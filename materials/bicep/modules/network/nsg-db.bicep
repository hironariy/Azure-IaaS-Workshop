// =============================================================================
// Network Security Group - Database Tier
// =============================================================================
// Purpose: Controls inbound/outbound traffic for MongoDB replica set VMs
// Reference: /design/AzureArchitectureDesign.md - NSG Rules section
//
// Security Principle: Maximum Isolation
//   - DB tier only accepts MongoDB traffic from App tier
//   - No direct access from Web tier or Internet
//   - Replica set communication between DB VMs allowed
//   - Most restrictive tier in the architecture
//
// Traffic Flow:
//   App Tier → DB Tier (MongoDB port 27017)
//   DB VM ↔ DB VM (MongoDB replica set port 27017)
//   Azure Bastion → DB Tier (SSH 22)
//
// AWS Comparison:
//   - Similar to RDS in private subnet
//   - MongoDB on VMs provides more control than managed DB
//   - Workshop uses VMs intentionally for IaaS learning
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('CIDR of the App tier subnet (only allowed MongoDB client)')
param appSubnetPrefix string = '10.0.2.0/24'

@description('CIDR of the DB tier subnet (for replica set communication)')
param dbSubnetPrefix string = '10.0.3.0/24'

@description('CIDR of the Bastion subnet for SSH access')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var nsgName = 'nsg-db-${environment}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'db'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Network Security Group
// =============================================================================
// Critical Security Notes:
//   - MongoDB port 27017 is NOT exposed to Internet
//   - Only App tier VMs can connect to MongoDB
//   - Replica set members can communicate with each other
//   - SSH only via Bastion (no public IP on DB VMs)
// =============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: allTags
  properties: {
    securityRules: [
      // =========================================================================
      // INBOUND RULES
      // =========================================================================
      
      // Allow MongoDB traffic from App tier ONLY
      // This is the only application traffic allowed
      {
        name: 'AllowMongoDBFromAppTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '27017'
          sourceAddressPrefix: appSubnetPrefix
          destinationAddressPrefix: '*'
          description: 'Allow MongoDB connections only from App tier (Express API)'
        }
      }
      
      // Allow MongoDB replica set communication within DB subnet
      // Required for primary/secondary replication and election
      {
        name: 'AllowMongoDBReplicaSet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '27017'
          sourceAddressPrefix: dbSubnetPrefix
          destinationAddressPrefix: '*'
          description: 'Allow MongoDB replica set communication between DB VMs'
        }
      }
      
      // Allow SSH from Azure Bastion only
      {
        name: 'AllowSSHFromBastion'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
          description: 'Allow SSH only from Azure Bastion for maintenance'
        }
      }
      
      // Allow Azure Load Balancer probes (for health monitoring)
      {
        name: 'AllowAzureLoadBalancerProbe'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          description: 'Allow Azure platform health monitoring'
        }
      }
      
      // Deny all other inbound traffic (explicit deny)
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Deny all other inbound - DB tier has strictest access control'
        }
      }

      // =========================================================================
      // OUTBOUND RULES
      // =========================================================================
      
      // Allow MongoDB replica set communication within DB subnet
      // NOTE: Priority 200 leaves 100-199 reserved for test/override rules (see Issue #16)
      {
        name: 'AllowMongoDBReplicaSetOutbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '27017'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: dbSubnetPrefix
          description: 'Allow MongoDB replica set communication (outbound to other DB VM)'
        }
      }
      
      // Allow outbound to Azure services (Storage for backups, Monitor)
      {
        name: 'AllowOutboundToAzureServices'
        properties: {
          priority: 300
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          description: 'Allow outbound to Azure (Storage for backups, Monitor for metrics)'
        }
      }
      
      // Allow outbound to Azure Storage specifically (for backups)
      {
        name: 'AllowOutboundToStorage'
        properties: {
          priority: 310
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Storage'
          description: 'Allow outbound to Azure Storage (backup destination)'
        }
      }
      
      // Allow DNS resolution
      {
        name: 'AllowDNS'
        properties: {
          priority: 400
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow DNS resolution'
        }
      }
      
      // Allow NTP for time synchronization
      // Critical for replica set - clock skew can cause election issues
      {
        name: 'AllowNTP'
        properties: {
          priority: 410
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '123'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow NTP (critical for replica set clock sync)'
        }
      }
      
      // Allow HTTP for apt package updates
      {
        name: 'AllowHTTPOutbound'
        properties: {
          priority: 500
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          description: 'Allow HTTP for apt package updates'
        }
      }
      
      // Allow HTTPS for MongoDB downloads and updates
      {
        name: 'AllowHTTPSOutbound'
        properties: {
          priority: 510
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          description: 'Allow HTTPS for MongoDB package downloads'
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the DB tier NSG')
output nsgId string = nsg.id

@description('Name of the DB tier NSG')
output nsgName string = nsg.name
