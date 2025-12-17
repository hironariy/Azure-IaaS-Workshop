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

# ==========================================================
# Generate Self-Signed SSL Certificate
# ==========================================================
# For workshop purposes - production should use Let's Encrypt or Azure-managed certs
# Certificate is valid for 365 days
# ==========================================================

echo "Generating self-signed SSL certificate..."

mkdir -p /etc/nginx/ssl

# Generate self-signed certificate (non-interactive)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Workshop/OU=IT/CN=blogapp.local"

# Set proper permissions
chmod 600 /etc/nginx/ssl/nginx.key
chmod 644 /etc/nginx/ssl/nginx.crt

echo "SSL certificate generated successfully"

# ==========================================================
# NGINX Configuration with HTTPS
# ==========================================================
# - Port 80: Health check only (for Azure LB probe)
# - Port 443: HTTPS with self-signed cert (main traffic)
# - API proxy to Internal Load Balancer
# ==========================================================

cat > /etc/nginx/sites-available/default << 'EOF'
# HTTP server - health check only
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # Health check endpoint for Load Balancer (must stay on HTTP)
    location /health {
        access_log off;
        return 200 'healthy\n';
        add_header Content-Type text/plain;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS server - main application
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    root /var/www/html;
    index index.html;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml;

    # Health check endpoint (also on HTTPS for completeness)
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
    # Note: NO trailing slash - preserves /api prefix (backend expects /api/posts)
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
