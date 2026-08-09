import 'dart:convert';

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
    final description = _requiredString(display, 'desc');
    final relationValue = relations[key];
    final relation = relationValue == null
        ? const <String, dynamic>{}
        : _decodeEntry(relationValue, 'Quest relation entry');
    final relationCode = relation['code'];
    if (relationCode is String &&
        relationCode.trim().isNotEmpty &&
        relationCode.trim() != code) {
      throw FormatException('Quest code mismatch for game id $gameId');
    }
    final prerequisites = relation['pre'];
    if (prerequisites != null &&
        (prerequisites is! List ||
            prerequisites.any(
              (item) => item is! String || item.trim().isEmpty,
            ))) {
      throw FormatException('Quest prerequisites are invalid for $gameId');
    }

    merged[key] = <String, Object?>{
      'code': code,
      'name': name,
      'desc': description,
      if (display['rewards'] case final String rewards) 'rewards': rewards,
      if (display['resources'] case final List resources)
        'resources': resources,
      if (prerequisites case final List pre) 'pre': pre,
    };
  }
  return jsonEncode(merged);
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
