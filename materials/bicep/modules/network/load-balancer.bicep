// =============================================================================
// Standard Load Balancer Module
// =============================================================================
// Purpose: Distribute HTTP/HTTPS traffic to Web tier VMs across Availability Zones
// Reference: /design/AzureArchitectureDesign.md - Section 3: Load Balancing
//
// Why Standard Load Balancer (not Basic)?
//   - Required for Availability Zone support
//   - Better SLA (99.99% vs 99.9%)
//   - Zone-redundant frontend
//   - Outbound rules for SNAT
//   - Required for production workloads
//
// Why Standard Load Balancer (not Application Gateway)?
//   - Workshop focuses on IaaS fundamentals
//   - Faster deployment (minutes vs 15-30 min for App Gateway)
//   - Lower cost
//   - Simpler configuration for learning
//   - Production: Application Gateway + WAF recommended
//
// AWS Comparison:
//   - Standard LB ≈ Network Load Balancer (NLB) - Layer 4
//   - Application Gateway ≈ Application Load Balancer (ALB) - Layer 7
//   - Basic LB (deprecated) ≈ Classic Load Balancer
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var loadBalancerName = 'lbe-${workloadName}-${environment}'
var publicIpName = 'pip-lb-${workloadName}-${environment}'
var frontendName = 'frontend-web'
var backendPoolName = 'backend-web'
var healthProbeName = 'probe-http'
var lbRuleHttpName = 'rule-http'
var lbRuleHttpsName = 'rule-https'
var outboundRuleName = 'outbound-web'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Public IP for Load Balancer
// =============================================================================
// Standard SKU required for Standard Load Balancer
// Zone-redundant for high availability across AZs
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
    // Optional: Configure DNS name
    dnsSettings: {
      domainNameLabel: '${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
  // Zone-redundant: survives any single AZ failure
  zones: [
    '1'
    '2'
    '3'
  ]
}

// =============================================================================
// Standard Load Balancer
// =============================================================================
// Configuration:
//   - Frontend: Public IP for incoming traffic
//   - Backend Pool: Web tier VMs (added separately)
//   - Health Probe: HTTP GET / on port 80
//   - Rules: Forward 80→80 and 443→443
//   - Outbound: SNAT for backend VMs Internet access
// =============================================================================

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-11-01' = {
  name: loadBalancerName
  location: location
  tags: allTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    // Frontend IP Configuration
    // Note: Zone-redundancy is inherited from the Public IP resource
    // Do NOT specify zones here when using a public IP reference
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    
    // Backend Address Pool (VMs added via NIC association)
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    
    // Health Probe
    // Checks if web servers are healthy before sending traffic
    probes: [
      {
        name: healthProbeName
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/health'  // NGINX should respond to this
          intervalInSeconds: 15
          numberOfProbes: 2  // 2 failures = unhealthy (30 seconds)
          probeThreshold: 1
        }
      }
    ]
    
    // Load Balancing Rules
    loadBalancingRules: [
      // HTTP Rule (port 80)
      {
        name: lbRuleHttpName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, healthProbeName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          // Idle timeout: 4 minutes (default)
          idleTimeoutInMinutes: 4
          // Disable session persistence (round-robin)
          // Stateless design - no session affinity needed
          loadDistribution: 'Default'
          // Disable TCP reset on idle
          enableTcpReset: true
          // Disable outbound SNAT for this rule (use outbound rule instead)
          disableOutboundSnat: true
        }
      }
      // HTTPS Rule (port 443)
      {
        name: lbRuleHttpsName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendPoolName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, healthProbeName)
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
          enableTcpReset: true
          disableOutboundSnat: true
        }
      }
    ]
    
    // Outbound Rules for SNAT
    // Allows backend VMs to access the Internet
    outboundRules: [
      {
        name: outboundRuleName
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendName)
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendPoolName)
          }
          protocol: 'All'
          // Allocated outbound ports per VM
          allocatedOutboundPorts: 10000
          enableTcpReset: true
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Load Balancer')
output loadBalancerId string = loadBalancer.id

@description('Name of the Load Balancer')
output loadBalancerName string = loadBalancer.name

@description('Public IP address of the Load Balancer')
output publicIpAddress string = publicIp.properties.ipAddress

@description('FQDN of the Load Balancer')
output fqdn string = publicIp.properties.dnsSettings.fqdn

@description('Resource ID of the backend address pool (for VM NIC association)')
output backendPoolId string = loadBalancer.properties.backendAddressPools[0].id

@description('Name of the backend address pool')
output backendPoolName string = backendPoolName
