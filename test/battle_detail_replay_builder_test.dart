import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_replay_builder.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test(
    'replay keeps multi-hit HP and enemy attack against friendly escort',
    () {
      final friendMain = <BattleShipSnapshot>[
        ship('大和改二重', BattleSide.friend, BattleFleetRole.main, hp: 100),
      ];
      final friendEscort = <BattleShipSnapshot>[
        ship('矢矧改二乙', BattleSide.friend, BattleFleetRole.escort, hp: 60),
      ];
      final enemyMain = <BattleShipSnapshot>[
        ship('战舰栖姬', BattleSide.enemy, BattleFleetRole.main, hp: 200),
      ];
      final enemyEscort = <BattleShipSnapshot>[
        ship('重巡ネ级', BattleSide.enemy, BattleFleetRole.escort, hp: 80),
      ];
      final session =
          BattleSession(
            id: 'battle-1',
            context: const BattleContext(
              mapAreaId: 62,
              mapInfoNo: 5,
              node: 48,
              combinedFleetType: CombinedFleetType.surfaceTaskForce,
            ),
            startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
            friendMain: friendMain,
            friendEscort: friendEscort,
            enemyMain: enemyMain,
            enemyEscort: enemyEscort,
          )..appendPacket(
            path: '/kcsapi/api_req_combined_battle/each_battle',
            sequence: 1,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1100),
            data: <String, Object?>{
              'api_hougeki1': <String, Object?>{
                'api_at_eflag': <int>[0, 1],
                'api_at_list': <int>[0, 6],
                'api_df_list': <Object?>[
                  <int>[0, 0],
                  <int>[6],
                ],
                'api_damage': <Object?>[
                  <num>[40.9, 20.8],
                  <num>[15.9],
                ],
                'api_cl_list': <Object?>[
                  <int>[1, 2],
                  <int>[2],
                ],
                'api_at_type': <int>[2, 0],
              },
            },
          );
      final battle = LiveBattle(
        context: session.context,
        friendMain: friendMain,
        friendEscort: friendEscort,
        enemyMain: enemyMain,
        enemyEscort: enemyEscort,
        rank: BattleRank.s,
        enemyFleetName: '深海联合舰队',
      );

      final detail = const BattleDetailReplayBuilder().build(
        session: session,
        battle: battle,
        completedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        gameState: GameState.empty,
      );

      expect(detail.fleets, hasLength(4));
      final stage = detail.stages.single;
      expect(stage.title, '第一炮击战');
      expect(stage.attacks, hasLength(2));

      final ours = stage.attacks.first;
      expect(ours.attackerName, '大和改二重');
      expect(ours.defenderName, '战舰栖姬');
      expect(ours.hits.map((hit) => hit.damage), <int>[40, 20]);
      expect(ours.hits.map((hit) => hit.hpAfter), <int>[160, 140]);
      expect(ours.hits.last.kind, BattleDetailHitKind.critical);

      final enemy = stage.attacks.last;
      expect(enemy.attackerSide, BattleDetailSide.enemy);
      expect(enemy.attackerRole, BattleDetailFleetRole.escort);
      expect(enemy.attackerName, '重巡ネ级');
      expect(enemy.defenderRole, BattleDetailFleetRole.escort);
      expect(enemy.defenderName, '矢矧改二乙');
      expect(enemy.defenderHpBefore, 60);
      expect(enemy.defenderHpAfter, 45);
    },
  );

  test('replay records a miss without reducing HP', () {
    final friend = <BattleShipSnapshot>[
      ship('雪风改二', BattleSide.friend, BattleFleetRole.main, hp: 35),
    ];
    final enemy = <BattleShipSnapshot>[
      ship('驱逐イ级', BattleSide.enemy, BattleFleetRole.main, hp: 20),
    ];
    final session =
        BattleSession(
          id: 'battle-2',
          context: const BattleContext(mapAreaId: 1, mapInfoNo: 1, node: 1),
          startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          friendMain: friend,
          enemyMain: enemy,
        )..appendPacket(
          path: '/kcsapi/api_req_sortie/battle',
          sequence: 1,
          capturedAt: DateTime.fromMillisecondsSinceEpoch(1100),
          data: <String, Object?>{
            'api_hougeki1': <String, Object?>{
              'api_at_eflag': <int>[0],
              'api_at_list': <int>[0],
              'api_df_list': <Object?>[
                <int>[0],
              ],
              'api_damage': <Object?>[
                <num>[0],
              ],
              'api_cl_list': <Object?>[
                <int>[0],
              ],
            },
          },
        );

    final detail = const BattleDetailReplayBuilder().build(
      session: session,
      battle: LiveBattle(
        context: session.context,
        friendMain: friend,
        enemyMain: enemy,
      ),
      completedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      gameState: GameState.empty,
    );

    final attack = detail.stages.single.attacks.single;
    expect(attack.hits.single.kind, BattleDetailHitKind.miss);
    expect(attack.defenderHpBefore, 20);
    expect(attack.defenderHpAfter, 20);
  });

  for (final (night, expectedTypes) in [
    (
      false,
      {6: 'PrCI', 7: 'CVCI', 200: 'ZuiunMultiAngle', 201: 'SeaAirMultiAngle'},
    ),
    (
      true,
      {
        6: 'NightCarrierCI',
        7: 'DestroyerGunTorpedoRadarCI',
        8: 'DestroyerTorpedoRadarLookoutCI',
        9: 'DestroyerTorpedoLookoutCI',
        10: 'DestroyerTorpedoDrumCI',
        11: 'DestroyerGunTorpedoRadarCI',
        12: 'DestroyerTorpedoRadarLookoutCI',
        13: 'DestroyerTorpedoLookoutCI',
        14: 'DestroyerTorpedoDrumCI',
        15: 'Normal',
        200: 'Zuiyun_Night_Attack',
      },
    ),
  ]) {
    test('replay keeps ${night ? 'night' : 'day'} attack type codes', () {
      final friend = [
        ship('我方舰', BattleSide.friend, BattleFleetRole.main, hp: 100),
      ];
      final enemy = [
        ship('敌方舰', BattleSide.enemy, BattleFleetRole.main, hp: 100),
      ];
      final types = expectedTypes.keys.toList();
      final sides = [for (var i = 0; i < types.length; i++) i % 2];
      final hitCounts = [
        for (final type in types)
          night && (type == 200 || (type >= 11 && type <= 14)) ? 2 : 1,
      ];
      final now = DateTime.fromMillisecondsSinceEpoch(1000);
      final session =
          BattleSession(
            id: 'attack-types',
            context: const BattleContext(mapAreaId: 1, mapInfoNo: 1, node: 1),
            startedAt: now,
            friendMain: friend,
            enemyMain: enemy,
          )..appendPacket(
            path: night
                ? '/kcsapi/api_req_battle_midnight/battle'
                : '/kcsapi/api_req_sortie/battle',
            sequence: 1,
            capturedAt: now,
            data: {
              (night ? 'api_hougeki' : 'api_hougeki1'): {
                'api_at_eflag': sides,
                'api_at_list': List.filled(types.length, 0),
                'api_df_list': [
                  for (final count in hitCounts) List.filled(count, 0),
                ],
                'api_damage': [
                  for (final count in hitCounts) List.filled(count, 5),
                ],
                'api_cl_list': [
                  for (final count in hitCounts) List.filled(count, 1),
                ],
                (night ? 'api_sp_list' : 'api_at_type'): types,
              },
            },
          );
      final detail = const BattleDetailReplayBuilder().build(
        session: session,
        battle: LiveBattle(
          context: session.context,
          friendMain: friend,
          enemyMain: enemy,
        ),
        completedAt: now,
        gameState: GameState.empty,
      );

      final attacks = detail.stages.single.attacks;
      expect(attacks.map((attack) => attack.attackTypeCode), [
        for (final code in expectedTypes.values)
          if (code == 'Zuiyun_Night_Attack') ...[code, code] else code,
      ]);
      expect(attacks.take(2).map((attack) => attack.attackerSide), [
        BattleDetailSide.friend,
        BattleDetailSide.enemy,
      ]);
      if (night) {
        expect(attacks[5].hits.map((hit) => hit.damage), [5, 5]);
        expect(attacks[5].defenderHpBefore - attacks[5].defenderHpAfter, 10);
      }
    });
  }

  test(
    'combined night specials keep both sides on their own fleet indices',
    () {
      final detail = replayPacket(
        '/kcsapi/api_req_combined_battle/ec_midnight_battle',
        {
          'api_hougeki': {
            'api_at_eflag': [1, 0, 1],
            'api_at_list': [0, 0, 6],
            'api_sp_list': [200, 104, 200],
            'api_df_list': [
              [6, 7],
              [0, 1],
              [6, 7],
            ],
            'api_damage': [
              [7, 11],
              [13, 17],
              [19, 0],
            ],
            'api_cl_list': [
              [2, 1],
              [1, 1],
              [1, 0],
            ],
          },
        },
        friendMain: [
          ship('我方主队', BattleSide.friend, BattleFleetRole.main, hp: 100),
        ],
        friendEscort: [
          ship('我方护卫一', BattleSide.friend, BattleFleetRole.escort, hp: 100),
          ship(
            '我方护卫二',
            BattleSide.friend,
            BattleFleetRole.escort,
            position: 1,
            hp: 100,
          ),
        ],
        enemyMain: [
          ship('敌方主队一', BattleSide.enemy, BattleFleetRole.main, hp: 100),
          ship(
            '敌方主队二',
            BattleSide.enemy,
            BattleFleetRole.main,
            position: 1,
            hp: 100,
          ),
        ],
        enemyEscort: [
          ship('敌方护卫一', BattleSide.enemy, BattleFleetRole.escort, hp: 100),
        ],
      );

      final attacks = detail.stages.single.attacks;
      expect(
        attacks.map(
          (attack) => (
            attack.attackerName,
            attack.attackerRole,
            attack.defenderName,
            attack.defenderHpBefore,
            attack.defenderHpAfter,
          ),
        ),
        [
          ('敌方主队一', BattleDetailFleetRole.main, '我方护卫一', 100, 93),
          ('敌方主队一', BattleDetailFleetRole.main, '我方护卫二', 100, 89),
          ('我方护卫一', BattleDetailFleetRole.escort, '敌方主队一', 100, 87),
          ('我方护卫二', BattleDetailFleetRole.escort, '敌方主队二', 100, 83),
          ('敌方护卫一', BattleDetailFleetRole.escort, '我方护卫一', 93, 74),
          ('敌方护卫一', BattleDetailFleetRole.escort, '我方护卫二', 89, 89),
        ],
      );
      expect(attacks.map((attack) => attack.attackTypeCode), [
        'Zuiyun_Night_Attack',
        'Zuiyun_Night_Attack',
        'Kongo_Class_Kaini_C',
        'Kongo_Class_Kaini_C',
        'Zuiyun_Night_Attack',
        'Zuiyun_Night_Attack',
      ]);
      expect(attacks.last.hits.single.kind, BattleDetailHitKind.miss);
    },
  );

  test('friendly fleet CI and enemy counterattack keep their own HP', () {
    final detail = replayPacket(
      '/kcsapi/api_req_battle_midnight/battle',
      {
        'api_friendly_info': {
          'api_ship_id': [501],
          'api_nowhps': [50],
          'api_maxhps': [50],
        },
        'api_friendly_battle': {
          'api_hougeki': {
            'api_at_eflag': [0, 1],
            'api_at_list': [0, 0],
            'api_sp_list': [6, 3],
            'api_df_list': [
              [0],
              [0, 0],
            ],
            'api_damage': [
              [15],
              [0, 9],
            ],
            'api_cl_list': [
              [1],
              [0, 1],
            ],
          },
        },
        'api_hougeki': {
          'api_at_eflag': [0],
          'api_at_list': [0],
          'api_sp_list': [1],
          'api_df_list': [
            [0, 0],
          ],
          'api_damage': [
            [0, 5],
          ],
          'api_cl_list': [
            [1, 1],
          ],
        },
      },
      friendMain: [
        ship('我方舰', BattleSide.friend, BattleFleetRole.main, hp: 100),
      ],
      enemyMain: [ship('敌方舰', BattleSide.enemy, BattleFleetRole.main, hp: 100)],
    );

    expect(detail.stages.map((stage) => stage.title), ['友军舰队', '夜战']);
    final npc = detail.stages.first.attacks.first;
    expect(
      (npc.attackerSide, npc.defenderSide, npc.attackTypeCode),
      (BattleDetailSide.npc, BattleDetailSide.enemy, 'NightCarrierCI'),
    );
    expect(npc.defenderHpAfter, 85);
    final counter = detail.stages.first.attacks.last;
    expect(
      (counter.attackerSide, counter.defenderSide, counter.attackTypeCode),
      (BattleDetailSide.enemy, BattleDetailSide.npc, 'TTCI'),
    );
    expect(counter.hits.map((hit) => hit.hpAfter), [50, 41]);
    expect(counter.hits.first.kind, BattleDetailHitKind.miss);
    final followUp = detail.stages.last.attacks.single;
    expect(
      (
        followUp.attackerName,
        followUp.defenderHpBefore,
        followUp.defenderHpAfter,
      ),
      ('我方舰', 85, 80),
    );
    expect(followUp.hits.first.kind, BattleDetailHitKind.hit);
  });

  test(
    'legacy shelling uses target indices for sides and keeps missing types normal',
    () {
      final detail = replayPacket(
        '/kcsapi/api_req_sortie/battle',
        {
          'api_hougeki1': {
            'api_at_list': [-1, 0, 2, 1],
            'api_at_type': [-1, 6, 2],
            'api_df_list': [
              -1,
              [3],
              [0],
              [2],
            ],
            'api_damage': [
              -1,
              [5],
              [7],
              [0],
            ],
            'api_cl_list': [
              -1,
              [1],
              [2],
              [0],
            ],
          },
        },
        friendMain: [
          ship('我方一', BattleSide.friend, BattleFleetRole.main, hp: 100),
          ship(
            '我方二',
            BattleSide.friend,
            BattleFleetRole.main,
            position: 1,
            hp: 100,
          ),
        ],
        enemyMain: [
          ship('敌方一', BattleSide.enemy, BattleFleetRole.main, hp: 100),
          ship(
            '敌方二',
            BattleSide.enemy,
            BattleFleetRole.main,
            position: 1,
            hp: 100,
          ),
        ],
      );

      final attacks = BattleDetailSnapshot.fromJson(
        detail.toJson(),
      ).stages.single.attacks;
      expect(
        attacks.map(
          (attack) => (
            attack.attackerName,
            attack.defenderName,
            attack.attackTypeCode,
            attack.defenderHpAfter,
          ),
        ),
        [
          ('我方一', '敌方二', 'PrCI', 95),
          ('敌方一', '我方一', 'Double', 93),
          ('我方二', '敌方一', 'Normal', 100),
        ],
      );
    },
  );
}

BattleDetailSnapshot replayPacket(
  String path,
  Map<String, Object?> data, {
  required List<BattleShipSnapshot> friendMain,
  required List<BattleShipSnapshot> enemyMain,
  List<BattleShipSnapshot> friendEscort = const [],
  List<BattleShipSnapshot> enemyEscort = const [],
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1000);
  final context = BattleContext(
    mapAreaId: 1,
    mapInfoNo: 1,
    node: 1,
    combinedFleetType: friendEscort.isEmpty
        ? CombinedFleetType.none
        : CombinedFleetType.surfaceTaskForce,
  );
  final session = BattleSession(
    id: 'battle-replay-smoke',
    context: context,
    startedAt: now,
    friendMain: friendMain,
    friendEscort: friendEscort,
    enemyMain: enemyMain,
    enemyEscort: enemyEscort,
  )..appendPacket(path: path, sequence: 1, capturedAt: now, data: data);
  return const BattleDetailReplayBuilder().build(
    session: session,
    battle: LiveBattle(
      context: context,
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
    ),
    completedAt: now,
    gameState: GameState.empty,
  );
}

BattleShipSnapshot ship(
  String name,
  BattleSide side,
  BattleFleetRole role, {
  required int hp,
  int position = 0,
}) => BattleShipSnapshot(
  masterId: name.hashCode,
  name: name,
  side: side,
  fleetRole: role,
  position: position,
  initialHp: hp,
  maxHp: hp,
  currentHp: hp,
);
