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

// =============================================================================
// Multi-Group Workshop Support
// =============================================================================
// For workshops with multiple groups (A-J) deploying to the same subscription:
// 1. Each group should use a unique resource group name
// 2. Set groupId to your assigned group letter (A-J)
// 3. Create resource group: rg-blogapp-{groupId}-workshop
//
// Example for Group C:
//   param groupId = 'C'
//   az group create --name rg-blogapp-C-workshop --location japanwest
//
// For single-group workshops, leave groupId empty (default)
// =============================================================================
param groupId = ''  // Set to 'A'-'J' for multi-group workshops

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

// =============================================================================
// MongoDB Application Password
// =============================================================================
// IMPORTANT: Use the SAME password in the post-deployment setup script!
// This password is injected into the backend API connection string.
// =============================================================================

// MongoDB application user password
// Use a strong password with at least 12 characters
// Example: Generate with: openssl rand -base64 16
param mongoDbAppPassword = ''  // REQUIRED: Add MongoDB app password here

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
// Dsv6 VMs expose managed disks through NVMe; the DB setup script identifies
// the data disk by Azure LUN rather than an unstable /dev/nvme* device name.
// SKU availability varies by region and Availability Zone. Check both sizes:
//   az vm list-skus --location japanwest --size Standard_D2s_v6 --zone -o table
//   az vm list-skus --location japanwest --size Standard_D4s_v6 --zone -o table
// The DB tier needs Standard_D4s_v6 in Zones 1, 2 AND 3 (3-node replica set,
// Issue #30): 3 x 4 = 12 Dsv6-family vCPUs for the DB tier alone.
// Listed SKUs do not guarantee available capacity at deployment time.
// =============================================================================

// Web tier: NGINX reverse proxy (2 vCPU, 8 GiB RAM)
param webVmSize = 'Standard_D2s_v6'

// App tier: Express/Node.js API (2 vCPU, 8 GiB RAM)
param appVmSize = 'Standard_D2s_v6'

// DB tier: MongoDB (4 vCPU, 16 GiB RAM), Premium SSD data disk
param dbVmSize = 'Standard_D4s_v6'

// MongoDB data disk size
param dbDataDiskSizeGB = 128

// Zone of the 3rd DB VM (vm-db-az3). Keep '3' (one member per zone).
// Only if Standard_D4s_v6 is NOT offered in Zone 3 of your region, set '1' or
// '2' (agree with the instructor first). Trade-off: a single VM failure is
// still tolerated, but losing the zone that hosts 2 members loses the majority.
param dbVmAz3Zone = '3'

// =============================================================================
// Optional Parameters - Tags
// =============================================================================

// Additional tags for all resources
param tags = {
  Project: 'AzureIaaSWorkshop'
  Student: 'workshop-user'  // Update with your name
}
