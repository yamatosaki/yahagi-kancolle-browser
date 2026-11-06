import 'dart:async';

import 'package:flutter/material.dart';

import '../browser/game_dialog_presentation_scope.dart';
import '../browser/game_reminder_dialog.dart';
import '../browser/native_game_resource_checklist.dart';
import 'layout_settings_controller.dart';

/// Keeps the native game live and uses the same dismissal protection as alerts.
Future<void> showGameDisplaySettingsDialog({
  required BuildContext context,
  LayoutSettingsController? controller,
  Listenable? changes,
  bool Function()? ownerIsCurrent,
  bool allowNative = true,
  required String kind,
  required String title,
  required List<Map<String, Object?>> Function() items,
  required FutureOr<void> Function(String id) onToggle,
  required FutureOr<void> Function() onReset,
  FutureOr<void> Function()? onDone,
  required String resetLabel,
  String? doneLabel,
  required Widget Function(BuildContext context, VoidCallback close) builder,
}) {
  bool ownerCanEdit() =>
      context.mounted &&
      controller?.uiLocked != true &&
      ownerIsCurrent?.call() != false;

  if (!ownerCanEdit()) return Future<void>.value();
  final scope = GameDialogPresentationScope.maybeOf(context);
  if (scope?.presentationEnabled == false) {
    return Future<void>.value();
  }
  final nativeActivity = scope?.nativeActivity ?? false;
  GameReminderDialogPresentation? presentation;
  NativeGameResourceChecklistAdapter? native;
  var disposed = false;

  bool hasCurrentOwner() {
    if (!ownerCanEdit()) return false;
    final current = context
        .getInheritedWidgetOfExactType<GameDialogPresentationScope>();
    return current?.presentationEnabled != false &&
        (current?.nativeActivity ?? false) == nativeActivity;
  }

  bool isCurrent() =>
      !disposed && presentation?.isActive == true && hasCurrentOwner();

  void refresh() {
    if (disposed) return;
    if (!isCurrent()) {
      presentation?.cancel();
      return;
    }
    native?.updateCurrent();
  }

  if (nativeActivity && allowNative) {
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
      doneLabel:
          doneLabel ?? MaterialLocalizations.of(context).closeButtonTooltip,
    );
  }
  final refreshSources = Listenable.merge([
    controller,
    if (!identical(controller, changes)) changes,
  ]);
  refreshSources.addListener(refresh);
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
    backCancels: onDone != null,
  );
  return presentation.completed
      .then<void>((accepted) async {
        if (accepted && onDone != null && hasCurrentOwner()) await onDone();
      })
      .whenComplete(() {
        disposed = true;
        ownerCheck.cancel();
        refreshSources.removeListener(refresh);
        native?.dispose();
      });
}
