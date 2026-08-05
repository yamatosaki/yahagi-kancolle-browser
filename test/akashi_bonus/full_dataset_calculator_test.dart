import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/akashi_bonus/lib/dataset_validator.dart';
import '../../tool/akashi_bonus/lib/models.dart';
import '../../tool/akashi_bonus/lib/name_resolver.dart';
import '../../tool/akashi_bonus/lib/reference_calculator.dart';

void main() {
  final master =
      MasterData.fromJsonFile('test/akashi_bonus/fixtures/master_266.json');
  final (rules, _) =
      DatasetReader.read('assets/data/equipment_fit_bonuses.json');
  // Full master for shipType/class lookups.
  final fullMaster = MasterData.fromJsonFile(
      'tool/wiki_bonus/cache/raw/start2.json');
  final calc = ReferenceCalculator(rules, master: fullMaster);

  bool has41cmKA2(EquipmentPredicate p) => (p.itemIds ?? const []).contains(318);

  CalcResult run(int shipId, int equipId, {int count = 1, int star = 0}) {
    return calc.compute(
      shipId: shipId,
      equipmentCounts: {equipId: count},
      equipmentStars: {equipId: star},
      predicateChecker: has41cmKA2,
    );
  }

  int shipIdOf(String name) {
    final ids = fullMaster.shipIdsByName[name];
    expect(ids, isNotNull, reason: 'master has $name');
    return ids!.first;
  }

  group('full-dataset end-to-end (round 4 sampling)', () {
    test('w330 16inch Mk.I連装砲: Nelson改 +2', () {
      final r = run(shipIdOf('Nelson改'), 330);
      expect(r.bonus.stats['firepower'], 2);
    });
    test('w330: Colorado +1', () {
      expect(run(shipIdOf('Colorado'), 330).bonus.stats['firepower'], 1);
    });
    test('w330: 長門 (unmodified form) +1', () {
      expect(run(shipIdOf('長門'), 330).bonus.stats['firepower'], 1);
    });
    test('w287 三式爆雷投射機(集中配備): 時雨改三 対潜+3', () {
      final r = run(shipIdOf('時雨改三'), 287);
      expect(r.bonus.stats['antiSubmarine'], 3);
    });
    test('w287: 香取 回避+2 対潜+3', () {
      final r = run(shipIdOf('香取'), 287);
      expect(r.bonus.stats['antiSubmarine'], 3);
      expect(r.bonus.stats['evasion'], 2);
    });
    test('w149 四式水中聴音機: 五十鈴改二 回避+3 対潜+1', () {
      final r = run(shipIdOf('五十鈴改二'), 149);
      expect(r.bonus.stats['evasion'], 3);
      expect(r.bonus.stats['antiSubmarine'], 1);
    });
    test('w149: 香取 回避+3 対潜+2 (override)', () {
      final r = run(shipIdOf('香取'), 149);
      expect(r.bonus.stats['evasion'], 3);
      expect(r.bonus.stats['antiSubmarine'], 2);
    });
    test('w290 41cm三連装砲改二: 長門改二 火力+2 回避+2 装甲+1 命中+1 (sim+41cm改二)', () {
      final r = run(shipIdOf('長門改二'), 290);
      expect(r.bonus.stats['firepower'], 2);
      expect(r.bonus.stats['evasion'], 2);
      expect(r.bonus.stats['armor'], 1);
      expect(r.bonus.stats['accuracy'], 1);
    });
    test('w290: 伊勢改二 火力+3 対空+2 回避+1 命中+3 (override)', () {
      final r = run(shipIdOf('伊勢改二'), 290);
      expect(r.bonus.stats['firepower'], 3);
      expect(r.bonus.stats['antiAir'], 2);
      expect(r.bonus.stats['evasion'], 1);
      expect(r.bonus.stats['accuracy'], 3);
    });
    test('w290: 日向改二 火力+3 対空+2 回避+2 命中+3 火力+1 命中+2 (sim+41cm改二)', () {
      final r = run(shipIdOf('日向改二'), 290);
      expect(r.bonus.stats['firepower'], 4);
      expect(r.bonus.stats['antiAir'], 2);
      expect(r.bonus.stats['evasion'], 2);
      expect(r.bonus.stats['accuracy'], 5);
    });
    test('w290: 伊勢改 火力+2 対空+2 命中+1 (override)', () {
      final r = run(shipIdOf('伊勢改'), 290);
      expect(r.bonus.stats['firepower'], 2);
      expect(r.bonus.stats['antiAir'], 2);
      expect(r.bonus.stats['accuracy'], 1);
    });
    test('w464 10cm連装高角砲群(集中配備): 大和改二 対空+5 回避+4', () {
      final r = run(shipIdOf('大和改二'), 464);
      expect(r.bonus.stats['antiAir'], 5);
      expect(r.bonus.stats['evasion'], 4);
    });
    test('w464: 榛名改二乙 対空+5 回避+4', () {
      final r = run(shipIdOf('榛名改二乙'), 464);
      expect(r.bonus.stats['antiAir'], 5);
      expect(r.bonus.stats['evasion'], 4);
    });
    test('w464: 武蔵改二 対空+3 回避+3 (override)', () {
      final r = run(shipIdOf('武蔵改二'), 464);
      expect(r.bonus.stats['antiAir'], 3);
      expect(r.bonus.stats['evasion'], 3);
    });
    test('w464: 金剛 (榛名改二乙/丙除く) negative 対空-2 回避-2 (override)', () {
      final r = run(shipIdOf('金剛'), 464);
      expect(r.bonus.stats['antiAir'], -2);
      expect(r.bonus.stats['evasion'], -2);
    });
    test('w468 38cm四連装砲改 deux: Richelieu 火力+3 命中+1', () {
      final r = run(shipIdOf('Richelieu'), 468);
      expect(r.bonus.stats['firepower'], 3);
      expect(r.bonus.stats['accuracy'], 1);
    });
    test('w470 12.7cm連装砲C型改三: 雪風改二 x1 火力+3 回避+2 命中+2', () {
      final r = run(shipIdOf('雪風改二'), 470, count: 1);
      expect(r.bonus.stats['firepower'], 3);
      expect(r.bonus.stats['evasion'], 2);
      expect(r.bonus.stats['accuracy'], 2);
    });
    test('w470: 陽炎改二 (秋雲除く) ★0 回避+3 (単体2+改修1)', () {
      final r = run(shipIdOf('陽炎改二'), 470);
      expect(r.bonus.stats['firepower'], 3);
      expect(r.bonus.stats['evasion'], 3);
    });
    test('w368 Swordfish: 瑞穂 x1 火力+1 対潜+2 索敵+2 回避+1', () {
      final r = run(shipIdOf('瑞穂'), 368, count: 1);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['antiSubmarine'], 2);
      expect(r.bonus.stats['lineOfSight'], 2);
      expect(r.bonus.stats['evasion'], 1);
    });
    test('w368: Gotland andra x1 火力+6 雷装+2 対潜+3 索敵+4 回避+3', () {
      final r = run(shipIdOf('Gotland andra'), 368, count: 1);
      expect(r.bonus.stats['firepower'], 6);
      expect(r.bonus.stats['torpedo'], 2);
      expect(r.bonus.stats['antiSubmarine'], 3);
      expect(r.bonus.stats['lineOfSight'], 4);
      expect(r.bonus.stats['evasion'], 3);
    });
    test('w368: Gotland andra x2 火力+10 (1つ目+2~4つ目)', () {
      final r = run(shipIdOf('Gotland andra'), 368, count: 2);
      expect(r.bonus.stats['firepower'], 10);
    });
    test('w369 Swordfish熟練: Gotland andra x1 火力+8 回避+6', () {
      final r = run(shipIdOf('Gotland andra'), 369, count: 1);
      expect(r.bonus.stats['firepower'], 8);
      expect(r.bonus.stats['evasion'], 6);
    });
    test('w369: Gotland andra x2 火力+13', () {
      expect(run(shipIdOf('Gotland andra'), 369, count: 2).bonus.stats['firepower'], 13);
    });
    test('w426 305mm/46 連装砲: Conte di Cavour x1 火力+3 回避+1', () {
      final r = run(shipIdOf('Conte di Cavour'), 426, count: 1);
      expect(r.bonus.stats['firepower'], 3);
      expect(r.bonus.stats['evasion'], 1);
    });
    test('w426: Conte di Cavour x2 火力+4 回避+2', () {
      final r = run(shipIdOf('Conte di Cavour'), 426, count: 2);
      expect(r.bonus.stats['firepower'], 4);
      expect(r.bonus.stats['evasion'], 2);
    });
    test('w426: Гангут x1 火力+2 回避+1 (override)', () {
      final r = run(shipIdOf('Гангут'), 426, count: 1);
      expect(r.bonus.stats['firepower'], 2);
      expect(r.bonus.stats['evasion'], 1);
    });
    test('w121 94式高射装置: 秋月改二 火力+1 対空+5 回避+3', () {
      final r = run(shipIdOf('秋月改二'), 121);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['antiAir'], 5);
      expect(r.bonus.stats['evasion'], 3);
    });
    test('w121: 玉波改二 火力+1 回避+1 (override)', () {
      final r = run(shipIdOf('玉波改二'), 121);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['evasion'], 1);
    });
    test('w121: 早波改二 火力+1 回避+1 (override)', () {
      final r = run(shipIdOf('早波改二'), 121);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['evasion'], 1);
    });
    test('w408 装甲艇: 大発駆逐艦 火力+1 索敵+1 回避-5 (override)', () {
      final r = run(shipIdOf('大潮改二'), 408);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['lineOfSight'], 1);
      expect(r.bonus.stats['evasion'], -5);
    });
    test('w408: 朝潮改二 (大発不可) no bonus', () {
      expect(run(shipIdOf('朝潮改二'), 408).bonus.stats, isEmpty);
    });
    test('w555 18cm/57 三連装主砲: Киров 火力+2 (★0-2)', () {
      final r = run(shipIdOf('Киров'), 555);
      expect(r.bonus.stats['firepower'], 2);
    });
    test('w555: Гангут (Киров以外) ★4 火力+2 (star table)', () {
      final r = run(shipIdOf('Гангут'), 555, star: 4);
      expect(r.bonus.stats['firepower'], 2);
    });
    test('w338 烈風改二戊型: 加賀改二護 火力+1 対空+2 回避+3 (override)', () {
      final r = run(shipIdOf('加賀改二護'), 338);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['antiAir'], 2);
      expect(r.bonus.stats['evasion'], 3);
    });
    test('w362 5inch連装両用砲(集中配備): 大淀 対空-1 回避-2 (override)', () {
      final r = run(shipIdOf('大淀'), 362);
      expect(r.bonus.stats['antiAir'], -1);
      expect(r.bonus.stats['evasion'], -2);
    });
    test('w362: 球磨改二 火力-3 対空-2 回避-6 (override)', () {
      final r = run(shipIdOf('球磨改二'), 362);
      expect(r.bonus.stats['firepower'], -3);
      expect(r.bonus.stats['antiAir'], -2);
      expect(r.bonus.stats['evasion'], -6);
    });
    test('w409 武装大発: 神州丸 火力+2 索敵+2 回避+3', () {
      final r = run(shipIdOf('神州丸'), 409);
      expect(r.bonus.stats['firepower'], 2);
      expect(r.bonus.stats['lineOfSight'], 2);
      expect(r.bonus.stats['evasion'], 3);
    });
    test('w194 Laté 298B: Richelieu改 火力+1 索敵+2 回避+2', () {
      final r = run(shipIdOf('Richelieu改'), 194);
      expect(r.bonus.stats['firepower'], 1);
      expect(r.bonus.stats['lineOfSight'], 2);
      expect(r.bonus.stats['evasion'], 2);
    });
  });
}
