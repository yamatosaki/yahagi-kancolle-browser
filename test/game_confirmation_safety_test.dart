import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/app_exit_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_refresh_shortcut_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_fullscreen_exit_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_refresh_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_check_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/startup_update_notice.dart';

class _Routes extends NavigatorObserver {
  Route<dynamic>? latest;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    latest = route;
  }
}

Widget _host(Widget child, _Routes routes) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  navigatorObservers: [routes],
  home: Scaffold(body: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('page refresh waits for the protected touch interval', (
    tester,
  ) async {
    final routes = _Routes();
    var refreshes = 0;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showGameRefreshDialog(
              context: context,
              onRefreshPage: () async => refreshes++,
              onReloadGame: () async => GameFrameReloadResult.reloaded,
            ),
            child: const Text('open'),
          ),
        ),
        routes,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(routes.latest, isA<GameSafetyDialogRoute>());

    await tester.tap(find.byKey(const Key('refresh-full-page')));
    await tester.pump();
    expect(refreshes, 0);
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets('frame confirmation returns only after input protection', (
    tester,
  ) async {
    final routes = _Routes();
    final decisions = <bool>[];
    final settings = await GameFrameRefreshShortcutSettings.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => decisions.add(
              await confirmGameFrameRefreshShortcut(
                context: context,
                settings: settings,
              ),
            ),
            child: const Text('open'),
          ),
        ),
        routes,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(routes.latest, isA<GameSafetyDialogRoute>());
    await tester.tap(find.byKey(const Key('frame-refresh-confirm')));
    await tester.pump();
    expect(decisions, isEmpty);
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(decisions, [true]);
  });

  testWidgets('fullscreen Back cancels through input protection', (
    tester,
  ) async {
    final routes = _Routes();
    final decisions = <bool>[];
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => decisions.add(
              await confirmGameFullscreenExit(context: context),
            ),
            child: const Text('open'),
          ),
        ),
        routes,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(routes.latest, isA<GameSafetyDialogRoute>());
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(decisions, isEmpty);
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(decisions, [false]);
    expect(await isExitFullscreenConfirmationSkipped(), isFalse);
  });

  testWidgets('app departure waits for input protection', (tester) async {
    const navigation = MethodChannel(
      'app.yahagi.kancollebrowser/app_navigation',
    );
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(navigation, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        navigation,
        null,
      ),
    );
    final routes = _Routes();
    await tester.pumpWidget(
      _host(
        AppExitGuard(
          fullscreen: false,
          onExitFullscreen: () {},
          child: const SizedBox.expand(),
        ),
        routes,
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(routes.latest, isA<GameSafetyDialogRoute>());
    await tester.tap(find.byKey(const Key('app-exit-to-desktop')));
    await tester.pump();
    expect(calls, isEmpty);
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(calls.map((call) => call.method), ['moveToBackground']);
  });

  testWidgets('startup update uses the same protected dialog route', (
    tester,
  ) async {
    final routes = _Routes();
    await tester.pumpWidget(
      _host(
        StartupUpdateNotice(
          checker: _NewRelease(),
          currentVersion: '1.0.1',
          child: const Text('game'),
        ),
        routes,
      ),
    );
    await tester.pumpAndSettle();
    expect(routes.latest, isA<GameSafetyDialogRoute>());
    await tester.tap(find.text('确定'));
    await tester.pump();
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('game'), findsOneWidget);
  });
}

class _NewRelease implements ReleaseChecker {
  @override
  Future<ReleaseCheckResult> check({required String currentVersion}) async =>
      const UpdateAvailable(
        latestVersion: '1.0.2',
        releaseName: '1.0.2',
        releaseNotes: '',
        releaseUrl: 'https://example.test/release',
      );
}
