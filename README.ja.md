# Azure IaaS ワークショップ - マルチユーザー ブログ アプリケーション

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

English version: [README.md](./README.md)
注: 日本語版の受講者導線を先行して更新しています。英語版 README は後続フェーズで同期予定です。

このリポジトリは、回復性の高い 3 層 Web アプリケーションを構築しながら、Azure IaaS の高可用性、監視、バックアップ、災害復旧を学ぶための 2 日版ハンズオン教材です。

## まずどこから始めるか

| 利用者 | 入口 | 目的 |
|---|---|---|
| 受講者 | [受講者ポータル](https://hironariy.github.io/Azure-IaaS-Workshop/) または [Markdown 版ポータル](materials/docs/learner-portal.ja.md) | Day 0、Day 1、Day 2 の教材を順番に進める |
| 講師 / TA | [WorkshopPlan.md](WorkshopPlan.md) | タイムテーブル、成功条件、支援ポイントを確認する |
| 教材・アプリ開発者 | [ローカル開発ガイド](materials/docs/development/local-development-guide.ja.md) と [design/](design/) | アプリケーション、Bicep、教材を保守・拡張する |

GitHub Pages を有効化したコピーリポジトリでは、公開 URL は通常 `https://<OWNER>.github.io/<REPOSITORY>/` になります。Pages が未設定の場合も、[Markdown 版ポータル](materials/docs/learner-portal.ja.md) から受講者向け教材を GitHub 上でそのまま読めます。

## 受講者向けクイックリンク

| 順番 | ページ | 内容 |
|---|---|---|
| 1 | [受講者クイックスタート](materials/docs/learner/learner-quickstart.ja.md) | 教材の読み順とワークショップ全体像 |
| 2 | [Day 0: 事前準備](materials/docs/learner/day-0-prerequisites.ja.md) | Azure Portal、Cloud Shell、Entra ID、クォータ、GitHub リポジトリ確認 |
| 3 | [Day 1: Azure リソースデプロイ](materials/docs/learner/day-1-deployment-checklist.ja.md) | Cloud Shell 準備、Bicep デプロイ、デプロイ後セットアップ、DCR 構成、FQDN 取得 |
| 4 | [Day 1: アプリデプロイ](materials/docs/learner/day-1-app-deployment.ja.md) | App VM / Web VM へのアプリケーションコード配置と疎通確認 |
| 5 | [監視ガイド](materials/docs/operations/monitoring-guide.ja.md) | Azure Monitor と Log Analytics の確認 |
| 6 | [Day 2: 回復性チェックリスト](materials/docs/learner/day-2-resiliency-checklist.ja.md) | Azure Backup、Restore、HA 検証、ASR/test failover |
| 7 | [災害復旧ガイド](materials/docs/operations/disaster-recovery-guide.ja.md) | BCDR の背景、安全ルール、期待結果 |
| 8 | [Azure Cloud Shell ミニガイド](materials/docs/learner/azure-cloud-shell-guide.ja.md) | Cloud Shell Bash の起動と基本操作の確認 |
| 9 | [トラブルシューティングランブック](materials/docs/operations/troubleshooting-runbook.ja.md) | 症状別の確認箇所と対処 |
| 10 | [クイックリファレンス](materials/docs/reference/quick-reference-card.ja.md) | リソース名、ポート、主要コマンド、KQL |

通常のワークショップ参加では、ローカル PC に Azure CLI、Azure PowerShell、Bicep CLI、OpenSSL、Node.js、Docker をインストールする必要はありません。CLI とスクリプト作業は Azure Cloud Shell Bash を標準にします。

## ワークショップ概要

### 対象者

- AWS の設計・運用経験があり、Azure IaaS の実践パターンを学びたいエンジニア
- Azure レベルは AZ-900 から AZ-104 程度
- 3 層 Web アプリケーション、監視、バックアップ、DR の実践的な流れを体験したい方

### 学習内容

| トピック | 主な Azure サービス |
|---|---|
| 高可用性 | Availability Zones、Application Gateway、Standard Load Balancer |
| ネットワーク | Virtual Network、Subnet、NSG、NAT Gateway、Azure Bastion |
| コンピューティング | Virtual Machines、Managed Disks |
| アイデンティティ | Microsoft Entra ID、Azure RBAC、Managed Identity |
| Infrastructure as Code | Bicep |
| 監視 | Azure Monitor、Log Analytics、Azure Monitor Agent |
| BCDR | Azure Backup、Azure Site Recovery |

## サンプルアプリケーション

サンプルは、Microsoft Entra ID 認証を使うマルチユーザー ブログプラットフォームです。

| レイヤー | 技術 |
|---|---|
| フロントエンド | React 18、TypeScript、TailwindCSS、Vite |
| バックエンド | Node.js 20、Express.js、TypeScript |
| データベース | MongoDB 7.0 レプリカセット |
| 認証 | Microsoft Entra ID + MSAL.js |

主な機能:

- 公開ブログ投稿の閲覧
- 認証済みユーザーによる投稿作成、編集、削除
- プロフィール管理

## Azure アーキテクチャ

![Architecture Diagram](assets/Architecture/architecture.png)

このワークショップでは、Web / App / DB の各 tier を VM で構成し、Availability Zones、ロードバランシング、Bastion、監視、バックアップ、DR の考え方を学びます。

## リポジトリ構成

| パス | 内容 |
|---|---|
| `materials/docs/` | 受講者向け教材と補足資料 |
| `materials/bicep/` | Azure IaaS 環境をデプロイする Bicep テンプレート |
| `frontend/` | React フロントエンド |
| `backend/` | Express バックエンド |
| `design/` | アーキテクチャ、バックエンド、フロントエンド、DB、横断設計 |
| `scripts/` | SSL 証明書生成、デプロイ後セットアップ、監視構成の補助スクリプト |
| `.github/workflows/pages.yml` | GitHub Actions-based Pages による受講者ポータル公開 |

## 開発者向け

アプリケーションをローカルで実行・変更する場合は、[ローカル開発ガイド](materials/docs/development/local-development-guide.ja.md) を参照してください。これは受講者の通常デプロイ手順ではなく、教材やアプリケーションを保守する開発者向けの任意資料です。

Bicep の構造を理解したい場合は、[Bicep テクニックガイド](materials/docs/reference/bicep-techniques-guide.ja.md) と [materials/bicep/README.md](materials/bicep/README.md) を参照してください。

## GitHub Pages の公開

このリポジトリは GitHub Actions-based Pages を使います。管理者は GitHub の **Settings > Pages** で source を **GitHub Actions** に設定してください。`main` ブランチに `materials/docs/**` または `assets/**` の変更が push されると、受講者ポータルがビルド・公開されます。

## ライセンス

このプロジェクトは [MIT License](LICENSE) のもとで公開されています。
