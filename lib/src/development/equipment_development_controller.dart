import 'dart:collection';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../account/account_session.dart';

import '../game_state/game_state.dart';
import 'development_dataset.dart';
import 'development_pool_matcher.dart';
import 'development_projection.dart';
import 'development_recipe_calculator.dart';
import 'development_repository.dart';
import 'development_resources.dart';
import 'development_workbench_state_store.dart';

class EquipmentDevelopmentController extends ChangeNotifier {
  EquipmentDevelopmentController({
    required this.repository,
    this.stateStore,
    AccountSession? accountSession,
  }) : accountSession = accountSession ?? AccountSession.shared {
    this.accountSession.addListener(_onAccountChanged);
  }

  final AccountSession accountSession;
  final DevelopmentRepository repository;
  final DevelopmentWorkbenchStateStore? stateStore;

  DevelopmentDataset? _dataset;
  GameState _gameState = GameState.empty;
  bool _loading = false;
  Object? _error;
  bool _manualPoolSelection = false;
  String? _selectedPoolKey;
  DevelopmentResources _resources = const DevelopmentResources(10, 10, 10, 10);
  final Set<int> _targets = <int>{};
  int? _equipmentTypeFilter;
  String _equipmentSearch = '';
  DevelopmentRatesResult? _currentRates;
  DevelopmentEquipmentGroups? _equipmentGroups;
  Set<int> _enabledEquipment = const <int>{};
  List<DevelopmentRecipeResult> _recipes = const [];
  DevelopmentRecipeSortField _recipeSort =
      DevelopmentRecipeSortField.targetRate;
  bool _sortAscending = false;
  DevelopmentWorkbenchMode _mode = DevelopmentWorkbenchMode.calculator;
  String? _lastAppliedRecipeKey;
  bool _disposed = false;
  DevelopmentWorkbenchState? _pendingRestoredState;

  DevelopmentDataset? get dataset => _dataset;
  bool get isLoading => _loading;
  Object? get error => _error;
  String? get selectedPoolKey => _selectedPoolKey;
  DevelopmentResources get resources => _resources;
  Set<int> get targets => UnmodifiableSetView(_targets);
  int? get equipmentTypeFilter => _equipmentTypeFilter;
  String get equipmentSearch => _equipmentSearch;
  DevelopmentRatesResult? get currentRates => _currentRates;
  DevelopmentEquipmentGroups? get equipmentGroups => _equipmentGroups;
  Set<int> get enabledEquipment => _enabledEquipment;
  List<DevelopmentRecipeResult> get recipes => _recipes;
  DevelopmentRecipeSortField get recipeSort => _recipeSort;
  bool get sortAscending => _sortAscending;
  DevelopmentWorkbenchMode get mode => _mode;
  bool get followsCurrentFlagship => !_manualPoolSelection;

  bool isRecipeApplied(DevelopmentRecipeResult recipe) =>
      _lastAppliedRecipeKey ==
      '${recipe.poolKey}:${recipe.resources.values.join(',')}';

  DevelopmentPoolRecord? get selectedPool {
    final key = _selectedPoolKey;
    return key == null ? null : _dataset?.poolsByKey[key];
  }

  int? get currentFlagshipMasterId {
    Fleet? firstFleet;
    for (final fleet in _gameState.fleets) {
      if (fleet.id == 1) {
        firstFleet = fleet;
        break;
      }
    }
    if (firstFleet == null || firstFleet.shipIds.isEmpty) return null;
    final ownedId = firstFleet.shipIds.firstWhere(
      (id) => id > 0,
      orElse: () => -1,
    );
    return _gameState.ships[ownedId]?.masterId;
  }

  String? get currentFlagshipName {
    final id = currentFlagshipMasterId;
    return id == null ? null : _gameState.masterShips[id]?.name;
  }

  List<DevelopmentEquipmentRecord> get filteredEquipment => _filteredEquipment(
    _equipmentTypeFilter == null ? null : {_equipmentTypeFilter!},
  );

  List<DevelopmentEquipmentRecord> filteredEquipmentForType(int typeId) =>
      filteredEquipmentForTypes({typeId});

  List<DevelopmentEquipmentRecord> filteredEquipmentForTypes(
    Set<int> typeIds,
  ) => _filteredEquipment(typeIds);

  List<DevelopmentEquipmentRecord> _filteredEquipment(Set<int>? typeIds) {
    final data = _dataset;
    if (data == null) return const [];
    final query = _equipmentSearch.trim().toLowerCase();
    final output = data.equipment.values.where((item) {
      if (typeIds != null && !typeIds.contains(item.typeId)) return false;
      if (query.isEmpty) return true;
      return item.searchableNames.any(
            (name) => name.toLowerCase().contains(query),
          ) ||
          (_gameState.masterSlotItems[item.id]?.name.toLowerCase().contains(
                query,
              ) ??
              false) ||
          item.id.toString() == query;
    }).toList();
    output.sort((left, right) {
      final byType = left.typeId.compareTo(right.typeId);
      if (byType != 0) return byType;
      final byIcon = left.iconId.compareTo(right.iconId);
      return byIcon != 0 ? byIcon : left.id.compareTo(right.id);
    });
    return output;
  }

  String equipmentTypeName(int typeId) =>
      _gameState.masterSlotItemTypes[typeId] ?? '—';

  Future<void> initialize(GameState state) async {
    _gameState = state;
    await _load(restoredStateFuture: _readStoredState());
  }

  Future<DevelopmentWorkbenchState?> _readStoredState() async {
    final scope = accountSession.current;
    if (!scope.isKnown) return null;
    DevelopmentWorkbenchState? restoredState;
    try {
      restoredState = await stateStore?.load();
    } on Object catch (error) {
      debugPrint('Failed to load development workbench state: $error');
    }
    if (_disposed || !accountSession.isCurrent(scope)) return null;
    _pendingRestoredState = restoredState;
    return restoredState;
  }

  Future<void> retry() => _load();

  Future<void> _load({
    Future<DevelopmentWorkbenchState?>? restoredStateFuture,
  }) async {
    if (_disposed || _loading) return;
    _loading = true;
    final scope = accountSession.current;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        repository.load(),
        restoredStateFuture ??
            Future<DevelopmentWorkbenchState?>.value(_pendingRestoredState),
      ]);
      if (_disposed) return;
      _dataset = results[0]! as DevelopmentDataset;
      _selectAutomaticPool();
      _recompute();
      final restoredState = accountSession.isCurrent(scope)
          ? results[1] as DevelopmentWorkbenchState?
          : _pendingRestoredState;
      if (restoredState != null) _restoreState(restoredState);
      _pendingRestoredState = null;
    } on Object catch (error) {
      if (_disposed) return;
      _error = error;
    } finally {
      _loading = false;
      _notifyListeners();
    }
  }

  void updateGameState(GameState state) {
    _gameState = state;
    if (!_manualPoolSelection) _selectAutomaticPool();
    _recompute();
    notifyListeners();
  }

  void _onAccountChanged() {
    _gameState = GameState.empty;
    _pendingRestoredState = null;
    _manualPoolSelection = false;
    _selectedPoolKey = null;
    _resources = const DevelopmentResources(10, 10, 10, 10);
    _targets.clear();
    _lastAppliedRecipeKey = null;
    _selectAutomaticPool();
    _recompute();
    notifyListeners();
    unawaited(_restoreAccountState());
  }

  Future<void> _restoreAccountState() async {
    final scope = accountSession.current;
    final restored = await _readStoredState();
    if (_disposed || !accountSession.isCurrent(scope) || restored == null) {
      return;
    }
    if (_dataset != null) {
      _restoreState(restored);
      _pendingRestoredState = null;
      notifyListeners();
    }
  }

  void selectPool(String key) {
    final pool = _dataset?.poolsByKey[key];
    if (pool == null || !pool.isSelectable) return;
    final changed = key != _selectedPoolKey;
    _selectedPoolKey = key;
    _manualPoolSelection = true;
    _lastAppliedRecipeKey = null;
    if (changed) _recompute();
    notifyListeners();
    _persistState();
  }

  bool useCurrentFlagship() {
    if (!_selectAutomaticPool(fallbackToFirst: false)) return false;
    _manualPoolSelection = false;
    _lastAppliedRecipeKey = null;
    _recompute();
    notifyListeners();
    _persistState();
    return true;
  }

  void commitResources(DevelopmentResources value) {
    if (value.values.any((amount) => amount < 10 || amount > 300) ||
        value == _resources) {
      return;
    }
    _resources = value;
    _recompute();
    notifyListeners();
    _persistState();
  }

  void toggleTarget(int equipmentId) {
    if (_targets.remove(equipmentId)) {
      _lastAppliedRecipeKey = null;
      _recompute();
      notifyListeners();
      _persistState();
      return;
    }
    if (!_enabledEquipment.contains(equipmentId)) return;
    _targets.add(equipmentId);
    _lastAppliedRecipeKey = null;
    _recompute();
    notifyListeners();
    _persistState();
  }

  void applyRecipe(DevelopmentRecipeResult recipe) {
    final applicationKey =
        '${recipe.poolKey}:${recipe.resources.values.join(',')}';
    if (_lastAppliedRecipeKey == applicationKey) return;
    _lastAppliedRecipeKey = applicationKey;
    _resources = recipe.resources;
    _selectedPoolKey = recipe.poolKey;
    _manualPoolSelection = true;
    _recompute();
    notifyListeners();
    _persistState();
  }

  void setEquipmentTypeFilter(int? typeId) {
    if (_equipmentTypeFilter == typeId) return;
    _equipmentTypeFilter = typeId;
    notifyListeners();
  }

  void setEquipmentSearch(String value) {
    if (_equipmentSearch == value) return;
    _equipmentSearch = value;
    notifyListeners();
  }

  void sortRecipes(DevelopmentRecipeSortField field) {
    if (_recipeSort == field) {
      _sortAscending = !_sortAscending;
    } else {
      _recipeSort = field;
      _sortAscending = field != DevelopmentRecipeSortField.targetRate;
    }
    _sortRecipeOutput();
    notifyListeners();
    _persistState();
  }

  void setMode(DevelopmentWorkbenchMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    _persistState();
  }

  void _restoreState(DevelopmentWorkbenchState state) {
    final data = _dataset;
    if (data == null) return;
    _mode = state.mode;
    _resources = state.resources.normalized();
    _recipeSort = state.recipeSort;
    _sortAscending = state.sortAscending;
    _targets.clear();

    final restoredPool = state.selectedPoolKey == null
        ? null
        : data.poolsByKey[state.selectedPoolKey];
    if (!state.followsCurrentFlagship && restoredPool?.isSelectable == true) {
      _selectedPoolKey = restoredPool!.key;
      _manualPoolSelection = true;
    } else {
      _selectedPoolKey = null;
      _manualPoolSelection = false;
      _selectAutomaticPool();
    }
    _recompute();

    for (final id in state.targetIds) {
      if (_enabledEquipment.contains(id)) {
        _targets.add(id);
        _recompute();
      }
    }
  }

  void _persistState() {
    final store = stateStore;
    if (store == null || _dataset == null || !accountSession.current.isKnown) {
      return;
    }
    final snapshot = DevelopmentWorkbenchState(
      mode: _mode,
      selectedPoolKey: _selectedPoolKey,
      followsCurrentFlagship: followsCurrentFlagship,
      resources: _resources,
      targetIds: List<int>.unmodifiable(_targets),
      recipeSort: _recipeSort,
      sortAscending: _sortAscending,
    );
    store.save(snapshot).onError((Object error, StackTrace stackTrace) {
      debugPrint('Failed to save development workbench state: $error');
    });
  }

  bool _selectAutomaticPool({bool fallbackToFirst = true}) {
    final data = _dataset;
    if (data == null) return false;
    final flagshipId = currentFlagshipMasterId;
    final matched = flagshipId == null
        ? null
        : data.secretaries[flagshipId]?.poolKey;
    if (matched != null) {
      _selectedPoolKey = matched;
      return true;
    }
    if (fallbackToFirst && _selectedPoolKey == null) {
      _selectedPoolKey = data.selectablePools.isEmpty
          ? null
          : data.selectablePools.first.key;
    }
    return false;
  }

  void _recompute() {
    final data = _dataset;
    final pool = selectedPool;
    if (data == null || pool == null) {
      _currentRates = null;
      _equipmentGroups = null;
      _enabledEquipment = const <int>{};
      _recipes = const [];
      return;
    }
    _currentRates = calculateDevelopmentRates(data, pool, _resources);
    _equipmentGroups = projectDevelopmentEquipment(
      totals: _currentRates!.totals,
      details: _currentRates!.details,
      targets: _targets,
      resources: _resources,
      equipment: data.equipment,
    );
    _enabledEquipment = calculateEnabledDevelopmentEquipment(data, _targets);
    _recipes = calculateDevelopmentRecipes(data, _targets);
    _sortRecipeOutput();
  }

  void _sortRecipeOutput() {
    final sorted = _recipes.toList();
    int compare(DevelopmentRecipeResult left, DevelopmentRecipeResult right) {
      final comparison = switch (_recipeSort) {
        DevelopmentRecipeSortField.targetRate => _compareTargetRate(
          left,
          right,
        ),
        DevelopmentRecipeSortField.totalResources =>
          left.totalResources.compareTo(right.totalResources),
        DevelopmentRecipeSortField.failureRate => left.failureRate.compareTo(
          right.failureRate,
        ),
      };
      if (comparison != 0) return _sortAscending ? comparison : -comparison;
      return left.poolKey.compareTo(right.poolKey);
    }

    sorted.sort(compare);
    _recipes = List.unmodifiable(sorted);
  }

  int _compareTargetRate(
    DevelopmentRecipeResult left,
    DevelopmentRecipeResult right,
  ) {
    final byRate = left.targetRate.compareTo(right.targetRate);
    if (byRate != 0) return byRate;
    if ((left.totalResources - right.totalResources).abs() > 1) {
      return -left.totalResources.compareTo(right.totalResources);
    }
    return left.failureRate.compareTo(right.failureRate);
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    accountSession.removeListener(_onAccountChanged);
    super.dispose();
  }
}
