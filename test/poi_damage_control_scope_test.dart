import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_replay_state.dart';

void main() {
  test('battle snapshots start with no damage control used this battle', () {
    const ship = BattleShipSnapshot(
      masterId: 100,
      name: 'friend-0',
      side: BattleSide.friend,
      fleetRole: BattleFleetRole.main,
      position: 0,
      initialHp: 30,
      maxHp: 30,
      currentHp: 30,
    );

    expect(ship.damageControlUsedThisBattle, isEmpty);
  });

  test('new POI battle clears stale battle use and keeps sortie use', () {
    final seed = _ship(
      equipment: const <int>[42, 42],
      sortieUsed: const <int>[42],
      battleUsed: const <int>[42],
    );
    final result = _engine(
      seed,
    ).append(path: _dayPath, data: _enemyDamage(<num>[1]));
    final ship = result.friendMain.single;

    expect(result.issues, isEmpty);
    expect(ship.currentHp, 29);
    expect(ship.damageControlUsedThisBattle, isEmpty);
    expect(ship.usedDamageControlItemIds, <int>[42]);
    expect(ship.equipmentMasterIds, <int>[42, 42]);
    expect(seed.damageControlUsedThisBattle, <int>[42]);
    expect(seed.usedDamageControlItemIds, <int>[42]);
  });

  test('new lethal POI battle records only the newly consumed item', () {
    final seed = _ship(
      equipment: const <int>[42, 42],
      sortieUsed: const <int>[42],
      battleUsed: const <int>[42],
    );
    final result = _engine(
      seed,
    ).append(path: _dayPath, data: _enemyDamage(<num>[30]));
    final ship = result.friendMain.single;

    expect(result.issues, isEmpty);
    expect(ship.currentHp, 6);
    expect(ship.damageControlUsedThisBattle, <int>[42]);
    expect(ship.usedDamageControlItemIds, <int>[42, 42]);
    expect(seed.damageControlUsedThisBattle, <int>[42]);
    expect(seed.usedDamageControlItemIds, <int>[42]);
  });

  test('POI replay retains day use once when night deals no damage', () {
    final engine = _engine(_ship(equipment: const <int>[42, 43]));
    final day = engine.append(path: _dayPath, data: _enemyDamage(<num>[30]));
    final night = engine.append(
      path: _nightPath,
      data: const <String, Object?>{},
    );
    final replayed = engine.append(
      path: _nightPath,
      data: const <String, Object?>{},
    );

    expect(day.issues, isEmpty);
    expect(day.friendMain.single.currentHp, 6);
    expect(day.friendMain.single.damageControlUsedThisBattle, <int>[42]);
    expect(night.issues, isEmpty);
    expect(night.friendMain.single.currentHp, 6);
    expect(night.friendMain.single.damageControlUsedThisBattle, <int>[42]);
    expect(night.friendMain.single.usedDamageControlItemIds, <int>[42]);
    expect(replayed.issues, isEmpty);
    expect(replayed.friendMain.single.currentHp, 6);
    expect(replayed.friendMain.single.damageControlUsedThisBattle, <int>[42]);
    expect(replayed.friendMain.single.usedDamageControlItemIds, <int>[42]);
  });

  test('POI battle records day repair crew and subsequent night goddess', () {
    final engine = _engine(_ship(equipment: const <int>[42, 43]));
    final day = engine.append(path: _dayPath, data: _enemyDamage(<num>[30]));
    final night = engine.append(
      path: _nightPath,
      data: _enemyDamage(<num>[6], night: true),
    );
    final replayed = engine.append(
      path: _nightPath,
      data: const <String, Object?>{},
    );

    expect(night.issues, isEmpty);
    expect(night.friendMain.single.currentHp, 30);
    expect(night.friendMain.single.damageControlUsedThisBattle, <int>[42, 43]);
    expect(night.friendMain.single.usedDamageControlItemIds, <int>[42, 43]);
    expect(replayed.friendMain.single.damageControlUsedThisBattle, <int>[
      42,
      43,
    ]);
    expect(replayed.friendMain.single.usedDamageControlItemIds, <int>[42, 43]);
    expect(day.friendMain.single.damageControlUsedThisBattle, <int>[42]);
    expect(day.friendMain.single.usedDamageControlItemIds, <int>[42]);
  });

  test(
    'POI records two same-type uses in one battle without deduplication',
    () {
      final engine = _engine(_ship(equipment: const <int>[42, 42]));
      final day = engine.append(
        path: _dayPath,
        data: _enemyDamage(<num>[30, 6]),
      );
      final night = engine.append(
        path: _nightPath,
        data: _enemyDamage(<num>[6], night: true),
      );

      expect(day.issues, isEmpty);
      expect(day.friendMain.single.currentHp, 6);
      expect(day.friendMain.single.damageControlUsedThisBattle, <int>[42, 42]);
      expect(day.friendMain.single.usedDamageControlItemIds, <int>[42, 42]);
      expect(night.issues, isEmpty);
      expect(night.friendMain.single.currentHp, 0);
      expect(night.friendMain.single.damageControlUsedThisBattle, <int>[
        42,
        42,
      ]);
      expect(night.friendMain.single.usedDamageControlItemIds, <int>[42, 42]);
    },
  );

  test('POI fleet clone copies battle-use lists without aliasing', () {
    final battleUsed = <int>[42];
    final sortieUsed = <int>[42];
    final seed = _ship(sortieUsed: sortieUsed, battleUsed: battleUsed);
    final clone = clonePoiBattleFleet(<BattleShipSnapshot>[seed]).single;

    expect(clone.damageControlUsedThisBattle, <int>[42]);
    expect(clone.damageControlUsedThisBattle, isNot(same(battleUsed)));
    expect(clone.usedDamageControlItemIds, isNot(same(sortieUsed)));

    battleUsed.add(43);
    sortieUsed.add(43);
    expect(clone.damageControlUsedThisBattle, <int>[42]);
    expect(clone.usedDamageControlItemIds, <int>[42]);

    clone.damageControlUsedThisBattle.add(42);
    expect(seed.damageControlUsedThisBattle, <int>[42, 43]);
  });

  test('copyWith preserves battle use unless explicitly replaced', () {
    final seed = _ship(
      sortieUsed: const <int>[42, 43],
      battleUsed: const <int>[43],
    );
    final copied = seed.copyWith(currentHp: 12);
    final replaced = seed.copyWith(damageControlUsedThisBattle: <int>[42]);
    final cleared = seed.copyWith(damageControlUsedThisBattle: <int>[]);

    expect(copied.currentHp, 12);
    expect(copied.damageControlUsedThisBattle, <int>[43]);
    expect(copied.usedDamageControlItemIds, <int>[42, 43]);
    expect(replaced.damageControlUsedThisBattle, <int>[42]);
    expect(replaced.usedDamageControlItemIds, <int>[42, 43]);
    expect(cleared.damageControlUsedThisBattle, isEmpty);
    expect(cleared.usedDamageControlItemIds, <int>[42, 43]);
    expect(seed.damageControlUsedThisBattle, <int>[43]);
  });
}

const _dayPath = '/kcsapi/api_req_sortie/battle';
const _nightPath = '/kcsapi/api_req_battle_midnight/battle';

BattleShipSnapshot _ship({
  BattleSide side = BattleSide.friend,
  List<int> equipment = const <int>[],
  List<int> sortieUsed = const <int>[],
  List<int> battleUsed = const <int>[],
}) => BattleShipSnapshot(
  masterId: 100,
  name: '$side-0',
  side: side,
  fleetRole: BattleFleetRole.main,
  position: 0,
  initialHp: 30,
  maxHp: 30,
  currentHp: 30,
  equipmentMasterIds: equipment,
  usedDamageControlItemIds: sortieUsed,
  damageControlUsedThisBattle: battleUsed,
);

PoiBattlePredictionEngine _engine(BattleShipSnapshot friend) =>
    PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[friend],
      enemyMain: <BattleShipSnapshot>[_ship(side: BattleSide.enemy)],
    );

Map<String, Object?> _enemyDamage(List<num> damages, {bool night = false}) =>
    <String, Object?>{
      night ? 'api_hougeki' : 'api_hougeki1': <String, Object?>{
        'api_at_eflag': <int>[for (final _ in damages) 1],
        'api_at_list': <int>[for (final _ in damages) 0],
        'api_df_list': <Object?>[
          for (final _ in damages) <int>[0],
        ],
        'api_damage': <Object?>[
          for (final damage in damages) <num>[damage],
        ],
      },
    };
