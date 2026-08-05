import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'fcd_map_dataset.dart';
import 'fcd_map_store.dart';

const fcdMapUpdateSources = <String>[
  'https://raw.githubusercontent.com/poooi/poi/master/assets/data/fcd/',
  'https://cdn.jsdelivr.net/gh/poooi/poi@master/assets/data/fcd/',
];

sealed class FcdMapUpdateResult {
  const FcdMapUpdateResult({required this.sourceHost});

  final String sourceHost;
}

final class FcdMapUpToDate extends FcdMapUpdateResult {
  const FcdMapUpToDate(this.version, {this.host = ''})
    : super(sourceHost: host);

  final FcdMapVersion version;
  final String host;
}

final class FcdMapUpdated extends FcdMapUpdateResult {
  const FcdMapUpdated(this.dataset, {this.host = ''}) : super(sourceHost: host);

  final FcdMapDataset dataset;
  final String host;
}

enum FcdMapUpdateFailure { network, validation, storage }

final class FcdMapUpdateFailed extends FcdMapUpdateResult {
  const FcdMapUpdateFailed(this.kind, this.error, {this.host = ''})
    : super(sourceHost: host);

  final FcdMapUpdateFailure kind;
  final Object error;
  final String host;
}

abstract interface class FcdMapUpdateClient {
  Future<FcdMapUpdateResult> checkAndUpdate({required FcdMapDataset current});
}

final class FcdMapUpdateService implements FcdMapUpdateClient {
  const FcdMapUpdateService({
    required this.client,
    required this.store,
    this.appVersion = '1.0.2',
    this.timeout = const Duration(seconds: 10),
    this.maxMapBytes = 1024 * 1024,
    this.minimumMapCount = 50,
  });

  final http.Client client;
  final FcdMapStore store;
  final String appVersion;
  final Duration timeout;
  final int maxMapBytes;
  final int minimumMapCount;

  @override
  Future<FcdMapUpdateResult> checkAndUpdate({
    required FcdMapDataset current,
  }) async {
    FcdMapUpdateFailed? lastFailure;
    for (final source in fcdMapUpdateSources) {
      final host = Uri.parse(source).host;
      try {
        final remoteVersion = await _readRemoteVersion(source);
        if (remoteVersion.compareTo(current.version) < 0) {
          throw const FormatException('FCD update would downgrade data');
        }
        if (remoteVersion == current.version) {
          final result = FcdMapUpToDate(current.version, host: host);
          await _persistState(current, result, 'upToDate');
          return result;
        }
        final dataset = await _downloadMap(source);
        if (dataset.version != remoteVersion) {
          throw const FormatException(
            'FCD meta.json and map.json versions do not match',
          );
        }
        if (dataset.version.compareTo(current.version) <= 0) {
          throw const FormatException('FCD update would downgrade data');
        }
        try {
          await store.save(dataset);
        } on IOException catch (error) {
          final result = FcdMapUpdateFailed(
            FcdMapUpdateFailure.storage,
            error,
            host: host,
          );
          await _persistState(current, result, 'storageFailed');
          return result;
        }
        final result = FcdMapUpdated(dataset, host: host);
        await _persistState(dataset, result, 'updated');
        return result;
      } on FormatException catch (error) {
        lastFailure = FcdMapUpdateFailed(
          FcdMapUpdateFailure.validation,
          error,
          host: host,
        );
      } on TimeoutException catch (error) {
        lastFailure = FcdMapUpdateFailed(
          FcdMapUpdateFailure.network,
          error,
          host: host,
        );
      } on http.ClientException catch (error) {
        lastFailure = FcdMapUpdateFailed(
          FcdMapUpdateFailure.network,
          error,
          host: host,
        );
      } on SocketException catch (error) {
        lastFailure = FcdMapUpdateFailed(
          FcdMapUpdateFailure.network,
          error,
          host: host,
        );
      }
    }
    final result =
        lastFailure ??
        const FcdMapUpdateFailed(
          FcdMapUpdateFailure.network,
          'No FCD update source is available',
        );
    await _persistState(current, result, '${result.kind.name}Failed');
    return result;
  }

  Future<void> _persistState(
    FcdMapDataset dataset,
    FcdMapUpdateResult result,
    String resultName,
  ) async {
    try {
      var source = result.sourceHost;
      if (result is FcdMapUpdateFailed) {
        source = (await store.loadState())?.source ?? '';
      }
      await store.saveState(
        FcdMapState(
          version: dataset.version.toString(),
          source: source,
          lastCheckedAt: DateTime.now().toUtc(),
          result: resultName,
        ),
      );
    } catch (_) {
      // The verified map remains usable even when diagnostic metadata fails.
    }
  }

  Future<FcdMapVersion> _readRemoteVersion(String source) async {
    final bytes = await _get(
      Uri.parse('${source}meta.json'),
      maxBytes: 64 * 1024,
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) {
      throw const FormatException('FCD metadata root must be an array');
    }
    for (final entry in decoded) {
      if (entry is Map<String, dynamic> && entry['name'] == 'map') {
        final version = entry['version'];
        if (version is String) return FcdMapVersion.parse(version);
      }
    }
    throw const FormatException('FCD map metadata is missing');
  }

  Future<FcdMapDataset> _downloadMap(String source) async {
    final bytes = await _get(
      Uri.parse('${source}map.json'),
      maxBytes: maxMapBytes,
    );
    return FcdMapDataset.parse(
      utf8.decode(bytes),
      maxBytes: maxMapBytes,
      minimumMapCount: minimumMapCount,
    );
  }

  Future<List<int>> _get(Uri uri, {required int maxBytes}) async {
    final stopwatch = Stopwatch()..start();
    final allowed = fcdMapUpdateSources.any(
      (source) =>
          uri == Uri.parse('${source}meta.json') ||
          uri == Uri.parse('${source}map.json'),
    );
    if (uri.scheme != 'https' || !allowed) {
      throw FormatException('FCD update URL is not allowed: $uri');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['User-Agent'] = 'Yahagi-Kancolle-Browser/$appVersion';
    final response = await client.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'FCD update request failed with HTTP ${response.statusCode}',
        uri,
      );
    }
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('FCD request exceeded its total deadline');
    }
    return _readResponse(
      response.stream,
      maxBytes: maxBytes,
      remaining: remaining,
    );
  }

  Future<List<int>> _readResponse(
    Stream<List<int>> stream, {
    required int maxBytes,
    required Duration remaining,
  }) {
    final completer = Completer<List<int>>();
    final bytes = <int>[];
    StreamSubscription<List<int>>? subscription;
    late final Timer deadline;
    var terminating = false;

    void fail(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted || terminating) return;
      terminating = true;
      deadline.cancel();
      final cancel = subscription?.cancel() ?? Future<void>.value();
      cancel.whenComplete(() {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace ?? StackTrace.current);
        }
      });
    }

    deadline = Timer(remaining, () {
      fail(TimeoutException('FCD request exceeded its total deadline'));
    });
    subscription = stream.listen(
      (chunk) {
        if (bytes.length + chunk.length > maxBytes) {
          fail(const FormatException('FCD response exceeds the size limit'));
          return;
        }
        bytes.addAll(chunk);
      },
      onError: fail,
      onDone: () {
        if (completer.isCompleted || terminating) return;
        deadline.cancel();
        completer.complete(bytes);
      },
    );
    return completer.future;
  }
}
