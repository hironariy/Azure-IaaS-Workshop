# Environment-Aware Backend Configuration Strategy

**Date**: 2025-12-16  
**Status**: Approved (Option A selected)  
**Author**: GitHub Copilot (based on user requirements)  
**Decision**: Option A - Bicep Injects Full Connection String (approved 2025-12-17)

## Problem Statement

The backend application needs to automatically recognize whether it's running in:
- **Local Development**: Docker Compose MongoDB (no auth, localhost)
- **Azure Production**: MongoDB Replica Set on VMs (with auth, private IPs)

Currently, developers must manually edit `.env` files when switching environments, which is error-prone and violates 12-factor app principles.

## Requirements

1. **Zero manual file editing** when deploying to different environments
2. **Same codebase** works in both dev and prod
3. **Credentials only in production** - local dev uses no-auth for simplicity
4. **Workshop clarity** - students understand the environment switching mechanism

## Proposed Strategy

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Application                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Environment Detection Logic                             │   │
│  │  ┌─────────────────┐    ┌─────────────────────────────┐ │   │
│  │  │ Check NODE_ENV  │───►│ Select Connection String    │ │   │
│  │  └─────────────────┘    └─────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐      ┌─────────────────────────────┐
│  Local Development  │      │     Azure Production        │
│  NODE_ENV=development│      │     NODE_ENV=production     │
│  .env file          │      │     System env vars (Bicep) │
│  No auth MongoDB    │      │     Authenticated MongoDB   │
└─────────────────────┘      └─────────────────────────────┘
```

### Option A: Bicep Injects Full Connection String (Recommended)

**Simplest approach** - Bicep sets all required environment variables on App VMs.

#### 1. Bicep Configuration (app-tier.bicep)

```bicep
// In CustomScript or cloud-init, set system-wide environment variables
var appEnvironmentVars = '''
# /etc/environment.d/blogapp.conf
NODE_ENV=production
MONGODB_URI=mongodb://blogapp:BlogAppUser2024@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=blogapp
PORT=3000
LOG_LEVEL=info
'''
```

#### 2. Backend .env.example

```bash
# =============================================================================
# Backend Environment Configuration
# =============================================================================
# LOCAL DEVELOPMENT: Copy to .env (these values work out of the box)
# AZURE PRODUCTION: Bicep sets these as system environment variables
# =============================================================================

NODE_ENV=development
PORT=3000
LOG_LEVEL=debug

# MongoDB - Local development (Docker Compose, no auth)
MONGODB_URI=mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0

# Note: In Azure production, Bicep overrides MONGODB_URI with authenticated connection
```

#### 3. Backend Code (config/environment.ts)

```typescript
// No special logic needed - just read environment variables
// System env vars (from Bicep) override .env file
export const config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  mongodbUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/blogapp',
  logLevel: process.env.LOG_LEVEL || 'debug',
};
```

**Pros:**
- Simplest implementation
- Standard Node.js behavior (system env overrides .env)
- No special environment detection code
- Secure - credentials only exist on production VMs

**Cons:**
- Connection strings in Bicep (though can use Key Vault reference)

---

### Option B: Dual Connection Strings in .env (Workshop-Friendly)

**More explicit** - Shows both connection patterns in the same file for educational purposes.

#### 1. Backend .env.example

```bash
# =============================================================================
# Backend Environment Configuration
# =============================================================================
# This file supports both local development and Azure production
# The application automatically selects the correct MongoDB URI based on NODE_ENV
# =============================================================================

# Environment Detection
# - Local: NODE_ENV=development (from .env)
# - Azure: NODE_ENV=production (from Bicep system environment)
NODE_ENV=development

PORT=3000
LOG_LEVEL=debug

# =============================================================================
# MongoDB Connection Strings
# =============================================================================
# Both are defined, but only one is used based on NODE_ENV

# Development: Docker Compose replica set (no authentication)
MONGODB_URI_DEV=mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0

# Production: Azure VMs with authentication
# Credentials: blogapp / BlogAppUser2024 (see /design/DatabaseDesign.md)
MONGODB_URI_PROD=mongodb://blogapp:BlogAppUser2024@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=blogapp

# =============================================================================
# Microsoft Entra ID Configuration
# =============================================================================
ENTRA_TENANT_ID=your-tenant-id
ENTRA_CLIENT_ID=your-client-id

# =============================================================================
# CORS Configuration
# =============================================================================
# Development: Local Vite dev server
CORS_ORIGINS_DEV=http://localhost:5173,http://localhost:3000

# Production: Azure Load Balancer public IP or custom domain
CORS_ORIGINS_PROD=http://your-lb-ip,https://your-domain.com
```

#### 2. Bicep Configuration (app-tier.bicep)

```bicep
// Set NODE_ENV=production via cloud-init or CustomScript
var cloudInitConfig = '''
#cloud-config
write_files:
  - path: /etc/environment.d/blogapp.conf
    content: |
      NODE_ENV=production
    owner: root:root
    permissions: '0644'
'''
```

#### 3. Backend Code (config/environment.ts)

```typescript
import dotenv from 'dotenv';

// Load .env file (development) - system env vars take precedence
dotenv.config();

/**
 * Environment-aware configuration
 * 
 * Detection Logic:
 * 1. Check NODE_ENV (system env from Bicep overrides .env)
 * 2. Select appropriate MongoDB URI based on environment
 * 3. Select appropriate CORS origins based on environment
 */
const isProduction = process.env.NODE_ENV === 'production';

export const config = {
  // Core settings
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction,
  port: parseInt(process.env.PORT || '3000', 10),
  
  // MongoDB - auto-select based on environment
  mongodbUri: isProduction
    ? process.env.MONGODB_URI_PROD || process.env.MONGODB_URI
    : process.env.MONGODB_URI_DEV || process.env.MONGODB_URI || 'mongodb://localhost:27017/blogapp',
  
  // CORS - auto-select based on environment
  corsOrigins: (isProduction
    ? process.env.CORS_ORIGINS_PROD
    : process.env.CORS_ORIGINS_DEV
  )?.split(',') || ['http://localhost:5173'],
  
  // Logging - more verbose in development
  logLevel: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
  
  // Auth
  entraTenantId: process.env.ENTRA_TENANT_ID,
  entraClientId: process.env.ENTRA_CLIENT_ID,
};

// Validate required config in production
if (isProduction) {
  const required = ['mongodbUri', 'entraTenantId', 'entraClientId'];
  for (const key of required) {
    if (!config[key as keyof typeof config]) {
      throw new Error(`Missing required production config: ${key}`);
    }
  }
}

// Log sanitized config at startup (see RepositoryWideDesignRules.md §1.4)
console.log('Environment:', config.nodeEnv);
console.log('MongoDB URI:', config.mongodbUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@'));
```

**Pros:**
- Educational - students see both connection patterns
- Self-documenting .env file
- Explicit environment detection logic
- No secrets needed in Bicep (just NODE_ENV)

**Cons:**
- More complex code
- Production credentials in .env.example (as example only)

---

## Recommended Implementation: Hybrid Approach

Combine the best of both options:

### 1. Use Bicep to Set NODE_ENV Only

```bicep
// app-tier.bicep - Only set NODE_ENV, not credentials
var cloudInitScript = '''
#!/bin/bash
echo 'NODE_ENV=production' >> /etc/environment
'''
```

### 2. Use GitHub Secrets for Production Connection String

```yaml
# .github/workflows/deploy-backend.yml
- name: Deploy to App VM
  env:
    MONGODB_URI: ${{ secrets.MONGODB_URI_PROD }}
```

### 3. Backend Code with Fallback Logic

```typescript
// config/environment.ts
const isProduction = process.env.NODE_ENV === 'production';

export const config = {
  mongodbUri: process.env.MONGODB_URI  // Single key, value differs by deployment
    || (isProduction 
        ? 'mongodb://blogapp:***@10.0.3.4:27017,...'  // Should never reach here
        : 'mongodb://localhost:27017/blogapp'),
};
```

---

## Implementation Checklist

### Bicep Changes (app-tier.bicep)

- [ ] Add cloud-init to set `NODE_ENV=production`
- [ ] Optionally set `MONGODB_URI` (or use GitHub Secrets)

### Backend Changes

- [ ] Update `config/environment.ts` with environment detection
- [ ] Update `.env.example` with dual connection strings
- [ ] Add startup validation for production config
- [ ] Update connection logging to sanitize credentials

### Documentation Changes

- [ ] Update `DatabaseDesign.md` connection string section
- [ ] Update `BackendApplicationDesign.md` configuration section
- [ ] Add environment setup instructions to backend README

---

## Security Considerations

1. **Never commit `.env` with real credentials** - .gitignore must include `.env`
2. **Production credentials** should come from:
   - Azure Key Vault (ideal)
   - GitHub Secrets (acceptable for workshop)
   - Bicep parameters with `@secure()` decorator
3. **Log sanitization** - Always mask credentials in logs (see RepositoryWideDesignRules.md §1.4)

---

## AWS Comparison (for Workshop Context)

| Aspect | AWS | Azure (This Workshop) |
|--------|-----|----------------------|
| Environment Detection | EC2 Instance Tags, SSM Parameter Store | NODE_ENV via cloud-init |
| Secrets | AWS Secrets Manager | Azure Key Vault |
| Config Injection | EC2 User Data, ECS Task Definition | Bicep CustomScript, cloud-init |
| Best Practice | Environment variables, not config files | Same |

---

## Decision

**Recommended**: Option A (Bicep Injects Full Connection String) with GitHub Secrets for the actual credential values.

**Rationale**:
- Simplest implementation
- Follows 12-factor app principles
- Secure credential management
- Workshop students understand the pattern

**Alternative**: Option B if workshop curriculum emphasizes environment detection patterns.
