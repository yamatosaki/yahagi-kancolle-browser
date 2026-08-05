import 'package:flutter_test/flutter_test.dart';

import '../../tool/akashi_bonus/lib/bonus_text_parser.dart';

void main() {
  group('parseBonusText', () {
    test('single value', () {
      final r = parseBonusText('火力+2');
      expect(r, isA<BonusTextParsed>());
      final b = (r as BonusTextParsed).bonus;
      expect(b.stat, 'firepower');
      expect(b.increments, [2]);
      expect(b.isCountSequence, isFalse);
      expect(b.condition.isEmpty, isTrue);
    });

    test('negative value', () {
      final r = parseBonusText('回避-1');
      final b = (r as BonusTextParsed).bonus;
      expect(b.stat, 'evasion');
      expect(b.increments, [-1]);
    });

    test('comma increments', () {
      final r = parseBonusText('火力+2,+3,+1');
      final b = (r as BonusTextParsed).bonus;
      expect(b.stat, 'firepower');
      expect(b.increments, [2, 3, 1]);
      expect(b.isCountSequence, isTrue);
    });

    test('all stat labels map', () {
      const cases = {
        '火力': 'firepower',
        '雷装': 'torpedo',
        '対空': 'antiAir',
        '回避': 'evasion',
        '命中': 'accuracy',
        '装甲': 'armor',
        '対潜': 'antiSubmarine',
        '索敵': 'lineOfSight',
        '爆装': 'bombing',
      };
      cases.forEach((label, stat) {
        final r = parseBonusText('$label+1');
        expect((r as BonusTextParsed).bonus.stat, stat, reason: label);
      });
    });

    test('のみ condition', () {
      final r = parseBonusText('回避+1(雪風改二のみ)');
      final b = (r as BonusTextParsed).bonus;
      expect(b.condition.onlyShipNames, ['雪風改二']);
      expect(b.condition.raw, '(雪風改二のみ)');
    });

    test('を除く condition', () {
      final r = parseBonusText('火力+1(時雨改二を除く)');
      final b = (r as BonusTextParsed).bonus;
      expect(b.condition.excludeShipNames, ['時雨改二']);
    });

    test('star condition', () {
      final r = parseBonusText('火力+1(★+4以上)');
      final b = (r as BonusTextParsed).bonus;
      expect(b.condition.minImprovement, 4);
    });

    test('star exact', () {
      final r = parseBonusText('火力+1(★6)');
      final b = (r as BonusTextParsed).bonus;
      expect(b.condition.minImprovement, 6);
      expect(b.condition.maxImprovement, 6);
    });

    test('multiple only ships', () {
      final r = parseBonusText('回避+1(雪風改二のみ・丹陽のみ)');
      final b = (r as BonusTextParsed).bonus;
      expect(b.condition.onlyShipNames, ['雪風改二', '丹陽']);
    });

    test('leading plus before stat (icon position)', () {
      final r = parseBonusText('+対空+4');
      final b = (r as BonusTextParsed).bonus;
      expect(b.stat, 'antiAir');
      expect(b.increments, [4]);
    });

    test('unknown text is unresolved', () {
      final r = parseBonusText('謎のテキスト?改修??');
      expect(r, isA<BonusTextUnresolved>());
      expect((r as BonusTextUnresolved).text, '謎のテキスト?改修??');
    });

    test('unknown condition is unresolved', () {
      final r = parseBonusText('火力+1(第2スロット時)');
      expect(r, isA<BonusTextUnresolved>());
    });

    test('のみ with a non-ship name still parses (fails later at resolver)', () {
      final r = parseBonusText('火力+1(第1スロットのみ)');
      final b = (r as BonusTextParsed).bonus;
      expect(b.condition.onlyShipNames, ['第1スロット']);
    });

    test('empty text is unresolved', () {
      expect(parseBonusText(''), isA<BonusTextUnresolved>());
    });
  });

  group('splitTargetTokens', () {
    test('separators', () {
      expect(splitTargetTokens('陽炎型改二・雪風改二'), ['陽炎型改二', '雪風改二']);
      expect(splitTargetTokens('白露型・朝潮型'), ['白露型', '朝潮型']);
      expect(splitTargetTokens('玉波改二・藤波改二\n浜波改二・早波改二'),
          ['玉波改二', '藤波改二', '浜波改二', '早波改二']);
    });
  });
}
