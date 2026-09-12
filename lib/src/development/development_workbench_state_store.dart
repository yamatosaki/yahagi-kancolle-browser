import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_session.dart';

import 'development_resources.dart';

enum DevelopmentWorkbenchMode { calculator, formula }

enum DevelopmentRecipeSortField { targetRate, totalResources, failureRate }

class DevelopmentWorkbenchState {
  const DevelopmentWorkbenchState({
    this.mode = DevelopmentWorkbenchMode.calculator,
    this.selectedPoolKey,
    this.followsCurrentFlagship = true,
    this.resources = const DevelopmentResources(10, 10, 10, 10),
    this.targetIds = const <int>[],
    this.recipeSort = DevelopmentRecipeSortField.targetRate,
    this.sortAscending = false,
  });

  factory DevelopmentWorkbenchState.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('unsupported development state version');
    }
    final resourceValues = json['resources'];
    if (resourceValues is! List<Object?> || resourceValues.length != 4) {
      throw const FormatException('invalid development resources');
    }
    final resources = resourceValues.map(_integer).toList(growable: false);
    final rawTargets = json['target_ids'];
    if (rawTargets is! List<Object?>) {
      throw const FormatException('invalid development targets');
    }
    return DevelopmentWorkbenchState(
      mode: _enumByName(
        DevelopmentWorkbenchMode.values,
        json['mode'],
        DevelopmentWorkbenchMode.calculator,
      ),
      selectedPoolKey: json['selected_pool_key'] is String
          ? json['selected_pool_key']! as String
          : null,
      followsCurrentFlagship: json['follows_current_flagship'] is bool
          ? json['follows_current_flagship']! as bool
          : true,
      resources: DevelopmentResources(
        resources[0],
        resources[1],
        resources[2],
        resources[3],
      ),
      targetIds: rawTargets.map(_integer).toList(growable: false),
      recipeSort: _enumByName(
        DevelopmentRecipeSortField.values,
        json['recipe_sort'],
        DevelopmentRecipeSortField.targetRate,
      ),
      sortAscending: json['sort_ascending'] is bool
          ? json['sort_ascending']! as bool
          : false,
    );
  }

  final DevelopmentWorkbenchMode mode;
  final String? selectedPoolKey;
  final bool followsCurrentFlagship;
  final DevelopmentResources resources;
  final List<int> targetIds;
  final DevelopmentRecipeSortField recipeSort;
  final bool sortAscending;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'mode': mode.name,
    'selected_pool_key': selectedPoolKey,
    'follows_current_flagship': followsCurrentFlagship,
    'resources': resources.values,
    'target_ids': targetIds,
    'recipe_sort': recipeSort.name,
    'sort_ascending': sortAscending,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevelopmentWorkbenchState &&
          mode == other.mode &&
          selectedPoolKey == other.selectedPoolKey &&
          followsCurrentFlagship == other.followsCurrentFlagship &&
          resources == other.resources &&
          listEquals(targetIds, other.targetIds) &&
          recipeSort == other.recipeSort &&
          sortAscending == other.sortAscending;

  @override
  int get hashCode => Object.hash(
    mode,
    selectedPoolKey,
    followsCurrentFlagship,
    resources,
    Object.hashAll(targetIds),
    recipeSort,
    sortAscending,
  );
}

abstract interface class DevelopmentWorkbenchStateStore {
  Future<DevelopmentWorkbenchState?> load();

  Future<void> save(DevelopmentWorkbenchState state);
}

final class SharedPreferencesDevelopmentWorkbenchStateStore
    implements DevelopmentWorkbenchStateStore {
  SharedPreferencesDevelopmentWorkbenchStateStore({
    AccountSession? accountSession,
  }) : accountSession = accountSession ?? AccountSession.shared;

  final AccountSession accountSession;
  static const key = 'development_workbench_state_v1';
  static Future<void> _pendingSave = Future<void>.value();
  static final Map<int, DevelopmentWorkbenchState> _latestStates = {};

  @override
  Future<DevelopmentWorkbenchState?> load() async {
    final scope = accountSession.current;
    if (!scope.isKnown) return null;
    final latest = _latestStates[scope.memberId];
    if (latest != null) return latest;
    await _pendingSave;
    if (_latestStates[scope.memberId] case final latest?) return latest;
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(scope.key(key));
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) return null;
      return DevelopmentWorkbenchState.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(DevelopmentWorkbenchState state) async {
    final scope = accountSession.current;
    if (!scope.isKnown) return;
    _latestStates[scope.memberId] = state;
    _pendingSave = _pendingSave
        .onError((Object error, StackTrace stackTrace) {})
        .then((_) async {
          final preferences = await SharedPreferences.getInstance();
          final saved = await preferences.setString(
            scope.key(key),
            jsonEncode(state.toJson()),
          );
          if (!saved) {
            throw StateError('development workbench state was not saved');
          }
        });
    await _pendingSave;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    try {
      await _pendingSave;
    } on Object {
      // A failed mocked write must not leak into the next test.
    }
    _pendingSave = Future<void>.value();
    _latestStates.clear();
  }
}

int _integer(Object? value) {
  if (value is int) return value;
  throw const FormatException('expected integer');
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}
