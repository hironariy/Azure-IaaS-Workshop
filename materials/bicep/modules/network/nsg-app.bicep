// =============================================================================
// Network Security Group - App Tier
// =============================================================================
// Purpose: Controls inbound/outbound traffic for Express/Node.js API VMs
// Reference: /design/AzureArchitectureDesign.md - NSG Rules section
//
// Security Principle: Least Privilege
//   - App tier only accepts traffic from Web tier (not directly from Internet)
//   - App tier can connect to DB tier (MongoDB)
//   - No public access to API endpoints
//
// Traffic Flow:
//   Web Tier (NGINX) → App Tier (port 3000)
//   App Tier → DB Tier (MongoDB port 27017)
//   Azure Bastion → App Tier (SSH 22)
//
// AWS Comparison:
//   - This pattern is similar to private subnets in AWS
//   - AWS would use private subnet + NAT Gateway
//   - Azure achieves same isolation with NSG rules
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('CIDR of the Web tier subnet (source for API traffic)')
param webSubnetPrefix string = '10.0.1.0/24'

@description('CIDR of the DB tier subnet (destination for database connections)')
param dbSubnetPrefix string = '10.0.3.0/24'

@description('CIDR of the Bastion subnet for SSH access')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var nsgName = 'nsg-app-${environment}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'app'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Network Security Group
// =============================================================================
// Key Security Pattern: Defense in Depth
//   - Even if Web tier is compromised, attacker can only reach port 3000
//   - No direct Internet access to App tier
//   - Explicit source restrictions (not just 'any')
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
      
      // Allow Express API traffic from Web tier ONLY
      // This is the primary security control - no direct Internet access
      {
        name: 'AllowAPIFromWebTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3000'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: '*'
          description: 'Allow API traffic only from Web tier (NGINX reverse proxy)'
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
          description: 'Allow SSH only from Azure Bastion subnet'
        }
      }
      
      // Allow Azure Load Balancer probes (if internal LB is used)
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
          description: 'Allow Azure Load Balancer health probes'
        }
      }
      
      // Deny all other inbound traffic (explicit deny for visibility)
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
          description: 'Deny all other inbound traffic - App tier is not publicly accessible'
        }
      }

      // =========================================================================
      // OUTBOUND RULES
      // =========================================================================
      
      // Allow MongoDB connections to DB tier
      {
        name: 'AllowMongoDBToDBTier'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '27017'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: dbSubnetPrefix
          description: 'Allow MongoDB connections to DB tier'
        }
      }
      
      // Allow outbound to Azure services (Key Vault, Monitor, Storage)
      {
        name: 'AllowOutboundToAzureServices'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          description: 'Allow outbound to Azure services (Key Vault, Monitor, Storage)'
        }
      }
      
      // Allow DNS resolution
      {
        name: 'AllowDNS'
        properties: {
          priority: 300
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
      {
        name: 'AllowNTP'
        properties: {
          priority: 310
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '123'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow NTP (required for JWT token validation timing)'
        }
      }
      
      // Allow HTTPS to Microsoft Entra ID (for JWKS validation)
      // This is critical for the backend to validate OAuth tokens
      {
        name: 'AllowHTTPSToEntraID'
        properties: {
          priority: 400
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureActiveDirectory'
          description: 'Allow HTTPS to Entra ID for JWKS token validation'
        }
      }
      
      // Allow HTTPS to Internet (for npm packages, external APIs)
      {
        name: 'AllowHTTPSOutbound'
        properties: {
          priority: 410
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          description: 'Allow HTTPS for npm packages and external API calls'
        }
      }
      
      // Allow HTTP for apt package updates
      {
        name: 'AllowHTTPOutbound'
        properties: {
          priority: 420
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
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the App tier NSG')
output nsgId string = nsg.id

@description('Name of the App tier NSG')
output nsgName string = nsg.name
