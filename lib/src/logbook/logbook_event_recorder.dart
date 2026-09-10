import '../bridge/captured_api_event.dart';
import '../battle/battle_models.dart';
import '../capture/game_capture_path_catalog.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_state.dart';
import 'expedition_log_catalog.dart';
import 'logbook_database.dart';

final class LogbookEventRecorder {
  LogbookEventRecorder({LogbookDatabase? database})
    : _database = database ?? LogbookDatabase.instance;

  final LogbookDatabase _database;
  final Map<int, _PendingConstruction> _pendingConstructions = {};

  static const supportedPaths = GameCapturePathCatalog.logbook;

  bool supports(String path) => supportedPaths.contains(path);

  Future<void> record(CapturedApiEvent event, GameState state) async {
    if (!supports(event.path) || event.apiResult != 1) return;
    switch (event.path) {
      case '/kcsapi/api_req_map/start':
      case '/kcsapi/api_req_map/next':
        await _recordMapResourceEvent(event, state);
      case '/kcsapi/api_req_mission/result':
        await _recordExpedition(event, state);
      case '/kcsapi/api_req_kousyou/createitem':
        await _recordDevelopment(event, state);
      case '/kcsapi/api_req_kousyou/createship':
        await _recordConstructionStart(event, state);
      case '/kcsapi/api_req_kousyou/getship':
        await _recordConstruction(event, state);
      case '/kcsapi/api_get_member/kdock':
        await _recordConstructionDockUpdate(event, state);
      case '/kcsapi/api_req_kousyou/destroyship':
        await _recordRetiredShips(event, state, type: '解体');
      case '/kcsapi/api_req_kaisou/powerup':
        await _recordRetiredShips(event, state, type: '改修');
    }
  }

  Future<void> _recordMapResourceEvent(
    CapturedApiEvent event,
    GameState state,
  ) async {
    final data = _data(event);
    final deltas = <GameResourceType, int>{};
    final rewards = <BattleRewardItem>[];
    for (final item in <Map<String, Object?>>[
      ..._maps(data['api_itemget']),
      ..._maps(data['api_itemget_eo_comment']),
    ]) {
      final useMaster = _int(item['api_usemst']);
      final id = _int(item['api_id']);
      final count = _positive(item['api_getcount'], 0);
      if (useMaster == 4) {
        final type = GameResourceType.values
            .where((candidate) => candidate.apiId == id)
            .firstOrNull;
        if (type != null && count > 0) {
          deltas[type] = (deltas[type] ?? 0) + count;
        }
      } else if (id > 0) {
        rewards.add(
          BattleRewardItem(
            kind: BattleRewardKind.item,
            id: id,
            count: count > 0 ? count : 1,
            name: expeditionRewardName(id, item['api_name']?.toString()),
          ),
        );
      }
    }

    var radarReduced = false;
    final happening = _map(data['api_happening']);
    if (happening != null) {
      final id = _positive(
        happening['api_icon_id'],
        _int(happening['api_mst_id']),
      );
      final type = GameResourceType.values
          .where((candidate) => candidate.apiId == id)
          .firstOrNull;
      final count = _positive(happening['api_count'], 0);
      if (type != null && count > 0) {
        deltas[type] = (deltas[type] ?? 0) - count;
      }
      radarReduced = _int(happening['api_dentan']) != 0;
    }
    if (deltas.isEmpty && rewards.isEmpty) return;

    final mapArea = _positive(data['api_maparea_id'], 0);
    final mapNo = _positive(data['api_mapinfo_no'], 0);
    final node = _positive(data['api_no'], 0);
    final eventKey =
        '${event.path}:${event.capturedAt.microsecondsSinceEpoch}:'
        'sequence:${event.sequence}:$mapArea-$mapNo-$node';
    await _database.insertMapResourceRecord(
      MapResourceLogEntry(
        eventKey: eventKey,
        timestamp: event.capturedAt,
        mapArea: mapArea,
        mapNo: mapNo,
        mapName: state.mapName(mapArea, mapNo) ?? '',
        node: node,
        mapDifficulty: state.mapDifficulty(mapArea, mapNo),
        fuelDelta: deltas[GameResourceType.fuel] ?? 0,
        ammoDelta: deltas[GameResourceType.ammunition] ?? 0,
        steelDelta: deltas[GameResourceType.steel] ?? 0,
        bauxiteDelta: deltas[GameResourceType.bauxite] ?? 0,
        instantBuildDelta: deltas[GameResourceType.instantBuild] ?? 0,
        instantRepairDelta: deltas[GameResourceType.instantRepair] ?? 0,
        developmentMaterialDelta:
            deltas[GameResourceType.developmentMaterial] ?? 0,
        improvementMaterialDelta:
            deltas[GameResourceType.improvementMaterial] ?? 0,
        rewardItems: rewards,
        radarReduced: radarReduced,
      ),
    );
  }

  Future<void> _recordExpedition(
    CapturedApiEvent event,
    GameState state,
  ) async {
    final data = _data(event);
    final expeditionId = _expeditionId(event, state, data);
    final master = state.masterMissions[expeditionId];
    final materials = _intList(data['api_get_material']);
    final rewards = _rewardItems(data);
    final item1 = rewards.isNotEmpty ? rewards[0] : const _RewardItem();
    final item2 = rewards.length > 1 ? rewards[1] : const _RewardItem();
    await _database.insertExpeditionResult(
      expeditionId: expeditionId,
      name: master?.name ?? data['api_quest_name']?.toString() ?? '远征',
      result: _int(data['api_clear_result']),
      materials: materials,
      bucketYield: rewards
          .where((item) => item.id == 1)
          .fold<int>(0, (total, item) => total + item.count),
      item1Id: item1.id > 0 ? item1.id : null,
      item1Name: item1.name,
      item1Count: item1.count,
      item2Id: item2.id > 0 ? item2.id : null,
      item2Name: item2.name,
      item2Count: item2.count,
      rewardItems: [for (final item in rewards) item.toJson()],
      timestamp: event.capturedAt.millisecondsSinceEpoch,
    );
  }

  int _expeditionId(
    CapturedApiEvent event,
    GameState state,
    Map<String, Object?> data,
  ) {
    final requestedId = _int(event.requestParams['api_mission_id']);
    if (requestedId > 0) return requestedId;

    final deckId = _int(event.requestParams['api_deck_id']);
    for (final fleet in state.fleets) {
      if (fleet.id == deckId && fleet.mission.missionId > 0) {
        return fleet.mission.missionId;
      }
    }

    final name = data['api_quest_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      for (final mission in state.masterMissions.values) {
        if (mission.name.trim() == name) return mission.id;
      }
    }
    return 0;
  }

  List<_RewardItem> _rewardItems(Map<String, Object?> data) {
    final result = <_RewardItem>[];
    final flags = _intList(data['api_useitem_flag']);

    void collect(Object? value, {int fallbackId = 0}) {
      if (value is List) {
        for (var index = 0; index < value.length; index++) {
          collect(
            value[index],
            fallbackId: index < flags.length ? flags[index] : fallbackId,
          );
        }
        return;
      }
      final reward = _rewardItem(value, fallbackId: fallbackId);
      if (reward.id > 0 && reward.count > 0) result.add(reward);
    }

    final modern = data['api_get_items'];
    if (modern is List && modern.isNotEmpty) {
      collect(modern);
    } else {
      final numberedKeys =
          data.keys
              .where((key) => RegExp(r'^api_get_item\d+$').hasMatch(key))
              .toList(growable: false)
            ..sort((left, right) {
              final leftSlot = int.parse(left.substring('api_get_item'.length));
              final rightSlot = int.parse(
                right.substring('api_get_item'.length),
              );
              return leftSlot.compareTo(rightSlot);
            });
      for (final key in numberedKeys) {
        final slotIndex = int.parse(key.substring('api_get_item'.length)) - 1;
        collect(
          data[key],
          fallbackId: slotIndex >= 0 && slotIndex < flags.length
              ? flags[slotIndex]
              : 0,
        );
      }
    }
    return result;
  }

  Future<void> _recordDevelopment(
    CapturedApiEvent event,
    GameState state,
  ) async {
    final data = _data(event);
    final modernItems = data['api_get_items'];
    final rawItems = modernItems is List
        ? (modernItems.isEmpty ? const <Object?>[null] : modernItems)
        : <Object?>[data['api_slot_item']];
    await _database.insertDevelopmentRecords(<DevelopmentLogEntry>[
      for (final rawItem in rawItems)
        _developmentResult(event, state, _map(rawItem)),
    ]);
  }

  DevelopmentLogEntry _developmentResult(
    CapturedApiEvent event,
    GameState state,
    Map<String, Object?>? slotItem,
  ) {
    final equipmentId = _int(slotItem?['api_slotitem_id']);
    final success = equipmentId > 0;
    final master = state.masterSlotItems[equipmentId];
    final iconId = master != null && master.type.length > 3
        ? master.type[3]
        : -1;
    return DevelopmentLogEntry(
      timestamp: event.capturedAt.millisecondsSinceEpoch,
      success: success,
      equipmentId: success && equipmentId > 0 ? equipmentId : null,
      equipmentName: success ? (master?.name ?? '装备 ID $equipmentId') : '—',
      equipmentType: success ? _equipmentType(master) : '—',
      equipmentIconId: iconId,
      fuel: _int(event.requestParams['api_item1']),
      ammo: _int(event.requestParams['api_item2']),
      steel: _int(event.requestParams['api_item3']),
      bauxite: _int(event.requestParams['api_item4']),
      secretaryName: _secretaryName(state),
    );
  }

  Future<void> _recordConstructionStart(
    CapturedApiEvent event,
    GameState state,
  ) async {
    final dockId = _int(event.requestParams['api_kdock_id']);
    final pending = _PendingConstruction(
      timestamp: event.capturedAt.millisecondsSinceEpoch,
      constructionType: _int(event.requestParams['api_large_flag']) > 0
          ? '大型建造'
          : '普通建造',
      fuel: _int(event.requestParams['api_item1']),
      ammo: _int(event.requestParams['api_item2']),
      steel: _int(event.requestParams['api_item3']),
      bauxite: _int(event.requestParams['api_item4']),
      developmentMaterial: _int(event.requestParams['api_item5']),
      secretaryName: _secretaryName(state),
    );
    final shipId = _createdShipId(
      _data(event, allowMissingData: true)['api_kdock'],
      dockId,
    );
    final master = state.masterShips[shipId];
    final shipType = master == null
        ? null
        : state.masterShipTypes[master.shipTypeId]?.name;
    final recordId = await _database.insertConstructionStartRecord(
      dockId: dockId,
      timestamp: pending.timestamp,
      constructionType: pending.constructionType,
      shipId: shipId > 0 ? shipId : null,
      shipName: master?.name ?? '建造中',
      shipType: shipType ?? '—',
      fuel: pending.fuel,
      ammo: pending.ammo,
      steel: pending.steel,
      bauxite: pending.bauxite,
      developmentMaterial: pending.developmentMaterial,
      secretaryName: pending.secretaryName,
    );
    _pendingConstructions[dockId] = pending.withRecordId(recordId);
  }

  Future<void> _recordConstruction(
    CapturedApiEvent event,
    GameState state,
  ) async {
    final dockId = _int(event.requestParams['api_kdock_id']);
    final pending = _pendingConstructions.remove(dockId);
    final shipData = _map(_data(event)['api_ship']);
    final shipId = _int(shipData?['api_ship_id']);
    final master = state.masterShips[shipId];
    final shipType = master == null
        ? null
        : state.masterShipTypes[master.shipTypeId]?.name;
    ConstructionDock? currentDock;
    for (final dock in state.constructionDocks) {
      if (dock.id == dockId &&
          dock.isBuilding &&
          dock.createdShipMasterId == shipId) {
        currentDock = dock;
        break;
      }
    }
    var construction = pending;
    var recordId = pending?.recordId ?? 0;
    if (pending != null &&
        currentDock != null &&
        !_pendingMatchesDock(pending, currentDock, master)) {
      construction = null;
      recordId = 0;
    }
    if (construction == null && currentDock != null) {
      construction = _constructionFromDock(
        currentDock,
        master,
        fallback: event.capturedAt,
      );
    }
    if (recordId <= 0) {
      final persisted = await _database.getPendingConstructionRecordForDock(
        dockId,
      );
      if (_persistedConstructionMatches(
        persisted,
        currentDock: currentDock,
        master: master,
        shipId: shipId,
      )) {
        recordId = _int(persisted?['id']);
      } else if (persisted != null) {
        await _database.clearPendingConstructionRecordForDock(
          dockId: dockId,
          recordId: _int(persisted['id']),
        );
      }
    }
    if (recordId <= 0 && construction != null) {
      final latest = await _database.getLatestConstructionRecordForDock(dockId);
      if (_matchesConstruction(latest, construction, shipId)) {
        recordId = _int(latest?['id']);
      }
    }
    final updated =
        recordId > 0 &&
        await _database.updateConstructionResult(
          recordId: recordId,
          dockId: dockId,
          shipId: shipId,
          shipName: master?.name ?? '舰娘 ID $shipId',
          shipType: shipType ?? '未知舰种',
          markCollected: true,
        );
    if (!updated && construction != null) {
      await _database.insertConstructionRecord(
        dockId: dockId,
        timestamp: construction.timestamp,
        constructionType: construction.constructionType,
        shipId: shipId > 0 ? shipId : null,
        shipName: master?.name ?? '舰娘 ID $shipId',
        shipType: shipType ?? '未知舰种',
        fuel: construction.fuel,
        ammo: construction.ammo,
        steel: construction.steel,
        bauxite: construction.bauxite,
        developmentMaterial: construction.developmentMaterial,
        secretaryName: construction.secretaryName,
      );
    }
  }

  Future<void> _recordConstructionDockUpdate(
    CapturedApiEvent event,
    GameState state,
  ) async {
    final decoded = GameApiDecoder.decodeEventData(event);
    final rawDocks = decoded is Map ? decoded['api_kdock'] : decoded;
    final docks = rawDocks is List ? rawDocks : <Object?>[rawDocks];
    for (final rawDock in docks) {
      final dock = _map(rawDock);
      if (dock == null) continue;
      final dockId = _int(dock['api_id']);
      final shipId = _int(dock['api_created_ship_id']);
      if (dockId <= 0) continue;
      if (shipId <= 0) {
        _pendingConstructions.remove(dockId);
        if (_int(dock['api_state']) == 0) {
          final persisted = await _database.getPendingConstructionRecordForDock(
            dockId,
          );
          if (persisted != null) {
            await _database.clearPendingConstructionRecordForDock(
              dockId: dockId,
              recordId: _int(persisted['id']),
            );
          }
        }
        continue;
      }
      final master = state.masterShips[shipId];
      final shipType = master == null
          ? null
          : state.masterShipTypes[master.shipTypeId]?.name;
      final currentDock = _constructionDockFromApi(dock);
      final pending = _pendingConstructions[dockId];
      var recordId = 0;
      if (pending != null && pending.recordId > 0) {
        if (_pendingMatchesDock(pending, currentDock, master)) {
          recordId = pending.recordId;
        } else {
          _pendingConstructions.remove(dockId);
        }
      }
      if (recordId <= 0) {
        final persisted = await _database.getPendingConstructionRecordForDock(
          dockId,
        );
        if (_persistedConstructionMatches(
          persisted,
          currentDock: currentDock,
          master: master,
          shipId: shipId,
        )) {
          recordId = _int(persisted?['id']);
        } else if (persisted != null) {
          await _database.clearPendingConstructionRecordForDock(
            dockId: dockId,
            recordId: _int(persisted['id']),
          );
        }
      }
      if (recordId <= 0) continue;
      await _database.updateConstructionResult(
        recordId: recordId,
        dockId: dockId,
        shipId: shipId,
        shipName: master?.name ?? '舰娘 ID $shipId',
        shipType: shipType ?? '未知舰种',
      );
    }
  }

  ConstructionDock _constructionDockFromApi(Map<String, dynamic> data) {
    final completionMilliseconds = _int(data['api_complete_time']);
    return ConstructionDock(
      id: _int(data['api_id']),
      state: _int(data['api_state']),
      createdShipMasterId: _int(data['api_created_ship_id']),
      completionTime: completionMilliseconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(completionMilliseconds)
          : null,
      fuel: _int(data['api_item1']),
      ammunition: _int(data['api_item2']),
      steel: _int(data['api_item3']),
      bauxite: _int(data['api_item4']),
      developmentMaterial: _int(data['api_item5']),
    );
  }

  _PendingConstruction _constructionFromDock(
    ConstructionDock dock,
    MasterShip? master, {
    required DateTime fallback,
  }) {
    final startedAt = _constructionStartedAt(dock, master) ?? fallback;
    return _PendingConstruction(
      timestamp: startedAt.millisecondsSinceEpoch,
      constructionType: dock.isLargeConstruction ? '大型建造' : '普通建造',
      fuel: dock.fuel,
      ammo: dock.ammunition,
      steel: dock.steel,
      bauxite: dock.bauxite,
      developmentMaterial: dock.developmentMaterial,
      secretaryName: '—',
    );
  }

  bool _pendingMatchesDock(
    _PendingConstruction pending,
    ConstructionDock dock,
    MasterShip? master,
  ) {
    if (pending.constructionType !=
            (dock.isLargeConstruction ? '大型建造' : '普通建造') ||
        pending.fuel != dock.fuel ||
        pending.ammo != dock.ammunition ||
        pending.steel != dock.steel ||
        pending.bauxite != dock.bauxite ||
        pending.developmentMaterial != dock.developmentMaterial) {
      return false;
    }
    final startedAt = _constructionStartedAt(dock, master);
    if (startedAt == null) return true;
    return (pending.timestamp - startedAt.millisecondsSinceEpoch).abs() <=
        const Duration(seconds: 5).inMilliseconds;
  }

  DateTime? _constructionStartedAt(ConstructionDock dock, MasterShip? master) {
    if (dock.startedAt != null) return dock.startedAt;
    if (dock.completionTime == null || (master?.buildTimeMinutes ?? 0) <= 0) {
      return null;
    }
    return dock.completionTime!.subtract(
      Duration(minutes: master!.buildTimeMinutes),
    );
  }

  int _createdShipId(Object? rawDocks, int dockId) {
    final docks = rawDocks is List ? rawDocks : <Object?>[rawDocks];
    for (final rawDock in docks) {
      final dock = _map(rawDock);
      if (dock == null) continue;
      final id = _int(dock['api_id']);
      if (dockId > 0 && id > 0 && id != dockId) continue;
      final shipId = _int(dock['api_created_ship_id']);
      if (shipId > 0) return shipId;
    }
    return 0;
  }

  bool _matchesConstruction(
    Map<String, dynamic>? row,
    _PendingConstruction construction,
    int shipId,
  ) {
    if (row == null ||
        _int(row['dock_id']) <= 0 ||
        row['construction_type'] != construction.constructionType ||
        _int(row['fuel']) != construction.fuel ||
        _int(row['ammo']) != construction.ammo ||
        _int(row['steel']) != construction.steel ||
        _int(row['bauxite']) != construction.bauxite ||
        _int(row['development_material']) != construction.developmentMaterial) {
      return false;
    }
    final recordedShipId = _int(row['ship_id']);
    if (recordedShipId > 0 && recordedShipId != shipId) return false;
    final timestampDelta = (_int(row['timestamp']) - construction.timestamp)
        .abs();
    return timestampDelta <= const Duration(seconds: 5).inMilliseconds;
  }

  bool _persistedConstructionMatches(
    Map<String, dynamic>? row, {
    required ConstructionDock? currentDock,
    required MasterShip? master,
    required int shipId,
  }) {
    if (row == null || _int(row['dock_id']) <= 0) return false;
    final recordedShipId = _int(row['ship_id']);
    if (recordedShipId > 0 && recordedShipId != shipId) return false;
    if (currentDock == null) return true;

    final construction = _constructionFromDock(
      currentDock,
      master,
      fallback: DateTime.fromMillisecondsSinceEpoch(_int(row['timestamp'])),
    );
    if (row['construction_type'] != construction.constructionType ||
        _int(row['fuel']) != construction.fuel ||
        _int(row['ammo']) != construction.ammo ||
        _int(row['steel']) != construction.steel ||
        _int(row['bauxite']) != construction.bauxite ||
        _int(row['development_material']) != construction.developmentMaterial) {
      return false;
    }

    final startedAt = _constructionStartedAt(currentDock, master);
    if (startedAt == null) return true;
    return (_int(row['timestamp']) - startedAt.millisecondsSinceEpoch).abs() <=
        const Duration(seconds: 5).inMilliseconds;
  }

  Future<void> _recordRetiredShips(
    CapturedApiEvent event,
    GameState state, {
    required String type,
  }) async {
    final raw = type == '改修'
        ? event.requestParams['api_id_items']
        : event.requestParams['api_ship_id'];
    final records = <RetirementLogEntry>[];
    for (final shipId in _ids(raw)) {
      final ship = state.ships[shipId];
      if (ship == null) continue;
      final master = state.masterShips[ship.masterId];
      records.add(
        RetirementLogEntry(
          timestamp: event.capturedAt.millisecondsSinceEpoch,
          type: type,
          shipType: master == null
              ? '未知舰种'
              : state.masterShipTypes[master.shipTypeId]?.name ?? '未知舰种',
          shipName: master?.name ?? '舰娘 ID ${ship.masterId}',
          level: ship.level,
        ),
      );
    }
    await _database.insertRetirementRecords(records);
  }

  String _secretaryName(GameState state) {
    if (state.fleets.isEmpty || state.fleets.first.shipIds.isEmpty) return '—';
    final ship = state.ships[state.fleets.first.shipIds.first];
    final master = ship == null ? null : state.masterShips[ship.masterId];
    return ship == null ? '—' : '${master?.name ?? '舰娘'} Lv.${ship.level}';
  }

  String _equipmentType(MasterSlotItem? master) {
    final type = master != null && master.type.length > 2 ? master.type[2] : -1;
    return switch (type) {
      1 => '小口径主炮',
      2 => '中口径主炮',
      3 => '大口径主炮',
      4 => '副炮',
      5 => '鱼雷',
      6 => '舰上战斗机',
      7 => '舰上爆击机',
      8 => '舰上攻击机',
      9 => '舰上侦察机',
      10 => '水上侦察机',
      11 => '水上爆击机',
      12 => '小型电探',
      13 => '大型电探',
      14 => '声呐',
      15 => '爆雷',
      19 => '炮弹',
      21 => '对空机枪',
      24 => '上陆用舟艇',
      32 => '潜水舰鱼雷',
      _ => '其他装备',
    };
  }

  Map<String, Object?> _data(
    CapturedApiEvent event, {
    bool allowMissingData = false,
  }) {
    final data = GameApiDecoder.decodeEventData(
      event,
      allowMissingData: allowMissingData,
    );
    return data is Map
        ? Map<String, Object?>.from(data)
        : const <String, Object?>{};
  }

  Map<String, Object?>? _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : null;

  List<Map<String, Object?>> _maps(Object? value) {
    if (value is Map) return <Map<String, Object?>>[Map.from(value)];
    if (value is! List) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[for (final item in value) ?_map(item)];
  }

  int _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  int _positive(Object? value, int fallback) {
    final parsed = _int(value);
    return parsed > 0 ? parsed : fallback;
  }

  List<int> _intList(Object? value) => value is List
      ? <int>[for (final item in value) _int(item)]
      : const <int>[];

  List<int> _ids(Object? value) => value
      .toString()
      .split(',')
      .map((item) => int.tryParse(item.trim()) ?? 0)
      .where((id) => id > 0)
      .toList(growable: false);

  _RewardItem _rewardItem(Object? value, {int fallbackId = 0}) {
    final item = _map(value);
    if (item == null) return const _RewardItem();
    final capturedId = _int(item['api_useitem_id']);
    final id = capturedId > 0 ? capturedId : fallbackId;
    return _RewardItem(
      id: id,
      name: expeditionRewardName(id, item['api_useitem_name']?.toString()),
      count: _int(item['api_useitem_count']),
    );
  }
}

final class _PendingConstruction {
  const _PendingConstruction({
    this.recordId = 0,
    required this.timestamp,
    required this.constructionType,
    required this.fuel,
    required this.ammo,
    required this.steel,
    required this.bauxite,
    required this.developmentMaterial,
    required this.secretaryName,
  });

  final int recordId;
  final int timestamp;
  final String constructionType;
  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;
  final int developmentMaterial;
  final String secretaryName;

  _PendingConstruction withRecordId(int value) => _PendingConstruction(
    recordId: value,
    timestamp: timestamp,
    constructionType: constructionType,
    fuel: fuel,
    ammo: ammo,
    steel: steel,
    bauxite: bauxite,
    developmentMaterial: developmentMaterial,
    secretaryName: secretaryName,
  );
}

final class _RewardItem {
  const _RewardItem({this.id = 0, this.name, this.count = 0});
  final int id;
  final String? name;
  final int count;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'count': count,
  };
}
