import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

enum _HeaderAvailability { visible, hidden, removed, native }

void main() {
  const nativeChannel = MethodChannel(
    'app.yahagi.kancollebrowser/game_fullscreen',
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, (_) async => false);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, null);
  });
  testWidgets(
    'replacing a shared warning session clears a capsule without build exceptions',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      fixture.advance();
      fixture.requests.single.complete(_state(equipped: true));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      final overlayState = tester.state(
        find.byType(BattleResultWarningOverlay),
      );
      final replacement = SortieWarningSession()..startSortie();
      fixture.replacementSessions.add(replacement);

      fixture.activeSession.value = replacement;
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(BattleResultWarningOverlay)),
        same(overlayState),
      );
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(replacement.isMuted, isFalse);
      expect(fixture.alerts.alerts, hasLength(1));
    },
  );

  testWidgets(
    'unmounting only the overlay clears its capsule while the host stays mounted',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      fixture.advance();
      fixture.requests.single.complete(_state(equipped: true));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      final hostState = tester.state(find.byType(QuestCompletionDrawerHost));
      final headerState = tester.state(find.byType(QuestCompletionHeaderSlot));

      fixture.overlayMounted.value = false;
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(BattleResultWarningOverlay), findsNothing);
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(
        tester.state(find.byType(QuestCompletionDrawerHost)),
        same(hostState),
      );
      expect(
        tester.state(find.byType(QuestCompletionHeaderSlot)),
        same(headerState),
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'replacing smart settings with default confirmation preserves the overlay without build exceptions',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      fixture.advance();
      fixture.requests.single.complete(_state(equipped: true));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final overlayState = tester.state(
        find.byType(BattleResultWarningOverlay),
      );
      final hostState = tester.state(find.byType(QuestCompletionDrawerHost));
      final replacement = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      fixture.replacementSettings.add(replacement);
      expect(
        replacement.advanceWarningDisplayMode,
        AdvanceWarningDisplayMode.alwaysConfirm,
      );

      fixture.activeSettings.value = replacement;
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(BattleResultWarningOverlay)),
        same(overlayState),
      );
      expect(
        tester.state(find.byType(QuestCompletionDrawerHost)),
        same(hostState),
      );
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('携带：应急修理要员 ×1'), findsOneWidget);
      expect(fixture.session.isMuted, isFalse);
    },
  );

  for (final unavailable in <_HeaderAvailability>[
    _HeaderAvailability.hidden,
    _HeaderAvailability.removed,
    _HeaderAvailability.native,
  ]) {
    testWidgets(
      'a confirmed capsule falls back when its header becomes $unavailable',
      (tester) async {
        final fixture = await _QueuedFixture.mount(tester);
        addTearDown(() => fixture.dispose(tester));
        fixture.advance();
        fixture.requests.single.complete(_state(equipped: true));
        await tester.pumpAndSettle();
        expect(find.text('大破舰已携带损管'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, hasLength(1));

        fixture.headerAvailability.value = unavailable;
        await tester.pumpAndSettle();

        expect(find.text('大破舰已携带损管'), findsNothing);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('携带：应急修理要员 ×1'), findsOneWidget);
        expect(fixture.session.isMuted, isFalse);
        expect(fixture.session.isActive, isTrue);
        await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.session.isMuted, isFalse);
      },
    );
  }

  testWidgets(
    '64 shuffled stale inventory results cannot replace the latest missing warning',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      for (var request = 0; request < 64; request++) {
        fixture.advance();
      }
      expect(fixture.requests, hasLength(64));
      fixture.requests.last.complete(_state(equipped: false));
      await tester.pumpAndSettle();
      expect(find.text('未携带损管'), findsOneWidget);
      final staleIndices = List<int>.generate(63, (index) => index)
        ..shuffle(Random(0x4243));
      for (final index in staleIndices) {
        fixture.requests[index].complete(_state(equipped: true));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('未携带损管'), findsOneWidget);
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
      expect(fixture.session.isMuted, isFalse);
    },
  );

  testWidgets(
    'a latest unknown result replaces a capsule while 64 stale results settle',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      fixture.advance();
      fixture.requests.single.complete(_state(equipped: true));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));

      for (var request = 0; request < 65; request++) {
        fixture.advance();
      }
      fixture.trusted = false;
      fixture.requests.last.complete(_state(equipped: true));
      await tester.pumpAndSettle();
      for (var index = fixture.requests.length - 2; index > 0; index--) {
        fixture.requests[index].complete(_state(equipped: true));
      }
      await tester.pumpAndSettle();

      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(2));
      expect(fixture.session.isMuted, isFalse);
    },
  );

  testWidgets(
    '32 account switches discard pending equipped results and warn for the new account',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      for (var scenario = 0; scenario < 32; scenario++) {
        final previousMember = fixture.account.current.memberId;
        fixture.advance();
        final stale = fixture.requests.last;
        fixture.account.selectMember(previousMember + 1);
        stale.complete(_state(equipped: true, memberId: previousMember));
        await tester.pumpAndSettle();
        expect(find.text('大破舰已携带损管'), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, hasLength(scenario));

        fixture.advance();
        fixture.requests.last.complete(
          _state(equipped: false, memberId: previousMember + 1),
        );
        await tester.pumpAndSettle();
        expect(find.text('未携带损管'), findsOneWidget);
        expect(fixture.alerts.alerts, hasLength(scenario + 1));
        await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
        await tester.pumpAndSettle();
        expect(fixture.session.isMuted, isFalse);
      }
    },
  );

  testWidgets(
    '32 capture interruptions discard pending capsules and permit the fresh warning',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      for (var scenario = 0; scenario < 32; scenario++) {
        fixture.advance();
        final stale = fixture.requests.last;
        fixture.capture.clearCapturedEvents();
        stale.complete(_state(equipped: true));
        await tester.pumpAndSettle();
        expect(find.text('大破舰已携带损管'), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, hasLength(scenario));

        fixture.advance();
        fixture.requests.last.complete(_state(equipped: false));
        await tester.pumpAndSettle();
        expect(find.text('未携带损管'), findsOneWidget);
        expect(fixture.alerts.alerts, hasLength(scenario + 1));
        await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    '64 obsolete danger results cannot restore a warning after the latest healthy snapshot',
    (tester) async {
      final fixture = await _QueuedFixture.mount(tester);
      addTearDown(() => fixture.dispose(tester));
      fixture.advance();
      fixture.requests.single.complete(_state(equipped: true));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      for (var request = 0; request < 65; request++) {
        fixture.advance();
      }
      fixture.requests.last.complete(_state(equipped: false, heavy: false));
      await tester.pumpAndSettle();
      for (var index = 1; index < fixture.requests.length - 1; index++) {
        fixture.requests[index].complete(_state(equipped: false));
      }
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
    },
  );
}

GameState _state({
  required bool equipped,
  int memberId = 1001,
  bool heavy = true,
}) => GameState(
  memberId: memberId,
  hasPortData: true,
  hasEquipmentInventory: true,
  combatState: const CombatState(isActive: true, sortieFleetId: 1),
  ships: <int, OwnedShip>{
    1: const OwnedShip(
      id: 1,
      masterId: 1,
      level: 50,
      currentHp: 100,
      maxHp: 100,
    ),
    2: OwnedShip(
      id: 2,
      masterId: 2,
      level: 50,
      currentHp: heavy ? 20 : 100,
      maxHp: 100,
      slotIds: equipped ? const <int>[501] : const <int>[],
    ),
  },
  slotItems: equipped
      ? const <int, OwnedSlotItem>{
          501: OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
        }
      : const <int, OwnedSlotItem>{},
  fleets: const <Fleet>[
    Fleet(id: 1, name: 'Main', shipIds: <int>[1, 2]),
  ],
);

final class _QueuedFixture {
  final account = AccountSession(initialMemberId: 1001);
  final session = SortieWarningSession();
  final capture = GameCaptureController();
  final port = _CapturePort();
  final alerts = _DamageAlerts();
  final requests = <Completer<GameState>>[];
  final headerAvailability = ValueNotifier<_HeaderAvailability>(
    _HeaderAvailability.visible,
  );
  late final SafetySettingsController settings;
  late final ValueNotifier<SafetySettingsController> activeSettings;
  final replacementSettings = <SafetySettingsController>[];
  final overlayMounted = ValueNotifier<bool>(true);
  late final ValueNotifier<SortieWarningSession> activeSession;
  final replacementSessions = <SortieWarningSession>[];
  var trusted = true;
  var _sequence = 0;

  static Future<_QueuedFixture> mount(WidgetTester tester) async {
    final fixture = _QueuedFixture();
    fixture.settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await fixture.settings.setAdvanceWarningDisplayMode(
      AdvanceWarningDisplayMode.smart,
    );
    fixture.activeSettings = ValueNotifier(fixture.settings);
    fixture.activeSession = ValueNotifier(fixture.session);
    await fixture.capture.attach(fixture.port, enabled: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<_HeaderAvailability>(
          valueListenable: fixture.headerAvailability,
          builder: (context, availability, child) => QuestCompletionDrawerHost(
            fullscreen: availability == _HeaderAvailability.native,
            nativeQuestOverlay: availability == _HeaderAvailability.native,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 44,
                  child: availability == _HeaderAvailability.removed
                      ? const SizedBox.shrink()
                      : Offstage(
                          offstage: availability == _HeaderAvailability.hidden,
                          child: const QuestCompletionHeaderSlot(
                            child: SizedBox.expand(),
                          ),
                        ),
                ),
                Expanded(child: child!),
              ],
            ),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: fixture.overlayMounted,
            builder: (context, mounted, child) =>
                mounted ? child! : const SizedBox.shrink(),
            child: ValueListenableBuilder<SafetySettingsController>(
              valueListenable: fixture.activeSettings,
              builder: (context, settings, child) =>
                  ValueListenableBuilder<SortieWarningSession>(
                    valueListenable: fixture.activeSession,
                    builder: (context, warningSession, child) =>
                        BattleResultWarningOverlay(
                          key: const Key('queuedWarningOverlay'),
                          accountSession: fixture.account,
                          warningSession: warningSession,
                          gameCaptureController: fixture.capture,
                          safetySettingsController: settings,
                          damageAlertPort: fixture.alerts,
                          damageControlStateTrusted: () => fixture.trusted,
                          loadSafetyState: () {
                            final request = Completer<GameState>();
                            fixture.requests.add(request);
                            return request.future;
                          },
                          child: const SizedBox.expand(),
                        ),
                  ),
            ),
          ),
        ),
      ),
    );
    return fixture;
  }

  void advance() => port.add(
    kcsapiEvent(
      '/kcsapi/api_req_map/next',
      const <String, Object?>{},
      sequence: ++_sequence,
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    capture.dispose();
    port.dispose();
    settings.dispose();
    for (final controller in replacementSettings) {
      controller.dispose();
    }
    activeSettings.dispose();
    overlayMounted.dispose();
    activeSession.dispose();
    for (final warningSession in replacementSessions) {
      warningSession.dispose();
    }
    headerAvailability.dispose();
    session.dispose();
    account.dispose();
  }
}

final class _DamageAlerts implements BattleDamageAlertPort {
  final alerts = <BattleDamageAlertSeverity>[];

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async =>
      alerts.add(severity);
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
