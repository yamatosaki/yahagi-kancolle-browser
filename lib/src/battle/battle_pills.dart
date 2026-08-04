import 'package:flutter/material.dart';

const double _battlePillHeight = 20;
const EdgeInsets _battlePillPadding = EdgeInsets.symmetric(horizontal: 8);
const TextStyle _battlePillTextStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1,
);

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

/// Boss nodes use red text so the player always knows they are at the boss,
/// normal nodes keep the gold style.
NodeTypePillColors nodeTypePillColors(String label) {
  if (label == 'Boss 战') {
    return const NodeTypePillColors(
      background: Color(0xff2b1a17),
      foreground: Color(0xffff8c78),
      border: Color(0xffa0453a),
    );
  }
  return const NodeTypePillColors(
    background: Color(0xff4a3b21),
    foreground: Color(0xffffc95c),
    border: Color(0xff8b6a2b),
  );
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
          '制空: $label',
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
          style: _battlePillTextStyle.copyWith(
            color: colors.foreground,
            fontWeight: label == 'Boss 战' ? FontWeight.w700 : FontWeight.w600,
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
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
