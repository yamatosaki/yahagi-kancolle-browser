import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_dialog_presentation_scope.dart';
import 'game_reminder_dialog.dart';
import 'game_surface_input_guard.dart';
import 'native_game_warning_dialog.dart';

class GameSurfaceDialogAction<T> {
  const GameSurfaceDialogAction({
    required this.id,
    required this.label,
    required this.value,
    this.enabled = true,
    this.variant = 'text',
  });

  final String id;
  final String label;
  final T value;
  final bool enabled;
  final String variant;
}

class GameSurfaceDialogChoice<T> {
  const GameSurfaceDialogChoice({
    required this.id,
    required this.label,
    required this.value,
    this.detail = '',
    this.group = '',
  });

  final String id;
  final String label;
  final T value;
  final String detail;
  final String group;
}

class GameSurfaceDialogCheckbox {
  const GameSurfaceDialogCheckbox({
    required this.label,
    required this.onChanged,
    this.initialValue = false,
  });

  final String label;
  final bool initialValue;
  final ValueChanged<bool> onChanged;
}

/// Presents a game dialog above the live surface and settles its typed result
/// only after the existing reminder host has finished input protection.
Future<T?> showGameSurfaceDialog<T>({
  required BuildContext context,
  required String title,
  String message = '',
  List<String> rows = const [],
  List<GameSurfaceDialogAction<T>> actions = const [],
  List<GameSurfaceDialogChoice<T>> choices = const [],
  String? selectedChoiceId,
  GameSurfaceDialogCheckbox? checkbox,
  bool allowFlutterFallback = true,
  // When provided, only these choices need a quiet interval after all touches
  // end. The closing gesture itself is always protected, including dismissal.
  Set<String>? postTouchProtectionActions,
  required Widget Function(BuildContext, void Function(T? value) close) builder,
}) async {
  if (!context.mounted) return null;
  final scope = GameDialogPresentationScope.maybeOf(context);
  if (scope?.presentationEnabled == false) return null;
  final nativeActivity = scope?.nativeActivity ?? false;
  T? selected;
  var selectionMade = false;
  var finished = false;
  GameReminderDialogPresentation? presentation;

  bool ownerIsCurrent() {
    if (!context.mounted) return false;
    final current = context
        .getInheritedWidgetOfExactType<GameDialogPresentationScope>();
    return current?.presentationEnabled != false &&
        (current?.nativeActivity ?? false) == nativeActivity;
  }

  void select(T? value) {
    if (selectionMade || finished || !ownerIsCurrent()) return;
    selectionMade = true;
    selected = value;
  }

  final native = nativeActivity
      ? _NativeGameSurfaceDialogAdapter<T>(
          actions: actions,
          choices: choices,
          rows: rows,
          selectedChoiceId: selectedChoiceId,
          checkbox: checkbox,
          postTouchProtectionActions: postTouchProtectionActions,
          isCurrent: () => !finished && ownerIsCurrent(),
          onSelected: select,
        )
      : null;
  presentation = showGameReminderDialog(
    context: context,
    kind: 'surfaceDialog',
    title: title,
    message: message,
    allowFlutterFallback: allowFlutterFallback,
    nativePort: native,
    inputProtectionMaxDuration:
        GameSurfaceInputGuardRoute.confirmationProtectionLimit,
    needsPostTouchProtection: () =>
        postTouchProtectionActions == null ||
        (selectionMade &&
            (actions.any(
                  (action) =>
                      postTouchProtectionActions.contains(action.id) &&
                      action.value == selected,
                ) ||
                choices.any(
                  (choice) =>
                      postTouchProtectionActions.contains(choice.id) &&
                      choice.value == selected,
                ))),
    builder: (dialogContext, acknowledge) => builder(dialogContext, (value) {
      if (selectionMade ||
          finished ||
          presentation?.isClosing == true ||
          !ownerIsCurrent() ||
          ModalRoute.of(dialogContext)?.isCurrent != true) {
        return;
      }
      select(value);
      acknowledge();
    }),
  );
  // A native window has no Flutter dialog element to dispose when its owner
  // leaves. Revoking the request still lets the host protect held touches.
  final ownerCheck = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!ownerIsCurrent()) presentation?.cancel();
  });
  try {
    final acknowledged = await presentation.completed;
    return acknowledged && ownerIsCurrent() ? selected : null;
  } finally {
    finished = true;
    ownerCheck.cancel();
  }
}

final class _NativeGameSurfaceDialogAdapter<T>
    implements NativeGameWarningDialogPort {
  _NativeGameSurfaceDialogAdapter({
    required this.actions,
    required this.choices,
    required this.rows,
    required this.selectedChoiceId,
    required this.checkbox,
    required this.postTouchProtectionActions,
    required this.isCurrent,
    required this.onSelected,
  });

  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/native_warning',
  );
  final List<GameSurfaceDialogAction<T>> actions;
  final List<GameSurfaceDialogChoice<T>> choices;
  final List<String> rows;
  final String? selectedChoiceId;
  final GameSurfaceDialogCheckbox? checkbox;
  final Set<String>? postTouchProtectionActions;
  final bool Function() isCurrent;
  final ValueChanged<T?> onSelected;

  Map<String, Object?> _payload(Map<String, Object?> warning) => {
    ...warning,
    'kind': 'surfaceDialog',
    'rows': rows,
    'actions': actions.map((action) => action.id).toList(),
    'labels': {for (final action in actions) action.id: action.label},
    'enabled': {for (final action in actions) action.id: action.enabled},
    'variants': {for (final action in actions) action.id: action.variant},
    'dismissible': false,
    if (postTouchProtectionActions case final actions?)
      'postTouchProtectionActions': actions.toList(),
    if (selectedChoiceId != null) 'selectedChoiceId': selectedChoiceId,
    if (checkbox case final checkbox?)
      'checkbox': {'label': checkbox.label, 'checked': checkbox.initialValue},
    if (choices.isNotEmpty)
      'choices': [
        for (final choice in choices)
          {
            'id': choice.id,
            'label': choice.label,
            'detail': choice.detail,
            'group': choice.group,
          },
      ],
  };

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'show',
      _payload(warning),
    );
    if (result == null || !isCurrent()) return null;
    final actionId = result['action'];
    if (actionId is! String || result['checked'] is! bool) {
      throw StateError('Invalid native game dialog result');
    }
    final values = <String, T>{
      for (final action in actions)
        if (action.enabled) action.id: action.value,
      for (final choice in choices) choice.id: choice.value,
    };
    if (!values.containsKey(actionId)) {
      throw StateError('Unknown native game dialog action: $actionId');
    }
    checkbox?.onChanged(result['checked']! as bool);
    onSelected(values[actionId]);
    return NativeGameWarningAction.acknowledge;
  }

  @override
  Future<void> update(Map<String, Object?> warning) =>
      _channel.invokeMethod<void>('update', _payload(warning));

  @override
  Future<void> dismiss(int id) => _channel.invokeMethod<void>('dismiss', {
    'kind': 'surfaceDialog',
    'id': id,
  });
}
