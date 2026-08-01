import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';

void main() {
  test('starts expanded and hides after five seconds of inactivity', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );

      expect(controller.stage, GameSurfaceStage.localPrototype);
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 4));
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('applies the default visibility only when the stage changes', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );

      controller.onStageChanged(GameSurfaceStage.game);
      expect(controller.isVisible, isFalse);

      controller.onStageChanged(GameSurfaceStage.login);
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 4));
      controller.onStageChanged(GameSurfaceStage.login);
      async.elapse(const Duration(seconds: 1));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('interaction pauses and restarts the auto-hide countdown', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );

      async.elapse(const Duration(seconds: 4));
      controller.beginInteraction();
      async.elapse(const Duration(seconds: 10));
      expect(controller.isVisible, isTrue);

      controller.endInteraction();
      async.elapse(const Duration(seconds: 4));
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });

  test('revealing and collapsing control visibility immediately', () {
    fakeAsync((async) {
      final controller = GameToolbarController(
        autoHideDuration: const Duration(seconds: 5),
      );

      controller.collapse();
      expect(controller.isVisible, isFalse);

      controller.reveal();
      expect(controller.isVisible, isTrue);

      async.elapse(const Duration(seconds: 5));
      expect(controller.isVisible, isFalse);
      controller.dispose();
    });
  });
}
