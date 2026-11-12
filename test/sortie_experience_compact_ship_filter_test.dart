import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_resource_checklist.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_controller.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_ship_filter.dart';

const _open = Key('open-picker');
const _next = Key('next-control');
const _dialog = Key('sortie-exp-filter-dialog');
const _first = Key('sortie-exp-filter-ship-101');
const _second = Key('sortie-exp-filter-ship-102');
const _done = Key('sortie-exp-filter-done');
const _close = Key('sortie-exp-filter-close');

void main() {
  testWidgets(
    'compact picker closes, goes back, and commits without a touch guard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 290);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fixture = await _mount(tester);
      final first = find.byKey(_first);
      final second = find.byKey(_second);
      final open = find.byKey(_open);

      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byKey(_dialog), findsOneWidget);
      expect(tester.getTopLeft(second).dy - tester.getTopLeft(first).dy, 39);
      expect(find.byKey(_done).hitTestable(), findsOneWidget);
      await tester.tap(first);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(first).value, isFalse);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);

      await tester.tap(find.byKey(_close));
      await tester.pump();
      fixture.expectNoGuard();
      expect(find.byKey(_dialog), findsNothing);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      await tester.tap(find.byKey(_next));
      expect(fixture.nextTaps, 1);

      await tester.tap(open);
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pump();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      fixture.expectNoGuard();
      expect(find.byKey(_dialog), findsNothing);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      await tester.tap(find.byKey(_next));
      expect(fixture.nextTaps, 2);

      await tester.tap(open);
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pump();
      await tester.tap(find.byKey(_done));
      await tester.pump();
      fixture.expectNoGuard();
      expect(fixture.controller.hiddenTotalShipIds, {101});
      await tester.tap(find.byKey(_next));
      expect(fixture.nextTaps, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native checklist requests no touch guard on Done or cancel', (
    tester,
  ) async {
    final port = _NativePort();
    addTearDown(port.source.close);
    final fixture = await _mount(tester, port: port);
    for (final action in [null, NativeGameWarningAction.acknowledge]) {
      await tester.tap(find.byKey(_open));
      await tester.pump();
      expect(port.request['protectInputOnDismiss'], isFalse);
      expect(port.request['backCancels'], isTrue);
      expect(port.request['compactShipChecklist'], isTrue);
      final row = (port.request['items'] as List).first as Map;
      expect(row['detail'], 'Lv.—');
      expect(row['value'], '+899 EXP');
      expect(
        port.request['closeLabel'],
        isA<String>().having((label) => label.isNotEmpty, 'isNotEmpty', isTrue),
      );
      expect(find.byKey(_dialog), findsNothing);
      port.source.add({
        'kind': port.request['kind'],
        'id': port.request['id'],
        'event': 'toggle',
        'changeId': 1,
        'itemId': '101',
        'checked': false,
      });
      await tester.pump();
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      port.result.complete(action);
      await tester.pump();
      fixture.expectNoGuard();
      expect(
        fixture.controller.hiddenTotalShipIds,
        action == null ? isEmpty : {101},
      );
      await tester.tap(find.byKey(_next));
    }
    expect(fixture.nextTaps, 2);
    expect(tester.takeException(), isNull);
  });
}

Future<_Fixture> _mount(WidgetTester tester, {_NativePort? port}) async {
  final originalTimerSetting = GameStateController.disableTimerForTest;
  GameStateController.disableTimerForTest = true;
  addTearDown(
    () => GameStateController.disableTimerForTest = originalTimerSetting,
  );
  SharedPreferences.setMockInitialValues({
    'account.99.sortieExperience.v1': jsonEncode({
      'version': 1,
      'memberId': 99,
      'tracking': true,
      'totalSorties': 1,
      'totals': [
        for (var id = 101; id <= 112; id++)
          {
            'ownedShipId': id,
            'masterShipId': id,
            'name': '舰娘 ${id - 100}',
            'fleetId': 1,
            'position': 0,
            'experience': 1000 - id,
            'retreated': false,
          },
      ],
    }),
  });
  final accountSession = AccountSession(initialMemberId: 99);
  final gameState = GameStateController(
    initialState: const GameState(memberId: 99),
  );
  final controller = SortieExperienceController(
    accountSession: accountSession,
    gameState: () => gameState.state,
  );
  final fixture = _Fixture(controller);
  addTearDown(() {
    controller.dispose();
    gameState.dispose();
    accountSession.dispose();
  });
  await controller.initialize();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: fixture.navigator,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GameDialogPresentationScope(
        nativeActivity: port != null,
        nativeChecklistPort: port,
        child: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  key: _open,
                  onPressed: () => unawaited(
                    showSortieExperienceShipFilter(
                      context: context,
                      controller: controller,
                      gameState: gameState,
                      account: accountSession.current,
                      ownerIsCurrent: () => true,
                    ),
                  ),
                  child: const Text('Open'),
                ),
                TextButton(
                  key: _next,
                  onPressed: () => fixture.nextTaps++,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return fixture;
}

final class _Fixture {
  _Fixture(this.controller);
  final SortieExperienceController controller;
  final navigator = GlobalKey<NavigatorState>();
  int nextTaps = 0;

  void expectNoGuard() {
    expect(
      GameSafetyDialogRoute.hasInputProtectionFor(navigator.currentState!),
      isFalse,
    );
    expect(
      GameSurfaceInputGuardRoute.hasActiveFor(navigator.currentState!),
      isFalse,
    );
  }
}

final class _NativePort implements NativeGameResourceChecklistPort {
  final source = StreamController<Map<String, Object?>>.broadcast(sync: true);
  late Completer<NativeGameWarningAction?> result;
  late Map<String, Object?> request;

  @override
  Stream<Map<String, Object?>> get events => source.stream;

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) {
    request = payload;
    result = Completer<NativeGameWarningAction?>();
    return result.future;
  }

  @override
  Future<void> update(Map<String, Object?> payload) async {}

  @override
  Future<void> dismiss({required String kind, required int id}) async {
    if (!result.isCompleted) result.complete(null);
  }
}
