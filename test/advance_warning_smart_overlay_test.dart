import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
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
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _refreshKeys = <Key>[
  Key('advanceWarningReloadGame'),
  Key('advanceWarningReloadFrame'),
];
const _refreshFailureMessage = '刷新未完成，请核对游戏状态与装备。';

void main() {
  for (final stage in ['advance', 'battle']) {
    for (final scenario in [
      'personnel',
      'goddess',
      'two-items',
      'missing',
      'mixed',
      'unknown',
      'inventory-missing',
      'always',
      'disabled',
      'unavailable',
      'healthy',
      'flagship',
      'escaped',
    ]) {
      testWidgets('native fullscreen $stage $scenario safety matrix', (
        tester,
      ) async {
        const channel = MethodChannel(
          'app.yahagi.kancollebrowser/game_fullscreen',
        );
        final shows = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'damageControlNotice') {
              if (call.arguments['message'] != '') shows.add(call);
              return scenario != 'unavailable';
            }
            if (call.method == 'damageControlNoticeVisible') return true;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final fixture = await _Fixture.create(
          tester,
          smart: scenario != 'always',
          nativeFullscreen: true,
          timings: AdvanceWarningTimingSettings.battleAndAdvance,
          equipment: switch (scenario) {
            'personnel' => [42],
            'two-items' => [42, 43],
            'missing' => [],
            _ => [43],
          },
        );
        if (scenario == 'mixed') fixture.state = _state([43], mixed: true);
        if (scenario == 'unknown') fixture.trusted = false;
        if (scenario == 'inventory-missing') {
          fixture.state = _state([43], inventory: false);
        }
        if (scenario == 'disabled') {
          await fixture.settings.setBattleWarningMode(BattleWarningMode.off);
        }
        if (scenario == 'healthy') {
          fixture.state = fixture.state.copyWith(
            ships: {
              ...fixture.state.ships,
              2: const OwnedShip(
                id: 2,
                masterId: 2,
                level: 99,
                currentHp: 6,
                maxHp: 20,
                slotIds: [100],
              ),
            },
          );
        }
        if (scenario == 'flagship') {
          fixture.state = fixture.state.copyWith(
            fleets: const [
              Fleet(id: 1, name: 'fleet', shipIds: [2, 1]),
            ],
          );
        }
        if (scenario == 'escaped') {
          fixture.state = fixture.state.copyWith(
            combatState: fixture.state.combatState.copyWith(
              escapedShipIds: {2},
            ),
          );
        }
        await fixture.advance(tester, postBattle: stage == 'battle');
        final notice = ['personnel', 'goddess', 'two-items'].contains(scenario);
        final noWarning = [
          'disabled',
          'healthy',
          'flagship',
          'escaped',
        ].contains(scenario);
        expect(
          find.byType(AlertDialog),
          notice || noWarning ? findsNothing : findsOneWidget,
        );
        expect(shows.length, notice || scenario == 'unavailable' ? 1 : 0);
        expect(find.text('大破舰已携带损管'), findsNothing);
        if (notice) {
          await tester.pump(const Duration(seconds: 9));
          expect(find.byType(AlertDialog), findsNothing);
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        }
      });
    }
  }

  testWidgets(
    'native smart keeps one damage control and warns after the last is consumed',
    (tester) async {
      const channel = MethodChannel(
        'app.yahagi.kancollebrowser/game_fullscreen',
      );
      final messages = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'damageControlNotice') {
          messages.add(call.arguments['message'] as String);
        }
        return call.method == 'questNotice' ? null : true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final fixture = await _Fixture.create(
        tester,
        smart: true,
        nativeFullscreen: true,
        equipment: [43, 43],
      );
      for (var remaining = 2; remaining >= 0; remaining--) {
        fixture.state = _state(List.filled(remaining, 43));
        await fixture.advance(tester);
        expect(
          find.byType(AlertDialog),
          remaining == 0 ? findsOneWidget : findsNothing,
        );
      }
      expect(messages.where((message) => message.isNotEmpty), hasLength(2));
      await tester.tap(find.text('此次出击不再提醒'));
      await tester.pumpAndSettle();
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsNothing);
      fixture.session.startSortie();
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets(
    'default always confirms equipped ships and exposes both refresh actions',
    (tester) async {
      final fixture = await _Fixture.create(tester);
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(find.byKey(const Key('advanceWarningReloadGame')), findsOneWidget);
      expect(
        find.byKey(const Key('advanceWarningReloadFrame')),
        findsOneWidget,
      );
    },
  );

  for (final equipment in <List<int>>[
    [42],
    [43],
    [42, 43],
    [42, 42],
    [43, 43],
  ]) {
    testWidgets('smart uses a ten-second header notice for $equipment', (
      tester,
    ) async {
      final fixture = await _Fixture.create(
        tester,
        smart: true,
        equipment: equipment,
      );
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      expect(fixture.alerts.alerts, [BattleDamageAlertSeverity.heavy]);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsNothing);
      await fixture.advance(tester);
      await tester.tap(find.text('大破舰已携带损管'));
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsNothing);
      expect(fixture.session.isMuted, isFalse);
      await fixture.advance(tester);
      expect(find.text('大破舰已携带损管'), findsOneWidget);
    });
  }

  for (final equipment in <List<int>>[
    [42, 42],
    [43, 43],
    [42, 43],
  ]) {
    testWidgets('smart becomes modal only after $equipment reaches zero', (
      tester,
    ) async {
      final fixture = await _Fixture.create(
        tester,
        smart: true,
        equipment: equipment,
      );
      for (var remaining = 2; remaining >= 0; remaining--) {
        fixture.state = _state(equipment.take(remaining).toList());
        await fixture.advance(tester);
        expect(
          find.byType(AlertDialog),
          remaining == 0 ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('大破舰已携带损管'),
          remaining == 0 ? findsNothing : findsOneWidget,
        );
      }
      expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
      await tester.tap(find.text('确认了解'));
      await tester.pumpAndSettle();
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }

  testWidgets(
    'unknown, inventory loss and a second unprotected ship never use a notice',
    (tester) async {
      final fixture = await _Fixture.create(tester, smart: true);
      for (final risk in ['untrusted', 'inventory', 'mixed']) {
        fixture.trusted = risk != 'untrusted';
        fixture.state = _state(
          [43],
          inventory: risk != 'inventory',
          mixed: risk == 'mixed',
        );
        await fixture.advance(tester);
        expect(find.byType(AlertDialog), findsOneWidget, reason: risk);
        expect(find.text('大破舰已携带损管'), findsNothing);
        await tester.tap(find.text('确认了解'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('no header host falls back to a confirmation', (tester) async {
    final fixture = await _Fixture.create(tester, smart: true, host: false);
    await fixture.advance(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'confirmation and mute are distinct red and yellow capsule buttons',
    (tester) async {
      final fixture = await _Fixture.create(tester);
      await fixture.advance(tester);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认了解'),
      );
      final mute = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '此次出击不再提醒'),
      );
      expect(confirm.style?.shape?.resolve({}), isA<StadiumBorder>());
      expect(mute.style?.shape?.resolve({}), isA<StadiumBorder>());
      expect(
        confirm.style?.backgroundColor?.resolve({}),
        const Color(0xffff7f88),
      );
      expect(mute.style?.backgroundColor?.resolve({}), const Color(0xffe4c267));
    },
  );

  testWidgets('mute still applies only to the current sortie', (tester) async {
    final fixture = await _Fixture.create(tester, smart: true, equipment: []);
    await fixture.advance(tester);
    await tester.tap(find.text('此次出击不再提醒'));
    await tester.pumpAndSettle();
    await fixture.advance(tester);
    expect(find.byType(AlertDialog), findsNothing);
    fixture.session.startSortie();
    await fixture.advance(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  for (final refreshKey in _refreshKeys) {
    testWidgets(
      '$refreshKey refresh closes immediately while pending without muting or consuming equipment',
      (tester) async {
        final pending = Completer<void>();
        var reloads = 0;
        var frameReloads = 0;
        final fixture = await _Fixture.create(
          tester,
          onReloadGame: () {
            reloads++;
            return pending.future;
          },
          onReloadGameFrame: () {
            frameReloads++;
            return pending.future;
          },
        );
        await fixture.advance(tester);
        final beforeRefresh = fixture.state;
        final sortieGeneration = fixture.session.generation;
        expect(reloads, 0);
        expect(frameReloads, 0);

        await tester.tap(find.byKey(refreshKey));
        await tester.pump();

        expect(pending.isCompleted, isFalse);
        expect(find.byType(AlertDialog), findsNothing);
        expect(reloads, refreshKey == _refreshKeys.first ? 1 : 0);
        expect(frameReloads, refreshKey == _refreshKeys.last ? 1 : 0);
        expect(fixture.session.isMuted, isFalse);
        expect(fixture.session.generation, sortieGeneration);
        expect(fixture.state, same(beforeRefresh));
        expect(fixture.state.slotItems[100]?.masterSlotItemId, 43);

        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(_refreshFailureMessage), findsNothing);
        await fixture.advance(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(fixture.session.isMuted, isFalse);
        expect(fixture.state, same(beforeRefresh));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$refreshKey current refresh failure restores danger with an error and stays confirmable',
      (tester) async {
        final pending = Completer<void>();
        final fixture = await _Fixture.create(
          tester,
          smart: true,
          equipment: const [],
          onReloadGame: () => pending.future,
          onReloadGameFrame: () => pending.future,
        );
        await fixture.advance(tester);
        await tester.tap(find.byKey(refreshKey));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.session.isMuted, isFalse);

        pending.completeError(StateError('refresh unavailable'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
        expect(find.text(_refreshFailureMessage), findsOneWidget);
        expect(find.text('大破舰已携带损管'), findsNothing);
        expect(fixture.session.isMuted, isFalse);
        expect(fixture.state.slotItems, isEmpty);
        await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await fixture.advance(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(_refreshFailureMessage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$refreshKey refresh rejects repeated and saved old callbacks without closing a newer dialog',
      (tester) async {
        final pending = Completer<void>();
        var refreshes = 0;
        Future<void> refresh() {
          refreshes++;
          return pending.future;
        }

        final fixture = await _Fixture.create(
          tester,
          onReloadGame: refresh,
          onReloadGameFrame: refresh,
        );
        await fixture.advance(tester);
        final oldActions = <Key, VoidCallback>{
          for (final key in _refreshKeys) key: _refreshAction(tester, key),
        };

        oldActions[refreshKey]!();
        oldActions[refreshKey]!();
        for (final action in oldActions.values) {
          action();
        }
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(find.byType(AlertDialog), findsNothing);

        await fixture.advance(tester);
        final newerDialog = tester.element(find.byType(AlertDialog));
        for (final action in oldActions.values) {
          action();
        }
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(tester.element(find.byType(AlertDialog)), same(newerDialog));
        pending.complete();
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(AlertDialog)), same(newerDialog));
        expect(find.text(_refreshFailureMessage), findsNothing);
        expect(fixture.session.isMuted, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    for (final interruption in <String>[
      'account',
      'capture gap',
      'new sortie',
      'warning off and on',
      'mute',
      'receipt rejected',
      'newer dialog',
      'newer dialog acknowledged',
      'disposed overlay',
    ]) {
      testWidgets(
        '$refreshKey late refresh failure after $interruption cannot revive or replace a warning',
        (tester) async {
          final pending = Completer<void>();
          final fixture = await _Fixture.create(
            tester,
            onReloadGame: () => pending.future,
            onReloadGameFrame: () => pending.future,
          );
          await fixture.advance(tester);
          await tester.tap(find.byKey(refreshKey));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          Element? newerDialog;
          switch (interruption) {
            case 'account':
              fixture.account.selectMember(2002);
            case 'capture gap':
              fixture.capture.clearCapturedEvents();
            case 'new sortie':
              fixture.session.startSortie();
            case 'warning off and on':
              await fixture.settings.setBattleWarningMode(
                BattleWarningMode.off,
              );
              await fixture.settings.setBattleWarningMode(
                BattleWarningMode.confirm,
              );
            case 'mute':
              fixture.session.muteCurrentSortie();
            case 'receipt rejected':
              fixture.safetyAccepted = false;
            case 'newer dialog':
              fixture.state = _state([43], mixed: true);
              await fixture.advance(tester);
              newerDialog = tester.element(find.byType(AlertDialog));
            case 'newer dialog acknowledged':
              await fixture.advance(tester);
              await tester.tap(
                find.byKey(const Key('acknowledgeAdvanceWarning')),
              );
            case 'disposed overlay':
              await tester.pumpWidget(const SizedBox.shrink());
          }
          await tester.pumpAndSettle();
          final alertsBeforeFailure = fixture.alerts.alerts.length;

          pending.completeError(StateError('stale refresh failure'));
          await tester.pumpAndSettle();

          expect(
            find.byType(AlertDialog),
            newerDialog == null ? findsNothing : findsOneWidget,
          );
          if (newerDialog != null) {
            expect(tester.element(find.byType(AlertDialog)), same(newerDialog));
            expect(find.text('夕立改二'), findsOneWidget);
            expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
          }
          expect(find.text(_refreshFailureMessage), findsNothing);
          expect(fixture.alerts.alerts, hasLength(alertsBeforeFailure));
          expect(fixture.session.isMuted, interruption == 'mute');
          expect(fixture.state.slotItems[100]?.masterSlotItemId, 43);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('old refresh callbacks cannot act after account changes', (
    tester,
  ) async {
    var reloads = 0;
    final fixture = await _Fixture.create(
      tester,
      onReloadGame: () async {
        reloads++;
      },
    );
    await fixture.advance(tester);
    final action = tester
        .widget<OutlinedButton>(
          find.byKey(const Key('advanceWarningReloadGame')),
        )
        .onPressed!;
    fixture.account.selectMember(2002);
    action();
    await tester.pumpAndSettle();
    expect(reloads, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'candidate updates do not auto-refresh and the current manual action closes the dialog',
    (tester) async {
      var reloads = 0;
      final fixture = await _Fixture.create(
        tester,
        onReloadGame: () async {
          reloads++;
        },
      );
      await fixture.advance(tester);
      final manualAction = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('advanceWarningReloadGame')),
          )
          .onPressed!;
      fixture.state = _state([43], mixed: true);
      await fixture.advance(tester);
      expect(reloads, 0);
      manualAction();
      await tester.pumpAndSettle();
      expect(reloads, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.session.isMuted, isFalse);
    },
  );

  testWidgets('disabled top notices and native fullscreen fail closed', (
    tester,
  ) async {
    final fixture = await _Fixture.create(
      tester,
      smart: true,
      noticeEnabled: false,
    );
    await fixture.advance(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('大破舰已携带损管'), findsNothing);
  });

  testWidgets('native fullscreen cannot exempt a ship without native support', (
    tester,
  ) async {
    const channel = MethodChannel('app.yahagi.kancollebrowser/game_fullscreen');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      throw MissingPluginException();
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final fixture = await _Fixture.create(
      tester,
      smart: true,
      nativeFullscreen: true,
    );
    await fixture.advance(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('大破舰已携带损管'), findsNothing);
  });

  testWidgets(
    'switching to always upgrades a notice; an open danger modal is never downgraded',
    (tester) async {
      final fixture = await _Fixture.create(tester, smart: true);
      await fixture.advance(tester);
      await fixture.settings.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.alwaysConfirm,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await fixture.settings.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.smart,
      );
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('大破舰已携带损管'), findsNothing);
      await fixture.settings.setBattleWarningMode(BattleWarningMode.off);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('dialog controls fit at 320px with large text in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await _Fixture.create(
        tester,
        locale: locale,
        textScale: 1.4,
      );
      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('advanceWarningReloadGame')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

VoidCallback _refreshAction(WidgetTester tester, Key key) =>
    tester.widget<OutlinedButton>(find.byKey(key)).onPressed!;

GameState _state(
  List<int> equipment, {
  bool inventory = true,
  bool mixed = false,
}) => GameState(
  memberId: 1001,
  hasEquipmentInventory: inventory,
  masterShips: const {
    1: MasterShip(id: 1, name: '旗舰', shipTypeId: 2),
    2: MasterShip(id: 2, name: '时雨改三', shipTypeId: 2),
    3: MasterShip(id: 3, name: '夕立改二', shipTypeId: 2),
  },
  ships: {
    1: const OwnedShip(id: 1, masterId: 1, level: 99, currentHp: 20, maxHp: 20),
    2: OwnedShip(
      id: 2,
      masterId: 2,
      level: 99,
      currentHp: 5,
      maxHp: 20,
      slotIds: [
        for (var index = 0; index < equipment.length; index++) 100 + index,
      ],
    ),
    if (mixed)
      3: const OwnedShip(
        id: 3,
        masterId: 3,
        level: 99,
        currentHp: 5,
        maxHp: 20,
      ),
  },
  slotItems: {
    for (var index = 0; index < equipment.length; index++)
      100 + index: OwnedSlotItem(
        id: 100 + index,
        masterSlotItemId: equipment[index],
        level: 0,
        proficiency: 0,
      ),
  },
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [1, 2, if (mixed) 3]),
  ],
  combatState: const CombatState(sortieFleetId: 1, isActive: true),
);

class _Fixture {
  _Fixture(this.account, this.capture, this.port, this.settings);
  final AccountSession account;
  final GameCaptureController capture;
  final _CapturePort port;
  final SafetySettingsController settings;
  final session = SortieWarningSession();
  final notices = TopNoticeController();
  final alerts = _AlertPort();
  GameState state = _state([43]);
  bool trusted = true;
  bool safetyAccepted = true;
  int sequence = 0;

  static Future<_Fixture> create(
    WidgetTester tester, {
    bool smart = false,
    bool host = true,
    List<int> equipment = const [43],
    Future<void> Function()? onReloadGame,
    Future<void> Function()? onReloadGameFrame,
    bool noticeEnabled = true,
    bool nativeFullscreen = false,
    AdvanceWarningTimingSettings timings =
        AdvanceWarningTimingSettings.advanceOnly,
    Locale locale = const Locale('zh'),
    double textScale = 1,
  }) async {
    final account = AccountSession(initialMemberId: 1001);
    final capture = GameCaptureController();
    final port = _CapturePort();
    await capture.attach(port, enabled: true);
    final settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await settings.setAdvanceWarningTimings(timings);
    if (smart) {
      await settings.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.smart,
      );
    }
    final fixture = _Fixture(account, capture, port, settings)
      ..state = _state(equipment);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture.notices.dispose();
      fixture.session.dispose();
      settings.dispose();
      capture.dispose();
      port.dispose();
      account.dispose();
    });
    final overlay = BattleResultWarningOverlay(
      accountSession: account,
      gameCaptureController: capture,
      loadSafetyState: () async => fixture.state,
      damageControlStateTrusted: () => fixture.trusted,
      safetyEventAccepted: (_, _) => fixture.safetyAccepted,
      safetySettingsController: settings,
      warningSession: fixture.session,
      damageAlertPort: fixture.alerts,
      onReloadGame: onReloadGame,
      onReloadGameFrame: onReloadGameFrame,
      damageControlNoticeEnabled: () => noticeEnabled,
      child: const SizedBox.expand(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: host
            ? QuestCompletionDrawerHost(
                controller: fixture.notices,
                fullscreen: nativeFullscreen,
                nativeQuestOverlay: nativeFullscreen,
                child: Column(
                  children: [
                    if (!nativeFullscreen)
                      const SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: QuestCompletionHeaderSlot(child: Text('顶栏')),
                      ),
                    Expanded(child: overlay),
                  ],
                ),
              )
            : overlay,
      ),
    );
    return fixture;
  }

  Future<void> advance(WidgetTester tester, {bool postBattle = false}) async {
    port.add(
      kcsapiEvent(
        postBattle
            ? '/kcsapi/api_req_sortie/battleresult'
            : '/kcsapi/api_req_map/next',
        const {},
        sequence: ++sequence,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
  }
}

class _AlertPort implements BattleDamageAlertPort {
  final alerts = <BattleDamageAlertSeverity>[];
  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async =>
      alerts.add(severity);
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
