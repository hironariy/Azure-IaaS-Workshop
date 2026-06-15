---
title: "Markdown 版 受講者ポータル"
---

# Markdown 版 受講者ポータル

このページは、GitHub 上で Markdown として読むための受講者向け入口です。GitHub Pages 版の [受講者ポータル](https://hironariy.github.io/Azure-IaaS-Workshop/) が使える場合はそちらを優先し、Pages が未設定のコピーリポジトリや、GitHub 上で教材を直接読む場合はこのページから進めてください。

CLI とスクリプト作業は **Azure Cloud Shell (Bash)** を標準にします。通常のワークショップ参加では、ローカル PC に Azure CLI、Bicep CLI、OpenSSL、Node.js、Docker をインストールする必要はありません。

## 進め方

上から順にページを開き、各ページのチェックポイントを確認しながら進めます。困ったときは、下部の参照 TOC からトラブルシューティングやクイックリファレンスを開いてください。

## ワークショップ進行 TOC

- [ ] **1. 受講者クイックスタート**: [教材の読み順と全体像を確認する](learner/learner-quickstart.ja.md)
- [ ] **2. Day 0: 事前準備**: [Azure Portal、Cloud Shell、Entra ID、クォータ、GitHub リポジトリを確認する](learner/day-0-prerequisites.ja.md)
- [ ] **3. Day 1: Azure リソースデプロイ**: [Cloud Shell 準備、Bicep デプロイ、デプロイ後セットアップ、DCR 構成、FQDN 取得を進める](learner/day-1-deployment-checklist.ja.md)
- [ ] **4. Day 1: アプリデプロイ**: [App VM / Web VM にアプリケーションコードを手作業で配置し、疎通確認する](learner/day-1-app-deployment.ja.md)
- [ ] **5. 監視ガイド**: [Azure Monitor と Log Analytics でメトリックとログを確認する](operations/monitoring-guide.ja.md)
- [ ] **6. Day 2: 回復性チェックリスト**: [Backup、Restore、障害検証、ASR / test failover を安全に進める](learner/day-2-resiliency-checklist.ja.md)
- [ ] **7. 災害復旧ガイド**: [BCDR の考え方、安全ルール、期待結果を確認する](operations/disaster-recovery-guide.ja.md)

## 迷ったときの参照 TOC

| 目的 | ページ | 使う場面 |
|---|---|---|
| Cloud Shell の基本だけ確認 | [Azure Cloud Shell ミニガイド](learner/azure-cloud-shell-guide.ja.md) | Bash の起動、サブスクリプション確認、Cloud Shell editor の使い方を確認したいとき |
| 症状別の切り分け | [トラブルシューティングランブック](operations/troubleshooting-runbook.ja.md) | デプロイ、Bastion SSH、アプリ疎通、監視などで詰まったとき |
| コマンドと値の確認 | [クイックリファレンス](reference/quick-reference-card.ja.md) | リソース名、主要コマンド、KQL、ポート番号をすぐ確認したいとき |
| 認証と権限の背景 | [Identity / Access](reference/identity-and-access-guide.ja.md) | Entra ID、RBAC、Managed Identity の関係を整理したいとき |
| Bicep の深掘り | [Bicep テクニック](reference/bicep-techniques-guide.ja.md) | Bicep テンプレートの構造や設計意図を理解したいとき |
| ローカル開発 | [ローカル開発ガイド](development/local-development-guide.ja.md) | 教材やアプリケーションを保守・拡張する開発者向け。通常の受講者手順では不要です |

## 作業場所の整理

| 作業 | 標準 | 補足 |
|---|---|---|
| Azure CLI 実行 | Azure Cloud Shell Bash | Azure 認証済みで、Git、OpenSSL、SSH も利用できます |
| ファイル編集 | Cloud Shell editor (`code`) | OS やローカルエディタ差分を避けます |
| Entra ID アプリ登録 | Azure Portal | 画面で認証構成を確認しながら進めます |
| デプロイ進捗確認 | Azure Portal の Resource group Deployments | Cloud Shell が切断されても状態を確認できます |
| アプリケーション配置 | Azure Bastion SSH | App VM / Web VM に入り、clone、build、start、deploy を手作業で進めます |

## 次に進む

最初に [受講者クイックスタート](learner/learner-quickstart.ja.md) を開き、ワークショップ全体の進め方を確認してください。