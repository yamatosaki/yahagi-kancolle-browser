import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/notification/method_channel_notification_port.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';

const _ready = NotificationPlatformCapabilities(
  notificationsGranted: true,
  exactAlarmsGranted: true,
  channelsEnabled: true,
);

const _missingPermission = NotificationPlatformCapabilities(
  notificationsGranted: false,
  exactAlarmsGranted: true,
  channelsEnabled: true,
);

const _indicatorKey = Key('notification-system-status-indicator');

class _CapabilityPort implements NotificationPort {
  _CapabilityPort(this.capabilities);

  Future<NotificationPlatformCapabilities> capabilities;

  @override
  Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot) {
    throw UnimplementedError();
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() => capabilities;

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<bool> requestNotificationPermission() async {
    capabilities = Future.value(_ready);
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const states = {
    'all capabilities available': _ready,
    'notification permission missing': _missingPermission,
    'exact alarm permission missing': NotificationPlatformCapabilities(
      notificationsGranted: true,
      exactAlarmsGranted: false,
      channelsEnabled: true,
    ),
    'notification channels disabled': NotificationPlatformCapabilities(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      channelsEnabled: false,
    ),
  };
  for (final MapEntry(key: label, value: capabilities) in states.entries) {
    testWidgets('shows aggregate status with $label', (tester) async {
      await _pumpPage(tester, _CapabilityPort(Future.value(capabilities)));
      await tester.pumpAndSettle();

      _expectIndicator(tester, ready: capabilities == _ready);
      expect(
        find.text(capabilities.notificationsGranted ? '通知权限已授予' : '通知权限未授予'),
        findsOneWidget,
      );
      expect(
        find.text(
          capabilities.exactAlarmsGranted ? '精确提醒已授权' : '精确提醒未授权，将使用省电兼容模式',
        ),
        findsOneWidget,
      );
      expect(
        find.text(capabilities.channelsEnabled ? '通知渠道可用' : '通知渠道已被系统关闭'),
        findsOneWidget,
      );
    });
  }

  testWidgets('waits for capabilities and updates when permission is granted', (
    tester,
  ) async {
    final initial = Completer<NotificationPlatformCapabilities>();
    await _pumpPage(tester, _CapabilityPort(initial.future));

    expect(find.byKey(_indicatorKey), findsNothing);
    initial.complete(_missingPermission);
    await tester.pumpAndSettle();
    _expectIndicator(tester, ready: false);

    final permissionRow = find.text('通知权限未授予');
    await tester.ensureVisible(permissionRow);
    await tester.tap(permissionRow);
    await tester.pumpAndSettle();
    _expectIndicator(tester, ready: true);
    expect(find.text('通知权限已授予'), findsOneWidget);
  });

  testWidgets(
    'status rows invoke platform actions and refresh after settings',
    (tester) async {
      const channel = MethodChannel('app.yahagi.kancollebrowser/notification');
      final messenger = tester.binding.defaultBinaryMessenger;
      final actions = <String>[];
      final capabilities = {
        'notificationsGranted': false,
        'exactAlarmsGranted': false,
        'channelsEnabled': false,
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getCapabilities':
            return capabilities;
          case 'requestNotificationPermission':
            actions.add(call.method);
            capabilities['notificationsGranted'] = true;
            return true;
          case 'requestExactAlarmPermission':
          case 'openSystemNotificationSettings':
            actions.add(call.method);
            return null;
          default:
            fail('Unexpected notification method: ${call.method}');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(() {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      Future<void> tapRow(String label) async {
        final row = find.text(label);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      Future<void> enableInSettings(String capability) async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        capabilities[capability] = true;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      }

      await _pumpPage(tester, const MethodChannelNotificationPort());
      await tester.pumpAndSettle();
      _expectIndicator(tester, ready: false);

      await tapRow('通知权限未授予');
      expect(actions, ['requestNotificationPermission']);
      expect(find.text('通知权限已授予'), findsOneWidget);
      _expectIndicator(tester, ready: false);

      await tapRow('精确提醒未授权，将使用省电兼容模式');
      expect(actions.last, 'requestExactAlarmPermission');
      expect(find.text('精确提醒已授权'), findsNothing);
      await enableInSettings('exactAlarmsGranted');
      expect(find.text('精确提醒已授权'), findsOneWidget);
      _expectIndicator(tester, ready: false);

      await tapRow('通知渠道已被系统关闭');
      expect(actions.last, 'openSystemNotificationSettings');
      expect(find.text('通知渠道可用'), findsNothing);
      await enableInSettings('channelsEnabled');
      expect(find.text('通知渠道可用'), findsOneWidget);
      _expectIndicator(tester, ready: true);
      expect(actions, [
        'requestNotificationPermission',
        'requestExactAlarmPermission',
        'openSystemNotificationSettings',
      ]);
    },
  );
}

Future<void> _pumpPage(WidgetTester tester, NotificationPort port) async {
  final controller = NotificationSettingsController();
  addTearDown(controller.dispose);
  await controller.initialize();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotificationSettingsPage(
        controller: controller,
        notificationPort: port,
      ),
    ),
  );
}

void _expectIndicator(WidgetTester tester, {required bool ready}) {
  final finder = find.byKey(_indicatorKey);
  expect(finder, findsOneWidget);
  final icon = tester.widget<Icon>(finder);
  final context = tester.element(finder);
  expect(icon.icon, ready ? Icons.check : Icons.close);
  expect(
    icon.color,
    ready
        ? AppPalette.of(context).success
        : appColor(context, const Color(0xffff6f68)),
  );
  expect(
    tester.getTopLeft(finder).dx,
    greaterThan(tester.getTopLeft(find.text('系统通知状态')).dx),
  );
}
