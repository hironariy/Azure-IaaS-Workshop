# Deployment Strategy for Blog Application to Azure VMs

**Date:** December 16, 2025  
**Author:** AI Deployment Agent  
**Status:** Template Ready  
**Last Updated:** January 2026 - Updated for Application Gateway with SSL/TLS termination

---

日本語版: [ブログアプリケーションのAzure VMへのデプロイ戦略](./deployment-strategy.ja.md)

## Executive Summary

This document outlines the deployment strategy for the multi-tier blog application to Azure VMs. The VMs are provisioned via Bicep templates which include **CustomScript Extensions** that:
1. Pre-install all middleware (MongoDB, Node.js, PM2, NGINX)
2. **Inject environment variables** to App tier VMs from Bicep parameters
3. **Create `/config.json`** on Web tier VMs for frontend runtime configuration

### Deployment Status

| Component | Status | Resource Group |
|-----------|--------|----------------|
| Infrastructure | ✅ Verified | `<YOUR_RESOURCE_GROUP>` |
| Config Injection (App tier) | ✅ Verified on all VMs | `/etc/environment`, `/opt/blogapp/.env` |
| Config Injection (Web tier) | ✅ Verified on all VMs | `/var/www/html/config.json` |
| MongoDB Replica Set | ✅ Verified | `post-deployment-setup.local.sh` |
| Backend Application | ✅ Verified | Deployed and running |
| Frontend Application | ✅ Verified | Static files deployed |

### Deployment Flow Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT FLOW                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Generate Self-Signed SSL Certificate                                │
│     └─ ./scripts/generate-ssl-cert.sh                                   │
│                          ↓                                               │
│  2. Edit main.bicepparam (or main.local.bicepparam)                     │
│     ├─ entraTenantId                                                    │
│     ├─ entraClientId (backend)                                          │
│     ├─ entraFrontendClientId                                            │
│     ├─ sshPublicKey                                                     │
│     ├─ adminObjectId                                                    │
│     ├─ sslCertificateData (base64-encoded PFX)                         │
│     ├─ sslCertificatePassword                                           │
│     └─ appGatewayDnsLabel (unique DNS label)                           │
│                          ↓                                               │
│  3. az deployment group create ...                                       │
│     └─ Creates all Azure resources with config injected                 │
│     └─ Application Gateway provides HTTPS with self-signed cert         │
│                          ↓                                               │
│  4. Post-deployment script (choose your platform)                       │
│     ├─ macOS/Linux: ./scripts/post-deployment-setup.local.sh            │
│     └─ Windows:     .\scripts\post-deployment-setup.local.ps1           │
│     Performs:                                                           │
│     ├─ Initializes MongoDB replica set                                  │
│     ├─ Creates MongoDB users (blogadmin, blogapp)                       │
│     └─ Verifies config injection (env vars, config.json)                │
│                          ↓                                               │
│  5. Deploy application code (backend + frontend)                        │
│     └─ No environment configuration needed!                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### What Bicep Provisions (Fully Automated)

| Tier | Pre-installed by Bicep | Config Injection | Status |
|------|------------------------|------------------|--------|
| **Database** | MongoDB 7.0, data disk at `/data/mongodb`, replica set config | N/A | ✅ Automated |
| **Backend** | Node.js 20 LTS, PM2, `/opt/blogapp` directory | `/etc/environment` + `/opt/blogapp/.env` with Entra IDs | ✅ Automated |
| **Frontend** | NGINX, reverse proxy config, `/var/www/html` | `/var/www/html/config.json` with Entra IDs | ✅ Automated |
| **Application Gateway** | SSL/TLS termination, HTTP→HTTPS redirect | Self-signed certificate, Azure DNS label | ✅ Automated |

> **Implementation Note:** Bicep templates use external shell scripts loaded via `loadTextContent()` with `replace()` functions for placeholder substitution. This avoids ARM's `format()` function issues with bash scripts and JSON containing curly braces.
>
> - `modules/compute/scripts/nginx-install.sh` - Web tier setup script
> - `modules/compute/scripts/nodejs-install.sh` - App tier setup script

### What Requires Post-Deployment Action

| Task | Manual/Automated | Script (macOS/Linux) | Script (Windows) |
|------|------------------|----------------------|------------------|
| Initialize MongoDB replica set | **Automated** | `post-deployment-setup.local.sh` | `post-deployment-setup.local.ps1` |
| Create MongoDB users | **Automated** | `post-deployment-setup.local.sh` | `post-deployment-setup.local.ps1` |
| Deploy backend application code | Manual | See Phase 2 | See Phase 2 |
| Deploy frontend static files | Manual | See Phase 3 | See Phase 3 |

### Target Environment

| Tier | VMs | IPs | Pre-installed | Config Files |
|------|-----|-----|---------------|--------------|
| Database | `vm-db-az1-prod`, `vm-db-az2-prod` | 10.0.3.4, 10.0.3.5 | MongoDB 7.0 | N/A |
| Backend | `vm-app-az1-prod`, `vm-app-az2-prod` | 10.0.2.5, 10.0.2.4 | Node.js 20, PM2 | `/etc/environment`, `/opt/blogapp/.env` |
| Frontend | `vm-web-az1-prod`, `vm-web-az2-prod` | 10.0.1.4, 10.0.1.5 | NGINX | `/var/www/html/config.json` |
| Application Gateway | N/A (PaaS) | Public IP | SSL/TLS termination | Self-signed certificate |

### Traffic Flow

```
Internet → Application Gateway (HTTPS:443)
         → SSL/TLS Termination (self-signed certificate)
         → Web Tier VMs (HTTP:80/NGINX)
         → Internal Load Balancer (HTTP:3000)
         → App Tier VMs (Express API)
         → MongoDB Replica Set
```

---

## Pre-Deployment: Generate SSL Certificate and Configure Bicep Parameters

### Step 0: Generate Self-Signed SSL Certificate

**Before deploying**, generate a self-signed SSL certificate for the Application Gateway:

**macOS/Linux:**
```bash
# Navigate to project root
cd /path/to/AzureIaaSWorkshop

# Generate self-signed certificate (valid for 365 days)
# This creates: cert.pfx and cert-base64.txt files
./scripts/generate-ssl-cert.sh

# The script will output:
# - cert.pfx (PKCS#12 format for Azure Application Gateway)
# - cert.pem (PEM format for reference)
# - cert-base64.txt (base64-encoded PFX for Bicep parameter)
```

**Windows PowerShell:**
```powershell
# Navigate to project root
cd C:\path\to\AzureIaaSWorkshop

# Generate self-signed certificate (valid for 365 days)
# Uses PowerShell's New-SelfSignedCertificate (no OpenSSL required)
.\scripts\generate-ssl-cert.ps1

# The script will output:
# - cert.pfx (PKCS#12 format for Azure Application Gateway)
# - cert-base64.txt (base64-encoded PFX for Bicep parameter)

# Copy base64 content to clipboard (for pasting into bicepparam)
Get-Content cert-base64.txt | Set-Clipboard
```

**Manual certificate generation (alternative):**

```bash
# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout cert.key -out cert.crt \
  -subj "/CN=blogapp.<region>.cloudapp.azure.com/O=Workshop/C=JP"

# Convert to PFX format (required for Application Gateway)
openssl pkcs12 -export -out cert.pfx -inkey cert.key -in cert.crt \
  -password pass:Workshop2024!

# Base64 encode for Bicep parameter
base64 -i cert.pfx | tr -d '\n' > cert-base64.txt
```

> **Note:** The certificate CN should match your expected FQDN, but for self-signed certificates, browser warnings will appear regardless. This is acceptable for workshop purposes.

### Required Parameters in `main.bicepparam`

Before deploying, edit `main.bicepparam` (or copy to `main.local.bicepparam` for personal values):

```bicep
using './main.bicep'

~~
skipped lines
~~

// ============================================================
// REQUIRED: Azure Security Parameters
// ============================================================
// SSH public key for VM access
param sshPublicKey = '<YOUR_SSH_PUBLIC_KEY>'

// Object ID of the admin user for Key Vault access
param adminObjectId = '<YOUR_ADMIN_OBJECT_ID>'

// ============================================================
// REQUIRED: Microsoft Entra ID Parameters  
// These values are injected into VMs by Bicep CustomScript
// ============================================================
// Your Azure AD tenant ID
param entraTenantId = '<YOUR_TENANT_ID>'

// Backend API app registration Client ID
param entraClientId = '<YOUR_BACKEND_CLIENT_ID>'

// Frontend SPA app registration Client ID
param entraFrontendClientId = '<YOUR_FRONTEND_CLIENT_ID>'

// ============================================================
// REQUIRED: Application Gateway SSL/TLS Configuration
// ============================================================
// Self-signed certificate (base64-encoded PFX)
// Generate with: ./scripts/generate-ssl-cert.sh
param sslCertificateData = '<CONTENTS_OF_cert-base64.txt>'

// Password for the PFX certificate
param sslCertificatePassword = 'Workshop2024!'

// Unique DNS label for Application Gateway public IP
// Results in FQDN: blogapp-<unique>.<region>.cloudapp.azure.com
param appGatewayDnsLabel = 'blogapp-<UNIQUE_SUFFIX>'
```

### Choosing Your DNS Label

The `appGatewayDnsLabel` must be **globally unique within the Azure region**. Azure will create an FQDN in the format:

```
<your-label>.<region>.cloudapp.azure.com
```

**Guidelines for choosing your DNS label:**

| Approach | Example | Result FQDN |
|----------|---------|-------------|
| Name + Random | `blogapp-john-x7k2` | `blogapp-john-x7k2.japanwest.cloudapp.azure.com` |
| Name + Date | `blogapp-tanaka-0106` | `blogapp-tanaka-0106.japanwest.cloudapp.azure.com` |
| Team + Number | `blogapp-team3` | `blogapp-team3.japanwest.cloudapp.azure.com` |

**Quick way to generate a unique suffix:**

```bash
# macOS/Linux - generate random 4-character suffix
echo "blogapp-$(openssl rand -hex 2)"
# Example output: blogapp-a3f2
```

```powershell
# Windows PowerShell - generate random 4-character suffix
"blogapp-$(-join ((48..57) + (97..102) | Get-Random -Count 4 | ForEach-Object {[char]$_}))"
# Example output: blogapp-7b2e
```

> **Important:** If deployment fails with "DNS label already in use", simply choose a different label and redeploy.

### Finding Your Values

**macOS/Linux (Azure CLI):**
```bash
# Get your Tenant ID
az account show --query tenantId -o tsv

# Get your Object ID (for Key Vault access)
az ad signed-in-user show --query id -o tsv

# List app registrations to find Client IDs
az ad app list --display-name "blogapp" --query "[].{name:displayName, appId:appId}"

# Get base64-encoded certificate (after running generate-ssl-cert.sh)
cat cert-base64.txt
```

**Windows PowerShell (Azure PowerShell):**
```powershell
# Get your Tenant ID
(Get-AzContext).Tenant.Id

# Get your Object ID (for Key Vault access)
(Get-AzADUser -SignedIn).Id

# List app registrations to find Client IDs
Get-AzADApplication -DisplayNameStartWith "blogapp" | Select-Object DisplayName, AppId

# Get base64-encoded certificate (after running generate-ssl-cert.ps1)
Get-Content cert-base64.txt
```

### Configure Redirect URIs in Entra ID (SPA Platform)

You must configure the **redirect URIs** for the frontend app registration. The redirect URI must use the Application Gateway FQDN (HTTPS).

> ⚠️ **CRITICAL**: The frontend app registration MUST use **Single-page application (SPA)** platform type - NOT "Web". MSAL.js uses the PKCE (Proof Key for Code Exchange) flow which only works with SPA platform type. Using "Web" platform will cause error: `AADSTS9002326: Cross-origin token redemption is permitted only for the 'Single-Page Application' client-type.`

> **Tip:** You can configure redirect URIs **before or after** deployment - the FQDN is predictable based on your chosen DNS label.

**Construct your Application Gateway FQDN:**

The FQDN follows a predictable format based on the `appGatewayDnsLabel` you set in `main.local.bicepparam`:

```
<appGatewayDnsLabel>.<region>.cloudapp.azure.com
```

| Your Parameter | Your FQDN |
|----------------|-----------|
| `appGatewayDnsLabel = 'blogapp-john123'` | `blogapp-john123.japanwest.cloudapp.azure.com` |
| `appGatewayDnsLabel = 'blogapp-team5'` | `blogapp-team5.japanwest.cloudapp.azure.com` |
| `location = 'eastus'` + `appGatewayDnsLabel = 'blogapp-abc'` | `blogapp-abc.eastus.cloudapp.azure.com` |

**Verify after deployment (optional):**

**macOS/Linux:**
```bash
# Confirm the FQDN matches your expectation
az network public-ip show \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv
```

**Windows PowerShell:**
```powershell
# Confirm the FQDN matches your expectation
$pip = Get-AzPublicIpAddress -ResourceGroupName <YOUR_RESOURCE_GROUP> -Name pip-agw-blogapp-prod
$pip.DnsSettings.Fqdn
```

**Update the frontend app registration with SPA redirect URIs:**

> **Note:** The `az ad app update` command does not support `--spa-redirect-uris`. You must use the Microsoft Graph API directly.

**macOS/Linux (Azure CLI with REST):**
```bash
# Replace <YOUR_FRONTEND_CLIENT_ID> with your frontend app's Client ID
# Replace <YOUR_APPGW_FQDN> with the FQDN from the command above
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='<YOUR_FRONTEND_CLIENT_ID>')" \
  --headers "Content-Type=application/json" \
  --body '{
    "spa": {
      "redirectUris": [
        "https://<YOUR_APPGW_FQDN>",
        "https://<YOUR_APPGW_FQDN>/",
        "http://localhost:5173",
        "http://localhost:5173/"
      ]
    },
    "web": {
      "redirectUris": []
    }
  }'
```

**Windows PowerShell (Microsoft Graph PowerShell):**
```powershell
# Install Microsoft Graph module if not installed
# Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All"

# Set your Frontend Client ID (from your App Registration)
$FrontendClientId = "<YOUR_FRONTEND_CLIENT_ID>"  # ← Replace with your actual value

# Set your Application Gateway FQDN
$FQDN = "<YOUR_APPGW_FQDN>"  # ← Replace with your actual value

# Get the application object
$app = Get-MgApplication -Filter "AppId eq '$FrontendClientId'"

# Update redirect URIs
$redirectUris = @(
    "https://$FQDN",
    "https://$FQDN/",
    "http://localhost:5173",
    "http://localhost:5173/"
)

Update-MgApplication -ApplicationId $app.Id -Spa @{RedirectUris = $redirectUris}

Write-Host "Redirect URIs updated successfully"
```

**Example with actual values:**
```bash
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='cc795eea-9e46-429b-990d-6c75d942ef91')" \
  --headers "Content-Type=application/json" \
  --body '{
    "spa": {
      "redirectUris": [
        "https://blogapp-12345.japanwest.cloudapp.azure.com",
        "https://blogapp-12345.japanwest.cloudapp.azure.com/",
        "http://localhost:5173",
        "http://localhost:5173/"
      ]
    },
    "web": {
      "redirectUris": []
    }
  }'
```

**Verify the SPA redirect URIs:**

**macOS/Linux:**
```bash
az ad app show --id <YOUR_FRONTEND_CLIENT_ID> --query "spa.redirectUris"
```

**Windows PowerShell:**
```powershell
$app = Get-MgApplication -Filter "AppId eq '<YOUR_FRONTEND_CLIENT_ID>'"
$app.Spa.RedirectUris
```

| Redirect URI | Purpose |
|--------------|---------|
| `https://<YOUR_APPGW_FQDN>` | Production - after MSAL login redirect |
| `https://<YOUR_APPGW_FQDN>/` | Production - with trailing slash (some browsers add this) |
| `http://localhost:5173` | Local development with Vite |
| `http://localhost:5173/` | Local development - with trailing slash |

> **Note:** HTTPS is provided by Application Gateway with a self-signed certificate. Browsers will show a certificate warning, but this is acceptable for workshop purposes. For production, use a certificate from a trusted CA or Azure Key Vault.

**Alternative: Azure Portal Method:**
1. Go to Azure Portal → Microsoft Entra ID → App registrations → Your Frontend App
2. Click **Authentication** in the left menu
3. Under "Platform configurations", verify you have **Single-page application** (NOT Web)
4. If you see "Web" platform with your URIs, delete it and add "Single-page application" instead
5. Add your redirect URIs under the SPA section
6. Click **Save**

---

## Phase 0: Deploy Infrastructure and Run Post-Deployment Script

### 0.1 Deploy Bicep Template

**macOS/Linux (Azure CLI):**
```bash
# Create resource group (choose your own name and region)
az group create --name <YOUR_RESOURCE_GROUP> --location <YOUR_REGION>

# Deploy infrastructure (initial deployment)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam

# Wait for deployment (15-30 minutes)
```

**Windows PowerShell (Azure PowerShell):**
```powershell
# Create resource group (choose your own name and region)
New-AzResourceGroup -Name <YOUR_RESOURCE_GROUP> -Location <YOUR_REGION>

# Deploy infrastructure (initial deployment)
# Note: Bicep CLI must be installed (winget install -e --id Microsoft.Bicep)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam

# Wait for deployment (15-30 minutes)
```

### 0.1.1 Re-run CustomScript on Existing VMs (Optional)

If you need to re-run CustomScript extensions on specific tiers (e.g., update NGINX config), use the **tier-specific force update tags** along with **skipVmCreation** to avoid the SSH key change error:

**macOS/Linux (Azure CLI):**
```bash
# Force re-run on Web tier only (e.g., NGINX config update)
# skipVmCreationWeb=true prevents "SSH key change not allowed" error
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationWeb=true \
               forceUpdateTagWeb="$(date +%Y%m%d%H%M%S)"

# Force re-run on App tier only (e.g., Node.js env update)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationApp=true \
               forceUpdateTagApp="$(date +%Y%m%d%H%M%S)"

# Force re-run on DB tier only (rarely needed)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationDb=true \
               forceUpdateTagDb="$(date +%Y%m%d%H%M%S)"

# Force re-run on ALL tiers (use with caution)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationWeb=true skipVmCreationApp=true skipVmCreationDb=true \
               forceUpdateTagWeb="$TIMESTAMP" \
               forceUpdateTagApp="$TIMESTAMP" \
               forceUpdateTagDb="$TIMESTAMP"
```

**Windows PowerShell (Azure PowerShell):**
```powershell
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"

# Force re-run on Web tier only (e.g., NGINX config update)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationWeb $true `
  -forceUpdateTagWeb $Timestamp

# Force re-run on App tier only (e.g., Node.js env update)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationApp $true `
  -forceUpdateTagApp $Timestamp

# Force re-run on DB tier only (rarely needed)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationDb $true `
  -forceUpdateTagDb $Timestamp

# Force re-run on ALL tiers (use with caution)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationWeb $true `
  -skipVmCreationApp $true `
  -skipVmCreationDb $true `
  -forceUpdateTagWeb $Timestamp `
  -forceUpdateTagApp $Timestamp `
  -forceUpdateTagDb $Timestamp
```

| Parameter | Purpose |
|-----------|---------|
| `skipVmCreationWeb/App/Db` | **Required for re-deployment**. Skips VM resource update, only updates extensions. Avoids "SSH key change not allowed" error. |
| `forceUpdateTagWeb/App/Db` | Changes to this value force CustomScript extension to re-run |

| Tier | forceUpdateTag | skipVmCreation | When to Use |
|------|----------------|----------------|-------------|
| Web (NGINX) | `forceUpdateTagWeb` | `skipVmCreationWeb` | Updated NGINX config, security headers |
| App (Node.js) | `forceUpdateTagApp` | `skipVmCreationApp` | Updated env vars, Node.js version |
| DB (MongoDB) | `forceUpdateTagDb` | `skipVmCreationDb` | Rarely needed (one-time setup) |

> **Important:** When VMs already exist, you MUST set `skipVmCreation*=true` for the corresponding tier. Otherwise, Azure will fail with "Changing property 'linuxConfiguration.ssh.publicKeys' is not allowed" error.

### 0.2 Prepare Post-Deployment Script

The post-deployment scripts use a **template pattern** to separate configuration from execution:

| File | Purpose | Commit to Git |
|------|---------|---------------|
| `post-deployment-setup.template.sh` | Template for macOS/Linux | ✅ Yes |
| `post-deployment-setup.template.ps1` | Template for Windows | ✅ Yes |
| `post-deployment-setup.local.sh` | Your local copy with values | ❌ No (gitignored) |
| `post-deployment-setup.local.ps1` | Your local copy with values | ❌ No (gitignored) |

**First time setup:**
```bash
# macOS/Linux
cp scripts/post-deployment-setup.template.sh scripts/post-deployment-setup.local.sh
chmod +x scripts/post-deployment-setup.local.sh
# Edit and replace placeholders with your values

# Windows PowerShell
Copy-Item scripts\post-deployment-setup.template.ps1 scripts\post-deployment-setup.local.ps1
# Edit and replace placeholders with your values
```

### 0.3 Run Post-Deployment Setup Script

**macOS/Linux:**
```bash
./scripts/post-deployment-setup.local.sh
```

**Windows PowerShell:**
```powershell
.\scripts\post-deployment-setup.local.ps1
```

**What the script does:**
1. ✅ Verifies all VMs are running
2. ✅ Waits for CustomScript extensions to complete
3. ✅ Initializes MongoDB replica set (`blogapp-rs0`)
4. ✅ Creates admin user (`blogadmin`)
5. ✅ Creates application user (`blogapp`)
6. ✅ Verifies environment variables on App tier
7. ✅ Verifies `config.json` on Web tier

### 0.4 Verify Config Injection (Already done by script, but for manual check)

#### Connect to VMs via Azure Bastion (Native SSH Client)

Use Azure CLI to connect to VMs via Bastion with your native SSH client:

**macOS/Linux (Azure CLI):**

**Connect to App tier VMs:**
```bash
# Connect to vm-app-az1-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-app-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# Connect to vm-app-az2-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-app-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

**Connect to Web tier VMs:**
```bash
# Connect to vm-web-az1-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# Connect to vm-web-az2-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

> **Note:** Replace `~/.ssh/id_rsa` with the path to your private SSH key that corresponds to the public key used during deployment.

**Windows PowerShell (Azure PowerShell) - Using Invoke-AzVMRunCommand:**

> **Note:** Windows users can use `Invoke-AzVMRunCommand` to execute commands on VMs without Bastion SSH. This is the recommended approach for PowerShell users.

```powershell
$ResourceGroup = "<YOUR_RESOURCE_GROUP>"

# Run command on App tier VM (vm-app-az1-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /etc/environment | grep -E '(AZURE_|NODE_ENV|PORT)'; cat /opt/blogapp/.env"

# Run command on App tier VM (vm-app-az2-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /etc/environment | grep -E '(AZURE_|NODE_ENV|PORT)'; cat /opt/blogapp/.env"

# Run command on Web tier VM (vm-web-az1-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /var/www/html/config.json"

# Run command on Web tier VM (vm-web-az2-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /var/www/html/config.json"
```

#### Verify Config on VMs

**On App tier VMs:**
```bash
# Check environment variables
cat /etc/environment | grep -E "(AZURE_|NODE_ENV|PORT)"
cat /opt/blogapp/.env
```

Expected output:
```
NODE_ENV=production
PORT=3000
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**On Web tier VMs:**
```bash
# Check config.json
cat /var/www/html/config.json
```

Expected output:
```json
{
  "VITE_ENTRA_CLIENT_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "VITE_ENTRA_TENANT_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "VITE_API_BASE_URL": ""
}
```

---

## Phase 1: Database Tier Configuration (AUTOMATED)

> **Note:** This phase is now fully automated by `post-deployment-setup.local.sh` / `post-deployment-setup.local.ps1`. The sections below are kept for reference and manual troubleshooting.

### 1.1 Verify Pre-installed MongoDB

**On both DB VMs - Verification only (no installation needed):**

```bash
# Check MongoDB is running
sudo systemctl status mongod

# Check MongoDB version
mongod --version

# Check data disk mount
df -h /data/mongodb

# Check MongoDB logs
sudo tail -20 /data/mongodb/log/mongod.log
```

### 1.2 Check Replica Set Status (BEFORE Initialization)

**On `vm-db-az1-prod` - Check if replica set is already initialized:**

```bash
# Check replica set status
mongosh --eval 'rs.status()' 2>&1
```

**Expected outputs and actions:**

| Output | Meaning | Action |
|--------|---------|--------|
| `"ok" : 1` with members list | Already initialized | Skip to 1.3 (user creation) |
| `MongoServerError: no replset config` | Not initialized | Execute 1.2.1 |
| `NotYetInitialized` | Not initialized | Execute 1.2.1 |

### 1.2.1 Initialize Replica Set (ONLY IF NOT INITIALIZED)

**Execute ONLY if rs.status() shows "no replset config" or "NotYetInitialized":**

```bash
# Initialize replica set (ONE TIME ONLY)
mongosh --eval '
rs.initiate({
  _id: "blogapp-rs0",
  members: [
    { _id: 0, host: "10.0.3.4:27017", priority: 2 },
    { _id: 1, host: "10.0.3.5:27017", priority: 1 }
  ]
})
'

# Wait for replica set to elect primary (about 10-20 seconds)
sleep 20

# Verify replica set status
mongosh --eval 'rs.status()'
```

### 1.3 Check/Create Application User (AUTOMATED)

> **Note:** User creation is now automated by `post-deployment-setup.local.sh` / `post-deployment-setup.local.ps1`.

**Manual verification if needed:**

```bash
# Check if blogapp user exists
mongosh admin --eval 'db.getUsers()' 2>&1 | grep -q "blogapp"
echo $?  # 0 = exists, 1 = not exists
```

**Create user ONLY if not exists:**

```javascript
// Connect to primary
mongosh

// Switch to admin database
use admin

// Check existing users
db.getUsers()

// Create user ONLY if not in the list above
db.createUser({
  user: "blogapp",
  pwd: "BlogApp2024Workshop",  // Change for production
  roles: [
    { role: "readWrite", db: "blogapp" }
  ]
})
```

### 1.4 Verification

```bash
# Test connection with credentials
mongosh "mongodb://blogapp:BlogApp2024Workshop!@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=admin" --eval 'db.runCommand({ping:1})'
```

---

## Phase 2: Backend Tier Deployment

> **Important:** Environment variables are now automatically injected by Bicep. You only need to deploy application code.

### 2.1 Verify Pre-installed Node.js/PM2 and Environment

**On both App VMs - Verification only:**

```bash
# Check Node.js version (should be v20.x)
node --version

# Check PM2
pm2 --version
pm2 list

# Check application directory
ls -la /opt/blogapp/

# Verify environment variables (NEW - injected by Bicep)
cat /opt/blogapp/.env
# Should show: NODE_ENV, PORT, AZURE_TENANT_ID, AZURE_CLIENT_ID
```

### 2.2 Clean Up Placeholder Health Server

The Bicep CustomScript starts a placeholder health server. After deploying the real application, this process will be in "errored" state (port conflict). Clean it up:

```bash
# Check PM2 status - you may see blogapp-health in "errored" state
pm2 list

# Delete the placeholder health server (safe to run even if not present)
pm2 delete blogapp-health 2>/dev/null || true

# Save PM2 process list
pm2 save
```

### 2.3 Deploy Application Code

**Option A: Clone from Git (Easy method, if repo is accessible):**

```bash
cd /opt/blogapp
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp
cp -r temp/materials/backend/* ./
rm -rf temp
```

**Option B: Upload via Bastion tunnel:**

**macOS/Linux (Azure CLI):**
```bash
# On local machine - create tunnel
az network bastion tunnel \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id <VM_RESOURCE_ID> \
  --resource-port 22 \
  --port 2222

# In another terminal - SCP through tunnel
scp -P 2222 -r ./materials/backend/* azureuser@127.0.0.1:/opt/blogapp/
```

**Windows PowerShell (Azure PowerShell) - Using Invoke-AzVMRunCommand:**
```powershell
$ResourceGroup = "<YOUR_RESOURCE_GROUP>"

# Since Bastion tunnel is not available in pure PowerShell, use Invoke-AzVMRunCommand
# to clone and deploy directly from the VM (Option A approach)

# Deploy backend to vm-app-az1-prod
$deployScript = @'
cd /opt/blogapp
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp
cp -r temp/materials/backend/* ./
rm -rf temp
npm ci --include=dev
npm run build
pm2 delete blogapp-health 2>/dev/null || true
pm2 start dist/src/app.js --name blogapp-api
pm2 save
'@

Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript

# Repeat for vm-app-az2-prod
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript
```

### 2.4 Install Dependencies and Build

**On both App VMs:**

```bash
cd /opt/blogapp

# Install all dependencies including devDependencies (TypeScript compiler)
# Note: --include=dev is required because NODE_ENV=production is set in /etc/environment,
# which causes npm to skip devDependencies by default
npm ci --include=dev

# Build TypeScript
npm run build
```

> **Why `--include=dev`?** The Bicep CustomScript sets `NODE_ENV=production` in `/etc/environment`. When `NODE_ENV=production`, npm automatically skips `devDependencies` during install. Since TypeScript is a devDependency needed for compilation, we must explicitly include it.

### 2.5 Verify MongoDB Connection String

> **Note:** The MongoDB connection string is now automatically injected by Bicep. This step is for verification only.

**Verify `/opt/blogapp/.env` contains MONGODB_URI:**

```bash
# Verify complete .env file
cat /opt/blogapp/.env
```

Expected `.env` (all values injected by Bicep):
```env
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
MONGODB_URI=mongodb://blogapp:BlogApp2024Workshop!@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=admin
ENTRA_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENTRA_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

> **If MONGODB_URI is missing or incorrect:** Check that `mongoDbUri` parameter is set in your `main.local.bicepparam` file and redeploy, or manually append:
> ```bash
> echo 'MONGODB_URI=mongodb://blogapp:BlogApp2024Workshop@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=admin' | sudo tee -a /opt/blogapp/.env
> ```

### 2.6 Start Application with PM2

```bash
cd /opt/blogapp

# Start application
# Note: Output is in dist/src/ because tsconfig.json has rootDir="." and includes both src/ and scripts/
pm2 start dist/src/app.js --name blogapp-api

# Save PM2 process list
pm2 save

# Verify running
pm2 list
pm2 logs blogapp-api --lines 20
```

### 2.7 Health Check Verification

```bash
# Test local health endpoint
curl http://localhost:3000/health

# Test from other VM (via Internal LB IP)
curl http://10.0.2.10:3000/health
```

---

## Phase 3: Frontend Tier Deployment

> **Important:** The frontend now uses runtime configuration via `/config.json` (already created by Bicep). No build-time environment variables needed!

### 3.1 Verify Pre-installed NGINX and Config

**On both Web VMs - Verification only:**

```bash
# Check NGINX is running
sudo systemctl status nginx
nginx -v

# Check current configuration
sudo nginx -T

# Test current health endpoint
curl http://localhost/health

# Verify config.json exists (NEW - created by Bicep)
cat /var/www/html/config.json
# Should show: VITE_ENTRA_CLIENT_ID, VITE_ENTRA_TENANT_ID, VITE_API_BASE_URL
```

### 3.2 Deploy Static Files

**Option A: Clone from Git and build on VM (recommended - uses NAT Gateway for outbound):**

```bash
cd /tmp

# Clone repository (NAT Gateway provides outbound internet access)
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp

# Install Node.js for build (if not already installed on Web tier)
# Note: Web tier VMs have NGINX but not Node.js by default
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Build frontend
cd temp/materials/frontend
npm ci
npm run build

# Deploy to web root (preserve existing config.json!)
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/

# Cleanup
cd /tmp && rm -rf temp
```

**Option B: Build locally and upload via Bastion tunnel:**

> **First, build on your local machine:**
> ```bash
> cd materials/frontend
> npm ci
> npm run build
> # Build output will be in dist/
> ```

**macOS/Linux (Azure CLI):**
```bash
# Create tunnel to vm-web-az1-prod
az network bastion tunnel \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id /subscriptions/.../vm-web-az1-prod \
  --resource-port 22 \
  --port 2222

# Upload files (IMPORTANT: preserve existing config.json!)
scp -P 2222 -r ./materials/frontend/dist/* azureuser@127.0.0.1:/tmp/frontend/

# On VM - move to web root but preserve config.json
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r /tmp/frontend/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/
```

**Windows PowerShell (Azure PowerShell) - Using Invoke-AzVMRunCommand:**
```powershell
$ResourceGroup = "<YOUR_RESOURCE_GROUP>"

# Deploy frontend via VM (clone, build, deploy - uses NAT Gateway)
$deployScript = @'
cd /tmp
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp

# Install Node.js for build (if not already installed on Web tier)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Build frontend
cd temp/materials/frontend
npm ci
npm run build

# Deploy to web root (preserve existing config.json!)
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/

# Cleanup
cd /tmp && rm -rf temp
'@

# Deploy to vm-web-az1-prod
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript

# Deploy to vm-web-az2-prod
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript
```

### 3.3 Verify NGINX Configuration (AUTOMATED)

> **Note:** NGINX is now **fully configured by Bicep** with:
> - Internal Load Balancer proxy (`10.0.2.10:3000`)
> - Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
> - Gzip compression
> - Static asset caching
> - SPA routing
>
> **No manual configuration needed!**

**Verify the configuration:**

```bash
# Check that API proxy is using Internal Load Balancer
grep "proxy_pass" /etc/nginx/sites-available/default
# Expected: proxy_pass http://10.0.2.10:3000;

# Test NGINX configuration syntax
sudo nginx -t

# Reload if needed (only if you made changes)
sudo systemctl reload nginx
```

<details>
<summary>📋 Full NGINX configuration (for reference)</summary>

This is automatically created by Bicep. You should NOT need to modify it.

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml;

    # Health check endpoint for Load Balancer
    location /health {
        access_log off;
        return 200 'healthy\n';
        add_header Content-Type text/plain;
    }

    # Serve static files (React frontend) with SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to Internal Load Balancer (10.0.2.10)
    location /api/ {
        proxy_pass http://10.0.2.10:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

</details>

### 3.4 Verification

```bash
# Test NGINX health endpoint (returns "healthy" from NGINX itself)
curl http://localhost/health

# Test API proxy to backend (use /api/posts, not /api/health)
# Note: Backend health is at /health, not /api/health
# NGINX proxies /api/* to backend /api/* - backend doesn't have /api/health route
curl http://localhost/api/posts
# Expected: JSON array of posts (may be empty)

# Test that SPA routing works (should return index.html for any frontend route)
curl -s http://localhost/login | head -5
# Expected: <!doctype html>...
```

---

## Phase 4: End-to-End Verification

> **Note:** Application Gateway is **fully automated by Bicep** - no manual setup required! It provides:
> - SSL/TLS termination with your self-signed certificate
> - HTTP→HTTPS redirect (port 80 → port 443)
> - Health probes to Web tier VMs
> - Azure DNS label for predictable FQDN

### 4.1 Health Check Matrix

| Endpoint | Expected | Command |
|----------|----------|---------|
| DB Primary | RS Primary | `mongosh 10.0.3.4 --eval 'rs.isMaster().ismaster'` |
| DB Secondary | RS Secondary | `mongosh 10.0.3.5 --eval 'rs.isMaster().secondary'` |
| Backend VM1 | `{"status":"healthy"}` | `curl http://10.0.2.5:3000/health` |
| Backend VM2 | `{"status":"healthy"}` | `curl http://10.0.2.4:3000/health` |
| Internal LB | `{"status":"healthy"}` | `curl http://10.0.2.10:3000/health` |
| Frontend VM1 (NGINX) | `healthy` | `curl http://10.0.1.4/health` |
| Frontend VM2 (NGINX) | `healthy` | `curl http://10.0.1.5/health` |
| Application Gateway (HTML) | HTML page | `curl -k https://<YOUR_APPGW_FQDN>/` |
| Application Gateway (API) | JSON array | `curl -k https://<YOUR_APPGW_FQDN>/api/posts` |

> **Note:** Backend health endpoint is at `/health`, not `/api/health`. The NGINX proxy maps `/api/*` to backend `/api/*`, so `/api/health` would try to reach a non-existent backend route. Use `/api/posts` to verify end-to-end API connectivity.

### 4.2 Verify Application Gateway

**Get your Application Gateway FQDN:**

**macOS/Linux:**
```bash
# Get the FQDN
az network public-ip show \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv
```

**Windows PowerShell:**
```powershell
# Get the FQDN
$pip = Get-AzPublicIpAddress -ResourceGroupName <YOUR_RESOURCE_GROUP> -Name pip-agw-blogapp-prod
$pip.DnsSettings.Fqdn
```

**Test HTTPS access (with self-signed certificate):**

**macOS/Linux:**
```bash
# Test via FQDN (use -k to skip certificate verification for self-signed cert)
curl -k https://<YOUR_APPGW_FQDN>/

# Test HTTP→HTTPS redirect (should return 301/302)
curl -I http://<YOUR_APPGW_FQDN>/

# Test API endpoint through Application Gateway
# Note: Use /api/posts (not /api/health) - backend health is at /health, not /api/health
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**Windows PowerShell:**
```powershell
# Test via FQDN (skip certificate verification for self-signed cert)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Test HTTPS access
Invoke-RestMethod -Uri "https://<YOUR_APPGW_FQDN>/" -SkipCertificateCheck

# Test API endpoint through Application Gateway
Invoke-RestMethod -Uri "https://<YOUR_APPGW_FQDN>/api/posts" -SkipCertificateCheck

# Test HTTP→HTTPS redirect
Invoke-WebRequest -Uri "http://<YOUR_APPGW_FQDN>/" -MaximumRedirection 0 -ErrorAction SilentlyContinue
```

**Access in browser:**
1. Open `https://<YOUR_APPGW_FQDN>/` in your browser
2. Accept the self-signed certificate warning (expected for workshop)
3. You should see the blog application login page

### 4.3 Application Test

```bash
# Test full stack via Application Gateway FQDN
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

---

## Deployment Checklist (Revised)

### Pre-Deployment Configuration
- [ ] `main.local.bicepparam` created with your values
- [ ] `sshPublicKey` parameter set
- [ ] `adminObjectId` parameter set
- [ ] `entraTenantId` parameter set
- [ ] `entraClientId` (backend) parameter set
- [ ] `entraFrontendClientId` parameter set

### Infrastructure Deployment (Phase 0)
- [ ] Resource group created
- [ ] Bicep deployment completed
- [ ] **Redirect URIs configured in Entra ID** (requires public IP from deployment)
- [ ] Post-deployment script template copied to `.local` version
- [ ] Post-deployment script configured with your values
- [ ] Post-deployment script executed successfully
- [ ] MongoDB replica set initialized (automated)
- [ ] MongoDB users created (automated)
- [ ] App tier env vars verified (automated)
- [ ] Web tier config.json verified (automated)

### Backend Tier (Code Deployment Only)
- [ ] ~~Node.js installed~~ (Bicep)
- [ ] ~~PM2 installed~~ (Bicep)
- [ ] ~~Environment variables configured~~ (Bicep - except MongoDB URI)
- [ ] Placeholder health server stopped
- [ ] Application code deployed
- [ ] Dependencies installed (`npm ci`)
- [ ] TypeScript built (`npm run build`)
- [ ] MongoDB connection string added to .env
- [ ] PM2 process running
- [ ] Health check passing

### Frontend Tier (Static Files Only)
- [ ] ~~NGINX installed~~ (Bicep)
- [ ] ~~config.json created~~ (Bicep)
- [ ] Frontend built locally (no env vars needed!)
- [ ] Static files uploaded (preserve config.json!)
- [ ] NGINX config verified
- [ ] Health check passing
- [ ] API proxy working

---

## Estimated Deployment Time (Revised)

| Phase | Duration | Notes |
|-------|----------|-------|
| Bicep Deployment | 15-30 min | Full infrastructure provisioning |
| Post-Deployment Script | 2-5 min | Automated MongoDB setup |
| Backend Deployment | 5-10 min | Code upload + build + start (env vars pre-configured!) |
| Frontend Deployment | 5-10 min | Build + upload only (no env config needed!) |
| Verification | 5-10 min | All tiers |
| **Total** | **30-65 min** | Mostly infrastructure provisioning time |

---

## Key Improvements in This Strategy

| Previous Approach | Current Approach |
|-------------------|------------------|
| Manually create `.env` files with Entra IDs | Bicep injects env vars automatically |
| Build frontend with `.env.production` | Frontend fetches `/config.json` at runtime |
| Manual MongoDB replica set initialization | Automated via post-deployment scripts |
| Manual MongoDB user creation | Automated via post-deployment scripts |
| Students edit multiple config files | Students only edit `main.bicepparam` |
| Single-platform scripts | Cross-platform (Bash + PowerShell) |
| Hardcoded values in scripts | Template pattern with `.local` copies (gitignored) |

### Technical Implementation Details

**Bicep Script Injection Pattern:**
- External shell scripts stored in `modules/compute/scripts/`
- `loadTextContent()` loads script content at deployment time
- `replace()` chains substitute `__PLACEHOLDER__` values with Bicep parameters
- Avoids ARM `format()` function issues with bash/JSON curly braces

**Post-Deployment Script Template Pattern:**
- Template files (`*.template.sh`, `*.template.ps1`) committed to repo
- Local copies (`*.local.sh`, `*.local.ps1`) created by user with their values
- `.gitignore` excludes `*.local.sh` and `*.local.ps1` to protect credentials

### Benefits for Workshop

1. **Single Point of Configuration**: All Azure-specific values in `main.bicepparam`
2. **No Rebuild Required**: Change Entra IDs by redeploying Bicep, not rebuilding apps
3. **Automated Database Setup**: One script handles all MongoDB configuration
4. **Verification Built-in**: Post-deployment script verifies all config injection
5. **Cross-Platform Support**: Workshop students on Windows or macOS/Linux can use native scripts

---

## Automation Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/post-deployment-setup.template.sh` | Template for MongoDB setup + verification (macOS/Linux) | Copy to `.local.sh`, edit placeholders |
| `scripts/post-deployment-setup.template.ps1` | Template for MongoDB setup + verification (Windows) | Copy to `.local.ps1`, edit placeholders |
| `scripts/post-deployment-setup.local.sh` | Your configured script (macOS/Linux) | `./scripts/post-deployment-setup.local.sh` |
| `scripts/post-deployment-setup.local.ps1` | Your configured script (Windows) | `.\scripts\post-deployment-setup.local.ps1` |

### Script Configuration Placeholders

| Placeholder | Description | Example Value |
|-------------|-------------|---------------|
| `<RESOURCE_GROUP>` | Azure resource group name | `rg-blogapp-prod` |
| `<BASTION_NAME>` | Bastion host name | `bastion-blogapp-prod` |
| `<MONGODB_ADMIN_PASSWORD>` | Admin user password | `AdminP@ss2024!` |
| `<MONGODB_APP_PASSWORD>` | App user password | `BlogApp2024Workshop!` |

---

## Troubleshooting

### Config Injection Issues

**App tier env vars not set:**
```bash
# Re-run CustomScript extension
az vm run-command invoke --resource-group <YOUR_RESOURCE_GROUP> \
  --name vm-app-az1-prod --command-id RunShellScript \
  --scripts "cat /opt/blogapp/.env"
```

**Web tier config.json missing:**
```bash
# Check if file exists
az vm run-command invoke --resource-group <YOUR_RESOURCE_GROUP> \
  --name vm-web-az1-prod --command-id RunShellScript \
  --scripts "cat /var/www/html/config.json"
```

### MongoDB Issues

**Replica set not initialized:**
```bash
# macOS/Linux - Run post-deployment script again
./scripts/post-deployment-setup.local.sh

# Windows
.\scripts\post-deployment-setup.local.ps1
```

**Users not created:**
```bash
# Script will skip if already exists, safe to re-run
./scripts/post-deployment-setup.local.sh  # macOS/Linux
.\scripts\post-deployment-setup.local.ps1  # Windows
```

### Bicep Template Curly Brace Issues

If you see ARM errors like "Input string was not in a correct format" when modifying CustomScript extensions:

**Problem:** ARM's `format()` function treats `{` not followed by a digit as invalid placeholders.

**Solution:** Use external script files with `loadTextContent()` and `replace()`:
```bicep
// Instead of format() with embedded scripts:
var scriptContent = loadTextContent('scripts/my-script.sh')
var finalScript = replace(
  replace(scriptContent, '__PLACEHOLDER1__', param1),
  '__PLACEHOLDER2__', param2
)
```

See `modules/compute/scripts/nginx-install.sh` and `nodejs-install.sh` for examples.

---

## Architecture Reference

See also:
- [AzureArchitectureDesign.md](../../design/AzureArchitectureDesign.md) - Infrastructure design and parameter flow
- [FrontendApplicationDesign.md](../../design/FrontendApplicationDesign.md) - Runtime config pattern details
- [BackendApplicationDesign.md](../../design/BackendApplicationDesign.md) - Backend environment configuration

---

## Appendix: Deployment Verification Commands

### Infrastructure Deployment

```
Resource Group: <YOUR_RESOURCE_GROUP>
Location: <YOUR_REGION>
Deployment Status: (check after deployment)
```

### Config Injection Verification (via az vm run-command)

**App Tier VMs - `/opt/blogapp/.env`:**

| VM | NODE_ENV | PORT | AZURE_TENANT_ID | AZURE_CLIENT_ID |
|----|----------|------|-----------------|-----------------|
| vm-app-az1-prod | production | 3000 | ✅ Injected | ✅ Injected |
| vm-app-az2-prod | production | 3000 | ✅ Injected | ✅ Injected |

**Web Tier VMs - `/var/www/html/config.json`:**

| VM | VITE_ENTRA_CLIENT_ID | VITE_ENTRA_TENANT_ID | VITE_API_BASE_URL |
|----|----------------------|----------------------|-------------------|
| vm-web-az1-prod | ✅ Injected | ✅ Injected | "" (relative) |
| vm-web-az2-prod | ✅ Injected | ✅ Injected | "" (relative) |

### Verification Commands

```bash
# App tier verification
az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-app-az1-prod \
  --command-id RunShellScript --scripts "cat /opt/blogapp/.env"

az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-app-az2-prod \
  --command-id RunShellScript --scripts "cat /opt/blogapp/.env"

# Web tier verification
az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod \
  --command-id RunShellScript --scripts "cat /var/www/html/config.json"

az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-web-az2-prod \
  --command-id RunShellScript --scripts "cat /var/www/html/config.json"
```

### Remaining Tasks

1. **Run post-deployment script** to initialize MongoDB replica set
2. **Deploy backend application code** to App tier VMs
3. **Deploy frontend static files** to Web tier VMs
