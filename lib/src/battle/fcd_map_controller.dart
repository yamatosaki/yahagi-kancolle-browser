// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'battle_node_label_resolver.dart';
import 'fcd_map_dataset.dart';
import 'fcd_map_update_service.dart';

final class FcdMapController extends ChangeNotifier
    implements BattleNodeLabelResolver {
  FcdMapController({
    required FcdMapDataset dataset,
    required FcdMapUpdateClient updater,
    DateTime? lastCheckedAt,
    String sourceHost = '',
    DateTime Function()? now,
  }) : _dataset = dataset,
       _updater = updater,
       _lastCheckedAt = lastCheckedAt?.toUtc(),
       _sourceHost = sourceHost,
       _now = now ?? _systemUtcNow;

  FcdMapDataset _dataset;
  final FcdMapUpdateClient _updater;
  Future<FcdMapUpdateResult>? _activeCheck;
  FcdMapUpdateResult? _lastResult;
  DateTime? _lastCheckedAt;
  String _sourceHost;
  final DateTime Function() _now;
  bool _disposed = false;

  FcdMapVersion get version => _dataset.version;
  bool get isChecking => _activeCheck != null;
  FcdMapUpdateResult? get lastResult => _lastResult;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  String get sourceHost => _sourceHost;

  @override
  String? resolve({
    required int mapAreaId,
    required int mapInfoNo,
    required int internalNodeId,
  }) => _dataset.resolve(
    mapAreaId: mapAreaId,
    mapInfoNo: mapInfoNo,
    internalNodeId: internalNodeId,
  );

  Future<FcdMapUpdateResult> checkForUpdates() {
    final active = _activeCheck;
    if (active != null) return active;
    final check = _performCheck();
    _activeCheck = check;
    notifyListeners();
    return check;
  }

  Future<FcdMapUpdateResult> _performCheck() async {
    try {
      final result = await _updater.checkAndUpdate(current: _dataset);
      if (result is FcdMapUpdated) _dataset = result.dataset;
      _lastResult = result;
      _lastCheckedAt = _now().toUtc();
      if (result is! FcdMapUpdateFailed) _sourceHost = result.sourceHost;
      return result;
    } finally {
      _activeCheck = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
