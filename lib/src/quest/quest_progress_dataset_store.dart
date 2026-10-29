import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';

import 'quest_progress_dataset.dart';

abstract interface class QuestProgressDatasetStorage {
  Future<String?> read();
  Future<void> write(String raw);
}

/// Public rule data is shared across accounts and committed as one preference.
final class PreferencesQuestProgressDatasetStorage
    implements QuestProgressDatasetStorage {
  const PreferencesQuestProgressDatasetStorage();

  static const cacheKey = 'quest-progress-rules.v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(cacheKey);

  @override
  Future<void> write(String raw) async {
    final written = await (await SharedPreferences.getInstance()).setString(
      cacheKey,
      raw,
    );
    if (!written) throw StateError('Quest progress rule cache write failed');
  }
}

final class QuestProgressDatasetStore {
  const QuestProgressDatasetStore(this.storage);

  static const maximumPayloadBytes = 2 * 1024 * 1024;
  static const _maximumCacheBytes = maximumPayloadBytes * 2 + 4096;

  final QuestProgressDatasetStorage storage;

  Future<QuestProgressDataset> loadBestAvailable(
    QuestProgressDataset bundled,
  ) async {
    try {
      final raw = await storage.read();
      if (raw == null || utf8.encode(raw).length > _maximumCacheBytes) {
        return bundled;
      }
      final envelope = jsonDecode(raw);
      if (envelope is! Map<String, dynamic> ||
          envelope['format'] != 1 ||
          envelope['rawJson'] is! String ||
          envelope['sourceCommit'] is! String ||
          envelope['sha256'] is! String) {
        return bundled;
      }
      final payload = envelope['rawJson'] as String;
      final commit = envelope['sourceCommit'] as String;
      if (utf8.encode(payload).length > maximumPayloadBytes ||
          !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit) ||
          envelope['sha256'] != _digest(payload)) {
        return bundled;
      }
      return QuestProgressDataset.parsePayload(
        payload,
        sourceCommit: commit,
      ).overlayOn(bundled);
    } catch (_) {
      // Missing, corrupt, or unavailable caches never displace bundled rules.
      return bundled;
    }
  }

  Future<void> save(QuestProgressDataset dataset) async {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(dataset.sourceCommit)) {
      throw const FormatException('Invalid quest progress source commit');
    }
    final ids = dataset.goals.keys.toList()..sort();
    // Persist the complete effective table so IDs retained from an earlier
    // online revision also survive a restart. The upstream payload remains
    // unchanged on the dataset itself; this cache is a local derived copy.
    final payload = jsonEncode({
      'meta': {'name': 'questgoal', 'version': dataset.version},
      'data': {for (final id in ids) '$id': dataset.goals[id]!.raw},
    });
    if (utf8.encode(payload).length > maximumPayloadBytes) {
      throw const FormatException(
        'Quest progress cache exceeds the size limit',
      );
    }
    QuestProgressDataset.parsePayload(
      payload,
      sourceCommit: dataset.sourceCommit,
    );
    final envelope = jsonEncode({
      'format': 1,
      'rawJson': payload,
      'sourceCommit': dataset.sourceCommit,
      'sha256': _digest(payload),
    });
    await storage.write(envelope);
  }
}

String _digest(String raw) =>
    crypto.sha256.convert(utf8.encode(raw)).toString();
