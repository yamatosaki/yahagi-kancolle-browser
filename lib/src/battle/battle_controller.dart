import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/combat_state.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_state.dart';
import 'battle_damage_parser.dart';
import 'battle_models.dart';
import 'battle_rank.dart';
import '../logbook/logbook_database.dart';

final class BattleController extends ChangeNotifier {
  BattleController({
    required this.gameState,
    BattleDamageParser? damageParser,
    this.maxRecords = 100,
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

  final GameState Function() gameState;
  final BattleDamageParser _damageParser;
  final int maxRecords;
  final List<BattleRecord> _records = <BattleRecord>[];
  final Set<int> _acceptedSequences = <int>{};

  Future<void> _queue = Future<void>.value();
  BattleContext _context = const BattleContext();
  LiveBattle? _current;
  String? _lastError;
  bool _disposed = false;

  LiveBattle? get current => _current;
  List<BattleRecord> get records => List.unmodifiable(_records);
  GameState get gameStateSnapshot => gameState();
  String? get lastError => _lastError;
  Future<void> get idle => _queue;

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
      return;
    }
    if (_battlePaths.contains(event.path)) {
      _applyBattlePhase(map, event);
      return;
    }
    if (_resultPaths.contains(event.path)) {
      _applyResult(map, event);
    }
  }

  BattleContext _contextFromMap(
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    return BattleContext(
      mapAreaId: _positive(data['api_maparea_id'], _context.mapAreaId),
      mapInfoNo: _positive(data['api_mapinfo_no'], _context.mapInfoNo),
      node: _positive(data['api_no'], _context.node),
      bossNode: _positive(data['api_bosscell_no'], _context.bossNode),
      deckId: _positive(event.requestParams['api_deck_id'], _context.deckId),
      combinedFleetType: gameState().combinedFleetType,
      eventId: _int(data['api_event_id']),
      eventKind: _int(data['api_event_kind']),
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
    final friendMain = _friendFleet(
      state,
      deckId,
      BattleFleetRole.main,
      nowHp: _fleetArray(data['api_f_nowhps']),
      maxHp: _fleetArray(data['api_f_maxhps']),
      previous: previous?.friendMain,
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
      previous: previous?.friendEscort,
      enabled: combined || (previous?.friendEscort.isNotEmpty ?? false),
    );
    final enemyMain = _enemyFleet(
      state,
      BattleFleetRole.main,
      ids: _fleetArray(data['api_ship_ke']),
      nowHp: _fleetArray(data['api_e_nowhps']),
      maxHp: _fleetArray(data['api_e_maxhps']),
      previous: previous?.enemyMain,
    );
    final enemyEscort = _enemyFleet(
      state,
      BattleFleetRole.escort,
      ids: _fleetArray(data['api_ship_ke_combined']),
      nowHp: _fleetArray(data['api_e_nowhps_combined']),
      maxHp: _fleetArray(data['api_e_maxhps_combined']),
      previous: previous?.enemyEscort,
    );

    final parsed = _damageParser.apply(
      data: data,
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
      path: event.path,
    );
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
    final enemyInfo = _optionalMap(data['api_enemy_info']);
    final getShip = _optionalMap(data['api_get_ship']);
    final getItem = _optionalMap(data['api_get_useitem']);
    final rank = BattleRank.parse(data['api_win_rank']);
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

    // Log to persistent database
    LogbookDatabase.instance.insertBattleRecord(record).catchError((error) {
      debugPrint('战斗记录写入失败: $error');
    });
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
    if (nowHp.isEmpty && previous != null) {
      return _withHp(previous, nowHp, maxHp);
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
          initialHp: _atPositive(nowHp, index, ownedShips[index].currentHp),
          maxHp: _atPositive(maxHp, index, ownedShips[index].maxHp),
          currentHp: _atPositive(nowHp, index, ownedShips[index].currentHp),
          damageDealt: index < (previous?.length ?? 0)
              ? previous![index].damageDealt
              : 0,
          condition: ownedShips[index].condition,
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
    if (ids.isEmpty && previous != null) {
      return _withHp(previous, nowHp, maxHp);
    }
    final result = <BattleShipSnapshot>[];
    for (var index = 0; index < ids.length; index++) {
      final masterId = _int(ids[index]);
      if (masterId <= 0) {
        continue;
      }
      final hp = _atPositive(nowHp, index, _atPositive(maxHp, index, 1));
      result.add(
        BattleShipSnapshot(
          masterId: masterId,
          name: state.masterShips[masterId]?.name ?? '敌舰 $masterId',
          side: BattleSide.enemy,
          fleetRole: role,
          position: result.length,
          initialHp: hp,
          maxHp: _atPositive(maxHp, index, hp),
          currentHp: hp,
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

  int _positive(Object? value, int fallback) {
    final number = _int(value);
    return number > 0 ? number : fallback;
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
