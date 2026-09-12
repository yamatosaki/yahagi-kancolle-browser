// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../account/account_session.dart';

import '../game_state/game_state.dart';
import '../inventory/owned_inventory_projection.dart';
import 'improvement_dataset.dart';
import 'improvement_favorites_store.dart';
import 'improvement_projection.dart';
import 'improvement_dataset_update_service.dart';

enum ConstructionCenterMode { construction, development, improvement }

class ImprovementPlannerController extends ChangeNotifier {
  ImprovementPlannerController({
    required ImprovementDataset dataset,
    ImprovementFavoritesStore? favoritesStore,
    DateTime Function()? clock,
    ImprovementUpdateClient? updater,
    AccountSession? accountSession,
  }) : _dataset = dataset,
       _favoritesStore = favoritesStore,
       _updater = updater,
       accountSession = accountSession ?? AccountSession.shared,
       selectedWeekday = jstWeekday((clock ?? DateTime.now).call()) {
    this.accountSession.addListener(_onAccountChanged);
  }

  final AccountSession accountSession;
  bool _disposed = false;
  int _favoriteLoadGeneration = 0;
  ImprovementDataset _dataset;
  final ImprovementFavoritesStore? _favoritesStore;
  final ImprovementUpdateClient? _updater;
  Future<ImprovementUpdateResult>? _activeUpdate;
  ImprovementUpdateResult? lastUpdateResult;
  DateTime? lastCheckedAt;
  final Set<int> _favoriteEquipmentIds = <int>{};
  int selectedWeekday;
  bool favoritesOnly = false;
  String query = '';
  EquipmentInventoryCategory equipmentCategory = EquipmentInventoryCategory.all;
  ImprovementEvolutionFilter evolutionFilter = ImprovementEvolutionFilter.all;

  ImprovementDataset get dataset => _dataset;
  Set<int> get favoriteEquipmentIds => Set.unmodifiable(_favoriteEquipmentIds);
  List<ImprovementPlannerRow> rowsFor(GameState state) =>
      projectImprovementRows(
        _dataset,
        weekday: selectedWeekday,
        equipmentMasters: state.masterSlotItems,
        shipMasters: state.masterShips,
        query: query,
        equipmentCategory: equipmentCategory,
        favoriteEquipmentIds: _favoriteEquipmentIds,
        favoritesOnly: favoritesOnly,
        evolutionFilter: evolutionFilter,
      );
  bool get hasSearch => query.trim().isNotEmpty;
  bool get hasFilters =>
      equipmentCategory != EquipmentInventoryCategory.all ||
      evolutionFilter != ImprovementEvolutionFilter.all;
  bool get isCheckingUpdates => _activeUpdate != null;

  Future<ImprovementUpdateResult> checkForUpdates() {
    final active = _activeUpdate;
    if (active != null) return active;
    final future = _performUpdate();
    _activeUpdate = future;
    notifyListeners();
    return future;
  }

  Future<ImprovementUpdateResult> _performUpdate() async {
    try {
      final updater = _updater;
      final result = updater == null
          ? const ImprovementUpdateFailed(
              ImprovementUpdateFailure.network,
              '更新服务未初始化',
            )
          : await updater.checkAndUpdate(_dataset);
      if (result is ImprovementUpdated) _dataset = result.dataset;
      lastUpdateResult = result;
      lastCheckedAt = DateTime.now().toUtc();
      return result;
    } finally {
      _activeUpdate = null;
      notifyListeners();
    }
  }

  Future<void> loadFavorites() async {
    final scope = accountSession.current;
    final generation = ++_favoriteLoadGeneration;
    final store = _favoritesStore;
    if (store == null || !scope.isKnown) return;
    final favorites = await store.load();
    if (_disposed ||
        !accountSession.isCurrent(scope) ||
        generation != _favoriteLoadGeneration) {
      return;
    }
    _favoriteEquipmentIds
      ..clear()
      ..addAll(favorites);
    notifyListeners();
  }

  void _onAccountChanged() {
    _favoriteLoadGeneration++;
    _favoriteEquipmentIds.clear();
    notifyListeners();
    loadFavorites().catchError((Object _) {});
  }

  void selectWeekday(int value) {
    if (value == selectedWeekday ||
        value < improvementAllWeekdays ||
        value > DateTime.sunday) {
      return;
    }
    selectedWeekday = value;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    favoritesOnly = !favoritesOnly;
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == query) return;
    query = value;
    notifyListeners();
  }

  void selectEquipmentCategory(EquipmentInventoryCategory value) {
    if (value == equipmentCategory) return;
    equipmentCategory = value;
    notifyListeners();
  }

  void selectEvolutionFilter(ImprovementEvolutionFilter value) {
    if (value == evolutionFilter) return;
    evolutionFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    if (!hasFilters) return;
    equipmentCategory = EquipmentInventoryCategory.all;
    evolutionFilter = ImprovementEvolutionFilter.all;
    notifyListeners();
  }

  Future<void> toggleFavorite(int equipmentId) async {
    if (!_favoriteEquipmentIds.remove(equipmentId)) {
      _favoriteEquipmentIds.add(equipmentId);
    }
    notifyListeners();
    if (!accountSession.current.isKnown) return;
    try {
      await _favoritesStore?.save(_favoriteEquipmentIds);
    } catch (_) {
      // 收藏首先保持当前交互状态；下次成功保存会覆盖持久层。
    }
  }

  void replaceDataset(ImprovementDataset value) {
    _dataset = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    accountSession.removeListener(_onAccountChanged);
    super.dispose();
  }
}
