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
param location = 'eastus'

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
