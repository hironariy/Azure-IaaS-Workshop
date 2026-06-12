---
title: Azure Cloud Shell ミニガイド
---

# Azure Cloud Shell ミニガイド

## このページでやること

Azure Cloud Shell を Bash モードで開き、Day 1 本編を進めるための基本操作だけを確認します。リポジトリ clone、SSH 鍵作成、SSL 証明書作成、Bicep パラメータ編集は [Day 1: Azure リソースデプロイとアプリ配置](day-1-deployment-checklist.ja.md) の第1章で実施します。

| 項目 | 内容 |
|---|---|
| 対象者 | Cloud Shell の開き方や Bash への切り替えだけを確認したい受講者 |
| 所要時間 | 3-5 分 |
| 前提 | Azure Portal にサインインできること |
| 完了条件 | Cloud Shell Bash のプロンプトを開き、Day 1 本編に戻れること |

## 1. Cloud Shell を Bash で開く

1. [Azure Portal](https://portal.azure.com) にサインインします。
2. 画面上部の Cloud Shell アイコンをクリックします。
3. 初回起動時はストレージ作成を求められるため、講師の指定に従って作成します。
4. シェル選択で **Bash** を選びます。

**期待結果:** Cloud Shell のプロンプトが表示され、コマンドを入力できます。

**チェックポイント:** Day 1 のコマンド例は Bash 用です。PowerShell を開いている場合は Bash に切り替えてください。

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

## 3. Cloud Shell editor を開く

Cloud Shell では `code` コマンドで Web エディタを開けます。

```bash
code .
```

保存後は Cloud Shell のプロンプトに戻り、次のコマンドを続けます。`code` が開かない場合は数秒待って再実行し、それでも開かない場合は `nano` を使います。

## 4. セッションが切れた場合に復帰する

Cloud Shell は長時間操作しないと切断されることがあります。再接続後は、Day 1 の手順に戻り、リポジトリディレクトリ、作業変数、SSH 鍵を復旧します。

```bash
cd ~/Azure-IaaS-Workshop
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

SSH 鍵を `~/clouddrive/workshop-keys` に退避していた場合は、次で戻します。

```bash
mkdir -p ~/.ssh
cp ~/clouddrive/workshop-keys/id_rsa ~/clouddrive/workshop-keys/id_rsa.pub ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

詳しい復旧手順は [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md) を参照してください。

## 次に進む

[Day 1: Azure リソースデプロイとアプリ配置](day-1-deployment-checklist.ja.md) に戻ります。

戻る: [受講者ポータル](../index.md)
