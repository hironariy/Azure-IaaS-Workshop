---
title: "Day 2: 回復性チェックリスト"
---

# Day 2: 回復性チェックリスト

## このページでやること

Day 1 で作成した Azure IaaS 環境を使い、Azure Backup、VM 障害時の HA 挙動、Azure Site Recovery (ASR) の考え方と test failover を確認します。Backup / Restore / ASR は Azure Portal 操作を中心に行い、VM の停止・起動や状態確認は Azure Cloud Shell Bash で行います。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 1 のデプロイと基本動作確認を終えた受講者 |
| 所要時間 | 90-150 分 |
| 前提 | Day 1 環境が稼働中、Application Gateway URL でアプリにアクセス可能、Cloud Shell Bash が利用可能 |
| 完了条件 | バックアップ取得、復元ポイント確認、Web/App/DB 障害検証、ASR の replication/test failover の考え方と安全なクリーンアップを説明できること |

## 安全ルール

- 障害検証は必ず講師の合図に合わせて行います。
- 停止した VM は各演習の最後に必ず起動します。
- Backup / Restore / ASR はコストと時間がかかるため、不要な test failover リソースは演習後に削除します。
- DB VM を停止する前に、アプリのテストデータと現在の正常性を確認します。
- ASR の初回レプリケーションは時間がかかる場合があります。ワークショップ時間内に test failover まで進まない場合は、講師デモまたは設計ウォークスルーに切り替えます。

## 0. 作業変数と Day 1 環境を確認する

Cloud Shell Bash で実行します。

```bash
cd ~/Azure-IaaS-Workshop

RESOURCE_GROUP="rg-blogapp-workshop"
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)

echo "https://$FQDN"
az vm list --resource-group "$RESOURCE_GROUP" -o table
```

**期待結果:** `vm-web-az1-prod`、`vm-web-az2-prod`、`vm-app-az1-prod`、`vm-app-az2-prod`、`vm-db-az1-prod`、`vm-db-az2-prod` が表示されます。

**チェックポイント:** 複数グループ構成の場合も VM 名は同じで、リソースグループ名だけが異なります。すべてのコマンドで `--resource-group "$RESOURCE_GROUP"` を指定してください。

## 1. テストデータを作成する

1. ブラウザで `https://$FQDN` を開きます。
2. 自己署名証明書の警告を通過します。
3. ログインし、テスト用の投稿を 1 件作成します。
4. 投稿タイトル、作成時刻、投稿者をメモします。

**期待結果:** Backup / Restore や障害検証後に比較できるテスト投稿が存在します。

**チェックポイント:** 個人情報や機密情報を投稿本文に入れないでください。

## 2. Recovery Services vault を作成する

Day 1 の Bicep では Recovery Services vault、Azure Backup、ASR は作成していません。Day 2 では Azure Portal で vault を作成します。

1. Azure Portal で **Recovery Services vaults** を検索します。
2. **Create** をクリックします。
3. Subscription と Resource group は Day 1 と同じものを選びます。
4. Vault name は例として `rsv-blogapp-workshop` のようにします。
5. Region は Day 1 の `LOCATION` と同じリージョンを選びます。
6. Review + create で作成します。

**期待結果:** Recovery Services vault が作成されます。

**チェックポイント:** `materials/bicep` の Storage Account にある `backups` container は、Recovery Services vault とは別物です。Azure VM Backup と ASR は Recovery Services vault で操作します。

## 3. Azure Backup を有効化する

1. 作成した Recovery Services vault を開きます。
2. **Backup** を選択します。
3. Workload location は **Azure**、Workload type は **Virtual machine** を選びます。
4. Backup policy はワークショップ用に短い保持期間のポリシーを作成または選択します。
5. 対象 VM を選択します。時間が限られる場合は、講師が指定する代表 VM だけを対象にします。
6. Enable backup を実行します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day2-backup-item.png`
> - Capture target: Recovery Services vault backup item page
> - Purpose: バックアップ対象 VM と backup item の状態確認画面を示す
> - Suggested alt text: Azure Recovery Services vault showing a protected VM backup item
> - Insertion note: Protected item の状態が分かる状態を撮影する
> - Mask: サブスクリプション ID、リソース名に含まれる個人情報、アカウント名、組織名

**期待結果:** 対象 VM が backup item として表示されます。

**チェックポイント:** 初回バックアップが完了するまで時間がかかる場合があります。

## 4. オンデマンドバックアップを取得する

1. Recovery Services vault > Backup items を開きます。
2. 対象 VM を選択します。
3. **Backup now** を実行します。
4. Backup jobs で進捗を確認します。

**期待結果:** Backup job が `Completed` になります。

**チェックポイント:** 失敗した場合は、VM が稼働中か、vault と VM が同じサブスクリプション内にあるか、権限が足りているかを確認します。

## 5. 復元ポイントを確認する

1. 対象 backup item を開きます。
2. **Restore VM** または **Restore points** を開きます。
3. 最新の復元ポイントが表示されることを確認します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day2-restore-point.png`
> - Capture target: VM restore point or restore operation page in Recovery Services vault
> - Purpose: 復元ポイントの存在と復元操作の入口を示す
> - Suggested alt text: Azure Recovery Services vault showing restore points for a protected VM
> - Insertion note: 復元ポイントの日時と操作ボタンが分かる状態を撮影する
> - Mask: サブスクリプション ID、リソース名に含まれる個人情報、アカウント名、組織名

**期待結果:** 復元ポイントが 1 つ以上表示されます。

**チェックポイント:** 本番相当環境では、復元は既存 VM へ上書きせず、新しい VM または別リソースグループへ復元して検証します。

## 6. Restore 操作を確認する

時間と権限に余裕がある場合のみ、講師の指示に従って Restore VM を実行します。時間が限られる場合は、復元ポイントと復元画面の確認をもって演習完了とします。

**期待結果:** 復元先、ネットワーク、ストレージ、VM 名の指定項目を説明できます。

**チェックポイント:** 復元 VM を作成した場合は、演習後に削除対象としてメモします。

## 7. Web VM 障害を検証する

Web tier は Application Gateway の backend pool に 2 台構成で配置されています。1 台を停止し、サービス継続を確認します。

```bash
az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table

az vm stop --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
sleep 90

curl -k "https://$FQDN/"

az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table

az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
```

**期待結果:** 片方の Web VM が停止しても、アプリケーションはもう片方の Web VM 経由で応答します。

**チェックポイント:** `az vm stop` は VM のゲスト OS 停止を模擬します。`az vm deallocate` は割り当て解除まで行うため、演習では講師の指示がない限り使いません。

## 8. App VM 障害を検証する

App tier は内部 Load Balancer の背後に 2 台構成で配置されています。

```bash
az vm stop --resource-group "$RESOURCE_GROUP" --name vm-app-az1-prod
sleep 90

curl -k "https://$FQDN/api/posts"

az vm start --resource-group "$RESOURCE_GROUP" --name vm-app-az1-prod
```

**期待結果:** 片方の App VM が停止しても、API はもう片方の App VM 経由で応答します。

**チェックポイント:** API 応答が不安定な場合は、数分待ってから再試行し、Application Gateway backend health と App VM の起動状態を確認します。

## 9. DB VM 障害を検証する

DB tier は MongoDB レプリカセットです。片方の DB VM を停止し、primary 再選出とアプリの影響を観察します。

```bash
az vm stop --resource-group "$RESOURCE_GROUP" --name vm-db-az1-prod
sleep 120

curl -k "https://$FQDN/api/posts"

az vm start --resource-group "$RESOURCE_GROUP" --name vm-db-az1-prod
```

**期待結果:** レプリカセットの primary が切り替わり、復旧後にアプリケーションが再び安定します。

**チェックポイント:** DB VM 障害は Web/App より影響が大きく、短時間の書き込み失敗が発生する可能性があります。演習後は必ず両方の DB VM が running になっていることを確認してください。

## 10. VM がすべて running に戻ったことを確認する

```bash
az vm list \
  --resource-group "$RESOURCE_GROUP" \
  --show-details \
  --query "[].{name:name,powerState:powerState}" \
  -o table
```

**期待結果:** 6 台すべてが `VM running` です。

**チェックポイント:** 停止した VM がある場合は、次のコマンドで起動します。

```bash
az vm start --resource-group "$RESOURCE_GROUP" --name <VM_NAME>
```

## 11. ASR レプリケーションを有効化する

ASR は時間がかかるため、講師デモまたは代表 VM での演習にする場合があります。

1. Recovery Services vault を開きます。
2. **Site Recovery** を開きます。
3. **Enable replication** を選択します。
4. Source は Day 1 のリソースグループとリージョンを選びます。
5. Target region は講師指定のリージョンを選びます。
6. ターゲット VNet / subnet のマッピングを確認します。
7. 代表 VM または講師指定の VM を選択します。
8. Enable replication を実行します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day2-asr-replication-health.png`
> - Capture target: Site Recovery replicated items page showing replication health
> - Purpose: ASR の replication health の確認場所を示す
> - Suggested alt text: Azure Site Recovery replicated items page showing replication health
> - Insertion note: Replication health と status が分かる状態を撮影する
> - Mask: サブスクリプション ID、リソース名に含まれる個人情報、アカウント名、組織名

**期待結果:** Replicated item が作成され、initial replication が開始または完了します。

**チェックポイント:** 初回レプリケーションが完了しない場合、test failover は講師デモまたは設計ウォークスルーに切り替えます。

## 12. Test failover を確認する

Test failover は本番側に影響しない分離ネットワークで行います。

1. Replicated item または Recovery Plan を開きます。
2. **Test failover** を選択します。
3. 復旧ポイントとテスト用 VNet を選択します。
4. Test failover を開始します。
5. 起動したテスト VM とネットワークを確認します。
6. 検証後、**Cleanup test failover** を実行します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/day2-asr-test-failover.png`
> - Capture target: Azure Site Recovery test failover confirmation or job page
> - Purpose: Test failover の実行確認画面とジョブ状態を示す
> - Suggested alt text: Azure Site Recovery test failover job page
> - Insertion note: Test failover の状態と cleanup 操作の入口が分かる状態を撮影する
> - Mask: サブスクリプション ID、リソース名に含まれる個人情報、アカウント名、組織名

**期待結果:** Test failover の流れと、本番影響を避けるための分離ネットワークの意味を説明できます。

**チェックポイント:** Cleanup test failover を実行しないと、不要なテストリソースが残り課金や混乱の原因になります。

## Day 2 完了条件

- Recovery Services vault を作成できた。
- 対象 VM の Backup を有効化し、復元ポイントを確認できた。
- Web VM 停止時の HA 挙動を確認し、VM を起動状態へ戻した。
- App VM 停止時の HA 挙動を確認し、VM を起動状態へ戻した。
- DB VM 停止時の影響と復旧の考え方を確認し、DB VM を起動状態へ戻した。
- ASR の replication health と test failover の考え方を説明できた。
- Test failover を実施した場合は、cleanup が完了している。
- 6 台の VM がすべて `VM running` である。

## 迷ったとき

- 症状別の確認は [トラブルシューティングランブック](troubleshooting-runbook.ja.md) を参照します。
- コマンドとリソース名は [クイックリファレンス](quick-reference-card.ja.md) を参照します。
- BCDR の背景説明は [災害復旧ガイド](disaster-recovery-guide.ja.md) を参照します。

前のページ: [Day 1: デプロイチェックリスト](day-1-deployment-checklist.ja.md)  
戻る: [受講者ポータル](index.md)
