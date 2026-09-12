// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get questCompletionNotice => '達成した任務があります';

  @override
  String questCompletionCount(int count) {
    return '達成済み・報酬未受領の任務が$count件';
  }

  @override
  String get resourceTrend90d => '90日';

  @override
  String get resourceTrendInventoryTitle => '在庫推移';

  @override
  String get resourceTrendCustomize => '表示する資源';

  @override
  String get resourceTrendAtLeastOne => '資源を1つ以上選んでください';

  @override
  String get resourceTrendBuildMaterial => '高速建造材';

  @override
  String get resourceTrendRepairMaterial => '高速修復材';

  @override
  String get resourceTrendDevMaterial => '開発資材';

  @override
  String get resourceTrendImproveMaterial => '改修資材';

  @override
  String get resourceTrendLatest => '最新の在庫';

  @override
  String get resourceTrendChange => '期間の増減';

  @override
  String resourceTrendBaseline(String time) {
    return '増減の基準：$time JST';
  }

  @override
  String resourceTrendObserved(String time) {
    return '最終記録：$time JST';
  }

  @override
  String get resourceTrendPartial => '開始時点の記録がないため、最初の記録から増減を計算';

  @override
  String get resourceTrendInsufficient => '比較できる記録が不足しています';

  @override
  String get resourceTrendNoPeriodData => 'この期間には資源の記録がありません';

  @override
  String get resourceTrendLoadError => '資源の記録を読み込めませんでした';

  @override
  String get resourceTrendSaveError => '資源の表示設定を保存できませんでした';

  @override
  String get resourceTrendInspect => 'スライドで確認';

  @override
  String get resourceTrendExpand => 'グラフを拡大';

  @override
  String get resourceTrendSampled => '長期間のグラフは極値を保持し、選択時は実際の抽出記録を表示';

  @override
  String get resourceTrendLocalScale => '縦軸は在庫の範囲に合わせて拡大・縮小';

  @override
  String get resourceTrendBaseShort => '基準';

  @override
  String get diagnosticLoggingSection => 'クライアント診断ログ';

  @override
  String get diagnosticLoggingTitle => 'クライアント診断ログを記録';

  @override
  String get diagnosticLoggingDesc =>
      '性能とエラーの概要のみを記録し、アカウント、パスワード、ログイン情報は含みません';

  @override
  String get diagnosticPrivacyTitle => 'プライバシー保護診断';

  @override
  String get diagnosticPrivacyDesc =>
      'エクスポート前に内容を再検査します。ログにはアカウント、パスワード、Cookie、トークン、リクエスト本文、レスポンス本文、チャット内容、スクリーンショットを記録せず、自動送信もしません。';

  @override
  String get diagnosticStatusEnabled => '記録中';

  @override
  String get diagnosticStatusDisabled => '記録停止中';

  @override
  String diagnosticStorageUsage(String size) {
    return 'ローカルログ使用量：$size';
  }

  @override
  String get exportDiagnosticFile => '診断ファイルを書き出す';

  @override
  String get saveDiagnosticFile => '端末に保存';

  @override
  String get shareDiagnosticFile => '診断ファイルを共有';

  @override
  String get diagnosticSaveConfirmTitle => '診断ファイルを保存しますか？';

  @override
  String get diagnosticSaveConfirmDesc =>
      'プライバシーチェック済みの JSON ファイルを作成します。保存先フォルダーのみを選択してください。ファイル名は自動生成され、変更できません。';

  @override
  String get diagnosticSaveAction => 'フォルダーを選択';

  @override
  String diagnosticSaveSucceeded(String fileName) {
    return '保存しました：$fileName';
  }

  @override
  String get diagnosticSaveFailed => '診断ファイルの保存に失敗しました';

  @override
  String get diagnosticShareConfirmTitle => '診断ファイルを共有しますか？';

  @override
  String get diagnosticShareConfirmDesc =>
      'プライバシーチェック済みの JSON ファイルを作成し、システムの共有画面を開きます。送信先をご確認ください。';

  @override
  String get diagnosticShareAction => '共有';

  @override
  String get diagnosticShareFailed => '診断ファイルの共有に失敗しました';

  @override
  String get clearDiagnosticData => '診断ログを削除';

  @override
  String get diagnosticExportConfirmTitle => '診断ファイルを書き出しますか？';

  @override
  String get diagnosticExportConfirmDesc =>
      '1つの JSON ファイルを作成し、システムの共有画面を開きます。ファイルにはクライアント性能、エラー概要、匿名の端末実行情報のみが含まれます。送信先をご確認ください。';

  @override
  String get diagnosticExportAction => '書き出す';

  @override
  String get diagnosticClearConfirmTitle => '診断ログを削除しますか？';

  @override
  String get diagnosticClearConfirmDesc => '端末上の診断ログを完全に削除します。';

  @override
  String get diagnosticExportFailed => '診断ファイルの書き出しに失敗しました';

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
  String get battleRecords => '航海日誌';

  @override
  String get settings => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get layoutSettings => 'UIとレイアウト';

  @override
  String get gameAreaRatio => 'ゲーム画面の比率';

  @override
  String get infoPanelWidth => '情報パネルの幅（縦画面では無効）';

  @override
  String get autoZoom => '推奨表示比率を適用（ゲームとメニューの比率 65:35）';

  @override
  String get enhancedDamagePulse => '損傷パルス表示を強化';

  @override
  String get enhancedDamagePulseDesc =>
      '小破・中破・大破に応じて色、速度、艦娘画像内の光を強調します。オフにすると通常表示になります。';

  @override
  String get informationPanelOnLeft => '機能エリアを左側に表示';

  @override
  String get informationPanelOnLeftDesc => 'オフの場合は右側に表示します。縦画面では上下配置を維持します。';

  @override
  String get workspaceMenuOnRight => 'メニューバーを右側に表示';

  @override
  String get workspaceMenuOnRightDesc => 'オフの場合はメニューバーを左側に表示します。';

  @override
  String get language => '言語 (Language)';

  @override
  String get networkSettings => 'ネットワーク設定';

  @override
  String get networkStatus => 'ネットワーク状態';

  @override
  String get proxyNotSupported =>
      'この端末の Android System WebView はアプリ内プロキシ設定に対応していません。\nシステムネットワークまたは端末全体に適用する VPN を使用してください。';

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
  String get currentSavedMode => '現在保存されているモード';

  @override
  String get vpnStatus => 'VPN 状態';

  @override
  String get vpnActive => 'VPNが検出されました';

  @override
  String get vpnInactive => 'VPNは検出されていません';

  @override
  String get testConnection => '接続テスト';

  @override
  String get applySettings => '設定を適用してゲームを再読み込み';

  @override
  String get restoreSystemNetwork => 'システムネットワークに戻す';

  @override
  String get gameSafety => '大破警告';

  @override
  String get blockSortieTitle => '大破進撃ストッパー';

  @override
  String get blockSortieDesc =>
      '出撃・進撃前に、艦隊に大破した艦娘（旗艦以外・ダメコン未装備）がいる場合、通信リクエストを強制的に遮断して警告を表示します。オンにすることを強く推奨します。';

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
      'ローカルにキャッシュされた個人情報除去済みの任務データを消去します。アプリ再起動後にゲーム内の任務画面で再取得する必要があります。';

  @override
  String get clearWebCache => 'ブラウザのWebキャッシュを消去';

  @override
  String get clearWebCacheDesc => 'WebView エンジンが保持する一時的なページやスクリプトデータを消去します。';

  @override
  String get baseSenkaResetTitle => '素戦果をリセット';

  @override
  String get baseSenkaResetDesc =>
      '今月の累計素戦果を 0.00 にします。EO・任務・その他の戦果データには影響しません。';

  @override
  String get baseSenkaResetConfirmTitle => '素戦果をリセット';

  @override
  String get baseSenkaResetConfirmDesc =>
      '今月の累計素戦果をリセットしますか？日別の EO・任務報酬は保持され、以後の経験値増分は 0.00 から加算されます。';

  @override
  String get baseSenkaResetSuccess => '今月の累計素戦果をリセットしました';

  @override
  String get baseSenkaManualTitle => '素戦果を手動入力';

  @override
  String baseSenkaCurrentValue(String value) {
    return '今月の累計：$value 戦果';
  }

  @override
  String get baseSenkaManualDialogTitle => '今月の累計素戦果を入力';

  @override
  String get baseSenkaManualInputLabel => '今月の累計素戦果';

  @override
  String get baseSenkaManualInvalid => '0 以上の数値を小数点以下 2 桁まで入力してください';

  @override
  String baseSenkaSetSuccess(String value) {
    return '今月の累計素戦果を $value に設定しました';
  }

  @override
  String get baseSenkaSaveFailed => '素戦果を保存できませんでした。もう一度お試しください';

  @override
  String get senkaTodaySorties => '本日の出撃';

  @override
  String get fleetBrief => '編成情報';

  @override
  String get expeditionBrief => '遠征情報';

  @override
  String get repairBrief => '修理概要';

  @override
  String get repairDockMode => '入渠';

  @override
  String get anchorageRepairMode => '泊地';

  @override
  String get idle => '空き';

  @override
  String get inactive => '待機';

  @override
  String get repairing => '修理中';

  @override
  String get outOfRepairRange => '修理範囲外';

  @override
  String get unableToRepair => '修理不可';

  @override
  String get constructionBrief => '建造情報';

  @override
  String get questBrief => '任務情報';

  @override
  String get preSortieCheck => '出撃前検査';

  @override
  String get sortieCheckShipsMode => '艦娘';

  @override
  String get sortieCheckMapsMode => '海域';

  @override
  String get mapHpGauges => '海域ゲージ';

  @override
  String get noMapGaugeData => '海域ゲージデータがありません';

  @override
  String get noMapGaugeDataHint => 'ゲーム内で出撃海域を開いて同期してください';

  @override
  String get showClearedMaps => '攻略済みを表示';

  @override
  String get allMapsCleared => 'すべての海域を攻略済みです';

  @override
  String get forecast => '戦闘予測';

  @override
  String get waitingForSortieData => '出撃データ待機中';

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
  String get clearWebCacheConfirmTitle => 'ブラウザのWebキャッシュを消去';

  @override
  String get clearWebCacheConfirmDesc =>
      'ブラウザのWebキャッシュを消去しますか？WebView が保持する一時データを削除します。ダウンロード済みのローカルリソースには影響しません。';

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
  String get aboutSubtitle => 'バージョン 学習版 1.0.2 · 免責事項 · 更新の確認';

  @override
  String get version => 'バージョン 学習版 1.0.2';

  @override
  String get disclaimerTitle => '免責事項 (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      '本プロジェクトは、プログラミング技術の交流と学習を目的として開発された、完全非営利かつ非公式のサードパーティ製汎用ブラウザツールです。「艦隊これくしょん -艦これ-」の公式や関連権利者とは一切関係ありません。';

  @override
  String get disclaimerP2 =>
      '本ソフトウェアは、ゲームサーバーの通信データに介入せず、遮断、再送、改ざんも行わず、プレイヤーに代わってゲーム操作を実行しません。原作者はソフトウェアの品質について、明示的にも黙示的にもいかなる保証も行いません（バグが一切ないこと、適合性、システムの安定性の保証を含みますが、これらに限りません）。';

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
  String get externalLinkOpenFailed => 'リンクを開けません。ブラウザがインストールされているか確認してください。';

  @override
  String get noUpdateLog => '更新ログなし';

  @override
  String get battleWarningOff => 'オフ';

  @override
  String get battleWarningConfirm => '確認ダイアログ';

  @override
  String get logoutSnackbar => 'ログアウトしてアカウント情報を消去しました。';

  @override
  String get logoutConfirmTitle => 'ログアウトしてアカウント情報を消去';

  @override
  String get logoutConfirmDesc =>
      'アプリ内ゲームページの Cookie、ローカルストレージ、キャッシュを消去してログイン画面へ戻ります。続行しますか？';

  @override
  String get logoutSucceeded => 'ログアウトしました。再度ログインしてください。';

  @override
  String get logoutFailed => 'ログアウトに失敗しました。しばらくしてからもう一度お試しください。';

  @override
  String get questCacheCleared => '任務データのローカルキャッシュを消去しました';

  @override
  String get webCacheCleared => 'ブラウザのWebキャッシュを消去しました';

  @override
  String get clearLogbook => '航海日誌データの消去';

  @override
  String get clearLogbookDesc =>
      'ローカルに保存された出撃、遠征、建造、開発、除籍、資源記録を消去します。この操作は元に戻せません。';

  @override
  String get clearLogbookConfirmTitle => '航海日誌データの消去';

  @override
  String get clearLogbookConfirmDesc =>
      '航海日誌のデータをすべて消去しますか？出撃、遠征、建造、開発、除籍、資源記録が削除されます。この操作は元に戻せません。';

  @override
  String get logbookCleared => '航海日誌データをすべて消去しました';

  @override
  String get antiCatbomb => '通信エラー保護 (防猫)';

  @override
  String get antiCatbombDesc =>
      '有効にすると、ネットワーク切断などでゲームのリクエストが失敗した場合、アプリがゲームを一時停止して再試行を続け、エラー画面（猫）が出るのを防ぎます。';

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
  String get avgCondition => '最低疲労';

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
  String get waitingForEquip => '装備データの更新待ち';

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
  String get autoRecordHint => '出撃後に自動で記録されます。追加の操作は不要です';

  @override
  String get thisSortie => '今回の出撃';

  @override
  String get historicalRecords => '過去の戦果';

  @override
  String get resourceTrend => '資源推移';

  @override
  String get expeditionIncome => '遠征収益';

  @override
  String get noHistoricalRecords => '過去の戦果はありません';

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
  String get resourceTrendMainGroup => '4種の資源';

  @override
  String get resourceTrendAuxGroup => '補助資源';

  @override
  String get gadgetBypass => 'ゲームリソースミラーとIP制限回避';

  @override
  String get gadgetBypassDesc =>
      '有効にすると、ゲームクライアントの静的リソースをミラー経由で読み込みます。DMM の地域制限への互換処理は自動で動作し、このスイッチの影響を受けません。';

  @override
  String get gadgetBypassEnable => 'ミラー経由の読み込みを有効にする';

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
  String get averageCondition => '最低疲労';

  @override
  String get moraleRecoveryCountdown => '回復カウントダウン';

  @override
  String get moraleRecovered => '回復済み';

  @override
  String get toggleMoraleMetric => '最低疲労と回復カウントダウンを切り替える';

  @override
  String get losDetails => '索敵詳細';

  @override
  String get airPowerDetails => '制空詳細';

  @override
  String get minimumValue => '最小';

  @override
  String get maximumValue => '最大';

  @override
  String get withoutBonus => '熟練度補正なし';

  @override
  String get showAirPowerDetails => '制空詳細を表示';

  @override
  String get unknownShipType => '未知の艦種';

  @override
  String get needsSupply => '補給が必要';

  @override
  String get equipmentDataWaiting => '装備データの更新待ち';

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

  @override
  String get startupUpdateTitle => '新しいバージョン';

  @override
  String get backgroundAudio => 'バックグラウンドで音声を再生';

  @override
  String get backgroundAudioDesc => 'オンにすると、アプリがバックグラウンドに移動してもゲーム音声を再生します。';

  @override
  String get backgroundGameRetention => 'バックグラウンドでゲームを維持';

  @override
  String get backgroundGameRetentionDesc =>
      'バックグラウンドに移動したとき常駐通知を表示し、ゲームセッションがシステムに終了されにくくします。電池消費が増える場合があります。';

  @override
  String get backgroundGameRetentionNotificationTitle => '矢矧はバックグラウンドで実行中';

  @override
  String get backgroundGameRetentionNotificationBody =>
      'ゲームセッションを維持中 · タップしてゲームに戻る';

  @override
  String get screenAwake => '画面を常にオン';

  @override
  String get screenAwakeDesc => 'オンにすると、アプリの使用中は画面が自動消灯しません。電池消費が増える場合があります。';

  @override
  String get gameToolbar => 'ゲームツールバー';

  @override
  String get toolbarAutoHide => '自動的に隠す';

  @override
  String get toolbarPersistent => '常に表示';

  @override
  String get back => '戻る';

  @override
  String get reload => '再読み込み';

  @override
  String get home => 'ホームに戻る';

  @override
  String get enterDmm => 'DMM ログインへ';

  @override
  String get enableGameAudio => 'ゲーム音声をオン';

  @override
  String get disableGameAudio => 'ゲーム音声をオフ';

  @override
  String get takeScreenshot => 'スクリーンショット';

  @override
  String get screenshotSaving => 'ゲーム画面を保存しています…';

  @override
  String get fitGameScreen => '表示を画面に合わせる';

  @override
  String get collapseToolbar => 'ツールバーを閉じる';

  @override
  String get editDone => '編集を完了';

  @override
  String get retryWithSystemNetwork => 'システムネットワークで再試行';

  @override
  String get displayMode => '表示モード';

  @override
  String get displayAuto => '自動';

  @override
  String get displayLandscape => '横画面';

  @override
  String get displayPortrait => '縦画面';

  @override
  String get allRanks => 'すべての評価';

  @override
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  ) {
    return '味方 $friendAlive/$friendTotal　敵 $enemyAlive/$enemyTotal';
  }

  @override
  String dropLabel(String name) {
    return 'ドロップ：$name';
  }

  @override
  String get item => 'アイテム';

  @override
  String get friendFinalStatus => '味方艦隊の最終状態';

  @override
  String get enemyFinalStatus => '敵艦隊の最終状態';

  @override
  String get enemyFleet => '敵艦隊';

  @override
  String airStateLabel(String label) {
    return '制空：$label';
  }

  @override
  String get postBattleWarningTitle => '大破安全警告';

  @override
  String get postBattleWarningHeadline => '出撃艦隊に大破艦がいます！';

  @override
  String get postBattleWarningBody =>
      '大破艦がいる状態で進撃しました！直ちに操作を止め、次の戦闘へ進まないでください。';

  @override
  String get acknowledgeAndRetreat => '了解しました';

  @override
  String get postBattleWarningBanner => '戦闘後の安全警告：出撃艦隊に大破艦がいます。撤退してください！';

  @override
  String get noActiveExpedition => '遠征中の艦隊はありません';

  @override
  String get noSortieWarnings => '出撃警告はありません';

  @override
  String preSortieCriticalWarning(String fleetName) {
    return '$fleetName に大破艦がいます。出撃を中止してください！';
  }

  @override
  String preSortieSupplyWarning(String fleetName) {
    return '$fleetName に未補給の艦娘がいます';
  }

  @override
  String preSortieFatigueWarning(String fleetName) {
    return '$fleetName に疲労が回復していない艦娘がいます';
  }

  @override
  String preSortieMainEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 装備不足（主スロット）：$shipNames';
  }

  @override
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 装備不足（補強増設スロット）：$shipNames';
  }

  @override
  String get noPinnedQuests => '現在進行中の任務はありません';

  @override
  String get questsNeedSync => '任務画面を開いて情報を同期してください';

  @override
  String get waitingQuestData => '任務データ待機中';

  @override
  String get waitingQuestDataDesc => 'ゲーム内の任務一覧を開くと、受注中の任務が自動的に同期されます';

  @override
  String get diagnosticsAndAbout => '診断とアプリ情報';

  @override
  String get safetyBoundary => '安全上の制限';

  @override
  String get applyingNetworkSettings => 'ネットワーク設定を適用しています…';

  @override
  String networkSettingsApplied(String message) {
    return 'ネットワーク設定を適用しました：$message';
  }

  @override
  String get clearingProxy => 'アプリ内プロキシを解除しています…';

  @override
  String get systemNetworkRestored => 'システムネットワークに戻しました。';

  @override
  String screenshotSaved(String path) {
    return 'ゲーム画面をギャラリーに保存しました：$path';
  }

  @override
  String get screenshotFailed => 'ゲーム画面の保存に失敗しました。しばらくしてからもう一度お試しください。';

  @override
  String startupUpdateMessage(String version) {
    return 'ヤハギ $version がリリースされました。';
  }

  @override
  String get gameStatusError => 'ゲーム状態エラー';

  @override
  String get gameStatusErrorDesc => 'Web ページまたは取得状態に異常があります。設定の診断情報を確認してください。';

  @override
  String get browserOnlyCaptureOff => '閲覧専用モード · データ取得オフ';

  @override
  String get browserOnlyCaptureOffDesc => 'ゲームは動作を続けますが、艦隊・任務・戦闘情報の更新は停止します。';

  @override
  String capturedCount(int count) {
    return '$count 件取得済み';
  }

  @override
  String get waitingKcsapi => '/kcsapi/ の応答を待機中';

  @override
  String get ignoredNonTargetMessage => '対象外メッセージを無視しました';

  @override
  String get readOnlyNoActions => '読み取り専用';

  @override
  String get readOnlyNoActionsDesc => 'クリック、補給、編成、出撃、任務受領を自動実行しません。';

  @override
  String get noCookieRead => 'Cookie を読み取りません';

  @override
  String get noCookieReadDesc => 'JS ブリッジのメッセージは API パス、応答本文、時刻のみを含みます。';

  @override
  String get browserIdle => 'Web ページ待機中';

  @override
  String get browserLoading => 'Web ページ読み込み中';

  @override
  String get browserReady => 'Web ページ準備完了';

  @override
  String get browserFailed => 'Web ページ読み込み失敗';

  @override
  String get capturePreparing => 'ゲーム API 取得を準備中';

  @override
  String get captureReady => '取得準備完了';

  @override
  String get captureActive => 'ゲーム API を取得中';

  @override
  String get captureUnsupported => '現在の WebView はフレーム間取得に対応していません';

  @override
  String get captureFailed => 'ゲーム API 取得の起動に失敗しました';

  @override
  String get captureCheckingDesc => 'Android WebView の取得能力を確認しています。';

  @override
  String get captureReadyDesc => '/kcsapi/ の応答待機中です。ゲームは通常どおり操作できます。';

  @override
  String get portCaptureVerified => '母港 API の確認に成功しました';

  @override
  String get captureReceived => 'ゲーム API を受信しました。';

  @override
  String captureLatest(String path) {
    return '最新の取得：$path';
  }

  @override
  String get captureUnsupportedDesc => 'ゲームは動作しますが、現在の端末では Web 閲覧のみ利用できます。';

  @override
  String get captureFailedDesc => 'ゲームは動作します。ページを再読み込みして再試行できます。';

  @override
  String networkApplyFailed(String code, String message) {
    return '設定に失敗しました [$code]：$message';
  }

  @override
  String networkRestoreFailed(String code, String message) {
    return '復元に失敗しました [$code]：$message';
  }

  @override
  String get tcpConnection => 'TCP 接続';

  @override
  String get gameService => 'ゲームサービス';

  @override
  String get externalNetwork => 'Google（外部ネットワーク）';

  @override
  String get statusUnknown => '不明';

  @override
  String get statusSuccess => '成功';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusSkipped => 'スキップ';

  @override
  String get formula33 => '33式';

  @override
  String fatigueValue(int value) {
    return '疲労 $value';
  }

  @override
  String get fcdMapSectionTitle => 'データ更新';

  @override
  String get fcdMapDataTitle => '戦闘予測データ';

  @override
  String fcdMapDataVersion(String version) {
    return 'データバージョン：$version';
  }

  @override
  String fcdMapLastChecked(String time) {
    return '最終確認：$time';
  }

  @override
  String get fcdMapNeverChecked => '最終確認：未確認';

  @override
  String fcdMapSource(String source) {
    return '更新元：$source';
  }

  @override
  String get fcdMapAttribution => 'データ提供：poi FCD（MIT）';

  @override
  String get fcdMapCheckUpdates => '戦闘予測データの更新を確認';

  @override
  String get fcdMapUpToDate => '戦闘予測データは最新です。';

  @override
  String fcdMapUpdated(String oldVersion, String newVersion) {
    return '戦闘予測データを $oldVersion から $newVersion に更新し、すぐに適用しました。';
  }

  @override
  String get fcdMapNetworkError => 'データ更新元に接続できません。しばらくしてから再試行してください。';

  @override
  String get fcdMapValidationError => 'ダウンロードしたデータを検証できなかったため、現在のバージョンを保持しました。';

  @override
  String get fcdMapStorageError => 'データを保存できなかったため、現在のバージョンを保持しました。';

  @override
  String get questCatalogDataTitle => '任務データ';

  @override
  String questCatalogDataVersion(String version) {
    return 'データバージョン：$version';
  }

  @override
  String get questCatalogNeverChecked => '最終確認：未確認';

  @override
  String questCatalogLastChecked(String time) {
    return '最終確認：$time';
  }

  @override
  String get questCatalogCheckUpdates => '任務データの更新を確認';

  @override
  String get questCatalogUpToDate => '任務データは最新です。';

  @override
  String questCatalogUpdated(String oldVersion, String newVersion) {
    return '任務データを $oldVersion から $newVersion に更新し、すぐに適用しました。';
  }

  @override
  String get questCatalogNetworkError => '任務データの更新元に接続できません。後でもう一度お試しください。';

  @override
  String get questCatalogValidationError =>
      'ダウンロードした任務データを検証できませんでした。現在のバージョンを保持します。';

  @override
  String get questCatalogStorageError => '任務データを保存できませんでした。現在のバージョンを保持します。';

  @override
  String get gameFrameRateTitle => 'ゲームフレームレート';

  @override
  String get gameFrameRateAutomatic => '自動';

  @override
  String get gameFrameRateStable60 => '60 FPS';

  @override
  String get gameFrameRateStable60Desc => '常に 60 FPS で動作し、自動的に下げません。';

  @override
  String get gameFrameRateStable30 => '30 FPS';

  @override
  String get gameFrameRateStable30Desc => '常に 30 FPS で動作し、消費電力と発熱を抑えます。';

  @override
  String get gameFrameRateHighRefresh => '高リフレッシュ';

  @override
  String get gameFrameRateHighRefreshDesc =>
      '60 FPS の制限を解除し、画面のリフレッシュレートに追従します。消費電力や発熱が増える場合があります。';

  @override
  String get gameFrameRateHighRefreshDialogTitle => '高リフレッシュモードを有効にしますか？';

  @override
  String get gameFrameRateHighRefreshDialogBody =>
      '高リフレッシュはゲームの動作フレームレートを変更するため、消費電力や発熱の増加、アニメーションの異常が発生する可能性があり、アカウントに関する未知のリスクもあります。結果についてはご自身で責任を負ってください。';

  @override
  String get gameFrameRateHighRefreshDialogConfirm => 'リスクを理解して有効にする';

  @override
  String get gameFrameRateAutomaticDesc =>
      '上限を 60 FPS とし、不安定な動作が続く場合や、システムの省電力モードが有効な場合、端末の発熱時には自動的に 30 FPS へ下げます。';

  @override
  String get gameFrameRateUnsupported =>
      '現在の Android WebView はフレームレート調整に対応していないため、ゲーム本来のフレームレートを維持します。';

  @override
  String get gameRenderingModeTitle => 'ゲーム描画モード';

  @override
  String get gameRenderingModeStandard => '軽量モード';

  @override
  String get gameRenderingModeStandardDesc =>
      'Flutter PlatformView + Texture Layer + WebGL。一部の合成負荷を軽減しますが、一部の端末で表示やタッチの互換性問題が発生する場合があります。';

  @override
  String get gameRenderingModeCompatibility => 'バランスモード';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Flutter PlatformView + Hybrid Composition + WebGL。ゲーム性能と端末互換性を両立します。';

  @override
  String get gameRenderingModeCanvas => '互換モード';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Flutter PlatformView + Hybrid Composition + Canvas。WebGL を回避し、GPU / WebGL の互換性問題を優先的に解決します。描画性能が低下する場合があります。';

  @override
  String get gameRenderingModeNativeActivity => 'ネイティブ独立描画（推奨）';

  @override
  String get gameRenderingModeNativeActivityDesc =>
      'Activity Direct WebView + WebGL。理論上、合成負荷が低く、ネイティブ互換性に優れています。';

  @override
  String get gameRenderingModeConfirmTitle => 'ゲーム描画モードを切り替えますか？';

  @override
  String get gameRenderingModeConfirmMessage =>
      '描画モードを切り替えるとアプリが自動的に再起動し、ゲームページが再読み込みされます。進行中の操作を終了してから切り替えてください。';

  @override
  String get gameRenderingModeBattleWarning =>
      '戦闘中の可能性があります。今切り替えると戦闘画面が中断されるため、戦闘終了後の変更を推奨します。';

  @override
  String get gameRenderingModeChanging => 'ゲームページを再構築しています…';

  @override
  String get gameRenderingModeApplied => '描画モードを切り替えました。';

  @override
  String get gameRenderingModeFailed => '切り替えに失敗しました。現在の設定を維持するか、安全なモードへ戻しました。';

  @override
  String get nativeGameSurfaceSwitchRenderingModeHint =>
      '現在の端末はこのモードに対応していません。左側のメニューをスクロールし、【設定 - 画面と音声】で描画モードを切り替えてください。';

  @override
  String nativeGameSurfacePageInitializationFailed(
    String stage,
    String errorType,
  ) {
    return 'ゲーム画面の初期化に失敗しました [$stage]：$errorType';
  }

  @override
  String get senka => '戦果';

  @override
  String get ownedInventory => '保有一覧';

  @override
  String get improvement => '改修';

  @override
  String get briefing => '概要';

  @override
  String get check => 'チェック';

  @override
  String get restoreDefaultOrder => '既定の並び順に戻す';

  @override
  String get sortAscending => '昇順';

  @override
  String get sortDescending => '降順';

  @override
  String sortPriority(int priority) {
    return '第$priority優先';
  }

  @override
  String get sortLockedState => 'ロック済み';

  @override
  String get sortTemporaryState => '一時ソート';

  @override
  String get sortHeaderHint => '選択で並び順を切替。長押しまたは Shift+Enter でロック';

  @override
  String get sortHeaderLockedHint => '選択で昇順・降順を切替。長押しまたは Shift+Enter でロック解除';

  @override
  String get sortLockAction => '次の優先順位としてロック';

  @override
  String get sortUnlockAction => '現在のソートロックを解除';

  @override
  String get settingsTabScreen => '画面と音声';

  @override
  String get settingsTabSound => 'サウンド';

  @override
  String get settingsTabBattle => '戦闘';

  @override
  String get settingsTabNotification => '通知';

  @override
  String get settingsTabNetwork => 'ネットワーク';

  @override
  String get settingsTabData => 'データ';

  @override
  String get settingsTabAboutSupport => '情報';

  @override
  String get notificationSectionSystem => 'システム通知の状態';

  @override
  String get notificationSectionSystemDesc =>
      '通知と正確なアラームの権限を許可すると、画面ロック中やバックグラウンドでも遠征・入渠などの通知を定刻に表示し、システムの省電力制御による遅延を防げます。該当項目をタップすると、システム設定で直接有効にできます。';

  @override
  String get notificationPermissionGranted => '通知権限は許可されています';

  @override
  String get notificationPermissionDenied => '通知権限が許可されていません';

  @override
  String get notificationExactAlarmGranted => '正確なアラームは許可されています';

  @override
  String get notificationExactAlarmDenied => '正確なアラームは未許可です。省電力互換モードを使用します';

  @override
  String get notificationChannelsEnabled => '通知チャンネルは利用可能です';

  @override
  String get notificationChannelsDisabled => '通知チャンネルがシステムで無効です';

  @override
  String get notificationSectionGeneral => '全体通知サービス';

  @override
  String get notificationEnableMaster => '通知サービスを有効化';

  @override
  String get notificationSound => '通知音';

  @override
  String get notificationVibration => '振動通知';

  @override
  String get notificationSectionOngoing => 'バックグラウンドで進行状況を常時表示';

  @override
  String get notificationOngoingLive => '常駐リアルタイム進行状況カード';

  @override
  String get notificationProgress => '進捗バー';

  @override
  String get notificationPercent => '割合(%)';

  @override
  String get notificationCountdown => 'カウントダウン';

  @override
  String get notificationSectionTypes => '通知種別とタイミング';

  @override
  String get notificationExpedition => '遠征';

  @override
  String get notificationRepair => '入渠';

  @override
  String get notificationAnchorage => '泊地';

  @override
  String get notificationConstruction => '建造';

  @override
  String get notificationMorale => '疲労 / キラ付け';

  @override
  String get notificationPunctual => '定刻';

  @override
  String get notificationPreempt30s => '30秒前';

  @override
  String get notificationPreempt60s => '60秒前';

  @override
  String get notificationPreempt120s => '2分前';

  @override
  String get notificationRepairPunctual => '定刻';

  @override
  String get notificationAnchorage20m => '20分経過時の初回修理';

  @override
  String get notificationAnchorageFull => '全回復';

  @override
  String get notificationAnchorageBoth => '両方通知';

  @override
  String get frameRateSettingsSection => 'フレームレート設定';

  @override
  String get battleAlertsSection => '戦闘通知';

  @override
  String get battleDamageVibration => '戦闘損傷時の振動通知';

  @override
  String get battleDamageVibrationDesc => '味方艦娘が戦闘中に中破または大破になったとき振動で通知します。';

  @override
  String get battleStatusEffectsSection => '戦闘ステータス効果';

  @override
  String get battleStatusEffectsEnabled => 'ステータス効果を有効化';

  @override
  String get battleStatusEffectsEnabledDesc => '損傷点滅、損傷振動、士気キラキラをまとめてオン／オフします。';

  @override
  String get battleEffectDisplayScope => '画面表示範囲';

  @override
  String get battleEffectDisplayScopeDesc => '損傷点滅と士気キラキラを表示する艦娘画面を選びます。';

  @override
  String get battleEffectScopePredictionOnly => '戦闘予測のみ';

  @override
  String get battleEffectScopeFleetOnly => '編成のみ';

  @override
  String get battleEffectScopeAll => 'すべて';

  @override
  String get battleDamagePulse => '損傷点滅';

  @override
  String get battleDamagePulseDesc => '現在の HP 損傷段階に応じて艦娘画像の枠を点滅させます。';

  @override
  String get battleDamageVibrationEffect => '損傷振動';

  @override
  String get battleDamageVibrationEffectDesc => '味方艦娘が戦闘中に選択した損傷段階へ入ったとき振動します。';

  @override
  String get battleMoraleSparkle => '士気キラキラ効果';

  @override
  String get battleMoraleSparkleDesc =>
      'Cond 50 以上で艦娘画像の周囲に星のアニメーションを表示します。疲労顔と疲労警告には影響しません。';

  @override
  String get battleEffectOff => 'オフ';

  @override
  String get battleEffectMinorOnly => '小破のみ';

  @override
  String get battleEffectModerateOnly => '中破のみ';

  @override
  String get battleEffectHeavyOnly => '大破のみ';

  @override
  String get battleEffectAll => 'すべて有効';

  @override
  String get battlePredictionSection => '戦闘予測';

  @override
  String get battleEnemyPreviewPortraits => '戦闘前の敵艦画像';

  @override
  String get battleEnemyPreviewPortraitsDesc => '戦闘予測に戦闘前の敵艦画像を表示します。';

  @override
  String get battleLastFormationHint => '前回選択した陣形を表示';

  @override
  String get battleLastFormationHintDesc =>
      '出撃マス到達時に、そのマスで前回使用した陣形を戦闘予測に表示します。';

  @override
  String battleLastFormation(String formation) {
    return '前回：$formation';
  }

  @override
  String get improvementDatasetTitle => '改修計画データ';

  @override
  String improvementDatasetVersion(String version) {
    return 'データバージョン $version';
  }

  @override
  String get improvementDatasetNeverChecked => '手動確認はまだ行われていません';

  @override
  String improvementDatasetLastChecked(String time) {
    return '最終確認 $time';
  }

  @override
  String get improvementDatasetManualUpdate => '改修データを手動更新';

  @override
  String improvementDatasetUpToDate(String version) {
    return '最新のデータです（$version）';
  }

  @override
  String improvementDatasetUpdated(String oldVersion, String newVersion) {
    return '改修データを $oldVersion から $newVersion に更新し、画面へ反映しました。';
  }

  @override
  String improvementDatasetNetworkError(String version) {
    return 'ネットワーク接続に失敗したため、ローカルデータ（$version）を使用します。';
  }

  @override
  String improvementDatasetValidationError(String version) {
    return 'リモートデータの検証に失敗したため、ローカルデータ（$version）を維持しました。';
  }

  @override
  String improvementDatasetStorageError(String version) {
    return 'データの保存に失敗したため、ローカルデータ（$version）を維持しました。';
  }

  @override
  String get networkValidationHostEmpty => 'アドレスを入力してください';

  @override
  String get networkValidationControlCharacter => '改行や制御文字は使用できません';

  @override
  String get networkValidationHttpScheme => 'http:// は入力せず、サーバーアドレスのみ入力してください。';

  @override
  String get networkValidationSocksScheme =>
      'socks:// は入力せず、サーバーアドレスのみ入力してください。';

  @override
  String get networkValidationScheme => 'プロトコル名は入力できません';

  @override
  String get networkValidationPath => 'パスは入力できません';

  @override
  String get networkValidationCredentials => 'ユーザー名やパスワードは入力できません';

  @override
  String get networkValidationIpv6 => 'IPv6 アドレスの形式が正しくありません（使用できない文字が含まれています）';

  @override
  String get networkValidationPortEmpty => 'ポート番号を入力してください';

  @override
  String get networkValidationPortDecimal => 'ポート番号に小数は使用できません';

  @override
  String get networkValidationPortNegative => 'ポート番号に負数は使用できません';

  @override
  String get networkValidationPortZero => 'ポート番号に 0 は使用できません';

  @override
  String get networkValidationPortInteger => 'ポート番号は整数で入力してください';

  @override
  String get networkValidationPortRange => 'ポート番号は 1～65535 の範囲で入力してください';

  @override
  String get gadgetBypassRestricted => '制限あり';

  @override
  String get networkProxyOperationBusy => 'プロキシ設定を適用中です';

  @override
  String get networkUnknownProxyMode => '不明なプロキシモードです';

  @override
  String get shipGirl => '艦娘';

  @override
  String get equipment => '装備';

  @override
  String get inventoryTypeSuffix => ' 種類';

  @override
  String get inventoryFilterResults => '絞り込み結果 ';

  @override
  String get inventoryOwned => '保有';

  @override
  String get inventoryUnowned => '未保有';

  @override
  String unownedShipSummary(int count, int excluded) {
    return '$count隻表示・除外済み $excluded隻';
  }

  @override
  String get unownedShipExcludedLabel => '除外済み';

  @override
  String get unownedShipReminderHint =>
      '未選択の艦娘を入手すると通常どおり通知と振動を行い、選択した艦娘は通知しません。';

  @override
  String get clearNewShipExclusions => '除外を解除';

  @override
  String get resetFilter => '絞り込みをリセット';

  @override
  String unownedEquipmentSummary(int count) {
    return '未保有装備を $count個表示';
  }

  @override
  String get otherType => 'その他';

  @override
  String newShipFallbackName(int id) {
    return '艦娘 No.$id';
  }

  @override
  String get newShipAlertTitle => '未保有艦娘を発見';

  @override
  String newShipAlertBody(String names) {
    return '$names、ロックをお忘れなく';
  }

  @override
  String get acknowledge => '了解';

  @override
  String get shipName => '艦名';

  @override
  String get shipType => '艦種';

  @override
  String get level => 'レベル';

  @override
  String get armor => '装甲';

  @override
  String get luck => '運';

  @override
  String get evasion => '回避';

  @override
  String get lockedStatus => 'ロック';

  @override
  String get equipmentName => '装備名';

  @override
  String get equipmentTotalRemaining => '合計（残り）';

  @override
  String get equipmentImprovementProficiency => '改修／熟練度';

  @override
  String get equipmentOfficialId => '公式ID';

  @override
  String get equipmentInstanceId => 'インスタンスID';

  @override
  String get equipmentUsage => '装備状況';

  @override
  String get highSpeedPlus => '高速+';

  @override
  String get all => 'すべて';

  @override
  String get equipmentMainGun => '主砲';

  @override
  String get equipmentSecondaryGun => '副砲／高角砲';

  @override
  String get equipmentMachineGun => '機銃';

  @override
  String get equipmentTorpedo => '魚雷／甲標的';

  @override
  String get equipmentCarrierAircraft => '艦載機';

  @override
  String get equipmentSeaplane => '水上機';

  @override
  String get equipmentLandBasedAircraft => '陸上機';

  @override
  String get equipmentRadar => '電探';

  @override
  String get equipmentLandingTransport => '上陸／輸送';

  @override
  String get equipmentSupport => '補助／その他';

  @override
  String get questAll => '全任務';

  @override
  String get chineseTranslation => '中国語訳';

  @override
  String get searchQuest => '任務を検索';

  @override
  String get filterQuest => '任務を絞り込む';

  @override
  String get searchQuestHint => '番号・任務名・説明・報酬を検索（空白区切りでいずれかに一致）';

  @override
  String get questAvailable => '未受注';

  @override
  String get questAcceptedOnly => '受注済みのみ（報酬待ちを含む）';

  @override
  String get questClaimable => '報酬待ち';

  @override
  String get questInferredCompleted => '完了推定';

  @override
  String get questStateUnknown => '状態不明';

  @override
  String get questFilterHelp =>
      '解放済みには未受注・遂行中・報酬待ち、未解放には状態不明、完了には報酬待ちと完了推定を含みます。';

  @override
  String get questNoResults => '条件に一致する任務がありません';

  @override
  String get questNoResultsHint => '検索内容を変更するか、絞り込みを解除してください。';

  @override
  String questResultsCount(int count) {
    return '全 $count 件';
  }

  @override
  String get clear => 'クリア';

  @override
  String get done => '完了';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get questType => '任務種別';

  @override
  String get allTypes => 'すべての種別';

  @override
  String get questFormation => '編成';

  @override
  String get questSortie => '出撃';

  @override
  String get questExercise => '演習';

  @override
  String get questSupplyRepair => '補給/入渠';

  @override
  String get questFactory => '工廠';

  @override
  String get questRemodeling => '改装';

  @override
  String get questPeriod => '任務周期';

  @override
  String get allPeriods => 'すべての周期';

  @override
  String get questSeasonal => 'クォータリー';

  @override
  String get questYearly => 'イヤーリー';

  @override
  String get unlockStatus => '解放状態';

  @override
  String get allStatuses => 'すべての状態';

  @override
  String get questUnlocked => '解放済み';

  @override
  String get questLocked => '未解放';

  @override
  String get noDescription => '説明はありません';

  @override
  String get completionConditions => '達成条件';

  @override
  String get questRelations => '関連任務';

  @override
  String get prerequisiteQuests => '前提任務';

  @override
  String get followingQuests => '後続任務';

  @override
  String get notCompleted => '未達成';

  @override
  String get gameResourceCacheTitle => 'ゲームリソースのローカルキャッシュ';

  @override
  String get gameResourceCacheDesc =>
      'リソースは「艦隊これくしょん -艦これ-」公式サーバーから取得します。キャッシュはいつでも削除できます。';

  @override
  String get gameResourceCacheNone => '一時キャッシュ';

  @override
  String get gameResourceCacheNoneDesc =>
      'リソースは事前ダウンロードせず、プレイ中に必要な分だけキャッシュします。保存期間は最長 7 日、使用量は最大 1 GB で、期限切れまたは上限超過時に自動削除されます。';

  @override
  String get gameResourceCacheLight => '軽量キャッシュ';

  @override
  String get gameResourceCacheLightDesc =>
      '起動ファイル、よく使う UI、保有艦娘の立ち絵と装備リソースをキャッシュします。';

  @override
  String get gameResourceCacheFull => 'ローカルキャッシュ';

  @override
  String get gameResourceCacheFullDesc =>
      '固定の基本リソース一覧に含まれるファイル（約 5.49 GB）を事前ダウンロードします。新しいコンテンツはプレイ中に自動でキャッシュします。';

  @override
  String get gameResourceCacheStart => 'ダウンロード開始';

  @override
  String get gameResourceCachePause => '一時停止';

  @override
  String get gameResourceCacheResume => '再開';

  @override
  String get gameResourceCacheCheck => '整合性を確認';

  @override
  String get gameResourceCacheRepair => '不足・破損を修復';

  @override
  String get gameResourceCacheClear => 'ローカルキャッシュを削除';

  @override
  String get gameResourceCacheIntegrityComplete => '現在のキャッシュは完全です';

  @override
  String get gameResourceCacheMissing => '不足';

  @override
  String get gameResourceCacheDamaged => '破損';

  @override
  String get gameResourceCacheOutdated => '確認待ち';

  @override
  String get gameResourceCacheItems => '件';

  @override
  String gameResourceCacheStoredSize(String size) {
    return 'キャッシュ済み $size';
  }

  @override
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  ) {
    return '不足 $missing 件・破損 $damaged 件・確認待ち $pending 件';
  }

  @override
  String get gameResourceCachePendingRetained =>
      '確認待ちのリソースは端末内に保持され、自動的には削除されません。';

  @override
  String get gameResourceCacheDownloadConfirmTitle => 'キャッシュをダウンロードしますか？';

  @override
  String get gameResourceCacheDownloadConfirmDesc =>
      '選択したモードのリソースを公式サーバーから一括取得します。いつでも一時停止・再開できます。';

  @override
  String get gameResourceCacheMobileConfirmDesc =>
      '現在モバイル回線を使用しています。通信量を消費して今回のダウンロードを続けますか？';

  @override
  String get gameResourceCacheWaitingForWifi => 'Wi-Fi を待機しています。接続後に自動で再開します。';

  @override
  String get gameResourceCacheClearConfirmTitle => 'ゲームリソースキャッシュを削除しますか？';

  @override
  String get gameResourceCacheClearConfirmDesc =>
      'ダウンロード済みリソースを削除します。モード設定は保持されます。';

  @override
  String get gameResourceCacheCapacityBlocked =>
      '空き容量が不足しているか、ゲームリソースキャッシュが 50 GB の上限に達しています。';

  @override
  String get gameResourceCacheActionFailed =>
      'キャッシュ操作を完了できませんでした。しばらくしてからお試しください。';

  @override
  String get confirmGameRefreshTitle => 'ゲームを更新しますか？';

  @override
  String get gameRefreshDialogDescription =>
      'ゲームを更新しますか？\n\n「ゲームページを更新」はブラウザーの更新と同じです。\n「ゲームを再読み込み」はゲームフレームだけを再読み込みするため通常は高速ですが、猫や通信エラーが発生する可能性があります。自己責任で使用してください。';

  @override
  String get refreshGamePage => 'ゲームページを更新';

  @override
  String get reloadGame => 'ゲームを再読み込み';

  @override
  String get gameFrameNotFound => 'ゲームフレームが見つかりません。ゲームに入ってから再試行してください。';

  @override
  String get gameHtmlWrapNotFound => 'ゲーム本体が見つかりません。読み込みを待ってから再試行してください。';

  @override
  String get gameFrameReloadBlocked =>
      'ゲームフレームを再読み込みできませんでした。しばらくしてから再試行してください。';

  @override
  String get gameFrameReloadUnsupported =>
      '現在の端末の Android WebView は古いため、子フレームへのスクリプト注入に対応していません。';

  @override
  String get logbookResourceDrop => '資源ドロップ';

  @override
  String get logbookItemDrop => 'アイテムドロップ';

  @override
  String get logbookResourceNode => '資源マス';

  @override
  String get logbookFriendFormation => '味方陣形';

  @override
  String get logbookEnemyFormation => '敵陣形';

  @override
  String get logbookAirSuperiority => '制空状態';

  @override
  String get airSuperiorityParity => '航空均衡';

  @override
  String get airSuperioritySecured => '制空権確保';

  @override
  String get airSuperiorityAdvantage => '航空優勢';

  @override
  String get airSuperiorityDisadvantage => '航空劣勢';

  @override
  String get airSuperiorityLost => '制空権喪失';

  @override
  String get logbookHeavyDamageShips => '大破艦娘';

  @override
  String get gameConnectorTitle => 'ゲーム接続';

  @override
  String get gameConnectorYahagi => 'Yahagi 接続';

  @override
  String get gameConnectorYahagiDesc => '現在の DMM 公式ログイン入口を使用します。';

  @override
  String get gameConnectorOoi => 'OOI 接続（実験的）';

  @override
  String get gameConnectorOoiDesc =>
      'ooi.moe のログイン画面をそのまま開き、モード 1・3・4 を選択できます。';

  @override
  String get gameConnectorConfirmTitle => 'ゲーム接続を切り替えますか？';

  @override
  String get gameConnectorOoiRisk =>
      'アカウント情報は第三者サイト ooi.moe に送信されます。Yahagi はアカウント名やパスワードを読み取り、保存、自動入力しません。';

  @override
  String get gameConnectorActiveWarning =>
      '切り替えると現在のゲーム画面が中断され、対象のログイン入口へ戻ります。';

  @override
  String get gameConnectorApplied => 'ゲーム接続を切り替えました。';

  @override
  String get gameConnectorSaveFailed => '接続設定を保存できなかったため、現在の接続を維持します。';

  @override
  String get gameConnectorNavigationFailed =>
      '接続設定は保存されましたが、ログイン画面を開けませんでした。もう一度お試しください。';

  @override
  String get kcwikiReportSection => 'KCWiki データ提供';

  @override
  String get kcwikiReportTitle => 'KCWiki のデータ収集に協力する';

  @override
  String get kcwikiReportDisabledDesc =>
      '初期設定はオンで、現在はオフです。オフの間は収集・整形・通信を行わず、ゲームやローカル機能に影響しません。';

  @override
  String get kcwikiReportEnabledDesc =>
      'オンです。進路、任務前提、戦闘、友軍、基地航空／空襲、改修データのみ送信します。';

  @override
  String get kcwikiReportConfirmTitle => 'KCWiki データ提供を有効にしますか？';

  @override
  String get kcwikiReportConfirmDesc =>
      '有効にすると、進路、任務前提、戦闘、友軍、基地航空／空襲、改修記録を KCWiki の report2 サーバーへ送信します。このサーバーは現在、暗号化されていない HTTP を使用します。ログイントークン、Cookie、リクエストヘッダーは送信せず、送信失敗でゲーム機能が停止することもありません。';

  @override
  String get kcwikiReportEnable => '任意で有効化';

  @override
  String get kcwikiReportSaveFailed =>
      'KCWiki データ提供の設定を保存できませんでした。もう一度お試しください。';

  @override
  String kcwikiReportCaptureFailed(String error) {
    return 'KCWiki データ収集の切り替えに失敗しました：$error';
  }

  @override
  String get kcwikiReportWaiting => '有効です。提供できるデータを待っています。';

  @override
  String kcwikiReportProcessing(String module, String time) {
    return '送信中：$module · $time';
  }

  @override
  String kcwikiReportParseRecovered(String time) {
    return '大きなデータの解析タイムアウトから復旧し、後続処理を再開しました · $time';
  }

  @override
  String kcwikiReportFailureHttp(String status) {
    return 'HTTP $status';
  }

  @override
  String get kcwikiReportFailureTimeout => '接続タイムアウト';

  @override
  String get kcwikiReportFailureNetwork => 'ネットワークエラー';

  @override
  String get kcwikiReportFailureBodyTooLarge => '1回の送信上限を超えました';

  @override
  String get kcwikiReportFailureQueueFull => '端末内の待機キューが上限です';

  @override
  String get kcwikiReportFailureLocal => '端末内処理エラー';

  @override
  String kcwikiReportCounters(int succeeded, int failed, int dropped) {
    return '成功 $succeeded · 失敗 $failed · 破棄 $dropped';
  }

  @override
  String kcwikiReportLastSuccess(
    String module,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '直近の送信成功：$module · $time · 成功 $succeeded · 失敗 $failed · 破棄 $dropped';
  }

  @override
  String kcwikiReportLastFailure(
    String module,
    String status,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '直近の送信失敗：$module（$status）· $time · 成功 $succeeded · 失敗 $failed · 破棄 $dropped';
  }

  @override
  String get landBaseBrief => '基地航空隊概要';

  @override
  String get landBaseNoData => 'データなし';

  @override
  String landBaseAreaFallback(int areaId) {
    return '海域 $areaId';
  }

  @override
  String landBaseUnitCount(int count) {
    return '航空隊 $count隊';
  }

  @override
  String get landBaseRange => '航続距離';

  @override
  String get landBaseActionSortie => '出撃';

  @override
  String get landBaseActionAirDefense => '防空';

  @override
  String get landBaseActionRest => '休息';

  @override
  String get landBaseActionRetreat => '退避';

  @override
  String get landBaseMissingPlanes => '未補充';

  @override
  String get landBaseRelocating => '配置転換中';

  @override
  String get senkaInfoTab => '戦果情報';

  @override
  String get senkaCalendarTab => '戦果カレンダー';

  @override
  String get senkaCalculatorTab => '戦果計算';

  @override
  String get senkaSaveFailedWarning => '戦果データを保存できませんでした。再起動すると失われる可能性があります';

  @override
  String get senkaLatestRanking => '最新ランキングの戦果';

  @override
  String get senkaTarget => '目標戦果';

  @override
  String senkaGap(String value) {
    return '目標まであと $value 戦果';
  }

  @override
  String senkaOver(String value) {
    return '目標を $value 戦果超過';
  }

  @override
  String get senkaPlannedEo => '予定 EO';

  @override
  String get senkaPlannedQuest => '予定任務';

  @override
  String get senkaDailyRequired => '1日あたり必要';

  @override
  String get senkaTodayRemaining => '本日の残り';

  @override
  String get senkaUnsettledDelta => '集計後増分';

  @override
  String get senkaAvailableDaysIncludingToday => '利用可能日数（本日含む）';

  @override
  String get senkaProjected => '予想戦果';

  @override
  String get senkaUnit => '戦果';

  @override
  String senkaInputTitle(String label) {
    return '$labelを入力';
  }

  @override
  String get senkaInvalidNumber => '有効な数値を入力してください';

  @override
  String get senkaPlannedEoReward => '予定 EO 戦果報酬';

  @override
  String get senkaPlannedQuestReward => '予定任務戦果報酬';

  @override
  String get senkaTotal => '合計';

  @override
  String get senkaEoRewards => 'EO 戦果報酬';

  @override
  String get senkaQuarterlyQuests => 'クォータリー戦果任務';

  @override
  String get senkaAnnualQuests => 'イヤーリー戦果任務';

  @override
  String get senkaOneTimeQuests => '単発戦果任務';

  @override
  String get senkaRewardLegend =>
      '黄＋✕：保留（予想に含めない）、緑＋✓：完了予定（予想に含める）、灰＋○：完了済み（重複計算しない）。';

  @override
  String get senkaRewardDeferred => '保留';

  @override
  String get senkaRewardPlanned => '完了予定（予想に計上）';

  @override
  String get senkaRewardCompleted => '完了済み';

  @override
  String senkaCalendarTitle(int year, int month) {
    return '$year年$month月 戦果カレンダー';
  }

  @override
  String senkaCalendarSummary(String recorded, String base) {
    return '今月の記録 $recorded · 素戦果 $base';
  }

  @override
  String get senkaExperience => '経験値';

  @override
  String get senkaQuest => '任務';

  @override
  String senkaCalendarCell(int year, int month, int day, String value) {
    return '$year年$month月$day日、戦果$value';
  }

  @override
  String get senkaServer => '所属サーバー';

  @override
  String get senkaRanking => '戦果ランキング';

  @override
  String get senkaRank => '順位';

  @override
  String senkaUpdated(String time) {
    return '更新：$time';
  }

  @override
  String get senkaOrder => '順位';

  @override
  String get senkaChange => '変化';

  @override
  String get senkaCurrent => '現在';

  @override
  String get senkaSortieStats => '出撃海域統計';

  @override
  String get senkaLatestRecord => '最終記録';

  @override
  String get senkaMonthSorties => '今月の出撃';

  @override
  String get senkaBossArrivals => 'Boss 到達';

  @override
  String get senkaSWins => 'S 勝利';

  @override
  String get senkaMonth => '今月';

  @override
  String get senkaToday => '今日';

  @override
  String get senkaShowHiddenAreas => '非表示海域を表示';

  @override
  String get senkaShowHidden => '非表示を表示';

  @override
  String get senkaArea => '海域';

  @override
  String get senkaBoss => 'Boss';

  @override
  String get senkaSorties => '出撃';

  @override
  String get senkaResult => 'S / A';

  @override
  String get senkaActions => '操作';

  @override
  String senkaFavoriteArea(String map) {
    return '海域 $map をお気に入りにする';
  }

  @override
  String senkaHideArea(String map) {
    return '海域 $map を非表示にする';
  }

  @override
  String get senkaUnknownServer => '不明なサーバー';

  @override
  String get toolbox => 'ツールボックス';

  @override
  String get fleetExport => 'データエクスポート';

  @override
  String get otherTools => 'その他';

  @override
  String get noro6 => 'noro6';

  @override
  String get jervis => 'Jervis';

  @override
  String get exportToNoro6 => 'noro6 へエクスポート';

  @override
  String get exportToNoro6Mirror => 'noro6（中国向けミラー）へエクスポート';

  @override
  String get exportToJervis => 'Jervis へエクスポート';

  @override
  String get eventLandBasesOnly => 'イベント海域の基地航空隊のみ出力';

  @override
  String get landBaseExportLimitHint =>
      'DeckBuilder は一度に最大3隊まで対応します。絞り込みを解除した場合は取得順の先頭3隊を出力します。';

  @override
  String get fleetExportText => '艦隊エクスポートテキスト';

  @override
  String get deckBuilderV4 => 'DeckBuilder v4';

  @override
  String get refreshExportText => '更新';

  @override
  String get copyExportText => 'テキストをコピー';

  @override
  String get openInSystemBrowser => 'システムの既定ブラウザーで開く';

  @override
  String get otherToolsComingSoon => 'その他の機能は順次開発中です';

  @override
  String get otherToolsHint => '今後の補助ツールはここに追加されます。';

  @override
  String get waitingForPortData => '母港データを待っています';

  @override
  String get externalFleetToolOpenFailed =>
      '外部艦隊ツールを開けません。ブラウザーがインストールされているか確認してください。';

  @override
  String get fleetExportCopied => '艦隊エクスポートテキストをコピーしました。';

  @override
  String get fleetExportCopyFailed => 'コピーできませんでした。しばらくしてからもう一度お試しください。';

  @override
  String equipmentCompatibilitySummary(int owned, int all) {
    return '装備可能：保有 $owned／全艦娘 $all';
  }

  @override
  String equipmentCompatibilityOwnedTab(int count) {
    return '保有艦娘 $count';
  }

  @override
  String equipmentCompatibilityAllTab(int count) {
    return '全艦娘 $count';
  }

  @override
  String equipmentCompatibilityOwnedCompact(int count) {
    return '所持 $count';
  }

  @override
  String equipmentCompatibilityAllCompact(int count) {
    return '全て $count';
  }

  @override
  String get equipmentCompatibilitySelectShipType => '艦種を選択';

  @override
  String get equipmentCompatibilitySearchHint => '艦娘を検索';

  @override
  String get equipmentCompatibilityAllSlots => '全スロット';

  @override
  String get equipmentCompatibilityRegularSlot => '通常スロット';

  @override
  String get equipmentCompatibilityExpansionSlot => '補強増設';

  @override
  String get equipmentCompatibilityBothSlots => '通常＋補強増設';

  @override
  String equipmentCompatibilityExpansionRequirement(int level) {
    return '補強増設は ★+$level 以上';
  }

  @override
  String equipmentCompatibilityOwnedLevels(String levels) {
    return 'Lv. $levels';
  }

  @override
  String equipmentCompatibilityFleetNumbers(String numbers) {
    return '第 $numbers 艦隊';
  }

  @override
  String get equipmentCompatibilityEmpty => '条件に一致する艦娘はいません';

  @override
  String equipmentCompatibilityOfficialId(int id) {
    return '装備 ID $id';
  }

  @override
  String equipmentCompatibilityOwnedCount(int count) {
    return '保有数 $count';
  }

  @override
  String equipmentCompatibilityRegularCount(int count) {
    return '通常枠 $count';
  }

  @override
  String equipmentCompatibilityExpansionCount(int count) {
    return '補強増設 $count';
  }

  @override
  String get equipmentCompatibilitySource => 'ルール出典：ゲーム公式マスターデータ';

  @override
  String get equipmentCompatibilityRulesWaiting => '装備ルールの更新を待っています';

  @override
  String get equipmentCompatibilityEmptyOwned => '装備可能な保有艦娘はいません';

  @override
  String get equipmentCompatibilityEmptyAll => '装備可能な艦娘形態が見つかりません';

  @override
  String equipmentCompatibilityCategory(String category) {
    return '分類：$category';
  }

  @override
  String equipmentCompatibilityShipClassId(int id) {
    return '艦級 #$id';
  }

  @override
  String get shipEquipmentCompatibilitySelectCategory => '装備カテゴリを選択';

  @override
  String get shipEquipmentCompatibilitySearchTitle => '装備を検索';

  @override
  String get shipEquipmentCompatibilitySearchHint => '装備名を入力';

  @override
  String shipEquipmentCompatibilityOwnedCount(int count) {
    return '所持 X$count';
  }

  @override
  String get shipEquipmentCompatibilityEmpty => '装備可能な装備が見つかりません';

  @override
  String get equipmentDevelopment => '装備開発';

  @override
  String get development => '開発';

  @override
  String get developmentCommandTitle => '開発指揮卓';

  @override
  String get developmentWorkbenchTitle => '開発ワークベンチ';

  @override
  String get developmentCalculator => '開発計算機';

  @override
  String get developmentFormula => '開発レシピ';

  @override
  String get developmentOutputProbability => '開発確率';

  @override
  String get developmentFinalProbability => '最終確率';

  @override
  String get developmentAvailableRecipes => '利用可能なレシピ';

  @override
  String get developmentPoolType => 'プール種類';

  @override
  String get developmentSelectSecretary => '秘書艦タイプを選択';

  @override
  String get developmentOtherSecretaryGroup => 'その他';

  @override
  String get developmentEquipmentType => '種類';

  @override
  String get developmentSecretary => '秘書艦';

  @override
  String get developmentFuelShort => '燃';

  @override
  String get developmentAmmoShort => '弾';

  @override
  String get developmentSteelShort => '鋼';

  @override
  String get developmentBauxiteShort => 'ボ';

  @override
  String get developmentOutputRate => '開発率';

  @override
  String get developmentEquipment => '装備';

  @override
  String get developmentCurrentFlagship => '現在の旗艦';

  @override
  String get developmentUseFlagship => '現在の旗艦を使用';

  @override
  String get developmentFlagshipUnsupported =>
      '現在の旗艦に対応する開発プールがないため、元の選択を維持しました';

  @override
  String get developmentSelectPool => '秘書艦タイプ';

  @override
  String get developmentCurrentRecipe => '現在のレシピ';

  @override
  String get developmentTargetEquipment => '目標装備';

  @override
  String get developmentChooseTarget => '目標装備を選択';

  @override
  String get developmentSearchEquipment => '装備を検索';

  @override
  String get developmentSearchHint => '装備名または ID';

  @override
  String get developmentAllTypes => 'すべての種類';

  @override
  String get developmentTargetDrops => '目標装備';

  @override
  String get developmentOtherDrops => 'その他の装備';

  @override
  String get developmentInsufficient => '資材不足';

  @override
  String get developmentReplaced => '置き換えられた装備';

  @override
  String get developmentRecommendations => 'おすすめレシピ';

  @override
  String get developmentNoTargets => '目標装備を選ぶとおすすめレシピを表示します';

  @override
  String get developmentNoResults => 'すべての目標を同時に開発できるレシピはありません';

  @override
  String get developmentTargetRate => '目標装備の開発率';

  @override
  String get developmentFailureRate => '失敗率';

  @override
  String get developmentTotalResources => '資材合計';

  @override
  String get developmentApplyRecipe => 'レシピを適用';

  @override
  String get developmentDataError => '装備開発データの読み込みに失敗しました';

  @override
  String get developmentRetry => '再試行';

  @override
  String developmentSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get developmentPoolBauxite => 'ボーキサイト系';

  @override
  String get developmentPoolAmmunition => '弾薬系';

  @override
  String get developmentPoolFuelSteel => '燃料・鋼材系';

  @override
  String get battlePredictionUnconfirmed =>
      'データ未確認：HP・予測は参考値です。ゲーム画面で確認してください。';
}
