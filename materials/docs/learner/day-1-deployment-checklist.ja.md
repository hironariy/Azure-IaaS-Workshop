---
title: "Day 1: Azure リソースデプロイとアプリ配置"
---

# Day 1: Azure リソースデプロイとアプリ配置

## このページでやること

Azure Cloud Shell Bash を使って、作業環境の準備、Bicep パラメータ作成、Azure IaaS 環境のデプロイ、デプロイ後セットアップ、アプリケーションコードの手動配置、疎通確認、監視確認までを進めます。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 0 の事前準備を終えた受講者 |
| 所要時間 | 90-150 分 |
| 前提 | Cloud Shell Bash、Entra ID アプリ登録値、VM クォータ、GitHub リポジトリのコピー |
| 完了条件 | Bicep deployment が `Succeeded` になり、App tier / Web tier にアプリケーションコードを配置し、Application Gateway 経由の動作確認と Log Analytics の基本確認ができること |

## 第1章: Cloud Shell と作業環境の準備

### 0. Cloud Shell Bash を開き、リポジトリを準備する

1. Azure Portal にサインインします。
2. 画面上部の Cloud Shell アイコンをクリックします。
3. シェル選択で **Bash** を選びます。
4. 初回起動時はストレージ作成を求められるため、講師の指定に従って作成します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-cloud-shell-launch.png`
> - Capture target: Azure Portal Cloud Shell launch screen
> - Purpose: 受講者が Azure Portal から Cloud Shell を起動する位置を確認する
> - Suggested alt text: Azure Portal showing the Cloud Shell launch button
> - Insertion note: Portal 上部の Cloud Shell アイコンと起動後のペインが分かる状態を撮影する
> - Mask: アカウント名、テナント ID、サブスクリプション ID

Cloud Shell Bash で、Day 0 で作成した自分のコピー先リポジトリを clone します。すでに clone 済みの場合は `cd` だけ実行します。

```bash
cd ~
if [ ! -d Azure-IaaS-Workshop ]; then
  git clone https://github.com/<OWNER>/Azure-IaaS-Workshop.git
fi
cd ~/Azure-IaaS-Workshop
```

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-git-clone-complete.png`
> - Capture target: Cloud Shell after git clone and cd into the repository
> - Purpose: clone が完了し、作業ディレクトリがリポジトリルートであることを確認する
> - Suggested alt text: Azure Cloud Shell showing completed git clone of the workshop repository
> - Insertion note: `git clone` の完了メッセージと `pwd` またはプロンプトのパスが見える状態を撮影する
> - Mask: GitHub ユーザー名、組織名、アカウント名

作業変数を設定します。Cloud Shell を再起動した場合も、この変数は再設定します。

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

### 1. Azure CLI の状態を確認する

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

**チェックポイント:** Day 0 で控えた Tenant ID と一致していることを確認します。

### 2. SSH 鍵を準備する

Cloud Shell 内に SSH 鍵がない場合は作成します。

```bash
ssh-keygen -t rsa -b 4096 -C "workshop@azure"
cat ~/.ssh/id_rsa.pub
```

Cloud Shell が切断された場合に備えて、秘密鍵と公開鍵を `~/clouddrive` に退避します。`~/clouddrive` は Cloud Shell の永続ストレージです。

```bash
mkdir -p ~/clouddrive/workshop-keys
cp ~/.ssh/id_rsa ~/.ssh/id_rsa.pub ~/clouddrive/workshop-keys/
chmod 600 ~/clouddrive/workshop-keys/id_rsa
```

**期待結果:** `ssh-rsa` で始まる公開鍵を取得できます。

**チェックポイント:** `main.local.bicepparam` に貼るのは公開鍵です。秘密鍵は Cloud Shell と `~/clouddrive/workshop-keys` だけに保持し、GitHub に push しません。

### 3. SSL 証明書を生成する

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

## 第2章: Azure リソースのデプロイと初期設定

### 4. Bicep パラメータファイルを作成する

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
| `mongoDbAppPassword` | MongoDB アプリユーザーのパスワード | 自分で決める強い値。Step 9 の `<YOUR_MONGODB_APP_PASSWORD>` と完全一致させる |
| `appGatewayDnsLabel` | 一意な DNS ラベル | 例: `blogapp-team1-0106` |

> [!IMPORTANT]
> `mongoDbAppPassword` は、Step 9 の `post-deployment-setup.local.sh` に設定する `<YOUR_MONGODB_APP_PASSWORD>` と **1 文字も違わず一致**させます。不一致の場合、Bicep が作成する App VM の `MONGODB_URI` と MongoDB 上のユーザー password がずれ、Backend API が DB に接続できません。
>
> MongoDB connection string では `@` が予約文字です。この教材では Bicep が password を connection string に埋め込むため、`mongoDbAppPassword` には `@` を使わないでください。迷った場合は、英数字と `!`、`-`、`_`、`.` の範囲で作成します。

複数グループの場合は `groupId` も設定します。

```bicep
param groupId = 'A'
```

**期待結果:** 個人値入りの `main.local.bicepparam` を作成できます。

**チェックポイント:** `main.local.bicepparam` は `.gitignore` 対象です。GitHub に push しません。

### 5. リソースグループを作成する

```bash
cd ~/Azure-IaaS-Workshop

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"
```

**期待結果:** リソースグループが作成されます。

### 6. Bicep デプロイを実行する

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

### 7. Portal でデプロイ進捗を確認する

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

### 8. Azure CLI の Bastion extension を準備する

デプロイ後セットアップとアプリケーション配置では `az network bastion ssh` を使います。Cloud Shell に Bastion extension が入っていない場合、セットアップスクリプトの SSH 実行で停止するため、ここで先に準備します。

```bash
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name bastion --upgrade --yes
az extension show --name bastion --query "{name:name,version:version}" -o table
```

**期待結果:** `bastion` extension の name と version が表示されます。

**チェックポイント:** `az network bastion ssh -h` を実行して help が表示されれば、以後の Bastion 経由 SSH コマンドを実行できます。

### 9. デプロイ後セットアップを実行する

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
| `<YOUR_MONGODB_APP_PASSWORD>` | Step 4 の `mongoDbAppPassword` と同じ値 |

実行します。

```bash
./post-deployment-setup.local.sh "$RESOURCE_GROUP"
```

**期待結果:** MongoDB レプリカセットとユーザー作成が成功し、検証メッセージが表示されます。

**チェックポイント:** `MONGODB_APP_PASSWORD` と `mongoDbAppPassword` が一致しない場合、バックエンド API は MongoDB に接続できません。`@` を含む password も MongoDB connection string を壊すため使わないでください。

### 10. Data Collection Rule を構成する

Log Analytics のテーブル初期化後に DCR を作成します。

```bash
cd ~/Azure-IaaS-Workshop
chmod +x scripts/configure-dcr.sh
./scripts/configure-dcr.sh "$RESOURCE_GROUP"
```

**期待結果:** Syslog と Perf の収集用 DCR が作成され、VM に関連付けられます。

**チェックポイント:** 新しい Log Analytics workspace ではテーブル初期化に 1-5 分かかることがあります。タイムアウトした場合は数分待って再実行します。

### 11. Application Gateway の FQDN を取得する

```bash
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "https://$FQDN"
```

**期待結果:** `https://<dns-label>.<region>.cloudapp.azure.com` 形式の URL が表示されます。

### 12. フロントエンド SPA のリダイレクト URI を更新する

Azure Portal でフロントエンド SPA のアプリ登録を開きます。

1. Microsoft Entra ID > App registrations > `BlogApp Frontend <自分またはチーム名>` を開きます。
2. Authentication を開きます。
3. Single-page application の Redirect URIs に次を追加します。
   - `https://<YOUR_FQDN>`
   - `https://<YOUR_FQDN>/`
4. 保存します。

**期待結果:** 本番 URL で MSAL のリダイレクトが許可されます。

**チェックポイント:** `http://localhost:5173` はローカル開発用として残して構いません。Day 1 の本線では `https://<YOUR_FQDN>` を追加します。

## 第3章: アプリケーションコードの手動デプロイ

### 13. アプリケーションコードの配置を確認する

Bicep は VM、ミドルウェア、環境変数、NGINX 設定、`config.json` までを準備します。一方で、Express API と React frontend のアプリケーションコードは、この Step で App tier / Web tier の VM に配置します。

この手順では、`deployment-strategy.md` の Phase 2 / Phase 3 と同じ考え方で、各 VM に Bastion 経由で接続し、VM 内で確認、clone、build、起動、検証を行います。App tier を先に配置し、その後 Web tier を配置します。

#### 13.1 配置対象と前提を確認する

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

VM 名を確認します。

```bash
APP_VMS=("vm-app-az1-prod" "vm-app-az2-prod")
WEB_VMS=("vm-web-az1-prod" "vm-web-az2-prod")
printf '%s\n' "${APP_VMS[@]}" "${WEB_VMS[@]}"
```

**チェックポイント:** `REPOSITORY_URL` は VM から `git clone` できる URL である必要があります。コピー先リポジトリを private にした場合は GitHub 認証が必要になり、ここで失敗します。ワークショップでは、組織ポリシーに反しない範囲で VM から認証なしで clone できる公開範囲を推奨します。

#### 13.2 App VM に Bastion 経由で接続する

App tier の 2 台に順番に接続して作業します。まず `vm-app-az1-prod` に接続します。

```bash
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "$(az vm show -g "$RESOURCE_GROUP" -n vm-app-az1-prod --query id -o tsv)" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

以降の **13.3 から 13.7** は、接続先の App VM 内で実行します。`vm-app-az1-prod` で完了したら `exit` で Cloud Shell に戻り、同じ手順を `vm-app-az2-prod` でも繰り返します。

```bash
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "$(az vm show -g "$RESOURCE_GROUP" -n vm-app-az2-prod --query id -o tsv)" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

**チェックポイント:** プロンプトが App VM 上の `azureuser` になっていることを確認してから次へ進みます。

#### 13.3 App VM の Node.js、PM2、環境変数を確認する

接続先の App VM で実行します。

```bash
node --version
pm2 --version
pm2 list
ls -la /opt/blogapp/
```

Bicep が作成した環境変数ファイルを確認します。`MONGODB_URI` にはパスワードが含まれるため、画面共有やスクリーンショットでは表示しないでください。

```bash
grep -E '^(NODE_ENV|PORT|LOG_LEVEL|ENTRA_TENANT_ID|ENTRA_CLIENT_ID)=' /opt/blogapp/.env
grep '^MONGODB_URI=' /opt/blogapp/.env | sed 's#://blogapp:[^@]*@#://blogapp:***@#'
```

**期待結果:** Node.js 20 系、PM2、`/opt/blogapp/.env` が確認できます。

#### 13.4 App VM の一時 health server を削除する

Bicep は App tier の起動確認用に `blogapp-health` という一時的な PM2 process を作成します。実アプリを起動する前に削除します。

```bash
pm2 list
pm2 delete blogapp-health 2>/dev/null || true
pm2 save
pm2 list
```

**チェックポイント:** `blogapp-health` が存在しない、または削除済みであることを確認します。

#### 13.5 Backend API のコードを配置する

App tier では、2 台の App VM に backend code を配置し、`npm ci --include=dev`、`npm run build`、PM2 起動を行います。Bicep が作成した `/opt/blogapp/.env` はそのまま使います。

接続先の App VM で実行します。`REPOSITORY_URL` は Day 0 で作成した自分のコピー先に置き換えます。

```bash
REPOSITORY_URL="https://github.com/<YOUR_GITHUB_USER>/Azure-IaaS-Workshop.git"

cd /opt/blogapp
rm -rf temp
git clone "$REPOSITORY_URL" temp
cp -r temp/materials/backend/* ./
rm -rf temp
```

**チェックポイント:** `package.json`、`src/`、`tsconfig.json` が `/opt/blogapp` に配置されます。

#### 13.6 Backend API を build して PM2 で起動する

接続先の App VM で実行します。

```bash
cd /opt/blogapp

# NODE_ENV=production が設定されているため、TypeScript build に必要な devDependencies も明示的に入れます。
npm ci --include=dev
npm run build

# Backend は build 後に dist/.env を読みます。Bicep が作成した .env を build 成果物側にも置きます。
cp /opt/blogapp/.env /opt/blogapp/dist/.env
chmod 600 /opt/blogapp/dist/.env

pm2 delete blogapp-api 2>/dev/null || true
pm2 start dist/src/app.js --name blogapp-api
pm2 save

pm2 list
pm2 logs blogapp-api --lines 20
```

**期待結果:** `blogapp-api` が PM2 の `online` 状態になります。

#### 13.7 Backend API を App VM 内で検証する

接続先の App VM で実行します。

```bash
curl http://localhost:3000/health
curl http://localhost:3000/api/posts
curl http://10.0.2.10:3000/health
```

**期待結果:** health endpoint が `healthy` を返し、`/api/posts` が JSON 配列を返します。投稿がまだない場合は `[]` が正常です。

`vm-app-az1-prod` の作業が終わったら `exit` で Cloud Shell に戻り、`vm-app-az2-prod` に接続して **13.3 から 13.7** を繰り返します。

#### 13.8 Web VM に Bastion 経由で接続する

Web tier の 2 台に順番に接続して作業します。まず `vm-web-az1-prod` に接続します。

```bash
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "$(az vm show -g "$RESOURCE_GROUP" -n vm-web-az1-prod --query id -o tsv)" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

以降の **13.9 から 13.12** は、接続先の Web VM 内で実行します。`vm-web-az1-prod` で完了したら `exit` で Cloud Shell に戻り、同じ手順を `vm-web-az2-prod` でも繰り返します。

```bash
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "$(az vm show -g "$RESOURCE_GROUP" -n vm-web-az2-prod --query id -o tsv)" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

#### 13.9 Web VM の NGINX と runtime config を確認する

接続先の Web VM で実行します。

```bash
sudo systemctl status nginx --no-pager
nginx -v
curl http://localhost/health
cat /var/www/html/config.json
grep "proxy_pass" /etc/nginx/sites-available/default
```

**期待結果:** NGINX が起動しており、`/var/www/html/config.json` に Entra ID と API の runtime 設定が入っています。

**チェックポイント:** `config.json` は frontend が起動時に読む設定ファイルです。静的ファイル配置時に消さないようにします。

#### 13.10 Frontend を build する

接続先の Web VM で実行します。`REPOSITORY_URL` は Day 0 で作成した自分のコピー先に置き換えます。

```bash
REPOSITORY_URL="https://github.com/<YOUR_GITHUB_USER>/Azure-IaaS-Workshop.git"

cd /tmp
rm -rf temp
git clone "$REPOSITORY_URL" temp

# Web tier VM には NGINX はありますが、Node.js はない場合があります。
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

cd temp/materials/frontend
npm ci
npm run build
```

**期待結果:** `dist/` が作成されます。

#### 13.11 Frontend の静的ファイルを NGINX に配置する

接続先の Web VM で実行します。既存の `config.json` を退避してから、Vite の build 成果物を `/var/www/html` に配置します。

```bash
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/

cd /tmp
rm -rf temp
```

**チェックポイント:** `/var/www/html/index.html` と `/var/www/html/config.json` の両方が存在することを確認します。

```bash
ls -l /var/www/html/index.html /var/www/html/config.json
```

#### 13.12 Web VM 内で NGINX と API proxy を検証する

接続先の Web VM で実行します。

```bash
sudo nginx -t
sudo systemctl reload nginx

curl http://localhost/health
curl -s http://localhost/ | head -5
curl http://localhost/api/posts
curl -s http://localhost/login | head -5
```

**期待結果:** `/` と `/login` は HTML を返し、`/api/posts` は JSON 配列を返します。

`vm-web-az1-prod` の作業が終わったら `exit` で Cloud Shell に戻り、`vm-web-az2-prod` に接続して **13.9 から 13.12** を繰り返します。

#### 13.13 Application Gateway 経由で確認する

App tier と Web tier の配置後、Cloud Shell から外部 URL を確認します。

```bash
curl -k -I "https://$FQDN/"
curl -k "https://$FQDN/api/posts"
```

**期待結果:** `/` は `200` または HTML 応答になり、`/api/posts` は JSON 配列を返します。投稿がまだない場合は `[]` が正常です。

#### 13.14 よくある失敗

| 症状 | 主な原因 | 確認すること |
|---|---|---|
| `git clone` が失敗する | `REPOSITORY_URL` がテンプレート元、private repository、または誤った URL になっている | Day 0 で作成した自分のコピーを指定しているか、VM から認証なしで clone できるか |
| `/` が `403 Forbidden` になる | Web VM に frontend の `index.html` が配置されていない | Step 13.11 が 2 台の Web VM で成功したか |
| `/api/posts` が `502` または `504` になる | App tier の `blogapp-api` が起動していない、または MongoDB に接続できない | Step 13.6、Step 13.7、Step 4 / Step 9 の MongoDB password 一致 |
| `npm ci` が失敗する | package lock と依存関係の取得に失敗している | VM から GitHub/npm へ outbound 接続できるか、再実行しても同じか |
| `config.json` が見つからない | Web tier の Bicep CustomScript が未完了または失敗している | Azure Portal の VM extensions と Step 7 の deployment status |

**期待結果:** Web tier と App tier にアプリケーションコードが配置され、サービスが起動します。

**チェックポイント:** App tier は `blogapp-api` の PM2 process が 2 台で `online`、Web tier は 2 台で `/var/www/html/index.html` と `/var/www/html/config.json` が存在する状態にします。

## 第4章: 疎通確認と監視確認

### 14. アプリケーション疎通を確認する

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

### 15. Application Gateway backend health を確認する

Azure Portal で Application Gateway を開き、Backend health を確認します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-appgw-backend-health.png`
> - Capture target: Application Gateway backend health page
> - Purpose: Web tier backend の正常性確認画面を示す
> - Suggested alt text: Azure Application Gateway backend health page showing healthy backend servers
> - Insertion note: backend の Healthy/Unhealthy 状態が分かるように撮影する
> - Mask: サブスクリプション ID、リソース名に含まれる個人情報、IP アドレスが組織情報に紐づく場合は IP

**期待結果:** 少なくとも期待する Web tier backend が Healthy になります。

### 16. Log Analytics の基本クエリを実行する

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
| MongoDB 接続に失敗する | `mongoDbAppPassword` と post-deployment script の値、`@` を含まない password か | Step 4、Step 9 |
| `/` が `403 Forbidden` になる | Web VM に frontend の `index.html` が配置されているか | Step 13 |
| `/api/posts` が `502` または `504` になる | App VM の `blogapp-api` と MongoDB 接続 | Step 13 |
| ログインに失敗する | SPA redirect URI と API permission | Day 0、Step 12 |
| `az network bastion ssh` が見つからない | Bastion extension が Cloud Shell に入っているか | Step 8 |
| Cloud Shell 再起動後に SSH できない | `~/.ssh/id_rsa` と環境変数を復旧したか | トラブルシューティングランブック |
| Log Analytics にデータがない | DCR 作成、VM 関連付け、数分の待機 | Step 10、Step 16 |

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

前のページ: [Day 0: 事前準備](day-0-prerequisites.ja.md)
迷ったとき: [受講者ポータル](../index.md) / [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) / [クイックリファレンス](../reference/quick-reference-card.ja.md)
