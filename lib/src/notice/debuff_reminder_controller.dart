import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../account/account_session.dart';
import '../bridge/captured_api_event.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_api_event_pipeline.dart';

enum DebuffReminderSource { port, battleResult, airDefense }

@immutable
final class DebuffReminderAlert {
  const DebuffReminderAlert({
    required this.id,
    required this.source,
    required this.occurredAt,
  });

  final int id;
  final DebuffReminderSource source;
  final DateTime occurredAt;
}

class DebuffReminderController extends ChangeNotifier
    implements GameApiEventConsumer {
  DebuffReminderController({
    this.accountSession,
    Future<void> Function()? vibrate,
  }) : _vibrate = vibrate ?? HapticFeedback.vibrate,
       _accountScope = accountSession?.current {
    accountSession?.addListener(_onAccountChanged);
  }

  final AccountSession? accountSession;
  final Future<void> Function() _vibrate;
  final List<DebuffReminderAlert> _alerts = [];
  AccountScope? _accountScope;
  Future<void> _queue = Future<void>.value();
  int _nextId = 1;
  bool _disposed = false;

  List<DebuffReminderAlert> get alerts => List.unmodifiable(_alerts);
  DebuffReminderAlert? get currentAlert =>
      _alerts.isEmpty ? null : _alerts.first;

  void acknowledge(int id) {
    if (_disposed) return;
    final index = _alerts.indexWhere((alert) => alert.id == id);
    if (index < 0) return;
    _alerts.removeAt(index);
    notifyListeners();
  }

  @override
  bool supportsPath(String path) => _sourceForPath(path) != null;

  @override
  void accept(CapturedApiEvent event) {
    final source = _sourceForPath(event.path);
    if (_disposed || source == null) return;
    // Capture ownership synchronously, before earlier vibration work settles.
    final scope = accountSession?.current;
    _queue = _queue.then((_) async {
      if (!_isCurrent(scope)) return;
      try {
        final data = GameApiDecoder.decodeEventData(event);
        if (data is! Map) return;
        final flag = switch (source) {
          DebuffReminderSource.port => _mapValue(
            data['api_event_object'],
            'api_m_flag2',
          ),
          DebuffReminderSource.battleResult => data['api_m2'],
          DebuffReminderSource.airDefense => _mapValue(
            data['api_destruction_battle'],
            'api_m2',
          ),
        };
        if (flag is! num || flag != 1 || !_isCurrent(scope)) return;

        _alerts.add(
          DebuffReminderAlert(
            id: _nextId++,
            source: source,
            occurredAt: event.capturedAt,
          ),
        );
        notifyListeners();
        // A listener can synchronously switch accounts or dispose this object.
        if (!_isCurrent(scope)) return;
        await _vibrate();
      } catch (_) {
        // Malformed packets and unavailable haptics must not poison the queue.
      }
    });
  }

  @override
  Future<void> get idle => _queue;

  bool _isCurrent(AccountScope? scope) =>
      !_disposed &&
      (accountSession == null ||
          (scope != null && accountSession!.isCurrent(scope)));

  void _onAccountChanged() {
    final current = accountSession?.current;
    if (_disposed || identical(current, _accountScope)) return;
    _accountScope = current;
    if (_alerts.isEmpty) return;
    _alerts.clear();
    notifyListeners();
  }

  static Object? _mapValue(Object? value, String key) =>
      value is Map ? value[key] : null;

  static DebuffReminderSource? _sourceForPath(String path) => switch (path) {
    '/kcsapi/api_port/port' => DebuffReminderSource.port,
    '/kcsapi/api_req_map/start' ||
    '/kcsapi/api_req_map/next' => DebuffReminderSource.airDefense,
    _ =>
      path.startsWith('/kcsapi') && path.endsWith('/battleresult')
          ? DebuffReminderSource.battleResult
          : null,
  };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    accountSession?.removeListener(_onAccountChanged);
    _alerts.clear();
    super.dispose();
  }
}
