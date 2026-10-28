import '../../battle_models.dart';
import '../battle_prediction_engine.dart';
import 'poi_battle_replay_state.dart';
import 'poi_battle_rules.dart';

/// POI-compatible engine that rebuilds the simulator from the opening state
/// whenever a new battle packet arrives.
final class PoiBattlePredictionEngine implements BattlePredictionEngine {
  PoiBattlePredictionEngine({
    required List<BattleShipSnapshot> friendMain,
    List<BattleShipSnapshot> friendEscort = const <BattleShipSnapshot>[],
    required List<BattleShipSnapshot> enemyMain,
    List<BattleShipSnapshot> enemyEscort = const <BattleShipSnapshot>[],
    this.fleetType = 0,
  }) : _friendMain = clonePoiBattleFleet(
         friendMain,
         resetBattleDamageControl: true,
       ),
       _friendEscort = clonePoiBattleFleet(
         friendEscort,
         resetBattleDamageControl: true,
       ),
       _enemyMain = clonePoiBattleFleet(enemyMain),
       _enemyEscort = clonePoiBattleFleet(enemyEscort);

  final List<BattleShipSnapshot> _friendMain;
  final List<BattleShipSnapshot> _friendEscort;
  final List<BattleShipSnapshot> _enemyMain;
  final List<BattleShipSnapshot> _enemyEscort;
  final int fleetType;
  final List<PoiBattleReplayPacket> _packets = <PoiBattleReplayPacket>[];

  @override
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  }) {
    _packets.add(PoiBattleReplayPacket(path: path, data: data));
    final simulator = _PoiBattleSimulator(
      clonePoiBattleFleet(_friendMain),
      clonePoiBattleFleet(_friendEscort),
      clonePoiBattleFleet(_enemyMain),
      clonePoiBattleFleet(_enemyEscort),
      fleetType: fleetType,
    );
    BattlePrediction? prediction;
    for (final packet in _packets) {
      prediction = simulator.simulate(path: packet.path, data: packet.data);
    }
    return prediction!;
  }
}

/// Mutable simulator used for one complete replay only.
final class _PoiBattleSimulator {
  static const Set<String> _dayPaths = <String>{
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
  };
  static const Set<String> _nightPaths = <String>{
    '/kcsapi/api_req_practice/midnight_battle',
    '/kcsapi/api_req_battle_midnight/battle',
    '/kcsapi/api_req_battle_midnight/sp_midnight',
    '/kcsapi/api_req_combined_battle/midnight_battle',
    '/kcsapi/api_req_combined_battle/sp_midnight',
    '/kcsapi/api_req_combined_battle/ec_midnight_battle',
    '!COMPAT/midnight_battle',
  };
  static const Set<String> _nightToDayPaths = <String>{
    '/kcsapi/api_req_combined_battle/ec_night_to_day',
  };
  static const Set<String> _airRaidPaths = <String>{
    '/kcsapi/api_req_sortie/ld_airbattle',
    '/kcsapi/api_req_sortie/ld_shooting',
    '/kcsapi/api_req_combined_battle/ld_airbattle',
    '/kcsapi/api_req_combined_battle/ld_shooting',
  };

  _PoiBattleSimulator(
    this._friendMain,
    this._friendEscort,
    this._enemyMain,
    this._enemyEscort, {
    required this.fleetType,
  });

  final List<BattleShipSnapshot> _friendMain;
  final List<BattleShipSnapshot> _friendEscort;
  final List<BattleShipSnapshot> _enemyMain;
  final List<BattleShipSnapshot> _enemyEscort;
  List<BattleShipSnapshot> _npcFriend = <BattleShipSnapshot>[];
  final int fleetType;
  final List<BattleParseIssue> _issues = <BattleParseIssue>[];
  String _stage = 'unknown';
  bool _airRaid = false;
  bool _nightOnlyMvp = false;
  final List<int> _nightEscortDamage = List<int>.filled(6, 0);

  BattlePrediction simulate({
    required String path,
    required Map<String, Object?> data,
  }) {
    _prepareNpcFriend(data['api_friendly_info']);
    _airRaid = _airRaid || _airRaidPaths.contains(path);
    _nightOnlyMvp =
        _nightOnlyMvp ||
        (path == '/kcsapi/api_req_combined_battle/midnight_battle' &&
            fleetType >= 1 &&
            fleetType <= 3);
    if (_nightToDayPaths.contains(path)) {
      _night(data);
      _day(data, path: path);
    } else if (_dayPaths.contains(path)) {
      _day(data, path: path);
    } else if (_nightPaths.contains(path)) {
      _night(data);
    } else {
      _issues.add(
        BattleParseIssue(
          stage: 'path',
          message: 'unsupported POI battle path: $path',
        ),
      );
    }
    return BattlePrediction(
      friendMain: List.unmodifiable(_friendMain),
      friendEscort: List.unmodifiable(_friendEscort),
      enemyMain: List.unmodifiable(_enemyMain),
      enemyEscort: List.unmodifiable(_enemyEscort),
      rank: _issues.isEmpty ? _rank() : BattleRank.unknown,
      mvpPositions: List<int>.unmodifiable(_mvpPositions()),
      issues: List.unmodifiable(_issues),
    );
  }

  void _day(Map<String, Object?> data, {required String path}) {
    for (final key in <String>[
      'api_air_base_injection',
      'api_injection_kouku',
    ]) {
      _aerial(data[key], key);
    }
    final bases = _list(data['api_air_base_attack']);
    for (var i = 0; i < bases.length; i++) {
      _aerial(bases[i], 'api_air_base_attack[$i]');
    }
    _friendlyAerial(data['api_friendly_kouku']);
    for (final key in <String>['api_kouku', 'api_kouku2']) {
      _aerial(data[key], key);
    }
    if (data['api_stage3'] is Map || data['api_stage3_combined'] is Map) {
      _aerial(data, 'packet-stage3');
    }
    _support(
      data['api_support_info'],
      _int(data['api_support_flag']),
      'api_support_info',
    );
    _shell(
      data['api_opening_taisen'],
      'api_opening_taisen',
      friendEscort: false,
      enemyEscort: false,
    );
    _torpedo(
      data['api_opening_atack'],
      'api_opening_atack',
      friendEscort: false,
      enemyEscort: false,
    );

    void shell(String key) {
      _shell(data[key], key, friendEscort: false, enemyEscort: false);
    }

    void torpedo() => _torpedo(
      data['api_raigeki'],
      'api_raigeki',
      friendEscort: false,
      enemyEscort: false,
    );

    for (final key in poiDayShellingOrder(path, fleetType)) {
      if (key == 'api_raigeki') {
        torpedo();
      } else {
        shell(key);
      }
    }
  }

  void _prepareNpcFriend(Object? value) {
    final info = _map(value);
    if (info == null) return;
    final ids = _list(info['api_ship_id']);
    final now = _list(info['api_nowhps']);
    final max = _list(info['api_maxhps']);
    _npcFriend = <BattleShipSnapshot>[
      for (var position = 0; position < ids.length; position++)
        if (_atInt(ids, position) > 0)
          BattleShipSnapshot(
            masterId: _atInt(ids, position),
            name: 'NPC friendly ${_atInt(ids, position)}',
            side: BattleSide.friend,
            fleetRole: BattleFleetRole.main,
            position: position,
            initialHp: _atInt(now, position),
            maxHp: _atInt(max, position),
            currentHp: _atInt(now, position),
          ),
    ];
  }

  void _friendlyAerial(Object? value) {
    final map = _map(value);
    if (map == null) return;
    _stage = 'api_friendly_kouku';
    final stage3 = _map(map['api_stage3']);
    if (stage3 != null) {
      _aerialDamage(_enemyMain, stage3, enemyTarget: true);
      _aerialDamage(_npcFriend, stage3, enemyTarget: false);
    }
    final combined = _map(map['api_stage3_combined']);
    if (combined != null) {
      _aerialDamage(_enemyEscort, combined, enemyTarget: true);
    }
  }

  void _night(Map<String, Object?> data) {
    _support(
      data['api_n_support_info'],
      _int(data['api_n_support_flag']),
      'api_n_support_info',
    );
    for (final key in <String>['api_n_hougeki1', 'api_n_hougeki2']) {
      _shell(
        data[key],
        key,
        friendEscort: false,
        enemyEscort: false,
        isNight: true,
      );
    }
    final friendly = _map(data['api_friendly_battle']);
    _friendlyShell(friendly?['api_hougeki'], 'api_friendly_battle.api_hougeki');
    _shell(
      data['api_hougeki'],
      'api_hougeki',
      friendEscort: false,
      enemyEscort: false,
      isNight: true,
    );
  }

  void _friendlyShell(Object? value, String stage) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    final flags = _list(map['api_at_eflag']);
    final defenders = _list(map['api_df_list']);
    final damages = _list(map['api_damage']);
    final attackTypes = _list(map['api_sp_list']);
    for (var row = 0; row < defenders.length && row < damages.length; row++) {
      if (row < flags.length && _int(flags[row]) != 0) {
        _issues.add(
          BattleParseIssue(
            stage: stage,
            message: 'NPC friendly attack row $row has enemy attacker flag',
          ),
        );
        continue;
      }
      final targets = _list(defenders[row]);
      final hits = _list(damages[row]);
      final attackOrder = row < attackTypes.length
          ? poiMultiTargetAttackOrder(_int(attackTypes[row]), isNight: true)
          : null;
      if (attackOrder == null) {
        if (targets.isEmpty) continue;
        final amount = hits.fold<int>(0, (sum, hit) => sum + _damage(hit));
        _damageNpcFriendlyTarget(_int(targets.first), amount);
        continue;
      }
      for (var hit = 0; hit < targets.length && hit < hits.length; hit++) {
        _damageNpcFriendlyTarget(_int(targets[hit]), _damage(hits[hit]));
      }
    }
  }

  void _damageNpcFriendlyTarget(int absolutePosition, int amount) {
    if (amount <= 0) return;
    final mainRange = _fleetRange(_enemyMain);
    if (absolutePosition < mainRange) {
      _receive(_enemyMain, absolutePosition, amount);
      return;
    }
    _receive(_enemyEscort, absolutePosition - mainRange, amount);
  }

  void _aerial(Object? value, String stage) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    final main = _map(map['api_stage3']);
    if (main != null) {
      _aerialDamage(_enemyMain, main, enemyTarget: true);
      _aerialDamage(_friendMain, main, enemyTarget: false);
    }
    final combined = _map(map['api_stage3_combined']);
    if (combined != null) {
      _aerialDamage(_enemyEscort, combined, enemyTarget: true);
      _aerialDamage(_friendEscort, combined, enemyTarget: false);
    }
  }

  void _aerialDamage(
    List<BattleShipSnapshot> fleet,
    Map<String, Object?> stage3, {
    required bool enemyTarget,
  }) {
    final damage = _list(stage3[enemyTarget ? 'api_edam' : 'api_fdam']);
    final values = damage.isNotEmpty && _int(damage.first) < 0
        ? damage.sublist(1)
        : damage;
    final bombing = _list(
      stage3[enemyTarget ? 'api_ebak_flag' : 'api_fbak_flag'],
    );
    final torpedo = _list(
      stage3[enemyTarget ? 'api_erai_flag' : 'api_frai_flag'],
    );
    for (var position = 0; position < values.length; position++) {
      if (_atInt(bombing, position) <= 0 && _atInt(torpedo, position) <= 0) {
        continue;
      }
      final amount = _damage(values[position]);
      if (amount > 0) _receive(fleet, position, amount);
    }
  }

  void _torpedo(
    Object? value,
    String stage, {
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    _attributeTorpedoDamage(map);
    _arrayDamage(
      map,
      escort: false,
      friendEscort: friendEscort,
      enemyEscort: enemyEscort,
    );
  }

  void _attributeTorpedoDamage(Map<String, Object?> map) {
    final rows = _list(map['api_fydam_list_items']);
    if (rows.isNotEmpty) {
      for (var position = 0; position < rows.length; position++) {
        final amount = _list(
          rows[position],
        ).fold<int>(0, (sum, value) => sum + _damage(value));
        _addAbsoluteFriendDamage(position, amount);
      }
      return;
    }
    if (map['api_frai'] == null) return;
    final values = _list(map['api_fydam']).isNotEmpty
        ? _list(map['api_fydam'])
        : _list(map['api_fdam']);
    for (var position = 0; position < values.length; position++) {
      _addAbsoluteFriendDamage(position, _damage(values[position]));
    }
  }

  void _addAbsoluteFriendDamage(int position, int amount) {
    if (amount <= 0) return;
    final mainRange = _fleetRange(_friendMain);
    if (_friendEscort.isNotEmpty && position >= mainRange) {
      _addDealt(_friendEscort, position - mainRange, amount);
    } else {
      _addDealt(_friendMain, position, amount);
    }
  }

  void _arrayDamage(
    Map<String, Object?>? map, {
    required bool escort,
    required bool friendEscort,
    required bool enemyEscort,
  }) {
    if (map == null) return;
    _damageArray(
      escort || friendEscort ? _friendEscort : _friendMain,
      _list(map['api_fdam']),
      main: _friendMain,
      escortFleet: _friendEscort,
    );
    _damageArray(
      escort || enemyEscort ? _enemyEscort : _enemyMain,
      _list(map['api_edam']),
      main: _enemyMain,
      escortFleet: _enemyEscort,
    );
  }

  void _shell(
    Object? value,
    String stage, {
    required bool friendEscort,
    required bool enemyEscort,
    bool attributeFriendDamage = true,
    bool isNight = false,
  }) {
    final map = _map(value);
    if (map == null) return;
    _stage = stage;
    final flags = _list(map['api_at_eflag']);
    final attackers = _list(map['api_at_list']);
    final defenders = _list(map['api_df_list']);
    final damages = _list(map['api_damage']);
    final attackTypes = _list(map[isNight ? 'api_sp_list' : 'api_at_type']);
    final mainFleetRange = _fleetRange(_friendMain);
    for (var row = 0; row < defenders.length && row < damages.length; row++) {
      final targets = _list(defenders[row]);
      final hits = _list(damages[row]);
      final enemyAttack = row < flags.length
          ? _int(flags[row]) != 0
          : (targets.isNotEmpty && _int(targets.first) < mainFleetRange);
      final attackOrder = row < attackTypes.length
          ? poiMultiTargetAttackOrder(_int(attackTypes[row]), isNight: isNight)
          : null;
      var dealt = 0;
      if (attackOrder == null) {
        final amount = hits.fold<int>(0, (sum, hit) => sum + _damage(hit));
        if (amount > 0 && targets.isNotEmpty) {
          if (attributeFriendDamage && !enemyAttack) dealt = amount;
          var position = _int(targets.first);
          var escort = enemyAttack ? friendEscort : enemyEscort;
          if (row >= flags.length) {
            if (!enemyAttack && position >= mainFleetRange) {
              position -= mainFleetRange;
            }
            escort = false;
          }
          _damagePosition(enemyAttack, escort, position, amount);
        }
      } else {
        for (var hit = 0; hit < targets.length && hit < hits.length; hit++) {
          final amount = _damage(hits[hit]);
          if (amount == 0) continue;
          if (attributeFriendDamage && !enemyAttack) {
            var attacker = row < attackers.length ? _int(attackers[row]) : -1;
            if (attacker >= 0) {
              attacker += hit < attackOrder.length ? attackOrder[hit] : 0;
              // poi-lib-battle mirrors this server-side combined-night index fix.
              if (isNight &&
                  _friendEscort.isNotEmpty &&
                  attacker < mainFleetRange) {
                attacker += mainFleetRange;
              }
              _addAbsoluteFriendDamage(attacker, amount);
              if (isNight) _addNightDamage(attacker, amount);
            }
          }
          var position = _int(targets[hit]);
          var escort = enemyAttack ? friendEscort : enemyEscort;
          if (row >= flags.length) {
            if (!enemyAttack && position >= mainFleetRange) {
              position -= mainFleetRange;
            }
            escort = false;
          }
          _damagePosition(enemyAttack, escort, position, amount);
        }
      }
      if (attributeFriendDamage &&
          !enemyAttack &&
          attackOrder == null &&
          row < attackers.length &&
          dealt > 0) {
        var position = _int(attackers[row]);
        final escort = friendEscort || position >= mainFleetRange;
        if (position >= mainFleetRange) position -= mainFleetRange;
        _addDealt(escort ? _friendEscort : _friendMain, position, dealt);
        if (isNight && escort && position < _nightEscortDamage.length) {
          _nightEscortDamage[position] += dealt;
        }
      }
    }
  }

  void _addNightDamage(int absolutePosition, int amount) {
    if (amount <= 0 || _friendEscort.isEmpty) return;
    final index = absolutePosition - _fleetRange(_friendMain);
    if (index >= 0 && index < _nightEscortDamage.length) {
      _nightEscortDamage[index] += amount;
    }
  }

  List<int> _mvpPositions() {
    int bestDamagePosition(List<BattleShipSnapshot> fleet) {
      var best = -1;
      var damage = -1;
      for (final ship in fleet) {
        if (ship.damageDealt > damage) {
          best = ship.position;
          damage = ship.damageDealt;
        }
      }
      return best;
    }

    if (_nightOnlyMvp) {
      var best = 0;
      for (var index = 1; index < _nightEscortDamage.length; index++) {
        if (_nightEscortDamage[index] > _nightEscortDamage[best]) best = index;
      }
      return <int>[0, best + 6];
    }
    final main = bestDamagePosition(_friendMain);
    final escort = bestDamagePosition(_friendEscort);
    return <int>[if (main >= 0) main, if (escort >= 0) escort + 6];
  }

  void _support(Object? value, int flag, String stage) {
    final map = _map(value);
    if (map == null || flag <= 0) return;
    _stage = stage;
    if (flag == 1 || flag == 4) {
      final attack = _map(map['api_support_airatack']);
      final stage3 = _map(attack?['api_stage3']);
      if (stage3 == null) return;
      final raw = _list(stage3['api_edam']);
      final values = raw.isNotEmpty && _int(raw.first) < 0
          ? raw.sublist(1)
          : raw;
      final bombing = _list(stage3['api_ebak_flag']);
      final torpedo = _list(stage3['api_erai_flag']);
      for (var position = 0; position < values.length; position++) {
        if (_atInt(bombing, position) <= 0 && _atInt(torpedo, position) <= 0) {
          continue;
        }
        _damagePosition(false, false, position, _damage(values[position]));
      }
      return;
    }
    if (flag == 2 || flag == 3) {
      final hourai = _map(map['api_support_hourai']);
      if (hourai == null) return;
      final raw = _list(hourai['api_damage']);
      final values = raw.isNotEmpty && _int(raw.first) < 0
          ? raw.sublist(1)
          : raw;
      final hits = _list(hourai['api_cl_list']);
      for (var position = 0; position < values.length; position++) {
        if (_atInt(hits, position) <= 0) continue;
        _damagePosition(false, false, position, _damage(values[position]));
      }
    }
  }

  void _damageArray(
    List<BattleShipSnapshot> fleet,
    List<Object?> raw, {
    required List<BattleShipSnapshot> main,
    required List<BattleShipSnapshot> escortFleet,
  }) {
    final values = raw.isNotEmpty && _int(raw.first) < 0 ? raw.sublist(1) : raw;
    if (escortFleet.isNotEmpty && values.length > 6) {
      _damageArray(
        main,
        values.take(6).toList(),
        main: main,
        escortFleet: const [],
      );
      _damageArray(
        escortFleet,
        values.skip(6).take(6).toList(),
        main: escortFleet,
        escortFleet: const [],
      );
      return;
    }
    for (var i = 0; i < values.length; i++) {
      final amount = _damage(values[i]);
      if (amount > 0) _receive(fleet, i, amount);
    }
  }

  void _damagePosition(
    bool friendTarget,
    bool escort,
    int position,
    int amount,
  ) {
    final hasEscort = friendTarget
        ? _friendEscort.isNotEmpty
        : _enemyEscort.isNotEmpty;
    final mainRange = friendTarget
        ? _fleetRange(_friendMain)
        : _fleetRange(_enemyMain);
    if (hasEscort && position >= mainRange) {
      escort = true;
      position -= mainRange;
    }
    final fleets = friendTarget
        ? (escort ? _friendEscort : _friendMain)
        : (escort ? _enemyEscort : _enemyMain);
    _receive(fleets, position, amount);
  }

  void _receive(List<BattleShipSnapshot> fleet, int position, int amount) {
    final index = fleet.indexWhere((ship) => ship.position == position);
    if (index < 0) {
      _issues.add(
        BattleParseIssue(
          stage: _stage,
          message: 'target $position is outside the captured fleets',
        ),
      );
      return;
    }
    final ship = fleet[index];
    var hp = (ship.currentHp - amount).clamp(0, ship.maxHp);
    final used = List<int>.from(ship.usedDamageControlItemIds);
    final usedThisBattle = List<int>.from(ship.damageControlUsedThisBattle);
    if (ship.side == BattleSide.friend && hp == 0) {
      final item = _nextDamageControl(ship, used);
      if (item == 42) hp = (ship.maxHp ~/ 5).clamp(1, ship.maxHp);
      if (item == 43) hp = ship.maxHp;
      if (item != null) {
        used.add(item);
        usedThisBattle.add(item);
      }
    }
    fleet[index] = ship.copyWith(
      currentHp: hp,
      damageReceived: ship.damageReceived + amount,
      usedDamageControlItemIds: used,
      damageControlUsedThisBattle: usedThisBattle,
    );
  }

  int? _nextDamageControl(BattleShipSnapshot ship, List<int> used) {
    final remaining = List<int>.from(ship.equipmentMasterIds);
    for (final id in used) {
      remaining.remove(id);
    }
    return remaining.where((id) => id == 42 || id == 43).firstOrNull;
  }

  void _addDealt(List<BattleShipSnapshot> fleet, int position, int amount) {
    final index = fleet.indexWhere((ship) => ship.position == position);
    if (index >= 0) {
      fleet[index] = fleet[index].copyWith(
        damageDealt: fleet[index].damageDealt + amount,
      );
    }
  }

  BattleRank _rank() {
    final ours = _status(<BattleShipSnapshot>[
      ..._friendMain,
      ..._friendEscort,
    ]);
    final enemy = _status(<BattleShipSnapshot>[..._enemyMain, ..._enemyEscort]);
    if (_airRaid) {
      final rate = ours.total == 0 ? 0 : ours.lost * 100 / ours.total;
      if (rate <= 0) return BattleRank.ss;
      if (rate < 10) return BattleRank.a;
      if (rate < 20) return BattleRank.b;
      if (rate < 50) return BattleRank.c;
      if (rate < 80) return BattleRank.d;
      return BattleRank.e;
    }
    if (ours.sunk == 0) {
      if (enemy.count > 0 && enemy.sunk == enemy.count) {
        return ours.lost <= 0 ? BattleRank.ss : BattleRank.s;
      }
      if (enemy.count > 1 && enemy.sunk >= _halfSunk(enemy.count)) {
        return BattleRank.a;
      }
    }
    if (enemy.flagshipSunk && ours.sunk < enemy.sunk) return BattleRank.b;
    if (ours.count == 1 && ours.flagshipCritical) return BattleRank.d;
    if (2 * enemy.rate > 5 * ours.rate) return BattleRank.b;
    if (10 * enemy.rate > 9 * ours.rate) return BattleRank.c;
    if (ours.sunk > 0 && ours.count - ours.sunk == 1) return BattleRank.e;
    return BattleRank.d;
  }

  ({
    int count,
    int sunk,
    int lost,
    int total,
    int rate,
    bool flagshipSunk,
    bool flagshipCritical,
  })
  _status(List<BattleShipSnapshot> ships) {
    final known = ships.where((ship) => !ship.hpUnknown).toList();
    if (known.isEmpty) {
      return (
        count: 0,
        sunk: 0,
        lost: 0,
        total: 0,
        rate: 0,
        flagshipSunk: false,
        flagshipCritical: false,
      );
    }
    final total = known.fold<int>(0, (v, s) => v + s.initialHp);
    final lost = known.fold<int>(0, (v, s) => v + s.initialHp - s.currentHp);
    final flagship = known.where((ship) => ship.position == 0).firstOrNull;
    return (
      count: known.length,
      sunk: known.where((s) => s.currentHp <= 0).length,
      lost: lost,
      total: total,
      rate: total == 0 ? 0 : lost * 100 ~/ total,
      flagshipSunk: flagship != null && flagship.currentHp <= 0,
      flagshipCritical:
          flagship != null && flagship.currentHp * 4 <= flagship.maxHp,
    );
  }

  int _halfSunk(int count) =>
      const <int>[0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 7, 7, 8][count.clamp(0, 12)];
  int _fleetRange(List<BattleShipSnapshot> fleet) => fleet.fold<int>(
    identical(fleet, _friendMain) && _friendEscort.isNotEmpty ? 6 : 0,
    (range, ship) => ship.position >= range ? ship.position + 1 : range,
  );
  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];
  Map<String, Object?>? _map(Object? value) =>
      value is Map ? value.map((k, v) => MapEntry(k.toString(), v)) : null;
  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  int _atInt(List<Object?> values, int index) =>
      index < values.length ? _int(values[index]) : 0;
  int _damage(Object? value) =>
      (_int(value is num ? value.floor() : value)).clamp(0, 1 << 30);
}
