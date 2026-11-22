import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_startup_overlay.dart';

void main() {
  testWidgets('uses a real percentage only for entry-page loading', (
    tester,
  ) async {
    await _pump(
      tester,
      const GameStartupOverlay(stage: GameStartupStage.page, pageProgress: 38),
    );
    expect(find.text('38%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.38,
    );

    await _pump(
      tester,
      const GameStartupOverlay(stage: GameStartupStage.game, pageProgress: 38),
    );
    expect(find.text('38%'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('compact resources remain centered and show the request count', (
    tester,
  ) async {
    await _pump(
      tester,
      const GameStartupOverlay(
        stage: GameStartupStage.game,
        compact: true,
        requestCount: 12,
      ),
      size: const Size(300, 220),
      textScale: 1.4,
    );
    expect(find.text('正在加载游戏资源'), findsOneWidget);
    expect(find.text('12 个请求'), findsOneWidget);
    expect(
      tester.getCenter(find.byType(SingleChildScrollView)),
      tester.getCenter(find.byType(GameStartupOverlay)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource bar loops a fixed-width segment along the track', (
    tester,
  ) async {
    await _pump(
      tester,
      const GameStartupOverlay(stage: GameStartupStage.game, compact: true),
    );
    final bar = find.byKey(const Key('game-startup-resource-progress'));
    final width = tester.getSize(bar).width;
    final initial = _paintedSegment(bar);
    await tester.pump(const Duration(milliseconds: 300));
    final advanced = _paintedSegment(bar);
    expect(advanced.left, greaterThan(initial.left));
    expect(advanced.width, closeTo(width * 0.28, 0.001));
    expect(advanced.right, lessThan(width));

    await tester.pump(const Duration(milliseconds: 1400));
    expect(_paintedSegment(bar).left, closeTo(advanced.left, 0.001));
  });

  testWidgets('reduced motion keeps the short resource segment still', (
    tester,
  ) async {
    await _pump(
      tester,
      const GameStartupOverlay(stage: GameStartupStage.game, compact: true),
      disableAnimations: true,
    );
    final bar = find.byKey(const Key('game-startup-resource-progress'));
    final initial = _paintedSegment(bar);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paintedSegment(bar), initial);
    expect(initial.width, lessThan(tester.getSize(bar).width));
  });

  testWidgets('a stalled stage offers retry without inventing a percentage', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      GameStartupOverlay(
        stage: GameStartupStage.game,
        stalled: true,
        onRetry: () => retries++,
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('已 20 秒没有新进展，可以继续等待或重新加载。'), findsOneWidget);
    expect(find.text('连接详情'), findsNothing);
    await tester.tap(find.text('重新载入游戏'));
    expect(retries, 1);
  });

  testWidgets('copies bounded failure details without the message or URL', (
    tester,
  ) async {
    String? clipboardText;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (method) async {
      if (method.method == 'Clipboard.setData') {
        clipboardText = (method.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pump(
      tester,
      const GameStartupOverlay(
        stage: GameStartupStage.page,
        failure: GameStartupFailure(
          '入口页面加载失败',
          host: 'https://user:secret@example.test/?token=private',
          code: 'HTTP 503',
        ),
      ),
    );

    expect(find.text('入口页面加载失败'), findsOneWidget);
    expect(find.text('HTTP 503'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('复制错误详情'));
    await tester.pump();

    expect(clipboardText, contains('HTTP 503'));
    expect(clipboardText, isNot(contains('private')));
    expect(clipboardText, isNot(contains('secret')));
    expect(clipboardText, isNot(contains('入口页面加载失败')));
    expect(find.text('已复制错误详情'), findsOneWidget);
  });

  testWidgets('fits a narrow, short game viewport with enlarged text', (
    tester,
  ) async {
    await _pump(
      tester,
      GameStartupOverlay(
        stage: GameStartupStage.preparing,
        failure: const GameStartupFailure(
          '无法连接 http本地代理',
          host: '127.0.0.1',
          code: 'HTTP_LISTENER_UNAVAILABLE',
          help: '请确认本地代理已启动，核对地址和端口后重试。',
        ),
        onRetry: () {},
        onRetryWithSystemNetwork: () {},
      ),
      size: const Size(300, 220),
      textScale: 1.4,
    );
    expect(tester.takeException(), isNull);

    final retry = find.text('重新载入游戏');
    await tester.ensureVisible(retry);
    expect(retry.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

RRect _paintedSegment(Finder bar) {
  late RRect segment;
  expect(
    bar,
    paints
      ..rrect()
      ..something((method, arguments) {
        if (method != #drawRRect) return false;
        segment = arguments.first as RRect;
        return true;
      }),
  );
  return segment;
}

Future<void> _pump(
  WidgetTester tester,
  Widget overlay, {
  Size size = const Size(500, 420),
  double textScale = 1.0,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: SizedBox.fromSize(size: size, child: overlay),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
