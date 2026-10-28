import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../settings/settings_ui_helpers.dart';
import 'ship_subtitle_language.dart';
import 'ship_subtitle_runtime_controller.dart';
import 'ship_subtitle_settings.dart';
import 'ship_subtitle_strings.dart';

class ShipSubtitleSettingsSection extends StatelessWidget
    with SettingsUIHelpers {
  const ShipSubtitleSettingsSection({
    super.key,
    required this.controller,
    this.runtimeController,
  });

  final ShipSubtitleSettingsController controller;
  final ShipSubtitleRuntimeController? runtimeController;

  @override
  Widget build(BuildContext context) {
    final strings = ShipSubtitleStrings.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([controller, runtimeController]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSwitchTile(
            switchKey: const Key('settings-ship-subtitles'),
            title: strings.title,
            subtitle: strings.description,
            value: controller.enabled,
            onChanged: controller.saving ? null : controller.setEnabled,
          ),
          if (controller.enabled) ...[
            if (runtimeController case final runtime?)
              if (runtime.status != ShipSubtitleRuntimeStatus.ready)
                _runtimeStatus(context, strings, runtime),
            Divider(color: appColor(context, Color(0xff294052)), height: 1),
            _choiceRow(
              strings.language,
              DropdownButton<ShipSubtitleLanguage>(
                key: const Key('settings-ship-subtitle-language'),
                value: controller.language,
                underline: const SizedBox(),
                alignment: AlignmentDirectional.centerEnd,
                items: [
                  for (final language in ShipSubtitleLanguage.values)
                    DropdownMenuItem(
                      value: language,
                      child: Text(language.label),
                    ),
                ],
                onChanged: controller.saving
                    ? null
                    : (value) {
                        if (value != null) controller.setLanguage(value);
                      },
              ),
            ),
            Divider(color: appColor(context, Color(0xff294052)), height: 1),
            _choiceRow(
              strings.fontSize,
              DropdownButton<ShipSubtitleFontSize>(
                key: const Key('settings-ship-subtitle-font-size'),
                value: controller.fontSize,
                underline: const SizedBox(),
                alignment: AlignmentDirectional.centerEnd,
                items: [
                  for (final size in ShipSubtitleFontSize.values)
                    DropdownMenuItem(
                      value: size,
                      child: Text(strings.sizeLabel(size)),
                    ),
                ],
                onChanged: controller.saving
                    ? null
                    : (value) {
                        if (value != null) controller.setFontSize(value);
                      },
              ),
            ),
          ],
          if (controller.saveFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                strings.saveFailed,
                style: appTextStyle(
                  context,
                  SettingsTileTypography.description.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _runtimeStatus(
    BuildContext context,
    ShipSubtitleStrings strings,
    ShipSubtitleRuntimeController runtime,
  ) {
    final status = runtime.status;
    final message = switch (status) {
      ShipSubtitleRuntimeStatus.checking => strings.runtimeChecking,
      ShipSubtitleRuntimeStatus.unsupported => strings.runtimeUnsupported,
      ShipSubtitleRuntimeStatus.failed => strings.runtimeFailed,
      ShipSubtitleRuntimeStatus.waitingForGameData =>
        strings.runtimeWaitingForGameData,
      ShipSubtitleRuntimeStatus.ready => '',
    };
    final needsRetry =
        status == ShipSubtitleRuntimeStatus.unsupported ||
        status == ShipSubtitleRuntimeStatus.failed;
    return Padding(
      key: const Key('settings-ship-subtitle-runtime-status'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: appTextStyle(
              context,
              SettingsTileTypography.description.copyWith(
                color: needsRetry
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (needsRetry || status == ShipSubtitleRuntimeStatus.checking)
            TextButton(
              key: const Key('settings-ship-subtitle-retry'),
              onPressed: status == ShipSubtitleRuntimeStatus.checking
                  ? null
                  : runtime.retry,
              child: Text(strings.retry),
            ),
        ],
      ),
    );
  }

  Widget _choiceRow(String title, Widget dropdown) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: SettingsTileTypography.title)),
        const SizedBox(width: 12),
        dropdown,
      ],
    ),
  );
}
