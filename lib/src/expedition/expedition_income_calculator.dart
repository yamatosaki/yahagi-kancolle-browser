import 'expedition_models.dart';
import '../game_state/game_state.dart';

class ExpeditionIncomeCalculator {
  const ExpeditionIncomeCalculator._();

  static ExpeditionIncome forMission({
    required MasterMission? mission,
    required bool greatSuccess,
    double daihatsuBonus = 0,
  }) {
    if (mission == null) return const ExpeditionIncome();
    final base = _baseResources[mission.id] ?? const <int>[0, 0, 0, 0];
    final multiplier = (greatSuccess ? 1.5 : 1.0) * (1 + daihatsuBonus);
    
    final items = <ExpeditionRewardItem>[];
    // winItem1: [id, count]
    if (mission.winItem1.length >= 2 && mission.winItem1[0] > 0 && mission.winItem1[1] > 0) {
      items.add(ExpeditionRewardItem(id: mission.winItem1[0], count: mission.winItem1[1], kind: ExpeditionRewardKind.normal));
    }
    if (greatSuccess && mission.winItem2.length >= 2 && mission.winItem2[0] > 0 && mission.winItem2[1] > 0) {
      items.add(ExpeditionRewardItem(id: mission.winItem2[0], count: mission.winItem2[1], kind: ExpeditionRewardKind.greatSuccess));
    }

    return ExpeditionIncome(
      fuel: (base[0] * multiplier).floor(),
      ammunition: (base[1] * multiplier).floor(),
      steel: (base[2] * multiplier).floor(),
      bauxite: (base[3] * multiplier).floor(),
      items: items,
    );
  }

  static double daihatsuBonusForFleet(GameState state, Fleet fleet) {
    var bonus05 = 0;
    var bonus03 = 0;
    var bonus02 = 0;
    var bonus01 = 0;
    var toku = 0;
    var improvementTotal = 0;
    var specialShips = 0;
    for (final shipId in fleet.shipIds) {
      final ship = state.ships[shipId];
      if (ship == null) continue;
      if (ship.masterId == 487) specialShips++;
      for (final equipment in state.equipmentForShip(ship)) {
        final id = equipment.owned.masterId;
        if (id == 68 || id == 193) {
          bonus05++;
          if (id == 193) toku++;
        } else if (id == 409) {
          bonus03++;
        } else if (const <int>{166, 408, 436, 449}.contains(id)) {
          bonus02++;
        } else if (id == 167) {
          bonus01++;
        } else {
          continue;
        }
        improvementTotal += equipment.owned.level;
      }
    }
    final count = bonus05 + bonus03 + bonus02 + bonus01;
    final normal =
        ((5 * (bonus05 + specialShips) + 3 * bonus03 + 2 * bonus02 + bonus01) /
                100)
            .clamp(0.0, 0.2);
    final improvement = count == 0
        ? 0.0
        : normal * (improvementTotal / count) / 100;
    final ordinary = bonus05 - toku;
    final tokuBonus = switch (toku) {
      <= 0 => 0.0,
      <= 2 => 0.02 * toku,
      3 =>
        ordinary <= 1
            ? 0.05
            : ordinary == 2
            ? 0.052
            : 0.054,
      _ =>
        ordinary == 0
            ? 0.054
            : ordinary == 1
            ? 0.056
            : ordinary == 2
            ? 0.058
            : ordinary == 3
            ? 0.059
            : 0.06,
    };
    return normal + improvement + tokuBonus;
  }
}

const Map<int, List<int>> _baseResources = <int, List<int>>{
  1: [0, 30, 0, 0],
  2: [0, 100, 30, 0],
  3: [30, 30, 40, 0],
  4: [0, 70, 0, 0],
  5: [200, 200, 20, 20],
  6: [0, 0, 0, 80],
  7: [0, 0, 50, 30],
  8: [50, 100, 50, 50],
  9: [350, 0, 0, 0],
  10: [0, 50, 0, 40],
  11: [0, 0, 0, 250],
  12: [50, 250, 200, 50],
  13: [240, 300, 0, 0],
  14: [0, 280, 200, 30],
  15: [0, 0, 300, 400],
  16: [500, 500, 200, 200],
  17: [70, 70, 50, 0],
  18: [0, 0, 300, 100],
  19: [400, 50, 50, 30],
  20: [0, 0, 150, 0],
  21: [320, 270, 0, 0],
  22: [0, 10, 0, 0],
  23: [0, 20, 0, 100],
  24: [500, 0, 0, 150],
  25: [900, 0, 500, 0],
  26: [0, 0, 0, 900],
  27: [0, 0, 800, 0],
  28: [0, 0, 900, 350],
  29: [0, 50, 0, 100],
  30: [0, 50, 0, 100],
  31: [0, 30, 0, 0],
  32: [50, 50, 50, 50],
  33: [0, 0, 0, 0],
  34: [0, 0, 0, 0],
  35: [0, 0, 240, 280],
  36: [480, 0, 200, 200],
  37: [0, 380, 270, 0],
  38: [420, 0, 200, 0],
  39: [0, 0, 300, 0],
  40: [300, 300, 0, 100],
  41: [100, 0, 0, 20],
  42: [800, 0, 0, 200],
  43: [2000, 0, 0, 400],
  44: [0, 200, 0, 800],
  45: [40, 0, 0, 220],
  46: [300, 0, 150, 380],
  100: [45, 45, 0, 0],
  101: [70, 40, 0, 10],
  102: [120, 0, 60, 60],
  103: [80, 120, 0, 100],
  104: [0, 300, 0, 100],
  105: [100, 500, 100, 200],
  110: [0, 0, 10, 30],
  111: [300, 200, 100, 0],
  112: [0, 100, 100, 180],
  113: [0, 0, 1200, 650],
  114: [500, 500, 1000, 750],
  115: [600, 1000, 600, 600],
  131: [0, 20, 20, 100],
  132: [0, 0, 400, 800],
  133: [0, 800, 500, 400],
  141: [0, 600, 600, 1000],
  142: [0, 480, 0, 0],
};
