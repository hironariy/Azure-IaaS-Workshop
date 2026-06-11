// =============================================================================
// Parameters File - Azure IaaS Workshop (Development / Cost-Optimized)
// =============================================================================
// Use this for local development and testing
// Reduces costs by using smaller VMs and skipping Bastion
//
// Usage:
//   az deployment group create \
//     --resource-group rg-blogapp-dev \
//     --template-file main.bicep \
//     --parameters dev.bicepparam
// =============================================================================

using 'main.bicep'

// =============================================================================
// Required Parameters
// =============================================================================

param location = 'eastus'
param environment = 'dev'
param workloadName = 'blogapp'
param adminUsername = 'azureuser'

// SSH public key - REQUIRED
param sshPublicKey = ''  // Add your SSH public key

// Azure AD Object ID - REQUIRED  
param adminObjectId = ''  // Add your Object ID

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
// MongoDB Application Password
// =============================================================================
// IMPORTANT: Use the SAME password in the post-deployment setup script!
// =============================================================================

param mongoDbAppPassword = ''  // Add MongoDB app password (must match post-deployment script)

// =============================================================================
// Cost Optimization - Disable expensive resources
// =============================================================================

// Skip Bastion to save ~$138/month
// Use serial console or temporarily add public IP for SSH
param deployBastion = false

// Keep monitoring for troubleshooting
param deployMonitoring = true

// Keep Key Vault (minimal cost)
param deployKeyVault = true

// Keep Storage (minimal cost)
param deployStorage = true

// =============================================================================
// Smaller Basv2 VM Sizes for Development
// =============================================================================

// Use low-memory Basv2-series VMs while keeping the same VM family as production.
param webVmSize = 'Standard_B2ats_v2'  // 2 vCPU, 1 GB RAM
param appVmSize = 'Standard_B2ats_v2'  // 2 vCPU, 1 GB RAM
param dbVmSize = 'Standard_B2als_v2'   // 2 vCPU, 4 GB RAM (needs some memory for MongoDB)

// Smaller data disk
param dbDataDiskSizeGB = 64

// =============================================================================
// Tags
// =============================================================================

param tags = {
  Project: 'AzureIaaSWorkshop'
  Student: 'developer'
  Purpose: 'Development'
}
