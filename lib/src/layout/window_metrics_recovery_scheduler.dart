import 'dart:async';

import 'package:flutter/foundation.dart';

/// Rechecks responsive layout after fold, rotation, PiP, and multi-window
/// animations. Recovery runs once after the latest change has been quiet for
/// 200ms, rather than repeatedly fitting intermediate window dimensions.
class WindowMetricsRecoveryScheduler {
  Timer? _timer;
  bool _disposed = false;

  void schedule(VoidCallback recover) {
    if (_disposed) return;
    _cancelTimer();
    _timer = Timer(const Duration(milliseconds: 200), () {
      _timer = null;
      if (!_disposed) recover();
    });
  }

  void cancel() {
    if (_disposed) return;
    _cancelTimer();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
