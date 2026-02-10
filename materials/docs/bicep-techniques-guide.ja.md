# このリポジトリで使っている Bicep テクニック

このガイドでは、このリポジトリのインフラテンプレートで実際に使っている **Bicep のパターン／テクニック** を説明します。

対象範囲:
- テンプレートは `materials/bicep/` 配下にあります
- エントリポイントは `materials/bicep/main.bicep` です
- このガイドは Azure サービスの一般論ではなく、*このリポジトリの Bicep がどう設計されているか* にフォーカスします（サービスの概念はワークショップ内で扱います）

## 0) Bicep ファイルのクイックマップ

- `materials/bicep/main.bicep`
  - 全体のオーケストレーション。パラメータ、機能フラグ、出力を定義します。
- `materials/bicep/main.bicepparam`
  - コミットされる「テンプレート」用パラメータファイル（学生が必要値を埋めます）。
- `materials/bicep/main.local.bicepparam`
  - 個人用パラメータファイル（gitignore 対象）。`main.bicepparam` をコピーして、tenant/client ID、SSH key など自分の値を入れます。
  - ルールはリポジトリルートの `.gitignore` にある `*.local.bicepparam` です。
- `materials/bicep/modules/**`
  - ドメインごとに整理された再利用モジュール: `network/`, `compute/`, `monitoring/`, `security/`, `storage/`。

## 1) パラメータ設計: 分かりやすい UX + 安全なデフォルト

### 1.1 `@description` と `@allowed` で学生の入力ミスを減らす
`materials/bicep/main.bicep` では多くのパラメータに対して、次を使っています。
- `@description()` で portal/CLI の入力プロンプトを理解しやすくする
- `@allowed([...])` で取り得る値を制限する（例: `environment` は `prod|dev|test`, `groupId` は `A-J`）

ワークショップ中の「うっかり設定ミス」を減らす狙いです。

### 1.2 `@secure()` で秘匿値を扱う
次のような値は `@secure()` として扱います。
- `sshPublicKey`（パスワードほどの秘匿性はないですが、慎重に扱う対象）
- `sslCertificateData`, `sslCertificatePassword`
- `mongoDbAppPassword`

意図は、**Git へのコミットやログへの混入を避ける**ことです。

### 1.3 機能フラグ（Feature flags）でコストと複雑さをコントロールする
`materials/bicep/main.bicep` では、コストが高い／任意のコンポーネントを on/off できるように boolean パラメータを用意しています。
- `deployBastion`
- `deployNatGateway`
- `deployMonitoring`
- `deployKeyVault`
- `deployStorage`

学生はワークショップ用に「フル構成」で実行し、開発時はインストラクタ側が「安い構成」へ切り替えることができます。

## 2) モジュール構成: ドメインモジュール + ティア（tier）モジュール

### 2.1 1つの “オーケストレータ” と小さなモジュール群
このリポジトリは一般的な本番パターンを採用しています。
- 受講者が基本的にデプロイするのは `main.bicep` だけ
- それ以外は `main.bicep` から呼び出されるモジュール

「コマンドはシンプル（1回のデプロイ）」を維持しつつ、IaC としての構造は良い形に保ちます。

### 2.2 再利用 VM モジュール + ティアのラッパー
コンピュートは次のように分割されています。
- `materials/bicep/modules/compute/vm.bicep`（「1台の VM」を作る再利用モジュール）
- `web-tier.bicep`, `app-tier.bicep`, `db-tier.bicep`（それぞれ AZ1 & AZ2 に 2台ずつ展開）

ティアモジュール側は、ティア固有の判断を担います。
- どの bootstrap スクリプトを使うか（NGINX / Node.js / MongoDB）
- どの入力が必要か（例: app tier は Entra IDs と MongoDB URI が必要）

## 3) 依存関係: 暗黙の依存（参照）と明示 `dependsOn` の使い分け

### 3.1 outputs 参照による暗黙依存
Bicep は、別モジュールの outputs を参照すると自動的に依存関係を作ります。

`materials/bicep/main.bicep` の例:
- VNet が NSG の ID を必要とする → `vnet` モジュールが `nsgWeb.outputs.nsgId` などを参照
- Key Vault が VM を待つ → VM の `principalIds` を参照

読みやすく、壊れにくいので、原則としてこの形を優先します。

### 3.2 Azure の都合で “順序が厳密” な場合に `dependsOn`
このリポジトリでは、次のように「先に作るだけでなく *使える状態* である必要がある」ケースで明示 `dependsOn` を使います。

`materials/bicep/main.bicep` の例:
- `vnet` が `natGateway` に依存（サブネットへ NAT Gateway を安全に関連付けるため）
- `dbTier` が `vnet` に依存（MongoDB のプロビジョニング前に outbound が整っていることを保証するため）

## 4) 条件付きデプロイ + 安全な参照（`.?` + `??`）

### 4.1 条件付きモジュール
例えば次のように、モジュールを条件付きでデプロイします。
- `module natGateway ... = if (deployNatGateway) { ... }`

### 4.2 条件付き outputs の安全な参照
条件付きモジュールは outputs が存在しない可能性があります。このリポジトリでは safe-dereference を使っています。
- `logAnalytics.?outputs.?workspaceId ?? ''`

これにより「監視を off」にしても `main.bicep` を修正せずデプロイできます。

## 5) “拡張だけ更新” パターン: `skipVmCreation` + `existing`

VM リソースは、immutable なプロパティ変更で再デプロイが失敗しやすいです（ワークショップだと SSH key 変更が典型）。

このリポジトリには、意図的な回避策があります。
- `main.bicep` 側（ティア単位）:
  - `skipVmCreationWeb`, `skipVmCreationApp`, `skipVmCreationDb`
- `vm.bicep` 側（VM モジュール）:
  - `skipVmCreation`

`skipVmCreation` が `true` のとき:
- VM/NIC は `existing` リソースとして扱う
- 更新対象は拡張（Azure Monitor Agent, Custom Script）だけにする

ワークショップ中の復旧・反復に向いた設計です。

## 6) Custom Script を確実に再実行する: `forceUpdateTag`

Custom Script Extension は基本的に冪等（idempotent）に設計されがちですが、Azure 側が「何も変わっていない」と判断すると再実行されないことがあります。

このリポジトリのテクニック:
- `vm.bicep` が `forceUpdateTag` を公開
- `main.bicep` が `forceUpdateTagWeb`, `forceUpdateTagApp`, `forceUpdateTagDb` を用意

タグ値（例: タイムスタンプ文字列）を変えると、そのティアのスクリプト再実行を強制できます。

## 7) スクリプト注入（script injection）: `loadTextContent()` + プレースホルダ + `base64()`

ティアモジュールは bash スクリプトを読み込み、プレースホルダ置換を行います。

例:
- `web-tier.bicep` が `scripts/nginx-install.sh` を読み込み、次を置換:
  - `__ENTRA_TENANT_ID__`, `__ENTRA_FRONTEND_CLIENT_ID__`, `__ENTRA_BACKEND_CLIENT_ID__`
- `app-tier.bicep` が `scripts/nodejs-install.sh` を読み込み、次を置換:
  - `__MONGODB_URI__`, `__ENTRA_TENANT_ID__`, `__ENTRA_CLIENT_ID__`

このパターンの理由:
- bash/JSON の `{}` などで `format()` のエスケープ地獄を避ける
- スクリプトを単体ファイルとして読みやすく／テストしやすく保つ
- 学生ごとの値の流れを「`.bicepparam` から 1本道」にできる

## 8) 可観測性: Bicep で AMA、DCR はデプロイ後に作る

VM モジュールは **Azure Monitor Agent（AMA）** を VM 拡張としてデプロイします。

一方で、このリポジトリは **Data Collection Rule（DCR）を Bicep ではデプロイしません**。
理由（`main.bicep` とスクリプトで説明・実装）:
- Log Analytics の `Syslog` / `Perf` などのテーブルは非同期に作成されます
- 直後に DCR を作ると “InvalidOutputTable” のようなエラーで失敗することがあります

ワークショップの流れ:
- Bicep でインフラをデプロイ
- その後、ポストデプロイのスクリプトを実行
  - macOS/Linux: `scripts/configure-dcr.sh <resource-group>`
  - Windows: `scripts/configure-dcr.ps1 -ResourceGroupName <resource-group>`

## 9) RBAC: Key Vault を VM の後にデプロイ（Managed Identity でアクセス）

Key Vault は `materials/bicep/modules/security/key-vault.bicep` でデプロイします。
主なポイント:
- `enableRbacAuthorization: true`（access policy ではなく RBAC モード）
- 組み込みロールを割り当て:
  - 管理者: “Key Vault Administrator”
  - VM: “Key Vault Secrets User”
- VM が欠けている／失敗している場合でもデプロイが壊れにくいよう、principal ID を防御的にフィルタします

ワークショップ中に Key Vault をアプリ側で使わなくても、次は学べます。
- “VM identity” が Azure の一級の principal であること
- Key Vault の secret read を許可するのは制御プレーン（RBAC）であること

## 10) Outputs を “ワークショップ契約（contract）” として使う

`materials/bicep/main.bicep` は、受講者／講師がすぐ使える outputs を出します。
- Application Gateway の FQDN と HTTPS URL
- 各ティアのプライベート IP
- MongoDB 接続文字列（検証用）
- Key Vault URI（デプロイ時）
- NAT Gateway の Public IP（デプロイ時）

Portal を探し回らなくても環境を利用できるようにする狙いです。

## 付録: パラメータファイルの安全な運用（学生向け）

推奨フロー（ワークショップ）:
1. `main.bicepparam` → `main.local.bicepparam` をコピー
2. 実値は `main.local.bicepparam` にだけ入れる
3. `--parameters main.local.bicepparam` でデプロイする

理由:
- tenant ID / client ID などの識別子や、よりセンシティブな値のコミット事故を避ける
- 「学生が編集するファイル」を固定し、進行を安定させる
