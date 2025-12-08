// =============================================================================
// App Tier Module
// =============================================================================
// Purpose: Deploy 2 Express/Node.js API VMs across Availability Zones
// Reference: /design/AzureArchitectureDesign.md - Section 2: Compute Resources
//
// Architecture:
//   - 2 VMs: vm-app-az1 (Zone 1), vm-app-az2 (Zone 2)
//   - Receives traffic from Web tier (NGINX) on port 3000
//   - Connects to DB tier (MongoDB) on port 27017
//   - Stateless design (horizontal scaling ready)
//
// Traffic Flow:
//   Web Tier (NGINX) → App Tier (Express:3000) → DB Tier (MongoDB:27017)
//
// VM Sizing Rationale (B2s):
//   - 2 vCPU, 4 GB RAM
//   - 60% CPU baseline with burst capability
//   - Node.js is single-threaded, 2 vCPU provides overhead for npm, OS
//   - 4 GB RAM sufficient for Express + Mongoose with light load
//   - Cost-effective: $0.042/hr
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the App tier subnet')
param subnetId string

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for authentication')
@secure()
param sshPublicKey string

@description('VM size for app tier')
param vmSize string = 'Standard_B2s'

@description('Enable Azure Monitor Agent')
param enableMonitoring bool = true

@description('Resource ID of Log Analytics workspace')
param logAnalyticsWorkspaceId string = ''

@description('Resource ID of Data Collection Rule')
param dataCollectionRuleId string = ''

@description('Tags to apply to all resources')
param tags object = {}

// =============================================================================
// Variables
// =============================================================================
var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'app'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// Node.js 20 LTS installation script (base64 encoded)
// This script:
//   1. Updates apt packages
//   2. Installs Node.js 20 LTS via NodeSource
//   3. Installs PM2 process manager
//   4. Creates application directory
var nodeInstallScript = '''
#!/bin/bash
set -e

# ==========================================================
# Wait for dpkg/apt locks to be released
# ==========================================================
# Azure Linux Agent may be running unattended-upgrades on first boot
# This can hold dpkg lock for 1-5 minutes
# We wait up to 5 minutes for the lock to be released
# ==========================================================

wait_for_apt_lock() {
  local timeout=300
  local interval=10
  local elapsed=0
  
  echo "Checking for dpkg/apt locks..."
  
  while true; do
    # Check if any apt/dpkg processes are running
    if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && \
       ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
       ! fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
      echo "All apt/dpkg locks are free, proceeding..."
      return 0
    fi
    
    if [ $elapsed -ge $timeout ]; then
      echo "ERROR: Timeout waiting for apt/dpkg locks after ${timeout}s"
      return 1
    fi
    
    echo "apt/dpkg lock is held, waiting ${interval}s... (${elapsed}s elapsed)"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
}

# Set non-interactive mode to prevent prompts during package installation
export DEBIAN_FRONTEND=noninteractive

# Execute wait function (initial check to reduce log spam)
wait_for_apt_lock

# Update packages with lock timeout (backup protection against race conditions)
# DPkg::Lock::Timeout waits up to 120 seconds if another process holds the lock
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 -y upgrade

# Install prerequisites
apt-get -o DPkg::Lock::Timeout=120 -y install ca-certificates curl gnupg

# Add NodeSource repository for Node.js 20 LTS
mkdir -p /etc/apt/keyrings

# Use --batch flag for non-interactive GPG operation (no TTY available in CustomScript)
# Check if keyring already exists to make script idempotent (re-runnable)
if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then
  echo "Downloading NodeSource GPG key..."
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --batch --dearmor -o /etc/apt/keyrings/nodesource.gpg
else
  echo "NodeSource GPG key already exists, skipping download"
fi

# Add repository if not already present
if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
fi

# Install Node.js 20 LTS
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 -y install nodejs

# Verify installation
node --version
npm --version

# Install PM2 globally (process manager for Node.js)
npm install -g pm2

# Create application directory
mkdir -p /opt/blogapp
chown -R azureuser:azureuser /opt/blogapp

# Create systemd service for PM2
pm2 startup systemd -u azureuser --hp /home/azureuser

# Create a placeholder health check server
cat > /opt/blogapp/health-server.js << 'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/api/health' || req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Health check server running on port ${PORT}`);
});
EOF

# Start health check server with PM2 (temporary until app is deployed)
cd /opt/blogapp
sudo -u azureuser pm2 start health-server.js --name blogapp-health
sudo -u azureuser pm2 save

echo "Node.js installation completed successfully"
'''

// =============================================================================
// App Tier VMs
// =============================================================================
// Deploy 2 VMs in different Availability Zones for high availability
// No Load Balancer - traffic comes from Web tier VMs directly
// =============================================================================

// VM in Availability Zone 1
module vmAz1 'vm.bicep' = {
  name: 'deploy-vm-app-az1'
  params: {
    location: location
    vmName: 'vm-app-az1-${environment}'
    vmSize: vmSize
    availabilityZone: '1'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    loadBalancerBackendPoolId: ''  // No LB for app tier
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(nodeInstallScript)
    tags: allTags
  }
}

// VM in Availability Zone 2
module vmAz2 'vm.bicep' = {
  name: 'deploy-vm-app-az2'
  params: {
    location: location
    vmName: 'vm-app-az2-${environment}'
    vmSize: vmSize
    availabilityZone: '2'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    loadBalancerBackendPoolId: ''  // No LB for app tier
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(nodeInstallScript)
    tags: allTags
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource IDs of App tier VMs')
output vmIds array = [
  vmAz1.outputs.vmId
  vmAz2.outputs.vmId
]

@description('Names of App tier VMs')
output vmNames array = [
  vmAz1.outputs.vmName
  vmAz2.outputs.vmName
]

@description('Private IP addresses of App tier VMs')
output privateIpAddresses array = [
  vmAz1.outputs.privateIpAddress
  vmAz2.outputs.privateIpAddress
]

@description('Principal IDs of VM managed identities')
output principalIds array = [
  vmAz1.outputs.principalId
  vmAz2.outputs.principalId
]
