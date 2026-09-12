import '../../battle_models.dart';

/// One immutable API response retained for deterministic battle replay.
final class PoiBattleReplayPacket {
  PoiBattleReplayPacket({
    required this.path,
    required Map<String, Object?> data,
  }) : data = clonePoiBattleMap(data);

  final String path;
  final Map<String, Object?> data;
}

Map<String, Object?> clonePoiBattleMap(Map<String, Object?> source) =>
    source.map((key, value) => MapEntry(key, _clonePoiBattleValue(value)));

Object? _clonePoiBattleValue(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _clonePoiBattleValue(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) _clonePoiBattleValue(item)];
  }
  return value;
}

List<BattleShipSnapshot> clonePoiBattleFleet(
  List<BattleShipSnapshot> source,
) => <BattleShipSnapshot>[
  for (final ship in source)
    BattleShipSnapshot(
      masterId: ship.masterId,
      ownedShipId: ship.ownedShipId,
      name: ship.name,
      side: ship.side,
      fleetRole: ship.fleetRole,
      position: ship.position,
      initialHp: ship.initialHp,
      maxHp: ship.maxHp,
      currentHp: ship.currentHp,
      damageDealt: ship.damageDealt,
      damageReceived: ship.damageReceived,
      condition: ship.condition,
      equipmentMasterIds: List<int>.from(ship.equipmentMasterIds),
      usedDamageControlItemIds: List<int>.from(ship.usedDamageControlItemIds),
      isEscaped: ship.isEscaped,
      hpUnknown: ship.hpUnknown,
      details: ship.details,
    ),
];
