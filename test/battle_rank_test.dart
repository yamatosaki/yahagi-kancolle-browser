import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_rank.dart';

BattleShipSnapshot ship({
  required BattleSide side,
  required int initialHp,
  required int currentHp,
  int position = 0,
}) {
  return BattleShipSnapshot(
    masterId: position + 1,
    name: '${side.name}-$position',
    side: side,
    fleetRole: BattleFleetRole.main,
    position: position,
    initialHp: initialHp,
    maxHp: initialHp,
    currentHp: currentHp,
  );
}

void main() {
  test('returns SS when every enemy is sunk and friend fleet is untouched', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 30, currentHp: 30),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 20, currentHp: 0),
      ],
    );

    expect(rank, BattleRank.ss);
  });

  test('returns S when every enemy is sunk but friend fleet took damage', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 30, currentHp: 20),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 20, currentHp: 0),
      ],
    );

    expect(rank, BattleRank.s);
  });

  test(
    'returns A when enough non-flagship enemies are sunk without losses',
    () {
      final rank = estimateBattleRank(
        friendShips: <BattleShipSnapshot>[
          ship(side: BattleSide.friend, initialHp: 30, currentHp: 30),
          ship(
            side: BattleSide.friend,
            initialHp: 30,
            currentHp: 30,
            position: 1,
          ),
        ],
        enemyShips: <BattleShipSnapshot>[
          ship(side: BattleSide.enemy, initialHp: 20, currentHp: 20),
          ship(
            side: BattleSide.enemy,
            initialHp: 20,
            currentHp: 0,
            position: 1,
          ),
          ship(
            side: BattleSide.enemy,
            initialHp: 20,
            currentHp: 0,
            position: 2,
          ),
        ],
      );

      expect(rank, BattleRank.a);
    },
  );

  test('returns B when enemy flagship is sunk and friend fleet is afloat', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 30, currentHp: 20),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 20, currentHp: 0),
        ship(side: BattleSide.enemy, initialHp: 20, currentHp: 20, position: 1),
        ship(side: BattleSide.enemy, initialHp: 20, currentHp: 20, position: 2),
      ],
    );

    expect(rank, BattleRank.b);
  });

  test('returns C when enemy damage rate is moderately higher', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 100, currentHp: 90),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 100, currentHp: 80),
      ],
    );

    expect(rank, BattleRank.c);
  });

  test('returns D when neither side has a meaningful advantage', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 100, currentHp: 80),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 100, currentHp: 90),
      ],
    );

    expect(rank, BattleRank.d);
  });

  test(
    'returns D when enemy damage is half but below ninety percent of ours',
    () {
      final rank = estimateBattleRank(
        friendShips: <BattleShipSnapshot>[
          ship(side: BattleSide.friend, initialHp: 100, currentHp: 40),
        ],
        enemyShips: <BattleShipSnapshot>[
          ship(side: BattleSide.enemy, initialHp: 100, currentHp: 50),
        ],
      );

      expect(rank, BattleRank.d);
    },
  );

  test('returns C when enemy damage exceeds ninety percent of ours', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 100, currentHp: 80),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 100, currentHp: 81),
      ],
    );

    expect(rank, BattleRank.c);
  });

  test('floors damage percentages before the strict B-rank comparison', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 1000, currentHp: 899),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 1000, currentHp: 746),
      ],
    );

    expect(rank, BattleRank.c);
  });

  test('returns E when only one friend ship remains afloat', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 30, currentHp: 1),
        ship(side: BattleSide.friend, initialHp: 30, currentHp: 0, position: 1),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 30, currentHp: 30),
        ship(side: BattleSide.enemy, initialHp: 30, currentHp: 30, position: 1),
      ],
    );

    expect(rank, BattleRank.e);
  });

  test('returns SS for an air raid when the friend fleet is untouched', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 100, currentHp: 100),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 100, currentHp: 100),
      ],
      airRaid: true,
    );

    expect(rank, BattleRank.ss);
  });

  test('keeps ordinary battle rules when both fleets are untouched', () {
    final rank = estimateBattleRank(
      friendShips: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, initialHp: 100, currentHp: 100),
      ],
      enemyShips: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, initialHp: 100, currentHp: 100),
      ],
    );

    expect(rank, BattleRank.d);
  });
}
