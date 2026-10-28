import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../fleet/fleet_ui_strings.dart';
import '../layout/flat_empty_text.dart';
import '../layout/flat_style.dart';
import '../layout/panel_style.dart';
import 'fleet_display_options.dart';
import 'layout_settings_controller.dart';
import 'game_display_settings_dialog.dart';

FleetSelectorLabelMode _repairFleetSelectorLabelMode =
    FleetSelectorLabelMode.customName;

FleetSelectorLabelMode get repairFleetSelectorLabelModeSetting =>
    _repairFleetSelectorLabelMode;

void setRepairFleetSelectorLabelModeSetting(FleetSelectorLabelMode mode) {
  _repairFleetSelectorLabelMode = mode;
}

const moduleDisplayOptions = FleetUiKeys.moduleDisplayOptions;
const moduleDisplayTitles = FleetUiKeys.moduleDisplayTitles;

abstract class ModuleDisplaySettingsStore {
  Future<List<String>?> loadModuleDisplayFields(String module);
  Future<void> saveModuleDisplayFields(String module, List<String> fields);
  Future<bool> loadModuleShowLogo(String module) async => true;
  Future<void> saveModuleShowLogo(String module, bool show) async {}
  Future<bool> loadModuleShowName(String module) async => true;
  Future<void> saveModuleShowName(String module, bool show) async {}
  Future<FleetSelectorLabelMode> loadRepairFleetSelectorLabelMode() async =>
      FleetSelectorLabelMode.customName;
  Future<void> saveRepairFleetSelectorLabelMode(
    FleetSelectorLabelMode mode,
  ) async {}
}

Widget? moduleDisplayGear(
  BuildContext context,
  String module,
  VoidCallback? onPressed,
) => onPressed == null
    ? null
    : displaySettingsGear(
        context,
        key: Key('$module-display-settings-button'),
        tooltip: fleetText(
          context,
          moduleDisplayTitles[module] ?? FleetUiKeys.displayContent,
        ),
        onPressed: onPressed,
      );

// 扁平标题行只有 24 高，M3 默认把点击区撑到 48，会被标题行连图标一起缩成一半。
Widget displaySettingsGear(
  BuildContext context, {
  required Key key,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  final flat = PanelStyleScope.isFlat(context);
  return IconButton(
    key: key,
    tooltip: tooltip,
    constraints: flat
        ? const BoxConstraints.tightFor(
            width: flatHeaderHeight,
            height: flatHeaderHeight,
          )
        : const BoxConstraints(minWidth: 36, minHeight: 36),
    style: flat
        ? const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap)
        : null,
    padding: EdgeInsets.zero,
    icon: Icon(
      Icons.settings_outlined,
      size: flat ? flatActionIconSize : 19,
      color: appColor(context, const Color(0xffd4a85f)),
    ),
    onPressed: onPressed,
  );
}

Future<void> showModuleDisplaySettings(
  BuildContext context,
  LayoutSettingsController controller,
  String module,
) {
  final options = moduleDisplayOptions[module] ?? const <String, String>{};
  String text(String key) => fleetText(context, key);
  Future<void> reset() async {
    await Future.wait([
      controller.setModuleShowLogo(module, true),
      controller.setModuleShowName(module, true),
      if (options.isNotEmpty)
        controller.setModuleDisplayFields(module, options.keys),
      if (module == 'repair')
        controller.setRepairFleetSelectorLabelMode(
          FleetSelectorLabelMode.customName,
        ),
    ]);
  }

  Future<void> toggle(String id) {
    if (id == 'appearance-logo') {
      return controller.setModuleShowLogo(
        module,
        !controller.moduleShowLogo(module),
      );
    }
    if (id == 'appearance-name') {
      return controller.setModuleShowName(
        module,
        !controller.moduleShowName(module),
      );
    }
    if (id.startsWith('field-')) {
      final field = id.substring(6);
      if (options.containsKey(field)) {
        final next = controller.moduleDisplayFields(module).toSet();
        next.contains(field) ? next.remove(field) : next.add(field);
        return controller.setModuleDisplayFields(module, next);
      }
    }
    if (module == 'repair' &&
        (id == 'fleet-name-custom' || id == 'fleet-name-number')) {
      return controller.setRepairFleetSelectorLabelMode(
        id == 'fleet-name-custom'
            ? FleetSelectorLabelMode.customName
            : FleetSelectorLabelMode.number,
      );
    }
    return Future<void>.value();
  }

  Map<String, Object?> item(String id, String label, bool checked) => {
    'id': id,
    'label': label,
    'value': '',
    'checked': checked,
  };
  return showGameDisplaySettingsDialog(
    context: context,
    controller: controller,
    kind: 'moduleDisplay',
    title: text(moduleDisplayTitles[module] ?? FleetUiKeys.displayContent),
    resetLabel: text(FleetUiKeys.reset),
    onReset: reset,
    onToggle: toggle,
    items: () => [
      item(
        'appearance-logo',
        '${text(FleetUiKeys.capsuleAppearance)} · ${text('LOGO')}',
        controller.moduleShowLogo(module),
      ),
      item(
        'appearance-name',
        '${text(FleetUiKeys.capsuleAppearance)} · ${text(FleetUiKeys.name)}',
        controller.moduleShowName(module),
      ),
      for (final option in options.entries)
        item(
          'field-${option.key}',
          '${text(FleetUiKeys.displayContent)} · ${text(option.value)}',
          controller.moduleDisplayFields(module).contains(option.key),
        ),
      if (module == 'repair') ...[
        item(
          'fleet-name-custom',
          '${text(FleetUiKeys.fleetSelectorName)} · ${text(FleetUiKeys.customFleetName)}',
          controller.repairFleetSelectorLabelMode ==
              FleetSelectorLabelMode.customName,
        ),
        item(
          'fleet-name-number',
          '${text(FleetUiKeys.fleetSelectorName)} · ${text(FleetUiKeys.shortFleetNumber)}',
          controller.repairFleetSelectorLabelMode ==
              FleetSelectorLabelMode.number,
        ),
      ],
    ],
    builder: (context, close) => Dialog(
      key: Key('module-display-settings-$module'),
      backgroundColor: appColor(context, const Color(0xff142735)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final fields = controller.moduleDisplayFields(module);
            final options =
                moduleDisplayOptions[module] ?? const <String, String>{};
            final hasOptions = options.isNotEmpty;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fleetText(
                              context,
                              moduleDisplayTitles[module] ??
                                  FleetUiKeys.displayContent,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('$module-display-reset'),
                          tooltip: fleetText(context, FleetUiKeys.reset),
                          icon: const Icon(
                            Icons.settings_backup_restore_rounded,
                          ),
                          onPressed: reset,
                        ),
                        const Spacer(),
                        IconButton(
                          key: Key('$module-display-close'),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          icon: const Icon(Icons.close),
                          onPressed: close,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fleetText(context, FleetUiKeys.capsuleAppearance),
                      style: TextStyle(
                        color: appColor(context, Color(0xffd8ad60)),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          key: Key('$module-capsule-logo'),
                          label: Text(fleetText(context, 'LOGO')),
                          selected: controller.moduleShowLogo(module),
                          showCheckmark: false,
                          onSelected: (enabled) {
                            controller.setModuleShowLogo(module, enabled);
                          },
                        ),
                        FilterChip(
                          key: Key('$module-capsule-name'),
                          label: Text(fleetText(context, FleetUiKeys.name)),
                          selected: controller.moduleShowName(module),
                          showCheckmark: false,
                          onSelected: (enabled) {
                            controller.setModuleShowName(module, enabled);
                          },
                        ),
                      ],
                    ),
                    if (hasOptions) ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: appColor(context, Color(0xff294052)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fleetText(context, FleetUiKeys.displayContent),
                        style: TextStyle(
                          color: appColor(context, Color(0xffd8ad60)),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final item in options.entries)
                            FilterChip(
                              key: Key('$module-display-${item.key}'),
                              label: Text(fleetText(context, item.value)),
                              selected: fields.contains(item.key),
                              showCheckmark: false,
                              onSelected: (enabled) {
                                final next = {...fields};
                                enabled
                                    ? next.add(item.key)
                                    : next.remove(item.key);
                                controller.setModuleDisplayFields(module, next);
                              },
                            ),
                        ],
                      ),
                    ],
                    if (module == 'repair') ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: appColor(context, Color(0xff294052)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fleetText(context, FleetUiKeys.fleetSelectorName),
                        style: TextStyle(
                          color: appColor(context, Color(0xffd8ad60)),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            key: const Key('repair-selector-label-custom-name'),
                            label: Text(
                              fleetText(context, FleetUiKeys.customFleetName),
                            ),
                            selected:
                                controller.repairFleetSelectorLabelMode ==
                                FleetSelectorLabelMode.customName,
                            showCheckmark: false,
                            onSelected: (_) {
                              controller.setRepairFleetSelectorLabelMode(
                                FleetSelectorLabelMode.customName,
                              );
                            },
                          ),
                          ChoiceChip(
                            key: const Key('repair-selector-label-number'),
                            label: Text(
                              fleetText(context, FleetUiKeys.shortFleetNumber),
                            ),
                            selected:
                                controller.repairFleetSelectorLabelMode ==
                                FleetSelectorLabelMode.number,
                            showCheckmark: false,
                            onSelected: (_) {
                              controller.setRepairFleetSelectorLabelMode(
                                FleetSelectorLabelMode.number,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class ModuleSlotGrid extends StatelessWidget {
  const ModuleSlotGrid({
    super.key,
    required this.children,
    required this.emptyLabel,
    this.columns = 2,
    this.runSpacing = 8,
  });
  final int columns;
  final double runSpacing;
  final List<Widget> children;
  final String emptyLabel;
  @override
  Widget build(BuildContext context) => children.isEmpty
      ? PanelStyleScope.isFlat(context)
            ? FlatEmptyText(fleetText(context, emptyLabel))
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  fleetText(context, emptyLabel),
                  style: TextStyle(
                    color: appColor(context, const Color(0xff8197a5)),
                  ),
                ),
              )
      : LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: runSpacing,
            children: [
              for (final child in children)
                SizedBox(
                  width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
                  child: child,
                ),
            ],
          ),
        );
}
