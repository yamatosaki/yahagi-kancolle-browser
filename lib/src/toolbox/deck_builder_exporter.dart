import 'dart:convert';

import '../game_state/game_state.dart';

class DeckBuilderExporter {
  const DeckBuilderExporter();

  Map<String, Object?> exportMap(
    GameState state, {
    bool eventLandBasesOnly = true,
  }) {
    final result = <String, Object?>{'version': 4, 'hqlv': state.admiralLevel};

    for (final fleet in state.fleets) {
      if (fleet.id < 1 || fleet.id > 4) continue;
      final fleetData = <String, Object?>{'name': fleet.name};
      if (fleet.id == 1 && state.combinedFleetType != CombinedFleetType.none) {
        fleetData['t'] = state.combinedFleetType.apiValue;
      }
      for (var index = 0; index < fleet.shipIds.length; index += 1) {
        final ship = state.ships[fleet.shipIds[index]];
        if (ship == null) continue;
        fleetData['s${index + 1}'] = <String, Object?>{
          'id': ship.masterId,
          'lv': ship.level,
          'luck': ship.luck,
          if (ship.maxHp > 0) 'hp': ship.maxHp,
          if (ship.antiSub > 0) 'asw': ship.antiSub,
          'exa': ship.extraSlotId != 0,
          if (ship.specialEffectKinds.isNotEmpty)
            'spi': [
              for (final kind in ship.specialEffectKinds) {'kind': kind},
            ],
          'items': _shipItems(state, ship),
        };
      }
      result['f${fleet.id}'] = fleetData;
    }

    final landBases = eventLandBasesOnly
        ? state.landBases.where((base) => base.areaId >= 30)
        : state.landBases;
    var outputIndex = 1;
    for (final base in landBases.take(3)) {
      final items = <String, Object?>{};
      for (final squadron in base.squadrons) {
        if (squadron.squadronId < 1 || squadron.squadronId > 4) continue;
        final item = state.slotItems[squadron.slotItemId];
        if (item == null) continue;
        items['i${squadron.squadronId}'] = {
          ..._itemData(item),
          if (squadron.maxCount > 0) 'ac': squadron.currentCount,
        };
      }
      result['a$outputIndex'] = <String, Object?>{
        'name': base.name,
        'mode': base.actionKind,
        'items': items,
      };
      outputIndex += 1;
    }

    return result;
  }

  Map<String, Object?> _shipItems(GameState state, OwnedShip ship) {
    final items = <String, Object?>{};
    for (var index = 0; index < ship.slotIds.length; index += 1) {
      final item = state.slotItems[ship.slotIds[index]];
      if (item == null) continue;
      items['i${index + 1}'] = {
        ..._itemData(item),
        if (index < ship.onSlot.length) 'ac': ship.onSlot[index],
      };
    }
    final extraItem = state.slotItems[ship.extraSlotId];
    if (extraItem != null) {
      items['ix'] = _itemData(extraItem);
    }
    return items;
  }

  Map<String, Object?> _itemData(OwnedSlotItem item) => <String, Object?>{
    'id': item.masterSlotItemId,
    'rf': item.level,
    if (item.proficiency > 0) 'mas': item.proficiency,
  };

  String exportJson(GameState state, {bool eventLandBasesOnly = true}) =>
      jsonEncode(exportMap(state, eventLandBasesOnly: eventLandBasesOnly));
}
