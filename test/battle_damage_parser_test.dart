import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_parser.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';

BattleShipSnapshot snapshot({
  required BattleSide side,
  required int position,
  required int hp,
  BattleFleetRole role = BattleFleetRole.main,
}) {
  return BattleShipSnapshot(
    masterId: 100 + position,
    name: '${side.name}-$position',
    side: side,
    fleetRole: role,
    position: position,
    initialHp: hp,
    maxHp: hp,
    currentHp: hp,
  );
}

void main() {
  test('applies shelling and torpedo damage to the correct sides', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_hougeki1': <String, Object?>{
          'api_at_eflag': <int>[0, 1],
          'api_at_list': <int>[0, 0],
          'api_df_list': <Object?>[
            <int>[0],
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[20.9],
            <num>[10.4],
          ],
        },
        'api_raigeki': <String, Object?>{
          'api_fdam': <num>[2.8, 0],
          'api_edam': <num>[0, 5.9],
        },
      },
      friendMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.friend, position: 0, hp: 30),
        snapshot(side: BattleSide.friend, position: 1, hp: 15),
      ],
      enemyMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.enemy, position: 0, hp: 20),
        snapshot(side: BattleSide.enemy, position: 1, hp: 10),
      ],
    );

    expect(result.friendMain.map((ship) => ship.currentHp), <int>[18, 15]);
    expect(result.enemyMain.map((ship) => ship.currentHp), <int>[0, 5]);
    expect(result.friendMain.first.damageDealt, 20);
    expect(result.friendMain.first.damageReceived, 12);
    expect(result.enemyMain[0].damageReceived, 20);
    expect(result.enemyMain[1].damageReceived, 5);
  });

  test('maps combined damage arrays to escort fleets', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_stage3_combined': <String, Object?>{
          'api_fdam': <num>[3],
          'api_edam': <num>[7],
        },
      },
      friendMain: <BattleShipSnapshot>[],
      friendEscort: <BattleShipSnapshot>[
        snapshot(
          side: BattleSide.friend,
          role: BattleFleetRole.escort,
          position: 0,
          hp: 20,
        ),
      ],
      enemyMain: <BattleShipSnapshot>[],
      enemyEscort: <BattleShipSnapshot>[
        snapshot(
          side: BattleSide.enemy,
          role: BattleFleetRole.escort,
          position: 0,
          hp: 15,
        ),
      ],
    );

    expect(result.friendEscort.single.currentHp, 17);
    expect(result.enemyEscort.single.currentHp, 8);
  });

  test('ignores the leading sentinel in real damage arrays', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_raigeki': <String, Object?>{
          'api_fdam': <num>[-1, 2, 0],
          'api_edam': <num>[-1, 0, 5],
        },
      },
      friendMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.friend, position: 0, hp: 30),
        snapshot(side: BattleSide.friend, position: 1, hp: 15),
      ],
      enemyMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.enemy, position: 0, hp: 20),
        snapshot(side: BattleSide.enemy, position: 1, hp: 10),
      ],
    );

    expect(result.friendMain.map((ship) => ship.currentHp), <int>[28, 15]);
    expect(result.enemyMain.map((ship) => ship.currentHp), <int>[20, 5]);
  });

  test('splits twelve-slot damage arrays between main and escort', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_raigeki': <String, Object?>{
          'api_fdam': <num>[-1, 2, 0, 0, 0, 0, 0, 3],
          'api_edam': <num>[-1, 4, 0, 0, 0, 0, 0, 5],
        },
      },
      friendMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.friend, position: 0, hp: 20),
      ],
      friendEscort: <BattleShipSnapshot>[
        snapshot(
          side: BattleSide.friend,
          role: BattleFleetRole.escort,
          position: 0,
          hp: 20,
        ),
      ],
      enemyMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.enemy, position: 0, hp: 20),
      ],
      enemyEscort: <BattleShipSnapshot>[
        snapshot(
          side: BattleSide.enemy,
          role: BattleFleetRole.escort,
          position: 0,
          hp: 20,
        ),
      ],
    );

    expect(result.friendMain.single.currentHp, 18);
    expect(result.friendEscort.single.currentHp, 17);
    expect(result.enemyMain.single.currentHp, 16);
    expect(result.enemyEscort.single.currentHp, 15);
  });

  test('uses active deck roles for combined night shelling', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_active_deck': <int>[2, 1],
        'api_hougeki': <String, Object?>{
          'api_at_eflag': <int>[0, 1],
          'api_at_list': <int>[0, 0],
          'api_df_list': <Object?>[
            <int>[0],
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[6],
            <num>[4],
          ],
        },
      },
      friendMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.friend, position: 0, hp: 20),
      ],
      friendEscort: <BattleShipSnapshot>[
        snapshot(
          side: BattleSide.friend,
          role: BattleFleetRole.escort,
          position: 0,
          hp: 20,
        ),
      ],
      enemyMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.enemy, position: 0, hp: 20),
      ],
      enemyEscort: <BattleShipSnapshot>[
        snapshot(
          side: BattleSide.enemy,
          role: BattleFleetRole.escort,
          position: 0,
          hp: 20,
        ),
      ],
    );

    expect(result.friendMain.single.currentHp, 20);
    expect(result.friendEscort.single.currentHp, 16);
    expect(result.enemyMain.single.currentHp, 14);
    expect(result.enemyEscort.single.currentHp, 20);
    expect(result.friendEscort.single.damageDealt, 6);
  });

  test('infers attack sides when combined shelling omits api_at_eflag', () {
    final friendMain = <BattleShipSnapshot>[
      for (var index = 0; index < 6; index++)
        snapshot(side: BattleSide.friend, position: index, hp: 30),
    ];
    final enemyMain = <BattleShipSnapshot>[
      for (var index = 0; index < 6; index++)
        snapshot(side: BattleSide.enemy, position: index, hp: 30),
    ];

    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_hougeki1': <String, Object?>{
          'api_at_list': <int>[-1, 1, 8],
          'api_df_list': <Object?>[
            -1,
            <int>[11],
            <int>[5],
          ],
          'api_damage': <Object?>[
            -1,
            <num>[20],
            <num>[7],
          ],
        },
      },
      friendMain: friendMain,
      enemyMain: enemyMain,
      path: '/kcsapi/api_req_combined_battle/battle',
    );

    expect(result.friendMain[5].currentHp, 23);
    expect(result.enemyMain[5].currentHp, 10);
    expect(result.friendMain[1].damageDealt, 20);
  });

  test('applies shelling support damage to the enemy fleet', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_support_flag': 2,
        'api_support_info': <String, Object?>{
          'api_support_hourai': <String, Object?>{
            'api_damage': <num>[10, 0],
            'api_cl_list': <int>[1, 0],
          },
        },
      },
      friendMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.enemy, position: 0, hp: 20),
        snapshot(side: BattleSide.enemy, position: 1, hp: 20),
      ],
    );

    expect(result.enemyMain.map((ship) => ship.currentHp), <int>[10, 20]);
  });

  test('applies aerial support damage exactly once', () {
    final result = BattleDamageParser().apply(
      data: <String, Object?>{
        'api_support_flag': 1,
        'api_support_info': <String, Object?>{
          'api_support_airatack': <String, Object?>{
            'api_stage3': <String, Object?>{
              'api_edam': <num>[10],
            },
          },
        },
      },
      friendMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        snapshot(side: BattleSide.enemy, position: 0, hp: 20),
      ],
    );

    expect(result.enemyMain.single.currentHp, 10);
  });
}
