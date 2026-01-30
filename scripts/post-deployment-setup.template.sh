#!/bin/bash
# =============================================================================
# Post-Deployment Setup Script - TEMPLATE
# =============================================================================
# This script configures the deployed Azure VMs after Bicep deployment:
#   1. Initializes MongoDB replica set
#   2. Creates MongoDB application users
#   3. Verifies all configurations
#
# SETUP INSTRUCTIONS:
#   1. Copy this file to post-deployment-setup.local.sh
#   2. Edit the Configuration section with your values
#   3. Make it executable: chmod +x post-deployment-setup.local.sh
#   4. Run: ./scripts/post-deployment-setup.local.sh
#
# Prerequisites:
#   - Azure CLI logged in
#   - Bicep deployment completed successfully
#   - SSH key available
#
# Usage:
#   ./scripts/post-deployment-setup.local.sh [resource-group-name]
#
# Example:
#   ./scripts/post-deployment-setup.local.sh rg-workshop-3
# =============================================================================

set -e

# =============================================================================
# Configuration - EDIT THESE VALUES
# =============================================================================
# Resource Group (can be overridden by command line argument)
RESOURCE_GROUP="${1:-<YOUR_RESOURCE_GROUP>}"

# Azure Resources
BASTION_NAME="<YOUR_BASTION_NAME>"
SSH_KEY="<PATH_TO_YOUR_SSH_KEY>"
USERNAME="azureuser"

# MongoDB Configuration
REPLICA_SET_NAME="blogapp-rs0"
ADMIN_USER="blogadmin"
ADMIN_PASSWORD="<YOUR_MONGODB_ADMIN_PASSWORD>"
APP_USER="blogapp"
# ⚠️ IMPORTANT: This password MUST match the 'mongoDbAppPassword' parameter in your .bicepparam file!
# If these don't match, the backend API will fail to connect to MongoDB.
APP_PASSWORD="<YOUR_MONGODB_APP_PASSWORD>"

# VM Names (change if using different naming convention)
DB_VM1_NAME="vm-db-az1-prod"
DB_VM2_NAME="vm-db-az2-prod"
APP_VM1_NAME="vm-app-az1-prod"
WEB_VM1_NAME="vm-web-az1-prod"

# MongoDB IPs (from Bicep deployment)
DB_VM1_IP="10.0.3.4"
DB_VM2_IP="10.0.3.5"
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Main Script
# =============================================================================

echo "=============================================================="
echo "  Post-Deployment Setup for Azure IaaS Workshop"
echo "=============================================================="
echo ""
log_info "Resource Group: $RESOURCE_GROUP"
log_info "Bastion: $BASTION_NAME"
echo ""

# Validate configuration
if [[ "$RESOURCE_GROUP" == *"<"* ]] || [[ "$BASTION_NAME" == *"<"* ]]; then
    log_error "Please edit this script and replace all <PLACEHOLDER> values!"
    log_error "Or copy post-deployment-setup.template.sh to post-deployment-setup.local.sh and edit."
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 1: Verify Deployment
# -----------------------------------------------------------------------------
log_info "Step 1: Verifying deployment..."

# Check if resource group exists
if ! az group show -n "$RESOURCE_GROUP" &>/dev/null; then
    log_error "Resource group $RESOURCE_GROUP not found!"
    exit 1
fi

# Get VM IDs
DB_VM1_ID=$(az vm show -g "$RESOURCE_GROUP" -n "$DB_VM1_NAME" --query id -o tsv 2>/dev/null || echo "")
DB_VM2_ID=$(az vm show -g "$RESOURCE_GROUP" -n "$DB_VM2_NAME" --query id -o tsv 2>/dev/null || echo "")

if [ -z "$DB_VM1_ID" ] || [ -z "$DB_VM2_ID" ]; then
    log_error "DB VMs not found! Ensure Bicep deployment completed successfully."
    exit 1
fi

log_success "All VMs found in resource group"

# -----------------------------------------------------------------------------
# Step 2: Wait for VMs to be ready
# -----------------------------------------------------------------------------
log_info "Step 2: Waiting for VMs to be ready..."

# Wait for CustomScript extensions to complete (they install MongoDB, Node.js, NGINX)
log_info "Waiting 60 seconds for CustomScript extensions to complete..."
sleep 60

log_success "VMs should be ready"

# -----------------------------------------------------------------------------
# Step 3: Initialize MongoDB Replica Set
# -----------------------------------------------------------------------------
log_info "Step 3: Initializing MongoDB replica set..."

# Check if replica set is already initialized
RS_STATUS=$(az network bastion ssh \
    --name "$BASTION_NAME" \
    -g "$RESOURCE_GROUP" \
    --target-resource-id "$DB_VM1_ID" \
    --auth-type "ssh-key" \
    --username "$USERNAME" \
    --ssh-key "$SSH_KEY" \
    -- -o StrictHostKeyChecking=no -t \
    "mongosh --quiet --eval 'rs.status().ok' 2>/dev/null || echo '0'" 2>/dev/null | tr -d '\r\n')

if [ "$RS_STATUS" = "1" ]; then
    log_warning "Replica set already initialized, skipping..."
else
    log_info "Initializing replica set $REPLICA_SET_NAME..."
    
    az network bastion ssh \
        --name "$BASTION_NAME" \
        -g "$RESOURCE_GROUP" \
        --target-resource-id "$DB_VM1_ID" \
        --auth-type "ssh-key" \
        --username "$USERNAME" \
        --ssh-key "$SSH_KEY" \
        -- -o StrictHostKeyChecking=no -t \
        "mongosh --quiet --eval 'rs.initiate({
            _id: \"$REPLICA_SET_NAME\",
            members: [
                { _id: 0, host: \"$DB_VM1_IP:27017\", priority: 2 },
                { _id: 1, host: \"$DB_VM2_IP:27017\", priority: 1 }
            ]
        })'"
    
    log_info "Waiting for replica set to elect primary (30 seconds)..."
    sleep 30
    
    log_success "Replica set initialized"
fi

# -----------------------------------------------------------------------------
# Step 4: Create MongoDB Admin User
# -----------------------------------------------------------------------------
log_info "Step 4: Creating MongoDB admin user..."

az network bastion ssh \
    --name "$BASTION_NAME" \
    -g "$RESOURCE_GROUP" \
    --target-resource-id "$DB_VM1_ID" \
    --auth-type "ssh-key" \
    --username "$USERNAME" \
    --ssh-key "$SSH_KEY" \
    -- -o StrictHostKeyChecking=no -t \
    "mongosh --quiet --eval '
        db = db.getSiblingDB(\"admin\");
        if (db.getUser(\"$ADMIN_USER\") === null) {
            db.createUser({
                user: \"$ADMIN_USER\",
                pwd: \"$ADMIN_PASSWORD\",
                roles: [
                    { role: \"root\", db: \"admin\" }
                ]
            });
            print(\"Admin user created\");
        } else {
            print(\"Admin user already exists\");
        }
    '" 2>/dev/null || log_warning "Admin user may already exist"

log_success "MongoDB admin user ready"

# -----------------------------------------------------------------------------
# Step 5: Create MongoDB Application User
# -----------------------------------------------------------------------------
log_info "Step 5: Creating MongoDB application user..."

az network bastion ssh \
    --name "$BASTION_NAME" \
    -g "$RESOURCE_GROUP" \
    --target-resource-id "$DB_VM1_ID" \
    --auth-type "ssh-key" \
    --username "$USERNAME" \
    --ssh-key "$SSH_KEY" \
    -- -o StrictHostKeyChecking=no -t \
    "mongosh --quiet --eval '
        db = db.getSiblingDB(\"blogapp\");
        if (db.getUser(\"$APP_USER\") === null) {
            db.createUser({
                user: \"$APP_USER\",
                pwd: \"$APP_PASSWORD\",
                roles: [
                    { role: \"readWrite\", db: \"blogapp\" }
                ]
            });
            print(\"Application user created\");
        } else {
            print(\"Application user already exists\");
        }
    '" 2>/dev/null || log_warning "Application user may already exist"

log_success "MongoDB application user ready"

# -----------------------------------------------------------------------------
# Step 6: Verify Configuration
# -----------------------------------------------------------------------------
log_info "Step 6: Verifying configuration..."

# Verify replica set status
log_info "Checking replica set status..."
az network bastion ssh \
    --name "$BASTION_NAME" \
    -g "$RESOURCE_GROUP" \
    --target-resource-id "$DB_VM1_ID" \
    --auth-type "ssh-key" \
    --username "$USERNAME" \
    --ssh-key "$SSH_KEY" \
    -- -o StrictHostKeyChecking=no -t \
    "mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + \": \" + m.stateStr))'"

# -----------------------------------------------------------------------------
# Step 7: Verify App Tier Environment Variables
# -----------------------------------------------------------------------------
log_info "Step 7: Verifying App tier environment variables..."

APP_VM1_ID=$(az vm show -g "$RESOURCE_GROUP" -n "$APP_VM1_NAME" --query id -o tsv 2>/dev/null || echo "")

if [ -n "$APP_VM1_ID" ]; then
    log_info "Checking /etc/environment on App VM..."
    az network bastion ssh \
        --name "$BASTION_NAME" \
        -g "$RESOURCE_GROUP" \
        --target-resource-id "$APP_VM1_ID" \
        --auth-type "ssh-key" \
        --username "$USERNAME" \
        --ssh-key "$SSH_KEY" \
        -- -o StrictHostKeyChecking=no -t \
        "cat /etc/environment | grep -E 'NODE_ENV|MONGODB_URI|ENTRA' || echo 'Environment variables not found (CustomScript may still be running)'"
fi

# -----------------------------------------------------------------------------
# Step 8: Verify Web Tier Config
# -----------------------------------------------------------------------------
log_info "Step 8: Verifying Web tier config.json..."

WEB_VM1_ID=$(az vm show -g "$RESOURCE_GROUP" -n "$WEB_VM1_NAME" --query id -o tsv 2>/dev/null || echo "")

if [ -n "$WEB_VM1_ID" ]; then
    log_info "Checking /var/www/html/config.json on Web VM..."
    az network bastion ssh \
        --name "$BASTION_NAME" \
        -g "$RESOURCE_GROUP" \
        --target-resource-id "$WEB_VM1_ID" \
        --auth-type "ssh-key" \
        --username "$USERNAME" \
        --ssh-key "$SSH_KEY" \
        -- -o StrictHostKeyChecking=no -t \
        "cat /var/www/html/config.json 2>/dev/null || echo 'config.json not found (CustomScript may still be running)'"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "  Post-Deployment Setup Complete!"
echo "=============================================================="
echo ""
log_success "MongoDB replica set: $REPLICA_SET_NAME"
log_success "MongoDB admin user: $ADMIN_USER"
log_success "MongoDB app user: $APP_USER"
echo ""
log_info "Next steps:"
echo "  1. Deploy backend application code to App VMs"
echo "  2. Build and deploy frontend to Web VMs"
echo "  3. Update NGINX configuration for API proxy"
echo ""
log_info "Connection string for backend:"
echo "  mongodb://$APP_USER:$APP_PASSWORD@$DB_VM1_IP:27017,$DB_VM2_IP:27017/blogapp?replicaSet=$REPLICA_SET_NAME&authSource=blogapp"
echo ""
