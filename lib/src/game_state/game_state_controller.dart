import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../quest/quest_store.dart';
import 'game_api_decoder.dart';
import 'game_state.dart';
import 'game_state_reducer.dart';
import 'game_state_store.dart';
import '../logbook/logbook_database.dart';
import '../fleet/anchorage_repair_timer.dart';

final class GameStateController extends ChangeNotifier {
  GameStateController({
    GameStateReducer? reducer,
    this.questStore,
    this.gameStateStore,
  }) : _reducer = reducer ?? GameStateReducer() {
    _initQuests();
    _initGameState();
    _startExpirationTimer();
  }

  final GameStateReducer _reducer;
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
    _state = _state.copyWith(quests: const {});
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
  Future<void> get idle => _queue;

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
          notifyListeners();

          if ((event.path.contains('/api_get_member/questlist') ||
                  event.path.contains('/api_req_quest/clearitemget') ||
                  event.path.contains('/api_req_quest/stop')) &&
              questStore != null) {
            await questStore!.saveQuests(next.quests);
          }
          if (gameStateStore != null) {
            gameStateStore!.save(next);
          }

          if (event.path.endsWith('/api_req_mission/result')) {
            _recordExpeditionResult(event);
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
        notifyListeners();
      }
    });
  }

  void _recordExpeditionResult(CapturedApiEvent event) {
    try {
      final data = GameApiDecoder.decodeData(event.responseBody);
      if (data is Map) {
        final clearResult = data['api_clear_result'];
        final result = clearResult is int
            ? clearResult
            : int.tryParse(clearResult?.toString() ?? '0') ?? 0;
        final name = data['api_quest_name']?.toString() ?? '远征';

        final materialObj = data['api_get_material'];
        final materials = <int>[];
        if (materialObj is List) {
          for (final item in materialObj) {
            materials.add(
              item is int ? item : int.tryParse(item?.toString() ?? '0') ?? 0,
            );
          }
        }

        final expeditionId =
            int.tryParse(
              event.requestParams['api_mission_id']?.toString() ?? '0',
            ) ??
            0;

        // Items are in api_get_item1 and api_get_item2
        // If it's a bucket (useitem_id = 1), count it.
        int bucketYield = 0;
        final item1 = data['api_get_item1'];
        if (item1 is Map && item1['api_useitem_id'] == 1) {
          bucketYield +=
              int.tryParse(item1['api_useitem_count']?.toString() ?? '0') ?? 0;
        }
        final item2 = data['api_get_item2'];
        if (item2 is Map && item2['api_useitem_id'] == 1) {
          bucketYield +=
              int.tryParse(item2['api_useitem_count']?.toString() ?? '0') ?? 0;
        }

        LogbookDatabase.instance
            .insertExpeditionResult(
              expeditionId: expeditionId,
              name: name,
              result: result,
              materials: materials,
              bucketYield: bucketYield,
            )
            .catchError((error) {
              debugPrint('远征记录写入失败: $error');
            });
      }
    } catch (error) {
      debugPrint('远征结果解析失败: $error');
    }
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _disposed = true;
    if (gameStateStore != null) {
      unawaited(gameStateStore!.flush());
    }
    super.dispose();
  }
}
