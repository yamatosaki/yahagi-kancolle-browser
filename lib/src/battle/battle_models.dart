import '../game_state/game_state.dart';

enum BattleSide { friend, enemy }

enum BattleFleetRole { main, escort }

enum LiveBattleStatus { forecast, confirmed }

enum BattleDisplayStage { navigation, battle, result }

enum BattleRank {
  ss('SS'),
  s('S'),
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E'),
  unknown('—');

  const BattleRank(this.label);

  final String label;

  static BattleRank parse(Object? value) {
    final label = value?.toString().toUpperCase();
    for (final rank in values) {
      if (rank.label == label) {
        return rank;
      }
    }
    return BattleRank.unknown;
  }
}

class BattleContext {
  const BattleContext({
    this.mapAreaId = 0,
    this.mapInfoNo = 0,
    this.node = 0,
    this.bossNode = 0,
    this.deckId = 1,
    this.combinedFleetType = CombinedFleetType.none,
    this.practice = false,
    this.eventId = 0,
    this.eventKind = 0,
  });

  final int mapAreaId;
  final int mapInfoNo;
  final int node;
  final int bossNode;
  final int deckId;
  final CombinedFleetType combinedFleetType;
  final bool practice;
  final int eventId;
  final int eventKind;

  String get mapLabel => practice
      ? '演习'
      : mapAreaId > 0 && mapInfoNo > 0
      ? '$mapAreaId-$mapInfoNo'
      : '未知海域';

  String get nodeLabel => node > 0 ? '${_alphabeticNode(node)}点' : '节点未知';

  String get nodeTypeLabel {
    var kind = eventId + 1;
    if (eventId == 4) {
      kind = switch (eventKind) {
        2 => 14,
        4 => 8,
        5 => 15,
        6 => 11,
        _ => kind,
      };
    } else if (eventId == 6) {
      kind = switch (eventKind) {
        1 => 7,
        2 => 12,
        _ => kind,
      };
    } else if (eventId == 7 && eventKind == 0) {
      kind = 13;
    } else if (eventId == 10 && eventKind == 0) {
      kind = 16;
    }
    return const <int, String>{
          1: '起点',
          2: '无战斗',
          3: '资源获得',
          4: '资源损失',
          5: '普通战斗',
          6: 'Boss 战',
          7: '无战斗',
          8: '空袭战',
          9: '护送成功',
          10: '运输点',
          11: '长距离空袭战',
          12: '能动分歧',
          13: '航空侦察',
          14: '夜战',
          15: '敌联合舰队',
          16: '泊地修理',
        }[kind] ??
        '节点事件';
  }

  BattleContext copyWith({
    int? mapAreaId,
    int? mapInfoNo,
    int? node,
    int? bossNode,
    int? deckId,
    CombinedFleetType? combinedFleetType,
    bool? practice,
    int? eventId,
    int? eventKind,
  }) {
    return BattleContext(
      mapAreaId: mapAreaId ?? this.mapAreaId,
      mapInfoNo: mapInfoNo ?? this.mapInfoNo,
      node: node ?? this.node,
      bossNode: bossNode ?? this.bossNode,
      deckId: deckId ?? this.deckId,
      combinedFleetType: combinedFleetType ?? this.combinedFleetType,
      practice: practice ?? this.practice,
      eventId: eventId ?? this.eventId,
      eventKind: eventKind ?? this.eventKind,
    );
  }
}

String _alphabeticNode(int node) {
  var value = node;
  final characters = <int>[];
  while (value > 0) {
    value--;
    characters.add(65 + value % 26);
    value ~/= 26;
  }
  return String.fromCharCodes(characters.reversed);
}

class BattleShipSnapshot {
  const BattleShipSnapshot({
    required this.masterId,
    required this.name,
    required this.side,
    required this.fleetRole,
    required this.position,
    required this.initialHp,
    required this.maxHp,
    required this.currentHp,
    this.ownedShipId,
    this.damageDealt = 0,
    this.condition = 49,
  });

  final int masterId;
  final int? ownedShipId;
  final String name;
  final BattleSide side;
  final BattleFleetRole fleetRole;
  final int position;
  final int initialHp;
  final int maxHp;
  final int currentHp;
  final int damageDealt;
  final int condition;

  bool get isSunk => currentHp <= 0;
  bool get isHeavilyDamaged => !isSunk && currentHp * 4 <= maxHp;

  BattleShipSnapshot copyWith({
    int? initialHp,
    int? maxHp,
    int? currentHp,
    int? damageDealt,
    int? condition,
  }) {
    return BattleShipSnapshot(
      masterId: masterId,
      ownedShipId: ownedShipId,
      name: name,
      side: side,
      fleetRole: fleetRole,
      position: position,
      initialHp: initialHp ?? this.initialHp,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      damageDealt: damageDealt ?? this.damageDealt,
      condition: condition ?? this.condition,
    );
  }
}

class LiveBattle {
  const LiveBattle({
    required this.context,
    this.friendMain = const <BattleShipSnapshot>[],
    this.friendEscort = const <BattleShipSnapshot>[],
    this.enemyMain = const <BattleShipSnapshot>[],
    this.enemyEscort = const <BattleShipSnapshot>[],
    this.rank = BattleRank.unknown,
    this.status = LiveBattleStatus.forecast,
    this.displayStage = BattleDisplayStage.battle,
    this.phaseLabel = '战斗',
    this.friendFormation = 0,
    this.enemyFormation = 0,
    this.engagement = 0,
    this.enemyFleetName = '',
    this.mvpPositions = const <int>[],
    this.dropShipMasterId,
    this.dropItemId,
    this.airSuperiority,
  });

  final BattleContext context;
  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;
  final BattleRank rank;
  final LiveBattleStatus status;
  final BattleDisplayStage displayStage;
  final String phaseLabel;
  final int friendFormation;
  final int enemyFormation;
  final int engagement;
  final String enemyFleetName;
  final List<int> mvpPositions;
  final int? dropShipMasterId;
  final int? dropItemId;
  final String? airSuperiority;

  List<BattleShipSnapshot> get friendShips =>
      List.unmodifiable(<BattleShipSnapshot>[...friendMain, ...friendEscort]);

  List<BattleShipSnapshot> get enemyShips =>
      List.unmodifiable(<BattleShipSnapshot>[...enemyMain, ...enemyEscort]);

  BattleShipSnapshot? get mvpCandidate {
    BattleShipSnapshot? best;
    for (final ship in friendShips) {
      if (best == null || ship.damageDealt > best.damageDealt) {
        best = ship;
      }
    }
    return best;
  }

  LiveBattle copyWith({
    BattleContext? context,
    List<BattleShipSnapshot>? friendMain,
    List<BattleShipSnapshot>? friendEscort,
    List<BattleShipSnapshot>? enemyMain,
    List<BattleShipSnapshot>? enemyEscort,
    BattleRank? rank,
    LiveBattleStatus? status,
    BattleDisplayStage? displayStage,
    String? phaseLabel,
    int? friendFormation,
    int? enemyFormation,
    int? engagement,
    String? enemyFleetName,
    List<int>? mvpPositions,
    int? dropShipMasterId,
    int? dropItemId,
    String? airSuperiority,
  }) {
    return LiveBattle(
      context: context ?? this.context,
      friendMain: friendMain ?? this.friendMain,
      friendEscort: friendEscort ?? this.friendEscort,
      enemyMain: enemyMain ?? this.enemyMain,
      enemyEscort: enemyEscort ?? this.enemyEscort,
      rank: rank ?? this.rank,
      status: status ?? this.status,
      displayStage: displayStage ?? this.displayStage,
      phaseLabel: phaseLabel ?? this.phaseLabel,
      friendFormation: friendFormation ?? this.friendFormation,
      enemyFormation: enemyFormation ?? this.enemyFormation,
      engagement: engagement ?? this.engagement,
      enemyFleetName: enemyFleetName ?? this.enemyFleetName,
      mvpPositions: mvpPositions ?? this.mvpPositions,
      dropShipMasterId: dropShipMasterId ?? this.dropShipMasterId,
      dropItemId: dropItemId ?? this.dropItemId,
      airSuperiority: airSuperiority ?? this.airSuperiority,
    );
  }
}

class BattleRecord {
  const BattleRecord({required this.battle, required this.completedAt});

  final LiveBattle battle;
  final DateTime completedAt;

  BattleRank get rank => battle.rank;
  String get enemyFleetName => battle.enemyFleetName;
  int? get dropShipMasterId => battle.dropShipMasterId;
}
