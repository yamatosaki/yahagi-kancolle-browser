import 'package:flutter/material.dart';
import 'dashboard_card.dart';
import 'ship_status_style.dart';

import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class PreSortieCheckSummary extends StatelessWidget {
  const PreSortieCheckSummary({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenFleet,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));
        final warnings = _generateWarnings(state, l10n);

        return DashboardCard(
          title: l10n.preSortieCheck,
          icon: const Icon(Icons.security_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (warnings.isEmpty)
                Center(
                  child: Text(
                    (AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('zh')))
                        .noSortieWarnings,
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ...warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Material(
                      key: Key(
                        'pre-sortie-warning-surface-${warning.fleetId}-${warning.kind.keyName}',
                      ),
                      color: warning.kind.foreground.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: warning.kind.foreground,
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key(
                          'pre-sortie-warning-${warning.fleetId}-${warning.kind.keyName}',
                        ),
                        onTap: () => onOpenFleet(warning.fleetId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                warning.kind.icon,
                                color: warning.kind.foreground,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  warning.message,
                                  style: TextStyle(
                                    color: warning.kind.foreground,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_PreSortieWarning> _generateWarnings(
    GameState state,
    AppLocalizations l10n,
  ) {
    final warnings = <_PreSortieWarning>[];
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

        if (isShipHeavilyDamaged(
          currentHp: ship.currentHp,
          maxHp: ship.maxHp,
        )) {
          hasTaiha = true;
        }

        final masterShip = state.masterShips[ship.masterId];
        if (masterShip != null) {
          if (ship.currentFuel < masterShip.maxFuel ||
              ship.currentAmmo < masterShip.maxAmmo) {
            hasUnresupplied = true;
          }
          if (ship.condition < 30) {
            hasFatigue = true;
          }
          final filledMainSlots = ship.slotIds.where((id) => id > 0).length;
          if (filledMainSlots < masterShip.slotCount) {
            mainEquipmentNames.add(masterShip.name);
          }
          if (ship.extraSlotId == -1) {
            extraEquipmentNames.add(masterShip.name);
          }
        }
      }

      if (hasTaiha) {
        warnings.add(
          _PreSortieWarning(
            fleetId: fleet.id,
            message: l10n.preSortieCriticalWarning(fleet.name),
            kind: _PreSortieWarningKind.critical,
          ),
        );
      }

      if (hasUnresupplied) {
        warnings.add(
          _PreSortieWarning(
            fleetId: fleet.id,
            message: l10n.preSortieSupplyWarning(fleet.name),
            kind: _PreSortieWarningKind.supply,
          ),
        );
      }

      if (hasFatigue) {
        warnings.add(
          _PreSortieWarning(
            fleetId: fleet.id,
            message: l10n.preSortieFatigueWarning(fleet.name),
            kind: _PreSortieWarningKind.fatigue,
          ),
        );
      }

      if (mainEquipmentNames.isNotEmpty) {
        warnings.add(
          _PreSortieWarning(
            fleetId: fleet.id,
            message: l10n.preSortieMainEquipmentWarning(
              fleet.name,
              mainEquipmentNames.join('、'),
            ),
            kind: _PreSortieWarningKind.mainEquipment,
          ),
        );
      }

      if (extraEquipmentNames.isNotEmpty) {
        warnings.add(
          _PreSortieWarning(
            fleetId: fleet.id,
            message: l10n.preSortieExtraEquipmentWarning(
              fleet.name,
              extraEquipmentNames.join('、'),
            ),
            kind: _PreSortieWarningKind.extraEquipment,
          ),
        );
      }
    }

    return warnings;
  }
}

class _PreSortieWarning {
  const _PreSortieWarning({
    required this.fleetId,
    required this.message,
    required this.kind,
  });
  final int fleetId;
  final String message;
  final _PreSortieWarningKind kind;
}

enum _PreSortieWarningKind {
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
