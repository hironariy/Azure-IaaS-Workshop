---
title: 災害復旧ガイド
---

# BCDR ガイド（Azure Backup + Azure Site Recovery）

## このページでやること

Day 2 の Backup、Restore、HA 検証、Azure Site Recovery (ASR) の背景を理解します。実際の手順は [Day 2: 回復性チェックリスト](../learner/day-2-resiliency-checklist.ja.md) を主線とし、このページでは判断理由、安全ルール、期待結果を補足します。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 2 の BCDR 演習を進める受講者 |
| 所要時間 | 20-30 分 |
| 前提 | Day 1 環境が稼働し、Recovery Services vault を作成できる権限があること |
| 完了条件 | Backup と ASR の役割、test failover の安全な進め方、DB 層の注意点を説明できること |

## 1. BCDR の基本方針

| 目的 | 使う Azure サービス | AWS との類比 |
|---|---|---|
| ポイントインタイム復旧 | Azure Backup | AWS Backup |
| VM のリージョン DR | Azure Site Recovery | EC2 レプリケーション + DR オーケストレーションに近い |
| 障害検知と確認 | Azure Monitor / Log Analytics | CloudWatch |
| トラフィック入口の正常性 | Application Gateway | ALB target health |

このワークショップでは、Azure IaaS の学習に集中するため、Backup / Restore / ASR は Portal で状態を見ながら進めます。CLI は VM 停止・起動や状態確認に使います。

## 2. Day 2 の安全ルール

- Day 1 の正常状態を確認してから障害検証を始めます。
- Web / App / DB VM を停止したら、同じ演習内で必ず起動します。
- Restore は既存 VM を上書きせず、新しい VM または別リソースグループへの復元として扱います。
- ASR test failover は分離ネットワークで実行します。
- Test failover 後は必ず cleanup を実行します。
- ASR 初回レプリケーションが長引く場合は、講師デモまたは設計ウォークスルーへ切り替えます。

## 3. Azure Backup の考え方

Azure Backup は、VM やデータの復元ポイントを作成するためのサービスです。Day 1 の Bicep は Recovery Services vault を作成しないため、Day 2 で vault と backup item を Portal から作成します。

### ワークショップで確認すること

1. Recovery Services vault を作成する。
2. VM Backup を有効化する。
3. Backup now を実行する。
4. Restore point を確認する。
5. Restore VM の入力項目と影響範囲を理解する。

**期待結果:** 復元ポイントが存在し、復元先やネットワークを選ぶ必要があることを説明できます。

**チェックポイント:** 復元 VM を実際に作成した場合は、削除対象として必ずメモします。

## 4. VM 障害と HA の考え方

| Tier | 構成 | 期待する挙動 |
|---|---|---|
| Web | 2 VM + Application Gateway | 1 台停止しても正常 VM へルーティング |
| App | 2 VM + Internal Load Balancer | 1 台停止しても API が継続または短時間で復旧 |
| DB | 2 VM + MongoDB replica set | primary 再選出により復旧。ただし一時的な失敗が起こり得る |

DB tier はステートフルであり、Web/App tier よりも停止の影響が大きくなります。演習では、停止、観測、起動、復旧確認を 1 セットで行います。

## 5. Azure Site Recovery の考え方

ASR は VM を別リージョンへレプリケートし、災害時の failover を支援します。

### ワークショップで確認すること

1. Recovery Services vault の Site Recovery を開く。
2. Enable replication で対象 VM とターゲットリージョンを選ぶ。
3. Replicated items で replication health を確認する。
4. 初回レプリケーション完了後、分離ネットワークへ test failover する。
5. 検証後、cleanup test failover を実行する。

**期待結果:** レプリケーションの状態と、test failover を始められる条件を説明できます。

## 6. Test failover と本番 failover の違い

| 操作 | 用途 | 本番影響 |
|---|---|---|
| Test failover | DR 手順の検証 | 分離ネットワークを使えば本番影響を避けられる |
| Planned failover | ソースが健全な状態で計画的に切り替える | 影響あり。事前調整が必要 |
| Unplanned failover | 障害時に切り替える | 影響あり。データ損失や復旧順序に注意 |

ワークショップでは、原則として test failover を扱います。Planned / unplanned failover は設計理解として扱います。

## 7. DB 層の注意点

MongoDB レプリカセットはゾーン障害には有効ですが、リージョン DR では追加の設計が必要です。

- DB VM を ASR 対象にする場合、Recovery Plan で DB を先に起動します。
- フェールオーバー後、MongoDB replica set の primary と接続文字列を確認します。
- 単一リージョン前提の replica set をそのまま別リージョンへ広げる設計は上級トピックとして扱います。
- ワークショップ時間内では、DB の復旧は Azure Backup の Restore と、単一 VM 停止時の replica set 挙動確認を中心にします。

## 8. 成功条件

- Recovery Services vault と backup item の役割を説明できる。
- Restore point が何を意味するか説明できる。
- Web/App/DB VM 停止時の期待挙動を区別できる。
- ASR replication health と test failover の意味を説明できる。
- Test failover 後の cleanup が必要な理由を説明できる。
- Day 2 終了時に VM と test failover リソースの状態を確認できる。

## 迷ったとき

- 実行手順は [Day 2: 回復性チェックリスト](../learner/day-2-resiliency-checklist.ja.md) を参照します。
- 症状別の切り分けは [トラブルシューティングランブック](troubleshooting-runbook.ja.md) を参照します。
- コマンドは [クイックリファレンス](../reference/quick-reference-card.ja.md) を参照します。

戻る: [受講者ポータル](../index.md)
