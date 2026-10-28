// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get debuffReminderTitle => '削甲提醒';

  @override
  String get debuffReminderSourcePort => '母港';

  @override
  String get debuffReminderSourceBattleResult => '战斗结算';

  @override
  String get debuffReminderSourceAirDefense => '基地防空';

  @override
  String debuffReminderMessage(String source) {
    return '$source：检测到解谜／削弱提示。';
  }

  @override
  String get debuffReminderSectionTitle => '游戏内提醒';

  @override
  String get debuffReminderSettingTitle => '削甲提醒';

  @override
  String get debuffReminderSettingSubtitle => '两种方式均附带震动；检测到解谜／削弱提示时提醒';

  @override
  String get debuffReminderStyleDialog => '确认弹窗（默认）';

  @override
  String get debuffReminderStyleTopNotice => '顶部提醒';

  @override
  String get cameraAvoidanceTitle => '摄像头避让';

  @override
  String get cameraAvoidanceDesc => '调整摄像头一侧的界面留白，翻转屏幕时自动换边。';

  @override
  String get cameraAvoidanceDistance => '避让距离';

  @override
  String get operationProtectionTitle => '操作保护';

  @override
  String get confirmBeforeExitTitle => '防误退';

  @override
  String get confirmBeforeExitDescription => '使用返回键或返回手势离开应用前，需要确认。';

  @override
  String get confirmBeforeExitSaveFailed => '防误退设置保存失败，请重试。';

  @override
  String get appExitConfirmTitle => '返回桌面？';

  @override
  String get appExitConfirmDescription => '当前游戏将切换到后台。';

  @override
  String get appExitStay => '继续游戏';

  @override
  String get appExitToDesktop => '返回桌面';

  @override
  String get appExitFailed => '无法返回桌面，请重试。';

  @override
  String get enterGameFullscreen => '游戏全屏';

  @override
  String get exitGameFullscreen => '退出全屏';

  @override
  String get exitFullscreenShort => '退出';

  @override
  String get exitFullscreenConfirmTitle => '确定退出游戏全屏？';

  @override
  String get exitFullscreenConfirmDescription => '退出全屏后将恢复控制台与工具栏显示。';

  @override
  String get exitFullscreenSkipConfirmation => '下次不再提醒';

  @override
  String get exitFullscreenConfirmAction => '退出全屏';

  @override
  String get gameFullscreenHint => '点击浮钮或按返回键退出全屏；可拖动浮钮调整位置';

  @override
  String get gameFullscreenUnavailable => '无法显示退出按钮，已恢复普通布局';

  @override
  String get questCompletionNotice => '有任务已完成';

  @override
  String questCompletionCount(int count) {
    return '$count 个任务已完成，待领取';
  }

  @override
  String get resourceTrend90d => '90天';

  @override
  String get resourceTrendInventoryTitle => '库存趋势';

  @override
  String get resourceTrendCustomize => '显示资源';

  @override
  String get resourceTrendAtLeastOne => '至少保留一项资源';

  @override
  String get resourceTrendBuildMaterial => '高速建造材';

  @override
  String get resourceTrendRepairMaterial => '高速修复材';

  @override
  String get resourceTrendDevMaterial => '开发资材';

  @override
  String get resourceTrendImproveMaterial => '改修资材';

  @override
  String get resourceTrendLatest => '最新存量';

  @override
  String get resourceTrendChange => '区间增减';

  @override
  String resourceTrendBaseline(String time) {
    return '增减基准：$time JST';
  }

  @override
  String resourceTrendObserved(String time) {
    return '最后记录：$time JST';
  }

  @override
  String get resourceTrendPartial => '缺少期初记录，按首条记录计算增减';

  @override
  String get resourceTrendInsufficient => '可比较的记录不足';

  @override
  String get resourceTrendNoPeriodData => '此时段暂无资源记录';

  @override
  String get resourceTrendLoadError => '资源记录加载失败';

  @override
  String get resourceTrendSaveError => '资源显示设置未能保存';

  @override
  String get resourceTrendInspect => '滑动查看';

  @override
  String get resourceTrendExpand => '放大图表';

  @override
  String get resourceTrendSampled => '长时段图表已保留峰谷，读数对应实际采样记录';

  @override
  String get resourceTrendLocalScale => '纵轴随存量范围缩放';

  @override
  String get resourceTrendBaseShort => '基准';

  @override
  String get diagnosticLoggingSection => '客户端诊断日志';

  @override
  String get diagnosticLoggingTitle => '记录客户端诊断日志';

  @override
  String get diagnosticLoggingDesc => '仅记录性能和错误摘要，不包含账号、密码或登录凭据';

  @override
  String get telemetryAnonymousStatsTitle => '匿名设备与使用统计';

  @override
  String get telemetryAnonymousStatsDesc =>
      '发送包含设备信息和渲染模式的匿名统计数据，以帮助开发者持续优化和改进应用。不包含任何账号或隐私信息。';

  @override
  String get diagnosticPrivacyTitle => '隐私安全诊断';

  @override
  String get diagnosticPrivacyDesc =>
      '导出前会再次检查内容。日志不记录账号、密码、Cookie、令牌、请求正文、响应正文、聊天内容或截图，也不会自动上传。';

  @override
  String get diagnosticStatusEnabled => '正在记录';

  @override
  String get diagnosticStatusDisabled => '已停止记录';

  @override
  String diagnosticStorageUsage(String size) {
    return '本地日志占用：$size';
  }

  @override
  String get exportDiagnosticFile => '导出诊断文件';

  @override
  String get saveDiagnosticFile => '保存到本地';

  @override
  String get shareDiagnosticFile => '分享诊断文件';

  @override
  String get diagnosticSaveConfirmTitle => '保存诊断文件？';

  @override
  String get diagnosticSaveConfirmDesc =>
      '将生成一个经过隐私检查的 JSON 文件。接下来只需选择保存文件夹，文件名由客户端自动生成且不可修改。';

  @override
  String get diagnosticSaveAction => '选择文件夹';

  @override
  String diagnosticSaveSucceeded(String fileName) {
    return '已保存：$fileName';
  }

  @override
  String get diagnosticSaveFailed => '诊断文件保存失败';

  @override
  String get diagnosticShareConfirmTitle => '分享诊断文件？';

  @override
  String get diagnosticShareConfirmDesc =>
      '将生成一个经过隐私检查的 JSON 文件，并打开系统分享面板。请在发送前自行确认接收方。';

  @override
  String get diagnosticShareAction => '分享';

  @override
  String get diagnosticShareFailed => '诊断文件分享失败';

  @override
  String get clearDiagnosticData => '清除诊断日志';

  @override
  String get diagnosticExportConfirmTitle => '导出诊断文件？';

  @override
  String get diagnosticExportConfirmDesc =>
      '将生成一个 JSON 文件，并调用系统分享面板。文件只包含客户端性能、错误摘要及匿名设备运行信息，请在发送前自行确认接收方。';

  @override
  String get diagnosticExportAction => '导出';

  @override
  String get diagnosticClearConfirmTitle => '清除诊断日志？';

  @override
  String get diagnosticClearConfirmDesc => '将删除应用内的诊断日志和临时导出副本。已另存或分享的文件需自行删除。';

  @override
  String get diagnosticClearFailed => '清除诊断数据失败，请重试。';

  @override
  String get diagnosticExportFailed => '诊断文件导出失败';

  @override
  String get langKo => '한국어';

  @override
  String get langEn => 'English';

  @override
  String get dataVersionLabel => '数据版本';

  @override
  String get dataLastCheckedLabel => '上次检查';

  @override
  String get dataNotChecked => '尚未检查';

  @override
  String get sortieMapDataTitle => '海域资料';

  @override
  String get enemyDataTitle => '敌舰资料';

  @override
  String dataCatalogUpToDate(String version) {
    return '资料已是最新版本。\n版本：$version';
  }

  @override
  String dataCatalogUpdated(String before, String after) {
    return '资料更新成功。\n$before → $after';
  }

  @override
  String get dataCatalogIncompatible => '当前应用版本过低，请先更新应用。';

  @override
  String get dataCatalogValidationFailed => '更新资料校验失败，已继续使用当前资料。';

  @override
  String get dataCatalogStorageFailed => '无法保存更新资料。';

  @override
  String get dataCatalogNetworkFailed => '网络更新失败，请稍后重试。';

  @override
  String get questLocalProgress => '本地进度';

  @override
  String questServerProgress(String progress) {
    return '服务器进度：$progress';
  }

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
  String get themeColorTitle => '主题色';

  @override
  String get themeClassicDark => '原版暗色';

  @override
  String get themeSeaSaltTeal => '海盐青';

  @override
  String get themeClearSkyBlue => '晴空蓝';

  @override
  String get uiFontSizeTitle => '界面字号';

  @override
  String get uiFontSizeDescription => '默认跟随系统。';

  @override
  String get uiFontSizeSystem => '默认（跟随系统）';

  @override
  String get uiFontSizeSmall => '小';

  @override
  String get uiFontSizeMedium => '中';

  @override
  String get uiFontSizeLarge => '大';

  @override
  String get uiDisplaySizeTitle => '界面UI大小';

  @override
  String get uiDisplaySizeDesc => '调整顶栏、导航栏与信息栏的显示密度';

  @override
  String get uiDisplaySizeNormal => '普通';

  @override
  String get uiDisplaySizeCompact => '紧凑';

  @override
  String get uiDisplaySizeMinimal => '极简';

  @override
  String get panelResourcesExpand => '展开资源';

  @override
  String get panelResourcesCollapse => '折叠资源';

  @override
  String get panelResourcesCollapsedItems => '折叠时显示';

  @override
  String get panelResourcesCollapsedItemsReset => '恢复默认';

  @override
  String get minimalResourcePositionTitle => '资源位置';

  @override
  String get minimalResourcePositionDesc =>
      '极简档手机横屏游戏页的资源显示在信息栏顶部、游戏上方的细横栏，或屏幕底部的细横栏';

  @override
  String get minimalResourcePositionPanel => '信息栏';

  @override
  String get minimalResourcePositionTopBar => '顶部横栏';

  @override
  String get minimalResourcePositionBottomBar => '底部横栏';

  @override
  String get gameAreaRatio => '游戏区域占比';

  @override
  String get infoPanelWidth => '信息面板宽度（竖屏模式无效）';

  @override
  String get autoZoom => '应用推荐显示比例（游戏与菜单比例 67:33）';

  @override
  String get enhancedDamagePulse => '加强受损呼吸提示';

  @override
  String get enhancedDamagePulseDesc => '按小破、中破、大破增强颜色、速度和头像内部光效。关闭后使用普通效果。';

  @override
  String get informationPanelOnLeft => '功能区域置于左侧';

  @override
  String get informationPanelOnLeftDesc => '关闭时功能区域保持在右侧，竖屏时保持上下布局。';

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
  String get gameSafety => '大破提醒';

  @override
  String get battleSafetySectionTitle => '游戏安全';

  @override
  String get blockSortieTitle => '大破进击提醒';

  @override
  String get blockSortieDesc =>
      '出击或进击请求返回后，若出击舰队中有非旗舰大破舰船（已撤退舰船除外），会弹出需要确认的警告。此提醒不拦截出击或进击请求，也不会自动撤退。';

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
  String get clearWebCache => '清理浏览器网页缓存';

  @override
  String get clearWebCacheDesc => '清除 WebView 网页内核的临时页面与脚本数据。';

  @override
  String get baseSenkaResetTitle => '素战果归零';

  @override
  String get baseSenkaResetDesc => '将本月累计素战果设为 0.00，不影响 EO、任务和其他战果数据。';

  @override
  String get baseSenkaResetConfirmTitle => '素战果归零';

  @override
  String get baseSenkaResetConfirmDesc =>
      '确定将本月累计素战果归零吗？每日 EO 与任务奖励记录会保留，后续经验增量将从 0.00 继续累计。';

  @override
  String get baseSenkaResetSuccess => '本月累计素战果已归零';

  @override
  String get baseSenkaManualTitle => '手动填写素战果';

  @override
  String baseSenkaCurrentValue(String value) {
    return '本月累计：$value 战果';
  }

  @override
  String get baseSenkaManualDialogTitle => '填写本月累计素战果';

  @override
  String get baseSenkaManualInputLabel => '本月累计素战果';

  @override
  String get baseSenkaManualInvalid => '请输入非负数字，最多保留两位小数';

  @override
  String baseSenkaSetSuccess(String value) {
    return '本月累计素战果已设为 $value';
  }

  @override
  String get baseSenkaSaveFailed => '素战果保存失败，请重试';

  @override
  String get senkaTodaySorties => '今日出击';

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
  String get sortieCheckShipsMode => '舰娘';

  @override
  String get sortieCheckMapsMode => '海域';

  @override
  String get mapHpGauges => '海域血量';

  @override
  String get noMapGaugeData => '暂无海域血量数据';

  @override
  String get noMapGaugeDataHint => '请在游戏中进入出击海域以同步数据';

  @override
  String get showClearedMaps => '显示已攻略';

  @override
  String get allMapsCleared => '所有海域已攻略完成';

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
  String get clearWebCacheConfirmTitle => '清理浏览器网页缓存';

  @override
  String get clearWebCacheConfirmDesc =>
      '确定要清除浏览器网页缓存吗？这将会删除 WebView 网页内核缓存的临时数据，不影响已下载的游戏本地资源包。';

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
  String get officialWebsite => '官网';

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
  String get externalLinkOpenFailed => '无法打开链接，请检查是否已安装浏览器。';

  @override
  String get noUpdateLog => '暂无更新日志';

  @override
  String get battleWarningOff => '关闭';

  @override
  String get battleWarningConfirm => '开启提醒';

  @override
  String get advanceWarningDisplayModeTitle => '提醒方式';

  @override
  String get advanceWarningAlwaysConfirm => '始终确认';

  @override
  String get advanceWarningSmart => '智能提醒';

  @override
  String get advanceWarningSmartDescription => '大破舰损管均确认可用时顶部通知，否则弹窗。';

  @override
  String get advanceWarningAlwaysConfirmDescription => '检测到大破时弹窗确认。';

  @override
  String get advanceWarningTimingModeTitle => '提醒时机';

  @override
  String get advanceWarningTimingModeDescription => '修改从下次出击生效。';

  @override
  String get advanceWarningPostBattle => '结算后提醒';

  @override
  String get advanceWarningAfterAdvance => '进击后提醒';

  @override
  String get advanceWarningBothTimings => '两次都提醒';

  @override
  String get advanceWarningAfterAdvanceDescription => '进击成功后检查大破。';

  @override
  String get advanceWarningPostBattleDescription => '战斗结算后检查大破。';

  @override
  String get advanceWarningBothTimingsDescription => '结算后和进击成功后均检查大破。';

  @override
  String get advanceWarningTimingRequired => '至少保留一项提醒时机。';

  @override
  String get advanceWarningPostBattleOnlyWarning => '进击成功后将不再检查大破状态。';

  @override
  String get postBattleDamageControlEquippedBody => '战斗结算后存在大破舰娘，请确认舰船及剩余损管。';

  @override
  String get postBattleDamageControlDangerBody =>
      '战斗结算后存在大破舰娘！请停止进击并核对游戏内状态，避免进入下一场战斗。';

  @override
  String get advanceWarningDamageControlActive => '大破舰已携带损管';

  @override
  String get advanceWarningReloadGame => '刷新游戏';

  @override
  String get advanceWarningReloadFrame => '框架刷新';

  @override
  String get advanceWarningRefreshFailed => '刷新未完成，请核对游戏状态与装备。';

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
  String get webCacheCleared => '已清理浏览器网页缓存';

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
  String get avgCondition => '最低士气';

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
  String get noBonusStats => '暂无装备属性';

  @override
  String get condition => '士气';

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
  String get gadgetBypass => '游戏资源镜像与IP限制绕行';

  @override
  String get gadgetBypassDesc => '开启后通过镜像加载游戏客户端静态资源。DMM 地区限制兼容处理自动生效，不受此开关影响。';

  @override
  String get gadgetBypassEnable => '开启镜像绕行';

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
  String get averageCondition => '最低士气';

  @override
  String get moraleRecoveryCountdown => '恢复倒计时';

  @override
  String get moraleRecovered => '已恢复';

  @override
  String get toggleMoraleMetric => '点击切换最低士气与恢复倒计时';

  @override
  String get losDetails => '索敌详情';

  @override
  String get airPowerDetails => '制空详情';

  @override
  String get minimumValue => '最小';

  @override
  String get maximumValue => '最大';

  @override
  String get withoutBonus => '不含熟练度加成';

  @override
  String get showAirPowerDetails => '点击查看制空详情';

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
  String get noAdditionalStats => '暂无装备属性';

  @override
  String get fatigue => '士气';

  @override
  String get startupUpdateTitle => '发现新版本';

  @override
  String get backgroundAudio => '后台播放声音';

  @override
  String get backgroundAudioDesc => '开启后，应用进入后台时游戏声音仍会继续播放。';

  @override
  String get backgroundGameRetention => '后台保持游戏';

  @override
  String get backgroundGameRetentionDesc =>
      '游戏运行期间显示常驻通知，降低切换应用后会话被系统回收的概率，可能增加耗电。';

  @override
  String get backgroundGameRetentionNotificationTitle => '矢矧正在后台运行';

  @override
  String get backgroundGameRetentionNotificationBody => '游戏会话保持中 · 点击返回游戏';

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
  String get enemyFleet => '敌舰队';

  @override
  String airStateLabel(String label) {
    return '制空：$label';
  }

  @override
  String get postBattleWarningTitle => '大破安全警告';

  @override
  String get advanceWarningMissingHeadline => '存在未携带损管的大破舰娘！';

  @override
  String get advanceWarningUnknownHeadline => '大破舰娘损管状态未知！';

  @override
  String get advanceWarningEquippedHeadline => '大破舰娘已携带损管，请确认剩余装备。';

  @override
  String get advanceWarningEquippedBody => '已在大破状态下选择进击，请确认舰船及剩余损管。';

  @override
  String get advanceWarningMissing => '未携带损管';

  @override
  String get advanceWarningUnknown => '损管状态未知，请核对游戏内装备';

  @override
  String advanceWarningEquipped(String items) {
    return '携带：$items';
  }

  @override
  String get advanceWarningPersonnel => '应急修理要员';

  @override
  String get advanceWarningGoddess => '应急修理女神';

  @override
  String advanceWarningShipPosition(int fleet, int position) {
    return '第$fleet舰队·$position号舰';
  }

  @override
  String get advanceWarningMuteSortie => '此次出击不再提醒';

  @override
  String get postBattleWarningHeadline => '出击舰队中存在大破舰娘！';

  @override
  String get postBattleWarningBody => '已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。';

  @override
  String get acknowledgeAndRetreat => '确认了解';

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
  String get questAwaitingConfirmation => '已达成（待确认）';

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
  String get noCookieReadDesc => 'JS 桥接捕获接口路径、脱敏请求参数与响应等游戏数据，不读取 Cookie。';

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
    return '士气 $value';
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
  String get gameFrameRateTitle => '游戏帧率';

  @override
  String get gameFrameRateAutomatic => '自动';

  @override
  String get gameFrameRateStable60 => '60 帧';

  @override
  String get gameFrameRateStable60Desc => '始终以 60 FPS 运行，不自动降档。';

  @override
  String get gameFrameRateStable30 => '30 帧';

  @override
  String get gameFrameRateStable30Desc => '始终以 30 FPS 运行，降低耗电和发热。';

  @override
  String get gameFrameRateHighRefresh => '高刷';

  @override
  String get gameFrameRateHighRefreshDesc =>
      '解除 60 FPS 限制，跟随屏幕刷新率运行，耗电和发热可能增加。';

  @override
  String get gameFrameRateHighRefreshDialogTitle => '开启高刷模式？';

  @override
  String get gameFrameRateHighRefreshDialogBody =>
      '高刷会修改游戏运行帧率，可能增加耗电、发热或引发动画异常，并存在未知的账号风险。请自行承担后果。';

  @override
  String get gameFrameRateHighRefreshDialogConfirm => '了解风险并开启';

  @override
  String get gameFrameRateAutomaticDesc =>
      '封顶 60 FPS；若持续不稳定、系统开启节能或设备发热，将自动降至 30 FPS。';

  @override
  String get gameFrameRateUnsupported =>
      '当前 Android WebView 不支持帧率调整，将保持游戏原始帧率。';

  @override
  String get gameRenderingModeTitle => '游戏渲染模式';

  @override
  String get gameRenderingModeStandard => '轻量模式';

  @override
  String get gameRenderingModeStandardDesc =>
      'Flutter PlatformView + Texture Layer + WebGL，减少部分合成开销，部分设备可能存在显示或触控兼容问题。';

  @override
  String get gameRenderingModeCompatibility => '均衡模式';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Flutter PlatformView + Hybrid Composition + WebGL，兼顾游戏性能与设备兼容性。';

  @override
  String get gameRenderingModeCanvas => '兼容模式';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Flutter PlatformView + Hybrid Composition + Canvas，绕过 WebGL，优先解决部分 GPU / WebGL 兼容问题，画面性能可能降低。';

  @override
  String get gameRenderingModeNativeActivity => '原生独立渲染（推荐）';

  @override
  String get gameRenderingModeNativeActivityDesc =>
      'Activity Direct WebView + WebGL，理论上具有更低的合成开销与更好的原生兼容性。';

  @override
  String get gameRenderingModeConfirmTitle => '切换游戏渲染模式？';

  @override
  String get gameRenderingModeConfirmMessage =>
      '切换渲染模式会自动重启应用，游戏页面将重新载入。请先结束正在进行的操作。';

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
  String get nativeGameSurfaceSwitchRenderingModeHint =>
      '当前设备暂不兼容此模式。请滚动左侧菜单，前往【设置 - 游戏运行】切换渲染模式。';

  @override
  String nativeGameSurfacePageInitializationFailed(
    String stage,
    String errorType,
  ) {
    return '游戏页面初始化失败 [$stage]：$errorType';
  }

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
  String get sortAscending => '升序';

  @override
  String get sortDescending => '降序';

  @override
  String sortPriority(int priority) {
    return '第$priority优先级';
  }

  @override
  String get sortLockedState => '已锁定';

  @override
  String get sortTemporaryState => '临时排序';

  @override
  String get sortHeaderHint => '点击切换排序；长按或按 Shift+Enter 锁定';

  @override
  String get sortHeaderLockedHint => '点击切换排序方向；长按或按 Shift+Enter 解除锁定';

  @override
  String get sortLockAction => '锁定为下一优先级';

  @override
  String get sortUnlockAction => '解除当前排序锁定';

  @override
  String get settingsTabScreen => '外观与布局';

  @override
  String get settingsTabSound => '声音';

  @override
  String get settingsTabBattle => '出击与战斗';

  @override
  String get settingsTabNotification => '通知与提醒';

  @override
  String get settingsTabNetwork => '网络与连接';

  @override
  String get settingsTabData => '数据管理';

  @override
  String get settingsTabAboutSupport => '关于与支持';

  @override
  String get notificationSectionSystem => '系统通知状态';

  @override
  String get notificationSectionSystemDesc =>
      '授权通知与精确提醒权限，可确保在锁屏或后台时远征、入渠等提醒准时弹出，避免被系统省电策略延迟。点击对应项可直接前往系统设置开启。';

  @override
  String get notificationPermissionGranted => '通知权限已授予';

  @override
  String get notificationPermissionDenied => '通知权限未授予';

  @override
  String get notificationExactAlarmGranted => '精确提醒已授权';

  @override
  String get notificationExactAlarmDenied => '精确提醒未授权，将使用省电兼容模式';

  @override
  String get notificationChannelsEnabled => '通知渠道可用';

  @override
  String get notificationChannelsDisabled => '通知渠道已被系统关闭';

  @override
  String get notificationSectionGeneral => '全局通知服务';

  @override
  String get notificationEnableMaster => '启用通知服务';

  @override
  String get notificationSound => '通知提示音';

  @override
  String get notificationVibration => '振动提醒';

  @override
  String get notificationSectionOngoing => '后台常驻进行中进度';

  @override
  String get notificationOngoingLive => '常驻实时进度条卡片';

  @override
  String get notificationProgress => '进度条';

  @override
  String get notificationPercent => '百分比';

  @override
  String get notificationCountdown => '实时倒计时';

  @override
  String get notificationSectionTypes => '通知类型与时机';

  @override
  String get notificationExpedition => '远征';

  @override
  String get notificationRepair => '入渠';

  @override
  String get notificationAnchorage => '泊地';

  @override
  String get notificationConstruction => '建造';

  @override
  String get notificationMorale => '疲劳 / 刷闪';

  @override
  String get notificationPunctual => '准点';

  @override
  String get notificationPreempt30s => '提前 30 秒';

  @override
  String get notificationPreempt60s => '提前 60 秒';

  @override
  String get notificationPreempt120s => '提前 2 分钟';

  @override
  String get notificationRepairPunctual => '准点';

  @override
  String get notificationAnchorage20m => '满 20 分钟首轮';

  @override
  String get notificationAnchorageFull => '全部修满';

  @override
  String get notificationAnchorageBoth => '双阶段均提醒';

  @override
  String get frameRateSettingsSection => '帧率设置';

  @override
  String get battleAlertsSection => '战斗提醒';

  @override
  String get battleDamageVibration => '战斗受损震动提醒';

  @override
  String get battleDamageVibrationDesc => '我方舰娘在战斗中刚进入中破或大破时震动提醒。';

  @override
  String get battleStatusEffectsSection => '战斗状态效果';

  @override
  String get battleStatusEffectsEnabled => '启用状态效果';

  @override
  String get battleStatusEffectsEnabledDesc => '统一开启或关闭受损闪烁、受损震动与士气闪光。';

  @override
  String get battleEffectDisplayScope => '画面显示范围';

  @override
  String get battleEffectDisplayScopeDesc => '决定受损闪烁与士气闪光出现在哪些舰娘画面。';

  @override
  String get battleEffectScopePredictionOnly => '仅未卜先知';

  @override
  String get battleEffectScopeFleetOnly => '仅编队';

  @override
  String get battleEffectScopeAll => '全部';

  @override
  String get battleDamagePulse => '受损闪烁';

  @override
  String get battleDamagePulseDesc => '按当前 HP 损伤等级控制头像边框的动态闪烁。';

  @override
  String get battleDamageVibrationEffect => '受损震动';

  @override
  String get battleDamageVibrationEffectDesc => '我方舰娘在战斗中刚进入所选损伤状态时震动。';

  @override
  String get battleMoraleSparkle => '士气闪光效果';

  @override
  String get battleMoraleSparkleDesc =>
      'Cond ≥ 50 时在舰娘头像周围显示闪烁或常亮星光；不影响疲劳脸和疲劳警告。';

  @override
  String get battleMoraleSparkleBlinking => '闪烁';

  @override
  String get battleMoraleSparkleSteady => '常亮';

  @override
  String get battleEffectOff => '关闭';

  @override
  String get battleEffectMinorOnly => '仅小破';

  @override
  String get battleEffectModerateOnly => '仅中破';

  @override
  String get battleEffectHeavyOnly => '仅大破';

  @override
  String get battleEffectAll => '全部开启';

  @override
  String get battlePredictionSection => '未卜先知';

  @override
  String get battleEnemyPreviewPortraits => '战前敌方立绘';

  @override
  String get battleEnemyPreviewPortraitsDesc => '在未卜先知中显示战前敌方立绘。';

  @override
  String get battleLastFormationHint => '显示上次选择的阵形';

  @override
  String get battleLastFormationHintDesc => '到达出击节点时，在未卜先知中提示该点上次使用的阵形。';

  @override
  String get battleEnemyPreviewPosition => '战前敌舰预测位置';

  @override
  String get battleEnemyPreviewPositionDesc => '选择战前敌舰预测显示在我方血条的上方或下方。';

  @override
  String get battleEnemyPreviewPositionAbove => '上方';

  @override
  String get battleEnemyPreviewPositionBelow => '下方';

  @override
  String get battleSectionOrder => '信息区顺序';

  @override
  String get battleSectionOrderDescription => '调整信息区显示顺序';

  @override
  String get battleSectionOrderAdjust => '调整';

  @override
  String get battleSectionOrderHint => '点击上下箭头调整，自动保存';

  @override
  String get battleSectionSortieMap => '海域小地图';

  @override
  String get battleSectionEnemyPreview => '敌方预测';

  @override
  String get battleSectionPredictionResult => '预测结果';

  @override
  String get battleSectionOrderRestoreDefault => '恢复默认';

  @override
  String get battleSectionOrderSaveFailed => '保存失败，请重试。';

  @override
  String battleSectionOrderMoveUp(String section) {
    return '上移$section';
  }

  @override
  String battleSectionOrderMoveDown(String section) {
    return '下移$section';
  }

  @override
  String battleLastFormation(String formation) {
    return '上次：$formation';
  }

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
  String get inventoryOwned => '持有';

  @override
  String get inventoryUnowned => '未持有';

  @override
  String unownedShipSummary(int count, int excluded) {
    return '显示 $count 艘 · 已排除 $excluded 艘';
  }

  @override
  String get unownedShipExcludedLabel => '已排除';

  @override
  String get unownedShipReminderHint => '获得未勾选的舰娘时，将正常提醒并震动；勾选的舰娘则不会提醒。';

  @override
  String get clearNewShipExclusions => '清除排除';

  @override
  String get resetFilter => '重置筛选';

  @override
  String unownedEquipmentSummary(int count) {
    return '显示 $count 件未持有装备';
  }

  @override
  String get otherType => '其他';

  @override
  String newShipFallbackName(int id) {
    return '舰娘 No.$id';
  }

  @override
  String get newShipAlertTitle => '发现未持有舰娘';

  @override
  String newShipAlertBody(String names) {
    return '$names，请不要忘记上锁';
  }

  @override
  String get acknowledge => '知道了';

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
  String get equipmentOfficialId => '官方ID';

  @override
  String get equipmentInstanceId => '实例ID';

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
  String get chineseTranslation => '中文翻译';

  @override
  String get searchQuest => '搜索任务';

  @override
  String get filterQuest => '筛选任务';

  @override
  String get searchQuestHint => '搜索编号、任务名、说明或奖励；空格分隔任一关键词';

  @override
  String get questAvailable => '未接取';

  @override
  String get questAcceptedOnly => '仅已接取（含待领取）';

  @override
  String get questClaimable => '待领取';

  @override
  String get questInferredCompleted => '推算完成';

  @override
  String get questStateUnknown => '状态未知';

  @override
  String get questFilterHelp => '已解锁包含未接取、进行中和待领取；未解锁包含状态未知；已完成包含待领取和推算完成。';

  @override
  String get questNoResults => '没有符合条件的任务';

  @override
  String get questNoResultsHint => '试试调整搜索内容或清除筛选条件。';

  @override
  String questResultsCount(int count) {
    return '共 $count 个任务';
  }

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

  @override
  String get gameResourceCacheTitle => '游戏资源本地缓存';

  @override
  String get gameResourceCacheDesc => '资源从舰队 Collection 官方服务器获取；缓存可随时清除。';

  @override
  String get gameResourceCacheNone => '临时缓存';

  @override
  String get gameResourceCacheNoneDesc =>
      '不预下载资源；游玩时按需缓存，缓存最多保留 7 天且占用不超过 2 GB，过期或超出上限时将自动清理。';

  @override
  String get gameResourceCacheLight => '轻度缓存';

  @override
  String get gameResourceCacheLightDesc => '缓存启动文件、常用 UI、已持有舰娘立绘和装备资源。';

  @override
  String get gameResourceCacheFull => '本地缓存';

  @override
  String get gameResourceCacheFullDesc =>
      '预下载基础资源（约 5.72 GB），无需等下载完成，可边下边玩，不影响游戏。新内容会在游玩时自动缓存。';

  @override
  String get gameResourceCacheStart => '开始下载';

  @override
  String get gameResourceCachePause => '暂停下载';

  @override
  String get gameResourceCacheResume => '继续下载';

  @override
  String get gameResourceCacheCheck => '检查完整性';

  @override
  String get gameResourceCacheRepair => '补齐或修复';

  @override
  String get gameResourceCacheClear => '清除本地缓存';

  @override
  String get gameResourceCacheIntegrityComplete => '当前缓存完整';

  @override
  String get gameResourceCacheMissing => '缺失';

  @override
  String get gameResourceCacheDamaged => '损坏';

  @override
  String get gameResourceCacheOutdated => '待校验';

  @override
  String get gameResourceCacheItems => '项';

  @override
  String gameResourceCacheStoredSize(String size) {
    return '已缓存 $size';
  }

  @override
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  ) {
    return '缺失 $missing 项 · 损坏 $damaged 项 · 待校验 $pending 项';
  }

  @override
  String get gameResourceCachePendingRetained => '待校验资源仍保留在本地，不会自动删除。';

  @override
  String get gameResourceCacheDownloadConfirmTitle => '确认下载缓存？';

  @override
  String get gameResourceCacheDownloadConfirmDesc =>
      '将从官方服务器批量下载所选模式的资源，可随时暂停并继续。';

  @override
  String get gameResourceCacheMobileConfirmDesc =>
      '当前正在使用移动网络。继续将消耗移动数据流量，是否允许本次下载？';

  @override
  String get gameResourceCacheWaitingForWifi => '正在等待 Wi-Fi，连接后会自动继续下载。';

  @override
  String get gameResourceCacheClearConfirmTitle => '清除游戏资源缓存？';

  @override
  String get gameResourceCacheClearConfirmDesc => '将删除已下载的游戏资源；模式设置会保留。';

  @override
  String get gameResourceCacheCapacityBlocked =>
      '可用存储空间不足，或本地游戏资源缓存已达到 50 GB 上限。';

  @override
  String get gameResourceCacheActionFailed => '缓存操作未完成，请稍后重试。';

  @override
  String get gameResourceCacheUnsupported =>
      '当前 Android WebView 不支持游戏资源本地缓存，请更新 WebView。';

  @override
  String get gameResourceCacheUnavailable =>
      '本地缓存初始化或清理失败，请检查存储空间并重启应用。游戏浏览不受影响。';

  @override
  String get gameResourceCacheManifestFailed => '预载资源清单加载失败，进入游戏后可重试。';

  @override
  String get confirmGameRefreshTitle => '确认刷新游戏？';

  @override
  String get gameRefreshDialogDescription =>
      '确定要刷新游戏吗？\n\n“刷新游戏页面”与浏览器刷新效果相同。\n“重新载入游戏”只重新载入游戏框架部分，通常更快，但可能导致猫袭或网络异常。请自行承担风险。';

  @override
  String get refreshGamePage => '刷新游戏页面';

  @override
  String get reloadGame => '重新载入游戏';

  @override
  String get frameRefreshShortcutLabel => '框架刷新';

  @override
  String get frameRefreshShortcutConfirmTitle => '确定刷新游戏框架？';

  @override
  String get frameRefreshShortcutConfirmDescription =>
      '重新载入游戏框架通常更快，但可能导致猫袭或网络异常。请自行承担风险。';

  @override
  String get frameRefreshShortcutSkipConfirmation => '下次不再提醒';

  @override
  String get frameRefreshShortcutConfirmAction => '确认刷新';

  @override
  String get gameFrameNotFound => '尚未找到游戏框架，请进入游戏后重试。';

  @override
  String get gameHtmlWrapNotFound => '尚未找到游戏本体，请等待页面载入后重试。';

  @override
  String get gameFrameReloadBlocked => '游戏框架未能重新载入，请稍后重试。';

  @override
  String get gameFrameReloadUnsupported =>
      '当前设备的 Android WebView 太旧，不支持对子框架注入。';

  @override
  String get logbookResourceDrop => '资源掉落';

  @override
  String get logbookItemDrop => '道具掉落';

  @override
  String get logbookResourceNode => '资源节点';

  @override
  String get logbookFriendFormation => '我方阵形';

  @override
  String get logbookEnemyFormation => '敌方阵形';

  @override
  String get logbookAirSuperiority => '制空状态';

  @override
  String get airSuperiorityParity => '均衡';

  @override
  String get airSuperioritySecured => '确保';

  @override
  String get airSuperiorityAdvantage => '优势';

  @override
  String get airSuperiorityDisadvantage => '劣势';

  @override
  String get airSuperiorityLost => '丧失';

  @override
  String get logbookHeavyDamageShips => '大破舰娘';

  @override
  String get gameConnectorTitle => '游戏连接';

  @override
  String get gameConnectorYahagi => 'Yahagi 连接';

  @override
  String get gameConnectorYahagiDesc => '使用当前 DMM 官方登录入口。';

  @override
  String get gameConnectorOoi => 'OOI 连接（实验性）';

  @override
  String get gameConnectorOoiDesc => '原样打开 ooi.moe 登录页，由你选择模式 1、3 或 4。';

  @override
  String get gameConnectorConfirmTitle => '切换游戏连接？';

  @override
  String get gameConnectorOoiRisk =>
      '账号凭据将提交给第三方站点 ooi.moe；Yahagi 不读取、不保存、不自动填写账号或密码。';

  @override
  String get gameConnectorActiveWarning => '切换会中断当前游戏页面并返回目标登录入口。';

  @override
  String get gameConnectorApplied => '游戏连接已切换。';

  @override
  String get gameConnectorSaveFailed => '连接选择保存失败，当前连接未改变。';

  @override
  String get gameConnectorNavigationFailed => '连接已保存，但登录页面打开失败，请重试。';

  @override
  String get kcwikiReportSection => 'KCWiki 数据贡献';

  @override
  String get kcwikiReportTitle => '帮助 KCWiki 收集数据';

  @override
  String get kcwikiReportDisabledDesc => '默认关闭。关闭时不收集、不组包、不联网，也不影响游戏和本地功能。';

  @override
  String get kcwikiReportEnabledDesc => '已开启；仅发送带路、任务前置、战斗、友军、陆航/空袭和改修数据。';

  @override
  String get kcwikiReportConfirmTitle => '开启 KCWiki 数据贡献？';

  @override
  String get kcwikiReportConfirmDesc =>
      '开启后，应用会通过已配置的 HTTPS 地址发送带路、任务前置、战斗、友军、陆航/空袭和改修记录。不发送登录令牌、Cookie 或请求头；上传失败不会阻塞游戏功能。';

  @override
  String get kcwikiReportUnavailable => '当前版本未配置安全的 HTTPS 上报地址，无法开启数据贡献。';

  @override
  String get kcwikiReportEnable => '自愿开启';

  @override
  String get kcwikiReportSaveFailed => 'KCWiki 数据贡献设置保存失败，请重试。';

  @override
  String kcwikiReportCaptureFailed(String error) {
    return 'KCWiki 数据收集切换失败：$error';
  }

  @override
  String get kcwikiReportWaiting => '已开启，正在等待可贡献的数据。';

  @override
  String kcwikiReportProcessing(String module, String time) {
    return '正在上传：$module · $time';
  }

  @override
  String kcwikiReportParseRecovered(String time) {
    return '大型数据解析超时已恢复，后续数据已继续处理 · $time';
  }

  @override
  String kcwikiReportFailureHttp(String status) {
    return 'HTTP $status';
  }

  @override
  String get kcwikiReportFailureTimeout => '连接超时';

  @override
  String get kcwikiReportFailureNetwork => '网络失败';

  @override
  String get kcwikiReportFailureBodyTooLarge => '数据超过单次上限';

  @override
  String get kcwikiReportFailureQueueFull => '本地等待队列已满';

  @override
  String get kcwikiReportFailureLocal => '本地处理失败';

  @override
  String kcwikiReportCounters(int succeeded, int failed, int dropped) {
    return '成功 $succeeded · 失败 $failed · 丢弃 $dropped';
  }

  @override
  String kcwikiReportLastSuccess(
    String module,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '最近上传成功：$module · $time · 成功 $succeeded · 失败 $failed · 丢弃 $dropped';
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
    return '最近上传失败：$module（$status）· $time · 成功 $succeeded · 失败 $failed · 丢弃 $dropped';
  }

  @override
  String get landBaseBrief => '陆基简报';

  @override
  String get landBaseNoData => '无数据';

  @override
  String landBaseAreaFallback(int areaId) {
    return '海域 $areaId';
  }

  @override
  String landBaseUnitCount(int count) {
    return '$count 支航空队';
  }

  @override
  String get landBaseRange => '航程';

  @override
  String get landBaseActionSortie => '出击';

  @override
  String get landBaseActionAirDefense => '防空';

  @override
  String get landBaseActionRest => '休息';

  @override
  String get landBaseActionRetreat => '退避';

  @override
  String get landBaseMissingPlanes => '缺机';

  @override
  String get landBaseRelocating => '配置转换中';

  @override
  String get senkaInfoTab => '战果信息';

  @override
  String get senkaCalendarTab => '战果日历';

  @override
  String get senkaCalculatorTab => '战果计算';

  @override
  String get senkaSaveFailedWarning => '战果数据保存失败，重启后可能丢失';

  @override
  String get senkaLatestRanking => '最新排名战果';

  @override
  String get senkaTarget => '目标战果';

  @override
  String senkaGap(String value) {
    return '距离目标还差 $value 战果';
  }

  @override
  String senkaOver(String value) {
    return '已超出 $value 战果';
  }

  @override
  String get senkaPlannedEo => '计划 EO';

  @override
  String get senkaPlannedQuest => '计划任务';

  @override
  String get senkaDailyRequired => '每日所需';

  @override
  String get senkaTodayRemaining => '今日剩余';

  @override
  String get senkaUnsettledDelta => '结算后增量';

  @override
  String get senkaAvailableDaysIncludingToday => '可用天数（含今日）';

  @override
  String get senkaProjected => '预计战果';

  @override
  String get senkaUnit => '战果';

  @override
  String senkaInputTitle(String label) {
    return '填写$label';
  }

  @override
  String get senkaInvalidNumber => '请输入有效数字';

  @override
  String get senkaPlannedEoReward => '计划 EO 战果奖励';

  @override
  String get senkaPlannedQuestReward => '计划任务战果奖励';

  @override
  String get senkaTotal => '合计';

  @override
  String get senkaEoRewards => 'EO 战果奖励';

  @override
  String get senkaQuarterlyQuests => '季度战果任务';

  @override
  String get senkaAnnualQuests => '年度战果任务';

  @override
  String get senkaOneTimeQuests => '单次战果任务';

  @override
  String get senkaRewardLegend =>
      '黄色＋✕：计划放置，不计入预计战果，绿色＋✓：计划完成，计入预计战果，灰色＋○：已经完成，不再重复计算。';

  @override
  String get senkaRewardDeferred => '计划放置';

  @override
  String get senkaRewardPlanned => '计划完成（计预计）';

  @override
  String get senkaRewardCompleted => '已完成';

  @override
  String senkaCalendarTitle(int year, int month) {
    return '$year年$month月战果日历';
  }

  @override
  String senkaCalendarSummary(String recorded, String base) {
    return '本月已记录 $recorded · 本月素战果 $base';
  }

  @override
  String get senkaExperience => '经验';

  @override
  String get senkaQuest => '任务';

  @override
  String senkaCalendarCell(int year, int month, int day, String value) {
    return '$year年$month月$day日，战果$value';
  }

  @override
  String get senkaServer => '所在服务器';

  @override
  String get senkaRanking => '战果排名';

  @override
  String get senkaRank => '排名';

  @override
  String senkaUpdated(String time) {
    return '更新：$time';
  }

  @override
  String get senkaOrder => '顺位';

  @override
  String get senkaChange => '变化';

  @override
  String get senkaCurrent => '当前';

  @override
  String get senkaSortieStats => '出击海域统计';

  @override
  String get senkaLatestRecord => '最近记录';

  @override
  String get senkaMonthSorties => '本月出击';

  @override
  String get senkaBossArrivals => 'Boss 到达';

  @override
  String get senkaSWins => 'S 胜';

  @override
  String get senkaMonth => '本月';

  @override
  String get senkaToday => '今日';

  @override
  String get senkaShowHiddenAreas => '显示隐藏海域';

  @override
  String get senkaShowHidden => '显示已隐藏';

  @override
  String get senkaArea => '海域';

  @override
  String get senkaBoss => 'Boss';

  @override
  String get senkaSorties => '出击';

  @override
  String get senkaResult => 'S / A';

  @override
  String get senkaActions => '操作';

  @override
  String senkaFavoriteArea(String map) {
    return '收藏海域 $map';
  }

  @override
  String senkaHideArea(String map) {
    return '隐藏海域 $map';
  }

  @override
  String get senkaUnknownServer => '未知服务器';

  @override
  String get toolbox => '工具箱';

  @override
  String get fleetExport => '导出数据';

  @override
  String get otherTools => '其他';

  @override
  String get noro6 => 'noro6';

  @override
  String get jervis => 'Jervis';

  @override
  String get exportToNoro6 => '导出至 noro6';

  @override
  String get exportToNoro6Mirror => '导出至 noro6（国内镜像）';

  @override
  String get exportToJervis => '导出至 Jervis';

  @override
  String get eventLandBasesOnly => '仅导出活动海域陆航';

  @override
  String get landBaseExportLimitHint =>
      'DeckBuilder 每次最多支持 3 队；关闭筛选时按已捕获顺序导出前 3 队。';

  @override
  String get fleetExportText => '舰队导出文本';

  @override
  String get deckBuilderV4 => 'DeckBuilder v4';

  @override
  String get refreshExportText => '刷新';

  @override
  String get copyExportText => '复制文本';

  @override
  String get openInSystemBrowser => '使用系统默认浏览器打开';

  @override
  String get otherToolsComingSoon => '其他功能正在开发中';

  @override
  String get otherToolsHint => '后续辅助工具会集中放在这里。';

  @override
  String get waitingForPortData => '等待母港数据';

  @override
  String get externalFleetToolOpenFailed => '无法打开外部舰队工具，请检查是否已安装浏览器。';

  @override
  String get fleetExportCopied => '舰队导出文本已复制。';

  @override
  String get fleetExportCopyFailed => '复制失败，请稍后重试。';

  @override
  String equipmentCompatibilitySummary(int owned, int all) {
    return '可装备：持有 $owned／全部 $all';
  }

  @override
  String equipmentCompatibilityOwnedTab(int count) {
    return '持有舰娘 $count';
  }

  @override
  String equipmentCompatibilityAllTab(int count) {
    return '全部舰娘 $count';
  }

  @override
  String equipmentCompatibilityOwnedCompact(int count) {
    return '持有 $count';
  }

  @override
  String equipmentCompatibilityAllCompact(int count) {
    return '全部 $count';
  }

  @override
  String get equipmentCompatibilitySelectShipType => '选择舰种';

  @override
  String get equipmentCompatibilitySearchHint => '搜索舰娘';

  @override
  String get equipmentCompatibilityAllSlots => '全部槽位';

  @override
  String get equipmentCompatibilityRegularSlot => '普通槽';

  @override
  String get equipmentCompatibilityExpansionSlot => '增设栏';

  @override
  String get equipmentCompatibilityBothSlots => '普通槽＋增设栏';

  @override
  String equipmentCompatibilityExpansionRequirement(int level) {
    return '增设栏需 ★+$level';
  }

  @override
  String equipmentCompatibilityOwnedLevels(String levels) {
    return 'Lv.$levels';
  }

  @override
  String equipmentCompatibilityFleetNumbers(String numbers) {
    return '第 $numbers 舰队';
  }

  @override
  String get equipmentCompatibilityEmpty => '没有符合条件的舰娘';

  @override
  String equipmentCompatibilityOfficialId(int id) {
    return '装备 ID $id';
  }

  @override
  String equipmentCompatibilityOwnedCount(int count) {
    return '持有数 $count';
  }

  @override
  String equipmentCompatibilityRegularCount(int count) {
    return '普通槽 $count';
  }

  @override
  String equipmentCompatibilityExpansionCount(int count) {
    return '增设栏 $count';
  }

  @override
  String get equipmentCompatibilitySource => '规则来源：游戏官方主数据';

  @override
  String get equipmentCompatibilityRulesWaiting => '装备规则数据等待更新';

  @override
  String get equipmentCompatibilityEmptyOwned => '当前没有持有可装备的舰娘';

  @override
  String get equipmentCompatibilityEmptyAll => '没有找到可装备的舰娘形态';

  @override
  String equipmentCompatibilityCategory(String category) {
    return '分类：$category';
  }

  @override
  String equipmentCompatibilityShipClassId(int id) {
    return '舰级 #$id';
  }

  @override
  String get shipEquipmentCompatibilitySelectCategory => '选择装备分类';

  @override
  String get shipEquipmentCompatibilitySearchTitle => '搜索装备';

  @override
  String get shipEquipmentCompatibilitySearchHint => '输入装备名称';

  @override
  String shipEquipmentCompatibilityOwnedCount(int count) {
    return '持有 X$count';
  }

  @override
  String get shipEquipmentCompatibilityEmpty => '没有找到可装备的装备';

  @override
  String get equipmentDevelopment => '装备开发';

  @override
  String get development => '开发';

  @override
  String get developmentCommandTitle => '开发指挥台';

  @override
  String get developmentWorkbenchTitle => '开发工作台';

  @override
  String get developmentCalculator => '开发计算器';

  @override
  String get developmentFormula => '开发公式';

  @override
  String get developmentOutputProbability => '出货概率';

  @override
  String get developmentFinalProbability => '最终概率';

  @override
  String get developmentAvailableRecipes => '可用公式';

  @override
  String get developmentPoolType => '池类型';

  @override
  String get developmentSelectSecretary => '选择秘书舰类型';

  @override
  String get developmentOtherSecretaryGroup => '其他';

  @override
  String get developmentEquipmentType => '类型';

  @override
  String get developmentSecretary => '秘书舰';

  @override
  String get developmentFuelShort => '油';

  @override
  String get developmentAmmoShort => '弹';

  @override
  String get developmentSteelShort => '钢';

  @override
  String get developmentBauxiteShort => '铝';

  @override
  String get developmentOutputRate => '出货率';

  @override
  String get developmentEquipment => '装备';

  @override
  String get developmentCurrentFlagship => '当前旗舰';

  @override
  String get developmentUseFlagship => '使用当前旗舰';

  @override
  String get developmentFlagshipUnsupported => '当前旗舰没有可用的开发池，已保留原选择';

  @override
  String get developmentSelectPool => '秘书舰类型';

  @override
  String get developmentCurrentRecipe => '当前配方';

  @override
  String get developmentTargetEquipment => '目标装备';

  @override
  String get developmentChooseTarget => '选择目标装备';

  @override
  String get developmentSearchEquipment => '搜索装备';

  @override
  String get developmentSearchHint => '输入装备名称或 ID';

  @override
  String get developmentAllTypes => '全部类型';

  @override
  String get developmentTargetDrops => '目标出货';

  @override
  String get developmentOtherDrops => '其他出货';

  @override
  String get developmentInsufficient => '资源不足';

  @override
  String get developmentReplaced => '被替换出货';

  @override
  String get developmentRecommendations => '推荐配方';

  @override
  String get developmentNoTargets => '选择目标装备后显示推荐配方';

  @override
  String get developmentNoResults => '没有能同时开发所有目标的配方';

  @override
  String get developmentTargetRate => '目标率';

  @override
  String get developmentFailureRate => '失败率';

  @override
  String get developmentTotalResources => '总资源';

  @override
  String get developmentApplyRecipe => '回填配方';

  @override
  String get developmentDataError => '装备开发数据加载失败';

  @override
  String get developmentRetry => '重试';

  @override
  String developmentSelectedCount(int count) {
    return '已选 $count 件';
  }

  @override
  String get developmentPoolBauxite => '铝土系';

  @override
  String get developmentPoolAmmunition => '弹药系';

  @override
  String get developmentPoolFuelSteel => '油钢系';

  @override
  String get battlePredictionUnconfirmed => '数据未确认：血量与预测仅供参考，请以游戏画面为准。';

  @override
  String get mouseWheelCompatibility => '外接鼠标滚轮兼容';

  @override
  String get mouseWheelCompatibilityDescription =>
      '使用外接鼠标时，若游戏内滚轮无响应，可尝试开启。立即生效，保留鼠标点击和手指触控。';

  @override
  String get mouseWheelCompatibilitySaveFailed => '设置保存失败，请重试。';

  @override
  String get hdMode => 'HD 模式';

  @override
  String get hdModeDescription =>
      '开启后，使用专为大屏设备优化的 UI 配置（推荐 8 寸以上设备）。非大屏设备强行开启可能导致界面显示异常、布局溢出或应用崩溃等问题。';

  @override
  String get hdBottomLayout => 'HD 下栏布局';

  @override
  String get hdSplit => '两个 1×1';

  @override
  String get hdWide => '一个 1×2';

  @override
  String get hdLeftModule => '左侧模块';

  @override
  String get hdRightModule => '右侧模块';

  @override
  String get hdWideModule => '整宽模块';

  @override
  String get hdCustomize => '自定义布局';

  @override
  String get hdEditHint => '长按拖动手柄排序或移入下栏；拖到已有模块上交换位置。勾选显示，取消勾选隐藏。';

  @override
  String get hdHalfWidth => '半宽 1×1';

  @override
  String get hdFullWidth => '整宽 1×2';

  @override
  String get hdDropArea => '可放置功能区';

  @override
  String get workspaceMenuPosition => '菜单栏位置';

  @override
  String get workspaceMenuPositionDesc => '上方位于游戏画面下方。';

  @override
  String get menuPositionTop => '上';

  @override
  String get menuPositionBottom => '下';

  @override
  String get menuPositionLeft => '左';

  @override
  String get menuPositionRight => '右';

  @override
  String get topNoticeSectionTitle => '顶栏消息通知';

  @override
  String get topNoticeEnabledTitle => '顶栏通知';

  @override
  String get topNoticeEnabledSubtitle => '在顶栏「ヤハギ」右侧显示开发、改修、出击检查与任务完成提示';

  @override
  String get topNoticeDurationTitle => '提示停留时间';

  @override
  String get topNoticeDurationSubtitle => '消息气泡弹出后无操作自动收起的时长';

  @override
  String get topNoticeDuration5s => '5 秒 (默认)';

  @override
  String get topNoticeDuration10s => '10 秒';

  @override
  String get topNoticeDuration15s => '15 秒';

  @override
  String questCompletionSingleNotice(String title) {
    return '任务达成：$title';
  }

  @override
  String questCompletionMultiNotice(int count) {
    return '$count 个任务已达成，请前往任务界面';
  }

  @override
  String questPendingConfirmationSingleNotice(String title) {
    return '任务目标已达成（待游戏确认）：$title';
  }

  @override
  String questPendingConfirmationMultiNotice(int count) {
    return '$count 个任务目标已达成（待游戏确认）';
  }

  @override
  String noticeDevSuccess(String name) {
    return '$name 开发成功';
  }

  @override
  String get noticeDevFailed => '装备开发失败';

  @override
  String get noticeDevFailedPenguin => '装备开发失败';

  @override
  String get noticeDevSlotFailed => '开发失败';

  @override
  String get noticeDevDefaultName => '新装备';

  @override
  String get noticeEquipImproveSuccess => '装备改修成功';

  @override
  String get noticeEquipImproveFailed => '装备改修失败';

  @override
  String get noticeModFailed => '近代化改修失败';

  @override
  String get noticeModSuccess => '近代化改修成功';

  @override
  String noticeModSuccessDetail(String stats) {
    return '改修成功：$stats';
  }

  @override
  String get noticeModSuccessMaxCap => '改修成功 (属性已达上限)';

  @override
  String get statFirepower => '火力';

  @override
  String get statTorpedo => '雷装';

  @override
  String get statAntiAir => '对空';

  @override
  String get statArmor => '装甲';

  @override
  String get statLuck => '运';

  @override
  String get statHp => '耐久';

  @override
  String get statAsw => '对潜';

  @override
  String noticeMarriageLuck(String arrow, int delta, int remaining) {
    return '誓约运提升：运 $arrow +$delta / +$remaining';
  }

  @override
  String noticeMarriageLuckMax(String arrow, int delta) {
    return '誓约运提升：运 $arrow +$delta / MAX';
  }

  @override
  String noticePracticeExp(int sExp, int aExp) {
    return '演习经验（约）：S胜 $sExp · A胜 $aExp';
  }

  @override
  String noticePracticeExpCtBonus(int sExp, int aExp, String bonus) {
    return '演习经验（约）：S胜 $sExp · A胜 $aExp (练巡 +$bonus)';
  }

  @override
  String get noticeSortieShipFull => '母港船位已满！出击将无法获得新舰娘';

  @override
  String noticeSortieShipLow(int count) {
    return '船位仅剩 $count 个，请注意母港容量';
  }

  @override
  String get noticeSortieItemFull => '装备槽已满！出击将无法获得新装备';

  @override
  String noticeSortieItemLow(int count) {
    return '装备槽仅剩 $count 个，请注意母港容量';
  }

  @override
  String get noticeSortieShipAndItemFull => '母港船位与装备槽已满！出击将无法获得新舰娘与装备';

  @override
  String noticeSortieShipAndItemLow(int shipCount, int itemCount) {
    return '船位仅剩 $shipCount 个 · 装备槽仅剩 $itemCount 个，请注意母港容量';
  }

  @override
  String get noticeSortieExpansionSlotUnused => '舰队中有未使用的补强增设插槽';

  @override
  String noticePreSortieCheckFailed(String reasons) {
    return '出击前检查未通过：$reasons';
  }

  @override
  String get noticeSortieReasonUnresupplied => '未补满补给';

  @override
  String get noticeSortieReasonFatigue => '舰娘疲劳 (黄脸/红脸)';

  @override
  String get noticeSortieReasonMainSlot => '主装备槽未装满';

  @override
  String get noticeSortieReasonExpansionSlot => '补强增设插槽闲置';

  @override
  String get lockUi => '锁定界面';

  @override
  String get unlockUi => '解锁界面';

  @override
  String get uiLockedToast => '界面已锁定，布局自定义已禁用，功能切换不受影响';

  @override
  String get uiUnlockedToast => '界面已解锁';

  @override
  String get uiLockTitle => '锁定界面布局';

  @override
  String get uiLockDesc => '锁定后禁止长按卡片与顶栏资源进入自定义编辑，并禁止拖拽导航栏排序；功能页仍可正常切换';

  @override
  String get filterVisibleItems => '筛选显示项目';

  @override
  String get selectHeaderVisibleItems => '选择顶部显示项目';

  @override
  String get expCalculator => '经验计算';

  @override
  String get expCalcShip => '舰娘';

  @override
  String get expCalcCurrentLevel => '现在等级';

  @override
  String get expCalcTargetLevel => '目标等级';

  @override
  String get expCalcMap => '海域';

  @override
  String get expCalcRank => '评价';

  @override
  String get expCalcBaseExp => '基本经验值';

  @override
  String get expCalcFlagship => '旗舰';

  @override
  String get expCalcMvp => 'MVP';

  @override
  String get expCalcMapExp => '海域经验值';

  @override
  String get expCalcRemainExp => '剩余经验值';

  @override
  String get expCalcBattle => '战斗';

  @override
  String get expCalcEmptyTrackList => '暂无练级追踪计划，点击上方 ＋ 添加';

  @override
  String get expCalcBaseExpHelpTitle => '常用海域基本经验参考';

  @override
  String get expCalcTrackAdded => '已添加到经验追踪列表';

  @override
  String get expCalcTrackDeleted => '已从经验追踪列表移除';

  @override
  String get expCalcTrackLoadFailed => '追踪列表读取失败，点击重试';

  @override
  String get expCalcTrackSaveFailed => '追踪列表保存失败，请重试';

  @override
  String get expCalcFreeMode => '自定义计算（无舰娘）';

  @override
  String get expCalcAddNode => '增加战斗点位 (连战累计加算)';

  @override
  String get expCalcRemoveNode => '移除点';

  @override
  String get expCalcRouteTotal => '整趟总收益';

  @override
  String get expCalcNodePoint => '点位';

  @override
  String get expCalcRouteSummary => '出击海域路线';

  @override
  String get expCalcAddTrack => '加入动态追踪表格';

  @override
  String get expCalcCompletedTag => '0 次 (已达成)';

  @override
  String get expCalcCardView => '卡片';

  @override
  String get expCalcTableView => '表格';

  @override
  String get expCalcTrackListTitle => '练级追踪列表';

  @override
  String get expCalcAutoSyncHint => '母港数据变动时自动刷新剩余经验与场次';

  @override
  String get expCalcDelete => '删除';

  @override
  String get expCalcStep1Title => '阶段 1 · 舰娘与等级目标';

  @override
  String get expCalcStep2Title => '阶段 2 · 出击海域点位与战术路线编排';

  @override
  String get expCalcResultHudTitle => '出击路线综合推演结算';

  @override
  String get expCalcTargetGapLabel => '升级经验缺口';

  @override
  String get expCalcTargetAlignHint => '目标经验自动与经验表对齐';

  @override
  String get expCalcRouteSummaryPrefix => '当前路线共计';

  @override
  String get expCalcCombatNodesSuffix => '个战斗点位';

  @override
  String get expCalcAccumulatedExpLabel => '累计经验';

  @override
  String get customFontTitle => '界面字体';

  @override
  String get customFontDescription => '导入喜欢的字体，预览后应用。支持 TTF、OTF，最大 32 MB。';

  @override
  String get customFontDefault => '默认字体（系统字体大小）';

  @override
  String get customFontImport => '导入字体';

  @override
  String get customFontRestore => '恢复默认';

  @override
  String get customFontPreviewTitle => '字体预览';

  @override
  String get customFontApply => '应用字体';

  @override
  String get customFontPreviewSample => '舰队信息 · 出击记录 · 画面设置';

  @override
  String get customFontPreviewNote => '确认应用后将用于客户端界面，重启后仍然保留。';

  @override
  String get customFontImportFailed => '无法导入字体，请选择有效的 TTF 或 OTF 文件。';

  @override
  String get customFontSaveFailed => '字体设置保存失败，请重试。';

  @override
  String get customFontUnsupported => '当前平台暂不支持字体导入。';

  @override
  String get customFontTooLarge => '字体文件不能超过 32 MB。';

  @override
  String get customFontLoadLimit =>
      '为控制内存占用，本次运行已达到字体切换上限。请重启应用后再应用新字体，仍可继续预览。';

  @override
  String get customFontPreviewFailed => '字体预览生成失败，请重试。';

  @override
  String get customFontPreviewRetry => '重新预览';

  @override
  String get browserMenuMute => '静音';

  @override
  String get browserMenuUnmute => '开声音';

  @override
  String get browserMenuScreenshot => '截图';

  @override
  String get browserMenuFit => '修复显示';

  @override
  String get browserMenuFullscreen => '全屏';

  @override
  String get browserMenuHome => '主页';

  @override
  String get browserMenuDismissHint => '点击空白处关闭';

  @override
  String summaryFleetHeavy(int count) {
    return '大破 $count';
  }

  @override
  String summaryFleetMedium(int count) {
    return '中破 $count';
  }

  @override
  String summaryFleetMinMorale(int value) {
    return '最低疲劳 $value';
  }

  @override
  String summaryExpedition(int active, String time) {
    return '进行中 $active/3 · 最近 $time';
  }

  @override
  String summaryRepair(int busy, int total, String time) {
    return '使用中 $busy/$total · 最近 $time';
  }

  @override
  String summaryRepairBusy(int busy, int total) {
    return '使用中 $busy/$total';
  }

  @override
  String summaryConstruction(int done, int building) {
    return '完成 $done · 建造中 $building';
  }

  @override
  String summaryQuests(int done, int active) {
    return '可完成 $done · 进行中 $active';
  }

  @override
  String summaryLandBase(int sortie, int defense) {
    return '出击 $sortie · 防空 $defense';
  }

  @override
  String summaryWarnings(int count) {
    return '警告 $count';
  }

  @override
  String get questQueryTitle => '搜索与筛选任务';

  @override
  String questQueryScope(String scope) {
    return '查询范围：$scope';
  }

  @override
  String questApplyQuery(int count) {
    return '显示 $count 个任务';
  }

  @override
  String get questAccepted => '已接取';

  @override
  String get questConditionsAndProgress => '条件与进度';

  @override
  String get questSelectTask => '选择任务，查看完成条件';

  @override
  String get questBackToList => '返回任务列表';

  @override
  String get questReturnToTarget => '回到目标任务';

  @override
  String get questNoPrerequisites => '资料未列出直接前置任务';

  @override
  String get questNoSuccessors => '资料未列出后续任务';

  @override
  String get japaneseOriginal => '日文原文';

  @override
  String questQueryActive(int count) {
    return '$count 项查询条件已生效';
  }

  @override
  String get settingsTabRuntime => '游戏运行';

  @override
  String get settingsGroupAppearance => '基础外观';

  @override
  String get settingsGroupScreenAdaptation => '屏幕适配';

  @override
  String get settingsGroupLayoutPosition => '布局与位置';

  @override
  String get settingsGroupContentCustomization => '内容自定义';

  @override
  String get settingsGroupLayoutManagement => '布局管理';

  @override
  String get settingsOtherModuleDisplay => '其他模块显示';

  @override
  String get settingsEditInformationLayout => '信息面板布局编辑';

  @override
  String get settingsEditHdLayout => 'HD布局编辑';

  @override
  String get settingsResetMenuOrder => '恢复菜单栏顺序';

  @override
  String get settingsResetCardOrder => '恢复功能区卡片顺序';

  @override
  String get settingsGroupPerformanceRendering => '性能与画面';

  @override
  String get settingsGroupSubtitles => '字幕';

  @override
  String get settingsGroupScreenBackground => '保持运行';

  @override
  String get settingsGroupInformationCapture => '信息读取';

  @override
  String get settingsFrameRefreshConfirm => '框架刷新前确认';

  @override
  String get settingsFrameRefreshConfirmDescription => '从顶栏刷新游戏框架前显示确认对话框。';

  @override
  String get settingsFrameRefreshConfirmSaveFailed => '框架刷新确认设置保存失败，请重试。';

  @override
  String get settingsGroupDebuff => '解谜与削甲';

  @override
  String get settingsGroupShipStatusFeedback => '舰娘状态反馈';

  @override
  String get settingsGroupSystemNotifications => '系统通知';

  @override
  String get settingsEnableSystemNotifications => '启用系统通知';

  @override
  String get settingsSystemNotificationSound => '系统通知提示音';

  @override
  String get settingsSystemNotificationVibration => '系统通知振动';

  @override
  String get settingsGroupDataUpdates => '资料更新';

  @override
  String get settingsGroupDataSharingPrivacy => '数据共享与隐私';

  @override
  String get settingsGroupClearLocalData => '清理本地数据';

  @override
  String get settingsGroupAccount => '账号操作';

  @override
  String get settingsGroupDiagnosticsSupport => '诊断与支持';

  @override
  String get settingsStatusEnabled => '已开启';

  @override
  String get settingsStatusDisabled => '已关闭';

  @override
  String get settingsFleetDisplayStandard => '普通舰队卡片';

  @override
  String get settingsFleetDisplayHd => 'HD 双列舰队卡片';

  @override
  String get briefingDisplayTitle => '简报展示方式';

  @override
  String get briefingDisplayDescription =>
      '折叠式可同时展开多个模块；标签式通过顶部标签切换模块。HD 模式下无效。';

  @override
  String get briefingDisplayAccordion => '折叠式';

  @override
  String get briefingDisplayTabs => '标签式';

  @override
  String get briefingTabForecast => '先知';

  @override
  String get briefingTabFleet => '编队';

  @override
  String get briefingTabLandBase => '陆基';

  @override
  String get briefingTabExpedition => '远征';

  @override
  String get briefingTabRepair => '入渠';

  @override
  String get briefingTabConstruction => '建造';

  @override
  String get briefingTabQuests => '任务';

  @override
  String get briefingTabPreSortie => '检查';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get debuffReminderTitle => '削甲提醒';

  @override
  String get debuffReminderSourcePort => '母港';

  @override
  String get debuffReminderSourceBattleResult => '戰鬥結算';

  @override
  String get debuffReminderSourceAirDefense => '基地防空';

  @override
  String debuffReminderMessage(String source) {
    return '$source：偵測到解謎／削弱提示。';
  }

  @override
  String get debuffReminderSectionTitle => '遊戲內提醒';

  @override
  String get debuffReminderSettingTitle => '削甲提醒';

  @override
  String get debuffReminderSettingSubtitle => '兩種方式均附帶震動；偵測到解謎／削弱提示時提醒';

  @override
  String get debuffReminderStyleDialog => '確認彈窗（預設）';

  @override
  String get debuffReminderStyleTopNotice => '頂部提醒';

  @override
  String get cameraAvoidanceTitle => '攝影鏡頭避讓';

  @override
  String get cameraAvoidanceDesc => '調整攝影鏡頭一側的介面留白，翻轉螢幕時自動換邊。';

  @override
  String get cameraAvoidanceDistance => '避讓距離';

  @override
  String get operationProtectionTitle => '操作保護';

  @override
  String get confirmBeforeExitTitle => '防止誤離開';

  @override
  String get confirmBeforeExitDescription => '使用返回鍵或返回手勢離開應用程式前，需要確認。';

  @override
  String get confirmBeforeExitSaveFailed => '防止誤離開設定儲存失敗，請重試。';

  @override
  String get appExitConfirmTitle => '返回主畫面？';

  @override
  String get appExitConfirmDescription => '目前的遊戲將切換至背景。';

  @override
  String get appExitStay => '繼續遊戲';

  @override
  String get appExitToDesktop => '返回主畫面';

  @override
  String get appExitFailed => '無法返回主畫面，請重試。';

  @override
  String get enterGameFullscreen => '遊戲全螢幕';

  @override
  String get exitGameFullscreen => '退出全螢幕';

  @override
  String get exitFullscreenShort => '退出';

  @override
  String get exitFullscreenConfirmTitle => '確定要退出遊戲全螢幕嗎？';

  @override
  String get exitFullscreenConfirmDescription => '退出全螢幕後將恢復控制台與工具列顯示。';

  @override
  String get exitFullscreenSkipConfirmation => '下次不再提醒';

  @override
  String get exitFullscreenConfirmAction => '退出全螢幕';

  @override
  String get gameFullscreenHint => '點擊浮鈕或按返回鍵退出全螢幕；可拖動浮鈕調整位置';

  @override
  String get gameFullscreenUnavailable => '無法顯示退出按鈕，已恢復一般佈局';

  @override
  String get questCompletionNotice => '有任務已完成';

  @override
  String questCompletionCount(int count) {
    return '$count 個任務已完成，待領取';
  }

  @override
  String get resourceTrend90d => '90天';

  @override
  String get resourceTrendInventoryTitle => '庫存趨勢';

  @override
  String get resourceTrendCustomize => '顯示資源';

  @override
  String get resourceTrendAtLeastOne => '至少保留一項資源';

  @override
  String get resourceTrendBuildMaterial => '高速建造材';

  @override
  String get resourceTrendRepairMaterial => '高速修復材';

  @override
  String get resourceTrendDevMaterial => '開發資材';

  @override
  String get resourceTrendImproveMaterial => '改修資材';

  @override
  String get resourceTrendLatest => '最新存量';

  @override
  String get resourceTrendChange => '區間增減';

  @override
  String resourceTrendBaseline(String time) {
    return '增減基準：$time JST';
  }

  @override
  String resourceTrendObserved(String time) {
    return '最後紀錄：$time JST';
  }

  @override
  String get resourceTrendPartial => '缺少期初紀錄，按首條紀錄計算增減';

  @override
  String get resourceTrendInsufficient => '可比較的紀錄不足';

  @override
  String get resourceTrendNoPeriodData => '此時段暫無資源紀錄';

  @override
  String get resourceTrendLoadError => '資源紀錄載入失敗';

  @override
  String get resourceTrendSaveError => '資源顯示設定未能儲存';

  @override
  String get resourceTrendInspect => '滑動查看';

  @override
  String get resourceTrendExpand => '放大圖表';

  @override
  String get resourceTrendSampled => '長時段圖表已保留峰谷，讀數對應實際取樣紀錄';

  @override
  String get resourceTrendLocalScale => '縱軸隨存量範圍縮放';

  @override
  String get resourceTrendBaseShort => '基準';

  @override
  String get diagnosticLoggingSection => '用戶端診斷日誌';

  @override
  String get diagnosticLoggingTitle => '記錄用戶端診斷日誌';

  @override
  String get diagnosticLoggingDesc => '僅記錄效能和錯誤摘要，不包含帳號、密碼或登入憑據';

  @override
  String get telemetryAnonymousStatsTitle => '匿名裝置與使用統計';

  @override
  String get telemetryAnonymousStatsDesc =>
      '傳送包含裝置資訊和渲染模式的匿名統計資料，以協助開發者持續最佳化與改進應用程式。不包含任何帳號或隱私資訊。';

  @override
  String get diagnosticPrivacyTitle => '隱私安全診斷';

  @override
  String get diagnosticPrivacyDesc =>
      '匯出前會再次檢查內容。日誌不記錄帳號、密碼、Cookie、權杖、請求正文、回應正文、聊天內容或截圖，也不會自動上傳。';

  @override
  String get diagnosticStatusEnabled => '正在記錄';

  @override
  String get diagnosticStatusDisabled => '已停止記錄';

  @override
  String diagnosticStorageUsage(String size) {
    return '本機日誌佔用：$size';
  }

  @override
  String get exportDiagnosticFile => '匯出診斷檔案';

  @override
  String get saveDiagnosticFile => '儲存到本機';

  @override
  String get shareDiagnosticFile => '分享診斷檔案';

  @override
  String get diagnosticSaveConfirmTitle => '儲存診斷檔案？';

  @override
  String get diagnosticSaveConfirmDesc =>
      '將產生一個通過隱私檢查的 JSON 檔案。接下來只需選擇儲存資料夾，檔名由用戶端自動產生且不可修改。';

  @override
  String get diagnosticSaveAction => '選擇資料夾';

  @override
  String diagnosticSaveSucceeded(String fileName) {
    return '已儲存：$fileName';
  }

  @override
  String get diagnosticSaveFailed => '診斷檔案儲存失敗';

  @override
  String get diagnosticShareConfirmTitle => '分享診斷檔案？';

  @override
  String get diagnosticShareConfirmDesc =>
      '將產生一個通過隱私檢查的 JSON 檔案，並開啟系統分享面板。請在傳送前自行確認接收方。';

  @override
  String get diagnosticShareAction => '分享';

  @override
  String get diagnosticShareFailed => '診斷檔案分享失敗';

  @override
  String get clearDiagnosticData => '清除診斷日誌';

  @override
  String get diagnosticExportConfirmTitle => '匯出診斷檔案？';

  @override
  String get diagnosticExportConfirmDesc =>
      '將產生一個 JSON 檔案，並呼叫系統分享面板。檔案只包含用戶端效能、錯誤摘要及匿名裝置執行資訊，請在傳送前自行確認接收方。';

  @override
  String get diagnosticExportAction => '匯出';

  @override
  String get diagnosticClearConfirmTitle => '清除診斷日誌？';

  @override
  String get diagnosticClearConfirmDesc =>
      '將刪除應用程式內的診斷日誌和暫存匯出副本。已另存或分享的檔案需自行刪除。';

  @override
  String get diagnosticClearFailed => '清除診斷資料失敗，請重試。';

  @override
  String get diagnosticExportFailed => '診斷檔案匯出失敗';

  @override
  String get langKo => '한국어';

  @override
  String get langEn => 'English';

  @override
  String get dataVersionLabel => '資料版本';

  @override
  String get dataLastCheckedLabel => '上次檢查';

  @override
  String get dataNotChecked => '尚未檢查';

  @override
  String get sortieMapDataTitle => '海域資料';

  @override
  String get enemyDataTitle => '敵艦資料';

  @override
  String dataCatalogUpToDate(String version) {
    return '資料已是最新版本。\n版本：$version';
  }

  @override
  String dataCatalogUpdated(String before, String after) {
    return '資料更新成功。\n$before → $after';
  }

  @override
  String get dataCatalogIncompatible => '目前應用程式版本過舊，請先更新應用程式。';

  @override
  String get dataCatalogValidationFailed => '更新資料驗證失敗，已繼續使用目前資料。';

  @override
  String get dataCatalogStorageFailed => '無法儲存更新資料。';

  @override
  String get dataCatalogNetworkFailed => '網路更新失敗，請稍後重試。';

  @override
  String get questLocalProgress => '本機進度';

  @override
  String questServerProgress(String progress) {
    return '伺服器進度：$progress';
  }

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
  String get layoutSettings => '介面與配置';

  @override
  String get themeColorTitle => '主題色';

  @override
  String get themeClassicDark => '原版暗色';

  @override
  String get themeSeaSaltTeal => '海鹽青';

  @override
  String get themeClearSkyBlue => '晴空藍';

  @override
  String get uiFontSizeTitle => '介面字級';

  @override
  String get uiFontSizeDescription => '預設跟隨系統。';

  @override
  String get uiFontSizeSystem => '預設（跟隨系統）';

  @override
  String get uiFontSizeSmall => '小';

  @override
  String get uiFontSizeMedium => '中';

  @override
  String get uiFontSizeLarge => '大';

  @override
  String get uiDisplaySizeTitle => '介面UI大小';

  @override
  String get uiDisplaySizeDesc => '調整頂欄、導航欄與資訊欄的顯示密度';

  @override
  String get uiDisplaySizeNormal => '標準';

  @override
  String get uiDisplaySizeCompact => '緊湊';

  @override
  String get uiDisplaySizeMinimal => '極簡';

  @override
  String get panelResourcesExpand => '展開資源';

  @override
  String get panelResourcesCollapse => '摺疊資源';

  @override
  String get panelResourcesCollapsedItems => '摺疊時顯示';

  @override
  String get panelResourcesCollapsedItemsReset => '恢復預設';

  @override
  String get minimalResourcePositionTitle => '資源位置';

  @override
  String get minimalResourcePositionDesc =>
      '極簡檔手機橫屏遊戲頁的資源顯示在資訊欄頂部、遊戲上方的細橫欄，或螢幕底部的細橫欄';

  @override
  String get minimalResourcePositionPanel => '資訊欄';

  @override
  String get minimalResourcePositionTopBar => '頂部橫欄';

  @override
  String get minimalResourcePositionBottomBar => '底部橫欄';

  @override
  String get gameAreaRatio => '遊戲區域佔比';

  @override
  String get infoPanelWidth => '資訊面板寬度（直向模式無效）';

  @override
  String get autoZoom => '套用建議顯示比例（遊戲與選單比例 67:33）';

  @override
  String get enhancedDamagePulse => '加強受損呼吸提示';

  @override
  String get enhancedDamagePulseDesc => '依小破、中破、大破增強顏色、速度與頭像內部光效。關閉後使用普通效果。';

  @override
  String get informationPanelOnLeft => '功能區域置於左側';

  @override
  String get informationPanelOnLeftDesc => '關閉時功能區域保持在右側，直向時保持上下配置。';

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
      '目前裝置的 Android System WebView 不支援應用程式內代理設定。\n您只能使用系統網路或全域 VPN。';

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
  String get hostAddress => '主機位址 (IP 或網域)';

  @override
  String get hostHint => '如 192.168.1.10';

  @override
  String get port => '通訊埠';

  @override
  String get currentSavedMode => '目前已儲存模式';

  @override
  String get vpnStatus => 'VPN 狀態';

  @override
  String get vpnActive => '已偵測到啟用中的 VPN';

  @override
  String get vpnInactive => '未偵測到啟用中的 VPN';

  @override
  String get testConnection => '網路連線測試';

  @override
  String get applySettings => '套用設定並重新載入遊戲';

  @override
  String get restoreSystemNetwork => '恢復系統網路';

  @override
  String get gameSafety => '大破提醒';

  @override
  String get battleSafetySectionTitle => '遊戲安全';

  @override
  String get blockSortieTitle => '大破進擊提醒';

  @override
  String get blockSortieDesc =>
      '出擊或進擊請求返回後，若出擊艦隊中有非旗艦大破艦船（已撤退艦船除外），會彈出需要確認的警告。此提醒不攔截出擊或進擊請求，也不會自動撤退。';

  @override
  String get storageAndCache => '儲存與快取';

  @override
  String get logoutAndClear => '登出 / 清除帳號資訊';

  @override
  String get logoutAndClearDesc => '清除遊戲登入狀態，下次開啟需要重新登入。';

  @override
  String get clearQuestCache => '清理任務資料快取';

  @override
  String get clearQuestCacheDesc => '清除本機快取中已去識別化的任務資料，重新啟動應用程式後需進入遊戲內任務面板重新取得';

  @override
  String get clearWebCache => '清理瀏覽器網頁快取';

  @override
  String get clearWebCacheDesc => '清除 WebView 網頁核心的暫存頁面與指令碼資料。';

  @override
  String get baseSenkaResetTitle => '素戰果歸零';

  @override
  String get baseSenkaResetDesc => '將本月累計素戰果設為 0.00，不影響 EO、任務和其他戰果資料。';

  @override
  String get baseSenkaResetConfirmTitle => '素戰果歸零';

  @override
  String get baseSenkaResetConfirmDesc =>
      '確定將本月累計素戰果歸零嗎？每日 EO 與任務獎勵記錄會保留，後續經驗增量將從 0.00 繼續累計。';

  @override
  String get baseSenkaResetSuccess => '本月累計素戰果已歸零';

  @override
  String get baseSenkaManualTitle => '手動填寫素戰果';

  @override
  String baseSenkaCurrentValue(String value) {
    return '本月累計：$value 戰果';
  }

  @override
  String get baseSenkaManualDialogTitle => '填寫本月累計素戰果';

  @override
  String get baseSenkaManualInputLabel => '本月累計素戰果';

  @override
  String get baseSenkaManualInvalid => '請輸入非負數字，最多保留兩位小數';

  @override
  String baseSenkaSetSuccess(String value) {
    return '本月累計素戰果已設為 $value';
  }

  @override
  String get baseSenkaSaveFailed => '素戰果儲存失敗，請重試';

  @override
  String get senkaTodaySorties => '今日出擊';

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
  String get sortieCheckShipsMode => '艦娘';

  @override
  String get sortieCheckMapsMode => '海域';

  @override
  String get mapHpGauges => '海域血量';

  @override
  String get noMapGaugeData => '暫無海域血量資料';

  @override
  String get noMapGaugeDataHint => '請在遊戲中進入出擊海域以同步資料';

  @override
  String get showClearedMaps => '顯示已攻略';

  @override
  String get allMapsCleared => '所有海域已攻略完成';

  @override
  String get forecast => '未卜先知';

  @override
  String get waitingForSortieData => '等待出擊資料';

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
  String get clearWebCacheConfirmTitle => '清理瀏覽器網頁快取';

  @override
  String get clearWebCacheConfirmDesc =>
      '確定要清除瀏覽器網頁快取嗎？這將會刪除 WebView 網頁核心快取的暫存資料，不影響已下載的遊戲本機資源包。';

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
      '本軟體不參與、不阻斷、不重放且不竄改遊戲伺服器的通訊資料，也不會代替玩家執行遊戲操作。原作者不對軟體的品質做任何明示或暗示的保證（包括但不限於對軟體完全無 Bug、適用性或系統穩定性的保證）。';

  @override
  String get disclaimerP3 =>
      '在任何情況下，因使用或無法使用本軟體而導致的任何行動裝置損壞、資料遺失、遊戲帳號封禁風險或其他任何形式的直接或間接利益損失，原作者均不承擔任何法律與連帶責任。如果您在「技術學習」之外的場景使用本軟體，所產生的一切版權爭議、服務條款違規及其他風險，均將由使用者自行承擔。';

  @override
  String get viewOnGitHub => '前往 GitHub';

  @override
  String get officialWebsite => '官網';

  @override
  String get checkForUpdates => '檢查更新';

  @override
  String get openSourceLicense => '開源授權條款：MIT License';

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
  String get noReleaseDesc => 'GitHub 儲存庫尚未發佈任何 Release。';

  @override
  String get checkFailed => '檢查失敗';

  @override
  String get networkError => '網路錯誤';

  @override
  String get networkErrorDesc => '檢查更新時發生錯誤，請稍後重試。';

  @override
  String get externalLinkOpenFailed => '無法開啟連結，請檢查是否已安裝瀏覽器。';

  @override
  String get noUpdateLog => '暫無更新日誌';

  @override
  String get battleWarningOff => '關閉';

  @override
  String get battleWarningConfirm => '開啟提醒';

  @override
  String get advanceWarningDisplayModeTitle => '提醒方式';

  @override
  String get advanceWarningAlwaysConfirm => '始終確認';

  @override
  String get advanceWarningSmart => '智慧提醒';

  @override
  String get advanceWarningSmartDescription => '大破艦損管均確認可用時頂部通知，否則彈窗。';

  @override
  String get advanceWarningAlwaysConfirmDescription => '偵測到大破時彈窗確認。';

  @override
  String get advanceWarningTimingModeTitle => '提醒時機';

  @override
  String get advanceWarningTimingModeDescription => '修改從下次出擊生效。';

  @override
  String get advanceWarningPostBattle => '結算後提醒';

  @override
  String get advanceWarningAfterAdvance => '進擊後提醒';

  @override
  String get advanceWarningBothTimings => '兩次都提醒';

  @override
  String get advanceWarningAfterAdvanceDescription => '進擊成功後檢查大破。';

  @override
  String get advanceWarningPostBattleDescription => '戰鬥結算後檢查大破。';

  @override
  String get advanceWarningBothTimingsDescription => '結算後和進擊成功後均檢查大破。';

  @override
  String get advanceWarningTimingRequired => '至少保留一項提醒時機。';

  @override
  String get advanceWarningPostBattleOnlyWarning => '進擊成功後將不再檢查大破狀態。';

  @override
  String get postBattleDamageControlEquippedBody => '戰鬥結算後存在大破艦娘，請確認艦船及剩餘損管。';

  @override
  String get postBattleDamageControlDangerBody =>
      '戰鬥結算後存在大破艦娘！請停止進擊並核對遊戲內狀態，避免進入下一場戰鬥。';

  @override
  String get advanceWarningDamageControlActive => '管損有效中';

  @override
  String get advanceWarningReloadGame => '重新整理遊戲';

  @override
  String get advanceWarningReloadFrame => '框架重新整理';

  @override
  String get advanceWarningRefreshFailed => '重新整理未完成，請核對遊戲狀態與裝備。';

  @override
  String get logoutSnackbar => '已登出並清除帳號資訊。';

  @override
  String get logoutConfirmTitle => '登出並清除帳號資訊';

  @override
  String get logoutConfirmDesc =>
      '將清除應用程式內遊戲頁面的 Cookie、本機儲存資料與快取，然後返回登入頁面。確定繼續嗎？';

  @override
  String get logoutSucceeded => '已登出，請重新登入。';

  @override
  String get logoutFailed => '登出失敗，請稍後再試。';

  @override
  String get questCacheCleared => '已清除任務資料本機快取';

  @override
  String get webCacheCleared => '已清理瀏覽器網頁快取';

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
  String get antiCatbombDesc => '開啟後，若遊戲請求因網路中斷等原因失敗，App 將暫停遊戲並持續重試，避免出現「貓」錯誤。';

  @override
  String get close => '關閉';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '確定';

  @override
  String get waitingForData => '等待資料';

  @override
  String get fleetNoShips => '目前艦隊沒有艦娘';

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
  String get avgCondition => '最低士氣';

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
  String get waitingForEquip => '裝備資料等待更新';

  @override
  String get fastSpeed => '高速';

  @override
  String get slowSpeed => '低速';

  @override
  String get gotIt => '知道了';

  @override
  String get unknownEquip => '未知裝備';

  @override
  String get noBonusStats => '暫無裝備屬性';

  @override
  String get condition => '士氣';

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
  String get gadgetBypass => '遊戲資源鏡像與IP限制繞行';

  @override
  String get gadgetBypassDesc => '開啟後透過鏡像載入遊戲用戶端靜態資源。DMM 地區限制相容處理自動生效，不受此開關影響。';

  @override
  String get gadgetBypassEnable => '開啟鏡像繞行';

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
  String get waitingForPortDataDescription => '進入遊戲母港或重新整理遊戲頁面後，這裡會自動更新';

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
  String get averageCondition => '最低士氣';

  @override
  String get moraleRecoveryCountdown => '恢復倒數';

  @override
  String get moraleRecovered => '已恢復';

  @override
  String get toggleMoraleMetric => '點擊切換最低士氣與恢復倒數';

  @override
  String get losDetails => '索敵詳情';

  @override
  String get airPowerDetails => '制空詳情';

  @override
  String get minimumValue => '最小';

  @override
  String get maximumValue => '最大';

  @override
  String get withoutBonus => '不含熟練度加成';

  @override
  String get showAirPowerDetails => '點擊查看制空詳情';

  @override
  String get unknownShipType => '未知艦種';

  @override
  String get needsSupply => '需要補給';

  @override
  String get equipmentDataWaiting => '裝備資料等待更新';

  @override
  String get highSpeed => '高速';

  @override
  String get lowSpeed => '低速';

  @override
  String get unknownEquipment => '未知裝備';

  @override
  String get noAdditionalStats => '暫無裝備屬性';

  @override
  String get fatigue => '士氣';

  @override
  String get startupUpdateTitle => '發現新版本';

  @override
  String get backgroundAudio => '背景播放聲音';

  @override
  String get backgroundAudioDesc => '開啟後，應用程式進入背景時遊戲聲音仍會繼續播放。';

  @override
  String get backgroundGameRetention => '背景保持遊戲';

  @override
  String get backgroundGameRetentionDesc =>
      '遊戲執行期間顯示常駐通知，降低切換應用程式後工作階段被系統回收的機率，可能增加耗電。';

  @override
  String get backgroundGameRetentionNotificationTitle => '矢矧正在背景執行';

  @override
  String get backgroundGameRetentionNotificationBody => '正在保持遊戲工作階段 · 點擊返回遊戲';

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
  String get takeScreenshot => '一鍵截圖';

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
  String get enemyFleet => '敵艦隊';

  @override
  String airStateLabel(String label) {
    return '制空：$label';
  }

  @override
  String get postBattleWarningTitle => '大破安全警告';

  @override
  String get advanceWarningMissingHeadline => '有未攜帶損管的大破艦娘！';

  @override
  String get advanceWarningUnknownHeadline => '大破艦娘的損管狀態未知！';

  @override
  String get advanceWarningEquippedHeadline => '大破艦娘已攜帶損管，請確認剩餘裝備。';

  @override
  String get advanceWarningEquippedBody => '已在大破狀態下選擇進擊，請確認艦船及剩餘損管。';

  @override
  String get advanceWarningMissing => '未攜帶損管';

  @override
  String get advanceWarningUnknown => '損管狀態未知，請核對遊戲內裝備';

  @override
  String advanceWarningEquipped(String items) {
    return '攜帶：$items';
  }

  @override
  String get advanceWarningPersonnel => '應急修理要員';

  @override
  String get advanceWarningGoddess => '應急修理女神';

  @override
  String advanceWarningShipPosition(int fleet, int position) {
    return '第$fleet艦隊·$position號艦';
  }

  @override
  String get advanceWarningMuteSortie => '此次出擊不再提醒';

  @override
  String get postBattleWarningHeadline => '出擊艦隊中有大破艦娘！';

  @override
  String get postBattleWarningBody => '已在大破狀態下選擇進擊！請立即停止後續操作，避免進入下一場戰鬥。';

  @override
  String get acknowledgeAndRetreat => '確認了解';

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
  String get questAwaitingConfirmation => '已達成（待確認）';

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
  String get browserOnlyCaptureOffDesc => '遊戲網頁繼續執行，艦隊、任務和戰鬥資訊暫停更新。';

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
  String get noCookieReadDesc => 'JS 橋接擷取介面路徑、去識別化的請求參數與回應等遊戲資料，不讀取 Cookie。';

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
  String get captureUnsupportedDesc => '遊戲仍可執行；目前裝置只提供網頁瀏覽。';

  @override
  String get captureFailedDesc => '遊戲仍可執行，可重新整理頁面後重試。';

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
    return '士氣 $value';
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
  String get gameFrameRateTitle => '遊戲幀率';

  @override
  String get gameFrameRateAutomatic => '自動';

  @override
  String get gameFrameRateStable60 => '60 幀';

  @override
  String get gameFrameRateStable60Desc => '始終以 60 FPS 執行，不自動降檔。';

  @override
  String get gameFrameRateStable30 => '30 幀';

  @override
  String get gameFrameRateStable30Desc => '始終以 30 FPS 執行，降低耗電和發熱。';

  @override
  String get gameFrameRateHighRefresh => '高更新率';

  @override
  String get gameFrameRateHighRefreshDesc =>
      '解除 60 FPS 限制，跟隨螢幕更新率執行，耗電和發熱可能增加。';

  @override
  String get gameFrameRateHighRefreshDialogTitle => '開啟高更新率模式？';

  @override
  String get gameFrameRateHighRefreshDialogBody =>
      '高更新率會修改遊戲執行幀率，可能增加耗電、發熱或引發動畫異常，並存在未知的帳號風險。請自行承擔後果。';

  @override
  String get gameFrameRateHighRefreshDialogConfirm => '了解風險並開啟';

  @override
  String get gameFrameRateAutomaticDesc =>
      '上限為 60 FPS；若持續不穩定、系統開啟省電或裝置發熱，將自動降至 30 FPS。';

  @override
  String get gameFrameRateUnsupported =>
      '目前 Android WebView 不支援幀率調整，將保持遊戲原始幀率。';

  @override
  String get gameRenderingModeTitle => '遊戲渲染模式';

  @override
  String get gameRenderingModeStandard => '輕量模式';

  @override
  String get gameRenderingModeStandardDesc =>
      'Flutter PlatformView + Texture Layer + WebGL，減少部分合成開銷，部分裝置可能存在顯示或觸控相容性問題。';

  @override
  String get gameRenderingModeCompatibility => '均衡模式';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Flutter PlatformView + Hybrid Composition + WebGL，兼顧遊戲效能與裝置相容性。';

  @override
  String get gameRenderingModeCanvas => '相容模式';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Flutter PlatformView + Hybrid Composition + Canvas，繞過 WebGL，優先解決部分 GPU / WebGL 相容性問題，畫面效能可能降低。';

  @override
  String get gameRenderingModeNativeActivity => '原生獨立渲染（推薦）';

  @override
  String get gameRenderingModeNativeActivityDesc =>
      'Activity Direct WebView + WebGL，理論上具有更低的合成開銷與更好的原生相容性。';

  @override
  String get gameRenderingModeConfirmTitle => '切換遊戲渲染模式？';

  @override
  String get gameRenderingModeConfirmMessage =>
      '切換渲染模式會自動重新啟動應用程式，遊戲頁面將重新載入。請先結束正在進行的操作。';

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
  String get nativeGameSurfaceSwitchRenderingModeHint =>
      '目前裝置暫不相容此模式。請捲動左側選單，前往【設定 - 遊戲運行】切換渲染模式。';

  @override
  String nativeGameSurfacePageInitializationFailed(
    String stage,
    String errorType,
  ) {
    return '遊戲頁面初始化失敗 [$stage]：$errorType';
  }

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
  String get sortAscending => '升序';

  @override
  String get sortDescending => '降序';

  @override
  String sortPriority(int priority) {
    return '第$priority優先級';
  }

  @override
  String get sortLockedState => '已鎖定';

  @override
  String get sortTemporaryState => '臨時排序';

  @override
  String get sortHeaderHint => '點擊切換排序；長按或按 Shift+Enter 鎖定';

  @override
  String get sortHeaderLockedHint => '點擊切換排序方向；長按或按 Shift+Enter 解除鎖定';

  @override
  String get sortLockAction => '鎖定為下一優先級';

  @override
  String get sortUnlockAction => '解除目前排序鎖定';

  @override
  String get settingsTabScreen => '外觀與布局';

  @override
  String get settingsTabSound => '聲音';

  @override
  String get settingsTabBattle => '出擊與戰鬥';

  @override
  String get settingsTabNotification => '通知與提醒';

  @override
  String get settingsTabNetwork => '網路與連線';

  @override
  String get settingsTabData => '資料管理';

  @override
  String get settingsTabAboutSupport => '關於與支援';

  @override
  String get notificationSectionSystem => '系統通知狀態';

  @override
  String get notificationSectionSystemDesc =>
      '授權通知與精確提醒權限，可確保在鎖定螢幕或背景執行時，遠征、入渠等提醒準時跳出，避免被系統省電策略延遲。點擊對應項目可直接前往系統設定開啟。';

  @override
  String get notificationPermissionGranted => '通知權限已授予';

  @override
  String get notificationPermissionDenied => '通知權限未授予';

  @override
  String get notificationExactAlarmGranted => '精確提醒已授權';

  @override
  String get notificationExactAlarmDenied => '精確提醒未授權，將使用省電相容模式';

  @override
  String get notificationChannelsEnabled => '通知頻道可用';

  @override
  String get notificationChannelsDisabled => '通知頻道已被系統關閉';

  @override
  String get notificationSectionGeneral => '全域通知服務';

  @override
  String get notificationEnableMaster => '啟用通知服務';

  @override
  String get notificationSound => '通知提示音';

  @override
  String get notificationVibration => '震動提醒';

  @override
  String get notificationSectionOngoing => '背景常駐進行中進度';

  @override
  String get notificationOngoingLive => '常駐即時進度條卡片';

  @override
  String get notificationProgress => '進度條';

  @override
  String get notificationPercent => '百分比';

  @override
  String get notificationCountdown => '即時倒數';

  @override
  String get notificationSectionTypes => '通知類型與時機';

  @override
  String get notificationExpedition => '遠征';

  @override
  String get notificationRepair => '入渠';

  @override
  String get notificationAnchorage => '泊地';

  @override
  String get notificationConstruction => '建造';

  @override
  String get notificationMorale => '疲勞 / 刷閃';

  @override
  String get notificationPunctual => '準時';

  @override
  String get notificationPreempt30s => '提前 30 秒';

  @override
  String get notificationPreempt60s => '提前 60 秒';

  @override
  String get notificationPreempt120s => '提前 2 分鐘';

  @override
  String get notificationRepairPunctual => '準時';

  @override
  String get notificationAnchorage20m => '滿 20 分鐘首輪';

  @override
  String get notificationAnchorageFull => '全部修滿';

  @override
  String get notificationAnchorageBoth => '雙階段均提醒';

  @override
  String get frameRateSettingsSection => '幀率設定';

  @override
  String get battleAlertsSection => '戰鬥提醒';

  @override
  String get battleDamageVibration => '戰鬥受損震動提醒';

  @override
  String get battleDamageVibrationDesc => '我方艦娘在戰鬥中剛進入中破或大破時震動提醒。';

  @override
  String get battleStatusEffectsSection => '戰鬥狀態效果';

  @override
  String get battleStatusEffectsEnabled => '啟用狀態效果';

  @override
  String get battleStatusEffectsEnabledDesc => '統一開啟或關閉受損閃爍、受損震動與士氣閃光。';

  @override
  String get battleEffectDisplayScope => '畫面顯示範圍';

  @override
  String get battleEffectDisplayScopeDesc => '決定受損閃爍與士氣閃光出現在哪些艦娘畫面。';

  @override
  String get battleEffectScopePredictionOnly => '僅未卜先知';

  @override
  String get battleEffectScopeFleetOnly => '僅編隊';

  @override
  String get battleEffectScopeAll => '全部';

  @override
  String get battleDamagePulse => '受損閃爍';

  @override
  String get battleDamagePulseDesc => '按目前 HP 損傷等級控制頭像邊框的動態閃爍。';

  @override
  String get battleDamageVibrationEffect => '受損震動';

  @override
  String get battleDamageVibrationEffectDesc => '我方艦娘在戰鬥中剛進入所選損傷狀態時震動。';

  @override
  String get battleMoraleSparkle => '士氣閃光效果';

  @override
  String get battleMoraleSparkleDesc =>
      'Cond ≥ 50 時在艦娘頭像周圍顯示閃爍或恆亮星光；不影響疲勞臉和疲勞警告。';

  @override
  String get battleMoraleSparkleBlinking => '閃爍';

  @override
  String get battleMoraleSparkleSteady => '恆亮';

  @override
  String get battleEffectOff => '關閉';

  @override
  String get battleEffectMinorOnly => '僅小破';

  @override
  String get battleEffectModerateOnly => '僅中破';

  @override
  String get battleEffectHeavyOnly => '僅大破';

  @override
  String get battleEffectAll => '全部開啟';

  @override
  String get battlePredictionSection => '未卜先知';

  @override
  String get battleEnemyPreviewPortraits => '戰前敵方立繪';

  @override
  String get battleEnemyPreviewPortraitsDesc => '在未卜先知中顯示戰前敵方立繪。';

  @override
  String get battleLastFormationHint => '顯示上次選擇的陣形';

  @override
  String get battleLastFormationHintDesc => '抵達出擊節點時，在未卜先知中提示該點上次使用的陣形。';

  @override
  String get battleEnemyPreviewPosition => '戰前敵艦預測位置';

  @override
  String get battleEnemyPreviewPositionDesc => '選擇戰前敵艦預測顯示在我方血條的上方或下方。';

  @override
  String get battleEnemyPreviewPositionAbove => '上方';

  @override
  String get battleEnemyPreviewPositionBelow => '下方';

  @override
  String get battleSectionOrder => '資訊區順序';

  @override
  String get battleSectionOrderDescription => '調整資訊區顯示順序';

  @override
  String get battleSectionOrderAdjust => '調整';

  @override
  String get battleSectionOrderHint => '點擊上下箭頭調整，自動儲存';

  @override
  String get battleSectionSortieMap => '海域小地圖';

  @override
  String get battleSectionEnemyPreview => '敵方預測';

  @override
  String get battleSectionPredictionResult => '預測結果';

  @override
  String get battleSectionOrderRestoreDefault => '恢復預設';

  @override
  String get battleSectionOrderSaveFailed => '儲存失敗，請重試。';

  @override
  String battleSectionOrderMoveUp(String section) {
    return '上移$section';
  }

  @override
  String battleSectionOrderMoveDown(String section) {
    return '下移$section';
  }

  @override
  String battleLastFormation(String formation) {
    return '上次：$formation';
  }

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
  String get networkValidationPortEmpty => '通訊埠不能為空';

  @override
  String get networkValidationPortDecimal => '通訊埠不能使用小數';

  @override
  String get networkValidationPortNegative => '通訊埠不能使用負數';

  @override
  String get networkValidationPortZero => '通訊埠不能為 0';

  @override
  String get networkValidationPortInteger => '通訊埠必須為整數';

  @override
  String get networkValidationPortRange => '通訊埠範圍為 1 至 65535';

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
  String get inventoryOwned => '持有';

  @override
  String get inventoryUnowned => '未持有';

  @override
  String unownedShipSummary(int count, int excluded) {
    return '顯示 $count 艘 · 已排除 $excluded 艘';
  }

  @override
  String get unownedShipExcludedLabel => '已排除';

  @override
  String get unownedShipReminderHint => '獲得未勾選的艦娘時，將正常提醒並震動；勾選的艦娘則不會提醒。';

  @override
  String get clearNewShipExclusions => '清除排除';

  @override
  String get resetFilter => '重設篩選';

  @override
  String unownedEquipmentSummary(int count) {
    return '顯示 $count 件未持有裝備';
  }

  @override
  String get otherType => '其他';

  @override
  String newShipFallbackName(int id) {
    return '艦娘 No.$id';
  }

  @override
  String get newShipAlertTitle => '發現未持有艦娘';

  @override
  String newShipAlertBody(String names) {
    return '$names，請不要忘記上鎖';
  }

  @override
  String get acknowledge => '知道了';

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
  String get equipmentOfficialId => '官方ID';

  @override
  String get equipmentInstanceId => '實例ID';

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
  String get chineseTranslation => '中文翻譯';

  @override
  String get searchQuest => '搜尋任務';

  @override
  String get filterQuest => '篩選任務';

  @override
  String get searchQuestHint => '搜尋編號、任務名稱、說明或獎勵；以空格分隔任一關鍵字';

  @override
  String get questAvailable => '未接取';

  @override
  String get questAcceptedOnly => '僅已接取（含待領取）';

  @override
  String get questClaimable => '待領取';

  @override
  String get questInferredCompleted => '推算完成';

  @override
  String get questStateUnknown => '狀態未知';

  @override
  String get questFilterHelp => '已解鎖包含未接取、進行中和待領取；未解鎖包含狀態未知；已完成包含待領取和推算完成。';

  @override
  String get questNoResults => '沒有符合條件的任務';

  @override
  String get questNoResultsHint => '試試調整搜尋內容或清除篩選條件。';

  @override
  String questResultsCount(int count) {
    return '共 $count 個任務';
  }

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

  @override
  String get gameResourceCacheTitle => '遊戲資源本機快取';

  @override
  String get gameResourceCacheDesc => '資源從艦隊 Collection 官方伺服器取得；快取可隨時清除。';

  @override
  String get gameResourceCacheNone => '暫存快取';

  @override
  String get gameResourceCacheNoneDesc =>
      '不預先下載資源；遊玩時按需快取，最多保留 7 天且占用不超過 2 GB，過期或超出上限時將自動清理。';

  @override
  String get gameResourceCacheLight => '輕度快取';

  @override
  String get gameResourceCacheLightDesc => '快取啟動檔案、常用 UI、已持有艦娘立繪與裝備資源。';

  @override
  String get gameResourceCacheFull => '本機快取';

  @override
  String get gameResourceCacheFullDesc =>
      '預先下載基礎資源（約 5.72 GB），無需等待下載完成，可邊下載邊遊玩，不影響遊戲。新內容會在遊玩時自動快取。';

  @override
  String get gameResourceCacheStart => '開始下載';

  @override
  String get gameResourceCachePause => '暫停下載';

  @override
  String get gameResourceCacheResume => '繼續下載';

  @override
  String get gameResourceCacheCheck => '檢查完整性';

  @override
  String get gameResourceCacheRepair => '補齊或修復';

  @override
  String get gameResourceCacheClear => '清除本機快取';

  @override
  String get gameResourceCacheIntegrityComplete => '目前快取完整';

  @override
  String get gameResourceCacheMissing => '缺少';

  @override
  String get gameResourceCacheDamaged => '損壞';

  @override
  String get gameResourceCacheOutdated => '待驗證';

  @override
  String get gameResourceCacheItems => '項';

  @override
  String gameResourceCacheStoredSize(String size) {
    return '已快取 $size';
  }

  @override
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  ) {
    return '缺少 $missing 項 · 損壞 $damaged 項 · 待驗證 $pending 項';
  }

  @override
  String get gameResourceCachePendingRetained => '待驗證資源仍保留在本機，不會自動刪除。';

  @override
  String get gameResourceCacheDownloadConfirmTitle => '確認下載快取？';

  @override
  String get gameResourceCacheDownloadConfirmDesc =>
      '將從官方伺服器批次下載所選模式的資源，可隨時暫停並繼續。';

  @override
  String get gameResourceCacheMobileConfirmDesc =>
      '目前正在使用行動網路。繼續將消耗行動資料，是否允許本次下載？';

  @override
  String get gameResourceCacheWaitingForWifi => '正在等待 Wi-Fi，連線後會自動繼續下載。';

  @override
  String get gameResourceCacheClearConfirmTitle => '清除遊戲資源快取？';

  @override
  String get gameResourceCacheClearConfirmDesc => '將刪除已下載的遊戲資源；模式設定會保留。';

  @override
  String get gameResourceCacheCapacityBlocked =>
      '可用儲存空間不足，或本機遊戲資源快取已達 50 GB 上限。';

  @override
  String get gameResourceCacheActionFailed => '快取操作未完成，請稍後重試。';

  @override
  String get gameResourceCacheUnsupported =>
      '目前的 Android WebView 不支援遊戲資源本機快取，請更新 WebView。';

  @override
  String get gameResourceCacheUnavailable =>
      '本機快取初始化或清理失敗，請檢查儲存空間並重新啟動應用程式。遊戲瀏覽不受影響。';

  @override
  String get gameResourceCacheManifestFailed => '預載資源清單載入失敗，進入遊戲後可重試。';

  @override
  String get confirmGameRefreshTitle => '確定要重新整理遊戲嗎？';

  @override
  String get gameRefreshDialogDescription =>
      '確定要重新整理遊戲嗎？\n\n「重新整理遊戲頁面」與瀏覽器重新整理效果相同。\n「重新載入遊戲」只重新載入遊戲框架部分，通常更快，但可能導致貓襲或網路異常。請自行承擔風險。';

  @override
  String get refreshGamePage => '重新整理遊戲頁面';

  @override
  String get reloadGame => '重新載入遊戲';

  @override
  String get frameRefreshShortcutLabel => '框架重新整理';

  @override
  String get frameRefreshShortcutConfirmTitle => '確定要重新整理遊戲框架嗎？';

  @override
  String get frameRefreshShortcutConfirmDescription =>
      '重新載入遊戲框架通常更快，但可能導致貓襲或網路異常。請自行承擔風險。';

  @override
  String get frameRefreshShortcutSkipConfirmation => '下次不再提醒';

  @override
  String get frameRefreshShortcutConfirmAction => '確認重新整理';

  @override
  String get gameFrameNotFound => '尚未找到遊戲框架，請進入遊戲後重試。';

  @override
  String get gameHtmlWrapNotFound => '尚未找到遊戲本體，請等待頁面載入後重試。';

  @override
  String get gameFrameReloadBlocked => '遊戲框架未能重新載入，請稍後重試。';

  @override
  String get gameFrameReloadUnsupported =>
      '目前裝置的 Android WebView 過舊，不支援向子框架注入指令碼。';

  @override
  String get logbookResourceDrop => '資源掉落';

  @override
  String get logbookItemDrop => '道具掉落';

  @override
  String get logbookResourceNode => '資源節點';

  @override
  String get logbookFriendFormation => '我方陣形';

  @override
  String get logbookEnemyFormation => '敵方陣形';

  @override
  String get logbookAirSuperiority => '制空狀態';

  @override
  String get airSuperiorityParity => '均衡';

  @override
  String get airSuperioritySecured => '確保';

  @override
  String get airSuperiorityAdvantage => '優勢';

  @override
  String get airSuperiorityDisadvantage => '劣勢';

  @override
  String get airSuperiorityLost => '喪失';

  @override
  String get logbookHeavyDamageShips => '大破艦娘';

  @override
  String get gameConnectorTitle => '遊戲連線';

  @override
  String get gameConnectorYahagi => 'Yahagi 連線';

  @override
  String get gameConnectorYahagiDesc => '使用目前 DMM 官方登入入口。';

  @override
  String get gameConnectorOoi => 'OOI 連線（實驗性）';

  @override
  String get gameConnectorOoiDesc => '原樣開啟 ooi.moe 登入頁，由你選擇模式 1、3 或 4。';

  @override
  String get gameConnectorConfirmTitle => '切換遊戲連線？';

  @override
  String get gameConnectorOoiRisk =>
      '帳號憑據將提交給第三方網站 ooi.moe；Yahagi 不讀取、不儲存、不自動填寫帳號或密碼。';

  @override
  String get gameConnectorActiveWarning => '切換會中斷目前遊戲頁面並返回目標登入入口。';

  @override
  String get gameConnectorApplied => '遊戲連線已切換。';

  @override
  String get gameConnectorSaveFailed => '連線選擇儲存失敗，目前連線未變更。';

  @override
  String get gameConnectorNavigationFailed => '連線已儲存，但登入頁面開啟失敗，請重試。';

  @override
  String get kcwikiReportSection => 'KCWiki 資料貢獻';

  @override
  String get kcwikiReportTitle => '協助 KCWiki 收集資料';

  @override
  String get kcwikiReportDisabledDesc => '預設關閉。關閉時不收集、不組包、不連線，也不影響遊戲和本機功能。';

  @override
  String get kcwikiReportEnabledDesc => '已開啟；僅傳送帶路、任務前置、戰鬥、友軍、陸航／空襲和改修資料。';

  @override
  String get kcwikiReportConfirmTitle => '開啟 KCWiki 資料貢獻？';

  @override
  String get kcwikiReportConfirmDesc =>
      '開啟後，應用程式會透過已設定的 HTTPS 位址傳送帶路、任務前置、戰鬥、友軍、陸航／空襲和改修記錄。不傳送登入權杖、Cookie 或請求標頭；上傳失敗不會阻塞遊戲功能。';

  @override
  String get kcwikiReportUnavailable => '目前版本未設定安全的 HTTPS 回報位址，無法開啟資料貢獻。';

  @override
  String get kcwikiReportEnable => '自願開啟';

  @override
  String get kcwikiReportSaveFailed => 'KCWiki 資料貢獻設定儲存失敗，請重試。';

  @override
  String kcwikiReportCaptureFailed(String error) {
    return 'KCWiki 資料收集切換失敗：$error';
  }

  @override
  String get kcwikiReportWaiting => '已開啟，正在等待可貢獻的資料。';

  @override
  String kcwikiReportProcessing(String module, String time) {
    return '正在上傳：$module · $time';
  }

  @override
  String kcwikiReportParseRecovered(String time) {
    return '大型資料解析逾時已恢復，後續資料已繼續處理 · $time';
  }

  @override
  String kcwikiReportFailureHttp(String status) {
    return 'HTTP $status';
  }

  @override
  String get kcwikiReportFailureTimeout => '連線逾時';

  @override
  String get kcwikiReportFailureNetwork => '網路失敗';

  @override
  String get kcwikiReportFailureBodyTooLarge => '資料超過單次上限';

  @override
  String get kcwikiReportFailureQueueFull => '本機等待佇列已滿';

  @override
  String get kcwikiReportFailureLocal => '本機處理失敗';

  @override
  String kcwikiReportCounters(int succeeded, int failed, int dropped) {
    return '成功 $succeeded · 失敗 $failed · 丟棄 $dropped';
  }

  @override
  String kcwikiReportLastSuccess(
    String module,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '最近上傳成功：$module · $time · 成功 $succeeded · 失敗 $failed · 丟棄 $dropped';
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
    return '最近上傳失敗：$module（$status）· $time · 成功 $succeeded · 失敗 $failed · 丟棄 $dropped';
  }

  @override
  String get landBaseBrief => '陸基簡報';

  @override
  String get landBaseNoData => '無資料';

  @override
  String landBaseAreaFallback(int areaId) {
    return '海域 $areaId';
  }

  @override
  String landBaseUnitCount(int count) {
    return '$count 支航空隊';
  }

  @override
  String get landBaseRange => '航程';

  @override
  String get landBaseActionSortie => '出擊';

  @override
  String get landBaseActionAirDefense => '防空';

  @override
  String get landBaseActionRest => '休息';

  @override
  String get landBaseActionRetreat => '退避';

  @override
  String get landBaseMissingPlanes => '缺機';

  @override
  String get landBaseRelocating => '配置轉換中';

  @override
  String get senkaInfoTab => '戰果資訊';

  @override
  String get senkaCalendarTab => '戰果日曆';

  @override
  String get senkaCalculatorTab => '戰果計算';

  @override
  String get senkaSaveFailedWarning => '戰果資料儲存失敗，重新啟動後可能遺失';

  @override
  String get senkaLatestRanking => '最新排名戰果';

  @override
  String get senkaTarget => '目標戰果';

  @override
  String senkaGap(String value) {
    return '距離目標還差 $value 戰果';
  }

  @override
  String senkaOver(String value) {
    return '已超出 $value 戰果';
  }

  @override
  String get senkaPlannedEo => '計畫 EO';

  @override
  String get senkaPlannedQuest => '計畫任務';

  @override
  String get senkaDailyRequired => '每日所需';

  @override
  String get senkaTodayRemaining => '今日剩餘';

  @override
  String get senkaUnsettledDelta => '結算後增量';

  @override
  String get senkaAvailableDaysIncludingToday => '可用天數（含今日）';

  @override
  String get senkaProjected => '預計戰果';

  @override
  String get senkaUnit => '戰果';

  @override
  String senkaInputTitle(String label) {
    return '填寫$label';
  }

  @override
  String get senkaInvalidNumber => '請輸入有效數字';

  @override
  String get senkaPlannedEoReward => '計畫 EO 戰果獎勵';

  @override
  String get senkaPlannedQuestReward => '計畫任務戰果獎勵';

  @override
  String get senkaTotal => '合計';

  @override
  String get senkaEoRewards => 'EO 戰果獎勵';

  @override
  String get senkaQuarterlyQuests => '季度戰果任務';

  @override
  String get senkaAnnualQuests => '年度戰果任務';

  @override
  String get senkaOneTimeQuests => '單次戰果任務';

  @override
  String get senkaRewardLegend =>
      '黃色＋✕：計畫擱置，不計入預計戰果；綠色＋✓：計畫完成，計入預計戰果；灰色＋○：已經完成，不再重複計算。';

  @override
  String get senkaRewardDeferred => '計畫擱置';

  @override
  String get senkaRewardPlanned => '計畫完成（計入預計）';

  @override
  String get senkaRewardCompleted => '已完成';

  @override
  String senkaCalendarTitle(int year, int month) {
    return '$year年$month月戰果日曆';
  }

  @override
  String senkaCalendarSummary(String recorded, String base) {
    return '本月已記錄 $recorded · 本月素戰果 $base';
  }

  @override
  String get senkaExperience => '經驗';

  @override
  String get senkaQuest => '任務';

  @override
  String senkaCalendarCell(int year, int month, int day, String value) {
    return '$year年$month月$day日，戰果$value';
  }

  @override
  String get senkaServer => '所在伺服器';

  @override
  String get senkaRanking => '戰果排名';

  @override
  String get senkaRank => '排名';

  @override
  String senkaUpdated(String time) {
    return '更新：$time';
  }

  @override
  String get senkaOrder => '順位';

  @override
  String get senkaChange => '變化';

  @override
  String get senkaCurrent => '目前';

  @override
  String get senkaSortieStats => '出擊海域統計';

  @override
  String get senkaLatestRecord => '最近記錄';

  @override
  String get senkaMonthSorties => '本月出擊';

  @override
  String get senkaBossArrivals => 'Boss 到達';

  @override
  String get senkaSWins => 'S 勝';

  @override
  String get senkaMonth => '本月';

  @override
  String get senkaToday => '今日';

  @override
  String get senkaShowHiddenAreas => '顯示隱藏海域';

  @override
  String get senkaShowHidden => '顯示已隱藏';

  @override
  String get senkaArea => '海域';

  @override
  String get senkaBoss => 'Boss';

  @override
  String get senkaSorties => '出擊';

  @override
  String get senkaResult => 'S / A';

  @override
  String get senkaActions => '操作';

  @override
  String senkaFavoriteArea(String map) {
    return '收藏海域 $map';
  }

  @override
  String senkaHideArea(String map) {
    return '隱藏海域 $map';
  }

  @override
  String get senkaUnknownServer => '未知伺服器';

  @override
  String get toolbox => '工具箱';

  @override
  String get fleetExport => '匯出資料';

  @override
  String get otherTools => '其他';

  @override
  String get noro6 => 'noro6';

  @override
  String get jervis => 'Jervis';

  @override
  String get exportToNoro6 => '匯出至 noro6';

  @override
  String get exportToNoro6Mirror => '匯出至 noro6（中國鏡像）';

  @override
  String get exportToJervis => '匯出至 Jervis';

  @override
  String get eventLandBasesOnly => '僅匯出活動海域陸航';

  @override
  String get landBaseExportLimitHint =>
      'DeckBuilder 每次最多支援 3 隊；關閉篩選時依擷取順序匯出前 3 隊。';

  @override
  String get fleetExportText => '艦隊匯出文字';

  @override
  String get deckBuilderV4 => 'DeckBuilder v4';

  @override
  String get refreshExportText => '重新整理';

  @override
  String get copyExportText => '複製文字';

  @override
  String get openInSystemBrowser => '使用系統預設瀏覽器開啟';

  @override
  String get otherToolsComingSoon => '其他功能陸續開發中';

  @override
  String get otherToolsHint => '後續輔助工具會集中放在這裡。';

  @override
  String get waitingForPortData => '等待母港資料';

  @override
  String get externalFleetToolOpenFailed => '無法開啟外部艦隊工具，請確認是否已安裝瀏覽器。';

  @override
  String get fleetExportCopied => '艦隊匯出文字已複製。';

  @override
  String get fleetExportCopyFailed => '複製失敗，請稍後再試。';

  @override
  String equipmentCompatibilitySummary(int owned, int all) {
    return '可裝備：持有 $owned／全部 $all';
  }

  @override
  String equipmentCompatibilityOwnedTab(int count) {
    return '持有艦娘 $count';
  }

  @override
  String equipmentCompatibilityAllTab(int count) {
    return '全部艦娘 $count';
  }

  @override
  String equipmentCompatibilityOwnedCompact(int count) {
    return '持有 $count';
  }

  @override
  String equipmentCompatibilityAllCompact(int count) {
    return '全部 $count';
  }

  @override
  String get equipmentCompatibilitySelectShipType => '選擇艦種';

  @override
  String get equipmentCompatibilitySearchHint => '搜尋艦娘';

  @override
  String get equipmentCompatibilityAllSlots => '所有欄位';

  @override
  String get equipmentCompatibilityRegularSlot => '一般裝備欄';

  @override
  String get equipmentCompatibilityExpansionSlot => '增設裝備欄';

  @override
  String get equipmentCompatibilityBothSlots => '一般欄＋增設欄';

  @override
  String equipmentCompatibilityExpansionRequirement(int level) {
    return '增設欄需要 ★+$level';
  }

  @override
  String equipmentCompatibilityOwnedLevels(String levels) {
    return '等級 $levels';
  }

  @override
  String equipmentCompatibilityFleetNumbers(String numbers) {
    return '第 $numbers 艦隊';
  }

  @override
  String get equipmentCompatibilityEmpty => '沒有符合條件的艦娘';

  @override
  String equipmentCompatibilityOfficialId(int id) {
    return '裝備 ID $id';
  }

  @override
  String equipmentCompatibilityOwnedCount(int count) {
    return '持有數量 $count';
  }

  @override
  String equipmentCompatibilityRegularCount(int count) {
    return '一般欄 $count';
  }

  @override
  String equipmentCompatibilityExpansionCount(int count) {
    return '增設欄 $count';
  }

  @override
  String get equipmentCompatibilitySource => '規則來源：遊戲官方主資料';

  @override
  String get equipmentCompatibilityRulesWaiting => '正在等待裝備規則資料更新';

  @override
  String get equipmentCompatibilityEmptyOwned => '目前沒有持有可裝備的艦娘';

  @override
  String get equipmentCompatibilityEmptyAll => '找不到可裝備的艦娘形態';

  @override
  String equipmentCompatibilityCategory(String category) {
    return '分類：$category';
  }

  @override
  String equipmentCompatibilityShipClassId(int id) {
    return '艦級 #$id';
  }

  @override
  String get shipEquipmentCompatibilitySelectCategory => '選擇裝備分類';

  @override
  String get shipEquipmentCompatibilitySearchTitle => '搜尋裝備';

  @override
  String get shipEquipmentCompatibilitySearchHint => '輸入裝備名稱';

  @override
  String shipEquipmentCompatibilityOwnedCount(int count) {
    return '持有 X$count';
  }

  @override
  String get shipEquipmentCompatibilityEmpty => '找不到可裝備的裝備';

  @override
  String get equipmentDevelopment => '裝備開發';

  @override
  String get development => '開發';

  @override
  String get developmentCommandTitle => '開發指揮台';

  @override
  String get developmentWorkbenchTitle => '開發工作台';

  @override
  String get developmentCalculator => '開發計算器';

  @override
  String get developmentFormula => '開發公式';

  @override
  String get developmentOutputProbability => '出貨機率';

  @override
  String get developmentFinalProbability => '最終機率';

  @override
  String get developmentAvailableRecipes => '可用公式';

  @override
  String get developmentPoolType => '池類型';

  @override
  String get developmentSelectSecretary => '選擇秘書艦類型';

  @override
  String get developmentOtherSecretaryGroup => '其他';

  @override
  String get developmentEquipmentType => '類型';

  @override
  String get developmentSecretary => '秘書艦';

  @override
  String get developmentFuelShort => '油';

  @override
  String get developmentAmmoShort => '彈';

  @override
  String get developmentSteelShort => '鋼';

  @override
  String get developmentBauxiteShort => '鋁';

  @override
  String get developmentOutputRate => '出貨率';

  @override
  String get developmentEquipment => '裝備';

  @override
  String get developmentCurrentFlagship => '目前旗艦';

  @override
  String get developmentUseFlagship => '使用目前旗艦';

  @override
  String get developmentFlagshipUnsupported => '目前旗艦沒有可用的開發池，已保留原選擇';

  @override
  String get developmentSelectPool => '秘書艦類型';

  @override
  String get developmentCurrentRecipe => '目前配方';

  @override
  String get developmentTargetEquipment => '目標裝備';

  @override
  String get developmentChooseTarget => '選擇目標裝備';

  @override
  String get developmentSearchEquipment => '搜尋裝備';

  @override
  String get developmentSearchHint => '輸入裝備名稱或 ID';

  @override
  String get developmentAllTypes => '全部類型';

  @override
  String get developmentTargetDrops => '目標出貨';

  @override
  String get developmentOtherDrops => '其他出貨';

  @override
  String get developmentInsufficient => '資源不足';

  @override
  String get developmentReplaced => '被替換出貨';

  @override
  String get developmentRecommendations => '推薦配方';

  @override
  String get developmentNoTargets => '選擇目標裝備後顯示推薦配方';

  @override
  String get developmentNoResults => '沒有能同時開發所有目標的配方';

  @override
  String get developmentTargetRate => '目標率';

  @override
  String get developmentFailureRate => '失敗率';

  @override
  String get developmentTotalResources => '總資源';

  @override
  String get developmentApplyRecipe => '回填配方';

  @override
  String get developmentDataError => '裝備開發資料載入失敗';

  @override
  String get developmentRetry => '重試';

  @override
  String developmentSelectedCount(int count) {
    return '已選 $count 件';
  }

  @override
  String get developmentPoolBauxite => '鋁土系';

  @override
  String get developmentPoolAmmunition => '彈藥系';

  @override
  String get developmentPoolFuelSteel => '油鋼系';

  @override
  String get battlePredictionUnconfirmed => '資料未確認：血量與預測僅供參考，請以遊戲畫面為準。';

  @override
  String get mouseWheelCompatibility => '外接滑鼠滾輪相容';

  @override
  String get mouseWheelCompatibilityDescription =>
      '使用外接滑鼠時，若遊戲內滾輪無反應，可嘗試開啟。立即生效，保留滑鼠點擊和手指觸控。';

  @override
  String get mouseWheelCompatibilitySaveFailed => '設定儲存失敗，請重試。';

  @override
  String get hdMode => 'HD 模式';

  @override
  String get hdModeDescription =>
      '開啟後，使用專為大螢幕裝置最佳化的 UI 配置（建議 8 吋以上裝置）。非大螢幕裝置強行開啟可能導致介面顯示異常、版面溢出或應用程式當機等問題。';

  @override
  String get hdBottomLayout => 'HD 下欄配置';

  @override
  String get hdSplit => '兩個 1×1';

  @override
  String get hdWide => '一個 1×2';

  @override
  String get hdLeftModule => '左側模組';

  @override
  String get hdRightModule => '右側模組';

  @override
  String get hdWideModule => '整寬模組';

  @override
  String get hdCustomize => '自訂配置';

  @override
  String get hdEditHint => '長按拖曳把手排序或移入下欄；拖到既有模組上交換位置。勾選顯示，取消勾選隱藏。';

  @override
  String get hdHalfWidth => '半寬 1×1';

  @override
  String get hdFullWidth => '全寬 1×2';

  @override
  String get hdDropArea => '可放置功能區';

  @override
  String get workspaceMenuPosition => '選單列位置';

  @override
  String get workspaceMenuPositionDesc => '上方位於遊戲畫面下方。';

  @override
  String get menuPositionTop => '上';

  @override
  String get menuPositionBottom => '下';

  @override
  String get menuPositionLeft => '左';

  @override
  String get menuPositionRight => '右';

  @override
  String get topNoticeSectionTitle => '頂欄消息通知';

  @override
  String get topNoticeEnabledTitle => '頂欄通知';

  @override
  String get topNoticeEnabledSubtitle => '在頂欄「ヤハギ」右側顯示開發、改修、出擊檢查與任務完成提示';

  @override
  String get topNoticeDurationTitle => '提示停留時間';

  @override
  String get topNoticeDurationSubtitle => '消息氣泡彈出後無操作自動收起的時長';

  @override
  String get topNoticeDuration5s => '5 秒 (默認)';

  @override
  String get topNoticeDuration10s => '10 秒';

  @override
  String get topNoticeDuration15s => '15 秒';

  @override
  String questCompletionSingleNotice(String title) {
    return '任務達成：$title';
  }

  @override
  String questCompletionMultiNotice(int count) {
    return '$count 個任務已達成，請前往任務介面';
  }

  @override
  String questPendingConfirmationSingleNotice(String title) {
    return '任務目標已達成（待遊戲確認）：$title';
  }

  @override
  String questPendingConfirmationMultiNotice(int count) {
    return '$count 個任務目標已達成（待遊戲確認）';
  }

  @override
  String noticeDevSuccess(String name) {
    return '$name 開發成功';
  }

  @override
  String get noticeDevFailed => '裝備開發失敗';

  @override
  String get noticeDevFailedPenguin => '裝備開發失敗';

  @override
  String get noticeDevSlotFailed => '開發失敗';

  @override
  String get noticeDevDefaultName => '新裝備';

  @override
  String get noticeEquipImproveSuccess => '裝備改修成功';

  @override
  String get noticeEquipImproveFailed => '裝備改修失敗';

  @override
  String get noticeModFailed => '近代化改修失敗';

  @override
  String get noticeModSuccess => '近代化改修成功';

  @override
  String noticeModSuccessDetail(String stats) {
    return '改修成功：$stats';
  }

  @override
  String get noticeModSuccessMaxCap => '改修成功 (屬性已達上限)';

  @override
  String get statFirepower => '火力';

  @override
  String get statTorpedo => '雷裝';

  @override
  String get statAntiAir => '對空';

  @override
  String get statArmor => '裝甲';

  @override
  String get statLuck => '運';

  @override
  String get statHp => '耐久';

  @override
  String get statAsw => '對潛';

  @override
  String noticeMarriageLuck(String arrow, int delta, int remaining) {
    return '誓約運提升：運 $arrow +$delta / +$remaining';
  }

  @override
  String noticeMarriageLuckMax(String arrow, int delta) {
    return '誓約運提升：運 $arrow +$delta / MAX';
  }

  @override
  String noticePracticeExp(int sExp, int aExp) {
    return '演習經驗（約）：S勝 $sExp · A勝 $aExp';
  }

  @override
  String noticePracticeExpCtBonus(int sExp, int aExp, String bonus) {
    return '演習經驗（約）：S勝 $sExp · A勝 $aExp (練巡 +$bonus)';
  }

  @override
  String get noticeSortieShipFull => '母港船位已滿！出擊將無法獲得新艦娘';

  @override
  String noticeSortieShipLow(int count) {
    return '船位僅剩 $count 個，請注意母港容量';
  }

  @override
  String get noticeSortieItemFull => '裝備槽已滿！出擊將無法獲得新裝備';

  @override
  String noticeSortieItemLow(int count) {
    return '裝備槽僅剩 $count 個，請注意母港容量';
  }

  @override
  String get noticeSortieShipAndItemFull => '母港船位與裝備槽已滿！出擊將無法獲得新艦娘與裝備';

  @override
  String noticeSortieShipAndItemLow(int shipCount, int itemCount) {
    return '船位僅剩 $shipCount 個 · 裝備槽僅剩 $itemCount 個，請注意母港容量';
  }

  @override
  String get noticeSortieExpansionSlotUnused => '艦隊中有未使用的補強增設插槽';

  @override
  String noticePreSortieCheckFailed(String reasons) {
    return '出擊前檢查未通過：$reasons';
  }

  @override
  String get noticeSortieReasonUnresupplied => '未補滿補給';

  @override
  String get noticeSortieReasonFatigue => '艦娘疲勞 (黃臉/紅臉)';

  @override
  String get noticeSortieReasonMainSlot => '主裝備槽未裝滿';

  @override
  String get noticeSortieReasonExpansionSlot => '補強增設插槽閒置';

  @override
  String get lockUi => '鎖定介面';

  @override
  String get unlockUi => '解鎖介面';

  @override
  String get uiLockedToast => '介面已鎖定，版面自訂已禁用，功能切換不受影響';

  @override
  String get uiUnlockedToast => '介面已解鎖';

  @override
  String get uiLockTitle => '鎖定介面配置';

  @override
  String get uiLockDesc => '鎖定後禁止長按卡片與頂欄資源進入自訂編輯，並禁止拖曳導覽列排序；功能頁仍可正常切換';

  @override
  String get filterVisibleItems => '篩選顯示項目';

  @override
  String get selectHeaderVisibleItems => '選擇頂部顯示項目';

  @override
  String get expCalculator => '經驗計算';

  @override
  String get expCalcShip => '艦娘';

  @override
  String get expCalcCurrentLevel => '現在等級';

  @override
  String get expCalcTargetLevel => '目標等級';

  @override
  String get expCalcMap => '海域';

  @override
  String get expCalcRank => '評價';

  @override
  String get expCalcBaseExp => '基本經驗值';

  @override
  String get expCalcFlagship => '旗艦';

  @override
  String get expCalcMvp => 'MVP';

  @override
  String get expCalcMapExp => '海域經驗值';

  @override
  String get expCalcRemainExp => '剩餘經驗值';

  @override
  String get expCalcBattle => '戰鬥';

  @override
  String get expCalcEmptyTrackList => '暫無練級追蹤計劃，點擊上方 ＋ 新增';

  @override
  String get expCalcBaseExpHelpTitle => '常用海域基本經驗參考';

  @override
  String get expCalcTrackAdded => '已新增至經驗追蹤清單';

  @override
  String get expCalcTrackDeleted => '已從經驗追蹤清單移除';

  @override
  String get expCalcTrackLoadFailed => '追蹤清單讀取失敗，點擊重試';

  @override
  String get expCalcTrackSaveFailed => '追蹤清單儲存失敗，請重試';

  @override
  String get expCalcFreeMode => '自訂計算（無艦娘）';

  @override
  String get expCalcAddNode => '增加戰鬥點位 (連戰累計加算)';

  @override
  String get expCalcRemoveNode => '移除點';

  @override
  String get expCalcRouteTotal => '整趟總收益';

  @override
  String get expCalcNodePoint => '點位';

  @override
  String get expCalcRouteSummary => '出擊海域路線';

  @override
  String get expCalcAddTrack => '加入動態追蹤表格';

  @override
  String get expCalcCompletedTag => '0 次 (已達成)';

  @override
  String get expCalcCardView => '卡片';

  @override
  String get expCalcTableView => '表格';

  @override
  String get expCalcTrackListTitle => '練級追蹤列表';

  @override
  String get expCalcAutoSyncHint => '母港數據變動時自動更新剩餘經驗與場次';

  @override
  String get expCalcDelete => '刪除';

  @override
  String get expCalcStep1Title => '階段 1 · 艦娘與等級目標';

  @override
  String get expCalcStep2Title => '階段 2 · 出擊海域點位與戰術路線編排';

  @override
  String get expCalcResultHudTitle => '出擊路線綜合推演結算';

  @override
  String get expCalcTargetGapLabel => '升級經驗缺口';

  @override
  String get expCalcTargetAlignHint => '目標經驗自動與經驗表對齊';

  @override
  String get expCalcRouteSummaryPrefix => '目前路線共計';

  @override
  String get expCalcCombatNodesSuffix => '個戰鬥點位';

  @override
  String get expCalcAccumulatedExpLabel => '累計經驗';

  @override
  String get customFontTitle => '介面字型';

  @override
  String get customFontDescription => '匯入喜歡的字型，預覽後套用。支援 TTF、OTF，最大 32 MB。';

  @override
  String get customFontDefault => '預設字型（系統字級）';

  @override
  String get customFontImport => '匯入字型';

  @override
  String get customFontRestore => '恢復預設';

  @override
  String get customFontPreviewTitle => '字型預覽';

  @override
  String get customFontApply => '套用字型';

  @override
  String get customFontPreviewSample => '艦隊資訊 · 出擊紀錄 · 畫面設定';

  @override
  String get customFontPreviewNote => '確認套用後將用於用戶端介面，重新啟動後仍會保留。';

  @override
  String get customFontImportFailed => '無法匯入字型，請選擇有效的 TTF 或 OTF 檔案。';

  @override
  String get customFontSaveFailed => '字型設定儲存失敗，請重試。';

  @override
  String get customFontUnsupported => '目前平台暫不支援字型匯入。';

  @override
  String get customFontTooLarge => '字型檔案不能超過 32 MB。';

  @override
  String get customFontLoadLimit =>
      '為控制記憶體用量，本次執行已達字型切換上限。請重新啟動應用程式後再套用新字型，仍可繼續預覽。';

  @override
  String get customFontPreviewFailed => '字型預覽產生失敗，請重試。';

  @override
  String get customFontPreviewRetry => '重新預覽';

  @override
  String get browserMenuMute => '靜音';

  @override
  String get browserMenuUnmute => '開聲音';

  @override
  String get browserMenuScreenshot => '截圖';

  @override
  String get browserMenuFit => '修復顯示';

  @override
  String get browserMenuFullscreen => '全螢幕';

  @override
  String get browserMenuHome => '主頁';

  @override
  String get browserMenuDismissHint => '點擊空白處關閉';

  @override
  String summaryFleetHeavy(int count) {
    return '大破 $count';
  }

  @override
  String summaryFleetMedium(int count) {
    return '中破 $count';
  }

  @override
  String summaryFleetMinMorale(int value) {
    return '最低疲勞 $value';
  }

  @override
  String summaryExpedition(int active, String time) {
    return '進行中 $active/3 · 最近 $time';
  }

  @override
  String summaryRepair(int busy, int total, String time) {
    return '使用中 $busy/$total · 最近 $time';
  }

  @override
  String summaryRepairBusy(int busy, int total) {
    return '使用中 $busy/$total';
  }

  @override
  String summaryConstruction(int done, int building) {
    return '完成 $done · 建造中 $building';
  }

  @override
  String summaryQuests(int done, int active) {
    return '可完成 $done · 進行中 $active';
  }

  @override
  String summaryLandBase(int sortie, int defense) {
    return '出擊 $sortie · 防空 $defense';
  }

  @override
  String summaryWarnings(int count) {
    return '警告 $count';
  }

  @override
  String get questQueryTitle => '搜尋與篩選任務';

  @override
  String questQueryScope(String scope) {
    return '查詢範圍：$scope';
  }

  @override
  String questApplyQuery(int count) {
    return '顯示 $count 個任務';
  }

  @override
  String get questAccepted => '已接取';

  @override
  String get questConditionsAndProgress => '條件與進度';

  @override
  String get questSelectTask => '選擇任務，查看完成條件';

  @override
  String get questBackToList => '返回任務列表';

  @override
  String get questReturnToTarget => '回到目標任務';

  @override
  String get questNoPrerequisites => '資料未列出直接前置任務';

  @override
  String get questNoSuccessors => '資料未列出後續任務';

  @override
  String get japaneseOriginal => '日文原文';

  @override
  String questQueryActive(int count) {
    return '$count 項查詢條件已生效';
  }

  @override
  String get settingsTabRuntime => '遊戲運行';

  @override
  String get settingsGroupAppearance => '基本外觀';

  @override
  String get settingsGroupScreenAdaptation => '螢幕適配';

  @override
  String get settingsGroupLayoutPosition => '布局與位置';

  @override
  String get settingsGroupContentCustomization => '內容自訂';

  @override
  String get settingsGroupLayoutManagement => '布局管理';

  @override
  String get settingsOtherModuleDisplay => '其他模組顯示';

  @override
  String get settingsEditInformationLayout => '資訊面板布局編輯';

  @override
  String get settingsEditHdLayout => 'HD布局編輯';

  @override
  String get settingsResetMenuOrder => '還原選單列順序';

  @override
  String get settingsResetCardOrder => '還原功能區卡片順序';

  @override
  String get settingsGroupPerformanceRendering => '效能與畫面';

  @override
  String get settingsGroupSubtitles => '字幕';

  @override
  String get settingsGroupScreenBackground => '保持執行';

  @override
  String get settingsGroupInformationCapture => '資訊讀取';

  @override
  String get settingsFrameRefreshConfirm => '框架重新整理前確認';

  @override
  String get settingsFrameRefreshConfirmDescription => '從頂欄重新整理遊戲框架前顯示確認對話框。';

  @override
  String get settingsFrameRefreshConfirmSaveFailed => '框架重新整理確認設定儲存失敗，請重試。';

  @override
  String get settingsGroupDebuff => '解謎與削甲';

  @override
  String get settingsGroupShipStatusFeedback => '艦娘狀態回饋';

  @override
  String get settingsGroupSystemNotifications => '系統通知';

  @override
  String get settingsEnableSystemNotifications => '啟用系統通知';

  @override
  String get settingsSystemNotificationSound => '系統通知提示音';

  @override
  String get settingsSystemNotificationVibration => '系統通知震動';

  @override
  String get settingsGroupDataUpdates => '資料更新';

  @override
  String get settingsGroupDataSharingPrivacy => '資料分享與隱私';

  @override
  String get settingsGroupClearLocalData => '清理本機資料';

  @override
  String get settingsGroupAccount => '帳號操作';

  @override
  String get settingsGroupDiagnosticsSupport => '診斷與支援';

  @override
  String get settingsStatusEnabled => '已開啟';

  @override
  String get settingsStatusDisabled => '已關閉';

  @override
  String get settingsFleetDisplayStandard => '一般艦隊卡片';

  @override
  String get settingsFleetDisplayHd => 'HD 雙欄艦隊卡片';

  @override
  String get briefingDisplayTitle => '簡報展示方式';

  @override
  String get briefingDisplayDescription =>
      '摺疊式可同時展開多個模組；分頁式透過頂部分頁切換模組。HD 模式下無效。';

  @override
  String get briefingDisplayAccordion => '摺疊式';

  @override
  String get briefingDisplayTabs => '分頁式';

  @override
  String get briefingTabForecast => '先知';

  @override
  String get briefingTabFleet => '編隊';

  @override
  String get briefingTabLandBase => '陸基';

  @override
  String get briefingTabExpedition => '遠征';

  @override
  String get briefingTabRepair => '入渠';

  @override
  String get briefingTabConstruction => '建造';

  @override
  String get briefingTabQuests => '任務';

  @override
  String get briefingTabPreSortie => '檢查';
}
