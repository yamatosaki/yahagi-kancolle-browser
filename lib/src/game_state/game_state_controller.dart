import 'dart:async';

import 'package:flutter/foundation.dart';
import '../account/account_session.dart';
import '../account/shared_game_data.dart';

import '../bridge/captured_api_event.dart';
import '../quest/quest_store.dart';
import '../quest/quest_progress_engine.dart';
import '../battle/battle_models.dart';
import '../performance/frame_notification_coalescer.dart';
import 'game_state.dart';
import 'game_api_event_pipeline.dart';
import 'game_state_reducer.dart';
import 'game_state_store.dart';
import '../logbook/logbook_database.dart';
import '../logbook/logbook_event_recorder.dart';
import '../fleet/global_game_timer.dart';
import '../fleet/timer_mechanics_service.dart';

final class GameStateController extends ChangeNotifier
    implements GameApiEventConsumer {
  GameStateController({
    GameStateReducer? reducer,
    this.questStore,
    this.questProgress,
    this.gameStateStore,
    this.accountSession,
    LogbookEventRecorder? logbookRecorder,
    FrameNotificationCoalescer? captureNotifications,
    TimerMechanicsService? timerService,
  }) : _reducer = reducer ?? GameStateReducer(),
       _logbookRecorder = logbookRecorder ?? LogbookEventRecorder(),
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer(),
       _timerService =
           timerService ??
           TimerMechanicsService(accountSession: accountSession) {
    accountSession?.addListener(_onAccountChanged);
    _initialization = _initialize();
    _startExpirationTimer();
  }

  final GameStateReducer _reducer;
  final LogbookEventRecorder _logbookRecorder;
  final FrameNotificationCoalescer _captureNotifications;
  final TimerMechanicsService _timerService;
  final QuestStore? questStore;
  final QuestProgressEngine? questProgress;
  LiveBattle? Function()? questBattleSnapshot;
  bool Function()? questBattleTrusted;
  Set<int> get completedQuestIds =>
      questProgress?.completedIds(DateTime.now().toUtc()) ?? const {};
  final GameStateStore? gameStateStore;
  final AccountSession? accountSession;
  Timer? _expirationTimer;
  late final Future<void> _initialization;

  @visibleForTesting
  static bool disableTimerForTest = false;

  Future<void> initialize() => _initialization;

  bool _isCurrent(AccountScope? scope) =>
      !_disposed && (scope == null || accountSession!.isCurrent(scope));

  QuestStore? _questsFor(int memberId) {
    final store = questStore;
    return store is AccountQuestStore ? store.forAccount(memberId) : store;
  }

  void _onAccountChanged() {
    final scope = accountSession!.current;
    _hasAcceptedLiveEvent = true;
    if (!scope.isKnown ||
        (_state.memberId > 0 && _state.memberId != scope.memberId)) {
      _state = sharedGameData(_state);
    }
    questProgress?.resetSession();
    _lastError = null;
    _lastUpdatedPath = null;
    _lastLogbookError = null;
    notifyListeners();
  }

  Future<void> _initialize() async {
    final scope = accountSession?.current;
    await _initQuests();
    await _initGameState();
    if (!_isCurrent(scope)) return;
    if (questProgress != null) {
      final restored = await questProgress!.restore(
        _state,
        DateTime.now().toUtc(),
      );
      if (_isCurrent(scope)) _state = restored;
    }
  }

  void _startExpirationTimer() {
    if (disableTimerForTest) return;
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final expiredState = questProgress?.expire(
        _state,
        DateTime.now().toUtc(),
      );
      if (expiredState != null && !identical(expiredState, _state)) {
        _state = expiredState;
        notifyListeners();
      }
      if (_state.quests.isEmpty && _state.availableQuests.isEmpty) return;

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
      final availableQuests = <int, GameQuest>{
        for (final entry in _state.availableQuests.entries)
          if (!entry.value.isExpired(now)) entry.key: entry.value,
      };
      hasExpired |= availableQuests.length != _state.availableQuests.length;

      if (hasExpired) {
        _state = _state.copyWith(
          quests: validQuests,
          availableQuests: availableQuests,
          hasCompleteQuestData: false,
        );
        notifyListeners();
        if (questStore != null) {
          questStore!.saveQuests(validQuests);
        }
      }
    });
  }

  Future<void> _initQuests() async {
    if (questStore == null) return;
    final scope = accountSession?.current;
    try {
      final cachedQuests = await questStore!.loadQuests();
      if (!_isCurrent(scope)) return;
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
    final scope = accountSession?.current;
    try {
      final cachedState = await gameStateStore!.load();
      if (!_isCurrent(scope)) return;
      if (!_hasAcceptedLiveEvent &&
          (cachedState.updatedAt != null ||
              cachedState.hasPortData ||
              cachedState.hasMasterData)) {
        // Keep existing quests if they were already loaded by _initQuests
        _state = cachedState.copyWith(quests: _state.quests);
        notifyListeners();
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> clearQuestsCache() async {
    final scope = accountSession?.current;
    final store = _questsFor(_state.memberId);
    if (questProgress != null) {
      await _initialization;
      await _queue;
      if (!_isCurrent(scope)) return;
      await questProgress!.clear();
    }
    if (store != null) {
      await store.clearQuests();
    }
    if (!_isCurrent(scope)) return;
    _state = _state.copyWith(
      quests: const {},
      availableQuests: const {},
      hasQuestData: false,
      hasCompleteQuestData: false,
      activeQuestCount: 0,
    );
    notifyListeners();
  }

  GameState _state = GameState.empty;
  Future<void> _queue = Future<void>.value();
  Future<void> _logbookQueue = Future<void>.value();
  String? _lastLogbookError;
  String? _lastError;
  String? _lastUpdatedPath;
  bool _disposed = false;
  bool _hasAcceptedLiveEvent = false;

  GameState get state => _state;
  String? get lastError => _lastError;
  String? get lastUpdatedPath => _lastUpdatedPath;
  TimerMechanicsService get timerService => _timerService;
  GlobalGameTimer get akashiTimer => _timerService.akashiTimer;
  GlobalGameTimer get nozakiTimer => _timerService.nozakiTimer;
  DateTime? get anchorageRepairStartedAt => _timerService.akashiTimer.anchorAt;
  DateTime? get nosakiSparkleStartedAt => _timerService.nozakiTimer.anchorAt;
  @override
  Future<void> get idle => _queue;

  /// Persistence is ordered but must not delay live game state or safety checks.
  Future<void> get logbookIdle => _logbookQueue;
  String? get lastLogbookError => _lastLogbookError;

  @override
  bool supportsPath(String path) {
    return _reducer.supportsPath(path) ||
        _logbookRecorder.supports(path) ||
        (questProgress != null &&
            (path == '/kcsapi/api_req_practice/battle' ||
                path == '/kcsapi/api_req_kousyou/remodel_slot'));
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed) {
      return;
    }
    _hasAcceptedLiveEvent = true;
    final scope = accountSession?.current;
    final questBattle = questBattleSnapshot?.call();
    final questBattleIsTrusted = questBattleTrusted?.call() ?? false;
    _queue = _queue.then((_) async {
      if (!_isCurrent(scope)) {
        return;
      }
      try {
        if (questProgress != null) await _initialization;
        if (!_isCurrent(scope)) return;
        final previous = _state;
        if (_logbookRecorder.supports(event.path)) {
          _logbookQueue = _logbookQueue.then((_) async {
            try {
              await _logbookRecorder.record(event, previous);
            } catch (error) {
              _lastLogbookError = 'Logbook write failed (${error.runtimeType})';
              debugPrint(_lastLogbookError);
            }
          });
        }
        var next = _reducer.reduce(previous, event);
        var hasAccountScopedQuests = false;
        if (accountSession != null &&
            next.memberId > 0 &&
            previous.memberId != next.memberId) {
          // Restore only this verified account's task state. Inventory and
          // safety flags come from live responses, never from a cached login.
          final cached = await gameStateStore?.loadForAccount(next.memberId);
          final quests = await _questsFor(next.memberId)?.loadQuests();
          if (!_isCurrent(scope)) return;
          next = next.copyWith(
            quests: quests?.isNotEmpty == true ? quests : cached?.quests,
          );
          hasAccountScopedQuests = true;
        }
        if (questProgress != null) {
          next = await questProgress!.process(
            previous,
            next,
            event,
            battle: questBattle,
            battleTrusted: questBattleIsTrusted,
            hasAccountScopedQuests: hasAccountScopedQuests,
          );
        }
        if (!_isCurrent(scope)) return;
        if (!identical(next, previous)) {
          _timerService.observe(
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
                  event.path.contains('/api_req_quest/stop') ||
                  event.path.contains('/api_req_quest/start')) &&
              questStore != null) {
            await _questsFor(next.memberId)!.saveQuests(next.quests);
          }
          if (gameStateStore != null) {
            gameStateStore!.save(next);
          }

          if (next.memberId > 0 && event.path.endsWith('/api_port/port')) {
            LogbookDatabase.forAccount(
              next.memberId,
            ).insertResourceSnapshot(next).catchError((error) {
              debugPrint('资源快照写入失败: $error');
            });
          }
        }
      } catch (error) {
        if (!_isCurrent(scope)) return;
        _lastError = '游戏数据解析失败（${error.runtimeType}）';
        _captureNotifications.schedule(notifyListeners);
      }
    });
  }

  void applyFriendlyBattleHp(Map<int, int> hpByShipId, DateTime capturedAt) {
    if (_disposed || hpByShipId.isEmpty) return;
    final scope = accountSession?.current;
    _queue = _queue.then((_) {
      if (!_isCurrent(scope)) return;
      final previous = _state;
      // A delayed prediction is not authoritative after returning to port.
      if (!previous.combatState.isActive) return;
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
    accountSession?.removeListener(_onAccountChanged);
    _timerService.dispose();
    _expirationTimer?.cancel();
    _disposed = true;
    _captureNotifications.dispose();
    if (gameStateStore != null) {
      unawaited(gameStateStore!.flush());
    }
    super.dispose();
  }
}
