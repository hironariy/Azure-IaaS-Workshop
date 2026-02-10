# アイデンティティ、アクセス、シークレットガイド（Entra ID + RBAC + Managed Identity）

このガイドでは、このワークショップにおける「アイデンティティとアクセス」の全体像を、次にフォーカスして説明します。
- Microsoft Entra ID（ユーザー認証）
- Azure RBAC（制御プレーンの認可）
- Managed Identity（Azure 内でのサービス間認証）
- このリポジトリで採用しているシークレット取り扱いパターン

AWS 経験者が理解しやすいように、Azure の概念を既存のメンタルモデルへマッピングして書いています。

## 1) 最重要のメンタルモデル: 2つの “プレーン（plane）”

Azure には混同されやすい「2つの認可の世界」があります。

### 1.1 制御プレーン（Azure Resource Manager / “ARM”）
- 「Azure リソースを作成／更新／参照してよいか？」
- **Azure RBAC のロール割り当て**（subscription / resource group / resource などのスコープ）で制御されます

AWS との類比:
- AWS API（CreateVpc, RunInstances など）を呼ぶための IAM 権限に概念的に近いです。

### 1.2 データプレーン（あなたのアプリ API）
- 「ブログ API を呼んでよいか？」
- アプリ側の **認証／認可**（OAuth トークン、JWT 検証、アプリロールなど）で制御されます

AWS との類比:
- Cognito が発行した JWT を API 側が検証する形に近いです。

このワークショップでは:
- Azure RBAC が Azure インフラ（portal、デプロイ、Key Vault など）へのアクセスを制御
- Entra ID のトークンが backend API エンドポイントへのアクセスを制御

## 2) このワークショップで登場する 3つのアイデンティティ

### 2.1 あなたの人間のアイデンティティ（受講者／講師）
用途:
- Portal アクセス
- デプロイ実行
- 自分の object ID の取得（Key Vault 管理者権限を付与するために使用）

Bicep パラメータファイルでは典型的に:
- `adminObjectId`

### 2.2 Entra ID のアプリ登録（frontend + backend）
このリポジトリは推奨されるエンタープライズパターンを採用しています。
- **Frontend SPA アプリ**: ブラウザが使う MSAL の client ID
- **Backend API アプリ**: API の audience（受信側）と scope 定義

Bicep パラメータファイルでは:
- `entraTenantId`
- `entraFrontendClientId`（SPA）
- `entraClientId`（API）

重要:
- **Client ID と tenant ID は識別子（identifier）であり、シークレットではありません**。
- ただし公開リポジトリに雑にコミットしない、という衛生面の配慮は推奨です（パスワード漏えいと同列ではない、という意味）。

### 2.3 VM の Managed Identity（system-assigned）
各 VM は **システム割り当ての Managed Identity** を持って作成されます。

用途:
- パスワード不要で Azure リソースへアクセス（例: Key Vault の secret read）

AWS との類比:
- EC2 の instance profile / インスタンスに紐づく IAM role に近いです。

どこに出るか:
- Bicep（`vm.bicep`）で `identity: { type: 'SystemAssigned' }`
- Key Vault モジュールで VM の identity に “Key Vault Secrets User” を割り当て

## 3) ユーザーログインの流れ（frontend）

### 3.1 設定ソース: dev と Azure（本番）の違い
frontend は **runtime configuration** をサポートする設計です。

- 開発モード:
  - Vite の環境変数（例: `.env.local`）を `import.meta.env.VITE_*` で参照
- 本番（Azure VM 上）:
  - 実行時に `/config.json` を fetch
  - このファイルは Web tier VM の bootstrap（NGINX Custom Script）で生成

関連ファイル:
- Frontend の runtime config loader: `materials/frontend/src/config/appConfig.ts`
- `/var/www/html/config.json` を書く NGINX スクリプト: `materials/bicep/modules/compute/scripts/nginx-install.sh`

なぜ重要か:
- React/Vite は通常 build 時に設定が焼き込まれます。
- ワークショップでは、学生ごとに Entra ID の値が違うため、frontend の再ビルドなしで差し替えられる必要があります。

### 3.2 MSAL の挙動
frontend は MSAL（Authorization Code Flow with PKCE）を使い、トークンは **sessionStorage**（localStorage ではない）に保存します。

設定箇所:
- `materials/frontend/src/config/authConfig.ts` が `cacheLocation: 'sessionStorage'` を指定

## 4) API 呼び出しの認可（frontend → backend）

### 4.1 API scope
frontend は backend API 用の scope に対してアクセストークンを要求します。

- Scope: `api://{BACKEND_CLIENT_ID}/access_as_user`

設定箇所:
- `materials/frontend/src/config/authConfig.ts`（`createApiRequest()` / `createLoginRequest()`）

### 4.2 トークン送信
backend を呼ぶとき、frontend は次を付与します。
- `Authorization: Bearer <access_token>`

実装箇所:
- `materials/frontend/src/services/api.ts`（Axios の request interceptor）

## 5) backend がトークンを検証する仕組み

backend は JWT を次の要素で検証します。
- テナントの **JWKS**（署名鍵）
- 標準的な JWT チェック: 署名、issuer、audience

実装箇所:
- `materials/backend/src/middleware/auth.middleware.ts`

（ワークショップで重要な）主な検証ルール:
- JWKS endpoint:
  - `https://login.microsoftonline.com/${ENTRA_TENANT_ID}/discovery/v2.0/keys`
- 有効な issuer:
  - `https://login.microsoftonline.com/${ENTRA_TENANT_ID}/v2.0`
  - `https://sts.windows.net/${ENTRA_TENANT_ID}/`（v1 issuer）
- Audience（API アプリ登録に一致させる必要）:
  - `api://${ENTRA_CLIENT_ID}`

audience チェックが重要な理由:
- SPA 向けの ID token（別 audience）を誤って受け入れることを防ぎます

## 6) Entra ID の値が VM に注入される流れ（デプロイ時）

このリポジトリは「学生ごとの設定」を Bicep パラメータファイルに集約する意図で設計されています。

### 6.1 App tier（backend）
app tier の bootstrap スクリプトは次へ書き込みます。
- `/etc/environment`
- `/opt/blogapp/.env`

含まれる値:
- `ENTRA_TENANT_ID`
- `ENTRA_CLIENT_ID`
- `MONGODB_URI`

定義箇所:
- スクリプトテンプレート: `materials/bicep/modules/compute/scripts/nodejs-install.sh`
- プレースホルダ置換: `materials/bicep/modules/compute/app-tier.bicep`

### 6.2 Web tier（frontend）
web tier の bootstrap スクリプトは次へ書き込みます。
- `/var/www/html/config.json`

含まれる値:
- `ENTRA_TENANT_ID`
- `ENTRA_FRONTEND_CLIENT_ID`
- `ENTRA_BACKEND_CLIENT_ID`

定義箇所:
- スクリプトテンプレート: `materials/bicep/modules/compute/scripts/nginx-install.sh`
- プレースホルダ置換: `materials/bicep/modules/compute/web-tier.bicep`

## 7) シークレット: このワークショップで「守るべき値」は何か

### 7.1 シークレット（必ず保護する）
- `mongoDbAppPassword`（MongoDB ユーザーのパスワード）
- `sslCertificateData` と `sslCertificatePassword`
- 将来的な client secret（もし confidential client flow を使う場合）

このリポジトリでの保護テクニック:
- Bicep の `@secure()` パラメータ
- ローカルのパラメータファイルを gitignore（リポジトリルートの `.gitignore` に `*.local.bicepparam`）
- backend/frontend の `.env` をコミットしない

### 7.2 シークレットではない（ただし丁寧に扱う）
- `entraTenantId`
- `entraClientId`, `entraFrontendClientId`

これらは識別子です。多くの状況で共有しても致命的ではありませんが、ワークショップでは「不用意にコミットしない」衛生面を推奨します。

## 8) Key Vault へのアクセス（RBAC + managed identity）

インフラは、RBAC 認可を有効化した Key Vault をデプロイします。
- `enableRbacAuthorization: true`

使うロール割り当て:
- 管理者ユーザー: “Key Vault Administrator”
- VM: “Key Vault Secrets User”

定義箇所:
- Key Vault モジュール: `materials/bicep/modules/security/key-vault.bicep`
- VM の `principalIds` を集めてロールを割り当てるため、モジュールは **VM の後** にデプロイされます

現在のリポジトリ状態に関する重要な注記:
- backend は現時点では `MONGODB_URI` を env var から直接読みます
- `materials/backend/src/config/environment.ts` に `KEY_VAULT_NAME`（任意）がある一方で、実行時の Key Vault secret 取得は未実装です

ワークショップのシンプルさを優先した意図的な設計です。Key Vault は教育用途や将来のハードニングには有用です。

## 9) よくある失敗パターン（だいたいの原因）

- backend が `401 Unauthorized`:
  - `Authorization: Bearer ...` ヘッダがない
  - トークン期限切れ
  - 間違った audience のトークン（SPA 用トークンなど）

- ログイン後も backend が `401 Invalid token`:
  - backend API の client ID が間違っている（audience mismatch）
  - tenant mismatch（設定した tenant と違う tenant が発行したトークン）

- frontend が consent を繰り返し求める / `AADSTS65001`:
  - SPA が `access_as_user` に同意できていない
  - 対策: ログイン時に API scope を要求する（このリポジトリはそうしています）

- VM identity から Key Vault が access denied:
  - ロール割り当てがない、または反映待ち
  - principal ID が変わっている（VM 作り直しで identity が変わる）

## 10) ログ衛生（シークレットを漏らさない）

このリポジトリにはログのサニタイズ（秘匿値のマスク）に関するルールとユーティリティがあります。重要なルールは次の 2つです。
- トークンはログに出さない
- パスワード付きの接続文字列はログに出さない

参照:
- リポジトリ共通ルール: `design/RepositoryWideDesignRules.md`（Secret Management & Log Sanitization）
- backend のサニタイザ: `materials/backend/src/utils/logger.ts`
