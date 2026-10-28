import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../browser/game_reminder_dialog.dart';
import '../browser/native_game_warning_dialog.dart';
import '../settings/notification_settings_controller.dart';
import '../settings/notification_settings_store.dart';
import '../widgets/top_notice.dart';
import 'debuff_reminder_controller.dart';

/// Presents each detected game hint once without changing its detection policy.
class DebuffReminderFeedback extends StatefulWidget {
  const DebuffReminderFeedback({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.headerNoticeController,
    required this.child,
    this.topNoticeDuration,
    this.nativeWarningDialogPort,
    this.presentationEnabled = true,
  });

  final DebuffReminderController controller;
  final NotificationSettingsController settingsController;
  final TopNoticeController headerNoticeController;
  final Widget child;
  final Duration Function()? topNoticeDuration;
  final NativeGameWarningDialogPort? nativeWarningDialogPort;
  final bool presentationEnabled;

  @override
  State<DebuffReminderFeedback> createState() => _DebuffReminderFeedbackState();
}

class _DebuffReminderFeedbackState extends State<DebuffReminderFeedback> {
  int _generation = 0;
  bool _scheduled = false;
  GameReminderDialogPresentation? _presentation;
  DebuffReminderController? _dialogController;
  DebuffReminderAlert? _dialogAlert;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAlerts);
    _handleAlerts();
  }

  @override
  void didUpdateWidget(DebuffReminderFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      oldWidget.controller.removeListener(_handleAlerts);
      widget.controller.addListener(_handleAlerts);
    }
    if (controllerChanged ||
        oldWidget.nativeWarningDialogPort != widget.nativeWarningDialogPort ||
        oldWidget.presentationEnabled != widget.presentationEnabled) {
      _invalidatePresentation();
      _handleAlerts();
    }
  }

  void _handleAlerts() {
    if (!widget.presentationEnabled) return;
    if (_presentation != null) {
      final stillQueued =
          identical(_dialogController, widget.controller) &&
          widget.controller.alerts.any(
            (alert) => identical(alert, _dialogAlert),
          );
      if (stillQueued) return;
      _invalidatePresentation();
    }
    if (_scheduled) return;
    final controller = widget.controller;
    final alert = controller.currentAlert;
    if (alert == null) return;
    _scheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _scheduled = false;
      if (!identical(controller, widget.controller) ||
          !identical(controller.currentAlert, alert)) {
        _handleAlerts();
        return;
      }
      // A setting change applies when the next alert is presented, leaving an
      // already open dialog unchanged until it is dismissed.
      if (widget.settingsController.settings.debuffReminderStyle ==
          DebuffReminderStyle.topNotice) {
        widget.headerNoticeController.show(
          message: '${_message(context, alert)} · ${_time(context, alert)}',
          tone: TopNoticeTone.debuff,
          customIcon: Icons.shield_outlined,
          showIcon: true,
          duration:
              widget.topNoticeDuration?.call() ?? const Duration(seconds: 5),
          replacementKey: 'debuff-reminder-${alert.id}',
        );
        controller.acknowledge(alert.id);
        return;
      }
      _showDialog(controller, alert, generation);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showDialog(
    DebuffReminderController controller,
    DebuffReminderAlert alert,
    int generation,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final presentation = showGameReminderDialog(
      context: context,
      kind: 'debuff',
      title: l10n.debuffReminderTitle,
      message: _message(context, alert),
      detail: _time(context, alert),
      nativePort: widget.nativeWarningDialogPort,
      builder: (context, acknowledge) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          key: const Key('debuff-reminder-dialog'),
          title: Text(l10n.debuffReminderTitle),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_message(context, alert)),
              const SizedBox(height: 12),
              Text(
                _time(context, alert),
                key: const Key('debuff-reminder-time'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            FilledButton(
              key: const Key('debuff-reminder-acknowledge'),
              onPressed: acknowledge,
              child: Text(l10n.acknowledge),
            ),
          ],
        );
      },
    );
    _presentation = presentation;
    _dialogController = controller;
    _dialogAlert = alert;
    unawaited(_awaitDialog(presentation, controller, alert, generation));
  }

  Future<void> _awaitDialog(
    GameReminderDialogPresentation presentation,
    DebuffReminderController controller,
    DebuffReminderAlert alert,
    int generation,
  ) async {
    final acknowledged = await presentation.completed;
    if (!mounted ||
        generation != _generation ||
        !identical(_presentation, presentation)) {
      return;
    }
    _presentation = null;
    _dialogController = null;
    _dialogAlert = null;
    if (acknowledged &&
        identical(controller, widget.controller) &&
        identical(controller.currentAlert, alert)) {
      controller.acknowledge(alert.id);
    }
    if (acknowledged) _handleAlerts();
  }

  void _invalidatePresentation() {
    _generation++;
    _scheduled = false;
    final presentation = _presentation;
    _presentation = null;
    _dialogController = null;
    _dialogAlert = null;
    presentation?.cancel();
  }

  String _message(BuildContext context, DebuffReminderAlert alert) {
    final l10n = AppLocalizations.of(context)!;
    final source = switch (alert.source) {
      DebuffReminderSource.port => l10n.debuffReminderSourcePort,
      DebuffReminderSource.battleResult =>
        l10n.debuffReminderSourceBattleResult,
      DebuffReminderSource.airDefense => l10n.debuffReminderSourceAirDefense,
    };
    return l10n.debuffReminderMessage(source);
  }

  String _time(BuildContext context, DebuffReminderAlert alert) =>
      DateFormat.jms(
        Localizations.localeOf(context).toString(),
      ).format(alert.occurredAt.toLocal());

  @override
  void dispose() {
    widget.controller.removeListener(_handleAlerts);
    _invalidatePresentation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
