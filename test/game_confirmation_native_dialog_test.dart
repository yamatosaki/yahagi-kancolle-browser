import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/app_exit_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_refresh_shortcut_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_fullscreen_exit_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_refresh_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_check_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/startup_update_notice.dart';

const _native = MethodChannel('app.yahagi.kancollebrowser/native_warning');
const _navigation = MethodChannel('app.yahagi.kancollebrowser/app_navigation');

Widget _nativeHost(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: GameDialogPresentationScope(
    nativeActivity: true,
    child: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <Map<Object?, Object?>>[];
  final navigationCalls = <MethodCall>[];
  late Completer<Object?> response;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    navigationCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_native, (call) async {
          if (call.method == 'waitUntilAvailable') return true;
          if (call.method == 'show') {
            requests.add(Map<Object?, Object?>.from(call.arguments as Map));
            return response.future;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigation, (call) async {
          navigationCalls.add(call);
          return true;
        });
  });

  tearDown(() {
    if (!response.isCompleted) response.complete(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_native, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigation, null);
  });

  for (final action in [null, 'cancel', 'refreshPage', 'reloadFrame']) {
    testWidgets(
      'native refresh result $action executes only its chosen action',
      (tester) async {
        response = Completer<Object?>();
        var pages = 0;
        var frames = 0;
        await tester.pumpWidget(
          _nativeHost(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showGameRefreshDialog(
                  context: context,
                  onRefreshPage: () async => pages++,
                  onReloadGame: () async {
                    frames++;
                    return GameFrameReloadResult.reloaded;
                  },
                ),
                child: const Text('game'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('game'));
        await tester.pumpAndSettle();
        expect(requests.single['kind'], 'surfaceDialog');
        expect(requests.single['actions'], [
          'cancel',
          'refreshPage',
          'reloadFrame',
        ]);
        expect(find.byType(AlertDialog), findsNothing);
        expect((pages, frames), (0, 0));
        response.complete(
          action == null ? null : {'action': action, 'checked': false},
        );
        await tester.pumpAndSettle();
        expect(
          (pages, frames),
          (action == 'refreshPage' ? 1 : 0, action == 'reloadFrame' ? 1 : 0),
        );
        expect(find.text('game'), findsOneWidget);
      },
    );
  }

  for (final action in [null, 'cancel', 'confirm']) {
    testWidgets('native frame checkbox is saved only on $action confirmation', (
      tester,
    ) async {
      response = Completer<Object?>();
      final settings = await GameFrameRefreshShortcutSettings.load();
      addTearDown(settings.dispose);
      final decisions = <bool>[];
      await tester.pumpWidget(
        _nativeHost(
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
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(requests.single['kind'], 'surfaceDialog');
      expect(requests.single['checkbox'], containsPair('checked', false));
      expect(find.byType(AlertDialog), findsNothing);
      response.complete(
        action == null ? null : {'action': action, 'checked': true},
      );
      await tester.pumpAndSettle();
      expect(decisions, [action == 'confirm']);
      expect(settings.skipHeaderConfirmation, action == 'confirm');
    });

    testWidgets(
      'native fullscreen checkbox is saved only on $action confirmation',
      (tester) async {
        response = Completer<Object?>();
        final decisions = <bool>[];
        await tester.pumpWidget(
          _nativeHost(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => decisions.add(
                  await confirmGameFullscreenExit(context: context),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(requests.single['kind'], 'surfaceDialog');
        expect(find.byType(AlertDialog), findsNothing);
        response.complete(
          action == null ? null : {'action': action, 'checked': true},
        );
        await tester.pumpAndSettle();
        expect(decisions, [action == 'confirm']);
        expect(
          await isExitFullscreenConfirmationSkipped(),
          action == 'confirm',
        );
      },
    );
  }

  for (final action in [null, 'stay', 'leave']) {
    testWidgets('native app departure requires explicit $action decision', (
      tester,
    ) async {
      response = Completer<Object?>();
      await tester.pumpWidget(
        _nativeHost(
          AppExitGuard(
            fullscreen: false,
            onExitFullscreen: () {},
            child: const Text('game'),
          ),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(requests.single['kind'], 'surfaceDialog');
      expect(navigationCalls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      response.complete(
        action == null ? null : {'action': action, 'checked': false},
      );
      await tester.pumpAndSettle();
      expect(navigationCalls, hasLength(action == 'leave' ? 1 : 0));
      expect(find.text('game'), findsOneWidget);
    });
  }

  testWidgets('startup update is shown in the native game window', (
    tester,
  ) async {
    response = Completer<Object?>();
    await tester.pumpWidget(
      _nativeHost(
        StartupUpdateNotice(
          checker: _NewRelease(),
          currentVersion: '1.0.1',
          child: const Text('game'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests.single['kind'], 'surfaceDialog');
    expect(requests.single['title'], '发现新版本');
    expect(find.byType(AlertDialog), findsNothing);
    response.complete({'action': 'confirm', 'checked': false});
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
