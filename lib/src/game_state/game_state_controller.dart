import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../quest/quest_store.dart';
import '../performance/frame_notification_coalescer.dart';
import 'game_state.dart';
import 'game_api_event_pipeline.dart';
import 'game_state_reducer.dart';
import 'game_state_store.dart';
import '../logbook/logbook_database.dart';
import '../logbook/logbook_event_recorder.dart';
import '../fleet/anchorage_repair_timer.dart';

final class GameStateController extends ChangeNotifier
    implements GameApiEventConsumer {
  GameStateController({
    GameStateReducer? reducer,
    this.questStore,
    this.gameStateStore,
    LogbookEventRecorder? logbookRecorder,
    FrameNotificationCoalescer? captureNotifications,
  }) : _reducer = reducer ?? GameStateReducer(),
       _logbookRecorder = logbookRecorder ?? LogbookEventRecorder(),
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer() {
    _initQuests();
    _initGameState();
    _startExpirationTimer();
  }

  final GameStateReducer _reducer;
  final LogbookEventRecorder _logbookRecorder;
  final FrameNotificationCoalescer _captureNotifications;
  final AnchorageRepairTimerTracker _anchorageRepairTimer =
      AnchorageRepairTimerTracker();
  final QuestStore? questStore;
  final GameStateStore? gameStateStore;
  Timer? _expirationTimer;

  @visibleForTesting
  static bool disableTimerForTest = false;

  void _startExpirationTimer() {
    if (disableTimerForTest) return;
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_state.quests.isEmpty) return;

      final now = DateTime.now().toUtc();
      bool hasExpired = false;
      final validQuests = <int, GameQuest>{};

      for (final entry in _state.quests.entries) {
        if (entry.value.isExpired(now)) {
          hasExpired = true;
        } else {
          validQuests[entry.key] = entry.value;
        }
      }

      if (hasExpired) {
        _state = _state.copyWith(quests: validQuests);
        notifyListeners();
        if (questStore != null) {
          questStore!.saveQuests(validQuests);
        }
      }
    });
  }

  Future<void> _initQuests() async {
    if (questStore == null) return;
    try {
      final cachedQuests = await questStore!.loadQuests();
      if (cachedQuests.isNotEmpty && _state.quests.isEmpty) {
        final now = DateTime.now().toUtc();
        final validQuests = <int, GameQuest>{};
        for (final entry in cachedQuests.entries) {
          if (!entry.value.isExpired(now)) {
            validQuests[entry.key] = entry.value;
          }
        }

        _state = _state.copyWith(quests: validQuests);
        notifyListeners();

        if (validQuests.length != cachedQuests.length) {
          await questStore!.saveQuests(validQuests);
        }
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> _initGameState() async {
    if (gameStateStore == null) return;
    try {
      final cachedState = await gameStateStore!.load();
      if (!_hasAcceptedLiveEvent &&
          (cachedState.updatedAt != null || cachedState.hasPortData)) {
        // Keep existing quests if they were already loaded by _initQuests
        _state = cachedState.copyWith(quests: _state.quests);
        notifyListeners();
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> clearQuestsCache() async {
    if (questStore != null) {
      await questStore!.clearQuests();
    }
    _state = _state.copyWith(
      quests: const {},
      hasQuestData: false,
      activeQuestCount: 0,
    );
    notifyListeners();
  }

  GameState _state = GameState.empty;
  Future<void> _queue = Future<void>.value();
  String? _lastError;
  String? _lastUpdatedPath;
  bool _disposed = false;
  bool _hasAcceptedLiveEvent = false;

  GameState get state => _state;
  String? get lastError => _lastError;
  String? get lastUpdatedPath => _lastUpdatedPath;
  DateTime? get anchorageRepairStartedAt => _anchorageRepairTimer.startedAt;
  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) {
    return _reducer.supportsPath(path) || _logbookRecorder.supports(path);
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed) {
      return;
    }
    _hasAcceptedLiveEvent = true;
    _queue = _queue.then((_) async {
      if (_disposed) {
        return;
      }
      try {
        final previous = _state;
        if (_logbookRecorder.supports(event.path)) {
          await _logbookRecorder.record(event, previous);
        }
        final next = _reducer.reduce(previous, event);
        if (!identical(next, previous)) {
          _anchorageRepairTimer.observe(
            previousState: previous,
            nextState: next,
            event: event,
          );
          _state = next;
          _lastUpdatedPath = event.path;
          _lastError = null;
          _captureNotifications.schedule(notifyListeners);

          if ((event.path.contains('/api_get_member/questlist') ||
                  event.path.contains('/api_req_quest/clearitemget') ||
                  event.path.contains('/api_req_quest/stop')) &&
              questStore != null) {
            await questStore!.saveQuests(next.quests);
          }
          if (gameStateStore != null) {
            gameStateStore!.save(next);
          }

          if (event.path.endsWith('/api_port/port')) {
            LogbookDatabase.instance.insertResourceSnapshot(next).catchError((
              error,
            ) {
              debugPrint('资源快照写入失败: $error');
            });
          }
        }
      } catch (error) {
        _lastError = '游戏数据解析失败（${error.runtimeType}）';
        _captureNotifications.schedule(notifyListeners);
      }
    });
  }

  void applyFriendlyBattleHp(Map<int, int> hpByShipId, DateTime capturedAt) {
    if (_disposed || hpByShipId.isEmpty) return;
    _queue = _queue.then((_) {
      if (_disposed) return;
      final previous = _state;
      final next = _reducer.applyFriendlyBattleHp(
        previous,
        hpByShipId,
        capturedAt,
      );
      if (identical(next, previous)) return;
      _state = next;
      _captureNotifications.schedule(notifyListeners);
      gameStateStore?.save(next);
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _disposed = true;
    _captureNotifications.dispose();
    if (gameStateStore != null) {
      unawaited(gameStateStore!.flush());
    }
    super.dispose();
  }
}
