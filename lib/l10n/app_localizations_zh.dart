// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ヤハギ';

  @override
  String get game => '游戏';

  @override
  String get fleet => '舰队';

  @override
  String get expedition => '远征';

  @override
  String get repair => '入渠';

  @override
  String get construction => '建造';

  @override
  String get quests => '任务';

  @override
  String get battleRecords => '战斗记录';

  @override
  String get settings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get layoutSettings => '界面与布局';

  @override
  String get gameAreaRatio => '游戏区域占比';

  @override
  String get infoPanelWidth => '情报面板宽度';

  @override
  String get autoZoom => '自动缩放游戏画面 (推荐)';

  @override
  String get language => '语言 (Language)';

  @override
  String get networkSettings => '网络设置';

  @override
  String get networkStatus => '网络状态';

  @override
  String get proxyNotSupported =>
      '当前设备的 Android System WebView 不支持应用内代理设置。\n您只能使用系统网络或全局 VPN。';

  @override
  String get systemNetwork => '系统网络 / VPN';

  @override
  String get systemNetworkDesc => '不使用应用内代理，跟随系统网络环境。';

  @override
  String get httpProxy => 'HTTP 代理';

  @override
  String get httpProxyDesc => '连接自定义 HTTP 代理服务器。';

  @override
  String get socks5Proxy => 'SOCKS5 代理';

  @override
  String get socks5ProxyDesc => '连接自定义 SOCKS5 代理服务器。';

  @override
  String get hostAddress => '主机地址 (IP 或域名)';

  @override
  String get hostHint => '如 192.168.1.10';

  @override
  String get port => '端口';

  @override
  String get currentSavedMode => '当前已保存模式';

  @override
  String get vpnStatus => 'VPN 状态';

  @override
  String get vpnActive => '已检测到活动 VPN';

  @override
  String get vpnInactive => '未检测到活动 VPN';

  @override
  String get testConnection => '网络连接测试';

  @override
  String get applySettings => '应用设置并重新加载游戏';

  @override
  String get restoreSystemNetwork => '恢复系统网络';

  @override
  String get gameSafety => '游戏安全';

  @override
  String get blockSortieTitle => '大破进击保护';

  @override
  String get blockSortieDesc =>
      '出击或进击前，若舰队中存在大破舰船（非旗舰且未装备损管），将强制阻断网络请求并弹出警告。强烈建议开启。';

  @override
  String get storageAndCache => '存储与缓存';

  @override
  String get logoutAndClear => '退出登录 / 清除账号信息';

  @override
  String get logoutAndClearDesc => '清除游戏登录状态，下次打开需要重新登录。';

  @override
  String get clearQuestCache => '清理任务数据缓存';

  @override
  String get clearQuestCacheDesc => '清除本地缓存的脱敏任务数据，重启应用后需进入游戏内任务面板重新获取';

  @override
  String get clearWebCache => '清理游戏 Web 缓存';

  @override
  String get clearWebCacheDesc => '清除游戏加载的图片、音频等静态资源缓存。';

  @override
  String get fleetBrief => '编队简报';

  @override
  String get expeditionBrief => '远征简报';

  @override
  String get repairBrief => '入渠简报';

  @override
  String get constructionBrief => '建造简报';

  @override
  String get questBrief => '任务简报';

  @override
  String get preSortieCheck => '出击前检查';

  @override
  String get forecast => '未卜先知';

  @override
  String get waitingForSortieData => '等待出击数据';

  @override
  String get standby => '待机';

  @override
  String get compact => '简洁';

  @override
  String get detailed => '完整';

  @override
  String get questDesc => '任务说明';

  @override
  String get baseReward => '基础奖励';

  @override
  String get accepted => '已接受';

  @override
  String get completed => '已完成';

  @override
  String get updatedAt => '更新于';

  @override
  String get questDaily => '日常';

  @override
  String get questWeekly => '周常';

  @override
  String get questMonthly => '月常';

  @override
  String get questOneTime => '单次';

  @override
  String get questOther => '其他';

  @override
  String get questUnknown => '未知';

  @override
  String get inProgress => '进行中';

  @override
  String get clearWebCacheConfirmTitle => '清理游戏 Web 缓存';

  @override
  String get clearWebCacheConfirmDesc =>
      '确定要清除游戏缓存吗？这将会删除已下载的图片、音频等静态资源，下次进入游戏或加载立绘时可能会消耗较多流量和时间。';

  @override
  String get confirmClear => '确定清除';

  @override
  String get captureMode => '数据捕获模式';

  @override
  String get gameAndSound => '游戏与声音';

  @override
  String get gameSound => '游戏声音';

  @override
  String get aboutApp => '关于 ヤハギ';

  @override
  String get aboutSubtitle => '版本 学习版 1.0.1 · 免责声明 · 检查更新';

  @override
  String get version => '版本 学习版 1.0.1';

  @override
  String get disclaimerTitle => '免责声明 (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      '本项目仅供编程技术交流与学习目的使用，是一款完全非盈利且非官方的第三方通用浏览器工具。本项目与 Kantai Collection (KanColle) 官方及任何相关权利方无任何关联。';

  @override
  String get disclaimerP2 =>
      '本软件不参与、不阻断、不重放且不篡改游戏服务器的通信数据，也不会代替玩家执行游戏操作。原作者不对软件的质量做任何明示或暗示的保证（包括但不限于对软件完全无 Bug、适用性或系统稳定性的保证）。';

  @override
  String get disclaimerP3 =>
      '在任何情况下，因使用或无法使用本软件而导致的任何移动设备损坏、数据丢失、游戏账号封禁风险或其他任何形式的直接或间接利益损失，原作者均不承担任何法律与连带责任。如果您在“技术学习”之外的场景使用本软件，所产生的一切版权争议、服务条款违规及其他风险，均将由使用者自行承担。';

  @override
  String get viewOnGitHub => '去 GitHub 看看';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get openSourceLicense => '开源协议: MIT License';

  @override
  String get newVersionFound => '🚀 发现新版本！';

  @override
  String get currentVersionLabel => '当前版本';

  @override
  String get latestVersionLabel => '最新版本';

  @override
  String get updateContent => '本次更新内容:';

  @override
  String get later => '以后再说';

  @override
  String get goDownload => '前往下载';

  @override
  String get alreadyLatest => '已经是最新版本';

  @override
  String get alreadyLatestDesc => '当前版本已经是最新版本。';

  @override
  String get noRelease => '暂无发布版本';

  @override
  String get noReleaseDesc => 'GitHub 仓库尚未发布任何 Release。';

  @override
  String get checkFailed => '检查失败';

  @override
  String get networkError => '网络错误';

  @override
  String get networkErrorDesc => '检查更新时发生错误，请稍后重试。';

  @override
  String get noUpdateLog => '暂无更新日志';

  @override
  String get battleWarningOff => '关闭';

  @override
  String get battleWarningReminder => '闪烁提醒';

  @override
  String get battleWarningConfirm => '弹框确认';

  @override
  String get logoutSnackbar => '退出登录功能已准备就绪，当前为保护您的测试账号暂未执行清除。';

  @override
  String get questCacheCleared => '已清除任务数据本地缓存';

  @override
  String get webCacheCleared => '已清理游戏 Web 缓存';

  @override
  String get clearLogbook => '清理航海日志数据';

  @override
  String get clearLogbookDesc => '清除本地保存的所有历史战果、资源与远征记录。此操作不可逆。';

  @override
  String get clearLogbookConfirmTitle => '清理航海日志数据';

  @override
  String get clearLogbookConfirmDesc =>
      '确定要清空所有航海日志数据吗？这将会删除您积攒的历史战果和资源统计记录。此操作无法撤销。';

  @override
  String get logbookCleared => '已清除所有航海日志数据';

  @override
  String get antiCatbomb => '断网防猫';

  @override
  String get antiCatbombDesc => '开启后，若游戏请求因网络断开等原因失败，App 将挂起游戏并不断重试，避免出现“猫”报错。';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get waitingForData => '等待数据';

  @override
  String get fleetNoShips => '当前舰队没有舰娘';

  @override
  String get unorganized => '未编成';

  @override
  String get speed => '速度';

  @override
  String get totalLevel => '总等级';

  @override
  String get firepower => '火力';

  @override
  String get torpedo => '雷装';

  @override
  String get antiAir => '对空';

  @override
  String get antiSub => '对潜';

  @override
  String get airPower => '制空';

  @override
  String get los => '索敌';

  @override
  String get avgCondition => '平均疲劳';

  @override
  String get losDetail => '索敌详情';

  @override
  String get totalLos => '总索敌';

  @override
  String get specialAttack => '特殊攻击';

  @override
  String get unknownShip => '未知舰娘';

  @override
  String get unknownClass => '未知舰种';

  @override
  String get needsResupply => '需要补给';

  @override
  String get fuel => '燃料';

  @override
  String get ammo => '弹药';

  @override
  String get hp => '血量';

  @override
  String get waitingForEquip => '装备数据等待更新';

  @override
  String get fastSpeed => '高速';

  @override
  String get slowSpeed => '低速';

  @override
  String get gotIt => '知道了';

  @override
  String get unknownEquip => '未知装备';

  @override
  String get noBonusStats => '暂无附加属性';

  @override
  String get condition => '疲劳';

  @override
  String get noExpeditionFleet => '暂无远征中的舰队';

  @override
  String get expeditionInProgress => '远征进行中';

  @override
  String get progress => '进行进度';

  @override
  String get unlocked => '未解锁';

  @override
  String get notRepairing => '未入渠';

  @override
  String get repairProgress => '修理进度';

  @override
  String get cost => '消耗';

  @override
  String get notConstructing => '未建造';

  @override
  String get lsc => '大型建造';

  @override
  String get normalConstruct => '常规建造';

  @override
  String get constructing => '建造中';

  @override
  String get constructProgress => '建造进度';

  @override
  String get constructComplete => '建造完成';

  @override
  String get allRatings => '全部评级';

  @override
  String get noBattleRecords => '尚无战斗记录';

  @override
  String get autoRecordHint => '出击后会自动记录，不需要额外操作';

  @override
  String get enemyFleet => '敌舰队';

  @override
  String get thisSortie => '本次出击';

  @override
  String get historicalRecords => '历史战果';

  @override
  String get resourceTrend => '资源趋势';

  @override
  String get expeditionIncome => '远征收益';

  @override
  String get noHistoricalRecords => '暂无历史战果';

  @override
  String get none => '无';

  @override
  String get unknownNode => '未知点';

  @override
  String get noResourceRecords => '暂无资源记录';

  @override
  String get resourceTrend24h => '24小时';

  @override
  String get resourceTrend7d => '7天';

  @override
  String get resourceTrend30d => '30天';

  @override
  String get resourceTrendAll => '全部记录';

  @override
  String get resourceTrendMainGroup => '四项资源';

  @override
  String get resourceTrendAuxGroup => '辅助资源';

  @override
  String get gadgetBypass => '游戏客户端资源绕行（实验性）';

  @override
  String get gadgetBypassDesc =>
      '仅在客户端静态资源服务器受限时改用镜像；不修改 DMM 登录、Cookie 或游戏数据接口。关闭时完全旁路。';

  @override
  String get gadgetBypassEnable => '开启绕行';

  @override
  String get gadgetBypassEndpoint => '镜像端点';

  @override
  String get endpointCustom => '自定义';

  @override
  String get gadgetBypassStatusOn => '已启用';

  @override
  String get gadgetBypassStatusOff => '未启用';

  @override
  String get gadgetBypassUnsupported => '当前设备不支持（需要 Android 8.0+）';

  @override
  String get gadgetBypassClearCache => '清空缓存';

  @override
  String get gadgetBypassError => '绕行配置失败';

  @override
  String get gadgetBypassDiagnose => '检查 403 与镜像连通性';

  @override
  String get gadgetBypassDiagnosing => '诊断中...';

  @override
  String get gadgetBypassW00g => '客户端服务器 (w00g)';

  @override
  String get gadgetBypassEndpointProbe => '镜像端点';

  @override
  String get gadgetBypassKcsapi => '游戏数据接口 (kcsapi)';

  @override
  String get gadgetBypassReachable => '通畅';

  @override
  String get gadgetBypassUnreachable => '无法连接';

  @override
  String get resourceTrendChart => '资源趋势变化 (最近 100 次记录)';

  @override
  String get steel => '钢材';

  @override
  String get bauxite => '铝土';

  @override
  String get noExpeditionRecords => '暂无远征记录';

  @override
  String get expeditionIncomeChart => '远征收益统计 (最近 7 天)';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langJa => '日本語';

  @override
  String get node => '点';

  @override
  String get friend => '我方';

  @override
  String get enemy => '敌方';

  @override
  String get drop => '掉落';

  @override
  String get inExpedition => '远征中';

  @override
  String get unknownProgress => '进度未知';

  @override
  String get waitingForPortData => '等待母港数据';

  @override
  String get waitingForPortDataDescription => '进入游戏母港或刷新游戏页面后，这里会自动更新';

  @override
  String get fleetNotFormed => '未编成';

  @override
  String get fleetStandby => '母港待命';

  @override
  String get shipsCount => '舰';

  @override
  String get noValue => '无';

  @override
  String get lineOfSight => '索敌';

  @override
  String get averageCondition => '平均疲劳';

  @override
  String get losDetails => '索敌详情';

  @override
  String get unknownShipType => '未知舰种';

  @override
  String get needsSupply => '需要补给';

  @override
  String get equipmentDataWaiting => '装备数据等待更新';

  @override
  String get highSpeed => '高速';

  @override
  String get lowSpeed => '低速';

  @override
  String get unknownEquipment => '未知装备';

  @override
  String get noAdditionalStats => '暂无附加属性';

  @override
  String get fatigue => '疲劳';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'ヤハギ';

  @override
  String get game => '遊戲';

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
  String get battleRecords => '戰鬥記錄';

  @override
  String get settings => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get layoutSettings => '介面與佈局';

  @override
  String get gameAreaRatio => '遊戲區域佔比';

  @override
  String get infoPanelWidth => '情報面板寬度';

  @override
  String get autoZoom => '自動縮放遊戲畫面 (推薦)';

  @override
  String get language => '語言 (Language)';

  @override
  String get networkSettings => '網路設定';

  @override
  String get networkStatus => '網路狀態';

  @override
  String get proxyNotSupported =>
      '當前設備的 Android System WebView 不支援應用程式內代理設定。\n您只能使用系統網路或全局 VPN。';

  @override
  String get systemNetwork => '系統網路 / VPN';

  @override
  String get systemNetworkDesc => '不使用應用程式內代理，跟隨系統網路環境。';

  @override
  String get httpProxy => 'HTTP 代理';

  @override
  String get httpProxyDesc => '連接自訂 HTTP 代理伺服器。';

  @override
  String get socks5Proxy => 'SOCKS5 代理';

  @override
  String get socks5ProxyDesc => '連接自訂 SOCKS5 代理伺服器。';

  @override
  String get hostAddress => '主機地址 (IP 或網域)';

  @override
  String get hostHint => '如 192.168.1.10';

  @override
  String get port => '通訊埠';

  @override
  String get currentSavedMode => '當前已儲存模式';

  @override
  String get vpnStatus => 'VPN 狀態';

  @override
  String get vpnActive => '已檢測到活動 VPN';

  @override
  String get vpnInactive => '未檢測到活動 VPN';

  @override
  String get testConnection => '網路連線測試';

  @override
  String get applySettings => '套用設定並重新載入遊戲';

  @override
  String get restoreSystemNetwork => '恢復系統網路';

  @override
  String get gameSafety => '遊戲安全';

  @override
  String get blockSortieTitle => '大破進擊保護';

  @override
  String get blockSortieDesc =>
      '出擊或進擊前，若艦隊中存在大破艦娘（非旗艦且未裝備損管），將強制阻斷網路請求並跳出警告。強烈建議開啟。';

  @override
  String get storageAndCache => '儲存與快取';

  @override
  String get logoutAndClear => '登出 / 清除帳號資訊';

  @override
  String get logoutAndClearDesc => '清除遊戲登入狀態，下次開啟需要重新登入。';

  @override
  String get clearQuestCache => '清理任務資料快取';

  @override
  String get clearQuestCacheDesc => '清除本機快取的脫敏任務資料，重啟應用程式後需進入遊戲內任務面板重新獲取';

  @override
  String get clearWebCache => '清理遊戲 Web 快取';

  @override
  String get clearWebCacheDesc => '清除遊戲載入的圖片、音訊等靜態資源快取。';

  @override
  String get fleetBrief => '艦隊簡報';

  @override
  String get expeditionBrief => '遠征簡報';

  @override
  String get repairBrief => '入渠簡報';

  @override
  String get constructionBrief => '建造簡報';

  @override
  String get questBrief => '任務簡報';

  @override
  String get preSortieCheck => '出擊前檢查';

  @override
  String get forecast => '未卜先知';

  @override
  String get waitingForSortieData => '等待出擊數據';

  @override
  String get standby => '待機';

  @override
  String get compact => '簡潔';

  @override
  String get detailed => '完整';

  @override
  String get questDesc => '任務說明';

  @override
  String get baseReward => '基礎獎勵';

  @override
  String get accepted => '已接受';

  @override
  String get completed => '已完成';

  @override
  String get updatedAt => '更新於';

  @override
  String get questDaily => '日常';

  @override
  String get questWeekly => '周常';

  @override
  String get questMonthly => '月常';

  @override
  String get questOneTime => '單次';

  @override
  String get questOther => '其他';

  @override
  String get questUnknown => '未知';

  @override
  String get inProgress => '進行中';

  @override
  String get clearWebCacheConfirmTitle => '清理遊戲 Web 快取';

  @override
  String get clearWebCacheConfirmDesc =>
      '確定要清除遊戲快取嗎？這將會刪除已下載的圖片、音訊等靜態資源，下次進入遊戲或載入立繪時可能會消耗較多流量和時間。';

  @override
  String get confirmClear => '確定清除';

  @override
  String get captureMode => '資料擷取模式';

  @override
  String get gameAndSound => '遊戲與聲音';

  @override
  String get gameSound => '遊戲聲音';

  @override
  String get aboutApp => '關於 ヤハギ';

  @override
  String get aboutSubtitle => '版本 學習版 1.0.1 · 免責聲明 · 檢查更新';

  @override
  String get version => '版本 學習版 1.0.1';

  @override
  String get disclaimerTitle => '免責聲明 (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      '本專案僅供程式技術交流與學習目的使用，是一款完全非營利且非官方的第三方通用瀏覽器工具。本專案與 Kantai Collection (KanColle) 官方及任何相關權利方無任何關聯。';

  @override
  String get disclaimerP2 =>
      '本軟體不參與、不阻斷、不重放且不竄改遊戲伺服器的通訊數據，也不會代替玩家執行遊戲操作。原作者不對軟體的品質做任何明示或暗示的保證（包括但不限於對軟體完全無 Bug、適用性或系統穩定性的保證）。';

  @override
  String get disclaimerP3 =>
      '在任何情況下，因使用或無法使用本軟體而導致的任何行動裝置損壞、資料遺失、遊戲帳號封禁風險或其他任何形式的直接或間接利益損失，原作者均不承擔任何法律與連帶責任。如果您在「技術學習」之外的場景使用本軟體，所產生的一切版權爭議、服務條款違規及其他風險，均將由使用者自行承擔。';

  @override
  String get viewOnGitHub => '前往 GitHub';

  @override
  String get checkForUpdates => '檢查更新';

  @override
  String get openSourceLicense => '開源協議: MIT License';

  @override
  String get newVersionFound => '🚀 發現新版本！';

  @override
  String get currentVersionLabel => '目前版本';

  @override
  String get latestVersionLabel => '最新版本';

  @override
  String get updateContent => '本次更新內容:';

  @override
  String get later => '稍後再說';

  @override
  String get goDownload => '前往下載';

  @override
  String get alreadyLatest => '已經是最新版本';

  @override
  String get alreadyLatestDesc => '目前版本已經是最新版本。';

  @override
  String get noRelease => '暫無發佈版本';

  @override
  String get noReleaseDesc => 'GitHub 倉庫尚未發佈任何 Release。';

  @override
  String get checkFailed => '檢查失敗';

  @override
  String get networkError => '網路錯誤';

  @override
  String get networkErrorDesc => '檢查更新時發生錯誤，請稍後重試。';

  @override
  String get noUpdateLog => '暫無更新日誌';

  @override
  String get battleWarningOff => '關閉';

  @override
  String get battleWarningReminder => '閃爍提醒';

  @override
  String get battleWarningConfirm => '彈框確認';

  @override
  String get logoutSnackbar => '登出功能已準備就緒，目前為保護您的測試帳號暫未執行清除。';

  @override
  String get questCacheCleared => '已清除任務資料本機快取';

  @override
  String get webCacheCleared => '已清理遊戲 Web 快取';

  @override
  String get clearLogbook => '清理航海日誌資料';

  @override
  String get clearLogbookDesc => '清除本機儲存的所有歷史戰果、資源與遠征記錄。此操作不可逆。';

  @override
  String get clearLogbookConfirmTitle => '清理航海日誌資料';

  @override
  String get clearLogbookConfirmDesc =>
      '確定要清空所有航海日誌資料嗎？這將會刪除您累積的歷史戰果和資源統計記錄。此操作無法撤銷。';

  @override
  String get logbookCleared => '已清除所有航海日誌資料';

  @override
  String get antiCatbomb => '斷網防貓';

  @override
  String get antiCatbombDesc => '開啟後，若遊戲請求因網路斷開等原因失敗，App 將掛起遊戲並不斷重試，避免出現「貓」報錯。';

  @override
  String get close => '關閉';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '確定';

  @override
  String get waitingForData => '等待數據';

  @override
  String get fleetNoShips => '當前艦隊沒有艦娘';

  @override
  String get unorganized => '未編成';

  @override
  String get speed => '速度';

  @override
  String get totalLevel => '總等級';

  @override
  String get firepower => '火力';

  @override
  String get torpedo => '雷裝';

  @override
  String get antiAir => '對空';

  @override
  String get antiSub => '對潛';

  @override
  String get airPower => '制空';

  @override
  String get los => '索敵';

  @override
  String get avgCondition => '平均疲勞';

  @override
  String get losDetail => '索敵詳情';

  @override
  String get totalLos => '總索敵';

  @override
  String get specialAttack => '特殊攻擊';

  @override
  String get unknownShip => '未知艦娘';

  @override
  String get unknownClass => '未知艦種';

  @override
  String get needsResupply => '需要補給';

  @override
  String get fuel => '燃料';

  @override
  String get ammo => '彈藥';

  @override
  String get hp => '血量';

  @override
  String get waitingForEquip => '裝備數據等待更新';

  @override
  String get fastSpeed => '高速';

  @override
  String get slowSpeed => '低速';

  @override
  String get gotIt => '知道了';

  @override
  String get unknownEquip => '未知裝備';

  @override
  String get noBonusStats => '暫無附加屬性';

  @override
  String get condition => '疲勞';

  @override
  String get noExpeditionFleet => '暫無遠征中的艦隊';

  @override
  String get expeditionInProgress => '遠征進行中';

  @override
  String get progress => '進行進度';

  @override
  String get unlocked => '未解鎖';

  @override
  String get notRepairing => '未入渠';

  @override
  String get repairProgress => '修理進度';

  @override
  String get cost => '消耗';

  @override
  String get notConstructing => '未建造';

  @override
  String get lsc => '大型建造';

  @override
  String get normalConstruct => '常規建造';

  @override
  String get constructing => '建造中';

  @override
  String get constructProgress => '建造進度';

  @override
  String get constructComplete => '建造完成';

  @override
  String get allRatings => '全部評級';

  @override
  String get noBattleRecords => '尚無戰鬥記錄';

  @override
  String get autoRecordHint => '出擊後會自動記錄，不需要額外操作';

  @override
  String get enemyFleet => '敵艦隊';

  @override
  String get thisSortie => '本次出擊';

  @override
  String get historicalRecords => '歷史戰果';

  @override
  String get resourceTrend => '資源趨勢';

  @override
  String get expeditionIncome => '遠征收益';

  @override
  String get noHistoricalRecords => '暫無歷史戰果';

  @override
  String get none => '無';

  @override
  String get unknownNode => '未知點';

  @override
  String get noResourceRecords => '暫無資源記錄';

  @override
  String get resourceTrend24h => '24小時';

  @override
  String get resourceTrend7d => '7天';

  @override
  String get resourceTrend30d => '30天';

  @override
  String get resourceTrendAll => '全部記錄';

  @override
  String get resourceTrendMainGroup => '四項資源';

  @override
  String get resourceTrendAuxGroup => '輔助資源';

  @override
  String get gadgetBypass => '遊戲客戶端資源繞行（實驗性）';

  @override
  String get gadgetBypassDesc =>
      '僅在客戶端靜態資源伺服器受限時改用鏡像；不修改 DMM 登入、Cookie 或遊戲資料介面。關閉時完全旁路。';

  @override
  String get gadgetBypassEnable => '開啟繞行';

  @override
  String get gadgetBypassEndpoint => '鏡像端點';

  @override
  String get endpointCustom => '自訂';

  @override
  String get gadgetBypassStatusOn => '已啟用';

  @override
  String get gadgetBypassStatusOff => '未啟用';

  @override
  String get gadgetBypassUnsupported => '目前裝置不支援（需要 Android 8.0+）';

  @override
  String get gadgetBypassClearCache => '清空快取';

  @override
  String get gadgetBypassError => '繞行配置失敗';

  @override
  String get gadgetBypassDiagnose => '檢查 403 與鏡像連通性';

  @override
  String get gadgetBypassDiagnosing => '診斷中...';

  @override
  String get gadgetBypassW00g => '用戶端伺服器 (w00g)';

  @override
  String get gadgetBypassEndpointProbe => '鏡像端點';

  @override
  String get gadgetBypassKcsapi => '遊戲資料介面 (kcsapi)';

  @override
  String get gadgetBypassReachable => '暢通';

  @override
  String get gadgetBypassUnreachable => '無法連接';

  @override
  String get resourceTrendChart => '資源趨勢變化 (最近 100 次記錄)';

  @override
  String get steel => '鋼材';

  @override
  String get bauxite => '鋁土';

  @override
  String get noExpeditionRecords => '暫無遠征記錄';

  @override
  String get expeditionIncomeChart => '遠征收益統計 (最近 7 天)';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langJa => '日本語';

  @override
  String get node => '点';

  @override
  String get friend => '我方';

  @override
  String get enemy => '敵方';

  @override
  String get drop => '掉落';

  @override
  String get inExpedition => '遠征中';

  @override
  String get unknownProgress => '進度未知';

  @override
  String get waitingForPortData => '等待母港數據';

  @override
  String get waitingForPortDataDescription => '進入遊戲母港或刷新遊戲頁面後，這裡會自動更新';

  @override
  String get fleetNotFormed => '未編成';

  @override
  String get fleetStandby => '母港待命';

  @override
  String get shipsCount => '艦';

  @override
  String get noValue => '無';

  @override
  String get lineOfSight => '索敵';

  @override
  String get averageCondition => '平均疲勞';

  @override
  String get losDetails => '索敵詳情';

  @override
  String get unknownShipType => '未知艦種';

  @override
  String get needsSupply => '需要補給';

  @override
  String get equipmentDataWaiting => '裝備數據等待更新';

  @override
  String get highSpeed => '高速';

  @override
  String get lowSpeed => '低速';

  @override
  String get unknownEquipment => '未知裝備';

  @override
  String get noAdditionalStats => '暫無附加屬性';

  @override
  String get fatigue => '疲勞';
}
