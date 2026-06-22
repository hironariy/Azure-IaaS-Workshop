---
title: "Day 1: Azure リソースデプロイ"
---

# Day 1: Azure リソースデプロイ

## このページでやること

Azure Cloud Shell Bash を使って、作業環境の準備、Bicep パラメータ作成、Azure IaaS 環境のデプロイ、MongoDB 初期化、Data Collection Rule 構成、Application Gateway FQDN 取得、フロントエンド SPA の redirect URI 更新までを進めます。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 0 の事前準備を終えた受講者 |
| 所要時間 | 45-75 分 |
| 前提 | Cloud Shell Bash、Entra ID アプリ登録値、VM クォータ、GitHub リポジトリのコピー |
| 完了条件 | Bicep deployment が `Succeeded` になり、デプロイ後セットアップ、DCR 構成、Application Gateway FQDN 取得、SPA redirect URI 更新が完了していること |

## 0. Cloud Shell Bash を開き、リポジトリを準備する

1. Azure Portal にサインインします。
2. 画面上部の Cloud Shell アイコンをクリックします。
3. シェル選択で **Bash** を選びます。
4. 初回起動時はストレージ作成を求められるため、講師の指定に従って作成します。

Cloud Shell Bash で、Day 0 で作成した自分のコピー先リポジトリを clone します。すでに clone 済みの場合は `cd` だけ実行します。

```bash
cd ~
if [ ! -d Azure-IaaS-Workshop ]; then
  git clone https://github.com/<OWNER>/Azure-IaaS-Workshop.git
fi
cd ~/Azure-IaaS-Workshop
```

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

Cloud Shell が切断された場合に備えて、秘密鍵と公開鍵を `~/clouddrive` に退避します。`~/clouddrive` は Cloud Shell の永続ストレージです。

```bash
mkdir -p ~/clouddrive/workshop-keys
cp ~/.ssh/id_rsa ~/.ssh/id_rsa.pub ~/clouddrive/workshop-keys/
chmod 600 ~/clouddrive/workshop-keys/id_rsa
```

**期待結果:** `ssh-rsa` で始まる公開鍵を取得できます。

**チェックポイント:** `main.local.bicepparam` に貼るのは公開鍵です。秘密鍵は Cloud Shell と `~/clouddrive/workshop-keys` だけに保持し、GitHub に push しません。

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

![Cloud Shell の VS Code](../assets/screenshots/learners-portal/day1/vscode.png)
*Cloud Shell の VS Code*

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
| `mongoDbAppPassword` | MongoDB アプリユーザーのパスワード | 自分で決める強い値。Step 9 の `<YOUR_MONGODB_APP_PASSWORD>` と完全一致させる。必ず下記の IMPORTANT の内容も読むこと。 |
| `appGatewayDnsLabel` | 一意な DNS ラベル | 例: `blogapp-team1-0106`。アルファベットの大文字や@などの特殊記号は利用しないこと。基本的には小文字、数字、ハイフンを利用する。 |

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

デプロイには 15-30 分かかることがあります。Application Gateway などは作成に時間がかかります。

**期待結果:** コマンドの最終出力に `"provisioningState": "Succeeded"` が表示されます。

**チェックポイント:** 10 分以上動いていないように見えてもすぐにキャンセルしません。Azure Portal でも進捗を確認します。

## 7. Portal でデプロイ進捗を確認する

1. Azure Portal > Resource groups を開きます。
2. 自身のリソースグループを開きます。
3. 左メニューのデプロイを開きます。
4. `main` または実行中の deployment を確認します。

![Azure Portal の該当のリソースグループのデプロイからも進捗を確認できる](../assets/screenshots/learners-portal/day1/deployment.png)
*Azure Portal の該当のリソースグループのデプロイからも進捗を確認できる*

## 8. Azure CLI の Bastion extension を準備する

デプロイ後セットアップとアプリケーション配置では `az network bastion ssh` を使います。Cloud Shell に Bastion extension が入っていない場合、セットアップスクリプトの SSH 実行で停止するため、ここで先に準備します。

```bash
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name bastion --upgrade --yes
az extension show --name bastion --query "{name:name,version:version}" -o table
```

**期待結果:** `bastion` extension の name と version が表示されます。

**チェックポイント:** `az network bastion ssh -h` を実行して help が表示されれば、以後の Bastion 経由 SSH コマンドを実行できます。

## 9. デプロイ後セットアップを実行する

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

## 10. Data Collection Rule を構成する

Log Analytics のテーブル初期化後に DCR を作成します。

```bash
cd ~/Azure-IaaS-Workshop
chmod +x scripts/configure-dcr.sh
./scripts/configure-dcr.sh "$RESOURCE_GROUP"
```

**期待結果:** Syslog と Perf の収集用 DCR が作成され、VM に関連付けられます。

**チェックポイント:** 新しい Log Analytics workspace ではテーブル初期化に 1-5 分かかることがあります。タイムアウトした場合は数分待って再実行します。

## 11. Application Gateway の FQDN を取得する

```bash
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "https://$FQDN"
```

**期待結果:** `https://<dns-label>.<region>.cloudapp.azure.com` 形式の URL が表示されます。

## 12. フロントエンド SPA のリダイレクト URI を更新する

Azure Portal でフロントエンド SPA のアプリ登録を開きます。

1. Microsoft Entra ID > App registrations > `BlogApp Frontend <自分またはチーム名>` を開きます。
2. Authentication を開きます。
3. Single-page application の Redirect URIs に次を追加します。
   - `https://<YOUR_FQDN>`
   - `https://<YOUR_FQDN>/`
4. 保存します。

**期待結果:** 本番 URL で MSAL のリダイレクトが許可されます。

**チェックポイント:** `http://localhost:5173` はローカル開発用として残して構いません。Day 1 の本線では `https://<YOUR_FQDN>` を追加します。

## よくある失敗と確認先

| 症状 | 確認すること | 参照先 |
|---|---|---|
| VM SKU が利用できない | `az vm list-skus --location japanwest --size Standard_B -o table` | `main.local.bicepparam` の VM size |
| DNS label が重複する | `appGatewayDnsLabel` がリージョン内で一意か | Step 4 |
| Deployment が失敗する | Portal の Deployments の失敗リソースと error details | Step 7 |
| MongoDB 接続に失敗する | `mongoDbAppPassword` と post-deployment script の値、`@` を含まない password か | Step 4、Step 9 |
| `az network bastion ssh` が見つからない | Bastion extension が Cloud Shell に入っているか | Step 8 |
| Cloud Shell 再起動後に SSH できない | `~/.ssh/id_rsa` と環境変数を復旧したか | トラブルシューティングランブック |
| Log Analytics にデータがない | DCR 作成、VM 関連付け、数分の待機 | Step 10、監視ガイド |

## Day 1 Azure リソースデプロイ完了条件

- Cloud Shell 上にリポジトリを clone できた。
- SSH 鍵と SSL 証明書を作成できた。
- `main.local.bicepparam` を作成し、必要値を設定できた。
- Bicep deployment が `Succeeded` になった。
- Azure CLI の Bastion extension を準備できた。
- デプロイ後セットアップが完了した。
- Data Collection Rule を構成できた。
- Application Gateway の FQDN を取得できた。
- フロントエンド SPA の本番リダイレクト URI を追加できた。

## 次に進む

[Day 1: アプリデプロイ](day-1-app-deployment.ja.md) に進みます。

前のページ: [Day 0: 事前準備](day-0-prerequisites.ja.md)
迷ったとき: [受講者ポータル](../index.md) / [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) / [クイックリファレンス](../reference/quick-reference-card.ja.md)
