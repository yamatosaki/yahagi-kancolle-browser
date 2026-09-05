import 'package:flutter/material.dart';
import '../battle/battle_detail_models.dart';
import '../battle/battle_detail_strings.dart';

// Shared by the logbook and the isolated UI preview. No sample data is loaded here.
// LogbookPage owns insets for both this view and the adjacent record list.
const ink = Color(0xff081521);
const panel = Color(0xff0b202d);
const border = Color(0xff294556);
const muted = Color(0xff92aab7);
const friend = Color(0xff91d8f3);
const enemy = Color(0xffffaaa3);
const gold = Color(0xffffd977);
const healthy = Color(0xff4dbb8b);
const _headerFontSize = 15.0;

Text label(
  String value, {
  Color color = const Color(0xffe4edf1),
  double size = 13,
  bool bold = false,
}) => Text(
  value,
  style: TextStyle(
    color: color,
    fontSize: size,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
  ),
);

class BattleDetailPage extends StatefulWidget {
  const BattleDetailPage({
    super.key,
    required this.detail,
    required this.onBack,
  });
  final BattleDetailSnapshot detail;
  final VoidCallback onBack;
  @override
  State<BattleDetailPage> createState() => _BattleDetailPageState();
}

class _BattleDetailPageState extends State<BattleDetailPage> {
  BattleDetailStrings get strings => BattleDetailStrings.of(context);

  int tab = 0;
  int filter = 0;
  final Set<String> closed = {};

  @override
  void didUpdateWidget(covariant BattleDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) {
      closed.clear();
      filter = 0;
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('battle-detail-page'),
    color: ink,
    child: Column(
      children: [
        _header(),
        Expanded(child: tab == 0 ? _fleets() : _process()),
      ],
    ),
  );

  Widget _tabs() => Container(
    key: const Key('detail-tabs'),
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: ink,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++)
          SizedBox(
            width: i == 0 ? 54 : 74,
            height: 24,
            child: TextButton(
              key: Key(
                i == 0
                    ? 'battle-detail-tab-fleet'
                    : 'battle-detail-tab-process',
              ),
              style: TextButton.styleFrom(
                foregroundColor: tab == i ? gold : muted,
                backgroundColor: tab == i
                    ? const Color(0xff806024)
                    : Colors.transparent,
                padding: EdgeInsets.zero,
                shape: const StadiumBorder(),
              ),
              onPressed: () => setState(() => tab = i),
              child: label(
                i == 0 ? strings.fleet : strings.process,
                size: 12,
                color: tab == i ? gold : muted,
                bold: true,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _header() => LayoutBuilder(
    builder: (context, box) {
      final inline = box.maxWidth >= 640;
      final detail = widget.detail;
      return Container(
        key: const Key('battle-detail-header'),
        padding: const EdgeInsets.fromLTRB(4, 3, 12, 3),
        decoration: const BoxDecoration(
          color: panel,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    key: const Key('battle-detail-back'),
                    tooltip: strings.back,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: friend,
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      label(
                        '${strings.title} · ${strings.localize(detail.mapLabel)} ${strings.localize(detail.nodeLabel)}',
                        size: _headerFontSize,
                        bold: true,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (detail.enemyFleetName.isNotEmpty) ...[
                            Flexible(
                              child: Tag(
                                strings.localize(detail.enemyFleetName),
                                color: enemy,
                                pill: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Tag(detail.rank, color: gold),
                        ],
                      ),
                    ],
                  ),
                ),
                if (inline) ...[const SizedBox(width: 8), _tabs()],
              ],
            ),
            if (!inline)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Align(alignment: Alignment.centerLeft, child: _tabs()),
              ),
          ],
        ),
      );
    },
  );

  Widget _fleets() => LayoutBuilder(
    builder: (context, box) {
      Widget side(BattleDetailSide side) {
        final fleets = widget.detail.fleets
            .where((f) => f.side == side && f.ships.isNotEmpty)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final fleet in fleets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FleetCard(fleet: fleet),
              ),
          ],
        );
      }

      return SingleChildScrollView(
        key: const PageStorageKey('battle-detail-fleet-scroll'),
        padding: const EdgeInsets.all(12),
        child: box.maxWidth >= 700
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: side(BattleDetailSide.friend)),
                  const SizedBox(width: 12),
                  Expanded(child: side(BattleDetailSide.enemy)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  side(BattleDetailSide.friend),
                  side(BattleDetailSide.enemy),
                ],
              ),
      );
    },
  );

  BattleDetailShip? _targetShip(BattleDetailAttack attack) {
    if (attack.defenderRole == null || attack.defenderPosition == null) {
      return null;
    }
    return widget.detail
        .fleet(attack.defenderSide, attack.defenderRole!)
        ?.ships
        .where((ship) => ship.position == attack.defenderPosition)
        .firstOrNull;
  }

  Widget _process() {
    var number = 0;
    final entries =
        <
          ({
            BattleDetailStage stage,
            List<({BattleDetailAttack attack, int number})> attacks,
          })
        >[];
    for (final stage in widget.detail.stages) {
      final attacks = <({BattleDetailAttack attack, int number})>[];
      for (final attack in stage.attacks) {
        number++;
        if (filter == 0 ||
            (filter == 1 && attack.attackerSide != BattleDetailSide.enemy) ||
            (filter == 2 && attack.attackerSide == BattleDetailSide.enemy)) {
          attacks.add((attack: attack, number: number));
        }
      }
      if (attacks.isNotEmpty) entries.add((stage: stage, attacks: attacks));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                key: const Key('battle-detail-filter-container'),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: ink,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      SizedBox(
                        width: i == 0 ? 54 : 74,
                        height: 24,
                        child: TextButton(
                          key: Key(
                            [
                              'battle-detail-filter-all',
                              'battle-detail-filter-friend',
                              'battle-detail-filter-enemy',
                            ][i],
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: filter == i ? gold : muted,
                            backgroundColor: filter == i
                                ? const Color(0xff806024)
                                : Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => setState(() => filter = i),
                          child: label(
                            [
                              strings.all,
                              strings.sideAttack(BattleDetailSide.friend),
                              strings.sideAttack(BattleDetailSide.enemy),
                            ][i],
                            size: 12,
                            color: filter == i ? gold : muted,
                            bold: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              label(strings.chronological, color: muted, size: 11),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: label(strings.noAttacks, color: muted))
              : ListView.builder(
                  key: PageStorageKey('battle-detail-process-$filter'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final stage = entry.stage;
                    final isClosed = closed.contains(stage.keyName);
                    final npcStage = stage.attacks.any(
                      (a) => a.attackerSide == BattleDetailSide.npc,
                    );
                    final beneficiary = npcStage
                        ? BattleDetailSide.npc
                        : BattleDetailSide.friend;

                    final dealt = stage.attacks
                        .where((a) => a.attackerSide != BattleDetailSide.enemy)
                        .fold(0, (sum, a) => sum + a.totalDamage);
                    final received = stage.attacks
                        .where((a) => a.defenderSide == beneficiary)
                        .fold(0, (sum, a) => sum + a.totalDamage);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            key: Key('stage-${stage.keyName}'),
                            onTap: () => setState(() {
                              if (!closed.remove(stage.keyName)) {
                                closed.add(stage.keyName);
                              }
                            }),
                            child: Container(
                              color: const Color(0xff112b39),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isClosed
                                        ? Icons.chevron_right
                                        : Icons.expand_more,
                                    color: gold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        label(
                                          strings.localize(stage.title),
                                          color: gold,
                                          bold: true,
                                        ),
                                        label(
                                          strings.stageDamage(
                                            beneficiary,
                                            dealt,
                                            received,
                                          ),
                                          color: muted,
                                          size: 11,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  label(
                                    strings.attackCount(entry.attacks.length),
                                    color: muted,
                                    size: 11,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isClosed)
                            for (final row in entry.attacks)
                              _AttackReport(
                                key: Key('attack-${row.number}'),
                                attack: row.attack,
                                number: row.number,
                                target: _targetShip(row.attack),
                              ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.color = muted,
    this.size = 11,
    this.pill = false,
  });
  final String text;
  final Color color;
  final double size;
  final bool pill;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      border: Border.all(color: color.withValues(alpha: .28)),
      borderRadius: BorderRadius.circular(pill ? 20 : 5),
    ),
    child: label(text, color: color, size: size, bold: true),
  );
}

class _AttackReport extends StatelessWidget {
  const _AttackReport({
    super.key,
    required this.attack,
    required this.number,
    this.target,
  });
  final BattleDetailAttack attack;
  final int number;
  final BattleDetailShip? target;

  String? get targetStatus {
    if (target?.hpUnknown == true || attack.defenderHpAfter < 0) return null;
    final hp = attack.defenderHpAfter;

    if (hp == 0 &&
        attack.defenderHpBefore > 0 &&
        attack.damageControlName == null) {
      return 'sunk';
    }
    final maxHp = target?.maxHp ?? 0;
    if (hp <= 0 || maxHp <= 0) return null;
    if (hp * 4 <= maxHp) return 'heavy';
    if (hp * 2 <= maxHp) return 'moderate';
    if (hp * 4 <= maxHp * 3) return 'minor';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = BattleDetailStrings.of(context);
    final a = attack;
    final accent = a.attackerSide != BattleDetailSide.enemy ? friend : enemy;
    final missed =
        a.hits.isNotEmpty &&
        a.hits.every((h) => h.kind == BattleDetailHitKind.miss);
    final critical = a.hits.any((h) => h.kind == BattleDetailHitKind.critical);
    final status = targetStatus;
    final statusColor = status == 'minor'
        ? gold
        : status == 'moderate'
        ? const Color(0xffffb45e)
        : enemy;
    final hp = strings.targetHp(
      a.defenderHpBefore,
      a.defenderHpAfter,
      a.totalDamage,
      unknown: target?.hpUnknown == true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: LayoutBuilder(
            builder: (context, box) {
              // Keep the result beside the attack at every device width.
              // Narrow viewports give the result more room for its badges.
              final compact = box.maxWidth < 480;
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      label(
                        number.toString().padLeft(2, '0'),
                        color: muted,
                        size: 11,
                      ),
                      Tag(strings.sideAttack(a.attackerSide), color: accent),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: strings.localize(a.attackerName),
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  ${strings.attack}  ',
                          style: const TextStyle(color: muted),
                        ),
                        TextSpan(
                          text: strings.localize(a.defenderName),
                          style: TextStyle(
                            color: a.defenderSide == BattleDetailSide.enemy
                                ? enemy
                                : friend,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              );
              final ending = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(
                        missed ? strings.miss : strings.damage(a.totalDamage),
                        color: missed ? muted : gold,
                        pill: true,
                      ),
                      if (critical && !missed)
                        Tag(strings.critical, color: enemy, pill: true),
                      if (status != null)
                        Tag(
                          '${strings.sideName(a.defenderSide)}${strings.damageStatus(status)}',
                          color: statusColor,
                          pill: true,
                        ),
                      if (a.damageControlName != null)
                        Tag(strings.damageControl, color: healthy, pill: true),
                    ],
                  ),
                  const SizedBox(height: 7),
                  label(hp, color: muted, size: 12),
                ],
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 54,
                    color: accent.withValues(alpha: .65),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: compact ? 4 : 6, child: summary),
                        SizedBox(width: compact ? 12 : 20),
                        Expanded(flex: compact ? 6 : 4, child: ending),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FleetCard extends StatelessWidget {
  const _FleetCard({required this.fleet});
  final BattleDetailFleet fleet;
  @override
  Widget build(BuildContext context) {
    final strings = BattleDetailStrings.of(context);
    final own = fleet.side != BattleDetailSide.enemy;
    final title = strings.fleetTitle(fleet.side, fleet.role);
    final accent = own ? friend : enemy;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: panel,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff112b39),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Row(
              children: [
                Expanded(child: label(title, color: accent, bold: true)),
                label(
                  strings.shipCount(fleet.ships.length),
                  color: muted,
                  size: 11,
                ),
              ],
            ),
          ),
          for (final ship in fleet.ships) _ShipCard(ship: ship),
        ],
      ),
    );
  }
}

class _ShipCard extends StatelessWidget {
  const _ShipCard({required this.ship});
  final BattleDetailShip ship;

  String? get damageStatus {
    if (ship.hpUnknown || ship.maxHp <= 0 || ship.finalHp < 0) return null;
    final hp = ship.finalHp;
    if (hp == 0) return 'sunk';
    if (hp * 4 <= ship.maxHp) return 'heavy';
    if (hp * 2 <= ship.maxHp) return 'moderate';
    if (hp * 4 <= ship.maxHp * 3) return 'minor';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = BattleDetailStrings.of(context);
    final s = ship;
    final status = damageStatus;
    final statusColor = status == 'minor'
        ? gold
        : status == 'moderate'
        ? const Color(0xffffb45e)
        : enemy;
    final ratio = s.maxHp <= 0 ? 0.0 : (s.finalHp / s.maxHp).clamp(0.0, 1.0);
    final hpColor = s.hpUnknown
        ? muted
        : ratio <= .25
        ? enemy
        : ratio <= .5
        ? gold
        : healthy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tag((s.position + 1).toString(), color: friend),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    label(
                      strings.localize(s.name) +
                          (s.level == null ? '' : '  Lv.${s.level}'),
                      size: 13,
                      bold: true,
                    ),
                    if (status != null)
                      Tag(
                        strings.damageStatus(status),
                        color: statusColor,
                        pill: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              label(
                s.hpUnknown
                    ? '${strings.hpUnknown}（-${s.damageReceived}）'
                    : '${s.finalHp} / ${s.maxHp}（-${s.damageReceived}）',
                color: hpColor,
                size: 12,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: s.hpUnknown ? 0 : ratio,
              minHeight: 5,
              color: hpColor,
              backgroundColor: const Color(0xff20333e),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              label(
                s.hpUnknown
                    ? strings.hpUnknown
                    : strings.hpChange(s.initialHp, s.finalHp),
                color: muted,
                size: 11,
              ),
              label(strings.dealt(s.damageDealt), color: muted, size: 11),
              label(strings.received(s.damageReceived), color: muted, size: 11),
              if (s.escaped) Tag(strings.escaped),
            ],
          ),
        ],
      ),
    );
  }
}
