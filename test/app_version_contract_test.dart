import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug and release builds use the 1.10 Beta3 version contract', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      contains(RegExp(r'^version: 1\.10\.0-beta\.3\+32\r?$', multiLine: true)),
    );
  });
}
