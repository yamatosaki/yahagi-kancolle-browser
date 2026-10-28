import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('debuff reminder defaults to the confirmation dialog', () {
    const settings = NotificationSettings();
    expect(settings.debuffReminderStyle, DebuffReminderStyle.dialog);
  });

  test('absent saved style falls back to the confirmation dialog', () async {
    const store = SharedPreferencesNotificationSettingsStore();
    expect(
      (await store.load()).debuffReminderStyle,
      DebuffReminderStyle.dialog,
    );
  });

  for (final style in DebuffReminderStyle.values) {
    test('loads saved ${style.name} style', () async {
      SharedPreferences.setMockInitialValues({_styleKey: style.storageValue});
      const store = SharedPreferencesNotificationSettingsStore();
      expect((await store.load()).debuffReminderStyle, style);
    });

    test('roundtrips ${style.name} alongside background settings', () async {
      const store = SharedPreferencesNotificationSettingsStore();
      final settings = NotificationSettings(
        master: false,
        vibration: false,
        expeditionPreemptSeconds: 30,
        debuffReminderStyle: style,
      );
      await store.save(settings);
      expect(await store.load(), settings);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_styleKey), style.storageValue);
    });
  }

  for (final invalid in <Object>['', 'unknown', 'disabled', 42, true]) {
    test('invalid saved style $invalid falls back to the dialog', () async {
      SharedPreferences.setMockInitialValues({_styleKey: invalid});
      const store = SharedPreferencesNotificationSettingsStore();
      expect(
        (await store.load()).debuffReminderStyle,
        DebuffReminderStyle.dialog,
      );
    });
  }

  test('copyWith and equality include the reminder style', () {
    const original = NotificationSettings(master: false, vibration: false);
    final updated = original.copyWith(
      debuffReminderStyle: DebuffReminderStyle.topNotice,
    );
    expect(updated.debuffReminderStyle, DebuffReminderStyle.topNotice);
    expect(updated.master, isFalse);
    expect(updated.vibration, isFalse);
    expect(updated, isNot(original));
    expect(updated.copyWith(), updated);
    expect(updated.copyWith().hashCode, updated.hashCode);
    expect(
      updated.copyWith(debuffReminderStyle: DebuffReminderStyle.dialog),
      original,
    );
  });

  test('controller notifies and saves style independently of master', () async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(
        master: false,
        vibration: false,
      ),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setDebuffReminderStyle(DebuffReminderStyle.topNotice);

    expect(notifications, 1);
    expect(
      controller.settings.debuffReminderStyle,
      DebuffReminderStyle.topNotice,
    );
    expect(controller.settings.master, isFalse);
    expect(controller.settings.vibration, isFalse);
    const store = SharedPreferencesNotificationSettingsStore();
    expect(await store.load(), controller.settings);

    await controller.setDebuffReminderStyle(DebuffReminderStyle.topNotice);
    expect(notifications, 1);

    await controller.resetToDefaults();
    expect(notifications, 2);
    expect(
      (await store.load()).debuffReminderStyle,
      DebuffReminderStyle.dialog,
    );
  });
}

const _styleKey = 'yahagi_notification_debuff_reminder_style';
