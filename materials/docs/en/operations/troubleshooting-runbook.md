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
| VM SKU availability | `az vm list-skus --location japanwest --size Standard_D2s_v6 --zone -o table` and `az vm list-skus --location japanwest --size Standard_D4s_v6 --zone -o table` |
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
  --query "[?contains(name.value, 'DSv6') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

This workshop needs 16 Dsv6-family vCPUs. Check both family and regional quota headroom (`Limit - Current`); quota does not guarantee zonal capacity. See the Day 0 quota check for details, and share the quota name and current value with the instructor.

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

Check DB VM power state, MongoDB replica set primary, App subnet to DB subnet TCP/27017, and post-deployment setup completion. If the API log shows `ECONNREFUSED` / `ReplicaSetNoPrimary`, see 7.1.

### 7.1 MongoDB Does Not Start: Linux Kernel 6.19 Or Newer (Issue #26)

**Symptoms**

- PM2 `blogapp-api` restarts in a loop:

  ```text
  MongooseServerSelectionError: connect ECONNREFUSED 10.0.3.4:27017
  ReplicaSetNoPrimary
  servers: 10.0.3.4:27017 = Unknown, 10.0.3.5:27017 = Unknown
  ```

- On the DB VM, `mongod.service` is `failed` and nothing listens on 27017.
- `post-deployment-setup` stops at Step 2 with `MongoDB is not ready after ...s`.

**Why it happens**

MongoDB 8.0.x refuses to start on Linux kernel 6.19 or newer because of a TCMalloc/rseq incompatibility ([SERVER-121912](https://jira.mongodb.org/browse/SERVER-121912)). The Ubuntu 24.04 Azure image follows the *rolling* `linux-azure` kernel, which [moved to 7.0](https://discourse.ubuntu.com/t/kernel-7-0-is-now-the-default-for-ubuntu-24-04-lts-on-azure/88459). The fix in this workshop is to keep the DB VMs on Ubuntu's *long-term* Azure kernel track `linux-azure-lts-24.04` (6.8.x, still receives security updates). New deployments do this automatically. DB VMs created before this fix need the migration below.

> **AWS comparison:** this is the same decision as keeping an EC2 database host on a specific Amazon Linux kernel line rather than the newest one. Amazon DocumentDB or RDS hide this problem because AWS owns the host OS and certifies the kernel/engine pair. On IaaS VMs, you own it.

**Diagnose (inside each DB VM)**

```bash
uname -r                                   # 6.8.x is OK; 6.19+ / 7.x is incompatible
dpkg-query -W mongodb-org-server           # 8.0.x
sudo systemctl status mongod --no-pager -l
sudo journalctl -u mongod -b --no-pager | grep -iE "kernel|SERVER-121912|blogapp-kernel-track"
sudo ss -lntp '( sport = :27017 )'
sudo blogapp-kernel-track status           # exists on DB VMs deployed with the fix
```

The MongoDB error is `MongoDB cannot start: Linux kernel versions 6.19 and newer has a known incompatibility with this version of MongoDB.` On VMs deployed with the fix, a guard prints `mongod 8.0.x cannot run on kernel ...` first.

If `uname -r` is not 6.8.x but `blogapp-kernel-track status` shows `finalize : pending`, the VM is still in the first-boot switch. Wait 3-5 minutes and check again.

**Fix: migrate an existing DB VM to the LTS kernel track (recommended)**

Do this one DB VM at a time, **DB2 first**. Run from Cloud Shell in the repository root. The helper installs `linux-azure-lts-24.04`, removes the rolling kernel metapackages, writes an apt pin, selects the 6.8 kernel in GRUB, and reboots the VM 1 minute later. After the reboot, it removes the non-LTS kernels. MongoDB data and the replica set configuration are not changed.

```bash
cd ~/Azure-IaaS-Workshop
az vm run-command invoke -g "$RESOURCE_GROUP" -n vm-db-az2-prod \
  --command-id RunShellScript \
  --scripts @materials/bicep/modules/compute/scripts/mongodb-kernel-track.sh \
  --parameters migrate
```

- Run Command returns **before** the VM reboots (about 1 minute later). Its output is truncated to about 4 KB, so judge the result with the checks below.
- If the VM is already running a 6.8.x kernel, the helper only finalizes and does not reboot. If mongod is still stopped in that case, start it with `sudo systemctl restart mongod`.
- If a VM was migrated with the earlier helper (repository before 2026-10) and mongod fails with `this subcommand must run as root`, rerun the same `migrate` from the latest repository and then run `sudo systemctl restart mongod` (Issue #31). On such a VM the installed helper always runs `migrate`, so do not use `sudo blogapp-kernel-track status` there; just rerun the migration.
- If Run Command does not return for a long time (10+ minutes), it may be waiting for another extension (for example `MDE.Linux` deployed by Azure Policy). Check with `az vm extension list -g "$RESOURCE_GROUP" --vm-name <vm-name> -o table`, then copy the helper to the VM over Bastion SSH and run `sudo bash mongodb-kernel-track.sh migrate`.

Wait about 3-5 minutes, then check DB2 (through Bastion SSH):

```bash
uname -r                                        # 6.8.x
findmnt --mountpoint /data/mongodb
sudo systemctl is-active mongod                 # active
mongosh --quiet --eval 'db.hello().isWritablePrimary + " " + db.hello().secondary'
sudo blogapp-kernel-track status                # finalize : done/not-needed
```

Also check replica set health: `mongosh --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'`. Then repeat the same steps for `vm-db-az1-prod`.

> **2-node replica set caution:** while one of the two DB VMs reboots, the other cannot keep a majority, so there is **no primary for a few minutes** and API writes fail. This is expected and a good illustration of why production uses 3 data-bearing members. On two nodes, `rs.stepDown()` does not shorten the outage, so skip it.

If you previously used the temporary GRUB workaround below, the helper's `/etc/default/grub.d/99-blogapp-kernel-track.cfg` overrides it. After the migration, set `GRUB_DEFAULT=0` back in `/etc/default/grub` and run `sudo update-grub` to keep the configuration clean.

**Temporary workaround: boot an older installed kernel (only if the migration cannot run)**

If an older kernel below 6.19 (for example `6.17.0-1022-azure`) is still installed, you can make GRUB boot it. This is a **short-term** workaround only: you must still migrate to the LTS track. Take a backup or snapshot first. Do not delete kernels or data disks.

```bash
uname -r
ls -l /boot/vmlinuz-6.17.0-1022-azure /boot/initrd.img-6.17.0-1022-azure
ls -ld /lib/modules/6.17.0-1022-azure
sudo grep -E '^[[:space:]]*(submenu|menuentry) ' /boot/grub/grub.cfg   # copy the exact titles
grep -rn GRUB_DEFAULT /etc/default/grub /etc/default/grub.d/ 2>/dev/null
```

Set this in `/etc/default/grub`, using the titles you saw, and make sure no file in `/etc/default/grub.d/` overrides it:

```text
GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.17.0-1022-azure"
```

```bash
sudo update-grub
sudo grub-script-check /boot/grub/grub.cfg && echo OK
sudo reboot
```

Recover DB2 first, then DB1. Never edit `/boot/grub/grub.cfg` directly. Do not reformat data, downgrade MongoDB, or rerun `rs.initiate()`. Do not bypass MongoDB's startup check. If `/data/mongodb` is not mounted, do not start mongod manually.

**When MongoDB supports Linux 6.19 or newer:** remove the pin only after that combination has been validated. Delete `/etc/apt/preferences.d/blogapp-mongodb-kernel-track` and the guard `/etc/systemd/system/mongod.service.d/10-blogapp-kernel-guard.conf`, run `sudo systemctl daemon-reload`, install `linux-azure`, and reboot one DB VM at a time.

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