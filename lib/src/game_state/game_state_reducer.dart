import '../bridge/captured_api_event.dart';
import 'combat_state.dart';
import 'game_api_decoder.dart';
import 'game_state.dart';

export 'game_api_decoder.dart' show GameApiParseException;

class GameStateReducer {
  static const Set<String> _supportedPaths = <String>{
    '/kcsapi/api_start2/getData',
    '/kcsapi/api_port/port',
    '/kcsapi/api_get_member/require_info',
    '/kcsapi/api_get_member/material',
    '/kcsapi/api_get_member/deck',
    '/kcsapi/api_get_member/ship2',
    '/kcsapi/api_get_member/ship3',
    '/kcsapi/api_get_member/ship_deck',
    '/kcsapi/api_get_member/slot_item',
    '/kcsapi/api_get_member/ndock',
    '/kcsapi/api_get_member/kdock',
    '/kcsapi/api_get_member/questlist',
    '/kcsapi/api_req_hokyu/charge',
    '/kcsapi/api_req_kaisou/slot_deprive',
    '/kcsapi/api_req_kaisou/slot_exchange_index',
    '/kcsapi/api_req_kousyou/createship',
    '/kcsapi/api_req_kousyou/createship_speedchange',
    '/kcsapi/api_req_kousyou/getship',
    '/kcsapi/api_req_hensei/change',
    '/kcsapi/api_req_hensei/combined',
    '/kcsapi/api_req_hensei/preset_select',
    '/kcsapi/api_req_nyukyo/start',
    '/kcsapi/api_req_nyukyo/speedchange',
    '/kcsapi/api_req_quest/clearitemget',
    '/kcsapi/api_req_quest/stop',
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/next',
    '/kcsapi/api_req_sortie/battle',
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_mission/result',
    '/kcsapi/api_req_mission/start',
  };

  GameState reduce(GameState state, CapturedApiEvent event) {
    if (!_supportedPaths.contains(event.path)) {
      return state;
    }

    final data = GameApiDecoder.decodeData(
      event.responseBody,
      // The formation change response only contains api_result and
      // api_result_msg. Its state transition is driven by request parameters.
      allowMissingData: event.path == '/kcsapi/api_req_hensei/change',
    );
    final origin = event.sourceOrigin.isEmpty
        ? state.serverOrigin
        : event.sourceOrigin;

    return switch (event.path) {
      '/kcsapi/api_start2/getData' => _start2(
        state,
        _requiredMap(data, 'start2'),
        event,
        origin,
      ),
      '/kcsapi/api_port/port' => _snapshot(
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
      '/kcsapi/api_get_member/questlist' => state.copyWith(
        quests: _parseQuests(
          _requiredMap(data, 'questlist'),
          state.quests,
          event.capturedAt,
        ),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
      '/kcsapi/api_req_hokyu/charge' => _charge(
        state,
        _requiredMap(data, 'charge'),
        event,
        origin,
      ),
      '/kcsapi/api_req_kaisou/slot_exchange_index' => _mergeActionShips(
        state,
        <Object?>[_requiredMap(data, 'slot exchange')['api_ship_data']],
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
        updatedAt: updatedAt,
      );
    }
    return quests;
  }

  GameState _removeQuest(
    GameState state,
    int questId,
    CapturedApiEvent event,
    String origin,
  ) {
    if (questId <= 0 || !state.quests.containsKey(questId)) {
      return state;
    }
    final quests = Map<int, GameQuest>.of(state.quests);
    quests.remove(questId);
    return state.copyWith(
      quests: quests,
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
      resources: data.containsKey('api_material')
          ? _parseResources(
              _optionalList(data['api_material']),
              state.resources,
            )
          : null,
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
      slotItems: data.containsKey('api_slot_item')
          ? _parseSlotItems(_optionalList(data['api_slot_item']))
          : null,
      serverOrigin: origin,
      hasPortData: hasPortData ? true : null,
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
    List<int>? onSlot,
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
      torpedo: ship.torpedo,
      antiAir: ship.antiAir,
      antiSub: ship.antiSub,
      lineOfSight: ship.lineOfSight,
      armor: ship.armor,
      evasion: ship.evasion,
      luck: ship.luck,
      speed: ship.speed,
      range: ship.range,
      slotIds: ship.slotIds,
      onSlot: onSlot ?? ship.onSlot,
      extraSlotId: ship.extraSlotId,
      repairDurationMilliseconds: ship.repairDurationMilliseconds,
      repairFuelCost: ship.repairFuelCost,
      repairSteelCost: ship.repairSteelCost,
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
        torpedo: _currentStat(item['api_raisou']),
        antiAir: _currentStat(item['api_taiku']),
        antiSub: _currentStat(item['api_taisen']),
        lineOfSight: _currentStat(item['api_sakuteki']),
        armor: _currentStat(item['api_soukou']),
        evasion: _currentStat(item['api_kaihi']),
        luck: _currentStat(item['api_lucky']),
        speed: _asInt(item['api_soku']),
        range: _asInt(item['api_leng']),
        slotIds: _intList(item['api_slot']),
        onSlot: _intList(item['api_onslot'], includeNonPositive: true),
        extraSlotId: _asInt(item['api_slot_ex'], -1),
        repairDurationMilliseconds: _asInt(item['api_ndock_time']),
        repairFuelCost: repairItems.isNotEmpty ? _asInt(repairItems[0]) : 0,
        repairSteelCost: repairItems.length > 1 ? _asInt(repairItems[1]) : 0,
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
          steelCost: _asInt(item['api_item2']),
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
    return state.copyWith(
      combatState: state.combatState
          .copyWith(mapArea: mapArea, mapInfo: mapInfo)
          .moveNext(nextNode),
    );
  }

  GameState _battle(
    GameState state,
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final enemyFleetName = parseEnemyFleetName(data['api_formation']);
    final airSuperiority = kAirSuperiorityLabels[parseDispSeiku(data)] ?? '未知';
    return state.copyWith(
      combatState: state.combatState.copyWith(
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
    final missionId = _asInt(event.requestParams['api_mission_id']);
    final fleets = <Fleet>[
      for (final fleet in state.fleets)
        if (missionId > 0 &&
            fleet.mission.missionId == missionId &&
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
