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

  test(
    'SharedPreferencesQuestStore restores F96 without false completion',
    () async {
      final store = SharedPreferencesQuestStore();
      const quests = <int, GameQuest>{
        1101: GameQuest(
          id: 1101,
          title: 'F96',
          detail: '',
          category: 6,
          type: 4,
          state: 2,
          progressFlag: 2,
          progressCurrent: 8,
          progressRequired: 8,
          localCompletionVerified: false,
        ),
      };

      await store.saveQuests(quests);
      final restored = await store.loadQuests();

      expect(restored[1101]?.progressCurrent, 8);
      expect(restored[1101]?.progressRequired, 8);
      expect(restored[1101]?.localCompletionVerified, isFalse);
      expect(restored[1101]?.isCompleted, isFalse);
    },
  );

  test(
    'legacy quest store migrates completion verification by quest',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'yahagi_quests':
            '[{"id":1101,"title":"F96","detail":"","category":6,'
            '"type":4,"state":2,"progressFlag":2,"progressCurrent":8,'
            '"progressRequired":8},{"id":503,"title":"repair quest",'
            '"detail":"","category":5,"type":1,"state":2,'
            '"progressFlag":2,"progressCurrent":5,"progressRequired":5}]',
      });

      final restored = await SharedPreferencesQuestStore().loadQuests();

      expect(restored[1101]?.progressCurrent, 8);
      expect(restored[1101]?.localCompletionVerified, isFalse);
      expect(restored[1101]?.isCompleted, isFalse);
      expect(restored[503]?.progressCurrent, 5);
      expect(restored[503]?.localCompletionVerified, isNull);
      expect(restored[503]?.isCompleted, isTrue);
    },
  );

  for (final entry in <String, String>{
    'null': 'null',
    'wrong type': '"not-a-bool"',
  }.entries) {
    test(
      'corrupt F96 quest-store verification (${entry.key}) is safe',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'yahagi_quests':
              '[{"id":1101,"title":"F96","detail":"","category":6,'
              '"type":4,"state":2,"progressFlag":2,"progressCurrent":8,'
              '"progressRequired":8,"localCompletionVerified":${entry.value}}]',
        });

        final restored = await SharedPreferencesQuestStore().loadQuests();

        expect(restored[1101]?.localCompletionVerified, isFalse);
        expect(restored[1101]?.isCompleted, isFalse);
      },
    );

    test(
      'corrupt ordinary quest-store verification (${entry.key}) keeps semantics',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'yahagi_quests':
              '[{"id":503,"title":"repair quest","detail":"",'
              '"category":5,"type":1,"state":2,"progressFlag":2,'
              '"progressCurrent":5,"progressRequired":5,'
              '"localCompletionVerified":${entry.value}}]',
        });

        final restored = await SharedPreferencesQuestStore().loadQuests();

        expect(restored[503]?.localCompletionVerified, isNull);
        expect(restored[503]?.isCompleted, isTrue);
      },
    );
  }
}
