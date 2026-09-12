import '../bridge/captured_api_event.dart';
import '../account/account_session.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import 'kcwiki_report_collector.dart';
import 'kcwiki_report_dispatcher.dart';
import 'kcwiki_report_settings.dart';

final class KcwikiReportConsumer implements GameApiEventConsumer {
  KcwikiReportConsumer({
    required this.controller,
    required this.collector,
    required this.dispatcher,
    required GameState Function() gameState,
    required Future<void> Function() waitForGameState,
    AccountSession? accountSession,
  }) : accountSession = accountSession ?? AccountSession.shared {
    _gameState = gameState;
    _waitForGameState = waitForGameState;
    _lastEnabled = controller.enabled;
    controller.addListener(_onSettingsChanged);
    this.accountSession.addListener(_onAccountChanged);
    if (controller.enabled && this.accountSession.current.isKnown) {
      dispatcher.start();
    }
  }

  final KcwikiReportController controller;
  final KcwikiReportCollector collector;
  final KcwikiReportDispatcher dispatcher;
  final AccountSession accountSession;
  late final GameState Function() _gameState;
  late final Future<void> Function() _waitForGameState;

  Future<void> _queue = Future<void>.value();
  int _session = 0;
  int _pendingEventCount = 0;
  bool _disposed = false;
  late bool _lastEnabled;

  int get pendingEventCount => _pendingEventCount;

  @override
  bool supportsPath(String path) =>
      !_disposed &&
      controller.enabled &&
      KcwikiReportCollector.supportedPaths.contains(path);

  @override
  void accept(CapturedApiEvent event) {
    if (!supportsPath(event.path)) return;
    final scope = accountSession.current;
    if (!scope.isKnown) return;
    final session = _session;
    final Future<void> stateReady;
    try {
      stateReady = _waitForGameState();
    } catch (_) {
      controller.recordDropped();
      return;
    }
    _pendingEventCount += 1;
    _queue = _queue.then(
      (_) => _process(event, session, scope, stateReady),
      onError: (_) => _process(event, session, scope, stateReady),
    );
  }

  Future<void> _process(
    CapturedApiEvent event,
    int session,
    AccountScope scope,
    Future<void> stateReady,
  ) async {
    try {
      await stateReady;
      if (_disposed ||
          session != _session ||
          !controller.enabled ||
          !accountSession.isCurrent(scope)) {
        return;
      }
      final state = _gameState();
      if (state.memberId != scope.memberId) return;
      final reports = collector.accept(event, state);
      if (_disposed || session != _session || !controller.enabled) return;
      for (final report in reports) {
        dispatcher.submit(report);
      }
    } catch (_) {
      if (!_disposed && session == _session) controller.recordDropped();
    } finally {
      _pendingEventCount -= 1;
    }
  }

  void _onSettingsChanged() {
    if (controller.enabled == _lastEnabled) return;
    _lastEnabled = controller.enabled;
    _onAccountChanged();
  }

  void _onAccountChanged() {
    _session += 1;
    _queue = Future<void>.value();
    collector.reset();
    dispatcher.stop();
    if (controller.enabled && accountSession.current.isKnown) {
      dispatcher.start();
    }
  }

  @override
  Future<void> get idle async {
    await _queue;
    await dispatcher.idle;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session += 1;
    controller.removeListener(_onSettingsChanged);
    accountSession.removeListener(_onAccountChanged);
    collector.reset();
    dispatcher.dispose();
  }
}
