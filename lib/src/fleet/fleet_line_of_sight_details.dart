import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_surface_dialog.dart';
import '../game_state/fleet_metrics.dart';

Future<void> showFleetLineOfSightDetails(
  BuildContext context,
  FleetMetrics metrics,
) async {
  final l10n = AppLocalizations.of(context);
  await showGameSurfaceDialog<bool>(
    context: context,
    title: l10n?.losDetails ?? '索敌详情',
    rows: [
      '${l10n?.totalLos ?? '总索敌'}：${metrics.lineOfSight}',
      for (final result in metrics.formula33)
        '${l10n?.formula33 ?? '33式'} × ${result.mapModifier.toInt()}：${result.total.toStringAsFixed(2)}',
    ],
    actions: [
      GameSurfaceDialogAction(
        id: 'close',
        label: l10n?.close ?? '关闭',
        value: true,
      ),
    ],
    builder: (context, close) => AlertDialog(
      backgroundColor: appColor(context, Color(0xff142735)),
      title: Text(
        l10n?.losDetails ?? '索敌详情',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Formula33DetailRow(
            label: l10n?.totalLos ?? '总索敌',
            value: '${metrics.lineOfSight}',
          ),
          Divider(color: appColor(context, Color(0xff294052))),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                l10n?.formula33 ?? '33式',
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xffdce6eb)),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          for (final result in metrics.formula33)
            _Formula33DetailRow(
              label: '× ${result.mapModifier.toInt()}',
              value: result.total.toStringAsFixed(2),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => close(true),
          child: Text(l10n?.close ?? '关闭'),
        ),
      ],
    ),
  );
}

class _Formula33DetailRow extends StatelessWidget {
  const _Formula33DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}
