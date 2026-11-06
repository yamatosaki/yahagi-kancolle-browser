import '../theme/app_palette.dart';
import '../widgets/app_segmented_style.dart';
import 'package:flutter/material.dart';
import '../localization/game_name_localizations.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_display.dart';
import '../fleet/equipment_type_icon.dart';
import '../fleet/fleet_ui_strings.dart';
import '../fleet/ship_portrait.dart';
import '../game_state/game_state.dart';
import '../widgets/standalone_text_input_dialog.dart';
import 'equipment_compatibility_projection.dart';
import 'owned_inventory_projection.dart';

class EquipmentCompatibilityDrawer extends StatefulWidget {
  const EquipmentCompatibilityDrawer({
    super.key,
    required this.state,
    required this.equipment,
    required this.onClose,
  });

  final GameState state;
  final MasterSlotItem equipment;
  final VoidCallback onClose;

  @override
  State<EquipmentCompatibilityDrawer> createState() =>
      _EquipmentCompatibilityDrawerState();
}

class _EquipmentCompatibilityDrawerState
    extends State<EquipmentCompatibilityDrawer> {
  bool _ownedOnly = true;
  ShipInventoryCategory _shipCategory = ShipInventoryCategory.all;
  String _query = '';
  EquipmentCompatibilitySlotFilter _slotFilter =
      EquipmentCompatibilitySlotFilter.all;
  late EquipmentCompatibilityProjection _projection;

  @override
  void initState() {
    super.initState();
    _projection = EquipmentCompatibilityProjection(widget.state);
  }

  @override
  void didUpdateWidget(covariant EquipmentCompatibilityDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      _projection = EquipmentCompatibilityProjection(widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final rows = _projection.rows(
      equipmentMasterId: widget.equipment.id,
      ownedOnly: _ownedOnly,
      shipCategory: _shipCategory,
      query: _query,
      nameWithIdResolver: (name, id) =>
          gameNames(context).shipName(name, shipId: id),
      filter: _slotFilter,
    );
    final allRows = _projection.rows(equipmentMasterId: widget.equipment.id);
    final ownedRows = _projection.rows(
      equipmentMasterId: widget.equipment.id,
      ownedOnly: true,
    );
    final allCount = allRows.length;
    final ownedCount = ownedRows.length;
    final iconId = widget.equipment.type.length > 3
        ? widget.equipment.type[3]
        : -1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 438.0);
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
          },
          child: Focus(
            autofocus: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1, end: 0),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, offset, child) => Transform.translate(
                  offset: Offset(width * offset, 0),
                  child: child,
                ),
                child: SizedBox(
                  key: const Key('equipment-compatibility-drawer'),
                  width: width,
                  height: constraints.maxHeight,
                  child: Material(
                    color: appColor(context, const Color(0xff0d2330)),
                    elevation: 18,
                    shadowColor: appColor(context, Colors.black87),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: appColor(context, Color(0xff38586b)),
                          ),
                        ),
                      ),
                      child: CustomScrollView(
                        key: const Key('equipment-compatibility-scroll'),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _Header(
                              equipment: widget.equipment,
                              iconId: iconId,
                              onClose: widget.onClose,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _EquipmentStats(equipment: widget.equipment),
                          ),
                          if (widget.state.hasEquipmentCompatibilityData)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  6,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        _ToolButton(
                                          key: const Key(
                                            'equipment-compatibility-ship-type-button',
                                          ),
                                          visualKey: const Key(
                                            'equipment-compatibility-ship-type-button-visual',
                                          ),
                                          icon: Icons.filter_alt_rounded,
                                          tooltip: l10n.shipType,
                                          active:
                                              _shipCategory !=
                                              ShipInventoryCategory.all,
                                          onPressed: _showShipTypeDialog,
                                        ),
                                        const SizedBox(width: 4),
                                        _ToolButton(
                                          key: const Key(
                                            'equipment-compatibility-search-button',
                                          ),
                                          visualKey: const Key(
                                            'equipment-compatibility-search-button-visual',
                                          ),
                                          icon: Icons.search_rounded,
                                          tooltip: l10n
                                              .equipmentCompatibilitySearchHint,
                                          active: _query.isNotEmpty,
                                          onPressed: _showSearchDialog,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ScopeTabs(
                                            ownedOnly: _ownedOnly,
                                            ownedCount: ownedCount,
                                            allCount: allCount,
                                            onChanged: (value) => setState(
                                              () => _ownedOnly = value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    _SlotFilters(
                                      selected: _slotFilter,
                                      onChanged: (value) =>
                                          setState(() => _slotFilter = value),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!widget.state.hasEquipmentCompatibilityData)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _RulesWaiting(),
                            )
                          else if (rows.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyResult(ownedOnly: _ownedOnly),
                            )
                          else
                            _CompatibilityList(state: widget.state, rows: rows),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShipTypeDialog() async {
    final selected = await showDialog<ShipInventoryCategory>(
      barrierDismissible: false,
      context: context,
      builder: (context) => _ShipTypeDialog(selectedCategory: _shipCategory),
    );
    if (selected == null || !mounted) return;
    setState(() => _shipCategory = selected);
  }

  Future<void> _showSearchDialog() async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final value = await showDialog<String>(
      barrierDismissible: false,
      context: context,
      builder: (context) => StandaloneTextInputDialog(
        key: const Key('equipment-compatibility-search-dialog'),
        title: l10n.equipmentCompatibilitySearchHint,
        label: l10n.equipmentCompatibilitySearchHint,
        initialValue: _query,
        fieldKey: const Key('equipment-compatibility-search-dialog-field'),
        cancelKey: const Key('equipment-compatibility-search-dialog-cancel'),
        confirmKey: const Key('equipment-compatibility-search-dialog-confirm'),
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _query = value.trim());
  }
}

class _EquipmentStats extends StatelessWidget {
  const _EquipmentStats({required this.equipment});

  final MasterSlotItem equipment;

  @override
  Widget build(BuildContext context) {
    final stats = equipmentStatDisplays(equipment);
    if (stats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Column(
        children: [
          for (var start = 0; start < stats.length; start += 4)
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < 4; column++)
                    Expanded(
                      child: start + column >= stats.length
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: EdgeInsets.only(
                                right: column == 3 ? 0 : 6,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: appColor(context, Color(0xff173546)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              '${fleetText(context, stats[start + column].label)} ',
                                          style: appTextStyle(
                                            context,
                                            TextStyle(
                                              color: appColor(
                                                context,
                                                Colors.white,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        TextSpan(
                                          text: fleetText(
                                            context,
                                            stats[start + column].value,
                                          ),
                                          style: appTextStyle(
                                            context,
                                            TextStyle(
                                              color: appColor(
                                                context,
                                                Color(0xff70d5cd),
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.equipment,
    required this.iconId,
    required this.onClose,
  });

  final MasterSlotItem equipment;
  final int iconId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: appColor(context, Color(0xff173546)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: EquipmentTypeIconImage(
                iconId: iconId,
                width: 30,
                height: 30,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              gameNames(context).equipmentName(equipment.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(
                context,
                TextStyle(
                  color: appColor(context, Color(0xfff2f7f9)),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('equipment-compatibility-close'),
            tooltip: l10n.close,
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: appColor(context, Color(0xffc7d5dc)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.visualKey,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final Key visualKey;
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    isSelected: active,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    style: IconButton.styleFrom(
      foregroundColor: appColor(
        context,
        active ? const Color(0xfff2f7f9) : const Color(0xff9bb0bb),
      ),
    ),
    onPressed: onPressed,
    icon: Container(
      key: visualKey,
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: appColor(
          context,
          active ? const Color(0xff2b7180) : const Color(0xff102a38),
        ),
        border: Border.all(
          color: appColor(
            context,
            active ? const Color(0xff69d2cf) : const Color(0xff315064),
          ),
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19),
    ),
  );
}

class _ShipTypeDialog extends StatelessWidget {
  const _ShipTypeDialog({required this.selectedCategory});

  final ShipInventoryCategory selectedCategory;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: appColor(context, Colors.transparent),
      child: Container(
        key: const Key('equipment-compatibility-ship-type-dialog'),
        width: 480,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: appColor(context, Color(0xff101d27)),
          border: Border.all(color: appColor(context, const Color(0xff385064))),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: appColor(context, Colors.black54),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.filter_alt_rounded,
                    size: 20,
                    color: appColor(context, Color(0xff69d2cf)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.equipmentCompatibilitySelectShipType,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xfff2f7f9)),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: appColor(context, Color(0xffc7d5dc)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Divider(height: 1, color: appColor(context, Color(0xff385064))),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in ShipInventoryCategory.values)
                        FilterChip(
                          key: Key(
                            'equipment-compatibility-ship-category-${category.name}',
                          ),
                          label: Text(_shipCategoryLabel(category, l10n)),
                          selected: selectedCategory == category,
                          onSelected: (_) =>
                              Navigator.of(context).pop(category),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shipCategoryLabel(
  ShipInventoryCategory category,
  AppLocalizations l10n,
) => switch (category) {
  ShipInventoryCategory.all => l10n.all,
  ShipInventoryCategory.bbBc => 'BB/BC',
  ShipInventoryCategory.cv => 'CV',
  ShipInventoryCategory.cvl => 'CVL',
  ShipInventoryCategory.ca => 'CA',
  ShipInventoryCategory.cl => 'CL',
  ShipInventoryCategory.dd => 'DD',
  ShipInventoryCategory.de => 'DE',
  ShipInventoryCategory.ss => 'SS',
  ShipInventoryCategory.support => 'AV/AO/AS…',
};

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.ownedOnly,
    required this.ownedCount,
    required this.allCount,
    required this.onChanged,
  });

  final bool ownedOnly;
  final int ownedCount;
  final int allCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      key: const Key('equipment-compatibility-scope-tabs'),
      height: 32,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          Expanded(
            child: _ScopeTab(
              key: const Key('equipment-compatibility-tab-owned'),
              selected: ownedOnly,
              label: l10n.equipmentCompatibilityOwnedCompact(ownedCount),
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ScopeTab(
              key: const Key('equipment-compatibility-tab-all'),
              selected: !ownedOnly,
              label: l10n.equipmentCompatibilityAllCompact(allCount),
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: Material(
      color: AppSegmentedStyle.selection(context, selected),
      borderRadius: AppSegmentedStyle.itemRadius(),
      child: InkWell(
        borderRadius: AppSegmentedStyle.itemRadius(),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: AppSegmentedStyle.textStyle(context, selected: selected),
          ),
        ),
      ),
    ),
  );
}

class _SlotFilters extends StatelessWidget {
  const _SlotFilters({required this.selected, required this.onChanged});

  final EquipmentCompatibilitySlotFilter selected;
  final ValueChanged<EquipmentCompatibilitySlotFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      key: const Key('equipment-compatibility-slot-tabs'),
      height: 32,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          for (final value in EquipmentCompatibilitySlotFilter.values)
            Expanded(
              child: _ScopeTab(
                key: Key('equipment-compatibility-filter-${value.name}'),
                selected: selected == value,
                label: switch (value) {
                  EquipmentCompatibilitySlotFilter.all =>
                    l10n.equipmentCompatibilityAllSlots,
                  EquipmentCompatibilitySlotFilter.regular =>
                    l10n.equipmentCompatibilityRegularSlot,
                  EquipmentCompatibilitySlotFilter.expansion =>
                    l10n.equipmentCompatibilityExpansionSlot,
                },
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompatibilityList extends StatelessWidget {
  const _CompatibilityList({required this.state, required this.rows});

  final GameState state;
  final List<EquipmentCompatibilityShipRow> rows;

  @override
  Widget build(BuildContext context) {
    final items = <({String? typeName, EquipmentCompatibilityShipRow? row})>[];
    int? previousTypeId;
    for (final row in rows) {
      if (row.shipMaster.shipTypeId != previousTypeId) {
        previousTypeId = row.shipMaster.shipTypeId;
        items.add((typeName: row.shipTypeName, row: null));
      }
      items.add((typeName: null, row: row));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      sliver: SliverList(
        key: const Key('equipment-compatibility-results'),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          final row = item.row;
          return row == null
              ? _TypeHeader(name: item.typeName!)
              : _ShipRow(state: state, row: row);
        }, childCount: items.length),
      ),
    );
  }
}

class _TypeHeader extends StatelessWidget {
  const _TypeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        name.isEmpty ? l10n.otherType : gameNames(context).shipTypeName(name),
        style: appTextStyle(
          context,
          TextStyle(
            color: appColor(context, Color(0xff69d2cf)),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ShipRow extends StatelessWidget {
  const _ShipRow({required this.state, required this.row});

  final GameState state;
  final EquipmentCompatibilityShipRow row;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final compatibility = row.compatibility;
    final slotLabel =
        compatibility.canEquipInRegularSlot &&
            compatibility.canEquipInExpansionSlot
        ? l10n.equipmentCompatibilityBothSlots
        : compatibility.canEquipInRegularSlot
        ? l10n.equipmentCompatibilityRegularSlot
        : l10n.equipmentCompatibilityExpansionSlot;
    final shipTypeLabel = row.shipTypeName.isEmpty
        ? l10n.otherType
        : gameNames(
            context,
          ).shipTypeName(row.shipTypeName, typeId: row.shipMaster.shipTypeId);
    final metadata = row.ownedShips.isEmpty
        ? shipTypeLabel
        : '$shipTypeLabel · ${l10n.equipmentCompatibilityOwnedLevels(row.ownedShips.map((ship) => ship.level).join(' / '))}';
    final fleetText = row.fleetNumbers.isEmpty
        ? null
        : l10n.equipmentCompatibilityFleetNumbers(row.fleetNumbers.join('、'));

    return Container(
      key: Key('equipment-compatibility-ship-${row.shipMaster.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff102a38)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: appColor(context, Color(0xff294052))),
      ),
      child: Row(
        children: [
          ShipPortrait(
            ship: row.shipMaster,
            serverOrigin: state.serverOrigin,
            width: 51.8,
            height: 33.6,
            decodeHeight: (35 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameNames(
                    context,
                  ).shipName(row.shipMaster.name, shipId: row.shipMaster.id),
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xffe8f0f4)),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metadata,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xff78909c)),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (fleetText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    fleetText,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff9bb0bb)),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                slotLabel,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xff72d8ae)),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (compatibility.expansionSlotMinimumImprovement > 0) ...[
                const SizedBox(height: 3),
                Text(
                  l10n.equipmentCompatibilityExpansionRequirement(
                    compatibility.expansionSlotMinimumImprovement,
                  ),
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xffffc85a)),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.ownedOnly});

  final bool ownedOnly;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          ownedOnly
              ? l10n.equipmentCompatibilityEmptyOwned
              : l10n.equipmentCompatibilityEmptyAll,
          textAlign: TextAlign.center,
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xff8ba2af)),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _RulesWaiting extends StatelessWidget {
  const _RulesWaiting();

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.equipmentCompatibilityRulesWaiting,
          textAlign: TextAlign.center,
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xff8ba2af)),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
