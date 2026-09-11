import 'dart:convert';

import '../game_state/quest_text_normalizer.dart';

String mergeQuestCatalogJson({
  required String japaneseJson,
  required String relationJson,
}) {
  final japanese = _decodeRoot(japaneseJson, 'Japanese quest catalog');
  final relations = _decodeRoot(relationJson, 'Quest relation catalog');
  final gameIds = japanese.keys.map(int.tryParse).toList(growable: false);
  if (gameIds.any((id) => id == null || id <= 0)) {
    throw const FormatException('Japanese quest id is invalid');
  }
  final sortedIds = gameIds.cast<int>()..sort();
  final merged = <String, Object?>{};

  for (final gameId in sortedIds) {
    final key = '$gameId';
    final display = _decodeEntry(japanese[key], 'Japanese quest entry');
    final code = _requiredString(display, 'code').trim();
    final name = _requiredString(display, 'name');
    final description = _string(display, 'desc');
    final relationValue = relations[key];
    final relation = relationValue == null
        ? const <String, dynamic>{}
        : _decodeEntry(relationValue, 'Quest relation entry');
    final prerequisites = relation['pre'];
    if (prerequisites != null &&
        (prerequisites is! List ||
            prerequisites.any(
              (item) => item is! String || item.trim().isEmpty,
            ))) {
      throw FormatException('Quest prerequisites are invalid for $gameId');
    }
    final translatedName = _optionalString(relation, 'name');
    final translatedDescription = _optionalString(relation, 'desc');

    merged[key] = <String, Object?>{
      'code': code,
      'name': name,
      'desc': description,
      'memo2': _optionalString(relation, 'memo2') ?? '',
      if (display['rewards'] case final String rewards) 'rewards': rewards,
      if (display['resources'] case final List resources)
        'resources': resources,
      if (prerequisites case final List pre) 'pre': pre,
      if (translatedName != null && translatedName.trim().isNotEmpty)
        'nameZh': _normalizeTranslation(translatedName),
      if (translatedDescription != null &&
          translatedDescription.trim().isNotEmpty)
        'descZh': _normalizeTranslation(translatedDescription),
    };
  }
  return jsonEncode(merged);
}

String _normalizeTranslation(String source) => normalizeQuestDetail(source)
    .replaceFirst(RegExp(r'^[A-Za-z]+\|'), '')
    .replaceAllMapped(
      RegExp(r'([「『（(])[^|，。！？；：\n「『（(]{1,30}\|'),
      (match) => match.group(1)!,
    );

String? _optionalString(Map<String, dynamic> entry, String key) {
  final value = entry[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Quest translation $key is invalid');
  }
  return value;
}

Map<String, dynamic> _decodeRoot(String source, String label) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$label root must be an object');
  }
  return decoded;
}

Map<String, dynamic> _decodeEntry(Object? value, String label) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$label must be an object');
  }
  return value;
}

String _requiredString(Map<String, dynamic> entry, String key) {
  final value = entry[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Japanese quest $key is invalid');
  }
  return value;
}

String _string(Map<String, dynamic> entry, String key) {
  final value = entry[key];
  if (value is! String) {
    throw FormatException('Japanese quest $key is invalid');
  }
  return value;
}
