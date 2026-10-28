import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/capture/sortie_warning_session.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_display_size.dart';

import 'fixtures/kcsapi_fixtures.dart';

enum _Stage { result, advance }

enum _Risk { equipped, exhausted, unknown, mixed }

enum _HeaderAvailability { visible, hidden, narrow, native }

enum _Presentation { quiet, gold, modal }

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
  for (final uiSize in <UiDisplaySize>[
    UiDisplaySize.normal,
    UiDisplaySize.compact,
  ]) {
    for (final timing in AdvanceWarningTimingSettings.values) {
      for (final equipment in <List<int>>[
        <int>[42],
        <int>[43],
        <int>[42, 43],
        <int>[42, 42],
        <int>[43, 43],
      ]) {
        for (final display in AdvanceWarningDisplayMode.values) {
          testWidgets(
            '$uiSize $timing $equipment $display survives repeated header lifecycles',
            (tester) async {
              final fixture = await _HeaderFixture.create(
                tester,
                uiSize: uiSize,
                timing: timing,
                display: display,
                equipment: equipment,
              );
              final identity = _WidgetIdentity(tester);
              for (var round = 0; round < 3; round++) {
                fixture.risk = _Risk.equipped;
                await fixture.configure(
                  tester,
                  uiSize: uiSize,
                  resources: round.isOdd,
                );
                fixture.expectGeometry(tester);
                for (final stage in _Stage.values) {
                  final expected = _oracle(
                    timing: timing,
                    stage: stage,
                    display: display,
                    risk: _Risk.equipped,
                  );
                  await fixture.fire(tester, stage);
                  fixture.expectPresentation(tester, expected);
                  identity.expectUnchanged(tester);
                  if (expected == _Presentation.quiet) continue;

                  if (expected == _Presentation.gold && round.isEven) {
                    final alertCount = fixture.alerts.values.length;
                    await tester.pump(const Duration(seconds: 9));
                    fixture.expectPresentation(tester, _Presentation.gold);
                    await tester.pump(const Duration(seconds: 2));
                    await tester.pumpAndSettle();
                    fixture.expectPresentation(tester, _Presentation.quiet);
                    expect(fixture.alerts.values, hasLength(alertCount));
                  } else {
                    await fixture.dismiss(tester);
                    fixture.expectPresentation(tester, _Presentation.quiet);
                  }

                  await fixture.fire(tester, stage);
                  fixture.expectPresentation(tester, expected);
                  final alertCount = fixture.alerts.values.length;
                  for (var change = 0; change < 4; change++) {
                    await fixture.configure(
                      tester,
                      uiSize: change.isEven
                          ? UiDisplaySize.compact
                          : UiDisplaySize.normal,
                      resources: change.isOdd,
                      toolbarVisible: change < 2,
                    );
                    fixture.expectGeometry(tester);
                    fixture.expectPresentation(tester, expected);
                    identity.expectUnchanged(tester);
                    expect(fixture.alerts.values, hasLength(alertCount));
                  }

                  fixture.risk = <_Risk>[
                    _Risk.exhausted,
                    _Risk.unknown,
                    _Risk.mixed,
                  ][round];
                  await fixture.fire(tester, stage);
                  fixture.expectPresentation(
                    tester,
                    _oracle(
                      timing: timing,
                      stage: stage,
                      display: display,
                      risk: fixture.risk,
                    ),
                  );
                  expect(
                    find.text(
                      fixture.risk == _Risk.unknown
                          ? '损管状态未知，请核对游戏内装备'
                          : '未携带损管',
                    ),
                    findsOneWidget,
                  );
                  if (fixture.risk == _Risk.mixed) {
                    expect(find.text('时雨'), findsOneWidget);
                    expect(find.text('夕立'), findsOneWidget);
                  }
                  final modalAlertCount = fixture.alerts.values.length;
                  fixture.risk = _Risk.equipped;
                  await fixture.fire(tester, stage);
                  fixture.expectPresentation(tester, _Presentation.modal);
                  expect(fixture.alerts.values, hasLength(modalAlertCount));
                  await fixture.dismiss(tester);

                  await fixture.fire(tester, stage);
                  fixture.expectPresentation(tester, expected);
                  await fixture.dismiss(tester);
                  identity.expectUnchanged(tester);
                }
              }
              expect(
                fixture.alerts.values,
                everyElement(BattleDamageAlertSeverity.heavy),
              );
            },
          );
        }
      }
    }

    for (final availability in <_HeaderAvailability>[
      _HeaderAvailability.hidden,
      _HeaderAvailability.narrow,
      _HeaderAvailability.native,
    ]) {
      testWidgets('$uiSize $availability retains conservative fallback', (
        tester,
      ) async {
        final fixture = await _HeaderFixture.create(
          tester,
          uiSize: uiSize,
          timing: AdvanceWarningTimingSettings.battleAndAdvance,
          display: AdvanceWarningDisplayMode.smart,
          equipment: <int>[42, 43],
        );
        final identity = _WidgetIdentity(tester);
        for (var round = 0; round < 3; round++) {
          final stage = round.isEven ? _Stage.advance : _Stage.result;
          await fixture.configure(tester, availability: availability);
          await fixture.fire(tester, stage);
          fixture.expectPresentation(
            tester,
            _oracle(
              timing: AdvanceWarningTimingSettings.battleAndAdvance,
              stage: stage,
              display: AdvanceWarningDisplayMode.smart,
              risk: _Risk.equipped,
              availability: availability,
            ),
          );
          await fixture.dismiss(tester);
          await fixture.configure(
            tester,
            availability: _HeaderAvailability.visible,
          );
          await fixture.fire(tester, stage);
          fixture.expectPresentation(tester, _Presentation.gold);
          await fixture.configure(tester, availability: availability);
          fixture.expectPresentation(tester, _Presentation.modal);
          await fixture.configure(
            tester,
            availability: _HeaderAvailability.visible,
          );
          fixture.expectPresentation(tester, _Presentation.modal);
          await fixture.dismiss(tester);
          identity.expectUnchanged(tester);
        }
      });
    }
  }
}

_Presentation _oracle({
  required AdvanceWarningTimingSettings timing,
  required _Stage stage,
  required AdvanceWarningDisplayMode display,
  required _Risk risk,
  _HeaderAvailability availability = _HeaderAvailability.visible,
}) {
  final enabled = stage == _Stage.result
      ? timing.postBattle
      : timing.afterAdvance;
  if (!enabled) return _Presentation.quiet;
  return display == AdvanceWarningDisplayMode.smart &&
          risk == _Risk.equipped &&
          availability == _HeaderAvailability.visible
      ? _Presentation.gold
      : _Presentation.modal;
}

class _HeaderFixture {
  _HeaderFixture(this.settings, this.layoutSettings, this.equipment);

  final SafetySettingsController settings;
  final LayoutSettingsController layoutSettings;
  final List<int> equipment;
  final account = AccountSession(initialMemberId: 1001);
  final capture = GameCaptureController();
  final session = SortieWarningSession();
  final port = _CapturePort();
  final alerts = _DamageAlerts();
  final layout = ValueNotifier(const _HeaderLayout());
  var risk = _Risk.equipped;
  var sequence = 0;

  static Future<_HeaderFixture> create(
    WidgetTester tester, {
    required UiDisplaySize uiSize,
    required AdvanceWarningTimingSettings timing,
    required AdvanceWarningDisplayMode display,
    required List<int> equipment,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await settings.setAdvanceWarningTimings(timing);
    await settings.setAdvanceWarningDisplayMode(display);
    final layoutSettings = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await layoutSettings.setUiDisplaySize(uiSize);
    final fixture = _HeaderFixture(settings, layoutSettings, equipment);
    await fixture.capture.attach(fixture.port, enabled: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture.capture.dispose();
      fixture.port.dispose();
      fixture.session.dispose();
      fixture.account.dispose();
      fixture.layout.dispose();
      layoutSettings.dispose();
      settings.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            fixture.layout,
            layoutSettings,
          ]),
          builder: (context, child) {
            final layout = fixture.layout.value;
            final headerHeight = topHeaderHeight(layoutSettings.uiDisplaySize);
            return QuestCompletionDrawerHost(
              fullscreen: layout.availability == _HeaderAvailability.native,
              nativeQuestOverlay:
                  layout.availability == _HeaderAvailability.native,
              child: Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: layout.availability == _HeaderAvailability.narrow
                          ? 130
                          : 800,
                      child: Container(
                        key: const Key('stressHeader'),
                        height: headerHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide()),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            const SizedBox(width: 84, child: Text('ヤハギ')),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: headerHeight,
                                child: Offstage(
                                  offstage:
                                      layout.availability ==
                                      _HeaderAvailability.hidden,
                                  child: QuestCompletionHeaderSlot(
                                    toolbarVisible: layout.toolbarVisible,
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: <Widget>[
                                        AnimatedOpacity(
                                          opacity: layout.toolbarVisible
                                              ? 0
                                              : 1,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: IgnorePointer(
                                            ignoring: layout.toolbarVisible,
                                            child: layout.resources
                                                ? CompactResourceBar(
                                                    state: const GameState(),
                                                    settingsController:
                                                        layoutSettings,
                                                  )
                                                : const SizedBox.shrink(
                                                    key: Key(
                                                      'stressEmptyContext',
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child!),
                ],
              ),
            );
          },
          child: BattleResultWarningOverlay(
            accountSession: fixture.account,
            gameCaptureController: fixture.capture,
            safetySettingsController: settings,
            warningSession: fixture.session,
            damageAlertPort: fixture.alerts,
            damageControlStateTrusted: () => fixture.risk != _Risk.unknown,
            loadSafetyState: () async =>
                _state(fixture.equipment, fixture.risk),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    return fixture;
  }

  Future<void> configure(
    WidgetTester tester, {
    UiDisplaySize? uiSize,
    bool resources = false,
    bool toolbarVisible = false,
    _HeaderAvailability availability = _HeaderAvailability.visible,
  }) async {
    if (uiSize != null) await layoutSettings.setUiDisplaySize(uiSize);
    layout.value = _HeaderLayout(
      resources: resources,
      toolbarVisible: toolbarVisible,
      availability: availability,
    );
    await tester.pumpAndSettle();
  }

  Future<void> fire(WidgetTester tester, _Stage stage) async {
    port.add(
      kcsapiEvent(
        stage == _Stage.result
            ? '/kcsapi/api_req_sortie/battleresult'
            : '/kcsapi/api_req_map/next',
        const <String, Object?>{},
        sequence: ++sequence,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  void expectGeometry(WidgetTester tester) {
    final compact = layoutSettings.uiDisplaySize == UiDisplaySize.compact;
    expect(
      tester.getSize(find.byKey(const Key('stressHeader'))).height,
      compact ? 36 : 44,
    );
    expect(
      tester.getSize(find.byType(QuestCompletionHeaderSlot)).height,
      compact ? 35 : 43,
    );
    if (layout.value.resources) {
      expect(
        tester.getSize(find.byType(CompactResourceBar)).height,
        compact ? 26 : 30,
      );
    } else {
      expect(
        tester.getSize(find.byKey(const Key('stressEmptyContext'))).height,
        0,
      );
    }
  }

  void expectPresentation(WidgetTester tester, _Presentation expected) {
    expect(
      find.byType(AlertDialog),
      expected == _Presentation.modal ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('大破舰已携带损管'),
      expected == _Presentation.gold ? findsOneWidget : findsNothing,
    );
    if (expected == _Presentation.gold) {
      expect(
        tester.getSize(find.byKey(const Key('header-notice-scroll'))).height,
        34,
      );
    }
    expect(session.isMuted, isFalse);
    expect(tester.takeException(), isNull);
  }

  Future<void> dismiss(WidgetTester tester) async {
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('acknowledgeAdvanceWarning')));
    } else {
      await tester.tap(find.text('大破舰已携带损管'));
    }
    await tester.pumpAndSettle();
  }
}

class _HeaderLayout {
  const _HeaderLayout({
    this.resources = false,
    this.toolbarVisible = false,
    this.availability = _HeaderAvailability.visible,
  });

  final bool resources;
  final bool toolbarVisible;
  final _HeaderAvailability availability;
}

class _WidgetIdentity {
  _WidgetIdentity(WidgetTester tester)
    : host = tester.state(find.byType(QuestCompletionDrawerHost)),
      slot = tester.state(find.byType(QuestCompletionHeaderSlot)),
      overlay = tester.state(find.byType(BattleResultWarningOverlay));

  final Object host;
  final Object slot;
  final Object overlay;

  void expectUnchanged(WidgetTester tester) {
    expect(tester.state(find.byType(QuestCompletionDrawerHost)), same(host));
    expect(
      tester.state(find.byType(QuestCompletionHeaderSlot, skipOffstage: false)),
      same(slot),
    );
    expect(
      tester.state(find.byType(BattleResultWarningOverlay)),
      same(overlay),
    );
  }
}

GameState _state(List<int> initialEquipment, _Risk risk) {
  final equipment = risk == _Risk.exhausted ? <int>[] : initialEquipment;
  return GameState(
    memberId: 1001,
    hasPortData: true,
    hasEquipmentInventory: true,
    masterShips: const <int, MasterShip>{
      1: MasterShip(id: 1, name: '旗舰', shipTypeId: 2),
      2: MasterShip(id: 2, name: '时雨', shipTypeId: 2),
      3: MasterShip(id: 3, name: '夕立', shipTypeId: 2),
    },
    ships: <int, OwnedShip>{
      1: const OwnedShip(
        id: 1,
        masterId: 1,
        level: 99,
        currentHp: 20,
        maxHp: 20,
      ),
      2: OwnedShip(
        id: 2,
        masterId: 2,
        level: 99,
        currentHp: 5,
        maxHp: 20,
        slotIds: <int>[if (equipment.isNotEmpty) 100],
        extraSlotId: equipment.length > 1 ? 101 : -1,
      ),
      if (risk == _Risk.mixed)
        3: const OwnedShip(
          id: 3,
          masterId: 3,
          level: 99,
          currentHp: 5,
          maxHp: 20,
        ),
    },
    slotItems: <int, OwnedSlotItem>{
      for (var index = 0; index < equipment.length; index++)
        100 + index: OwnedSlotItem(
          instanceId: 100 + index,
          masterSlotItemId: equipment[index],
        ),
    },
    fleets: <Fleet>[
      Fleet(
        id: 1,
        name: '第一舰队',
        shipIds: <int>[1, 2, if (risk == _Risk.mixed) 3],
      ),
    ],
    combatState: const CombatState(isActive: true, sortieFleetId: 1),
  );
}

class _DamageAlerts implements BattleDamageAlertPort {
  final values = <BattleDamageAlertSeverity>[];

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async =>
      values.add(severity);
}

class _CapturePort implements GameCapturePort {
  final controller = StreamController<CapturedApiEvent>.broadcast(sync: true);

  @override
  Stream<CapturedApiEvent> get events => controller.stream;

  void add(CapturedApiEvent event) => controller.add(event);

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => true;

  @override
  void dispose() => unawaited(controller.close());
}
