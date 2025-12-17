# Local Development Environment Setup

Complete guide to run the Azure IaaS Workshop Blog Application locally.

## Prerequisites

- **Node.js** 20.x LTS
- **Docker Desktop** for Mac (includes Docker Compose)
- **Microsoft Entra ID** app registrations (2 required - see below)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Local Development                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Browser ──► Frontend (Vite :5173) ──► Backend (Express :3000)  │
│                     │                          │                 │
│                     │                          │                 │
│                     ▼                          ▼                 │
│             Microsoft Entra ID         MongoDB (Docker :27017)   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Microsoft Entra ID Setup

You need **two app registrations** in Azure Portal:

### 1.1 Create Frontend App Registration

1. Go to Azure Portal → Microsoft Entra ID → App registrations → New registration
2. Configure:
   - **Name**: \`BlogApp Frontend (Dev)\`
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: Select **Single-page application (SPA)** from dropdown → Enter \`http://localhost:5173\`
   
   > ⚠️ **CRITICAL**: You MUST select "Single-page application (SPA)" - NOT "Web". MSAL.js uses PKCE flow which only works with SPA platform type. If you select "Web", you will get error: `AADSTS9002326: Cross-origin token redemption is permitted only for the 'Single-Page Application' client-type.`

3. After creation, note the **Application (client) ID** → This is \`VITE_ENTRA_CLIENT_ID\`
4. Note the **Directory (tenant) ID** → This is \`VITE_ENTRA_TENANT_ID\`

### 1.1.1 Add Production Redirect URI (After Azure Deployment)

After deploying to Azure, add the production redirect URI:

1. Go to Frontend App → **Authentication**
2. Under "Single-page application" section, click **Add URI**
3. Add your production URLs:
   - \`https://<YOUR_PUBLIC_IP>\`
   - \`https://<YOUR_PUBLIC_IP>/\`
4. Click **Save**

**Or use Azure CLI with Graph API:**
```bash
# Get your public IP first
PUBLIC_IP=$(az network public-ip show -g <RESOURCE_GROUP> -n pip-lb-external-prod --query ipAddress -o tsv)

# Update SPA redirect URIs (requires Graph API - az ad app update doesn't support SPA)
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='<YOUR_FRONTEND_CLIENT_ID>')" \
  --headers "Content-Type=application/json" \
  --body "{
    \"spa\": {
      \"redirectUris\": [
        \"https://${PUBLIC_IP}\",
        \"https://${PUBLIC_IP}/\",
        \"http://localhost:5173\",
        \"http://localhost:5173/\"
      ]
    }
  }"
```

### 1.2 Create Backend API App Registration

1. Create another app registration:
   - **Name**: \`BlogApp API (Dev)\`
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: Leave empty (APIs don't need redirect URIs)
2. After creation, note the **Application (client) ID** → This is \`VITE_API_CLIENT_ID\` and \`ENTRA_CLIENT_ID\`

### 1.3 Expose API Scope on Backend App

1. Go to Backend App → **Expose an API**
2. Click **Add a scope**:
   - **Application ID URI**: Accept default \`api://{client-id}\` or click "Add"
   - **Scope name**: \`access_as_user\`
   - **Who can consent**: Admins and users
   - **Admin consent display name**: \`Access BlogApp API\`
   - **Admin consent description**: \`Allows the app to access BlogApp API on behalf of the signed-in user\`
3. Save the scope

### 1.4 Grant Frontend Permission to Call Backend API

1. Go to Frontend App → **API permissions**
2. Click **Add a permission** → **My APIs** → Select "BlogApp API (Dev)"
3. Check \`access_as_user\` → Add permissions
4. (Optional) Click **Grant admin consent** for your organization

---

## Step 2: Start MongoDB (Docker)

```bash
# Navigate to dev-environment folder
cd dev-environment

# Start MongoDB container
docker-compose up -d

# Verify container is running
docker-compose ps
```

**Expected output:**
```bash
NAME                   STATUS          PORTS
blogapp-mongo-primary  running         0.0.0.0:27017->27017/tcp
```

### Initialize Replica Set (First Time Only)

```bash
# Wait for MongoDB to be ready
sleep 5

# Initialize replica set
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

### Verify MongoDB Connection

```bash
# Test connection
docker exec -it blogapp-mongo-primary mongosh --eval "db.adminCommand('ping')"
```

### Seed Sample Data (Optional)

After the backend is configured (Step 3), you can populate the database with sample data:

```bash
cd materials/backend

# Run seed script
npm run seed
```

**What the seed script creates:**
- 3 sample users (Alice, Bob, Carol)
- 5 sample blog posts with Azure-related content
- Sample comments on posts

**Note**: The seed script uses sample OIDs (not real Entra ID users). These posts will be read-only unless you modify the seed data to use your actual Entra ID OID.

**To find your OID**: After logging in, check the backend logs or use Azure Portal → Entra ID → Users → Your user → Object ID.

---

## Step 3: Configure Backend

### 3.1 Create Environment File

```bash
cd materials/backend

# Copy example config
cp .env.example .env
```

### 3.2 Edit \`.env\` with Your Values

```bash
# materials/backend/.env

NODE_ENV=development
PORT=3000

# MongoDB (local Docker)
MONGODB_URI=mongodb://localhost:27017/blogapp?replicaSet=blogapp-rs0

# Microsoft Entra ID - Use your Backend API app registration
ENTRA_TENANT_ID=your-tenant-id-here
ENTRA_CLIENT_ID=your-backend-api-client-id-here

# Logging
LOG_LEVEL=debug

# CORS
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

### 3.3 Install Dependencies and Start

```bash
# Install packages
npm install

# Start development server (with hot reload)
npm run dev
```

**Expected output:**
```
[INFO] Server running on port 3000
[INFO] MongoDB connected successfully
[INFO] Environment: development
```

### 3.4 Verify Backend Health

```bash
# In another terminal
curl http://localhost:3000/health
```

**Expected response:**
```json
{"status":"healthy","timestamp":"...","environment":"development"}
```

---

## Step 4: Configure Frontend

### 4.1 Create Environment File

```bash
cd materials/frontend

# Copy example config
cp .env.example .env
```

### 4.2 Edit \`.env\` with Your Values

```bash
# materials/frontend/.env

# Frontend App Registration (for MSAL login)
VITE_ENTRA_CLIENT_ID=your-frontend-client-id-here
VITE_ENTRA_TENANT_ID=your-tenant-id-here
VITE_ENTRA_REDIRECT_URI=http://localhost:5173

# Backend API App Registration (for API token audience)
VITE_API_CLIENT_ID=your-backend-api-client-id-here
```

### 4.3 Install Dependencies and Start

```bash
# Install packages
npm install

# Start development server (with hot reload)
npm run dev
```

**Expected output:**
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

---

## Step 5: Test the Application

### 5.1 Open Browser

Navigate to: **http://localhost:5173**

### 5.2 Test Public Features (No Login Required)

- ✅ View home page with post list
- ✅ Click on a published post to view details

### 5.3 Test Authentication

1. Click **"Login"** button in the header
2. Sign in with your Microsoft account (must be in the Entra ID tenant)
3. Consent to permissions when prompted
4. After login, you should see your name in the header

### 5.4 Test Authenticated Features

- ✅ Click **"Create Post"** → Create a new post
- ✅ Click **"My Posts"** → View your posts (including drafts)
- ✅ Edit your posts
- ✅ Delete your posts

---

## Quick Reference Commands

### Start Everything

```bash
# Terminal 1: MongoDB
cd dev-environment && docker-compose up -d

# Terminal 2: Backend
cd materials/backend && npm run dev

# Terminal 3: Frontend
cd materials/frontend && npm run dev
```

### Stop Everything

```bash
# Stop frontend/backend: Ctrl+C in each terminal

# Stop MongoDB
cd dev-environment && docker-compose stop
```

### Reset Database

```bash
cd dev-environment
docker-compose down -v
docker-compose up -d
sleep 5
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

### Reset and Reseed Database

```bash
# Reset MongoDB
cd dev-environment
docker-compose down -v
docker-compose up -d
sleep 5
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js

# Reseed sample data
cd ../materials/backend
npm run seed
```

---

## Troubleshooting

### "AADSTS65001: User hasn't consented"

**Cause**: API permissions not granted

**Fix**:
1. Go to Azure Portal → Frontend App → API permissions
2. Verify \`access_as_user\` permission is listed
3. Click "Grant admin consent" or sign in again to consent

### "Invalid token" or "401 Unauthorized"

**Cause**: Token audience mismatch

**Check**:
- \`VITE_API_CLIENT_ID\` in frontend \`.env\` matches \`ENTRA_CLIENT_ID\` in backend \`.env\`
- Both should be the **Backend API** app registration's client ID

### MongoDB Connection Failed

```bash
# Check if container is running
docker-compose ps

# Check logs
docker-compose logs mongodb-primary

# Restart container
docker-compose restart mongodb-primary
```

### Port Already in Use

```bash
# Find process using port
lsof -i :3000  # Backend
lsof -i :5173  # Frontend
lsof -i :27017 # MongoDB

# Kill process
kill -9 <PID>
```

### CORS Errors

**Check** backend \`.env\`:
```bash
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

---

## Environment Variables Summary

| Variable | Location | Description |
|----------|----------|-------------|
| \`VITE_ENTRA_CLIENT_ID\` | Frontend \`.env\` | Frontend app registration client ID |
| \`VITE_ENTRA_TENANT_ID\` | Frontend \`.env\` | Azure Entra ID tenant ID |
| \`VITE_API_CLIENT_ID\` | Frontend \`.env\` | Backend API app registration client ID |
| \`ENTRA_TENANT_ID\` | Backend \`.env\` | Azure Entra ID tenant ID |
| \`ENTRA_CLIENT_ID\` | Backend \`.env\` | Backend API app registration client ID |
| \`MONGODB_URI\` | Backend \`.env\` | MongoDB connection string |

---

## Services Ports

| Service | Port | URL |
|---------|------|-----|
| Frontend (Vite) | 5173 | http://localhost:5173 |
| Backend (Express) | 3000 | http://localhost:3000 |
| MongoDB | 27017 | mongodb://localhost:27017 |
| Mongo Express (optional) | 8081 | http://localhost:8081 |

---

## Known Limitations (First Draft)

This is the first working draft. The following are not yet implemented:

- ❌ **MongoDB authentication disabled** (CRITICAL for production)
- ❌ Unit/Integration tests
- ❌ Input sanitization (XSS protection)
- ❌ Rate limiting enforcement
- ❌ Comments feature (backend exists, frontend not connected)
- ❌ Image upload
- ❌ Rich text editor (using plain textarea)

These will be addressed in future iterations before the workshop.

---

## Next Steps

After local development is complete:

1. Deploy to Azure VMs using Bicep templates
2. Configure Azure Load Balancer
3. Set up Azure Monitor
4. Configure production secrets in Azure Key Vault

See: \`/design/AzureArchitectureDesign.md\` for production deployment details.
