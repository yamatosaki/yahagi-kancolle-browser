import 'dart:async';

import 'package:flutter/material.dart';

import '../browser/game_dialog_presentation_scope.dart';
import '../browser/game_reminder_dialog.dart';
import '../browser/native_game_resource_checklist.dart';
import 'layout_settings_controller.dart';

/// Keeps the native game live and uses the same dismissal protection as alerts.
Future<void> showGameDisplaySettingsDialog({
  required BuildContext context,
  required LayoutSettingsController controller,
  required String kind,
  required String title,
  required List<Map<String, Object?>> Function() items,
  required FutureOr<void> Function(String id) onToggle,
  required FutureOr<void> Function() onReset,
  required String resetLabel,
  required Widget Function(BuildContext context, VoidCallback close) builder,
}) {
  if (!context.mounted) return Future<void>.value();
  final scope = GameDialogPresentationScope.maybeOf(context);
  if (controller.uiLocked || scope?.presentationEnabled == false) {
    return Future<void>.value();
  }
  final nativeActivity = scope?.nativeActivity ?? false;
  GameReminderDialogPresentation? presentation;
  NativeGameResourceChecklistAdapter? native;
  var disposed = false;

  bool isCurrent() {
    if (disposed ||
        !context.mounted ||
        controller.uiLocked ||
        presentation?.isActive != true) {
      return false;
    }
    final current = context
        .getInheritedWidgetOfExactType<GameDialogPresentationScope>();
    return current?.presentationEnabled != false &&
        (current?.nativeActivity ?? false) == nativeActivity;
  }

  void refresh() {
    if (disposed) return;
    if (!isCurrent()) {
      presentation?.cancel();
      return;
    }
    native?.updateCurrent();
  }

  if (nativeActivity) {
    native = NativeGameResourceChecklistAdapter(
      kind: kind,
      port:
          scope?.nativeChecklistPort ??
          const MethodChannelNativeGameResourceChecklistPort(),
      items: items,
      isCurrent: isCurrent,
      onToggle: onToggle,
      onReset: onReset,
      resetLabel: resetLabel,
      doneLabel: MaterialLocalizations.of(context).closeButtonTooltip,
    );
  }
  controller.addListener(refresh);
  // Native windows have no Flutter dialog widget whose dispose can own them.
  final ownerCheck = Timer.periodic(
    const Duration(seconds: 1),
    (_) => refresh(),
  );
  presentation = showGameReminderDialog(
    context: context,
    kind: kind,
    title: title,
    message: '',
    nativePort: native,
    builder: builder,
  );
  return presentation.completed.then<void>((_) {}).whenComplete(() {
    disposed = true;
    ownerCheck.cancel();
    controller.removeListener(refresh);
    native?.dispose();
  });
}
