import 'dart:convert';

import '../game_state/game_state.dart';
import '../game_state/game_state_serializer.dart';

/// Freezes the selected composition, including equipment and combat stats
/// omitted by the lightweight session serializer.
String serializeCompositionSnapshot(
  GameState state, {
  required Set<int> fleetIds,
  required int? landBaseAreaId,
  required Set<int> landBaseIds,
  CombinedFleetType combinedFleetType = CombinedFleetType.none,
}) {
  final fleets = state.fleets
      .where((fleet) => fleetIds.contains(fleet.id))
      .toList();
  final shipIds = fleets
      .expand((fleet) => fleet.shipIds)
      .where((id) => id > 0)
      .toSet();
  final ships = Map<int, OwnedShip>.fromEntries(
    state.ships.entries.where((entry) => shipIds.contains(entry.key)),
  );
  final bases = state.landBases
      .where(
        (base) =>
            base.areaId == landBaseAreaId && landBaseIds.contains(base.baseId),
      )
      .toList();
  final equipmentIds = <int>{
    for (final ship in ships.values) ...ship.slotIds.where((id) => id > 0),
    for (final ship in ships.values)
      if (ship.extraSlotId > 0) ship.extraSlotId,
    for (final base in bases)
      for (final squadron in base.squadrons)
        if (squadron.slotItemId > 0) squadron.slotItemId,
  };
  final equipment = Map<int, OwnedSlotItem>.fromEntries(
    state.slotItems.entries.where((entry) => equipmentIds.contains(entry.key)),
  );
  final shipMasterIds = ships.values.map((ship) => ship.masterId).toSet();
  final equipmentMasterIds = equipment.values
      .map((item) => item.masterSlotItemId)
      .toSet();
  final masterShips = Map<int, MasterShip>.fromEntries(
    state.masterShips.entries.where(
      (entry) => shipMasterIds.contains(entry.key),
    ),
  );
  final shipTypeIds = masterShips.values.map((ship) => ship.shipTypeId).toSet();
  final reduced = GameState(
    memberId: state.memberId,
    admiralLevel: state.admiralLevel,
    masterMapAreas:
        landBaseAreaId == null ||
            !state.masterMapAreas.containsKey(landBaseAreaId)
        ? const {}
        : {landBaseAreaId: state.masterMapAreas[landBaseAreaId]!},
    fleets: fleets,
    landBases: bases,
    masterShipTypes: Map<int, MasterShipType>.fromEntries(
      state.masterShipTypes.entries.where(
        (entry) => shipTypeIds.contains(entry.key),
      ),
    ),
  );
  final data =
      jsonDecode(GameStateSerializer.serialize(reduced))
          as Map<String, dynamic>;
  if (combinedFleetType != CombinedFleetType.none) {
    data['combinedFleetType'] = combinedFleetType.apiValue;
  }
  data['serverOrigin'] = state.serverOrigin;
  data['ships'] = ships.map(
    (id, ship) => MapEntry('$id', {
      'id': ship.id,
      'masterId': ship.masterId,
      'level': ship.level,
      'luck': ship.luck,
      'condition': ship.condition,
      'firepower': ship.firepower,
      'torpedo': ship.torpedo,
      'antiAir': ship.antiAir,
      'antiSub': ship.antiSub,
      'lineOfSight': ship.lineOfSight,
      'speed': ship.speed,
      'slotIds': ship.slotIds,
      'onSlot': ship.onSlot,
      'maxSlotCounts': ship.maxSlotCounts,
      'extraSlotId': ship.extraSlotId,
    }),
  );
  data['slotItems'] = equipment.map(
    (id, item) => MapEntry('$id', {
      'instanceId': item.instanceId,
      'masterSlotItemId': item.masterSlotItemId,
      'level': item.level,
      'proficiency': item.proficiency,
    }),
  );
  data['masterShips'] = masterShips.map(
    (id, ship) => MapEntry('$id', {
      'id': ship.id,
      'name': ship.name,
      'shipTypeId': ship.shipTypeId,
      'speed': ship.speed,
      'slotCount': ship.slotCount,
      'slotCapacities': ship.slotCapacities,
      'portraitFileName': ship.portraitFileName,
      'portraitVersion': ship.portraitVersion,
    }),
  );
  data['masterSlotItems'] = Map<String, Object?>.fromEntries(
    state.masterSlotItems.entries
        .where((entry) => equipmentMasterIds.contains(entry.key))
        .map(
          (entry) => MapEntry('${entry.key}', {
            'id': entry.value.id,
            'name': entry.value.name,
            'type': entry.value.type,
            'firepower': entry.value.firepower,
            'torpedo': entry.value.torpedo,
            'bombing': entry.value.bombing,
            'antiAir': entry.value.antiAir,
            'antiSub': entry.value.antiSub,
            'lineOfSight': entry.value.lineOfSight,
            'accuracy': entry.value.accuracy,
            'evasion': entry.value.evasion,
            'armor': entry.value.armor,
            'range': entry.value.range,
            'interception': entry.value.interception,
            'antiBomber': entry.value.antiBomber,
            'distance': entry.value.distance,
            'resourceVersion': entry.value.resourceVersion,
          }),
        ),
  );
  return jsonEncode(data);
}

GameState deserializeCompositionSnapshot(String value) {
  final data = jsonDecode(value) as Map<String, dynamic>;
  final base = GameStateSerializer.deserialize(value);
  int number(Object? value) => (value as num?)?.toInt() ?? 0;
  List<int> numbers(Object? value) => (value as List<dynamic>? ?? const [])
      .whereType<num>()
      .map((n) => n.toInt())
      .toList();
  final ships = <int, OwnedShip>{};
  for (final entry
      in (data['ships'] as Map<String, dynamic>? ?? const {}).entries) {
    final item = entry.value as Map<String, dynamic>;
    final id = int.parse(entry.key);
    ships[id] = OwnedShip(
      id: id,
      masterId: number(item['masterId']),
      level: number(item['level']),
      luck: number(item['luck']),
      condition: number(item['condition']),
      firepower: number(item['firepower']),
      torpedo: number(item['torpedo']),
      antiAir: number(item['antiAir']),
      antiSub: number(item['antiSub']),
      lineOfSight: number(item['lineOfSight']),
      speed: number(item['speed']),
      slotIds: numbers(item['slotIds']),
      onSlot: numbers(item['onSlot']),
      maxSlotCounts: numbers(item['maxSlotCounts']),
      extraSlotId: number(item['extraSlotId']),
    );
  }
  final slotItems = <int, OwnedSlotItem>{};
  for (final entry
      in (data['slotItems'] as Map<String, dynamic>? ?? const {}).entries) {
    final item = entry.value as Map<String, dynamic>;
    final id = int.parse(entry.key);
    slotItems[id] = OwnedSlotItem(
      instanceId: id,
      masterSlotItemId: number(item['masterSlotItemId']),
      level: number(item['level']),
      proficiency: number(item['proficiency']),
    );
  }
  final masterShips = <int, MasterShip>{};
  for (final entry
      in (data['masterShips'] as Map<String, dynamic>? ?? const {}).entries) {
    final item = entry.value as Map<String, dynamic>;
    final id = int.parse(entry.key);
    masterShips[id] = MasterShip(
      id: id,
      name: item['name'] as String? ?? '',
      shipTypeId: number(item['shipTypeId']),
      speed: number(item['speed']),
      slotCount: number(item['slotCount']),
      slotCapacities: numbers(item['slotCapacities']),
      portraitFileName: item['portraitFileName'] as String?,
      portraitVersion: item['portraitVersion'] as String?,
    );
  }
  final masterSlotItems = <int, MasterSlotItem>{};
  for (final entry
      in (data['masterSlotItems'] as Map<String, dynamic>? ?? const {})
          .entries) {
    final item = entry.value as Map<String, dynamic>;
    final id = int.parse(entry.key);
    masterSlotItems[id] = MasterSlotItem(
      id: id,
      name: item['name'] as String? ?? '',
      type: numbers(item['type']),
      firepower: number(item['firepower']),
      torpedo: number(item['torpedo']),
      bombing: number(item['bombing']),
      antiAir: number(item['antiAir']),
      antiSub: number(item['antiSub']),
      lineOfSight: number(item['lineOfSight']),
      accuracy: number(item['accuracy']),
      evasion: number(item['evasion']),
      armor: number(item['armor']),
      range: number(item['range']),
      interception: number(item['interception']),
      antiBomber: number(item['antiBomber']),
      distance: number(item['distance']),
      resourceVersion: item['resourceVersion'] as String? ?? '',
    );
  }
  return base.copyWith(
    serverOrigin: data['serverOrigin'] as String? ?? '',
    combinedFleetType: CombinedFleetType.fromApiValue(
      number(data['combinedFleetType']),
    ),
    ships: ships,
    slotItems: slotItems,
    masterShips: masterShips,
    masterSlotItems: masterSlotItems,
  );
}
