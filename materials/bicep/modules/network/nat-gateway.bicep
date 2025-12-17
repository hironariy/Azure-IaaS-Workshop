// =============================================================================
// NAT Gateway Module
// =============================================================================
// Purpose: Provides outbound internet connectivity for private subnets
// Reference: /design/AzureArchitectureDesign.md - Network Architecture
//
// NAT Gateway SKUs:
//   - Standard: Zonal or non-zonal (GA)
//   - StandardV2: Zone-redundant (PREVIEW as of Dec 2024)
//
// This module uses StandardV2 SKU for zone-redundant high availability.
// StandardV2 automatically spans all availability zones in the region.
//
// Why NAT Gateway for App/DB Tiers?
//   - VMs need outbound internet for:
//     * Package updates (apt/yum)
//     * MongoDB repository access during provisioning
//     * npm package downloads
//     * Azure Monitor agent communication
//   - NAT Gateway provides:
//     * Secure outbound-only connectivity (no inbound from internet)
//     * Predictable public IP for firewall whitelisting
//     * High throughput (up to 50 Gbps)
//
// AWS Comparison:
//   - Azure NAT Gateway Standard ≈ AWS NAT Gateway (zonal, single AZ)
//   - Azure NAT Gateway StandardV2 ≈ AWS NAT Gateway with cross-AZ redundancy
//   - Unlike AWS where you need one NAT Gateway per AZ, Azure StandardV2 is zone-redundant
//
// Cost Estimate: ~$32/month + $0.045/GB data processed
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Idle timeout in minutes (4-120)')
@minValue(4)
@maxValue(120)
param idleTimeoutInMinutes int = 10

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
var natGatewayName = 'nat-${workloadName}-${environment}'
var publicIpName = 'pip-nat-${workloadName}-${environment}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  Component: 'nat-gateway'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Public IP for NAT Gateway
// =============================================================================
// StandardV2 SKU Public IP (required for StandardV2 NAT Gateway)
// Zone-redundant by default - no zones property needed
// Reference: https://learn.microsoft.com/azure/nat-gateway/quickstart-create-nat-gateway-v2-templates
// =============================================================================

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: publicIpName
  location: location
  tags: allTags
  sku: {
    name: 'StandardV2'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: idleTimeoutInMinutes
  }
}

// =============================================================================
// NAT Gateway StandardV2 (Zone-Redundant)
// =============================================================================
// StandardV2 SKU provides zone-redundant outbound connectivity
// Can survive single zone failure - connections flow from healthy zones
// NOTE: StandardV2 is in PREVIEW as of late 2024
// Reference: https://learn.microsoft.com/azure/nat-gateway/quickstart-create-nat-gateway-v2-templates
// =============================================================================

resource natGateway 'Microsoft.Network/natGateways@2024-01-01' = {
  name: natGatewayName
  location: location
  tags: allTags
  sku: {
    name: 'StandardV2'
  }
  properties: {
    idleTimeoutInMinutes: idleTimeoutInMinutes
    publicIpAddresses: [
      {
        id: publicIp.id
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the NAT Gateway')
output natGatewayId string = natGateway.id

@description('Name of the NAT Gateway')
output natGatewayName string = natGateway.name

@description('Resource ID of the NAT Gateway Public IP')
output publicIpId string = publicIp.id

@description('Public IP address of the NAT Gateway')
output publicIpAddress string = publicIp.properties.ipAddress
