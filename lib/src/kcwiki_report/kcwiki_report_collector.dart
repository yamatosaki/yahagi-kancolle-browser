import 'dart:convert';
import 'dart:math' as math;

import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import '../game_state/fleet_metrics.dart';
import '../game_state/game_state.dart';
import 'kcwiki_report_request.dart';

final class KcwikiReportCollector {
  KcwikiReportCollector({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String schemaVersion = String.fromEnvironment(
    'KCWIKI_REPORT_VERSION',
    defaultValue: 'yahagi-1',
  );
  static final Set<String> supportedPaths = Set<String>.unmodifiable(<String>{
    '/kcsapi/api_start2/getData',
    '/kcsapi/api_get_member/questlist',
    '/kcsapi/api_req_quest/clearitemget',
    '/kcsapi/api_req_kousyou/remodel_slotlist',
    '/kcsapi/api_req_kousyou/remodel_slotlist_detail',
    '/kcsapi/api_req_member/set_friendly_request',
    '/kcsapi/api_port/port',
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/next',
    ...GameCapturePathCatalog.battlePhases,
    ...GameCapturePathCatalog.battleResults,
    ...GameCapturePathCatalog.battleRetreat,
  });

  final DateTime Function() _clock;
  final Map<int, Map<String, Object?>> _quests = <int, Map<String, Object?>>{};
  int? _clearedQuestId;
  int? _clearedQuestDay;
  List<Map<String, Object?>> _remodelList = <Map<String, Object?>>[];
  int _mapAreaId = 0;
  int _mapNo = 0;
  int _cellId = 0;
  int _deckId = 1;
  int _cellDataCount = 0;
  Set<int> _bossCells = <int>{};
  final List<int> _route = <int>[];
  final Set<int> _escapeList = <int>{};
  final List<Map<String, Object?>> _battlePackets = <Map<String, Object?>>[];
  Map<String, Object?>? _battleFleetBefore;
  String _formation = '';
  Map<String, Object?> _friendlyStatus = <String, Object?>{
    'flag': 0,
    'type': 0,
  };

  List<KcwikiReportRequest> accept(CapturedApiEvent event, GameState state) {
    final output = <KcwikiReportRequest>[];
    final data = event.decodedEnvelope?['api_data'];

    switch (event.path) {
      case '/kcsapi/api_start2/getData':
        reset();
      case '/kcsapi/api_get_member/questlist':
        output.addAll(_acceptQuestList(data));
      case '/kcsapi/api_req_quest/clearitemget':
        if (event.apiResult == 1) {
          final id = _int(event.requestParams['api_quest_id']);
          if (id > 0) {
            _clearedQuestId = id;
            _clearedQuestDay = _gameDay(_clock());
          }
        }
      case '/kcsapi/api_req_kousyou/remodel_slotlist':
        _remodelList = _mapList(data);
        if (_remodelList.isNotEmpty) {
          output.add(_remodelRequest(state));
        }
      case '/kcsapi/api_req_kousyou/remodel_slotlist_detail':
        final id = _int(event.requestParams['api_id']);
        final detail = _stringMap(data);
        final index = _remodelList.indexWhere(
          (item) => _int(item['api_id']) == id,
        );
        if (index >= 0) {
          _remodelList[index] = <String, Object?>{
            ..._remodelList[index],
            ...detail,
          };
        } else if (detail.isNotEmpty) {
          _remodelList.add(<String, Object?>{'api_id': id, ...detail});
        }
        if (_remodelList.isNotEmpty) output.add(_remodelRequest(state));
      case '/kcsapi/api_req_member/set_friendly_request':
        if (event.apiResult == 1) {
          _friendlyStatus = <String, Object?>{
            'flag': _int(event.requestParams['api_request_flag']),
            'type': _int(event.requestParams['api_request_type']),
            'version': schemaVersion,
          };
        }
      case '/kcsapi/api_port/port':
        output.addAll(_flushBattle(state));
        final port = _stringMap(data);
        final setting = _stringMap(port['api_friendly_setting']);
        if (setting.isNotEmpty) {
          _friendlyStatus = <String, Object?>{
            'flag': _int(setting['api_request_flag']),
            'type': _int(setting['api_request_type']),
            'version': schemaVersion,
          };
        }
      case '/kcsapi/api_req_map/start':
        _beginSortie(event, data);
        output.add(_nextWayRequest(data, state));
      case '/kcsapi/api_req_map/next':
        output.addAll(_flushBattle(state));
        _advanceRoute(data);
        final destruction = _stringMap(
          _stringMap(data)['api_destruction_battle'],
        );
        if (destruction['api_air_base_attack'] case final attack?) {
          output.add(_airBaseRequest(destruction, attack));
        }
        output.add(_nextWayRequest(data, state));
      case '/kcsapi/api_req_sortie/goback_port':
      case '/kcsapi/api_req_combined_battle/goback_port':
        _recordEscapes(data);
      default:
        if (GameCapturePathCatalog.battlePhases.contains(event.path)) {
          output.addAll(_acceptBattlePhase(event, data, state));
        } else if (GameCapturePathCatalog.battleResults.contains(event.path)) {
          _appendBattlePacket(event, data, state);
        }
    }
    return output;
  }

  void reset() {
    _quests.clear();
    _clearedQuestId = null;
    _clearedQuestDay = null;
    _remodelList = <Map<String, Object?>>[];
    _mapAreaId = 0;
    _mapNo = 0;
    _cellId = 0;
    _deckId = 1;
    _cellDataCount = 0;
    _bossCells = <int>{};
    _route.clear();
    _escapeList.clear();
    _battlePackets.clear();
    _battleFleetBefore = null;
    _formation = '';
    _friendlyStatus = <String, Object?>{'flag': 0, 'type': 0};
  }

  List<KcwikiReportRequest> _acceptQuestList(Object? raw) {
    final list = _mapList(_stringMap(raw)['api_list']);
    final next = <int, Map<String, Object?>>{
      for (final quest in list)
        if (_int(quest['api_no']) > 0) _int(quest['api_no']): quest,
    };
    final output = <KcwikiReportRequest>[];
    final cleared = _clearedQuestId;
    if (cleared != null && _clearedQuestDay == _gameDay(_clock())) {
      final after = next.keys
          .where((id) => !_quests.containsKey(id))
          .toList(growable: false);
      if (after.isNotEmpty && !after.contains(201)) {
        final detail = <Object?>[
          ?_quests[cleared],
          for (final id in after) next[id]!,
        ];
        output.add(
          KcwikiReportRequest.form(KcwikiReportModule.quest, <String, Object?>{
            'current': cleared,
            'after': after,
            'detail': detail,
            'version': schemaVersion,
          }),
        );
      }
    }
    _quests
      ..clear()
      ..addAll(next);
    _clearedQuestId = null;
    _clearedQuestDay = null;
    return output;
  }

  KcwikiReportRequest _remodelRequest(GameState state) {
    OwnedShip? assistant;
    if (state.fleets.isNotEmpty && state.fleets.first.shipIds.length > 1) {
      assistant = state.ships[state.fleets.first.shipIds[1]];
    }
    return KcwikiReportRequest.json(
      KcwikiReportModule.remodel,
      <String, Object?>{
        'ship': assistant == null
            ? <String, Object?>{}
            : _fullShip(assistant, state),
        'list': _remodelList,
        'timestamp': _clock().millisecondsSinceEpoch,
        'version': schemaVersion,
      },
    );
  }

  void _beginSortie(CapturedApiEvent event, Object? raw) {
    _battlePackets.clear();
    _battleFleetBefore = null;
    _route.clear();
    _escapeList.clear();
    final data = _stringMap(raw);
    _mapAreaId = _int(data['api_maparea_id']);
    _mapNo = _int(data['api_mapinfo_no']);
    _cellId = _int(data['api_no']);
    _deckId = math.max(1, _int(event.requestParams['api_deck_id']));
    _route.add(_cellId);
    final cells = _mapList(data['api_cell_data']);
    _cellDataCount = cells.length;
    _bossCells = cells
        .where((cell) => _int(cell['api_color_no']) == 5)
        .map((cell) => _int(cell['api_no']))
        .toSet();
  }

  void _advanceRoute(Object? raw) {
    final data = _stringMap(raw);
    _cellId = _int(data['api_no']);
    if (_cellId > 0) _route.add(_cellId);
  }

  KcwikiReportRequest _nextWayRequest(Object? raw, GameState state) {
    final data = _stringMap(raw);
    final primary = _fleetById(state, _deckId);
    final combined =
        state.combinedFleetType != CombinedFleetType.none && _deckId == 1;
    final escort = combined ? _fleetById(state, 2) : null;
    final map = state.memberMapInfos[_mapAreaId * 100 + _mapNo];
    return KcwikiReportRequest.form(
      KcwikiReportModule.nextWayV2,
      <String, Object?>{
        'deck1': _routeShips(primary, state),
        'deck2': _routeShips(escort, state),
        'slot1': _routeSlots(primary, state),
        'slot2': _routeSlots(escort, state),
        'cell_ids': List<int>.from(_route),
        'mapLevels': <Object?>[
          <String, Object?>{
            '${_mapAreaId * 10 + _mapNo}': map?.selectedRank ?? 0,
          },
        ],
        'nextInfo': <String, Object?>{
          'api_maparea_id': _int(data['api_maparea_id'], _mapAreaId),
          'api_mapinfo_no': _int(data['api_mapinfo_no'], _mapNo),
          'api_defeat_count': map?.defeatCount ?? 0,
          'api_required_defeat_count': map?.requiredDefeatCount ?? 0,
          'api_now_maphp': map?.currentHp ?? 0,
          'api_max_maphp': map?.maxHp ?? 0,
          'api_itemget': _safeCopy(data['api_itemget']),
          'api_happening': _safeCopy(data['api_happening']),
        },
        'escapeList': _escapeList.toList(growable: false)..sort(),
        'combined_type': combined ? state.combinedFleetType.index : 0,
        'teitokuLv': state.admiralLevel,
        'saku': <String, Object?>{
          ..._saku('One', primary, state),
          ..._saku('Two', escort, state),
        },
        'api_cell_data': _cellDataCount,
        'version': schemaVersion,
      },
    );
  }

  KcwikiReportRequest _airBaseRequest(
    Map<String, Object?> destruction,
    Object attack,
  ) => KcwikiReportRequest.form(
    KcwikiReportModule.airBaseAttack,
    <String, Object?>{
      ...destruction,
      'api_air_base_attack': jsonEncode(_safeCopy(attack)),
      'maparea_id': _mapAreaId,
      'mapinfo_no': _mapNo,
      'curCellId': _cellId,
      'version': schemaVersion,
    },
  );

  List<KcwikiReportRequest> _acceptBattlePhase(
    CapturedApiEvent event,
    Object? raw,
    GameState state,
  ) {
    _formation = event.requestParams['api_formation']?.toString() ?? _formation;
    _appendBattlePacket(event, raw, state);
    final data = _stringMap(raw);
    final friendly = _stringMap(data['api_friendly_info']);
    if (friendly.isEmpty) return const <KcwikiReportRequest>[];
    final primary = _fleetById(state, _deckId);
    final combined =
        state.combinedFleetType != CombinedFleetType.none && _deckId == 1;
    return <KcwikiReportRequest>[
      KcwikiReportRequest.json(
        KcwikiReportModule.friendlyInfo,
        <String, Object?>{
          ...friendly,
          'maparea_id': _mapAreaId,
          'mapinfo_no': _mapNo,
          'curCellId': _cellId,
          'mapLevel': state.mapDifficulty(_mapAreaId, _mapNo),
          'friendly_status': _friendlyStatus,
          'escapeList': _escapeList.toList(growable: false)..sort(),
          'formation': _formation,
          'enemy': <String, Object?>{
            'api_ship_ke': _safeCopy(data['api_ship_ke']),
            'api_ship_ke_combined':
                _safeCopy(data['api_ship_ke_combined']) ?? <Object?>[],
            'api_e_nowhps': _safeCopy(data['api_e_nowhps']),
            'api_e_nowhps_combined':
                _safeCopy(data['api_e_nowhps_combined']) ?? <Object?>[],
            'api_xal01': _safeCopy(data['api_xal01']),
          },
          'deck1': _battleShips(primary, state),
          'deck2': combined
              ? _battleShips(_fleetById(state, 2), state)
              : <Object?>[],
          'api_friendly_battle': _safeCopy(data['api_friendly_battle']),
          'version': schemaVersion,
        },
      ),
    ];
  }

  void _appendBattlePacket(
    CapturedApiEvent event,
    Object? raw,
    GameState state,
  ) {
    if (_mapAreaId <= 0 || _mapNo <= 0 || _cellId <= 0) return;
    _battleFleetBefore ??= _battleFleet(state);
    _battlePackets.add(<String, Object?>{
      ..._stringMap(_safeCopy(raw)),
      'poi_time': event.capturedAt.millisecondsSinceEpoch,
      'poi_path': event.path,
    });
  }

  List<KcwikiReportRequest> _flushBattle(GameState state) {
    if (_battlePackets.isEmpty || _battleFleetBefore == null) {
      return const <KcwikiReportRequest>[];
    }
    final before = _battleFleetBefore!;
    final after = _battleFleet(state);
    final report = KcwikiReportRequest.json(
      KcwikiReportModule.battle,
      <String, Object?>{
        'data': <String, Object?>{
          'fleet': before,
          'fleetAfter': <String, Object?>{
            'main': after['main'],
            'escort': after['escort'],
            'LBAC': <Object?>[],
          },
          'map': <int>[_mapAreaId, _mapNo, _cellId],
          'packet': List<Map<String, Object?>>.from(_battlePackets),
          'type': _bossCells.contains(_cellId) ? 'Boss' : 'Normal',
          'version': schemaVersion,
          'groupId': _clock().microsecondsSinceEpoch,
          'time': _clock().millisecondsSinceEpoch,
          'api_cell_data': _cellDataCount,
          'mapLevel': state.mapDifficulty(_mapAreaId, _mapNo),
        },
      },
    );
    _battlePackets.clear();
    _battleFleetBefore = null;
    return <KcwikiReportRequest>[report];
  }

  Map<String, Object?> _battleFleet(GameState state) {
    final combined =
        state.combinedFleetType != CombinedFleetType.none && _deckId == 1;
    return <String, Object?>{
      'LBAC': <Object?>[],
      'escort': combined ? _battleShips(_fleetById(state, 2), state) : null,
      'main': _battleShips(_fleetById(state, _deckId), state),
      'support': null,
      'type': combined ? state.combinedFleetType.index : 0,
    };
  }

  void _recordEscapes(Object? raw) {
    final escape = _stringMap(_stringMap(raw)['api_escape']);
    for (final key in const <String>['api_escape_idx', 'api_tow_idx']) {
      final values = escape[key];
      if (values is List) {
        _escapeList.addAll(values.map(_int).where((value) => value > 0));
      }
    }
  }

  Map<String, num> _saku(String label, Fleet? fleet, GameState state) {
    if (fleet == null) {
      return <String, num>{
        'saku${label}25': 0,
        'saku${label}25a': 0,
        for (final modifier in const <int>[1, 2, 3, 4])
          'saku${label}33x$modifier': 0,
      };
    }
    final metrics = FleetMetrics.fromState(state, fleet);
    return <String, num>{
      'saku${label}25': _saku25(fleet, state),
      'saku${label}25a': _saku25a(fleet, state),
      for (final modifier in const <int>[1, 2, 3, 4])
        'saku${label}33x$modifier': metrics.formula33.length >= modifier
            ? _round2(metrics.formula33[modifier - 1].total)
            : 0,
    };
  }
}

Fleet? _fleetById(GameState state, int id) {
  for (final fleet in state.fleets) {
    if (fleet.id == id) return fleet;
  }
  return null;
}

List<Object?> _routeShips(Fleet? fleet, GameState state) {
  if (fleet == null) return <Object?>[];
  return <Object?>[
    for (final id in fleet.shipIds)
      if (state.ships[id] case final ship?)
        <String, Object?>{
          'api_ship_id': ship.masterId,
          'api_lv': ship.level,
          'api_sally_area': 0,
          'api_soku': ship.effectiveSpeed(state.masterForShip(ship)),
          'api_slotitem_ex': _extraSlotMasterId(ship, state),
          'api_slotitem_level': _extraSlotLevel(ship, state),
        },
  ];
}

List<Object?> _routeSlots(Fleet? fleet, GameState state) {
  if (fleet == null) return <Object?>[];
  return <Object?>[
    for (final id in fleet.shipIds)
      if (state.ships[id] case final ship?)
        <Object?>[
          for (final slotId in ship.slotIds)
            if (state.slotItems[slotId] case final item?)
              <String, Object?>{
                'api_id': item.instanceId,
                'api_slotitem_id': item.masterSlotItemId,
                'api_locked': item.locked ? 1 : 0,
                'api_level': item.level,
                'api_alv': item.proficiency,
              },
        ],
  ];
}

List<Object?> _battleShips(Fleet? fleet, GameState state) {
  if (fleet == null) return <Object?>[];
  return <Object?>[
    for (final id in fleet.shipIds)
      if (state.ships[id] case final ship?) _fullShip(ship, state),
  ];
}

Map<String, Object?> _fullShip(OwnedShip ship, GameState state) =>
    <String, Object?>{
      'api_id': ship.id,
      'api_sortno': state.masterForShip(ship)?.sortNo ?? 0,
      'api_ship_id': ship.masterId,
      'api_lv': ship.level,
      'api_exp': <int>[0, ship.nextExperience],
      'api_nowhp': ship.currentHp,
      'api_maxhp': ship.maxHp,
      'api_soku': ship.effectiveSpeed(state.masterForShip(ship)),
      'api_leng': ship.effectiveRange(state.masterForShip(ship)),
      'api_slot': List<int>.from(ship.slotIds),
      'api_onslot': List<int>.from(ship.onSlot),
      'api_slot_ex': ship.extraSlotId,
      'api_fuel': ship.currentFuel,
      'api_bull': ship.currentAmmo,
      'api_cond': ship.condition,
      'api_karyoku': <int>[ship.firepower, ship.firepowerMax],
      'api_raisou': <int>[ship.torpedo, ship.torpedoMax],
      'api_taiku': <int>[ship.antiAir, ship.antiAirMax],
      'api_soukou': <int>[ship.armor, ship.armorMax],
      'api_kaihi': <int>[ship.evasion, 0],
      'api_taisen': <int>[ship.antiSub, 0],
      'api_sakuteki': <int>[ship.lineOfSight, 0],
      'api_lucky': <int>[ship.luck, ship.luckMax],
      'api_locked': ship.locked ? 1 : 0,
      'poi_slot': <Object?>[
        for (final id in ship.slotIds)
          if (state.slotItems[id] case final item?) _slotItem(item),
      ],
      'poi_slot_ex': switch (state.slotItems[ship.extraSlotId]) {
        final item? => _slotItem(item),
        null => null,
      },
    };

Map<String, Object?> _slotItem(OwnedSlotItem item) => <String, Object?>{
  'api_id': item.instanceId,
  'api_slotitem_id': item.masterSlotItemId,
  'api_locked': item.locked ? 1 : 0,
  'api_level': item.level,
  'api_alv': item.proficiency,
};

int _extraSlotMasterId(OwnedShip ship, GameState state) =>
    state.slotItems[ship.extraSlotId]?.masterSlotItemId ?? -1;

int _extraSlotLevel(OwnedShip ship, GameState state) =>
    state.slotItems[ship.extraSlotId]?.level ?? -1;

double _saku25(Fleet fleet, GameState state) {
  var recon = 0.0;
  var radar = 0.0;
  var shipTotal = 0.0;
  for (final shipId in fleet.shipIds) {
    final ship = state.ships[shipId];
    if (ship == null) continue;
    shipTotal += ship.lineOfSight;
    for (final equipment in state.equipmentForShip(ship)) {
      final master = equipment.master;
      if (master == null) continue;
      final outer = master.type.length > 3 ? master.type[3] : -1;
      final inner = master.type.length > 2 ? master.type[2] : -1;
      if (outer == 9 || (outer == 10 && inner == 10)) {
        recon += master.lineOfSight;
        shipTotal -= master.lineOfSight;
      } else if (outer == 11) {
        radar += master.lineOfSight;
        shipTotal -= master.lineOfSight;
      }
    }
  }
  return _round2(recon * 2 + radar + math.sqrt(math.max(0, shipTotal)));
}

double _saku25a(Fleet fleet, GameState state) {
  var shipScore = 0.0;
  var equipmentScore = 0.0;
  for (final shipId in fleet.shipIds) {
    final ship = state.ships[shipId];
    if (ship == null) continue;
    var pure = ship.lineOfSight.toDouble();
    for (final equipment in state.equipmentForShip(ship)) {
      final master = equipment.master;
      if (master == null) continue;
      pure -= master.lineOfSight;
      final outer = master.type.length > 3 ? master.type[3] : -1;
      final inner = master.type.length > 2 ? master.type[2] : -1;
      final factor = switch (outer) {
        7 => 1.04,
        8 => 1.37,
        9 => 1.66,
        10 when inner == 10 => 2.0,
        10 when inner == 11 => 1.78,
        11 when inner == 12 => 1.0,
        11 when inner == 13 => 0.99,
        24 => 0.91,
        _ => 0.0,
      };
      equipmentScore += master.lineOfSight * factor;
    }
    shipScore += math.sqrt(math.max(0, pure)) * 1.69;
  }
  final admiralPenalty = 0.61 * (((state.admiralLevel + 4) ~/ 5) * 5);
  return _round2(shipScore + equipmentScore - admiralPenalty);
}

double _round2(num value) => (value * 100).round() / 100;

int _gameDay(DateTime value) =>
    (value.toUtc().millisecondsSinceEpoch ~/ 3600000 + 4) ~/ 24;

int _int(Object? value, [int fallback = 0]) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: _safeCopy(entry.value),
  };
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return <Map<String, Object?>>[];
  return <Map<String, Object?>>[
    for (final item in value)
      if (item is Map) _stringMap(item),
  ];
}

Object? _safeCopy(Object? value) {
  if (value is Map) {
    final output = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || _isSensitiveKey(key)) continue;
      output[key] = _safeCopy(entry.value);
    }
    return output;
  }
  if (value is List) {
    return <Object?>[for (final item in value) _safeCopy(item)];
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  return value.toString();
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return normalized == 'api_token' ||
      normalized == 'api_starttime' ||
      normalized == 'cookie' ||
      normalized == 'headers';
}
