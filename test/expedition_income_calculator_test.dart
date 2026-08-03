import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_income_calculator.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  const mission14 = MasterMission(
    id: 14,
    name: '第十四号远征',
    duration: Duration(hours: 6),
  );

  test('远征 14 普通成功返回基础资源', () {
    final income = ExpeditionIncomeCalculator.forMission(
      mission: mission14,
      greatSuccess: false,
    );

    expect(income.fuel, 0);
    expect(income.ammunition, 280);
    expect(income.steel, 200);
    expect(income.bauxite, 30);
  });

  test('大成功按 1.5 倍向下取整', () {
    final income = ExpeditionIncomeCalculator.forMission(
      mission: mission14,
      greatSuccess: true,
    );

    expect(income.ammunition, 420);
    expect(income.steel, 300);
    expect(income.bauxite, 45);
  });

  test('一件大发动艇按 POI 规则增加 5% 收入', () {
    const state = GameState(
      ships: <int, OwnedShip>{
        1: OwnedShip(id: 1, masterId: 1, level: 1, slotIds: <int>[10]),
      },
      slotItems: <int, OwnedSlotItem>{10: OwnedSlotItem(id: 10, masterId: 68)},
    );
    const fleet = Fleet(id: 1, name: '第一舰队', shipIds: <int>[1]);

    final bonus = ExpeditionIncomeCalculator.daihatsuBonusForFleet(
      state,
      fleet,
    );
    final income = ExpeditionIncomeCalculator.forMission(
      mission: mission14,
      greatSuccess: false,
      daihatsuBonus: bonus,
    );

    expect(income.ammunition, 294);
    expect(income.steel, 210);
  });
}
