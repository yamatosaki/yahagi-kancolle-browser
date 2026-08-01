import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_version.dart';

void main() {
  test('compares release tags by semantic version precedence', () {
    expect(isNewerRelease('v1.10.0', currentTag: 'v1.9.0'), isTrue);
    expect(isNewerRelease('v2.0.0', currentTag: 'v10.0.0'), isFalse);
    expect(isNewerRelease('v1.0.0', currentTag: 'v1.0.0-demo.1'), isTrue);
    expect(isNewerRelease('v1.0.0-demo.2', currentTag: 'v1.0.0'), isFalse);
    expect(isNewerRelease('unexpected', currentTag: 'v1.0.0'), isFalse);
  });
}
