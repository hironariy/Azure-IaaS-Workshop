#!/bin/bash
# =============================================================================
# Post-Deployment Setup Script - TEMPLATE
# =============================================================================
# This script configures the deployed Azure VMs after Bicep deployment:
#   1. Initializes the 3-member MongoDB replica set (Issue #30)
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
#
# Re-running is safe (idempotent): an already-initialized replica set is never
# re-initiated or force-reconfigured, and existing users are kept.
# Existing 2-node environments: add the 3rd member with the migration
# procedure in the troubleshooting runbook (section 7.2), not with this script.
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
DB_VM3_NAME="vm-db-az3-prod"
APP_VM1_NAME="vm-app-az1-prod"
WEB_VM1_NAME="vm-web-az1-prod"

# MongoDB IPs (from Bicep deployment)
DB_VM1_IP="10.0.3.4"
DB_VM2_IP="10.0.3.5"
DB_VM3_IP="10.0.3.6"
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
DB_VM3_ID=$(az vm show -g "$RESOURCE_GROUP" -n "$DB_VM3_NAME" --query id -o tsv 2>/dev/null || echo "")

if [ -z "$DB_VM1_ID" ] || [ -z "$DB_VM2_ID" ]; then
    log_error "DB VMs not found! Ensure Bicep deployment completed successfully."
    exit 1
fi
if [ -z "$DB_VM3_ID" ]; then
    # Issue #30: the replica set needs 3 data-bearing voting members so that
    # any single-node failure still leaves a majority (2 of 3).
    log_error "$DB_VM3_NAME not found. The workshop now uses a 3-node replica set (Issue #30)."
    log_error "New deployment: re-run the Bicep deployment (it creates vm-db-az3)."
    log_error "Existing 2-node environment: follow troubleshooting runbook 7.2 '2-node to 3-node migration'."
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

# DB VMs reboot once after the CustomScript to switch to the Ubuntu 24.04 LTS
# Azure kernel (6.8), because MongoDB 8.0 does not start on Linux >= 6.19
# (Issue #26). mongod is only reachable after that reboot, so poll each DB VM
# until: kernel is 6.8.x, mongod is active, and db.hello() answers.
DB_READY_TIMEOUT_SEC="${DB_READY_TIMEOUT_SEC:-900}"
DB_READY_INTERVAL_SEC=30

wait_for_db_ready() {
    local vm_name="$1" vm_id="$2"
    local elapsed=0 out line kernel="?" mongod_state="?" hello="?"
    log_info "Waiting for MongoDB on $vm_name (6.8 LTS kernel + mongod running, timeout ${DB_READY_TIMEOUT_SEC}s)..."
    while [ "$elapsed" -lt "$DB_READY_TIMEOUT_SEC" ]; do
        # Fails while the VM is rebooting; that is expected, just retry.
        out=$(az network bastion ssh \
            --name "$BASTION_NAME" \
            -g "$RESOURCE_GROUP" \
            --target-resource-id "$vm_id" \
            --auth-type "ssh-key" \
            --username "$USERNAME" \
            --ssh-key "$SSH_KEY" \
            -- -o StrictHostKeyChecking=no -o ConnectTimeout=20 \
            "echo DBREADY kernel=\$(uname -r) mongod=\$(systemctl is-active mongod) hello=\$(mongosh --quiet --eval 'db.hello().ok' 2>/dev/null || echo 0)" \
            2>/dev/null || true)
        line=$(printf '%s\n' "$out" | tr -d '\r' | grep '^DBREADY ' | tail -1 || true)
        if [ -n "$line" ]; then
            kernel=$(printf '%s\n' "$line" | sed -n 's/.*kernel=\([^ ]*\).*/\1/p')
            mongod_state=$(printf '%s\n' "$line" | sed -n 's/.*mongod=\([^ ]*\).*/\1/p')
            hello=$(printf '%s\n' "$line" | sed -n 's/.*hello=\([^ ]*\).*/\1/p')
            if [[ "$kernel" == 6.8.* ]] && [ "$mongod_state" = "active" ] && [ "$hello" = "1" ]; then
                log_success "$vm_name ready: kernel=$kernel mongod=$mongod_state"
                return 0
            fi
            log_info "  $vm_name not ready yet: kernel=$kernel mongod=$mongod_state hello=$hello (${elapsed}s)"
        else
            log_info "  $vm_name not reachable yet (rebooting into the LTS kernel?) (${elapsed}s)"
        fi
        sleep "$DB_READY_INTERVAL_SEC"
        elapsed=$((elapsed + DB_READY_INTERVAL_SEC))
    done
    log_error "$vm_name: MongoDB is not ready after ${DB_READY_TIMEOUT_SEC}s (last: kernel=$kernel mongod=$mongod_state hello=$hello)."
    log_error "MongoDB 8.0 needs the 6.8 LTS kernel (Issue #26). On $vm_name run:"
    log_error "  uname -r ; sudo blogapp-kernel-track status ; sudo journalctl -u mongod -u blogapp-kernel-track-finalize -b --no-pager | tail -50"
    log_error "Fix: troubleshooting runbook section 7.1 'MongoDB Does Not Start: Linux Kernel 6.19 Or Newer' (Issue #26)."
    log_error "Re-run this script when all 3 DB VMs are ready (it is safe to re-run)."
    exit 1
}

wait_for_db_ready "$DB_VM1_NAME" "$DB_VM1_ID"
wait_for_db_ready "$DB_VM2_NAME" "$DB_VM2_ID"
wait_for_db_ready "$DB_VM3_NAME" "$DB_VM3_ID"

log_success "VMs are ready"

# -----------------------------------------------------------------------------
# Step 3: Initialize MongoDB Replica Set
# -----------------------------------------------------------------------------
log_info "Step 3: Initializing MongoDB replica set..."

# Replica set seed list: all 3 members. mongosh/drivers use it to find the
# current PRIMARY, so later steps work even if an election already moved the
# PRIMARY away from vm-db-az1.
RS_HOSTS="$DB_VM1_IP:27017,$DB_VM2_IP:27017,$DB_VM3_IP:27017"
RS_URI="mongodb://$RS_HOSTS/?replicaSet=$REPLICA_SET_NAME"

# Run a command on DB VM 1 through Bastion.
db_vm1_ssh() {
    az network bastion ssh \
        --name "$BASTION_NAME" \
        -g "$RESOURCE_GROUP" \
        --target-resource-id "$DB_VM1_ID" \
        --auth-type "ssh-key" \
        --username "$USERNAME" \
        --ssh-key "$SSH_KEY" \
        -- -o StrictHostKeyChecking=no -t \
        "$1"
}

# Check whether the replica set is already initialized (idempotency).
# rs.conf() throws NotYetInitialized on a fresh node.
RS_STATE_LINE=$(db_vm1_ssh "mongosh --quiet --eval 'try { print(\"RSSTATE initialized \" + rs.conf().members.length) } catch (e) { print(\"RSSTATE uninitialized \" + e.codeName) }'" 2>/dev/null \
    | tr -d '\r' | grep '^RSSTATE ' | tail -1 || true)
log_info "Replica set state on $DB_VM1_NAME: ${RS_STATE_LINE:-unknown}"

if [[ "$RS_STATE_LINE" == "RSSTATE initialized "* ]]; then
    RS_MEMBER_COUNT="${RS_STATE_LINE##* }"
    log_warning "Replica set already initialized ($RS_MEMBER_COUNT members), skipping rs.initiate."
    if [ "$RS_MEMBER_COUNT" != "3" ]; then
        # Never force-reconfigure here: adding a member to a live set must be
        # done with rs.add() after the new VM is ready (runbook 7.2).
        log_warning "Expected 3 members. For an existing 2-node set, follow troubleshooting runbook 7.2 (rs.add, wait for initial sync)."
    fi
elif [[ "$RS_STATE_LINE" == "RSSTATE uninitialized "* ]]; then
    log_info "Initializing replica set $REPLICA_SET_NAME with 3 members..."

    # All 3 members are data-bearing, voting (votes: 1) and electable
    # (priority > 0). vm-db-az1 gets priority 2 only to make the INITIAL
    # PRIMARY deterministic for the workshop steps. Side effect to observe on
    # Day 2: after vm-db-az1 recovers and catches up, it calls a "priority
    # takeover" election and becomes PRIMARY again (a second short election).
    db_vm1_ssh "mongosh --quiet --eval 'rs.initiate({
            _id: \"$REPLICA_SET_NAME\",
            members: [
                { _id: 0, host: \"$DB_VM1_IP:27017\", priority: 2, votes: 1 },
                { _id: 1, host: \"$DB_VM2_IP:27017\", priority: 1, votes: 1 },
                { _id: 2, host: \"$DB_VM3_IP:27017\", priority: 1, votes: 1 }
            ]
        })'"

    log_success "Replica set initiated"
else
    log_error "Could not read the replica set state from $DB_VM1_NAME (got: '${RS_STATE_LINE:-nothing}')."
    log_error "Check: mongosh --eval 'db.hello()' on $DB_VM1_NAME, then re-run this script."
    exit 1
fi

# Wait until the set is healthy: exactly 1 PRIMARY and 2 SECONDARY.
# (Replaces a fixed sleep: initial sync of an empty set takes ~10-30s.)
log_info "Waiting for 1 PRIMARY + 2 SECONDARY (up to 3 minutes)..."
RS_HEALTH=$(db_vm1_ssh "mongosh --quiet --eval 'for (let i = 0; i < 36; i++) { let p = 0, s = 0; try { rs.status().members.forEach(m => { if (m.stateStr === \"PRIMARY\") p++; if (m.stateStr === \"SECONDARY\") s++; }); } catch (e) {} if (p === 1 && s === 2) { print(\"RSHEALTH ok\"); quit(0); } sleep(5000); } print(\"RSHEALTH timeout\");'" 2>/dev/null \
    | tr -d '\r' | grep '^RSHEALTH ' | tail -1 || true)
if [ "$RS_HEALTH" = "RSHEALTH ok" ]; then
    log_success "Replica set healthy: 1 PRIMARY + 2 SECONDARY"
else
    log_warning "Replica set did not reach 1 PRIMARY + 2 SECONDARY in time (${RS_HEALTH:-no answer}). See Step 6 output and troubleshooting runbook 7."
fi

# -----------------------------------------------------------------------------
# Step 4: Create MongoDB Admin User
# -----------------------------------------------------------------------------
log_info "Step 4: Creating MongoDB admin user..."
# Connect with the replica set URI so the write goes to the current PRIMARY
# (createUser uses w:"majority" by default on a replica set).

az network bastion ssh \
    --name "$BASTION_NAME" \
    -g "$RESOURCE_GROUP" \
    --target-resource-id "$DB_VM1_ID" \
    --auth-type "ssh-key" \
    --username "$USERNAME" \
    --ssh-key "$SSH_KEY" \
    -- -o StrictHostKeyChecking=no -t \
    "mongosh --quiet \"$RS_URI\" --eval '
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
    "mongosh --quiet \"$RS_URI\" --eval '
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
    "mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name + \": \" + m.stateStr + \" (health=\" + m.health + \")\"))'"
log_info "Expected: 3 members = 1 PRIMARY + 2 SECONDARY (10.0.3.4 is normally PRIMARY)."

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
echo "  mongodb://$APP_USER:$APP_PASSWORD@$RS_HOSTS/blogapp?replicaSet=$REPLICA_SET_NAME&authSource=blogapp&w=majority"
echo ""
