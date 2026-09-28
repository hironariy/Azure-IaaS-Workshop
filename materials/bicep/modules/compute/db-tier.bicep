// =============================================================================
// Database Tier Module
// =============================================================================
// Purpose: Deploy 2 MongoDB replica set VMs across Availability Zones
// Reference: /design/AzureArchitectureDesign.md - Section 2: Compute Resources
// Reference: /design/DatabaseDesign.md - MongoDB Replica Set configuration
//
// Architecture:
//   - 2 VMs: vm-db-az1 (Primary, Zone 1), vm-db-az2 (Secondary, Zone 2)
//   - MongoDB 8.0 replica set (blogapp-rs0)
//   - Premium SSD data disks for database files
//   - Automatic failover within the replica set
//
// Traffic Flow:
//   App Tier (Express) → DB Tier (MongoDB:27017)
//   DB VM ↔ DB VM (replica set sync:27017)
//
// VM Sizing Rationale (D4s_v6):
//   - 4 vCPU, 16 GiB RAM
//   - General-purpose performance and Premium SSD support for MongoDB
//
// 2-Node Replica Set Considerations:
//   - Educational value: Demonstrates replication without complexity
//   - Limitation: Cannot survive majority loss (both nodes needed for writes)
//   - Alternative: 3-node with arbiter for production (discussed in workshop)
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Environment name (prod, dev, test)')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Workload name for naming convention')
param workloadName string = 'blogapp'

@description('Resource ID of the DB tier subnet')
param subnetId string

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for authentication')
@secure()
param sshPublicKey string

@description('VM size for database tier')
param vmSize string = 'Standard_D4s_v6'

@description('Data disk size in GB for MongoDB data')
param dataDiskSizeGB int = 128

@description('Enable Azure Monitor Agent')
param enableMonitoring bool = true

@description('Resource ID of Log Analytics workspace')
param logAnalyticsWorkspaceId string = ''

@description('Resource ID of Data Collection Rule')
param dataCollectionRuleId string = ''

@description('Tags to apply to all resources')
param tags object = {}

@description('Force update tag - changing this value forces CustomScript to re-run')
param forceUpdateTag string = ''

@description('Skip VM creation and only update extensions (for re-deployment)')
param skipVmCreation bool = false

@description('Static private IP for DB VM in Zone 1 (must be in dbSubnet range)')
param dbVmAz1PrivateIp string = '10.0.3.4'

@description('Static private IP for DB VM in Zone 2 (must be in dbSubnet range)')
param dbVmAz2PrivateIp string = '10.0.3.5'

// =============================================================================
// Variables
// =============================================================================
var defaultTags = {
  Environment: environment
  Workload: workloadName
  Tier: 'db'
  ManagedBy: 'Bicep'
}
var allTags = union(defaultTags, tags)

// Data disk configuration for MongoDB
var dataDisks = [
  {
    sizeGB: dataDiskSizeGB
    type: 'Premium_LRS'  // Premium SSD for database performance
    caching: 'None'       // Recommended for database workloads
  }
]

// MongoDB 8.0 installation script (base64 encoded)
// This script:
//   1. Updates apt packages
//   2. Mounts data disk to /data/mongodb
//   3. Installs MongoDB 8.0
//   4. Configures for replica set
//   5. Enables and starts mongod service
// Note: Replica set initialization is a separate manual step
var mongoInstallScript = replace('''
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

# ==========================================================
# Mount Data Disk
# ==========================================================
# Azure's LUN 0 links identify the managed data disk on NVMe (v6) and SCSI
# without relying on device names or accidentally selecting the OS/temp disk.
# https://learn.microsoft.com/azure/virtual-machines/linux/azure-virtual-machine-utilities
# ==========================================================

MOUNT_POINT="/data/mongodb"
EXPECTED_SIZE_GB=__DATA_DISK_SIZE_GB__
ALREADY_MOUNTED=false

echo "=== Identifying managed data disk at LUN 0 ==="
if [ -b /dev/disk/azure/data/by-lun/0 ]; then
  DATA_DISK=$(readlink -f /dev/disk/azure/data/by-lun/0)
elif [ -b /dev/disk/azure/scsi1/lun0 ]; then
  DATA_DISK=$(readlink -f /dev/disk/azure/scsi1/lun0)
else
  echo "ERROR: No managed data disk at LUN 0; check disk attachment and azure-vm-utils" >&2
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
  exit 1
fi

if [ "$(lsblk -dn -o TYPE "$DATA_DISK")" != "disk" ]; then
  echo "ERROR: LUN 0 does not point to a whole disk: $DATA_DISK" >&2
  exit 1
fi

DISK_SIZE_GB=$(($(blockdev --getsize64 "$DATA_DISK") / 1024 / 1024 / 1024))
if [ "$DISK_SIZE_GB" -ne "$EXPECTED_SIZE_GB" ]; then
  echo "ERROR: LUN 0 is ${DISK_SIZE_GB} GiB, expected ${EXPECTED_SIZE_GB} GiB" >&2
  exit 1
fi
echo "Using data disk: $DATA_DISK (${DISK_SIZE_GB} GiB)"

if mountpoint -q "$MOUNT_POINT"; then
  MOUNT_SOURCE=$(findmnt -n -o SOURCE --mountpoint "$MOUNT_POINT")
  if [ "$(readlink -f "$MOUNT_SOURCE")" != "$DATA_DISK" ]; then
    echo "ERROR: $MOUNT_POINT is mounted from $MOUNT_SOURCE instead of LUN 0" >&2
    exit 1
  fi
  ALREADY_MOUNTED=true
else
  DISK_MOUNTS=$(lsblk -nr -o MOUNTPOINTS "$DATA_DISK")
  if [ -n "$DISK_MOUNTS" ]; then
    echo "ERROR: LUN 0 or its partitions are mounted elsewhere; refusing to format" >&2
    lsblk -f "$DATA_DISK"
    exit 1
  fi
  if [ -d "$MOUNT_POINT" ] && [ -n "$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "ERROR: $MOUNT_POINT already contains files but is not mounted" >&2
    exit 1
  fi
fi

# ==========================================================
# Format and Mount (skip if already mounted at target)
# ==========================================================
if [ "$ALREADY_MOUNTED" = "true" ]; then
  echo "Disk is already mounted at $MOUNT_POINT, skipping format and mount steps"
else
  if lsblk -nr -o TYPE "$DATA_DISK" | grep -q '^part$'; then
    echo "ERROR: LUN 0 has partitions; refusing to format the whole disk" >&2
    exit 1
  fi

  if ! blkid -s TYPE "$DATA_DISK" > /dev/null 2>&1; then
    DISK_SIGNATURES=$(wipefs -n "$DATA_DISK")
    if [ -n "$DISK_SIGNATURES" ]; then
      echo "ERROR: LUN 0 has existing signatures; refusing to format" >&2
      exit 1
    fi
    echo "Creating ext4 filesystem on $DATA_DISK"
    mkfs.ext4 -F "$DATA_DISK"
  elif [ "$(blkid -s TYPE -o value "$DATA_DISK")" != "ext4" ]; then
    echo "ERROR: LUN 0 already has a non-ext4 filesystem; refusing to mount as ext4" >&2
    exit 1
  fi

  # Create mount point
  mkdir -p "$MOUNT_POINT"

  # Mount by UUID because NVMe and SCSI device names can change across boots.
  DISK_UUID=$(blkid -s UUID -o value "$DATA_DISK")
  if [ -z "$DISK_UUID" ]; then
    echo "ERROR: Could not get UUID for $DATA_DISK"
    exit 1
  fi
  echo "Disk UUID: $DISK_UUID"

  FSTAB_SOURCE=$(awk -v target="$MOUNT_POINT" '$1 !~ /^#/ && $2 == target { print $1 }' /etc/fstab)
  if [ -n "$FSTAB_SOURCE" ] && [ "$FSTAB_SOURCE" != "UUID=$DISK_UUID" ]; then
    echo "ERROR: $MOUNT_POINT has a different disk in /etc/fstab: $FSTAB_SOURCE" >&2
    exit 1
  fi
  if [ -z "$FSTAB_SOURCE" ]; then
    echo "UUID=$DISK_UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    # Reload systemd to recognize new fstab entry
    systemctl daemon-reload
  fi

  # Wait a moment for any systemd mount activity to settle
  sleep 3

  # Mount the disk with comprehensive checks and retries
  mount_with_retry() {
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
      echo "Mount attempt $attempt of $max_attempts..."
      
      # Check if mount point is already mounted
      if mountpoint -q "$MOUNT_POINT"; then
        echo "$MOUNT_POINT is already mounted"
        return 0
      fi
      
      # Check if the disk is already mounted somewhere (by UUID)
      MOUNTED_AT=$(findmnt -n -o TARGET --source "UUID=$DISK_UUID" 2>/dev/null || true)
      if [ -n "$MOUNTED_AT" ]; then
        echo "Disk (UUID=$DISK_UUID) is already mounted at $MOUNTED_AT"
        if [ "$MOUNTED_AT" = "$MOUNT_POINT" ]; then
          return 0
        fi
        echo "ERROR: LUN 0 is already mounted at $MOUNTED_AT; refusing to unmount it" >&2
        return 1
      fi
      
      # Try to mount using UUID
      echo "Attempting to mount UUID=$DISK_UUID to $MOUNT_POINT"
      if mount "UUID=$DISK_UUID" "$MOUNT_POINT" 2>/dev/null; then
        echo "Mount successful"
        return 0
      fi
      
      # Mount failed - check if systemd mounted it in the meantime
      if mountpoint -q "$MOUNT_POINT"; then
        echo "Mount point became active (systemd mount succeeded)"
      return 0
    fi
    
    echo "Mount attempt $attempt failed, waiting before retry..."
    sleep 5
    attempt=$((attempt + 1))
  done
  
  echo "ERROR: Failed to mount $DATA_DISK after $max_attempts attempts"
  return 1
}

# Execute mount with retry logic
if ! mount_with_retry; then
  echo "=== Debug: Current mounts ==="
  mount | grep -E "(mongodb|$DISK_UUID)" || echo "No relevant mounts found"
  echo "=== Debug: fstab content ==="
  grep -E "(mongodb|$DISK_UUID)" /etc/fstab || echo "No relevant fstab entries"
  echo "=== Debug: Block devices ==="
  lsblk -f
  exit 1
fi

# Verify mount succeeded
if mountpoint -q "$MOUNT_POINT"; then
  MOUNT_SOURCE=$(findmnt -n -o SOURCE --mountpoint "$MOUNT_POINT")
  if [ "$(readlink -f "$MOUNT_SOURCE")" != "$DATA_DISK" ]; then
    echo "ERROR: $MOUNT_POINT is mounted from $MOUNT_SOURCE instead of LUN 0" >&2
    exit 1
  fi
  echo "Verified: LUN 0 is mounted at $MOUNT_POINT"
  df -h "$MOUNT_POINT"
else
  echo "ERROR: $MOUNT_POINT is not mounted after all attempts"
  exit 1
fi

fi # End of ALREADY_MOUNTED check

# Set ownership for mongodb user (will be created by package)
# Done after mongodb installation

# ==========================================================
# Install MongoDB 8.0
# ==========================================================
# Import MongoDB public GPG key
apt-get -o DPkg::Lock::Timeout=120 -y install gnupg curl

# Use --batch flag for non-interactive GPG operation (no TTY available in CustomScript)
# Check if keyring already exists to make script idempotent (re-runnable)
if [ ! -f /usr/share/keyrings/mongodb-server-8.0.gpg ]; then
  echo "Downloading MongoDB GPG key..."
  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
    gpg --batch -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
else
  echo "MongoDB GPG key already exists, skipping download"
fi

# Add MongoDB repository if not already present
if [ ! -f /etc/apt/sources.list.d/mongodb-org-8.0.list ]; then
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-8.0.list
fi

# Create MongoDB data and log directories on data disk BEFORE installing MongoDB
# This ensures the directories exist when the mongod service first starts
mkdir -p /data/mongodb/db
mkdir -p /data/mongodb/log

# Update and install MongoDB
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 -y install mongodb-org

# ==========================================================
# Configure MongoDB for Replica Set
# ==========================================================
# Backup original config
cp /etc/mongod.conf /etc/mongod.conf.bak

# Set ownership (mongodb user created by package installation)
chown -R mongodb:mongodb /data/mongodb

# Configure MongoDB
# Note: MongoDB 7.0+ no longer uses storage.journal.enabled (journaling is always on)
cat > /etc/mongod.conf << 'EOF'
# MongoDB 8.0 configuration file
# Reference: https://www.mongodb.com/docs/manual/reference/configuration-options/

# Where and how to store data
storage:
  dbPath: /data/mongodb/db
  wiredTiger:
    engineConfig:
      cacheSizeGB: 8  # Use 50% of RAM (16GB VM)

# Where to write logging data
systemLog:
  destination: file
  logAppend: true
  path: /data/mongodb/log/mongod.log

# Network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0  # Listen on all interfaces (NSG controls access)

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

# Security (enable after replica set is initialized)
# security:
#   authorization: enabled
#   keyFile: /etc/mongodb/keyfile

# Replica set configuration
replication:
  replSetName: blogapp-rs0
EOF

# Stop MongoDB if it was auto-started with default config
systemctl stop mongod 2>/dev/null || true

# Ensure correct ownership after config change
chown -R mongodb:mongodb /data/mongodb

# Enable and start MongoDB with new configuration
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

# Wait for MongoDB to start (give it more time on first boot)
echo "Waiting for MongoDB to start..."
sleep 15

# Verify MongoDB is running with retries
for i in 1 2 3; do
  if systemctl is-active --quiet mongod; then
    echo "MongoDB installation completed successfully"
    # Show MongoDB version for verification
    mongod --version | head -1
    exit 0
  fi
  echo "MongoDB not ready yet, waiting... (attempt $i/3)"
  sleep 10
done

# If we get here, MongoDB failed to start
echo "MongoDB failed to start after 3 attempts"
echo "=== MongoDB service status ==="
systemctl status mongod --no-pager || true
echo "=== Last 50 lines of MongoDB log ==="
tail -50 /data/mongodb/log/mongod.log 2>/dev/null || echo "No log file found"
exit 1

# ==========================================================
# Post-Installation Notes
# ==========================================================
# To initialize the replica set, run the following on the PRIMARY node:
#
# mongosh --eval "rs.initiate({
#   _id: 'blogapp-rs0',
#   members: [
#     { _id: 0, host: 'vm-db-az1-prod:27017', priority: 2 },
#     { _id: 1, host: 'vm-db-az2-prod:27017', priority: 1 }
#   ]
# })"
#
# Check replica set status:
# mongosh --eval "rs.status()"
''', '__DATA_DISK_SIZE_GB__', string(dataDiskSizeGB))

// =============================================================================
// Database Tier VMs
// =============================================================================
// Deploy 2 VMs in different Availability Zones for high availability
// Each has a Premium SSD data disk for MongoDB data files
// =============================================================================

// Primary MongoDB VM in Availability Zone 1
module vmAz1 'vm.bicep' = {
  name: 'deploy-vm-db-az1'
  params: {
    location: location
    vmName: 'vm-db-az1-${environment}'
    vmSize: vmSize
    availabilityZone: '1'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    dataDisks: dataDisks
    loadBalancerBackendPoolId: ''  // No LB for DB tier
    privateIPAddress: dbVmAz1PrivateIp  // Static IP for predictable replica set config
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(mongoInstallScript)
    forceUpdateTag: forceUpdateTag
    skipVmCreation: skipVmCreation
    tags: union(allTags, { Role: 'primary' })
  }
}

// Secondary MongoDB VM in Availability Zone 2
module vmAz2 'vm.bicep' = {
  name: 'deploy-vm-db-az2'
  params: {
    location: location
    vmName: 'vm-db-az2-${environment}'
    vmSize: vmSize
    availabilityZone: '2'
    subnetId: subnetId
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGB: 30
    dataDisks: dataDisks
    loadBalancerBackendPoolId: ''  // No LB for DB tier
    privateIPAddress: dbVmAz2PrivateIp  // Static IP for predictable replica set config
    enableMonitoring: enableMonitoring
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    dataCollectionRuleId: dataCollectionRuleId
    customScriptContent: base64(mongoInstallScript)
    forceUpdateTag: forceUpdateTag
    skipVmCreation: skipVmCreation
    tags: union(allTags, { Role: 'secondary' })
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Resource IDs of DB tier VMs')
output vmIds array = [
  vmAz1.outputs.vmId
  vmAz2.outputs.vmId
]

@description('Names of DB tier VMs')
output vmNames array = [
  vmAz1.outputs.vmName
  vmAz2.outputs.vmName
]

@description('Private IP addresses of DB tier VMs')
output privateIpAddresses array = [
  vmAz1.outputs.privateIpAddress
  vmAz2.outputs.privateIpAddress
]

@description('Principal IDs of VM managed identities')
output principalIds array = [
  vmAz1.outputs.principalId
  vmAz2.outputs.principalId
]

@description('MongoDB connection string (after replica set initialization)')
output mongoConnectionString string = 'mongodb://${dbVmAz1PrivateIp}:27017,${dbVmAz2PrivateIp}:27017/blogapp?replicaSet=blogapp-rs0'
