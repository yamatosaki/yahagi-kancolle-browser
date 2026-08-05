import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_display.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('equipmentStatDisplays', () {
    test('shows non-zero stats and converts range to a readable label', () {
      const item = MasterSlotItem(
        id: 201,
        name: '120mm/50 连装炮',
        firepower: 3,
        antiAir: 2,
        accuracy: 1,
        range: 1,
      );

      expect(
        equipmentStatDisplays(
          item,
        ).map((entry) => '${entry.label} ${entry.value}').toList(),
        <String>['火力 +3', '对空 +2', '命中 +1', '射程 短'],
      );
    });

    test('does not invent zero-valued equipment stats', () {
      const item = MasterSlotItem(id: 202, name: '无属性装备');

      expect(equipmentStatDisplays(item), isEmpty);
    });

    test('adds official-style visible bonuses for the equipped ship', () {
      const item = MasterSlotItem(
        id: 266,
        name: '12.7cm連装砲C型改二',
        firepower: 3,
        antiAir: 2,
        accuracy: 1,
        armor: 1,
        range: 1,
      );

      final bonuses = equipmentVisibleBonuses(item: item, shipName: '雪風改');
      final stats = equipmentStatDisplays(item, bonuses: bonuses);

      expect(bonuses, <String, int>{'火力': 1, '回避': 1});
      expect(stats.firstWhere((entry) => entry.label == '火力').bonus, 1);
      expect(stats.firstWhere((entry) => entry.label == '回避').bonus, 1);
    });
  });
}
