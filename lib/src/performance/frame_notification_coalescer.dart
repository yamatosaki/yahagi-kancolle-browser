import 'dart:async';

import 'package:flutter/scheduler.dart';

typedef FrameNotificationScheduler = void Function(VoidCallback callback);

final class FrameNotificationCoalescer {
  FrameNotificationCoalescer({FrameNotificationScheduler? scheduleFrame})
    : _scheduleFrame = scheduleFrame ?? _scheduleOnFlutterFrame;

  final FrameNotificationScheduler _scheduleFrame;
  bool _pending = false;
  bool _disposed = false;

  void schedule(VoidCallback callback) {
    if (_disposed || _pending) return;
    _pending = true;
    _scheduleFrame(() {
      if (_disposed) return;
      _pending = false;
      callback();
    });
  }

  void dispose() {
    _disposed = true;
    _pending = false;
  }
}

void _scheduleOnFlutterFrame(VoidCallback callback) {
  try {
    final scheduler = SchedulerBinding.instance;
    scheduler.scheduleFrameCallback((_) => callback());
    scheduler.scheduleFrame();
  } catch (_) {
    // Pure unit tests and headless consumers may not install a Flutter binding.
    scheduleMicrotask(callback);
  }
}
