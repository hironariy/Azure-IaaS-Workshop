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
| `adminObjectId` | 自分の Entra object ID | Day 0 で控えた値 |
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

Bicep は VM、ミドルウェア、環境変数、NGINX 設定、`config.json` までを準備します。一方で、Express API と React frontend のアプリケーションコードは、この Step で App tier / Web tier の VM に配置します。

この手順では、`deployment-strategy.md` の Phase 2 / Phase 3 の内容を、Cloud Shell から実行しやすい形にまとめています。App tier を先に配置し、その後 Web tier を配置します。

### 12.1 配置対象と前提を確認する

Cloud Shell で、リポジトリルートにいることを確認します。

```bash
cd ~/Azure-IaaS-Workshop
```

受講者自身のコピー先リポジトリ URL を設定します。テンプレート元ではなく、Day 0 で作成した自分のリポジトリを指定してください。

```bash
REPOSITORY_URL="https://github.com/<YOUR_GITHUB_USER>/Azure-IaaS-Workshop.git"
```

現在のリポジトリが自分のコピーであれば、次のコマンドで確認できます。

```bash
git remote -v
```

VM 名を変数に入れます。

```bash
APP_VMS=("vm-app-az1-prod" "vm-app-az2-prod")
WEB_VMS=("vm-web-az1-prod" "vm-web-az2-prod")
```

**チェックポイント:** `REPOSITORY_URL` は VM から `git clone` できる URL である必要があります。コピー先リポジトリを private にした場合は GitHub 認証が必要になり、ここで失敗します。ワークショップでは、組織ポリシーに反しない範囲で VM から認証なしで clone できる公開範囲を推奨します。

### 12.2 Backend API を App VM に配置する

App tier では、2 台の App VM に backend code を配置し、`npm ci --include=dev`、`npm run build`、PM2 起動を行います。Bicep が作成した `/opt/blogapp/.env` はそのまま使います。

Cloud Shell で backend 配置用スクリプトを作成します。

```bash
cat > /tmp/deploy-backend.sh <<'BACKEND_SCRIPT'
set -euo pipefail

REPOSITORY_URL="__REPOSITORY_URL__"

export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 -y install git

chown -R azureuser:azureuser /opt/blogapp

sudo -H -u azureuser bash <<'APP_SCRIPT'
set -euo pipefail

REPOSITORY_URL="__REPOSITORY_URL__"
WORK_DIR="/tmp/blogapp-backend-$(date +%s)"

cd /opt/blogapp
rm -rf "$WORK_DIR"
git clone "$REPOSITORY_URL" "$WORK_DIR"
cp -r "$WORK_DIR/materials/backend/." /opt/blogapp/
rm -rf "$WORK_DIR"

npm ci --include=dev
npm run build

# The backend loads dotenv from dist/.env after TypeScript build.
cp /opt/blogapp/.env /opt/blogapp/dist/.env
chmod 600 /opt/blogapp/dist/.env

pm2 delete blogapp-health 2>/dev/null || true
pm2 delete blogapp-api 2>/dev/null || true
pm2 start dist/src/app.js --name blogapp-api
pm2 save

pm2 list

API_OK=0
for attempt in $(seq 1 12); do
  if curl -fsS http://localhost:3000/health && curl -fsS http://localhost:3000/api/posts; then
    API_OK=1
    break
  fi
  echo "Waiting for backend API to start... attempt ${attempt}/12"
  sleep 10
done

test "$API_OK" = "1"
APP_SCRIPT
BACKEND_SCRIPT

sed -i "s|__REPOSITORY_URL__|$REPOSITORY_URL|g" /tmp/deploy-backend.sh
```

2 台の App VM に実行します。

```bash
for VM in "${APP_VMS[@]}"; do
  echo "Deploying backend to $VM ..."
  az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM" \
    --command-id RunShellScript \
    --scripts @/tmp/deploy-backend.sh \
    --query "value[0].message" \
    -o tsv
done
```

**期待結果:** 各 App VM の出力で、`blogapp-api` が PM2 の `online` 状態になり、`curl http://localhost:3000/health` と `curl http://localhost:3000/api/posts` が成功します。

**チェックポイント:** `blogapp-health` は Bicep が作成した一時的な health server です。実アプリを起動する前に削除して問題ありません。

### 12.3 Frontend を Web VM に配置する

Web tier では、2 台の Web VM 上で frontend を build し、生成された `dist` を `/var/www/html` に配置します。Bicep が作成した `/var/www/html/config.json` には Entra ID と API の runtime 設定が入っているため、削除せずに退避してから戻します。

Cloud Shell で frontend 配置用スクリプトを作成します。

```bash
cat > /tmp/deploy-frontend.sh <<'FRONTEND_SCRIPT'
set -euo pipefail

REPOSITORY_URL="__REPOSITORY_URL__"
WORK_DIR="/tmp/blogapp-frontend-$(date +%s)"

export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=120 update
apt-get -o DPkg::Lock::Timeout=120 -y install git curl ca-certificates

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get -o DPkg::Lock::Timeout=120 -y install nodejs
fi

if [ ! -f /var/www/html/config.json ]; then
  echo "/var/www/html/config.json が見つかりません。Bicep の Web tier CustomScript が完了しているか確認してください。"
  exit 1
fi

rm -rf "$WORK_DIR"
git clone "$REPOSITORY_URL" "$WORK_DIR"

cd "$WORK_DIR/materials/frontend"
npm ci
npm run build

cp /var/www/html/config.json /tmp/config.json.bak
rm -rf /var/www/html/*
cp -r dist/* /var/www/html/
cp /tmp/config.json.bak /var/www/html/config.json
chown -R www-data:www-data /var/www/html

nginx -t
systemctl reload nginx

curl -fsS http://localhost/health
curl -fsS http://localhost/ | head -5

API_PROXY_OK=0
for attempt in $(seq 1 12); do
  if curl -fsS http://localhost/api/posts; then
    API_PROXY_OK=1
    break
  fi
  echo "Waiting for Web tier API proxy to reach App tier... attempt ${attempt}/12"
  sleep 10
done

test "$API_PROXY_OK" = "1"

rm -rf "$WORK_DIR"
FRONTEND_SCRIPT

sed -i "s|__REPOSITORY_URL__|$REPOSITORY_URL|g" /tmp/deploy-frontend.sh
```

2 台の Web VM に実行します。

```bash
for VM in "${WEB_VMS[@]}"; do
  echo "Deploying frontend to $VM ..."
  az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM" \
    --command-id RunShellScript \
    --scripts @/tmp/deploy-frontend.sh \
    --query "value[0].message" \
    -o tsv
done
```

**期待結果:** 各 Web VM の出力で、`nginx -t` が successful になり、`curl http://localhost/` の先頭に `<!doctype html>` または HTML が表示されます。`curl http://localhost/api/posts` は Web VM から Internal Load Balancer 経由で App tier に到達する確認です。

**チェックポイント:** `/var/www/html/config.json` を消すと、フロントエンドが Entra ID と API の接続先を取得できません。上記スクリプトは `config.json` を退避してから戻します。

### 12.4 Application Gateway 経由で確認する

App tier と Web tier の配置後、Cloud Shell から外部 URL を確認します。

```bash
curl -k -I "https://$FQDN/"
curl -k "https://$FQDN/api/posts"
```

**期待結果:** `/` は `200` または HTML 応答になり、`/api/posts` は JSON 配列を返します。投稿がまだない場合は `[]` が正常です。

### 12.5 よくある失敗

| 症状 | 主な原因 | 確認すること |
|---|---|---|
| `git clone` が失敗する | `REPOSITORY_URL` がテンプレート元、private repository、または誤った URL になっている | Day 0 で作成した自分のコピーを指定しているか、VM から認証なしで clone できるか |
| `/` が `403 Forbidden` になる | Web VM に frontend の `index.html` が配置されていない | Step 12.3 が 2 台の Web VM で成功したか |
| `/api/posts` が `502` または `504` になる | App tier の `blogapp-api` が起動していない、または MongoDB に接続できない | Step 12.2 の PM2 出力、Step 8 の MongoDB password 一致 |
| `npm ci` が失敗する | package lock と依存関係の取得に失敗している | VM から GitHub/npm へ outbound 接続できるか、再実行しても同じか |
| `config.json` が見つからない | Web tier の Bicep CustomScript が未完了または失敗している | Azure Portal の VM extensions と Step 7 の deployment status |

**期待結果:** Web tier と App tier にアプリケーションコードが配置され、サービスが起動します。

**チェックポイント:** App tier は `blogapp-api` の PM2 process が 2 台で `online`、Web tier は 2 台で `/var/www/html/index.html` と `/var/www/html/config.json` が存在する状態にします。

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

**チェックポイント:** データがすぐに出ない場合は、DCR 関連付け後に数分待ちます。監視の詳細は [監視ガイド](../operations/monitoring-guide.ja.md) を参照してください。

## よくある失敗と確認先

| 症状 | 確認すること | 参照先 |
|---|---|---|
| VM SKU が利用できない | `az vm list-skus --location japanwest --size Standard_B -o table` | `main.local.bicepparam` の VM size |
| DNS label が重複する | `appGatewayDnsLabel` がリージョン内で一意か | Step 4 |
| Deployment が失敗する | Portal の Deployments の失敗リソースと error details | Step 7 |
| MongoDB 接続に失敗する | `mongoDbAppPassword` と post-deployment script の値 | Step 8 |
| `/` が `403 Forbidden` になる | Web VM に frontend の `index.html` が配置されているか | Step 12 |
| `/api/posts` が `502` または `504` になる | App VM の `blogapp-api` と MongoDB 接続 | Step 12 |
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
- Backend API を 2 台の App VM に配置し、`blogapp-api` を PM2 で起動できた。
- Frontend を 2 台の Web VM に配置し、`index.html` と `config.json` を確認できた。
- アプリケーションの疎通確認ができた。
- Application Gateway backend health を確認できた。
- Log Analytics で基本クエリを実行できた。

## 次に進む

Day 1 の監視演習では [監視ガイド](../operations/monitoring-guide.ja.md) を参照します。Day 2 では [Day 2: 回復性チェックリスト](day-2-resiliency-checklist.ja.md) に進みます。

前のページ: [Azure Cloud Shell ガイド](azure-cloud-shell-guide.ja.md)  
迷ったとき: [受講者ポータル](../index.md) / [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) / [クイックリファレンス](../reference/quick-reference-card.ja.md)
