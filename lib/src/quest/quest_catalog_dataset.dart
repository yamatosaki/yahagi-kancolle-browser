import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'quest_catalog.dart';

final class QuestCatalogVersion implements Comparable<QuestCatalogVersion> {
  const QuestCatalogVersion({
    required this.committedAt,
    required String commitSha,
    String? relationCommitSha,
    required this.sha256,
  }) : displayCommitSha = commitSha,
       relationCommitSha = relationCommitSha ?? commitSha;

  final DateTime committedAt;
  final String displayCommitSha;
  final String relationCommitSha;
  final String sha256;

  String get commitSha => displayCommitSha;

  String get shortLabel =>
      '${committedAt.toUtc().toIso8601String().substring(0, 10)} '
      '${displayCommitSha.substring(0, 7)}/'
      '${relationCommitSha.substring(0, 7)}';

  @override
  int compareTo(QuestCatalogVersion other) {
    final time = committedAt.compareTo(other.committedAt);
    if (time != 0) return time;
    if (displayCommitSha == other.displayCommitSha &&
        relationCommitSha == other.relationCommitSha) {
      return 0;
    }
    if (sha256 == other.sha256) return 0;
    final display = displayCommitSha.compareTo(other.displayCommitSha);
    return display != 0
        ? display
        : relationCommitSha.compareTo(other.relationCommitSha);
  }

  factory QuestCatalogVersion.fromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Quest metadata root must be an object');
    }
    final committedAt = DateTime.tryParse(
      decoded['committedAt'] as String? ?? '',
    );
    final displayCommitSha =
        decoded['displayCommitSha'] ?? decoded['commitSha'];
    final relationCommitSha = decoded['relationCommitSha'] ?? displayCommitSha;
    final contentHash = decoded['sha256'];
    if (committedAt == null ||
        displayCommitSha is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(displayCommitSha) ||
        relationCommitSha is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(relationCommitSha) ||
        contentHash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) {
      throw const FormatException('Quest metadata fields are invalid');
    }
    return QuestCatalogVersion(
      committedAt: committedAt.toUtc(),
      commitSha: displayCommitSha,
      relationCommitSha: relationCommitSha,
      sha256: contentHash,
    );
  }

  String toJson() => jsonEncode(<String, Object?>{
    'committedAt': committedAt.toUtc().toIso8601String(),
    'commitSha': displayCommitSha,
    'displayCommitSha': displayCommitSha,
    'relationCommitSha': relationCommitSha,
    'sha256': sha256,
  });
}

final class QuestCatalogDataset {
  const QuestCatalogDataset({
    required this.catalog,
    required this.version,
    required this.rawJson,
  });

  final QuestCatalog catalog;
  final QuestCatalogVersion version;
  final String rawJson;

  static QuestCatalogDataset parse({
    required String rawJson,
    required QuestCatalogVersion version,
    int minimumQuestCount = 500,
    int maxBytes = 1024 * 1024,
  }) {
    final bytes = utf8.encode(rawJson);
    if (bytes.length > maxBytes) {
      throw const FormatException('Quest catalog exceeds the size limit');
    }
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != version.sha256) {
      throw const FormatException('Quest catalog hash does not match metadata');
    }
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Quest catalog root must be an object');
    }
    if (decoded.length < minimumQuestCount) {
      throw const FormatException('Quest catalog contains too few quests');
    }
    final entries = <QuestCatalogEntry>[];
    final codes = <String>{};
    for (final item in decoded.entries) {
      final gameId = int.tryParse(item.key);
      final value = item.value;
      if (gameId == null || gameId <= 0 || value is! Map<String, dynamic>) {
        throw const FormatException('Quest catalog entry is invalid');
      }
      final code = value['code'];
      final name = value['name'];
      final description = value['desc'];
      if (code is! String ||
          code.trim().isEmpty ||
          name is! String ||
          description is! String ||
          !codes.add(code.trim())) {
        throw const FormatException('Quest catalog fields are invalid');
      }
      final pre = value['pre'];
      if (pre != null &&
          (pre is! List ||
              pre.any((item) => item is! String || item.trim().isEmpty))) {
        throw const FormatException('Quest prerequisites are invalid');
      }
      final prerequisites = pre == null
          ? const <String>[]
          : (pre as List).cast<String>();
      if (prerequisites.contains(code.trim())) {
        throw const FormatException('Quest cannot depend on itself');
      }
      for (final optional in const <String>['memo', 'memo2', 'rewards']) {
        if (value[optional] != null && value[optional] is! String) {
          throw const FormatException('Quest optional field is invalid');
        }
      }
      entries.add(QuestCatalogEntry.fromJson(gameId, value));
    }
    entries.sort((a, b) => a.gameId.compareTo(b.gameId));
    return QuestCatalogDataset(
      catalog: QuestCatalog(entries),
      version: version,
      rawJson: rawJson,
    );
  }
}
