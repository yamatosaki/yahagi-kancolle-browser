<div align="center">
  <img src="assets/app_icon.png" width="128" alt="ヤハギのアプリアイコン">

# ヤハギ（Yahagi KanColle Browser）

モバイル端末向けの『艦隊これくしょん -艦これ-』非公式ブラウザ兼ローカル情報支援ツールです。

<p>
  <strong>🌐 他の言語 / Other Languages:</strong><br>
  <a href="README.md">简体中文</a> ｜
  <a href="README.zh-Hant.md">繁體中文</a> ｜
  <strong>日本語</strong>
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![CI](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml/badge.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml)

</div>

## アプリについて

ヤハギ（Yahagi）は、Flutter と Android System WebView で開発された、『艦隊これくしょん -艦これ-』向けのモバイルブラウザ兼ローカル情報支援ツールです。ゲームページは Android System WebView（Chromium）で読み込まれます。閲覧、ログイン、Cookie、ページ操作は同じ端末上の Chrome に近い動作になりますが、システムの WebView と Chrome のバージョン差によって挙動が異なる場合があります。

本アプリが読み取るのは、ゲームページがすでに受信した `/kcsapi/` レスポンスのみです。読み取った情報は、端末内で補助情報やログを生成するために使用します。アカウント情報の自動入力、ページの自動クリック、艦隊編成、補給、出撃、任務受領などは行いません。ゲーム内の操作は、すべてプレイヤー本人が行います。

## スクリーンショット

### ゲーム画面と戦闘支援

画像をクリックすると原寸で表示できます。

<p align="center">
  <a href="docs/images/screenshots/battle.png">
    <img src="docs/images/screenshots/battle.png" width="100%" alt="ゲーム画面とリアルタイム支援情報の並列表示">
  </a>
</p>

<table>
  <tr>
    <td width="50%" align="center">
      <a href="docs/images/screenshots/fleet.png">
        <img src="docs/images/screenshots/fleet.png" alt="艦隊情報画面">
      </a>
    </td>
    <td width="50%" align="center">
      <a href="docs/images/screenshots/quests.png">
        <img src="docs/images/screenshots/quests.png" alt="任務情報画面">
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">艦隊情報</td>
    <td align="center">任務情報</td>
  </tr>
</table>

### 端末ごとの表示

<table>
  <tr>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/phone.png">
        <img src="docs/images/screenshots/phone.png" alt="一般的なスマートフォンでの横画面表示">
      </a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/tablet.png">
        <img src="docs/images/screenshots/tablet.png" alt="タブレットでの横画面表示">
      </a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/foldable.png">
        <img src="docs/images/screenshots/foldable.png" alt="折りたたみ端末での表示">
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">スマートフォン</td>
    <td align="center">タブレット</td>
    <td align="center">折りたたみ端末</td>
  </tr>
</table>

ヤハギは、タブレットの横画面、折りたたみ端末、ゲーム画面と情報パネルを並べて使用する場面に合わせてレイアウトを最適化しています。現時点では、タブレットや折りたたみ端末での使用を特に推奨しています。一般的なスマートフォンでも動作しますが、画面サイズの制約により、ホーム画面に同時表示できる支援情報は大画面端末より少なくなります。

## 動作モード

本アプリには、いつでも切り替えられる 2 つの動作モードがあります。

- **ゲーム情報モード：** ゲームページがすでに受信した `/kcsapi/` レスポンスを読み取り、以下のローカル支援機能を有効にします。
- **ブラウザ専用モード：** API 情報の読み取りを停止し、WebView でゲームページを表示・操作する機能のみを使用します。

どちらのモードでも、本アプリがプレイヤーに代わってゲームを操作することはありません。

## 主な機能

### ゲームブラウザ

- Android System WebView で DMM のログインページとゲームページを読み込みます。
- 戻る、再読み込み、ホーム、ミュート、画面調整などの操作を提供します。
- システムの自動回転がオフの場合は横画面を維持し、オンの場合は端末の向きに合わせて縦画面と横画面を切り替えます。
- 簡体字中国語、繁体字中国語、日本語の UI に対応しています。

### 艦隊・作業状況

- 艦娘のレベル、耐久、疲労度、燃料、弾薬、装備を確認できます。
- 速力、火力、雷装、対空、対潜、制空、索敵などの艦隊情報を集計します。
- 遠征、入渠、建造の状態と残り時間を表示します。
- 出撃前に注意が必要な艦隊状態を確認できます。

### 任務情報

- 受領中の任務、達成状態、分類、周期、サーバー側で確認可能な進捗範囲を表示します。
- 任務一覧、詳細説明、基本報酬を表示します。
- 解析・匿名化した任務情報を端末内に保存します。

### 戦闘支援・ログ

- 海域の進行地点、敵味方の艦隊、交戦状態、耐久の変化を記録します。
- ゲームページがすでに受信したデータから、戦闘経過、勝利ランク、MVP 予測を表示します。
- 公式の戦闘結果レスポンスを受信した後、予測を確定結果に更新します。
- 通常艦隊と連合艦隊に対応し、戦闘記録を端末内に保存します。

### ネットワーク・ローカルデータ

- システムネットワーク、HTTP プロキシ、SOCKS5 プロキシに対応しています。
- 支援データは端末内に保存され、クラウドアカウントの追加登録は不要です。
- アプリ内でバージョンを確認し、GitHub Releases から最新情報を取得できます。

## データと安全上の境界

- 実際の Web ナビゲーションでは、DMM と艦これサーバーの HTTPS オリジンのみを許可します。
- ネイティブのキャプチャブリッジは、許可リスト内のオリジンと `/kcsapi/` パスのみを受け付けます。
- Web、Android、Dart の各層で `api_token`、`api_starttime` などの機密パラメータを除去します。
- Cookie、ログインフォーム、完全なリクエストヘッダーを読み取ったり、外部へ出力したりしません。
- キャプチャ処理はゲーム通信を遮断、再送、改変せず、プレイヤーの操作を代行しません。
- Android System WebView は、システムの標準動作に従ってログイン Cookie を保存する場合があります。

## アプリの入手

公開済みバージョンと APK は [GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases) から入手できます。

## 今後の開発予定

作者が当初想定していた主な機能は、おおむね実装済みです。一方で、未発見の不具合やテストが十分でない箇所が残っている可能性があります。使用感、互換性の問題、機能に関する提案は Issue でお知らせください。寄せられた内容を参考に、今後も修正と改善を続けます。

iOS 版は現在計画段階です。作者の手元に Mac などの iOS 開発・検証環境がないため、開発にはしばらく時間がかかる見込みです。

HarmonyOS 版についても、将来的に実現可能性を調査する可能性がありますが、現時点では具体的な開発計画や時期は決まっていません。

## オープンソースとコントリビューション

ヤハギはオープンソースで開発されています。次の方法でプロジェクトに参加できます。

- Issue で不具合や機能案を報告する。
- Pull Request で機能、互換性、ドキュメント、翻訳を改善する。
- さまざまな Android 端末や WebView バージョンでテストし、結果を共有する。

開発に参加する前に、[コントリビューションガイド](CONTRIBUTING.md) と [セキュリティポリシー](SECURITY.md) をご確認ください。

ソースコードには [MIT License](LICENSE) が適用されます。サードパーティーのフォント、依存ライブラリ、その他の素材については [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) をご確認ください。

## 免責事項

ヤハギはコミュニティーによって開発された非公式ツールであり、『艦隊これくしょん -艦これ-』の運営・開発元、DMM、および各権利者との間に所属、許諾、提携関係はありません。

利用者は関連する利用規約を自ら確認・遵守し、サードパーティー製ツールの使用に伴うアカウント、ネットワーク、互換性上のリスクを負うものとします。ゲーム名、商標、第三者素材に関する権利は、それぞれの権利者に帰属します。

## 謝辞

[poi](https://github.com/poooi/poi) プロジェクトと、そのオープンソースコミュニティーに心より感謝します。poi は長年にわたり、オープンソースを通じて『艦隊これくしょん -艦これ-』コミュニティーツールの発展を支えてきました。本プロジェクトも、データ構成、機能設計、コミュニティー運営など、多くの面で貴重な知見と着想を得ています。

Flutter、WebView Flutter、本プロジェクトが利用する各ライブラリのメンテナー、ならびにテスト、フィードバック、コード提供に協力してくださった皆さまにも感謝します。

ヤハギは独立して開発されているプロジェクトです。本プロジェクトの見解や実装は、上記のプロジェクトおよびコミュニティーの公式見解を示すものではありません。
