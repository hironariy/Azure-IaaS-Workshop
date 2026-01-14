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

# Wait for tables to initialize
Write-Host "Waiting 60 seconds for Log Analytics tables (Syslog, Perf) to initialize..." -ForegroundColor Yellow
Write-Host "This is necessary because new workspaces don't have tables immediately."
Start-Sleep -Seconds 60

# Check if DCR already exists
$existingDcr = az monitor data-collection rule show `
    --resource-group $ResourceGroupName `
    --name $DcrName 2>$null

if ($existingDcr) {
    Write-Host "DCR '$DcrName' already exists. Deleting and recreating..." -ForegroundColor Yellow
    az monitor data-collection rule delete `
        --resource-group $ResourceGroupName `
        --name $DcrName `
        --yes
    Start-Sleep -Seconds 5
}

Write-Host "Creating Data Collection Rule: $DcrName" -ForegroundColor Green

# Create DCR using Azure CLI
az monitor data-collection rule create `
    --resource-group $ResourceGroupName `
    --name $DcrName `
    --location $Location `
    --kind "Linux" `
    --description "Data Collection Rule for Azure IaaS Workshop VMs" `
    --log-analytics "name=logAnalyticsDestination workspaceResourceId=$LogAnalyticsWorkspaceId" `
    --syslog "name=syslogDataSource streams=Microsoft-Syslog facilityNames=[auth,authpriv,daemon,syslog,user] logLevels=[Debug,Info,Notice,Warning,Error,Critical,Alert,Emergency]" `
    --performance-counters "name=perfCounterDataSource streams=Microsoft-Perf samplingFrequencyInSeconds=60 counterSpecifiers=['Processor(*)\\% Processor Time','Processor(*)\\% User Time','Processor(*)\\% Idle Time','Memory(*)\\% Used Memory','Memory(*)\\Available MBytes Memory','LogicalDisk(*)\\% Used Space','LogicalDisk(*)\\Free Megabytes','Network(*)\\Total Bytes Transmitted','Network(*)\\Total Bytes Received']" `
    --data-flows "streams=[Microsoft-Syslog] destinations=[logAnalyticsDestination]" `
    --data-flows "streams=[Microsoft-Perf] destinations=[logAnalyticsDestination]"

Write-Host "DCR created successfully!" -ForegroundColor Green

# Get DCR ID
$DcrId = az monitor data-collection rule show `
    --resource-group $ResourceGroupName `
    --name $DcrName `
    --query id -o tsv

Write-Host "DCR ID: $DcrId" -ForegroundColor Blue

# Associate DCR with all VMs
Write-Host ""
Write-Host "=== Associating DCR with VMs ===" -ForegroundColor Green

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
        
        # Check if association already exists and delete it
        try {
            az monitor data-collection rule association delete `
                --name $AssociationName `
                --resource $VmId `
                --yes 2>$null
        } catch {
            # Ignore errors if association doesn't exist
        }
        
        az monitor data-collection rule association create `
            --name $AssociationName `
            --resource $VmId `
            --rule-id $DcrId
        
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
