import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_check_service.dart';

void main() {
  test(
    'new two-part releases upgrade old versions and canonical betas',
    () async {
      final checker = GitHubReleaseChecker(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': 'v1.10',
              'html_url': 'https://example.test/releases/v1.10',
            }),
            200,
          ),
        ),
      );
      for (final current in ['1.0.9', '1.10.0-beta.1', '1.10-beta10']) {
        final result = await checker.check(currentVersion: current);
        expect(result, isA<UpdateAvailable>(), reason: current);
        expect((result as UpdateAvailable).latestVersion, '1.10');
      }
      expect(
        await checker.check(currentVersion: '1.10.0'),
        isA<AlreadyLatest>(),
      );
    },
  );

  test(
    'compact beta release numbering upgrades canonical betas numerically',
    () async {
      final checker = GitHubReleaseChecker(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': 'v1.10-beta10',
              'html_url': 'https://example.test/releases/v1.10-beta10',
            }),
            200,
          ),
        ),
      );
      final result = await checker.check(currentVersion: '1.10.0-beta.2');
      expect(result, isA<UpdateAvailable>());
      expect((result as UpdateAvailable).latestVersion, '1.10-beta10');
      expect(
        await checker.check(currentVersion: '1.10.0-beta.10'),
        isA<AlreadyLatest>(),
      );
    },
  );

  test('1.0.9 stable is offered to every published 1.0.9 beta', () async {
    final checker = GitHubReleaseChecker(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'tag_name': 'v1.0.9',
            'name': '1.0.9',
            'html_url': 'https://example.test/releases/v1.0.9',
          }),
          200,
        ),
      ),
    );

    for (var beta = 1; beta <= 7; beta++) {
      final result = await checker.check(currentVersion: '1.0.9-beta.$beta');
      expect(result, isA<UpdateAvailable>());
      expect((result as UpdateAvailable).latestVersion, '1.0.9');
    }
    expect(await checker.check(currentVersion: '1.0.9'), isA<AlreadyLatest>());
  });

  test('returns update only for a newer valid release tag', () async {
    final checker = GitHubReleaseChecker(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'tag_name': 'v1.0.2',
            'name': '1.0.2',
            'body': 'notes',
            'html_url': 'https://example.test/release',
          }),
          200,
        ),
      ),
    );

    final result = await checker.check(currentVersion: '1.0.1');

    expect(result, isA<UpdateAvailable>());
    expect((result as UpdateAvailable).latestVersion, '1.0.2');
  });

  test(
    'same, lower, malformed, and failed responses do not report updates',
    () async {
      for (final tag in <String>['v1.0.1', 'v1.0.0']) {
        final checker = GitHubReleaseChecker(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(<String, Object?>{
                'tag_name': tag,
                'html_url': 'https://example.test/release',
              }),
              200,
            ),
          ),
        );
        expect(
          await checker.check(currentVersion: '1.0.1'),
          isA<AlreadyLatest>(),
        );
      }

      for (final response in <http.Response>[
        http.Response('{}', 500),
        http.Response('{broken', 200),
        http.Response(
          jsonEncode(<String, String>{'tag_name': 'release-1.0.2'}),
          200,
        ),
      ]) {
        final checker = GitHubReleaseChecker(
          client: MockClient((_) async => response),
        );
        expect(
          await checker.check(currentVersion: '1.0.1'),
          isA<ReleaseCheckFailed>(),
        );
      }
    },
  );
}
