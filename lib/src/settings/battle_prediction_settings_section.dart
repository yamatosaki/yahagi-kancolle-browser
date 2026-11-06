import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../widgets/top_notice.dart';
import 'battle_prediction_settings.dart';
import 'settings_ui_helpers.dart';

class BattlePredictionSettingsSection extends StatelessWidget
    with SettingsUIHelpers {
  const BattlePredictionSettingsSection({super.key, required this.controller});

  final BattlePredictionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          buildSwitchTile(
            title: l10n.battleEnemyPreviewPortraits,
            switchKey: const Key('battle-enemy-preview-portraits'),
            subtitle: l10n.battleEnemyPreviewPortraitsDesc,
            value: controller.enemyPortraitsEnabled,
            onChanged: controller.setEnemyPortraitsEnabled,
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildSwitchTile(
            title: l10n.battleLastFormationHint,
            switchKey: const Key('battle-last-formation-hint'),
            subtitle: l10n.battleLastFormationHintDesc,
            value: controller.lastFormationHintEnabled,
            onChanged: controller.setLastFormationHintEnabled,
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildActionTile(
            title: l10n.fleetInformationSyncTitle,
            subtitle:
                controller.fleetInformationSyncMode ==
                    FleetInformationSyncMode.immediate
                ? l10n.fleetInformationSyncImmediateDesc
                : l10n.fleetInformationSyncSettlementDesc,
            trailing: DropdownButton<FleetInformationSyncMode>(
              key: const Key('fleet-information-sync-mode'),
              barrierDismissible: false,
              value: controller.fleetInformationSyncMode,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: FleetInformationSyncMode.immediate,
                  child: Text(l10n.fleetInformationSyncImmediate),
                ),
                DropdownMenuItem(
                  value: FleetInformationSyncMode.settlement,
                  child: Text(l10n.fleetInformationSyncSettlement),
                ),
              ],
              onChanged: (mode) async {
                if (mode == null) return;
                try {
                  await controller.setFleetInformationSyncMode(mode);
                } catch (_) {
                  if (!context.mounted) return;
                  TopNotice.show(
                    context,
                    message: l10n.fleetInformationSyncSaveFailed,
                    tone: TopNoticeTone.error,
                  );
                }
              },
            ),
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildActionTile(
            key: const Key('battle-section-order'),
            title: l10n.battleSectionOrder,
            subtitle: l10n.battleSectionOrderDescription,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.battleSectionOrderAdjust,
                  style: appTextStyle(
                    context,
                    SettingsTileTypography.description.copyWith(
                      fontSize: Theme.of(
                        context,
                      ).textTheme.titleMedium?.fontSize,
                      color: const Color(0xffd4a85f),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: appColor(context, Color(0xffd4a85f)),
                ),
              ],
            ),
            onTap: () => _showOrderSheet(context),
          ),
        ],
      ),
    );
  }

  void _showOrderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: appColor(context, Colors.transparent),
      constraints: const BoxConstraints(maxWidth: 444),
      builder: (sheetContext) => _BattlePredictionOrderSheet(
        controller: controller,
        onSaveFailed: () {
          if (!context.mounted) return;
          TopNotice.show(
            context,
            message: AppLocalizations.of(context)!.battleSectionOrderSaveFailed,
            tone: TopNoticeTone.error,
          );
        },
      ),
    );
  }
}

String _sectionLabel(AppLocalizations l10n, BattlePredictionSection section) =>
    switch (section) {
      BattlePredictionSection.sortieMap => l10n.battleSectionSortieMap,
      BattlePredictionSection.enemyPreview => l10n.battleSectionEnemyPreview,
      BattlePredictionSection.predictionResult =>
        l10n.battleSectionPredictionResult,
    };

class _BattlePredictionOrderSheet extends StatefulWidget {
  const _BattlePredictionOrderSheet({
    required this.controller,
    required this.onSaveFailed,
  });

  final BattlePredictionSettingsController controller;
  final VoidCallback onSaveFailed;

  @override
  State<_BattlePredictionOrderSheet> createState() =>
      _BattlePredictionOrderSheetState();
}

class _BattlePredictionOrderSheetState
    extends State<_BattlePredictionOrderSheet> {
  bool _saving = false;
  bool _saveFailed = false;
  final _errorKey = GlobalKey();

  Future<void> _save(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(() => _saveFailed = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final errorContext = _errorKey.currentContext;
          if (!mounted || errorContext == null) return;
          Scrollable.ensureVisible(errorContext);
        });
      }
      widget.onSaveFailed();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        key: const Key('battle-section-order-sheet'),
        color: appColor(context, Color(0xff142735)),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const Key('battle-section-order-scroll'),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final order = widget.controller.sectionOrder;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 30,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: appColor(context, const Color(0xff526776)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      l10n.battleSectionOrder,
                      style: TextStyle(
                        color: appColor(context, Color(0xffe1eaf0)),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.battleSectionOrderHint,
                      style: appTextStyle(
                        context,
                        SettingsTileTypography.description,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: appColor(context, const Color(0xff10212e)),
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          for (
                            var index = 0;
                            index < order.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Divider(
                                color: appColor(context, Color(0xff203746)),
                                height: 1,
                              ),
                            _buildRow(l10n, order[index], index, order.length),
                          ],
                        ],
                      ),
                    ),
                    if (_saveFailed) ...<Widget>[
                      const SizedBox(height: 10),
                      Semantics(
                        key: _errorKey,
                        liveRegion: true,
                        child: Text(
                          l10n.battleSectionOrderSaveFailed,
                          key: const Key('battle-section-order-error'),
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.description.copyWith(
                              color: const Color(0xffff8c78),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OverflowBar(
                      alignment: MainAxisAlignment.spaceBetween,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 8,
                      overflowSpacing: 8,
                      children: <Widget>[
                        TextButton(
                          key: const Key('battle-section-order-reset'),
                          onPressed: _saving
                              ? null
                              : () =>
                                    _save(widget.controller.resetSectionOrder),
                          style: TextButton.styleFrom(
                            foregroundColor: appColor(
                              context,
                              Color(0xffd4a85f),
                            ),
                            minimumSize: const Size(44, 44),
                            textStyle: SettingsTileTypography.title,
                          ),
                          child: Text(l10n.battleSectionOrderRestoreDefault),
                        ),
                        FilledButton(
                          key: const Key('battle-section-order-done'),
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: appColor(
                              context,
                              Color(0xffd4a85f),
                            ),
                            foregroundColor: appOnAccentColor(
                              context,
                              Color(0xff332914),
                            ),
                            minimumSize: const Size(64, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            textStyle: SettingsTileTypography.title,
                          ),
                          child: Text(l10n.done),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    AppLocalizations l10n,
    BattlePredictionSection section,
    int index,
    int length,
  ) {
    final label = _sectionLabel(l10n, section);
    return Padding(
      key: Key('battle-section-row-${section.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 16,
            child: Text(
              '${index + 1}',
              style: appTextStyle(context, SettingsTileTypography.description),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: appColor(context, Color(0xffe1eaf0)),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _moveButton(
            section: section,
            delta: -1,
            tooltip: l10n.battleSectionOrderMoveUp(label),
            enabled: !_saving && index > 0,
          ),
          _moveButton(
            section: section,
            delta: 1,
            tooltip: l10n.battleSectionOrderMoveDown(label),
            enabled: !_saving && index < length - 1,
          ),
        ],
      ),
    );
  }

  Widget _moveButton({
    required BattlePredictionSection section,
    required int delta,
    required String tooltip,
    required bool enabled,
  }) {
    return IconButton(
      key: Key('battle-section-${delta < 0 ? 'up' : 'down'}-${section.name}'),
      tooltip: tooltip,
      onPressed: enabled
          ? () => _save(() => widget.controller.moveSection(section, delta))
          : null,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      color: appColor(context, Color(0xffe1eaf0)),
      disabledColor: appColor(context, Color(0xff405462)),
      icon: Icon(
        delta < 0 ? Icons.arrow_upward : Icons.arrow_downward,
        size: 19,
      ),
    );
  }
}
