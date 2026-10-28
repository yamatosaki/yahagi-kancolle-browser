// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get debuffReminderTitle => 'Armor debuff reminder';

  @override
  String get debuffReminderSourcePort => 'Port';

  @override
  String get debuffReminderSourceBattleResult => 'Battle results';

  @override
  String get debuffReminderSourceAirDefense => 'Base air defense';

  @override
  String debuffReminderMessage(String source) {
    return '$source: Puzzle or debuff cue detected.';
  }

  @override
  String get debuffReminderSectionTitle => 'In-game reminders';

  @override
  String get debuffReminderSettingTitle => 'Armor debuff reminder';

  @override
  String get debuffReminderSettingSubtitle =>
      'Both options vibrate when a puzzle or debuff cue is detected.';

  @override
  String get debuffReminderStyleDialog => 'Confirmation dialog (default)';

  @override
  String get debuffReminderStyleTopNotice => 'Top notice';

  @override
  String get cameraAvoidanceTitle => 'Camera avoidance';

  @override
  String get cameraAvoidanceDesc =>
      'Adjust the interface spacing on the camera side. The spacing switches sides automatically when you flip the screen.';

  @override
  String get cameraAvoidanceDistance => 'Avoidance distance';

  @override
  String get operationProtectionTitle => 'Accidental action protection';

  @override
  String get confirmBeforeExitTitle => 'Confirm before leaving';

  @override
  String get confirmBeforeExitDescription =>
      'Ask for confirmation before leaving the app with the Back button or gesture.';

  @override
  String get confirmBeforeExitSaveFailed =>
      'Could not save the exit confirmation setting. Please try again.';

  @override
  String get appExitConfirmTitle => 'Return to the home screen?';

  @override
  String get appExitConfirmDescription =>
      'The game will move to the background.';

  @override
  String get appExitStay => 'Continue playing';

  @override
  String get appExitToDesktop => 'Go to home screen';

  @override
  String get appExitFailed =>
      'Could not return to the home screen. Please try again.';

  @override
  String get enterGameFullscreen => 'Game fullscreen';

  @override
  String get exitGameFullscreen => 'Exit fullscreen';

  @override
  String get exitFullscreenShort => 'Exit';

  @override
  String get exitFullscreenConfirmTitle => 'Exit game fullscreen?';

  @override
  String get exitFullscreenConfirmDescription =>
      'The information panel and toolbar will be shown again.';

  @override
  String get exitFullscreenSkipConfirmation => 'Do not ask again';

  @override
  String get exitFullscreenConfirmAction => 'Exit fullscreen';

  @override
  String get gameFullscreenHint =>
      'Tap the floating button or press Back to exit fullscreen. Drag the button to move it';

  @override
  String get gameFullscreenUnavailable =>
      'Could not display the exit button. Restored the normal layout';

  @override
  String get questCompletionNotice => 'Completed quests are available';

  @override
  String questCompletionCount(int count) {
    return 'Completed quests awaiting rewards: $count';
  }

  @override
  String get resourceTrend90d => '90 days';

  @override
  String get resourceTrendInventoryTitle => 'Inventory trends';

  @override
  String get resourceTrendCustomize => 'Visible resources';

  @override
  String get resourceTrendAtLeastOne => 'Select at least one resource';

  @override
  String get resourceTrendBuildMaterial => 'Instant construction material';

  @override
  String get resourceTrendRepairMaterial => 'Instant repair material';

  @override
  String get resourceTrendDevMaterial => 'Development material';

  @override
  String get resourceTrendImproveMaterial => 'Improvement material';

  @override
  String get resourceTrendLatest => 'Latest balance';

  @override
  String get resourceTrendChange => 'Change over period';

  @override
  String resourceTrendBaseline(String time) {
    return 'Change baseline: $time JST';
  }

  @override
  String resourceTrendObserved(String time) {
    return 'Last recorded: $time JST';
  }

  @override
  String get resourceTrendPartial =>
      'No record at the start of this period. Changes use the first available record';

  @override
  String get resourceTrendInsufficient => 'Not enough records to compare';

  @override
  String get resourceTrendNoPeriodData => 'No resource records for this period';

  @override
  String get resourceTrendLoadError => 'Could not load resource records';

  @override
  String get resourceTrendSaveError =>
      'Could not save resource display settings';

  @override
  String get resourceTrendInspect => 'Swipe to inspect';

  @override
  String get resourceTrendExpand => 'Expand chart';

  @override
  String get resourceTrendSampled =>
      'Long-range charts preserve peaks and troughs. Values show actual sampled records';

  @override
  String get resourceTrendLocalScale =>
      'The vertical axis scales to the balance range';

  @override
  String get resourceTrendBaseShort => 'Baseline';

  @override
  String get diagnosticLoggingSection => 'Client diagnostic logs';

  @override
  String get diagnosticLoggingTitle => 'Record client diagnostic logs';

  @override
  String get diagnosticLoggingDesc =>
      'Records only performance and error summaries, without accounts, passwords, or login credentials';

  @override
  String get telemetryAnonymousStatsTitle =>
      'Anonymous device and usage statistics';

  @override
  String get telemetryAnonymousStatsDesc =>
      'Send anonymous device information and rendering mode statistics to help improve the app. No account or personal information is included.';

  @override
  String get diagnosticPrivacyTitle => 'Privacy-protected diagnostics';

  @override
  String get diagnosticPrivacyDesc =>
      'Contents are checked again before export. Logs do not record accounts, passwords, Cookie data, tokens, request or response bodies, chats, or screenshots, and are never uploaded automatically.';

  @override
  String get diagnosticStatusEnabled => 'Recording';

  @override
  String get diagnosticStatusDisabled => 'Recording stopped';

  @override
  String diagnosticStorageUsage(String size) {
    return 'Local log size: $size';
  }

  @override
  String get exportDiagnosticFile => 'Export diagnostic file';

  @override
  String get saveDiagnosticFile => 'Save to device';

  @override
  String get shareDiagnosticFile => 'Share diagnostic file';

  @override
  String get diagnosticSaveConfirmTitle => 'Save diagnostic file?';

  @override
  String get diagnosticSaveConfirmDesc =>
      'A JSON file that has passed a privacy check will be created. Select a destination folder. The client generates the filename automatically, and it cannot be changed.';

  @override
  String get diagnosticSaveAction => 'Choose folder';

  @override
  String diagnosticSaveSucceeded(String fileName) {
    return 'Saved: $fileName';
  }

  @override
  String get diagnosticSaveFailed => 'Could not save the diagnostic file';

  @override
  String get diagnosticShareConfirmTitle => 'Share diagnostic file?';

  @override
  String get diagnosticShareConfirmDesc =>
      'A JSON file that has passed a privacy check will be created, then the system share sheet will open. Check the recipient before sending.';

  @override
  String get diagnosticShareAction => 'Share';

  @override
  String get diagnosticShareFailed => 'Could not share the diagnostic file';

  @override
  String get clearDiagnosticData => 'Clear diagnostic logs';

  @override
  String get diagnosticExportConfirmTitle => 'Export diagnostic file?';

  @override
  String get diagnosticExportConfirmDesc =>
      'A JSON file will be created and the system share sheet will open. The file contains only client performance, error summaries, and anonymous device runtime information. Check the recipient before sending.';

  @override
  String get diagnosticExportAction => 'Export';

  @override
  String get diagnosticClearConfirmTitle => 'Clear diagnostic logs?';

  @override
  String get diagnosticClearConfirmDesc =>
      'Deletes diagnostic logs and temporary export copies within the app. Delete any separately saved or shared files yourself.';

  @override
  String get diagnosticClearFailed =>
      'Could not clear diagnostic data. Please try again.';

  @override
  String get diagnosticExportFailed => 'Could not export the diagnostic file';

  @override
  String get langKo => '한국어';

  @override
  String get langEn => 'English';

  @override
  String get dataVersionLabel => 'Data version';

  @override
  String get dataLastCheckedLabel => 'Last checked';

  @override
  String get dataNotChecked => 'Not checked yet';

  @override
  String get sortieMapDataTitle => 'Sortie map data';

  @override
  String get enemyDataTitle => 'Enemy ship data';

  @override
  String dataCatalogUpToDate(String version) {
    return 'Data is up to date.\nVersion: $version';
  }

  @override
  String dataCatalogUpdated(String before, String after) {
    return 'Data updated successfully.\n$before → $after';
  }

  @override
  String get dataCatalogIncompatible =>
      'This app version is too old. Update the app first.';

  @override
  String get dataCatalogValidationFailed =>
      'Updated data failed validation. Continuing with the current data.';

  @override
  String get dataCatalogStorageFailed => 'Could not save the updated data.';

  @override
  String get dataCatalogNetworkFailed =>
      'Network update failed. Please try again later.';

  @override
  String get questLocalProgress => 'Local progress';

  @override
  String questServerProgress(String progress) {
    return 'Server progress: $progress';
  }

  @override
  String get appTitle => 'ヤハギ';

  @override
  String get game => 'Game';

  @override
  String get fleet => 'Fleet';

  @override
  String get expedition => 'Expedition';

  @override
  String get repair => 'Repair';

  @override
  String get construction => 'Construction';

  @override
  String get quests => 'Quests';

  @override
  String get battleRecords => 'Logbook';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get layoutSettings => 'Interface and layout';

  @override
  String get themeColorTitle => 'Theme color';

  @override
  String get themeClassicDark => 'Classic dark';

  @override
  String get themeSeaSaltTeal => 'Sea salt teal';

  @override
  String get themeClearSkyBlue => 'Clear sky blue';

  @override
  String get uiFontSizeTitle => 'Interface font size';

  @override
  String get uiFontSizeDescription => 'Default follows the system.';

  @override
  String get uiFontSizeSystem => 'Default (follow system)';

  @override
  String get uiFontSizeSmall => 'Small';

  @override
  String get uiFontSizeMedium => 'Medium';

  @override
  String get uiFontSizeLarge => 'Large';

  @override
  String get uiDisplaySizeTitle => 'UI size';

  @override
  String get uiDisplaySizeDesc =>
      'Adjust the density of the top bar, navigation bar and info panel';

  @override
  String get uiDisplaySizeNormal => 'Normal';

  @override
  String get uiDisplaySizeCompact => 'Compact';

  @override
  String get uiDisplaySizeMinimal => 'Minimal';

  @override
  String get panelResourcesExpand => 'Expand resources';

  @override
  String get panelResourcesCollapse => 'Collapse resources';

  @override
  String get panelResourcesCollapsedItems => 'Shown when collapsed';

  @override
  String get panelResourcesCollapsedItemsReset => 'Restore default';

  @override
  String get minimalResourcePositionTitle => 'Resource position';

  @override
  String get minimalResourcePositionDesc =>
      'Where Minimal shows resources on the game page in phone landscape: atop the info panel, in a thin bar above the game, or in a thin bar along the bottom of the screen';

  @override
  String get minimalResourcePositionPanel => 'Info panel';

  @override
  String get minimalResourcePositionTopBar => 'Top bar';

  @override
  String get minimalResourcePositionBottomBar => 'Bottom bar';

  @override
  String get gameAreaRatio => 'Game area ratio';

  @override
  String get infoPanelWidth =>
      'Information panel width (not applied in portrait)';

  @override
  String get autoZoom => 'Apply recommended ratio (game:menu 67:33)';

  @override
  String get enhancedDamagePulse => 'Enhanced damage pulse';

  @override
  String get enhancedDamagePulseDesc =>
      'Intensify the color, speed, and light effects inside portraits for light, moderate, and heavy damage. Turn off to use the standard effect.';

  @override
  String get informationPanelOnLeft =>
      'Place the information panel on the left';

  @override
  String get informationPanelOnLeftDesc =>
      'When off, the panel stays on the right. Portrait mode keeps a vertical layout.';

  @override
  String get workspaceMenuOnRight => 'Place the menu on the right';

  @override
  String get workspaceMenuOnRightDesc =>
      'When off, the menu stays on the left.';

  @override
  String get language => 'Language';

  @override
  String get networkSettings => 'Network settings';

  @override
  String get networkStatus => 'Network status';

  @override
  String get proxyNotSupported =>
      'Android System WebView on this device does not support in-app proxy settings.\nUse the system network or a device-wide VPN.';

  @override
  String get systemNetwork => 'System network / VPN';

  @override
  String get systemNetworkDesc =>
      'Use the system network environment without an in-app proxy.';

  @override
  String get httpProxy => 'HTTP proxy';

  @override
  String get httpProxyDesc => 'Connect to a custom HTTP proxy server.';

  @override
  String get socks5Proxy => 'SOCKS5 proxy';

  @override
  String get socks5ProxyDesc => 'Connect to a custom SOCKS5 proxy server.';

  @override
  String get hostAddress => 'Host address (IP or domain)';

  @override
  String get hostHint => 'For example, 192.168.1.10';

  @override
  String get port => 'Port';

  @override
  String get currentSavedMode => 'Saved mode';

  @override
  String get vpnStatus => 'VPN status';

  @override
  String get vpnActive => 'Active VPN detected';

  @override
  String get vpnInactive => 'No active VPN detected';

  @override
  String get testConnection => 'Test connection';

  @override
  String get applySettings => 'Apply settings and reload game';

  @override
  String get restoreSystemNetwork => 'Restore system network';

  @override
  String get gameSafety => 'Heavy damage alerts';

  @override
  String get battleSafetySectionTitle => 'Game safety';

  @override
  String get blockSortieTitle => 'Heavy damage advance warning';

  @override
  String get blockSortieDesc =>
      'After the game responds to a sortie or advance request, a warning requiring confirmation appears if a non-flagship ship in the sortie fleet is heavily damaged (excluding evacuated ships). The app does not block sortie or advance requests or automatically order a retreat.';

  @override
  String get storageAndCache => 'Storage and cache';

  @override
  String get logoutAndClear => 'Log out / clear account information';

  @override
  String get logoutAndClearDesc =>
      'Clear the game login session. You will need to log in again next time.';

  @override
  String get clearQuestCache => 'Clear quest data cache';

  @override
  String get clearQuestCacheDesc =>
      'Clear locally cached, de-identified quest data. After restarting the app, open the in-game quest screen to fetch it again';

  @override
  String get clearWebCache => 'Clear browser cache';

  @override
  String get clearWebCacheDesc =>
      'Clear temporary pages and scripts cached by WebView.';

  @override
  String get baseSenkaResetTitle => 'Reset base senka';

  @override
  String get baseSenkaResetDesc =>
      'Set this month\'s accumulated base senka to 0.00. EO, quest, and other senka data are unaffected.';

  @override
  String get baseSenkaResetConfirmTitle => 'Reset base senka';

  @override
  String get baseSenkaResetConfirmDesc =>
      'Reset this month\'s accumulated base senka? Daily EO and quest rewards are kept. Future experience gains will accumulate from 0.00.';

  @override
  String get baseSenkaResetSuccess =>
      'This month\'s accumulated base senka has been reset';

  @override
  String get baseSenkaManualTitle => 'Enter base senka manually';

  @override
  String baseSenkaCurrentValue(String value) {
    return 'This month: $value senka';
  }

  @override
  String get baseSenkaManualDialogTitle =>
      'Enter this month\'s accumulated base senka';

  @override
  String get baseSenkaManualInputLabel => 'Accumulated base senka this month';

  @override
  String get baseSenkaManualInvalid =>
      'Enter a non-negative number with up to two decimal places';

  @override
  String baseSenkaSetSuccess(String value) {
    return 'This month\'s accumulated base senka is now $value';
  }

  @override
  String get baseSenkaSaveFailed =>
      'Could not save base senka. Please try again';

  @override
  String get senkaTodaySorties => 'Today\'s sorties';

  @override
  String get fleetBrief => 'Fleet summary';

  @override
  String get expeditionBrief => 'Expedition summary';

  @override
  String get repairBrief => 'Repair summary';

  @override
  String get repairDockMode => 'Dock';

  @override
  String get anchorageRepairMode => 'Anchorage';

  @override
  String get idle => 'Empty';

  @override
  String get inactive => 'Unused';

  @override
  String get repairing => 'Repairing';

  @override
  String get outOfRepairRange => 'Outside repair range';

  @override
  String get unableToRepair => 'Cannot repair';

  @override
  String get constructionBrief => 'Construction summary';

  @override
  String get questBrief => 'Quest summary';

  @override
  String get preSortieCheck => 'Pre-sortie checks';

  @override
  String get sortieCheckShipsMode => 'Ships';

  @override
  String get sortieCheckMapsMode => 'Maps';

  @override
  String get mapHpGauges => 'Map gauges';

  @override
  String get noMapGaugeData => 'No map gauge data';

  @override
  String get noMapGaugeDataHint =>
      'Open a sortie map in the game to sync its data';

  @override
  String get showClearedMaps => 'Show cleared maps';

  @override
  String get allMapsCleared => 'All maps have been cleared';

  @override
  String get forecast => 'Battle prediction';

  @override
  String get waitingForSortieData => 'Waiting for sortie data';

  @override
  String get standby => 'Standby';

  @override
  String get compact => 'Compact';

  @override
  String get detailed => 'Detailed';

  @override
  String get questDesc => 'Quest description';

  @override
  String get baseReward => 'Base rewards';

  @override
  String get accepted => 'Accepted';

  @override
  String get completed => 'Completed';

  @override
  String get updatedAt => 'Updated';

  @override
  String get questDaily => 'Daily';

  @override
  String get questWeekly => 'Weekly';

  @override
  String get questMonthly => 'Monthly';

  @override
  String get questOneTime => 'One-time';

  @override
  String get questOther => 'Other';

  @override
  String get questUnknown => 'Unknown';

  @override
  String get inProgress => 'In progress';

  @override
  String get clearWebCacheConfirmTitle => 'Clear browser cache';

  @override
  String get clearWebCacheConfirmDesc =>
      'Clear the browser cache? This deletes temporary data cached by WebView. Downloaded local game resources are unaffected.';

  @override
  String get confirmClear => 'Clear';

  @override
  String get captureMode => 'Data capture mode';

  @override
  String get gameAndSound => 'Game and sound';

  @override
  String get gameSound => 'Game audio';

  @override
  String get aboutApp => 'About ヤハギ';

  @override
  String get aboutSubtitle =>
      'Learning edition 1.0.2 · Disclaimer · Check for updates';

  @override
  String get version => 'Learning edition 1.0.2';

  @override
  String get disclaimerTitle => 'Disclaimer (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      'This project is a non-profit, unofficial third-party general-purpose browser tool provided solely for programming study and technical exchange. It is not affiliated with the official operators of Kantai Collection (KanColle) or any related rights holders.';

  @override
  String get disclaimerP2 =>
      'This software does not intervene in, block, replay, or modify communications with the game servers, and does not perform game actions on the player\'s behalf. The original author makes no express or implied warranties about its quality, including but not limited to freedom from bugs, fitness for purpose, or system stability.';

  @override
  String get disclaimerP3 =>
      'Under no circumstances is the original author legally or jointly liable for device damage, data loss, the risk of a game account ban, or any other direct or indirect loss resulting from using or being unable to use this software. Any copyright disputes, terms-of-service violations, or other risks arising from use beyond technical study are solely the user\'s responsibility.';

  @override
  String get viewOnGitHub => 'View on GitHub';

  @override
  String get officialWebsite => 'Official website';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get openSourceLicense => 'Open-source license: MIT License';

  @override
  String get newVersionFound => '🚀 A new version is available!';

  @override
  String get currentVersionLabel => 'Current version';

  @override
  String get latestVersionLabel => 'Latest version';

  @override
  String get updateContent => 'What\'s new:';

  @override
  String get later => 'Later';

  @override
  String get goDownload => 'Download';

  @override
  String get alreadyLatest => 'Up to date';

  @override
  String get alreadyLatestDesc => 'You are using the latest version.';

  @override
  String get noRelease => 'No releases';

  @override
  String get noReleaseDesc =>
      'No Release has been published in the GitHub repository yet.';

  @override
  String get checkFailed => 'Check failed';

  @override
  String get networkError => 'Network error';

  @override
  String get networkErrorDesc =>
      'An error occurred while checking for updates. Please try again later.';

  @override
  String get externalLinkOpenFailed =>
      'Could not open the link. Check that a browser is installed.';

  @override
  String get noUpdateLog => 'No release notes';

  @override
  String get battleWarningOff => 'Off';

  @override
  String get battleWarningConfirm => 'Alerts enabled';

  @override
  String get advanceWarningDisplayModeTitle => 'Warning display';

  @override
  String get advanceWarningAlwaysConfirm => 'Always confirm';

  @override
  String get advanceWarningSmart => 'Smart alerts';

  @override
  String get advanceWarningSmartDescription =>
      'Top notice when all heavily damaged ships have confirmed remaining damage control; otherwise, a confirmation dialog.';

  @override
  String get advanceWarningAlwaysConfirmDescription =>
      'Show a confirmation dialog when heavy damage is detected.';

  @override
  String get advanceWarningTimingModeTitle => 'Warning timing';

  @override
  String get advanceWarningTimingModeDescription =>
      'Changes apply from the next sortie.';

  @override
  String get advanceWarningPostBattle => 'Alert after battle results';

  @override
  String get advanceWarningAfterAdvance => 'Alert after advancing';

  @override
  String get advanceWarningBothTimings => 'Alert at both stages';

  @override
  String get advanceWarningAfterAdvanceDescription =>
      'Check for heavy damage after advancing successfully.';

  @override
  String get advanceWarningPostBattleDescription =>
      'Check for heavy damage after battle results.';

  @override
  String get advanceWarningBothTimingsDescription =>
      'Check after battle results and after advancing successfully.';

  @override
  String get advanceWarningTimingRequired =>
      'Keep at least one warning timing selected.';

  @override
  String get advanceWarningPostBattleOnlyWarning =>
      'Heavy damage will no longer be checked after advancing successfully.';

  @override
  String get postBattleDamageControlEquippedBody =>
      'A heavily damaged ship remains after battle results. Check the ships and remaining damage control.';

  @override
  String get postBattleDamageControlDangerBody =>
      'A heavily damaged ship remains after battle results! Stop advancing and check the in-game state before entering another battle.';

  @override
  String get advanceWarningDamageControlActive => 'Damage control active';

  @override
  String get advanceWarningReloadGame => 'Reload game';

  @override
  String get advanceWarningReloadFrame => 'Reload frame';

  @override
  String get advanceWarningRefreshFailed =>
      'Refresh did not finish. Check the game state and equipment.';

  @override
  String get logoutSnackbar => 'Logged out and cleared account information.';

  @override
  String get logoutConfirmTitle => 'Log out and clear account information';

  @override
  String get logoutConfirmDesc =>
      'Clear the game page\'s Cookie data, local storage, and cache, then return to the login page. Continue?';

  @override
  String get logoutSucceeded => 'Logged out. Please log in again.';

  @override
  String get logoutFailed => 'Could not log out. Please try again later.';

  @override
  String get questCacheCleared => 'Local quest data cache cleared';

  @override
  String get webCacheCleared => 'Browser cache cleared';

  @override
  String get clearLogbook => 'Clear logbook data';

  @override
  String get clearLogbookDesc =>
      'Delete locally stored sortie, expedition, construction, development, ship removal, and resource records. This cannot be undone.';

  @override
  String get clearLogbookConfirmTitle => 'Clear logbook data';

  @override
  String get clearLogbookConfirmDesc =>
      'Clear all logbook data? Sortie, expedition, construction, development, ship removal, and resource records will be deleted. This cannot be undone.';

  @override
  String get logbookCleared => 'All logbook data cleared';

  @override
  String get antiCatbomb => 'Prevent disconnect errors';

  @override
  String get antiCatbombDesc =>
      'If a game request fails due to a lost connection or similar issue, pause the game and keep retrying to prevent the cat error screen.';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get waitingForData => 'Waiting for data';

  @override
  String get fleetNoShips => 'There are no ships in this fleet';

  @override
  String get unorganized => 'Not formed';

  @override
  String get speed => 'Speed';

  @override
  String get totalLevel => 'Total level';

  @override
  String get firepower => 'Firepower';

  @override
  String get torpedo => 'Torpedo';

  @override
  String get antiAir => 'Anti-air';

  @override
  String get antiSub => 'Anti-sub';

  @override
  String get airPower => 'Air power';

  @override
  String get los => 'LOS';

  @override
  String get avgCondition => 'Minimum morale';

  @override
  String get losDetail => 'LOS details';

  @override
  String get totalLos => 'Total LOS';

  @override
  String get specialAttack => 'Special attacks';

  @override
  String get unknownShip => 'Unknown ship';

  @override
  String get unknownClass => 'Unknown ship type';

  @override
  String get needsResupply => 'Resupply needed';

  @override
  String get fuel => 'Fuel';

  @override
  String get ammo => 'Ammo';

  @override
  String get hp => 'HP';

  @override
  String get waitingForEquip => 'Waiting for equipment data update';

  @override
  String get fastSpeed => 'Fast';

  @override
  String get slowSpeed => 'Slow';

  @override
  String get gotIt => 'Got it';

  @override
  String get unknownEquip => 'Unknown equipment';

  @override
  String get noBonusStats => 'No equipment stats';

  @override
  String get condition => 'Morale';

  @override
  String get noExpeditionFleet => 'No fleets on expedition';

  @override
  String get expeditionInProgress => 'Expedition in progress';

  @override
  String get progress => 'Progress';

  @override
  String get unlocked => 'Locked';

  @override
  String get notRepairing => 'Not in dock';

  @override
  String get repairProgress => 'Repair progress';

  @override
  String get cost => 'Cost';

  @override
  String get notConstructing => 'No construction';

  @override
  String get lsc => 'Large ship construction';

  @override
  String get normalConstruct => 'Normal construction';

  @override
  String get constructing => 'Under construction';

  @override
  String get constructProgress => 'Construction progress';

  @override
  String get constructComplete => 'Construction complete';

  @override
  String get allRatings => 'All ratings';

  @override
  String get noBattleRecords => 'No battle records yet';

  @override
  String get autoRecordHint =>
      'Sorties are recorded automatically. No extra action is needed';

  @override
  String get thisSortie => 'This sortie';

  @override
  String get historicalRecords => 'Battle history';

  @override
  String get resourceTrend => 'Resource trends';

  @override
  String get expeditionIncome => 'Expedition income';

  @override
  String get noHistoricalRecords => 'No battle history yet';

  @override
  String get none => 'None';

  @override
  String get unknownNode => 'Unknown node';

  @override
  String get noResourceRecords => 'No resource records';

  @override
  String get resourceTrend24h => '24 hours';

  @override
  String get resourceTrend7d => '7 days';

  @override
  String get resourceTrend30d => '30 days';

  @override
  String get resourceTrendAll => 'All records';

  @override
  String get resourceTrendMainGroup => 'Four main resources';

  @override
  String get resourceTrendAuxGroup => 'Other resources';

  @override
  String get gadgetBypass => 'Game resource mirror and IP restriction bypass';

  @override
  String get gadgetBypassDesc =>
      'Load static game client resources through a mirror. DMM region compatibility is applied automatically and is unaffected by this switch.';

  @override
  String get gadgetBypassEnable => 'Enable mirror access';

  @override
  String get gadgetBypassEndpoint => 'Mirror endpoint';

  @override
  String get endpointCustom => 'Custom';

  @override
  String get gadgetBypassStatusOn => 'Enabled';

  @override
  String get gadgetBypassStatusOff => 'Disabled';

  @override
  String get gadgetBypassUnsupported =>
      'Not supported on this device (requires Android 8.0+)';

  @override
  String get gadgetBypassClearCache => 'Clear cache';

  @override
  String get gadgetBypassError => 'Could not configure bypass';

  @override
  String get gadgetBypassDiagnose => 'Check 403 errors and mirror connectivity';

  @override
  String get gadgetBypassDiagnosing => 'Diagnosing...';

  @override
  String get gadgetBypassW00g => 'Client server (w00g)';

  @override
  String get gadgetBypassEndpointProbe => 'Mirror endpoint';

  @override
  String get gadgetBypassKcsapi => 'Game data API (kcsapi)';

  @override
  String get gadgetBypassReachable => 'Reachable';

  @override
  String get gadgetBypassUnreachable => 'Unreachable';

  @override
  String get resourceTrendChart => 'Resource trends (last 100 records)';

  @override
  String get steel => 'Steel';

  @override
  String get bauxite => 'Bauxite';

  @override
  String get noExpeditionRecords => 'No expedition records';

  @override
  String get expeditionIncomeChart => 'Expedition income (last 7 days)';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langJa => '日本語';

  @override
  String get node => 'Node';

  @override
  String get friend => 'Friendly';

  @override
  String get enemy => 'Enemy';

  @override
  String get drop => 'Drop';

  @override
  String get inExpedition => 'On expedition';

  @override
  String get unknownProgress => 'Progress unknown';

  @override
  String get waitingForPortDataDescription =>
      'Enter the game\'s home port or reload the game page to update this information automatically';

  @override
  String get fleetNotFormed => 'Not formed';

  @override
  String get fleetStandby => 'Standing by in port';

  @override
  String get shipsCount => ' ships';

  @override
  String get noValue => 'None';

  @override
  String get lineOfSight => 'LOS';

  @override
  String get averageCondition => 'Minimum morale';

  @override
  String get moraleRecoveryCountdown => 'Recovery countdown';

  @override
  String get moraleRecovered => 'Recovered';

  @override
  String get toggleMoraleMetric =>
      'Tap to switch between minimum morale and recovery countdown';

  @override
  String get losDetails => 'LOS details';

  @override
  String get airPowerDetails => 'Air power details';

  @override
  String get minimumValue => 'Minimum';

  @override
  String get maximumValue => 'Maximum';

  @override
  String get withoutBonus => 'Without proficiency bonus';

  @override
  String get showAirPowerDetails => 'Tap to view air power details';

  @override
  String get unknownShipType => 'Unknown ship type';

  @override
  String get needsSupply => 'Resupply needed';

  @override
  String get equipmentDataWaiting => 'Waiting for equipment data update';

  @override
  String get highSpeed => 'Fast';

  @override
  String get lowSpeed => 'Slow';

  @override
  String get unknownEquipment => 'Unknown equipment';

  @override
  String get noAdditionalStats => 'No equipment stats';

  @override
  String get fatigue => 'Morale';

  @override
  String get startupUpdateTitle => 'New version available';

  @override
  String get backgroundAudio => 'Background audio';

  @override
  String get backgroundAudioDesc =>
      'Continue playing game audio when the app is in the background.';

  @override
  String get backgroundGameRetention => 'Keep game in background';

  @override
  String get backgroundGameRetentionDesc =>
      'Show an ongoing notification while the game is running to reduce the chance of the system ending the session after switching apps. May use more battery.';

  @override
  String get backgroundGameRetentionNotificationTitle =>
      'ヤハギ is running in the background';

  @override
  String get backgroundGameRetentionNotificationBody =>
      'Game session active · Tap to return to the game';

  @override
  String get screenAwake => 'Keep screen on';

  @override
  String get screenAwakeDesc =>
      'Keep the screen on while the app is in the foreground. May use more battery.';

  @override
  String get gameToolbar => 'Game toolbar';

  @override
  String get toolbarAutoHide => 'Auto-hide';

  @override
  String get toolbarPersistent => 'Always visible';

  @override
  String get back => 'Back';

  @override
  String get reload => 'Reload';

  @override
  String get home => 'Home';

  @override
  String get enterDmm => 'DMM login';

  @override
  String get enableGameAudio => 'Enable game audio';

  @override
  String get disableGameAudio => 'Mute game audio';

  @override
  String get takeScreenshot => 'Take screenshot';

  @override
  String get screenshotSaving => 'Saving game screenshot…';

  @override
  String get fitGameScreen => 'Fit game to screen';

  @override
  String get collapseToolbar => 'Collapse toolbar';

  @override
  String get editDone => 'Done editing';

  @override
  String get retryWithSystemNetwork => 'Retry with system network';

  @override
  String get displayMode => 'Display orientation';

  @override
  String get displayAuto => 'Automatic';

  @override
  String get displayLandscape => 'Landscape';

  @override
  String get displayPortrait => 'Portrait';

  @override
  String get allRanks => 'All ratings';

  @override
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  ) {
    return 'Friendly $friendAlive/$friendTotal　Enemy $enemyAlive/$enemyTotal';
  }

  @override
  String dropLabel(String name) {
    return 'Drop: $name';
  }

  @override
  String get item => 'Item';

  @override
  String get friendFinalStatus => 'Friendly final status';

  @override
  String get enemyFinalStatus => 'Enemy final status';

  @override
  String get enemyFleet => 'Enemy fleet';

  @override
  String airStateLabel(String label) {
    return 'Air control: $label';
  }

  @override
  String get postBattleWarningTitle => 'Heavy damage safety warning';

  @override
  String get advanceWarningMissingHeadline =>
      'A heavily damaged ship has no damage control equipped!';

  @override
  String get advanceWarningUnknownHeadline =>
      'Damage control status is unknown for a heavily damaged ship!';

  @override
  String get advanceWarningEquippedHeadline =>
      'Heavily damaged ships have damage control equipped. Check their remaining equipment.';

  @override
  String get advanceWarningEquippedBody =>
      'You selected advance with a heavily damaged ship. Check the ships and their remaining damage control.';

  @override
  String get advanceWarningMissing => 'No damage control equipped';

  @override
  String get advanceWarningUnknown =>
      'Damage control status unknown. Check equipment in the game.';

  @override
  String advanceWarningEquipped(String items) {
    return 'Equipped: $items';
  }

  @override
  String get advanceWarningPersonnel => 'Emergency Repair Personnel';

  @override
  String get advanceWarningGoddess => 'Emergency Repair Goddess';

  @override
  String advanceWarningShipPosition(int fleet, int position) {
    return 'Fleet $fleet · Ship $position';
  }

  @override
  String get advanceWarningMuteSortie =>
      'Do not remind me again during this sortie';

  @override
  String get postBattleWarningHeadline =>
      'A ship in the sortie fleet is heavily damaged!';

  @override
  String get postBattleWarningBody =>
      'You selected advance with a heavily damaged ship! Stop all further actions immediately to avoid entering the next battle.';

  @override
  String get acknowledgeAndRetreat => 'Understood';

  @override
  String get postBattleWarningBanner =>
      'Post-battle safety warning: a ship in the sortie fleet is heavily damaged! Retreat now!';

  @override
  String get noActiveExpedition => 'No expeditions in progress';

  @override
  String get noSortieWarnings => 'No sortie warnings';

  @override
  String preSortieCriticalWarning(String fleetName) {
    return '$fleetName has a heavily damaged ship. Stop the sortie!';
  }

  @override
  String preSortieSupplyWarning(String fleetName) {
    return '$fleetName has ships needing resupply';
  }

  @override
  String preSortieFatigueWarning(String fleetName) {
    return '$fleetName has ships whose morale has not recovered';
  }

  @override
  String preSortieMainEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName missing equipment (normal slots): $shipNames';
  }

  @override
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName missing equipment (expansion slots): $shipNames';
  }

  @override
  String get noPinnedQuests => 'No quests in progress';

  @override
  String get questsNeedSync => 'Open the quest screen to sync information';

  @override
  String get questAwaitingConfirmation => 'Goal met (awaiting confirmation)';

  @override
  String get waitingQuestData => 'Waiting for quest data';

  @override
  String get waitingQuestDataDesc =>
      'Open the in-game quest list to sync accepted quests automatically';

  @override
  String get diagnosticsAndAbout => 'Diagnostics and about';

  @override
  String get safetyBoundary => 'Safety boundaries';

  @override
  String get applyingNetworkSettings => 'Applying network settings…';

  @override
  String networkSettingsApplied(String message) {
    return 'Network settings applied: $message';
  }

  @override
  String get clearingProxy => 'Clearing in-app proxy…';

  @override
  String get systemNetworkRestored => 'System network restored.';

  @override
  String screenshotSaved(String path) {
    return 'Game screenshot saved to the gallery: $path';
  }

  @override
  String get screenshotFailed =>
      'Could not save the game screenshot. Please try again later.';

  @override
  String startupUpdateMessage(String version) {
    return 'ヤハギ $version has been released.';
  }

  @override
  String get gameStatusError => 'Game status error';

  @override
  String get gameStatusErrorDesc =>
      'The page or data capture is in an error state. Check diagnostics in Settings.';

  @override
  String get browserOnlyCaptureOff => 'Browser-only mode · Data capture off';

  @override
  String get browserOnlyCaptureOffDesc =>
      'The game page keeps running. Fleet, quest, and battle information will stop updating.';

  @override
  String capturedCount(int count) {
    return 'Captured responses: $count';
  }

  @override
  String get waitingKcsapi => 'Waiting for /kcsapi/ responses';

  @override
  String get ignoredNonTargetMessage => 'Non-target message ignored';

  @override
  String get readOnlyNoActions => 'Read-only access';

  @override
  String get readOnlyNoActionsDesc =>
      'No automatic clicking, resupply, fleet formation, sorties, or quest reward claims.';

  @override
  String get noCookieRead => 'No Cookie access';

  @override
  String get noCookieReadDesc =>
      'The JS bridge captures game data such as API paths, sanitized request parameters, and responses. It does not read Cookie data.';

  @override
  String get browserIdle => 'Waiting for page';

  @override
  String get browserLoading => 'Loading page';

  @override
  String get browserReady => 'Page ready';

  @override
  String get browserFailed => 'Page load failed';

  @override
  String get capturePreparing => 'Preparing game API capture';

  @override
  String get captureReady => 'Capture ready';

  @override
  String get captureActive => 'Capturing game API responses';

  @override
  String get captureUnsupported =>
      'This WebView does not support cross-frame capture';

  @override
  String get captureFailed => 'Could not start game API capture';

  @override
  String get captureCheckingDesc => 'Checking Android WebView capture support.';

  @override
  String get captureReadyDesc =>
      'Waiting for /kcsapi/ responses. You can play the game normally.';

  @override
  String get portCaptureVerified => 'Home port API verified';

  @override
  String get captureReceived => 'Game API response received.';

  @override
  String captureLatest(String path) {
    return 'Latest capture: $path';
  }

  @override
  String get captureUnsupportedDesc =>
      'The game can still run. Only web browsing is supported on this device.';

  @override
  String get captureFailedDesc =>
      'The game can still run. Reload the page to try again.';

  @override
  String networkApplyFailed(String code, String message) {
    return 'Settings failed [$code]: $message';
  }

  @override
  String networkRestoreFailed(String code, String message) {
    return 'Restore failed [$code]: $message';
  }

  @override
  String get tcpConnection => 'TCP connection';

  @override
  String get gameService => 'Game service';

  @override
  String get externalNetwork => 'Google (external network)';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get statusSuccess => 'Success';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get formula33 => 'Formula 33';

  @override
  String fatigueValue(int value) {
    return 'Morale $value';
  }

  @override
  String get fcdMapSectionTitle => 'Data updates';

  @override
  String get fcdMapDataTitle => 'Battle prediction data';

  @override
  String fcdMapDataVersion(String version) {
    return 'Data version: $version';
  }

  @override
  String fcdMapLastChecked(String time) {
    return 'Last checked: $time';
  }

  @override
  String get fcdMapNeverChecked => 'Last checked: never';

  @override
  String fcdMapSource(String source) {
    return 'Update source: $source';
  }

  @override
  String get fcdMapAttribution => 'Data source: poi FCD (MIT)';

  @override
  String get fcdMapCheckUpdates => 'Check for battle prediction data updates';

  @override
  String get fcdMapUpToDate => 'Battle prediction data is up to date.';

  @override
  String fcdMapUpdated(String oldVersion, String newVersion) {
    return 'Battle prediction data updated from $oldVersion to $newVersion. Changes are effective immediately.';
  }

  @override
  String get fcdMapNetworkError =>
      'Could not connect to the data update source. Please try again later.';

  @override
  String get fcdMapValidationError =>
      'Downloaded data failed validation. The current version was kept.';

  @override
  String get fcdMapStorageError =>
      'Could not save the data. The current version was kept.';

  @override
  String get questCatalogDataTitle => 'Quest data';

  @override
  String questCatalogDataVersion(String version) {
    return 'Data version: $version';
  }

  @override
  String get questCatalogNeverChecked => 'Last checked: never';

  @override
  String questCatalogLastChecked(String time) {
    return 'Last checked: $time';
  }

  @override
  String get questCatalogCheckUpdates => 'Check for quest data updates';

  @override
  String get questCatalogUpToDate => 'Quest data is up to date.';

  @override
  String questCatalogUpdated(String oldVersion, String newVersion) {
    return 'Quest data updated from $oldVersion to $newVersion. Changes are effective immediately.';
  }

  @override
  String get questCatalogNetworkError =>
      'Could not connect to the quest data update source. Please try again later.';

  @override
  String get questCatalogValidationError =>
      'Downloaded quest data failed validation. The current version was kept.';

  @override
  String get questCatalogStorageError =>
      'Could not save quest data. The current version was kept.';

  @override
  String get gameFrameRateTitle => 'Game frame rate';

  @override
  String get gameFrameRateAutomatic => 'Automatic';

  @override
  String get gameFrameRateStable60 => '60 FPS';

  @override
  String get gameFrameRateStable60Desc =>
      'Always run at 60 FPS without automatically reducing the frame rate.';

  @override
  String get gameFrameRateStable30 => '30 FPS';

  @override
  String get gameFrameRateStable30Desc =>
      'Always run at 30 FPS to reduce battery use and heat.';

  @override
  String get gameFrameRateHighRefresh => 'High refresh rate';

  @override
  String get gameFrameRateHighRefreshDesc =>
      'Remove the 60 FPS limit and follow the screen\'s refresh rate. May increase battery use and heat.';

  @override
  String get gameFrameRateHighRefreshDialogTitle => 'Enable high refresh rate?';

  @override
  String get gameFrameRateHighRefreshDialogBody =>
      'This changes the game\'s frame rate and may increase battery use, heat, or cause animation issues. It also carries unknown account risks. You accept responsibility for any consequences.';

  @override
  String get gameFrameRateHighRefreshDialogConfirm => 'Accept risks and enable';

  @override
  String get gameFrameRateAutomaticDesc =>
      'Up to 60 FPS. Automatically reduce to 30 FPS if performance stays unstable, system battery saver is on, or the device gets hot.';

  @override
  String get gameFrameRateUnsupported =>
      'This Android WebView does not support frame rate adjustments. The game\'s original frame rate will be used.';

  @override
  String get gameRenderingModeTitle => 'Game rendering mode';

  @override
  String get gameRenderingModeStandard => 'Lightweight';

  @override
  String get gameRenderingModeStandardDesc =>
      'Flutter PlatformView + Texture Layer + WebGL. Reduces some compositing overhead, but may cause display or touch compatibility issues on some devices.';

  @override
  String get gameRenderingModeCompatibility => 'Balanced';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Flutter PlatformView + Hybrid Composition + WebGL. Balances game performance and device compatibility.';

  @override
  String get gameRenderingModeCanvas => 'Compatibility';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Flutter PlatformView + Hybrid Composition + Canvas. Bypasses WebGL to prioritize resolving GPU / WebGL compatibility issues. Rendering performance may be lower.';

  @override
  String get gameRenderingModeNativeActivity =>
      'Independent native rendering (recommended)';

  @override
  String get gameRenderingModeNativeActivityDesc =>
      'Activity Direct WebView + WebGL. In theory, this reduces compositing overhead and improves native compatibility.';

  @override
  String get gameRenderingModeConfirmTitle => 'Switch game rendering mode?';

  @override
  String get gameRenderingModeConfirmMessage =>
      'Switching rendering mode automatically restarts the app and reloads the game page. Finish any actions in progress first.';

  @override
  String get gameRenderingModeBattleWarning =>
      'A battle may be in progress. Switching now could interrupt the battle page. Wait until the battle is over.';

  @override
  String get gameRenderingModeChanging => 'Rebuilding game page…';

  @override
  String get gameRenderingModeApplied => 'Rendering mode changed.';

  @override
  String get gameRenderingModeFailed =>
      'Could not switch modes. The previous setting was kept or a safe mode was restored.';

  @override
  String get nativeGameSurfaceSwitchRenderingModeHint =>
      'This device is not compatible with this mode. Scroll the left menu and go to [Settings - Game runtime] to change the rendering mode.';

  @override
  String nativeGameSurfacePageInitializationFailed(
    String stage,
    String errorType,
  ) {
    return 'Game page initialization failed [$stage]: $errorType';
  }

  @override
  String get senka => 'Senka';

  @override
  String get ownedInventory => 'Inventory';

  @override
  String get improvement => 'Improvement';

  @override
  String get briefing => 'Summary';

  @override
  String get check => 'Check';

  @override
  String get restoreDefaultOrder => 'Restore default order';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String sortPriority(int priority) {
    return 'Priority $priority';
  }

  @override
  String get sortLockedState => 'Locked';

  @override
  String get sortTemporaryState => 'Temporary sort';

  @override
  String get sortHeaderHint =>
      'Tap to change sorting. Long-press or press Shift+Enter to lock';

  @override
  String get sortHeaderLockedHint =>
      'Tap to reverse sorting. Long-press or press Shift+Enter to unlock';

  @override
  String get sortLockAction => 'Lock as the next priority';

  @override
  String get sortUnlockAction => 'Unlock current sort';

  @override
  String get settingsTabScreen => 'Appearance & layout';

  @override
  String get settingsTabSound => 'Sound';

  @override
  String get settingsTabBattle => 'Sortie & battle';

  @override
  String get settingsTabNotification => 'Notifications & reminders';

  @override
  String get settingsTabNetwork => 'Network & connection';

  @override
  String get settingsTabData => 'Data management';

  @override
  String get settingsTabAboutSupport => 'About & support';

  @override
  String get notificationSectionSystem => 'System notification status';

  @override
  String get notificationSectionSystemDesc =>
      'Allow notifications and exact alarms to receive expedition, dock, and other reminders on time while the screen is locked or the app is in the background. This helps prevent delays from system battery saving. Tap an item to open its system settings.';

  @override
  String get notificationPermissionGranted => 'Notifications allowed';

  @override
  String get notificationPermissionDenied => 'Notifications not allowed';

  @override
  String get notificationExactAlarmGranted => 'Exact alarms allowed';

  @override
  String get notificationExactAlarmDenied =>
      'Exact alarms not allowed. Using battery-compatible mode';

  @override
  String get notificationChannelsEnabled => 'Notification channels available';

  @override
  String get notificationChannelsDisabled =>
      'Notification channels disabled by the system';

  @override
  String get notificationSectionGeneral => 'Global notification service';

  @override
  String get notificationEnableMaster => 'Enable notifications';

  @override
  String get notificationSound => 'Notification sound';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get notificationSectionOngoing => 'Ongoing background progress';

  @override
  String get notificationOngoingLive => 'Persistent live progress card';

  @override
  String get notificationProgress => 'Progress bar';

  @override
  String get notificationPercent => 'Percentage';

  @override
  String get notificationCountdown => 'Live countdown';

  @override
  String get notificationSectionTypes => 'Notification types and timing';

  @override
  String get notificationExpedition => 'Expedition';

  @override
  String get notificationRepair => 'Dock repair';

  @override
  String get notificationAnchorage => 'Anchorage repair';

  @override
  String get notificationConstruction => 'Construction';

  @override
  String get notificationMorale => 'Morale / sparkle';

  @override
  String get notificationPunctual => 'On completion';

  @override
  String get notificationPreempt30s => '30 seconds early';

  @override
  String get notificationPreempt60s => '60 seconds early';

  @override
  String get notificationPreempt120s => '2 minutes early';

  @override
  String get notificationRepairPunctual => 'On completion';

  @override
  String get notificationAnchorage20m => 'First repair after 20 minutes';

  @override
  String get notificationAnchorageFull => 'All repairs complete';

  @override
  String get notificationAnchorageBoth => 'Both stages';

  @override
  String get frameRateSettingsSection => 'Frame rate settings';

  @override
  String get battleAlertsSection => 'Battle alerts';

  @override
  String get battleDamageVibration => 'Vibrate on battle damage';

  @override
  String get battleDamageVibrationDesc =>
      'Vibrate when a friendly ship first becomes moderately or heavily damaged in battle.';

  @override
  String get battleStatusEffectsSection => 'Battle status effects';

  @override
  String get battleStatusEffectsEnabled => 'Enable status effects';

  @override
  String get battleStatusEffectsEnabledDesc =>
      'Turn damage pulses, damage vibration, and morale sparkle on or off together.';

  @override
  String get battleEffectDisplayScope => 'Display scope';

  @override
  String get battleEffectDisplayScopeDesc =>
      'Choose which ship views show damage pulses and morale sparkle.';

  @override
  String get battleEffectScopePredictionOnly => 'Battle prediction only';

  @override
  String get battleEffectScopeFleetOnly => 'Fleet only';

  @override
  String get battleEffectScopeAll => 'All';

  @override
  String get battleDamagePulse => 'Damage pulse';

  @override
  String get battleDamagePulseDesc =>
      'Pulse portrait borders according to the current HP damage level.';

  @override
  String get battleDamageVibrationEffect => 'Damage vibration';

  @override
  String get battleDamageVibrationEffectDesc =>
      'Vibrate when a friendly ship first enters a selected damage state in battle.';

  @override
  String get battleMoraleSparkle => 'Morale sparkle';

  @override
  String get battleMoraleSparkleDesc =>
      'Show blinking or steady stars around portraits at Cond ≥ 50. Fatigue faces and warnings are unaffected.';

  @override
  String get battleMoraleSparkleBlinking => 'Blinking';

  @override
  String get battleMoraleSparkleSteady => 'Steady';

  @override
  String get battleEffectOff => 'Off';

  @override
  String get battleEffectMinorOnly => 'Light damage only';

  @override
  String get battleEffectModerateOnly => 'Moderate damage only';

  @override
  String get battleEffectHeavyOnly => 'Heavy damage only';

  @override
  String get battleEffectAll => 'Enable all';

  @override
  String get battlePredictionSection => 'Battle prediction';

  @override
  String get battleEnemyPreviewPortraits => 'Pre-battle enemy portraits';

  @override
  String get battleEnemyPreviewPortraitsDesc =>
      'Show enemy portraits before battle in the prediction panel.';

  @override
  String get battleLastFormationHint => 'Show last formation';

  @override
  String get battleLastFormationHintDesc =>
      'When reaching a sortie node, show the formation last used there in the prediction panel.';

  @override
  String get battleEnemyPreviewPosition => 'Pre-battle enemy preview position';

  @override
  String get battleEnemyPreviewPositionDesc =>
      'Show the pre-battle enemy preview above or below friendly HP bars.';

  @override
  String get battleEnemyPreviewPositionAbove => 'Above';

  @override
  String get battleEnemyPreviewPositionBelow => 'Below';

  @override
  String get battleSectionOrder => 'Information section order';

  @override
  String get battleSectionOrderDescription =>
      'Reorder the information sections';

  @override
  String get battleSectionOrderAdjust => 'Adjust';

  @override
  String get battleSectionOrderHint =>
      'Use the arrows to reorder. Changes are saved automatically';

  @override
  String get battleSectionSortieMap => 'Sortie minimap';

  @override
  String get battleSectionEnemyPreview => 'Enemy preview';

  @override
  String get battleSectionPredictionResult => 'Prediction results';

  @override
  String get battleSectionOrderRestoreDefault => 'Restore defaults';

  @override
  String get battleSectionOrderSaveFailed =>
      'Could not save. Please try again.';

  @override
  String battleSectionOrderMoveUp(String section) {
    return 'Move $section up';
  }

  @override
  String battleSectionOrderMoveDown(String section) {
    return 'Move $section down';
  }

  @override
  String battleLastFormation(String formation) {
    return 'Last used: $formation';
  }

  @override
  String get improvementDatasetTitle => 'Improvement planning data';

  @override
  String improvementDatasetVersion(String version) {
    return 'Data version $version';
  }

  @override
  String get improvementDatasetNeverChecked => 'Not checked manually yet';

  @override
  String improvementDatasetLastChecked(String time) {
    return 'Last checked $time';
  }

  @override
  String get improvementDatasetManualUpdate =>
      'Update improvement data manually';

  @override
  String improvementDatasetUpToDate(String version) {
    return 'Data is up to date ($version)';
  }

  @override
  String improvementDatasetUpdated(String oldVersion, String newVersion) {
    return 'Improvement data updated from $oldVersion to $newVersion. The page has refreshed.';
  }

  @override
  String improvementDatasetNetworkError(String version) {
    return 'Network connection failed. Continuing with local data ($version).';
  }

  @override
  String improvementDatasetValidationError(String version) {
    return 'Remote data failed validation. Local data ($version) was kept.';
  }

  @override
  String improvementDatasetStorageError(String version) {
    return 'Could not save data. Local data ($version) was kept.';
  }

  @override
  String get networkValidationHostEmpty => 'Enter an address';

  @override
  String get networkValidationControlCharacter =>
      'Line breaks and control characters are not allowed';

  @override
  String get networkValidationHttpScheme =>
      'Enter only the server address, without http://.';

  @override
  String get networkValidationSocksScheme =>
      'Enter only the server address, without socks://.';

  @override
  String get networkValidationScheme => 'Do not include a protocol prefix';

  @override
  String get networkValidationPath => 'Paths are not allowed';

  @override
  String get networkValidationCredentials =>
      'Usernames and passwords are not allowed';

  @override
  String get networkValidationIpv6 =>
      'Invalid IPv6 address (contains invalid characters)';

  @override
  String get networkValidationPortEmpty => 'Enter a port';

  @override
  String get networkValidationPortDecimal =>
      'The port cannot contain decimal places';

  @override
  String get networkValidationPortNegative => 'The port cannot be negative';

  @override
  String get networkValidationPortZero => 'The port cannot be 0';

  @override
  String get networkValidationPortInteger => 'The port must be an integer';

  @override
  String get networkValidationPortRange =>
      'The port must be between 1 and 65535';

  @override
  String get gadgetBypassRestricted => 'Restricted';

  @override
  String get networkProxyOperationBusy => 'Proxy settings are being applied';

  @override
  String get networkUnknownProxyMode => 'Unknown proxy mode';

  @override
  String get shipGirl => 'Ships';

  @override
  String get equipment => 'Equipment';

  @override
  String get inventoryTypeSuffix => ' types';

  @override
  String get inventoryFilterResults => 'Filtered results ';

  @override
  String get inventoryOwned => 'Owned';

  @override
  String get inventoryUnowned => 'Not owned';

  @override
  String unownedShipSummary(int count, int excluded) {
    return 'Ships shown: $count · Excluded: $excluded';
  }

  @override
  String get unownedShipExcludedLabel => 'Excluded';

  @override
  String get unownedShipReminderHint =>
      'Newly acquired unchecked ships trigger normal alerts and vibration. Checked ships will not trigger alerts.';

  @override
  String get clearNewShipExclusions => 'Clear exclusions';

  @override
  String get resetFilter => 'Reset filters';

  @override
  String unownedEquipmentSummary(int count) {
    return 'Unowned equipment shown: $count';
  }

  @override
  String get otherType => 'Other';

  @override
  String newShipFallbackName(int id) {
    return 'Ship No.$id';
  }

  @override
  String get newShipAlertTitle => 'New unowned ship found';

  @override
  String newShipAlertBody(String names) {
    return '$names · Remember to lock them';
  }

  @override
  String get acknowledge => 'Got it';

  @override
  String get shipName => 'Ship name';

  @override
  String get shipType => 'Ship type';

  @override
  String get level => 'Level';

  @override
  String get armor => 'Armor';

  @override
  String get luck => 'Luck';

  @override
  String get evasion => 'Evasion';

  @override
  String get lockedStatus => 'Lock';

  @override
  String get equipmentName => 'Equipment name';

  @override
  String get equipmentTotalRemaining => 'Total (remaining)';

  @override
  String get equipmentImprovementProficiency => 'Improvement / proficiency';

  @override
  String get equipmentOfficialId => 'Official ID';

  @override
  String get equipmentInstanceId => 'Instance ID';

  @override
  String get equipmentUsage => 'Equipped status';

  @override
  String get highSpeedPlus => 'Fast+';

  @override
  String get all => 'All';

  @override
  String get equipmentMainGun => 'Main guns';

  @override
  String get equipmentSecondaryGun => 'Secondary / high-angle guns';

  @override
  String get equipmentMachineGun => 'Machine guns';

  @override
  String get equipmentTorpedo => 'Torpedoes / Midget submarines';

  @override
  String get equipmentCarrierAircraft => 'Carrier aircraft';

  @override
  String get equipmentSeaplane => 'Seaplanes';

  @override
  String get equipmentLandBasedAircraft => 'Land-based aircraft';

  @override
  String get equipmentRadar => 'Radar';

  @override
  String get equipmentLandingTransport => 'Landing / transport';

  @override
  String get equipmentSupport => 'Support / other';

  @override
  String get questAll => 'All quests';

  @override
  String get chineseTranslation => 'Chinese translation';

  @override
  String get searchQuest => 'Search quests';

  @override
  String get filterQuest => 'Filter quests';

  @override
  String get searchQuestHint =>
      'Search ID, name, description, or rewards. Separate keywords with spaces to match any';

  @override
  String get questAvailable => 'Not accepted';

  @override
  String get questAcceptedOnly => 'Accepted only (including rewards pending)';

  @override
  String get questClaimable => 'Rewards pending';

  @override
  String get questInferredCompleted => 'Inferred complete';

  @override
  String get questStateUnknown => 'Status unknown';

  @override
  String get questFilterHelp =>
      'Unlocked includes unaccepted, active, and reward-pending quests. Locked includes unknown states. Completed includes reward-pending and inferred-complete quests.';

  @override
  String get questNoResults => 'No matching quests';

  @override
  String get questNoResultsHint =>
      'Try changing the search or clearing the filters.';

  @override
  String questResultsCount(int count) {
    return 'Quests: $count';
  }

  @override
  String get clear => 'Clear';

  @override
  String get done => 'Done';

  @override
  String get clearAll => 'Clear all';

  @override
  String get questType => 'Quest type';

  @override
  String get allTypes => 'All types';

  @override
  String get questFormation => 'Fleet formation';

  @override
  String get questSortie => 'Sortie';

  @override
  String get questExercise => 'Exercise';

  @override
  String get questSupplyRepair => 'Resupply / dock repair';

  @override
  String get questFactory => 'Arsenal';

  @override
  String get questRemodeling => 'Remodel';

  @override
  String get questPeriod => 'Quest cycle';

  @override
  String get allPeriods => 'All cycles';

  @override
  String get questSeasonal => 'Quarterly';

  @override
  String get questYearly => 'Yearly';

  @override
  String get unlockStatus => 'Unlock status';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get questUnlocked => 'Unlocked';

  @override
  String get questLocked => 'Locked';

  @override
  String get noDescription => 'No description';

  @override
  String get completionConditions => 'Completion conditions';

  @override
  String get questRelations => 'Quest relationships';

  @override
  String get prerequisiteQuests => 'Prerequisite quests';

  @override
  String get followingQuests => 'Following quests';

  @override
  String get notCompleted => 'Not completed';

  @override
  String get gameResourceCacheTitle => 'Local game resource cache';

  @override
  String get gameResourceCacheDesc =>
      'Resources are downloaded from the official 艦隊これくしょん servers. The cache can be cleared at any time.';

  @override
  String get gameResourceCacheNone => 'Temporary cache';

  @override
  String get gameResourceCacheNoneDesc =>
      'No pre-downloads. Cache resources as you play, for up to 7 days and 2 GB. Expired files and data over the limit are cleared automatically.';

  @override
  String get gameResourceCacheLight => 'Light cache';

  @override
  String get gameResourceCacheLightDesc =>
      'Cache startup files, common UI, owned ship portraits, and equipment resources.';

  @override
  String get gameResourceCacheFull => 'Local cache';

  @override
  String get gameResourceCacheFullDesc =>
      'Pre-download basic resources (about 5.72 GB). You can keep playing while they download. New content is cached automatically as you play.';

  @override
  String get gameResourceCacheStart => 'Start download';

  @override
  String get gameResourceCachePause => 'Pause download';

  @override
  String get gameResourceCacheResume => 'Resume download';

  @override
  String get gameResourceCacheCheck => 'Check integrity';

  @override
  String get gameResourceCacheRepair => 'Download missing files / repair';

  @override
  String get gameResourceCacheClear => 'Clear local cache';

  @override
  String get gameResourceCacheIntegrityComplete => 'Cache is complete';

  @override
  String get gameResourceCacheMissing => 'Missing';

  @override
  String get gameResourceCacheDamaged => 'Damaged';

  @override
  String get gameResourceCacheOutdated => 'Pending verification';

  @override
  String get gameResourceCacheItems => 'items';

  @override
  String gameResourceCacheStoredSize(String size) {
    return 'Cached: $size';
  }

  @override
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  ) {
    return 'Missing $missing · Damaged $damaged · Pending verification $pending';
  }

  @override
  String get gameResourceCachePendingRetained =>
      'Resources pending verification are kept locally and are not deleted automatically.';

  @override
  String get gameResourceCacheDownloadConfirmTitle => 'Download cache?';

  @override
  String get gameResourceCacheDownloadConfirmDesc =>
      'Download resources for the selected mode in bulk from the official servers. You can pause and resume at any time.';

  @override
  String get gameResourceCacheMobileConfirmDesc =>
      'You are using a mobile network. Continuing will use mobile data. Allow this download?';

  @override
  String get gameResourceCacheWaitingForWifi =>
      'Waiting for Wi-Fi. Downloading will resume automatically when connected.';

  @override
  String get gameResourceCacheClearConfirmTitle => 'Clear game resource cache?';

  @override
  String get gameResourceCacheClearConfirmDesc =>
      'Delete downloaded game resources. The mode setting will be kept.';

  @override
  String get gameResourceCacheCapacityBlocked =>
      'Not enough free storage, or the local game resource cache has reached its 50 GB limit.';

  @override
  String get gameResourceCacheActionFailed =>
      'Could not complete the cache operation. Please try again later.';

  @override
  String get gameResourceCacheUnsupported =>
      'This Android WebView does not support local game resource caching. Update WebView.';

  @override
  String get gameResourceCacheUnavailable =>
      'Local cache initialization or cleanup failed. Check storage space and restart the app. Game browsing is unaffected.';

  @override
  String get gameResourceCacheManifestFailed =>
      'Could not load the pre-download resource list. Try again after entering the game.';

  @override
  String get confirmGameRefreshTitle => 'Refresh the game?';

  @override
  String get gameRefreshDialogDescription =>
      'Refresh the game?\n\nRefresh game page works like a browser refresh.\nReload game reloads only the game frame and is usually faster, but may cause cat errors or network issues. Use at your own risk.';

  @override
  String get refreshGamePage => 'Refresh game page';

  @override
  String get reloadGame => 'Reload game';

  @override
  String get frameRefreshShortcutLabel => 'Refresh game frame';

  @override
  String get frameRefreshShortcutConfirmTitle => 'Refresh the game frame?';

  @override
  String get frameRefreshShortcutConfirmDescription =>
      'Reloading only the game frame is usually faster, but may cause cat errors or network issues. Use at your own risk.';

  @override
  String get frameRefreshShortcutSkipConfirmation => 'Do not ask again';

  @override
  String get frameRefreshShortcutConfirmAction => 'Refresh';

  @override
  String get gameFrameNotFound =>
      'Game frame not found. Enter the game and try again.';

  @override
  String get gameHtmlWrapNotFound =>
      'Game content not found. Wait for the page to load and try again.';

  @override
  String get gameFrameReloadBlocked =>
      'Could not reload the game frame. Please try again later.';

  @override
  String get gameFrameReloadUnsupported =>
      'This device\'s Android WebView is too old to support injection into subframes.';

  @override
  String get logbookResourceDrop => 'Resource drops';

  @override
  String get logbookItemDrop => 'Item drops';

  @override
  String get logbookResourceNode => 'Resource node';

  @override
  String get logbookFriendFormation => 'Friendly formation';

  @override
  String get logbookEnemyFormation => 'Enemy formation';

  @override
  String get logbookAirSuperiority => 'Air control state';

  @override
  String get airSuperiorityParity => 'Air parity';

  @override
  String get airSuperioritySecured => 'Air supremacy';

  @override
  String get airSuperiorityAdvantage => 'Air superiority';

  @override
  String get airSuperiorityDisadvantage => 'Air disadvantage';

  @override
  String get airSuperiorityLost => 'Air control lost';

  @override
  String get logbookHeavyDamageShips => 'Heavily damaged ships';

  @override
  String get gameConnectorTitle => 'Game connection';

  @override
  String get gameConnectorYahagi => 'Yahagi connection';

  @override
  String get gameConnectorYahagiDesc =>
      'Use the current official DMM login page.';

  @override
  String get gameConnectorOoi => 'OOI connection (experimental)';

  @override
  String get gameConnectorOoiDesc =>
      'Open the ooi.moe login page unchanged. Choose mode 1, 3, or 4 yourself.';

  @override
  String get gameConnectorConfirmTitle => 'Switch game connection?';

  @override
  String get gameConnectorOoiRisk =>
      'Your account credentials will be sent to the third-party site ooi.moe. Yahagi does not read, save, or automatically fill in your account or password.';

  @override
  String get gameConnectorActiveWarning =>
      'Switching interrupts the current game page and opens the selected login page.';

  @override
  String get gameConnectorApplied => 'Game connection changed.';

  @override
  String get gameConnectorSaveFailed =>
      'Could not save the connection choice. The current connection was kept.';

  @override
  String get gameConnectorNavigationFailed =>
      'The connection was saved, but the login page could not be opened. Please try again.';

  @override
  String get kcwikiReportSection => 'KCWiki data contribution';

  @override
  String get kcwikiReportTitle => 'Help KCWiki collect data';

  @override
  String get kcwikiReportDisabledDesc =>
      'Off by default. When off, no data is collected, packaged, or sent. The game and local features are unaffected.';

  @override
  String get kcwikiReportEnabledDesc =>
      'Enabled. Sends only routing, quest prerequisite, battle, friendly fleet, land-base/air raid, and improvement data.';

  @override
  String get kcwikiReportConfirmTitle => 'Enable KCWiki data contribution?';

  @override
  String get kcwikiReportConfirmDesc =>
      'When enabled, the app sends routing, quest prerequisite, battle, friendly fleet, land-base/air raid, and improvement records to the configured HTTPS address. It does not send login tokens, Cookie data, or request headers. Upload failures do not block game features.';

  @override
  String get kcwikiReportUnavailable =>
      'This version has no secure HTTPS reporting address configured, so data contribution cannot be enabled.';

  @override
  String get kcwikiReportEnable => 'Opt in';

  @override
  String get kcwikiReportSaveFailed =>
      'Could not save KCWiki data contribution settings. Please try again.';

  @override
  String kcwikiReportCaptureFailed(String error) {
    return 'Could not switch KCWiki data collection: $error';
  }

  @override
  String get kcwikiReportWaiting => 'Enabled. Waiting for data to contribute.';

  @override
  String kcwikiReportProcessing(String module, String time) {
    return 'Uploading: $module · $time';
  }

  @override
  String kcwikiReportParseRecovered(String time) {
    return 'Recovered from a large-data parsing timeout. Processing subsequent data · $time';
  }

  @override
  String kcwikiReportFailureHttp(String status) {
    return 'HTTP $status';
  }

  @override
  String get kcwikiReportFailureTimeout => 'Connection timed out';

  @override
  String get kcwikiReportFailureNetwork => 'Network failure';

  @override
  String get kcwikiReportFailureBodyTooLarge =>
      'Data exceeds the per-upload limit';

  @override
  String get kcwikiReportFailureQueueFull => 'Local queue is full';

  @override
  String get kcwikiReportFailureLocal => 'Local processing failed';

  @override
  String kcwikiReportCounters(int succeeded, int failed, int dropped) {
    return 'Succeeded $succeeded · Failed $failed · Dropped $dropped';
  }

  @override
  String kcwikiReportLastSuccess(
    String module,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return 'Last successful upload: $module · $time · Succeeded $succeeded · Failed $failed · Dropped $dropped';
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
    return 'Last failed upload: $module ($status) · $time · Succeeded $succeeded · Failed $failed · Dropped $dropped';
  }

  @override
  String get landBaseBrief => 'Land base summary';

  @override
  String get landBaseNoData => 'No data';

  @override
  String landBaseAreaFallback(int areaId) {
    return 'Map area $areaId';
  }

  @override
  String landBaseUnitCount(int count) {
    return 'Air squadrons: $count';
  }

  @override
  String get landBaseRange => 'Combat radius';

  @override
  String get landBaseActionSortie => 'Sortie';

  @override
  String get landBaseActionAirDefense => 'Air defense';

  @override
  String get landBaseActionRest => 'Rest';

  @override
  String get landBaseActionRetreat => 'Evacuate';

  @override
  String get landBaseMissingPlanes => 'Missing aircraft';

  @override
  String get landBaseRelocating => 'Relocating';

  @override
  String get senkaInfoTab => 'Senka information';

  @override
  String get senkaCalendarTab => 'Senka calendar';

  @override
  String get senkaCalculatorTab => 'Senka calculator';

  @override
  String get senkaSaveFailedWarning =>
      'Could not save senka data. It may be lost after restarting';

  @override
  String get senkaLatestRanking => 'Latest ranking senka';

  @override
  String get senkaTarget => 'Target senka';

  @override
  String senkaGap(String value) {
    return '$value senka short of target';
  }

  @override
  String senkaOver(String value) {
    return '$value senka above target';
  }

  @override
  String get senkaPlannedEo => 'Planned EO';

  @override
  String get senkaPlannedQuest => 'Planned quests';

  @override
  String get senkaDailyRequired => 'Daily requirement';

  @override
  String get senkaTodayRemaining => 'Remaining today';

  @override
  String get senkaUnsettledDelta => 'Gain since last tally';

  @override
  String get senkaAvailableDaysIncludingToday =>
      'Days available (including today)';

  @override
  String get senkaProjected => 'Projected senka';

  @override
  String get senkaUnit => 'Senka';

  @override
  String senkaInputTitle(String label) {
    return 'Enter $label';
  }

  @override
  String get senkaInvalidNumber => 'Enter a valid number';

  @override
  String get senkaPlannedEoReward => 'Planned EO senka rewards';

  @override
  String get senkaPlannedQuestReward => 'Planned quest senka rewards';

  @override
  String get senkaTotal => 'Total';

  @override
  String get senkaEoRewards => 'EO senka rewards';

  @override
  String get senkaQuarterlyQuests => 'Quarterly senka quests';

  @override
  String get senkaAnnualQuests => 'Yearly senka quests';

  @override
  String get senkaOneTimeQuests => 'One-time senka quests';

  @override
  String get senkaRewardLegend =>
      'Yellow＋✕: deferred, excluded from projections. Green＋✓: planned completion, included in projections. Gray＋○: completed, not counted again.';

  @override
  String get senkaRewardDeferred => 'Deferred';

  @override
  String get senkaRewardPlanned => 'Planned (included)';

  @override
  String get senkaRewardCompleted => 'Completed';

  @override
  String senkaCalendarTitle(int year, int month) {
    return 'Senka calendar: $year-$month';
  }

  @override
  String senkaCalendarSummary(String recorded, String base) {
    return 'Recorded this month $recorded · Base senka this month $base';
  }

  @override
  String get senkaExperience => 'Experience';

  @override
  String get senkaQuest => 'Quests';

  @override
  String senkaCalendarCell(int year, int month, int day, String value) {
    return '$year-$month-$day, senka $value';
  }

  @override
  String get senkaServer => 'Server';

  @override
  String get senkaRanking => 'Senka ranking';

  @override
  String get senkaRank => 'Rank';

  @override
  String senkaUpdated(String time) {
    return 'Updated: $time';
  }

  @override
  String get senkaOrder => 'Rank';

  @override
  String get senkaChange => 'Change';

  @override
  String get senkaCurrent => 'Current';

  @override
  String get senkaSortieStats => 'Sortie map statistics';

  @override
  String get senkaLatestRecord => 'Latest record';

  @override
  String get senkaMonthSorties => 'Sorties this month';

  @override
  String get senkaBossArrivals => 'Boss reached';

  @override
  String get senkaSWins => 'S wins';

  @override
  String get senkaMonth => 'This month';

  @override
  String get senkaToday => 'Today';

  @override
  String get senkaShowHiddenAreas => 'Show hidden maps';

  @override
  String get senkaShowHidden => 'Show hidden';

  @override
  String get senkaArea => 'Map';

  @override
  String get senkaBoss => 'Boss';

  @override
  String get senkaSorties => 'Sorties';

  @override
  String get senkaResult => 'S / A';

  @override
  String get senkaActions => 'Actions';

  @override
  String senkaFavoriteArea(String map) {
    return 'Favorite map $map';
  }

  @override
  String senkaHideArea(String map) {
    return 'Hide map $map';
  }

  @override
  String get senkaUnknownServer => 'Unknown server';

  @override
  String get toolbox => 'Toolbox';

  @override
  String get fleetExport => 'Export data';

  @override
  String get otherTools => 'Other';

  @override
  String get noro6 => 'noro6';

  @override
  String get jervis => 'Jervis';

  @override
  String get exportToNoro6 => 'Export to noro6';

  @override
  String get exportToNoro6Mirror => 'Export to noro6 (China mirror)';

  @override
  String get exportToJervis => 'Export to Jervis';

  @override
  String get eventLandBasesOnly => 'Export event map land bases only';

  @override
  String get landBaseExportLimitHint =>
      'DeckBuilder supports up to 3 air squadrons at a time. With the filter off, the first 3 are exported in capture order.';

  @override
  String get fleetExportText => 'Fleet export text';

  @override
  String get deckBuilderV4 => 'DeckBuilder v4';

  @override
  String get refreshExportText => 'Refresh';

  @override
  String get copyExportText => 'Copy text';

  @override
  String get openInSystemBrowser => 'Open in system default browser';

  @override
  String get otherToolsComingSoon => 'More tools are in development';

  @override
  String get otherToolsHint => 'New helper tools will be added here.';

  @override
  String get waitingForPortData => 'Waiting for home port data';

  @override
  String get externalFleetToolOpenFailed =>
      'Could not open the external fleet tool. Check that a browser is installed.';

  @override
  String get fleetExportCopied => 'Fleet export text copied.';

  @override
  String get fleetExportCopyFailed => 'Could not copy. Please try again later.';

  @override
  String equipmentCompatibilitySummary(int owned, int all) {
    return 'Can equip: owned $owned / all $all';
  }

  @override
  String equipmentCompatibilityOwnedTab(int count) {
    return 'Owned ships $count';
  }

  @override
  String equipmentCompatibilityAllTab(int count) {
    return 'All ships $count';
  }

  @override
  String equipmentCompatibilityOwnedCompact(int count) {
    return 'Owned $count';
  }

  @override
  String equipmentCompatibilityAllCompact(int count) {
    return 'All $count';
  }

  @override
  String get equipmentCompatibilitySelectShipType => 'Select ship type';

  @override
  String get equipmentCompatibilitySearchHint => 'Search ships';

  @override
  String get equipmentCompatibilityAllSlots => 'All slots';

  @override
  String get equipmentCompatibilityRegularSlot => 'Normal slot';

  @override
  String get equipmentCompatibilityExpansionSlot => 'Expansion slot';

  @override
  String get equipmentCompatibilityBothSlots => 'Normal＋expansion slots';

  @override
  String equipmentCompatibilityExpansionRequirement(int level) {
    return 'Expansion slot requires ★+$level';
  }

  @override
  String equipmentCompatibilityOwnedLevels(String levels) {
    return 'Lv.$levels';
  }

  @override
  String equipmentCompatibilityFleetNumbers(String numbers) {
    return 'Fleet $numbers';
  }

  @override
  String get equipmentCompatibilityEmpty => 'No matching ships';

  @override
  String equipmentCompatibilityOfficialId(int id) {
    return 'Equipment ID $id';
  }

  @override
  String equipmentCompatibilityOwnedCount(int count) {
    return 'Owned $count';
  }

  @override
  String equipmentCompatibilityRegularCount(int count) {
    return 'Normal slots $count';
  }

  @override
  String equipmentCompatibilityExpansionCount(int count) {
    return 'Expansion slots $count';
  }

  @override
  String get equipmentCompatibilitySource =>
      'Rules source: official game master data';

  @override
  String get equipmentCompatibilityRulesWaiting =>
      'Waiting for equipment rule data';

  @override
  String get equipmentCompatibilityEmptyOwned =>
      'You do not own any ships that can equip this';

  @override
  String get equipmentCompatibilityEmptyAll =>
      'No ship forms that can equip this were found';

  @override
  String equipmentCompatibilityCategory(String category) {
    return 'Category: $category';
  }

  @override
  String equipmentCompatibilityShipClassId(int id) {
    return 'Ship class #$id';
  }

  @override
  String get shipEquipmentCompatibilitySelectCategory =>
      'Select equipment category';

  @override
  String get shipEquipmentCompatibilitySearchTitle => 'Search equipment';

  @override
  String get shipEquipmentCompatibilitySearchHint => 'Enter equipment name';

  @override
  String shipEquipmentCompatibilityOwnedCount(int count) {
    return 'Owned X$count';
  }

  @override
  String get shipEquipmentCompatibilityEmpty => 'No compatible equipment found';

  @override
  String get equipmentDevelopment => 'Equipment development';

  @override
  String get development => 'Development';

  @override
  String get developmentCommandTitle => 'Development console';

  @override
  String get developmentWorkbenchTitle => 'Development workbench';

  @override
  String get developmentCalculator => 'Development calculator';

  @override
  String get developmentFormula => 'Development recipes';

  @override
  String get developmentOutputProbability => 'Development probability';

  @override
  String get developmentFinalProbability => 'Final probability';

  @override
  String get developmentAvailableRecipes => 'Available recipes';

  @override
  String get developmentPoolType => 'Pool type';

  @override
  String get developmentSelectSecretary => 'Select secretary ship type';

  @override
  String get developmentOtherSecretaryGroup => 'Other';

  @override
  String get developmentEquipmentType => 'Type';

  @override
  String get developmentSecretary => 'Secretary ship';

  @override
  String get developmentFuelShort => 'Fuel';

  @override
  String get developmentAmmoShort => 'Ammo';

  @override
  String get developmentSteelShort => 'Steel';

  @override
  String get developmentBauxiteShort => 'Baux';

  @override
  String get developmentOutputRate => 'Development rate';

  @override
  String get developmentEquipment => 'Equipment';

  @override
  String get developmentCurrentFlagship => 'Current flagship';

  @override
  String get developmentUseFlagship => 'Use current flagship';

  @override
  String get developmentFlagshipUnsupported =>
      'No development pool is available for this flagship. The previous selection was kept';

  @override
  String get developmentSelectPool => 'Secretary ship type';

  @override
  String get developmentCurrentRecipe => 'Current recipe';

  @override
  String get developmentTargetEquipment => 'Target equipment';

  @override
  String get developmentChooseTarget => 'Choose target equipment';

  @override
  String get developmentSearchEquipment => 'Search equipment';

  @override
  String get developmentSearchHint => 'Enter equipment name or ID';

  @override
  String get developmentAllTypes => 'All types';

  @override
  String get developmentTargetDrops => 'Target results';

  @override
  String get developmentOtherDrops => 'Other results';

  @override
  String get developmentInsufficient => 'Insufficient resources';

  @override
  String get developmentReplaced => 'Replaced results';

  @override
  String get developmentRecommendations => 'Recommended recipes';

  @override
  String get developmentNoTargets =>
      'Select target equipment to see recommended recipes';

  @override
  String get developmentNoResults =>
      'No recipe can develop all selected targets';

  @override
  String get developmentTargetRate => 'Target rate';

  @override
  String get developmentFailureRate => 'Failure rate';

  @override
  String get developmentTotalResources => 'Total resources';

  @override
  String get developmentApplyRecipe => 'Apply recipe';

  @override
  String get developmentDataError =>
      'Could not load equipment development data';

  @override
  String get developmentRetry => 'Retry';

  @override
  String developmentSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get developmentPoolBauxite => 'Bauxite pool';

  @override
  String get developmentPoolAmmunition => 'Ammo pool';

  @override
  String get developmentPoolFuelSteel => 'Fuel / steel pool';

  @override
  String get battlePredictionUnconfirmed =>
      'Data unconfirmed: HP and predictions are for reference only. Check the game screen.';

  @override
  String get mouseWheelCompatibility => 'External mouse wheel compatibility';

  @override
  String get mouseWheelCompatibilityDescription =>
      'Enable this if an external mouse wheel does not respond in the game. Takes effect immediately. Mouse clicks and touch remain available.';

  @override
  String get mouseWheelCompatibilitySaveFailed =>
      'Could not save the setting. Please try again.';

  @override
  String get hdMode => 'HD mode';

  @override
  String get hdModeDescription =>
      'Use a UI optimized for large screens (8 inches or larger recommended). Enabling this on a small screen may cause display errors, layout overflow, or app crashes.';

  @override
  String get hdBottomLayout => 'HD bottom layout';

  @override
  String get hdSplit => 'Two 1×1 panels';

  @override
  String get hdWide => 'One 1×2 panel';

  @override
  String get hdLeftModule => 'Left panel';

  @override
  String get hdRightModule => 'Right panel';

  @override
  String get hdWideModule => 'Full-width panel';

  @override
  String get hdCustomize => 'Customize layout';

  @override
  String get hdEditHint =>
      'Long-press a handle to reorder or move a panel to the bottom. Drop it on another panel to swap positions. Check to show, uncheck to hide.';

  @override
  String get hdHalfWidth => 'Half width 1×1';

  @override
  String get hdFullWidth => 'Full width 1×2';

  @override
  String get hdDropArea => 'Drop a panel here';

  @override
  String get workspaceMenuPosition => 'Menu position';

  @override
  String get workspaceMenuPositionDesc =>
      'Top places the menu directly below the game screen.';

  @override
  String get menuPositionTop => 'Top';

  @override
  String get menuPositionBottom => 'Bottom';

  @override
  String get menuPositionLeft => 'Left';

  @override
  String get menuPositionRight => 'Right';

  @override
  String get topNoticeSectionTitle => 'Top bar messages';

  @override
  String get topNoticeEnabledTitle => 'Top bar notifications';

  @override
  String get topNoticeEnabledSubtitle =>
      'Show development, improvement, pre-sortie check, and quest completion alerts to the right of 「ヤハギ」 in the top bar';

  @override
  String get topNoticeDurationTitle => 'Alert duration';

  @override
  String get topNoticeDurationSubtitle =>
      'Time before an alert bubble closes automatically when left untouched';

  @override
  String get topNoticeDuration5s => '5 seconds (default)';

  @override
  String get topNoticeDuration10s => '10 seconds';

  @override
  String get topNoticeDuration15s => '15 seconds';

  @override
  String questCompletionSingleNotice(String title) {
    return 'Quest completed: $title';
  }

  @override
  String questCompletionMultiNotice(int count) {
    return 'Quests completed: $count. Open the quest screen';
  }

  @override
  String questPendingConfirmationSingleNotice(String title) {
    return 'Quest goal met (awaiting game confirmation): $title';
  }

  @override
  String questPendingConfirmationMultiNotice(int count) {
    return 'Quest goals met: $count (awaiting game confirmation)';
  }

  @override
  String noticeDevSuccess(String name) {
    return 'Developed $name';
  }

  @override
  String get noticeDevFailed => 'Equipment development failed';

  @override
  String get noticeDevFailedPenguin => 'Equipment development failed';

  @override
  String get noticeDevSlotFailed => 'Development failed';

  @override
  String get noticeDevDefaultName => 'New equipment';

  @override
  String get noticeEquipImproveSuccess => 'Equipment improvement succeeded';

  @override
  String get noticeEquipImproveFailed => 'Equipment improvement failed';

  @override
  String get noticeModFailed => 'Modernization failed';

  @override
  String get noticeModSuccess => 'Modernization succeeded';

  @override
  String noticeModSuccessDetail(String stats) {
    return 'Modernization succeeded: $stats';
  }

  @override
  String get noticeModSuccessMaxCap =>
      'Modernization succeeded (stats already capped)';

  @override
  String get statFirepower => 'Firepower';

  @override
  String get statTorpedo => 'Torpedo';

  @override
  String get statAntiAir => 'Anti-air';

  @override
  String get statArmor => 'Armor';

  @override
  String get statLuck => 'Luck';

  @override
  String get statHp => 'HP';

  @override
  String get statAsw => 'Anti-sub';

  @override
  String noticeMarriageLuck(String arrow, int delta, int remaining) {
    return 'Marriage luck gain: Luck $arrow +$delta / +$remaining';
  }

  @override
  String noticeMarriageLuckMax(String arrow, int delta) {
    return 'Marriage luck gain: Luck $arrow +$delta / MAX';
  }

  @override
  String noticePracticeExp(int sExp, int aExp) {
    return 'Exercise EXP (approx.): S win $sExp · A win $aExp';
  }

  @override
  String noticePracticeExpCtBonus(int sExp, int aExp, String bonus) {
    return 'Exercise EXP (approx.): S win $sExp · A win $aExp (training cruiser +$bonus)';
  }

  @override
  String get noticeSortieShipFull =>
      'Ship capacity is full! You cannot obtain new ships on sortie';

  @override
  String noticeSortieShipLow(int count) {
    return 'Ship slots remaining: $count. Check home port capacity';
  }

  @override
  String get noticeSortieItemFull =>
      'Equipment capacity is full! You cannot obtain new equipment on sortie';

  @override
  String noticeSortieItemLow(int count) {
    return 'Equipment slots remaining: $count. Check home port capacity';
  }

  @override
  String get noticeSortieShipAndItemFull =>
      'Ship and equipment capacity are full! You cannot obtain new ships or equipment on sortie';

  @override
  String noticeSortieShipAndItemLow(int shipCount, int itemCount) {
    return 'Slots remaining: ships $shipCount · equipment $itemCount. Check home port capacity';
  }

  @override
  String get noticeSortieExpansionSlotUnused =>
      'The fleet has unused expansion slots';

  @override
  String noticePreSortieCheckFailed(String reasons) {
    return 'Pre-sortie checks failed: $reasons';
  }

  @override
  String get noticeSortieReasonUnresupplied => 'Resupply incomplete';

  @override
  String get noticeSortieReasonFatigue => 'Low ship morale (yellow/red faces)';

  @override
  String get noticeSortieReasonMainSlot => 'Normal equipment slots not filled';

  @override
  String get noticeSortieReasonExpansionSlot => 'Expansion slots unused';

  @override
  String get lockUi => 'Lock interface';

  @override
  String get unlockUi => 'Unlock interface';

  @override
  String get uiLockedToast =>
      'Interface locked. Layout editing is disabled; feature switching remains available';

  @override
  String get uiUnlockedToast => 'Interface unlocked';

  @override
  String get uiLockTitle => 'Lock interface layout';

  @override
  String get uiLockDesc =>
      'Disable long-press editing of cards and top bar resources, and drag-reordering of navigation. Feature pages can still be switched';

  @override
  String get filterVisibleItems => 'Filter visible items';

  @override
  String get selectHeaderVisibleItems => 'Select top bar items';

  @override
  String get expCalculator => 'Experience calculator';

  @override
  String get expCalcShip => 'Ship';

  @override
  String get expCalcCurrentLevel => 'Current level';

  @override
  String get expCalcTargetLevel => 'Target level';

  @override
  String get expCalcMap => 'Map';

  @override
  String get expCalcRank => 'Rating';

  @override
  String get expCalcBaseExp => 'Base EXP';

  @override
  String get expCalcFlagship => 'Flagship';

  @override
  String get expCalcMvp => 'MVP';

  @override
  String get expCalcMapExp => 'Map EXP';

  @override
  String get expCalcRemainExp => 'Remaining EXP';

  @override
  String get expCalcBattle => 'Battles';

  @override
  String get expCalcEmptyTrackList =>
      'No leveling plans. Tap ＋ above to add one';

  @override
  String get expCalcBaseExpHelpTitle => 'Base EXP reference for common maps';

  @override
  String get expCalcTrackAdded => 'Added to the EXP tracking list';

  @override
  String get expCalcTrackDeleted => 'Removed from the EXP tracking list';

  @override
  String get expCalcTrackLoadFailed =>
      'Could not load the tracking list. Tap to retry';

  @override
  String get expCalcTrackSaveFailed =>
      'Could not save the tracking list. Please try again';

  @override
  String get expCalcFreeMode => 'Custom calculation (no ship selected)';

  @override
  String get expCalcAddNode => 'Add battle node (cumulative battles)';

  @override
  String get expCalcRemoveNode => 'Remove node';

  @override
  String get expCalcRouteTotal => 'EXP per sortie';

  @override
  String get expCalcNodePoint => 'Node';

  @override
  String get expCalcRouteSummary => 'Sortie route';

  @override
  String get expCalcAddTrack => 'Add to live tracking';

  @override
  String get expCalcCompletedTag => '0 runs (complete)';

  @override
  String get expCalcCardView => 'Cards';

  @override
  String get expCalcTableView => 'Table';

  @override
  String get expCalcTrackListTitle => 'Leveling tracker';

  @override
  String get expCalcAutoSyncHint =>
      'Remaining EXP and runs update automatically when home port data changes';

  @override
  String get expCalcDelete => 'Delete';

  @override
  String get expCalcStep1Title => 'Step 1 · Ship and target level';

  @override
  String get expCalcStep2Title => 'Step 2 · Sortie nodes and route planning';

  @override
  String get expCalcResultHudTitle => 'Sortie route calculation results';

  @override
  String get expCalcTargetGapLabel => 'EXP needed to level up';

  @override
  String get expCalcTargetAlignHint =>
      'Target EXP is matched to the experience table automatically';

  @override
  String get expCalcRouteSummaryPrefix => 'Current route total';

  @override
  String get expCalcCombatNodesSuffix => 'battle nodes';

  @override
  String get expCalcAccumulatedExpLabel => 'Total EXP';

  @override
  String get customFontTitle => 'Interface font';

  @override
  String get customFontDescription =>
      'Import a font you like, then preview and apply it. Supports TTF and OTF, up to 32 MB.';

  @override
  String get customFontDefault => 'Default font (system font size)';

  @override
  String get customFontImport => 'Import font';

  @override
  String get customFontRestore => 'Restore default';

  @override
  String get customFontPreviewTitle => 'Font preview';

  @override
  String get customFontApply => 'Apply font';

  @override
  String get customFontPreviewSample =>
      'Fleet information · Sortie records · Screen settings';

  @override
  String get customFontPreviewNote =>
      'Applying this font changes the client interface and keeps your choice after restarting.';

  @override
  String get customFontImportFailed =>
      'Unable to import the font. Choose a valid TTF or OTF file.';

  @override
  String get customFontSaveFailed =>
      'Unable to save the font setting. Please try again.';

  @override
  String get customFontUnsupported =>
      'Font import is not supported on this platform yet.';

  @override
  String get customFontTooLarge => 'The font file must not exceed 32 MB.';

  @override
  String get customFontLoadLimit =>
      'The font switching limit for this session has been reached to keep memory usage bounded. Restart the app to apply another font. You can still preview fonts.';

  @override
  String get customFontPreviewFailed =>
      'Unable to generate the font preview. Please try again.';

  @override
  String get customFontPreviewRetry => 'Retry preview';

  @override
  String get browserMenuMute => 'Mute';

  @override
  String get browserMenuUnmute => 'Unmute';

  @override
  String get browserMenuScreenshot => 'Screenshot';

  @override
  String get browserMenuFit => 'Fix display';

  @override
  String get browserMenuFullscreen => 'Fullscreen';

  @override
  String get browserMenuHome => 'Home';

  @override
  String get browserMenuDismissHint => 'Tap outside to close';

  @override
  String summaryFleetHeavy(int count) {
    return 'Heavy $count';
  }

  @override
  String summaryFleetMedium(int count) {
    return 'Moderate $count';
  }

  @override
  String summaryFleetMinMorale(int value) {
    return 'Min morale $value';
  }

  @override
  String summaryExpedition(int active, String time) {
    return 'Active $active/3 · Next $time';
  }

  @override
  String summaryRepair(int busy, int total, String time) {
    return 'In use $busy/$total · Next $time';
  }

  @override
  String summaryRepairBusy(int busy, int total) {
    return 'In use $busy/$total';
  }

  @override
  String summaryConstruction(int done, int building) {
    return 'Done $done · Building $building';
  }

  @override
  String summaryQuests(int done, int active) {
    return 'Ready $done · Active $active';
  }

  @override
  String summaryLandBase(int sortie, int defense) {
    return 'Sortie $sortie · Air defense $defense';
  }

  @override
  String summaryWarnings(int count) {
    return 'Warnings $count';
  }

  @override
  String get questQueryTitle => 'Search and filter quests';

  @override
  String questQueryScope(String scope) {
    return 'Search scope: $scope';
  }

  @override
  String questApplyQuery(int count) {
    return 'Show $count quests';
  }

  @override
  String get questAccepted => 'Accepted';

  @override
  String get questConditionsAndProgress => 'Conditions and progress';

  @override
  String get questSelectTask => 'Select a quest to view completion conditions';

  @override
  String get questBackToList => 'Back to quest list';

  @override
  String get questReturnToTarget => 'Return to target quest';

  @override
  String get questNoPrerequisites =>
      'No direct prerequisite quests listed in the data';

  @override
  String get questNoSuccessors => 'No following quests listed in the data';

  @override
  String get japaneseOriginal => 'Japanese original';

  @override
  String questQueryActive(int count) {
    return '$count query conditions applied';
  }

  @override
  String get settingsTabRuntime => 'Game runtime';

  @override
  String get settingsGroupAppearance => 'Appearance';

  @override
  String get settingsGroupScreenAdaptation => 'Screen adaptation';

  @override
  String get settingsGroupLayoutPosition => 'Layout & position';

  @override
  String get settingsGroupContentCustomization => 'Content customization';

  @override
  String get settingsGroupLayoutManagement => 'Layout management';

  @override
  String get settingsOtherModuleDisplay => 'Other module content';

  @override
  String get settingsEditInformationLayout => 'Edit information panel layout';

  @override
  String get settingsEditHdLayout => 'Edit HD layout';

  @override
  String get settingsResetMenuOrder => 'Reset menu order';

  @override
  String get settingsResetCardOrder => 'Reset card order';

  @override
  String get settingsGroupPerformanceRendering => 'Performance & rendering';

  @override
  String get settingsGroupSubtitles => 'Subtitles';

  @override
  String get settingsGroupScreenBackground => 'Screen & background operation';

  @override
  String get settingsGroupInformationCapture => 'Game information capture';

  @override
  String get settingsFrameRefreshConfirm => 'Confirm before frame refresh';

  @override
  String get settingsFrameRefreshConfirmDescription =>
      'Show confirmation before refreshing the game frame from the header.';

  @override
  String get settingsFrameRefreshConfirmSaveFailed =>
      'Could not save frame refresh confirmation. Please try again.';

  @override
  String get settingsGroupDebuff => 'Gimmicks & armor debuff';

  @override
  String get settingsGroupShipStatusFeedback => 'Ship status feedback';

  @override
  String get settingsGroupSystemNotifications => 'System notifications';

  @override
  String get settingsEnableSystemNotifications => 'Enable system notifications';

  @override
  String get settingsSystemNotificationSound => 'System notification sound';

  @override
  String get settingsSystemNotificationVibration =>
      'System notification vibration';

  @override
  String get settingsGroupDataUpdates => 'Data updates';

  @override
  String get settingsGroupDataSharingPrivacy => 'Data sharing & privacy';

  @override
  String get settingsGroupClearLocalData => 'Clear local data';

  @override
  String get settingsGroupAccount => 'Account';

  @override
  String get settingsGroupDiagnosticsSupport => 'Diagnostics & support';

  @override
  String get settingsStatusEnabled => 'Enabled';

  @override
  String get settingsStatusDisabled => 'Disabled';

  @override
  String get settingsFleetDisplayStandard => 'Standard fleet card';

  @override
  String get settingsFleetDisplayHd => 'HD two-column fleet card';

  @override
  String get briefingDisplayTitle => 'Briefing display';

  @override
  String get briefingDisplayDescription =>
      'Accordion opens several modules at once. Tabs switch modules from the top. This setting has no effect in HD mode.';

  @override
  String get briefingDisplayAccordion => 'Accordion';

  @override
  String get briefingDisplayTabs => 'Tabs';

  @override
  String get briefingTabForecast => 'Forecast';

  @override
  String get briefingTabFleet => 'Fleet';

  @override
  String get briefingTabLandBase => 'Air Base';

  @override
  String get briefingTabExpedition => 'Exped.';

  @override
  String get briefingTabRepair => 'Repair';

  @override
  String get briefingTabConstruction => 'Build';

  @override
  String get briefingTabQuests => 'Quests';

  @override
  String get briefingTabPreSortie => 'Check';
}
