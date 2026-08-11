import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';

void main() {
  test('coalesces repeated notifications into one frame callback', () {
    final scheduled = <VoidCallback>[];
    final coalescer = FrameNotificationCoalescer(scheduleFrame: scheduled.add);
    var calls = 0;

    coalescer
      ..schedule(() => calls += 1)
      ..schedule(() => calls += 1);

    expect(scheduled, hasLength(1));
    expect(calls, 0);
    scheduled.removeAt(0)();
    expect(calls, 1);
  });

  test('allows another notification on the following frame', () {
    final scheduled = <VoidCallback>[];
    final coalescer = FrameNotificationCoalescer(scheduleFrame: scheduled.add);
    var calls = 0;

    coalescer.schedule(() => calls += 1);
    scheduled.removeAt(0)();
    coalescer.schedule(() => calls += 1);
    scheduled.removeAt(0)();

    expect(calls, 2);
  });

  test('dispose cancels queued and future notifications', () {
    final scheduled = <VoidCallback>[];
    final coalescer = FrameNotificationCoalescer(scheduleFrame: scheduled.add);
    var calls = 0;

    coalescer.schedule(() => calls += 1);
    coalescer.dispose();
    scheduled.removeAt(0)();
    coalescer.schedule(() => calls += 1);

    expect(calls, 0);
    expect(scheduled, isEmpty);
  });
}
