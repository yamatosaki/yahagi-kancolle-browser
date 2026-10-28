import '../game_state/game_state.dart';

/// Counts active completions and remembers alerts for the current quest period.
/// Missing pages or server confirmation of local progress must not replay alerts.
class QuestCompletionTracker {
  QuestCompletionTracker(
    GameState initial, {
    required DateTime now,
    this.periodFor,
  }) : _memberId = initial.memberId {
    _seed(initial, now);
  }

  final String Function(GameQuest, DateTime)? periodFor;
  int _memberId;
  final Map<int, GameQuest> _announced = {};
  int completedCount = 0;
  List<GameQuest> _latestCompletedQuests = [];
  List<GameQuest> get latestCompletedQuests =>
      List.unmodifiable(_latestCompletedQuests);

  /// A prediction rejected before its alert was displayed may complete later.
  void cancelPendingAlert(int questId) => _announced.remove(questId);

  Iterable<GameQuest> _completed(GameState state, DateTime now) =>
      state.quests.values.where(
        (quest) =>
            quest.isAccepted && quest.isCompleted && !quest.isExpired(now),
      );

  void _seed(GameState state, DateTime now) {
    _announced.clear();
    _latestCompletedQuests = [];
    final completed = _completed(state, now).toList();
    completedCount = completed.length;
    for (final quest in completed) {
      _announced[quest.id] = quest;
    }
  }

  /// Returns true only if at least one previously unannounced task completed.
  bool update(GameState state, {required DateTime now}) {
    if (state.memberId != _memberId) {
      _memberId = state.memberId;
      _seed(state, now);
      return false;
    }
    _announced.removeWhere(
      (_, quest) =>
          quest.isExpired(now) ||
          (periodFor != null &&
              quest.updatedAt != null &&
              periodFor!(quest, quest.updatedAt!) != periodFor!(quest, now)),
    );
    final completed = _completed(state, now).toList();
    completedCount = completed.length;
    _latestCompletedQuests = [];
    var newlyCompleted = false;
    for (final quest in completed) {
      if (!_announced.containsKey(quest.id)) {
        _announced[quest.id] = quest;
        _latestCompletedQuests.add(quest);
        newlyCompleted = true;
      }
    }
    return newlyCompleted;
  }
}
