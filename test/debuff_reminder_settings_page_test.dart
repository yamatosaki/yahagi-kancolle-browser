import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/settings_organization_strings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'disabling system notifications leaves Battle debuff settings active',
    (tester) async {
      final controller = NotificationSettingsController(
        initialSettings: const NotificationSettings(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NotificationSettingsPage(
              controller: controller,
              notificationPort: _NotificationPortStub(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debuff-reminder-style-menu')), findsNothing);
      await tester.tap(find.byKey(const Key('notification-master-switch')));
      await tester.pumpAndSettle();
      expect(controller.settings.master, isFalse);
      await _pumpPage(tester, controller);

      expect(find.text('解谜与削甲'), findsOneWidget);
      expect(find.text('削甲提醒'), findsOneWidget);
      expect(find.text('确认弹窗（默认）'), findsOneWidget);
      expect(find.text('两种方式均附带震动；检测到解谜／削弱提示时提醒'), findsOneWidget);
      expect(
        find.byKey(const Key('debuff-reminder-style-menu')),
        findsOneWidget,
      );
      final menu = tester.widget<DropdownButton<DebuffReminderStyle>>(
        find.byKey(const Key('debuff-reminder-style-menu')),
      );
      expect(menu.onChanged, isNotNull);
      expect(menu.items, hasLength(2));
      expect(find.byType(Switch), findsNWidgets(2));
      final reminder = find.byKey(const Key('debuff-reminder-style-menu'));
      await tester.ensureVisible(reminder);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('顶部提醒').last);
      await tester.pumpAndSettle();
      expect(controller.settings.master, isFalse);
      expect(
        controller.settings.debuffReminderStyle,
        DebuffReminderStyle.topNotice,
      );
      const store = SharedPreferencesNotificationSettingsStore();
      expect(
        (await store.load()).debuffReminderStyle,
        DebuffReminderStyle.topNotice,
      );
    },
  );

  testWidgets('selecting either reminder style saves immediately', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(master: false),
    );
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);

    final menu = find.byKey(const Key('debuff-reminder-style-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('顶部提醒').last);
    await tester.pumpAndSettle();

    expect(
      controller.settings.debuffReminderStyle,
      DebuffReminderStyle.topNotice,
    );
    const store = SharedPreferencesNotificationSettingsStore();
    expect(
      (await store.load()).debuffReminderStyle,
      DebuffReminderStyle.topNotice,
    );

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认弹窗（默认）').last);
    await tester.pumpAndSettle();
    expect(
      (await store.load()).debuffReminderStyle,
      DebuffReminderStyle.dialog,
    );
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('reminder menu fits a 320px ${locale.languageCode} screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = NotificationSettingsController();
      addTearDown(controller.dispose);
      await _pumpPage(tester, controller, locale: locale);

      final l10n = lookupAppLocalizations(locale);
      expect(
        find.text(
          settingsOrganizationText(
            tester.element(find.byType(BattleSettingsPage)),
            'settingsGroupDebuff',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.debuffReminderSettingTitle), findsOneWidget);
      final menu = find.byKey(const Key('debuff-reminder-style-menu'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();

      expect(find.text(l10n.debuffReminderStyleTopNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.debuffReminderStyleTopNotice));
      await tester.pumpAndSettle();
      expect(
        controller.settings.debuffReminderStyle,
        DebuffReminderStyle.topNotice,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  NotificationSettingsController controller, {
  Locale locale = const Locale('zh'),
}) async {
  final safety = await SafetySettingsController.load(
    MemorySafetySettingsStore(),
  );
  addTearDown(safety.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BattleSettingsPage(
          safetySettingsController: safety,
          notificationSettingsController: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NotificationPortStub implements NotificationPort {
  @override
  Future<NotificationApplyResult> applySnapshot(
    NotificationSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async =>
      const NotificationPlatformCapabilities(
        notificationsGranted: true,
        exactAlarmsGranted: true,
        channelsEnabled: true,
      );

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<bool> requestNotificationPermission() async => true;
}
