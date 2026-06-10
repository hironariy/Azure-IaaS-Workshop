---
title: Azure Cloud Shell ガイド
---

# Azure Cloud Shell ガイド

## このページでやること

Azure Cloud Shell を Bash モードで開き、ワークショップ用リポジトリの clone、ファイル編集、Azure CLI の状態確認、SSH 鍵と SSL 証明書の準備を行える状態にします。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 1 のデプロイ作業を Cloud Shell で進める受講者 |
| 所要時間 | 15-25 分 |
| 前提 | Azure Portal にサインインできること、GitHub のリポジトリ URL が分かること |
| 完了条件 | Cloud Shell Bash でリポジトリを clone し、`code` でファイルを開けること |

## 1. Cloud Shell を Bash で開く

1. [Azure Portal](https://portal.azure.com) にサインインします。
2. 画面上部の Cloud Shell アイコンをクリックします。
3. 初回起動時はストレージ作成を求められるため、講師の指定に従って作成します。
4. シェル選択で **Bash** を選びます。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-cloud-shell-launch.png`
> - Capture target: Azure Portal Cloud Shell launch screen
> - Purpose: 受講者が Azure Portal から Cloud Shell を起動する位置を確認する
> - Suggested alt text: Azure Portal showing the Cloud Shell launch button
> - Insertion note: Portal 上部の Cloud Shell アイコンと起動後のペインが分かる状態を撮影する
> - Mask: アカウント名、テナント ID、サブスクリプション ID

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-cloud-shell-bash.png`
> - Capture target: Cloud Shell with Bash mode selected
> - Purpose: 受講者が PowerShell ではなく Bash を選んでいることを確認する
> - Suggested alt text: Azure Cloud Shell opened in Bash mode
> - Insertion note: プロンプトと Bash 表示が分かる状態を撮影する
> - Mask: アカウント名、テナント ID、サブスクリプション ID

**期待結果:** Cloud Shell のプロンプトが表示され、コマンドを入力できます。

**チェックポイント:** 以後のコマンド例は Bash 用です。PowerShell を開いている場合は Bash に切り替えてください。

## 2. サブスクリプションとテナントを確認する

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

複数サブスクリプションがある場合は、講師から指定されたサブスクリプションへ切り替えます。

```bash
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

**期待結果:** ワークショップで使うサブスクリプション名とテナント ID が表示されます。

**チェックポイント:** 表示されたテナント ID は、Day 0 の Entra ID アプリ登録で使うテナントと一致している必要があります。

## 3. リポジトリを clone する

受講者は、このテンプレートリポジトリを自分の GitHub アカウントまたは指定組織にコピーしてから clone します。コピー先を private にすると Cloud Shell で GitHub 認証が必要になるため、ワークショップでは組織ポリシーに反しない範囲で認証不要の clone ができる公開範囲を推奨します。

```bash
cd ~
git clone https://github.com/<OWNER>/Azure-IaaS-Workshop.git
cd Azure-IaaS-Workshop
```

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-git-clone-complete.png`
> - Capture target: Cloud Shell after git clone and cd into the repository
> - Purpose: clone が完了し、作業ディレクトリがリポジトリルートであることを確認する
> - Suggested alt text: Azure Cloud Shell showing completed git clone of the workshop repository
> - Insertion note: `git clone` の完了メッセージと `pwd` またはプロンプトのパスが見える状態を撮影する
> - Mask: GitHub ユーザー名、組織名、アカウント名

**期待結果:** `Azure-IaaS-Workshop` ディレクトリに移動できます。

**チェックポイント:** 以後の手順はリポジトリルートから実行します。

## 4. Cloud Shell editor でファイルを編集する

Cloud Shell では `code` コマンドで Web エディタを開けます。

```bash
code materials/bicep/main.bicepparam
```

保存後は Cloud Shell のプロンプトに戻り、次のコマンドを続けます。

**代替:** `nano` や `vi` も使用できますが、ワークショップでは画面を揃えるため `code` を標準にします。

## 5. SSH 鍵を Cloud Shell 内で作成する

ワークショップ用の SSH 鍵は Cloud Shell 内で作成します。

```bash
ssh-keygen -t rsa -b 4096 -C "workshop@azure"
cat ~/.ssh/id_rsa.pub
```

**期待結果:** 公開鍵が `ssh-rsa ...` で始まる 1 行の文字列として表示されます。

**チェックポイント:** `main.local.bicepparam` には公開鍵を貼り付けます。秘密鍵 `~/.ssh/id_rsa` は貼り付けたり GitHub に push したりしません。

## 6. SSL 証明書を Cloud Shell で生成する

Application Gateway の HTTPS 終端用に、ワークショップ用の自己署名証明書を作成します。

```bash
chmod +x scripts/generate-ssl-cert.sh
./scripts/generate-ssl-cert.sh
cat cert-base64.txt
```

**期待結果:** リポジトリルートに `cert.pfx` と `cert-base64.txt` が作成されます。

**チェックポイント:** `cert-base64.txt` の内容を `sslCertificateData` に貼り付けます。スクリプト既定の PFX パスワードは `Workshop2024!` です。証明書ファイルと `cert-base64.txt` は `.gitignore` 対象であり、GitHub に push しません。

## 7. セッションが切れた場合に復帰する

Cloud Shell は長時間操作しないと切断されることがあります。再接続後は次を確認します。

```bash
cd ~/Azure-IaaS-Workshop
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

デプロイ中に切断された場合でも、Azure Portal の Resource group > Deployments で進捗を確認できます。

## よくあるつまずき

| 症状 | 確認すること | 対処 |
|---|---|---|
| PowerShell のプロンプトになっている | Cloud Shell の左上表示 | Bash に切り替える |
| `git clone` が認証で失敗する | コピー先リポジトリが private ではないか | public にするか、講師の指示に従って GitHub 認証を行う |
| `code` が開かない | Cloud Shell editor の起動待ち | 数秒待つ。だめな場合は `nano` を使う |
| デプロイ中に Cloud Shell が切れた | Portal の Deployments | 再接続して `az deployment group show` または Portal で状態確認する |
