import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_display_controller.dart';

void main() {
  test('defaults to auto-hide and persists persistent mode', () async {
    final store = _MemoryToolbarDisplayStore();
    final controller = await GameToolbarDisplayController.load(store);

    expect(controller.mode, GameToolbarDisplayMode.autoHide);

    await controller.setMode(GameToolbarDisplayMode.persistent);

    expect(controller.mode, GameToolbarDisplayMode.persistent);
    expect(store.value, GameToolbarDisplayMode.persistent);
  });
}

final class _MemoryToolbarDisplayStore implements GameToolbarDisplayStore {
  GameToolbarDisplayMode? value;

  @override
  Future<GameToolbarDisplayMode?> read() async => value;

  @override
  Future<void> write(GameToolbarDisplayMode mode) async => value = mode;
}
