---
title: "Learner Quickstart"
---

# Learner Quickstart

## What You Do On This Page

Confirm how to move through the 2-day Azure IaaS Workshop and which pages to open in order. This workshop standardizes CLI and script work on **Azure Cloud Shell (Bash)** to reduce proxy, certificate, PATH, and local tool differences.

| Item | Details |
|---|---|
| Audience | Learners with AWS experience who want to practice Azure IaaS, availability, monitoring, and BCDR |
| Time | 5-10 minutes |
| Prerequisites | Browser access to GitHub and Azure Portal |
| Done When | You can explain which page to use for Day 0, Day 1, and Day 2 |

## Learning Flow

| Timing | Page | Done When |
|---|---|---|
| Before the workshop or at the start | [Day 0: Prerequisites](day-0-prerequisites.md) | You have checked Azure Portal, Cloud Shell, Entra ID permissions, quota, and your GitHub repository copy |
| Day 1 resources | [Day 1: Azure resource deployment](day-1-deployment-checklist.md) | You can prepare Cloud Shell, deploy Bicep, run post-deployment setup, configure DCR, and collect the FQDN |
| Day 1 application | [Day 1: Application deployment](day-1-app-deployment.md) | You can manually place application code on the App/Web VMs and validate traffic |
| Day 1 monitoring | [Monitoring guide](../operations/monitoring-guide.md) | You can run basic Log Analytics queries |
| Day 2 main lab | [Day 2: Resiliency checklist](day-2-resiliency-checklist.md) | You can work through Backup, restore checks, failure validation, and ASR/test failover concepts safely |
| When stuck | [Troubleshooting runbook](../operations/troubleshooting-runbook.md), [Quick reference](../reference/quick-reference-card.md), [Azure Cloud Shell mini guide](azure-cloud-shell-guide.md) | You can find symptom-based checks, common commands, and Cloud Shell basics |

## Standard Work Locations

| Work | Standard | Why |
|---|---|---|
| Azure CLI commands | Azure Cloud Shell Bash | Authenticated to Azure and includes CLI, Git, OpenSSL, and SSH |
| File editing | Cloud Shell editor (`code`) | Avoids local OS and editor differences |
| Entra ID app registrations | Azure Portal | Makes the authentication configuration visible and teachable |
| Deployment progress | Resource group Deployments in Azure Portal | Lets you inspect state even if Cloud Shell disconnects |
| Local development | Optional | Developer material only; not the standard learner deployment path |

## What Learners Need

- Azure subscription access, or access to a subscription assigned by the instructor
- Permission to create Microsoft Entra ID app registrations, or app registration values provided by the instructor
- GitHub account
- Browser

Local Azure CLI, Azure PowerShell, Bicep CLI, OpenSSL, Node.js, and Docker are not required for the normal workshop path.

## AWS-To-Azure Mental Map

| AWS Concept | Azure Equivalent |
|---|---|
| VPC | Virtual Network (VNet) |
| Security Group / NACL | Network Security Group (NSG) |
| ALB | Application Gateway |
| NLB | Standard Load Balancer |
| IAM Role / Instance Profile | Azure RBAC / Managed Identity |
| CloudWatch Logs | Azure Monitor / Log Analytics |
| EC2 multi-AZ placement | VM placement across Availability Zones |

## Checkpoints

- You can explain what Day 0 prepares.
- You understand that CLI work is done in Cloud Shell Bash.
- You understand that Cloud Shell startup, repository clone, SSH key creation, and SSL certificate generation are grouped at the start of Day 1 resource deployment.
- You understand that the local development guide is optional developer material, not the Azure deployment path.

## Next

Continue to [Day 0: Prerequisites](day-0-prerequisites.md).

If you get lost, return to the [learner portal](../index.md) or open the [troubleshooting runbook](../operations/troubleshooting-runbook.md).