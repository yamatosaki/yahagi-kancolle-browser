import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_toolbar.dart';

void main() {
  testWidgets('real web mode shows safe address and browser controls', (
    tester,
  ) async {
    var backCalls = 0;
    var reloadCalls = 0;
    var homeCalls = 0;
    var audioCalls = 0;
    var collapseCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBrowserToolbar(
            mode: GameBrowserMode.realWeb,
            loadState: GamePageLoadState.ready,
            displayAddress: 'https://accounts.dmm.com/login',
            onBack: () async => backCalls++,
            onReload: () async => reloadCalls++,
            onHome: () async => homeCalls++,
            onEnterDmm: () async {},
            isMuted: false,
            audioEnabled: true,
            onToggleMuted: () async => audioCalls++,
            onCollapse: () => collapseCalls++,
            onFitScreen: () {},
          ),
        ),
      ),
    );

    expect(find.text('https://accounts.dmm.com/login'), findsOneWidget);
    expect(find.textContaining('token='), findsNothing);

    await tester.tap(find.byKey(const Key('browser-back')));
    await tester.tap(find.byKey(const Key('browser-reload')));
    await tester.tap(find.byKey(const Key('browser-home')));
    await tester.tap(find.byKey(const Key('game-audio-toggle')));
    await tester.tap(find.byKey(const Key('browser-toolbar-collapse')));

    expect(
      (backCalls, reloadCalls, homeCalls, audioCalls, collapseCalls),
      (1, 1, 1, 1, 1),
    );
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.text('有声音'), findsNothing);
    expect(find.text('已静音'), findsNothing);
  });

  testWidgets('local mode requires an explicit DMM login action', (
    tester,
  ) async {
    var loginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBrowserToolbar(
            mode: GameBrowserMode.localPrototype,
            loadState: GamePageLoadState.ready,
            displayAddress: '本地模拟页',
            onBack: () async {},
            onReload: () async {},
            onHome: () async {},
            onEnterDmm: () async => loginCalls++,
            isMuted: true,
            audioEnabled: true,
            onToggleMuted: () async {},
            onCollapse: () {},
            onFitScreen: () {},
          ),
        ),
      ),
    );

    expect(find.text('本地模拟页'), findsOneWidget);
    expect(find.byKey(const Key('browser-enter-dmm')), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('browser-enter-dmm')));

    expect(loginCalls, 1);
  });

  testWidgets('disables the icon-only audio button when unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBrowserToolbar(
            mode: GameBrowserMode.realWeb,
            loadState: GamePageLoadState.ready,
            displayAddress: 'https://play.games.dmm.com/game/kancolle',
            onBack: () async {},
            onReload: () async {},
            onHome: () async {},
            onEnterDmm: () async {},
            isMuted: false,
            audioEnabled: false,
            onToggleMuted: () async {},
            onCollapse: () {},
            onFitScreen: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(
      find.byKey(const Key('game-audio-toggle')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('声音不可用'), findsNothing);
  });
}
