---
title: 受講者クイックスタート
---

# 受講者クイックスタート

## このページでやること

2 日版 Azure IaaS Workshop の進め方を確認し、どの順番で教材を読むかを決めます。このワークショップでは、CLI とスクリプト作業を **Azure Cloud Shell (Bash)** に寄せることで、ローカル PC のプロキシ、証明書、PATH、ツール差分によるつまずきを減らします。

| 項目 | 内容 |
|---|---|
| 対象者 | AWS の経験があり、Azure IaaS、可用性、監視、BCDR を学ぶ受講者 |
| 所要時間 | 5-10 分 |
| 前提 | ブラウザで GitHub と Azure Portal にアクセスできること |
| 完了条件 | Day 0、Cloud Shell、Day 1 のどのページから進めるかを説明できること |

## 学習の流れ

| タイミング | 使うページ | 完了条件 |
|---|---|---|
| 事前または開始直後 | [Day 0: 事前準備](day-0-prerequisites.ja.md) | Azure Portal、Cloud Shell、Entra ID 権限、クォータ、GitHub リポジトリを確認できた |
| Day 1 の最初 | [Azure Cloud Shell ガイド](azure-cloud-shell-guide.ja.md) | Cloud Shell Bash でリポジトリを clone し、ファイルを編集できる |
| Day 1 本編 | [Day 1: デプロイチェックリスト](day-1-deployment-checklist.ja.md) | Bicep デプロイ、デプロイ後セットアップ、疎通確認、監視確認を進められる |
| Day 1 監視演習 | [監視ガイド](monitoring-guide.ja.md) | Log Analytics で基本クエリを実行できる |
| Day 2 本編 | [Day 2: 回復性チェックリスト](day-2-resiliency-checklist.ja.md) | Backup、Restore、障害検証、ASR/test failover を安全に進められる |
| 困ったとき | [トラブルシューティングランブック](troubleshooting-runbook.ja.md) / [クイックリファレンス](quick-reference-card.ja.md) | 症状別の確認と主要コマンドを確認できる |

## このワークショップで標準にする作業場所

| 作業 | 標準 | 理由 |
|---|---|---|
| Azure CLI 実行 | Azure Cloud Shell Bash | Azure 認証済みで、CLI、Git、OpenSSL、SSH が利用できる |
| ファイル編集 | Cloud Shell editor (`code`) | OS やローカルエディタの差分を避ける |
| Entra ID アプリ登録 | Azure Portal | 認証構成を画面で確認する学習効果が高い |
| デプロイ進捗確認 | Azure Portal の Resource group Deployments | Cloud Shell が切断されても状態を確認できる |
| ローカル開発 | 任意 | アプリを変更したい開発者向けで、通常の受講者手順ではない |

## 受講者が準備するもの

- Azure サブスクリプション、または講師から指定されたサブスクリプションへのアクセス
- Microsoft Entra ID でアプリ登録を作成できる権限、または講師から配布されるアプリ登録値
- GitHub アカウント
- ブラウザ

ローカルの Azure CLI、Azure PowerShell、Bicep CLI、OpenSSL、Node.js、Docker は、通常のワークショップ参加には必須ではありません。

## AWS 経験者向けの対応関係

| AWS での考え方 | Azure での対応 |
|---|---|
| VPC | Virtual Network (VNet) |
| Security Group / NACL | Network Security Group (NSG) |
| ALB | Application Gateway |
| NLB | Standard Load Balancer |
| IAM Role / Instance Profile | Azure RBAC / Managed Identity |
| CloudWatch Logs | Azure Monitor / Log Analytics |
| EC2 multi-AZ 配置 | VM の Availability Zone 配置 |

## チェックポイント

- Day 0 で確認する内容を説明できる。
- CLI 作業は Cloud Shell Bash で行うことを理解している。
- ローカル開発ガイドは任意の開発者向け資料であり、Azure デプロイの本線ではないことを理解している。

## 次に進む

[Day 0: 事前準備](day-0-prerequisites.ja.md) に進みます。

迷ったときは [受講者ポータル](index.md) または [トラブルシューティングランブック](troubleshooting-runbook.ja.md) に戻ってください。
