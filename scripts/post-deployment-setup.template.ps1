# =============================================================================
# Post-Deployment Setup Script - TEMPLATE (Windows 11 / PowerShell)
# =============================================================================
# This script configures the deployed Azure VMs after Bicep deployment:
#   1. Initializes MongoDB replica set
#   2. Creates MongoDB application users
#   3. Verifies all configurations
#
# SETUP INSTRUCTIONS:
#   1. Copy this file to post-deployment-setup.local.ps1
#   2. Edit the Configuration section with your values
#   3. Run: .\scripts\post-deployment-setup.local.ps1
#
# Prerequisites:
#   - Azure PowerShell module installed (Install-Module -Name Az)
#   - Logged in to Azure (Connect-AzAccount)
#   - PowerShell 7+ recommended
#   - Bicep deployment completed successfully
#
# Usage:
#   .\scripts\post-deployment-setup.local.ps1 [-ResourceGroup "rg-workshop-3"]
#
# =============================================================================

param(
    [string]$ResourceGroup = "<YOUR_RESOURCE_GROUP>"
)

# =============================================================================
# Configuration - EDIT THESE VALUES
# =============================================================================
$Config = @{
    # MongoDB Configuration
    ReplicaSetName = "blogapp-rs0"
    AdminUser      = "blogadmin"
    AdminPassword  = "<YOUR_MONGODB_ADMIN_PASSWORD>"
    AppUser        = "blogapp"
    # ⚠️ IMPORTANT: This password MUST match the 'mongoDbAppPassword' parameter in your .bicepparam file!
    # If these don't match, the backend API will fail to connect to MongoDB.
    AppPassword    = "<YOUR_MONGODB_APP_PASSWORD>"

    # VM Names (change if using different naming convention)
    DbVm1Name  = "vm-db-az1-prod"
    DbVm2Name  = "vm-db-az2-prod"
    AppVm1Name = "vm-app-az1-prod"
    WebVm1Name = "vm-web-az1-prod"

    # MongoDB IPs (from Bicep deployment)
    DbVm1Ip = "10.0.3.4"
    DbVm2Ip = "10.0.3.5"
}
# =============================================================================

# =============================================================================
# Helper Functions
# =============================================================================

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Invoke-VMCommand {
    param(
        [string]$ResourceGroupName,
        [string]$VMName,
        [string]$Script
    )
    
    Write-LogInfo "Running command on $VMName..."
    $result = Invoke-AzVMRunCommand `
        -ResourceGroupName $ResourceGroupName `
        -VMName $VMName `
        -CommandId 'RunShellScript' `
        -ScriptString $Script
    
    # Return the output
    if ($result.Value) {
        $result.Value | ForEach-Object {
            if ($_.Message) {
                Write-Host $_.Message
            }
        }
    }
    return $result
}

# =============================================================================
# Main Script
# =============================================================================

Write-Host "=============================================================="
Write-Host "  Post-Deployment Setup for Azure IaaS Workshop"
Write-Host "=============================================================="
Write-Host ""
Write-LogInfo "Resource Group: $ResourceGroup"
Write-Host ""

# Validate configuration
if ($ResourceGroup -like "*<*" -or $Config.AdminPassword -like "*<*") {
    Write-LogError "Please edit this script and replace all <PLACEHOLDER> values!"
    Write-LogError "Or copy post-deployment-setup.template.ps1 to post-deployment-setup.local.ps1 and edit."
    exit 1
}

# Check Azure PowerShell login
$context = Get-AzContext
if (-not $context) {
    Write-LogError "Not logged in to Azure. Please run 'Connect-AzAccount' first."
    exit 1
}
Write-LogInfo "Logged in as: $($context.Account.Id)"

# -----------------------------------------------------------------------------
# Step 1: Verify Deployment
# -----------------------------------------------------------------------------
Write-LogInfo "Step 1: Verifying deployment..."

# Check if resource group exists
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop
    Write-LogSuccess "Resource group found: $($rg.ResourceGroupName)"
}
catch {
    Write-LogError "Resource group $ResourceGroup not found!"
    exit 1
}

# Get VM objects
try {
    $DbVm1 = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Config.DbVm1Name -ErrorAction Stop
    $DbVm2 = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Config.DbVm2Name -ErrorAction Stop
    Write-LogSuccess "All DB VMs found in resource group"
}
catch {
    Write-LogError "DB VMs not found! Ensure Bicep deployment completed successfully."
    Write-LogError $_.Exception.Message
    exit 1
}

# -----------------------------------------------------------------------------
# Step 2: Wait for VMs to be ready
# -----------------------------------------------------------------------------
Write-LogInfo "Step 2: Waiting for VMs to be ready..."

# Wait for CustomScript extensions to complete
Write-LogInfo "Waiting 60 seconds for CustomScript extensions to complete..."
Start-Sleep -Seconds 60

Write-LogSuccess "VMs should be ready"

# -----------------------------------------------------------------------------
# Step 3: Initialize MongoDB Replica Set
# -----------------------------------------------------------------------------
Write-LogInfo "Step 3: Initializing MongoDB replica set..."

# Check if replica set is already initialized
$rsStatusScript = "mongosh --quiet --eval 'rs.status().ok' 2>/dev/null || echo '0'"
$rsStatusResult = Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $rsStatusScript

$rsInitialized = $rsStatusResult.Value | Where-Object { $_.Message -match "^1$" }

if ($rsInitialized) {
    Write-LogWarning "Replica set already initialized, skipping..."
}
else {
    Write-LogInfo "Initializing replica set $($Config.ReplicaSetName)..."
    
    $initScript = @"
mongosh --quiet --eval 'rs.initiate({
    _id: "$($Config.ReplicaSetName)",
    members: [
        { _id: 0, host: "$($Config.DbVm1Ip):27017", priority: 2 },
        { _id: 1, host: "$($Config.DbVm2Ip):27017", priority: 1 }
    ]
})'
"@
    
    Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $initScript
    
    Write-LogInfo "Waiting for replica set to elect primary (30 seconds)..."
    Start-Sleep -Seconds 30
    
    Write-LogSuccess "Replica set initialized"
}

# -----------------------------------------------------------------------------
# Step 4: Create MongoDB Admin User
# -----------------------------------------------------------------------------
Write-LogInfo "Step 4: Creating MongoDB admin user..."

$adminUserScript = @"
mongosh --quiet --eval '
    db = db.getSiblingDB("admin");
    if (db.getUser("$($Config.AdminUser)") === null) {
        db.createUser({
            user: "$($Config.AdminUser)",
            pwd: "$($Config.AdminPassword)",
            roles: [{ role: "root", db: "admin" }]
        });
        print("Admin user created");
    } else {
        print("Admin user already exists");
    }
'
"@

try {
    Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $adminUserScript
}
catch {
    Write-LogWarning "Admin user may already exist"
}

Write-LogSuccess "MongoDB admin user ready"

# -----------------------------------------------------------------------------
# Step 5: Create MongoDB Application User
# -----------------------------------------------------------------------------
Write-LogInfo "Step 5: Creating MongoDB application user..."

$appUserScript = @"
mongosh --quiet --eval '
    db = db.getSiblingDB("blogapp");
    if (db.getUser("$($Config.AppUser)") === null) {
        db.createUser({
            user: "$($Config.AppUser)",
            pwd: "$($Config.AppPassword)",
            roles: [{ role: "readWrite", db: "blogapp" }]
        });
        print("Application user created");
    } else {
        print("Application user already exists");
    }
'
"@

try {
    Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $appUserScript
}
catch {
    Write-LogWarning "Application user may already exist"
}

Write-LogSuccess "MongoDB application user ready"

# -----------------------------------------------------------------------------
# Step 6: Verify Configuration
# -----------------------------------------------------------------------------
Write-LogInfo "Step 6: Verifying configuration..."

# Verify replica set status
Write-LogInfo "Checking replica set status..."
$rsVerifyScript = 'mongosh --quiet --eval "rs.status().members.forEach(m => print(m.name + \": \" + m.stateStr))"'
Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $rsVerifyScript

# -----------------------------------------------------------------------------
# Step 7: Verify App Tier Environment Variables
# -----------------------------------------------------------------------------
Write-LogInfo "Step 7: Verifying App tier environment variables..."

try {
    $AppVm1 = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Config.AppVm1Name -ErrorAction Stop
    Write-LogInfo "Checking /etc/environment on App VM..."
    $envScript = "cat /etc/environment | grep -E 'NODE_ENV|MONGODB_URI|ENTRA' || echo 'Environment variables not found'"
    Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.AppVm1Name -Script $envScript
}
catch {
    Write-LogWarning "App VM not found or not accessible"
}

# -----------------------------------------------------------------------------
# Step 8: Verify Web Tier Config
# -----------------------------------------------------------------------------
Write-LogInfo "Step 8: Verifying Web tier config.json..."

try {
    $WebVm1 = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Config.WebVm1Name -ErrorAction Stop
    Write-LogInfo "Checking /var/www/html/config.json on Web VM..."
    $configScript = "cat /var/www/html/config.json 2>/dev/null || echo 'config.json not found'"
    Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.WebVm1Name -Script $configScript
}
catch {
    Write-LogWarning "Web VM not found or not accessible"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================="
Write-Host "  Post-Deployment Setup Complete!"
Write-Host "=============================================================="
Write-Host ""
Write-LogSuccess "MongoDB replica set: $($Config.ReplicaSetName)"
Write-LogSuccess "MongoDB admin user: $($Config.AdminUser)"
Write-LogSuccess "MongoDB app user: $($Config.AppUser)"
Write-Host ""
Write-LogInfo "Next steps:"
Write-Host "  1. Deploy backend application code to App VMs"
Write-Host "  2. Build and deploy frontend to Web VMs"
Write-Host "  3. Update NGINX configuration for API proxy"
Write-Host ""
Write-LogInfo "Connection string for backend:"
Write-Host "  mongodb://$($Config.AppUser):$($Config.AppPassword)@$($Config.DbVm1Ip):27017,$($Config.DbVm2Ip):27017/blogapp?replicaSet=$($Config.ReplicaSetName)&authSource=blogapp"
Write-Host ""
