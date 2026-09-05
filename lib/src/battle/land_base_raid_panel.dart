import 'package:flutter/material.dart';

import 'battle_ui_text.dart';

import '../fleet/ship_status_style.dart';
import 'battle_models.dart';
import 'battle_pills.dart';

class LandBaseRaidPanel extends StatelessWidget {
  const LandBaseRaidPanel({
    super.key,
    required this.result,
    this.compact = false,
  });

  final LandBaseRaidResult result;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('land-base-raid-panel'),
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xff24191b),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff713d43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Color(0xffff8c78),
              ),
              const SizedBox(width: 6),
              const BattleUiText(
                '基地空袭',
                style: TextStyle(
                  color: Color(0xffffa092),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              AirSuperiorityPill(label: result.airSuperiority),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: ColoredBox(
              color: const Color(0xff10212e),
              child: Column(
                children: <Widget>[
                  for (var index = 0; index < result.bases.length; index++) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xff294354),
                      ),
                    _LandBaseRaidTile(
                      base: result.bases[index],
                      compact: compact,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandBaseRaidTile extends StatelessWidget {
  const _LandBaseRaidTile({required this.base, required this.compact});

  final LandBaseRaidSnapshot base;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ratio = base.hpRatio.clamp(0.0, 1.0);
    final isZeroHp = base.currentHp <= 0;
    final barColor = shipHpBarColor(ratio, isZeroHp: isZeroHp);
    final valueColor = shipHpValueColor(ratio, isZeroHp: isZeroHp);
    return Padding(
      key: Key('land-base-raid-${base.baseId}'),
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: compact ? 7 : 9),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              _landBaseJapaneseName(base.baseId),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Color(0xfff0f5f7),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${base.currentHp}/${base.maxHp}（-${base.damage}）',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: compact ? 6 : 7,
                    value: ratio,
                    color: barColor,
                    backgroundColor: const Color(0xff263e4d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _landBaseJapaneseName(int baseId) {
  return switch (baseId) {
    1 => '第一基地航空隊',
    2 => '第二基地航空隊',
    3 => '第三基地航空隊',
    4 => '第四基地航空隊',
    5 => '第五基地航空隊',
    _ => '第$baseId基地航空隊',
  };
}
