import '../settings/game_frame_rate_settings.dart';

enum FrameRateDecision { keep60, downgradeTo30, lock30 }

final class GameFrameRatePolicy {
  GameFrameRatePolicy({required this.mode});

  GameFrameRateMode mode;
  final List<double> _createJsSamples = <double>[];
  int _flutterFrameCount = 0;
  int _slowFlutterFrameCount = 0;
  int _consecutiveUnstableWindows = 0;
  bool _lockedTo30 = false;

  bool get isLockedTo30 => _lockedTo30;
  int get flutterFrameCount => _flutterFrameCount;

  void setMode(GameFrameRateMode mode) {
    if (this.mode == mode) return;
    this.mode = mode;
    resetWindow();
    _consecutiveUnstableWindows = 0;
  }

  void addCreateJsSample(double fps) {
    if (!fps.isFinite || fps < 0) return;
    _createJsSamples.add(fps);
  }

  void addFlutterFrame(Duration totalSpan) {
    _flutterFrameCount += 1;
    if (totalSpan > const Duration(milliseconds: 32)) {
      _slowFlutterFrameCount += 1;
    }
  }

  FrameRateDecision completeWindow() {
    if (mode == GameFrameRateMode.stable30 || _lockedTo30) {
      resetWindow();
      return FrameRateDecision.lock30;
    }
    if (mode == GameFrameRateMode.prefer60) {
      resetWindow();
      _consecutiveUnstableWindows = 0;
      return FrameRateDecision.keep60;
    }

    final createJsUnstable =
        _createJsSamples.length >= 4 &&
        _createJsSamples.where((fps) => fps < 50).length >= 3;
    final flutterUnstable =
        _flutterFrameCount >= 10 &&
        _slowFlutterFrameCount / _flutterFrameCount >= 0.2;
    if (createJsUnstable || flutterUnstable) {
      _consecutiveUnstableWindows += 1;
    } else {
      _consecutiveUnstableWindows = 0;
    }
    resetWindow();

    if (_consecutiveUnstableWindows >= 2) {
      _lockedTo30 = true;
      return FrameRateDecision.downgradeTo30;
    }
    return FrameRateDecision.keep60;
  }

  void resetWindow() {
    _createJsSamples.clear();
    _flutterFrameCount = 0;
    _slowFlutterFrameCount = 0;
  }
}
