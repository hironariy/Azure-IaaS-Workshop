---
title: "Day 0: 事前準備"
---

# Day 0: 事前準備

## このページでやること

ワークショップ開始前または冒頭で、Azure Portal、Cloud Shell、Entra ID アプリ登録権限、VM クォータ、GitHub リポジトリの準備を確認します。

| 項目 | 内容 |
|---|---|
| 対象者 | 2 日版ワークショップの受講者 |
| 所要時間 | 30-45 分 |
| 前提 | Azure サブスクリプション、GitHub アカウント、ブラウザ |
| 完了条件 | Day 1 の Cloud Shell デプロイに必要な値と権限が揃っていること |

## 1. Azure Portal にサインインする

1. [Azure Portal](https://portal.azure.com) を開きます。
2. ワークショップで使うアカウントでサインインします。
3. 右上のアカウントとディレクトリが想定どおりか確認します。

**期待結果:** Azure Portal のホームまたはダッシュボードが表示されます。

**チェックポイント:** 複数テナントを持つ場合は、ワークショップで使うテナントへ切り替えてください。

## 2. Cloud Shell を一度起動する

Day 1 で待ち時間を減らすため、事前に Cloud Shell を起動して初回ストレージ作成を完了させます。

1. Azure Portal 上部の Cloud Shell アイコンをクリックします。
2. Bash を選択します。
3. 初回ストレージ作成が表示された場合は、講師の指定に従って作成します。

**期待結果:** Bash プロンプトが表示されます。

**チェックポイント:** Cloud Shell 起動手順は [Azure Cloud Shell ガイド](azure-cloud-shell-guide.ja.md) でも確認できます。

## 3. サブスクリプションとクォータを確認する

Cloud Shell Bash で次を実行します。

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

必要に応じてサブスクリプションを切り替えます。

```bash
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
```

このワークショップでは B シリーズ VM を 6 台使います。

| VM サイズ | 台数 | 各 vCPU | 合計 |
|---|---:|---:|---:|
| Standard_B2s (Web) | 2 | 2 | 4 |
| Standard_B2s (App) | 2 | 2 | 4 |
| Standard_B4ms (DB) | 2 | 4 | 8 |
| **合計** | **6** |  | **16 vCPU** |

```bash
az vm list-usage --location japanwest \
  --query "[?contains(name.value, 'standardBSFamily') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

**期待結果:** B シリーズまたはリージョン全体で、少なくとも 16 vCPU 分の余裕があることを確認できます。

**チェックポイント:** クォータが不足している場合は、講師に相談してください。リージョン変更やクォータ増加申請が必要になることがあります。

## 4. リソースプロバイダーを確認する

```bash
for provider in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault Microsoft.OperationalInsights Microsoft.Insights; do
  az provider show --namespace "$provider" --query "{namespace:namespace,state:registrationState}" -o table
done
```

`NotRegistered` がある場合は、講師の指示に従って登録します。

```bash
az provider register --namespace Microsoft.Compute
```

**期待結果:** 必要なプロバイダーが `Registered` になります。

## 5. GitHub テンプレートリポジトリをコピーする

1. [hironariy/Azure-IaaS-Workshop](https://github.com/hironariy/Azure-IaaS-Workshop) を開きます。
2. **Use this template** > **Create a new repository** を選択します。
3. Owner は自分の GitHub アカウントまたは指定組織を選びます。
4. Repository name は `Azure-IaaS-Workshop` または講師指定の名前にします。
5. Visibility は、組織ポリシーに反しない範囲で Cloud Shell から認証なしで clone できる公開範囲を推奨します。

**期待結果:** 自分用の作業リポジトリが作成されます。

**チェックポイント:** Day 1 ではテンプレート元ではなく、自分のコピーを clone します。

## 6. Entra ID アプリ登録権限を確認する

Microsoft Entra ID でアプリ登録を作成するには、次のいずれかが必要です。

| 権限または設定 | 説明 |
|---|---|
| アプリケーション開発者 | IT 管理者が割り当てるロール |
| クラウドアプリケーション管理者 | IT 管理者が割り当てるロール |
| グローバル管理者 | テナント管理者 |
| ユーザーはアプリケーションを登録できる | テナント設定で許可されている場合 |

確認方法:

1. Azure Portal > Microsoft Entra ID > App registrations を開きます。
2. **New registration** をクリックします。
3. 登録フォームが表示されれば、作成権限があります。

権限がない場合は、講師に相談してください。講師が事前作成した Client ID を配布する場合があります。

## 7. フロントエンド SPA アプリ登録を作成する

1. Microsoft Entra ID > App registrations > **New registration** を開きます。
2. Name に `BlogApp Frontend <自分またはチーム名>` を入力します。
3. Supported account types は講師指定がなければ **Accounts in this organizational directory only** を選びます。
4. Redirect URI は platform に **Single-page application (SPA)** を選び、`http://localhost:5173` を入力します。
5. Register をクリックします。
6. Overview で **Application (client) ID** と **Directory (tenant) ID** を控えます。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day0-entra-frontend-overview.png`
> - Capture target: Frontend app registration overview page
> - Purpose: フロントエンド SPA の client ID と tenant ID の確認位置を示す
> - Suggested alt text: Microsoft Entra frontend app registration overview showing client and tenant IDs
> - Insertion note: ID 値はマスクし、項目名と配置が分かるように撮影する
> - Mask: Client ID、Tenant ID、アカウント名、メールアドレス、組織名

**期待結果:** フロントエンド用 Client ID を取得できます。

**チェックポイント:** Platform は必ず SPA です。Web を選ぶと MSAL.js の認証で `AADSTS9002326` が発生します。

## 8. バックエンド API アプリ登録を作成する

1. App registrations > **New registration** を開きます。
2. Name に `BlogApp API <自分またはチーム名>` を入力します。
3. Redirect URI は空のまま Register します。
4. Overview で **Application (client) ID** を控えます。
5. 左メニューの **Expose an API** を開きます。
6. **Add a scope** をクリックし、Application ID URI は既定値で保存します。
7. Scope name に `access_as_user` を入力します。
8. Who can consent は **Admins and users** を選びます。
9. Admin consent display name と description を入力し、スコープを追加します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day0-entra-api-overview.png`
> - Capture target: Backend API app registration overview page
> - Purpose: バックエンド API の client ID の確認位置を示す
> - Suggested alt text: Microsoft Entra backend API app registration overview showing client ID
> - Insertion note: ID 値はマスクし、Overview の項目名が読める状態を撮影する
> - Mask: Client ID、Tenant ID、アカウント名、メールアドレス、組織名

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day0-entra-api-scope.png`
> - Capture target: Expose an API page with access_as_user scope
> - Purpose: API スコープ `access_as_user` の設定場所を示す
> - Suggested alt text: Microsoft Entra Expose an API page showing access_as_user scope
> - Insertion note: Scope 名が分かる状態を撮影する。ID 値はマスクする
> - Mask: Application ID URI、Client ID、Tenant ID、アカウント名

**期待結果:** バックエンド API 用 Client ID と `access_as_user` スコープを作成できます。

## 9. フロントエンドに API アクセス許可を追加する

1. フロントエンド SPA のアプリ登録を開きます。
2. **API permissions** > **Add a permission** をクリックします。
3. **APIs my organization uses** または **My APIs** から `BlogApp API <自分またはチーム名>` を選びます。
4. `access_as_user` を選択して追加します。
5. 管理者権限があり講師が指示した場合のみ、admin consent を付与します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day0-entra-api-permission.png`
> - Capture target: Frontend app API permissions page with BlogApp API access_as_user permission
> - Purpose: フロントエンドがバックエンド API を呼び出す権限設定を確認する
> - Suggested alt text: Microsoft Entra API permissions page showing BlogApp API access_as_user permission
> - Insertion note: 権限名と状態が分かる状態を撮影する。組織名はマスクする
> - Mask: テナント名、組織名、アカウント名、メールアドレス、Client ID

**期待結果:** フロントエンドアプリにバックエンド API の delegated permission が追加されます。

## 10. Day 1 で使う値を控える

| 値 | 取得場所 | Day 1 のパラメータ |
|---|---|---|
| Tenant ID | 任意のアプリ登録 Overview または `az account show` | `entraTenantId` |
| Backend API Client ID | Backend API アプリ登録 Overview | `entraClientId` |
| Frontend SPA Client ID | Frontend SPA アプリ登録 Overview | `entraFrontendClientId` |
| Admin Object ID | `az ad signed-in-user show --query id -o tsv` | `adminObjectId` |

**チェックポイント:** Client ID と Tenant ID は識別子ですが、公開リポジトリへ作業メモとして雑に push しないでください。パスワードやシークレットは絶対に記録しません。

## 次に進む

[Azure Cloud Shell ガイド](azure-cloud-shell-guide.ja.md) に進みます。

前のページ: [受講者クイックスタート](learner-quickstart.ja.md)  
迷ったとき: [受講者ポータル](../index.md) / [トラブルシューティングランブック](../operations/troubleshooting-runbook.ja.md)
