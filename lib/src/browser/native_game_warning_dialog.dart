import 'package:flutter/services.dart';

enum NativeGameWarningAction { acknowledge, mute, reloadGame, reloadFrame }

/// Native windows can cover the independent Activity WebView without hiding it.
abstract interface class NativeGameWarningDialogPort {
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning);
  Future<void> update(Map<String, Object?> warning);
  Future<void> dismiss(int id);
}

final class MethodChannelNativeGameWarningDialogPort
    implements NativeGameWarningDialogPort {
  const MethodChannelNativeGameWarningDialogPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/native_warning',
    ),
  ]) : _reminderKind = null;

  const MethodChannelNativeGameWarningDialogPort.forReminder(
    String kind, [
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/native_warning',
    ),
  ]) : _reminderKind = kind;

  final MethodChannel channel;
  final String? _reminderKind;

  Map<String, Object?> _payload(Map<String, Object?> warning) =>
      _reminderKind == null ? warning : {...warning, 'kind': _reminderKind};

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) async {
    final action = await channel.invokeMethod<String>(
      'show',
      _payload(warning),
    );
    if (action == null) return null;
    for (final value in NativeGameWarningAction.values) {
      if (value.name == action) return value;
    }
    throw StateError('Unknown native warning action: $action');
  }

  @override
  Future<void> update(Map<String, Object?> warning) =>
      channel.invokeMethod<void>('update', _payload(warning));

  @override
  Future<void> dismiss(int id) =>
      channel.invokeMethod<void>('dismiss', _payload({'id': id}));
}
