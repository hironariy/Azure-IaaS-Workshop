---
title: トラブルシューティングランブック
---

# トラブルシューティングランブック

## このページでやること

ワークショップ中に起きやすい問題を、症状から確認箇所、対処へ順番に切り分けます。調査は原則として外側から内側へ、つまり Application Gateway、Web tier、App tier、DB tier の順に進めます。

| 項目 | 内容 |
|---|---|
| 対象者 | Day 1 / Day 2 の演習でエラーや想定外の状態に遭遇した受講者 |
| 所要時間 | 症状ごとに 5-15 分 |
| 前提 | Cloud Shell Bash、対象リソースグループ名、Application Gateway FQDN |
| 完了条件 | 症状に対して、どの層を確認すべきか説明し、次の確認コマンドまたは Portal 画面に進めること |

## 最初に設定する変数

```bash
RESOURCE_GROUP="rg-blogapp-workshop"
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv 2>/dev/null || true)
```

複数グループ構成の場合は、講師から指定されたリソースグループ名に置き換えます。

## 切り分けの基本順序

1. **入口:** Application Gateway の URL に到達できるか。
2. **Web tier:** Web VM と NGINX が応答しているか。
3. **App tier:** App VM と Express API が応答しているか。
4. **DB tier:** MongoDB レプリカセットと接続文字列が正常か。
5. **認証:** Entra ID アプリ登録、API permission、redirect URI が正しいか。
6. **監視:** Log Analytics に Heartbeat / Perf / Syslog が入っているか。

## 1. Bicep deployment が失敗した

| 確認すること | コマンドまたは画面 |
|---|---|
| 失敗した deployment operation | Azure Portal > Resource group > Deployments > failed deployment |
| CLI のエラー詳細 | `az deployment operation group list --resource-group "$RESOURCE_GROUP" --name main -o table` |
| VM SKU availability | `az vm list-skus --location japanwest --size Standard_D2s_v6 --zone -o table` と `az vm list-skus --location japanwest --size Standard_D4s_v6 --zone -o table` |
| DNS label 重複 | `appGatewayDnsLabel` を別の一意な値に変更 |
| パラメータ未設定 | `materials/bicep/main.local.bicepparam` の空文字を確認 |

**よくある対処:**

- `QuotaExceeded`: Day 0 のクォータ確認に戻り、講師へ相談します。
- `DnsRecordInUse`: `appGatewayDnsLabel` にランダムな suffix を追加します。
- `InvalidTemplate` / `InvalidParameter`: `main.local.bicepparam` の引用符、空値、貼り付けた証明書データを確認します。
- `SkuNotAvailable`: `webVmSize`、`appVmSize`、`dbVmSize` を利用可能な代替 SKU に変更します。

> [!TODO] スクリーンショットを挿入
> - Image path: `assets/screenshots/troubleshooting-deployment-failure.png`
> - Capture target: Resource group deployment error details page
> - Purpose: デプロイ失敗時に error details を確認する場所を示す
> - Suggested alt text: Azure deployment error details page in a resource group
> - Insertion note: エラーメッセージの構造が分かる状態を撮影する。実 ID はマスクする
> - Mask: サブスクリプション ID、テナント ID、リソース名に含まれる個人情報、アカウント名

## 2. クォータ不足で VM が作れない

```bash
az vm list-usage --location japanwest \
  --query "[?contains(name.value, 'DSv6') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

**判断:** このワークショップでは Dsv6 シリーズで合計 20 vCPU（DB VM 3 台分を含む）が必要です。DB VM は Zone 1/2/3 に 1 台ずつ配置するため、DB の SKU が 3 つのゾーンすべてで利用できる必要があります。ファミリーとリージョン全体の両方の残量（Limit - Current）を確認します。クォータが足りても実際のゾーン内キャパシティが不足する場合があります。詳細は Day 0 のクォータ確認を参照してください。

**対処:**

1. 講師に不足している quota 名と現在値を共有します。
2. 別リージョンへ切り替えるか、クォータ増加申請を行います。
3. 講師が許可した場合のみ、`main.local.bicepparam` の VM size を代替 SKU に変更します。

## 3. Entra ID アプリ登録を作成できない

**症状:**

- App registrations の **New registration** が押せない。
- 権限エラーが表示される。

**確認すること:**

- 自分が正しいテナントにいるか。
- テナントで「ユーザーはアプリケーションを登録できる」が許可されているか。
- アプリケーション開発者、クラウドアプリケーション管理者、グローバル管理者のいずれかのロールがあるか。

**対処:**

- 講師に相談し、事前作成された Frontend SPA Client ID、Backend API Client ID、Tenant ID を受け取ります。
- 受け取った値を `main.local.bicepparam` に設定します。

## 4. ログインまたは API 呼び出しが認証エラーになる

| 症状 | 確認すること | 対処 |
|---|---|---|
| `AADSTS9002326` | フロントエンドアプリの platform が SPA か | Authentication で SPA redirect URI を設定し、Web platform を使わない |
| redirect URI mismatch | `https://<FQDN>` と `https://<FQDN>/` が登録済みか | フロントエンド SPA の redirect URI に追加 |
| API 403 / invalid audience | backend API の Client ID と scope | `entraClientId` と API permission を確認 |
| consent required | API permission の同意状態 | 管理者が必要な場合は講師へ相談 |

**確認先:** Azure Portal > Microsoft Entra ID > App registrations

## 5. Application Gateway が 502 / 503 を返す

まず backend health を確認します。

```bash
az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

**確認すること:**

- Web VM が running か。
- NGINX が起動しているか。
- NSG で Application Gateway subnet から Web subnet への通信が許可されているか。
- 証明書警告をブラウザ側で通過しているか。

Portal での確認は Day 1 の backend health プレースホルダと同じ画面です。

**対処例:**

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[].{name:name,powerState:powerState}" -o table

az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az1-prod
az vm start --resource-group "$RESOURCE_GROUP" --name vm-web-az2-prod
```

## 6. API は動かないが Web 画面は表示される

**確認すること:**

- App VM が running か。
- 内部 Load Balancer の backend が正常か。
- App VM の Node.js / PM2 プロセスが起動しているか。
- `mongoDbAppPassword` と post-deployment script の `APP_PASSWORD` が一致しているか。

**Cloud Shell での初期確認:**

```bash
curl -k "https://$FQDN/api/posts"
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?contains(name, 'vm-app')].{name:name,powerState:powerState}" -o table
```

**対処:** App VM が停止している場合は起動します。MongoDB 接続エラーが疑われる場合は、post-deployment setup のパスワード同期を確認します。

## 7. DB connection timeout が発生する

**確認すること:**

- DB VM 3 台（`vm-db-az1/az2/az3-prod`）が running か。2 台以上止まると過半数を失い、Primary が存在しなくなります。
- MongoDB レプリカセットの primary が存在するか（`rs.status()` で PRIMARY 1 台 + SECONDARY 2 台）。
- App subnet から DB subnet の 27017/TCP が許可されているか。
- post-deployment setup が完了しているか。

```bash
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[?contains(name, 'vm-db')].{name:name,powerState:powerState}" -o table
```

**対処:**

- DB VM が停止していれば起動します。
- Day 1 の post-deployment setup を再確認します。
- パスワード不一致が疑われる場合は `main.local.bicepparam` と `post-deployment-setup.local.sh` の値を照合します。
- `mongoDbAppPassword` に `@` を含めた場合、Bicep が作成する `MONGODB_URI` の user info 区切りとして解釈され、接続文字列が壊れます。この教材では password を作り直し、`main.local.bicepparam` と `post-deployment-setup.local.sh` を同じ値にそろえてから再実行します。
- API のログに `ECONNREFUSED` / `ReplicaSetNoPrimary` が出る場合は 7.1 を確認します。
- Issue #30 以前に作成した 2 ノード環境で、post-deployment setup が `vm-db-az3-prod` が見つからない、またはメンバー数が 3 未満と警告する場合は 7.2 を実施します。

### 7.1 MongoDB が起動しない: Linux カーネル 6.19 以上 (Issue #26)

**症状:**

- PM2 の `blogapp-api` が再起動を繰り返し、次のようなログが出ます。

  ```text
  MongooseServerSelectionError: connect ECONNREFUSED 10.0.3.4:27017
  ReplicaSetNoPrimary
  servers: 10.0.3.4:27017 = Unknown, 10.0.3.5:27017 = Unknown, 10.0.3.6:27017 = Unknown
  ```

- DB VM 上で `mongod.service` が `failed` になり、27017 で待ち受けていません。
- `post-deployment-setup` が Step 2 で `MongoDB is not ready after ...s` を出して停止します。

**原因:**

MongoDB 8.0.x は TCMalloc / rseq の互換性問題により、Linux カーネル 6.19 以上では起動を拒否します（[SERVER-121912](https://jira.mongodb.org/browse/SERVER-121912)）。Ubuntu 24.04 の Azure イメージは *ローリング* の `linux-azure` カーネルを追従しており、[7.0 に切り替わりました](https://discourse.ubuntu.com/t/kernel-7-0-is-now-the-default-for-ubuntu-24-04-lts-on-azure/88459)。この教材では DB VM を Ubuntu の *長期* Azure カーネルトラック `linux-azure-lts-24.04`（6.8.x、セキュリティ更新は継続）に固定して対処します。新規デプロイでは自動的にこの構成になります。修正前に作成した DB VM は、下記の移行手順を実施します。

> **AWS との比較:** EC2 上の DB ホストで、最新ではなく特定の Amazon Linux カーネル系列に留める判断と同じです。Amazon DocumentDB や RDS ではホスト OS を AWS が管理し、カーネルとエンジンの組み合わせを保証するため、この問題は表に出ません。IaaS VM では利用者がこの責任を持ちます。

**確認（各 DB VM 内で実行）:**

```bash
uname -r                                   # 6.8.x なら OK、6.19 以上 / 7.x は非互換
dpkg-query -W mongodb-org-server           # 8.0.x
sudo systemctl status mongod --no-pager -l
sudo journalctl -u mongod -b --no-pager | grep -iE "kernel|SERVER-121912|blogapp-kernel-track"
sudo ss -lntp '( sport = :27017 )'
sudo blogapp-kernel-track status           # 修正後にデプロイした DB VM に存在します
```

MongoDB のエラーは `MongoDB cannot start: Linux kernel versions 6.19 and newer has a known incompatibility with this version of MongoDB.` です。修正後にデプロイした VM では、その前にガードが `mongod 8.0.x cannot run on kernel ...` を出力します。

`uname -r` が 6.8.x ではなく、`blogapp-kernel-track status` が `finalize : pending` を示す場合は、初回起動時の切り替え中です。3〜5 分待ってから再確認します。

**対処: 既存の DB VM を LTS カーネルトラックへ移行する（推奨）**

DB VM は 1 台ずつ、**`vm-db-az3-prod` → `vm-db-az2-prod` → `vm-db-az1-prod`（通常は Primary）の順** に実施します。2 ノード環境の場合は az3 を飛ばします。Cloud Shell でリポジトリのルートから実行します。ヘルパーは次の処理を行います。

1. `linux-azure-lts-24.04` をインストールする
2. ローリングカーネルのメタパッケージを削除する
3. apt pin を書き込む
4. GRUB で 6.8 カーネルを選択し、1 分後に VM を再起動する
5. 再起動後、LTS 以外のカーネルを削除する

MongoDB のデータとレプリカセット構成は変更しません。

```bash
cd ~/Azure-IaaS-Workshop
az vm run-command invoke -g "$RESOURCE_GROUP" -n vm-db-az2-prod \
  --command-id RunShellScript \
  --scripts @materials/bicep/modules/compute/scripts/mongodb-kernel-track.sh \
  --parameters migrate
```

- Run Command は VM の再起動（約 1 分後）の **前に** 戻ります。出力は約 4 KB で切り詰められるため、結果は下記の確認コマンドで判断します。
- 対象 VM が既に 6.8.x で起動している場合、ヘルパーは再起動せずに後処理（finalize）だけを行います。このとき mongod が停止したままなら、`sudo systemctl restart mongod` で起動します。
- 修正前のヘルパー（2026-10 以前のリポジトリ）で移行した VM で、mongod が `this subcommand must run as root` を出して起動しない場合は、最新のリポジトリで同じ `migrate` を再実行してから `sudo systemctl restart mongod` を実行します（Issue #31）この VM では、インストール済みのヘルパーが常に `migrate` を実行するため、`sudo blogapp-kernel-track status` は使わずに再実行してください。
- Run Command が長時間（10 分以上）戻らない場合は、拡張機能（Azure Policy で配布される `MDE.Linux` など）の処理待ちの可能性があります。`az vm extension list -g "$RESOURCE_GROUP" --vm-name <VM 名> -o table` で状態を確認し、Bastion SSH でヘルパーを VM にコピーして `sudo bash mongodb-kernel-track.sh migrate` を実行します。

3〜5 分待ってから、Bastion SSH で対象の DB VM を確認します。

```bash
uname -r                                        # 6.8.x
findmnt --mountpoint /data/mongodb
sudo systemctl is-active mongod                 # active
mongosh --quiet --eval 'db.hello().isWritablePrimary + " " + db.hello().secondary'
sudo blogapp-kernel-track status                # finalize : done/not-needed
```

レプリカセットの状態も確認します: `mongosh --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr)'`。対象が `SECONDARY` として復帰したことを確認してから、次の VM で同じ手順を繰り返します。Primary（通常 `vm-db-az1-prod`）は最後に実施し、計画的に切り替える場合は下記の注意どおり `rs.stepDown(300)` を実行します。

> **3 ノード構成での影響:** 1 台ずつ再起動する限り、残り 2 台で過半数（3 票中 2 票）を維持するため、API は動き続けます。Primary の VM では、Run Command が戻った直後（再起動の約 1 分前）に、Primary 上で `rs.stepDown(300)` を実行します。既定の 60 秒では再起動の前に期限が切れ、priority 2 の az1 が Primary に戻ってしまいます。正常なシャットダウンでは mongod が自分で Primary を引き渡すため、選出は通常数秒で終わります。**2 台を同時に再起動しないでください**（過半数を失い、Primary が存在しなくなります）。
>
> **旧 2 ノード構成の注意:** Issue #30 以前の 2 ノード環境では、1 台の再起動中に残り 1 台では過半数を維持できないため、**数分間 Primary が存在せず** API の書き込みが失敗します。`rs.stepDown()` を実行しても停止時間は短くならないため不要です。7.2 で 3 ノード構成へ移行することを推奨します。

下記の暫定回避策を使っていた場合でも、ヘルパーの `/etc/default/grub.d/99-blogapp-kernel-track.cfg` がそれを上書きします。移行後は `/etc/default/grub` の `GRUB_DEFAULT` を `0` に戻し、`sudo update-grub` を実行して設定を整理します。

**暫定回避策: インストール済みの旧カーネルで起動する（移行を実行できない場合のみ）**

6.19 未満の旧カーネル（例: `6.17.0-1022-azure`）が残っている場合は、GRUB でそのカーネルを起動できます。これは **短期の回避策** で、後で必ず LTS トラックへ移行します。事前にバックアップ／スナップショットを取得し、カーネルやデータディスクは削除しません。

```bash
uname -r
ls -l /boot/vmlinuz-6.17.0-1022-azure /boot/initrd.img-6.17.0-1022-azure
ls -ld /lib/modules/6.17.0-1022-azure
sudo grep -E '^[[:space:]]*(submenu|menuentry) ' /boot/grub/grub.cfg   # 実際のメニュー名を確認
grep -rn GRUB_DEFAULT /etc/default/grub /etc/default/grub.d/ 2>/dev/null
```

確認したメニュー名を使って `/etc/default/grub` に次を設定し、`/etc/default/grub.d/` で上書きされていないことを確認します。

```text
GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 6.17.0-1022-azure"
```

```bash
sudo update-grub
sudo grub-script-check /boot/grub/grub.cfg && echo OK
sudo reboot
```

Secondary（az3、az2）から復旧し、最後に Primary（通常 az1）を復旧します。

- `/boot/grub/grub.cfg` は直接編集しません。
- データの再フォーマット、MongoDB のダウングレード、`rs.initiate()` の再実行はしません。
- MongoDB の起動チェックを無効化しません。
- `/data/mongodb` がマウントされていない場合は、mongod を手動で起動しません。

**MongoDB が Linux 6.19 以上に対応したら:** その組み合わせを検証してから固定を解除します。

1. `/etc/apt/preferences.d/blogapp-mongodb-kernel-track` を削除する
2. ガード `/etc/systemd/system/mongod.service.d/10-blogapp-kernel-guard.conf` を削除する
3. `sudo systemctl daemon-reload` を実行する
4. `linux-azure` をインストールする
5. DB VM を 1 台ずつ再起動する

### 7.2 既存の 2 ノード環境を 3 ノードへ移行する (Issue #30)

**対象:** Issue #30 より前にデプロイし、`vm-db-az1-prod` と `vm-db-az2-prod` の 2 台だけで MongoDB レプリカセットを構成している環境です。

**なぜ移行するか:** 2 ノード構成では、どちらか 1 台が止まると残り 1 台は 2 票中 1 票しか持たず、過半数を満たせません。そのため Primary を自動選出できず、手動の強制再構成が必要でした。3 台のデータ保持メンバー（PSS）にすると、どの 1 台が止まっても残り 2 台で自動選出でき、`w=majority` の書き込みも続きます。

> **AWS との比較:** EC2 上の自己管理 MongoDB で、2 AZ 構成に 3 つ目の AZ のインスタンスを足すのと同じ作業です。Amazon DocumentDB ではレプリカインスタンスを追加するだけですが、ここではメンバー追加、初期同期の待機、接続文字列の更新を自分で行います。

**方針:** オンラインで 1 台を追加します（`rs.add()`）。`rs.reconfig({force: true})` やレプリカセットの再作成、既存データの再初期化は **行いません**。

**コストとクォータ:** 受講者 1 人あたり、`Standard_D4s_v6` 1 台（+4 vCPU）、128 GB Premium SSD 1 本、OS ディスク 1 本が増えます。

#### 手順 1: バックアップを取得する

どちらかを実施します。

- Azure Backup を構成済みの場合: `vm-db-az1-prod` と `vm-db-az2-prod` で **Backup now** を実行し、完了を確認します。
- 構成していない場合: 両 DB VM のデータディスクのスナップショットを作成します。

```bash
for vm in vm-db-az1-prod vm-db-az2-prod; do
  DISK_ID=$(az vm show -g "$RESOURCE_GROUP" -n $vm --query "storageProfile.dataDisks[0].managedDisk.id" -o tsv)
  az snapshot create -g "$RESOURCE_GROUP" -n "snap-${vm}-pre-issue30" --source "$DISK_ID" --incremental true
done
```

任意で、Primary 上で `mongodump --db blogapp --out /tmp/pre-issue30` を実行し、論理バックアップも取得します。

#### 手順 2: クォータとゾーンを確認する

```bash
LOCATION="japanwest"   # デプロイしたリージョンに合わせます
az vm list-usage --location "$LOCATION" \
  --query "[?contains(name.value, 'DSv6') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" -o table
az vm list-skus --location "$LOCATION" --size Standard_D4s_v6 \
  --query "[].locationInfo[].zones" -o tsv
```

**判断:** 残量（Limit - Current）が 4 vCPU 以上あり、ゾーン一覧に `3` が含まれていれば続行します。Zone 3 がない場合は、講師と相談してください（`dbVmAz3Zone` で別ゾーンに置けますが、2 台が同じゾーンに入るとゾーン障害時に過半数を失う可能性があります）。

#### 手順 3: Bicep を再デプロイして `vm-db-az3-prod` だけを作成する

既存 VM は作り直さず、3 台目だけを作成します。`skipVmCreationDbAz3` は既定で `skipVmCreationDb` と同じ値になるため、明示的に `false` を指定します。

```bash
cd ~/Azure-IaaS-Workshop
git pull   # Issue #30 を含む版を取得
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file materials/bicep/main.bicep \
  --parameters materials/bicep/main.local.bicepparam \
  --parameters skipVmCreationWeb=true skipVmCreationApp=true skipVmCreationDb=true skipVmCreationDbAz3=false
```

**期待結果:** `provisioningState` が `Succeeded` になり、`vm-db-az3-prod`（10.0.3.6、Zone 3）が作成されます。

**影響:**

- 既存の DB VM の Custom Script は内容が同じため再実行されません。
- App VM の Custom Script は `MONGODB_URI` が 3 ホストに変わるため **再実行されます**（パッケージ更新を含みます）。`/opt/blogapp/.env` と `/etc/environment` は新しい URI に更新されますが、実行中の API と `/opt/blogapp/dist/.env` は変わりません（手順 6 で反映します）。
- `--parameters` の上書き指定がエラーになる場合は、`main.local.bicepparam` に同じ 4 つの値を書いてから実行します。

#### 手順 4: 新しい DB VM の準備完了を待つ

新規 DB VM は初回起動時に LTS カーネル（6.8）へ切り替えるため、1 回再起動します（7.1 参照）。3〜5 分待ってから、Bastion SSH で `vm-db-az3-prod` を確認します。

```bash
uname -r                                  # 6.8.x
sudo blogapp-kernel-track status          # finalize : done/not-needed
findmnt --mountpoint /data/mongodb
sudo systemctl is-active mongod           # active
mongosh --quiet --eval 'db.hello().isWritablePrimary'   # false（まだメンバーではない）
```

#### 手順 5: Primary で `rs.add()` を実行する

Primary（通常 `vm-db-az1-prod`）に Bastion SSH で接続します。

```bash
mongosh --quiet --eval 'db.hello().isWritablePrimary'   # true であること
mongosh --quiet --eval 'rs.add({ host: "10.0.3.6:27017", priority: 1, votes: 1 })'
```

**期待結果:** `{ ok: 1 }` が返ります。すでに追加済みの場合は `Found two member configurations with same host field` というエラーになります。この場合は追加済みなので、手順 6 に進みます。

> **なぜ `priority: 1, votes: 1` か:** 新規デプロイと同じ構成（az1 = priority 2、az2/az3 = priority 1、全員 1 票）にそろえます。初期同期中のメンバーは選出に立候補せず、多数決の計算にも影響しません。そのため、同期を待たずに追加しても安全です。

#### 手順 6: 初期同期の完了を待つ

```bash
mongosh --quiet --eval '
const s = rs.status();
const p = s.members.find(m => m.stateStr === "PRIMARY");
s.members.forEach(m => print(m.name, m.stateStr, "lagSec=" + ((p.optimeDate - m.optimeDate) / 1000)));
'
```

`10.0.3.6:27017` が `STARTUP2`（初期同期中）から `SECONDARY` になり、`lagSec=0`（または数秒）になるまで、1 分おきに繰り返します。ワークショップのデータ量なら通常は数分以内です。

#### 手順 7: アプリの接続文字列を更新し、API を 1 台ずつ再起動する

Driver は既存の 2 ホストからも新メンバーを自動検出しますが、seed list に 3 ホストすべてを含めておきます。そうすると、将来 az1/az2 が停止した状態で API が起動しても接続できます。App VM ごとに（`vm-app-az1-prod` → `vm-app-az2-prod`）Bastion SSH で実行します。

```bash
grep '^MONGODB_URI' /opt/blogapp/.env | sed -E 's#//[^@]*@#//***@#'   # 3 ホスト (10.0.3.4/5/6) と replicaSet=blogapp-rs0 を確認
cp /opt/blogapp/.env /opt/blogapp/dist/.env
chmod 600 /opt/blogapp/dist/.env
pm2 restart blogapp-api --update-env
sleep 5
curl -s http://localhost:3000/health
```

**期待結果:** `healthy` が返ります。1 台目が正常になってから 2 台目を実施します。内部 Load Balancer がもう一方の App VM に振り分けるため、API は停止しません。

手順 3 で App tier を再デプロイしなかった場合は、`/opt/blogapp/.env` と `/opt/blogapp/dist/.env` の `MONGODB_URI` のホスト部を `10.0.3.4:27017,10.0.3.5:27017,10.0.3.6:27017` に編集してから再起動します。

#### 手順 8: 動作を確認する

```bash
mongosh --quiet --eval 'rs.status().members.map(m => m.name + " " + m.stateStr + " votes=" + rs.conf().members.find(c => c.host === m.name).votes)'
```

- PRIMARY 1 台、SECONDARY 2 台、すべて `votes=1` であること。
- ブラウザで投稿の作成と編集ができること。
- post-deployment setup を再実行すると、`Replica set already initialized (3 members)` と表示され、再初期化されないこと。
- Day 2 の DB フェイルオーバー演習（Primary 停止で自動選出）が実施できること。

**ロールバック:** 問題があれば、Primary で `rs.remove("10.0.3.6:27017")` を実行し、2 ノード構成に戻します（接続文字列の 3 つ目のホストは無視されます）。不要になった `vm-db-az3-prod` とそのディスクを削除し、手順 1 のスナップショットは確認後に削除します。

## 8. Cloud Shell が切断された

Cloud Shell を再接続すると、カレントディレクトリ、作業変数、`~/.ssh` 配下の SSH 鍵が期待どおりでないことがあります。Day 1 の Step 2 で `~/clouddrive/workshop-keys` に SSH 鍵を退避していれば、次の順に復旧します。

```bash
cd ~/Azure-IaaS-Workshop

LOCATION="japanwest"
RESOURCE_GROUP="rg-blogapp-workshop"

az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

複数グループの場合は、`RESOURCE_GROUP` を講師から割り当てられた値に戻します。

```bash
RESOURCE_GROUP="rg-blogapp-A-workshop"
```

SSH 鍵を復旧します。

```bash
mkdir -p ~/.ssh
cp ~/clouddrive/workshop-keys/id_rsa ~/clouddrive/workshop-keys/id_rsa.pub ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

Bastion extension も確認します。

```bash
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name bastion --upgrade --yes
az extension show --name bastion --query "{name:name,version:version}" -o table
```

FQDN を使う手順まで進んでいた場合は、再取得します。

```bash
FQDN=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-agw-blogapp-prod \
  --query dnsSettings.fqdn -o tsv)
echo "https://$FQDN"
```

デプロイ中だった場合は、Portal で Resource group > Deployments を開きます。Cloud Shell の切断だけで Azure deployment が止まるとは限りません。

**チェックポイント:** `az network bastion ssh` が `az network bastion: 'ssh' is not in the 'az network bastion' command group` のようなエラーになる場合は、Bastion extension の未導入または古い version が原因です。上記の extension 手順を再実行します。

## 9. Log Analytics にデータが出ない

**確認すること:**

- `scripts/configure-dcr.sh "$RESOURCE_GROUP"` が成功したか。
- VM に DCR が関連付いているか。
- Log Analytics workspace のテーブル初期化後に数分待ったか。

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

**対処:** 新規 workspace では Syslog / Perf table の初期化に 1-5 分かかります。時間を置いて DCR スクリプトを再実行します。

## 10. Day 2 の Backup / ASR が進まない

| 症状 | 確認すること | 対処 |
|---|---|---|
| Backup item が出ない | Recovery Services vault と VM の選択 | Backup の有効化手順を再確認 |
| Backup job が遅い | 初回バックアップかどうか | 講師の指示に従い、代表 VM のみで進める |
| ASR initial replication が終わらない | Replication health と進捗 | Test failover は講師デモまたは設計説明に切り替える |
| Test failover リソースが残った | Cleanup test failover 実行有無 | Recovery Services vault から cleanup を実行 |

## 次に進む

- コマンドやリソース名は [クイックリファレンス](../reference/quick-reference-card.ja.md) を参照します。
- Day 1 の Azure リソースデプロイは [Day 1: Azure リソースデプロイ](../learner/day-1-deployment-checklist.ja.md) に戻ります。
- Day 1 のアプリデプロイは [Day 1: アプリデプロイ](../learner/day-1-app-deployment.ja.md) に戻ります。
- Day 2 の手順は [Day 2: 回復性チェックリスト](../learner/day-2-resiliency-checklist.ja.md) に戻ります。

戻る: [受講者ポータル](../index.md)
