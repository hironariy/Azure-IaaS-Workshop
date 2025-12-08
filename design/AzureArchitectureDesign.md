# Azure Infrastructure Architecture Design

## Overview

This document defines the technical architecture requirements for the Azure IaaS Workshop. This serves as the specification that the Azure Infrastructure Architect agent and other agents must follow when creating Bicep templates, documentation, and workshop materials.

## Target Architecture

### Application Overview
- **Application Type**: Multi-user blog site
- **Architecture Pattern**: Traditional 3-tier web application
- **Tiers**: Web (NGINX) → Internal LB → App (Express/TypeScript) → DB (MongoDB)
- **Traffic Flow**: Internet → External LB → Web VMs → Internal LB (10.0.2.10) → App VMs → DB VMs
- **OS**: Ubuntu 22.04 LTS
- **HA Strategy**: Availability Zones within primary region
- **DR Strategy**: Azure Site Recovery to secondary region
- **Authentication**: OAuth2.0 with Microsoft Entra ID

## Infrastructure Components

### 1. Networking Architecture

#### Virtual Network (VNet)
- **Address Space**: 10.0.0.0/16 (or suitable range)
- **Subnet Design**:
  - Web tier subnet: 10.0.1.0/24 (2 VMs in different AZs)
  - App tier subnet: 10.0.2.0/24 (2 VMs in different AZs)
  - DB tier subnet: 10.0.3.0/24 (2 VMs in different AZs)
  - Azure Bastion subnet: 10.0.255.0/26 (AzureBastionSubnet - required name)
  - Load balancer subnet: If needed based on design

#### Network Security Groups (NSGs)

**Web Tier NSG Rules:**
- Allow HTTPS (443) from Internet
- Allow HTTP (80) from Internet
- Allow SSH (22) from Azure Bastion subnet only
- Deny all other inbound traffic

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
- Software: Node.js, Express (TypeScript)
- **Rationale**: B-series cost-effective for Node.js apps with low concurrent users (10-20 during workshop)

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

#### External Load Balancer (Web Tier)

**Purpose**: Public-facing load balancer for web traffic

**SKU**: Standard (not Basic)
- **Reason**: Zone redundancy, better SLA, required for AZ deployment

**Public IP**:
- SKU: Standard
- Allocation: Static
- Zone: Zone-redundant

**Frontend Configuration**:
- Public IP address for web traffic

**Backend Pools**:
- Web tier VMs (both AZs)

**Health Probes**:
- HTTP probe on port 80
- Path: /health
- Interval: 15 seconds
- Unhealthy threshold: 2

**Load Balancing Rules**:
- HTTP (port 80) → Backend port 80
- HTTPS (port 443) → Backend port 443 (if SSL termination on VMs)

**Outbound Rules**:
- Configure for outbound internet access from backend VMs

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
| Resource Group | rg-{workload}-{env}-{region} | rg-blogapp-prod-eastus |
| Virtual Network | vnet-{workload}-{env}-{region} | vnet-blogapp-prod-eastus |
| Subnet | snet-{tier}-{env} | snet-web-prod |
| VM | vm-{tier}{instance}-{env} | vm-web01-prod |
| External Load Balancer | lbe-{workload}-{env} | lbe-blogapp-prod |
| Internal Load Balancer | lbi-{tier}-{workload}-{env} | lbi-app-blogapp-prod |
| Storage Account | st{workload}{uniqueid} | stblogapp001 |
| NSG | nsg-{subnet}-{env} | nsg-web-prod |
| Log Analytics | log-{workload}-{env} | log-blogapp-prod |

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
- Load Balancer distributes traffic
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
- Standard Load Balancer (External + Internal) + Public IP: **~$2.00**
- Storage Account (Standard LRS, minimal usage): **~$0.50**
- Azure Bastion (Standard SKU): **~$9.00** (enables native client SSH from terminal)
- Log Analytics (30-day retention, light ingestion): **~$2.00**
- Azure Backup (Recovery Services Vault): **~$1.00**
- Azure Site Recovery (replication): **~$6.00**
- Data transfer (minimal): **~$0.50**

**Total Estimated Cost**: **~$47 per student** for 48-hour workshop

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
- **Workshop Choice**: Standard Load Balancer
- **Better Production Choice**: Application Gateway + WAF
- **Reason for SLB**: Time constraints, focus on IaaS fundamentals
- **Explanation Required**: Document why App Gateway is preferred for production

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
**Last Updated**: 2025-12-01
**Version**: 1.0
