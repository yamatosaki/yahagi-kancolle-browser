import '../game_state/game_state.dart';

class EquipmentStatDisplay {
  const EquipmentStatDisplay({required this.label, required this.value});

  final String label;
  final String value;
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

List<EquipmentStatDisplay> equipmentStatDisplays(MasterSlotItem item) {
  final result = <EquipmentStatDisplay>[];

  void addNumber(String label, int value) {
    if (value == 0) {
      return;
    }
    result.add(
      EquipmentStatDisplay(
        label: label,
        value: value > 0 ? '+$value' : '$value',
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
