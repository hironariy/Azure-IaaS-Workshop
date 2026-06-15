---
title: "Azure IaaS Workshop Learner Portal"
---

# Azure IaaS Workshop Learner Portal

This is the English learner entry point for the 2-day Azure IaaS Workshop. Use this page on GitHub Pages at `/en/`, or read it directly on GitHub when Pages is not enabled for your copied repository.

CLI and script work is standardized on **Azure Cloud Shell (Bash)**. For the normal workshop path, learners only need a browser and access to Azure Portal and GitHub.

## How To Use This Portal

Open the pages from top to bottom. Each page includes expected results and checkpoints so you can tell whether you are ready to move on.

## Workshop Flow

- [ ] **1. Learner quickstart**: [Confirm the reading order and workshop overview](learner/learner-quickstart.md)
- [ ] **2. Day 0: Prerequisites**: [Check Azure Portal, Cloud Shell, Entra ID, quota, and GitHub repository readiness](learner/day-0-prerequisites.md)
- [ ] **3. Day 1: Azure resource deployment**: [Prepare Cloud Shell, deploy Bicep, run post-deployment setup, configure DCR, and collect the FQDN](learner/day-1-deployment-checklist.md)
- [ ] **4. Day 1: Application deployment**: [Place backend and frontend code on the App/Web VMs and validate traffic](learner/day-1-app-deployment.md)
- [ ] **5. Monitoring guide**: [Use Azure Monitor and Log Analytics to inspect the environment](operations/monitoring-guide.md)
- [ ] **6. Day 2: Resiliency checklist**: [Practice Backup, restore checks, HA validation, and ASR/test failover concepts](learner/day-2-resiliency-checklist.md)
- [ ] **7. Disaster recovery guide**: [Review BCDR concepts, safety rules, and expected outcomes](operations/disaster-recovery-guide.md)

## Reference TOC

| Goal | Page | Use When |
|---|---|---|
| Confirm Cloud Shell basics | [Azure Cloud Shell mini guide](learner/azure-cloud-shell-guide.md) | You need to open Bash, check the subscription, or use the Cloud Shell editor |
| Troubleshoot by symptom | [Troubleshooting runbook](operations/troubleshooting-runbook.md) | Deployment, Bastion SSH, application traffic, monitoring, or resiliency checks fail |
| Look up commands and names | [Quick reference](reference/quick-reference-card.md) | You need resource names, common commands, KQL, or port numbers quickly |
| Understand identity and access | [Identity / Access](identity-and-access-guide.md) | You want the background for Entra ID, Azure RBAC, and Managed Identity |
| Go deeper on Bicep | [Bicep techniques](bicep-techniques-guide.md) | You want to understand the template structure and design choices |
| Run local development | [Local development guide](local-development-guide.md) | You are maintaining or extending the app; this is not required for normal learners |

## Standard Work Locations

| Work | Standard Location | Notes |
|---|---|---|
| Azure CLI commands | Azure Cloud Shell Bash | Already authenticated to Azure and includes Git, OpenSSL, and SSH |
| File editing | Cloud Shell editor (`code`) | Avoids local OS and editor differences |
| Entra ID app registrations | Azure Portal | Keeps the authentication configuration visible and teachable |
| Deployment progress | Resource group > Deployments in Azure Portal | Lets you inspect progress even if Cloud Shell disconnects |
| Application code placement | Azure Bastion SSH | You connect to App/Web VMs and run clone, build, start, and deploy steps manually |

## Start Here

Begin with the [learner quickstart](learner/learner-quickstart.md), then move through the Day 0, Day 1, and Day 2 pages in order.