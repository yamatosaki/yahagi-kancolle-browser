import 'dart:async';

import 'package:flutter/foundation.dart';

enum GameSurfaceStage { localPrototype, login, game }

final class GameToolbarController extends ChangeNotifier {
  GameToolbarController({this.autoHideDuration = const Duration(seconds: 5)}) {
    _scheduleAutoHide();
  }

  final Duration autoHideDuration;

  GameSurfaceStage _stage = GameSurfaceStage.localPrototype;
  bool _isVisible = true;
  Timer? _autoHideTimer;

  GameSurfaceStage get stage => _stage;
  bool get isVisible => _isVisible;

  void onStageChanged(GameSurfaceStage stage) {
    if (_stage == stage) {
      return;
    }
    _stage = stage;
    if (stage == GameSurfaceStage.game) {
      collapse();
    } else {
      reveal();
    }
  }

  void reveal() {
    _setVisible(true);
    _scheduleAutoHide();
  }

  void collapse() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _setVisible(false);
  }

  void beginInteraction() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void endInteraction() {
    if (_isVisible) {
      _scheduleAutoHide();
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(autoHideDuration, collapse);
  }

  void _setVisible(bool visible) {
    if (_isVisible == visible) {
      return;
    }
    _isVisible = visible;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }
}
