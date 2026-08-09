import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'quest_catalog_dataset.dart';
import 'quest_catalog_store.dart';

const questCatalogCommitApi =
    'https://api.github.com/repos/kcwikizh/kcQuests/commits'
    '?path=quests-scn.json&per_page=1';

sealed class QuestCatalogUpdateResult {
  const QuestCatalogUpdateResult({required this.sourceHost});
  final String sourceHost;
}

final class QuestCatalogUpToDate extends QuestCatalogUpdateResult {
  const QuestCatalogUpToDate(this.version, {super.sourceHost = ''});
  final QuestCatalogVersion version;
}

final class QuestCatalogUpdated extends QuestCatalogUpdateResult {
  const QuestCatalogUpdated(this.dataset, {super.sourceHost = ''});
  final QuestCatalogDataset dataset;
}

enum QuestCatalogUpdateFailure { network, validation, storage }

final class QuestCatalogUpdateFailed extends QuestCatalogUpdateResult {
  const QuestCatalogUpdateFailed(
    this.kind,
    this.error, {
    super.sourceHost = '',
  });
  final QuestCatalogUpdateFailure kind;
  final Object error;
}

abstract interface class QuestCatalogUpdateClient {
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  });
}

final class QuestCatalogUpdateService implements QuestCatalogUpdateClient {
  const QuestCatalogUpdateService({
    required this.client,
    required this.store,
    this.appVersion = '1.0.3',
    this.timeout = const Duration(seconds: 10),
    this.maximumDataBytes = 1024 * 1024,
    this.minimumQuestCount = 500,
  });

  final http.Client client;
  final QuestCatalogStore store;
  final String appVersion;
  final Duration timeout;
  final int maximumDataBytes;
  final int minimumQuestCount;

  @override
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  }) async {
    try {
      final remote = await _readRemoteVersion();
      if (remote.commitSha == current.version.commitSha) {
        final result = QuestCatalogUpToDate(
          current.version,
          sourceHost: 'api.github.com',
        );
        await _saveState(current, result, 'upToDate');
        return result;
      }
      if (remote.committedAt.isBefore(current.version.committedAt)) {
        throw const FormatException('Quest catalog update would downgrade');
      }

      QuestCatalogUpdateFailed? lastFailure;
      for (final uri in _dataSources(remote.commitSha)) {
        try {
          final bytes = await _get(uri, maximumDataBytes);
          final raw = utf8.decode(bytes);
          final version = QuestCatalogVersion(
            committedAt: remote.committedAt,
            commitSha: remote.commitSha,
            sha256: sha256.convert(bytes).toString(),
          );
          final dataset = QuestCatalogDataset.parse(
            rawJson: raw,
            version: version,
            minimumQuestCount: minimumQuestCount,
            maxBytes: maximumDataBytes,
          );
          try {
            await store.save(dataset);
          } on IOException catch (error) {
            final failed = QuestCatalogUpdateFailed(
              QuestCatalogUpdateFailure.storage,
              error,
              sourceHost: uri.host,
            );
            await _saveState(current, failed, 'storageFailed');
            return failed;
          }
          final result = QuestCatalogUpdated(dataset, sourceHost: uri.host);
          await _saveState(dataset, result, 'updated');
          return result;
        } on FormatException catch (error) {
          lastFailure = QuestCatalogUpdateFailed(
            QuestCatalogUpdateFailure.validation,
            error,
            sourceHost: uri.host,
          );
        } on Object catch (error) {
          lastFailure = QuestCatalogUpdateFailed(
            QuestCatalogUpdateFailure.network,
            error,
            sourceHost: uri.host,
          );
        }
      }
      final result =
          lastFailure ??
          const QuestCatalogUpdateFailed(
            QuestCatalogUpdateFailure.network,
            'No quest catalog source is available',
          );
      await _saveState(current, result, '${result.kind.name}Failed');
      return result;
    } on FormatException catch (error) {
      final result = QuestCatalogUpdateFailed(
        QuestCatalogUpdateFailure.validation,
        error,
        sourceHost: 'api.github.com',
      );
      await _saveState(current, result, 'validationFailed');
      return result;
    } on Object catch (error) {
      final result = QuestCatalogUpdateFailed(
        QuestCatalogUpdateFailure.network,
        error,
        sourceHost: 'api.github.com',
      );
      await _saveState(current, result, 'networkFailed');
      return result;
    }
  }

  Future<QuestCatalogVersion> _readRemoteVersion() async {
    final bytes = await _get(Uri.parse(questCatalogCommitApi), 64 * 1024);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw const FormatException('Quest commit metadata is invalid');
    }
    final item = (decoded.first as Map).cast<String, dynamic>();
    final sha = item['sha'];
    final commit = item['commit'];
    final committer = commit is Map ? commit['committer'] : null;
    final date = committer is Map
        ? DateTime.tryParse('${committer['date']}')
        : null;
    if (sha is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(sha) ||
        date == null) {
      throw const FormatException('Quest commit fields are invalid');
    }
    return QuestCatalogVersion(
      committedAt: date.toUtc(),
      commitSha: sha,
      sha256: '0' * 64,
    );
  }

  List<Uri> _dataSources(String sha) => <Uri>[
    Uri.parse(
      'https://raw.githubusercontent.com/kcwikizh/kcQuests/$sha/quests-scn.json',
    ),
    Uri.parse(
      'https://cdn.jsdelivr.net/gh/kcwikizh/kcQuests@$sha/quests-scn.json',
    ),
  ];

  Future<List<int>> _get(Uri uri, int maxBytes) async {
    final allowed =
        uri == Uri.parse(questCatalogCommitApi) ||
        _dataSources(
          RegExp(r'[0-9a-f]{40}').firstMatch(uri.toString())?.group(0) ?? '',
        ).contains(uri);
    if (uri.scheme != 'https' || !allowed) {
      throw FormatException('Quest update URL is not allowed: $uri');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser/$appVersion';
    final response = await client.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Quest update request failed with HTTP ${response.statusCode}',
        uri,
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(timeout)) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Quest update response is too large');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<void> _saveState(
    QuestCatalogDataset dataset,
    QuestCatalogUpdateResult result,
    String resultName,
  ) async {
    try {
      var source = result.sourceHost;
      if (result is QuestCatalogUpdateFailed) {
        source = (await store.loadState())?.source ?? '';
      }
      await store.saveState(
        QuestCatalogState(
          version: dataset.version,
          source: source,
          lastCheckedAt: DateTime.now().toUtc(),
          result: resultName,
        ),
      );
    } catch (_) {
      // A diagnostic state failure must never replace a verified dataset.
    }
  }
}
