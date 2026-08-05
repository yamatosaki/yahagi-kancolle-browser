import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';

void main() {
  test('默认自动，修改后持久化', () async {
    final store = MemoryDisplayModeStore();
    final controller = await DisplayModeController.load(store);
    expect(controller.displayMode, DisplayMode.auto);

    await controller.setDisplayMode(DisplayMode.landscape);
    expect(controller.displayMode, DisplayMode.landscape);

    final reloaded = await DisplayModeController.load(store);
    expect(reloaded.displayMode, DisplayMode.landscape);

    await reloaded.setDisplayMode(DisplayMode.portrait);
    expect(reloaded.displayMode, DisplayMode.portrait);
  });
}
