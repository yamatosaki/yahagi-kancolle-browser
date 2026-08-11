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
  String get repair => '修理';

  @override
  String get construction => '建造';

  @override
  String get quests => '任务';

  @override
  String get battleRecords => '航海日志';

  @override
  String get settings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get layoutSettings => '界面与布局';

  @override
  String get gameAreaRatio => '游戏区域占比';

  @override
  String get infoPanelWidth => '信息面板宽度（竖屏模式无效）';

  @override
  String get autoZoom => '应用推荐显示比例（游戏与菜单比例 65:35）';

  @override
  String get enhancedDamagePulse => '加强受损呼吸提示';

  @override
  String get enhancedDamagePulseDesc => '按小破、中破、大破增强颜色、速度和头像内部光效。关闭后使用普通效果。';

  @override
  String get workspaceMenuOnRight => '菜单栏置于右侧';

  @override
  String get workspaceMenuOnRightDesc => '关闭时菜单栏保持在左侧。';

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
  String get repairBrief => '维修简报';

  @override
  String get repairDockMode => '入渠';

  @override
  String get anchorageRepairMode => '泊地';

  @override
  String get idle => '空闲';

  @override
  String get inactive => '闲置';

  @override
  String get repairing => '正在修理';

  @override
  String get outOfRepairRange => '超出修理范围';

  @override
  String get unableToRepair => '无法修理';

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
  String get aboutSubtitle => '版本 学习版 1.0.2 · 免责声明 · 检查更新';

  @override
  String get version => '版本 学习版 1.0.2';

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
  String get logoutSnackbar => '已退出登录并清除账号信息。';

  @override
  String get logoutConfirmTitle => '退出登录并清除账号信息';

  @override
  String get logoutConfirmDesc => '将清除应用内游戏页面的 Cookie、本地存储和缓存，然后返回登录页面。确定继续吗？';

  @override
  String get logoutSucceeded => '已退出登录，请重新登录。';

  @override
  String get logoutFailed => '退出登录失败，请稍后重试。';

  @override
  String get questCacheCleared => '已清除任务数据本地缓存';

  @override
  String get webCacheCleared => '已清理游戏 Web 缓存';

  @override
  String get clearLogbook => '清理航海日志数据';

  @override
  String get clearLogbookDesc => '清除本地保存的出击、远征、建造、开发、除籍与资源记录。此操作不可逆。';

  @override
  String get clearLogbookConfirmTitle => '清理航海日志数据';

  @override
  String get clearLogbookConfirmDesc =>
      '确定要清空所有航海日志数据吗？出击、远征、建造、开发、除籍和资源记录都会被删除。此操作无法撤销。';

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
  String get avgCondition => '最低疲劳';

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
  String get averageCondition => '最低疲劳';

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

  @override
  String get startupUpdateTitle => '发现新版本';

  @override
  String get backgroundAudio => '后台播放声音';

  @override
  String get backgroundAudioDesc => '开启后，应用进入后台时游戏声音仍会继续播放。';

  @override
  String get screenAwake => '屏幕常亮';

  @override
  String get screenAwakeDesc => '开启后，应用在前台期间屏幕不会自动关闭，可能增加耗电。';

  @override
  String get gameToolbar => '游戏工具栏';

  @override
  String get toolbarAutoHide => '自动隐藏';

  @override
  String get toolbarPersistent => '常驻';

  @override
  String get back => '返回';

  @override
  String get reload => '刷新';

  @override
  String get home => '回到主页';

  @override
  String get enterDmm => '进入 DMM 登录';

  @override
  String get enableGameAudio => '开启游戏声音';

  @override
  String get disableGameAudio => '关闭游戏声音';

  @override
  String get takeScreenshot => '一键截图';

  @override
  String get screenshotSaving => '正在保存游戏截图…';

  @override
  String get fitGameScreen => '修复显示（自适应屏幕）';

  @override
  String get collapseToolbar => '收起工具栏';

  @override
  String get editDone => '完成编辑';

  @override
  String get retryWithSystemNetwork => '改用系统网络重试';

  @override
  String get displayMode => '显示模式';

  @override
  String get displayAuto => '自动';

  @override
  String get displayLandscape => '横屏';

  @override
  String get displayPortrait => '竖屏';

  @override
  String get allRanks => '全部评级';

  @override
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  ) {
    return '我方 $friendAlive/$friendTotal　敌方 $enemyAlive/$enemyTotal';
  }

  @override
  String dropLabel(String name) {
    return '掉落：$name';
  }

  @override
  String get item => '道具';

  @override
  String get friendFinalStatus => '我方最终状态';

  @override
  String get enemyFinalStatus => '敌方最终状态';

  @override
  String airStateLabel(String label) {
    return '制空：$label';
  }

  @override
  String get postBattleWarningTitle => '战后安全警告';

  @override
  String get postBattleWarningHeadline => '出击舰队中存在大破舰娘！';

  @override
  String get postBattleWarningBody => '请在接下来的选择界面务必点击“撤退”，切勿强行进击以免沉船！';

  @override
  String get acknowledgeAndRetreat => '确认了解并撤退';

  @override
  String get postBattleWarningBanner => '战后安全警告：出击舰队中存在大破舰娘！请注意撤退！';

  @override
  String get noActiveExpedition => '没有正在进行的远征';

  @override
  String get noSortieWarnings => '暂无出击警告';

  @override
  String preSortieCriticalWarning(String fleetName) {
    return '$fleetName 存在大破舰，停止出击！';
  }

  @override
  String preSortieSupplyWarning(String fleetName) {
    return '$fleetName 舰娘未补给';
  }

  @override
  String preSortieFatigueWarning(String fleetName) {
    return '$fleetName 舰娘疲劳未恢复';
  }

  @override
  String preSortieMainEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 装备缺失（主装备槽）：$shipNames';
  }

  @override
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 装备缺失（增设槽）：$shipNames';
  }

  @override
  String get noPinnedQuests => '当前无进行中任务';

  @override
  String get questsNeedSync => '需进入任务界面同步信息';

  @override
  String get waitingQuestData => '等待任务数据';

  @override
  String get waitingQuestDataDesc => '打开游戏任务列表后，这里会自动同步当前已接受任务';

  @override
  String get diagnosticsAndAbout => '诊断与关于';

  @override
  String get safetyBoundary => '安全边界';

  @override
  String get applyingNetworkSettings => '正在应用网络设置…';

  @override
  String networkSettingsApplied(String message) {
    return '网络设置应用成功：$message';
  }

  @override
  String get clearingProxy => '正在清除应用内代理…';

  @override
  String get systemNetworkRestored => '已恢复系统网络。';

  @override
  String screenshotSaved(String path) {
    return '游戏截图已保存到相册：$path';
  }

  @override
  String get screenshotFailed => '游戏截图失败，请稍后重试。';

  @override
  String startupUpdateMessage(String version) {
    return 'ヤハギ $version 已发布。';
  }

  @override
  String get gameStatusError => '游戏状态异常';

  @override
  String get gameStatusErrorDesc => '网页或捕获状态异常，请在设置中查看诊断信息。';

  @override
  String get browserOnlyCaptureOff => '纯浏览模式 · 数据捕获已关闭';

  @override
  String get browserOnlyCaptureOffDesc => '游戏网页继续运行，舰队、任务和战斗信息暂停更新。';

  @override
  String capturedCount(int count) {
    return '已捕获 $count 条';
  }

  @override
  String get waitingKcsapi => '等待 /kcsapi/ 响应';

  @override
  String get ignoredNonTargetMessage => '已忽略非目标消息';

  @override
  String get readOnlyNoActions => '只读取，不操作';

  @override
  String get readOnlyNoActionsDesc => '不会自动点击、补给、编成、出击或领取任务。';

  @override
  String get noCookieRead => '不读取 Cookie';

  @override
  String get noCookieReadDesc => 'JS 桥接消息只包含接口路径、响应正文和时间。';

  @override
  String get browserIdle => '等待网页';

  @override
  String get browserLoading => '网页加载中';

  @override
  String get browserReady => '网页已就绪';

  @override
  String get browserFailed => '网页加载失败';

  @override
  String get capturePreparing => '正在准备游戏接口捕获';

  @override
  String get captureReady => '捕获已就绪';

  @override
  String get captureActive => '正在捕获游戏接口';

  @override
  String get captureUnsupported => '当前 WebView 不支持跨框架捕获';

  @override
  String get captureFailed => '游戏接口捕获启动失败';

  @override
  String get captureCheckingDesc => '正在检查 Android WebView 捕获能力。';

  @override
  String get captureReadyDesc => '等待 /kcsapi/ 响应，游戏仍可正常操作。';

  @override
  String get portCaptureVerified => '母港接口验证通过';

  @override
  String get captureReceived => '已经收到游戏接口。';

  @override
  String captureLatest(String path) {
    return '最近一次捕获：$path';
  }

  @override
  String get captureUnsupportedDesc => '游戏仍可运行；当前设备只提供网页浏览。';

  @override
  String get captureFailedDesc => '游戏仍可运行，可刷新页面后重试。';

  @override
  String networkApplyFailed(String code, String message) {
    return '设置失败 [$code]：$message';
  }

  @override
  String networkRestoreFailed(String code, String message) {
    return '恢复失败 [$code]：$message';
  }

  @override
  String get tcpConnection => 'TCP 连接';

  @override
  String get gameService => '游戏服务';

  @override
  String get externalNetwork => 'Google（外网）';

  @override
  String get statusUnknown => '未知';

  @override
  String get statusSuccess => '成功';

  @override
  String get statusFailed => '失败';

  @override
  String get statusSkipped => '跳过';

  @override
  String get formula33 => '33式';

  @override
  String fatigueValue(int value) {
    return '疲劳 $value';
  }

  @override
  String get fcdMapSectionTitle => '数据更新';

  @override
  String get fcdMapDataTitle => '未卜先知数据';

  @override
  String fcdMapDataVersion(String version) {
    return '数据版本：$version';
  }

  @override
  String fcdMapLastChecked(String time) {
    return '上次检查：$time';
  }

  @override
  String get fcdMapNeverChecked => '上次检查：尚未检查';

  @override
  String fcdMapSource(String source) {
    return '更新源：$source';
  }

  @override
  String get fcdMapAttribution => '数据来源：poi FCD（MIT）';

  @override
  String get fcdMapCheckUpdates => '检查未卜先知数据更新';

  @override
  String get fcdMapUpToDate => '未卜先知数据已经是最新版本。';

  @override
  String fcdMapUpdated(String oldVersion, String newVersion) {
    return '未卜先知数据已从 $oldVersion 更新至 $newVersion，已立即生效。';
  }

  @override
  String get fcdMapNetworkError => '未能连接数据更新源，请稍后重试。';

  @override
  String get fcdMapValidationError => '下载的数据未通过校验，已保留当前版本。';

  @override
  String get fcdMapStorageError => '数据保存失败，已保留当前版本。';

  @override
  String get questCatalogDataTitle => '任务资料';

  @override
  String questCatalogDataVersion(String version) {
    return '资料版本：$version';
  }

  @override
  String get questCatalogNeverChecked => '上次检查：尚未检查';

  @override
  String questCatalogLastChecked(String time) {
    return '上次检查：$time';
  }

  @override
  String get questCatalogCheckUpdates => '检查任务资料更新';

  @override
  String get questCatalogUpToDate => '任务资料已经是最新版本。';

  @override
  String questCatalogUpdated(String oldVersion, String newVersion) {
    return '任务资料已从 $oldVersion 更新至 $newVersion，并已立即生效。';
  }

  @override
  String get questCatalogNetworkError => '无法连接任务资料更新源，请稍后再试。';

  @override
  String get questCatalogValidationError => '下载的任务资料未通过验证，已保留当前版本。';

  @override
  String get questCatalogStorageError => '任务资料保存失败，已保留当前版本。';

  @override
  String get gameFrameRateTitle => '解除 60 FPS 上限';

  @override
  String get gameFrameRateOff => '关闭';

  @override
  String get gameFrameRateMax60 => '最高 60 FPS';

  @override
  String get gameFrameRateFollowDisplay => '跟随屏幕';

  @override
  String get gameFrameRateOffDesc => '保持游戏原始帧率行为。';

  @override
  String get gameFrameRateMax60Desc => '使用 RAF 渲染，并将目标帧率限制为最高 60 FPS。';

  @override
  String get gameFrameRateFollowDisplayDesc =>
      '使用 GotoBrowser 同款主脚本补丁，让游戏跟随设备刷新率；可能增加耗电和发热。';

  @override
  String get gameFrameRateUnsupported => '当前 Android WebView 不支持解除帧率上限';

  @override
  String get gameFrameRateRestartRequired => '重新加载游戏页面后生效';

  @override
  String get gameRenderingModeTitle => '游戏渲染兼容模式';

  @override
  String get gameRenderingModeStandard => '标准模式';

  @override
  String get gameRenderingModeStandardDesc =>
      'Texture Layer + WebGL，保留工具栏模糊效果。';

  @override
  String get gameRenderingModeCompatibility => '兼容模式';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Hybrid Composition + WebGL，关闭工具栏模糊；适合华为、荣耀设备卡顿时尝试。';

  @override
  String get gameRenderingModeCanvas => '深度兼容模式';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Hybrid Composition + Canvas，关闭工具栏模糊；兼容性优先，画面性能可能降低。';

  @override
  String get gameRenderingModeConfirmTitle => '切换游戏渲染模式？';

  @override
  String get gameRenderingModeConfirmMessage =>
      '切换后将自动重建游戏页面，当前页面会短暂关闭并重新载入。请先避免正在进行的操作。';

  @override
  String get gameRenderingModeBattleWarning =>
      '检测到可能正在战斗。现在切换可能中断当前战斗页面，建议结束战斗后再操作。';

  @override
  String get gameRenderingModeChanging => '正在重建游戏页面…';

  @override
  String get gameRenderingModeApplied => '渲染模式已切换。';

  @override
  String get gameRenderingModeFailed => '切换失败，已保留或回退到安全模式。';

  @override
  String get senka => '战果';

  @override
  String get ownedInventory => '持有一览';

  @override
  String get improvement => '改修';

  @override
  String get briefing => '简报';

  @override
  String get check => '检查';

  @override
  String get restoreDefaultOrder => '还原默认排序';

  @override
  String get settingsTabScreen => '画面';

  @override
  String get settingsTabSound => '声音';

  @override
  String get settingsTabBattle => '战斗';

  @override
  String get settingsTabNetwork => '网络';

  @override
  String get settingsTabAboutSupport => '关于与支持';

  @override
  String get frameRateSettingsSection => '帧率设置';

  @override
  String get battleAlertsSection => '战斗提醒';

  @override
  String get battleDamageVibration => '战斗受损震动提醒';

  @override
  String get battleDamageVibrationDesc => '我方舰娘在战斗中刚进入中破或大破时震动提醒。';

  @override
  String get battlePredictionSection => '战斗预测';

  @override
  String get battlePredictionEngine => '战斗预测引擎';

  @override
  String get battlePredictionRecommendation => '推荐使用增强模式，可获得更完整的战斗预测结果。';

  @override
  String get battlePredictionHighAccuracy => '增强模式';

  @override
  String get battlePredictionLightweight => '轻量模式';

  @override
  String get battlePredictionHighAccuracyDesc => '按战斗模拟规则完整复演，预测更精确，但性能开销更高。';

  @override
  String get battlePredictionLightweightDesc => '使用轻量化预测逻辑，性能开销更低。';

  @override
  String get battlePredictionNextBattle => '切换从下一场战斗开始生效。';

  @override
  String get improvementDatasetTitle => '改修规划资料';

  @override
  String improvementDatasetVersion(String version) {
    return '资料版本 $version';
  }

  @override
  String get improvementDatasetNeverChecked => '尚未手动检查';

  @override
  String improvementDatasetLastChecked(String time) {
    return '最近检查 $time';
  }

  @override
  String get improvementDatasetManualUpdate => '手动更新改修资料';

  @override
  String improvementDatasetUpToDate(String version) {
    return '当前已经是最新资料（$version）';
  }

  @override
  String improvementDatasetUpdated(String oldVersion, String newVersion) {
    return '改修资料已从 $oldVersion 更新到 $newVersion，页面已立即刷新。';
  }

  @override
  String improvementDatasetNetworkError(String version) {
    return '网络连接失败，已继续使用本地资料（$version）。';
  }

  @override
  String improvementDatasetValidationError(String version) {
    return '远程资料校验失败，未替换本地资料（$version）。';
  }

  @override
  String improvementDatasetStorageError(String version) {
    return '资料保存失败，未替换本地资料（$version）。';
  }

  @override
  String get networkValidationHostEmpty => '地址不能为空';

  @override
  String get networkValidationControlCharacter => '不允许包含换行或控制字符';

  @override
  String get networkValidationHttpScheme => '地址中不要包含 http://，只需填写服务器地址。';

  @override
  String get networkValidationSocksScheme => '地址中不要包含 socks://，只需填写服务器地址。';

  @override
  String get networkValidationScheme => '地址中不要包含协议头';

  @override
  String get networkValidationPath => '不允许包含路径';

  @override
  String get networkValidationCredentials => '不允许包含用户名或密码';

  @override
  String get networkValidationIpv6 => 'IPv6 地址格式不正确（含有非法字符）';

  @override
  String get networkValidationPortEmpty => '端口不能为空';

  @override
  String get networkValidationPortDecimal => '端口不允许使用小数';

  @override
  String get networkValidationPortNegative => '端口不允许使用负数';

  @override
  String get networkValidationPortZero => '端口不能为 0';

  @override
  String get networkValidationPortInteger => '端口必须为整数';

  @override
  String get networkValidationPortRange => '端口范围为 1 至 65535';

  @override
  String get gadgetBypassRestricted => '受限';

  @override
  String get networkProxyOperationBusy => '代理设置正在应用中';

  @override
  String get networkUnknownProxyMode => '未知代理模式';

  @override
  String get shipGirl => '舰娘';

  @override
  String get equipment => '装备';

  @override
  String get inventoryTypeSuffix => ' 种';

  @override
  String get inventoryFilterResults => '筛选结果 ';

  @override
  String get shipName => '舰名';

  @override
  String get shipType => '舰种';

  @override
  String get level => '等级';

  @override
  String get armor => '装甲';

  @override
  String get luck => '幸运';

  @override
  String get evasion => '回避';

  @override
  String get lockedStatus => '锁定';

  @override
  String get equipmentName => '装备名称';

  @override
  String get equipmentTotalRemaining => '总数（剩余）';

  @override
  String get equipmentImprovementProficiency => '改修／熟练度';

  @override
  String get equipmentUsage => '着装情况';

  @override
  String get highSpeedPlus => '高速+';

  @override
  String get all => '全部';

  @override
  String get equipmentMainGun => '主炮';

  @override
  String get equipmentSecondaryGun => '副炮／高角炮';

  @override
  String get equipmentMachineGun => '机枪';

  @override
  String get equipmentTorpedo => '鱼雷／甲标';

  @override
  String get equipmentCarrierAircraft => '舰载机';

  @override
  String get equipmentSeaplane => '水上机';

  @override
  String get equipmentLandBasedAircraft => '陆航';

  @override
  String get equipmentRadar => '电探';

  @override
  String get equipmentLandingTransport => '登陆／运输';

  @override
  String get equipmentSupport => '辅助／其他';

  @override
  String get questAll => '全任务';

  @override
  String get searchQuest => '搜索任务';

  @override
  String get filterQuest => '筛选任务';

  @override
  String get searchQuestHint => '搜索编号、任务名或说明';

  @override
  String get clear => '清除';

  @override
  String get done => '完成';

  @override
  String get clearAll => '清除全部';

  @override
  String get questType => '任务类型';

  @override
  String get allTypes => '全部类型';

  @override
  String get questFormation => '编成';

  @override
  String get questSortie => '出击';

  @override
  String get questExercise => '演习';

  @override
  String get questSupplyRepair => '补给/入渠';

  @override
  String get questFactory => '工厂';

  @override
  String get questRemodeling => '改装';

  @override
  String get questPeriod => '任务周期';

  @override
  String get allPeriods => '全部周期';

  @override
  String get questSeasonal => '季常';

  @override
  String get questYearly => '年常';

  @override
  String get unlockStatus => '解锁状态';

  @override
  String get allStatuses => '全部状态';

  @override
  String get questUnlocked => '已解锁';

  @override
  String get questLocked => '未解锁';

  @override
  String get noDescription => '暂无说明';

  @override
  String get completionConditions => '完成条件';

  @override
  String get questRelations => '任务关系';

  @override
  String get prerequisiteQuests => '前置任务';

  @override
  String get followingQuests => '后置任务';

  @override
  String get notCompleted => '未完成';
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
  String get repair => '修理';

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
  String get layoutSettings => '介面與佈局';

  @override
  String get gameAreaRatio => '遊戲區域佔比';

  @override
  String get infoPanelWidth => '資訊面板寬度（直屏模式無效）';

  @override
  String get autoZoom => '套用建議顯示比例（遊戲與選單比例 65:35）';

  @override
  String get enhancedDamagePulse => '加強受損呼吸提示';

  @override
  String get enhancedDamagePulseDesc => '依小破、中破、大破增強顏色、速度與頭像內部光效。關閉後使用普通效果。';

  @override
  String get workspaceMenuOnRight => '選單列置於右側';

  @override
  String get workspaceMenuOnRightDesc => '關閉時選單列保持在左側。';

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
  String get repairBrief => '維修簡報';

  @override
  String get repairDockMode => '入渠';

  @override
  String get anchorageRepairMode => '泊地';

  @override
  String get idle => '空閒';

  @override
  String get inactive => '閒置';

  @override
  String get repairing => '正在修理';

  @override
  String get outOfRepairRange => '超出修理範圍';

  @override
  String get unableToRepair => '無法修理';

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
  String get aboutSubtitle => '版本 學習版 1.0.2 · 免責聲明 · 檢查更新';

  @override
  String get version => '版本 學習版 1.0.2';

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
  String get logoutSnackbar => '已登出並清除帳號資訊。';

  @override
  String get logoutConfirmTitle => '登出並清除帳號資訊';

  @override
  String get logoutConfirmDesc =>
      '將清除應用程式內遊戲頁面的 Cookie、本機儲存空間與快取，然後返回登入頁面。確定繼續嗎？';

  @override
  String get logoutSucceeded => '已登出，請重新登入。';

  @override
  String get logoutFailed => '登出失敗，請稍後再試。';

  @override
  String get questCacheCleared => '已清除任務資料本機快取';

  @override
  String get webCacheCleared => '已清理遊戲 Web 快取';

  @override
  String get clearLogbook => '清理航海日誌資料';

  @override
  String get clearLogbookDesc => '清除本機儲存的出擊、遠征、建造、開發、除籍與資源記錄。此操作不可逆。';

  @override
  String get clearLogbookConfirmTitle => '清理航海日誌資料';

  @override
  String get clearLogbookConfirmDesc =>
      '確定要清空所有航海日誌資料嗎？出擊、遠征、建造、開發、除籍和資源記錄都會被刪除。此操作無法撤銷。';

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
  String get avgCondition => '最低疲勞';

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
  String get node => '點';

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
  String get averageCondition => '最低疲勞';

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

  @override
  String get startupUpdateTitle => '發現新版本';

  @override
  String get backgroundAudio => '背景播放聲音';

  @override
  String get backgroundAudioDesc => '開啟後，應用程式進入背景時遊戲聲音仍會繼續播放。';

  @override
  String get screenAwake => '螢幕保持開啟';

  @override
  String get screenAwakeDesc => '開啟後，應用程式位於前景時螢幕不會自動關閉，可能增加耗電。';

  @override
  String get gameToolbar => '遊戲工具列';

  @override
  String get toolbarAutoHide => '自動隱藏';

  @override
  String get toolbarPersistent => '常駐';

  @override
  String get back => '返回';

  @override
  String get reload => '重新整理';

  @override
  String get home => '返回首頁';

  @override
  String get enterDmm => '進入 DMM 登入';

  @override
  String get enableGameAudio => '開啟遊戲聲音';

  @override
  String get disableGameAudio => '關閉遊戲聲音';

  @override
  String get takeScreenshot => '遊戲截圖';

  @override
  String get screenshotSaving => '正在儲存遊戲截圖…';

  @override
  String get fitGameScreen => '修正顯示（自動適應螢幕）';

  @override
  String get collapseToolbar => '收起工具列';

  @override
  String get editDone => '完成編輯';

  @override
  String get retryWithSystemNetwork => '改用系統網路重試';

  @override
  String get displayMode => '顯示模式';

  @override
  String get displayAuto => '自動';

  @override
  String get displayLandscape => '橫向';

  @override
  String get displayPortrait => '直向';

  @override
  String get allRanks => '全部評級';

  @override
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  ) {
    return '我方 $friendAlive/$friendTotal　敵方 $enemyAlive/$enemyTotal';
  }

  @override
  String dropLabel(String name) {
    return '掉落：$name';
  }

  @override
  String get item => '道具';

  @override
  String get friendFinalStatus => '我方最終狀態';

  @override
  String get enemyFinalStatus => '敵方最終狀態';

  @override
  String airStateLabel(String label) {
    return '制空：$label';
  }

  @override
  String get postBattleWarningTitle => '戰後安全警告';

  @override
  String get postBattleWarningHeadline => '出擊艦隊中有大破艦娘！';

  @override
  String get postBattleWarningBody => '請務必在接下來的選擇畫面點選「撤退」，切勿強行進擊以免沉船！';

  @override
  String get acknowledgeAndRetreat => '確認並撤退';

  @override
  String get postBattleWarningBanner => '戰後安全警告：出擊艦隊中有大破艦娘！請注意撤退！';

  @override
  String get noActiveExpedition => '沒有正在進行的遠征';

  @override
  String get noSortieWarnings => '暫無出擊警告';

  @override
  String preSortieCriticalWarning(String fleetName) {
    return '$fleetName 存在大破艦，停止出擊！';
  }

  @override
  String preSortieSupplyWarning(String fleetName) {
    return '$fleetName 艦娘尚未補給';
  }

  @override
  String preSortieFatigueWarning(String fleetName) {
    return '$fleetName 艦娘疲勞尚未恢復';
  }

  @override
  String preSortieMainEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 裝備缺失（主裝備欄）：$shipNames';
  }

  @override
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 裝備缺失（增設欄）：$shipNames';
  }

  @override
  String get noPinnedQuests => '目前無進行中任務';

  @override
  String get questsNeedSync => '需進入任務介面同步資訊';

  @override
  String get waitingQuestData => '等待任務資料';

  @override
  String get waitingQuestDataDesc => '開啟遊戲任務列表後，這裡會自動同步目前已接受的任務';

  @override
  String get diagnosticsAndAbout => '診斷與關於';

  @override
  String get safetyBoundary => '安全界線';

  @override
  String get applyingNetworkSettings => '正在套用網路設定…';

  @override
  String networkSettingsApplied(String message) {
    return '網路設定套用成功：$message';
  }

  @override
  String get clearingProxy => '正在清除應用程式內代理…';

  @override
  String get systemNetworkRestored => '已恢復系統網路。';

  @override
  String screenshotSaved(String path) {
    return '遊戲截圖已儲存至相簿：$path';
  }

  @override
  String get screenshotFailed => '遊戲截圖失敗，請稍後再試。';

  @override
  String startupUpdateMessage(String version) {
    return 'ヤハギ $version 已發布。';
  }

  @override
  String get gameStatusError => '遊戲狀態異常';

  @override
  String get gameStatusErrorDesc => '網頁或擷取狀態異常，請在設定中查看診斷資訊。';

  @override
  String get browserOnlyCaptureOff => '純瀏覽模式 · 資料擷取已關閉';

  @override
  String get browserOnlyCaptureOffDesc => '遊戲網頁繼續運行，艦隊、任務和戰鬥資訊暫停更新。';

  @override
  String capturedCount(int count) {
    return '已擷取 $count 條';
  }

  @override
  String get waitingKcsapi => '等待 /kcsapi/ 回應';

  @override
  String get ignoredNonTargetMessage => '已忽略非目標訊息';

  @override
  String get readOnlyNoActions => '只讀取，不操作';

  @override
  String get readOnlyNoActionsDesc => '不會自動點擊、補給、編成、出擊或領取任務。';

  @override
  String get noCookieRead => '不讀取 Cookie';

  @override
  String get noCookieReadDesc => 'JS 橋接訊息只包含介面路徑、回應本文和時間。';

  @override
  String get browserIdle => '等待網頁';

  @override
  String get browserLoading => '網頁載入中';

  @override
  String get browserReady => '網頁已就緒';

  @override
  String get browserFailed => '網頁載入失敗';

  @override
  String get capturePreparing => '正在準備遊戲介面擷取';

  @override
  String get captureReady => '擷取已就緒';

  @override
  String get captureActive => '正在擷取遊戲介面';

  @override
  String get captureUnsupported => '目前 WebView 不支援跨框架擷取';

  @override
  String get captureFailed => '遊戲介面擷取啟動失敗';

  @override
  String get captureCheckingDesc => '正在檢查 Android WebView 擷取能力。';

  @override
  String get captureReadyDesc => '等待 /kcsapi/ 回應，遊戲仍可正常操作。';

  @override
  String get portCaptureVerified => '母港介面驗證通過';

  @override
  String get captureReceived => '已經收到遊戲介面。';

  @override
  String captureLatest(String path) {
    return '最近一次擷取：$path';
  }

  @override
  String get captureUnsupportedDesc => '遊戲仍可運行；目前裝置只提供網頁瀏覽。';

  @override
  String get captureFailedDesc => '遊戲仍可運行，可重新整理頁面後重試。';

  @override
  String networkApplyFailed(String code, String message) {
    return '設定失敗 [$code]：$message';
  }

  @override
  String networkRestoreFailed(String code, String message) {
    return '恢復失敗 [$code]：$message';
  }

  @override
  String get tcpConnection => 'TCP 連線';

  @override
  String get gameService => '遊戲服務';

  @override
  String get externalNetwork => 'Google（外網）';

  @override
  String get statusUnknown => '未知';

  @override
  String get statusSuccess => '成功';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusSkipped => '略過';

  @override
  String get formula33 => '33式';

  @override
  String fatigueValue(int value) {
    return '疲勞 $value';
  }

  @override
  String get fcdMapSectionTitle => '資料更新';

  @override
  String get fcdMapDataTitle => '未卜先知資料';

  @override
  String fcdMapDataVersion(String version) {
    return '資料版本：$version';
  }

  @override
  String fcdMapLastChecked(String time) {
    return '上次檢查：$time';
  }

  @override
  String get fcdMapNeverChecked => '上次檢查：尚未檢查';

  @override
  String fcdMapSource(String source) {
    return '更新來源：$source';
  }

  @override
  String get fcdMapAttribution => '資料來源：poi FCD（MIT）';

  @override
  String get fcdMapCheckUpdates => '檢查未卜先知資料更新';

  @override
  String get fcdMapUpToDate => '未卜先知資料已是最新版本。';

  @override
  String fcdMapUpdated(String oldVersion, String newVersion) {
    return '未卜先知資料已從 $oldVersion 更新至 $newVersion，並已立即生效。';
  }

  @override
  String get fcdMapNetworkError => '無法連線至資料更新來源，請稍後再試。';

  @override
  String get fcdMapValidationError => '下載的資料未通過驗證，已保留目前版本。';

  @override
  String get fcdMapStorageError => '資料儲存失敗，已保留目前版本。';

  @override
  String get questCatalogDataTitle => '任務資料';

  @override
  String questCatalogDataVersion(String version) {
    return '資料版本：$version';
  }

  @override
  String get questCatalogNeverChecked => '上次檢查：尚未檢查';

  @override
  String questCatalogLastChecked(String time) {
    return '上次檢查：$time';
  }

  @override
  String get questCatalogCheckUpdates => '檢查任務資料更新';

  @override
  String get questCatalogUpToDate => '任務資料已是最新版本。';

  @override
  String questCatalogUpdated(String oldVersion, String newVersion) {
    return '任務資料已從 $oldVersion 更新至 $newVersion，並已立即生效。';
  }

  @override
  String get questCatalogNetworkError => '無法連線至任務資料更新來源，請稍後再試。';

  @override
  String get questCatalogValidationError => '下載的任務資料未通過驗證，已保留目前版本。';

  @override
  String get questCatalogStorageError => '任務資料儲存失敗，已保留目前版本。';

  @override
  String get gameFrameRateTitle => '解除 60 FPS 限制';

  @override
  String get gameFrameRateOff => '關閉';

  @override
  String get gameFrameRateMax60 => '最高 60 FPS';

  @override
  String get gameFrameRateFollowDisplay => '跟隨螢幕';

  @override
  String get gameFrameRateOffDesc => '保持遊戲原始幀率行為。';

  @override
  String get gameFrameRateMax60Desc => '使用 RAF 渲染，並將目標幀率限制為最高 60 FPS。';

  @override
  String get gameFrameRateFollowDisplayDesc =>
      '使用與 GotoBrowser 相同的主腳本補丁，讓遊戲跟隨裝置更新率；可能增加耗電與發熱。';

  @override
  String get gameFrameRateUnsupported => '目前 Android WebView 不支援解除幀率上限';

  @override
  String get gameFrameRateRestartRequired => '重新載入遊戲頁面後生效';

  @override
  String get gameRenderingModeTitle => '遊戲渲染相容模式';

  @override
  String get gameRenderingModeStandard => '標準模式';

  @override
  String get gameRenderingModeStandardDesc =>
      'Texture Layer + WebGL，保留工具列模糊效果。';

  @override
  String get gameRenderingModeCompatibility => '相容模式';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Hybrid Composition + WebGL，關閉工具列模糊；適合華為、榮耀裝置卡頓時嘗試。';

  @override
  String get gameRenderingModeCanvas => '深度相容模式';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Hybrid Composition + Canvas，關閉工具列模糊；相容性優先，畫面效能可能降低。';

  @override
  String get gameRenderingModeConfirmTitle => '切換遊戲渲染模式？';

  @override
  String get gameRenderingModeConfirmMessage =>
      '切換後將自動重建遊戲頁面，目前頁面會短暫關閉並重新載入。請先避免正在進行的操作。';

  @override
  String get gameRenderingModeBattleWarning =>
      '偵測到可能正在戰鬥。現在切換可能中斷目前戰鬥頁面，建議結束戰鬥後再操作。';

  @override
  String get gameRenderingModeChanging => '正在重建遊戲頁面…';

  @override
  String get gameRenderingModeApplied => '渲染模式已切換。';

  @override
  String get gameRenderingModeFailed => '切換失敗，已保留或回退至安全模式。';

  @override
  String get senka => '戰果';

  @override
  String get ownedInventory => '持有一覽';

  @override
  String get improvement => '改修';

  @override
  String get briefing => '簡報';

  @override
  String get check => '檢查';

  @override
  String get restoreDefaultOrder => '還原預設排序';

  @override
  String get settingsTabScreen => '畫面';

  @override
  String get settingsTabSound => '聲音';

  @override
  String get settingsTabBattle => '戰鬥';

  @override
  String get settingsTabNetwork => '網路';

  @override
  String get settingsTabAboutSupport => '關於與支援';

  @override
  String get frameRateSettingsSection => '幀率設定';

  @override
  String get battleAlertsSection => '戰鬥提醒';

  @override
  String get battleDamageVibration => '戰鬥受損震動提醒';

  @override
  String get battleDamageVibrationDesc => '我方艦娘在戰鬥中剛進入中破或大破時震動提醒。';

  @override
  String get battlePredictionSection => '戰鬥預測';

  @override
  String get battlePredictionEngine => '戰鬥預測引擎';

  @override
  String get battlePredictionRecommendation => '建議使用增強模式，可獲得更完整的戰鬥預測結果。';

  @override
  String get battlePredictionHighAccuracy => '增強模式';

  @override
  String get battlePredictionLightweight => '輕量模式';

  @override
  String get battlePredictionHighAccuracyDesc => '依照戰鬥模擬規則完整重演，預測更精確，但效能開銷較高。';

  @override
  String get battlePredictionLightweightDesc => '使用輕量化預測邏輯，效能開銷較低。';

  @override
  String get battlePredictionNextBattle => '切換將從下一場戰鬥開始生效。';

  @override
  String get improvementDatasetTitle => '改修規劃資料';

  @override
  String improvementDatasetVersion(String version) {
    return '資料版本 $version';
  }

  @override
  String get improvementDatasetNeverChecked => '尚未手動檢查';

  @override
  String improvementDatasetLastChecked(String time) {
    return '最近檢查 $time';
  }

  @override
  String get improvementDatasetManualUpdate => '手動更新改修資料';

  @override
  String improvementDatasetUpToDate(String version) {
    return '目前已是最新資料（$version）';
  }

  @override
  String improvementDatasetUpdated(String oldVersion, String newVersion) {
    return '改修資料已從 $oldVersion 更新至 $newVersion，頁面已立即重新整理。';
  }

  @override
  String improvementDatasetNetworkError(String version) {
    return '網路連線失敗，已繼續使用本機資料（$version）。';
  }

  @override
  String improvementDatasetValidationError(String version) {
    return '遠端資料驗證失敗，未取代本機資料（$version）。';
  }

  @override
  String improvementDatasetStorageError(String version) {
    return '資料儲存失敗，未取代本機資料（$version）。';
  }

  @override
  String get networkValidationHostEmpty => '位址不能為空';

  @override
  String get networkValidationControlCharacter => '不能包含換行或控制字元';

  @override
  String get networkValidationHttpScheme => '位址中請勿包含 http://，只需填寫伺服器位址。';

  @override
  String get networkValidationSocksScheme => '位址中請勿包含 socks://，只需填寫伺服器位址。';

  @override
  String get networkValidationScheme => '位址中請勿包含通訊協定前綴';

  @override
  String get networkValidationPath => '不能包含路徑';

  @override
  String get networkValidationCredentials => '不能包含使用者名稱或密碼';

  @override
  String get networkValidationIpv6 => 'IPv6 位址格式不正確（含有非法字元）';

  @override
  String get networkValidationPortEmpty => '連接埠不能為空';

  @override
  String get networkValidationPortDecimal => '連接埠不能使用小數';

  @override
  String get networkValidationPortNegative => '連接埠不能使用負數';

  @override
  String get networkValidationPortZero => '連接埠不能為 0';

  @override
  String get networkValidationPortInteger => '連接埠必須為整數';

  @override
  String get networkValidationPortRange => '連接埠範圍為 1 至 65535';

  @override
  String get gadgetBypassRestricted => '受限';

  @override
  String get networkProxyOperationBusy => '代理設定正在套用中';

  @override
  String get networkUnknownProxyMode => '未知的代理模式';

  @override
  String get shipGirl => '艦娘';

  @override
  String get equipment => '裝備';

  @override
  String get inventoryTypeSuffix => ' 種';

  @override
  String get inventoryFilterResults => '篩選結果 ';

  @override
  String get shipName => '艦名';

  @override
  String get shipType => '艦種';

  @override
  String get level => '等級';

  @override
  String get armor => '裝甲';

  @override
  String get luck => '幸運';

  @override
  String get evasion => '迴避';

  @override
  String get lockedStatus => '鎖定';

  @override
  String get equipmentName => '裝備名稱';

  @override
  String get equipmentTotalRemaining => '總數（剩餘）';

  @override
  String get equipmentImprovementProficiency => '改修／熟練度';

  @override
  String get equipmentUsage => '裝備情況';

  @override
  String get highSpeedPlus => '高速+';

  @override
  String get all => '全部';

  @override
  String get equipmentMainGun => '主砲';

  @override
  String get equipmentSecondaryGun => '副砲／高角砲';

  @override
  String get equipmentMachineGun => '機槍';

  @override
  String get equipmentTorpedo => '魚雷／甲標';

  @override
  String get equipmentCarrierAircraft => '艦載機';

  @override
  String get equipmentSeaplane => '水上機';

  @override
  String get equipmentLandBasedAircraft => '陸航';

  @override
  String get equipmentRadar => '電探';

  @override
  String get equipmentLandingTransport => '登陸／運輸';

  @override
  String get equipmentSupport => '輔助／其他';

  @override
  String get questAll => '全部任務';

  @override
  String get searchQuest => '搜尋任務';

  @override
  String get filterQuest => '篩選任務';

  @override
  String get searchQuestHint => '搜尋編號、任務名稱或說明';

  @override
  String get clear => '清除';

  @override
  String get done => '完成';

  @override
  String get clearAll => '全部清除';

  @override
  String get questType => '任務類型';

  @override
  String get allTypes => '全部類型';

  @override
  String get questFormation => '編成';

  @override
  String get questSortie => '出擊';

  @override
  String get questExercise => '演習';

  @override
  String get questSupplyRepair => '補給/入渠';

  @override
  String get questFactory => '工廠';

  @override
  String get questRemodeling => '改裝';

  @override
  String get questPeriod => '任務週期';

  @override
  String get allPeriods => '全部週期';

  @override
  String get questSeasonal => '季常';

  @override
  String get questYearly => '年常';

  @override
  String get unlockStatus => '解鎖狀態';

  @override
  String get allStatuses => '全部狀態';

  @override
  String get questUnlocked => '已解鎖';

  @override
  String get questLocked => '未解鎖';

  @override
  String get noDescription => '暫無說明';

  @override
  String get completionConditions => '完成條件';

  @override
  String get questRelations => '任務關係';

  @override
  String get prerequisiteQuests => '前置任務';

  @override
  String get followingQuests => '後置任務';

  @override
  String get notCompleted => '未完成';
}
