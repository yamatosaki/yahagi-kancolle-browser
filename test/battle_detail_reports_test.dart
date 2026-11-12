import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';
import 'fixtures/battle_detail_ui_sample.dart';

Widget app(
  BattleDetailSnapshot data, {
  Locale locale = const Locale('zh'),
  AppThemeMode mode = AppThemeMode.dark,
}) => MaterialApp(
  locale: locale,
  theme: ThemeData(extensions: [AppPalette(mode)]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BattleDetailPage(detail: data, onBack: () {}),
);

BattleDetailSnapshot sequence(List<BattleDetailStage> stages) =>
    BattleDetailSnapshot(
      completedAtMillis: 0,
      mapLabel: '5-5',
      nodeLabel: 'S点',
      rank: 'A',
      enemyFleetName: '测试舰队',
      stages: stages,
    );

BattleDetailAttack strike(
  BattleDetailSide attacker,
  String code,
  int hpBefore,
  int damage,
) => BattleDetailAttack(
  attackerSide: attacker,
  attackerName: '攻击舰',
  defenderSide: attacker == BattleDetailSide.enemy
      ? BattleDetailSide.friend
      : BattleDetailSide.enemy,
  defenderName: '受击舰',
  attackType: '炮击',
  attackTypeCode: code,
  defenderHpBefore: hpBefore,
  defenderHpAfter: hpBefore - damage,
  hits: [
    BattleDetailHit(
      damage: damage,
      hpAfter: hpBefore - damage,
      kind: damage == 0 ? BattleDetailHitKind.miss : BattleDetailHitKind.hit,
    ),
  ],
);

Finder textInAttack(int number, String text) => find.descendant(
  of: find.byKey(Key('attack-$number')),
  matching: find.text(text),
);

BattleDetailSnapshot report(
  BattleDetailSide target,
  int hp, {
  bool repair = false,
  bool unknown = false,
  int maxHp = 100,
  String attackTypeCode = 'Normal',
}) => BattleDetailSnapshot(
  completedAtMillis: 0,
  mapLabel: '1-1',
  nodeLabel: 'C点',
  rank: 'S',
  enemyFleetName: '测试舰队',
  fleets: [
    BattleDetailFleet(
      side: target,
      role: BattleDetailFleetRole.escort,
      ships: [
        BattleDetailShip(
          name: '受击舰',
          side: target,
          role: BattleDetailFleetRole.escort,
          position: 0,
          initialHp: 100,
          maxHp: maxHp,
          finalHp: hp,
          hpUnknown: unknown,
        ),
      ],
    ),
    // Same position in main fleet must not determine escort status.
    BattleDetailFleet(
      side: target,
      role: BattleDetailFleetRole.main,
      ships: [
        BattleDetailShip(
          name: '同名舰',
          side: target,
          role: BattleDetailFleetRole.main,
          position: 0,
          initialHp: 200,
          maxHp: 200,
          finalHp: 200,
        ),
      ],
    ),
  ],
  stages: [
    BattleDetailStage(
      keyName: 'test',
      title: '炮击战',
      attacks: [
        BattleDetailAttack(
          attackerSide: target == BattleDetailSide.enemy
              ? BattleDetailSide.friend
              : BattleDetailSide.enemy,
          attackerName: '攻击舰',
          defenderSide: target,
          defenderName: '受击舰',
          defenderRole: BattleDetailFleetRole.escort,
          defenderPosition: 0,
          attackType: '炮击',
          attackTypeCode: attackTypeCode,
          defenderHpBefore: 100,
          defenderHpAfter: hp,
          damageControlName: repair ? '应急修理女神' : null,
          hits: [
            BattleDetailHit(
              damage: repair ? 120 : 100 - hp,
              kind: BattleDetailHitKind.hit,
              hpAfter: hp,
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  for (final (target, code, label, color) in [
    (BattleDetailSide.enemy, 'Nagato', '一齐射击（长门）', const Color(0xffff8b88)),
    (BattleDetailSide.enemy, 'TTCI', '鱼雷 CI', const Color(0xffbfa4ff)),
    (BattleDetailSide.friend, 'TTCI', '鱼雷 CI', const Color(0xffbfa4ff)),
    (BattleDetailSide.friend, 'CVCI', '战爆联合 CI', const Color(0xffbfa4ff)),
    (BattleDetailSide.friend, 'Double', null, null),
    (BattleDetailSide.enemy, 'Normal', null, null),
  ]) {
    testWidgets('attack type pill for $target $code', (tester) async {
      final saved = report(target, 70, attackTypeCode: code);
      await tester.pumpWidget(
        app(BattleDetailSnapshot.fromJson(saved.toJson())),
      );
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();

      final side = find.text(
        target == BattleDetailSide.enemy ? '我方攻击' : '敌方攻击',
      );
      final header = find.ancestor(of: side, matching: find.byType(Wrap));
      final tags = tester
          .widgetList<Tag>(
            find.descendant(of: header, matching: find.byType(Tag)),
          )
          .toList();
      expect(tags, hasLength(label == null ? 1 : 2));
      if (label != null) {
        expect(tags.last.text, label);
        expect(tags.last.color, color);
        expect(tags.last.pill, isTrue);
      }
    });
  }

  testWidgets('mixed stages keep attack pills with their rows when filtered', (
    tester,
  ) async {
    final battle = sequence([
      BattleDetailStage(
        keyName: 'day',
        title: '第一炮击战',
        attacks: [
          strike(BattleDetailSide.friend, 'Yamato_Triple', 100, 35),
          strike(BattleDetailSide.friend, 'Yamato_Triple', 65, 0),
          strike(BattleDetailSide.enemy, 'Laser', 100, 44),
        ],
      ),
      BattleDetailStage(
        keyName: 'night',
        title: '夜战',
        attacks: [
          strike(BattleDetailSide.enemy, 'TTCI', 56, 0),
          strike(BattleDetailSide.npc, 'Kongo_Class_Kaini_C', 65, 15),
          strike(BattleDetailSide.friend, 'UnknownFutureAttack', 50, 12),
        ],
      ),
    ]);
    await tester.pumpWidget(
      app(BattleDetailSnapshot.fromJson(battle.toJson())),
    );
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();

    expect(textInAttack(1, '大和三舰特殊攻击'), findsOneWidget);
    expect(textInAttack(2, '大和三舰特殊攻击'), findsOneWidget);
    expect(textInAttack(2, '未命中'), findsOneWidget);
    expect(textInAttack(3, '激光攻击'), findsOneWidget);
    expect(textInAttack(4, '鱼雷 CI'), findsOneWidget);
    expect(textInAttack(4, '未命中'), findsOneWidget);
    expect(textInAttack(5, '僚舰夜战突击'), findsOneWidget);
    final unknownHeader = find.ancestor(
      of: textInAttack(6, '我方攻击'),
      matching: find.byType(Wrap),
    );
    expect(
      find.descendant(of: unknownHeader, matching: find.byType(Tag)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('battle-detail-filter-enemy')));
    await tester.pumpAndSettle();
    expect(textInAttack(3, '激光攻击'), findsOneWidget);
    expect(textInAttack(4, '鱼雷 CI'), findsOneWidget);
    expect(textInAttack(4, '未命中'), findsOneWidget);
    expect(find.text('大和三舰特殊攻击'), findsNothing);
    expect(find.text('僚舰夜战突击'), findsNothing);

    await tester.tap(find.byKey(const Key('battle-detail-filter-friend')));
    await tester.pumpAndSettle();
    expect(textInAttack(1, '大和三舰特殊攻击'), findsOneWidget);
    expect(textInAttack(2, '大和三舰特殊攻击'), findsOneWidget);
    expect(textInAttack(5, '僚舰夜战突击'), findsOneWidget);
    expect(find.text('激光攻击'), findsNothing);
    expect(find.text('鱼雷 CI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (locale, mode, special, cutIn, miss) in [
    (
      const Locale('zh'),
      AppThemeMode.dark,
      '一齐射击（长门）',
      '鱼雷·运输桶·水雷见张员 CI',
      '未命中',
    ),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      AppThemeMode.seaSalt,
      '一齊射擊（長門）',
      '魚雷·運輸桶·水雷見張員 CI',
      '未命中',
    ),
    (
      const Locale('ja'),
      AppThemeMode.dark,
      '一斉射（長門）',
      '魚雷・ドラム缶・水雷見張員 CI',
      'ミス',
    ),
    (
      const Locale('ko'),
      AppThemeMode.skyBlue,
      '일제사격(長門)',
      '어뢰·드럼통·수뢰견시원 CI',
      '빗나감',
    ),
    (
      const Locale('en'),
      AppThemeMode.seaSalt,
      'Simultaneous fire (長門)',
      'Torpedo/Drum/Skilled Lookout CI',
      'Miss',
    ),
  ]) {
    testWidgets('localized attack pills fit narrow $locale $mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() async {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        app(
          sequence([
            BattleDetailStage(
              keyName: 'night',
              title: '夜战',
              attacks: [
                strike(BattleDetailSide.friend, 'Nagato', 100, 45),
                strike(
                  BattleDetailSide.friend,
                  'DestroyerTorpedoDrumCI',
                  55,
                  0,
                ),
              ],
            ),
          ]),
          locale: locale,
          mode: mode,
        ),
      );
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();

      final specialText = textInAttack(1, special);
      final cutInText = textInAttack(2, cutIn);
      final missText = textInAttack(2, miss);
      expect(specialText, findsOneWidget);
      expect(cutInText, findsOneWidget);
      expect(missText, findsOneWidget);
      final cutInTag = find.ancestor(of: cutInText, matching: find.byType(Tag));
      final missTag = find.ancestor(of: missText, matching: find.byType(Tag));
      expect(
        tester.getRect(cutInTag).right,
        lessThan(tester.getRect(missTag).left),
      );

      final palette = AppPalette(mode);
      final specialColor = tester.widget<Text>(specialText).style!.color!;
      final cutInColor = tester.widget<Text>(cutInText).style!.color!;
      expect(specialColor, palette.color(const Color(0xffff8b88)));
      expect(cutInColor, palette.color(const Color(0xffbfa4ff)));
      expect(cutInColor, isNot(specialColor));
      for (final color in [specialColor, cutInColor]) {
        final background = Color.alphaBlend(
          color.withValues(alpha: .10),
          palette.color(panel),
        );
        final luminances = [
          color.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + .05) / (luminances.first + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('target HP includes this attack damage', (tester) async {
    await tester.pumpWidget(app(sampleBattle(true)));
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('目标HP 120 → 96（-24）'), findsOneWidget);
  });
  testWidgets('reports hide attack type and hit count but preserve results', (
    tester,
  ) async {
    final data = sampleBattle(true);
    final attack = data.stages
        .expand((s) => s.attacks)
        .firstWhere((a) => a.hits.length == 2);
    await tester.pumpWidget(
      app(
        BattleDetailSnapshot(
          completedAtMillis: data.completedAtMillis,
          mapLabel: data.mapLabel,
          nodeLabel: data.nodeLabel,
          rank: data.rank,
          enemyFleetName: data.enemyFleetName,
          fleets: data.fleets,
          stages: [
            BattleDetailStage(
              keyName: 'test',
              title: '第一炮击战',
              attacks: [attack],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text(attack.attackType), findsNothing);
    expect(find.text('2段'), findsNothing);
    expect(find.text('第一炮击战'), findsOneWidget);
    expect(find.text('造成 120 伤害'), findsOneWidget);
    expect(find.text('敌方大破'), findsOneWidget);
    expect(find.text('目标HP 160 → 40（-120）'), findsOneWidget);
  });
  testWidgets('fleet equipment is not displayed', (tester) async {
    await tester.pumpWidget(app(sampleBattle(false)));
    expect(find.text('15.5cm三连装副炮'), findsNothing);
    expect(find.text('甲标的 丙型 ★4'), findsNothing);
    expect(find.text('造成 371'), findsOneWidget);
  });
  testWidgets('reports have no expandable details and use target HP', (
    tester,
  ) async {
    await tester.pumpWidget(app(sampleBattle(false)));
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('目标HP 33 → 0（-67）'), findsOneWidget);
    expect(find.textContaining('点击战报看明细'), findsNothing);
    final row = find.byKey(const Key('attack-1'));
    expect(
      find.descendant(of: row, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.expand_more)),
      findsNothing,
    );
    expect(find.text('第 1 段'), findsNothing);
    expect(
      find.ancestor(of: find.text('造成 67 伤害'), matching: find.byType(Tag)),
      findsOneWidget,
    );
  });
  for (final side in [BattleDetailSide.friend, BattleDetailSide.enemy]) {
    for (final entry in {
      76: null,
      75: '小破',
      51: '小破',
      50: '中破',
      26: '中破',
      25: '大破',
      1: '大破',
      0: '击沉',
    }.entries) {
      testWidgets('target state $side HP=${entry.key}', (tester) async {
        await tester.pumpWidget(app(report(side, entry.key)));
        await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
        await tester.pumpAndSettle();
        final prefix = side == BattleDetailSide.friend ? '我方' : '敌方';
        for (final status in ['小破', '中破', '大破', '击沉']) {
          expect(
            find.text('$prefix$status'),
            status == entry.value ? findsOneWidget : findsNothing,
          );
        }
      });
    }
  }
  testWidgets('damage control reports restored HP, not sinking', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(report(BattleDetailSide.friend, 100, repair: true)),
    );
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('损管发动'), findsOneWidget);
    expect(find.text('目标HP 100 → 100（-120）'), findsOneWidget);
    expect(find.text('我方击沉'), findsNothing);
    expect(find.text('我方大破'), findsNothing);
  });
  for (final unknown in [true, false]) {
    testWidgets('unknown or missing maximum HP is not guessed $unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          report(
            BattleDetailSide.enemy,
            20,
            unknown: unknown,
            maxHp: unknown ? 100 : 0,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      expect(find.text('敌方大破'), findsNothing);
      expect(find.text('敌方中破'), findsNothing);
      expect(find.text('敌方小破'), findsNothing);
    });
  }
}
