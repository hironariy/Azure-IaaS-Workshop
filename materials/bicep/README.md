# Azure IaaS Workshop - Bicep Infrastructure Templates

> **Learner path:** This file is a technical reference for the Bicep templates. Workshop learners should follow the Japanese Cloud Shell-first flow in [`materials/docs/learner/learner-quickstart.ja.md`](../docs/learner/learner-quickstart.ja.md), [`materials/docs/learner/day-1-deployment-checklist.ja.md`](../docs/learner/day-1-deployment-checklist.ja.md), and [`materials/docs/learner/day-1-app-deployment.ja.md`](../docs/learner/day-1-app-deployment.ja.md). Local Azure CLI, Bicep CLI, and OpenSSL installation are not required for the standard learner path because Azure Cloud Shell provides the required tools.

This directory contains the Bicep Infrastructure as Code (IaC) templates for deploying the Azure IaaS Workshop infrastructure.

## 🎯 Overview

These templates deploy a highly available, 3-tier blog application infrastructure:

| Tier | Components | VM Size | Availability |
|------|-----------|---------|-------------|
| **Web** | 2 × NGINX reverse proxy VMs | Standard_D2s_v6 | Zone 1 & 2 |
| **App** | 2 × Node.js/Express VMs | Standard_D2s_v6 | Zone 1 & 2 |
| **DB** | 3 × MongoDB VMs (replica set, no arbiter) | Standard_D4s_v6 | Zone 1, 2 & 3 |

### Architecture Highlights

- **High Availability**: VMs distributed across 2 Availability Zones
- **HTTPS by Default**: Application Gateway with SSL/TLS termination (self-signed certificate)
- **Security**: No public IPs on VMs, Azure Bastion for secure access
- **Monitoring**: Azure Monitor with Log Analytics and Data Collection Rules
- **Secrets**: Azure Key Vault with Managed Identity integration
- **Load Balancing**: Application Gateway (Layer 7) + Internal Load Balancer (App tier)

## 🚀 Quick Start - Deploy to Azure

Click the button below to deploy the infrastructure directly to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYOUR_ORG%2FAzureIaaSWorkshop%2Fmain%2Fmaterials%2Fbicep%2Fmain.bicep)

> **Note**: Update the URL above with your actual GitHub repository path after pushing the code.

## 📋 Prerequisites

### Required Tools

1. **Azure CLI** (2.40+)
   ```bash
   # macOS
   brew install azure-cli
   
   # Windows
   winget install Microsoft.AzureCLI
   
   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **Bicep CLI** (included with Azure CLI 2.20+)
   ```bash
   # Verify installation
   az bicep version
   
   # Install/upgrade if needed
   az bicep install
   ```

### Azure Requirements

- Active Azure subscription
- **Owner** (recommended), or **Contributor + User Access Administrator**, on the subscription or resource group. The Key Vault module creates role assignments (`Microsoft.Authorization/roleAssignments/write`), which Contributor alone cannot do.
- Contributor only: set `assignKeyVaultRoles = false` (Key Vault is created without role assignments; the app does not read Key Vault at runtime). In ASR, manage extension updates manually.
- Sufficient quota for:
  - 7 VMs (20 Dsv6-family and total regional vCPUs; the DB size must be available in zones 1, 2 and 3)
  - 10 managed disks (7 OS disks + 3 MongoDB data disks)
  - 1 public IP address
  - 1 Application Gateway v2
  - 1 Internal Load Balancer
  - 1 Azure Bastion (optional)

### Prepare SSH Key

Generate an SSH key pair if you don't have one:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure-workshop -C "azure-workshop"
```

### Generate SSL Certificate for Application Gateway

Generate a self-signed SSL certificate for HTTPS termination:

**macOS/Linux:**
```bash
# From repository root
./scripts/generate-ssl-cert.sh

# Output files:
# - cert.pfx (for Application Gateway)
# - cert-base64.txt (for Bicep parameter)
```

**Windows PowerShell:**
```powershell
# From repository root
.\scripts\generate-ssl-cert.ps1

# Copy to clipboard for easy pasting
Get-Content cert-base64.txt | Set-Clipboard
```

> **Note:** Self-signed certificates will cause browser warnings. This is expected for workshop purposes.

## 📦 Deployment Options

### Option 1: Azure CLI (Recommended)

```bash
# 1. Login to Azure
az login

# 2. Set your subscription
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# 3. Create a resource group
az group create --name rg-blogapp-prod --location japaneast

# 4. Get your Azure AD Object ID (for Key Vault access)
ADMIN_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# 5. Deploy the infrastructure
az deployment group create \
  --resource-group rg-blogapp-prod \
  --template-file main.bicep \
  --parameters \
    sshPublicKey="$(cat ~/.ssh/azure-workshop.pub)" \
    adminObjectId="$ADMIN_OBJECT_ID" \
    entraTenantId="$(az account show --query tenantId -o tsv)" \
    entraClientId="<YOUR_BACKEND_API_CLIENT_ID>" \
    entraFrontendClientId="<YOUR_FRONTEND_SPA_CLIENT_ID>" \
    environment="prod"

# 6. Get deployment outputs
az deployment group show \
  --resource-group rg-blogapp-prod \
  --name main \
  --query properties.outputs -o json
```

### Option 2: Parameter File Deployment (Workshop Recommended)

**Important**: The parameter files contain personal Azure identifiers. Use the following pattern:

| File | Purpose | Git Status |
|------|---------|------------|
| `main.bicepparam` | **Template** - Empty values, shows required params | ✅ Committed |
| `main.local.bicepparam` | **Your values** - Personal development | ❌ Gitignored |

```bash
# Step 1: Create your local parameter file (first time only)
cp main.bicepparam main.local.bicepparam

# Step 2: Edit main.local.bicepparam with your values
# - sshPublicKey          (SSH public key for VM access)
# - adminObjectId         (Your Azure AD Object ID)
# - entraTenantId         (Microsoft Entra tenant ID)
# - entraClientId         (Backend API app registration)
# - entraFrontendClientId (Frontend SPA app registration)
# - sslCertificateData    (Contents of cert-base64.txt)
# - sslCertificatePassword (Certificate password: Workshop2024!)
# - appGatewayDnsLabel    (Unique DNS label, e.g., blogapp-yourname)

# Step 3: Deploy using YOUR local parameters
az deployment group create \
  --resource-group rg-blogapp-prod \
  --template-file main.bicep \
  --parameters main.local.bicepparam
```

> **Security Note**: `*.local.bicepparam` files are gitignored to prevent accidentally committing your personal Azure identifiers to a public repository.

### Option 3: Azure Portal

1. Navigate to Azure Portal → Create a resource → "Template deployment"
2. Select "Build your own template in the editor"
3. Copy the contents of `main.bicep`
4. Fill in the required parameters
5. Click "Review + Create"

## 📁 Module Structure

```
materials/bicep/
├── main.bicep              # Main orchestrator template
├── main.bicepparam         # Production parameters
├── dev.bicepparam          # Development parameters (lower cost)
└── modules/
    ├── network/
    │   ├── vnet.bicep              # Virtual Network with 5 subnets
    │   ├── nsg-web.bicep           # Web tier NSG (HTTP from App Gateway)
    │   ├── nsg-app.bicep           # App tier NSG (port 3000 from web)
    │   ├── nsg-db.bicep            # DB tier NSG (MongoDB from app)
    │   ├── bastion.bicep           # Azure Bastion for secure VM access
    │   ├── application-gateway.bicep # App Gateway with SSL termination
    │   └── internal-load-balancer.bicep # Internal LB for app tier
    ├── compute/
    │   ├── vm.bicep            # Reusable VM module
    │   ├── web-tier.bicep      # 2 NGINX VMs
    │   ├── app-tier.bicep      # 2 Express/Node.js VMs
    │   └── db-tier.bicep       # 3 MongoDB VMs (Zones 1-3) with data disks
    ├── monitoring/
    │   ├── log-analytics.bicep # Log Analytics workspace
    │   └── data-collection-rule.bicep # DCR for VM telemetry
    ├── security/
    │   └── key-vault.bicep     # Key Vault with RBAC
    └── storage/
        └── storage-account.bicep # Storage for static assets
```

## ⚙️ Parameters

### Required Parameters

| Parameter | Description | How to Get |
|-----------|-------------|------------|
| `sshPublicKey` | SSH public key for VM authentication | `cat ~/.ssh/id_rsa.pub` |
| `adminObjectId` | Azure AD Object ID for Key Vault access | `az ad signed-in-user show --query id -o tsv` |
| `entraTenantId` | Microsoft Entra tenant ID | `az account show --query tenantId -o tsv` |
| `entraClientId` | Backend API app registration client ID | Azure Portal → App registrations → Backend API |
| `entraFrontendClientId` | Frontend SPA app registration client ID | Azure Portal → App registrations → Frontend SPA |
| `sslCertificateData` | Base64-encoded PFX certificate | `cat cert-base64.txt` (after running generate script) |
| `sslCertificatePassword` | Password for the PFX certificate | Default: `Workshop2024!` |
| `appGatewayDnsLabel` | Unique DNS label for Application Gateway | Choose unique value, e.g., `blogapp-yourname123` |

#### Choosing Your DNS Label

The `appGatewayDnsLabel` must be **globally unique within your Azure region**. It creates an FQDN:

```
<your-label>.<region>.cloudapp.azure.com
```

**Examples:**
- `blogapp-john123` → `blogapp-john123.japanwest.cloudapp.azure.com`
- `blogapp-team5` → `blogapp-team5.japanwest.cloudapp.azure.com`

**Generate a random suffix:**
```bash
# macOS/Linux
echo "blogapp-$(openssl rand -hex 2)"  # e.g., blogapp-a3f2
```

```powershell
# Windows PowerShell
"blogapp-$(-join ((48..57) + (97..102) | Get-Random -Count 4 | ForEach-Object {[char]$_}))"
```

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `location` | Resource group location | Azure region |
| `environment` | `prod` | Environment name (prod, dev, test) |
| `workloadName` | `blogapp` | Workload identifier for naming |
| `adminUsername` | `azureuser` | VM admin username |
| `deployBastion` | `true` | Deploy Azure Bastion |
| `deployMonitoring` | `true` | Deploy Log Analytics & DCR |
| `deployKeyVault` | `true` | Deploy Key Vault |
| `assignKeyVaultRoles` | `true` | Create Key Vault role assignments; `false` for Contributor-only users |
| `deployStorage` | `true` | Deploy Storage Account |
| `webVmSize` | `Standard_D2s_v6` | Web tier VM size |
| `appVmSize` | `Standard_D2s_v6` | App tier VM size |
| `dbVmSize` | `Standard_D4s_v6` | DB tier VM size |
| `dbDataDiskSizeGB` | `128` | MongoDB data disk size |
| `skipVmCreationDb` | `false` | Reuse existing `vm-db-az1`/`vm-db-az2` (update extensions only) |
| `skipVmCreationDbAz3` | `skipVmCreationDb` | Reuse existing `vm-db-az3`. Set `skipVmCreationDb=true` + `skipVmCreationDbAz3=false` to add only the 3rd DB VM to an existing 2-node environment (Issue #30) |

## 💰 Cost Estimation

### Production Configuration

Estimate the cost of four `Standard_D2s_v6` and three `Standard_D4s_v6` VMs (the 3rd DB VM adds one D4s_v6 plus one 128 GB Premium SSD data disk per environment, Issue #30) in Japan West, plus disks, Application Gateway, Bastion, monitoring, and networking, with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) before running the workshop. The previous Basv2-based daily estimate does not apply to Dsv6. Check both regional and Dsv6-family vCPU quotas using the [Day 0 prerequisites](../docs/learner/day-0-prerequisites.ja.md); quota does not guarantee capacity in each zone.

### Development Configuration

Use `dev.bicepparam` to disable Bastion, Key Vault, and Storage for development; it specifies a separate, smaller VM configuration from the production Dsv6 parameters.

## 🔍 Post-Deployment Steps

After deployment completes, perform these steps:

### 1. Verify Deployment

```bash
# List all deployed resources
az resource list --resource-group rg-blogapp-prod -o table

# Get VM information
az vm list --resource-group rg-blogapp-prod -o table
```

### 2. Connect to VMs via Bastion

1. Go to Azure Portal → Virtual Machines → Select a VM
2. Click "Connect" → "Bastion"
3. Enter username `azureuser` and upload your private key

Or via CLI:
```bash
az network bastion ssh \
  --name bast-blogapp-prod \
  --resource-group rg-blogapp-prod \
  --target-resource-id <VM_RESOURCE_ID> \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/azure-workshop
```

### 3. Initialize MongoDB Replica Set

Normally `scripts/post-deployment-setup.*` does this. Manually, connect to the first DB VM and run:

```bash
# 3 data-bearing, voting members (no arbiter). priority 2 only makes the
# initial PRIMARY deterministic; any member can be elected.
mongosh --eval "rs.initiate({
  _id: 'blogapp-rs0',
  members: [
    { _id: 0, host: '10.0.3.4:27017', priority: 2, votes: 1 },
    { _id: 1, host: '10.0.3.5:27017', priority: 1, votes: 1 },
    { _id: 2, host: '10.0.3.6:27017', priority: 1, votes: 1 }
  ]
})"
# Expect 1 PRIMARY + 2 SECONDARY
mongosh --quiet --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"
```

### 4. Add Secrets to Key Vault

```bash
az keyvault secret set \
  --vault-name kv-blogapp-prod-<unique> \
  --name "MongoDbConnectionString" \
  --value "mongodb://10.0.3.4:27017,10.0.3.5:27017,10.0.3.6:27017/blogapp?replicaSet=blogapp-rs0&w=majority"
```

### 5. Deploy Application Code

See the workshop materials for deploying:
- NGINX configuration to Web VMs
- Express.js application to App VMs
- MongoDB configuration to DB VMs

## 🧹 Cleanup

Remove all resources when the workshop is complete:

```bash
# Delete the resource group (this deletes all resources)
az group delete --name rg-blogapp-prod --yes --no-wait

# Verify deletion
az group show --name rg-blogapp-prod 2>/dev/null || echo "Resource group deleted"
```

## 🔧 Troubleshooting

### Deployment Failures

**Issue: Quota exceeded**
```
Error: QuotaExceeded
```
Solution: Request quota increase or use smaller VM sizes.

**Issue: Name already exists**
```
Error: ResourceAlreadyExists
```
Solution: Use a unique `workloadName` or change the environment.

**Issue: DNS label already in use**
```
Error: DnsRecordInUse
```
Solution: Choose a different `appGatewayDnsLabel` value (must be globally unique in the region).

**Issue: SSH key validation failed**
```
Error: InvalidParameter - sshPublicKey
```
Solution: Ensure the SSH key is in the correct format (`ssh-rsa AAAA...`).

### Connectivity Issues

**Cannot connect via Bastion**
1. Verify Bastion is deployed (`deployBastion = true`)
2. Check NSG rules allow Bastion subnet access
3. Wait 5-10 minutes after deployment for Bastion to be fully provisioned

**VMs cannot communicate**
1. Check NSG rules for the affected tier
2. Verify subnet routing
3. Test with `ping` and `telnet` from within the VMs

### Monitoring Issues

**No metrics in Azure Monitor**
1. Verify `deployMonitoring = true`
2. Check Azure Monitor Agent extension installed on VMs
3. Wait 5-10 minutes for data to appear
4. **Important**: Run the DCR configuration script after deployment (see below)

---

## 🔧 DCR Configuration (Post-Deployment Required)

The Data Collection Rule (DCR) is **not deployed via Bicep**. Instead, you must create it using Azure CLI after the infrastructure deployment completes.

### Why Post-Deployment?

When deploying a new Log Analytics workspace, built-in tables (Syslog, Perf) take 1-5 minutes to initialize. If DCR deployment tries to reference these tables before they exist, Azure returns:

```
Error: InvalidOutputTable
Message: Table for output stream 'Microsoft-Syslog' is not available
```

By creating the DCR post-deployment, we:
1. ✅ Avoid the InvalidOutputTable error
2. ✅ Give students hands-on experience with Azure CLI
3. ✅ Allow customization of monitoring configuration

### Create DCR After Deployment

After Bicep deployment completes, run the configuration script to create DCR and associate it with VMs:

**Bash (macOS/Linux):**
```bash
./scripts/configure-dcr.sh <resource-group-name>

# Example:
./scripts/configure-dcr.sh rg-blogapp-prod
```

**PowerShell (Windows):**
```powershell
.\scripts\configure-dcr.ps1 -ResourceGroupName <resource-group-name>

# Example:
.\scripts\configure-dcr.ps1 -ResourceGroupName rg-blogapp-prod
```

### What the Script Does

The script performs these operations:

1. **Waits 60 seconds** for Log Analytics tables to initialize
2. **Creates DCR** with Syslog and Performance Counter data sources
3. **Associates DCR** with all VMs in the resource group

| Data Source | Description |
|-------------|-------------|
| **Syslog** | System logs from auth, authpriv, daemon, syslog, user facilities |
| **Performance Counters** | CPU, Memory, Disk, Network metrics at 60-second intervals |

### Manual Configuration (Alternative)

If you prefer to create DCR manually via Azure Portal:

1. Go to **Azure Portal** → **Monitor** → **Data Collection Rules**
2. Click **+ Create**
3. Configure:
   - Name: `dcr-blogapp-prod`
   - Platform Type: Linux
   - Add data sources: Linux Syslog, Performance Counters
   - Add destinations: Your Log Analytics workspace
4. Associate with VMs in the resource group
5. Save changes

### Verify Configuration

```bash
# Check DCR data sources are configured
az monitor data-collection rule show \
  -g <resource-group-name> \
  -n dcr-blogapp-prod \
  --query 'dataSources'
```

---

## 📚 AWS to Azure Comparison

For AWS-experienced engineers:

| AWS Service | Azure Equivalent | Key Differences |
|-------------|-----------------|-----------------|
| CloudFormation | Bicep/ARM | Bicep has simpler syntax |
| VPC | VNet | Similar concepts |
| Security Groups | NSG | Stateful in both, similar rules |
| EC2 | Azure VMs | Different SKU naming |
| ALB (Layer 7) | Application Gateway | Both support SSL termination, path routing |
| NLB (Layer 4) | Load Balancer | Standard vs Basic SKU matters |
| ACM (Certificates) | Key Vault / App Gateway | Self-signed certs uploaded directly |
| Route 53 | Azure DNS / DNS Labels | App Gateway provides `*.cloudapp.azure.com` |
| CloudWatch | Azure Monitor | Different metric paths |
| Secrets Manager | Key Vault | RBAC-based access |
| Systems Manager | Bastion | Similar secure access pattern |

## 📖 References

- [Azure Architecture Design](../../design/AzureArchitectureDesign.md)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Azure Naming Conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
