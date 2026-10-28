import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'notification_settings_controller.dart';
import 'notification_settings_store.dart';
import 'settings_ui_helpers.dart';

class DebuffReminderSettingsSection extends StatelessWidget
    with SettingsUIHelpers {
  const DebuffReminderSettingsSection({super.key, required this.controller});

  final NotificationSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return buildActionTile(
          title: l10n.debuffReminderSettingTitle,
          subtitle: l10n.debuffReminderSettingSubtitle,
          trailing: SizedBox(
            width: 220,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DebuffReminderStyle>(
                key: const Key('debuff-reminder-style-menu'),
                value: settings.debuffReminderStyle,
                alignment: AlignmentDirectional.centerEnd,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: DebuffReminderStyle.dialog,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      l10n.debuffReminderStyleDialog,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  DropdownMenuItem(
                    value: DebuffReminderStyle.topNotice,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      l10n.debuffReminderStyleTopNotice,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
                onChanged: (style) {
                  if (style != null) {
                    controller.setDebuffReminderStyle(style);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
