import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:yahagi_kancolle_browser/src/layout/window_metrics_change.dart';

void main() {
  test('system bar visibility alone does not resize the window', () {
    const hidden = WindowMetricsSnapshot(
      physicalSize: Size(1220, 824),
      devicePixelRatio: 3.25,
      imeBottom: 0,
    );
    for (final padding in const [
      EdgeInsets.only(bottom: 52),
      EdgeInsets.only(right: 52),
    ]) {
      final shown = WindowMetricsSnapshot(
        physicalSize: hidden.physicalSize,
        devicePixelRatio: hidden.devicePixelRatio,
        imeBottom: 0,
        viewPadding: padding,
      );
      expect(classifyWindowMetricsChange(hidden, shown).name, 'insetsOnly');
      expect(classifyWindowMetricsChange(shown, hidden).name, 'insetsOnly');
      final tracker = WindowMetricsChangeTracker(hidden);
      expect(tracker.update(shown).name, 'insetsOnly');
      expect(tracker.update(hidden).name, 'insetsOnly');
    }
  });

  test('180-degree cutout and safe-inset swaps count as geometry changes', () {
    final left = WindowMetricsSnapshot(
      physicalSize: const Size(2400, 1080),
      devicePixelRatio: 3,
      imeBottom: 0,
      viewPadding: const EdgeInsets.only(left: 96),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(12, 480, 72, 72),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ],
    );
    final right = WindowMetricsSnapshot(
      physicalSize: const Size(2400, 1080),
      devicePixelRatio: 3,
      imeBottom: 0,
      viewPadding: const EdgeInsets.only(right: 96),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(2316, 480, 72, 72),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ],
    );
    expect(
      classifyWindowMetricsChange(left, right),
      WindowMetricsChange.geometry,
    );
    final noInset = WindowMetricsSnapshot(
      physicalSize: left.physicalSize,
      devicePixelRatio: 3,
      imeBottom: 0,
      displayFeatures: right.displayFeatures,
    );
    final noInsetOld = WindowMetricsSnapshot(
      physicalSize: left.physicalSize,
      devicePixelRatio: 3,
      imeBottom: 0,
      displayFeatures: left.displayFeatures,
    );
    expect(
      classifyWindowMetricsChange(noInsetOld, noInset),
      WindowMetricsChange.geometry,
    );
  });

  const original = WindowMetricsSnapshot(
    physicalSize: Size(1080, 2400),
    devicePixelRatio: 3,
    imeBottom: 0,
  );

  test('classifies equal metrics as unchanged', () {
    expect(
      classifyWindowMetricsChange(original, original),
      WindowMetricsChange.unchanged,
    );
  });

  test('classifies an IME inset-only transition without geometry recovery', () {
    const keyboardOpen = WindowMetricsSnapshot(
      physicalSize: Size(1080, 2400),
      devicePixelRatio: 3,
      imeBottom: 900,
    );

    expect(
      classifyWindowMetricsChange(original, keyboardOpen),
      WindowMetricsChange.imeOnly,
    );
    expect(
      classifyWindowMetricsChange(keyboardOpen, original),
      WindowMetricsChange.imeOnly,
    );
  });

  test(
    'IME transitions take precedence over simultaneous geometry changes',
    () {
      const foldableKeyboardOpen = WindowMetricsSnapshot(
        physicalSize: Size(1768, 2208),
        devicePixelRatio: 2.625,
        imeBottom: 840,
      );

      expect(
        classifyWindowMetricsChange(original, foldableKeyboardOpen),
        WindowMetricsChange.imeOnly,
      );
      expect(
        classifyWindowMetricsChange(foldableKeyboardOpen, original),
        WindowMetricsChange.imeOnly,
      );
    },
  );

  test('classifies physical size and DPR transitions as geometry changes', () {
    expect(
      classifyWindowMetricsChange(
        original,
        const WindowMetricsSnapshot(
          physicalSize: Size(2400, 1080),
          devicePixelRatio: 3,
          imeBottom: 0,
        ),
      ),
      WindowMetricsChange.geometry,
    );
    expect(
      classifyWindowMetricsChange(
        original,
        const WindowMetricsSnapshot(
          physicalSize: Size(1080, 2400),
          devicePixelRatio: 2.75,
          imeBottom: 0,
        ),
      ),
      WindowMetricsChange.geometry,
    );
  });

  test(
    'suppresses foldable geometry fluctuations for the whole IME session',
    () {
      const unfolded = WindowMetricsSnapshot(
        physicalSize: Size(1768, 2208),
        devicePixelRatio: 2.625,
        imeBottom: 0,
      );
      final tracker = WindowMetricsChangeTracker(unfolded);

      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2176),
            devicePixelRatio: 2.625,
            imeBottom: 840,
          ),
        ),
        WindowMetricsChange.imeOnly,
      );
      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2144),
            devicePixelRatio: 2.625,
            imeBottom: 840,
          ),
        ),
        WindowMetricsChange.imeOnly,
      );
      expect(tracker.update(unfolded), WindowMetricsChange.imeOnly);
    },
  );

  test('recovers a real geometry change after the IME closes', () {
    const unfolded = WindowMetricsSnapshot(
      physicalSize: Size(1768, 2208),
      devicePixelRatio: 2.625,
      imeBottom: 0,
    );
    final tracker = WindowMetricsChangeTracker(unfolded);

    tracker.update(
      const WindowMetricsSnapshot(
        physicalSize: Size(1768, 2176),
        devicePixelRatio: 2.625,
        imeBottom: 840,
      ),
    );
    tracker.update(
      const WindowMetricsSnapshot(
        physicalSize: Size(2208, 1768),
        devicePixelRatio: 2.625,
        imeBottom: 840,
      ),
    );

    expect(
      tracker.update(
        const WindowMetricsSnapshot(
          physicalSize: Size(2208, 1768),
          devicePixelRatio: 2.625,
          imeBottom: 0,
        ),
      ),
      WindowMetricsChange.geometry,
    );
  });

  test(
    'uses stable geometry when a size event arrives just before the IME',
    () {
      const unfolded = WindowMetricsSnapshot(
        physicalSize: Size(1768, 2208),
        devicePixelRatio: 2.625,
        imeBottom: 0,
      );
      final tracker = WindowMetricsChangeTracker(unfolded);

      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2176),
            devicePixelRatio: 2.625,
            imeBottom: 0,
          ),
        ),
        WindowMetricsChange.geometry,
      );
      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2176),
            devicePixelRatio: 2.625,
            imeBottom: 840,
          ),
        ),
        WindowMetricsChange.imeOnly,
      );

      expect(tracker.update(unfolded), WindowMetricsChange.imeOnly);
    },
  );
}
