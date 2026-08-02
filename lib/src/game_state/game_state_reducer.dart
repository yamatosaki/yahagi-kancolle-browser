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
    '/kcsapi/api_req_kousyou/createship',
    '/kcsapi/api_req_hensei/combined',
    '/kcsapi/api_req_quest/clearitemget',
    '/kcsapi/api_req_quest/stop',
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/next',
    '/kcsapi/api_req_sortie/battle',
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_mission/result',
  };

  GameState reduce(GameState state, CapturedApiEvent event) {
    if (!_supportedPaths.contains(event.path)) {
      return state;
    }

    final data = GameApiDecoder.decodeData(event.responseBody);
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
      '/kcsapi/api_req_kousyou/createship' => _constructionStart(
        state,
        _requiredMap(data, 'createship'),
        event,
        origin,
      ),
      '/kcsapi/api_req_hensei/combined' => state.copyWith(
        combinedFleetType: CombinedFleetType.fromApiValue(
          _asInt(event.requestParams['api_combined_type']),
        ),
        serverOrigin: origin,
        updatedAt: event.capturedAt,
      ),
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
      _ => state,
    };
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
        slotIds: _intList(item['api_slot']),
        onSlot: _intList(item['api_onslot'], includeNonPositive: true),
        extraSlotId: _asInt(item['api_slot_ex'], -1),
        repairDurationMilliseconds: _asInt(item['api_ndock_time']),
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
