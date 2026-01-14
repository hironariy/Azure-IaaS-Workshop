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
#   - Azure PowerShell module installed (Install-Module -Name Az)
#   - Logged in to Azure (Connect-AzAccount)
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

# Check Azure PowerShell login
$context = Get-AzContext
if (-not $context) {
    Write-Host "Error: Not logged in to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
    exit 1
}
Write-Host "Logged in as: $($context.Account.Id)" -ForegroundColor Green
Write-Host ""

Write-Host "=== Creating Data Collection Rule ===" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName"

# Get resource group location
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    $Location = $rg.Location
    Write-Host "Location: $Location"
}
catch {
    Write-Host "Error: Resource group '$ResourceGroupName' not found!" -ForegroundColor Red
    exit 1
}

# Get Log Analytics workspace
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName | Select-Object -First 1

if (-not $workspace) {
    Write-Host "Error: No Log Analytics workspace found in resource group $ResourceGroupName" -ForegroundColor Red
    exit 1
}

$LogAnalyticsWorkspaceId = $workspace.ResourceId
$LogAnalyticsWorkspaceName = $workspace.Name

Write-Host "Found Log Analytics Workspace: $LogAnalyticsWorkspaceName"

# Function to check if required tables exist
function Test-TablesReady {
    param(
        [string]$WorkspaceName,
        [string]$ResourceGroup
    )
    
    try {
        # Check Syslog table using REST API
        $subscriptionId = (Get-AzContext).Subscription.Id
        $syslogUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/Syslog?api-version=2022-10-01"
        $syslogTable = Invoke-AzRestMethod -Uri $syslogUri -Method GET
        
        if ($syslogTable.StatusCode -ne 200) {
            return $false
        }
        
        # Check Perf table
        $perfUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/Perf?api-version=2022-10-01"
        $perfTable = Invoke-AzRestMethod -Uri $perfUri -Method GET
        
        if ($perfTable.StatusCode -ne 200) {
            return $false
        }
        
        return $true
    }
    catch {
        return $false
    }
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
$existingDcr = Get-AzDataCollectionRule -ResourceGroupName $ResourceGroupName -Name $DcrName -ErrorAction SilentlyContinue

if ($existingDcr) {
    Write-Host "DCR '$DcrName' already exists. Deleting and recreating..." -ForegroundColor Yellow
    Remove-AzDataCollectionRule -ResourceGroupName $ResourceGroupName -Name $DcrName
    Write-Host "Waiting for deletion to complete..."
    Start-Sleep -Seconds 5
}

Write-Host "Creating Data Collection Rule: $DcrName" -ForegroundColor Green
Write-Host "This may take 1-2 minutes..."

# Create DCR using Azure PowerShell
$subscriptionId = (Get-AzContext).Subscription.Id

# Define Syslog data source
$syslogDataSource = New-AzSyslogDataSourceObject `
    -Name "syslogDataSource" `
    -Stream "Microsoft-Syslog" `
    -FacilityName @("auth", "authpriv", "daemon", "syslog", "user") `
    -LogLevel @("Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency")

# Define Performance Counter data source
$perfCounterDataSource = New-AzPerfCounterDataSourceObject `
    -Name "perfCounterDataSource" `
    -Stream "Microsoft-Perf" `
    -SamplingFrequencyInSecond 60 `
    -CounterSpecifier @(
        "Processor(*)\\% Processor Time",
        "Processor(*)\\% User Time",
        "Processor(*)\\% Idle Time",
        "Memory(*)\\% Used Memory",
        "Memory(*)\\Available MBytes Memory",
        "LogicalDisk(*)\\% Used Space",
        "LogicalDisk(*)\\Free Megabytes",
        "Network(*)\\Total Bytes Transmitted",
        "Network(*)\\Total Bytes Received"
    )

# Define Log Analytics destination
$logAnalyticsDestination = New-AzLogAnalyticsDestinationObject `
    -Name "logAnalyticsDestination" `
    -WorkspaceResourceId $LogAnalyticsWorkspaceId

# Define data flows
$syslogDataFlow = New-AzDataFlowObject `
    -Stream "Microsoft-Syslog" `
    -Destination "logAnalyticsDestination"

$perfDataFlow = New-AzDataFlowObject `
    -Stream "Microsoft-Perf" `
    -Destination "logAnalyticsDestination"

# Create the Data Collection Rule
New-AzDataCollectionRule `
    -ResourceGroupName $ResourceGroupName `
    -Name $DcrName `
    -Location $Location `
    -Kind "Linux" `
    -Description "Data Collection Rule for Azure IaaS Workshop VMs" `
    -DataSourceSyslog $syslogDataSource `
    -DataSourcePerformanceCounter $perfCounterDataSource `
    -DestinationLogAnalytic $logAnalyticsDestination `
    -DataFlow @($syslogDataFlow, $perfDataFlow) | Out-Null

Write-Host "DCR created successfully!" -ForegroundColor Green

# Get DCR ID
Write-Host "Getting DCR ID..." -ForegroundColor Blue
$dcr = Get-AzDataCollectionRule -ResourceGroupName $ResourceGroupName -Name $DcrName
$DcrId = $dcr.Id

Write-Host "DCR ID: $DcrId" -ForegroundColor Blue

# Associate DCR with all VMs
Write-Host ""
Write-Host "=== Associating DCR with VMs ===" -ForegroundColor Green

Write-Host "Fetching VM list..."
$vmList = Get-AzVM -ResourceGroupName $ResourceGroupName

if ($vmList.Count -eq 0) {
    Write-Host "No VMs found in resource group. Skipping DCR association." -ForegroundColor Yellow
} else {
    Write-Host "Found $($vmList.Count) VM(s) to associate with DCR"
    
    foreach ($vm in $vmList) {
        $VmName = $vm.Name
        $VmId = $vm.Id
        $AssociationName = "configurationAccessEndpoint"
        
        Write-Host "Associating DCR with VM: $VmName" -ForegroundColor Blue
        
        # Delete existing association if exists
        $existingAssociation = Get-AzDataCollectionRuleAssociation -TargetResourceId $VmId -AssociationName $AssociationName -ErrorAction SilentlyContinue
        if ($existingAssociation) {
            Remove-AzDataCollectionRuleAssociation -TargetResourceId $VmId -AssociationName $AssociationName
        }
        
        # Create new association
        New-AzDataCollectionRuleAssociation `
            -TargetResourceId $VmId `
            -AssociationName $AssociationName `
            -DataCollectionRuleId $DcrId | Out-Null
        
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
Write-Host "  Get-AzDataCollectionRule -ResourceGroupName $ResourceGroupName -Name $DcrName"
Write-Host ""
Write-Host "To verify VM associations:"
Write-Host "  Get-AzDataCollectionRuleAssociation -TargetResourceId <VM_ID>"
