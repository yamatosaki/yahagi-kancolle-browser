import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../tool/akashi_bonus/lib/detail_parser.dart';

Document fixtureDoc(String name) =>
    html_parser.parse(File('test/akashi_bonus/fixtures/$name').readAsStringSync());

void main() {
  group('parseDetailDocument', () {
    test('parses w266 identity, base stats, fits and tipbody', () {
      final r = parseDetailDocument(fixtureDoc('detail_w266.html'), 266);
      expect(r.equipmentIdFromUrl, 266);
      expect(r.pageNo, 266);
      expect(r.pageName, '12.7cm連装砲C型改二');
      expect(r.baseStats.stats['firepower'], 3);
      expect(r.baseStats.stats['antiAir'], 2);
      expect(r.baseStats.stats['accuracy'], 1);
      expect(r.baseStats.stats['armor'], 1);
      expect(r.titleNotes.countByComma, isTrue);
      expect(r.titleNotes.synergyNoStack, isTrue);
      expect(r.titleNotes.repeatable, isTrue);
      expect(r.fits, hasLength(4));
      expect(r.tipGroups.map((g) => g.label), containsAll(['陽炎型改二', '陽炎型', '白露型', '朝潮型']));
      final g1 = r.tipGroups.firstWhere((g) => g.label == '陽炎型改二');
      expect(g1.shipNames, containsAll(['雪風改二', '陽炎改二', '天津風改二']));
      expect(g1.shipNames, hasLength(8));
    });

    test('fit 1 has base block, synergy block and target', () {
      final r = parseDetailDocument(fixtureDoc('detail_w266.html'), 266);
      final fit = r.fits[0];
      expect(fit.targetTokens, ['陽炎型改二', '雪風改二']);
      expect(fit.blocks, hasLength(2));
      final base = fit.blocks[0];
      expect(base.isSynergy, isFalse);
      expect(base.statBonuses.map((b) => b.rawText), ['火力+2,+3,+1', '回避+1(雪風改二のみ)']);
      final syn = fit.blocks[1];
      expect(syn.isSynergy, isTrue);
      expect(syn.icons.single.title, '水上電探');
      expect(syn.statBonuses.map((b) => b.rawText), ['火力+2', '雷装+3', '回避+1']);
    });

    test('w330 style: spans without sm1 class, no synergy', () {
      final html = '<html><body><div class="name jpfont"><span class="no">No.330 </span>'
          '<span class="wname">16inch Mk.I連装砲</span></div>'
          '<div class="detail-row bonus-contents"><table><tbody><tr>'
          '<th class="title" colspan="4">装備ボーナス<span class="font70">(重複可)</span></th>'
          '</tr></tbody></table><table class="infotip"><tbody><tr class="fitting">'
          '<td class="fit"><span><sunit>火力+2</sunit></span>'
          '<span>Nelson改・長門型改二</span></td>'
          '</tr></tbody></table></div></body></html>';
      final r = parseDetailDocument(html_parser.parse(html), 330);
      expect(r.fits, hasLength(1));
      final fit = r.fits.single;
      expect(fit.blocks, hasLength(1));
      expect(fit.targetTokens, ['Nelson改', '長門型改二']);
    });

    test('w122 style: divs with rstar and icons inside span', () {
      final html = '<html><body><div class="name jpfont"><span class="no">No.122 </span>'
          '<span class="wname">10cm連装高角砲＋高射装置</span></div>'
          '<div class="detail-row bonus-contents"><table><tbody><tr>'
          '<th class="title" colspan="4">装備ボーナス<span class="font70">(重複可、シナジー重複不可 '
          '<i class="radar sm" title="水上電探"></i>: 水上電探 <i class="radar-aa sm" title="対空電探"></i>: 対空電探)</span></th>'
          '</tr></tbody></table><table class="infotip"><tbody><tr class="fitting">'
          '<td class="fit"><span class="sm2"><div><sunit class="rstar">★4～</sunit><br>'
          '<sunit>火力+5</sunit><sunit>対空+3</sunit></div>'
          '<div>＋<i class="radar sm" title="水上電探"></i><sunit>火力+4</sunit></div></span>'
          '<span class="sm2"><sunit>ボーナス艦1</sunit></span>'
          '<span class="sm1"><sunit>吹雪改三</sunit></span></td>'
          '</tr></tbody></table></div></body></html>';
      final r = parseDetailDocument(html_parser.parse(html), 122);
      expect(r.titleNotes.synergyNoStack, isTrue);
      final fit = r.fits.single;
      expect(fit.annotation, 'ボーナス艦1');
      expect(fit.blocks, hasLength(2));
      expect(fit.blocks[0].starGte, 4);
      expect(fit.blocks[0].statBonuses.map((b) => b.rawText), ['火力+5', '対空+3']);
      expect(fit.blocks[1].isSynergy, isTrue);
      expect(fit.blocks[1].icons.single.title, '水上電探');
    });

    test('rbonus star table is captured', () {
      final html = '<html><body><div class="name jpfont"><span class="no">No.999 </span>'
          '<span class="wname">rbonus装備</span></div>'
          '<div class="detail-row bonus-contents"><table><tbody><tr>'
          '<th class="title" colspan="4">装備ボーナス<span class="font70">(重複可)</span></th>'
          '</tr></tbody></table><table class="infotip"><tbody><tr class="fitting">'
          '<td class="fit"><span class="sm2"><div><sunit>火力+2<sn class="rbonus"><r></r><r></r><r></r>'
          '<r></r><r></r><r></r><r></r><r></r><r></r><r><sunit>火力+1</sunit></r></sn></sunit></div></span>'
          '<span class="sm1"><sunit>秋月型改二</sunit></span></td>'
          '</tr></tbody></table></div></body></html>';
      final r = parseDetailDocument(html_parser.parse(html), 999);
      final block = r.fits.single.blocks.single;
      expect(block.starAdditions, hasLength(10));
      expect(block.starAdditions[9].star, 10);
      expect(block.starAdditions[9].additions.single.rawText, '火力+1');
      expect(block.starAdditions[0].additions, isEmpty);
    });

    test('base stats ignore <r> remodel values', () {
      final html = '<html><body><div class="name jpfont"><span class="no">No.1 </span>'
          '<span class="wname">装備</span></div>'
          '<div class="detail-status"><table><tbody><tr><th>火力</th>'
          '<td>+3<span class="fire"><r>+1</r><r>+1.4</r><r>+2</r><r>+3</r></span></td><th>射程</th><td>短</td></tr>'
          '</tbody></table></div></body></html>';
      final r = parseDetailDocument(html_parser.parse(html), 1);
      expect(r.baseStats.stats['firepower'], 3);
      expect(r.baseStats.stats['range'], 1);
      expect(r.baseStats.rangeLabel, '短');
    });

    test('identity mismatch is detected via pageNo', () {
      final html = '<html><body><div class="name jpfont"><span class="no">No.999 </span>'
          '<span class="wname">装備</span></div></body></html>';
      final r = parseDetailDocument(html_parser.parse(html), 1);
      expect(r.pageNo, 999);
    });

    test('missing name throws', () {
      expect(() => parseDetailDocument(html_parser.parse('<html><body></body></html>'), 1),
          throwsA(isA<DetailParseException>()));
    });

    test('malformed fit text throws', () {
      expect(() => parseDetailDocument(fixtureDoc('malformed_fit.html'), 306),
          throwsA(isA<DetailParseException>()));
    });

    test('no bonus contents yields empty fits (no_bonus)', () {
      final r = parseDetailDocument(fixtureDoc('missing_bonus_contents.html'), 308);
      expect(r.fits, isEmpty);
      expect(r.baseStats.stats['firepower'], 3);
    });
  });
}
