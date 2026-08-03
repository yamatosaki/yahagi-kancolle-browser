import 'battle_models.dart';

class BattleDamageResult {
  const BattleDamageResult({
    required this.friendMain,
    required this.friendEscort,
    required this.enemyMain,
    required this.enemyEscort,
  });

  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;
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
    _applySupport(
      data['api_support_info'],
      flag: _int(data['api_support_flag']),
      battle: mutable,
    );
    _applySupport(
      data['api_n_support_info'],
      flag: _int(data['api_n_support_flag']),
      battle: mutable,
    );
    _walk(
      data,
      mutable,
      keyPath: '',
      friendActiveRole: _activeRole(activeDeck, 0),
      enemyActiveRole: _activeRole(activeDeck, 1),
    );
    return BattleDamageResult(
      friendMain: List.unmodifiable(mutable.friendMain),
      friendEscort: List.unmodifiable(mutable.friendEscort),
      enemyMain: List.unmodifiable(mutable.enemyMain),
      enemyEscort: List.unmodifiable(mutable.enemyEscort),
    );
  }

  void _walk(
    Object? value,
    _MutableBattle battle, {
    required String keyPath,
    required BattleFleetRole friendActiveRole,
    required BattleFleetRole enemyActiveRole,
  }) {
    if (value is Map) {
      final map = value.map((key, child) => MapEntry(key.toString(), child));
      if (map['api_df_list'] is List && map['api_damage'] is List) {
        _applyShelling(
          map,
          battle,
          friendActiveRole: friendActiveRole,
          enemyActiveRole: enemyActiveRole,
        );
      } else if (map['api_fdam'] is List || map['api_edam'] is List) {
        _applyArrayDamage(
          map,
          battle,
          escort: keyPath.contains('combined'),
          friendActiveRole: friendActiveRole,
          enemyActiveRole: enemyActiveRole,
        );
      }
      for (final entry in map.entries) {
        if (entry.key == 'api_support_info' ||
            entry.key == 'api_n_support_info') {
          continue;
        }
        _walk(
          entry.value,
          battle,
          keyPath: keyPath.isEmpty ? entry.key : '$keyPath.${entry.key}',
          friendActiveRole: friendActiveRole,
          enemyActiveRole: enemyActiveRole,
        );
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index++) {
        _walk(
          value[index],
          battle,
          keyPath: '$keyPath[$index]',
          friendActiveRole: friendActiveRole,
          enemyActiveRole: enemyActiveRole,
        );
      }
    }
  }

  void _applyShelling(
    Map<String, Object?> map,
    _MutableBattle battle, {
    required BattleFleetRole friendActiveRole,
    required BattleFleetRole enemyActiveRole,
  }) {
    final flags = _list(map['api_at_eflag']);
    final attackers = _list(map['api_at_list']);
    final defenders = _list(map['api_df_list']);
    final damageRows = _list(map['api_damage']);
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
      final hitCount = targets.length < damages.length
          ? targets.length
          : damages.length;
      var dealt = 0;
      for (var hit = 0; hit < hitCount; hit++) {
        final damage = _damage(damages[hit]);
        if (damage <= 0) {
          continue;
        }
        dealt += damage;
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
      if (!attackerIsEnemy && attackIndex < attackers.length && dealt > 0) {
        _addDamageDealt(
          battle,
          absolutePosition: _int(attackers[attackIndex]),
          damage: dealt,
          roleHint: friendActiveRole,
        );
      }
    }
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
      if (_damageValues(damages).length > 6) {
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
      if (_damageValues(damages).length > 6) {
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
    if (!escort && _damageValues(friendDamage).length > 6) {
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
    if (!escort && _damageValues(enemyDamage).length > 6) {
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
    final count = fleet.length < values.length ? fleet.length : values.length;
    for (var index = 0; index < count; index++) {
      final damage = _damage(values[index]);
      if (damage > 0) {
        fleet[index] = fleet[index].copyWith(
          currentHp: (fleet[index].currentHp - damage).clamp(0, 9999),
          damageReceived: fleet[index].damageReceived + damage,
        );
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
    final encodedEscort = absolutePosition >= 6;
    final escort = encodedEscort || roleHint == BattleFleetRole.escort;
    final index = encodedEscort ? absolutePosition - 6 : absolutePosition;
    final fleet = switch ((side, escort)) {
      (BattleSide.friend, false) => battle.friendMain,
      (BattleSide.friend, true) => battle.friendEscort,
      (BattleSide.enemy, false) => battle.enemyMain,
      (BattleSide.enemy, true) => battle.enemyEscort,
    };
    if (index < 0 || index >= fleet.length) {
      return;
    }
    fleet[index] = fleet[index].copyWith(
      currentHp: (fleet[index].currentHp - damage).clamp(0, 9999),
      damageReceived: fleet[index].damageReceived + damage,
    );
  }

  void _addDamageDealt(
    _MutableBattle battle, {
    required int absolutePosition,
    required int damage,
    required BattleFleetRole roleHint,
  }) {
    final encodedEscort = absolutePosition >= 6;
    final escort = encodedEscort || roleHint == BattleFleetRole.escort;
    final index = encodedEscort ? absolutePosition - 6 : absolutePosition;
    final fleet = escort ? battle.friendEscort : battle.friendMain;
    if (index < 0 || index >= fleet.length) {
      return;
    }
    fleet[index] = fleet[index].copyWith(
      damageDealt: fleet[index].damageDealt + damage,
    );
  }

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

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
}
