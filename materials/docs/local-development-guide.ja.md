# ローカル開発ガイド

このガイドでは、開発およびテスト用にローカルマシンでブログアプリケーションをセットアップして実行する方法を説明します。

---

## 目次

- [1. アーキテクチャ概要](#1-アーキテクチャ概要)
- [2. 前提条件](#2-前提条件)
  - [2.1 必要なツール](#21-必要なツール)
  - [2.2 Microsoft Entra ID アプリ登録](#22-microsoft-entra-id-アプリ登録)
- [3. セットアップ手順](#3-セットアップ手順)
  - [ステップ1: リポジトリのクローン](#ステップ1-リポジトリのクローン)
  - [ステップ2: MongoDBの起動](#ステップ2-mongodbの起動)
  - [ステップ3: バックエンドの構成と起動](#ステップ3-バックエンドの構成と起動)
  - [ステップ4: フロントエンドの構成と起動](#ステップ4-フロントエンドの構成と起動)
  - [ステップ5: アプリケーションのテスト](#ステップ5-アプリケーションのテスト)
- [4. クイックコマンドリファレンス](#4-クイックコマンドリファレンス)
- [5. トラブルシューティング](#5-トラブルシューティング)

---

## 1. アーキテクチャ概要

ローカル開発環境では、すべてのコンポーネントをマシン上で実行します：

```
┌─────────────────────────────────────────────────────────────────┐
│                    ローカル開発環境                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ブラウザ ──► フロントエンド (Vite :5173) ──► バックエンド (Express :3000)  │
│                     │                          │                 │
│                     │                          │                 │
│                     ▼                          ▼                 │
│             Microsoft Entra ID         MongoDB (Docker :27017)   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

| コンポーネント | 技術 | ポート |
|-----------|------------|------|
| フロントエンド | React 18 + Vite | 5173 |
| バックエンド | Express.js + TypeScript | 3000 |
| データベース | MongoDB 7.0 (Docker) | 27017 |
| 認証 | Microsoft Entra ID | N/A（クラウドサービス） |

---

## 2. 前提条件

### 2.1 必要なツール

コンピュータに以下のツールをインストールしてください：

| ツール | バージョン | 目的 | インストール |
|------|---------|---------|--------------|
| **Node.js** | 20.x LTS | JavaScriptランタイム | [ダウンロード](https://nodejs.org/) |
| **npm** | 10.x以上 | パッケージマネージャー | Node.jsに含まれる |
| **Git** | 2.x以上 | バージョン管理 | [ダウンロード](https://git-scm.com/) |
| **Docker Desktop** | 最新版 | ローカルMongoDB | [ダウンロード](https://www.docker.com/products/docker-desktop/) |
| **VS Code** | 最新版 | コードエディタ（推奨） | [ダウンロード](https://code.visualstudio.com/) |

**インストールの確認:**

```bash
# Node.jsの確認
node --version
# 期待値: v20.x.x

# npmの確認
npm --version
# 期待値: 10.x.x

# Gitの確認
git --version
# 期待値: git version 2.x.x

# Dockerの確認
docker --version
# 期待値: Docker version 24.x.x以降
```

### 2.2 Microsoft Entra ID アプリ登録

認証を機能させるために、Microsoft Entra ID で **2 つのアプリ登録** を作成する必要があります。

> **なぜ2つのアプリ登録が必要？**
> - **フロントエンドアプリ**: MSAL.js経由のユーザーログイン処理（ブラウザベース）
> - **バックエンドAPIアプリ**: JWTトークンの検証とAPIエンドポイントの保護

#### 必要な権限

> ⚠️ **重要: 開始前に権限を確認してください**
>
> Microsoft Entra IDでアプリ登録を作成するには、以下のいずれかが必要です：
>
> | ロール/設定 | 所有者 |
> |--------------|------------|
> | **アプリケーション開発者**ロール | IT管理者が割り当て |
> | **クラウドアプリケーション管理者**ロール | IT管理者が割り当て |
> | **グローバル管理者**ロール | テナント管理者 |
> | **「ユーザーはアプリケーションを登録できる」** = はい | デフォルトのテナント設定（無効化されている場合あり） |
>
> **権限があるか確認する方法:**
> 1. [Azure Portal](https://portal.azure.com) → Microsoft Entra ID → アプリの登録 に移動
> 2. 「+ 新規登録」をクリック
> 3. 登録フォームが表示されれば、権限があります ✅
> 4. エラーが表示されるかボタンが無効な場合は、IT管理者に連絡してください ❌
>
> **個人/無料Azureアカウントの場合:**
> 自分でAzureアカウントを作成した場合、自動的にグローバル管理者となり、追加設定なしでアプリ登録を作成できます。

#### フロントエンドアプリ登録の作成

<details>
<summary>📝 クリックして展開: ステップバイステップ手順</summary>

1. **Azure Portalを開く**
   - [portal.azure.com](https://portal.azure.com) にアクセス
   - Microsoftアカウントでサインイン

2. **Entra IDに移動**
   - 上部の検索バーで「Entra ID」と入力
   - 「Microsoft Entra ID」をクリック

3. **アプリ登録を作成**
   - 左メニューで「アプリの登録」をクリック
   - 「+ 新規登録」ボタンをクリック

4. **アプリを構成**
   - **名前**: `BlogApp Frontend (Dev)`（または任意の名前）
   - **サポートされているアカウントの種類**: 「この組織ディレクトリのみに含まれるアカウント」を選択
   - **リダイレクトURI**: 
     - ドロップダウンから**「シングルページアプリケーション (SPA)」**を選択
     - 入力: `http://localhost:5173`

   > ⚠️ **重要**: 必ず**「シングルページアプリケーション (SPA)」**を選択してください - 「Web」ではありません。
   > 「Web」を選択すると、認証がエラー`AADSTS9002326`で失敗します。

5. **「登録」をクリック**

6. **重要な値をコピー**（後で必要になります）
   - **アプリケーション (クライアント) ID**: これが `VITE_ENTRA_CLIENT_ID` です
   - **ディレクトリ (テナント) ID**: これが `VITE_ENTRA_TENANT_ID` です

   > 💡 このブラウザタブを開いたままにしておいてください - すぐにこれらの値が必要になります。

</details>

#### バックエンドAPIアプリ登録の作成

<details>
<summary>📝 クリックして展開: ステップバイステップ手順</summary>

1. **別のアプリ登録を作成**
   - 「アプリの登録」に戻る
   - 「+ 新規登録」をクリック

2. **アプリを構成**
   - **名前**: `BlogApp API (Dev)`
   - **サポートされているアカウントの種類**: 「この組織ディレクトリのみに含まれるアカウント」
   - **リダイレクトURI**: 空のままにする（APIはリダイレクトURIを必要としない）

3. **「登録」をクリック**

4. **アプリケーション (クライアント) IDをコピー**
   - これが `ENTRA_CLIENT_ID`（バックエンド用）です
   - `VITE_API_CLIENT_ID`（フロントエンド用）としても使用します

5. **APIスコープを公開**
   - 左メニューで「APIの公開」をクリック
   - 「スコープの追加」をクリック
   - アプリケーションID URIを求められたら、「保存して続行」をクリック（デフォルトを受け入れる）
   - スコープを構成:
     - **スコープ名**: `access_as_user`
     - **同意できるユーザー**: 管理者とユーザー
     - **管理者の同意の表示名**: `BlogApp APIへのアクセス`
     - **管理者の同意の説明**: `サインインしたユーザーに代わってアプリがBlogApp APIにアクセスすることを許可します`
   - 「スコープの追加」をクリック

</details>

#### フロントエンドにバックエンドAPI呼び出しの権限を付与

<details>
<summary>📝 クリックして展開: ステップバイステップ手順</summary>

1. **フロントエンドアプリ登録に移動**
   - アプリの登録 → `BlogApp Frontend (Dev)` に移動

2. **API権限を追加**
   - 左メニューで「APIのアクセス許可」をクリック
   - 「+ アクセス許可の追加」をクリック
   - 「自分のAPI」タブを選択
   - 「BlogApp API (Dev)」をクリック
   - `access_as_user` の横のチェックボックスをオン
   - 「アクセス許可の追加」をクリック

3. **（オプション）管理者の同意を付与**
   - 管理者の場合、「[組織名]に管理者の同意を与えます」をクリック
   - これにより、ユーザーが個別に同意する必要がなくなります

</details>

#### 必要な値のまとめ

| 値 | 取得場所 | 用途 |
|-------|---------------|----------|
| `VITE_ENTRA_CLIENT_ID` | フロントエンドアプリ → 概要 → アプリケーション (クライアント) ID | フロントエンドログイン |
| `VITE_ENTRA_TENANT_ID` | 任意のアプリ → 概要 → ディレクトリ (テナント) ID | フロントエンドとバックエンド両方 |
| `ENTRA_CLIENT_ID` | バックエンドAPIアプリ → 概要 → アプリケーション (クライアント) ID | バックエンドトークン検証 |
| `VITE_API_CLIENT_ID` | ENTRA_CLIENT_IDと同じ | フロントエンドAPI呼び出し |

---

## 3. セットアップ手順

以下の手順に従って、ローカルマシンでアプリケーションを実行します。

### ステップ1: リポジトリのクローン

```bash
# リポジトリをクローン
git clone https://github.com/YOUR_USERNAME/AzureIaaSWorkshop.git

# プロジェクトフォルダに移動
cd AzureIaaSWorkshop
```

### ステップ2: MongoDBの起動

アプリケーションはレプリカセット構成のMongoDBを使用します。簡単なセットアップのためにDocker Compose構成を提供しています。

```bash
# dev-environmentフォルダに移動
cd dev-environment

# MongoDBコンテナを起動
docker-compose up -d

# MongoDBの準備が整うまで待機（約5秒）
sleep 5

# レプリカセットを初期化（初回のみ）
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js
```

**MongoDBが実行されていることを確認:**

```bash
# コンテナのステータスを確認
docker-compose ps

# 期待される出力:
# NAME                   STATUS          PORTS
# blogapp-mongo-primary  running         0.0.0.0:27017->27017/tcp

# MongoDB接続をテスト
docker exec -it blogapp-mongo-primary mongosh --eval "db.adminCommand('ping')"
# 期待値: { ok: 1 }
```

> **💡 トラブルシューティング:** コンテナの起動に失敗した場合は、以下を試してください：
> ```bash
> docker-compose down -v  # 既存のボリュームを削除
> docker-compose up -d    # 新規起動
> ```

### ステップ3: バックエンドの構成と起動

```bash
# バックエンドフォルダに移動（プロジェクトルートから）
cd materials/backend

# サンプルから環境ファイルを作成
cp .env.example .env
```

**`.env`ファイルを編集**し、Entra IDの値を設定:

```bash
# materials/backend/.env

NODE_ENV=development
PORT=3000

# MongoDB（ローカルDocker）
MONGODB_URI=mongodb://localhost:27017/blogapp?replicaSet=blogapp-rs0

# Microsoft Entra ID - バックエンドAPIアプリ登録の値を使用
ENTRA_TENANT_ID=ここにテナントIDを貼り付け
ENTRA_CLIENT_ID=ここにバックエンドAPIクライアントIDを貼り付け

# ロギング
LOG_LEVEL=debug

# CORS（フロントエンドからAPIを呼び出せるようにする）
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

**バックエンドを起動:**

```bash
# 依存関係をインストール
npm install

# 開発サーバーを起動（ホットリロード付き）
npm run dev
```

**期待される出力:**
```
[INFO] Server running on port 3000
[INFO] MongoDB connected successfully
[INFO] Environment: development
```

**バックエンドが動作していることを確認:**

```bash
# 新しいターミナルで
curl http://localhost:3000/health

# 期待されるレスポンス:
# {"status":"healthy","timestamp":"...","environment":"development"}
```

> **このターミナルを開いたまま**にしてください - バックエンドは実行し続ける必要があります。

### ステップ4: フロントエンドの構成と起動

```bash
# 新しいターミナルを開き、フロントエンドフォルダに移動
cd materials/frontend

# サンプルから環境ファイルを作成
cp .env.example .env
```

**`.env`ファイルを編集**し、Entra IDの値を設定:

```bash
# materials/frontend/.env

# フロントエンドアプリ登録（MSALログイン用）
VITE_ENTRA_CLIENT_ID=ここにフロントエンドクライアントIDを貼り付け
VITE_ENTRA_TENANT_ID=ここにテナントIDを貼り付け
VITE_ENTRA_REDIRECT_URI=http://localhost:5173

# バックエンドAPIアプリ登録（APIトークンのオーディエンス用）
VITE_API_CLIENT_ID=ここにバックエンドAPIクライアントIDを貼り付け
```

**フロントエンドを起動:**

```bash
# 依存関係をインストール
npm install

# 開発サーバーを起動
npm run dev
```

**期待される出力:**
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

### ステップ5: アプリケーションのテスト

1. **ブラウザを開き**、以下にアクセス: **http://localhost:5173**

2. **ログインせずにテスト:**
   - 投稿リストのあるホームページが表示されるはずです（最初は空の場合があります）
   - これでフロントエンド → バックエンド → MongoDBの接続が動作していることを確認できます

3. **ログインをテスト:**
   - ヘッダーの**「ログイン」**ボタンをクリック
   - Microsoftアカウントでサインイン
   - プロンプトが表示されたら権限を承認
   - ログイン後、ヘッダーに名前が表示されます

4. **認証済み機能をテスト:**
   - **「投稿を作成」**をクリックして新しいブログ投稿を書く
   - 下書きとして保存または公開
   - **「マイ投稿」**で投稿を確認

**🎉 おめでとうございます！** ローカル開発環境の準備が整いました。

---

## 4. クイックコマンドリファレンス

```bash
# すべてを起動（別々のターミナルで実行）
cd dev-environment && docker-compose up -d      # ターミナル1: MongoDB
cd materials/backend && npm run dev              # ターミナル2: バックエンド
cd materials/frontend && npm run dev             # ターミナル3: フロントエンド

# すべてを停止
docker-compose stop                              # MongoDBを停止
# バックエンド/フロントエンドのターミナルでCtrl+Cを押す

# データベースをリセット（必要な場合）
cd dev-environment
docker-compose down -v
docker-compose up -d
sleep 5
docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js

# サンプルデータを追加（オプション）
cd materials/backend && npm run seed
```

---

## 5. トラブルシューティング

### MongoDBの問題

| 問題 | 解決策 |
|---------|----------|
| コンテナが起動しない | `docker-compose down -v` を実行してから `docker-compose up -d` |
| レプリカセットが初期化されない | 初期化スクリプトを再実行: `docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js` |
| ポート27017が使用中 | 他のMongoDBインスタンスを停止するか、`docker-compose.yml`でポートを変更 |

### バックエンドの問題

| 問題 | 解決策 |
|---------|----------|
| MongoDB接続失敗 | MongoDBコンテナが実行中でレプリカセットが初期化されていることを確認 |
| ポート3000が使用中 | `.env`で`PORT`を変更するか、競合するプロセスを停止 |
| 環境変数がない | `.env`ファイルが存在し、すべての必要な値が設定されていることを確認 |

### フロントエンドの問題

| 問題 | 解決策 |
|---------|----------|
| CORSエラー | バックエンドの`.env`で`CORS_ORIGINS`に`http://localhost:5173`が含まれていることを確認 |
| ログインがAADSTS9002326で失敗 | フロントエンドアプリ登録が「シングルページアプリケーション (SPA)」リダイレクトタイプを使用していることを確認 |
| API呼び出しが401を返す | `VITE_API_CLIENT_ID`がバックエンドの`ENTRA_CLIENT_ID`と一致していることを確認 |

### 認証の問題

| 問題 | 解決策 |
|---------|----------|
| アプリ登録を作成できない | 必要な権限があるか確認（前提条件セクションを参照） |
| トークン検証が失敗 | `ENTRA_TENANT_ID`と`ENTRA_CLIENT_ID`がアプリ登録と一致していることを確認 |
| スコープが見つからないエラー | バックエンドAPIアプリで`access_as_user`スコープを公開していることを確認 |

---

## 関連ドキュメント

- [README.ja.md](../../README.ja.md) - メインプロジェクトドキュメントとAzureデプロイガイド
- [dev-environment/README.md](../../dev-environment/README.md) - Docker環境の詳細
- [バックエンドアプリケーション設計](../../design/BackendApplicationDesign.md) - API仕様
- [フロントエンドアプリケーション設計](../../design/FrontendApplicationDesign.md) - UI/UX仕様
