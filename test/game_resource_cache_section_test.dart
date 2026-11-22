import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_resource_cache_section.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  Widget app(GameResourceCacheController controller) => MaterialApp(
    home: TopNoticeHost(
      child: Scaffold(body: GameResourceCacheSection(controller: controller)),
    ),
  );

  testWidgets('shows two modes and labels the cached size', (tester) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));

    expect(find.byKey(const Key('cache-mode-temporary')), findsOneWidget);
    expect(find.byKey(const Key('cache-mode-light')), findsNothing);
    expect(find.byKey(const Key('cache-mode-full')), findsOneWidget);
    expect(find.text('本地缓存'), findsOneWidget);
    expect(find.textContaining('预下载基础资源（约 5.72 GB）'), findsOneWidget);
    expect(find.textContaining('游玩时自动缓存'), findsOneWidget);
    expect(find.text('已缓存 6.84 GB'), findsOneWidget);
    expect(find.textContaining('/ 8.12 GB'), findsNothing);
    expect(find.textContaining('1,284'), findsNothing);

    final textCenterY = tester
        .getCenter(find.byKey(const Key('cache-completeness-line')))
        .dy;
    final buttonCenterY = tester
        .getCenter(find.byKey(const Key('cache-check-integrity')))
        .dy;
    expect((textCenterY - buttonCenterY).abs(), lessThan(4.0));

    final noneLeft = tester.getTopLeft(find.text('临时缓存')).dx;
    final fullLeft = tester.getTopLeft(find.text('本地缓存')).dx;
    final completenessLeft = tester
        .getTopLeft(find.byKey(const Key('cache-completeness-line')))
        .dx;
    expect(fullLeft, noneLeft);
    expect(completenessLeft, noneLeft);
  });

  testWidgets('temporary mode explains its limits and hides preload actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.temporary),
      port: _FakePort(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));

    expect(find.text('临时缓存'), findsOneWidget);
    expect(find.textContaining('最多保留 7 天'), findsOneWidget);
    expect(find.textContaining('不超过 2 GB'), findsOneWidget);
    expect(find.byKey(const Key('cache-download-toggle')), findsNothing);
    expect(find.byKey(const Key('cache-check-integrity')), findsNothing);
    expect(find.byKey(const Key('cache-repair')), findsNothing);
    final localClear = find.byKey(const Key('cache-clear'));
    final kanxyClear = find.byKey(const Key('kanxy-cache-clear'));
    expect(tester.getCenter(localClear).dy, tester.getCenter(kanxyClear).dy);
    expect(
      tester.getRect(localClear).right,
      lessThan(tester.getRect(kanxyClear).left),
    );
    expect(tester.widget(localClear), isA<OutlinedButton>());
    expect(tester.widget(kanxyClear), isA<OutlinedButton>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable cache shows warning and disables mode controls', (
    tester,
  ) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.temporary),
      port: port,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));

    expect(find.textContaining('本地缓存初始化或清理失败'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    await tester.tap(find.byKey(const Key('cache-mode-full')));
    await tester.pump();
    expect(port.mode, GameResourceCacheMode.light);
  });

  testWidgets('integrity check distinguishes retained pending resources', (
    tester,
  ) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));
    await tester.tap(find.byKey(const Key('cache-check-integrity')));
    await tester.pump();

    expect(port.integrityCalls, 1);
    expect(find.byKey(const Key('cache-integrity-result')), findsOneWidget);
    expect(find.textContaining('缺失 3'), findsOneWidget);
    expect(find.textContaining('损坏 1'), findsOneWidget);
    expect(find.textContaining('待校验 2'), findsOneWidget);
    expect(find.textContaining('仍保留在本地'), findsOneWidget);
    expect(find.byKey(const Key('cache-repair')), findsOneWidget);
  });

  testWidgets('changing mode keeps existing files', (tester) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.temporary),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));
    await tester.tap(find.byKey(const Key('cache-mode-full')));
    await tester.pumpAndSettle();

    expect(controller.mode, GameResourceCacheMode.full);
    expect(port.clearCalls, 0);
  });

  testWidgets('mobile data requires confirmation for the current download', (
    tester,
  ) async {
    final port = _FakePort()..metered = true;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));
    await tester.tap(find.byKey(const Key('cache-download-toggle')));
    await tester.pumpAndSettle();

    expect(find.textContaining('移动网络'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(port.allowedMetered, isTrue);
  });

  testWidgets('waits for the manifest before enabling preload', (tester) async {
    final port = _FakePort()..manifestReady = false;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    final download = find.byKey(const Key('cache-download-toggle'));
    expect(find.textContaining('资源清单尚未就绪'), findsOneWidget);
    expect(tester.widget<FilledButton>(download).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('cache-check-integrity')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('cache-clear')))
          .onPressed,
      isNotNull,
    );

    port.manifestReady = true;
    await controller.refresh();
    await tester.pump();
    expect(find.textContaining('资源清单尚未就绪'), findsNothing);
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
  });

  testWidgets('shows proxy pause while preserving integrity and active pause', (
    tester,
  ) async {
    final port = _FakePort()
      ..preloadBlockedByProxy = true
      ..waitingForWifi = true
      ..state = GameResourceCacheState.paused;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    final download = find.byKey(const Key('cache-download-toggle'));
    final repair = find.byKey(const Key('cache-repair'));
    expect(find.textContaining('串联 Kanxy 时已暂停预下载'), findsOneWidget);
    expect(find.textContaining('正在等待 Wi-Fi'), findsNothing);
    expect(tester.widget<FilledButton>(download).onPressed, isNull);
    await tester.tap(find.byKey(const Key('cache-check-integrity')));
    await tester.pump();
    expect(port.integrityCalls, 1);
    expect(tester.widget<OutlinedButton>(repair).onPressed, isNull);

    port.state = GameResourceCacheState.downloading;
    await controller.refresh();
    await tester.pump();
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);

    port.state = GameResourceCacheState.paused;
    port.preloadBlockedByProxy = false;
    port.waitingForWifi = false;
    await controller.refresh();
    await tester.pump();
    expect(find.textContaining('串联 Kanxy 时已暂停预下载'), findsNothing);
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(repair).onPressed, isNotNull);
  });

  for (final outcome in ['reloaded', 'cleared']) {
    testWidgets('Kanxy clear reports $outcome and leaves the stock cache', (
      tester,
    ) async {
      final port = _FakePort();
      final controller = GameResourceCacheController(
        store: _MemoryStore(GameResourceCacheMode.temporary),
        port: port,
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      const channel = MethodChannel(gameFrameReloadMethodChannelName);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return outcome;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(app(controller));
      await tester.tap(find.byKey(const Key('kanxy-cache-clear')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(calls, ['clearKanxyCacheAndReload']);
      expect(port.clearCalls, 0);
      expect(
        find.text(
          outcome == 'reloaded'
              ? '已清除 Yahagi 的 Kanxy 资源缓存并刷新游戏。'
              : '已清除 Yahagi 的 Kanxy 资源缓存，请手动刷新游戏。',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('failed cache action shows an error notice', (tester) async {
    final port = _FakePort()..failStartDownload = true;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    await tester.tap(find.byKey(const Key('cache-download-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final notice = find.byKey(topNoticeKey);
    expect(
      find.descendant(of: notice, matching: find.text('缓存操作未完成，请稍后重试。')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notice,
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('native clear exception shows an error notice', (tester) async {
    final port = _FakePort()..failClear = true;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.temporary),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    await tester.tap(find.byKey(const Key('cache-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除本地缓存').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('缓存操作未完成，请稍后重试。'), findsOneWidget);
  });
}

final class _MemoryStore implements GameResourceCacheStore {
  _MemoryStore(this.mode);
  GameResourceCacheMode mode;

  @override
  Future<GameResourceCacheMode> load() async => mode;

  @override
  Future<void> save(GameResourceCacheMode value) async => mode = value;
}

final class _FakePort implements GameResourceCachePort {
  int integrityCalls = 0;
  int clearCalls = 0;
  GameResourceCacheMode mode = GameResourceCacheMode.light;
  bool metered = false;
  bool manifestReady = true;
  bool preloadBlockedByProxy = false;
  bool waitingForWifi = false;
  GameResourceCacheState state = GameResourceCacheState.idle;
  bool allowedMetered = false;
  bool failStartDownload = false;
  bool failClear = false;

  GameResourceCacheStatus get value => GameResourceCacheStatus(
    mode: mode,
    state: state,
    cachedBytes: 6840000000,
    maxBytes: 10000000000,
    targetBytes: 8120000000,
    downloadedBytes: 0,
    bytesPerSecond: 0,
    remainingSeconds: null,
    missingCount: 3,
    damagedCount: 1,
    outdatedCount: 2,
    fileCount: 1284,
    capacityBlocked: false,
    isMetered: metered,
    manifestReady: manifestReady,
    preloadBlockedByProxy: preloadBlockedByProxy,
    waitingForWifi: waitingForWifi,
  );

  @override
  Future<bool> configure(GameResourceCacheMode value) async {
    mode = value;
    return true;
  }

  @override
  Future<GameResourceCacheStatus> status() async => value;

  @override
  Future<bool> setManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  }) async => shouldContinue?.call() ?? true;

  @override
  Future<bool> startDownload({bool allowMetered = false}) async {
    allowedMetered = allowMetered;
    return !failStartDownload;
  }

  @override
  Future<bool> pauseDownload() async => true;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async {
    integrityCalls++;
    return value;
  }

  @override
  Future<bool> repair({bool allowMetered = false}) async => true;

  @override
  Future<bool> clear() async {
    clearCalls++;
    if (failClear) throw PlatformException(code: 'clear_failed');
    return true;
  }
}
