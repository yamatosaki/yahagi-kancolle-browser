import '../../theme/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../fleet/equipment_type_icon.dart';
import '../../fleet/ship_portrait.dart';
import '../../game_state/game_state.dart';
import '../../localization/game_name_localizations.dart';
import '../../widgets/top_notice.dart';
import 'enemy_catalog.dart';
import 'sortie_map_models.dart';
import 'sortie_enemy_details_strings.dart';

Future<void> showSortieEnemyDetails(
  BuildContext context, {
  required EnemyShipEntry entry,
  required GameState state,
  EnemyCatalogData? catalog,
}) async {
  if (catalog == null) {
    final loaded = await EnemyCatalogData.loadAsset();
    if (!context.mounted) return;
    return showSortieEnemyDetails(
      context,
      entry: entry,
      state: state,
      catalog: loaded,
    );
  }
  final details = catalog.resolve(entry);
  if (details == null) {
    final strings = EnemyDetailsStrings.of(context);
    TopNotice.show(
      context,
      message: strings.preciseConfigurationMissing,
      tone: TopNoticeTone.error,
    );
    return Future<void>.value();
  }
  return showDialog<void>(
    barrierDismissible: false,
    context: context,
    barrierColor: appColor(context, Colors.black54),
    builder: (context) =>
        _SortieEnemyDetailsDialog(entry: entry, details: details, state: state),
  );
}

class _SortieEnemyDetailsDialog extends StatelessWidget {
  const _SortieEnemyDetailsDialog({
    required this.entry,
    required this.details,
    required this.state,
  });

  final EnemyShipEntry entry;
  final EnemyConfiguration details;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final strings = EnemyDetailsStrings.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: appColor(context, Colors.transparent),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(360, viewport.width - 32),
          maxHeight: math.max(0, viewport.height - 32),
        ),
        child: Material(
          key: const Key('sortie-enemy-details-card'),
          color: appColor(context, Color(0xff192f3d)),
          elevation: 18,
          shadowColor: appColor(context, Colors.black87),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: appColor(context, Color(0x99ff907e))),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(entry: entry, details: details, state: state),
                const SizedBox(height: 8),
                Wrap(
                  key: const Key('sortie-enemy-primary-chips'),
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: 'Lv. ${_number(details.level)}',
                      color: appColor(context, const Color(0xffffc95c)),
                    ),
                    _InfoChip(
                      label: 'ID ${details.id}',
                      color: appColor(context, const Color(0xffff907e)),
                    ),
                    _InfoChip(
                      label: gameNames(
                        context,
                      ).shipTypeName(details.shipType ?? strings.enemyShip),
                      color: appColor(context, const Color(0xffffc95c)),
                    ),
                    _InfoChip(
                      label: strings.preciseConfiguration,
                      color: appColor(context, const Color(0xff70c7bc)),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _StatsGrid(details: details),
                const SizedBox(height: 10),
                Text(
                  strings.equipment,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (details.equipment.isEmpty)
                  Text(
                    strings.equipmentMissing,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff93aab8)),
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  for (final item in details.equipment)
                    _EquipmentRow(item: item, state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _number(num? value) => value?.toString() ?? '—';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.entry,
    required this.details,
    required this.state,
  });

  final EnemyShipEntry entry;
  final EnemyConfiguration details;
  final GameState state;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShipPortrait(
        ship: state.masterShips[details.id] ?? state.masterShips[entry.id],
        serverOrigin: state.serverOrigin,
        width: 72,
        height: 34,
        decodeHeight: 68,
        resourceType: ShipPortraitResourceType.banner,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          gameNames(context).shipName(entry.nameJa, shipId: entry.id),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        key: const Key('sortie-enemy-details-close'),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.of(context).pop(),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.close,
          size: 19,
          color: appColor(context, Color(0xffa5bac4)),
        ),
      ),
    ],
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.details});

  final EnemyConfiguration details;

  @override
  Widget build(BuildContext context) {
    final strings = EnemyDetailsStrings.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    Widget valueText(String value) => Text(
      value,
      maxLines: 1,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
    final stats = <(String, String)>[
      (strings.hp, _number(details.hp)),
      (strings.speed, strings.speedValue(details.speed)),
      (strings.range, strings.rangeValue(details.range)),
      (strings.aircraftCapacity, _number(details.aircraftCapacity)),
      (strings.firepower, _stat(details.firepower)),
      (strings.torpedo, _stat(details.torpedo)),
      (strings.antiAir, _stat(details.antiAir)),
      (strings.armor, _stat(details.armor)),
      (strings.evasion, _number(details.evasion)),
      (strings.antiSub, _number(details.antiSub)),
      (strings.search, _number(details.search)),
      (strings.luck, _number(details.luck)),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff10232e)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: GridView.count(
          key: const Key('sortie-enemy-vitals-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 2.35,
          mainAxisExtent: english
              ? MediaQuery.textScalerOf(context).scale(50)
              : null,
          children: [
            for (final stat in stats)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.$1,
                    maxLines: english ? 2 : null,
                    textAlign: english ? TextAlign.center : null,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff93aab8)),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (english)
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: valueText(stat.$2),
                      ),
                    )
                  else
                    valueText(stat.$2),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _number(num? value) => value?.toString() ?? '—';

  static String _stat(EnemyStat? value) => value == null
      ? '—'
      : value.equipped == null || value.equipped == value.base
      ? '${value.base}'
      : '${value.base} → ${value.equipped}';
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.item, required this.state});

  final EnemyEquipment item;
  final GameState state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        EquipmentTypeIconImage(
          iconId: _equipmentIconId(item, state),
          width: 20,
          height: 20,
          imageKey: Key('sortie-enemy-equipment-icon-${item.slot}'),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            gameNames(context).equipmentName(item.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

int _equipmentIconId(EnemyEquipment item, GameState state) {
  final normalizedName = normalizeEnemyName(item.name);
  for (final master in state.masterSlotItems.values) {
    if (normalizeEnemyName(master.name) == normalizedName &&
        master.type.length > 3) {
      return master.type[3];
    }
  }
  return enemyEquipmentTypeIconIds[item.type] ?? -1;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: appColor(context, color.withValues(alpha: .12)),
      border: Border.all(
        color: appColor(context, color.withValues(alpha: .55)),
      ),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        style: appTextStyle(
          context,
          TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
