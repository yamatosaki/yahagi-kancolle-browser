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
  /// **'入渠'**
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
  /// **'战斗记录'**
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
  /// **'情报面板宽度'**
  String get infoPanelWidth;

  /// No description provided for @autoZoom.
  ///
  /// In zh, this message translates to:
  /// **'自动缩放游戏画面 (推荐)'**
  String get autoZoom;

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
  /// **'入渠简报'**
  String get repairBrief;

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
  /// **'版本 学习版 1.0 · 免责声明 · 检查更新'**
  String get aboutSubtitle;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本 学习版 1.0'**
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
  /// **'退出登录功能已准备就绪，当前为保护您的测试账号暂未执行清除。'**
  String get logoutSnackbar;

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
  /// **'清除本地保存的所有历史战果、资源与远征记录。此操作不可逆。'**
  String get clearLogbookDesc;

  /// No description provided for @clearLogbookConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理航海日志数据'**
  String get clearLogbookConfirmTitle;

  /// No description provided for @clearLogbookConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有航海日志数据吗？这将会删除您积攒的历史战果和资源统计记录。此操作无法撤销。'**
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
  /// **'平均疲劳'**
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
  /// **'平均疲劳'**
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
