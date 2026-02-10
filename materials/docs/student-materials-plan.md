# Student Learning Materials Plan (Azure IaaS Workshop)

## Purpose
This document proposes **additional student-facing materials** to help AWS-experienced engineers understand Azure concepts faster and operate the workshop environment with less instructor intervention.

This plan complements existing student guides:
- `materials/docs/local-development-guide.md`
- `materials/docs/monitoring-guide.md`
- `materials/docs/disaster-recovery-guide.md`

## Audience
- Engineers with 3–5 years experience
- AWS familiarity (VPC/ALB/NLB/IAM/CloudWatch/Route 53)
- Azure level around AZ-900 to AZ-104 (or studying)

## Design principles
- **Workshop-first**: every doc should directly support a lab step or a common failure mode.
- **AWS→Azure translation**: explain concepts using an AWS mental model first, then the Azure-native model.
- **Actionable**: include “what to click / what to check / expected result”.
- **Time-boxed**: each document should have a “10-minute version” section.
- **Avoid duplication**: link to existing guides for monitoring/DR/local dev details.

## Planned materials (including the two you already identified)

### 1) Azure Resources Used in This Workshop (you already planned)
**Proposed file**: `materials/docs/azure-resources-guide.md` (and optional `azure-resources-guide.ja.md`)

**Why**: Students often get lost in the portal because they don’t know which resources matter, which are supporting services, and what “healthy” looks like.

**Outline**
- Architecture at a glance (one diagram)
- Resource inventory table: resource → role → AWS analogy → “where to check health”
- Traffic flow: Internet → App Gateway/LB → web/app/db
- “Golden signals” per tier (latency, errors, saturation, availability)

**Estimated read time**: 15–25 minutes

---

### 2) Bicep Techniques Used in This Repository (you already planned)
**Proposed file**: `materials/docs/bicep-techniques-guide.md` (and optional `.ja.md`)

**Why**: Students can copy/paste Bicep without understanding modules, parameterization, and environment separation.

**Outline**
- How this repo structures Bicep (folders/modules/entry points)
- Parameters: `@description`, `@allowed`, `@secure`, environment naming
- Outputs and cross-module wiring
- Common pitfalls: `existing` resources, scopes, resource naming constraints
- “How to debug deployments” (what error messages mean, where to look)

**Estimated read time**: 20–30 minutes

---

## Additional high-impact ideas

### 3) AWS-to-Azure Concept Translation Cheat Sheet
**Proposed file**: `materials/docs/aws-to-azure-cheatsheet.md`

**Why**: Many workshop questions are really “what is the Azure equivalent of X?” or “why is Azure doing this differently?”

**Outline**
- Quick mapping table (AWS → Azure):
  - VPC → VNet, Subnet → Subnet, SG/NACL → NSG, IGW/NAT → Public IP/NAT Gateway
  - ALB/NLB → Application Gateway/Load Balancer, Route 53 → Azure DNS/Traffic Manager
  - CloudWatch → Azure Monitor/Log Analytics, CloudTrail → Activity Log
  - IAM role → RBAC role assignment, Instance Profile → Managed Identity
- “Same word, different meaning” pitfalls (e.g., *resource group*, *availability zone*)
- 5 common mental-model mistakes and how to correct them

**Estimated read time**: 10–15 minutes

---

### 4) Networking Primer for This Workshop (VNet/Subnets/NSG/Routes/DNS)
**Proposed file**: `materials/docs/networking-primer.md`

**Why**: Most lab failures in IaaS workshops are networking-related (NSG, routes, probes, DNS), and students need a simple, consistent checklist.

**Outline**
- “How packets flow” in this lab (diagram + narrative)
- VNets and subnets: why tiers are separated
- NSGs: inbound/outbound rules, service tags, troubleshooting patterns
- User Defined Routes (UDR): when they matter (and when they don’t)
- DNS basics for the lab: private vs public resolution, common confusion points
- Connectivity checklist:
  - From App Gateway/LB to web
  - From web to app
  - From app to DB

**Estimated read time**: 20 minutes

---

### 5) Identity, Access, and Secrets Guide (Entra ID + RBAC + Managed Identity)
**Proposed file**: `materials/docs/identity-and-access-guide.md`

**Why**: Students must understand the difference between **Entra ID app registrations**, **OAuth tokens**, and **Azure RBAC** (control-plane permissions). This is a frequent source of confusion.

**Outline**
- Two planes:
  - Control plane (ARM): Azure RBAC
  - Data plane (app APIs): OAuth scopes/audience
- Entra ID basics used by this app (ties to local-dev guide)
- Managed identity: what it is, when to use it in Azure
- Secret hygiene for the workshop:
  - What must never go in Git
  - Where to store secrets (Key Vault in prod; local `.env` for dev)
- Common errors and fixes (403, invalid audience, missing consent)

**Estimated read time**: 15–25 minutes

---

### 6) Troubleshooting Runbook (Symptom → Checks → Fix)
**Proposed file**: `materials/docs/troubleshooting-runbook.md`

**Why**: This reduces instructor load and improves learning by guiding students through a repeatable diagnostic process.

**Outline**
- First principles: start at the edge and move inward
- “If X happens, check Y” playbooks:
  - 502/503 at the gateway
  - Health probe failures
  - Login/auth failures
  - API works locally but not on VM
  - DB connection timeouts
- Where to look:
  - Azure portal (Backend health, VM status, boot diagnostics)
  - VM commands (systemd/service status, logs)
  - Log Analytics (link to monitoring guide + starter KQL)

**Estimated read time**: 15–20 minutes

---

### 7) Resiliency Test Playbook (Failure Injection + Expected Outcomes)
**Proposed file**: `materials/docs/resiliency-test-playbook.md`

**Why**: Resiliency becomes real when students run controlled failures and validate recovery. A playbook prevents “random breakage” and keeps exercises safe.

**Outline**
- Safety rules and rollback
- Zonal failure simulations (VM stop, NSG block, backend pool removal)
- What should happen (expected user impact + recovery time targets)
- Validation checklist:
  - App still serves traffic
  - Metrics/logs show the incident
  - Post-incident verification

**Estimated read time**: 15–25 minutes

---

### 8) Cost, Quotas, and Cleanup Guide
**Proposed file**: `materials/docs/cost-and-cleanup-guide.md`

**Why**: Students often overrun time due to quota issues and forget cleanup steps (ASR and vaults can be sticky/costly).

**Outline**
- Common quota blockers (cores per region, public IPs, etc.)
- Cost hotspots in this workshop
- Cleanup checklist:
  - Delete resource group(s)
  - Remove ASR replication/test resources
  - Remove Recovery Services vault artifacts
- “Done means done” verification

**Estimated read time**: 10–15 minutes

---

## Suggested packaging (to keep it manageable)
To avoid overwhelming students, ship documents in two tiers.

### Minimum set (strongly suggested)
- `azure-resources-guide.md`
- `aws-to-azure-cheatsheet.md`
- `networking-primer.md`
- `troubleshooting-runbook.md`
- `bicep-techniques-guide.md`

### Optional / extension set (nice-to-have)
- `identity-and-access-guide.md` (if you want deeper auth/RBAC learning)
- `resiliency-test-playbook.md`
- `cost-and-cleanup-guide.md`

## Recommended timing in the workshop
- Pre-work (send 2–3 days before): `aws-to-azure-cheatsheet.md` + `azure-resources-guide.md`
- Day 1 morning: `networking-primer.md` (first 10-minute version)
- Day 1 afternoon: `troubleshooting-runbook.md` (use during labs)
- Day 2: `bicep-techniques-guide.md` + `resiliency-test-playbook.md`

## Implementation notes
- Place all student-facing docs under `materials/docs/` to keep discovery simple.
- Consider adding `.ja.md` mirrors only for the **minimum set** first, to control translation cost.
- Keep diagrams simple (Mermaid is ideal if you want diff-friendly diagrams).
