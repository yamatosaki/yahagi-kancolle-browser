import 'battle_models.dart';

enum BattleStageKind {
  landBaseJetAssault,
  jetAssault,
  landBaseAirAttack,
  friendlyAirCombat,
  aerialCombat,
  secondAerialCombat,
  support,
  openingAntiSubmarine,
  openingTorpedo,
  shelling,
  closingTorpedo,
  nightSupport,
  nightShelling,
  friendlyNightBattle,
}

class BattleStageTrace {
  const BattleStageTrace({required this.kind, required this.sourceKey});

  final BattleStageKind kind;
  final String sourceKey;
}

class BattleParseIssue {
  const BattleParseIssue({required this.stage, required this.message});

  final String stage;
  final String message;
}

class BattleDamageResult {
  const BattleDamageResult({
    required this.friendMain,
    required this.friendEscort,
    required this.enemyMain,
    required this.enemyEscort,
    this.stages = const <BattleStageTrace>[],
    this.issues = const <BattleParseIssue>[],
  });

  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;
  final List<BattleStageTrace> stages;
  final List<BattleParseIssue> issues;
  bool get isConfirmed => issues.isEmpty;
}

class BattleDamageParser {
  BattleDamageResult apply({
    required Map<String, Object?> data,
    required List<BattleShipSnapshot> friendMain,
    List<BattleShipSnapshot> friendEscort = const <BattleShipSnapshot>[],
    required List<BattleShipSnapshot> enemyMain,
    List<BattleShipSnapshot> enemyEscort = const <BattleShipSnapshot>[],
    String path = '',
  }) {
    final mutable = _MutableBattle(
      friendMain: List<BattleShipSnapshot>.from(friendMain),
      friendEscort: List<BattleShipSnapshot>.from(friendEscort),
      enemyMain: List<BattleShipSnapshot>.from(enemyMain),
      enemyEscort: List<BattleShipSnapshot>.from(enemyEscort),
    );
    final activeDeck = _list(data['api_active_deck']);
    final friendRole = _activeRole(activeDeck, 0);
    final enemyRole = _activeRole(activeDeck, 1);
    final stages = <BattleStageTrace>[];
    final nightFirst = path.contains('night_to_day');
    if (nightFirst) {
      _applyNightStages(
        data,
        mutable,
        stages,
        friendRole: friendRole,
        enemyRole: enemyRole,
      );
    }
    _applyDayStages(
      data,
      mutable,
      stages,
      friendRole: friendRole,
      enemyRole: enemyRole,
    );
    if (!nightFirst) {
      _applyNightStages(
        data,
        mutable,
        stages,
        friendRole: friendRole,
        enemyRole: enemyRole,
      );
    }
    return BattleDamageResult(
      friendMain: List.unmodifiable(mutable.friendMain),
      friendEscort: List.unmodifiable(mutable.friendEscort),
      enemyMain: List.unmodifiable(mutable.enemyMain),
      enemyEscort: List.unmodifiable(mutable.enemyEscort),
      stages: List.unmodifiable(stages),
      issues: List.unmodifiable(mutable.issues),
    );
  }

  void _applyDayStages(
    Map<String, Object?> data,
    _MutableBattle battle,
    List<BattleStageTrace> stages, {
    required BattleFleetRole friendRole,
    required BattleFleetRole enemyRole,
  }) {
    void aerial(String key, BattleStageKind kind) {
      final map = _asMap(data[key]);
      if (map == null) return;
      battle.currentStage = key;
      stages.add(BattleStageTrace(kind: kind, sourceKey: key));
      _applyAerial(map, battle, friendRole: friendRole, enemyRole: enemyRole);
    }

    aerial('api_air_base_injection', BattleStageKind.landBaseJetAssault);
    aerial('api_injection_kouku', BattleStageKind.jetAssault);
    final landBase = _list(data['api_air_base_attack']);
    for (var index = 0; index < landBase.length; index++) {
      final map = _asMap(landBase[index]);
      if (map == null) continue;
      battle.currentStage = 'api_air_base_attack[$index]';
      stages.add(
        BattleStageTrace(
          kind: BattleStageKind.landBaseAirAttack,
          sourceKey: 'api_air_base_attack[$index]',
        ),
      );
      _applyAerial(map, battle, friendRole: friendRole, enemyRole: enemyRole);
    }
    aerial('api_friendly_kouku', BattleStageKind.friendlyAirCombat);
    aerial('api_kouku', BattleStageKind.aerialCombat);
    aerial('api_kouku2', BattleStageKind.secondAerialCombat);
    if (data['api_stage3'] is Map || data['api_stage3_combined'] is Map) {
      battle.currentStage = 'packet-stage3';
      stages.add(
        const BattleStageTrace(
          kind: BattleStageKind.aerialCombat,
          sourceKey: 'packet-stage3',
        ),
      );
      _applyAerial(data, battle, friendRole: friendRole, enemyRole: enemyRole);
    }

    if (_asMap(data['api_support_info']) case final support?) {
      final flag = _int(data['api_support_flag']);
      if (flag > 0) {
        battle.currentStage = 'api_support_info';
        stages.add(
          const BattleStageTrace(
            kind: BattleStageKind.support,
            sourceKey: 'api_support_info',
          ),
        );
        _applySupport(support, flag: flag, battle: battle);
      }
    }

    void shelling(String key, BattleStageKind kind) {
      final map = _asMap(data[key]);
      if (map == null) return;
      battle.currentStage = key;
      stages.add(BattleStageTrace(kind: kind, sourceKey: key));
      _applyShelling(
        map,
        battle,
        friendActiveRole: friendRole,
        enemyActiveRole: enemyRole,
        isNight:
            kind == BattleStageKind.nightShelling ||
            kind == BattleStageKind.friendlyNightBattle,
        attributeFriendDamage: kind != BattleStageKind.friendlyNightBattle,
      );
    }

    shelling('api_opening_taisen', BattleStageKind.openingAntiSubmarine);
    if (_asMap(data['api_opening_atack']) case final opening?) {
      battle.currentStage = 'api_opening_atack';
      stages.add(
        const BattleStageTrace(
          kind: BattleStageKind.openingTorpedo,
          sourceKey: 'api_opening_atack',
        ),
      );
      _applyArrayDamage(
        opening,
        battle,
        escort: false,
        friendActiveRole: friendRole,
        enemyActiveRole: enemyRole,
      );
      _addTorpedoDamage(opening, battle);
    }
    shelling('api_hougeki1', BattleStageKind.shelling);
    shelling('api_hougeki2', BattleStageKind.shelling);
    shelling('api_hougeki3', BattleStageKind.shelling);
    if (_asMap(data['api_raigeki']) case final closing?) {
      battle.currentStage = 'api_raigeki';
      stages.add(
        const BattleStageTrace(
          kind: BattleStageKind.closingTorpedo,
          sourceKey: 'api_raigeki',
        ),
      );
      _applyArrayDamage(
        closing,
        battle,
        escort: false,
        friendActiveRole: friendRole,
        enemyActiveRole: enemyRole,
      );
      _addTorpedoDamage(closing, battle);
    }
  }

  void _addTorpedoDamage(Map<String, Object?> map, _MutableBattle battle) {
    final rows = _list(map['api_fydam_list_items']);
    if (rows.isNotEmpty) {
      for (var position = 0; position < rows.length; position++) {
        final amount = _list(
          rows[position],
        ).fold<int>(0, (sum, value) => sum + _damage(value));
        _addDamageDealt(
          battle,
          absolutePosition: position,
          damage: amount,
          roleHint: BattleFleetRole.main,
        );
      }
      return;
    }
    if (map['api_frai'] == null) return;
    final values = _list(map['api_fydam']).isNotEmpty
        ? _list(map['api_fydam'])
        : _list(map['api_fdam']);
    for (var position = 0; position < values.length; position++) {
      _addDamageDealt(
        battle,
        absolutePosition: position,
        damage: _damage(values[position]),
        roleHint: BattleFleetRole.main,
      );
    }
  }

  void _applyNightStages(
    Map<String, Object?> data,
    _MutableBattle battle,
    List<BattleStageTrace> stages, {
    required BattleFleetRole friendRole,
    required BattleFleetRole enemyRole,
  }) {
    if (_asMap(data['api_n_support_info']) case final support?) {
      final flag = _int(data['api_n_support_flag']);
      if (flag > 0) {
        battle.currentStage = 'api_n_support_info';
        stages.add(
          const BattleStageTrace(
            kind: BattleStageKind.nightSupport,
            sourceKey: 'api_n_support_info',
          ),
        );
        _applySupport(support, flag: flag, battle: battle);
      }
    }

    void shelling(Object? value, String key, BattleStageKind kind) {
      final map = _asMap(value);
      if (map == null) return;
      battle.currentStage = key;
      stages.add(BattleStageTrace(kind: kind, sourceKey: key));
      _applyShelling(
        map,
        battle,
        friendActiveRole: friendRole,
        enemyActiveRole: enemyRole,
      );
    }

    shelling(
      data['api_n_hougeki1'],
      'api_n_hougeki1',
      BattleStageKind.nightShelling,
    );
    shelling(
      data['api_n_hougeki2'],
      'api_n_hougeki2',
      BattleStageKind.nightShelling,
    );
    final friendlyBattle = _asMap(data['api_friendly_battle']);
    shelling(
      friendlyBattle?['api_hougeki'],
      'api_friendly_battle.api_hougeki',
      BattleStageKind.friendlyNightBattle,
    );
    shelling(data['api_hougeki'], 'api_hougeki', BattleStageKind.nightShelling);
  }

  void _applyAerial(
    Map<String, Object?> map,
    _MutableBattle battle, {
    required BattleFleetRole friendRole,
    required BattleFleetRole enemyRole,
  }) {
    if (_asMap(map['api_stage3']) case final stage3?) {
      _applyArrayDamage(
        stage3,
        battle,
        escort: false,
        friendActiveRole: friendRole,
        enemyActiveRole: enemyRole,
      );
    }
    if (_asMap(map['api_stage3_combined']) case final combined?) {
      _applyArrayDamage(
        combined,
        battle,
        escort: true,
        friendActiveRole: friendRole,
        enemyActiveRole: enemyRole,
      );
    }
  }

  void _applyShelling(
    Map<String, Object?> map,
    _MutableBattle battle, {
    required BattleFleetRole friendActiveRole,
    required BattleFleetRole enemyActiveRole,
    bool isNight = false,
    bool attributeFriendDamage = true,
  }) {
    final flags = _list(map['api_at_eflag']);
    final attackers = _list(map['api_at_list']);
    final defenders = _list(map['api_df_list']);
    final damageRows = _list(map['api_damage']);
    final attackTypes = _list(map[isNight ? 'api_sp_list' : 'api_at_type']);
    final count = defenders.length < damageRows.length
        ? defenders.length
        : damageRows.length;

    for (var attackIndex = 0; attackIndex < count; attackIndex++) {
      final targets = _list(defenders[attackIndex]);
      final damages = _list(damageRows[attackIndex]);
      if (targets.isEmpty || damages.isEmpty) {
        continue;
      }
      final hasAttackerFlag = attackIndex < flags.length;
      final attackerIsEnemy = hasAttackerFlag
          ? _int(flags[attackIndex]) != 0
          : _int(targets.first) < 6;
      final attackOrder = attackIndex < attackTypes.length
          ? _multiTargetAttackOrder(
              _int(attackTypes[attackIndex]),
              isNight: isNight,
            )
          : null;
      final hitCount = targets.length < damages.length
          ? targets.length
          : damages.length;
      var dealt = 0;
      for (var hit = 0; hit < hitCount; hit++) {
        final damage = _damage(damages[hit]);
        if (damage <= 0) {
          continue;
        }
        if (attributeFriendDamage && !attackerIsEnemy && attackOrder != null) {
          var attacker = attackIndex < attackers.length
              ? _int(attackers[attackIndex])
              : -1;
          if (attacker >= 0) {
            attacker += hit < attackOrder.length ? attackOrder[hit] : 0;
            if (isNight &&
                battle.friendEscort.isNotEmpty &&
                attacker < battle.friendMain.length) {
              attacker += battle.friendMain.length;
            }
            _addDamageDealt(
              battle,
              absolutePosition: attacker,
              damage: damage,
              roleHint: BattleFleetRole.main,
            );
          }
        } else {
          dealt += damage;
        }
        var targetPosition = _int(targets[hit]);
        var targetRole = attackerIsEnemy ? friendActiveRole : enemyActiveRole;
        if (!hasAttackerFlag) {
          if (!attackerIsEnemy && targetPosition >= 6) {
            targetPosition -= 6;
          }
          targetRole = BattleFleetRole.main;
        }
        _damagePosition(
          battle,
          side: attackerIsEnemy ? BattleSide.friend : BattleSide.enemy,
          absolutePosition: targetPosition,
          damage: damage,
          roleHint: targetRole,
        );
      }
      if (attributeFriendDamage &&
          !attackerIsEnemy &&
          attackOrder == null &&
          attackIndex < attackers.length &&
          dealt > 0) {
        _addDamageDealt(
          battle,
          absolutePosition: _int(attackers[attackIndex]),
          damage: dealt,
          roleHint: friendActiveRole,
        );
      }
    }
  }

  static List<int>? _multiTargetAttackOrder(
    int attackType, {
    required bool isNight,
  }) {
    if (!isNight && attackType == 1) return const <int>[0, 0, 0];
    return switch (attackType) {
      100 => const <int>[0, 2, 4],
      101 || 102 || 105 || 106 => const <int>[0, 0, 1],
      103 => const <int>[0, 1, 2],
      104 when isNight => const <int>[0, 1],
      200 when isNight => const <int>[0, 0],
      300 => const <int>[1, 1, 2, 2],
      301 => const <int>[2, 2, 3, 3],
      302 => const <int>[1, 1, 3, 3],
      400 => const <int>[0, 1, 2],
      401 => const <int>[0, 0, 1],
      1000 => const <int>[0, 0, 0, 0, 0, 0],
      _ => null,
    };
  }

  void _applySupport(
    Object? value, {
    required int flag,
    required _MutableBattle battle,
  }) {
    if (value is! Map || flag <= 0) {
      return;
    }
    final support = value.map((key, child) => MapEntry(key.toString(), child));
    if (flag == 1 || flag == 4) {
      final airAttack = support['api_support_airatack'];
      if (airAttack is! Map) {
        return;
      }
      final airMap = airAttack.map(
        (key, child) => MapEntry(key.toString(), child),
      );
      final stage3 = airMap['api_stage3'];
      if (stage3 is! Map) {
        return;
      }
      final stage3Map = stage3.map(
        (key, child) => MapEntry(key.toString(), child),
      );
      final damages = _list(stage3Map['api_edam']);
      if (battle.enemyEscort.isNotEmpty && _damageValues(damages).length > 6) {
        _applySplitDamageArray(battle.enemyMain, battle.enemyEscort, damages);
      } else {
        _applyDamageArray(battle.enemyMain, damages);
      }
      return;
    }
    if (flag == 2 || flag == 3) {
      final hourai = support['api_support_hourai'];
      if (hourai is! Map) {
        return;
      }
      final houraiMap = hourai.map(
        (key, child) => MapEntry(key.toString(), child),
      );
      final damages = _list(houraiMap['api_damage']);
      if (battle.enemyEscort.isNotEmpty && _damageValues(damages).length > 6) {
        _applySplitDamageArray(battle.enemyMain, battle.enemyEscort, damages);
      } else {
        _applyDamageArray(battle.enemyMain, damages);
      }
    }
  }

  void _applyArrayDamage(
    Map<String, Object?> map,
    _MutableBattle battle, {
    required bool escort,
    required BattleFleetRole friendActiveRole,
    required BattleFleetRole enemyActiveRole,
  }) {
    final friendDamage = _list(map['api_fdam']);
    final enemyDamage = _list(map['api_edam']);
    if (!escort &&
        battle.friendEscort.isNotEmpty &&
        _damageValues(friendDamage).length > 6) {
      _applySplitDamageArray(
        battle.friendMain,
        battle.friendEscort,
        friendDamage,
      );
    } else {
      _applyDamageArray(
        escort || friendActiveRole == BattleFleetRole.escort
            ? battle.friendEscort
            : battle.friendMain,
        friendDamage,
      );
    }
    if (!escort &&
        battle.enemyEscort.isNotEmpty &&
        _damageValues(enemyDamage).length > 6) {
      _applySplitDamageArray(battle.enemyMain, battle.enemyEscort, enemyDamage);
    } else {
      _applyDamageArray(
        escort || enemyActiveRole == BattleFleetRole.escort
            ? battle.enemyEscort
            : battle.enemyMain,
        enemyDamage,
      );
    }
  }

  List<Object?> _damageValues(List<Object?> damages) =>
      damages.isNotEmpty && _int(damages.first) < 0
      ? damages.sublist(1)
      : damages;

  void _applySplitDamageArray(
    List<BattleShipSnapshot> main,
    List<BattleShipSnapshot> escort,
    List<Object?> damages,
  ) {
    final values = _damageValues(damages);
    _applyDamageArray(main, values.take(6).toList());
    _applyDamageArray(escort, values.skip(6).take(6).toList());
  }

  void _applyDamageArray(
    List<BattleShipSnapshot> fleet,
    List<Object?> damages,
  ) {
    final values = _damageValues(damages);
    for (var position = 0; position < values.length; position++) {
      final damage = _damage(values[position]);
      if (damage > 0) {
        final index = fleet.indexWhere((ship) => ship.position == position);
        if (index >= 0) {
          fleet[index] = _receiveDamage(fleet[index], damage);
        }
      }
    }
  }

  void _damagePosition(
    _MutableBattle battle, {
    required BattleSide side,
    required int absolutePosition,
    required int damage,
    required BattleFleetRole roleHint,
  }) {
    final hasEscort = switch (side) {
      BattleSide.friend => battle.friendEscort.isNotEmpty,
      BattleSide.enemy => battle.enemyEscort.isNotEmpty,
    };
    final encodedEscort = hasEscort && absolutePosition >= 6;
    final escort = encodedEscort || roleHint == BattleFleetRole.escort;
    final index = encodedEscort ? absolutePosition - 6 : absolutePosition;
    final fleet = switch ((side, escort)) {
      (BattleSide.friend, false) => battle.friendMain,
      (BattleSide.friend, true) => battle.friendEscort,
      (BattleSide.enemy, false) => battle.enemyMain,
      (BattleSide.enemy, true) => battle.enemyEscort,
    };
    final fleetIndex = fleet.indexWhere((ship) => ship.position == index);
    if (fleetIndex < 0) {
      battle.issue('target $absolutePosition is outside the captured fleets');
      return;
    }
    fleet[fleetIndex] = _receiveDamage(fleet[fleetIndex], damage);
  }

  void _addDamageDealt(
    _MutableBattle battle, {
    required int absolutePosition,
    required int damage,
    required BattleFleetRole roleHint,
  }) {
    if (damage <= 0) return;
    final encodedEscort =
        battle.friendEscort.isNotEmpty && absolutePosition >= 6;
    final escort = encodedEscort || roleHint == BattleFleetRole.escort;
    final index = encodedEscort ? absolutePosition - 6 : absolutePosition;
    final fleet = escort ? battle.friendEscort : battle.friendMain;
    final fleetIndex = fleet.indexWhere((ship) => ship.position == index);
    if (fleetIndex < 0) {
      battle.issue('attacker $absolutePosition is outside the captured fleets');
      return;
    }
    fleet[fleetIndex] = fleet[fleetIndex].copyWith(
      damageDealt: fleet[fleetIndex].damageDealt + damage,
    );
  }

  BattleShipSnapshot _receiveDamage(BattleShipSnapshot ship, int damage) {
    var hp = (ship.currentHp - damage).clamp(0, ship.maxHp);
    final usedItems = List<int>.from(ship.usedDamageControlItemIds);
    if (ship.side == BattleSide.friend && hp <= 0) {
      final damageControl = _nextDamageControl(ship, usedItems);
      if (damageControl == 42) {
        hp = ship.maxHp ~/ 5;
        usedItems.add(42);
      } else if (damageControl == 43) {
        hp = ship.maxHp;
        usedItems.add(43);
      }
    }
    return ship.copyWith(
      currentHp: hp,
      damageReceived: ship.damageReceived + damage,
      usedDamageControlItemIds: usedItems,
    );
  }

  int? _nextDamageControl(BattleShipSnapshot ship, List<int> usedItems) {
    final usedCounts = <int, int>{};
    for (final id in usedItems) {
      usedCounts[id] = (usedCounts[id] ?? 0) + 1;
    }
    final seenCounts = <int, int>{};
    for (final id in ship.equipmentMasterIds) {
      if (id != 42 && id != 43) {
        continue;
      }
      seenCounts[id] = (seenCounts[id] ?? 0) + 1;
      if (seenCounts[id]! > (usedCounts[id] ?? 0)) {
        return id;
      }
    }
    return null;
  }

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  Map<String, Object?>? _asMap(Object? value) => value is Map
      ? value.map((key, child) => MapEntry(key.toString(), child))
      : null;

  int _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };

  int _damage(Object? value) {
    final damage = switch (value) {
      num number => number.floor(),
      String text => double.tryParse(text)?.floor() ?? 0,
      _ => 0,
    };
    return damage < 0 ? 0 : damage;
  }

  BattleFleetRole _activeRole(List<Object?> values, int index) =>
      index < values.length && _int(values[index]) == 2
      ? BattleFleetRole.escort
      : BattleFleetRole.main;
}

class _MutableBattle {
  _MutableBattle({
    required this.friendMain,
    required this.friendEscort,
    required this.enemyMain,
    required this.enemyEscort,
  });

  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;
  final List<BattleParseIssue> issues = <BattleParseIssue>[];
  String currentStage = 'unknown';

  void issue(String message) {
    issues.add(BattleParseIssue(stage: currentStage, message: message));
  }
}
