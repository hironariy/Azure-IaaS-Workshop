---
title: "Quick Reference"
---

# Quick Reference

## What You Do On This Page

Look up common resource names, ports, Cloud Shell commands, Azure Portal locations, and KQL queries during the workshop.

| Item | Details |
|---|---|
| Audience | Learners who need quick lookup during Day 1 / Day 2 |
| Time | 1-5 minutes for the needed section |
| Prerequisites | You know the Day 1 resource group name |
| Done When | You can quickly find common commands and Portal locations |

## Working Variables

```bash
RESOURCE_GROUP="rg-blogapp-workshop"
LOCATION="japanwest"

FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)
```

For multiple groups, set `RESOURCE_GROUP` to something like `rg-blogapp-A-workshop`.

## Main Resource Names

| Type | Name |
|---|---|
| Resource group | `rg-blogapp-workshop` or `rg-blogapp-<groupId>-workshop` |
| Application Gateway | `agw-blogapp-prod` |
| Application Gateway public IP | `pip-agw-blogapp-prod` |
| Bastion | `bastion-blogapp-prod` |
| Web VMs | `vm-web-az1-prod`, `vm-web-az2-prod` |
| App VMs | `vm-app-az1-prod`, `vm-app-az2-prod` |
| DB VMs | `vm-db-az1-prod`, `vm-db-az2-prod` |
| MongoDB replica set | `blogapp-rs0` |
| VM admin user | `azureuser` |

VM names do not change per group; always specify `--resource-group`.

## Ports

| Traffic | Port | Purpose |
|---|---:|---|
| Internet -> Application Gateway | 443 | HTTPS |
| Application Gateway -> Web VM | 80 | NGINX |
| Web VM -> Internal Load Balancer / App VM | 3000 | Express API |
| App VM -> DB VM | 27017 | MongoDB |
| Bastion -> VM | 22 | SSH |

## Bicep Parameter Map

| Parameter | Meaning | How To Get It |
|---|---|---|
| `sshPublicKey` | Public key for VM SSH | `cat ~/.ssh/id_rsa.pub` |
| `adminObjectId` | Your object ID for Key Vault management | `az ad signed-in-user show --query id -o tsv` |
| `entraTenantId` | Entra tenant ID | `az account show --query tenantId -o tsv` |
| `entraClientId` | Backend API app registration Client ID | Azure Portal > App registrations |
| `entraFrontendClientId` | Frontend SPA app registration Client ID | Azure Portal > App registrations |
| `sslCertificateData` | Base64 encoded PFX | `cat cert-base64.txt` |
| `sslCertificatePassword` | PFX password | Default `Workshop2024!` |
| `mongoDbAppPassword` | MongoDB app user password | Same as post-deployment setup. Do not use `@` |
| `appGatewayDnsLabel` | Application Gateway FQDN DNS label | Example: `blogapp-team1-0106` |

## Common Cloud Shell Commands

### Azure Account

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
```

### VM State

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[].{name:name,powerState:powerState,privateIps:privateIps}" -o table
```

### Stop And Start VMs

```bash
az vm stop --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
```

Use `az vm stop` for workshop failure simulation. Do not use `az vm deallocate` unless the instructor tells you to.

### Application Gateway FQDN

```bash
az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv
```

### Backend Health

```bash
az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

### App Traffic

```bash
curl -k "https://$FQDN/"
curl -k "https://$FQDN/api/posts"
```

`-k` skips self-signed certificate validation for workshop checks.

### DCR Configuration

```bash
./scripts/configure-dcr.sh "$RESOURCE_GROUP"
```

### Bastion Extension

```bash
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name bastion --upgrade --yes
az extension show --name bastion --query "{name:name,version:version}" -o table
```

### Cloud Shell Recovery

```bash
cd ~/Azure-IaaS-Workshop
LOCATION="japanwest"
RESOURCE_GROUP="rg-blogapp-workshop"

mkdir -p ~/.ssh
cp ~/clouddrive/workshop-keys/id_rsa ~/clouddrive/workshop-keys/id_rsa.pub ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

## Common Azure Portal Locations

| Goal | Portal Location |
|---|---|
| Deployment progress | Resource group > Deployments |
| Application Gateway health | Application Gateway > Backend health |
| VM state | Virtual machines > target VM > Overview |
| VM boot diagnostics | Virtual machines > target VM > Boot diagnostics |
| Log Analytics | Log Analytics workspace > Logs |
| DCR | Monitor > Data Collection Rules |
| Backup | Recovery Services vault > Backup items |
| Backup job | Recovery Services vault > Backup jobs |
| ASR replication | Recovery Services vault > Site Recovery > Replicated items |
| Entra app registrations | Microsoft Entra ID > App registrations |

## KQL Starters

### VM Heartbeat

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

### CPU By VM

```kusto
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCpuPercent=avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated asc
| render timechart
```

### Memory By VM

```kusto
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Memory" and CounterName == "% Used Memory"
| summarize AvgMemoryUsedPercent=avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated asc
| render timechart
```

### Recent Syslog Errors

```kusto
Syslog
| where SeverityLevel in ("err", "crit", "alert", "emerg")
| project TimeGenerated, Computer, Facility, SeverityLevel, SyslogMessage
| order by TimeGenerated desc
| take 50
```

### Explore Application Gateway Logs

```kusto
search "ApplicationGateway"
| order by TimeGenerated desc
| take 50
```

## Return Points

| Situation | Page |
|---|---|
| Check Day 1 resource deployment | [Day 1: Azure resource deployment](../learner/day-1-deployment-checklist.md) |
| Check Day 1 application deployment | [Day 1: Application deployment](../learner/day-1-app-deployment.md) |
| Check Day 2 procedure | [Day 2: Resiliency checklist](../learner/day-2-resiliency-checklist.md) |
| Diagnose by symptom | [Troubleshooting runbook](../operations/troubleshooting-runbook.md) |
| Go deeper on monitoring | [Monitoring guide](../operations/monitoring-guide.md) |
| Go deeper on BCDR | [Disaster recovery guide](../operations/disaster-recovery-guide.md) |

Back to the [learner portal](../index.md)