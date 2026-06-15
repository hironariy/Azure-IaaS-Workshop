---
title: "Troubleshooting Runbook"
---

# Troubleshooting Runbook

## What You Do On This Page

Use symptom-based checks to move from the outside of the system inward: Application Gateway, Web tier, App tier, DB tier, authentication, and monitoring.

| Item | Details |
|---|---|
| Audience | Learners who hit errors or unexpected states during Day 1 / Day 2 |
| Time | 5-15 minutes per symptom |
| Prerequisites | Cloud Shell Bash, resource group name, Application Gateway FQDN |
| Done When | You can identify which layer to inspect next and run the relevant command or Portal check |

## First Variables

```bash
RESOURCE_GROUP="rg-blogapp-workshop"
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv 2>/dev/null || true)
```

For multiple groups, replace `RESOURCE_GROUP` with the instructor-assigned value.

## Basic Triage Order

1. **Entry:** Can you reach the Application Gateway URL?
2. **Web tier:** Are Web VMs and NGINX responding?
3. **App tier:** Are App VMs and Express API responding?
4. **DB tier:** Is MongoDB replica set connectivity healthy?
5. **Authentication:** Are Entra app registrations, API permission, and redirect URI correct?
6. **Monitoring:** Are Heartbeat, Perf, or Syslog records present in Log Analytics?

## 1. Bicep Deployment Failed

| Check | Command Or Screen |
|---|---|
| Failed operation | Azure Portal > Resource group > Deployments > failed deployment |
| CLI operation details | `az deployment operation group list --resource-group "$RESOURCE_GROUP" --name main -o table` |
| VM SKU availability | `az vm list-skus --location japanwest --size Standard_B -o table` |
| DNS label conflict | Change `appGatewayDnsLabel` to a unique value |
| Missing parameters | Check empty strings in `materials/bicep/main.local.bicepparam` |

Common actions:

- `QuotaExceeded`: return to Day 0 quota checks and ask the instructor.
- `DnsRecordInUse`: add a random suffix to `appGatewayDnsLabel`.
- `InvalidTemplate` / `InvalidParameter`: check quotes, empty values, and pasted certificate data.
- `SkuNotAvailable`: use an instructor-approved alternative VM size.

## 2. VM Quota Is Insufficient

```bash
az vm list-usage --location japanwest \
  --query "[?contains(name.value, 'standardBASv2Family') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

This workshop needs 16 Basv2-family vCPUs. Share the quota name and current value with the instructor.

## 3. Entra ID App Registration Cannot Be Created

Symptoms:

- **New registration** is disabled.
- Azure Portal shows a permission error.

Check tenant selection and whether you have Application Developer, Cloud Application Administrator, Global Administrator, or a tenant setting that allows users to register applications.

Action: Ask the instructor for pre-created Frontend SPA Client ID, Backend API Client ID, and Tenant ID if needed.

## 4. Login Or API Authentication Fails

| Symptom | Check | Action |
|---|---|---|
| `AADSTS9002326` | Frontend platform is SPA | Configure SPA redirect URI, not Web platform |
| Redirect URI mismatch | `https://<FQDN>` and `https://<FQDN>/` are registered | Add both to the Frontend SPA app |
| API 403 / invalid audience | Backend API Client ID and scope | Check `entraClientId` and API permission |
| Consent required | Permission consent state | Ask instructor if admin consent is required |

## 5. Application Gateway Returns 502 / 503

```bash
az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

Check Web VM power state, NGINX, NSG rules from Application Gateway subnet to Web subnet, and whether the browser accepted the self-signed certificate warning.

Start stopped Web VMs:

```bash
az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az2-prod
```

## 6. Web Loads But API Fails

Check App VM state, PM2 process state, internal load balancer path, and MongoDB password alignment.

```bash
curl -k "https://$FQDN/api/posts"
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?contains(name, 'vm-app')].{name:name,powerState:powerState}" -o table
```

If MongoDB connectivity is suspected, confirm that `mongoDbAppPassword` and `post-deployment-setup.local.sh` use the same value and that the password does not contain `@`.

## 7. DB Connection Timeout Occurs

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?contains(name, 'vm-db')].{name:name,powerState:powerState}" -o table
```

Check DB VM power state, MongoDB replica set primary, App subnet to DB subnet TCP/27017, and post-deployment setup completion.

## 8. Cloud Shell Disconnected

```bash
cd ~/Azure-IaaS-Workshop

LOCATION="japanwest"
RESOURCE_GROUP="rg-blogapp-workshop"

az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

Restore SSH keys if you backed them up.

```bash
mkdir -p ~/.ssh
cp ~/clouddrive/workshop-keys/id_rsa ~/clouddrive/workshop-keys/id_rsa.pub ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

Check the Bastion extension.

```bash
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name bastion --upgrade --yes
az extension show --name bastion --query "{name:name,version:version}" -o table
```

Recover FQDN if needed.

```bash
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)
echo "https://$FQDN"
```

## 9. Log Analytics Has No Data

Check that `scripts/configure-dcr.sh "$RESOURCE_GROUP"` succeeded, DCR is associated to VMs, and enough time has passed for table initialization.

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

## 10. Backup Or ASR Does Not Progress

| Symptom | Check | Action |
|---|---|---|
| Backup item missing | Vault and VM selection | Recheck Backup enablement |
| Backup job slow | Initial backup | Use only representative VMs if instructor says so |
| ASR initial replication slow | Replication health and progress | Switch to instructor demo or design walkthrough |
| Test failover resources remain | Cleanup test failover | Run cleanup from Recovery Services vault |

## Next

- Commands and resource names: [Quick reference](../reference/quick-reference-card.md)
- Day 1 resource deployment: [Day 1: Azure resource deployment](../learner/day-1-deployment-checklist.md)
- Day 1 application deployment: [Day 1: Application deployment](../learner/day-1-app-deployment.md)
- Day 2 resiliency: [Day 2: Resiliency checklist](../learner/day-2-resiliency-checklist.md)

Back to the [learner portal](../index.md)