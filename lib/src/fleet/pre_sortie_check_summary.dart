import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'dashboard_card.dart';
import 'fleet_ui_strings.dart';
import 'ship_status_style.dart';

enum SortieCheckMode { ships, maps }

class PreSortieCheckSummary extends StatefulWidget {
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
  State<PreSortieCheckSummary> createState() => _PreSortieCheckSummaryState();
}

class _PreSortieCheckSummaryState extends State<PreSortieCheckSummary> {
  SortieCheckMode _mode = SortieCheckMode.ships;
  bool _showClearedMaps = true;
  bool _modeRestored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_modeRestored) return;
    final storedMode = PageStorage.maybeOf(context)?.readState(context);
    if (storedMode is String) {
      _mode = SortieCheckMode.values.firstWhere(
        (mode) => mode.name == storedMode,
        orElse: () => _mode,
      );
    }
    _modeRestored = true;
  }

  void _setMode(SortieCheckMode mode) {
    setState(() => _mode = mode);
    PageStorage.maybeOf(context)?.writeState(context, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));

        return DashboardCard(
          title: l10n.preSortieCheck,
          icon: const Icon(Icons.security_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          trailing: _SortieSummaryModeSelector(
            mode: _mode,
            shipsLabel: l10n.sortieCheckShipsMode,
            mapsLabel: l10n.sortieCheckMapsMode,
            onChanged: _setMode,
          ),
          child: _mode == SortieCheckMode.ships
              ? _buildShipsCheckView(state, l10n)
              : _buildMapsGaugeView(state, l10n),
        );
      },
    );
  }

  Widget _buildShipsCheckView(GameState state, AppLocalizations l10n) {
    final warnings = _generateWarnings(state, l10n);
    if (warnings.isEmpty) {
      return Center(
        child: Text(
          l10n.noSortieWarnings,
          style: const TextStyle(color: Color(0xff8197a5), fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: warnings
          .map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                key: Key(
                  'pre-sortie-warning-surface-${warning.fleetId}-${warning.kind.keyName}',
                ),
                color: warning.kind.foreground.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: warning.kind.foreground, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key(
                    'pre-sortie-warning-${warning.fleetId}-${warning.kind.keyName}',
                  ),
                  onTap: () => widget.onOpenFleet(warning.fleetId),
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
          )
          .toList(),
    );
  }

  Widget _buildMapsGaugeView(GameState state, AppLocalizations l10n) {
    final allGauges = state.memberMapInfos.values
        .where((m) => m.hasGauge)
        .toList();

    if (allGauges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.noMapGaugeData,
                style: const TextStyle(
                  color: Color(0xff8197a5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.noMapGaugeDataHint,
                style: const TextStyle(color: Color(0xff4a5c68), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final displayedGauges = _showClearedMaps
        ? allGauges
        : allGauges.where((m) => !m.isGaugeCleared).toList();

    displayedGauges.sort((a, b) {
      if (a.isGaugeCleared != b.isGaugeCleared) {
        return a.isGaugeCleared ? 1 : -1;
      }
      if (a.isEvent != b.isEvent) {
        return a.isEvent ? -1 : 1;
      }
      if (a.mapAreaId != b.mapAreaId) {
        return a.mapAreaId.compareTo(b.mapAreaId);
      }
      if (a.mapNo != b.mapNo) {
        return a.mapNo.compareTo(b.mapNo);
      }
      return (a.gaugeNum ?? 0).compareTo(b.gaugeNum ?? 0);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              key: const Key('map-gauge-toggle-show-cleared'),
              onTap: () => setState(() => _showClearedMaps = !_showClearedMaps),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showClearedMaps
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.showClearedMaps,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (displayedGauges.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.allMapsCleared,
                style: const TextStyle(color: Color(0xff8197a5), fontSize: 12),
              ),
            ),
          )
        else
          ...displayedGauges.map(
            (gauge) => _MapGaugeRow(
              key: Key('map-gauge-row-${gauge.mapAreaId}-${gauge.mapNo}'),
              gauge: gauge,
              state: state,
            ),
          ),
      ],
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

class _SortieSummaryModeSelector extends StatelessWidget {
  const _SortieSummaryModeSelector({
    required this.mode,
    required this.shipsLabel,
    required this.mapsLabel,
    required this.onChanged,
  });

  final SortieCheckMode mode;
  final String shipsLabel;
  final String mapsLabel;
  final ValueChanged<SortieCheckMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sortie-check-mode-selector'),
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xff294052)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            key: const Key('sortie-check-mode-ships'),
            label: shipsLabel,
            selected: mode == SortieCheckMode.ships,
            onTap: () => onChanged(SortieCheckMode.ships),
          ),
          _ModeButton(
            key: const Key('sortie-check-mode-maps'),
            label: mapsLabel,
            selected: mode == SortieCheckMode.maps,
            onTap: () => onChanged(SortieCheckMode.maps),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xff5b4829) : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xfff7e7c4)
                  : const Color(0xff8197a5),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGaugeRow extends StatelessWidget {
  const _MapGaugeRow({super.key, required this.gauge, required this.state});

  final MemberMapInfo gauge;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final displayName = gauge.displayName.isNotEmpty
        ? gauge.displayName
        : (state.mapName(gauge.mapAreaId, gauge.mapNo) ?? '');
    final rankText = gauge.rankName != null ? ' ${gauge.rankName}' : '';
    final gaugeNumText =
        (gauge.gaugeNum != null &&
            gauge.gaugeMaxNum != null &&
            gauge.gaugeMaxNum! > 1)
        ? ' (${gauge.gaugeNum}/${gauge.gaugeMaxNum})'
        : '';

    final tagBg = switch (gauge.categoryTag) {
      'Extra' => const Color(0xff1565c0),
      'SP Normal' => const Color(0xff00897b),
      'Event' => const Color(0xff6a1b9a),
      _ => const Color(0xff37474f),
    };

    final percentage = gauge.percentage;
    final isCleared = gauge.isGaugeCleared;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xff0d1a26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCleared
                ? const Color(0xff1e303d)
                : const Color(0xff294052),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    fleetText(context, gauge.categoryTag),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${gauge.code} $displayName$rankText$gaugeNumText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCleared
                          ? const Color(0xff607786)
                          : const Color(0xffdce6eb),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${gauge.currentGaugeValue} / ${gauge.maxGaugeValue}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCleared
                        ? const Color(0xff607786)
                        : const Color(0xff70c7bc),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: const Color(0xff142735),
                alignment: Alignment.centerLeft,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      width: constraints.maxWidth * percentage,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: percentage > 0
                              ? (gauge.isEvent
                                    ? const [
                                        Color(0xff7e57c2),
                                        Color(0xffab47bc),
                                      ]
                                    : const [
                                        Color(0xff26a69a),
                                        Color(0xff4db6ac),
                                      ])
                              : const [Color(0xff37474f), Color(0xff455a64)],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
