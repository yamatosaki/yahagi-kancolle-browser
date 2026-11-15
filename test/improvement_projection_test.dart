import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';

const _emptyStage = ImprovementStageCost(
  developmentMin: 0,
  developmentMax: 0,
  improvementMin: 0,
  improvementMax: 0,
  items: <ImprovementConsumeItem>[],
);

void main() {
  final dataset = ImprovementDataset(
    version: const ImprovementDatasetVersion(
      dataVersion: 'test',
      commitSha: '',
    ),
    entries: <ImprovementEntry>[
      _entry(1, evolvable: true),
      _entry(2, evolvable: false),
      _entry(3, evolvable: true),
      _entry(4, evolvable: true, evolutionAvailableToday: false),
    ],
  );
  const equipmentMasters = <int, MasterSlotItem>{
    1: MasterSlotItem(id: 1, name: 'Alpha Gun', type: <int>[1, 0, 1, 1]),
    2: MasterSlotItem(id: 2, name: 'Beta Torpedo', type: <int>[2, 0, 5, 5]),
    3: MasterSlotItem(id: 3, name: 'Gamma Gun', type: <int>[1, 0, 1, 1]),
    4: MasterSlotItem(id: 4, name: 'Delta Radar', type: <int>[0, 0, 12, 11]),
  };

  group('owned equipment order', () {
    const masters = <int, MasterSlotItem>{
      2: MasterSlotItem(id: 2, name: 'Twin Medium Gun', type: [1, 0, 2]),
      11: MasterSlotItem(id: 11, name: 'Single Gun', type: [1, 0, 1]),
      12: MasterSlotItem(
        id: 12,
        name: 'Twin Gun B',
        sortNo: 20,
        type: [1, 0, 1],
      ),
      13: MasterSlotItem(
        id: 13,
        name: 'Twin Gun A',
        sortNo: 10,
        type: [1, 0, 1],
      ),
      14: MasterSlotItem(
        id: 14,
        name: 'Single Gun A',
        sortNo: 10,
        type: [1, 0, 1],
      ),
      21: MasterSlotItem(id: 21, name: 'Radar', sortNo: 1, type: [6, 0, 12]),
    };
    final orderedDataset = ImprovementDataset(
      version: dataset.version,
      entries: [
        for (final id in [2, 3, 11, 12, 13, 14, 21])
          _entry(
            id,
            evolvable: false,
            weekday: id == 14 ? DateTime.tuesday : DateTime.monday,
          ),
      ],
    );

    Iterable<int> equipmentIds({
      int weekday = improvementAllWeekdays,
      Set<int> favorites = const {},
      String query = '',
    }) => projectImprovementRows(
      orderedDataset,
      weekday: weekday,
      equipmentMasters: masters,
      favoriteEquipmentIds: favorites,
      favoritesOnly: favorites.isNotEmpty,
      query: query,
    ).map((row) => row.entry.equipmentId);

    test('matches the inventory and keeps unowned and unknown recipes', () {
      final inventoryIds = OwnedInventoryProjection(
        GameState(
          masterSlotItems: masters,
          slotItems: {
            for (final id in [2, 11, 12, 14, 21])
              id: OwnedSlotItem(id: id, masterId: id),
          },
        ),
      ).equipmentGroups().map((group) => group.master.id);
      final improvementIds = equipmentIds();

      expect(improvementIds, [13, 14, 11, 12, 2, 21, 3]);
      expect(improvementIds.where(inventoryIds.contains), inventoryIds);
    });

    test('keeps inventory order when selecting a weekday', () {
      expect(equipmentIds(weekday: DateTime.monday), [13, 11, 12, 2, 21, 3]);
      expect(equipmentIds(weekday: DateTime.tuesday), [14]);
    });

    test('keeps inventory order when showing favorites', () {
      expect(equipmentIds(favorites: {2, 13, 14, 21}), [13, 14, 2, 21]);
    });

    test('keeps inventory order when searching for equipment', () {
      expect(equipmentIds(query: ' twin '), [13, 12, 2]);
    });
  });

  test('filters daily rows by evolvable state', () {
    expect(
      projectImprovementRows(
        dataset,
        weekday: DateTime.monday,
        evolutionFilter: ImprovementEvolutionFilter.all,
      ).map((row) => row.entry.equipmentId),
      <int>[1, 2, 3, 4],
    );
    expect(
      projectImprovementRows(
        dataset,
        weekday: DateTime.monday,
        evolutionFilter: ImprovementEvolutionFilter.evolvable,
      ).map((row) => row.entry.equipmentId),
      <int>[1, 3],
    );
    expect(
      projectImprovementRows(
        dataset,
        weekday: DateTime.monday,
        evolutionFilter: ImprovementEvolutionFilter.notEvolvable,
      ).map((row) => row.entry.equipmentId),
      <int>[2, 4],
    );
  });

  test('combines favorite-only and evolution filters', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      favoriteEquipmentIds: const <int>{2, 3},
      favoritesOnly: true,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );
    expect(rows.map((row) => row.entry.equipmentId), <int>[3]);
  });

  test('searches equipment names with trimmed case-insensitive text', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      equipmentMasters: equipmentMasters,
      query: ' beta ',
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[2]);
  });

  test(
    'search accepts translated equipment while retaining original names',
    () {
      const masters = <int, MasterSlotItem>{
        1: MasterSlotItem(id: 1, name: '小口径主砲', type: <int>[1, 0, 1, 1]),
      };
      String translated(String original) =>
          original == '小口径主砲' ? 'Small Main Gun' : original;
      for (final query in [' small main ', '小口径']) {
        final rows = projectImprovementRows(
          dataset,
          weekday: DateTime.monday,
          equipmentMasters: masters,
          query: query,
          equipmentNameResolver: translated,
        );
        expect(rows.map((row) => row.entry.equipmentId), [1]);
      }
      expect(masters[1]!.name, '小口径主砲');
    },
  );

  test('uses owned inventory equipment categories', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      equipmentMasters: equipmentMasters,
      equipmentCategory: EquipmentInventoryCategory.mainGun,
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[1, 3]);
  });

  test('combines search category and evolution filters', () {
    final rows = projectImprovementRows(
      dataset,
      weekday: DateTime.monday,
      equipmentMasters: equipmentMasters,
      query: 'gamma',
      equipmentCategory: EquipmentInventoryCategory.mainGun,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[3]);
  });

  test('all weekdays keeps one row and merges weekdays per secretary', () {
    final allWeekdaysDataset = ImprovementDataset(
      version: const ImprovementDatasetVersion(
        dataVersion: 'test',
        commitSha: '',
      ),
      entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: false)],
    );

    final rows = projectImprovementRows(
      allWeekdaysDataset,
      weekday: improvementAllWeekdays,
    );

    expect(rows, hasLength(1));
    expect(rows.single.secretaryLabels, <String>['明石①⑤', '夕张①②③④⑤⑥⑦']);
    expect(rows.single.secretarySchedules, hasLength(2));
    expect(rows.single.secretarySchedules[0].secretaryLabels, <String>['明石']);
    expect(rows.single.secretarySchedules[0].weekdays, <int>{1, 5});
    expect(rows.single.secretarySchedules[1].secretaryLabels, <String>['夕张']);
    expect(rows.single.secretarySchedules[1].weekdays, <int>{
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    });
  });

  test('specific weekday keeps secretary labels without weekday suffix', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: false)],
      ),
      weekday: DateTime.friday,
    );

    expect(rows.single.secretaryLabels, <String>['明石', '夕张']);
    expect(rows.single.secretarySchedules[0].weekdays, <int>{1, 5});
  });

  test('groups secretaries that share the same weekly schedule', () {
    final source = _multiWeekdayEntry(evolvable: false);
    final entry = ImprovementEntry(
      equipmentId: source.equipmentId,
      baseCost: source.baseCost,
      arrangements: <ImprovementArrangement>[
        ...source.arrangements,
        const ImprovementArrangement(
          secretaryId: 3,
          secretaryLabel: '大淀',
          weekdays: <int>{DateTime.monday, DateTime.friday},
        ),
      ],
      stage0: source.stage0,
      stage1: source.stage1,
      upgrades: source.upgrades,
    );
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[entry],
      ),
      weekday: improvementAllWeekdays,
    );

    expect(rows.single.secretarySchedules, hasLength(2));
    expect(rows.single.secretarySchedules.first.secretaryLabels, <String>[
      '明石',
      '大淀',
    ]);
    expect(rows.single.secretarySchedules.first.weekdays, <int>{1, 5});
  });

  test('resolves numeric secretary labels by ship sort number', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[
          ImprovementEntry(
            equipmentId: 10,
            baseCost: const ImprovementResourceCost(
              fuel: 0,
              ammo: 0,
              steel: 0,
              bauxite: 0,
            ),
            arrangements: <ImprovementArrangement>[
              ImprovementArrangement(
                secretaryId: 444,
                secretaryLabel: '#444',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
              ImprovementArrangement(
                secretaryId: 1,
                secretaryLabel: '明石',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
              ImprovementArrangement(
                secretaryId: 999,
                secretaryLabel: '#999',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
              ImprovementArrangement(
                secretaryId: 444,
                secretaryLabel: '#444改',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
            ],
            stage0: _emptyStage,
            stage1: _emptyStage,
            upgrades: const <ImprovementUpgrade>[],
          ),
        ],
      ),
      weekday: DateTime.monday,
      shipMasters: const <int, MasterShip>{
        444: MasterShip(id: 444, name: 'Aquila', shipTypeId: 11, sortNo: 244),
        644: MasterShip(id: 644, name: '桃', shipTypeId: 2, sortNo: 444),
      },
    );

    expect(rows.single.secretaryLabels, <String>['桃', '明石', '#999', '#444改']);
    expect(rows.single.secretaryLabels, isNot(contains('#444')));
    expect(rows.single.secretaryLabels, isNot(contains('Aquila')));
  });

  test('keeps numeric secretary label when ship sort number is ambiguous', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_secretaryEntry('#444', 444)],
      ),
      weekday: DateTime.monday,
      shipMasters: const <int, MasterShip>{
        644: MasterShip(id: 644, name: '桃', shipTypeId: 2, sortNo: 444),
        645: MasterShip(id: 645, name: '桃改', shipTypeId: 2, sortNo: 444),
      },
    );

    expect(rows.single.secretaryLabels, <String>['#444']);
  });

  test('keeps oversized numeric secretary label without throwing', () {
    const label = '#999999999999999999999999999999999999999999999999999999';
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_secretaryEntry(label, null)],
      ),
      weekday: DateTime.monday,
    );

    expect(rows.single.secretaryLabels, <String>[label]);
  });

  test('all weekdays is evolvable when any weekday has a valid route', () {
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: true)],
      ),
      weekday: improvementAllWeekdays,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );

    expect(rows, hasLength(1));
    expect(rows.single.upgradeRoutes.single.secretaryLabels, <String>[
      '明石①⑤',
      '夕张①②③④⑤⑥⑦',
    ]);
  });

  test('all weekdays combines search category favorite and evolution', () {
    const allEquipmentMasters = <int, MasterSlotItem>{
      10: MasterSlotItem(id: 10, name: 'Weekly Gun', type: <int>[1, 0, 1, 1]),
    };
    final rows = projectImprovementRows(
      ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[_multiWeekdayEntry(evolvable: true)],
      ),
      weekday: improvementAllWeekdays,
      equipmentMasters: allEquipmentMasters,
      query: ' weekly ',
      equipmentCategory: EquipmentInventoryCategory.mainGun,
      favoriteEquipmentIds: const <int>{10},
      favoritesOnly: true,
      evolutionFilter: ImprovementEvolutionFilter.evolvable,
    );

    expect(rows.map((row) => row.entry.equipmentId), <int>[10]);
  });
}

ImprovementEntry _secretaryEntry(String label, int? id) => ImprovementEntry(
  equipmentId: 10,
  baseCost: const ImprovementResourceCost(
    fuel: 0,
    ammo: 0,
    steel: 0,
    bauxite: 0,
  ),
  arrangements: <ImprovementArrangement>[
    ImprovementArrangement(
      secretaryId: id,
      secretaryLabel: label,
      weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
    ),
  ],
  stage0: _emptyStage,
  stage1: _emptyStage,
  upgrades: const <ImprovementUpgrade>[],
);

ImprovementEntry _multiWeekdayEntry({required bool evolvable}) =>
    ImprovementEntry(
      equipmentId: 10,
      baseCost: const ImprovementResourceCost(
        fuel: 0,
        ammo: 0,
        steel: 0,
        bauxite: 0,
      ),
      arrangements: <ImprovementArrangement>[
        ImprovementArrangement(
          secretaryId: 1,
          secretaryLabel: '明石',
          weekdays: Set<int>.unmodifiable(<int>{DateTime.friday}),
        ),
        ImprovementArrangement(
          secretaryId: 1,
          secretaryLabel: '明石',
          weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
        ),
        ImprovementArrangement(
          secretaryId: 2,
          secretaryLabel: '夕张',
          weekdays: Set<int>.unmodifiable(<int>{
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
          }),
        ),
      ],
      stage0: _emptyStage,
      stage1: _emptyStage,
      upgrades: evolvable
          ? const <ImprovementUpgrade>[
              ImprovementUpgrade(
                targetEquipmentId: 110,
                developmentMin: 0,
                developmentMax: 0,
                improvementMin: 0,
                improvementMax: 0,
                items: <ImprovementConsumeItem>[],
              ),
            ]
          : const <ImprovementUpgrade>[],
    );

ImprovementEntry _entry(
  int id, {
  required bool evolvable,
  bool evolutionAvailableToday = true,
  int weekday = DateTime.monday,
}) => ImprovementEntry(
  equipmentId: id,
  baseCost: const ImprovementResourceCost(
    fuel: 0,
    ammo: 0,
    steel: 0,
    bauxite: 0,
  ),
  arrangements: <ImprovementArrangement>[
    ImprovementArrangement(
      secretaryId: 1,
      secretaryLabel: '秘书舰',
      weekdays: Set<int>.unmodifiable(<int>{weekday}),
      routeKind: evolutionAvailableToday ? null : 'kind1',
    ),
  ],
  stage0: _emptyStage,
  stage1: _emptyStage,
  upgrades: evolvable
      ? <ImprovementUpgrade>[
          ImprovementUpgrade(
            targetEquipmentId: id + 100,
            developmentMin: 0,
            developmentMax: 0,
            improvementMin: 0,
            improvementMax: 0,
            items: const <ImprovementConsumeItem>[],
            routeKind: evolutionAvailableToday ? null : 'kind2',
          ),
        ]
      : const <ImprovementUpgrade>[],
);
