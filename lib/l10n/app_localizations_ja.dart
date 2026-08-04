// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ヤハギ';

  @override
  String get game => 'ゲーム';

  @override
  String get fleet => '艦隊';

  @override
  String get expedition => '遠征';

  @override
  String get repair => '入渠';

  @override
  String get construction => '建造';

  @override
  String get quests => '任務';

  @override
  String get battleRecords => '戦闘記録';

  @override
  String get settings => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get layoutSettings => 'UIとレイアウト';

  @override
  String get gameAreaRatio => 'ゲーム画面の比率';

  @override
  String get infoPanelWidth => '情報パネルの幅';

  @override
  String get autoZoom => '自動ズーム (推奨)';

  @override
  String get language => '言語 (Language)';

  @override
  String get networkSettings => 'ネットワーク設定';

  @override
  String get networkStatus => 'ネットワーク状態';

  @override
  String get proxyNotSupported =>
      'この端末の Android System WebView はアプリ内プロキシをサポートしていません。\nシステムネットワークまたはVPNを使用してください。';

  @override
  String get systemNetwork => 'システムネットワーク / VPN';

  @override
  String get systemNetworkDesc => 'アプリ内プロキシを使用せず、システムのネットワークに従います。';

  @override
  String get httpProxy => 'HTTP プロキシ';

  @override
  String get httpProxyDesc => 'カスタム HTTP プロキシに接続します。';

  @override
  String get socks5Proxy => 'SOCKS5 プロキシ';

  @override
  String get socks5ProxyDesc => 'カスタム SOCKS5 プロキシに接続します。';

  @override
  String get hostAddress => 'ホストアドレス (IP またはドメイン)';

  @override
  String get hostHint => '例: 192.168.1.10';

  @override
  String get port => 'ポート';

  @override
  String get currentSavedMode => '現在の保存モード';

  @override
  String get vpnStatus => 'VPN 状態';

  @override
  String get vpnActive => 'VPNが検出されました';

  @override
  String get vpnInactive => 'VPNは検出されていません';

  @override
  String get testConnection => '接続テスト';

  @override
  String get applySettings => '適用して再読み込み';

  @override
  String get restoreSystemNetwork => 'システムネットワークに戻す';

  @override
  String get gameSafety => 'ゲームの安全性';

  @override
  String get blockSortieTitle => '大破進撃ストッパー';

  @override
  String get blockSortieDesc =>
      '艦隊に大破した艦娘（旗艦以外・ダメコン未装備）がいる場合、出撃・進撃をブロックして警告を表示します。オンにすることを強く推奨します。';

  @override
  String get storageAndCache => 'ストレージとキャッシュ';

  @override
  String get logoutAndClear => 'ログアウト / アカウント情報の消去';

  @override
  String get logoutAndClearDesc => 'ゲームのログイン状態をクリアします。次回起動時に再ログインが必要です。';

  @override
  String get clearQuestCache => '任務データのキャッシュを消去';

  @override
  String get clearQuestCacheDesc =>
      'ローカルにキャッシュされた任務データを消去します。アプリ再起動後にゲーム内の任務画面で再取得する必要があります。';

  @override
  String get clearWebCache => 'ゲーム Web キャッシュの消去';

  @override
  String get clearWebCacheDesc => 'ゲームが読み込んだ画像や音声などの静的リソースのキャッシュを消去します。';

  @override
  String get fleetBrief => '編成情報';

  @override
  String get expeditionBrief => '遠征情報';

  @override
  String get repairBrief => '入渠情報';

  @override
  String get constructionBrief => '建造情報';

  @override
  String get questBrief => '任務情報';

  @override
  String get preSortieCheck => '出撃前検査';

  @override
  String get forecast => '戦闘予測';

  @override
  String get waitingForSortieData => '出撃待機中';

  @override
  String get standby => '待機';

  @override
  String get compact => '簡潔';

  @override
  String get detailed => '詳細';

  @override
  String get questDesc => '任務詳細';

  @override
  String get baseReward => '基本報酬';

  @override
  String get accepted => '受注済';

  @override
  String get completed => '完了';

  @override
  String get updatedAt => '更新';

  @override
  String get questDaily => 'デイリー';

  @override
  String get questWeekly => 'ウィークリー';

  @override
  String get questMonthly => 'マンスリー';

  @override
  String get questOneTime => '単発';

  @override
  String get questOther => '他';

  @override
  String get questUnknown => '不明';

  @override
  String get inProgress => '進行中';

  @override
  String get clearWebCacheConfirmTitle => 'ゲーム Web キャッシュの消去';

  @override
  String get clearWebCacheConfirmDesc =>
      'ゲームのキャッシュを消去しますか？ダウンロード済みの画像や音声などの静的リソースが削除されるため、次回起動時や立ち絵の読み込み時に多くの通信量と時間がかかる場合があります。';

  @override
  String get confirmClear => '消去する';

  @override
  String get captureMode => 'データキャプチャモード';

  @override
  String get gameAndSound => 'ゲームとサウンド';

  @override
  String get gameSound => 'ゲームのサウンド';

  @override
  String get aboutApp => 'ヤハギ について';

  @override
  String get aboutSubtitle => 'バージョン 學習版 1.0.1 · 免責事項 · 更新の確認';

  @override
  String get version => 'バージョン 學習版 1.0.1';

  @override
  String get disclaimerTitle => '免責事項 (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      '本プロジェクトは、プログラミング技術の交流と学習を目的として開発された、完全非営利かつ非公式のサードパーティ製汎用ブラウザツールです。「艦隊これくしょん -艦これ-」の公式や関連権利者とは一切関係ありません。';

  @override
  String get disclaimerP2 =>
      '本ソフトウェアは、ゲームサーバーとの通信を妨害、再送、改ざんせず、プレイヤーに代わってゲーム操作を実行しません。原作者はソフトウェアの品質（バグの有無、適用性、安定性を含む）について、明示的にも暗示的にもいかなる保証も行いません。';

  @override
  String get disclaimerP3 =>
      '本ソフトウェアの使用、または使用できないことによって生じた端末の破損、データ喪失、アカウント停止のリスク、その他の直接的または間接的な利益の損失について、原作者はいかなる法的・連帯責任も負いません。「技術学習」以外の目的で使用した場合に生じる著作権の争いや利用規約違反などのリスクは、すべて利用者の自己責任となります。';

  @override
  String get viewOnGitHub => 'GitHubを見る';

  @override
  String get checkForUpdates => '更新を確認';

  @override
  String get openSourceLicense => 'ライセンス: MIT License';

  @override
  String get newVersionFound => '🚀 新しいバージョンが見つかりました！';

  @override
  String get currentVersionLabel => '現在のバージョン';

  @override
  String get latestVersionLabel => '最新バージョン';

  @override
  String get updateContent => '更新内容:';

  @override
  String get later => '後で';

  @override
  String get goDownload => 'ダウンロードへ';

  @override
  String get alreadyLatest => '最新版です';

  @override
  String get alreadyLatestDesc => '現在のバージョンは最新です。';

  @override
  String get noRelease => 'リリースなし';

  @override
  String get noReleaseDesc => 'GitHub リポジトリにはまだリリースがありません。';

  @override
  String get checkFailed => '確認に失敗しました';

  @override
  String get networkError => 'ネットワークエラー';

  @override
  String get networkErrorDesc => '更新の確認中にエラーが発生しました。後でもう一度お試しください。';

  @override
  String get noUpdateLog => '更新ログなし';

  @override
  String get battleWarningOff => 'オフ';

  @override
  String get battleWarningReminder => '点滅通知';

  @override
  String get battleWarningConfirm => '確認ダイアログ';

  @override
  String get logoutSnackbar => 'ログアウト機能は準備完了ですが、テストアカウント保護のため現在は実行されません。';

  @override
  String get questCacheCleared => '任務データのローカルキャッシュを消去しました';

  @override
  String get webCacheCleared => 'ゲーム Web キャッシュを消去しました';

  @override
  String get clearLogbook => '航海日誌データの消去';

  @override
  String get clearLogbookDesc => 'ローカルに保存された戦果、資源、遠征記録をすべて消去します。この操作は元に戻せません。';

  @override
  String get clearLogbookConfirmTitle => '航海日誌データの消去';

  @override
  String get clearLogbookConfirmDesc =>
      '航海日誌のデータをすべて消去しますか？蓄積された戦果や資源統計の記録がすべて削除されます。この操作は元に戻せません。';

  @override
  String get logbookCleared => '航海日誌データをすべて消去しました';

  @override
  String get antiCatbomb => '通信エラー保護 (防猫)';

  @override
  String get antiCatbombDesc =>
      '有効にすると、通信エラーでゲームのAPIが失敗した場合、エラー画面 (猫) を出さずに自動で再試行します。';

  @override
  String get close => '閉じる';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get waitingForData => 'データ待機中';

  @override
  String get fleetNoShips => '現在の艦隊に艦娘がいません';

  @override
  String get unorganized => '未編成';

  @override
  String get speed => '速力';

  @override
  String get totalLevel => '合計Lv';

  @override
  String get firepower => '火力';

  @override
  String get torpedo => '雷装';

  @override
  String get antiAir => '対空';

  @override
  String get antiSub => '対潜';

  @override
  String get airPower => '制空';

  @override
  String get los => '索敵';

  @override
  String get avgCondition => '平均疲労';

  @override
  String get losDetail => '索敵詳細';

  @override
  String get totalLos => '索敵合計';

  @override
  String get specialAttack => '特殊攻撃';

  @override
  String get unknownShip => '未知の艦娘';

  @override
  String get unknownClass => '未知の艦種';

  @override
  String get needsResupply => '補給が必要';

  @override
  String get fuel => '燃料';

  @override
  String get ammo => '弾薬';

  @override
  String get hp => '耐久';

  @override
  String get waitingForEquip => '装備データ待機中';

  @override
  String get fastSpeed => '高速';

  @override
  String get slowSpeed => '低速';

  @override
  String get gotIt => 'OK';

  @override
  String get unknownEquip => '未知の装備';

  @override
  String get noBonusStats => 'ボーナスステータスなし';

  @override
  String get condition => '疲労';

  @override
  String get noExpeditionFleet => '遠征中の艦隊はありません';

  @override
  String get expeditionInProgress => '遠征中';

  @override
  String get progress => '進行度';

  @override
  String get unlocked => '未開放';

  @override
  String get notRepairing => '入渠していません';

  @override
  String get repairProgress => '修理進行度';

  @override
  String get cost => '消費';

  @override
  String get notConstructing => '建造していません';

  @override
  String get lsc => '大型艦建造';

  @override
  String get normalConstruct => '通常建造';

  @override
  String get constructing => '建造中';

  @override
  String get constructProgress => '建造進行度';

  @override
  String get constructComplete => '建造完了';

  @override
  String get allRatings => 'すべての評価';

  @override
  String get noBattleRecords => '戦闘記録がありません';

  @override
  String get autoRecordHint => '出撃後自動で記録されます';

  @override
  String get enemyFleet => '敵艦隊';

  @override
  String get thisSortie => '今回の出撃';

  @override
  String get historicalRecords => '歴史戦果';

  @override
  String get resourceTrend => '資源推移';

  @override
  String get expeditionIncome => '遠征収益';

  @override
  String get noHistoricalRecords => '歴史戦果がありません';

  @override
  String get none => 'なし';

  @override
  String get unknownNode => '未知のマス';

  @override
  String get noResourceRecords => '資源記録がありません';

  @override
  String get resourceTrend24h => '24時間';

  @override
  String get resourceTrend7d => '7日';

  @override
  String get resourceTrend30d => '30日';

  @override
  String get resourceTrendAll => 'すべての記録';

  @override
  String get resourceTrendMainGroup => '主要資源';

  @override
  String get resourceTrendAuxGroup => '補助資源';

  @override
  String get gadgetBypass => 'ゲームクライアント資源迂回（実験的）';

  @override
  String get gadgetBypassDesc =>
      '静的クライアント資源サーバーが制限された場合のみミラーを使用します。DMMログイン、Cookie、ゲームデータAPIは変更せず、無効時は完全に迂回します。';

  @override
  String get gadgetBypassEnable => '迂回を有効にする';

  @override
  String get gadgetBypassEndpoint => 'ミラーエンドポイント';

  @override
  String get endpointCustom => 'カスタム';

  @override
  String get gadgetBypassStatusOn => '有効';

  @override
  String get gadgetBypassStatusOff => '無効';

  @override
  String get gadgetBypassUnsupported => 'この端末では非対応（Android 8.0+ が必要）';

  @override
  String get gadgetBypassClearCache => 'キャッシュをクリア';

  @override
  String get gadgetBypassError => '迂回設定に失敗しました';

  @override
  String get gadgetBypassDiagnose => '403 とミラー接続を確認';

  @override
  String get gadgetBypassDiagnosing => '診断中...';

  @override
  String get gadgetBypassW00g => 'クライアントサーバー (w00g)';

  @override
  String get gadgetBypassEndpointProbe => 'ミラーエンドポイント';

  @override
  String get gadgetBypassKcsapi => 'ゲームデータAPI (kcsapi)';

  @override
  String get gadgetBypassReachable => '接続OK';

  @override
  String get gadgetBypassUnreachable => '接続不可';

  @override
  String get resourceTrendChart => '資源推移 (直近 100 件)';

  @override
  String get steel => '鋼材';

  @override
  String get bauxite => 'ボーキ';

  @override
  String get noExpeditionRecords => '遠征記録がありません';

  @override
  String get expeditionIncomeChart => '遠征収益統計 (直近 7 日間)';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langJa => '日本語';

  @override
  String get node => 'マス';

  @override
  String get friend => '自軍';

  @override
  String get enemy => '敵軍';

  @override
  String get drop => 'ドロップ';

  @override
  String get inExpedition => '遠征中';

  @override
  String get unknownProgress => '進行度不明';

  @override
  String get waitingForPortData => '母港データ待機中';

  @override
  String get waitingForPortDataDescription => '母港に移動するかリロードすると更新されます';

  @override
  String get fleetNotFormed => '未編成';

  @override
  String get fleetStandby => '母港待機';

  @override
  String get shipsCount => '隻';

  @override
  String get noValue => 'なし';

  @override
  String get lineOfSight => '索敵';

  @override
  String get averageCondition => '平均疲労';

  @override
  String get losDetails => '索敵詳細';

  @override
  String get unknownShipType => '未知の艦種';

  @override
  String get needsSupply => '補給が必要';

  @override
  String get equipmentDataWaiting => '装備データ待機中';

  @override
  String get highSpeed => '高速';

  @override
  String get lowSpeed => '低速';

  @override
  String get unknownEquipment => '未知の装備';

  @override
  String get noAdditionalStats => 'ボーナスステータスなし';

  @override
  String get fatigue => '疲労';
}
