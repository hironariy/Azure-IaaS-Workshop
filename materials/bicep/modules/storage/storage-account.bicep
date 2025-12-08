// =============================================================================
// Storage Account Module
// =============================================================================
// Purpose: Blob storage for static assets (images, CSS, JavaScript)
// Reference: /design/AzureArchitectureDesign.md - Section 4: Storage
//
// Use cases:
//   - Static website assets (React build output)
//   - User-uploaded images (blog post images)
//   - Application logs backup
//   - Azure Backup storage (managed by Recovery Services Vault)
//
// Configuration:
//   - Standard performance (sufficient for static assets)
//   - LRS replication (workshop doesn't need geo-redundancy)
//   - Hot access tier (frequently accessed assets)
//   - Private endpoint optional (NSG controls access)
//
// AWS Comparison:
//   - Blob Storage ≈ S3
//   - Access tiers (Hot/Cool/Archive) ≈ S3 Standard/IA/Glacier
//   - LRS/ZRS/GRS ≈ S3 One Zone/Standard/Cross-Region
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Storage account SKU (LRS for workshop, ZRS/GRS for production)')
@allowed(['Standard_LRS', 'Standard_ZRS', 'Standard_GRS', 'Standard_RAGRS'])
param storageSku string = 'Standard_LRS'

@description('Enable blob versioning')
param enableVersioning bool = false

@description('Enable soft delete for blobs')
param enableBlobSoftDelete bool = true

@description('Soft delete retention in days')
param softDeleteRetentionDays int = 7

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
// Storage account name must be globally unique (3-24 chars, lowercase alphanumeric only)
var storageAccountName = 'st${workloadName}${uniqueString(resourceGroup().id)}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Storage Account
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: allTags
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'  // General-purpose v2 (recommended)
  properties: {
    accessTier: 'Hot'  // Frequently accessed static assets
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false  // Security: no public access
    allowSharedKeyAccess: true   // For workshop simplicity (use Managed Identity in production)
    // Network configuration
    publicNetworkAccess: 'Enabled'  // For workshop simplicity
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// =============================================================================
// Blob Service Configuration
// =============================================================================

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    // Enable versioning for data protection
    isVersioningEnabled: enableVersioning
    // Soft delete for accidental deletion recovery
    deleteRetentionPolicy: {
      enabled: enableBlobSoftDelete
      days: softDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: enableBlobSoftDelete
      days: softDeleteRetentionDays
    }
  }
}

// =============================================================================
// Blob Containers
// =============================================================================

// Container for static website assets
resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'assets'
  properties: {
    publicAccess: 'None'  // Private - use SAS tokens or Managed Identity
  }
}

// Container for user uploads (blog images)
resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'uploads'
  properties: {
    publicAccess: 'None'
  }
}

// Container for backups
resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'backups'
  properties: {
    publicAccess: 'None'
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Storage Account')
output storageAccountId string = storageAccount.id

@description('Name of the Storage Account')
output storageAccountName string = storageAccount.name

@description('Primary Blob endpoint URL')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('Assets container name')
output assetsContainerName string = assetsContainer.name

@description('Uploads container name')
output uploadsContainerName string = uploadsContainer.name

@description('Backups container name')
output backupsContainerName string = backupsContainer.name
