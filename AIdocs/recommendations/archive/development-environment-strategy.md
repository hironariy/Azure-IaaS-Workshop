# Development Environment Strategy: Local vs Azure

**Created**: 2025-12-04  
**Purpose**: Guidance on choosing between local containers and Azure VMs for workshop development  
**Decision**: Hybrid Approach (Local Development + Azure Validation)

---

## Executive Summary

**Recommendation: Use a Hybrid Approach**

- ✅ **Local Docker Containers** for daily development (90% of time)
- ✅ **Azure VMs** for validation and testing (10% of time)

**Key Benefits:**
- Zero cost during active development
- Fast iteration cycles (seconds vs minutes)
- Validate Azure-specific features when needed
- **Estimated savings: $120-170/month** vs Azure-only approach

---

## The Question

Should you set up a small development environment on your local PC with containers, or create Azure VMs with Bicep for the development environment?

---

## Option 1: Local Development with Containers ⭐ **RECOMMENDED for Active Coding**

### Setup

Use Docker Compose to run MongoDB replica set locally:

```yaml
# docker-compose.yml
version: '3.8'
services:
  mongodb-primary:
    image: mongo:7.0
    container_name: blogapp-mongo-primary
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: devpassword
    command: --replSet blogapp-rs0
    volumes:
      - mongo-primary-data:/data/db
  
  mongodb-secondary:
    image: mongo:7.0
    container_name: blogapp-mongo-secondary
    ports:
      - "27018:27017"
    command: --replSet blogapp-rs0
    volumes:
      - mongo-secondary-data:/data/db
  
  # Optional: MongoDB Express for GUI
  mongo-express:
    image: mongo-express:latest
    ports:
      - "8081:8081"
    environment:
      ME_CONFIG_MONGODB_URL: mongodb://admin:devpassword@mongodb-primary:27017/
    depends_on:
      - mongodb-primary

volumes:
  mongo-primary-data:
  mongo-secondary-data:
```

### Advantages

- ✅ **Fast iteration** - Code → Save → See changes in seconds
- ✅ **Zero Azure costs** during development
- ✅ **Work offline** - No internet required
- ✅ **Easy teardown/rebuild** - `docker-compose down -v`
- ✅ **Consistent environment** - Same setup across developers
- ✅ **No quota concerns** - Unlimited VM restarts
- ✅ **Perfect for backend/frontend development**

### Disadvantages

- ❌ Can't test Azure-specific features (Managed Identity, Key Vault)
- ❌ Different from production (Ubuntu VMs vs containers)
- ❌ Won't validate Bicep templates

### Best For

- Writing backend API code
- Developing frontend React app
- Unit/integration testing
- MongoDB schema development
- Rapid prototyping
- Daily development work (95% of time)

---

## Option 2: Azure VMs with Bicep 🔧 **RECOMMENDED for Validation**

### Setup

Deploy minimal Azure environment for testing:

```bicep
// dev.bicep - Minimal Azure setup for testing
param location string = 'japaneast'

// Single resource group with minimal resources
// 1 Web VM, 1 App VM, 1 DB VM (single instance, no HA)
// No Load Balancer initially (test direct via public IP)
// No Bastion (use SSH with public key)
// No ASR (dev environment only)
```

**Cost Optimization Strategies:**
- Use **B1s VMs** ($7.59/month) instead of B2s during dev
- **Auto-shutdown** at 6 PM daily
- **Deallocate when not testing** (storage cost only ~$1/month)
- Delete entirely when not needed for weeks

### Advantages

- ✅ **Tests actual production setup** - Real Azure VMs, networking
- ✅ **Validates Bicep templates** - Ensures IaC works
- ✅ **Tests Azure integrations** - Managed Identity, Key Vault, Monitor
- ✅ **Realistic performance** - Same as student experience
- ✅ **Workshop rehearsal** - Dry run capability

### Disadvantages

- ❌ **Costs money** - Even B1s VMs = ~$30-50/month if left running
- ❌ **Slow iteration** - Deploy, wait, test, repeat (15-30 minutes per cycle)
- ❌ **Internet required** - Can't work offline
- ❌ **Quota limits** - May hit subscription limits
- ❌ **Complex setup/teardown** - Not suitable for frequent changes

### Best For

- Bicep template development/validation
- Azure-specific feature testing
- Load balancer configuration
- Monitoring/logging validation
- Workshop dry runs
- Final validation before workshop delivery

### Estimated Monthly Cost

**If left running 24/7:**
- 3x B1s VMs: ~$23/month
- Storage: ~$5/month
- **Total: ~$28/month**

**With auto-shutdown (recommended):**
- 3x B1s VMs (8 hours/day): ~$8/month
- Storage: ~$5/month
- **Total: ~$13/month**

**Best practice: Deallocate when not actively testing:**
- Storage only: ~$5/month
- **Total: ~$5/month**

---

## 🎯 Recommended Hybrid Workflow

### Phase 1: Local Development (90% of time)

**Setup on Your Mac:**

```bash
# Install Docker Desktop (if not already)
brew install --cask docker

# Navigate to dev environment
cd /Users/hironariy/dev/AzureIaaSWorkshop/dev-environment

# Start local environment
docker-compose up -d

# Initialize MongoDB replica set (one-time)
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  /scripts/init-replica-set.js
```

**Development Loop:**

```bash
# Start local environment (if not already running)
docker-compose up -d

# Develop backend
cd ../materials/backend
npm run dev  # Hot reload on file changes

# Develop frontend (separate terminal)
cd ../materials/frontend
npm run dev  # Hot reload with Vite

# Access locally
# Backend: http://localhost:3000
# Frontend: http://localhost:5173
# MongoDB: localhost:27017
# Mongo Express: http://localhost:8081
```

**When to Use:**
- ✅ Writing TypeScript code (backend/frontend)
- ✅ Creating MongoDB schemas
- ✅ Testing API endpoints with Postman
- ✅ Debugging business logic
- ✅ Unit testing
- ✅ 95% of daily development work

---

### Phase 2: Azure Validation (10% of time)

**Create Minimal Dev Environment:**

Only deploy to Azure for:
1. Validating Bicep templates work
2. Testing Azure-specific features
3. Workshop dry runs
4. Before major commits

**Deployment Pattern:**

```bash
# Deploy minimal dev environment
az group create --name rg-workshop-dev --location japaneast

az deployment group create \
  --resource-group rg-workshop-dev \
  --template-file materials/bicep/dev/main.bicep \
  --parameters environment=dev

# Test your code on real Azure infrastructure
# ... testing ...

# Deallocate VMs when done (save costs)
az vm deallocate --ids $(az vm list -g rg-workshop-dev --query "[].id" -o tsv)

# Or delete entire environment
az group delete --name rg-workshop-dev --yes --no-wait
```

**When to Use:**
- ⏰ After completing a major feature locally
- ⏰ Validating Bicep templates work
- ⏰ Testing Managed Identity → Key Vault
- ⏰ Validating Azure Monitor integration
- ⏰ Before committing major changes
- ⏰ Workshop dry run (full deployment)

---

## Specific Workflow by Development Stage

### Stage 3.2: Bicep Development

**Approach: Azure First**

Bicep templates can't be tested locally (need real Azure), so:

1. Write Bicep modules locally in VS Code
2. Validate syntax locally: `az bicep build --file main.bicep`
3. Deploy to Azure dev environment: `az deployment group create...`
4. Validate resources created correctly
5. Iterate and refine
6. Delete resources when done

**No local containers needed** for infrastructure development.

---

### Stage 3.3: Database (MongoDB)

**Approach: Local Containers First, Azure Validation**

**Local Development (90% of time):**

```bash
# Use Docker Compose MongoDB
docker-compose up -d

# Develop schema, seed data locally
mongosh localhost:27017 < create-schema.js
mongosh localhost:27017 < seed-data.js

# Test queries
mongosh localhost:27017
> use blogapp
> db.posts.find().limit(5)

# Test replica set failover (simulated)
docker stop blogapp-mongo-primary
# Verify secondary can be promoted (manual in dev)
docker start blogapp-mongo-primary
```

**Azure Validation (before finalizing):**

Deploy to Azure to validate:
- Ubuntu 24.04 + MongoDB 7.0 compatibility
- Installation scripts work on real VMs
- Actual replica set behavior (automatic failover)
- Azure Backup integration
- Performance characteristics

---

### Stage 3.4: Backend API (Express/TypeScript)

**Approach: Local Containers First**

**Daily Development:**

```bash
# MongoDB in Docker
docker-compose up -d mongodb-primary mongodb-secondary

# Backend local development
cd materials/backend
npm run dev

# .env.development
MONGODB_URI=mongodb://admin:devpassword123@localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0&authSource=admin
PORT=3000
NODE_ENV=development
USE_MOCK_AUTH=true
```

**Testing locally:**

```bash
# Test API endpoints
curl http://localhost:3000/api/posts

# Test with Postman
# Import collection, run tests

# Unit tests
npm test

# Integration tests
npm run test:integration
```

**Azure Validation (milestone checkpoints):**

Deploy to Azure to test:
- After completing authentication middleware
- After completing all CRUD endpoints
- To validate Managed Identity → Key Vault integration
- Before finalizing deployment scripts
- To test with real Entra ID authentication

---

### Stage 3.5: Frontend (React/TypeScript)

**Approach: Local Development with Mock Auth**

**Local Development:**

```bash
# Use mock MSAL for local dev
# frontend/.env.development
VITE_USE_MOCK_AUTH=true
VITE_API_URL=http://localhost:3000

npm run dev
# Hot reload as you code
```

**What you can test locally:**
- ✅ All UI components
- ✅ Routing and navigation
- ✅ API calls to local backend
- ✅ State management
- ✅ Form validation
- ✅ Error handling
- ✅ Responsive design

**Azure Validation:**

Deploy to Azure to test:
- Real MSAL authentication flow
- CORS configuration with actual domains
- Production build optimization
- NGINX configuration and SPA routing
- HTTPS setup
- Performance under real network conditions

---

### Stage 3.6: Integration Testing

**Approach: Azure Full Stack**

This stage **requires Azure** - no local equivalent:

1. Deploy complete environment to Azure
2. Run through all workshop steps
3. Validate student experience
4. Test HA scenarios (VM failures)
5. Test monitoring and logging
6. Validate backup/restore
7. Test disaster recovery

This is the **final validation** before workshop delivery.

---

## Cost Comparison Analysis

| Approach | Daily Development Cost | Azure Validation Cost | Monthly Total |
|----------|------------------------|----------------------|---------------|
| **Local Only** | $0 | ❌ Can't test Azure | **$0** (but incomplete testing) |
| **Azure Only** | ~$150-200 (VMs running 24/7) | Included | **$150-200** |
| **Hybrid (Recommended)** | $0 (local containers) | ~$10-30 (on-demand testing) | **$10-30** |

**Hybrid approach saves $120-170/month** during active development.

---

## Resource Usage Comparison

### Local Docker Environment

**Typical Resource Consumption:**
- CPU: ~5-10% (idle), ~30-50% (active development)
- RAM: ~500 MB (all containers)
- Disk: ~2 GB (with data)
- Network: 0 (offline capable)

**Safe to run in background** while developing.

### Azure Development Environment

**Minimal Setup (3x B1s VMs):**
- Cost: ~$28/month (if running 24/7)
- Deployment time: 15-30 minutes
- Teardown time: 5-10 minutes
- Internet: Required

**Best Practice:**
- Deploy only when needed
- Auto-shutdown nights/weekends
- Deallocate between testing sessions

---

## Decision Matrix: When to Use Which Environment

### Use Local Containers When:

- ✅ Writing code (TypeScript, React)
- ✅ Debugging application logic
- ✅ Creating database schemas
- ✅ Developing API endpoints
- ✅ Building UI components
- ✅ Running unit tests
- ✅ Iterating quickly on features
- ✅ Working offline
- ✅ Prototyping new ideas
- ✅ Daily development work

### Use Azure VMs When:

- ✅ Testing Bicep templates
- ✅ Validating infrastructure design
- ✅ Testing Managed Identity
- ✅ Testing Key Vault integration
- ✅ Configuring Azure Monitor
- ✅ Testing load balancer behavior
- ✅ Validating network security groups
- ✅ Testing Azure Backup
- ✅ Testing Azure Site Recovery
- ✅ Workshop dry runs
- ✅ Final pre-workshop validation
- ✅ Demonstrating to stakeholders

### Don't Use Azure VMs For:

- ❌ Daily coding iterations
- ❌ Debugging JavaScript/TypeScript
- ❌ Testing business logic
- ❌ Developing UI components
- ❌ Running unit tests
- ❌ Quick prototyping
- ❌ Learning new libraries
- ❌ Experimenting with designs

---

## Implementation: Local Development Environment

### What Was Created

The following local development environment has been set up:

```
dev-environment/
├── docker-compose.yml           # MongoDB replica set (2 nodes) + Mongo Express
├── scripts/
│   └── init-replica-set.js      # Replica set initialization script
├── README.md                     # Complete usage guide
└── .env.example                  # Configuration reference
```

### Quick Start Guide

**1. Start the environment:**

```bash
cd /Users/hironariy/dev/AzureIaaSWorkshop/dev-environment

# Start all containers
docker-compose up -d

# Check status
docker-compose ps
```

**2. Initialize MongoDB replica set (first time only):**

```bash
# Wait for containers to be healthy
sleep 15

# Initialize replica set
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  /scripts/init-replica-set.js
```

**3. Verify setup:**

```bash
# Check replica set status
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  --eval "rs.status()"

# Expected: PRIMARY on mongo-primary, SECONDARY on mongo-secondary
```

**4. Access services:**

- **MongoDB Primary**: `localhost:27017`
- **MongoDB Secondary**: `localhost:27018`
- **Mongo Express Web UI**: http://localhost:8081
  - Username: `admin`
  - Password: `admin`

### Connection Strings

**For Backend Application (`materials/backend/.env.development`):**

```bash
NODE_ENV=development
PORT=3000

# MongoDB connection string (replica set)
MONGODB_URI=mongodb://admin:devpassword123@localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0&authSource=admin

# Mock authentication for local development
JWT_ISSUER=https://login.microsoftonline.com/mock-tenant-id/v2.0
JWT_AUDIENCE=api://mock-app-id
USE_MOCK_AUTH=true
```

**Direct Connection (mongosh CLI):**

```bash
# Connect to primary
mongosh "mongodb://admin:devpassword123@localhost:27017/?authSource=admin"

# Connect to secondary (read-only)
mongosh "mongodb://admin:devpassword123@localhost:27018/?authSource=admin&readPreference=secondary"
```

### Common Development Tasks

**Start environment:**
```bash
docker-compose up -d
```

**Stop environment (preserve data):**
```bash
docker-compose stop
```

**Stop and remove (preserve volumes):**
```bash
docker-compose down
```

**Reset everything (delete all data):**
```bash
docker-compose down -v
docker-compose up -d
sleep 15
docker exec -it blogapp-mongo-primary mongosh -u admin -p devpassword123 --authenticationDatabase admin /scripts/init-replica-set.js
```

**View logs:**
```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f mongodb-primary
```

**Test failover (HA simulation):**
```bash
# Stop primary
docker-compose stop mongodb-primary

# Check secondary status
docker exec -it blogapp-mongo-secondary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  --eval "rs.status()"

# Restart primary
docker-compose start mongodb-primary
```

**Execute MongoDB scripts:**
```bash
# Run schema creation
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  blogapp < ../materials/backend/scripts/create-schema.js

# Run seed data
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  blogapp < ../materials/backend/scripts/seed-data.js
```

---

## Typical Daily Workflow

### Morning: Start Development Session

```bash
# 1. Start local environment
cd /Users/hironariy/dev/AzureIaaSWorkshop/dev-environment
docker-compose up -d

# 2. Verify MongoDB is ready
docker-compose ps

# 3. Start backend development server
cd ../materials/backend
npm run dev
# Runs on http://localhost:3000

# 4. Start frontend development server (new terminal)
cd ../materials/frontend
npm run dev
# Runs on http://localhost:5173
```

### During Development

```bash
# Edit code in VS Code
# Save file
# See changes immediately (hot reload)

# Test API endpoints
curl http://localhost:3000/api/posts

# View MongoDB data
# Open browser: http://localhost:8081

# Run tests
npm test

# Check logs
docker-compose logs -f mongodb-primary
```

### Evening: End Development Session

```bash
# Option 1: Stop containers (can resume quickly tomorrow)
cd dev-environment
docker-compose stop

# Option 2: Leave running (if continuing tomorrow)
# Just close terminals

# Option 3: Clean shutdown and data wipe
docker-compose down -v
```

---

## When to Deploy to Azure

### Milestone-Based Deployment Strategy

**After Stage 3.2 Complete (Bicep Templates):**
- Deploy full infrastructure to Azure
- Validate all resources created correctly
- Test network connectivity
- Verify NSG rules
- Deallocate VMs until next stage

**After Stage 3.3 Complete (Database):**
- Deploy DB VMs
- Run MongoDB installation scripts
- Test replica set initialization
- Validate connectivity from App tier
- Load seed data
- Test backup configuration
- Deallocate when validated

**After Stage 3.4 Complete (Backend):**
- Deploy App tier VMs
- Deploy backend code
- Test with Azure-hosted MongoDB
- Validate Managed Identity → Key Vault
- Test API endpoints via public IP
- Run integration tests
- Deallocate when validated

**After Stage 3.5 Complete (Frontend):**
- Deploy Web tier VMs
- Build and deploy frontend
- Configure NGINX
- Test full stack integration
- Test real MSAL authentication
- Validate CORS and routing
- Run E2E tests
- Deallocate when validated

**Stage 3.6 (Final Integration):**
- Deploy complete workshop environment
- Run full workshop dry run
- Test all HA scenarios
- Validate monitoring and logging
- Test backup/restore
- Test disaster recovery
- Keep environment running for final validations
- Delete after workshop is production-ready

---

## Cost Optimization Best Practices

### For Development Environment

**1. Use Smallest VM Sizes:**
```bicep
// dev.bicep
param vmSizeWeb string = 'Standard_B1s'    // Not B2s
param vmSizeApp string = 'Standard_B1s'    // Not B2s
param vmSizeDb string = 'Standard_B2s'     // Not B4ms
```

**2. Implement Auto-Shutdown:**
```bicep
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1800'  // 6 PM
    }
    timeZoneId: 'Tokyo Standard Time'
    targetResourceId: vm.id
  }
}
```

**3. Deallocate When Not Testing:**
```bash
# Deallocate all VMs in dev resource group
az vm deallocate --ids $(az vm list -g rg-workshop-dev --query "[].id" -o tsv)

# Cost drops to ~$5/month (storage only)
```

**4. Delete When Not Needed:**
```bash
# Delete entire dev environment
az group delete --name rg-workshop-dev --yes --no-wait

# Cost: $0
```

**5. Use Spot VMs (Optional):**
```bicep
// For non-critical dev testing
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  properties: {
    priority: 'Spot'
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: -1  // Pay up to regular price
    }
  }
}
// Saves ~60-90% vs regular VMs
```

### Monthly Cost Tracking

**Local Development Only:**
- Cost: **$0/month**
- Can't test Azure features

**Hybrid (Recommended):**
- Local development: $0
- Azure validation (deallocated): ~$5/month
- Azure validation (active 40 hours/month): ~$10-15/month
- **Total: $10-20/month**

**Azure Only (Not Recommended):**
- 6 VMs running 24/7: ~$150-200/month
- Inefficient for rapid development

---

## Troubleshooting

### Local Environment Issues

**Containers won't start:**
```bash
# Check if ports are in use
lsof -i :27017
lsof -i :27018
lsof -i :8081

# Kill conflicting processes or change ports in docker-compose.yml

# Remove and recreate
docker-compose down -v
docker-compose up -d
```

**Replica set not initialized:**
```bash
# Check MongoDB is ready
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  --eval "db.adminCommand('ping')"

# Re-run initialization
docker exec -it blogapp-mongo-primary mongosh \
  -u admin -p devpassword123 \
  --authenticationDatabase admin \
  /scripts/init-replica-set.js
```

**Can't connect from backend:**
- Ensure using `localhost` (not `mongo-primary`)
- Verify ports: `27017,27018`
- Check authentication: `authSource=admin`
- Verify containers running: `docker-compose ps`

**Mongo Express not loading:**
```bash
# Restart Mongo Express
docker-compose restart mongo-express

# Check logs
docker-compose logs mongo-express
```

### Azure Environment Issues

**Deployment fails:**
```bash
# Validate template syntax
az bicep build --file main.bicep

# Check deployment logs
az deployment group show \
  --resource-group rg-workshop-dev \
  --name <deployment-name> \
  --query properties.error

# Check activity log
az monitor activity-log list --resource-group rg-workshop-dev
```

**VMs won't start:**
```bash
# Check quota limits
az vm list-usage --location japaneast --output table

# Check VM status
az vm get-instance-view \
  --resource-group rg-workshop-dev \
  --name vm-web-dev \
  --query instanceView.statuses
```

**Can't SSH to VMs:**
```bash
# Use Bastion (if deployed)
az network bastion ssh \
  --name bastion-dev \
  --resource-group rg-workshop-dev \
  --target-resource-id <vm-id> \
  --auth-type password \
  --username azureuser

# Or use serial console
az vm run-command invoke \
  --resource-group rg-workshop-dev \
  --name vm-web-dev \
  --command-id RunShellScript \
  --scripts "echo 'Hello from VM'"
```

---

## Summary and Recommendations

### The Answer: Hybrid Approach ✅

**For daily development (90% of time):**
- Use **local Docker containers**
- Free, fast, and offline-capable
- Perfect for writing code

**For Azure validation (10% of time):**
- Deploy **minimal Azure VMs**
- On-demand testing only
- Deallocate when done

### Key Benefits

1. **Cost Savings**: Save $120-170/month vs Azure-only
2. **Development Speed**: Iterate in seconds, not minutes
3. **Flexibility**: Work offline, no quota limits
4. **Realistic Testing**: Validate on real Azure when needed
5. **Best of Both Worlds**: Fast development + Azure validation

### Implementation Status

✅ **Local environment ready** - `dev-environment/` fully configured  
⏸️ **Azure templates pending** - Create in Stage 3.2  
📋 **Workflow documented** - This guide and dev-environment/README.md

### Next Steps

1. ✅ **Test local environment** - Start Docker containers, verify MongoDB
2. ✅ **Begin Stage 3.1** - Pre-coding validation
3. ✅ **Create backend structure** - Set up materials/backend/
4. ✅ **Write first Bicep module** - Start with vnet.bicep
5. ⏰ **Deploy to Azure** - Only after local development complete

### Golden Rule

**Develop locally, validate on Azure, deliver confidently.**

Don't waste time and money deploying to Azure for every code change. Use local containers for rapid development, then validate on Azure at key milestones.

---

## References

- [Workshop Development Strategy](./workshop-development-strategy.md)
- [Local Development README](../dev-environment/README.md)
- [Azure Architecture Design](../design/AzureArchitectureDesign.md)
- [Backend Application Design](../design/BackendApplicationDesign.md)
- [Database Design](../design/DatabaseDesign.md)
- [Repository-Wide Design Rules](../design/RepositoryWideDesignRules.md)
