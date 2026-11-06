import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../browser/game_surface_dialog.dart';
import '../fleet/dashboard_card.dart';
import '../game_state/game_state_controller.dart';
import '../layout/flat_empty_text.dart';
import '../layout/flat_style.dart';
import '../layout/flat_text_toggle.dart';
import '../layout/flat_underline_tabs.dart';
import '../layout/hd_dashboard_content.dart';
import '../layout/panel_style.dart';
import '../localization/game_name_localizations.dart';
import '../settings/module_display_settings.dart';
import '../theme/app_palette.dart';
import '../widgets/app_segmented_style.dart';
import 'sortie_experience_controller.dart';
import 'sortie_experience_row.dart';
import 'sortie_experience_ship_filter.dart';
import 'sortie_experience_strings.dart';

class SortieExperienceCard extends StatefulWidget {
  const SortieExperienceCard({
    super.key,
    required this.controller,
    required this.gameState,
    required this.collapsed,
    required this.onToggleCollapse,
    this.showLogo = true,
    this.showTitle = true,
    this.onOpenDisplaySettings,
  });

  final SortieExperienceController controller;
  final GameStateController gameState;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final bool showLogo;
  final bool showTitle;
  final VoidCallback? onOpenDisplaySettings;

  @override
  State<SortieExperienceCard> createState() => _SortieExperienceCardState();
}

class _SortieExperienceCardState extends State<SortieExperienceCard> {
  bool _showTotal = false;
  bool _totalDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('zh');
    final l10n = AppLocalizations.of(context) ?? lookupAppLocalizations(locale);
    final strings = SortieExperienceStrings(locale);
    final numberFormat = NumberFormat.decimalPattern(l10n.localeName);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, widget.gameState]),
      builder: (context, _) {
        final snapshot = controller.sortie;
        final active = controller.isActive;
        final statusLabel = switch ((snapshot?.isPractice ?? false, active)) {
          (true, true) => strings.practiceActive,
          (true, false) => strings.practiceSettled,
          (false, true) => strings.active,
          (false, false) => strings.returned,
        };
        final palette = AppPalette.of(context);
        final options = [
          FlatTextToggleOption(
            key: const Key('sortie-exp-tab-sortie'),
            label: snapshot != null && !active
                ? strings.lastSortie
                : l10n.thisSortie,
            selected: !_showTotal,
            onTap: () => setState(() => _showTotal = false),
          ),
          FlatTextToggleOption(
            key: const Key('sortie-exp-tab-total'),
            label: strings.total,
            selected: _showTotal,
            onTap: () => setState(() => _showTotal = true),
          ),
        ];
        return DashboardCard(
          title: l10n.sortieExperience,
          icon: const Icon(Icons.trending_up),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          showLogo: widget.showLogo,
          showTitle: widget.showTitle,
          headerAction: moduleDisplayGear(
            context,
            'sortie_experience',
            widget.onOpenDisplaySettings,
          ),
          titleBadge: _showTotal || snapshot == null
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: active ? palette.successSurface : palette.raised,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    child: Text(
                      statusLabel,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: active ? palette.success : palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
          child: widget.collapsed
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ExperienceSwitcher(options: options),
                      const SizedBox(height: 7),
                      if (_showTotal)
                        _buildTotal(context, strings, l10n, numberFormat)
                      else if (snapshot == null)
                        _ExperienceMessage(text: strings.waiting)
                      else
                        _buildSortie(
                          context,
                          strings,
                          l10n,
                          numberFormat,
                          snapshot,
                          active,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSortie(
    BuildContext context,
    SortieExperienceStrings strings,
    AppLocalizations l10n,
    NumberFormat format,
    SortieExperienceSnapshot snapshot,
    bool active,
  ) {
    final location = [
      if (snapshot.isPractice)
        l10n.questExercise
      else if (snapshot.mapAreaId > 0 && snapshot.mapInfoNo > 0)
        '${snapshot.mapAreaId}-${snapshot.mapInfoNo}',
      if (snapshot.deckId > 0) strings.fleet(snapshot.deckId),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 3,
          children: [
            _summary(
              context,
              strings.battles(
                format.format(snapshot.battles),
                singular: snapshot.battles == 1,
              ),
            ),
            if (location.isNotEmpty) _secondary(context, location),
          ],
        ),
        const SizedBox(height: 6),
        if (snapshot.incomplete) ...[
          _secondary(context, strings.incomplete),
          const SizedBox(height: 5),
        ],
        if (snapshot.ships.isEmpty)
          _ExperienceMessage(text: strings.emptyRoster)
        else
          _shipTable(
            context,
            strings,
            l10n,
            format,
            snapshot.ships,
            active: active,
            mainFleetId: snapshot.deckId,
            unverifiedShipIds: snapshot.unverifiedShipIds,
          ),
      ],
    );
  }

  Widget _buildTotal(
    BuildContext context,
    SortieExperienceStrings strings,
    AppLocalizations l10n,
    NumberFormat format,
  ) {
    final controller = widget.controller;
    final account = controller.accountScope;
    final palette = AppPalette.of(context);
    final ready = controller.isReady && !controller.storageUnavailable;
    final allShips = controller.totals;
    final hidden = controller.hiddenTotalShipIds;
    final ships = hidden.isEmpty
        ? allShips
        : allShips.where((ship) => !hidden.contains(ship.ownedShipId)).toList();
    final flat = PanelStyleScope.isFlat(context);
    final controlHeight = flat
        ? FlatUnderlineTabs.height
        : AppSegmentedStyle.compactHeight -
              AppSegmentedStyle.padding(compact: true).vertical -
              AppSegmentedStyle.decoration(
                context,
                compact: true,
              ).padding.vertical;
    final controlTextStyle = AppSegmentedStyle.textStyle(
      context,
      selected: false,
      compact: true,
      fontSize: flat ? flatRowFontSize : null,
    );
    final buttonTextStyle =
        Theme.of(context).textTheme.labelLarge?.merge(controlTextStyle) ??
        controlTextStyle;
    final clearLabel = TextPainter(
      text: TextSpan(text: strings.clear, style: buttonTextStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final capsuleSize = Size(
      math.max(32.0, clearLabel.width.ceilToDouble() + 16),
      math.max(controlHeight, clearLabel.height.ceilToDouble()),
    );
    clearLabel.dispose();
    ButtonStyle capsuleStyle(Color background, Color foreground) =>
        FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: .35),
          disabledForegroundColor: foreground,
          textStyle: buttonTextStyle,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          fixedSize: capsuleSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          shape: RoundedRectangleBorder(
            borderRadius: AppSegmentedStyle.itemRadius(compact: true),
          ),
        );
    return Column(
      key: ValueKey(account),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Wrap(
              spacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _summary(
                  context,
                  strings.totalCount(format.format(controller.totalSorties)),
                ),
                _secondary(
                  context,
                  strings.totalUnit(singular: controller.totalSorties == 1),
                ),
              ],
            ),
            Wrap(
              spacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: strings.tracking,
                      child: SizedBox(
                        height: controlHeight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Switch(
                            key: const Key('sortie-exp-tracking-switch'),
                            value: controller.trackingEnabled,
                            onChanged: ready
                                ? (value) => controller.setTrackingEnabled(
                                    value,
                                    expectedAccount: account,
                                  )
                                : null,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeTrackColor: palette.successSurface,
                            activeThumbColor: palette.success,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      controller.trackingEnabled ? strings.on : strings.off,
                      style: appTextStyle(
                        context,
                        controlTextStyle.copyWith(color: palette.muted),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (buttonContext) => Wrap(
                    spacing: 5,
                    runSpacing: 2,
                    children: [
                      Tooltip(
                        message: strings.filterTitle,
                        child: FilledButton(
                          key: const Key('sortie-exp-filter-total'),
                          onPressed:
                              ready &&
                                  controller.isTotalShipVisibilityReady &&
                                  allShips.isNotEmpty
                              ? () => _showTotalShipFilter(
                                  buttonContext,
                                  controller,
                                  account,
                                )
                              : null,
                          style: capsuleStyle(
                            const Color(0xfff0c06f),
                            const Color(0xff342500),
                          ),
                          child: const Icon(Icons.filter_alt_rounded, size: 16),
                        ),
                      ),
                      FilledButton(
                        key: const Key('sortie-exp-clear-total'),
                        onPressed: ready && controller.totalSorties > 0
                            ? () => _confirmClearTotal(
                                buttonContext,
                                controller,
                                account,
                                strings,
                                l10n,
                              )
                            : null,
                        style: capsuleStyle(palette.error, Colors.white),
                        child: Text(strings.clear),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (controller.storageUnavailable) ...[
          _ExperienceMessage(text: strings.storageUnavailable),
          if (allShips.isNotEmpty) const SizedBox(height: 5),
        ],
        if (ships.isNotEmpty)
          _shipTable(context, strings, l10n, format, ships, active: false)
        else if (allShips.isNotEmpty)
          _ExperienceMessage(text: strings.noVisibleShips)
        else if (!controller.storageUnavailable)
          _ExperienceMessage(
            text: !controller.isReady
                ? l10n.waitingForSortieData
                : controller.trackingEnabled
                ? strings.trackingHint
                : strings.offHint,
          ),
      ],
    );
  }

  Future<void> _showTotalShipFilter(
    BuildContext context,
    SortieExperienceController controller,
    AccountScope account,
  ) async {
    bool ownerIsCurrent() =>
        context.mounted &&
        identical(widget.controller, controller) &&
        identical(controller.accountScope, account) &&
        controller.isReady &&
        !controller.storageUnavailable &&
        controller.isTotalShipVisibilityReady;

    if (_totalDialogOpen || !ownerIsCurrent()) return;
    _totalDialogOpen = true;
    try {
      await showSortieExperienceShipFilter(
        context: context,
        controller: controller,
        gameState: widget.gameState,
        account: account,
        ownerIsCurrent: ownerIsCurrent,
      );
    } finally {
      _totalDialogOpen = false;
    }
  }

  Future<void> _confirmClearTotal(
    BuildContext context,
    SortieExperienceController controller,
    AccountScope account,
    SortieExperienceStrings strings,
    AppLocalizations l10n,
  ) async {
    bool canClear() =>
        context.mounted &&
        identical(widget.controller, controller) &&
        identical(controller.accountScope, account) &&
        controller.isReady &&
        !controller.storageUnavailable &&
        controller.totalSorties > 0;

    if (_totalDialogOpen || !canClear()) return;
    _totalDialogOpen = true;
    try {
      final confirmed = await showGameSurfaceDialog<bool>(
        context: context,
        title: strings.clearTitle,
        message: strings.clearMessage,
        actions: [
          GameSurfaceDialogAction(
            id: 'cancel',
            label: l10n.cancel,
            value: false,
          ),
          GameSurfaceDialogAction(
            id: 'confirm',
            label: l10n.confirm,
            value: true,
            variant: 'filled',
          ),
        ],
        builder: (_, close) => AlertDialog(
          key: const Key('sortie-exp-clear-dialog'),
          scrollable: true,
          title: Text(strings.clearTitle),
          content: Text(strings.clearMessage),
          actions: [
            TextButton(
              key: const Key('sortie-exp-clear-cancel'),
              onPressed: () => close(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('sortie-exp-clear-confirm'),
              onPressed: () => close(true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed == true && canClear()) {
        await controller.clearTotal(expectedAccount: account);
      }
    } finally {
      _totalDialogOpen = false;
    }
  }

  Widget _shipTable(
    BuildContext context,
    SortieExperienceStrings strings,
    AppLocalizations l10n,
    NumberFormat format,
    List<SortieExperienceShip> ships, {
    required bool active,
    int? mainFleetId,
    Set<int> unverifiedShipIds = const {},
  }) {
    final flat = PanelStyleScope.isFlat(context);
    final palette = AppPalette.of(context);
    final expColor = palette.isDark
        ? Color(active ? 0xfff7cf75 : 0xff8adac7)
        : active
        ? palette.warning
        : palette.success;
    final names = gameNames(context);
    final masterShips = widget.gameState.state.masterShips;
    final fleets = <int, List<SortieExperienceShip>>{};
    if (mainFleetId != null) {
      for (final ship in ships) {
        fleets.putIfAbsent(ship.fleetId, () => []).add(ship);
      }
    }
    Widget table(double width, {int? fleetId}) {
      final compact = width <= 248;
      final padding = EdgeInsets.symmetric(
        horizontal: flat ? 2 : (compact ? 4 : 8),
      );
      final gap = SizedBox(width: compact ? 4 : 6);
      final nameWidth = (width - padding.horizontal) * (compact ? 0.29 : 0.35);

      Widget columns(Widget name, Widget progress, Widget amount) => Row(
        children: [
          SizedBox(width: nameWidth.clamp(0.0, 164.0), child: name),
          gap,
          Expanded(flex: compact ? 36 : 30, child: progress),
          gap,
          Expanded(flex: compact ? 35 : 26, child: amount),
        ],
      );

      Widget heading(String label, {bool end = false}) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: end ? Alignment.centerRight : Alignment.centerLeft,
        child: _secondary(context, label),
      );

      Widget fleetHeading(int id) => DecoratedBox(
        decoration: BoxDecoration(
          color: flat ? Colors.transparent : palette.raised,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Padding(
          padding: padding.add(const EdgeInsets.symmetric(vertical: 3)),
          child: _secondary(
            context,
            id == mainFleetId ? strings.fleetMain : strings.fleetEscort,
          ),
        ),
      );

      Widget shipRow(int index, SortieExperienceShip ship) {
        final id = ship.ownedShipId;
        final (:level, :nextExperience) = widget.controller.progressFor(id);
        final captured = !unverifiedShipIds.contains(id);
        final name = names.shipName(
          ship.name.isNotEmpty
              ? ship.name
              : masterShips[ship.masterShipId]?.name ?? strings.unknownShip,
          shipId: ship.masterShipId,
        );
        return DecoratedBox(
          key: Key('sortie-exp-ship-$id'),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : Border(top: BorderSide(color: palette.border)),
          ),
          child: Padding(
            padding: padding.add(const EdgeInsets.symmetric(vertical: 5)),
            child: columns(
              SortieExperienceShipName(
                name: name,
                retreatedLabel: ship.retreated ? strings.retreated : null,
              ),
              SortieExperienceProgress(
                levelText: 'Lv.${level ?? '—'}',
                nextText:
                    'Next. ${nextExperience == null ? '—' : format.format(nextExperience)}',
                levelKey: Key('sortie-exp-level-$id'),
                nextKey: Key('sortie-exp-next-$id'),
              ),
              SortieExperienceAmount(
                value: captured
                    ? '${ship.experience > 0 ? '+' : ''}${format.format(ship.experience)}'
                    : strings.uncaptured,
                unit: captured ? 'EXP' : null,
                color: captured ? expColor : palette.muted,
                valueKey: Key('sortie-exp-value-$id'),
              ),
            ),
          ),
        );
      }

      final groups = fleetId != null
          ? {fleetId: fleets[fleetId]!}
          : fleets.length > 1
          ? fleets
          : {null: ships};
      return ClipRRect(
        borderRadius: BorderRadius.circular(flat ? 0 : 7),
        child: ColoredBox(
          color: flat ? Colors.transparent : palette.inner,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fleetId != null) fleetHeading(fleetId),
              ColoredBox(
                color: flat ? Colors.transparent : palette.raised,
                child: Padding(
                  padding: padding.add(const EdgeInsets.symmetric(vertical: 4)),
                  child: columns(
                    heading(strings.ship),
                    heading(l10n.level),
                    heading(l10n.expCalcAccumulatedExpLabel, end: true),
                  ),
                ),
              ),
              for (final group in groups.entries) ...[
                if (fleetId == null && group.key != null)
                  fleetHeading(group.key!),
                for (final (index, ship) in group.value.indexed)
                  shipRow(index, ship),
              ],
            ],
          ),
        ),
      );
    }

    const fleetGap = 8.0;
    const minFleetWidth = 240.0;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final minColumnWidth =
        minFleetWidth * textScale.clamp(1.0, double.infinity);
    final canSplit =
        HdModuleColumns.of(context) > 1 &&
        fleets.length == 2 &&
        fleets.containsKey(mainFleetId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fleetWidth = (width - fleetGap) / 2;
        if (!canSplit || fleetWidth < minColumnWidth) return table(width);

        final escortFleetId = fleets.keys.firstWhere((id) => id != mainFleetId);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: table(fleetWidth, fleetId: mainFleetId)),
            const SizedBox(width: fleetGap),
            Expanded(child: table(fleetWidth, fleetId: escortFleetId)),
          ],
        );
      },
    );
  }
}

class _ExperienceSwitcher extends StatelessWidget {
  const _ExperienceSwitcher({required this.options});

  final List<FlatTextToggleOption> options;

  @override
  Widget build(BuildContext context) {
    if (PanelStyleScope.isFlat(context)) {
      return FlatUnderlineTabs(options: options);
    }
    return Container(
      height: AppSegmentedStyle.compactHeight,
      padding: AppSegmentedStyle.padding(compact: true),
      decoration: AppSegmentedStyle.decoration(context, compact: true),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Semantics(
                selected: option.selected,
                child: Material(
                  key: option.key,
                  color: AppSegmentedStyle.selection(context, option.selected),
                  borderRadius: AppSegmentedStyle.itemRadius(compact: true),
                  child: InkWell(
                    onTap: option.onTap,
                    borderRadius: AppSegmentedStyle.itemRadius(compact: true),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          option.label,
                          style: AppSegmentedStyle.textStyle(
                            context,
                            selected: option.selected,
                            compact: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExperienceMessage extends StatelessWidget {
  const _ExperienceMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (PanelStyleScope.isFlat(context)) return FlatEmptyText(text);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.of(context).inner,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _secondaryStyle(context),
        ),
      ),
    );
  }
}

Text _summary(BuildContext context, String text) => Text(
  text,
  style: appTextStyle(
    context,
    TextStyle(
      color: AppPalette.of(context).foreground,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  ),
);

Text _secondary(BuildContext context, String text) =>
    Text(text, style: _secondaryStyle(context));

TextStyle _secondaryStyle(BuildContext context) => appTextStyle(
  context,
  TextStyle(color: AppPalette.of(context).muted, fontSize: 11),
);
