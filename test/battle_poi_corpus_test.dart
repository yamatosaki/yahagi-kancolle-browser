import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/yahagi_battle_prediction_engine.dart';

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, child) => MapEntry(key.toString(), child))
    : const <String, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];

int _int(Object? value) => value is num ? value.toInt() : 0;

Map<String, Object?> _loadUpstreamPoiOracle(Directory fixtureRoot) {
  final sourceRoot = fixtureRoot.parent.parent.parent;
  final entry = File('${sourceRoot.path}${Platform.pathSeparator}index.js');
  if (!entry.existsSync()) {
    markTestSkipped('Build poi-lib-battle first with npm run build.');
    return const <String, Object?>{};
  }
  const script = r'''
const fs=require('fs'),path=require('path'),lib=require(process.argv[1]);
const root=process.argv[2], out={};
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){
  const p=path.join(dir,e.name); if(e.isDirectory()) walk(p); else if(p.endsWith('.json')){
    const j=JSON.parse(fs.readFileSync(p,'utf8'));
    const prediction={...j,packet:j.packet.filter(v=>
      !v.poi_path.endsWith('battleresult')&&!v.poi_path.endsWith('battle_result'))};
    const s=lib.Simulator.auto(new lib.Battle(prediction),{usePoiAPI:false});
    const hp=x=>(x||[]).filter(Boolean).map(v=>v.nowHP);
    out[path.relative(root,p).replaceAll('\\','/')]={
      friend:[...hp(s.mainFleet),...hp(s.escortFleet)],
      enemy:[...hp(s.enemyFleet),...hp(s.enemyEscort)],
      rank:s.result.rank,mvp:s.result.mvp
    };
  }
}}
walk(root); process.stdout.write(JSON.stringify(out));
''';
  final result = Process.runSync('node', <String>[
    '-e',
    script,
    entry.path,
    fixtureRoot.path,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return _map(jsonDecode(result.stdout.toString()));
}

List<int> _predictedMvp(
  List<BattleShipSnapshot> main,
  List<BattleShipSnapshot> escort,
) {
  int best(List<BattleShipSnapshot> ships) {
    var position = -1;
    var damage = -1;
    for (var index = 0; index < ships.length; index++) {
      if (ships[index].damageDealt > damage) {
        damage = ships[index].damageDealt;
        position = index;
      }
    }
    return position;
  }

  return <int>[best(main), best(escort)];
}

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
    final upstream = _loadUpstreamPoiOracle(root);
    expect(upstream, hasLength(303));

    for (final file in files) {
      final battle = _map(jsonDecode(file.readAsStringSync()));
      final fleet = _map(battle['fleet']);
      var friendMain = _friendFleet(fleet['main'], BattleFleetRole.main);
      var friendEscort = _friendFleet(fleet['escort'], BattleFleetRole.escort);
      var enemyMain = <BattleShipSnapshot>[];
      var enemyEscort = <BattleShipSnapshot>[];
      Map<String, Object?>? resultPacket;
      PoiBattlePredictionEngine? engine;
      YahagiBattlePredictionEngine? yahagiEngine;
      BattlePrediction? yahagiPrediction;
      BattleRank predictedRank = BattleRank.unknown;

      for (final rawPacket in _list(battle['packet'])) {
        final packet = _map(rawPacket);
        final path = packet['poi_path']?.toString() ?? '';
        if (path.endsWith('battleresult') || path.endsWith('battle_result')) {
          resultPacket = packet;
          continue;
        }
        if (!path.contains('battle') && !path.contains('ld_shooting')) continue;
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
        engine ??= PoiBattlePredictionEngine(
          friendMain: friendMain,
          friendEscort: friendEscort,
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
        );
        yahagiEngine ??= YahagiBattlePredictionEngine(
          friendMain: friendMain,
          friendEscort: friendEscort,
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
        );
        final parsed = engine.append(path: path, data: packet);
        yahagiPrediction = yahagiEngine.append(path: path, data: packet);
        friendMain = parsed.friendMain;
        friendEscort = parsed.friendEscort;
        enemyMain = parsed.enemyMain;
        enemyEscort = parsed.enemyEscort;
        predictedRank = parsed.rank;
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
        final friendShips = <BattleShipSnapshot>[
          ...friendMain,
          ...friendEscort,
        ];
        final enemyShips = <BattleShipSnapshot>[...enemyMain, ...enemyEscort];
        var officialRank = BattleRank.parse(result['api_win_rank']);
        if (officialRank == BattleRank.s && friendShips.isNotEmpty) {
          final initialHp = friendShips.fold<int>(
            0,
            (sum, ship) => sum + ship.initialHp,
          );
          final currentHp = friendShips.fold<int>(
            0,
            (sum, ship) => sum + ship.currentHp,
          );
          if (currentHp >= initialHp) officialRank = BattleRank.ss;
        }
        expect(
          predictedRank,
          officialRank,
          reason:
              '${file.path} friend=${friendShips.map((ship) => '${ship.initialHp}/${ship.currentHp}').join(',')}',
        );
        final yahagi = yahagiPrediction!;
        expect(
          <int>[
            ...yahagi.friendMain.map((ship) => ship.currentHp),
            ...yahagi.friendEscort.map((ship) => ship.currentHp),
            ...yahagi.enemyMain.map((ship) => ship.currentHp),
            ...yahagi.enemyEscort.map((ship) => ship.currentHp),
          ],
          <int>[
            ...friendMain.map((ship) => ship.currentHp),
            ...friendEscort.map((ship) => ship.currentHp),
            ...enemyMain.map((ship) => ship.currentHp),
            ...enemyEscort.map((ship) => ship.currentHp),
          ],
          reason: '${file.path} final HP differs between engines',
        );
        expect(yahagi.rank, predictedRank, reason: '${file.path} rank differs');
        final relative = file.path
            .substring(root.path.length + 1)
            .replaceAll('\\', '/');
        final oracle = _map(upstream[relative]);
        expect(
          <int>[
            ...friendMain.map((ship) => ship.currentHp),
            ...friendEscort.map((ship) => ship.currentHp),
          ],
          _list(oracle['friend']).map(_int).toList(),
          reason: '${file.path} friend HP differs from upstream POI',
        );
        expect(
          <int>[
            ...enemyMain.map((ship) => ship.currentHp),
            ...enemyEscort.map((ship) => ship.currentHp),
          ],
          _list(oracle['enemy']).map(_int).toList(),
          reason: '${file.path} enemy HP differs from upstream POI',
        );
        expect(
          predictedRank.name.toUpperCase(),
          oracle['rank'],
          reason: '${file.path} rank differs from upstream POI',
        );
        expect(
          _predictedMvp(friendMain, friendEscort),
          _list(oracle['mvp']).map(_int).toList(),
          reason: '${file.path} MVP differs from upstream POI',
        );

        final sunk = <BattleShipSnapshot>[
          ...enemyMain,
          ...enemyEscort,
        ].where((ship) => ship.isSunk).length;
        if (result['api_dests'] is num) {
          expect(
            sunk,
            _int(result['api_dests']),
            reason:
                '${file.path} enemy=${enemyShips.map((ship) => '${ship.fleetRole.name}:${ship.position}:${ship.currentHp}').join(',')}',
          );
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
