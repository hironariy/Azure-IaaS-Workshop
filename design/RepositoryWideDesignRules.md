# Repository-Wide Design Rules

**Purpose**: Establish consistent design patterns across all tiers (frontend, backend, database, infrastructure) for the Azure IaaS Workshop.

**Target Audience**: AWS-experienced engineers (3-5 years, AZ-900 to AZ-104 level) learning Azure IaaS patterns.

**Last Updated**: 2025-12-03

---

## 1. Secret Management & Credential Handling

### 1.1 Core Principles

**NEVER**:
- ❌ Hardcode credentials in source code
- ❌ Commit secrets to version control (including `.env` files)
- ❌ Log passwords, connection strings, or API keys
- ❌ Store secrets in localStorage (frontend)
- ❌ Pass secrets via URL query parameters

**ALWAYS**:
- ✅ Use Azure Key Vault for production secrets
- ✅ Use Managed Identities for Azure resource authentication
- ✅ Use GitHub Secrets for CI/CD workflows
- ✅ Sanitize logs to redact sensitive information
- ✅ Use sessionStorage for tokens (frontend)

### 1.2 Azure Key Vault Integration (Production Pattern)

**Infrastructure Setup** (Bicep):
```bicep
// Create Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-blogapp-${uniqueSuffix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true  // Use Azure RBAC, not access policies
  }
}

// Store secret
resource mongoPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mongodb-api-password'
  properties: {
    value: mongoApiPassword  // From @secure() parameter
  }
}

// Grant VM Managed Identity access
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, vmManagedIdentity.id, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6')  // Key Vault Secrets User
    principalId: vmManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

**Application Retrieval** (TypeScript/Node.js):
```typescript
import { SecretClient } from '@azure/keyvault-secrets';
import { DefaultAzureCredential } from '@azure/identity';

async function getSecret(secretName: string): Promise<string> {
  const keyVaultName = process.env.KEY_VAULT_NAME;
  if (!keyVaultName) {
    throw new Error('KEY_VAULT_NAME environment variable not set');
  }

  const credential = new DefaultAzureCredential();
  const client = new SecretClient(
    `https://${keyVaultName}.vault.azure.net`,
    credential
  );

  const secret = await client.getSecret(secretName);
  return secret.value!;
}

// Usage
const mongoPassword = await getSecret('mongodb-api-password');
const connectionString = `mongodb://blogapp_api_user:${mongoPassword}@...`;
```

### 1.3 GitHub Secrets (Workshop Pattern)

**Workshop Simplification**: Use GitHub Secrets for deployment automation

**Setup**:
```bash
# Add secret to GitHub repository
gh secret set MONGODB_API_PASSWORD --body "your-secure-password"
gh secret set ENTRA_CLIENT_SECRET --body "your-client-secret"
```

**GitHub Actions Workflow**:
```yaml
name: Deploy Backend
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy with secrets
        env:
          MONGODB_PASSWORD: ${{ secrets.MONGODB_API_PASSWORD }}
          ENTRA_SECRET: ${{ secrets.ENTRA_CLIENT_SECRET }}
        run: |
          # Create .env file on VM (never committed)
          ssh $VM_HOST "echo 'MONGODB_URI=mongodb://user:${MONGODB_PASSWORD}@...' > /opt/blogapp/.env"
```

**Important**: Add to `.gitignore`:
```gitignore
# Never commit secrets
.env
.env.local
.env.*.local
*.pem
*.key
```

### 1.4 Log Sanitization (All Tiers)

**Backend (Node.js/TypeScript)**:
```typescript
// Utility function to sanitize logs
export function sanitizeForLogging(data: any): any {
  const sensitivePatterns = [
    { pattern: /password["\s:=]+([^"\s,}]+)/gi, replacement: 'password: ***' },
    { pattern: /mongodb:\/\/[^:]+:([^@]+)@/gi, replacement: 'mongodb://***:***@' },
    { pattern: /Bearer\s+([^\s]+)/gi, replacement: 'Bearer ***' },
    { pattern: /"token":\s*"([^"]+)"/gi, replacement: '"token": "***"' },
  ];

  let sanitized = JSON.stringify(data);
  sensitivePatterns.forEach(({ pattern, replacement }) => {
    sanitized = sanitized.replace(pattern, replacement);
  });
  return JSON.parse(sanitized);
}

// Use in logger
logger.info('Database connected', sanitizeForLogging({
  connectionString: mongoUri,
  database: 'blogapp'
}));
// Output: { connectionString: 'mongodb://***:***@...', database: 'blogapp' }
```

**Frontend (React)**:
```typescript
// Never log full tokens or API responses with sensitive data
console.log('Auth token acquired');  // ✅ GOOD
console.log('Token:', accessToken);  // ❌ BAD

// Sanitize user data before logging
const sanitizedUser = {
  id: user.id,
  email: user.email.replace(/(?<=.{2}).*(?=@)/, '***')  // j***@example.com
};
console.log('User logged in:', sanitizedUser);
```

### 1.5 Environment Variables

**Structure** (`.env` template committed, actual values not):
```bash
# .env.example (committed to repo)
# Copy to .env and fill in actual values

# Azure Resources
KEY_VAULT_NAME=kv-blogapp-xxxxx
RESOURCE_GROUP=rg-blogapp-student01

# MongoDB (retrieve password from Key Vault)
MONGODB_HOST=10.0.3.4
MONGODB_PORT=27017
MONGODB_DATABASE=blogapp
MONGODB_USER=blogapp_api_user
# MONGODB_PASSWORD retrieved from Key Vault at runtime

# Entra ID Authentication
ENTRA_TENANT_ID=your-tenant-id
ENTRA_CLIENT_ID=your-client-id
# ENTRA_CLIENT_SECRET retrieved from Key Vault at runtime
```

**Loading** (TypeScript):
```typescript
import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Validate environment variables (fail fast if missing)
const envSchema = z.object({
  KEY_VAULT_NAME: z.string().min(1),
  MONGODB_HOST: z.string().ip(),
  MONGODB_PORT: z.string().regex(/^\d+$/),
  ENTRA_TENANT_ID: z.string().uuid(),
  ENTRA_CLIENT_ID: z.string().uuid(),
});

export const env = envSchema.parse(process.env);
```

---

## 2. Logging & Observability Standards

### 2.1 Structured Logging (JSON Format)

**All tiers must use structured JSON logging for Azure Monitor integration.**

**Backend (Winston)**:
```typescript
import winston from 'winston';

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'blogapp-backend',
    tier: 'app',
    environment: process.env.NODE_ENV
  },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: '/var/log/blogapp/error.log', level: 'error' }),
    new winston.transports.File({ filename: '/var/log/blogapp/combined.log' })
  ]
});

// Usage
logger.info('User created', { userId: user.id, email: user.email });
logger.error('Database connection failed', { error: err.message, stack: err.stack });
```

**Output Example**:
```json
{
  "timestamp": "2025-12-03T10:30:45.123Z",
  "level": "info",
  "message": "User created",
  "service": "blogapp-backend",
  "tier": "app",
  "environment": "production",
  "userId": "user-123",
  "email": "user@example.com"
}
```

**Azure Monitor Query** (KQL):
```kql
CustomLogs_CL
| where service_s == "blogapp-backend"
| where level_s == "error"
| project timestamp_t, message_s, error_s, stack_s
| order by timestamp_t desc
```

### 2.2 Correlation IDs (Request Tracing)

**Trace requests across tiers using correlation IDs.**

**Backend Middleware**:
```typescript
import { v4 as uuidv4 } from 'uuid';
import { Request, Response, NextFunction } from 'express';

export function correlationMiddleware(req: Request, res: Response, next: NextFunction) {
  const correlationId = req.headers['x-correlation-id'] as string || uuidv4();
  req.correlationId = correlationId;
  res.setHeader('X-Correlation-ID', correlationId);
  
  // Add to logger context
  logger.defaultMeta.correlationId = correlationId;
  
  next();
}

// Usage in route
app.get('/api/posts', (req, res) => {
  logger.info('Fetching posts', { correlationId: req.correlationId });
  // ... fetch posts
});
```

**Frontend Request**:
```typescript
import { v4 as uuidv4 } from 'uuid';

async function fetchPosts() {
  const correlationId = uuidv4();
  
  const response = await fetch('/api/posts', {
    headers: {
      'X-Correlation-ID': correlationId
    }
  });
  
  console.log('Request sent', { correlationId });
}
```

### 2.3 Log Levels & Guidelines

| Level | When to Use | Examples |
|-------|-------------|----------|
| **ERROR** | Errors requiring immediate attention | Database connection failed, unhandled exceptions |
| **WARN** | Recoverable issues or potential problems | Slow query detected, deprecated API used |
| **INFO** | Significant application events | User login, post created, deployment started |
| **DEBUG** | Detailed diagnostic information | Query parameters, function entry/exit |
| **TRACE** | Very detailed diagnostic (development only) | Variable values, loop iterations |

**Production**: `INFO` level (exclude DEBUG/TRACE)  
**Development**: `DEBUG` level  
**Troubleshooting**: `DEBUG` or `TRACE` temporarily

---

## 3. Error Handling Patterns

### 3.1 Consistent Error Responses (Backend API)

**Standard Error Format**:
```typescript
interface ApiError {
  error: {
    code: string;           // Machine-readable error code
    message: string;        // Human-readable message (student-friendly)
    details?: any;          // Additional context (optional)
    timestamp: string;      // ISO 8601 timestamp
    correlationId: string;  // Request correlation ID
  };
}
```

**Implementation**:
```typescript
export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: any
  ) {
    super(message);
    this.name = 'AppError';
  }
}

// Error handler middleware
export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
        timestamp: new Date().toISOString(),
        correlationId: req.correlationId
      }
    });
  }

  // Unknown error (don't expose internal details)
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred. Please try again later.',
      timestamp: new Date().toISOString(),
      correlationId: req.correlationId
    }
  });
}

// Usage in routes
app.post('/api/posts', async (req, res, next) => {
  try {
    const post = await createPost(req.body);
    res.status(201).json(post);
  } catch (err) {
    if (err.code === 11000) {  // MongoDB duplicate key
      next(new AppError(409, 'DUPLICATE_POST', 'A post with this title already exists'));
    } else {
      next(err);  // Pass to error handler
    }
  }
});
```

### 3.2 Student-Friendly Error Messages

**Principle**: Error messages should help students understand what went wrong and how to fix it.

**Examples**:

❌ **BAD** (Cryptic):
```typescript
throw new Error('E11000 duplicate key error collection');
```

✅ **GOOD** (Actionable):
```typescript
throw new AppError(
  409,
  'DUPLICATE_POST',
  'A post with this title already exists. Please use a different title.',
  { field: 'title', value: req.body.title }
);
```

❌ **BAD** (Too technical):
```typescript
throw new Error('MongoNetworkError: connect ECONNREFUSED 10.0.3.4:27017');
```

✅ **GOOD** (Educational):
```typescript
throw new AppError(
  503,
  'DATABASE_UNAVAILABLE',
  'Unable to connect to database. Check that MongoDB is running and network security groups allow traffic on port 27017.',
  {
    host: '10.0.3.4',
    port: 27017,
    troubleshooting: 'https://docs.mongodb.com/manual/tutorial/troubleshoot-connection/'
  }
);
```

### 3.3 Frontend Error Handling

**React Error Boundary**:
```typescript
import { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: any) {
    console.error('React error:', error, errorInfo);
    // Send to monitoring (Azure Application Insights)
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-container">
          <h1>Oops! Something went wrong</h1>
          <p>We're sorry for the inconvenience. Please refresh the page or try again later.</p>
          <details>
            <summary>Error details</summary>
            <pre>{this.state.error?.message}</pre>
          </details>
        </div>
      );
    }

    return this.props.children;
  }
}
```

**API Error Handling**:
```typescript
async function fetchPosts(): Promise<Post[]> {
  try {
    const response = await fetch('/api/posts');
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error.message || 'Failed to fetch posts');
    }
    
    return await response.json();
  } catch (err) {
    console.error('Failed to fetch posts:', err);
    // Show user-friendly error message
    throw new Error('Unable to load posts. Please check your connection and try again.');
  }
}
```

---

## 4. Resource Naming & Placeholder Conventions

### 4.1 Bicep Placeholder Patterns

**Principle**: Use placeholders for resources that must be globally unique or student-specific.

**Common Placeholders**:
```bicep
// Storage account (globally unique)
@description('Unique suffix for storage account name (6 chars, lowercase alphanumeric)')
param storageAccountSuffix string = uniqueString(resourceGroup().id)

var storageAccountName = 'stblogapp${storageAccountSuffix}'  // stblogappjh7k2m

// Key Vault (globally unique)
var keyVaultName = 'kv-blogapp-${storageAccountSuffix}'  // kv-blogapp-jh7k2m

// Resource-specific names (not globally unique)
var vmNameDb1 = 'vm-db-az1'
var vmNameDb2 = 'vm-db-az2'
```

**Output for Scripts**:
```bicep
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output dbVm1PrivateIp string = dbVm1Nic.properties.ipConfigurations[0].properties.privateIPAddress
```

### 4.2 Documentation Placeholder Format

**In design documents, use descriptive placeholders**:

```markdown
## Connection String Examples

**Format**:
```
mongodb://blogapp_api_user:<password>@<db-primary-ip>:27017,<db-secondary-ip>:27017/blogapp?replicaSet=blogapp-rs0
```

**Placeholders**:
- `<password>`: Retrieved from Azure Key Vault secret `mongodb-api-password`
- `<db-primary-ip>`: DB VM primary private IP (from Bicep output `dbVm1PrivateIp`)
- `<db-secondary-ip>`: DB VM secondary private IP (from Bicep output `dbVm2PrivateIp`)

**Example** (actual deployment):
```bash
# Retrieve values from Bicep deployment
DB_PRIMARY_IP=$(az deployment group show \
  --resource-group rg-blogapp-student01 \
  --name main-deployment \
  --query properties.outputs.dbVm1PrivateIp.value -o tsv)

DB_PASSWORD=$(az keyvault secret show \
  --vault-name kv-blogapp-jh7k2m \
  --name mongodb-api-password \
  --query value -o tsv)

# Construct connection string
export MONGODB_URI="mongodb://blogapp_api_user:${DB_PASSWORD}@${DB_PRIMARY_IP}:27017,${DB_SECONDARY_IP}:27017/blogapp?replicaSet=blogapp-rs0"
```
```

---

## 5. Network Security Patterns

### 5.1 Network Segmentation

**Principle**: Isolate tiers using subnets and Network Security Groups (NSGs).

**Subnet Design**:
```bicep
var subnets = [
  {
    name: 'snet-web'
    addressPrefix: '10.0.1.0/24'
    tier: 'web'
  }
  {
    name: 'snet-app'
    addressPrefix: '10.0.2.0/24'
    tier: 'app'
  }
  {
    name: 'snet-db'
    addressPrefix: '10.0.3.0/24'
    tier: 'db'
  }
]
```

**NSG Rule Pattern** (Least Privilege):
```bicep
// Allow app tier -> db tier (MongoDB)
resource nsgRuleAppToDb 'Microsoft.Network/networkSecurityGroups/securityRules@2023-05-01' = {
  parent: nsgDb
  name: 'Allow-App-MongoDB'
  properties: {
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceAddressPrefix: '10.0.2.0/24'  // App subnet
    sourcePortRange: '*'
    destinationAddressPrefix: '10.0.3.0/24'  // DB subnet
    destinationPortRange: '27017'
    description: 'Allow backend API to connect to MongoDB'
  }
}

// Deny all other inbound traffic (default deny)
resource nsgRuleDenyAll 'Microsoft.Network/networkSecurityGroups/securityRules@2023-05-01' = {
  parent: nsgDb
  name: 'Deny-All-Inbound'
  properties: {
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
    description: 'Default deny all inbound traffic'
  }
}
```

### 5.2 Managed Identities (No Passwords)

**Principle**: Use Managed Identities for Azure resource authentication.

**System-Assigned Managed Identity** (Bicep):
```bicep
resource vmApp 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-app-az1'
  location: location
  identity: {
    type: 'SystemAssigned'  // Enables Managed Identity
  }
  properties: {
    // ... VM configuration
  }
}

// Grant Key Vault access
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, vmApp.id, 'Key Vault Secrets User')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: vmApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

**Application Usage** (TypeScript):
```typescript
import { DefaultAzureCredential } from '@azure/identity';

// DefaultAzureCredential automatically uses Managed Identity on Azure VMs
const credential = new DefaultAzureCredential();

// No client secrets needed!
const client = new SecretClient('https://kv-blogapp.vault.azure.net', credential);
```

---

## 6. Monitoring & Health Checks

### 6.1 Health Check Endpoints (All Tiers)

**Backend Health Check**:
```typescript
import express from 'express';
import mongoose from 'mongoose';

const app = express();

// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    checks: {
      database: 'unknown',
      memory: process.memoryUsage(),
      uptime: process.uptime()
    }
  };

  try {
    // Check MongoDB connection
    if (mongoose.connection.readyState === 1) {
      health.checks.database = 'healthy';
    } else {
      health.status = 'degraded';
      health.checks.database = 'unhealthy';
    }
  } catch (err) {
    health.status = 'unhealthy';
    health.checks.database = 'error';
  }

  const statusCode = health.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});

// Liveness probe (always returns 200 if process is running)
app.get('/health/live', (req, res) => {
  res.status(200).json({ status: 'alive' });
});

// Readiness probe (returns 200 only if ready to serve traffic)
app.get('/health/ready', async (req, res) => {
  if (mongoose.connection.readyState === 1) {
    res.status(200).json({ status: 'ready' });
  } else {
    res.status(503).json({ status: 'not_ready' });
  }
});
```

**Load Balancer Health Probe** (Bicep):
```bicep
resource loadBalancerProbe 'Microsoft.Network/loadBalancers/probes@2023-05-01' = {
  parent: loadBalancer
  name: 'health-probe'
  properties: {
    protocol: 'Http'
    port: 3000
    requestPath: '/health/ready'
    intervalInSeconds: 15
    numberOfProbes: 2  // Mark unhealthy after 2 failures (30 seconds)
  }
}
```

### 6.2 Azure Monitor Integration

**Application Insights** (Backend):
```typescript
import { TelemetryClient } from 'applicationinsights';

const appInsights = new TelemetryClient(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING);

// Track custom metrics
appInsights.trackMetric({
  name: 'MongoDB_Connections',
  value: mongoose.connection.db?.stats().connections || 0
});

// Track dependencies
appInsights.trackDependency({
  target: 'MongoDB',
  name: 'findPosts',
  data: 'db.posts.find()',
  duration: 45,  // milliseconds
  resultCode: 0,
  success: true
});

// Track custom events
appInsights.trackEvent({
  name: 'PostCreated',
  properties: { userId: user.id, postId: post.id }
});
```

---

## 7. High Availability Patterns

### 7.1 Availability Zone Distribution

**Principle**: Distribute VMs across at least 2 Availability Zones.

**Bicep Pattern**:
```bicep
resource vmDb1 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-db-az1'
  location: location
  zones: ['1']  // Availability Zone 1
  properties: {
    // ... configuration
  }
}

resource vmDb2 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-db-az2'
  location: location
  zones: ['2']  // Availability Zone 2
  properties: {
    // ... configuration
  }
}
```

**Educational Note**: 
- 1 zone: No HA (single point of failure)
- 2 zones: Basic HA (survives 1 zone failure)
- 3 zones: Production HA (survives 1 zone failure with quorum)

### 7.2 Load Balancer Health Probes

**Principle**: Remove unhealthy VMs from load balancer pool automatically.

```bicep
resource lbRule 'Microsoft.Network/loadBalancers/loadBalancingRules@2023-05-01' = {
  parent: loadBalancer
  name: 'http-rule'
  properties: {
    frontendIPConfiguration: {
      id: loadBalancer.properties.frontendIPConfigurations[0].id
    }
    backendAddressPool: {
      id: loadBalancer.properties.backendAddressPools[0].id
    }
    probe: {
      id: healthProbe.id  // Reference health probe
    }
    protocol: 'Tcp'
    frontendPort: 80
    backendPort: 3000
    enableFloatingIP: false
    idleTimeoutInMinutes: 4
    loadDistribution: 'Default'
  }
}
```

---

## 8. Disaster Recovery Standards

### 8.1 Backup Retention Policies

**Principle**: Define retention based on recovery objectives.

**Workshop Standard**:

| Backup Type | Retention | Use Case | Cost (per VM) |
|-------------|-----------|----------|---------------|
| **Azure Backup** | 7d + 4w + 3m | VM-level DR | ~$30/month |
| **Application Backup** | 7 days | Quick recovery | ~$1/month |

**Bicep Configuration**:
```bicep
resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-01-01' = {
  parent: recoveryServicesVault
  name: 'daily-backup-policy'
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: ['2025-01-01T02:00:00Z']  // 2 AM UTC
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: ['2025-01-01T02:00:00Z']
        retentionDuration: {
          count: 7
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: ['Sunday']
        retentionTimes: ['2025-01-01T02:00:00Z']
        retentionDuration: {
          count: 4
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: ['Sunday']
          weeksOfTheMonth: ['First']
        }
        retentionTimes: ['2025-01-01T02:00:00Z']
        retentionDuration: {
          count: 3
          durationType: 'Months'
        }
      }
    }
  }
}
```

### 8.2 Recovery Objectives

**Define RTO/RPO for each tier**:

| Tier | RTO (Recovery Time) | RPO (Data Loss) | Strategy |
|------|---------------------|-----------------|----------|
| **Web** | < 1 hour | N/A (stateless) | Redeploy from source |
| **App** | < 1 hour | N/A (stateless) | Redeploy from source |
| **DB** | < 4 hours | < 1 hour | Azure Backup + MongoDB backups |

---

## Compliance Checklist

Use this checklist when reviewing design documents or implementing code:

### Secret Management
- [ ] No hardcoded credentials in source code
- [ ] `.env` files in `.gitignore`
- [ ] Secrets stored in Azure Key Vault or GitHub Secrets
- [ ] Managed Identities used for Azure resource access
- [ ] Logs sanitized to redact sensitive information

### Logging & Observability
- [ ] Structured JSON logging implemented
- [ ] Correlation IDs used for request tracing
- [ ] Appropriate log levels used
- [ ] Azure Monitor integration configured

### Error Handling
- [ ] Consistent API error format used
- [ ] Student-friendly error messages provided
- [ ] Error boundary implemented (frontend)
- [ ] Unhandled errors logged without exposing internals

### Resource Naming
- [ ] Placeholders documented for globally unique resources
- [ ] Bicep outputs provided for runtime values
- [ ] Naming conventions followed (see AzureArchitectureDesign.md)

### Network Security
- [ ] Network segmentation with NSGs implemented
- [ ] Least privilege access rules configured
- [ ] Managed Identities used instead of passwords

### Monitoring
- [ ] Health check endpoints implemented
- [ ] Load balancer health probes configured
- [ ] Application Insights integrated

### High Availability
- [ ] VMs distributed across 2+ Availability Zones
- [ ] Load balancer configured with health probes
- [ ] Stateless tiers designed for horizontal scaling

### Disaster Recovery
- [ ] Backup policies defined with retention
- [ ] RTO/RPO objectives documented
- [ ] DR testing procedures documented

---

## Educational Notes for Students

### Why These Rules Matter

**Secret Management**:
- Real-world scenario: Hardcoded password in GitHub → credential leak → database breach
- Azure solution: Key Vault + Managed Identity = zero secrets in code

**Structured Logging**:
- AWS equivalent: CloudWatch Logs with JSON format
- Azure advantage: Native integration with Log Analytics (KQL queries)

**Managed Identities**:
- AWS equivalent: IAM roles for EC2
- Azure advantage: Same concept, different implementation

**Availability Zones**:
- AWS equivalent: Multi-AZ deployments
- Azure difference: Zone selection explicit in VM configuration

---

## Versioning

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-03 | Initial repository-wide design rules |

---

**Next Steps**:
1. Review this document before creating any new design specifications
2. Update tier-specific design documents to reference these rules
3. Validate existing code against compliance checklist
4. Incorporate rules into code review process
