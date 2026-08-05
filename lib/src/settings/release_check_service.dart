import 'dart:convert';

import 'package:http/http.dart' as http;

import 'release_version.dart';

sealed class ReleaseCheckResult {
  const ReleaseCheckResult();
}

final class UpdateAvailable extends ReleaseCheckResult {
  const UpdateAvailable({
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.releaseUrl,
  });

  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String releaseUrl;
}

final class AlreadyLatest extends ReleaseCheckResult {
  const AlreadyLatest();
}

final class ReleaseCheckFailed extends ReleaseCheckResult {
  const ReleaseCheckFailed([this.error]);

  final Object? error;
}

abstract interface class ReleaseChecker {
  Future<ReleaseCheckResult> check({required String currentVersion});
}

final class GitHubReleaseChecker implements ReleaseChecker {
  GitHubReleaseChecker({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       endpoint =
           endpoint ??
           Uri.parse(
             'https://api.github.com/repos/yamatosaki/yahagi-kancolle-browser/releases/latest',
           );

  final http.Client _client;
  final Duration timeout;
  final Uri endpoint;

  @override
  Future<ReleaseCheckResult> check({required String currentVersion}) async {
    try {
      final response = await _client.get(endpoint).timeout(timeout);
      if (response.statusCode != 200) {
        return ReleaseCheckFailed(
          StateError('GitHub returned HTTP ${response.statusCode}'),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const ReleaseCheckFailed();
      }
      final tag = decoded['tag_name'];
      final url = decoded['html_url'];
      if (tag is! String ||
          url is! String ||
          !isValidReleaseTag(tag) ||
          !isValidReleaseTag(currentVersion)) {
        return const ReleaseCheckFailed();
      }
      if (!isNewerRelease(tag, currentTag: currentVersion)) {
        return const AlreadyLatest();
      }
      return UpdateAvailable(
        latestVersion: normalizedReleaseVersion(tag),
        releaseName: decoded['name'] is String
            ? decoded['name'] as String
            : normalizedReleaseVersion(tag),
        releaseNotes: decoded['body'] is String
            ? decoded['body'] as String
            : '',
        releaseUrl: url,
      );
    } catch (error) {
      return ReleaseCheckFailed(error);
    }
  }
}
