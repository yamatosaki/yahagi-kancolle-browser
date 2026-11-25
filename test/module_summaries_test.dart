import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_strings.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/module_summaries.dart';

GameQuest _quest(int id, int state) => GameQuest(
  id: id,
  title: 'q$id',
  detail: '',
  category: 1,
  type: 1,
  state: state,
  progressFlag: 0,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));
  final now = DateTime.utc(2030);

  test('远征摘要显示进行中数量与最近的剩余时间', () {
    final state = GameState(
      fleets: [
        Fleet(
          id: 2,
          name: '',
          mission: FleetMission(
            state: 1,
            missionId: 1,
            completionTime: now.add(const Duration(minutes: 14, seconds: 21)),
          ),
        ),
        Fleet(
          id: 3,
          name: '',
          mission: FleetMission(
            state: 1,
            missionId: 2,
            completionTime: now.add(
              const Duration(hours: 1, minutes: 2, seconds: 33),
            ),
          ),
        ),
      ],
    );
    expect(expeditionSummary(l10n, state, now), '进行中 2/3 · 下次完成 00:14:21');
  });

  test('没有远征时摘要为空', () {
    expect(expeditionSummary(l10n, const GameState(), now), isNull);
  });

  test('舰队摘要省略为零的破损段', () {
    final state = GameState(
      fleets: const [
        Fleet(id: 1, name: '', shipIds: [1, 2]),
      ],
      ships: const {
        1: OwnedShip(
          id: 1,
          masterId: 1,
          level: 1,
          currentHp: 5,
          maxHp: 40,
          condition: 40,
        ),
        2: OwnedShip(
          id: 2,
          masterId: 2,
          level: 1,
          currentHp: 30,
          maxHp: 30,
          condition: 17,
        ),
      },
    );
    expect(fleetSummary(l10n, state, 1), '大破 1 · 最低士气 17');
  });

  test('舰队摘要同时显示大破与中破', () {
    final state = GameState(
      fleets: const [
        Fleet(id: 1, name: '', shipIds: [1, 2]),
      ],
      ships: const {
        1: OwnedShip(
          id: 1,
          masterId: 1,
          level: 1,
          currentHp: 5,
          maxHp: 40,
          condition: 49,
        ),
        2: OwnedShip(
          id: 2,
          masterId: 2,
          level: 1,
          currentHp: 15,
          maxHp: 30,
          condition: 33,
        ),
      },
    );
    expect(fleetSummary(l10n, state, 1), '大破 1 · 中破 1 · 最低士气 33');
  });

  test('没有舰船的舰队没有摘要', () {
    expect(fleetSummary(l10n, const GameState(), 1), isNull);
  });

  test('入渠摘要统计使用中的船渠', () {
    final state = GameState(
      repairDocks: [
        RepairDock(
          id: 1,
          state: 1,
          shipId: 5,
          completionTime: now.add(const Duration(minutes: 5)),
        ),
        RepairDock(
          id: 2,
          state: 1,
          shipId: 6,
          completionTime: now.add(const Duration(minutes: 2, seconds: 1)),
        ),
        const RepairDock(id: 3),
        const RepairDock(id: 4),
      ],
    );
    expect(repairSummary(l10n, state, now), '使用中 2/4 · 下次完成 00:02:01');
    expect(repairSummary(l10n, const GameState(), now), isNull);
  });

  test('建造摘要区分完成与建造中', () {
    final state = GameState(
      constructionDocks: [
        const ConstructionDock(id: 1, state: 3, createdShipMasterId: 10),
        ConstructionDock(
          id: 2,
          state: 2,
          createdShipMasterId: 11,
          completionTime: now.add(const Duration(minutes: 3)),
        ),
        const ConstructionDock(id: 3),
      ],
    );
    expect(constructionSummary(l10n, state, now), '完成 1 · 建造中 1');
    expect(constructionSummary(l10n, const GameState(), now), isNull);
  });

  test('任务摘要区分可完成与进行中', () {
    final state = GameState(
      quests: {
        for (var i = 1; i <= 2; i++) i: _quest(i, 3),
        for (var i = 3; i <= 7; i++) i: _quest(i, 2),
        8: _quest(8, 1),
      },
    );
    expect(questSummary(l10n, state), '可完成 2 · 进行中 5');
    expect(questSummary(l10n, const GameState()), isNull);
  });

  test('未卜先知摘要显示节点与评级，没有战斗时为空', () {
    const ship = BattleShipSnapshot(
      masterId: 1,
      name: 'x',
      side: BattleSide.friend,
      fleetRole: BattleFleetRole.main,
      position: 0,
      initialHp: 10,
      maxHp: 10,
      currentHp: 10,
    );
    const battle = LiveBattle(
      context: BattleContext(nodeDisplayLabel: 'C'),
      friendMain: [ship],
      rank: BattleRank.s,
    );
    const zh = BattleDetailStrings.forLocale(Locale('zh'));
    expect(battleSummary(zh, battle), 'C · S');
    expect(
      battleSummary(
        zh,
        const LiveBattle(
          context: BattleContext(nodeDisplayLabel: 'C'),
          friendMain: [ship],
        ),
      ),
      'C',
    );
    expect(battleSummary(zh, null), isNull);
    expect(
      battleSummary(
        const BattleDetailStrings.forLocale(Locale('en')),
        const LiveBattle(
          context: BattleContext(practice: true),
          friendMain: [ship],
        ),
      ),
      'Exercise',
    );
  });

  test('基地航空队与出击前检查摘要', () {
    expect(
      landBaseSummary(l10n, const [
        LandBaseState(areaId: 6, baseId: 1, name: '', actionKind: 1),
        LandBaseState(areaId: 6, baseId: 2, name: '', actionKind: 1),
        LandBaseState(areaId: 6, baseId: 3, name: '', actionKind: 2),
      ]),
      '出击 2 · 防空 1',
    );
    expect(landBaseSummary(l10n, const []), isNull);
    expect(preSortieSummary(l10n, 3), '警告 3');
    expect(preSortieSummary(l10n, 0), l10n.noSortieWarnings);
  });
}
