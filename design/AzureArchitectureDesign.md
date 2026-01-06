# Azure Infrastructure Architecture Design

## Overview

This document defines the technical architecture requirements for the Azure IaaS Workshop. This serves as the specification that the Azure Infrastructure Architect agent and other agents must follow when creating Bicep templates, documentation, and workshop materials.

## Target Architecture

### Application Overview
- **Application Type**: Multi-user blog site
- **Architecture Pattern**: Traditional 3-tier web application
- **Tiers**: Web (NGINX) → Internal LB → App (Express/TypeScript) → DB (MongoDB)
- **Traffic Flow**: Internet → Application Gateway (HTTPS:443) → Web VMs (HTTP:80) → Internal LB (10.0.2.10) → App VMs → DB VMs
- **SSL/TLS**: Application Gateway terminates HTTPS with self-signed certificate; backend traffic is HTTP within VNet
- **OS**: Ubuntu 22.04 LTS
- **HA Strategy**: Availability Zones within primary region
- **DR Strategy**: Azure Site Recovery to secondary region
- **Authentication**: OAuth2.0 with Microsoft Entra ID

## Infrastructure Components

### 1. Networking Architecture

#### Virtual Network (VNet)
- **Address Space**: 10.0.0.0/16 (or suitable range)
- **Subnet Design**:
  - **Application Gateway subnet**: 10.0.0.0/24 (dedicated subnet for App Gateway, minimum /26)
  - Web tier subnet: 10.0.1.0/24 (2 VMs in different AZs)
  - App tier subnet: 10.0.2.0/24 (2 VMs in different AZs)
  - DB tier subnet: 10.0.3.0/24 (2 VMs in different AZs)
  - Azure Bastion subnet: 10.0.255.0/26 (AzureBastionSubnet - required name)

#### Network Security Groups (NSGs)

**Web Tier NSG Rules:**
- Allow HTTP (80) from Application Gateway subnet only (backend traffic after SSL termination)
- Allow health probe traffic (65200-65535) from GatewayManager service tag
- Allow SSH (22) from Azure Bastion subnet only
- Deny all other inbound traffic
- **Note**: No direct Internet traffic to Web VMs; all traffic flows through Application Gateway

**App Tier NSG Rules:**
- Allow application port (e.g., 3000) from Web tier subnet only
- Allow SSH (22) from Azure Bastion subnet only
- Deny all other inbound traffic

**DB Tier NSG Rules:**
- Allow MongoDB port (27017) from App tier subnet only
- Allow SSH (22) from Azure Bastion subnet only
- Deny all other inbound traffic

#### Network Topology Considerations
- Network peering to DR region (for Azure Site Recovery)
- Private endpoints for storage accounts (optional but recommended)
- DNS resolution strategy

### 2. Compute Resources

#### Virtual Machine Specifications

**Web Tier VMs (2 instances):**
- VM SKU: Standard_B2s (2 vCPU, 4 GB RAM)
- OS: Ubuntu 24.04 LTS
- Availability: Spread across AZ 1 and AZ 2
- Managed Disk: Standard SSD (OS: 30 GB)
- Software: NGINX
- **Rationale**: B-series burstable VMs are ideal for workshop's intermittent, low-traffic workload (~60% CPU baseline, bursts to 100%)

**App Tier VMs (2 instances):**
- VM SKU: Standard_B2s (2 vCPU, 4 GB RAM)
- OS: Ubuntu 24.04 LTS
- Availability: Spread across AZ 1 and AZ 2
- Managed Disk: Standard SSD (OS: 30 GB)
- Software: Node.js 20 LTS, Express (TypeScript), PM2 (process manager)
- **Rationale**: B-series cost-effective for Node.js apps with low concurrent users (10-20 during workshop)
- **Environment Configuration**: Bicep CustomScript injects production environment variables
  - `NODE_ENV=production`
  - `MONGODB_URI=mongodb://blogapp:<password>@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=blogapp`
  - `PORT=3000`
  - See [BackendApplicationDesign.md](BackendApplicationDesign.md#environment-aware-configuration) for details

**DB Tier VMs (2 instances):**
- VM SKU: Standard_B4ms (4 vCPU, 16 GB RAM)
- OS: Ubuntu 24.04 LTS
- Availability: Spread across AZ 1 and AZ 2
- Managed Disk: 
  - OS: Standard SSD (30 GB)
  - Data: Premium SSD (128 GB or 256 GB)
- Software: MongoDB (Replica Set configuration)
- **Rationale**: B4ms supports Premium SSD, provides sufficient memory for MongoDB with workshop data volumes, 60% CPU baseline adequate for light database operations

#### VM Extensions Required
- Azure Monitor Agent (for all VMs)
- Custom Script Extension (for initial configuration)

#### Custom Script Extension: Environment Configuration

Bicep uses Custom Script Extension to configure production environment on each VM tier:

**App Tier Environment Injection:**
```bash
# Set system-wide environment variables for Node.js application
cat <<EOF >> /etc/environment
NODE_ENV=production
MONGODB_URI=mongodb://blogapp:<password>@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=blogapp
PORT=3000
LOG_LEVEL=info
ENTRA_TENANT_ID=<tenant-id>
ENTRA_CLIENT_ID=<client-id>
CORS_ORIGINS=http://<load-balancer-ip>
EOF
```

**Why Bicep Injection (vs. manual .env editing)?**
- **Zero manual configuration**: VMs are production-ready after deployment
- **12-factor compliance**: Environment determines behavior, not config files
- **Workshop efficiency**: Students don't edit files on VMs
- **Security**: Credentials injected at deploy time, not stored in Git

#### Bicep Parameter Flow

Student-specific configuration flows from parameter file to VM configuration:

```
main.bicepparam (Student edits)    
        │                          
        │  param entraTenantId          (Entra tenant)
        │  param entraClientId          (Backend API app)
        │  param entraFrontendClientId  (Frontend SPA app)
        │  param sshPublicKey      
        ▼                          
    main.bicep                     
        │                          
        │  passes to modules       
        ├──────────────────────────────────┐
        ▼                                  ▼
  app-tier.bicep                     web-tier.bicep
        │                                  │
        │  CustomScript Extension          │  CustomScript Extension
        ▼                                  ▼
  /etc/environment (on VM)         /var/www/html/config.json
        │                                  │
        │  NODE_ENV=production             │  {
        │  ENTRA_TENANT_ID=xxx             │    "ENTRA_TENANT_ID": "xxx",
        │  ENTRA_CLIENT_ID=yyy             │    "ENTRA_FRONTEND_CLIENT_ID": "zzz",
        ▼                                  │    "ENTRA_BACKEND_CLIENT_ID": "yyy"
  Backend Application                      │  }
  (reads process.env.*)                    ▼
                                    Frontend Application
                                    (fetches /config.json at runtime)
```

**Workshop Instruction Pattern:**
1. Students edit **only `main.bicepparam`** - single location for all customization
2. No editing of `.bicep` module files (infrastructure code)
3. No editing of `.env` files on deployed VMs
4. No rebuilding frontend app with different Entra IDs

**Parameters Students Must Configure** (in `main.bicepparam`):

| Parameter | Description | How to Get |
|-----------|-------------|------------|
| `sshPublicKey` | SSH public key for VM access | `cat ~/.ssh/id_rsa.pub` |
| `adminObjectId` | User's Azure AD Object ID | `az ad signed-in-user show --query id -o tsv` |
| `entraTenantId` | Microsoft Entra tenant ID | `az account show --query tenantId -o tsv` |
| `entraClientId` | Backend API app registration ID | Azure Portal → App Registrations → Backend API |
| `entraFrontendClientId` | Frontend SPA app registration ID | Azure Portal → App Registrations → Frontend SPA |

**Config Injection by Tier:**

| Tier | Injection Method | Target File | Used By |
|------|-----------------|-------------|---------|
| **App (Backend)** | `/etc/environment` + `/opt/blogapp/.env` | Environment variables | Node.js `process.env.*` |
| **Web (Frontend)** | `/var/www/html/config.json` | JSON config file | Frontend `fetch('/config.json')` |

**Why Different Methods:**
- **Backend**: Node.js reads environment variables at runtime via `process.env`
- **Frontend**: React apps bake `import.meta.env.*` at build time, so we use runtime fetch instead

**AWS Comparison:**
- AWS uses EC2 User Data or SSM Parameter Store for similar pattern
- Azure Custom Script Extension is equivalent to EC2 User Data
- Both allow environment-specific configuration at provisioning time

#### Design Decisions
- **Proximity Placement Groups**: NOT used (explain: AZ distribution takes priority)
- **Ephemeral OS Disks**: Evaluate per tier (consider for stateless web tier)

#### Architecture Decision Record: VM Series Selection (B-series vs D-series)

**Decision**: Use B-series (burstable) VMs instead of D-series (general-purpose) VMs for workshop environment

**Context**:
- Workshop duration: 2 days (48 hours)
- Expected load: 10-20 concurrent users per student deployment
- Usage pattern: Intermittent testing during workshop with idle periods during lectures
- Students use personal Azure subscriptions (cost-sensitive)
- Educational environment, not production workload

**Comparison Analysis**:

| Criteria | B-series (Chosen) | D-series (Alternative) |
|----------|-------------------|------------------------|
| **Cost (48h, East US)** | ~$24/student | ~$37/student |
| **Cost Savings** | ✅ **35% cheaper** | Baseline |
| **Workload Match** | ✅ Perfect for burstable | Overkill for workshop |
| **CPU Model** | 60% baseline + burst to 100% | 100% always available |
| **Availability Zones** | ✅ Supported | ✅ Supported |
| **Premium SSD (DB)** | ✅ Supported (B4ms) | ✅ Supported |
| **Best For** | Dev/test, low-traffic apps | Production, sustained load |

**Cost Analysis (per student, 48 hours)**:
- Web: 2 × B2s @ $0.042/hr = $4.03 (vs 2 × D2s_v5 @ $0.096/hr = $9.22)
- App: 2 × B2s @ $0.042/hr = $4.03 (vs 2 × D2s_v5 @ $0.096/hr = $9.22)
- DB: 2 × B4ms @ $0.166/hr = $15.94 (vs 2 × D4s_v5 @ $0.192/hr = $18.43)
- **Total: $24.00 vs $36.87 = $12.87 savings per student**
- **For 25 students: $321.75 total savings**

**Why B-series Works for This Workshop**:
1. **Burstable workload pattern**: Students deploy → test briefly → idle during lectures → occasional testing
2. **CPU credits system**: VMs earn credits during idle time, spend during bursts (perfect match)
3. **Low baseline sufficient**: 60% CPU baseline = 1.2 vCPUs constantly available on B2s (enough for NGINX/Node.js with light traffic)
4. **Memory adequate**: 4 GB sufficient for web/app tiers; 16 GB appropriate for MongoDB with workshop data
5. **No performance compromise**: Workshop load won't exhaust CPU credits; even if it does, 60% baseline is acceptable

**When Would D-series Be Better?** (Teaching Opportunity)
- Production workloads with sustained 24/7 traffic
- CPU utilization consistently > 40-50%
- Strict performance SLAs required
- Latency-sensitive applications
- High-throughput database operations

**Educational Value**:
This choice becomes a teaching moment: "We're using B-series because workshop load is intermittent and burstable. In production with sustained traffic, you'd choose:
- **D-series**: General-purpose workloads
- **E-series**: Memory-optimized (large databases, caching)
- **F-series**: Compute-optimized (batch processing, analytics)
- Understanding workload patterns is key to Azure cost optimization."

**AWS Comparison for Students**:
- B-series ≈ AWS T3/T4g instances (burstable)
- D-series ≈ AWS M6i instances (general-purpose)

**Consequences**:
- ✅ 35% cost reduction for students
- ✅ Same HA/DR learning objectives achieved
- ✅ Additional lesson on VM selection and cost optimization
- ⚠️ If students stress-test heavily, may hit CPU baseline (becomes teaching opportunity)
- ✅ All technical requirements met (AZ support, Premium SSD, ASR compatibility)

**Alternatives Considered**:
1. D-series: Better for production, but unnecessarily expensive for workshop
2. A-series: Cheaper but older generation, limited AZ support
3. PaaS (App Service, Cosmos DB): Better for production, but workshop focuses on IaaS learning

### 3. Load Balancing

#### Application Gateway (Web Tier)

**Purpose**: Public-facing Layer 7 load balancer with SSL/TLS termination for secure web traffic

**Why Application Gateway Instead of Standard Load Balancer**:
- **SSL/TLS Termination**: Offloads certificate management from VMs; students don't need to configure NGINX for HTTPS
- **Layer 7 Features**: Path-based routing, URL rewriting, WAF capability (optional)
- **Azure DNS Label**: Provides `<label>.<region>.cloudapp.azure.com` domain - no custom domain required
- **Workshop Simplification**: Self-signed certificate eliminates need for CA or domain ownership
- **Educational Value**: Teaches modern cloud load balancing patterns vs basic Layer 4 load balancing

**SKU**: Standard_v2
- **Reason**: Zone redundancy, auto-scaling, better performance
- **Tier**: Standard (WAF_v2 optional for security demonstration)
- **Capacity**: Manual scaling with 1-2 instances (cost-optimized for workshop)

**Public IP**:
- SKU: Standard
- Allocation: Static
- Zone: Zone-redundant
- **DNS Label**: `blogapp-<unique>` → `blogapp-<unique>.<region>.cloudapp.azure.com`

**SSL/TLS Configuration**:
- **Certificate Type**: Self-signed certificate (PFX format)
- **Certificate Generation**:
  ```bash
  # Generate self-signed certificate (students run this script)
  # Replace <region> with your Azure region (e.g., japanwest, eastus, westeurope)
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout workshop.key \
    -out workshop.crt \
    -subj "/CN=blogapp-<unique>.<region>.cloudapp.azure.com"
  
  # Convert to PFX for Application Gateway
  openssl pkcs12 -export -out workshop.pfx \
    -inkey workshop.key \
    -in workshop.crt \
    -password pass:WorkshopP@ss123
  ```
- **Browser Warning**: Expected with self-signed certificates (acceptable for workshop)
- **Alternative (Production)**: Azure Key Vault integration with CA-signed certificates

**Frontend Configuration**:
- **HTTPS Listener** (port 443): Primary listener with SSL certificate
- **HTTP Listener** (port 80): Redirects to HTTPS (HTTP→HTTPS redirect rule)

**Backend Pool**:
- Web tier VMs (both AZs)
- **Backend Port**: 80 (HTTP - SSL terminated at App Gateway)
- **Backend Protocol**: HTTP

**Backend HTTP Settings**:
- Port: 80
- Protocol: HTTP
- Cookie-based affinity: Disabled (stateless SPA)
- Request timeout: 30 seconds
- **Override backend path**: Not used

**Health Probes**:
- Protocol: HTTP
- Path: /health
- Host: Pick from backend HTTP settings
- Interval: 15 seconds
- Unhealthy threshold: 3
- Match status codes: 200-399

**Routing Rules**:
- **HTTPS Rule**: HTTPS listener → Backend pool (Web VMs)
- **HTTP Redirect Rule**: HTTP listener → Redirect to HTTPS listener (permanent 301)

**WAF Configuration** (Optional - for security demonstration):
- Mode: Detection (not Prevention for workshop to avoid blocking legitimate traffic)
- Rule set: OWASP 3.2
- **Educational Value**: Shows how to add application-layer security

**AWS Comparison**:
| Azure Application Gateway | AWS Equivalent |
|--------------------------|----------------|
| Application Gateway | Application Load Balancer (ALB) |
| SSL/TLS termination | ALB HTTPS listener |
| Backend HTTP settings | Target group settings |
| Health probes | ALB health checks |
| WAF_v2 SKU | AWS WAF attached to ALB |
| Azure DNS label | Route 53 alias or ALB DNS name |

#### Internal Load Balancer (App Tier)

**Purpose**: Internal load balancer for App tier (VMSS-ready architecture)

**SKU**: Standard
- **Reason**: Prepares architecture for future VMSS auto-scaling migration

**Frontend Configuration**:
- Private IP: 10.0.2.10 (static, within App subnet)
- Zone-redundant frontend

**Backend Pools**:
- App tier VMs (both AZs)

**Health Probes**:
- HTTP probe on port 3000
- Path: /health
- Interval: 15 seconds
- Unhealthy threshold: 2

**Load Balancing Rules**:
- TCP (port 3000) → Backend port 3000

**Benefits**:
- Single endpoint for NGINX upstream configuration
- Azure-native health checks for App tier
- Seamless VMSS migration path (swap VMs for VMSS, keep ILB IP)
- Consistent architecture pattern across tiers

**VMSS Migration Path** (Future):
1. Create VMSS with same configuration as individual VMs
2. Add VMSS to Internal LB backend pool
3. Remove individual VMs from backend pool
4. Delete individual VMs
5. Enable auto-scaling rules on VMSS
6. **No changes needed to NGINX or LB** - ILB IP stays the same

### 4. Storage

#### Blob Storage Account

**Purpose**: Static assets (images, CSS, JavaScript files)

**Configuration**:
- SKU: Standard_LRS or Standard_ZRS (document choice)
- Performance: Standard
- Replication: LRS or ZRS within primary region
- Access tier: Hot
- Public access: Disabled (use private endpoints or SAS tokens)
- Lifecycle management: Implement policies for old data

#### Managed Disks

**Web Tier**: Standard SSD
**App Tier**: Standard SSD
**DB Tier**: Premium SSD (for data disks)

**Caching Settings**:
- OS Disks: ReadWrite
- Data Disks (DB): None or ReadOnly (based on workload)

**Zone-Redundant Storage**:
- Evaluate for critical data disks

### 5. Monitoring & Logging

#### Log Analytics Workspace
- Single workspace for all monitoring data
- Retention: 30 days (configurable)
- Region: Same as primary deployment

#### Azure Monitor Configuration
- **Azure Monitor Agent**: Deployed on all VMs via VM extension
- **Data Collection Rules**: 
  - System logs (syslog)
  - Performance counters (CPU, Memory, Disk, Network)
  - Application logs (custom paths)

#### Diagnostic Settings
Enable for all resources:
- Virtual Machines → Log Analytics
- Load Balancer → Log Analytics
- Storage Accounts → Log Analytics
- NSGs → Log Analytics (flow logs)

#### Alert Rules (Examples to Create)
- VM CPU > 80% for 5 minutes
- VM Memory > 90% for 5 minutes
- Load Balancer backend health < 50%
- Storage account availability < 99%

#### Workbooks
- Create custom workbook templates for workshop demonstration

### 6. Backup & Recovery

#### Recovery Services Vault

**Configuration**:
- Region: Same as primary deployment
- Storage redundancy: Geo-redundant (GRS) or Locally redundant (LRS)
- Soft delete: Enabled
- Security features: Enhanced security enabled

#### Backup Policies

**VM Backup Policy**:
- Frequency: Daily
- Time: 2:00 AM (local time)
- Retention: 
  - Daily: 7 days
  - Weekly: 4 weeks
  - Monthly: 3 months
- Instant restore: 2 days

**Database Backup Considerations**:
- Application-consistent backups for MongoDB
- Pre/post-scripts for MongoDB replica set

### 7. Azure Site Recovery (ASR)

#### DR Region Selection
- Use Azure region pairs (e.g., East US → West US 2)
- Consider data residency requirements
- Verify service availability in both regions

#### ASR Configuration

**Recovery Services Vault** (in secondary region):
- Purpose: Disaster recovery
- Storage redundancy: Locally redundant (in DR region)

**Replication Policy**:
- RPO threshold: 15 minutes
- Recovery points retention: 24 hours
- App-consistent snapshot frequency: 1 hour

**Recovery Plans**:
- Orchestrated failover sequence:
  1. DB tier VMs
  2. App tier VMs
  3. Web tier VMs
- Include manual actions for DNS update
- Post-failover validation steps

#### Network Mapping
- Primary VNet → Secondary VNet
- Subnet mappings for each tier
- IP address considerations (static vs dynamic)

### 8. Security & Identity

#### Azure Bastion
- Dedicated subnet (AzureBastionSubnet /26 minimum)
- **SKU: Standard** (enables native client support)
- Purpose: Secure SSH access without public IPs on VMs
- No public IPs required on any application VMs
- **Standard SKU Features**:
  - Native client support (SSH from local terminal via `az network bastion ssh`)
  - File copy/transfer
  - IP-based connection
  - Shareable links
  - Tunneling support
- **AWS Comparison**: Similar to AWS Session Manager but browser-based + native client

#### Managed Identities
- System-assigned managed identities for all VMs
- Use for:
  - Accessing Azure Storage
  - Accessing Key Vault
  - Logging to Log Analytics

#### Microsoft Entra ID Integration
- OAuth2.0 authentication for application
- App registration in Entra ID tenant
- Redirect URIs configured
- API permissions granted

#### Key Vault (Optional)
- Store application secrets
- MongoDB connection strings
- OAuth2.0 client secrets
- TLS/SSL certificates

#### Microsoft Defender for Cloud
- Enable for subscription
- Configure security policies
- Review recommendations

### 9. Resource Organization

#### Naming Conventions

Follow Azure naming best practices:

| Resource Type | Pattern | Example |
|---------------|---------|---------||
| Resource Group | rg-{workload}-{env}-{region} | rg-blogapp-prod-japanwest |
| Virtual Network | vnet-{workload}-{env}-{region} | vnet-blogapp-prod-japanwest |
| Subnet | snet-{tier}-{env} | snet-web-prod |
| VM | vm-{tier}{instance}-{env} | vm-web01-prod |
| **Application Gateway** | agw-{workload}-{env} | agw-blogapp-prod |
| **App Gateway Public IP** | pip-agw-{workload}-{env} | pip-agw-blogapp-prod |
| Internal Load Balancer | lbi-{tier}-{workload}-{env} | lbi-app-blogapp-prod |
| Storage Account | st{workload}{uniqueid} | stblogapp001 |
| NSG | nsg-{subnet}-{env} | nsg-web-prod |
| Log Analytics | log-{workload}-{env} | log-blogapp-prod |

**Application Gateway DNS Label**: `{workload}-{unique}` → `blogapp-<unique>.<region>.cloudapp.azure.com`

#### Tagging Strategy

Required tags for all resources:
- `Environment`: prod / dev / test
- `Workload`: blogapp
- `Owner`: Workshop / Student name
- `CostCenter`: Training
- `Tier`: web / app / db / shared
- `ManagedBy`: Bicep / Portal / CLI

### 10. High Availability Design

#### Availability Targets
- **SLA Target**: 99.95% (with Availability Zones)
- **RTO**: < 1 hour (for regional failure)
- **RPO**: < 15 minutes (for data loss)

#### HA Implementation per Tier

**Web Tier**:
- 2 VMs in different Availability Zones
- Application Gateway distributes traffic (Layer 7, HTTPS termination)
- Stateless design (no session affinity)

**App Tier**:
- 2 VMs in different Availability Zones
- Internal Load Balancer distributes traffic (10.0.2.10:3000)
- Horizontal scaling ready (VMSS migration path prepared)
- Stateless design

**DB Tier**:
- 2 VMs in different Availability Zones
- MongoDB Replica Set (Primary + Secondary)
- Automatic failover within cluster

#### Failure Scenarios to Handle
- Single VM failure per tier
- Availability Zone failure
- Regional failure (via ASR)

### 11. Cost Optimization

#### VM Sizing Strategy
- Right-size for workshop duration (2 days)
- Match VM series to workload characteristics (burstable for intermittent load)
- Use B-series burstable VMs (cost-optimized for dev/test scenarios)
- **Cost Optimization**: B-series saves 35% compared to D-series ($24 vs $37 per student for 48 hours)
- **Production Note**: Production workloads would typically use D/E/F-series for consistent performance

#### Resource Lifecycle
- Auto-shutdown for non-production resources
- Deallocate VMs during breaks (optional)
- Delete all resources after workshop

#### Cost Estimation (per student, 2-day workshop)

**VM Compute Costs (48 hours, East US region, pay-as-you-go)**:
- Web Tier: 2 × B2s @ $0.042/hr = **$4.03**
- App Tier: 2 × B2s @ $0.042/hr = **$4.03**
- DB Tier: 2 × B4ms @ $0.166/hr = **$15.94**
- **VM Subtotal**: **$24.00**

**Additional Infrastructure Costs (48 hours)**:
- Managed Disks (6 × Standard SSD 30GB + 2 × Premium SSD 128GB): **~$2.50**
- Application Gateway (Standard_v2, 1 capacity unit) + Public IP: **~$12.00**
- Internal Load Balancer + Private IP: **~$1.00**
- Storage Account (Standard LRS, minimal usage): **~$0.50**
- Azure Bastion (Standard SKU): **~$9.00** (enables native client SSH from terminal)
- Log Analytics (30-day retention, light ingestion): **~$2.00**
- Azure Backup (Recovery Services Vault): **~$1.00**
- Azure Site Recovery (replication): **~$6.00**
- Data transfer (minimal): **~$0.50**

**Total Estimated Cost**: **~$58 per student** for 48-hour workshop

**Note**: Application Gateway adds ~$11 vs Standard Load Balancer, but provides:
- SSL/TLS termination (no NGINX HTTPS config needed)
- Azure-provided DNS label (no custom domain needed)
- Layer 7 load balancing features
- Optional WAF for security

**Cost Optimization Tips for Students**:
- Deallocate VMs during breaks: Save ~$0.50/hour
- Use Bastion only when needed: Deallocate to save $0.19/hour
- Delete all resources after workshop: Zero ongoing costs
- **For 25 students, total workshop cost**: ~$1,175

*Note: Prices based on East US region, pay-as-you-go rates (December 2025). Actual costs vary by region, currency, and enterprise agreements.*

### 12. Performance Requirements

#### Expected Load
- Concurrent users: 10-20 (workshop testing)
- Response time: < 2 seconds
- Throughput: Low (educational environment)

#### Disk Performance
- DB tier: Premium SSD for IOPS requirements
- Web/App tier: Standard SSD sufficient

#### Network Performance
- Standard VM network bandwidth adequate
- Accelerated Networking: Not required

### 13. Compliance & Governance

#### Azure Well-Architected Framework Alignment

**Reliability Pillar**:
- ✅ Availability Zones
- ✅ Azure Site Recovery
- ✅ Backup and restore
- ✅ Health monitoring

**Security Pillar**:
- ✅ Network isolation (NSGs)
- ✅ No public IPs (Bastion only)
- ✅ Managed identities
- ✅ Entra ID authentication
- ✅ Defender for Cloud

**Cost Optimization Pillar**:
- ✅ Appropriate VM sizing
- ✅ Resource tagging
- ✅ Cleanup procedures

**Operational Excellence Pillar**:
- ✅ Infrastructure as Code
- ✅ Monitoring and alerting
- ✅ Automated deployment

**Performance Efficiency Pillar**:
- ✅ Right-sized resources
- ✅ Appropriate disk tiers
- ✅ Load balancing

## Architecture Diagrams Required

1. **High-level Architecture**: 3-tier application with Availability Zones
2. **Network Topology**: VNet, subnets, NSGs, traffic flow
3. **Availability Zones Distribution**: VM placement across zones
4. **DR Topology**: Primary region → Secondary region via ASR
5. **Monitoring Architecture**: Data flow from resources to Log Analytics

## Alternative Technologies (Educational Context)

### Application Gateway vs Standard Load Balancer
- **Workshop Choice**: Application Gateway with self-signed certificate
- **Reason for Application Gateway**:
  - **SSL/TLS termination**: Eliminates need for students to configure HTTPS on NGINX
  - **Azure DNS label**: Provides `<label>.<region>.cloudapp.azure.com` domain - no custom domain or CA needed
  - **Self-signed certificate**: Quick to generate, acceptable for workshop (browser warnings expected)
  - **Educational value**: Teaches Layer 7 load balancing, SSL offloading patterns
- **Cost Trade-off**: ~$11 more per student for 48 hours vs Standard Load Balancer
- **Alternative (Standard Load Balancer)**: Would require students to:
  - Generate certificates on each VM
  - Configure NGINX for HTTPS (time-consuming, not workshop focus)
  - Either accept HTTP-only (insecure) or spend significant time on certificate management

### Azure Files vs Blob Storage
- **Workshop Choice**: Blob Storage for static assets
- **Alternative**: Azure Files for SMB/NFS workloads
- **Use Cases for Azure Files**:
  - Legacy applications requiring file shares
  - Shared configuration files
  - Multi-VM file access
- **Tradeoffs**: Document cost, performance, protocol differences

### B-series vs D-series VMs
- **Workshop Choice**: B-series (burstable VMs)
- **Production Alternative**: D-series (general-purpose), E-series (memory-optimized), F-series (compute-optimized)
- **Reason for B-series**: 
  - 35% cost savings for workshop ($24 vs $37 per student)
  - Workload characteristics match perfectly (intermittent, low-traffic)
  - Teaches VM selection and cost optimization concepts
- **When to Use D-series**:
  - Production workloads with sustained traffic
  - CPU utilization > 40-50% consistently
  - Strict performance SLAs
- **Tradeoffs**: B-series uses CPU credit system (60% baseline, burst to 100%); D-series provides consistent 100% CPU availability
- **AWS Equivalent**: B-series ≈ T3/T4g; D-series ≈ M6i

### IaaS VMs vs PaaS
- **Workshop Choice**: IaaS VMs (intentional for learning)
- **PaaS Alternatives**:
  - App Service (instead of VMs + NGINX/Express)
  - Cosmos DB for MongoDB API (instead of MongoDB on VMs)
  - Azure Database for MongoDB (managed service)
- **Future Workshop**: PaaS migration workshop

## Deployment Constraints

### Time Constraints
- Infrastructure deployment: 15-30 minutes via Bicep
- Should not block workshop progress
- Asynchronous where possible

### Concurrent Deployments
- Support 20-30 students deploying simultaneously
- No quota conflicts
- Unique naming with parameters

### Workshop Environment
- Students use their own Azure subscriptions
- No shared infrastructure
- Complete isolation between students

---

**Document Status**: Living document - update as architecture evolves
**Last Updated**: 2026-01-06
**Version**: 2.0

### Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-01 | Initial specification |
| 2.0 | 2026-01-06 | Major architecture update:<br>- Replaced Standard Load Balancer with Application Gateway for Web tier<br>- Added SSL/TLS termination with self-signed certificate<br>- Added Application Gateway subnet (10.0.0.0/24)<br>- Updated NSG rules for App Gateway traffic patterns<br>- Added certificate generation script documentation<br>- Updated cost estimates (+$11/student for App Gateway)<br>- Added Azure DNS label for HTTPS endpoint<br>- Updated naming conventions for Application Gateway resources |
