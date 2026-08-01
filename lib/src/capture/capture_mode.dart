enum CaptureMode {
  game,
  browserOnly;

  String get storageValue => switch (this) {
    CaptureMode.game => 'game',
    CaptureMode.browserOnly => 'browserOnly',
  };

  bool get installsGameBridge => this == CaptureMode.game;

  String get title => switch (this) {
    CaptureMode.game => '游戏模式（默认）',
    CaptureMode.browserOnly => '纯浏览模式',
  };

  String get description => switch (this) {
    CaptureMode.game => '只读解析游戏接口，用于舰队、任务和战斗信息；不会替你操作。',
    CaptureMode.browserOnly => '不读取游戏接口，仅显示游戏网页；信息功能将暂停更新。',
  };

  static CaptureMode? fromStorageValue(String? value) {
    return switch (value) {
      'game' => CaptureMode.game,
      'browserOnly' => CaptureMode.browserOnly,
      _ => null,
    };
  }
}
