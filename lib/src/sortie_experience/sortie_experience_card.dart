import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../browser/game_surface_dialog.dart';
import '../fleet/dashboard_card.dart';
import '../fleet/header_resource_catalog.dart';
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
import 'sortie_resource_ledger.dart';

part 'sortie_experience_resource_view.dart';

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
  bool _showConsumption = false;
  bool _totalDialogOpen = false;
  _ResourceKind? _sortByResource;

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
          titleBadge: !widget.collapsed || _showTotal || snapshot == null
              ? null
              : _sortieStatus(context, statusLabel, active: active),
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
                          statusLabel,
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
    String statusLabel,
  ) {
    final location = snapshot.isPractice
        ? l10n.questExercise
        : snapshot.mapAreaId > 0 && snapshot.mapInfoNo > 0
        ? '${snapshot.mapAreaId}-${snapshot.mapInfoNo}'
        : '—';
    final fleet = snapshot.deckId > 0 ? strings.fleet(snapshot.deckId) : '—';
    final experience = snapshot.ships.fold(
      0,
      (sum, ship) => sum + (snapshot.confirmedExperience(ship) ?? 0),
    );
    final experienceText =
        snapshot.unverifiedShipIds.length == snapshot.ships.length
        ? '—'
        : '+${format.format(experience)} EXP';
    Widget fit(Widget child) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
    TableRow line(Widget left, Widget right, {double top = 0}) => TableRow(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(top: top, end: 5),
          child: left,
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(top: top, start: 5),
          child: right,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryPanel(context, [
          Table(
            key: const Key('sortie-exp-sortie-summary-grid'),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              line(
                fit(_secondary(context, strings.sortieArea)),
                fit(_secondary(context, strings.sortieFleet)),
              ),
              line(
                fit(_summary(context, location)),
                fit(_summary(context, fleet)),
                top: 2,
              ),
              line(
                fit(_secondary(context, strings.settled)),
                fit(
                  _secondary(
                    context,
                    strings.sortieFleetExperience(active: active),
                  ),
                ),
                top: 6,
              ),
              line(
                fit(
                  _summary(
                    context,
                    strings.battleCount(
                      format.format(snapshot.battles),
                      singular: snapshot.battles == 1,
                    ),
                  ),
                ),
                _experienceAmount(
                  context,
                  experienceText,
                  key: const Key('sortie-exp-sortie-experience'),
                  active: active,
                ),
                top: 2,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _sortieStatus(context, statusLabel, active: active),
          ),
        ]),
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
            experienceTotal: experience,
            mainFleetId: snapshot.deckId,
            sortieBattles: snapshot.battles,
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
    final ships = allShips
        .where((ship) => !hidden.contains(ship.ownedShipId))
        .toList();
    final sortBy = _sortByResource;
    if (_showConsumption && sortBy != null) {
      final spending = {
        for (final ship in ships)
          ship.ownedShipId: sortBy.amount(
            controller.resourceSpendingFor(ship.ownedShipId)?.total ??
                const SortieResourceAmounts(),
          ),
      };
      ships.sort((a, b) {
        final byAmount = spending[b.ownedShipId]!.compareTo(
          spending[a.ownedShipId]!,
        );
        if (byAmount != 0) return byAmount;
        final byExperience = b.experience.compareTo(a.experience);
        return byExperience == 0
            ? a.ownedShipId.compareTo(b.ownedShipId)
            : byExperience;
      });
    }
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
        _summaryPanel(context, [
          _summaryPair(
            _summaryMetric(
              context,
              strings.totalRecord,
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
            ),
            _summaryMetric(
              context,
              strings.allShipsExperience,
              _experienceAmount(
                context,
                strings.totalExperience(
                  format.format(controller.totalExperience),
                ),
                key: const Key('sortie-exp-total-experience'),
              ),
            ),
          ),
          const SizedBox(height: 6),
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
                      onPressed:
                          ready &&
                              (controller.totalSorties > 0 ||
                                  controller.hasResourceSpendingData)
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
        ]),
        const SizedBox(height: 4),
        _ExperienceSwitcher(
          options: [
            FlatTextToggleOption(
              key: const Key('sortie-exp-total-tab-experience'),
              label: strings.experienceTab,
              selected: !_showConsumption,
              onTap: () => setState(() => _showConsumption = false),
            ),
            FlatTextToggleOption(
              key: const Key('sortie-exp-total-tab-consumption'),
              label: strings.consumptionTab,
              selected: _showConsumption,
              onTap: () => setState(() => _showConsumption = true),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (controller.storageUnavailable) ...[
          _ExperienceMessage(text: strings.storageUnavailable),
          if (allShips.isNotEmpty) const SizedBox(height: 5),
        ],
        if (_showConsumption && ready) ...[
          _WarehouseSpendingSummary(
            strings: strings,
            localizations: l10n,
            format: format,
            confirmed: controller.totalResourceSpending,
            unallocated: controller.unallocatedResourceSpending,
            incomplete: controller.resourceSpendingIncomplete,
          ),
          const SizedBox(height: 5),
          if (ships.isNotEmpty) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _resourceSortMenu(context, account, strings, l10n),
            ),
            const SizedBox(height: 4),
          ],
        ],
        if (ships.isNotEmpty)
          _PaginatedTotalShips(
            key: ValueKey((controller, account)),
            ships: ships,
            sortByResource: sortBy,
            allShipIds: {for (final ship in allShips) ship.ownedShipId},
            hiddenShipIds: hidden,
            format: format,
            tableBuilder: (pageShips) => _shipTable(
              context,
              strings,
              l10n,
              format,
              pageShips,
              active: false,
              experienceTotal: controller.totalExperience,
              showResourceSpending: _showConsumption,
            ),
          )
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

  Widget _resourceSortMenu(
    BuildContext context,
    AccountScope account,
    SortieExperienceStrings strings,
    AppLocalizations l10n,
  ) {
    final palette = AppPalette.of(context);
    final outline = BorderSide(color: palette.border);
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(116.0, constraints.maxWidth);
        return SizedBox(
          width: width,
          child: MenuAnchor(
            key: ValueKey((controller, account)),
            crossAxisUnconstrained: false,
            consumeOutsideTap: false,
            alignmentOffset: const Offset(0, 3),
            style: MenuStyle(
              alignment: AlignmentDirectional.bottomStart,
              fixedSize: WidgetStatePropertyAll(Size.fromWidth(width)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 3),
              ),
              backgroundColor: WidgetStatePropertyAll(palette.surface),
              side: WidgetStatePropertyAll(outline),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            menuChildren: [
              for (final kind in _ResourceKind.values)
                MenuItemButton(
                  key: Key('sortie-exp-resource-sort-${kind.name}'),
                  style: ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(width, 32)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      kind == _sortByResource
                          ? palette.accent
                          : palette.foreground,
                    ),
                  ),
                  trailingIcon: kind == _sortByResource
                      ? const Icon(Icons.check, size: 14)
                      : null,
                  onPressed: () {
                    if (!mounted ||
                        !identical(widget.controller, controller) ||
                        !identical(controller.accountScope, account)) {
                      return;
                    }
                    setState(() => _sortByResource = kind);
                  },
                  child: Text(
                    kind.label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            builder: (context, menu, _) => TextButton(
              key: const Key('sortie-exp-resource-sort'),
              style: TextButton.styleFrom(
                foregroundColor: palette.muted,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: outline,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: () {
                if (menu.isOpen) {
                  menu.close();
                } else if (!_totalDialogOpen) {
                  menu.open();
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sortByResource?.label(l10n) ?? strings.resourceSort,
                      style: _secondaryStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    menu.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
        (controller.totalSorties > 0 || controller.hasResourceSpendingData);

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

  Future<void> _showResourceBill(
    BuildContext context,
    SortieExperienceController controller,
    AccountScope account,
    SortieExperienceStrings strings,
    AppLocalizations l10n,
    NumberFormat format,
    String name,
    int id,
  ) async {
    if (_totalDialogOpen ||
        !context.mounted ||
        !identical(widget.controller, controller) ||
        !identical(controller.accountScope, account) ||
        !controller.isReady ||
        controller.storageUnavailable) {
      return;
    }
    _totalDialogOpen = true;
    try {
      await _showWarehouseSpendingDialog(
        context,
        strings,
        l10n,
        format,
        name,
        controller.resourceSpendingFor(id),
      );
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
    required int experienceTotal,
    bool showResourceSpending = false,
    int? mainFleetId,
    int? sortieBattles,
    Set<int> unverifiedShipIds = const {},
  }) {
    final flat = PanelStyleScope.isFlat(context);
    final palette = AppPalette.of(context);
    final expColor = _experienceColor(context, active: active);
    final names = gameNames(context);
    final controller = widget.controller;
    final account = controller.accountScope;
    final percentFormat = NumberFormat.percentPattern(l10n.localeName)
      ..maximumFractionDigits = 1;
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
      final nameWidth =
          (width - padding.horizontal) *
          (showResourceSpending ? 0.27 : (compact ? 0.29 : 0.35));

      Widget columns(
        Widget name,
        Widget progress,
        Widget amount, [
        Widget? mvp,
      ]) => Row(
        children: [
          SizedBox(width: nameWidth.clamp(0.0, 164.0), child: name),
          gap,
          Expanded(
            flex: showResourceSpending ? 23 : (compact ? 36 : 30),
            child: progress,
          ),
          gap,
          Expanded(
            flex: showResourceSpending ? 50 : (compact ? 35 : 26),
            child: amount,
          ),
          if (mvp != null) ...[
            gap,
            SizedBox(width: compact ? 28 : 38, child: mvp),
          ],
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
        final mvp = sortieBattles == 0 ? 0 : ship.mvpCount;
        final name = names.shipName(
          ship.name.isNotEmpty
              ? ship.name
              : masterShips[ship.masterShipId]?.name ?? strings.unknownShip,
          shipId: ship.masterShipId,
        );
        final row = DecoratedBox(
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
              showResourceSpending
                  ? _WarehouseShipSpending(
                      strings: strings,
                      localizations: l10n,
                      format: format,
                      spending: controller.resourceSpendingFor(id),
                    )
                  : SortieExperienceAmount(
                      value: captured
                          ? '${ship.experience > 0 ? '+' : ''}${format.format(ship.experience)}'
                          : strings.uncaptured,
                      unit: !captured
                          ? null
                          : percentFormat.format(
                              experienceTotal == 0
                                  ? 0
                                  : ship.experience / experienceTotal,
                            ),
                      color: captured ? expColor : palette.muted,
                      valueKey: Key('sortie-exp-value-$id'),
                      unitKey: Key('sortie-exp-percentage-$id'),
                    ),
              showResourceSpending
                  ? null
                  : SortieExperienceAmount(
                      value: mvp == null ? '—' : format.format(mvp),
                      color: mvp == null || mvp == 0
                          ? palette.muted
                          : palette.accent,
                      valueKey: Key('sortie-exp-mvp-$id'),
                    ),
            ),
          ),
        );
        if (!showResourceSpending ||
            !controller.isReady ||
            controller.storageUnavailable) {
          return row;
        }
        return Material(
          type: MaterialType.transparency,
          child: Builder(
            builder: (rowContext) => InkWell(
              key: Key('sortie-exp-resource-open-$id'),
              onTap: () => _showResourceBill(
                rowContext,
                controller,
                account,
                strings,
                l10n,
                format,
                name,
                id,
              ),
              child: row,
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
                    heading(
                      showResourceSpending
                          ? strings.periodSpending
                          : l10n.expCalcAccumulatedExpLabel,
                      end: true,
                    ),
                    showResourceSpending
                        ? null
                        : Tooltip(
                            message: strings.mvpTooltip(
                              total: sortieBattles == null,
                            ),
                            child: heading('MVP', end: true),
                          ),
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

class _PaginatedTotalShips extends StatefulWidget {
  const _PaginatedTotalShips({
    super.key,
    required this.ships,
    required this.sortByResource,
    required this.allShipIds,
    required this.hiddenShipIds,
    required this.format,
    required this.tableBuilder,
  });

  final List<SortieExperienceShip> ships;
  final _ResourceKind? sortByResource;
  final Set<int> allShipIds;
  final Set<int> hiddenShipIds;
  final NumberFormat format;
  final Widget Function(List<SortieExperienceShip>) tableBuilder;

  @override
  State<_PaginatedTotalShips> createState() => _PaginatedTotalShipsState();
}

class _PaginatedTotalShipsState extends State<_PaginatedTotalShips> {
  static const _pageSize = 10;
  int _page = 0;

  int get _pageCount =>
      math.max(1, (widget.ships.length + _pageSize - 1) ~/ _pageSize);

  @override
  void didUpdateWidget(covariant _PaginatedTotalShips oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousSelection = oldWidget.hiddenShipIds.intersection(
      widget.allShipIds,
    );
    final currentSelection = widget.hiddenShipIds.intersection(
      widget.allShipIds,
    );
    _page =
        oldWidget.sortByResource == widget.sortByResource &&
            setEquals(previousSelection, currentSelection)
        ? math.min(_page, _pageCount - 1)
        : 0;
  }

  void _changePage(int direction) {
    if (!mounted) return;
    setState(() => _page = (_page + direction).clamp(0, _pageCount - 1));
  }

  @override
  Widget build(BuildContext context) {
    final start = _page * _pageSize;
    final end = math.min(start + _pageSize, widget.ships.length);
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.tableBuilder(widget.ships.sublist(start, end)),
        if (_pageCount > 1) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('sortie-exp-total-previous'),
                onPressed: _page > 0 ? () => _changePage(-1) : null,
                tooltip: localizations.previousPageTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                visualDensity: VisualDensity.standard,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.format.format(_page + 1)} / ${widget.format.format(_pageCount)}',
                    key: const Key('sortie-exp-total-page'),
                    semanticsLabel: localizations.pageRowsInfoTitle(
                      start + 1,
                      end,
                      widget.ships.length,
                      false,
                    ),
                    style: _secondaryStyle(context),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('sortie-exp-total-next'),
                onPressed: _page + 1 < _pageCount ? () => _changePage(1) : null,
                tooltip: localizations.nextPageTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                visualDensity: VisualDensity.standard,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
        ],
      ],
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

const _summaryValueFontSize = 12.0;

Text _summary(BuildContext context, String text) =>
    Text(text, style: _summaryValueStyle(context));

TextStyle _summaryValueStyle(BuildContext context) => appTextStyle(
  context,
  TextStyle(
    color: AppPalette.of(context).foreground,
    fontSize: _summaryValueFontSize,
    fontWeight: FontWeight.w700,
  ),
);

Text _secondary(BuildContext context, String text) =>
    Text(text, style: _secondaryStyle(context));

TextStyle _secondaryStyle(BuildContext context) => appTextStyle(
  context,
  TextStyle(color: AppPalette.of(context).muted, fontSize: 11),
);

Widget _summaryPanel(BuildContext context, List<Widget> children) {
  final palette = AppPalette.of(context);
  final flat = PanelStyleScope.isFlat(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      color: flat ? Colors.transparent : palette.inner,
      border: Border.all(color: palette.border),
      borderRadius: BorderRadius.circular(flat ? 0 : 7),
    ),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

Widget _summaryPair(Widget left, Widget right) => LayoutBuilder(
  builder: (context, constraints) {
    final scaledFontSize = MediaQuery.textScalerOf(
      context,
    ).scale(_summaryValueFontSize);
    final twoColumnWidth = 240 * scaledFontSize / _summaryValueFontSize;
    return constraints.maxWidth < twoColumnWidth
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 6), right],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 10),
              Expanded(child: right),
            ],
          );
  },
);

Widget _summaryMetric(BuildContext context, String label, Widget value) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_secondary(context, label), const SizedBox(height: 2), value],
    );

Color _experienceColor(BuildContext context, {required bool active}) {
  final palette = AppPalette.of(context);
  if (palette.isDark) return Color(active ? 0xfff7cf75 : 0xff8adac7);
  return active ? palette.warning : palette.success;
}

Widget _experienceAmount(
  BuildContext context,
  String text, {
  required Key key,
  bool active = false,
}) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: AlignmentDirectional.centerStart,
  child: Text(
    text,
    key: key,
    maxLines: 1,
    style: _summaryValueStyle(context).copyWith(
      color: _experienceColor(context, active: active),
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  ),
);

Widget _sortieStatus(
  BuildContext context,
  String label, {
  required bool active,
}) {
  final palette = AppPalette.of(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: active ? palette.warning.withValues(alpha: 0.14) : palette.raised,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Text(
        label,
        style: appTextStyle(
          context,
          TextStyle(
            color: active
                ? _experienceColor(context, active: true)
                : palette.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
