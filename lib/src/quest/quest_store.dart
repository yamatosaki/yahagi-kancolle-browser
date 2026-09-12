import '../game_state/game_state.dart';

abstract class QuestStore {
  Future<Map<int, GameQuest>> loadQuests();
  Future<void> saveQuests(Map<int, GameQuest> quests);
  Future<void> clearQuests();
}

abstract interface class AccountQuestStore implements QuestStore {
  QuestStore forAccount(int memberId);
}
