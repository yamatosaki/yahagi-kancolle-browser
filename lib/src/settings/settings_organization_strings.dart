import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';

/// Adapts section identifiers to the app's generated five-locale resources.
String settingsOrganizationText(BuildContext context, String key) {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  return switch (key) {
    'settingsTabRuntime' => l10n.settingsTabRuntime,
    'settingsGroupAppearance' => l10n.settingsGroupAppearance,
    'settingsGroupScreenAdaptation' => l10n.settingsGroupScreenAdaptation,
    'settingsGroupLayoutPosition' => l10n.settingsGroupLayoutPosition,
    'settingsGroupContentCustomization' =>
      l10n.settingsGroupContentCustomization,
    'settingsGroupLayoutManagement' => l10n.settingsGroupLayoutManagement,
    'settingsOtherModuleDisplay' => l10n.settingsOtherModuleDisplay,
    'settingsEditInformationLayout' => l10n.settingsEditInformationLayout,
    'settingsEditHdLayout' => l10n.settingsEditHdLayout,
    'settingsResetMenuOrder' => l10n.settingsResetMenuOrder,
    'settingsResetCardOrder' => l10n.settingsResetCardOrder,
    'settingsGroupPerformanceRendering' =>
      l10n.settingsGroupPerformanceRendering,
    'settingsGroupSubtitles' => l10n.settingsGroupSubtitles,
    'settingsGroupScreenBackground' => l10n.settingsGroupScreenBackground,
    'settingsGroupInformationCapture' => l10n.settingsGroupInformationCapture,
    'settingsFrameRefreshConfirm' => l10n.settingsFrameRefreshConfirm,
    'settingsFrameRefreshConfirmDescription' =>
      l10n.settingsFrameRefreshConfirmDescription,
    'settingsFrameRefreshConfirmSaveFailed' =>
      l10n.settingsFrameRefreshConfirmSaveFailed,
    'settingsGroupDebuff' => l10n.settingsGroupDebuff,
    'settingsGroupShipStatusFeedback' => l10n.settingsGroupShipStatusFeedback,
    'settingsGroupSystemNotifications' => l10n.settingsGroupSystemNotifications,
    'settingsEnableSystemNotifications' =>
      l10n.settingsEnableSystemNotifications,
    'settingsSystemNotificationSound' => l10n.settingsSystemNotificationSound,
    'settingsSystemNotificationVibration' =>
      l10n.settingsSystemNotificationVibration,
    'settingsGroupDataUpdates' => l10n.settingsGroupDataUpdates,
    'settingsGroupDataSharingPrivacy' => l10n.settingsGroupDataSharingPrivacy,
    'settingsGroupClearLocalData' => l10n.settingsGroupClearLocalData,
    'settingsGroupAccount' => l10n.settingsGroupAccount,
    'settingsGroupDiagnosticsSupport' => l10n.settingsGroupDiagnosticsSupport,
    'settingsStatusEnabled' => l10n.settingsStatusEnabled,
    'settingsStatusDisabled' => l10n.settingsStatusDisabled,
    'settingsFleetDisplayStandard' => l10n.settingsFleetDisplayStandard,
    'settingsFleetDisplayHd' => l10n.settingsFleetDisplayHd,
    _ => throw ArgumentError.value(key, 'key', 'Unknown settings label'),
  };
}
