import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/detailed_battle_panel.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/battle/prophet_hp_bar.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

import 'damage_control_briefing_sync_test.dart'
    show createSortieState, apiEvent, mapData, lethalBattle;

const _longName = 'Samuel B.Roberts Mk.II';

OwnedShip _owned(int id, {List<int> slots = const [], int extra = -1}) =>
    OwnedShip(
      id: id,
      masterId: 101,
      level: 50,
      currentHp: 30,
      maxHp: 30,
      slotIds: slots,
      extraSlotId: extra,
    );

BattleShipSnapshot _ship(
  int? id, {
  String name = '熊野改',
  BattleSide side = BattleSide.friend,
  BattleFleetRole role = BattleFleetRole.main,
  List<int> equipment = const [42, 43],
  List<int> used = const [],
  List<int> usedThisBattle = const [],
}) => BattleShipSnapshot(
  masterId: 101,
  ownedShipId: id,
  name: name,
  side: side,
  fleetRole: role,
  position: 0,
  initialHp: 30,
  maxHp: 30,
  currentHp: 30,
  equipmentMasterIds: equipment,
  usedDamageControlItemIds: used,
  damageControlUsedThisBattle: usedThisBattle,
);

LiveBattle _battle({
  BattleDisplayStage stage = BattleDisplayStage.battle,
  List<BattleShipSnapshot>? main,
  List<BattleShipSnapshot> escort = const [],
  List<BattleShipSnapshot> enemies = const [],
  List<int> mvp = const [],
}) => LiveBattle(
  context: const BattleContext(mapAreaId: 1, mapInfoNo: 1, node: 1),
  displayStage: stage,
  friendMain: main ?? [_ship(1001)],
  friendEscort: escort,
  enemyMain: enemies,
  mvpPositions: mvp,
);

Widget _app(
  GameState state,
  LiveBattle battle, {
  double width = 389,
  double scale = 1,
  PanelStyle style = PanelStyle.card,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: PanelStyleScope(
              style: style,
              child: DetailedBattlePanel(
                battle: battle,
                gameState: state,
                damagePulseMode: DamagePulseFilter.off,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder _row(String side, int index) =>
    find.byKey(Key('battle-ship-$side-$index'));

Finder _icons(Finder row) => find.descendant(
  of: row,
  matching: find.byWidgetPredicate(
    (widget) => widget is EquipmentTypeIconImage && widget.iconId == 14,
  ),
);

void main() {
  setUpAll(() => GameStateController.disableTimerForTest = true);
  tearDownAll(() => GameStateController.disableTimerForTest = false);
  for (final stage in BattleDisplayStage.values) {
    for (final masterId in [42, 43]) {
      testWidgets('$stage hides carried unused damage control $masterId', (
        tester,
      ) async {
        final state = createSortieState(
          ships: [
            _owned(1001, slots: [501]),
          ],
          slotItems: [
            OwnedSlotItem(instanceId: 501, masterSlotItemId: masterId),
          ],
        );
        await tester.pumpWidget(_app(state, _battle(stage: stage)));
        await tester.pump();

        expect(_icons(_row('friend', 0)), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '$stage applies stage guard to this battle use of $masterId',
        (tester) async {
          final state = createSortieState(ships: [], slotItems: []);
          await tester.pumpWidget(
            _app(
              state,
              _battle(
                stage: stage,
                main: [
                  _ship(1001, equipment: [], usedThisBattle: [masterId]),
                ],
              ),
            ),
          );
          await tester.pump();

          final icons = _icons(_row('friend', 0));
          if (stage == BattleDisplayStage.navigation) {
            expect(icons, findsNothing);
          } else {
            expect(icons, findsOneWidget);
            final image = tester.widget<EquipmentTypeIconImage>(icons);
            expect(image.width, 16);
            expect(image.height, 16);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('unused damage control in expansion slot has no hammer', (
    tester,
  ) async {
    final state = createSortieState(
      ships: [
        _owned(1001, slots: [101], extra: 501),
      ],
      slotItems: const [
        OwnedSlotItem(instanceId: 101, masterSlotItemId: 1),
        OwnedSlotItem(instanceId: 501, masterSlotItemId: 43),
      ],
    );
    await tester.pumpWidget(_app(state, _battle()));
    await tester.pump();
    expect(_icons(_row('friend', 0)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'equipment and cumulative sortie consumption do not add this battle hammers',
    (tester) async {
      final state = createSortieState(
        ships: [
          _owned(1001, slots: [101, -1], extra: -1),
        ],
        slotItems: const [
          OwnedSlotItem(instanceId: 101, masterSlotItemId: 1),
          // Inventory and historical consumption are not this battle's uses.
          OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
        ],
      );
      await tester.pumpWidget(
        _app(
          state,
          _battle(
            main: [
              _ship(1001, used: [42, 43]),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(_icons(_row('friend', 0)), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'this battle use remains visible without owned ship or inventory',
    (tester) async {
      for (final ships in <List<OwnedShip>>[
        [],
        [
          _owned(1001, slots: [501]),
        ],
      ]) {
        final state = createSortieState(ships: ships, slotItems: const []);
        await tester.pumpWidget(
          _app(
            state,
            _battle(
              main: [
                _ship(1001, equipment: [], usedThisBattle: [42]),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(_icons(_row('friend', 0)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('friendly use record does not require an owned ship id', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        createSortieState(ships: [], slotItems: []),
        _battle(
          main: [
            _ship(null, equipment: [], usedThisBattle: [43]),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(_icons(_row('friend', 0)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'snapshot copies preserve this battle and cumulative records separately',
    () {
      final defaultShip = _ship(1001, used: [42]);
      expect(defaultShip.damageControlUsedThisBattle, isEmpty);
      final activeShip = defaultShip.copyWith(
        damageControlUsedThisBattle: [43],
      );
      final copied = activeShip.copyWith(currentHp: 6);
      expect(copied.damageControlUsedThisBattle, [43]);
      expect(copied.usedDamageControlItemIds, [42]);
      expect(
        copied
            .copyWith(damageControlUsedThisBattle: [])
            .damageControlUsedThisBattle,
        isEmpty,
      );
    },
  );

  testWidgets('this battle use is independent of inventory changes', (
    tester,
  ) async {
    final initial = createSortieState(
      ships: [
        _owned(1001, slots: [501], extra: 502),
      ],
      slotItems: const [
        OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
        OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
      ],
    );
    // Equipment inventory may change independently of this battle's use record.
    final battle = _battle(
      main: [
        _ship(1001, used: const [42, 42], usedThisBattle: const [42]),
      ],
    );
    await tester.pumpWidget(_app(initial, battle));
    await tester.pump();
    expect(_icons(_row('friend', 0)), findsOneWidget);

    final afterFirst = initial.copyWith(
      ships: {
        1001: _owned(1001, slots: [-1], extra: 502),
      },
      slotItems: const {
        502: OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
      },
    );
    await tester.pumpWidget(_app(afterFirst, battle));
    await tester.pump();
    expect(_icons(_row('friend', 0)), findsOneWidget);

    final afterLast = afterFirst.copyWith(
      ships: {
        1001: _owned(1001, slots: [-1], extra: -1),
      },
      slotItems: const {},
    );
    await tester.pumpWidget(_app(afterLast, battle));
    await tester.pump();
    expect(_icons(_row('friend', 0)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'combined fleets use each friendly ship record and ignore enemy uses',
    (tester) async {
      final state = createSortieState(
        ships: [
          _owned(1001, slots: [501]),
          _owned(1002),
          _owned(1003, extra: 502),
        ],
        slotItems: const [
          OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
          OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
        ],
      );
      final battle = _battle(
        stage: BattleDisplayStage.battle,
        main: [
          _ship(1002),
          _ship(1001, usedThisBattle: [42]),
        ],
        escort: [
          _ship(1003, role: BattleFleetRole.escort, usedThisBattle: [43]),
        ],
        // Deliberately reuse owned id to ensure the side guard is authoritative.
        enemies: [
          _ship(1001, side: BattleSide.enemy, usedThisBattle: [42, 43]),
        ],
      );
      await tester.pumpWidget(_app(state, battle));
      await tester.pump();

      expect(_icons(_row('friend', 0)), findsNothing);
      expect(_icons(_row('friend', 1)), findsOneWidget);
      expect(_icons(_row('friend', 6)), findsOneWidget);
      expect(_icons(_row('enemy', 0)), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [280.0, 389.0]) {
    for (final scale in [1.0, 1.5]) {
      for (final style in PanelStyle.values) {
        testWidgets(
          '$style $width scale $scale keeps two hammers and MVP before HP',
          (tester) async {
            final state = createSortieState(
              ships: [
                _owned(1001, slots: [501], extra: 502),
              ],
              slotItems: const [
                OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
                OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
              ],
            );
            await tester.pumpWidget(
              _app(
                state,
                _battle(
                  stage: BattleDisplayStage.battle,
                  main: [
                    _ship(1001, name: _longName, usedThisBattle: [42, 43]),
                  ],
                  mvp: const [0],
                ),
                width: width,
                scale: scale,
                style: style,
              ),
            );
            await tester.pump();

            final row = _row('friend', 0);
            final icons = _icons(row);
            expect(icons, findsNWidgets(2));
            final rowRect = tester.getRect(row);
            final hpRect = tester.getRect(
              find.descendant(of: row, matching: find.byType(ProphetHpBar)),
            );
            final text = find.descendant(
              of: row,
              matching: find.text(_longName),
            );
            final paragraph = tester.renderObject<RenderParagraph>(text);
            expect(paragraph.didExceedMaxLines, isTrue);
            expect(tester.widget<Text>(text).overflow, TextOverflow.ellipsis);
            var previousRight = tester.getRect(text).right;
            for (var index = 0; index < 2; index++) {
              final rect = tester.getRect(icons.at(index));
              expect(rect.size, const Size(16, 16));
              expect(rect.left, greaterThanOrEqualTo(previousRight));
              expect(rect.left, greaterThanOrEqualTo(rowRect.left));
              expect(rect.right, lessThanOrEqualTo(hpRect.left));
              expect(rect.bottom, lessThanOrEqualTo(rowRect.bottom));
              previousRight = rect.right;
            }
            final mvpRect = tester.getRect(
              find.byKey(const Key('battle-mvp-friend-0')),
            );
            expect(mvpRect.left, greaterThanOrEqualTo(previousRight));
            expect(mvpRect.right, lessThanOrEqualTo(hpRect.left));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final style in PanelStyle.values) {
    for (final stage in [
      BattleDisplayStage.battle,
      BattleDisplayStage.result,
    ]) {
      testWidgets(
        '$style $stage wraps six full-size hammers in narrow fleets',
        (tester) async {
          final state = createSortieState(
            ships: [
              _owned(1001, slots: [501, 502, 503, 504, 505], extra: 506),
              _owned(1002, extra: 507),
            ],
            slotItems: [
              for (var id = 501; id <= 507; id++)
                OwnedSlotItem(instanceId: id, masterSlotItemId: 42),
            ],
          );
          await tester.pumpWidget(
            _app(
              state,
              _battle(
                stage: stage,
                main: [
                  _ship(
                    1001,
                    name: _longName,
                    usedThisBattle: [42, 42, 42, 42, 42, 42],
                  ),
                ],
                escort: [
                  _ship(
                    1002,
                    role: BattleFleetRole.escort,
                    usedThisBattle: [43],
                  ),
                ],
                mvp: const [0, 6],
              ),
              width: 280,
              scale: 1.5,
              style: style,
            ),
          );
          await tester.pump();

          final row = _row('friend', 0);
          final icons = _icons(row);
          expect(icons, findsNWidgets(6));
          expect(_icons(_row('friend', 6)), findsOneWidget);
          final rowRect = tester.getRect(row);
          final hpRect = tester.getRect(
            find.descendant(of: row, matching: find.byType(ProphetHpBar)),
          );
          final tops = <double>{};
          for (var index = 0; index < 6; index++) {
            final rect = tester.getRect(icons.at(index));
            expect(rect.size, const Size(16, 16));
            expect(rect.left, greaterThanOrEqualTo(rowRect.left));
            expect(rect.right, lessThanOrEqualTo(hpRect.left));
            expect(rect.top, greaterThanOrEqualTo(rowRect.top));
            expect(rect.bottom, lessThanOrEqualTo(rowRect.bottom));
            tops.add(rect.top);
          }
          expect(tops.length, greaterThan(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  Widget liveApp(GameStateController game, BattleController battle) =>
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 389,
              child: Column(
                children: [
                  FleetSummaryCard(
                    controller: game,
                    collapsed: false,
                    onToggleCollapse: () {},
                    onOpenFleet: (_) {},
                  ),
                  LiveBattleCard(
                    controller: battle,
                    collapsed: false,
                    onToggleCollapse: () {},
                    damagePulseMode: DamagePulseFilter.off,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  (int, int) liveIconCounts() => (
    _icons(_row('friend', 0)).evaluate().length,
    _icons(find.byKey(const Key('equipment-1001'))).evaluate().length,
  );

  Future<void> startSortie(
    WidgetTester tester,
    GameStateController game,
    BattleController battle,
  ) async {
    final start = apiEvent(
      '/kcsapi/api_req_map/start',
      mapData,
      sequence: 2,
      requestParams: const {'api_deck_id': '1'},
    );
    game.accept(start);
    battle.accept(start);
    await game.idle;
    await battle.idle;
    await tester.pumpWidget(liveApp(game, battle));
    await tester.pump();
  }

  GameState initialState({int secondMasterId = 43}) => createSortieState(
    ships: [
      _owned(1001, slots: [501], extra: 502),
    ],
    slotItems: [
      const OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
      OwnedSlotItem(instanceId: 502, masterSlotItemId: secondMasterId),
    ],
  );

  BattleController newBattleController(GameStateController game) {
    final battle = BattleController(
      gameState: () => game.state,
      waitForGameState: () => game.idle,
      onFriendlyHpUpdated: game.applyFriendlyBattleHp,
      onDamageControlConsumed: game.applyDamageControlConsumption,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
    addTearDown(battle.dispose);
    addTearDown(game.dispose);
    return battle;
  }

  Future<void> acceptBattleEvent(
    WidgetTester tester,
    GameStateController game,
    BattleController battle,
    String path,
    Map<String, Object?> data,
    int sequence,
  ) async {
    final event = apiEvent(path, data, sequence: sequence);
    if (path == '/kcsapi/api_req_map/next') game.accept(event);
    battle.accept(event);
    await battle.idle;
    await game.idle;
    await tester.pump();
  }

  for (final secondMasterId in [42, 43]) {
    testWidgets(
      'used damage control lifecycle resets per node for 42+$secondMasterId',
      (tester) async {
        final game = GameStateController(
          initialState: initialState(secondMasterId: secondMasterId),
        );
        final battle = newBattleController(game);
        await startSortie(tester, game, battle);
        final counts = <(int, int)>[liveIconCounts()];

        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          3,
        );
        counts.add(liveIconCounts());
        expect(game.state.slotItems.containsKey(501), isFalse);
        expect(game.state.slotItems.containsKey(502), isTrue);
        expect(battle.current!.friendMain.single.damageControlUsedThisBattle, [
          42,
        ]);

        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_sortie/battleresult',
          const {'api_win_rank': 'B', 'api_mvp': 1},
          4,
        );
        expect(battle.current!.displayStage, BattleDisplayStage.result);
        counts.add(liveIconCounts());
        expect(battle.current!.friendMain.single.damageControlUsedThisBattle, [
          42,
        ]);

        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_map/next',
          {...mapData, 'api_no': 2},
          5,
        );
        counts.add(liveIconCounts());
        expect(
          battle.current!.friendMain.single.damageControlUsedThisBattle,
          isEmpty,
        );

        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(0, openingHp: 6),
          6,
        );
        counts.add(liveIconCounts());
        expect(
          battle.current!.friendMain.single.damageControlUsedThisBattle,
          isEmpty,
        );

        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_map/next',
          {...mapData, 'api_no': 3},
          7,
        );
        counts.add(liveIconCounts());

        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          8,
        );
        counts.add(liveIconCounts());
        expect(game.state.slotItems.containsKey(502), isFalse);
        expect(battle.current!.friendMain.single.damageControlUsedThisBattle, [
          secondMasterId,
        ]);
        expect(battle.current!.friendMain.single.usedDamageControlItemIds, [
          42,
          secondMasterId,
        ]);
        // Prophet counts items used in this battle; briefing counts items left.
        expect(counts, const [
          (0, 2),
          (1, 1),
          (1, 1),
          (0, 1),
          (0, 1),
          (0, 1),
          (1, 0),
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dayDamage in [0, 30]) {
    testWidgets(
      'used damage control day to night keeps and adds uses after $dayDamage day damage',
      (tester) async {
        final game = GameStateController(initialState: initialState());
        final battle = newBattleController(game);
        await startSortie(tester, game, battle);
        final counts = <(int, int)>[liveIconCounts()];
        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(dayDamage, openingHp: 30),
          3,
        );
        counts.add(liveIconCounts());

        Map<String, Object?> nightDamage(int damage) => {
          'api_hougeki': {
            'api_at_eflag': [1],
            'api_at_list': [0],
            'api_df_list': [
              [0],
            ],
            'api_damage': [
              [damage],
            ],
          },
        };
        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_battle_midnight/battle',
          nightDamage(0),
          4,
        );
        counts.add(liveIconCounts());
        await acceptBattleEvent(
          tester,
          game,
          battle,
          '/kcsapi/api_req_battle_midnight/battle',
          nightDamage(dayDamage == 0 ? 30 : 6),
          5,
        );
        counts.add(liveIconCounts());
        expect(
          counts,
          dayDamage == 0
              ? const [(0, 2), (0, 2), (0, 2), (1, 1)]
              : const [(0, 2), (1, 1), (1, 1), (2, 0)],
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
