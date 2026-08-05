import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/adaptive_layout.dart';

void main() {
  test('screen classes share one compact, square, and wide rule', () {
    expect(
      classifyAdaptiveWindow(const Size(412, 915)),
      AdaptiveWindowClass.compact,
    );
    expect(
      classifyAdaptiveWindow(const Size(673, 841)),
      AdaptiveWindowClass.nearSquareLarge,
    );
    expect(
      classifyAdaptiveWindow(const Size(1280, 800)),
      AdaptiveWindowClass.wideLarge,
    );
  });

  test(
    'near-square displays keep the vertical workspace after a 90 degree turn',
    () {
      expect(usesVerticalWorkspace(const Size(673, 841)), isTrue);
      expect(usesVerticalWorkspace(const Size(841, 673)), isTrue);
      expect(usesVerticalWorkspace(const Size(800, 1280)), isTrue);
      expect(usesVerticalWorkspace(const Size(1280, 800)), isFalse);
    },
  );
}
