# Azure IaaS Workshop - Multi-User Blog Application

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A hands-on workshop for learning Azure IaaS patterns through building and deploying a resilient multi-tier web application.

---

## Table of Contents

- [1. Introduction](#1-introduction)
  - [1.1 About This Workshop](#11-about-this-workshop)
  - [1.2 What You Will Learn](#12-what-you-will-learn)
  - [1.3 Application Overview](#13-application-overview)
  - [1.4 Architecture Overview](#14-architecture-overview)
- [2. How to Deploy](#2-how-to-deploy)
  - [2.1 Prerequisites](#21-prerequisites)
  - [2.2 Local Development Environment](#22-local-development-environment)
  - [2.3 Azure Deployment](#23-azure-deployment)
- [3. Resiliency Testing](#3-resiliency-testing)

---

## 1. Introduction

### 1.1 About This Workshop

This workshop is designed for engineers who want to learn **Azure Infrastructure as a Service (IaaS)** patterns by building a real-world, production-ready web application. 

**Target Audience:**
- Engineers with 3-5 years of experience (particularly those familiar with AWS)
- Developers preparing for Azure certifications (AZ-104, AZ-305)
- Teams migrating from AWS to Azure

**Workshop Duration:** 2 days (approximately 16 hours)

### 1.2 What You Will Learn

By completing this workshop, you will gain hands-on experience with:

| Topic | Azure Services |
|-------|----------------|
| **High Availability** | Availability Zones, Load Balancers, Application Gateway |
| **Networking** | Virtual Networks, Subnets, NSGs, NAT Gateway, Bastion |
| **Compute** | Virtual Machines, VM Scale concepts |
| **Security** | Microsoft Entra ID, Managed Identities, Key Vault |
| **Infrastructure as Code** | Bicep templates, ARM deployment |
| **Monitoring** | Azure Monitor, Log Analytics (planned) |
| **Disaster Recovery** | Azure Site Recovery concepts (planned) |

### 1.3 Application Overview

The sample application is a **multi-user blog platform** with the following features:

**For All Users (Public):**
- 📖 Browse and read published blog posts
- 🔍 View post details with author information

**For Authenticated Users:**
- ✍️ Create, edit, and delete your own blog posts
- 📝 Save posts as drafts before publishing
- 👤 Manage your profile and view your posts

**Technology Stack:**

| Layer | Technology |
|-------|------------|
| Frontend | React 18, TypeScript, TailwindCSS, Vite |
| Backend | Node.js 20, Express.js, TypeScript |
| Database | MongoDB 7.0 with Replica Set |
| Authentication | Microsoft Entra ID (Azure AD) with MSAL.js |

### 1.4 Architecture Overview

#### Local Development Architecture

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

#### Azure Production Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              Azure Architecture                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   Internet                                                                    │
│      │                                                                        │
│      ▼                                                                        │
│   ┌─────────────────────────────────┐                                        │
│   │   Application Gateway (HTTPS)   │  ◄── SSL/TLS Termination              │
│   │   - Public IP with DNS label    │      Self-signed certificate          │
│   │   - HTTP→HTTPS redirect         │                                        │
│   └─────────────────────────────────┘                                        │
│                  │                                                            │
│                  ▼                                                            │
│   ┌─────────────────────────────────┐     ┌────────────────┐                │
│   │        Web Tier (NGINX)         │     │  Azure Bastion │                │
│   │   VM-AZ1        VM-AZ2          │     │  (Secure SSH)  │                │
│   │   10.0.1.4      10.0.1.5        │     └────────────────┘                │
│   └─────────────────────────────────┘                                        │
│                  │                                                            │
│                  ▼                                                            │
│   ┌─────────────────────────────────┐                                        │
│   │   Internal Load Balancer (:3000)│                                        │
│   └─────────────────────────────────┘                                        │
│                  │                                                            │
│                  ▼                                                            │
│   ┌─────────────────────────────────┐                                        │
│   │       App Tier (Node.js)        │                                        │
│   │   VM-AZ1        VM-AZ2          │                                        │
│   │   10.0.2.5      10.0.2.4        │                                        │
│   └─────────────────────────────────┘                                        │
│                  │                                                            │
│                  ▼                                                            │
│   ┌─────────────────────────────────┐                                        │
│   │     Database Tier (MongoDB)     │                                        │
│   │   Primary       Secondary       │  ◄── Replica Set                      │
│   │   10.0.3.4      10.0.3.5        │      (Auto-failover)                  │
│   └─────────────────────────────────┘                                        │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Key Azure Services Used:**

| Service | Purpose |
|---------|---------|
| **Virtual Machines** | Compute for all three tiers |
| **Application Gateway** | Layer 7 load balancer with SSL termination |
| **Standard Load Balancer** | Internal load balancing for App tier |
| **Virtual Network** | Network isolation with 4 subnets |
| **NAT Gateway** | Outbound internet for private VMs |
| **Azure Bastion** | Secure SSH access without public IPs |
| **Network Security Groups** | Firewall rules for each tier |
| **Availability Zones** | High availability across data centers |

---

## 2. How to Deploy

This section explains how to deploy the application. Choose the environment that fits your needs:

| Environment | Use Case | Time Required |
|-------------|----------|---------------|
| **Local Development** | Code changes, debugging, learning | 15-30 minutes |
| **Azure** | Production deployment, workshop exercises | 45-90 minutes |

### 2.1 Prerequisites

Before starting, make sure you have the following tools and accounts set up.

#### 2.1.1 Required Tools

Install these tools on your computer:

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Node.js** | 20.x LTS | JavaScript runtime | [Download](https://nodejs.org/) |
| **npm** | 10.x+ | Package manager | Included with Node.js |
| **Git** | 2.x+ | Version control | [Download](https://git-scm.com/) |
| **Docker Desktop** | Latest | Local MongoDB | [Download](https://www.docker.com/products/docker-desktop/) |
| **Azure CLI** | 2.60+ | Azure management | [Install Guide](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| **VS Code** | Latest | Code editor (recommended) | [Download](https://code.visualstudio.com/) |

**Verify your installation:**

```bash
# Check Node.js
node --version
# Expected: v20.x.x

# Check npm
npm --version
# Expected: 10.x.x

# Check Git
git --version
# Expected: git version 2.x.x

# Check Docker
docker --version
# Expected: Docker version 24.x.x or newer

# Check Azure CLI
az --version
# Expected: azure-cli 2.60.x or newer
```

#### 2.1.2 Required Accounts

You need access to the following:

| Account | Purpose | How to Get |
|---------|---------|------------|
| **Microsoft Azure** | Cloud platform | [Free Account](https://azure.microsoft.com/free/) |
| **Microsoft Entra ID** | Authentication | Included with Azure subscription |
| **GitHub** (optional) | Clone repository | [Sign Up](https://github.com/join) |

> **💡 Tip for Azure beginners:** Azure offers $200 free credit for new accounts. This is more than enough to complete this workshop.

#### 2.1.3 Required Permissions for Entra ID

> ⚠️ **IMPORTANT: Check Your Permissions Before Starting**
>
> To create app registrations in Microsoft Entra ID, you need one of the following:
>
> | Role/Setting | Who Has It |
> |--------------|------------|
> | **Application Developer** role | Assigned by your IT admin |
> | **Cloud Application Administrator** role | Assigned by your IT admin |
> | **Global Administrator** role | Tenant administrators |
> | **"Users can register applications"** = Yes | Default tenant setting (may be disabled) |
>
> **How to check if you have permission:**
> 1. Go to [Azure Portal](https://portal.azure.com) → Microsoft Entra ID → App registrations
> 2. Click "+ New registration"
> 3. If you see the registration form, you have permission ✅
> 4. If you see an error or the button is disabled, contact your IT administrator ❌
>
> **For Workshop Organizers:**
> If participants cannot create app registrations, you have two options:
> 1. **Ask IT admin** to assign the "Application Developer" role to participants
> 2. **Pre-create app registrations** and share the Client IDs with participants
>
> **For Personal/Free Azure Accounts:**
> If you created your own Azure account, you are automatically the Global Administrator and can create app registrations without any additional setup.

#### 2.1.3 Microsoft Entra ID App Registrations

You need to create **two app registrations** in Microsoft Entra ID. This is required for both local development and Azure deployment.

> **Why two app registrations?**
> - **Frontend App**: Handles user login via MSAL.js (browser-based)
> - **Backend API App**: Validates JWT tokens and protects API endpoints

**Step-by-step guide:**

<details>
<summary>📝 Click to expand: Create Frontend App Registration</summary>

1. **Open Azure Portal**
   - Go to [portal.azure.com](https://portal.azure.com)
   - Sign in with your Microsoft account

2. **Navigate to Entra ID**
   - In the search bar at the top, type "Entra ID"
   - Click on "Microsoft Entra ID"

3. **Create App Registration**
   - In the left menu, click "App registrations"
   - Click "+ New registration" button

4. **Configure the App**
   - **Name**: `BlogApp Frontend (Dev)` (or any name you prefer)
   - **Supported account types**: Select "Accounts in this organizational directory only"
   - **Redirect URI**: 
     - Select **"Single-page application (SPA)"** from the dropdown
     - Enter: `http://localhost:5173`

   > ⚠️ **CRITICAL**: You MUST select **"Single-page application (SPA)"** - NOT "Web". 
   > If you select "Web", authentication will fail with error `AADSTS9002326`.

5. **Click "Register"**

6. **Copy Important Values** (you'll need these later)
   - **Application (client) ID**: This is your `VITE_ENTRA_CLIENT_ID`
   - **Directory (tenant) ID**: This is your `VITE_ENTRA_TENANT_ID`

   > 💡 Keep this browser tab open - you'll need these values soon.

</details>

<details>
<summary>📝 Click to expand: Create Backend API App Registration</summary>

1. **Create Another App Registration**
   - Go back to "App registrations"
   - Click "+ New registration"

2. **Configure the App**
   - **Name**: `BlogApp API (Dev)`
   - **Supported account types**: "Accounts in this organizational directory only"
   - **Redirect URI**: Leave empty (APIs don't need redirect URIs)

3. **Click "Register"**

4. **Copy the Application (client) ID**
   - This is your `ENTRA_CLIENT_ID` (for backend)
   - Also used as `VITE_API_CLIENT_ID` (for frontend)

5. **Expose an API Scope**
   - In the left menu, click "Expose an API"
   - Click "Add a scope"
   - If asked for Application ID URI, click "Save and continue" (accept default)
   - Configure the scope:
     - **Scope name**: `access_as_user`
     - **Who can consent**: Admins and users
     - **Admin consent display name**: `Access BlogApp API`
     - **Admin consent description**: `Allows the app to access BlogApp API on behalf of the signed-in user`
   - Click "Add scope"

</details>

<details>
<summary>📝 Click to expand: Grant Frontend Permission to Call Backend API</summary>

1. **Go to Frontend App Registration**
   - Navigate to App registrations → `BlogApp Frontend (Dev)`

2. **Add API Permission**
   - In the left menu, click "API permissions"
   - Click "+ Add a permission"
   - Select "My APIs" tab
   - Click on "BlogApp API (Dev)"
   - Check the box next to `access_as_user`
   - Click "Add permissions"

3. **(Optional) Grant Admin Consent**
   - If you're an admin, click "Grant admin consent for [Your Organization]"
   - This prevents users from needing to consent individually

</details>

**Summary of Values You'll Need:**

| Value | Where to Find | Used For |
|-------|---------------|----------|
| `VITE_ENTRA_CLIENT_ID` | Frontend app → Overview → Application (client) ID | Frontend login |
| `VITE_ENTRA_TENANT_ID` | Any app → Overview → Directory (tenant) ID | Both frontend and backend |
| `ENTRA_CLIENT_ID` | Backend API app → Overview → Application (client) ID | Backend token validation |
| `VITE_API_CLIENT_ID` | Same as ENTRA_CLIENT_ID | Frontend API calls |

---

### 2.2 Local Development Environment

Follow these steps to run the application on your local machine.

#### Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/AzureIaaSWorkshop.git

# Navigate to project folder
cd AzureIaaSWorkshop
```

#### Step 2: Start MongoDB

The application uses MongoDB with a replica set. We provide a Docker Compose configuration for easy setup.

```bash
# Navigate to dev-environment folder
cd dev-environment

# Start MongoDB container
docker-compose up -d

# Wait for MongoDB to be ready (about 5 seconds)
sleep 5

# Initialize the replica set (first time only)
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

**Verify MongoDB is running:**

```bash
# Check container status
docker-compose ps

# Expected output:
# NAME                   STATUS          PORTS
# blogapp-mongo-primary  running         0.0.0.0:27017->27017/tcp

# Test MongoDB connection
docker exec -it blogapp-mongo-primary mongosh --eval "db.adminCommand('ping')"
# Expected: { ok: 1 }
```

> **💡 Troubleshooting:** If the container fails to start, try:
> ```bash
> docker-compose down -v  # Remove existing volumes
> docker-compose up -d    # Start fresh
> ```

#### Step 3: Configure and Start Backend

```bash
# Navigate to backend folder (from project root)
cd materials/backend

# Create environment file from example
cp .env.example .env
```

**Edit `.env` file** with your Entra ID values:

```bash
# materials/backend/.env

NODE_ENV=development
PORT=3000

# MongoDB (local Docker)
MONGODB_URI=mongodb://localhost:27017/blogapp?replicaSet=blogapp-rs0

# Microsoft Entra ID - Use values from your Backend API app registration
ENTRA_TENANT_ID=paste-your-tenant-id-here
ENTRA_CLIENT_ID=paste-your-backend-api-client-id-here

# Logging
LOG_LEVEL=debug

# CORS (allow frontend to call API)
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

**Start the backend:**

```bash
# Install dependencies
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

**Verify backend is working:**

```bash
# In a new terminal
curl http://localhost:3000/health

# Expected response:
# {"status":"healthy","timestamp":"...","environment":"development"}
```

> **Keep this terminal open** - the backend needs to stay running.

#### Step 4: Configure and Start Frontend

```bash
# Open a new terminal and navigate to frontend folder
cd materials/frontend

# Create environment file from example
cp .env.example .env
```

**Edit `.env` file** with your Entra ID values:

```bash
# materials/frontend/.env

# Frontend App Registration (for MSAL login)
VITE_ENTRA_CLIENT_ID=paste-your-frontend-client-id-here
VITE_ENTRA_TENANT_ID=paste-your-tenant-id-here
VITE_ENTRA_REDIRECT_URI=http://localhost:5173

# Backend API App Registration (for API token audience)
VITE_API_CLIENT_ID=paste-your-backend-api-client-id-here
```

**Start the frontend:**

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

**Expected output:**
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

#### Step 5: Test the Application

1. **Open your browser** and go to: **http://localhost:5173**

2. **Test without login:**
   - You should see the home page with a list of posts (may be empty initially)
   - This verifies frontend → backend → MongoDB connection is working

3. **Test login:**
   - Click the **"Login"** button in the header
   - Sign in with your Microsoft account
   - Accept the permissions when prompted
   - After login, your name should appear in the header

4. **Test authenticated features:**
   - Click **"Create Post"** to write a new blog post
   - Save as draft or publish
   - View your posts in **"My Posts"**

**🎉 Congratulations!** Your local development environment is ready.

#### Quick Commands Reference

```bash
# Start everything (run in separate terminals)
cd dev-environment && docker-compose up -d      # Terminal 1: MongoDB
cd materials/backend && npm run dev              # Terminal 2: Backend
cd materials/frontend && npm run dev             # Terminal 3: Frontend

# Stop everything
docker-compose stop                              # Stop MongoDB
# Press Ctrl+C in backend/frontend terminals

# Reset database (if needed)
cd dev-environment
docker-compose down -v
docker-compose up -d
sleep 5
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js

# Add sample data (optional)
cd materials/backend && npm run seed
```

---

### 2.3 Azure Deployment

Follow these steps to deploy the application to Azure.

> **⏱️ Estimated time:** 45-90 minutes (including infrastructure provisioning)

#### Step 1: Login to Azure

```bash
# Login to Azure
az login

# Verify you're logged in
az account show

# (Optional) Set specific subscription if you have multiple
az account set --subscription "Your Subscription Name"
```

#### Step 2: Generate SSL Certificate

Application Gateway requires an SSL certificate for HTTPS. For this workshop, we'll create a self-signed certificate.

**macOS/Linux:**
```bash
# Navigate to project root
cd AzureIaaSWorkshop

# Make script executable
chmod +x scripts/generate-ssl-cert.sh

# Generate certificate
./scripts/generate-ssl-cert.sh
```

**Windows PowerShell:**
```powershell
# Navigate to project root
cd AzureIaaSWorkshop

# Generate certificate
.\scripts\generate-ssl-cert.ps1
```

This creates:
- `cert.pfx` - Certificate file for Application Gateway
- `cert-base64.txt` - Base64-encoded certificate (paste into Bicep parameters)

#### Step 3: Get Your Azure Values

You'll need several values for the deployment. Here's how to get them:

```bash
# Get your Tenant ID
az account show --query tenantId -o tsv

# Get your Object ID (for Key Vault access)
az ad signed-in-user show --query id -o tsv

# Get your SSH public key (or generate one)
cat ~/.ssh/id_rsa.pub

# If you don't have an SSH key, generate one:
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### Step 4: Configure Bicep Parameters

```bash
# Navigate to bicep folder
cd materials/bicep

# Create your local parameter file
cp main.bicepparam main.local.bicepparam
```

**Edit `main.local.bicepparam`** with your values:

```bicep
using './main.bicep'

// ============================================================
// REQUIRED: Azure Security Parameters
// ============================================================
param sshPublicKey = 'ssh-rsa AAAA...your-public-key...'
param adminObjectId = 'your-object-id-from-step-3'

// ============================================================
// REQUIRED: Microsoft Entra ID Parameters
// ============================================================
param entraTenantId = 'your-tenant-id'
param entraClientId = 'your-backend-api-client-id'
param entraFrontendClientId = 'your-frontend-client-id'

// ============================================================
// REQUIRED: Application Gateway SSL/TLS Configuration
// ============================================================
// Paste the contents of cert-base64.txt (one long line)
param sslCertificateData = 'MIIKcQIBAzCCCi...very-long-base64-string...'
param sslCertificatePassword = 'Workshop2024!'

// Choose a unique DNS label (must be unique in your region)
param appGatewayDnsLabel = 'blogapp-yourname-1234'
```

> **💡 Choosing a DNS label:** The label must be unique within your Azure region. Try formats like:
> - `blogapp-yourname-0106` (name + date)
> - `blogapp-team1-abc` (team + random)

#### Step 5: Deploy to Azure

```bash
# Create resource group
az group create --name rg-blogapp-workshop --location japanwest

# Deploy infrastructure (this takes 15-30 minutes)
az deployment group create \
  --resource-group rg-blogapp-workshop \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam
```

**Wait for deployment to complete.** You can monitor progress in:
- Terminal output
- Azure Portal → Resource groups → rg-blogapp-workshop → Deployments

#### Step 6: Run Post-Deployment Setup

The post-deployment script initializes MongoDB replica set and creates database users.

```bash
# Navigate to scripts folder
cd scripts

# Create your local script
cp post-deployment-setup.template.sh post-deployment-setup.local.sh
chmod +x post-deployment-setup.local.sh

# Edit the script and replace placeholders:
# - <RESOURCE_GROUP> → rg-blogapp-workshop
# - <BASTION_NAME> → bastion-blogapp-prod
# - <MONGODB_ADMIN_PASSWORD> → Your chosen admin password
# - <MONGODB_APP_PASSWORD> → Your chosen app password

# Run the script
./post-deployment-setup.local.sh
```

#### Step 7: Update Entra ID Redirect URIs

After deployment, update your frontend app registration with the production URL:

```bash
# Get your Application Gateway FQDN
FQDN=$(az network public-ip show \
  --resource-group rg-blogapp-workshop \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "Your Application URL: https://$FQDN"

# Update redirect URIs
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='your-frontend-client-id')" \
  --headers "Content-Type=application/json" \
  --body "{
    \"spa\": {
      \"redirectUris\": [
        \"https://$FQDN\",
        \"https://$FQDN/\",
        \"http://localhost:5173\",
        \"http://localhost:5173/\"
      ]
    }
  }"
```

#### Step 8: Deploy Application Code

**Deploy Backend to App VMs:**

Connect to each App VM via Bastion and deploy the backend code. See [deployment-strategy.md](AIdocs/dev-record/deployment-strategy.md) Phase 2 for detailed steps.

**Deploy Frontend to Web VMs:**

Connect to each Web VM via Bastion and deploy the frontend code. See [deployment-strategy.md](AIdocs/dev-record/deployment-strategy.md) Phase 3 for detailed steps.

#### Step 9: Verify Deployment

```bash
# Test HTTPS access (use -k for self-signed certificate)
curl -k https://$FQDN/

# Test API endpoint
curl -k https://$FQDN/api/health

# Open in browser
echo "Open: https://$FQDN"
```

> **⚠️ Browser Warning:** Your browser will show a certificate warning because we're using a self-signed certificate. This is expected for the workshop. Click "Advanced" → "Proceed" to continue.

**🎉 Congratulations!** Your application is now running on Azure!

#### Cleanup (When Done)

To avoid ongoing Azure charges, delete all resources when you're finished:

```bash
# Delete resource group and all resources inside
az group delete --name rg-blogapp-workshop --yes --no-wait
```

---

## 3. Resiliency Testing

*This section will contain exercises for testing the high availability and disaster recovery capabilities of the deployed architecture.*

### Planned Exercises

| Exercise | Description | Status |
|----------|-------------|--------|
| **VM Failure Simulation** | Stop a VM and verify automatic failover | 🔜 Coming Soon |
| **Zone Failure Simulation** | Test cross-zone failover | 🔜 Coming Soon |
| **Database Failover** | Force MongoDB replica set failover | 🔜 Coming Soon |
| **Load Balancer Health Probes** | Verify unhealthy instances are removed | 🔜 Coming Soon |
| **Application Gateway Failover** | Test backend pool failover | 🔜 Coming Soon |

### Prerequisites for Resiliency Testing

- Completed Azure deployment (Section 2.3)
- Azure CLI configured
- Access to Azure Portal for monitoring

*Detailed instructions will be added in future updates.*

---

## Additional Resources

### Documentation

- [Deployment Strategy (Detailed)](AIdocs/dev-record/deployment-strategy.md) - Complete step-by-step deployment guide
- [Azure Architecture Design](design/AzureArchitectureDesign.md) - Infrastructure specifications
- [Backend Application Design](design/BackendApplicationDesign.md) - API design and specifications
- [Frontend Application Design](design/FrontendApplicationDesign.md) - UI/UX specifications
- [Database Design](design/DatabaseDesign.md) - MongoDB schema and patterns

### Azure Documentation

- [Azure Virtual Machines](https://docs.microsoft.com/azure/virtual-machines/)
- [Azure Application Gateway](https://docs.microsoft.com/azure/application-gateway/)
- [Azure Load Balancer](https://docs.microsoft.com/azure/load-balancer/)
- [Microsoft Entra ID](https://docs.microsoft.com/azure/active-directory/)
- [Azure Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)

### AWS to Azure Comparison

| AWS Service | Azure Equivalent |
|-------------|------------------|
| EC2 | Virtual Machines |
| ALB | Application Gateway |
| NLB | Standard Load Balancer |
| VPC | Virtual Network |
| NAT Gateway | NAT Gateway |
| Cognito | Microsoft Entra ID |
| CloudFormation | Bicep / ARM Templates |
| CloudWatch | Azure Monitor |

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
