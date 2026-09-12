import 'dart:convert';

import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import 'combat_state.dart';
import 'game_api_decoder.dart';
import 'game_state.dart';
import 'land_base_raid.dart';
import 'quest_text_normalizer.dart';

export 'game_api_decoder.dart' show GameApiParseException;

class GameStateReducer {
  bool supportsPath(String path) =>
      GameCapturePathCatalog.gameState.contains(path);

  GameState reduce(GameState state, CapturedApiEvent event) {
    if (!supportsPath(event.path)) {
      return state;
    }

    final data = GameApiDecoder.decodeEventData(
      event,
      // The formation change response only contains api_result and
      // api_result_msg. Its state transition is driven by request parameters.
      allowMissingData:
          GameCapturePathCatalog.battleRetreat.contains(event.path) ||
          event.path == '/kcsapi/api_req_hensei/change' ||
          event.path == '/kcsapi/api_req_hensei/combined' ||
          event.path == '/kcsapi/api_req_kaisou/slotset' ||
          event.path == '/kcsapi/api_req_kaisou/slotset_ex' ||
          event.path == '/kcsapi/api_req_kaisou/unsetslot_all' ||
          event.path == '/kcsapi/api_req_kaisou/open_exslot' ||
          event.path == '/kcsapi/api_req_kousyou/createship' ||
          event.path == '/kcsapi/api_req_kousyou/createship_speedchange' ||
          event.path == '/kcsapi/api_req_nyukyo/start' ||
          event.path == '/kcsapi/api_req_nyukyo/speedchange' ||
          event.path == '/kcsapi/api_req_air_corps/set_action' ||
          event.path == '/kcsapi/api_req_air_corps/change_name' ||
          event.path == '/kcsapi/api_port/airCorpsCondRecoveryWithTimer' ||
          event.path == '/kcsapi/api_req_quest/clearitemget' ||
          event.path == '/kcsapi/api_req_quest/start' ||
          event.path == '/kcsapi/api_req_quest/stop',
    );
    final origin = event.sourceOrigin.isEmpty
        ? state.serverOrigin
        : event.sourceOrigin;

    final reduced = switch (event.path) {
      '/kcsapi/api_start2/getData' => _start2(
        state,
        _requiredMap(data, 'start2'),
        event,
        origin,
      ),
      '/kcsapi/api_port/port' => _portSnapshot(
        state,
        _requiredMap(data, 'port'),
        event,
        origin,
        hasPortData: true,
      ),
      '/kcsapi/api_get_member/basic' => _basic(
        state,
        _requiredMap(data, 'basic'),
        event,
        origin,
      ),
      '/kcsapi/api_get_member/require_info' => _snapshot(
        state,
        _requiredMap(data, 'require_info'),
        event,
        origin,
      ),
      '/kcsapi/api_get_member/material' => state.copyWith(
        resources: _parseResources(
          _requiredList(data, 'material'),
          state.resources,
        ),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_get_member/useitem' => state.copyWith(
        useItems: _parseUseItems(_requiredList(data, 'useitem')),
        hasUseItemData: true,
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_get_member/deck' => state.copyWith(
        fleets: _parseFleets(_requiredList(data, 'deck')),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_get_member/slot_item' => state.copyWith(
        slotItems: _parseSlotItems(_requiredList(data, 'slot_item')),
        hasEquipmentInventory: true,
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_get_member/ndock' => state.copyWith(
        repairDocks: _parseRepairDocks(_requiredList(data, 'ndock')),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_get_member/kdock' => state.copyWith(
        constructionDocks: _parseConstructionDocks(
          _requiredList(data, 'kdock'),
        ),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_get_member/questlist' => _questList(
        state,
        _requiredMap(data, 'questlist'),
        event,
        origin,
      ),
      '/kcsapi/api_get_member/mapinfo' => _mapInfo(
        state,
        _requiredMap(data, 'mapinfo'),
        event,
        origin,
      ),
      '/kcsapi/api_req_air_corps/expand_base' => _expandLandBases(
        state,
        _requiredList(data, 'new land bases'),
        event,
        origin,
      ),
      '/kcsapi/api_req_air_corps/set_plane' ||
      '/kcsapi/api_req_air_corps/supply' ||
      '/kcsapi/api_req_air_corps/cond_recovery' => _updateLandBasePlanes(
        state,
        _requiredMap(data, 'land-base planes'),
        event,
        origin,
      ),
      '/kcsapi/api_port/airCorpsCondRecoveryWithTimer' =>
        _updateLandBasePlanesIfPresent(state, data, event, origin),
      '/kcsapi/api_req_air_corps/change_deployment_base' =>
        _changeLandBaseDeployment(
          state,
          _requiredMap(data, 'land-base deployment'),
          event,
          origin,
        ),
      '/kcsapi/api_req_air_corps/set_action' => _setLandBaseAction(
        state,
        event,
        origin,
      ),
      '/kcsapi/api_req_air_corps/change_name' => _changeLandBaseName(
        state,
        event,
        origin,
      ),
      '/kcsapi/api_req_hokyu/charge' => _charge(
        state,
        _requiredMap(data, 'charge'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/slotset' => _slotSet(state, event, origin),
      '/kcsapi/api_req_kaisou/slotset_ex' => _slotSetExtra(
        state,
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/unsetslot_all' => _unsetAllSlots(
        state,
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/slot_exchange_index' => _mergeActionShips(
        state,
        _optionalListOrSingleMap(
          _requiredMap(data, 'slot exchange')['api_ship_data'],
        ),
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/slot_deprive' => _slotDeprive(
        state,
        _requiredMap(data, 'slot deprive'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/createship' => _constructionStart(
        state,
        data == null
            ? const <String, Object?>{}
            : _requiredMap(data, 'createship'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/createship_speedchange' =>
        _constructionSpeedChange(state, event, origin),
      '/kcsapi/api_req_kousyou/createitem' => _createSlotItems(
        state,
        _requiredMap(data, 'createitem'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/remodel_slot' => _remodelSlotItems(
        state,
        _requiredMap(data, 'equipment modernization'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/remodel_slot_recover' => _createSlotItems(
        state,
        {
          'api_slot_item': _requiredMap(
            data,
            'equipment recovery',
          )['api_after_slot'],
        },
        event,
        origin,
      ),
      '/kcsapi/api_req_member/itemuse' => _createSlotItems(
        state,
        {
          'api_get_items': [
            for (final entry in _optionalList(
              _requiredMap(data, 'item use')['api_getitem'],
            ))
              if (entry is Map && entry['api_slotitem'] is Map)
                entry['api_slotitem'],
          ],
        },
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/marriage' => _shipAndDeck(
        state,
        {
          'api_ship_data': [data],
        },
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/open_exslot' => _updateShipCapacity(
        state,
        const {},
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/hangar_expand' => _updateShipCapacity(
        state,
        _requiredMap(data, 'hangar expansion'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/destroyship' => _consumeShips(
        state,
        _requestIds(event.requestParams['api_ship_id']),
        removeEquipment: _asInt(event.requestParams['api_slot_dest_flag']) > 0,
        event: event,
        origin: origin,
      ),
      '/kcsapi/api_req_kousyou/destroyitem2' => _destroySlotItems(
        state,
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/getship' => _getShip(
        state,
        _requiredMap(data, 'getship'),
        event,
        origin,
      ),
      '/kcsapi/api_req_hensei/change' => _formationChange(state, event, origin),
      '/kcsapi/api_req_hensei/combined' => state.copyWith(
        combinedFleetType: CombinedFleetType.fromApiValue(
          _asInt(event.requestParams['api_combined_type']),
        ),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_req_hensei/preset_select' => _formationPresetSelect(
        state,
        _requiredMap(data, 'formation preset'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/powerup' => _modernizeShip(
        state,
        _optionalMap(data) ?? const <String, Object?>{},
        event,
        origin,
      ),
      '/kcsapi/api_req_nyukyo/speedchange' => _repairSpeedChange(
        state,
        event,
        origin,
      ),
      '/kcsapi/api_req_nyukyo/start' => _repairStart(state, event, origin),
      '/kcsapi/api_req_quest/clearitemget' ||
      '/kcsapi/api_req_quest/stop' => _removeQuest(
        state,
        _asInt(event.requestParams['api_quest_id']),
        event,
        origin,
      ),
      '/kcsapi/api_req_quest/start' => _acceptQuest(state, event, origin),
      '/kcsapi/api_get_member/ship2' ||
      '/kcsapi/api_get_member/ship3' ||
      '/kcsapi/api_get_member/ship_deck' => _shipAndDeck(
        state,
        data,
        event,
        origin,
      ),
      '/kcsapi/api_req_map/select_eventmap_rank' => _selectEventMapRank(
        state,
        _optionalMap(data) ?? const <String, Object?>{},
        event,
        origin,
      ),
      '/kcsapi/api_req_map/start' => _mapStartOrNext(
        state,
        _requiredMap(data, 'map data'),
        event,
      ),
      '/kcsapi/api_req_map/air_raid' => state.copyWith(
        landBases: _applyLandBaseRaid(
          state.landBases,
          _requiredMap(data, 'air raid'),
          _asInt(
            _optionalMap(data)?['api_maparea_id'],
            state.combatState.mapArea,
          ),
        ),
      ),
      '/kcsapi/api_req_map/next' => _mapStartOrNext(
        state,
        _requiredMap(data, 'map data'),
        event,
      ),
      '/kcsapi/api_req_sortie/battle' => _battle(
        state,
        _requiredMap(data, 'battle data'),
        event,
      ),
      '/kcsapi/api_req_sortie/battleresult' => _battleResult(
        state,
        _requiredMap(data, 'battle result'),
        event,
      ),
      '/kcsapi/api_req_combined_battle/battleresult' => _battleResult(
        state,
        _requiredMap(data, 'combined battle result'),
        event,
      ),
      '/kcsapi/api_req_sortie/goback_port' ||
      '/kcsapi/api_req_combined_battle/goback_port' => _goBackPort(
        state,
        event,
      ),
      '/kcsapi/api_req_mission/result' => _missionResult(state, event, origin),
      '/kcsapi/api_req_mission/start' => _missionStart(
        state,
        _requiredMap(data, 'mission start'),
        event,
        origin,
      ),
      _ => state,
    };
    return _revalidateF96(
      _applyKnownQuestProgress(reduced, event, data),
      event.capturedAt,
    );
  }

  GameState _destroySlotItems(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final rawIds = event.requestParams['api_slotitem_ids']?.toString() ?? '';
    final ids = rawIds.split(',').map(_asInt).where((id) => id > 0).toSet();
    if (ids.isEmpty) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }

    final removed = <OwnedSlotItem>[for (final id in ids) ?state.slotItems[id]];
    final slotItems = Map<int, OwnedSlotItem>.of(state.slotItems)
      ..removeWhere((id, _) => ids.contains(id));

    final quest = state.quests[_f96QuestId];
    final destroyedRequired = removed
        .where((item) => item.masterSlotItemId == _f96DiscardMasterId)
        .length;
    if (quest == null || !quest.isAccepted || destroyedRequired == 0) {
      return state.copyWith(
        slotItems: slotItems,
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      );
    }

    final quests = Map<int, GameQuest>.of(state.quests);
    quests[_f96QuestId] = quest.incrementExactProgress(
      destroyedRequired,
      updatedAt: event.capturedAt,
    );
    return state.copyWith(
      slotItems: slotItems,
      quests: quests,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _createSlotItems(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final rawItems = data['api_get_items'];
    final parsed = _parseSlotItems(
      rawItems is List
          ? List<Object?>.from(rawItems)
          : <Object?>[data['api_slot_item']],
    );
    return state.copyWith(
      slotItems: Map<int, OwnedSlotItem>.of(state.slotItems)..addAll(parsed),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _updateShipCapacity(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final id = _asInt(
      event.requestParams['api_ship_id'] ?? event.requestParams['api_id'],
    );
    final ship = state.ships[id];
    if (ship == null) return state;
    final expanded = event.path.endsWith('/open_exslot');
    return _replaceShip(
      state,
      _copyShip(
        ship,
        extraSlotId: expanded && ship.extraSlotId == 0 ? -1 : null,
        maxSlotCounts: data['api_onslot_max'] is List
            ? _intList(data['api_onslot_max'], includeNonPositive: true)
            : null,
      ),
      event,
      origin,
    );
  }

  GameState _remodelSlotItems(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final consumed = _intList(data['api_use_slot_id']).toSet();
    final items = Map<int, OwnedSlotItem>.of(state.slotItems)
      ..removeWhere((id, _) => consumed.contains(id));
    if (_asInt(data['api_remodel_flag']) == 1) {
      items.addAll(_parseSlotItems([data['api_after_slot']]));
    }
    return state.copyWith(
      slotItems: items,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _modernizeShip(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final consumed = _consumeShips(
      state,
      _requestIds(event.requestParams['api_id_items']),
      removeEquipment: _asInt(event.requestParams['api_slot_dest_flag']) != 0,
      event: event,
      origin: origin,
    );
    final ship = _optionalMap(data['api_ship']);
    if (ship == null) return consumed;
    return consumed.copyWith(
      pendingExportShipIds: _remainingExportShipIds(consumed, [ship]),
      ships: {
        ...consumed.ships,
        ..._parseShips([ship], previous: consumed.ships),
      },
    );
  }

  GameState _consumeShips(
    GameState state,
    Set<int> shipIds, {
    required bool removeEquipment,
    required CapturedApiEvent event,
    required String origin,
  }) {
    if (shipIds.isEmpty) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }
    final equipmentIds = <int>{
      if (removeEquipment)
        for (final shipId in shipIds)
          if (state.ships[shipId] case final ship?) ...<int>{
            ...ship.slotIds.where((id) => id > 0),
            if (ship.extraSlotId > 0) ship.extraSlotId,
          },
    };
    final ships = Map<int, OwnedShip>.of(state.ships)
      ..removeWhere((id, _) => shipIds.contains(id));
    final slotItems = Map<int, OwnedSlotItem>.of(state.slotItems)
      ..removeWhere((id, _) => equipmentIds.contains(id));
    final fleets = <Fleet>[
      for (final fleet in state.fleets)
        Fleet(
          id: fleet.id,
          name: fleet.name,
          shipIds: <int>[
            for (final shipId in fleet.shipIds)
              if (!shipIds.contains(shipId)) shipId,
          ],
          slotCount: fleet.slotCount,
          mission: fleet.mission,
        ),
    ];
    return state.copyWith(
      ships: ships,
      slotItems: slotItems,
      fleets: fleets,
      pendingExportShipIds: state.pendingExportShipIds.difference(shipIds),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  Set<int> _requestIds(Object? value) {
    final values = value is Iterable ? value : <Object?>[value];
    final ids = <int>{};
    for (final rawValue in values) {
      for (final part in rawValue.toString().split(',')) {
        final id = _asInt(part);
        if (id > 0) ids.add(id);
      }
    }
    return ids;
  }

  GameState _revalidateF96(GameState state, DateTime updatedAt) {
    final quest = state.quests[_f96QuestId];
    if (quest == null || !quest.isAccepted || quest.isServerCompleted) {
      return state;
    }
    final verified =
        state.hasFurnitureCoinData &&
        state.furnitureCoins >= _f96RequiredFurnitureCoins &&
        _slotItemCount(state.slotItems, _f96PreparedMasterId4) >= 4 &&
        _slotItemCount(state.slotItems, _f96PreparedMasterId6) >= 4;
    if (quest.localCompletionVerified == verified) return state;
    final quests = Map<int, GameQuest>.of(state.quests);
    quests[_f96QuestId] = quest.withLocalCompletionVerified(
      verified,
      updatedAt: updatedAt,
    );
    return state.copyWith(quests: quests);
  }

  int _slotItemCount(Map<int, OwnedSlotItem> items, int masterId) =>
      items.values.where((item) => item.masterSlotItemId == masterId).length;

  GameState applyFriendlyBattleHp(
    GameState state,
    Map<int, int> hpByShipId,
    DateTime capturedAt,
  ) {
    Map<int, OwnedShip>? updatedShips;
    for (final entry in hpByShipId.entries) {
      final ship = state.ships[entry.key];
      if (ship == null) continue;
      final currentHp = entry.value.clamp(0, ship.maxHp).toInt();
      if (currentHp == ship.currentHp) continue;
      updatedShips ??= Map<int, OwnedShip>.of(state.ships);
      updatedShips[ship.id] = _copyShip(ship, currentHp: currentHp);
    }
    if (updatedShips == null) return state;
    return state.copyWith(ships: updatedShips, updatedAt: capturedAt);
  }

  GameState _charge(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final ships = Map<int, OwnedShip>.of(state.ships);
    for (final value in _optionalList(data['api_ship'])) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final previous = ships[id];
      if (item == null || previous == null) {
        continue;
      }
      ships[id] = _copyShip(
        previous,
        currentFuel: _asInt(item['api_fuel'], previous.currentFuel),
        currentAmmo: _asInt(item['api_bull'], previous.currentAmmo),
        onSlot: item.containsKey('api_onslot')
            ? _intList(item['api_onslot'], includeNonPositive: true)
            : previous.onSlot,
      );
    }
    return state.copyWith(
      ships: ships,
      resources: _mergeResourceArray(
        state.resources,
        _optionalList(data['api_material']),
      ),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _slotSet(GameState state, CapturedApiEvent event, String origin) {
    final shipId = _asInt(event.requestParams['api_id']);
    final slotIndex = _asInt(event.requestParams['api_slot_idx'], -1);
    final itemId = _asInt(event.requestParams['api_item_id'], -1);
    final ship = state.ships[shipId];
    if (ship == null || slotIndex < 0) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }

    final slots = List<int>.of(ship.slotIds);
    while (slots.length <= slotIndex) {
      slots.add(-1);
    }
    slots[slotIndex] = itemId;
    return _replaceShip(state, _copyShip(ship, slotIds: slots), event, origin);
  }

  GameState _slotSetExtra(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final shipId = _asInt(event.requestParams['api_id']);
    final itemId = _asInt(event.requestParams['api_item_id'], -1);
    final ship = state.ships[shipId];
    if (ship == null) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }
    return _replaceShip(
      state,
      _copyShip(ship, extraSlotId: itemId),
      event,
      origin,
    );
  }

  GameState _unsetAllSlots(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final shipId = _asInt(event.requestParams['api_id']);
    final ship = state.ships[shipId];
    if (ship == null) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }
    return _replaceShip(
      state,
      _copyShip(ship, slotIds: List<int>.filled(ship.slotIds.length, -1)),
      event,
      origin,
    );
  }

  GameState _replaceShip(
    GameState state,
    OwnedShip ship,
    CapturedApiEvent event,
    String origin,
  ) {
    final previous = state.ships[ship.id];
    final slotsChanged =
        previous != null &&
        (previous.extraSlotId != ship.extraSlotId ||
            previous.slotIds.length != ship.slotIds.length ||
            Iterable<int>.generate(
              ship.slotIds.length,
            ).any((index) => previous.slotIds[index] != ship.slotIds[index]));
    return state.copyWith(
      ships: Map<int, OwnedShip>.of(state.ships)..[ship.id] = ship,
      pendingExportShipIds:
          slotsChanged &&
              const {
                '/kcsapi/api_req_kaisou/slotset',
                '/kcsapi/api_req_kaisou/slotset_ex',
                '/kcsapi/api_req_kaisou/unsetslot_all',
              }.contains(event.path)
          ? {...state.pendingExportShipIds, ship.id}
          : null,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _mergeActionShips(
    GameState state,
    List<Object?> values,
    CapturedApiEvent event,
    String origin,
  ) {
    final parsed = _parseShips(values, previous: state.ships);
    final ships = Map<int, OwnedShip>.of(state.ships)..addAll(parsed);
    return state.copyWith(
      ships: ships,
      pendingExportShipIds: _remainingExportShipIds(state, values),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  Set<int> _remainingExportShipIds(GameState state, List<Object?> values) {
    if (state.pendingExportShipIds.isEmpty) return state.pendingExportShipIds;
    final pending = {...state.pendingExportShipIds};
    for (final value in values) {
      final ship = _optionalMap(value);
      // A charge/partial response cannot confirm that displayed stats match
      // the new equipment. Wait for the authoritative ship response.
      if (ship != null &&
          _asInt(ship['api_ship_id']) > 0 &&
          ship['api_slot'] is List &&
          ship.containsKey('api_taisen')) {
        pending.remove(_asInt(ship['api_id']));
      }
    }
    return pending;
  }

  GameState _slotDeprive(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final shipData = _optionalMap(data['api_ship_data']);
    return _mergeActionShips(
      state,
      shipData?.values.toList() ?? const <Object?>[],
      event,
      origin,
    );
  }

  GameState _getShip(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final ships = Map<int, OwnedShip>.of(state.ships)
      ..addAll(_parseShips(<Object?>[data['api_ship']], previous: state.ships));
    final slotItems = Map<int, OwnedSlotItem>.of(state.slotItems)
      ..addAll(_parseSlotItems(_optionalList(data['api_slotitem'])));
    final parsedDocks = _parseConstructionDocks(
      _optionalList(data['api_kdock']),
    );
    final docksById = <int, ConstructionDock>{
      for (final dock in state.constructionDocks) dock.id: dock,
      for (final dock in parsedDocks) dock.id: dock,
    };
    final docks = docksById.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return state.copyWith(
      ships: ships,
      slotItems: slotItems,
      constructionDocks: docks,
      pendingExportShipIds: _remainingExportShipIds(state, [data['api_ship']]),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _missionStart(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final deckId = _asInt(event.requestParams['api_deck_id']);
    final missionId = _asInt(event.requestParams['api_mission_id']);
    final completionTime = _dateTimeFromMilliseconds(data['api_complatetime']);
    if (deckId <= 0 || missionId <= 0 || completionTime == null) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }
    final fleets = <Fleet>[
      for (final fleet in state.fleets)
        if (fleet.id == deckId)
          Fleet(
            id: fleet.id,
            name: fleet.name,
            shipIds: fleet.shipIds,
            slotCount: fleet.slotCount,
            mission: FleetMission(
              state: 1,
              missionId: missionId,
              completionTime: completionTime,
            ),
          )
        else
          fleet,
    ];
    return state.copyWith(
      fleets: fleets,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _repairSpeedChange(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final dockId = _asInt(event.requestParams['api_ndock_id']);
    final dock = state.repairDocks
        .where((candidate) => candidate.id == dockId)
        .firstOrNull;
    if (dock == null) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }
    final ships = Map<int, OwnedShip>.of(state.ships);
    final ship = ships[dock.shipId];
    if (ship != null) {
      ships[ship.id] = _copyShip(ship, currentHp: ship.maxHp);
    }
    final docks = <RepairDock>[
      for (final candidate in state.repairDocks)
        if (candidate.id == dockId) RepairDock(id: candidate.id) else candidate,
    ];
    return state.copyWith(
      ships: ships,
      repairDocks: docks,
      resources: _changeResource(
        state.resources,
        GameResourceType.instantRepair,
        -1,
      ),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _repairStart(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final dockId = _asInt(event.requestParams['api_ndock_id']);
    final shipId = _asInt(event.requestParams['api_ship_id']);
    final highSpeed = _asInt(event.requestParams['api_highspeed']) == 1;
    final ship = state.ships[shipId];
    if (dockId <= 0 || ship == null) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }

    var resources = _changeResource(
      state.resources,
      GameResourceType.fuel,
      -ship.repairFuelCost,
    );
    resources = _changeResource(
      resources,
      GameResourceType.steel,
      -ship.repairSteelCost,
    );
    final ships = Map<int, OwnedShip>.of(state.ships);
    var docks = state.repairDocks;
    if (highSpeed) {
      ships[shipId] = _copyShip(ship, currentHp: ship.maxHp);
      resources = _changeResource(
        resources,
        GameResourceType.instantRepair,
        -1,
      );
    } else {
      docks = <RepairDock>[
        for (final dock in state.repairDocks)
          if (dock.id == dockId)
            RepairDock(
              id: dock.id,
              state: 1,
              shipId: shipId,
              completionTime: event.capturedAt.add(
                Duration(milliseconds: ship.repairDurationMilliseconds),
              ),
              fuelCost: ship.repairFuelCost,
              steelCost: ship.repairSteelCost,
            )
          else
            dock,
      ];
    }
    return state.copyWith(
      ships: ships,
      repairDocks: docks,
      resources: resources,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _constructionSpeedChange(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final dockId = _asInt(event.requestParams['api_kdock_id']);
    final docks = <ConstructionDock>[
      for (final dock in state.constructionDocks)
        if (dock.id == dockId)
          ConstructionDock(
            id: dock.id,
            state: 3,
            createdShipMasterId: dock.createdShipMasterId,
            completionTime: event.capturedAt,
            startedAt: dock.startedAt,
            fuel: dock.fuel,
            ammunition: dock.ammunition,
            steel: dock.steel,
            bauxite: dock.bauxite,
            developmentMaterial: dock.developmentMaterial,
          )
        else
          dock,
    ];
    final dock = state.constructionDocks
        .where((candidate) => candidate.id == dockId)
        .firstOrNull;
    final bucketCost = dock?.isLargeConstruction == true ? 10 : 1;
    return state.copyWith(
      constructionDocks: docks,
      resources: _changeResource(
        state.resources,
        GameResourceType.instantBuild,
        -bucketCost,
      ),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  Map<int, GameQuest> _parseQuests(
    Map<String, Object?> data,
    Map<int, GameQuest> existing,
    DateTime updatedAt, {
    int minimumState = 2,
    bool retainOnlyReturned = false,
  }) {
    final quests = retainOnlyReturned
        ? <int, GameQuest>{}
        : Map<int, GameQuest>.of(existing);
    for (final value in _optionalList(data['api_list'])) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_no']);
      if (item == null || id <= 0) {
        continue;
      }
      final state = _asInt(item['api_state']);
      if (state < minimumState || state > 3) {
        quests.remove(id);
        continue;
      }
      final rawMaterials = _optionalList(item['api_get_material']);
      final previous = existing[id];
      final prior = previous != null && !previous.isExpired(updatedAt)
          ? previous
          : null;
      final materials = List<int>.generate(
        4,
        (index) =>
            index < rawMaterials.length ? _asInt(rawMaterials[index]) : 0,
        growable: false,
      );
      quests[id] = GameQuest(
        id: id,
        title: _asString(item['api_title']),
        detail: normalizeQuestDetail(_asString(item['api_detail'])),
        category: _asInt(item['api_category']),
        type: _asInt(item['api_type']),
        state: state,
        progressFlag: _asInt(item['api_progress_flag']),
        materials: materials,
        progressCurrent: _serverAlignedQuestCount(
          prior?.progressCurrent ?? _knownQuestGoals[id]?.initial ?? 0,
          _knownQuestGoals[id]?.required,
          _asInt(item['api_progress_flag']),
          state == 3,
        ),
        progressRequired: _knownQuestGoals[id]?.required,
        localCompletionVerified: id == _f96QuestId && state != 3
            ? false
            : prior?.localCompletionVerified,
        updatedAt: updatedAt,
      );
    }
    return quests;
  }

  GameState _applyKnownQuestProgress(
    GameState state,
    CapturedApiEvent event,
    Object? data,
  ) {
    final events = <_QuestProgressEvent>[];
    switch (event.path) {
      case '/kcsapi/api_req_nyukyo/start':
        events.add(_QuestProgressEvent.repair);
      case '/kcsapi/api_req_hokyu/charge':
        events.add(_QuestProgressEvent.supply);
      case '/kcsapi/api_req_kousyou/createitem':
        events.add(_QuestProgressEvent.createItem);
      case '/kcsapi/api_req_kousyou/createship':
        events.add(_QuestProgressEvent.createShip);
      case '/kcsapi/api_req_mission/result':
        final result = _optionalMap(data);
        if (_asInt(result?['api_clear_result']) > 0) {
          events.add(_QuestProgressEvent.missionSuccess);
        }
      case '/kcsapi/api_req_sortie/battleresult':
        events.add(_QuestProgressEvent.battle);
        final result = _optionalMap(data);
        if (<String>{
          'S',
          'A',
          'B',
        }.contains(_asString(result?['api_win_rank']))) {
          events.add(_QuestProgressEvent.battleWin);
        }
      case '/kcsapi/api_req_practice/battle_result':
        events.add(_QuestProgressEvent.practice);
        final result = _optionalMap(data);
        if (<String>{
          'S',
          'A',
          'B',
        }.contains(_asString(result?['api_win_rank']))) {
          events.add(_QuestProgressEvent.practiceWin);
        }
    }
    if (events.isEmpty || state.quests.isEmpty) return state;

    var changed = false;
    final quests = <int, GameQuest>{};
    for (final entry in state.quests.entries) {
      final goal = _knownQuestGoals[entry.key];
      final quest = entry.value;
      if (goal != null && quest.isAccepted && events.contains(goal.event)) {
        final next = quest.incrementExactProgress(
          1,
          updatedAt: event.capturedAt,
        );
        quests[entry.key] = next;
        changed = changed || !identical(next, quest);
      } else {
        quests[entry.key] = quest;
      }
    }
    return changed ? state.copyWith(quests: quests) : state;
  }

  bool _isCompleteQuestList(Map<String, Object?> data, CapturedApiEvent event) {
    if (_asInt(event.requestParams['api_tab_id'], -1) != 0 ||
        _asInt(data['api_page_count']) > 1 ||
        data['api_list'] is! List) {
      return false;
    }
    final rows = _optionalList(
      data['api_list'],
    ).map(_optionalMap).whereType<Map<String, Object?>>().toList();
    if (rows.any(
      (q) =>
          _asInt(q['api_no']) <= 0 ||
          _asInt(q['api_state']) < 1 ||
          _asInt(q['api_state']) > 3,
    )) {
      return false;
    }
    final ids = rows.map((q) => _asInt(q['api_no'])).toSet();
    return ids.length == rows.length &&
        ids.length == _asInt(data['api_count'], -1) &&
        rows.where((q) => _asInt(q['api_state']) >= 2).length ==
            _asInt(data['api_exec_count'], -1);
  }

  GameState _acceptQuest(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final id = _asInt(event.requestParams['api_quest_id']);
    final quest = state.quests[id] ?? state.availableQuests[id];
    if (quest == null || quest.isAccepted) {
      return state.copyWith(hasCompleteQuestData: false);
    }
    final accepted = quest.withState(2);
    return state.copyWith(
      quests: {...state.quests, id: accepted},
      availableQuests: {...state.availableQuests, id: accepted},
      hasCompleteQuestData: false,
      activeQuestCount: state.activeQuestCount + 1,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _questList(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final activeCount = _asInt(data['api_exec_count']).clamp(0, 99);
    final isCompleteSnapshot =
        _asInt(event.requestParams['yahagi_full_quest_snapshot']) == 1 ||
        _isCompleteQuestList(data, event);
    final quests = _parseQuests(
      data,
      state.quests,
      event.capturedAt,
      retainOnlyReturned: isCompleteSnapshot,
    );
    final availableQuests = _parseQuests(
      data,
      {...state.availableQuests, ...state.quests},
      event.capturedAt,
      minimumState: 1,
      retainOnlyReturned: isCompleteSnapshot,
    );
    return state.copyWith(
      quests: quests,
      availableQuests: availableQuests,
      hasQuestData: true,
      hasCompleteQuestData: isCompleteSnapshot,
      activeQuestCount: activeCount,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _removeQuest(
    GameState state,
    int questId,
    CapturedApiEvent event,
    String origin,
  ) {
    if (questId <= 0) {
      return state;
    }
    final quests = Map<int, GameQuest>.of(state.quests);
    quests.remove(questId);
    final availableQuests = Map<int, GameQuest>.of(state.availableQuests);
    final quest = state.quests[questId] ?? availableQuests[questId];
    if (event.path.endsWith('/stop') && quest != null) {
      availableQuests[questId] = quest.withState(1);
    } else {
      availableQuests.remove(questId);
    }
    return state.copyWith(
      quests: quests,
      availableQuests: availableQuests,
      hasCompleteQuestData: false,
      activeQuestCount: state.activeQuestCount > 0
          ? state.activeQuestCount - 1
          : 0,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _formationChange(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final deckId = _asInt(event.requestParams['api_id']);
    final position = _asInt(event.requestParams['api_ship_idx'], -1);
    final nextShipId = _asInt(event.requestParams['api_ship_id']);
    final targetFleetIndex = state.fleets.indexWhere(
      (fleet) => fleet.id == deckId,
    );
    if (targetFleetIndex < 0) {
      return state;
    }

    final targetFleet = state.fleets[targetFleetIndex];
    final fleets = List<Fleet>.of(state.fleets);

    // This mirrors Poi's formation reducer: -2 keeps only the flagship.
    if (nextShipId == -2) {
      fleets[targetFleetIndex] = Fleet(
        id: targetFleet.id,
        name: targetFleet.name,
        shipIds: targetFleet.shipIds.take(1).toList(growable: false),
        slotCount: targetFleet.slotCount,
        mission: targetFleet.mission,
      );
      return state.copyWith(
        fleets: fleets,
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      );
    }

    if (position < 0 || position >= targetFleet.slotCount) {
      return state;
    }

    final previousShipId = position < targetFleet.shipIds.length
        ? targetFleet.shipIds[position]
        : -1;
    var sourceFleetIndex = -1;
    var sourcePosition = -1;
    if (nextShipId > 0) {
      for (var index = 0; index < fleets.length; index++) {
        final found = fleets[index].shipIds.indexOf(nextShipId);
        if (found >= 0) {
          sourceFleetIndex = index;
          sourcePosition = found;
          break;
        }
      }
    }

    // Set the destination first, then put the displaced ship back at the
    // source position. The order is significant for same-fleet swaps.
    fleets[targetFleetIndex] = _setFleetShip(
      fleets[targetFleetIndex],
      position,
      nextShipId,
    );
    if (sourceFleetIndex >= 0) {
      fleets[sourceFleetIndex] = _setFleetShip(
        fleets[sourceFleetIndex],
        sourcePosition,
        previousShipId,
      );
    }

    return state.copyWith(
      fleets: fleets,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _formationPresetSelect(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final parsed = _parseFleets(<Object?>[data]);
    if (parsed.isEmpty) {
      return state;
    }
    final replacement = parsed.single;
    final fleets = <Fleet>[
      for (final fleet in state.fleets)
        if (fleet.id == replacement.id) replacement else fleet,
    ];
    if (!fleets.any((fleet) => fleet.id == replacement.id)) {
      fleets.add(replacement);
      fleets.sort((a, b) => a.id.compareTo(b.id));
    }
    return state.copyWith(
      fleets: fleets,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  Fleet _setFleetShip(Fleet fleet, int position, int shipId) {
    final slots = List<int>.generate(
      fleet.slotCount,
      (index) => index < fleet.shipIds.length ? fleet.shipIds[index] : -1,
    );
    if (shipId == -1) {
      slots.removeAt(position);
      slots.add(-1);
    } else {
      slots[position] = shipId;
    }
    return Fleet(
      id: fleet.id,
      name: fleet.name,
      shipIds: slots.where((id) => id > 0).toList(growable: false),
      slotCount: fleet.slotCount,
      mission: fleet.mission,
    );
  }

  GameState _start2(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    // A fresh login may deliver require_info before the member identity.
    state = _clearMemberData(state);
    final shipTypes = _parseMasterShipTypes(
      _optionalList(data['api_mst_stype']),
    );
    final shipEquipOverrides = _optionalMap(data['api_mst_equip_ship']);
    final expansionSlotEquipmentTypeIds = Set<int>.unmodifiable(
      _intList(data['api_mst_equip_exslot']).where((id) => id > 0),
    );
    final expansionSlotSpecialRules = _parseExpansionSlotSpecialRules(
      _optionalMap(data['api_mst_equip_exslot_ship']),
    );
    final expansionSlotLimitsByShipId = _parseExpansionSlotLimits(
      _optionalMap(data['api_mst_equip_limit_exslot']),
    );
    final hasEquipmentCompatibilityData =
        data['api_mst_equip_ship'] is Map &&
        data['api_mst_equip_exslot'] is List &&
        data['api_mst_equip_exslot_ship'] is Map &&
        data['api_mst_equip_limit_exslot'] is Map;
    final portraitData = <int, ({String? fileName, String? version})>{};
    for (final value in _optionalList(data['api_mst_shipgraph'])) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      if (item == null || id <= 0) {
        continue;
      }
      final versions = _optionalList(item['api_version']);
      portraitData[id] = (
        fileName: _nullableString(item['api_filename']),
        version: versions.isEmpty ? null : _nullableString(versions.first),
      );
    }

    final ships = <int, MasterShip>{};
    for (final value in _optionalList(data['api_mst_ship'])) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final name = _asString(item?['api_name']);
      if (item == null || id <= 0 || name.isEmpty) {
        continue;
      }
      final portrait = portraitData[id];
      final shipTypeId = _asInt(item['api_stype']);
      final shipOverride = _optionalMap(shipEquipOverrides?['$id']);
      final shipOverrideTypes = _optionalMap(shipOverride?['api_equip_type']);
      final equipTypeIds = shipOverride == null
          ? shipTypes[shipTypeId]?.equipTypeIds ?? const <int>{}
          : _positiveIntKeys(shipOverrideTypes, requireEnabledValue: false);
      final antiSubRange = _optionalList(item['api_tais']);
      ships[id] = MasterShip(
        id: id,
        name: name,
        reading: _asString(item['api_yomi'], ''),
        shipTypeId: shipTypeId,
        afterShipId: _asInt(item['api_aftershipid']),
        sortNo: _asInt(item['api_sortno']),
        classTypeId: _asInt(item['api_ctype']),
        speed: _asInt(item['api_soku']),
        range: _asInt(item['api_leng']),
        maxFuel: _asInt(item['api_fuel_max']),
        maxAmmo: _asInt(item['api_bull_max']),
        slotCount: _asInt(item['api_slot_num']),
        slotCapacities: _intList(item['api_maxeq'], includeNonPositive: true),
        buildTimeMinutes: _asInt(item['api_buildtime']),
        baseAntiSub: antiSubRange.isEmpty ? 0 : _asInt(antiSubRange.first),
        equipTypeIds: equipTypeIds,
        limitedEquipmentIdsByType: _parseLimitedEquipmentIdsByType(
          shipOverrideTypes,
        ),
        portraitFileName: portrait?.fileName,
        portraitVersion: portrait?.version,
      );
    }

    return state.copyWith(
      masterShipTypes: shipTypes,
      masterShips: ships,
      masterSlotItems: _parseMasterSlotItems(
        _optionalList(data['api_mst_slotitem']),
      ),
      masterSlotItemTypes: _parseIdNameMap(
        _optionalList(data['api_mst_slotitem_equiptype']),
      ),
      expansionSlotEquipmentTypeIds: expansionSlotEquipmentTypeIds,
      expansionSlotSpecialRules: expansionSlotSpecialRules,
      expansionSlotLimitsByShipId: expansionSlotLimitsByShipId,
      hasEquipmentCompatibilityData: hasEquipmentCompatibilityData,
      masterMissions: _parseMasterMissions(
        _optionalList(data['api_mst_mission']),
      ),
      masterMapInfos: _parseMasterMapInfos(
        _optionalList(data['api_mst_mapinfo']),
      ),
      masterMapAreas: _parseIdNameMap(_optionalList(data['api_mst_maparea'])),
      serverOrigin: origin,
      hasMasterData: ships.isNotEmpty,
      updatedAt: event.capturedAt,
    );
  }

  GameState _clearMemberData(GameState state) => GameState(
    masterShipTypes: state.masterShipTypes,
    masterShips: state.masterShips,
    masterSlotItems: state.masterSlotItems,
    masterSlotItemTypes: state.masterSlotItemTypes,
    expansionSlotEquipmentTypeIds: state.expansionSlotEquipmentTypeIds,
    expansionSlotSpecialRules: state.expansionSlotSpecialRules,
    expansionSlotLimitsByShipId: state.expansionSlotLimitsByShipId,
    hasEquipmentCompatibilityData: state.hasEquipmentCompatibilityData,
    masterMissions: state.masterMissions,
    masterMapInfos: state.masterMapInfos,
    masterMapAreas: state.masterMapAreas,
    hasMasterData: state.hasMasterData,
    serverOrigin: state.serverOrigin,
  );

  GameState _forMember(GameState state, int memberId) =>
      state.memberId > 0 && memberId > 0 && state.memberId != memberId
      ? _clearMemberData(state)
      : state;

  GameState _basic(
    GameState state,
    Map<String, Object?> basic,
    CapturedApiEvent event,
    String origin,
  ) => _forMember(state, _asInt(basic['api_member_id'])).copyWith(
    memberId: _asInt(basic['api_member_id']),
    admiralLevel: _asInt(basic['api_level']),
    maxShipCount: basic.containsKey('api_max_chara')
        ? _asInt(basic['api_max_chara'])
        : null,
    maxEquipmentCount: basic.containsKey('api_max_slotitem')
        ? _equipmentCapacityFromApi(basic['api_max_slotitem'])
        : null,
    furnitureCoins: basic.containsKey('api_fcoin')
        ? _asInt(basic['api_fcoin'])
        : null,
    hasFurnitureCoinData: basic.containsKey('api_fcoin') ? true : null,
    serverOrigin: origin,
    updatedAt: event.capturedAt,
  );

  GameState _snapshot(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin, {
    bool hasPortData = false,
  }) {
    final basic = _optionalMap(data['api_basic']);
    state = _forMember(state, _asInt(basic?['api_member_id']));
    return state.copyWith(
      memberId: basic == null ? null : _asInt(basic['api_member_id']),
      admiralLevel: basic == null ? null : _asInt(basic['api_level']),
      maxShipCount: basic?.containsKey('api_max_chara') == true
          ? _asInt(basic!['api_max_chara'])
          : null,
      maxEquipmentCount: basic?.containsKey('api_max_slotitem') == true
          ? _equipmentCapacityFromApi(basic!['api_max_slotitem'])
          : null,
      furnitureCoins: basic?.containsKey('api_fcoin') == true
          ? _asInt(basic!['api_fcoin'])
          : null,
      hasFurnitureCoinData: basic?.containsKey('api_fcoin') == true
          ? true
          : null,
      resources: data.containsKey('api_material')
          ? _parseResources(
              _optionalList(data['api_material']),
              state.resources,
            )
          : null,
      useItems: data.containsKey('api_useitem')
          ? _parseUseItems(_optionalList(data['api_useitem']))
          : null,
      hasUseItemData: data.containsKey('api_useitem') ? true : null,
      ships: data.containsKey('api_ship')
          ? _parseShips(_optionalList(data['api_ship']))
          : null,
      fleets: data.containsKey('api_deck_port')
          ? _parseFleets(_optionalList(data['api_deck_port']))
          : data.containsKey('api_deck')
          ? _parseFleets(_optionalList(data['api_deck']))
          : null,
      repairDocks: data.containsKey('api_ndock')
          ? _parseRepairDocks(_optionalList(data['api_ndock']))
          : null,
      constructionDocks: data.containsKey('api_kdock')
          ? _parseConstructionDocks(_optionalList(data['api_kdock']))
          : null,
      combinedFleetType: data.containsKey('api_combined_flag')
          ? CombinedFleetType.fromApiValue(_asInt(data['api_combined_flag']))
          : null,
      questCapacity: data.containsKey('api_parallel_quest_count')
          ? _asInt(data['api_parallel_quest_count'], state.questCapacity)
          : null,
      slotItems: data.containsKey('api_slot_item')
          ? _parseSlotItems(_optionalList(data['api_slot_item']))
          : null,
      hasEquipmentInventory: data['api_slot_item'] is List ? true : null,
      pendingExportShipIds: hasPortData && data['api_ship'] is List
          ? const <int>{}
          : _remainingExportShipIds(state, _optionalList(data['api_ship'])),
      serverOrigin: origin,
      hasPortData: hasPortData ? true : null,
      combatState: hasPortData ? CombatState.empty : null,
      updatedAt: event.capturedAt,
    );
  }

  GameState _portSnapshot(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin, {
    bool hasPortData = false,
  }) {
    final snapshot = _snapshot(
      state,
      data,
      event,
      origin,
      hasPortData: hasPortData,
    );
    return snapshot.copyWith(
      landBases: <LandBaseState>[
        for (final base in snapshot.landBases) base.copyWith(clearHp: true),
      ],
    );
  }

  GameState _mapInfo(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final mapDifficulties = Map<int, int>.from(state.mapDifficulties);
    // mapinfo is an authoritative snapshot. Maps omitted from the response are
    // currently unavailable and must not retain stale gauge progress.
    final memberMapInfos = <int, MemberMapInfo>{};

    for (final value in _optionalList(data['api_map_info'])) {
      final item = _optionalMap(value);
      final mapId = _asInt(item?['api_id']);
      if (item == null || mapId <= 0) continue;

      MasterMapInfo? master;
      for (final candidate in state.masterMapInfos.values) {
        if (candidate.id == mapId) {
          master = candidate;
          break;
        }
      }
      final areaId = master?.mapAreaId ?? (mapId >= 10 ? mapId ~/ 10 : mapId);
      final mapNo = master?.mapNo ?? (mapId >= 10 ? mapId % 10 : 1);
      if (areaId <= 0 || mapNo <= 0) continue;
      final key = areaId * 100 + mapNo;

      final cleared = _asInt(item['api_cleared']) > 0;
      final defeatCount = item['api_defeat_count'] != null
          ? _asInt(item['api_defeat_count'])
          : null;
      var requiredDefeatCount = item['api_required_defeat_count'] != null
          ? _asInt(item['api_required_defeat_count'])
          : master?.requiredDefeatCount;
      if ((requiredDefeatCount == null || requiredDefeatCount <= 0) &&
          _knownDefaultRequiredDefeatCounts.containsKey(key)) {
        requiredDefeatCount = _knownDefaultRequiredDefeatCounts[key];
      }

      final eventMap = _optionalMap(item['api_eventmap']);
      final rank = _asInt(eventMap?['api_selected_rank']);
      if (rank > 0) {
        mapDifficulties[key] = rank;
      } else {
        mapDifficulties.remove(key);
      }

      final gaugeType = item['api_gauge_type'] != null
          ? _asInt(item['api_gauge_type'])
          : null;
      final gaugeNum = item['api_gauge_num'] != null
          ? _asInt(item['api_gauge_num'])
          : null;
      final gaugeMaxNum = item['api_gauge_max_num'] != null
          ? _asInt(item['api_gauge_max_num'])
          : (eventMap != null && eventMap['api_gauge_max_num'] != null
                ? _asInt(eventMap['api_gauge_max_num'])
                : null);

      final currentHp = eventMap != null && eventMap['api_now_maphp'] != null
          ? _asInt(eventMap['api_now_maphp'])
          : (item['api_now_maphp'] != null
                ? _asInt(item['api_now_maphp'])
                : null);
      final maxHp = eventMap != null && eventMap['api_max_maphp'] != null
          ? _asInt(eventMap['api_max_maphp'])
          : (item['api_max_maphp'] != null
                ? _asInt(item['api_max_maphp'])
                : master?.maxMapHp);

      memberMapInfos[key] = MemberMapInfo(
        id: mapId,
        mapAreaId: areaId,
        mapNo: mapNo,
        name: master?.name ?? '',
        operationText: master?.operationText ?? '',
        cleared: cleared,
        defeatCount: defeatCount,
        requiredDefeatCount: requiredDefeatCount,
        currentHp: currentHp,
        maxHp: maxHp,
        gaugeType:
            gaugeType ??
            (eventMap != null ? _asInt(eventMap['api_gauge_type']) : null),
        gaugeNum:
            gaugeNum ??
            (eventMap != null ? _asInt(eventMap['api_gauge_num']) : null),
        gaugeMaxNum: gaugeMaxNum,
        selectedRank: rank > 0 ? rank : null,
        isEvent: eventMap != null || areaId >= 20,
      );
    }

    List<LandBaseState>? bases;
    if (data.containsKey('api_air_base')) {
      bases = _parseLandBases(_optionalList(data['api_air_base']));
    }
    return state.copyWith(
      landBases: bases,
      mapDifficulties: mapDifficulties,
      memberMapInfos: memberMapInfos,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  List<LandBaseState> _parseLandBases(List<Object?> values) {
    final bases = <LandBaseState>[];
    for (final value in values) {
      final item = _optionalMap(value);
      final areaId = _asInt(item?['api_area_id']);
      final baseId = _asInt(item?['api_rid']);
      if (item == null || areaId <= 0 || baseId <= 0) continue;
      bases.add(
        LandBaseState(
          areaId: areaId,
          baseId: baseId,
          name: _asString(item['api_name'], '第 $baseId 基地航空队'),
          actionKind: _asInt(item['api_action_kind']),
          distanceBase: _asInt(_optionalMap(item['api_distance'])?['api_base']),
          distanceBonus: _asInt(
            _optionalMap(item['api_distance'])?['api_bonus'],
          ),
          squadrons: _mergeLandBaseSquadrons(
            const <LandBaseSquadronState>[],
            _optionalList(item['api_plane_info']),
          ),
        ),
      );
    }
    bases.sort((left, right) {
      final byArea = left.areaId.compareTo(right.areaId);
      return byArea != 0 ? byArea : left.baseId.compareTo(right.baseId);
    });
    return bases;
  }

  GameState _expandLandBases(
    GameState state,
    List<Object?> values,
    CapturedApiEvent event,
    String origin,
  ) {
    final basesById = <(int, int), LandBaseState>{
      for (final base in state.landBases) (base.areaId, base.baseId): base,
      for (final base in _parseLandBases(values))
        (base.areaId, base.baseId): base,
    };
    final bases = basesById.values.toList()
      ..sort((left, right) {
        final byArea = left.areaId.compareTo(right.areaId);
        return byArea != 0 ? byArea : left.baseId.compareTo(right.baseId);
      });
    return state.copyWith(
      landBases: bases,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _selectEventMapRank(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final areaId = _asInt(event.requestParams['api_maparea_id']);
    final mapNo = _asInt(event.requestParams['api_map_no']);
    final rank = _asInt(event.requestParams['api_rank']);
    final key = areaId * 100 + mapNo;
    final mapDifficulties = Map<int, int>.of(state.mapDifficulties);
    if (rank > 0) {
      mapDifficulties[key] = rank;
    } else {
      mapDifficulties.remove(key);
    }

    final rawMapHp = _optionalMap(data['api_maphp']);
    final memberMapInfos = Map<int, MemberMapInfo>.of(state.memberMapInfos);
    final existing = memberMapInfos[key];
    if (existing != null || rawMapHp != null) {
      final nowHp = rawMapHp != null && rawMapHp['api_now_maphp'] != null
          ? _asInt(rawMapHp['api_now_maphp'])
          : existing?.currentHp;
      final maxHp = rawMapHp != null && rawMapHp['api_max_maphp'] != null
          ? _asInt(rawMapHp['api_max_maphp'])
          : existing?.maxHp;
      final gaugeType = rawMapHp != null && rawMapHp['api_gauge_type'] != null
          ? _asInt(rawMapHp['api_gauge_type'])
          : existing?.gaugeType;
      final gaugeNum = rawMapHp != null && rawMapHp['api_gauge_num'] != null
          ? _asInt(rawMapHp['api_gauge_num'])
          : existing?.gaugeNum;
      final gaugeMaxNum =
          rawMapHp != null && rawMapHp['api_gauge_max_num'] != null
          ? _asInt(rawMapHp['api_gauge_max_num'])
          : existing?.gaugeMaxNum;

      if (existing != null) {
        memberMapInfos[key] = existing.copyWith(
          selectedRank: rank > 0 ? rank : null,
          currentHp: nowHp,
          maxHp: maxHp,
          gaugeType: gaugeType,
          gaugeNum: gaugeNum,
          gaugeMaxNum: gaugeMaxNum,
        );
      }
    }

    return state.copyWith(
      mapDifficulties: mapDifficulties,
      memberMapInfos: memberMapInfos,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _updateLandBasePlanes(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final areaId = _asInt(event.requestParams['api_area_id']);
    final baseId = _asInt(event.requestParams['api_base_id']);
    final index = state.landBases.indexWhere(
      (base) => base.areaId == areaId && base.baseId == baseId,
    );
    if (index < 0 || !data.containsKey('api_plane_info')) return state;

    final previous = state.landBases[index];
    final distance = _optionalMap(data['api_distance']);
    final updated = previous.copyWith(
      distanceBase: distance != null && distance.containsKey('api_base')
          ? _asInt(distance['api_base'])
          : null,
      distanceBonus: distance != null && distance.containsKey('api_bonus')
          ? _asInt(distance['api_bonus'])
          : null,
      squadrons: _mergeLandBaseSquadrons(
        previous.squadrons,
        _optionalList(data['api_plane_info']),
      ),
    );
    return state.copyWith(
      landBases: <LandBaseState>[
        for (var i = 0; i < state.landBases.length; i++)
          if (i == index) updated else state.landBases[i],
      ],
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _updateLandBasePlanesIfPresent(
    GameState state,
    Object? data,
    CapturedApiEvent event,
    String origin,
  ) {
    final planeData = _optionalMap(data);
    return planeData == null
        ? state
        : _updateLandBasePlanes(state, planeData, event, origin);
  }

  GameState _changeLandBaseDeployment(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final areaId = _asInt(event.requestParams['api_area_id']);
    final items = _optionalList(data['api_base_items']);
    if (areaId <= 0 || items.isEmpty) return state;
    final bases = <LandBaseState>[...state.landBases];
    var changed = false;
    for (final value in items) {
      final item = _optionalMap(value);
      final baseId = _asInt(item?['api_rid']);
      final index = bases.indexWhere(
        (base) => base.areaId == areaId && base.baseId == baseId,
      );
      if (item == null || index < 0 || !item.containsKey('api_plane_info')) {
        continue;
      }
      final previous = bases[index];
      final distance = _optionalMap(item['api_distance']);
      bases[index] = previous.copyWith(
        distanceBase: distance != null && distance.containsKey('api_base')
            ? _asInt(distance['api_base'])
            : null,
        distanceBonus: distance != null && distance.containsKey('api_bonus')
            ? _asInt(distance['api_bonus'])
            : null,
        squadrons: _mergeLandBaseSquadrons(
          previous.squadrons,
          _optionalList(item['api_plane_info']),
        ),
      );
      changed = true;
    }
    return changed
        ? state.copyWith(
            landBases: bases,
            serverOrigin: origin,
            updatedAt: event.capturedAt,
          )
        : state;
  }

  GameState _setLandBaseAction(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final areaId = _asInt(event.requestParams['api_area_id']);
    // These are parallel CSV lists, not sets of IDs. Action 0 is standby,
    // and several bases may receive the same action in one request.
    List<int> requestValues(String key) => event.requestParams[key]
        .toString()
        .split(',')
        .map((value) => _asInt(value, -1))
        .toList();
    final baseIds = requestValues('api_base_id');
    final actions = requestValues('api_action_kind');
    if (areaId <= 0 ||
        baseIds.any((id) => id <= 0) ||
        actions.any((action) => action < 0) ||
        baseIds.length != actions.length) {
      return state;
    }
    var changed = false;
    final bases = <LandBaseState>[
      for (final base in state.landBases)
        if (base.areaId == areaId && baseIds.contains(base.baseId))
          () {
            final action = actions[baseIds.indexOf(base.baseId)];
            changed = true;
            return base.copyWith(actionKind: action);
          }()
        else
          base,
    ];
    return changed
        ? state.copyWith(
            landBases: bases,
            serverOrigin: origin,
            updatedAt: event.capturedAt,
          )
        : state;
  }

  GameState _changeLandBaseName(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final areaId = _asInt(event.requestParams['api_area_id']);
    final baseId = _asInt(event.requestParams['api_base_id']);
    final name = _asString(event.requestParams['api_name']);
    final index = state.landBases.indexWhere(
      (base) => base.areaId == areaId && base.baseId == baseId,
    );
    if (index < 0 || name.isEmpty) return state;
    return state.copyWith(
      landBases: <LandBaseState>[
        for (var i = 0; i < state.landBases.length; i++)
          if (i == index)
            state.landBases[i].copyWith(name: name)
          else
            state.landBases[i],
      ],
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  static List<LandBaseSquadronState> _mergeLandBaseSquadrons(
    List<LandBaseSquadronState> existing,
    List<Object?> values,
  ) {
    final result = <LandBaseSquadronState>[...existing];
    for (final value in values) {
      final item = _optionalMap(value);
      final squadronId = _asInt(item?['api_squadron_id']);
      if (item == null || squadronId <= 0) continue;
      final index = result.indexWhere(
        (squadron) => squadron.squadronId == squadronId,
      );
      final previous = index >= 0
          ? result[index]
          : LandBaseSquadronState(squadronId: squadronId);
      final updated = previous.copyWith(
        state: item.containsKey('api_state') ? _asInt(item['api_state']) : null,
        slotItemId: item.containsKey('api_slotid')
            ? _asInt(item['api_slotid'])
            : null,
        currentCount: item.containsKey('api_count')
            ? _asInt(item['api_count'])
            : null,
        maxCount: item.containsKey('api_max_count')
            ? _asInt(item['api_max_count'])
            : null,
        condition: item.containsKey('api_cond')
            ? _asInt(item['api_cond'])
            : null,
      );
      if (index >= 0) {
        result[index] = updated;
      } else {
        result.add(updated);
      }
    }
    result.sort((left, right) => left.squadronId.compareTo(right.squadronId));
    return result;
  }

  GameState _shipAndDeck(
    GameState state,
    Object? data,
    CapturedApiEvent event,
    String origin,
  ) {
    if (data is List) {
      final newShips = _parseShips(
        List<Object?>.from(data),
        previous: state.ships,
      );
      final mergedShips = Map<int, OwnedShip>.from(state.ships)
        ..addAll(newShips);
      return state.copyWith(
        ships: mergedShips,
        pendingExportShipIds: _remainingExportShipIds(
          state,
          List<Object?>.from(data),
        ),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      );
    }
    final map = _requiredMap(data, 'ship data');
    final shipData =
        map['api_ship_data'] ?? map['api_ship'] ?? map['api_ship_data_list'];
    final deckData = map['api_deck_data'] ?? map['api_deck'];
    if (shipData == null && deckData == null) {
      throw const GameApiParseException('舰娘接口缺少舰娘和舰队数据');
    }

    Map<int, OwnedShip>? mergedShips;
    if (shipData != null) {
      final newShips = _parseShips(
        _optionalList(shipData),
        previous: state.ships,
      );
      mergedShips = Map<int, OwnedShip>.from(state.ships)..addAll(newShips);
    }

    List<Fleet>? mergedFleets;
    if (deckData != null) {
      final newFleets = _parseFleets(_optionalList(deckData));
      final newFleetsMap = <int, Fleet>{for (final f in newFleets) f.id: f};
      final Set<int> processedIds = {};
      mergedFleets = state.fleets.map((f) {
        processedIds.add(f.id);
        return newFleetsMap.containsKey(f.id) ? newFleetsMap[f.id]! : f;
      }).toList();
      for (final nf in newFleets) {
        if (!processedIds.contains(nf.id)) {
          mergedFleets.add(nf);
        }
      }
      mergedFleets.sort((a, b) => a.id.compareTo(b.id));
    }

    return state.copyWith(
      ships: mergedShips ?? state.ships,
      fleets: mergedFleets ?? state.fleets,
      pendingExportShipIds: _remainingExportShipIds(
        state,
        _optionalList(shipData),
      ),
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _constructionStart(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final rawDock = data['api_kdock'];
    final values = rawDock is List
        ? List<Object?>.from(rawDock)
        : rawDock == null
        ? const <Object?>[]
        : <Object?>[rawDock];
    final updatedDocks = _parseConstructionDocks(
      values,
      startedAt: event.capturedAt,
    );
    if (updatedDocks.isEmpty) {
      return state.copyWith(serverOrigin: origin, updatedAt: event.capturedAt);
    }
    final docksById = <int, ConstructionDock>{
      for (final dock in state.constructionDocks) dock.id: dock,
      for (final dock in updatedDocks) dock.id: dock,
    };
    final docks = docksById.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return state.copyWith(
      constructionDocks: docks,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  Map<int, int> _parseUseItems(List<Object?> values) {
    final result = <int, int>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      if (id <= 0) continue;
      result[id] = _asInt(item?['api_count']).clamp(0, 1 << 31).toInt();
    }
    return result;
  }

  Map<GameResourceType, int> _parseResources(
    List<Object?> values,
    Map<GameResourceType, int> previous,
  ) {
    final result = Map<GameResourceType, int>.of(previous);
    for (final value in values) {
      final item = _optionalMap(value);
      final type = GameResourceType.fromApiId(_asInt(item?['api_id']));
      if (item == null || type == null) {
        continue;
      }
      result[type] = _asInt(item['api_value']);
    }
    return result;
  }

  Map<GameResourceType, int> _mergeResourceArray(
    Map<GameResourceType, int> previous,
    List<Object?> values,
  ) {
    final result = Map<GameResourceType, int>.of(previous);
    for (var index = 0; index < values.length; index++) {
      final type = GameResourceType.fromApiId(index + 1);
      if (type != null) {
        result[type] = _asInt(values[index], result[type] ?? 0);
      }
    }
    return result;
  }

  Map<GameResourceType, int> _changeResource(
    Map<GameResourceType, int> previous,
    GameResourceType type,
    int delta,
  ) {
    final result = Map<GameResourceType, int>.of(previous);
    result[type] = ((result[type] ?? 0) + delta).clamp(0, 999999);
    return result;
  }

  OwnedShip _copyShip(
    OwnedShip ship, {
    int? currentHp,
    int? currentFuel,
    int? currentAmmo,
    List<int>? slotIds,
    List<int>? onSlot,
    int? extraSlotId,
    List<int>? maxSlotCounts,
  }) {
    return OwnedShip(
      id: ship.id,
      masterId: ship.masterId,
      level: ship.level,
      currentHp: currentHp ?? ship.currentHp,
      maxHp: ship.maxHp,
      condition: ship.condition,
      currentFuel: currentFuel ?? ship.currentFuel,
      currentAmmo: currentAmmo ?? ship.currentAmmo,
      experience: ship.experience,
      nextExperience: ship.nextExperience,
      firepower: ship.firepower,
      firepowerMax: ship.firepowerMax,
      torpedo: ship.torpedo,
      torpedoMax: ship.torpedoMax,
      antiAir: ship.antiAir,
      antiAirMax: ship.antiAirMax,
      antiSub: ship.antiSub,
      lineOfSight: ship.lineOfSight,
      armor: ship.armor,
      armorMax: ship.armorMax,
      evasion: ship.evasion,
      luck: ship.luck,
      luckMax: ship.luckMax,
      modernization: ship.modernization,
      sallyArea: ship.sallyArea,
      specialEffectKinds: ship.specialEffectKinds,
      maxSlotCounts: maxSlotCounts ?? ship.maxSlotCounts,
      speed: ship.speed,
      range: ship.range,
      slotIds: slotIds ?? ship.slotIds,
      onSlot: onSlot ?? ship.onSlot,
      extraSlotId: extraSlotId ?? ship.extraSlotId,
      repairDurationMilliseconds: ship.repairDurationMilliseconds,
      repairFuelCost: ship.repairFuelCost,
      repairSteelCost: ship.repairSteelCost,
      locked: ship.locked,
    );
  }

  Map<int, MasterShipType> _parseMasterShipTypes(List<Object?> values) {
    final result = <int, MasterShipType>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final name = _asString(item?['api_name']);
      if (item != null && id > 0 && name.isNotEmpty) {
        result[id] = MasterShipType(
          id: id,
          name: name,
          equipTypeIds: _positiveIntKeys(
            _optionalMap(item['api_equip_type']),
            requireEnabledValue: true,
          ),
        );
      }
    }
    return result;
  }

  Map<int, MasterSlotItem> _parseMasterSlotItems(List<Object?> values) {
    final result = <int, MasterSlotItem>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final name = _asString(item?['api_name']);
      if (item == null || id <= 0 || name.isEmpty) {
        continue;
      }
      result[id] = MasterSlotItem(
        id: id,
        name: name,
        sortNo: _asInt(item['api_sortno']),
        firepower: _asInt(item['api_houg']),
        torpedo: _asInt(item['api_raig']),
        bombing: _asInt(item['api_baku']),
        antiAir: _asInt(item['api_tyku']),
        antiSub: _asInt(item['api_tais']),
        lineOfSight: _asInt(item['api_saku']),
        accuracy: _asInt(item['api_houm']),
        evasion: _asInt(item['api_houk']),
        armor: _asInt(item['api_souk']),
        range: _asInt(item['api_leng']),
        type: _intList(item['api_type'], includeNonPositive: true),
        interception: _asInt(item['api_houk']),
        antiBomber: _asInt(item['api_houm']),
        distance: _asInt(item['api_distance']),
        resourceVersion: item['api_version']?.toString() ?? '',
      );
    }
    return result;
  }

  Map<int, Set<int>> _parseLimitedEquipmentIdsByType(
    Map<String, Object?>? values,
  ) {
    if (values == null) return const <int, Set<int>>{};
    final result = <int, Set<int>>{};
    for (final entry in values.entries) {
      final typeId = int.tryParse(entry.key) ?? 0;
      if (typeId <= 0 || entry.value is! List) continue;
      final equipmentIds = Set<int>.unmodifiable(
        _intList(entry.value).where((id) => id > 0),
      );
      result[typeId] = equipmentIds;
    }
    return Map<int, Set<int>>.unmodifiable(result);
  }

  Map<int, ExpansionSlotSpecialRule> _parseExpansionSlotSpecialRules(
    Map<String, Object?>? values,
  ) {
    if (values == null) return const <int, ExpansionSlotSpecialRule>{};
    final result = <int, ExpansionSlotSpecialRule>{};
    for (final entry in values.entries) {
      final equipmentMasterId = int.tryParse(entry.key) ?? 0;
      final rule = _optionalMap(entry.value);
      if (equipmentMasterId <= 0 || rule == null) continue;
      result[equipmentMasterId] = ExpansionSlotSpecialRule(
        equipmentMasterId: equipmentMasterId,
        shipMasterIds: _positiveIntKeys(
          _optionalMap(rule['api_ship_ids']),
          requireEnabledValue: false,
        ),
        classTypeIds: _positiveIntKeys(
          _optionalMap(rule['api_ctypes']),
          requireEnabledValue: false,
        ),
        shipTypeIds: _positiveIntKeys(
          _optionalMap(rule['api_stypes']),
          requireEnabledValue: false,
        ),
        minimumImprovement: _asInt(rule['api_req_level']).clamp(0, 10),
      );
    }
    return Map<int, ExpansionSlotSpecialRule>.unmodifiable(result);
  }

  Map<int, Set<int>> _parseExpansionSlotLimits(Map<String, Object?>? values) {
    if (values == null) return const <int, Set<int>>{};
    final result = <int, Set<int>>{};
    for (final entry in values.entries) {
      final shipMasterId = int.tryParse(entry.key) ?? 0;
      if (shipMasterId <= 0 || entry.value is! List) continue;
      result[shipMasterId] = Set<int>.unmodifiable(
        _intList(entry.value).where((id) => id > 0),
      );
    }
    return Map<int, Set<int>>.unmodifiable(result);
  }

  Map<int, String> _parseIdNameMap(List<Object?> values) {
    final result = <int, String>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final name = _asString(item?['api_name']);
      if (item != null && id > 0 && name.isNotEmpty) {
        result[id] = name;
      }
    }
    return result;
  }

  Map<int, MasterMission> _parseMasterMissions(List<Object?> values) {
    final result = <int, MasterMission>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final name = _asString(item?['api_name']);
      final durationMinutes = _asInt(item?['api_time']);
      if (item == null || id <= 0 || name.isEmpty || durationMinutes <= 0) {
        continue;
      }
      result[id] = MasterMission(
        id: id,
        name: name,
        duration: Duration(minutes: durationMinutes),
        displayNumber: _asString(item['api_disp_no']),
        mapAreaId: _asInt(item['api_maparea_id']),
        fuelConsumptionRate: _asDouble(item['api_use_fuel']),
        ammunitionConsumptionRate: _asDouble(item['api_use_bull']),
        winItem1: _intList(item['api_win_item1'], includeNonPositive: true),
        winItem2: _intList(item['api_win_item2'], includeNonPositive: true),
      );
    }
    return result;
  }

  Map<int, MasterMapInfo> _parseMasterMapInfos(List<Object?> values) {
    final result = <int, MasterMapInfo>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final mapAreaId = _asInt(item?['api_maparea_id']);
      final mapNo = _asInt(item?['api_no']);
      final name = _asString(item?['api_name']);
      if (item == null ||
          id <= 0 ||
          mapAreaId <= 0 ||
          mapNo <= 0 ||
          name.isEmpty) {
        continue;
      }
      final reqDefeat = item['api_required_defeat_count'] != null
          ? _asInt(item['api_required_defeat_count'])
          : null;
      final maxMapHp = item['api_max_maphp'] != null
          ? _asInt(item['api_max_maphp'])
          : null;
      result[mapAreaId * 100 + mapNo] = MasterMapInfo(
        id: id,
        mapAreaId: mapAreaId,
        mapNo: mapNo,
        name: name,
        operationText: _asString(item['api_opetext']),
        requiredDefeatCount: reqDefeat != null && reqDefeat > 0
            ? reqDefeat
            : null,
        maxMapHp: maxMapHp != null && maxMapHp > 0 ? maxMapHp : null,
      );
    }
    return result;
  }

  Map<int, OwnedShip> _parseShips(
    List<Object?> values, {
    Map<int, OwnedShip> previous = const {},
  }) {
    final result = <int, OwnedShip>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final masterId = _asInt(item?['api_ship_id']);
      if (item == null || id <= 0 || masterId <= 0) {
        continue;
      }
      final existing = previous[id]?.masterId == masterId ? previous[id] : null;
      final experience = _optionalList(item['api_exp']);
      final repairItems = _optionalList(item['api_ndock_item']);
      result[id] = OwnedShip(
        id: id,
        masterId: masterId,
        level: _asInt(item['api_lv'], existing?.level ?? 0),
        currentHp: _asInt(item['api_nowhp'], existing?.currentHp ?? 0),
        maxHp: _asInt(item['api_maxhp'], existing?.maxHp ?? 0),
        condition: _asInt(item['api_cond'], existing?.condition ?? 49),
        currentFuel: _asInt(item['api_fuel'], existing?.currentFuel ?? 0),
        currentAmmo: _asInt(item['api_bull'], existing?.currentAmmo ?? 0),
        experience: experience.isNotEmpty
            ? _asInt(experience[0])
            : existing?.experience ?? 0,
        nextExperience: experience.length > 1
            ? _asInt(experience[1])
            : existing?.nextExperience ?? 0,
        firepower: item.containsKey('api_karyoku')
            ? _currentStat(item['api_karyoku'])
            : existing?.firepower ?? 0,
        firepowerMax: item.containsKey('api_karyoku')
            ? _maximumStat(item['api_karyoku'])
            : existing?.firepowerMax ?? 0,
        torpedo: item.containsKey('api_raisou')
            ? _currentStat(item['api_raisou'])
            : existing?.torpedo ?? 0,
        torpedoMax: item.containsKey('api_raisou')
            ? _maximumStat(item['api_raisou'])
            : existing?.torpedoMax ?? 0,
        antiAir: item.containsKey('api_taiku')
            ? _currentStat(item['api_taiku'])
            : existing?.antiAir ?? 0,
        antiAirMax: item.containsKey('api_taiku')
            ? _maximumStat(item['api_taiku'])
            : existing?.antiAirMax ?? 0,
        antiSub: item.containsKey('api_taisen')
            ? _currentStat(item['api_taisen'])
            : existing?.antiSub ?? 0,
        lineOfSight: item.containsKey('api_sakuteki')
            ? _currentStat(item['api_sakuteki'])
            : existing?.lineOfSight ?? 0,
        armor: item.containsKey('api_soukou')
            ? _currentStat(item['api_soukou'])
            : existing?.armor ?? 0,
        armorMax: item.containsKey('api_soukou')
            ? _maximumStat(item['api_soukou'])
            : existing?.armorMax ?? 0,
        evasion: item.containsKey('api_kaihi')
            ? _currentStat(item['api_kaihi'])
            : existing?.evasion ?? 0,
        luck: item.containsKey('api_lucky')
            ? _currentStat(item['api_lucky'])
            : existing?.luck ?? 0,
        luckMax: item.containsKey('api_lucky')
            ? _maximumStat(item['api_lucky'])
            : existing?.luckMax ?? 0,
        modernization: item.containsKey('api_kyouka')
            ? _intList(item['api_kyouka'], includeNonPositive: true)
            : existing?.modernization ?? const [],
        sallyArea: _asInt(item['api_sally_area'], existing?.sallyArea ?? 0),
        specialEffectKinds: !item.containsKey('api_sp_effect_items')
            ? existing?.specialEffectKinds ?? const []
            : [
                for (final effect in _optionalList(item['api_sp_effect_items']))
                  if (_asInt(_optionalMap(effect)?['api_kind']) > 0)
                    _asInt(_optionalMap(effect)?['api_kind']),
              ],
        maxSlotCounts: !item.containsKey('api_onslot_max')
            ? existing?.maxSlotCounts ?? const []
            : _intList(item['api_onslot_max'], includeNonPositive: true)
                  .take(
                    _asInt(
                      item['api_slotnum'],
                      _optionalList(item['api_onslot_max']).length,
                    ).clamp(0, _optionalList(item['api_onslot_max']).length),
                  )
                  .toList(),
        speed: _asInt(item['api_soku'], existing?.speed ?? 0),
        range: _asInt(item['api_leng'], existing?.range ?? 0),
        slotIds: item.containsKey('api_slot')
            ? _intList(item['api_slot'], includeNonPositive: true)
            : existing?.slotIds ?? const [],
        onSlot: item.containsKey('api_onslot')
            ? _intList(item['api_onslot'], includeNonPositive: true)
            : existing?.onSlot ?? const [],
        extraSlotId: _asInt(item['api_slot_ex'], existing?.extraSlotId ?? -1),
        repairDurationMilliseconds: _asInt(
          item['api_ndock_time'],
          existing?.repairDurationMilliseconds ?? 0,
        ),
        repairFuelCost: !item.containsKey('api_ndock_item')
            ? existing?.repairFuelCost ?? 0
            : repairItems.isNotEmpty
            ? _asInt(repairItems[0])
            : 0,
        repairSteelCost: !item.containsKey('api_ndock_item')
            ? existing?.repairSteelCost ?? 0
            : repairItems.length > 2
            ? _asInt(repairItems[2])
            : 0,
        locked:
            _asInt(item['api_locked'], existing?.locked == true ? 1 : 0) > 0,
      );
    }
    return result;
  }

  Map<int, OwnedSlotItem> _parseSlotItems(List<Object?> values) {
    final result = <int, OwnedSlotItem>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final instanceId = _asInt(item?['api_id']);
      final masterSlotItemId = _asInt(item?['api_slotitem_id']);
      if (item == null || instanceId <= 0 || masterSlotItemId <= 0) {
        continue;
      }
      result[instanceId] = OwnedSlotItem(
        instanceId: instanceId,
        masterSlotItemId: masterSlotItemId,
        level: _asInt(item['api_level']),
        proficiency: _asInt(item['api_alv']),
        locked: _asInt(item['api_locked']) > 0,
      );
    }
    return result;
  }

  List<Fleet> _parseFleets(List<Object?> values) {
    final result = <Fleet>[];
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      if (item == null || id <= 0) {
        continue;
      }
      final mission = _optionalList(item['api_mission']);
      final rawShipIds = _intList(item['api_ship'], includeNonPositive: true);
      result.add(
        Fleet(
          id: id,
          name: _asString(item['api_name'], '第 $id 舰队'),
          shipIds: rawShipIds.where((shipId) => shipId > 0).toList(),
          slotCount: rawShipIds.length,
          mission: FleetMission(
            state: mission.isEmpty ? 0 : _asInt(mission[0]),
            missionId: mission.length > 1 ? _asInt(mission[1]) : 0,
            completionTime: mission.length > 2
                ? _dateTimeFromMilliseconds(mission[2])
                : null,
          ),
        ),
      );
    }
    result.sort((left, right) => left.id.compareTo(right.id));
    return result;
  }

  List<RepairDock> _parseRepairDocks(List<Object?> values) {
    final result = <RepairDock>[];
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      if (item == null || id <= 0) {
        continue;
      }
      result.add(
        RepairDock(
          id: id,
          state: _asInt(item['api_state']),
          shipId: _asInt(item['api_ship_id']),
          completionTime: _dateTimeFromMilliseconds(item['api_complete_time']),
          fuelCost: _asInt(item['api_item1']),
          steelCost: _asInt(item['api_item3']),
        ),
      );
    }
    result.sort((left, right) => left.id.compareTo(right.id));
    return result;
  }

  List<ConstructionDock> _parseConstructionDocks(
    List<Object?> values, {
    DateTime? startedAt,
  }) {
    final result = <ConstructionDock>[];
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      if (item == null || id <= 0) {
        continue;
      }
      result.add(
        ConstructionDock(
          id: id,
          state: _asInt(item['api_state']),
          createdShipMasterId: _asInt(item['api_created_ship_id']),
          completionTime: _dateTimeFromMilliseconds(item['api_complete_time']),
          startedAt: startedAt,
          fuel: _asInt(item['api_item1']),
          ammunition: _asInt(item['api_item2']),
          steel: _asInt(item['api_item3']),
          bauxite: _asInt(item['api_item4']),
          developmentMaterial: _asInt(item['api_item5']),
        ),
      );
    }
    result.sort((left, right) => left.id.compareTo(right.id));
    return result;
  }

  static Map<String, Object?> _requiredMap(Object? value, String label) {
    final result = _optionalMap(value);
    if (result == null) {
      throw GameApiParseException('$label 数据不是对象');
    }
    return result;
  }

  static List<Object?> _requiredList(Object? value, String label) {
    if (value is! List) {
      throw GameApiParseException('$label 数据不是数组');
    }
    return List<Object?>.from(value);
  }

  static Map<String, Object?>? _optionalMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is String) {
        result[entry.key as String] = entry.value;
      }
    }
    return result;
  }

  static List<Object?> _optionalList(Object? value) {
    return value is List ? List<Object?>.from(value) : const <Object?>[];
  }

  static Set<int> _positiveIntKeys(
    Map<String, Object?>? values, {
    required bool requireEnabledValue,
  }) {
    if (values == null) return const <int>{};
    return Set<int>.unmodifiable(
      values.entries
          .where((entry) => !requireEnabledValue || _asInt(entry.value) == 1)
          .map((entry) => int.tryParse(entry.key) ?? 0)
          .where((id) => id > 0),
    );
  }

  static List<Object?> _optionalListOrSingleMap(Object? value) {
    if (value is List) {
      return List<Object?>.from(value);
    }
    if (value is Map) {
      return <Object?>[value];
    }
    return const <Object?>[];
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }

  static int _equipmentCapacityFromApi(Object? value) {
    final capacity = _asInt(value);
    return capacity > 0 ? capacity + 3 : capacity;
  }

  static double _asDouble(Object? value, [double fallback = 0]) {
    return switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }

  static String _asString(Object? value, [String fallback = '']) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  static String? _nullableString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  static int _currentStat(Object? value) {
    final list = _optionalList(value);
    return list.isEmpty ? _asInt(value) : _asInt(list.first);
  }

  static int _maximumStat(Object? value) {
    final list = _optionalList(value);
    return list.length > 1 ? _asInt(list[1]) : _currentStat(value);
  }

  static List<int> _intList(Object? value, {bool includeNonPositive = false}) {
    final result = <int>[];
    for (final item in _optionalList(value)) {
      final number = _asInt(item, -1);
      if (includeNonPositive || number > 0) {
        result.add(number);
      }
    }
    return result;
  }

  static DateTime? _dateTimeFromMilliseconds(Object? value) {
    final milliseconds = _asInt(value);
    return milliseconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
        : null;
  }

  GameState _mapStartOrNext(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final isStart = event.path.endsWith('/start');
    final nextNode = _asInt(data['api_no']);
    final mapArea = _asInt(data['api_maparea_id']);
    final mapInfo = _asInt(data['api_mapinfo_no']);
    final sortieFleetId = _asInt(event.requestParams['api_deck_id']);
    final landBases = _applyLandBaseRaid(state.landBases, data, mapArea);

    final currentCombat = isStart ? CombatState.empty : state.combatState;
    final nextEscaped = isStart ? const <int>{} : currentCombat.escapedShipIds;

    return state.copyWith(
      landBases: landBases,
      combatState: currentCombat
          .copyWith(
            sortieFleetId: sortieFleetId > 0 ? sortieFleetId : null,
            mapArea: mapArea,
            mapInfo: mapInfo,
            escapedShipIds: nextEscaped,
          )
          .moveNext(nextNode),
    );
  }

  List<LandBaseState> _applyLandBaseRaid(
    List<LandBaseState> existing,
    Map<String, Object?> data,
    int areaId,
  ) {
    final raids = parseLandBaseRaids(data);
    if (raids.isEmpty || areaId <= 0) return existing;
    final result = <LandBaseState>[...existing];
    for (final raid in raids) {
      for (final hp in raid.bases) {
        final baseId = hp.baseId;
        final found = result.indexWhere(
          (base) => base.areaId == areaId && base.baseId == hp.baseId,
        );
        final previous = found >= 0
            ? result[found]
            : LandBaseState(
                areaId: areaId,
                baseId: hp.baseId,
                name: '第 $baseId 基地航空队',
              );
        final updated = previous.copyWith(
          maxHp: hp.maxHp,
          currentHp: hp.currentHp,
          lastRaidDamage: hp.damage,
        );
        if (found >= 0) {
          result[found] = updated;
        } else {
          result.add(updated);
        }
      }
    }
    result.sort((left, right) {
      final byArea = left.areaId.compareTo(right.areaId);
      return byArea != 0 ? byArea : left.baseId.compareTo(right.baseId);
    });
    return result;
  }

  static Object? _decodeNestedJson(Object? value) {
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  GameState _battle(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final enemyFleetName = parseEnemyFleetName(data['api_formation']);
    final airSuperiority = kAirSuperiorityLabels[parseDispSeiku(data)] ?? '未知';
    final sortieFleetId = _asInt(data['api_deck_id']);
    return state.copyWith(
      combatState: state.combatState.copyWith(
        sortieFleetId: sortieFleetId > 0 ? sortieFleetId : null,
        enemyFleetName: enemyFleetName,
        airSuperiority: airSuperiority,
      ),
    );
  }

  GameState _missionResult(
    GameState state,
    CapturedApiEvent event,
    String origin,
  ) {
    final requestedMissionId = _asInt(event.requestParams['api_mission_id']);
    final deckId = _asInt(event.requestParams['api_deck_id']);
    final fleets = <Fleet>[
      for (final fleet in state.fleets)
        if (((deckId > 0 && fleet.id == deckId) ||
                (requestedMissionId > 0 &&
                    fleet.mission.missionId == requestedMissionId)) &&
            fleet.mission.isActive)
          Fleet(
            id: fleet.id,
            name: fleet.name,
            shipIds: fleet.shipIds,
            slotCount: fleet.slotCount,
            mission: const FleetMission(),
          )
        else
          fleet,
    ];
    return state.copyWith(
      fleets: fleets,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _battleResult(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final getShip = _optionalMap(data['api_get_ship']);
    final dropShipMasterId = _asInt(getShip?['api_ship_id']);

    final mapArea = state.combatState.mapArea;
    final mapInfoNo = state.combatState.mapInfo;
    Map<int, MemberMapInfo>? updatedMemberMapInfos;

    final rawMapHp =
        _optionalMap(data['api_maphp']) ?? _optionalMap(data['api_map_hp']);
    if (rawMapHp != null && mapArea > 0 && mapInfoNo > 0) {
      final key = mapArea * 100 + mapInfoNo;
      final existing = state.memberMapInfos[key];
      if (existing != null) {
        final nowHp = rawMapHp['api_now_maphp'] != null
            ? _asInt(rawMapHp['api_now_maphp'])
            : existing.currentHp;
        final maxHp = rawMapHp['api_max_maphp'] != null
            ? _asInt(rawMapHp['api_max_maphp'])
            : existing.maxHp;
        final gaugeNum = rawMapHp['api_gauge_num'] != null
            ? _asInt(rawMapHp['api_gauge_num'])
            : existing.gaugeNum;
        final gaugeMaxNum = rawMapHp['api_gauge_max_num'] != null
            ? _asInt(rawMapHp['api_gauge_max_num'])
            : existing.gaugeMaxNum;
        final gaugeType = rawMapHp['api_gauge_type'] != null
            ? _asInt(rawMapHp['api_gauge_type'])
            : existing.gaugeType;

        final newMapInfos = Map<int, MemberMapInfo>.from(state.memberMapInfos);
        newMapInfos[key] = existing.copyWith(
          currentHp: nowHp,
          maxHp: maxHp,
          gaugeNum: gaugeNum,
          gaugeMaxNum: gaugeMaxNum,
          gaugeType: gaugeType,
        );
        updatedMemberMapInfos = newMapInfos;
      }
    }

    final rawLandingHp = _optionalMap(data['api_landing_hp']);
    if (rawLandingHp != null && mapArea > 0 && mapInfoNo > 0) {
      final key = mapArea * 100 + mapInfoNo;
      final existing = (updatedMemberMapInfos ?? state.memberMapInfos)[key];
      if (existing != null) {
        final nowHp = rawLandingHp['api_now_hp'] != null
            ? _asInt(rawLandingHp['api_now_hp'])
            : existing.currentHp;
        final maxHp = rawLandingHp['api_max_hp'] != null
            ? _asInt(rawLandingHp['api_max_hp'])
            : existing.maxHp;
        final newMapInfos = Map<int, MemberMapInfo>.from(
          updatedMemberMapInfos ?? state.memberMapInfos,
        );
        newMapInfos[key] = existing.copyWith(currentHp: nowHp, maxHp: maxHp);
        updatedMemberMapInfos = newMapInfos;
      }
    }

    // Parse FCF / escape proposals
    final escapeFlag = _asInt(data['api_escape_flag']);
    List<int> pendingEscape = const <int>[];
    if (escapeFlag > 0) {
      final decodedEscape = _decodeNestedJson(data['api_escape']);
      final escapeObj =
          _optionalMap(decodedEscape) ?? _optionalMap(data['api_escape']);
      final rawEscape = escapeObj?['api_escape_idx'] ?? data['api_escape_idx'];
      final rawTow = escapeObj?['api_tow_idx'] ?? data['api_tow_idx'];

      int firstEscapeIndex(Object? raw) {
        final values = _optionalList(raw);
        return values.isEmpty ? _asInt(raw) : _asInt(values.first);
      }

      final indices = <int>[];
      final escapeIndex = firstEscapeIndex(rawEscape);
      final towIndex = firstEscapeIndex(rawTow);
      if (escapeIndex > 0) indices.add(escapeIndex);
      if (towIndex > 0) indices.add(towIndex);

      final requestedDeckId = _asInt(event.requestParams['api_deck_id']);
      final battleDeckId = _asInt(data['api_deck_id']);
      final sortieFleetId = state.combatState.sortieFleetId > 0
          ? state.combatState.sortieFleetId
          : (requestedDeckId > 0
                ? requestedDeckId
                : (battleDeckId > 0 ? battleDeckId : 1));
      final isCombined =
          sortieFleetId == 1 &&
          (state.combinedFleetType != CombinedFleetType.none ||
              event.path.contains('combined'));
      final mainFleet = state.fleets
          .where((f) => f.id == (isCombined ? 1 : sortieFleetId))
          .firstOrNull;
      final escortFleet = isCombined
          ? state.fleets.where((f) => f.id == 2).firstOrNull
          : null;

      final shipIds = <int>[];
      for (final idx in indices) {
        if (isCombined) {
          if (idx >= 1 && idx <= 6) {
            final slot = idx - 1;
            if (mainFleet != null && slot < mainFleet.shipIds.length) {
              shipIds.add(mainFleet.shipIds[slot]);
            }
          } else if (idx >= 7 && idx <= 12) {
            final slot = idx - 7;
            if (escortFleet != null && slot < escortFleet.shipIds.length) {
              shipIds.add(escortFleet.shipIds[slot]);
            }
          }
        } else {
          final slot = idx - 1;
          if (mainFleet != null && slot < mainFleet.shipIds.length) {
            shipIds.add(mainFleet.shipIds[slot]);
          }
        }
      }
      pendingEscape = shipIds.toSet().toList(growable: false);
    }

    return state.copyWith(
      memberMapInfos: updatedMemberMapInfos ?? state.memberMapInfos,
      combatState: state.combatState.copyWith(
        dropShipMasterId: dropShipMasterId > 0 ? dropShipMasterId : null,
        pendingEscapeShipIds: pendingEscape,
      ),
    );
  }

  GameState _goBackPort(GameState state, CapturedApiEvent event) {
    if (state.combatState.pendingEscapeShipIds.isEmpty) {
      return state;
    }
    final nextEscaped = Set<int>.from(state.combatState.escapedShipIds)
      ..addAll(state.combatState.pendingEscapeShipIds);
    return state.copyWith(
      combatState: state.combatState.copyWith(
        escapedShipIds: nextEscaped,
        pendingEscapeShipIds: const <int>[],
      ),
      updatedAt: event.capturedAt,
    );
  }
}

enum _QuestProgressEvent {
  battle,
  battleWin,
  practice,
  practiceWin,
  missionSuccess,
  repair,
  supply,
  createItem,
  createShip,
  destroyItem,
}

class _KnownQuestGoal {
  const _KnownQuestGoal(this.event, this.required, {this.initial = 0});

  final _QuestProgressEvent event;
  final int required;
  final int initial;
}

const Map<int, _KnownQuestGoal> _knownQuestGoals = <int, _KnownQuestGoal>{
  201: _KnownQuestGoal(_QuestProgressEvent.battleWin, 1),
  216: _KnownQuestGoal(_QuestProgressEvent.battle, 1),
  210: _KnownQuestGoal(_QuestProgressEvent.battle, 10),
  303: _KnownQuestGoal(_QuestProgressEvent.practice, 3),
  304: _KnownQuestGoal(_QuestProgressEvent.practiceWin, 5),
  402: _KnownQuestGoal(_QuestProgressEvent.missionSuccess, 3),
  403: _KnownQuestGoal(_QuestProgressEvent.missionSuccess, 10),
  503: _KnownQuestGoal(_QuestProgressEvent.repair, 5),
  504: _KnownQuestGoal(_QuestProgressEvent.supply, 15),
  605: _KnownQuestGoal(_QuestProgressEvent.createItem, 1),
  606: _KnownQuestGoal(_QuestProgressEvent.createShip, 1),
  607: _KnownQuestGoal(_QuestProgressEvent.createItem, 4, initial: 1),
  608: _KnownQuestGoal(_QuestProgressEvent.createShip, 4, initial: 1),
  1101: _KnownQuestGoal(_QuestProgressEvent.destroyItem, 8),
};

const int _f96QuestId = 1101;
const int _f96DiscardMasterId = 2;
const int _f96PreparedMasterId4 = 4;
const int _f96PreparedMasterId6 = 6;
const int _f96RequiredFurnitureCoins = 4000;

int? _serverAlignedQuestCount(
  int current,
  int? required,
  int progressFlag,
  bool completed,
) {
  if (required == null) return null;
  if (completed) return required;
  final maximum = required - 1;
  return switch (progressFlag) {
    1 => _limitQuestCount(
      current,
      (required * 0.5).ceil(),
      (required * 0.8).ceil() - 1,
    ),
    2 => _limitQuestCount(current, (required * 0.8).ceil(), maximum),
    _ => _limitQuestCount(current, 0, (required * 0.5).ceil() - 1),
  };
}

int _limitQuestCount(int current, int minimum, int maximum) {
  final raised = current < minimum ? minimum : current;
  return raised > maximum ? maximum : raised;
}

const Map<int, int> _knownDefaultRequiredDefeatCounts = <int, int>{
  105: 4, // 1-5
  106: 7, // 1-6
  205: 4, // 2-5
  305: 4, // 3-5
  405: 5, // 4-5
  505: 5, // 5-5
  605: 6, // 6-5
  702: 3, // 7-2
  703: 3, // 7-3
  704: 3, // 7-4
  705: 3, // 7-5
};
