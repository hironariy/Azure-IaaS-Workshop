---
title: Azure IaaS Workshop 受講者ポータル
---

# Azure IaaS Workshop 受講者ポータル

このポータルは、2 日版 Azure IaaS Workshop を進めるための受講者向け入口です。CLI とスクリプト作業は **Azure Cloud Shell (Bash)** を標準にし、ローカル PC にはブラウザ以外のツールを原則として要求しません。

## ワークショップ進行 TOC

この表を上から順に進めます。右端のチェックボックスは、受講者が自分の進捗確認に使うための一時的なチェック欄です。

| 順番 | タイミング | ページ | このページで完了すること | 完了 |
|---:|---|---|---|---|
| 1 | 事前確認 | [受講者クイックスタート](learner/learner-quickstart.ja.md) | 教材の読み順と Cloud Shell-first の進め方を理解する | <input type="checkbox" aria-label="受講者クイックスタート完了"> |
| 2 | Day 0 | [Day 0: 事前準備](learner/day-0-prerequisites.ja.md) | Azure Portal、Cloud Shell、Entra ID 権限、クォータ、GitHub リポジトリを確認する | <input type="checkbox" aria-label="Day 0 事前準備完了"> |
| 3 | Day 1 開始 | [Azure Cloud Shell ガイド](learner/azure-cloud-shell-guide.ja.md) | Cloud Shell の起動、clone、ファイル編集、SSH 鍵、証明書生成を確認する | <input type="checkbox" aria-label="Azure Cloud Shell ガイド完了"> |
| 4 | Day 1 本編 | [Day 1: デプロイチェックリスト](learner/day-1-deployment-checklist.ja.md) | Bicep デプロイ、デプロイ後セットアップ、疎通確認、監視確認を完了する | <input type="checkbox" aria-label="Day 1 デプロイチェックリスト完了"> |
| 5 | Day 1 監視 | [監視ガイド](operations/monitoring-guide.ja.md) | Application Gateway、VM Heartbeat、KQL の基本確認を行う | <input type="checkbox" aria-label="監視ガイド完了"> |
| 6 | Day 2 本編 | [Day 2: 回復性チェックリスト](learner/day-2-resiliency-checklist.ja.md) | Backup、Restore、HA 検証、ASR/test failover を安全に進める | <input type="checkbox" aria-label="Day 2 回復性チェックリスト完了"> |
| 7 | Day 2 補足 | [災害復旧ガイド](operations/disaster-recovery-guide.ja.md) | BCDR の背景、安全ルール、期待結果を理解する | <input type="checkbox" aria-label="災害復旧ガイド完了"> |

## 迷ったときの参照 TOC

| 用途 | ページ | いつ見るか | 確認済み |
|---|---|---|---|
| 症状別の切り分け | [トラブルシューティングランブック](operations/troubleshooting-runbook.ja.md) | エラー、失敗、想定外の状態に遭遇したとき | <input type="checkbox" aria-label="トラブルシューティングランブック確認済み"> |
| コマンドと値の確認 | [クイックリファレンス](reference/quick-reference-card.ja.md) | リソース名、ポート、主要コマンド、KQL を素早く確認したいとき | <input type="checkbox" aria-label="クイックリファレンス確認済み"> |
| 認証と権限の背景 | [アイデンティティ、アクセス、シークレットガイド](reference/identity-and-access-guide.ja.md) | Entra ID、RBAC、Managed Identity の関係を確認したいとき | <input type="checkbox" aria-label="アイデンティティガイド確認済み"> |
| Bicep の深掘り | [Bicep テクニックガイド](reference/bicep-techniques-guide.ja.md) | Bicep の構造やパラメータ設計を学びたいとき | <input type="checkbox" aria-label="Bicep テクニックガイド確認済み"> |
| ローカル開発 | [ローカル開発ガイド](development/local-development-guide.ja.md) | アプリケーションを手元で変更・検証したいとき | <input type="checkbox" aria-label="ローカル開発ガイド確認済み"> |

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
