import '../theme/app_palette.dart';
import '../localization/game_name_localizations.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/ship_status_style.dart';
import 'battle_controller.dart';
import 'battle_models.dart';

class BattleRecordsPage extends StatefulWidget {
  const BattleRecordsPage({
    super.key,
    required this.controller,
    this.hideTitle = false,
  });

  final BattleController controller;
  final bool hideTitle;

  @override
  State<BattleRecordsPage> createState() => _BattleRecordsPageState();
}

class _BattleRecordsPageState extends State<BattleRecordsPage> {
  BattleRank? _rankFilter;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: appColor(context, const Color(0xff081521)),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final records = widget.controller.records
              .where(
                (record) => _rankFilter == null || record.rank == _rankFilter,
              )
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.hideTitle)
                _Header(
                  rankFilter: _rankFilter,
                  onRankChanged: (rank) => setState(() => _rankFilter = rank),
                ),
              Expanded(
                child: records.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _RecordCard(
                          key: Key('battle-record-$index'),
                          record: records[index],
                          stateController: widget.controller,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.rankFilter, required this.onRankChanged});

  final BattleRank? rankFilter;
  final ValueChanged<BattleRank?> onRankChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff0d1a26)),
        border: Border(
          bottom: BorderSide(color: appColor(context, Color(0xff294052))),
        ),
      ),
      child: Row(
        children: [
          Text(
            l10n.battleRecords,
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffd4a85f)),
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<BattleRank?>(
              barrierDismissible: false,
              key: const Key('battle-rank-filter'),
              value: rankFilter,
              hint: Text(l10n.allRanks),
              dropdownColor: appColor(context, Color(0xff142735)),
              items: <DropdownMenuItem<BattleRank?>>[
                DropdownMenuItem<BattleRank?>(
                  value: null,
                  child: Text(l10n.allRanks),
                ),
                for (final rank in BattleRank.values)
                  if (rank != BattleRank.unknown)
                    DropdownMenuItem<BattleRank?>(
                      value: rank,
                      child: Text(rank.label),
                    ),
              ],
              onChanged: onRankChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 42,
            color: appColor(context, Color(0xff567080)),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noBattleRecords,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.autoRecordHint,
            style: appTextStyle(
              context,
              TextStyle(color: appColor(context, Color(0xff8197a5))),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    super.key,
    required this.record,
    required this.stateController,
  });

  final BattleRecord record;
  final BattleController stateController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final battle = record.battle;
    final dropNames = <String>[
      for (final id in battle.effectiveDropShipMasterIds)
        gameNames(context).shipName(
          stateController.gameStateSnapshot.masterShips[id]?.name ?? 'ID: $id',
          shipId: id,
        ),
    ];
    final dropName = dropNames.isEmpty ? null : dropNames.join('、');
    final friendAlive = battle.friendShips.where((ship) => !ship.isSunk).length;
    final enemyAlive = battle.enemyShips.where((ship) => !ship.isSunk).length;
    return Material(
      color: appColor(context, Color(0xff142735)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: appColor(context, Color(0xff294052))),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: appColor(context, const Color(0xffd4a85f)),
        collapsedIconColor: appColor(context, const Color(0xff8197a5)),
        leading: _RecordRank(rank: battle.rank),
        title: Row(
          children: [
            Expanded(
              child: Text(
                battle.enemyFleetName.isEmpty
                    ? l10n.enemyFleet
                    : battle.enemyFleetName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              _time(record.completedAt),
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('${battle.context.mapLabel} · ${battle.context.nodeLabel}'),
              Text(battle.phaseLabel),
              Text(
                l10n.battleFleetSummary(
                  friendAlive,
                  battle.friendShips.length,
                  enemyAlive,
                  battle.enemyShips.length,
                ),
              ),
              if (dropName != null) Text(l10n.dropLabel(dropName)),
              for (final reward in battle.rewardItems)
                Text(
                  l10n.dropLabel(
                    '${reward.kind == BattleRewardKind.equipment ? gameNames(context).equipmentName(reward.name) : reward.name} ×${reward.count}',
                  ),
                ),
            ],
          ),
        ),
        children: [
          Divider(color: appColor(context, Color(0xff294052))),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 680;
              final friend = _FleetResult(
                title: l10n.friendFinalStatus,
                ships: battle.friendShips,
                color: appColor(context, Color(0xff70c7bc)),
              );
              final enemy = _FleetResult(
                title: l10n.enemyFinalStatus,
                ships: battle.enemyShips,
                color: appColor(context, const Color(0xffff8c78)),
              );
              return vertical
                  ? Column(
                      children: [friend, const SizedBox(height: 10), enemy],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: friend),
                        const SizedBox(width: 12),
                        Expanded(child: enemy),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _RecordRank extends StatelessWidget {
  const _RecordRank({required this.rank});

  final BattleRank rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff2c2c22)),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: appColor(context, Color(0xff8b6a2b))),
      ),
      child: Text(
        rank.label,
        style: appTextStyle(
          context,
          TextStyle(
            color: appColor(context, Color(0xffffd65c)),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _FleetResult extends StatelessWidget {
  const _FleetResult({
    required this.title,
    required this.ships,
    required this.color,
  });

  final String title;
  final List<BattleShipSnapshot> ships;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: appTextStyle(
            context,
            TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 7),
        for (final ship in ships) ...[
          Builder(
            builder: (context) {
              final ratio = ship.maxHp <= 0
                  ? 0.0
                  : (ship.currentHp / ship.maxHp).clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          gameNames(
                            context,
                          ).shipName(ship.name, shipId: ship.masterId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${ship.currentHp}/${ship.maxHp}',
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: shipHpValueColor(
                              ratio,
                              isZeroHp: ship.currentHp <= 0,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: appColor(context, Color(0xff243b49)),
                    color: appColor(
                      context,
                      shipHpBarColor(ratio, isZeroHp: ship.currentHp <= 0),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
