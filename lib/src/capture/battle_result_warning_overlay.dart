import 'dart:math';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../battle/battle_controller.dart';
import '../battle/battle_models.dart';
import '../settings/safety_settings_controller.dart';
import '../settings/safety_settings_store.dart';
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
  return battle.friendShips.any((ship) => ship.isHeavilyDamaged);
}

class BattleResultWarningOverlay extends StatefulWidget {
  const BattleResultWarningOverlay({
    super.key,
    required this.gameCaptureController,
    required this.battleController,
    required this.safetySettingsController,
    required this.child,
  });

  final GameCaptureController gameCaptureController;
  final BattleController battleController;
  final SafetySettingsController safetySettingsController;
  final Widget child;

  @override
  State<BattleResultWarningOverlay> createState() =>
      _BattleResultWarningOverlayState();
}

class _BattleResultWarningOverlayState
    extends State<BattleResultWarningOverlay> {
  OverlayEntry? _reminderOverlayEntry;

  @override
  void initState() {
    super.initState();
    widget.gameCaptureController.eventActivity.addListener(
      _onGameCaptureUpdate,
    );
    widget.battleController.addListener(_onBattleChanged);
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
    if (oldWidget.battleController != widget.battleController) {
      oldWidget.battleController.removeListener(_onBattleChanged);
      widget.battleController.addListener(_onBattleChanged);
    }
  }

  @override
  void dispose() {
    _clearReminderOverlay();
    widget.battleController.removeListener(_onBattleChanged);
    widget.gameCaptureController.eventActivity.removeListener(
      _onGameCaptureUpdate,
    );
    super.dispose();
  }

  void _onBattleChanged() {
    final battle = widget.battleController.current;
    if (battle == null || battle.displayStage != BattleDisplayStage.result) {
      _clearReminderOverlay();
    }
  }

  void _clearReminderOverlay() {
    if (_reminderOverlayEntry != null) {
      if (_reminderOverlayEntry!.mounted) {
        _reminderOverlayEntry!.remove();
      }
      _reminderOverlayEntry = null;
    }
  }

  void _onGameCaptureUpdate() {
    final event = widget.gameCaptureController.latestEvent;
    if (event == null || !event.path.endsWith('/battleresult')) return;

    // Schedule checking on the next frame so that BattleController has processed the result
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkWarning();
    });
  }

  void _checkWarning() {
    final battle = widget.battleController.current;
    if (shouldShowPostBattleWarning(battle)) {
      final mode = widget.safetySettingsController.battleWarningMode;
      if (mode == BattleWarningMode.confirm) {
        _showWarningDialog();
      } else if (mode == BattleWarningMode.reminder) {
        _showFlashingReminder();
      }
    }
  }

  void _showFlashingReminder() {
    _clearReminderOverlay();
    final overlayState = Overlay.of(context, rootOverlay: true);
    _reminderOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: const _FlashingReminder(),
        );
      },
    );
    overlayState.insert(_reminderOverlayEntry!);
  }

  void _showWarningDialog() {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _FlashingReminder extends StatefulWidget {
  const _FlashingReminder();

  @override
  State<_FlashingReminder> createState() => _FlashingReminderState();
}

class _FlashingReminderState extends State<_FlashingReminder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final flash = sin(_controller.value * 5 * pi).abs();
          return Opacity(opacity: flash.clamp(0.0, 1.0), child: child);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            (AppLocalizations.of(context) ??
                    lookupAppLocalizations(const Locale('zh')))
                .postBattleWarningBanner,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
