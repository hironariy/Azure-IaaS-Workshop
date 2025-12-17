// =============================================================================
// Virtual Network Module
// =============================================================================
// Purpose: Creates the VNet with 4 subnets for 3-tier architecture + Bastion
// Reference: /design/AzureArchitectureDesign.md - Section 1: Networking Architecture
// 
// Subnet Layout:
//   - Web tier:     10.0.1.0/24 (NGINX reverse proxy)
//   - App tier:     10.0.2.0/24 (Express/Node.js API)
//   - DB tier:      10.0.3.0/24 (MongoDB replica set)
//   - Bastion:      10.0.255.0/26 (Azure Bastion - required name: AzureBastionSubnet)
//
// AWS Comparison:
//   - VNet ≈ AWS VPC
//   - Subnets are similar but Azure subnets can span AZs (unlike AWS)
//   - NSGs ≈ Security Groups (but applied at subnet level by default)
// =============================================================================

@description('Azure region for all resources. Use the same region as your resource group.')
param location string

@description('Environment name for naming convention (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('VNet address space CIDR block')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Web tier subnet CIDR block')
param webSubnetPrefix string = '10.0.1.0/24'

@description('App tier subnet CIDR block')
param appSubnetPrefix string = '10.0.2.0/24'

@description('DB tier subnet CIDR block')
param dbSubnetPrefix string = '10.0.3.0/24'

@description('Azure Bastion subnet CIDR block (minimum /26)')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('Resource ID of NSG for Web tier subnet')
param webNsgId string

@description('Resource ID of NSG for App tier subnet')
param appNsgId string

@description('Resource ID of NSG for DB tier subnet')
param dbNsgId string

@description('Resource ID of NAT Gateway for App tier outbound connectivity (optional)')
param appNatGatewayId string = ''

@description('Resource ID of NAT Gateway for DB tier outbound connectivity (optional)')
param dbNatGatewayId string = ''

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming Convention
// =============================================================================
var vnetName = 'vnet-${workloadName}-${environment}-${location}'
var webSubnetName = 'snet-web-${environment}'
var appSubnetName = 'snet-app-${environment}'
var dbSubnetName = 'snet-db-${environment}'
// Azure Bastion requires exactly this subnet name
var bastionSubnetName = 'AzureBastionSubnet'

// Merge default tags with provided tags
var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Virtual Network Resource
// =============================================================================
// Why single VNet with multiple subnets?
//   - Simpler management than peered VNets
//   - Lower latency between tiers (same backbone)
//   - NSGs provide network isolation between subnets
//   - Cost-effective (no peering charges)
//
// Production consideration: For enterprise workloads, consider:
//   - Hub-spoke topology with Azure Firewall
//   - Separate VNets for security boundaries
//   - Private endpoints for PaaS services
// =============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: allTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    // Define all subnets within the VNet
    // Note: Subnets in Azure can span Availability Zones (unlike AWS)
    subnets: [
      {
        name: webSubnetName
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: webNsgId
          }
          // Service endpoints for Azure services (optional but recommended)
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          // Disable private endpoint network policies if needed
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: appNsgId
          }
          // NAT Gateway for outbound internet connectivity
          // Required for: npm package downloads, Azure Monitor agent
          natGateway: !empty(appNatGatewayId) ? {
            id: appNatGatewayId
          } : null
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: dbSubnetName
        properties: {
          addressPrefix: dbSubnetPrefix
          networkSecurityGroup: {
            id: dbNsgId
          }
          // NAT Gateway for outbound internet connectivity
          // Required for: MongoDB repo access, package updates, Azure Monitor
          natGateway: !empty(dbNatGatewayId) ? {
            id: dbNatGatewayId
          } : null
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
          // Bastion subnet does NOT get NSG attached (Azure manages it)
          // This is different from other subnets
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================
// These outputs are consumed by other modules (compute, bastion, load balancer)

@description('Resource ID of the Virtual Network')
output vnetId string = vnet.id

@description('Name of the Virtual Network')
output vnetName string = vnet.name

@description('Resource ID of the Web tier subnet')
output webSubnetId string = vnet.properties.subnets[0].id

@description('Resource ID of the App tier subnet')
output appSubnetId string = vnet.properties.subnets[1].id

@description('Resource ID of the DB tier subnet')
output dbSubnetId string = vnet.properties.subnets[2].id

@description('Resource ID of the Bastion subnet')
output bastionSubnetId string = vnet.properties.subnets[3].id

@description('Name of the Web tier subnet')
output webSubnetName string = webSubnetName

@description('Name of the App tier subnet')
output appSubnetName string = appSubnetName

@description('Name of the DB tier subnet')
output dbSubnetName string = dbSubnetName

@description('Address prefix of the Web tier subnet')
output webSubnetAddressPrefix string = webSubnetPrefix

@description('Address prefix of the App tier subnet')
output appSubnetAddressPrefix string = appSubnetPrefix

@description('Address prefix of the DB tier subnet')
output dbSubnetAddressPrefix string = dbSubnetPrefix
