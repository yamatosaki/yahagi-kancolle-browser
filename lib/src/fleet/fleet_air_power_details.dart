import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_surface_dialog.dart';
import '../game_state/fleet_metrics.dart';

AppLocalizations _airPowerL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('zh'));

Future<void> showFleetAirPowerDetails(
  BuildContext context,
  FleetMetrics metrics,
) async {
  final l10n = _airPowerL10n(context);
  final rows = <(String, int?)>[
    (l10n.minimumValue, metrics.airPower),
    (l10n.maximumValue, metrics.airPowerMaximum),
    (l10n.withoutBonus, metrics.airPowerWithoutProficiency),
  ];
  await showGameSurfaceDialog<bool>(
    context: context,
    title: l10n.airPowerDetails,
    rows: [for (final row in rows) '${row.$1}：${row.$2 ?? '—'}'],
    actions: [
      GameSurfaceDialogAction(id: 'close', label: l10n.close, value: true),
    ],
    builder: (context, close) => AlertDialog(
      backgroundColor: appColor(context, Color(0xff142735)),
      title: Text(
        l10n.airPowerDetails,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _AirPowerDetailRow(
              label: rows[index].$1,
              value: rows[index].$2?.toString() ?? '—',
            ),
            if (index != rows.length - 1)
              Divider(color: appColor(context, Color(0xff294052))),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => close(true), child: Text(l10n.close)),
      ],
    ),
  );
}

class _AirPowerDetailRow extends StatelessWidget {
  const _AirPowerDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: appTextStyle(
              context,
              TextStyle(color: appColor(context, Color(0xff9fb4bf))),
            ),
          ),
        ),
        Text(
          value,
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xffe1e9ed)),
              fontWeight: FontWeight.w800,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}
