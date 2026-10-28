import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
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
  for (final path in [
    '/kcsapi/api_req_map/next',
    '/kcsapi/api_req_sortie/battleresult',
  ]) {
    for (final button in [
      'acknowledgeAdvanceWarning',
      'muteCurrentSortieWarning',
      'advanceWarningReloadGame',
      'advanceWarningReloadFrame',
    ]) {
      testWidgets(
        '$path $button absorbs follow-up taps before restoring game',
        (tester) async {
          final fixture = await _Fixture.create();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            fixture.dispose();
          });
          await fixture.pump(tester);
          fixture.port.add(kcsapiEvent(path, const {}));
          await tester.pumpAndSettle();
          final position = tester.getCenter(find.byKey(Key(button)));

          await tester.tapAt(position);
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byType(AlertDialog), findsNothing);
          expect(fixture.reloads, button == 'advanceWarningReloadGame' ? 1 : 0);
          expect(
            fixture.frameReloads,
            button == 'advanceWarningReloadFrame' ? 1 : 0,
          );
          expect(fixture.session.isMuted, button == 'muteCurrentSortieWarning');
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tapAt(position);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tapAt(position);
          await tester.pump();

          expect(
            fixture.gameTouches,
            0,
            reason: 'follow-up taps must not advance the game',
          );
          await tester.pumpAndSettle();
          await tester.tapAt(position);
          await tester.pump();
          expect(
            fixture.gameTouches,
            1,
            reason: 'normal game input must recover after the guard',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('disposing a closing warning removes its temporary input guard', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    final visible = ValueNotifier<bool>(true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      visible.dispose();
      fixture.dispose();
    });
    await fixture.pump(tester, visible: visible);
    fixture.port.add(kcsapiEvent('/kcsapi/api_req_map/next', const {}));
    await tester.pumpAndSettle();
    final position = tester.getCenter(
      find.byKey(const Key('acknowledgeAdvanceWarning')),
    );
    await tester.tapAt(position);
    await tester.pump();
    visible.value = false;
    await tester.pumpAndSettle();
    await tester.tapAt(position);
    await tester.pump();
    expect(fixture.gameTouches, 1);
    expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  final account = AccountSession(initialMemberId: 1001);
  final capture = GameCaptureController();
  final port = _CapturePort();
  final session = SortieWarningSession()..startSortie();
  late SafetySettingsController settings;
  var gameTouches = 0;
  var reloads = 0;
  var frameReloads = 0;

  static Future<_Fixture> create() async {
    final fixture = _Fixture();
    fixture.settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await fixture.settings.setAdvanceWarningTimings(
      AdvanceWarningTimingSettings.battleAndAdvance,
    );
    await fixture.capture.attach(fixture.port, enabled: true);
    return fixture;
  }

  Future<void> pump(WidgetTester tester, {ValueNotifier<bool>? visible}) =>
      tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible ?? const AlwaysStoppedAnimation(true),
            builder: (context, show, child) {
              final game = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => gameTouches++,
                child: const SizedBox.expand(),
              );
              if (!show) return game;
              return BattleResultWarningOverlay(
                accountSession: account,
                warningSession: session,
                gameCaptureController: capture,
                loadSafetyState: () async => _sortie,
                safetySettingsController: settings,
                damageAlertPort: const _Alerts(),
                onReloadGame: () async => reloads++,
                onReloadGameFrame: () async => frameReloads++,
                child: game,
              );
            },
          ),
        ),
      );

  void dispose() {
    capture.dispose();
    port.dispose();
    settings.dispose();
    session.dispose();
    account.dispose();
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
