// =============================================================================
// Application Gateway Module
// =============================================================================
// Purpose: Layer 7 load balancer with SSL/TLS termination for Web tier VMs
// Reference: /design/AzureArchitectureDesign.md - Section 3: Load Balancing
//
// Why Application Gateway (not Standard Load Balancer)?
//   - SSL/TLS termination: Students don't need to configure HTTPS on NGINX
//   - Azure DNS label: Provides <label>.<region>.cloudapp.azure.com (no custom domain needed)
//   - Self-signed certificate: Workshop can use HTTPS without CA or domain ownership
//   - Layer 7 features: Path-based routing, URL rewriting, optional WAF
//   - Educational value: Teaches modern cloud load balancing patterns
//
// Self-Signed Certificate Approach (Workshop):
//   - Certificate generated via script (OpenSSL) and uploaded as PFX
//   - Browser shows certificate warning (expected, students click "Proceed")
//   - Entra ID OAuth2.0 works with self-signed HTTPS redirect URIs
//   - Trade-off: Browser warning vs. HTTP-only insecure patterns
//
// AWS Comparison:
//   - Application Gateway ≈ Application Load Balancer (ALB)
//   - SSL termination ≈ ALB HTTPS listener
//   - Backend HTTP settings ≈ ALB target group
//   - Azure DNS label ≈ ALB DNS name or Route 53 alias
//   - WAF_v2 SKU ≈ AWS WAF attached to ALB
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the Application Gateway subnet')
param subnetId string

@description('Private IP addresses of Web tier VMs for backend pool')
param webTierPrivateIps array

@description('Self-signed SSL certificate in PFX format (base64 encoded)')
@secure()
param sslCertificateData string = ''

@description('Password for the PFX certificate')
@secure()
param sslCertificatePassword string = ''

@description('DNS label for public IP (creates <label>.<region>.cloudapp.azure.com)')
param dnsLabel string = ''

@description('Enable WAF (Web Application Firewall) - Detection mode for workshop')
param enableWaf bool = false

@description('Application Gateway capacity (instance count)')
@minValue(1)
@maxValue(10)
param capacity int = 1

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Naming and Tags
// =============================================================================
var appGatewayName = 'agw-${workloadName}-${environment}'
var publicIpName = 'pip-agw-${workloadName}-${environment}'
var frontendIpConfigName = 'frontend-ip'
var frontendPortHttpName = 'frontend-port-http'
var frontendPortHttpsName = 'frontend-port-https'
var backendPoolName = 'backend-web'
var backendHttpSettingsName = 'backend-http-settings'
var httpListenerName = 'listener-http'
var httpsListenerName = 'listener-https'
var requestRoutingRuleHttpName = 'rule-http-redirect'
var requestRoutingRuleHttpsName = 'rule-https'
var redirectConfigName = 'redirect-http-to-https'
var healthProbeName = 'probe-web'
var sslCertificateName = 'ssl-cert-workshop'

// Generate unique DNS label if not provided
var actualDnsLabel = !empty(dnsLabel) ? dnsLabel : '${workloadName}-${uniqueString(resourceGroup().id)}'

// Determine if SSL is configured (certificate provided)
var sslConfigured = !empty(sslCertificateData) && !empty(sslCertificatePassword)

// SKU based on WAF enablement
var skuName = enableWaf ? 'WAF_v2' : 'Standard_v2'
var skuTier = enableWaf ? 'WAF_v2' : 'Standard_v2'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Public IP for Application Gateway
// =============================================================================
// Standard SKU required for Application Gateway v2
// DNS label provides <label>.<region>.cloudapp.azure.com
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
    dnsSettings: {
      domainNameLabel: actualDnsLabel
    }
  }
  // Zone-redundant for high availability
  zones: [
    '1'
    '2'
    '3'
  ]
}

// =============================================================================
// Application Gateway
// =============================================================================
// Configuration:
//   - Frontend: Public IP with HTTPS (443) and HTTP (80) listeners
//   - Backend: Web tier VMs (HTTP port 80 - SSL terminated at gateway)
//   - SSL: Self-signed certificate for workshop
//   - Routing: HTTP→HTTPS redirect, HTTPS→Backend
//   - Health Probe: HTTP /health on backend
// =============================================================================

resource applicationGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGatewayName
  location: location
  tags: allTags
  properties: {
    sku: {
      name: skuName
      tier: skuTier
      capacity: capacity
    }
    
    // Gateway IP configuration (subnet)
    gatewayIPConfigurations: [
      {
        name: 'gateway-ip-config'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    
    // Frontend IP configuration
    frontendIPConfigurations: [
      {
        name: frontendIpConfigName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    
    // Frontend ports
    frontendPorts: [
      {
        name: frontendPortHttpName
        properties: {
          port: 80
        }
      }
      {
        name: frontendPortHttpsName
        properties: {
          port: 443
        }
      }
    ]
    
    // SSL certificates (if configured)
    sslCertificates: sslConfigured ? [
      {
        name: sslCertificateName
        properties: {
          data: sslCertificateData
          password: sslCertificatePassword
        }
      }
    ] : []
    
    // Backend address pool (Web tier VMs)
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
          backendAddresses: [for ip in webTierPrivateIps: {
            ipAddress: ip
          }]
        }
      }
    ]
    
    // Backend HTTP settings (connect to NGINX on port 80)
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'  // Stateless SPA
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, healthProbeName)
          }
        }
      }
    ]
    
    // Health probe for Web tier
    probes: [
      {
        name: healthProbeName
        properties: {
          protocol: 'Http'
          host: '127.0.0.1'
          path: '/health'
          interval: 15
          timeout: 10
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    
    // HTTP listeners
    httpListeners: concat(
      // HTTP listener (for redirect to HTTPS)
      [
        {
          name: httpListenerName
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, frontendIpConfigName)
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortHttpName)
            }
            protocol: 'Http'
          }
        }
      ],
      // HTTPS listener (only if SSL is configured)
      sslConfigured ? [
        {
          name: httpsListenerName
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, frontendIpConfigName)
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortHttpsName)
            }
            protocol: 'Https'
            sslCertificate: {
              id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, sslCertificateName)
            }
          }
        }
      ] : []
    )
    
    // Redirect configurations (HTTP → HTTPS)
    redirectConfigurations: sslConfigured ? [
      {
        name: redirectConfigName
        properties: {
          redirectType: 'Permanent'  // 301 redirect
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, httpsListenerName)
          }
          includePath: true
          includeQueryString: true
        }
      }
    ] : []
    
    // Request routing rules
    requestRoutingRules: concat(
      // HTTP redirect rule (or direct to backend if no SSL)
      [
        {
          name: requestRoutingRuleHttpName
          properties: {
            ruleType: 'Basic'
            priority: 200
            httpListener: {
              id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, httpListenerName)
            }
            // If SSL configured: redirect to HTTPS; otherwise: route to backend
            redirectConfiguration: sslConfigured ? {
              id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', appGatewayName, redirectConfigName)
            } : null
            backendAddressPool: !sslConfigured ? {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, backendPoolName)
            } : null
            backendHttpSettings: !sslConfigured ? {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, backendHttpSettingsName)
            } : null
          }
        }
      ],
      // HTTPS routing rule (only if SSL configured)
      sslConfigured ? [
        {
          name: requestRoutingRuleHttpsName
          properties: {
            ruleType: 'Basic'
            priority: 100
            httpListener: {
              id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, httpsListenerName)
            }
            backendAddressPool: {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, backendPoolName)
            }
            backendHttpSettings: {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, backendHttpSettingsName)
            }
          }
        }
      ] : []
    )
    
    // WAF configuration (if enabled)
    webApplicationFirewallConfiguration: enableWaf ? {
      enabled: true
      firewallMode: 'Detection'  // Detection mode for workshop (won't block traffic)
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    } : null
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Application Gateway')
output applicationGatewayId string = applicationGateway.id

@description('Name of the Application Gateway')
output applicationGatewayName string = applicationGateway.name

@description('Public IP address of the Application Gateway')
output publicIpAddress string = publicIp.properties.ipAddress

@description('FQDN of the Application Gateway (Azure DNS label)')
output fqdn string = publicIp.properties.dnsSettings.fqdn

@description('HTTPS URL for the application')
output httpsUrl string = sslConfigured ? 'https://${publicIp.properties.dnsSettings.fqdn}' : 'http://${publicIp.properties.dnsSettings.fqdn}'

@description('DNS label used for the public IP')
output dnsLabel string = actualDnsLabel

@description('Backend pool name for reference')
output backendPoolName string = backendPoolName

@description('Indicates if SSL/TLS is configured')
output sslEnabled bool = sslConfigured
