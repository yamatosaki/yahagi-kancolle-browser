import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';

void main() {
  test('standard mode keeps the current texture WebGL path', () {
    const mode = GameRenderingMode.standard;

    expect(mode.usesHybridComposition, isFalse);
    expect(mode.usesCanvasRenderer, isFalse);
    expect(mode.enablesToolbarBlur, isTrue);
  });

  test('compatibility mode uses hybrid WebGL without toolbar blur', () {
    const mode = GameRenderingMode.compatibility;

    expect(mode.usesHybridComposition, isTrue);
    expect(mode.usesCanvasRenderer, isFalse);
    expect(mode.enablesToolbarBlur, isFalse);
  });

  test('canvas compatibility mode uses hybrid Canvas without blur', () {
    const mode = GameRenderingMode.canvasCompatibility;

    expect(mode.usesHybridComposition, isTrue);
    expect(mode.usesCanvasRenderer, isTrue);
    expect(mode.enablesToolbarBlur, isFalse);
  });

  test('stored names round-trip and invalid values fall back to standard', () {
    for (final mode in GameRenderingMode.values) {
      expect(GameRenderingModeCodec.decode(mode.storageName), mode);
    }

    expect(GameRenderingModeCodec.decode(null), GameRenderingMode.standard);
    expect(GameRenderingModeCodec.decode('broken'), GameRenderingMode.standard);
  });
}
