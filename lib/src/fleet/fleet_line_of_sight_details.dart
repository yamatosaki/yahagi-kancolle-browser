import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/fleet_metrics.dart';
import '../theme/app_palette.dart';
import 'fleet_metric_details_popover.dart';

class FleetLineOfSightDetails extends StatelessWidget {
  const FleetLineOfSightDetails({
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
    final l10n = AppLocalizations.of(context);
    return FleetMetricDetailsPopover(
      title: l10n?.losDetails ?? '索敌详情',
      closeLabel: l10n?.close ?? '关闭',
      cardKey: const Key('fleet-los-details-popover'),
      closeKey: const Key('fleet-los-details-close'),
      viewportContext: viewportContext,
      builder: builder,
      children: [
        FleetMetricDetailRow(
          label: l10n?.totalLos ?? '总索敌',
          value: '${metrics.lineOfSight}',
        ),
        Divider(color: appColor(context, const Color(0xff294052))),
        Text(
          l10n?.formula33 ?? '33式',
          style: appTextStyle(
            context,
            const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        for (final result in metrics.formula33)
          FleetMetricDetailRow(
            label: '× ${result.mapModifier.toInt()}',
            value: result.total.toStringAsFixed(2),
          ),
      ],
    );
  }
}
