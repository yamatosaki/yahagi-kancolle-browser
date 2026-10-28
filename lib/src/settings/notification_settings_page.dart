import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../notification/method_channel_notification_port.dart';
import '../notification/notification_models.dart';
import '../notification/notification_port.dart';
import 'notification_settings_controller.dart';
import 'notification_settings_store.dart';
import 'layout_settings_controller.dart';
import 'settings_organization_strings.dart';
import 'top_notice_settings_section.dart';
import 'settings_ui_helpers.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    required this.controller,
    this.layoutSettingsController,
    this.notificationPort = const MethodChannelNotificationPort(),
  });

  final NotificationSettingsController controller;
  final LayoutSettingsController? layoutSettingsController;
  final NotificationPort notificationPort;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with SettingsUIHelpers, WidgetsBindingObserver {
  late Future<NotificationPlatformCapabilities> _capabilities;

  NotificationSettingsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshCapabilities();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_refreshCapabilities);
    }
  }

  void _refreshCapabilities() {
    _capabilities = widget.notificationPort.getCapabilities();
  }

  Future<void> _requestNotificationPermission() async {
    await widget.notificationPort.requestNotificationPermission();
    setState(_refreshCapabilities);
  }

  Future<void> _requestExactAlarmPermission() async {
    await widget.notificationPort.requestExactAlarmPermission();
    setState(_refreshCapabilities);
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final settings = controller.settings;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildSectionTitle(
                  settingsOrganizationText(
                    context,
                    'settingsGroupSystemNotifications',
                  ),
                ),
                buildCard(
                  child: Column(
                    children: [
                      buildSwitchTile(
                        title: settingsOrganizationText(
                          context,
                          'settingsEnableSystemNotifications',
                        ),
                        switchKey: const Key('notification-master-switch'),
                        value: settings.master,
                        onChanged: (v) => controller.setMaster(v),
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),
                      buildSwitchTile(
                        title: settingsOrganizationText(
                          context,
                          'settingsSystemNotificationSound',
                        ),
                        value: settings.sound,
                        onChanged: settings.master
                            ? (v) => controller.setSound(v)
                            : null,
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),
                      buildSwitchTile(
                        title: settingsOrganizationText(
                          context,
                          'settingsSystemNotificationVibration',
                        ),
                        value: settings.vibration,
                        onChanged: settings.master
                            ? (v) => controller.setVibration(v)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                buildSectionTitle(l10n.notificationSectionTypes),
                buildCard(
                  child: Column(
                    children: [
                      _buildNotificationTypeRow<int>(
                        rowKey: const Key('notification-expedition-row'),
                        menuKey: const Key('notification-expedition-menu'),
                        switchKey: const Key('notification-expedition-switch'),
                        title: _notificationTypeTitle(
                          l10n.notificationExpedition,
                        ),
                        selected: settings.expeditionPreemptSeconds,
                        items: [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(l10n.notificationPunctual),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text(l10n.notificationPreempt30s),
                          ),
                          DropdownMenuItem<int>(
                            value: 60,
                            child: Text(l10n.notificationPreempt60s),
                          ),
                        ],
                        menuEnabled: settings.master && settings.expedition,
                        onSelected: controller.setExpeditionPreemptSeconds,
                        switchedOn: settings.expedition,
                        onSwitchChanged: settings.master
                            ? controller.setExpedition
                            : null,
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),

                      _buildNotificationTypeRow<int>(
                        rowKey: const Key('notification-repair-row'),
                        menuKey: const Key('notification-repair-menu'),
                        switchKey: const Key('notification-repair-switch'),
                        title: _notificationTypeTitle(l10n.notificationRepair),
                        selected: settings.repairPreemptSeconds,
                        items: [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(l10n.notificationRepairPunctual),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text(l10n.notificationPreempt30s),
                          ),
                          DropdownMenuItem<int>(
                            value: 60,
                            child: Text(l10n.notificationPreempt60s),
                          ),
                        ],
                        menuEnabled: settings.master && settings.repair,
                        onSelected: controller.setRepairPreemptSeconds,
                        switchedOn: settings.repair,
                        onSwitchChanged: settings.master
                            ? controller.setRepair
                            : null,
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),

                      _buildNotificationTypeRow<int>(
                        rowKey: const Key('notification-construction-row'),
                        menuKey: const Key('notification-construction-menu'),
                        switchKey: const Key(
                          'notification-construction-switch',
                        ),
                        title: _notificationTypeTitle(
                          l10n.notificationConstruction,
                        ),
                        selected: settings.constructionPreemptSeconds,
                        items: [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(l10n.notificationPunctual),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text(l10n.notificationPreempt30s),
                          ),
                          DropdownMenuItem<int>(
                            value: 60,
                            child: Text(l10n.notificationPreempt60s),
                          ),
                        ],
                        menuEnabled: settings.master && settings.construction,
                        onSelected: controller.setConstructionPreemptSeconds,
                        switchedOn: settings.construction,
                        onSwitchChanged: settings.master
                            ? controller.setConstruction
                            : null,
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),

                      _buildNotificationTypeRow<AnchorageNotificationMode>(
                        rowKey: const Key('notification-anchorage-row'),
                        menuKey: const Key('notification-anchorage-menu'),
                        switchKey: const Key('notification-anchorage-switch'),
                        title: _notificationTypeTitle(
                          l10n.notificationAnchorage,
                        ),
                        selected: settings.anchorageMode,
                        items: [
                          DropdownMenuItem<AnchorageNotificationMode>(
                            value: AnchorageNotificationMode.twentyMinutes,
                            child: Text(l10n.notificationAnchorage20m),
                          ),
                          DropdownMenuItem<AnchorageNotificationMode>(
                            value: AnchorageNotificationMode.allRepaired,
                            child: Text(l10n.notificationAnchorageFull),
                          ),
                          DropdownMenuItem<AnchorageNotificationMode>(
                            value: AnchorageNotificationMode.both,
                            child: Text(l10n.notificationAnchorageBoth),
                          ),
                        ],
                        menuEnabled: settings.master && settings.anchorage,
                        onSelected: controller.setAnchorageMode,
                        switchedOn: settings.anchorage,
                        onSwitchChanged: settings.master
                            ? controller.setAnchorage
                            : null,
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),

                      _buildNotificationTypeRow<int>(
                        rowKey: const Key('notification-morale-row'),
                        menuKey: const Key('notification-morale-menu'),
                        switchKey: const Key('notification-morale-switch'),
                        title: _notificationTypeTitle(l10n.notificationMorale),
                        selected: settings.moralePreemptSeconds,
                        items: [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(l10n.notificationPunctual),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text(l10n.notificationPreempt30s),
                          ),
                          DropdownMenuItem<int>(
                            value: 60,
                            child: Text(l10n.notificationPreempt60s),
                          ),
                        ],
                        menuEnabled: settings.master && settings.morale,
                        onSelected: controller.setMoralePreemptSeconds,
                        switchedOn: settings.morale,
                        onSwitchChanged: settings.master
                            ? controller.setMorale
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                buildSectionTitle(l10n.notificationSectionOngoing),
                buildCard(
                  child: Column(
                    children: [
                      buildSwitchTile(
                        title: l10n.notificationOngoingLive,
                        value: settings.ongoingLive,
                        onChanged: settings.master
                            ? (v) => controller.setOngoingLive(v)
                            : null,
                      ),
                      Divider(
                        color: appColor(context, Color(0xff294052)),
                        height: 1,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          children: [
                            _buildCheckItem(
                              label: l10n.notificationProgress,
                              value: settings.showProgress,
                              enabled: settings.master && settings.ongoingLive,
                              onChanged: (v) =>
                                  controller.setShowProgress(v ?? true),
                            ),
                            _buildCheckItem(
                              label: l10n.notificationPercent,
                              value: settings.showPercent,
                              enabled: settings.master && settings.ongoingLive,
                              onChanged: (v) =>
                                  controller.setShowPercent(v ?? true),
                            ),
                            _buildCheckItem(
                              label: l10n.notificationCountdown,
                              value: settings.showCountdown,
                              enabled: settings.master && settings.ongoingLive,
                              onChanged: (v) =>
                                  controller.setShowCountdown(v ?? true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (widget.layoutSettingsController case final layout?) ...[
                  TopNoticeSettingsSection(controller: layout),
                  const SizedBox(height: 24),
                ],
                buildSectionTitle(l10n.notificationSectionSystem),
                FutureBuilder<NotificationPlatformCapabilities>(
                  future: _capabilities,
                  builder: (context, snapshot) {
                    final capabilities = snapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildCard(
                          child: Column(
                            children: [
                              buildActionTile(
                                title:
                                    capabilities?.notificationsGranted == true
                                    ? l10n.notificationPermissionGranted
                                    : l10n.notificationPermissionDenied,
                                trailing: Icon(
                                  capabilities?.notificationsGranted == true
                                      ? Icons.check_circle_outline
                                      : Icons.notifications_off_outlined,
                                ),
                                onTap:
                                    capabilities?.notificationsGranted == true
                                    ? widget
                                          .notificationPort
                                          .openSystemNotificationSettings
                                    : _requestNotificationPermission,
                              ),
                              Divider(
                                color: appColor(context, Color(0xff294052)),
                                height: 1,
                              ),
                              buildActionTile(
                                title: capabilities?.exactAlarmsGranted == true
                                    ? l10n.notificationExactAlarmGranted
                                    : l10n.notificationExactAlarmDenied,
                                trailing: Icon(
                                  capabilities?.exactAlarmsGranted == true
                                      ? Icons.alarm_on_outlined
                                      : Icons.alarm_off_outlined,
                                ),
                                onTap: _requestExactAlarmPermission,
                              ),
                              Divider(
                                color: appColor(context, Color(0xff294052)),
                                height: 1,
                              ),
                              buildActionTile(
                                title: capabilities?.channelsEnabled == true
                                    ? l10n.notificationChannelsEnabled
                                    : l10n.notificationChannelsDisabled,
                                trailing: Icon(
                                  capabilities?.channelsEnabled == true
                                      ? Icons.tune_outlined
                                      : Icons.block_outlined,
                                ),
                                onTap: widget
                                    .notificationPort
                                    .openSystemNotificationSettings,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            left: 4,
                            right: 4,
                          ),
                          child: Text(
                            l10n.notificationSectionSystemDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: appColor(context, Color(0xff8197a5)),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckItem({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: appColor(context, Color(0xffd4a85f)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: appTextStyle(
                context,
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? const Color(0xffc7d5dc)
                      : const Color(0xff526776),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeRow<T>({
    required Key rowKey,
    required Key menuKey,
    required Key switchKey,
    required Widget title,
    required T selected,
    required List<DropdownMenuItem<T>> items,
    required bool menuEnabled,
    required ValueChanged<T> onSelected,
    required bool switchedOn,
    required ValueChanged<bool>? onSwitchChanged,
  }) {
    final effectiveSelected = items.any((item) => item.value == selected)
        ? selected
        : (items.isNotEmpty ? items.first.value : selected);
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: title),
          SizedBox(
            width: 154,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                key: menuKey,
                value: effectiveSelected,
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appColor(
                    context,
                    menuEnabled
                        ? const Color(0xffd4a85f)
                        : const Color(0xff526776),
                  ),
                ),
                items: items,
                onChanged: menuEnabled
                    ? (value) {
                        if (value != null) onSelected(value);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            key: switchKey,
            value: switchedOn,
            onChanged: onSwitchChanged,
            activeThumbColor: appColor(context, const Color(0xffd4a85f)),
          ),
        ],
      ),
    );
  }

  Widget _notificationTypeTitle(String label, {bool isNew = false}) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        if (isNew) ...[
          const SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: appColor(context, Color(0xffd4a85f)),
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                'NEW',
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appOnAccentColor(context, Colors.black),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
