import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/app_exit_guard.dart';
import 'package:yahagi_kancolle_browser/src/settings/app_exit_settings.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

const _navigationChannel = MethodChannel(
  'app.yahagi.kancollebrowser/app_navigation',
);
const _dialog = Key('app-exit-confirm-dialog');
const _stay = Key('app-exit-stay');
const _leave = Key('app-exit-to-desktop');
const _game = Key('game-probe');

Widget _host({
  AppExitSettingsController? settings,
  bool fullscreen = false,
  VoidCallback? onExitFullscreen,
  Widget? child,
  Locale locale = const Locale('zh'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TopNoticeHost(
    child: Scaffold(
      body: AppExitGuard(
        settingsController: settings,
        fullscreen: fullscreen,
        onExitFullscreen: onExitFullscreen ?? () {},
        child: child ?? const SizedBox.expand(key: _game),
      ),
    ),
  ),
);

Widget _localHistoryHost(List<int> removed, {int depth = 1}) => _host(
  child: Builder(
    builder: (context) => TextButton(
      onPressed: () {
        for (var entry = 1; entry <= depth; entry++) {
          final id = entry;
          ModalRoute.of(context)!.addLocalHistoryEntry(
            LocalHistoryEntry(onRemove: () => removed.add(id)),
          );
        }
      },
      child: const Text('Open local details'),
    ),
  ),
);

void main() {
  final navigationCalls = <MethodCall>[];
  final platformCalls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    navigationCalls.clear();
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, (call) async {
          navigationCalls.add(call);
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('root Back is blocked ahead of time and asks by default', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.byKey(_game)))!;
    expect(route.popDisposition, RoutePopDisposition.doNotPop);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(_dialog), findsOneWidget);
    expect(find.text('返回桌面？'), findsOneWidget);
    expect(find.text('继续游戏'), findsOneWidget);
    expect(find.text('下次不再提醒'), findsNothing);
    expect(navigationCalls, isEmpty);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );
  });

  testWidgets('only explicit confirmation backgrounds the existing game', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final gameElement = tester.element(find.byKey(_game));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_leave));
    await tester.pumpAndSettle();

    expect(navigationCalls.map((call) => call.method), ['moveToBackground']);
    expect(find.byKey(_dialog), findsNothing);
    expect(tester.element(find.byKey(_game)), same(gameElement));
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );
    // Returning to the game does not disable protection for the next Back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets('stay cancels and the next Back still asks', (tester) async {
    await tester.pumpWidget(_host());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_stay));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets('Back dismisses confirmation and never confirms leaving', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);
    expect(find.byKey(_game), findsOneWidget);
  });

  testWidgets('tapping the barrier keeps exit confirmation open', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
    expect(navigationCalls, isEmpty);
    await tester.tap(find.byKey(_stay));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);
  });

  testWidgets('rapid Back events cannot stack dialogs or leave the app', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await Future.wait(List.generate(5, (_) => tester.binding.handlePopRoute()));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog).evaluate().length, lessThanOrEqualTo(1));
    expect(navigationCalls, isEmpty);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );
    if (find.byKey(_dialog).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(_stay));
      await tester.pumpAndSettle();
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets('disabled preference allows normal root Back', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppExitSettingsController.preferenceKey: false,
    });
    final settings = await AppExitSettingsController.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(_host(settings: settings));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.byKey(_game)))!;
    expect(route.popDisposition, RoutePopDisposition.bubble);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      hasLength(1),
    );
  });

  testWidgets('changing the switch updates Back protection immediately', (
    tester,
  ) async {
    final settings = await AppExitSettingsController.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(_host(settings: settings));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.byKey(_game)))!;

    await settings.setEnabled(false);
    await tester.pumpAndSettle();
    expect(route.popDisposition, RoutePopDisposition.bubble);
    await settings.setEnabled(true);
    await tester.pumpAndSettle();
    expect(route.popDisposition, RoutePopDisposition.doNotPop);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets('fullscreen Back exits fullscreen before asking to leave', (
    tester,
  ) async {
    final fullscreen = ValueNotifier(true);
    addTearDown(fullscreen.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: ValueListenableBuilder<bool>(
          valueListenable: fullscreen,
          builder: (context, active, _) => AppExitGuard(
            fullscreen: active,
            onExitFullscreen: () => fullscreen.value = false,
            child: const Scaffold(body: SizedBox.expand(key: _game)),
          ),
        ),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(fullscreen.value, isFalse);
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets('Back pops a pushed page without showing exit confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Details')),
              ),
            ),
            child: const Text('Open details'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsNothing);
    expect(find.text('Open details'), findsOneWidget);
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);
  });

  testWidgets('Back closes local details before asking to leave the app', (
    tester,
  ) async {
    final removed = <int>[];
    await tester.pumpWidget(_localHistoryHost(removed));
    await tester.tap(find.text('Open local details'));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(
      tester.element(find.text('Open local details')),
    )!;
    expect(route.willHandlePopInternally, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(removed, [1]);
    expect(find.byKey(_dialog), findsNothing);
    expect(route.isCurrent, isTrue);
    expect(route.popDisposition, RoutePopDisposition.doNotPop);
    expect(navigationCalls, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets('each Back consumes only the latest local history entry', (
    tester,
  ) async {
    final removed = <int>[];
    await tester.pumpWidget(_localHistoryHost(removed, depth: 2));
    await tester.tap(find.text('Open local details'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(removed, [2]);
    expect(find.byKey(_dialog), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(removed, [2, 1]);
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsOneWidget);
  });

  testWidgets(
    'immediate Back after the last local entry still requires confirmation',
    (tester) async {
      final removed = <int>[];
      await tester.pumpWidget(_localHistoryHost(removed));
      await tester.tap(find.text('Open local details'));
      await tester.pumpAndSettle();

      // Deliberately do not render a new frame between the two Back events.
      await tester.binding.handlePopRoute();
      expect(removed, [1]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsOneWidget);
      expect(navigationCalls, isEmpty);
      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
      );
    },
  );

  testWidgets('manually closing local details keeps root Back protected', (
    tester,
  ) async {
    final removed = <int>[];
    LocalHistoryEntry? entry;
    await tester.pumpWidget(
      _host(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              entry = LocalHistoryEntry(onRemove: () => removed.add(1));
              ModalRoute.of(context)!.addLocalHistoryEntry(entry!);
            },
            child: const Text('Open local details'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open local details'));
    await tester.pumpAndSettle();
    entry!.remove();
    // No frame is needed to restore protection after an external dismissal.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(removed, [1]);
    expect(find.byKey(_dialog), findsOneWidget);
    expect(navigationCalls, isEmpty);
  });

  testWidgets('Back dismisses an existing dialog before considering app exit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('Other dialog')),
            ),
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Other dialog'), findsNothing);
    expect(find.byKey(_dialog), findsNothing);
    expect(navigationCalls, isEmpty);
  });

  for (final result in [false, null, 'error']) {
    testWidgets('failed background request $result keeps protection active', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_navigationChannel, (call) async {
            navigationCalls.add(call);
            if (result == 'error') {
              throw PlatformException(code: 'move_to_background_failed');
            }
            return result;
          });
      await tester.pumpWidget(_host());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_leave));
      await tester.pumpAndSettle();
      expect(find.text('无法返回桌面，请重试。'), findsOneWidget);
      expect(find.byKey(_game), findsOneWidget);
      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('pending native request does not allow duplicate departures', (
    tester,
  ) async {
    final completed = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, (call) {
          navigationCalls.add(call);
          return completed.future;
        });
    await tester.pumpWidget(_host());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_leave));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(navigationCalls, hasLength(1));
    expect(find.byKey(_dialog), findsNothing);
    completed.complete(true);
    await tester.pumpAndSettle();
  });

  for (final action in [_stay, _leave]) {
    testWidgets('rapid taps on $action cannot pop the underlying game', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(action));
      await tester.tap(find.byKey(action), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(_game), findsOneWidget);
      expect(navigationCalls, hasLength(action == _leave ? 1 : 0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposing during a pending departure is safe', (tester) async {
    final completed = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, (_) => completed.future);
    await tester.pumpWidget(_host());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_leave));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    completed.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
