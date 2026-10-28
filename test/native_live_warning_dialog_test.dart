import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
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

void main() {
  for (final action in NativeGameWarningAction.values) {
    testWidgets(
      '$action keeps the game route visible and runs only its action',
      (tester) async {
        final fixture = await _Fixture.create(tester);
        await fixture.warn(tester);
        expect(fixture.native.shown, hasLength(1));
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byType(ModalBarrier),
          findsNWidgets(fixture.baselineBarriers),
        );
        final payload = fixture.native.shown.single;
        expect(payload['title'], isNotEmpty);
        expect(payload['rows'], isNotEmpty);
        expect(
          (payload['labels'] as Map).keys,
          containsAll(['acknowledge', 'mute', 'reloadGame', 'reloadFrame']),
        );

        fixture.native.pending.single.complete(action);
        await tester.pumpAndSettle();
        expect(
          fixture.reloads,
          action == NativeGameWarningAction.reloadGame ? 1 : 0,
        );
        expect(
          fixture.frameReloads,
          action == NativeGameWarningAction.reloadFrame ? 1 : 0,
        );
        expect(fixture.session.isMuted, action == NativeGameWarningAction.mute);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byType(ModalBarrier),
          findsNWidgets(fixture.baselineBarriers),
        );
        expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
        expect(
          fixture.native.dismissed,
          isEmpty,
          reason: 'the native post-action input guard owns its lifetime',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('new accepted metadata updates the current native presentation', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    await fixture.warn(tester);
    final id = fixture.native.shown.single['id'];
    await fixture.warn(tester);
    expect(fixture.native.shown, hasLength(1));
    expect(fixture.native.updated, hasLength(1));
    expect(fixture.native.updated.single['id'], id);
    expect(find.byType(ModalBarrier), findsNWidgets(fixture.baselineBarriers));
  });

  for (final invalidation in [
    'account',
    'capture',
    'settings',
    'dispose',
    'mode',
  ]) {
    testWidgets(
      '$invalidation cancels native warning and ignores a late action',
      (tester) async {
        final fixture = await _Fixture.create(tester);
        await fixture.warn(tester);
        final id = fixture.native.shown.single['id'];
        switch (invalidation) {
          case 'account':
            fixture.account.selectMember(2002);
          case 'capture':
            fixture.capture.clearCapturedEvents();
          case 'settings':
            await fixture.settings.setBattleWarningMode(BattleWarningMode.off);
          case 'dispose':
            await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          case 'mode':
            fixture.useNative.value = false;
        }
        await tester.pumpAndSettle();
        expect(fixture.native.dismissed, [id]);
        fixture.native.pending.single.complete(
          NativeGameWarningAction.reloadGame,
        );
        await tester.pumpAndSettle();
        expect(fixture.reloads, 0);
        expect(fixture.frameReloads, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('refresh failure reopens native warning with localized error', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    fixture.failFrameReload = true;
    await fixture.warn(tester);
    fixture.native.pending.single.complete(NativeGameWarningAction.reloadFrame);
    await tester.pumpAndSettle();
    expect(fixture.frameReloads, 1);
    expect(fixture.native.shown, hasLength(2));
    expect(
      fixture.native.shown.last['id'],
      isNot(fixture.native.shown.first['id']),
    );
    expect(fixture.native.shown.last['refreshFailed'], isNotEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ModalBarrier), findsNWidgets(fixture.baselineBarriers));
    fixture.native.pending.last.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(fixture.frameReloads, 1);
  });

  testWidgets(
    'temporarily unavailable native dialog retries on the next warning',
    (tester) async {
      final fixture = await _Fixture.create(tester);
      fixture.native.failure = PlatformException(
        code: 'native_warning_unavailable',
      );
      await fixture.warn(tester);
      expect(fixture.native.shown, hasLength(1));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
      await tester.pumpAndSettle();
      fixture.native.failure = null;
      await fixture.warn(tester);
      expect(fixture.native.shown, hasLength(2));
      expect(find.byType(AlertDialog), findsNothing);
      fixture.native.pending.single.complete(
        NativeGameWarningAction.acknowledge,
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('missing native channel uses the protected Flutter fallback', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    fixture.native.failure = MissingPluginException(
      'native warning unavailable',
    );
    await fixture.warn(tester);
    expect(fixture.native.shown, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
    await tester.pumpAndSettle();
    await fixture.warn(tester);
    expect(fixture.native.shown, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('cancelled native window never executes an action', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    await fixture.warn(tester);
    fixture.native.pending.single.complete(null);
    await tester.pumpAndSettle();
    expect(fixture.reloads, 0);
    expect(fixture.frameReloads, 0);
    expect(fixture.session.isMuted, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a no-longer-accepted response releases its presentation slot', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    await fixture.warn(tester);
    fixture.safetyAccepted = false;
    fixture.native.pending.single.complete(NativeGameWarningAction.reloadGame);
    await tester.pumpAndSettle();
    expect(fixture.reloads, 0);
    fixture.safetyAccepted = true;
    await fixture.warn(tester);
    expect(fixture.native.shown, hasLength(2));
  });

  testWidgets('other rendering modes retain the existing Flutter dialog', (
    tester,
  ) async {
    final fixture = await _Fixture.create(tester);
    fixture.useNative.value = false;
    await tester.pumpAndSettle();
    await fixture.warn(tester);
    expect(fixture.native.shown, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

class _Fixture {
  final account = AccountSession(initialMemberId: 1001);
  final capture = GameCaptureController();
  final capturePort = _CapturePort();
  final session = SortieWarningSession()..startSortie();
  final native = _NativeDialog();
  final useNative = ValueNotifier(true);
  late SafetySettingsController settings;
  var reloads = 0;
  var frameReloads = 0;
  var failFrameReload = false;
  var safetyAccepted = true;
  var sequence = 0;
  var baselineBarriers = 0;

  static Future<_Fixture> create(WidgetTester tester) async {
    final fixture = _Fixture();
    fixture.settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await fixture.settings.setAdvanceWarningTimings(
      AdvanceWarningTimingSettings.battleAndAdvance,
    );
    await fixture.capture.attach(fixture.capturePort, enabled: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture.capture.dispose();
      fixture.capturePort.dispose();
      fixture.settings.dispose();
      fixture.session.dispose();
      fixture.account.dispose();
      fixture.useNative.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: fixture.useNative,
          builder: (context, native, child) => BattleResultWarningOverlay(
            accountSession: fixture.account,
            warningSession: fixture.session,
            gameCaptureController: fixture.capture,
            loadSafetyState: () async => _sortie,
            safetySettingsController: fixture.settings,
            safetyEventAccepted: (_, _) => fixture.safetyAccepted,
            damageAlertPort: const _Alerts(),
            nativeWarningDialogPort: native ? fixture.native : null,
            onReloadGame: () async => fixture.reloads++,
            onReloadGameFrame: () async {
              fixture.frameReloads++;
              if (fixture.failFrameReload) {
                throw StateError('test frame failure');
              }
            },
            child: const SizedBox.expand(key: Key('live-game')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    fixture.baselineBarriers = find.byType(ModalBarrier).evaluate().length;
    return fixture;
  }

  Future<void> warn(WidgetTester tester) async {
    capturePort.add(
      kcsapiEvent('/kcsapi/api_req_map/next', const {}, sequence: ++sequence),
    );
    await tester.pumpAndSettle();
  }
}

class _NativeDialog implements NativeGameWarningDialogPort {
  final shown = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];
  final dismissed = <int>[];
  final pending = <Completer<NativeGameWarningAction?>>[];
  Object? failure;

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) {
    shown.add(warning);
    if (failure case final error?) return Future.error(error);
    final completer = Completer<NativeGameWarningAction?>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> update(Map<String, Object?> warning) async =>
      updated.add(warning);

  @override
  Future<void> dismiss(int id) async => dismissed.add(id);
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

class _CapturePort implements GameCapturePort {
  final _events = StreamController<CapturedApiEvent>.broadcast(sync: true);
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
  void dispose() => unawaited(_events.close());
}
