import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../battle/battle_damage_alert.dart';
import '../battle/battle_models.dart';
import '../game_state/game_state.dart';
import '../settings/safety_settings_controller.dart';
import '../settings/safety_settings_store.dart';
import '../fleet/ship_damage_level.dart';
import 'game_capture_controller.dart';

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

bool shouldShowAdvanceWarning(GameState state) {
  final combat = state.combatState;
  final sortieFleetId = combat.sortieFleetId;
  if (!combat.isActive || sortieFleetId <= 0) {
    return false;
  }

  final escapedShipIds = combat.escapedShipIds;
  bool hasHeavyDamage(int fleetId) {
    final fleet = state.fleets
        .where((fleet) => fleet.id == fleetId)
        .firstOrNull;
    if (fleet == null) return false;
    // Keep the original positions: missing ship data must not promote a
    // non-flagship into the flagship exception.
    for (final shipId in fleet.shipIds.skip(1)) {
      final ship = state.ships[shipId];
      if (ship == null || escapedShipIds.contains(ship.id)) {
        continue;
      }
      if (shipDamageLevel(currentHp: ship.currentHp, maxHp: ship.maxHp) ==
          ShipDamageLevel.heavy) {
        return true;
      }
    }
    return false;
  }

  if (hasHeavyDamage(sortieFleetId)) {
    return true;
  }
  final isCombinedSortie =
      sortieFleetId == 1 && state.combinedFleetType != CombinedFleetType.none;
  return isCombinedSortie && hasHeavyDamage(2);
}

class BattleResultWarningOverlay extends StatefulWidget {
  const BattleResultWarningOverlay({
    super.key,
    required this.gameCaptureController,
    required this.loadSafetyState,
    required this.safetySettingsController,
    required this.damageAlertPort,
    required this.child,
  });

  final GameCaptureController gameCaptureController;
  final Future<GameState> Function() loadSafetyState;
  final SafetySettingsController safetySettingsController;
  final BattleDamageAlertPort damageAlertPort;
  final Widget child;

  @override
  State<BattleResultWarningOverlay> createState() =>
      _BattleResultWarningOverlayState();
}

class _BattleResultWarningOverlayState
    extends State<BattleResultWarningOverlay> {
  int _advanceCheckGeneration = 0;
  bool _warningDialogVisible = false;

  @override
  void initState() {
    super.initState();
    widget.gameCaptureController.eventActivity.addListener(
      _onGameCaptureUpdate,
    );
  }

  @override
  void didUpdateWidget(BattleResultWarningOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameCaptureController != widget.gameCaptureController) {
      oldWidget.gameCaptureController.eventActivity.removeListener(
        _onGameCaptureUpdate,
      );
      widget.gameCaptureController.eventActivity.addListener(
        _onGameCaptureUpdate,
      );
    }
  }

  @override
  void dispose() {
    widget.gameCaptureController.eventActivity.removeListener(
      _onGameCaptureUpdate,
    );
    super.dispose();
  }

  void _onGameCaptureUpdate() {
    final event = widget.gameCaptureController.latestEvent;
    if (event == null || event.apiResult != 1) return;

    if (event.path == '/kcsapi/api_port/port') {
      _advanceCheckGeneration += 1;
      return;
    }

    final isAdvance =
        event.path == '/kcsapi/api_req_map/start' ||
        event.path == '/kcsapi/api_req_map/next';
    if (!isAdvance) {
      return;
    }

    final generation = ++_advanceCheckGeneration;
    unawaited(_checkAdvanceSafety(generation));
  }

  Future<void> _checkAdvanceSafety(int generation) async {
    try {
      final state = await widget.loadSafetyState();
      if (!mounted || generation != _advanceCheckGeneration) {
        return;
      }
      if (shouldShowAdvanceWarning(state)) {
        _showAdvanceWarning();
      }
    } catch (error) {
      debugPrint('Advance safety check failed: $error');
    }
  }

  void _showAdvanceWarning() {
    final mode = widget.safetySettingsController.battleWarningMode;
    if (mode == BattleWarningMode.off) return;
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
    _showWarningDialog();
  }

  void _showWarningDialog() {
    if (_warningDialogVisible) return;
    _warningDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final l10n =
              AppLocalizations.of(context) ??
              lookupAppLocalizations(const Locale('zh'));
          return AlertDialog(
            backgroundColor: const Color(0xff122431),
            title: Text(
              l10n.postBattleWarningTitle,
              style: const TextStyle(color: Color(0xffd4a85f)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.postBattleWarningHeadline,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.postBattleWarningBody,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff4B9FD5),
                ),
                child: Text(l10n.acknowledgeAndRetreat),
              ),
            ],
          );
        },
      ).whenComplete(() {
        _warningDialogVisible = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
