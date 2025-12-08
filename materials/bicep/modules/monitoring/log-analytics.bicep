// =============================================================================
// Log Analytics Workspace Module
// =============================================================================
// Purpose: Centralized logging and monitoring for all Azure resources
// Reference: /design/AzureArchitectureDesign.md - Section 5: Monitoring & Logging
//
// Log Analytics is the foundation of Azure Monitor:
//   - Collects logs from VMs (via Azure Monitor Agent)
//   - Stores metrics and diagnostic data
//   - Enables KQL queries for troubleshooting
//   - Powers alerts and workbooks
//
// AWS Comparison:
//   - Log Analytics ≈ CloudWatch Logs + CloudWatch Metrics combined
//   - KQL (Kusto Query Language) ≈ CloudWatch Logs Insights
//   - Workbooks ≈ CloudWatch Dashboards
//   - Data Collection Rules ≈ CloudWatch Agent configuration
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Log retention in days (30-730, or -1 for unlimited)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
var workspaceName = 'log-${workloadName}-${environment}-${location}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Log Analytics Workspace
// =============================================================================
// Pricing tier: PerGB2018 (pay per GB ingested)
// For workshop: expect minimal data (< 5 GB/day)
// =============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: allTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    // Enable features
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    // Network access (allow public access for workshop simplicity)
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('Name of the Log Analytics workspace')
output workspaceName string = logAnalyticsWorkspace.name

@description('Workspace ID (GUID) for agent configuration')
output customerId string = logAnalyticsWorkspace.properties.customerId

// Note: Primary shared key removed to avoid security warning
// Modern Azure Monitor Agent uses Managed Identity, not shared keys
// If needed for legacy agents, retrieve via: az monitor log-analytics workspace get-shared-keys
