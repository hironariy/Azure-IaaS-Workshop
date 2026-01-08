# Azure IaaS ワークショップ向けレジリエンシー テスト戦略

**日付:** 2026年1月8日  
**著者:** AI Workshop Agent  
**ステータス:** Draft  
**目的:** マルチティア構成のブログアプリケーションに対する実践的なレジリエンシー テストを定義する

---

English version: [Resiliency Test Strategy for Azure IaaS Workshop](./resiliency-test-strategy.md)

## エグゼクティブ サマリー

本ドキュメントは、Azure IaaS ワークショップ向けの包括的なレジリエンシー テスト戦略をまとめたものです。これらのテストは、次を目的として設計されています。

1. **検証**: 高可用性アーキテクチャの妥当性を確認する
2. **教育**: 参加者に障害モードと復旧を理解してもらう
3. **実演**: Azure に組み込まれた回復性（resilience）機能を示す

### アーキテクチャ再掲

```
Internet → Application Gateway (Zone-redundant)
         → Web Tier: VM-AZ1 + VM-AZ2 (NGINX)
         → Internal LB
         → App Tier: VM-AZ1 + VM-AZ2 (Node.js)
         → Database Tier: Primary (AZ1) + Secondary (AZ2) (MongoDB Replica Set)
```

本書では、MongoDB の役割を **プライマリ（Primary）** / **セカンダリ（Secondary）** と表記します。

### テスト対象とする主要な回復性機能

| 機能 | コンポーネント | 期待される動作 |
|---------|-----------|-------------------|
| ロードバランサーのヘルスプローブ | Application Gateway, Internal Load Balancer | 不健全なインスタンスを除外 |
| クロスゾーン冗長性 | 全 tier | 1 つのゾーン障害を生き残る |
| MongoDB レプリカセット | Database tier | ⚠️ 手動フェイルオーバーが必要（2 メンバー制限） |
| ステートレスなアプリケーション tier | Web, App | どのインスタンスでもリクエストを処理できる |

### データベース VM の IP アドレス（静的割り当て）

Bicep テンプレートは、DB VM に **静的なプライベート IP** を割り当て、レプリカセット構成を予測可能にします。

| VM 名 | 可用性ゾーン | プライベート IP | MongoDB ロール（初期） |
|---------|-------------------|------------|------------------------|
| `vm-db-az1-prod` | ゾーン 1 | `10.0.3.4` | プライマリ（Primary） |
| `vm-db-az2-prod` | ゾーン 2 | `10.0.3.5` | セカンダリ（Secondary） |

> **Note:** 静的 IP は `modules/compute/db-tier.bicep` のパラメータで定義されています:
> - `dbVmAz1PrivateIp` = `10.0.3.4`
> - `dbVmAz2PrivateIp` = `10.0.3.5`

---

## テストカテゴリ

### レベル 1: 初級（安全・可逆）
- VM stop/start
- アプリケーション プロセス stop/start
- 基本的なヘルスチェック検証

### レベル 2: 中級（監視が必要）
- DB フェイルオーバー
- ヘルスプローブの操作
- トラフィック分散の検証

### レベル 3: 上級（計画が必要）
- ゾーン障害のシミュレーション
- ネットワーク分断
- カオス エンジニアリング

---

## レベル 1: 初級テスト

### テスト 1.1: Web tier VM 障害

**目的:** Application Gateway が障害 VM をバックエンド プールから除外することを確認する。

**前提条件:**
- アプリケーションがデプロイ済みでアクセス可能
- 両方の Web VM が稼働中かつ正常
- ブラウザまたは curl でアプリにアクセスできる

**手順:**

```bash
# 1. Verify both Web VMs are healthy
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# Expected output: Both servers show "Healthy"
# [
#   { "address": "10.0.1.4", "health": "Healthy" },
#   { "address": "10.0.1.5", "health": "Healthy" }
# ]

# 2. Open application in browser and verify it works
curl -k https://<YOUR_APPGW_FQDN>/

# 3. Stop one Web VM
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod

# 4. Wait for health probe to detect failure (30-60 seconds)
sleep 60

# 5. Verify application still works
curl -k https://<YOUR_APPGW_FQDN>/

# 6. Check backend health (one should be unhealthy)
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# 7. Restore the VM
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod

# 8. Wait for VM to become healthy again
sleep 120

# 9. Verify both VMs are healthy
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'
```

**期待される結果:**
| 手順 | 期待される結果 |
|------|------------------|
| Step 2 | HTML 応答（200 OK） |
| Step 5 | HTML 応答（200 OK） - 継続して動作する |
| Step 6 | 片方が "Unhealthy"、片方が "Healthy" |
| Step 9 | 両方が "Healthy" |

**学習ポイント:**
- Application Gateway はヘルスプローブにより VM 障害を自動検知する
- トラフィックは正常なインスタンスにのみルーティングされる
- フェイルオーバーに手動介入は不要
- VM が正常に戻ると自動で復旧する

---

### テスト 1.2: App tier VM 障害

**目的:** Internal Load Balancer が障害 VM をバックエンド プールから除外することを確認する。

**手順:**

```bash
# 1. Connect to a Web VM to test Internal LB
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. From Web VM, test API through Internal LB
curl http://10.0.2.10:3000/health
# Expected: {"status":"healthy",...}

# 3. Exit Web VM session
exit

# 4. Stop one App VM
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod

# 5. Wait for health probe (30-60 seconds)
sleep 60

# 6. Reconnect to Web VM and test API via Internal LB
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# Test backend health directly via Internal LB (not through NGINX /api/ proxy)
curl http://10.0.2.10:3000/health
# Expected: Still returns {"status":"healthy",...}

# 7. Test from browser - full application should work
exit
# Test API endpoint (not health - backend health is at /health, not /api/health)
curl -k https://<YOUR_APPGW_FQDN>/api/posts

# 8. Restore the VM
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod
```

**期待される結果:**
- App VM が 1 台停止しても API は継続して動作する
- Internal Load Balancer のヘルスプローブが障害を検知する
- トラフィックは残存する正常な App VM にルーティングされる

---

### テスト 1.3: アプリケーション プロセス障害（NGINX）

**目的:** VM 障害だけでなくアプリケーション レベルの障害もヘルスプローブが検知できることを確認する。

**このテストが重要な理由:**
- VM が完全に落ちるケースは比較的まれ
- 実際にはアプリケーションが落ちるケースのほうが頻繁
- ヘルスプローブはネットワーク疎通ではなくアプリケーションの健全性を検知すべき

**手順:**

```bash
# 1. Connect to Web VM
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Verify NGINX is running
sudo systemctl status nginx

# 3. Stop NGINX (application crashes)
sudo systemctl stop nginx

# 4. Verify local health check fails
curl http://localhost/health
# Expected: Connection refused

# 5. Exit and wait for health probe
exit
sleep 60

# 6. Test application - should still work (via other VM)
curl -k https://<YOUR_APPGW_FQDN>/

# 7. Reconnect and restart NGINX
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

sudo systemctl start nginx

# 8. Verify recovery
curl http://localhost/api/posts
# Expected: healthy
```

**学習ポイント:**
- ヘルスプローブは VM 障害だけでなくアプリケーション障害も検知する
- VM stop よりもプロセス stop のほうが現実に近い
- アプリケーション レベルのヘルスチェックによる多層防御を示せる

---

### テスト 1.4: アプリケーション プロセス障害（Node.js/PM2）

**目的:** Internal Load Balancer が Node.js アプリケーション障害を検知できることを確認する。

**手順:**

```bash
# 1. Connect to App VM
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-app-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Check PM2 status
pm2 list

# 3. Stop the application
pm2 stop blogapp-api

# 4. Verify local health check fails
curl http://localhost:3000/health
# Expected: Connection refused

# 5. Exit and test through Application Gateway
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Still works (via other App VM)
# Note: Use /api/posts because backend health is at /health, not /api/health

# 6. Reconnect and restart application
az network bastion ssh ... # same as above
pm2 start blogapp-api
pm2 list  # Verify running
```

---

## レベル 2: 中級テスト

### テスト 2.1: MongoDB プライマリ フェイルオーバー

**目的:** MongoDB レプリカセットの自動フェイルオーバーを確認する。

**前提条件:**
- 2 メンバーで MongoDB レプリカセットが初期化済み
- アプリケーションがレプリカセットへ接続済み

**手順:**

```bash
# 1. Connect to current primary (vm-db-az1-prod by default)
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-db-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Check current replica set status
mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
# Expected (with static IP assignment from Bicep):
# [
#   { name: "10.0.3.4:27017", state: "PRIMARY" },   # vm-db-az1-prod (Zone 1)
#   { name: "10.0.3.5:27017", state: "SECONDARY" }  # vm-db-az2-prod (Zone 2)
# ]

# 3. Force primary to step down (triggers election)
mongosh --eval 'rs.stepDown(60)'
# This forces the primary to become secondary for 60 seconds

# 4. Check new status (secondary should become primary)
mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
# Expected:
# [
#   { name: "10.0.3.4:27017", state: "SECONDARY" },  # vm-db-az1-prod
#   { name: "10.0.3.5:27017", state: "PRIMARY" }     # vm-db-az2-prod (now primary)
# ]

# 5. Exit and test application
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Still returns posts (application reconnected to new primary)

# 6. Create a new post to verify writes work
# Use browser or API call with authentication

# 7. Verify data on both members
az network bastion ssh ... # connect to vm-db-az2-prod
mongosh --eval 'db.posts.countDocuments()'
```

**期待される結果:**
| 手順 | 期待される結果 |
|------|------------------|
| Step 3 | プライマリが step down し、選挙（election）が開始される |
| Step 4 | 新しいプライマリが選出される（通常 10-15 秒以内） |
| Step 5 | アプリケーションは継続して動作する |
| Step 6 | 新規投稿（書き込み）が可能 |

**学習ポイント:**
- MongoDB レプリカセットは自動フェイルオーバーを提供する
- レプリカセット接続文字列を使用するアプリケーションはフェイルオーバーを透過的に扱える
- 選挙は通常 10-15 秒で完了する
- 選挙中は書き込みができない（短い停止ウィンドウ）

---

### テスト 2.2: MongoDB プライマリ VM Stop（任意 - 上級）

**目的:** プライマリ VM が完全に利用不能になった場合の MongoDB レプリカセット挙動を理解する。

> ⏱️ **Optional Test** - このテストは手動復旧（テスト 2.2a）が必要で、15-30 分かかる場合があります。時間が限られる場合はスキップしてください。

> ⚠️ **Critical Limitation: 2-Member Replica Set**
>
> 2 メンバーのみの場合、プライマリが停止すると **自動フェイルオーバーは発生しません**。
> MongoDB は新しいプライマリを選出するために **過半数投票** を必要とします:
>
> | Members | Majority Needed | When 1 Down | Result |
> |---------|-----------------|-------------|--------|
> | 2 | 2 | Only 1 vote | ❌ No election possible |
> | 3 | 2 | 2 votes | ✅ Can elect new primary |
>
> 生存するセカンダリは単独で過半数に到達できないためセカンダリ（SECONDARY）のままになります。
> **このテストは制限を実演し、手動復旧を学ぶためのものです。**

**手順:**

```bash
# 1. Identify current primary
az network bastion ssh ... # connect to any DB VM
mongosh --eval 'rs.isMaster().primary'
# Note which VM is primary (assume 10.0.3.4 / vm-db-az1-prod)

# 2. Stop the primary VM (from your local machine)
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod

# 3. Wait and observe
sleep 20

# 4. Connect to other DB VM and check status
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-db-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

mongosh --eval 'rs.isMaster().ismaster'
# Expected: false (NOT true!) - cannot self-elect without majority

mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
# Expected:
# [
#   { name: "10.0.3.4:27017", state: "(not reachable/healthy)" },  # vm-db-az1-prod (stopped)
#   { name: "10.0.3.5:27017", state: "SECONDARY" }  # vm-db-az2-prod - Still secondary!
# ]

# 5. Test application - READS WILL FAIL (no primary)
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Error - application cannot connect to primary for reads
```

**期待される結果（手動介入なし）:**
| 手順 | 期待される結果 |
|------|------------------|
| Step 4 | `rs.isMaster().ismaster` が **false** を返す |
| Step 5 | アプリケーションがエラーを返す（プライマリ不在） |

---

### テスト 2.2a: MongoDB の手動復旧（任意 - 上級）

**目的:** 生存するセカンダリを手動でプライマリに昇格させる方法を学ぶ。

> ⏱️ **Optional Test** - これはテスト 2.2 / テスト 3.1 の復旧手順です。これらをスキップした場合は本手順もスキップしてください。

**使用する場面:** プライマリ VM がダウンし、2 メンバー制限により自動選出ができない場合。

**復旧手順:**

```bash
# 1. Connect to the surviving secondary (vm-db-az2-prod)
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-db-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# 2. Connect to MongoDB and check current status
mongosh

# 3. View current configuration
rs.status()

# 4. Get current replica set configuration
cfg = rs.conf()

# 5. Remove the unavailable member from configuration
# If vm-db-az1-prod (10.0.3.4) is stopped:
cfg.members = cfg.members.filter(m => m.host !== "10.0.3.4:27017")
# If vm-db-az2-prod (10.0.3.5) is stopped instead:
# cfg.members = cfg.members.filter(m => m.host !== "10.0.3.5:27017")

# 6. Force reconfigure (bypasses "need a primary" requirement)
rs.reconfig(cfg, {force: true})

# 7. Verify this node is now PRIMARY
rs.isMaster().ismaster
# Expected: true

rs.status()
# Expected: Single member showing as PRIMARY

# 8. Exit MongoDB shell and test application
exit  # from mongosh
exit  # from SSH

curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Success! Application works again
```

**元のプライマリ VM を起動した後 - レプリカセットへ再追加:**

```bash
# 1. Start the original primary VM
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod

# 2. Wait for VM to fully start
sleep 60

# 3. Connect to the current primary (vm-db-az2-prod)
az network bastion ssh ... # connect to vm-db-az2-prod
mongosh

# 4. Re-add the recovered VM as a new member
# Add back vm-db-az1-prod:
rs.add("10.0.3.4:27017")

# 5. Verify both members are present
rs.status().members.map(m => ({name: m.name, state: m.stateStr}))
# Expected:
# [
#   { name: "10.0.3.5:27017", state: "PRIMARY" },     # vm-db-az2-prod (current primary)
#   { name: "10.0.3.4:27017", state: "SECONDARY" }    # vm-db-az1-prod (rejoined)
# ]

# 6. Exit and verify application
exit
exit
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**重要事項:**
- 元のプライマリは **SECONDARY**（セカンダリ）として復帰します（リーダーシップを取り戻しません）
- 旧プライマリのみに存在し、ダウン前に他メンバーへ複製されていない書き込みは **失われます**
- そのため本番システムでは **3+ メンバー**、または **2 データ + 1 arbiter** を使用します

**学習ポイント:**
- 2 メンバーのレプリカセットは自動フェイルオーバーできない
- `rs.reconfig({force: true})` によりプライマリ不在でも再構成が可能
- 災害復旧には手動介入が必要
- 本番推奨: 3 メンバー、または arbiter の追加

---

### テスト 2.3: トラフィック分散の確認

**目的:** ロードバランサーが複数インスタンスにトラフィックを分散することを確認する。

**手順:**

```bash
# 1. Connect to both Web VMs and tail access logs

# Terminal 1: Web VM AZ1
az network bastion ssh ... --name vm-web-az1-prod
sudo tail -f /var/log/nginx/access.log

# Terminal 2: Web VM AZ2
az network bastion ssh ... --name vm-web-az2-prod
sudo tail -f /var/log/nginx/access.log

# 2. Generate traffic from your machine
for i in {1..20}; do
  curl -k https://<YOUR_APPGW_FQDN>/ > /dev/null 2>&1
  sleep 1
done

# 3. Observe logs in both terminals
# You should see requests appearing in BOTH logs
# Distribution may not be exactly 50/50 but should be balanced
```

**期待される結果:**
- 両方の Web VM のログにリクエストが出現する
- 分散は概ねバランスしている（厳密に 50/50 でなくてよい）
- Application Gateway のロードバランシングを確認できる

---

### テスト 2.4: ヘルスプローブの操作

**目的:** ヘルスプローブがトラフィック ルーティングに与える影響を理解する。

**手順:**

```bash
# 1. Connect to Web VM
az network bastion ssh ... --name vm-web-az1-prod

# 2. Modify health endpoint to return error
# Edit the NGINX site configuration (location must be inside server block)
sudo nano /etc/nginx/sites-enabled/default

# Add this block INSIDE the server { } block, BEFORE other location blocks:
# location = /health {
#     return 503 "unhealthy";
#     add_header Content-Type text/plain;
# }

# Or use sed to insert after "server {" line:
sudo sed -i '/server {/a \    location = /health { return 503 "unhealthy"; add_header Content-Type text/plain; }' /etc/nginx/sites-enabled/default

sudo nginx -t && sudo systemctl reload nginx

# 3. Verify local health check fails
curl -I http://localhost/health
# Expected: HTTP 503

# 4. Exit and wait for health probe
exit
sleep 60

# 5. Check backend health
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod \
  --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[].{address:address,health:health}'

# Expected: 10.0.1.4 shows "Unhealthy"

# 6. Test application - should still work
curl -k https://<YOUR_APPGW_FQDN>/

# 7. Restore health endpoint
az network bastion ssh ... --name vm-web-az1-prod
# Remove the health override line
sudo sed -i '/location = \/health { return 503/d' /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
curl http://localhost/health
# Expected: healthy
```

**学習ポイント:**
- ヘルスプローブはアプリケーションのヘルス エンドポイントをチェックする
- 2xx 以外を返すとインスタンスが除外される
- VM やプロセスを落とすよりも局所的で安全
- グレースフル デプロイ（更新前に drain）などに有用

---

## レベル 3: 上級テスト

### テスト 3.1: ゾーン障害のシミュレーション（任意 - 上級）

**目的:** ゾーン全体の停止を想定してもアプリケーションが継続できることを確認する。

> ⏱️ **Optional Test** - このテストは MongoDB の手動復旧が必要で、15-30 分かかる場合があります。時間が限られる場合はスキップしてください。Web / App tier のフェイルオーバーは、より簡単なテスト（1.1、1.2）でも観察できます。

**なぜ "simulate" なのか？**
- Azure 利用者は実際のゾーン障害を発生させられない
- ただし、1 つのゾーンにあるリソースをまとめて停止することで擬似的に再現できる

**手順:**

```bash
# 1. Document which resources are in Zone 1 (with static IPs from Bicep)
# - vm-web-az1-prod (10.0.1.4) - Web tier
# - vm-app-az1-prod (10.0.2.4) - App tier
# - vm-db-az1-prod (10.0.3.4)  - Database tier (MongoDB primary)

# 2. Verify application works before test
curl -k https://<YOUR_APPGW_FQDN>/
curl -k https://<YOUR_APPGW_FQDN>/api/posts

# 3. Stop ALL Zone 1 VMs simultaneously
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod --no-wait
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod --no-wait
az vm stop --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod --no-wait

# 4. Wait for failures to be detected
echo "Waiting 90 seconds for health probes..."
sleep 90

# 5. Test application - should still work!
curl -k https://<YOUR_APPGW_FQDN>/
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Note: Backend health endpoint is at /health (not /api/health)
# To test backend health, connect to remaining App VM and run: curl http://localhost:3000/health

# 6. Verify by checking which instances are serving
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod

# 7. Test database (connect to Zone 2 DB)
az network bastion ssh ... --name vm-db-az2-prod
mongosh --eval 'rs.isMaster().ismaster'
# Expected: false (2-member replica set cannot auto-elect!)
# See Test 2.2a for manual recovery procedure

# 7a. Manual recovery required for database writes
# Follow Test 2.2a steps to force reconfigure replica set:
mongosh
cfg = rs.conf()
cfg.members = cfg.members.filter(m => m.host !== "10.0.3.4:27017")
rs.reconfig(cfg, {force: true})
rs.isMaster().ismaster  # Now returns true
exit

# 8. After manual recovery, create new data to verify writes work
# Use browser to create a post

# 9. Restore Zone 1 resources
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-web-az1-prod --no-wait
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-app-az1-prod --no-wait
az vm start --resource-group <YOUR_RESOURCE_GROUP> --name vm-db-az1-prod --no-wait

# 10. Wait for recovery
echo "Waiting 120 seconds for VMs to start and rejoin..."
sleep 120

# 11. Verify all healthy
az network application-gateway show-backend-health \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name agw-blogapp-prod
```

**期待される結果:**
| コンポーネント | ゾーン 1 停止時 | 復旧 |
|-----------|-------------|----------|
| Web tier | vm-web-az2-prod が提供 | 両方の VM が healthy |
| App tier | vm-app-az2-prod が提供 | 両方の VM が healthy |
| Database | ⚠️ **手動介入が必要**（2 メンバー RS） | 再追加後、元プライマリはセカンダリとして復帰 |
| Application | **DB 手動復旧まで READ は失敗** | 完全復旧 |

> ⚠️ **2-Member Replica Set Limitation**
>
> Web / App tier は自動フェイルオーバーしますが、2 メンバーの DB レプリカセットは
> 片方がダウンすると **新しいプライマリを自動選出できません**。
> これは MongoDB のクォーラム要件によるものです。手動復旧はテスト 2.2a を参照してください。
>
> **本番推奨:** 自動フェイルオーバーのために arbiter（アービター）を追加してください。

**学習ポイント:**
- クロスゾーン設計によりゾーン全体の停止を生き残れる
- MongoDB の選挙（election）は自動で行われる
- ロードバランサーが障害インスタンスを避けてルーティングする
- ゾーン内リソースが戻ると自動で復旧する

---

### テスト 3.2: ネットワーク分断（NSG ベース）

**目的:** tier 間のネットワーク接続が失われた場合の挙動をテストする。

**注意:** 適切に元に戻さないと長時間の停止につながる可能性があります。

**テスト: App tier → Database tier をブロック**

```bash
# 1. Create NSG rule to block MongoDB traffic
az network nsg rule create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --nsg-name nsg-app-prod \
  --name DenyMongoDB \
  --priority 100 \
  --access Deny \
  --direction Outbound \
  --destination-address-prefixes 10.0.3.0/24 \
  --destination-port-ranges 27017 \
  --protocol Tcp

# 2. Test application
curl -k https://<YOUR_APPGW_FQDN>/api/posts
# Expected: Error (database unreachable)

# 3. Check application logs
az network bastion ssh ... --name vm-app-az1-prod
pm2 logs blogapp-api --lines 50
# Look for MongoDB connection errors

# 4. Remove the blocking rule
az network nsg rule delete \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --nsg-name nsg-app-prod \
  --name DenyMongoDB

# 5. Verify recovery
sleep 30
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**学習ポイント:**
- ネットワーク障害はアプリケーション障害につながる
- 適切なエラーハンドリングはユーザーフレンドリな表示につながる
- 接続リトライ ロジックが復旧に役立つ
- NSG ルールによりテストのために問題を切り分け・隔離できる

---

### テスト 3.3: Azure Chaos Studio（任意）

**目的:** Azure のマネージド カオス エンジニアリング サービスを使用する。

**前提条件:**
- Azure Chaos Studio が有効化されている
- 適切な権限（Contributor + Chaos 固有のロール）

**手動テストに対する利点:**
- スケジュールされたカオス実験
- 自動ロールバック
- Azure Monitor との統合
- 実験の監査証跡

**サンプル実験: VM シャットダウン**

```bash
# 1. Register resource provider
az provider register --namespace Microsoft.Chaos

# 2. Enable target VM for chaos
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Compute/virtualMachines/vm-web-az1-prod/providers/Microsoft.Chaos/targets/Microsoft-VirtualMachine?api-version=2023-11-01" \
  --body '{"properties":{}}'

# 3. Create experiment (via Portal or ARM template)
# See: https://docs.microsoft.com/azure/chaos-studio/
```

**利用可能な Fault 種別:**
| Fault | Target | Description |
|-------|--------|-------------|
| VM Shutdown | Virtual Machine | Power off VM |
| CPU Pressure | Virtual Machine | Consume CPU |
| Memory Pressure | Virtual Machine | Consume memory |
| Network Disconnect | Virtual Machine | Block network |
| Disk I/O Pressure | Virtual Machine | Slow disk operations |

---

## テスト中の監視と検証

### テスト中に監視するもの

| メトリック | ツール | 見るべきポイント |
|--------|------|------------------|
| バックエンド健全性 | `az network application-gateway show-backend-health` | Healthy/Unhealthy 状態 |
| アプリ応答 | `curl` | HTTP ステータス、応答時間 |
| MongoDB 状態 | `mongosh rs.status()` | メンバー状態、選挙イベント |
| アプリログ | `pm2 logs`, NGINX logs | エラー、再接続メッセージ |
| Azure Monitor | Portal → Metrics | リクエスト数、応答時間、エラー |

### 成功基準

| テスト | 成功条件 |
|------|------------|
| VM 障害 | アプリが応答する（フェイルオーバー中に短時間エラーが出る場合あり） |
| プロセス障害 | ヘルスプローブが除外後もアプリが継続 |
| DB フェイルオーバー | 30 秒以内に新しいプライマリへ再接続 |
| ゾーン障害 | 縮退運転でもアプリが継続 |
| ネットワーク分断 | エラーを適切に表示し、復旧後に回復 |

---

## ワークショップ向けテスト チェックリスト

### 初級（全参加者に推奨）

- [ ] **テスト 1.1**: Web VM を停止し、Application Gateway のフェイルオーバーを確認
- [ ] **テスト 1.2**: App VM を停止し、Internal Load Balancer のフェイルオーバーを確認
- [ ] **テスト 1.3**: NGINX プロセスを停止し、ヘルスプローブ検知を確認
- [ ] **テスト 1.4**: Node.js プロセスを停止し、ヘルスプローブ検知を確認

### 中級（時間に余裕のある参加者向け）

- [ ] **テスト 2.1**: MongoDB stepDown により自動選出を確認
- [ ] **テスト 2.2**: *(任意)* DB プライマリ VM を停止し、2 メンバー RS 制限を観察
- [ ] **テスト 2.2a**: *(任意)* MongoDB 手動復旧（強制 reconfig）
- [ ] **テスト 2.3**: VM 間のトラフィック分散を確認
- [ ] **テスト 2.4**: ヘルスエンドポイントを操作してプールから除外されることを確認

### 上級（経験者向け）

- [ ] **テスト 3.1**: *(任意)* ゾーン障害シミュレーション（DB 手動復旧が必要）
- [ ] **テスト 3.2**: NSG によるネットワーク分断
- [ ] **テスト 3.3**: *(任意)* Azure Chaos Studio 実験（有効化されている場合）

---

## 復旧手順

### アプリケーションが利用不能になった場合

1. **バックエンド健全性を確認**
   ```bash
   az network application-gateway show-backend-health -g <RG> -n agw-blogapp-prod
   ```

2. **停止した VM を起動**
   ```bash
   az vm start -g <RG> -n vm-web-az1-prod
   az vm start -g <RG> -n vm-web-az2-prod
   az vm start -g <RG> -n vm-app-az1-prod
   az vm start -g <RG> -n vm-app-az2-prod
   ```

3. **アプリケーション プロセスを再起動**
   ```bash
   # On Web VMs
   sudo systemctl start nginx
   
   # On App VMs
   pm2 start blogapp-api
   ```

4. **MongoDB レプリカセットを確認**
   ```bash
   mongosh --eval 'rs.status()'
   ```

### MongoDB に問題がある場合

1. **両 DB VM でレプリカセット状態を確認**
   ```bash
   mongosh --eval 'rs.status().members.map(m => ({name: m.name, state: m.stateStr}))'
   ```

2. **プライマリ不在（2 メンバー制限）の場合は強制 reconfig:**
   ```bash
   mongosh
   cfg = rs.conf()
   # Remove unavailable member (adjust IP based on which VM is down)
   # vm-db-az1-prod = 10.0.3.4, vm-db-az2-prod = 10.0.3.5
   cfg.members = cfg.members.filter(m => m.host !== "10.0.3.4:27017")  # if az1 is down
   # cfg.members = cfg.members.filter(m => m.host !== "10.0.3.5:27017")  # if az2 is down
   rs.reconfig(cfg, {force: true})
   rs.isMaster().ismaster  # Should return true now
   ```

3. **VM 起動後に復旧したメンバーを再追加:**
   ```bash
   mongosh
   # Add back the recovered VM (use the IP of the VM you just started)
   rs.add("10.0.3.4:27017")  # if vm-db-az1-prod was recovered
   # rs.add("10.0.3.5:27017")  # if vm-db-az2-prod was recovered
   rs.status()  # Verify both members present
   ```

4. **`/data/mongodb/log/mongod.log` を確認してエラーを調べる**

---

## まとめ

このレジリエンシー テスト戦略は、以下を提供します。

1. **初級から上級までの段階的アプローチ**
2. **期待結果を含む明確な手順**
3. **本番障害に近い現実的なシナリオ**
4. **Azure の HA パターンの学習機会**
5. **安全な復旧手順**（テスト後のクリーンアップ）

以下を備えた適切なマルチティア アプリケーションは、
- ロードバランサーのヘルスプローブ
- クロスゾーン冗長性
- データベース複製

により、さまざまな障害モードを手動介入なしで乗り切れることを示します。
