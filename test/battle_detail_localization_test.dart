import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_strings.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_rules.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';

void main() {
  const zh = BattleDetailStrings.forLocale(Locale('zh'));
  const hant = BattleDetailStrings.forLocale(
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  );
  const ja = BattleDetailStrings.forLocale(Locale('ja'));

  test('legacy replay labels translate without touching game proper names', () {
    expect(ja.localize('第一炮击战'), '第1砲撃戦');
    expect(hant.localize('第一炮击战'), '第一砲擊戰');
    expect(ja.localize('基地航空队 3'), '基地航空隊 3');
    expect(hant.localize('敌航空战'), '敵航空戰');
    expect(ja.localize('友军·夕立改二'), '友軍·夕立改二');
    expect(ja.localize('未知舰船'), '不明な艦船');
    expect(ja.localize('装备 99'), '装備 99');
    expect(ja.localize('我方主力（单纵阵）'), '味方主力（単縦陣）');
    expect(hant.localize('阵型 17'), '陣型 17');
    expect(ja.localize('节点 12'), 'マス 12');
    expect(hant.localize('潜艇战'), '潛艇戰');
    expect(ja.localize('潜艇战'), '潜水艦戦');
    expect(ja.localize('Z1点'), 'Z1マス');
    expect(ja.localize('深海棲艦'), '深海棲艦');
    expect(hant.localize('大和改二重'), '大和改二重');
    expect(zh.localize('友军·夕立改二'), '友军·夕立改二');
  });

  test(
    'all POI attack descriptions have Japanese and traditional coverage',
    () {
      for (final night in [false, true]) {
        for (final type in [
          0,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          100,
          101,
          102,
          103,
          104,
          105,
          106,
          200,
          201,
          300,
          301,
          302,
          400,
          401,
          1000,
        ]) {
          final raw = poiAttackTypeLabel(type, isNight: night);
          expect(zh.localize(raw), raw);
          if (raw == 'Nelson Touch') continue;
          expect(ja.localize(raw), isNot(raw), reason: '$type night=$night');
          expect(hant.localize(raw), isNot(raw), reason: '$type night=$night');
        }
      }
    },
  );

  for (final locale in [
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('ja'),
  ]) {
    testWidgets(
      'battle detail renders ${locale.toLanguageTag()} on a narrow screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final snapshot = BattleDetailSnapshot.fromJson(_snapshot.toJson());
        final stored = jsonEncode(snapshot.toJson());
        final strings = BattleDetailStrings.forLocale(locale);
        await tester.pumpWidget(_app(locale, snapshot));
        await tester.pumpAndSettle();
        expect(find.text(strings.fleet), findsOneWidget);
        expect(
          find.text(
            strings.fleetTitle(
              BattleDetailSide.friend,
              BattleDetailFleetRole.main,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('夕立改二'), findsOneWidget);
        expect(find.text(strings.localize('未知舰船')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
        await tester.pumpAndSettle();
        expect(find.text(strings.localize('第一炮击战')), findsOneWidget);
        expect(find.text(strings.damage(50)), findsOneWidget);
        expect(find.text(strings.critical), findsOneWidget);
        expect(
          find.text(
            '${strings.sideName(BattleDetailSide.enemy)}${strings.damageStatus('moderate')}',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(jsonEncode(snapshot.toJson()), stored);
      },
    );
  }

  testWidgets(
    'changing language redraws an open replay without changing its data',
    (tester) async {
      final stored = jsonEncode(_snapshot.toJson());
      await tester.pumpWidget(_app(const Locale('zh'), _snapshot));
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      expect(find.text('第一炮击战'), findsOneWidget);
      await tester.pumpWidget(_app(const Locale('ja'), _snapshot));
      await tester.pumpAndSettle();
      expect(find.text('第1砲撃戦'), findsOneWidget);
      expect(find.text('第一炮击战'), findsNothing);
      expect(jsonEncode(_snapshot.toJson()), stored);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(Locale locale, BattleDetailSnapshot detail) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: BattleDetailPage(detail: detail, onBack: () {}),
  ),
);

const _snapshot = BattleDetailSnapshot(
  completedAtMillis: 0,
  mapLabel: '1-1',
  nodeLabel: 'A点',
  rank: 'S',
  enemyFleetName: '敌舰队',
  fleets: [
    BattleDetailFleet(
      side: BattleDetailSide.friend,
      role: BattleDetailFleetRole.main,
      ships: [
        BattleDetailShip(
          name: '夕立改二',
          side: BattleDetailSide.friend,
          role: BattleDetailFleetRole.main,
          position: 0,
          initialHp: 30,
          maxHp: 30,
          finalHp: 30,
          damageDealt: 50,
        ),
      ],
    ),
    BattleDetailFleet(
      side: BattleDetailSide.enemy,
      role: BattleDetailFleetRole.main,
      ships: [
        BattleDetailShip(
          name: '未知舰船',
          side: BattleDetailSide.enemy,
          role: BattleDetailFleetRole.main,
          position: 0,
          initialHp: 100,
          maxHp: 100,
          finalHp: 50,
          damageReceived: 50,
        ),
      ],
    ),
  ],
  stages: [
    BattleDetailStage(
      keyName: 'api_hougeki1',
      title: '第一炮击战',
      attacks: [
        BattleDetailAttack(
          attackerSide: BattleDetailSide.friend,
          attackerName: '夕立改二',
          defenderSide: BattleDetailSide.enemy,
          defenderRole: BattleDetailFleetRole.main,
          defenderPosition: 0,
          defenderName: '未知舰船',
          attackType: '主炮连击',
          defenderHpBefore: 100,
          defenderHpAfter: 50,
          hits: [
            BattleDetailHit(
              damage: 50,
              kind: BattleDetailHitKind.critical,
              hpAfter: 50,
            ),
          ],
        ),
      ],
    ),
  ],
);
