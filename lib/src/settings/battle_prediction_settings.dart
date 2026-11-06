import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EnemyPreviewPosition { above, below }

enum FleetInformationSyncMode { immediate, settlement }

enum BattlePredictionSection { sortieMap, enemyPreview, predictionResult }

const defaultBattlePredictionSectionOrder = <BattlePredictionSection>[
  BattlePredictionSection.sortieMap,
  BattlePredictionSection.enemyPreview,
  BattlePredictionSection.predictionResult,
];

List<BattlePredictionSection> normalizeBattlePredictionSectionOrder(
  Iterable<BattlePredictionSection> order,
) => List<BattlePredictionSection>.unmodifiable(<BattlePredictionSection>{
  ...order,
  ...defaultBattlePredictionSectionOrder,
});

abstract interface class BattlePredictionSettingsStore {
  Future<void> initialize();

  Future<bool> loadEnemyPortraitsEnabled();

  Future<void> saveEnemyPortraitsEnabled(bool enabled);

  Future<bool> loadLastFormationHintEnabled();

  Future<void> saveLastFormationHintEnabled(bool enabled);

  Future<EnemyPreviewPosition> loadEnemyPreviewPosition();

  Future<void> saveEnemyPreviewPosition(EnemyPreviewPosition position);

  Future<FleetInformationSyncMode> loadFleetInformationSyncMode();

  Future<void> saveFleetInformationSyncMode(FleetInformationSyncMode mode);

  Future<List<BattlePredictionSection>?> loadSectionOrder();

  Future<void> saveSectionOrder(List<BattlePredictionSection> order);
}

final class SharedPreferencesBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  static const String _legacyPredictionMethodKey = 'battle.predictionMethod';
  static const String _enemyPortraitsKey =
      'battle.enemyPreviewPortraitsEnabled';
  static const String _lastFormationHintKey = 'battle.lastFormationHintEnabled';
  static const String _enemyPreviewPositionKey = 'battle.enemyPreviewPosition';
  static const String _fleetInformationSyncModeKey =
      'battle.fleetInformationSyncMode';
  static const String _sectionOrderKey = 'battle.sectionOrder';

  @override
  Future<void> initialize() async {
    await (await SharedPreferences.getInstance()).remove(
      _legacyPredictionMethodKey,
    );
  }

  @override
  Future<bool> loadEnemyPortraitsEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(
          _enemyPortraitsKey,
        ) ??
        true;
  }

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _enemyPortraitsKey,
      enabled,
    );
    if (!saved) throw StateError('enemy portrait setting was not saved');
  }

  @override
  Future<bool> loadLastFormationHintEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(
          _lastFormationHintKey,
        ) ??
        true;
  }

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _lastFormationHintKey,
      enabled,
    );
    if (!saved) throw StateError('last formation hint setting was not saved');
  }

  @override
  Future<EnemyPreviewPosition> loadEnemyPreviewPosition() async {
    final value = (await SharedPreferences.getInstance()).get(
      _enemyPreviewPositionKey,
    );
    return EnemyPreviewPosition.values.firstWhere(
      (position) => position.name == value,
      orElse: () => EnemyPreviewPosition.above,
    );
  }

  @override
  Future<void> saveEnemyPreviewPosition(EnemyPreviewPosition position) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _enemyPreviewPositionKey,
      position.name,
    );
    if (!saved) throw StateError('enemy preview position was not saved');
  }

  @override
  Future<FleetInformationSyncMode> loadFleetInformationSyncMode() async {
    final value = (await SharedPreferences.getInstance()).get(
      _fleetInformationSyncModeKey,
    );
    return FleetInformationSyncMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => FleetInformationSyncMode.immediate,
    );
  }

  @override
  Future<void> saveFleetInformationSyncMode(
    FleetInformationSyncMode mode,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.get(_fleetInformationSyncModeKey);
    try {
      if (!await preferences.setString(
        _fleetInformationSyncModeKey,
        mode.name,
      )) {
        throw StateError('fleet information sync mode was not saved');
      }
    } catch (_) {
      // SharedPreferences updates its cache before completing the platform write.
      try {
        if (previous is String) {
          await preferences.setString(_fleetInformationSyncModeKey, previous);
        } else {
          await preferences.remove(_fleetInformationSyncModeKey);
        }
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<List<BattlePredictionSection>?> loadSectionOrder() async {
    final value = (await SharedPreferences.getInstance()).get(_sectionOrderKey);
    if (value is! List) return null;
    return normalizeBattlePredictionSectionOrder(
      value.expand<BattlePredictionSection>((name) {
        return BattlePredictionSection.values.where(
          (section) => section.name == name,
        );
      }),
    );
  }

  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {
    final normalized = normalizeBattlePredictionSectionOrder(order);
    final saved = await (await SharedPreferences.getInstance()).setStringList(
      _sectionOrderKey,
      normalized.map((section) => section.name).toList(),
    );
    if (!saved) throw StateError('battle section order was not saved');
  }
}

final class MemoryBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  MemoryBattlePredictionSettingsStore([
    this._enemyPortraitsEnabled = true,
    this._lastFormationHintEnabled = true,
    this._enemyPreviewPosition = EnemyPreviewPosition.above,
  ]);

  bool _enemyPortraitsEnabled;
  bool _lastFormationHintEnabled;
  EnemyPreviewPosition _enemyPreviewPosition;
  FleetInformationSyncMode _fleetInformationSyncMode =
      FleetInformationSyncMode.immediate;
  List<BattlePredictionSection>? _sectionOrder;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> loadEnemyPortraitsEnabled() async => _enemyPortraitsEnabled;

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {
    _enemyPortraitsEnabled = enabled;
  }

  @override
  Future<bool> loadLastFormationHintEnabled() async =>
      _lastFormationHintEnabled;

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {
    _lastFormationHintEnabled = enabled;
  }

  @override
  Future<EnemyPreviewPosition> loadEnemyPreviewPosition() async =>
      _enemyPreviewPosition;

  @override
  Future<void> saveEnemyPreviewPosition(EnemyPreviewPosition position) async {
    _enemyPreviewPosition = position;
  }

  @override
  Future<FleetInformationSyncMode> loadFleetInformationSyncMode() async =>
      _fleetInformationSyncMode;

  @override
  Future<void> saveFleetInformationSyncMode(
    FleetInformationSyncMode mode,
  ) async {
    _fleetInformationSyncMode = mode;
  }

  @override
  Future<List<BattlePredictionSection>?> loadSectionOrder() async =>
      _sectionOrder;

  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {
    _sectionOrder = normalizeBattlePredictionSectionOrder(order);
  }
}

final class BattlePredictionSettingsController extends ChangeNotifier {
  BattlePredictionSettingsController._(this._store);

  final BattlePredictionSettingsStore _store;
  bool _enemyPortraitsEnabled = true;
  bool _lastFormationHintEnabled = true;
  EnemyPreviewPosition _enemyPreviewPosition = EnemyPreviewPosition.above;
  FleetInformationSyncMode _fleetInformationSyncMode =
      FleetInformationSyncMode.immediate;
  Future<void> _fleetInformationSyncSave = Future<void>.value();
  List<BattlePredictionSection>? _sectionOrder;
  Future<void>? _sectionOrderOperation;

  bool get enemyPortraitsEnabled => _enemyPortraitsEnabled;
  bool get lastFormationHintEnabled => _lastFormationHintEnabled;
  EnemyPreviewPosition get enemyPreviewPosition => _enemyPreviewPosition;
  FleetInformationSyncMode get fleetInformationSyncMode =>
      _fleetInformationSyncMode;
  // Existing controllers retain their legacy arrangement across hot reload.
  List<BattlePredictionSection> get sectionOrder =>
      _sectionOrder ??
      (_enemyPreviewPosition == EnemyPreviewPosition.above
          ? defaultBattlePredictionSectionOrder
          : const <BattlePredictionSection>[
              BattlePredictionSection.sortieMap,
              BattlePredictionSection.predictionResult,
              BattlePredictionSection.enemyPreview,
            ]);

  static Future<BattlePredictionSettingsController> load(
    BattlePredictionSettingsStore store,
  ) async {
    final controller = BattlePredictionSettingsController._(store);
    try {
      await store.initialize();
    } catch (_) {
      // A stale engine preference must never block the remaining settings.
    }
    controller._enemyPortraitsEnabled = await store.loadEnemyPortraitsEnabled();
    controller._lastFormationHintEnabled = await store
        .loadLastFormationHintEnabled();
    controller._enemyPreviewPosition = await store.loadEnemyPreviewPosition();
    controller._fleetInformationSyncMode = await store
        .loadFleetInformationSyncMode();
    try {
      final savedOrder = await store.loadSectionOrder();
      if (savedOrder != null) {
        controller._sectionOrder = normalizeBattlePredictionSectionOrder(
          savedOrder,
        );
      }
    } catch (_) {
      // A corrupt or unavailable order must not block the remaining settings.
    }
    return controller;
  }

  Future<void> setEnemyPortraitsEnabled(bool enabled) async {
    if (_enemyPortraitsEnabled == enabled) return;
    await _store.saveEnemyPortraitsEnabled(enabled);
    _enemyPortraitsEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLastFormationHintEnabled(bool enabled) async {
    if (_lastFormationHintEnabled == enabled) return;
    await _store.saveLastFormationHintEnabled(enabled);
    _lastFormationHintEnabled = enabled;
    notifyListeners();
  }

  Future<void> setEnemyPreviewPosition(EnemyPreviewPosition position) async {
    if (_enemyPreviewPosition == position) return;
    await _store.saveEnemyPreviewPosition(position);
    _enemyPreviewPosition = position;
    notifyListeners();
  }

  Future<void> setFleetInformationSyncMode(FleetInformationSyncMode mode) {
    final pending = _fleetInformationSyncSave.then((_) async {
      if (_fleetInformationSyncMode == mode) return;
      await _store.saveFleetInformationSyncMode(mode);
      _fleetInformationSyncMode = mode;
      notifyListeners();
    });
    _fleetInformationSyncSave = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  Future<void> setSectionOrder(List<BattlePredictionSection> order) {
    final normalized = normalizeBattlePredictionSectionOrder(order);
    return _enqueueSectionOrderOperation(() => _saveSectionOrder(normalized));
  }

  Future<void> moveSection(BattlePredictionSection section, int delta) {
    return _enqueueSectionOrderOperation(() async {
      final order = sectionOrder.toList();
      final currentIndex = order.indexOf(section);
      final targetIndex = (currentIndex + delta).clamp(0, order.length - 1);
      if (currentIndex == targetIndex) return;
      order.removeAt(currentIndex);
      order.insert(targetIndex, section);
      await _saveSectionOrder(normalizeBattlePredictionSectionOrder(order));
    });
  }

  Future<void> resetSectionOrder() =>
      setSectionOrder(defaultBattlePredictionSectionOrder);

  Future<void> _saveSectionOrder(List<BattlePredictionSection> order) async {
    final changed = !listEquals(sectionOrder, order);
    if (_sectionOrder != null && !changed) return;
    await _store.saveSectionOrder(order);
    _sectionOrder = order;
    if (changed) notifyListeners();
  }

  Future<void> _enqueueSectionOrderOperation(
    Future<void> Function() operation,
  ) {
    final pending = (_sectionOrderOperation ?? Future<void>.value()).then(
      (_) => operation(),
    );
    _sectionOrderOperation = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }
}
