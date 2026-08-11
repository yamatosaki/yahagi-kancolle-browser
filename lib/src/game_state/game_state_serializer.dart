import 'dart:convert';
import 'game_state.dart';

class GameStateSerializer {
  static String serialize(GameState state) {
    return jsonEncode({
      'admiralLevel': state.admiralLevel,
      'resources': state.resources.map(
        (k, v) => MapEntry(k.apiId.toString(), v),
      ),
      'useItems': state.useItems.map((k, v) => MapEntry(k.toString(), v)),
      'hasUseItemData': state.hasUseItemData,
      'furnitureCoins': state.furnitureCoins,
      'hasFurnitureCoinData': state.hasFurnitureCoinData,
      'quests': state.quests.map(
        (k, v) => MapEntry(k.toString(), {
          'id': v.id,
          'title': v.title,
          'detail': v.detail,
          'category': v.category,
          'type': v.type,
          'state': v.state,
          'progressFlag': v.progressFlag,
          'materials': v.materials,
          'progressCurrent': v.progressCurrent,
          'progressRequired': v.progressRequired,
          'localCompletionVerified': v.localCompletionVerified,
          'updatedAt': v.updatedAt?.millisecondsSinceEpoch,
        }),
      ),
      'hasQuestData': state.hasQuestData,
      'activeQuestCount': state.activeQuestCount,
      'questCapacity': state.questCapacity,
      'fleets': state.fleets
          .map(
            (f) => {
              'id': f.id,
              'name': f.name,
              'shipIds': f.shipIds,
              'slotCount': f.slotCount,
              'mission': {
                'state': f.mission.state,
                'missionId': f.mission.missionId,
                'completionTime':
                    f.mission.completionTime?.millisecondsSinceEpoch,
              },
            },
          )
          .toList(),
      'repairDocks': state.repairDocks
          .map(
            (r) => {
              'id': r.id,
              'state': r.state,
              'shipId': r.shipId,
              'completionTime': r.completionTime?.millisecondsSinceEpoch,
              'fuelCost': r.fuelCost,
              'steelCost': r.steelCost,
            },
          )
          .toList(),
      'constructionDocks': state.constructionDocks
          .map(
            (c) => {
              'id': c.id,
              'state': c.state,
              'createdShipMasterId': c.createdShipMasterId,
              'completionTime': c.completionTime?.millisecondsSinceEpoch,
              'startedAt': c.startedAt?.millisecondsSinceEpoch,
              'fuel': c.fuel,
              'ammunition': c.ammunition,
              'steel': c.steel,
              'bauxite': c.bauxite,
              'developmentMaterial': c.developmentMaterial,
            },
          )
          .toList(),
      'landBases': state.landBases
          .map(
            (base) => {
              'areaId': base.areaId,
              'baseId': base.baseId,
              'name': base.name,
              'actionKind': base.actionKind,
            },
          )
          .toList(),
      'updatedAt': state.updatedAt?.millisecondsSinceEpoch,
    });
  }

  static GameState deserialize(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return GameState.empty;
      }
      final map = decoded;

      final resources = <GameResourceType, int>{};
      final rawResources = map['resources'];
      if (rawResources is Map) {
        for (final entry in rawResources.entries) {
          final type = GameResourceType.fromApiId(
            int.tryParse('${entry.key}') ?? -1,
          );
          if (type != null && entry.value is int) {
            resources[type] = entry.value as int;
          }
        }
      }

      final useItems = <int, int>{};
      final rawUseItems = map['useItems'];
      if (rawUseItems is Map) {
        for (final entry in rawUseItems.entries) {
          final id = int.tryParse('${entry.key}');
          final count = _int(entry.value);
          if (id != null && id > 0 && count != null) {
            useItems[id] = count.clamp(0, 1 << 31).toInt();
          }
        }
      }

      final quests = <int, GameQuest>{};
      final rawQuests = map['quests'];
      if (rawQuests is Map) {
        for (final entry in rawQuests.entries) {
          final id = int.tryParse('${entry.key}');
          final v = entry.value;
          if (id == null || v is! Map) {
            continue;
          }
          final updatedAt = _int(v['updatedAt']);
          final state = _int(v['state']) ?? 0;
          final progressCurrent = _int(v['progressCurrent']);
          final progressRequired = _int(v['progressRequired']);
          quests[id] = GameQuest(
            id: id,
            title: _string(v['title']),
            detail: _string(v['detail']),
            category: _int(v['category']) ?? 0,
            type: _int(v['type']) ?? 0,
            state: state,
            progressFlag: _int(v['progressFlag']) ?? 0,
            materials: _intList(v['materials']),
            progressCurrent: progressCurrent,
            progressRequired: progressRequired,
            localCompletionVerified: _completionVerification(
              v,
              id: id,
              state: state,
              current: progressCurrent,
              required: progressRequired,
            ),
            updatedAt: updatedAt != null
                ? DateTime.fromMillisecondsSinceEpoch(updatedAt)
                : null,
          );
        }
      }

      final fleets = <Fleet>[];
      final rawFleets = map['fleets'];
      if (rawFleets is List) {
        for (final item in rawFleets) {
          if (item is! Map) {
            continue;
          }
          final mission = item['mission'];
          final completionTime = mission is Map
              ? _int(mission['completionTime'])
              : null;
          fleets.add(
            Fleet(
              id: _int(item['id']) ?? 0,
              name: _string(item['name']),
              shipIds: _intList(item['shipIds']),
              slotCount: _int(item['slotCount']) ?? 0,
              mission: FleetMission(
                state: mission is Map ? _int(mission['state']) ?? 0 : 0,
                missionId: mission is Map ? _int(mission['missionId']) ?? 0 : 0,
                completionTime: completionTime != null
                    ? DateTime.fromMillisecondsSinceEpoch(completionTime)
                    : null,
              ),
            ),
          );
        }
      }

      final repairDocks = <RepairDock>[];
      final rawRepairDocks = map['repairDocks'];
      if (rawRepairDocks is List) {
        for (final item in rawRepairDocks) {
          if (item is! Map) {
            continue;
          }
          final completionTime = _int(item['completionTime']);
          repairDocks.add(
            RepairDock(
              id: _int(item['id']) ?? 0,
              state: _int(item['state']) ?? 0,
              shipId: _int(item['shipId']) ?? 0,
              completionTime: completionTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(completionTime)
                  : null,
              fuelCost: _int(item['fuelCost']) ?? 0,
              steelCost: _int(item['steelCost']) ?? 0,
            ),
          );
        }
      }

      final constructionDocks = <ConstructionDock>[];
      final rawConstructionDocks = map['constructionDocks'];
      if (rawConstructionDocks is List) {
        for (final item in rawConstructionDocks) {
          if (item is! Map) {
            continue;
          }
          final completionTime = _int(item['completionTime']);
          final startedAt = _int(item['startedAt']);
          constructionDocks.add(
            ConstructionDock(
              id: _int(item['id']) ?? 0,
              state: _int(item['state']) ?? 0,
              createdShipMasterId: _int(item['createdShipMasterId']) ?? 0,
              completionTime: completionTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(completionTime)
                  : null,
              startedAt: startedAt != null
                  ? DateTime.fromMillisecondsSinceEpoch(startedAt)
                  : null,
              fuel: _int(item['fuel']) ?? 0,
              ammunition: _int(item['ammunition']) ?? 0,
              steel: _int(item['steel']) ?? 0,
              bauxite: _int(item['bauxite']) ?? 0,
              developmentMaterial: _int(item['developmentMaterial']) ?? 0,
            ),
          );
        }
      }

      final landBases = <LandBaseState>[];
      final rawLandBases = map['landBases'];
      if (rawLandBases is List) {
        for (final item in rawLandBases) {
          if (item is! Map) continue;
          final areaId = _int(item['areaId']) ?? 0;
          final baseId = _int(item['baseId']) ?? 0;
          if (areaId <= 0 || baseId <= 0) continue;
          landBases.add(
            LandBaseState(
              areaId: areaId,
              baseId: baseId,
              name: _string(item['name']),
              actionKind: _int(item['actionKind']) ?? 0,
            ),
          );
        }
      }

      final updatedAt = _int(map['updatedAt']);
      return GameState(
        admiralLevel: _int(map['admiralLevel']) ?? 0,
        resources: resources,
        useItems: useItems,
        hasUseItemData: map['hasUseItemData'] == true || useItems.isNotEmpty,
        furnitureCoins: _int(map['furnitureCoins']) ?? 0,
        hasFurnitureCoinData: map['hasFurnitureCoinData'] == true,
        quests: quests,
        hasQuestData: map['hasQuestData'] == true,
        activeQuestCount: _int(map['activeQuestCount']) ?? 0,
        questCapacity: _int(map['questCapacity']) ?? 5,
        fleets: fleets,
        repairDocks: repairDocks,
        constructionDocks: constructionDocks,
        landBases: landBases,
        updatedAt: updatedAt != null
            ? DateTime.fromMillisecondsSinceEpoch(updatedAt)
            : null,
      );
    } catch (e) {
      return GameState.empty;
    }
  }

  static int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static bool? _completionVerification(
    Map<dynamic, dynamic> map, {
    required int id,
    required int state,
    required int? current,
    required int? required,
  }) {
    if (map.containsKey('localCompletionVerified')) {
      final value = map['localCompletionVerified'];
      if (value is bool) return value;
    }
    if (id == 1101 &&
        state == 2 &&
        current != null &&
        required != null &&
        required > 0 &&
        current >= required) {
      return false;
    }
    return null;
  }

  static List<int> _intList(Object? value) {
    if (value is! List) {
      return const <int>[];
    }
    return <int>[for (final item in value) _int(item) ?? 0];
  }
}
