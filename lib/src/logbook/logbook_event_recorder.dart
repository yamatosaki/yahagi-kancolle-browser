import '../bridge/captured_api_event.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_state.dart';
import 'expedition_log_catalog.dart';
import 'logbook_database.dart';

final class LogbookEventRecorder {
  LogbookEventRecorder({LogbookDatabase? database})
    : _database = database ?? LogbookDatabase.instance;

  final LogbookDatabase _database;
  final Map<int, _PendingConstruction> _pendingConstructions = {};

  static const supportedPaths = <String>{
    '/kcsapi/api_req_mission/result',
    '/kcsapi/api_req_kousyou/createitem',
    '/kcsapi/api_req_kousyou/createship',
    '/kcsapi/api_req_kousyou/getship',
    '/kcsapi/api_get_member/kdock',
    '/kcsapi/api_req_kousyou/destroyship',
    '/kcsapi/api_req_kaisou/powerup',
  };

  bool supports(String path) => supportedPaths.contains(path);

  Future<void> record(CapturedApiEvent event, GameState state) async {
    if (!supports(event.path) || event.apiResult != 1) return;
    switch (event.path) {
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

    void collect(Object? value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      final reward = _rewardItem(value);
      if (reward.id > 0 && reward.count > 0) result.add(reward);
    }

    final modern = data['api_get_items'];
    if (modern is List) {
      collect(modern);
    } else {
      final numberedKeys =
          data.keys
              .where((key) => key.startsWith('api_get_item'))
              .toList(growable: false)
            ..sort();
      for (final key in numberedKeys) {
        collect(data[key]);
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
    if (modernItems is List) {
      if (modernItems.isEmpty) {
        await _insertDevelopmentResult(event, state, null);
      } else {
        for (final rawItem in modernItems) {
          await _insertDevelopmentResult(event, state, _map(rawItem));
        }
      }
      return;
    }
    await _insertDevelopmentResult(event, state, _map(data['api_slot_item']));
  }

  Future<void> _insertDevelopmentResult(
    CapturedApiEvent event,
    GameState state,
    Map<String, Object?>? slotItem,
  ) async {
    final equipmentId = _int(slotItem?['api_slotitem_id']);
    final success = equipmentId > 0;
    final master = state.masterSlotItems[equipmentId];
    final iconId = master != null && master.type.length > 3
        ? master.type[3]
        : -1;
    await _database.insertDevelopmentRecord(
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
    _pendingConstructions[dockId] = pending;

    final shipId = _createdShipId(_data(event)['api_kdock'], dockId);
    final master = state.masterShips[shipId];
    final shipType = master == null
        ? null
        : state.masterShipTypes[master.shipTypeId]?.name;
    await _database.insertConstructionRecord(
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
    final updated = await _database.updateConstructionResult(
      dockId: dockId,
      shipId: shipId,
      shipName: master?.name ?? '舰娘 ID $shipId',
      shipType: shipType ?? '未知舰种',
    );
    if (!updated && pending != null) {
      await _database.insertConstructionRecord(
        dockId: dockId,
        timestamp: pending.timestamp,
        constructionType: pending.constructionType,
        shipId: shipId > 0 ? shipId : null,
        shipName: master?.name ?? '舰娘 ID $shipId',
        shipType: shipType ?? '未知舰种',
        fuel: pending.fuel,
        ammo: pending.ammo,
        steel: pending.steel,
        bauxite: pending.bauxite,
        developmentMaterial: pending.developmentMaterial,
        secretaryName: pending.secretaryName,
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
      if (dockId <= 0 || shipId <= 0) continue;
      final master = state.masterShips[shipId];
      final shipType = master == null
          ? null
          : state.masterShipTypes[master.shipTypeId]?.name;
      await _database.updateConstructionResult(
        dockId: dockId,
        shipId: shipId,
        shipName: master?.name ?? '舰娘 ID $shipId',
        shipType: shipType ?? '未知舰种',
      );
    }
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

  Future<void> _recordRetiredShips(
    CapturedApiEvent event,
    GameState state, {
    required String type,
  }) async {
    final raw = type == '改修'
        ? event.requestParams['api_id_items']
        : event.requestParams['api_ship_id'];
    for (final shipId in _ids(raw)) {
      final ship = state.ships[shipId];
      if (ship == null) continue;
      final master = state.masterShips[ship.masterId];
      await _database.insertRetirementRecord(
        timestamp: event.capturedAt.millisecondsSinceEpoch,
        type: type,
        shipType: master == null
            ? '未知舰种'
            : state.masterShipTypes[master.shipTypeId]?.name ?? '未知舰种',
        shipName: master?.name ?? '舰娘 ID ${ship.masterId}',
        level: ship.level,
      );
    }
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

  Map<String, Object?> _data(CapturedApiEvent event) {
    final data = GameApiDecoder.decodeEventData(event);
    return data is Map
        ? Map<String, Object?>.from(data)
        : const <String, Object?>{};
  }

  Map<String, Object?>? _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : null;

  int _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  List<int> _intList(Object? value) => value is List
      ? <int>[for (final item in value) _int(item)]
      : const <int>[];

  List<int> _ids(Object? value) => value
      .toString()
      .split(',')
      .map((item) => int.tryParse(item.trim()) ?? 0)
      .where((id) => id > 0)
      .toList(growable: false);

  _RewardItem _rewardItem(Object? value) {
    final item = _map(value);
    if (item == null) return const _RewardItem();
    final id = _int(item['api_useitem_id']);
    return _RewardItem(
      id: id,
      name: expeditionRewardName(id, item['api_useitem_name']?.toString()),
      count: _int(item['api_useitem_count']),
    );
  }
}

final class _PendingConstruction {
  const _PendingConstruction({
    required this.timestamp,
    required this.constructionType,
    required this.fuel,
    required this.ammo,
    required this.steel,
    required this.bauxite,
    required this.developmentMaterial,
    required this.secretaryName,
  });

  final int timestamp;
  final String constructionType;
  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;
  final int developmentMaterial;
  final String secretaryName;
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
