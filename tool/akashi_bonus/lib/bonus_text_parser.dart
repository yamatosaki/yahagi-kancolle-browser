/// Parses sunit text values like `火力+2,+3,+1` or `回避+1(雪風改二のみ)`
/// into structured stat bonuses. DOM-only parsing happens upstream; this
/// module only parses *short text values* already extracted from the DOM,
/// which is why plain regular expressions are acceptable here.
library;

/// Japanese stat label → normalized stat name.
const Map<String, String> kStatLabels = <String, String>{
  '火力': 'firepower',
  '雷装': 'torpedo',
  '対空': 'antiAir',
  '回避': 'evasion',
  '命中': 'accuracy',
  '装甲': 'armor',
  '対潜': 'antiSubmarine',
  '索敵': 'lineOfSight',
  '爆装': 'bombing',
  '射程': 'range',
};

final RegExp _statPattern = RegExp(
    r'^\+?\s*(?:\((.+?)\)\s*)?(火力|雷装|対空|回避|命中|装甲|対潜|索敵|爆装|射程)'
    r'([+-]\d+(?:,[+-]?\d+)*)(.*)$');

/// Parsed condition inside a parenthetical of a bonus text.
class ParsedCondition {
  final List<String> onlyShipNames;
  final List<String> excludeShipNames;
  final int? minImprovement;
  final int? maxImprovement;
  final String? raw;

  const ParsedCondition({
    this.onlyShipNames = const [],
    this.excludeShipNames = const [],
    this.minImprovement,
    this.maxImprovement,
    this.raw,
  });

  bool get isEmpty =>
      onlyShipNames.isEmpty &&
      excludeShipNames.isEmpty &&
      minImprovement == null &&
      maxImprovement == null;
}

/// One stat bonus with comma increments and an optional condition.
class StatBonusText {
  final String stat;
  final List<int> increments;
  final ParsedCondition condition;
  final String rawText;

  const StatBonusText({
    required this.stat,
    required this.increments,
    required this.condition,
    required this.rawText,
  });

  bool get isCountSequence => increments.length > 1;
}

/// Result of parsing one bonus sunit text.
sealed class BonusTextParseResult {
  const BonusTextParseResult();
}

class BonusTextParsed extends BonusTextParseResult {
  final StatBonusText bonus;
  const BonusTextParsed(this.bonus);
}

class BonusTextUnresolved extends BonusTextParseResult {
  final String text;
  final String reason;
  const BonusTextUnresolved(this.text, this.reason);
}

/// Parses one sunit text value.
///
/// Recognized shapes:
///   * `火力+2`
///   * `火力+2,+3,+1` (comma increments → count sequence)
///   * `火力-1` (negative)
///   * `火力+2(雪風改二のみ)`
///   * `回避+1(時雨改二を除く)`
///   * `火力+1(★+4以上)`
///   * `+対空+4` (leading `+` before the stat label, e.g. after an icon)
/// Anything else returns [BonusTextUnresolved].
BonusTextParseResult parseBonusText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const BonusTextUnresolved('', 'empty bonus text');
  }
  final m = _statPattern.firstMatch(text);
  if (m == null) {
    // Range stat written as `射程:長` / `射程：短`.
    final rangeM = RegExp(r'^射程\s*[:：]\s*(短|中|長|超長)$').firstMatch(text);
    if (rangeM != null) {
      return BonusTextParsed(StatBonusText(
        stat: 'range',
        increments: [kRangeLabels[rangeM.group(1)]!],
        condition: const ParsedCondition(),
        rawText: text,
      ));
    }
    return BonusTextUnresolved(text, 'not a stat bonus shape');
  }
  final stat = kStatLabels[m.group(2)!]!;
  final numbers = m.group(3)!;
  final tail = m.group(4)!;

  final increments = <int>[];
  for (final part in numbers.split(',')) {
    final v = int.tryParse(part);
    if (v == null) {
      return BonusTextUnresolved(text, 'unparseable increment "$part"');
    }
    increments.add(v);
  }
  if (increments.isEmpty) {
    return BonusTextUnresolved(text, 'no increment values');
  }

  final conditionText = tail.trim();
  final suffixCondition = conditionText.isEmpty
      ? const ParsedCondition()
      : _parseCondition(conditionText);
  if (conditionText.isNotEmpty && suffixCondition.isEmpty) {
    return BonusTextUnresolved(text, 'unparseable condition "$conditionText"');
  }

  // Prefix condition like `(大淀) 火力+3` means "only for 大淀".
  final prefixParen = m.group(1);
  ParsedCondition condition = suffixCondition;
  if (prefixParen != null && prefixParen.isNotEmpty) {
    final p = _parseCondition('($prefixParen)');
    if (p.onlyShipNames.isEmpty &&
        p.excludeShipNames.isEmpty &&
        p.minImprovement == null &&
        p.maxImprovement == null) {
      // Unstructured prefix: by convention it is an "only these ships"
      // restriction.
      condition = ParsedCondition(
        onlyShipNames: [
          ...condition.onlyShipNames,
          ...prefixParen
              .split(RegExp(r'[・、\s]+'))
              .where((s) => s.isNotEmpty),
        ],
        excludeShipNames: condition.excludeShipNames,
        minImprovement: condition.minImprovement,
        maxImprovement: condition.maxImprovement,
        raw: [condition.raw, '($prefixParen)']
            .where((r) => r != null)
            .join(' '),
      );
    } else {
      condition = ParsedCondition(
        onlyShipNames: [...condition.onlyShipNames, ...p.onlyShipNames],
        excludeShipNames:
            [...condition.excludeShipNames, ...p.excludeShipNames],
        minImprovement: condition.minImprovement ?? p.minImprovement,
        maxImprovement: condition.maxImprovement ?? p.maxImprovement,
        raw: [condition.raw, p.raw].where((r) => r != null).join(' '),
      );
    }
  }

  return BonusTextParsed(StatBonusText(
    stat: stat,
    increments: increments,
    condition: condition,
    rawText: text,
  ));
}

final RegExp _parenPattern = RegExp(r'^\((.+)\)$', dotAll: true);

ParsedCondition _parseCondition(String raw) {
  final m = _parenPattern.firstMatch(raw);
  if (m == null) return const ParsedCondition();
  final inner = m.group(1)!.trim();
  final pieces = inner
      .split(RegExp(r'[・、\s]+'))
      .where((p) => p.isNotEmpty)
      .toList();

  final only = <String>[];
  final exclude = <String>[];
  int? minImp;
  int? maxImp;

  for (final piece in pieces) {
    final onlyM = RegExp(r'^(.+?)のみ$').firstMatch(piece);
    if (onlyM != null) {
      only.add(onlyM.group(1)!);
      continue;
    }
    final exclM = RegExp(r'^(.+?)(?:を)?除く$').firstMatch(piece);
    if (exclM != null) {
      exclude.add(exclM.group(1)!);
      continue;
    }
    final exactM = RegExp(r'^★\s*[+＋]?\s*(\d+)$').firstMatch(piece);
    if (exactM != null) {
      final n = int.parse(exactM.group(1)!);
      minImp = n;
      maxImp = n;
      continue;
    }
    final rangeM = RegExp(r'^★\s*[+＋]?\s*(\d+)\s*[〜~～]\s*[+＋]?\s*(\d+)$').firstMatch(piece);
    if (rangeM != null) {
      minImp = int.parse(rangeM.group(1)!);
      maxImp = int.parse(rangeM.group(2)!);
      continue;
    }
    final starM = RegExp(r'^★\s*[+＋]?\s*(\d+)\s*(?:以上|〜|~|～)?$').firstMatch(piece);
    if (starM != null) {
      final n = int.parse(starM.group(1)!);
      minImp = n;
      continue;
    }
    // Unknown condition piece: keep raw so the caller can report it.
    return ParsedCondition(raw: raw);
  }
  return ParsedCondition(
    onlyShipNames: only,
    excludeShipNames: exclude,
    minImprovement: minImp,
    maxImprovement: maxImp,
    raw: raw,
  );
}

/// Splits a target text (group labels / ship names) into tokens.
/// Separators are `・`, `、` and newlines only, and only OUTSIDE
/// parentheses (notes like `陽炎型改二(雪風改二・秋雲改二除く)` stay whole).
/// Spaces and `/` are kept inside tokens because ship names use them
/// (e.g. `Prinz Eugen`, `矢矧改二/乙`).
List<String> splitTargetTokens(String text) {
  final tokens = <String>[];
  var depth = 0;
  var buf = StringBuffer();
  for (final ch in text.split('')) {
    if (ch == '(' || ch == '（') {
      depth++;
      buf.write(ch);
      continue;
    }
    if (ch == ')' || ch == '）') {
      if (depth > 0) depth--;
      buf.write(ch);
      continue;
    }
    if (depth == 0 && (ch == '・' || ch == '、' || ch == '\n')) {
      final t = buf.toString().trim();
      if (t.isNotEmpty) tokens.add(t);
      buf = StringBuffer();
      continue;
    }
    buf.write(ch);
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) tokens.add(tail);
  return tokens;
}

/// Range labels for the 射程 stat.
const Map<String, int> kRangeLabels = <String, int>{
  '短': 1,
  '中': 2,
  '長': 3,
  '超長': 4,
};
