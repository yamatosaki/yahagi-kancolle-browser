import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'combat_state.dart';

enum GameResourceType {
  fuel(1, '燃料'),
  ammunition(2, '弹药'),
  steel(3, '钢材'),
  bauxite(4, '铝土'),
  instantBuild(5, '高建造材'),
  instantRepair(6, '高修复材'),
  developmentMaterial(7, '开发资材'),
  improvementMaterial(8, '改修资材');

  const GameResourceType(this.apiId, this.label);

  final int apiId;
  final String label;

  static GameResourceType? fromApiId(int id) {
    for (final type in values) {
      if (type.apiId == id) {
        return type;
      }
    }
    return null;
  }
}

class MasterShipType {
  const MasterShipType({required this.id, required this.name});

  final int id;
  final String name;
}

class MasterShip {
  const MasterShip({
    required this.id,
    required this.name,
    required this.shipTypeId,
    this.classTypeId = 0,
    this.speed = 0,
    this.range = 0,
    this.maxFuel = 0,
    this.maxAmmo = 0,
    this.slotCount = 0,
    this.buildTimeMinutes = 0,
    this.portraitFileName,
    this.portraitVersion,
  });

  final int id;
  final String name;
  final int shipTypeId;
  final int classTypeId;
  final int speed;
  final int range;
  final int maxFuel;
  final int maxAmmo;
  final int slotCount;
  final int buildTimeMinutes;
  final String? portraitFileName;
  final String? portraitVersion;

  MasterShip copyWith({String? portraitFileName, String? portraitVersion}) {
    return MasterShip(
      id: id,
      name: name,
      shipTypeId: shipTypeId,
      classTypeId: classTypeId,
      speed: speed,
      range: range,
      maxFuel: maxFuel,
      maxAmmo: maxAmmo,
      slotCount: slotCount,
      buildTimeMinutes: buildTimeMinutes,
      portraitFileName: portraitFileName ?? this.portraitFileName,
      portraitVersion: portraitVersion ?? this.portraitVersion,
    );
  }
}

class MasterSlotItem {
  const MasterSlotItem({
    required this.id,
    required this.name,
    this.firepower = 0,
    this.torpedo = 0,
    this.bombing = 0,
    this.antiAir = 0,
    this.antiSub = 0,
    this.lineOfSight = 0,
    this.accuracy = 0,
    this.evasion = 0,
    this.armor = 0,
    this.range = 0,
    this.type = const <int>[],
  });

  final int id;
  final String name;
  final int firepower;
  final int torpedo;
  final int bombing;
  final int antiAir;
  final int antiSub;
  final int lineOfSight;
  final int accuracy;
  final int evasion;
  final int armor;
  final int range;
  final List<int> type;
}

class MasterMission {
  const MasterMission({
    required this.id,
    required this.name,
    required this.duration,
    this.displayNumber = '',
    this.mapAreaId = 0,
    this.fuelConsumptionRate = 0,
    this.ammunitionConsumptionRate = 0,
    this.winItem1 = const [],
    this.winItem2 = const [],
  });

  final int id;
  final String name;
  final Duration duration;
  final String displayNumber;
  final int mapAreaId;
  final double fuelConsumptionRate;
  final double ammunitionConsumptionRate;
  final List<int> winItem1;
  final List<int> winItem2;

  int get fuelConsumptionPercent => (fuelConsumptionRate * 100).round();
  int get ammunitionConsumptionPercent =>
      (ammunitionConsumptionRate * 100).round();

  DateTime? startedAt(DateTime? completionTime) {
    return completionTime?.subtract(duration);
  }
}

class OwnedShip {
  const OwnedShip({
    required this.id,
    required this.masterId,
    required this.level,
    this.currentHp = 0,
    this.maxHp = 0,
    this.condition = 49,
    this.currentFuel = 0,
    this.currentAmmo = 0,
    this.nextExperience = 0,
    this.firepower = 0,
    this.torpedo = 0,
    this.antiAir = 0,
    this.antiSub = 0,
    this.lineOfSight = 0,
    this.slotIds = const <int>[],
    this.onSlot = const <int>[],
    this.extraSlotId = -1,
    this.repairDurationMilliseconds = 0,
  });

  final int id;
  final int masterId;
  final int level;
  final int currentHp;
  final int maxHp;
  final int condition;
  final int currentFuel;
  final int currentAmmo;
  final int nextExperience;
  final int firepower;
  final int torpedo;
  final int antiAir;
  final int antiSub;
  final int lineOfSight;
  final List<int> slotIds;
  final List<int> onSlot;
  final int extraSlotId;
  final int repairDurationMilliseconds;
}

class OwnedSlotItem {
  const OwnedSlotItem({
    required this.id,
    required this.masterId,
    this.level = 0,
    this.proficiency = 0,
  });

  final int id;
  final int masterId;
  final int level;
  final int proficiency;
}

class FleetMission {
  const FleetMission({this.state = 0, this.missionId = 0, this.completionTime});

  final int state;
  final int missionId;
  final DateTime? completionTime;

  bool get isActive => state > 0 && completionTime != null;
}

class Fleet {
  const Fleet({
    required this.id,
    required this.name,
    this.shipIds = const <int>[],
    this.slotCount = 6,
    this.mission = const FleetMission(),
  });

  final int id;
  final String name;
  final List<int> shipIds;
  final int slotCount;
  final FleetMission mission;
}

class RepairDock {
  const RepairDock({
    required this.id,
    this.state = 0,
    this.shipId = 0,
    this.completionTime,
    this.fuelCost = 0,
    this.steelCost = 0,
  });

  final int id;
  final int state;
  final int shipId;
  final DateTime? completionTime;
  final int fuelCost;
  final int steelCost;

  bool get isRepairing => state > 0 && shipId > 0;
  bool get isLocked => state < 0;
}

class ConstructionDock {
  const ConstructionDock({
    required this.id,
    this.state = 0,
    this.createdShipMasterId = 0,
    this.completionTime,
    this.startedAt,
    this.fuel = 0,
    this.ammunition = 0,
    this.steel = 0,
    this.bauxite = 0,
    this.developmentMaterial = 0,
  });

  final int id;
  final int state;
  final int createdShipMasterId;
  final DateTime? completionTime;
  final DateTime? startedAt;
  final int fuel;
  final int ammunition;
  final int steel;
  final int bauxite;
  final int developmentMaterial;

  bool get isBuilding => state > 0;
  bool get isLocked => state < 0;
  bool isCompletedAt(DateTime now) {
    if (!isBuilding || createdShipMasterId <= 0) {
      return false;
    }
    if (state == 3) {
      return true;
    }
    return completionTime != null && !now.isBefore(completionTime!);
  }

  bool get isLargeConstruction =>
      fuel >= 1000 || ammunition >= 1000 || steel >= 1000 || bauxite >= 1000;
}

class GameQuest {
  const GameQuest({
    required this.id,
    required this.title,
    required this.detail,
    required this.category,
    required this.type,
    required this.state,
    required this.progressFlag,
    this.materials = const <int>[0, 0, 0, 0],
    this.updatedAt,
  });

  final int id;
  final String title;
  final String detail;
  final int category;
  final int type;
  final int state;
  final int progressFlag;
  final List<int> materials;
  final DateTime? updatedAt;

  bool get isAccepted => state >= 2;
  bool get isCompleted => state == 3;

  String get progressPercentLabel {
    if (isCompleted) {
      return '100%';
    }
    return switch (progressFlag) {
      1 => '50%+',
      2 => '80%+',
      _ => '＜50%',
    };
  }

  String get progressLabel {
    if (isCompleted) {
      return '已完成';
    }
    return switch (progressFlag) {
      1 => '服务器进度 50% 以上',
      2 => '服务器进度 80% 以上',
      _ => '进行中',
    };
  }

  String get categoryLabel => switch (category) {
    1 => '编成',
    2 || 8 || 9 || 10 => '出击',
    3 => '演习',
    4 => '远征',
    5 => '补给 / 入渠',
    6 || 11 => '工厂',
    7 => '改',
    _ => '其他',
  };

  Color get categoryColor => switch (category) {
    1 => const Color(0xff19BB2E),
    2 || 8 || 9 || 10 => const Color(0xffe73939),
    3 => const Color(0xff87da61),
    4 => const Color(0xff16C2A3),
    5 => const Color(0xffE2C609),
    6 || 11 => const Color(0xff805444),
    7 => const Color(0xffc792e8),
    _ => const Color(0xffffffff),
  };

  String getPeriodLabel(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return switch (type) {
      1 => localizations?.questDaily ?? '日常',
      2 => localizations?.questWeekly ?? '周常',
      3 => localizations?.questMonthly ?? '月常',
      4 => localizations?.questOneTime ?? '单',
      5 => localizations?.questOther ?? '其他',
      _ => localizations?.questUnknown ?? '期',
    };
  }

  Color get periodColor => switch (type) {
    1 => const Color(0xff4B9FD5), // 日常 (Daily) - Blue
    2 => const Color(0xffDB6565), // 周常 (Weekly) - Red
    3 => const Color(0xff80C16B), // 月常 (Monthly) - Green
    4 => const Color(0xffE0C345), // 单 (One-time) - Yellow
    5 => const Color(0xffE58C4F), // 其他 (Other) - Orange
    _ => const Color(0xff5c6c70), // 期 (Unknown) - Gray
  };

  bool isExpired(DateTime now) {
    if (updatedAt == null) return false;

    // Kancolle resets happen at 5:00 AM JST (UTC+9)
    // To align this boundary to 00:00, we use a +4 hour offset from UTC.
    // 5:00 JST = 20:00 UTC (previous day). 20:00 + 4 hours = 24:00 = 00:00!
    const int fourHours = 4 * 60 * 60 * 1000;
    const int oneDay = 24 * 60 * 60 * 1000;
    const int oneWeek = 7 * oneDay;

    final t1 = updatedAt!.millisecondsSinceEpoch;
    final t2 = now.millisecondsSinceEpoch;

    bool isDifferentDay() {
      final day1 = (t1 + fourHours) ~/ oneDay;
      final day2 = (t2 + fourHours) ~/ oneDay;
      return day1 != day2;
    }

    bool isDifferentWeek() {
      // Jan 1 1970 is Thursday. To align week boundary to Monday 05:00 JST, subtract 4 days padding.
      final week1 = (t1 + fourHours - (4 * oneDay)) ~/ oneWeek;
      final week2 = (t2 + fourHours - (4 * oneDay)) ~/ oneWeek;
      return week1 != week2;
    }

    bool isDifferentMonth() {
      final date1 = DateTime.fromMillisecondsSinceEpoch(
        t1 + fourHours,
        isUtc: true,
      );
      final date2 = DateTime.fromMillisecondsSinceEpoch(
        t2 + fourHours,
        isUtc: true,
      );
      return date1.month != date2.month || date1.year != date2.year;
    }

    if (!isDifferentDay()) return false;

    // Daily quests (api_type == 1) or specific bd1/bd2 daily IDs
    if (type == 1 || id == 211 || id == 212) return true;

    // Weekly quests
    if (type == 2 && isDifferentWeek()) return true;

    // Monthly quests
    if (type == 3 && isDifferentMonth()) return true;

    return false;
  }
}

class ShipEquipment {
  const ShipEquipment({required this.owned, required this.master});

  final OwnedSlotItem owned;
  final MasterSlotItem? master;
}

enum CombinedFleetType {
  none(0, '出击舰队'),
  carrierTaskForce(1, '空母机动部队'),
  surfaceTaskForce(2, '水上打击部队'),
  transportEscort(3, '输送护卫部队');

  const CombinedFleetType(this.apiValue, this.label);

  final int apiValue;
  final String label;

  static CombinedFleetType fromApiValue(int value) {
    for (final type in values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return CombinedFleetType.none;
  }
}

class GameState {
  const GameState({
    this.admiralLevel = 0,
    this.resources = const <GameResourceType, int>{},
    this.masterShipTypes = const <int, MasterShipType>{},
    this.masterShips = const <int, MasterShip>{},
    this.masterSlotItems = const <int, MasterSlotItem>{},
    this.masterMissions = const <int, MasterMission>{},
    this.ships = const <int, OwnedShip>{},
    this.slotItems = const <int, OwnedSlotItem>{},
    this.fleets = const <Fleet>[],
    this.repairDocks = const <RepairDock>[],
    this.constructionDocks = const <ConstructionDock>[],
    this.quests = const <int, GameQuest>{},
    this.combinedFleetType = CombinedFleetType.none,
    this.serverOrigin = '',
    this.hasMasterData = false,
    this.hasPortData = false,
    this.combatState = CombatState.empty,
    this.updatedAt,
  });

  static const GameState empty = GameState();

  final int admiralLevel;
  final Map<GameResourceType, int> resources;
  final Map<int, MasterShipType> masterShipTypes;
  final Map<int, MasterShip> masterShips;
  final Map<int, MasterSlotItem> masterSlotItems;
  final Map<int, MasterMission> masterMissions;
  final Map<int, OwnedShip> ships;
  final Map<int, OwnedSlotItem> slotItems;
  final List<Fleet> fleets;
  final List<RepairDock> repairDocks;
  final List<ConstructionDock> constructionDocks;
  final Map<int, GameQuest> quests;
  final CombinedFleetType combinedFleetType;
  final String serverOrigin;
  final bool hasMasterData;
  final bool hasPortData;
  final CombatState combatState;
  final DateTime? updatedAt;

  int? resource(GameResourceType type) => resources[type];

  List<OwnedShip> shipsForFleet(int fleetId) {
    Fleet? fleet;
    for (final candidate in fleets) {
      if (candidate.id == fleetId) {
        fleet = candidate;
        break;
      }
    }
    if (fleet == null) {
      return const <OwnedShip>[];
    }
    return <OwnedShip>[for (final id in fleet.shipIds) ?ships[id]];
  }

  MasterShip? masterForShip(OwnedShip ship) => masterShips[ship.masterId];

  MasterShipType? typeForShip(OwnedShip ship) {
    final master = masterForShip(ship);
    return master == null ? null : masterShipTypes[master.shipTypeId];
  }

  List<ShipEquipment> equipmentForShip(OwnedShip ship) {
    final ids = <int>[
      ...ship.slotIds.where((id) => id > 0),
      if (ship.extraSlotId > 0) ship.extraSlotId,
    ];
    return <ShipEquipment>[
      for (final id in ids)
        if (slotItems[id] case final owned?)
          ShipEquipment(owned: owned, master: masterSlotItems[owned.masterId]),
    ];
  }

  GameState copyWith({
    int? admiralLevel,
    Map<GameResourceType, int>? resources,
    Map<int, MasterShipType>? masterShipTypes,
    Map<int, MasterShip>? masterShips,
    Map<int, MasterSlotItem>? masterSlotItems,
    Map<int, MasterMission>? masterMissions,
    Map<int, OwnedShip>? ships,
    Map<int, OwnedSlotItem>? slotItems,
    List<Fleet>? fleets,
    List<RepairDock>? repairDocks,
    List<ConstructionDock>? constructionDocks,
    Map<int, GameQuest>? quests,
    CombinedFleetType? combinedFleetType,
    String? serverOrigin,
    bool? hasMasterData,
    bool? hasPortData,
    CombatState? combatState,
    DateTime? updatedAt,
  }) {
    return GameState(
      admiralLevel: admiralLevel ?? this.admiralLevel,
      resources: resources ?? this.resources,
      masterShipTypes: masterShipTypes ?? this.masterShipTypes,
      masterShips: masterShips ?? this.masterShips,
      masterSlotItems: masterSlotItems ?? this.masterSlotItems,
      masterMissions: masterMissions ?? this.masterMissions,
      ships: ships ?? this.ships,
      slotItems: slotItems ?? this.slotItems,
      fleets: fleets ?? this.fleets,
      repairDocks: repairDocks ?? this.repairDocks,
      constructionDocks: constructionDocks ?? this.constructionDocks,
      quests: quests ?? this.quests,
      combinedFleetType: combinedFleetType ?? this.combinedFleetType,
      serverOrigin: serverOrigin ?? this.serverOrigin,
      hasMasterData: hasMasterData ?? this.hasMasterData,
      hasPortData: hasPortData ?? this.hasPortData,
      combatState: combatState ?? this.combatState,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
