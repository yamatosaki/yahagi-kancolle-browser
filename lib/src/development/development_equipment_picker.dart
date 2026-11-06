import '../theme/app_palette.dart';
import '../widgets/app_segmented_style.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/equipment_type_icon.dart';
import '../localization/game_name_localizations.dart';
import 'development_dataset.dart';
import 'development_name_labels.dart';
import 'equipment_development_controller.dart';

Future<void> showDevelopmentEquipmentPicker(
  BuildContext context,
  EquipmentDevelopmentController controller,
) => showDialog<void>(
  barrierDismissible: false,
  context: context,
  builder: (dialogContext) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) =>
        _DevelopmentEquipmentPicker(controller: controller),
  ),
);

class _EquipmentTypeGroup {
  const _EquipmentTypeGroup(this.key, this.typeIds);

  final String key;
  final List<int> typeIds;
}

class _DevelopmentEquipmentPicker extends StatefulWidget {
  const _DevelopmentEquipmentPicker({required this.controller});

  final EquipmentDevelopmentController controller;

  @override
  State<_DevelopmentEquipmentPicker> createState() =>
      _DevelopmentEquipmentPickerState();
}

class _DevelopmentEquipmentPickerState
    extends State<_DevelopmentEquipmentPicker> {
  late String selectedGroupKey = _initialGroupKey();

  EquipmentDevelopmentController get controller => widget.controller;

  List<int> get typeIds {
    final values =
        controller.dataset?.equipment.values
            .map((item) => item.typeId)
            .toSet()
            .toList() ??
        <int>[];
    values.sort();
    return values;
  }

  List<_EquipmentTypeGroup> get typeGroups {
    final known = <_EquipmentTypeGroup>[];
    final unknown = <int>[];
    for (final typeId in typeIds) {
      if (controller.equipmentTypeName(typeId) == '—') {
        unknown.add(typeId);
      } else {
        known.add(_EquipmentTypeGroup('$typeId', [typeId]));
      }
    }
    if (unknown.isNotEmpty) {
      known.add(_EquipmentTypeGroup('other', unknown));
    }
    return known;
  }

  String _initialGroupKey() {
    final groups = typeGroups;
    final current = controller.equipmentTypeFilter;
    if (current != null) {
      for (final group in groups) {
        if (group.typeIds.contains(current)) return group.key;
      }
    }
    for (final id in controller.targets) {
      final typeId = controller.dataset?.equipment[id]?.typeId;
      for (final group in groups) {
        if (typeId != null && group.typeIds.contains(typeId)) return group.key;
      }
    }
    return groups.isEmpty ? '' : groups.first.key;
  }

  String _typeLabel(AppLocalizations l10n, _EquipmentTypeGroup group) =>
      group.key == 'other'
      ? l10n.developmentOtherSecretaryGroup
      : gameNames(context).equipmentTypeName(
          controller.equipmentTypeName(group.typeIds.single),
          typeId: group.typeIds.single,
        );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(720.0, math.max(300.0, screen.width - 32));
    final height = math.min(620.0, math.max(380.0, screen.height * 0.78));
    final leftWidth = (width * 0.3).clamp(112.0, 190.0);
    final groups = typeGroups;
    if (groups.isNotEmpty &&
        !groups.any((group) => group.key == selectedGroupKey)) {
      selectedGroupKey = groups.first.key;
    }
    _EquipmentTypeGroup? selectedGroup;
    for (final group in groups) {
      if (group.key == selectedGroupKey) {
        selectedGroup = group;
        break;
      }
    }
    final equipment = selectedGroup == null
        ? const <DevelopmentEquipmentRecord>[]
        : controller.filteredEquipmentForTypes(
            selectedGroup.typeIds.toSet(),
            equipmentNameResolver: gameNames(context).equipmentName,
          );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: appColor(context, Colors.transparent),
      child: Container(
        key: const Key('development-target-dialog'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: appColor(context, Color(0xff101d27)),
          border: Border.all(color: appColor(context, Color(0xff385064))),
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
          children: [
            _DialogHeader(controller: controller),
            Divider(height: 1, color: appColor(context, Color(0xff385064))),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: ColoredBox(
                      color: appColor(context, const Color(0xff0b1720)),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final selected = group.key == selectedGroupKey;
                          return Material(
                            color: AppSegmentedStyle.selection(
                              context,
                              selected,
                            ),
                            child: InkWell(
                              key: Key(
                                'development-equipment-type-${group.key}',
                              ),
                              onTap: () =>
                                  setState(() => selectedGroupKey = group.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                child: Text(
                                  _typeLabel(l10n, group),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: appTextStyle(
                                    context,
                                    TextStyle(
                                      color: selected
                                          ? AppSegmentedStyle.foreground(
                                              context,
                                              true,
                                            )
                                          : null,
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: appColor(context, Color(0xff385064)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.equipmentSearch.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: InputChip(
                              label: Text(controller.equipmentSearch),
                              avatar: const Icon(Icons.search, size: 16),
                              onDeleted: () =>
                                  controller.setEquipmentSearch(''),
                            ),
                          ),
                        Expanded(
                          child: equipment.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.developmentNoResults,
                                    style: appTextStyle(
                                      context,
                                      TextStyle(
                                        color: appColor(
                                          context,
                                          Color(0xff91a9b5),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(10),
                                  itemCount: equipment.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 5),
                                  itemBuilder: (context, index) =>
                                      _EquipmentOption(
                                        controller: controller,
                                        equipment: equipment[index],
                                      ),
                                ),
                        ),
                      ],
                    ),
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.controller});

  final EquipmentDevelopmentController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.category_outlined,
            size: 20,
            color: appColor(context, Color(0xffd4a85f)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.developmentChooseTarget,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.developmentSelectedCount(controller.targets.length),
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xff89a5b3)),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            key: const Key('development-search-button'),
            tooltip: l10n.developmentSearchEquipment,
            onPressed: () => _showSearchDialog(context, controller),
            icon: const Icon(Icons.search, size: 20),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('development-target-close'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _EquipmentOption extends StatelessWidget {
  const _EquipmentOption({required this.controller, required this.equipment});

  final EquipmentDevelopmentController controller;
  final DevelopmentEquipmentRecord equipment;

  @override
  Widget build(BuildContext context) {
    final selected = controller.targets.contains(equipment.id);
    final enabled =
        selected || controller.enabledEquipment.contains(equipment.id);
    return Material(
      color: appColor(
        context,
        selected ? const Color(0xff1d5f91) : const Color(0xff172a38),
      ),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        key: Key('development-equipment-${equipment.id}'),
        borderRadius: BorderRadius.circular(7),
        onTap: enabled ? () => controller.toggleTarget(equipment.id) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              EquipmentTypeIconImage(
                iconId: equipment.iconId,
                width: 23,
                height: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  developmentEquipmentLabel(context, equipment),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: enabled
                          ? const Color(0xffedf4f6)
                          : const Color(0xff647986),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline,
                size: 19,
                color: appColor(
                  context,
                  selected
                      ? const Color(0xff68b7ef)
                      : enabled
                      ? const Color(0xff7594a4)
                      : const Color(0xff455966),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showSearchDialog(
  BuildContext context,
  EquipmentDevelopmentController controller,
) async {
  final value = await showDialog<String>(
    barrierDismissible: false,
    context: context,
    builder: (context) =>
        _DevelopmentSearchDialog(initialValue: controller.equipmentSearch),
  );
  if (value != null) controller.setEquipmentSearch(value.trim());
}

class _DevelopmentSearchDialog extends StatefulWidget {
  const _DevelopmentSearchDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_DevelopmentSearchDialog> createState() =>
      _DevelopmentSearchDialogState();
}

class _DevelopmentSearchDialogState extends State<_DevelopmentSearchDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('development-search-dialog'),
      title: Text(l10n.developmentSearchEquipment),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.developmentSearchHint,
          prefixIcon: const Icon(Icons.search),
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
