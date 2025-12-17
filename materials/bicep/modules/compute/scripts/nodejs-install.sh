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

# ==========================================================
# Inject Production Environment Variables
# ==========================================================
# These environment variables are loaded by Node.js process.env
# /etc/environment makes them available to all users and services
# Reference: /design/BackendApplicationDesign.md - Environment-Aware Configuration
# ==========================================================

echo "Configuring production environment variables..."

cat >> /etc/environment << ENVEOF
# ==========================================================
# Backend Application Environment Variables
# Injected by Bicep CustomScript Extension
# DO NOT EDIT MANUALLY - regenerated on VM provisioning
# ==========================================================
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
MONGODB_URI=__MONGODB_URI__
ENTRA_TENANT_ID=__ENTRA_TENANT_ID__
ENTRA_CLIENT_ID=__ENTRA_CLIENT_ID__
ENVEOF

# Make environment variables available immediately for current session
export NODE_ENV=production
export PORT=3000
export LOG_LEVEL=info
export MONGODB_URI="__MONGODB_URI__"
export ENTRA_TENANT_ID="__ENTRA_TENANT_ID__"
export ENTRA_CLIENT_ID="__ENTRA_CLIENT_ID__"

# Also create /opt/blogapp/.env for PM2 and direct Node.js execution
cat > /opt/blogapp/.env << DOTENVEOF
# Production environment configuration
# Injected by Bicep CustomScript Extension
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
MONGODB_URI=__MONGODB_URI__
ENTRA_TENANT_ID=__ENTRA_TENANT_ID__
ENTRA_CLIENT_ID=__ENTRA_CLIENT_ID__
DOTENVEOF

chown azureuser:azureuser /opt/blogapp/.env
chmod 600 /opt/blogapp/.env

echo "Environment variables configured successfully"
echo "Node.js installation completed successfully"
