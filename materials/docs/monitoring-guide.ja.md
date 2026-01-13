# 監視ガイド（Azure Monitor + Log Analytics）

このガイドでは、ワークショップ環境を観測・トラブルシュートするために次を利用する方法を説明します。
- **Azure Monitor**（メトリック + プラットフォームログ）
- **Log Analytics**（KQL によるログクエリ）

## 対象範囲

- **インフラ**: Application Gateway、Load Balancer、VM（NGINX/Web + Node/App + MongoDB/DB）
- **目的**: 「稼働しているか？」「どこが遅いか？」「何が失敗したか？」を素早く答えられるようにする

> 注: 監視の一部は Bicep による IaC 化が「planned」になっている場合があります。本ガイドは、ワークショップを進行できるようにするための実用的な手動設定手順にフォーカスします。

---

## 1. Log Analytics ワークスペースを作成（または再利用）する

1. Azure portal で **Log Analytics workspaces** を検索します。
2. 主要なデプロイ先と同じリージョンにワークスペースを作成します（推奨）。
3. 例: `law-blogapp-dev` のように環境サフィックス付きで命名します。

**AWS との類比:** Log Analytics ワークスペースは、集中管理された CloudWatch Logs の集約先 + クエリレイヤーに概念的に近いものです。

---

## 2. プラットフォーム診断ログを Log Analytics に送る

### 2.1 Application Gateway の診断

診断を有効化して、次をクエリできるようにします。
- アクセスログ（誰が/何を/レイテンシ）
- パフォーマンスログ
- ファイアウォールログ（WAF を使用している場合）

手順（portal）:
1. **Application Gateway** リソースを開きます。
2. **Diagnostic settings** に移動します。
3. ログを **Log Analytics workspace** に送る診断設定を作成します。
4. 関連カテゴリ（Access/Performance）を選択します。

### 2.2 Load Balancer の診断（該当する場合）

Load Balancer のメトリック/診断に依存する場合:
1. **Load Balancer** リソースを開きます。
2. 同様に診断を設定し、同じワークスペースに送信します。

---

## 3. VM のログとパフォーマンスデータを収集する

VM 監視には、一般的に次の 2 段階があります。

### 3.1 ベースライン: Metrics + Activity Log

- 各 VM の **Metrics** で CPU / ディスク / ネットワークを確認します。
- **Activity Log** で制御プレーン操作（start/stop, redeploy, updates）を追跡します。

これはすぐ使えますが、OS ログは含まれません。

### 3.2 推奨: VM Insights（パフォーマンス + 依存関係ビュー）

1. Azure portal で **Virtual Machines** を検索します。
2. VM を選び、**Insights** を開きます。
3. Insights を有効化し、出力先を **Log Analytics workspace** に設定します。

Web/App/DB VM について繰り返します。

---

## 4. ワークショップ中に見るべきポイント

### 4.1 「サービスは稼働しているか？」

- Application Gateway のバックエンド正常性
- VM 状態（稼働中、ブート診断）
- Load Balancer のヘルスプローブ状態

### 4.2 「なぜ遅いのか？」

- App Gateway のアクセスログ: リクエスト時間とバックエンド応答時間
- VM CPU（web/app）とディスクレイテンシ（db）
- MongoDB のパフォーマンスカウンタ（エクスポートしている場合）

### 4.3 「何が失敗したのか？」

- App Gateway ログ: 4xx/5xx の傾向
- VM 上の Node/NGINX のサービスログ
- OS の syslog / Windows Event logs（イメージに依存）

---

## 5. Log Analytics: KQL クエリ例（導入用）

> ここでは意図的に汎用的な例を示します。実際のテーブルは有効化した診断/エージェントによって異なります。

### 5.1 直近イベントの表示（疎通確認）

```kusto
search *
| take 50
```

### 5.2 HTTP 5xx エラーの検索（gateway）

```kusto
search " 500 "
| take 100
```

### 5.3 VM のハートビート / エージェント有効性

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

---

## 6. 運用のコツ（ワークショップ向け）

- 1 学習環境（学生環境）につき **ワークスペースは 1 つ** にして、クエリを簡単にします。
- 診断設定名は一貫させます（例: `to-law-blogapp`）。
- 調査時は、外側（**Application Gateway**）から内側（web → app → db）へ順に追います。

---

## 7. 次のステップ（任意）

- Azure Monitor の **アラート** を追加（HTTP 5xx 率、バックエンド異常、VM CPU 高騰など）
- Bicep で **診断設定を IaC 化** し、環境の観測性を一貫させる
