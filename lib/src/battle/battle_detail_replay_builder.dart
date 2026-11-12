import '../game_state/game_state.dart';
import 'battle_detail_models.dart';
import 'battle_models.dart';
import 'battle_session.dart';
import 'prediction/poi/poi_battle_rules.dart';

/// Converts the packets retained for one battle into a stable, display-only
/// snapshot. Parsing is deliberately independent from the live predictor so a
/// detail failure can never change the battle result shown to the player.
final class BattleDetailReplayBuilder {
  const BattleDetailReplayBuilder();

  BattleDetailSnapshot build({
    required BattleSession session,
    required LiveBattle battle,
    required DateTime completedAt,
    required GameState gameState,
  }) {
    final state = _ReplayState(battle);
    final stages = <BattleDetailStage>[];
    final stageKeys = <String>{};
    for (final packet in session.packets) {
      if (_isResultPath(packet.path)) continue;
      state.prepareNpc(packet.data['api_friendly_info'], gameState);
      for (final stage in _parsePacket(packet.path, packet.data, state)) {
        final key = stageKeys.add(stage.keyName)
            ? stage.keyName
            : '${packet.sequence}:${stage.keyName}';
        stages.add(
          BattleDetailStage(
            keyName: key,
            title: stage.title,
            attacks: stage.attacks,
          ),
        );
      }
    }
    return BattleDetailSnapshot(
      completedAtMillis: completedAt.millisecondsSinceEpoch,
      mapLabel: battle.context.mapLabel,
      nodeLabel: battle.context.nodeLabel,
      rank: battle.rank.label,
      enemyFleetName: battle.enemyFleetName,
      fleets: List<BattleDetailFleet>.unmodifiable(<BattleDetailFleet>[
        _fleet(
          battle.friendMain,
          gameState,
          state,
          BattleDetailSide.friend,
          BattleDetailFleetRole.main,
        ),
        _fleet(
          battle.friendEscort,
          gameState,
          state,
          BattleDetailSide.friend,
          BattleDetailFleetRole.escort,
        ),
        _fleet(
          battle.enemyMain,
          gameState,
          state,
          BattleDetailSide.enemy,
          BattleDetailFleetRole.main,
        ),
        _fleet(
          battle.enemyEscort,
          gameState,
          state,
          BattleDetailSide.enemy,
          BattleDetailFleetRole.escort,
        ),
      ]),
      stages: List<BattleDetailStage>.unmodifiable(stages),
    );
  }

  bool _isResultPath(String path) =>
      path.contains('battleresult') || path.contains('battle_result');

  BattleDetailFleet _fleet(
    List<BattleShipSnapshot> ships,
    GameState gameState,
    _ReplayState state,
    BattleDetailSide side,
    BattleDetailFleetRole role,
  ) {
    return BattleDetailFleet(
      side: side,
      role: role,
      ships: List<BattleDetailShip>.unmodifiable(
        ships.map((ship) => _ship(ship, gameState, state)),
      ),
    );
  }

  BattleDetailShip _ship(
    BattleShipSnapshot ship,
    GameState gameState,
    _ReplayState state,
  ) {
    final replay = state.resolveRole(
      _side(ship.side),
      _role(ship.fleetRole),
      ship.position,
    )!;
    final owned = ship.ownedShipId == null
        ? null
        : gameState.ships[ship.ownedShipId];
    final ownedEquipment = owned == null
        ? const <ShipEquipment>[]
        : gameState.equipmentForShip(owned);
    final equipment = ownedEquipment.isNotEmpty
        ? <BattleDetailEquipment>[
            for (final item in ownedEquipment)
              BattleDetailEquipment(
                masterId: item.owned.masterSlotItemId,
                name: item.master?.name ?? '装备 ${item.owned.masterSlotItemId}',
                improvement: item.owned.level,
                proficiency: item.owned.proficiency,
              ),
          ]
        : <BattleDetailEquipment>[
            for (final id in ship.equipmentMasterIds.where((id) => id > 0))
              BattleDetailEquipment(
                masterId: id,
                name: gameState.masterSlotItems[id]?.name ?? '装备 $id',
              ),
          ];
    return BattleDetailShip(
      masterId: ship.masterId,
      name: ship.name,
      side: _side(ship.side),
      role: _role(ship.fleetRole),
      position: ship.position,
      level: owned?.level,
      initialHp: ship.initialHp,
      maxHp: ship.maxHp,
      finalHp: replay.hp,
      damageDealt: replay.damageDealt,
      damageReceived: replay.damageReceived,
      equipment: List<BattleDetailEquipment>.unmodifiable(equipment),
      escaped: ship.isEscaped,
      hpUnknown: ship.hpUnknown,
    );
  }

  List<BattleDetailStage> _parsePacket(
    String path,
    Map<String, Object?> data,
    _ReplayState state,
  ) {
    final stages = <BattleDetailStage>[];
    void aerial(
      Object? raw,
      String key,
      String title, {
      bool npc = false,
      bool landBase = false,
    }) {
      _appendStage(
        stages,
        key,
        title,
        _parseAerial(raw, title, state, npc: npc, landBase: landBase),
      );
    }

    void shell(String key, String title, {bool night = false}) {
      _appendStage(
        stages,
        key,
        title,
        _parseShell(data[key], title, state, night: night),
      );
    }

    void torpedo(String key, String title, {bool opening = false}) {
      _appendStage(
        stages,
        key,
        title,
        _parseTorpedo(data[key], title, state, opening: opening),
      );
    }

    if (_nightPath(path) || path.contains('night_to_day')) {
      _appendStage(
        stages,
        'api_n_support_info',
        '夜战支援',
        _parseSupport(
          data['api_n_support_info'],
          '夜战支援',
          state,
          _int(data['api_n_support_flag']),
        ),
      );
      shell('api_n_hougeki1', '夜战第一轮', night: true);
      shell('api_n_hougeki2', '夜战第二轮', night: true);
      _appendStage(
        stages,
        'api_friendly_battle.api_hougeki',
        '友军舰队',
        _parseShell(
          _map(data['api_friendly_battle'])?['api_hougeki'],
          '友军舰队',
          state,
          night: true,
          npc: true,
        ),
      );
      shell('api_hougeki', '夜战', night: true);
      if (!path.contains('night_to_day')) return stages;
    }
    aerial(
      data['api_air_base_injection'],
      'api_air_base_injection',
      '基地喷气强袭',
      landBase: true,
    );
    aerial(data['api_injection_kouku'], 'api_injection_kouku', '喷气强袭');
    final bases = _list(data['api_air_base_attack']);
    for (var i = 0; i < bases.length; i++) {
      aerial(
        bases[i],
        'api_air_base_attack[$i]',
        '基地航空队 ${i + 1}',
        landBase: true,
      );
    }
    aerial(
      data['api_friendly_kouku'],
      'api_friendly_kouku',
      '友军航空战',
      npc: true,
    );
    aerial(data['api_kouku'], 'api_kouku', '航空战');
    aerial(data['api_kouku2'], 'api_kouku2', '第二次航空战');
    _appendStage(
      stages,
      'api_support_info',
      '支援攻击',
      _parseSupport(
        data['api_support_info'],
        '支援攻击',
        state,
        _int(data['api_support_flag']),
      ),
    );
    shell('api_opening_taisen', '开幕反潜');
    torpedo('api_opening_atack', '开幕雷击', opening: true);
    for (final key in poiDayShellingOrder(path, state.fleetType)) {
      if (key == 'api_raigeki') {
        torpedo(key, '雷击战');
      } else {
        shell(
          key,
          const {
            'api_hougeki1': '第一炮击战',
            'api_hougeki2': '第二炮击战',
            'api_hougeki3': '第三炮击战',
          }[key]!,
        );
      }
    }
    return stages;
  }

  bool _nightPath(String path) => path.contains('midnight');

  void _appendStage(
    List<BattleDetailStage> stages,
    String key,
    String title,
    List<BattleDetailAttack> attacks,
  ) {
    if (attacks.isNotEmpty) {
      stages.add(
        BattleDetailStage(
          keyName: key,
          title: title,
          attacks: List<BattleDetailAttack>.unmodifiable(attacks),
        ),
      );
    }
  }

  List<BattleDetailAttack> _parseShell(
    Object? raw,
    String title,
    _ReplayState state, {
    bool night = false,
    bool npc = false,
  }) {
    final map = _map(raw);
    if (map == null) return [];
    final flags = _list(map['api_at_eflag']);
    final attackers = _list(map['api_at_list']);
    final defenders = _list(map['api_df_list']);
    final damages = _list(map['api_damage']);
    final criticals = _list(map['api_cl_list']);
    final types = _list(map[night ? 'api_sp_list' : 'api_at_type']);
    final result = <BattleDetailAttack>[];
    final friendlySide = npc ? BattleDetailSide.npc : BattleDetailSide.friend;
    final friendlyRange = state.mainRange(friendlySide);
    for (
      var row = 0;
      row < attackers.length && row < defenders.length && row < damages.length;
      row++
    ) {
      final originalAttacker = _int(attackers[row]);
      if (originalAttacker < 0) continue;
      final targets = _list(defenders[row]);
      final hits = _list(damages[row]);
      if (targets.isEmpty || hits.isEmpty) continue;
      final cls = row < criticals.length ? _list(criticals[row]) : <Object?>[];
      final rawType = _atInt(types, row);
      final order = poiMultiTargetAttackOrder(rawType, isNight: night);
      final attackType = poiAttackTypeLabel(rawType, isNight: night);
      // POI applies ordinary multi-hit attacks as one HP transaction.
      // Specials retain server hit order and attribute each participating ship.
      final count = order == null ? 1 : targets.length;
      for (var hit = 0; hit < count && hit < hits.length; hit++) {
        var at =
            originalAttacker +
            (order == null ? 0 : (hit < order.length ? order[hit] : 0));
        var df = _int(targets[order == null ? 0 : hit]);
        final enemyAttack = map['api_at_eflag'] != null
            ? _atInt(flags, row) == 1
            : df < friendlyRange;
        // A combined night special can report our escort's local index.
        if (order != null &&
            night &&
            !npc &&
            !enemyAttack &&
            state.hasEscort(BattleDetailSide.friend) &&
            at < friendlyRange) {
          at += friendlyRange;
        }
        if (map['api_at_eflag'] == null) {
          if (at >= friendlyRange) at -= friendlyRange;
          if (df >= friendlyRange) df -= friendlyRange;
        }
        final attackerSide = enemyAttack
            ? BattleDetailSide.enemy
            : friendlySide;
        final defenderSide = enemyAttack
            ? friendlySide
            : BattleDetailSide.enemy;
        final attacker = state.resolve(attackerSide, at);
        final defender = state.resolve(defenderSide, df);
        if (defender == null) continue;
        final values = order == null
            ? hits.map(_damage).toList()
            : [_damage(hits[hit])];
        final kinds = order == null
            ? [for (var i = 0; i < values.length; i++) _hitKind(_atInt(cls, i))]
            : [_hitKind(_atInt(cls, hit))];
        result.add(
          _record(
            state,
            defender,
            values,
            kinds,
            attacker: attacker,
            attackerSide: attackerSide,
            source: title,
            type: attackType,
            typeCode: poiAttackTypeCode(rawType, isNight: night),
          ),
        );
      }
    }
    return result;
  }

  List<BattleDetailAttack> _parseAerial(
    Object? raw,
    String title,
    _ReplayState state, {
    bool npc = false,
    bool landBase = false,
  }) {
    final map = _map(raw);
    if (map == null) return [];
    final result = <BattleDetailAttack>[];
    void parse(Object? rawStage, BattleDetailFleetRole role) {
      final stage = _map(rawStage);
      if (stage == null) return;
      result.addAll(
        _aerialHits(
          stage,
          'e',
          title,
          state,
          (position) =>
              state.resolveRole(BattleDetailSide.enemy, role, position),
        ),
      );
      if (!landBase && !(npc && role == BattleDetailFleetRole.escort)) {
        result.addAll(
          _aerialHits(
            stage,
            'f',
            '敌$title',
            state,
            (position) => state.resolveRole(
              npc ? BattleDetailSide.npc : BattleDetailSide.friend,
              role,
              position,
            ),
          ),
        );
      }
    }

    parse(map['api_stage3'], BattleDetailFleetRole.main);
    parse(map['api_stage3_combined'], BattleDetailFleetRole.escort);
    return result;
  }

  List<BattleDetailAttack> _aerialHits(
    Map<String, Object?> stage,
    String side,
    String source,
    _ReplayState state,
    _ReplayShip? Function(int) resolve,
  ) {
    final damage = _list(stage['api_${side}dam']);
    final bombing = _list(stage['api_${side}bak_flag']);
    final torpedo = _list(stage['api_${side}rai_flag']);
    final critical = _list(stage['api_${side}cl_flag']);
    final result = <BattleDetailAttack>[];
    for (var i = 0; i < damage.length; i++) {
      if (_int(damage[i]) < 0 ||
          (_atInt(bombing, i) <= 0 && _atInt(torpedo, i) <= 0)) {
        continue;
      }
      final target = resolve(i);
      if (target == null) continue;
      final amount = _damage(damage[i]);
      final kind = _atInt(critical, i) == 1
          ? BattleDetailHitKind.critical
          : amount > 0
          ? BattleDetailHitKind.hit
          : BattleDetailHitKind.miss;
      result.add(_record(state, target, [amount], [kind], source: source));
    }
    return result;
  }

  List<BattleDetailAttack> _parseTorpedo(
    Object? raw,
    String title,
    _ReplayState state, {
    required bool opening,
  }) {
    final map = _map(raw);
    if (map == null) return [];
    final multi = opening && map['api_frai'] == null;
    final result = <BattleDetailAttack>[];
    void parse(String prefix, BattleDetailSide from, BattleDetailSide to) {
      final targets = _list(
        map[multi ? 'api_${prefix}rai_list_items' : 'api_${prefix}rai'],
      );
      final damage = _list(
        multi
            ? map['api_${prefix}ydam_list_items']
            : (map['api_${prefix}ydam'] ?? map['api_${prefix}dam']),
      );
      final critical = _list(
        map[multi ? 'api_${prefix}cl_list_items' : 'api_${prefix}cl'],
      );
      for (var i = 0; i < targets.length; i++) {
        final attacker = state.resolve(from, i);
        if (attacker == null) continue;
        final indices = multi ? _list(targets[i]) : [targets[i]];
        for (var j = 0; j < indices.length; j++) {
          if (!multi &&
              (i >= damage.length ||
                  damage[i] == null ||
                  i >= critical.length ||
                  critical[i] == null)) {
            continue;
          }
          final index = _int(indices[j]);
          if (index < 0) continue;
          final defender = state.resolve(to, index);
          if (defender == null) continue;
          final amount = multi
              ? _damage(_atValue(_list(_atValue(damage, i)), j))
              : _damage(damage[i]);
          final cl = multi
              ? _atInt(_list(_atValue(critical, i)), j)
              : _atInt(critical, i);
          result.add(
            _record(
              state,
              defender,
              [amount],
              [_hitKind(cl)],
              attacker: attacker,
              attackerSide: from,
              source: title,
            ),
          );
        }
      }
    }

    parse('f', BattleDetailSide.friend, BattleDetailSide.enemy);
    parse('e', BattleDetailSide.enemy, BattleDetailSide.friend);
    return result;
  }

  List<BattleDetailAttack> _parseSupport(
    Object? raw,
    String title,
    _ReplayState state,
    int flag,
  ) {
    final map = _map(raw);
    if (map == null || flag <= 0) return [];
    if (flag == 1 || flag == 4) {
      final stage = _map(_map(map['api_support_airatack'])?['api_stage3']);
      return stage == null
          ? []
          : _aerialHits(
              stage,
              'e',
              title,
              state,
              (position) => state.resolve(BattleDetailSide.enemy, position),
            );
    }
    if (flag != 2 && flag != 3) return [];
    final hourai = _map(map['api_support_hourai']);
    if (hourai == null) return [];
    final damage = _list(hourai['api_damage']);
    final critical = _list(hourai['api_cl_list']);
    final result = <BattleDetailAttack>[];
    for (var i = 0; i < damage.length; i++) {
      final kind = _hitKind(_atInt(critical, i));
      if (kind == BattleDetailHitKind.miss) continue;
      final target = state.resolve(BattleDetailSide.enemy, i);
      if (target != null) {
        result.add(
          _record(state, target, [_damage(damage[i])], [kind], source: title),
        );
      }
    }
    return result;
  }

  BattleDetailAttack _record(
    _ReplayState state,
    _ReplayShip defender,
    List<int> damages,
    List<BattleDetailHitKind> kinds, {
    _ReplayShip? attacker,
    BattleDetailSide? attackerSide,
    required String source,
    String? type,
    String typeCode = 'Normal',
  }) {
    final before = defender.hp;
    final total = damages.fold<int>(0, (sum, value) => sum + value);
    final control = state.damage(defender, total);
    if (attacker != null) attacker.damageDealt += total;
    var intermediateHp = before;
    final hits = <BattleDetailHit>[];
    for (var i = 0; i < damages.length; i++) {
      intermediateHp = (intermediateHp - damages[i]).clamp(0, defender.maxHp);
      hits.add(
        BattleDetailHit(
          damage: damages[i],
          kind: kinds[i],
          hpAfter: i == damages.length - 1 ? defender.hp : intermediateHp,
        ),
      );
    }
    return BattleDetailAttack(
      attackerSide:
          attackerSide ??
          (defender.side == BattleDetailSide.enemy
              ? BattleDetailSide.friend
              : BattleDetailSide.enemy),
      attackerRole: attacker?.role,
      attackerPosition: attacker?.position,
      attackerName: attacker?.name ?? source,
      defenderSide: defender.side,
      defenderRole: defender.role,
      defenderPosition: defender.position,
      defenderName: defender.name,
      attackType: type ?? source,
      attackTypeCode: typeCode,
      defenderHpBefore: before,
      defenderHpAfter: defender.hp,
      hits: List<BattleDetailHit>.unmodifiable(hits),
      damageControlName: control,
    );
  }

  BattleDetailHitKind _hitKind(int raw) => raw == 2
      ? BattleDetailHitKind.critical
      : raw == 1
      ? BattleDetailHitKind.hit
      : BattleDetailHitKind.miss;

  Object? _atValue(List<Object?> values, int index) =>
      index >= 0 && index < values.length ? values[index] : null;

  BattleDetailSide _side(BattleSide side) => side == BattleSide.friend
      ? BattleDetailSide.friend
      : BattleDetailSide.enemy;

  BattleDetailFleetRole _role(BattleFleetRole role) =>
      role == BattleFleetRole.main
      ? BattleDetailFleetRole.main
      : BattleDetailFleetRole.escort;

  Map<String, Object?>? _map(Object? value) => value is Map
      ? value.map((key, child) => MapEntry(key.toString(), child))
      : null;

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int _atInt(List<Object?> values, int index) =>
      index >= 0 && index < values.length ? _int(values[index]) : 0;

  int _damage(Object? value) {
    final amount = value is num ? value.floor() : _int(value);
    return amount.clamp(0, 1 << 30);
  }
}

final class _ReplayState {
  _ReplayState(LiveBattle battle)
    : fleetType = battle.context.combinedFleetType.apiValue {
    add(battle.friendMain);
    add(battle.friendEscort);
    add(battle.enemyMain);
    add(battle.enemyEscort);
  }

  final Map<String, _ReplayShip> _ships = <String, _ReplayShip>{};
  final int fleetType;
  int _npcRange = 0;

  void prepareNpc(Object? raw, GameState gameState) {
    if (raw is! Map) return;
    _ships.removeWhere((_, ship) => ship.side == BattleDetailSide.npc);
    final ids = raw['api_ship_id'] is List
        ? raw['api_ship_id'] as List
        : const [];
    final now = raw['api_nowhps'] is List
        ? raw['api_nowhps'] as List
        : const [];
    final max = raw['api_maxhps'] is List
        ? raw['api_maxhps'] as List
        : const [];
    _npcRange = ids.length;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] is! num || (ids[i] as num) <= 0) continue;
      final id = (ids[i] as num).toInt();
      final hp = i < now.length && now[i] is num ? (now[i] as num).toInt() : 0;
      final maxHp = i < max.length && max[i] is num
          ? (max[i] as num).toInt()
          : 0;
      _ships[_key(
        BattleDetailSide.npc,
        BattleDetailFleetRole.main,
        i,
      )] = _ReplayShip(
        side: BattleDetailSide.npc,
        role: BattleDetailFleetRole.main,
        position: i,
        name: '友军·${gameState.masterShips[id]?.name ?? '舰船 $id'}',
        maxHp: maxHp,
        hp: hp,
        damageControl: const [],
      );
    }
  }

  bool hasEscort(BattleDetailSide side) => _ships.values.any(
    (s) => s.side == side && s.role == BattleDetailFleetRole.escort,
  );

  int mainRange(BattleDetailSide side) {
    if (side == BattleDetailSide.npc) return _npcRange;
    return _ships.values
        .where((s) => s.side == side && s.role == BattleDetailFleetRole.main)
        .fold<int>(
          hasEscort(side) ? 6 : 0,
          (range, ship) => ship.position >= range ? ship.position + 1 : range,
        );
  }

  void add(List<BattleShipSnapshot> ships) {
    for (final ship in ships) {
      final side = ship.side == BattleSide.friend
          ? BattleDetailSide.friend
          : BattleDetailSide.enemy;
      final role = ship.fleetRole == BattleFleetRole.main
          ? BattleDetailFleetRole.main
          : BattleDetailFleetRole.escort;
      _ships[_key(side, role, ship.position)] = _ReplayShip(
        side: side,
        role: role,
        position: ship.position,
        name: ship.name,
        maxHp: ship.maxHp,
        hp: ship.initialHp,
        damageControl: <int>[
          for (final id in ship.equipmentMasterIds)
            if (id == 42 || id == 43) id,
        ],
      );
    }
  }

  _ReplayShip? resolve(BattleDetailSide side, int absolutePosition) {
    final range = mainRange(side);
    final role = absolutePosition >= range
        ? BattleDetailFleetRole.escort
        : BattleDetailFleetRole.main;
    final position = absolutePosition >= range
        ? absolutePosition - range
        : absolutePosition;
    return resolveRole(side, role, position);
  }

  _ReplayShip? resolveRole(
    BattleDetailSide side,
    BattleDetailFleetRole role,
    int position,
  ) => _ships[_key(side, role, position)];

  String? damage(_ReplayShip ship, int amount) {
    ship.damageReceived += amount;
    ship.hp = (ship.hp - amount).clamp(0, ship.maxHp);
    if (ship.side != BattleDetailSide.friend || ship.hp > 0) return null;
    if (ship.damageControl.isEmpty) return null;
    // Match POI useItem: choose the first repair item on each lethal attack.
    // This is display replay only; inventory consumption is handled elsewhere.
    final item = ship.damageControl.first;
    if (item == 42) {
      ship.hp = ship.maxHp ~/ 5;
      return '应急修理要员';
    }
    if (item == 43) {
      ship.hp = ship.maxHp;
      return '应急修理女神';
    }
    return null;
  }

  String _key(
    BattleDetailSide side,
    BattleDetailFleetRole role,
    int position,
  ) => '${side.name}:${role.name}:$position';
}

final class _ReplayShip {
  _ReplayShip({
    required this.side,
    required this.role,
    required this.position,
    required this.name,
    required this.maxHp,
    required this.hp,
    required this.damageControl,
  });

  final BattleDetailSide side;
  final BattleDetailFleetRole role;
  final int position;
  final String name;
  final int maxHp;
  int hp;
  int damageDealt = 0;
  int damageReceived = 0;
  final List<int> damageControl;
}
