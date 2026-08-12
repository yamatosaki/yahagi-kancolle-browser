import 'dart:convert';

import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import 'combat_state.dart';
import 'game_api_decoder.dart';
import 'game_state.dart';

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
          event.path == '/kcsapi/api_req_hensei/change' ||
          event.path == '/kcsapi/api_req_kaisou/slotset' ||
          event.path == '/kcsapi/api_req_kaisou/slotset_ex' ||
          event.path == '/kcsapi/api_req_kaisou/unsetslot_all' ||
          event.path == '/kcsapi/api_req_nyukyo/start' ||
          event.path == '/kcsapi/api_req_nyukyo/speedchange' ||
          event.path == '/kcsapi/api_req_quest/clearitemget' ||
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
        _requiredMap(data, 'createship'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kousyou/createship_speedchange' =>
        _constructionSpeedChange(state, event, origin),
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
      '/kcsapi/api_get_member/ship2' ||
      '/kcsapi/api_get_member/ship3' ||
      '/kcsapi/api_get_member/ship_deck' => _shipAndDeck(
        state,
        data,
        event,
        origin,
      ),
      '/kcsapi/api_req_map/start' => _mapStartOrNext(
        state,
        _requiredMap(data, 'map data'),
        event,
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
        .where((item) => item.masterId == _f96DiscardMasterId)
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
      items.values.where((item) => item.masterId == masterId).length;

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
    return state.copyWith(
      ships: Map<int, OwnedShip>.of(state.ships)..[ship.id] = ship,
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
    final parsed = _parseShips(values);
    final ships = Map<int, OwnedShip>.of(state.ships)..addAll(parsed);
    return state.copyWith(
      ships: ships,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
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
      ..addAll(_parseShips(<Object?>[data['api_ship']]));
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
    DateTime updatedAt,
  ) {
    final quests = Map<int, GameQuest>.of(existing);
    for (final value in _optionalList(data['api_list'])) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_no']);
      if (item == null || id <= 0) {
        continue;
      }
      final state = _asInt(item['api_state']);
      if (state < 2) {
        quests.remove(id);
        continue;
      }
      final rawMaterials = _optionalList(item['api_get_material']);
      final materials = List<int>.generate(
        4,
        (index) =>
            index < rawMaterials.length ? _asInt(rawMaterials[index]) : 0,
        growable: false,
      );
      quests[id] = GameQuest(
        id: id,
        title: _asString(item['api_title']),
        detail: _asString(
          item['api_detail'],
        ).replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'),
        category: _asInt(item['api_category']),
        type: _asInt(item['api_type']),
        state: state,
        progressFlag: _asInt(item['api_progress_flag']),
        materials: materials,
        progressCurrent: _serverAlignedQuestCount(
          existing[id]?.progressCurrent ?? _knownQuestGoals[id]?.initial ?? 0,
          _knownQuestGoals[id]?.required,
          _asInt(item['api_progress_flag']),
          state == 3,
        ),
        progressRequired: _knownQuestGoals[id]?.required,
        localCompletionVerified: id == _f96QuestId && state != 3
            ? false
            : existing[id]?.localCompletionVerified,
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

  GameState _questList(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin,
  ) {
    final activeCount = _asInt(data['api_exec_count']).clamp(0, 99);
    final isCompleteSnapshot =
        _asInt(event.requestParams['yahagi_full_quest_snapshot']) == 1;
    final quests = _parseQuests(
      data,
      isCompleteSnapshot ? const <int, GameQuest>{} : state.quests,
      event.capturedAt,
    );
    return state.copyWith(
      quests: quests,
      hasQuestData: true,
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
    return state.copyWith(
      quests: quests,
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
    if (targetFleetIndex < 0 || position < 0) {
      return state;
    }

    final targetFleet = state.fleets[targetFleetIndex];
    if (position >= targetFleet.slotCount) {
      return state;
    }
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
    final shipTypes = _parseMasterShipTypes(
      _optionalList(data['api_mst_stype']),
    );
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
      ships[id] = MasterShip(
        id: id,
        name: name,
        shipTypeId: _asInt(item['api_stype']),
        classTypeId: _asInt(item['api_ctype']),
        speed: _asInt(item['api_soku']),
        range: _asInt(item['api_leng']),
        maxFuel: _asInt(item['api_fuel_max']),
        maxAmmo: _asInt(item['api_bull_max']),
        slotCount: _asInt(item['api_slot_num']),
        buildTimeMinutes: _asInt(item['api_buildtime']),
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
      masterMissions: _parseMasterMissions(
        _optionalList(data['api_mst_mission']),
      ),
      masterMapInfos: _parseMasterMapInfos(
        _optionalList(data['api_mst_mapinfo']),
      ),
      serverOrigin: origin,
      hasMasterData: ships.isNotEmpty,
      updatedAt: event.capturedAt,
    );
  }

  GameState _snapshot(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
    String origin, {
    bool hasPortData = false,
  }) {
    final basic = _optionalMap(data['api_basic']);
    return state.copyWith(
      admiralLevel: basic == null ? null : _asInt(basic['api_level']),
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
        for (final base in snapshot.landBases)
          LandBaseState(
            areaId: base.areaId,
            baseId: base.baseId,
            name: base.name,
            actionKind: base.actionKind,
          ),
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
    for (final value in _optionalList(data['api_map_info'])) {
      final item = _optionalMap(value);
      final mapId = _asInt(item?['api_id']);
      final eventMap = _optionalMap(item?['api_eventmap']);
      final rank = _asInt(eventMap?['api_selected_rank']);
      if (item == null || mapId <= 0 || eventMap == null) continue;
      MasterMapInfo? master;
      for (final candidate in state.masterMapInfos.values) {
        if (candidate.id == mapId) {
          master = candidate;
          break;
        }
      }
      final areaId = master?.mapAreaId ?? mapId ~/ 10;
      final mapNo = master?.mapNo ?? mapId % 10;
      if (areaId <= 0 || mapNo <= 0) continue;
      final key = areaId * 100 + mapNo;
      if (rank > 0) {
        mapDifficulties[key] = rank;
      } else {
        mapDifficulties.remove(key);
      }
    }

    List<LandBaseState>? bases;
    if (data.containsKey('api_air_base')) {
      bases = <LandBaseState>[];
      for (final value in _optionalList(data['api_air_base'])) {
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
          ),
        );
      }
      bases.sort((left, right) {
        final byArea = left.areaId.compareTo(right.areaId);
        return byArea != 0 ? byArea : left.baseId.compareTo(right.baseId);
      });
    }
    return state.copyWith(
      landBases: bases,
      mapDifficulties: mapDifficulties,
      serverOrigin: origin,
      updatedAt: event.capturedAt,
    );
  }

  GameState _shipAndDeck(
    GameState state,
    Object? data,
    CapturedApiEvent event,
    String origin,
  ) {
    if (data is List) {
      final newShips = _parseShips(List<Object?>.from(data));
      final mergedShips = Map<int, OwnedShip>.from(state.ships)
        ..addAll(newShips);
      return state.copyWith(
        ships: mergedShips,
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
      final newShips = _parseShips(_optionalList(shipData));
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
        result[id] = MasterShipType(id: id, name: name);
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
      );
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
      result[mapAreaId * 100 + mapNo] = MasterMapInfo(
        id: id,
        mapAreaId: mapAreaId,
        mapNo: mapNo,
        name: name,
        operationText: _asString(item['api_opetext']),
      );
    }
    return result;
  }

  Map<int, OwnedShip> _parseShips(List<Object?> values) {
    final result = <int, OwnedShip>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final masterId = _asInt(item?['api_ship_id']);
      if (item == null || id <= 0 || masterId <= 0) {
        continue;
      }
      final experience = _optionalList(item['api_exp']);
      final repairItems = _optionalList(item['api_ndock_item']);
      result[id] = OwnedShip(
        id: id,
        masterId: masterId,
        level: _asInt(item['api_lv']),
        currentHp: _asInt(item['api_nowhp']),
        maxHp: _asInt(item['api_maxhp']),
        condition: _asInt(item['api_cond'], 49),
        currentFuel: _asInt(item['api_fuel']),
        currentAmmo: _asInt(item['api_bull']),
        nextExperience: experience.length > 1 ? _asInt(experience[1]) : 0,
        firepower: _currentStat(item['api_karyoku']),
        firepowerMax: _maximumStat(item['api_karyoku']),
        torpedo: _currentStat(item['api_raisou']),
        torpedoMax: _maximumStat(item['api_raisou']),
        antiAir: _currentStat(item['api_taiku']),
        antiAirMax: _maximumStat(item['api_taiku']),
        antiSub: _currentStat(item['api_taisen']),
        lineOfSight: _currentStat(item['api_sakuteki']),
        armor: _currentStat(item['api_soukou']),
        armorMax: _maximumStat(item['api_soukou']),
        evasion: _currentStat(item['api_kaihi']),
        luck: _currentStat(item['api_lucky']),
        luckMax: _maximumStat(item['api_lucky']),
        speed: _asInt(item['api_soku']),
        range: _asInt(item['api_leng']),
        slotIds: _intList(item['api_slot']),
        onSlot: _intList(item['api_onslot'], includeNonPositive: true),
        extraSlotId: _asInt(item['api_slot_ex'], -1),
        repairDurationMilliseconds: _asInt(item['api_ndock_time']),
        repairFuelCost: repairItems.isNotEmpty ? _asInt(repairItems[0]) : 0,
        repairSteelCost: repairItems.length > 2 ? _asInt(repairItems[2]) : 0,
        locked: _asInt(item['api_locked']) > 0,
      );
    }
    return result;
  }

  Map<int, OwnedSlotItem> _parseSlotItems(List<Object?> values) {
    final result = <int, OwnedSlotItem>{};
    for (final value in values) {
      final item = _optionalMap(value);
      final id = _asInt(item?['api_id']);
      final masterId = _asInt(item?['api_slotitem_id']);
      if (item == null || id <= 0 || masterId <= 0) {
        continue;
      }
      result[id] = OwnedSlotItem(
        id: id,
        masterId: masterId,
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
    final nextNode = _asInt(data['api_no']);
    final mapArea = _asInt(data['api_maparea_id']);
    final mapInfo = _asInt(data['api_mapinfo_no']);
    final sortieFleetId = _asInt(event.requestParams['api_deck_id']);
    final landBases = _applyLandBaseRaid(state.landBases, data, mapArea);
    return state.copyWith(
      landBases: landBases,
      combatState: state.combatState
          .copyWith(
            sortieFleetId: sortieFleetId > 0 ? sortieFleetId : null,
            mapArea: mapArea,
            mapInfo: mapInfo,
          )
          .moveNext(nextNode),
    );
  }

  List<LandBaseState> _applyLandBaseRaid(
    List<LandBaseState> existing,
    Map<String, Object?> data,
    int areaId,
  ) {
    final destruction = _optionalMap(data['api_destruction_battle']);
    if (destruction == null || areaId <= 0) return existing;
    final maxHp = _optionalList(destruction['api_f_maxhps']);
    final nowHp = _optionalList(destruction['api_f_nowhps']);
    final rawAttack = _decodeNestedJson(destruction['api_air_base_attack']);
    final attack = _optionalMap(rawAttack);
    final stage3 = _optionalMap(attack?['api_stage3']);
    var damage = _optionalList(stage3?['api_fdam']);
    if (attack == null) return existing;
    if (damage.length > maxHp.length &&
        damage.isNotEmpty &&
        _asInt(damage.first) < 0) {
      damage = damage.sublist(1);
    }
    final count = <int>[
      maxHp.length,
      nowHp.length,
      damage.length,
    ].reduce((left, right) => left > right ? left : right);
    if (count == 0) return existing;

    final result = <LandBaseState>[...existing];
    for (var index = 0; index < count; index++) {
      final baseId = index + 1;
      final found = result.indexWhere(
        (base) => base.areaId == areaId && base.baseId == baseId,
      );
      final previous = found >= 0
          ? result[found]
          : LandBaseState(
              areaId: areaId,
              baseId: baseId,
              name: '第 $baseId 基地航空队',
            );
      final maximum = index < maxHp.length
          ? _asInt(maxHp[index])
          : previous.maxHp;
      final initial = index < nowHp.length
          ? _asInt(nowHp[index])
          : previous.currentHp;
      final lost = index < damage.length
          ? _asInt(damage[index]).clamp(0, 1 << 30)
          : 0;
      if (maximum == null || initial == null) continue;
      final current = (initial - lost).clamp(0, maximum);
      final updated = LandBaseState(
        areaId: previous.areaId,
        baseId: previous.baseId,
        name: previous.name,
        actionKind: previous.actionKind,
        maxHp: maximum,
        currentHp: current,
        lastRaidDamage: lost,
      );
      if (found >= 0) {
        result[found] = updated;
      } else {
        result.add(updated);
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
    return state.copyWith(
      combatState: state.combatState.copyWith(
        dropShipMasterId: dropShipMasterId > 0 ? dropShipMasterId : null,
      ),
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
