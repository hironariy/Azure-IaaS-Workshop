// =============================================================================
// Azure Bastion Module
// =============================================================================
// Purpose: Secure SSH/RDP access to VMs without public IPs
// Reference: /design/AzureArchitectureDesign.md - Section 8: Security & Identity
//
// Why Azure Bastion?
//   - VMs don't need public IP addresses (security best practice)
//   - Browser-based SSH/RDP via Azure Portal
//   - Audit logging of all sessions
//   - Protection against port scanning attacks
//
// AWS Comparison:
//   - Bastion ≈ AWS Session Manager (SSM)
//   - Traditional approach: Jump box / bastion host in public subnet
//   - Azure Bastion is a managed PaaS service (no VM to manage)
//
// Cost Considerations:
//   - Basic SKU: ~$0.19/hour (~$138/month if always on)
//   - Workshop optimization: Deploy only when needed, deallocate otherwise
//   - Alternative: Developer SKU available for dev scenarios
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the Bastion subnet (must be named AzureBastionSubnet)')
param bastionSubnetId string

@description('Bastion SKU - Basic is sufficient for workshop')
@allowed(['Basic', 'Standard', 'Developer'])
param bastionSku string = 'Basic'

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var bastionName = 'bastion-${workloadName}-${environment}'
var publicIpName = 'pip-bastion-${workloadName}-${environment}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Public IP for Bastion
// =============================================================================
// Bastion requires a Standard SKU public IP with static allocation
// This is the ONLY public IP in our architecture (except Load Balancer)
// =============================================================================

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
    // DNS settings for Bastion - useful for troubleshooting and documentation
    dnsSettings: {
      domainNameLabel: 'bastion-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
  // Zone-redundant for high availability
  // Bastion can survive an Availability Zone failure
  zones: [
    '1'
    '2'
    '3'
  ]
}

// =============================================================================
// Azure Bastion
// =============================================================================
// SKU Options:
//   - Basic: SSH/RDP only, sufficient for workshop
//   - Standard: Adds features like native client, shareable links
//   - Developer: Lowest cost, limited features
// =============================================================================

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  tags: allTags
  sku: {
    name: bastionSku
  }
  properties: {
    // IP configuration connects Bastion to the subnet
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    // Disable copy/paste for Basic SKU (not available)
    // Enable for Standard SKU if needed
    disableCopyPaste: false
    // Enable file transfer for Standard SKU (disabled for Basic)
    enableFileCopy: bastionSku == 'Standard'
    // Enable IP-based connection for Standard SKU
    enableIpConnect: bastionSku == 'Standard'
    // Enable shareable links for Standard SKU
    enableShareableLink: bastionSku == 'Standard'
    // Enable tunneling for Standard SKU (native client support)
    enableTunneling: bastionSku == 'Standard'
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of Azure Bastion')
output bastionId string = bastion.id

@description('Name of Azure Bastion')
output bastionName string = bastion.name

@description('Public IP address of Azure Bastion')
output bastionPublicIp string = publicIp.properties.ipAddress

@description('DNS name for Bastion')
output bastionFqdn string = publicIp.properties.dnsSettings.?fqdn ?? ''
