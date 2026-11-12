import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_replay_builder.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

Map<String, dynamic> object(Object? value) =>
    (value as Map).cast<String, dynamic>();
List<dynamic> array(Object? value) => value is List ? value : [];
int integer(Object? value) => value is num ? value.toInt() : 0;

void main() {
  final cases = array(
    jsonDecode(
      File('test/fixtures/battle_detail_poi_3_0_5.json').readAsStringSync(),
    ),
  );
  for (final raw in cases) {
    final c = object(raw);
    test('POI 3.0.5 detail parity: ${c['name']}', () => verifyDetail(c));
  }
  final poiRoot = Platform.environment['YAHAGI_POI_DETAIL_LIB'];
  if (poiRoot != null) {
    test('live POI oracle: complete captured attack streams', () {
      final result = Process.runSync(
        'node',
        [
          'tool/battle_detail_poi_oracle.cjs',
          poiRoot,
          Platform.environment['YAHAGI_POI_BATTLE_FIXTURES'] ?? '-',
          if (Platform.environment['YAHAGI_POI_DETAIL_CAPTURE']
              case final String capture)
            capture,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final oracleCases = array(jsonDecode(result.stdout.toString()));
      final failures = <String>[];
      for (final raw in oracleCases) {
        try {
          verifyDetail(object(raw));
        } catch (error) {
          failures.add('${object(raw)['name']}: $error');
        }
      }
      // ignore: avoid_print
      print(
        'POI detail oracle: ${oracleCases.length} cases, ${failures.length} differences',
      );
      expect(failures, isEmpty);
    });
  }
}

/// Expected attack streams were produced by the unmodified npm POI 3.0.5
/// simulator. Compare the whole stream, not only the eventual sunk counts.
void verifyDetail(Map<String, dynamic> c) {
  final fleets = <List<BattleShipSnapshot>>[];
  final finalHp = <String, int>{};
  final expectedHp = <String, int>{};
  for (var group = 0; group < 4; group++) {
    final ships = <BattleShipSnapshot>[];
    final side = group < 2 ? BattleSide.friend : BattleSide.enemy;
    final role = group.isEven ? BattleFleetRole.main : BattleFleetRole.escort;
    final inputs = array(array(c['fleets'])[group]);
    for (var index = 0; index < inputs.length; index++) {
      if (inputs[index] == null) continue;
      final s = object(inputs[index]);
      final key = '${side.name}:${role.name}:$index';
      ships.add(
        BattleShipSnapshot(
          masterId: integer(s['id']),
          name: key,
          side: side,
          fleetRole: role,
          position: index,
          initialHp: integer(s['initial']),
          currentHp: integer(s['final']),
          maxHp: integer(s['max']),
          hpUnknown: s['max'] is! num || s['initial'] is! num,
          equipmentMasterIds: array(s['items']).map(integer).toList(),
        ),
      );
      finalHp[key] = integer(s['initial']);
      expectedHp[key] = integer(s['final']);
    }
    fleets.add(ships);
  }
  final session = BattleSession(
    id: '${c['name']}',
    context: BattleContext(
      combinedFleetType: CombinedFleetType.fromApiValue(
        integer(c['fleetType']),
      ),
    ),
    startedAt: DateTime(2026),
    friendMain: fleets[0],
    friendEscort: fleets[1],
    enemyMain: fleets[2],
    enemyEscort: fleets[3],
  );
  final npcIds = <int, int>{};
  for (final raw in array(c['packets'])) {
    final packet = object(raw);
    if (packet['api_friendly_info'] is Map) {
      final ids = array(object(packet['api_friendly_info'])['api_ship_id']);
      for (var i = 0; i < ids.length; i++) {
        npcIds[i] = integer(ids[i]);
      }
    }
    session.appendPacket(
      path: '${packet['poi_path']}',
      sequence: session.packets.length,
      capturedAt: DateTime(2026),
      data: packet,
    );
  }
  final detail = const BattleDetailReplayBuilder().build(
    session: session,
    battle: LiveBattle(
      context: session.context,
      friendMain: fleets[0],
      friendEscort: fleets[1],
      enemyMain: fleets[2],
      enemyEscort: fleets[3],
    ),
    completedAt: DateTime(2026),
    gameState: GameState.empty,
  );
  String? identity(
    BattleDetailSide side,
    BattleDetailFleetRole? role,
    int? position,
  ) {
    if (position == null) return null;
    if (side.name == 'npc') return 'npc:${npcIds[position]}:$position';
    return '${side.name}:${role!.name}:$position';
  }

  final actual = <Object?>[];
  // POI 3.0.5 returns Normal for these types. The replay builder tests
  // separately verify Yahagi's labels for them.
  const additionalCiTypes = {
    'NightCarrierCI',
    'DestroyerGunTorpedoRadarCI',
    'DestroyerTorpedoRadarLookoutCI',
    'DestroyerTorpedoLookoutCI',
    'DestroyerTorpedoDrumCI',
    'ZuiunMultiAngle',
    'SeaAirMultiAngle',
  };
  for (final stage in detail.stages) {
    for (final a in stage.attacks) {
      final target = identity(
        a.defenderSide,
        a.defenderRole,
        a.defenderPosition,
      )!;
      if (finalHp.containsKey(target)) finalHp[target] = a.defenderHpAfter;
      actual.add({
        'from': identity(a.attackerSide, a.attackerRole, a.attackerPosition),
        'to': target,
        'before': a.defenderHpBefore,
        'after': a.defenderHpAfter,
        'damage': a.hits.map((h) => h.damage).toList(),
        'hit': a.hits.map((h) => h.kind.name).toList(),
        'type': additionalCiTypes.contains(a.attackTypeCode)
            ? 'Normal'
            : a.attackTypeCode,
        'useItem': const {'应急修理要员': 42, '应急修理女神': 43}[a.damageControlName],
      });
    }
  }
  expect(
    actual,
    c['attacks'],
    reason: '${c['name']}: complete ordered attack stream',
  );
  expect(finalHp, expectedHp, reason: '${c['name']}: replay ending HP');
  for (var group = 0; group < 4; group++) {
    for (final ship in detail.fleets[group].ships) {
      final expected = object(array(array(c['fleets'])[group])[ship.position]);
      expect(
        ship.hpUnknown ? null : ship.finalHp,
        expected['final'] is num ? expected['final'] : null,
        reason: '${c['name']}: fleet tab ending HP',
      );
      if (expected.containsKey('damageDealt')) {
        expect(
          ship.damageDealt,
          expected['damageDealt'],
          reason: '${c['name']}: fleet damage dealt',
        );
        expect(
          ship.damageReceived,
          expected['damageReceived'],
          reason: '${c['name']}: fleet damage received',
        );
      }
    }
  }
  expect(
    BattleDetailSnapshot.fromJson(detail.toJson()).toJson(),
    detail.toJson(),
    reason: 'stored detail round trip',
  );
}
