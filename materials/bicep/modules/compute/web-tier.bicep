// =============================================================================
// Web Tier Module
// =============================================================================
// Purpose: Deploy 2 NGINX reverse proxy VMs across Availability Zones
// Reference: /design/AzureArchitectureDesign.md - Section 2: Compute Resources
//
// Architecture:
//   - 2 VMs: vm-web-az1 (Zone 1), vm-web-az2 (Zone 2)
//   - Application Gateway routes HTTPS traffic to these VMs
//   - NGINX serves static React frontend and proxies to App tier
//   - Stateless design (no session affinity)
//
// Traffic Flow:
//   Internet → Application Gateway (HTTPS) → Web Tier (HTTP/NGINX) → App Tier
//
// VM Sizing Rationale (B2s):
//   - 2 vCPU, 4 GB RAM
//   - 60% CPU baseline with burst capability
//   - Perfect for NGINX reverse proxy workload
//   - Cost-effective: $0.042/hr (saves 35% vs D2s_v5)
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the Web tier subnet')
param subnetId string

@description('Resource ID of the Load Balancer backend pool (optional - not used with Application Gateway)')
param loadBalancerBackendPoolId string = ''

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for authentication')
@secure()
param sshPublicKey string

@description('VM size for web tier')
param vmSize string = 'Standard_B2s'

@description('Enable Azure Monitor Agent')
param enableMonitoring bool = true

@description('Resource ID of Log Analytics workspace')
param logAnalyticsWorkspaceId string = ''

@description('Resource ID of Data Collection Rule')
param dataCollectionRuleId string = ''

@description('Force update tag to trigger CustomScript re-execution (change value to re-run)')
param forceUpdateTag string = ''

@description('Skip VM creation and only update extensions (for re-deployment)')
param skipVmCreation bool = false

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Microsoft Entra ID Parameters (for Frontend Runtime Configuration)
// =============================================================================
// These are injected into /var/www/html/config.json for frontend runtime config
// Reference: /design/FrontendApplicationDesign.md - Runtime Config Pattern
// =============================================================================

@description('Microsoft Entra tenant ID')
param entraTenantId string

@description('Microsoft Entra client ID for backend API')
param entraClientId string

@description('Microsoft Entra client ID for frontend SPA')
param entraFrontendClientId string

// =============================================================================
// Variables
// =============================================================================
var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'web'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// NGINX installation script
// This script:
//   1. Updates apt packages
//   2. Installs NGINX
//   3. Creates a basic health check endpoint
//   4. Configures NGINX as reverse proxy to App tier
//   5. Creates /config.json for frontend runtime configuration
//
// Note: Using loadTextContent() + replace() instead of format() to avoid
// ARM template escaping issues with bash/JSON curly braces
// The script uses __PLACEHOLDER__ syntax for parameter substitution
var nginxInstallScriptRaw = loadTextContent('scripts/nginx-install.sh')
var nginxInstallScript = replace(
  replace(
    replace(
      nginxInstallScriptRaw,
      '__ENTRA_TENANT_ID__', entraTenantId
    ),
    '__ENTRA_FRONTEND_CLIENT_ID__', entraFrontendClientId
  ),
  '__ENTRA_BACKEND_CLIENT_ID__', entraClientId
)

// =============================================================================
// Web Tier VMs
// =============================================================================
// Deploy 2 VMs in different Availability Zones for high availability
// Application Gateway manages backend pool using VM private IPs directly
// =============================================================================

// VM in Availability Zone 1
module vmAz1 'vm.bicep' = {
  name: 'deploy-vm-web-az1'
  params: {
    location: location
    vmName: 'vm-web-az1-${environment}'
    vmSize: vmSize
    availabilityZone: '1'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    loadBalancerBackendPoolId: loadBalancerBackendPoolId
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(nginxInstallScript)
    forceUpdateTag: forceUpdateTag
    skipVmCreation: skipVmCreation
    tags: allTags
  }
}

// VM in Availability Zone 2
module vmAz2 'vm.bicep' = {
  name: 'deploy-vm-web-az2'
  params: {
    location: location
    vmName: 'vm-web-az2-${environment}'
    vmSize: vmSize
    availabilityZone: '2'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    loadBalancerBackendPoolId: loadBalancerBackendPoolId
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(nginxInstallScript)
    forceUpdateTag: forceUpdateTag
    skipVmCreation: skipVmCreation
    tags: allTags
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource IDs of Web tier VMs')
output vmIds array = [
  vmAz1.outputs.vmId
  vmAz2.outputs.vmId
]

@description('Names of Web tier VMs')
output vmNames array = [
  vmAz1.outputs.vmName
  vmAz2.outputs.vmName
]

@description('Private IP addresses of Web tier VMs')
output privateIpAddresses array = [
  vmAz1.outputs.privateIpAddress
  vmAz2.outputs.privateIpAddress
]

@description('Principal IDs of VM managed identities')
output principalIds array = [
  vmAz1.outputs.principalId
  vmAz2.outputs.principalId
]
