

# health-planet-to-fitbit

HealthPlanet で測定した 体重と体脂肪率を FitBit にコピーするツール。
使用する為には、以下の設定が必要です。
* HealthPlanet のアカウント作成 (HealthPlanet アプリ)
* HealthPlanet の[API の設定](https://www.healthplanet.jp/apis_account.do)
* FitBit のアカウント作成 (FitBit アプリ)
* FitBit の[App の登録](https://dev.fitbit.com/apps)

## 使い方

### 初期設定

> ruby lib/cli.rb --mode setup

初期設定を行います。
設定ファイルは .hpfbconf に保存されます (--file で変更可能)。


> ruby lib/cli.rb --mode setup-health-planet

> ruby lib/cli.rb --mode setup-fit-bit

HealthPlanet 部分のみ、または FitBit 部分のみの初期設定を行います。

### コピー実行

> ruby lib/cli.rb --mode copy --from YYYY-MM-DD --to YYYY-MM-DD

from, to で指定した期間の体重・体脂肪率の情報を HealthPlanet から取得し、FitBit にコピーします。
from, to は省略すると、from は30日前、 to は今日の日付になります。

