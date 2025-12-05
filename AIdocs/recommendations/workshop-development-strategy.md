# Workshop Development Strategy

**Created**: 2025-12-03  
**Purpose**: Strategic plan for developing Azure IaaS Workshop materials from design to delivery  
**Target**: 2-day workshop for AWS-experienced engineers learning Azure IaaS

---

## Executive Summary

### Current Status: ✅ Design Phase Complete

You have successfully completed **Phases 1-2** of the workshop development:

| Phase | Status | Completion |
|-------|--------|------------|
| 1. Planning | ✅ Complete | 100% |
| 2. Design | ✅ Complete | 100% |
| 3. Coding | 🔄 Ready to Start | 0% |
| 4. Implementation | ⏸️ Pending | 0% |

### What You Have
- ✅ Comprehensive workshop plan (`WorkshopPlan.md`)
- ✅ Azure Architecture Design (549 lines)
- ✅ Backend Application Design (6,443 lines)
- ✅ Frontend Application Design (937 lines)
- ✅ Database Design (2,316 lines)
- ✅ Repository-Wide Design Rules (1,025 lines)
- ✅ Strategic reviews and feedback from AI consultants
- ✅ Empty materials directories ready for code

### What's Missing
- ❌ **No code written yet** (backend/, frontend/, bicep/ all empty)
- ❌ No Bicep infrastructure templates
- ❌ No GitHub Actions workflows
- ❌ No deployment scripts
- ❌ No student-facing documentation

---

## Phase Assessment: Your Steps vs. Recommended Approach

### Your Proposed Steps (Analysis)

Your proposed workflow is **fundamentally correct** but needs **refinement**:

#### ✅ Correct Aspects:
1. Logical progression: Design → Code → Deploy → Test
2. Separated concerns (DB, Backend, Frontend, Infrastructure)
3. Included testing phases (integration, E2E)
4. Recognized need for deployment procedures

#### ⚠️ Gaps and Improvements Needed:

**Gap 1: Missing Pre-Coding Validation**
- Your Step 3.1 ("Check sufficient design documents") is vague
- **Recommendation**: Add explicit design validation checklist

**Gap 2: No Incremental Development Strategy**
- Trying to code everything then deploy can cause late discovery of issues
- **Recommendation**: Adopt iterative build-test-refine cycles

**Gap 3: Missing Student-Facing Materials**
- Your steps focus on building artifacts but not workshop instructions
- **Recommendation**: Develop student materials in parallel with code

**Gap 4: No Testing Strategy Details**
- Steps 4.7-4.8 (Integration/E2E test) lack methodology
- **Recommendation**: Define test scenarios and acceptance criteria

**Gap 5: No Code Review/Quality Gates**
- Your Step 3.3 ("Evaluate the code") is too late and vague
- **Recommendation**: Build in continuous validation

**Gap 6: Missing Dry Run**
- No practice workshop execution before production delivery
- **Recommendation**: Add pilot testing phase

---

## Recommended Development Strategy

### Strategic Principles

1. **Iterate, Don't Waterfall**: Build → Test → Refine in small cycles
2. **Student-Centric**: Every artifact should answer "How does this help students learn?"
3. **Fail Fast**: Validate early, discover issues before they compound
4. **Automation First**: Automate deployments to reduce workshop complexity
5. **Documentation is Code**: Treat student instructions as critical as source code

### Phase 3: Coding (Detailed Breakdown)

#### Stage 3.1: Pre-Coding Validation ⏱️ 2-4 hours

**Objective**: Ensure design documents provide sufficient detail to begin coding

**Activities**:
1. **Design Completeness Audit**
   - [ ] Read all design documents end-to-end
   - [ ] Create missing section checklist
   - [ ] Validate cross-document consistency (API contracts, data models)
   - [ ] Verify all security patterns documented (RepositoryWideDesignRules.md)

2. **Technology Stack Validation**
   - [ ] Confirm all npm packages are compatible (React 18 + MSAL + Vite)
   - [ ] Verify MongoDB 7.0 + Mongoose 8 compatibility
   - [ ] Check Bicep API versions are current
   - [ ] Validate Ubuntu 24.04 LTS package availability (Node.js 20, MongoDB 7)

3. **Development Environment Setup**
   - [ ] Install required tools (Node.js 20, Azure CLI, Bicep CLI)
   - [ ] Set up local testing environment (MongoDB local, or Docker)
   - [ ] Configure VS Code extensions (ESLint, Prettier, Bicep)
   - [ ] Create `.gitignore` and `.env.example` templates

4. **Create Development Roadmap**
   - [ ] Prioritize which tier to build first (see Stage 3.2)
   - [ ] Define intermediate milestones with acceptance criteria
   - [ ] Identify critical path dependencies
   - [ ] Estimate time per component (be realistic!)

**Deliverable**: Go/No-Go decision document with any design gaps identified

---

#### Stage 3.2: Infrastructure as Code (Bicep) ⏱️ 16-24 hours

**Priority**: **Build this FIRST** - nothing works without infrastructure

**Rationale**:
- Students need working infrastructure on Day 1
- Bicep deployment is the foundation for all other tiers
- Early validation of Azure resource compatibility
- Enables parallel development (backend/frontend can develop locally)

**Sub-Stage 3.2.1: Core Network Infrastructure (4-6 hours)**

**Build Order**:
1. **Module**: `modules/network/vnet.bicep`
   - VNet with 4 subnets (web, app, db, bastion)
   - NSGs for each tier with detailed rules
   - Outputs: Subnet IDs

2. **Module**: `modules/network/nsg-rules.bicep`
   - NSG rules as documented in AzureArchitectureDesign.md
   - Web tier: Allow 80/443 from Internet, 22 from Bastion
   - App tier: Allow 3000 from Web subnet, 22 from Bastion
   - DB tier: Allow 27017 from App subnet, 22 from Bastion

3. **Module**: `modules/network/bastion.bicep`
   - Azure Bastion with Standard SKU
   - Public IP for Bastion

**Testing**:
```bash
# Deploy and validate
az deployment group create \
  --resource-group rg-workshop-test \
  --template-file modules/network/vnet.bicep

# Verify subnets created
az network vnet subnet list \
  --resource-group rg-workshop-test \
  --vnet-name vnet-blogapp-prod \
  --output table
```

**Success Criteria**:
- [ ] All 4 subnets created with correct CIDR ranges
- [ ] NSGs applied to subnets
- [ ] NSG rules match design specifications
- [ ] Bastion can be deployed (test in isolated RG)

---

**Sub-Stage 3.2.2: Compute Resources (6-8 hours)**

**Build Order**:
1. **Module**: `modules/compute/vm.bicep` (reusable VM template)
   - Parameters: vmName, vmSize, subnetId, availabilityZone, nsgId
   - Managed Identity enabled
   - Cloud-init or Custom Script Extension placeholder
   - Azure Monitor Agent extension

2. **Module**: `modules/compute/web-tier.bicep`
   - Deploy 2 Web VMs (Standard_B2s) across AZ 1 and 2
   - Attach to web subnet
   - Custom Script Extension to install NGINX
   - Outputs: Private IPs

3. **Module**: `modules/compute/app-tier.bicep`
   - Deploy 2 App VMs (Standard_B2s) across AZ 1 and 2
   - Attach to app subnet
   - Custom Script Extension to install Node.js 20
   - Outputs: Private IPs

4. **Module**: `modules/compute/db-tier.bicep`
   - Deploy 2 DB VMs (Standard_B4ms) across AZ 1 and 2
   - Attach Premium SSD data disk (128 GB)
   - Attach to db subnet
   - Custom Script Extension to install MongoDB 7.0
   - Outputs: Private IPs for replica set config

**Testing** (per module):
```bash
# Test single VM deployment
az deployment group create \
  --resource-group rg-workshop-test \
  --template-file modules/compute/vm.bicep \
  --parameters vmName=test-vm vmSize=Standard_B2s

# Verify VM created in correct AZ
az vm show \
  --resource-group rg-workshop-test \
  --name test-vm \
  --query "zones" \
  --output table

# Test SSH access via Bastion
az network bastion ssh \
  --name bastion-blogapp \
  --resource-group rg-workshop-test \
  --target-resource-id /subscriptions/.../test-vm \
  --auth-type password \
  --username azureuser
```

**Success Criteria**:
- [ ] VMs deployed across correct Availability Zones
- [ ] VMs can be accessed via Bastion
- [ ] Managed Identity configured
- [ ] OS disks and data disks attached
- [ ] Azure Monitor Agent installed and reporting

---

**Sub-Stage 3.2.3: Load Balancing and Public Access (3-4 hours)**

**Build Order**:
1. **Module**: `modules/network/public-ip.bicep`
   - Standard SKU (zone-redundant)
   - Static allocation
   - DNS label (optional)

2. **Module**: `modules/network/load-balancer.bicep`
   - Standard Load Balancer (not Basic)
   - Frontend IP configuration (public IP)
   - Backend pool: Web tier VMs
   - Health probe: HTTP on port 80 (path `/health`)
   - Load balancing rule: Port 80 and 443

**Testing**:
```bash
# Deploy load balancer
az deployment group create \
  --resource-group rg-workshop-test \
  --template-file modules/network/load-balancer.bicep

# Test health probe
curl http://<PUBLIC_IP>/health

# Test load distribution (repeat and check which VM responds)
for i in {1..10}; do
  curl -s http://<PUBLIC_IP>/ | grep "Server:"
done
```

**Success Criteria**:
- [ ] Public IP accessible from Internet
- [ ] Health probe succeeds (after NGINX config in Stage 3.4)
- [ ] Traffic distributed across Web tier VMs
- [ ] HTTPS configuration ready (cert placeholder)

---

**Sub-Stage 3.2.4: Monitoring and Storage (3-4 hours)**

**Build Order**:
1. **Module**: `modules/monitoring/log-analytics.bicep`
   - Log Analytics Workspace
   - Retention: 30 days (workshop acceptable)
   - Data sources: VM metrics, logs

2. **Module**: `modules/monitoring/alerts.bicep`
   - Alert rules for CPU, memory, disk
   - Action group (email notifications)

3. **Module**: `modules/storage/storage-account.bicep`
   - General-purpose v2
   - LRS replication (workshop acceptable)
   - Blob container for static assets
   - Private endpoint (optional, document as enhancement)

**Testing**:
```bash
# Verify Log Analytics receiving data
az monitor log-analytics query \
  --workspace <WORKSPACE_ID> \
  --analytics-query "Heartbeat | take 10"

# Upload test blob
az storage blob upload \
  --account-name <STORAGE_ACCOUNT> \
  --container-name assets \
  --name test.txt \
  --file test.txt
```

**Success Criteria**:
- [ ] Log Analytics Workspace created
- [ ] Azure Monitor Agent sending data (verify Heartbeat table)
- [ ] Alert rules configured (test by stopping a VM)
- [ ] Storage account accessible from App tier VMs

---

**Sub-Stage 3.2.5: Security and Secrets (2-3 hours)**

**Build Order**:
1. **Module**: `modules/security/key-vault.bicep`
   - Azure Key Vault (Standard SKU)
   - RBAC authorization (not access policies)
   - Secrets: MongoDB connection string, JWT secret

2. **Module**: `modules/security/managed-identity-rbac.bicep`
   - Assign "Key Vault Secrets User" role to App tier VMs
   - Assign "Storage Blob Data Contributor" to App tier VMs

**Testing**:
```bash
# Store secret in Key Vault
az keyvault secret set \
  --vault-name kv-blogapp-xxxx \
  --name mongodb-password \
  --value "SecurePassword123!"

# Test retrieval from VM (using Managed Identity)
# SSH to App VM via Bastion
curl -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net"
```

**Success Criteria**:
- [ ] Key Vault created and secrets stored
- [ ] App tier VMs can retrieve secrets via Managed Identity
- [ ] No secrets hardcoded in Bicep files
- [ ] RBAC permissions working

---

**Sub-Stage 3.2.6: Main Template and Deployment (2-3 hours)**

**Build Order**:
1. **File**: `main.bicep`
   - Orchestrates all modules
   - Parameters: environment, location, adminUsername
   - Outputs: Load balancer public IP, Bastion ID, Key Vault name

2. **File**: `azuredeploy.json` (compiled from Bicep)
   - For "Deploy to Azure" button

3. **File**: `.github/workflows/bicep-deploy.yml`
   - GitHub Actions workflow for automated deployment
   - Uses Azure CLI and Bicep

**Testing**:
```bash
# Validate entire template
az deployment group validate \
  --resource-group rg-workshop-prod \
  --template-file main.bicep \
  --parameters parameters.prod.json

# Deploy full stack
az deployment group create \
  --resource-group rg-workshop-prod \
  --template-file main.bicep \
  --parameters parameters.prod.json \
  --name workshop-deployment-$(date +%Y%m%d-%H%M%S)

# Verify all resources deployed
az resource list \
  --resource-group rg-workshop-prod \
  --output table
```

**Success Criteria**:
- [ ] Full infrastructure deploys in 15-30 minutes
- [ ] No deployment errors
- [ ] All outputs populated correctly
- [ ] Resources tagged appropriately (Environment, CostCenter, etc.)
- [ ] "Deploy to Azure" button works

**Deliverable**: Working Bicep templates deployable via Azure Portal button

---

#### Stage 3.3: Database Tier (MongoDB) ⏱️ 8-12 hours

**Priority**: Build SECOND (after infrastructure) - backend depends on this

**Sub-Stage 3.3.1: MongoDB Installation and Configuration (4-6 hours)**

**Artifacts to Create**:
1. **Script**: `materials/bicep/scripts/install-mongodb.sh`
   - Install MongoDB 7.0 on Ubuntu 24.04
   - Configure MongoDB for replica set
   - Set up systemd service
   - Configure firewall rules

```bash
#!/bin/bash
# install-mongodb.sh

# Install MongoDB 7.0
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/mongodb-server-7.0.gpg

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
   sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt-get update
sudo apt-get install -y mongodb-org

# Configure replica set
sudo sed -i 's/#replication:/replication:\n  replSetName: "blogapp-rs0"/' /etc/mongod.conf
sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

# Start MongoDB
sudo systemctl enable mongod
sudo systemctl start mongod
```

2. **Script**: `materials/bicep/scripts/init-replica-set.sh`
   - Initialize MongoDB replica set
   - Add members
   - Create admin user

```javascript
// init-replica-set.js
rs.initiate({
  _id: "blogapp-rs0",
  members: [
    { _id: 0, host: "10.0.3.4:27017", priority: 2 },
    { _id: 1, host: "10.0.3.5:27017", priority: 1 }
  ]
});

// Create admin user
use admin;
db.createUser({
  user: "adminUser",
  pwd: "<FROM_KEY_VAULT>",
  roles: [{ role: "root", db: "admin" }]
});
```

**Testing**:
```bash
# SSH to DB VM 1 via Bastion
# Run installation script
sudo bash install-mongodb.sh

# Verify MongoDB running
sudo systemctl status mongod

# Initialize replica set (on primary only)
mongosh --eval "rs.initiate({...})"

# Check replica set status
mongosh --eval "rs.status()"

# Verify secondary syncing
mongosh --host 10.0.3.5:27017 --eval "rs.status()"
```

**Success Criteria**:
- [ ] MongoDB 7.0 installed on both DB VMs
- [ ] Replica set initialized with 2 members
- [ ] Primary elected (usually the higher priority node)
- [ ] Secondary in SECONDARY state (not ARBITER)
- [ ] Replication lag < 1 second

---

**Sub-Stage 3.3.2: Database Schema and Seed Data (4-6 hours)**

**Artifacts to Create**:
1. **Script**: `materials/backend/scripts/create-schema.js`
   - Create database `blogapp`
   - Create collections with validation rules
   - Create indexes

```javascript
// create-schema.js
use blogapp;

// Users collection
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["email", "displayName", "entraIdSub"],
      properties: {
        email: { bsonType: "string", pattern: "^.+@.+$" },
        displayName: { bsonType: "string", minLength: 1 },
        entraIdSub: { bsonType: "string" },
        createdAt: { bsonType: "date" }
      }
    }
  }
});

// Create indexes
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "entraIdSub": 1 }, { unique: true });

// Posts collection (see DatabaseDesign.md for full schema)
db.createCollection("posts", {
  validator: { /* ... */ }
});

db.posts.createIndex({ "authorId": 1 });
db.posts.createIndex({ "status": 1, "publishedAt": -1 });
db.posts.createIndex({ "tags": 1 });
```

2. **Script**: `materials/backend/scripts/seed-data.js`
   - Create 5-10 sample users
   - Create 20-30 sample blog posts
   - Create 50-100 sample comments

```javascript
// seed-data.js
use blogapp;

// Sample users
const users = [
  {
    email: "alice@example.com",
    displayName: "Alice Johnson",
    entraIdSub: "00000000-0000-0000-0000-000000000001",
    avatarUrl: "https://api.dicebear.com/7.x/avataaars/svg?seed=Alice",
    bio: "Cloud architect learning Azure",
    createdAt: new Date()
  },
  // ... more users
];

db.users.insertMany(users);

// Sample posts
const posts = [
  {
    title: "Getting Started with Azure VMs",
    content: "In this post, we'll explore...",
    authorId: users[0]._id,
    status: "published",
    publishedAt: new Date("2025-11-01"),
    tags: ["azure", "vm", "iaas"],
    // ... more fields
  },
  // ... more posts
];

db.posts.insertMany(posts);
```

**Testing**:
```bash
# Run schema creation
mongosh --host 10.0.3.4:27017 < create-schema.js

# Verify collections created
mongosh --host 10.0.3.4:27017 --eval "db.getCollectionNames()"

# Run seed data
mongosh --host 10.0.3.4:27017 < seed-data.js

# Verify data inserted
mongosh --host 10.0.3.4:27017 --eval "db.users.countDocuments()"
mongosh --host 10.0.3.4:27017 --eval "db.posts.countDocuments()"

# Test replica set replication
mongosh --host 10.0.3.5:27017 --eval "db.users.countDocuments()" --readPreference secondary
```

**Success Criteria**:
- [ ] Collections created with validation rules
- [ ] Indexes created on appropriate fields
- [ ] Seed data inserted (5+ users, 20+ posts, 50+ comments)
- [ ] Data replicated to secondary node
- [ ] Can query from secondary with `readPreference=secondary`

**Deliverable**: Fully configured MongoDB replica set with sample data

---

#### Stage 3.4: Backend API (Express/TypeScript) ⏱️ 20-30 hours

**Priority**: Build THIRD (depends on database and infrastructure)

**Sub-Stage 3.4.1: Project Scaffolding and Configuration (3-4 hours)**

**Artifacts to Create**:
1. **File**: `materials/backend/package.json`
   - Dependencies: express, mongoose, jsonwebtoken, jwks-rsa, helmet, cors, etc.
   - Scripts: `dev`, `build`, `start`, `test`, `lint`

2. **File**: `materials/backend/tsconfig.json`
   - Strict mode enabled
   - Target: ES2022
   - Module: CommonJS or ESNext

3. **File**: `materials/backend/.eslintrc.json`
   - Google TypeScript Style Guide rules
   - Prettier integration

4. **File**: `materials/backend/src/config/environment.ts`
   - Load and validate environment variables
   - Type-safe configuration object

```typescript
// environment.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  PORT: z.string().transform(Number).default('3000'),
  MONGODB_URI: z.string().url(),
  JWT_ISSUER: z.string().url(),
  JWT_AUDIENCE: z.string(),
  AZURE_KEY_VAULT_NAME: z.string().optional(),
});

export const config = envSchema.parse(process.env);
```

5. **File**: `materials/backend/.env.example`
   - Template for environment variables (no secrets)

```bash
NODE_ENV=development
PORT=3000
MONGODB_URI=mongodb://10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred
JWT_ISSUER=https://login.microsoftonline.com/<TENANT_ID>/v2.0
JWT_AUDIENCE=api://<APP_ID>
AZURE_KEY_VAULT_NAME=kv-blogapp-xxxx
```

**Testing**:
```bash
cd materials/backend

# Install dependencies
npm install

# Verify TypeScript compilation
npm run build

# Run linting
npm run lint

# Verify environment config loads
npm run dev
# Should fail if .env missing (expected)
```

**Success Criteria**:
- [ ] `npm install` completes without errors
- [ ] TypeScript compiles without errors
- [ ] ESLint passes (or only warns, no errors)
- [ ] Environment validation works (rejects missing vars)

---

**Sub-Stage 3.4.2: Database Connection and Models (4-6 hours)**

**Artifacts to Create**:
1. **File**: `materials/backend/src/config/database.ts`
   - MongoDB connection with retry logic
   - Connection pooling configuration
   - Error handling

```typescript
// database.ts
import mongoose from 'mongoose';
import { config } from './environment';

export async function connectToDatabase(): Promise<void> {
  try {
    await mongoose.connect(config.MONGODB_URI, {
      maxPoolSize: 10,
      minPoolSize: 5,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    });
    console.log('✅ Connected to MongoDB replica set');
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error);
    process.exit(1);
  }
}
```

2. **File**: `materials/backend/src/models/user.model.ts`
   - Mongoose schema for User (see DatabaseDesign.md)
   - TypeScript interface
   - Methods and virtuals

```typescript
// user.model.ts
import mongoose, { Document, Schema } from 'mongoose';

export interface IUser extends Document {
  email: string;
  displayName: string;
  entraIdSub: string;
  avatarUrl?: string;
  bio?: string;
  role: 'user' | 'admin';
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    match: /^.+@.+$/,
  },
  displayName: {
    type: String,
    required: true,
    minlength: 1,
    maxlength: 100,
  },
  entraIdSub: {
    type: String,
    required: true,
    unique: true,
  },
  avatarUrl: String,
  bio: {
    type: String,
    maxlength: 500,
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user',
  },
}, {
  timestamps: true,
});

export const User = mongoose.model<IUser>('User', userSchema);
```

3. **File**: `materials/backend/src/models/post.model.ts`
   - Mongoose schema for Post (see DatabaseDesign.md)

4. **File**: `materials/backend/src/models/comment.model.ts`
   - Mongoose schema for Comment (see DatabaseDesign.md)

**Testing**:
```bash
# Create test script
# materials/backend/src/test-db.ts
import { connectToDatabase } from './config/database';
import { User } from './models/user.model';

async function testDb() {
  await connectToDatabase();
  
  const user = await User.create({
    email: 'test@example.com',
    displayName: 'Test User',
    entraIdSub: 'test-sub-123',
  });
  
  console.log('✅ User created:', user);
  process.exit(0);
}

testDb();

# Run test
npx ts-node src/test-db.ts
```

**Success Criteria**:
- [ ] Database connection succeeds
- [ ] Models can create documents
- [ ] Validation rules work (try invalid data)
- [ ] Indexes created automatically

---

**Sub-Stage 3.4.3: Authentication Middleware (4-6 hours)**

**Artifacts to Create**:
1. **File**: `materials/backend/src/middleware/auth.middleware.ts`
   - JWT validation with JWKS
   - Extract user from token
   - Attach user to request object

```typescript
// auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { config } from '../config/environment';

const client = jwksClient({
  jwksUri: `https://login.microsoftonline.com/${config.TENANT_ID}/discovery/v2.0/keys`,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
});

function getKey(header: any, callback: any) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
}

export async function authenticateJWT(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: { message: 'No token provided' } });
    return;
  }
  
  const token = authHeader.substring(7);
  
  jwt.verify(token, getKey, {
    issuer: config.JWT_ISSUER,
    audience: config.JWT_AUDIENCE,
    algorithms: ['RS256'],
  }, (err, decoded) => {
    if (err) {
      res.status(401).json({ error: { message: 'Invalid token' } });
      return;
    }
    
    req.user = decoded; // Attach user to request
    next();
  });
}
```

2. **File**: `materials/backend/src/types/express.d.ts`
   - Extend Express Request type

```typescript
// express.d.ts
import { JwtPayload } from 'jsonwebtoken';

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}
```

**Testing**:
```bash
# Test with valid JWT (get from MSAL in browser)
curl -H "Authorization: Bearer <VALID_JWT>" \
  http://localhost:3000/api/posts

# Test with invalid JWT
curl -H "Authorization: Bearer invalid_token" \
  http://localhost:3000/api/posts
# Should return 401 Unauthorized
```

**Success Criteria**:
- [ ] Valid JWTs accepted
- [ ] Invalid JWTs rejected with 401
- [ ] Expired JWTs rejected
- [ ] User info extracted from token

---

**Sub-Stage 3.4.4: API Routes and Controllers (8-12 hours)**

**Artifacts to Create** (per resource):

1. **Posts API**:
   - `src/routes/post.routes.ts` - Route definitions
   - `src/controllers/post.controller.ts` - Business logic
   - `src/validators/post.validator.ts` - Input validation

```typescript
// post.routes.ts
import express from 'express';
import { authenticateJWT } from '../middleware/auth.middleware';
import { PostController } from '../controllers/post.controller';
import { validateCreatePost, validateUpdatePost } from '../validators/post.validator';

const router = express.Router();
const postController = new PostController();

// Public routes
router.get('/', postController.getAllPosts);
router.get('/:id', postController.getPostById);

// Protected routes
router.post('/', authenticateJWT, validateCreatePost, postController.createPost);
router.put('/:id', authenticateJWT, validateUpdatePost, postController.updatePost);
router.delete('/:id', authenticateJWT, postController.deletePost);

export default router;
```

```typescript
// post.controller.ts
import { Request, Response } from 'express';
import { Post } from '../models/post.model';
import { User } from '../models/user.model';

export class PostController {
  async getAllPosts(req: Request, res: Response): Promise<void> {
    try {
      const { page = 1, limit = 10, status = 'published' } = req.query;
      
      const posts = await Post.find({ status })
        .sort({ publishedAt: -1 })
        .limit(Number(limit))
        .skip((Number(page) - 1) * Number(limit))
        .populate('authorId', 'displayName avatarUrl');
      
      const totalCount = await Post.countDocuments({ status });
      
      res.json({
        data: posts,
        pagination: {
          page: Number(page),
          pageSize: Number(limit),
          totalCount,
          totalPages: Math.ceil(totalCount / Number(limit)),
        },
      });
    } catch (error) {
      res.status(500).json({ error: { message: 'Internal server error' } });
    }
  }
  
  async createPost(req: Request, res: Response): Promise<void> {
    try {
      // Find or create user from JWT
      let user = await User.findOne({ entraIdSub: req.user!.sub });
      if (!user) {
        user = await User.create({
          email: req.user!.email,
          displayName: req.user!.name,
          entraIdSub: req.user!.sub,
        });
      }
      
      const post = await Post.create({
        ...req.body,
        authorId: user._id,
        publishedAt: req.body.status === 'published' ? new Date() : null,
      });
      
      res.status(201).json({ data: post });
    } catch (error) {
      res.status(500).json({ error: { message: 'Failed to create post' } });
    }
  }
  
  // ... other methods
}
```

```typescript
// post.validator.ts
import { body, validationResult } from 'express-validator';
import { Request, Response, NextFunction } from 'express';

export const validateCreatePost = [
  body('title')
    .trim()
    .isLength({ min: 5, max: 200 })
    .withMessage('Title must be between 5 and 200 characters'),
  body('content')
    .trim()
    .isLength({ min: 50, max: 50000 })
    .withMessage('Content must be between 50 and 50,000 characters'),
  body('excerpt')
    .optional()
    .trim()
    .isLength({ max: 500 }),
  body('tags')
    .optional()
    .isArray({ max: 10 })
    .withMessage('Maximum 10 tags allowed'),
  body('status')
    .isIn(['draft', 'published'])
    .withMessage('Status must be draft or published'),
  
  (req: Request, res: Response, next: NextFunction) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ error: { message: 'Validation failed', details: errors.array() } });
      return;
    }
    next();
  },
];
```

2. **Comments API**: Similar structure
   - `src/routes/comment.routes.ts`
   - `src/controllers/comment.controller.ts`
   - `src/validators/comment.validator.ts`

3. **Users API**: Similar structure
   - `src/routes/user.routes.ts`
   - `src/controllers/user.controller.ts`

**Testing** (per endpoint):
```bash
# Test GET /api/posts (public)
curl http://localhost:3000/api/posts

# Test POST /api/posts (protected)
curl -X POST http://localhost:3000/api/posts \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Post",
    "content": "This is a test post content that is long enough to pass validation...",
    "status": "published",
    "tags": ["test", "azure"]
  }'

# Test validation error
curl -X POST http://localhost:3000/api/posts \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Too short"}'
# Should return 400 with validation errors

# Test pagination
curl "http://localhost:3000/api/posts?page=2&limit=5"
```

**Success Criteria**:
- [ ] All CRUD endpoints functional
- [ ] Authentication enforced on protected routes
- [ ] Validation working (reject invalid input)
- [ ] Pagination working
- [ ] Error responses follow standard format
- [ ] Logging structured and informative

---

**Sub-Stage 3.4.5: Error Handling and Logging (2-3 hours)**

**Artifacts to Create**:
1. **File**: `materials/backend/src/middleware/error.middleware.ts`
   - Global error handler
   - Sanitize error responses

```typescript
// error.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { config } from '../config/environment';

export function errorHandler(
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  console.error('❌ Error:', {
    message: err.message,
    stack: config.NODE_ENV === 'development' ? err.stack : undefined,
    path: req.path,
    method: req.method,
  });
  
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal server error';
  
  res.status(statusCode).json({
    error: {
      code: err.code || 'INTERNAL_ERROR',
      message,
      ...(config.NODE_ENV === 'development' && { stack: err.stack }),
    },
  });
}
```

2. **File**: `materials/backend/src/utils/logger.ts`
   - Structured logging with Winston

```typescript
// logger.ts
import winston from 'winston';
import { config } from '../config/environment';

export const logger = winston.createLogger({
  level: config.NODE_ENV === 'production' ? 'info' : 'debug',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
    }),
  ],
});

// Sanitize sensitive data
logger.info = ((originalInfo) => {
  return (message: string, meta?: any) => {
    // Redact passwords, tokens, etc.
    const sanitizedMeta = JSON.parse(JSON.stringify(meta || {}), (key, value) => {
      if (['password', 'token', 'authorization'].includes(key.toLowerCase())) {
        return '***REDACTED***';
      }
      return value;
    });
    
    return originalInfo(message, sanitizedMeta);
  };
})(logger.info.bind(logger));
```

**Testing**:
```bash
# Trigger error
curl http://localhost:3000/api/posts/invalid_id
# Should log error and return 500

# Check log files
cat logs/error.log
cat logs/combined.log

# Verify sensitive data redacted
# Add test with password in request body, verify not logged
```

**Success Criteria**:
- [ ] Errors caught and handled gracefully
- [ ] Logs structured (JSON format)
- [ ] Sensitive data never logged
- [ ] Stack traces only in development

---

**Sub-Stage 3.4.6: Deployment Configuration (2-3 hours)**

**Artifacts to Create**:
1. **File**: `materials/backend/ecosystem.config.js` (PM2)
   - Process manager configuration

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'blogapp-api',
    script: './dist/server.js',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
  }],
};
```

2. **File**: `materials/backend/deploy.sh`
   - Deployment script for App tier VMs

```bash
#!/bin/bash
# deploy.sh

set -e

echo "📦 Installing dependencies..."
npm ci --production

echo "🔨 Building TypeScript..."
npm run build

echo "🚀 Restarting PM2..."
pm2 restart ecosystem.config.js

echo "✅ Deployment complete!"
pm2 status
```

3. **File**: `.github/workflows/backend-deploy.yml`
   - GitHub Actions workflow

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths:
      - 'materials/backend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Install dependencies
        working-directory: materials/backend
        run: npm ci
      
      - name: Run tests
        working-directory: materials/backend
        run: npm test
      
      - name: Build
        working-directory: materials/backend
        run: npm run build
      
      - name: Deploy to App VMs
        run: |
          # SSH to App VMs and deploy
          # (Use Azure Bastion or SSH keys)
```

**Testing**:
```bash
# Test PM2 configuration
pm2 start ecosystem.config.js
pm2 status
pm2 logs blogapp-api

# Test deployment script
bash deploy.sh

# Verify API running
curl http://localhost:3000/api/posts
```

**Success Criteria**:
- [ ] PM2 manages process lifecycle
- [ ] Deployment script works
- [ ] GitHub Actions workflow triggers on push
- [ ] API accessible after deployment

**Deliverable**: Fully functional backend API with deployment automation

---

#### Stage 3.5: Frontend Application (React/TypeScript) ⏱️ 20-30 hours

**Priority**: Build FOURTH (depends on backend API)

**Note**: This section follows the same detailed structure as backend. Due to token limits, I'll provide the high-level breakdown. Would you like me to expand any sub-stage?

**Sub-Stages**:
1. **3.5.1: Project Scaffolding** (3-4 hours)
   - Vite + React + TypeScript setup
   - TailwindCSS configuration
   - ESLint + Prettier
   - `.env.example` with MSAL config

2. **3.5.2: Authentication with MSAL** (4-6 hours)
   - MSAL configuration (`msalConfig.ts`)
   - Authentication context (`AuthContext.tsx`)
   - Protected route component
   - Login/logout flows

3. **3.5.3: API Client and React Query** (3-4 hours)
   - Axios instance with interceptors
   - React Query setup
   - Custom hooks for API calls

4. **3.5.4: UI Components** (8-12 hours)
   - Layout components (Header, Footer, Sidebar)
   - Post list component
   - Post detail component
   - Post editor component
   - Comment components
   - User profile component

5. **3.5.5: Routing and Pages** (2-3 hours)
   - React Router setup
   - Home, Post Detail, Create Post, Edit Post, Profile pages

6. **3.5.6: Deployment Configuration** (2-3 hours)
   - Build script for production
   - NGINX configuration for SPA routing
   - GitHub Actions workflow

**Testing Strategy**:
- Component tests with Vitest + React Testing Library
- E2E tests with Playwright (optional, time permitting)
- Accessibility testing with axe-core

**Deliverable**: Production-ready React application

---

#### Stage 3.6: Integration and Testing ⏱️ 8-12 hours

**Objective**: Verify all tiers work together

**Sub-Stage 3.6.1: Local Integration Testing** (4-6 hours)

**Activities**:
1. Run full stack locally (MongoDB + Backend + Frontend)
2. Test complete user flows:
   - [ ] User can login with MSAL
   - [ ] User can view post list
   - [ ] User can create new post
   - [ ] User can edit own post
   - [ ] User can delete own post
   - [ ] User can add comment
   - [ ] Data persists in MongoDB
3. Test error scenarios:
   - [ ] Invalid JWT handled gracefully
   - [ ] Network errors show user-friendly messages
   - [ ] Validation errors displayed
4. Test performance:
   - [ ] Page load time < 3 seconds
   - [ ] API response time < 500ms
   - [ ] Lighthouse score > 90

**Tools**:
- Browser DevTools
- Postman/Insomnia (API testing)
- Lighthouse (performance)

---

**Sub-Stage 3.6.2: Azure Integration Testing** (4-6 hours)

**Activities**:
1. Deploy full stack to Azure (using Bicep + scripts)
2. Test complete flows in Azure environment:
   - [ ] Access via Load Balancer public IP
   - [ ] HTTPS working (if configured)
   - [ ] Authentication with real Entra ID tenant
   - [ ] Data persistence across VM restarts
   - [ ] Load balancer distributing traffic
3. Test Azure-specific features:
   - [ ] Managed Identity retrieving Key Vault secrets
   - [ ] Azure Monitor Agent sending metrics
   - [ ] Log Analytics receiving logs
   - [ ] MongoDB replica set failover

**Testing Procedure**:
```bash
# 1. Deploy infrastructure
az deployment group create --template-file main.bicep ...

# 2. Configure MongoDB replica set
# SSH to DB VMs via Bastion, run init scripts

# 3. Deploy backend
# SSH to App VMs, run deploy.sh

# 4. Deploy frontend
# SSH to Web VMs, build and configure NGINX

# 5. Test application
curl https://<PUBLIC_IP>/
# Open in browser, test all features

# 6. Test failover
# Stop one Web VM
sudo systemctl stop nginx
# Verify app still accessible

# Stop one DB VM
sudo systemctl stop mongod
# Verify app still functional (may have brief interruption)
```

**Success Criteria**:
- [ ] All features work in Azure
- [ ] HA validated (survive single VM failure)
- [ ] Monitoring data visible in Log Analytics
- [ ] No hardcoded secrets (all from Key Vault)

**Deliverable**: Fully tested and validated Azure deployment

---

### Phase 4: Implementation (Workshop Preparation) ⏱️ 20-30 hours

**Objective**: Create student-facing materials and workshop logistics

#### Stage 4.1: Student Documentation ⏱️ 8-12 hours

**Artifacts to Create**:

1. **File**: `docs/student-guide/00-prerequisites.md`
   - Prerequisites checklist
   - Azure subscription setup
   - VS Code extensions
   - Azure CLI installation

2. **File**: `docs/student-guide/01-infrastructure-deployment.md`
   - Step-by-step Bicep deployment
   - "Deploy to Azure" button instructions
   - Validation steps
   - Troubleshooting common errors

3. **File**: `docs/student-guide/02-database-configuration.md`
   - MongoDB replica set setup
   - Seed data loading
   - Connection testing

4. **File**: `docs/student-guide/03-backend-deployment.md`
   - Backend deployment steps
   - Environment configuration
   - PM2 setup
   - Testing API endpoints

5. **File**: `docs/student-guide/04-frontend-deployment.md`
   - Frontend build and deployment
   - NGINX configuration
   - Testing application

6. **File**: `docs/student-guide/05-monitoring-setup.md`
   - Azure Monitor configuration
   - Log Analytics queries
   - Alert rule creation

7. **File**: `docs/student-guide/06-ha-testing.md`
   - Failure scenario testing
   - Observing failover behavior
   - Recovery procedures

8. **File**: `docs/student-guide/07-backup-restore.md`
   - Azure Backup configuration
   - Creating backup
   - Restore testing

9. **File**: `docs/student-guide/08-disaster-recovery.md`
   - Azure Site Recovery setup
   - DR failover testing
   - Failback procedures

10. **File**: `docs/student-guide/09-cleanup.md`
    - Resource deletion steps
    - Cost verification

**Format**:
- Clear step numbering
- Screenshots for complex UI steps
- Code blocks with syntax highlighting
- Warning callouts for critical steps
- Success validation checkpoints

---

#### Stage 4.2: Instructor Materials ⏱️ 4-6 hours

**Artifacts to Create**:

1. **File**: `docs/instructor-guide/workshop-setup.md`
   - Pre-workshop checklist
   - Demo environment setup
   - Assistant briefing

2. **File**: `docs/instructor-guide/presentation-slides.pptx`
   - Architecture diagrams
   - Azure service explanations
   - AWS vs Azure comparisons
   - Best practices

3. **File**: `docs/instructor-guide/troubleshooting-guide.md`
   - Common student errors
   - Quick fixes
   - When to escalate

4. **File**: `docs/instructor-guide/timing-guide.md`
   - Recommended pace
   - Buffer time allocation
   - Break scheduling

---

#### Stage 4.3: Automated Testing Scripts ⏱️ 4-6 hours

**Artifacts to Create**:

1. **File**: `scripts/validate-deployment.sh`
   - Check all Azure resources deployed
   - Verify network connectivity
   - Test API endpoints
   - Validate monitoring data

```bash
#!/bin/bash
# validate-deployment.sh

echo "🔍 Validating Azure deployment..."

# Check resource group exists
if ! az group show --name $RG_NAME &>/dev/null; then
  echo "❌ Resource group $RG_NAME not found"
  exit 1
fi

# Check VMs running
VM_COUNT=$(az vm list --resource-group $RG_NAME --query "length([?powerState=='VM running'])" -o tsv)
if [ "$VM_COUNT" -ne 6 ]; then
  echo "❌ Expected 6 running VMs, found $VM_COUNT"
  exit 1
fi

# Test API endpoint
if ! curl -f http://$PUBLIC_IP/api/posts &>/dev/null; then
  echo "❌ API endpoint not responding"
  exit 1
fi

echo "✅ Deployment validation passed!"
```

2. **File**: `scripts/simulate-failures.sh`
   - Stop VMs to simulate failures
   - Verify application resilience

3. **File**: `scripts/load-test.sh`
   - Generate traffic to test load balancing
   - Verify distribution

---

#### Stage 4.4: Workshop Dry Run ⏱️ 4-8 hours

**Activities**:
1. Execute full workshop as a student would
2. Time each section
3. Identify pain points
4. Update documentation based on findings
5. Prepare contingency plans

**Validation**:
- [ ] All steps complete successfully
- [ ] Timing fits within 2-day schedule
- [ ] Documentation clear and unambiguous
- [ ] Troubleshooting guide comprehensive
- [ ] Automation works reliably

**Deliverable**: Production-ready workshop materials

---

## Recommended Execution Sequence

### Week 1: Infrastructure and Database
- Day 1-2: Stage 3.1 (Pre-Coding Validation)
- Day 3-5: Stage 3.2 (Bicep templates)
- Day 6-7: Stage 3.3 (MongoDB setup)

### Week 2: Backend Development
- Day 8-10: Stage 3.4.1-3.4.3 (Backend scaffolding, DB, auth)
- Day 11-13: Stage 3.4.4-3.4.6 (API routes, error handling, deployment)
- Day 14: Buffer/catch-up

### Week 3: Frontend Development
- Day 15-17: Stage 3.5.1-3.5.3 (Frontend scaffolding, MSAL, API client)
- Day 18-20: Stage 3.5.4-3.5.6 (UI components, routing, deployment)
- Day 21: Buffer/catch-up

### Week 4: Integration and Workshop Prep
- Day 22-23: Stage 3.6 (Integration testing)
- Day 24-26: Stage 4.1 (Student documentation)
- Day 27: Stage 4.2 (Instructor materials)
- Day 28: Stage 4.4 (Dry run and refinement)

**Total Estimated Time**: 90-120 hours (4-6 weeks at 20-30 hours/week)

---

## Critical Success Factors

### Technical Excellence
1. **Follow Design Documents Religiously**: Your design docs are excellent - don't deviate
2. **Security First**: Never compromise on RepositoryWideDesignRules.md security patterns
3. **Code Quality**: Google TypeScript Style Guide is non-negotiable
4. **Test Continuously**: Don't wait until the end to test

### Educational Value
1. **AWS Comparisons**: Always relate Azure concepts to AWS equivalents
2. **Explain the Why**: Don't just tell students what to do, explain rationale
3. **Failure Scenarios**: Make failure testing educational, not frustrating
4. **Clear Documentation**: Assume students have never used Azure Portal

### Operational Excellence
1. **Automation**: Students should focus on learning, not manual toil
2. **Reliable Timing**: Workshop must fit in 2 days, test this thoroughly
3. **Cost Control**: Provide clear cost estimates and cleanup procedures
4. **Scalability**: Materials must work for 20-30 concurrent students

---

## Risk Mitigation

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Bicep deployment fails | High | Test templates extensively; provide Portal fallback |
| MongoDB replica set won't initialize | High | Automated scripts + detailed troubleshooting guide |
| MSAL authentication issues | Medium | Provide pre-configured Entra ID app registrations |
| GitHub Actions timeouts | Medium | Keep builds under 10 minutes; provide manual deploy fallback |
| Azure quota limits | High | Pre-request quota increase; stagger student deployments |

### Educational Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Students fall behind | High | Provide pre-deployed checkpoints; assistants monitor progress |
| Network/proxy issues | Medium | Test environment requirements beforehand; provide workarounds |
| Insufficient Azure permissions | High | Validate subscription permissions in prerequisites |
| Confusion due to AWS habits | Medium | Explicit AWS vs Azure comparisons throughout |

---

## Next Steps (Immediate Actions)

### Phase 3.1: Pre-Coding Validation (Start Now)

1. **Read Design Documents End-to-End** ⏱️ 2-3 hours
   - Validate completeness
   - Note any ambiguities
   - Create clarification list

2. **Set Up Development Environment** ⏱️ 1-2 hours
   ```bash
   # Install tools
   brew install azure-cli node@20
   az bicep install
   
   # Clone and set up workspace
   cd /Users/hironariy/dev/AzureIaaSWorkshop
   code .
   
   # Verify versions
   node --version  # Should be v20.x
   az --version
   az bicep version
   ```

3. **Create Initial Project Structure** ⏱️ 30 minutes
   ```bash
   # Backend
   mkdir -p materials/backend/{src,tests,scripts}
   mkdir -p materials/backend/src/{config,middleware,models,routes,controllers,validators,utils}
   
   # Frontend
   mkdir -p materials/frontend/{src,public}
   mkdir -p materials/frontend/src/{components,pages,hooks,services,contexts,types}
   
   # Bicep
   mkdir -p materials/bicep/{modules,scripts}
   mkdir -p materials/bicep/modules/{network,compute,storage,monitoring,security}
   
   # Docs
   mkdir -p docs/{student-guide,instructor-guide}
   
   # Scripts
   mkdir -p scripts
   ```

4. **Initialize Git** ⏱️ 15 minutes
   ```bash
   # Create comprehensive .gitignore
   cat > .gitignore << 'EOF'
   # Node
   node_modules/
   npm-debug.log
   yarn-error.log
   .env
   .env.local
   dist/
   build/
   
   # IDE
   .vscode/
   .idea/
   
   # OS
   .DS_Store
   Thumbs.db
   
   # Logs
   *.log
   logs/
   
   # Azure
   .azure/
   
   # Bicep
   *.bicep.json
   EOF
   
   git add .gitignore
   git commit -m "chore: add comprehensive .gitignore"
   ```

5. **Start with Bicep** (Stage 3.2.1)
   - Begin with `modules/network/vnet.bicep`
   - This unblocks everything else

---

## Appendix: Tool and Resource Links

### Development Tools
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install)
- [Node.js 20 LTS](https://nodejs.org/)
- [VS Code](https://code.visualstudio.com/)
- [MongoDB Compass](https://www.mongodb.com/products/compass)

### VS Code Extensions
- Azure Bicep (ms-azuretools.vscode-bicep)
- ESLint (dbaeumer.vscode-eslint)
- Prettier (esbenp.prettier-vscode)
- MongoDB for VS Code (mongodb.mongodb-vscode)

### Documentation
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- [Express.js Best Practices](https://expressjs.com/en/advanced/best-practice-performance.html)
- [React Best Practices](https://react.dev/learn)
- [MongoDB Best Practices](https://www.mongodb.com/docs/manual/administration/production-notes/)

---

## Summary

You are at a **critical transition point**: excellent designs complete, ready to code. Your proposed steps are correct in principle but need the structure and detail provided in this strategy.

**Key Takeaways**:
1. ✅ Your Phase 1-2 work is excellent and complete
2. ⚠️ Don't jump straight to coding - validate designs first (Stage 3.1)
3. 🎯 Build infrastructure FIRST (Bicep) - everything depends on it
4. 🔄 Iterate in small cycles - build, test, refine
5. 📚 Develop student docs in parallel with code
6. 🧪 Test continuously - don't wait until the end
7. ⏱️ Realistic timeline: 4-6 weeks for quality execution

**Immediate Next Action**: Execute Stage 3.1 (Pre-Coding Validation) - I can help you with this right now if you'd like to proceed.

Would you like me to:
1. Help you start Stage 3.1 (design validation)?
2. Create the initial project structure?
3. Begin writing the first Bicep module (`vnet.bicep`)?
4. Generate a more detailed project schedule with milestones?
