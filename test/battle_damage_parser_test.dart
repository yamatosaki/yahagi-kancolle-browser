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
}
