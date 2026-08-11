enum GameRenderingMode {
  standard,
  compatibility,
  canvasCompatibility;

  bool get usesHybridComposition => this != standard;

  bool get usesCanvasRenderer => this == canvasCompatibility;

  bool get enablesToolbarBlur => this == standard;

  String get storageName => name;
}

abstract final class GameRenderingModeCodec {
  static GameRenderingMode decode(String? value) {
    for (final mode in GameRenderingMode.values) {
      if (mode.storageName == value) return mode;
    }
    return GameRenderingMode.standard;
  }
}
