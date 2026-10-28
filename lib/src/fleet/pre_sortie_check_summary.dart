import '../widgets/app_segmented_style.dart';
import '../theme/app_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'dashboard_card.dart';
import '../layout/flat_empty_text.dart';
import '../layout/flat_list_row.dart';
import '../layout/flat_style.dart';
import '../layout/flat_text_toggle.dart';
import '../layout/hd_dashboard_content.dart';
import '../layout/module_summaries.dart';
import '../layout/panel_style.dart';
import 'fleet_ui_strings.dart';
import 'pre_sortie_warnings.dart';
import '../settings/layout_settings_controller.dart';
import '../settings/module_display_settings.dart';

enum SortieCheckMode { ships, maps }

class PreSortieCheckSummary extends StatefulWidget {
  const PreSortieCheckSummary({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenFleet,
    this.settingsController,
    this.showLogo = true,
    this.showTitle = true,
    this.onOpenDisplaySettings,
    this.warningFocusRequest,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;
  final LayoutSettingsController? settingsController;
  final bool showLogo;
  final bool showTitle;
  final VoidCallback? onOpenDisplaySettings;
  final ValueListenable<int>? warningFocusRequest;

  @override
  State<PreSortieCheckSummary> createState() => _PreSortieCheckSummaryState();
}

class _PreSortieCheckSummaryState extends State<PreSortieCheckSummary> {
  SortieCheckMode _mode = SortieCheckMode.ships;
  bool _showClearedMaps = false;
  bool _modeRestored = false;

  @override
  void initState() {
    super.initState();
    widget.warningFocusRequest?.addListener(_focusWarnings);
  }

  @override
  void didUpdateWidget(covariant PreSortieCheckSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warningFocusRequest != widget.warningFocusRequest) {
      oldWidget.warningFocusRequest?.removeListener(_focusWarnings);
      widget.warningFocusRequest?.addListener(_focusWarnings);
    }
  }

  @override
  void dispose() {
    widget.warningFocusRequest?.removeListener(_focusWarnings);
    super.dispose();
  }

  void _focusWarnings() => _setMode(SortieCheckMode.ships);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_modeRestored) return;
    final storedMode = PageStorage.maybeOf(context)?.readState(context);
    if (storedMode is String) {
      _mode = SortieCheckMode.values.firstWhere(
        (mode) => mode.name == storedMode,
        orElse: () => _mode,
      );
    }
    _modeRestored = true;
  }

  void _setMode(SortieCheckMode mode) {
    setState(() => _mode = mode);
    PageStorage.maybeOf(context)?.writeState(context, mode.name);
  }

  bool get _effectiveShowClearedMaps =>
      widget.settingsController?.showClearedMaps ?? _showClearedMaps;

  void _toggleShowClearedMaps() {
    final next = !_effectiveShowClearedMaps;
    if (widget.settingsController case final settings?) {
      settings.setShowClearedMaps(next);
    } else {
      setState(() => _showClearedMaps = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.settingsController != null) widget.settingsController!,
      ]),
      builder: (context, _) {
        final state = widget.controller.state;
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));

        return DashboardCard(
          collapsedSummary: widget.collapsed
              ? preSortieSummary(
                  l10n,
                  generatePreSortieWarnings(context, state, l10n).length,
                )
              : null,
          headerAction: moduleDisplayGear(
            context,
            'pre_sortie',
            widget.onOpenDisplaySettings,
          ),
          title: l10n.preSortieCheck,
          icon: const Icon(Icons.security_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          showLogo: widget.showLogo,
          showTitle: widget.showTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (HdModuleColumns.of(context) > 1 &&
                  _mode == SortieCheckMode.maps) ...[
                _buildShowClearedToggle(l10n),
                const SizedBox(width: 6),
              ],
              _SortieSummaryModeSelector(
                mode: _mode,
                shipsLabel: l10n.sortieCheckShipsMode,
                mapsLabel: l10n.sortieCheckMapsMode,
                onChanged: _setMode,
              ),
            ],
          ),
          child: _mode == SortieCheckMode.ships
              ? _buildShipsCheckView(state, l10n)
              : _buildMapsGaugeView(state, l10n),
        );
      },
    );
  }

  Widget _buildShipsCheckView(GameState state, AppLocalizations l10n) {
    final warnings = generatePreSortieWarnings(context, state, l10n);
    final flat = PanelStyleScope.isFlat(context);
    if (warnings.isEmpty) {
      if (flat) return FlatEmptyText(l10n.noSortieWarnings);
      return Center(
        child: Text(
          l10n.noSortieWarnings,
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xff8197a5)),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget buildFlatWarning(PreSortieWarning warning) => Padding(
      key: Key(
        'pre-sortie-warning-surface-${warning.fleetId}-${warning.kind.keyName}',
      ),
      padding: const EdgeInsets.only(bottom: flatRowSpacing),
      child: InkWell(
        key: Key(
          'pre-sortie-warning-${warning.fleetId}-${warning.kind.keyName}',
        ),
        onTap: () => widget.onOpenFleet(warning.fleetId),
        child: FlatIconLine(
          icon: warning.kind.icon,
          color: warning.kind.foreground,
          size: 12,
          child: Text(
            warning.message,
            style: flatRowTextStyle(context, color: warning.kind.foreground),
          ),
        ),
      ),
    );

    Widget buildWarning(PreSortieWarning warning) => Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        key: Key(
          'pre-sortie-warning-surface-${warning.fleetId}-${warning.kind.keyName}',
        ),
        color: appColor(
          context,
          warning.kind.foreground.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: appColor(context, warning.kind.foreground),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key(
            'pre-sortie-warning-${warning.fleetId}-${warning.kind.keyName}',
          ),
          onTap: () => widget.onOpenFleet(warning.fleetId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  warning.kind.icon,
                  color: appColor(context, warning.kind.foreground),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning.message,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: warning.kind.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (flat) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: warnings.map(buildFlatWarning).toList(),
      );
    }
    final columns = HdModuleColumns.of(context);
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings.map(buildWarning).toList(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const textInsets = 48.0; // Padding, icon and icon-to-text gap.
        final cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          children: [
            for (final warning in warnings)
              Builder(
                builder: (context) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: warning.message,
                      style: appTextStyle(
                        context,
                        DefaultTextStyle.of(context).style.merge(
                          const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    locale: Localizations.maybeLocaleOf(context),
                  )..layout();
                  final fullRow =
                      warning.message.contains('\n') ||
                      painter.width > cellWidth - textInsets;
                  painter.dispose();
                  return SizedBox(
                    width: fullRow ? constraints.maxWidth : cellWidth,
                    child: buildWarning(warning),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildMapsGaugeView(GameState state, AppLocalizations l10n) {
    final flat = PanelStyleScope.isFlat(context);
    final allGauges = state.memberMapInfos.values
        .where((m) => m.hasGauge)
        .toList();

    if (allGauges.isEmpty && flat) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlatEmptyText(l10n.noMapGaugeData),
          Text(
            l10n.noMapGaugeDataHint,
            style: TextStyle(
              color: appColor(context, const Color(0xff4a5c68)),
              fontSize: flatRowFontSize,
            ),
          ),
        ],
      );
    }
    if (allGauges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.noMapGaugeData,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xff8197a5)),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.noMapGaugeDataHint,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xff4a5c68)),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayedGauges = _effectiveShowClearedMaps
        ? allGauges
        : allGauges.where((m) => !m.isGaugeCleared).toList();

    displayedGauges.sort((a, b) {
      if (a.isGaugeCleared != b.isGaugeCleared) {
        return a.isGaugeCleared ? 1 : -1;
      }
      if (a.isEvent != b.isEvent) {
        return a.isEvent ? -1 : 1;
      }
      if (a.mapAreaId != b.mapAreaId) {
        return a.mapAreaId.compareTo(b.mapAreaId);
      }
      if (a.mapNo != b.mapNo) {
        return a.mapNo.compareTo(b.mapNo);
      }
      return (a.gaugeNum ?? 0).compareTo(b.gaugeNum ?? 0);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (HdModuleColumns.of(context) == 1) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _buildShowClearedToggle(l10n),
          ),
          const SizedBox(height: 4),
        ],
        if (displayedGauges.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.allMapsCleared,
                style: TextStyle(
                  color: appColor(context, const Color(0xff8197a5)),
                  fontSize: flat ? flatRowFontSize : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          HdDashboardItems(
            spacing: 0,
            runSpacing: 0,
            children: displayedGauges
                .map(
                  (gauge) => _MapGaugeRow(
                    key: Key('map-gauge-row-${gauge.mapAreaId}-${gauge.mapNo}'),
                    gauge: gauge,
                    state: state,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildShowClearedToggle(AppLocalizations l10n) => InkWell(
    key: const Key('map-gauge-toggle-show-cleared'),
    onTap: _toggleShowClearedMaps,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _effectiveShowClearedMaps
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank_outlined,
            size: 14,
            color: appColor(context, Colors.white),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.showClearedMaps,
              style: appTextStyle(
                context,
                TextStyle(
                  fontSize: 11,
                  color: appColor(context, Colors.white),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SortieSummaryModeSelector extends StatelessWidget {
  const _SortieSummaryModeSelector({
    required this.mode,
    required this.shipsLabel,
    required this.mapsLabel,
    required this.onChanged,
  });

  final SortieCheckMode mode;
  final String shipsLabel;
  final String mapsLabel;
  final ValueChanged<SortieCheckMode> onChanged;

  @override
  Widget build(BuildContext context) {
    if (PanelStyleScope.isFlat(context)) {
      return FlatTextToggle(
        key: const Key('sortie-check-mode-selector'),
        options: [
          FlatTextToggleOption(
            key: const Key('sortie-check-mode-ships'),
            label: shipsLabel,
            selected: mode == SortieCheckMode.ships,
            onTap: () => onChanged(SortieCheckMode.ships),
          ),
          FlatTextToggleOption(
            key: const Key('sortie-check-mode-maps'),
            label: mapsLabel,
            selected: mode == SortieCheckMode.maps,
            onTap: () => onChanged(SortieCheckMode.maps),
          ),
        ],
      );
    }
    return Container(
      key: const Key('sortie-check-mode-selector'),
      height: AppSegmentedStyle.compactHeight,
      padding: AppSegmentedStyle.padding(compact: true),
      decoration: AppSegmentedStyle.decoration(context, compact: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            key: const Key('sortie-check-mode-ships'),
            label: shipsLabel,
            selected: mode == SortieCheckMode.ships,
            onTap: () => onChanged(SortieCheckMode.ships),
          ),
          _ModeButton(
            key: const Key('sortie-check-mode-maps'),
            label: mapsLabel,
            selected: mode == SortieCheckMode.maps,
            onTap: () => onChanged(SortieCheckMode.maps),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppSegmentedStyle.selection(context, selected),
      borderRadius: AppSegmentedStyle.itemRadius(compact: true),
      child: InkWell(
        borderRadius: AppSegmentedStyle.itemRadius(compact: true),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            label,
            style: AppSegmentedStyle.textStyle(
              context,
              selected: selected,
              compact: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGaugeRow extends StatelessWidget {
  const _MapGaugeRow({super.key, required this.gauge, required this.state});

  final MemberMapInfo gauge;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final displayName = gauge.displayName.isNotEmpty
        ? gauge.displayName
        : (state.mapName(gauge.mapAreaId, gauge.mapNo) ?? '');
    final rankText = gauge.rankName != null ? ' ${gauge.rankName}' : '';
    final gaugeNumText =
        (gauge.gaugeNum != null &&
            gauge.gaugeMaxNum != null &&
            gauge.gaugeMaxNum! > 1)
        ? ' (${gauge.gaugeNum}/${gauge.gaugeMaxNum})'
        : '';

    final tagBg = switch (gauge.categoryTag) {
      'Extra' => const Color(0xff1565c0),
      'SP Normal' => const Color(0xff00897b),
      'Event' => const Color(0xff6a1b9a),
      _ => const Color(0xff37474f),
    };

    final percentage = gauge.percentage;
    final isCleared = gauge.isGaugeCleared;

    final flatTagColor = switch (gauge.categoryTag) {
      'Extra' => const Color(0xff64b5f6),
      'SP Normal' => const Color(0xff4db6ac),
      'Event' => const Color(0xffba68c8),
      _ => const Color(0xff90a4ae),
    };
    final flat = PanelStyleScope.isFlat(context);
    final nameColor = isCleared
        ? const Color(0xff607786)
        : const Color(0xffdce6eb);
    final valueColor = isCleared
        ? const Color(0xff607786)
        : const Color(0xff70c7bc);
    if (flat) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: flatRowSpacing / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlatListRow(
              tags: [
                flatRowText(
                  context,
                  fleetText(context, gauge.categoryTag),
                  color: flatTagColor,
                ),
              ],
              name: flatRowText(
                context,
                '${gauge.code} $displayName$rankText$gaugeNumText',
                color: nameColor,
              ),
              trailing: flatRowTrailing(
                Text(
                  '${gauge.currentGaugeValue} / ${gauge.maxGaugeValue}',
                  style: flatRowTextStyle(context, color: valueColor).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            _gaugeBar(context, percentage, 4),
          ],
        ),
      );
    }

    final tagStyle = appTextStyle(
      context,
      TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        color:
            AppPalette.of(context).isDark ||
                appColor(context, tagBg).computeLuminance() < .179
            ? appOnAccentColor(context, Colors.white)
            : appColor(context, Colors.white),
      ),
    );
    final nameStyle = appTextStyle(
      context,
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: nameColor),
    );
    final valueStyle = appTextStyle(
      context,
      TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: valueColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final categoryLabel = fleetText(context, gauge.categoryTag);
    final gaugeValue = '${gauge.currentGaugeValue} / ${gauge.maxGaugeValue}';
    final category = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: appColor(context, tagBg),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(categoryLabel, style: tagStyle),
    );
    final mapName = Text(
      '${gauge.code} $displayName$rankText$gaugeNumText',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );
    final value = Text(gaugeValue, style: valueStyle);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: appColor(context, Color(0xff0d1a26)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: appColor(
              context,
              isCleared ? const Color(0xff1e303d) : const Color(0xff294052),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                double textWidth(String text, TextStyle style) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: text,
                      style: DefaultTextStyle.of(context).style.merge(style),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    locale: Localizations.maybeLocaleOf(context),
                    maxLines: 1,
                  )..layout();
                  final width = painter.width;
                  painter.dispose();
                  return width;
                }

                // Preserve the usual row while the category, value and some
                // map name fit. Narrow cards keep the same readable font size.
                final rowMinimumWidth =
                    textWidth(categoryLabel, tagStyle) +
                    10 +
                    textWidth(gaugeValue, valueStyle) +
                    14 +
                    textWidth(gauge.code, nameStyle);
                if (constraints.maxWidth >= rowMinimumWidth) {
                  return Row(
                    children: [
                      category,
                      const SizedBox(width: 6),
                      Expanded(child: mapName),
                      const SizedBox(width: 8),
                      value,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mapName,
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [category, value],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 5),
            _gaugeBar(context, percentage, 5),
          ],
        ),
      ),
    );
  }

  Widget _gaugeBar(BuildContext context, double percentage, double height) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: height,
          color: appColor(context, const Color(0xff142735)),
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth * percentage,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: appColors(
                      context,
                      percentage > 0
                          ? (gauge.isEvent
                                ? const [Color(0xff7e57c2), Color(0xffab47bc)]
                                : const [Color(0xff26a69a), Color(0xff4db6ac)])
                          : const [Color(0xff37474f), Color(0xff455a64)],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}
