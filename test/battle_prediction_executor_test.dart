import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';

void main() {
  test('returns the mutated engine for the following battle phase', () async {
    const enemy = BattleShipSnapshot(
      masterId: 501,
      name: 'enemy',
      side: BattleSide.enemy,
      fleetRole: BattleFleetRole.main,
      position: 0,
      initialHp: 20,
      maxHp: 20,
      currentHp: 20,
    );
    final executor = IsolateBattlePredictionExecutor();
    final first = await executor.append(
      engine: _CountingEngine(const <BattleShipSnapshot>[enemy]),
      path: '/day',
      data: const <String, Object?>{},
    );
    final second = await executor.append(
      engine: first.engine,
      path: '/night',
      data: const <String, Object?>{},
    );

    expect(first.prediction.enemyMain.single.currentHp, 19);
    expect(second.prediction.enemyMain.single.currentHp, 18);
    expect((second.engine as _CountingEngine).phaseCount, 2);
  });
}

final class _CountingEngine implements BattlePredictionEngine {
  _CountingEngine(this._enemyMain);

  List<BattleShipSnapshot> _enemyMain;
  int phaseCount = 0;

  @override
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  }) {
    phaseCount += 1;
    _enemyMain = <BattleShipSnapshot>[
      for (final ship in _enemyMain)
        ship.copyWith(currentHp: ship.currentHp - 1),
    ];
    return BattlePrediction(
      friendMain: const <BattleShipSnapshot>[],
      friendEscort: const <BattleShipSnapshot>[],
      enemyMain: _enemyMain,
      enemyEscort: const <BattleShipSnapshot>[],
      rank: BattleRank.a,
    );
  }
}
