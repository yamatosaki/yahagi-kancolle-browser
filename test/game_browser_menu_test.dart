import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_menu.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';

const _menuButtonKeys = [
  'back',
  'reload',
  'home',
  'mute',
  'screenshot',
  'fit',
  'fullscreen',
  'lock',
];

class _ActionCounter {
  final calls = <String, int>{};

  int get total => calls.values.fold(0, (sum, count) => sum + count);

  void hit(String action) => calls[action] = (calls[action] ?? 0) + 1;

  GameBrowserActions actions({
    GameBrowserMode mode = GameBrowserMode.realWeb,
    bool isMuted = false,
    bool interactionEnabled = true,
    Future<void> Function()? onReload,
  }) => GameBrowserActions(
    mode: mode,
    interactionEnabled: interactionEnabled,
    onBack: () async => hit('back'),
    onReload: onReload ?? () async => hit('reload'),
    onHome: () async => hit('home'),
    onEnterDmm: () async => hit('dmm'),
    isMuted: isMuted,
    audioEnabled: true,
    onToggleMuted: () async => hit('mute'),
    onFitScreen: () => hit('fit'),
    onEnterFullscreen: () => hit('fullscreen'),
    onScreenshot: () => hit('screenshot'),
    uiLocked: false,
    onToggleUiLock: () => hit('lock'),
  );
}

class _RouteRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  var depth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    depth++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => depth--;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth--;
}

Future<void> _openMenu(
  WidgetTester tester,
  GameBrowserActions actions, {
  _RouteRecorder? recorder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [?recorder],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGameBrowserMenu(context, actions),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows tool and page buttons', (tester) async {
    await _openMenu(tester, _ActionCounter().actions(isMuted: true));

    for (final action in _menuButtonKeys) {
      expect(
        find.byKey(Key('game-browser-menu-$action')),
        findsOneWidget,
        reason: action,
      );
    }
    expect(find.byKey(const Key('game-browser-menu-close')), findsOneWidget);
    expect(find.text('开声音'), findsOneWidget);
  });

  testWidgets('local prototype offers DMM instead of back and home', (
    tester,
  ) async {
    final counter = _ActionCounter();
    await _openMenu(
      tester,
      counter.actions(mode: GameBrowserMode.localPrototype),
    );

    expect(find.byKey(const Key('game-browser-menu-dmm')), findsOneWidget);
    expect(find.byKey(const Key('game-browser-menu-reload')), findsOneWidget);
    expect(find.byKey(const Key('game-browser-menu-back')), findsNothing);
    expect(find.byKey(const Key('game-browser-menu-home')), findsNothing);

    await tester.tap(find.byKey(const Key('game-browser-menu-dmm')));
    await tester.pumpAndSettle();
    expect(counter.calls, {'dmm': 1});
    expect(find.byKey(const Key('game-browser-menu-close')), findsNothing);
  });

  testWidgets('real web hides the DMM entry', (tester) async {
    await _openMenu(tester, _ActionCounter().actions());

    expect(find.byKey(const Key('game-browser-menu-dmm')), findsNothing);
  });

  testWidgets('tapping barrier keeps the menu open without invoking actions', (
    tester,
  ) async {
    final counter = _ActionCounter();
    await _openMenu(tester, counter.actions());

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game-browser-menu-close')), findsOneWidget);
    expect(counter.total, 0);
    await tester.tap(find.byKey(const Key('game-browser-menu-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-browser-menu-close')), findsNothing);
  });

  testWidgets('reload pops menu before invoking callback', (tester) async {
    final recorder = _RouteRecorder();
    late BuildContext hostContext;
    final counter = _ActionCounter();
    bool? menuPresentAtReload;
    final actions = counter.actions(
      onReload: () async {
        counter.hit('reload');
        menuPresentAtReload = find
            .byKey(const Key('game-browser-menu-close'))
            .evaluate()
            .isNotEmpty;
        await showDialog<void>(
          context: hostContext,
          builder: (_) => const AlertDialog(content: Text('refresh-confirm')),
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [recorder],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return TextButton(
                onPressed: () => showGameBrowserMenu(context, actions),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(recorder.depth, 2);

    await tester.tap(find.byKey(const Key('game-browser-menu-reload')));
    await tester.pumpAndSettle();

    expect(counter.calls['reload'], 1);
    expect(menuPresentAtReload, isFalse);
    expect(find.byKey(const Key('game-browser-menu-close')), findsNothing);
    expect(find.text('refresh-confirm'), findsOneWidget);
    expect(recorder.depth, 2);
  });

  testWidgets('menu route is a popup route that hides the game surface', (
    tester,
  ) async {
    final recorder = _RouteRecorder();
    await _openMenu(tester, _ActionCounter().actions(), recorder: recorder);

    final route = recorder.pushed.last;
    expect(route, isA<PopupRoute<dynamic>>());
    expect(shouldRouteHideGameSurface(route), isTrue);
  });

  testWidgets('disabled when interaction is disabled', (tester) async {
    final counter = _ActionCounter();
    await _openMenu(tester, counter.actions(interactionEnabled: false));

    await tester.tap(
      find.byKey(const Key('game-browser-menu-back')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(counter.calls['back'], isNull);
  });
}
