import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
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
    for (final action in [
      'acknowledge',
      'mute',
      'covered',
      'reloadGame',
      'reloadFrame',
      'reloadGameFailure',
      'reloadFrameFailure',
    ]) {
      testWidgets(
        'closing $path warning restores the native game via $action',
        (tester) async {
          final account = AccountSession(initialMemberId: 1001);
          final capture = GameCaptureController();
          final port = _CapturePort();
          await capture.attach(port, enabled: true);
          final settings = await SafetySettingsController.load(
            MemorySafetySettingsStore(),
          );
          await settings.setBattleWarningMode(BattleWarningMode.confirm);
          await settings.setAdvanceWarningTimings(
            AdvanceWarningTimingSettings.battleAndAdvance,
          );
          final observer = YahagiGameRouteObserver();
          final navigatorKey = GlobalKey<NavigatorState>();
          final visibility = <bool>[];
          var previewVisible = false;
          var previewClearCount = 0;
          final refresh = Completer<void>();
          var gameReloads = 0;
          var frameReloads = 0;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            settings.dispose();
            capture.dispose();
            port.dispose();
            account.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigatorKey,
              navigatorObservers: [observer],
              home: BattleResultWarningOverlay(
                accountSession: account,
                gameCaptureController: capture,
                loadSafetyState: () async => _activeSortie,
                safetySettingsController: settings,
                damageAlertPort: const _DamageAlerts(),
                onReloadGame: () {
                  gameReloads++;
                  return refresh.future;
                },
                onReloadGameFrame: () {
                  frameReloads++;
                  return refresh.future;
                },
                child: NativeGameSurfaceSlot(
                  routeObserver: observer,
                  onBoundsChanged: (_) async {},
                  onVisibilityChanged: (visible) async =>
                      visibility.add(visible),
                  onBeforePopupRouteHidden: () async => previewVisible = true,
                  onAfterPopupRouteRevealed: () {
                    previewVisible = false;
                    previewClearCount++;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(visibility, [true]);

          port.add(kcsapiEvent(path, const {}));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(visibility, [true, false]);
          expect(previewVisible, isFalse);

          if (action == 'covered') {
            unawaited(
              navigatorKey.currentState!.push<void>(
                RawDialogRoute<void>(
                  pageBuilder: (_, _, _) => const Text('covering dialog'),
                  barrierLabel: 'barrier',
                  barrierColor: Colors.black54,
                ),
              ),
            );
            await tester.pumpAndSettle();
            await settings.setBattleWarningMode(BattleWarningMode.off);
            await tester.pumpAndSettle();
            expect(find.text('covering dialog'), findsOneWidget);
            expect(visibility, [true, false]);
            expect(previewVisible, isFalse);
            navigatorKey.currentState!.pop();
          } else {
            await tester.tap(
              find.byKey(
                Key(
                  action == 'mute'
                      ? 'muteCurrentSortieWarning'
                      : action.startsWith('reloadGame')
                      ? 'advanceWarningReloadGame'
                      : action.startsWith('reloadFrame')
                      ? 'advanceWarningReloadFrame'
                      : 'acknowledgeAdvanceWarning',
                ),
              ),
            );
          }
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(visibility, [true, false, true]);
          expect(previewVisible, isFalse);
          expect(previewClearCount, 1);
          if (action.startsWith('reload')) {
            expect(gameReloads, action.startsWith('reloadGame') ? 1 : 0);
            expect(frameReloads, action.startsWith('reloadFrame') ? 1 : 0);
            // Restoring the game must not wait for the refresh to finish.
            expect(refresh.isCompleted, isFalse);
            if (action.endsWith('Failure')) {
              refresh.completeError(StateError('refresh unavailable'));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(visibility, [true, false, true, false]);
              expect(previewVisible, isFalse);
              await tester.tap(
                find.byKey(const Key('acknowledgeAdvanceWarning')),
              );
              await tester.pumpAndSettle();
              expect(visibility, [true, false, true, false, true]);
              expect(previewClearCount, 2);
            } else {
              refresh.complete();
              await tester.pumpAndSettle();
              expect(visibility, [true, false, true]);
            }
            expect(find.byType(AlertDialog), findsNothing);
            expect(previewVisible, isFalse);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

const _activeSortie = GameState(
  memberId: 1001,
  hasEquipmentInventory: true,
  ships: {
    101: OwnedShip(id: 101, masterId: 1, level: 99, currentHp: 20, maxHp: 20),
    102: OwnedShip(id: 102, masterId: 2, level: 99, currentHp: 2, maxHp: 20),
  },
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [101, 102]),
  ],
  combatState: CombatState(sortieFleetId: 1, isActive: true),
);

final class _DamageAlerts implements BattleDamageAlertPort {
  const _DamageAlerts();

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {}
}

final class _CapturePort implements GameCapturePort {
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
