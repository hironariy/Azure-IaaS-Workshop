# Bicep Deployment Failure Analysis

| Field | Value |
|-------|-------|
| **Date** | 2025-12-08 |
| **Analyst** | Azure Infrastructure Architect Agent |
| **Input** | `AIdocs/feedback/bicep-draft-deployment-failure.md` |
| **Status** | ✅ Fixes Implemented - Ready for Deployment |

---

## Executive Summary

The deployment of `materials/bicep/main.bicep` failed with **5 deployment errors** affecting 3 distinct categories:

| Category | Affected Deployments | Root Cause | Severity |
|----------|---------------------|------------|----------|
| **Load Balancer Zone Configuration** | `deploy-load-balancer` | Invalid zone specification on frontend with public IP | 🔴 Critical |
| **Bastion DNS Output** | `deploy-bastion` | Missing `dnsSettings` on Bastion public IP | 🟡 Medium |
| **VM Image Reference** | `deploy-app-tier`, `deploy-db-tier` | Ubuntu 24.04 LTS image not available in region | 🔴 Critical |

All issues are **fixable** with targeted Bicep template modifications. No architectural changes required.

---

## Failure Analysis

### Issue 1: Load Balancer Frontend Zone Configuration

**Deployment**: `deploy-load-balancer`

**Error Message**:
```
LoadBalancerFrontendIPConfigCannotHaveZoneWhenReferencingPublicIPAddress
```

**Full Error**:
> Load balancer frontendIPConfiguration has 1 zone specified and is referencing a publicIPAddress. Networking supports zones only for frontendIpconfigurations which reference a subnet.

#### Root Cause Analysis

The `load-balancer.bicep` template has a configuration conflict:

**Current Code** (lines 110-125):
```bicep
frontendIPConfigurations: [
  {
    name: frontendName
    properties: {
      publicIPAddress: {
        id: publicIp.id
      }
    }
    // ❌ PROBLEM: zones specified on frontend with public IP
    zones: [
      '1'
      '2'
      '3'
    ]
  }
]
```

**Why This Fails**:

Azure Load Balancer has a specific constraint:

| Frontend Type | Zone Specification | Allowed? |
|--------------|-------------------|----------|
| Public IP reference | On frontend config | ❌ **NO** |
| Public IP reference | On Public IP resource | ✅ YES |
| Subnet reference (internal LB) | On frontend config | ✅ YES |

When using a public IP address, the **zone-redundancy is inherited from the Public IP**, not specified on the frontend configuration itself.

**Evidence**: The Public IP is already configured correctly as zone-redundant (lines 63-84):
```bicep
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  // ...
  zones: ['1', '2', '3']  // ✅ Correct: zone-redundant public IP
}
```

#### Hypothesis

The template incorrectly duplicates zone specification on both:
1. Public IP resource (correct)
2. Frontend IP configuration (incorrect when using public IP)

This was likely a misunderstanding of how zone-redundancy works for Standard Load Balancers with public frontends.

#### Revision Strategy

**Remove `zones` from frontend IP configuration** since zone-redundancy is inherited from the zone-redundant Public IP:

```bicep
frontendIPConfigurations: [
  {
    name: frontendName
    properties: {
      publicIPAddress: {
        id: publicIp.id
      }
    }
    // ✅ FIXED: No zones here - inherited from Public IP
  }
]
```

**Risk**: None - functionality unchanged, zone-redundancy preserved via Public IP.

---

### Issue 2: Bastion DNS Output Evaluation Failure

**Deployment**: `deploy-bastion`

**Error Message**:
```
DeploymentOutputEvaluationFailed - bastionFqdn
```

**Full Error**:
> The template output 'bastionFqdn' is not valid: The language expression property 'dnsSettings' doesn't exist, available properties are 'provisioningState, resourceGuid, ipAddress, publicIPAddressVersion, publicIPAllocationMethod, idleTimeoutInMinutes, ipTags, ddosSettings'.

#### Root Cause Analysis

The `bastion.bicep` template outputs a DNS FQDN that doesn't exist:

**Current Code** (line 143):
```bicep
@description('DNS name for Bastion')
output bastionFqdn string = publicIp.properties.dnsSettings.?fqdn ?? ''
```

**Why This Fails**:

Looking at the Public IP resource definition in `bastion.bicep` (lines 62-79):
```bicep
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  // ...
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    // ❌ NO dnsSettings configured!
  }
  zones: ['1', '2', '3']
}
```

**Contrast with Load Balancer's Public IP** which DOES have dnsSettings (lines 73-76):
```bicep
dnsSettings: {
  domainNameLabel: '${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
}
```

The Bastion Public IP was created **without** a `dnsSettings` block, but the output tries to reference `dnsSettings.fqdn`.

Even though we use safe-dereference (`?.`), ARM template evaluation occurs **at deployment time**, and the property structure simply doesn't exist on the deployed resource.

#### Hypothesis

The code author likely copied the output pattern from `load-balancer.bicep` (which has dnsSettings) without realizing that `bastion.bicep` doesn't configure DNS for its Public IP.

#### Revision Strategy

**Option A (Recommended): Add dnsSettings to Bastion Public IP**

This provides a useful DNS name for documentation and troubleshooting:

```bicep
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  tags: allTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    // ✅ ADD: DNS settings
    dnsSettings: {
      domainNameLabel: 'bastion-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
  zones: ['1', '2', '3']
}
```

**Option B: Remove the FQDN output**

If DNS name isn't needed for Bastion (users connect via Portal):

```bicep
// Remove this output entirely
// output bastionFqdn string = publicIp.properties.dnsSettings.?fqdn ?? ''
```

**Recommendation**: Option A - Consistency with other public IPs and useful for troubleshooting.

---

### Issue 3: Ubuntu 24.04 LTS Image Not Found

**Deployments**: `deploy-app-tier`, `deploy-db-tier`

**Error Message**:
```
InvalidParameter - imageReference
```

**Full Error**:
> The following list of images referenced from the deployment template are not found: Publisher: Canonical, Offer: 0001-com-ubuntu-server-noble, Sku: 24_04-lts-gen2, Version: latest.

#### Root Cause Analysis

The `vm.bicep` module uses hardcoded Ubuntu 24.04 LTS image reference:

**Current Code** (lines 82-87):
```bicep
var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-noble'
  sku: '24_04-lts-gen2'
  version: 'latest'
}
```

**Why This Fails**:

Ubuntu 24.04 LTS (Noble Numbat) availability varies by Azure region. The image might:

1. **Not be available in the deployment region** (most likely)
2. Have a different offer/SKU naming convention
3. Be recently published and not yet propagated

**Verification Command** (should be run to confirm):
```bash
az vm image list \
  --publisher Canonical \
  --offer "0001-com-ubuntu-server-noble" \
  --sku "24_04-lts-gen2" \
  --location japaneast \
  --all \
  --output table
```

**Alternative - Check available Ubuntu images**:
```bash
az vm image list \
  --publisher Canonical \
  --all \
  --location japaneast \
  --output table | grep -i "noble\|24.04\|24_04"
```

#### Hypothesis

1. **Primary**: Ubuntu 24.04 LTS is not yet available in the target region (likely `japaneast` based on workshop context)
2. **Secondary**: The image naming convention changed between our template creation and deployment

#### Revision Strategy

**Option A (Recommended): Use Ubuntu 22.04 LTS as Fallback**

Ubuntu 22.04 LTS (Jammy Jellyfish) is universally available and will work for the workshop:

```bicep
var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}
```

**Verification**:
```bash
az vm image list \
  --publisher Canonical \
  --offer "0001-com-ubuntu-server-jammy" \
  --sku "22_04-lts-gen2" \
  --location japaneast \
  --all \
  --output table
```

**Option B: Make Image Reference a Parameter**

Allow flexibility for different regions/versions:

```bicep
@description('VM image publisher')
param imagePublisher string = 'Canonical'

@description('VM image offer')
param imageOffer string = '0001-com-ubuntu-server-jammy'

@description('VM image SKU')
param imageSku string = '22_04-lts-gen2'

@description('VM image version')
param imageVersion string = 'latest'

var imageReference = {
  publisher: imagePublisher
  offer: imageOffer
  sku: imageSku
  version: imageVersion
}
```

**Option C: Verify correct 24.04 naming and use if available**

First verify the correct naming:
```bash
az vm image list-offers --publisher Canonical --location japaneast --output table
az vm image list-skus --publisher Canonical --offer "ubuntu-24_04-lts" --location japaneast --output table
```

The offer might be `ubuntu-24_04-lts` instead of `0001-com-ubuntu-server-noble`.

**Recommendation**: Option A with Option B enhancement for production readiness.

---

## Affected Files Summary

| File | Line(s) | Issue | Fix Required |
|------|---------|-------|--------------|
| `modules/network/load-balancer.bicep` | 118-123 | Remove `zones` from frontend config | Required |
| `modules/network/bastion.bicep` | 62-79, 143 | Add `dnsSettings` or remove output | Required |
| `modules/compute/vm.bicep` | 82-87 | Update image reference to 22.04 LTS or parameterize | Required |

---

## Revision Implementation Plan

### Phase 1: Quick Fixes (All Issues)

| Step | File | Change | Estimated Time |
|------|------|--------|----------------|
| 1 | `load-balancer.bicep` | Remove `zones` from frontend IP config | 5 min |
| 2 | `bastion.bicep` | Add `dnsSettings` to Public IP | 5 min |
| 3 | `vm.bicep` | Change image to Ubuntu 22.04 LTS | 5 min |
| 4 | Validate | Run `az bicep build --file main.bicep` | 2 min |
| 5 | Deploy | Test deployment in `rg-workshop-test` | 15-30 min |

### Phase 2: Production Hardening (Recommended)

| Step | File | Change | Benefit |
|------|------|--------|---------|
| 1 | `vm.bicep` | Parameterize image reference | Region flexibility |
| 2 | All modules | Add pre-deployment validation | Catch issues earlier |
| 3 | `README.md` | Document region-specific requirements | User guidance |

---

## Validation Checklist

After implementing fixes, verify:

- [ ] `az bicep build --file main.bicep` completes without errors
- [ ] All Bicep lint warnings resolved
- [ ] Test deployment succeeds in target region
- [ ] All 6 VMs created across Availability Zones
- [ ] Load Balancer health probes pass
- [ ] Bastion connectivity works
- [ ] Azure Monitor Agent reporting metrics

---

## Lessons Learned

### 1. Zone-Redundancy for Public Load Balancers

> **Rule**: For Standard Load Balancers with public frontends, zone-redundancy is specified on the **Public IP resource**, not on the frontend IP configuration.

### 2. Output Dependencies

> **Rule**: Before referencing a property in outputs, ensure the property is actually configured on the resource. Safe-dereference (`?.`) doesn't prevent ARM template evaluation failures.

### 3. Regional Image Availability

> **Rule**: Always verify VM image availability in target regions before hardcoding image references. Consider parameterization for cross-region deployments.

### 4. Pre-Deployment Validation

> **Recommendation**: Use `az deployment group what-if` to preview deployments and catch configuration issues before actual deployment.

```bash
az deployment group what-if \
  --resource-group rg-workshop-test \
  --template-file main.bicep \
  --parameters main.bicepparam
```

---

## References

- [Azure Load Balancer Zone-Redundancy](https://learn.microsoft.com/azure/load-balancer/load-balancer-standard-availability-zones)
- [Azure Public IP Address DNS Settings](https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses#dns-settings)
- [Find Azure VM Images](https://learn.microsoft.com/azure/virtual-machines/linux/cli-ps-findimage)
- [Ubuntu on Azure Marketplace](https://azuremarketplace.microsoft.com/marketplace/apps/canonical.0001-com-ubuntu-server-jammy)
