import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_version.dart';

void main() {
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
