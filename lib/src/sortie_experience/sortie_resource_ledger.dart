import '../bridge/captured_api_event.dart';
import '../game_state/game_state.dart';

final class SortieResourceAmounts {
  const SortieResourceAmounts({
    this.fuel = 0,
    this.ammo = 0,
    this.steel = 0,
    this.bauxite = 0,
    this.buckets = 0,
  });

  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;
  final int buckets;

  bool get isEmpty =>
      fuel == 0 && ammo == 0 && steel == 0 && bauxite == 0 && buckets == 0;

  SortieResourceAmounts operator +(SortieResourceAmounts other) =>
      SortieResourceAmounts(
        fuel: _bounded(fuel + other.fuel),
        ammo: _bounded(ammo + other.ammo),
        steel: _bounded(steel + other.steel),
        bauxite: _bounded(bauxite + other.bauxite),
        buckets: _bounded(buckets + other.buckets),
      );

  @override
  bool operator ==(Object other) =>
      other is SortieResourceAmounts &&
      fuel == other.fuel &&
      ammo == other.ammo &&
      steel == other.steel &&
      bauxite == other.bauxite &&
      buckets == other.buckets;

  @override
  int get hashCode => Object.hash(fuel, ammo, steel, bauxite, buckets);

  int _for(_SupplyResource resource) => switch (resource) {
    _SupplyResource.fuel => fuel,
    _SupplyResource.ammo => ammo,
    _SupplyResource.bauxite => bauxite,
  };

  SortieResourceAmounts _with(_SupplyResource resource, int value) =>
      SortieResourceAmounts(
        fuel: resource == _SupplyResource.fuel ? value : fuel,
        ammo: resource == _SupplyResource.ammo ? value : ammo,
        steel: steel,
        bauxite: resource == _SupplyResource.bauxite ? value : bauxite,
        buckets: buckets,
      );

  Map<String, Object?> _toJson() => {
    'fuel': fuel,
    'ammo': ammo,
    'steel': steel,
    'bauxite': bauxite,
    'buckets': buckets,
  };

  static SortieResourceAmounts _decode(Object? value) {
    if (value is! Map) throw const FormatException('Invalid resource amounts');
    return SortieResourceAmounts(
      fuel: _storedInt(value['fuel']),
      ammo: _storedInt(value['ammo']),
      steel: _storedInt(value['steel']),
      bauxite: _storedInt(value['bauxite']),
      buckets: _storedInt(value['buckets']),
    );
  }
}

final class SortieShipResourceSpending {
  const SortieShipResourceSpending({
    this.supply = const SortieResourceAmounts(),
    this.repair = const SortieResourceAmounts(),
    this.pending = const SortieResourceAmounts(),
    this.incomplete = false,
  });

  final SortieResourceAmounts supply;
  final SortieResourceAmounts repair;
  final SortieResourceAmounts pending;
  final bool incomplete;

  SortieResourceAmounts get total => supply + repair;

  bool get _isEmpty =>
      supply.isEmpty && repair.isEmpty && pending.isEmpty && !incomplete;

  SortieShipResourceSpending _with({
    SortieResourceAmounts? supply,
    SortieResourceAmounts? repair,
    SortieResourceAmounts? pending,
    bool? incomplete,
  }) => SortieShipResourceSpending(
    supply: supply ?? this.supply,
    repair: repair ?? this.repair,
    pending: pending ?? this.pending,
    incomplete: incomplete ?? this.incomplete,
  );
}

enum _SupplyResource {
  fuel(GameResourceType.fuel),
  ammo(GameResourceType.ammunition),
  bauxite(GameResourceType.bauxite);

  const _SupplyResource(this.resource);
  final GameResourceType resource;
}

typedef _PlaneStock = ({List<int> slots, List<int> counts});
typedef _SupplyStock = ({int? fuel, int? ammo, _PlaneStock? aircraft});
typedef _ChargeRow = ({
  int id,
  OwnedShip? ship,
  _SupplyStock after,
  _PlaneStock? planeRefill,
});
typedef _RepairQuote = ({int? hp, int fuel, int steel});

/// Local, per-account warehouse spending. The caller verifies ownership and
/// serializes accepted capture events before handing them to this ledger.
final class SortieResourceLedger {
  SortieResourceLedger();

  static const _port = '/kcsapi/api_port/port';
  static const _material = '/kcsapi/api_get_member/material';
  static const _charge = '/kcsapi/api_req_hokyu/charge';
  static const _repairStart = '/kcsapi/api_req_nyukyo/start';
  static const _repairSpeed = '/kcsapi/api_req_nyukyo/speedchange';
  static const _practice = '/kcsapi/api_req_practice/battle';
  static const _missionStart = '/kcsapi/api_req_mission/start';
  static const _rosterPaths = {
    '/kcsapi/api_get_member/ship2',
    '/kcsapi/api_get_member/ship3',
    '/kcsapi/api_get_member/ship_deck',
  };
  static const _materialChangePaths = {
    '/kcsapi/api_req_mission/result',
    '/kcsapi/api_req_quest/clearitemget',
    '/kcsapi/api_req_member/itemuse',
    '/kcsapi/api_req_air_corps/supply',
    '/kcsapi/api_req_air_corps/set_plane',
    '/kcsapi/api_req_air_corps/change_deployment_base',
    '/kcsapi/api_req_kousyou/createship',
    '/kcsapi/api_req_kousyou/createitem',
    '/kcsapi/api_req_kousyou/destroyitem2',
    '/kcsapi/api_req_kousyou/destroyship',
    '/kcsapi/api_req_kousyou/remodel_slot',
    '/kcsapi/api_req_kousyou/remodel_slot_recover',
    '/kcsapi/api_req_kaisou/marriage',
    '/kcsapi/api_req_kaisou/powerup',
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/air_raid',
  };
  static const _equipmentPaths = {
    '/kcsapi/api_req_kaisou/slotset',
    '/kcsapi/api_req_kaisou/unsetslot_all',
    '/kcsapi/api_req_kaisou/slot_deprive',
    '/kcsapi/api_req_kaisou/slot_exchange_index',
  };

  static bool supportsPath(String path) =>
      path == _port ||
      path == _material ||
      path == _charge ||
      path == _repairStart ||
      path == _repairSpeed ||
      path == _practice ||
      path == _missionStart ||
      _rosterPaths.contains(path) ||
      _materialChangePaths.contains(path) ||
      _equipmentPaths.contains(path);

  final _ships = <int, SortieShipResourceSpending>{};
  final _planeDebt = <int, _PlaneStock>{};
  final _repairQuotes = <int, _RepairQuote>{};
  final _acceleratedDocks = <int>{};
  Map<int, _SupplyStock>? _active;
  Map<GameResourceType, int> _warehouse = const {};
  DateTime? _warehouseAt;
  bool _incomplete = false;
  SortieResourceAmounts _unallocated = const SortieResourceAmounts();

  bool get hasData => _ships.isNotEmpty || _incomplete || !_unallocated.isEmpty;
  bool get incomplete =>
      _incomplete || _ships.values.any((entry) => entry.incomplete);
  SortieResourceAmounts get unallocated => _unallocated;
  Iterable<int> get shipIds => _ships.keys;
  SortieShipResourceSpending? spendingFor(int id) => _ships[id];

  factory SortieResourceLedger.fromJson(Object? raw) {
    final ledger = SortieResourceLedger();
    if (raw == null) return ledger;
    if (raw is! Map || raw['version'] != 1 || raw['ships'] is! List) {
      return ledger.._incomplete = true;
    }
    ledger._incomplete =
        raw['incomplete'] is! bool || raw['incomplete'] == true;
    try {
      ledger._unallocated = SortieResourceAmounts._decode(raw['unallocated']);
    } on FormatException {
      ledger._incomplete = true;
    }
    final seen = <int>{};
    for (final value in raw['ships'] as List) {
      try {
        if (value is! Map || value['incomplete'] is! bool) {
          throw const FormatException('Invalid spending row');
        }
        final id = _storedInt(value['id']);
        if (id == 0 || !seen.add(id)) {
          ledger._ships.remove(id);
          throw const FormatException('Invalid spending ship');
        }
        final pending = SortieResourceAmounts._decode(value['pending']);
        // A restarted capture cannot prove that an old deficit is unchanged.
        ledger._put(
          id,
          SortieShipResourceSpending(
            supply: SortieResourceAmounts._decode(value['supply']),
            repair: SortieResourceAmounts._decode(value['repair']),
            incomplete: value['incomplete'] == true || !pending.isEmpty,
          ),
        );
      } on FormatException {
        ledger._incomplete = true;
      }
    }
    return ledger;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'incomplete': _incomplete,
    'unallocated': _unallocated._toJson(),
    'ships': [
      for (final entry in _ships.entries)
        {
          'id': entry.key,
          'supply': entry.value.supply._toJson(),
          'repair': entry.value.repair._toJson(),
          'pending': entry.value.pending._toJson(),
          'incomplete': entry.value.incomplete,
        },
    ],
  };

  void beginSortie(
    GameState before,
    Iterable<int> shipIds, {
    required bool tracking,
  }) {
    _active = tracking && before.hasPortData
        ? {
            for (final id in shipIds)
              if (before.ships[id] case final ship?)
                id: _sortieStock(ship, before.masterShips[ship.masterId]),
          }
        : null;
  }

  bool returnToPort(Object? shipRows, {required bool tracking}) {
    final active = _active;
    _active = null;
    _observeRepairQuotes(shipRows);
    if (!tracking || active == null || active.isEmpty) return false;
    final rows = _shipRows(shipRows);
    var changed = false;
    for (final entry in active.entries) {
      final id = entry.key;
      final start = entry.value;
      final after = rows?[id];
      if (after == null) {
        if (_hasSupplyBaseline(start)) {
          final prior = _ships[id] ?? const SortieShipResourceSpending();
          changed = _put(id, prior._with(incomplete: true)) || changed;
        }
        changed = _invalidatePending(id) || changed;
        continue;
      }
      final end = _wireStock(after);
      final previous = _ships[id] ?? const SortieShipResourceSpending();
      final fuel = _accumulateDeficit(
        previous.pending.fuel,
        start.fuel,
        end.fuel,
      );
      final ammo = _accumulateDeficit(
        previous.pending.ammo,
        start.ammo,
        end.ammo,
      );
      final aircraft = _planeDifference(start.aircraft, end.aircraft);
      final older = _planeDebt[id];
      final aircraftValid =
          aircraft != null &&
          (older == null || _sameList(aircraft.slots, older.slots));
      var bauxite = 0;
      if (aircraftValid) {
        final counts = [
          for (var i = 0; i < aircraft.counts.length; i++)
            _bounded(aircraft.counts[i] + (older?.counts[i] ?? 0)),
        ];
        bauxite = _planeValue(counts);
        if (bauxite > 0) {
          _planeDebt[id] = (slots: aircraft.slots, counts: counts);
        }
      }
      if (bauxite == 0) _planeDebt.remove(id);
      final pending = SortieResourceAmounts(
        fuel: fuel ?? 0,
        ammo: ammo ?? 0,
        bauxite: bauxite,
      );
      changed =
          _put(
            id,
            previous._with(
              pending: pending,
              incomplete:
                  previous.incomplete ||
                  (fuel == null && previous.pending.fuel > 0) ||
                  (ammo == null && previous.pending.ammo > 0) ||
                  (start.fuel != null && end.fuel == null) ||
                  (start.ammo != null && end.ammo == null) ||
                  (!aircraftValid &&
                      (previous.pending.bauxite > 0 ||
                          _hasAircraftBaseline(start))),
            ),
          ) ||
          changed;
    }
    return changed;
  }

  void abandonSortie() => _active = null;

  bool observeOffshoreSupply(Iterable<int> ids, {required bool tracking}) {
    abandonSortie();
    final affected = ids.toSet();
    var changed = tracking && _markIncomplete();
    for (final id in affected.isEmpty ? _ships.keys.toList() : affected) {
      final previous = _ships[id];
      if (previous == null ||
          (previous.pending.fuel == 0 && previous.pending.ammo == 0)) {
        continue;
      }
      changed =
          _put(
            id,
            previous._with(
              pending: SortieResourceAmounts(bauxite: previous.pending.bauxite),
              incomplete: true,
            ),
          ) ||
          changed;
    }
    return changed;
  }

  bool interrupt() {
    var changed = _active?.isNotEmpty == true && _markIncomplete();
    abandonSortie();
    _warehouse = const {};
    _warehouseAt = null;
    _repairQuotes.clear();
    _acceleratedDocks.clear();
    for (final id in _ships.keys.toList()) {
      changed = _invalidatePending(id) || changed;
    }
    return changed;
  }

  bool forgetShips(Set<int> ids) {
    var changed = false;
    for (final id in ids) {
      _active?.remove(id);
      _planeDebt.remove(id);
      _repairQuotes.remove(id);
      changed = (_ships.remove(id) != null) || changed;
    }
    return changed;
  }

  void clear() {
    abandonSortie();
    _ships.clear();
    _planeDebt.clear();
    _unallocated = const SortieResourceAmounts();
    _incomplete = false;
  }

  bool record(
    CapturedApiEvent event,
    Object? data,
    GameState before, {
    required bool tracking,
  }) {
    final object = data is Map ? data : null;
    switch (event.path) {
      case _port:
        _setWarehouse(
          _indexedMaterial(object?['api_material']),
          event.capturedAt,
        );
        return false;
      case _material:
        _setWarehouse(_indexedMaterial(data), event.capturedAt);
        return false;
      case _charge:
        return _recordCharge(object, before, event.capturedAt, tracking);
      case _repairStart:
        return _recordRepair(event, before, tracking);
      case _repairSpeed:
        final dockId = _wireInt(event.requestParams['api_ndock_id']);
        final dock = before.repairDocks
            .where((dock) => dock.id == dockId && dock.isRepairing)
            .firstOrNull;
        if (dock == null) {
          return tracking &&
              !_acceleratedDocks.contains(dockId) &&
              _markIncomplete();
        }
        _acceleratedDocks.add(dock.id);
        return tracking &&
            _addRepair(dock.shipId, const SortieResourceAmounts(buckets: 1));
      case _practice:
      case _missionStart:
        final deckId =
            _wireInt(event.requestParams['api_deck_id']) ??
            _wireInt(object?['api_deck_id']);
        final fleet = before.fleets
            .where((fleet) => fleet.id == deckId)
            .firstOrNull;
        var changed = false;
        for (final id in fleet?.shipIds ?? const <int>[]) {
          changed = _invalidatePending(id) || changed;
        }
        return changed;
      case final path when _rosterPaths.contains(path):
        _observeRepairQuotes(
          data is List
              ? data
              : object?['api_ship_data'] ??
                    object?['api_ship'] ??
                    object?['api_ship_data_list'],
        );
        return false;
      case final path when _equipmentPaths.contains(path):
        final affected = <int>{
          ?_wireInt(event.requestParams['api_id']),
          ?_wireInt(event.requestParams['api_ship_id']),
          ?_wireInt(event.requestParams['api_set_ship']),
          ?_wireInt(event.requestParams['api_unset_ship']),
          ...?_shipRows(_actionShipRows(object?['api_ship_data']))?.keys,
        };
        var changed = false;
        for (final id in affected) {
          if (_planeDebt.remove(id) == null) continue;
          final row = _ships[id]!;
          changed =
              _put(
                id,
                row._with(
                  pending: row.pending._with(_SupplyResource.bauxite, 0),
                  incomplete: true,
                ),
              ) ||
              changed;
        }
        return changed;
      case final path when _materialChangePaths.contains(path):
        _setWarehouse(const {}, event.capturedAt);
        return false;
      default:
        return false;
    }
  }

  bool _recordCharge(Map? data, GameState before, DateTime at, bool tracking) {
    final past = _warehouseAt;
    final warehouse = _warehouse;
    // The client only treats api_use_bou as a flag. Use the stockpile values
    // and actual per-slot replenishment to verify bauxite spending.
    final after = _positionalMaterial(data?['api_material']);
    _setWarehouse(after, at);
    final rows = _shipRows(data?['api_ship']);
    var changed = false;
    if (rows == null) {
      for (final id in _ships.keys.toList()) {
        changed = _invalidatePending(id) || changed;
      }
      return changed;
    }
    final chargeRows = <_ChargeRow>[
      for (final entry in rows.entries)
        (
          id: entry.key,
          ship: before.ships[entry.key],
          after: _wireStock(entry.value),
          planeRefill: _refilledPlanes(before.ships[entry.key], entry.value),
        ),
    ];
    final fresh =
        past != null &&
        !at.isBefore(past) &&
        at.difference(past) <= const Duration(minutes: 2);
    for (final resource in _SupplyResource.values) {
      final type = resource.resource;
      final from = warehouse[type];
      final to = after[type];
      final debit =
          fresh &&
              from != null &&
              to != null &&
              before.resource(type) == from &&
              to <= from
          ? from - to
          : null;
      changed =
          _reconcileCharge(resource, chargeRows, before, debit, tracking) ||
          changed;
    }
    return changed;
  }

  bool _reconcileCharge(
    _SupplyResource resource,
    List<_ChargeRow> rows,
    GameState before,
    int? debit,
    bool tracking,
  ) {
    final candidates = <int, int?>{};
    final eligible = <int>{};
    var changed = false;
    for (final row in rows) {
      final ship = row.ship;
      final refill = switch (resource) {
        _SupplyResource.fuel => _difference(row.after.fuel, ship?.currentFuel),
        _SupplyResource.ammo => _difference(row.after.ammo, ship?.currentAmmo),
        _SupplyResource.bauxite =>
          row.planeRefill == null ? null : _planeValue(row.planeRefill!.counts),
      };
      candidates[row.id] = refill == null
          ? null
          : resource == _SupplyResource.bauxite ||
                ship == null ||
                ship.level <= 99 ||
                refill == 0
          ? refill
          : (refill * 85 ~/ 100).clamp(1, refill);
      final prior = _ships[row.id];
      final owed = prior?.pending._for(resource) ?? 0;
      if (prior == null || owed == 0 || refill == 0) continue;

      final master = before.masterShips[ship?.masterId];
      final cleanDeficit = switch (resource) {
        _SupplyResource.fuel =>
          master != null && master.maxFuel - ship!.currentFuel == owed,
        _SupplyResource.ammo =>
          master != null && master.maxAmmo - ship!.currentAmmo == owed,
        _SupplyResource.bauxite => _matchesPlaneDebt(row, before, master),
      };
      final reconciled = cleanDeficit && refill != null && refill <= owed;
      if (reconciled) eligible.add(row.id);
      if (resource == _SupplyResource.bauxite) _planeDebt.remove(row.id);
      changed =
          _put(
            row.id,
            prior._with(
              pending: prior.pending._with(
                resource,
                reconciled ? owed - refill : 0,
              ),
              incomplete:
                  prior.incomplete ||
                  (tracking &&
                      (refill == null || (refill <= owed && !reconciled))),
            ),
          ) ||
          changed;
    }
    if (!tracking || eligible.isEmpty) return changed;
    final balanced =
        debit != null &&
        candidates.values.every((value) => value != null) &&
        candidates.values.fold(0, (sum, value) => sum + value!) == debit;
    if (balanced) {
      for (final id in eligible) {
        final spending = _ships[id] ?? const SortieShipResourceSpending();
        final amount = candidates[id]!;
        changed =
            _put(
              id,
              spending._with(
                supply:
                    spending.supply +
                    const SortieResourceAmounts()._with(resource, amount),
              ),
            ) ||
            changed;
      }
    } else {
      // The observed stockpile difference is not a confirmed per-ship debit.
      // Keep it separate only when all possible contributors are in scope.
      if (debit != null &&
          debit > 0 &&
          candidates.entries.every(
            (entry) => entry.value == 0 || eligible.contains(entry.key),
          )) {
        _unallocated += const SortieResourceAmounts()._with(resource, debit);
        changed = true;
      }
      for (final id in eligible) {
        final spending = _ships[id] ?? const SortieShipResourceSpending();
        changed = _put(id, spending._with(incomplete: true)) || changed;
      }
    }
    return changed;
  }

  bool _matchesPlaneDebt(_ChargeRow row, GameState before, MasterShip? master) {
    final pending = _planeDebt[row.id];
    final refill = row.planeRefill;
    final ship = row.ship;
    if (pending == null ||
        refill == null ||
        ship == null ||
        !_sameList(pending.slots, refill.slots) ||
        !_sameList(pending.counts, refill.counts)) {
      return false;
    }
    final capacities = ship.maxSlotCounts.isNotEmpty
        ? ship.maxSlotCounts
        : master?.slotCapacities ?? const <int>[];
    for (var index = 0; index < refill.counts.length; index++) {
      if (refill.counts[index] == 0) continue;
      final item = before.slotItems[refill.slots[index]];
      final type = before.masterSlotItems[item?.masterSlotItemId]?.type;
      final capacity = type != null && type.length > 2 && type[2] == 41
          ? 1 // Large flying boats occupy a single aircraft position.
          : index < capacities.length
          ? capacities[index]
          : null;
      if (capacity == null ||
          ship.onSlot[index] + refill.counts[index] != capacity) {
        return false;
      }
    }
    return true;
  }

  bool _recordRepair(CapturedApiEvent event, GameState before, bool tracking) {
    final id = _wireInt(event.requestParams['api_ship_id']);
    final dock = _wireInt(event.requestParams['api_ndock_id']);
    final instant = _wireInt(event.requestParams['api_highspeed']);
    final ship = before.ships[id];
    if (ship == null ||
        id == null ||
        dock == null ||
        dock <= 0 ||
        (instant != 0 && instant != 1)) {
      _setWarehouse(const {}, event.capturedAt);
      return tracking && _markIncomplete();
    }
    if ((ship.maxHp > 0 && ship.currentHp >= ship.maxHp) ||
        before.repairDocks.any(
          (entry) =>
              entry.id == dock && entry.shipId == id && entry.isRepairing,
        )) {
      return false;
    }
    _acceleratedDocks.remove(dock);
    final quote = _repairQuotes.remove(id);
    final freshQuote =
        quote != null &&
        quote.hp == ship.currentHp &&
        quote.fuel == ship.repairFuelCost &&
        quote.steel == ship.repairSteelCost;
    final fuel = freshQuote ? quote.fuel : null;
    final steel = freshQuote ? quote.steel : null;
    if (_warehouse[GameResourceType.fuel] case final balance?) {
      if (fuel != null &&
          balance >= fuel &&
          before.resource(GameResourceType.fuel) == balance) {
        _warehouse = {..._warehouse, GameResourceType.fuel: balance - fuel};
      } else {
        _warehouse = {..._warehouse}..remove(GameResourceType.fuel);
      }
    }
    if (!tracking) return false;
    return _addRepair(
      id,
      SortieResourceAmounts(
        fuel: fuel ?? 0,
        steel: steel ?? 0,
        buckets: instant == 1 ? 1 : 0,
      ),
      incomplete: fuel == null || steel == null,
    );
  }

  void _observeRepairQuotes(Object? value) {
    final rows = _shipRows(value);
    if (rows == null) return;
    for (final entry in rows.entries) {
      final row = entry.value;
      final hp = _wireInt(row['api_nowhp']);
      if (!row.containsKey('api_ndock_item')) {
        if (hp != null && _repairQuotes[entry.key]?.hp != hp) {
          _repairQuotes.remove(entry.key);
        }
        continue;
      }
      final costs = _numberList(row['api_ndock_item']);
      if (costs != null && (costs.length == 2 || costs.isEmpty) && hp != null) {
        _repairQuotes[entry.key] = (
          hp: hp,
          fuel: costs.isEmpty ? 0 : costs.first,
          steel: costs.isEmpty ? 0 : costs.last,
        );
      } else {
        _repairQuotes.remove(entry.key);
      }
    }
  }

  void _setWarehouse(Map<GameResourceType, int> values, DateTime at) {
    _warehouse = values;
    _warehouseAt = values.isEmpty ? null : at;
  }

  bool _addRepair(
    int id,
    SortieResourceAmounts amounts, {
    bool incomplete = false,
  }) {
    final previous = _ships[id] ?? const SortieShipResourceSpending();
    return _put(
      id,
      previous._with(
        repair: previous.repair + amounts,
        incomplete: previous.incomplete || incomplete,
      ),
    );
  }

  bool _invalidatePending(int id) {
    final previous = _ships[id];
    if (previous == null || previous.pending.isEmpty) return false;
    _planeDebt.remove(id);
    return _put(
      id,
      previous._with(pending: const SortieResourceAmounts(), incomplete: true),
    );
  }

  bool _markIncomplete() {
    final changed = !_incomplete;
    _incomplete = true;
    return changed;
  }

  bool _put(int id, SortieShipResourceSpending next) {
    if (next._isEmpty) return _ships.remove(id) != null;
    final old = _ships[id];
    if (old != null &&
        old.supply == next.supply &&
        old.repair == next.repair &&
        old.pending == next.pending &&
        old.incomplete == next.incomplete) {
      return false;
    }
    _ships[id] = next;
    return true;
  }
}

const _maxStoredAmount = 9007199254740991;

int _bounded(int value) => value.clamp(0, _maxStoredAmount);

int _storedInt(Object? value) {
  if (value is int && value >= 0 && value <= _maxStoredAmount) return value;
  throw const FormatException('Invalid stored resource integer');
}

int? _wireInt(Object? value) {
  final number = value is int
      ? value
      : value is String
      ? int.tryParse(value)
      : null;
  return number != null && number >= 0 && number <= _maxStoredAmount
      ? number
      : null;
}

List<int>? _numberList(Object? value, {bool slots = false}) {
  if (value is! List) return null;
  final numbers = <int>[];
  for (final element in value) {
    final number = slots && element == -1 ? -1 : _wireInt(element);
    if (number == null) return null;
    numbers.add(number);
  }
  return numbers;
}

bool _sameList(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

_PlaneStock? _planeStock(List<int>? slots, List<int>? counts) =>
    slots != null && counts != null && slots.length == counts.length
    ? (slots: slots, counts: counts)
    : null;

_SupplyStock _ownedStock(OwnedShip ship) => (
  fuel: _wireInt(ship.currentFuel),
  ammo: _wireInt(ship.currentAmmo),
  aircraft: _planeStock(List.of(ship.slotIds), List.of(ship.onSlot)),
);

_SupplyStock _sortieStock(OwnedShip ship, MasterShip? master) {
  final stock = _ownedStock(ship);
  return (
    fuel: ship.currentFuel > 0 || (master?.maxFuel ?? 0) > 0
        ? stock.fuel
        : null,
    ammo: ship.currentAmmo > 0 || (master?.maxAmmo ?? 0) > 0
        ? stock.ammo
        : null,
    aircraft: stock.aircraft,
  );
}

bool _hasAircraftBaseline(_SupplyStock stock) =>
    stock.aircraft?.counts.any((count) => count > 0) ?? false;

bool _hasSupplyBaseline(_SupplyStock stock) =>
    stock.fuel != null || stock.ammo != null || _hasAircraftBaseline(stock);

_SupplyStock _wireStock(Map row) => (
  fuel: _wireInt(row['api_fuel']),
  ammo: _wireInt(row['api_bull']),
  aircraft: _planeStock(
    _numberList(row['api_slot'], slots: true),
    _numberList(row['api_onslot']),
  ),
);

_PlaneStock? _refilledPlanes(OwnedShip? ship, Map row) {
  if (ship == null) return null;
  final before = _ownedStock(ship).aircraft;
  final after = _planeStock(ship.slotIds, _numberList(row['api_onslot']));
  return _planeDifference(after, before);
}

_PlaneStock? _planeDifference(_PlaneStock? more, _PlaneStock? less) {
  if (more == null || less == null || !_sameList(more.slots, less.slots)) {
    return null;
  }
  final difference = <int>[];
  for (var i = 0; i < more.counts.length; i++) {
    final delta = _difference(more.counts[i], less.counts[i]);
    if (delta == null) return null;
    difference.add(delta);
  }
  return (slots: more.slots, counts: difference);
}

int _planeValue(List<int> aircraft) =>
    aircraft.fold(0, (sum, count) => _bounded(sum + count * 5));

int? _difference(int? more, int? less) =>
    more == null || less == null || more < less ? null : more - less;

int? _accumulateDeficit(int previous, int? start, int? end) {
  final difference = _difference(start, end);
  return difference == null ? null : _bounded(previous + difference);
}

Map<int, Map>? _shipRows(Object? value) {
  if (value is! List) return null;
  final result = <int, Map>{};
  for (final row in value) {
    if (row is! Map) return null;
    final id = _wireInt(row['api_id']);
    if (id == null || id <= 0 || result.containsKey(id)) return null;
    result[id] = row;
  }
  return result;
}

Object? _actionShipRows(Object? value) =>
    value is Map ? value.values.toList() : value;

Map<GameResourceType, int> _indexedMaterial(Object? value) {
  final result = <GameResourceType, int>{};
  if (value is! List) return result;
  for (final row in value) {
    if (row is! Map) return const {};
    final id = _wireInt(row['api_id']);
    final type = id == null ? null : GameResourceType.fromApiId(id);
    if (type == null) continue;
    final amount = _wireInt(row['api_value']);
    if (amount == null || result.containsKey(type)) return const {};
    result[type] = amount;
  }
  return result;
}

Map<GameResourceType, int> _positionalMaterial(Object? value) {
  if (value is! List || value.length < 4) return const {};
  final result = <GameResourceType, int>{};
  for (final type in GameResourceType.values.take(4)) {
    final amount = _wireInt(value[type.apiId - 1]);
    if (amount == null) return const {};
    result[type] = amount;
  }
  return result;
}
