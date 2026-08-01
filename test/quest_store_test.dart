import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/shared_preferences_quest_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'SharedPreferencesQuestStore saves and loads quests successfully',
    () async {
      final store = SharedPreferencesQuestStore();
      final quests = <int, GameQuest>{
        101: GameQuest(
          id: 101,
          title: 'Test Quest',
          detail: 'Do something',
          category: 1,
          type: 2,
          state: 2,
          progressFlag: 1,
          materials: const [100, 200, 300, 400],
          updatedAt: DateTime.utc(2023, 1, 1),
        ),
      };

      await store.saveQuests(quests);

      final loadedQuests = await store.loadQuests();
      expect(loadedQuests.length, 1);
      expect(loadedQuests[101]?.title, 'Test Quest');
      expect(loadedQuests[101]?.materials, [100, 200, 300, 400]);
      expect(loadedQuests[101]?.updatedAt, DateTime.utc(2023, 1, 1));
    },
  );

  test('SharedPreferencesQuestStore clearQuests removes quests', () async {
    final store = SharedPreferencesQuestStore();
    final quests = <int, GameQuest>{
      101: GameQuest(
        id: 101,
        title: 'Test Quest',
        detail: 'Do something',
        category: 1,
        type: 2,
        state: 2,
        progressFlag: 1,
      ),
    };

    await store.saveQuests(quests);
    await store.clearQuests();

    final loadedQuests = await store.loadQuests();
    expect(loadedQuests.isEmpty, isTrue);
  });
}
