# Azure IaC と Bicep 入門: ワークショップ構成の読み方

> **位置づけ:** このページは、Azure の Infrastructure as Code（IaC）を初めて読む受講者向けの補足資料です。Day 1 の Azure リソースデプロイは [Day 1: Azure リソースデプロイ](../learner/day-1-deployment-checklist.ja.md) に従ってください。

このガイドでは、Bicep の細かいテクニックを先に覚えるのではなく、次の順で「Azure の IaC がどう動き、このワークショップの Bicep が何を作っているのか」を理解できるように説明します。

対象範囲:
- テンプレートは `materials/bicep/` 配下にあります。
- エントリポイントは `materials/bicep/main.bicep` です。
- 受講者が主に編集する値は `materials/bicep/main.local.bicepparam` に置きます。
- このページは Azure IaaS Workshop の Bicep を読むための入門資料です。Azure サービスの詳細な操作手順は各 Day の手順書で扱います。

このガイドで参照する主なファイル:

```text
materials/bicep/
├── main.bicep              # 全体を組み立てる入口
├── main.bicepparam         # コミットされるパラメータ例
├── dev.bicepparam          # 開発向けの低コスト設定例
└── modules/
    ├── network/            # VNet, NSG, NAT Gateway, Bastion, Gateway, Load Balancer
    ├── compute/            # VM 共通部品, Web/App/DB tier
    ├── monitoring/         # Log Analytics
    ├── security/           # Key Vault, RBAC
    └── storage/            # Storage Account
```

## 1) Azure の IaC の仕組み

### 1.1 IaC は「作業手順」ではなく「望ましい状態」を書く

Infrastructure as Code（IaC）は、クラウドのリソースを手作業で作る代わりに、コードとして管理する考え方です。

たとえば Azure Portal で次の操作を順番に行う代わりに、Bicep では「最終的にこういう状態にしたい」と宣言します。

- VNet を作る。
- Web/App/DB 用のサブネットを作る。
- VM を 2 つの Availability Zone に分けて作る。
- NSG で通信元とポートを制限する。
- Application Gateway と Internal Load Balancer を作る。
- Log Analytics や Key Vault を作る。

Bicep はシェルスクリプトのような「1 行ずつ実行する手順書」ではありません。Azure Resource Manager がテンプレートを読み取り、現在の状態とテンプレート上の望ましい状態を比較し、必要な作成や更新を行います。

AWS 経験者向けにいうと、Azure Resource Manager と Bicep の関係は、CloudFormation と YAML/JSON template の関係に近いです。ただし、Azure の Bicep は ARM template JSON をより読みやすく書くための専用言語です。

### 1.2 Azure Resource Manager、ARM template、Bicep の関係

Azure の IaC は、主に次の流れで動きます。

```text
受講者 / 講師
  -> Azure CLI または Azure Portal
  -> Bicep ファイル
  -> ARM template JSON に変換
  -> Azure Resource Manager
  -> 各 Resource Provider
  -> Azure リソース作成・更新
```

用語を分けると、次のようになります。

- **Azure Resource Manager（ARM）**: Azure リソースの作成、更新、削除を受け付ける管理プレーンです。
- **ARM template**: ARM に渡す JSON 形式の IaC テンプレートです。
- **Bicep**: ARM template を簡潔に書くための言語です。デプロイ時には ARM template JSON に変換されます。
- **Resource Provider**: `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.KeyVault` など、各 Azure サービスを作成する裏側の提供元です。

このワークショップでは、受講者は ARM template JSON を直接書きません。`main.bicep` と各モジュールを Bicep として読み、Azure CLI からデプロイします。

### 1.3 このワークショップはリソースグループ単位でデプロイする

Azure の Bicep は、いくつかのスコープに対してデプロイできます。

- Management Group
- Subscription
- Resource Group
- Tenant

このワークショップの `main.bicep` は、基本的に **Resource Group deployment** として実行します。つまり、ひとつのリソースグループの中に、ネットワーク、VM、Load Balancer、Key Vault などをまとめて作ります。

ワークショップでリソースグループ単位にする理由は単純です。

- 受講者ごとの環境を分けやすい。
- デプロイ結果を Azure Portal で確認しやすい。
- 終了後にリソースグループを削除すれば、関連リソースをまとめて片付けられる。

### 1.4 `main.bicep` と `.bicepparam` の役割

Bicep では、テンプレート本体と入力値を分けて管理できます。

- `main.bicep`
  - 何を作るかを定義します。
  - VNet、NSG、VM、Application Gateway、Key Vault などの構造を持ちます。
  - 受講者ごとに大きく変えるファイルではありません。
- `main.bicepparam`
  - `main.bicep` に渡す値の例です。
  - コミットされるテンプレート用のパラメータファイルです。
- `main.local.bicepparam`
  - 受講者や講師が自分の値を入れるローカル用ファイルです。
  - `*.local.bicepparam` は gitignore 対象です。

典型的な流れは次のとおりです。

```bash
cd materials/bicep
cp main.bicepparam main.local.bicepparam

# main.local.bicepparam に自分の値を入れてからデプロイ
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file main.bicep \
  --parameters main.local.bicepparam
```

この分離により、Bicep の構造は共通化しつつ、SSH 公開鍵、Microsoft Entra ID の client ID、証明書、DNS ラベルなど、受講者ごとに異なる値だけを差し替えられます。

### 1.5 デプロイ時に何が起きるか

`az deployment group create` を実行すると、Azure は次のように動きます。

1. Azure CLI が `main.bicep` と parameter file を読み込みます。
2. Bicep が ARM template JSON に変換されます。
3. Azure Resource Manager がテンプレートを検証します。
4. Resource Provider がリソースを作成または更新します。
5. Bicep の `output` に定義された値がデプロイ結果として返ります。

重要なのは、同じテンプレートを再実行しても「もう存在するリソースを毎回ゼロから作り直す」わけではないことです。Azure はテンプレートとの差分を見て、必要な変更を行います。

ただし、すべての変更が安全に更新できるわけではありません。VM の一部のプロパティのように、作成後に変えにくいものもあります。このワークショップの Bicep では、そのような再デプロイ時の扱いを 5 章で紹介する `skipVmCreation` などで補助しています。

### 1.6 `output` はデプロイ後の入口になる

`main.bicep` の最後には、デプロイ後に受講者や講師が使う値が `output` として定義されています。

代表例:

- `appGatewayFqdn`
- `appGatewayHttpsUrl`
- `webTierPrivateIps`
- `appTierPrivateIps`
- `dbTierPrivateIps`
- `mongoConnectionString`
- `bastionName`
- `natGatewayPublicIp`

Azure Portal を探し回らなくても、デプロイ結果からアプリケーションの URL や VM の private IP を確認できるようにしています。

## 2) Bicep を使う利点

### 2.1 ARM template JSON より読みやすい

Azure Resource Manager が最終的に受け取るのは ARM template JSON ですが、JSON で大きなインフラを直接書くと、構造が深くなり、繰り返しも多くなります。

Bicep では、同じ Azure リソースをより短く、構造的に書けます。

```bicep
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}
```

初心者にとって大事なのは、Bicep の構文をすべて暗記することではありません。まずは次の読み方ができれば十分です。

- `param` は外から受け取る値。
- `var` はテンプレート内で使う計算済みの値。
- `resource` は Azure に作るリソース。
- `module` は別の Bicep ファイルを呼び出す仕組み。
- `output` はデプロイ後に返す値。

### 2.2 入力ミスを減らす仕組みがある

`main.bicep` では、パラメータに説明や制約を付けています。

```bicep
@description('Environment name for naming convention')
@allowed([
  'prod'
  'dev'
  'test'
])
param environment string = 'prod'
```

よく使う仕組みは次のとおりです。

- `@description()`
  - Azure Portal やエディタで、入力値の意味を理解しやすくします。
- `@allowed()`
  - 入力できる値を制限します。環境名やグループ ID の入力ミスを減らせます。
- `@secure()`
  - 証明書パスワードや MongoDB パスワードなど、ログや履歴に出したくない値を秘匿値として扱います。

このワークショップでは、学生が短時間で同じ構成を作る必要があります。入力欄で迷う時間や、単純なタイプミスによる失敗を減らすため、Bicep 側で入力 UX を整えています。

### 2.3 パラメータを分けることで、同じ構成を何度でも再現できる

IaC の大きな利点は、同じコードから同じ構成を再現できることです。

このリポジトリでは、受講者が編集する値を `main.local.bicepparam` に寄せています。

推奨フロー:

1. `main.bicepparam` を `main.local.bicepparam` にコピーする。
2. 実値は `main.local.bicepparam` にだけ入れる。
3. `--parameters main.local.bicepparam` でデプロイする。

この方式の利点:

- 受講者ごとの値を Git にコミットしにくい。
- 講師が説明する「編集するファイル」を固定できる。
- 失敗した場合でも、同じ入力で再実行しやすい。
- `dev.bicepparam` のように、開発向けの低コスト構成も別ファイルで管理できる。

### 2.4 モジュール化しやすい

Bicep の `module` を使うと、大きなテンプレートを小さなファイルに分けられます。

このワークショップでは、ネットワーク、コンピュート、監視、セキュリティ、ストレージを別々のモジュールにしています。

モジュール化の利点:

- 1 ファイルが巨大になりすぎない。
- VNet、VM、Key Vault などの責務が分かりやすい。
- 同じ VM 作成ロジックを Web/App/DB で再利用できる。
- 受講者が「今どの層の設定を見ているのか」を追いやすい。

### 2.5 Azure の標準ツールと相性がよい

Bicep は Azure の標準的な IaC 言語です。Azure CLI、Azure Cloud Shell、VS Code の Bicep 拡張、Azure Portal の template deployment などと自然に連携します。

ワークショップで重要な点は、受講者のローカル PC に複雑なツールチェーンを要求しないことです。標準の学習フローでは Azure Cloud Shell を使うため、Azure CLI と Bicep が利用できる状態から始められます。

### 2.6 変更内容をコードレビューしやすい

Azure Portal で手作業した変更は、後から「何を変えたか」を追いにくくなります。Bicep で管理すれば、Pull Request や Git diff で変更内容を確認できます。

例:

- VM サイズを変えた。
- Storage Account の SKU を変えた。
- NSG の許可元 CIDR を変えた。
- Key Vault の RBAC 設定を変えた。

本番運用ではこの性質が非常に重要です。ワークショップでは、受講者が「Azure の構成もアプリコードと同じようにレビューできる」という感覚をつかむことを狙っています。

## 3) Bicep のモジュール化の仕組み

### 3.1 `main.bicep` は全体を組み立てるオーケストレータ

このリポジトリでは、受講者がデプロイする入口を `main.bicep` に集約しています。

`main.bicep` の主な役割:

- 受講者や講師が指定するパラメータを受け取る。
- 共通の名前、タグ、サブネット CIDR を決める。
- 各モジュールを正しい関係で呼び出す。
- モジュール間で必要な ID や private IP を受け渡す。
- デプロイ後に必要な値を `output` として返す。

`main.bicep` 自体がすべての Azure リソースを直接定義しているわけではありません。多くのリソースは `modules/` 配下のファイルに分かれています。

### 3.2 `module` は別の Bicep ファイルを呼び出す仕組み

Bicep の `module` は、別ファイルを呼び出して、その中で定義されたリソースをデプロイする仕組みです。

例:

```bicep
module vnet 'modules/network/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    webNsgId: nsgWeb.outputs.nsgId
    appNsgId: nsgApp.outputs.nsgId
    dbNsgId: nsgDb.outputs.nsgId
  }
}
```

この例では、`main.bicep` が `modules/network/vnet.bicep` を呼び出しています。`params` の中で、VNet モジュールに必要な値を渡しています。

### 3.3 モジュールは `param` で受け取り、`output` で返す

モジュール間のやり取りは、基本的に `param` と `output` で行います。

```text
main.bicep
  -> param で値を渡す
  -> module 内で resource を作る
  <- output で作成結果を返す
```

たとえば VNet モジュールは、作成した各サブネットの ID を `output` として返します。その ID を使って、Bastion、Application Gateway、Web/App/DB VM が適切なサブネットに接続されます。

```bicep
subnetId: vnet.outputs.webSubnetId
```

このように `outputs` を参照すると、Bicep は「Web tier は VNet の作成後に必要」という関係を自動的に理解します。

### 3.4 依存関係は多くの場合、自動で作られる

Bicep では、あるリソースやモジュールが別のリソースやモジュールの値を参照すると、依存関係が自動的に作られます。

このワークショップの例:

- `vnet` は `nsgWeb.outputs.nsgId` を参照するため、NSG 作成後に VNet を作ります。
- `bastion` は `vnet.outputs.bastionSubnetId` を参照するため、VNet 作成後に Bastion を作ります。
- `keyVault` は Web/App/DB VM の `principalIds` を参照するため、VM 作成後に RBAC を設定します。

初心者のうちは、まず「ID や output を渡しているところに依存関係が生まれる」と理解すると読みやすくなります。

### 3.5 必要な場合だけ `dependsOn` で順序を明示する

多くの依存関係は参照から自動で作られますが、Azure の都合で順序を明示したい場合があります。

このワークショップでは、NAT Gateway と VNet、DB tier の関係で `dependsOn` を使っています。

- App/DB subnet に NAT Gateway を関連付ける。
- DB VM は MongoDB のパッケージ取得などで outbound internet access を必要とする。
- そのため、DB VM を作る前に NAT Gateway が subnet に関連付いている状態にしたい。

つまり、単に「リソース ID がある」だけでなく、「その設定が有効な状態になってから次へ進めたい」ケースで `dependsOn` を使っています。

### 3.6 条件付きモジュールで構成を切り替える

`main.bicep` には、任意のコンポーネントを on/off するパラメータがあります。

- `deployBastion`
- `deployNatGateway`
- `deployMonitoring`
- `deployKeyVault`
- `deployStorage`

Bicep では次のように、条件付きでモジュールをデプロイできます。

```bicep
module natGateway 'modules/network/nat-gateway.bicep' = if (deployNatGateway) {
  name: 'deploy-nat-gateway'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
  }
}
```

ワークショップでは基本的にフル構成を使います。一方で、教材開発や検証では、Bastion や Storage などを切り替えられるとコストと時間を調整しやすくなります。

### 3.7 VM は「共通 VM モジュール」と「ティア別モジュール」に分かれている

コンピュート層は、次の 2 段構えです。

- `modules/compute/vm.bicep`
  - 1 台の VM を作る共通部品です。
  - NIC、VM、Managed Disk、Managed Identity、Azure Monitor Agent、Custom Script Extension などを扱います。
- `modules/compute/web-tier.bicep`
- `modules/compute/app-tier.bicep`
- `modules/compute/db-tier.bicep`
  - Web/App/DB という役割ごとのラッパーです。
  - それぞれ Zone 1 と Zone 2 に 2 台の VM を展開します。
  - ティアごとの bootstrap script や static private IP、Load Balancer backend pool などを指定します。

この構成により、「VM として共通の作り方」と「Web/App/DB ごとの違い」を分けて読めます。

## 4) 今回のワークショップの Bicep の `main` および各モジュールの内容

### 4.1 全体アーキテクチャ

この Bicep が作るのは、Azure VM を中心にした 3-tier のブログアプリ基盤です。

```text
Internet
  -> Application Gateway (public, HTTPS)
  -> Web tier: 2 x NGINX VM
  -> Internal Load Balancer (private, 10.0.2.10:3000)
  -> App tier: 2 x Node.js/Express VM
  -> DB tier: 2 x MongoDB VM
```

補助的なコンポーネントとして、次も作ります。

- VNet と 5 つのサブネット。
- Web/App/DB 用の Network Security Group。
- App/DB subnet 用の NAT Gateway。
- VM へ SSH するための Azure Bastion。
- VM 監視のための Log Analytics workspace。
- secret 管理を学ぶための Key Vault。
- Blob 用の Storage Account。

### 4.2 `main.bicep` が受け取る主な入力

`main.bicep` は、インフラ全体に必要な値をパラメータとして受け取ります。

分類すると次のようになります。

| 分類 | 主なパラメータ | 何に使うか |
|------|----------------|------------|
| 基本情報 | `location`, `environment`, `workloadName`, `groupId` | リージョン、名前付け、タグ、複数グループ運用 |
| VM 接続 | `adminUsername`, `sshPublicKey` | Linux VM の管理ユーザーと SSH 公開鍵 |
| 機能フラグ | `deployBastion`, `deployNatGateway`, `deployMonitoring`, `deployKeyVault`, `deployStorage` | 任意コンポーネントの on/off |
| VM サイズ | `webVmSize`, `appVmSize`, `dbVmSize`, `dbDataDiskSizeGB` | Web/App/DB のコストと性能 |
| Microsoft Entra ID | `entraTenantId`, `entraClientId`, `entraFrontendClientId` | Frontend/Backend の認証設定 |
| HTTPS | `sslCertificateData`, `sslCertificatePassword`, `appGatewayDnsLabel` | Application Gateway の TLS 終端と FQDN |
| DB | `mongoDbAppPassword` | App tier から MongoDB へ接続するためのパスワード |
| 再デプロイ補助 | `forceUpdateTagWeb`, `forceUpdateTagApp`, `forceUpdateTagDb`, `skipVmCreationWeb`, `skipVmCreationApp`, `skipVmCreationDb` | Custom Script 再実行や VM 既存参照 |

一般的な Azure 設定:

- 環境名、ワークロード名、タグを使ってリソースを整理します。
- VM サイズやディスクサイズをパラメータ化します。
- 秘匿値には `@secure()` を使います。

今回のワークショップの特徴的な設定:

- `groupId` により、複数グループで同時にデプロイしても名前を分けやすくしています。
- `appGatewayDnsLabel` を学生ごとに変え、Application Gateway の FQDN 重複を避けます。
- `main.local.bicepparam` を使い、個人ごとの値をコミットしない運用にしています。
- `forceUpdateTag*` と `skipVmCreation*` により、ワークショップ中の再実行や復旧をしやすくしています。

### 4.3 `main.bicep` のモジュール呼び出し順と依存関係

`main.bicep` は、ファイル上ではおおよそ次の順でモジュールを呼び出します。

```text
1. monitoring/log-analytics.bicep
2. network/nsg-web.bicep
3. network/nsg-app.bicep
4. network/nsg-db.bicep
5. network/nat-gateway.bicep
6. network/vnet.bicep
7. network/bastion.bicep
8. network/application-gateway.bicep
9. network/internal-load-balancer.bicep
10. storage/storage-account.bicep
11. compute/web-tier.bicep
12. compute/app-tier.bicep
13. compute/db-tier.bicep
14. security/key-vault.bicep
```

実際の Azure 側の作成順は、依存関係に応じて最適化されます。たとえば Application Gateway の module はファイル上では Web tier より前に書かれていますが、`webTier.outputs.privateIpAddresses` を参照するため、Web VM の private IP が分かってから構成されます。ここで重要なのは、`main.bicep` が「どの部品を、どの値で、どうつなぐか」を担当していることです。

### 4.4 Network modules: VNet、NSG、NAT Gateway、Bastion、Gateway、Load Balancer

#### `network/nsg-web.bicep`

Web tier 用の Network Security Group を作ります。

一般的な Azure 設定:

- Web tier に入ってよい通信元を絞ります。
- Application Gateway subnet から Web VM への HTTP 通信を許可します。
- SSH は Bastion subnet からの通信に限定します。

今回のワークショップの特徴的な設定:

- VM に public IP を付けず、外部公開は Application Gateway に集約します。
- 受講者が「入口は Gateway、VM 管理は Bastion」という Azure の基本構成を確認できます。

#### `network/nsg-app.bicep`

App tier 用の Network Security Group を作ります。

一般的な Azure 設定:

- App tier の API ポートは Web tier からの通信に絞ります。
- SSH は Bastion 経由に限定します。
- tier 間通信を NSG で明示的に分離します。

今回のワークショップの特徴的な設定:

- Web tier の NGINX から Internal Load Balancer を経由して App tier へ到達する構成を学べます。
- App tier は public に公開せず、内部向けサービスとして扱います。

#### `network/nsg-db.bicep`

DB tier 用の Network Security Group を作ります。

一般的な Azure 設定:

- MongoDB のポートは App subnet からの通信に限定します。
- DB VM 同士の replica set 通信を許可します。
- SSH は Bastion 経由に限定します。

今回のワークショップの特徴的な設定:

- MongoDB を PaaS ではなく VM 上に構築し、IaaS の可用性設計を学ぶ教材にしています。
- 2 台構成の replica set とし、短時間で HA の挙動を確認できるようにしています。

#### `network/nat-gateway.bicep`

App/DB subnet からインターネットへ出るための NAT Gateway を作ります。

一般的な Azure 設定:

- private subnet の VM に public IP を付けずに outbound internet access を提供します。
- パッケージ取得、OS 更新、監視エージェント通信などに使います。
- outbound public IP を固定しやすくなります。

今回のワークショップの特徴的な設定:

- App tier と DB tier の subnet に関連付けます。
- MongoDB インストールやパッケージ更新が、VM の public IP なしで実行できる構成にしています。

#### `network/vnet.bicep`

ワークショップ全体の VNet とサブネットを作ります。

サブネット構成:

| Subnet | CIDR | 用途 |
|--------|------|------|
| Application Gateway subnet | `10.0.0.0/24` | Application Gateway 専用 |
| Web subnet | `10.0.1.0/24` | NGINX reverse proxy VM |
| App subnet | `10.0.2.0/24` | Node.js/Express VM、Internal Load Balancer |
| DB subnet | `10.0.3.0/24` | MongoDB VM |
| AzureBastionSubnet | `10.0.255.0/26` | Azure Bastion 専用 |

一般的な Azure 設定:

- ひとつの VNet を複数 subnet に分け、tier ごとに通信を制御します。
- Web/App/DB subnet に NSG を関連付けます。
- App/DB subnet に NAT Gateway を関連付けます。
- Storage と Key Vault の service endpoint を有効化します。

今回のワークショップの特徴的な設定:

- 3-tier 構成を 1 つの VNet 内に収め、学習しやすい構成にしています。
- Application Gateway と Bastion には Azure が要求する専用 subnet を用意しています。
- Azure の subnet は AWS の subnet と異なり、Availability Zone に固定されません。VM 側で zone を指定します。

#### `network/bastion.bicep`

Azure Bastion を作ります。

一般的な Azure 設定:

- VM に public IP を付けずに SSH 接続できます。
- Bastion 用の subnet は `AzureBastionSubnet` という固定名が必要です。

今回のワークショップの特徴的な設定:

- Standard SKU を使い、Cloud Shell や native client からの SSH、ファイルコピー、IP connect を扱いやすくしています。
- 受講者が VM に入ってアプリ配置や確認作業を行うための入口にしています。

#### `network/application-gateway.bicep`

外部公開用の Application Gateway を作ります。

一般的な Azure 設定:

- public IP を持つ Layer 7 load balancer として使います。
- HTTPS 入口を提供し、Web tier へルーティングします。
- health probe により、正常な Web VM へ traffic を流します。

今回のワークショップの特徴的な設定:

- 自己署名証明書で HTTPS を有効化します。独自ドメインや商用証明書を準備しなくても TLS 終端を体験できます。
- TLS は Application Gateway で終端し、Web tier へは HTTP で転送します。end-to-end TLS より構成を簡単にし、学習時間を短縮しています。
- backend pool は Web VM の private IP を使います。

#### `network/internal-load-balancer.bicep`

App tier 用の Internal Load Balancer を作ります。

一般的な Azure 設定:

- private IP の Load Balancer として、VNet 内の通信を分散します。
- frontend private IP は App subnet 内に置きます。
- health probe により、正常な App VM にだけ traffic を流します。

今回のワークショップの特徴的な設定:

- frontend private IP は `10.0.2.10` に固定しています。
- Web tier の NGINX が、この Internal Load Balancer に向けて API traffic を送ります。
- 将来的に VM Scale Set へ移行する場合にも考え方をつなげやすい構成です。

### 4.5 Compute modules: VM 共通部品と Web/App/DB tier

#### `compute/vm.bicep`

1 台の Linux VM を作る共通モジュールです。

一般的な Azure 設定:

- Ubuntu 22.04 LTS の Gen2 イメージを使います。
- SSH key 認証を使い、password login を無効化します。
- system-assigned Managed Identity を有効化します。
- Availability Zone を指定します。
- OS disk と必要に応じた data disk を managed disk として作ります。
- Azure Monitor Agent と Custom Script Extension を扱います。
- VM には public IP を付けず、NIC を subnet に接続します。

今回のワークショップの特徴的な設定:

- Basv2 系 VM サイズを既定にし、学習用途としてコストを抑えています。
- Trusted Launch、Secure Boot、vTPM を有効化し、IaaS VM の現代的なセキュリティ既定値を見せています。
- Azure Monitor Agent を VM 拡張として入れますが、DCR の本体は post-deployment script で作ります。
- `skipVmCreation` により、既存 VM の拡張だけ更新できるようにしています。

#### `compute/web-tier.bicep`

Web tier として、NGINX VM を 2 台作ります。

一般的な Azure 設定:

- Zone 1 と Zone 2 に VM を分けます。
- Application Gateway の backend として、Web VM の private IP を使います。
- Web tier は reverse proxy として、frontend 配信と API proxy の入口になります。

今回のワークショップの特徴的な設定:

- `scripts/nginx-install.sh` を Bicep から読み込み、Custom Script Extension で初期設定します。
- Microsoft Entra ID の tenant/client ID を frontend 用 `config.json` に注入します。
- 受講者が後続手順で frontend アプリを手動配置しやすいよう、Web VM 上に NGINX の土台を作ります。

#### `compute/app-tier.bicep`

App tier として、Node.js/Express VM を 2 台作ります。

一般的な Azure 設定:

- Zone 1 と Zone 2 に VM を分けます。
- Internal Load Balancer の backend pool に NIC を関連付けます。
- App tier は DB tier へ接続し、外部からは直接公開しません。

今回のワークショップの特徴的な設定:

- `scripts/nodejs-install.sh` を Bicep から読み込み、Node.js アプリ実行に必要な土台を作ります。
- Microsoft Entra ID の tenant/client ID と MongoDB 接続情報を App VM 側の設定に流します。
- アプリケーションコードの配置は、Day 1 の手順で受講者が Bastion SSH 経由で実施します。Bicep は OS と実行環境の準備までを担当します。

#### `compute/db-tier.bicep`

DB tier として、MongoDB VM を 2 台作ります。

一般的な Azure 設定:

- Zone 1 と Zone 2 に VM を分けます。
- DB 用 data disk を追加します。
- static private IP を使い、DB 接続先と replica set の構成を安定させます。
- DB tier は App tier からのみ接続される前提にします。

今回のワークショップの特徴的な設定:

- 2 node の MongoDB replica set を構成します。本番では 3 node 以上や managed service を検討しますが、ワークショップでは短時間で AZ 障害や復旧の考え方を学ぶため 2 node にしています。
- `vm-db-az1` と `vm-db-az2` を固定 IP で配置し、接続文字列を `output` で返します。
- IaaS 上で DB を動かす場合のディスク、ネットワーク、可用性の設計ポイントを見える形にしています。

### 4.6 Monitoring module: Log Analytics

#### `monitoring/log-analytics.bicep`

Log Analytics workspace を作ります。

一般的な Azure 設定:

- VM のログやメトリックを集約する場所として使います。
- retention を設定し、監視データの保持期間を管理します。
- Azure Monitor Agent と組み合わせて使います。

今回のワークショップの特徴的な設定:

- retention は 30 日です。
- DCR は Bicep では作らず、デプロイ後に `scripts/configure-dcr.sh` または `scripts/configure-dcr.ps1` で作ります。
- 理由は、Log Analytics の `Syslog` や `Perf` などの table が非同期に初期化され、Bicep 直後に DCR を作ると失敗することがあるためです。

### 4.7 Security module: Key Vault

#### `security/key-vault.bicep`

Key Vault と RBAC を作ります。

一般的な Azure 設定:

- secret や証明書などの秘匿情報を管理する Azure サービスです。
- `enableRbacAuthorization: true` により、access policy ではなく Azure RBAC で権限を管理します。
- VM の system-assigned Managed Identity に `Key Vault Secrets User` を割り当てます。
- 管理者には `Key Vault Administrator` を割り当てます。

今回のワークショップの特徴的な設定:

- Key Vault は VM 作成後にデプロイします。VM の principal ID を受け取って RBAC を割り当てるためです。
- `vmPrincipalIds` を defensive に filter し、空や不正な principal ID による RBAC エラーを避けます。
- Key Vault をアプリの全 secret 管理に完全統合するよりも、まず Managed Identity と RBAC の基本を学ぶ教材として配置しています。

### 4.8 Storage module: Storage Account

#### `storage/storage-account.bicep`

Blob 用の Storage Account を作ります。

一般的な Azure 設定:

- `StorageV2` の汎用 Storage Account を作ります。
- Blob endpoint を `output` として返します。
- Blob soft delete など、誤削除に備える設定を持ちます。

今回のワークショップの特徴的な設定:

- SKU は `Standard_LRS` です。本番では ZRS/GRS なども候補になりますが、ワークショップではコストとシンプルさを優先しています。
- 静的 assets、uploads、backups などを扱う拡張ポイントとして用意しています。
- Storage 自体は 3-tier IaaS 構成の中心ではないため、必要に応じて `deployStorage` で切り替えられます。

### 4.9 一般的な Azure 設定とワークショップ特有の設定のまとめ

一般的な Azure 設定:

- 3-tier を subnet と NSG で分離する。
- VM に public IP を持たせず、入口を Application Gateway と Bastion に分ける。
- Availability Zone に VM を分散する。
- Managed Identity を使い、VM を Azure RBAC の principal として扱う。
- Log Analytics と Azure Monitor Agent で監視の入口を作る。
- Key Vault は RBAC モードで管理する。
- Load Balancer と health probe で正常な instance に traffic を流す。

今回のワークショップの特徴的な設定:

- 2 zone、各 tier 2 台構成にして、短時間で HA の考え方を確認できるようにしている。
- MongoDB は 2 node replica set とし、IaaS 上の DB 可用性を教材として扱う。
- 自己署名証明書を使い、ドメインや商用証明書なしで HTTPS を体験できるようにしている。
- VM サイズと Storage SKU は学習用にコストを抑えている。
- アプリの配置は Bicep で完全自動化せず、受講者が Bastion SSH で確認しながら実施する流れを残している。
- `groupId`、DNS label、local parameter file により、20〜30 名程度の同時演習でも環境を分けやすくしている。

## 5) その他、今回の Bicep のコードで使われているテクニックの紹介

ここからは、最初に理解しなくてもデプロイはできます。ただし、再デプロイ、トラブルシュート、教材開発をする場合に役立つ Bicep のテクニックです。

### 5.1 条件付きモジュールと safe-dereference

`deployMonitoring` や `deployKeyVault` のように、条件付きで作るモジュールがあります。

条件付きモジュールは、off のときに `outputs` が存在しません。そのため、`main.bicep` では safe-dereference を使っています。

```bicep
logAnalyticsWorkspaceId: logAnalytics.?outputs.?workspaceId ?? ''
```

意味:

- `.?` は、値が存在しない可能性を許容して参照します。
- `?? ''` は、左側が null の場合に空文字を使います。

これにより、監視を off にしても同じ `main.bicep` を使えます。

### 5.2 `loadTextContent()` と `replace()` でスクリプトを注入する

Web/App tier では、Linux VM の初期設定用 script を Bicep から読み込んでいます。

例:

- `compute/web-tier.bicep` が `scripts/nginx-install.sh` を読み込む。
- `compute/app-tier.bicep` が `scripts/nodejs-install.sh` を読み込む。

Bicep 側では `loadTextContent()` で script を読み取り、`replace()` で placeholder を実値に置き換え、Custom Script Extension に渡します。

この方式の利点:

- bash script を Bicep ファイルの中に長く埋め込まずに済む。
- script 単体で読みやすい。
- Bicep の `format()` と bash の `${variable}` のような記法が衝突しにくい。
- Entra ID や MongoDB 接続情報など、受講者ごとの値を parameter file から VM へ流せる。

### 5.3 `forceUpdateTag` で Custom Script を再実行する

Azure の Custom Script Extension は、設定が変わっていないと再実行されないことがあります。

このワークショップでは、次のパラメータで再実行を促せるようにしています。

- `forceUpdateTagWeb`
- `forceUpdateTagApp`
- `forceUpdateTagDb`

値にタイムスタンプのような新しい文字列を入れると、その tier の Custom Script Extension が更新扱いになります。

例:

```bicep
forceUpdateTagWeb = '20260616120000'
```

NGINX 設定や VM 初期化 script を再適用したいときに使います。

### 5.4 `skipVmCreation` と `existing` で拡張だけ更新する

VM は、作成後に変えにくいプロパティがあります。たとえば SSH key や OS profile 周辺の変更は、再デプロイ時に失敗しやすい代表例です。

このワークショップでは、VM を作り直さずに extension だけ更新するため、次のパラメータを用意しています。

- `skipVmCreationWeb`
- `skipVmCreationApp`
- `skipVmCreationDb`

`compute/vm.bicep` では、`skipVmCreation` が `true` の場合に VM と NIC を `existing` resource として参照します。

```bicep
resource existingVm 'Microsoft.Compute/virtualMachines@2023-09-01' existing = if (skipVmCreation) {
  name: vmName
}
```

これにより、既存 VM はそのままにして、Azure Monitor Agent や Custom Script Extension だけを更新できます。

### 5.5 DCR を Bicep 後に作る

`main.bicep` には、DCR を Bicep で作らない理由がコメントされています。

Log Analytics workspace を作った直後は、`Syslog` や `Perf` などの table がまだ準備中の場合があります。その状態で DCR を作ると、table が見つからずエラーになることがあります。

そのため、このワークショップでは次の流れにしています。

1. Bicep で Log Analytics workspace と VM を作る。
2. VM に Azure Monitor Agent を入れる。
3. デプロイ後に `scripts/configure-dcr.sh` または `scripts/configure-dcr.ps1` を実行する。
4. script 側で table の準備を待ってから DCR と関連付けを作る。

これは「何でも Bicep に入れる」のではなく、Azure 側の非同期初期化を踏まえて、安定する分割を選んでいる例です。

### 5.6 Key Vault の principal ID を filter する

Key Vault モジュールでは、VM の Managed Identity に RBAC を割り当てます。

ただし、VM 作成が途中で失敗した場合など、principal ID が空になる可能性があります。そのため、`filter()` で有効そうな ID だけを取り出してから role assignment を作ります。

```bicep
var validVmPrincipalIds = filter(vmPrincipalIds, id => !empty(id) && length(id) >= 36)
```

これは教材としても重要です。IaC では「正常系だけ」ではなく、途中失敗や再実行に強い書き方が役に立ちます。

### 5.7 `output` をワークショップの操作契約として使う

`main.bicep` の `output` は、単なるおまけではありません。受講者と手順書の間の契約として使っています。

例:

- アプリ URL を確認するために `appGatewayHttpsUrl` を返す。
- Bastion SSH の接続先確認のために各 tier の private IP を返す。
- DB 接続確認のために `mongoConnectionString` を返す。
- 後続 script や講師確認のために `bastionName` や `natGatewayPublicIp` を返す。

ワークショップでは、Portal でリソースを探す時間を減らし、学習者が次の操作に進みやすくするために outputs を設計しています。

### 5.8 まず読むべき場所

Bicep 初心者がこのリポジトリを読む場合は、次の順がおすすめです。

1. `materials/bicep/main.bicep` の `param` と `output` を読む。
2. `main.bicep` の `module` 呼び出し順を追う。
3. `modules/network/vnet.bicep` で subnet 構成を見る。
4. `modules/compute/web-tier.bicep`, `app-tier.bicep`, `db-tier.bicep` で tier ごとの差分を見る。
5. `modules/compute/vm.bicep` で 1 台の VM がどう作られるかを見る。
6. 余裕があれば、5 章のテクニックをコード上で探してみる。

最初からすべての property を理解する必要はありません。まずは「どのモジュールが、どの Azure リソースを、何のために作っているか」を追えるようになることが、このページのゴールです。
