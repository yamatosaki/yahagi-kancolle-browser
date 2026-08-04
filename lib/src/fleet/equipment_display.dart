import '../game_state/game_state.dart';

// Keep the calculation code available, but do not expose provisional bonuses
// until the authoritative equipment-bonus database is ready.
const bool kShowEquipmentVisibleBonuses = false;

class EquipmentStatDisplay {
  const EquipmentStatDisplay({
    required this.label,
    required this.value,
    this.bonus = 0,
  });

  final String label;
  final String value;
  final int bonus;
}

class EquipmentMechanismDisplay {
  const EquipmentMechanismDisplay({
    required this.label,
    required this.description,
    this.tone = MechanismTone.neutral,
  });

  final String label;
  final String description;
  final MechanismTone tone;
}

enum MechanismTone { neutral, antiSubmarine, antiAir, specialAttack }

List<EquipmentStatDisplay> equipmentStatDisplays(
  MasterSlotItem item, {
  Map<String, int> bonuses = const <String, int>{},
}) {
  final result = <EquipmentStatDisplay>[];

  void addNumber(String label, int value) {
    final bonus = bonuses[label] ?? 0;
    if (value == 0 && bonus == 0) {
      return;
    }
    result.add(
      EquipmentStatDisplay(
        label: label,
        value: value == 0 ? '' : (value > 0 ? '+$value' : '$value'),
        bonus: bonus,
      ),
    );
  }

  addNumber('火力', item.firepower);
  addNumber('雷装', item.torpedo);
  addNumber('爆装', item.bombing);
  addNumber('对空', item.antiAir);
  addNumber('对潜', item.antiSub);
  addNumber('索敌', item.lineOfSight);
  addNumber('命中', item.accuracy);
  addNumber('回避', item.evasion);
  addNumber('装甲', item.armor);

  final range = _rangeLabel(item.range);
  if (range != null) {
    result.add(EquipmentStatDisplay(label: '射程', value: range));
  }
  return result;
}

Map<String, int> equipmentVisibleBonuses({
  required MasterSlotItem item,
  required String shipName,
}) {
  final normalizedItemName = item.name.replaceAll(' ', '');
  final normalizedShipName = shipName.replaceAll(' ', '');
  if (item.id != 266 && !normalizedItemName.contains('12.7cm連装砲C型改二')) {
    return const <String, int>{};
  }

  if (normalizedShipName == '雪風改' ||
      normalizedShipName == '丹陽' ||
      normalizedShipName == '磯風乙改') {
    return const <String, int>{'火力': 1, '回避': 1};
  }
  if (normalizedShipName == '雪風改二') {
    return const <String, int>{'火力': 2, '回避': 1};
  }
  return const <String, int>{};
}

String? _rangeLabel(int range) {
  return switch (range) {
    1 => '短',
    2 => '中',
    3 => '长',
    4 => '超长',
    5 => '超长＋',
    _ => null,
  };
}
