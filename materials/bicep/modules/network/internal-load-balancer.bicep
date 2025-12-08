// =============================================================================
// Internal Load Balancer Module (App Tier)
// =============================================================================
// Purpose: Distribute traffic from Web tier to App tier VMs
// Reference: /design/AzureArchitectureDesign.md - Section 3: Load Balancing
//
// Why Internal Load Balancer for App Tier?
//   - Prepares architecture for VMSS auto-scaling migration
//   - Azure-native health checks for backend VMs
//   - Consistent architecture pattern across tiers
//   - Simplifies NGINX upstream configuration (single ILB IP)
//   - No public IP exposure (internal only)
//
// Traffic Flow:
//   Internet → Public LB → Web VMs (NGINX) → Internal LB → App VMs (Express)
//
// VMSS Migration Path:
//   Current:  Internal LB → 2 individual App VMs
//   Future:   Internal LB → VMSS with 2-10 instances (auto-scale)
//   Change:   Only swap backend pool members, no LB reconfiguration needed
//
// AWS Comparison:
//   - Internal LB ≈ Internal NLB / Internal ALB
//   - Private subnet placement, no internet-facing
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the App tier subnet for frontend IP')
param subnetId string

@description('Private IP address for the Internal Load Balancer frontend (must be within App tier subnet 10.0.2.0/24)')
param frontendPrivateIp string = '10.0.2.10'

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var loadBalancerName = 'lbi-app-${workloadName}-${environment}'
var frontendName = 'frontend-app'
var backendPoolName = 'backend-app'
var healthProbeName = 'probe-app-http'
var lbRuleName = 'rule-app-http'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'app'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Internal Load Balancer
// =============================================================================
// Configuration:
//   - Frontend: Private IP in App tier subnet
//   - Backend Pool: App tier VMs (added separately)
//   - Health Probe: HTTP GET /health on port 3000
//   - Rule: Forward 3000→3000 (Express API)
//
// Note: No public IP, no outbound rules (VMs use NAT Gateway or own route)
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
    // Frontend IP Configuration (Private IP in App subnet)
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          privateIPAddress: frontendPrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
        }
        // Zone-redundant frontend for HA
        zones: [
          '1'
          '2'
          '3'
        ]
      }
    ]
    
    // Backend Address Pool (VMs added via NIC association)
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    
    // Health Probe
    // Checks if Express API servers are healthy
    probes: [
      {
        name: healthProbeName
        properties: {
          protocol: 'Http'
          port: 3000
          requestPath: '/health'  // Express health endpoint
          intervalInSeconds: 15
          numberOfProbes: 2  // 2 failures = unhealthy (30 seconds)
          probeThreshold: 1
        }
      }
    ]
    
    // Load Balancing Rules
    loadBalancingRules: [
      // Express API Rule (port 3000)
      {
        name: lbRuleName
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
          frontendPort: 3000
          backendPort: 3000
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          // Round-robin distribution (stateless API)
          loadDistribution: 'Default'
          enableTcpReset: true
          // Internal LB doesn't need outbound SNAT rules
          disableOutboundSnat: true
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Internal Load Balancer')
output loadBalancerId string = loadBalancer.id

@description('Name of the Internal Load Balancer')
output loadBalancerName string = loadBalancer.name

@description('Private IP address of the Internal Load Balancer frontend')
output frontendPrivateIp string = frontendPrivateIp

@description('Resource ID of the backend address pool (for VM NIC association)')
output backendPoolId string = loadBalancer.properties.backendAddressPools[0].id

@description('Name of the backend address pool')
output backendPoolName string = backendPoolName
