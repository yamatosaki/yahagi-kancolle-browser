import 'package:flutter/material.dart';
import 'dashboard_card.dart';

import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class PreSortieCheckSummary extends StatelessWidget {
  const PreSortieCheckSummary({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final warnings = _generateWarnings(state);

        return DashboardCard(
          title: AppLocalizations.of(context)?.preSortieCheck ?? '出击前检查',
          icon: const Icon(Icons.security_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (warnings.isEmpty)
                const Center(
                  child: Text(
                    '暂无出击告',
                    style: TextStyle(color: Color(0xff8197a5), fontSize: 13),
                  ),
                )
              else
                ...warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: warning.isCritical
                            ? const Color(0x33f44336)
                            : const Color(0x33ff9800),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: warning.isCritical
                              ? const Color(0xfff44336)
                              : const Color(0xffff9800),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            warning.isCritical
                                ? Icons.warning_rounded
                                : Icons.info_outline_rounded,
                            color: warning.isCritical
                                ? const Color(0xfff44336)
                                : const Color(0xffff9800),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning.message,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
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

  List<_PreSortieWarning> _generateWarnings(GameState state) {
    final warnings = <_PreSortieWarning>[];
    if (state.fleets.isEmpty || !state.hasMasterData) return warnings;

    // Check non-expedition fleets (usually fleets at port)
    for (final fleet in state.fleets) {
      if (fleet.mission.isActive || fleet.shipIds.isEmpty) continue;

      bool hasTaiha = false;
      bool hasUnresupplied = false;
      final taihaNames = <String>[];

      for (final shipId in fleet.shipIds) {
        final ship = state.ships[shipId];
        if (ship == null) continue;

        if (ship.currentHp > 0 && ship.currentHp / ship.maxHp <= 0.25) {
          hasTaiha = true;
          final masterShip = state.masterShips[ship.masterId];
          taihaNames.add(masterShip?.name ?? '期舰');
        }

        final masterShip = state.masterShips[ship.masterId];
        if (masterShip != null) {
          if (ship.currentFuel < masterShip.maxFuel ||
              ship.currentAmmo < masterShip.maxAmmo) {
            hasUnresupplied = true;
          }
        }
      }

      if (hasTaiha) {
        warnings.add(
          _PreSortieWarning(
            message: '${fleet.name} 存在大破舰: ${taihaNames.join(", ")}，止出击！',
            isCritical: true,
          ),
        );
      }

      if (hasUnresupplied) {
        warnings.add(
          _PreSortieWarning(message: '${fleet.name} 有舰娘未补给', isCritical: false),
        );
      }
    }

    return warnings;
  }
}

class _PreSortieWarning {
  const _PreSortieWarning({required this.message, required this.isCritical});
  final String message;
  final bool isCritical;
}
