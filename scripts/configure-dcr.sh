#!/bin/bash
# =============================================================================
# Create and Configure Data Collection Rule for Azure Monitor
# =============================================================================
# Purpose: Create DCR and associate it with VMs after Bicep deployment
#
# This script:
#   1. Waits for Log Analytics tables to initialize
#   2. Creates a new Data Collection Rule with Syslog and Performance counters
#   3. Associates the DCR with all VMs in the resource group
#
# Why post-deployment?
#   - Log Analytics tables (Syslog, Perf) take 1-5 minutes to initialize
#   - DCR creation validates tables at creation time
#   - Bicep deployment would fail with "InvalidOutputTable" error
#
# Prerequisites:
#   - Azure CLI installed and logged in
#   - Log Analytics workspace already deployed
#   - VMs already deployed with Azure Monitor Agent extension
#
# Usage:
#   ./configure-dcr.sh <resource-group-name>
#
# Example:
#   ./configure-dcr.sh rg-blogapp-prod
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Resource group name required${NC}"
    echo "Usage: $0 <resource-group-name>"
    echo "Example: $0 rg-blogapp-prod"
    exit 1
fi

RESOURCE_GROUP="$1"
LOCATION=$(az group show -n "$RESOURCE_GROUP" --query location -o tsv)
DCR_NAME="dcr-blogapp-prod"

echo -e "${GREEN}=== Creating Data Collection Rule ===${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"

# Get Log Analytics workspace
LOG_ANALYTICS_WORKSPACE=$(az monitor log-analytics workspace list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0]" -o json 2>/dev/null)

if [ -z "$LOG_ANALYTICS_WORKSPACE" ] || [ "$LOG_ANALYTICS_WORKSPACE" = "null" ]; then
    echo -e "${RED}Error: No Log Analytics workspace found in resource group $RESOURCE_GROUP${NC}"
    exit 1
fi

LOG_ANALYTICS_WORKSPACE_ID=$(echo "$LOG_ANALYTICS_WORKSPACE" | jq -r '.id')
LOG_ANALYTICS_WORKSPACE_NAME=$(echo "$LOG_ANALYTICS_WORKSPACE" | jq -r '.name')

echo "Found Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE_NAME"

# Wait for tables to initialize
echo -e "${YELLOW}Waiting 60 seconds for Log Analytics tables (Syslog, Perf) to initialize...${NC}"
echo "This is necessary because new workspaces don't have tables immediately."
sleep 60

# Check if DCR already exists
EXISTING_DCR=$(az monitor data-collection rule show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DCR_NAME" 2>/dev/null || echo "")

if [ -n "$EXISTING_DCR" ]; then
    echo -e "${YELLOW}DCR '$DCR_NAME' already exists. Deleting and recreating...${NC}"
    az monitor data-collection rule delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DCR_NAME" \
        --yes
    sleep 5
fi

echo -e "${GREEN}Creating Data Collection Rule: $DCR_NAME${NC}"

# Create DCR using Azure CLI
az monitor data-collection rule create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DCR_NAME" \
    --location "$LOCATION" \
    --kind "Linux" \
    --description "Data Collection Rule for Azure IaaS Workshop VMs" \
    --log-analytics "name=logAnalyticsDestination workspaceResourceId=$LOG_ANALYTICS_WORKSPACE_ID" \
    --syslog "name=syslogDataSource streams=Microsoft-Syslog facilityNames=[auth,authpriv,daemon,syslog,user] logLevels=[Debug,Info,Notice,Warning,Error,Critical,Alert,Emergency]" \
    --performance-counters "name=perfCounterDataSource streams=Microsoft-Perf samplingFrequencyInSeconds=60 counterSpecifiers=['Processor(*)\\% Processor Time','Processor(*)\\% User Time','Processor(*)\\% Idle Time','Memory(*)\\% Used Memory','Memory(*)\\Available MBytes Memory','LogicalDisk(*)\\% Used Space','LogicalDisk(*)\\Free Megabytes','Network(*)\\Total Bytes Transmitted','Network(*)\\Total Bytes Received']" \
    --data-flows "streams=[Microsoft-Syslog] destinations=[logAnalyticsDestination]" \
    --data-flows "streams=[Microsoft-Perf] destinations=[logAnalyticsDestination]"

echo -e "${GREEN}DCR created successfully!${NC}"

# Get DCR ID
DCR_ID=$(az monitor data-collection rule show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DCR_NAME" \
    --query id -o tsv)

echo -e "${BLUE}DCR ID: $DCR_ID${NC}"

# Associate DCR with all VMs
echo ""
echo -e "${GREEN}=== Associating DCR with VMs ===${NC}"

VM_LIST=$(az vm list --resource-group "$RESOURCE_GROUP" --query "[].{name:name,id:id}" -o json)
VM_COUNT=$(echo "$VM_LIST" | jq length)

if [ "$VM_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No VMs found in resource group. Skipping DCR association.${NC}"
else
    echo "Found $VM_COUNT VM(s) to associate with DCR"
    
    echo "$VM_LIST" | jq -c '.[]' | while read -r vm; do
        VM_NAME=$(echo "$vm" | jq -r '.name')
        VM_ID=$(echo "$vm" | jq -r '.id')
        ASSOCIATION_NAME="configurationAccessEndpoint"
        
        echo -e "${BLUE}Associating DCR with VM: $VM_NAME${NC}"
        
        # Check if association already exists
        EXISTING_ASSOC=$(az monitor data-collection rule association list \
            --resource "$VM_ID" \
            --query "[?name=='$ASSOCIATION_NAME']" -o json 2>/dev/null || echo "[]")
        
        if [ "$(echo "$EXISTING_ASSOC" | jq length)" -gt 0 ]; then
            echo "  Association already exists, updating..."
            az monitor data-collection rule association delete \
                --name "$ASSOCIATION_NAME" \
                --resource "$VM_ID" \
                --yes 2>/dev/null || true
        fi
        
        az monitor data-collection rule association create \
            --name "$ASSOCIATION_NAME" \
            --resource "$VM_ID" \
            --rule-id "$DCR_ID"
        
        echo -e "  ${GREEN}✓ Associated${NC}"
    done
fi

echo ""
echo -e "${GREEN}=== DCR Configuration Complete ===${NC}"
echo ""
echo "Data Collection Rule '$DCR_NAME' is now configured to collect:"
echo "  📊 Syslog (auth, authpriv, daemon, syslog, user facilities)"
echo "  📈 Performance Counters (CPU, Memory, Disk, Network)"
echo ""
echo "Data will appear in Log Analytics within 5-10 minutes."
echo ""
echo "To verify DCR configuration:"
echo "  az monitor data-collection rule show -g $RESOURCE_GROUP -n $DCR_NAME"
echo ""
echo "To verify VM associations:"
echo "  az monitor data-collection rule association list --resource <VM_ID>"
