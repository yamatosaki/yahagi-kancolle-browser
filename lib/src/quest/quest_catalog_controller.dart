// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'quest_catalog.dart';
import 'quest_catalog_dataset.dart';
import 'quest_catalog_update_service.dart';

final class QuestCatalogController extends ChangeNotifier {
  QuestCatalogController({
    required QuestCatalogDataset dataset,
    required QuestCatalogUpdateClient updater,
    DateTime? lastCheckedAt,
    String sourceHost = '',
    DateTime Function()? now,
  }) : _dataset = dataset,
       _updater = updater,
       _lastCheckedAt = lastCheckedAt?.toUtc(),
       _sourceHost = sourceHost,
       _now = now ?? _utcNow;

  QuestCatalogDataset _dataset;
  final QuestCatalogUpdateClient _updater;
  final DateTime Function() _now;
  Future<QuestCatalogUpdateResult>? _activeCheck;
  QuestCatalogUpdateResult? _lastResult;
  DateTime? _lastCheckedAt;
  String _sourceHost;
  bool _disposed = false;

  QuestCatalogDataset get dataset => _dataset;
  QuestCatalog get catalog => _dataset.catalog;
  QuestCatalogVersion get version => _dataset.version;
  bool get isChecking => _activeCheck != null;
  QuestCatalogUpdateResult? get lastResult => _lastResult;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  String get sourceHost => _sourceHost;

  Future<QuestCatalogUpdateResult> checkForUpdates() {
    final active = _activeCheck;
    if (active != null) return active;
    final check = _performCheck();
    _activeCheck = check;
    notifyListeners();
    return check;
  }

  Future<QuestCatalogUpdateResult> _performCheck() async {
    try {
      final result = await _updater.checkAndUpdate(current: _dataset);
      if (result is QuestCatalogUpdated) _dataset = result.dataset;
      _lastResult = result;
      _lastCheckedAt = _now().toUtc();
      if (result is! QuestCatalogUpdateFailed) {
        _sourceHost = result.sourceHost;
      }
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

DateTime _utcNow() => DateTime.now().toUtc();
