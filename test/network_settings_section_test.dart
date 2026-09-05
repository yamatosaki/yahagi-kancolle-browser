import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.yahagi.kancollebrowser/network_proxy');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Widget app(
    NetworkSettingsController controller, {
    VoidCallback? onSuccess,
    Locale locale = const Locale('zh'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TopNoticeHost(
        child: Scaffold(
          body: NetworkSettingsSection(
            controller: controller,
            onApplySuccess: onSuccess ?? () {},
          ),
        ),
      ),
    );
  }

  Future<NetworkSettingsController> createController({
    NetworkSettings settings = const NetworkSettings(),
    Future<dynamic> Function(MethodCall call)? handler,
  }) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isProxyOverrideSupported') return true;
      if (call.method == 'getNetworkStatus') {
        return <String, dynamic>{'hasVpn': false, 'hasActiveNetwork': true};
      }
      return handler?.call(call);
    });
    final controller = NetworkSettingsController(store: _MemoryStore(settings));
    await controller.initialize();
    addTearDown(controller.dispose);
    return controller;
  }

  Finder noticeMatching(Finder matching) =>
      find.descendant(of: find.byKey(topNoticeKey), matching: matching);

  testWidgets('diagnostic result follows app locale and keeps raw errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var message = '网络畅通，可正常访问游戏服务。';
    final controller = await createController(
      handler: (_) async => {
        'success': true,
        'code': 'ok',
        'message': message,
        'elapsedMs': 10,
      },
    );
    await controller.testConnection(NetworkMode.system, '', 8080);
    await tester.pumpWidget(app(controller, locale: const Locale('ja')));
    await tester.pumpAndSettle();
    expect(find.text('ネットワークは正常で、ゲームサービスに接続できます。'), findsOneWidget);
    expect(find.text(message), findsNothing);
    await tester.pumpWidget(
      app(
        controller,
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('網路暢通，可正常存取遊戲服務。'), findsOneWidget);
    message = 'SocketException: 系统原始错误 127.0.0.1:8080';
    await controller.testConnection(NetworkMode.system, '', 8080);
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('network settings omit VPN status row', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('VPN 状态'), findsNothing);
    expect(find.textContaining('已检测到活动 VPN'), findsNothing);
    expect(find.textContaining('未检测到活动 VPN'), findsNothing);
  });

  testWidgets('validation failure shows an error notice', (tester) async {
    final controller = await createController(
      settings: const NetworkSettings(mode: NetworkMode.httpProxy, host: ''),
    );
    await tester.pumpWidget(app(controller));

    await tester.tap(find.textContaining('应用设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('地址不能为空')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.error_outline_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('apply shows a one-second neutral notice then success', (
    tester,
  ) async {
    final result = Completer<dynamic>();
    final controller = await createController(handler: (call) => result.future);
    var successCalls = 0;
    await tester.pumpWidget(app(controller, onSuccess: () => successCalls++));

    await tester.tap(find.textContaining('应用设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(noticeMatching(find.text('正在应用网络设置…')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.info_outline_rounded)),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byKey(topNoticeKey), findsNothing);

    result.complete(<String, dynamic>{
      'success': true,
      'code': 'ok',
      'message': 'done',
      'elapsedMs': 12,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('网络设置应用成功：done')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.check_circle_outline_rounded)),
      findsOneWidget,
    );
    expect(successCalls, 1);
  });

  testWidgets('apply failure shows an error notice', (tester) async {
    final controller = await createController(
      handler: (call) async => <String, dynamic>{
        'success': false,
        'code': 'denied',
        'message': 'blocked',
        'elapsedMs': 4,
      },
    );
    await tester.pumpWidget(app(controller));

    await tester.tap(find.textContaining('应用设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('设置失败 [denied]：blocked')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.error_outline_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('restore clears the proxy then shows a success notice', (
    tester,
  ) async {
    final calls = <String>[];
    final result = Completer<dynamic>();
    final controller = await createController(
      settings: const NetworkSettings(
        mode: NetworkMode.httpProxy,
        host: '127.0.0.1',
        port: 8080,
      ),
      handler: (call) {
        calls.add(call.method);
        return result.future;
      },
    );
    var successCalls = 0;
    await tester.pumpWidget(app(controller, onSuccess: () => successCalls++));

    await tester.tap(find.text('恢复系统网络'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(calls, ['clearProxyOverride']);
    expect(noticeMatching(find.text('正在清除应用内代理…')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.info_outline_rounded)),
      findsOneWidget,
    );

    result.complete(<String, dynamic>{
      'success': true,
      'code': 'ok',
      'message': 'cleared',
      'elapsedMs': 8,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(noticeMatching(find.text('正在清除应用内代理…')), findsNothing);
    expect(noticeMatching(find.text('已恢复系统网络。')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.check_circle_outline_rounded)),
      findsOneWidget,
    );
    expect(successCalls, 1);
  });

  testWidgets('restore failure shows an error notice', (tester) async {
    final calls = <String>[];
    final controller = await createController(
      settings: const NetworkSettings(
        mode: NetworkMode.socks5Proxy,
        host: '127.0.0.1',
        port: 1080,
      ),
      handler: (call) async {
        calls.add(call.method);
        return <String, dynamic>{
          'success': false,
          'code': 'denied',
          'message': 'blocked',
          'elapsedMs': 5,
        };
      },
    );
    await tester.pumpWidget(app(controller));

    await tester.tap(find.text('恢复系统网络'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(calls, ['clearProxyOverride']);
    expect(noticeMatching(find.text('正在清除应用内代理…')), findsNothing);
    expect(noticeMatching(find.text('恢复失败 [denied]：blocked')), findsOneWidget);
    expect(
      noticeMatching(find.byIcon(Icons.error_outline_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('代理地址和端口在同一独立弹窗中编辑', (tester) async {
    const channel = MethodChannel('app.yahagi.kancollebrowser/network_proxy');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'isProxyOverrideSupported' => true,
        'getNetworkStatus' => <String, dynamic>{
          'hasVpn': false,
          'hasActiveNetwork': true,
        },
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final controller = NetworkSettingsController(
      store: _MemoryStore(
        const NetworkSettings(
          mode: NetworkMode.httpProxy,
          host: '127.0.0.1',
          port: 8080,
        ),
      ),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: NetworkSettingsSection(
            controller: controller,
            onApplySuccess: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('network-proxy-input')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('network-proxy-input-dialog')), findsOneWidget);
    expect(find.byKey(const Key('network-proxy-host-field')), findsOneWidget);
    expect(find.byKey(const Key('network-proxy-port-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('network-proxy-host-field')),
      '192.168.1.8',
    );
    await tester.enterText(
      find.byKey(const Key('network-proxy-port-field')),
      '1080',
    );
    await tester.tap(find.byKey(const Key('network-proxy-input-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('192.168.1.8'), findsOneWidget);
    expect(find.text('1080'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('横屏键盘弹出后代理输入弹窗可滚动且不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    const channel = MethodChannel('app.yahagi.kancollebrowser/network_proxy');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'isProxyOverrideSupported' => true,
        'getNetworkStatus' => <String, dynamic>{
          'hasVpn': false,
          'hasActiveNetwork': true,
        },
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final controller = NetworkSettingsController(
      store: _MemoryStore(
        const NetworkSettings(
          mode: NetworkMode.httpProxy,
          host: '127.0.0.1',
          port: 8080,
        ),
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
            child: NetworkSettingsSection(
              controller: controller,
              onApplySuccess: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('network-proxy-input')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final confirm = find.byKey(const Key('network-proxy-input-confirm'));
    expect(confirm, findsOneWidget);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(160));
  });
}

final class _MemoryStore implements NetworkSettingsStore {
  _MemoryStore([this.settings = const NetworkSettings()]);

  NetworkSettings settings;

  @override
  Future<NetworkSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(NetworkSettings settings) async {
    this.settings = settings;
  }
}
