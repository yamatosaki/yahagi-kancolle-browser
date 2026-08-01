import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flush persists a pending debounced game state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = GameStateStore(saveDelay: const Duration(hours: 1));
    store.save(
      GameState(
        resources: const <GameResourceType, int>{GameResourceType.fuel: 321},
        updatedAt: DateTime.utc(2026),
      ),
    );

    await store.flush();

    final restored = await GameStateStore().load();
    expect(restored.resource(GameResourceType.fuel), 321);
  });
}
