/// DOM parsing of an akashi-list.me `/detail/w{id}.html` page.
///
/// Only the identity node (`.name`), the base status table
/// (`.detail-status`), the blue bonus block (`.bonus-contents`) and the
/// target-ship definitions (`.tipbody`) are read. All structure checks that
/// do not match the expected shapes fail loudly via [DetailParseException];
/// nothing is silently dropped.
library;

import 'package:html/dom.dart';

import 'bonus_text_parser.dart';

/// One icon element found inside a bonus block (e.g. `<i class="radar"
/// title="水上電探">`), or an equipment link (`<a data-wid="247">`).
class BonusIcon {
  final String cssClass;
  final String title;
  final int? equipmentId;
  const BonusIcon(this.cssClass, this.title, {this.equipmentId});
}

/// One star-level entry of an `rbonus` table: additions at that star.
class StarAddition {
  final int star; // 1..10
  final List<StatBonusText> additions;
  const StarAddition(this.star, this.additions);
}

/// One count-gated segment: stats that apply to the Nth equipped copy
/// (and every later copy when [end] is null).
class CountSegment {
  final int start;
  final int? end;
  final List<StatBonusText> stats;
  const CountSegment(this.start, this.end, this.stats);
}

/// A parsed bonus block: either the base effect, or a synergy block.
class BonusBlock {
  final bool isSynergy;
  final List<BonusIcon> icons;
  final List<StatBonusText> statBonuses;

  /// Named equipment requirements written as text (`15.2cm三連装砲：火力+2`).
  final List<String> equipmentNames;

  /// Parenthetical-only texts inside a synergy group (`(沖波改二)`) that
  /// restrict the rule to those ships.
  final List<String> onlyShipNames;

  /// Star threshold written as `(★+5)` in a synergy group.
  final int? requirementStarGte;

  /// Stat thresholds written in a synergy group (`命中8以上`).
  final List<String> predicateTexts;

  /// Count-gated segments (`2機目～`, `1つ目`, `2~4つ目`).
  final List<CountSegment> countSegments;

  /// Minimum equipped count required by a requirement (`× 2`).
  final int? requirementMinCount;

  /// Count-gate texts that could not be normalized into the current schema.
  final List<String> countGateTexts;

  /// Improvement threshold written as `★4〜` prefix (1-based).
  final int? starGte;

  /// Per-star *additions* when the source used an `rbonus` table.
  final List<StarAddition> starAdditions;

  const BonusBlock({
    required this.isSynergy,
    this.icons = const [],
    this.statBonuses = const [],
    this.equipmentNames = const [],
    this.onlyShipNames = const [],
    this.requirementStarGte,
    this.predicateTexts = const [],
    this.countSegments = const [],
    this.requirementMinCount,
    this.countGateTexts = const [],
    this.starGte,
    this.starAdditions = const [],
  });

  bool get isEmpty =>
      statBonuses.isEmpty &&
      starGte == null &&
      starAdditions.isEmpty &&
      icons.isEmpty &&
      equipmentNames.isEmpty &&
      onlyShipNames.isEmpty;
}

/// One `.fit` cell: effect blocks + target tokens (+ optional annotation).
class BonusFit {
  final List<BonusBlock> blocks;
  final List<String> targetTokens;
  final String? annotation;
  final String rawHtml;

  const BonusFit({
    required this.blocks,
    required this.targetTokens,
    required this.rawHtml,
    this.annotation,
  });
}

/// One group of the `.tipbody`: label → ship names in page order.
class TipGroup {
  final String label;
  final List<String> shipNames;
  const TipGroup(this.label, this.shipNames);
}

/// Notes extracted from the bonus title (e.g. シナジー重複不可).
class BonusTitleNotes {
  bool countByComma;
  bool synergyNoStack;
  bool repeatable;
  /// 重複不可: single-equipment bonuses apply once (not per slot).
  bool singleNoStack;
  List<BonusIcon> legendIcons;
  BonusTitleNotes({
    this.countByComma = false,
    this.synergyNoStack = false,
    this.repeatable = false,
    this.singleNoStack = false,
    this.legendIcons = const [],
  });
}

/// Base stats of the equipment, excluding the `<r>` remodel display.
class BaseStats {
  final Map<String, int> stats;
  final String rangeLabel;
  const BaseStats(this.stats, this.rangeLabel);
}

/// Everything extracted from one detail page.
class DetailParseResult {
  final int equipmentIdFromUrl;
  final int pageNo;
  final String pageName;
  final BaseStats baseStats;
  final BonusTitleNotes titleNotes;
  final List<BonusFit> fits;
  final List<TipGroup> tipGroups;

  const DetailParseResult({
    required this.equipmentIdFromUrl,
    required this.pageNo,
    required this.pageName,
    required this.baseStats,
    required this.titleNotes,
    required this.fits,
    required this.tipGroups,
  });
}

class DetailParseException implements Exception {
  final String message;
  final int equipmentId;
  DetailParseException(this.message, this.equipmentId);
  @override
  String toString() => 'DetailParseException(w$equipmentId): $message';
}

/// Parses the four target nodes of a detail page.
DetailParseResult parseDetailDocument(Document doc, int equipmentIdFromUrl) {
  final nameNode = doc.querySelector('.name');
  if (nameNode == null) {
    throw DetailParseException('.name node missing', equipmentIdFromUrl);
  }
  final noEl = nameNode.querySelector('.no');
  final wnameEl = nameNode.querySelector('.wname');
  if (noEl == null || wnameEl == null) {
    throw DetailParseException('.name .no or .name .wname missing', equipmentIdFromUrl);
  }
  final noText = noEl.text.trim();
  final noMatch = RegExp(r'^No\.?\s*(\d+)').firstMatch(noText);
  if (noMatch == null) {
    throw DetailParseException('cannot parse page number from "$noText"',
        equipmentIdFromUrl);
  }
  final pageNo = int.parse(noMatch.group(1)!);
  final pageName = wnameEl.text.trim();

  final baseStats = _parseBaseStats(doc.querySelector('.detail-status'), equipmentIdFromUrl);
  final titleNotes = _parseTitleNotes(doc.querySelector('.bonus-contents'));
  final fits = _parseFits(doc.querySelector('.bonus-contents'), equipmentIdFromUrl);
  final tips = _parseTipBody(doc.querySelector('.tipbody'), equipmentIdFromUrl);

  return DetailParseResult(
    equipmentIdFromUrl: equipmentIdFromUrl,
    pageNo: pageNo,
    pageName: pageName,
    baseStats: baseStats,
    titleNotes: titleNotes,
    fits: fits,
    tipGroups: tips,
  );
}

const Map<String, String> _statusLabels = <String, String>{
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

const Map<String, int> _rangeLabels = <String, int>{
  '短': 1,
  '中': 2,
  '長': 3,
  '超長': 4,
};

BaseStats _parseBaseStats(Element? ds, int eqId) {
  final stats = <String, int>{};
  var rangeLabel = '';
  if (ds == null) return const BaseStats(<String, int>{}, '');
  for (final tr in ds.querySelectorAll('tr')) {
    final ths = tr.children.where((e) => e.localName == 'th').toList();
    final tds = tr.children.where((e) => e.localName == 'td').toList();
    for (var i = 0; i < ths.length && i < tds.length; i++) {
      final label = ths[i].text.trim();
      final stat = _statusLabels[label];
      if (stat != null) {
        // Strip <r> remodel display nodes before reading the value.
        for (final r in tds[i].querySelectorAll('r')) {
          r.remove();
        }
        final v = _firstInt(tds[i].text);
        if (v != null) stats[stat] = v;
        continue;
      }
      if (label == '射程') {
        rangeLabel = tds[i].text.trim();
        final rv = _rangeLabels[rangeLabel];
        if (rv != null) stats['range'] = rv;
      }
    }
  }
  return BaseStats(stats, rangeLabel);
}

int? _firstInt(String s) {
  final m = RegExp(r'[+-]?\d+').firstMatch(s.trim());
  return m == null ? null : int.parse(m.group(0)!);
}

BonusTitleNotes _parseTitleNotes(Element? bc) {
  final notes = BonusTitleNotes();
  if (bc == null) return notes;
  final th = bc.querySelector('th.title');
  if (th == null) return notes;
  final text = th.text;
  notes.countByComma = text.contains('カンマ') || text.contains('カンマ区切り');
  notes.synergyNoStack = text.contains('シナジー重複不可');
  notes.repeatable = text.contains('重複可');
  // `重複可` wins over `重複不可`: the latter also appears inside
  // `シナジー重複不可`, which only restricts synergy stacking.
  notes.singleNoStack = !text.contains('重複可') && text.contains('重複不可');
  final icons = <BonusIcon>[];
  for (final i in th.querySelectorAll('i')) {
    icons.add(BonusIcon(i.attributes['class'] ?? '', i.attributes['title'] ?? ''));
  }
  notes.legendIcons = icons;
  return notes;
}

List<BonusFit> _parseFits(Element? bc, int eqId) {
  if (bc == null) return const [];
  final fits = <BonusFit>[];
  for (final td in bc.querySelectorAll('td.fit')) {
    final fit = _parseFit(td, eqId);
    // Skip layout-artifact empty fits (no effect blocks, no targets).
    if (fit.blocks.isEmpty && fit.targetTokens.isEmpty) continue;
    fits.add(fit);
  }
  return fits;
}

/// Ordered walk unit: either text, a requirement (equipment link or icon),
/// or punctuation to drop.
class _WalkUnit {
  final String? text;
  final BonusIcon? icon;
  const _WalkUnit.text(this.text) : icon = null;
  const _WalkUnit.icon(this.icon) : text = null;
}

List<_WalkUnit> _walkUnits(Element node) {
  final out = <_WalkUnit>[];
  _walk(node, out);
  return out;
}

void _walk(Element node, List<_WalkUnit> out) {
  for (final child in node.nodes) {
    if (child is Comment) continue;
    if (child is Text) {
      final t = child.text;
      if (t.trim().isNotEmpty) out.add(_WalkUnit.text(t));
      continue;
    }
    if (child is! Element) continue;
    final e = child;
    switch (e.localName) {
      case 'sn':
        continue; // star tables handled separately
      case 'br':
        out.add(const _WalkUnit.text('\n'));
        continue;
      case 'i':
        out.add(_WalkUnit.icon(
            BonusIcon(e.attributes['class'] ?? '', e.attributes['title'] ?? '')));
        continue;
      case 'a':
        final widM = RegExp(r'^w?(\d+)$').firstMatch(e.attributes['data-wid'] ?? '');
        if (widM != null) {
          out.add(_WalkUnit.icon(BonusIcon(
              'equipmentLink', e.text.trim(), equipmentId: int.parse(widM.group(1)!))));
        } else if (e.text.trim().isNotEmpty) {
          out.add(_WalkUnit.text(e.text.trim()));
        }
        continue;
      default:
        _walk(e, out);
    }
  }
}

const Set<String> _decorText = {
  '＋', '+', '：', ':', '・', '、', '(', ')', '（', '）', ',', '，', '/', 'or',
};

/// Groups ordered walk units: an icon/requirement starts a new group
/// (consecutive icons merge); texts accumulate into the current group; pure
/// punctuation is dropped.
List<_WalkGroup> _groupUnits(List<_WalkUnit> units) {
  final groups = <_WalkGroup>[];
  for (final u in units) {
    if (u.icon != null) {
      if (groups.isNotEmpty &&
          groups.last.icon != null &&
          groups.last.texts.isEmpty) {
        // Merge consecutive requirement icons (e.g. カ号・オ号改(改二)).
        continue;
      }
      groups.add(_WalkGroup(icon: u.icon));
      continue;
    }
    final t = u.text!.trim();
    if (t.isEmpty) continue;
    // Strip edge decoration (`, ＋`, `：` etc.) that HTML text nodes may
    // carry alongside separators.
    final cleaned = t.replaceAll(
        RegExp(r'^[＋+,，：:・、/ ]+|[＋+,，：:・、/ ]+$'), '');
    if (cleaned.isEmpty) continue;
    if (_decorText.contains(cleaned)) continue;
    if (groups.isEmpty) {
      groups.add(_WalkGroup());
    }
    groups.last.texts.add(cleaned);
  }
  return groups;
}

class _WalkGroup {
  BonusIcon? icon;
  final List<String> texts = [];
  _WalkGroup({this.icon});
}

List<StarAddition> _starAdditions(Element block, int eqId) {
  final out = <StarAddition>[];
  final rbonus = block.querySelector('sn.rbonus');
  if (rbonus == null) return out;
  final rs = rbonus.querySelectorAll('r');
  for (var i = 0; i < rs.length; i++) {
    final r = rs[i];
    final additions = <StatBonusText>[];
    for (final s in r.querySelectorAll('sunit')) {
      final t = s.text.trim();
      if (t.isEmpty || t == 'なし') continue;
      final parsed = parseBonusText(t);
      if (parsed is BonusTextParsed) {
        additions.add(parsed.bonus);
      } else {
        throw DetailParseException(
            'unparseable star bonus text "$t"', eqId);
      }
    }
    out.add(StarAddition(i + 1, additions));
  }
  return out;
}

BonusFit _parseFit(Element td, int eqId) {
  // Effect blocks may be wrapped in <span> or <div> depending on the page;
  // some pages put <sunit> directly inside the fit cell.
  final children = td.children
      .where((e) =>
          e.localName == 'span' ||
          e.localName == 'div' ||
          e.localName == 'sunit')
      .toList();
  if (children.isEmpty) {
    // Layout artifact: an empty fit cell contributes nothing.
    return const BonusFit(blocks: [], targetTokens: [], rawHtml: '');
  }
  final blocks = <BonusBlock>[];
  final targets = <String>[];
  String? annotation;

  for (final child in children) {
    if (child.localName == 'span' &&
        child.children.isEmpty &&
        child.text.trim().isEmpty) {
      continue;
    }
    final childText = child.text.trim();
    if (RegExp(r'^ボーナス艦\d+$').hasMatch(childText)) {
      if (annotation != null) {
        throw DetailParseException('multiple annotation spans in one fit', eqId);
      }
      annotation = childText;
      continue;
    }
    if (child.localName == 'span') {
      final divs = child.children
          .where((e) => e.localName == 'div')
          .toList();
      if (divs.isNotEmpty) {
        for (var d = 0; d < divs.length; d++) {
          _parseBlock(divs[d], eqId, blocks, targets);
        }
        // Some pages mix divs and direct sunits in one span; treat the
        // direct sunits as one additional block (divs excluded).
        final direct =
            child.children.where((e) => e.localName == 'sunit').toList();
        if (direct.isNotEmpty) {
          final clone = child.clone(true);
          for (final d in clone.children
              .where((e) => e.localName == 'div')
              .toList()) {
            d.remove();
          }
          _parseBlock(clone, eqId, blocks, targets);
        }
        continue;
      }
    }
    _parseBlock(child, eqId, blocks, targets);
  }

  if (blocks.isEmpty) {
    throw DetailParseException('fit has no effect blocks', eqId);
  }
  if (targets.isEmpty && annotation == null) {
    throw DetailParseException('fit has no target span', eqId);
  }
  if (targets.isEmpty) {
    throw DetailParseException('fit targets empty', eqId);
  }
  return BonusFit(
    blocks: blocks,
    targetTokens: targets,
    rawHtml: td.outerHtml,
    annotation: annotation,
  );
}

void _parseBlock(Element node, int eqId, List<BonusBlock> blocks,
    List<String> targets) {
  final additions = _starAdditions(node, eqId);
  final blocksBefore = blocks.length;

  int? starGte;
  final groups = _groupUnits(_walkUnits(node));
  final parsedGroups = <_WalkGroup>[];
  for (final g in groups) {
    final texts = <String>[];
    for (final t in g.texts) {
      final starM = RegExp(r'^★\s*(\d+)\s*[〜~～]').firstMatch(t);
      if (starM != null) {
        starGte = int.parse(starM.group(1)!);
        continue;
      }
      texts.add(t);
    }
    if (texts.isEmpty && g.icon == null) continue;
    parsedGroups.add(_WalkGroup(icon: g.icon)..texts.addAll(texts));
  }

  if (parsedGroups.isEmpty) {
    if (additions.isNotEmpty) {
      blocks.add(BonusBlock(
        isSynergy: false,
        starAdditions: additions,
        starGte: starGte,
      ));
      return;
    }
    final snippet = node.outerHtml.length < 300
        ? node.outerHtml
        : node.outerHtml.substring(0, 300);
    throw DetailParseException('unclassifiable span text: $snippet', eqId);
  }

  for (final g in parsedGroups) {
    if (g.icon != null) {
      // Synergy group: requirement icon + stat texts. Parenthetical-only
      // texts restrict the rule to those ships or set a star threshold.
      final parsed = _parseGroupTexts(g.texts, eqId, isSynergy: true);
      blocks.add(BonusBlock(
        isSynergy: true,
        icons: [g.icon!],
        statBonuses: parsed.bonuses,
        onlyShipNames: parsed.onlyShips,
        requirementStarGte: parsed.requirementStarGte,
        predicateTexts: parsed.predicateTexts,
        countSegments: parsed.countSegments,
        requirementMinCount: parsed.requirementMinCount,
        countGateTexts: parsed.countGates,
        starAdditions: additions,
      ));
      continue;
    }
    final baseTexts = g.texts;
    final hasCountGate = baseTexts.any((t) => _countGatePattern.hasMatch(t));
    if ((baseTexts.isNotEmpty && !_looksLikeTarget(baseTexts)) ||
        hasCountGate) {
      // Effect group: stats possibly with named-equipment text.
      final parsed = _parseGroupTexts(baseTexts, eqId, isSynergy: false);
      blocks.add(BonusBlock(
        isSynergy: false,
        statBonuses: parsed.bonuses,
        equipmentNames: parsed.equipmentNames,
        predicateTexts: parsed.predicateTexts,
        countSegments: parsed.countSegments,
        requirementMinCount: parsed.requirementMinCount,
        countGateTexts: parsed.countGates,
        starGte: starGte,
        starAdditions: additions,
      ));
      continue;
    }
    // Target group. Continuation form words (`赤城改・改二` → 赤城改二,
    // `龍鳳改二戊・改二` → 龍鳳改二) merge into the preceding token.
    for (final t in baseTexts) {
      for (final tok in splitTargetTokens(t)) {
        final formM = RegExp(r'^(改|改二|改三|改四|特|丁|甲|乙|丙|戊|戦|護)$')
            .firstMatch(tok);
        if (formM != null && targets.isNotEmpty) {
          final last = targets.removeLast();
          final form = formM.group(1)!;
          final base = last.replaceFirst(
              RegExp(r'(改|特|丁|甲|乙|丙|戊|戦|護)$'), '');
          // A branch-suffix form (龍鳳改二戊・改二) refers back to the
          // base remodel; a plain 改 suffix upgrades it (赤城改・改二).
          final tail = last[last.length - 1];
          final merged = (tail == '改' || tail == '護')
              ? '$base$form'
              : base;
          targets.add(merged);
          continue;
        }
        targets.add(tok);
      }
    }
  }
  // The span contributed nothing: no effect block, no target tokens.
  if (blocks.length == blocksBefore && targets.isEmpty) {
    throw DetailParseException('unclassifiable span text', eqId);
  }
}
bool _looksLikeTarget(List<String> texts) {
  for (final t in texts) {
    if (RegExp(r'^(火力|雷装|対空|回避|命中|装甲|対潜|索敵|爆装|射程)').hasMatch(t)) {
      return false;
    }
  }
  return true;
}

List<TipGroup> _parseTipBody(Element? tip, int eqId) {
  if (tip == null) return const [];
  final groups = <TipGroup>[];
  for (final table in tip.querySelectorAll('table')) {
    final rows = table.querySelectorAll('tr');
    for (var r = 0; r + 1 < rows.length; r++) {
      final th = rows[r].children
          .where((e) => e.localName == 'th')
          .toList()
          .firstOrNull;
      if (th == null) continue;
      final label = th.text.trim();
      if (label.isEmpty) continue;
      final names = <String>[];
      final nextTd = rows[r + 1].children
          .where((e) => e.localName == 'td')
          .toList()
          .firstOrNull;
      if (nextTd != null) {
        for (final span in nextTd.querySelectorAll('span')) {
          final t = span.text.trim();
          if (t.isNotEmpty) names.add(t);
        }
      }
      if (names.isNotEmpty) groups.add(TipGroup(label, names));
    }
  }
  return groups;
}

class _GroupTextParse {
  final List<StatBonusText> bonuses;
  final List<String> equipmentNames;
  final List<String> onlyShips;
  final int? requirementStarGte;
  final List<String> predicateTexts;
  final List<CountSegment> countSegments;
  final int? requirementMinCount;
  final List<String> countGates;
  const _GroupTextParse(this.bonuses, this.equipmentNames, this.onlyShips,
      this.requirementStarGte, this.predicateTexts, this.countSegments,
      this.requirementMinCount, this.countGates);
}

final RegExp _parenOnlyPattern = RegExp(r'^\((.+?)\)[:：]?$');
final RegExp _commaContinuationPattern =
    RegExp(r'^,?([+-]?\d+(?:,[+-]?\d+)*)$');
final RegExp _countGatePattern = RegExp(
    r'^\d+[機機]?目|^\d+[~〜～~]?\d*つ目|デメリット|'
    r'×\s*\d+|^\d+回');

/// Stat threshold written inside a synergy group (`命中8以上`).
final RegExp _thresholdPattern = RegExp(
    r'^(命中|索敵|対空|火力|回避|装甲|雷装|対潜|爆装)\s*\d+以上$');

/// Parses the stat texts of one group, handling parenthetical-only ship
/// restrictions, comma continuations, count gates and named equipment.
_GroupTextParse _parseGroupTexts(List<String> texts, int eqId,
    {required bool isSynergy}) {
  final bonuses = <StatBonusText>[];
  final equipmentNames = <String>[];
  final onlyShips = <String>[];
  int? requirementStarGte;
  final predicateTexts = <String>[];
  final countSegments = <CountSegment>[];
  final currentSegments = <CountSegment>[];
  int? requirementMinCount;
  final countGates = <String>[];

  List<StatBonusText> segTarget() =>
      currentSegments.isEmpty ? bonuses : currentSegments.last.stats;

  for (final raw in texts) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    final parenOnly = _parenOnlyPattern.firstMatch(t);
    if (parenOnly != null) {
      final inner = parenOnly.group(1)!.trim();
      final starM = RegExp(r'^★\s*[+＋]?\s*(\d+)').firstMatch(inner);
      if (starM != null) {
        requirementStarGte = int.parse(starM.group(1)!);
      } else {
        onlyShips.add(inner);
      }
      continue;
    }
    if (_thresholdPattern.hasMatch(t)) {
      predicateTexts.add(t);
      continue;
    }
    // Count-gated segments: `2機目～` / `1機目：` / `1つ目:` / `2~4つ目:`.
    final segM = RegExp(
            r'^(\d+)[機機]?目(?:から)?[～~〜]?[:：]?$|^(\d+)つ目[:：]?$|'
            r'^(\d+)[~〜～](\d+)つ目[:：]?$')
        .firstMatch(t);
    if (segM != null) {
      final segStart =
          int.parse(segM.group(1) ?? segM.group(2) ?? segM.group(3)!);
      final segEnd = segM.group(4) != null
          ? int.parse(segM.group(4)!)
          : (segM.group(1) != null ? null : segStart);
      currentSegments.add(CountSegment(segStart, segEnd, []));
      continue;
    }
    // Requirement multiplicity: `× 2` (possibly with bracket decoration).
    final multM = RegExp(r'^[()（）、]?\s*×\s*(\d+)$').firstMatch(t);
    if (multM != null) {
      requirementMinCount = int.parse(multM.group(1)!);
      continue;
    }
    if (_countGatePattern.hasMatch(t)) {
      countGates.add(t);
      continue;
    }
    final commaM = _commaContinuationPattern.firstMatch(t);
    if (commaM != null) {
      if (bonuses.isEmpty) {
        countGates.add(t);
        continue;
      }
      final last = bonuses.removeLast();
      final extra = commaM
          .group(1)!
          .split(',')
          .map((s) => int.parse(s))
          .toList();
      bonuses.add(StatBonusText(
        stat: last.stat,
        increments: [...last.increments, ...extra],
        condition: last.condition,
        rawText: '${last.rawText},${commaM.group(1)}',
      ));
      continue;
    }
    final p = parseBonusText(t);
    if (p is BonusTextParsed) {
      segTarget().add(p.bonus);
      continue;
    }
    // `＋15.2cm三連装砲：火力+2命中+1` → named equipment + stats.
    final named = RegExp(r'^[＋+]?\s*(.+?)[:：](.+)$').firstMatch(t);
    if (named != null) {
      final name = named.group(1)!.trim();
      final stats = named.group(2)!;
      if (name.isNotEmpty &&
          !RegExp(r'^(火力|雷装|対空|回避|命中)').hasMatch(name)) {
        final statsParsed = <StatBonusText>[];
        var ok = true;
        for (final seg in stats
            .split(RegExp(r'(?=[火力雷装対空回避命中装甲対潜索敵爆装])'))) {
          final sp = parseBonusText(seg);
          if (sp is BonusTextParsed) {
            statsParsed.add(sp.bonus);
          } else {
            ok = false;
            break;
          }
        }
        if (ok && statsParsed.isNotEmpty) {
          equipmentNames.add(name);
          segTarget().addAll(statsParsed);
          continue;
        }
      }
    }
    throw DetailParseException(
        'unparseable ${isSynergy ? 'synergy' : 'bonus'} text "$t"', eqId);
  }
  countSegments.addAll(currentSegments);
  return _GroupTextParse(bonuses, equipmentNames, onlyShips,
      requirementStarGte, predicateTexts, countSegments, requirementMinCount,
      countGates);
}
