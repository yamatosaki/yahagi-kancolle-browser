import '../theme/app_palette.dart';
import '../widgets/app_segmented_style.dart';
import 'package:flutter/material.dart';
import '../localization/game_name_localizations.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_type_icon.dart';
import '../fleet/ship_portrait.dart';
import '../game_state/game_state.dart';
import '../widgets/standalone_text_input_dialog.dart';
import 'equipment_compatibility_projection.dart';
import 'owned_inventory_projection.dart';
import 'ship_equipment_compatibility_projection.dart';

class ShipEquipmentCompatibilityDrawer extends StatefulWidget {
  const ShipEquipmentCompatibilityDrawer({
    super.key,
    required this.state,
    required this.ship,
    required this.ownedShip,
    required this.onClose,
  });

  final GameState state;
  final MasterShip ship;
  final OwnedShip? ownedShip;
  final VoidCallback onClose;

  @override
  State<ShipEquipmentCompatibilityDrawer> createState() =>
      _ShipEquipmentCompatibilityDrawerState();
}

class _ShipEquipmentCompatibilityDrawerState
    extends State<ShipEquipmentCompatibilityDrawer> {
  bool _ownedOnly = true;
  EquipmentInventoryCategory _category = EquipmentInventoryCategory.all;
  String _query = '';
  EquipmentCompatibilitySlotFilter _slotFilter =
      EquipmentCompatibilitySlotFilter.all;
  late ShipEquipmentCompatibilityProjection _projection;

  @override
  void initState() {
    super.initState();
    _projection = ShipEquipmentCompatibilityProjection(widget.state);
  }

  @override
  void didUpdateWidget(covariant ShipEquipmentCompatibilityDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state) ||
        !identical(oldWidget.ship, widget.ship)) {
      _projection = ShipEquipmentCompatibilityProjection(widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final groups = _projection.groups(
      shipMasterId: widget.ship.id,
      ownedOnly: _ownedOnly,
      category: _category,
      query: _query,
      nameResolver: gameNames(context).equipmentName,
      filter: _slotFilter,
    );
    final ownedCount = _projection
        .groups(shipMasterId: widget.ship.id, ownedOnly: true)
        .fold<int>(0, (count, group) => count + group.rows.length);
    final allCount = _projection
        .groups(shipMasterId: widget.ship.id)
        .fold<int>(0, (count, group) => count + group.rows.length);

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
                  key: const Key('ship-equipment-compatibility-drawer'),
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
                        key: const Key('ship-equipment-compatibility-scroll'),
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: _Header(
                              state: widget.state,
                              ship: widget.ship,
                              ownedShip: widget.ownedShip,
                              onClose: widget.onClose,
                            ),
                          ),
                          if (widget.state.hasEquipmentCompatibilityData)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  2,
                                  14,
                                  10,
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        _ToolButton(
                                          key: const Key(
                                            'ship-equipment-compatibility-category-button',
                                          ),
                                          icon: Icons.filter_alt_rounded,
                                          tooltip: l10n
                                              .shipEquipmentCompatibilitySelectCategory,
                                          active:
                                              _category !=
                                              EquipmentInventoryCategory.all,
                                          onPressed: _showCategoryDialog,
                                        ),
                                        const SizedBox(width: 4),
                                        _ToolButton(
                                          key: const Key(
                                            'ship-equipment-compatibility-search-button',
                                          ),
                                          icon: Icons.search_rounded,
                                          tooltip: l10n
                                              .shipEquipmentCompatibilitySearchTitle,
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
                                    const SizedBox(height: 8),
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
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _Message(
                                text: l10n.equipmentCompatibilityRulesWaiting,
                              ),
                            )
                          else if (groups.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _Message(
                                text: l10n.shipEquipmentCompatibilityEmpty,
                              ),
                            )
                          else
                            _EquipmentList(groups: groups),
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

  Future<void> _showCategoryDialog() async {
    final selected = await showDialog<EquipmentInventoryCategory>(
      barrierDismissible: false,
      context: context,
      builder: (context) => _CategoryDialog(selected: _category),
    );
    if (selected == null || !mounted) return;
    setState(() => _category = selected);
  }

  Future<void> _showSearchDialog() async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final value = await showDialog<String>(
      barrierDismissible: false,
      context: context,
      builder: (context) => StandaloneTextInputDialog(
        key: const Key('ship-equipment-compatibility-search-dialog'),
        title: l10n.shipEquipmentCompatibilitySearchTitle,
        label: l10n.shipEquipmentCompatibilitySearchHint,
        initialValue: _query,
        fieldKey: const Key('ship-equipment-compatibility-search-dialog-field'),
        cancelKey: const Key(
          'ship-equipment-compatibility-search-dialog-cancel',
        ),
        confirmKey: const Key(
          'ship-equipment-compatibility-search-dialog-confirm',
        ),
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _query = value.trim());
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.ship,
    required this.ownedShip,
    required this.onClose,
  });

  final GameState state;
  final MasterShip ship;
  final OwnedShip? ownedShip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final typeName = gameNames(context).shipTypeName(
      state.masterShipTypes[ship.shipTypeId]?.name ?? l10n.otherType,
      typeId: ship.shipTypeId,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(
        children: <Widget>[
          ShipPortrait(
            ship: ship,
            serverOrigin: state.serverOrigin,
            width: 74,
            height: 48,
            decodeHeight: (50 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  gameNames(context).shipName(ship.name, shipId: ship.id),
                  maxLines: 1,
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
                const SizedBox(height: 3),
                Text(
                  ownedShip == null
                      ? typeName
                      : '$typeName  Lv.${ownedShip!.level}',
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xff9bb0bb)),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('ship-equipment-compatibility-close'),
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
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

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

class _CategoryDialog extends StatelessWidget {
  const _CategoryDialog({required this.selected});

  final EquipmentInventoryCategory selected;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: appColor(context, Colors.transparent),
      child: Container(
        key: const Key('ship-equipment-compatibility-category-dialog'),
        width: 520,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: appColor(context, Color(0xff101d27)),
          border: Border.all(color: appColor(context, const Color(0xff385064))),
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
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
          children: <Widget>[
            SizedBox(
              height: 52,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.filter_alt_rounded,
                    size: 20,
                    color: appColor(context, Color(0xff69d2cf)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.shipEquipmentCompatibilitySelectCategory,
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
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final category in EquipmentInventoryCategory.values)
                        FilterChip(
                          key: Key(
                            'ship-equipment-compatibility-category-${category.name}',
                          ),
                          label: Text(_categoryLabel(category, l10n)),
                          selected: selected == category,
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

String _categoryLabel(
  EquipmentInventoryCategory value,
  AppLocalizations l10n,
) => switch (value) {
  EquipmentInventoryCategory.all => l10n.all,
  EquipmentInventoryCategory.mainGun => l10n.equipmentMainGun,
  EquipmentInventoryCategory.secondaryGun => l10n.equipmentSecondaryGun,
  EquipmentInventoryCategory.machineGun => l10n.equipmentMachineGun,
  EquipmentInventoryCategory.torpedo => l10n.equipmentTorpedo,
  EquipmentInventoryCategory.carrierAircraft => l10n.equipmentCarrierAircraft,
  EquipmentInventoryCategory.seaplane => l10n.equipmentSeaplane,
  EquipmentInventoryCategory.landBasedAircraft =>
    l10n.equipmentLandBasedAircraft,
  EquipmentInventoryCategory.antiSubmarine => l10n.antiSub,
  EquipmentInventoryCategory.radar => l10n.equipmentRadar,
  EquipmentInventoryCategory.landingTransport => l10n.equipmentLandingTransport,
  EquipmentInventoryCategory.support => l10n.equipmentSupport,
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
      key: const Key('ship-equipment-compatibility-scope-tabs'),
      height: 32,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ScopeTab(
              key: const Key('ship-equipment-compatibility-tab-owned'),
              selected: ownedOnly,
              label: l10n.equipmentCompatibilityOwnedCompact(ownedCount),
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ScopeTab(
              key: const Key('ship-equipment-compatibility-tab-all'),
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final value in EquipmentCompatibilitySlotFilter.values)
          _FilterChip(
            key: Key('ship-equipment-compatibility-filter-${value.name}'),
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
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      color: selected
          ? AppSegmentedStyle.selectedBackground(context)
          : appColor(context, const Color(0xff102a38)),
      borderRadius: AppSegmentedStyle.itemRadius(compact: true),
      child: InkWell(
        borderRadius: AppSegmentedStyle.itemRadius(compact: true),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: appTextStyle(
              context,
              TextStyle(
                color: selected
                    ? AppSegmentedStyle.foreground(context, true)
                    : const Color(0xff9bb0bb),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EquipmentList extends StatelessWidget {
  const _EquipmentList({required this.groups});
  final List<ShipEquipmentCompatibilityGroup> groups;

  @override
  Widget build(BuildContext context) {
    final items = <Object>[];
    for (final group in groups) {
      items
        ..add(group)
        ..addAll(group.rows);
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      sliver: SliverList(
        key: const Key('ship-equipment-compatibility-results'),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return item is ShipEquipmentCompatibilityGroup
              ? _GroupHeader(group: item)
              : _EquipmentRow(row: item as ShipEquipmentCompatibilityRow);
        }, childCount: items.length),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final ShipEquipmentCompatibilityGroup group;

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('ship-equipment-compatibility-group-${group.typeId}'),
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
    child: Text(
      gameNames(
        context,
      ).equipmentTypeName(group.typeName, typeId: group.typeId),
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

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.row});
  final ShipEquipmentCompatibilityRow row;

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
    final iconId = row.master.type.length > 3 ? row.master.type[3] : -1;
    return Container(
      key: Key('ship-equipment-compatibility-equipment-${row.master.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff102a38)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: appColor(context, Color(0xff294052))),
      ),
      child: Row(
        children: <Widget>[
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  gameNames(context).equipmentName(row.master.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                if (compatibility.expansionSlotMinimumImprovement >
                    0) ...<Widget>[
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
          ),
          if (row.ownedCount > 0) ...<Widget>[
            const SizedBox(width: 6),
            SizedBox(
              width: 62,
              child: Align(
                key: Key(
                  'ship-equipment-compatibility-owned-count-${row.master.id}',
                ),
                alignment: Alignment.centerRight,
                child: Text(
                  l10n.shipEquipmentCompatibilityOwnedCount(row.ownedCount),
                  textAlign: TextAlign.right,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xfff2c96d)),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appTextStyle(
          context,
          TextStyle(color: appColor(context, Color(0xff8ba2af)), fontSize: 12),
        ),
      ),
    ),
  );
}
