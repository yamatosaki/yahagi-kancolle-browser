import '../theme/app_palette.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../battle/battle_damage_alert.dart';
import '../battle/battle_models.dart';
import '../bridge/captured_api_event.dart';
import '../browser/game_surface_input_guard.dart';
import '../browser/native_game_warning_dialog.dart';
import '../game_state/game_state.dart';
import '../settings/safety_settings_controller.dart';
import '../settings/safety_settings_store.dart';
import '../fleet/ship_damage_level.dart';
import '../quest/quest_completion_drawer.dart';
import 'game_capture_controller.dart';
import 'advance_warning_details.dart';
import 'sortie_warning_session.dart';

bool shouldShowPostBattleWarning(LiveBattle? battle) {
  if (battle == null || battle.displayStage != BattleDisplayStage.result) {
    return false;
  }
  final context = battle.context;
  final isBossNode =
      (context.bossNode > 0 && context.node == context.bossNode) ||
      context.nodeTypeLabel == 'Boss 战';
  if (isBossNode) {
    return false;
  }
  final isCombinedFleet = context.combinedFleetType != CombinedFleetType.none;
  return battle.friendShips.any((ship) {
    if (ship.isEscaped || !ship.isHeavilyDamaged) {
      return false;
    }
    final isExcludedFlagship =
        ship.position == 0 &&
        (ship.fleetRole == BattleFleetRole.main ||
            (isCombinedFleet && ship.fleetRole == BattleFleetRole.escort));
    return !isExcludedFlagship;
  });
}

bool shouldShowAdvanceWarning(GameState state) => collectAdvanceWarningShips(
  state,
  damageControlStateTrusted: false,
).isNotEmpty;

bool isPostBattleSafetyEvent(CapturedApiEvent event) =>
    event.path == '/kcsapi/api_req_sortie/battleresult' ||
    event.path == '/kcsapi/api_req_combined_battle/battleresult';

class BattleResultWarningOverlay extends StatefulWidget {
  const BattleResultWarningOverlay({
    super.key,
    required this.gameCaptureController,
    required this.loadSafetyState,
    required this.safetySettingsController,
    required this.damageAlertPort,
    required this.child,
    this.accountSession,
    this.damageControlStateTrusted,
    this.warningSession,
    this.safetyEventAccepted,
    this.damageControlNoticeEnabled,
    this.onReloadGame,
    this.onReloadGameFrame,
    this.nativeWarningDialogPort,
  });

  final GameCaptureController gameCaptureController;
  final Future<GameState> Function() loadSafetyState;
  final SafetySettingsController safetySettingsController;
  final BattleDamageAlertPort damageAlertPort;
  final Widget child;
  final AccountSession? accountSession;
  final bool Function()? damageControlStateTrusted;
  final SortieWarningSession? warningSession;
  final bool Function(CapturedApiEvent event, GameState state)?
  safetyEventAccepted;
  final bool Function()? damageControlNoticeEnabled;
  final Future<void> Function()? onReloadGame;
  final Future<void> Function()? onReloadGameFrame;
  final NativeGameWarningDialogPort? nativeWarningDialogPort;

  @override
  State<BattleResultWarningOverlay> createState() =>
      _BattleResultWarningOverlayState();
}

class _BattleResultWarningOverlayState
    extends State<BattleResultWarningOverlay> {
  int _advanceCheckGeneration = 0;
  int? _pendingSortieStartGeneration;
  AdvanceWarningTimingSettings? _pendingSortieTiming;
  int _metadataGeneration = 0;
  Future<void> _safetyCheckQueue = Future<void>.value();
  CapturedApiEvent? _warningEvent;
  GameState? _warningState;
  late AccountSession _accountSession;
  late AccountScope _accountScope;
  late SortieWarningSession _warningSession;
  final Set<(String?, String?, int)> _checkedSequences = {};
  final ValueNotifier<List<AdvanceWarningShip>> _warningShips =
      ValueNotifier<List<AdvanceWarningShip>>(const []);
  final Set<DialogRoute<void>> _warningDialogRoutes = {};
  DialogRoute<void>? _warningDialogRoute;
  static int _nativeDialogSequence = 0;
  _NativeWarningPresentation? _nativeWarningPresentation;
  _DeferredFlutterWarning? _deferredFlutterWarning;
  bool _nativeDialogUnavailable = false;
  GameSurfaceInputGuardRoute? _inputGuardRoute;
  VoidCallback? _removeDamageControlNotice;
  bool _damageControlNoticeActive = false;
  int _damageControlNoticeRevision = 0;
  late AdvanceWarningDisplayMode _displayMode;
  bool _postBattlePresentation = false;
  ({
    int generation,
    int continuity,
    String? session,
    String? document,
    int fleet,
    int area,
    int map,
    int node,
    bool terminal,
  })?
  _navigation;

  bool get _hasWarningDialog =>
      _warningDialogRoute != null ||
      _nativeWarningPresentation != null ||
      _deferredFlutterWarning != null;

  @override
  void initState() {
    super.initState();
    _accountSession = widget.accountSession ?? AccountSession.shared;
    _accountScope = _accountSession.current;
    _accountSession.addListener(_onAccountChanged);
    _warningSession = widget.warningSession ?? SortieWarningSession();
    _warningSession.addListener(_onWarningSessionChanged);
    _displayMode = widget.safetySettingsController.advanceWarningDisplayMode;
    widget.safetySettingsController.addListener(_onSafetySettingsChanged);
    widget.gameCaptureController.eventActivity.addListener(
      _onGameCaptureUpdate,
    );
    widget.gameCaptureController.addListener(_onCaptureContinuityChanged);
    _warningShips.addListener(_updateNativeWarning);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateNativeWarning();
    final remove = QuestCompletionDrawerHost.damageControlNoticeRemover(
      context,
    );
    final previous = _removeDamageControlNotice;
    _removeDamageControlNotice = remove;
    if (previous != null && previous != remove && _damageControlNoticeActive) {
      final generation = _advanceCheckGeneration;
      final scope = _accountSession.current;
      final captureGeneration =
          widget.gameCaptureController.continuityGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous();
        _fallbackDamageControlNotice(generation, scope, captureGeneration);
      });
    }
  }

  void _clearDamageControlNotice() {
    _damageControlNoticeRevision++;
    _damageControlNoticeActive = false;
    _removeDamageControlNotice?.call();
  }

  bool _noticeEnabled() {
    try {
      return widget.damageControlNoticeEnabled?.call() ?? true;
    } catch (_) {
      return false;
    }
  }

  bool _currentSafetyEventAccepted() {
    final event = _warningEvent;
    final state = _warningState;
    if (event == null || state == null) return false;
    try {
      return widget.safetyEventAccepted?.call(event, state) ?? true;
    } catch (_) {
      return false;
    }
  }

  void _fallbackDamageControlNotice(
    int generation,
    AccountScope scope,
    int captureGeneration,
  ) {
    if (!mounted ||
        !_damageControlNoticeActive ||
        generation != _advanceCheckGeneration ||
        captureGeneration !=
            widget.gameCaptureController.continuityGeneration ||
        !_accountSession.isCurrent(scope) ||
        !_currentSafetyEventAccepted() ||
        _warningSession.isMuted ||
        widget.safetySettingsController.battleWarningMode ==
            BattleWarningMode.off) {
      return;
    }
    _clearDamageControlNotice();
    _showWarningDialog();
  }

  void _onSafetySettingsChanged() {
    final mode = widget.safetySettingsController.battleWarningMode;
    final display = widget.safetySettingsController.advanceWarningDisplayMode;
    final upgrade =
        _displayMode != display &&
        display == AdvanceWarningDisplayMode.alwaysConfirm;
    _displayMode = display;
    if (mode == BattleWarningMode.off) {
      _invalidateWarning(preserveMetadata: true);
      _cancelDamageAlert();
    } else if (upgrade &&
        _damageControlNoticeActive &&
        !_warningSession.isMuted) {
      _clearDamageControlNotice();
      _showWarningDialog();
    }
  }

  @override
  void didUpdateWidget(BattleResultWarningOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nativeWarningDialogPort != widget.nativeWarningDialogPort) {
      _dismissNativeWarning();
      _nativeDialogUnavailable = false;
    }
    if (_damageControlNoticeActive && !_noticeEnabled()) {
      final generation = _advanceCheckGeneration;
      final scope = _accountSession.current;
      final captureGeneration =
          widget.gameCaptureController.continuityGeneration;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) =>
            _fallbackDamageControlNotice(generation, scope, captureGeneration),
      );
    }
    if (oldWidget.safetySettingsController != widget.safetySettingsController) {
      oldWidget.safetySettingsController.removeListener(
        _onSafetySettingsChanged,
      );
      widget.safetySettingsController.addListener(_onSafetySettingsChanged);
      final settings = widget.safetySettingsController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(widget.safetySettingsController, settings)) {
          _onSafetySettingsChanged();
        }
      });
    }
    if (oldWidget.warningSession != widget.warningSession) {
      _warningSession.removeListener(_onWarningSessionChanged);
      if (oldWidget.warningSession == null) _warningSession.dispose();
      _warningSession = widget.warningSession ?? SortieWarningSession();
      _warningSession.addListener(_onWarningSessionChanged);
      _invalidateWarning();
    }
    final session = widget.accountSession ?? AccountSession.shared;
    if (!identical(_accountSession, session)) {
      _accountSession.removeListener(_onAccountChanged);
      _accountSession = session;
      _accountScope = session.current;
      _accountSession.addListener(_onAccountChanged);
      _warningSession.endSortie();
      _checkedSequences.clear();
      _invalidateWarning();
    }
    if (oldWidget.gameCaptureController != widget.gameCaptureController) {
      _checkedSequences.clear();
      _warningSession.endSortie();
      _invalidateWarning();
      oldWidget.gameCaptureController.eventActivity.removeListener(
        _onGameCaptureUpdate,
      );
      oldWidget.gameCaptureController.removeListener(
        _onCaptureContinuityChanged,
      );
      widget.gameCaptureController.eventActivity.addListener(
        _onGameCaptureUpdate,
      );
      widget.gameCaptureController.addListener(_onCaptureContinuityChanged);
    }
  }

  @override
  void dispose() {
    _deferredFlutterWarning = null;
    _dismissNativeWarning();
    _warningShips.removeListener(_updateNativeWarning);
    widget.safetySettingsController.removeListener(_onSafetySettingsChanged);
    _clearDamageControlNotice();
    _accountSession.removeListener(_onAccountChanged);
    _warningSession.removeListener(_onWarningSessionChanged);
    if (widget.warningSession == null) _warningSession.dispose();
    final inputGuard = _inputGuardRoute;
    _inputGuardRoute = null;
    inputGuard?.cancelProtection();
    if (inputGuard != null && inputGuard.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (inputGuard.isActive) inputGuard.navigator?.removeRoute(inputGuard);
      });
    }
    final routes = _warningDialogRoutes.toList();
    _warningDialogRoute = null;
    if (routes.isEmpty) {
      _warningShips.dispose();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final route in routes) {
          if (route.isActive) route.navigator?.removeRoute(route);
        }
      });
      unawaited(
        Future.wait(
          routes.map((route) => route.completed),
        ).whenComplete(_warningShips.dispose),
      );
    }
    _advanceCheckGeneration += 1;
    widget.gameCaptureController.eventActivity.removeListener(
      _onGameCaptureUpdate,
    );
    widget.gameCaptureController.removeListener(_onCaptureContinuityChanged);
    super.dispose();
  }

  void _onGameCaptureUpdate() {
    final event = widget.gameCaptureController.latestEvent;
    if (event == null) {
      _checkedSequences.clear();
      _warningSession.endSortie();
      _invalidateWarning();
      return;
    }
    if (event.apiResult != 1) return;
    if (event.sequence > 0 &&
        !_checkedSequences.add((
          event.captureSessionId,
          event.captureDocumentId,
          event.sequence,
        ))) {
      return;
    }
    if (_checkedSequences.length > 512) {
      _checkedSequences.remove(_checkedSequences.first);
    }

    if (event.path == '/kcsapi/api_port/port' ||
        event.path == '/kcsapi/api_start2/getData') {
      if (widget.warningSession == null) {
        _warningSession.endSortie();
        _invalidateWarning();
      }
      return;
    }

    final isAdvance =
        event.path == '/kcsapi/api_req_map/start' ||
        event.path == '/kcsapi/api_req_map/next';
    final isResult = isPostBattleSafetyEvent(event);
    final configuredTiming =
        widget.safetySettingsController.advanceWarningTimings;
    final effectiveTiming =
        _pendingSortieTiming ?? _warningSession.timings ?? configuredTiming;
    if (!isAdvance && (!isResult || !effectiveTiming.postBattle)) {
      return;
    }
    if (event.path == '/kcsapi/api_req_map/start') {
      _invalidateWarning();
      if (widget.warningSession == null) _warningSession.startSortie();
      _pendingSortieTiming = configuredTiming;
    }

    final scope = _accountSession.current;
    if (!scope.isKnown) return;
    if (isResult || effectiveTiming.afterAdvance) {
      _clearDamageControlNotice();
    }
    final generation = ++_advanceCheckGeneration;
    _pendingSortieStartGeneration =
        event.path == '/kcsapi/api_req_map/start' ||
            _pendingSortieTiming != null
        ? generation
        : null;
    final captureGeneration = widget.gameCaptureController.continuityGeneration;
    final metadataGeneration = _metadataGeneration;
    final timing = _pendingSortieTiming ?? configuredTiming;
    Future<void> check() => _checkAdvanceSafety(
      generation,
      scope,
      captureGeneration,
      event,
      timing,
      metadataGeneration,
    );
    if ((_pendingSortieTiming ?? _warningSession.timings ?? timing)
        .postBattle) {
      _safetyCheckQueue = _safetyCheckQueue.then(
        (_) => check(),
        onError: (_) => check(),
      );
    } else {
      unawaited(check());
    }
  }

  void _invalidateWarning({bool preserveMetadata = false}) {
    _advanceCheckGeneration += 1;
    if (preserveMetadata) {
      if (_pendingSortieTiming != null) {
        _pendingSortieStartGeneration = _advanceCheckGeneration;
      }
    } else {
      _metadataGeneration += 1;
      _safetyCheckQueue = Future<void>.value();
      _pendingSortieStartGeneration = null;
      _pendingSortieTiming = null;
      _navigation = null;
    }
    _warningEvent = null;
    _warningState = null;
    _clearDamageControlNotice();
    _dismissWarningDialog();
  }

  void _dismissWarningDialog() {
    _deferredFlutterWarning = null;
    _dismissNativeWarning();
    final route = _warningDialogRoute;
    _warningDialogRoute = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  void _dismissNativeWarning() {
    final presentation = _nativeWarningPresentation;
    _nativeWarningPresentation = null;
    if (presentation == null) return;
    unawaited(
      presentation.port.dismiss(presentation.id).catchError((Object error) {
        debugPrint('Native safety warning dismissal failed: $error');
      }),
    );
  }

  void _onCaptureContinuityChanged() {
    final presentation = _nativeWarningPresentation;
    if (presentation != null &&
        presentation.captureGeneration !=
            widget.gameCaptureController.continuityGeneration) {
      _invalidateWarning();
    }
  }

  void _protectWarningDismissal() {
    final current = _inputGuardRoute;
    if (current != null && current.isActive) {
      current.extendProtection();
      return;
    }
    final guard = GameSurfaceInputGuardRoute(context: context);
    _inputGuardRoute = guard;
    // Cover the game before removing the warning so neither native nor platform
    // views receive the remaining taps of the same burst.
    unawaited(
      Navigator.of(context, rootNavigator: true).push<void>(guard).whenComplete(
        () {
          if (identical(_inputGuardRoute, guard)) _inputGuardRoute = null;
        },
      ),
    );
  }

  void _onAccountChanged() {
    if (identical(_accountScope, _accountSession.current)) return;
    _accountScope = _accountSession.current;
    _checkedSequences.clear();
    _warningSession.endSortie();
    _invalidateWarning();
  }

  void _onWarningSessionChanged() {
    if (_warningSession.isMuted) {
      _invalidateWarning(preserveMetadata: true);
      _cancelDamageAlert();
    } else {
      if (_pendingSortieStartGeneration == _advanceCheckGeneration) {
        _clearDamageControlNotice();
        _dismissWarningDialog();
      } else {
        _invalidateWarning();
      }
    }
  }

  void _cancelDamageAlert() {
    final port = widget.damageAlertPort;
    if (port is CancellableBattleDamageAlertPort) {
      final cancellable = port as CancellableBattleDamageAlertPort;
      unawaited(
        cancellable.cancel().catchError((Object error) {
          debugPrint('Failed to cancel damage warning vibration: $error');
        }),
      );
    }
  }

  Future<void> _checkAdvanceSafety(
    int generation,
    AccountScope scope,
    int captureGeneration,
    CapturedApiEvent event,
    AdvanceWarningTimingSettings configuredTiming,
    int metadataGeneration,
  ) async {
    if (!mounted ||
        metadataGeneration != _metadataGeneration ||
        captureGeneration !=
            widget.gameCaptureController.continuityGeneration ||
        !_accountSession.isCurrent(scope)) {
      return;
    }
    final warningGeneration = _warningSession.generation;
    final pendingSortieStart = _pendingSortieStartGeneration == generation;
    try {
      final state = await widget.loadSafetyState();
      if (_pendingSortieStartGeneration == generation) {
        _pendingSortieStartGeneration = null;
        _pendingSortieTiming = null;
      }
      if (!mounted ||
          metadataGeneration != _metadataGeneration ||
          captureGeneration !=
              widget.gameCaptureController.continuityGeneration ||
          !_accountSession.isCurrent(scope) ||
          state.memberId != scope.memberId ||
          (pendingSortieStart &&
              warningGeneration != _warningSession.generation &&
              !_warningSession.isActive) ||
          widget.safetyEventAccepted?.call(event, state) == false) {
        return;
      }
      if (state.combatState.isActive) _warningSession.ensureSortie();
      final timing = _warningSession.timingsForSortie(configuredTiming);
      final combat = state.combatState;
      if (isPostBattleSafetyEvent(event)) {
        if (!timing.postBattle) return;
        final navigation = _navigation;
        if (navigation != null &&
            navigation.generation == _warningSession.generation &&
            navigation.continuity == captureGeneration &&
            navigation.session == event.captureSessionId &&
            navigation.document == event.captureDocumentId &&
            navigation.fleet == combat.sortieFleetId &&
            navigation.area == combat.mapArea &&
            navigation.map == combat.mapInfo &&
            navigation.node == combat.currentNode &&
            navigation.terminal) {
          return;
        }
      } else {
        final envelope =
            event.decodedEnvelope ?? jsonDecode(event.responseBody);
        final data = envelope is Map ? envelope['api_data'] : null;
        _navigation = (
          generation: _warningSession.generation,
          continuity: captureGeneration,
          session: event.captureSessionId,
          document: event.captureDocumentId,
          fleet: combat.sortieFleetId,
          area: combat.mapArea,
          map: combat.mapInfo,
          node: combat.currentNode,
          terminal:
              data is Map &&
              data['api_next'] == 0 &&
              data['api_maparea_id'] == combat.mapArea &&
              data['api_mapinfo_no'] == combat.mapInfo &&
              data['api_no'] == combat.currentNode,
        );
      }
      if (generation != _advanceCheckGeneration || _warningSession.isMuted) {
        return;
      }
      if (!isPostBattleSafetyEvent(event) && !timing.afterAdvance) return;
      _postBattlePresentation = isPostBattleSafetyEvent(event);
      _warningEvent = event;
      _warningState = state;
      var trusted = false;
      try {
        trusted = widget.damageControlStateTrusted?.call() ?? false;
      } catch (error) {
        debugPrint('Damage-control state could not be verified: $error');
      }
      final ships = collectAdvanceWarningShips(
        state,
        damageControlStateTrusted: trusted,
      );
      if (ships.isNotEmpty) {
        await _showAdvanceWarning(ships, generation, scope, captureGeneration);
      } else {
        _clearDamageControlNotice();
        _dismissWarningDialog();
      }
    } catch (error) {
      if (_pendingSortieStartGeneration == generation) {
        _pendingSortieStartGeneration = null;
      }
      debugPrint('Advance safety check failed: $error');
    }
  }

  Future<void> _showAdvanceWarning(
    List<AdvanceWarningShip> ships,
    int generation,
    AccountScope scope,
    int captureGeneration,
  ) async {
    final mode = widget.safetySettingsController.battleWarningMode;
    if (mode == BattleWarningMode.off || _warningSession.isMuted) {
      return;
    }
    _warningShips.value = ships;
    final deferred = _deferredFlutterWarning;
    if (deferred != null && !_deferredFlutterWarningIsCurrent(deferred)) {
      // Rebinding capture can retain the last event. Fresh accepted danger must
      // replace that old wait token without bypassing the still-held guard.
      _deferFlutterWarning(
        Navigator.of(context, rootNavigator: true),
        refreshFailed: deferred.refreshFailed,
        forceFlutter: deferred.forceFlutter,
        nativePort: deferred.nativePort,
      );
    }
    if (_hasWarningDialog) return;
    if (widget.safetySettingsController.advanceWarningDisplayMode ==
            AdvanceWarningDisplayMode.smart &&
        ships.every((ship) => ship.hasConfirmedDamageControl)) {
      final noticeRevision = ++_damageControlNoticeRevision;
      var shown = false;
      try {
        if (_noticeEnabled()) {
          final l10n =
              AppLocalizations.of(context) ??
              lookupAppLocalizations(const Locale('zh'));
          shown = await QuestCompletionDrawerHost.showDamageControlNotice(
            context,
            l10n.advanceWarningDamageControlActive,
            onUnavailable: () => _fallbackDamageControlNotice(
              generation,
              scope,
              captureGeneration,
            ),
            onDismissed: () {
              if (mounted && noticeRevision == _damageControlNoticeRevision) {
                _damageControlNoticeActive = false;
              }
            },
          );
        }
      } catch (error) {
        debugPrint('Damage-control notice unavailable: $error');
      }
      if (!mounted ||
          generation != _advanceCheckGeneration ||
          captureGeneration !=
              widget.gameCaptureController.continuityGeneration ||
          !_accountSession.isCurrent(scope) ||
          !_currentSafetyEventAccepted() ||
          _warningSession.isMuted ||
          widget.safetySettingsController.battleWarningMode ==
              BattleWarningMode.off) {
        return;
      }
      _damageControlNoticeActive =
          shown &&
          _noticeEnabled() &&
          widget.safetySettingsController.advanceWarningDisplayMode ==
              AdvanceWarningDisplayMode.smart;
      if (_damageControlNoticeActive) {
        _alertHeavyDamage();
        return;
      }
    }
    _clearDamageControlNotice();
    _alertHeavyDamage();
    _showWarningDialog();
  }

  void _alertHeavyDamage() {
    if (widget.safetySettingsController.battleStatusEffects.vibrates(
      ShipDamageLevel.heavy,
    )) {
      unawaited(
        widget.damageAlertPort
            .alert(BattleDamageAlertSeverity.heavy)
            .catchError((Object error) {
              debugPrint('战后大破警告震动失败: $error');
            }),
      );
    }
  }

  Future<void> _refreshWarning(
    DialogRoute<void> route,
    AccountScope scope,
    int sortieGeneration,
    Future<void> Function() action,
  ) async {
    if (!mounted ||
        !identical(_warningDialogRoute, route) ||
        !route.isCurrent ||
        !_accountSession.isCurrent(scope) ||
        _warningSession.generation != sortieGeneration) {
      return;
    }
    final generation = _advanceCheckGeneration;
    final captureGeneration = widget.gameCaptureController.continuityGeneration;
    _protectWarningDismissal();
    _dismissWarningDialog();
    try {
      await action();
    } catch (error) {
      debugPrint('Manual game refresh failed: $error');
      if (!mounted ||
          generation != _advanceCheckGeneration ||
          captureGeneration !=
              widget.gameCaptureController.continuityGeneration ||
          !_accountSession.isCurrent(scope) ||
          _warningSession.generation != sortieGeneration ||
          _warningSession.isMuted ||
          widget.safetySettingsController.battleWarningMode ==
              BattleWarningMode.off ||
          !_currentSafetyEventAccepted() ||
          _hasWarningDialog) {
        return;
      }
      _showWarningDialog(refreshFailed: true);
    }
  }

  void _showWarningDialog({
    bool refreshFailed = false,
    bool forceFlutter = false,
  }) {
    if (!mounted || _hasWarningDialog) return;
    final nativePort = widget.nativeWarningDialogPort;
    if (nativePort != null && !_nativeDialogUnavailable && !forceFlutter) {
      final presentation = _NativeWarningPresentation(
        id: ++_nativeDialogSequence,
        port: nativePort,
        scope: _accountSession.current,
        sortieGeneration: _warningSession.generation,
        captureGeneration: widget.gameCaptureController.continuityGeneration,
        refreshFailed: refreshFailed,
      );
      _nativeWarningPresentation = presentation;
      unawaited(_runNativeWarning(presentation));
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (_hasFlutterInputProtection(navigator)) {
      _deferFlutterWarning(
        navigator,
        refreshFailed: refreshFailed,
        forceFlutter: forceFlutter,
        nativePort: nativePort,
      );
      return;
    }
    final warningGeneration = _warningSession.generation;
    final warningScope = _accountSession.current;
    late final DialogRoute<void> route;
    route = GameSafetyDialogRoute(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<List<AdvanceWarningShip>>(
          valueListenable: _warningShips,
          builder: (context, ships, child) {
            final l10n =
                AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('zh'));
            final allEquipped = ships.every(
              (ship) =>
                  ship.damageControlStatus ==
                  AdvanceDamageControlStatus.equipped,
            );
            final hasMissing = ships.any(
              (ship) =>
                  ship.damageControlStatus ==
                  AdvanceDamageControlStatus.missing,
            );
            final reloadGame = widget.onReloadGame;
            final reloadGameFrame = widget.onReloadGameFrame;
            return LayoutBuilder(
              builder: (context, constraints) {
                final viewInsets = MediaQuery.viewInsetsOf(context);
                final contentWidth =
                    (constraints.maxWidth - viewInsets.horizontal - 72).clamp(
                      0.0,
                      480.0,
                    );
                final scrollActions =
                    constraints.maxHeight - viewInsets.vertical < 400;
                final warningActions = _AdvanceWarningButtonRow(
                  availableWidth: contentWidth,
                  leadingFlex: 3,
                  trailingFlex: 2,
                  leading: FilledButton(
                    key: const Key('muteCurrentSortieWarning'),
                    onPressed: () {
                      if (!mounted ||
                          !identical(_warningDialogRoute, route) ||
                          !route.isCurrent ||
                          !_accountSession.isCurrent(warningScope) ||
                          _warningSession.generation != warningGeneration) {
                        return;
                      }
                      _protectWarningDismissal();
                      _warningSession.muteCurrentSortie();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      backgroundColor: appColor(
                        context,
                        const Color(0xffe4c267),
                      ),
                      foregroundColor: appColor(
                        context,
                        const Color(0xff302305),
                      ),
                    ),
                    child: Text(l10n.advanceWarningMuteSortie),
                  ),
                  trailing: FilledButton(
                    key: const Key('acknowledgeAdvanceWarning'),
                    onPressed: () {
                      if (mounted &&
                          identical(_warningDialogRoute, route) &&
                          route.isCurrent) {
                        _protectWarningDismissal();
                        _dismissWarningDialog();
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      backgroundColor: appColor(
                        context,
                        const Color(0xffff7f88),
                      ),
                      foregroundColor: appColor(
                        context,
                        const Color(0xff330c12),
                      ),
                    ),
                    child: Text(l10n.acknowledgeAndRetreat),
                  ),
                );
                final warningDialog = AlertDialog(
                  scrollable: true,
                  constraints: const BoxConstraints(maxWidth: 520),
                  insetPadding: const EdgeInsets.all(16),
                  titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  buttonPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  backgroundColor: appColor(context, const Color(0xff122431)),
                  title: Text(
                    l10n.postBattleWarningTitle,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, const Color(0xffd4a85f)),
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  content: SizedBox(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          allEquipped
                              ? l10n.advanceWarningEquippedHeadline
                              : hasMissing
                              ? l10n.advanceWarningMissingHeadline
                              : l10n.advanceWarningUnknownHeadline,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(
                                context,
                                allEquipped
                                    ? const Color(0xffd4a85f)
                                    : Colors.redAccent,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: appColor(context, const Color(0xff162c38)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var index = 0;
                                  index < ships.length;
                                  index++
                                ) ...[
                                  if (index > 0)
                                    Divider(
                                      height: 1,
                                      color: appColor(
                                        context,
                                        const Color(0xff354550),
                                      ),
                                    ),
                                  _AdvanceWarningShipRow(
                                    ship: ships[index],
                                    l10n: l10n,
                                    availableWidth: (contentWidth - 24).clamp(
                                      0.0,
                                      456.0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _postBattlePresentation
                              ? allEquipped
                                    ? l10n.postBattleDamageControlEquippedBody
                                    : l10n.postBattleDamageControlDangerBody
                              : allEquipped
                              ? l10n.advanceWarningEquippedBody
                              : l10n.postBattleWarningBody,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, Colors.white70),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AdvanceWarningRefreshActions(
                          l10n: l10n,
                          availableWidth: contentWidth,
                          initiallyFailed: refreshFailed,
                          canRefresh: () =>
                              mounted &&
                              identical(_warningDialogRoute, route) &&
                              route.isCurrent &&
                              _accountSession.isCurrent(warningScope) &&
                              _warningSession.generation == warningGeneration,
                          onReloadGame: reloadGame == null
                              ? null
                              : () => _refreshWarning(
                                  route,
                                  warningScope,
                                  warningGeneration,
                                  reloadGame,
                                ),
                          onReloadGameFrame: reloadGameFrame == null
                              ? null
                              : () => _refreshWarning(
                                  route,
                                  warningScope,
                                  warningGeneration,
                                  reloadGameFrame,
                                ),
                        ),
                        if (scrollActions) ...[
                          const SizedBox(height: 10),
                          warningActions,
                        ],
                      ],
                    ),
                  ),
                  actions: scrollActions
                      ? null
                      : [SizedBox(width: 480, child: warningActions)],
                );
                return Padding(
                  padding: viewInsets,
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeLeft: true,
                    removeTop: true,
                    removeRight: true,
                    removeBottom: true,
                    child: warningDialog,
                  ),
                );
              },
            );
          },
        );
      },
    );
    _warningDialogRoute = route;
    _warningDialogRoutes.add(route);
    unawaited(
      route.completed.then((_) {
        _warningDialogRoutes.remove(route);
      }),
    );
    unawaited(
      Navigator.of(context, rootNavigator: true).push<void>(route).whenComplete(
        () {
          if (identical(_warningDialogRoute, route)) {
            _warningDialogRoute = null;
          }
        },
      ),
    );
  }

  void _deferFlutterWarning(
    NavigatorState navigator, {
    required bool refreshFailed,
    required bool forceFlutter,
    required NativeGameWarningDialogPort? nativePort,
  }) {
    final presentation = _DeferredFlutterWarning(
      scope: _accountSession.current,
      metadataGeneration: _metadataGeneration,
      captureGeneration: widget.gameCaptureController.continuityGeneration,
      sortieGeneration: _warningSession.generation,
      refreshFailed: refreshFailed,
      forceFlutter: forceFlutter,
      nativePort: nativePort,
    );
    _deferredFlutterWarning = presentation;
    unawaited(_waitForFlutterInputProtection(navigator, presentation));
  }

  bool _hasFlutterInputProtection(NavigatorState navigator) =>
      GameSafetyDialogRoute.hasInputProtectionFor(navigator) ||
      GameSurfaceInputGuardRoute.hasBlockingForHandoff(navigator);

  bool _deferredFlutterWarningIsCurrent(_DeferredFlutterWarning presentation) =>
      mounted &&
      identical(_deferredFlutterWarning, presentation) &&
      presentation.metadataGeneration == _metadataGeneration &&
      presentation.captureGeneration ==
          widget.gameCaptureController.continuityGeneration &&
      presentation.sortieGeneration == _warningSession.generation &&
      _accountSession.isCurrent(presentation.scope) &&
      !_warningSession.isMuted &&
      widget.safetySettingsController.battleWarningMode !=
          BattleWarningMode.off &&
      _warningShips.value.isNotEmpty &&
      _currentSafetyEventAccepted();

  Future<void> _waitForFlutterInputProtection(
    NavigatorState navigator,
    _DeferredFlutterWarning presentation,
  ) async {
    try {
      while (_deferredFlutterWarningIsCurrent(presentation)) {
        await Future.wait<void>([
          GameSafetyDialogRoute.waitUntilInputProtectionIdle(navigator),
          GameSurfaceInputGuardRoute.waitUntilReadyForHandoff(navigator),
        ]);
        if (!_deferredFlutterWarningIsCurrent(presentation)) return;
        // A preserved dialog hands off atomically to a raw guard. Recheck both
        // registries so completing the old route never exposes a gap.
        if (_hasFlutterInputProtection(navigator)) continue;
        _deferredFlutterWarning = null;
        // New accepted metadata updates this queued warning just as it updates
        // an already visible one. Explicit invalidations revoke its identity.
        _showWarningDialog(
          refreshFailed: presentation.refreshFailed,
          forceFlutter:
              presentation.forceFlutter &&
              identical(
                widget.nativeWarningDialogPort,
                presentation.nativePort,
              ),
        );
        return;
      }
    } finally {
      if (identical(_deferredFlutterWarning, presentation)) {
        _deferredFlutterWarning = null;
      }
    }
  }

  bool _nativeWarningIsCurrent(_NativeWarningPresentation presentation) =>
      mounted &&
      identical(_nativeWarningPresentation, presentation) &&
      identical(widget.nativeWarningDialogPort, presentation.port) &&
      _accountSession.isCurrent(presentation.scope) &&
      _warningSession.generation == presentation.sortieGeneration &&
      widget.gameCaptureController.continuityGeneration ==
          presentation.captureGeneration &&
      !_warningSession.isMuted &&
      widget.safetySettingsController.battleWarningMode !=
          BattleWarningMode.off &&
      _currentSafetyEventAccepted();

  Future<void> _runNativeWarning(
    _NativeWarningPresentation presentation,
  ) async {
    NativeGameWarningAction? action;
    try {
      action = await presentation.port.show(
        _nativeWarningPayload(presentation),
      );
    } catch (error) {
      _nativeWarningFailed(presentation, error);
      return;
    }
    if (!_nativeWarningIsCurrent(presentation)) {
      if (identical(_nativeWarningPresentation, presentation)) {
        _dismissNativeWarning();
      }
      return;
    }
    // The native window owns its post-action input guard. A Flutter modal here
    // would hide the independent WebView and defeat the live background.
    _nativeWarningPresentation = null;
    switch (action) {
      case null:
      case NativeGameWarningAction.acknowledge:
        return;
      case NativeGameWarningAction.mute:
        _warningSession.muteCurrentSortie();
      case NativeGameWarningAction.reloadGame:
        final reload = widget.onReloadGame;
        if (reload != null) await _refreshNativeWarning(presentation, reload);
      case NativeGameWarningAction.reloadFrame:
        final reload = widget.onReloadGameFrame;
        if (reload != null) await _refreshNativeWarning(presentation, reload);
    }
  }

  Future<void> _refreshNativeWarning(
    _NativeWarningPresentation presentation,
    Future<void> Function() action,
  ) async {
    final generation = _advanceCheckGeneration;
    try {
      await action();
    } catch (error) {
      debugPrint('Manual native game refresh failed: $error');
      if (!mounted ||
          generation != _advanceCheckGeneration ||
          presentation.captureGeneration !=
              widget.gameCaptureController.continuityGeneration ||
          !_accountSession.isCurrent(presentation.scope) ||
          _warningSession.generation != presentation.sortieGeneration ||
          _warningSession.isMuted ||
          widget.safetySettingsController.battleWarningMode ==
              BattleWarningMode.off ||
          !_currentSafetyEventAccepted() ||
          _hasWarningDialog) {
        return;
      }
      _showWarningDialog(refreshFailed: true);
    }
  }

  void _updateNativeWarning() {
    final presentation = _nativeWarningPresentation;
    if (presentation == null || !_nativeWarningIsCurrent(presentation)) return;
    unawaited(
      presentation.port
          .update(_nativeWarningPayload(presentation))
          .catchError(
            (Object error) => _nativeWarningFailed(presentation, error),
          ),
    );
  }

  void _nativeWarningFailed(
    _NativeWarningPresentation presentation,
    Object error,
  ) {
    if (!_nativeWarningIsCurrent(presentation)) return;
    debugPrint('Native safety warning unavailable: $error');
    // Missing platform support is permanent for this overlay. A covered or
    // temporarily unavailable WebView must be allowed to try on the next warning.
    if (error is MissingPluginException) _nativeDialogUnavailable = true;
    _dismissNativeWarning();
    _showWarningDialog(
      refreshFailed: presentation.refreshFailed,
      forceFlutter: true,
    );
  }

  Map<String, Object?> _nativeWarningPayload(
    _NativeWarningPresentation presentation,
  ) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final ships = _warningShips.value;
    final allEquipped = ships.every(
      (ship) => ship.damageControlStatus == AdvanceDamageControlStatus.equipped,
    );
    final hasMissing = ships.any(
      (ship) => ship.damageControlStatus == AdvanceDamageControlStatus.missing,
    );
    return {
      'id': presentation.id,
      'title': l10n.postBattleWarningTitle,
      'headline': allEquipped
          ? l10n.advanceWarningEquippedHeadline
          : hasMissing
          ? l10n.advanceWarningMissingHeadline
          : l10n.advanceWarningUnknownHeadline,
      'body': _postBattlePresentation
          ? allEquipped
                ? l10n.postBattleDamageControlEquippedBody
                : l10n.postBattleDamageControlDangerBody
          : allEquipped
          ? l10n.advanceWarningEquippedBody
          : l10n.postBattleWarningBody,
      'rows': [
        for (final ship in ships)
          '${_warningShipName(ship, l10n)}\n${_warningShipStatus(ship, l10n)}',
      ],
      'labels': {
        'acknowledge': l10n.acknowledgeAndRetreat,
        'mute': l10n.advanceWarningMuteSortie,
        'reloadGame': l10n.advanceWarningReloadGame,
        'reloadFrame': l10n.advanceWarningReloadFrame,
      },
      'enabled': {
        'acknowledge': true,
        'mute': true,
        'reloadGame': widget.onReloadGame != null,
        'reloadFrame': widget.onReloadGameFrame != null,
      },
      'refreshFailed': presentation.refreshFailed
          ? l10n.advanceWarningRefreshFailed
          : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

final class _DeferredFlutterWarning {
  const _DeferredFlutterWarning({
    required this.scope,
    required this.metadataGeneration,
    required this.captureGeneration,
    required this.sortieGeneration,
    required this.refreshFailed,
    required this.forceFlutter,
    required this.nativePort,
  });

  final AccountScope scope;
  final int metadataGeneration;
  final int captureGeneration;
  final int sortieGeneration;
  final bool refreshFailed;
  final bool forceFlutter;
  final NativeGameWarningDialogPort? nativePort;
}

final class _NativeWarningPresentation {
  const _NativeWarningPresentation({
    required this.id,
    required this.port,
    required this.scope,
    required this.sortieGeneration,
    required this.captureGeneration,
    required this.refreshFailed,
  });

  final int id;
  final NativeGameWarningDialogPort port;
  final AccountScope scope;
  final int sortieGeneration;
  final int captureGeneration;
  final bool refreshFailed;
}

String _warningShipName(AdvanceWarningShip ship, AppLocalizations l10n) =>
    ship.requiresDisambiguation
    ? '${ship.name}（${l10n.advanceWarningShipPosition(ship.fleetId, ship.position)}）'
    : ship.name;

String _warningShipStatus(AdvanceWarningShip ship, AppLocalizations l10n) =>
    switch (ship.damageControlStatus) {
      AdvanceDamageControlStatus.missing => l10n.advanceWarningMissing,
      AdvanceDamageControlStatus.unknown => l10n.advanceWarningUnknown,
      AdvanceDamageControlStatus.equipped => l10n.advanceWarningEquipped(
        ship.remainingDamageControls.entries
            .map((entry) {
              final item = entry.key == 42
                  ? l10n.advanceWarningPersonnel
                  : l10n.advanceWarningGoddess;
              return '$item ×${entry.value}';
            })
            .join('、'),
      ),
    };

class _AdvanceWarningButtonRow extends StatelessWidget {
  const _AdvanceWarningButtonRow({
    required this.leading,
    required this.trailing,
    required this.availableWidth,
    this.leadingFlex = 1,
    this.trailingFlex = 1,
  });

  final Widget leading;
  final Widget trailing;
  final double availableWidth;
  final int leadingFlex;
  final int trailingFlex;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (availableWidth < 240 * textScale) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [leading, const SizedBox(height: 8), trailing],
      );
    }
    return Row(
      children: [
        Expanded(flex: leadingFlex, child: leading),
        const SizedBox(width: 8),
        Expanded(flex: trailingFlex, child: trailing),
      ],
    );
  }
}

class _AdvanceWarningRefreshActions extends StatefulWidget {
  const _AdvanceWarningRefreshActions({
    required this.l10n,
    required this.availableWidth,
    required this.canRefresh,
    required this.onReloadGame,
    required this.onReloadGameFrame,
    this.initiallyFailed = false,
  });

  final AppLocalizations l10n;
  final double availableWidth;
  final bool Function() canRefresh;
  final Future<void> Function()? onReloadGame;
  final Future<void> Function()? onReloadGameFrame;
  final bool initiallyFailed;

  @override
  State<_AdvanceWarningRefreshActions> createState() =>
      _AdvanceWarningRefreshActionsState();
}

class _AdvanceWarningRefreshActionsState
    extends State<_AdvanceWarningRefreshActions> {
  bool _busy = false;
  late bool _failed = widget.initiallyFailed;

  Future<void> _refresh(Future<void> Function() action) async {
    if (!mounted || _busy || !widget.canRefresh()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
      foregroundColor: appColor(context, const Color(0xffd4a85f)),
      side: BorderSide(color: appColor(context, const Color(0xff867b61))),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdvanceWarningButtonRow(
          availableWidth: widget.availableWidth,
          leading: OutlinedButton.icon(
            key: const Key('advanceWarningReloadGame'),
            onPressed: _busy || widget.onReloadGame == null
                ? null
                : () => _refresh(widget.onReloadGame!),
            icon: const Icon(Icons.refresh, size: 18),
            style: buttonStyle,
            label: Text(widget.l10n.advanceWarningReloadGame),
          ),
          trailing: OutlinedButton.icon(
            key: const Key('advanceWarningReloadFrame'),
            onPressed: _busy || widget.onReloadGameFrame == null
                ? null
                : () => _refresh(widget.onReloadGameFrame!),
            icon: const Icon(Icons.web_asset, size: 18),
            style: buttonStyle,
            label: Text(widget.l10n.advanceWarningReloadFrame),
          ),
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.l10n.advanceWarningRefreshFailed,
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, Colors.redAccent)),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdvanceWarningShipRow extends StatelessWidget {
  const _AdvanceWarningShipRow({
    required this.ship,
    required this.l10n,
    required this.availableWidth,
  });

  final AdvanceWarningShip ship;
  final AppLocalizations l10n;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final equipped =
        ship.damageControlStatus == AdvanceDamageControlStatus.equipped;
    final color = appColor(
      context,
      equipped ? const Color(0xffd4a85f) : Colors.redAccent,
    );
    final name = _warningShipName(ship, l10n);
    final status = _warningShipStatus(ship, l10n);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Builder(
        builder: (context) {
          final stacked =
              availableWidth < 360 ||
              (MediaQuery.textScalerOf(context).scale(14) > 18 &&
                  availableWidth < 430);
          final nameLabel = Text(
            name,
            style: appTextStyle(
              context,
              TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          );
          final statusLabel = Text(
            status,
            textAlign: stacked ? TextAlign.start : TextAlign.end,
            style: appTextStyle(
              context,
              TextStyle(color: color, fontSize: 13, height: 1.5),
            ),
          );
          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [nameLabel, const SizedBox(height: 4), statusLabel],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: nameLabel),
              const SizedBox(width: 12),
              Expanded(flex: 7, child: statusLabel),
            ],
          );
        },
      ),
    );
  }
}
