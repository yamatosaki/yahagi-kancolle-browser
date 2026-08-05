/// Parses the 対象艦 cell of a bonus table into a structured, ID-neutral
/// [ShipGroupSpec]. Name/ID resolution happens later in [NameResolver];
/// this module only recognizes the *shapes* the wiki uses and hard-fails
/// (returns [ShipGroupUnresolved]) on anything unrecognized.
library;

import 'models.dart';
import 'table_expander.dart';

/// Result of parsing a 対象 cell.
sealed class ShipGroupParseResult {
  const ShipGroupParseResult();
}

class ShipGroupSpec extends ShipGroupParseResult {
  /// Ship page names (link titles) explicitly listed.
  final List<String> shipNames;

  /// Class anchors: e.g. `白露` for `白露型` (resolver maps via ctype).
  final List<String> classAnchors;

  /// Ship-type names such as 駆逐艦 (resolver maps via api_mst_stype).
  final List<String> shipTypeNames;

  /// Nationality terms such as アメリカ艦 (resolver maps via curated map).
  final List<String> nationalityTerms;

  /// Glossary terms such as 特型 (resolver maps via curated glossary).
  final List<String> glossaryTerms;

  /// Ships explicitly excluded, e.g. `(深雪改二以外)`.
  final List<String> exclusions;

  /// Ships explicitly included, e.g. `(含秋雲改二)`.
  final List<String> inclusions;

  /// True when the wiki writes `他` (other): the group excludes every ship
  /// explicitly listed earlier on the same page.
  final bool othersExcluded;

  /// True when the cell is empty: no ship restriction (all ships).
  final bool isAllShips;

  const ShipGroupSpec({
    this.shipNames = const [],
    this.classAnchors = const [],
    this.shipTypeNames = const [],
    this.nationalityTerms = const [],
    this.glossaryTerms = const [],
    this.exclusions = const [],
    this.inclusions = const [],
    this.othersExcluded = false,
    this.isAllShips = false,
  });

  bool get isEmpty =>
      shipNames.isEmpty &&
      classAnchors.isEmpty &&
      shipTypeNames.isEmpty &&
      nationalityTerms.isEmpty &&
      glossaryTerms.isEmpty;
}

class ShipGroupUnresolved extends ShipGroupParseResult {
  final String cellText;
  final String reason;
  const ShipGroupUnresolved(this.cellText, this.reason);
}

const Set<String> kShipTypeTermNames = <String>{
  '駆逐艦',
  '軽巡洋艦',
  '軽巡',
  '重巡洋艦',
  '重巡',
  '戦艦',
  '正規空母',
  '空母',
  '軽空母',
  '航空戦艦',
  '水上機母艦',
  '水母',
  '潜水艦',
  '潜水空母',
  '重雷装巡洋艦',
  '練習巡洋艦',
  '補給艦',
  '工作艦',
  '装甲空母',
  '海防艦',
  '揚陸艦',
  '潜水母艦',
  '敵艦',
};

const Set<String> kNationalityTermNames = <String>{
  '日本艦',
  '日本船',
  '米国艦',
  'アメリカ艦',
  '米艦',
  '英国艦',
  'イギリス艦',
  '英艦',
  '独国艦',
  'ドイツ艦',
  '独艦',
  '伊国艦',
  'イタリア艦',
  '伊艦',
  '仏国艦',
  'フランス艦',
  '露国艦',
  'ロシア艦',
  '中国艦',
  '瑞国艦',
  'スウェーデン艦',
  '蘭国艦',
  'オランダ艦',
  '豪国艦',
  'オーストラリア艦',
  '加国艦',
  'カナダ艦',
};

/// Recognized glossary terms (用語集2 anchors) mapped to group definitions.
const Map<String, GlossaryTermDef> kGlossaryTerms = <String, GlossaryTermDef>{
  '特型': GlossaryTermDef(
      anchor: 'le765ff7',
      kind: GlossaryKind.classGroup,
      anchorShipName: '吹雪',
      label: '特型駆逐艦(吹雪型)'),
  '吹雪型': GlossaryTermDef(
      anchor: 'le765ff7',
      kind: GlossaryKind.classGroup,
      anchorShipName: '吹雪',
      label: '吹雪型駆逐艦'),
};

enum GlossaryKind { classGroup, typeGroup, nationalityGroup }

class GlossaryTermDef {
  final String anchor;
  final GlossaryKind kind;
  final String anchorShipName;
  final String label;
  const GlossaryTermDef({
    required this.anchor,
    required this.kind,
    required this.anchorShipName,
    required this.label,
  });
}

/// Parses one 対象 cell into a [ShipGroupSpec].
///
/// Unrecognized shapes return [ShipGroupUnresolved] so the caller can record
/// them instead of guessing.
ShipGroupParseResult parseShipGroup(ExpandedCell cell) {
  final text = cell.text;
  if (text.trim().isEmpty && cell.links.isEmpty) {
    return const ShipGroupSpec(isAllShips: true);
  }

  final spec = ShipGroupSpecBuilder();
  final segs = cell.segments.where((s) => !s.isFootnote).toList();

  var parenBuf = StringBuffer();
  var inParen = false;
  var parenIsExclusion = false;
  var parenIsInclusion = false;

  var i = 0;
  while (i < segs.length) {
    final s = segs[i];
    if (s.isLink) {
      final title = s.title ?? s.text;
      if (inParen) {
        final cur = parenBuf.toString();
        if (!cur.contains(title)) parenBuf.write(title);
        i++;
        continue;
      }
      final isGlossary = (s.href ?? '').contains('用語集') ||
          Uri.decodeComponent(s.href ?? '').contains('用語集');
      if (isGlossary) {
        final visible = s.text.trim();
        spec.glossaryTerms.add(visible.isNotEmpty ? visible : title);
        i++;
        continue;
      }
      // Class group: link followed by '型' text. The suffix text itself is
      // left for the plain-text walker, which tolerates 型 remnants and
      // tracks parentheses.
      var suffix = '';
      var k = i + 1;
      while (k < segs.length && !segs[k].isLink) {
        final t = segs[k].text;
        if (t.contains('型')) {
          suffix = t;
          break;
        }
        k++;
      }
      if (suffix.contains('型')) {
        spec.classAnchors.add(title);
      } else {
        spec.shipNames.add(title);
      }
      i++;
      continue;
    }
    final t = s.text;
    // Walk text char groups, honoring parentheses that may span segments.
    var buf = StringBuffer();
    for (var ci = 0; ci < t.length; ci++) {
      final ch = t[ci];
      if (ch == '(') {
        if (buf.isNotEmpty) {
          _consumePlainText(buf.toString(), spec, text);
          buf = StringBuffer();
        }
        inParen = true;
        parenIsExclusion = false;
        parenIsInclusion = false;
        parenBuf = StringBuffer();
        continue;
      }
      if (ch == ')') {
        if (inParen) {
          _consumeParenthetical(parenBuf.toString(), spec, text);
          inParen = false;
        } else {
          buf.write(ch);
        }
        continue;
      }
      if (inParen) {
        parenBuf.write(ch);
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) {
      _consumePlainText(buf.toString(), spec, text);
    }
    i++;
  }
  if (inParen) {
    return ShipGroupUnresolved(
        text, 'unterminated parenthesis');
  }

  final result = spec.build();
  if (result.isEmpty &&
      !result.othersExcluded &&
      !result.isAllShips &&
      result.exclusions.isEmpty &&
      result.inclusions.isEmpty) {
    return ShipGroupUnresolved(text, 'nothing recognized');
  }
  return result;
}

void _consumePlainText(String t, ShipGroupSpecBuilder spec, String cellText) {
  if (t.trim().isEmpty) return;
  if (t.replaceAll('他', '').trim().isEmpty) {
    spec.othersExcluded = true;
    return;
  }
  if (t.contains('全艦') || t.contains('全船')) return;
  final parts =
      t.split(RegExp(r'[・、\s/]+')).where((p) => p.isNotEmpty).toList();
  for (final part in parts) {
    if (part == '全艦' || part == '全船') continue;
    if (part == '他') {
      spec.othersExcluded = true;
      continue;
    }
    if (_isClassSuffixRemnant(part)) continue;
    if (kShipTypeTermNames.contains(part)) {
      spec.shipTypeNames.add(part);
    } else if (kNationalityTermNames.contains(part)) {
      spec.nationalityTerms.add(part);
    } else {
      throw _UnresolvedGroup(cellText, 'unrecognized text: $part');
    }
  }
}

/// Tolerates class-suffix remnants like `型`, `型全艦` that belong to an
/// already-consumed class link, and standalone `型` decorations.
bool _isClassSuffixRemnant(String part) {
  if (!part.contains('型')) return false;
  final rest = part.replaceAll('型', '').replaceAll('全艦', '').trim();
  return rest.isEmpty;
}

void _consumeParenthetical(
    String inner, ShipGroupSpecBuilder spec, String cellText) {
  if (inner.contains('以外')) {
    final name = inner.replaceAll('以外', '').trim();
    if (name.isNotEmpty) {
      spec.exclusions.add(name);
    }
  } else if (inner.contains('含')) {
    final name = inner.replaceAll('含', '').trim();
    if (name.isNotEmpty) {
      spec.inclusions.add(name);
    }
  } else if (inner.contains('除く')) {
    final name = inner.replaceAll('除く', '').trim();
    if (name.isNotEmpty) {
      spec.exclusions.add(name);
    }
  } else if (inner.trim().isNotEmpty) {
    // Unknown parenthetical — record as exclusion, reviewer must verify.
    spec.exclusions.add(inner.trim());
  }
}

class _UnresolvedGroup implements Exception {
  final String cellText;
  final String reason;
  _UnresolvedGroup(this.cellText, this.reason);
}

/// Converts [_UnresolvedGroup] throws into [ShipGroupUnresolved] at the
/// boundary (see [parseShipGroupSafe]).
ShipGroupParseResult parseShipGroupSafe(ExpandedCell cell) {
  try {
    return parseShipGroup(cell);
  } on _UnresolvedGroup catch (e) {
    return ShipGroupUnresolved(e.cellText, e.reason);
  }
}

class ShipGroupSpecBuilder {
  final List<String> shipNames = [];
  final List<String> classAnchors = [];
  final List<String> shipTypeNames = [];
  final List<String> nationalityTerms = [];
  final List<String> glossaryTerms = [];
  final List<String> exclusions = [];
  final List<String> inclusions = [];
  bool othersExcluded = false;

  ShipGroupSpec build() => ShipGroupSpec(
        shipNames: shipNames,
        classAnchors: classAnchors,
        shipTypeNames: shipTypeNames,
        nationalityTerms: nationalityTerms,
        glossaryTerms: glossaryTerms,
        exclusions: exclusions,
        inclusions: inclusions,
        othersExcluded: othersExcluded,
      );
}

/// The 装備 column of single/synergy rows: either the page's own equipment
/// or another equipment/category.
sealed class EquipmentRefParseResult {
  const EquipmentRefParseResult();
}

class EquipmentRefOwn extends EquipmentRefParseResult {
  const EquipmentRefOwn();
}

class EquipmentRefNamed extends EquipmentRefParseResult {
  /// Link titles of the referenced equipment (synergy partners).
  final List<String> names;
  const EquipmentRefNamed(this.names);
}

class EquipmentRefCategory extends EquipmentRefParseResult {
  /// Category label such as 水上電探 / 国産ソナー.
  final String label;
  const EquipmentRefCategory(this.label);
}

class EquipmentRefUnresolved extends EquipmentRefParseResult {
  final String text;
  final String reason;
  const EquipmentRefUnresolved(this.text, this.reason);
}

/// Parses an 装備1/装備2/装備 column cell.
///
/// * `本装備` or a name matching the page equipment → [EquipmentRefOwn].
/// * Link(s) to other equipment pages → [EquipmentRefNamed].
/// * Plain category label (水上電探, 国産ソナー...) → [EquipmentRefCategory].
/// * `-`/empty → null (no equipment requirement).
EquipmentRefParseResult? parseEquipmentRef(ExpandedCell? cell) {
  if (cell == null) return null;
  final text = cell.text.trim();
  if (text.isEmpty || text == '-') return null;
  if (text == '本装備' || text == '本装备' || text == '当装備') {
    return const EquipmentRefOwn();
  }
  if (cell.links.isNotEmpty) {
    final names = cell.links.map((l) => l.title).toList();
    return EquipmentRefNamed(names);
  }
  if (text.contains('本装備') || text.contains('本装备')) {
    return const EquipmentRefOwn();
  }
  return EquipmentRefCategory(text);
}
