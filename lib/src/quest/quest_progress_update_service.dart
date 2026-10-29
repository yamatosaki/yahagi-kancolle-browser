import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'quest_progress_dataset.dart';
import 'quest_progress_dataset_store.dart';

const questProgressCommitApi =
    'https://api.github.com/repos/poooi/poi/commits'
    '?path=assets/data/fcd/questgoal.json&per_page=1';

sealed class QuestProgressUpdateResult {
  const QuestProgressUpdateResult({required this.sourceHost});
  final String sourceHost;
}

final class QuestProgressUpToDate extends QuestProgressUpdateResult {
  const QuestProgressUpToDate(this.version, {super.sourceHost = ''});
  final String version;
}

final class QuestProgressUpdated extends QuestProgressUpdateResult {
  const QuestProgressUpdated(this.dataset, {super.sourceHost = ''});
  final QuestProgressDataset dataset;
}

enum QuestProgressUpdateFailure { network, validation, storage }

final class QuestProgressUpdateFailed extends QuestProgressUpdateResult {
  const QuestProgressUpdateFailed(
    this.kind,
    this.error, {
    super.sourceHost = '',
  });
  final QuestProgressUpdateFailure kind;
  final Object error;
}

abstract interface class QuestProgressUpdateClient {
  Future<QuestProgressUpdateResult> checkAndUpdate({
    required QuestProgressDataset current,
  });
}

final class QuestProgressUpdateService implements QuestProgressUpdateClient {
  const QuestProgressUpdateService({
    required this.client,
    required this.store,
    this.appVersion = '1.0.9',
    this.timeout = const Duration(seconds: 10),
    this.maximumDataBytes = 2 * 1024 * 1024,
  });

  final http.Client client;
  final QuestProgressDatasetStore store;
  final String appVersion;
  final Duration timeout;
  final int maximumDataBytes;

  @override
  Future<QuestProgressUpdateResult> checkAndUpdate({
    required QuestProgressDataset current,
  }) async {
    var sourceHost = 'api.github.com';
    final budget = _ByteBudget(
      maximumDataBytes.clamp(1, QuestProgressDatasetStore.maximumPayloadBytes),
    );
    try {
      final metadata = await _get(
        Uri.parse(questProgressCommitApi),
        budget,
        maxBytes: 64 * 1024,
      );
      final decoded = jsonDecode(utf8.decode(metadata));
      if (decoded is! List ||
          decoded.length != 1 ||
          decoded.first is! Map<String, dynamic>) {
        throw const FormatException('Invalid quest progress commit metadata');
      }
      final commit = (decoded.first as Map<String, dynamic>)['sha'];
      if (commit is! String || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
        throw const FormatException('Invalid quest progress commit SHA');
      }
      String? raw;
      Object? lastNetworkError;
      for (final uri in _sources(commit)) {
        sourceHost = uri.host;
        try {
          raw = utf8.decode(await _get(uri, budget));
          break;
        } on FormatException {
          rethrow;
        } on Object catch (error) {
          lastNetworkError = error;
        }
      }
      if (raw == null) {
        throw lastNetworkError ??
            http.ClientException('No rule source available');
      }
      final remote = QuestProgressDataset.parsePayload(
        raw,
        sourceCommit: commit,
      );
      final comparison = remote.version.compareTo(current.version);
      if (comparison < 0) {
        throw const FormatException(
          'Quest progress update would downgrade data',
        );
      }
      if (comparison == 0) {
        return QuestProgressUpToDate(current.version, sourceHost: sourceHost);
      }
      final updated = remote.overlayOn(current);
      try {
        await store.save(updated);
      } on Object catch (error) {
        return QuestProgressUpdateFailed(
          QuestProgressUpdateFailure.storage,
          error,
          sourceHost: sourceHost,
        );
      }
      return QuestProgressUpdated(updated, sourceHost: sourceHost);
    } on FormatException catch (error) {
      return QuestProgressUpdateFailed(
        QuestProgressUpdateFailure.validation,
        error,
        sourceHost: sourceHost,
      );
    } on Object catch (error) {
      return QuestProgressUpdateFailed(
        QuestProgressUpdateFailure.network,
        error,
        sourceHost: sourceHost,
      );
    }
  }

  List<Uri> _sources(String commit) => [
    Uri.parse(
      'https://raw.githubusercontent.com/poooi/poi/'
      '$commit/assets/data/fcd/questgoal.json',
    ),
    Uri.parse(
      'https://cdn.jsdelivr.net/gh/poooi/poi@'
      '$commit/assets/data/fcd/questgoal.json',
    ),
  ];

  Future<Uint8List> _get(Uri uri, _ByteBudget budget, {int? maxBytes}) async {
    final commit = RegExp(r'[0-9a-f]{40}').firstMatch('$uri')?.group(0) ?? '';
    final allowed =
        uri == Uri.parse(questProgressCommitApi) ||
        _sources(commit).contains(uri);
    if (uri.scheme != 'https' || !allowed) {
      throw const FormatException('Quest progress update URL is not allowed');
    }
    final abort = Completer<void>();
    void abortRequest() {
      if (!abort.isCompleted) abort.complete();
    }

    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser/$appVersion'
          ..headers['Accept'] = 'application/json';
    final elapsed = Stopwatch()..start();
    var headersExpired = false;
    final pendingResponse = client.send(request);
    unawaited(
      pendingResponse.then<void>((response) {
        if (headersExpired) _cancelStream(response.stream);
      }, onError: (Object _) {}),
    );
    final response = await pendingResponse.timeout(
      timeout,
      onTimeout: () {
        headersExpired = true;
        abortRequest();
        throw TimeoutException('Quest progress request exceeded its deadline');
      },
    );
    if (response.statusCode != 200) {
      abortRequest();
      _cancelStream(response.stream);
      throw http.ClientException(
        'Quest progress request failed with HTTP ${response.statusCode}',
        uri,
      );
    }
    final remaining = timeout - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      abortRequest();
      _cancelStream(response.stream);
      throw TimeoutException('Quest progress request exceeded its deadline');
    }
    return _readResponse(
      response.stream,
      budget: budget,
      maxBytes: maxBytes,
      remaining: remaining,
      abortRequest: abortRequest,
    );
  }

  Future<Uint8List> _readResponse(
    Stream<List<int>> stream, {
    required _ByteBudget budget,
    required int? maxBytes,
    required Duration remaining,
    required void Function() abortRequest,
  }) {
    final done = Completer<Uint8List>();
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    late final Timer deadline;
    var finished = false;
    void fail(Object error, [StackTrace? stack]) {
      if (finished) return;
      finished = true;
      deadline.cancel();
      abortRequest();
      final cancellation = subscription?.cancel();
      if (cancellation != null) {
        unawaited(cancellation.catchError((Object _) {}));
      }
      done.completeError(error, stack ?? StackTrace.current);
    }

    deadline = Timer(remaining, () {
      fail(TimeoutException('Quest progress request exceeded its deadline'));
    });
    subscription = stream.listen(
      (chunk) {
        if (finished) return;
        try {
          budget.consume(chunk.length);
          if (maxBytes != null && bytes.length + chunk.length > maxBytes) {
            throw const FormatException(
              'Quest progress response exceeds the size limit',
            );
          }
          bytes.add(chunk);
        } on Object catch (error, stack) {
          fail(error, stack);
        }
      },
      onError: fail,
      onDone: () {
        if (finished) return;
        finished = true;
        deadline.cancel();
        done.complete(bytes.takeBytes());
      },
    );
    return done.future;
  }
}

void _cancelStream(Stream<List<int>> stream) {
  unawaited(
    stream
        .listen((_) {}, onError: (Object _) {})
        .cancel()
        .catchError((Object _) {}),
  );
}

final class _ByteBudget {
  _ByteBudget(this.remaining);
  int remaining;
  void consume(int bytes) {
    if (bytes > remaining) {
      throw const FormatException(
        'Quest progress download exceeds the size limit',
      );
    }
    remaining -= bytes;
  }
}
