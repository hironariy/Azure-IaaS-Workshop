# BCDR Guide (Azure Backup + Azure Site Recovery)

This guide describes a practical approach to **Business Continuity and Disaster Recovery (BCDR)** for this workshop’s IaaS-based 3-tier application.

- **Azure Backup**: protects data and VM state (point-in-time restore)
- **Azure Site Recovery (ASR)**: orchestrates regional failover of VMs (disaster recovery)

## Important workshop note

This application includes:
- Web tier VM(s) (NGINX)
- App tier VM(s) (Node.js)
- DB tier VM(s) (MongoDB replica set)

Failing over the DB tier is more nuanced than stateless tiers. This guide focuses on **workshop-appropriate DR exercises** and highlights where you must make design decisions.

---

## 1. Choose a DR strategy (recommended for the workshop)

### Option A (recommended): Backup for recovery + ASR for compute

- Use **Azure Backup** for point-in-time VM restore and data recovery
- Use **ASR** to fail over web/app VMs to a paired region
- Treat the DB tier carefully (see “DB considerations” below)

### Option B (advanced): Full regional DR with ASR for all tiers

- ASR replicate web/app/db VMs
- Requires clearer DB failover plan and consistent recovery sequencing

**AWS analogy:** ASR resembles a managed version of replicating instances + orchestrating failover (a blend of Route 53 failover + EC2 replication patterns), while Azure Backup resembles AWS Backup.

---

## 2. Azure Backup: protect the VMs

### 2.1 Create a Recovery Services vault

1. In Azure portal, create **Recovery Services vault**.
2. Place it in the same subscription and (typically) the same region as the workload.

### 2.2 Enable VM backups

1. Open the Recovery Services vault.
2. Go to **Backup** → choose **Azure** as workload location and **Virtual machine** as workload.
3. Select your workshop VMs and configure a **backup policy**.

**Minimum for the workshop:** daily backup + short retention.

### 2.3 Perform a restore (exercise)

- Use **Restore VM** to create a new VM from a restore point.
- Validate:
  - VM boots
  - application services start
  - the restored VM can join the network (NSGs/subnets)

---

## 3. Azure Site Recovery: regional failover of VMs

### 3.1 Prerequisites

- A **Recovery Services vault** to manage replication
- A **target region** (often the Azure paired region)
- Target networking prepared (VNet/subnets) or mapped during ASR setup

### 3.2 Enable replication

1. In the Recovery Services vault, go to **Site Recovery**.
2. Choose **Enable replication** for Azure VMs.
3. Select:
   - Source region/resource group
   - Target region
   - Target resource group
   - Target VNet/subnet mapping
4. Create/choose a **replication policy**.

### 3.3 Create a Recovery Plan (recommended)

A recovery plan lets you define the startup order:
1. Database tier (if included)
2. App tier
3. Web tier

You can also include manual steps, but keep it minimal for the workshop.

### 3.4 Test failover (safe exercise)

1. Run **Test failover** to an isolated network.
2. Validate:
   - VMs start in the expected order
   - web/app endpoints respond in the test network
3. Clean up the test failover resources.

### 3.5 Planned failover / unplanned failover

- **Planned failover**: use when the source region is still healthy (cleaner, lower risk)
- **Unplanned failover**: use during an outage scenario

---

## 4. DNS and traffic switching

Failover is only “done” once users reach the new region.

For the workshop environment, switching usually means updating:
- Application Gateway public endpoint (DNS label / public IP)
- Any client-side base URLs if hardcoded

**Recommendation:** keep DNS labels/environment variables clearly documented so switching is easy during exercises.

---

## 5. Database tier considerations (MongoDB)

MongoDB replica sets are designed for node-level failure and zonal resiliency, but **regional DR** requires a plan.

Workshop-friendly guidance:
- If you replicate DB VMs with ASR, ensure the recovery plan starts DB first.
- After failover, validate replica set health and primary election.
- If your design assumes a single-region replica set, treat cross-region as an **advanced extension**.

If you want a simpler DR story for the workshop, consider:
- Using Azure Backup restores for DB tier recovery exercises
- Keeping ASR failover focus on stateless tiers (web/app)

---

## 6. What “good” looks like (acceptance checks)

- **RPO defined**: how much data loss is acceptable
- **RTO defined**: how long outage can last
- Backups succeed and restores are repeatable
- ASR test failover is repeatable and validated
- Traffic cutover steps are documented and can be performed within workshop time

---

## 7. Next steps (optional)

- Automate backup and ASR configuration via Bicep/CLI
- Add runbooks for:
  - failover
  - failback
  - post-failover validation
- Add Azure Monitor alerts for backup failures and replication health
