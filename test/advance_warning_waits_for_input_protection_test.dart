import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_reminder_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/capture/sortie_warning_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _guard = Key('game-safety-input-guard');
const _battle = Key('acknowledgeAdvanceWarning');
const _headerDone = Key('test-header-done');

void main() {
  testWidgets(
    'the ready guard stays installed until the queued battle is pushed',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      final held = await fixture.protectHeader(tester, rawGuard: true);
      await fixture.warn(tester);
      await held.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_battle), findsOneWidget);
      final battlePush = fixture.observer.events.indexWhere(
        (event) => event.$1 == 'push' && event.$2 is GameSafetyDialogRoute,
        fixture.observer.events.indexWhere(
          (event) => event.$2 is GameSurfaceInputGuardRoute,
        ),
      );
      final guardRemoval = fixture.observer.events.indexWhere(
        (event) =>
            event.$1 == 'remove' && event.$2 is GameSurfaceInputGuardRoute,
      );
      expect(battlePush, greaterThanOrEqualTo(0));
      expect(guardRemoval, greaterThanOrEqualTo(0));
      expect(
        battlePush,
        lessThan(guardRemoval),
        reason: 'native visibility must stay covered during the modal handoff',
      );
    },
  );

  for (final rawGuard in [false, true]) {
    testWidgets(
      'battle waits for ${rawGuard ? 'raw' : 'in-place'} header protection and the real held pointer',
      (tester) async {
        final fixture = await _Fixture.mount(tester);
        final held = await fixture.protectHeader(tester, rawGuard: rawGuard);
        await fixture.warn(tester);
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.byKey(_battle),
          findsNothing,
          reason: 'a battle popup must not replace the held input target',
        );
        expect(find.byKey(_guard), findsOneWidget);
        expect(fixture.header!.isActive, isTrue);
        expect(fixture.gameTouches, 0);
        await held.up();
        await tester.pump(const Duration(milliseconds: 599));
        expect(find.byKey(_battle), findsNothing);
        await tester.pumpAndSettle();
        expect(await fixture.header!.completed, isTrue);
        expect(find.byKey(_battle), findsOneWidget);
        await tester.tap(find.byKey(_battle));
        await tester.pumpAndSettle();
        expect(fixture.gameTouches, 0);
        await tester.tapAt(const Offset(20, 100));
        expect(fixture.gameTouches, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new accepted danger metadata survives the wait and is shown once',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      final held = await fixture.protectHeader(tester);
      await fixture.warn(tester);
      fixture.state = _sortie.copyWith(
        masterShips: const {
          2: MasterShip(id: 2, name: 'latest danger', shipTypeId: 2),
        },
      );
      await fixture.warn(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_battle), findsNothing);
      await held.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_battle), findsOneWidget);
      expect(find.text('latest danger'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.gameTouches, 0);
    },
  );

  testWidgets(
    'interruption preserves the latest event and queues fresh danger',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      final held = await fixture.protectHeader(tester);
      await fixture.warn(tester);
      final oldEvent = fixture.capture.latestEvent;
      final oldGeneration = fixture.capture.continuityGeneration;
      fixture.port.interrupt();
      expect(fixture.capture.latestEvent, same(oldEvent));
      expect(fixture.capture.continuityGeneration, greaterThan(oldGeneration));
      fixture.state = _sortie.copyWith(
        masterShips: const {
          2: MasterShip(id: 2, name: 'recovered danger', shipTypeId: 2),
        },
      );
      await fixture.warn(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_battle), findsNothing);
      expect(find.byKey(_guard), findsOneWidget);
      await held.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_battle), findsOneWidget);
      expect(find.text('recovered danger'), findsOneWidget);
      expect(fixture.gameTouches, 0);
    },
  );
  testWidgets(
    'recovering a deferred Flutter fallback cannot retry native while held',
    (tester) async {
      final native = _TemporarilyUnavailableNative();
      final fixture = await _Fixture.mount(tester, native: native);
      final held = await fixture.protectHeader(tester);
      await fixture.warn(tester);
      expect(native.showCount, 1);
      fixture.port.interrupt();
      fixture.state = _sortie.copyWith(
        masterShips: const {
          2: MasterShip(
            id: 2,
            name: 'fallback recovered danger',
            shipTypeId: 2,
          ),
        },
      );
      await fixture.warn(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(
        native.showCount,
        1,
        reason: 'preserve the guarded Flutter fallback choice',
      );
      expect(find.byKey(_battle), findsNothing);
      expect(find.byKey(_guard), findsOneWidget);
      await held.up();
      await tester.pumpAndSettle();
      expect(native.showCount, 1);
      expect(find.byKey(_battle), findsOneWidget);
      expect(find.text('fallback recovered danger'), findsOneWidget);
    },
  );

  for (final cancellation in [
    'account',
    'capture',
    'off',
    'mute',
    'dispose',
    'safe',
  ]) {
    testWidgets(
      '$cancellation cannot resurrect a queued battle after protection',
      (tester) async {
        final fixture = await _Fixture.mount(tester);
        final held = await fixture.protectHeader(tester);
        await fixture.warn(tester);
        switch (cancellation) {
          case 'account':
            fixture.account.selectMember(2002);
          case 'capture':
            fixture.capture.clearCapturedEvents();
          case 'off':
            await fixture.settings.setBattleWarningMode(BattleWarningMode.off);
          case 'mute':
            fixture.session.muteCurrentSortie();
          case 'dispose':
            fixture.visible.value = false;
          case 'safe':
            fixture.state = _sortie.copyWith(
              ships: const {
                101: OwnedShip(
                  id: 101,
                  masterId: 1,
                  level: 99,
                  currentHp: 20,
                  maxHp: 20,
                ),
                102: OwnedShip(
                  id: 102,
                  masterId: 2,
                  level: 99,
                  currentHp: 20,
                  maxHp: 20,
                ),
              },
            );
            await fixture.warn(tester);
        }
        await tester.pump();
        await held.up();
        await tester.pumpAndSettle();
        expect(find.byKey(_battle), findsNothing);
        expect(find.byKey(_guard), findsNothing);
        expect(fixture.gameTouches, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Held {
  _Held(this.gesture);
  final TestGesture gesture;
  bool released = false;
  Future<void> up() async {
    released = true;
    await gesture.up();
  }

  Future<void> cancelIfHeld() async {
    if (!released) {
      released = true;
      await gesture.cancel();
    }
  }
}

class _Fixture {
  final account = AccountSession(initialMemberId: 1001);
  final capture = GameCaptureController();
  final port = _CapturePort();
  final session = SortieWarningSession()..startSortie();
  final visible = ValueNotifier(true);
  final observer = _RouteOrderObserver();
  late SafetySettingsController settings;
  late BuildContext context;
  GameState state = _sortie;
  GameReminderDialogPresentation? header;
  int gameTouches = 0;
  int sequence = 0;
  NativeGameWarningDialogPort? native;

  static Future<_Fixture> mount(
    WidgetTester tester, {
    NativeGameWarningDialogPort? native,
  }) async {
    final fixture = _Fixture();
    fixture.native = native;
    fixture.settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await fixture.settings.setAdvanceWarningTimings(
      AdvanceWarningTimingSettings.battleAndAdvance,
    );
    await fixture.capture.attach(fixture.port, enabled: true);
    addTearDown(() async {
      fixture.header?.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture.capture.dispose();
      fixture.port.dispose();
      fixture.settings.dispose();
      fixture.session.dispose();
      fixture.account.dispose();
      fixture.visible.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [fixture.observer],
        home: ValueListenableBuilder<bool>(
          valueListenable: fixture.visible,
          builder: (context, show, _) {
            final game = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => fixture.gameTouches++,
              child: const SizedBox.expand(),
            );
            if (!show) return game;
            return BattleResultWarningOverlay(
              accountSession: fixture.account,
              warningSession: fixture.session,
              gameCaptureController: fixture.capture,
              loadSafetyState: () async => fixture.state,
              safetySettingsController: fixture.settings,
              damageAlertPort: const _Alerts(),
              nativeWarningDialogPort: fixture.native,
              child: Builder(
                builder: (context) {
                  fixture.context = context;
                  return game;
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<_Held> protectHeader(
    WidgetTester tester, {
    bool rawGuard = false,
  }) async {
    header = showGameReminderDialog(
      context: context,
      kind: 'headerResources',
      title: 'header',
      message: '',
      builder: (_, acknowledge) => Dialog(
        child: SizedBox(
          width: 280,
          height: 180,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('actual header body'),
              TextButton(
                key: _headerDone,
                onPressed: acknowledge,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    late TestGesture pointer;
    if (rawGuard) {
      await tester.tap(find.byKey(_headerDone));
      await tester.pump();
      pointer = await tester.startGesture(const Offset(20, 100), pointer: 41);
    } else {
      pointer = await tester.startGesture(
        tester.getCenter(find.text('actual header body')),
        pointer: 41,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
    }
    final held = _Held(pointer);
    addTearDown(held.cancelIfHeld);
    expect(find.byKey(_guard), findsOneWidget);
    return held;
  }

  Future<void> warn(WidgetTester tester) async {
    port.add(
      kcsapiEvent('/kcsapi/api_req_map/next', const {}, sequence: ++sequence),
    );
    await tester.pump();
    await tester.pump();
  }
}

const _sortie = GameState(
  memberId: 1001,
  hasEquipmentInventory: true,
  ships: {
    101: OwnedShip(id: 101, masterId: 1, level: 99, currentHp: 20, maxHp: 20),
    102: OwnedShip(id: 102, masterId: 2, level: 99, currentHp: 2, maxHp: 20),
  },
  fleets: [
    Fleet(id: 1, name: 'test', shipIds: [101, 102]),
  ],
  combatState: CombatState(sortieFleetId: 1, isActive: true),
);

class _Alerts implements BattleDamageAlertPort {
  const _Alerts();
  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {}
}

class _RouteOrderObserver extends NavigatorObserver {
  final events = <(String, Route<dynamic>)>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add(('push', route));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add(('remove', route));
  }
}

class _TemporarilyUnavailableNative implements NativeGameWarningDialogPort {
  int showCount = 0;
  final pending = <int, Completer<NativeGameWarningAction?>>{};
  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) async {
    showCount++;
    if (showCount == 1) {
      throw PlatformException(code: 'native_warning_unavailable');
    }
    final result = Completer<NativeGameWarningAction?>();
    pending[payload['id']! as int] = result;
    return result.future;
  }

  @override
  Future<void> update(Map<String, Object?> payload) async {}
  @override
  Future<void> dismiss(int id) async {
    final result = pending.remove(id);
    if (result != null && !result.isCompleted) result.complete(null);
  }
}

class _CapturePort implements GameCapturePort, GameCaptureContinuityPort {
  final _events = StreamController<CapturedApiEvent>.broadcast(sync: true);
  final _interruptions = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get interruptions => _interruptions.stream;
  void interrupt() => _interruptions.add(null);
  @override
  Stream<CapturedApiEvent> get events => _events.stream;
  void add(CapturedApiEvent event) => _events.add(event);
  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}
  @override
  Future<bool> isSupported() async => true;
  @override
  void dispose() {
    unawaited(_events.close());
    unawaited(_interruptions.close());
  }
}
