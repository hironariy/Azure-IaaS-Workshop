---
title: トラブルシューティングランブック
---

# トラブルシューティングランブック

## このページでやること

ワークショップ中に起きやすい問題を、症状から確認箇所、対処へ順番に切り分けます。調査は原則として外側から内側へ、つまり Application Gateway、Web tier、App tier、DB tier の順に進めます。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 1 / Day 2 の演習でエラーや想定外の状態に遭遇した受講者 |
| 所要時間 | 症状ごとに 5-15 分 |
| 前提 | Cloud Shell Bash、対象リソースグループ名、Application Gateway FQDN |
| 完了条件 | 症状に対して、どの層を確認すべきか説明し、次の確認コマンドまたは Portal 画面に進めること |

## 最初に設定する変数

```bash
RESOURCE_GROUP="rg-blogapp-workshop"
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv 2>/dev/null || true)
```

複数グループ構成の場合は、講師から指定されたリソースグループ名に置き換えます。

## 切り分けの基本順序

1. **入口:** Application Gateway の URL に到達できるか。
2. **Web tier:** Web VM と NGINX が応答しているか。
3. **App tier:** App VM と Express API が応答しているか。
4. **DB tier:** MongoDB レプリカセットと接続文字列が正常か。
5. **認証:** Entra ID アプリ登録、API permission、redirect URI が正しいか。
6. **監視:** Log Analytics に Heartbeat / Perf / Syslog が入っているか。

## 1. Bicep deployment が失敗した

| 確認すること | コマンドまたは画面 |
|---|---|
| 失敗した deployment operation | Azure Portal > Resource group > Deployments > failed deployment |
| CLI のエラー詳細 | `az deployment operation group list --resource-group "$RESOURCE_GROUP" --name main -o table` |
| VM SKU availability | `az vm list-skus --location japanwest --size Standard_B -o table` |
| DNS label 重複 | `appGatewayDnsLabel` を別の一意な値に変更 |
| パラメータ未設定 | `materials/bicep/main.local.bicepparam` の空文字を確認 |

**よくある対処:**

- `QuotaExceeded`: Day 0 のクォータ確認に戻り、講師へ相談します。
- `DnsRecordInUse`: `appGatewayDnsLabel` にランダムな suffix を追加します。
- `InvalidTemplate` / `InvalidParameter`: `main.local.bicepparam` の引用符、空値、貼り付けた証明書データを確認します。
- `SkuNotAvailable`: `webVmSize`、`appVmSize`、`dbVmSize` を利用可能な代替 SKU に変更します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/troubleshooting-deployment-failure.png`
> - Capture target: Resource group deployment error details page
> - Purpose: デプロイ失敗時に error details を確認する場所を示す
> - Suggested alt text: Azure deployment error details page in a resource group
> - Insertion note: エラーメッセージの構造が分かる状態を撮影する。実 ID はマスクする
> - Mask: サブスクリプション ID、テナント ID、リソース名に含まれる個人情報、アカウント名

## 2. クォータ不足で VM が作れない

```bash
az vm list-usage --location japanwest \
  --query "[?contains(name.value, 'standardBASv2Family') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

**判断:** このワークショップでは Basv2 シリーズで合計 16 vCPU が必要です。

**対処:**

1. 講師に不足している quota 名と現在値を共有します。
2. 別リージョンへ切り替えるか、クォータ増加申請を行います。
3. 講師が許可した場合のみ、`main.local.bicepparam` の VM size を代替 SKU に変更します。

## 3. Entra ID アプリ登録を作成できない

**症状:**

- App registrations の **New registration** が押せない。
- 権限エラーが表示される。

**確認すること:**

- 自分が正しいテナントにいるか。
- テナントで「ユーザーはアプリケーションを登録できる」が許可されているか。
- アプリケーション開発者、クラウドアプリケーション管理者、グローバル管理者のいずれかのロールがあるか。

**対処:**

- 講師に相談し、事前作成された Frontend SPA Client ID、Backend API Client ID、Tenant ID を受け取ります。
- 受け取った値を `main.local.bicepparam` に設定します。

## 4. ログインまたは API 呼び出しが認証エラーになる

| 症状 | 確認すること | 対処 |
|---|---|---|
| `AADSTS9002326` | フロントエンドアプリの platform が SPA か | Authentication で SPA redirect URI を設定し、Web platform を使わない |
| redirect URI mismatch | `https://<FQDN>` と `https://<FQDN>/` が登録済みか | フロントエンド SPA の redirect URI に追加 |
| API 403 / invalid audience | backend API の Client ID と scope | `entraClientId` と API permission を確認 |
| consent required | API permission の同意状態 | 管理者が必要な場合は講師へ相談 |

**確認先:** Azure Portal > Microsoft Entra ID > App registrations

## 5. Application Gateway が 502 / 503 を返す

まず backend health を確認します。

```bash
az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

**確認すること:**

- Web VM が running か。
- NGINX が起動しているか。
- NSG で Application Gateway subnet から Web subnet への通信が許可されているか。
- 証明書警告をブラウザ側で通過しているか。

Portal での確認は Day 1 の backend health プレースホルダと同じ画面です。

**対処例:**

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[].{name:name,powerState:powerState}" -o table

az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az2-prod
```

## 6. API は動かないが Web 画面は表示される

**確認すること:**

- App VM が running か。
- 内部 Load Balancer の backend が正常か。
- App VM の Node.js / PM2 プロセスが起動しているか。
- `mongoDbAppPassword` と post-deployment script の `APP_PASSWORD` が一致しているか。

**Cloud Shell での初期確認:**

```bash
curl -k "https://$FQDN/api/posts"
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?contains(name, 'vm-app')].{name:name,powerState:powerState}" -o table
```

**対処:** App VM が停止している場合は起動します。MongoDB 接続エラーが疑われる場合は、post-deployment setup のパスワード同期を確認します。

## 7. DB connection timeout が発生する

**確認すること:**

- DB VM が running か。
- MongoDB レプリカセットの primary が存在するか。
- App subnet から DB subnet の 27017/TCP が許可されているか。
- post-deployment setup が完了しているか。

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?contains(name, 'vm-db')].{name:name,powerState:powerState}" -o table
```

**対処:**

- DB VM が停止していれば起動します。
- Day 1 の post-deployment setup を再確認します。
- パスワード不一致が疑われる場合は `main.local.bicepparam` と `post-deployment-setup.local.sh` の値を照合します。

## 8. Cloud Shell が切断された

**対処:**

```bash
cd ~/Azure-IaaS-Workshop
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

デプロイ中だった場合は、Portal で Resource group > Deployments を開きます。Cloud Shell の切断だけで Azure deployment が止まるとは限りません。

## 9. Log Analytics にデータが出ない

**確認すること:**

- `scripts/configure-dcr.sh "$RESOURCE_GROUP"` が成功したか。
- VM に DCR が関連付いているか。
- Log Analytics workspace のテーブル初期化後に数分待ったか。

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

**対処:** 新規 workspace では Syslog / Perf table の初期化に 1-5 分かかります。時間を置いて DCR スクリプトを再実行します。

## 10. Day 2 の Backup / ASR が進まない

| 症状 | 確認すること | 対処 |
|---|---|---|
| Backup item が出ない | Recovery Services vault と VM の選択 | Backup の有効化手順を再確認 |
| Backup job が遅い | 初回バックアップかどうか | 講師の指示に従い、代表 VM のみで進める |
| ASR initial replication が終わらない | Replication health と進捗 | Test failover は講師デモまたは設計説明に切り替える |
| Test failover リソースが残った | Cleanup test failover 実行有無 | Recovery Services vault から cleanup を実行 |

## 次に進む

- コマンドやリソース名は [クイックリファレンス](../reference/quick-reference-card.ja.md) を参照します。
- Day 1 の手順は [Day 1: デプロイチェックリスト](../learner/day-1-deployment-checklist.ja.md) に戻ります。
- Day 2 の手順は [Day 2: 回復性チェックリスト](../learner/day-2-resiliency-checklist.ja.md) に戻ります。

戻る: [受講者ポータル](../index.md)
