import 'dart:async';

import 'package:flutter/foundation.dart';
import '../account/account_session.dart';
import '../account/shared_game_data.dart';

import '../bridge/captured_api_event.dart';
import '../quest/quest_store.dart';
import '../quest/quest_progress_engine.dart';
import '../battle/battle_models.dart';
import '../battle/sortie_damage_control_ledger.dart';
import '../performance/frame_notification_coalescer.dart';
import 'game_state.dart';
import 'game_api_event_pipeline.dart';
import 'conservative_battle_hp_update.dart';
import 'game_state_reducer.dart';
import 'game_state_store.dart';
import '../logbook/logbook_database.dart';
import '../logbook/logbook_event_recorder.dart';
import '../fleet/global_game_timer.dart';
import '../fleet/timer_mechanics_service.dart';

final class GameStateController extends ChangeNotifier
    implements GameApiEventConsumer, GameApiContinuityGuard {
  GameStateController({
    GameState? initialState,
    GameStateReducer? reducer,
    this.questStore,
    this.questProgress,
    this.gameStateStore,
    this.accountSession,
    LogbookEventRecorder? logbookRecorder,
    FrameNotificationCoalescer? captureNotifications,
    TimerMechanicsService? timerService,
  }) : _state = initialState ?? GameState.empty,
       _hasAcceptedLiveEvent = initialState != null,
       _reducer = reducer ?? GameStateReducer(),
       _logbookRecorder = logbookRecorder ?? LogbookEventRecorder(),
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer(),
       _timerService =
           timerService ??
           TimerMechanicsService(accountSession: accountSession) {
    _accountScope = accountSession?.current;
    accountSession?.addListener(_onAccountChanged);
    _initialization = _initialize();
    _startExpirationTimer();
  }

  final GameStateReducer _reducer;
  final LogbookEventRecorder _logbookRecorder;
  final FrameNotificationCoalescer _captureNotifications;
  final ChangeNotifier _notificationChanges = ChangeNotifier();
  final TimerMechanicsService _timerService;
  final QuestStore? questStore;
  final QuestProgressEngine? questProgress;
  LiveBattle? Function()? questBattleSnapshot;
  bool Function()? questBattleTrusted;
  Set<int> get completedQuestIds =>
      questProgress?.completedIds(DateTime.now().toUtc()) ?? const {};
  final GameStateStore? gameStateStore;
  final AccountSession? accountSession;
  final Map<int, List<DamageControlEquipmentRef>> _sortieConsumptions = {};
  int _captureContinuityGeneration = 0;
  bool _captureContinuityInterrupted = false;
  String? _sortieCaptureDocumentId;
  AccountScope? _accountScope;
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
    if (identical(scope, _accountScope)) return;
    _accountScope = scope;
    _sortieConsumptions.clear();
    _captureContinuityInterrupted = false;
    _sortieCaptureDocumentId = null;
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
      if (_isCurrent(scope) && !identical(restored, _state)) {
        _state = restored;
        notifyListeners();
      }
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

  GameState _state;
  Future<void> _queue = Future<void>.value();
  Future<void> _logbookQueue = Future<void>.value();
  String? _lastLogbookError;
  String? _lastError;
  String? _lastUpdatedPath;
  bool _disposed = false;
  bool _hasAcceptedLiveEvent;

  GameState get state => _state;

  /// State changes for notification scheduling, independent of UI frames.
  Listenable get notificationChanges => _notificationChanges;

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
  void notifyListeners() {
    if (_disposed) return;
    _notificationChanges.notifyListeners();
    _notifyUiListeners();
  }

  // A rendered frame must not rebroadcast a state already sent to scheduling.
  void _notifyUiListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _notifyCapturedStateChange() {
    if (_disposed) return;
    _notificationChanges.notifyListeners();
    _captureNotifications.schedule(_notifyUiListeners);
  }

  @override
  void interruptCaptureContinuity() {
    _captureContinuityGeneration++;
    _captureContinuityInterrupted = true;
  }

  bool _preservesInterruptedConsumptions(CapturedApiEvent event) =>
      _captureContinuityInterrupted &&
      _sortieConsumptions.isNotEmpty &&
      (event.captureDocumentId == null ||
          _sortieCaptureDocumentId == null ||
          event.captureDocumentId == _sortieCaptureDocumentId);

  @override
  bool allowsCaptureEvent(CapturedApiEvent event) {
    if (!_preservesInterruptedConsumptions(event)) return true;
    if (event.path == '/kcsapi/api_start2/getData') return false;
    final data = event.decodedEnvelope?['api_data'];
    if (event.path == '/kcsapi/api_get_member/basic') {
      return data is Map &&
          _captureInteger(data['api_member_id']) == _state.memberId;
    }
    if (event.path == '/kcsapi/api_get_member/require_info' &&
        data is Map &&
        data.containsKey('api_basic')) {
      final basic = data['api_basic'];
      return basic is Map &&
          _captureInteger(basic['api_member_id']) == _state.memberId;
    }
    if (event.path != '/kcsapi/api_port/port') return true;
    if (data is! Map) return false;
    final basic = data['api_basic'];
    final ships = data['api_ship'];
    final decks = data.containsKey('api_deck_port')
        ? data['api_deck_port']
        : data['api_deck'];
    if (basic is! Map ||
        _captureInteger(basic['api_member_id']) <= 0 ||
        (_state.memberId > 0 &&
            _captureInteger(basic['api_member_id']) != _state.memberId) ||
        ships is! List ||
        ships.isEmpty ||
        decks is! List ||
        decks.isEmpty) {
      return false;
    }
    final spentIds = <int>{
      for (final refs in _sortieConsumptions.values)
        for (final ref in refs) ref.instanceId,
    };
    final shipIds = <int>{};
    for (final ship in ships) {
      if (ship is! Map ||
          _captureInteger(ship['api_id']) <= 0 ||
          !shipIds.add(_captureInteger(ship['api_id'])) ||
          !_isCaptureInteger(ship['api_nowhp']) ||
          !_isCaptureInteger(ship['api_maxhp']) ||
          (ship['api_maxhp'] as num) <= 0 ||
          (ship['api_nowhp'] as num) < 0 ||
          (ship['api_nowhp'] as num) > (ship['api_maxhp'] as num) ||
          ship['api_slot'] is! List ||
          !_isCaptureInteger(ship['api_slot_ex'])) {
        return false;
      }
      final slots = ship['api_slot'] as List;
      if (slots.any((slot) => !_isCaptureInteger(slot)) ||
          slots.any((slot) => spentIds.contains(_captureInteger(slot))) ||
          spentIds.contains(_captureInteger(ship['api_slot_ex']))) {
        return false;
      }
    }
    var hasFleetShip = false;
    for (final deck in decks) {
      if (deck is! Map ||
          _captureInteger(deck['api_id']) <= 0 ||
          deck['api_ship'] is! List) {
        return false;
      }
      for (final shipId in deck['api_ship'] as List) {
        if (!_isCaptureInteger(shipId) ||
            (_captureInteger(shipId) > 0 &&
                !shipIds.contains(_captureInteger(shipId)))) {
          return false;
        }
        if (_captureInteger(shipId) > 0) hasFleetShip = true;
      }
    }
    if (!hasFleetShip) return false;
    if (data.containsKey('api_slot_item')) {
      final items = data['api_slot_item'];
      if (items is! List ||
          items.any(
            (item) =>
                item is! Map ||
                _captureInteger(item['api_id']) <= 0 ||
                spentIds.contains(_captureInteger(item['api_id'])),
          )) {
        return false;
      }
    }
    return true;
  }

  static int _captureInteger(Object? value) => _isCaptureInteger(value)
      ? (value! as num).toInt()
      : int.tryParse('$value') ?? 0;

  static bool _isCaptureInteger(Object? value) =>
      value is num && value.isFinite && value == value.truncateToDouble();

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
    final continuityGeneration = _captureContinuityGeneration;
    final questBattle = questBattleSnapshot?.call();
    final questBattleIsTrusted = questBattleTrusted?.call() ?? false;
    _queue = _queue.then((_) async {
      if (!_isCurrent(scope) ||
          continuityGeneration != _captureContinuityGeneration) {
        return;
      }
      try {
        if (questProgress != null) await _initialization;
        if (!_isCurrent(scope) ||
            continuityGeneration != _captureContinuityGeneration) {
          return;
        }
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
        final resetsConsumptions =
            event.path == '/kcsapi/api_port/port' ||
            event.path == '/kcsapi/api_start2/getData' ||
            (event.path == '/kcsapi/api_req_map/start' &&
                !_preservesInterruptedConsumptions(event)) ||
            next.memberId != previous.memberId;
        if (!resetsConsumptions &&
            next.combatState.isActive &&
            _sortieConsumptions.isNotEmpty) {
          next = _reducer.reconcileSortieConsumptions(
            previous,
            next,
            _sortieConsumptions,
            event.capturedAt,
          );
        }
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
        if (!_isCurrent(scope) ||
            continuityGeneration != _captureContinuityGeneration) {
          return;
        }
        if (resetsConsumptions) {
          _sortieConsumptions.clear();
          _captureContinuityInterrupted = false;
          _sortieCaptureDocumentId = null;
        }
        if (next.combatState.isActive && event.captureDocumentId != null) {
          _sortieCaptureDocumentId = event.captureDocumentId;
        }
        if (!identical(next, previous)) {
          _timerService.observe(
            previousState: previous,
            nextState: next,
            event: event,
          );
          _state = next;
          _lastUpdatedPath = event.path;
          _lastError = null;
          // Goal transitions must be observed before a following response can
          // claim/remove the task. Ordinary UI updates still coalesce by frame.
          if (_reachedQuestGoal(previous, next, event.capturedAt)) {
            notifyListeners();
          } else {
            _notifyCapturedStateChange();
          }

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
        _captureNotifications.schedule(_notifyUiListeners);
      }
    });
  }

  bool _reachedQuestGoal(GameState previous, GameState next, DateTime now) {
    if (previous.memberId != next.memberId) return false;
    for (final quest in next.quests.values) {
      if (!quest.isAccepted || !_isCurrentQuestPeriod(quest, now)) continue;
      var before = previous.quests[quest.id];
      if (before != null && !_isCurrentQuestPeriod(before, now)) before = null;
      if (quest.isCompleted &&
          (before == null || !before.isAccepted || !before.isCompleted)) {
        return true;
      }
      if (_hasFullQuestCount(quest) && !_hasFullQuestCount(before)) return true;
    }
    return false;
  }

  bool _isCurrentQuestPeriod(GameQuest quest, DateTime now) =>
      !quest.isExpired(now) &&
      (questProgress == null ||
          quest.updatedAt == null ||
          questProgress!.periodFor(quest, quest.updatedAt!) ==
              questProgress!.periodFor(quest, now));

  bool _hasFullQuestCount(GameQuest? quest) =>
      quest != null &&
      quest.isAccepted &&
      (quest.progressRequired ?? 0) > 0 &&
      (quest.progressCurrent ?? 0) >= quest.progressRequired!;

  void applyFriendlyBattleHp(Map<int, int> hpByShipId, DateTime capturedAt) {
    if (_disposed || hpByShipId.isEmpty) return;
    final scope = accountSession?.current;
    final continuityGeneration = _captureContinuityGeneration;
    _queue = _queue.then((_) {
      if (!_isCurrent(scope) ||
          continuityGeneration != _captureContinuityGeneration) {
        return;
      }
      final previous = _state;
      // A delayed prediction is not authoritative after returning to port.
      if (!previous.combatState.isActive) return;
      final effectiveHp = hpByShipId is ConservativeBattleHpUpdate
          ? <int, int>{
              for (final entry in hpByShipId.entries)
                if (previous.ships[entry.key] case final ship?
                    when ship.currentHp > 0 && entry.value < ship.currentHp)
                  entry.key: entry.value.clamp(1, ship.currentHp).toInt(),
            }
          : hpByShipId;
      final next = _reducer.applyFriendlyBattleHp(
        previous,
        effectiveHp,
        capturedAt,
      );
      if (identical(next, previous)) return;
      _state = next;
      _notifyCapturedStateChange();
      gameStateStore?.save(next);
    });
  }

  void applyDamageControlConsumption(
    Map<int, List<DamageControlEquipmentRef>> consumedByShipId,
    DateTime capturedAt,
  ) {
    if (_disposed || consumedByShipId.isEmpty) return;
    final scope = accountSession?.current;
    _queue = _queue.then((_) {
      if (!_isCurrent(scope)) return;
      final previous = _state;
      // A delayed prediction is not authoritative after returning to port.
      if (!previous.combatState.isActive) return;
      for (final entry in consumedByShipId.entries) {
        _sortieConsumptions[entry.key] =
            List<DamageControlEquipmentRef>.unmodifiable(entry.value);
      }
      final next = _reducer.applyDamageControlConsumption(
        previous,
        consumedByShipId,
        capturedAt,
      );
      if (identical(next, previous)) return;
      _state = next;
      _notifyCapturedStateChange();
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
    _notificationChanges.dispose();
    if (gameStateStore != null) {
      unawaited(gameStateStore!.flush());
    }
    super.dispose();
  }
}
