import 'dart:async';

import 'package:flutter/foundation.dart';
import '../account/account_session.dart';

import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import '../capture/sortie_warning_session.dart';
import '../game_state/combat_state.dart';
import '../game_state/conservative_battle_hp_update.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import '../game_state/land_base_raid.dart';
import 'formation_memory.dart';
import 'battle_models.dart';
import 'battle_ship_details.dart';
import 'battle_node_label_resolver.dart';
import 'battle_session.dart';
import 'fcd_map_geometry.dart';
import 'sortie_damage_control_ledger.dart';
import 'sortie_map_progress.dart';
import 'prediction/battle_prediction_engine.dart';
import 'prediction/battle_prediction_executor.dart';
import 'prediction/poi/poi_battle_prediction_engine.dart';
import '../logbook/logbook_database.dart';
import '../logbook/expedition_log_catalog.dart';
import '../performance/frame_notification_coalescer.dart';
import '../fleet/ship_damage_level.dart';
import '../settings/battle_status_effect_settings.dart';
import 'battle_damage_alert.dart';
import 'battle_detail_models.dart';
import 'battle_detail_replay_builder.dart';

final class BattleController extends ChangeNotifier
    implements GameApiEventConsumer {
  BattleController({
    required this.gameState,
    this.waitForGameState,
    void Function(Map<int, int> hpByShipId, DateTime capturedAt)?
    onFriendlyHpUpdated,
    void Function(
      Map<int, List<DamageControlEquipmentRef>> consumedByShipId,
      DateTime capturedAt,
    )?
    onDamageControlConsumed,
    this.onFleetBattleDisplayStarted,
    this.onFleetBattleDisplaySettled,
    this.damageAlertPort,
    this.battleStatusEffectSettings,
    this.poiEngineFactory,
    this.maxRecords = 100,
    this.nodeLabelResolver = const EmptyBattleNodeLabelResolver(),
    FrameNotificationCoalescer? captureNotifications,
    BattlePredictionExecutor? predictionExecutor,
    this.formationMemory,
    this.accountSession,
  }) : _friendlyHpUpdater = onFriendlyHpUpdated,
       _damageControlUpdater = onDamageControlConsumed,
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer(),
       _predictionExecutor =
           predictionExecutor ?? const IsolateBattlePredictionExecutor(),
       assert(maxRecords > 0) {
    _memberId = accountSession?.current.memberId ?? gameState().memberId;
    _accountScope = accountSession?.current;
    accountSession?.addListener(_onAccountChanged);
  }

  static const Set<String> _mapPaths = GameCapturePathCatalog.battleMap;
  static const Set<String> _battlePaths = GameCapturePathCatalog.battlePhases;
  static const Set<String> _resultPaths = GameCapturePathCatalog.battleResults;
  static const Set<String> _retreatPaths = GameCapturePathCatalog.battleRetreat;

  final GameState Function() gameState;
  final Future<void> Function()? waitForGameState;
  void Function(Map<int, int> hpByShipId, DateTime capturedAt)?
  _friendlyHpUpdater;
  void Function(
    Map<int, List<DamageControlEquipmentRef>> consumedByShipId,
    DateTime capturedAt,
  )?
  _damageControlUpdater;
  final void Function(Iterable<int> shipIds)? onFleetBattleDisplayStarted;
  final VoidCallback? onFleetBattleDisplaySettled;
  final FrameNotificationCoalescer _captureNotifications;
  final BattlePredictionExecutor _predictionExecutor;
  final BattleDamageAlertPort? damageAlertPort;
  final BattleStatusEffectSettings Function()? battleStatusEffectSettings;
  final BattlePredictionEngineFactory? poiEngineFactory;
  final int maxRecords;
  final BattleNodeLabelResolver nodeLabelResolver;
  final FormationMemoryController? formationMemory;
  final AccountSession? accountSession;
  final SortieWarningSession warningSession = SortieWarningSession();
  AccountScope? _accountScope;
  int _memberId = 0;
  int _generation = 0;
  final Map<int, List<BattleRecord>> _recordsByMember = {};
  final Map<int, List<BattleSession>> _sessionsByMember = {};

  void _onAccountChanged() {
    final scope = accountSession!.current;
    if (identical(scope, _accountScope)) return;
    _accountScope = scope;
    _selectAccount(scope.memberId);
  }

  void _selectAccount(int memberId) {
    if (_memberId > 0) {
      _recordsByMember[_memberId] = List.of(_records);
      _sessionsByMember[_memberId] = List.of(_recentSessions);
    }
    _memberId = memberId;
    _generation++;
    _current = null;
    _session = null;
    _predictionEngine = null;
    _fleetBattleDisplayPending = false;
    _lastBattleCapturedAt = null;
    _lastError = null;
    _sortieDamageControls.endSortie();
    _hasTrustedDamageControlBaseline = true;
    warningSession.endSortie();
    _clearSortieMapProgress();
    _context = const BattleContext();
    _acceptedSequences.clear();
    _records
      ..clear()
      ..addAll(_recordsByMember[memberId] ?? []);
    _recentSessions
      ..clear()
      ..addAll(_sessionsByMember[memberId] ?? []);
    if (!_disposed) {
      if (accountSession != null) {
        notifyListeners();
      } else {
        _captureNotifications.schedule(notifyListeners);
      }
    }
  }

  final List<BattleRecord> _records = <BattleRecord>[];
  final Set<int> _acceptedSequences = <int>{};
  final List<BattleSession> _recentSessions = <BattleSession>[];

  Future<void> _queue = Future<void>.value();
  BattleContext _context = const BattleContext();
  BattleSession? _session;
  BattlePredictionEngine? _predictionEngine;
  final SortieDamageControlLedger _sortieDamageControls =
      SortieDamageControlLedger();
  bool _hasTrustedDamageControlBaseline = true;
  LiveBattle? _current;
  SortieMapProgress? _sortieMapProgress;
  bool _sortieMapFallbackAllowed = true;
  CombatState? _sortieMapResetCombat;
  DateTime? _lastBattleCapturedAt;
  String? _lastError;
  bool _fleetBattleDisplayPending = false;
  bool _disposed = false;

  LiveBattle? get current {
    final battle = _current;
    final combat = gameState().combatState;
    if (battle == null ||
        battle.context.practice ||
        !combat.isActive ||
        battle.context.mapAreaId != combat.mapArea ||
        battle.context.mapInfoNo != combat.mapInfo ||
        battle.context.deckId != combat.sortieFleetId) {
      return battle;
    }
    return _withRetreatState(battle, combat.escapedShipIds);
  }

  List<BattleRecord> get records => List.unmodifiable(_records);
  GameState get gameStateSnapshot => gameState();
  String? get lastError => _lastError;
  BattleSession? get session => _session;
  bool get isDamageControlStateTrusted =>
      _sortieDamageControls.isActive && _sortieDamageControls.isTrusted;

  SortieMapProgress? get sortieMapProgress {
    if (!_sortieMapFallbackAllowed ||
        _context.practice ||
        (accountSession != null && !accountSession!.current.isKnown)) {
      return null;
    }
    final progress = _sortieMapProgress;
    if (progress != null) return progress;

    // A hot reload or an attachment during battle has no observed route
    // history. Preserve only the current node that the active context knows.
    if (_context.mapAreaId > 0 && _context.mapInfoNo > 0 && _context.node > 0) {
      return SortieMapProgress(
        mapAreaId: _context.mapAreaId,
        mapInfoNo: _context.mapInfoNo,
        routeIds: [_context.node],
        bossRouteId: _context.bossNode > 0 ? _context.bossNode : null,
        isPartial: true,
      );
    }
    final combat = gameState().combatState;
    if (!combat.isActive ||
        combat.mapArea <= 0 ||
        combat.mapInfo <= 0 ||
        combat.currentNode <= 0) {
      return null;
    }
    return SortieMapProgress(
      mapAreaId: combat.mapArea,
      mapInfoNo: combat.mapInfo,
      routeIds: [combat.currentNode],
      isPartial: true,
    );
  }

  FcdMapGeometry? get sortieMapGeometry {
    final progress = sortieMapProgress;
    final resolver = nodeLabelResolver;
    if (progress == null || resolver is! BattleMapGeometryResolver) return null;
    return (resolver as BattleMapGeometryResolver).geometryFor(
      mapAreaId: progress.mapAreaId,
      mapInfoNo: progress.mapInfoNo,
    );
  }

  bool get isPredictionConfirmed =>
      _lastError == null &&
      (_session?.isConfirmed ?? true) &&
      !_hasUntrustedPoiLedger;
  List<BattleSession> get recentSessions => List.unmodifiable(_recentSessions);
  @override
  Future<void> get idle => _queue;

  void invalidateCaptureContinuity() {
    if (_disposed) return;
    _generation++;
    _acceptedSequences.clear();
    _fleetBattleDisplayPending = false;
    _lastBattleCapturedAt = null;
    _hasTrustedDamageControlBaseline = false;
    _sortieDamageControls.beginSortie(
      trusted: false,
      reason: 'capture continuity interrupted',
    );
    warningSession.endSortie();
    _captureNotifications.schedule(notifyListeners);
  }

  void bindFriendlyHpUpdater(
    void Function(Map<int, int> hpByShipId, DateTime capturedAt) updater,
  ) {
    // A rebuild must not replay an old prediction over a newer ship snapshot.
    if (_friendlyHpUpdater == updater) return;
    _friendlyHpUpdater = updater;
    final current = _current;
    if (current == null ||
        current.context.practice ||
        current.displayStage == BattleDisplayStage.navigation ||
        (_hasUntrustedPoiLedger && _lastBattleCapturedAt == null)) {
      return;
    }
    _emitFriendlyHp(current, _lastBattleCapturedAt ?? DateTime.now().toUtc());
  }

  void bindDamageControlUpdater(
    void Function(
      Map<int, List<DamageControlEquipmentRef>> consumedByShipId,
      DateTime capturedAt,
    )
    updater,
  ) {
    _damageControlUpdater = updater;
    final current = _current;
    if (current == null ||
        current.context.practice ||
        current.displayStage == BattleDisplayStage.navigation ||
        _hasUntrustedPoiLedger ||
        _sortieDamageControls.consumedByShipId.isEmpty) {
      return;
    }
    _emitDamageControlConsumption(
      _lastBattleCapturedAt ?? DateTime.now().toUtc(),
    );
  }

  void refreshNodeLabel() {
    if (_disposed) return;
    final refreshGeometry =
        sortieMapProgress != null &&
        nodeLabelResolver is BattleMapGeometryResolver;
    if (_context.node <= 0) {
      if (refreshGeometry) notifyListeners();
      return;
    }
    final label = nodeLabelResolver
        .resolve(
          mapAreaId: _context.mapAreaId,
          mapInfoNo: _context.mapInfoNo,
          internalNodeId: _context.node,
        )
        ?.trim();
    final normalized = label == null || label.isEmpty ? null : label;
    if (_context.nodeDisplayLabel == normalized) {
      if (refreshGeometry) notifyListeners();
      return;
    }
    _context = _context.copyWith(nodeDisplayLabel: normalized);
    final current = _current;
    if (current != null) _current = current.copyWith(context: _context);
    notifyListeners();
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed || !supportsPath(event.path)) {
      return;
    }
    if (accountSession == null && event.apiResult == 1) {
      if (event.path == '/kcsapi/api_start2/getData') {
        _selectAccount(0);
      } else if (_memberId != gameState().memberId) {
        _selectAccount(gameState().memberId);
      }
    }
    final scope = accountSession?.current;
    final generation = _generation;
    final stateReady = waitForGameState?.call();
    if (scope != null &&
        !scope.isKnown &&
        event.path != '/kcsapi/api_start2/getData') {
      return;
    }
    if (event.sequence > 0 && !_acceptedSequences.add(event.sequence)) {
      return;
    }
    if (_acceptedSequences.length > 512) {
      _acceptedSequences.remove(_acceptedSequences.first);
    }
    _queue = _queue.then((_) async {
      if (_disposed) {
        return;
      }
      try {
        await stateReady;
        await formationMemory?.idle;
        if (_disposed ||
            generation != _generation ||
            (scope != null && !accountSession!.isCurrent(scope))) {
          return;
        }
        _lastError = null;
        await _reduce(event, generation);
        if (generation != _generation) return;
        _captureNotifications.schedule(notifyListeners);
      } catch (error) {
        if (generation != _generation || _disposed) return;
        if (_battlePaths.contains(event.path) &&
            _sortieDamageControls.isActive) {
          _sortieDamageControls.markUntrusted(
            'battle prediction failed before damage-control synchronization',
          );
        }
        _session?.markUnconfirmed(stage: event.path, message: error.toString());
        _lastError = '战斗数据暂时无法解析（${error.runtimeType}）';
        _captureNotifications.schedule(notifyListeners);
      }
    });
  }

  @override
  bool supportsPath(String path) =>
      GameCapturePathCatalog.battle.contains(path);

  Future<void> _reduce(CapturedApiEvent event, int generation) async {
    final envelope =
        event.decodedEnvelope ??
        GameApiDecoder.decodeEnvelope(event.responseBody);
    if (envelope['api_result'].toString() != '1') return;
    final data = GameApiDecoder.decodeEventData(
      event.withDecodedEnvelope(envelope),
      allowMissingData: _retreatPaths.contains(event.path),
    );
    if (event.path == '/kcsapi/api_port/port' ||
        event.path == '/kcsapi/api_start2/getData') {
      _map(data); // Do not clear a valid session for a malformed snapshot.
      if (event.path == '/kcsapi/api_port/port' &&
          _map(data)['api_ship'] is List) {
        _hasTrustedDamageControlBaseline = true;
      }
      _current = null;
      _archiveSession();
      _session = null;
      _predictionEngine = null;
      _fleetBattleDisplayPending = false;
      _sortieDamageControls.endSortie();
      warningSession.endSortie();
      _clearSortieMapProgress();
      _context = const BattleContext();
      return;
    }
    if (_retreatPaths.contains(event.path)) {
      _applyRetreat();
      return;
    }
    final map = _map(data);
    if (event.path.startsWith('/kcsapi/api_req_practice/')) {
      _clearSortieMapProgress();
    } else if (!_mapPaths.contains(event.path)) {
      if (_battlePaths.contains(event.path)) {
        _recoverPartialSortieMapProgress();
      }
      // Persist a node observed while attached mid-sortie before a subsequent
      // navigation response advances the game-state snapshot to another node.
      _sortieMapProgress ??= sortieMapProgress;
    }
    if (_mapPaths.contains(event.path) ||
        event.path == '/kcsapi/api_req_map/air_raid') {
      if (_mapPaths.contains(event.path)) {
        _updateSortieMapProgress(map, event);
      }
      if (event.path == '/kcsapi/api_req_map/start') {
        warningSession.startSortie();
        _sortieDamageControls.beginSortie(
          trusted: _hasTrustedDamageControlBaseline,
          reason:
              'fresh ship equipment snapshot required after capture interruption',
        );
      } else if (!_sortieDamageControls.isActive) {
        warningSession.ensureSortie();
        _sortieDamageControls.beginSortie(
          trusted: false,
          reason: 'missing previous sortie node',
        );
      }
      _context = _contextFromMap(map, event);
      final state = gameState();
      final landBaseRaid = _landBaseRaid(map, state);
      _current = LiveBattle(
        context: _context,
        friendMain: _friendFleet(
          state,
          _context.deckId,
          BattleFleetRole.main,
          nowHp: const <Object?>[],
          maxHp: const <Object?>[],
        ),
        friendEscort: _friendFleet(
          state,
          2,
          BattleFleetRole.escort,
          nowHp: const <Object?>[],
          maxHp: const <Object?>[],
          enabled: _context.combinedFleetType != CombinedFleetType.none,
        ),
        phaseLabel: landBaseRaid == null ? '航行中' : '基地空袭',
        displayStage: BattleDisplayStage.navigation,
        landBaseRaid: landBaseRaid,
        enemyPreviewShips: _officialEnemyPreviewShips(map, state),
        enemyPreviewCombined: _officialEnemyPreviewCombined(map),
        rewardItems: _mapRewardItems(map),
        resourceChanges: _mapResourceChanges(map),
        lastFormation: formationMemory?.formationFor(
          mapAreaId: _context.mapAreaId,
          mapInfoNo: _context.mapInfoNo,
          node: _context.node,
        ),
      );
      _archiveSession();
      _predictionEngine = null;
      _fleetBattleDisplayPending = false;
      _session = BattleSession(
        id: '${event.sequence}:${_context.mapAreaId}-${_context.mapInfoNo}-${_context.node}',
        context: _context,
        startedAt: event.capturedAt,
        friendMain: _current!.friendMain,
        friendEscort: _current!.friendEscort,
      );
      return;
    }
    if (_battlePaths.contains(event.path)) {
      _ensureSession(event);
      _session!.appendPacket(
        path: event.path,
        sequence: event.sequence,
        capturedAt: event.capturedAt,
        data: map,
      );
      await _applyBattlePhase(map, event, generation);
      if (generation != _generation || _disposed) return;
      final battle = _current!;
      _session!.updateFleets(
        friendMain: battle.friendMain,
        friendEscort: battle.friendEscort,
        enemyMain: battle.enemyMain,
        enemyEscort: battle.enemyEscort,
      );
      return;
    }
    if (_resultPaths.contains(event.path)) {
      if (_session != null) {
        _session!.appendPacket(
          path: event.path,
          sequence: event.sequence,
          capturedAt: event.capturedAt,
          data: map,
        );
      }
      _applyResult(map, event);
      return;
    }
  }

  void _clearSortieMapProgress() {
    _sortieMapProgress = null;
    _sortieMapResetCombat = gameState().combatState;
    // State consumers may still expose the preceding sortie when a reset is
    // delivered. Do not revive that context through the partial fallback.
    _sortieMapFallbackAllowed = false;
  }

  void _recoverPartialSortieMapProgress() {
    if (_sortieMapFallbackAllowed || _context.practice) return;
    final state = gameState();
    final combat = state.combatState;
    final resetCombat = _sortieMapResetCombat;
    final scope = accountSession?.current;
    if (!combat.isActive ||
        combat.mapArea <= 0 ||
        combat.mapInfo <= 0 ||
        combat.currentNode <= 0 ||
        (scope != null && state.memberId != scope.memberId) ||
        resetCombat == null) {
      return;
    }
    // Battle reducers can replace a combat object without changing its map
    // position. Only a different active position establishes fresh context.
    if (resetCombat.isActive &&
        resetCombat.mapArea == combat.mapArea &&
        resetCombat.mapInfo == combat.mapInfo &&
        resetCombat.currentNode == combat.currentNode) {
      return;
    }
    _sortieMapProgress = SortieMapProgress(
      mapAreaId: combat.mapArea,
      mapInfoNo: combat.mapInfo,
      routeIds: [combat.currentNode],
      isPartial: true,
    );
    _sortieMapFallbackAllowed = true;
  }

  void _updateSortieMapProgress(
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final isStart = event.path == '/kcsapi/api_req_map/start';
    final previous = isStart ? null : _sortieMapProgress;
    if (isStart) _clearSortieMapProgress();
    final (area, info) = _mapIdentityFromNavigation(data, event);
    if (area <= 0 || info <= 0) return;

    final sameMap =
        previous != null &&
        previous.mapAreaId == area &&
        previous.mapInfoNo == info;
    final routes = <int>[if (sameMap) ...previous.routeIds];
    // Zero is a valid departure route on start, but api_no == 0 on next
    // signals the end of movement rather than another traversed edge.
    if (isStart && data.containsKey('api_from_no')) {
      final from = int.tryParse('${data['api_from_no']}');
      if (from != null && from >= 0) routes.add(from);
    }
    final node = _int(data['api_no']);
    if (node > 0) routes.add(node);
    if (routes.isEmpty) {
      _clearSortieMapProgress();
      return;
    }

    final contextBoss =
        !isStart &&
            previous == null &&
            _context.mapAreaId == area &&
            _context.mapInfoNo == info
        ? _context.bossNode
        : 0;
    final boss = _positive(
      data['api_bosscell_no'],
      sameMap ? (previous.bossRouteId ?? 0) : contextBoss,
    );
    _sortieMapProgress = SortieMapProgress(
      mapAreaId: area,
      mapInfoNo: info,
      routeIds: routes,
      bossRouteId: boss > 0 ? boss : null,
      isPartial: !isStart && (!sameMap || previous.isPartial),
    );
    _sortieMapFallbackAllowed = true;
  }

  (int, int) _mapIdentityFromNavigation(
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    var area = _positive(
      data['api_maparea_id'],
      _int(event.requestParams['api_maparea_id']),
    );
    var info = _positive(
      data['api_mapinfo_no'],
      _int(event.requestParams['api_mapinfo_no']),
    );
    final combat = gameState().combatState;
    if (event.path != '/kcsapi/api_req_map/start' &&
        (area <= 0 || info <= 0) &&
        combat.isActive &&
        (area <= 0 || area == combat.mapArea) &&
        (info <= 0 || info == combat.mapInfo)) {
      area = _positive(area, combat.mapArea);
      info = _positive(info, combat.mapInfo);
    }
    if (event.path != '/kcsapi/api_req_map/start' && (area <= 0 || info <= 0)) {
      final previousArea = _sortieMapProgress?.mapAreaId ?? _context.mapAreaId;
      final previousInfo = _sortieMapProgress?.mapInfoNo ?? _context.mapInfoNo;
      if ((area <= 0 || area == previousArea) &&
          (info <= 0 || info == previousInfo)) {
        area = _positive(area, previousArea);
        info = _positive(info, previousInfo);
      }
    }
    return (area, info);
  }

  BattleContext _contextFromMap(
    Map<String, Object?> data,
    CapturedApiEvent event,
  ) {
    final state = gameState();
    final isStart = event.path == '/kcsapi/api_req_map/start';
    final (mapAreaId, mapInfoNo) = _mapIdentityFromNavigation(data, event);
    final samePreviousMap =
        !isStart &&
        mapAreaId == _context.mapAreaId &&
        mapInfoNo == _context.mapInfoNo;
    final node = _positive(data['api_no'], isStart ? 0 : _context.node);
    final sortieFleetId = state.combatState.sortieFleetId;
    final deckId = _positive(
      event.requestParams['api_deck_id'],
      _context.deckId > 0
          ? _context.deckId
          : (sortieFleetId > 0 ? sortieFleetId : 1),
    );
    final previewEnemyIds = <int>[
      for (final deckValue in _list(data['api_e_deck_info']))
        if (_optionalMap(deckValue) case final deck?)
          for (final shipValue in _list(deck['api_ship_ids']))
            if (_int(shipValue) > 0) _int(shipValue),
    ];
    return BattleContext(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      node: node,
      bossNode: _positive(
        data['api_bosscell_no'],
        samePreviousMap ? _context.bossNode : 0,
      ),
      deckId: deckId,
      combinedFleetType: _combinedFleetTypeForDeck(state, deckId),
      eventId: _int(data['api_event_id'] ?? _context.eventId),
      eventKind: _int(data['api_event_kind'] ?? _context.eventKind),
      nodeDisplayLabel: nodeLabelResolver.resolve(
        mapAreaId: mapAreaId,
        mapInfoNo: mapInfoNo,
        internalNodeId: node,
      ),
      nodeTypeOverride: _isAllSubmarineEnemyIds(state, previewEnemyIds)
          ? '潜艇战'
          : null,
    );
  }

  LandBaseRaidResult? _landBaseRaid(
    Map<String, Object?> data,
    GameState state,
  ) {
    final raids = parseLandBaseRaids(data);
    if (raids.isEmpty) return null;
    final areaId = _positive(data['api_maparea_id'], _context.mapAreaId);
    // Each response carries absolute starting HP; the last raid wins, as in POI.
    final latest = <int, LandBaseRaidHp>{};
    for (final raid in raids) {
      for (final base in raid.bases) {
        latest[base.baseId] = base;
      }
    }
    return LandBaseRaidResult(
      areaId: areaId,
      bases: List.unmodifiable([
        for (final hp in latest.values)
          LandBaseRaidSnapshot(
            baseId: hp.baseId,
            name:
                state.landBases
                    .where(
                      (base) =>
                          base.areaId == areaId && base.baseId == hp.baseId,
                    )
                    .map((base) => base.name)
                    .where((name) => name.isNotEmpty)
                    .firstOrNull ??
                '第 ${hp.baseId} 基地航空队',
            currentHp: hp.currentHp,
            maxHp: hp.maxHp,
            damage: hp.damage,
          ),
      ]),
      airSuperiority: kAirSuperiorityLabels[raids.last.airSuperiority] ?? '未知',
    );
  }

  List<EnemyPreviewShip> _officialEnemyPreviewShips(
    Map<String, Object?> data,
    GameState state,
  ) {
    final previews = <Map<String, Object?>>[];
    for (final value in _list(data['api_e_deck_info'])) {
      final candidate = _optionalMap(value);
      if (candidate != null) previews.add(candidate);
    }
    if (previews.isEmpty) return const <EnemyPreviewShip>[];

    List<EnemyPreviewShip> shipsOf(
      Map<String, Object?> preview,
      BattleFleetRole fleetRole,
    ) {
      final ships = <EnemyPreviewShip>[];
      for (final value in _list(preview['api_ship_ids'])) {
        final masterId = _int(value);
        if (masterId <= 0) continue;
        final name = state.masterShips[masterId]?.name.trim() ?? '';
        if (name.isEmpty) continue;
        ships.add(
          EnemyPreviewShip(
            masterId: masterId,
            name: name,
            fleetRole: fleetRole,
          ),
        );
        if (ships.length == 3) break;
      }
      return ships;
    }

    final ships = shipsOf(
      previews.last,
      previews.length > 1 ? BattleFleetRole.escort : BattleFleetRole.main,
    );
    if (previews.length > 1) {
      ships.addAll(shipsOf(previews.first, BattleFleetRole.main));
    }
    return List<EnemyPreviewShip>.unmodifiable(ships);
  }

  bool _officialEnemyPreviewCombined(Map<String, Object?> data) {
    var deckCount = 0;
    for (final value in _list(data['api_e_deck_info'])) {
      if (_optionalMap(value) != null) deckCount++;
    }
    return deckCount > 1;
  }

  Future<void> _applyBattlePhase(
    Map<String, Object?> data,
    CapturedApiEvent event,
    int generation,
  ) async {
    final state = gameState();
    final practice =
        _context.practice || event.path.startsWith('/kcsapi/api_req_practice/');
    final deckId = _positive(data['api_deck_id'], _context.deckId);
    final combinedFleetType = practice
        ? CombinedFleetType.none
        : _combinedFleetTypeForDeck(state, deckId);
    if (practice) {
      _context = BattleContext(
        deckId: deckId,
        practice: true,
        combinedFleetType: CombinedFleetType.none,
      );
    } else {
      _context = _context.copyWith(
        deckId: deckId,
        practice: false,
        combinedFleetType: combinedFleetType,
      );
    }

    final previous = _current;
    final previousBattle = previous?.displayStage == BattleDisplayStage.battle
        ? previous
        : null;
    final friendMain = _friendFleet(
      state,
      deckId,
      BattleFleetRole.main,
      nowHp: _fleetArray(data['api_f_nowhps']),
      maxHp: _fleetArray(data['api_f_maxhps']),
      previous: previousBattle?.friendMain,
    );
    final combined = combinedFleetType != CombinedFleetType.none;
    final friendEscort = _friendFleet(
      state,
      2,
      BattleFleetRole.escort,
      nowHp: _fleetArray(data['api_f_nowhps_combined']),
      maxHp: _fleetArray(data['api_f_maxhps_combined']),
      previous: previousBattle?.friendEscort,
      enabled: combined,
    );
    final enemyMain = _enemyFleet(
      state,
      BattleFleetRole.main,
      ids: _fleetArray(data['api_ship_ke']),
      levels: _fleetArray(data['api_ship_lv']),
      parameters: _fleetArray(data['api_eParam']),
      slots: _fleetArray(data['api_eSlot']),
      nowHp: _fleetArray(data['api_e_nowhps']),
      maxHp: _fleetArray(data['api_e_maxhps']),
      previous: previousBattle?.enemyMain,
    );
    final enemyEscort = _enemyFleet(
      state,
      BattleFleetRole.escort,
      ids: _fleetArray(data['api_ship_ke_combined']),
      levels: _fleetArray(data['api_ship_lv_combined']),
      parameters: _fleetArray(data['api_eParam_combined']),
      slots: _fleetArray(data['api_eSlot_combined']),
      nowHp: _fleetArray(data['api_e_nowhps_combined']),
      maxHp: _fleetArray(data['api_e_maxhps_combined']),
      previous: previousBattle?.enemyEscort,
    );

    if (_predictionEngine == null) {
      if (!practice) {
        if (!_sortieDamageControls.isActive) {
          _sortieDamageControls.beginSortie(
            trusted: false,
            reason: 'missing sortie node context',
          );
        }
        _predictionEngine = _createPredictionEngine(
          friendMain: _sortieDamageControls.seedFleet(friendMain),
          friendEscort: _sortieDamageControls.seedFleet(friendEscort),
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
        );
      } else {
        _predictionEngine = _createPredictionEngine(
          friendMain: friendMain,
          friendEscort: friendEscort,
          enemyMain: enemyMain,
          enemyEscort: enemyEscort,
        );
      }
    }
    final appendResult = await _predictionExecutor.append(
      engine: _predictionEngine!,
      path: event.path,
      data: data,
    );
    if (_disposed || generation != _generation) return;
    _predictionEngine = appendResult.engine;
    final parsed = appendResult.prediction;
    if (!practice) {
      if (parsed.issues.isEmpty && _sortieDamageControls.isTrusted) {
        _sortieDamageControls.synchronize(
          ships: <BattleShipSnapshot>[
            ...parsed.friendMain,
            ...parsed.friendEscort,
          ],
          equipmentByShipId: _damageControlEquipmentByShipId(
            state,
            <BattleShipSnapshot>[...parsed.friendMain, ...parsed.friendEscort],
          ),
        );
      } else if (parsed.issues.isNotEmpty) {
        _sortieDamageControls.markUntrusted(
          'incomplete battle parse; damage-control consumption is unknown',
        );
      }
      if (!_sortieDamageControls.isTrusted) {
        _session?.markUnconfirmed(
          stage: 'damage-control-ledger',
          message:
              _sortieDamageControls.untrustedReason ??
              'cross-node damage-control state is unknown',
        );
      }
    }
    final hasUntrustedPoiLedger = _hasUntrustedPoiLedger;
    final parsedFriendMain = [
      for (final ship in _mergeEscapedFlags(parsed.friendMain, friendMain))
        ship.withLatestFriendlyProficiency(state),
    ];
    final parsedFriendEscort = [
      for (final ship in _mergeEscapedFlags(parsed.friendEscort, friendEscort))
        ship.withLatestFriendlyProficiency(state),
    ];
    if (!practice && !hasUntrustedPoiLedger) {
      final settings = battleStatusEffectSettings?.call();
      final severity = detectFriendlyDamageAlert(
        before: <BattleShipSnapshot>[...friendMain, ...friendEscort],
        after: <BattleShipSnapshot>[...parsedFriendMain, ...parsedFriendEscort],
        includeModerate: settings?.vibrates(ShipDamageLevel.moderate) == true,
        includeHeavy:
            !warningSession.isMuted &&
            settings?.vibrates(ShipDamageLevel.heavy) == true,
      );
      if (severity != null && damageAlertPort != null) {
        unawaited(
          damageAlertPort!.alert(severity).catchError((Object error) {
            debugPrint('战斗受损震动提醒失败: $error');
          }),
        );
      }
    }
    for (final issue in parsed.issues) {
      _session?.markUnconfirmed(stage: issue.stage, message: issue.message);
    }
    final formation = _list(data['api_formation']);
    final parsedEnemyName = parseEnemyFleetName(data['api_formation']);
    final enemyFleetName = parsedEnemyName.isNotEmpty
        ? parsedEnemyName
        : previous?.enemyFleetName ?? '';
    final seiku = parseDispSeiku(data);
    final airSuperiority = seiku >= 0 && seiku <= 4
        ? kAirSuperiorityLabels[seiku]
        : previousBattle?.airSuperiority;
    final rank = (_session?.isConfirmed ?? parsed.issues.isEmpty)
        ? parsed.rank
        : BattleRank.unknown;
    _context = _context.copyWith(
      nodeTypeOverride:
          _isAllSubmarineEnemyIds(state, <int>[
            for (final ship in <BattleShipSnapshot>[
              ...parsed.enemyMain,
              ...parsed.enemyEscort,
            ])
              ship.masterId,
          ])
          ? '潜艇战'
          : null,
    );

    _current = LiveBattle(
      context: _context,
      friendMain: parsedFriendMain,
      friendEscort: parsedFriendEscort,
      enemyMain: parsed.enemyMain,
      enemyEscort: parsed.enemyEscort,
      rank: rank,
      displayStage: BattleDisplayStage.battle,
      phaseLabel: _phaseLabel(event.path),
      friendFormation: _atInt(formation, 0),
      enemyFormation: _atInt(formation, 1),
      engagement: _atInt(formation, 2),
      enemyFleetName: enemyFleetName,
      airSuperiority: airSuperiority ?? '未知',
      mvpPositions: parsed.mvpPositions.isNotEmpty
          ? parsed.mvpPositions
          : _predictedMvpPositions(parsed.friendMain, parsed.friendEscort),
    );
    _lastBattleCapturedAt = event.capturedAt;
    if (!practice) {
      if (onFleetBattleDisplayStarted case final started?) {
        if ((previous == null ||
                previous.displayStage == BattleDisplayStage.navigation) &&
            _matchesFleetBattleDisplayContext(_context, state.combatState)) {
          final shipIds = <int>[
            for (final ship in _current!.friendShips) ?ship.ownedShipId,
          ];
          if (shipIds.isNotEmpty) {
            _fleetBattleDisplayPending = true;
            started(shipIds);
          }
        }
      }
      _emitFriendlyHp(_current!, event.capturedAt);
      if (!hasUntrustedPoiLedger) {
        _emitDamageControlConsumption(event.capturedAt);
      }
    }
  }

  bool _matchesFleetBattleDisplayContext(
    BattleContext context,
    CombatState combat,
  ) =>
      !context.practice &&
      combat.isActive &&
      context.mapAreaId > 0 &&
      context.mapInfoNo > 0 &&
      context.node > 0 &&
      context.mapAreaId == combat.mapArea &&
      context.mapInfoNo == combat.mapInfo &&
      context.node == combat.currentNode &&
      context.deckId == combat.sortieFleetId;

  void _emitFriendlyHp(LiveBattle battle, DateTime capturedAt) {
    final hpByShipId = <int, int>{};
    final untrusted = _hasUntrustedPoiLedger;
    final ownedShips = untrusted ? gameState().ships : null;
    for (final ship in battle.friendShips) {
      final shipId = ship.ownedShipId;
      if (shipId == null) continue;
      if (!untrusted) {
        hpByShipId[shipId] = ship.currentHp;
        continue;
      }
      final ownedShip = ownedShips![shipId];
      if (ownedShip == null || ownedShip.currentHp <= 0) continue;
      final predictedHp = ship.usedDamageControlItemIds.isEmpty
          ? ship.currentHp
          : 1;
      final conservativeHp = predictedHp.clamp(1, ownedShip.currentHp).toInt();
      if (conservativeHp < ownedShip.currentHp) {
        hpByShipId[shipId] = conservativeHp;
      }
    }
    if (untrusted && hpByShipId.isEmpty) return;
    _friendlyHpUpdater?.call(
      untrusted
          ? ConservativeBattleHpUpdate(hpByShipId)
          : Map<int, int>.unmodifiable(hpByShipId),
      capturedAt,
    );
  }

  void _emitDamageControlConsumption(DateTime capturedAt) {
    final consumptions = _sortieDamageControls.consumedByShipId;
    if (consumptions.isEmpty) return;
    _damageControlUpdater?.call(consumptions, capturedAt);
  }

  bool get _hasUntrustedPoiLedger =>
      _sortieDamageControls.isActive && !_sortieDamageControls.isTrusted;

  BattlePredictionEngine _createPredictionEngine({
    required List<BattleShipSnapshot> friendMain,
    required List<BattleShipSnapshot> friendEscort,
    required List<BattleShipSnapshot> enemyMain,
    required List<BattleShipSnapshot> enemyEscort,
  }) {
    final factory = poiEngineFactory;
    if (factory != null) {
      return factory(
        friendMain: friendMain,
        friendEscort: friendEscort,
        enemyMain: enemyMain,
        enemyEscort: enemyEscort,
      );
    }
    return PoiBattlePredictionEngine(
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
      fleetType: _context.combinedFleetType.apiValue,
    );
  }

  void _applyResult(Map<String, Object?> data, CapturedApiEvent event) {
    if (_current == null ||
        _current!.displayStage == BattleDisplayStage.navigation) {
      _lastError = '收到结算数据时没有可匹配的战斗会话';
      return;
    }
    final enemyInfo = _optionalMap(data['api_enemy_info']);
    final getShip = _optionalMap(data['api_get_ship']);
    final getItem = _optionalMap(data['api_get_useitem']);
    final extraMapUseItemId = _positive(data['api_get_exmap_useitem_id'], 0);
    final eventRewards = _eventRewards(data['api_get_eventitem']);
    final eventShipIds = eventRewards
        .where((reward) => reward.$1 == 2)
        .map((reward) => reward.$2)
        .toList(growable: false);
    final normalShipId = _positive(getShip?['api_ship_id'], 0);
    final dropShipMasterIds = <int>[
      if (normalShipId > 0) normalShipId,
      ...eventShipIds,
    ];
    final rewardItems = <BattleRewardItem>[
      if (_positive(getItem?['api_useitem_id'], 0) case final id when id > 0)
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: id,
          count: 1,
          name: expeditionRewardName(id, _string(getItem?['api_useitem_name'])),
        ),
      if (extraMapUseItemId > 0)
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: extraMapUseItemId,
          count: 1,
          name: expeditionRewardName(extraMapUseItemId),
        ),
      for (final reward in eventRewards)
        if (reward.$1 != 2) _eventRewardItem(reward, gameState()),
    ];
    var rank = BattleRank.parse(data['api_win_rank']);
    if (rank == BattleRank.s) {
      final friendShips = _current!.friendShips;
      final initialHp = friendShips.fold<int>(
        0,
        (sum, ship) => sum + ship.initialHp,
      );
      final currentHp = friendShips.fold<int>(
        0,
        (sum, ship) => sum + ship.currentHp,
      );
      if (friendShips.isNotEmpty && currentHp >= initialHp) {
        rank = BattleRank.ss;
      }
    }
    final mainMvp = _int(data['api_mvp']) - 1;
    final escortMvp = _int(data['api_mvp_combined']) - 1;
    final confirmed = (_current ?? LiveBattle(context: _context)).copyWith(
      rank: rank,
      status: LiveBattleStatus.confirmed,
      displayStage: BattleDisplayStage.result,
      enemyFleetName: _string(enemyInfo?['api_deck_name']),
      mvpPositions: <int>[
        if (mainMvp >= 0) mainMvp,
        if (escortMvp >= 0) escortMvp + 6,
      ],
      dropShipMasterId: dropShipMasterIds.firstOrNull,
      dropShipMasterIds: dropShipMasterIds,
      dropItemId: _positive(getItem?['api_useitem_id'], 0),
      dropItemName: _string(getItem?['api_useitem_name']),
      rewardItems: rewardItems,
    );
    _current = confirmed;
    if (!confirmed.context.practice && formationMemory != null) {
      unawaited(
        formationMemory!
            .remember(
              mapAreaId: confirmed.context.mapAreaId,
              mapInfoNo: confirmed.context.mapInfoNo,
              node: confirmed.context.node,
              formation: confirmed.friendFormation,
            )
            .catchError((Object error) {
              debugPrint('Failed to persist node formation memory: $error');
            }),
      );
    }
    final state = gameState();
    BattleDetailSnapshot? detail;
    final session = _session;
    if (session != null && session.packets.isNotEmpty) {
      try {
        detail = const BattleDetailReplayBuilder().build(
          session: session,
          battle: confirmed,
          completedAt: event.capturedAt,
          gameState: state,
        );
      } catch (error) {
        debugPrint('战斗详情生成失败: $error');
      }
    }
    final record = BattleRecord(
      battle: confirmed,
      completedAt: event.capturedAt,
      detail: detail,
    );
    _records.insert(0, record);
    if (_records.length > maxRecords) {
      _records.removeRange(maxRecords, _records.length);
    }
    if (_session != null) {
      _session!.completed = true;
      _archiveSession();
    }
    if (!confirmed.context.practice && !_hasUntrustedPoiLedger) {
      _emitDamageControlConsumption(event.capturedAt);
    }
    if (_fleetBattleDisplayPending &&
        rank != BattleRank.unknown &&
        event.path != '/kcsapi/api_req_practice/battle_result' &&
        _matchesFleetBattleDisplayContext(
          confirmed.context,
          state.combatState,
        )) {
      final resultDeckId = _positive(
        data['api_deck_id'],
        _positive(event.requestParams['api_deck_id'], confirmed.context.deckId),
      );
      if (resultDeckId == confirmed.context.deckId) {
        _fleetBattleDisplayPending = false;
        onFleetBattleDisplaySettled?.call();
      }
    }

    // Log to persistent database
    if (_memberId <= 0) return;
    final isPractice =
        confirmed.context.practice || confirmed.context.mapAreaId == 0;
    LogbookDatabase.forAccount(_memberId)
        .insertBattleRecord(
          record,
          mapName: isPractice
              ? '演习'
              : (state.mapName(
                      confirmed.context.mapAreaId,
                      confirmed.context.mapInfoNo,
                    ) ??
                    ''),
          mapDifficulty: isPractice
              ? 0
              : state.mapDifficulty(
                  confirmed.context.mapAreaId,
                  confirmed.context.mapInfoNo,
                ),
          nodeLabel: isPractice
              ? '-'
              : (confirmed.context.nodeDisplayLabel?.trim() ?? ''),
        )
        .catchError((Object error) {
          debugPrint('战斗记录写入失败: $error');
          return -1;
        });
  }

  void _applyRetreat() {
    final current = _current;
    if (current == null) return;
    final state = gameState();
    final escaped = state.combatState.escapedShipIds;
    final updated = _withRetreatState(current, escaped);
    if (identical(updated, current)) return;
    _current = updated;
    if (_records.isNotEmpty) {
      final firstBattle = _records[0].battle;
      final match =
          identical(firstBattle, current) ||
          (firstBattle.context.mapAreaId == current.context.mapAreaId &&
              firstBattle.context.mapInfoNo == current.context.mapInfoNo &&
              firstBattle.context.node == current.context.node);
      if (match) {
        _records[0] = BattleRecord(
          battle: _current!,
          completedAt: _records[0].completedAt,
          detail: _records[0].detail,
        );
      }
    }
  }

  LiveBattle _withRetreatState(LiveBattle battle, Set<int> escaped) {
    List<BattleShipSnapshot> fleet(List<BattleShipSnapshot> ships) {
      var changed = false;
      final result = <BattleShipSnapshot>[];
      for (final ship in ships) {
        final isEscaped = escaped.contains(ship.ownedShipId);
        if (ship.ownedShipId != null && ship.isEscaped != isEscaped) {
          changed = true;
          result.add(ship.copyWith(isEscaped: isEscaped));
        } else {
          result.add(ship);
        }
      }
      return changed ? List.unmodifiable(result) : ships;
    }

    final main = fleet(battle.friendMain);
    final escort = fleet(battle.friendEscort);
    return identical(main, battle.friendMain) &&
            identical(escort, battle.friendEscort)
        ? battle
        : battle.copyWith(friendMain: main, friendEscort: escort);
  }

  void _ensureSession(CapturedApiEvent event) {
    _session ??= BattleSession(
      id: '${event.sequence}:${_context.mapAreaId}-${_context.mapInfoNo}-${_context.node}',
      context: _context,
      startedAt: event.capturedAt,
    );
  }

  void _archiveSession() {
    final session = _session;
    if (session == null ||
        session.packets.isEmpty ||
        _recentSessions.contains(session)) {
      return;
    }
    _recentSessions.insert(0, session);
    if (_recentSessions.length > 10) {
      _recentSessions.removeRange(10, _recentSessions.length);
    }
  }

  List<BattleShipSnapshot> _mergeEscapedFlags(
    List<BattleShipSnapshot> parsed,
    List<BattleShipSnapshot> detected,
  ) {
    final escapedByPosition = <int, bool>{
      for (final ship in detected)
        if (ship.isEscaped) ship.position: true,
    };
    if (escapedByPosition.isEmpty) return parsed;
    var changed = false;
    final result = <BattleShipSnapshot>[];
    for (final ship in parsed) {
      if (escapedByPosition[ship.position] == true && !ship.isEscaped) {
        changed = true;
        result.add(ship.copyWith(isEscaped: true));
      } else {
        result.add(ship);
      }
    }
    return changed ? List.unmodifiable(result) : parsed;
  }

  Map<int, List<DamageControlEquipmentRef>> _damageControlEquipmentByShipId(
    GameState state,
    Iterable<BattleShipSnapshot> ships,
  ) {
    final result = <int, List<DamageControlEquipmentRef>>{};
    for (final ship in ships) {
      final shipId = ship.ownedShipId;
      final ownedShip = shipId == null ? null : state.ships[shipId];
      if (shipId == null || ownedShip == null) continue;
      final alreadyConsumed = _sortieDamageControls.consumptionsForShip(shipId);
      final currentEquipment = <DamageControlEquipmentRef>[
        for (final equipment in state.equipmentForShip(ownedShip))
          if (equipment.owned.masterSlotItemId == 42 ||
              equipment.owned.masterSlotItemId == 43)
            DamageControlEquipmentRef(
              instanceId: equipment.owned.instanceId,
              masterId: equipment.owned.masterSlotItemId,
            ),
      ];
      result[shipId] = <DamageControlEquipmentRef>[
        ...alreadyConsumed,
        for (final item in currentEquipment)
          if (!alreadyConsumed.any(
            (consumed) => consumed.instanceId == item.instanceId,
          ))
            item,
      ];
    }
    return result;
  }

  List<BattleShipSnapshot> _friendFleet(
    GameState state,
    int deckId,
    BattleFleetRole role, {
    required List<Object?> nowHp,
    required List<Object?> maxHp,
    List<BattleShipSnapshot>? previous,
    bool enabled = true,
  }) {
    if (!enabled) {
      return const <BattleShipSnapshot>[];
    }
    final escapedIds = state.combatState.escapedShipIds;
    // Match POI: only a confirmed escape is retreat state. Negative HP slots
    // mean that the ship did not participate and must not create that state.
    if (previous != null) {
      return <BattleShipSnapshot>[
        for (var index = 0; index < previous.length; index++)
          () {
            final ship = previous[index];
            final isEscaped =
                ship.ownedShipId != null &&
                escapedIds.contains(ship.ownedShipId!);
            return isEscaped && !ship.isEscaped
                ? ship.copyWith(isEscaped: true)
                : ship;
          }(),
      ];
    }
    final ownedShips = state.shipsForFleet(deckId);
    final fleetShipIds =
        state.fleets
            .where((fleet) => fleet.id == deckId)
            .firstOrNull
            ?.shipIds ??
        const <int>[];
    if (ownedShips.isEmpty && previous != null) {
      return _withHp(previous, nowHp, maxHp);
    }
    return <BattleShipSnapshot>[
      for (var index = 0; index < ownedShips.length; index++)
        () {
          final position = fleetShipIds.indexOf(ownedShips[index].id);
          final isEscaped = escapedIds.contains(ownedShips[index].id);
          final equipped = state.equipmentForShip(ownedShips[index]);
          final consumed = _sortieDamageControls.consumptionsForShip(
            ownedShips[index].id,
          );
          return BattleShipSnapshot(
            masterId: ownedShips[index].masterId,
            ownedShipId: ownedShips[index].id,
            name:
                state.masterForShip(ownedShips[index])?.name ??
                '舰娘 ${ownedShips[index].masterId}',
            side: BattleSide.friend,
            fleetRole: role,
            position: position,
            initialHp: _atNonNegative(
              nowHp,
              position,
              ownedShips[index].currentHp,
            ),
            maxHp: _atPositive(maxHp, position, ownedShips[index].maxHp),
            currentHp: _atNonNegative(
              nowHp,
              position,
              ownedShips[index].currentHp,
            ),
            damageDealt: index < (previous?.length ?? 0)
                ? previous![index].damageDealt
                : 0,
            damageReceived: index < (previous?.length ?? 0)
                ? previous![index].damageReceived
                : 0,
            condition: ownedShips[index].condition,
            details: BattleShipDetails.friendly(ownedShips[index], state),
            equipmentMasterIds: <int>[
              for (final item in consumed) item.masterId,
              for (final equipment in equipped)
                if (!consumed.any(
                  (item) => item.instanceId == equipment.owned.instanceId,
                ))
                  equipment.owned.masterSlotItemId,
            ],
            isEscaped: isEscaped,
          );
        }(),
    ];
  }

  CombinedFleetType _combinedFleetTypeForDeck(GameState state, int deckId) {
    // A player can keep fleets 1 and 2 combined while separately sending the
    // seven-ship striking force in fleet 3. Only deck 1 represents the friendly
    // combined fleet; treating every sortie as combined also makes position 6
    // resolve to escort ship 1 instead of striking-force ship 7.
    return deckId == 1 ? state.combinedFleetType : CombinedFleetType.none;
  }

  bool _isAllSubmarineEnemyIds(GameState state, Iterable<int> masterIds) {
    final effectiveIds = masterIds.where((id) => id > 0).toList();
    return effectiveIds.isNotEmpty &&
        effectiveIds.every((masterId) {
          final shipTypeId = state.masterShips[masterId]?.shipTypeId;
          return shipTypeId == 13 || shipTypeId == 14;
        });
  }

  List<BattleShipSnapshot> _enemyFleet(
    GameState state,
    BattleFleetRole role, {
    required List<Object?> ids,
    required List<Object?> levels,
    required List<Object?> parameters,
    required List<Object?> slots,
    required List<Object?> nowHp,
    required List<Object?> maxHp,
    List<BattleShipSnapshot>? previous,
  }) {
    if (previous != null) {
      return previous;
    }
    final result = <BattleShipSnapshot>[];
    for (var index = 0; index < ids.length; index++) {
      final masterId = _int(ids[index]);
      if (masterId <= 0) {
        continue;
      }
      final hp = _atNonNegative(nowHp, index, _atPositive(maxHp, index, 1));
      final hpUnknown =
          index >= nowHp.length ||
          index >= maxHp.length ||
          nowHp[index] is! num ||
          maxHp[index] is! num;
      result.add(
        BattleShipSnapshot(
          masterId: masterId,
          name: state.masterShips[masterId]?.name ?? '敌舰 $masterId',
          side: BattleSide.enemy,
          fleetRole: role,
          position: index,
          initialHp: hp,
          maxHp: _atPositive(maxHp, index, hp),
          currentHp: hp,
          hpUnknown: hpUnknown,
          details: BattleShipDetails.enemy(
            level: index < levels.length ? levels[index] : null,
            reading: state.masterShips[masterId]?.reading,
            parameters: index < parameters.length ? parameters[index] : null,
            slots: index < slots.length ? slots[index] : null,
            state: state,
          ),
          damageReceived: index < (previous?.length ?? 0)
              ? previous![index].damageReceived
              : 0,
        ),
      );
    }
    return result;
  }

  List<BattleShipSnapshot> _withHp(
    List<BattleShipSnapshot> previous,
    List<Object?> nowHp,
    List<Object?> maxHp,
  ) {
    return <BattleShipSnapshot>[
      for (var index = 0; index < previous.length; index++)
        previous[index].copyWith(
          currentHp: _atPositive(nowHp, index, previous[index].currentHp),
          maxHp: _atPositive(maxHp, index, previous[index].maxHp),
        ),
    ];
  }

  String _phaseLabel(String path) {
    if (path.contains('midnight') || path.contains('night_to_day')) {
      return '夜战';
    }
    if (path.contains('airbattle') || path.contains('ld_')) {
      return '航空战';
    }
    return '昼战';
  }

  List<BattleResourceChange> _mapResourceChanges(Map<String, Object?> data) {
    final changes = <BattleResourceChange>[];
    for (final item in _mapItemEntries(data)) {
      if (_int(item['api_usemst']) != 4) continue;
      final resourceId = _int(item['api_id']);
      final type = GameResourceType.values
          .where((candidate) => candidate.apiId == resourceId)
          .firstOrNull;
      final amount = _positive(item['api_getcount'], 0);
      if (type != null && amount > 0) {
        changes.add(BattleResourceChange(type: type, amount: amount));
      }
    }
    final happening = _optionalMap(data['api_happening']);
    if (happening != null) {
      final resourceId = _positive(
        happening['api_icon_id'],
        _int(happening['api_mst_id']),
      );
      final type = GameResourceType.values
          .where((candidate) => candidate.apiId == resourceId)
          .firstOrNull;
      final amount = _positive(happening['api_count'], 0);
      if (type != null && amount > 0) {
        changes.add(
          BattleResourceChange(
            type: type,
            amount: -amount,
            radarReduced: _int(happening['api_dentan']) != 0,
          ),
        );
      }
    }
    return changes;
  }

  List<BattleRewardItem> _mapRewardItems(Map<String, Object?> data) {
    final rewards = <BattleRewardItem>[];
    for (final item in _mapItemEntries(data)) {
      if (_int(item['api_usemst']) == 4) continue;
      final id = _positive(item['api_id'], 0);
      if (id <= 0) continue;
      rewards.add(
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: id,
          count: _positive(item['api_getcount'], 1),
          name: expeditionRewardName(id, _string(item['api_name'])),
        ),
      );
    }
    return rewards;
  }

  List<Map<String, Object?>> _mapItemEntries(Map<String, Object?> data) => [
    ..._objectOrArrayMaps(data['api_itemget']),
    ..._objectOrArrayMaps(data['api_itemget_eo_comment']),
  ];

  List<(int, int, int)> _eventRewards(Object? value) => [
    for (final item in _objectOrArrayMaps(value))
      if (_positive(item['api_id'], 0) case final id when id > 0)
        (_positive(item['api_type'], 1), id, _positive(item['api_value'], 1)),
  ];

  BattleRewardItem _eventRewardItem((int, int, int) reward, GameState state) {
    final (type, id, count) = reward;
    return switch (type) {
      3 => BattleRewardItem(
        kind: BattleRewardKind.equipment,
        id: id,
        count: count,
        name: state.masterSlotItems[id]?.name ?? 'Equipment $id',
      ),
      5 => BattleRewardItem(
        kind: BattleRewardKind.furniture,
        id: id,
        count: count,
        name: 'Furniture $id',
      ),
      _ => BattleRewardItem(
        kind: BattleRewardKind.item,
        id: id,
        count: count,
        name: expeditionRewardName(id),
      ),
    };
  }

  List<Map<String, Object?>> _objectOrArrayMaps(Object? value) {
    if (value is Map) return <Map<String, Object?>>[_map(value)];
    return <Map<String, Object?>>[
      for (final item in _list(value)) ?_optionalMap(item),
    ];
  }

  List<int> _predictedMvpPositions(
    List<BattleShipSnapshot> main,
    List<BattleShipSnapshot> escort,
  ) {
    final positions = <int>[];
    int? bestPosition;
    var bestDamage = -1;
    for (var index = 0; index < main.length; index++) {
      if (main[index].damageDealt > bestDamage) {
        bestDamage = main[index].damageDealt;
        bestPosition = index;
      }
    }
    if (bestPosition != null) {
      positions.add(bestPosition);
    }
    bestPosition = null;
    bestDamage = -1;
    for (var index = 0; index < escort.length; index++) {
      if (escort[index].damageDealt > bestDamage) {
        bestDamage = escort[index].damageDealt;
        bestPosition = index + 6;
      }
    }
    if (bestPosition != null) {
      positions.add(bestPosition);
    }
    return positions;
  }

  Map<String, Object?> _map(Object? value) {
    if (value is! Map) {
      throw const GameApiParseException('战斗接口数据不是对象');
    }
    return value.map((key, child) => MapEntry(key.toString(), child));
  }

  Map<String, Object?>? _optionalMap(Object? value) => value is Map
      ? value.map((key, child) => MapEntry(key.toString(), child))
      : null;

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  List<Object?> _fleetArray(Object? value) {
    final values = _list(value);
    if (values.isNotEmpty && _int(values.first) < 0) {
      return values.sublist(1);
    }
    return values;
  }

  int _atInt(List<Object?> values, int index) =>
      index >= 0 && index < values.length ? _int(values[index]) : 0;

  int _atPositive(List<Object?> values, int index, int fallback) =>
      index >= 0 && index < values.length
      ? _positive(values[index], fallback)
      : fallback;

  int _atNonNegative(List<Object?> values, int index, int fallback) =>
      index >= 0 && index < values.length
      ? _nonNegative(values[index], fallback)
      : fallback;

  int _positive(Object? value, int fallback) {
    final number = _int(value);
    return number > 0 ? number : fallback;
  }

  int _nonNegative(Object? value, int fallback) {
    final number = _int(value);
    return number >= 0 ? number : fallback;
  }

  int _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };

  String _string(Object? value) => value?.toString() ?? '';

  @override
  void dispose() {
    _disposed = true;
    accountSession?.removeListener(_onAccountChanged);
    warningSession.dispose();
    _captureNotifications.dispose();
    super.dispose();
  }
}
