import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enables Flutter HCPP inside the Android application node', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final application = RegExp(
      r'<application\b[\s\S]*?</application>',
    ).firstMatch(manifest)?.group(0);

    expect(application, isNotNull);
    expect(
      RegExp(
        r'<meta-data\b(?=[^>]*android:name="io\.flutter\.embedding\.android\.EnableHcpp")(?=[^>]*android:value="true")[^>]*/?>',
      ).hasMatch(application!),
      isTrue,
    );
  });
}
