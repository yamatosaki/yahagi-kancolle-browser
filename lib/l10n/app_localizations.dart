import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @questCompletionNotice.
  ///
  /// In zh, this message translates to:
  /// **'有任务已完成'**
  String get questCompletionNotice;

  /// No description provided for @questCompletionCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务已完成，待领取'**
  String questCompletionCount(int count);

  /// No description provided for @resourceTrend90d.
  ///
  /// In zh, this message translates to:
  /// **'90天'**
  String get resourceTrend90d;

  /// No description provided for @resourceTrendInventoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'库存趋势'**
  String get resourceTrendInventoryTitle;

  /// No description provided for @resourceTrendCustomize.
  ///
  /// In zh, this message translates to:
  /// **'显示资源'**
  String get resourceTrendCustomize;

  /// No description provided for @resourceTrendAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一项资源'**
  String get resourceTrendAtLeastOne;

  /// No description provided for @resourceTrendBuildMaterial.
  ///
  /// In zh, this message translates to:
  /// **'高速建造材'**
  String get resourceTrendBuildMaterial;

  /// No description provided for @resourceTrendRepairMaterial.
  ///
  /// In zh, this message translates to:
  /// **'高速修复材'**
  String get resourceTrendRepairMaterial;

  /// No description provided for @resourceTrendDevMaterial.
  ///
  /// In zh, this message translates to:
  /// **'开发资材'**
  String get resourceTrendDevMaterial;

  /// No description provided for @resourceTrendImproveMaterial.
  ///
  /// In zh, this message translates to:
  /// **'改修资材'**
  String get resourceTrendImproveMaterial;

  /// No description provided for @resourceTrendLatest.
  ///
  /// In zh, this message translates to:
  /// **'最新存量'**
  String get resourceTrendLatest;

  /// No description provided for @resourceTrendChange.
  ///
  /// In zh, this message translates to:
  /// **'区间增减'**
  String get resourceTrendChange;

  /// No description provided for @resourceTrendBaseline.
  ///
  /// In zh, this message translates to:
  /// **'增减基准：{time} JST'**
  String resourceTrendBaseline(String time);

  /// No description provided for @resourceTrendObserved.
  ///
  /// In zh, this message translates to:
  /// **'最后记录：{time} JST'**
  String resourceTrendObserved(String time);

  /// No description provided for @resourceTrendPartial.
  ///
  /// In zh, this message translates to:
  /// **'缺少期初记录，按首条记录计算增减'**
  String get resourceTrendPartial;

  /// No description provided for @resourceTrendInsufficient.
  ///
  /// In zh, this message translates to:
  /// **'可比较的记录不足'**
  String get resourceTrendInsufficient;

  /// No description provided for @resourceTrendNoPeriodData.
  ///
  /// In zh, this message translates to:
  /// **'此时段暂无资源记录'**
  String get resourceTrendNoPeriodData;

  /// No description provided for @resourceTrendLoadError.
  ///
  /// In zh, this message translates to:
  /// **'资源记录加载失败'**
  String get resourceTrendLoadError;

  /// No description provided for @resourceTrendSaveError.
  ///
  /// In zh, this message translates to:
  /// **'资源显示设置未能保存'**
  String get resourceTrendSaveError;

  /// No description provided for @resourceTrendInspect.
  ///
  /// In zh, this message translates to:
  /// **'滑动查看'**
  String get resourceTrendInspect;

  /// No description provided for @resourceTrendExpand.
  ///
  /// In zh, this message translates to:
  /// **'放大图表'**
  String get resourceTrendExpand;

  /// No description provided for @resourceTrendSampled.
  ///
  /// In zh, this message translates to:
  /// **'长时段图表已保留峰谷，读数对应实际采样记录'**
  String get resourceTrendSampled;

  /// No description provided for @resourceTrendLocalScale.
  ///
  /// In zh, this message translates to:
  /// **'纵轴随存量范围缩放'**
  String get resourceTrendLocalScale;

  /// No description provided for @resourceTrendBaseShort.
  ///
  /// In zh, this message translates to:
  /// **'基准'**
  String get resourceTrendBaseShort;

  /// No description provided for @diagnosticLoggingSection.
  ///
  /// In zh, this message translates to:
  /// **'客户端诊断日志'**
  String get diagnosticLoggingSection;

  /// No description provided for @diagnosticLoggingTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录客户端诊断日志'**
  String get diagnosticLoggingTitle;

  /// No description provided for @diagnosticLoggingDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅记录性能和错误摘要，不包含账号、密码或登录凭据'**
  String get diagnosticLoggingDesc;

  /// No description provided for @diagnosticPrivacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私安全诊断'**
  String get diagnosticPrivacyTitle;

  /// No description provided for @diagnosticPrivacyDesc.
  ///
  /// In zh, this message translates to:
  /// **'导出前会再次检查内容。日志不记录账号、密码、Cookie、令牌、请求正文、响应正文、聊天内容或截图，也不会自动上传。'**
  String get diagnosticPrivacyDesc;

  /// No description provided for @diagnosticStatusEnabled.
  ///
  /// In zh, this message translates to:
  /// **'正在记录'**
  String get diagnosticStatusEnabled;

  /// No description provided for @diagnosticStatusDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已停止记录'**
  String get diagnosticStatusDisabled;

  /// No description provided for @diagnosticStorageUsage.
  ///
  /// In zh, this message translates to:
  /// **'本地日志占用：{size}'**
  String diagnosticStorageUsage(String size);

  /// No description provided for @exportDiagnosticFile.
  ///
  /// In zh, this message translates to:
  /// **'导出诊断文件'**
  String get exportDiagnosticFile;

  /// No description provided for @saveDiagnosticFile.
  ///
  /// In zh, this message translates to:
  /// **'保存到本地'**
  String get saveDiagnosticFile;

  /// No description provided for @shareDiagnosticFile.
  ///
  /// In zh, this message translates to:
  /// **'分享诊断文件'**
  String get shareDiagnosticFile;

  /// No description provided for @diagnosticSaveConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存诊断文件？'**
  String get diagnosticSaveConfirmTitle;

  /// No description provided for @diagnosticSaveConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'将生成一个经过隐私检查的 JSON 文件。接下来只需选择保存文件夹，文件名由客户端自动生成且不可修改。'**
  String get diagnosticSaveConfirmDesc;

  /// No description provided for @diagnosticSaveAction.
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get diagnosticSaveAction;

  /// No description provided for @diagnosticSaveSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已保存：{fileName}'**
  String diagnosticSaveSucceeded(String fileName);

  /// No description provided for @diagnosticSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'诊断文件保存失败'**
  String get diagnosticSaveFailed;

  /// No description provided for @diagnosticShareConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'分享诊断文件？'**
  String get diagnosticShareConfirmTitle;

  /// No description provided for @diagnosticShareConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'将生成一个经过隐私检查的 JSON 文件，并打开系统分享面板。请在发送前自行确认接收方。'**
  String get diagnosticShareConfirmDesc;

  /// No description provided for @diagnosticShareAction.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get diagnosticShareAction;

  /// No description provided for @diagnosticShareFailed.
  ///
  /// In zh, this message translates to:
  /// **'诊断文件分享失败'**
  String get diagnosticShareFailed;

  /// No description provided for @clearDiagnosticData.
  ///
  /// In zh, this message translates to:
  /// **'清除诊断日志'**
  String get clearDiagnosticData;

  /// No description provided for @diagnosticExportConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出诊断文件？'**
  String get diagnosticExportConfirmTitle;

  /// No description provided for @diagnosticExportConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'将生成一个 JSON 文件，并调用系统分享面板。文件只包含客户端性能、错误摘要及匿名设备运行信息，请在发送前自行确认接收方。'**
  String get diagnosticExportConfirmDesc;

  /// No description provided for @diagnosticExportAction.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get diagnosticExportAction;

  /// No description provided for @diagnosticClearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除诊断日志？'**
  String get diagnosticClearConfirmTitle;

  /// No description provided for @diagnosticClearConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'设备上的诊断日志将被永久删除。'**
  String get diagnosticClearConfirmDesc;

  /// No description provided for @diagnosticExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'诊断文件导出失败'**
  String get diagnosticExportFailed;

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'ヤハギ'**
  String get appTitle;

  /// No description provided for @game.
  ///
  /// In zh, this message translates to:
  /// **'游戏'**
  String get game;

  /// No description provided for @fleet.
  ///
  /// In zh, this message translates to:
  /// **'舰队'**
  String get fleet;

  /// No description provided for @expedition.
  ///
  /// In zh, this message translates to:
  /// **'远征'**
  String get expedition;

  /// No description provided for @repair.
  ///
  /// In zh, this message translates to:
  /// **'修理'**
  String get repair;

  /// No description provided for @construction.
  ///
  /// In zh, this message translates to:
  /// **'建造'**
  String get construction;

  /// No description provided for @quests.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get quests;

  /// No description provided for @battleRecords.
  ///
  /// In zh, this message translates to:
  /// **'航海日志'**
  String get battleRecords;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @layoutSettings.
  ///
  /// In zh, this message translates to:
  /// **'界面与布局'**
  String get layoutSettings;

  /// No description provided for @gameAreaRatio.
  ///
  /// In zh, this message translates to:
  /// **'游戏区域占比'**
  String get gameAreaRatio;

  /// No description provided for @infoPanelWidth.
  ///
  /// In zh, this message translates to:
  /// **'信息面板宽度（竖屏模式无效）'**
  String get infoPanelWidth;

  /// No description provided for @autoZoom.
  ///
  /// In zh, this message translates to:
  /// **'应用推荐显示比例（游戏与菜单比例 65:35）'**
  String get autoZoom;

  /// No description provided for @enhancedDamagePulse.
  ///
  /// In zh, this message translates to:
  /// **'加强受损呼吸提示'**
  String get enhancedDamagePulse;

  /// No description provided for @enhancedDamagePulseDesc.
  ///
  /// In zh, this message translates to:
  /// **'按小破、中破、大破增强颜色、速度和头像内部光效。关闭后使用普通效果。'**
  String get enhancedDamagePulseDesc;

  /// No description provided for @informationPanelOnLeft.
  ///
  /// In zh, this message translates to:
  /// **'功能区域置于左侧'**
  String get informationPanelOnLeft;

  /// No description provided for @informationPanelOnLeftDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭时功能区域保持在右侧，竖屏时保持上下布局。'**
  String get informationPanelOnLeftDesc;

  /// No description provided for @workspaceMenuOnRight.
  ///
  /// In zh, this message translates to:
  /// **'菜单栏置于右侧'**
  String get workspaceMenuOnRight;

  /// No description provided for @workspaceMenuOnRightDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭时菜单栏保持在左侧。'**
  String get workspaceMenuOnRightDesc;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言 (Language)'**
  String get language;

  /// No description provided for @networkSettings.
  ///
  /// In zh, this message translates to:
  /// **'网络设置'**
  String get networkSettings;

  /// No description provided for @networkStatus.
  ///
  /// In zh, this message translates to:
  /// **'网络状态'**
  String get networkStatus;

  /// No description provided for @proxyNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备的 Android System WebView 不支持应用内代理设置。\n您只能使用系统网络或全局 VPN。'**
  String get proxyNotSupported;

  /// No description provided for @systemNetwork.
  ///
  /// In zh, this message translates to:
  /// **'系统网络 / VPN'**
  String get systemNetwork;

  /// No description provided for @systemNetworkDesc.
  ///
  /// In zh, this message translates to:
  /// **'不使用应用内代理，跟随系统网络环境。'**
  String get systemNetworkDesc;

  /// No description provided for @httpProxy.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 代理'**
  String get httpProxy;

  /// No description provided for @httpProxyDesc.
  ///
  /// In zh, this message translates to:
  /// **'连接自定义 HTTP 代理服务器。'**
  String get httpProxyDesc;

  /// No description provided for @socks5Proxy.
  ///
  /// In zh, this message translates to:
  /// **'SOCKS5 代理'**
  String get socks5Proxy;

  /// No description provided for @socks5ProxyDesc.
  ///
  /// In zh, this message translates to:
  /// **'连接自定义 SOCKS5 代理服务器。'**
  String get socks5ProxyDesc;

  /// No description provided for @hostAddress.
  ///
  /// In zh, this message translates to:
  /// **'主机地址 (IP 或域名)'**
  String get hostAddress;

  /// No description provided for @hostHint.
  ///
  /// In zh, this message translates to:
  /// **'如 192.168.1.10'**
  String get hostHint;

  /// No description provided for @port.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get port;

  /// No description provided for @currentSavedMode.
  ///
  /// In zh, this message translates to:
  /// **'当前已保存模式'**
  String get currentSavedMode;

  /// No description provided for @vpnStatus.
  ///
  /// In zh, this message translates to:
  /// **'VPN 状态'**
  String get vpnStatus;

  /// No description provided for @vpnActive.
  ///
  /// In zh, this message translates to:
  /// **'已检测到活动 VPN'**
  String get vpnActive;

  /// No description provided for @vpnInactive.
  ///
  /// In zh, this message translates to:
  /// **'未检测到活动 VPN'**
  String get vpnInactive;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'网络连接测试'**
  String get testConnection;

  /// No description provided for @applySettings.
  ///
  /// In zh, this message translates to:
  /// **'应用设置并重新加载游戏'**
  String get applySettings;

  /// No description provided for @restoreSystemNetwork.
  ///
  /// In zh, this message translates to:
  /// **'恢复系统网络'**
  String get restoreSystemNetwork;

  /// No description provided for @gameSafety.
  ///
  /// In zh, this message translates to:
  /// **'大破提醒'**
  String get gameSafety;

  /// No description provided for @blockSortieTitle.
  ///
  /// In zh, this message translates to:
  /// **'大破进击保护'**
  String get blockSortieTitle;

  /// No description provided for @blockSortieDesc.
  ///
  /// In zh, this message translates to:
  /// **'出击或进击前，若舰队中存在大破舰船（非旗舰且未装备损管），将强制阻断网络请求并弹出警告。强烈建议开启。'**
  String get blockSortieDesc;

  /// No description provided for @storageAndCache.
  ///
  /// In zh, this message translates to:
  /// **'存储与缓存'**
  String get storageAndCache;

  /// No description provided for @logoutAndClear.
  ///
  /// In zh, this message translates to:
  /// **'退出登录 / 清除账号信息'**
  String get logoutAndClear;

  /// No description provided for @logoutAndClearDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除游戏登录状态，下次打开需要重新登录。'**
  String get logoutAndClearDesc;

  /// No description provided for @clearQuestCache.
  ///
  /// In zh, this message translates to:
  /// **'清理任务数据缓存'**
  String get clearQuestCache;

  /// No description provided for @clearQuestCacheDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除本地缓存的脱敏任务数据，重启应用后需进入游戏内任务面板重新获取'**
  String get clearQuestCacheDesc;

  /// No description provided for @clearWebCache.
  ///
  /// In zh, this message translates to:
  /// **'清理浏览器网页缓存'**
  String get clearWebCache;

  /// No description provided for @clearWebCacheDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除 WebView 网页内核的临时页面与脚本数据。'**
  String get clearWebCacheDesc;

  /// No description provided for @baseSenkaResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'素战果归零'**
  String get baseSenkaResetTitle;

  /// No description provided for @baseSenkaResetDesc.
  ///
  /// In zh, this message translates to:
  /// **'将本月累计素战果设为 0.00，不影响 EO、任务和其他战果数据。'**
  String get baseSenkaResetDesc;

  /// No description provided for @baseSenkaResetConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'素战果归零'**
  String get baseSenkaResetConfirmTitle;

  /// No description provided for @baseSenkaResetConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'确定将本月累计素战果归零吗？每日 EO 与任务奖励记录会保留，后续经验增量将从 0.00 继续累计。'**
  String get baseSenkaResetConfirmDesc;

  /// No description provided for @baseSenkaResetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'本月累计素战果已归零'**
  String get baseSenkaResetSuccess;

  /// No description provided for @baseSenkaManualTitle.
  ///
  /// In zh, this message translates to:
  /// **'手动填写素战果'**
  String get baseSenkaManualTitle;

  /// No description provided for @baseSenkaCurrentValue.
  ///
  /// In zh, this message translates to:
  /// **'本月累计：{value} 战果'**
  String baseSenkaCurrentValue(String value);

  /// No description provided for @baseSenkaManualDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'填写本月累计素战果'**
  String get baseSenkaManualDialogTitle;

  /// No description provided for @baseSenkaManualInputLabel.
  ///
  /// In zh, this message translates to:
  /// **'本月累计素战果'**
  String get baseSenkaManualInputLabel;

  /// No description provided for @baseSenkaManualInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入非负数字，最多保留两位小数'**
  String get baseSenkaManualInvalid;

  /// No description provided for @baseSenkaSetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'本月累计素战果已设为 {value}'**
  String baseSenkaSetSuccess(String value);

  /// No description provided for @baseSenkaSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'素战果保存失败，请重试'**
  String get baseSenkaSaveFailed;

  /// No description provided for @senkaTodaySorties.
  ///
  /// In zh, this message translates to:
  /// **'今日出击'**
  String get senkaTodaySorties;

  /// No description provided for @fleetBrief.
  ///
  /// In zh, this message translates to:
  /// **'编队简报'**
  String get fleetBrief;

  /// No description provided for @expeditionBrief.
  ///
  /// In zh, this message translates to:
  /// **'远征简报'**
  String get expeditionBrief;

  /// No description provided for @repairBrief.
  ///
  /// In zh, this message translates to:
  /// **'维修简报'**
  String get repairBrief;

  /// No description provided for @repairDockMode.
  ///
  /// In zh, this message translates to:
  /// **'入渠'**
  String get repairDockMode;

  /// No description provided for @anchorageRepairMode.
  ///
  /// In zh, this message translates to:
  /// **'泊地'**
  String get anchorageRepairMode;

  /// No description provided for @idle.
  ///
  /// In zh, this message translates to:
  /// **'空闲'**
  String get idle;

  /// No description provided for @inactive.
  ///
  /// In zh, this message translates to:
  /// **'闲置'**
  String get inactive;

  /// No description provided for @repairing.
  ///
  /// In zh, this message translates to:
  /// **'正在修理'**
  String get repairing;

  /// No description provided for @outOfRepairRange.
  ///
  /// In zh, this message translates to:
  /// **'超出修理范围'**
  String get outOfRepairRange;

  /// No description provided for @unableToRepair.
  ///
  /// In zh, this message translates to:
  /// **'无法修理'**
  String get unableToRepair;

  /// No description provided for @constructionBrief.
  ///
  /// In zh, this message translates to:
  /// **'建造简报'**
  String get constructionBrief;

  /// No description provided for @questBrief.
  ///
  /// In zh, this message translates to:
  /// **'任务简报'**
  String get questBrief;

  /// No description provided for @preSortieCheck.
  ///
  /// In zh, this message translates to:
  /// **'出击前检查'**
  String get preSortieCheck;

  /// No description provided for @sortieCheckShipsMode.
  ///
  /// In zh, this message translates to:
  /// **'舰娘'**
  String get sortieCheckShipsMode;

  /// No description provided for @sortieCheckMapsMode.
  ///
  /// In zh, this message translates to:
  /// **'海域'**
  String get sortieCheckMapsMode;

  /// No description provided for @mapHpGauges.
  ///
  /// In zh, this message translates to:
  /// **'海域血量'**
  String get mapHpGauges;

  /// No description provided for @noMapGaugeData.
  ///
  /// In zh, this message translates to:
  /// **'暂无海域血量数据'**
  String get noMapGaugeData;

  /// No description provided for @noMapGaugeDataHint.
  ///
  /// In zh, this message translates to:
  /// **'请在游戏中进入出击海域以同步数据'**
  String get noMapGaugeDataHint;

  /// No description provided for @showClearedMaps.
  ///
  /// In zh, this message translates to:
  /// **'显示已攻略'**
  String get showClearedMaps;

  /// No description provided for @allMapsCleared.
  ///
  /// In zh, this message translates to:
  /// **'所有海域已攻略完成'**
  String get allMapsCleared;

  /// No description provided for @forecast.
  ///
  /// In zh, this message translates to:
  /// **'未卜先知'**
  String get forecast;

  /// No description provided for @waitingForSortieData.
  ///
  /// In zh, this message translates to:
  /// **'等待出击数据'**
  String get waitingForSortieData;

  /// No description provided for @standby.
  ///
  /// In zh, this message translates to:
  /// **'待机'**
  String get standby;

  /// No description provided for @compact.
  ///
  /// In zh, this message translates to:
  /// **'简洁'**
  String get compact;

  /// No description provided for @detailed.
  ///
  /// In zh, this message translates to:
  /// **'完整'**
  String get detailed;

  /// No description provided for @questDesc.
  ///
  /// In zh, this message translates to:
  /// **'任务说明'**
  String get questDesc;

  /// No description provided for @baseReward.
  ///
  /// In zh, this message translates to:
  /// **'基础奖励'**
  String get baseReward;

  /// No description provided for @accepted.
  ///
  /// In zh, this message translates to:
  /// **'已接受'**
  String get accepted;

  /// No description provided for @completed.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completed;

  /// No description provided for @updatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新于'**
  String get updatedAt;

  /// No description provided for @questDaily.
  ///
  /// In zh, this message translates to:
  /// **'日常'**
  String get questDaily;

  /// No description provided for @questWeekly.
  ///
  /// In zh, this message translates to:
  /// **'周常'**
  String get questWeekly;

  /// No description provided for @questMonthly.
  ///
  /// In zh, this message translates to:
  /// **'月常'**
  String get questMonthly;

  /// No description provided for @questOneTime.
  ///
  /// In zh, this message translates to:
  /// **'单次'**
  String get questOneTime;

  /// No description provided for @questOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get questOther;

  /// No description provided for @questUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get questUnknown;

  /// No description provided for @inProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get inProgress;

  /// No description provided for @clearWebCacheConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理浏览器网页缓存'**
  String get clearWebCacheConfirmTitle;

  /// No description provided for @clearWebCacheConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除浏览器网页缓存吗？这将会删除 WebView 网页内核缓存的临时数据，不影响已下载的游戏本地资源包。'**
  String get clearWebCacheConfirmDesc;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确定清除'**
  String get confirmClear;

  /// No description provided for @captureMode.
  ///
  /// In zh, this message translates to:
  /// **'数据捕获模式'**
  String get captureMode;

  /// No description provided for @gameAndSound.
  ///
  /// In zh, this message translates to:
  /// **'游戏与声音'**
  String get gameAndSound;

  /// No description provided for @gameSound.
  ///
  /// In zh, this message translates to:
  /// **'游戏声音'**
  String get gameSound;

  /// No description provided for @aboutApp.
  ///
  /// In zh, this message translates to:
  /// **'关于 ヤハギ'**
  String get aboutApp;

  /// No description provided for @aboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本 学习版 1.0.2 · 免责声明 · 检查更新'**
  String get aboutSubtitle;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本 学习版 1.0.2'**
  String get version;

  /// No description provided for @disclaimerTitle.
  ///
  /// In zh, this message translates to:
  /// **'免责声明 (DISCLAIMER)'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerP1.
  ///
  /// In zh, this message translates to:
  /// **'本项目仅供编程技术交流与学习目的使用，是一款完全非盈利且非官方的第三方通用浏览器工具。本项目与 Kantai Collection (KanColle) 官方及任何相关权利方无任何关联。'**
  String get disclaimerP1;

  /// No description provided for @disclaimerP2.
  ///
  /// In zh, this message translates to:
  /// **'本软件不参与、不阻断、不重放且不篡改游戏服务器的通信数据，也不会代替玩家执行游戏操作。原作者不对软件的质量做任何明示或暗示的保证（包括但不限于对软件完全无 Bug、适用性或系统稳定性的保证）。'**
  String get disclaimerP2;

  /// No description provided for @disclaimerP3.
  ///
  /// In zh, this message translates to:
  /// **'在任何情况下，因使用或无法使用本软件而导致的任何移动设备损坏、数据丢失、游戏账号封禁风险或其他任何形式的直接或间接利益损失，原作者均不承担任何法律与连带责任。如果您在“技术学习”之外的场景使用本软件，所产生的一切版权争议、服务条款违规及其他风险，均将由使用者自行承担。'**
  String get disclaimerP3;

  /// No description provided for @viewOnGitHub.
  ///
  /// In zh, this message translates to:
  /// **'去 GitHub 看看'**
  String get viewOnGitHub;

  /// No description provided for @checkForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// No description provided for @openSourceLicense.
  ///
  /// In zh, this message translates to:
  /// **'开源协议: MIT License'**
  String get openSourceLicense;

  /// No description provided for @newVersionFound.
  ///
  /// In zh, this message translates to:
  /// **'🚀 发现新版本！'**
  String get newVersionFound;

  /// No description provided for @currentVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersionLabel;

  /// No description provided for @latestVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get latestVersionLabel;

  /// No description provided for @updateContent.
  ///
  /// In zh, this message translates to:
  /// **'本次更新内容:'**
  String get updateContent;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'以后再说'**
  String get later;

  /// No description provided for @goDownload.
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get goDownload;

  /// No description provided for @alreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'已经是最新版本'**
  String get alreadyLatest;

  /// No description provided for @alreadyLatestDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前版本已经是最新版本。'**
  String get alreadyLatestDesc;

  /// No description provided for @noRelease.
  ///
  /// In zh, this message translates to:
  /// **'暂无发布版本'**
  String get noRelease;

  /// No description provided for @noReleaseDesc.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库尚未发布任何 Release。'**
  String get noReleaseDesc;

  /// No description provided for @checkFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查失败'**
  String get checkFailed;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get networkError;

  /// No description provided for @networkErrorDesc.
  ///
  /// In zh, this message translates to:
  /// **'检查更新时发生错误，请稍后重试。'**
  String get networkErrorDesc;

  /// No description provided for @externalLinkOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接，请检查是否已安装浏览器。'**
  String get externalLinkOpenFailed;

  /// No description provided for @noUpdateLog.
  ///
  /// In zh, this message translates to:
  /// **'暂无更新日志'**
  String get noUpdateLog;

  /// No description provided for @battleWarningOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get battleWarningOff;

  /// No description provided for @battleWarningConfirm.
  ///
  /// In zh, this message translates to:
  /// **'弹框确认'**
  String get battleWarningConfirm;

  /// No description provided for @logoutSnackbar.
  ///
  /// In zh, this message translates to:
  /// **'已退出登录并清除账号信息。'**
  String get logoutSnackbar;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出登录并清除账号信息'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'将清除应用内游戏页面的 Cookie、本地存储和缓存，然后返回登录页面。确定继续吗？'**
  String get logoutConfirmDesc;

  /// No description provided for @logoutSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已退出登录，请重新登录。'**
  String get logoutSucceeded;

  /// No description provided for @logoutFailed.
  ///
  /// In zh, this message translates to:
  /// **'退出登录失败，请稍后重试。'**
  String get logoutFailed;

  /// No description provided for @questCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除任务数据本地缓存'**
  String get questCacheCleared;

  /// No description provided for @webCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清理浏览器网页缓存'**
  String get webCacheCleared;

  /// No description provided for @clearLogbook.
  ///
  /// In zh, this message translates to:
  /// **'清理航海日志数据'**
  String get clearLogbook;

  /// No description provided for @clearLogbookDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除本地保存的出击、远征、建造、开发、除籍与资源记录。此操作不可逆。'**
  String get clearLogbookDesc;

  /// No description provided for @clearLogbookConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理航海日志数据'**
  String get clearLogbookConfirmTitle;

  /// No description provided for @clearLogbookConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有航海日志数据吗？出击、远征、建造、开发、除籍和资源记录都会被删除。此操作无法撤销。'**
  String get clearLogbookConfirmDesc;

  /// No description provided for @logbookCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除所有航海日志数据'**
  String get logbookCleared;

  /// No description provided for @antiCatbomb.
  ///
  /// In zh, this message translates to:
  /// **'断网防猫'**
  String get antiCatbomb;

  /// No description provided for @antiCatbombDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后，若游戏请求因网络断开等原因失败，App 将挂起游戏并不断重试，避免出现“猫”报错。'**
  String get antiCatbombDesc;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @waitingForData.
  ///
  /// In zh, this message translates to:
  /// **'等待数据'**
  String get waitingForData;

  /// No description provided for @fleetNoShips.
  ///
  /// In zh, this message translates to:
  /// **'当前舰队没有舰娘'**
  String get fleetNoShips;

  /// No description provided for @unorganized.
  ///
  /// In zh, this message translates to:
  /// **'未编成'**
  String get unorganized;

  /// No description provided for @speed.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get speed;

  /// No description provided for @totalLevel.
  ///
  /// In zh, this message translates to:
  /// **'总等级'**
  String get totalLevel;

  /// No description provided for @firepower.
  ///
  /// In zh, this message translates to:
  /// **'火力'**
  String get firepower;

  /// No description provided for @torpedo.
  ///
  /// In zh, this message translates to:
  /// **'雷装'**
  String get torpedo;

  /// No description provided for @antiAir.
  ///
  /// In zh, this message translates to:
  /// **'对空'**
  String get antiAir;

  /// No description provided for @antiSub.
  ///
  /// In zh, this message translates to:
  /// **'对潜'**
  String get antiSub;

  /// No description provided for @airPower.
  ///
  /// In zh, this message translates to:
  /// **'制空'**
  String get airPower;

  /// No description provided for @los.
  ///
  /// In zh, this message translates to:
  /// **'索敌'**
  String get los;

  /// No description provided for @avgCondition.
  ///
  /// In zh, this message translates to:
  /// **'最低疲劳'**
  String get avgCondition;

  /// No description provided for @losDetail.
  ///
  /// In zh, this message translates to:
  /// **'索敌详情'**
  String get losDetail;

  /// No description provided for @totalLos.
  ///
  /// In zh, this message translates to:
  /// **'总索敌'**
  String get totalLos;

  /// No description provided for @specialAttack.
  ///
  /// In zh, this message translates to:
  /// **'特殊攻击'**
  String get specialAttack;

  /// No description provided for @unknownShip.
  ///
  /// In zh, this message translates to:
  /// **'未知舰娘'**
  String get unknownShip;

  /// No description provided for @unknownClass.
  ///
  /// In zh, this message translates to:
  /// **'未知舰种'**
  String get unknownClass;

  /// No description provided for @needsResupply.
  ///
  /// In zh, this message translates to:
  /// **'需要补给'**
  String get needsResupply;

  /// No description provided for @fuel.
  ///
  /// In zh, this message translates to:
  /// **'燃料'**
  String get fuel;

  /// No description provided for @ammo.
  ///
  /// In zh, this message translates to:
  /// **'弹药'**
  String get ammo;

  /// No description provided for @hp.
  ///
  /// In zh, this message translates to:
  /// **'血量'**
  String get hp;

  /// No description provided for @waitingForEquip.
  ///
  /// In zh, this message translates to:
  /// **'装备数据等待更新'**
  String get waitingForEquip;

  /// No description provided for @fastSpeed.
  ///
  /// In zh, this message translates to:
  /// **'高速'**
  String get fastSpeed;

  /// No description provided for @slowSpeed.
  ///
  /// In zh, this message translates to:
  /// **'低速'**
  String get slowSpeed;

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @unknownEquip.
  ///
  /// In zh, this message translates to:
  /// **'未知装备'**
  String get unknownEquip;

  /// No description provided for @noBonusStats.
  ///
  /// In zh, this message translates to:
  /// **'暂无附加属性'**
  String get noBonusStats;

  /// No description provided for @condition.
  ///
  /// In zh, this message translates to:
  /// **'疲劳'**
  String get condition;

  /// No description provided for @noExpeditionFleet.
  ///
  /// In zh, this message translates to:
  /// **'暂无远征中的舰队'**
  String get noExpeditionFleet;

  /// No description provided for @expeditionInProgress.
  ///
  /// In zh, this message translates to:
  /// **'远征进行中'**
  String get expeditionInProgress;

  /// No description provided for @progress.
  ///
  /// In zh, this message translates to:
  /// **'进行进度'**
  String get progress;

  /// No description provided for @unlocked.
  ///
  /// In zh, this message translates to:
  /// **'未解锁'**
  String get unlocked;

  /// No description provided for @notRepairing.
  ///
  /// In zh, this message translates to:
  /// **'未入渠'**
  String get notRepairing;

  /// No description provided for @repairProgress.
  ///
  /// In zh, this message translates to:
  /// **'修理进度'**
  String get repairProgress;

  /// No description provided for @cost.
  ///
  /// In zh, this message translates to:
  /// **'消耗'**
  String get cost;

  /// No description provided for @notConstructing.
  ///
  /// In zh, this message translates to:
  /// **'未建造'**
  String get notConstructing;

  /// No description provided for @lsc.
  ///
  /// In zh, this message translates to:
  /// **'大型建造'**
  String get lsc;

  /// No description provided for @normalConstruct.
  ///
  /// In zh, this message translates to:
  /// **'常规建造'**
  String get normalConstruct;

  /// No description provided for @constructing.
  ///
  /// In zh, this message translates to:
  /// **'建造中'**
  String get constructing;

  /// No description provided for @constructProgress.
  ///
  /// In zh, this message translates to:
  /// **'建造进度'**
  String get constructProgress;

  /// No description provided for @constructComplete.
  ///
  /// In zh, this message translates to:
  /// **'建造完成'**
  String get constructComplete;

  /// No description provided for @allRatings.
  ///
  /// In zh, this message translates to:
  /// **'全部评级'**
  String get allRatings;

  /// No description provided for @noBattleRecords.
  ///
  /// In zh, this message translates to:
  /// **'尚无战斗记录'**
  String get noBattleRecords;

  /// No description provided for @autoRecordHint.
  ///
  /// In zh, this message translates to:
  /// **'出击后会自动记录，不需要额外操作'**
  String get autoRecordHint;

  /// No description provided for @thisSortie.
  ///
  /// In zh, this message translates to:
  /// **'本次出击'**
  String get thisSortie;

  /// No description provided for @historicalRecords.
  ///
  /// In zh, this message translates to:
  /// **'历史战果'**
  String get historicalRecords;

  /// No description provided for @resourceTrend.
  ///
  /// In zh, this message translates to:
  /// **'资源趋势'**
  String get resourceTrend;

  /// No description provided for @expeditionIncome.
  ///
  /// In zh, this message translates to:
  /// **'远征收益'**
  String get expeditionIncome;

  /// No description provided for @noHistoricalRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史战果'**
  String get noHistoricalRecords;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get none;

  /// No description provided for @unknownNode.
  ///
  /// In zh, this message translates to:
  /// **'未知点'**
  String get unknownNode;

  /// No description provided for @noResourceRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无资源记录'**
  String get noResourceRecords;

  /// No description provided for @resourceTrend24h.
  ///
  /// In zh, this message translates to:
  /// **'24小时'**
  String get resourceTrend24h;

  /// No description provided for @resourceTrend7d.
  ///
  /// In zh, this message translates to:
  /// **'7天'**
  String get resourceTrend7d;

  /// No description provided for @resourceTrend30d.
  ///
  /// In zh, this message translates to:
  /// **'30天'**
  String get resourceTrend30d;

  /// No description provided for @resourceTrendAll.
  ///
  /// In zh, this message translates to:
  /// **'全部记录'**
  String get resourceTrendAll;

  /// No description provided for @resourceTrendMainGroup.
  ///
  /// In zh, this message translates to:
  /// **'四项资源'**
  String get resourceTrendMainGroup;

  /// No description provided for @resourceTrendAuxGroup.
  ///
  /// In zh, this message translates to:
  /// **'辅助资源'**
  String get resourceTrendAuxGroup;

  /// No description provided for @gadgetBypass.
  ///
  /// In zh, this message translates to:
  /// **'游戏资源镜像与IP限制绕行'**
  String get gadgetBypass;

  /// No description provided for @gadgetBypassDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后通过镜像加载游戏客户端静态资源。DMM 地区限制兼容处理自动生效，不受此开关影响。'**
  String get gadgetBypassDesc;

  /// No description provided for @gadgetBypassEnable.
  ///
  /// In zh, this message translates to:
  /// **'开启镜像绕行'**
  String get gadgetBypassEnable;

  /// No description provided for @gadgetBypassEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'镜像端点'**
  String get gadgetBypassEndpoint;

  /// No description provided for @endpointCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get endpointCustom;

  /// No description provided for @gadgetBypassStatusOn.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get gadgetBypassStatusOn;

  /// No description provided for @gadgetBypassStatusOff.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get gadgetBypassStatusOff;

  /// No description provided for @gadgetBypassUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持（需要 Android 8.0+）'**
  String get gadgetBypassUnsupported;

  /// No description provided for @gadgetBypassClearCache.
  ///
  /// In zh, this message translates to:
  /// **'清空缓存'**
  String get gadgetBypassClearCache;

  /// No description provided for @gadgetBypassError.
  ///
  /// In zh, this message translates to:
  /// **'绕行配置失败'**
  String get gadgetBypassError;

  /// No description provided for @gadgetBypassDiagnose.
  ///
  /// In zh, this message translates to:
  /// **'检查 403 与镜像连通性'**
  String get gadgetBypassDiagnose;

  /// No description provided for @gadgetBypassDiagnosing.
  ///
  /// In zh, this message translates to:
  /// **'诊断中...'**
  String get gadgetBypassDiagnosing;

  /// No description provided for @gadgetBypassW00g.
  ///
  /// In zh, this message translates to:
  /// **'客户端服务器 (w00g)'**
  String get gadgetBypassW00g;

  /// No description provided for @gadgetBypassEndpointProbe.
  ///
  /// In zh, this message translates to:
  /// **'镜像端点'**
  String get gadgetBypassEndpointProbe;

  /// No description provided for @gadgetBypassKcsapi.
  ///
  /// In zh, this message translates to:
  /// **'游戏数据接口 (kcsapi)'**
  String get gadgetBypassKcsapi;

  /// No description provided for @gadgetBypassReachable.
  ///
  /// In zh, this message translates to:
  /// **'通畅'**
  String get gadgetBypassReachable;

  /// No description provided for @gadgetBypassUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接'**
  String get gadgetBypassUnreachable;

  /// No description provided for @resourceTrendChart.
  ///
  /// In zh, this message translates to:
  /// **'资源趋势变化 (最近 100 次记录)'**
  String get resourceTrendChart;

  /// No description provided for @steel.
  ///
  /// In zh, this message translates to:
  /// **'钢材'**
  String get steel;

  /// No description provided for @bauxite.
  ///
  /// In zh, this message translates to:
  /// **'铝土'**
  String get bauxite;

  /// No description provided for @noExpeditionRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无远征记录'**
  String get noExpeditionRecords;

  /// No description provided for @expeditionIncomeChart.
  ///
  /// In zh, this message translates to:
  /// **'远征收益统计 (最近 7 天)'**
  String get expeditionIncomeChart;

  /// No description provided for @langZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get langZh;

  /// No description provided for @langZhHant.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get langZhHant;

  /// No description provided for @langJa.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get langJa;

  /// No description provided for @node.
  ///
  /// In zh, this message translates to:
  /// **'点'**
  String get node;

  /// No description provided for @friend.
  ///
  /// In zh, this message translates to:
  /// **'我方'**
  String get friend;

  /// No description provided for @enemy.
  ///
  /// In zh, this message translates to:
  /// **'敌方'**
  String get enemy;

  /// No description provided for @drop.
  ///
  /// In zh, this message translates to:
  /// **'掉落'**
  String get drop;

  /// No description provided for @inExpedition.
  ///
  /// In zh, this message translates to:
  /// **'远征中'**
  String get inExpedition;

  /// No description provided for @unknownProgress.
  ///
  /// In zh, this message translates to:
  /// **'进度未知'**
  String get unknownProgress;

  /// No description provided for @waitingForPortDataDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入游戏母港或刷新游戏页面后，这里会自动更新'**
  String get waitingForPortDataDescription;

  /// No description provided for @fleetNotFormed.
  ///
  /// In zh, this message translates to:
  /// **'未编成'**
  String get fleetNotFormed;

  /// No description provided for @fleetStandby.
  ///
  /// In zh, this message translates to:
  /// **'母港待命'**
  String get fleetStandby;

  /// No description provided for @shipsCount.
  ///
  /// In zh, this message translates to:
  /// **'舰'**
  String get shipsCount;

  /// No description provided for @noValue.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get noValue;

  /// No description provided for @lineOfSight.
  ///
  /// In zh, this message translates to:
  /// **'索敌'**
  String get lineOfSight;

  /// No description provided for @averageCondition.
  ///
  /// In zh, this message translates to:
  /// **'最低疲劳'**
  String get averageCondition;

  /// No description provided for @moraleRecoveryCountdown.
  ///
  /// In zh, this message translates to:
  /// **'恢复倒计时'**
  String get moraleRecoveryCountdown;

  /// No description provided for @moraleRecovered.
  ///
  /// In zh, this message translates to:
  /// **'已恢复'**
  String get moraleRecovered;

  /// No description provided for @toggleMoraleMetric.
  ///
  /// In zh, this message translates to:
  /// **'点击切换最低疲劳与恢复倒计时'**
  String get toggleMoraleMetric;

  /// No description provided for @losDetails.
  ///
  /// In zh, this message translates to:
  /// **'索敌详情'**
  String get losDetails;

  /// No description provided for @airPowerDetails.
  ///
  /// In zh, this message translates to:
  /// **'制空详情'**
  String get airPowerDetails;

  /// No description provided for @minimumValue.
  ///
  /// In zh, this message translates to:
  /// **'最小'**
  String get minimumValue;

  /// No description provided for @maximumValue.
  ///
  /// In zh, this message translates to:
  /// **'最大'**
  String get maximumValue;

  /// No description provided for @withoutBonus.
  ///
  /// In zh, this message translates to:
  /// **'无加成'**
  String get withoutBonus;

  /// No description provided for @showAirPowerDetails.
  ///
  /// In zh, this message translates to:
  /// **'点击查看制空详情'**
  String get showAirPowerDetails;

  /// No description provided for @unknownShipType.
  ///
  /// In zh, this message translates to:
  /// **'未知舰种'**
  String get unknownShipType;

  /// No description provided for @needsSupply.
  ///
  /// In zh, this message translates to:
  /// **'需要补给'**
  String get needsSupply;

  /// No description provided for @equipmentDataWaiting.
  ///
  /// In zh, this message translates to:
  /// **'装备数据等待更新'**
  String get equipmentDataWaiting;

  /// No description provided for @highSpeed.
  ///
  /// In zh, this message translates to:
  /// **'高速'**
  String get highSpeed;

  /// No description provided for @lowSpeed.
  ///
  /// In zh, this message translates to:
  /// **'低速'**
  String get lowSpeed;

  /// No description provided for @unknownEquipment.
  ///
  /// In zh, this message translates to:
  /// **'未知装备'**
  String get unknownEquipment;

  /// No description provided for @noAdditionalStats.
  ///
  /// In zh, this message translates to:
  /// **'暂无附加属性'**
  String get noAdditionalStats;

  /// No description provided for @fatigue.
  ///
  /// In zh, this message translates to:
  /// **'疲劳'**
  String get fatigue;

  /// No description provided for @startupUpdateTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get startupUpdateTitle;

  /// No description provided for @backgroundAudio.
  ///
  /// In zh, this message translates to:
  /// **'后台播放声音'**
  String get backgroundAudio;

  /// No description provided for @backgroundAudioDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后，应用进入后台时游戏声音仍会继续播放。'**
  String get backgroundAudioDesc;

  /// No description provided for @backgroundGameRetention.
  ///
  /// In zh, this message translates to:
  /// **'后台保持游戏'**
  String get backgroundGameRetention;

  /// No description provided for @backgroundGameRetentionDesc.
  ///
  /// In zh, this message translates to:
  /// **'进入后台时显示常驻通知以降低游戏会话被系统回收的概率，可能增加耗电。'**
  String get backgroundGameRetentionDesc;

  /// No description provided for @backgroundGameRetentionNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'矢矧正在后台运行'**
  String get backgroundGameRetentionNotificationTitle;

  /// No description provided for @backgroundGameRetentionNotificationBody.
  ///
  /// In zh, this message translates to:
  /// **'游戏会话保持中 · 点击返回游戏'**
  String get backgroundGameRetentionNotificationBody;

  /// No description provided for @screenAwake.
  ///
  /// In zh, this message translates to:
  /// **'屏幕常亮'**
  String get screenAwake;

  /// No description provided for @screenAwakeDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后，应用在前台期间屏幕不会自动关闭，可能增加耗电。'**
  String get screenAwakeDesc;

  /// No description provided for @gameToolbar.
  ///
  /// In zh, this message translates to:
  /// **'游戏工具栏'**
  String get gameToolbar;

  /// No description provided for @toolbarAutoHide.
  ///
  /// In zh, this message translates to:
  /// **'自动隐藏'**
  String get toolbarAutoHide;

  /// No description provided for @toolbarPersistent.
  ///
  /// In zh, this message translates to:
  /// **'常驻'**
  String get toolbarPersistent;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @reload.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get reload;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'回到主页'**
  String get home;

  /// No description provided for @enterDmm.
  ///
  /// In zh, this message translates to:
  /// **'进入 DMM 登录'**
  String get enterDmm;

  /// No description provided for @enableGameAudio.
  ///
  /// In zh, this message translates to:
  /// **'开启游戏声音'**
  String get enableGameAudio;

  /// No description provided for @disableGameAudio.
  ///
  /// In zh, this message translates to:
  /// **'关闭游戏声音'**
  String get disableGameAudio;

  /// No description provided for @takeScreenshot.
  ///
  /// In zh, this message translates to:
  /// **'一键截图'**
  String get takeScreenshot;

  /// No description provided for @screenshotSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存游戏截图…'**
  String get screenshotSaving;

  /// No description provided for @fitGameScreen.
  ///
  /// In zh, this message translates to:
  /// **'修复显示（自适应屏幕）'**
  String get fitGameScreen;

  /// No description provided for @collapseToolbar.
  ///
  /// In zh, this message translates to:
  /// **'收起工具栏'**
  String get collapseToolbar;

  /// No description provided for @editDone.
  ///
  /// In zh, this message translates to:
  /// **'完成编辑'**
  String get editDone;

  /// No description provided for @retryWithSystemNetwork.
  ///
  /// In zh, this message translates to:
  /// **'改用系统网络重试'**
  String get retryWithSystemNetwork;

  /// No description provided for @displayMode.
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get displayMode;

  /// No description provided for @displayAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get displayAuto;

  /// No description provided for @displayLandscape.
  ///
  /// In zh, this message translates to:
  /// **'横屏'**
  String get displayLandscape;

  /// No description provided for @displayPortrait.
  ///
  /// In zh, this message translates to:
  /// **'竖屏'**
  String get displayPortrait;

  /// No description provided for @allRanks.
  ///
  /// In zh, this message translates to:
  /// **'全部评级'**
  String get allRanks;

  /// No description provided for @battleFleetSummary.
  ///
  /// In zh, this message translates to:
  /// **'我方 {friendAlive}/{friendTotal}　敌方 {enemyAlive}/{enemyTotal}'**
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  );

  /// No description provided for @dropLabel.
  ///
  /// In zh, this message translates to:
  /// **'掉落：{name}'**
  String dropLabel(String name);

  /// No description provided for @item.
  ///
  /// In zh, this message translates to:
  /// **'道具'**
  String get item;

  /// No description provided for @friendFinalStatus.
  ///
  /// In zh, this message translates to:
  /// **'我方最终状态'**
  String get friendFinalStatus;

  /// No description provided for @enemyFinalStatus.
  ///
  /// In zh, this message translates to:
  /// **'敌方最终状态'**
  String get enemyFinalStatus;

  /// No description provided for @enemyFleet.
  ///
  /// In zh, this message translates to:
  /// **'敌舰队'**
  String get enemyFleet;

  /// No description provided for @airStateLabel.
  ///
  /// In zh, this message translates to:
  /// **'制空：{label}'**
  String airStateLabel(String label);

  /// No description provided for @postBattleWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'大破安全警告'**
  String get postBattleWarningTitle;

  /// No description provided for @postBattleWarningHeadline.
  ///
  /// In zh, this message translates to:
  /// **'出击舰队中存在大破舰娘！'**
  String get postBattleWarningHeadline;

  /// No description provided for @postBattleWarningBody.
  ///
  /// In zh, this message translates to:
  /// **'已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。'**
  String get postBattleWarningBody;

  /// No description provided for @acknowledgeAndRetreat.
  ///
  /// In zh, this message translates to:
  /// **'确认了解'**
  String get acknowledgeAndRetreat;

  /// No description provided for @postBattleWarningBanner.
  ///
  /// In zh, this message translates to:
  /// **'战后安全警告：出击舰队中存在大破舰娘！请注意撤退！'**
  String get postBattleWarningBanner;

  /// No description provided for @noActiveExpedition.
  ///
  /// In zh, this message translates to:
  /// **'没有正在进行的远征'**
  String get noActiveExpedition;

  /// No description provided for @noSortieWarnings.
  ///
  /// In zh, this message translates to:
  /// **'暂无出击警告'**
  String get noSortieWarnings;

  /// No description provided for @preSortieCriticalWarning.
  ///
  /// In zh, this message translates to:
  /// **'{fleetName} 存在大破舰，停止出击！'**
  String preSortieCriticalWarning(String fleetName);

  /// No description provided for @preSortieSupplyWarning.
  ///
  /// In zh, this message translates to:
  /// **'{fleetName} 舰娘未补给'**
  String preSortieSupplyWarning(String fleetName);

  /// No description provided for @preSortieFatigueWarning.
  ///
  /// In zh, this message translates to:
  /// **'{fleetName} 舰娘疲劳未恢复'**
  String preSortieFatigueWarning(String fleetName);

  /// No description provided for @preSortieMainEquipmentWarning.
  ///
  /// In zh, this message translates to:
  /// **'{fleetName} 装备缺失（主装备槽）：{shipNames}'**
  String preSortieMainEquipmentWarning(String fleetName, String shipNames);

  /// No description provided for @preSortieExtraEquipmentWarning.
  ///
  /// In zh, this message translates to:
  /// **'{fleetName} 装备缺失（增设槽）：{shipNames}'**
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames);

  /// No description provided for @noPinnedQuests.
  ///
  /// In zh, this message translates to:
  /// **'当前无进行中任务'**
  String get noPinnedQuests;

  /// No description provided for @questsNeedSync.
  ///
  /// In zh, this message translates to:
  /// **'需进入任务界面同步信息'**
  String get questsNeedSync;

  /// No description provided for @waitingQuestData.
  ///
  /// In zh, this message translates to:
  /// **'等待任务数据'**
  String get waitingQuestData;

  /// No description provided for @waitingQuestDataDesc.
  ///
  /// In zh, this message translates to:
  /// **'打开游戏任务列表后，这里会自动同步当前已接受任务'**
  String get waitingQuestDataDesc;

  /// No description provided for @diagnosticsAndAbout.
  ///
  /// In zh, this message translates to:
  /// **'诊断与关于'**
  String get diagnosticsAndAbout;

  /// No description provided for @safetyBoundary.
  ///
  /// In zh, this message translates to:
  /// **'安全边界'**
  String get safetyBoundary;

  /// No description provided for @applyingNetworkSettings.
  ///
  /// In zh, this message translates to:
  /// **'正在应用网络设置…'**
  String get applyingNetworkSettings;

  /// No description provided for @networkSettingsApplied.
  ///
  /// In zh, this message translates to:
  /// **'网络设置应用成功：{message}'**
  String networkSettingsApplied(String message);

  /// No description provided for @clearingProxy.
  ///
  /// In zh, this message translates to:
  /// **'正在清除应用内代理…'**
  String get clearingProxy;

  /// No description provided for @systemNetworkRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复系统网络。'**
  String get systemNetworkRestored;

  /// No description provided for @screenshotSaved.
  ///
  /// In zh, this message translates to:
  /// **'游戏截图已保存到相册：{path}'**
  String screenshotSaved(String path);

  /// No description provided for @screenshotFailed.
  ///
  /// In zh, this message translates to:
  /// **'游戏截图失败，请稍后重试。'**
  String get screenshotFailed;

  /// No description provided for @startupUpdateMessage.
  ///
  /// In zh, this message translates to:
  /// **'ヤハギ {version} 已发布。'**
  String startupUpdateMessage(String version);

  /// No description provided for @gameStatusError.
  ///
  /// In zh, this message translates to:
  /// **'游戏状态异常'**
  String get gameStatusError;

  /// No description provided for @gameStatusErrorDesc.
  ///
  /// In zh, this message translates to:
  /// **'网页或捕获状态异常，请在设置中查看诊断信息。'**
  String get gameStatusErrorDesc;

  /// No description provided for @browserOnlyCaptureOff.
  ///
  /// In zh, this message translates to:
  /// **'纯浏览模式 · 数据捕获已关闭'**
  String get browserOnlyCaptureOff;

  /// No description provided for @browserOnlyCaptureOffDesc.
  ///
  /// In zh, this message translates to:
  /// **'游戏网页继续运行，舰队、任务和战斗信息暂停更新。'**
  String get browserOnlyCaptureOffDesc;

  /// No description provided for @capturedCount.
  ///
  /// In zh, this message translates to:
  /// **'已捕获 {count} 条'**
  String capturedCount(int count);

  /// No description provided for @waitingKcsapi.
  ///
  /// In zh, this message translates to:
  /// **'等待 /kcsapi/ 响应'**
  String get waitingKcsapi;

  /// No description provided for @ignoredNonTargetMessage.
  ///
  /// In zh, this message translates to:
  /// **'已忽略非目标消息'**
  String get ignoredNonTargetMessage;

  /// No description provided for @readOnlyNoActions.
  ///
  /// In zh, this message translates to:
  /// **'只读取，不操作'**
  String get readOnlyNoActions;

  /// No description provided for @readOnlyNoActionsDesc.
  ///
  /// In zh, this message translates to:
  /// **'不会自动点击、补给、编成、出击或领取任务。'**
  String get readOnlyNoActionsDesc;

  /// No description provided for @noCookieRead.
  ///
  /// In zh, this message translates to:
  /// **'不读取 Cookie'**
  String get noCookieRead;

  /// No description provided for @noCookieReadDesc.
  ///
  /// In zh, this message translates to:
  /// **'JS 桥接消息只包含接口路径、响应正文和时间。'**
  String get noCookieReadDesc;

  /// No description provided for @browserIdle.
  ///
  /// In zh, this message translates to:
  /// **'等待网页'**
  String get browserIdle;

  /// No description provided for @browserLoading.
  ///
  /// In zh, this message translates to:
  /// **'网页加载中'**
  String get browserLoading;

  /// No description provided for @browserReady.
  ///
  /// In zh, this message translates to:
  /// **'网页已就绪'**
  String get browserReady;

  /// No description provided for @browserFailed.
  ///
  /// In zh, this message translates to:
  /// **'网页加载失败'**
  String get browserFailed;

  /// No description provided for @capturePreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备游戏接口捕获'**
  String get capturePreparing;

  /// No description provided for @captureReady.
  ///
  /// In zh, this message translates to:
  /// **'捕获已就绪'**
  String get captureReady;

  /// No description provided for @captureActive.
  ///
  /// In zh, this message translates to:
  /// **'正在捕获游戏接口'**
  String get captureActive;

  /// No description provided for @captureUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前 WebView 不支持跨框架捕获'**
  String get captureUnsupported;

  /// No description provided for @captureFailed.
  ///
  /// In zh, this message translates to:
  /// **'游戏接口捕获启动失败'**
  String get captureFailed;

  /// No description provided for @captureCheckingDesc.
  ///
  /// In zh, this message translates to:
  /// **'正在检查 Android WebView 捕获能力。'**
  String get captureCheckingDesc;

  /// No description provided for @captureReadyDesc.
  ///
  /// In zh, this message translates to:
  /// **'等待 /kcsapi/ 响应，游戏仍可正常操作。'**
  String get captureReadyDesc;

  /// No description provided for @portCaptureVerified.
  ///
  /// In zh, this message translates to:
  /// **'母港接口验证通过'**
  String get portCaptureVerified;

  /// No description provided for @captureReceived.
  ///
  /// In zh, this message translates to:
  /// **'已经收到游戏接口。'**
  String get captureReceived;

  /// No description provided for @captureLatest.
  ///
  /// In zh, this message translates to:
  /// **'最近一次捕获：{path}'**
  String captureLatest(String path);

  /// No description provided for @captureUnsupportedDesc.
  ///
  /// In zh, this message translates to:
  /// **'游戏仍可运行；当前设备只提供网页浏览。'**
  String get captureUnsupportedDesc;

  /// No description provided for @captureFailedDesc.
  ///
  /// In zh, this message translates to:
  /// **'游戏仍可运行，可刷新页面后重试。'**
  String get captureFailedDesc;

  /// No description provided for @networkApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置失败 [{code}]：{message}'**
  String networkApplyFailed(String code, String message);

  /// No description provided for @networkRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败 [{code}]：{message}'**
  String networkRestoreFailed(String code, String message);

  /// No description provided for @tcpConnection.
  ///
  /// In zh, this message translates to:
  /// **'TCP 连接'**
  String get tcpConnection;

  /// No description provided for @gameService.
  ///
  /// In zh, this message translates to:
  /// **'游戏服务'**
  String get gameService;

  /// No description provided for @externalNetwork.
  ///
  /// In zh, this message translates to:
  /// **'Google（外网）'**
  String get externalNetwork;

  /// No description provided for @statusUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get statusUnknown;

  /// No description provided for @statusSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get statusSuccess;

  /// No description provided for @statusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get statusFailed;

  /// No description provided for @statusSkipped.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get statusSkipped;

  /// No description provided for @formula33.
  ///
  /// In zh, this message translates to:
  /// **'33式'**
  String get formula33;

  /// No description provided for @fatigueValue.
  ///
  /// In zh, this message translates to:
  /// **'疲劳 {value}'**
  String fatigueValue(int value);

  /// No description provided for @fcdMapSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据更新'**
  String get fcdMapSectionTitle;

  /// No description provided for @fcdMapDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'未卜先知数据'**
  String get fcdMapDataTitle;

  /// No description provided for @fcdMapDataVersion.
  ///
  /// In zh, this message translates to:
  /// **'数据版本：{version}'**
  String fcdMapDataVersion(String version);

  /// No description provided for @fcdMapLastChecked.
  ///
  /// In zh, this message translates to:
  /// **'上次检查：{time}'**
  String fcdMapLastChecked(String time);

  /// No description provided for @fcdMapNeverChecked.
  ///
  /// In zh, this message translates to:
  /// **'上次检查：尚未检查'**
  String get fcdMapNeverChecked;

  /// No description provided for @fcdMapSource.
  ///
  /// In zh, this message translates to:
  /// **'更新源：{source}'**
  String fcdMapSource(String source);

  /// No description provided for @fcdMapAttribution.
  ///
  /// In zh, this message translates to:
  /// **'数据来源：poi FCD（MIT）'**
  String get fcdMapAttribution;

  /// No description provided for @fcdMapCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查未卜先知数据更新'**
  String get fcdMapCheckUpdates;

  /// No description provided for @fcdMapUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'未卜先知数据已经是最新版本。'**
  String get fcdMapUpToDate;

  /// No description provided for @fcdMapUpdated.
  ///
  /// In zh, this message translates to:
  /// **'未卜先知数据已从 {oldVersion} 更新至 {newVersion}，已立即生效。'**
  String fcdMapUpdated(String oldVersion, String newVersion);

  /// No description provided for @fcdMapNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'未能连接数据更新源，请稍后重试。'**
  String get fcdMapNetworkError;

  /// No description provided for @fcdMapValidationError.
  ///
  /// In zh, this message translates to:
  /// **'下载的数据未通过校验，已保留当前版本。'**
  String get fcdMapValidationError;

  /// No description provided for @fcdMapStorageError.
  ///
  /// In zh, this message translates to:
  /// **'数据保存失败，已保留当前版本。'**
  String get fcdMapStorageError;

  /// No description provided for @questCatalogDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务资料'**
  String get questCatalogDataTitle;

  /// No description provided for @questCatalogDataVersion.
  ///
  /// In zh, this message translates to:
  /// **'资料版本：{version}'**
  String questCatalogDataVersion(String version);

  /// No description provided for @questCatalogNeverChecked.
  ///
  /// In zh, this message translates to:
  /// **'上次检查：尚未检查'**
  String get questCatalogNeverChecked;

  /// No description provided for @questCatalogLastChecked.
  ///
  /// In zh, this message translates to:
  /// **'上次检查：{time}'**
  String questCatalogLastChecked(String time);

  /// No description provided for @questCatalogCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查任务资料更新'**
  String get questCatalogCheckUpdates;

  /// No description provided for @questCatalogUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'任务资料已经是最新版本。'**
  String get questCatalogUpToDate;

  /// No description provided for @questCatalogUpdated.
  ///
  /// In zh, this message translates to:
  /// **'任务资料已从 {oldVersion} 更新至 {newVersion}，并已立即生效。'**
  String questCatalogUpdated(String oldVersion, String newVersion);

  /// No description provided for @questCatalogNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'无法连接任务资料更新源，请稍后再试。'**
  String get questCatalogNetworkError;

  /// No description provided for @questCatalogValidationError.
  ///
  /// In zh, this message translates to:
  /// **'下载的任务资料未通过验证，已保留当前版本。'**
  String get questCatalogValidationError;

  /// No description provided for @questCatalogStorageError.
  ///
  /// In zh, this message translates to:
  /// **'任务资料保存失败，已保留当前版本。'**
  String get questCatalogStorageError;

  /// No description provided for @gameFrameRateTitle.
  ///
  /// In zh, this message translates to:
  /// **'游戏帧率'**
  String get gameFrameRateTitle;

  /// No description provided for @gameFrameRateAutomatic.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get gameFrameRateAutomatic;

  /// No description provided for @gameFrameRateStable60.
  ///
  /// In zh, this message translates to:
  /// **'60 帧'**
  String get gameFrameRateStable60;

  /// No description provided for @gameFrameRateStable60Desc.
  ///
  /// In zh, this message translates to:
  /// **'始终以 60 FPS 运行，不自动降档。'**
  String get gameFrameRateStable60Desc;

  /// No description provided for @gameFrameRateStable30.
  ///
  /// In zh, this message translates to:
  /// **'30 帧'**
  String get gameFrameRateStable30;

  /// No description provided for @gameFrameRateStable30Desc.
  ///
  /// In zh, this message translates to:
  /// **'始终以 30 FPS 运行，降低耗电和发热。'**
  String get gameFrameRateStable30Desc;

  /// No description provided for @gameFrameRateHighRefresh.
  ///
  /// In zh, this message translates to:
  /// **'高刷'**
  String get gameFrameRateHighRefresh;

  /// No description provided for @gameFrameRateHighRefreshDesc.
  ///
  /// In zh, this message translates to:
  /// **'解除 60 FPS 限制，跟随屏幕刷新率运行，耗电和发热可能增加。'**
  String get gameFrameRateHighRefreshDesc;

  /// No description provided for @gameFrameRateHighRefreshDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启高刷模式？'**
  String get gameFrameRateHighRefreshDialogTitle;

  /// No description provided for @gameFrameRateHighRefreshDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'高刷会修改游戏运行帧率，可能增加耗电、发热或引发动画异常，并存在未知的账号风险。请自行承担后果。'**
  String get gameFrameRateHighRefreshDialogBody;

  /// No description provided for @gameFrameRateHighRefreshDialogConfirm.
  ///
  /// In zh, this message translates to:
  /// **'了解风险并开启'**
  String get gameFrameRateHighRefreshDialogConfirm;

  /// No description provided for @gameFrameRateAutomaticDesc.
  ///
  /// In zh, this message translates to:
  /// **'封顶 60 FPS；若持续不稳定、系统开启节能或设备发热，将自动降至 30 FPS。'**
  String get gameFrameRateAutomaticDesc;

  /// No description provided for @gameFrameRateUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前 Android WebView 不支持帧率调整，将保持游戏原始帧率。'**
  String get gameFrameRateUnsupported;

  /// No description provided for @gameRenderingModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'游戏渲染模式'**
  String get gameRenderingModeTitle;

  /// No description provided for @gameRenderingModeStandard.
  ///
  /// In zh, this message translates to:
  /// **'轻量模式'**
  String get gameRenderingModeStandard;

  /// No description provided for @gameRenderingModeStandardDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter PlatformView + Texture Layer + WebGL，减少部分合成开销，部分设备可能存在显示或触控兼容问题。'**
  String get gameRenderingModeStandardDesc;

  /// No description provided for @gameRenderingModeCompatibility.
  ///
  /// In zh, this message translates to:
  /// **'均衡模式'**
  String get gameRenderingModeCompatibility;

  /// No description provided for @gameRenderingModeCompatibilityDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter PlatformView + Hybrid Composition + WebGL，兼顾游戏性能与设备兼容性。'**
  String get gameRenderingModeCompatibilityDesc;

  /// No description provided for @gameRenderingModeCanvas.
  ///
  /// In zh, this message translates to:
  /// **'兼容模式'**
  String get gameRenderingModeCanvas;

  /// No description provided for @gameRenderingModeCanvasDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter PlatformView + Hybrid Composition + Canvas，绕过 WebGL，优先解决部分 GPU / WebGL 兼容问题，画面性能可能降低。'**
  String get gameRenderingModeCanvasDesc;

  /// No description provided for @gameRenderingModeNativeActivity.
  ///
  /// In zh, this message translates to:
  /// **'原生独立渲染（推荐）'**
  String get gameRenderingModeNativeActivity;

  /// No description provided for @gameRenderingModeNativeActivityDesc.
  ///
  /// In zh, this message translates to:
  /// **'Activity Direct WebView + WebGL，理论上具有更低的合成开销与更好的原生兼容性。'**
  String get gameRenderingModeNativeActivityDesc;

  /// No description provided for @gameRenderingModeConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换游戏渲染模式？'**
  String get gameRenderingModeConfirmTitle;

  /// No description provided for @gameRenderingModeConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'切换渲染模式会自动重启应用，游戏页面将重新载入。请先结束正在进行的操作。'**
  String get gameRenderingModeConfirmMessage;

  /// No description provided for @gameRenderingModeBattleWarning.
  ///
  /// In zh, this message translates to:
  /// **'检测到可能正在战斗。现在切换可能中断当前战斗页面，建议结束战斗后再操作。'**
  String get gameRenderingModeBattleWarning;

  /// No description provided for @gameRenderingModeChanging.
  ///
  /// In zh, this message translates to:
  /// **'正在重建游戏页面…'**
  String get gameRenderingModeChanging;

  /// No description provided for @gameRenderingModeApplied.
  ///
  /// In zh, this message translates to:
  /// **'渲染模式已切换。'**
  String get gameRenderingModeApplied;

  /// No description provided for @gameRenderingModeFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换失败，已保留或回退到安全模式。'**
  String get gameRenderingModeFailed;

  /// No description provided for @nativeGameSurfaceSwitchRenderingModeHint.
  ///
  /// In zh, this message translates to:
  /// **'当前设备暂不兼容此模式。请滚动左侧菜单，前往【设置 - 画面与声音】切换渲染模式。'**
  String get nativeGameSurfaceSwitchRenderingModeHint;

  /// No description provided for @nativeGameSurfacePageInitializationFailed.
  ///
  /// In zh, this message translates to:
  /// **'游戏页面初始化失败 [{stage}]：{errorType}'**
  String nativeGameSurfacePageInitializationFailed(
    String stage,
    String errorType,
  );

  /// No description provided for @senka.
  ///
  /// In zh, this message translates to:
  /// **'战果'**
  String get senka;

  /// No description provided for @ownedInventory.
  ///
  /// In zh, this message translates to:
  /// **'持有一览'**
  String get ownedInventory;

  /// No description provided for @improvement.
  ///
  /// In zh, this message translates to:
  /// **'改修'**
  String get improvement;

  /// No description provided for @briefing.
  ///
  /// In zh, this message translates to:
  /// **'简报'**
  String get briefing;

  /// No description provided for @check.
  ///
  /// In zh, this message translates to:
  /// **'检查'**
  String get check;

  /// No description provided for @restoreDefaultOrder.
  ///
  /// In zh, this message translates to:
  /// **'还原默认排序'**
  String get restoreDefaultOrder;

  /// No description provided for @sortAscending.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get sortDescending;

  /// No description provided for @sortPriority.
  ///
  /// In zh, this message translates to:
  /// **'第{priority}优先级'**
  String sortPriority(int priority);

  /// No description provided for @sortLockedState.
  ///
  /// In zh, this message translates to:
  /// **'已锁定'**
  String get sortLockedState;

  /// No description provided for @sortTemporaryState.
  ///
  /// In zh, this message translates to:
  /// **'临时排序'**
  String get sortTemporaryState;

  /// No description provided for @sortHeaderHint.
  ///
  /// In zh, this message translates to:
  /// **'点击切换排序；长按或按 Shift+Enter 锁定'**
  String get sortHeaderHint;

  /// No description provided for @sortHeaderLockedHint.
  ///
  /// In zh, this message translates to:
  /// **'点击切换排序方向；长按或按 Shift+Enter 解除锁定'**
  String get sortHeaderLockedHint;

  /// No description provided for @sortLockAction.
  ///
  /// In zh, this message translates to:
  /// **'锁定为下一优先级'**
  String get sortLockAction;

  /// No description provided for @sortUnlockAction.
  ///
  /// In zh, this message translates to:
  /// **'解除当前排序锁定'**
  String get sortUnlockAction;

  /// No description provided for @settingsTabScreen.
  ///
  /// In zh, this message translates to:
  /// **'画面与声音'**
  String get settingsTabScreen;

  /// No description provided for @settingsTabSound.
  ///
  /// In zh, this message translates to:
  /// **'声音'**
  String get settingsTabSound;

  /// No description provided for @settingsTabBattle.
  ///
  /// In zh, this message translates to:
  /// **'战斗'**
  String get settingsTabBattle;

  /// No description provided for @settingsTabNotification.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get settingsTabNotification;

  /// No description provided for @settingsTabNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get settingsTabNetwork;

  /// No description provided for @settingsTabData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsTabData;

  /// No description provided for @settingsTabAboutSupport.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsTabAboutSupport;

  /// No description provided for @notificationSectionSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统通知状态'**
  String get notificationSectionSystem;

  /// No description provided for @notificationSectionSystemDesc.
  ///
  /// In zh, this message translates to:
  /// **'授权通知与精确提醒权限，可确保在锁屏或后台时远征、入渠等提醒准时弹出，避免被系统省电策略延迟。点击对应项可直接前往系统设置开启。'**
  String get notificationSectionSystemDesc;

  /// No description provided for @notificationPermissionGranted.
  ///
  /// In zh, this message translates to:
  /// **'通知权限已授予'**
  String get notificationPermissionGranted;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'通知权限未授予'**
  String get notificationPermissionDenied;

  /// No description provided for @notificationExactAlarmGranted.
  ///
  /// In zh, this message translates to:
  /// **'精确提醒已授权'**
  String get notificationExactAlarmGranted;

  /// No description provided for @notificationExactAlarmDenied.
  ///
  /// In zh, this message translates to:
  /// **'精确提醒未授权，将使用省电兼容模式'**
  String get notificationExactAlarmDenied;

  /// No description provided for @notificationChannelsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'通知渠道可用'**
  String get notificationChannelsEnabled;

  /// No description provided for @notificationChannelsDisabled.
  ///
  /// In zh, this message translates to:
  /// **'通知渠道已被系统关闭'**
  String get notificationChannelsDisabled;

  /// No description provided for @notificationSectionGeneral.
  ///
  /// In zh, this message translates to:
  /// **'全局通知服务'**
  String get notificationSectionGeneral;

  /// No description provided for @notificationEnableMaster.
  ///
  /// In zh, this message translates to:
  /// **'启用通知服务'**
  String get notificationEnableMaster;

  /// No description provided for @notificationSound.
  ///
  /// In zh, this message translates to:
  /// **'通知提示音'**
  String get notificationSound;

  /// No description provided for @notificationVibration.
  ///
  /// In zh, this message translates to:
  /// **'振动提醒'**
  String get notificationVibration;

  /// No description provided for @notificationSectionOngoing.
  ///
  /// In zh, this message translates to:
  /// **'后台常驻进行中进度'**
  String get notificationSectionOngoing;

  /// No description provided for @notificationOngoingLive.
  ///
  /// In zh, this message translates to:
  /// **'常驻实时进度条卡片'**
  String get notificationOngoingLive;

  /// No description provided for @notificationProgress.
  ///
  /// In zh, this message translates to:
  /// **'进度条'**
  String get notificationProgress;

  /// No description provided for @notificationPercent.
  ///
  /// In zh, this message translates to:
  /// **'百分比'**
  String get notificationPercent;

  /// No description provided for @notificationCountdown.
  ///
  /// In zh, this message translates to:
  /// **'实时倒计时'**
  String get notificationCountdown;

  /// No description provided for @notificationSectionTypes.
  ///
  /// In zh, this message translates to:
  /// **'通知类型与时机'**
  String get notificationSectionTypes;

  /// No description provided for @notificationExpedition.
  ///
  /// In zh, this message translates to:
  /// **'远征'**
  String get notificationExpedition;

  /// No description provided for @notificationRepair.
  ///
  /// In zh, this message translates to:
  /// **'入渠'**
  String get notificationRepair;

  /// No description provided for @notificationAnchorage.
  ///
  /// In zh, this message translates to:
  /// **'泊地'**
  String get notificationAnchorage;

  /// No description provided for @notificationConstruction.
  ///
  /// In zh, this message translates to:
  /// **'建造'**
  String get notificationConstruction;

  /// No description provided for @notificationMorale.
  ///
  /// In zh, this message translates to:
  /// **'疲劳 / 刷闪'**
  String get notificationMorale;

  /// No description provided for @notificationPunctual.
  ///
  /// In zh, this message translates to:
  /// **'准点'**
  String get notificationPunctual;

  /// No description provided for @notificationPreempt30s.
  ///
  /// In zh, this message translates to:
  /// **'提前 30 秒'**
  String get notificationPreempt30s;

  /// No description provided for @notificationPreempt60s.
  ///
  /// In zh, this message translates to:
  /// **'提前 60 秒'**
  String get notificationPreempt60s;

  /// No description provided for @notificationPreempt120s.
  ///
  /// In zh, this message translates to:
  /// **'提前 2 分钟'**
  String get notificationPreempt120s;

  /// No description provided for @notificationRepairPunctual.
  ///
  /// In zh, this message translates to:
  /// **'准点'**
  String get notificationRepairPunctual;

  /// No description provided for @notificationAnchorage20m.
  ///
  /// In zh, this message translates to:
  /// **'满 20 分钟首轮'**
  String get notificationAnchorage20m;

  /// No description provided for @notificationAnchorageFull.
  ///
  /// In zh, this message translates to:
  /// **'全部修满'**
  String get notificationAnchorageFull;

  /// No description provided for @notificationAnchorageBoth.
  ///
  /// In zh, this message translates to:
  /// **'双阶段均提醒'**
  String get notificationAnchorageBoth;

  /// No description provided for @frameRateSettingsSection.
  ///
  /// In zh, this message translates to:
  /// **'帧率设置'**
  String get frameRateSettingsSection;

  /// No description provided for @battleAlertsSection.
  ///
  /// In zh, this message translates to:
  /// **'战斗提醒'**
  String get battleAlertsSection;

  /// No description provided for @battleDamageVibration.
  ///
  /// In zh, this message translates to:
  /// **'战斗受损震动提醒'**
  String get battleDamageVibration;

  /// No description provided for @battleDamageVibrationDesc.
  ///
  /// In zh, this message translates to:
  /// **'我方舰娘在战斗中刚进入中破或大破时震动提醒。'**
  String get battleDamageVibrationDesc;

  /// No description provided for @battleStatusEffectsSection.
  ///
  /// In zh, this message translates to:
  /// **'战斗状态效果'**
  String get battleStatusEffectsSection;

  /// No description provided for @battleStatusEffectsEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用状态效果'**
  String get battleStatusEffectsEnabled;

  /// No description provided for @battleStatusEffectsEnabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'统一开启或关闭受损闪烁、受损震动与士气闪光。'**
  String get battleStatusEffectsEnabledDesc;

  /// No description provided for @battleEffectDisplayScope.
  ///
  /// In zh, this message translates to:
  /// **'画面显示范围'**
  String get battleEffectDisplayScope;

  /// No description provided for @battleEffectDisplayScopeDesc.
  ///
  /// In zh, this message translates to:
  /// **'决定受损闪烁与士气闪光出现在哪些舰娘画面。'**
  String get battleEffectDisplayScopeDesc;

  /// No description provided for @battleEffectScopePredictionOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅未卜先知'**
  String get battleEffectScopePredictionOnly;

  /// No description provided for @battleEffectScopeFleetOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅编队'**
  String get battleEffectScopeFleetOnly;

  /// No description provided for @battleEffectScopeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get battleEffectScopeAll;

  /// No description provided for @battleDamagePulse.
  ///
  /// In zh, this message translates to:
  /// **'受损闪烁'**
  String get battleDamagePulse;

  /// No description provided for @battleDamagePulseDesc.
  ///
  /// In zh, this message translates to:
  /// **'按当前 HP 损伤等级控制头像边框的动态闪烁。'**
  String get battleDamagePulseDesc;

  /// No description provided for @battleDamageVibrationEffect.
  ///
  /// In zh, this message translates to:
  /// **'受损震动'**
  String get battleDamageVibrationEffect;

  /// No description provided for @battleDamageVibrationEffectDesc.
  ///
  /// In zh, this message translates to:
  /// **'我方舰娘在战斗中刚进入所选损伤状态时震动。'**
  String get battleDamageVibrationEffectDesc;

  /// No description provided for @battleMoraleSparkle.
  ///
  /// In zh, this message translates to:
  /// **'士气闪光效果'**
  String get battleMoraleSparkle;

  /// No description provided for @battleMoraleSparkleDesc.
  ///
  /// In zh, this message translates to:
  /// **'Cond ≥ 50 时在舰娘头像周围显示星光动画；不影响疲劳脸和疲劳警告。'**
  String get battleMoraleSparkleDesc;

  /// No description provided for @battleEffectOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get battleEffectOff;

  /// No description provided for @battleEffectMinorOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅小破'**
  String get battleEffectMinorOnly;

  /// No description provided for @battleEffectModerateOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅中破'**
  String get battleEffectModerateOnly;

  /// No description provided for @battleEffectHeavyOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅大破'**
  String get battleEffectHeavyOnly;

  /// No description provided for @battleEffectAll.
  ///
  /// In zh, this message translates to:
  /// **'全部开启'**
  String get battleEffectAll;

  /// No description provided for @battlePredictionSection.
  ///
  /// In zh, this message translates to:
  /// **'战斗预测'**
  String get battlePredictionSection;

  /// No description provided for @battleEnemyPreviewPortraits.
  ///
  /// In zh, this message translates to:
  /// **'战前敌方立绘'**
  String get battleEnemyPreviewPortraits;

  /// No description provided for @battleEnemyPreviewPortraitsDesc.
  ///
  /// In zh, this message translates to:
  /// **'在未卜先知中显示战前敌方立绘。'**
  String get battleEnemyPreviewPortraitsDesc;

  /// No description provided for @battleLastFormationHint.
  ///
  /// In zh, this message translates to:
  /// **'显示上次选择的阵形'**
  String get battleLastFormationHint;

  /// No description provided for @battleLastFormationHintDesc.
  ///
  /// In zh, this message translates to:
  /// **'到达出击节点时，在未卜先知中提示该点上次使用的阵形。'**
  String get battleLastFormationHintDesc;

  /// No description provided for @battleLastFormation.
  ///
  /// In zh, this message translates to:
  /// **'上次：{formation}'**
  String battleLastFormation(String formation);

  /// No description provided for @improvementDatasetTitle.
  ///
  /// In zh, this message translates to:
  /// **'改修规划资料'**
  String get improvementDatasetTitle;

  /// No description provided for @improvementDatasetVersion.
  ///
  /// In zh, this message translates to:
  /// **'资料版本 {version}'**
  String improvementDatasetVersion(String version);

  /// No description provided for @improvementDatasetNeverChecked.
  ///
  /// In zh, this message translates to:
  /// **'尚未手动检查'**
  String get improvementDatasetNeverChecked;

  /// No description provided for @improvementDatasetLastChecked.
  ///
  /// In zh, this message translates to:
  /// **'最近检查 {time}'**
  String improvementDatasetLastChecked(String time);

  /// No description provided for @improvementDatasetManualUpdate.
  ///
  /// In zh, this message translates to:
  /// **'手动更新改修资料'**
  String get improvementDatasetManualUpdate;

  /// No description provided for @improvementDatasetUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'当前已经是最新资料（{version}）'**
  String improvementDatasetUpToDate(String version);

  /// No description provided for @improvementDatasetUpdated.
  ///
  /// In zh, this message translates to:
  /// **'改修资料已从 {oldVersion} 更新到 {newVersion}，页面已立即刷新。'**
  String improvementDatasetUpdated(String oldVersion, String newVersion);

  /// No description provided for @improvementDatasetNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，已继续使用本地资料（{version}）。'**
  String improvementDatasetNetworkError(String version);

  /// No description provided for @improvementDatasetValidationError.
  ///
  /// In zh, this message translates to:
  /// **'远程资料校验失败，未替换本地资料（{version}）。'**
  String improvementDatasetValidationError(String version);

  /// No description provided for @improvementDatasetStorageError.
  ///
  /// In zh, this message translates to:
  /// **'资料保存失败，未替换本地资料（{version}）。'**
  String improvementDatasetStorageError(String version);

  /// No description provided for @networkValidationHostEmpty.
  ///
  /// In zh, this message translates to:
  /// **'地址不能为空'**
  String get networkValidationHostEmpty;

  /// No description provided for @networkValidationControlCharacter.
  ///
  /// In zh, this message translates to:
  /// **'不允许包含换行或控制字符'**
  String get networkValidationControlCharacter;

  /// No description provided for @networkValidationHttpScheme.
  ///
  /// In zh, this message translates to:
  /// **'地址中不要包含 http://，只需填写服务器地址。'**
  String get networkValidationHttpScheme;

  /// No description provided for @networkValidationSocksScheme.
  ///
  /// In zh, this message translates to:
  /// **'地址中不要包含 socks://，只需填写服务器地址。'**
  String get networkValidationSocksScheme;

  /// No description provided for @networkValidationScheme.
  ///
  /// In zh, this message translates to:
  /// **'地址中不要包含协议头'**
  String get networkValidationScheme;

  /// No description provided for @networkValidationPath.
  ///
  /// In zh, this message translates to:
  /// **'不允许包含路径'**
  String get networkValidationPath;

  /// No description provided for @networkValidationCredentials.
  ///
  /// In zh, this message translates to:
  /// **'不允许包含用户名或密码'**
  String get networkValidationCredentials;

  /// No description provided for @networkValidationIpv6.
  ///
  /// In zh, this message translates to:
  /// **'IPv6 地址格式不正确（含有非法字符）'**
  String get networkValidationIpv6;

  /// No description provided for @networkValidationPortEmpty.
  ///
  /// In zh, this message translates to:
  /// **'端口不能为空'**
  String get networkValidationPortEmpty;

  /// No description provided for @networkValidationPortDecimal.
  ///
  /// In zh, this message translates to:
  /// **'端口不允许使用小数'**
  String get networkValidationPortDecimal;

  /// No description provided for @networkValidationPortNegative.
  ///
  /// In zh, this message translates to:
  /// **'端口不允许使用负数'**
  String get networkValidationPortNegative;

  /// No description provided for @networkValidationPortZero.
  ///
  /// In zh, this message translates to:
  /// **'端口不能为 0'**
  String get networkValidationPortZero;

  /// No description provided for @networkValidationPortInteger.
  ///
  /// In zh, this message translates to:
  /// **'端口必须为整数'**
  String get networkValidationPortInteger;

  /// No description provided for @networkValidationPortRange.
  ///
  /// In zh, this message translates to:
  /// **'端口范围为 1 至 65535'**
  String get networkValidationPortRange;

  /// No description provided for @gadgetBypassRestricted.
  ///
  /// In zh, this message translates to:
  /// **'受限'**
  String get gadgetBypassRestricted;

  /// No description provided for @networkProxyOperationBusy.
  ///
  /// In zh, this message translates to:
  /// **'代理设置正在应用中'**
  String get networkProxyOperationBusy;

  /// No description provided for @networkUnknownProxyMode.
  ///
  /// In zh, this message translates to:
  /// **'未知代理模式'**
  String get networkUnknownProxyMode;

  /// No description provided for @shipGirl.
  ///
  /// In zh, this message translates to:
  /// **'舰娘'**
  String get shipGirl;

  /// No description provided for @equipment.
  ///
  /// In zh, this message translates to:
  /// **'装备'**
  String get equipment;

  /// No description provided for @inventoryTypeSuffix.
  ///
  /// In zh, this message translates to:
  /// **' 种'**
  String get inventoryTypeSuffix;

  /// No description provided for @inventoryFilterResults.
  ///
  /// In zh, this message translates to:
  /// **'筛选结果 '**
  String get inventoryFilterResults;

  /// No description provided for @inventoryOwned.
  ///
  /// In zh, this message translates to:
  /// **'持有'**
  String get inventoryOwned;

  /// No description provided for @inventoryUnowned.
  ///
  /// In zh, this message translates to:
  /// **'未持有'**
  String get inventoryUnowned;

  /// No description provided for @unownedShipSummary.
  ///
  /// In zh, this message translates to:
  /// **'显示 {count} 艘 · 已排除 {excluded} 艘'**
  String unownedShipSummary(int count, int excluded);

  /// No description provided for @unownedShipExcludedLabel.
  ///
  /// In zh, this message translates to:
  /// **'已排除'**
  String get unownedShipExcludedLabel;

  /// No description provided for @unownedShipReminderHint.
  ///
  /// In zh, this message translates to:
  /// **'获得未勾选的舰娘时，将正常提醒并震动；勾选的舰娘则不会提醒。'**
  String get unownedShipReminderHint;

  /// No description provided for @clearNewShipExclusions.
  ///
  /// In zh, this message translates to:
  /// **'清除排除'**
  String get clearNewShipExclusions;

  /// No description provided for @resetFilter.
  ///
  /// In zh, this message translates to:
  /// **'重置筛选'**
  String get resetFilter;

  /// No description provided for @unownedEquipmentSummary.
  ///
  /// In zh, this message translates to:
  /// **'显示 {count} 件未持有装备'**
  String unownedEquipmentSummary(int count);

  /// No description provided for @otherType.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get otherType;

  /// No description provided for @newShipFallbackName.
  ///
  /// In zh, this message translates to:
  /// **'舰娘 No.{id}'**
  String newShipFallbackName(int id);

  /// No description provided for @newShipAlertTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现未持有舰娘'**
  String get newShipAlertTitle;

  /// No description provided for @newShipAlertBody.
  ///
  /// In zh, this message translates to:
  /// **'{names}，请不要忘记上锁'**
  String newShipAlertBody(String names);

  /// No description provided for @acknowledge.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get acknowledge;

  /// No description provided for @shipName.
  ///
  /// In zh, this message translates to:
  /// **'舰名'**
  String get shipName;

  /// No description provided for @shipType.
  ///
  /// In zh, this message translates to:
  /// **'舰种'**
  String get shipType;

  /// No description provided for @level.
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get level;

  /// No description provided for @armor.
  ///
  /// In zh, this message translates to:
  /// **'装甲'**
  String get armor;

  /// No description provided for @luck.
  ///
  /// In zh, this message translates to:
  /// **'幸运'**
  String get luck;

  /// No description provided for @evasion.
  ///
  /// In zh, this message translates to:
  /// **'回避'**
  String get evasion;

  /// No description provided for @lockedStatus.
  ///
  /// In zh, this message translates to:
  /// **'锁定'**
  String get lockedStatus;

  /// No description provided for @equipmentName.
  ///
  /// In zh, this message translates to:
  /// **'装备名称'**
  String get equipmentName;

  /// No description provided for @equipmentTotalRemaining.
  ///
  /// In zh, this message translates to:
  /// **'总数（剩余）'**
  String get equipmentTotalRemaining;

  /// No description provided for @equipmentImprovementProficiency.
  ///
  /// In zh, this message translates to:
  /// **'改修／熟练度'**
  String get equipmentImprovementProficiency;

  /// No description provided for @equipmentOfficialId.
  ///
  /// In zh, this message translates to:
  /// **'官方ID'**
  String get equipmentOfficialId;

  /// No description provided for @equipmentInstanceId.
  ///
  /// In zh, this message translates to:
  /// **'实例ID'**
  String get equipmentInstanceId;

  /// No description provided for @equipmentUsage.
  ///
  /// In zh, this message translates to:
  /// **'着装情况'**
  String get equipmentUsage;

  /// No description provided for @highSpeedPlus.
  ///
  /// In zh, this message translates to:
  /// **'高速+'**
  String get highSpeedPlus;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @equipmentMainGun.
  ///
  /// In zh, this message translates to:
  /// **'主炮'**
  String get equipmentMainGun;

  /// No description provided for @equipmentSecondaryGun.
  ///
  /// In zh, this message translates to:
  /// **'副炮／高角炮'**
  String get equipmentSecondaryGun;

  /// No description provided for @equipmentMachineGun.
  ///
  /// In zh, this message translates to:
  /// **'机枪'**
  String get equipmentMachineGun;

  /// No description provided for @equipmentTorpedo.
  ///
  /// In zh, this message translates to:
  /// **'鱼雷／甲标'**
  String get equipmentTorpedo;

  /// No description provided for @equipmentCarrierAircraft.
  ///
  /// In zh, this message translates to:
  /// **'舰载机'**
  String get equipmentCarrierAircraft;

  /// No description provided for @equipmentSeaplane.
  ///
  /// In zh, this message translates to:
  /// **'水上机'**
  String get equipmentSeaplane;

  /// No description provided for @equipmentLandBasedAircraft.
  ///
  /// In zh, this message translates to:
  /// **'陆航'**
  String get equipmentLandBasedAircraft;

  /// No description provided for @equipmentRadar.
  ///
  /// In zh, this message translates to:
  /// **'电探'**
  String get equipmentRadar;

  /// No description provided for @equipmentLandingTransport.
  ///
  /// In zh, this message translates to:
  /// **'登陆／运输'**
  String get equipmentLandingTransport;

  /// No description provided for @equipmentSupport.
  ///
  /// In zh, this message translates to:
  /// **'辅助／其他'**
  String get equipmentSupport;

  /// No description provided for @questAll.
  ///
  /// In zh, this message translates to:
  /// **'全任务'**
  String get questAll;

  /// No description provided for @chineseTranslation.
  ///
  /// In zh, this message translates to:
  /// **'中文翻译'**
  String get chineseTranslation;

  /// No description provided for @searchQuest.
  ///
  /// In zh, this message translates to:
  /// **'搜索任务'**
  String get searchQuest;

  /// No description provided for @filterQuest.
  ///
  /// In zh, this message translates to:
  /// **'筛选任务'**
  String get filterQuest;

  /// No description provided for @searchQuestHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索编号、任务名、说明或奖励；空格分隔任一关键词'**
  String get searchQuestHint;

  /// No description provided for @questAvailable.
  ///
  /// In zh, this message translates to:
  /// **'未接取'**
  String get questAvailable;

  /// No description provided for @questAcceptedOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅已接取（含待领取）'**
  String get questAcceptedOnly;

  /// No description provided for @questClaimable.
  ///
  /// In zh, this message translates to:
  /// **'待领取'**
  String get questClaimable;

  /// No description provided for @questInferredCompleted.
  ///
  /// In zh, this message translates to:
  /// **'推算完成'**
  String get questInferredCompleted;

  /// No description provided for @questStateUnknown.
  ///
  /// In zh, this message translates to:
  /// **'状态未知'**
  String get questStateUnknown;

  /// No description provided for @questFilterHelp.
  ///
  /// In zh, this message translates to:
  /// **'已解锁包含未接取、进行中和待领取；未解锁包含状态未知；已完成包含待领取和推算完成。'**
  String get questFilterHelp;

  /// No description provided for @questNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的任务'**
  String get questNoResults;

  /// No description provided for @questNoResultsHint.
  ///
  /// In zh, this message translates to:
  /// **'试试调整搜索内容或清除筛选条件。'**
  String get questNoResultsHint;

  /// No description provided for @questResultsCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个任务'**
  String questResultsCount(int count);

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @clearAll.
  ///
  /// In zh, this message translates to:
  /// **'清除全部'**
  String get clearAll;

  /// No description provided for @questType.
  ///
  /// In zh, this message translates to:
  /// **'任务类型'**
  String get questType;

  /// No description provided for @allTypes.
  ///
  /// In zh, this message translates to:
  /// **'全部类型'**
  String get allTypes;

  /// No description provided for @questFormation.
  ///
  /// In zh, this message translates to:
  /// **'编成'**
  String get questFormation;

  /// No description provided for @questSortie.
  ///
  /// In zh, this message translates to:
  /// **'出击'**
  String get questSortie;

  /// No description provided for @questExercise.
  ///
  /// In zh, this message translates to:
  /// **'演习'**
  String get questExercise;

  /// No description provided for @questSupplyRepair.
  ///
  /// In zh, this message translates to:
  /// **'补给/入渠'**
  String get questSupplyRepair;

  /// No description provided for @questFactory.
  ///
  /// In zh, this message translates to:
  /// **'工厂'**
  String get questFactory;

  /// No description provided for @questRemodeling.
  ///
  /// In zh, this message translates to:
  /// **'改装'**
  String get questRemodeling;

  /// No description provided for @questPeriod.
  ///
  /// In zh, this message translates to:
  /// **'任务周期'**
  String get questPeriod;

  /// No description provided for @allPeriods.
  ///
  /// In zh, this message translates to:
  /// **'全部周期'**
  String get allPeriods;

  /// No description provided for @questSeasonal.
  ///
  /// In zh, this message translates to:
  /// **'季常'**
  String get questSeasonal;

  /// No description provided for @questYearly.
  ///
  /// In zh, this message translates to:
  /// **'年常'**
  String get questYearly;

  /// No description provided for @unlockStatus.
  ///
  /// In zh, this message translates to:
  /// **'解锁状态'**
  String get unlockStatus;

  /// No description provided for @allStatuses.
  ///
  /// In zh, this message translates to:
  /// **'全部状态'**
  String get allStatuses;

  /// No description provided for @questUnlocked.
  ///
  /// In zh, this message translates to:
  /// **'已解锁'**
  String get questUnlocked;

  /// No description provided for @questLocked.
  ///
  /// In zh, this message translates to:
  /// **'未解锁'**
  String get questLocked;

  /// No description provided for @noDescription.
  ///
  /// In zh, this message translates to:
  /// **'暂无说明'**
  String get noDescription;

  /// No description provided for @completionConditions.
  ///
  /// In zh, this message translates to:
  /// **'完成条件'**
  String get completionConditions;

  /// No description provided for @questRelations.
  ///
  /// In zh, this message translates to:
  /// **'任务关系'**
  String get questRelations;

  /// No description provided for @prerequisiteQuests.
  ///
  /// In zh, this message translates to:
  /// **'前置任务'**
  String get prerequisiteQuests;

  /// No description provided for @followingQuests.
  ///
  /// In zh, this message translates to:
  /// **'后置任务'**
  String get followingQuests;

  /// No description provided for @notCompleted.
  ///
  /// In zh, this message translates to:
  /// **'未完成'**
  String get notCompleted;

  /// No description provided for @gameResourceCacheTitle.
  ///
  /// In zh, this message translates to:
  /// **'游戏资源本地缓存'**
  String get gameResourceCacheTitle;

  /// No description provided for @gameResourceCacheDesc.
  ///
  /// In zh, this message translates to:
  /// **'资源从舰队 Collection 官方服务器获取；缓存可随时清除。'**
  String get gameResourceCacheDesc;

  /// No description provided for @gameResourceCacheNone.
  ///
  /// In zh, this message translates to:
  /// **'临时缓存'**
  String get gameResourceCacheNone;

  /// No description provided for @gameResourceCacheNoneDesc.
  ///
  /// In zh, this message translates to:
  /// **'不预下载资源；游玩时按需缓存，缓存最多保留 7 天且占用不超过 1 GB，过期或超出上限时将自动清理。'**
  String get gameResourceCacheNoneDesc;

  /// No description provided for @gameResourceCacheLight.
  ///
  /// In zh, this message translates to:
  /// **'轻度缓存'**
  String get gameResourceCacheLight;

  /// No description provided for @gameResourceCacheLightDesc.
  ///
  /// In zh, this message translates to:
  /// **'缓存启动文件、常用 UI、已持有舰娘立绘和装备资源。'**
  String get gameResourceCacheLightDesc;

  /// No description provided for @gameResourceCacheFull.
  ///
  /// In zh, this message translates to:
  /// **'本地缓存'**
  String get gameResourceCacheFull;

  /// No description provided for @gameResourceCacheFullDesc.
  ///
  /// In zh, this message translates to:
  /// **'预下载固定基础资源清单（约 5.49 GB）；新内容会在游玩时自动缓存。'**
  String get gameResourceCacheFullDesc;

  /// No description provided for @gameResourceCacheStart.
  ///
  /// In zh, this message translates to:
  /// **'开始下载'**
  String get gameResourceCacheStart;

  /// No description provided for @gameResourceCachePause.
  ///
  /// In zh, this message translates to:
  /// **'暂停下载'**
  String get gameResourceCachePause;

  /// No description provided for @gameResourceCacheResume.
  ///
  /// In zh, this message translates to:
  /// **'继续下载'**
  String get gameResourceCacheResume;

  /// No description provided for @gameResourceCacheCheck.
  ///
  /// In zh, this message translates to:
  /// **'检查完整性'**
  String get gameResourceCacheCheck;

  /// No description provided for @gameResourceCacheRepair.
  ///
  /// In zh, this message translates to:
  /// **'补齐或修复'**
  String get gameResourceCacheRepair;

  /// No description provided for @gameResourceCacheClear.
  ///
  /// In zh, this message translates to:
  /// **'清除本地缓存'**
  String get gameResourceCacheClear;

  /// No description provided for @gameResourceCacheIntegrityComplete.
  ///
  /// In zh, this message translates to:
  /// **'当前缓存完整'**
  String get gameResourceCacheIntegrityComplete;

  /// No description provided for @gameResourceCacheMissing.
  ///
  /// In zh, this message translates to:
  /// **'缺失'**
  String get gameResourceCacheMissing;

  /// No description provided for @gameResourceCacheDamaged.
  ///
  /// In zh, this message translates to:
  /// **'损坏'**
  String get gameResourceCacheDamaged;

  /// No description provided for @gameResourceCacheOutdated.
  ///
  /// In zh, this message translates to:
  /// **'待校验'**
  String get gameResourceCacheOutdated;

  /// No description provided for @gameResourceCacheItems.
  ///
  /// In zh, this message translates to:
  /// **'项'**
  String get gameResourceCacheItems;

  /// No description provided for @gameResourceCacheStoredSize.
  ///
  /// In zh, this message translates to:
  /// **'已缓存 {size}'**
  String gameResourceCacheStoredSize(String size);

  /// No description provided for @gameResourceCacheIntegritySummary.
  ///
  /// In zh, this message translates to:
  /// **'缺失 {missing} 项 · 损坏 {damaged} 项 · 待校验 {pending} 项'**
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  );

  /// No description provided for @gameResourceCachePendingRetained.
  ///
  /// In zh, this message translates to:
  /// **'待校验资源仍保留在本地，不会自动删除。'**
  String get gameResourceCachePendingRetained;

  /// No description provided for @gameResourceCacheDownloadConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认下载缓存？'**
  String get gameResourceCacheDownloadConfirmTitle;

  /// No description provided for @gameResourceCacheDownloadConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'将从官方服务器批量下载所选模式的资源，可随时暂停并继续。'**
  String get gameResourceCacheDownloadConfirmDesc;

  /// No description provided for @gameResourceCacheMobileConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前正在使用移动网络。继续将消耗移动数据流量，是否允许本次下载？'**
  String get gameResourceCacheMobileConfirmDesc;

  /// No description provided for @gameResourceCacheWaitingForWifi.
  ///
  /// In zh, this message translates to:
  /// **'正在等待 Wi-Fi，连接后会自动继续下载。'**
  String get gameResourceCacheWaitingForWifi;

  /// No description provided for @gameResourceCacheClearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除游戏资源缓存？'**
  String get gameResourceCacheClearConfirmTitle;

  /// No description provided for @gameResourceCacheClearConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'将删除已下载的游戏资源；模式设置会保留。'**
  String get gameResourceCacheClearConfirmDesc;

  /// No description provided for @gameResourceCacheCapacityBlocked.
  ///
  /// In zh, this message translates to:
  /// **'可用存储空间不足，或本地游戏资源缓存已达到 50 GB 上限。'**
  String get gameResourceCacheCapacityBlocked;

  /// No description provided for @gameResourceCacheActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'缓存操作未完成，请稍后重试。'**
  String get gameResourceCacheActionFailed;

  /// No description provided for @confirmGameRefreshTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认刷新游戏？'**
  String get confirmGameRefreshTitle;

  /// No description provided for @gameRefreshDialogDescription.
  ///
  /// In zh, this message translates to:
  /// **'确定要刷新游戏吗？\n\n“刷新游戏页面”与浏览器刷新效果相同。\n“重新载入游戏”只重新载入游戏框架部分，通常更快，但可能导致猫袭或网络异常。请自行承担风险。'**
  String get gameRefreshDialogDescription;

  /// No description provided for @refreshGamePage.
  ///
  /// In zh, this message translates to:
  /// **'刷新游戏页面'**
  String get refreshGamePage;

  /// No description provided for @reloadGame.
  ///
  /// In zh, this message translates to:
  /// **'重新载入游戏'**
  String get reloadGame;

  /// No description provided for @gameFrameNotFound.
  ///
  /// In zh, this message translates to:
  /// **'尚未找到游戏框架，请进入游戏后重试。'**
  String get gameFrameNotFound;

  /// No description provided for @gameHtmlWrapNotFound.
  ///
  /// In zh, this message translates to:
  /// **'尚未找到游戏本体，请等待页面载入后重试。'**
  String get gameHtmlWrapNotFound;

  /// No description provided for @gameFrameReloadBlocked.
  ///
  /// In zh, this message translates to:
  /// **'游戏框架未能重新载入，请稍后重试。'**
  String get gameFrameReloadBlocked;

  /// No description provided for @gameFrameReloadUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备的 Android WebView 太旧，不支持对子框架注入。'**
  String get gameFrameReloadUnsupported;

  /// No description provided for @logbookResourceDrop.
  ///
  /// In zh, this message translates to:
  /// **'资源掉落'**
  String get logbookResourceDrop;

  /// No description provided for @logbookItemDrop.
  ///
  /// In zh, this message translates to:
  /// **'道具掉落'**
  String get logbookItemDrop;

  /// No description provided for @logbookResourceNode.
  ///
  /// In zh, this message translates to:
  /// **'资源节点'**
  String get logbookResourceNode;

  /// No description provided for @logbookFriendFormation.
  ///
  /// In zh, this message translates to:
  /// **'我方阵形'**
  String get logbookFriendFormation;

  /// No description provided for @logbookEnemyFormation.
  ///
  /// In zh, this message translates to:
  /// **'敌方阵形'**
  String get logbookEnemyFormation;

  /// No description provided for @logbookAirSuperiority.
  ///
  /// In zh, this message translates to:
  /// **'制空状态'**
  String get logbookAirSuperiority;

  /// No description provided for @airSuperiorityParity.
  ///
  /// In zh, this message translates to:
  /// **'均衡'**
  String get airSuperiorityParity;

  /// No description provided for @airSuperioritySecured.
  ///
  /// In zh, this message translates to:
  /// **'确保'**
  String get airSuperioritySecured;

  /// No description provided for @airSuperiorityAdvantage.
  ///
  /// In zh, this message translates to:
  /// **'优势'**
  String get airSuperiorityAdvantage;

  /// No description provided for @airSuperiorityDisadvantage.
  ///
  /// In zh, this message translates to:
  /// **'劣势'**
  String get airSuperiorityDisadvantage;

  /// No description provided for @airSuperiorityLost.
  ///
  /// In zh, this message translates to:
  /// **'丧失'**
  String get airSuperiorityLost;

  /// No description provided for @logbookHeavyDamageShips.
  ///
  /// In zh, this message translates to:
  /// **'大破舰娘'**
  String get logbookHeavyDamageShips;

  /// No description provided for @gameConnectorTitle.
  ///
  /// In zh, this message translates to:
  /// **'游戏连接'**
  String get gameConnectorTitle;

  /// No description provided for @gameConnectorYahagi.
  ///
  /// In zh, this message translates to:
  /// **'Yahagi 连接'**
  String get gameConnectorYahagi;

  /// No description provided for @gameConnectorYahagiDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用当前 DMM 官方登录入口。'**
  String get gameConnectorYahagiDesc;

  /// No description provided for @gameConnectorOoi.
  ///
  /// In zh, this message translates to:
  /// **'OOI 连接（实验性）'**
  String get gameConnectorOoi;

  /// No description provided for @gameConnectorOoiDesc.
  ///
  /// In zh, this message translates to:
  /// **'原样打开 ooi.moe 登录页，由你选择模式 1、3 或 4。'**
  String get gameConnectorOoiDesc;

  /// No description provided for @gameConnectorConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换游戏连接？'**
  String get gameConnectorConfirmTitle;

  /// No description provided for @gameConnectorOoiRisk.
  ///
  /// In zh, this message translates to:
  /// **'账号凭据将提交给第三方站点 ooi.moe；Yahagi 不读取、不保存、不自动填写账号或密码。'**
  String get gameConnectorOoiRisk;

  /// No description provided for @gameConnectorActiveWarning.
  ///
  /// In zh, this message translates to:
  /// **'切换会中断当前游戏页面并返回目标登录入口。'**
  String get gameConnectorActiveWarning;

  /// No description provided for @gameConnectorApplied.
  ///
  /// In zh, this message translates to:
  /// **'游戏连接已切换。'**
  String get gameConnectorApplied;

  /// No description provided for @gameConnectorSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接选择保存失败，当前连接未改变。'**
  String get gameConnectorSaveFailed;

  /// No description provided for @gameConnectorNavigationFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接已保存，但登录页面打开失败，请重试。'**
  String get gameConnectorNavigationFailed;

  /// No description provided for @kcwikiReportSection.
  ///
  /// In zh, this message translates to:
  /// **'KCWiki 数据贡献'**
  String get kcwikiReportSection;

  /// No description provided for @kcwikiReportTitle.
  ///
  /// In zh, this message translates to:
  /// **'帮助 KCWiki 收集数据'**
  String get kcwikiReportTitle;

  /// No description provided for @kcwikiReportDisabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'默认开启，当前已关闭。关闭时不收集、不组包、不联网，也不影响游戏和本地功能。'**
  String get kcwikiReportDisabledDesc;

  /// No description provided for @kcwikiReportEnabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'已开启；仅发送带路、任务前置、战斗、友军、陆航/空袭和改修数据。'**
  String get kcwikiReportEnabledDesc;

  /// No description provided for @kcwikiReportConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启 KCWiki 数据贡献？'**
  String get kcwikiReportConfirmTitle;

  /// No description provided for @kcwikiReportConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后，应用会把带路、任务前置、战斗、友军、陆航/空袭和改修记录发送到 KCWiki 的 report2 服务器。该服务器目前使用未加密的 HTTP；不会发送登录令牌、Cookie 或请求头；上传失败不会阻塞游戏功能。'**
  String get kcwikiReportConfirmDesc;

  /// No description provided for @kcwikiReportEnable.
  ///
  /// In zh, this message translates to:
  /// **'自愿开启'**
  String get kcwikiReportEnable;

  /// No description provided for @kcwikiReportSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'KCWiki 数据贡献设置保存失败，请重试。'**
  String get kcwikiReportSaveFailed;

  /// No description provided for @kcwikiReportCaptureFailed.
  ///
  /// In zh, this message translates to:
  /// **'KCWiki 数据收集切换失败：{error}'**
  String kcwikiReportCaptureFailed(String error);

  /// No description provided for @kcwikiReportWaiting.
  ///
  /// In zh, this message translates to:
  /// **'已开启，正在等待可贡献的数据。'**
  String get kcwikiReportWaiting;

  /// No description provided for @kcwikiReportProcessing.
  ///
  /// In zh, this message translates to:
  /// **'正在上传：{module} · {time}'**
  String kcwikiReportProcessing(String module, String time);

  /// No description provided for @kcwikiReportParseRecovered.
  ///
  /// In zh, this message translates to:
  /// **'大型数据解析超时已恢复，后续数据已继续处理 · {time}'**
  String kcwikiReportParseRecovered(String time);

  /// No description provided for @kcwikiReportFailureHttp.
  ///
  /// In zh, this message translates to:
  /// **'HTTP {status}'**
  String kcwikiReportFailureHttp(String status);

  /// No description provided for @kcwikiReportFailureTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get kcwikiReportFailureTimeout;

  /// No description provided for @kcwikiReportFailureNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络失败'**
  String get kcwikiReportFailureNetwork;

  /// No description provided for @kcwikiReportFailureBodyTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'数据超过单次上限'**
  String get kcwikiReportFailureBodyTooLarge;

  /// No description provided for @kcwikiReportFailureQueueFull.
  ///
  /// In zh, this message translates to:
  /// **'本地等待队列已满'**
  String get kcwikiReportFailureQueueFull;

  /// No description provided for @kcwikiReportFailureLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地处理失败'**
  String get kcwikiReportFailureLocal;

  /// No description provided for @kcwikiReportCounters.
  ///
  /// In zh, this message translates to:
  /// **'成功 {succeeded} · 失败 {failed} · 丢弃 {dropped}'**
  String kcwikiReportCounters(int succeeded, int failed, int dropped);

  /// No description provided for @kcwikiReportLastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'最近上传成功：{module} · {time} · 成功 {succeeded} · 失败 {failed} · 丢弃 {dropped}'**
  String kcwikiReportLastSuccess(
    String module,
    String time,
    int succeeded,
    int failed,
    int dropped,
  );

  /// No description provided for @kcwikiReportLastFailure.
  ///
  /// In zh, this message translates to:
  /// **'最近上传失败：{module}（{status}）· {time} · 成功 {succeeded} · 失败 {failed} · 丢弃 {dropped}'**
  String kcwikiReportLastFailure(
    String module,
    String status,
    String time,
    int succeeded,
    int failed,
    int dropped,
  );

  /// No description provided for @landBaseBrief.
  ///
  /// In zh, this message translates to:
  /// **'陆基简报'**
  String get landBaseBrief;

  /// No description provided for @landBaseNoData.
  ///
  /// In zh, this message translates to:
  /// **'无数据'**
  String get landBaseNoData;

  /// No description provided for @landBaseAreaFallback.
  ///
  /// In zh, this message translates to:
  /// **'海域 {areaId}'**
  String landBaseAreaFallback(int areaId);

  /// No description provided for @landBaseUnitCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 支航空队'**
  String landBaseUnitCount(int count);

  /// No description provided for @landBaseRange.
  ///
  /// In zh, this message translates to:
  /// **'航程'**
  String get landBaseRange;

  /// No description provided for @landBaseActionSortie.
  ///
  /// In zh, this message translates to:
  /// **'出击'**
  String get landBaseActionSortie;

  /// No description provided for @landBaseActionAirDefense.
  ///
  /// In zh, this message translates to:
  /// **'防空'**
  String get landBaseActionAirDefense;

  /// No description provided for @landBaseActionRest.
  ///
  /// In zh, this message translates to:
  /// **'休息'**
  String get landBaseActionRest;

  /// No description provided for @landBaseActionRetreat.
  ///
  /// In zh, this message translates to:
  /// **'退避'**
  String get landBaseActionRetreat;

  /// No description provided for @landBaseMissingPlanes.
  ///
  /// In zh, this message translates to:
  /// **'缺机'**
  String get landBaseMissingPlanes;

  /// No description provided for @landBaseRelocating.
  ///
  /// In zh, this message translates to:
  /// **'配置转换中'**
  String get landBaseRelocating;

  /// No description provided for @senkaInfoTab.
  ///
  /// In zh, this message translates to:
  /// **'战果信息'**
  String get senkaInfoTab;

  /// No description provided for @senkaCalendarTab.
  ///
  /// In zh, this message translates to:
  /// **'战果日历'**
  String get senkaCalendarTab;

  /// No description provided for @senkaCalculatorTab.
  ///
  /// In zh, this message translates to:
  /// **'战果计算'**
  String get senkaCalculatorTab;

  /// No description provided for @senkaSaveFailedWarning.
  ///
  /// In zh, this message translates to:
  /// **'战果数据保存失败，重启后可能丢失'**
  String get senkaSaveFailedWarning;

  /// No description provided for @senkaLatestRanking.
  ///
  /// In zh, this message translates to:
  /// **'最新排名战果'**
  String get senkaLatestRanking;

  /// No description provided for @senkaTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标战果'**
  String get senkaTarget;

  /// No description provided for @senkaGap.
  ///
  /// In zh, this message translates to:
  /// **'距离目标还差 {value} 战果'**
  String senkaGap(String value);

  /// No description provided for @senkaOver.
  ///
  /// In zh, this message translates to:
  /// **'已超出 {value} 战果'**
  String senkaOver(String value);

  /// No description provided for @senkaPlannedEo.
  ///
  /// In zh, this message translates to:
  /// **'计划 EO'**
  String get senkaPlannedEo;

  /// No description provided for @senkaPlannedQuest.
  ///
  /// In zh, this message translates to:
  /// **'计划任务'**
  String get senkaPlannedQuest;

  /// No description provided for @senkaDailyRequired.
  ///
  /// In zh, this message translates to:
  /// **'每日所需'**
  String get senkaDailyRequired;

  /// No description provided for @senkaTodayRemaining.
  ///
  /// In zh, this message translates to:
  /// **'今日剩余'**
  String get senkaTodayRemaining;

  /// No description provided for @senkaUnsettledDelta.
  ///
  /// In zh, this message translates to:
  /// **'结算后增量'**
  String get senkaUnsettledDelta;

  /// No description provided for @senkaAvailableDaysIncludingToday.
  ///
  /// In zh, this message translates to:
  /// **'可用天数（含今日）'**
  String get senkaAvailableDaysIncludingToday;

  /// No description provided for @senkaProjected.
  ///
  /// In zh, this message translates to:
  /// **'预计战果'**
  String get senkaProjected;

  /// No description provided for @senkaUnit.
  ///
  /// In zh, this message translates to:
  /// **'战果'**
  String get senkaUnit;

  /// No description provided for @senkaInputTitle.
  ///
  /// In zh, this message translates to:
  /// **'填写{label}'**
  String senkaInputTitle(String label);

  /// No description provided for @senkaInvalidNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效数字'**
  String get senkaInvalidNumber;

  /// No description provided for @senkaPlannedEoReward.
  ///
  /// In zh, this message translates to:
  /// **'计划 EO 战果奖励'**
  String get senkaPlannedEoReward;

  /// No description provided for @senkaPlannedQuestReward.
  ///
  /// In zh, this message translates to:
  /// **'计划任务战果奖励'**
  String get senkaPlannedQuestReward;

  /// No description provided for @senkaTotal.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get senkaTotal;

  /// No description provided for @senkaEoRewards.
  ///
  /// In zh, this message translates to:
  /// **'EO 战果奖励'**
  String get senkaEoRewards;

  /// No description provided for @senkaQuarterlyQuests.
  ///
  /// In zh, this message translates to:
  /// **'季度战果任务'**
  String get senkaQuarterlyQuests;

  /// No description provided for @senkaAnnualQuests.
  ///
  /// In zh, this message translates to:
  /// **'年度战果任务'**
  String get senkaAnnualQuests;

  /// No description provided for @senkaOneTimeQuests.
  ///
  /// In zh, this message translates to:
  /// **'单次战果任务'**
  String get senkaOneTimeQuests;

  /// No description provided for @senkaRewardLegend.
  ///
  /// In zh, this message translates to:
  /// **'黄色＋✕：计划放置，不计入预计战果，绿色＋✓：计划完成，计入预计战果，灰色＋○：已经完成，不再重复计算。'**
  String get senkaRewardLegend;

  /// No description provided for @senkaRewardDeferred.
  ///
  /// In zh, this message translates to:
  /// **'计划放置'**
  String get senkaRewardDeferred;

  /// No description provided for @senkaRewardPlanned.
  ///
  /// In zh, this message translates to:
  /// **'计划完成（计预计）'**
  String get senkaRewardPlanned;

  /// No description provided for @senkaRewardCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get senkaRewardCompleted;

  /// No description provided for @senkaCalendarTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月战果日历'**
  String senkaCalendarTitle(int year, int month);

  /// No description provided for @senkaCalendarSummary.
  ///
  /// In zh, this message translates to:
  /// **'本月已记录 {recorded} · 本月素战果 {base}'**
  String senkaCalendarSummary(String recorded, String base);

  /// No description provided for @senkaExperience.
  ///
  /// In zh, this message translates to:
  /// **'经验'**
  String get senkaExperience;

  /// No description provided for @senkaQuest.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get senkaQuest;

  /// No description provided for @senkaCalendarCell.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月{day}日，战果{value}'**
  String senkaCalendarCell(int year, int month, int day, String value);

  /// No description provided for @senkaServer.
  ///
  /// In zh, this message translates to:
  /// **'所在服务器'**
  String get senkaServer;

  /// No description provided for @senkaRanking.
  ///
  /// In zh, this message translates to:
  /// **'战果排名'**
  String get senkaRanking;

  /// No description provided for @senkaRank.
  ///
  /// In zh, this message translates to:
  /// **'排名'**
  String get senkaRank;

  /// No description provided for @senkaUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新：{time}'**
  String senkaUpdated(String time);

  /// No description provided for @senkaOrder.
  ///
  /// In zh, this message translates to:
  /// **'顺位'**
  String get senkaOrder;

  /// No description provided for @senkaChange.
  ///
  /// In zh, this message translates to:
  /// **'变化'**
  String get senkaChange;

  /// No description provided for @senkaCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get senkaCurrent;

  /// No description provided for @senkaSortieStats.
  ///
  /// In zh, this message translates to:
  /// **'出击海域统计'**
  String get senkaSortieStats;

  /// No description provided for @senkaLatestRecord.
  ///
  /// In zh, this message translates to:
  /// **'最近记录'**
  String get senkaLatestRecord;

  /// No description provided for @senkaMonthSorties.
  ///
  /// In zh, this message translates to:
  /// **'本月出击'**
  String get senkaMonthSorties;

  /// No description provided for @senkaBossArrivals.
  ///
  /// In zh, this message translates to:
  /// **'Boss 到达'**
  String get senkaBossArrivals;

  /// No description provided for @senkaSWins.
  ///
  /// In zh, this message translates to:
  /// **'S 胜'**
  String get senkaSWins;

  /// No description provided for @senkaMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get senkaMonth;

  /// No description provided for @senkaToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get senkaToday;

  /// No description provided for @senkaShowHiddenAreas.
  ///
  /// In zh, this message translates to:
  /// **'显示隐藏海域'**
  String get senkaShowHiddenAreas;

  /// No description provided for @senkaShowHidden.
  ///
  /// In zh, this message translates to:
  /// **'显示已隐藏'**
  String get senkaShowHidden;

  /// No description provided for @senkaArea.
  ///
  /// In zh, this message translates to:
  /// **'海域'**
  String get senkaArea;

  /// No description provided for @senkaBoss.
  ///
  /// In zh, this message translates to:
  /// **'Boss'**
  String get senkaBoss;

  /// No description provided for @senkaSorties.
  ///
  /// In zh, this message translates to:
  /// **'出击'**
  String get senkaSorties;

  /// No description provided for @senkaResult.
  ///
  /// In zh, this message translates to:
  /// **'S / A'**
  String get senkaResult;

  /// No description provided for @senkaActions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get senkaActions;

  /// No description provided for @senkaFavoriteArea.
  ///
  /// In zh, this message translates to:
  /// **'收藏海域 {map}'**
  String senkaFavoriteArea(String map);

  /// No description provided for @senkaHideArea.
  ///
  /// In zh, this message translates to:
  /// **'隐藏海域 {map}'**
  String senkaHideArea(String map);

  /// No description provided for @senkaUnknownServer.
  ///
  /// In zh, this message translates to:
  /// **'未知服务器'**
  String get senkaUnknownServer;

  /// No description provided for @toolbox.
  ///
  /// In zh, this message translates to:
  /// **'工具箱'**
  String get toolbox;

  /// No description provided for @fleetExport.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get fleetExport;

  /// No description provided for @otherTools.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get otherTools;

  /// No description provided for @noro6.
  ///
  /// In zh, this message translates to:
  /// **'noro6'**
  String get noro6;

  /// No description provided for @jervis.
  ///
  /// In zh, this message translates to:
  /// **'Jervis'**
  String get jervis;

  /// No description provided for @exportToNoro6.
  ///
  /// In zh, this message translates to:
  /// **'导出至 noro6'**
  String get exportToNoro6;

  /// No description provided for @exportToNoro6Mirror.
  ///
  /// In zh, this message translates to:
  /// **'导出至 noro6（国内镜像）'**
  String get exportToNoro6Mirror;

  /// No description provided for @exportToJervis.
  ///
  /// In zh, this message translates to:
  /// **'导出至 Jervis'**
  String get exportToJervis;

  /// No description provided for @eventLandBasesOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅导出活动海域陆航'**
  String get eventLandBasesOnly;

  /// No description provided for @landBaseExportLimitHint.
  ///
  /// In zh, this message translates to:
  /// **'DeckBuilder 每次最多支持 3 队；关闭筛选时按已捕获顺序导出前 3 队。'**
  String get landBaseExportLimitHint;

  /// No description provided for @fleetExportText.
  ///
  /// In zh, this message translates to:
  /// **'舰队导出文本'**
  String get fleetExportText;

  /// No description provided for @deckBuilderV4.
  ///
  /// In zh, this message translates to:
  /// **'DeckBuilder v4'**
  String get deckBuilderV4;

  /// No description provided for @refreshExportText.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refreshExportText;

  /// No description provided for @copyExportText.
  ///
  /// In zh, this message translates to:
  /// **'复制文本'**
  String get copyExportText;

  /// No description provided for @openInSystemBrowser.
  ///
  /// In zh, this message translates to:
  /// **'使用系统默认浏览器打开'**
  String get openInSystemBrowser;

  /// No description provided for @otherToolsComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'其他功能陆续开发中'**
  String get otherToolsComingSoon;

  /// No description provided for @otherToolsHint.
  ///
  /// In zh, this message translates to:
  /// **'后续辅助工具会集中放在这里。'**
  String get otherToolsHint;

  /// No description provided for @waitingForPortData.
  ///
  /// In zh, this message translates to:
  /// **'等待母港数据'**
  String get waitingForPortData;

  /// No description provided for @externalFleetToolOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开外部舰队工具，请检查是否已安装浏览器。'**
  String get externalFleetToolOpenFailed;

  /// No description provided for @fleetExportCopied.
  ///
  /// In zh, this message translates to:
  /// **'舰队导出文本已复制。'**
  String get fleetExportCopied;

  /// No description provided for @fleetExportCopyFailed.
  ///
  /// In zh, this message translates to:
  /// **'复制失败，请稍后重试。'**
  String get fleetExportCopyFailed;

  /// No description provided for @equipmentCompatibilitySummary.
  ///
  /// In zh, this message translates to:
  /// **'可装备：持有 {owned}／全部 {all}'**
  String equipmentCompatibilitySummary(int owned, int all);

  /// No description provided for @equipmentCompatibilityOwnedTab.
  ///
  /// In zh, this message translates to:
  /// **'持有舰娘 {count}'**
  String equipmentCompatibilityOwnedTab(int count);

  /// No description provided for @equipmentCompatibilityAllTab.
  ///
  /// In zh, this message translates to:
  /// **'全部舰娘 {count}'**
  String equipmentCompatibilityAllTab(int count);

  /// No description provided for @equipmentCompatibilityOwnedCompact.
  ///
  /// In zh, this message translates to:
  /// **'持有 {count}'**
  String equipmentCompatibilityOwnedCompact(int count);

  /// No description provided for @equipmentCompatibilityAllCompact.
  ///
  /// In zh, this message translates to:
  /// **'全部 {count}'**
  String equipmentCompatibilityAllCompact(int count);

  /// No description provided for @equipmentCompatibilitySelectShipType.
  ///
  /// In zh, this message translates to:
  /// **'选择舰种'**
  String get equipmentCompatibilitySelectShipType;

  /// No description provided for @equipmentCompatibilitySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索舰娘'**
  String get equipmentCompatibilitySearchHint;

  /// No description provided for @equipmentCompatibilityAllSlots.
  ///
  /// In zh, this message translates to:
  /// **'全部槽位'**
  String get equipmentCompatibilityAllSlots;

  /// No description provided for @equipmentCompatibilityRegularSlot.
  ///
  /// In zh, this message translates to:
  /// **'普通槽'**
  String get equipmentCompatibilityRegularSlot;

  /// No description provided for @equipmentCompatibilityExpansionSlot.
  ///
  /// In zh, this message translates to:
  /// **'增设栏'**
  String get equipmentCompatibilityExpansionSlot;

  /// No description provided for @equipmentCompatibilityBothSlots.
  ///
  /// In zh, this message translates to:
  /// **'普通槽＋增设栏'**
  String get equipmentCompatibilityBothSlots;

  /// No description provided for @equipmentCompatibilityExpansionRequirement.
  ///
  /// In zh, this message translates to:
  /// **'增设栏需 ★+{level}'**
  String equipmentCompatibilityExpansionRequirement(int level);

  /// No description provided for @equipmentCompatibilityOwnedLevels.
  ///
  /// In zh, this message translates to:
  /// **'Lv.{levels}'**
  String equipmentCompatibilityOwnedLevels(String levels);

  /// No description provided for @equipmentCompatibilityFleetNumbers.
  ///
  /// In zh, this message translates to:
  /// **'第 {numbers} 舰队'**
  String equipmentCompatibilityFleetNumbers(String numbers);

  /// No description provided for @equipmentCompatibilityEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的舰娘'**
  String get equipmentCompatibilityEmpty;

  /// No description provided for @equipmentCompatibilityOfficialId.
  ///
  /// In zh, this message translates to:
  /// **'装备 ID {id}'**
  String equipmentCompatibilityOfficialId(int id);

  /// No description provided for @equipmentCompatibilityOwnedCount.
  ///
  /// In zh, this message translates to:
  /// **'持有数 {count}'**
  String equipmentCompatibilityOwnedCount(int count);

  /// No description provided for @equipmentCompatibilityRegularCount.
  ///
  /// In zh, this message translates to:
  /// **'普通槽 {count}'**
  String equipmentCompatibilityRegularCount(int count);

  /// No description provided for @equipmentCompatibilityExpansionCount.
  ///
  /// In zh, this message translates to:
  /// **'增设栏 {count}'**
  String equipmentCompatibilityExpansionCount(int count);

  /// No description provided for @equipmentCompatibilitySource.
  ///
  /// In zh, this message translates to:
  /// **'规则来源：游戏官方主数据'**
  String get equipmentCompatibilitySource;

  /// No description provided for @equipmentCompatibilityRulesWaiting.
  ///
  /// In zh, this message translates to:
  /// **'装备规则数据等待更新'**
  String get equipmentCompatibilityRulesWaiting;

  /// No description provided for @equipmentCompatibilityEmptyOwned.
  ///
  /// In zh, this message translates to:
  /// **'当前没有持有可装备的舰娘'**
  String get equipmentCompatibilityEmptyOwned;

  /// No description provided for @equipmentCompatibilityEmptyAll.
  ///
  /// In zh, this message translates to:
  /// **'没有找到可装备的舰娘形态'**
  String get equipmentCompatibilityEmptyAll;

  /// No description provided for @equipmentCompatibilityCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类：{category}'**
  String equipmentCompatibilityCategory(String category);

  /// No description provided for @equipmentCompatibilityShipClassId.
  ///
  /// In zh, this message translates to:
  /// **'舰级 #{id}'**
  String equipmentCompatibilityShipClassId(int id);

  /// No description provided for @shipEquipmentCompatibilitySelectCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择装备分类'**
  String get shipEquipmentCompatibilitySelectCategory;

  /// No description provided for @shipEquipmentCompatibilitySearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索装备'**
  String get shipEquipmentCompatibilitySearchTitle;

  /// No description provided for @shipEquipmentCompatibilitySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入装备名称'**
  String get shipEquipmentCompatibilitySearchHint;

  /// No description provided for @shipEquipmentCompatibilityOwnedCount.
  ///
  /// In zh, this message translates to:
  /// **'持有 X{count}'**
  String shipEquipmentCompatibilityOwnedCount(int count);

  /// No description provided for @shipEquipmentCompatibilityEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到可装备的装备'**
  String get shipEquipmentCompatibilityEmpty;

  /// No description provided for @equipmentDevelopment.
  ///
  /// In zh, this message translates to:
  /// **'装备开发'**
  String get equipmentDevelopment;

  /// No description provided for @development.
  ///
  /// In zh, this message translates to:
  /// **'开发'**
  String get development;

  /// No description provided for @developmentCommandTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发指挥台'**
  String get developmentCommandTitle;

  /// No description provided for @developmentWorkbenchTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发工作台'**
  String get developmentWorkbenchTitle;

  /// No description provided for @developmentCalculator.
  ///
  /// In zh, this message translates to:
  /// **'开发计算器'**
  String get developmentCalculator;

  /// No description provided for @developmentFormula.
  ///
  /// In zh, this message translates to:
  /// **'开发公式'**
  String get developmentFormula;

  /// No description provided for @developmentOutputProbability.
  ///
  /// In zh, this message translates to:
  /// **'出货概率'**
  String get developmentOutputProbability;

  /// No description provided for @developmentFinalProbability.
  ///
  /// In zh, this message translates to:
  /// **'最终概率'**
  String get developmentFinalProbability;

  /// No description provided for @developmentAvailableRecipes.
  ///
  /// In zh, this message translates to:
  /// **'可用公式'**
  String get developmentAvailableRecipes;

  /// No description provided for @developmentPoolType.
  ///
  /// In zh, this message translates to:
  /// **'池类型'**
  String get developmentPoolType;

  /// No description provided for @developmentSelectSecretary.
  ///
  /// In zh, this message translates to:
  /// **'选择秘书舰类型'**
  String get developmentSelectSecretary;

  /// No description provided for @developmentOtherSecretaryGroup.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get developmentOtherSecretaryGroup;

  /// No description provided for @developmentEquipmentType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get developmentEquipmentType;

  /// No description provided for @developmentSecretary.
  ///
  /// In zh, this message translates to:
  /// **'秘书舰'**
  String get developmentSecretary;

  /// No description provided for @developmentFuelShort.
  ///
  /// In zh, this message translates to:
  /// **'油'**
  String get developmentFuelShort;

  /// No description provided for @developmentAmmoShort.
  ///
  /// In zh, this message translates to:
  /// **'弹'**
  String get developmentAmmoShort;

  /// No description provided for @developmentSteelShort.
  ///
  /// In zh, this message translates to:
  /// **'钢'**
  String get developmentSteelShort;

  /// No description provided for @developmentBauxiteShort.
  ///
  /// In zh, this message translates to:
  /// **'铝'**
  String get developmentBauxiteShort;

  /// No description provided for @developmentOutputRate.
  ///
  /// In zh, this message translates to:
  /// **'出货率'**
  String get developmentOutputRate;

  /// No description provided for @developmentEquipment.
  ///
  /// In zh, this message translates to:
  /// **'装备'**
  String get developmentEquipment;

  /// No description provided for @developmentCurrentFlagship.
  ///
  /// In zh, this message translates to:
  /// **'当前旗舰'**
  String get developmentCurrentFlagship;

  /// No description provided for @developmentUseFlagship.
  ///
  /// In zh, this message translates to:
  /// **'使用当前旗舰'**
  String get developmentUseFlagship;

  /// No description provided for @developmentFlagshipUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前旗舰没有可用的开发池，已保留原选择'**
  String get developmentFlagshipUnsupported;

  /// No description provided for @developmentSelectPool.
  ///
  /// In zh, this message translates to:
  /// **'秘书舰类型'**
  String get developmentSelectPool;

  /// No description provided for @developmentCurrentRecipe.
  ///
  /// In zh, this message translates to:
  /// **'当前配方'**
  String get developmentCurrentRecipe;

  /// No description provided for @developmentTargetEquipment.
  ///
  /// In zh, this message translates to:
  /// **'目标装备'**
  String get developmentTargetEquipment;

  /// No description provided for @developmentChooseTarget.
  ///
  /// In zh, this message translates to:
  /// **'选择目标装备'**
  String get developmentChooseTarget;

  /// No description provided for @developmentSearchEquipment.
  ///
  /// In zh, this message translates to:
  /// **'搜索装备'**
  String get developmentSearchEquipment;

  /// No description provided for @developmentSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入装备名称或 ID'**
  String get developmentSearchHint;

  /// No description provided for @developmentAllTypes.
  ///
  /// In zh, this message translates to:
  /// **'全部类型'**
  String get developmentAllTypes;

  /// No description provided for @developmentTargetDrops.
  ///
  /// In zh, this message translates to:
  /// **'目标出货'**
  String get developmentTargetDrops;

  /// No description provided for @developmentOtherDrops.
  ///
  /// In zh, this message translates to:
  /// **'其他出货'**
  String get developmentOtherDrops;

  /// No description provided for @developmentInsufficient.
  ///
  /// In zh, this message translates to:
  /// **'资源不足'**
  String get developmentInsufficient;

  /// No description provided for @developmentReplaced.
  ///
  /// In zh, this message translates to:
  /// **'被替换出货'**
  String get developmentReplaced;

  /// No description provided for @developmentRecommendations.
  ///
  /// In zh, this message translates to:
  /// **'推荐配方'**
  String get developmentRecommendations;

  /// No description provided for @developmentNoTargets.
  ///
  /// In zh, this message translates to:
  /// **'选择目标装备后显示推荐配方'**
  String get developmentNoTargets;

  /// No description provided for @developmentNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有能同时开发所有目标的配方'**
  String get developmentNoResults;

  /// No description provided for @developmentTargetRate.
  ///
  /// In zh, this message translates to:
  /// **'目标率'**
  String get developmentTargetRate;

  /// No description provided for @developmentFailureRate.
  ///
  /// In zh, this message translates to:
  /// **'失败率'**
  String get developmentFailureRate;

  /// No description provided for @developmentTotalResources.
  ///
  /// In zh, this message translates to:
  /// **'总资源'**
  String get developmentTotalResources;

  /// No description provided for @developmentApplyRecipe.
  ///
  /// In zh, this message translates to:
  /// **'回填配方'**
  String get developmentApplyRecipe;

  /// No description provided for @developmentDataError.
  ///
  /// In zh, this message translates to:
  /// **'装备开发数据加载失败'**
  String get developmentDataError;

  /// No description provided for @developmentRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get developmentRetry;

  /// No description provided for @developmentSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 件'**
  String developmentSelectedCount(int count);

  /// No description provided for @developmentPoolBauxite.
  ///
  /// In zh, this message translates to:
  /// **'铝土系'**
  String get developmentPoolBauxite;

  /// No description provided for @developmentPoolAmmunition.
  ///
  /// In zh, this message translates to:
  /// **'弹药系'**
  String get developmentPoolAmmunition;

  /// No description provided for @developmentPoolFuelSteel.
  ///
  /// In zh, this message translates to:
  /// **'油钢系'**
  String get developmentPoolFuelSteel;

  /// No description provided for @battlePredictionUnconfirmed.
  ///
  /// In zh, this message translates to:
  /// **'数据未确认：血量与预测仅供参考，请以游戏画面为准。'**
  String get battlePredictionUnconfirmed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
