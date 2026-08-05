/// Polite single-concurrency fetcher for akashi-list.me with retry/backoff
/// and a content-hash cache.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

class FetchResult {
  final int statusCode;
  final String body;
  final String? lastModified;
  final String? etag;
  final String sha256;

  const FetchResult({
    required this.statusCode,
    required this.body,
    required this.sha256,
    this.lastModified,
    this.etag,
  });
}

class FetchStopException implements Exception {
  final int statusCode;
  final String reason;
  FetchStopException(this.statusCode, this.reason);
  @override
  String toString() => 'FetchStopException($statusCode): $reason';
}

/// The detail page does not exist (404/410): the equipment is listed on the
/// homepage but has no page. Recorded as `sourceStatus: missing` instead of
/// stopping the crawl.
class FetchMissingException implements Exception {
  final int statusCode;
  FetchMissingException(this.statusCode);
  @override
  String toString() => 'FetchMissingException($statusCode)';
}

/// Fetches pages with a fixed 1s gap between requests, exponential backoff
/// on 429/503, and hard stop on 403/5xx/redirect-to-captcha.
class AkashiFetcher {
  final String userAgent;
  final String cacheDir;
  final HttpClient _client;
  final DateTime Function() now;

  AkashiFetcher({
    this.userAgent = 'YahagiKancolleBonusDatasetBuilder/1.0 (+https://github.com/)',
    required this.cacheDir,
    DateTime Function()? now,
  })  : _client = HttpClient()..connectionTimeout = const Duration(seconds: 30),
        now = now ?? DateTime.now;

  Duration _lastRequestAt = Duration.zero;

  Future<void> _politeDelay() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _lastRequestAt.inMilliseconds;
    if (_lastRequestAt != Duration.zero && elapsed < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed));
    }
    _lastRequestAt = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
  }

  /// Reads a cached page with its metadata; returns null when absent.
  FetchResult? readCache(String key) {
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) return null;
    final bodyFile = File('$cacheDir\\$key.html');
    final metaFile = File('$cacheDir\\$key.meta.json');
    if (!bodyFile.existsSync() || !metaFile.existsSync()) return null;
    try {
      final meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final body = bodyFile.readAsStringSync();
      return FetchResult(
        statusCode: 200,
        body: body,
        sha256: (meta['sha256'] as String?) ?? '',
        lastModified: meta['lastModified'] as String?,
        etag: meta['etag'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void writeCache(String key, FetchResult result) {
    final dir = Directory(cacheDir);
    dir.createSync(recursive: true);
    File('$cacheDir\\$key.html').writeAsStringSync(result.body);
    File('$cacheDir\\$key.meta.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'sha256': result.sha256,
        'lastModified': result.lastModified,
        'etag': result.etag,
        'fetchedAt': now().toIso8601String(),
      }),
    );
  }

  /// Fetches [url] with retry/backoff, optionally reusing the cache when the
  /// server content is unchanged.
  Future<FetchResult> fetch(
    String url, {
    bool useCache = true,
    required String cacheKey,
  }) async {
    if (useCache) {
      final cached = readCache(cacheKey);
      if (cached != null) return cached;
    }
    var attempt = 0;
    while (true) {
      attempt++;
      await _politeDelay();
      final req = await _client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', userAgent);
      req.headers.set('Accept', 'text/html,application/json;q=0.9,*/*;q=0.8');
      final cached = readCache(cacheKey);
      if (cached != null && (cached.etag != null || cached.lastModified != null)) {
        if (cached.etag != null) {
          req.headers.set('If-None-Match', cached.etag!);
        } else if (cached.lastModified != null) {
          req.headers.set('If-Modified-Since', cached.lastModified!);
        }
      }
      final res = await req.close();
      if (res.statusCode == 304 && cached != null) {
        await res.drain<void>();
        return cached;
      }
      if (res.statusCode == 429 || res.statusCode == 503) {
        await res.drain<void>();
        if (attempt >= 3) {
          throw FetchStopException(
              res.statusCode, 'retries exhausted after $attempt attempts');
        }
        final wait = 30 * (1 << (attempt - 1)); // 30, 60, 120
        stdout.writeln('  HTTP ${res.statusCode} on $url, backing off ${wait}s');
        await Future.delayed(Duration(seconds: wait));
        continue;
      }
      if (res.statusCode == 403 || res.statusCode >= 500) {
        await res.drain<void>();
        throw FetchStopException(
            res.statusCode, 'site refused access / server error');
      }
      if (res.statusCode == 404 || res.statusCode == 410) {
        await res.drain<void>();
        throw FetchMissingException(res.statusCode);
      }
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw FetchStopException(
            res.statusCode, 'unexpected status ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      final etag = res.headers.value('etag');
      final lastModified = res.headers.value('last-modified');
      final result = FetchResult(
        statusCode: 200,
        body: body,
        sha256: 'sha256:${_sha256(body)}',
        lastModified: lastModified,
        etag: etag,
      );
      writeCache(cacheKey, result);
      return result;
    }
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  void close() {
    _client.close(force: true);
  }
}

/// Convenience wrapper for tests.
String sha256Hex(String input) =>
    sha256.convert(utf8.encode(input)).toString();
