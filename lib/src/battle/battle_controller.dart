import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/combat_state.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_state.dart';
import 'battle_damage_parser.dart';
import 'battle_models.dart';
import 'battle_node_label_resolver.dart';
import 'battle_rank.dart';
import 'battle_session.dart';
import '../logbook/logbook_database.dart';

final class BattleController extends ChangeNotifier {
  BattleController({
    required this.gameState,
    BattleDamageParser? damageParser,
    this.maxRecords = 100,
    this.nodeLabelResolver = const EmptyBattleNodeLabelResolver(),
  }) : _damageParser = damageParser ?? BattleDamageParser(),
       assert(maxRecords > 0);

  static const Set<String> _mapPaths = <String>{
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/next',
  };

  static const Set<String> _battlePaths = <String>{
    '/kcsapi/api_req_practice/battle',
    '/kcsapi/api_req_sortie/battle',
    '/kcsapi/api_req_sortie/airbattle',
    '/kcsapi/api_req_sortie/ld_airbattle',
    '/kcsapi/api_req_sortie/ld_shooting',
    '/kcsapi/api_req_combined_battle/battle',
    '/kcsapi/api_req_combined_battle/battle_water',
    '/kcsapi/api_req_combined_battle/airbattle',
    '/kcsapi/api_req_combined_battle/ld_airbattle',
    '/kcsapi/api_req_combined_battle/ld_shooting',
    '/kcsapi/api_req_combined_battle/ec_battle',
    '/kcsapi/api_req_combined_battle/each_battle',
    '/kcsapi/api_req_combined_battle/each_battle_water',
    '/kcsapi/api_req_battle_midnight/battle',
    '/kcsapi/api_req_battle_midnight/sp_midnight',
    '/kcsapi/api_req_combined_battle/midnight_battle',
    '/kcsapi/api_req_combined_battle/sp_midnight',
    '/kcsapi/api_req_combined_battle/ec_midnight_battle',
    '/kcsapi/api_req_combined_battle/ec_night_to_day',
  };

  static const Set<String> _resultPaths = <String>{
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_combined_battle/battleresult',
    '/kcsapi/api_req_practice/battle_result',
  };

  static const Set<String> _airRaidPaths = <String>{
    '/kcsapi/api_req_sortie/ld_airbattle',
    '/kcsapi/api_req_sortie/ld_shooting',
    '/kcsapi/api_req_combined_battle/ld_airbattle',
    '/kcsapi/api_req_combined_battle/ld_shooting',
  };

  final GameState Function() gameState;
  final BattleDamageParser _damageParser;
  final int maxRecords;
  final BattleNodeLabelResolver nodeLabelResolver;
  final List<BattleRecord> _records = <BattleRecord>[];
  final Set<int> _acceptedSequences = <int>{};
  final List<BattleSession> _recentSessions = <BattleSession>[];

  Future<void> _queue = Future<void>.value();
  BattleContext _context = const BattleContext();
  BattleSession? _session;
  LiveBattle? _current;
  String? _lastError;
  bool _disposed = false;

  LiveBattle? get current => _current;
  List<BattleRecord> get records => List.unmodifiable(_records);
  GameState get gameStateSnapshot => gameState();
  String? get lastError => _lastError;
  BattleSession? get session => _session;
  List<BattleSession> get recentSessions => List.unmodifiable(_recentSessions);
  Future<void> get idle => _queue;

  void refreshNodeLabel() {
    if (_disposed || _context.node <= 0) return;
    final label = nodeLabelResolver
        .resolve(
          mapAreaId: _context.mapAreaId,
          mapInfoNo: _context.mapInfoNo,
          internalNodeId: _context.node,
        )
        ?.trim();
    final normalized = label == null || label.isEmpty ? null : label;
    if (_context.nodeDisplayLabel == normalized) return;
    _context = _context.copyWith(nodeDisplayLabel: normalized);
    final current = _current;
    if (current != null) _current = current.copyWith(context: _context);
    notifyListeners();
  }

  void accept(CapturedApiEvent event) {
    if (_disposed || !_isSupported(event.path)) {
      return;
    }
    if (event.sequence > 0 && !_acceptedSequences.add(event.sequence)) {
      return;
    }
    if (_acceptedSequences.length > 512) {
      _acceptedSequences.remove(_acceptedSequences.first);
    }
    _queue = _queue.then((_) {
      if (_disposed) {
        return;
      }
      try {
        _reduce(event);
        _lastError = null;
        notifyListeners();
      } catch (error) {
        _session?.markUnconfirmed(stage: event.path, message: error.toString());
        _lastError = '战斗数据暂时无法解析（${error.runtimeType}）';
        notifyListeners();
      }
    });
  }

  bool _isSupported(String path) =>
      _mapPaths.contains(path) ||
      _battlePaths.contains(path) ||
      _resultPaths.contains(path) ||
      path == '/kcsapi/api_port/port' ||
      path == '/kcsapi/api_start2/getData';

  void _reduce(CapturedApiEvent event) {
    if (event.path == '/kcsapi/api_port/port' ||
        event.path == '/kcsapi/api_start2/getData') {
      _current = null;
      _archiveSession();
      _session = null;
      return;
    }
    final data = GameApiDecoder.decodeData(event.responseBody);
    final map = _map(data);
    if (_mapPaths.contains(event.path)) {
      _context = _contextFromMap(map, event);
      final state = gameState();
      _current = LiveBattle(
        context: _context,
        friendMain: _friendFleet(
          state,
          _context.deckId,
          BattleFleetRole.main,
          nowHp: const <Object?>[],
          maxHp: const <Object?>[],
        ),
        friendEscort: _friendFleet(
          state,
          2,
          BattleFleetRole.escort,
          nowHp: const <Object?>[],
          maxHp: const <Object?>[],
          enabled: state.combinedFleetType != CombinedFleetType.none,
        ),
        phaseLabel: '航行中',
        displayStage: BattleDisplayStage.navigation,
      );
      _archiveSession();
      _session = BattleSession(
        id: '${event.sequence}:${_context.mapAreaId}-${_context.mapInfoNo}-${_context.node}',
        context: _context,
        startedAt: event.capturedAt,
        friendMain: _current!.friendMain,
        friendEscort: _current!.friendEscort,
      );
      return;
    }
    if (_battlePaths.contains(event.path)) {
      _ensureSession(event);
      _session!.appendPacket(
        path: event.path,
        sequence: event.sequence,
        capturedAt: event.capturedAt,
        data: map,
      );
      _applyBattlePhase(map, event);
      final battle = _current!;
      _session!.updateFleets(
        friendMain: battle.friendMain,
        friendEscort: battle.friendEscort,
        enemyMain: battle.enemyMain,
        enemyEscort: battle.enemyEscort,
      );
      return;
    }
    if (_resultPaths.contains(event.path)) {
      if (_session != null) {
        _session!.appendPacket(
          path: event.path,
          sequence: event.sequence,
          capturedAt: event.capturedAt,
          data: map,
        );
      }
      _applyResult(map, event);
    }
  }

  BattleContext _contextFromMap(
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final mapAreaId = _positive(data['api_maparea_id'], _context.mapAreaId);
    final mapInfoNo = _positive(data['api_mapinfo_no'], _context.mapInfoNo);
    final node = _positive(data['api_no'], _context.node);
    return BattleContext(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      node: node,
      bossNode: _positive(data['api_bosscell_no'], _context.bossNode),
      deckId: _positive(event.requestParams['api_deck_id'], _context.deckId),
      combinedFleetType: gameState().combinedFleetType,
      eventId: _int(data['api_event_id']),
      eventKind: _int(data['api_event_kind']),
      nodeDisplayLabel: nodeLabelResolver.resolve(
        mapAreaId: mapAreaId,
        mapInfoNo: mapInfoNo,
        internalNodeId: node,
      ),
    );
  }

  void _applyBattlePhase(Map<String, Object?> data, CapturedApiEvent event) {
    final state = gameState();
    final practice = event.path == '/kcsapi/api_req_practice/battle';
    final deckId = _positive(data['api_deck_id'], _context.deckId);
    if (practice) {
      _context = _context.copyWith(deckId: deckId, practice: true);
    } else if (deckId != _context.deckId) {
      _context = _context.copyWith(deckId: deckId);
    }

    final previous = _current;
    final previousBattle = previous?.displayStage == BattleDisplayStage.battle
        ? previous
        : null;
    final friendMain = _friendFleet(
      state,
      deckId,
      BattleFleetRole.main,
      nowHp: _fleetArray(data['api_f_nowhps']),
      maxHp: _fleetArray(data['api_f_maxhps']),
      previous: previousBattle?.friendMain,
    );
    final combined =
        _context.combinedFleetType != CombinedFleetType.none ||
        state.combinedFleetType != CombinedFleetType.none;
    final friendEscort = _friendFleet(
      state,
      2,
      BattleFleetRole.escort,
      nowHp: _fleetArray(data['api_f_nowhps_combined']),
      maxHp: _fleetArray(data['api_f_maxhps_combined']),
      previous: previousBattle?.friendEscort,
      enabled: combined || (previous?.friendEscort.isNotEmpty ?? false),
    );
    final enemyMain = _enemyFleet(
      state,
      BattleFleetRole.main,
      ids: _fleetArray(data['api_ship_ke']),
      nowHp: _fleetArray(data['api_e_nowhps']),
      maxHp: _fleetArray(data['api_e_maxhps']),
      previous: previousBattle?.enemyMain,
    );
    final enemyEscort = _enemyFleet(
      state,
      BattleFleetRole.escort,
      ids: _fleetArray(data['api_ship_ke_combined']),
      nowHp: _fleetArray(data['api_e_nowhps_combined']),
      maxHp: _fleetArray(data['api_e_maxhps_combined']),
      previous: previousBattle?.enemyEscort,
    );

    final parsed = _damageParser.apply(
      data: data,
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
      path: event.path,
    );
    for (final issue in parsed.issues) {
      _session?.markUnconfirmed(stage: issue.stage, message: issue.message);
    }
    final friendShips = <BattleShipSnapshot>[
      ...parsed.friendMain,
      ...parsed.friendEscort,
    ];
    final enemyShips = <BattleShipSnapshot>[
      ...parsed.enemyMain,
      ...parsed.enemyEscort,
    ];
    final formation = _list(data['api_formation']);
    final parsedEnemyName = parseEnemyFleetName(data['api_formation']);
    final enemyFleetName = parsedEnemyName.isNotEmpty
        ? parsedEnemyName
        : previous?.enemyFleetName ?? '';
    final seiku = parseDispSeiku(data);

    _current = LiveBattle(
      context: _context,
      friendMain: parsed.friendMain,
      friendEscort: parsed.friendEscort,
      enemyMain: parsed.enemyMain,
      enemyEscort: parsed.enemyEscort,
      rank: estimateBattleRank(
        friendShips: friendShips,
        enemyShips: enemyShips,
        airRaid: _airRaidPaths.contains(event.path),
      ),
      displayStage: BattleDisplayStage.battle,
      phaseLabel: _phaseLabel(event.path),
      friendFormation: _atInt(formation, 0),
      enemyFormation: _atInt(formation, 1),
      engagement: _atInt(formation, 2),
      enemyFleetName: enemyFleetName,
      airSuperiority: kAirSuperiorityLabels[seiku] ?? '未知',
      mvpPositions: _predictedMvpPositions(
        parsed.friendMain,
        parsed.friendEscort,
      ),
    );
  }

  void _applyResult(Map<String, Object?> data, CapturedApiEvent event) {
    if (_current == null ||
        _current!.displayStage == BattleDisplayStage.navigation) {
      _lastError = '收到结算数据时没有可匹配的战斗会话';
      return;
    }
    final enemyInfo = _optionalMap(data['api_enemy_info']);
    final getShip = _optionalMap(data['api_get_ship']);
    final getItem = _optionalMap(data['api_get_useitem']);
    var rank = BattleRank.parse(data['api_win_rank']);
    if (rank == BattleRank.s) {
      final friendShips = _current!.friendShips;
      final initialHp = friendShips.fold<int>(
        0,
        (sum, ship) => sum + ship.initialHp,
      );
      final currentHp = friendShips.fold<int>(
        0,
        (sum, ship) => sum + ship.currentHp,
      );
      if (currentHp >= initialHp) {
        rank = BattleRank.ss;
      }
    }
    final mainMvp = _int(data['api_mvp']) - 1;
    final escortMvp = _int(data['api_mvp_combined']) - 1;
    final confirmed = (_current ?? LiveBattle(context: _context)).copyWith(
      rank: rank,
      status: LiveBattleStatus.confirmed,
      displayStage: BattleDisplayStage.result,
      enemyFleetName: _string(enemyInfo?['api_deck_name']),
      mvpPositions: <int>[
        if (mainMvp >= 0) mainMvp,
        if (escortMvp >= 0) escortMvp + 6,
      ],
      dropShipMasterId: _positive(getShip?['api_ship_id'], 0),
      dropItemId: _positive(getItem?['api_useitem_id'], 0),
      dropItemName: _string(getItem?['api_useitem_name']),
    );
    _current = confirmed;
    final record = BattleRecord(
      battle: confirmed,
      completedAt: event.capturedAt,
    );
    _records.insert(0, record);
    if (_records.length > maxRecords) {
      _records.removeRange(maxRecords, _records.length);
    }
    if (_session != null) {
      _session!.completed = true;
      _archiveSession();
    }

    // Log to persistent database
    LogbookDatabase.instance.insertBattleRecord(record).catchError((error) {
      debugPrint('战斗记录写入失败: $error');
    });
  }

  void _ensureSession(CapturedApiEvent event) {
    _session ??= BattleSession(
      id: '${event.sequence}:${_context.mapAreaId}-${_context.mapInfoNo}-${_context.node}',
      context: _context,
      startedAt: event.capturedAt,
    );
  }

  void _archiveSession() {
    final session = _session;
    if (session == null ||
        session.packets.isEmpty ||
        _recentSessions.contains(session)) {
      return;
    }
    _recentSessions.insert(0, session);
    if (_recentSessions.length > 10) {
      _recentSessions.removeRange(10, _recentSessions.length);
    }
  }

  List<BattleShipSnapshot> _friendFleet(
    GameState state,
    int deckId,
    BattleFleetRole role, {
    required List<Object?> nowHp,
    required List<Object?> maxHp,
    List<BattleShipSnapshot>? previous,
    bool enabled = true,
  }) {
    if (!enabled) {
      return const <BattleShipSnapshot>[];
    }
    if (previous != null) {
      return previous;
    }
    final ownedShips = state.shipsForFleet(deckId);
    if (ownedShips.isEmpty && previous != null) {
      return _withHp(previous, nowHp, maxHp);
    }
    return <BattleShipSnapshot>[
      for (var index = 0; index < ownedShips.length; index++)
        BattleShipSnapshot(
          masterId: ownedShips[index].masterId,
          ownedShipId: ownedShips[index].id,
          name:
              state.masterForShip(ownedShips[index])?.name ??
              '舰娘 ${ownedShips[index].masterId}',
          side: BattleSide.friend,
          fleetRole: role,
          position: index,
          initialHp: _atNonNegative(nowHp, index, ownedShips[index].currentHp),
          maxHp: _atPositive(maxHp, index, ownedShips[index].maxHp),
          currentHp: _atNonNegative(nowHp, index, ownedShips[index].currentHp),
          damageDealt: index < (previous?.length ?? 0)
              ? previous![index].damageDealt
              : 0,
          damageReceived: index < (previous?.length ?? 0)
              ? previous![index].damageReceived
              : 0,
          condition: ownedShips[index].condition,
          equipmentMasterIds: <int>[
            for (final equipment in state.equipmentForShip(ownedShips[index]))
              equipment.owned.masterId,
          ],
        ),
    ];
  }

  List<BattleShipSnapshot> _enemyFleet(
    GameState state,
    BattleFleetRole role, {
    required List<Object?> ids,
    required List<Object?> nowHp,
    required List<Object?> maxHp,
    List<BattleShipSnapshot>? previous,
  }) {
    if (previous != null) {
      return previous;
    }
    final result = <BattleShipSnapshot>[];
    for (var index = 0; index < ids.length; index++) {
      final masterId = _int(ids[index]);
      if (masterId <= 0) {
        continue;
      }
      final hp = _atNonNegative(nowHp, index, _atPositive(maxHp, index, 1));
      result.add(
        BattleShipSnapshot(
          masterId: masterId,
          name: state.masterShips[masterId]?.name ?? '敌舰 $masterId',
          side: BattleSide.enemy,
          fleetRole: role,
          position: index,
          initialHp: hp,
          maxHp: _atPositive(maxHp, index, hp),
          currentHp: hp,
          damageReceived: index < (previous?.length ?? 0)
              ? previous![index].damageReceived
              : 0,
        ),
      );
    }
    return result;
  }

  List<BattleShipSnapshot> _withHp(
    List<BattleShipSnapshot> previous,
    List<Object?> nowHp,
    List<Object?> maxHp,
  ) {
    return <BattleShipSnapshot>[
      for (var index = 0; index < previous.length; index++)
        previous[index].copyWith(
          currentHp: _atPositive(nowHp, index, previous[index].currentHp),
          maxHp: _atPositive(maxHp, index, previous[index].maxHp),
        ),
    ];
  }

  String _phaseLabel(String path) {
    if (path.contains('midnight') || path.contains('night_to_day')) {
      return '夜战';
    }
    if (path.contains('airbattle') || path.contains('ld_')) {
      return '航空战';
    }
    return '昼战';
  }

  List<int> _predictedMvpPositions(
    List<BattleShipSnapshot> main,
    List<BattleShipSnapshot> escort,
  ) {
    final positions = <int>[];
    int? bestPosition;
    var bestDamage = 0;
    for (var index = 0; index < main.length; index++) {
      if (main[index].damageDealt > bestDamage) {
        bestDamage = main[index].damageDealt;
        bestPosition = index;
      }
    }
    if (bestPosition != null) {
      positions.add(bestPosition);
    }
    bestPosition = null;
    bestDamage = 0;
    for (var index = 0; index < escort.length; index++) {
      if (escort[index].damageDealt > bestDamage) {
        bestDamage = escort[index].damageDealt;
        bestPosition = index + 6;
      }
    }
    if (bestPosition != null) {
      positions.add(bestPosition);
    }
    return positions;
  }

  Map<String, Object?> _map(Object? value) {
    if (value is! Map) {
      throw const GameApiParseException('战斗接口数据不是对象');
    }
    return value.map((key, child) => MapEntry(key.toString(), child));
  }

  Map<String, Object?>? _optionalMap(Object? value) => value is Map
      ? value.map((key, child) => MapEntry(key.toString(), child))
      : null;

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  List<Object?> _fleetArray(Object? value) {
    final values = _list(value);
    if (values.isNotEmpty && _int(values.first) < 0) {
      return values.sublist(1);
    }
    return values;
  }

  int _atInt(List<Object?> values, int index) =>
      index >= 0 && index < values.length ? _int(values[index]) : 0;

  int _atPositive(List<Object?> values, int index, int fallback) =>
      index >= 0 && index < values.length
      ? _positive(values[index], fallback)
      : fallback;

  int _atNonNegative(List<Object?> values, int index, int fallback) =>
      index >= 0 && index < values.length
      ? _nonNegative(values[index], fallback)
      : fallback;

  int _positive(Object? value, int fallback) {
    final number = _int(value);
    return number > 0 ? number : fallback;
  }

  int _nonNegative(Object? value, int fallback) {
    final number = _int(value);
    return number >= 0 ? number : fallback;
  }

  int _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };

  String _string(Object? value) => value?.toString() ?? '';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
