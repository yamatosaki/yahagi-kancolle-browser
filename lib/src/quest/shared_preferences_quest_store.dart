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
          quests[id] = GameQuest(
            id: id,
            title: item['title'] as String,
            detail: item['detail'] as String,
            category: item['category'] as int,
            type: item['type'] as int,
            state: item['state'] as int,
            progressFlag: item['progressFlag'] as int,
            materials:
                (item['materials'] as List<dynamic>?)?.cast<int>() ??
                const <int>[0, 0, 0, 0],
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
}
