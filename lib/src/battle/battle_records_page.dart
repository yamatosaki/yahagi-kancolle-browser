import 'package:flutter/material.dart';

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
      color: const Color(0xff081521),
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
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xff0d1a26),
        border: Border(bottom: BorderSide(color: Color(0xff294052))),
      ),
      child: Row(
        children: [
          const Text(
            '战斗记录',
            style: TextStyle(
              color: Color(0xffd4a85f),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<BattleRank?>(
              key: const Key('battle-rank-filter'),
              value: rankFilter,
              hint: const Text('全部评级'),
              dropdownColor: const Color(0xff142735),
              items: <DropdownMenuItem<BattleRank?>>[
                const DropdownMenuItem<BattleRank?>(
                  value: null,
                  child: Text('全部评级'),
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off, size: 42, color: Color(0xff567080)),
          SizedBox(height: 12),
          Text(
            '尚无战斗记录',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text('出击后会自动记录，不需要额外操作', style: TextStyle(color: Color(0xff8197a5))),
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
    final battle = record.battle;
    final dropName = battle.dropShipMasterId == null
        ? null
        : stateController
              .gameStateSnapshot
              .masterShips[battle.dropShipMasterId]
              ?.name;
    final dropItemName = battle.dropItemName?.trim();
    final friendAlive = battle.friendShips.where((ship) => !ship.isSunk).length;
    final enemyAlive = battle.enemyShips.where((ship) => !ship.isSunk).length;
    return Material(
      color: const Color(0xff142735),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xff294052)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: const Color(0xffd4a85f),
        collapsedIconColor: const Color(0xff8197a5),
        leading: _RecordRank(rank: battle.rank),
        title: Row(
          children: [
            Expanded(
              child: Text(
                battle.enemyFleetName.isEmpty ? '敌舰队' : battle.enemyFleetName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              _time(record.completedAt),
              style: const TextStyle(color: Color(0xff8197a5), fontSize: 12),
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
                '我方 $friendAlive/${battle.friendShips.length}　'
                '敌方 $enemyAlive/${battle.enemyShips.length}',
              ),
              if (dropName != null) Text('掉落：$dropName'),
              if ((battle.dropItemId ?? 0) > 0)
                Text(
                  '掉落：${dropItemName?.isNotEmpty == true ? dropItemName : '道具'}',
                ),
            ],
          ),
        ),
        children: [
          const Divider(color: Color(0xff294052)),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 680;
              final friend = _FleetResult(
                title: '我方最终状态',
                ships: battle.friendShips,
                color: const Color(0xff70c7bc),
              );
              final enemy = _FleetResult(
                title: '敌方最终状态',
                ships: battle.enemyShips,
                color: const Color(0xffff8c78),
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
        color: const Color(0xff2c2c22),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xff8b6a2b)),
      ),
      child: Text(
        rank.label,
        style: const TextStyle(
          color: Color(0xffffd65c),
          fontWeight: FontWeight.w900,
          fontSize: 18,
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
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        for (final ship in ships) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  ship.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${ship.currentHp}/${ship.maxHp}',
                style: TextStyle(
                  color: ship.isSunk
                      ? const Color(0xffff746d)
                      : const Color(0xffa9bdc8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ship.maxHp <= 0 ? 0 : ship.currentHp / ship.maxHp,
            minHeight: 4,
            backgroundColor: const Color(0xff243b49),
            color: ship.isSunk ? const Color(0xffff746d) : color,
          ),
          const SizedBox(height: 7),
        ],
      ],
    );
  }
}
