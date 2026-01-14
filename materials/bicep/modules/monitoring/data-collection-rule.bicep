// =============================================================================
// Data Collection Rule Module
// =============================================================================
// Purpose: Define what data Azure Monitor Agent collects from VMs
// Reference: /design/AzureArchitectureDesign.md - Section 5: Monitoring & Logging
//
// Data Collection Rules (DCR) are the modern way to configure monitoring:
//   - Replace legacy OMS/MMA agent configuration
//   - Define data sources (syslog, performance counters, custom logs)
//   - Route data to Log Analytics workspace
//   - Can be shared across multiple VMs
//
// This DCR collects:
//   - Syslog (auth, daemon, syslog facilities)
//   - Performance counters (CPU, Memory, Disk, Network)
//
// Note on Data Collection Endpoint (DCE):
//   - DCE is NOT required for built-in streams (Microsoft-Syslog, Microsoft-Perf)
//   - AMA sends to Azure Monitor public endpoints by default
//   - DCE is only needed for: custom logs, private link scenarios, IIS logs
//
// AWS Comparison:
//   - DCR ≈ CloudWatch Agent configuration file
//   - Performance counters ≈ CloudWatch Metrics
//   - Syslog collection ≈ CloudWatch Logs Agent
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
var dcrName = 'dcr-${workloadName}-${environment}'
var dceName = 'dce-${workloadName}-${environment}'

var defaultTags = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// =============================================================================
// Data Collection Endpoint (optional for built-in streams, added here to avoid
// table validation issues in some regions/tenants)
// =============================================================================

resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: dceName
  location: location
  tags: allTags
  kind: 'Linux'
  properties: {
    description: 'Data Collection Endpoint for ${workloadName} workshop VMs'
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// =============================================================================
// Data Collection Rule
// =============================================================================
// Configures Azure Monitor Agent to collect:
//   1. Syslog - system logs for troubleshooting
//   2. Performance counters - resource utilization metrics
//
// For built-in streams (Microsoft-Syslog, Microsoft-Perf):
//   - Do NOT specify transformKql or outputStream
//   - Azure automatically routes to Syslog and Perf tables
//   - Tables are auto-created when first data arrives
//   - Specifying outputStream triggers deployment-time validation that can fail
//     on new workspaces where tables haven't been initialized yet
// =============================================================================

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dcrName
  location: location
  tags: allTags
  kind: 'Linux'  // For Ubuntu VMs
  properties: {
    description: 'Data Collection Rule for ${workloadName} workshop VMs'
    dataCollectionEndpointId: dataCollectionEndpoint.id
    
    // Data sources - what to collect
    dataSources: {
      // Syslog collection
      syslog: [
        {
          name: 'syslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'daemon'
            'syslog'
            'user'
          ]
          logLevels: [
            'Debug'
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
      
      // Performance counters collection
      performanceCounters: [
        {
          name: 'perfCounterDataSource'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            // CPU metrics
            'Processor(*)\\% Processor Time'
            'Processor(*)\\% User Time'
            'Processor(*)\\% Idle Time'
            
            // Memory metrics
            'Memory(*)\\% Used Memory'
            'Memory(*)\\Available MBytes Memory'
            'Memory(*)\\Used Memory MBytes'
            
            // Disk metrics
            'LogicalDisk(*)\\% Used Space'
            'LogicalDisk(*)\\Free Megabytes'
            'LogicalDisk(*)\\Disk Reads/sec'
            'LogicalDisk(*)\\Disk Writes/sec'
            
            // Network metrics
            'Network(*)\\Total Bytes Transmitted'
            'Network(*)\\Total Bytes Received'
            'Network(*)\\Bytes Total/sec'
          ]
        }
      ]
    }
    
    // Destinations - where to send data
    destinations: {
      logAnalytics: [
        {
          name: 'logAnalyticsDestination'
          workspaceResourceId: logAnalyticsWorkspaceId
        }
      ]
    }
    
    // Data flows - map sources to destinations
    // Using transformKql with outputStream ensures Azure creates the tables
    // even when the workspace is brand new and tables haven't been initialized
    dataFlows: [
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-Syslog'
      }
      {
        streams: [
          'Microsoft-Perf'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-Perf'
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Data Collection Rule')
output dcrId string = dataCollectionRule.id

@description('Name of the Data Collection Rule')
output dcrName string = dataCollectionRule.name

@description('Resource ID of the Data Collection Endpoint')
output dceId string = dataCollectionEndpoint.id
