import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'dart:async';
import 'package:yahagi_kancolle_browser/src/browser/game_launch_config.dart';

void main() {
  test(
    'unattached controller does not navigate before WebView is ready',
    () async {
      final controller = GameBrowserController();

      await controller.enterDmmLoginTest();

      expect(controller.mode, GameBrowserMode.realWeb);
      expect(controller.errorMessage, 'WebView 尚未就绪');
    },
  );

  test(
    'starts locally and enters DMM only after an explicit command',
    () async {
      final port = FakeGameBrowserPort();
      final controller = GameBrowserController(port: port);

      expect(controller.mode, GameBrowserMode.realWeb);
      expect(port.loadedUris, isEmpty);

      await controller.enterDmmLoginTest();

      expect(controller.mode, GameBrowserMode.realWeb);
      expect(port.loadedUris.single, GameLaunchConfig.dmmGameEntry);
    },
  );

  test('back refresh and home commands are delegated to the port', () async {
    final port = FakeGameBrowserPort(canGoBackResult: true);
    final controller = GameBrowserController(port: port);

    await controller.enterDmmLoginTest();
    await controller.goBack();
    await controller.reload();
    await controller.goHome();

    expect(port.goBackCalls, 1);
    expect(port.reloadCalls, 1);
    expect(port.goBackCalls, 1);
    expect(port.reloadCalls, 1);
    expect(controller.mode, GameBrowserMode.realWeb);
  });

  test('back returns home when real page has no browser history', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(port: port);

    await controller.enterDmmLoginTest();
    await controller.goBack();

    expect(port.goBackCalls, 0);
    expect(port.goBackCalls, 0);
    expect(controller.mode, GameBrowserMode.realWeb);
  });

  test('page state stores only a sanitized address', () {
    final controller = GameBrowserController(port: FakeGameBrowserPort());

    controller.onPageStarted(
      'https://accounts.dmm.com/login?token=secret#callback',
    );

    expect(controller.displayAddress, 'https://accounts.dmm.com/login');
    expect(controller.displayAddress, isNot(contains('secret')));
    expect(controller.loadState, GamePageLoadState.loading);
  });

  test('subresource failures do not fail the main page', () {
    final controller = GameBrowserController(port: FakeGameBrowserPort());
    controller.onPageFinished('https://www.dmm.com/game');

    controller.onWebResourceError(
      description: 'image failed',
      isForMainFrame: false,
    );

    expect(controller.loadState, GamePageLoadState.ready);
    expect(controller.errorMessage, isNull);
  });

  test('blocked navigation reports only its scheme', () {
    final controller = GameBrowserController(port: FakeGameBrowserPort());

    controller.onBlockedNavigation(Uri.parse('intent://login?token=secret'));

    expect(controller.errorMessage, '暂不支持的外部跳转：intent');
    expect(controller.errorMessage, isNot(contains('secret')));
  });

  test('coalesces rapid reload taps into one in-flight request', () async {
    final port = FakeGameBrowserPort()..reloadCompleter = Completer<void>();
    final controller = GameBrowserController(port: port);

    final first = controller.reload();
    final second = controller.reload();
    await Future<void>.delayed(Duration.zero);

    expect(port.reloadCalls, 1);
    port.reloadCompleter!.complete();
    await Future.wait(<Future<void>>[first, second]);
  });

  test('logout clears the WebView session before loading DMM login', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(port: port);

    await controller.logoutAndClearSession();

    expect(port.clearSessionCalls, 1);
    expect(port.loadedUris, <Uri>[GameLaunchConfig.dmmGameEntry]);
  });
}

final class FakeGameBrowserPort implements GameBrowserPort {
  FakeGameBrowserPort({this.canGoBackResult = false});

  final bool canGoBackResult;
  final List<Uri> loadedUris = [];
  var showLocalHomeCalls = 0;
  var reloadCalls = 0;
  var goBackCalls = 0;
  var clearSessionCalls = 0;
  Completer<void>? reloadCompleter;

  @override
  Future<bool> canGoBack() async => canGoBackResult;

  @override
  Future<void> goBack() async {
    goBackCalls++;
  }

  @override
  Future<void> loadUri(Uri uri) async {
    loadedUris.add(uri);
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
    await reloadCompleter?.future;
  }

  @override
  Future<void> showLocalHome() async {
    showLocalHomeCalls++;
  }

  String? lastRunJavaScript;

  @override
  Future<void> runJavaScript(String javascript) async {
    lastRunJavaScript = javascript;
  }

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {
    clearSessionCalls++;
  }
}
