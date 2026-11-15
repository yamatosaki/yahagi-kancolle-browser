import 'package:flutter/foundation.dart' show mergeSort;

import '../game_state/game_state.dart';
import '../inventory/owned_inventory_projection.dart';
import 'improvement_dataset.dart';

enum ImprovementEvolutionFilter { all, evolvable, notEvolvable }

const int improvementAllWeekdays = 0;

class ImprovementPlannerRow {
  const ImprovementPlannerRow({
    required this.entry,
    required this.secretaryLabels,
    required this.secretarySchedules,
    required this.upgradeRoutes,
  });

  final ImprovementEntry entry;
  final List<String> secretaryLabels;
  final List<ImprovementSecretarySchedule> secretarySchedules;
  final List<ImprovementUpgradeRoute> upgradeRoutes;
}

class ImprovementSecretarySchedule {
  const ImprovementSecretarySchedule({
    required this.weekdays,
    required this.secretaryLabels,
  });

  final Set<int> weekdays;
  final List<String> secretaryLabels;
}

class ImprovementUpgradeRoute {
  const ImprovementUpgradeRoute({
    required this.upgrade,
    required this.secretaryLabels,
    required this.secretarySchedules,
  });

  final ImprovementUpgrade upgrade;
  final List<String> secretaryLabels;
  final List<ImprovementSecretarySchedule> secretarySchedules;
}

int jstWeekday(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 9)).weekday;

List<ImprovementPlannerRow> projectImprovementRows(
  ImprovementDataset dataset, {
  required int weekday,
  Map<int, MasterSlotItem> equipmentMasters = const <int, MasterSlotItem>{},
  Map<int, MasterShip> shipMasters = const <int, MasterShip>{},
  String query = '',
  String Function(String)? equipmentNameResolver,
  EquipmentInventoryCategory equipmentCategory = EquipmentInventoryCategory.all,
  Set<int> favoriteEquipmentIds = const <int>{},
  bool favoritesOnly = false,
  ImprovementEvolutionFilter evolutionFilter = ImprovementEvolutionFilter.all,
}) {
  final rows = <ImprovementPlannerRow>[];
  final normalizedQuery = query.trim().toLowerCase();
  final allWeekdays = weekday == improvementAllWeekdays;
  final shipNamesBySortNo = <int, String>{};
  final ambiguousShipSortNos = <int>{};
  for (final master in shipMasters.values) {
    final sortNo = master.sortNo;
    if (sortNo <= 0 || ambiguousShipSortNos.contains(sortNo)) continue;
    if (shipNamesBySortNo.containsKey(sortNo)) {
      shipNamesBySortNo.remove(sortNo);
      ambiguousShipSortNos.add(sortNo);
    } else {
      shipNamesBySortNo[sortNo] = master.name;
    }
  }
  for (final entry in dataset.entries) {
    final master = equipmentMasters[entry.equipmentId];
    if (normalizedQuery.isNotEmpty &&
        !(master?.name.toLowerCase().contains(normalizedQuery) ?? false) &&
        !(master != null &&
            (equipmentNameResolver
                    ?.call(master.name)
                    .toLowerCase()
                    .contains(normalizedQuery) ??
                false))) {
      continue;
    }
    if (equipmentCategory != EquipmentInventoryCategory.all &&
        (master == null ||
            equipmentInventoryCategoryFor(master) != equipmentCategory)) {
      continue;
    }
    if (favoritesOnly && !favoriteEquipmentIds.contains(entry.equipmentId)) {
      continue;
    }
    final dayArrangements = entry.arrangements
        .where(
          (arrangement) => allWeekdays
              ? arrangement.weekdays.isNotEmpty
              : arrangement.weekdays.contains(weekday),
        )
        .toList(growable: false);
    final labels = _secretaryLabels(
      dayArrangements,
      includeWeekdays: allWeekdays,
      shipNamesBySortNo: shipNamesBySortNo,
    );
    final schedules = _secretarySchedules(
      dayArrangements,
      entry.arrangements,
      shipNamesBySortNo,
    );
    if (labels.isNotEmpty) {
      final routes = <ImprovementUpgradeRoute>[];
      for (final upgrade in entry.upgrades) {
        final routeArrangements = <ImprovementArrangement>[
          for (final arrangement in dayArrangements)
            if (upgrade.routeKind == null ||
                arrangement.routeKind == null ||
                arrangement.routeKind == upgrade.routeKind)
              arrangement,
        ];
        final routeSecretaries = _secretaryLabels(
          routeArrangements,
          includeWeekdays: allWeekdays,
          shipNamesBySortNo: shipNamesBySortNo,
        );
        final allRouteArrangements = entry.arrangements.where(
          (arrangement) =>
              upgrade.routeKind == null ||
              arrangement.routeKind == null ||
              arrangement.routeKind == upgrade.routeKind,
        );
        final routeSchedules = _secretarySchedules(
          routeArrangements,
          allRouteArrangements,
          shipNamesBySortNo,
        );
        if (routeSecretaries.isNotEmpty) {
          routes.add(
            ImprovementUpgradeRoute(
              upgrade: upgrade,
              secretaryLabels: List<String>.unmodifiable(routeSecretaries),
              secretarySchedules: routeSchedules,
            ),
          );
        }
      }
      final evolvableToday = routes.isNotEmpty;
      if (evolutionFilter == ImprovementEvolutionFilter.evolvable &&
          !evolvableToday) {
        continue;
      }
      if (evolutionFilter == ImprovementEvolutionFilter.notEvolvable &&
          evolvableToday) {
        continue;
      }
      rows.add(
        ImprovementPlannerRow(
          entry: entry,
          secretaryLabels: List.unmodifiable(labels),
          secretarySchedules: schedules,
          upgradeRoutes: List.unmodifiable(routes),
        ),
      );
    }
  }
  mergeSort(
    rows,
    compare: (left, right) => _compareEquipmentOrder(
      equipmentMasters[left.entry.equipmentId],
      equipmentMasters[right.entry.equipmentId],
    ),
  );
  return List.unmodifiable(rows);
}

int _compareEquipmentOrder(MasterSlotItem? left, MasterSlotItem? right) {
  // Missing master data leaves recipes at the end in their dataset order.
  if (left == null) return right == null ? 0 : 1;
  if (right == null) return -1;

  // Match the default order of OwnedInventoryProjection.equipmentGroups.
  final leftType = left.type;
  final rightType = right.type;
  final byBroad = (leftType.isNotEmpty ? leftType[0] : 0).compareTo(
    rightType.isNotEmpty ? rightType[0] : 0,
  );
  if (byBroad != 0) return byBroad;
  final byFine = (leftType.length > 2 ? leftType[2] : 0).compareTo(
    rightType.length > 2 ? rightType[2] : 0,
  );
  if (byFine != 0) return byFine;
  final leftSort = left.sortNo > 0 ? left.sortNo : left.id;
  final rightSort = right.sortNo > 0 ? right.sortNo : right.id;
  final bySort = leftSort.compareTo(rightSort);
  return bySort != 0 ? bySort : left.id.compareTo(right.id);
}

List<ImprovementSecretarySchedule> _secretarySchedules(
  Iterable<ImprovementArrangement> visibleArrangements,
  Iterable<ImprovementArrangement> allArrangements,
  Map<int, String> shipNamesBySortNo,
) {
  final weekdaysBySecretary = <String, Set<int>>{};
  for (final arrangement in allArrangements) {
    final name = _resolvedSecretaryLabel(
      arrangement.secretaryLabel,
      shipNamesBySortNo,
    );
    weekdaysBySecretary
        .putIfAbsent(name, () => <int>{})
        .addAll(arrangement.weekdays.where((day) => day >= 1 && day <= 7));
  }
  final namesBySchedule = <int, List<String>>{};
  final visibleNames = <String>{};
  for (final arrangement in visibleArrangements) {
    final name = _resolvedSecretaryLabel(
      arrangement.secretaryLabel,
      shipNamesBySortNo,
    );
    if (!visibleNames.add(name)) continue;
    final weekdays = weekdaysBySecretary[name] ?? <int>{};
    final mask = weekdays.fold<int>(0, (mask, day) => mask | (1 << day));
    namesBySchedule.putIfAbsent(mask, () => <String>[]).add(name);
  }
  return List<ImprovementSecretarySchedule>.unmodifiable(
    <ImprovementSecretarySchedule>[
      for (final group in namesBySchedule.entries)
        ImprovementSecretarySchedule(
          weekdays: Set<int>.unmodifiable(<int>{
            for (var day = 1; day <= 7; day++)
              if (group.key & (1 << day) != 0) day,
          }),
          secretaryLabels: List<String>.unmodifiable(group.value),
        ),
    ],
  );
}

List<String> _secretaryLabels(
  Iterable<ImprovementArrangement> arrangements, {
  required bool includeWeekdays,
  required Map<int, String> shipNamesBySortNo,
}) {
  final weekdaysBySecretary = <String, Set<int>>{};
  for (final arrangement in arrangements) {
    final secretaryLabel = _resolvedSecretaryLabel(
      arrangement.secretaryLabel,
      shipNamesBySortNo,
    );
    weekdaysBySecretary
        .putIfAbsent(secretaryLabel, () => <int>{})
        .addAll(arrangement.weekdays);
  }
  return <String>[
    for (final entry in weekdaysBySecretary.entries)
      if (includeWeekdays)
        '${entry.key}${_weekdayLabels(entry.value).join()}'
      else
        entry.key,
  ];
}

String _resolvedSecretaryLabel(
  String label,
  Map<int, String> shipNamesBySortNo,
) {
  final match = RegExp(r'^#(\d+)$').firstMatch(label);
  if (match == null) return label;
  final sortNo = int.tryParse(match.group(1)!);
  return sortNo == null ? label : shipNamesBySortNo[sortNo] ?? label;
}

List<String> _weekdayLabels(Set<int> weekdays) {
  const labels = <String>['①', '②', '③', '④', '⑤', '⑥', '⑦'];
  final sorted = weekdays.where((day) => day >= 1 && day <= 7).toList()..sort();
  return <String>[for (final day in sorted) labels[day - 1]];
}
