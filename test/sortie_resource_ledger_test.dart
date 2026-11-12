import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_resource_ledger.dart';

import 'fixtures/kcsapi_fixtures.dart';

final _time = DateTime.utc(2026, 11, 10);
const _material = '/kcsapi/api_get_member/material';
const _charge = '/kcsapi/api_req_hokyu/charge';
const _repair = '/kcsapi/api_req_nyukyo/start';
const _speed = '/kcsapi/api_req_nyukyo/speedchange';

OwnedShip _ship(
  int id, {
  int fuel = 20,
  int ammo = 20,
  int planes = 8,
  int hp = 12,
}) => OwnedShip(
  id: id,
  masterId: 1,
  level: id == 101 ? 120 : 98,
  currentHp: hp,
  maxHp: 20,
  currentFuel: fuel,
  currentAmmo: ammo,
  slotIds: [id * 2],
  onSlot: [planes],
  maxSlotCounts: const [8],
  repairFuelCost: 6,
  repairSteelCost: 12,
);

GameState _state(List<OwnedShip> ships, {List<RepairDock> docks = const []}) =>
    GameState(
      memberId: 9,
      hasPortData: true,
      updatedAt: _time,
      ships: {for (final ship in ships) ship.id: ship},
      masterShips: const {
        1: MasterShip(
          id: 1,
          name: 'Yahagi',
          shipTypeId: 3,
          maxFuel: 20,
          maxAmmo: 20,
        ),
      },
      resources: const {
        GameResourceType.fuel: 1000,
        GameResourceType.ammunition: 1000,
        GameResourceType.steel: 1000,
        GameResourceType.bauxite: 1000,
      },
      repairDocks: docks,
    );

Map<String, Object?> _row(OwnedShip ship) => {
  'api_id': ship.id,
  'api_fuel': ship.currentFuel,
  'api_bull': ship.currentAmmo,
  'api_slot': ship.slotIds,
  'api_onslot': ship.onSlot,
  'api_nowhp': ship.currentHp,
  'api_ndock_item': [ship.repairFuelCost, ship.repairSteelCost],
};

void _balance(SortieResourceLedger ledger, GameState state) {
  final data = [
    for (var index = 1; index <= 4; index++)
      {'api_id': index, 'api_value': 1000},
  ];
  ledger.record(
    kcsapiEvent(_material, data, capturedAt: _time),
    data,
    state,
    tracking: true,
  );
}

bool _supply(
  SortieResourceLedger ledger,
  GameState before,
  List<OwnedShip> ships,
  List<int> balance, {
  bool tracking = true,
  int elapsed = 1,
}) {
  final data = {
    'api_ship': ships.map(_row).toList(),
    'api_material': balance,
    'api_use_bou': 1,
  };
  return ledger.record(
    kcsapiEvent(
      _charge,
      data,
      capturedAt: _time.add(Duration(seconds: elapsed)),
    ),
    data,
    before,
    tracking: tracking,
  );
}

void main() {
  test(
    'charges only after return and reconciles marriage and aircraft in batch',
    () {
      final ledger = SortieResourceLedger();
      final start = _state([_ship(101), _ship(102)]);
      final after = [
        _ship(101, fuel: 10, ammo: 8, planes: 6),
        _ship(102, fuel: 14, ammo: 15, planes: 5),
      ];
      ledger.beginSortie(start, [101, 102], tracking: true);
      expect(ledger.hasData, isFalse);
      expect(
        ledger.returnToPort(after.map(_row).toList(), tracking: true),
        isTrue,
      );
      expect(ledger.spendingFor(101)!.pending.fuel, 10);
      expect(ledger.spendingFor(101)!.total.isEmpty, isTrue);
      final before = _state(after);
      _balance(ledger, before);
      expect(
        _supply(
          ledger,
          before,
          [_ship(101), _ship(102)],
          [986, 985, 1000, 975],
        ),
        isTrue,
      );
      expect(ledger.spendingFor(101)!.supply.fuel, 8);
      expect(ledger.spendingFor(101)!.supply.ammo, 10);
      expect(ledger.spendingFor(101)!.supply.bauxite, 10);
      expect(ledger.spendingFor(102)!.supply.bauxite, 15);
      expect(ledger.spendingFor(101)!.pending.isEmpty, isTrue);
      expect(ledger.incomplete, isFalse);
    },
  );

  test(
    'mixed deficits and paused purchases do not become tracked spending',
    () {
      final ledger = SortieResourceLedger();
      final first = _ship(101, fuel: 17);
      ledger.beginSortie(_state([first, _ship(102)]), [
        101,
        102,
      ], tracking: true);
      final after = [_ship(101, fuel: 12), _ship(102, fuel: 14)];
      ledger.returnToPort(after.map(_row).toList(), tracking: true);
      final before = _state(after);
      _balance(ledger, before);
      _supply(ledger, before, [_ship(101)], [994, 1000, 1000, 1000]);
      expect(ledger.spendingFor(101)?.supply.fuel ?? 0, 0);
      expect(ledger.spendingFor(101)?.pending.fuel ?? 0, 0);
      _balance(ledger, before);
      _supply(
        ledger,
        before,
        [_ship(102)],
        [994, 1000, 1000, 1000],
        tracking: false,
      );
      expect(ledger.spendingFor(102)?.supply.fuel ?? 0, 0);
      expect(ledger.spendingFor(102)?.pending.fuel ?? 0, 0);
    },
  );

  test('deducts repair costs at admission and the bucket at acceleration', () {
    final ledger = SortieResourceLedger();
    final state = _state([_ship(101), _ship(102)]);
    ledger.returnToPort(state.ships.values.map(_row).toList(), tracking: true);
    void repair(int id, bool instant) => ledger.record(
      kcsapiEvent(
        _repair,
        null,
        requestParams: {
          'api_ship_id': id.toString(),
          'api_ndock_id': id == 101 ? '1' : '2',
          'api_highspeed': instant ? '1' : '0',
        },
      ),
      null,
      state,
      tracking: true,
    );
    repair(101, false);
    repair(102, true);
    expect(ledger.spendingFor(101)!.repair.buckets, 0);
    expect(ledger.spendingFor(102)!.repair.buckets, 1);
    ledger.record(
      kcsapiEvent(_speed, null, requestParams: {'api_ndock_id': '1'}),
      null,
      _state(
        [_ship(101)],
        docks: const [RepairDock(id: 1, state: 1, shipId: 101)],
      ),
      tracking: true,
    );
    expect(ledger.spendingFor(101)!.total.fuel, 6);
    expect(ledger.spendingFor(101)!.total.steel, 12);
    expect(ledger.spendingFor(101)!.total.buckets, 1);
    expect(
      ledger.record(
        kcsapiEvent(_speed, null, requestParams: {'api_ndock_id': '1'}),
        null,
        _state([_ship(101, hp: 20)]),
        tracking: true,
      ),
      isFalse,
    );
    expect(ledger.spendingFor(101)!.total.buckets, 1);
    expect(ledger.incomplete, isFalse);
  });

  test(
    'stale repair quote does not fabricate fuel or steel, but bucket counts',
    () {
      final ledger = SortieResourceLedger();
      ledger.returnToPort([_row(_ship(101))], tracking: true);
      ledger.record(
        kcsapiEvent(
          _repair,
          null,
          requestParams: {
            'api_ship_id': '101',
            'api_ndock_id': '1',
            'api_highspeed': '1',
          },
        ),
        null,
        _state([_ship(101, hp: 9)]),
        tracking: true,
      );
      expect(
        ledger.spendingFor(101)!.repair,
        const SortieResourceAmounts(buckets: 1),
      );
      expect(ledger.spendingFor(101)!.incomplete, isTrue);
    },
  );

  test(
    'partial refill only counts when the whole pre-charge deficit is tracked',
    () {
      final ledger = SortieResourceLedger();
      ledger.beginSortie(_state([_ship(101), _ship(102, fuel: 17)]), [
        101,
        102,
      ], tracking: true);
      final after = [_ship(101, fuel: 10), _ship(102, fuel: 12)];
      ledger.returnToPort(after.map(_row).toList(), tracking: true);
      final before = _state(after);
      _balance(ledger, before);
      _supply(
        ledger,
        before,
        [_ship(101, fuel: 14), _ship(102, fuel: 17)],
        [992, 1000, 1000, 1000],
      );
      expect(ledger.spendingFor(101)!.supply.fuel, 3);
      expect(ledger.spendingFor(101)!.pending.fuel, 6);
      expect(ledger.spendingFor(102)!.supply.fuel, 0);
      expect(ledger.spendingFor(102)!.pending.fuel, 0);
      expect(ledger.spendingFor(102)!.incomplete, isTrue);
    },
  );

  test('unrelated equipment change does not invalidate a carrier deficit', () {
    final ledger = SortieResourceLedger();
    ledger.beginSortie(_state([_ship(101), _ship(102)]), [
      101,
      102,
    ], tracking: true);
    final after = [_ship(101, planes: 6), _ship(102, planes: 5)];
    ledger.returnToPort(after.map(_row).toList(), tracking: true);
    final before = _state(after);
    ledger.record(
      kcsapiEvent(
        '/kcsapi/api_req_kaisou/slotset',
        null,
        requestParams: {'api_id': '102'},
      ),
      null,
      before,
      tracking: true,
    );
    expect(ledger.spendingFor(101)!.pending.bauxite, 10);
    expect(ledger.spendingFor(102)!.pending.bauxite, 0);
    _balance(ledger, before);
    _supply(ledger, before, [_ship(101)], [1000, 1000, 1000, 990]);
    expect(ledger.spendingFor(101)!.supply.bauxite, 10);
  });

  test('fuel and ammo can be confirmed in separate replenishments', () {
    final ledger = SortieResourceLedger();
    final full = _ship(101);
    ledger.beginSortie(_state([full]), [101], tracking: true);
    final depleted = _ship(101, fuel: 10, ammo: 8);
    ledger.returnToPort([_row(depleted)], tracking: true);
    final before = _state([depleted]);
    _balance(ledger, before);

    final refueled = _ship(101, ammo: 8);
    expect(
      _supply(ledger, before, [refueled], [992, 1000, 1000, 1000]),
      isTrue,
    );
    expect(
      ledger.spendingFor(101)!.supply,
      const SortieResourceAmounts(fuel: 8),
    );
    expect(
      ledger.spendingFor(101)!.pending,
      const SortieResourceAmounts(ammo: 12),
    );

    final beforeAmmo = _state([
      refueled,
    ]).copyWith(resources: {...before.resources, GameResourceType.fuel: 992});
    expect(
      _supply(ledger, beforeAmmo, [full], [992, 990, 1000, 1000], elapsed: 2),
      isTrue,
    );
    expect(
      ledger.spendingFor(101)!.supply,
      const SortieResourceAmounts(fuel: 8, ammo: 10),
    );
    expect(ledger.spendingFor(101)!.pending.isEmpty, isTrue);
    expect(ledger.incomplete, isFalse);
  });

  test('a mismatched warehouse debit stays outside confirmed spending', () {
    final ledger = SortieResourceLedger();
    final full = _ship(102);
    ledger.beginSortie(_state([full]), [102], tracking: true);
    final depleted = _ship(102, fuel: 15);
    ledger.returnToPort([_row(depleted)], tracking: true);
    final before = _state([depleted]);
    _balance(ledger, before);

    _supply(ledger, before, [full], [994, 1000, 1000, 1000]);

    expect(ledger.spendingFor(102)!.total.isEmpty, isTrue);
    expect(ledger.unallocated, const SortieResourceAmounts(fuel: 6));
    expect(ledger.incomplete, isTrue);
  });

  test('offshore supply discards affected oil and ammunition while paused', () {
    final ledger = SortieResourceLedger();
    ledger.beginSortie(_state([_ship(101), _ship(102)]), [
      101,
      102,
    ], tracking: true);
    final after = [
      _ship(101, fuel: 10, ammo: 12, planes: 6),
      _ship(102, fuel: 12),
    ];
    ledger.returnToPort(after.map(_row).toList(), tracking: true);
    expect(ledger.observeOffshoreSupply([101], tracking: false), isTrue);
    expect(
      ledger.spendingFor(101)!.pending,
      const SortieResourceAmounts(bauxite: 10),
    );
    expect(ledger.spendingFor(102)!.pending.fuel, 8);
    final before = _state(after);
    _balance(ledger, before);
    _supply(ledger, before, [_ship(101)], [992, 994, 1000, 990]);
    expect(
      ledger.spendingFor(101)!.supply,
      const SortieResourceAmounts(bauxite: 10),
    );
  });

  test('a missing return stock value and capture interruption are visible', () {
    final ledger = SortieResourceLedger();
    final start = _state([_ship(101)]);
    ledger.beginSortie(start, [101], tracking: true);
    final incomplete = _row(_ship(101))..remove('api_fuel');
    expect(ledger.returnToPort([incomplete], tracking: true), isTrue);
    expect(ledger.spendingFor(101)!.incomplete, isTrue);
    expect(ledger.spendingFor(101)!.pending.isEmpty, isTrue);
    ledger.clear();
    ledger.beginSortie(start, [101], tracking: true);
    expect(ledger.interrupt(), isTrue);
    expect(ledger.incomplete, isTrue);
    expect(
      ledger.returnToPort([_row(_ship(101, fuel: 12))], tracking: true),
      isFalse,
    );
  });

  test('restore keeps expenses but discards unverified pending provenance', () {
    final ledger = SortieResourceLedger();
    final start = _state([_ship(101)]);
    ledger.beginSortie(start, [101], tracking: true);
    final after = _ship(101, fuel: 10, ammo: 8);
    ledger.returnToPort([_row(after)], tracking: true);
    final before = _state([after]);
    _balance(ledger, before);
    _supply(ledger, before, [_ship(101, ammo: 8)], [992, 1000, 1000, 1000]);
    expect(ledger.spendingFor(101)!.pending.ammo, 12);
    final restored = SortieResourceLedger.fromJson(ledger.toJson());
    expect(restored.spendingFor(101)!.supply.fuel, 8);
    expect(restored.spendingFor(101)!.pending.isEmpty, isTrue);
    expect(restored.spendingFor(101)!.incomplete, isTrue);
    expect(restored.forgetShips({101}), isTrue);
    expect(restored.hasData, isFalse);
  });

  test('legacy or malformed ledger cannot manufacture a confirmed expense', () {
    expect(SortieResourceLedger.fromJson(null).hasData, isFalse);
    final corrupted = SortieResourceLedger.fromJson({'ships': 'invalid'});
    expect(corrupted.incomplete, isTrue);
    expect(corrupted.shipIds, isEmpty);
  });
}
