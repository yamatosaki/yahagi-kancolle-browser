import 'dart:convert';
import 'game_state.dart';
import 'quest_text_normalizer.dart';

class GameStateSerializer {
  static String serialize(GameState state) {
    return jsonEncode({
      'memberId': state.memberId,
      'admiralLevel': state.admiralLevel,
      'resources': state.resources.map(
        (k, v) => MapEntry(k.apiId.toString(), v),
      ),
      'useItems': state.useItems.map((k, v) => MapEntry(k.toString(), v)),
      'hasUseItemData': state.hasUseItemData,
      'furnitureCoins': state.furnitureCoins,
      'hasFurnitureCoinData': state.hasFurnitureCoinData,
      'mapDifficulties': state.mapDifficulties.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'masterMapAreas': state.masterMapAreas.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'memberMapInfos': state.memberMapInfos.map(
        (key, value) => MapEntry(key.toString(), {
          'id': value.id,
          'mapAreaId': value.mapAreaId,
          'mapNo': value.mapNo,
          'name': value.name,
          'operationText': value.operationText,
          'cleared': value.cleared,
          'defeatCount': value.defeatCount,
          'requiredDefeatCount': value.requiredDefeatCount,
          'currentHp': value.currentHp,
          'maxHp': value.maxHp,
          'gaugeType': value.gaugeType,
          'gaugeNum': value.gaugeNum,
          'gaugeMaxNum': value.gaugeMaxNum,
          'selectedRank': value.selectedRank,
          'isEvent': value.isEvent,
        }),
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
              'distanceBase': base.distanceBase,
              'distanceBonus': base.distanceBonus,
              'squadrons': base.squadrons
                  .map(
                    (squadron) => {
                      'squadronId': squadron.squadronId,
                      'state': squadron.state,
                      'slotItemId': squadron.slotItemId,
                      'currentCount': squadron.currentCount,
                      'maxCount': squadron.maxCount,
                      'condition': squadron.condition,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'masterMissions': state.masterMissions.map(
        (k, v) => MapEntry(k.toString(), {
          'id': v.id,
          'name': v.name,
          'durationSeconds': v.duration.inSeconds,
          'displayNumber': v.displayNumber,
          'mapAreaId': v.mapAreaId,
        }),
      ),
      'masterShipTypes': state.masterShipTypes.map(
        (k, v) => MapEntry(k.toString(), {
          'id': v.id,
          'name': v.name,
          'equipTypeIds': v.equipTypeIds.toList(),
        }),
      ),
      'masterShips': state.masterShips.map(
        (k, v) => MapEntry(k.toString(), {
          'id': v.id,
          'name': v.name,
          'shipTypeId': v.shipTypeId,
          'afterShipId': v.afterShipId,
          'buildTimeMinutes': v.buildTimeMinutes,
          'sortNo': v.sortNo,
          'classTypeId': v.classTypeId,
          'equipTypeIds': v.equipTypeIds.toList(),
          'limitedEquipmentIdsByType': v.limitedEquipmentIdsByType.map(
            (typeId, equipmentIds) =>
                MapEntry(typeId.toString(), equipmentIds.toList()),
          ),
        }),
      ),
      'masterSlotItems': state.masterSlotItems.map(
        (k, v) => MapEntry(k.toString(), {
          'id': v.id,
          'name': v.name,
          'sortNo': v.sortNo,
          'type': v.type,
        }),
      ),
      'masterSlotItemTypes': state.masterSlotItemTypes.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'expansionSlotEquipmentTypeIds': state.expansionSlotEquipmentTypeIds
          .toList(),
      'expansionSlotSpecialRules': state.expansionSlotSpecialRules.map(
        (equipmentId, rule) => MapEntry(equipmentId.toString(), {
          'equipmentMasterId': rule.equipmentMasterId,
          'shipMasterIds': rule.shipMasterIds.toList(),
          'classTypeIds': rule.classTypeIds.toList(),
          'shipTypeIds': rule.shipTypeIds.toList(),
          'minimumImprovement': rule.minimumImprovement,
        }),
      ),
      'expansionSlotLimitsByShipId': state.expansionSlotLimitsByShipId.map(
        (shipId, typeIds) => MapEntry(shipId.toString(), typeIds.toList()),
      ),
      'hasEquipmentCompatibilityData': state.hasEquipmentCompatibilityData,
      'ships': state.ships.map(
        (k, v) => MapEntry(k.toString(), {
          'id': v.id,
          'masterId': v.masterId,
          'level': v.level,
          'currentHp': v.currentHp,
          'maxHp': v.maxHp,
          'luck': v.luck,
          'luckMax': v.luckMax,
          'modernization': v.modernization,
          'sallyArea': v.sallyArea,
          'specialEffectKinds': v.specialEffectKinds,
          'maxSlotCounts': v.maxSlotCounts,
          'condition': v.condition,
          'experience': v.experience,
          'nextExperience': v.nextExperience,
          'extraSlotId': v.extraSlotId,
          'repairDurationMilliseconds': v.repairDurationMilliseconds,
          'repairFuelCost': v.repairFuelCost,
          'repairSteelCost': v.repairSteelCost,
        }),
      ),
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
            detail: normalizeQuestDetail(_string(v['detail'])),
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

      final mapDifficulties = <int, int>{};
      final rawMapDifficulties = map['mapDifficulties'];
      if (rawMapDifficulties is Map) {
        for (final entry in rawMapDifficulties.entries) {
          final key = int.tryParse('${entry.key}');
          final rank = _int(entry.value);
          if (key != null && key > 0 && rank != null && rank > 0) {
            mapDifficulties[key] = rank;
          }
        }
      }

      final masterMapAreas = <int, String>{};
      final rawMasterMapAreas = map['masterMapAreas'];
      if (rawMasterMapAreas is Map) {
        for (final entry in rawMasterMapAreas.entries) {
          final id = int.tryParse('${entry.key}');
          if (id != null && id > 0) {
            masterMapAreas[id] = _string(entry.value);
          }
        }
      }

      final memberMapInfos = <int, MemberMapInfo>{};
      final rawMemberMapInfos = map['memberMapInfos'];
      if (rawMemberMapInfos is Map) {
        for (final entry in rawMemberMapInfos.entries) {
          final key = int.tryParse('${entry.key}');
          final item = entry.value;
          if (key == null || key <= 0 || item is! Map) continue;
          final id = _int(item['id']) ?? key;
          final mapAreaId = _int(item['mapAreaId']) ?? (key ~/ 100);
          final mapNo = _int(item['mapNo']) ?? (key % 100);
          memberMapInfos[key] = MemberMapInfo(
            id: id,
            mapAreaId: mapAreaId,
            mapNo: mapNo,
            name: _string(item['name']),
            operationText: _string(item['operationText']),
            cleared: item['cleared'] == true,
            defeatCount: _int(item['defeatCount']),
            requiredDefeatCount: _int(item['requiredDefeatCount']),
            currentHp: _int(item['currentHp']),
            maxHp: _int(item['maxHp']),
            gaugeType: _int(item['gaugeType']),
            gaugeNum: _int(item['gaugeNum']),
            gaugeMaxNum: _int(item['gaugeMaxNum']),
            selectedRank: _int(item['selectedRank']),
            isEvent: item['isEvent'] == true,
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
          final squadrons = <LandBaseSquadronState>[];
          final rawSquadrons = item['squadrons'];
          if (rawSquadrons is List) {
            for (final squadron in rawSquadrons) {
              if (squadron is! Map) continue;
              final squadronId = _int(squadron['squadronId']) ?? 0;
              if (squadronId <= 0) continue;
              squadrons.add(
                LandBaseSquadronState(
                  squadronId: squadronId,
                  state: _int(squadron['state']) ?? 0,
                  slotItemId: _int(squadron['slotItemId']) ?? 0,
                  currentCount: _int(squadron['currentCount']) ?? 0,
                  maxCount: _int(squadron['maxCount']) ?? 0,
                  condition: _int(squadron['condition']) ?? 1,
                ),
              );
            }
          }
          landBases.add(
            LandBaseState(
              areaId: areaId,
              baseId: baseId,
              name: _string(item['name']),
              actionKind: _int(item['actionKind']) ?? 0,
              distanceBase: _int(item['distanceBase']) ?? 0,
              distanceBonus: _int(item['distanceBonus']) ?? 0,
              squadrons: squadrons,
            ),
          );
        }
      }

      final masterMissions = <int, MasterMission>{};
      final rawMasterMissions = map['masterMissions'];
      if (rawMasterMissions is Map) {
        for (final entry in rawMasterMissions.entries) {
          final id = int.tryParse('${entry.key}');
          final v = entry.value;
          if (id != null && id > 0 && v is Map) {
            masterMissions[id] = MasterMission(
              id: id,
              name: _string(v['name']),
              duration: Duration(seconds: _int(v['durationSeconds']) ?? 0),
              displayNumber: _string(v['displayNumber']),
              mapAreaId: _int(v['mapAreaId']) ?? 0,
            );
          }
        }
      }

      final masterShipTypes = <int, MasterShipType>{};
      final rawMasterShipTypes = map['masterShipTypes'];
      if (rawMasterShipTypes is Map) {
        for (final entry in rawMasterShipTypes.entries) {
          final id = int.tryParse('${entry.key}');
          final v = entry.value;
          if (id != null && id > 0 && v is Map) {
            masterShipTypes[id] = MasterShipType(
              id: id,
              name: _string(v['name']),
              equipTypeIds: _positiveIntSet(v['equipTypeIds']),
            );
          }
        }
      }

      final masterShips = <int, MasterShip>{};
      final rawMasterShips = map['masterShips'];
      if (rawMasterShips is Map) {
        for (final entry in rawMasterShips.entries) {
          final id = int.tryParse('${entry.key}');
          final v = entry.value;
          if (id != null && id > 0 && v is Map) {
            masterShips[id] = MasterShip(
              id: id,
              name: _string(v['name']),
              shipTypeId: _int(v['shipTypeId']) ?? 0,
              afterShipId: _int(v['afterShipId']) ?? 0,
              buildTimeMinutes: _int(v['buildTimeMinutes']) ?? 0,
              sortNo: _int(v['sortNo']) ?? 0,
              classTypeId: _int(v['classTypeId']) ?? 0,
              equipTypeIds: _positiveIntSet(v['equipTypeIds']),
              limitedEquipmentIdsByType: _positiveIntSetMap(
                v['limitedEquipmentIdsByType'],
              ),
            );
          }
        }
      }

      final masterSlotItems = <int, MasterSlotItem>{};
      final rawMasterSlotItems = map['masterSlotItems'];
      if (rawMasterSlotItems is Map) {
        for (final entry in rawMasterSlotItems.entries) {
          final id = int.tryParse('${entry.key}');
          final v = entry.value;
          if (id != null && id > 0 && v is Map) {
            masterSlotItems[id] = MasterSlotItem(
              id: id,
              name: _string(v['name']),
              sortNo: _int(v['sortNo']) ?? 0,
              type: _intList(v['type']),
            );
          }
        }
      }

      final masterSlotItemTypes = <int, String>{};
      final rawMasterSlotItemTypes = map['masterSlotItemTypes'];
      if (rawMasterSlotItemTypes is Map) {
        for (final entry in rawMasterSlotItemTypes.entries) {
          final id = int.tryParse('${entry.key}');
          if (id != null && id > 0) {
            masterSlotItemTypes[id] = _string(entry.value);
          }
        }
      }

      final expansionSlotEquipmentTypeIds = _positiveIntSet(
        map['expansionSlotEquipmentTypeIds'],
      );
      final expansionSlotSpecialRules = <int, ExpansionSlotSpecialRule>{};
      final rawExpansionSlotSpecialRules = map['expansionSlotSpecialRules'];
      if (rawExpansionSlotSpecialRules is Map) {
        for (final entry in rawExpansionSlotSpecialRules.entries) {
          final equipmentMasterId = int.tryParse('${entry.key}');
          final v = entry.value;
          if (equipmentMasterId != null && equipmentMasterId > 0 && v is Map) {
            expansionSlotSpecialRules[equipmentMasterId] =
                ExpansionSlotSpecialRule(
                  equipmentMasterId: equipmentMasterId,
                  shipMasterIds: _positiveIntSet(v['shipMasterIds']),
                  classTypeIds: _positiveIntSet(v['classTypeIds']),
                  shipTypeIds: _positiveIntSet(v['shipTypeIds']),
                  minimumImprovement: (_int(v['minimumImprovement']) ?? 0)
                      .clamp(0, 10),
                );
          }
        }
      }
      final expansionSlotLimitsByShipId = _positiveIntSetMap(
        map['expansionSlotLimitsByShipId'],
      );

      final ships = <int, OwnedShip>{};
      final rawShips = map['ships'];
      if (rawShips is Map) {
        for (final entry in rawShips.entries) {
          final id = int.tryParse('${entry.key}');
          final v = entry.value;
          if (id != null && id > 0 && v is Map) {
            ships[id] = OwnedShip(
              id: id,
              masterId: _int(v['masterId']) ?? 0,
              level: _int(v['level']) ?? 1,
              currentHp: _int(v['currentHp']) ?? 0,
              maxHp: _int(v['maxHp']) ?? 0,
              luck: _int(v['luck']) ?? 0,
              luckMax: _int(v['luckMax']) ?? 0,
              sallyArea: _int(v['sallyArea']) ?? 0,
              specialEffectKinds: v['specialEffectKinds'] is List
                  ? (v['specialEffectKinds'] as List)
                        .map((value) => _int(value) ?? 0)
                        .toList()
                  : const [],
              maxSlotCounts: v['maxSlotCounts'] is List
                  ? (v['maxSlotCounts'] as List)
                        .map((value) => _int(value) ?? 0)
                        .toList()
                  : const [],
              modernization: v['modernization'] is List
                  ? (v['modernization'] as List)
                        .map((value) => _int(value) ?? 0)
                        .toList()
                  : const [],
              condition: _int(v['condition']) ?? 49,
              currentFuel: 100,
              currentAmmo: 100,
              experience: _int(v['experience']) ?? 0,
              nextExperience: _int(v['nextExperience']) ?? 0,
              slotIds: const [],
              extraSlotId: _int(v['extraSlotId']) ?? -1,
              repairDurationMilliseconds:
                  _int(v['repairDurationMilliseconds']) ?? 0,
              repairFuelCost: _int(v['repairFuelCost']) ?? 0,
              repairSteelCost: _int(v['repairSteelCost']) ?? 0,
            );
          }
        }
      }

      final updatedAt = _int(map['updatedAt']);
      return GameState(
        memberId: _int(map['memberId']) ?? 0,
        admiralLevel: _int(map['admiralLevel']) ?? 0,
        resources: resources,
        useItems: useItems,
        hasUseItemData: map['hasUseItemData'] == true || useItems.isNotEmpty,
        furnitureCoins: _int(map['furnitureCoins']) ?? 0,
        hasFurnitureCoinData: map['hasFurnitureCoinData'] == true,
        mapDifficulties: mapDifficulties,
        masterMapAreas: masterMapAreas,
        memberMapInfos: memberMapInfos,
        quests: quests,
        hasQuestData: map['hasQuestData'] == true,
        activeQuestCount: _int(map['activeQuestCount']) ?? 0,
        questCapacity: _int(map['questCapacity']) ?? 5,
        fleets: fleets,
        repairDocks: repairDocks,
        constructionDocks: constructionDocks,
        landBases: landBases,
        masterMissions: masterMissions,
        masterShipTypes: masterShipTypes,
        masterShips: masterShips,
        masterSlotItems: masterSlotItems,
        masterSlotItemTypes: masterSlotItemTypes,
        expansionSlotEquipmentTypeIds: expansionSlotEquipmentTypeIds,
        expansionSlotSpecialRules: expansionSlotSpecialRules,
        expansionSlotLimitsByShipId: expansionSlotLimitsByShipId,
        hasEquipmentCompatibilityData:
            map['hasEquipmentCompatibilityData'] == true,
        ships: ships,
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

  static Set<int> _positiveIntSet(Object? value) =>
      Set<int>.unmodifiable(_intList(value).where((item) => item > 0));

  static Map<int, Set<int>> _positiveIntSetMap(Object? value) {
    if (value is! Map) return const <int, Set<int>>{};
    final result = <int, Set<int>>{};
    for (final entry in value.entries) {
      final id = int.tryParse('${entry.key}') ?? 0;
      if (id <= 0 || entry.value is! List) continue;
      result[id] = _positiveIntSet(entry.value);
    }
    return Map<int, Set<int>>.unmodifiable(result);
  }
}
