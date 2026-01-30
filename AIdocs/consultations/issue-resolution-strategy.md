# Issue Resolution Strategy

**Created:** January 30, 2026  
**Total Issues:** 19 (1 bug, 1 enhancement, 17 documentation)

---

## Executive Summary

All 19 issues have been categorized and prioritized based on:
1. **Blocking Impact** - Does it prevent workshop completion?
2. **User Experience** - How confusing/frustrating is it?
3. **Dependencies** - Does it need to be resolved before other issues?
4. **Scope of Change** - How many files/systems are affected?

### Issue Distribution

| Category | Count | Issues |
|----------|-------|--------|
| **Bug** | 1 | #1 |
| **Enhancement** | 1 | #2 |
| **Documentation (README)** | 12 | #3-15, #19 |
| **Documentation (deployment-strategy)** | 2 | #18 |
| **Infrastructure + Documentation** | 2 | #16, #17 |

---

## Priority Tiers

### 🔴 Tier 1: Critical (Blocks Workshop Completion)

These must be resolved first as they prevent users from completing the workshop.

| # | Issue | Impact | Affected Files |
|---|-------|--------|----------------|
| **#1** | MongoDB password sync gap | App won't connect to DB | Bicep + scripts |
| **#10** | Wrong `cd scripts` path in Step 6 | Users can't find script | README.md, README.ja.md |
| **#16** | NSG priority conflict in Test 8 | Test fails with Azure error | Bicep + README |

### 🟠 Tier 2: High (Significant User Confusion)

These cause significant confusion or require users to troubleshoot independently.

| # | Issue | Impact | Affected Files |
|---|-------|--------|----------------|
| **#4** | Azure PowerShell installation notes | Users stuck on install | README.md, README.ja.md |
| **#5** | Az module verification command | Can't verify installation | README.md, README.ja.md |
| **#13** | curl.exe for Windows | Step 10 fails on Windows | README.md, README.ja.md |
| **#14** | Windows syntax for Resiliency Tests | All 8 tests fail on Windows | README.md, README.ja.md |
| **#15** | Azure CLI extensions for Bastion | SSH commands fail | README.md, README.ja.md |
| **#19** | PowerShell 7+ required for -SkipCertificateCheck | HTTPS verification fails | deployment-strategy.md |

### 🟡 Tier 3: Medium (Improves Clarity)

These improve user experience but don't block progress.

| # | Issue | Impact | Affected Files |
|---|-------|--------|----------------|
| **#3** | VM size availability guide | Deployment may fail in some regions | README.md, README.ja.md |
| **#6** | Placeholder naming consistency | Confusing mapping | README.md, README.ja.md |
| **#7** | Terminal commands for file editing | Minor inconvenience | README.md, README.ja.md |
| **#8** | Tenant option for multi-tenant users | Some users can't login | README.md, README.ja.md |
| **#9** | Deployment progress monitoring | Users unsure if working | README.md, README.ja.md |
| **#11** | Microsoft Graph install time warning | Unexpected wait | README.md, README.ja.md |
| **#12** | Warning before Cleanup section | Users may delete resources | README.md, README.ja.md |
| **#18** | Enhanced health check verification | Harder to troubleshoot | deployment-strategy.md |

### 🟢 Tier 4: Low (Nice to Have / Future Enhancement)

These are improvements for future workshop iterations.

| # | Issue | Impact | Affected Files |
|---|-------|--------|----------------|
| **#2** | Group identifier naming convention | Multi-group workshops | Bicep + README |
| **#17** | NSG stateful behavior explanation | Test 8 educational | README.md, README.ja.md |

---

## Recommended Resolution Order

### Phase 1: Critical Fixes (Day 1)

**Goal:** Ensure workshop can be completed end-to-end

```
#1  → MongoDB password synchronization
#10 → Fix cd scripts path
#16 → NSG priority restructuring (requires Bicep change)
```

**Dependencies:**
- #1 is standalone (Bicep + scripts)
- #10 is standalone (documentation only)
- #16 must be done before #17 (Test 8 must work before explaining stateful behavior)

### Phase 2: Windows Compatibility (Day 1-2)

**Goal:** Full Windows 11 support

```
#4  → Azure PowerShell installation notes
#5  → Az module verification (add alternative commands)
#13 → curl.exe for Step 10
#14 → Windows syntax for all 8 Resiliency Tests
#15 → Azure CLI extension installation
#19 → PowerShell version note for -SkipCertificateCheck
```

**Efficiency:** Issues #4, #5, #13, #14, #15, #19 can be batched into a single PR since they all modify the same files (README.md, README.ja.md) for Windows compatibility.

### Phase 3: User Experience Improvements (Day 2-3)

**Goal:** Reduce confusion and support calls

```
#6  → Placeholder naming consistency
#7  → Terminal commands for file editing
#8  → Tenant option for multi-tenant users
#9  → Deployment progress monitoring
#11 → Microsoft Graph install time warning
#12 → Warning before Cleanup section
```

**Efficiency:** All these modify README.md and README.ja.md, can be done in 1-2 PRs.

### Phase 4: Deployment Strategy Doc (Day 3)

**Goal:** Improve troubleshooting guidance

```
#18 → Enhanced health check verification
#19 → (already done in Phase 2 if deployment-strategy.md also affected)
```

### Phase 5: Future Enhancements (Backlog)

**Goal:** Prepare for scaled workshops

```
#2  → Group identifier naming convention
#17 → NSG stateful behavior explanation (after #16 is done)
#3  → VM size availability guide (can be done anytime)
```

---

## Implementation Details

### Issue #1: MongoDB Password Sync

**Complexity:** Medium  
**Files:**
- `materials/bicep/modules/compute/app-tier.bicep`
- `materials/bicep/main.bicep` (add parameter)
- `scripts/post-deployment-setup.template.sh`
- `scripts/post-deployment-setup.template.ps1`

**Approach:**
1. Add `mongoDbAppPassword` parameter to Bicep
2. Remove hardcoded password from app-tier.bicep
3. Update post-deployment scripts to use same parameter source
4. Document in README that password must match

### Issue #16: NSG Priority Restructuring

**Complexity:** Medium  
**Files:**
- `materials/bicep/modules/network/nsg-app.bicep`
- `materials/bicep/modules/network/nsg-web.bicep` (if needed)
- `materials/bicep/modules/network/nsg-db.bicep` (if needed)
- `README.md` (Test 8 section)
- `README.ja.md`

**Approach:**
1. Shift all Outbound rules in nsg-app.bicep from 100/200/300 to 200/300/400
2. Reserve 100-199 for test/override rules
3. Update Test 8 to use priority 100 (now valid)
4. Add educational note about priority planning

### Issue #14: Windows Syntax for Resiliency Tests

**Complexity:** High (8 tests to update)  
**Files:**
- `README.md` (Section 3.1, all 8 tests)
- `README.ja.md`

**Approach:** Add collapsible sections for each test:
```markdown
<details>
<summary>🪟 Windows PowerShell Syntax</summary>
... PowerShell equivalent ...
</details>
```

**Or** Add a separate "Windows PowerShell Commands" subsection after each test.

---

## Effort Estimates

| Phase | Issues | Effort | PRs |
|-------|--------|--------|-----|
| Phase 1 | #1, #10, #16 | 4-6 hours | 2-3 |
| Phase 2 | #4, #5, #13, #14, #15, #19 | 4-6 hours | 1-2 |
| Phase 3 | #6, #7, #8, #9, #11, #12 | 3-4 hours | 1-2 |
| Phase 4 | #18 | 1-2 hours | 1 |
| Phase 5 | #2, #3, #17 | 3-4 hours | 2-3 |
| **Total** | **19 issues** | **15-22 hours** | **7-11 PRs** |

---

## Quick Wins (Can Be Done Immediately)

These are simple text changes that don't require code changes:

1. **#10** - Fix `cd scripts` → `cd ../../scripts` (5 min)
2. **#11** - Add time warning for Microsoft Graph (5 min)
3. **#12** - Add warning before Cleanup (5 min)
4. **#7** - Add `notepad`/`code` commands (10 min)
5. **#8** - Add `--tenant` option (10 min)

**Total Quick Wins:** ~35 min for 5 issues

---

## Next Steps

1. **Immediate:** Start with Phase 1 critical fixes
2. **Today:** Complete Phase 2 Windows compatibility
3. **Tomorrow:** Finish Phases 3-4
4. **Backlog:** Schedule Phase 5 for next sprint

Would you like me to start implementing any specific issue or phase?
