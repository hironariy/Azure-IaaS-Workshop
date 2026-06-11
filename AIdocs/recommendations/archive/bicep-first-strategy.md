# Bicep-First Development Strategy

**Date**: December 5, 2025  
**Decision**: Start with Bicep infrastructure development before full application code  
**Status**: Recommended approach for Azure IaaS Workshop development

---

## Executive Summary

**Recommendation**: Develop Bicep infrastructure templates FIRST, then develop backend/frontend in parallel while infrastructure is deployed.

**Rationale**: Infrastructure is the critical path for workshop success. Validating Azure deployment early reduces risk of late-stage failures and enables realistic integration testing throughout development.

**Timeline Impact**: 6 weeks total with lower risk vs. 6-7 weeks with higher risk of late surprises.

---

## Strategic Analysis

### Current Situation Assessment

**✅ Complete**:
- Design documents (10,270+ lines)
- Local MongoDB replica set (Docker)
- Design validation report

**❌ Not Started**:
- Bicep templates
- Backend code
- Frontend code
- Azure infrastructure deployment

---

## Option Comparison

### Option A: Bicep First (RECOMMENDED ✅)

**Sequence**: Infrastructure → Parallel local development → Incremental Azure deployment

#### Advantages

1. **Early Azure Validation**
   - Discover quota limits NOW (not in Week 5)
   - Verify region availability, service limits
   - Test "Deploy to Azure" button early
   - Validate NSG rules, Load Balancer configuration

2. **Parallel Development Possible**
   - While Bicep templates deploy (15-30 min), start backend scaffolding
   - Backend can develop locally while infrastructure provisions
   - No blocking dependencies

3. **Real Environment Testing**
   - Deploy backend to actual Azure VMs early (Week 3)
   - Test with real Load Balancer, NSGs, Availability Zones
   - Integration issues caught during development (not at end)

4. **Workshop-Ready Faster**
   - Infrastructure is Day 1 requirement for students
   - Critical path item completed early
   - Reduces risk to workshop timeline

5. **Fail Fast Philosophy**
   - Azure subscription issues discovered early
   - Service availability confirmed before investing weeks in code
   - Better risk management

6. **Realistic Development Context**
   - Code designed with deployment target in mind
   - Network constraints considered from start
   - VM sizing impacts architecture decisions

#### Timeline (6 weeks)

```
Week 1: Bicep Infrastructure Development
├─ Days 1-3: Core modules (VNet, VMs, Load Balancer)
├─ Days 4-5: Deploy to Azure test resource group
└─ Days 6-7: Validate deployment, fix issues

Week 2: Backend Development (Local) + Infrastructure Refinement
├─ Backend: Project scaffolding, MongoDB models
└─ Infrastructure: Monitoring, security modules

Week 3: Backend Development + Azure Deployment
├─ Backend: API endpoints, authentication
└─ Deploy backend to Azure VMs, integration test

Week 4: Frontend Development (Local)
├─ Frontend: React components, MSAL auth
└─ Connect to deployed backend API on Azure

Week 5: Frontend Deployment + Integration
├─ Deploy frontend to Azure web tier
└─ End-to-end testing on Azure stack

Week 6: Workshop Preparation
├─ HA/DR testing
├─ Student materials creation
└─ Final validation
```

#### Risk Assessment

| Risk | Mitigation |
|------|------------|
| Bicep learning curve | Design docs provide detailed specifications |
| Azure deployment failures | Discovered early, time to fix |
| Cost overruns | Deallocate VMs when not testing |
| Integration issues | Caught incrementally, easier to debug |

**Overall Risk Level**: **LOW** ✅

---

### Option B: Local Dev First (Alternative)

**Sequence**: Backend/Frontend locally → Bicep → Migrate to Azure

#### Advantages

1. **Faster Initial Progress**
   - See working app on localhost quickly
   - Familiar development environment
   - Immediate gratification

2. **No Azure Costs During Development**
   - Only pay when deploying infrastructure
   - Can develop for weeks without Azure charges

3. **Better Local Debugging**
   - VS Code debugging works seamlessly
   - No remote SSH debugging needed
   - Faster iteration cycles

#### Disadvantages

1. **Late Discovery of Issues** ⚠️
   - Azure deployment problems found after weeks of coding
   - Network configuration issues discovered late
   - Permission/Managed Identity issues surface at end

2. **Migration Pain**
   - Code works locally but fails on Azure (common scenario)
   - Environment variable differences
   - Localhost vs. private IP addressing
   - File path differences (Windows-style paths, etc.)

3. **No Integration Testing Until Late**
   - Load Balancer behavior unknown until deployment
   - NSG rules might break connectivity
   - Availability Zone failover untested

4. **Workshop Risk** ⚠️
   - If Bicep fails in Week 5, workshop materials not ready
   - Student experience compromised
   - Last-minute scrambling likely

5. **Potential Wasted Effort**
   - Code might need significant rewrites for Azure
   - Optimizations for local dev don't apply to Azure
   - Technical debt from "works on my machine"

#### Timeline (6-7 weeks)

```
Week 1-2: Backend Development (Local)
└─ Full API implementation on localhost

Week 3-4: Frontend Development (Local)
└─ Full React app on localhost

Week 5: Bicep Development (RUSHED)
├─ Create all templates quickly
└─ Deploy to Azure (HOPE IT WORKS)

Week 6: Migration & Debugging
├─ Fix Azure deployment issues
├─ Code changes for Azure environment
└─ Integration testing (DISCOVERING PROBLEMS LATE)

Week 7: Workshop Preparation (IF TIME ALLOWS)
└─ Rushed student materials creation
```

#### Risk Assessment

| Risk | Impact |
|------|--------|
| Late Azure issues | HIGH - May require code rewrites |
| Deployment failures | HIGH - No time to recover |
| Integration problems | HIGH - Discovered at worst time |
| Workshop delay | HIGH - Critical path compressed |

**Overall Risk Level**: **MEDIUM-HIGH** ⚠️

---

## Recommended Strategy: Hybrid Bicep-First Approach

### Phase 1: Infrastructure Foundation (Week 1-2)

#### Week 1: Bicep Development

**Days 1-3**: Core Infrastructure Modules
```bash
# Create directory structure
mkdir -p materials/bicep/modules/{network,compute,monitoring,security,storage}

# Develop core modules
materials/bicep/modules/network/
├── vnet.bicep              # VNet with 4 subnets
├── nsg-web.bicep           # Web tier NSG rules
├── nsg-app.bicep           # App tier NSG rules
├── nsg-db.bicep            # DB tier NSG rules
├── bastion.bicep           # Azure Bastion
├── load-balancer.bicep     # Standard Load Balancer
└── public-ip.bicep         # Public IPs

materials/bicep/modules/compute/
├── vm.bicep                # Reusable VM template
├── web-tier.bicep          # 2 Web VMs (AZ 1 & 2)
├── app-tier.bicep          # 2 App VMs (AZ 1 & 2)
└── db-tier.bicep           # 2 DB VMs (AZ 1 & 2)
```

**Days 4-5**: Deploy to Azure Test Environment
```bash
# Create test resource group
az group create \
  --name rg-workshop-test \
  --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-workshop-test \
  --template-file materials/bicep/main.bicep \
  --parameters parameters.test.json

# Verify deployment (15-30 minutes)
# Test: Can access Bastion? VMs pingable? Load Balancer responds?
```

**Days 6-7**: Validation & Refinement
```bash
# Test connectivity
ssh -J bastion azureuser@<app-vm-ip>

# Verify NSG rules
curl http://<load-balancer-ip>/health

# Check Availability Zone distribution
az vm show --resource-group rg-workshop-test --name vm-web-az1 --query zones
```

#### Week 1-2 Parallel: Local Environment Preparation

**While Bicep develops, prepare local scaffolding** (doesn't block Bicep work):

```bash
# Backend scaffolding
cd materials/backend
npm init -y
npm install express typescript @types/node @types/express
npx tsc --init
mkdir -p src/{config,middleware,routes,controllers,models,services,utils,types}

# Frontend scaffolding
cd materials/frontend
npm create vite@latest . -- --template react-ts
npm install
mkdir -p src/{components,pages,hooks,services,types,utils}

# Don't implement full features yet, just structure
```

**Goal**: By end of Week 1, infrastructure is deployed and validated on Azure.

---

### Phase 2: Backend Development (Week 2-4)

#### Week 2-3: Local Backend Development

**Connect to Local MongoDB** (already working from Docker):
```typescript
// materials/backend/src/config/database.ts
const MONGODB_URI = process.env.MONGODB_URI || 
  'mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0';
```

**Implement Core Features**:
- ✅ Mongoose models (User, Post, Comment)
- ✅ Authentication middleware (JWT validation)
- ✅ API routes (posts, comments, users, auth)
- ✅ Error handling middleware
- ✅ Logging with Winston

**Test Locally**:
```bash
npm run dev
curl http://localhost:3000/api/health
# Should return: {"status": "healthy", "database": "connected"}
```

#### Week 3: Deploy Backend to Azure VMs

**Deployment Steps**:
```bash
# SSH to App VM via Bastion
az network bastion ssh \
  --name bastion-blogapp \
  --resource-group rg-workshop-test \
  --target-resource-id <app-vm-resource-id> \
  --auth-type password \
  --username azureuser

# On VM: Install Node.js, clone repo, deploy
sudo apt update && sudo apt install -y nodejs npm
git clone <your-repo>
cd backend
npm install
npm run build

# Configure systemd service for backend
sudo systemctl start blogapp-backend
```

**Integration Testing on Azure**:
```bash
# Test Load Balancer → App tier
curl http://<load-balancer-ip>/api/health

# Test App tier → DB tier (MongoDB)
# Backend logs should show: "✅ Connected to MongoDB replica set"

# Test NSG rules
# Should work: curl from Web VM to App VM:3000
# Should fail: curl from Internet to App VM:3000 (blocked by NSG)
```

**Benefits of Early Azure Deployment**:
- Validates NSG rules work correctly
- Tests Load Balancer health probes
- Confirms MongoDB connectivity across subnets
- Discovers permission issues (Managed Identity, Key Vault)
- Real-world latency and performance testing

---

### Phase 3: Frontend Development (Week 4-5)

#### Week 4: Local Frontend Development

**Develop with Real Azure Backend**:
```typescript
// materials/frontend/.env.development
VITE_API_URL=http://<load-balancer-ip>/api  # Use deployed backend!
VITE_ENTRA_CLIENT_ID=<your-entra-client-id>
VITE_ENTRA_TENANT_ID=<your-tenant-id>
```

**Implement Core Features**:
- ✅ MSAL authentication with real Entra ID
- ✅ React Query for API calls
- ✅ Post list, post detail, create post pages
- ✅ Comment functionality
- ✅ Protected routes

**Test Locally**:
```bash
npm run dev
# Open http://localhost:5173
# Login with Microsoft account
# Create/read posts using deployed backend API
```

**Benefit**: Frontend development uses real Azure backend, catching integration issues early.

#### Week 5: Deploy Frontend to Azure VMs

**Build and Deploy**:
```bash
# Build production bundle
npm run build
# Output: dist/ directory

# SSH to Web VM via Bastion
# Copy dist/ to /var/www/blogapp
# Configure NGINX to serve static files
sudo systemctl reload nginx

# Test via Load Balancer
curl http://<load-balancer-ip>/
# Should return: index.html (React app)
```

**End-to-End Testing**:
```bash
# Open browser: http://<load-balancer-ip>
# Test full flow:
# 1. Login with Microsoft
# 2. Create blog post
# 3. View post
# 4. Add comment
# 5. Logout

# All working on Azure infrastructure!
```

---

### Phase 4: Integration & Workshop Prep (Week 6)

#### Week 6: Full Stack Validation

**High Availability Testing** (Workshop Day 2 content):
```bash
# Stop Web VM in AZ 1
az vm stop --resource-group rg-workshop-test --name vm-web-az1

# Test: App should still work (Load Balancer routes to AZ 2)
curl http://<load-balancer-ip>/
# Should return: 200 OK

# Restart Web VM
az vm start --resource-group rg-workshop-test --name vm-web-az1
```

**Disaster Recovery Testing**:
```bash
# Create backup recovery point
az backup protection backup-now \
  --resource-group rg-workshop-test \
  --vault-name rsv-blogapp \
  --container-name vm-db-az1 \
  --item-name vm-db-az1

# Test restore (to separate test environment)
```

**Student Materials Creation**:
- ✅ Step-by-step deployment guides (9 documents)
- ✅ Troubleshooting FAQ
- ✅ Validation scripts
- ✅ Instructor slides

**Final Validation**:
- ✅ Lighthouse score > 90
- ✅ All API endpoints working
- ✅ Authentication flow complete
- ✅ HA failover demonstrated
- ✅ Backup/restore tested

---

## Concrete Action Plan (This Week)

### Day 1 (Today): Bicep - Core Networking

**Tasks**:
1. Create Bicep directory structure
2. Develop `modules/network/vnet.bicep`
3. Develop NSG modules (web, app, db)

**Files to Create**:
```
materials/bicep/
├── modules/
│   └── network/
│       ├── vnet.bicep          # VNet with 4 subnets
│       ├── nsg-web.bicep       # Web tier NSG rules
│       ├── nsg-app.bicep       # App tier NSG rules
│       └── nsg-db.bicep        # DB tier NSG rules
├── main.bicep                  # Orchestrator (placeholder)
└── parameters.test.json        # Test parameters
```

**Success Criteria**:
- ✅ VNet created with correct CIDR (10.0.0.0/16)
- ✅ 4 subnets created (web, app, db, bastion)
- ✅ NSG rules follow least-privilege principle

---

### Day 2: Bicep - Compute Resources

**Tasks**:
1. Develop reusable `modules/compute/vm.bicep`
2. Develop tier-specific modules (web, app, db)
3. Configure Availability Zone distribution

**Files to Create**:
```
materials/bicep/modules/compute/
├── vm.bicep                # Reusable VM template
├── web-tier.bicep          # 2 Web VMs (B2s, AZ 1 & 2)
├── app-tier.bicep          # 2 App VMs (B2s, AZ 1 & 2)
└── db-tier.bicep           # 2 DB VMs (B4ms, AZ 1 & 2)
```

**Success Criteria**:
- ✅ 6 VMs total (2 per tier)
- ✅ VMs distributed across AZ 1 and 2
- ✅ Correct VM sizes (B2s, B4ms)
- ✅ Managed Identity enabled

---

### Day 3: Bicep - Load Balancer & Deploy

**Tasks**:
1. Develop `modules/network/load-balancer.bicep`
2. Develop `modules/network/bastion.bicep`
3. Create `main.bicep` orchestrator
4. **Deploy to Azure test resource group**

**Deployment**:
```bash
# Create resource group
az group create \
  --name rg-workshop-test \
  --location eastus \
  --tags Environment=Test Workshop=BlogApp

# Deploy infrastructure
az deployment group create \
  --resource-group rg-workshop-test \
  --template-file materials/bicep/main.bicep \
  --parameters parameters.test.json \
  --name initial-deployment

# Wait 15-30 minutes for deployment
# Validate deployment
az deployment group show \
  --resource-group rg-workshop-test \
  --name initial-deployment \
  --query properties.provisioningState
```

**Success Criteria**:
- ✅ Deployment succeeds (provisioningState: Succeeded)
- ✅ All resources created in correct Availability Zones
- ✅ Load Balancer public IP accessible
- ✅ Bastion allows SSH to VMs

---

### Day 4-5: Backend Scaffolding (Parallel Work)

**Tasks** (while Azure infrastructure is deployed):
1. Initialize backend Node.js project
2. Set up TypeScript configuration
3. Create project structure
4. Install dependencies

**Commands**:
```bash
cd materials/backend

# Initialize npm project
npm init -y

# Install core dependencies
npm install express mongoose dotenv winston cors helmet
npm install jsonwebtoken jwks-rsa express-validator

# Install dev dependencies
npm install -D typescript @types/node @types/express
npm install -D @types/mongoose @types/jsonwebtoken
npm install -D eslint prettier nodemon ts-node

# Initialize TypeScript
npx tsc --init

# Create .env.example
cat > .env.example << 'EOF'
NODE_ENV=development
PORT=3000
MONGODB_URI=mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0
ENTRA_TENANT_ID=your-tenant-id
ENTRA_CLIENT_ID=your-client-id
KEY_VAULT_NAME=kv-blogapp-xxxxx
EOF

# Create directory structure
mkdir -p src/{config,middleware,routes,controllers,models,services,utils,types}
```

**Success Criteria**:
- ✅ `npm install` completes without errors
- ✅ TypeScript compilation works: `npx tsc`
- ✅ Can start dev server: `npm run dev` (even if empty)

---

### Day 6-7: Infrastructure Validation

**Tasks**:
1. Test Azure deployment thoroughly
2. Validate network connectivity
3. Document any issues
4. Refine Bicep templates if needed

**Validation Commands**:
```bash
# Test Bastion SSH access
az network bastion ssh \
  --name bastion-blogapp \
  --resource-group rg-workshop-test \
  --target-resource-id <web-vm-resource-id> \
  --auth-type password \
  --username azureuser

# From Web VM, test App VM connectivity
ping 10.0.2.4  # Should work (App VM private IP)

# From App VM, test DB VM connectivity
ping 10.0.3.4  # Should work (DB VM private IP)

# Test NSG rules (should fail from Internet)
curl http://10.0.2.4:3000  # Should timeout (NSG blocks)

# Test Load Balancer (should return 503 until backend deployed)
curl http://<load-balancer-ip>/health  # 503 expected (no backend yet)
```

**Success Criteria**:
- ✅ Can SSH to all VMs via Bastion
- ✅ VM-to-VM connectivity works within allowed paths
- ✅ NSG rules block unauthorized traffic
- ✅ Load Balancer is reachable (even if backend not deployed yet)

---

## Why Bicep First Works Best

### 1. Infrastructure is the Critical Path

**Workshop Requirement**: Students need working Azure infrastructure on Day 1.

**Timeline Analysis**:
- Bicep development: 1-2 weeks
- Backend development: 2-3 weeks
- Frontend development: 2-3 weeks

**Critical Path**: Infrastructure + Backend + Frontend = 6 weeks minimum

**If Bicep is last**: Backend (3 weeks) + Frontend (3 weeks) + Bicep (1 week rushed) = **7 weeks + HIGH RISK**

**If Bicep is first**: Bicep (1 week) + Backend (3 weeks parallel) + Frontend (2 weeks parallel) = **6 weeks + LOW RISK**

---

### 2. Real Integration Testing Throughout

**Bicep First** enables:
- Week 3: Test backend on Azure VMs (early integration)
- Week 4: Test frontend with deployed backend (realistic network)
- Week 5: Full stack on Azure (complete validation)
- Week 6: HA/DR testing (workshop scenarios)

**Local Dev First** delays:
- Week 6: First Azure deployment (late integration)
- Week 7: Integration issues discovered (crisis mode)
- No time for: HA testing, DR validation, student materials

---

### 3. Fail Fast Philosophy

**Azure Issues Discovered Early** (Bicep First):
- Quota limits exceeded? → Discovered Week 1 → Request increase immediately
- Region unavailable? → Discovered Week 1 → Switch regions
- Service limitations? → Discovered Week 1 → Adjust design
- Cost overruns? → Discovered Week 1 → Optimize VM sizing

**Azure Issues Discovered Late** (Local Dev First):
- Quota limits exceeded? → Discovered Week 6 → **PANIC** → Delay workshop
- Region unavailable? → Discovered Week 6 → Rewrite Bicep templates frantically
- Service limitations? → Discovered Week 6 → Redesign application
- Cost overruns? → Discovered Week 6 → No time to optimize

**Risk Impact**: Exponentially worse when discovered late.

---

### 4. Realistic Development Context

**With Deployed Infrastructure**:
- Backend developer knows: "I have 10.0.2.4 and 10.0.2.5 for app VMs"
- Frontend developer knows: "Load Balancer IP is 20.10.5.100"
- Database developer knows: "MongoDB is on 10.0.3.4:27017 and 10.0.3.5:27017"

**Code reflects reality**:
```typescript
// Backend connects to real MongoDB addresses
const MONGODB_URI = 'mongodb://10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0';

// Frontend connects to real Load Balancer
const API_URL = 'http://20.10.5.100/api';
```

**Without Infrastructure**:
- Everyone uses localhost
- Code assumes `localhost:27017`, `localhost:3000`
- Migration requires find-replace across codebase
- Bugs from localhost vs. private IP differences

---

### 5. Cost is Manageable

**Azure Costs During Development** (Bicep First):
- Week 1: $45 (deploy, test, keep running for 48 hours)
- Week 2: $0 (deallocate VMs when not testing)
- Week 3: $45 (restart VMs, deploy backend, test)
- Week 4: $0 (deallocate VMs, develop frontend locally)
- Week 5: $45 (restart VMs, deploy frontend, test)
- Week 6: $45 (HA/DR testing, keep running)

**Total**: ~$180 for 6 weeks (averaging $30/week)

**Cost Optimization**:
```bash
# When not actively testing, deallocate VMs
az vm deallocate --resource-group rg-workshop-test --name vm-web-az1
az vm deallocate --resource-group rg-workshop-test --name vm-web-az2
# ... repeat for all VMs

# Cost drops to ~$5/week (storage only, no compute charges)

# When needed, restart VMs
az vm start --resource-group rg-workshop-test --name vm-web-az1
# Takes 2-3 minutes to start
```

**ROI**: $180 investment buys:
- 6 weeks of integration testing capability
- Risk reduction (early issue detection)
- Realistic development environment
- Workshop readiness confidence

**Value**: Far exceeds cost (prevents potential weeks of rework).

---

## Decision Framework

### Choose Bicep First If:

✅ **Workshop timeline is fixed** (you MUST have infrastructure ready)  
✅ **You want to reduce late-stage risk** (fail fast philosophy)  
✅ **You value integration testing** (catch issues incrementally)  
✅ **You're comfortable with Bicep** (design docs provide detailed specs)  
✅ **Azure subscription is available** (can start deploying now)

**Confidence Level**: **95%** - This is the RIGHT approach for your project.

---

### Choose Local Dev First If:

⚠️ **Learning Bicep would be too time-consuming** (steep learning curve)  
⚠️ **Azure subscription access is uncertain** (waiting for approval)  
⚠️ **Psychological need to see working code quickly** (motivation factor)  
⚠️ **Workshop deadline is flexible** (can absorb delays)

**Confidence Level**: **40%** - Higher risk, but viable if above factors apply.

---

## Expected Outcomes (Bicep First)

### Week 1 Outcomes:
- ✅ Azure infrastructure deployed and validated
- ✅ VMs accessible via Bastion
- ✅ Load Balancer responding (even if no backend yet)
- ✅ NSG rules tested and working
- ✅ Availability Zones confirmed
- ✅ Backend project scaffolding complete

### Week 3 Outcomes:
- ✅ Backend API deployed to Azure VMs
- ✅ MongoDB replica set operational on Azure
- ✅ Load Balancer routing to backend
- ✅ Health checks passing
- ✅ Integration testing on Azure

### Week 5 Outcomes:
- ✅ Frontend deployed to Azure VMs
- ✅ End-to-end app working on Azure
- ✅ Authentication with Entra ID functional
- ✅ All API endpoints tested

### Week 6 Outcomes:
- ✅ HA testing complete (VM failover scenarios)
- ✅ DR testing complete (backup/restore)
- ✅ Student materials ready
- ✅ Workshop validated end-to-end

**Confidence**: **HIGH** - This timeline is achievable and realistic.

---

## Conclusion

**Recommendation**: **Start Bicep development TODAY**.

**First Task**: Create `materials/bicep/modules/network/vnet.bicep`

**Why Now**:
1. Design validation is complete (Stage 3.1 ✅)
2. Local MongoDB is working (development env ready)
3. Infrastructure is the critical path (longest pole)
4. Early validation reduces risk exponentially
5. Parallel development possible (maximize efficiency)

**What You Gain**:
- **Risk Reduction**: Azure issues discovered Week 1 (not Week 6)
- **Integration Testing**: Realistic environment from Week 3 onward
- **Workshop Readiness**: Infrastructure guaranteed ready on time
- **Development Confidence**: Code designed for actual deployment target
- **Cost Efficiency**: ~$30/week for world-class development environment

**What You Avoid**:
- Late-stage infrastructure failures
- Code rewrites for Azure compatibility
- Rushed Bicep development
- Workshop deadline pressure
- "Works on my machine" syndrome

---

## Next Steps

**Immediate Action** (Choose one to start):

**Option 1**: I create Bicep templates now
- `modules/network/vnet.bicep`
- `modules/network/nsg-web.bicep`
- `modules/network/nsg-app.bicep`
- `modules/network/nsg-db.bicep`

**Option 2**: You review this strategy first, then we proceed

**Option 3**: We start both Bicep AND backend scaffolding in parallel

**Your Move**: Let me know which option you prefer, and we'll begin Stage 3.2 immediately.

---

**Document Status**: Strategy documented for reference  
**Decision**: Pending your confirmation to proceed  
**Next Stage**: Stage 3.2 - Infrastructure as Code (Bicep Development)
