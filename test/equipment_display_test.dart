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
  });
}
