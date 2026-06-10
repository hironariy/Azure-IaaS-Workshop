# ワークショップ教材改善設計書

作成日: 2026-06-10  
ステータス: レビュー用ドラフト  
対象: Azure IaaS Workshop の受講者向け教材、README、GitHub Pages、スクリーンショット計画

## 1. 目的

この設計書は、Azure IaaS Workshop の次回実施に向けて、受講者が本質ではない環境依存の問題でつまずく時間を減らし、GitHub 上の教材を迷わず進められる形へ改善するための方針をまとめる。

改善対象は、ワークショップ後のアンケートで多く寄せられた次の 2 点である。

1. フォワードプロキシがある環境でハンズオンを行ったため、Azure CLI の SSL エラーなど、学習テーマと直接関係しない問題で時間がかかった。
2. GitHub で README を見ながら作業したが、開発者向けセクションが混在していること、スクリーンショットが少ないこと、現在位置を見失いやすいことが問題になった。

改善の基本方針は、CLI とスクリプト作業を Azure Cloud Shell に寄せ、受講者向け手順を GitHub Pages のポータルとして整理することである。Microsoft Entra ID アプリ登録や Azure Portal 上での状態確認など、画面操作として残すことに意味がある箇所は Portal 手順として維持する。

本設計はドキュメント改善に限定する。アプリケーションコードおよび Bicep テンプレートの修正は対象外とする。

## 2. 背景

現在の教材では、受講者が Azure IaaS の高可用性、監視、BCDR という本来の学習テーマに入る前に、ローカル PC の環境差分でつまずく余地が大きい。

特に、企業ネットワーク配下ではフォワードプロキシや独自証明書により Azure CLI の SSL 検証エラーが発生しやすい。また、Windows、macOS、Linux で Azure CLI、Azure PowerShell、Bicep CLI、OpenSSL、PATH 設定などの前提が分かれるため、講師と受講者の画面やコマンドが揃いにくい。

一方で、README には受講者向け手順、ローカル開発、アーキテクチャ説明、開発者向け情報が混在している。既存の関連ガイドは有用だが、Day 0、Day 1、Day 2 の学習パスとして整理されていないため、受講者が「今どこにいるか」「次に何をすべきか」を把握しづらい。

## 3. 制約

本改善では、次の制約を守る。

- 可能な限り教材、手順、公開方法を GitHub のサービスに閉じる。
- アプリケーションコードは変更しない。
- Bicep テンプレートやインフラコードは変更しない。
- 既存のワークショップの主目的である Azure IaaS、Availability Zones、Azure Monitor、Azure Backup、Azure Site Recovery の学習内容は維持する。
- 日本語教材を先行し、英語版は後追いで整備する。
- 2 日版ワークショップを主対象とする。
- 4 時間短縮版は将来の派生として扱う。
- スクリーンショット本体は後でユーザーが取得して挿入する。ページ作成時点ではプレースホルダを置く。

## 4. 非対象

この設計では、次の作業は対象外とする。

- React、Express、MongoDB のアプリケーション実装変更
- Bicep モジュール、パラメータ、デプロイロジックの変更
- Azure リソース構成そのものの見直し
- 本番運用向けのセキュリティ強化実装
- すべての Portal 操作の CLI 化
- すべてのスクリーンショットの即時作成
- Azure 外部の独立した LMS やドキュメントサービスへの移行

## 5. 決定済み方針

| 項目 | 方針 |
|---|---|
| Cloud Shell の適用範囲 | CLI とスクリプト作業は Azure Cloud Shell を標準とする。Entra ID アプリ登録や視覚的な状態確認などは Azure Portal 操作として残す。 |
| 教材公開形態 | GitHub Pages を受講者向けの正式なポータルとする。 |
| GitHub Pages 実装方式 | GitHub Actions-based Pages を採用する。branch-based Pages は代替案としてのみ扱う。 |
| 受講者リポジトリ | このワークショップリポジトリを public template repository とし、受講者は各自の GitHub アカウントまたは指定組織にコピーして利用する。 |
| Entra ID アプリ登録 | 標準は受講者が各自で Portal から作成する。組織ポリシーで権限が不足する場合は講師が対応する。 |
| 言語 | 日本語を先行整備し、英語は後追いで同期する。 |
| ワークショップ範囲 | 2 日版ワークショップを主対象とする。 |
| 変更対象 | README、教材 Markdown、スクリーンショット用アセット、GitHub Pages 関連設定。 |
| 変更しないもの | アプリケーションコード、Bicep 実装、既存インフラ構成の挙動。 |
| スクリーンショット | ページ作成時点では実画像を入れず、標準化したプレースホルダを置く。実画像は後でユーザーが取得し挿入する。 |

## 6. スクリーンショットプレースホルダ方針

受講者向け GitHub Pages のページを作成する段階では、実際のスクリーンショットは挿入しない。代わりに、後から画像を差し替えやすい TODO 形式のプレースホルダを配置する。

各プレースホルダには、以下の項目を必ず含める。

| 項目 | 内容 |
|---|---|
| 期待する画像パス | 例: `assets/screenshots/day1-cloud-shell-launch.png` |
| 撮影対象 | 例: Azure Portal の Cloud Shell 起動画面 |
| 画像の目的 | 例: 受講者が Bash モードの Cloud Shell を開けていることを確認する |
| 推奨 alt text | 例: Azure Portal showing Cloud Shell opened in Bash mode |
| 挿入メモ | 後で画像を置き換える際の注意点 |
| マスク対象 | アカウント名、テナント ID、サブスクリプション ID、メールアドレス、リソース名に含まれる個人情報など |

標準プレースホルダ例:

```markdown
> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day1-cloud-shell-launch.png`
> - Capture target: Azure Portal Cloud Shell launch screen
> - Purpose: 受講者が Cloud Shell を Bash モードで開けていることを確認する
> - Suggested alt text: Azure Portal showing Cloud Shell opened in Bash mode
> - Insertion note: Cloud Shell が画面下部に表示され、Bash が選択されている状態を撮影する
> - Mask: アカウント名、テナント ID、サブスクリプション ID
```

## 7. 現状分析

### 7.1 参照した既存ファイル

| ファイル | 位置づけ |
|---|---|
| `README.ja.md` | 現在の日本語エントリポイント。受講者向け、開発者向け、講師向け情報が混在しているため、役割別導線への再構成が必要。 |
| `README.md` | 英語版 README。日本語版の改善方針を確定した後に追従する。 |
| `WorkshopPlan.md` | 2 日版ワークショップの Day 1、Day 2、成功条件、タイムテーブルの根拠。 |
| `materials/docs/student-materials-plan.md` | 既存の教材ロードマップ。教材設計原則と追加ガイド案を再利用する。 |
| `materials/docs/local-development-guide.ja.md` | ローカル開発パス。ワークショップの Azure デプロイ手順とは切り離し、任意の開発者向け資料として明確化する。 |
| `materials/docs/monitoring-guide.ja.md` | Day 1 の監視演習に利用する。スクリーンショット、チェックポイント、KQL 例の補強対象。 |
| `materials/docs/disaster-recovery-guide.ja.md` | Day 2 の BCDR 演習に利用する。安全手順、期待結果、ロールバック、復旧確認の補強対象。 |
| `materials/docs/bicep-techniques-guide.ja.md` | Bicep を深く学ぶための補助資料。受講者のメイン手順ではなく、発展学習として扱う。 |
| `materials/docs/identity-and-access-guide.ja.md` | Entra ID、RBAC、Managed Identity の背景理解用資料。メインラボ手順ではなく参照資料として扱う。 |
| `materials/bicep/README.md` | Bicep デプロイの技術リファレンス。受講者向け Cloud Shell 手順と整合させる。 |
| `assets/Architecture/architecture.png` | 既存のアーキテクチャ図。ポータルホームや受講者クイックスタートで再利用する。 |
| `assets/images/*.png` | アプリケーションのサンプル画像。手順説明用スクリーンショットとしては使用しない。 |

### 7.2 README の課題

現在の `README.ja.md` と `README.md` は、受講者向けのデプロイ手順、ローカル開発手順、アーキテクチャ説明、開発者向け情報が混在している。

課題:

- 受講者が読むべき箇所と、開発者だけが読むべき箇所が区別しづらい。
- Azure デプロイの前提条件にローカル Azure CLI、Azure PowerShell、Bicep CLI、OpenSSL、Windows PATH 設定などが長く並び、本質的でない準備に注意が向きやすい。
- Windows、macOS、Linux の分岐が多く、受講者の画面やコマンドが揃いにくい。
- ローカル開発は任意であるにもかかわらず、受講者向け本線と近い位置にあり、混乱の原因になりうる。
- Day 1 と Day 2 の進行状況を追うためのチェックリストが、受講者向けの導線としてまとまっていない。
- スクリーンショットがほぼなく、Azure Portal 上でどの画面を見ればよいか判断しづらい。

### 7.3 関連ドキュメントの課題

`materials/docs/` 配下には有用なガイドが存在するが、受講者向けの一貫したナビゲーションにはなっていない。

既存の主なドキュメント:

- `materials/docs/local-development-guide.ja.md`
- `materials/docs/monitoring-guide.ja.md`
- `materials/docs/disaster-recovery-guide.ja.md`
- `materials/docs/bicep-techniques-guide.ja.md`
- `materials/docs/identity-and-access-guide.ja.md`
- `materials/docs/student-materials-plan.md`

課題:

- `student-materials-plan.md` には良い教材案があるが、受講者の入口からは見つけにくい。
- 監視ガイドと DR ガイドはあるが、Day 1/Day 2 のワークショップ手順としての前後関係が弱い。
- `local-development-guide.ja.md` は開発者には有用だが、Azure デプロイのみを行う受講者には任意であることをより強く示す必要がある。
- `bicep-techniques-guide.ja.md` と `identity-and-access-guide.ja.md` は深掘り教材として位置付け、本線の手順からは必要な場面で参照する形が望ましい。

### 7.4 スクリーンショットと画像アセットの現状

既存の画像アセットとして、`assets/Architecture/architecture.png` がある。これはアーキテクチャ概要の説明に再利用できる。

一方で、手順説明に必要な以下のスクリーンショットは不足している。

- Azure Portal で Cloud Shell を起動する画面
- Cloud Shell でリポジトリを clone した画面
- Microsoft Entra ID のアプリ登録画面
- API スコープ、API アクセス許可、リダイレクト URI 設定画面
- Bicep デプロイ実行中の Cloud Shell 画面
- リソースグループのデプロイ進捗画面
- Application Gateway の backend health 画面
- Log Analytics のクエリ画面
- Recovery Services vault のバックアップ画面
- Azure Site Recovery の test failover 画面

`assets/images/*.png` はアプリケーションのサンプル画像であり、手順説明用のスクリーンショットとしては使わない。

## 8. 将来の情報設計

### 8.1 全体構造

推奨する情報構造は次のとおり。

```text
README.ja.md
├── 受講者向け: GitHub Pages ポータルへ誘導
├── 講師向け: WorkshopPlan.md と運営資料へ誘導
├── 開発者向け: local-development-guide と design/ へ誘導
└── リポジトリ概要、ライセンス、関連リンク

GitHub Pages learner portal
├── ホーム
├── Day 0: 事前準備
├── Day 1: Cloud Shell でのデプロイと監視
├── Day 2: バックアップ、HA 検証、DR 演習
├── トラブルシューティング
├── クイックリファレンス
└── 補足資料

materials/docs/
├── learner-quickstart.ja.md
├── azure-cloud-shell-guide.ja.md
├── day-0-prerequisites.ja.md
├── day-1-deployment-checklist.ja.md
├── day-2-resiliency-checklist.ja.md
├── troubleshooting-runbook.ja.md
├── quick-reference-card.ja.md
├── monitoring-guide.ja.md
├── disaster-recovery-guide.ja.md
├── local-development-guide.ja.md
├── bicep-techniques-guide.ja.md
└── identity-and-access-guide.ja.md
```

`materials/docs/` は Markdown の正本として扱う。GitHub Pages の実装方式によっては、Pages 専用の source フォルダを追加してもよいが、初期設計では既存の Markdown 資産を活かす。

### 8.2 役割別の導線

| 利用者 | 主な入口 | 目的 |
|---|---|---|
| 受講者 | GitHub Pages の受講者ポータル | Day 0、Day 1、Day 2 の手順を迷わず進める。 |
| 講師、TA | `WorkshopPlan.md` と講師向け運用資料 | タイムテーブル、成功条件、支援ポイントを確認する。 |
| 開発者 | `materials/docs/local-development-guide.ja.md`、`design/`、各種設計資料 | アプリや教材の開発、保守、拡張を行う。 |

### 8.3 受講者向けページの設計原則

受講者向けページは、次の原則に従う。

- 1 ページ 1 目的にする。
- 各ページの冒頭に「このページでやること」「所要時間」「前提」「完了条件」を置く。
- 各手順には「期待結果」と「チェックポイント」を置く。
- ページ末尾には「次に進む」と「迷ったときに見るページ」を置く。
- Azure Portal 操作には、必要な箇所にスクリーンショットプレースホルダを置く。
- AWS 経験者向けに、必要な箇所で AWS サービスとの対応関係を示す。
- 開発者向けの補足は、本線の途中に長く置かず、別ページへリンクする。

## 9. Cloud Shell-first ワークフロー設計

### 9.1 基本方針

受講者のローカル PC ではブラウザのみを必須とし、Azure CLI、Azure PowerShell、Bicep CLI、OpenSSL、Git、SSH クライアントのローカルインストールを前提にしない。

Cloud Shell が提供するもの:

- Azure CLI
- Bash と PowerShell
- Git
- OpenSSL
- SSH クライアント
- `code` コマンドによる Web エディタ
- ファイルアップロードとダウンロード
- Azure 認証済みコンテキスト
- 永続ストレージ

### 9.2 Cloud Shell で扱う標準作業

以下は Cloud Shell で実施する標準作業とする。

- リポジトリの clone
- `az account show` によるログイン状態確認
- 必要に応じた `az account set` によるサブスクリプション選択
- 必要リソースプロバイダーの確認
- VM クォータの確認
- SSH 鍵の生成またはアップロード後の確認
- SSL 証明書生成スクリプトの実行
- `cert-base64.txt` の内容確認
- `main.local.bicepparam` の作成と編集
- `code` コマンドによる Cloud Shell エディタの利用
- リソースグループ作成
- `az deployment group create` による Bicep デプロイ
- デプロイ後スクリプトの編集と実行
- Bastion 経由の SSH 操作
- 監視設定、DCR 設定などの CLI 実行

### 9.3 Portal 操作として残す作業

以下は Cloud Shell に寄せすぎず、Azure Portal 操作として残す。

- Microsoft Entra ID アプリ登録の作成
- フロントエンド SPA とバックエンド API のアプリ登録設定
- API スコープ公開と API アクセス許可の設定
- 管理者の同意付与が必要な場合の確認
- リソースグループのデプロイ進捗確認
- Application Gateway の backend health 確認
- Log Analytics 画面でのクエリ実行
- Recovery Services vault での Backup / Restore 操作
- Azure Site Recovery の test failover 確認

Entra ID アプリ登録については、受講者が各自で作成する標準フローとする。ただし、組織ポリシーやテナント設定により権限が不足する場合は、講師が代替手順、事前作成値の配布、権限確認の支援などで対応する。

### 9.4 Day 0 で扱う準備

Day 0 またはワークショップ冒頭で、次を確認する。

- Azure Portal にサインインできる。
- Azure Cloud Shell を Bash モードで開ける。
- Cloud Shell の初回ストレージ作成が完了している。
- `az account show` で意図したテナントとサブスクリプションが選択されている。
- 必要なリソースプロバイダーと VM クォータを確認できる。
- Entra ID アプリ登録を作成できる権限がある、または講師から代替手順や必要値を受け取っている。

### 9.5 明示すべき Cloud Shell 固有ポイント

| 項目 | 設計方針 |
|---|---|
| 初回起動 | Cloud Shell のストレージ初期化に時間がかかることを説明する。 |
| シェル選択 | Bash を標準とする。PowerShell は必要時の参考扱いとする。 |
| ファイル編集 | `code <file>` を標準とし、`nano` や `vi` を代替として示す。 |
| ファイル保存場所 | Cloud Shell の永続ストレージと作業ディレクトリの違いを説明する。 |
| SSH 鍵 | Cloud Shell 内で生成する方法を標準とし、既存鍵アップロードは代替とする。 |
| 秘密鍵 | Cloud Shell 内に保存されるため、権限と取り扱いに注意する。 |
| 証明書 | 生成された `cert.pfx` と `cert-base64.txt` の用途を分けて説明する。 |
| セッションタイムアウト | 長時間デプロイ中に切断されても Portal のデプロイ状態で進捗確認できることを説明する。 |
| GitHub 認証 | このワークショップリポジトリを public template repository として使い、受講者は各自のリポジトリにコピーしてから Cloud Shell で clone する。コピー先を private にする場合は GitHub 認証や PAT が必要になり得るため、ワークショップでは認証不要で clone できる公開範囲を推奨する。 |

### 9.6 SSH 鍵

SSH 鍵は Cloud Shell 上で生成する手順を標準とする。

想定コマンド:

```bash
ssh-keygen -t rsa -b 4096 -C "workshop@azure"
cat ~/.ssh/id_rsa.pub
```

代替として、既存鍵を Cloud Shell にアップロードする手順も補足する。ただし、秘密鍵の扱いを受講者が誤る可能性があるため、標準は Cloud Shell 内での新規生成とする。

### 9.7 SSL 証明書

自己署名証明書は Cloud Shell 上で生成する。

想定手順:

```bash
chmod +x scripts/generate-ssl-cert.sh
./scripts/generate-ssl-cert.sh
cat cert-base64.txt
```

`cert-base64.txt` の値は Bicep パラメータに貼り付ける。Cloud Shell 上のファイルを直接編集する場合は `code` を使用する。

### 9.8 パラメータファイル編集

`materials/bicep/main.bicepparam` をコピーして `main.local.bicepparam` を作成し、Cloud Shell の Web エディタで編集する。

想定手順:

```bash
cd materials/bicep
cp main.bicepparam main.local.bicepparam
code main.local.bicepparam
```

編集対象には、少なくとも次を含む。

- SSH public key
- admin object ID
- Entra tenant ID
- backend API app registration client ID
- frontend SPA app registration client ID
- SSL certificate data
- SSL certificate password
- MongoDB application password
- Application Gateway DNS label

### 9.9 デプロイ

Cloud Shell から Azure CLI でデプロイする。

想定手順:

```bash
az group create --name rg-blogapp-workshop --location japanwest

az deployment group create \
  --resource-group rg-blogapp-workshop \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam
```

デプロイは 15 分から 30 分程度かかる可能性がある。Cloud Shell の出力だけでなく、Azure Portal のリソースグループの Deployments 画面で進捗を確認する手順を入れる。

### 9.10 デプロイ後セットアップ

デプロイ後スクリプトも Cloud Shell 上で実行する。

ポイント:

- `post-deployment-setup.template.sh` を `post-deployment-setup.local.sh` にコピーする。
- Cloud Shell の `code` でプレースホルダを置換する。
- Bicep パラメータで指定した MongoDB password と、デプロイ後スクリプト内の password が一致していることをチェックポイント化する。
- Bastion 経由の SSH に必要な秘密鍵パスは、Cloud Shell 上で生成した鍵のパスを使う。

## 10. GitHub Pages 設計

### 10.1 目的

GitHub Pages は、受講者がワークショップ中に迷わず進めるための正式な教材ポータルとする。

期待する効果:

- README よりも見やすいナビゲーションを提供する。
- Day 0、Day 1、Day 2 の現在位置を明確にする。
- スクリーンショットを含む手順を見やすく提示する。ただし初期作成時はプレースホルダを置く。
- 開発者向け情報を本線から分離する。
- GitHub リポジトリ内で教材管理を完結させる。

### 10.2 実装方式の選択肢

| 案 | 内容 | 長所 | 注意点 |
|---|---|---|---|
| branch-based Pages | リポジトリ内の Markdown と Jekyll 設定を使い、GitHub Pages を公開する。 | 設定が少なく、GitHub の標準機能に近い。 | 受講者向けでないファイルを除外する設計が必要。 |
| GitHub Actions-based Pages | GitHub Actions で Pages 用の成果物を組み立てて公開する。 | 受講者向けポータルだけをきれいに公開しやすい。将来的なリンクチェックやビルド検証も組み込みやすい。 | Workflow の追加と保守が必要。 |

採用方式は GitHub Actions-based Pages とする。受講者向けの出力だけを整理でき、将来的にリンクチェック、Markdown lint、画像参照チェックなどを追加しやすいためである。

branch-based Pages は、GitHub Actions workflow を追加できない場合の代替案としてのみ残す。その場合は、Jekyll の除外設定やページ構成を明確にし、開発者向けドキュメントが受講者ポータルに混ざらないようにする。

## 11. 2 日版ワークショップの受講者ジャーニー

### 11.1 Day 0: 事前準備

目的:

- ワークショップ開始前に、Azure Portal と Cloud Shell が使える状態にする。
- Entra ID アプリ登録権限、サブスクリプション、クォータを確認する。
- GitHub リポジトリの扱いを確認する。

主なチェックポイント:

- Azure Portal にサインインできる。
- Cloud Shell Bash を起動できる。
- `az account show` で想定サブスクリプションが表示される。
- Entra ID アプリ登録を作成できる、または講師から必要な値を受け取っている。
- VM クォータが足りている。

### 11.2 Day 1: デプロイ、HA 構成、監視

目的:

- Cloud Shell で Azure IaaS 環境をデプロイする。
- 3 層アプリケーションを動作確認する。
- Azure Monitor と Log Analytics で観測できる状態を確認する。

Day 1 チェックリストには、各ステップに以下を持たせる。

- 目的
- 想定所要時間
- 実行コマンドまたは Portal 操作
- 期待結果
- チェックポイント
- よくある失敗と参照先
- 次のステップへのリンク
- 必要に応じたスクリーンショットプレースホルダ

主なステップ:

1. Cloud Shell の起動と作業ディレクトリ準備
2. リポジトリの clone
3. サブスクリプションとテナントの確認
4. リソースプロバイダーとクォータ確認
5. Entra ID アプリ登録の作成または配布値の確認
6. SSH 鍵の準備
7. SSL 証明書の生成
8. Bicep パラメータファイル作成と編集
9. リソースグループ作成
10. Bicep デプロイ実行
11. Portal でデプロイ進捗確認
12. デプロイ後セットアップ実行
13. アプリケーション疎通確認
14. Application Gateway/backend health 確認
15. Azure Monitor / Log Analytics の確認

主なチェックポイント:

- Cloud Shell 上にリポジトリを clone できた。
- SSH 鍵を用意できた。
- SSL 証明書を生成できた。
- `main.local.bicepparam` を作成、編集できた。
- Resource group を作成できた。
- Bicep deployment が `Succeeded` になった。
- デプロイ後スクリプトが完了した。
- Application Gateway の URL にアクセスできた。
- ログイン、投稿作成、投稿表示などの基本動作を確認できた。
- Log Analytics で基本クエリを実行できた。

### 11.3 Day 2: BCDR と障害検証

目的:

- Azure Backup によるバックアップとリストアを体験する。
- Web、App、DB 層の障害時の挙動を確認する。
- Azure Site Recovery による DR の考え方と手順を理解する。

Day 2 チェックリストには、Day 1 と同様に目的、期待結果、チェックポイント、ロールバック、安全確認、スクリーンショットプレースホルダを持たせる。

主なステップ:

1. Day 1 環境が正常稼働していることを確認
2. テストデータを作成
3. Recovery Services vault と Backup 設定を確認
4. オンデマンドバックアップを取得
5. 復元ポイントを確認
6. Restore 操作を実施またはデモ確認
7. Web VM 停止による HA 確認
8. Web VM 再起動後の正常性確認
9. App VM 停止による HA 確認
10. DB VM 停止による MongoDB レプリカセット動作確認
11. ASR のレプリケーション状態確認
12. test failover 実行
13. test failover 後のアプリケーション確認
14. test failover リソースのクリーンアップ

主なチェックポイント:

- Recovery Services vault を確認できた。
- 対象 VM のバックアップを構成または確認できた。
- 復元ポイントを作成できた。
- Web VM 停止時もサービスが継続することを確認できた。
- App VM 停止時の影響と復旧を確認できた。
- DB VM 停止時の挙動を確認できた。
- ASR の test failover または設計上の DR 手順を確認できた。
- 演習後に停止、復旧、クリーンアップの状態を確認できた。

## 12. 作成または改訂するドキュメント

### 12.1 新規作成候補

| ドキュメント | 目的 | 優先度 |
|---|---|---|
| GitHub Pages learner portal home | 受講者向けの正式な入口。Day 0、Day 1、Day 2、トラブルシューティング、クリーンアップへ誘導する。 | 高 |
| `materials/docs/learner-quickstart.ja.md` | 初めて参加する受講者向けの最短導線。読むべき順番、所要時間、前提条件を示す。 | 高 |
| `materials/docs/azure-cloud-shell-guide.ja.md` | Cloud Shell の起動、Bash 選択、clone、ファイル編集、ファイルアップロード/ダウンロード、セッションタイムアウト時の復帰を説明する。 | 高 |
| `materials/docs/day-0-prerequisites.ja.md` | ワークショップ前のチェックリスト。Azure サインイン、サブスクリプション、Entra ID 権限、クォータ、GitHub リポジトリを扱う。 | 高 |
| `materials/docs/day-1-deployment-checklist.ja.md` | Day 1 の本線。Cloud Shell を使ったデプロイ、デプロイ後セットアップ、基本動作確認、監視確認をチェックリスト化する。 | 高 |
| `materials/docs/day-2-resiliency-checklist.ja.md` | Day 2 の本線。Backup、Restore、HA 検証、ASR/test failover を安全に進めるチェックリストにする。 | 中 |
| `materials/docs/troubleshooting-runbook.ja.md` | 症状から確認箇所へ進むランブック。deployment failure、quota exceeded、Entra ID 権限不足、Application Gateway 502/503、health probe failure、DB connection timeout、Cloud Shell session timeout などを扱う。 | 中 |
| `materials/docs/quick-reference-card.ja.md` | リソース名、ポート、主要コマンド、確認画面、よく使う KQL などを 1 ページにまとめる。 | 中 |
| `materials/docs/aws-to-azure-cheatsheet.ja.md` | AWS 経験者向けの対応表。VPC/VNet、Security Group/NSG、ALB/Application Gateway、NLB/Load Balancer、IAM/RBAC、CloudWatch/Azure Monitor などを扱う。 | 任意 |

### 12.2 改訂対象

| ドキュメント | 改訂方針 |
|---|---|
| `README.ja.md` | 詳細手順を長く置くのではなく、役割別の入口へ再構成する。受講者は GitHub Pages へ、講師は `WorkshopPlan.md` へ、開発者はローカル開発ガイドや設計資料へ誘導する。 |
| `README.md` | 日本語版の構成が固まった後に追従する。 |
| `materials/docs/local-development-guide.ja.md` | Azure デプロイの本線ではなく、開発者向け任意手順であることを冒頭で明確化する。 |
| `materials/docs/monitoring-guide.ja.md` | Day 1 の監視演習とつながるように、チェックポイント、スクリーンショットプレースホルダ、KQL スタータークエリを追加する。 |
| `materials/docs/disaster-recovery-guide.ja.md` | Day 2 の演習手順とつながるように、安全ルール、ロールバック、期待結果、スクリーンショットプレースホルダを追加する。 |
| `materials/docs/bicep-techniques-guide.ja.md` | 受講者の本線ではなく、Bicep を深掘りしたい人向けの補足として位置付ける。 |
| `materials/docs/identity-and-access-guide.ja.md` | Entra ID、RBAC、Managed Identity の背景理解用として参照する。本線のアプリ登録手順は Day 0 または Cloud Shell ガイド側に置く。 |
| `materials/bicep/README.md` | 技術リファレンスとして残し、受講者向け Cloud Shell 手順と矛盾しないようにする。 |

## 13. スクリーンショットとアセット計画

### 13.1 保存場所

最終的なスクリーンショットは、GitHub Pages と GitHub の Markdown 表示で安定して参照できるよう、リポジトリ内に保存する。

推奨保存先:

```text
assets/screenshots/
├── day0-*.png
├── day1-*.png
├── day2-*.png
└── troubleshooting-*.png
```

Pages 実装方式に合わせて documentation-specific な画像フォルダを作ってもよい。

### 13.2 優先スクリーンショット

Phase 1 では、実画像ではなく、以下の位置にプレースホルダを配置する。

| 種別 | 撮影対象 | 想定ファイル名例 | 優先度 |
|---|---|---|---|
| Cloud Shell | Azure Portal から Cloud Shell を起動した画面 | `assets/screenshots/day1-cloud-shell-launch.png` | 高 |
| Cloud Shell | Bash モードが選択されている画面 | `assets/screenshots/day1-cloud-shell-bash.png` | 高 |
| GitHub clone | Cloud Shell でリポジトリを clone した直後 | `assets/screenshots/day1-git-clone-complete.png` | 高 |
| Entra ID | フロントエンドアプリ登録の概要画面 | `assets/screenshots/day0-entra-frontend-overview.png` | 高 |
| Entra ID | バックエンド API アプリ登録の概要画面 | `assets/screenshots/day0-entra-api-overview.png` | 高 |
| Entra ID | API スコープ公開画面 | `assets/screenshots/day0-entra-api-scope.png` | 高 |
| Entra ID | API アクセス許可追加画面 | `assets/screenshots/day0-entra-api-permission.png` | 高 |
| Bicep | `main.local.bicepparam` を Cloud Shell editor で開いた画面 | `assets/screenshots/day1-bicep-param-edit.png` | 高 |
| デプロイ | `az deployment group create` 実行中の Cloud Shell | `assets/screenshots/day1-deployment-command.png` | 高 |
| デプロイ | Resource group の Deployments 画面 | `assets/screenshots/day1-deployment-progress.png` | 高 |
| デプロイ | デプロイ成功画面 | `assets/screenshots/day1-deployment-succeeded.png` | 高 |
| アプリ | Application Gateway URL でアプリが表示された画面 | `assets/screenshots/day1-app-home.png` | 高 |
| 正常性 | Application Gateway backend health | `assets/screenshots/day1-appgw-backend-health.png` | 高 |
| 監視 | Log Analytics で KQL を実行した画面 | `assets/screenshots/day1-log-analytics-query.png` | 中 |
| Backup | Recovery Services vault の backup item 画面 | `assets/screenshots/day2-backup-item.png` | 中 |
| Restore | 復元ポイントまたは restore 操作画面 | `assets/screenshots/day2-restore-point.png` | 中 |
| ASR | Site Recovery の replication health | `assets/screenshots/day2-asr-replication-health.png` | 中 |
| ASR | Test failover の確認画面 | `assets/screenshots/day2-asr-test-failover.png` | 中 |

### 13.3 マスク対象

スクリーンショットでは、次の情報を必ずマスクまたは写り込まないようにする。

- アカウント名
- メールアドレス
- テナント ID
- サブスクリプション ID
- Client ID などの識別子
- シークレット値
- 接続文字列
- パスワード
- 個人名や組織名
- 顧客名が推測できるリソース名

### 13.4 スクリーンショット挿入後の確認

実画像が挿入された後は、以下を確認する。

- プレースホルダで指定した撮影対象と一致している。
- alt text が設定されている。
- 画像が GitHub Pages で表示される。
- 画像が GitHub の Markdown 表示でも破綻しない。
- 機密情報や個人情報が写っていない。
- 画面上のリソース名が個人や顧客を特定できない。

## 14. 段階的ロールアウト計画

### 14.1 Phase 1: 次回ワークショップの主要課題を解消する

目的:

- Cloud Shell 標準化により、ローカルプロキシや SSL エラーの影響を減らす。
- 受講者が迷わない入口と Day 1 手順を作る。
- 必要なスクリーンショット位置にプレースホルダを置く。

作業:

- GitHub Pages learner portal home の作成
- `materials/docs/azure-cloud-shell-guide.ja.md` の作成
- `materials/docs/learner-quickstart.ja.md` の作成
- `materials/docs/day-0-prerequisites.ja.md` の作成
- `materials/docs/day-1-deployment-checklist.ja.md` の作成
- `README.ja.md` の役割別ナビゲーション化
- Day 0/Day 1 に必要なスクリーンショットプレースホルダの挿入
- GitHub Pages の最小ポータルを用意

完了条件:

- 受講者が README から GitHub Pages に移動できる。
- 受講者が Cloud Shell を使って Day 1 のデプロイ作業を進められる。
- ローカル Azure CLI、OpenSSL、Bicep CLI のインストールが通常手順から外れている。
- 必要なスクリーンショット箇所にはプレースホルダがある。
- アプリケーションコードと Bicep 実装に変更がない。

### 14.2 Phase 2: Day 2 と運用支援を強化する

目的:

- BCDR 演習を安全に進められるようにする。
- トラブルシューティングを受講者自身で進めやすくする。
- 監視と DR の既存ガイドをワークショップ手順と接続する。

作業:

- `materials/docs/day-2-resiliency-checklist.ja.md` の作成
- `materials/docs/troubleshooting-runbook.ja.md` の作成
- `materials/docs/quick-reference-card.ja.md` の作成
- `materials/docs/monitoring-guide.ja.md` の強化
- `materials/docs/disaster-recovery-guide.ja.md` の強化
- Day 2 とトラブルシューティングに必要なスクリーンショットプレースホルダの挿入
- GitHub Pages のナビゲーション改善

### 14.3 Phase 3: 維持運用と拡張

目的:

- 英語版を日本語版に追従させる。
- 実画像挿入後の品質確認を行う。
- 講師、アシスタント向けの運営負荷を下げる。

作業:

- 英語版 README と教材の同期
- 必要に応じた AWS-to-Azure cheat sheet の整備または拡張
- ユーザーが取得した実スクリーンショットの挿入支援
- 実スクリーンショット挿入後のレビュー
- 講師向け運用資料の整備
- スクリーンショット更新基準の明文化
- 4 時間短縮版への派生方針整理

## 15. ガバナンスと保守ルール

### 15.1 言語運用

- 日本語を主として先行整備する。
- 英語版は日本語版の構成が固まってから同期する。
- 英語版が未同期の場合は、ページ内にその旨を明記する。
- 主要な更新時は、日本語版と英語版の同期対象リストを残す。

### 15.2 ページ作成ルール

- 各ページの冒頭に目的、対象者、所要時間、前提条件を置く。
- 各ステップには期待結果とチェックポイントを置く。
- ページ末尾に次のページへのリンクを置く。
- 迷ったときの戻り先として、ポータルトップとトラブルシューティングへのリンクを置く。
- ローカル開発や詳細設計は任意参照として分離する。
- 受講者向け日本語ページは `.ja.md` を付ける。
- ページ名は目的が分かるようにする。

### 15.3 ナビゲーション

各受講者向けページには、次を置く。

- 前のページ
- 次のページ
- 迷ったときのページ
- 関連する補足資料

### 15.4 スクリーンショット更新ルール

- スクリーンショットが必要な箇所には、まずプレースホルダを置く。
- 実画像を挿入する場合は、プレースホルダの情報と一致していることを確認する。
- Azure Portal の UI 変更があった場合、該当画像と手順を更新する。
- 画像には秘密情報や個人情報を含めない。
- 更新時は GitHub Pages と GitHub Markdown の両方で表示を確認する。

### 15.5 レビュー観点

ページ追加または更新時には、次を確認する。

- 受講者がそのページで何を完了すべきか明確か。
- 期待結果とチェックポイントがあるか。
- 本線と補足が分離されているか。
- スクリーンショットプレースホルダに必要項目があるか。
- 機密情報が含まれていないか。
- 内部リンクが GitHub Pages と GitHub Markdown の両方で辿れるか。
- アプリコードや Bicep コードに不要な変更が入っていないか。

## 16. 検証計画

### 16.1 Cloud Shell ドライラン

クリーンな Cloud Shell セッションで、次を確認する。

1. Cloud Shell を起動する。
2. リポジトリを clone する。
3. `az account show` でサブスクリプションを確認する。
4. 必要なツールを確認する。
5. SSH 鍵を生成する。
6. SSL 証明書を生成する。
7. `main.local.bicepparam` を作成する。
8. `code` でパラメータファイルを編集する。
9. Resource group を作成する。
10. Bicep deployment を開始する。
11. Azure Portal で進捗を確認する。

この検証では、ローカル Azure CLI、ローカル OpenSSL、ローカル Git、ローカル Bicep CLI が不要であることを確認する。

### 16.2 ドキュメントナビゲーション検証

GitHub Pages のホームから、次のページへ 1 クリックまたは次ページナビゲーションで到達できることを確認する。

- Day 0
- Day 1
- Day 2
- トラブルシューティング
- クイックリファレンス
- クリーンアップ

### 16.3 リンク検証

日本語の受講者向け導線について、GitHub Pages 表示と GitHub Markdown 表示の両方で内部リンクが解決されることを確認する。

### 16.4 スクリーンショットプレースホルダ検証

実画像挿入前に、すべての必要箇所にプレースホルダがあることを確認する。

各プレースホルダについて確認する項目:

- 想定画像パスがある。
- 撮影対象が明確である。
- 画像の目的が明確である。
- 推奨 alt text がある。
- 挿入メモがある。
- マスク対象が明記されている。

実画像挿入後に確認する項目:

- 画像がプレースホルダの目的と一致している。
- 画像が GitHub Pages で表示される。
- alt text が適切である。
- テナント ID、サブスクリプション ID、アカウント名、Client ID、シークレットなどが写っていない。

### 16.5 講師レビュー

講師またはアシスタントが、`WorkshopPlan.md` の成功条件と各ページのチェックポイントが対応していることを確認する。

### 16.6 スコープ確認

Git の差分を確認し、アプリケーションソースと Bicep テンプレートに変更がないことを確認する。

## 17. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| Entra ID アプリ登録権限がない | 受講者が認証設定を進められない。 | Day 0 で権限確認を行う。標準は受講者作成とし、権限が不足する場合は講師が代替手順や事前作成値の配布などで対応する。 |
| Cloud Shell の初回ストレージ作成で時間がかかる | Day 1 冒頭で待ち時間が発生する。 | Day 0 チェックリストで事前起動を促す。 |
| SSH 秘密鍵が Cloud Shell に残る | 鍵管理上の懸念がある。 | ワークショップ用途の鍵を Cloud Shell で生成し、取り扱いと削除手順を明記する。 |
| 既存 SSH 鍵アップロード時の扱いを誤る | 個人鍵の漏えいリスクがある。 | 既存鍵アップロードは補足扱いにし、標準は Cloud Shell 内での新規生成とする。 |
| `main.local.bicepparam` に秘密情報が含まれる | 誤 commit や画面共有時の漏えいリスクがある。 | gitignore 前提を説明し、GitHub へ push しないこと、画面共有時に隠すことを明記する。 |
| 受講者のコピー先リポジトリを private にした場合に PAT が必要 | Cloud Shell に GitHub 認証情報を入力する必要が出る。 | ワークショップリポジトリは public template repository とし、受講者は各自のリポジトリへコピーして使う。コピー先は、組織ポリシーに反しない範囲で Cloud Shell から認証なしで clone できる公開範囲を推奨する。 |
| Cloud Shell セッションタイムアウト | デプロイ中に画面が切断される。 | Portal の Deployments で進捗確認できることを説明する。再接続後の状態確認手順を runbook に入れる。 |
| サブスクリプションクォータ不足 | デプロイが失敗する。 | Day 0 または Day 1 冒頭で VM クォータ確認手順を実施する。講師も事前に参加者数とリージョンのクォータを確認する。 |
| 日本語版と英語版の差分が広がる | 英語利用者向けの内容が古くなる。 | 日本語先行、英語後追いの同期ルールを設ける。 |
| スクリーンショットに機密情報が写る | 情報漏えいリスクがある。 | プレースホルダにマスク対象を明記し、挿入後レビューで確認する。 |
| Azure Portal UI が変わる | スクリーンショットと手順が一致しなくなる。 | スクリーンショット更新基準を設け、手順本文と画像をセットで更新する。 |

## 18. 後続で確認する事項と決定済み補足

### 18.1 GitHub Pages の source strategy（決定済み）

決定事項: GitHub Pages は GitHub Actions-based Pages を採用する。

判断理由: 受講者向け出力を明示的に制御しやすく、将来的にリンクチェックや画像チェックを追加しやすいためである。branch-based Pages は、GitHub Actions workflow を追加できない場合の代替案としてのみ扱う。

### 18.2 受講者が使う GitHub リポジトリ（決定済み）

決定事項: このワークショップリポジトリはすでに public template repository であるため、受講者は各自の GitHub アカウントまたは指定組織にコピーして利用する。

判断理由: 受講者ごとに作業リポジトリを分離でき、パラメータファイル、メモ、スクリーンショット挿入などの個別作業を他の受講者に影響させずに進められるためである。Cloud Shell から clone する際の GitHub 認証負荷を避けるため、コピー先は組織ポリシーに反しない範囲で認証不要にすることを推奨する。

### 18.3 Entra ID アプリ登録の作成主体（決定済み）

決定事項: Entra ID のアプリ登録は、受講者が各自で Portal から作成することを主とする。

判断理由: Entra ID アプリ登録、API スコープ、API アクセス許可、リダイレクト URI の関係を受講者が自分で確認できるため、認証構成の学習効果が高い。組織ポリシーやテナント設定により権限が不足する場合は、講師が事前作成値の配布、権限確認、代替テナント利用など、その場の制約に応じて対応する。

## 19. レビュー依頼時の観点

別エージェントまたは人間レビューでは、次の観点で確認する。

1. アンケートで挙がった 2 つの課題に対して、設計が直接効いているか。
2. Cloud Shell-first によって、プロキシ、SSL、ローカルツール差分の問題を十分に回避できるか。
3. Portal に残す操作の理由が妥当か。
4. GitHub Pages を受講者向け入口にする設計が、GitHub に閉じる制約と整合しているか。
5. README の役割別分離が十分か。
6. Day 0、Day 1、Day 2 の進行が受講者にとって追いやすいか。
7. スクリーンショットプレースホルダの項目が後挿入に十分か。
8. 機密情報の写り込み防止が十分か。
9. Phase 1 が次回ワークショップまでに実現可能な粒度か。
10. アプリコードと Bicep コードを変更しない制約が守られているか。
11. 日本語先行、英語後追いの運用で、将来的なドキュメント差分を管理できるか。
12. 受講者、講師、開発者の導線が明確に分離されているか。
