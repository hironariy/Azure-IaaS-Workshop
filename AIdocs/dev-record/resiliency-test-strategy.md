# Resiliency Test Strategy for Azure IaaS Workshop

**Date:** January 6, 2026  
**Author:** AI Workshop Agent  
**Status:** Draft  
**Purpose:** Define practical resiliency tests for the multi-tier blog application

---

日本語版: [Azure IaaS ワークショップの回復性テスト戦略](./resiliency-test-strategy.ja.md)

## Executive Summary

This document outlines a comprehensive resiliency testing strategy for the Azure IaaS Workshop. The tests are designed to:

1. **Validate** the high availability architecture
2. **Educate** workshop participants on failure modes and recovery
3. **Demonstrate** Azure's built-in resilience features

### Architecture Recap

```
Internet → Application Gateway (Zone-redundant)
         → Web Tier: VM-AZ1 + VM-AZ2 (NGINX)
         → Internal LB
         → App Tier: VM-AZ1 + VM-AZ2 (Node.js)
         → Database Tier: Primary (AZ1) + Secondary (AZ2) (MongoDB Replica Set)
```

### Key Resilience Features to Test

| Feature | Component | Expected Behavior |
|---------|-----------|-------------------|
| Load Balancer Health Probes | Application Gateway, Internal LB | Remove unhealthy instances |
| Cross-Zone Redundancy | All tiers | Survive single zone failure |
| MongoDB Replica Set | Database tier | ⚠️ Manual failover required (2-member limitation) |
| Stateless Application Tiers | Web, App | Any instance can handle requests |

### Database VM IP Addresses (Static Assignment)

The Bicep templates assign **static private IPs** to database VMs for predictable replica set configuration:

| VM Name | Availability Zone | Private IP | MongoDB Role (Initial) |
|---------|-------------------|------------|------------------------|
| `vm-db-az1-prod` | Zone 1 | `10.0.3.4` | Primary |
| `vm-db-az2-prod` | Zone 2 | `10.0.3.5` | Secondary |

> **Note:** Static IPs are defined in `modules/compute/db-tier.bicep` parameters:
> - `dbVmAz1PrivateIp` = `10.0.3.4`
> - `dbVmAz2PrivateIp` = `10.0.3.5`

---

## Test Categories

### Level 1: Beginner (Safe, Reversible)
- VM stop/start
- Application process stop/start
- Basic health check verification

### Level 2: Intermediate (Requires monitoring)
- Database failover
- Health probe manipulation
- Traffic distribution verification

### Level 3: Advanced (Requires planning)
- Simulated zone failure
- Network partition
- Chaos engineering

---

## Level 1: Beginner Tests

### Test 1.1: Web Tier VM Failure

**Objective:** Verify Application Gateway removes failed VM from backend pool.

**Prerequisites:**
- Application deployed and accessible
- Both Web VMs running and healthy
- Browser or curl access to application

**Test Steps:**

```bash
# 1. Verify both Web VMs are healthy
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# Expected output: Both servers show "Healthy"
# [
#   { "address": "10.0.1.4", "health": "Healthy" },
#   { "address": "10.0.1.5", "health": "Healthy" }
# ]

# 2. Open application in browser and verify it works
curl -k https://<YOUR_APPGW_FQDN>/

# 3. Stop one Web VM
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod

# 4. Wait for health probe to detect failure (30-60 seconds)
sleep 60

# 5. Verify application still works
curl -k https://<YOUR_APPGW_FQDN>/

# 6. Check backend health (one should be unhealthy)
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# 7. Restore the VM
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod

# 8. Wait for VM to become healthy again
sleep 120

# 9. Verify both VMs are healthy
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'
```

**Expected Results:**
| Step | Expected Outcome |
|------|------------------|
| Step 2 | HTML response (200 OK) |
| Step 5 | HTML response (200 OK) - still working! |
| Step 6 | One server "Unhealthy", one "Healthy" |
| Step 9 | Both servers "Healthy" |

**Learning Points:**
- Application Gateway automatically detects VM failure via health probes
- Traffic is routed only to healthy instances
- No manual intervention required for failover
- Recovery is automatic when VM becomes healthy

---

### Test 1.2: App Tier VM Failure

**Objective:** Verify Internal Load Balancer removes failed VM from backend pool.

**Test Steps:**

```bash
# 1. Connect to a Web VM to test Internal LB
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. From Web VM, test API through Internal LB
curl http://10.0.2.10:3000/health
# Expected: {"status":"healthy",...}

# 3. Exit Web VM session
exit

# 4. Stop one App VM
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod

# 5. Wait for health probe (30-60 seconds)
sleep 60

# 6. Reconnect to Web VM and test API via Internal LB
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# Test backend health directly via Internal LB (not through NGINX /api/ proxy)
curl http://10.0.2.10:3000/health
# Expected: Still returns {"status":"healthy",...}

# 7. Test from browser - full application should work
exit
# Test API endpoint (not health - backend health is at /health, not /api/health)
curl -k https://<YOUR_APPGW_FQDN>/api/posts

# 8. Restore the VM
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod
```

**Expected Results:**
- API continues to work with one App VM down
- Internal Load Balancer health probe detects failure
- Traffic routed to remaining healthy App VM

---

### Test 1.3: Application Process Failure (NGINX)

**Objective:** Verify health probes detect application-level failures (not just VM failures).

**Why This Test Matters:**
- VMs rarely fail completely
- Applications crash more frequently
- Health probes should detect application health, not just network connectivity

**Test Steps:**

```bash
# 1. Connect to Web VM
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Verify NGINX is running
sudo systemctl status nginx

# 3. Stop NGINX (application crashes)
sudo systemctl stop nginx

# 4. Verify local health check fails
curl http://localhost/health
# Expected: Connection refused

# 5. Exit and wait for health probe
exit
sleep 60

# 6. Test application - should still work (via other VM)
curl -k https://<YOUR_APPGW_FQDN>/

# 7. Reconnect and restart NGINX
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

sudo systemctl start nginx

# 8. Verify recovery
curl http://localhost/api/posts
# Expected: healthy
```

**Learning Points:**
- Health probes detect application failures, not just VM failures
- Stopping a process is more realistic than stopping a VM
- Demonstrates defense-in-depth: health checks at application level

---

### Test 1.4: Application Process Failure (Node.js/PM2)

**Objective:** Verify Internal LB detects Node.js application failure.

**Test Steps:**

```bash
# 1. Connect to App VM
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-app-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Check PM2 status
pm2 list

# 3. Stop the application
pm2 stop blogapp-api

# 4. Verify local health check fails
curl http://localhost:3000/health
# Expected: Connection refused

# 5. Exit and test through Application Gateway
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Still works (via other App VM)
# Note: Use /api/posts because backend health is at /health, not /api/health

# 6. Reconnect and restart application
az network bastion ssh ... # same as above
pm2 start blogapp-api
pm2 list  # Verify running
```

---

## Level 2: Intermediate Tests

### Test 2.1: MongoDB Primary Failover

**Objective:** Verify MongoDB replica set automatic failover.

**Prerequisites:**
- MongoDB replica set initialized with two members
- Application connected to replica set

**Test Steps:**

```bash
# 1. Connect to current primary (vm-db-az1-prod by default)
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-db-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Check current replica set status
mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
# Expected (with static IP assignment from Bicep):
# [
#   { name: "10.0.3.4:27017", state: "PRIMARY" },   # vm-db-az1-prod (Zone 1)
#   { name: "10.0.3.5:27017", state: "SECONDARY" }  # vm-db-az2-prod (Zone 2)
# ]

# 3. Force primary to step down (triggers election)
mongosh --eval 'rs.stepDown(60)'
# This forces the primary to become secondary for 60 seconds

# 4. Check new status (secondary should become primary)
mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
# Expected:
# [
#   { name: "10.0.3.4:27017", state: "SECONDARY" },  # vm-db-az1-prod
#   { name: "10.0.3.5:27017", state: "PRIMARY" }     # vm-db-az2-prod (now primary)
# ]

# 5. Exit and test application
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Still returns posts (application reconnected to new primary)

# 6. Create a new post to verify writes work
# Use browser or API call with authentication

# 7. Verify data on both members
az network bastion ssh ... # connect to vm-db-az2-prod
mongosh --eval 'db.posts.countDocuments()'
```

**Expected Results:**
| Step | Expected Outcome |
|------|------------------|
| Step 3 | Primary steps down, election begins |
| Step 4 | New primary elected (typically within 10-15 seconds) |
| Step 5 | Application continues to work |
| Step 6 | New posts can be created |

**Learning Points:**
- MongoDB replica set provides automatic failover
- Application using replica set connection string handles failover transparently
- Election typically completes in 10-15 seconds
- Writes are unavailable during election (brief window)

---

### Test 2.2: MongoDB Primary VM Stop (Optional - Advanced)

**Objective:** Understand MongoDB replica set behavior when primary VM is completely unavailable.

> ⏱️ **Optional Test** - This test requires manual MongoDB recovery (Test 2.2a) which can take 15-30 minutes. Skip if time is limited.

> ⚠️ **Critical Limitation: 2-Member Replica Set**
>
> With only 2 members, **automatic failover will NOT occur** when the primary is stopped.
> MongoDB requires a **majority vote** to elect a new primary:
>
> | Members | Majority Needed | When 1 Down | Result |
> |---------|-----------------|-------------|--------|
> | 2 | 2 | Only 1 vote | ❌ No election possible |
> | 3 | 2 | 2 votes | ✅ Can elect new primary |
>
> The surviving secondary remains as SECONDARY because it cannot achieve majority alone.
> **This test demonstrates the limitation and teaches manual recovery.**

**Test Steps:**

```bash
# 1. Identify current primary
az network bastion ssh ... # connect to any DB VM
mongosh --eval 'rs.isMaster().primary'
# Note which VM is primary (assume 10.0.3.4 / vm-db-az1-prod)

# 2. Stop the primary VM (from your local machine)
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod

# 3. Wait and observe
sleep 20

# 4. Connect to other DB VM and check status
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-db-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

mongosh --eval 'rs.isMaster().ismaster'
# Expected: false (NOT true!) - cannot self-elect without majority

mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
# Expected:
# [
#   { name: "10.0.3.4:27017", state: "(not reachable/healthy)" },  # vm-db-az1-prod (stopped)
#   { name: "10.0.3.5:27017", state: "SECONDARY" }  # vm-db-az2-prod - Still secondary!
# ]

# 5. Test application - READS WILL FAIL (no primary)
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Error - application cannot connect to primary for reads
```

**Expected Results (Without Manual Intervention):**
| Step | Expected Outcome |
|------|------------------|
| Step 4 | `rs.isMaster().ismaster` returns **false** |
| Step 5 | Application returns error (no primary available) |

---

### Test 2.2a: Manual MongoDB Recovery (Optional - Advanced)

**Objective:** Learn how to manually promote the surviving secondary to primary.

> ⏱️ **Optional Test** - This is the recovery procedure for Test 2.2 and Test 3.1. Skip if you skipped those tests.

**When to Use:** When primary VM is down and automatic election cannot occur (2-member replica set).

**Recovery Steps:**

```bash
# 1. Connect to the surviving secondary (vm-db-az2-prod)
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-db-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Connect to MongoDB and check current status
mongosh

# 3. View current configuration
rs.status()

# 4. Get current replica set configuration
cfg = rs.conf()

# 5. Remove the unavailable member from configuration
# If vm-db-az1-prod (10.0.3.4) is stopped:
cfg.members = cfg.members.filter(m => m.host !== "10.0.3.4:27017")
# If vm-db-az2-prod (10.0.3.5) is stopped instead:
# cfg.members = cfg.members.filter(m => m.host !== "10.0.3.5:27017")

# 6. Force reconfigure (bypasses "need a primary" requirement)
rs.reconfig(cfg, {force: true})

# 7. Verify this node is now PRIMARY
rs.isMaster().ismaster
# Expected: true

rs.status()
# Expected: Single member showing as PRIMARY

# 8. Exit MongoDB shell and test application
exit  # from mongosh
exit  # from SSH

curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Success! Application works again
```

**After Original Primary VM Starts - Re-add to Replica Set:**

```bash
# 1. Start the original primary VM
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod

# 2. Wait for VM to fully start
sleep 60

# 3. Connect to the current primary (vm-db-az2-prod)
az network bastion ssh ... # connect to vm-db-az2-prod
mongosh

# 4. Re-add the recovered VM as a new member
# Add back vm-db-az1-prod:
rs.add("10.0.3.4:27017")

# 5. Verify both members are present
rs.status().members.map(m => ({name: m.name, state: m.stateStr}))
# Expected:
# [
#   { name: "10.0.3.5:27017", state: "PRIMARY" },     # vm-db-az2-prod (current primary)
#   { name: "10.0.3.4:27017", state: "SECONDARY" }    # vm-db-az1-prod (rejoined)
# ]

# 6. Exit and verify application
exit
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**Important Notes:**
- The original primary rejoins as **SECONDARY** (does not reclaim leadership)
- Any writes that occurred only on the old primary before it went down are **lost**
- This is why production systems use **3+ members** or **2 data + 1 arbiter**

**Learning Points:**
- 2-member replica sets cannot automatically fail over
- `rs.reconfig({force: true})` allows reconfiguration without a primary
- Manual intervention is required for disaster recovery
- Production recommendation: Use 3 members or add an arbiter

---

### Test 2.3: Verify Traffic Distribution

**Objective:** Confirm load balancer distributes traffic across multiple instances.

**Test Steps:**

```bash
# 1. Connect to both Web VMs and tail access logs

# Terminal 1: Web VM AZ1
az network bastion ssh ... --name vm-web-az1-prod
sudo tail -f /var/log/nginx/access.log

# Terminal 2: Web VM AZ2
az network bastion ssh ... --name vm-web-az2-prod
sudo tail -f /var/log/nginx/access.log

# 2. Generate traffic from your machine
for i in {1..20}; do
  curl -k https://<YOUR_APPGW_FQDN>/ > /dev/null 2>&1
  sleep 1
done

# 3. Observe logs in both terminals
# You should see requests appearing in BOTH logs
# Distribution may not be exactly 50/50 but should be balanced
```

**Expected Results:**
- Requests appear in both Web VM logs
- Distribution is roughly balanced
- Demonstrates Application Gateway's load balancing

---

### Test 2.4: Health Probe Manipulation

**Objective:** Understand how health probes affect traffic routing.

**Test Steps:**

```bash
# 1. Connect to Web VM
az network bastion ssh ... --name vm-web-az1-prod

# 2. Modify health endpoint to return error
# Edit the NGINX site configuration (location must be inside server block)
sudo nano /etc/nginx/sites-enabled/default

# Add this block INSIDE the server { } block, BEFORE other location blocks:
# location = /health {
#     return 503 "unhealthy";
#     add_header Content-Type text/plain;
# }

# Or use sed to insert after "server {" line:
sudo sed -i '/server {/a \    location = /health { return 503 "unhealthy"; add_header Content-Type text/plain; }' /etc/nginx/sites-enabled/default

sudo nginx -t && sudo systemctl reload nginx

# 3. Verify local health check fails
curl -I http://localhost/health
# Expected: HTTP 503

# 4. Exit and wait for health probe
exit
sleep 60

# 5. Check backend health
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# Expected: 10.0.1.4 shows "Unhealthy"

# 6. Test application - should still work
curl -k https://<YOUR_APPGW_FQDN>/

# 7. Restore health endpoint
az network bastion ssh ... --name vm-web-az1-prod
# Remove the health override line
sudo sed -i '/location = \/health { return 503/d' /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
curl http://localhost/health
# Expected: healthy
```

**Learning Points:**
- Health probes check application health endpoints
- Returning non-2xx status causes instance removal
- This is more surgical than stopping VM/process
- Useful for graceful deployments (drain before update)

---

## Level 3: Advanced Tests

### Test 3.1: Simulated Zone Failure (Optional - Advanced)

**Objective:** Verify application survives complete zone outage.

> ⏱️ **Optional Test** - This test requires manual MongoDB recovery which can take 15-30 minutes. Skip if time is limited. The Web and App tier failover can be observed through simpler tests (1.1, 1.2).

**Why "Simulate"?**
- Azure users cannot trigger actual zone failures
- But we can simulate by stopping all resources in one zone

**Test Steps:**

```bash
# 1. Document which resources are in Zone 1 (with static IPs from Bicep)
# - vm-web-az1-prod (10.0.1.4) - Web tier
# - vm-app-az1-prod (10.0.2.4) - App tier
# - vm-db-az1-prod (10.0.3.4)  - Database tier (MongoDB primary)

# 2. Verify application works before test
curl -k https://<YOUR_APPGW_FQDN>/
curl -k https://<YOUR_APPGW_FQDN>/api/posts

# 3. Stop ALL Zone 1 VMs simultaneously
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod --no-wait
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod --no-wait
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod --no-wait

# 4. Wait for failures to be detected
echo "Waiting 90 seconds for health probes..."
sleep 90

# 5. Test application - should still work!
curl -k https://<YOUR_APPGW_FQDN>/
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Note: Backend health endpoint is at /health (not /api/health)
# To test backend health, connect to remaining App VM and run: curl http://localhost:3000/health

# 6. Verify by checking which instances are serving
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod

# 7. Test database (connect to Zone 2 DB)
az network bastion ssh ... --name vm-db-az2-prod
mongosh --eval 'rs.isMaster().ismaster'
# Expected: false (2-member replica set cannot auto-elect!)
# See Test 2.2a for manual recovery procedure

# 7a. Manual recovery required for database writes
# Follow Test 2.2a steps to force reconfigure replica set:
mongosh
cfg = rs.conf()
cfg.members = cfg.members.filter(m => m.host !== "10.0.3.4:27017")
rs.reconfig(cfg, {force: true})
rs.isMaster().ismaster  # Now returns true
exit

# 8. After manual recovery, create new data to verify writes work
# Use browser to create a post

# 9. Restore Zone 1 resources
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod --no-wait
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod --no-wait
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod --no-wait

# 10. Wait for recovery
echo "Waiting 120 seconds for VMs to start and rejoin..."
sleep 120

# 11. Verify all healthy
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod
```

**Expected Results:**
| Component | Zone 1 Down | Recovery |
|-----------|-------------|----------|
| Web Tier | Served by vm-web-az2-prod | Both VMs healthy |
| App Tier | Served by vm-app-az2-prod | Both VMs healthy |
| Database | ⚠️ **Manual intervention required** (2-member RS) | Original primary rejoins as secondary after re-add |
| Application | **Reads fail until DB manual recovery** | Full capacity restored |

> ⚠️ **2-Member Replica Set Limitation**
>
> Unlike the Web and App tiers which fail over automatically, the database tier with a 2-member
> replica set **cannot automatically elect a new primary** when one member is down.
> This is a fundamental MongoDB quorum requirement. See Test 2.2a for manual recovery steps.
>
> **Production Recommendation:** Add an arbiter to enable automatic failover.

**Learning Points:**
- Cross-zone architecture survives complete zone failure
- MongoDB election happens automatically
- Load balancers route around failed instances
- Recovery is automatic when zone resources return

---

### Test 3.2: Network Partition (NSG-based)

**Objective:** Test behavior when network connectivity is lost between tiers.

**Caution:** This test can cause extended downtime if not reversed properly.

**Test: Block App Tier → Database Tier**

```bash
# 1. Create NSG rule to block MongoDB traffic
az network nsg rule create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --nsg-name nsg-app-prod \
  --name DenyMongoDB \
  --priority 100 \
  --access Deny \
  --direction Outbound \
  --destination-address-prefixes 10.0.3.0/24 \
  --destination-port-ranges 27017 \
  --protocol Tcp

# 2. Test application
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Error (database unreachable)

# 3. Check application logs
az network bastion ssh ... --name vm-app-az1-prod
pm2 logs blogapp-api --lines 50
# Look for MongoDB connection errors

# 4. Remove the blocking rule
az network nsg rule delete \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --nsg-name nsg-app-prod \
  --name DenyMongoDB

# 5. Verify recovery
sleep 30
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**Learning Points:**
- Network issues can cause application failures
- Proper error handling shows user-friendly messages
- Connection retry logic helps recovery
- NSG rules can isolate issues for testing

---

### Test 3.3: Azure Chaos Studio (Optional)

**Objective:** Use Azure's managed chaos engineering service.

**Prerequisites:**
- Azure Chaos Studio enabled
- Appropriate permissions (Contributor + Chaos specific roles)

**Benefits over manual testing:**
- Scheduled chaos experiments
- Automatic rollback
- Integration with Azure Monitor
- Audit trail of experiments

**Sample Experiment: VM Shutdown**

```bash
# 1. Register resource provider
az provider register --namespace Microsoft.Chaos

# 2. Enable target VM for chaos
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Compute/virtualMachines/vm-web-az1-prod/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine?api-version=2023-11-01" \
  --body '{"properties":{}}'

# 3. Create experiment (via Portal or ARM template)
# See: https://docs.microsoft.com/azure/chaos-studio/
```

**Available Fault Types:**
| Fault | Target | Description |
|-------|--------|-------------|
| VM Shutdown | Virtual Machine | Power off VM |
| CPU Pressure | Virtual Machine | Consume CPU |
| Memory Pressure | Virtual Machine | Consume memory |
| Network Disconnect | Virtual Machine | Block network |
| Disk I/O Pressure | Virtual Machine | Slow disk operations |

---

## Test Monitoring and Verification

### What to Monitor During Tests

| Metric | Tool | What to Look For |
|--------|------|------------------|
| Backend Health | `az network application-gateway show-backend-health` | Healthy/Unhealthy states |
| Application Response | `curl` commands | HTTP status codes, response times |
| MongoDB Status | `mongosh rs.status()` | Member states, election events |
| Application Logs | `pm2 logs`, NGINX logs | Errors, reconnection messages |
| Azure Monitor | Portal → Metrics | Request count, response time, errors |

### Success Criteria

| Test | Success If |
|------|------------|
| VM Failure | Application responds (may have brief errors during failover) |
| Process Failure | Application continues after health probe removes instance |
| DB Failover | Application reconnects to new primary within 30 seconds |
| Zone Failure | Application continues with reduced capacity |
| Network Partition | Application shows error gracefully, recovers when fixed |

---

## Test Checklist for Workshop

### Beginner Level (Recommended for all participants)

- [ ] **Test 1.1**: Stop Web VM, verify Application Gateway failover
- [ ] **Test 1.2**: Stop App VM, verify Internal LB failover
- [ ] **Test 1.3**: Stop NGINX process, verify health probe detection
- [ ] **Test 1.4**: Stop Node.js process, verify health probe detection

### Intermediate Level (For participants with extra time)

- [ ] **Test 2.1**: MongoDB stepDown, verify automatic election
- [ ] **Test 2.2**: *(Optional)* Stop primary DB VM, observe 2-member RS limitation
- [ ] **Test 2.2a**: *(Optional)* Manual MongoDB recovery - force primary election
- [ ] **Test 2.3**: Verify traffic distribution across VMs
- [ ] **Test 2.4**: Manipulate health endpoint, verify removal from pool

### Advanced Level (For experienced participants)

- [ ] **Test 3.1**: *(Optional)* Simulated zone failure (requires manual DB recovery)
- [ ] **Test 3.2**: Network partition via NSG rules
- [ ] **Test 3.3**: *(Optional)* Azure Chaos Studio experiment (if enabled)

---

## Recovery Procedures

### If Application Becomes Unavailable

1. **Check backend health**
   ```bash
   az network application-gateway show-backend-health -g <RG> -n agw-blogapp-prod
   ```

2. **Start stopped VMs**
   ```bash
   az vm start -g <RG> -n vm-web-az1-prod
   az vm start -g <RG> -n vm-web-az2-prod
   az vm start -g <RG> -n vm-app-az1-prod
   az vm start -g <RG> -n vm-app-az2-prod
   ```

3. **Restart application processes**
   ```bash
   # On Web VMs
   sudo systemctl start nginx
   
   # On App VMs
   pm2 start blogapp-api
   ```

4. **Check MongoDB replica set**
   ```bash
   mongosh --eval 'rs.status()'
   ```

### If MongoDB Has Issues

1. **Check replica set status on both DB VMs**
   ```bash
   mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
   ```

2. **If no primary (2-member limitation), force reconfigure:**
   ```bash
   mongosh
   cfg = rs.conf()
   # Remove unavailable member (adjust IP based on which VM is down)
   # vm-db-az1-prod = 10.0.3.4, vm-db-az2-prod = 10.0.3.5
   cfg.members = cfg.members.filter(m => m.host !== "10.0.3.4:27017")  # if az1 is down
   # cfg.members = cfg.members.filter(m => m.host !== "10.0.3.5:27017")  # if az2 is down
   rs.reconfig(cfg, {force: true})
   rs.isMaster().ismaster  # Should return true now
   ```

3. **Re-add recovered member after VM starts:**
   ```bash
   mongosh
   # Add back the recovered VM (use the IP of the VM you just started)
   rs.add("10.0.3.4:27017")  # if vm-db-az1-prod was recovered
   # rs.add("10.0.3.5:27017")  # if vm-db-az2-prod was recovered
   rs.status()  # Verify both members present
   ```

4. **Check `/data/mongodb/log/mongod.log` for errors**

---

## Summary

This resiliency testing strategy provides:

1. **Structured approach** from beginner to advanced
2. **Clear steps** with expected outcomes
3. **Real-world scenarios** that match production failures
4. **Learning opportunities** about Azure HA patterns
5. **Safe recovery procedures** for test cleanup

The tests demonstrate that a properly architected multi-tier application with:
- Load balancer health probes
- Cross-zone redundancy
- Database replication

Can survive various failure modes without manual intervention.
