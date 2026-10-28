import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../localization/game_name_localizations.dart';
import 'ship_status_style.dart';

List<PreSortieWarning> generatePreSortieWarnings(
  BuildContext context,
  GameState state,
  AppLocalizations l10n,
) {
  final warnings = <PreSortieWarning>[];
  if (state.fleets.isEmpty || !state.hasMasterData) return warnings;

  // Check non-expedition fleets (usually fleets at port)
  for (final fleet in state.fleets) {
    if (fleet.mission.isActive || fleet.shipIds.isEmpty) continue;

    bool hasTaiha = false;
    bool hasUnresupplied = false;
    bool hasFatigue = false;
    final mainEquipmentNames = <String>[];
    final extraEquipmentNames = <String>[];

    for (final shipId in fleet.shipIds) {
      final ship = state.ships[shipId];
      if (ship == null) continue;

      if (isShipHeavilyDamaged(currentHp: ship.currentHp, maxHp: ship.maxHp)) {
        hasTaiha = true;
      }

      final masterShip = state.masterShips[ship.masterId];
      if (masterShip != null) {
        if (ship.currentFuel < masterShip.maxFuel ||
            ship.currentAmmo < masterShip.maxAmmo) {
          hasUnresupplied = true;
        }
        if (ship.condition < 40) {
          hasFatigue = true;
        }
        final filledMainSlots = ship.slotIds.where((id) => id > 0).length;
        if (filledMainSlots < masterShip.slotCount) {
          mainEquipmentNames.add(
            gameNames(context).shipName(masterShip.name, shipId: masterShip.id),
          );
        }
        if (ship.extraSlotId == -1) {
          extraEquipmentNames.add(
            gameNames(context).shipName(masterShip.name, shipId: masterShip.id),
          );
        }
      }
    }

    if (hasTaiha) {
      warnings.add(
        PreSortieWarning(
          fleetId: fleet.id,
          message: l10n.preSortieCriticalWarning(fleet.name),
          kind: PreSortieWarningKind.critical,
        ),
      );
    }

    if (hasUnresupplied) {
      warnings.add(
        PreSortieWarning(
          fleetId: fleet.id,
          message: l10n.preSortieSupplyWarning(fleet.name),
          kind: PreSortieWarningKind.supply,
        ),
      );
    }

    if (hasFatigue) {
      warnings.add(
        PreSortieWarning(
          fleetId: fleet.id,
          message: l10n.preSortieFatigueWarning(fleet.name),
          kind: PreSortieWarningKind.fatigue,
        ),
      );
    }

    if (mainEquipmentNames.isNotEmpty) {
      warnings.add(
        PreSortieWarning(
          fleetId: fleet.id,
          message: l10n.preSortieMainEquipmentWarning(
            fleet.name,
            mainEquipmentNames.join('、'),
          ),
          kind: PreSortieWarningKind.mainEquipment,
        ),
      );
    }

    if (extraEquipmentNames.isNotEmpty) {
      warnings.add(
        PreSortieWarning(
          fleetId: fleet.id,
          message: l10n.preSortieExtraEquipmentWarning(
            fleet.name,
            extraEquipmentNames.join('、'),
          ),
          kind: PreSortieWarningKind.extraEquipment,
        ),
      );
    }
  }

  return warnings;
}

class PreSortieWarning {
  const PreSortieWarning({
    required this.fleetId,
    required this.message,
    required this.kind,
  });
  final int fleetId;
  final String message;
  final PreSortieWarningKind kind;
}

enum PreSortieWarningKind {
  critical,
  supply,
  fatigue,
  mainEquipment,
  extraEquipment;

  String get keyName => switch (this) {
    critical => 'critical',
    supply => 'supply',
    fatigue => 'fatigue',
    mainEquipment => 'main-equipment',
    extraEquipment => 'extra-equipment',
  };

  Color get foreground => switch (this) {
    critical => const Color(0xfff44336),
    _ => const Color(0xffff9800),
  };

  IconData get icon => switch (this) {
    critical => Icons.warning_rounded,
    _ => Icons.info_outline_rounded,
  };
}
