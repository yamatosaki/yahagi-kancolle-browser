// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'quest_progress_dataset.dart';
import 'quest_progress_update_service.dart';

final class QuestProgressRulesController extends ChangeNotifier {
  QuestProgressRulesController({
    required QuestProgressDataset dataset,
    required QuestProgressUpdateClient updater,
    Future<void> Function(QuestProgressDataset)? onUpdated,
    DateTime Function()? now,
    DateTime? lastCheckedAt,
    String sourceHost = '',
  }) : _dataset = dataset,
       _updater = updater,
       _onUpdated = onUpdated,
       _now = now ?? _utcNow,
       _lastCheckedAt = lastCheckedAt?.toUtc(),
       _sourceHost = sourceHost;

  QuestProgressDataset _dataset;
  final QuestProgressUpdateClient _updater;
  final Future<void> Function(QuestProgressDataset)? _onUpdated;
  final DateTime Function() _now;
  Future<QuestProgressUpdateResult>? _activeCheck;
  QuestProgressUpdateResult? _lastResult;
  DateTime? _lastCheckedAt;
  String _sourceHost;
  bool _disposed = false;

  QuestProgressDataset get dataset => _dataset;
  String get version => _dataset.version;
  bool get isChecking => _activeCheck != null;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  String get sourceHost => _sourceHost;
  QuestProgressUpdateResult? get lastResult => _lastResult;

  Future<QuestProgressUpdateResult> checkForUpdates() {
    final active = _activeCheck;
    if (active != null) return active;
    if (_disposed) {
      return Future.value(
        QuestProgressUpdateFailed(
          QuestProgressUpdateFailure.validation,
          StateError('Quest progress rules controller is disposed'),
        ),
      );
    }
    // Schedule after assigning the shared future, including synchronous errors
    // from an injected updater and checks triggered by a notification listener.
    final check = Future<QuestProgressUpdateResult>.microtask(_performCheck);
    _activeCheck = check;
    notifyListeners();
    return check;
  }

  Future<QuestProgressUpdateResult> _performCheck() async {
    QuestProgressUpdateResult result;
    try {
      try {
        result = await _updater.checkAndUpdate(current: _dataset);
      } on Object catch (error) {
        result = QuestProgressUpdateFailed(
          QuestProgressUpdateFailure.network,
          error,
        );
      }
      if (result is QuestProgressUpdated && !_disposed) {
        final updated = result.dataset.overlayOn(_dataset);
        try {
          await _onUpdated?.call(updated);
          if (!_disposed) _dataset = updated;
          result = QuestProgressUpdated(updated, sourceHost: result.sourceHost);
        } on Object catch (error) {
          result = QuestProgressUpdateFailed(
            QuestProgressUpdateFailure.storage,
            error,
            sourceHost: result.sourceHost,
          );
        }
      }
      _lastResult = result;
      _lastCheckedAt = _now().toUtc();
      if (result is! QuestProgressUpdateFailed) _sourceHost = result.sourceHost;
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
