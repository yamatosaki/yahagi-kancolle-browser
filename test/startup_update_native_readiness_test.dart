import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_check_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/startup_update_notice.dart';

const _channel = MethodChannel('app.yahagi.kancollebrowser/native_warning');

Widget _host({ValueNotifier<bool>? native}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ValueListenableBuilder<bool>(
    valueListenable: native ?? ValueNotifier(true),
    child: StartupUpdateNotice(
      checker: _ImmediateUpdate(),
      currentVersion: '1.0.0',
      child: const Scaffold(body: Text('loading game')),
    ),
    builder: (_, isNative, child) =>
        GameDialogPresentationScope(nativeActivity: isNative, child: child!),
  ),
);

class _ImmediateUpdate implements ReleaseChecker {
  @override
  Future<ReleaseCheckResult> check({required String currentVersion}) async =>
      const UpdateAvailable(
        latestVersion: '9.9.9',
        releaseName: 'offline test',
        releaseNotes: '',
        releaseUrl: 'https://example.invalid/offline',
      );
}

void main() {
  testWidgets(
    'losing native readiness before show never hides the starting game',
    (tester) async {
      final calls = <String>[];
      _mock(Future.value(true), calls, failShow: true);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(calls.take(2), ['waitUntilAvailable', 'show']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
    },
  );

  testWidgets('fast startup update waits for the real native surface', (
    tester,
  ) async {
    final ready = Completer<bool>();
    final calls = <String>[];
    _mock(ready.future, calls);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(calls, ['waitUntilAvailable']);
    expect(find.byType(AlertDialog), findsNothing);
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(calls, ['waitUntilAvailable', 'show']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final available in [false, 'unavailable']) {
    testWidgets(
      '$available native startup never opens a covering Flutter modal',
      (tester) async {
        final calls = <String>[];
        _mock(Future.value(available), calls);
        await tester.pumpWidget(_host());
        await tester.pumpAndSettle();
        expect(calls, ['waitUntilAvailable']);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  testWidgets('disposed startup notice ignores a late native readiness', (
    tester,
  ) async {
    final ready = Completer<bool>();
    final calls = <String>[];
    _mock(ready.future, calls);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(calls, ['waitUntilAvailable']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing modes revokes even a late return to native mode', (
    tester,
  ) async {
    final ready = Completer<bool>();
    final calls = <String>[];
    final native = ValueNotifier(true);
    addTearDown(native.dispose);
    _mock(ready.future, calls);
    await tester.pumpWidget(_host(native: native));
    await tester.pumpAndSettle();
    native.value = false;
    await tester.pump();
    native.value = true;
    await tester.pump();
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(calls, ['waitUntilAvailable']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'an unresponsive readiness bridge times out without a late modal',
    (tester) async {
      final ready = Completer<bool>();
      final calls = <String>[];
      _mock(ready.future, calls);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      ready.complete(true);
      await tester.pumpAndSettle();
      expect(calls, ['waitUntilAvailable']);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}

void _mock(Future<Object?> ready, List<String> calls, {bool failShow = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call.method);
        if (call.method == 'waitUntilAvailable') {
          final value = await ready;
          if (value == 'unavailable') {
            throw PlatformException(code: 'native_warning_unavailable');
          }
          return value;
        }
        if (call.method == 'show') {
          if (failShow) {
            throw PlatformException(code: 'native_warning_unavailable');
          }
          return {'action': 'confirm', 'checked': false};
        }
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });
}
