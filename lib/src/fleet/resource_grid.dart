import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../settings/header_resource_settings.dart';
import '../settings/layout_settings_controller.dart';
import '../performance/second_tick_scope.dart';
import 'anchorage_repair_calculator.dart';
import 'header_resource_catalog.dart';

class ResourceGrid extends StatelessWidget {
  const ResourceGrid({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 450 ? 2 : 4;

        const spacing = 4.0;
        final available =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final itemWidth = available.clamp(0.0, double.infinity);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final type in GameResourceType.values)
              SizedBox(
                width: itemWidth,
                child: Tooltip(
                  message: fleetText(context, type.label),
                  child: _ResourceItem(type: type, value: state.resource(type)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResourceItem extends StatelessWidget {
  const _ResourceItem({required this.type, required this.value});

  final GameResourceType type;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('resource-item-${type.apiId}'),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xff142735),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff315064)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Image.asset(
            _assetPath(type),
            key: Key('resource-icon-${type.apiId}'),
            width: 17,
            height: 17,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value?.toString() ?? '—',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _assetPath(GameResourceType type) =>
      'assets/images/material/${type.apiId.toString().padLeft(2, '0')}.png';
}

class CompactResourceBar extends StatefulWidget {
  const CompactResourceBar({
    super.key,
    required this.state,
    this.senka,
    this.rank,
    this.anchorageRepairStartedAt,
    this.nosakiSparkleStartedAt,
    this.settingsController,
    this.onSenkaTap,
    this.onAnchorageTimerTap,
    this.onNosakiTimerTap,
  });

  final GameState state;
  final double? senka;
  final int? rank;
  final DateTime? anchorageRepairStartedAt;
  final DateTime? nosakiSparkleStartedAt;
  final LayoutSettingsController? settingsController;
  final VoidCallback? onSenkaTap;
  final VoidCallback? onAnchorageTimerTap;
  final VoidCallback? onNosakiTimerTap;

  @override
  State<CompactResourceBar> createState() => _CompactResourceBarState();
}

class _CompactResourceBarState extends State<CompactResourceBar> {
  bool _editing = false;
  DateTime _now = DateTime.now().toUtc();

  String get _anchorageElapsed {
    if (!AnchorageRepairCalculator.hasReadyFleet(widget.state)) {
      return '--:--:--';
    }
    return formatAnchorageRepairElapsed(widget.anchorageRepairStartedAt, _now);
  }

  String get _nosakiElapsed {
    return formatNosakiSparkleElapsed(widget.nosakiSparkleStartedAt, _now);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anchorageRepairStartedAt == null &&
        widget.nosakiSparkleStartedAt == null) {
      return _buildWithSettings(context, DateTime.now().toUtc());
    }
    return SecondTickBuilder(
      builder: (context, now, _) => _buildWithSettings(context, now),
    );
  }

  Widget _buildWithSettings(BuildContext context, DateTime now) {
    _now = now;
    final controller = widget.settingsController;
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _buildBar(controller),
      );
    }
    return _buildBar(null);
  }

  Widget _buildBar(LayoutSettingsController? controller) {
    final order = controller?.headerResourceOrder ?? allHeaderResourceIds;
    final visible =
        (controller?.visibleHeaderResourceIds ??
                defaultVisibleHeaderResourceIds)
            .toSet();
    final ids = _editing
        ? order
        : <String>[
            for (final id in order)
              if (visible.contains(id)) id,
          ];
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return SizedBox(
      height: 30,
      child: _editing
          ? Row(
              key: const Key('header-resource-edit-mode'),
              children: [
                _EditButton(
                  key: const Key('header-resource-reset'),
                  icon: Icons.restart_alt_rounded,
                  tooltip: fleetText(context, '恢复默认'),
                  onPressed: controller?.resetHeaderResources,
                ),
                const SizedBox(width: 4),
                _EditButton(
                  key: const Key('header-resource-edit-done'),
                  icon: Icons.check_rounded,
                  tooltip: fleetText(context, '完成'),
                  onPressed: () => setState(() => _editing = false),
                ),
                const SizedBox(width: 4),
                _EditButton(
                  key: const Key('header-resource-filter'),
                  icon: Icons.filter_alt_rounded,
                  tooltip: fleetText(context, '筛选显示项目'),
                  onPressed: controller == null
                      ? null
                      : () => _showResourceFilter(controller),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: ids.length,
                    onReorderItem: (oldIndex, newIndex) {
                      if (controller == null) return;
                      final reordered = List<String>.from(ids);
                      final item = reordered.removeAt(oldIndex);
                      reordered.insert(
                        newIndex.clamp(0, reordered.length),
                        item,
                      );
                      controller.setHeaderResourceOrder(reordered);
                    },
                    itemBuilder: (context, index) {
                      final id = ids[index];
                      return Padding(
                        key: ValueKey('header-resource-edit-$id'),
                        padding: EdgeInsets.only(
                          right: index + 1 < ids.length ? 6 : 0,
                        ),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: _buildEditableItem(
                            id,
                            visible: visible.contains(id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : ListView.separated(
              key: const Key('header-resource-list'),
              padding: EdgeInsets.zero,
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: ids.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final id = ids[index];
                return GestureDetector(
                  key: Key('header-resource-$id'),
                  behavior: HitTestBehavior.opaque,
                  onTap: switch (id) {
                    headerSenkaId => widget.onSenkaTap,
                    headerAnchorageTimerId => widget.onAnchorageTimerTap,
                    headerNosakiTimerId => widget.onNosakiTimerTap,
                    _ => null,
                  },
                  onLongPress: () => setState(() => _editing = true),
                  child: Tooltip(
                    message: switch (id) {
                      headerSenkaId => fleetText(context, '战果'),
                      headerAnchorageTimerId => fleetText(context, '泊地修理计时'),
                      headerNosakiTimerId => fleetText(context, '野埼刷闪计时'),
                      headerShipCapacityId => l10n.shipGirl,
                      headerEquipmentCapacityId => l10n.equipment,
                      _ => fleetText(context, headerResourceById[id]!.label),
                    },
                    triggerMode:
                        id == headerSenkaId ||
                            id == headerAnchorageTimerId ||
                            id == headerNosakiTimerId
                        ? TooltipTriggerMode.manual
                        : TooltipTriggerMode.tap,
                    child: SizedBox(
                      width: switch (id) {
                        headerSenkaId => 142,
                        headerAnchorageTimerId => 128,
                        headerNosakiTimerId => 128,
                        headerShipCapacityId => 118,
                        headerEquipmentCapacityId => 138,
                        _ => 82,
                      },
                      child: _buildDisplayItem(id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDisplayItem(String id) {
    if (id == headerSenkaId) {
      return _HeaderSenkaSummary(senka: widget.senka, rank: widget.rank);
    }
    if (id == headerAnchorageTimerId) {
      return _HeaderAnchorageTimerSummary(elapsed: _anchorageElapsed);
    }
    if (id == headerNosakiTimerId) {
      return _HeaderNosakiTimerSummary(elapsed: _nosakiElapsed);
    }
    if (id == headerShipCapacityId || id == headerEquipmentCapacityId) {
      return _buildCapacityPill(id);
    }
    final spec = headerResourceById[id]!;
    return _HeaderResourceItem(spec: spec, value: spec.value(widget.state));
  }

  Widget _buildEditableItem(String id, {required bool visible}) {
    if (id == headerSenkaId) {
      return _EditableHeaderSenkaItem(
        senka: widget.senka,
        rank: widget.rank,
        visible: visible,
      );
    }
    if (id == headerAnchorageTimerId) {
      return _EditableHeaderAnchorageTimerItem(
        elapsed: _anchorageElapsed,
        visible: visible,
      );
    }
    if (id == headerNosakiTimerId) {
      return _EditableHeaderNosakiTimerItem(
        elapsed: _nosakiElapsed,
        visible: visible,
      );
    }
    if (id == headerShipCapacityId || id == headerEquipmentCapacityId) {
      return _EditableHeaderCapacityItem(
        width: id == headerShipCapacityId ? 118 : 138,
        visible: visible,
        child: _buildCapacityPill(id),
      );
    }
    final spec = headerResourceById[id]!;
    return _EditableHeaderResourceItem(
      spec: spec,
      value: spec.value(widget.state),
      visible: visible,
    );
  }

  Widget _buildCapacityPill(String id) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final ships = id == headerShipCapacityId;
    return _HeaderCapacityPill(
      key: Key(ships ? 'header-ship-capacity' : 'header-equipment-capacity'),
      label: ships ? l10n.shipGirl : l10n.equipment,
      current: widget.state.hasPortData
          ? (ships
                ? widget.state.ships.length
                : widget.state.equipmentCapacityUsed)
          : null,
      maximum: ships
          ? widget.state.maxShipCount
          : widget.state.maxEquipmentCount,
    );
  }

  Future<void> _showResourceFilter(LayoutSettingsController controller) async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xff102532),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xff315064)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fleetText(context, '选择顶部显示项目'),
                        style: TextStyle(
                          color: Color(0xffe0b25c),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('header-resource-filter-done'),
                      tooltip: fleetText(context, '完成'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.check_rounded,
                        color: Color(0xffe0b25c),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xff294052)),
              Flexible(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final visible = controller.visibleHeaderResourceIds.toSet();
                    return ListView.builder(
                      key: const Key('header-resource-filter-list'),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: controller.headerResourceOrder.length,
                      itemBuilder: (context, index) {
                        final id = controller.headerResourceOrder[index];
                        if (id == headerSenkaId) {
                          return _HeaderSenkaFilterRow(
                            senka: widget.senka,
                            rank: widget.rank,
                            visible: visible.contains(id),
                            onChanged: () =>
                                controller.toggleHeaderResourceVisible(id),
                          );
                        }
                        if (id == headerAnchorageTimerId) {
                          return _HeaderAnchorageTimerFilterRow(
                            elapsed: _anchorageElapsed,
                            visible: visible.contains(id),
                            onChanged: () =>
                                controller.toggleHeaderResourceVisible(id),
                          );
                        }
                        if (id == headerNosakiTimerId) {
                          return _HeaderNosakiTimerFilterRow(
                            elapsed: _nosakiElapsed,
                            visible: visible.contains(id),
                            onChanged: () =>
                                controller.toggleHeaderResourceVisible(id),
                          );
                        }
                        if (id == headerShipCapacityId ||
                            id == headerEquipmentCapacityId) {
                          final ships = id == headerShipCapacityId;
                          return _HeaderCapacityFilterRow(
                            id: id,
                            label: ships ? l10n.shipGirl : l10n.equipment,
                            value:
                                '${widget.state.hasPortData ? (ships ? widget.state.ships.length : widget.state.equipmentCapacityUsed) : '—'} / ${ships ? widget.state.maxShipCount ?? '—' : widget.state.maxEquipmentCount ?? '—'}',
                            icon: ships
                                ? Icons.directions_boat_filled_rounded
                                : Icons.build_rounded,
                            visible: visible.contains(id),
                            onChanged: () =>
                                controller.toggleHeaderResourceVisible(id),
                          );
                        }
                        final spec = headerResourceById[id]!;
                        return _HeaderResourceFilterRow(
                          spec: spec,
                          value: spec.value(widget.state),
                          visible: visible.contains(id),
                          onChanged: () =>
                              controller.toggleHeaderResourceVisible(id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCapacityPill extends StatelessWidget {
  const _HeaderCapacityPill({
    super.key,
    required this.label,
    required this.current,
    required this.maximum,
  });

  final String label;
  final int? current;
  final int? maximum;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xff315064)),
    ),
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        '$label: ${current ?? '—'} / ${maximum ?? '—'}',
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          color: Color(0xffdce6eb),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

String formatAnchorageRepairElapsed(DateTime? startedAt, DateTime now) {
  if (startedAt == null) return '--:--:--';
  final normalizedStart = startedAt.toUtc();
  final normalizedNow = now.toUtc();
  final elapsed = normalizedNow.isBefore(normalizedStart)
      ? Duration.zero
      : normalizedNow.difference(normalizedStart);
  final hours = elapsed.inHours.toString().padLeft(2, '0');
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String formatNosakiSparkleElapsed(DateTime? startedAt, DateTime now) {
  if (startedAt == null) return '--:--:--';
  final normalizedStart = startedAt.toUtc();
  final normalizedNow = now.toUtc();
  final elapsed = normalizedNow.isBefore(normalizedStart)
      ? Duration.zero
      : normalizedNow.difference(normalizedStart);
  final hours = elapsed.inHours.toString().padLeft(2, '0');
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _HeaderAnchorageTimerSummary extends StatelessWidget {
  const _HeaderAnchorageTimerSummary({required this.elapsed});

  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final isActive = elapsed != '--:--:--';
    return Container(
      key: const Key('header-anchorage-timer-summary'),
      width: 128,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xff142735),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff315064)),
      ),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          fleetText(context, '泊地：$elapsed'),
          maxLines: 1,
          style: TextStyle(
            color: isActive ? const Color(0xffdce6eb) : const Color(0xff9fb3bf),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _HeaderNosakiTimerSummary extends StatelessWidget {
  const _HeaderNosakiTimerSummary({required this.elapsed});

  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final isActive = elapsed != '--:--:--';
    return Container(
      key: const Key('header-nosaki-timer-summary'),
      width: 128,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xff142735),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff315064)),
      ),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          fleetText(context, '野埼：$elapsed'),
          maxLines: 1,
          style: TextStyle(
            color: isActive ? const Color(0xffdce6eb) : const Color(0xff9fb3bf),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _HeaderSenkaSummary extends StatelessWidget {
  const _HeaderSenkaSummary({required this.senka, required this.rank});

  final double? senka;
  final int? rank;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('header-senka-summary'),
    width: 142,
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xff315064)),
    ),
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        fleetText(context, '战果：${_formatSenka(senka)}（#${rank ?? '--'}）'),
        maxLines: 1,
        style: const TextStyle(
          color: Color(0xffe0b25c),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

String _formatSenka(double? value) {
  if (value == null) return '--';
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

class _HeaderResourceItem extends StatelessWidget {
  const _HeaderResourceItem({required this.spec, required this.value});

  final HeaderResourceSpec spec;
  final int? value;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xff315064)),
    ),
    child: Row(
      children: [
        Image.asset(
          spec.assetPath,
          width: 17,
          height: 17,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value?.toString() ?? '—',
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xffdce6eb),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EditableHeaderResourceItem extends StatelessWidget {
  const _EditableHeaderResourceItem({
    required this.spec,
    required this.value,
    required this.visible,
  });

  final HeaderResourceSpec spec;
  final int? value;
  final bool visible;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: 82,
      child: _HeaderResourceItem(spec: spec, value: value),
    ),
  );
}

class _EditableHeaderSenkaItem extends StatelessWidget {
  const _EditableHeaderSenkaItem({
    required this.senka,
    required this.rank,
    required this.visible,
  });

  final double? senka;
  final int? rank;
  final bool visible;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: 142,
      child: _HeaderSenkaSummary(senka: senka, rank: rank),
    ),
  );
}

class _EditableHeaderAnchorageTimerItem extends StatelessWidget {
  const _EditableHeaderAnchorageTimerItem({
    required this.elapsed,
    required this.visible,
  });

  final String elapsed;
  final bool visible;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: 128,
      child: _HeaderAnchorageTimerSummary(elapsed: elapsed),
    ),
  );
}

class _EditableHeaderNosakiTimerItem extends StatelessWidget {
  const _EditableHeaderNosakiTimerItem({
    required this.elapsed,
    required this.visible,
  });

  final String elapsed;
  final bool visible;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: 128,
      child: _HeaderNosakiTimerSummary(elapsed: elapsed),
    ),
  );
}

class _EditableHeaderCapacityItem extends StatelessWidget {
  const _EditableHeaderCapacityItem({
    required this.width,
    required this.visible,
    required this.child,
  });

  final double width;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(width: width, child: child),
  );
}

class _HeaderCapacityFilterRow extends StatelessWidget {
  const _HeaderCapacityFilterRow({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    required this.visible,
    required this.onChanged,
  });

  final String id;
  final String label;
  final String value;
  final IconData icon;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('header-resource-filter-row-$id'),
    color: Colors.transparent,
    child: InkWell(
      onTap: onChanged,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Checkbox(
              key: Key('header-resource-visible-$id'),
              value: visible,
              onChanged: (_) => onChanged(),
              visualDensity: VisualDensity.compact,
            ),
            Icon(icon, size: 24, color: const Color(0xff9fb3bf)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xffdce6eb),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

class _HeaderSenkaFilterRow extends StatelessWidget {
  const _HeaderSenkaFilterRow({
    required this.senka,
    required this.rank,
    required this.visible,
    required this.onChanged,
  });

  final double? senka;
  final int? rank;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('header-resource-filter-row-senka'),
    color: Colors.transparent,
    child: InkWell(
      onTap: onChanged,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Checkbox(
              key: const Key('header-resource-visible-senka'),
              value: visible,
              onChanged: (_) => onChanged(),
              visualDensity: VisualDensity.compact,
            ),
            const Icon(
              Icons.emoji_events_rounded,
              size: 24,
              color: Color(0xffe0b25c),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fleetText(context, '战果'),
                style: TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_formatSenka(senka)}（#${rank ?? '--'}）',
              style: const TextStyle(
                color: Color(0xffe0b25c),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

class _HeaderAnchorageTimerFilterRow extends StatelessWidget {
  const _HeaderAnchorageTimerFilterRow({
    required this.elapsed,
    required this.visible,
    required this.onChanged,
  });

  final String elapsed;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('header-resource-filter-row-anchorage-timer'),
    color: Colors.transparent,
    child: InkWell(
      onTap: onChanged,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Checkbox(
              key: const Key('header-resource-visible-anchorage-timer'),
              value: visible,
              onChanged: (_) => onChanged(),
              visualDensity: VisualDensity.compact,
            ),
            const Icon(
              Icons.anchor_rounded,
              size: 24,
              color: Color(0xff9fb3bf),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fleetText(context, '泊地计时'),
                style: TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              elapsed,
              style: const TextStyle(
                color: Color(0xff9fb3bf),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

class _HeaderNosakiTimerFilterRow extends StatelessWidget {
  const _HeaderNosakiTimerFilterRow({
    required this.elapsed,
    required this.visible,
    required this.onChanged,
  });

  final String elapsed;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('header-resource-filter-row-nosaki-timer'),
    color: Colors.transparent,
    child: InkWell(
      onTap: onChanged,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Checkbox(
              key: const Key('header-resource-visible-nosaki-timer'),
              value: visible,
              onChanged: (_) => onChanged(),
              visualDensity: VisualDensity.compact,
            ),
            const Icon(
              Icons.restaurant_rounded,
              size: 24,
              color: Color(0xff9fb3bf),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fleetText(context, '野埼计时'),
                style: TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              elapsed,
              style: const TextStyle(
                color: Color(0xff9fb3bf),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

class _HeaderResourceFilterRow extends StatelessWidget {
  const _HeaderResourceFilterRow({
    required this.spec,
    required this.value,
    required this.visible,
    required this.onChanged,
  });

  final HeaderResourceSpec spec;
  final int? value;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('header-resource-filter-row-${spec.id}'),
    color: Colors.transparent,
    child: InkWell(
      onTap: onChanged,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Checkbox(
              key: Key('header-resource-visible-${spec.id}'),
              value: visible,
              onChanged: (_) => onChanged(),
              visualDensity: VisualDensity.compact,
            ),
            Image.asset(
              spec.assetPath,
              width: 24,
              height: 24,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fleetText(context, spec.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value?.toString() ?? '—',
              style: const TextStyle(
                color: Color(0xff9fb3bf),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

class _EditButton extends StatelessWidget {
  const _EditButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 30,
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: const Color(0xffe0b25c)),
    ),
  );
}
