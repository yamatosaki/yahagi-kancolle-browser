import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_version.dart';

void main() {
  test('display labels omit zero patches and render numbered beta aliases', () {
    const labels = {
      '1.10.0-beta.1': '1.10 Beta1',
      'v1.10-beta1': '1.10 Beta1',
      '1.10.0-beta10+30': '1.10 Beta10',
      '1.10.0': '1.10',
      'v1.11': '1.11',
      '1.0.9': '1.0.9',
      '1.0.9-beta.7': '1.0.9 Beta7',
      '1.10.1-beta.2': '1.10.1 Beta2',
      '1.10.0-rc.1+30': '1.10-rc.1',
    };
    for (final entry in labels.entries) {
      expect(displayReleaseVersion(entry.key), entry.value);
    }
    for (final value in [
      '',
      'unknown',
      '  custom release title  ',
      '1.10-beta..1',
    ]) {
      expect(displayReleaseVersion(value), value);
    }
    expect(normalizedReleaseVersion(' v1.10.0-beta.1+30 '), '1.10.0-beta.1+30');
  });

  test('other prerelease identifiers retain semantic precedence', () {
    const ordered = [
      '1.10-alpha',
      '1.10-alpha.2',
      '1.10-alpha.10',
      '1.10-beta.1',
      '1.10-rc.1',
      '1.10',
    ];
    for (var index = 1; index < ordered.length; index++) {
      expect(
        isNewerRelease(ordered[index], currentTag: ordered[index - 1]),
        isTrue,
      );
    }
    expect(isNewerRelease('1.10-alpha', currentTag: '1.10-1'), isTrue);
  });

  test(
    'two-part releases follow old patches and compare numeric minor versions',
    () {
      expect(isNewerRelease('v1.10-beta1', currentTag: '1.0.9'), isTrue);
      expect(isNewerRelease('v1.10', currentTag: '1.9'), isTrue);
      expect(isNewerRelease('v1.11-beta.1', currentTag: '1.10'), isTrue);
      expect(isNewerRelease('v1.11', currentTag: '1.11-beta1'), isTrue);
      expect(isNewerRelease('v1.10', currentTag: '1.11'), isFalse);
    },
  );

  test('omitted patch and compact beta aliases have identical precedence', () {
    const aliases = [
      'v1.10-beta1',
      '1.10-beta.1',
      '1.10.0-beta1',
      '1.10.0-beta.1',
    ];
    for (final left in aliases) {
      expect(isValidReleaseTag(left), isTrue, reason: left);
      for (final right in aliases) {
        expect(
          isNewerRelease(left, currentTag: right),
          isFalse,
          reason: '$left = $right',
        );
      }
    }
    expect(isNewerRelease('1.10', currentTag: '1.10.0'), isFalse);
    expect(isNewerRelease('1.10.0', currentTag: '1.10'), isFalse);
  });

  test('beta numbering is numeric across compact and dotted spellings', () {
    const ordered = [
      '1.10-beta1',
      '1.10-beta.2',
      '1.10-beta10',
      '1.10-beta.11',
      '1.10',
    ];
    for (var left = 0; left < ordered.length; left++) {
      for (var right = 0; right < ordered.length; right++) {
        expect(
          isNewerRelease(ordered[left], currentTag: ordered[right]),
          left > right,
          reason: '${ordered[left]} versus ${ordered[right]}',
        );
      }
    }
    expect(isNewerRelease('1.0.9-beta10', currentTag: '1.0.9-beta2'), isTrue);
    expect(isNewerRelease('1.10.1', currentTag: '1.10'), isTrue);
    expect(
      isNewerRelease('1.10.0-beta.1+30', currentTag: '1.10-beta1+29'),
      isFalse,
    );
  });

  test('invalid and overflowing versions fail validation without throwing', () {
    for (final value in [
      '1',
      '1.10.',
      '1.10-beta..1',
      '1.10-beta.',
      '1.10+build..1',
      '1.10 Beta1',
      '999999999999999999999999999999.10.0',
    ]) {
      expect(isValidReleaseTag(value), isFalse, reason: value);
      expect(
        isNewerRelease(value, currentTag: '1.0.9'),
        isFalse,
        reason: value,
      );
    }
  });

  test('1.0.9 stable supersedes 1.0.8 and every published 1.0.9 beta', () {
    expect(isNewerRelease('v1.0.9', currentTag: 'v1.0.8'), isTrue);
    for (var beta = 1; beta <= 7; beta++) {
      expect(isNewerRelease('v1.0.9', currentTag: 'v1.0.9-beta.$beta'), isTrue);
      expect(
        isNewerRelease('v1.0.9-beta.$beta', currentTag: 'v1.0.9'),
        isFalse,
      );
    }
    expect(isNewerRelease('v1.0.9', currentTag: 'v1.0.9'), isFalse);
  });

  test('1.0.8 stable supersedes 1.0.7 and every 1.0.8 beta', () {
    expect(isNewerRelease('v1.0.8', currentTag: 'v1.0.7'), isTrue);
    for (var beta = 1; beta <= 5; beta++) {
      expect(isNewerRelease('v1.0.8', currentTag: 'v1.0.8-beta.$beta'), isTrue);
    }
  });

  test('1.0.6 beta1 upgrades 1.0.5 and yields to 1.0.6 stable', () {
    expect(isNewerRelease('v1.0.6-beta1', currentTag: 'v1.0.5'), isTrue);
    expect(isNewerRelease('v1.0.6', currentTag: 'v1.0.6-beta1'), isTrue);
    expect(isNewerRelease('v1.0.5', currentTag: 'v1.0.6-beta1'), isFalse);
  });
  test('compares release tags by semantic version precedence', () {
    expect(isNewerRelease('v1.0.1', currentTag: 'v1.0.0'), isTrue);
    expect(isNewerRelease('v1.0.1', currentTag: 'v1.0.1'), isFalse);
    expect(isNewerRelease('v1.10.0', currentTag: 'v1.9.0'), isTrue);
    expect(isNewerRelease('v2.0.0', currentTag: 'v10.0.0'), isFalse);
    expect(isNewerRelease('v1.0.0', currentTag: 'v1.0.0-demo.1'), isTrue);
    expect(isNewerRelease('v1.0.0-demo.2', currentTag: 'v1.0.0'), isFalse);
    expect(isNewerRelease('unexpected', currentTag: 'v1.0.0'), isFalse);
  });
}
