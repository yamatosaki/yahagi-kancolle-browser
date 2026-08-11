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
  /// **'游戏安全'**
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
  /// **'清理游戏 Web 缓存'**
  String get clearWebCache;

  /// No description provided for @clearWebCacheDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除游戏加载的图片、音频等静态资源缓存。'**
  String get clearWebCacheDesc;

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
  /// **'清理游戏 Web 缓存'**
  String get clearWebCacheConfirmTitle;

  /// No description provided for @clearWebCacheConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除游戏缓存吗？这将会删除已下载的图片、音频等静态资源，下次进入游戏或加载立绘时可能会消耗较多流量和时间。'**
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

  /// No description provided for @battleWarningReminder.
  ///
  /// In zh, this message translates to:
  /// **'闪烁提醒'**
  String get battleWarningReminder;

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
  /// **'已清理游戏 Web 缓存'**
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

  /// No description provided for @enemyFleet.
  ///
  /// In zh, this message translates to:
  /// **'敌舰队'**
  String get enemyFleet;

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
  /// **'游戏客户端资源绕行（实验性）'**
  String get gadgetBypass;

  /// No description provided for @gadgetBypassDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅在客户端静态资源服务器受限时改用镜像；不修改 DMM 登录、Cookie 或游戏数据接口。关闭时完全旁路。'**
  String get gadgetBypassDesc;

  /// No description provided for @gadgetBypassEnable.
  ///
  /// In zh, this message translates to:
  /// **'开启绕行'**
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

  /// No description provided for @waitingForPortData.
  ///
  /// In zh, this message translates to:
  /// **'等待母港数据'**
  String get waitingForPortData;

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

  /// No description provided for @losDetails.
  ///
  /// In zh, this message translates to:
  /// **'索敌详情'**
  String get losDetails;

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

  /// No description provided for @airStateLabel.
  ///
  /// In zh, this message translates to:
  /// **'制空：{label}'**
  String airStateLabel(String label);

  /// No description provided for @postBattleWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'战后安全警告'**
  String get postBattleWarningTitle;

  /// No description provided for @postBattleWarningHeadline.
  ///
  /// In zh, this message translates to:
  /// **'出击舰队中存在大破舰娘！'**
  String get postBattleWarningHeadline;

  /// No description provided for @postBattleWarningBody.
  ///
  /// In zh, this message translates to:
  /// **'请在接下来的选择界面务必点击“撤退”，切勿强行进击以免沉船！'**
  String get postBattleWarningBody;

  /// No description provided for @acknowledgeAndRetreat.
  ///
  /// In zh, this message translates to:
  /// **'确认了解并撤退'**
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
  /// **'解除 60 FPS 上限'**
  String get gameFrameRateTitle;

  /// No description provided for @gameFrameRateOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get gameFrameRateOff;

  /// No description provided for @gameFrameRateMax60.
  ///
  /// In zh, this message translates to:
  /// **'最高 60 FPS'**
  String get gameFrameRateMax60;

  /// No description provided for @gameFrameRateFollowDisplay.
  ///
  /// In zh, this message translates to:
  /// **'跟随屏幕'**
  String get gameFrameRateFollowDisplay;

  /// No description provided for @gameFrameRateOffDesc.
  ///
  /// In zh, this message translates to:
  /// **'保持游戏原始帧率行为。'**
  String get gameFrameRateOffDesc;

  /// No description provided for @gameFrameRateMax60Desc.
  ///
  /// In zh, this message translates to:
  /// **'使用 RAF 渲染，并将目标帧率限制为最高 60 FPS。'**
  String get gameFrameRateMax60Desc;

  /// No description provided for @gameFrameRateFollowDisplayDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用 GotoBrowser 同款主脚本补丁，让游戏跟随设备刷新率；可能增加耗电和发热。'**
  String get gameFrameRateFollowDisplayDesc;

  /// No description provided for @gameFrameRateUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前 Android WebView 不支持解除帧率上限'**
  String get gameFrameRateUnsupported;

  /// No description provided for @gameFrameRateRestartRequired.
  ///
  /// In zh, this message translates to:
  /// **'重新加载游戏页面后生效'**
  String get gameFrameRateRestartRequired;

  /// No description provided for @gameRenderingModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'游戏渲染兼容模式'**
  String get gameRenderingModeTitle;

  /// No description provided for @gameRenderingModeStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准模式'**
  String get gameRenderingModeStandard;

  /// No description provided for @gameRenderingModeStandardDesc.
  ///
  /// In zh, this message translates to:
  /// **'Texture Layer + WebGL，保留工具栏模糊效果。'**
  String get gameRenderingModeStandardDesc;

  /// No description provided for @gameRenderingModeCompatibility.
  ///
  /// In zh, this message translates to:
  /// **'兼容模式'**
  String get gameRenderingModeCompatibility;

  /// No description provided for @gameRenderingModeCompatibilityDesc.
  ///
  /// In zh, this message translates to:
  /// **'Hybrid Composition + WebGL，关闭工具栏模糊；适合华为、荣耀设备卡顿时尝试。'**
  String get gameRenderingModeCompatibilityDesc;

  /// No description provided for @gameRenderingModeCanvas.
  ///
  /// In zh, this message translates to:
  /// **'深度兼容模式'**
  String get gameRenderingModeCanvas;

  /// No description provided for @gameRenderingModeCanvasDesc.
  ///
  /// In zh, this message translates to:
  /// **'Hybrid Composition + Canvas，关闭工具栏模糊；兼容性优先，画面性能可能降低。'**
  String get gameRenderingModeCanvasDesc;

  /// No description provided for @gameRenderingModeConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换游戏渲染模式？'**
  String get gameRenderingModeConfirmTitle;

  /// No description provided for @gameRenderingModeConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'切换后将自动重建游戏页面，当前页面会短暂关闭并重新载入。请先避免正在进行的操作。'**
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
