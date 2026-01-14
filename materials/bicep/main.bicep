// =============================================================================
// Main Bicep Template - Azure IaaS Workshop Infrastructure
// =============================================================================
// Purpose: Orchestrate deployment of all infrastructure components
// Reference: /design/AzureArchitectureDesign.md
//
// Deployment Order (managed by Bicep dependency resolution):
//   1. Monitoring - Log Analytics Workspace (deploys first, needs time for table init)
//   2. Network - NSGs → NAT Gateway → VNet
//   3. Monitoring - Data Collection Rule (after VNet, ensures LA tables are ready)
//   4. Network - Bastion (parallel with VMs, only depends on VNet)
//   5. Network - Application Gateway, Internal Load Balancer
//   6. Storage - Storage Account
//   7. Compute - Web/App/DB tier VMs (parallel deployment possible)
//   8. Security - Key Vault (after all VMs for principal ID access)
//
// Performance Notes:
//   - Bastion deploys in parallel with VMs (no mutual dependency)
//   - DCR deploys after VNet to allow Log Analytics tables to initialize
//
// Usage:
//   az deployment group create \
//     --resource-group rg-blogapp-prod \
//     --template-file main.bicep \
//     --parameters main.bicepparam
//
// Estimated Deployment Time: 15-30 minutes
// Estimated Cost: ~$58 per student for 48-hour workshop (includes Application Gateway)
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

@description('Deploy NAT Gateway for DB tier outbound connectivity')
param deployNatGateway bool = true

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
// Force Update Tags (CustomScript Re-execution Control)
// =============================================================================
// Change these values to force CustomScript extensions to re-run on specific tiers.
// Use timestamp or version string. Empty string = no forced re-run.
// Example: forceUpdateTagWeb='20251217120000' to update only Web tier NGINX config
// =============================================================================

@description('Force update tag for Web tier - changes force NGINX script to re-run')
param forceUpdateTagWeb string = ''

@description('Force update tag for App tier - changes force Node.js script to re-run')
param forceUpdateTagApp string = ''

@description('Force update tag for DB tier - changes force MongoDB script to re-run (rarely needed)')
param forceUpdateTagDb string = ''

// =============================================================================
// Skip VM Creation (Extension-Only Updates)
// =============================================================================
// Set to true when VMs already exist and you only want to update extensions.
// This avoids the "Changing SSH keys not allowed" error on re-deployment.
// =============================================================================

@description('Skip Web tier VM creation - only update extensions on existing VMs')
param skipVmCreationWeb bool = false

@description('Skip App tier VM creation - only update extensions on existing VMs')
param skipVmCreationApp bool = false

@description('Skip DB tier VM creation - only update extensions on existing VMs')
param skipVmCreationDb bool = false

// =============================================================================
// Microsoft Entra ID Parameters (Authentication Configuration)
// =============================================================================
// These are injected into VMs by CustomScript Extension:
// - App tier: Environment variables for backend authentication
// - Web tier: /config.json for frontend runtime configuration
// Reference: /design/AzureArchitectureDesign.md - Bicep Parameter Flow
// =============================================================================

@description('Microsoft Entra tenant ID for authentication')
param entraTenantId string

@description('Microsoft Entra client ID for backend API (registered app)')
param entraClientId string

@description('Microsoft Entra client ID for frontend SPA (registered app)')
param entraFrontendClientId string

// =============================================================================
// Application Gateway SSL Certificate Parameters
// =============================================================================
// For workshop: Self-signed certificate enables HTTPS without custom domain/CA
// Students generate certificate using provided script and encode as base64
// Browser will show certificate warning (expected - students click "Proceed")
// =============================================================================

@description('Self-signed SSL certificate in PFX format (base64 encoded). Leave empty to use HTTP only.')
@secure()
param sslCertificateData string = ''

@description('Password for the PFX certificate. Required if sslCertificateData is provided.')
@secure()
param sslCertificatePassword string = ''

@description('DNS label for Application Gateway public IP (creates <label>.<region>.cloudapp.azure.com)')
param appGatewayDnsLabel string = ''

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
var appGatewaySubnetPrefix = '10.0.0.0/24'
var webSubnetPrefix = '10.0.1.0/24'
var appSubnetPrefix = '10.0.2.0/24'
var dbSubnetPrefix = '10.0.3.0/24'
var bastionSubnetPrefix = '10.0.255.0/26'

// =============================================================================
// Module 1: Monitoring - Log Analytics Workspace
// =============================================================================
// Deploy first - Log Analytics workspace needs time to initialize tables
// before Data Collection Rule can reference them
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
    appGatewaySubnetPrefix: appGatewaySubnetPrefix
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
// Module 2b: NAT Gateway (for DB Tier outbound connectivity)
// =============================================================================
// NAT Gateway v2 provides zone-redundant outbound internet access
// Required for: MongoDB installation, package updates, Azure Monitor
// =============================================================================

module natGateway 'modules/network/nat-gateway.bicep' = if (deployNatGateway) {
  name: 'deploy-nat-gateway'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    idleTimeoutInMinutes: 10
    tags: allTags
  }
}

// =============================================================================
// Module 3: Virtual Network
// =============================================================================
// VNet with 4 subnets, NSGs attached
// NAT Gateway attached to DB subnet for outbound connectivity
// =============================================================================

module vnet 'modules/network/vnet.bicep' = {
  name: 'deploy-vnet'
  // Note: Implicit dependency on natGateway via natGateway.outputs.natGatewayId parameter
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    vnetAddressPrefix: vnetAddressPrefix
    appGatewaySubnetPrefix: appGatewaySubnetPrefix
    webSubnetPrefix: webSubnetPrefix
    appSubnetPrefix: appSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    webNsgId: nsgWeb.outputs.nsgId
    appNsgId: nsgApp.outputs.nsgId
    dbNsgId: nsgDb.outputs.nsgId
    appNatGatewayId: natGateway.?outputs.?natGatewayId ?? ''
    dbNatGatewayId: natGateway.?outputs.?natGatewayId ?? ''
    tags: allTags
  }
}

// =============================================================================
// Module 4: Data Collection Rule (for Azure Monitor Agent)
// =============================================================================
// Deploy after VNet to give Log Analytics workspace time to initialize tables
// (Syslog, Perf tables need ~30-60 seconds to become available after workspace creation)
// VMs deployed later will reference DCR for Azure Monitor Agent configuration
// =============================================================================

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
// Module 5: Azure Bastion
// =============================================================================
// Secure SSH access without public IPs on VMs
// Standard SKU enables native client support (SSH from local terminal)
// Note: Bastion only depends on VNet (bastionSubnetId), not on VMs
//       This allows Bastion and VMs to deploy in parallel for faster deployment
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
// Module 7: Application Gateway (Web Tier - External)
// =============================================================================
// Application Gateway v2 for Web tier (public-facing with SSL/TLS termination)
// Provides Layer 7 load balancing with HTTPS support via self-signed certificate
// =============================================================================

module applicationGateway 'modules/network/application-gateway.bicep' = {
  name: 'deploy-application-gateway'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    tags: allTags
    subnetId: vnet.outputs.appGatewaySubnetId
    webTierPrivateIps: webTier.outputs.privateIpAddresses
    sslCertificateData: sslCertificateData
    sslCertificatePassword: sslCertificatePassword
    dnsLabel: appGatewayDnsLabel
  }
}

// =============================================================================
// Module 7b: Internal Load Balancer (App Tier)
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
// Key Vault Note: Deployed AFTER all VMs (see Module 12)
// This ensures VM principal IDs are available for role assignments
// =============================================================================

// =============================================================================
// Module 8: Storage Account
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
// Module 9: Web Tier VMs
// =============================================================================
// 2 NGINX VMs across Availability Zones
// Application Gateway manages backend pool using VM private IPs
// =============================================================================

module webTier 'modules/compute/web-tier.bicep' = {
  name: 'deploy-web-tier'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    subnetId: vnet.outputs.webSubnetId
    // Note: Application Gateway uses VM private IPs directly (no backendPoolId needed)
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    vmSize: webVmSize
    enableMonitoring: deployMonitoring
    logAnalyticsWorkspaceId: logAnalytics.?outputs.?workspaceId ?? ''  // Safe-dereference for conditional module
    dataCollectionRuleId: dataCollectionRule.?outputs.?dcrId ?? ''      // Safe-dereference for conditional module
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    entraFrontendClientId: entraFrontendClientId
    forceUpdateTag: forceUpdateTagWeb
    skipVmCreation: skipVmCreationWeb
    tags: allTags
  }
}

// =============================================================================
// Module 10: App Tier VMs
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
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    forceUpdateTag: forceUpdateTagApp
    skipVmCreation: skipVmCreationApp
    tags: allTags
  }
}

// =============================================================================
// Module 11: DB Tier VMs
// =============================================================================
// 2 MongoDB VMs across Availability Zones
// =============================================================================

module dbTier 'modules/compute/db-tier.bicep' = {
  name: 'deploy-db-tier'
  // Note: Implicit dependency on vnet via vnet.outputs.dbSubnetId parameter
  // This ensures: NAT Gateway → VNet (with NAT Gateway attached to subnets) → DB VMs
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
    forceUpdateTag: forceUpdateTagDb
    skipVmCreation: skipVmCreationDb
    tags: allTags
  }
}

// =============================================================================
// Module 12: Key Vault (deployed after all VMs)
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

@description('Application Gateway public IP address')
output appGatewayPublicIp string = applicationGateway.outputs.publicIpAddress

@description('Application Gateway FQDN')
output appGatewayFqdn string = applicationGateway.outputs.fqdn

@description('Application Gateway HTTPS URL')
output appGatewayHttpsUrl string = applicationGateway.outputs.httpsUrl

@description('SSL/TLS enabled status')
output sslEnabled bool = applicationGateway.outputs.sslEnabled

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

@description('NAT Gateway Public IP (for outbound connectivity)')
output natGatewayPublicIp string = natGateway.?outputs.?publicIpAddress ?? ''

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
