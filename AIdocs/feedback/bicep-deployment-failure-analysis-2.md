# Bicep Deployment Failure Analysis - Round 2

| Field | Value |
|-------|-------|
| **Date** | 2025-12-08 |
| **Analyst** | Azure Infrastructure Architect Agent |
| **Input** | `AIdocs/feedback/bicep-draft-deployment-failure-2.md` |
| **Previous Fixes** | Load Balancer zones, Bastion DNS, Ubuntu image (Round 1) |
| **Status** | ✅ Fixes Implemented - Ready for Deployment |

---

## Executive Summary

The second deployment attempt failed with **7 deployment errors** affecting 2 distinct categories:

| Category | Affected Deployments | Root Cause | Severity |
|----------|---------------------|------------|----------|
| **CustomScript dpkg Lock** | `deploy-web-tier`, `deploy-db-tier` (4 VMs) | Race condition between Azure Linux Agent and CustomScript | 🔴 Critical |
| **Key Vault Invalid Principal ID** | `deploy-key-vault` | Empty string passed to role assignment | 🟡 Medium |

**Good News**: The Ubuntu 22.04 LTS image fix worked - VMs are being created. The previous fixes (Load Balancer, Bastion) also appear resolved.

---

## Failure Analysis

### Issue 1: CustomScript Extension dpkg Lock Race Condition

**Deployments Affected**: 
- `deploy-vm-web-az1`
- `deploy-vm-db-az1`
- `deploy-vm-db-az2`

**Successful (no CustomScript issues)**:
- `deploy-vm-web-az2`
- `deploy-vm-app-az1`
- `deploy-vm-app-az2`

**Error Message**:
```
E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process 2852 (dpkg)
E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?
```

**Exit Code**: 100 (apt/dpkg error)

#### Root Cause Analysis

This is a well-known **race condition** on Ubuntu VMs in Azure:

1. **Azure Linux Agent (waagent)** starts automatically when VM boots
2. It runs **automatic security updates** via `unattended-upgrades`
3. This holds the dpkg lock (`/var/lib/dpkg/lock-frontend`)
4. **CustomScript Extension** runs **simultaneously** and tries to run `apt-get update`
5. CustomScript fails because dpkg lock is held by another process

**Evidence from Error Logs**:
- The script ran `apt-get update` successfully (42.3 MB fetched)
- Failed when trying to run next apt command
- Lock held by process 2852/2810/2922 (dpkg) - these are different PIDs showing it's the waagent's unattended-upgrades

**Why Some VMs Succeeded**:
- App tier VMs (az1 and az2) succeeded
- Web tier vm-az2 succeeded
- The timing is non-deterministic - some VMs finish waagent updates before CustomScript runs

#### Hypothesis

The CustomScript starts too quickly after VM boot, colliding with Azure Linux Agent's automatic package operations.

#### Revision Strategy

**Option A (Recommended): Add Lock Wait Logic to Scripts**

Modify the installation scripts to wait for dpkg lock before proceeding:

```bash
#!/bin/bash
set -e

# ==========================================================
# Wait for dpkg lock to be released
# ==========================================================
# Azure Linux Agent may be running updates on first boot
# Wait up to 5 minutes for the lock to be released
LOCK_WAIT_TIMEOUT=300
LOCK_WAIT_INTERVAL=10
LOCK_WAIT_ELAPSED=0

echo "Waiting for dpkg lock to be released..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  if [ $LOCK_WAIT_ELAPSED -ge $LOCK_WAIT_TIMEOUT ]; then
    echo "ERROR: Timeout waiting for dpkg lock after ${LOCK_WAIT_TIMEOUT}s"
    exit 1
  fi
  echo "dpkg lock is held, waiting ${LOCK_WAIT_INTERVAL}s... (${LOCK_WAIT_ELAPSED}s elapsed)"
  sleep $LOCK_WAIT_INTERVAL
  LOCK_WAIT_ELAPSED=$((LOCK_WAIT_ELAPSED + LOCK_WAIT_INTERVAL))
done

echo "dpkg lock is available, proceeding with installation..."

# Update packages
apt-get update
apt-get upgrade -y

# ... rest of script
```

**Option B: Use systemd-run with flock**

Use flock to serialize access to apt:

```bash
#!/bin/bash
set -e

# Wait for apt locks and run update
flock --wait 300 /var/lib/dpkg/lock-frontend apt-get update
flock --wait 300 /var/lib/dpkg/lock-frontend apt-get upgrade -y

# ... rest of script
```

**Option C: Remove CustomScript, Use cloud-init Instead**

Use cloud-init's `runcmd` which waits for system boot to complete:

```yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - nginx
runcmd:
  - mkdir -p /var/www/html
  - echo 'OK' > /var/www/html/health
```

However, this requires VM image changes and is more complex to implement in Bicep.

**Option D: Disable Automatic Updates Before Script (Quick Fix)**

```bash
#!/bin/bash
set -e

# Stop unattended-upgrades if running
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true

# Kill any running apt/dpkg processes
pkill -9 apt 2>/dev/null || true
pkill -9 dpkg 2>/dev/null || true

# Wait for locks to be released
sleep 10

# Remove lock files if they exist (use with caution)
rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
rm -f /var/lib/apt/lists/lock 2>/dev/null || true

# Reconfigure dpkg if interrupted
dpkg --configure -a 2>/dev/null || true

# Now proceed with installation
apt-get update
# ...
```

**Recommendation**: **Option A** - Most robust and doesn't interfere with system operations.

---

### Issue 2: Key Vault Invalid Principal ID for Role Assignment

**Deployment**: `deploy-key-vault`

**Error Message**:
```
InvalidPrincipalId: A valid principal ID must be provided for role assignment.
```

#### Root Cause Analysis

Looking at `key-vault.bicep` (lines 117-127):

```bicep
// Grant VMs access to read secrets
resource vmRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, index) in vmPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId  // ❌ Can be empty string if VM creation failed
    principalType: 'ServicePrincipal'
  }
}]
```

The `vmPrincipalIds` array is populated from VM outputs. When VM deployments fail (due to CustomScript errors above), the principal IDs may be:
1. Empty strings
2. Not available because the loop runs before VM identity is created

Looking at `main.bicep`, Key Vault deployment happens **before** VMs are fully deployed, or the `vmPrincipalIds` array contains empty/invalid values.

**Key Vault Re-deployment Issue**:

Looking at `main.bicep`, there's a pattern where Key Vault is deployed twice:

1. First deployment: Initial Key Vault (before VMs)
2. Second deployment (`keyVaultVmAccess`): Update with VM principal IDs

The second deployment fails because some VMs failed, returning empty principal IDs.

#### Hypothesis

1. **Primary**: VM deployments failed, returning empty/null principal IDs
2. **Secondary**: The `vmPrincipalIds` array in `keyVaultVmAccess` module contains empty strings

#### Revision Strategy

**Option A (Recommended by User): Restructure Deployment Order**

The current architecture has a flaw: `keyVaultVmAccess` references VM outputs (`webTier.outputs.principalIds`, etc.) which creates an **implicit dependency**. However:

1. The implicit dependency via `concat(webTier.outputs.principalIds, ...)` should ensure VMs are deployed first
2. The issue is that when VM's CustomScript extension **fails**, the VM itself is **partially deployed** - the VM exists and has a principal ID, but the deployment is marked as failed
3. This causes a cascading failure in `keyVaultVmAccess`

**Better Architecture**: Deploy Key Vault **once** at the end, after ALL VM deployments complete successfully:

**Current Flow** (Problematic):
```
1. deploy-key-vault (initial, no VM access)
2. deploy-web-tier, deploy-app-tier, deploy-db-tier (parallel)
3. update-key-vault-access (uses VM principal IDs) ← FAILS if any VM extension fails
```

**Proposed Flow** (Robust):
```
1. deploy-web-tier, deploy-app-tier, deploy-db-tier (parallel)
2. deploy-key-vault (single deployment, includes VM principal IDs)
```

**Implementation**: Remove the initial `keyVault` deployment and keep only `keyVaultVmAccess`, but ensure it has explicit dependencies on all tier deployments.

**Code Change in `main.bicep`**:

```bicep
// Remove the initial keyVault deployment (Module 6)
// Keep only keyVaultVmAccess, renamed to keyVault

module keyVault 'modules/security/key-vault.bicep' = if (deployKeyVault) {
  name: 'deploy-key-vault'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    adminObjectId: adminObjectId
    vmPrincipalIds: concat(
      webTier.outputs.principalIds,
      appTier.outputs.principalIds,
      dbTier.outputs.principalIds
    )
    enableSoftDelete: environment == 'prod'
    tags: allTags
  }
  // Explicit dependencies ensure all VMs are fully deployed before Key Vault
  dependsOn: [
    webTier
    appTier
    dbTier
  ]
}
```

**Why This Works**:
- Key Vault is deployed **after** all VMs succeed
- If any VM fails, Key Vault deployment doesn't start (no cascading errors)
- Cleaner architecture with single Key Vault deployment

**Option B: Filter Out Empty Principal IDs (Defensive Fallback)**

Even with Option A, we should keep this as defensive programming:

Modify `key-vault.bicep` to skip empty principal IDs:

```bicep
// Filter out empty principal IDs
var validPrincipalIds = filter(vmPrincipalIds, id => !empty(id))

// Grant VMs access to read secrets (only for valid principals)
resource vmRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, index) in validPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
```

**Option B: Add Condition to Role Assignment Loop**

```bicep
resource vmRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, index) in vmPrincipalIds: if (!empty(principalId)) {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
```

**Option C: Don't Deploy Key Vault VM Access Until VMs Succeed**

Separate the Key Vault role assignments into a post-deployment step.

**Recommendation**: **Option A** - Uses Bicep's `filter()` function to clean the array before iteration.

---

## Affected Files Summary

| File | Lines | Issue | Fix Required |
|------|-------|-------|--------------|
| `modules/compute/web-tier.bicep` | 75-127 (nginxInstallScript) | Add dpkg lock wait | Required |
| `modules/compute/db-tier.bicep` | 87-222 (mongoInstallScript) | Add dpkg lock wait | Required |
| `modules/compute/app-tier.bicep` | Similar location | Add dpkg lock wait | Recommended |
| `modules/security/key-vault.bicep` | 117-127 | Filter empty principal IDs | Required |
| `main.bicep` | 232-248, 344-362 | Remove duplicate Key Vault, add explicit dependsOn | Required |

---

## Revision Implementation Plan

### Phase 1: Fix CustomScript Lock Issues

| Step | File | Change | Estimated Time |
|------|------|--------|----------------|
| 1 | `web-tier.bicep` | Add dpkg lock wait to nginxInstallScript | 5 min |
| 2 | `db-tier.bicep` | Add dpkg lock wait to mongoInstallScript | 5 min |
| 3 | `app-tier.bicep` | Add dpkg lock wait to nodeInstallScript | 5 min |

### Phase 2: Fix Key Vault Deployment Architecture

| Step | File | Change | Estimated Time |
|------|------|--------|----------------|
| 1 | `main.bicep` | Remove initial `keyVault` module (Module 6) | 3 min |
| 2 | `main.bicep` | Add explicit `dependsOn` to `keyVaultVmAccess` for webTier, appTier, dbTier | 3 min |
| 3 | `main.bicep` | Rename `keyVaultVmAccess` to `keyVault` for clarity | 2 min |
| 4 | `key-vault.bicep` | Add filter for empty principal IDs (defensive) | 5 min |

### Phase 3: Validate and Deploy

| Step | Action | Estimated Time |
|------|--------|----------------|
| 1 | Run `az bicep build --file main.bicep` | 2 min |
| 2 | Delete failed resources in `rg-workshop-test` | 5 min |
| 3 | Redeploy with fixes | 15-30 min |

---

## Lock Wait Script Template

To be added at the beginning of all installation scripts:

```bash
#!/bin/bash
set -e

# ==========================================================
# Wait for dpkg/apt locks to be released
# ==========================================================
# Azure Linux Agent may be running unattended-upgrades on first boot
# This can hold dpkg lock for 1-5 minutes
# We wait up to 5 minutes for the lock to be released
# ==========================================================

wait_for_apt_lock() {
  local timeout=300
  local interval=10
  local elapsed=0
  
  echo "Checking for dpkg/apt locks..."
  
  while true; do
    # Check if any apt/dpkg processes are running
    if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
       ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
       ! fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
      echo "All apt/dpkg locks are free, proceeding..."
      return 0
    fi
    
    if [ $elapsed -ge $timeout ]; then
      echo "ERROR: Timeout waiting for apt/dpkg locks after ${timeout}s"
      return 1
    fi
    
    echo "apt/dpkg lock is held, waiting ${interval}s... (${elapsed}s elapsed)"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
}

# Execute wait function
wait_for_apt_lock

# ==========================================================
# Now safe to run apt commands
# ==========================================================
apt-get update
apt-get upgrade -y

# ... rest of script continues here
```

---

## Validation Checklist

After implementing fixes, verify:

- [ ] `az bicep build --file main.bicep` completes without errors
- [ ] All 6 VMs created successfully
- [ ] CustomScript extensions complete without errors
- [ ] NGINX installed and running on web tier VMs
- [ ] MongoDB installed and running on db tier VMs
- [ ] Node.js installed on app tier VMs
- [ ] Key Vault role assignments created (for successful VMs)
- [ ] Azure Monitor Agent reporting metrics

---

## Lessons Learned

### 1. Azure Linux Agent Race Condition

> **Rule**: Ubuntu VMs in Azure run `unattended-upgrades` on first boot. CustomScript extensions that use `apt-get` must wait for the dpkg lock to be released.

**Best Practice**: Always add lock-wait logic to any script that uses apt/dpkg:
```bash
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  sleep 10
done
```

### 2. Defensive Array Filtering in Bicep

> **Rule**: When iterating over arrays that may contain empty values (especially from conditional module outputs), filter the array first.

**Best Practice**: Use Bicep's `filter()` function:
```bicep
var validIds = filter(maybeEmptyArray, id => !empty(id))
```

### 3. Extension Ordering and Dependencies

> **Rule**: VM extensions can have complex interactions. Order matters:
> 1. VM creation
> 2. Azure Monitor Agent
> 3. CustomScript (waits for AMA via `dependsOn`)

The current design correctly orders AMA before CustomScript, but doesn't account for waagent's unattended-upgrades.

---

## Root Cause Correlation

| Issue | Actual Root Cause | Why Previous Analysis Missed It |
|-------|------------------|--------------------------------|
| VM Image Error | Fixed ✅ | N/A - correctly identified |
| dpkg Lock | Azure Linux Agent timing | Not visible in Bicep - OS-level issue |
| Key Vault Principal | Cascading failure from VM errors | Secondary effect of primary failure |

**Key Insight**: Once VM CustomScript failures are fixed, the Key Vault issue may self-resolve (VMs will have valid principal IDs). However, we should still add the filter as defensive programming.

---

## References

- [Azure VM Extension Troubleshooting](https://aka.ms/VMExtensionCSELinuxTroubleshoot)
- [CustomScript Extension for Linux](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux)
- [Handling apt lock in scripts](https://askubuntu.com/questions/15433/unable-to-lock-the-administration-directory-var-lib-dpkg-is-another-process)
- [Bicep filter function](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-lambda#filter)
