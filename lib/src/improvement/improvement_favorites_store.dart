import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_session.dart';

abstract interface class ImprovementFavoritesStore {
  Future<Set<int>> load();
  Future<void> save(Set<int> equipmentIds);
}

final class SharedPreferencesImprovementFavoritesStore
    implements ImprovementFavoritesStore {
  SharedPreferencesImprovementFavoritesStore({AccountSession? accountSession})
    : accountSession = accountSession ?? AccountSession.shared;

  final AccountSession accountSession;
  static const _key = 'improvement.favorite-equipment-ids.v1';

  @override
  Future<Set<int>> load() async {
    final scope = accountSession.current;
    if (!scope.isKnown) return <int>{};
    return (await SharedPreferences.getInstance())
            .getStringList(scope.key(_key))
            ?.map(int.tryParse)
            .whereType<int>()
            .toSet() ??
        <int>{};
  }

  @override
  Future<void> save(Set<int> equipmentIds) async {
    final scope = accountSession.current;
    if (!scope.isKnown) return;
    final values = equipmentIds.toList()..sort();
    final saved = await (await SharedPreferences.getInstance()).setStringList(
      scope.key(_key),
      values.map((value) => '$value').toList(),
    );
    if (!saved) throw StateError('无法保存改修收藏');
  }
}
