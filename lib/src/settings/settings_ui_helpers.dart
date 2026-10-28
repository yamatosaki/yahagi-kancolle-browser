import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

abstract final class SettingsTileTypography {
  static const title = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const description = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xff8197a5),
  );
}

/// Keeps controls readable when the panel is narrow or system text is enlarged.
class SettingsControlRow extends StatelessWidget {
  const SettingsControlRow({
    super.key,
    required this.label,
    required this.controlBuilder,
    this.hasControl = true,
    this.minInlineWidth = 280,
  });

  final Widget label;
  final Widget Function(bool stacked) controlBuilder;
  final bool hasControl;
  final double minInlineWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!hasControl) return label;
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final stacked = constraints.maxWidth / textScale < minInlineWidth;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: controlBuilder(true),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 12),
          controlBuilder(false),
        ],
      );
    },
  );
}

mixin SettingsUIHelpers {
  Widget buildSectionTitle(String title) {
    return Builder(
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          title,
          style: TextStyle(
            color: appColor(context, Color(0xffd4a85f)),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget buildCard({required Widget child}) {
    return Builder(
      builder: (BuildContext context) => Material(
        color: appColor(context, const Color(0xff142735)),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            minLeadingWidth: 0,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget buildActionTile({
    Key? key,
    required String title,
    Key? titleKey,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Builder(
      builder: (BuildContext context) => InkWell(
        key: key,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SettingsControlRow(
            hasControl: trailing != null,
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  key: titleKey,
                  style: appTextStyle(
                    context,
                    SettingsTileTypography.title.copyWith(
                      color: enabled ? null : const Color(0xff526776),
                    ),
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: appTextStyle(
                      context,
                      SettingsTileTypography.description.copyWith(
                        color: enabled ? null : const Color(0xff526776),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            controlBuilder: (_) => trailing ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget buildSwitchTile({
    required String title,
    Key? titleKey,
    Key? switchKey,
    String? subtitle,
    Widget? trailingBeforeSwitch,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null;
    return Builder(
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    key: titleKey,
                    style: appTextStyle(
                      context,
                      SettingsTileTypography.title.copyWith(
                        color: enabled ? null : const Color(0xff526776),
                      ),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: appTextStyle(
                        context,
                        SettingsTileTypography.description.copyWith(
                          color: enabled ? null : const Color(0xff526776),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingBeforeSwitch != null) ...<Widget>[
              const SizedBox(width: 12),
              trailingBeforeSwitch,
            ],
            const SizedBox(width: 12),
            Switch(
              key: switchKey,
              value: value,
              onChanged: onChanged,
              activeThumbColor: appColor(context, const Color(0xffd4a85f)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
  }) {
    return Builder(
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: appTextStyle(context, SettingsTileTypography.title),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(value * 100).toInt()}%',
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: onChanged == null
                          ? const Color(0xff526776)
                          : const Color(0xffd4a85f),
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              activeColor: appColor(context, const Color(0xffd4a85f)),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
