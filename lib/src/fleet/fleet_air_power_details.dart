import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/fleet_metrics.dart';
import '../theme/app_palette.dart';
import 'fleet_metric_details_popover.dart';

class FleetAirPowerDetails extends StatelessWidget {
  const FleetAirPowerDetails({
    super.key,
    required this.metrics,
    required this.builder,
    this.viewportContext,
  });

  final FleetMetrics metrics;
  final Widget Function(VoidCallback toggle) builder;
  final BuildContext? viewportContext;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final rows = <(String, int?)>[
      (l10n.minimumValue, metrics.airPower),
      (l10n.maximumValue, metrics.airPowerMaximum),
      (l10n.withoutBonus, metrics.airPowerWithoutProficiency),
    ];
    return FleetMetricDetailsPopover(
      title: l10n.airPowerDetails,
      closeLabel: l10n.close,
      cardKey: const Key('fleet-air-power-details-popover'),
      closeKey: const Key('fleet-air-power-details-close'),
      viewportContext: viewportContext,
      builder: builder,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index != 0)
            Divider(color: appColor(context, const Color(0xff294052))),
          FleetMetricDetailRow(
            label: rows[index].$1,
            value: rows[index].$2?.toString() ?? '—',
          ),
        ],
      ],
    );
  }
}
