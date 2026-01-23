# Azure IaaS Workshop - Multi-User Blog Application

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

日本語版: [README.ja.md](./README.ja.md)

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
  - [2.2 Local Development (Optional)](#22-local-development-environment-optional)
  - [2.3 Azure Deployment](#23-azure-deployment)
- [3. Resiliency Testing](#3-resiliency-testing)
- [4. Operational Guides](#4-operational-guides)

---

## 1. Introduction

### 1.1 About This Workshop

This workshop is designed for engineers who want to learn **Azure Infrastructure as a Service (IaaS)** patterns by building a real-world, production-ready web application. 

**Target Audience:**
- Engineers with 3-5 years of experience (particularly those familiar with AWS)
- Developers preparing for Azure certifications (AZ-104, AZ-305)
- Teams migrating from AWS to Azure

**Workshop Duration:**　approximately 4 hours

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

![Architecture Diagram](assets/Architecture/architecture.png)

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

This section explains how to deploy the application to Azure.

> **📝 Looking for local development setup?**
> See the [Local Development Guide](materials/docs/local-development-guide.md) for running the application on your local machine.

### 2.1 Prerequisites

Before starting, make sure you have the following tools and accounts set up.

#### 2.1.1 Required Tools

Install these tools on your computer:

**All Platforms:**

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Git** | 2.x+ | Version control | [Download](https://git-scm.com/) |
| **VS Code** | Latest | Code editor (recommended) | [Download](https://code.visualstudio.com/) |

**macOS/Linux:**

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Azure CLI** | 2.60+ | Azure management | [Install Guide](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| **OpenSSL** | Latest | SSL certificate generation | Pre-installed |

**Windows:**

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Azure PowerShell** | 12.0+ | Azure management | [Install Guide](https://docs.microsoft.com/powershell/azure/install-azure-powershell) |
| **Bicep CLI** | Latest | Infrastructure as Code | [Install Guide](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#windows) |
| **OpenSSL** | Latest | SSL certificate generation | [Download](https://slproweb.com/products/Win32OpenSSL.html) |

> **⚠️ Important: Bicep CLI Required for Windows**  
> Unlike Azure CLI (which auto-installs Bicep), Azure PowerShell requires manual Bicep CLI installation.
> 
> **Recommended installation method (winget):**
> ```powershell
> winget install -e --id Microsoft.Bicep
> ```
> 
> **Alternative methods:**
> - **Chocolatey:** `choco install bicep`
> - **Windows Installer:** [Download bicep-setup-win-x64.exe](https://github.com/Azure/bicep/releases/latest/download/bicep-setup-win-x64.exe)
> 
> After installation, close and reopen your terminal, then verify:
> ```powershell
> bicep --version
> # Expected: Bicep CLI version 0.x.x
> ```

**Verify your installation:**

**macOS/Linux:**
```bash
# Check Git
git --version
# Expected: git version 2.x.x

# Check Azure CLI
az --version
# Expected: azure-cli 2.60.x or newer

# Check OpenSSL
openssl version
# Expected: OpenSSL 3.x.x or LibreSSL 3.x.x
```

**Windows PowerShell:**
```powershell
# Check Git
git --version
# Expected: git version 2.x.x

# Check Azure PowerShell
Get-Module -Name Az -ListAvailable | Select-Object Name, Version
# Expected: Az 12.x.x or newer

# Check Bicep CLI
bicep --version
# Expected: Bicep CLI version 0.x.x

# Check OpenSSL
openssl version
# Expected: OpenSSL 3.x.x
```

> **📝 Need Node.js and Docker?** These are only required for [local development](materials/docs/local-development-guide.md), not for Azure deployment.

#### 2.1.2 Required Accounts

You need access to the following:

| Account | Purpose | How to Get |
|---------|---------|------------|
| **Microsoft Azure** | Cloud platform | [Free Account](https://azure.microsoft.com/free/). Workshop attendees must have an active subscription with owner role.|
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

#### 2.1.4 Clone the Repository

Clone the workshop repository to your local machine:

```bash
# Clone the official repository
git clone https://github.com/hironariy/Azure-IaaS-Workshop.git

# Navigate to the project folder
cd Azure-IaaS-Workshop
```

> **💡 For Workshop Participants:** If you forked this repository to your own GitHub account, clone your fork instead:
> ```bash
> git clone https://github.com/YOUR_USERNAME/Azure-IaaS-Workshop.git
> cd Azure-IaaS-Workshop
> ```

#### 2.1.5 Microsoft Entra ID App Registrations

You need to create **two app registrations** in Microsoft Entra ID. This is required for Azure deployment (and also for local development).

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
   - In the left menu, click "Manage" > "App registrations"
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

### 2.2 Local Development Environment (Optional)

> **📖 Full Guide:** For local development setup, see the [Local Development Guide](materials/docs/local-development-guide.md).

Local development requires additional tools (Node.js, Docker) and is useful for:
- Making code changes and debugging
- Testing features before Azure deployment
- Learning the application architecture

If you just want to deploy to Azure, you can skip to the next section.

---

### 2.3 Azure Deployment

Follow these steps to deploy the application to Azure.

> **⏱️ Estimated time:** 45-90 minutes (including infrastructure provisioning)

#### Step 1: Login to Azure

**macOS/Linux (bash/zsh):**
```bash
# Login to Azure
az login

# Verify you're logged in
az account show

# (Optional) Set specific subscription if you have multiple
az account set --subscription "Your Subscription Name"
```

**Windows PowerShell:**
```powershell
# Login to Azure
Connect-AzAccount

# Verify you're logged in
Get-AzContext

# (Optional) Set specific subscription if you have multiple
Set-AzContext -Subscription "Your Subscription Name"
```

#### Step 2: Generate SSL Certificate

Application Gateway requires an SSL certificate for HTTPS. For this workshop, we'll create a self-signed certificate.

**macOS/Linux:**
```bash
# Navigate to project root
cd Azure-IaaS-Workshop

# Make script executable
chmod +x scripts/generate-ssl-cert.sh

# Generate certificate
./scripts/generate-ssl-cert.sh
```

**Windows PowerShell:**
```powershell
# Navigate to project root
cd Azure-IaaS-Workshop

# Generate certificate
.\scripts\generate-ssl-cert.ps1
```

This creates:
- `cert.pfx` - Certificate file for Application Gateway
- `cert-base64.txt` - Base64-encoded certificate (paste into Bicep parameters)

#### Step 3: Get Your Azure Values

You'll need several values for the deployment. Here's how to get them:

**macOS/Linux (bash/zsh):**
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

**Windows PowerShell:**
```powershell
# Get your Tenant ID
(Get-AzContext).Tenant.Id

# Get your Object ID (for Key Vault access)
(Get-AzADUser -SignedIn).Id

# Get your SSH public key (or generate one)
Get-Content ~/.ssh/id_rsa.pub

# If you don't have an SSH key, generate one:
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### Step 4: Configure Bicep Parameters

**macOS/Linux:**
```bash
# Navigate to bicep folder
cd materials/bicep

# Create your local parameter file
cp main.bicepparam main.local.bicepparam
```

**Windows PowerShell:**
```powershell
# Navigate to bicep folder
cd materials\bicep

# Create your local parameter file
Copy-Item main.bicepparam main.local.bicepparam
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

**macOS/Linux (bash/zsh):**
```bash
# Create resource group
az group create --name rg-blogapp-workshop --location japanwest

# Deploy infrastructure (this takes 15-30 minutes)
az deployment group create \
  --resource-group rg-blogapp-workshop \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam
```

**Windows PowerShell:**
```powershell
# Create resource group
New-AzResourceGroup -Name rg-blogapp-workshop -Location japanwest

# Deploy infrastructure (this takes 15-30 minutes)
New-AzResourceGroupDeployment `
  -ResourceGroupName rg-blogapp-workshop `
  -TemplateFile materials\bicep\main.bicep `
  -TemplateParameterFile materials\bicep\main.local.bicepparam
```

**Wait for deployment to complete.** You can monitor progress in:
- Terminal output
- Azure Portal → Resource groups → rg-blogapp-workshop → Deployments

#### Step 6: Run Post-Deployment Setup

The post-deployment script initializes MongoDB replica set and creates database users.

**macOS/Linux:**
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

**Windows PowerShell:**
```powershell
# Navigate to scripts folder
cd scripts

# Create your local script
Copy-Item post-deployment-setup.template.ps1 post-deployment-setup.local.ps1

# Edit the script and replace placeholders:
# - <RESOURCE_GROUP> → rg-blogapp-workshop
# - <BASTION_NAME> → bastion-blogapp-prod
# - <MONGODB_ADMIN_PASSWORD> → Your chosen admin password
# - <MONGODB_APP_PASSWORD> → Your chosen app password

# Run the script
.\post-deployment-setup.local.ps1
```

#### Step 7: Configure Azure Monitor (DCR)

Create the Data Collection Rule to enable VM monitoring:

**macOS/Linux:**
```bash
# From project root
./scripts/configure-dcr.sh rg-blogapp-workshop
```

**Windows PowerShell:**
```powershell
.\scripts\configure-dcr.ps1 -ResourceGroupName rg-blogapp-workshop
```

> **📝 Why is this separate?** New Log Analytics workspaces need 1-5 minutes for tables to initialize. The script waits for this and then creates the DCR with Syslog and Performance Counter collection.

#### Step 8: Update Entra ID Redirect URIs

After deployment, update your frontend app registration with the production URL:

**macOS/Linux (bash/zsh):**
```bash
# Get your Application Gateway FQDN
FQDN=$(az network public-ip show \
  --resource-group rg-blogapp-workshop \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "Your Application URL: https://$FQDN"

# Set your Frontend Client ID (from Step 4 / entraFrontendClientId)
FRONTEND_CLIENT_ID="your-frontend-client-id"  # ← Replace with your actual value

# Update redirect URIs
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='$FRONTEND_CLIENT_ID')" \
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

**Windows PowerShell:**
```powershell
# Get your Application Gateway FQDN
$pip = Get-AzPublicIpAddress -ResourceGroupName rg-blogapp-workshop -Name pip-agw-blogapp-prod
$FQDN = $pip.DnsSettings.Fqdn

Write-Host "Your Application URL: https://$FQDN"

# Set your Frontend Client ID (from Step 4 / entraFrontendClientId)
$FrontendClientId = "your-frontend-client-id"  # ← Replace with your actual value

# Update redirect URIs using Microsoft Graph PowerShell
# First, install Microsoft Graph module if not installed:
# Install-Module Microsoft.Graph -Scope CurrentUser

Connect-MgGraph -Scopes "Application.ReadWrite.All"

$app = Get-MgApplication -Filter "AppId eq '$FrontendClientId'"

$redirectUris = @(
    "https://$FQDN",
    "https://$FQDN/",
    "http://localhost:5173",
    "http://localhost:5173/"
)

Update-MgApplication -ApplicationId $app.Id -Spa @{RedirectUris = $redirectUris}
```

> **⚠️ Admin Consent Required:** The `Application.ReadWrite.All` scope requires tenant administrator approval. If you see a "Need admin approval" error, use one of the alternatives below.

**Alternative 1: Manual Configuration via Azure Portal (Recommended)**

This method doesn't require any special permissions beyond owning the app registration:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** → **App registrations** → **BlogApp Frontend (Dev)**
3. Click **Authentication** in the left menu
4. Under **Single-page application**, click **Add URI** and add:
   - `https://<YOUR_FQDN>` (replace with your Application Gateway FQDN)
   - `https://<YOUR_FQDN>/`
5. Click **Save**

**Alternative 2: Request Admin Consent**

If you prefer using PowerShell, ask your tenant administrator to:

1. Go to **Azure Portal** → **Microsoft Entra ID** → **Enterprise applications**
2. Search for **Microsoft Graph Command Line Tools**
3. Click **Permissions** in the left menu
4. Click **Grant admin consent for [Organization Name]**

After admin consent is granted, you can run the PowerShell commands above.

> **💡 Alternative:** You can also update redirect URIs manually in Azure Portal:
> 1. Go to **Microsoft Entra ID** → **App registrations** → **BlogApp Frontend (Dev)**
> 2. Click **Authentication** in the left menu
> 3. Under **Single-page application**, add `https://<YOUR_FQDN>` and `https://<YOUR_FQDN>/`
> 4. Click **Save**

#### Step 9: Deploy Application Code

**Deploy Backend to App VMs:**

Connect to each App VM via Bastion and deploy the backend code. See [deployment-strategy.md](AIdocs/dev-record/deployment-strategy.md) Phase 2 for detailed steps.

**Deploy Frontend to Web VMs:**

Connect to each Web VM via Bastion and deploy the frontend code. See [deployment-strategy.md](AIdocs/dev-record/deployment-strategy.md) Phase 3 for detailed steps.

#### Step 10: Verify Deployment

```bash
# Test HTTPS access (use -k for self-signed certificate)
curl -k https://$FQDN/

# Test API endpoint (use /api/posts - backend health is at /health, not /api/health)
curl -k https://$FQDN/api/posts

# Open in browser
echo "Open: https://$FQDN"
```

> **⚠️ Browser Warning:** Your browser will show a certificate warning because we're using a self-signed certificate. This is expected for the workshop. Click "Advanced" → "Proceed" to continue.

**🎉 Congratulations!** Your application is now running on Azure!

#### Cleanup (When Done)

To avoid ongoing Azure charges, delete all resources when you're finished:

**macOS/Linux (bash/zsh):**
```bash
# Delete resource group and all resources inside
az group delete --name rg-blogapp-workshop --yes --no-wait
```

**Windows PowerShell:**
```powershell
# Delete resource group and all resources inside
Remove-AzResourceGroup -Name rg-blogapp-workshop -Force -AsJob
```

---

## 3. Resiliency Testing

This section contains exercises for testing the high availability and disaster recovery capabilities of the deployed architecture.

### Prerequisites

- Completed Azure deployment (Section 2.3)
- Azure CLI configured and logged in
- Access to Azure Portal for monitoring
- Application accessible via Application Gateway URL

### 3.1 Core Resiliency Tests (Recommended)

These tests demonstrate automatic failover capabilities without requiring complex manual recovery steps.

#### Test 1: Web Tier VM Failure

**Objective:** Verify Application Gateway removes failed VM from backend pool automatically.

```bash
# 1. Verify both Web VMs are healthy
az network application-gateway show-backend-health \
  -g rg-blogapp-workshop \
  -n agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# 2. Stop one Web VM
az vm stop -g rg-blogapp-workshop -n vm-web-az1-prod

# 3. Wait for health probe (60 seconds)
sleep 60

# 4. Verify application still works
curl -k https://<YOUR_APPGW_FQDN>/

# 5. Check backend health - one should be "Unhealthy"
az network application-gateway show-backend-health \
  -g rg-blogapp-workshop \
  -n agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# 6. Restore the VM
az vm start -g rg-blogapp-workshop -n vm-web-az1-prod
```

**Expected Result:** Application continues to work. Traffic automatically routes to healthy VM.

---

#### Test 2: App Tier VM Failure

**Objective:** Verify Internal Load Balancer removes failed VM from backend pool.

```bash
# 1. Stop one App VM
az vm stop -g rg-blogapp-workshop -n vm-app-az1-prod

# 2. Wait for health probe (60 seconds)
sleep 60

# 3. Test API endpoint - should still work
curl -k https://<YOUR_APPGW_FQDN>/api/posts

# 4. Restore the VM
az vm start -g rg-blogapp-workshop -n vm-app-az1-prod
```

**Expected Result:** API continues to respond. Internal LB routes to healthy App VM.

---

#### Test 3: Application Process Failure (NGINX)

**Objective:** Verify health probes detect application-level failures, not just VM failures.

```bash
# 1. Connect to Web VM via Bastion
az network bastion ssh \
  -n bastion-blogapp-prod \
  -g rg-blogapp-workshop \
  --target-resource-id $(az vm show -g rg-blogapp-workshop -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Stop NGINX
sudo systemctl stop nginx

# 3. Exit and wait for health probe
exit
sleep 60

# 4. Test application - should still work via other VM
curl -k https://<YOUR_APPGW_FQDN>/

# 5. Reconnect and restart NGINX
# (use same bastion ssh command as step 1)
sudo systemctl start nginx
```

**Expected Result:** Application Gateway detects NGINX failure and routes traffic to healthy VM.

---

#### Test 4: Application Process Failure (Node.js/PM2)

**Objective:** Verify Internal LB detects Node.js application failure.

```bash
# 1. Connect to App VM via Bastion
az network bastion ssh \
  -n bastion-blogapp-prod \
  -g rg-blogapp-workshop \
  --target-resource-id $(az vm show -g rg-blogapp-workshop -n vm-app-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Stop the application
pm2 stop blogapp-api

# 3. Exit and test API
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Should still work via other App VM

# 4. Reconnect and restart
pm2 start blogapp-api
```

**Expected Result:** API continues to respond via healthy App VM.

---

#### Test 5: MongoDB Graceful Failover (rs.stepDown)

**Objective:** Verify MongoDB replica set automatic election when primary steps down gracefully.

> **Note:** This tests graceful failover where both members are online. For hard failure scenarios, see Optional Tests.

```bash
# 1. Connect to primary DB VM
az network bastion ssh \
  -n bastion-blogapp-prod \
  -g rg-blogapp-workshop \
  --target-resource-id $(az vm show -g rg-blogapp-workshop -n vm-db-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Check current status
mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'

# 3. Force primary to step down (triggers election)
mongosh --eval 'rs.stepDown(60)'

# 4. Check new status - roles should be swapped
mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'

# 5. Exit and test application
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**Expected Result:** Secondary becomes PRIMARY within 10-15 seconds. Application reconnects automatically.

---

#### Test 6: Traffic Distribution Verification

**Objective:** Confirm Application Gateway distributes traffic across multiple instances.

```bash
# Terminal 1: Tail logs on Web VM AZ1
az network bastion ssh ... -n vm-web-az1-prod
sudo tail -f /var/log/nginx/access.log

# Terminal 2: Tail logs on Web VM AZ2
az network bastion ssh ... -n vm-web-az2-prod
sudo tail -f /var/log/nginx/access.log

# Terminal 3: Generate traffic
for i in {1..20}; do
  curl -k https://<YOUR_APPGW_FQDN>/ > /dev/null 2>&1
  sleep 1
done
```

**Expected Result:** Requests appear in BOTH Web VM logs, showing load balancing.

---

#### Test 7: Health Probe Manipulation

**Objective:** Understand how health probes affect traffic routing.

```bash
# 1. Connect to Web VM
az network bastion ssh ... -n vm-web-az1-prod

# 2. Inject health failure into NGINX config
sudo sed -i '/server {/a \    location = /health { return 503 "unhealthy"; add_header Content-Type text/plain; }' /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# 3. Verify health returns 503
curl -I http://localhost/health

# 4. Exit and wait for probe detection
exit
sleep 60

# 5. Check backend health - should show one Unhealthy
az network application-gateway show-backend-health \
  -g rg-blogapp-workshop \
  -n agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# 6. Application should still work
curl -k https://<YOUR_APPGW_FQDN>/

# 7. Restore health endpoint
# Reconnect and run:
sudo sed -i '/location = \/health { return 503/d' /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**Expected Result:** Health probe detects 503, removes VM from pool, traffic routes to healthy VM.

---

#### Test 8: Network Partition (NSG-based)

**Objective:** Test behavior when network connectivity is lost between tiers.

```bash
# 1. Block App Tier → Database Tier traffic
az network nsg rule create \
  -g rg-blogapp-workshop \
  --nsg-name nsg-app-prod \
  -n DenyMongoDB \
  --priority 100 \
  --access Deny \
  --direction Outbound \
  --destination-address-prefixes 10.0.3.0/24 \
  --destination-port-ranges 27017 \
  --protocol Tcp

# 2. Test application - should return error
curl -k https://<YOUR_APPGW_FQDN>/api/posts

# 3. Remove the blocking rule
az network nsg rule delete \
  -g rg-blogapp-workshop \
  --nsg-name nsg-app-prod \
  -n DenyMongoDB

# 4. Verify recovery
sleep 30
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**Expected Result:** Application shows database error, then recovers after rule removal.

---

### 3.2 Optional Advanced Tests

The following tests involve **manual MongoDB recovery** due to the 2-member replica set limitation. They are educational but time-consuming (15-30 minutes each).

> ⚠️ **2-Member Replica Set Limitation**
> 
> MongoDB requires a majority vote to elect a new primary. With only 2 members:
> - When both are online: Election works (2/2 votes available)
> - When one is down: No election possible (only 1/2 votes)
> 
> This is why graceful `rs.stepDown()` works, but hard VM failure requires manual recovery.

| Test | Description | Time Required |
|------|-------------|---------------|
| **MongoDB Hard Failure** | Stop primary DB VM, observe no auto-election | 15-30 min |
| **Manual MongoDB Recovery** | Force reconfigure to promote secondary | 15-30 min |
| **Simulated Zone Failure** | Stop all Zone 1 VMs simultaneously | 20-40 min |
| **Azure Chaos Studio** | Use Azure's managed chaos engineering | Setup required |

For detailed instructions on these advanced tests, see:
📄 **[Resiliency Test Strategy (Full Document)](AIdocs/dev-record/resiliency-test-strategy.md)**

---

### 3.3 Test Summary

| Test | Type | Failover | Recovery |
|------|------|----------|----------|
| Web VM Stop | Automatic | ✅ Application Gateway health probe | Start VM |
| App VM Stop | Automatic | ✅ Internal LB health probe | Start VM |
| NGINX Stop | Automatic | ✅ Application Gateway health probe | Start NGINX |
| PM2 Stop | Automatic | ✅ Internal LB health probe | Start PM2 |
| MongoDB stepDown | Automatic | ✅ Replica set election | Automatic |
| MongoDB VM Stop | ⚠️ Manual | ❌ 2-member RS limitation | Force reconfigure |
| Zone Failure | ⚠️ Manual | ❌ Requires DB manual recovery | Force reconfigure + Start VMs |

### Key Learnings

After completing these tests, you will understand:

1. **Health Probes**: How Azure load balancers detect and route around failures
2. **Automatic Failover**: Web and App tiers fail over without intervention
3. **MongoDB Replication**: Graceful failover vs. hard failure scenarios
4. **2-Member RS Limitation**: Why production uses 3+ members or arbiters
5. **Defense in Depth**: Multiple layers of redundancy protect the application

---

## 4. Operational Guides

- [Monitoring Guide (Azure Monitor + Log Analytics)](./materials/docs/monitoring-guide.md)
- [BCDR Guide (Azure Backup + Azure Site Recovery)](./materials/docs/disaster-recovery-guide.md)

---

## Additional Resources

### Documentation

- [Local Development Guide](materials/docs/local-development-guide.md) - Run the application locally
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
