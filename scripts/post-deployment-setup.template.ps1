# =============================================================================
# Post-Deployment Setup Script - TEMPLATE (Windows 11 / PowerShell)
# =============================================================================
# This script configures the deployed Azure VMs after Bicep deployment:
#   1. Initializes the 3-member MongoDB replica set (Issue #30)
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
# Re-running is safe (idempotent): an already-initialized replica set is never
# re-initiated or force-reconfigured, and existing users are kept.
# Existing 2-node environments: add the 3rd member with the migration
# procedure in the troubleshooting runbook (section 7.2), not with this script.
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
    DbVm3Name  = "vm-db-az3-prod"
    AppVm1Name = "vm-app-az1-prod"
    WebVm1Name = "vm-web-az1-prod"

    # MongoDB IPs (from Bicep deployment)
    DbVm1Ip = "10.0.3.4"
    DbVm2Ip = "10.0.3.5"
    DbVm3Ip = "10.0.3.6"
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

# Mask the password in MongoDB connection strings before anything is printed
# (RepositoryWideDesignRules.md 1.4): mongodb://user:secret@host -> mongodb://user:***@host
function ConvertTo-MaskedText {
    param([string]$Text)
    return [regex]::Replace($Text, '(mongodb(\+srv)?://[^:/@\s]*:)[^@\s]*@', '$1***@')
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
    
    # Print the output with secrets masked (Issue #32)
    if ($result.Value) {
        $result.Value | ForEach-Object {
            if ($_.Message) {
                Write-Host (ConvertTo-MaskedText $_.Message)
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
}
catch {
    Write-LogError "DB VMs not found! Ensure Bicep deployment completed successfully."
    Write-LogError $_.Exception.Message
    exit 1
}
try {
    $DbVm3 = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Config.DbVm3Name -ErrorAction Stop
}
catch {
    # Issue #30: the replica set needs 3 data-bearing voting members so that
    # any single-node failure still leaves a majority (2 of 3).
    Write-LogError "$($Config.DbVm3Name) not found. The workshop now uses a 3-node replica set (Issue #30)."
    Write-LogError "New deployment: re-run the Bicep deployment (it creates vm-db-az3)."
    Write-LogError "Existing 2-node environment: follow troubleshooting runbook 7.2 '2-node to 3-node migration'."
    exit 1
}
Write-LogSuccess "All 3 DB VMs found in resource group"

# -----------------------------------------------------------------------------
# Step 2: Wait for VMs to be ready
# -----------------------------------------------------------------------------
Write-LogInfo "Step 2: Waiting for VMs to be ready..."

# Wait for CustomScript extensions to complete
Write-LogInfo "Waiting 60 seconds for CustomScript extensions to complete..."
Start-Sleep -Seconds 60

# DB VMs reboot once after the CustomScript to switch to the Ubuntu 24.04 LTS
# Azure kernel (6.8), because MongoDB 8.0 does not start on Linux >= 6.19
# (Issue #26). mongod is only reachable after that reboot, so poll each DB VM
# until: kernel is 6.8.x, mongod is active, and db.hello() answers.
$DbReadyTimeoutSec = 900
$DbReadyIntervalSec = 30

function Wait-DbVmReady {
    param([string]$VMName)

    $elapsed = 0
    $last = "kernel=? mongod=? hello=?"
    $lastError = ""
    $probe = 'echo DBREADY kernel=$(uname -r) mongod=$(systemctl is-active mongod) hello=$(mongosh --quiet --eval ''db.hello().ok'' 2>/dev/null || echo 0)'
    Write-LogInfo "Waiting for MongoDB on $VMName (6.8 LTS kernel + mongod running, timeout ${DbReadyTimeoutSec}s)..."
    while ($elapsed -lt $DbReadyTimeoutSec) {
        $message = ""
        try {
            # Fails or times out while the VM is rebooting; that is expected, just retry.
            $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroup -VMName $VMName `
                -CommandId 'RunShellScript' -ScriptString $probe -ErrorAction Stop
            $message = ($result.Value | ForEach-Object { $_.Message }) -join "`n"
        }
        catch {
            $message = ""
            $lastError = ConvertTo-MaskedText $_.Exception.Message
        }
        $m = [regex]::Match($message, 'DBREADY kernel=(\S+) mongod=(\S+) hello=(\S+)')
        if ($m.Success) {
            $kernel = $m.Groups[1].Value
            $state = $m.Groups[2].Value
            $hello = $m.Groups[3].Value
            $last = "kernel=$kernel mongod=$state hello=$hello"
            if ($kernel -like "6.8.*" -and $state -eq "active" -and $hello -eq "1") {
                Write-LogSuccess "$VMName ready: kernel=$kernel mongod=$state"
                return
            }
            Write-LogInfo "  $VMName not ready yet: $last (${elapsed}s)"
        }
        else {
            Write-LogInfo "  $VMName not reachable yet (rebooting into the LTS kernel?) (${elapsed}s) $lastError"
        }
        Start-Sleep -Seconds $DbReadyIntervalSec
        $elapsed += $DbReadyIntervalSec
    }
    Write-LogError "${VMName}: MongoDB is not ready after ${DbReadyTimeoutSec}s (last: $last)."
    Write-LogError "MongoDB 8.0 needs the 6.8 LTS kernel (Issue #26). On $VMName run:"
    Write-LogError "  uname -r ; sudo blogapp-kernel-track status ; sudo journalctl -u mongod -u blogapp-kernel-track-finalize -b --no-pager | tail -50"
    Write-LogError "Fix: troubleshooting runbook section 7.1 'MongoDB Does Not Start: Linux Kernel 6.19 Or Newer' (Issue #26)."
    Write-LogError "Re-run this script when all 3 DB VMs are ready (it is safe to re-run)."
    exit 1
}

Wait-DbVmReady -VMName $Config.DbVm1Name
Wait-DbVmReady -VMName $Config.DbVm2Name
Wait-DbVmReady -VMName $Config.DbVm3Name

Write-LogSuccess "VMs are ready"

# -----------------------------------------------------------------------------
# Step 3: Initialize MongoDB Replica Set
# -----------------------------------------------------------------------------
Write-LogInfo "Step 3: Initializing MongoDB replica set..."

# Replica set seed list: all 3 members. mongosh/drivers use it to find the
# current PRIMARY, so later steps work even if an election already moved the
# PRIMARY away from vm-db-az1.
$RsHosts = "$($Config.DbVm1Ip):27017,$($Config.DbVm2Ip):27017,$($Config.DbVm3Ip):27017"
$RsUri = "mongodb://$RsHosts/?replicaSet=$($Config.ReplicaSetName)"

function Get-RunCommandText {
    param($Result)
    return (($Result.Value | ForEach-Object { $_.Message }) -join "`n")
}

# Check whether the replica set is already initialized (idempotency).
# rs.conf() throws NotYetInitialized on a fresh node.
$rsStateScript = @'
mongosh --quiet --eval 'try { print("RSSTATE initialized " + rs.conf().members.length) } catch (e) { print("RSSTATE uninitialized " + e.codeName) }'
'@
$rsStateResult = Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $rsStateScript
$rsStateMatch = [regex]::Match((Get-RunCommandText $rsStateResult), 'RSSTATE (initialized|uninitialized) (\S+)')

if ($rsStateMatch.Success -and $rsStateMatch.Groups[1].Value -eq "initialized") {
    $rsMemberCount = $rsStateMatch.Groups[2].Value
    Write-LogWarning "Replica set already initialized ($rsMemberCount members), skipping rs.initiate."
    if ($rsMemberCount -ne "3") {
        # Never force-reconfigure here: adding a member to a live set must be
        # done with rs.add() after the new VM is ready (runbook 7.2).
        Write-LogWarning "Expected 3 members. For an existing 2-node set, follow troubleshooting runbook 7.2 (rs.add, wait for initial sync)."
    }
}
elseif ($rsStateMatch.Success) {
    Write-LogInfo "Initializing replica set $($Config.ReplicaSetName) with 3 members..."

    # All 3 members are data-bearing, voting (votes: 1) and electable
    # (priority > 0). vm-db-az1 gets priority 2 only to make the INITIAL
    # PRIMARY deterministic for the workshop steps. Side effect to observe on
    # Day 2: after vm-db-az1 recovers and catches up, it calls a "priority
    # takeover" election and becomes PRIMARY again (a second short election).
    # Print a marker so success is checked, not assumed (Issue #32).
    $initScript = @"
mongosh --quiet --eval 'try {
    const r = rs.initiate({
        _id: "$($Config.ReplicaSetName)",
        members: [
            { _id: 0, host: "$($Config.DbVm1Ip):27017", priority: 2, votes: 1 },
            { _id: 1, host: "$($Config.DbVm2Ip):27017", priority: 1, votes: 1 },
            { _id: 2, host: "$($Config.DbVm3Ip):27017", priority: 1, votes: 1 }
        ]
    });
    print("RSINIT ok=" + r.ok);
} catch (e) { print("RSINIT error " + e.codeName + ": " + e.message) }'
"@

    $initResult = Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $initScript
    $initMatch = [regex]::Match((Get-RunCommandText $initResult), 'RSINIT .*')
    if (-not $initMatch.Success -or $initMatch.Value.Trim() -ne "RSINIT ok=1") {
        Write-LogError "rs.initiate failed on $($Config.DbVm1Name): $(if ($initMatch.Success) { $initMatch.Value } else { 'no answer' })"
        Write-LogError "Check that all 3 DB VMs can reach each other on port 27017 (NSG, mongod bindIp), then re-run this script."
        exit 1
    }
    Write-LogSuccess "Replica set initiated"
}
else {
    Write-LogError "Could not read the replica set state from $($Config.DbVm1Name)."
    Write-LogError "Check: mongosh --eval 'db.hello()' on $($Config.DbVm1Name), then re-run this script."
    exit 1
}

# Wait until the set is healthy: exactly 1 PRIMARY and 2 SECONDARY.
# (Replaces a fixed sleep: initial sync of an empty set takes ~10-30s.)
Write-LogInfo "Waiting for 1 PRIMARY + 2 SECONDARY (up to 3 minutes)..."
$rsHealthScript = @'
mongosh --quiet --eval 'for (let i = 0; i < 36; i++) { let p = 0, s = 0; try { rs.status().members.forEach(m => { if (m.stateStr === "PRIMARY") p++; if (m.stateStr === "SECONDARY") s++; }); } catch (e) {} if (p === 1 && s === 2) { print("RSHEALTH ok"); quit(0); } sleep(5000); } print("RSHEALTH timeout");'
'@
$rsHealthResult = Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $rsHealthScript
if ((Get-RunCommandText $rsHealthResult) -match 'RSHEALTH ok') {
    Write-LogSuccess "Replica set healthy: 1 PRIMARY + 2 SECONDARY"
}
else {
    # Users cannot be created without a PRIMARY, so stop here (Issue #32).
    Write-LogError "Replica set did not reach 1 PRIMARY + 2 SECONDARY within 3 minutes."
    Write-LogError "See troubleshooting runbook section 7, then re-run this script (it is safe to re-run)."
    exit 1
}

# -----------------------------------------------------------------------------
# Step 4: Create MongoDB Admin User
# -----------------------------------------------------------------------------
Write-LogInfo "Step 4: Creating MongoDB admin user..."

# Check the USER marker printed by the createUser commands in Steps 4-5:
# "USER created", "USER exists", or "USER error ...". Anything else stops
# the script instead of being reported as success (Issue #32).
function Assert-UserResult {
    param($Result, [string]$Label)
    $m = [regex]::Match((Get-RunCommandText $Result), 'USER .*')
    $line = if ($m.Success) { $m.Value.Trim() } else { "" }
    switch ($line) {
        "USER created" { Write-LogSuccess "MongoDB $Label created" }
        "USER exists" { Write-LogSuccess "MongoDB $Label already exists (kept as is)" }
        default {
            Write-LogError "Could not create MongoDB ${Label}: $(if ($line) { ConvertTo-MaskedText $line } else { 'no answer' })"
            Write-LogError "Fix the error above, then re-run this script (it is safe to re-run)."
            exit 1
        }
    }
}
# Connect with the replica set URI so the write goes to the current PRIMARY
# (createUser uses w:"majority" by default on a replica set).

$adminUserScript = @"
mongosh --quiet "$RsUri" --eval '
    try {
        db = db.getSiblingDB("admin");
        if (db.getUser("$($Config.AdminUser)") === null) {
            db.createUser({
                user: "$($Config.AdminUser)",
                pwd: "$($Config.AdminPassword)",
                roles: [{ role: "root", db: "admin" }]
            });
            print("USER created");
        } else {
            print("USER exists");
        }
    } catch (e) { print("USER error " + e.codeName + ": " + e.message) }
'
"@

$adminUserResult = Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $adminUserScript
Assert-UserResult -Result $adminUserResult -Label "admin user $($Config.AdminUser)"

# -----------------------------------------------------------------------------
# Step 5: Create MongoDB Application User
# -----------------------------------------------------------------------------
Write-LogInfo "Step 5: Creating MongoDB application user..."

$appUserScript = @"
mongosh --quiet "$RsUri" --eval '
    try {
        db = db.getSiblingDB("blogapp");
        if (db.getUser("$($Config.AppUser)") === null) {
            db.createUser({
                user: "$($Config.AppUser)",
                pwd: "$($Config.AppPassword)",
                roles: [{ role: "readWrite", db: "blogapp" }]
            });
            print("USER created");
        } else {
            print("USER exists");
        }
    } catch (e) { print("USER error " + e.codeName + ": " + e.message) }
'
"@

$appUserResult = Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $appUserScript
Assert-UserResult -Result $appUserResult -Label "application user $($Config.AppUser)"

# -----------------------------------------------------------------------------
# Step 6: Verify Configuration
# -----------------------------------------------------------------------------
Write-LogInfo "Step 6: Verifying configuration..."

# Verify replica set status
Write-LogInfo "Checking replica set status..."
$rsVerifyScript = 'mongosh --quiet --eval "rs.status().members.forEach(m => print(m.name + \": \" + m.stateStr + \" (health=\" + m.health + \")\"))"'
Invoke-VMCommand -ResourceGroupName $ResourceGroup -VMName $Config.DbVm1Name -Script $rsVerifyScript
Write-LogInfo "Expected: 3 members = 1 PRIMARY + 2 SECONDARY (10.0.3.4 is normally PRIMARY)."

# -----------------------------------------------------------------------------
# Step 7: Verify App Tier Environment Variables
# -----------------------------------------------------------------------------
Write-LogInfo "Step 7: Verifying App tier environment variables..."

try {
    $AppVm1 = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Config.AppVm1Name -ErrorAction Stop
    Write-LogInfo "Checking /etc/environment on App VM..."
    # MONGODB_URI contains the app password; Invoke-VMCommand masks it.
    $envScript = "grep -E 'NODE_ENV|MONGODB_URI|ENTRA' /etc/environment || echo 'Environment variables not found'"
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
Write-LogInfo "Connection string for backend (password masked; Bicep already wrote the real value to MONGODB_URI on the App VMs):"
Write-Host "  mongodb://$($Config.AppUser):***@$RsHosts/blogapp?replicaSet=$($Config.ReplicaSetName)&authSource=blogapp&w=majority"
Write-Host ""
