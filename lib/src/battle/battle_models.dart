import '../game_state/game_state.dart';
import 'battle_detail_models.dart';
import 'battle_ship_details.dart';

enum BattleSide { friend, enemy }

enum BattleFleetRole { main, escort }

enum LiveBattleStatus { forecast, confirmed }

String battleEnemyFleetDisplayName(String name) {
  final trimmed = name.trim();
  return trimmed.startsWith('敌 ') ? trimmed.substring(2).trimLeft() : name;
}

enum BattleDisplayStage { navigation, battle, result }

const _unsetNodeDisplayLabel = Object();
const _unsetLandBaseRaid = Object();
const _unsetEnemyPreviewShips = Object();
const _unsetLastFormation = Object();

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
    this.nodeDisplayLabel,
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
  final String? nodeDisplayLabel;

  String get mapLabel => practice
      ? '演习'
      : mapAreaId > 0 && mapInfoNo > 0
      ? '$mapAreaId-$mapInfoNo'
      : '未知海域';

  String get nodeLabel {
    if (practice) return '演习';
    final label = nodeDisplayLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return '$label点';
    }
    return node > 0 ? '节点 $node' : '节点未知';
  }

  String get forecastNodeLabel {
    if (practice) return '演习';
    final label = nodeDisplayLabel?.trim();
    return label != null && label.isNotEmpty ? label : nodeLabel;
  }

  String get nodeTypeLabel {
    if (practice) return '普通战斗';
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
          12: '路线选择',
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
    Object? nodeDisplayLabel = _unsetNodeDisplayLabel,
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
      nodeDisplayLabel: identical(nodeDisplayLabel, _unsetNodeDisplayLabel)
          ? this.nodeDisplayLabel
          : nodeDisplayLabel as String?,
    );
  }
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
    this.damageReceived = 0,
    this.condition = 49,
    this.equipmentMasterIds = const <int>[],
    this.usedDamageControlItemIds = const <int>[],
    this.isEscaped = false,
    this.hpUnknown = false,
    this.details,
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
  final int damageReceived;
  final int condition;
  final List<int> equipmentMasterIds;
  final List<int> usedDamageControlItemIds;
  final bool isEscaped;
  final bool hpUnknown;
  final BattleShipDetails? details;

  bool get isSunk => currentHp <= 0;
  bool get isHeavilyDamaged => !isSunk && currentHp * 4 <= maxHp;

  BattleShipSnapshot copyWith({
    int? initialHp,
    int? maxHp,
    int? currentHp,
    int? damageDealt,
    int? damageReceived,
    int? condition,
    List<int>? usedDamageControlItemIds,
    bool? isEscaped,
    bool? hpUnknown,
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
      damageReceived: damageReceived ?? this.damageReceived,
      condition: condition ?? this.condition,
      equipmentMasterIds: equipmentMasterIds,
      usedDamageControlItemIds:
          usedDamageControlItemIds ?? this.usedDamageControlItemIds,
      isEscaped: isEscaped ?? this.isEscaped,
      hpUnknown: hpUnknown ?? this.hpUnknown,
      details: details,
    );
  }
}

class LandBaseRaidSnapshot {
  const LandBaseRaidSnapshot({
    required this.baseId,
    required this.name,
    required this.currentHp,
    required this.maxHp,
    required this.damage,
  });

  final int baseId;
  final String name;
  final int currentHp;
  final int maxHp;
  final int damage;

  double get hpRatio => maxHp <= 0 ? 0 : currentHp / maxHp;
}

class LandBaseRaidResult {
  const LandBaseRaidResult({
    required this.areaId,
    required this.bases,
    this.airSuperiority = '未知',
  });

  final int areaId;
  final List<LandBaseRaidSnapshot> bases;
  final String airSuperiority;
}

class EnemyPreviewShip {
  const EnemyPreviewShip({
    required this.masterId,
    required this.name,
    this.fleetRole = BattleFleetRole.main,
  });

  final int masterId;
  final String name;
  final BattleFleetRole fleetRole;

  @override
  bool operator ==(Object other) {
    return other is EnemyPreviewShip &&
        other.masterId == masterId &&
        other.name == name &&
        other.fleetRole == fleetRole;
  }

  @override
  int get hashCode => Object.hash(masterId, name, fleetRole);
}

enum BattleRewardKind { item, equipment, furniture }

class BattleRewardItem {
  const BattleRewardItem({
    required this.kind,
    required this.id,
    required this.count,
    required this.name,
  });

  final BattleRewardKind kind;
  final int id;
  final int count;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is BattleRewardItem &&
      other.kind == kind &&
      other.id == id &&
      other.count == count &&
      other.name == name;

  @override
  int get hashCode => Object.hash(kind, id, count, name);
}

class BattleResourceChange {
  const BattleResourceChange({
    required this.type,
    required this.amount,
    this.radarReduced = false,
  });

  final GameResourceType type;
  final int amount;
  final bool radarReduced;

  @override
  bool operator ==(Object other) =>
      other is BattleResourceChange &&
      other.type == type &&
      other.amount == amount &&
      other.radarReduced == radarReduced;

  @override
  int get hashCode => Object.hash(type, amount, radarReduced);
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
    this.dropShipMasterIds = const <int>[],
    this.dropItemId,
    this.dropItemName,
    this.rewardItems = const <BattleRewardItem>[],
    this.resourceChanges = const <BattleResourceChange>[],
    this.airSuperiority,
    this.landBaseRaid,
    this.enemyPreviewShips,
    this.enemyPreviewCombined = false,
    this.lastFormation,
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
  final List<int> dropShipMasterIds;
  final int? dropItemId;
  final String? dropItemName;
  final List<BattleRewardItem> rewardItems;
  final List<BattleResourceChange> resourceChanges;

  List<int> get effectiveDropShipMasterIds => dropShipMasterIds.isNotEmpty
      ? dropShipMasterIds
      : <int>[if ((dropShipMasterId ?? 0) > 0) dropShipMasterId!];
  final String? airSuperiority;
  final LandBaseRaidResult? landBaseRaid;
  final List<EnemyPreviewShip>? enemyPreviewShips;
  final bool enemyPreviewCombined;
  final int? lastFormation;

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
    List<int>? dropShipMasterIds,
    int? dropItemId,
    String? dropItemName,
    List<BattleRewardItem>? rewardItems,
    List<BattleResourceChange>? resourceChanges,
    String? airSuperiority,
    Object? landBaseRaid = _unsetLandBaseRaid,
    Object? enemyPreviewShips = _unsetEnemyPreviewShips,
    bool? enemyPreviewCombined,
    Object? lastFormation = _unsetLastFormation,
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
      dropShipMasterIds: dropShipMasterIds ?? this.dropShipMasterIds,
      dropItemId: dropItemId ?? this.dropItemId,
      dropItemName: dropItemName ?? this.dropItemName,
      rewardItems: rewardItems ?? this.rewardItems,
      resourceChanges: resourceChanges ?? this.resourceChanges,
      airSuperiority: airSuperiority ?? this.airSuperiority,
      landBaseRaid: identical(landBaseRaid, _unsetLandBaseRaid)
          ? this.landBaseRaid
          : landBaseRaid as LandBaseRaidResult?,
      enemyPreviewShips: identical(enemyPreviewShips, _unsetEnemyPreviewShips)
          ? this.enemyPreviewShips
          : enemyPreviewShips as List<EnemyPreviewShip>?,
      enemyPreviewCombined: enemyPreviewCombined ?? this.enemyPreviewCombined,
      lastFormation: identical(lastFormation, _unsetLastFormation)
          ? this.lastFormation
          : lastFormation as int?,
    );
  }
}

class BattleRecord {
  const BattleRecord({
    required this.battle,
    required this.completedAt,
    this.detail,
  });

  final LiveBattle battle;
  final DateTime completedAt;
  final BattleDetailSnapshot? detail;

  BattleRank get rank => battle.rank;
  String get enemyFleetName => battle.enemyFleetName;
  int? get dropShipMasterId => battle.dropShipMasterId;
  List<int> get dropShipMasterIds => battle.effectiveDropShipMasterIds;
}
