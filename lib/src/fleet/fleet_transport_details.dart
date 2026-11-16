import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../theme/app_palette.dart';
import 'fleet_metric_details_popover.dart';
import 'fleet_transport_points.dart';

class FleetTransportDetails extends StatelessWidget {
  const FleetTransportDetails({
    super.key,
    required this.points,
    required this.builder,
    this.viewportContext,
  });

  final FleetTransportPoints points;
  final Widget Function(VoidCallback toggle) builder;
  final BuildContext? viewportContext;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return FleetMetricDetailsPopover(
      title: points.isCombined
          ? l10n.fleetCombinedTransportPoints
          : l10n.fleetTransportPoints,
      closeLabel: l10n.close,
      cardKey: const Key('fleet-transport-details-popover'),
      closeKey: const Key('fleet-transport-details-close'),
      viewportContext: viewportContext,
      builder: builder,
      children: [
        if (points.isCombined) ...[
          for (final contribution in points.contributions)
            FleetMetricDetailRow(
              label: contribution.fleetId == 1
                  ? l10n.questEligibleFleetFirst
                  : l10n.questEligibleFleetSecond,
              value: '${contribution.points} TP',
            ),
          if (points.kinuBonus > 0)
            FleetMetricDetailRow(
              label: l10n.fleetTransportKinuBonus,
              value: '+${points.kinuBonus} TP',
            ),
          Divider(color: appColor(context, const Color(0xff294052))),
        ],
        FleetMetricDetailRow(
          label: l10n.fleetTransportTotal,
          value: l10n.fleetTransportRankValues(points.sRank, points.aRank),
        ),
      ],
    );
  }
}
