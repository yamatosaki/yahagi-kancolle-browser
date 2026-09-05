import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

class _NotificationPortStub implements NotificationPort {
  @override
  Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot) {
    throw UnimplementedError();
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async {
    return const NotificationPlatformCapabilities(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      channelsEnabled: true,
    );
  }

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<bool> requestNotificationPermission() async => true;
}

void main() {
  testWidgets('master switch disables every dependent notification control', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(master: false),
    );
    await _pumpPage(tester, controller);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(9));
    expect(switches.first.onChanged, isNotNull);
    for (final dependentSwitch in switches.skip(1)) {
      expect(dependentSwitch.onChanged, isNull);
    }

    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(checkbox.onChanged, isNull);
    }
    final menus = find.byWidgetPredicate((widget) => widget is DropdownButton);
    expect(menus, findsNWidgets(5));
    for (final element in menus.evaluate()) {
      final menu = element.widget as dynamic;
      expect(menu.onChanged, isNull);
    }
  });

  testWidgets('notification type choices use aligned menus before switches', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(),
    );
    await _pumpPage(tester, controller);

    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(
      find.byType(SegmentedButton<AnchorageNotificationMode>),
      findsNothing,
    );

    const menuKeys = <Key>[
      Key('notification-expedition-menu'),
      Key('notification-repair-menu'),
      Key('notification-anchorage-menu'),
      Key('notification-construction-menu'),
      Key('notification-morale-menu'),
    ];
    const switchKeys = <Key>[
      Key('notification-expedition-switch'),
      Key('notification-repair-switch'),
      Key('notification-anchorage-switch'),
      Key('notification-construction-switch'),
      Key('notification-morale-switch'),
    ];
    for (var index = 0; index < menuKeys.length; index++) {
      final menu = find.byKey(menuKeys[index]);
      final toggle = find.byKey(switchKeys[index]);
      expect(menu, findsOneWidget);
      expect(toggle, findsOneWidget);
      expect(
        tester.getTopLeft(menu).dx,
        lessThan(tester.getTopLeft(toggle).dx),
      );
      expect(
        tester.getCenter(menu).dy,
        closeTo(tester.getCenter(toggle).dy, 1),
      );
    }

    final menuWidths = menuKeys
        .map((key) => tester.getSize(find.byKey(key)).width)
        .toSet();
    expect(menuWidths, hasLength(1));
  });

  testWidgets(
    'capability items and general settings titles share the same left alignment',
    (tester) async {
      final controller = NotificationSettingsController(
        initialSettings: const NotificationSettings(),
      );
      await _pumpPage(tester, controller);

      final titleFinders = <Finder>[
        find.text('通知权限已授予'),
        find.text('精确提醒已授权'),
        find.text('通知渠道可用'),
        find.text('启用通知服务'),
        find.text('通知提示音'),
        find.text('振动提醒'),
        find.text('常驻实时进度条卡片'),
        find.text('远征'),
        find.text('入渠'),
        find.text('泊地'),
        find.text('建造'),
        find.text('疲劳 / 刷闪'),
      ];

      for (final finder in titleFinders) {
        expect(finder, findsOneWidget);
      }

      final titleDx = <double>[
        for (final finder in titleFinders) tester.getTopLeft(finder).dx,
      ];
      expect(titleDx.toSet(), hasLength(1));
      expect(titleDx.first, 32.0);
    },
  );

  testWidgets('expedition menu updates the selected preempt time', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(),
    );
    await _pumpPage(tester, controller);

    final menu = find.byKey(const Key('notification-expedition-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提前 30 秒').last);
    await tester.pumpAndSettle();

    expect(controller.settings.expeditionPreemptSeconds, 30);
  });

  testWidgets('construction and morale menus update preempt time', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(),
    );
    await _pumpPage(tester, controller);

    final constrMenu = find.byKey(const Key('notification-construction-menu'));
    await tester.ensureVisible(constrMenu);
    await tester.tap(constrMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提前 60 秒').last);
    await tester.pumpAndSettle();

    expect(controller.settings.constructionPreemptSeconds, 60);

    final moraleMenu = find.byKey(const Key('notification-morale-menu'));
    await tester.ensureVisible(moraleMenu);
    await tester.tap(moraleMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提前 30 秒').last);
    await tester.pumpAndSettle();

    expect(controller.settings.moralePreemptSeconds, 30);
  });

  test(
    'notification setting labels contain no English annotations or units',
    () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final zhHant = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      final ja = lookupAppLocalizations(const Locale('ja'));

      expect(zh.notificationSectionOngoing, '后台常驻进行中进度');
      expect(zh.notificationSectionTypes, '通知类型与时机');
      expect(zh.notificationExpedition, '远征');
      expect(zh.notificationRepair, '入渠');
      expect(zh.notificationAnchorage, '泊地');
      expect(zh.notificationConstruction, '建造');
      expect(zh.notificationMorale, '疲劳 / 刷闪');
      expect(zh.notificationPunctual, '准点');
      expect(zh.notificationPreempt30s, '提前 30 秒');
      expect(zh.notificationPreempt60s, '提前 60 秒');
      expect(zh.notificationPreempt120s, '提前 2 分钟');
      expect(zh.notificationRepairPunctual, '准点');
      expect(zh.notificationAnchorage20m, '满 20 分钟首轮');

      expect(zhHant.notificationSectionOngoing, '背景常駐進行中進度');
      expect(zhHant.notificationSectionTypes, '通知類型與時機');
      expect(zhHant.notificationPreempt60s, '提前 60 秒');
      expect(zhHant.notificationPreempt120s, '提前 2 分鐘');
      expect(zhHant.notificationAnchorage20m, '滿 20 分鐘首輪');

      expect(ja.notificationSectionOngoing, 'バックグラウンドで進行状況を常時表示');
      expect(ja.notificationSectionTypes, '通知種別とタイミング');
      expect(ja.notificationExpedition, '遠征');
      expect(ja.notificationRepair, '入渠');
      expect(ja.notificationAnchorage, '泊地');
      expect(ja.notificationConstruction, '建造');
      expect(ja.notificationMorale, '疲労 / キラ付け');
      expect(ja.notificationPunctual, '定刻');
      expect(ja.notificationRepairPunctual, '定刻');
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  NotificationSettingsController controller,
) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotificationSettingsPage(
        controller: controller,
        notificationPort: _NotificationPortStub(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
