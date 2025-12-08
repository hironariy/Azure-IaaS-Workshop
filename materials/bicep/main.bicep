// =============================================================================
// Main Bicep Template - Azure IaaS Workshop Infrastructure
// =============================================================================
// Purpose: Orchestrate deployment of all infrastructure components
// Reference: /design/AzureArchitectureDesign.md
//
// Deployment Order (managed by Bicep dependency resolution):
//   1. Monitoring (Log Analytics, Data Collection Rule)
//   2. Security (Key Vault)
//   3. Storage (Storage Account)
//   4. Network (NSGs → VNet → Bastion, Load Balancer)
//   5. Compute (Web tier → App tier → DB tier)
//
// Usage:
//   az deployment group create \
//     --resource-group rg-blogapp-prod \
//     --template-file main.bicep \
//     --parameters main.bicepparam
//
// Estimated Deployment Time: 15-30 minutes
// Estimated Cost: ~$45 per student for 48-hour workshop
// =============================================================================

// =============================================================================
// Target Scope
// =============================================================================
targetScope = 'resourceGroup'

// =============================================================================
// Parameters
// =============================================================================

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Admin username for all VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for VM authentication')
@secure()
param sshPublicKey string

@description('Object ID of the admin user for Key Vault access')
param adminObjectId string

@description('Deploy Azure Bastion (set to false to reduce costs during development)')
param deployBastion bool = true

@description('Deploy Monitoring resources (Log Analytics, DCR)')
param deployMonitoring bool = true

@description('Deploy Key Vault for secrets management')
param deployKeyVault bool = true

@description('Deploy Storage Account for static assets')
param deployStorage bool = true

@description('VM size for Web tier')
param webVmSize string = 'Standard_B2s'

@description('VM size for App tier')
param appVmSize string = 'Standard_B2s'

@description('VM size for DB tier')
param dbVmSize string = 'Standard_B4ms'

@description('MongoDB data disk size in GB')
param dbDataDiskSizeGB int = 128

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
var defaultTags = {
  Environment: environment
  Workload: workloadName
  Owner: 'Workshop'
  CostCenter: 'Training'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// Subnet CIDRs
var vnetAddressPrefix = '10.0.0.0/16'
var webSubnetPrefix = '10.0.1.0/24'
var appSubnetPrefix = '10.0.2.0/24'
var dbSubnetPrefix = '10.0.3.0/24'
var bastionSubnetPrefix = '10.0.255.0/26'

// =============================================================================
// Module 1: Monitoring (Log Analytics + Data Collection Rule)
// =============================================================================
// Deploy first - VMs need this for Azure Monitor Agent
// =============================================================================

module logAnalytics 'modules/monitoring/log-analytics.bicep' = if (deployMonitoring) {
  name: 'deploy-log-analytics'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    retentionInDays: 30
    tags: allTags
  }
}

module dataCollectionRule 'modules/monitoring/data-collection-rule.bicep' = if (deployMonitoring) {
  name: 'deploy-dcr'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    // Use safe-dereference even for co-conditional modules (Bicep linter requirement)
    logAnalyticsWorkspaceId: logAnalytics.?outputs.?workspaceId ?? ''
    tags: allTags
  }
}

// =============================================================================
// Module 2: Network Security Groups
// =============================================================================
// Deploy before VNet (VNet references NSG IDs)
// =============================================================================

module nsgWeb 'modules/network/nsg-web.bicep' = {
  name: 'deploy-nsg-web'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    bastionSubnetPrefix: bastionSubnetPrefix
    tags: allTags
  }
}

module nsgApp 'modules/network/nsg-app.bicep' = {
  name: 'deploy-nsg-app'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    webSubnetPrefix: webSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    tags: allTags
  }
}

module nsgDb 'modules/network/nsg-db.bicep' = {
  name: 'deploy-nsg-db'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    appSubnetPrefix: appSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    tags: allTags
  }
}

// =============================================================================
// Module 3: Virtual Network
// =============================================================================
// VNet with 4 subnets, NSGs attached
// =============================================================================

module vnet 'modules/network/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    vnetAddressPrefix: vnetAddressPrefix
    webSubnetPrefix: webSubnetPrefix
    appSubnetPrefix: appSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    webNsgId: nsgWeb.outputs.nsgId
    appNsgId: nsgApp.outputs.nsgId
    dbNsgId: nsgDb.outputs.nsgId
    tags: allTags
  }
}

// =============================================================================
// Module 4: Azure Bastion
// =============================================================================
// Secure SSH access without public IPs on VMs
// Standard SKU enables native client support (SSH from local terminal)
// =============================================================================

module bastion 'modules/network/bastion.bicep' = if (deployBastion) {
  name: 'deploy-bastion'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    bastionSubnetId: vnet.outputs.bastionSubnetId
    bastionSku: 'Standard'  // Standard enables native client, file copy, IP connect
    tags: allTags
  }
}

// =============================================================================
// Module 5: Load Balancer (Web Tier - External)
// =============================================================================
// Standard Load Balancer for Web tier (public-facing)
// =============================================================================

module loadBalancer 'modules/network/load-balancer.bicep' = {
  name: 'deploy-load-balancer'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    tags: allTags
  }
}

// =============================================================================
// Module 5b: Internal Load Balancer (App Tier)
// =============================================================================
// Internal Load Balancer for App tier
// Prepares architecture for future VMSS auto-scaling migration
// NGINX (Web tier) → ILB → App tier VMs
// =============================================================================

module internalLoadBalancer 'modules/network/internal-load-balancer.bicep' = {
  name: 'deploy-internal-load-balancer'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    subnetId: vnet.outputs.appSubnetId
    frontendPrivateIp: '10.0.2.10'  // Static IP within App subnet
    tags: allTags
  }
}

// =============================================================================
// Module 6: Key Vault
// =============================================================================
// Key Vault is now deployed AFTER all VMs (see Module 11)
// This ensures VM principal IDs are available for role assignments
// =============================================================================

// =============================================================================
// Module 7: Storage Account
// =============================================================================
// Blob storage for static assets
// =============================================================================

module storageAccount 'modules/storage/storage-account.bicep' = if (deployStorage) {
  name: 'deploy-storage'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    storageSku: 'Standard_LRS'
    enableVersioning: false
    enableBlobSoftDelete: true
    tags: allTags
  }
}

// =============================================================================
// Module 8: Web Tier VMs
// =============================================================================
// 2 NGINX VMs across Availability Zones
// =============================================================================

module webTier 'modules/compute/web-tier.bicep' = {
  name: 'deploy-web-tier'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    subnetId: vnet.outputs.webSubnetId
    loadBalancerBackendPoolId: loadBalancer.outputs.backendPoolId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    vmSize: webVmSize
    enableMonitoring: deployMonitoring
    logAnalyticsWorkspaceId: logAnalytics.?outputs.?workspaceId ?? ''  // Safe-dereference for conditional module
    dataCollectionRuleId: dataCollectionRule.?outputs.?dcrId ?? ''      // Safe-dereference for conditional module
    tags: allTags
  }
}

// =============================================================================
// Module 9: App Tier VMs
// =============================================================================
// 2 Express/Node.js VMs across Availability Zones
// Connected to Internal Load Balancer (VMSS-ready architecture)
// =============================================================================

module appTier 'modules/compute/app-tier.bicep' = {
  name: 'deploy-app-tier'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    subnetId: vnet.outputs.appSubnetId
    loadBalancerBackendPoolId: internalLoadBalancer.outputs.backendPoolId  // Internal LB
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    vmSize: appVmSize
    enableMonitoring: deployMonitoring
    logAnalyticsWorkspaceId: logAnalytics.?outputs.?workspaceId ?? ''  // Safe-dereference for conditional module
    dataCollectionRuleId: dataCollectionRule.?outputs.?dcrId ?? ''      // Safe-dereference for conditional module
    tags: allTags
  }
}

// =============================================================================
// Module 10: DB Tier VMs
// =============================================================================
// 2 MongoDB VMs across Availability Zones
// =============================================================================

module dbTier 'modules/compute/db-tier.bicep' = {
  name: 'deploy-db-tier'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    subnetId: vnet.outputs.dbSubnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    vmSize: dbVmSize
    dataDiskSizeGB: dbDataDiskSizeGB
    enableMonitoring: deployMonitoring
    logAnalyticsWorkspaceId: logAnalytics.?outputs.?workspaceId ?? ''  // Safe-dereference for conditional module
    dataCollectionRuleId: dataCollectionRule.?outputs.?dcrId ?? ''      // Safe-dereference for conditional module
    tags: allTags
  }
}

// =============================================================================
// Module 11: Key Vault (deployed after all VMs)
// =============================================================================
// Key Vault is deployed AFTER all VMs to ensure:
// 1. All VM principal IDs are available for role assignments
// 2. If any VM fails, Key Vault deployment doesn't start (no cascading errors)
// =============================================================================

module keyVault 'modules/security/key-vault.bicep' = if (deployKeyVault) {
  name: 'deploy-key-vault'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    adminObjectId: adminObjectId
    // Implicit dependencies: Key Vault waits for all VM tiers to complete
    // because we reference their outputs (principalIds) below
    vmPrincipalIds: concat(
      webTier.outputs.principalIds,
      appTier.outputs.principalIds,
      dbTier.outputs.principalIds
    )
    enableSoftDelete: environment == 'prod'
    tags: allTags
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource Group name')
output resourceGroupName string = resourceGroup().name

@description('Load Balancer public IP address')
output loadBalancerPublicIp string = loadBalancer.outputs.publicIpAddress

@description('Load Balancer FQDN')
output loadBalancerFqdn string = loadBalancer.outputs.fqdn

@description('Internal Load Balancer private IP (App tier)')
output internalLoadBalancerIp string = internalLoadBalancer.outputs.frontendPrivateIp

@description('Web tier VM private IPs')
output webTierPrivateIps array = webTier.outputs.privateIpAddresses

@description('App tier VM private IPs')
output appTierPrivateIps array = appTier.outputs.privateIpAddresses

@description('DB tier VM private IPs')
output dbTierPrivateIps array = dbTier.outputs.privateIpAddresses

@description('MongoDB connection string')
output mongoConnectionString string = dbTier.outputs.mongoConnectionString

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.?outputs.?workspaceId ?? ''

@description('Key Vault URI')
output keyVaultUri string = keyVault.?outputs.?keyVaultUri ?? ''

@description('Storage Account Blob Endpoint')
output storageBlobEndpoint string = storageAccount.?outputs.?blobEndpoint ?? ''

@description('Azure Bastion name (for portal access)')
output bastionName string = bastion.?outputs.?bastionName ?? ''

// =============================================================================
// Post-Deployment Instructions
// =============================================================================
// After deployment completes, perform these manual steps:
//
// 1. Connect to DB VMs via Bastion and initialize MongoDB replica set:
//    mongosh --eval "rs.initiate({
//      _id: 'blogapp-rs0',
//      members: [
//        { _id: 0, host: '<db-vm-1-ip>:27017', priority: 2 },
//        { _id: 1, host: '<db-vm-2-ip>:27017', priority: 1 }
//      ]
//    })"
//
// 2. Update NGINX configuration on Web VMs to use Internal LB:
//    upstream backend {
//        server 10.0.2.10:3000;  # Internal LB IP (not individual VM IPs)
//    }
//    Note: Using ILB IP prepares for VMSS auto-scaling migration
//
// 3. Deploy application code to App and Web VMs
//
// 4. Add secrets to Key Vault:
//    az keyvault secret set --vault-name <keyvault-name> \
//      --name "MongoDbConnectionString" \
//      --value "<connection-string>"
// =============================================================================
