# =============================================================================
# Create and Configure Data Collection Rule for Azure Monitor
# =============================================================================
# Purpose: Create DCR and associate it with VMs after Bicep deployment
#
# This script:
#   1. Waits for Log Analytics tables to initialize
#   2. Creates a new Data Collection Rule with Syslog and Performance counters
#   3. Associates the DCR with all VMs in the resource group
#
# Why post-deployment?
#   - Log Analytics tables (Syslog, Perf) take 1-5 minutes to initialize
#   - DCR creation validates tables at creation time
#   - Bicep deployment would fail with "InvalidOutputTable" error
#
# Prerequisites:
#   - Azure CLI installed and logged in
#   - Log Analytics workspace already deployed
#   - VMs already deployed with Azure Monitor Agent extension
#
# Usage:
#   .\configure-dcr.ps1 -ResourceGroupName <resource-group-name>
#
# Example:
#   .\configure-dcr.ps1 -ResourceGroupName rg-blogapp-prod
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = "Stop"

$DcrName = "dcr-blogapp-prod"

# Ensure required Azure CLI extensions are installed
Write-Host "Checking Azure CLI extensions..." -ForegroundColor Blue
az config set extension.use_dynamic_install=yes_without_prompt 2>$null
$extensionInstalled = az extension show --name monitor-control-service 2>$null
if (-not $extensionInstalled) {
    Write-Host "Installing monitor-control-service extension..."
    az extension add --name monitor-control-service --yes
}
Write-Host "Azure CLI extensions ready" -ForegroundColor Green
Write-Host ""

Write-Host "=== Creating Data Collection Rule ===" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName"

# Get resource group location
$rg = az group show -n $ResourceGroupName | ConvertFrom-Json
$Location = $rg.location
Write-Host "Location: $Location"

# Get Log Analytics workspace
$workspace = az monitor log-analytics workspace list `
    --resource-group $ResourceGroupName `
    --query "[0]" | ConvertFrom-Json

if (-not $workspace) {
    Write-Host "Error: No Log Analytics workspace found in resource group $ResourceGroupName" -ForegroundColor Red
    exit 1
}

$LogAnalyticsWorkspaceId = $workspace.id
$LogAnalyticsWorkspaceName = $workspace.name

Write-Host "Found Log Analytics Workspace: $LogAnalyticsWorkspaceName"

# Function to check if required tables exist
function Test-TablesReady {
    param(
        [string]$WorkspaceName,
        [string]$ResourceGroup
    )
    
    # Check Syslog table
    $syslogTable = az monitor log-analytics workspace table show `
        --resource-group $ResourceGroup `
        --workspace-name $WorkspaceName `
        --name Syslog 2>$null
    
    if (-not $syslogTable) {
        return $false
    }
    
    # Check Perf table
    $perfTable = az monitor log-analytics workspace table show `
        --resource-group $ResourceGroup `
        --workspace-name $WorkspaceName `
        --name Perf 2>$null
    
    if (-not $perfTable) {
        return $false
    }
    
    return $true
}

# Wait for tables to initialize with timeout
Write-Host "Checking if Log Analytics tables (Syslog, Perf) are initialized..." -ForegroundColor Yellow
Write-Host "This may take 1-5 minutes for newly created workspaces."
Write-Host ""

$MaxAttempts = 30  # 30 attempts * 10 seconds = 5 minutes max
$Attempt = 1

while ($Attempt -le $MaxAttempts) {
    if (Test-TablesReady -WorkspaceName $LogAnalyticsWorkspaceName -ResourceGroup $ResourceGroupName) {
        Write-Host "✓ Log Analytics tables are ready!" -ForegroundColor Green
        break
    }
    
    if ($Attempt -eq $MaxAttempts) {
        Write-Host "Error: Timeout waiting for Log Analytics tables to initialize." -ForegroundColor Red
        Write-Host "Please wait a few more minutes and run this script again."
        exit 1
    }
    
    Write-Host "  Attempt $Attempt/$MaxAttempts`: Tables not ready yet. Waiting 10 seconds..."
    Start-Sleep -Seconds 10
    $Attempt++
}

# Check if DCR already exists
Write-Host "Checking if DCR already exists..." -ForegroundColor Blue
$existingDcr = az monitor data-collection rule show `
    --resource-group $ResourceGroupName `
    --name $DcrName 2>$null

if ($existingDcr) {
    Write-Host "DCR '$DcrName' already exists. Deleting and recreating..." -ForegroundColor Yellow
    az monitor data-collection rule delete `
        --resource-group $ResourceGroupName `
        --name $DcrName `
        --yes `
        --output none
    Write-Host "Waiting for deletion to complete..."
    Start-Sleep -Seconds 5
}

Write-Host "Creating Data Collection Rule: $DcrName" -ForegroundColor Green
Write-Host "This may take 1-2 minutes..."

# Create DCR JSON configuration
$subscriptionId = (az account show --query id -o tsv)
$dcrJson = @"
{
    "location": "$Location",
    "kind": "Linux",
    "properties": {
        "description": "Data Collection Rule for Azure IaaS Workshop VMs",
        "dataSources": {
            "syslog": [
                {
                    "name": "syslogDataSource",
                    "streams": ["Microsoft-Syslog"],
                    "facilityNames": ["auth", "authpriv", "daemon", "syslog", "user"],
                    "logLevels": ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
                }
            ],
            "performanceCounters": [
                {
                    "name": "perfCounterDataSource",
                    "streams": ["Microsoft-Perf"],
                    "samplingFrequencyInSeconds": 60,
                    "counterSpecifiers": [
                        "Processor(*)\\% Processor Time",
                        "Processor(*)\\% User Time",
                        "Processor(*)\\% Idle Time",
                        "Memory(*)\\% Used Memory",
                        "Memory(*)\\Available MBytes Memory",
                        "LogicalDisk(*)\\% Used Space",
                        "LogicalDisk(*)\\Free Megabytes",
                        "Network(*)\\Total Bytes Transmitted",
                        "Network(*)\\Total Bytes Received"
                    ]
                }
            ]
        },
        "destinations": {
            "logAnalytics": [
                {
                    "name": "logAnalyticsDestination",
                    "workspaceResourceId": "$LogAnalyticsWorkspaceId"
                }
            ]
        },
        "dataFlows": [
            {
                "streams": ["Microsoft-Syslog"],
                "destinations": ["logAnalyticsDestination"]
            },
            {
                "streams": ["Microsoft-Perf"],
                "destinations": ["logAnalyticsDestination"]
            }
        ]
    }
}
"@

# Save JSON to temp file
$tempFile = [System.IO.Path]::GetTempFileName()
$dcrJson | Out-File -FilePath $tempFile -Encoding utf8

# Create DCR using REST API (more reliable than CLI shorthand)
az rest --method PUT `
    --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/dataCollectionRules/$DcrName`?api-version=2022-06-01" `
    --body "@$tempFile" `
    --output none

# Clean up temp file
Remove-Item -Path $tempFile -Force

Write-Host "DCR created successfully!" -ForegroundColor Green

# Get DCR ID
Write-Host "Getting DCR ID..." -ForegroundColor Blue
$DcrId = az monitor data-collection rule show `
    --resource-group $ResourceGroupName `
    --name $DcrName `
    --query id -o tsv

Write-Host "DCR ID: $DcrId" -ForegroundColor Blue

# Associate DCR with all VMs
Write-Host ""
Write-Host "=== Associating DCR with VMs ===" -ForegroundColor Green

Write-Host "Fetching VM list..."
$vmList = az vm list --resource-group $ResourceGroupName | ConvertFrom-Json

if ($vmList.Count -eq 0) {
    Write-Host "No VMs found in resource group. Skipping DCR association." -ForegroundColor Yellow
} else {
    Write-Host "Found $($vmList.Count) VM(s) to associate with DCR"
    
    foreach ($vm in $vmList) {
        $VmName = $vm.name
        $VmId = $vm.id
        $AssociationName = "configurationAccessEndpoint"
        
        Write-Host "Associating DCR with VM: $VmName" -ForegroundColor Blue
        
        # Delete existing association if exists (faster than checking first)
        az monitor data-collection rule association delete `
            --name $AssociationName `
            --resource $VmId `
            --yes `
            --output none 2>$null
        
        az monitor data-collection rule association create `
            --name $AssociationName `
            --resource $VmId `
            --rule-id $DcrId `
            --output none
        
        Write-Host "  ✓ Associated" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== DCR Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Data Collection Rule '$DcrName' is now configured to collect:"
Write-Host "  📊 Syslog (auth, authpriv, daemon, syslog, user facilities)"
Write-Host "  📈 Performance Counters (CPU, Memory, Disk, Network)"
Write-Host ""
Write-Host "Data will appear in Log Analytics within 5-10 minutes."
Write-Host ""
Write-Host "To verify DCR configuration:"
Write-Host "  az monitor data-collection rule show -g $ResourceGroupName -n $DcrName"
Write-Host ""
Write-Host "To verify VM associations:"
Write-Host "  az monitor data-collection rule association list --resource <VM_ID>"
