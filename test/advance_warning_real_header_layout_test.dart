import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notice/game_info_notice_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_display_size.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import 'damage_control_briefing_sync_test.dart' show createSortieState;
import 'fixtures/kcsapi_fixtures.dart';

const _damageMessage = '大破舰已携带损管';
const _refreshFailureMessage = '刷新未完成，请核对游戏状态与装备。';
const _damageAlertChannel = MethodChannel(
  'app.yahagi.kancollebrowser/battle_damage_alert',
);

enum _RefreshTarget {
  page(Key('advanceWarningReloadGame')),
  frame(Key('advanceWarningReloadFrame'));

  const _RefreshTarget(this.key);

  final Key key;
}

void main() {
  for (final uiSize in <UiDisplaySize>[
    UiDisplaySize.normal,
    UiDisplaySize.compact,
  ]) {
    testWidgets(
      'real $uiSize header reserves notice height before its first notice and after toolbar changes',
      (tester) async {
        final fixture = await _RealHeaderFixture.create(tester, uiSize: uiSize);

        expect(find.byType(CompactResourceBar), findsOneWidget);
        expect(find.byKey(const Key('quest-completion-drawer')), findsNothing);
        for (final toolbarVisible in <bool>[false, true, false]) {
          if (toolbarVisible) {
            fixture.toolbar.reveal();
          } else {
            fixture.toolbar.collapse();
          }
          await _pumpHeader(tester);
          expect(
            tester.getSize(fixture.slot).height,
            closeTo(topHeaderHeight(uiSize) - 1, 0.01),
            reason: 'An empty real header must already fit its 34px notice.',
          );
          final shown = QuestCompletionDrawerHost.showDamageControlNotice(
            fixture.slotContext(tester),
            _damageMessage,
          );
          await tester.pump();
          expect(await shown, isTrue, reason: 'toolbar=$toolbarVisible');
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(_damageMessage), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.getSize(_capsule()).height, 34);
          QuestCompletionDrawerHost.removeDamageControlNotice(
            fixture.slotContext(tester),
          );
          await _pumpHeader(tester);
          expect(find.text(_damageMessage), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );

    for (final scenario
        in <({int equipmentId, AdvanceWarningDisplayMode mode})>[
          (equipmentId: 43, mode: AdvanceWarningDisplayMode.alwaysConfirm),
          (equipmentId: 1, mode: AdvanceWarningDisplayMode.smart),
        ]) {
      for (final postBattle in <bool>[false, true]) {
        testWidgets(
          'real $uiSize compact warning gear=${scenario.equipmentId} mode=${scenario.mode} postBattle=$postBattle retains layered actions',
          (tester) async {
            final fixture = await _RealHeaderFixture.create(
              tester,
              uiSize: uiSize,
              equipmentId: scenario.equipmentId,
              displayMode: scenario.mode,
              postBattle: postBattle,
            );
            await fixture.start(tester);
            if (postBattle) await fixture.finishBattle(tester);

            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.text(_damageMessage), findsNothing);
            final surface = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Material && widget.type == MaterialType.card,
              ),
            );
            expect(tester.getSize(surface).width, closeTo(520, 0.01));
            expect(tester.getSize(surface).height, lessThanOrEqualTo(340));
            final warningShip = fixture.state.state.ships[1002]!;
            final name = fixture.state.state.masterForShip(warningShip)!.name;
            final status = scenario.equipmentId == 43
                ? find.textContaining('应急修理女神 ×1')
                : find.text('未携带损管');
            expect(status, findsOneWidget);
            expect(
              tester
                  .getCenter(
                    find.descendant(
                      of: find.byType(AlertDialog),
                      matching: find.text(name),
                    ),
                  )
                  .dy,
              closeTo(tester.getCenter(status).dy, 3),
            );
            for (final key in <Key>[
              const Key('advanceWarningReloadGame'),
              const Key('advanceWarningReloadFrame'),
              const Key('muteCurrentSortieWarning'),
              const Key('acknowledgeAdvanceWarning'),
            ]) {
              expect(find.byKey(key).hitTestable(), findsOneWidget);
              expect(
                tester.getSize(find.byKey(key)).height,
                greaterThanOrEqualTo(44),
              );
            }
            expect(
              tester
                  .getBottomLeft(
                    find.byKey(const Key('advanceWarningReloadGame')),
                  )
                  .dy,
              lessThan(
                tester
                    .getTopLeft(
                      find.byKey(const Key('muteCurrentSortieWarning')),
                    )
                    .dy,
              ),
            );
            await tester.tap(
              find.byKey(const Key('acknowledgeAdvanceWarning')),
            );
            await _pumpHeader(tester);
            expect(find.byType(AlertDialog), findsNothing);
            expect(fixture.battle.warningSession.isMuted, isFalse);
            expect(fixture.state.lastError, isNull);
            expect(fixture.battle.lastError, isNull);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final equipmentId in <int>[42, 43]) {
      for (final postBattle in <bool>[false, true]) {
        testWidgets(
          'real $uiSize header first smart notice gear=$equipmentId postBattle=$postBattle stays gold for ten seconds',
          (tester) async {
            final fixture = await _RealHeaderFixture.create(
              tester,
              uiSize: uiSize,
              equipmentId: equipmentId,
              postBattle: postBattle,
            );
            expect(find.byType(CompactResourceBar), findsOneWidget);
            expect(
              find.byKey(const Key('quest-completion-drawer')),
              findsNothing,
            );
            expect(find.byType(AlertDialog), findsNothing);
            expect(fixture.notices.notices, isEmpty);

            await fixture.start(tester);
            expect(fixture.battle.isDamageControlStateTrusted, isTrue);
            if (postBattle) {
              expect(find.text(_damageMessage), findsNothing);
              await fixture.finishBattle(tester);
            }

            expect(find.byType(AlertDialog), findsNothing);
            expect(find.text(_damageMessage), findsOneWidget);
            expect(fixture.state.state.ships[1002]!.currentHp, 20);
            expect(
              fixture.state.state.slotItems[501]!.masterSlotItemId,
              equipmentId,
            );
            final capsule = _capsule();
            expect(tester.getSize(capsule).height, 34);
            final decoration =
                tester.widget<Container>(capsule).decoration! as BoxDecoration;
            expect(
              (decoration.border! as Border).top.color,
              const Color(0xffd4a85f).withValues(alpha: 0.35),
            );
            await tester.pump(const Duration(seconds: 9));
            expect(find.text(_damageMessage), findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
            await tester.pump(const Duration(seconds: 2));
            await _pumpHeader(tester);
            expect(find.text(_damageMessage), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(fixture.battle.warningSession.isMuted, isFalse);
            expect(fixture.state.lastError, isNull);
            expect(fixture.battle.lastError, isNull);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final target in _RefreshTarget.values) {
      testWidgets(
        'real $uiSize $target browser refresh closes while pending and preserves later danger',
        (tester) async {
          final browserPort = _RefreshBrowserPort();
          final fixture = await _RealHeaderFixture.create(
            tester,
            uiSize: uiSize,
            equipmentId: 1,
            browserPort: browserPort,
          );
          await fixture.start(tester);
          expect(find.text('未携带损管'), findsOneWidget);
          final stateBefore = fixture.state.state;
          final generationBefore = fixture.battle.warningSession.generation;

          await tester.tap(find.byKey(target.key));
          await tester.pump();

          _expectPendingRefresh(browserPort, target);
          expect(find.byType(AlertDialog), findsNothing);
          expect(fixture.state.state, same(stateBefore));
          expect(fixture.battle.warningSession.generation, generationBefore);
          expect(fixture.battle.warningSession.isMuted, isFalse);
          if (target == _RefreshTarget.page) {
            browserPort.page.complete();
          } else {
            browserPort.frame.complete(GameFrameReloadResult.reloaded);
          }
          await _pumpHeader(tester);

          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text(_refreshFailureMessage), findsNothing);
          expect(fixture.state.state, same(stateBefore));
          await fixture.advance(tester);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('未携带损管'), findsOneWidget);
          expect(find.text(_damageMessage), findsNothing);
          expect(fixture.battle.warningSession.isMuted, isFalse);
          expect(fixture.state.state.slotItems[501]?.masterSlotItemId, 1);
          expect(fixture.state.lastError, isNull);
          expect(fixture.battle.lastError, isNull);
          expect(tester.takeException(), isNull);
        },
      );

      for (final result
          in target == _RefreshTarget.page
              ? <GameFrameReloadResult?>[null]
              : <GameFrameReloadResult?>[
                  GameFrameReloadResult.gameFrameNotFound,
                  GameFrameReloadResult.htmlWrapNotFound,
                  GameFrameReloadResult.blocked,
                  GameFrameReloadResult.unsupported,
                  null,
                ]) {
        testWidgets(
          'real $uiSize $target browser failure ${result ?? 'exception'} restores confirmable danger',
          (tester) async {
            final browserPort = _RefreshBrowserPort();
            final fixture = await _RealHeaderFixture.create(
              tester,
              uiSize: uiSize,
              equipmentId: 1,
              browserPort: browserPort,
            );
            await fixture.start(tester);
            final stateBefore = fixture.state.state;
            final generationBefore = fixture.battle.warningSession.generation;
            await tester.tap(find.byKey(target.key));
            await tester.pump();

            _expectPendingRefresh(browserPort, target);
            expect(find.byType(AlertDialog), findsNothing);
            expect(fixture.battle.warningSession.isMuted, isFalse);
            final alertsBeforeFailure = fixture.damageAlerts.length;
            browserPort.fail(target, result: result);
            await _pumpHeader(tester);

            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.text(_refreshFailureMessage), findsOneWidget);
            expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
            expect(find.text('未携带损管'), findsOneWidget);
            expect(find.text(_damageMessage), findsNothing);
            expect(fixture.state.state, same(stateBefore));
            expect(fixture.state.state.slotItems[501]?.masterSlotItemId, 1);
            expect(fixture.battle.warningSession.generation, generationBefore);
            expect(fixture.battle.warningSession.isMuted, isFalse);
            expect(fixture.damageAlerts, hasLength(alertsBeforeFailure));
            for (final key in <Key>[
              const Key('advanceWarningReloadGame'),
              const Key('advanceWarningReloadFrame'),
              const Key('muteCurrentSortieWarning'),
              const Key('acknowledgeAdvanceWarning'),
            ]) {
              expect(find.byKey(key).hitTestable(), findsOneWidget);
            }
            await tester.tap(
              find.byKey(const Key('acknowledgeAdvanceWarning')),
            );
            await _pumpHeader(tester);
            expect(find.byType(AlertDialog), findsNothing);
            expect(fixture.battle.warningSession.isMuted, isFalse);
            await fixture.advance(tester);
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.text('未携带损管'), findsOneWidget);
            expect(find.text(_refreshFailureMessage), findsNothing);
            expect(fixture.state.lastError, isNull);
            expect(fixture.battle.lastError, isNull);
            expect(tester.takeException(), isNull);
          },
        );
      }

      for (final boundary in <String>['account', 'newer warning']) {
        testWidgets(
          'real $uiSize $target browser failure after $boundary cannot revive an obsolete warning',
          (tester) async {
            final browserPort = _RefreshBrowserPort();
            final fixture = await _RealHeaderFixture.create(
              tester,
              uiSize: uiSize,
              equipmentId: 1,
              browserPort: browserPort,
            );
            await fixture.start(tester);
            await tester.tap(find.byKey(target.key));
            await tester.pump();
            _expectPendingRefresh(browserPort, target);
            expect(find.byType(AlertDialog), findsNothing);

            Element? newerDialog;
            if (boundary == 'account') {
              fixture.account.selectMember(2002);
              await _pumpHeader(tester);
              expect(fixture.state.state.ships, isEmpty);
            } else {
              await fixture.advance(tester);
              expect(find.text('未携带损管'), findsOneWidget);
              newerDialog = tester.element(find.byType(AlertDialog));
            }
            final stateBeforeFailure = fixture.state.state;
            final generationBeforeFailure =
                fixture.battle.warningSession.generation;
            final alertsBeforeFailure = fixture.damageAlerts.length;
            browserPort.fail(target, result: GameFrameReloadResult.blocked);
            await _pumpHeader(tester);

            expect(
              find.byType(AlertDialog),
              newerDialog == null ? findsNothing : findsOneWidget,
            );
            if (newerDialog != null) {
              expect(
                tester.element(find.byType(AlertDialog)),
                same(newerDialog),
              );
              expect(find.text('未携带损管'), findsOneWidget);
            }
            expect(find.text(_refreshFailureMessage), findsNothing);
            expect(find.text(_damageMessage), findsNothing);
            expect(fixture.state.state, same(stateBeforeFailure));
            expect(
              fixture.battle.warningSession.generation,
              generationBeforeFailure,
            );
            expect(fixture.battle.warningSession.isMuted, isFalse);
            expect(fixture.damageAlerts, hasLength(alertsBeforeFailure));
            expect(fixture.state.lastError, isNull);
            expect(fixture.battle.lastError, isNull);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'real $uiSize header shares capsule geometry across quest improvement development and damage control',
      (tester) async {
        final fixture = await _RealHeaderFixture.create(tester, uiSize: uiSize);
        final geometries = <({Size contentSize, TextStyle? style})>[];
        for (final kind in <String>[
          'quest',
          'improvement',
          'development',
          'damage',
        ]) {
          final context = fixture.slotContext(tester);
          switch (kind) {
            case 'quest':
              QuestCompletionDrawerHost.show(context, _damageMessage);
            case 'improvement':
            case 'development':
              fixture.gameInfo.postNotice(
                message: _damageMessage,
                tone: TopNoticeTone.success,
              );
            case 'damage':
              final shown = QuestCompletionDrawerHost.showDamageControlNotice(
                context,
                _damageMessage,
              );
              await tester.pump();
              expect(await shown, isTrue);
          }
          await _pumpHeader(tester);
          final capsule = _capsule();
          final size = tester.getSize(capsule);
          final text = tester.widget<Text>(find.text(_damageMessage));
          final icons = find.descendant(
            of: capsule,
            matching: find.byType(Icon),
          );
          expect(icons, kind == 'damage' ? findsNothing : findsOneWidget);
          expect(size.height, 34, reason: kind);
          expect(text.style?.fontSize, 13, reason: kind);
          expect(
            tester.widget<Container>(capsule).padding,
            const EdgeInsets.symmetric(horizontal: 10),
            reason: kind,
          );
          final switcher = tester.widget<AnimatedSwitcher>(
            find
                .ancestor(of: capsule, matching: find.byType(AnimatedSwitcher))
                .first,
          );
          expect(
            switcher.duration,
            const Duration(milliseconds: 240),
            reason: kind,
          );
          expect(
            switcher.reverseDuration,
            const Duration(milliseconds: 200),
            reason: kind,
          );
          geometries.add((
            contentSize: Size(
              size.width - (kind == 'damage' ? 0 : 24),
              size.height,
            ),
            style: text.style,
          ));
          final decoration =
              tester.widget<Container>(capsule).decoration! as BoxDecoration;
          expect(
            decoration.borderRadius,
            BorderRadius.circular(8),
            reason: kind,
          );
          QuestCompletionDrawerHost.hide(context);
          QuestCompletionDrawerHost.removeDamageControlNotice(context);
          await _pumpHeader(tester);
        }
        for (final geometry in geometries.skip(1)) {
          expect(geometry.contentSize, geometries.first.contentSize);
          expect(geometry.style, geometries.first.style);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Finder _capsule() => find
    .ancestor(of: find.text(_damageMessage), matching: find.byType(Container))
    .first;

Future<void> _pumpHeader(WidgetTester tester) async {
  await tester.pump();
  if (find.byKey(const Key('game-safety-input-guard')).evaluate().isNotEmpty) {
    // A refreshed warning waits for the real post-action touch guard to hand
    // off. Header animation time alone does not advance its quiet interval.
    await tester.pump(GameSurfaceInputGuardRoute.protectionDuration);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void _expectPendingRefresh(_RefreshBrowserPort port, _RefreshTarget target) {
  expect(
    find.byKey(const Key('game-safety-input-guard')),
    findsOneWidget,
    reason:
        'Refresh keeps the game covered during the post-action touch guard.',
  );
  expect(port.page.isCompleted, isFalse);
  expect(port.frame.isCompleted, isFalse);
  expect(port.pageCalls, target == _RefreshTarget.page ? 1 : 0);
  expect(port.frameCalls, target == _RefreshTarget.frame ? 1 : 0);
}

final class _RealHeaderFixture {
  _RealHeaderFixture({
    required this.account,
    required this.state,
    required this.battle,
    required this.pipeline,
    required this.capture,
    required this.port,
    required this.toolbar,
    required this.notices,
    required this.gameInfo,
    required this.postBattle,
    required this.damageAlerts,
  });

  final AccountSession account;
  final GameStateController state;
  final BattleController battle;
  final GameApiEventPipeline pipeline;
  final GameCaptureController capture;
  final _CapturePort port;
  final GameToolbarController toolbar;
  final TopNoticeController notices;
  final GameInfoNoticeController gameInfo;
  final bool postBattle;
  final List<MethodCall> damageAlerts;
  int _sequence = 0;

  Finder get slot => find.byType(QuestCompletionHeaderSlot);

  BuildContext slotContext(WidgetTester tester) => tester.element(slot);

  static Future<_RealHeaderFixture> create(
    WidgetTester tester, {
    required UiDisplaySize uiSize,
    int equipmentId = 43,
    AdvanceWarningDisplayMode displayMode = AdvanceWarningDisplayMode.smart,
    bool postBattle = false,
    GameBrowserPort? browserPort,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousTimerSetting = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(
      () => GameStateController.disableTimerForTest = previousTimerSetting,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 850);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final damageAlerts = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_damageAlertChannel, (call) async {
          damageAlerts.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_damageAlertChannel, null);
    });

    final account = AccountSession(initialMemberId: 1001);
    final state = GameStateController(
      accountSession: account,
      initialState: createSortieState(
        ships: <OwnedShip>[
          const OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 100,
            maxHp: 100,
          ),
          OwnedShip(
            id: 1002,
            masterId: 102,
            level: 50,
            currentHp: postBattle ? 100 : 20,
            maxHp: 100,
            slotIds: const <int>[501],
          ),
        ],
        slotItems: <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 501, masterSlotItemId: equipmentId),
        ],
      ).copyWith(memberId: 1001, hasEquipmentInventory: true),
    );
    await state.initialize();
    final safety = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await safety.setAdvanceWarningDisplayMode(displayMode);
    await safety.setAdvanceWarningTimings(
      postBattle
          ? AdvanceWarningTimingSettings.battleOnly
          : AdvanceWarningTimingSettings.advanceOnly,
    );
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await layout.setLocaleCode('zh');
    await layout.setUiDisplaySize(uiSize);
    final notices = TopNoticeController();
    final gameInfo = GameInfoNoticeController(
      stateProvider: () => state.state,
      layoutSettingsController: layout,
      topNoticeController: notices,
      accountSession: account,
    );
    final battle = BattleController(
      accountSession: account,
      gameState: () => state.state,
      waitForGameState: () => state.idle,
      onFriendlyHpUpdated: state.applyFriendlyBattleHp,
      onDamageControlConsumed: state.applyDamageControlConsumption,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[account, state, battle, gameInfo],
      settleGameState: () async {
        await state.idle;
        await battle.idle;
        await state.idle;
      },
    );
    final capture = GameCaptureController(onAcceptedEvent: pipeline.add);
    final port = _CapturePort();
    await capture.attach(port, enabled: true);
    final toolbar = GameToolbarController();
    final browser = GameBrowserController(port: browserPort);
    final status = PrototypeStatusController();
    final network = NetworkSettingsController(
      store: SharedPreferencesNetworkSettingsStore(),
    );
    final bypass = GadgetBypassController(
      store: SharedPreferencesGadgetBypassStore(),
      port: MethodChannelGadgetBypassPort(),
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    final mode = await CaptureModeController.load(
      SharedPreferencesCaptureModeStore(),
    );
    final audio = await GameAudioController.load(
      SharedPreferencesGameAudioStore(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpHeader(tester);
      capture.dispose();
      port.dispose();
      gameInfo.dispose();
      for (final notifier in <ChangeNotifier>[
        battle,
        state,
        toolbar,
        browser,
        status,
        network,
        bypass,
        safety,
        display,
        mode,
        audio,
        notices,
        layout,
        account,
      ]) {
        notifier.dispose();
      }
    });
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: network,
        gadgetBypassController: bypass,
        safetySettingsController: safety,
        displayModeController: display,
        controller: status,
        browserController: browser,
        captureModeController: mode,
        gameCaptureController: capture,
        gameApiEventPipeline: pipeline,
        gameStateController: state,
        battleController: battle,
        audioController: audio,
        toolbarController: toolbar,
        headerNoticeController: notices,
        gameInfoNoticeController: gameInfo,
        gameSurface: const SizedBox.expand(
          key: Key('real-header-game-surface'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    return _RealHeaderFixture(
      account: account,
      state: state,
      battle: battle,
      pipeline: pipeline,
      capture: capture,
      port: port,
      toolbar: toolbar,
      notices: notices,
      gameInfo: gameInfo,
      postBattle: postBattle,
      damageAlerts: damageAlerts,
    );
  }

  Future<void> start(WidgetTester tester) => publish(
    tester,
    '/kcsapi/api_req_map/start',
    const <String, Object?>{
      'api_maparea_id': 1,
      'api_mapinfo_no': 1,
      'api_no': 1,
      'api_next': 1,
    },
    requestParams: const <String, Object?>{'api_deck_id': '1'},
  );

  Future<void> advance(WidgetTester tester) =>
      publish(tester, '/kcsapi/api_req_map/next', const <String, Object?>{
        'api_maparea_id': 1,
        'api_mapinfo_no': 1,
        'api_no': 2,
        'api_next': 1,
      });

  Future<void> finishBattle(WidgetTester tester) async {
    await publish(tester, '/kcsapi/api_req_sortie/battle', <String, Object?>{
      'api_deck_id': 1,
      'api_f_nowhps': const <int>[-1, 100, 100],
      'api_f_maxhps': const <int>[-1, 100, 100],
      'api_e_nowhps': const <int>[-1, 20],
      'api_e_maxhps': const <int>[-1, 20],
      'api_ship_ke': const <int>[-1, 501],
      'api_hougeki1': <String, Object?>{
        'api_at_eflag': const <int>[1],
        'api_at_list': const <int>[0],
        'api_df_list': const <Object?>[
          <int>[1],
        ],
        'api_damage': const <Object?>[
          <num>[80],
        ],
      },
    });
    await publish(
      tester,
      '/kcsapi/api_req_sortie/battleresult',
      const <String, Object?>{'api_win_rank': 'A', 'api_mvp': 1},
    );
  }

  Future<void> publish(
    WidgetTester tester,
    String path,
    Object? data, {
    Map<String, Object?> requestParams = const <String, Object?>{},
  }) async {
    port.add(
      kcsapiEvent(
        path,
        data,
        sequence: ++_sequence,
        requestParams: requestParams,
      ),
    );
    await pipeline.idle;
    await _pumpHeader(tester);
  }
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

final class _RefreshBrowserPort implements GameBrowserPort {
  final page = Completer<void>();
  final frame = Completer<GameFrameReloadResult>();
  int pageCalls = 0;
  int frameCalls = 0;

  void fail(_RefreshTarget target, {GameFrameReloadResult? result}) {
    if (target == _RefreshTarget.page) {
      page.completeError(StateError('full-page refresh unavailable'));
    } else if (result == null) {
      frame.completeError(StateError('game-frame refresh unavailable'));
    } else {
      frame.complete(result);
    }
  }

  @override
  Future<void> reload() async {
    pageCalls++;
    await page.future;
  }

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async {
    frameCalls++;
    return frame.future;
  }

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> showLocalHome() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> fitGameScreen() async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}
}
