import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import 'fleet_status_visual.dart';
import 'status_density.dart';

AppLocalizations _fleetSwitcherL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('zh'));

class FleetSwitcherBar extends StatelessWidget {
  const FleetSwitcherBar({
    super.key,
    required this.fleets,
    required this.selectedFleetId,
    this.sortieFleetId,
    this.onFleetSelected,
    this.showTitle = true,
  });

  final List<Fleet> fleets;
  final int selectedFleetId;
  final int? sortieFleetId;
  final ValueChanged<int>? onFleetSelected;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final visibleFleets = fleets.take(4).toList(growable: false);
    return Row(
      children: [
        if (showTitle) ...[
          SizedBox(
            key: const Key('workspace-title-fleet'),
            width: 72,
            child: Text(
              _fleetSwitcherL10n(context).fleet,
              style: const TextStyle(
                color: Color(0xffe0b25c),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        for (final item in visibleFleets) ...[
          Expanded(
            child: _FleetButton(
              key: Key('fleet-button-${item.id}'),
              fleet: item,
              selected: item.id == selectedFleetId,
              isSortie: item.id == sortieFleetId,
              onTap: () => onFleetSelected?.call(item.id),
            ),
          ),
          if (item != visibleFleets.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _FleetButton extends StatelessWidget {
  const _FleetButton({
    super.key,
    required this.fleet,
    required this.selected,
    required this.isSortie,
    required this.onTap,
  });

  final Fleet fleet;
  final bool selected;
  final bool isSortie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phone = usesCompactFleetLayout(context);
    final status = fleetStatusVisual(fleet, isSortie: isSortie);
    return Material(
      color: selected ? const Color(0xff3a3020) : const Color(0xff102331),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: phone ? 30 : 32,
          padding: EdgeInsets.symmetric(
            horizontal: phone ? 4 : 11,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? const Color(0xff8d7040)
                  : const Color(0xff294052),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  key: Key('fleet-name-cell-${fleet.id}'),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fleet.name,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xfff0c675)
                              : const Color(0xffe1e9ed),
                          fontWeight: FontWeight.w700,
                          fontSize: phone ? 12 : 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  key: Key('fleet-status-cell-${fleet.id}'),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: Key('fleet-selector-status-dot-${fleet.id}'),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: phone ? 4 : 6),
                          Text(
                            fleetText(context, status.label),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: phone ? 9 : 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
