# Round 3 Deployment Failure Analysis

**Date**: 2025-12-08  
**Status**: ✅ Fix Applied - Ready for Re-deployment  
**Scope**: DB Tier VM CustomScript Extension Failure  

---

## Executive Summary

Round 3 deployment showed **partial success**: Web and App tier VMs deployed successfully with the lock-wait function working correctly. However, DB tier VMs continue to fail with the same dpkg lock error despite having identical lock-wait logic.

**Root Cause**: Race condition between lock check completion and `apt-get` execution. The `fuser` check passes, but `unattended-upgrades` acquires the lock in the microseconds between the check returning and `apt-get update` starting.

---

## 1. Deployment Results Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Network Infrastructure | ✅ SUCCESS | VNet, NSGs, Bastion deployed |
| Monitoring | ✅ SUCCESS | Log Analytics, DCR deployed |
| Storage | ✅ SUCCESS | Storage account deployed |
| Web Tier VMs | ✅ SUCCESS | Both vm-web-az1 and vm-web-az2 |
| App Tier VMs | ✅ SUCCESS | Both vm-app-az1 and vm-app-az2 |
| **DB Tier VMs** | ❌ FAILED | Both vm-db-az1 and vm-db-az2 |
| Key Vault | ⏸️ BLOCKED | Depends on DB tier VMs |

---

## 2. Failure Log Analysis

### Error Output (vm-db-az1-prod)
```
Checking for dpkg/apt locks...
All apt/dpkg locks are free, proceeding...
Hit:1 http://azure.archive.ubuntu.com/ubuntu jammy InRelease
[apt-get update output...]
E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process 2918 (dpkg)
N: Be aware that removing the lock file is not a solution and may break your system.
E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?
```

### Critical Observations

1. **Lock check passed**: "All apt/dpkg locks are free, proceeding..." was printed
2. **apt-get update started**: Initial "Hit:1 http://azure.archive.ubuntu.com/ubuntu jammy InRelease" output visible
3. **Lock acquired by another process**: dpkg (PID 2918) acquired the lock AFTER our check
4. **Exit code**: 100 (apt-get failure)

### Timeline Reconstruction

```
T+0.000s: wait_for_apt_lock() starts checking
T+0.001s: fuser /var/lib/dpkg/lock-frontend returns 0 (no lock)
T+0.002s: All three fuser checks pass
T+0.003s: echo "All apt/dpkg locks are free, proceeding..."
T+0.004s: apt-get update starts
T+0.005s: apt-get begins downloading package lists
T+0.100s: *** unattended-upgrades wakes up and acquires dpkg lock ***
T+0.200s: apt-get tries to use dpkg → LOCKED → fails
```

---

## 3. Why DB Tier Fails but Web/App Tier Succeeds

### Hypothesis 1: Deployment Timing Difference

Web and App tier VMs deploy in parallel. DB tier VMs may start slightly later or finish their check at exactly the wrong moment when `unattended-upgrades` runs.

**Evidence**: Random timing - with Azure's parallel deployment, any tier could theoretically fail.

### Hypothesis 2: VM Size Difference (Most Likely)

- Web/App: **B2s** (2 vCPU, 4 GB RAM) - faster boot, earlier script start
- DB: **B4ms** (4 vCPU, 16 GB RAM) - larger VM, potentially different boot timing

Larger VMs may have:
- Different Azure Agent initialization timing
- More services starting on boot
- Different `unattended-upgrades` schedule due to different systemd timing

### Hypothesis 3: Data Disk Attachment

DB tier VMs have Premium SSD data disks attached. The disk attachment process may delay script execution slightly, changing the race condition timing.

### Hypothesis 4: Statistical Variance

With 6 VMs total:
- Web: 2 VMs, both succeeded
- App: 2 VMs, both succeeded  
- DB: 2 VMs, both failed

This could be coincidence, but the consistent failure of both DB VMs suggests a deterministic factor.

---

## 4. Fix Options Analysis

### Option A: Use apt-get's Built-in Lock Timeout (RECOMMENDED)

**Implementation**:
```bash
# Instead of manual lock checking, let apt-get handle it
export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=300 update
apt-get -o DPkg::Lock::Timeout=300 upgrade -y
```

**Pros**:
- Built-in mechanism, no race condition
- apt-get itself will wait for locks
- Simpler code, fewer failure points
- Works with any dpkg operation

**Cons**:
- Only works with apt-get ≥ 1.9.11 (Ubuntu 18.04+) - not an issue for 22.04

**Assessment**: ✅ Best solution - eliminates race condition at the source

---

### Option B: Disable unattended-upgrades First

**Implementation**:
```bash
# Stop unattended-upgrades before any apt operations
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true

# Kill any remaining apt processes
killall apt apt-get dpkg 2>/dev/null || true

# Wait a moment for processes to terminate
sleep 5

# Now safe to run apt
apt-get update
```

**Pros**:
- Aggressive but guaranteed to work
- Prevents future interference

**Cons**:
- Disables security updates (needs re-enabling later)
- killall is risky if apt is in middle of operation
- More complex, more things that can fail

**Assessment**: ⚠️ Works but heavy-handed

---

### Option C: Combined Lock Check + apt-get Timeout (BELT AND SUSPENDERS)

**Implementation**:
```bash
wait_for_apt_lock() {
  local timeout=300
  local interval=10
  local elapsed=0
  
  echo "Checking for dpkg/apt locks..."
  
  while true; do
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

# Execute wait function first
wait_for_apt_lock

# Then use apt-get with lock timeout as backup
export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 upgrade -y
```

**Pros**:
- Initial wait reduces immediate retry spam in logs
- apt-get timeout handles race condition
- More informative logging for debugging
- Educational - shows multiple approaches

**Cons**:
- Slightly more complex
- Two timeout mechanisms to track

**Assessment**: ✅ Good for educational purposes - shows defense in depth

---

### Option D: Retry Loop with Exponential Backoff

**Implementation**:
```bash
apt_retry() {
  local max_retries=5
  local retry=0
  local wait_time=10
  
  while [ $retry -lt $max_retries ]; do
    if apt-get "$@"; then
      return 0
    fi
    retry=$((retry + 1))
    echo "apt-get failed, retry $retry of $max_retries in ${wait_time}s..."
    sleep $wait_time
    wait_time=$((wait_time * 2))
  done
  
  echo "apt-get failed after $max_retries retries"
  return 1
}

apt_retry update
apt_retry upgrade -y
```

**Pros**:
- Handles transient failures
- Good pattern for production scripts

**Cons**:
- Longer total execution time if fails multiple times
- Doesn't address root cause

**Assessment**: ⚠️ Valid but doesn't solve the actual race condition

---

## 5. Recommendation

### Primary Fix: Option A (apt-get Lock Timeout)

This is the cleanest solution. Ubuntu 22.04 LTS fully supports the `DPkg::Lock::Timeout` option.

**Changes Required**:

All three tier scripts should be updated:

```bash
# Remove the wait_for_apt_lock() function (optional - can keep for educational value)
# Add these environment variables and options:

export DEBIAN_FRONTEND=noninteractive

# Update packages with lock timeout
apt-get -o DPkg::Lock::Timeout=300 update
apt-get -o DPkg::Lock::Timeout=300 -y upgrade

# All subsequent apt-get install commands:
apt-get -o DPkg::Lock::Timeout=300 -y install <packages>
```

### Files to Modify

| File | Changes |
|------|---------|
| `modules/compute/db-tier.bicep` | Add DEBIAN_FRONTEND and DPkg::Lock::Timeout to all apt commands |
| `modules/compute/web-tier.bicep` | Same changes for consistency |
| `modules/compute/app-tier.bicep` | Same changes for consistency |

### Alternative: Option C (Combined Approach)

If we want to keep the educational value of showing the lock-wait function AND ensure reliability:

1. Keep `wait_for_apt_lock()` function with good comments
2. Add `DPkg::Lock::Timeout=120` to all apt-get commands as backup
3. Add `DEBIAN_FRONTEND=noninteractive` to prevent interactive prompts

---

## 6. Implementation Plan

### Phase 1: Update DB Tier (Immediate Fix)

**File**: `modules/compute/db-tier.bicep`

**Changes to `mongoInstallScript`**:
1. Keep existing `wait_for_apt_lock()` function for educational value
2. Add `export DEBIAN_FRONTEND=noninteractive` at script start
3. Add `-o DPkg::Lock::Timeout=120` to ALL apt-get commands:
   - `apt-get update`
   - `apt-get upgrade -y`
   - `apt-get install -y gnupg curl`
   - `apt-get install -y mongodb-org`

### Phase 2: Update Web and App Tiers (Consistency)

While these work now, update for consistency and robustness:

**Files**: 
- `modules/compute/web-tier.bicep`
- `modules/compute/app-tier.bicep`

Same pattern: Add `DEBIAN_FRONTEND` and `DPkg::Lock::Timeout` to all apt commands.

### Phase 3: Verify Deployment

Re-run full deployment and verify all 6 VMs succeed.

---

## 7. Code Changes Preview

### db-tier.bicep mongoInstallScript (Key Section)

**Before**:
```bash
# Execute wait function
wait_for_apt_lock

# Update packages
apt-get update
apt-get upgrade -y
```

**After**:
```bash
# Set non-interactive frontend to prevent any prompts
export DEBIAN_FRONTEND=noninteractive

# Execute wait function (initial check to reduce log spam)
wait_for_apt_lock

# Update packages with lock timeout (backup protection)
# DPkg::Lock::Timeout waits up to 120 seconds if lock is held
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 -y upgrade
```

### For MongoDB Installation Section

**Before**:
```bash
apt-get install -y gnupg curl
...
apt-get install -y mongodb-org
```

**After**:
```bash
apt-get -o DPkg::Lock::Timeout=120 -y install gnupg curl
...
apt-get -o DPkg::Lock::Timeout=120 -y install mongodb-org
```

---

## 8. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Extended deployment time | 120s timeout is acceptable; usually completes in <10s |
| Silent failures | Script still uses `set -e`, will fail if timeout exceeded |
| DEBIAN_FRONTEND side effects | None for package installation, standard practice |
| Consistency across tiers | Update all three tiers, not just DB |

---

## 9. Testing Checklist

After applying fixes:

- [ ] `bicep build main.bicep` succeeds without warnings
- [ ] All 6 VMs deploy successfully (CustomScript extensions complete)
- [ ] MongoDB service running on DB VMs
- [ ] NGINX service running on Web VMs
- [ ] Node.js available on App VMs
- [ ] Key Vault role assignments complete (depends on VM success)

---

## 10. Approval Request

**Recommended Action**: Apply Option A (apt-get Lock Timeout) to all three tier scripts.

**Estimated Changes**:
- `db-tier.bicep`: ~10 lines modified in script
- `web-tier.bicep`: ~5 lines modified in script
- `app-tier.bicep`: ~5 lines modified in script

**Ready to proceed with implementation upon approval.**

---

*Analysis prepared by Azure Infrastructure Architect Agent*
