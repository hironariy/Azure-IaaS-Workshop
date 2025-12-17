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

# Install NGINX
apt-get -o DPkg::Lock::Timeout=120 -y install nginx

# Create health check endpoint
mkdir -p /var/www/html
echo 'OK' > /var/www/html/health

# Basic NGINX configuration for reverse proxy
# Configured to use Internal Load Balancer for high availability
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml;

    # Health check endpoint for Load Balancer
    location /health {
        access_log off;
        return 200 'healthy\n';
        add_header Content-Type text/plain;
    }

    # Serve static files (React frontend) with SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to Internal Load Balancer (10.0.2.10)
    # This provides high availability across both App tier VMs
    location /api/ {
        proxy_pass http://10.0.2.10:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable and restart NGINX
systemctl enable nginx
systemctl restart nginx

# ==========================================================
# Create Frontend Runtime Configuration
# ==========================================================
# /config.json is fetched by the frontend at runtime
# This allows Bicep to inject Entra IDs without rebuilding the frontend
# Reference: /design/FrontendApplicationDesign.md - Runtime Config Pattern
# ==========================================================

echo "Creating frontend runtime configuration..."

cat > /var/www/html/config.json << CONFIGEOF
{
  "ENTRA_TENANT_ID": "__ENTRA_TENANT_ID__",
  "ENTRA_FRONTEND_CLIENT_ID": "__ENTRA_FRONTEND_CLIENT_ID__",
  "ENTRA_BACKEND_CLIENT_ID": "__ENTRA_BACKEND_CLIENT_ID__",
  "API_BASE_URL": "/api"
}
CONFIGEOF

# Set proper permissions
chmod 644 /var/www/html/config.json

echo "Frontend runtime configuration created at /var/www/html/config.json"
echo "NGINX installation completed successfully"
