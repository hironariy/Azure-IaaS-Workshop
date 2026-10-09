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
- `AuthorizationFailed` (`Microsoft.Authorization/roleAssignments/write`): the Contributor role cannot create role assignments. Ask the instructor for Owner or User Access Administrator, or set `param assignKeyVaultRoles = false` in `main.local.bicepparam` and redeploy (Day 0 Step 3.1). The VMs and other resources already exist, so the redeploy only applies the difference.

## 2. VM Quota Is Insufficient

```bash
az vm list-usage --location japanwest \
  --query "[?name.value=='StandardDsv6Family' || name.value=='standardDSv6Family' || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

JMESPath `contains()` is case-sensitive and the quota name varies (`StandardDsv6Family` / `standardDSv6Family`), so the query matches both spellings exactly.

This workshop needs 20 Dsv6-family vCPUs (including three DB VMs). The DB VMs are placed one per Zone 1/2/3, so the DB SKU must be available in all three zones. Check both family and regional quota headroom (`Limit - Current`); quota does not guarantee zonal capacity. See the Day 0 quota check for details, and share the quota name and current value with the instructor.

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

Check that all three DB VMs (`vm-db-az1/az2/az3-prod`) are running (if two or more stop, the replica set loses its majority and has no PRIMARY), that `rs.status()` shows one PRIMARY and two SECONDARY members, App subnet to DB subnet TCP/27017, and post-deployment setup completion. If the API log shows `ECONNREFUSED` / `ReplicaSetNoPrimary`, see 7.1. If the environment was deployed before Issue #30 with two DB nodes and post-deployment setup reports that `vm-db-az3-prod` is missing or that the set has fewer than 3 members, see 7.2. If the API log shows `Authentication failed`, check that `mongoDbAppPassword` matches `APP_PASSWORD` in post-deployment setup. If post-deployment setup warns `mongod is running without authorization`, or a DB VM has `/etc/mongod.conf.pending-auth`, see 7.3.

> **mongosh authentication (Issue #36):** MongoDB access control is on. Every command except `db.hello()` (for example `rs.status()` and `rs.add()`) must log in as the admin user `blogadmin`. Commands in this section use the form `mongosh -u blogadmin -p --authenticationDatabase admin`, which prompts for the password (`<YOUR_MONGODB_ADMIN_PASSWORD>`).

### 7.1 MongoDB Does Not Start: Linux Kernel 6.19 Or Newer (Issue #26)

**Symptoms**

- PM2 `blogapp-api` restarts in a loop:

  ```text
  MongooseServerSelectionError: connect ECONNREFUSED 10.0.3.4:27017
  ReplicaSetNoPrimary
  servers: 10.0.3.4:27017 = Unknown, 10.0.3.5:27017 = Unknown, 10.0.3.6:27017 = Unknown
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

Do this one DB VM at a time, in the order **`vm-db-az3-prod` → `vm-db-az2-prod` → `vm-db-az1-prod` (usually the PRIMARY)**. Skip az3 in a 2-node environment. Run from Cloud Shell in the repository root. The helper installs `linux-azure-lts-24.04`, removes the rolling kernel metapackages, writes an apt pin, selects the 6.8 kernel in GRUB, and reboots the VM 1 minute later. After the reboot, it removes the non-LTS kernels. MongoDB data and the replica set configuration are not changed.

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

Wait about 3-5 minutes, then check the target DB VM (through Bastion SSH):

```bash
uname -r                                        # 6.8.x
findmnt --mountpoint /data/mongodb
sudo systemctl is-active mongod                 # active
mongosh --quiet --eval 'db.hello().isWritablePrimary + " " + db.hello().secondary'
sudo blogapp-kernel-track status                # finalize : done/not-needed
```

Also check replica set health: `mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'`. After the target is back as `SECONDARY`, repeat the steps for the next VM. Do the PRIMARY (usually `vm-db-az1-prod`) last; for a planned switchover, run `rs.stepDown(300)` as described in the note below.

> **Impact with 3 nodes:** as long as you reboot one VM at a time, the other two keep a majority (2 of 3 votes) and the API keeps working. For the PRIMARY VM, run `rs.stepDown(300)` on the PRIMARY right after Run Command returns (about 1 minute before the reboot). The default 60 seconds expires before the reboot, and az1 (priority 2) takes PRIMARY back. On a clean shutdown mongod hands over PRIMARY itself, so the election usually finishes within a few seconds. **Do not reboot two DB VMs at the same time** (the set loses its majority and has no PRIMARY).
>
> **Legacy 2-node caution:** in a 2-node environment from before Issue #30, while one DB VM reboots the other cannot keep a majority, so there is **no primary for a few minutes** and API writes fail. `rs.stepDown()` does not shorten the outage, so skip it. Migrating to 3 nodes with 7.2 is recommended.

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

Recover the SECONDARY members (az3, az2) first, then the PRIMARY (usually az1). Never edit `/boot/grub/grub.cfg` directly. Do not reformat data, downgrade MongoDB, or rerun `rs.initiate()`. Do not bypass MongoDB's startup check. If `/data/mongodb` is not mounted, do not start mongod manually.

**When MongoDB supports Linux 6.19 or newer:** remove the pin only after that combination has been validated. Delete `/etc/apt/preferences.d/blogapp-mongodb-kernel-track` and the guard `/etc/systemd/system/mongod.service.d/10-blogapp-kernel-guard.conf`, run `sudo systemctl daemon-reload`, install `linux-azure`, and reboot one DB VM at a time.

### 7.2 Migrate An Existing 2-Node Environment To 3 Nodes (Issue #30)

**Applies to:** environments deployed before Issue #30 whose MongoDB replica set has only `vm-db-az1-prod` and `vm-db-az2-prod`.

**Why migrate:** with two nodes, if either one stops, the survivor has only 1 of 2 votes and is not a majority. It cannot elect a PRIMARY automatically, and recovery needed a manual forced reconfiguration. With three data-bearing members (PSS), any single node can stop: the other two elect a PRIMARY automatically and `w=majority` writes continue.

> **AWS comparison:** this is the same work as adding an instance in a third AZ to a self-managed 2-AZ MongoDB deployment on EC2. With Amazon DocumentDB you just add a replica instance; here you add the member, wait for initial sync, and update the connection string yourself.

**Approach:** add one member online with `rs.add()`. Do **not** use `rs.reconfig({force: true})`, recreate the replica set, or reinitialize existing data.

**Cost and quota:** per learner, one more `Standard_D4s_v6` (+4 vCPU), one 128 GB Premium SSD data disk, and one OS disk.

#### Step 1: Take A Backup

Do one of the following:

- If Azure Backup is configured: run **Backup now** for `vm-db-az1-prod` and `vm-db-az2-prod` and wait for completion.
- Otherwise: snapshot the data disk of both DB VMs.

```bash
for vm in vm-db-az1-prod vm-db-az2-prod; do
  DISK_ID=$(az vm show -g "$RESOURCE_GROUP" -n $vm --query "storageProfile.dataDisks[0].managedDisk.id" -o tsv)
  az snapshot create -g "$RESOURCE_GROUP" -n "snap-${vm}-pre-issue30" --source "$DISK_ID" --incremental true
done
```

Optionally, also take a logical backup on the PRIMARY with `mongodump --db blogapp --out /tmp/pre-issue30`.

#### Step 2: Check Quota And Zones

```bash
LOCATION="japanwest"   # match your deployment region
az vm list-usage --location "$LOCATION" \
  --query "[?name.value=='StandardDsv6Family' || name.value=='standardDSv6Family' || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" -o table
az vm list-skus --location "$LOCATION" --size Standard_D4s_v6 \
  --query "[].locationInfo[].zones" -o tsv
```

**Decision:** continue if headroom (`Limit - Current`) is at least 4 vCPU and the zone list includes `3`. If Zone 3 is not available, talk to the instructor. Adding `--parameters dbVmAz3Zone=1` (or `2`) to the step 3 command places the third VM in another zone (`param dbVmAz3Zone = '1'` in `main.local.bicepparam` works too). Two members then share one zone, so an outage of that zone loses the majority and no PRIMARY can be elected (a single VM failure is still tolerated).

#### Step 3: Redeploy Bicep To Create Only `vm-db-az3-prod`

Keep the existing VMs and create only the third one. `skipVmCreationDbAz3` defaults to the value of `skipVmCreationDb`, so set it to `false` explicitly.

```bash
cd ~/Azure-IaaS-Workshop
git pull   # get the version that includes Issue #30
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationWeb=true skipVmCreationApp=true skipVmCreationDb=true skipVmCreationDbAz3=false
```

**Expected Result:** `provisioningState` is `Succeeded`, and `vm-db-az3-prod` (10.0.3.6, Zone 3) is created.

**Side effects:**

- The CustomScript on the existing DB VMs does not re-run, because its content is unchanged.
- The CustomScript on the App VMs **does re-run**, because `MONGODB_URI` now has three hosts (this includes package updates). It updates `/opt/blogapp/.env` and `/etc/environment` with the new URI, but it does not change the running API or `/opt/blogapp/dist/.env` (Step 7 applies the change).
- If the inline `--parameters` overrides are rejected, put the same four values in `main.local.bicepparam` and run the command again.

#### Step 4: Wait Until The New DB VM Is Ready

On first boot, a new DB VM switches to the LTS kernel (6.8) and reboots once (see 7.1). Wait 3-5 minutes **after the Step 3 deployment completes**, then check `vm-db-az3-prod` through Bastion SSH (the deployment itself takes 6-7 minutes including the az3 CustomScript, so this is about 9-10 minutes after VM creation starts):

```bash
uname -r                                  # 6.8.x
sudo blogapp-kernel-track status          # finalize : done/not-needed
findmnt --mountpoint /data/mongodb
sudo systemctl is-active mongod           # active
mongosh --quiet --eval 'db.hello().isWritablePrimary'   # false (not a member yet)
```

#### Step 5: Run `rs.add()` On The PRIMARY

Connect to the PRIMARY (usually `vm-db-az1-prod`) through Bastion SSH.

```bash
mongosh --quiet --eval 'db.hello().isWritablePrimary'   # must be true
mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval 'rs.add({ host: "10.0.3.6:27017", priority: 1, votes: 1 })'
```

> **Environment deployed before Issue #36:** `vm-db-az3-prod`, redeployed in Step 3, starts with access control (keyFile), but the existing az1/az2 run without a keyFile. The new and existing members then cannot authenticate each other and the new member cannot sync. If `vm-db-az1-prod` has `/etc/mongod.conf.pending-auth`, **finish 7.3 first**, then run `rs.add()`.

**Expected Result:** `{ ok: 1 }`. If you get `Found two member configurations with same host field`, the member was already added; continue with Step 6.

`rs.conf().version` increases by two for one `rs.add()` (for example 1 -> 3). The new member is first added with a `newlyAdded` flag, and MongoDB updates the config once more when it removes that flag automatically. This is expected.

> **Why `priority: 1, votes: 1`:** this matches a fresh deployment (az1 = priority 2, az2/az3 = priority 1, one vote each). A member that is still in initial sync does not stand for election and does not count toward the majority, so adding it before the sync finishes is safe.

#### Step 6: Wait For Initial Sync To Finish

```bash
mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval '
const s = rs.status();
const p = s.members.find(m => m.stateStr === "PRIMARY");
s.members.forEach(m => print(m.name, m.stateStr, "lagSec=" + ((p.optimeDate - m.optimeDate) / 1000)));
'
```

Repeat every minute until `10.0.3.6:27017` moves from `STARTUP2` (initial sync) to `SECONDARY` and shows `lagSec=0` (or a few seconds). With workshop data volumes, this usually takes a few minutes.

#### Step 7: Update The App Connection String And Restart The API One VM At A Time

The driver discovers the new member from the existing two hosts, but keep all three hosts in the seed list. Then the API can still start later even if az1 and az2 are down. On each App VM (`vm-app-az1-prod`, then `vm-app-az2-prod`), through Bastion SSH:

```bash
grep '^MONGODB_URI' /opt/blogapp/.env | sed -E 's#//[^@]*@#//***@#'   # confirm 3 hosts (10.0.3.4/5/6) and replicaSet=blogapp-rs0
cp /opt/blogapp/.env /opt/blogapp/dist/.env
chmod 600 /opt/blogapp/dist/.env
pm2 restart blogapp-api --update-env
sleep 5
curl -s http://localhost:3000/health
```

**Expected Result:** `healthy`. Move to the second App VM only after the first is healthy. The internal load balancer sends traffic to the other App VM, so the API stays available.

If you did not redeploy the App tier in Step 3, edit the host list in `MONGODB_URI` in both `/opt/blogapp/.env` and `/opt/blogapp/dist/.env` to `10.0.3.4:27017,10.0.3.5:27017,10.0.3.6:27017` before restarting.

#### Step 8: Verify

```bash
mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr + " votes=" + rs.conf().members.find(c => c.host === m.name).votes)'
```

- One PRIMARY and two SECONDARY members, all with `votes=1`.
- Creating and editing posts in the browser works.
- Re-running post-deployment setup prints `Replica set already initialized (3 members)` and does not reinitialize anything.
- The Day 2 DB failover exercise (automatic election when the PRIMARY stops) can be run.

**Rollback:** if something goes wrong, run `rs.remove("10.0.3.6:27017")` on the PRIMARY to return to two members (the driver ignores the third seed host). Delete `vm-db-az3-prod` and its disks if no longer needed, and delete the Step 1 snapshots after you confirm everything is healthy.

### 7.3 Enable MongoDB Access Control On An Existing Environment (Issue #36)

**Symptoms:**

- Post-deployment setup ends with `Unauthenticated read was not rejected` / `mongod is running without authorization`.
- Unauthenticated `mongosh --quiet --eval 'db.getSiblingDB("blogapp").posts.findOne()'` returns data.
- A DB VM has `/etc/mongod.conf.pending-auth`.

**Cause:** Environments deployed before Issue #36 run mongod without a keyFile (member-to-member authentication) and without `authorization` (client authentication). Redeploying with the new Bicep writes `/etc/mongodb/keyfile` on every DB VM. On an existing member that has data, however, it does not switch the config: it only stages the new config as `/etc/mongod.conf.pending-auth`. The three CustomScripts run in parallel, so restarting there would stop all members at once, and a member with a keyFile cannot talk to members without one. You therefore switch one member at a time, using `transitionToAuth`.

> **AWS comparison:** Amazon DocumentDB always requires authentication; you cannot turn it off. With self-managed MongoDB, as on EC2, you enable access control and manage the key yourself.

#### Step 1: Check Prerequisites

1. You have redeployed `main.bicep` with `mongoDbReplicaSetKey` set, as in Day 1 Step 4. **All three VMs use the same key.** Do not change the key in later redeployments (CustomScript fails with `mongoDbReplicaSetKey differs`).
2. The keyfile is identical on all three VMs. Connect to each DB VM through Bastion SSH and check that the hashes match (this does not print the key itself):

   ```bash
   sudo ls -l /etc/mongodb/keyfile /etc/mongod.conf.pending-auth   # -r-------- mongodb mongodb
   sudo sha256sum /etc/mongodb/keyfile | cut -c1-16
   ```

3. The admin user `blogadmin` and the app user exist. Running the latest post-deployment setup once creates or checks them (the final warning is expected at this point). The app `MONGODB_URI` already contains the user name and password.
4. Take snapshots or backups of the DB VMs, just in case.
5. Do not redeploy `main.bicep` while you work through this section.

#### Step 2: Phase 1 — Enable The keyFile With `transitionToAuth`

A member with `transitionToAuth: true` accepts connections both with and without the keyFile, so restarting one member at a time keeps the replica set and the app running. Start with the SECONDARY members (`vm-db-az3-prod` → `vm-db-az2-prod`) and do the PRIMARY (usually `vm-db-az1-prod`) last. Connect to each VM through Bastion SSH and run:

```bash
sudo cp /etc/mongod.conf /etc/mongod.conf.pre-auth
sed 's/^  authorization: enabled$/  transitionToAuth: true/' /etc/mongod.conf.pending-auth \
  | sudo tee /etc/mongod.conf > /dev/null
grep -A2 '^security:' /etc/mongod.conf    # keyFile and transitionToAuth: true
sudo systemctl restart mongod
sleep 15
sudo systemctl is-active mongod           # active
mongosh --quiet --eval 'db.hello().secondary'   # true (back as SECONDARY)
```

On the PRIMARY, hand over the PRIMARY role **before** the restart:

```bash
mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval 'rs.stepDown(300)'
```

> **Result on the former PRIMARY:** restarting mongod clears the `rs.stepDown(300)` wait period. `vm-db-az1-prod` (priority 2) therefore takes PRIMARY back as soon as it catches up, so `db.hello().secondary` may print `false`. This is expected. Everything is fine if `rs.status()` below shows 1 PRIMARY + 2 SECONDARY.

After each member, check that the set is back to 1 PRIMARY + 2 SECONDARY before moving on:

```bash
mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'
```

#### Step 3: Phase 2 — Enable `authorization`

When all three members have finished Phase 1, switch to the final config in the same order (SECONDARY members first, then the PRIMARY). On the PRIMARY, run `rs.stepDown(300)` first.

```bash
sudo mv /etc/mongod.conf.pending-auth /etc/mongod.conf
sudo systemctl restart mongod
sleep 15
sudo systemctl is-active mongod           # active
mongosh --quiet --eval 'db.hello().secondary'   # true (former PRIMARY: may be false, see above)
```

#### Step 4: Verify

```bash
mongosh --quiet --eval 'db.getSiblingDB("blogapp").posts.findOne()'   # rejected: requires authentication
mongosh -u blogadmin -p --authenticationDatabase admin --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'
```

- You can create and edit posts in the browser.
- Rerunning post-deployment setup no longer prints `mongod is running without authorization`.
- After you confirm everything works, delete `/etc/mongod.conf.pre-auth` on each VM.

**If something goes wrong:**

- mongod does not start: check `sudo tail -n 50 /data/mongodb/log/mongod.log`. For `permissions on /etc/mongodb/keyfile are too open`, run `sudo chown mongodb:mongodb /etc/mongodb/keyfile && sudo chmod 400 /etc/mongodb/keyfile`.
- A member stays `(not reachable/healthy)` and the log shows `Authentication failed`: the keyfiles differ. Compare the hashes as in Step 1, item 2, and redeploy with the same key.
- To roll back during Phase 1, run `sudo cp /etc/mongod.conf.pre-auth /etc/mongod.conf && sudo systemctl restart mongod` (one member at a time). After Phase 2 has started, first return every member to the Phase 1 config.

**If downtime is acceptable (short procedure):** in a practice environment where 1-2 minutes without writes is acceptable, you can switch all three members at once. Check Step 1, then run in Cloud Shell:

```bash
for vm in vm-db-az1-prod vm-db-az2-prod vm-db-az3-prod; do
  az vm run-command invoke -g "$RESOURCE_GROUP" -n "$vm" --command-id RunShellScript \
    --scripts 'mv /etc/mongod.conf.pending-auth /etc/mongod.conf && systemctl restart mongod && echo restarted' \
    --query "value[0].message" -o tsv &
done
wait
```

Then verify with Step 4.

> **Key rotation:** changing `mongoDbReplicaSetKey` and redeploying does not replace the key of a running member (CustomScript stops with an error). To change the key, follow MongoDB's [Rotate Keys for Self-Managed Replica Sets](https://www.mongodb.com/docs/manual/tutorial/rotate-key-replica-set/) one member at a time.

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
| Enabling ASR fails with `does not allow key based authentication and it does not have vault Managed System Identity configured` (28176) | Whether organization policy disables shared key access on the cache Storage account | Turn on the vault's system-assigned managed identity (vault > Identity), then assign it Contributor and Storage Blob Data Contributor on the cache Storage account. With Contributor only, ask the instructor to create the assignments (Day 0 Step 3.1). [Microsoft Learn](https://learn.microsoft.com/azure/site-recovery/asr-turn-off-key-authentication-cache) |
| Enable replication fails with `151141: ... version of mobility service doesn't support the operating system kernel version (...) running on the source machine` | Whether `uname -r` on the source VM is in the Mobility service's supported-kernel list for the installed agent build ([Azure/Azure-SiteRecovery `MobilityAgent/AzureToAzure/SupportedKernels`](https://github.com/Azure/Azure-SiteRecovery/tree/main/MobilityAgent/AzureToAzure/SupportedKernels)). Common when Ubuntu 24.04's rolling `linux-azure` kernel (or the DB tier's `linux-azure-lts-24.04` kernel) ships ahead of an updated supported-kernel list | Run the official kernel-module hotfix in §10.1, then disable/remove the failed replicated item and enable replication again |
| Test failover resources remain | Cleanup test failover | Run cleanup from Recovery Services vault |

### 10.1 Error 151141 (Kernel Not Yet Supported By Mobility Service)

The Mobility service agent compares the VM's exact kernel version against the supported-kernel list for the build it installed. When a new kernel patch ships (Ubuntu's `linux-azure`, or the DB tier's `linux-azure-lts-24.04`) ahead of an updated list on GitHub, Enable replication fails with 151141. Microsoft's published kernel-module hotfix ([aka.ms/asr-linux-kernel-module](https://aka.ms/asr-linux-kernel-module)) resolves it; run it **after** the failed attempt, since the agent is already installed by then.

```bash
sudo -i
mkdir -p /root/asr-drivers && cd /root/asr-drivers
wget https://raw.githubusercontent.com/Azure/Azure-SiteRecovery/main/MobilityAgent/hotfix_install.sh \
     https://raw.githubusercontent.com/Azure/Azure-SiteRecovery/main/MobilityAgent/OS_details.sh
chmod +x hotfix_install.sh OS_details.sh
./hotfix_install.sh /root/asr-drivers/
```

You can also run this with `az vm run-command invoke --command-id RunShellScript` instead of SSH. After the hotfix, disable/remove the failed replicated item and re-run Enable replication.

**Instructor pre-check:** Before the workshop, check `uname -r` on a freshly deployed Web/App/DB VM and compare it against the [supported-kernel list](https://github.com/Azure/Azure-SiteRecovery/tree/main/MobilityAgent/AzureToAzure/SupportedKernels). Ubuntu's rolling kernel updates can outpace the published list by the workshop date. If so, fold this procedure into the Day 2 Step 11 introduction.

## Next

- Commands and resource names: [Quick reference](../reference/quick-reference-card.md)
- Day 1 resource deployment: [Day 1: Azure resource deployment](../learner/day-1-deployment-checklist.md)
- Day 1 application deployment: [Day 1: Application deployment](../learner/day-1-app-deployment.md)
- Day 2 resiliency: [Day 2: Resiliency checklist](../learner/day-2-resiliency-checklist.md)

Back to the [learner portal](../index.md)