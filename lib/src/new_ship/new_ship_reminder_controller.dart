import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../account/account_session.dart';
import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import '../inventory/unowned_inventory_projection.dart';
import 'new_ship_reminder_store.dart';

class NewShipAlert {
  NewShipAlert({
    required this.key,
    required Iterable<int> masterIds,
    required Iterable<NewShipAcquisitionSource> sources,
    required this.occurredAt,
  }) : masterIds = List<int>.unmodifiable((masterIds.toSet().toList()..sort())),
       sources = Set<NewShipAcquisitionSource>.unmodifiable(sources.toSet());

  final String key;
  final List<int> masterIds;
  final Set<NewShipAcquisitionSource> sources;
  final DateTime occurredAt;
}

typedef NewShipAlertPublisher = void Function(NewShipAlert alert);

final class NewShipReminderController extends ChangeNotifier
    implements GameApiEventConsumer {
  NewShipReminderController({
    required this.stateProvider,
    required this.store,
    required this.onPublish,
    this.waitForGameState,
    this.accountSession,
  }) {
    accountSession?.addListener(_onAccountChanged);
  }

  final GameState Function() stateProvider;
  final NewShipReminderStore store;
  final NewShipAlertPublisher onPublish;
  final Future<void> Function()? waitForGameState;
  final AccountSession? accountSession;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();
  final Set<String> _acceptedEventKeys = <String>{};
  Set<int> _excludedFamilyIds = <int>{};
  int _loadedMemberId = 0;
  int _activeMemberId = 0;
  int _accountGeneration = 0;
  NewShipAlert? _currentAlert;

  Set<int> get excludedFamilyIds => Set<int>.unmodifiable(_excludedFamilyIds);
  NewShipAlert? get currentAlert => _currentAlert;

  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) =>
      path == '/kcsapi/api_start2/getData' ||
      path == '/kcsapi/api_get_member/basic' ||
      path == '/kcsapi/api_port/port' ||
      path.endsWith('/battleresult') ||
      path.endsWith('/battle_result') ||
      path == '/kcsapi/api_req_kousyou/getship' ||
      path == '/kcsapi/api_req_quest/clearitemget';

  void _onAccountChanged() =>
      _selectAccount(accountSession!.current.memberId, newSession: true);

  @override
  void dispose() {
    _disposed = true;
    _accountGeneration += 1;
    accountSession?.removeListener(_onAccountChanged);
    super.dispose();
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed || !supportsPath(event.path) || event.apiResult != 1) return;
    if (event.path == '/kcsapi/api_start2/getData') {
      _selectAccount(0, newSession: true);
      return;
    }
    final stateBeforeEvent = stateProvider();
    final data = _apiData(event);
    final basic = event.path == '/kcsapi/api_port/port' && data is Map
        ? data['api_basic']
        : event.path == '/kcsapi/api_get_member/basic'
        ? data
        : null;
    // The first port response can belong to a different account than the
    // pre-event snapshot. Its identity is authoritative for pending reminders.
    final memberId = basic is Map
        ? (_positiveInt(basic['api_member_id']) ?? 0)
        : stateBeforeEvent.memberId;
    _selectAccount(memberId);
    final generation = _accountGeneration;
    // Capture this event's reducer future now, before later events are queued.
    final stateReady = waitForGameState?.call();
    Future<void> process() async {
      await stateReady;
      if (!_isCurrentAccount(memberId, generation)) return;
      await _process(event, stateBeforeEvent, memberId, generation);
    }

    _queue = _queue.then((_) => process(), onError: (_) => process());
  }

  Future<void> setFamilyExcluded(int familyRootId, bool excluded) async {
    final memberId = stateProvider().memberId;
    if (familyRootId <= 0 || memberId <= 0) return;
    _selectAccount(memberId);
    final generation = _accountGeneration;
    await _ensureAccount(memberId);
    if (!_isCurrentAccount(memberId, generation)) return;
    if (excluded) {
      _excludedFamilyIds.add(familyRootId);
    } else {
      _excludedFamilyIds.remove(familyRootId);
    }
    await store.saveExcludedFamilyIds(memberId, _excludedFamilyIds);
    if (_isCurrentAccount(memberId, generation)) notifyListeners();
  }

  Future<void> clearExcludedFamilies() async {
    final memberId = stateProvider().memberId;
    if (memberId <= 0) return;
    _selectAccount(memberId);
    final generation = _accountGeneration;
    await _ensureAccount(memberId);
    if (!_isCurrentAccount(memberId, generation)) return;
    _excludedFamilyIds.clear();
    await store.saveExcludedFamilyIds(memberId, _excludedFamilyIds);
    if (_isCurrentAccount(memberId, generation)) notifyListeners();
  }

  void acknowledge(String alertKey) {
    if (_currentAlert?.key != alertKey) return;
    _currentAlert = null;
    notifyListeners();
  }

  Future<void> _process(
    CapturedApiEvent event,
    GameState state,
    int memberId,
    int generation,
  ) async {
    await _ensureAccount(memberId);
    if (!_isCurrentAccount(memberId, generation)) return;
    if (event.path == '/kcsapi/api_get_member/basic') return;
    final eventKey = '$memberId:${event.path}:${event.sequence}';
    if (!_acceptedEventKeys.add(eventKey)) return;
    if (_acceptedEventKeys.length > 512) {
      _acceptedEventKeys.remove(_acceptedEventKeys.first);
    }

    if (event.path == '/kcsapi/api_port/port') {
      await _publishPending(memberId, generation, _apiData(event));
      return;
    }

    final data = _apiData(event);
    final source = _sourceFor(event.path);
    final detections = <NewShipAcquisitionSource, Set<int>>{
      source: _shipMasterIds(data, event.path),
      if (source == NewShipAcquisitionSource.battle)
        NewShipAcquisitionSource.eventReward: _eventRewardShipIds(data),
    };
    final pending = <PendingNewShipAcquisition>[
      for (final entry in detections.entries)
        if (_eligibleMasterIds(state, entry.value) case final ids
            when ids.isNotEmpty)
          PendingNewShipAcquisition(
            key: '$eventKey:${entry.key.name}',
            masterIds: ids,
            source: entry.key,
            occurredAt: event.capturedAt,
          ),
    ];
    if (pending.isEmpty) return;
    if (source == NewShipAcquisitionSource.battle) {
      final existing = await store.loadPending(memberId);
      if (!_isCurrentAccount(memberId, generation)) return;
      await store.savePending(memberId, <PendingNewShipAcquisition>[
        ...existing,
        ...pending,
      ]);
      return;
    }
    _publish(pending, memberId, generation);
  }

  void _selectAccount(int memberId, {bool newSession = false}) {
    if (!newSession && memberId == _activeMemberId) return;
    _activeMemberId = memberId;
    _accountGeneration += 1;
    _loadedMemberId = 0;
    _excludedFamilyIds = <int>{};
    _acceptedEventKeys.clear();
    _currentAlert = null;
    notifyListeners();
  }

  bool _isCurrentAccount(int memberId, int generation) =>
      !_disposed &&
      memberId > 0 &&
      (accountSession == null ||
          accountSession!.current.memberId == memberId) &&
      memberId == _activeMemberId &&
      generation == _accountGeneration &&
      stateProvider().memberId == memberId;

  Future<void> _ensureAccount(int memberId) async {
    if (memberId <= 0 || memberId == _loadedMemberId) return;
    final generation = _accountGeneration;
    final excluded = await store.loadExcludedFamilyIds(memberId);
    if (!_isCurrentAccount(memberId, generation)) return;
    _excludedFamilyIds = excluded;
    _loadedMemberId = memberId;
    notifyListeners();
  }

  Future<void> _publishPending(
    int memberId,
    int generation,
    Object? data,
  ) async {
    if (data is! Map || data['api_ship'] is! List) return;
    // Revalidate persisted drops against this account's authoritative inventory.
    // A ship may have been locked or removed since the reminder was queued.
    final unlockedIds = <int>{
      for (final ship in data['api_ship'] as List)
        if (ship is Map && _positiveInt(ship['api_locked']) != 1)
          ?_positiveInt(ship['api_ship_id']),
    };
    final pending = await store.loadPending(memberId);
    if (!_isCurrentAccount(memberId, generation)) return;
    await store.savePending(memberId, const <PendingNewShipAcquisition>[]);
    final verified = <PendingNewShipAcquisition>[
      for (final item in pending)
        if (item.masterIds.where(unlockedIds.contains).toList() case final ids
            when ids.isNotEmpty)
          PendingNewShipAcquisition(
            key: item.key,
            masterIds: ids,
            source: item.source,
            occurredAt: item.occurredAt,
          ),
    ];
    if (verified.isNotEmpty) _publish(verified, memberId, generation);
  }

  void _publish(
    List<PendingNewShipAcquisition> acquisitions,
    int memberId,
    int generation,
  ) {
    if (!_isCurrentAccount(memberId, generation)) return;
    final ids = <int>{};
    final sources = <NewShipAcquisitionSource>{};
    var occurredAt = acquisitions.first.occurredAt;
    final keys = <String>[];
    final projection = UnownedInventoryProjection(stateProvider());
    for (final acquisition in acquisitions) {
      keys.add(acquisition.key);
      sources.add(acquisition.source);
      if (acquisition.occurredAt.isAfter(occurredAt)) {
        occurredAt = acquisition.occurredAt;
      }
      for (final id in acquisition.masterIds) {
        if (!_excludedFamilyIds.contains(projection.familyRootOf(id))) {
          ids.add(id);
        }
      }
    }
    if (ids.isEmpty) return;
    keys.sort();
    final alert = NewShipAlert(
      key: keys.join('|'),
      masterIds: ids,
      sources: sources,
      occurredAt: occurredAt,
    );
    _currentAlert = alert;
    onPublish(alert);
    notifyListeners();
  }

  Set<int> _eligibleMasterIds(GameState state, Set<int> detected) {
    final projection = UnownedInventoryProjection(state);
    final ownedRoots = state.ships.values
        .map((ship) => projection.familyRootOf(ship.masterId))
        .toSet();
    return <int>{
      for (final id in detected)
        if (state.masterShips.containsKey(id) &&
            !ownedRoots.contains(projection.familyRootOf(id)) &&
            !_excludedFamilyIds.contains(projection.familyRootOf(id)))
          id,
    };
  }

  static NewShipAcquisitionSource _sourceFor(String path) {
    if (path.endsWith('/battleresult') || path.endsWith('/battle_result')) {
      return NewShipAcquisitionSource.battle;
    }
    if (path == '/kcsapi/api_req_kousyou/getship') {
      return NewShipAcquisitionSource.construction;
    }
    if (path == '/kcsapi/api_req_quest/clearitemget') {
      return NewShipAcquisitionSource.questReward;
    }
    return NewShipAcquisitionSource.eventReward;
  }

  static Object? _apiData(CapturedApiEvent event) {
    try {
      final envelope = event.decodedEnvelope ?? jsonDecode(event.responseBody);
      return envelope is Map ? envelope['api_data'] : null;
    } on FormatException {
      return null;
    }
  }

  static Set<int> _shipMasterIds(Object? data, String path) {
    if (data is! Map) return <int>{};
    if (path.endsWith('/battleresult') || path.endsWith('/battle_result')) {
      final ship = data['api_get_ship'];
      return ship is Map ? <int>{?_positiveInt(ship['api_ship_id'])} : <int>{};
    }
    if (path == '/kcsapi/api_req_kousyou/getship') {
      final ship = data['api_ship'];
      return ship is Map ? <int>{?_positiveInt(ship['api_ship_id'])} : <int>{};
    }
    if (path == '/kcsapi/api_req_quest/clearitemget') {
      final bonuses = data['api_bounus'];
      if (bonuses is! List) return <int>{};
      // Quest type 1 is a consumable (e.g. development material ID 7),
      // not a ship master ID. Type 11 carries an actual awarded ship.
      return <int>{
        for (final bonus in bonuses)
          if (bonus is Map && _positiveInt(bonus['api_type']) == 11)
            if (bonus['api_item'] case final Map ship)
              ?_positiveInt(ship['api_ship_id']),
      };
    }
    return <int>{};
  }

  static Set<int> _eventRewardShipIds(Object? data) {
    if (data is! Map || data['api_get_eventitem'] is! List) return <int>{};
    // Event type 2 is a ship; type 1 is an item and type 3 is equipment.
    return <int>{
      for (final reward in data['api_get_eventitem'] as List)
        if (reward is Map && _positiveInt(reward['api_type']) == 2)
          ?_positiveInt(reward['api_id']),
    };
  }

  static int? _positiveInt(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
