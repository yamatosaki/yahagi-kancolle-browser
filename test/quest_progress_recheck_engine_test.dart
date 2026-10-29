import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise a real SharedPreferences write that reports failure without throwing.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';

import 'quest_progress_engine_test.dart' as existing;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a false platform save result remains retryable after rule adoption',
    () async {
      final platform = _ControlledPreferences()..fail = true;
      SharedPreferencesStorePlatform.instance = platform;
      final engine = QuestProgressEngine(
        goals: {},
        storage: PreferencesQuestProgressStorage(),
      );
      final now = DateTime.utc(2026, 10, 29);
      var state = await engine.restore(existing.sample(now, id: 99990), now);
      final goals = {
        99990: QuestProgressGoal(99990, {
          'type': 0,
          'create_item': {'required': 3, 'init': 1},
        }),
      };

      state = await engine.replaceGoals(state, goals, now);
      expect(state.quests[99990]!.exactProgressLabel, '1/3');
      expect(platform.writes, 1);
      expect(engine.persistenceError, isNotNull);

      platform.fail = false;
      state = await engine.replaceGoals(state, goals, now);
      expect(platform.writes, 2);
      expect(engine.persistenceError, isNull);
      await (await SharedPreferences.getInstance()).reload();
      final restarted = QuestProgressEngine(
        goals: goals,
        storage: PreferencesQuestProgressStorage(),
      );
      final restored = await restarted.restore(state, now);
      expect(restored.quests[99990]!.exactProgressLabel, '1/3');
    },
  );
}

class _ControlledPreferences extends InMemorySharedPreferencesStore {
  _ControlledPreferences() : super.withData({});
  bool fail = false;
  int writes = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes++;
    if (fail) return false;
    return super.setValue(valueType, key, value);
  }
}
