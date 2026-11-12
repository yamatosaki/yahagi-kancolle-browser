import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class SortieExperienceShipName extends StatelessWidget {
  const SortieExperienceShipName({
    super.key,
    required this.name,
    this.retreatedLabel,
  });

  final String name;
  final String? retreatedLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final retreat = retreatedLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: name,
          excludeFromSemantics: true,
          child: Text(
            name,
            maxLines: retreat == null ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: appTextStyle(
              context,
              TextStyle(
                color: palette.foreground,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (retreat != null)
          _metricText(context, retreat, color: palette.muted, fontSize: 10),
      ],
    );
  }
}

class SortieExperienceProgress extends StatelessWidget {
  const SortieExperienceProgress({
    super.key,
    required this.levelText,
    required this.nextText,
    this.levelKey,
    this.nextKey,
  });

  final String levelText;
  final String nextText;
  final Key? levelKey;
  final Key? nextKey;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricText(
          context,
          levelText,
          key: levelKey,
          color: palette.info,
          fontSize: 12,
          weight: FontWeight.w700,
        ),
        _metricText(
          context,
          nextText,
          key: nextKey,
          color: palette.foreground,
          fontSize: 11,
        ),
      ],
    );
  }
}

class SortieExperienceAmount extends StatelessWidget {
  const SortieExperienceAmount({
    super.key,
    required this.value,
    required this.color,
    this.unit,
    this.valueKey,
    this.unitKey,
  });

  final String value;
  final Color color;
  final String? unit;
  final Key? valueKey;
  final Key? unitKey;

  @override
  Widget build(BuildContext context) {
    final unit = this.unit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _metricText(
          context,
          value,
          key: valueKey,
          color: color,
          fontSize: 13,
          weight: FontWeight.w700,
          alignment: Alignment.centerRight,
        ),
        if (unit != null)
          _metricText(
            context,
            unit,
            key: unitKey,
            color: AppPalette.of(context).muted,
            fontSize: 10,
            weight: FontWeight.w600,
            alignment: Alignment.centerRight,
          ),
      ],
    );
  }
}

// Scale individual lines only when a narrow column cannot fit all digits.
Widget _metricText(
  BuildContext context,
  String text, {
  Key? key,
  required Color color,
  required double fontSize,
  FontWeight? weight,
  Alignment alignment = Alignment.centerLeft,
}) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: alignment,
  child: Text(
    text,
    key: key,
    maxLines: 1,
    softWrap: false,
    style: appTextStyle(
      context,
      TextStyle(
        color: color,
        fontSize: fontSize,
        height: 1.2,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  ),
);
