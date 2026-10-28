import 'package:flutter/foundation.dart';
import 'notification_settings_store.dart';

class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController({
    NotificationSettingsStore? store,
    NotificationSettings? initialSettings,
  }) : _store = store ?? const SharedPreferencesNotificationSettingsStore(),
       _settings = initialSettings ?? const NotificationSettings();

  final NotificationSettingsStore _store;
  NotificationSettings _settings;

  NotificationSettings get settings => _settings;

  Future<void> initialize() async {
    _settings = await _store.load();
    notifyListeners();
  }

  Future<void> _saveAndNotify(NotificationSettings next) async {
    if (_settings == next) return;
    _settings = next;
    notifyListeners();
    await _store.save(next);
  }

  Future<void> setMaster(bool value) =>
      _saveAndNotify(_settings.copyWith(master: value));

  Future<void> setSound(bool value) =>
      _saveAndNotify(_settings.copyWith(sound: value));

  Future<void> setVibration(bool value) =>
      _saveAndNotify(_settings.copyWith(vibration: value));

  Future<void> setOngoingLive(bool value) =>
      _saveAndNotify(_settings.copyWith(ongoingLive: value));

  Future<void> setShowProgress(bool value) =>
      _saveAndNotify(_settings.copyWith(showProgress: value));

  Future<void> setShowPercent(bool value) =>
      _saveAndNotify(_settings.copyWith(showPercent: value));

  Future<void> setShowCountdown(bool value) =>
      _saveAndNotify(_settings.copyWith(showCountdown: value));

  Future<void> setExpedition(bool value) =>
      _saveAndNotify(_settings.copyWith(expedition: value));

  Future<void> setExpeditionPreemptSeconds(int seconds) =>
      _saveAndNotify(_settings.copyWith(expeditionPreemptSeconds: seconds));

  Future<void> setRepair(bool value) =>
      _saveAndNotify(_settings.copyWith(repair: value));

  Future<void> setRepairPreemptSeconds(int seconds) =>
      _saveAndNotify(_settings.copyWith(repairPreemptSeconds: seconds));

  Future<void> setAnchorage(bool value) =>
      _saveAndNotify(_settings.copyWith(anchorage: value));

  Future<void> setAnchorageMode(AnchorageNotificationMode mode) =>
      _saveAndNotify(_settings.copyWith(anchorageMode: mode));

  Future<void> setConstruction(bool value) =>
      _saveAndNotify(_settings.copyWith(construction: value));

  Future<void> setConstructionPreemptSeconds(int seconds) =>
      _saveAndNotify(_settings.copyWith(constructionPreemptSeconds: seconds));

  Future<void> setMorale(bool value) =>
      _saveAndNotify(_settings.copyWith(morale: value));

  Future<void> setMoralePreemptSeconds(int seconds) =>
      _saveAndNotify(_settings.copyWith(moralePreemptSeconds: seconds));

  Future<void> setDebuffReminderStyle(DebuffReminderStyle style) =>
      _saveAndNotify(_settings.copyWith(debuffReminderStyle: style));

  Future<void> resetToDefaults() =>
      _saveAndNotify(const NotificationSettings());
}
