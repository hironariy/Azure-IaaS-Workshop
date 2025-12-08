// =============================================================================
// Key Vault Module
// =============================================================================
// Purpose: Secure storage for application secrets
// Reference: /design/RepositoryWideDesignRules.md - Section 1: Secret Management
//
// Key Vault stores:
//   - MongoDB connection strings
//   - OAuth2.0 client secrets (if needed)
//   - TLS/SSL certificates
//   - Any other sensitive configuration
//
// Access pattern:
//   - VMs use Managed Identity to access secrets
//   - No passwords/keys in code or environment variables
//   - RBAC for fine-grained access control
//
// AWS Comparison:
//   - Key Vault ≈ AWS Secrets Manager + AWS KMS combined
//   - Access via Managed Identity ≈ IAM Instance Role + AWS SDK
//   - RBAC authorization ≈ IAM Policies
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Object ID of the current user/service principal for initial access')
param adminObjectId string

@description('Tenant ID for the Key Vault')
param tenantId string = subscription().tenantId

@description('Principal IDs of VMs that need secret access')
param vmPrincipalIds array = []

@description('Enable soft delete (recommended for production)')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 30

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
// Key Vault name must be globally unique (3-24 chars, alphanumeric + hyphens)
var keyVaultName = 'kv-${workloadName}-${uniqueString(resourceGroup().id)}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Key Vault
// =============================================================================
// Using RBAC authorization (recommended over access policies)
// This allows fine-grained control via Azure RBAC
// =============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: allTags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'  // Standard tier sufficient for workshop
    }
    // Use RBAC for authorization (modern approach)
    enableRbacAuthorization: true
    // Soft delete protects against accidental deletion
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    // Purge protection prevents permanent deletion during retention period
    enablePurgeProtection: enableSoftDelete
    // Network configuration
    publicNetworkAccess: 'Enabled'  // For workshop simplicity
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// =============================================================================
// Role Assignments
// =============================================================================
// Grant access using Azure RBAC roles
// Key Vault Secrets User: Read secrets only (for VMs)
// Key Vault Administrator: Full access (for admin)
// =============================================================================

// Built-in role IDs
var keyVaultSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
var keyVaultAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')

// Filter out empty or invalid principal IDs (defensive programming)
// This prevents InvalidPrincipalId errors if some VMs fail to deploy
// A valid GUID is 36 characters (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
var validVmPrincipalIds = filter(vmPrincipalIds, id => !empty(id) && length(id) >= 36)

// Validate adminObjectId - must be a valid GUID
var isAdminObjectIdValid = !empty(adminObjectId) && length(adminObjectId) >= 36

// Grant admin full access to Key Vault (only if valid admin ID provided)
resource adminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isAdminObjectIdValid) {
  name: guid(keyVault.id, adminObjectId, keyVaultAdminRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultAdminRoleId
    principalId: adminObjectId
    principalType: 'User'
  }
}

// Grant VMs access to read secrets (only for valid principal IDs)
resource vmRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, index) in validVmPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'  // Managed Identity is a service principal
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('Name of the Key Vault')
output keyVaultName string = keyVault.name

@description('URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
