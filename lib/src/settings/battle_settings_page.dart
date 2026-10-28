import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_prediction_settings.dart';
import 'battle_prediction_settings_section.dart';
import 'battle_status_effect_settings.dart';
import 'debuff_reminder_settings_section.dart';
import 'notification_settings_controller.dart';
import 'settings_organization_strings.dart';
import 'safety_settings_controller.dart';
import 'safety_settings_store.dart';
import 'settings_ui_helpers.dart';

class BattleSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const BattleSettingsPage({
    super.key,
    this.battlePredictionSettingsController,
    this.notificationSettingsController,
    required this.safetySettingsController,
  });

  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildSectionTitle(l10n.battleSafetySectionTitle),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) {
                  final enabled =
                      safetySettingsController.battleWarningMode ==
                      BattleWarningMode.confirm;
                  return Column(
                    children: <Widget>[
                      MergeSemantics(
                        child: InkWell(
                          key: const Key('battleWarningMasterRow'),
                          onTap: () {
                            safetySettingsController.setBattleWarningMode(
                              enabled
                                  ? BattleWarningMode.off
                                  : BattleWarningMode.confirm,
                            );
                          },
                          child: buildSwitchTile(
                            switchKey: const Key('battleWarningMasterSwitch'),
                            title: l10n.gameSafety,
                            value: enabled,
                            onChanged: (value) {
                              safetySettingsController.setBattleWarningMode(
                                value
                                    ? BattleWarningMode.confirm
                                    : BattleWarningMode.off,
                              );
                            },
                          ),
                        ),
                      ),
                      if (enabled) ...<Widget>[
                        Divider(
                          height: 1,
                          color: appColor(context, const Color(0xff294052)),
                        ),
                        _AdvanceWarningTimingOptions(
                          controller: safetySettingsController,
                        ),
                        Divider(
                          height: 1,
                          color: appColor(context, const Color(0xff294052)),
                        ),
                        _WarningDropdownRow<AdvanceWarningDisplayMode>(
                          key: const Key('advanceWarningDisplayModeSelector'),
                          dropdownKey: const Key(
                            'advanceWarningDisplayModeDropdown',
                          ),
                          title: l10n.advanceWarningDisplayModeTitle,
                          subtitle:
                              safetySettingsController
                                      .advanceWarningDisplayMode ==
                                  AdvanceWarningDisplayMode.smart
                              ? l10n.advanceWarningSmartDescription
                              : l10n.advanceWarningAlwaysConfirmDescription,
                          value: safetySettingsController
                              .advanceWarningDisplayMode,
                          choices: [
                            _WarningChoice(
                              key: const Key(
                                'advanceWarningDisplayOptionAlways',
                              ),
                              value: AdvanceWarningDisplayMode.alwaysConfirm,
                              label: l10n.advanceWarningAlwaysConfirm,
                            ),
                            _WarningChoice(
                              key: const Key(
                                'advanceWarningDisplayOptionSmart',
                              ),
                              value: AdvanceWarningDisplayMode.smart,
                              label: l10n.advanceWarningSmart,
                            ),
                          ],
                          onChanged: safetySettingsController
                              .setAdvanceWarningDisplayMode,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (notificationSettingsController case final notifications?) ...[
              buildSectionTitle(
                settingsOrganizationText(context, 'settingsGroupDebuff'),
              ),
              buildCard(
                child: DebuffReminderSettingsSection(controller: notifications),
              ),
              const SizedBox(height: 24),
            ],
            if (battlePredictionSettingsController != null) ...<Widget>[
              buildSectionTitle(l10n.battlePredictionSection),
              buildCard(
                child: BattlePredictionSettingsSection(
                  controller: battlePredictionSettingsController!,
                ),
              ),
              const SizedBox(height: 24),
            ],
            buildSectionTitle(
              settingsOrganizationText(
                context,
                'settingsGroupShipStatusFeedback',
              ),
            ),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) {
                  final settings = safetySettingsController.battleStatusEffects;
                  final childrenEnabled = settings.enabled;
                  return Column(
                    children: <Widget>[
                      buildSwitchTile(
                        title: l10n.battleStatusEffectsEnabled,
                        subtitle: l10n.battleStatusEffectsEnabledDesc,
                        switchKey: const Key('battleStatusEffectsMasterSwitch'),
                        value: settings.enabled,
                        onChanged: safetySettingsController
                            .setBattleStatusEffectsEnabled,
                      ),
                      Divider(
                        height: 1,
                        color: appColor(context, Color(0xff294052)),
                      ),
                      _StatusEffectRow(
                        title: l10n.battleEffectDisplayScope,
                        subtitle: l10n.battleEffectDisplayScopeDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<BattleEffectDisplayScope>(
                          key: const Key('battleEffectScopeDropdown'),
                          value: settings.displayScope,
                          underline: const SizedBox(),
                          alignment: AlignmentDirectional.centerEnd,
                          isExpanded: true,
                          itemHeight: null,
                          items: BattleEffectDisplayScope.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    _scopeLabel(l10n, value),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setBattleEffectDisplayScope(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: appColor(context, Color(0xff294052)),
                      ),
                      _StatusEffectRow(
                        title: l10n.battleDamagePulse,
                        subtitle: l10n.battleDamagePulseDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<DamagePulseFilter>(
                          key: const Key('damagePulseFilterDropdown'),
                          value: settings.damagePulseFilter,
                          underline: const SizedBox(),
                          alignment: AlignmentDirectional.centerEnd,
                          isExpanded: true,
                          itemHeight: null,
                          items: DamagePulseFilter.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    _pulseFilterLabel(l10n, value),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setDamagePulseFilter(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: appColor(context, Color(0xff294052)),
                      ),
                      _StatusEffectRow(
                        title: l10n.battleDamageVibrationEffect,
                        subtitle: l10n.battleDamageVibrationEffectDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<DamageVibrationFilter>(
                          key: const Key('damageVibrationFilterDropdown'),
                          value: settings.damageVibrationFilter,
                          underline: const SizedBox(),
                          alignment: AlignmentDirectional.centerEnd,
                          isExpanded: true,
                          itemHeight: null,
                          items: DamageVibrationFilter.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    _vibrationFilterLabel(l10n, value),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setDamageVibrationFilter(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: appColor(context, Color(0xff294052)),
                      ),
                      _StatusEffectRow(
                        title: l10n.battleMoraleSparkle,
                        subtitle: l10n.battleMoraleSparkleDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<MoraleSparkleMode>(
                          key: const Key('moraleSparkleModeDropdown'),
                          value: settings.moraleSparkleMode,
                          underline: const SizedBox(),
                          alignment: AlignmentDirectional.centerEnd,
                          isExpanded: true,
                          itemHeight: null,
                          items: MoraleSparkleMode.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    _moraleSparkleModeLabel(l10n, value),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setMoraleSparkleMode(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AdvanceWarningTimingOptions extends StatelessWidget {
  const _AdvanceWarningTimingOptions({required this.controller});

  final SafetySettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final settings = controller.advanceWarningTimings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _WarningDropdownRow<AdvanceWarningTimingSettings>(
          key: const Key('advanceWarningTimingSelector'),
          dropdownKey: const Key('advanceWarningTimingDropdown'),
          title: l10n.advanceWarningTimingModeTitle,
          subtitle: l10n.advanceWarningTimingModeDescription,
          value: settings,
          choices: [
            _WarningChoice(
              key: const Key('advanceWarningTimingOptionAdvance'),
              value: AdvanceWarningTimingSettings.advanceOnly,
              label: l10n.advanceWarningAfterAdvance,
            ),
            _WarningChoice(
              key: const Key('advanceWarningTimingOptionBattle'),
              value: AdvanceWarningTimingSettings.battleOnly,
              label: l10n.advanceWarningPostBattle,
            ),
            _WarningChoice(
              key: const Key('advanceWarningTimingOptionBoth'),
              value: AdvanceWarningTimingSettings.battleAndAdvance,
              label: l10n.advanceWarningBothTimings,
            ),
          ],
          onChanged: controller.setAdvanceWarningTimings,
        ),
        if (settings.postBattle && !settings.afterAdvance)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              l10n.advanceWarningPostBattleOnlyWarning,
              key: const Key('advanceWarningPostBattleOnlyWarning'),
              style: appTextStyle(
                context,
                SettingsTileTypography.description.copyWith(
                  color: appColor(context, const Color(0xffd4a85f)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WarningChoice<T> {
  const _WarningChoice({
    required this.key,
    required this.value,
    required this.label,
  });

  final Key key;
  final T value;
  final String label;
}

class _WarningDropdownRow<T> extends StatelessWidget {
  const _WarningDropdownRow({
    super.key,
    required this.dropdownKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final Key dropdownKey;
  final String title;
  final String subtitle;
  final T value;
  final List<_WarningChoice<T>> choices;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StatusEffectRow(
      title: title,
      subtitle: subtitle,
      enabled: true,
      trailing: DropdownButton<T>(
        key: dropdownKey,
        value: value,
        underline: const SizedBox(),
        alignment: AlignmentDirectional.centerEnd,
        isExpanded: true,
        itemHeight: null,
        items: [
          for (final choice in choices)
            DropdownMenuItem<T>(
              key: choice.key,
              value: choice.value,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(choice.label, textAlign: TextAlign.end),
            ),
        ],
        onChanged: (selection) {
          if (selection != null) onChanged(selection);
        },
      ),
    );
  }
}

String _pulseFilterLabel(AppLocalizations l10n, DamagePulseFilter filter) =>
    switch (filter) {
      DamagePulseFilter.off => l10n.battleEffectOff,
      DamagePulseFilter.minorOnly => l10n.battleEffectMinorOnly,
      DamagePulseFilter.moderateOnly => l10n.battleEffectModerateOnly,
      DamagePulseFilter.heavyOnly => l10n.battleEffectHeavyOnly,
      DamagePulseFilter.all => l10n.battleEffectAll,
    };

String _moraleSparkleModeLabel(AppLocalizations l10n, MoraleSparkleMode mode) =>
    switch (mode) {
      MoraleSparkleMode.blinking => l10n.battleMoraleSparkleBlinking,
      MoraleSparkleMode.steady => l10n.battleMoraleSparkleSteady,
      MoraleSparkleMode.off => l10n.battleEffectOff,
    };

String _scopeLabel(AppLocalizations l10n, BattleEffectDisplayScope scope) =>
    switch (scope) {
      BattleEffectDisplayScope.predictionOnly =>
        l10n.battleEffectScopePredictionOnly,
      BattleEffectDisplayScope.fleetOnly => l10n.battleEffectScopeFleetOnly,
      BattleEffectDisplayScope.all => l10n.battleEffectScopeAll,
    };

String _vibrationFilterLabel(
  AppLocalizations l10n,
  DamageVibrationFilter filter,
) => switch (filter) {
  DamageVibrationFilter.off => l10n.battleEffectOff,
  DamageVibrationFilter.moderateOnly => l10n.battleEffectModerateOnly,
  DamageVibrationFilter.heavyOnly => l10n.battleEffectHeavyOnly,
  DamageVibrationFilter.all => l10n.battleEffectAll,
};

Widget _fitDropdown({required double maxWidth, required Widget child}) =>
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: IntrinsicWidth(child: child),
    );

class _StatusEffectRow extends StatelessWidget {
  const _StatusEffectRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: appTextStyle(
            context,
            SettingsTileTypography.title.copyWith(
              color: enabled ? null : const Color(0xff526776),
            ),
          ),
        ),
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
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final dropdown = _fitDropdown(
          maxWidth: (constraints.maxWidth - 32) * (compact ? 1 : .5),
          child: trailing,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    text,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: dropdown),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    dropdown,
                  ],
                ),
        );
      },
    );
  }
}
