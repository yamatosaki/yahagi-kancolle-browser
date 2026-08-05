import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'battle_models.dart';

const double _battlePillHeight = 20;
const EdgeInsets _battlePillPadding = EdgeInsets.symmetric(horizontal: 8);
const TextStyle _battlePillTextStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1,
);

class AdaptiveBattleHeader extends StatelessWidget {
  const AdaptiveBattleHeader({
    super.key,
    required this.nodeLabel,
    required this.enemyName,
    required this.enemyStyle,
  });

  final String nodeLabel;
  final String enemyName;
  final TextStyle enemyStyle;

  @override
  Widget build(BuildContext context) {
    final nodeStyle = const TextStyle(
      color: Color(0xffffd65c),
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(nodeLabel, style: nodeStyle),
        const SizedBox(width: 6),
        Expanded(child: Text(enemyName, style: enemyStyle)),
      ],
    );
  }
}

class AirSuperiorityPillColors {
  const AirSuperiorityPillColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

class NodeTypePillColors {
  const NodeTypePillColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

NodeTypePillColors nodeTypePillColors(String label) {
  if (label == 'Boss 战') {
    return const NodeTypePillColors(
      background: Color(0xff2b1a17),
      foreground: Color(0xffff8c78),
      border: Color(0xffa0453a),
    );
  }
  if (label == '夜战') {
    return const NodeTypePillColors(
      background: Color(0xff302943),
      foreground: Color(0xffcbbcf6),
      border: Color(0xff6b5b91),
    );
  }
  if (const <String>{'资源获得', '运输点', '护送成功', '航空侦察', '泊地修理'}.contains(label)) {
    return const NodeTypePillColors(
      background: Color(0xff183e38),
      foreground: Color(0xff83d5c8),
      border: Color(0xff2f7469),
    );
  }
  if (const <String>{'资源损失', '起点', '无战斗', '路线选择', '节点事件'}.contains(label)) {
    return const NodeTypePillColors(
      background: Color(0xff26343e),
      foreground: Color(0xff9db2bf),
      border: Color(0xff526875),
    );
  }
  return const NodeTypePillColors(
    background: Color(0xff4a3b21),
    foreground: Color(0xffffc95c),
    border: Color(0xff8b6a2b),
  );
}

Color battlePhaseChipColor(String label) {
  if (label == '夜战') return const Color(0xffcbbcf6);
  if (label == '昼战' || label == '航空战') {
    return const Color(0xffffc95c);
  }
  return const Color(0xff9db2bf);
}

class MetaChipColors {
  const MetaChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

MetaChipColors metaChipColors(Color foreground) {
  if (foreground == const Color(0xffffc95c)) {
    return const MetaChipColors(
      background: Color(0xff4a3b21),
      foreground: Color(0xffffc95c),
      border: Color(0xff8b6a2b),
    );
  }
  if (foreground == const Color(0xffcbbcf6)) {
    return const MetaChipColors(
      background: Color(0xff302943),
      foreground: Color(0xffcbbcf6),
      border: Color(0xff6b5b91),
    );
  }
  if (foreground == const Color(0xff6fd3a9) ||
      foreground == const Color(0xff70c7bc)) {
    return MetaChipColors(
      background: const Color(0xff183e38),
      foreground: foreground,
      border: const Color(0xff2f7469),
    );
  }
  if (foreground == const Color(0xffff6f68)) {
    return const MetaChipColors(
      background: Color(0xff46211e),
      foreground: Color(0xffff6f68),
      border: Color(0xffa0453a),
    );
  }
  return const MetaChipColors(
    background: Color(0xff26343e),
    foreground: Color(0xff9db2bf),
    border: Color(0xff526875),
  );
}

class BattleRankBadgeColors {
  const BattleRankBadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

BattleRankBadgeColors battleRankBadgeColors(BattleRank rank) {
  switch (rank) {
    case BattleRank.ss:
    case BattleRank.s:
      return const BattleRankBadgeColors(
        background: Color(0xff4a3b21),
        foreground: Color(0xffffd65c),
        border: Color(0xffd4a85f),
      );
    case BattleRank.a:
      return const BattleRankBadgeColors(
        background: Color(0xff2b1a17),
        foreground: Color(0xffff8c78),
        border: Color(0xffa0453a),
      );
    case BattleRank.b:
      return const BattleRankBadgeColors(
        background: Color(0xff183e38),
        foreground: Color(0xff83d5c8),
        border: Color(0xff2f7469),
      );
    case BattleRank.c:
    case BattleRank.d:
    case BattleRank.e:
    case BattleRank.unknown:
      return const BattleRankBadgeColors(
        background: Color(0xff26343e),
        foreground: Color(0xff9db2bf),
        border: Color(0xff526875),
      );
  }
}

/// Air-control state colors: ensure/advantage green, disadvantage/loss red,
/// balance/unknown yellow.
AirSuperiorityPillColors airSuperiorityPillColors(String label) {
  switch (label) {
    case '确保':
    case '优势':
      return const AirSuperiorityPillColors(
        background: Color(0xff183e38),
        foreground: Color(0xff83d5c8),
        border: Color(0xff2f7469),
      );
    case '劣势':
    case '丧失':
      return const AirSuperiorityPillColors(
        background: Color(0xff46211e),
        foreground: Color(0xffff8c78),
        border: Color(0xffa0453a),
      );
    default:
      return const AirSuperiorityPillColors(
        background: Color(0xff4a3b21),
        foreground: Color(0xffffc95c),
        border: Color(0xff8b6a2b),
      );
  }
}

class AirSuperiorityPill extends StatelessWidget {
  const AirSuperiorityPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = airSuperiorityPillColors(label);
    return Container(
      key: const Key('air-superiority-pill'),
      height: _battlePillHeight,
      padding: _battlePillPadding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          (AppLocalizations.of(context) ??
                  lookupAppLocalizations(const Locale('zh')))
              .airStateLabel(label),
          style: _battlePillTextStyle.copyWith(color: colors.foreground),
        ),
      ),
    );
  }
}

class NodeTypePill extends StatelessWidget {
  const NodeTypePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = nodeTypePillColors(label);
    return Container(
      key: const Key('node-type-pill'),
      height: _battlePillHeight,
      padding: _battlePillPadding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: _battlePillTextStyle.copyWith(color: colors.foreground),
        ),
      ),
    );
  }
}

class DropPill extends StatelessWidget {
  const DropPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('battle-drop-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xff183e38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xff2f7469)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff83d5c8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = metaChipColors(color);
    return Container(
      height: _battlePillHeight,
      padding: _battlePillPadding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: _battlePillTextStyle.copyWith(color: colors.foreground),
        ),
      ),
    );
  }
}

class BattleRankBadge extends StatelessWidget {
  const BattleRankBadge({
    super.key,
    required this.rank,
    this.size = 50,
    this.fontSize = 21,
  });

  final BattleRank rank;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = battleRankBadgeColors(rank);
    return Container(
      key: const Key('battle-rank-badge'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        rank.label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String formationLabel(int value) =>
    const <int, String>{
      1: '单纵阵',
      2: '复纵阵',
      3: '轮形阵',
      4: '梯形阵',
      5: '单横阵',
      6: '警戒阵',
      11: '第一警戒',
      12: '第二警戒',
      13: '第三警戒',
      14: '第四警戒',
    }[value] ??
    '阵型 $value';

String engagementLabel(int value) =>
    const <int, String>{1: '同航战', 2: '反航战', 3: 'T 字有利', 4: 'T 字不利'}[value] ??
    '航向 $value';
