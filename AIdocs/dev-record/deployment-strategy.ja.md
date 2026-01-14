# Azure VM へのブログアプリケーション デプロイ戦略

**日付:** 2025年12月16日  
**著者:** AI Deployment Agent  
**ステータス:** Template Ready  
**最終更新:** 2026年1月 - Application Gateway の SSL/TLS 終端対応に更新

---

English version: [Deployment Strategy for Blog Application to Azure VMs](./deployment-strategy.md)

## エグゼクティブ サマリー

このドキュメントは、マルチティア構成のブログアプリケーションを Azure VM にデプロイするための戦略をまとめたものです。VM は Bicep テンプレートでプロビジョニングされ、テンプレートには **CustomScript Extensions** が含まれます。これにより以下を実施します。

1. すべてのミドルウェア（MongoDB / Node.js / PM2 / NGINX）を事前インストール
2. Bicep パラメータから App tier VM に **環境変数を注入**
3. フロントエンドの実行時設定のために Web tier VM 上に **`/config.json` を作成**

### デプロイ状況

| コンポーネント | 状態 | リソース グループ |
|-----------|--------|----------------|
| インフラ | ✅ 検証済み | `<YOUR_RESOURCE_GROUP>` |
| 設定注入（App tier） | ✅ 全 VM で検証済み | `/etc/environment`, `/opt/blogapp/.env` |
| 設定注入（Web tier） | ✅ 全 VM で検証済み | `/var/www/html/config.json` |
| MongoDB レプリカセット | ✅ 検証済み | `post-deployment-setup.local.sh` |
| バックエンド アプリケーション | ✅ 検証済み | デプロイ済み・稼働中 |
| フロントエンド アプリケーション | ✅ 検証済み | 静的ファイル デプロイ済み |

### デプロイ フロー概要

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT FLOW                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Generate Self-Signed SSL Certificate                                │
│     └─ ./scripts/generate-ssl-cert.sh                                   │
│                          ↓                                               │
│  2. Edit main.bicepparam (or main.local.bicepparam)                     │
│     ├─ entraTenantId                                                    │
│     ├─ entraClientId (backend)                                          │
│     ├─ entraFrontendClientId                                            │
│     ├─ sshPublicKey                                                     │
│     ├─ adminObjectId                                                    │
│     ├─ sslCertificateData (base64-encoded PFX)                         │
│     ├─ sslCertificatePassword                                           │
│     └─ appGatewayDnsLabel (unique DNS label)                           │
│                          ↓                                               │
│  3. az deployment group create ...                                       │
│     └─ Creates all Azure resources with config injected                 │
│     └─ Application Gateway provides HTTPS with self-signed cert         │
│                          ↓                                               │
│  4. Post-deployment script (choose your platform)                       │
│     ├─ macOS/Linux: ./scripts/post-deployment-setup.local.sh            │
│     └─ Windows:     .\scripts\post-deployment-setup.local.ps1           │
│     Performs:                                                           │
│     ├─ Initializes MongoDB replica set                                  │
│     ├─ Creates MongoDB users (blogadmin, blogapp)                       │
│     └─ Verifies config injection (env vars, config.json)                │
│                          ↓                                               │
│  5. Deploy application code (backend + frontend)                        │
│     └─ No environment configuration needed!                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Bicep がプロビジョニングするもの（完全自動）

| Tier | Bicep により事前インストール | 設定注入 | 状態 |
|------|------------------------|------------------|--------|
| **Database** | MongoDB 7.0、`/data/mongodb` にデータディスク、レプリカセット設定 | N/A | ✅ 自動化 |
| **Backend** | Node.js 20 LTS、PM2、`/opt/blogapp` ディレクトリ | Entra ID を含む `/etc/environment` + `/opt/blogapp/.env` | ✅ 自動化 |
| **Frontend** | NGINX、リバースプロキシ設定、`/var/www/html` | Entra ID を含む `/var/www/html/config.json` | ✅ 自動化 |
| **Application Gateway** | SSL/TLS 終端、HTTP→HTTPS リダイレクト | 自己署名証明書、Azure DNS ラベル | ✅ 自動化 |

> **実装メモ:** Bicep テンプレートは、`loadTextContent()` で外部シェルスクリプトを読み込み、`replace()` 関数でプレースホルダ置換を行います。これにより、bash スクリプトや JSON に含まれる波括弧が原因で ARM の `format()` 関数が問題を起こすケースを回避できます。
>
> - `modules/compute/scripts/nginx-install.sh` - Web tier セットアップ スクリプト
> - `modules/compute/scripts/nodejs-install.sh` - App tier セットアップ スクリプト

### ポストデプロイで必要な作業

| タスク | 手動/自動 | スクリプト（macOS/Linux） | スクリプト（Windows） |
|------|------------------|----------------------|------------------|
| MongoDB レプリカセット初期化 | **自動** | `post-deployment-setup.local.sh` | `post-deployment-setup.local.ps1` |
| MongoDB ユーザー作成 | **自動** | `post-deployment-setup.local.sh` | `post-deployment-setup.local.ps1` |
| バックエンド アプリケーションのコード デプロイ | 手動 | Phase 2 を参照 | Phase 2 を参照 |
| フロントエンド静的ファイルのデプロイ | 手動 | Phase 3 を参照 | Phase 3 を参照 |

### 対象環境

| Tier | VM | IP | 事前インストール | 設定ファイル |
|------|-----|-----|---------------|--------------|
| Database | `vm-db-az1-prod`, `vm-db-az2-prod` | 10.0.3.4, 10.0.3.5 | MongoDB 7.0 | N/A |
| Backend | `vm-app-az1-prod`, `vm-app-az2-prod` | 10.0.2.5, 10.0.2.4 | Node.js 20, PM2 | `/etc/environment`, `/opt/blogapp/.env` |
| Frontend | `vm-web-az1-prod`, `vm-web-az2-prod` | 10.0.1.4, 10.0.1.5 | NGINX | `/var/www/html/config.json` |
| Application Gateway | N/A（PaaS） | Public IP | SSL/TLS 終端 | 自己署名証明書 |

### トラフィック フロー

```
Internet → Application Gateway (HTTPS:443)
         → SSL/TLS Termination (self-signed certificate)
         → Web Tier VMs (HTTP:80/NGINX)
         → Internal Load Balancer (HTTP:3000)
         → App Tier VMs (Express API)
         → MongoDB Replica Set
```

---

## デプロイ前: SSL 証明書の生成と Bicep パラメータの設定

### Step 0: 自己署名 SSL 証明書の生成

**デプロイ前に**、Application Gateway 用の自己署名 SSL 証明書を生成します。

**macOS/Linux:**
```bash
# Navigate to project root
cd /path/to/AzureIaaSWorkshop

# Generate self-signed certificate (valid for 365 days)
# This creates: cert.pfx and cert-base64.txt files
./scripts/generate-ssl-cert.sh

# The script will output:
# - cert.pfx (PKCS#12 format for Azure Application Gateway)
# - cert.pem (PEM format for reference)
# - cert-base64.txt (base64-encoded PFX for Bicep parameter)
```

**Windows PowerShell:**
```powershell
# Navigate to project root
cd C:\path\to\AzureIaaSWorkshop

# Generate self-signed certificate (valid for 365 days)
# Uses PowerShell's New-SelfSignedCertificate (no OpenSSL required)
.\scripts\generate-ssl-cert.ps1

# The script will output:
# - cert.pfx (PKCS#12 format for Azure Application Gateway)
# - cert-base64.txt (base64-encoded PFX for Bicep parameter)

# Copy base64 content to clipboard (for pasting into bicepparam)
Get-Content cert-base64.txt | Set-Clipboard
```

**手動での証明書生成（代替手段）:**

```bash
# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout cert.key -out cert.crt \
  -subj "/CN=blogapp.<region>.cloudapp.azure.com/O=Workshop/C=JP"

# Convert to PFX format (required for Application Gateway)
openssl pkcs12 -export -out cert.pfx -inkey cert.key -in cert.crt \
  -password pass:Workshop2024!

# Base64 encode for Bicep parameter
base64 -i cert.pfx | tr -d '\n' > cert-base64.txt
```

> **Note:** 証明書の CN は想定する FQDN と一致させる必要があります。ただし自己署名証明書の場合、いずれにせよブラウザ警告が表示されます。ワークショップ用途では許容されます。

### `main.bicepparam` に必要なパラメータ

デプロイ前に `main.bicepparam` を編集します（または個人値用に `main.local.bicepparam` をコピーして利用します）。

```bicep
using './main.bicep'

~~
skipped lines
~~

// ============================================================
// REQUIRED: Azure Security Parameters
// ============================================================
// SSH public key for VM access
param sshPublicKey = '<YOUR_SSH_PUBLIC_KEY>'

// Object ID of the admin user for Key Vault access
param adminObjectId = '<YOUR_ADMIN_OBJECT_ID>'

// ============================================================
// REQUIRED: Microsoft Entra ID Parameters  
// These values are injected into VMs by Bicep CustomScript
// ============================================================
// Your Azure AD tenant ID
param entraTenantId = '<YOUR_TENANT_ID>'

// Backend API app registration Client ID
param entraClientId = '<YOUR_BACKEND_CLIENT_ID>'

// Frontend SPA app registration Client ID
param entraFrontendClientId = '<YOUR_FRONTEND_CLIENT_ID>'

// ============================================================
// REQUIRED: Application Gateway SSL/TLS Configuration
// ============================================================
// Self-signed certificate (base64-encoded PFX)
// Generate with: ./scripts/generate-ssl-cert.sh
param sslCertificateData = '<CONTENTS_OF_cert-base64.txt>'

// Password for the PFX certificate
param sslCertificatePassword = 'Workshop2024!'

// Unique DNS label for Application Gateway public IP
// Results in FQDN: blogapp-<unique>.<region>.cloudapp.azure.com
param appGatewayDnsLabel = 'blogapp-<UNIQUE_SUFFIX>'
```

### DNS ラベルの選び方

`appGatewayDnsLabel` は **Azure リージョン内でグローバルに一意**である必要があります。Azure は次の形式で FQDN を作成します。

```
<your-label>.<region>.cloudapp.azure.com
```

**DNS ラベル選択のガイドライン:**

| アプローチ | 例 | 結果 FQDN |
|----------|---------|-------------|
| 名前 + ランダム | `blogapp-john-x7k2` | `blogapp-john-x7k2.japanwest.cloudapp.azure.com` |
| 名前 + 日付 | `blogapp-tanaka-0106` | `blogapp-tanaka-0106.japanwest.cloudapp.azure.com` |
| チーム + 番号 | `blogapp-team3` | `blogapp-team3.japanwest.cloudapp.azure.com` |

**一意なサフィックスを生成する簡単な方法:**

```bash
# macOS/Linux - generate random 4-character suffix
echo "blogapp-$(openssl rand -hex 2)"
# Example output: blogapp-a3f2
```

```powershell
# Windows PowerShell - generate random 4-character suffix
"blogapp-$(-join ((48..57) + (97..102) | Get-Random -Count 4 | ForEach-Object {[char]$_}))"
# Example output: blogapp-7b2e
```

> **Important:** デプロイが "DNS label already in use" で失敗した場合、別のラベルに変更して再デプロイしてください。

### 値の確認方法

**macOS/Linux (Azure CLI):**
```bash
# Get your Tenant ID
az account show --query tenantId -o tsv

# Get your Object ID (for Key Vault access)
az ad signed-in-user show --query id -o tsv

# List app registrations to find Client IDs
az ad app list --display-name "blogapp" --query "[].{name:displayName, appId:appId}"

# Get base64-encoded certificate (after running generate-ssl-cert.sh)
cat cert-base64.txt
```

**Windows PowerShell (Azure PowerShell):**
```powershell
# Get your Tenant ID
(Get-AzContext).Tenant.Id

# Get your Object ID (for Key Vault access)
(Get-AzADUser -SignedIn).Id

# List app registrations to find Client IDs
Get-AzADApplication -DisplayNameStartWith "blogapp" | Select-Object DisplayName, AppId

# Get base64-encoded certificate (after running generate-ssl-cert.ps1)
Get-Content cert-base64.txt
```

### Entra ID のリダイレクト URI 設定（SPA プラットフォーム）

フロントエンドのアプリ登録の **リダイレクト URI** を設定する必要があります。リダイレクト URI は Application Gateway の FQDN（HTTPS）を使用します。

> ⚠️ **CRITICAL**: フロントエンドのアプリ登録は **Single-page application (SPA)** プラットフォーム種別でなければなりません（"Web" ではありません）。MSAL.js は PKCE（Proof Key for Code Exchange）フローを使用しますが、これは SPA プラットフォーム種別でのみ動作します。"Web" プラットフォームを使うと、次のエラーになります: `AADSTS9002326: Cross-origin token redemption is permitted only for the 'Single-Page Application' client-type.`

> **Tip:** リダイレクト URI は、デプロイの前後どちらでも設定できます。FQDN は選択した DNS ラベルから予測可能です。

**Application Gateway の FQDN を組み立てる:**

`main.local.bicepparam` に設定した `appGatewayDnsLabel` に基づき、FQDN は次の予測可能な形式になります。

```
<appGatewayDnsLabel>.<region>.cloudapp.azure.com
```

| パラメータ | FQDN |
|----------------|-----------|
| `appGatewayDnsLabel = 'blogapp-john123'` | `blogapp-john123.japanwest.cloudapp.azure.com` |
| `appGatewayDnsLabel = 'blogapp-team5'` | `blogapp-team5.japanwest.cloudapp.azure.com` |
| `location = 'eastus'` + `appGatewayDnsLabel = 'blogapp-abc'` | `blogapp-abc.eastus.cloudapp.azure.com` |

**デプロイ後に確認（任意）:**

**macOS/Linux:**
```bash
# Confirm the FQDN matches your expectation
az network public-ip show \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv
```

**Windows PowerShell:**
```powershell
# Confirm the FQDN matches your expectation
$pip = Get-AzPublicIpAddress -ResourceGroupName <YOUR_RESOURCE_GROUP> -Name pip-agw-blogapp-prod
$pip.DnsSettings.Fqdn
```

**SPA のリダイレクト URI を Microsoft Graph で更新:**

> **Note:** `az ad app update` コマンドは `--spa-redirect-uris` をサポートしていません。Microsoft Graph API を直接使用する必要があります。

**macOS/Linux (Azure CLI with REST):**
```bash
# Replace <YOUR_FRONTEND_CLIENT_ID> with your frontend app's Client ID
# Replace <YOUR_APPGW_FQDN> with the FQDN from the command above
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='<YOUR_FRONTEND_CLIENT_ID>')" \
  --headers "Content-Type=application/json" \
  --body '{
    "spa": {
      "redirectUris": [
        "https://<YOUR_APPGW_FQDN>",
        "https://<YOUR_APPGW_FQDN>/",
        "http://localhost:5173",
        "http://localhost:5173/"
      ]
    },
    "web": {
      "redirectUris": []
    }
  }'
```

**Windows PowerShell (Microsoft Graph PowerShell):**
```powershell
# Install Microsoft Graph module if not installed
# Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All"

# Set your Frontend Client ID (from your App Registration)
$FrontendClientId = "<YOUR_FRONTEND_CLIENT_ID>"  # ← 実際の値に置き換えてください

# Set your Application Gateway FQDN
$FQDN = "<YOUR_APPGW_FQDN>"  # ← 実際の値に置き換えてください

# Get the application object
$app = Get-MgApplication -Filter "AppId eq '$FrontendClientId'"

# Update redirect URIs
$redirectUris = @(
    "https://$FQDN",
    "https://$FQDN/",
    "http://localhost:5173",
    "http://localhost:5173/"
)

Update-MgApplication -ApplicationId $app.Id -Spa @{RedirectUris = $redirectUris}

Write-Host "リダイレクト URI の更新が完了しました"
```

**実値の例:**
```bash
az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='cc795eea-9e46-429b-990d-6c75d942ef91')" \
  --headers "Content-Type=application/json" \
  --body '{
    "spa": {
      "redirectUris": [
        "https://blogapp-12345.japanwest.cloudapp.azure.com",
        "https://blogapp-12345.japanwest.cloudapp.azure.com/",
        "http://localhost:5173",
        "http://localhost:5173/"
      ]
    },
    "web": {
      "redirectUris": []
    }
  }'
```

**SPA のリダイレクト URI を確認:**

**macOS/Linux:**
```bash
az ad app show --id <YOUR_FRONTEND_CLIENT_ID> --query "spa.redirectUris"
```

**Windows PowerShell:**
```powershell
$app = Get-MgApplication -Filter "AppId eq '<YOUR_FRONTEND_CLIENT_ID>'"
$app.Spa.RedirectUris
```

| リダイレクト URI | 目的 |
|--------------|---------|
| `https://<YOUR_APPGW_FQDN>` | 本番 - MSAL ログイン後のリダイレクト |
| `https://<YOUR_APPGW_FQDN>/` | 本番 - 末尾スラッシュ付き（ブラウザが付与する場合あり） |
| `http://localhost:5173` | Vite を用いたローカル開発 |
| `http://localhost:5173/` | ローカル開発 - 末尾スラッシュ付き |

> **Note:** HTTPS は自己署名証明書を使った Application Gateway により提供されます。ブラウザで証明書警告が出ますが、ワークショップ用途では許容されます。本番では、信頼された CA の証明書、もしくは Azure Key Vault の証明書を使用してください。

**代替手段: Azure Portal を使う方法:**
1. Azure Portal → Microsoft Entra ID → App registrations → 対象のフロントエンド アプリ
2. 左メニューの **Authentication** をクリック
3. "Platform configurations" で **Single-page application**（"Web" ではない）になっていることを確認
4. "Web" プラットフォームの URI がある場合は削除し、代わりに "Single-page application" を追加
5. SPA セクションにリダイレクト URI を追加
6. **Save** をクリック

---

## Phase 0: インフラをデプロイし、ポストデプロイ スクリプトを実行

### 0.1 Bicep テンプレートのデプロイ

**macOS/Linux (Azure CLI):**
```bash
# Create resource group (choose your own name and region)
az group create --name <YOUR_RESOURCE_GROUP> --location <YOUR_REGION>

# Deploy infrastructure (initial deployment)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam

# Wait for deployment (15-30 minutes)
```

**Windows PowerShell (Azure PowerShell):**
```powershell
# Create resource group (choose your own name and region)
New-AzResourceGroup -Name <YOUR_RESOURCE_GROUP> -Location <YOUR_REGION>

# Deploy infrastructure (initial deployment)
# Note: Bicep CLI must be installed (winget install -e --id Microsoft.Bicep)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam

# Wait for deployment (15-30 minutes)
```

### 0.1.1 既存 VM の CustomScript を再実行（任意）

特定 tier（例: NGINX 設定更新）の CustomScript を再実行したい場合、**tier 別の force update タグ** と `skipVmCreation` を併用して、SSH キー変更エラーを回避します。

**macOS/Linux (Azure CLI):**
```bash
# Force re-run on Web tier only (e.g., NGINX config update)
# skipVmCreationWeb=true prevents "SSH key change not allowed" error
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationWeb=true \
               forceUpdateTagWeb="$(date +%Y%m%d%H%M%S)"

# Force re-run on App tier only (e.g., Node.js env update)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationApp=true \
               forceUpdateTagApp="$(date +%Y%m%d%H%M%S)"

# Force re-run on DB tier only (rarely needed)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationDb=true \
               forceUpdateTagDb="$(date +%Y%m%d%H%M%S)"

# Force re-run on ALL tiers (use with caution)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
az deployment group create \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationWeb=true skipVmCreationApp=true skipVmCreationDb=true \
               forceUpdateTagWeb="$TIMESTAMP" \
               forceUpdateTagApp="$TIMESTAMP" \
               forceUpdateTagDb="$TIMESTAMP"
```

**Windows PowerShell (Azure PowerShell):**
```powershell
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"

# Force re-run on Web tier only (e.g., NGINX config update)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationWeb $true `
  -forceUpdateTagWeb $Timestamp

# Force re-run on App tier only (e.g., Node.js env update)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationApp $true `
  -forceUpdateTagApp $Timestamp

# Force re-run on DB tier only (rarely needed)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationDb $true `
  -forceUpdateTagDb $Timestamp

# Force re-run on ALL tiers (use with caution)
New-AzResourceGroupDeployment `
  -ResourceGroupName <YOUR_RESOURCE_GROUP> `
  -TemplateFile materials/bicep/main.bicep `
  -TemplateParameterFile materials/bicep/main.local.bicepparam `
  -skipVmCreationWeb $true `
  -skipVmCreationApp $true `
  -skipVmCreationDb $true `
  -forceUpdateTagWeb $Timestamp `
  -forceUpdateTagApp $Timestamp `
  -forceUpdateTagDb $Timestamp
```

| パラメータ | 目的 |
|-----------|---------|
| `skipVmCreationWeb/App/Db` | **再デプロイに必須**。VM リソース更新をスキップし、拡張機能のみ更新します。"SSH key change not allowed" エラーを回避します。 |
| `forceUpdateTagWeb/App/Db` | 値を変更すると CustomScript 拡張機能の再実行を強制します |

| Tier | forceUpdateTag | skipVmCreation | 使いどころ |
|------|----------------|----------------|-------------|
| Web（NGINX） | `forceUpdateTagWeb` | `skipVmCreationWeb` | NGINX 設定更新、セキュリティヘッダ更新 |
| App（Node.js） | `forceUpdateTagApp` | `skipVmCreationApp` | 環境変数更新、Node.js バージョン更新 |
| DB（MongoDB） | `forceUpdateTagDb` | `skipVmCreationDb` | まれ（基本は一度きりのセットアップ） |

> **Important:** VM が既に存在する場合、該当 tier の `skipVmCreation*=true` を必ず指定してください。指定しないと、Azure は "Changing property 'linuxConfiguration.ssh.publicKeys' is not allowed" エラーで失敗します。

### 0.2 ポストデプロイ スクリプトの準備

ポストデプロイ スクリプトは、設定と実行を分離する **テンプレート パターン** を使います。

| ファイル | 用途 | Git にコミット |
|------|---------|---------------|
| `post-deployment-setup.template.sh` | macOS/Linux 用テンプレート | ✅ Yes |
| `post-deployment-setup.template.ps1` | Windows 用テンプレート | ✅ Yes |
| `post-deployment-setup.local.sh` | 値を入れたローカル用コピー | ❌ No（gitignored） |
| `post-deployment-setup.local.ps1` | 値を入れたローカル用コピー | ❌ No（gitignored） |

**初回セットアップ:**
```bash
# macOS/Linux
cp scripts/post-deployment-setup.template.sh scripts/post-deployment-setup.local.sh
chmod +x scripts/post-deployment-setup.local.sh
# Edit and replace placeholders with your values

# Windows PowerShell
Copy-Item scripts\post-deployment-setup.template.ps1 scripts\post-deployment-setup.local.ps1
# Edit and replace placeholders with your values
```

### 0.3 ポストデプロイ セットアップ スクリプトの実行

**macOS/Linux:**
```bash
./scripts/post-deployment-setup.local.sh
```

**Windows PowerShell:**
```powershell
.\scripts\post-deployment-setup.local.ps1
```

**スクリプトが実施する内容:**
1. ✅ すべての VM が起動していることを確認
2. ✅ CustomScript 拡張機能の完了を待機
3. ✅ MongoDB レプリカセット（`blogapp-rs0`）を初期化
4. ✅ 管理ユーザー（`blogadmin`）を作成
5. ✅ アプリケーション ユーザー（`blogapp`）を作成
6. ✅ App tier の環境変数を検証
7. ✅ Web tier の `config.json` を検証

### 0.4 設定注入の検証（スクリプトで実施済みだが、手動確認用）

#### Azure Bastion 経由で VM に接続（ネイティブ SSH クライアント）

Azure CLI を使用して、ネイティブ SSH クライアントで Bastion 経由で VM に接続します。

**macOS/Linux (Azure CLI):**

**App tier VM に接続:**
```bash
# Connect to vm-app-az1-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-app-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# Connect to vm-app-az2-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-app-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

**Web tier VM に接続:**
```bash
# Connect to vm-web-az1-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa

# Connect to vm-web-az2-prod
az network bastion ssh \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id $(az vm show -g <YOUR_RESOURCE_GROUP> -n vm-web-az2-prod --query id -o tsv) \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

> **Note:** `~/.ssh/id_rsa` は、デプロイ時に使用した公開鍵に対応する秘密鍵のパスに置き換えてください。

**Windows PowerShell (Azure PowerShell) - Invoke-AzVMRunCommand を使用:**

> **Note:** Windows ユーザーは `Invoke-AzVMRunCommand` を使用して Bastion SSH なしで VM 上のコマンドを実行できます。これは PowerShell ユーザーにおすすめのアプローチです。

```powershell
$ResourceGroup = "<YOUR_RESOURCE_GROUP>"

# Run command on App tier VM (vm-app-az1-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /etc/environment | grep -E '(AZURE_|NODE_ENV|PORT)'; cat /opt/blogapp/.env"

# Run command on App tier VM (vm-app-az2-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /etc/environment | grep -E '(AZURE_|NODE_ENV|PORT)'; cat /opt/blogapp/.env"

# Run command on Web tier VM (vm-web-az1-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /var/www/html/config.json"

# Run command on Web tier VM (vm-web-az2-prod)
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString "cat /var/www/html/config.json"
```

#### VM 上で設定を検証

**App tier VM 上:**
```bash
# Check environment variables
cat /etc/environment | grep -E "(AZURE_|NODE_ENV|PORT)"
cat /opt/blogapp/.env
```

期待される出力:
```
NODE_ENV=production
PORT=3000
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Web tier VM 上:**
```bash
# Check config.json
cat /var/www/html/config.json
```

期待される出力:
```json
{
  "VITE_ENTRA_CLIENT_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "VITE_ENTRA_TENANT_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "VITE_API_BASE_URL": ""
}
```

---

## Phase 1: Database tier 設定（自動化）

> **Note:** この Phase は `post-deployment-setup.local.sh` / `post-deployment-setup.local.ps1` により完全に自動化されています。以下のセクションは参照および手動トラブルシュート用に残しています。

### 1.1 事前インストール済み MongoDB の確認

**両方の DB VM で確認のみ（インストール不要）:**

```bash
# Check MongoDB is running
sudo systemctl status mongod

# Check MongoDB version
mongod --version

# Check data disk mount
df -h /data/mongodb

# Check MongoDB logs
sudo tail -20 /data/mongodb/log/mongod.log
```

### 1.2 レプリカセット状態の確認（初期化前）

**`vm-db-az1-prod` 上で、レプリカセットが既に初期化されているか確認:**

```bash
# Check replica set status
mongosh --eval 'rs.status()' 2>&1
```

**想定される出力とアクション:**

| 出力 | 意味 | アクション |
|--------|---------|--------|
| `"ok" : 1` と members リスト | 既に初期化済み | 1.3（ユーザー作成）へスキップ |
| `MongoServerError: no replset config` | 未初期化 | 1.2.1 を実行 |
| `NotYetInitialized` | 未初期化 | 1.2.1 を実行 |

### 1.2.1 レプリカセット初期化（未初期化の場合のみ）

**`rs.status()` が "no replset config" または "NotYetInitialized" の場合のみ実行:**

```bash
# Initialize replica set (ONE TIME ONLY)
mongosh --eval '
rs.initiate({
  _id: "blogapp-rs0",
  members: [
    { _id: 0, host: "10.0.3.4:27017", priority: 2 },
    { _id: 1, host: "10.0.3.5:27017", priority: 1 }
  ]
})
'

# Wait for replica set to elect primary (about 10-20 seconds)
sleep 20

# Verify replica set status
mongosh --eval 'rs.status()'
```

### 1.3 アプリケーション ユーザーの確認/作成（自動化）

> **Note:** ユーザー作成は `post-deployment-setup.local.sh` / `post-deployment-setup.local.ps1` により自動化されています。

**必要に応じた手動確認:**

```bash
# Check if blogapp user exists
mongosh admin --eval 'db.getUsers()' 2>&1 | grep -q "blogapp"
echo $?  # 0 = exists, 1 = not exists
```

**存在しない場合のみ作成:**

```javascript
// Connect to primary
mongosh

// Switch to admin database
use admin

// Check existing users
db.getUsers()

// Create user ONLY if not in the list above
db.createUser({
  user: "blogapp",
  pwd: "BlogApp2024Workshop",  // Change for production
  roles: [
    { role: "readWrite", db: "blogapp" }
  ]
})
```

### 1.4 検証

```bash
# Test connection with credentials
mongosh "mongodb://blogapp:BlogApp2024Workshop!@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=admin" --eval 'db.runCommand({ping:1})'
```

---

## Phase 2: Backend tier デプロイ

> **Important:** 環境変数は Bicep によって自動注入されます。必要なのはアプリケーション コードのデプロイのみです。

### 2.1 事前インストール済み Node.js/PM2 と環境の確認

**両方の App VM 上で確認のみ:**

```bash
# Check Node.js version (should be v20.x)
node --version

# Check PM2
pm2 --version
pm2 list

# Check application directory
ls -la /opt/blogapp/

# Verify environment variables (NEW - injected by Bicep)
cat /opt/blogapp/.env
# Should show: NODE_ENV, PORT, AZURE_TENANT_ID, AZURE_CLIENT_ID
```

### 2.2 プレースホルダ ヘルスサーバのクリーンアップ

Bicep の CustomScript はプレースホルダのヘルスサーバを開始します。実際のアプリケーションをデプロイした後、このプロセスは "errored"（ポート競合）になります。クリーンアップしてください。

```bash
# Check PM2 status - you may see blogapp-health in "errored" state
pm2 list

# Delete the placeholder health server (safe to run even if not present)
pm2 delete blogapp-health 2>/dev/null || true

# Save PM2 process list
pm2 save
```

### 2.3 アプリケーション コードのデプロイ

**Option A: Git から clone（簡単、リポジトリにアクセス可能な場合）:**

```bash
cd /opt/blogapp
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp
cp -r temp/materials/backend/* ./
rm -rf temp
```

**Option B: Bastion トンネル経由でアップロード:**

**macOS/Linux (Azure CLI):**
```bash
# On local machine - create tunnel
az network bastion tunnel \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id <VM_RESOURCE_ID> \
  --resource-port 22 \
  --port 2222

# In another terminal - SCP through tunnel
scp -P 2222 -r ./materials/backend/* azureuser@127.0.0.1:/opt/blogapp/
```

**Windows PowerShell (Azure PowerShell) - Invoke-AzVMRunCommand を使用:**
```powershell
$ResourceGroup = "<YOUR_RESOURCE_GROUP>"

# Bastion トンネルは純粋な PowerShell では利用できないため、Invoke-AzVMRunCommand を使用して
# VM から直接 clone とデプロイを行います（Option A のアプローチ）

# Backend を vm-app-az1-prod にデプロイ
$deployScript = @'
cd /opt/blogapp
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp
cp -r temp/materials/backend/* ./
rm -rf temp
npm ci --include=dev
npm run build
pm2 delete blogapp-health 2>/dev/null || true
pm2 start dist/src/app.js --name blogapp-api
pm2 save
'@

Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript

# vm-app-az2-prod にも同様に実行
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-app-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript
```

### 2.4 依存関係のインストールとビルド

**両方の App VM 上:**

```bash
cd /opt/blogapp

# Install all dependencies including devDependencies (TypeScript compiler)
# Note: --include=dev is required because NODE_ENV=production is set in /etc/environment,
# which causes npm to skip devDependencies by default
npm ci --include=dev

# Build TypeScript
npm run build
```

> **なぜ `--include=dev` が必要？** Bicep の CustomScript は `/etc/environment` に `NODE_ENV=production` を設定します。`NODE_ENV=production` のとき、npm はインストール時に `devDependencies` を自動的にスキップします。TypeScript はコンパイルに必要な devDependency のため、明示的に含める必要があります。

### 2.5 MongoDB 接続文字列の確認

> **Note:** MongoDB の接続文字列は Bicep によって自動注入されます。このステップは確認用です。

**`/opt/blogapp/.env` に MONGODB_URI が含まれていることを確認:**

```bash
# Verify complete .env file
cat /opt/blogapp/.env
```

期待される `.env`（すべての値は Bicep により注入）:
```env
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
MONGODB_URI=mongodb://blogapp:BlogApp2024Workshop!@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=admin
ENTRA_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENTRA_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

> **MONGODB_URI が無い/不正な場合:** `main.local.bicepparam` の `mongoDbUri` パラメータが設定されているか確認して再デプロイするか、手動で追記します:
> ```bash
> echo 'MONGODB_URI=mongodb://blogapp:BlogApp2024Workshop@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&authSource=admin' | sudo tee -a /opt/blogapp/.env
> ```

### 2.6 PM2 でアプリケーションを起動

```bash
cd /opt/blogapp

# Start application
# Note: Output is in dist/src/ because tsconfig.json has rootDir="." and includes both src/ and scripts/
pm2 start dist/src/app.js --name blogapp-api

# Save PM2 process list
pm2 save

# Verify running
pm2 list
pm2 logs blogapp-api --lines 20
```

### 2.7 ヘルスチェック検証

```bash
# Test local health endpoint
curl http://localhost:3000/health

# Test from other VM (via Internal LB IP)
curl http://10.0.2.10:3000/health
```

---

## Phase 3: Frontend tier デプロイ

> **Important:** フロントエンドは実行時に `/config.json` を利用するようになりました（Bicep により既に作成済み）。ビルド時の環境変数は不要です。

### 3.1 事前インストール済み NGINX と設定の確認

**両方の Web VM 上で確認のみ:**

```bash
# Check NGINX is running
sudo systemctl status nginx
nginx -v

# Check current configuration
sudo nginx -T

# Test current health endpoint
curl http://localhost/health

# Verify config.json exists (NEW - created by Bicep)
cat /var/www/html/config.json
# Should show: VITE_ENTRA_CLIENT_ID, VITE_ENTRA_TENANT_ID, VITE_API_BASE_URL
```

### 3.2 静的ファイルのデプロイ

**Option A: Git から clone して VM でビルド（推奨。NAT Gateway によりアウトバウンドが可能）:**

```bash
cd /tmp

# Clone repository (NAT Gateway provides outbound internet access)
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp

# Install Node.js for build (if not already installed on Web tier)
# Note: Web tier VMs have NGINX but not Node.js by default
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Build frontend
cd temp/materials/frontend
npm ci
npm run build

# Deploy to web root (preserve existing config.json!)
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/

# Cleanup
cd /tmp && rm -rf temp
```

**Option B: ローカルでビルドして Bastion トンネル経由でアップロード:**

> **まず、ローカルマシンでビルド:**
> ```bash
> cd materials/frontend
> npm ci
> npm run build
> # ビルド出力は dist/ に作成されます
> ```

**macOS/Linux (Azure CLI):**
```bash
# Create tunnel to vm-web-az1-prod
az network bastion tunnel \
  --name bastion-blogapp-prod \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --target-resource-id /subscriptions/.../vm-web-az1-prod \
  --resource-port 22 \
  --port 2222

# Upload files (IMPORTANT: preserve existing config.json!)
scp -P 2222 -r ./materials/frontend/dist/* azureuser@127.0.0.1:/tmp/frontend/

# On VM - move to web root but preserve config.json
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r /tmp/frontend/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/
```

**Windows PowerShell (Azure PowerShell) - Invoke-AzVMRunCommand を使用:**
```powershell
$ResourceGroup = "<YOUR_RESOURCE_GROUP>"

# VM から直接 clone、ビルド、デプロイ（NAT Gateway を利用）
$deployScript = @'
cd /tmp
git clone https://github.com/<repo>/Azure-IaaS-Workshop.git temp

# Install Node.js for build (if not already installed on Web tier)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Build frontend
cd temp/materials/frontend
npm ci
npm run build

# Deploy to web root (preserve existing config.json!)
sudo cp /var/www/html/config.json /tmp/config.json.bak
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/
sudo cp /tmp/config.json.bak /var/www/html/config.json
sudo chown -R www-data:www-data /var/www/html/

# Cleanup
cd /tmp && rm -rf temp
'@

# vm-web-az1-prod にデプロイ
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az1-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript

# vm-web-az2-prod にデプロイ
Invoke-AzVMRunCommand `
  -ResourceGroupName $ResourceGroup `
  -VMName "vm-web-az2-prod" `
  -CommandId "RunShellScript" `
  -ScriptString $deployScript
```

### 3.4 NGINX 設定の検証（自動化）

> **Note:** NGINX は Bicep により **完全に設定済み**です:
> - Internal Load Balancer へのプロキシ（`10.0.2.10:3000`）
> - セキュリティヘッダ（X-Frame-Options、X-Content-Type-Options など）
> - Gzip 圧縮
> - 静的アセットのキャッシュ
> - SPA ルーティング
>
> **手動設定は不要です。**

**設定の確認:**

```bash
# Check that API proxy is using Internal Load Balancer
grep "proxy_pass" /etc/nginx/sites-available/default
# Expected: proxy_pass http://10.0.2.10:3000;

# Test NGINX configuration syntax
sudo nginx -t

# Reload if needed (only if you made changes)
sudo systemctl reload nginx
```

<details>
<summary>📋 NGINX の完全設定（参考）</summary>

Bicep により自動作成されます。基本的に変更は不要です。

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml;

    # Health check endpoint for Load Balancer
    location /health {
        access_log off;
        return 200 'healthy\n';
        add_header Content-Type text/plain;
    }

    # Serve static files (React frontend) with SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to Internal Load Balancer (10.0.2.10)
    location /api/ {
        proxy_pass http://10.0.2.10:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

</details>

### 3.4 検証

```bash
# Test NGINX health endpoint (returns "healthy" from NGINX itself)
curl http://localhost/health

# Test API proxy to backend (use /api/posts, not /api/health)
# Note: Backend health is at /health, not /api/health
# NGINX proxies /api/* to backend /api/* - backend doesn't have /api/health route
curl http://localhost/api/posts
# Expected: JSON array of posts (may be empty)

# Test that SPA routing works (should return index.html for any frontend route)
curl -s http://localhost/login | head -5
# Expected: <!doctype html>...
```

---

## Phase 4: エンドツーエンド検証

> **Note:** Application Gateway は Bicep により **完全に自動化**されており、手動設定は不要です。以下を提供します:
> - 自己署名証明書での SSL/TLS 終端
> - HTTP→HTTPS リダイレクト（port 80 → port 443）
> - Web tier VM へのヘルスプローブ
> - 予測可能な FQDN のための Azure DNS ラベル

### 4.1 ヘルスチェック マトリクス

| エンドポイント | 期待値 | コマンド |
|----------|----------|---------|
| DB Primary | RS Primary | `mongosh 10.0.3.4 --eval 'rs.isMaster().ismaster'` |
| DB Secondary | RS Secondary | `mongosh 10.0.3.5 --eval 'rs.isMaster().secondary'` |
| Backend VM1 | `{"status":"healthy"}` | `curl http://10.0.2.5:3000/health` |
| Backend VM2 | `{"status":"healthy"}` | `curl http://10.0.2.4:3000/health` |
| Internal LB | `{"status":"healthy"}` | `curl http://10.0.2.10:3000/health` |
| Frontend VM1（NGINX） | `healthy` | `curl http://10.0.1.4/health` |
| Frontend VM2（NGINX） | `healthy` | `curl http://10.0.1.5/health` |
| Application Gateway（HTML） | HTML page | `curl -k https://<YOUR_APPGW_FQDN>/` |
| Application Gateway（API） | JSON array | `curl -k https://<YOUR_APPGW_FQDN>/api/posts` |

> **Note:** バックエンドのヘルスエンドポイントは `/health`（`/api/health` ではない）です。NGINX のプロキシは `/api/*` をバックエンドの `/api/*` にマップするため、`/api/health` は存在しないバックエンド ルートに到達してしまいます。エンドツーエンドの API 接続確認には `/api/posts` を使用してください。

### 4.2 Application Gateway の検証

**Application Gateway の FQDN を取得:**

**macOS/Linux:**
```bash
# Get the FQDN
az network public-ip show \
  --resource-group <YOUR_RESOURCE_GROUP> \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv
```

**Windows PowerShell:**
```powershell
# Get the FQDN
$pip = Get-AzPublicIpAddress -ResourceGroupName <YOUR_RESOURCE_GROUP> -Name pip-agw-blogapp-prod
$pip.DnsSettings.Fqdn
```

**HTTPS アクセスのテスト（自己署名証明書）:**

**macOS/Linux:**
```bash
# Test via FQDN (use -k to skip certificate verification for self-signed cert)
curl -k https://<YOUR_APPGW_FQDN>/

# Test HTTP→HTTPS redirect (should return 301/302)
curl -I http://<YOUR_APPGW_FQDN>/

# Test API endpoint through Application Gateway
# Note: Use /api/posts (not /api/health) - backend health is at /health, not /api/health
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

**Windows PowerShell:**
```powershell
# Test via FQDN (skip certificate verification for self-signed cert)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Test HTTPS access
Invoke-RestMethod -Uri "https://<YOUR_APPGW_FQDN>/" -SkipCertificateCheck

# Test API endpoint through Application Gateway
Invoke-RestMethod -Uri "https://<YOUR_APPGW_FQDN>/api/posts" -SkipCertificateCheck

# Test HTTP→HTTPS redirect
Invoke-WebRequest -Uri "http://<YOUR_APPGW_FQDN>/" -MaximumRedirection 0 -ErrorAction SilentlyContinue
```

**ブラウザでアクセス:**
1. ブラウザで `https://<YOUR_APPGW_FQDN>/` を開きます
2. 自己署名証明書の警告を受け入れます（ワークショップ用途では想定どおり）
3. ブログアプリケーションのログインページが表示されます

### 4.3 アプリケーション テスト

```bash
# Test full stack via Application Gateway FQDN
curl -k https://<YOUR_APPGW_FQDN>/api/posts
```

---

## デプロイ チェックリスト（改訂版）

### デプロイ前設定
- [ ] `main.local.bicepparam` を作成し値を設定
- [ ] `sshPublicKey` パラメータを設定
- [ ] `adminObjectId` パラメータを設定
- [ ] `entraTenantId` パラメータを設定
- [ ] `entraClientId`（backend）パラメータを設定
- [ ] `entraFrontendClientId` パラメータを設定

### インフラ デプロイ（Phase 0）
- [ ] リソース グループを作成
- [ ] Bicep デプロイが完了
- [ ] **Entra ID のリダイレクト URI を設定**（デプロイにより Public IP が必要）
- [ ] ポストデプロイ スクリプトのテンプレートを `.local` へコピー
- [ ] ポストデプロイ スクリプトに値を設定
- [ ] ポストデプロイ スクリプトが正常終了
- [ ] MongoDB レプリカセット初期化（自動）
- [ ] MongoDB ユーザー作成（自動）
- [ ] App tier の環境変数検証（自動）
- [ ] Web tier の config.json 検証（自動）

### Backend tier（コード デプロイのみ）
- [ ] ~~Node.js installed~~（Bicep）
- [ ] ~~PM2 installed~~（Bicep）
- [ ] ~~Environment variables configured~~（Bicep - MongoDB URI 以外）
- [ ] プレースホルダ ヘルスサーバを停止
- [ ] アプリケーション コードをデプロイ
- [ ] 依存関係をインストール（`npm ci`）
- [ ] TypeScript をビルド（`npm run build`）
- [ ] MongoDB 接続文字列を .env に追加
- [ ] PM2 プロセスが稼働
- [ ] ヘルスチェックが通る

### Frontend tier（静的ファイルのみ）
- [ ] ~~NGINX installed~~（Bicep）
- [ ] ~~config.json created~~（Bicep）
- [ ] フロントエンドをローカルでビルド（env 不要）
- [ ] 静的ファイルをアップロード（config.json を保持）
- [ ] NGINX 設定を検証
- [ ] ヘルスチェックが通る
- [ ] API プロキシが動作

---

## 推定デプロイ時間（改訂版）

| フェーズ | 所要時間 | 備考 |
|-------|----------|-------|
| Bicep デプロイ | 15-30 分 | インフラ一式のプロビジョニング |
| ポストデプロイ スクリプト | 2-5 分 | MongoDB セットアップ自動化 |
| Backend デプロイ | 5-10 分 | コード転送 + ビルド + 起動（環境変数は事前設定） |
| Frontend デプロイ | 5-10 分 | ビルド + アップロードのみ（環境設定不要） |
| 検証 | 5-10 分 | 全 tier |
| **合計** | **30-65 分** | 主にインフラのプロビジョニング時間 |

---

## この戦略の主要な改善点

| 従来アプローチ | 現在アプローチ |
|-------------------|------------------|
| Entra ID を含む `.env` を手動作成 | Bicep が環境変数を自動注入 |
| `.env.production` を使ってフロントエンドをビルド | フロントエンドは実行時に `/config.json` を取得 |
| MongoDB レプリカセット初期化を手動実行 | ポストデプロイ スクリプトで自動化 |
| MongoDB ユーザー作成を手動実行 | ポストデプロイ スクリプトで自動化 |
| 学習者が複数の設定ファイルを編集 | 学習者は `main.bicepparam` のみ編集 |
| 単一プラットフォームのスクリプト | クロスプラットフォーム（Bash + PowerShell） |
| スクリプト内に値をハードコード | `.local` コピーを使うテンプレート パターン（gitignored） |

### 技術的な実装詳細

**Bicep スクリプト注入パターン:**
- 外部シェルスクリプトを `modules/compute/scripts/` に保存
- `loadTextContent()` がデプロイ時にスクリプトを読み込み
- `replace()` をチェーンして `__PLACEHOLDER__` を Bicep パラメータで置換
- bash/JSON の波括弧による ARM `format()` 問題を回避

**ポストデプロイ スクリプトのテンプレート パターン:**
- テンプレート（`*.template.sh`, `*.template.ps1`）はリポジトリにコミット
- ローカルコピー（`*.local.sh`, `*.local.ps1`）は利用者が値を入れて作成
- `.gitignore` で `*.local.sh` と `*.local.ps1` を除外し、資格情報を保護

### ワークショップにおける利点

1. **単一の設定ポイント**: Azure 固有の値は `main.bicepparam` に集約
2. **リビルド不要**: Entra ID の変更は Bicep 再デプロイで反映（アプリの再ビルド不要）
3. **DB セットアップ自動化**: 1 つのスクリプトで MongoDB 設定一式を実行
4. **検証の組み込み**: ポストデプロイ スクリプトが設定注入を検証
5. **クロスプラットフォーム対応**: Windows / macOS/Linux いずれでもネイティブ スクリプトで実行

---

## 自動化スクリプト参照

| スクリプト | 用途 | 使い方 |
|--------|---------|-------|
| `scripts/post-deployment-setup.template.sh` | MongoDB セットアップ + 検証のテンプレート（macOS/Linux） | `.local.sh` にコピーしてプレースホルダを編集 |
| `scripts/post-deployment-setup.template.ps1` | MongoDB セットアップ + 検証のテンプレート（Windows） | `.local.ps1` にコピーしてプレースホルダを編集 |
| `scripts/post-deployment-setup.local.sh` | 設定済みスクリプト（macOS/Linux） | `./scripts/post-deployment-setup.local.sh` |
| `scripts/post-deployment-setup.local.ps1` | 設定済みスクリプト（Windows） | `.\scripts\post-deployment-setup.local.ps1` |

### スクリプト設定用プレースホルダ

| プレースホルダ | 説明 | 例 |
|-------------|-------------|---------------|
| `<RESOURCE_GROUP>` | Azure リソース グループ名 | `rg-blogapp-prod` |
| `<BASTION_NAME>` | Bastion ホスト名 | `bastion-blogapp-prod` |
| `<MONGODB_ADMIN_PASSWORD>` | 管理ユーザーのパスワード | `AdminP@ss2024!` |
| `<MONGODB_APP_PASSWORD>` | アプリ ユーザーのパスワード | `BlogApp2024Workshop!` |

---

## トラブルシューティング

### 設定注入の問題

**App tier の環境変数が設定されない:**
```bash
# Re-run CustomScript extension
az vm run-command invoke --resource-group <YOUR_RESOURCE_GROUP> \
  --name vm-app-az1-prod --command-id RunShellScript \
  --scripts "cat /opt/blogapp/.env"
```

**Web tier の config.json が無い:**
```bash
# Check if file exists
az vm run-command invoke --resource-group <YOUR_RESOURCE_GROUP> \
  --name vm-web-az1-prod --command-id RunShellScript \
  --scripts "cat /var/www/html/config.json"
```

### MongoDB の問題

**レプリカセットが初期化されていない:**
```bash
# macOS/Linux - Run post-deployment script again
./scripts/post-deployment-setup.local.sh

# Windows
.\scripts\post-deployment-setup.local.ps1
```

**ユーザーが作成されない:**
```bash
# Script will skip if already exists, safe to re-run
./scripts/post-deployment-setup.local.sh  # macOS/Linux
.\scripts\post-deployment-setup.local.ps1  # Windows
```

### Bicep テンプレートの波括弧問題

CustomScript 拡張機能を変更した際、ARM エラー（例: "Input string was not in a correct format"）が出る場合:

**問題:** ARM の `format()` 関数は、数字が続かない `{` を無効なプレースホルダとして扱います。

**解決策:** `loadTextContent()` と `replace()` を使って外部スクリプトを適用します:
```bicep
// Instead of format() with embedded scripts:
var scriptContent = loadTextContent('scripts/my-script.sh')
var finalScript = replace(
  replace(scriptContent, '__PLACEHOLDER1__', param1),
  '__PLACEHOLDER2__', param2
)
```

例として `modules/compute/scripts/nginx-install.sh` と `nodejs-install.sh` を参照してください。

---

## アーキテクチャ参照

以下も参照してください:
- [AzureArchitectureDesign.md](../../design/AzureArchitectureDesign.md) - インフラ設計とパラメータ フロー
- [FrontendApplicationDesign.md](../../design/FrontendApplicationDesign.md) - 実行時設定パターンの詳細
- [BackendApplicationDesign.md](../../design/BackendApplicationDesign.md) - バックエンドの環境設定

---

## 付録: デプロイ検証コマンド

### インフラ デプロイ

```
Resource Group: <YOUR_RESOURCE_GROUP>
Location: <YOUR_REGION>
Deployment Status: (check after deployment)
```

### 設定注入の検証（az vm run-command）

**App tier VM - `/opt/blogapp/.env`:**

| VM | NODE_ENV | PORT | AZURE_TENANT_ID | AZURE_CLIENT_ID |
|----|----------|------|-----------------|-----------------|
| vm-app-az1-prod | production | 3000 | ✅ Injected | ✅ Injected |
| vm-app-az2-prod | production | 3000 | ✅ Injected | ✅ Injected |

**Web tier VM - `/var/www/html/config.json`:**

| VM | VITE_ENTRA_CLIENT_ID | VITE_ENTRA_TENANT_ID | VITE_API_BASE_URL |
|----|----------------------|----------------------|-------------------|
| vm-web-az1-prod | ✅ Injected | ✅ Injected | "" (relative) |
| vm-web-az2-prod | ✅ Injected | ✅ Injected | "" (relative) |

### 検証コマンド

```bash
# App tier verification
az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-app-az1-prod \
  --command-id RunShellScript --scripts "cat /opt/blogapp/.env"

az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-app-az2-prod \
  --command-id RunShellScript --scripts "cat /opt/blogapp/.env"

# Web tier verification
az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-web-az1-prod \
  --command-id RunShellScript --scripts "cat /var/www/html/config.json"

az vm run-command invoke -g <YOUR_RESOURCE_GROUP> -n vm-web-az2-prod \
  --command-id RunShellScript --scripts "cat /var/www/html/config.json"
```

### 残作業

1. **ポストデプロイ スクリプトを実行**して MongoDB レプリカセットを初期化
2. App tier VM に **バックエンド アプリケーション コードをデプロイ**
3. Web tier VM に **フロントエンド静的ファイルをデプロイ**
