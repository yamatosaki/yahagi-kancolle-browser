import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_evaluator.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('ExpeditionEvaluator', () {
    test('远征 14 在旗舰等级、数量、编成和补给均满足时通过', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(),
        fleet: _fleet,
        missionId: 14,
      );

      expect(result.hasRule, isTrue);
      expect(result.normalPassed, isTrue);
      expect(result.normalConditions, isNotEmpty);
      expect(result.normalConditions.every((item) => item.passed), isTrue);
    });

    test('补给不足时普通成功检查不通过', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(underSupplied: true),
        fleet: _fleet,
        missionId: 14,
      );

      expect(result.normalPassed, isFalse);
      expect(
        result.normalConditions.any(
          (item) =>
              item.kind == ExpeditionConditionKind.resupply && !item.passed,
        ),
        isTrue,
      );
    });

    test('大成功使用当前概率与默认 100% 目标分别判断', () {
      final result = ExpeditionEvaluator().evaluate(
        state: _state(allSparkled: true),
        fleet: _fleet,
        missionId: 14,
        greatSuccessTarget: 100,
      );

      expect(result.normalPassed, isTrue);
      expect(result.greatSuccessRate, greaterThanOrEqualTo(100));
      expect(result.greatSuccessPassed, isTrue);
    });
  });
}

const _fleet = Fleet(id: 2, name: '第2艦隊', shipIds: <int>[1, 2, 3, 4, 5, 6]);

GameState _state({bool underSupplied = false, bool allSparkled = false}) {
  final conditions = allSparkled ? 60 : 49;
  return GameState(
    masterShips: const <int, MasterShip>{
      101: MasterShip(
        id: 101,
        name: '軽巡',
        shipTypeId: 3,
        maxFuel: 30,
        maxAmmo: 30,
      ),
      102: MasterShip(
        id: 102,
        name: '駆逐',
        shipTypeId: 2,
        maxFuel: 15,
        maxAmmo: 20,
      ),
    },
    ships: <int, OwnedShip>{
      1: OwnedShip(
        id: 1,
        masterId: 101,
        level: 76,
        condition: conditions,
        currentFuel: 30,
        currentAmmo: 30,
      ),
      for (var id = 2; id <= 6; id++)
        id: OwnedShip(
          id: id,
          masterId: 102,
          level: 20,
          condition: conditions,
          currentFuel: underSupplied && id == 2 ? 14 : 15,
          currentAmmo: 20,
        ),
    },
  );
}
