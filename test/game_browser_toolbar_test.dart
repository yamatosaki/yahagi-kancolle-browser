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

  testWidgets(
    'persistent mode shows six actions in order without overlay controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var screenshots = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameBrowserToolbar(
              persistent: true,
              mode: GameBrowserMode.realWeb,
              loadState: GamePageLoadState.ready,
              displayAddress: 'https://play.games.dmm.com/game/kancolle',
              onBack: () async {},
              onReload: () async {},
              onHome: () async {},
              onEnterDmm: () async {},
              isMuted: false,
              audioEnabled: true,
              onToggleMuted: () async {},
              onCollapse: () {},
              onFitScreen: () {},
              onScreenshot: () => screenshots++,
            ),
          ),
        ),
      );

      final actions = <Finder>[
        find.byKey(const Key('browser-back')),
        find.byKey(const Key('browser-reload')),
        find.byKey(const Key('browser-home')),
        find.byKey(const Key('game-audio-toggle')),
        find.byKey(const Key('browser-screenshot')),
        find.byKey(const Key('browser-fit-screen')),
      ];
      for (var index = 1; index < actions.length; index++) {
        expect(
          tester.getCenter(actions[index]).dx,
          greaterThan(tester.getCenter(actions[index - 1]).dx),
        );
      }
      expect(find.byKey(const Key('browser-toolbar-collapse')), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
      await tester.tap(find.byKey(const Key('browser-screenshot')));
      expect(screenshots, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('persistent toolbar is compact only on landscape phones', (
    tester,
  ) async {
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameBrowserToolbar(
              persistent: true,
              mode: GameBrowserMode.realWeb,
              loadState: GamePageLoadState.ready,
              displayAddress: 'https://play.games.dmm.com/game/kancolle',
              onBack: () async {},
              onReload: () async {},
              onHome: () async {},
              onEnterDmm: () async {},
              isMuted: false,
              audioEnabled: true,
              onToggleMuted: () async {},
              onCollapse: () {},
              onFitScreen: () {},
            ),
          ),
        ),
      );
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(const Size(700, 320));
    expect(tester.getSize(find.byType(GameBrowserToolbar)).height, 36);
    expect(
      tester.getSize(find.byKey(const Key('browser-back'))),
      const Size(34, 34),
    );
    expect(
      tester.getSize(find.byKey(const Key('game-audio-toggle'))),
      const Size(34, 34),
    );

    await pumpAt(const Size(1200, 800));
    expect(tester.getSize(find.byType(GameBrowserToolbar)).height, 42);
    expect(
      tester.getSize(find.byKey(const Key('browser-back'))),
      const Size(36, 36),
    );
    expect(
      tester.getSize(find.byKey(const Key('game-audio-toggle'))),
      const Size(40, 40),
    );
  });

  testWidgets('toolbar blur can be disabled for compatibility rendering', (
    tester,
  ) async {
    Future<void> pumpToolbar({required bool enableBackdropBlur}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameBrowserToolbar(
              enableBackdropBlur: enableBackdropBlur,
              mode: GameBrowserMode.realWeb,
              loadState: GamePageLoadState.ready,
              displayAddress: 'https://play.games.dmm.com/game/kancolle',
              onBack: () async {},
              onReload: () async {},
              onHome: () async {},
              onEnterDmm: () async {},
              isMuted: false,
              audioEnabled: true,
              onToggleMuted: () async {},
              onCollapse: () {},
              onFitScreen: () {},
            ),
          ),
        ),
      );
    }

    await pumpToolbar(enableBackdropBlur: true);
    expect(find.byType(BackdropFilter), findsOneWidget);

    await pumpToolbar(enableBackdropBlur: false);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byKey(const Key('browser-back')), findsOneWidget);
  });

  testWidgets('toolbar interactions can be locked during a rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBrowserToolbar(
            interactionEnabled: false,
            mode: GameBrowserMode.realWeb,
            loadState: GamePageLoadState.ready,
            displayAddress: 'https://play.games.dmm.com/game/kancolle',
            onBack: () async {},
            onReload: () async {},
            onHome: () async {},
            onEnterDmm: () async {},
            isMuted: false,
            audioEnabled: true,
            onToggleMuted: () async {},
            onCollapse: () {},
            onFitScreen: () {},
            onScreenshot: () {},
          ),
        ),
      ),
    );

    for (final key in <String>[
      'browser-back',
      'browser-reload',
      'browser-home',
      'game-audio-toggle',
      'browser-screenshot',
      'browser-fit-screen',
      'browser-toolbar-collapse',
    ]) {
      final keyed = find.byKey(Key(key));
      final keyedWidget = tester.widget(keyed);
      final button = keyedWidget is IconButton
          ? keyedWidget
          : tester.widget<IconButton>(
              find.descendant(of: keyed, matching: find.byType(IconButton)),
            );
      expect(button.onPressed, isNull);
    }
  });
}
