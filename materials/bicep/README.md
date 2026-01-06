# Azure IaaS Workshop - Bicep Infrastructure Templates

This directory contains the Bicep Infrastructure as Code (IaC) templates for deploying the Azure IaaS Workshop infrastructure.

## 🎯 Overview

These templates deploy a highly available, 3-tier blog application infrastructure:

| Tier | Components | VM Size | Availability |
|------|-----------|---------|-------------|
| **Web** | 2 × NGINX reverse proxy VMs | Standard_B2s | Zone 1 & 2 |
| **App** | 2 × Node.js/Express VMs | Standard_B2s | Zone 1 & 2 |
| **DB** | 2 × MongoDB VMs | Standard_B4ms | Zone 1 & 2 |

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
- Contributor role on the subscription or resource group
- Sufficient quota for:
  - 6 VMs (B-series)
  - 6 managed disks
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
    │   └── db-tier.bicep       # 2 MongoDB VMs with data disks
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
| `deployStorage` | `true` | Deploy Storage Account |
| `webVmSize` | `Standard_B2s` | Web tier VM size |
| `appVmSize` | `Standard_B2s` | App tier VM size |
| `dbVmSize` | `Standard_B4ms` | DB tier VM size |
| `dbDataDiskSizeGB` | `128` | MongoDB data disk size |

## 💰 Cost Estimation

### Production Configuration (~$58/day)

| Resource | Quantity | Est. Cost/Day |
|----------|----------|---------------|
| Web VMs (B2s) | 2 | $2.40 |
| App VMs (B2s) | 2 | $2.40 |
| DB VMs (B4ms) | 2 | $9.60 |
| MongoDB Data Disks (P10) | 2 × 128GB | $2.80 |
| Application Gateway v2 | 1 | $7.30 |
| Internal Load Balancer | 1 | $0.72 |
| Azure Bastion | 1 | $4.40 |
| Public IP | 2 | $0.24 |
| Log Analytics | 1 | ~$2.00 |
| Key Vault | 1 | ~$0.05 |
| **Total** | | **~$32/day** |

> **2-Day Workshop Estimate**: ~$65 per student

### Development Configuration (~$15/day)

Use `dev.bicepparam` to disable Bastion, Key Vault, and Storage for lower cost during development.

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

Connect to the first DB VM and run:

```bash
# Get DB VM IPs from deployment output
mongosh --eval "rs.initiate({
  _id: 'blogapp-rs0',
  members: [
    { _id: 0, host: '<DB_VM_1_IP>:27017', priority: 2 },
    { _id: 1, host: '<DB_VM_2_IP>:27017', priority: 1 }
  ]
})"
```

### 4. Add Secrets to Key Vault

```bash
az keyvault secret set \
  --vault-name kv-blogapp-prod-<unique> \
  --name "MongoDbConnectionString" \
  --value "mongodb://<DB_VM_1_IP>:27017,<DB_VM_2_IP>:27017/blogapp?replicaSet=blogapp-rs0"
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

- [Azure Architecture Design](/design/AzureArchitectureDesign.md)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Azure Naming Conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
