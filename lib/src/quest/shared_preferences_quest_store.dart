import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../game_state/game_state.dart';
import 'quest_store.dart';

class SharedPreferencesQuestStore implements QuestStore {
  static const _keyQuests = 'yahagi_quests';

  @override
  Future<Map<int, GameQuest>> loadQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyQuests);
    if (jsonStr == null) {
      return const <int, GameQuest>{};
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final quests = <int, GameQuest>{};
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as int;
          final state = item['state'] as int;
          final progressCurrent = _int(item['progressCurrent']);
          final progressRequired = _int(item['progressRequired']);
          quests[id] = GameQuest(
            id: id,
            title: item['title'] as String,
            detail: item['detail'] as String,
            category: item['category'] as int,
            type: item['type'] as int,
            state: state,
            progressFlag: item['progressFlag'] as int,
            materials:
                (item['materials'] as List<dynamic>?)?.cast<int>() ??
                const <int>[0, 0, 0, 0],
            progressCurrent: progressCurrent,
            progressRequired: progressRequired,
            localCompletionVerified: _completionVerification(
              item,
              id: id,
              state: state,
              current: progressCurrent,
              required: progressRequired,
            ),
            updatedAt: item['updatedAt'] != null
                ? DateTime.parse(item['updatedAt'] as String)
                : null,
          );
        }
      }
      return quests;
    } catch (e) {
      return const <int, GameQuest>{};
    }
  }

  @override
  Future<void> saveQuests(Map<int, GameQuest> quests) async {
    final prefs = await SharedPreferences.getInstance();
    final list = quests.values
        .map(
          (q) => {
            'id': q.id,
            'title': q.title,
            'detail': q.detail,
            'category': q.category,
            'type': q.type,
            'state': q.state,
            'progressFlag': q.progressFlag,
            'materials': q.materials,
            'progressCurrent': q.progressCurrent,
            'progressRequired': q.progressRequired,
            'localCompletionVerified': q.localCompletionVerified,
            'updatedAt': q.updatedAt?.toIso8601String(),
          },
        )
        .toList(growable: false);
    await prefs.setString(_keyQuests, jsonEncode(list));
  }

  @override
  Future<void> clearQuests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyQuests);
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _completionVerification(
    Map<String, dynamic> map, {
    required int id,
    required int state,
    required int? current,
    required int? required,
  }) {
    if (map.containsKey('localCompletionVerified')) {
      final value = map['localCompletionVerified'];
      if (value is bool) return value;
    }
    if (id == 1101 &&
        state == 2 &&
        current != null &&
        required != null &&
        required > 0 &&
        current >= required) {
      return false;
    }
    return null;
  }
}
