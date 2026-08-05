import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_parser.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, child) => MapEntry(key.toString(), child))
    : const <String, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];

int _int(Object? value) => value is num ? value.toInt() : 0;

List<BattleShipSnapshot> _friendFleet(Object? value, BattleFleetRole role) {
  final ships = _list(value);
  return <BattleShipSnapshot>[
    for (var position = 0; position < ships.length; position++)
      if (_map(ships[position]) case final ship when ship.isNotEmpty)
        BattleShipSnapshot(
          masterId: _int(ship['api_ship_id']),
          ownedShipId: _int(ship['api_id']),
          name: 'friend-${ship['api_ship_id']}',
          side: BattleSide.friend,
          fleetRole: role,
          position: position,
          initialHp: _int(ship['api_nowhp']),
          maxHp: _int(ship['api_maxhp']),
          currentHp: _int(ship['api_nowhp']),
          equipmentMasterIds: <int>[
            for (final raw in _list(ship['poi_slot']))
              if (_int(_map(raw)['api_slotitem_id']) > 0)
                _int(_map(raw)['api_slotitem_id']),
            if (_int(_map(ship['poi_slot_ex'])['api_slotitem_id']) > 0)
              _int(_map(ship['poi_slot_ex'])['api_slotitem_id']),
          ],
        ),
  ];
}

List<BattleShipSnapshot> _enemyFleet(
  Map<String, Object?> packet,
  String idsKey,
  String hpKey,
  String maxHpKey,
  BattleFleetRole role,
) {
  final ids = _list(packet[idsKey]);
  final hp = _list(packet[hpKey]);
  final maxHp = _list(packet[maxHpKey]);
  return <BattleShipSnapshot>[
    for (var position = 0; position < ids.length; position++)
      if (_int(ids[position]) > 0)
        BattleShipSnapshot(
          masterId: _int(ids[position]),
          name: 'enemy-${ids[position]}',
          side: BattleSide.enemy,
          fleetRole: role,
          position: position,
          initialHp: position < hp.length ? _int(hp[position]) : 0,
          maxHp: position < maxHp.length ? _int(maxHp[position]) : 0,
          currentHp: position < hp.length ? _int(hp[position]) : 0,
        ),
  ];
}

void main() {
  test('poi 303-fixture corpus matches authoritative sink results', () {
    final rootPath = Platform.environment['YAHAGI_POI_BATTLE_FIXTURES'];
    if (rootPath == null || rootPath.isEmpty) {
      markTestSkipped(
        'Set YAHAGI_POI_BATTLE_FIXTURES to poi-lib-battle fixtures.',
      );
      return;
    }
    final root = Directory(rootPath);
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(303));

    for (final file in files) {
      final battle = _map(jsonDecode(file.readAsStringSync()));
      final fleet = _map(battle['fleet']);
      var friendMain = _friendFleet(fleet['main'], BattleFleetRole.main);
      var friendEscort = _friendFleet(fleet['escort'], BattleFleetRole.escort);
      var enemyMain = <BattleShipSnapshot>[];
      var enemyEscort = <BattleShipSnapshot>[];
      Map<String, Object?>? resultPacket;

      for (final rawPacket in _list(battle['packet'])) {
        final packet = _map(rawPacket);
        final path = packet['poi_path']?.toString() ?? '';
        if (path.endsWith('battleresult') || path.endsWith('battle_result')) {
          resultPacket = packet;
          continue;
        }
        if (!path.contains('battle')) continue;
        if (enemyMain.isEmpty) {
          enemyMain = _enemyFleet(
            packet,
            'api_ship_ke',
            'api_e_nowhps',
            'api_e_maxhps',
            BattleFleetRole.main,
          );
          enemyEscort = _enemyFleet(
            packet,
            'api_ship_ke_combined',
            'api_e_nowhps_combined',
            'api_e_maxhps_combined',
            BattleFleetRole.escort,
          );
        }
        final parsed = BattleDamageParser().apply(
          data: packet,
          friendMain: friendMain,
          friendEscort: friendEscort,
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
          path: path,
        );
        friendMain = parsed.friendMain;
        friendEscort = parsed.friendEscort;
        enemyMain = parsed.enemyMain;
        enemyEscort = parsed.enemyEscort;
      }

      for (final ship in <BattleShipSnapshot>[
        ...friendMain,
        ...friendEscort,
        ...enemyMain,
        ...enemyEscort,
      ]) {
        expect(
          ship.currentHp,
          inInclusiveRange(0, ship.maxHp),
          reason: file.path,
        );
      }
      if (resultPacket case final result?) {
        final sunk = <BattleShipSnapshot>[
          ...enemyMain,
          ...enemyEscort,
        ].where((ship) => ship.isSunk).length;
        if (result['api_dests'] is num) {
          expect(sunk, _int(result['api_dests']), reason: file.path);
        }
        if (result['api_destsf'] is num && enemyMain.isNotEmpty) {
          expect(
            enemyMain.first.isSunk ? 1 : 0,
            _int(result['api_destsf']),
            reason: file.path,
          );
        }
      }
    }
  });
}
