// =============================================================================
// Parameters File - Azure IaaS Workshop (Production)
// =============================================================================
// Usage:
//   az deployment group create \
//     --resource-group rg-blogapp-prod \
//     --template-file main.bicep \
//     --parameters main.bicepparam
// =============================================================================

using 'main.bicep'

// =============================================================================
// Required Parameters
// =============================================================================

// Azure region - use a region with Availability Zone support
param location = 'japanwest'

// Environment
param environment = 'prod'

// Workload name (used in resource naming)
param workloadName = 'blogapp'

// Admin username for SSH
param adminUsername = 'azureuser'

// SSH public key for authentication
// Generate with: ssh-keygen -t rsa -b 4096 -C "workshop@azure"
// Then copy the contents of ~/.ssh/id_rsa.pub
param sshPublicKey = ''  // REQUIRED: Add your SSH public key here

// Object ID of the admin user for Key Vault access
// Get with: az ad signed-in-user show --query id -o tsv
param adminObjectId = ''  // REQUIRED: Add your Azure AD Object ID here

// =============================================================================
// Microsoft Entra ID - Authentication Configuration
// =============================================================================
// These parameters configure authentication for both frontend and backend
// Reference: /design/AzureArchitectureDesign.md - Bicep Parameter Flow
// =============================================================================

// Microsoft Entra tenant ID (shared by all apps)
// Get with: az account show --query tenantId -o tsv
param entraTenantId = ''  // REQUIRED: Add your Entra tenant ID here

// Microsoft Entra client ID - Backend API (registered app)
// Get from Azure Portal > App registrations > Backend API > Application (client) ID
param entraClientId = ''  // REQUIRED: Add your backend API client ID here

// Microsoft Entra client ID - Frontend SPA (registered app)
// Get from Azure Portal > App registrations > Frontend SPA > Application (client) ID
param entraFrontendClientId = ''  // REQUIRED: Add your frontend SPA client ID here

// =============================================================================
// Application Gateway SSL/TLS Configuration
// =============================================================================
// These parameters configure HTTPS termination at the Application Gateway
// Reference: /design/AzureArchitectureDesign.md - Application Gateway Configuration
// =============================================================================

// Self-signed SSL certificate in PFX format (base64 encoded)
// Generate with: ./scripts/generate-ssl-cert.sh
// Then base64 encode: base64 -i cert.pfx | tr -d '\n'
param sslCertificateData = ''  // REQUIRED: Add base64-encoded PFX certificate here

// Password for the PFX certificate
// Must match the password used when generating the certificate
param sslCertificatePassword = ''  // REQUIRED: Add certificate password here

// DNS label prefix for Application Gateway public IP
// Results in FQDN: <label>.<region>.cloudapp.azure.com
// Example: blogapp-12345 → blogapp-12345.japanwest.cloudapp.azure.com
param appGatewayDnsLabel = ''  // REQUIRED: Add unique DNS label here

// =============================================================================
// Optional Parameters - Feature Flags
// =============================================================================

// Deploy Azure Bastion for secure VM access
// Set to false during development to save ~$0.19/hour
param deployBastion = true

// Deploy monitoring resources (Log Analytics, Data Collection Rule)
param deployMonitoring = true

// Deploy Key Vault for secrets management
param deployKeyVault = true

// Deploy Storage Account for static assets
param deployStorage = true

// =============================================================================
// Optional Parameters - VM Sizing
// =============================================================================

// Web tier: NGINX reverse proxy (2 vCPU, 4 GB RAM)
param webVmSize = 'Standard_B2s'

// App tier: Express/Node.js API (2 vCPU, 4 GB RAM)
param appVmSize = 'Standard_B2s'

// DB tier: MongoDB (4 vCPU, 16 GB RAM) - needs Premium SSD support
param dbVmSize = 'Standard_B4ms'

// MongoDB data disk size
param dbDataDiskSizeGB = 128

// =============================================================================
// Optional Parameters - Tags
// =============================================================================

// Additional tags for all resources
param tags = {
  Project: 'AzureIaaSWorkshop'
  Student: 'workshop-user'  // Update with your name
}
