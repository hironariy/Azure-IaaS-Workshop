// =============================================================================
// Network Security Group - Web Tier
// =============================================================================
// Purpose: Controls inbound/outbound traffic for NGINX reverse proxy VMs
// Reference: /design/AzureArchitectureDesign.md - NSG Rules section
//
// Security Principle: Least Privilege
//   - Only allow traffic that is explicitly required
//   - Deny everything else (default Azure behavior)
//
// Traffic Flow (with Application Gateway):
//   Internet → Application Gateway (HTTPS:443) → Web Tier VMs (HTTP:80)
//   Azure Bastion → Web Tier VMs (SSH 22)
//
// Note: Application Gateway terminates SSL/TLS, sends HTTP to backend VMs
//       No direct Internet traffic reaches Web VMs
//
// AWS Comparison:
//   - NSG ≈ Security Group, but:
//     - NSGs are stateful (return traffic allowed automatically)
//     - NSGs apply at subnet level OR NIC level
//     - AWS SGs are only at instance/ENI level
//   - Default deny vs AWS default allow-all-outbound
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('CIDR of the Bastion subnet for SSH access')
param bastionSubnetPrefix string = '10.0.255.0/26'

@description('CIDR of the Application Gateway subnet')
param appGatewaySubnetPrefix string = '10.0.0.0/24'

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var nsgName = 'nsg-web-${environment}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'web'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Network Security Group
// =============================================================================
// Rule priority: Lower number = higher priority
// Range: 100-4096 (100-999 recommended for custom rules)
// Reserved: 65000-65535 for Azure default rules
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
      
      // Allow HTTP from Application Gateway subnet only
      // Application Gateway terminates HTTPS and forwards HTTP to backend
      {
        name: 'AllowHTTPFromAppGateway'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: appGatewaySubnetPrefix
          destinationAddressPrefix: '*'
          description: 'Allow HTTP from Application Gateway (SSL terminated at gateway)'
        }
      }
      
      // Allow Application Gateway health probes
      // GatewayManager service tag covers App Gateway v2 infrastructure
      {
        name: 'AllowAppGatewayHealthProbe'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          description: 'Required for Application Gateway v2 health probes'
        }
      }
      
      // Allow SSH from Azure Bastion only
      // This is critical for security - no direct SSH from Internet
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
          description: 'Allow SSH only from Azure Bastion subnet - no public SSH access'
        }
      }
      
      // Allow Azure Load Balancer probes (if internal LB is used for health)
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
          description: 'Required for Azure Load Balancer health probes'
        }
      }
      
      // Deny all other inbound traffic (explicit for visibility)
      // Azure has implicit deny, but this makes it visible in the portal
      // Note: No direct Internet traffic allowed - all goes through App Gateway
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
          description: 'Deny all other inbound traffic (defense in depth)'
        }
      }

      // =========================================================================
      // OUTBOUND RULES
      // =========================================================================
      
      // Allow outbound to App tier (port 3000 - Express API)
      // NOTE: Priority 200 leaves 100-199 reserved for test/override rules (see Issue #16)
      {
        name: 'AllowOutboundToAppTier'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3000'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '10.0.2.0/24'
          description: 'Allow NGINX to forward requests to App tier (Express API)'
        }
      }
      
      // Allow outbound to Azure services (for monitoring, updates)
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
          description: 'Allow outbound to Azure services (monitoring, updates)'
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
          description: 'Allow NTP for time sync (critical for auth tokens)'
        }
      }
      
      // Allow HTTP for package updates (apt)
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
      
      // Allow HTTPS for package updates
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
          description: 'Allow HTTPS for secure package updates and npm'
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Web tier NSG')
output nsgId string = nsg.id

@description('Name of the Web tier NSG')
output nsgName string = nsg.name
