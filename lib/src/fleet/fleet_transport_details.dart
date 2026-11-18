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
      title: l10n.fleetTransportPoints,
      closeLabel: l10n.close,
      cardKey: const Key('fleet-transport-details-popover'),
      closeKey: const Key('fleet-transport-details-close'),
      viewportContext: viewportContext,
      builder: builder,
      children: [
        for (final tank in [false, true]) ...[
          if (tank) const SizedBox(height: 14),
          Text(
            tank ? l10n.fleetTransportTank : l10n.fleetTransportOrdinary,
            style: appTextStyle(
              context,
              TextStyle(
                fontSize: 12,
                color: appColor(context, const Color(0xff9fb4bf)),
              ),
            ),
          ),
          if (points.isCombined) ...[
            for (final contribution in points.contributions)
              FleetMetricDetailRow(
                label: contribution.fleetId == 1
                    ? l10n.questEligibleFleetFirst
                    : l10n.questEligibleFleetSecond,
                value:
                    '${tank ? contribution.tankPoints : contribution.points} TP',
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
            value: l10n.fleetTransportRankValues(
              tank ? points.tankSRank : points.sRank,
              tank ? points.tankARank : points.aRank,
            ),
          ),
        ],
      ],
    );
  }
}
