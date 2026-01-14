// =============================================================================
// Reusable Virtual Machine Module
// =============================================================================
// Purpose: Creates a single Azure VM with configurable options
// Reference: /design/AzureArchitectureDesign.md - Section 2: Compute Resources
//
// This module is designed to be reusable across all tiers (web, app, db)
// It supports:
//   - Availability Zone placement
//   - Managed Identity
//   - Data disks (for DB tier)
//   - Azure Monitor Agent extension
//   - Custom Script Extension
//   - Load Balancer backend pool association
//
// AWS Comparison:
//   - Azure VM ≈ EC2 Instance
//   - Managed Disk ≈ EBS Volume
//   - Availability Zone ≈ Availability Zone (same concept)
//   - Managed Identity ≈ IAM Instance Role
//   - VM Extension ≈ User Data + SSM Agent
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Name of the Virtual Machine')
param vmName string

@description('VM size (e.g., Standard_B2s for web/app, Standard_B4ms for db)')
param vmSize string

@description('Availability Zone for the VM (1, 2, or 3)')
@allowed(['1', '2', '3'])
param availabilityZone string

@description('Resource ID of the subnet to attach the VM')
param subnetId string

@description('Admin username for the VM')
param adminUsername string

@description('SSH public key for authentication (recommended over password)')
@secure()
param sshPublicKey string

@description('OS disk type')
@allowed(['Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS'])
param osDiskType string = 'StandardSSD_LRS'

@description('OS disk size in GB')
param osDiskSizeGB int = 30

@description('Data disk configurations (optional, for DB tier)')
param dataDisks array = []

@description('Resource ID of Load Balancer backend pool (optional, for web tier)')
param loadBalancerBackendPoolId string = ''

@description('Static private IP address (optional, uses Dynamic if empty)')
param privateIPAddress string = ''

@description('Enable Azure Monitor Agent extension')
param enableMonitoring bool = true

@description('Resource ID of Log Analytics workspace (required if enableMonitoring is true)')
param logAnalyticsWorkspaceId string = ''

@description('Resource ID of Data Collection Rule (required if enableMonitoring is true)')
param dataCollectionRuleId string = ''

@description('Custom script to run on VM startup (base64 encoded)')
param customScriptContent string = ''

@description('Force update tag to trigger script re-execution (change value to re-run script)')
param forceUpdateTag string = ''

@description('Skip VM creation and only update extensions on existing VM')
param skipVmCreation bool = false

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
var nicName = 'nic-${vmName}'

// Merge default tags with provided tags
var defaultTags = {
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// Ubuntu 22.04 LTS image reference
// Note: 22.04 LTS (Jammy) is used instead of 24.04 (Noble) for broader regional availability
// 24.04 LTS may not be available in all Azure regions yet
var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// =============================================================================
// Network Interface
// =============================================================================
// NIC connects the VM to the VNet subnet
// For web tier: Also connects to Load Balancer backend pool
// No public IP assigned (access via Bastion only)
// =============================================================================

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = if (!skipVmCreation) {
  name: nicName
  location: location
  tags: allTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          // Use Static allocation if privateIPAddress is provided, otherwise Dynamic
          privateIPAllocationMethod: !empty(privateIPAddress) ? 'Static' : 'Dynamic'
          privateIPAddress: !empty(privateIPAddress) ? privateIPAddress : null
          subnet: {
            id: subnetId
          }
          // Associate with Load Balancer backend pool if provided
          loadBalancerBackendAddressPools: !empty(loadBalancerBackendPoolId) ? [
            {
              id: loadBalancerBackendPoolId
            }
          ] : []
        }
      }
    ]
    // Enable accelerated networking for better performance (if VM size supports it)
    // B-series VMs don't support accelerated networking
    enableAcceleratedNetworking: false
  }
}

// =============================================================================
// Virtual Machine
// =============================================================================
// Configuration:
//   - Ubuntu 24.04 LTS (Gen2)
//   - SSH key authentication (no password)
//   - System-assigned Managed Identity
//   - Availability Zone placement
//   - Managed disks
// =============================================================================

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = if (!skipVmCreation) {
  name: vmName
  location: location
  tags: allTags
  // Place in specific Availability Zone
  zones: [
    availabilityZone
  ]
  // Enable system-assigned managed identity
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: 'osdisk-${vmName}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: osDiskSizeGB
        deleteOption: 'Delete'  // Delete disk when VM is deleted
      }
      // Add data disks if specified (for DB tier)
      dataDisks: [for (disk, index) in dataDisks: {
        name: 'datadisk-${vmName}-${index}'
        lun: index
        createOption: 'Empty'
        diskSizeGB: disk.sizeGB
        caching: disk.?caching ?? 'None'
        managedDisk: {
          storageAccountType: disk.?type ?? 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      // SSH key authentication (more secure than password)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        // Enable automatic OS patching
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
            deleteOption: 'Delete'  // Delete NIC when VM is deleted
          }
        }
      ]
    }
    // Boot diagnostics for troubleshooting
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        // Use managed storage account (no configuration needed)
      }
    }
    // Security settings
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// =============================================================================
// Existing VM Reference (when skipVmCreation is true)
// =============================================================================
// References an existing VM to allow updating extensions without recreating VM
// =============================================================================

resource existingVm 'Microsoft.Compute/virtualMachines@2023-09-01' existing = if (skipVmCreation) {
  name: vmName
}

resource existingNic 'Microsoft.Network/networkInterfaces@2023-11-01' existing = if (skipVmCreation) {
  name: nicName
}

// =============================================================================
// Azure Monitor Agent Extension
// =============================================================================
// Collects logs and metrics, sends to Log Analytics workspace
// Replaces deprecated OMS/MMA agent
// Note: Separate resources for new vs existing VMs due to Bicep parent limitations
// =============================================================================

resource amaExtensionNew 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (!skipVmCreation && enableMonitoring && !empty(logAnalyticsWorkspaceId)) {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  tags: allTags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      authentication: {
        managedIdentity: {
          'identifier-name': 'mi_res_id'
          'identifier-value': vm.id
        }
      }
    }
  }
}

resource amaExtensionExisting 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (skipVmCreation && enableMonitoring && !empty(logAnalyticsWorkspaceId)) {
  parent: existingVm
  name: 'AzureMonitorLinuxAgent'
  location: location
  tags: allTags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      authentication: {
        managedIdentity: {
          'identifier-name': 'mi_res_id'
          'identifier-value': existingVm.id
        }
      }
    }
  }
}

// =============================================================================
// Data Collection Rule Association
// =============================================================================
// Associates the VM with a Data Collection Rule for log/metric collection
// =============================================================================

resource dcrAssociationNew 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = if (!skipVmCreation && enableMonitoring && !empty(dataCollectionRuleId)) {
  name: 'configurationAccessEndpoint'
  scope: vm
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [
    amaExtensionNew
  ]
}

resource dcrAssociationExisting 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = if (skipVmCreation && enableMonitoring && !empty(dataCollectionRuleId)) {
  name: 'configurationAccessEndpoint'
  scope: existingVm
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [
    amaExtensionExisting
  ]
}

// =============================================================================
// Custom Script Extension (Optional)
// =============================================================================
// Runs custom setup script on VM (e.g., install NGINX, Node.js, MongoDB)
// =============================================================================

resource customScriptNew 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (!skipVmCreation && !empty(customScriptContent)) {
  parent: vm
  name: 'CustomScript'
  location: location
  tags: allTags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    forceUpdateTag: !empty(forceUpdateTag) ? forceUpdateTag : null
    settings: {
      script: customScriptContent
    }
  }
  dependsOn: [
    amaExtensionNew
  ]
}

resource customScriptExisting 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (skipVmCreation && !empty(customScriptContent)) {
  parent: existingVm
  name: 'CustomScript'
  location: location
  tags: allTags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    forceUpdateTag: !empty(forceUpdateTag) ? forceUpdateTag : null
    settings: {
      script: customScriptContent
    }
  }
  dependsOn: [
    amaExtensionExisting
  ]
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource ID of the Virtual Machine')
output vmId string = skipVmCreation ? existingVm!.id : vm!.id

@description('Name of the Virtual Machine')
output vmName string = skipVmCreation ? existingVm!.name : vm!.name

@description('Private IP address of the VM')
output privateIpAddress string = skipVmCreation ? existingNic!.properties.ipConfigurations[0].properties.privateIPAddress : nic!.properties.ipConfigurations[0].properties.privateIPAddress

@description('Principal ID of the VM managed identity (for RBAC assignments)')
output principalId string = skipVmCreation ? existingVm!.identity.principalId : vm!.identity.principalId

@description('Resource ID of the Network Interface')
output nicId string = skipVmCreation ? existingNic!.id : nic!.id

@description('Availability Zone of the VM')
output zone string = availabilityZone
