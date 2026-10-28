import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../browser/game_reminder_dialog.dart';
import '../browser/native_game_warning_dialog.dart';
import '../game_state/game_state.dart';
import '../localization/game_name_localizations.dart';
import 'new_ship_reminder_controller.dart';

class NewShipReminderFeedback extends StatefulWidget {
  const NewShipReminderFeedback({
    super.key,
    required this.controller,
    required this.stateProvider,
    required this.child,
    this.nativeWarningDialogPort,
    this.presentationEnabled = true,
  });

  final NewShipReminderController controller;
  final GameState Function() stateProvider;
  final Widget child;
  final NativeGameWarningDialogPort? nativeWarningDialogPort;
  final bool presentationEnabled;

  @override
  State<NewShipReminderFeedback> createState() =>
      _NewShipReminderFeedbackState();
}

class _NewShipReminderFeedbackState extends State<NewShipReminderFeedback> {
  int _generation = 0;
  bool _scheduled = false;
  GameReminderDialogPresentation? _presentation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAlerts);
    _handleAlerts();
  }

  @override
  void didUpdateWidget(NewShipReminderFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleAlerts);
      _cancelPresentation();
      widget.controller.addListener(_handleAlerts);
    } else if (oldWidget.nativeWarningDialogPort !=
            widget.nativeWarningDialogPort ||
        oldWidget.presentationEnabled != widget.presentationEnabled) {
      _cancelPresentation();
    }
    _handleAlerts();
  }

  void _handleAlerts() {
    if (!mounted) return;
    if (!widget.presentationEnabled || widget.controller.currentAlert == null) {
      _cancelPresentation();
      return;
    }
    // A later acquisition replaces currentAlert. Finish the already displayed
    // reminder first; acknowledging its old key cannot consume the new alert.
    if (_presentation != null || _scheduled) return;
    final controller = widget.controller;
    final alert = controller.currentAlert!;
    final generation = _generation;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _scheduled = false;
      if (!widget.presentationEnabled ||
          !identical(controller, widget.controller) ||
          !identical(controller.currentAlert, alert)) {
        _handleAlerts();
        return;
      }
      final state = widget.stateProvider();
      final l10n =
          AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh'));
      final message = l10n.newShipAlertBody(
        alert.masterIds
            .map(
              (id) => gameNames(context).shipName(
                state.masterShips[id]?.name ?? l10n.newShipFallbackName(id),
                shipId: id,
              ),
            )
            .join('、'),
      );
      final presentation = showGameReminderDialog(
        context: context,
        kind: 'newShip',
        title: l10n.newShipAlertTitle,
        message: message,
        nativePort: widget.nativeWarningDialogPort,
        builder: (dialogContext, acknowledge) => AlertDialog(
          key: const Key('new-ship-alert-dialog'),
          title: Text(l10n.newShipAlertTitle),
          content: Text(message),
          actions: [
            FilledButton(
              key: const Key('new-ship-reminder-acknowledge'),
              onPressed: acknowledge,
              child: Text(l10n.acknowledge),
            ),
          ],
        ),
      );
      _presentation = presentation;
      unawaited(
        _finishPresentation(presentation, controller, alert, generation),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _finishPresentation(
    GameReminderDialogPresentation presentation,
    NewShipReminderController controller,
    NewShipAlert alert,
    int generation,
  ) async {
    bool acknowledged;
    try {
      acknowledged = await presentation.completed;
    } catch (error) {
      debugPrint('New ship reminder presentation failed: $error');
      if (identical(_presentation, presentation)) _presentation = null;
      return;
    }
    if (!mounted ||
        generation != _generation ||
        !identical(_presentation, presentation) ||
        !identical(controller, widget.controller)) {
      return;
    }
    _presentation = null;
    if (acknowledged) controller.acknowledge(alert.key);
    _handleAlerts();
  }

  void _cancelPresentation() {
    _generation++;
    _scheduled = false;
    final presentation = _presentation;
    _presentation = null;
    presentation?.cancel();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAlerts);
    _cancelPresentation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
