---
title: Azure IaaS Workshop 受講者ポータル
---

# Azure IaaS Workshop 受講者ポータル

このポータルは、2 日版 Azure IaaS Workshop を進めるための受講者向け入口です。CLI とスクリプト作業は **Azure Cloud Shell (Bash)** を標準にし、ローカル PC にはブラウザ以外のツールを原則として要求しません。

## まず読むページ

| 順番 | ページ | 目的 |
|---|---|---|
| 1 | [受講者クイックスタート](learner/learner-quickstart.ja.md) | 全体像、読む順番、完了条件を確認する |
| 2 | [Day 0: 事前準備](learner/day-0-prerequisites.ja.md) | Azure Portal、Cloud Shell、Entra ID 権限、クォータを確認する |
| 3 | [Azure Cloud Shell ガイド](learner/azure-cloud-shell-guide.ja.md) | Cloud Shell の起動、clone、ファイル編集、復帰方法を確認する |
| 4 | [Day 1: デプロイチェックリスト](learner/day-1-deployment-checklist.ja.md) | Cloud Shell でデプロイ、初期設定、動作確認、監視確認を進める |
| 5 | [Day 2: 回復性チェックリスト](learner/day-2-resiliency-checklist.ja.md) | Backup、Restore、HA 検証、ASR/test failover を安全に進める |

## 補足資料

| ページ | 位置づけ |
|---|---|
| [監視ガイド](operations/monitoring-guide.ja.md) | Day 1 の Azure Monitor / Log Analytics 演習で参照する |
| [災害復旧ガイド](operations/disaster-recovery-guide.ja.md) | Day 2 の Backup / Restore / ASR 演習で参照する |
| [トラブルシューティングランブック](operations/troubleshooting-runbook.ja.md) | 症状から確認箇所と対処に進む |
| [クイックリファレンス](reference/quick-reference-card.ja.md) | リソース名、ポート、主要コマンド、KQL を確認する |
| [アイデンティティ、アクセス、シークレットガイド](reference/identity-and-access-guide.ja.md) | Entra ID、RBAC、Managed Identity の背景理解に使う |
| [Bicep テクニックガイド](reference/bicep-techniques-guide.ja.md) | Bicep の構造を深掘りしたい場合に読む |
| [ローカル開発ガイド](development/local-development-guide.ja.md) | アプリケーションを手元で変更・検証したい開発者向けの任意資料 |

## ディレクトリ構成

| フォルダ | 内容 |
|---|---|
| `learner/` | 受講者が順番に進める Day 0 / Day 1 / Day 2 の本線 |
| `operations/` | 監視、BCDR、トラブルシューティングなど運用系の補足 |
| `reference/` | クイックリファレンス、Bicep、Identity などの参照資料 |
| `development/` | ローカル開発など教材・アプリ開発者向けの任意資料 |
| `en/` | 既存英語版ドキュメント。日本語版の構成確定後に同期予定 |
| `archive/` | 教材計画など、受講者ポータルには出さない内部メモ |

## 現在の整備状況

Day 0、Day 1、Day 2、トラブルシューティング、クイックリファレンスの主要導線を整備しています。クリーンアップ専用ページと英語版同期は後続フェーズで拡張します。

## GitHub Pages を有効化する場合

このリポジトリでは GitHub Actions-based Pages を使います。リポジトリの **Settings > Pages** で source を **GitHub Actions** に設定すると、このポータルが公開されます。公開 URL は通常 `https://<OWNER>.github.io/<REPOSITORY>/` です。
