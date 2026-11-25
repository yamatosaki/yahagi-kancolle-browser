import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_strings.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_rules.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_page.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_enemy_details_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_query_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_query_page.dart';

void main() {
  const locale = Locale('en');
  const battle = BattleDetailStrings.forLocale(locale);
  const composition = CompositionImageStrings(locale);
  const map = SortieMapQueryStrings(locale);

  test(
    'English battle UI translates generated labels with grammatical spacing',
    () {
      expect(battle.title, 'Battle details');
      expect(battle.sideAttack(BattleDetailSide.friend), 'Friendly attack');
      expect(battle.localize('第一炮击战'), 'Shelling phase 1');
      expect(battle.localize('基地航空队 3'), 'Land-based air squadron 3');
      expect(battle.localize('我方主力（单纵阵）'), 'Friendly main fleet (Line ahead)');
      expect(battle.localize('敌航空战'), 'Enemy air battle');
      expect(battle.localize('友军·夕立改二'), 'Allied fleet · 夕立改二');
      expect(battle.localize('Z1点'), 'Sortie node Z1');
      expect(battle.hpChange(30, 10), 'HP 30 → 10');
      expect(battle.damage(20), '20 damage');
      expect(battle.damageStatus('heavy'), 'Heavy damage');
      expect(battle.attackCount(1), '1 attack');
      expect(battle.attackCount(2), '2 attacks');
      expect(battle.shipCount(1), '1 ship');
      expect(battle.shipCount(2), '2 ships');
      expect(battle.mapNode(12), 'Sortie node 12');
      expect(battle.mapRoute(4), 'Route segment 4');
      expect(battle.mapPartial, contains('recorded segments'));
    },
  );

  test('English replay wrappers preserve source names and stored labels', () {
    for (final raw in ['夕立改二', '深海棲艦', '大和改二重', '46cm三連装砲', '我的编队']) {
      expect(battle.localize(raw), raw);
    }
    expect(battle.localize('应急修理要员'), '応急修理要員');
    expect(battle.localize('长门特殊攻击'), '長門 special attack');
    expect(battle.localize('陆奥特殊攻击'), '陸奥 special attack');
    expect(battle.localize('夜间瑞云攻击'), 'Night 瑞雲 attack');
    expect(
      const BattleDetailStrings.forLocale(Locale('zh')).localize('第一炮击战'),
      '第一炮击战',
    );
  });

  test('every generated battle attack description has an English UI label', () {
    for (final night in [false, true]) {
      for (final type in [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        100,
        101,
        102,
        103,
        104,
        105,
        106,
        200,
        300,
        301,
        302,
        400,
        401,
        1000,
      ]) {
        final raw = poiAttackTypeLabel(type, isNight: night);
        if (raw == 'Nelson Touch') continue;
        expect(
          battle.localize(raw),
          matches(RegExp('[A-Za-z]')),
          reason: '$raw type=$type night=$night',
        );
      }
    }
  });

  test(
    'English composition UI leaves game areas and difficulty codes intact',
    () {
      expect(composition.title, 'Composition records');
      expect(composition.fleet(2), 'Fleet 2');
      expect(composition.range(7), 'Combat radius 7');
      expect(composition.fleetForms, contains('Transport escort force'));
      expect(composition.normalArea(2), '南西諸島海域');
      expect(compositionDifficultyCodes, ['甲', '乙', '丙', '丁']);
      expect(composition.baseMode(1), 'Sortie');
      expect(composition.landBaseCount(1), '1 land-based air squadron');
      expect(composition.landBaseCount(2), '2 land-based air squadrons');
      expect(composition.recordDeleted, 'Record deleted.');
    },
  );

  test('English map UI preserves original enemy names and source notes', () {
    const ship = EnemyShipEntry(id: 1, nameJa: '駆逐イ級', nameZh: '驱逐I级');
    expect(map.title, 'Map lookup');
    expect(map.airPower, 'Air power');
    expect(map.fleetNumber(3), 'Enemy fleet 3');
    expect(map.configuration(2), 'Composition 2');
    expect(map.nodeKind('night'), 'Night battle');
    expect(map.nodeKind('battle'), 'Battle node');
    expect(map.enemyShipName(ship), '駆逐イ級');
    expect(map.sourceDetail('燃料 100'), '燃料 100');
    expect(map.sourceDetail('来自 kcwiki 的原始资料'), '来自 kcwiki 的原始资料');
    expect(map.sourceDetail(null), isNull);
    expect(ship.nameZh, '驱逐I级');
  });

  testWidgets('English calculator and enemy attributes use existing UI APIs', (
    tester,
  ) async {
    late ExpCalcStrings exp;
    late EnemyDetailsStrings enemy;
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            exp = ExpCalcStrings(context);
            enemy = EnemyDetailsStrings.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(exp.target, 'Ship and target');
    expect(exp.coverage(2, 5), '2 of 5 compositions known');
    expect(exp.equalWeight, contains('final forms'));
    expect(exp.addNode, 'Add battle node');
    expect(enemy.preciseConfiguration, 'Exact loadout');
    expect(enemy.antiSub, 'ASW');
    expect(enemy.hp, 'HP');
    expect(enemy.speedValue('高速'), 'Fast');
    expect(enemy.speedValue('低速'), 'Slow');
    expect(enemy.speedValue('陸上'), 'Land-based');
    expect(enemy.speedValue('なし'), 'None');
    expect(enemy.speedValue('新しい速力'), '新しい速力');
    expect(enemy.rangeValue('超短'), 'Very short');
    expect(enemy.rangeValue('短'), 'Short');
    expect(enemy.rangeValue('中'), 'Medium');
    expect(enemy.rangeValue('長'), 'Long');
    expect(enemy.rangeValue('超長'), 'Very long');
    expect(enemy.rangeValue('超長+'), 'Very long+');
    expect(enemy.rangeValue('?'), '?');
    expect(enemy.rangeValue('新しい射程'), '新しい射程');
    expect(enemy.rangeValue(null), '—');
    expect(enemyEquipmentTypeIconIds['艦上戦闘機'], 6);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('English screen settings fit a $width px viewport', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
        systemLocaleCode: 'en',
      );
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      addTearDown(layout.dispose);
      addTearDown(display.dispose);
      await tester.pumpWidget(
        _app(
          ScreenSettingsPage(
            layoutSettingsController: layout,
            displayModeController: display,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-language-label')), findsOneWidget);
      expect(
        find.text('Information panel width (not applied in portrait)'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-reset-workspace-menu-order')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-information-panel-position')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('English route summary uses singular and plural battle nodes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        ExpCalcPage(
          state: GameState.empty,
          catalogLoader: () async => _expCatalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 battle node'), findsOneWidget);
    expect(find.text('time'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exp-calc-target-level')), '4');
    await tester.pumpAndSettle();
    expect(find.text('times'), findsOneWidget);
    await tester.ensureVisible(find.text('Add battle node'));
    await tester.tap(find.text('Add battle node'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exp-calc-add-point-C')), findsOneWidget);
    await tester.tap(find.byKey(const Key('exp-calc-add-point-C')));
    await tester.pumpAndSettle();
    expect(find.text('2 battle nodes'), findsOneWidget);
    expect(find.text('1 battle node'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English battle and map summaries separate translated words', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(BattleDetailPage(detail: _battle, onBack: () {})),
    );
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('Enemy Heavy damage'), findsOneWidget);
    expect(find.text('EnemyHeavy damage'), findsNothing);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _app(SortieMapQueryPage(catalogLoader: () async => _mapCatalog)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Air power 10 (AS 15 / AS+ 30)'), findsOneWidget);
    expect(find.text('駆逐イ級'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final count in [1, 2]) {
    testWidgets('English inventory count labels $count equipment types', (
      tester,
    ) async {
      GameStateController.disableTimerForTest = true;
      addTearDown(() => GameStateController.disableTimerForTest = false);
      final controller = GameStateController(
        initialState: GameState(
          hasPortData: true,
          slotItems: {
            for (var id = 1; id <= count; id++)
              id: OwnedSlotItem(id: id, masterId: id),
          },
          masterSlotItems: {
            for (var id = 1; id <= count; id++)
              id: MasterSlotItem(id: id, name: '装備$id', type: const [0, 0, 1]),
          },
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(OwnedInventoryPage(controller: controller, showShips: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text(count == 1 ? '1 type' : '2 types'), findsOneWidget);
      expect(find.text('装備1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

SortieMapCatalogData _expCatalog() {
  final source = _mapCatalog.maps.first;
  final node = source.nodes.first;
  return SortieMapCatalogData(
    version: 1,
    source: 'test',
    maps: [
      SortieMapInfo(
        id: '5-2',
        nameJa: '珊瑚諸島沖',
        difficulty: 1,
        coverAsset: source.coverAsset,
        mapAsset: source.mapAsset,
        source: null,
        nodes: [
          SortieMapNode(
            point: 'C',
            kind: node.kind,
            typeLabel: node.typeLabel,
            battleTypeLabel: node.battleTypeLabel,
            nameJa: node.nameJa,
            reward: node.reward,
            formations: node.formations,
          ),
        ],
      ),
    ],
  );
}

const _mapCatalog = SortieMapCatalogData(
  version: 1,
  source: 'test',
  maps: [
    SortieMapInfo(
      id: '1-1',
      nameJa: '鎮守府正面海域',
      difficulty: 1,
      coverAsset: 'missing-cover.png',
      mapAsset: 'missing-map.png',
      source: null,
      nodes: [
        SortieMapNode(
          point: 'A',
          kind: 'battle',
          typeLabel: '通常',
          battleTypeLabel: '通常戦闘',
          nameJa: '敵艦隊',
          reward: null,
          formations: [
            EnemyFormation(
              variant: 1,
              isFinal: false,
              formation: null,
              experience: 100,
              airPower: 10,
              airSuperiority: 15,
              airSupremacy: 30,
              fleetGroups: [
                [EnemyShipEntry(id: 1501, nameJa: '駆逐イ級', nameZh: '驱逐I级')],
              ],
              note: null,
            ),
          ],
        ),
      ],
    ),
  ],
);

const _battle = BattleDetailSnapshot(
  completedAtMillis: 0,
  mapLabel: '1-1',
  nodeLabel: 'A点',
  rank: 'S',
  enemyFleetName: '敵艦隊',
  fleets: [
    BattleDetailFleet(
      side: BattleDetailSide.enemy,
      role: BattleDetailFleetRole.main,
      ships: [
        BattleDetailShip(
          name: '駆逐イ級',
          side: BattleDetailSide.enemy,
          role: BattleDetailFleetRole.main,
          position: 0,
          initialHp: 100,
          maxHp: 100,
          finalHp: 10,
          damageReceived: 90,
        ),
      ],
    ),
  ],
  stages: [
    BattleDetailStage(
      keyName: 'api_hougeki1',
      title: '第一炮击战',
      attacks: [
        BattleDetailAttack(
          attackerSide: BattleDetailSide.friend,
          attackerName: '夕立改二',
          defenderSide: BattleDetailSide.enemy,
          defenderRole: BattleDetailFleetRole.main,
          defenderPosition: 0,
          defenderName: '駆逐イ級',
          attackType: '主炮连击',
          defenderHpBefore: 100,
          defenderHpAfter: 10,
          hits: [
            BattleDetailHit(
              damage: 90,
              kind: BattleDetailHitKind.hit,
              hpAfter: 10,
            ),
          ],
        ),
      ],
    ),
  ],
);
