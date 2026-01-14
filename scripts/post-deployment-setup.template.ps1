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
#   - Azure CLI installed and logged in
#   - PowerShell 7+ recommended
#   - Bicep deployment completed successfully
#   - SSH key available
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
    # Azure Resources
    BastionName = "<YOUR_BASTION_NAME>"
    SshKey      = "<PATH_TO_YOUR_SSH_KEY>"  # e.g., "$env:USERPROFILE\.ssh\id_rsa"
    Username    = "azureuser"

    # MongoDB Configuration
    ReplicaSetName = "blogapp-rs0"
    AdminUser      = "blogadmin"
    AdminPassword  = "<YOUR_MONGODB_ADMIN_PASSWORD>"
    AppUser        = "blogapp"
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

function Invoke-BastionSsh {
    param(
        [string]$VmId,
        [string]$Command
    )
    
    # Note: The command must be passed as a single quoted string after -t
    # Using Start-Process to capture output properly
    $sshArgs = @(
        "network", "bastion", "ssh",
        "--name", $Config.BastionName,
        "-g", $ResourceGroup,
        "--target-resource-id", $VmId,
        "--auth-type", "ssh-key",
        "--username", $Config.Username,
        "--ssh-key", $Config.SshKey,
        "--",
        "-o", "StrictHostKeyChecking=no",
        "-t", $Command
    )
    
    az @sshArgs
}

# =============================================================================
# Main Script
# =============================================================================

Write-Host "=============================================================="
Write-Host "  Post-Deployment Setup for Azure IaaS Workshop"
Write-Host "=============================================================="
Write-Host ""
Write-LogInfo "Resource Group: $ResourceGroup"
Write-LogInfo "Bastion: $($Config.BastionName)"
Write-Host ""

# Validate configuration
if ($ResourceGroup -like "*<*" -or $Config.BastionName -like "*<*") {
    Write-LogError "Please edit this script and replace all <PLACEHOLDER> values!"
    Write-LogError "Or copy post-deployment-setup.template.ps1 to post-deployment-setup.local.ps1 and edit."
    exit 1
}

# -----------------------------------------------------------------------------
# Step 1: Verify Deployment
# -----------------------------------------------------------------------------
Write-LogInfo "Step 1: Verifying deployment..."

# Check if resource group exists
$rgExists = az group show -n $ResourceGroup 2>$null
if (-not $rgExists) {
    Write-LogError "Resource group $ResourceGroup not found!"
    exit 1
}

# Get VM IDs
$DbVm1Id = az vm show -g $ResourceGroup -n $Config.DbVm1Name --query id -o tsv 2>$null
$DbVm2Id = az vm show -g $ResourceGroup -n $Config.DbVm2Name --query id -o tsv 2>$null

if (-not $DbVm1Id -or -not $DbVm2Id) {
    Write-LogError "DB VMs not found! Ensure Bicep deployment completed successfully."
    exit 1
}

Write-LogSuccess "All VMs found in resource group"

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
$rsStatusCmd = "mongosh --quiet --eval 'rs.status().ok' 2>/dev/null || echo '0'"
Write-LogInfo "Checking replica set status via Bastion SSH..."
$rsStatus = Invoke-BastionSsh -VmId $DbVm1Id -Command $rsStatusCmd 2>$null

if ($rsStatus -match "1") {
    Write-LogWarning "Replica set already initialized, skipping..."
}
else {
    Write-LogInfo "Initializing replica set $($Config.ReplicaSetName)..."
    
    # Use single-line command to avoid PowerShell string escaping issues
    $initCmd = "mongosh --quiet --eval 'rs.initiate({ _id: `"$($Config.ReplicaSetName)`", members: [{ _id: 0, host: `"$($Config.DbVm1Ip):27017`", priority: 2 }, { _id: 1, host: `"$($Config.DbVm2Ip):27017`", priority: 1 }] })'"
    
    Invoke-BastionSsh -VmId $DbVm1Id -Command $initCmd
    
    Write-LogInfo "Waiting for replica set to elect primary (30 seconds)..."
    Start-Sleep -Seconds 30
    
    Write-LogSuccess "Replica set initialized"
}

# -----------------------------------------------------------------------------
# Step 4: Create MongoDB Admin User
# -----------------------------------------------------------------------------
Write-LogInfo "Step 4: Creating MongoDB admin user..."

# Use single-line command to avoid PowerShell string escaping issues
$adminUserCmd = "mongosh --quiet --eval 'db = db.getSiblingDB(`"admin`"); if (db.getUser(`"$($Config.AdminUser)`") === null) { db.createUser({ user: `"$($Config.AdminUser)`", pwd: `"$($Config.AdminPassword)`", roles: [{ role: `"root`", db: `"admin`" }] }); print(`"Admin user created`"); } else { print(`"Admin user already exists`"); }'"

try {
    Invoke-BastionSsh -VmId $DbVm1Id -Command $adminUserCmd 2>$null
}
catch {
    Write-LogWarning "Admin user may already exist"
}

Write-LogSuccess "MongoDB admin user ready"

# -----------------------------------------------------------------------------
# Step 5: Create MongoDB Application User
# -----------------------------------------------------------------------------
Write-LogInfo "Step 5: Creating MongoDB application user..."

# Use single-line command to avoid PowerShell string escaping issues
$appUserCmd = "mongosh --quiet --eval 'db = db.getSiblingDB(`"blogapp`"); if (db.getUser(`"$($Config.AppUser)`") === null) { db.createUser({ user: `"$($Config.AppUser)`", pwd: `"$($Config.AppPassword)`", roles: [{ role: `"readWrite`", db: `"blogapp`" }] }); print(`"Application user created`"); } else { print(`"Application user already exists`"); }'"

try {
    Invoke-BastionSsh -VmId $DbVm1Id -Command $appUserCmd 2>$null
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
$rsVerifyCmd = "mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + `\": `\" + m.stateStr))'"
Invoke-BastionSsh -VmId $DbVm1Id -Command $rsVerifyCmd

# -----------------------------------------------------------------------------
# Step 7: Verify App Tier Environment Variables
# -----------------------------------------------------------------------------
Write-LogInfo "Step 7: Verifying App tier environment variables..."

$AppVm1Id = az vm show -g $ResourceGroup -n $Config.AppVm1Name --query id -o tsv 2>$null

if ($AppVm1Id) {
    Write-LogInfo "Checking /etc/environment on App VM..."
    $envCmd = "cat /etc/environment | grep -E 'NODE_ENV|MONGODB_URI|ENTRA' || echo 'Environment variables not found'"
    Invoke-BastionSsh -VmId $AppVm1Id -Command $envCmd
}

# -----------------------------------------------------------------------------
# Step 8: Verify Web Tier Config
# -----------------------------------------------------------------------------
Write-LogInfo "Step 8: Verifying Web tier config.json..."

$WebVm1Id = az vm show -g $ResourceGroup -n $Config.WebVm1Name --query id -o tsv 2>$null

if ($WebVm1Id) {
    Write-LogInfo "Checking /var/www/html/config.json on Web VM..."
    $configCmd = "cat /var/www/html/config.json 2>/dev/null || echo 'config.json not found'"
    Invoke-BastionSsh -VmId $WebVm1Id -Command $configCmd
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
