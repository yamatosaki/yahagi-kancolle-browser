import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'dart:async';
import 'package:yahagi_kancolle_browser/src/browser/game_launch_config.dart';
import 'package:yahagi_kancolle_browser/src/browser/origin_cookie_manager_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector.dart';

void main() {
  test('logout invalidates account before delayed browser cleanup', () async {
    final port = FakeGameBrowserPort()
      ..clearSessionCompleter = Completer<void>();
    var resets = 0;
    final controller = GameBrowserController(
      port: port,
      onSessionReset: () => resets++,
    );
    final loggingOut = controller.logoutAndClearSession();
    expect(resets, 1);
    expect(port.loadedUris, isEmpty);
    port.clearSessionCompleter!.complete();
    await loggingOut;
    expect(port.loadedUris, hasLength(1));
    await controller.switchHome(GameConnector.yahagi.entryUri);
    expect(resets, 2);
    controller.dispose();
  });

  test(
    'navigation waits for capture reset and ignores an obsolete switch',
    () async {
      final port = FakeGameBrowserPort();
      final resets = <Completer<void>>[];
      final controller = GameBrowserController(
        port: port,
        onSessionReset: () {
          final pending = Completer<void>();
          resets.add(pending);
          return pending.future;
        },
      );
      final first = controller.switchHome(GameConnector.ooi.entryUri);
      final second = controller.switchHome(GameConnector.yahagi.entryUri);
      expect(port.loadedUris, isEmpty);
      resets[1].complete();
      await second;
      resets[0].complete();
      await first;
      expect(port.loadedUris, [GameConnector.yahagi.entryUri]);
      controller.dispose();
    },
  );
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

  test('switchHome navigates immediately and home uses the target', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(
      homeUri: GameConnector.yahagi.entryUri,
      port: port,
      originCookieManagerPort: port,
    );

    await controller.switchHome(GameConnector.ooi.entryUri);
    await controller.goHome();

    expect(controller.homeUri, GameConnector.ooi.entryUri);
    expect(port.loadedUris, <Uri>[
      GameConnector.ooi.entryUri,
      GameConnector.ooi.entryUri,
    ]);
  });

  test('cold OOI entry clears only once per app process', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(
      homeUri: GameConnector.ooi.entryUri,
      port: port,
      originCookieManagerPort: port,
    );

    await controller.prepareInitialHome();
    await controller.prepareInitialHome();

    expect(port.clearedCookieOrigins, <Uri>[GameConnector.ooi.entryOrigin]);
    expect(port.operations, <String>['clear:https://ooi.moe']);
  });

  test('cold Yahagi entry preserves every cookie', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(
      homeUri: GameConnector.yahagi.entryUri,
      port: port,
      originCookieManagerPort: port,
    );

    await controller.prepareInitialHome();

    expect(port.clearedCookieOrigins, isEmpty);
  });

  test('each switch into OOI clears before navigation', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(
      homeUri: GameConnector.yahagi.entryUri,
      port: port,
      originCookieManagerPort: port,
    );

    await controller.switchHome(GameConnector.ooi.entryUri);
    await controller.switchHome(GameConnector.yahagi.entryUri);
    await controller.switchHome(GameConnector.ooi.entryUri);

    expect(port.operations, <String>[
      'clear:https://ooi.moe',
      'load:https://ooi.moe/',
      'load:${GameConnector.yahagi.entryUri}',
      'clear:https://ooi.moe',
      'load:https://ooi.moe/',
    ]);
  });

  test('OOI refresh and home navigation preserve the active session', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(
      homeUri: GameConnector.ooi.entryUri,
      port: port,
      originCookieManagerPort: port,
    );
    await controller.prepareInitialHome();
    port.operations.clear();
    port.clearedCookieOrigins.clear();

    await controller.reload();
    await controller.goHome();

    expect(port.clearedCookieOrigins, isEmpty);
    expect(port.operations, <String>['reload', 'load:https://ooi.moe/']);
  });

  test(
    'failed OOI cookie clearing never navigates with the old session',
    () async {
      final port = FakeGameBrowserPort()
        ..clearCookiesError = StateError('fail');
      final controller = GameBrowserController(
        homeUri: GameConnector.yahagi.entryUri,
        port: port,
        originCookieManagerPort: port,
      );

      await expectLater(
        controller.switchHome(GameConnector.ooi.entryUri),
        throwsStateError,
      );

      expect(port.loadedUris, isEmpty);
    },
  );

  test('logout returns to the selected connector home', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(
      homeUri: GameConnector.ooi.entryUri,
      port: port,
    );

    await controller.logoutAndClearSession();

    expect(port.clearSessionCalls, 1);
    expect(port.loadedUris, <Uri>[GameConnector.ooi.entryUri]);
  });

  test('detects only official game pages as active games', () {
    final controller = GameBrowserController();
    expect(controller.isOfficialGamePage, isFalse);

    controller.onPageFinished(
      'https://w17k.kancolle-server.com/kcs2/index.html?token=secret',
    );
    expect(controller.isOfficialGamePage, isTrue);

    controller.onPageFinished('https://ooi.moe/');
    expect(controller.isOfficialGamePage, isFalse);
  });

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

  test(
    'reload game frame delegates without refreshing the full page',
    () async {
      final port = FakeGameBrowserPort();
      final controller = GameBrowserController(port: port);

      final result = await controller.reloadGameFrame();

      expect(result, GameFrameReloadResult.reloaded);
      expect(port.reloadGameFrameCalls, 1);
      expect(port.reloadCalls, 0);
    },
  );

  test('coalesces rapid game frame reload taps', () async {
    final port = FakeGameBrowserPort()
      ..reloadGameFrameCompleter = Completer<GameFrameReloadResult>();
    final controller = GameBrowserController(port: port);

    final first = controller.reloadGameFrame();
    final second = controller.reloadGameFrame();
    await Future<void>.delayed(Duration.zero);

    expect(port.reloadGameFrameCalls, 1);
    port.reloadGameFrameCompleter!.complete(GameFrameReloadResult.reloaded);
    expect(
      await Future.wait(<Future<GameFrameReloadResult>>[first, second]),
      everyElement(GameFrameReloadResult.reloaded),
    );
  });

  test('a replacement port can reload its game frame immediately', () async {
    final first = FakeGameBrowserPort()
      ..reloadGameFrameCompleter = Completer<GameFrameReloadResult>();
    final second = FakeGameBrowserPort();
    final controller = GameBrowserController(port: first);

    final oldReload = controller.reloadGameFrame();
    await Future<void>.delayed(Duration.zero);
    controller.attachPort(second);
    final replacementReload = controller.reloadGameFrame();

    expect(await replacementReload, GameFrameReloadResult.reloaded);
    expect(second.reloadGameFrameCalls, 1);
    first.reloadGameFrameCompleter!.complete(GameFrameReloadResult.reloaded);
    expect(await oldReload, GameFrameReloadResult.reloaded);
  });

  test('logout clears the WebView session before loading DMM login', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(port: port);

    await controller.logoutAndClearSession();

    expect(port.clearSessionCalls, 1);
    expect(port.loadedUris, <Uri>[GameLaunchConfig.dmmGameEntry]);
  });

  test('fit screen delegates a full presentation resynchronization', () async {
    final port = FakeGameBrowserPort();
    final controller = GameBrowserController(port: port);

    await controller.fitGameScreen();

    expect(port.fitGameScreenCalls, 1);
  });

  test(
    'detaches ports by identity without disconnecting a replacement',
    () async {
      final first = FakeGameBrowserPort();
      final second = FakeGameBrowserPort();
      final controller = GameBrowserController(port: first);
      controller.attachPort(second);

      controller.detachPort(first);
      await controller.reload();

      expect(second.reloadCalls, 1);
      controller.detachPort(second);
      await controller.reload();
      expect(controller.errorMessage, 'WebView 尚未就绪');
      expect(second.reloadCalls, 1);
    },
  );

  test(
    'reloading a replacement port does not await an old port request',
    () async {
      final first = FakeGameBrowserPort()..reloadCompleter = Completer<void>();
      final second = FakeGameBrowserPort();
      final controller = GameBrowserController(port: first);

      final oldReload = controller.reload();
      await Future<void>.delayed(Duration.zero);
      controller.attachPort(second);
      controller.detachPort(first);
      final replacementReload = controller.reload();
      await Future<void>.delayed(Duration.zero);

      expect(second.reloadCalls, 1);
      first.reloadCompleter!.complete();
      await Future.wait(<Future<void>>[oldReload, replacementReload]);
    },
  );

  test('attaching the same port keeps an in-flight reload coalesced', () async {
    final port = FakeGameBrowserPort()..reloadCompleter = Completer<void>();
    final controller = GameBrowserController(port: port);

    final first = controller.reload();
    await Future<void>.delayed(Duration.zero);
    controller.attachPort(port);
    final second = controller.reload();
    await Future<void>.delayed(Duration.zero);

    expect(port.reloadCalls, 1);
    port.reloadCompleter!.complete();
    await Future.wait(<Future<void>>[first, second]);
  });
}

final class FakeGameBrowserPort
    implements GameBrowserPort, OriginCookieManagerPort {
  FakeGameBrowserPort({this.canGoBackResult = false});

  final bool canGoBackResult;
  final List<Uri> loadedUris = [];
  final List<Uri> clearedCookieOrigins = [];
  final List<String> operations = [];
  Object? clearCookiesError;
  var showLocalHomeCalls = 0;
  var reloadCalls = 0;
  var reloadGameFrameCalls = 0;
  var goBackCalls = 0;
  var clearSessionCalls = 0;
  var fitGameScreenCalls = 0;
  Completer<void>? reloadCompleter;
  Completer<void>? clearSessionCompleter;
  Completer<GameFrameReloadResult>? reloadGameFrameCompleter;

  @override
  Future<bool> canGoBack() async => canGoBackResult;

  @override
  Future<void> goBack() async {
    goBackCalls++;
  }

  @override
  Future<void> loadUri(Uri uri) async {
    loadedUris.add(uri);
    operations.add('load:$uri');
  }

  @override
  Future<void> clearCookiesForOrigin(Uri origin) async {
    operations.add('clear:$origin');
    clearedCookieOrigins.add(origin);
    final error = clearCookiesError;
    if (error != null) throw error;
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
    operations.add('reload');
    await reloadCompleter?.future;
  }

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async {
    reloadGameFrameCalls++;
    return await reloadGameFrameCompleter?.future ??
        GameFrameReloadResult.reloaded;
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
  Future<void> fitGameScreen() async {
    fitGameScreenCalls++;
  }

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {
    clearSessionCalls++;
    await clearSessionCompleter?.future;
  }
}
