---
title: "Day 1: デプロイチェックリスト"
---

# Day 1: デプロイチェックリスト

## このページでやること

Azure Cloud Shell Bash を使って、Bicep パラメータ作成、Azure IaaS 環境のデプロイ、デプロイ後セットアップ、アプリケーション疎通確認、監視確認までを進めます。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 0 の事前準備を終えた受講者 |
| 所要時間 | 60-120 分 |
| 前提 | Cloud Shell Bash、Entra ID アプリ登録値、VM クォータ、GitHub リポジトリのコピー |
| 完了条件 | Bicep deployment が `Succeeded` になり、Application Gateway 経由の動作確認と Log Analytics の基本確認ができること |

## 0. 作業変数を決める

Cloud Shell でリポジトリルートに移動し、作業変数を設定します。

```bash
cd ~/Azure-IaaS-Workshop

LOCATION="japanwest"
RESOURCE_GROUP="rg-blogapp-workshop"
```

複数グループで同じサブスクリプションを使う場合は、講師から割り当てられたグループ ID をリソースグループ名に含めます。

| グループ | リソースグループ名 |
|---|---|
| A | `rg-blogapp-A-workshop` |
| B | `rg-blogapp-B-workshop` |
| C | `rg-blogapp-C-workshop` |

**期待結果:** 自分が使うリソースグループ名を説明できます。

## 1. Azure CLI の状態を確認する

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

**チェックポイント:** Day 0 で控えた Tenant ID と一致していることを確認します。

## 2. SSH 鍵を準備する

Cloud Shell 内に SSH 鍵がない場合は作成します。

```bash
ssh-keygen -t rsa -b 4096 -C "workshop@azure"
cat ~/.ssh/id_rsa.pub
```

**期待結果:** `ssh-rsa` で始まる公開鍵を取得できます。

**チェックポイント:** `main.local.bicepparam` に貼るのは公開鍵です。秘密鍵は Cloud Shell 内に保持し、GitHub に push しません。

## 3. SSL 証明書を生成する

```bash
chmod +x scripts/generate-ssl-cert.sh
./scripts/generate-ssl-cert.sh
```

確認します。

```bash
ls -l cert.pfx cert-base64.txt
```

**期待結果:** `cert.pfx` と `cert-base64.txt` が作成されます。

**チェックポイント:** `sslCertificatePassword` は、スクリプト既定の `Workshop2024!` と一致させます。自己署名証明書のため、ブラウザ警告は想定内です。

## 4. Bicep パラメータファイルを作成する

```bash
cd materials/bicep
cp main.bicepparam main.local.bicepparam
code main.local.bicepparam
```

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-bicep-param-edit.png`
> - Capture target: main.local.bicepparam opened in Cloud Shell editor
> - Purpose: Cloud Shell editor で Bicep パラメータを編集する画面を示す
> - Suggested alt text: Cloud Shell editor showing main.local.bicepparam
> - Insertion note: 実値はマスクし、パラメータ名が分かる状態を撮影する
> - Mask: SSH public key、Object ID、Tenant ID、Client ID、証明書データ、パスワード、個人名

少なくとも次を設定します。

| パラメータ | 入力する値 | 取得方法 |
|---|---|---|
| `sshPublicKey` | Cloud Shell で作成した公開鍵 | `cat ~/.ssh/id_rsa.pub` |
| `adminObjectId` | 自分の Entra object ID | `az ad signed-in-user show --query id -o tsv` |
| `entraTenantId` | Tenant ID | Day 0 で控えた値 |
| `entraClientId` | Backend API Client ID | Day 0 で控えた値 |
| `entraFrontendClientId` | Frontend SPA Client ID | Day 0 で控えた値 |
| `sslCertificateData` | `cert-base64.txt` の内容 | `cat ../../cert-base64.txt` |
| `sslCertificatePassword` | PFX パスワード | 既定値 `Workshop2024!` |
| `mongoDbAppPassword` | MongoDB アプリユーザーのパスワード | 自分で決める強い値 |
| `appGatewayDnsLabel` | 一意な DNS ラベル | 例: `blogapp-team1-0106` |

複数グループの場合は `groupId` も設定します。

```bicep
param groupId = 'A'
```

**期待結果:** 個人値入りの `main.local.bicepparam` を作成できます。

**チェックポイント:** `main.local.bicepparam` は `.gitignore` 対象です。GitHub に push しません。

## 5. リソースグループを作成する

```bash
cd ~/Azure-IaaS-Workshop

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"
```

**期待結果:** リソースグループが作成されます。

## 6. Bicep デプロイを実行する

```bash
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam
```

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-deployment-command.png`
> - Capture target: Cloud Shell running az deployment group create
> - Purpose: デプロイコマンド実行中の状態を示す
> - Suggested alt text: Azure Cloud Shell running az deployment group create for the workshop
> - Insertion note: 実行コマンドと Running 状態が分かるように撮影する
> - Mask: サブスクリプション ID、テナント ID、個人名、リソース名に含まれる個人情報

デプロイには 15-30 分かかることがあります。Application Gateway などは作成に時間がかかります。

**期待結果:** コマンドの最終出力に `"provisioningState": "Succeeded"` が表示されます。

**チェックポイント:** 10 分以上動いていないように見えてもすぐにキャンセルしません。Azure Portal でも進捗を確認します。

## 7. Portal でデプロイ進捗を確認する

1. Azure Portal > Resource groups を開きます。
2. `$RESOURCE_GROUP` を開きます。
3. 左メニューの Deployments を開きます。
4. `main` または実行中の deployment を確認します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-deployment-progress.png`
> - Capture target: Resource group Deployments page showing running deployment
> - Purpose: Cloud Shell が切断されても Portal で進捗確認できることを示す
> - Suggested alt text: Azure Resource group deployments page showing deployment progress
> - Insertion note: Deployment の状態が分かる状態を撮影する
> - Mask: サブスクリプション ID、テナント ID、個人名、リソース名に含まれる個人情報

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-deployment-succeeded.png`
> - Capture target: Resource group Deployments page showing succeeded deployment
> - Purpose: デプロイ成功状態の見方を示す
> - Suggested alt text: Azure Resource group deployments page showing succeeded deployment
> - Insertion note: `Succeeded` の状態が分かる状態を撮影する
> - Mask: サブスクリプション ID、テナント ID、個人名、リソース名に含まれる個人情報

## 8. デプロイ後セットアップを実行する

MongoDB レプリカセット初期化とユーザー作成を行います。

```bash
cd ~/Azure-IaaS-Workshop/scripts
cp post-deployment-setup.template.sh post-deployment-setup.local.sh
chmod +x post-deployment-setup.local.sh
code post-deployment-setup.local.sh
```

置き換える主な値:

| プレースホルダ | 入力例 |
|---|---|
| `<YOUR_RESOURCE_GROUP>` | `$RESOURCE_GROUP` の値 |
| `<YOUR_BASTION_NAME>` | `bastion-blogapp-prod` |
| `<PATH_TO_YOUR_SSH_KEY>` | `/home/<cloud-shell-user>/.ssh/id_rsa` または `~/.ssh/id_rsa` |
| `<YOUR_MONGODB_ADMIN_PASSWORD>` | 自分で決める管理者パスワード |
| `<YOUR_MONGODB_APP_PASSWORD>` | `main.local.bicepparam` の `mongoDbAppPassword` と同じ値 |

実行します。

```bash
./post-deployment-setup.local.sh "$RESOURCE_GROUP"
```

**期待結果:** MongoDB レプリカセットとユーザー作成が成功し、検証メッセージが表示されます。

**チェックポイント:** `MONGODB_APP_PASSWORD` と `mongoDbAppPassword` が一致しない場合、バックエンド API は MongoDB に接続できません。

## 9. Data Collection Rule を構成する

Log Analytics のテーブル初期化後に DCR を作成します。

```bash
cd ~/Azure-IaaS-Workshop
chmod +x scripts/configure-dcr.sh
./scripts/configure-dcr.sh "$RESOURCE_GROUP"
```

**期待結果:** Syslog と Perf の収集用 DCR が作成され、VM に関連付けられます。

**チェックポイント:** 新しい Log Analytics workspace ではテーブル初期化に 1-5 分かかることがあります。タイムアウトした場合は数分待って再実行します。

## 10. Application Gateway の FQDN を取得する

```bash
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "https://$FQDN"
```

**期待結果:** `https://<dns-label>.<region>.cloudapp.azure.com` 形式の URL が表示されます。

## 11. フロントエンド SPA のリダイレクト URI を更新する

Azure Portal でフロントエンド SPA のアプリ登録を開きます。

1. Microsoft Entra ID > App registrations > `BlogApp Frontend <自分またはチーム名>` を開きます。
2. Authentication を開きます。
3. Single-page application の Redirect URIs に次を追加します。
   - `https://<YOUR_FQDN>`
   - `https://<YOUR_FQDN>/`
4. 保存します。

**期待結果:** 本番 URL で MSAL のリダイレクトが許可されます。

**チェックポイント:** `http://localhost:5173` はローカル開発用として残して構いません。Day 1 の本線では `https://<YOUR_FQDN>` を追加します。

## 12. アプリケーションコードの配置を確認する

Bicep は VM、ミドルウェア、環境変数、NGINX 設定、`config.json` を準備します。バックエンドとフロントエンドのアプリケーションコード配置は、ワークショップ当日の講師手順または自動化済み手順に従います。

**期待結果:** Web tier と App tier にアプリケーションコードが配置され、サービスが起動します。

**チェックポイント:** このページでは Cloud Shell-first のインフラデプロイ手順を優先しています。アプリコード配置は、ワークショップ当日の講師手順または別途用意された自動化手順に従ってください。

## 13. アプリケーション疎通を確認する

```bash
curl -k "https://$FQDN/"
curl -k "https://$FQDN/api/posts"
```

ブラウザでも `https://$FQDN` を開きます。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-app-home.png`
> - Capture target: Blog application home page through Application Gateway URL
> - Purpose: Application Gateway 経由でアプリが表示されることを確認する
> - Suggested alt text: Blog application home page opened through the Application Gateway URL
> - Insertion note: URL とアプリのホーム画面が分かる状態を撮影する
> - Mask: 個人名、メールアドレス、投稿内容、リソース名に含まれる個人情報

**期待結果:** 自己署名証明書の警告を通過後、ブログアプリが表示されます。

**チェックポイント:** `curl -k` は自己署名証明書の検証をスキップするためのワークショップ用確認です。本番運用では信頼された証明書を使用します。

## 14. Application Gateway backend health を確認する

Azure Portal で Application Gateway を開き、Backend health を確認します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-appgw-backend-health.png`
> - Capture target: Application Gateway backend health page
> - Purpose: Web tier backend の正常性確認画面を示す
> - Suggested alt text: Azure Application Gateway backend health page showing healthy backend servers
> - Insertion note: backend の Healthy/Unhealthy 状態が分かるように撮影する
> - Mask: サブスクリプション ID、リソース名に含まれる個人情報、IP アドレスが組織情報に紐づく場合は IP

**期待結果:** 少なくとも期待する Web tier backend が Healthy になります。

## 15. Log Analytics の基本クエリを実行する

Azure Portal で Log Analytics workspace を開き、Logs から次を実行します。

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-log-analytics-query.png`
> - Capture target: Log Analytics query editor with Heartbeat query results
> - Purpose: Log Analytics で基本クエリを実行できることを確認する
> - Suggested alt text: Azure Log Analytics query editor showing Heartbeat query results
> - Insertion note: クエリ本文と結果表が分かる状態を撮影する
> - Mask: サブスクリプション ID、ワークスペース名、VM 名に含まれる個人情報

**期待結果:** VM の `Computer` と `LastSeen` が表示されます。

**チェックポイント:** データがすぐに出ない場合は、DCR 関連付け後に数分待ちます。監視の詳細は [監視ガイド](monitoring-guide.ja.md) を参照してください。

## よくある失敗と確認先

| 症状 | 確認すること | 参照先 |
|---|---|---|
| VM SKU が利用できない | `az vm list-skus --location japanwest --size Standard_B -o table` | `main.local.bicepparam` の VM size |
| DNS label が重複する | `appGatewayDnsLabel` がリージョン内で一意か | Step 4 |
| Deployment が失敗する | Portal の Deployments の失敗リソースと error details | Step 7 |
| MongoDB 接続に失敗する | `mongoDbAppPassword` と post-deployment script の値 | Step 8 |
| ログインに失敗する | SPA redirect URI と API permission | Day 0、Step 11 |
| Log Analytics にデータがない | DCR 作成、VM 関連付け、数分の待機 | Step 9、Step 15 |

## Day 1 完了条件

- Cloud Shell 上にリポジトリを clone できた。
- SSH 鍵と SSL 証明書を作成できた。
- `main.local.bicepparam` を作成し、必要値を設定できた。
- Bicep deployment が `Succeeded` になった。
- デプロイ後セットアップが完了した。
- Application Gateway の FQDN を取得できた。
- フロントエンド SPA の本番リダイレクト URI を追加できた。
- アプリケーションの疎通確認ができた。
- Application Gateway backend health を確認できた。
- Log Analytics で基本クエリを実行できた。

## 次に進む

Day 1 の監視演習では [監視ガイド](monitoring-guide.ja.md) を参照します。Day 2 では [Day 2: 回復性チェックリスト](day-2-resiliency-checklist.ja.md) に進みます。

前のページ: [Azure Cloud Shell ガイド](azure-cloud-shell-guide.ja.md)  
迷ったとき: [受講者ポータル](index.md) / [トラブルシューティングランブック](troubleshooting-runbook.ja.md) / [クイックリファレンス](quick-reference-card.ja.md)
