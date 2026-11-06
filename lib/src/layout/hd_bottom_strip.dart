import '../widgets/app_popup_menu_button.dart';
import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../settings/layout_settings_controller.dart';
import '../settings/ui_display_size.dart';
import '../widgets/top_notice.dart';
import 'hd_home_editor.dart';
import 'hd_dashboard_content.dart';
import 'panel_style.dart';
import 'ui_scale.dart';

class HdBottomStrip extends StatelessWidget {
  const HdBottomStrip({
    super.key,
    required this.controller,
    required this.moduleBuilder,
    this.editing = false,
    this.onStartEditing,
  });
  final LayoutSettingsController controller;
  final Widget Function(String module) moduleBuilder;
  final bool editing;
  final VoidCallback? onStartEditing;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final settings = controller.hdSettings;
      final modules = settings.bottom;
      Widget buildModule(int index) {
        final module = modules[index];
        final child = moduleBuilder(module.id);
        return module.id == 'fleet' ||
                module.id == 'land_base' ||
                module.id == 'repair' ||
                module.id == 'quests' ||
                module.id == 'expedition' ||
                module.id == 'pre_sortie'
            ? HdModuleColumns(columns: module.span, child: child)
            : child;
      }

      final strip = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: editing
            ? null
            : () {
                if (controller.uiLocked) {
                  final l10n =
                      AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh'));
                  TopNotice.show(context, message: l10n.uiLockedToast);
                  return;
                }
                onStartEditing?.call();
              },
        child: ColoredBox(
          color: appColor(context, const Color(0xff0c1c27)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final unit = (constraints.maxWidth - 16) / 3;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < modules.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      SizedBox(
                        width:
                            unit * modules[i].span + 8 * (modules[i].span - 1),
                        key: Key(
                          'hd-slot-${modules[i].span == 3 ? 'wide' : ['left', 'right', 'third'][i]}',
                        ),
                        child: DashboardDropTarget(
                          id: modules[i].id,
                          horizontal: true,
                          key: Key('hd-bottom-target-${modules[i].id}'),
                          accepts: (id) =>
                              editing && controller.canMoveHdModuleToBottom(id),
                          onMove: (id, after) =>
                              controller.moveHdModuleToBottom(
                                id,
                                before: modules[i].id,
                                after: after,
                              ),
                          child: ClipRect(
                            child: !editing
                                ? (settings.hidden.contains(modules[i].id)
                                      ? const SizedBox.expand()
                                      : buildModule(i))
                                : DashboardEditItem(
                                    id: modules[i].id,
                                    hidden: settings.hidden.contains(
                                      modules[i].id,
                                    ),
                                    onToggle: () => controller
                                        .toggleHdModuleHidden(modules[i].id),
                                    action: AppPopupMenuButton<int>(
                                      key: Key('hd-width-${modules[i].id}'),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text('1×${modules[i].span} ▾'),
                                      ),
                                      onSelected: (span) => controller
                                          .setHdModuleSpan(modules[i].id, span),
                                      itemBuilder: (_) => [
                                        for (var span = 1; span <= 3; span++)
                                          CheckedPopupMenuItem(
                                            value: span,
                                            checked: modules[i].span == span,
                                            enabled: controller
                                                .canSetHdModuleSpan(
                                                  modules[i].id,
                                                  span,
                                                ),
                                            child: Text('1×$span'),
                                          ),
                                      ],
                                    ),
                                    child: SizedBox(
                                      height: 72,
                                      child: buildModule(i),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                    if (settings.usedColumns < 3) ...[
                      if (modules.isNotEmpty) const SizedBox(width: 8),
                      Expanded(
                        child: !editing
                            ? (modules.isEmpty
                                  ? const _HdDropPlaceholder(
                                      key: Key('hd-empty-wide'),
                                      span: 3,
                                    )
                                  : const SizedBox.shrink())
                            : Row(
                                key: const Key('hd-bottom-target-empty'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var column = settings.usedColumns;
                                    column < 3;
                                    column++
                                  ) ...[
                                    if (column > settings.usedColumns)
                                      const SizedBox(width: 8),
                                    Expanded(
                                      child: DashboardDropTarget(
                                        key: Key('hd-empty-cell-$column'),
                                        horizontal: true,
                                        accepts:
                                            controller.canMoveHdModuleToBottom,
                                        onMove: (id, _) =>
                                            controller.moveHdModuleToBottom(id),
                                        child: const _HdDropPlaceholder(
                                          span: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      );
      return UiScale(
        scale: controller.uiDisplaySize.isMinimal ? minimalUiScale : 1.0,
        child: PanelStyleScope(
          style: controller.uiDisplaySize.isMinimal
              ? PanelStyle.flat
              : PanelStyle.card,
          child: strip,
        ),
      );
    },
  );
}

class _HdDropPlaceholder extends StatelessWidget {
  const _HdDropPlaceholder({super.key, required this.span});
  final int span;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: appColor(context, const Color(0xff49616f))),
      color: appColor(context, const Color(0xff102331)),
    ),
    padding: const EdgeInsets.all(8),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '1×$span',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffd4a85f)),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.hdDropArea,
            textAlign: TextAlign.center,
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xff8197a5)),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
