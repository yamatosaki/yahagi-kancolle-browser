import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../theme/app_palette.dart';
import 'layout_settings_controller.dart';
import 'settings_ui_helpers.dart';

class TopNoticeSettingsSection extends StatelessWidget with SettingsUIHelpers {
  const TopNoticeSettingsSection({super.key, required this.controller});

  final LayoutSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final english = Localizations.localeOf(context).languageCode == 'en';
    final layoutSettingsController = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle(l10n.topNoticeSectionTitle),
        buildCard(
          child: AnimatedBuilder(
            animation: layoutSettingsController,
            builder: (context, _) => Column(
              children: [
                buildSwitchTile(
                  title: l10n.topNoticeEnabledTitle,
                  titleKey: const Key('settings-top-notice-enabled'),
                  subtitle: l10n.topNoticeEnabledSubtitle,
                  value: layoutSettingsController.topNoticeEnabled,
                  onChanged: layoutSettingsController.setTopNoticeEnabled,
                ),
                Divider(color: appColor(context, Color(0xff294052)), height: 1),
                Opacity(
                  opacity: layoutSettingsController.topNoticeEnabled
                      ? 1.0
                      : 0.45,
                  child: IgnorePointer(
                    ignoring: !layoutSettingsController.topNoticeEnabled,
                    child: Padding(
                      key: const Key('settings-top-notice-duration-row'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.topNoticeDurationTitle,
                                  style: appTextStyle(
                                    context,
                                    SettingsTileTypography.title,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.topNoticeDurationSubtitle,
                                  style: appTextStyle(
                                    context,
                                    SettingsTileTypography.description,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              key: const Key(
                                'settings-top-notice-duration-dropdown',
                              ),
                              selectedItemBuilder: english
                                  ? (context) => [
                                      for (final seconds in [5, 10, 15])
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('$seconds s'),
                                        ),
                                    ]
                                  : null,
                              value:
                                  const [5, 10, 15].contains(
                                    layoutSettingsController
                                        .topNoticeDurationSeconds,
                                  )
                                  ? layoutSettingsController
                                        .topNoticeDurationSeconds
                                  : 5,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: appColor(
                                  context,
                                  layoutSettingsController.topNoticeEnabled
                                      ? const Color(0xffd4a85f)
                                      : const Color(0xff526776),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text(l10n.topNoticeDuration5s),
                                ),
                                DropdownMenuItem(
                                  value: 10,
                                  child: Text(l10n.topNoticeDuration10s),
                                ),
                                DropdownMenuItem(
                                  value: 15,
                                  child: Text(l10n.topNoticeDuration15s),
                                ),
                              ],
                              onChanged:
                                  layoutSettingsController.topNoticeEnabled
                                  ? (value) {
                                      if (value != null) {
                                        layoutSettingsController
                                            .setTopNoticeDurationSeconds(value);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
