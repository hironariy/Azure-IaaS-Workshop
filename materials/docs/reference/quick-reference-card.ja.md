---
title: クイックリファレンス
---

# クイックリファレンス

## このページでやること

ワークショップ中によく使うリソース名、ポート、Cloud Shell コマンド、Portal 画面、KQL クエリを 1 ページで確認します。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 1 / Day 2 の演習中に値やコマンドを素早く確認したい受講者 |
| 所要時間 | 必要な箇所だけ 1-5 分 |
| 前提 | Day 1 のリソースグループ名が分かること |
| 完了条件 | 主要な確認コマンドと Portal の場所をすぐに参照できること |

## 作業変数

```bash
RESOURCE_GROUP="rg-blogapp-workshop"
LOCATION="japanwest"

FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)
```

複数グループの場合は、`RESOURCE_GROUP` を `rg-blogapp-A-workshop` などに変更します。

## 主要リソース名

| 種別 | 名前 |
|---|---|
| Resource group | `rg-blogapp-workshop` または `rg-blogapp-<groupId>-workshop` |
| Application Gateway | `agw-blogapp-prod` |
| Application Gateway public IP | `pip-agw-blogapp-prod` |
| Bastion | `bastion-blogapp-prod` |
| Web VM | `vm-web-az1-prod`, `vm-web-az2-prod` |
| App VM | `vm-app-az1-prod`, `vm-app-az2-prod` |
| DB VM | `vm-db-az1-prod`, `vm-db-az2-prod` |
| MongoDB replica set | `blogapp-rs0` |
| VM admin user | `azureuser` |

`groupId` は推奨リソースグループ名にだけ使われます。VM 名はグループごとに変わらないため、必ず `--resource-group` を指定します。

## ポート

| 通信 | ポート | 用途 |
|---|---:|---|
| Internet -> Application Gateway | 443 | HTTPS |
| Application Gateway -> Web VM | 80 | NGINX |
| Web VM -> Internal Load Balancer / App VM | 3000 | Express API |
| App VM -> DB VM | 27017 | MongoDB |
| Bastion -> VM | 22 | SSH |

## Bicep パラメータ対応表

| パラメータ | 値の意味 | 取得方法 |
|---|---|---|
| `sshPublicKey` | VM SSH 用公開鍵 | `cat ~/.ssh/id_rsa.pub` |
| `adminObjectId` | Key Vault 管理用の自分の object ID | `az ad signed-in-user show --query id -o tsv` |
| `entraTenantId` | Entra tenant ID | `az account show --query tenantId -o tsv` |
| `entraClientId` | Backend API app registration Client ID | Azure Portal > App registrations |
| `entraFrontendClientId` | Frontend SPA app registration Client ID | Azure Portal > App registrations |
| `sslCertificateData` | Base64 encoded PFX | `cat cert-base64.txt` |
| `sslCertificatePassword` | PFX password | 既定 `Workshop2024!` |
| `mongoDbAppPassword` | MongoDB app user password | 自分で決める強い値 |
| `appGatewayDnsLabel` | Application Gateway FQDN の DNS label | 例: `blogapp-team1-0106` |

## よく使う Cloud Shell コマンド

### Azure account

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
```

### VM 状態

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[].{name:name,powerState:powerState,privateIps:privateIps}" -o table
```

### VM 停止・起動

```bash
az vm stop --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
```

`az vm stop` はゲスト OS 停止を模擬します。`az vm deallocate` は割り当て解除まで行うため、演習では講師の指示がない限り使いません。

### Application Gateway FQDN

```bash
az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv
```

### Backend health

```bash
az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

### アプリ疎通

```bash
curl -k "https://$FQDN/"
curl -k "https://$FQDN/api/posts"
```

`-k` は自己署名証明書の検証をスキップするワークショップ用確認です。

### DCR 構成

```bash
./scripts/configure-dcr.sh "$RESOURCE_GROUP"
```

## よく開く Azure Portal 画面

| 目的 | Portal で開く場所 |
|---|---|
| デプロイ進捗 | Resource group > Deployments |
| Application Gateway 正常性 | Application Gateway > Backend health |
| VM 状態 | Virtual machines > 対象 VM > Overview |
| VM ブート診断 | Virtual machines > 対象 VM > Boot diagnostics |
| Log Analytics | Log Analytics workspace > Logs |
| DCR | Monitor > Data Collection Rules |
| Backup | Recovery Services vault > Backup items |
| Backup job | Recovery Services vault > Backup jobs |
| ASR replication | Recovery Services vault > Site Recovery > Replicated items |
| Entra app registrations | Microsoft Entra ID > App registrations |

## KQL スターター

### VM Heartbeat

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

### CPU 使用率の概要

```kusto
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCpu=avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

### Syslog の直近エラー

```kusto
Syslog
| where SeverityLevel in ("err", "crit", "alert", "emerg")
| project TimeGenerated, Computer, Facility, SeverityLevel, SyslogMessage
| order by TimeGenerated desc
| take 50
```

### Application Gateway 関連ログの探索

```kusto
search "ApplicationGateway"
| order by TimeGenerated desc
| take 50
```

実際のテーブル名は診断設定や有効化したログカテゴリにより変わります。最初は `search * | take 50` で入っているデータを確認します。

## 困ったときの戻り先

| 状況 | 戻るページ |
|---|---|
| Day 1 手順を確認したい | [Day 1: デプロイチェックリスト](../learner/day-1-deployment-checklist.ja.md) |
| Day 2 手順を確認したい | [Day 2: 回復性チェックリスト](../learner/day-2-resiliency-checklist.ja.md) |
| 症状別に調べたい | [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) |
| 監視を深掘りしたい | [監視ガイド](../operations/monitoring-guide.ja.md) |
| BCDR を深掘りしたい | [災害復旧ガイド](../operations/disaster-recovery-guide.ja.md) |

戻る: [受講者ポータル](../index.md)
