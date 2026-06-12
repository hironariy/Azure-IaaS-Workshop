---
title: "Day 1: アプリデプロイ"
---

# Day 1: アプリデプロイ

## このページでやること

[Day 1: Azure リソースデプロイ](day-1-deployment-checklist.ja.md) で作成した App tier / Web tier の VM に、Backend API と Frontend のアプリケーションコードを手作業で配置します。Bastion 経由で各 VM に接続し、VM 内で確認、clone、build、起動、検証を行います。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 1 の Azure リソースデプロイを完了した受講者 |
| 所要時間 | 45-75 分 |
| 前提 | `RESOURCE_GROUP`、`FQDN`、Bastion extension、SSH 鍵、Application Gateway redirect URI 更新が完了していること |
| 完了条件 | Backend API が 2 台の App VM で PM2 `online` になり、Frontend が 2 台の Web VM の NGINX root に配置され、Application Gateway 経由でアプリが表示されること |

## 0. 作業変数と前提を確認する

Cloud Shell で、リポジトリルートにいることを確認します。

```bash
cd ~/Azure-IaaS-Workshop

RESOURCE_GROUP="rg-blogapp-workshop"
```

複数グループ構成の場合は、`RESOURCE_GROUP` を講師から割り当てられた値に置き換えます。

```bash
RESOURCE_GROUP="rg-blogapp-A-workshop"
```

Application Gateway の FQDN を再取得します。

```bash
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "https://$FQDN"
```

Bastion extension と SSH 鍵を確認します。

```bash
az extension show --name bastion --query "{name:name,version:version}" -o table
ls -l ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
```

**チェックポイント:** `az network bastion ssh -h` で help が表示され、`~/.ssh/id_rsa` が存在することを確認します。Cloud Shell を再接続した場合は [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) の Cloud Shell 復旧手順を先に実行します。

## 1. 配置対象リポジトリと VM 名を確認する

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

## 2. App VM に Bastion 経由で接続する

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

以降の **3 から 7** は、接続先の App VM 内で実行します。`vm-app-az1-prod` で完了したら `exit` で Cloud Shell に戻り、同じ手順を `vm-app-az2-prod` でも繰り返します。

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

## 3. App VM の Node.js、PM2、環境変数を確認する

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

## 4. App VM の一時 health server を削除する

Bicep は App tier の起動確認用に `blogapp-health` という一時的な PM2 process を作成します。実アプリを起動する前に削除します。

```bash
pm2 list
pm2 delete blogapp-health 2>/dev/null || true
pm2 save
pm2 list
```

**チェックポイント:** `blogapp-health` が存在しない、または削除済みであることを確認します。

## 5. Backend API のコードを配置する

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

## 6. Backend API を build して PM2 で起動する

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

**期待結果:** `blogapp-api` が PM2 の `online` 状態になります。ログ表示が続く場合は `Ctrl+C` でプロンプトに戻ります。

## 7. Backend API を App VM 内で検証する

接続先の App VM で実行します。

```bash
curl http://localhost:3000/health
curl http://localhost:3000/api/posts
curl http://10.0.2.10:3000/health
```

**期待結果:** health endpoint が `healthy` を返し、`/api/posts` が JSON 配列を返します。投稿がまだない場合は `[]` が正常です。

`vm-app-az1-prod` の作業が終わったら `exit` で Cloud Shell に戻り、`vm-app-az2-prod` に接続して **3 から 7** を繰り返します。

## 8. Web VM に Bastion 経由で接続する

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

以降の **9 から 12** は、接続先の Web VM 内で実行します。`vm-web-az1-prod` で完了したら `exit` で Cloud Shell に戻り、同じ手順を `vm-web-az2-prod` でも繰り返します。

```bash
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group "$RESOURCE_GROUP" \
  --target-resource-id "$(az vm show -g "$RESOURCE_GROUP" -n vm-web-az2-prod --query id -o tsv)" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

## 9. Web VM の NGINX と runtime config を確認する

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

## 10. Frontend を build する

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

## 11. Frontend の静的ファイルを NGINX に配置する

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

## 12. Web VM 内で NGINX と API proxy を検証する

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

`vm-web-az1-prod` の作業が終わったら `exit` で Cloud Shell に戻り、`vm-web-az2-prod` に接続して **9 から 12** を繰り返します。

## 13. Application Gateway 経由でアプリケーションを確認する

App tier と Web tier の配置後、Cloud Shell から外部 URL を確認します。

```bash
curl -k -I "https://$FQDN/"
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

**期待結果:** `/` は `200` または HTML 応答になり、`/api/posts` は JSON 配列を返します。ブラウザでは自己署名証明書の警告を通過後、ブログアプリが表示されます。

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

## よくある失敗と確認先

| 症状 | 主な原因 | 確認すること |
|---|---|---|
| `git clone` が失敗する | `REPOSITORY_URL` がテンプレート元、private repository、または誤った URL になっている | Day 0 で作成した自分のコピーを指定しているか、VM から認証なしで clone できるか |
| `/` が `403 Forbidden` になる | Web VM に frontend の `index.html` が配置されていない | Step 11 が 2 台の Web VM で成功したか |
| `/api/posts` が `502` または `504` になる | App tier の `blogapp-api` が起動していない、または MongoDB に接続できない | Step 6、Step 7、Azure リソースデプロイ Step 4 / Step 9 の MongoDB password 一致 |
| `npm ci` が失敗する | package lock と依存関係の取得に失敗している | VM から GitHub/npm へ outbound 接続できるか、再実行しても同じか |
| `config.json` が見つからない | Web tier の Bicep CustomScript が未完了または失敗している | Azure Portal の VM extensions と Azure リソースデプロイ Step 7 の deployment status |
| ログインに失敗する | SPA redirect URI と API permission が不足している | Azure リソースデプロイ Step 12 と Day 0 の API permission |

## Day 1 アプリデプロイ完了条件

- Backend API を 2 台の App VM に配置し、`blogapp-api` を PM2 で起動できた。
- App VM 内で `/health` と `/api/posts` を確認できた。
- Frontend を 2 台の Web VM に配置し、`index.html` と `config.json` を確認できた。
- Web VM 内で `/`、`/login`、`/api/posts` を確認できた。
- Application Gateway 経由でアプリケーションの疎通確認ができた。
- Application Gateway backend health を確認できた。

## 次に進む

Day 1 の監視演習では [監視ガイド](../operations/monitoring-guide.ja.md) を参照します。

前のページ: [Day 1: Azure リソースデプロイ](day-1-deployment-checklist.ja.md)
迷ったとき: [受講者ポータル](../index.md) / [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) / [クイックリファレンス](../reference/quick-reference-card.ja.md)
