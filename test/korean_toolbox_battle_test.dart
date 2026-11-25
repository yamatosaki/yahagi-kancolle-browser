import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_strings.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_rules.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_enemy_details.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_enemy_details_strings.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_query_strings.dart';

void main() {
  const ko = Locale('ko');
  const battle = BattleDetailStrings.forLocale(ko);
  const composition = CompositionImageStrings(ko);
  const map = SortieMapQueryStrings(ko);

  test(
    'morale values and proficiency exclusion describe the actual metrics',
    () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final hant = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(zh.averageCondition, '最低士气');
      expect(zh.avgCondition, '最低士气');
      expect(zh.condition, '士气');
      expect(zh.fatigueValue(49), '士气 49');
      expect(hant.averageCondition, '最低士氣');
      expect(hant.fatigueValue(49), '士氣 49');
      expect(ja.averageCondition, '最低コンディション');
      expect(ja.fatigueValue(49), 'コンディション 49');
      expect(zh.withoutBonus, '不含熟练度加成');
      expect(hant.withoutBonus, '不含熟練度加成');
      expect(ja.withoutBonus, '熟練度補正なし');
      expect(ja.noAdditionalStats, '装備ステータスなし');
      expect(ja.landBaseRange, '行動半径');
      expect(zh.noCookieReadDesc, contains('请求参数'));
      expect(hant.noCookieReadDesc, contains('請求參數'));
      expect(ja.noCookieReadDesc, contains('リクエスト情報'));
    },
  );

  test('Korean battle labels include generated wrappers and damage values', () {
    expect(battle.title, '전투 상세');
    expect(battle.localize('第一炮击战'), '제1포격전');
    expect(battle.localize('基地航空队 3'), '기지항공대 3');
    expect(battle.localize('我方主力（单纵阵）'), '아군 주력（단종진）');
    expect(battle.localize('敌航空战'), '적 항공전');
    expect(battle.localize('友军·夕立改二'), '우군·夕立改二');
    expect(battle.localize('Z1点'), 'Z1 지점');
    expect(battle.hpChange(30, 10), '내구 30 → 10');
    expect(battle.damageStatus('heavy'), '대파');
    expect(battle.sideAttack(BattleDetailSide.friend), '아군 공격');
    expect(battle.mapNode(12), '지점 12');
    expect(battle.mapPartial, contains('항적'));
    for (final raw in ['夕立改二', '深海棲艦', '大和改二重', '46cm三連装砲', '我的编队']) {
      expect(battle.localize(raw), raw);
    }
  });

  test(
    'all generated POI battle attack labels have Korean UI translations',
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
          100,
          101,
          102,
          103,
          104,
          105,
          106,
          200,
          300,
          301,
          302,
          400,
          401,
          1000,
        ]) {
          final raw = poiAttackTypeLabel(type, isNight: night);
          if (raw == 'Nelson Touch') continue;
          expect(
            battle.localize(raw),
            matches(RegExp('[가-힣]')),
            reason: '$raw type=$type night=$night',
          );
        }
      }
    },
  );

  test('Korean composition UI keeps canonical map and difficulty names', () {
    expect(composition.title, '편성 기록');
    expect(composition.fleet(2), '제2함대');
    expect(composition.range(7), '행동 반경 7');
    expect(composition.fleetForms, contains('수송호위부대'));
    expect(composition.normalArea(2), '南西諸島海域');
    expect(compositionDifficultyCodes, ['甲', '乙', '丙', '丁']);
    expect(
      const CompositionImageStrings(Locale('zh')).fleetForms,
      contains('输送护卫部队'),
    );
    expect(
      const CompositionImageStrings(Locale('zh', 'TW')).fleetForms,
      contains('輸送護衛部隊'),
    );
  });

  test(
    'Korean map UI uses Japanese enemy names and leaves source data alone',
    () {
      const ship = EnemyShipEntry(id: 1, nameJa: '駆逐イ級', nameZh: '驱逐I级');
      expect(map.title, '해역 조회');
      expect(map.fleetNumber(3), '적 제3함대');
      expect(map.configuration(2), '편성 2');
      expect(map.nodeKind('night'), '야전');
      expect(map.enemyShipName(ship), '駆逐イ級');
      expect(map.sourceDetail('燃料 100'), '燃料 100');
      expect(map.sourceDetail('来自 kcwiki 的原始资料'), '来自 kcwiki 的原始资料');
      expect(map.sourceDetail(null), isNull);
      expect(
        const SortieMapQueryStrings(Locale('ja')).sourceDetail('中文备注'),
        isNull,
      );
      expect(ship.nameZh, '驱逐I级');
      expect(
        const SortieMapQueryStrings(Locale('zh')).enemyShipName(ship),
        '驱逐I级',
      );
    },
  );

  testWidgets('Korean calculator and enemy detail display localized UI', (
    tester,
  ) async {
    late ExpCalcStrings exp;
    late EnemyDetailsStrings enemy;
    await tester.pumpWidget(
      Localizations(
        locale: ko,
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            exp = ExpCalcStrings(context);
            enemy = EnemyDetailsStrings.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(exp.target, '함선과 목표');
    expect(exp.coverage(2, 5), '5개 편성 중 2개 확인');
    expect(exp.equalWeight, contains('최종 형태'));
    expect(enemy.preciseConfiguration, '능력치 및 장비 일치');
    expect(enemy.antiSub, '대잠');
    expect(enemy.hp, 'HP');
    expect(enemyEquipmentTypeIconIds['艦上戦闘機'], 6);
    expect(enemy.speedValue('高速'), '고속');
    expect(enemy.speedValue('低速'), '저속');
    expect(enemy.speedValue('陸上'), '지상');
    expect(enemy.speedValue('なし'), '없음');
    expect(enemy.speedValue('新しい速力'), '新しい速力');
    expect(enemy.rangeValue('超短'), '초단');
    expect(enemy.rangeValue('短'), '단');
    expect(enemy.rangeValue('中'), '중');
    expect(enemy.rangeValue('長'), '장');
    expect(enemy.rangeValue('超長'), '초장');
    expect(enemy.rangeValue('超長+'), '초장+');
    expect(enemy.rangeValue('?'), '?');
    expect(enemy.rangeValue('新しい射程'), '新しい射程');
    expect(enemy.rangeValue(null), '—');
  });

  testWidgets(
    'Korean enemy dialog translates attributes and preserves game names',
    (tester) async {
      const entry = EnemyShipEntry(id: 1501, nameJa: '駆逐イ級', nameZh: '驱逐I级');
      final rawCatalog = jsonEncode({
        'schemaVersion': 1,
        'dataVersion': 'test',
        'revision': 1,
        'publishedAt': '2026-10-18T00:00:00Z',
        'source': 'test',
        'quality': <String, Object?>{},
        'aliases': {'1501|駆逐イ級': 'test-enemy'},
        'ships': [
          {
            'key': 'test-enemy',
            'id': 1501,
            'name': '駆逐イ級',
            'hp': 20,
            'speed': '高速',
            'range': '短',
            'equipment': [
              {'slot': 1, 'name': '5inch単装砲', 'type': '小口径主砲', 'matched': true},
            ],
          },
        ],
      });
      final catalog = EnemyCatalogData.fromJsonString(rawCatalog);
      await tester.pumpWidget(
        MaterialApp(
          locale: ko,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSortieEnemyDetails(
                  context,
                  entry: entry,
                  state: GameState.empty,
                  catalog: catalog,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('속력'), findsOneWidget);
      expect(find.text('고속'), findsOneWidget);
      expect(find.text('사거리'), findsOneWidget);
      expect(find.text('단'), findsOneWidget);
      expect(find.text('駆逐イ級'), findsOneWidget);
      expect(find.text('5inch単装砲'), findsOneWidget);
      expect(catalog.rawJson, rawCatalog);
      expect(tester.takeException(), isNull);
    },
  );
}
