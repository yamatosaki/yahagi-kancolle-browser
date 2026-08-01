import '../game_state/game_state.dart';
import 'equipment_display.dart';

List<EquipmentMechanismDisplay> detectShipCombatMechanisms(
  GameState state,
  OwnedShip ship,
) {
  final master = state.masterForShip(ship);
  if (master == null) {
    return const <EquipmentMechanismDisplay>[];
  }
  final equipment = state.equipmentForShip(ship);
  final result = <EquipmentMechanismDisplay>[];

  if (_canOpeningAsw(master, ship, equipment)) {
    result.add(
      const EquipmentMechanismDisplay(
        label: '先制对潜',
        description: '开幕雷击前先进行一次对潜攻击。当前舰娘的舰种、对潜值和装备组合满足 Yahagi 的先制对潜静态判定。',
        tone: MechanismTone.antiSubmarine,
      ),
    );
  }
  if (_canAntiAirCutIn(master, equipment)) {
    result.add(
      const EquipmentMechanismDisplay(
        label: '对空 CI',
        description: '当前装备组合可触发对空弹幕（对空 Cut-in）。实际触发类型和击坠效果由舰娘与装备组合决定。',
        tone: MechanismTone.antiAir,
      ),
    );
  }
  if (_canAntiAirRocketBarrage(master, equipment)) {
    result.add(
      const EquipmentMechanismDisplay(
        label: '对空喷进弹幕',
        description: '当前舰种装备了 12cm 30连装喷进炮改二，可在航空战中判定对空喷进弹幕；是否触发仍受游戏内概率影响。',
        tone: MechanismTone.antiAir,
      ),
    );
  }
  return result;
}

EquipmentMechanismDisplay? detectFleetSpecialAttack(
  GameState state,
  Fleet fleet,
) {
  final ships = state.shipsForFleet(fleet.id);
  if (ships.length < 2) {
    return null;
  }
  final masters = <MasterShip?>[
    for (final ship in ships) state.masterForShip(ship),
  ];
  if (masters.any((item) => item == null)) {
    return null;
  }
  final flagship = masters[0]!;
  final second = masters[1]!;
  final fullFleet = ships.length >= 6;
  final flagshipHealthy = _notMediumDamage(ships[0]);
  final secondHealthy = _notHeavyDamage(ships[1]);

  EquipmentMechanismDisplay mechanism(String label, String summary) {
    return EquipmentMechanismDisplay(
      label: label,
      description: '$summary 当前仅表示编成与耐久等静态条件匹配；实际发动还受阵型、联合舰队状态和本次出击中的使用次数限制。',
      tone: MechanismTone.specialAttack,
    );
  }

  if (fullFleet &&
      flagship.classTypeId == 88 &&
      flagshipHealthy &&
      _nelsonPositionsAreValid(masters)) {
    return mechanism('Nelson Touch', 'Nelson 级旗舰的特殊攻击编成。');
  }
  if (fullFleet &&
      flagship.id == 541 &&
      flagshipHealthy &&
      _isBattleship(second) &&
      secondHealthy) {
    return mechanism('一齐射击（长门）', '长门改二旗舰的特殊攻击编成。');
  }
  if (fullFleet &&
      flagship.id == 573 &&
      flagshipHealthy &&
      _isBattleship(second) &&
      secondHealthy) {
    return mechanism('一齐射击（陆奥）', '陆奥改二旗舰的特殊攻击编成。');
  }
  if (fullFleet &&
      flagship.classTypeId == 93 &&
      flagshipHealthy &&
      masters.length >= 3 &&
      _isBattleship(second) &&
      _isBattleship(masters[2]!) &&
      secondHealthy &&
      _notHeavyDamage(ships[2])) {
    return mechanism('Colorado Touch', 'Colorado 级旗舰的特殊攻击编成。');
  }
  if (fullFleet &&
      const <int>{911, 916, 546}.contains(flagship.id) &&
      flagshipHealthy &&
      _yamatoPartner(second) &&
      _notMediumDamage(ships[1])) {
    return mechanism('大和型特殊攻击', '大和改二／武藏改二旗舰的特殊攻击编成。');
  }
  if (fullFleet &&
      const <int>{591, 592, 593, 954, 694}.contains(flagship.id) &&
      flagshipHealthy &&
      const <int>{
        151,
        152,
        364,
        439,
        591,
        592,
        593,
        694,
        733,
        927,
        954,
      }.contains(second.id) &&
      _notMediumDamage(ships[1])) {
    return mechanism('僚舰夜战突击', '金刚级改二丙／榛名改二乙系旗舰的夜战特殊攻击编成。');
  }
  if (fullFleet &&
      const <int>{364, 733}.contains(flagship.id) &&
      const <int>{364, 733}.contains(second.id) &&
      flagship.id != second.id &&
      flagshipHealthy &&
      secondHealthy) {
    return mechanism('Queen Elizabeth级特殊攻击', 'Warspite改与Valiant改组成的特殊攻击编成。');
  }
  if (fullFleet &&
      const <int>{392, 969, 724}.contains(flagship.id) &&
      const <int>{392, 969, 724}.contains(second.id) &&
      flagship.id != second.id &&
      flagshipHealthy &&
      secondHealthy) {
    return mechanism('Richelieu级特殊攻击', 'Richelieu改／Deux与Jean Bart改组成的特殊攻击编成。');
  }
  return null;
}

bool _canOpeningAsw(
  MasterShip master,
  OwnedShip ship,
  List<ShipEquipment> equipment,
) {
  const unconditional = <int>{
    141,
    394,
    478,
    624,
    562,
    689,
    596,
    692,
    628,
    629,
    681,
    726,
    893,
    906,
    920,
    941,
    1040,
  };
  if (unconditional.contains(master.id)) {
    return true;
  }
  final hasSonar = equipment.any((item) => _icon(item.master) == 18);
  final equipmentAsw = equipment.fold<int>(
    0,
    (sum, item) => sum + (item.master?.antiSub ?? 0),
  );
  if (master.shipTypeId == 1) {
    return (ship.antiSub >= 60 && hasSonar) ||
        (ship.antiSub >= 75 && equipmentAsw >= 4);
  }
  if (const <int>{2, 3, 4, 21, 22}.contains(master.shipTypeId)) {
    return ship.antiSub >= 100 && hasSonar;
  }
  if (const <int>{380, 381, 529, 536, 646}.contains(master.id)) {
    return equipment.any((item) {
      final type = _type(item.master);
      return const <int>{7, 8, 11, 25, 26}.contains(type) &&
          (item.master?.antiSub ?? 0) > 0;
    });
  }
  return false;
}

bool _canAntiAirCutIn(MasterShip master, List<ShipEquipment> equipment) {
  if (const <int>{13, 14}.contains(master.shipTypeId)) {
    return false;
  }
  final highAngle = equipment.where((item) => _icon(item.master) == 16).length;
  final builtInHighAngle = equipment
      .where(
        (item) => _icon(item.master) == 16 && (item.master?.antiAir ?? 0) >= 8,
      )
      .length;
  final hasAaRadar = equipment.any(
    (item) =>
        const <int>{12, 13}.contains(_type(item.master)) &&
        (item.master?.antiAir ?? 0) > 0,
  );
  final hasAafd = equipment.any((item) => _type(item.master) == 36);
  final hasLargeGun = equipment.any((item) => _type(item.master) == 3);
  final hasType3Shell = equipment.any((item) => _type(item.master) == 18);
  final aaGuns = equipment.where((item) => _type(item.master) == 21).length;
  final hasConcentratedAaGun = equipment.any(
    (item) => _type(item.master) == 21 && (item.master?.antiAir ?? 0) >= 9,
  );
  final slotCount = equipment.length;

  if (_isBattleship(master) &&
      slotCount >= 4 &&
      hasLargeGun &&
      hasType3Shell &&
      hasAafd &&
      hasAaRadar) {
    return true;
  }
  if (slotCount >= 3 &&
      ((builtInHighAngle >= 2 && hasAaRadar) ||
          (highAngle >= 1 && hasAafd && hasAaRadar) ||
          (hasConcentratedAaGun && aaGuns >= 2 && hasAaRadar) ||
          (builtInHighAngle >= 1 && hasConcentratedAaGun && hasAaRadar))) {
    return true;
  }
  if (slotCount >= 2 &&
      ((builtInHighAngle >= 1 && hasAaRadar) || (highAngle >= 1 && hasAafd))) {
    return true;
  }
  if (master.id == 428 &&
      highAngle >= 1 &&
      hasConcentratedAaGun &&
      (hasAaRadar || slotCount >= 2)) {
    return true;
  }
  return false;
}

bool _canAntiAirRocketBarrage(
  MasterShip master,
  List<ShipEquipment> equipment,
) {
  return const <int>{6, 7, 10, 11, 16, 18}.contains(master.shipTypeId) &&
      equipment.any((item) => item.master?.id == 274);
}

bool _nelsonPositionsAreValid(List<MasterShip?> masters) {
  if (masters.length < 6) {
    return false;
  }
  return !_isSubmarine(masters[1]!) &&
      !_isSubmarine(masters[2]!) &&
      !_isCarrier(masters[2]!) &&
      !_isSubmarine(masters[3]!) &&
      !_isSubmarine(masters[4]!) &&
      !_isCarrier(masters[4]!) &&
      !_isSubmarine(masters[5]!);
}

bool _yamatoPartner(MasterShip master) {
  return const <int>{
    178,
    360,
    392,
    546,
    724,
    911,
    916,
    969,
  }.contains(master.id);
}

bool _notMediumDamage(OwnedShip ship) => ship.currentHp * 2 > ship.maxHp;

bool _notHeavyDamage(OwnedShip ship) => ship.currentHp * 4 > ship.maxHp;

bool _isSubmarine(MasterShip master) =>
    const <int>{13, 14}.contains(master.shipTypeId);

bool _isCarrier(MasterShip master) =>
    const <int>{7, 11, 18}.contains(master.shipTypeId);

bool _isBattleship(MasterShip master) =>
    const <int>{8, 9, 10, 12}.contains(master.shipTypeId);

int _type(MasterSlotItem? item) =>
    item != null && item.type.length >= 3 ? item.type[2] : -1;

int _icon(MasterSlotItem? item) =>
    item != null && item.type.length >= 4 ? item.type[3] : -1;
