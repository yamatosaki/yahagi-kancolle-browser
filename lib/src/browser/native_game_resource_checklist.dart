import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_game_warning_dialog.dart';

abstract interface class NativeGameResourceChecklistPort {
  Stream<Map<String, Object?>> get events;
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload);
  Future<void> update(Map<String, Object?> payload);
  Future<void> dismiss({required String kind, required int id});
}

/// A single incoming handler fans out events without replacing other editors.
final class MethodChannelNativeGameResourceChecklistPort
    implements NativeGameResourceChecklistPort {
  const MethodChannelNativeGameResourceChecklistPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/native_warning',
    ),
  ]);

  final MethodChannel channel;
  static final _hubs = Expando<Map<String, _ChecklistEventHub>>(
    'Native checklist events by messenger',
  );

  @override
  Stream<Map<String, Object?>> get events {
    final channels = _hubs[channel.binaryMessenger] ??= {};
    return (channels[channel.name] ??= _ChecklistEventHub(
      channel,
    )).events.stream;
  }

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) =>
      MethodChannelNativeGameWarningDialogPort(channel).show(payload);

  @override
  Future<void> update(Map<String, Object?> payload) =>
      channel.invokeMethod<void>('update', payload);

  @override
  Future<void> dismiss({required String kind, required int id}) =>
      channel.invokeMethod<void>('dismiss', {'kind': kind, 'id': id});
}

final class _ChecklistEventHub {
  _ChecklistEventHub(MethodChannel channel) {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'checklistChanged' || call.arguments is! Map) return;
      final arguments = call.arguments as Map;
      if (arguments.keys.any((key) => key is! String)) return;
      events.add(Map<String, Object?>.from(arguments));
    });
  }

  final events = StreamController<Map<String, Object?>>.broadcast(sync: true);
}

/// Adds editable rows to the existing protected reminder presentation.
final class NativeGameResourceChecklistAdapter
    implements NativeGameWarningDialogPort {
  NativeGameResourceChecklistAdapter({
    required this.kind,
    required this.port,
    required this.items,
    required this.isCurrent,
    required this.onToggle,
    required this.doneLabel,
    this.onReset,
    this.resetLabel,
  });

  final String kind;
  final NativeGameResourceChecklistPort port;
  final List<Map<String, Object?>> Function() items;
  final bool Function() isCurrent;
  final FutureOr<void> Function(String id) onToggle;
  final FutureOr<void> Function()? onReset;
  final String doneLabel;
  final String? resetLabel;
  Map<String, Object?>? _warning;
  StreamSubscription<Map<String, Object?>>? _subscription;
  bool _showing = false;
  int _appliedChangeId = 0;
  final _knownItemIds = <String>{};

  Map<String, Object?> _payload(Map<String, Object?> warning) {
    final rows = items();
    _knownItemIds.addAll(rows.map((row) => row['id']).whereType<String>());
    return {
      ...warning,
      'kind': kind,
      'items': rows,
      'appliedChangeId': _appliedChangeId,
      'labels': {'acknowledge': doneLabel},
      if (onReset != null && resetLabel != null) 'resetLabel': resetLabel,
    };
  }

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) async {
    _warning = Map<String, Object?>.of(warning);
    _showing = true;
    _appliedChangeId = 0;
    _knownItemIds.clear();
    _subscription = port.events.listen(_onEvent);
    try {
      return await port.show(_payload(warning));
    } finally {
      _stopListening();
    }
  }

  void _onEvent(Map<String, Object?> event) {
    if (!_showing ||
        !isCurrent() ||
        event['kind'] != kind ||
        event['id'] != _warning?['id']) {
      return;
    }
    final changeId = event['changeId'];
    if (changeId is! int || changeId <= _appliedChangeId) return;
    if (event['event'] == 'reset' && onReset != null) {
      _appliedChangeId = changeId;
      _applyChange(onReset!);
      return;
    }
    if (event['event'] != 'toggle' || event['checked'] is! bool) return;
    final id = event['itemId'];
    for (final item in items()) {
      if (item['id'] == id) {
        _appliedChangeId = changeId;
        if (item['checked'] != event['checked']) {
          _applyChange(() => onToggle(id! as String));
        } else {
          updateCurrent();
        }
        return;
      }
    }
    if (id is String && _knownItemIds.contains(id)) {
      // A formerly visible row can race an external structural update. Settle
      // its native sequence without applying a stale business edit.
      _appliedChangeId = changeId;
      updateCurrent();
    }
  }

  void _applyChange(FutureOr<void> Function() change) {
    // Controller changes run now; a previous save never blocks the next tap.
    unawaited(
      Future<void>.sync(change)
          .whenComplete(updateCurrent)
          .catchError(
            (Object error) =>
                debugPrint('Native checklist save failed: $error'),
          ),
    );
    updateCurrent();
  }

  void updateCurrent() {
    final warning = _warning;
    if (!_showing || warning == null || !isCurrent()) return;
    unawaited(
      update(warning).catchError((Object error) {
        debugPrint('Native checklist update failed: $error');
      }),
    );
  }

  @override
  Future<void> update(Map<String, Object?> warning) =>
      port.update(_payload(warning));

  @override
  Future<void> dismiss(int id) {
    _stopListening();
    // Stream cancellation can be asynchronous. Native input protection must
    // start immediately and must not wait for that unrelated cleanup Future.
    return port.dismiss(kind: kind, id: id);
  }

  void _stopListening() {
    _showing = false;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object error) {
          debugPrint('Native checklist event cleanup failed: $error');
        }),
      );
    }
  }

  void dispose() => _stopListening();
}
