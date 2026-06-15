---
title: "Azure Cloud Shell Mini Guide"
---

# Azure Cloud Shell Mini Guide

## What You Do On This Page

Open Azure Cloud Shell in Bash mode and confirm only the basics needed before returning to Day 1. Repository clone, SSH key creation, SSL certificate generation, and Bicep parameter editing are covered in [Day 1: Azure resource deployment](day-1-deployment-checklist.md).

| Item | Details |
|---|---|
| Audience | Learners who only need to confirm how to open Cloud Shell and switch to Bash |
| Time | 3-5 minutes |
| Prerequisites | You can sign in to Azure Portal |
| Done When | Cloud Shell Bash is open and you can return to the Day 1 resource deployment page |

## 1. Open Cloud Shell In Bash

1. Sign in to [Azure Portal](https://portal.azure.com).
2. Select the Cloud Shell icon in the top bar.
3. If this is your first launch, create storage according to the instructor's guidance.
4. Select **Bash** as the shell.

**Expected Result:** A Cloud Shell prompt appears and accepts commands.

**Checkpoint:** Day 1 commands are written for Bash. If PowerShell is open, switch to Bash.

## 2. Check Subscription And Tenant

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

If you have multiple subscriptions, switch to the subscription assigned by the instructor.

```bash
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

**Expected Result:** The workshop subscription name and tenant ID are displayed.

## 3. Open The Cloud Shell Editor

Cloud Shell can open a web editor with the `code` command.

```bash
code .
```

After saving files, return to the Cloud Shell prompt and continue. If `code` does not open, wait a few seconds and try again; use `nano` as a fallback.

## 4. Recover After A Session Disconnect

Cloud Shell can disconnect after inactivity. After reconnecting, return to the Day 1 instructions and restore the repository directory, variables, and SSH key as needed.

```bash
cd ~/Azure-IaaS-Workshop
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

If you backed up SSH keys to `~/clouddrive/workshop-keys`, restore them with:

```bash
mkdir -p ~/.ssh
cp ~/clouddrive/workshop-keys/id_rsa ~/clouddrive/workshop-keys/id_rsa.pub ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

For the complete recovery flow, see the [troubleshooting runbook](../operations/troubleshooting-runbook.md).

## Next

Return to [Day 1: Azure resource deployment](day-1-deployment-checklist.md).

Back to the [learner portal](../index.md).