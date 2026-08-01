import 'dart:convert';
import 'game_state.dart';

class GameStateSerializer {
  static String serialize(GameState state) {
    return jsonEncode({
      'admiralLevel': state.admiralLevel,
      'resources': state.resources.map(
        (k, v) => MapEntry(k.apiId.toString(), v),
      ),
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
          'updatedAt': v.updatedAt?.millisecondsSinceEpoch,
        }),
      ),
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
          quests[id] = GameQuest(
            id: id,
            title: _string(v['title']),
            detail: _string(v['detail']),
            category: _int(v['category']) ?? 0,
            type: _int(v['type']) ?? 0,
            state: _int(v['state']) ?? 0,
            progressFlag: _int(v['progressFlag']) ?? 0,
            materials: _intList(v['materials']),
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

      final updatedAt = _int(map['updatedAt']);
      return GameState(
        admiralLevel: _int(map['admiralLevel']) ?? 0,
        resources: resources,
        quests: quests,
        fleets: fleets,
        repairDocks: repairDocks,
        constructionDocks: constructionDocks,
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

  static List<int> _intList(Object? value) {
    if (value is! List) {
      return const <int>[];
    }
    return <int>[for (final item in value) _int(item) ?? 0];
  }
}
