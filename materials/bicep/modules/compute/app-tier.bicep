// =============================================================================
// App Tier Module
// =============================================================================
// Purpose: Deploy 2 Express/Node.js API VMs across Availability Zones
// Reference: /design/AzureArchitectureDesign.md - Section 2: Compute Resources
//
// Architecture:
//   - 2 VMs: vm-app-az1 (Zone 1), vm-app-az2 (Zone 2)
//   - Receives traffic from Web tier (NGINX) on port 3000
//   - Connects to DB tier (MongoDB) on port 27017
//   - Stateless design (horizontal scaling ready)
//
// Traffic Flow:
//   Web Tier (NGINX) → App Tier (Express:3000) → DB Tier (MongoDB:27017)
//
// VM Sizing Rationale (B2s):
//   - 2 vCPU, 4 GB RAM
//   - 60% CPU baseline with burst capability
//   - Node.js is single-threaded, 2 vCPU provides overhead for npm, OS
//   - 4 GB RAM sufficient for Express + Mongoose with light load
//   - Cost-effective: $0.042/hr
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the App tier subnet')
param subnetId string

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for authentication')
@secure()
param sshPublicKey string

@description('VM size for app tier')
param vmSize string = 'Standard_B2s'

@description('Enable Azure Monitor Agent')
param enableMonitoring bool = true

@description('Resource ID of Log Analytics workspace')
param logAnalyticsWorkspaceId string = ''

@description('Resource ID of Data Collection Rule')
param dataCollectionRuleId string = ''

@description('Resource ID of Internal Load Balancer backend pool')
param loadBalancerBackendPoolId string = ''

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Microsoft Entra ID Parameters (for Backend API Authentication)
// =============================================================================
// Passed from main.bicep, injected into VMs as environment variables
// Reference: /design/BackendApplicationDesign.md
// =============================================================================

@description('Microsoft Entra tenant ID for backend API authentication')
param entraTenantId string

@description('Microsoft Entra client ID for backend API (registered app)')
param entraClientId string

// =============================================================================
// Variables
// =============================================================================
var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'app'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// MongoDB connection string for production
// Uses blogapp user with credentials created during DB provisioning
// Reference: /design/DatabaseDesign.md - Section 3.4: Authentication & Users
var mongoDbUri = 'mongodb://blogapp:BlogAppUser2024@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=blogapp'

// Node.js 20 LTS installation script
// This script:
//   1. Updates apt packages
//   2. Installs Node.js 20 LTS via NodeSource
//   3. Installs PM2 process manager
//   4. Creates application directory
//   5. Injects production environment variables
//
// Note: Using loadTextContent() + replace() instead of format() to avoid
// ARM template escaping issues with bash/JSON curly braces
// The script uses __PLACEHOLDER__ syntax for parameter substitution
var nodeInstallScriptRaw = loadTextContent('scripts/nodejs-install.sh')
var nodeInstallScript = replace(
  replace(
    replace(
      nodeInstallScriptRaw,
      '__MONGODB_URI__', mongoDbUri
    ),
    '__ENTRA_TENANT_ID__', entraTenantId
  ),
  '__ENTRA_CLIENT_ID__', entraClientId
)

// =============================================================================
// App Tier VMs
// =============================================================================
// Deploy 2 VMs in different Availability Zones for high availability
// No Load Balancer - traffic comes from Web tier VMs directly
// =============================================================================

// VM in Availability Zone 1
module vmAz1 'vm.bicep' = {
  name: 'deploy-vm-app-az1'
  params: {
    location: location
    vmName: 'vm-app-az1-${environment}'
    vmSize: vmSize
    availabilityZone: '1'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    loadBalancerBackendPoolId: loadBalancerBackendPoolId  // Internal LB for App tier
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(nodeInstallScript)
    tags: allTags
  }
}

// VM in Availability Zone 2
module vmAz2 'vm.bicep' = {
  name: 'deploy-vm-app-az2'
  params: {
    location: location
    vmName: 'vm-app-az2-${environment}'
    vmSize: vmSize
    availabilityZone: '2'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    loadBalancerBackendPoolId: loadBalancerBackendPoolId  // Internal LB for App tier
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(nodeInstallScript)
    tags: allTags
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource IDs of App tier VMs')
output vmIds array = [
  vmAz1.outputs.vmId
  vmAz2.outputs.vmId
]

@description('Names of App tier VMs')
output vmNames array = [
  vmAz1.outputs.vmName
  vmAz2.outputs.vmName
]

@description('Private IP addresses of App tier VMs')
output privateIpAddresses array = [
  vmAz1.outputs.privateIpAddress
  vmAz2.outputs.privateIpAddress
]

@description('Principal IDs of VM managed identities')
output principalIds array = [
  vmAz1.outputs.principalId
  vmAz2.outputs.principalId
]
