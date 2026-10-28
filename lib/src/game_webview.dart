import 'theme/app_palette.dart';
import 'localization/runtime_message_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'audio/game_audio_controller.dart';
import 'audio/game_audio_port.dart';
import 'bridge/native_game_capture_script.dart';
import 'browser/game_browser_controller.dart';
import 'browser/game_frame_rate_port.dart';
import 'browser/game_frame_reload_port.dart';
import 'browser/game_frame_rate_policy.dart';
import 'browser/game_frame_rate_runtime_controller.dart';
import 'browser/game_initial_address.dart';
import 'browser/game_local_home.dart';
import 'browser/game_page_alignment_script.dart';
import 'browser/game_presentation_state.dart';
import 'browser/game_toolbar_controller.dart';
import 'browser/game_webview_compatibility.dart';
import 'browser/game_navigation_policy.dart';
import 'browser/game_navigation_watchdog.dart';
import 'browser/game_load_event.dart';
import 'browser/network_proxy_channel.dart';
import 'capture/capture_mode.dart';
import 'capture/capture_mode_controller.dart';
import 'capture/android_game_capture_port.dart';
import 'capture/game_capture_controller.dart';
import 'capture/game_capture_port.dart';
import 'capture/game_capture_startup_sequence.dart';
import 'prototype_status_controller.dart';
import 'settings/network_settings_controller.dart';
import 'settings/network_settings_store.dart';
import 'settings/network_settings_validator.dart';
import 'settings/game_frame_rate_settings.dart';
import 'settings/game_rendering_mode.dart';
import 'settings/game_mouse_wheel_settings.dart';
import 'browser/game_mouse_wheel_region.dart';

import 'settings/safety_settings_controller.dart';

enum GameStartupState {
  loadingSettings,
  applyingNetwork,
  networkReady,
  loadingGame,
  ready,
  error,
}

final class GameSurfaceNetworkResult {
  const GameSurfaceNetworkResult({
    required this.success,
    required this.code,
    required this.message,
  });

  const GameSurfaceNetworkResult.success()
    : success = true,
      code = 'ok',
      message = '';

  final bool success;
  final String code;
  final String message;
}

abstract interface class GameSurfaceStartupOrchestrator {
  Future<GameSurfaceNetworkResult> applyNetworkSettings();

  Future<void> runCaptureStartup({
    required Future<void> Function() waitForSurface,
    required bool Function() isActive,
    required Future<void> Function() navigate,
  });

  Future<void> prepareCapture();

  Future<void> attachAudioPortOnce();

  Future<bool> attachFrameRatePlatformPort();

  FutureOr<void> dispose();
}

@visibleForTesting
final class SharedGameNetworkSettingsArbiter {
  SharedGameNetworkSettingsArbiter._();

  static final SharedGameNetworkSettingsArbiter instance =
      SharedGameNetworkSettingsArbiter._();
  final _SharedNetworkConfigurationArbiter _delegate =
      _SharedNetworkConfigurationArbiter();

  Object claimOwner() {
    final owner = Object();
    _delegate.claim(owner);
    return owner;
  }

  Future<ProxyResult> run(
    Object owner,
    Duration timeout,
    Future<ProxyResult> Function() operation,
  ) => _delegate.run(owner, timeout, operation);

  void release(Object owner) => _delegate.release(owner);

  int get activeOwnerCountForTesting => _delegate.hasOwner ? 1 : 0;

  void resetForTesting() => _delegate.reset();
}

final class _SharedNetworkConfigurationArbiter {
  Object? _owner;
  int _revision = 0;
  _NetworkConfigurationCommand? _desired;
  Future<void> _tail = Future<void>.value();

  bool get hasOwner => _owner != null;

  void claim(Object owner) {
    _owner = owner;
    _revision += 1;
    _desired = null;
  }

  Future<ProxyResult> run(
    Object owner,
    Duration timeout,
    Future<ProxyResult> Function() operation,
  ) {
    if (!identical(owner, _owner)) {
      return Future<ProxyResult>.error(StateError('stale network owner'));
    }
    final command = _NetworkConfigurationCommand(
      owner: owner,
      revision: ++_revision,
      timeout: timeout,
      operation: operation,
    );
    _desired = command;
    final result = Completer<ProxyResult>();
    final scheduled = _tail.then<void>((_) async {
      if (!_isCurrent(command)) {
        result.completeError(StateError('stale network command'));
        return;
      }
      var timedOut = false;
      final raw = Future<ProxyResult>.sync(command.operation);
      unawaited(
        raw.then<void>(
          (_) {
            if (timedOut) _replayIfStale(command);
          },
          onError: (Object _, StackTrace _) {
            if (timedOut) _replayIfStale(command);
          },
        ),
      );
      try {
        final value = await raw.timeout(
          timeout,
          onTimeout: () {
            timedOut = true;
            throw TimeoutException('Network configuration timed out', timeout);
          },
        );
        if (!result.isCompleted) result.complete(value);
      } catch (error, stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
      }
    });
    _tail = scheduled.catchError((Object _, StackTrace _) {});
    return result.future;
  }

  bool _isCurrent(_NetworkConfigurationCommand command) {
    return identical(_owner, command.owner) &&
        identical(_desired, command) &&
        _revision == command.revision;
  }

  void _replayIfStale(_NetworkConfigurationCommand command) {
    if (_isCurrent(command)) return;
    final current = _desired;
    if (current == null || !_isCurrent(current)) return;
    unawaited(
      run(current.owner, current.timeout, current.operation).catchError(
        (Object _, StackTrace _) => const ProxyResult(
          success: false,
          code: 'late_replay_failed',
          message: '',
          elapsedMs: 0,
        ),
      ),
    );
  }

  void release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _desired = null;
    _revision += 1;
  }

  void reset() {
    _owner = null;
    _desired = null;
    _revision += 1;
  }
}

final class _NetworkConfigurationCommand {
  const _NetworkConfigurationCommand({
    required this.owner,
    required this.revision,
    required this.timeout,
    required this.operation,
  });

  final Object owner;
  final int revision;
  final Duration timeout;
  final Future<ProxyResult> Function() operation;
}

final class DefaultGameSurfaceStartupOrchestrator
    implements GameSurfaceStartupOrchestrator {
  DefaultGameSurfaceStartupOrchestrator({
    required this.networkSettingsController,
    required this.captureModeController,
    required this.audioController,
    required this.gameCaptureController,
    required this.frameRateSettingsController,
    GameCapturePort Function()? capturePortFactory,
    GameAudioPort Function()? audioPortFactory,
    GameFrameRatePort Function()? frameRatePortFactory,
    this.networkTimeout = const Duration(seconds: 10),
  }) : _gameCapturePort =
           (capturePortFactory ?? createPlatformGameCapturePort)(),
       _audioPortFactory = audioPortFactory ?? MethodChannelGameAudioPort.new,
       _frameRatePortFactory =
           frameRatePortFactory ?? createPlatformGameFrameRatePort {
    if (networkTimeout <= Duration.zero) {
      throw ArgumentError.value(
        networkTimeout,
        'networkTimeout',
        'must be positive',
      );
    }
    _networkOwner = _networkArbiter.claimOwner();
  }

  final NetworkSettingsController networkSettingsController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameCaptureController gameCaptureController;
  final GameFrameRateSettingsController? frameRateSettingsController;
  final GameCapturePort _gameCapturePort;
  final GameAudioPort Function() _audioPortFactory;
  final GameFrameRatePort Function() _frameRatePortFactory;
  final Duration networkTimeout;
  late final Object _networkOwner;
  final SharedGameNetworkSettingsArbiter _networkArbiter =
      SharedGameNetworkSettingsArbiter.instance;

  bool _capturePortAttached = false;
  bool _captureRebindRequired = false;
  bool _audioPortAttached = false;
  bool _disposed = false;
  int _captureRevision = 0;
  int _captureEpoch = 0;
  Future<void>? _captureInFlight;
  Future<void>? _audioAttachInFlight;

  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async {
    final settings = networkSettingsController.settings;
    final result = await _networkArbiter.run(
      _networkOwner,
      networkTimeout,
      () => networkSettingsController.applySettings(
        settings.mode,
        NetworkSettingsValidator.formatProxyHost(settings.host),
        settings.port,
      ),
    );
    return GameSurfaceNetworkResult(
      success: result.success,
      code: result.code,
      message: result.message,
    );
  }

  @override
  Future<void> runCaptureStartup({
    required Future<void> Function() waitForSurface,
    required bool Function() isActive,
    required Future<void> Function() navigate,
  }) {
    return GameCaptureStartupSequence.run(
      waitForPlatformView: waitForSurface,
      configureCapture: () async {
        if (isActive()) {
          // Startup belongs to a new WebView. Its capture install must not
          // await a response from the retired renderer on the same channel.
          _captureEpoch += 1;
          _captureRebindRequired = true;
          _captureInFlight = null;
          if (_gameCapturePort case final GameCaptureRebindPort port) {
            port.rebindWebView();
          }
          await prepareCapture();
        }
      },
      navigate: navigate,
    );
  }

  @override
  Future<void> prepareCapture() {
    _captureRevision += 1;
    final inFlight = _captureInFlight;
    if (inFlight != null) return inFlight;
    final operation = _drainCaptureChanges();
    _captureInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_captureInFlight, operation)) _captureInFlight = null;
    });
  }

  Future<void> _drainCaptureChanges() async {
    final epoch = _captureEpoch;
    while (!_disposed && epoch == _captureEpoch) {
      final revision = _captureRevision;
      final rebindRequired = _captureRebindRequired;
      _captureRebindRequired = false;
      final enabled = captureModeController.mode.installsGameBridge;
      final script = nativeGameCaptureScript;
      if (!_capturePortAttached) {
        await gameCaptureController.attach(
          _gameCapturePort,
          enabled: enabled,
          script: script,
        );
        if (_disposed || epoch != _captureEpoch) return;
        _capturePortAttached = true;
      } else {
        await gameCaptureController.configure(
          enabled: enabled,
          script: script,
          force: rebindRequired,
        );
      }
      if (epoch != _captureEpoch) return;
      if (revision == _captureRevision) {
        // The controller exposes configuration errors as state. Startup must
        // propagate them before navigating, while unsupported capture remains
        // a valid browsing fallback.
        if (enabled && gameCaptureController.state == GameCaptureState.error) {
          throw StateError('Game capture configuration failed');
        }
        return;
      }
    }
  }

  @override
  Future<void> attachAudioPortOnce() {
    if (_audioPortAttached) return Future<void>.value();
    final inFlight = _audioAttachInFlight;
    if (inFlight != null) return inFlight;
    final operation = _attachAudioPort();
    _audioAttachInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_audioAttachInFlight, operation)) {
        _audioAttachInFlight = null;
      }
    });
  }

  Future<void> _attachAudioPort() async {
    await audioController.attachPort(_audioPortFactory());
    if (_disposed) return;
    _audioPortAttached =
        audioController.availability == GameAudioAvailability.available;
  }

  @override
  Future<bool> attachFrameRatePlatformPort() async {
    final controller = frameRateSettingsController;
    if (controller == null) return false;
    await controller.attachPort(_frameRatePortFactory());
    return controller.supported == true;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _networkArbiter.release(_networkOwner);
    _gameCapturePort.dispose();
  }
}

@visibleForTesting
final class GameWebViewBindingCoordinator {
  GameWebViewBindingCoordinator({
    required GameBrowserController browserController,
    required GameBrowserPort browserPort,
    required NetworkSettingsController networkSettingsController,
    required CaptureModeController captureModeController,
    required GameSurfaceStartupOrchestrator startupOrchestrator,
    required VoidCallback onNetworkSettingsChanged,
    required VoidCallback onCaptureModeChanged,
  }) : this._internal(
         browserController: browserController,
         browserPort: browserPort,
         networkSettingsController: networkSettingsController,
         captureModeController: captureModeController,
         startupOrchestrator: startupOrchestrator,
         onNetworkSettingsChanged: onNetworkSettingsChanged,
         onCaptureModeChanged: onCaptureModeChanged,
       );

  GameWebViewBindingCoordinator._internal({
    required this._browserController,
    required this.browserPort,
    required this._networkSettingsController,
    required this._captureModeController,
    required this._startupOrchestrator,
    required this.onNetworkSettingsChanged,
    required this.onCaptureModeChanged,
  }) {
    _browserController.attachPort(browserPort);
    _networkSettingsController.addListener(onNetworkSettingsChanged);
    _captureModeController.addListener(onCaptureModeChanged);
  }

  final GameBrowserPort browserPort;
  final VoidCallback onNetworkSettingsChanged;
  final VoidCallback onCaptureModeChanged;
  GameBrowserController _browserController;
  NetworkSettingsController _networkSettingsController;
  CaptureModeController _captureModeController;
  GameSurfaceStartupOrchestrator _startupOrchestrator;
  bool _disposed = false;

  GameSurfaceStartupOrchestrator get startupOrchestrator =>
      _startupOrchestrator;

  void update({
    required GameBrowserController browserController,
    required NetworkSettingsController networkSettingsController,
    required CaptureModeController captureModeController,
    required GameSurfaceStartupOrchestrator startupOrchestrator,
  }) {
    if (_disposed) return;
    if (!identical(_browserController, browserController)) {
      _browserController.detachPort(browserPort);
      _browserController = browserController;
      _browserController.attachPort(browserPort);
    }
    if (!identical(_networkSettingsController, networkSettingsController)) {
      _networkSettingsController.removeListener(onNetworkSettingsChanged);
      _networkSettingsController = networkSettingsController;
      _networkSettingsController.addListener(onNetworkSettingsChanged);
    }
    if (!identical(_captureModeController, captureModeController)) {
      _captureModeController.removeListener(onCaptureModeChanged);
      _captureModeController = captureModeController;
      _captureModeController.addListener(onCaptureModeChanged);
    }
    if (!identical(_startupOrchestrator, startupOrchestrator)) {
      final previous = _startupOrchestrator;
      _startupOrchestrator = startupOrchestrator;
      unawaited(_disposeGuarded(previous));
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _browserController.detachPort(browserPort);
    _networkSettingsController.removeListener(onNetworkSettingsChanged);
    _captureModeController.removeListener(onCaptureModeChanged);
    await _disposeGuarded(_startupOrchestrator);
  }

  Future<void> _disposeGuarded(
    GameSurfaceStartupOrchestrator orchestrator,
  ) async {
    try {
      await orchestrator.dispose();
    } catch (error, stackTrace) {
      debugPrint(
        'Game WebView orchestrator dispose failed: $error\n$stackTrace',
      );
    }
  }
}

@visibleForTesting
final class GameWebViewCaptureUpdateCoordinator {
  int _revision = 0;
  int _processedRevision = 0;
  Future<void>? _drainFuture;
  _GameWebViewCaptureUpdate? _latest;
  final Map<int, Completer<void>> _waiters = <int, Completer<void>>{};
  bool _disposed = false;

  Future<void> request({
    required Future<void> Function() configure,
    required Future<void> Function() reload,
    required bool Function() isActive,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    if (_disposed) return Future<void>.value();
    final revision = ++_revision;
    final waiter = Completer<void>();
    _waiters[revision] = waiter;
    late final Future<void> configuration;
    try {
      configuration = Future<void>.sync(configure);
    } catch (error, stackTrace) {
      configuration = Future<void>.error(error, stackTrace);
    }
    _latest = _GameWebViewCaptureUpdate(
      revision: revision,
      configuration: configuration,
      reload: reload,
      isActive: isActive,
      onError: onError,
    );
    _ensureDrain();
    return waiter.future;
  }

  void _ensureDrain() {
    if (_drainFuture != null || _disposed) return;
    final operation = _drain();
    _drainFuture = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_drainFuture, operation)) _drainFuture = null;
        if (!_disposed && _processedRevision < _revision) _ensureDrain();
      }),
    );
  }

  Future<void> _drain() async {
    while (!_disposed && _processedRevision < _revision) {
      final update = _latest!;
      try {
        await update.configuration;
        if (_disposed) return;
        if (update.revision != _revision) {
          _completeThrough(update.revision);
          continue;
        }
        if (update.isActive()) await update.reload();
      } catch (error, stackTrace) {
        if (!_disposed && update.revision == _revision && update.isActive()) {
          update.onError(error, stackTrace);
        }
      }
      _processedRevision = update.revision;
      _completeThrough(update.revision);
    }
  }

  void _completeThrough(int revision) {
    final keys = _waiters.keys.where((key) => key <= revision).toList();
    for (final key in keys) {
      _waiters.remove(key)?.complete();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revision += 1;
    for (final waiter in _waiters.values) {
      waiter.complete();
    }
    _waiters.clear();
  }
}

@visibleForTesting
final class GameWebViewStartupCoordinator {
  GameWebViewStartupCoordinator({
    Duration stageTimeout = const Duration(seconds: 10),
  }) : _stageTimeout = _validateTimeout(stageTimeout);

  Duration _stageTimeout;
  Duration get stageTimeout => _stageTimeout;
  Future<void>? _tail;
  Future<void>? _navigation;
  bool _navigationIssued = false;
  bool _navigationAcknowledged = false;
  Uri? _navigationTarget;

  static Duration _validateTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'stageTimeout', 'must be positive');
    }
    return timeout;
  }

  void updateTimeout(Duration timeout) {
    _stageTimeout = _validateTimeout(timeout);
  }

  Future<void> schedule(Future<void> Function() operation) {
    final previous = _tail ?? Future<void>.value();
    final scheduled = previous
        .catchError((Object _, StackTrace _) {})
        .then<void>((_) => operation());
    _tail = scheduled.catchError((Object _, StackTrace _) {});
    return scheduled;
  }

  Future<void> navigateOnce(Uri target, Future<void> Function() navigate) {
    if (_navigationAcknowledged || _navigationIssued) {
      return _navigation ?? Future<void>.value();
    }
    final pending = _navigation;
    if (pending != null) return pending;

    _navigationIssued = true;
    _navigationTarget = canonicalNavigationTarget(target);
    var responseTimedOut = false;
    late final Future<void> operation;
    operation = Future<void>.sync(navigate)
        .timeout(
          stageTimeout,
          onTimeout: () {
            responseTimedOut = true;
            throw TimeoutException('Initial navigation response timed out');
          },
        )
        .catchError((Object error, StackTrace stackTrace) {
          if (_navigationAcknowledged) return;
          if (!responseTimedOut) {
            _navigationIssued = false;
            _navigationTarget = null;
          }
          Error.throwWithStackTrace(error, stackTrace);
        })
        .whenComplete(() {
          if (identical(_navigation, operation)) _navigation = null;
        });
    _navigation = operation;
    return operation;
  }

  bool acknowledgeNavigation(Uri? startedUri) {
    if (!_navigationIssued || startedUri == null) return false;
    if (canonicalNavigationTarget(startedUri) != _navigationTarget) {
      return false;
    }
    _navigationAcknowledged = true;
    return true;
  }

  Future<T> waitForStage<T>(Future<T> operation) {
    return operation.timeout(stageTimeout);
  }
}

Uri canonicalNavigationTarget(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final isDefaultPort =
      (scheme == 'https' && uri.port == 443) ||
      (scheme == 'http' && uri.port == 80);
  return Uri(
    scheme: scheme,
    userInfo: uri.userInfo,
    host: host,
    port: uri.hasPort && !isDefaultPort ? uri.port : null,
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
  );
}

@visibleForTesting
final class GameWebViewPageReadiness {
  bool _ready = false;

  bool get isReady => _ready;

  void pageStarted() => _ready = false;

  void pageFinished() => _ready = true;

  GameStartupState stateAfterBootstrap(GameStartupState fallback) {
    return _ready ? GameStartupState.ready : fallback;
  }
}

final class _GameWebViewCaptureUpdate {
  const _GameWebViewCaptureUpdate({
    required this.revision,
    required this.configuration,
    required this.reload,
    required this.isActive,
    required this.onError,
  });

  final int revision;
  final Future<void> configuration;
  final Future<void> Function() reload;
  final bool Function() isActive;
  final void Function(Object error, StackTrace stackTrace) onError;
}

class GameWebView extends StatefulWidget {
  const GameWebView({
    super.key,
    required this.networkSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    this.frameRateSettingsController,
    this.mouseWheelSettingsController,
    this.renderingMode = GameRenderingMode.compatibility,
    this.startupTimeout,
    this.startupOrchestratorFactory,
    this.frameRatePortFactory,
    this.navigationTimeout = const Duration(seconds: 45),
    this.onLoadEvent,
  });

  final NetworkSettingsController networkSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameFrameRateSettingsController? frameRateSettingsController;
  final GameMouseWheelSettingsController? mouseWheelSettingsController;
  final GameRenderingMode renderingMode;
  final Duration? startupTimeout;
  final GameSurfaceStartupOrchestrator Function()? startupOrchestratorFactory;
  final GameFrameRatePort Function()? frameRatePortFactory;
  final Duration navigationTimeout;
  final ValueChanged<GameLoadEvent>? onLoadEvent;

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> with WidgetsBindingObserver {
  late final WebViewController _webViewController;
  late Future<void> _compatibilityReady;
  late Future<void> _frameRateReady;
  late final WebViewGameBrowserPort _browserPort;
  late final GameWebViewBindingCoordinator _bindings;
  final GameNavigationPolicy _navigationPolicy = GameNavigationPolicy();
  final GameWebViewCaptureUpdateCoordinator _captureUpdates =
      GameWebViewCaptureUpdateCoordinator();
  late final GameWebViewStartupCoordinator _startupCoordinator;
  late final GameNavigationWatchdog _navigationWatchdog;
  final GameWebViewPageReadiness _pageReadiness = GameWebViewPageReadiness();
  late CaptureMode _activeCaptureMode;
  GameFrameRateRuntimeController? _frameRateRuntimeController;
  static const _scaleChannel = MethodChannel(
    'app.webview/fixed_canvas_scaling',
  );

  int _navigationEpoch = 0;
  int _startupEpoch = 0;
  int _bindingEpoch = 0;
  int _frameRateBindingGeneration = 0;
  Completer<void>? _frameRatePreparationCancelled;
  bool _frameRatePreparationPending = false;
  bool _disposed = false;
  bool _hasNavigated = false;
  bool _retryInProgress = false;
  bool _awaitingNavigationStart = false;
  bool _documentFinished = false;
  int? _failedNavigationEpoch;
  Uri? _navigationUri;
  DateTime? _navigationStartedAt;
  GamePresentationState? _presentationState;
  GamePresentationState? _appliedPresentationState;
  Future<void>? _presentationInFlight;
  int? _presentationInFlightEpoch;
  bool _presentationRefreshRequested = false;
  bool _presentationRuntimeRequested = false;
  bool _presentationForceFitRequested = false;
  static const _readPresentationScript = '''
    (() => typeof window.__yahagiMobileReadPresentation === 'function'
      ? window.__yahagiMobileReadPresentation() : null)();
  ''';

  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  void _onNetworkSettingsChanged() {
    if (!mounted || _disposed) return;
    if (_startupState == GameStartupState.error && !_retryInProgress) {
      unawaited(_retryPage());
    }
  }

  void _handleCaptureModeChanged() {
    _onCaptureModeChanged();
  }

  GameSurfaceStartupOrchestrator _createStartupOrchestrator(
    GameWebView config,
  ) {
    final factory = config.startupOrchestratorFactory;
    if (factory != null) return factory();
    return DefaultGameSurfaceStartupOrchestrator(
      networkSettingsController: config.networkSettingsController,
      captureModeController: config.captureModeController,
      audioController: config.audioController,
      gameCaptureController: config.gameCaptureController,
      frameRateSettingsController: config.frameRateSettingsController,
    );
  }

  @override
  void initState() {
    super.initState();
    _startupCoordinator = GameWebViewStartupCoordinator(
      stageTimeout: widget.startupTimeout ?? const Duration(seconds: 10),
    );
    _navigationWatchdog = GameNavigationWatchdog(
      timeout: widget.navigationTimeout,
      onTimeout: (epoch) {
        if (!_isCurrentNavigation(epoch)) return;
        _failedNavigationEpoch = epoch;
        _emitLoadEvent(GameLoadPhase.timedOut);
        _reportRecoverableError(
          _documentFinished ? '游戏本体加载超时，请重新加载。' : '游戏页面加载超时，请重新加载或检查网络。',
        );
      },
    );
    _navigationWatchdog.setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    WidgetsBinding.instance.addObserver(this);
    _activeCaptureMode = widget.captureModeController.mode;
    _webViewController = WebViewController();
    _compatibilityReady = _configureCompatibility();
    _browserPort = WebViewGameBrowserPort(
      _webViewController,
      gameLocalHomeHtml,
      gameFrameReloadPort: MethodChannelGameFrameReloadPort(),
      compatibilityReady: _compatibilityReady,
      waitForSurfaceReady: () => _frameRateReady,
      isActive: () => mounted && !_disposed,
      prepareForRealNavigation: _prepareCapture,
      synchronizeGamePresentation: () =>
          _synchronizeGamePresentation(forceNativeFit: true),
      beforeNavigation: _beginNavigation,
    );
    _bindings = GameWebViewBindingCoordinator(
      browserController: widget.browserController,
      browserPort: _browserPort,
      networkSettingsController: widget.networkSettingsController,
      captureModeController: widget.captureModeController,
      startupOrchestrator: _createStartupOrchestrator(widget),
      onNetworkSettingsChanged: _onNetworkSettingsChanged,
      onCaptureModeChanged: _handleCaptureModeChanged,
    );
    _frameRateReady = _startFrameRatePreparation();

    _webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff000000))
      ..addJavaScriptChannel(
        'YahagiBridge',
        onMessageReceived: (message) {
          if (widget.browserController.mode == GameBrowserMode.localPrototype) {
            widget.controller.onJavaScriptMessage(message.message);
          }
        },
      )
      ..addJavaScriptChannel(
        'YahagiPresentation',
        onMessageReceived: (message) {
          final forceFit = message.message == 'game-fit';
          final state = decodeGamePresentationState(message.message);
          if (!forceFit && state == null) return;
          // Re-read the current document instead of trusting a possibly stale
          // message. A notification must not reinject the runtime: injection
          // emits game-fit itself and would otherwise keep this queue alive.
          _synchronizeGamePresentation(
            refreshAfterCurrent: true,
            readOnly: true,
            forceNativeFit: forceFit,
          ).catchError((Object _) {});
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (url) {
            if (_disposed || !mounted) return;
            _startupCoordinator.acknowledgeNavigation(Uri.tryParse(url));
            _navigationPolicy.onPageStarted(Uri.tryParse(url));
            _beginNavigation(Uri.tryParse(url));
            _awaitingNavigationStart = false;
            _frameRateRuntimeController?.onPageStarted();
            widget.controller.onPageStarted(url);
            widget.browserController.onPageStarted(url);
            widget.toolbarController.onStageChanged(
              widget.browserController.mode == GameBrowserMode.localPrototype
                  ? GameSurfaceStage.localPrototype
                  : GameSurfaceStage.login,
            );
          },
          onPageFinished: (url) async {
            await _finishPage(url);
          },
          onHttpError: (error) {
            if (!mounted || _disposed) return;
            final code = error.response?.statusCode;
            if (code == null) return;
            final requestedUri = error.request?.uri;
            // The Flutter Android plugin forwards the URI but omits the
            // native isForMainFrame flag for HTTP errors.
            final mainFrame =
                requestedUri != null &&
                _navigationUri != null &&
                canonicalNavigationTarget(requestedUri) ==
                    canonicalNavigationTarget(_navigationUri!);
            _emitLoadEvent(
              GameLoadPhase.failed,
              errorCode: code,
              isMainFrame: mainFrame,
            );
            if (!mainFrame) return;
            _failedNavigationEpoch = _navigationEpoch;
            _navigationWatchdog.complete(_navigationEpoch);
            _pageReadiness.pageStarted();
            final message = '游戏页面加载失败 [HTTP $code]，请重新加载或检查网络。';
            widget.controller.onWebResourceError(message);
            widget.browserController.onWebResourceError(
              description: message,
              isForMainFrame: true,
            );
            _reportRecoverableError(message);
          },
          onWebResourceError: (error) {
            if (_disposed || !mounted) return;
            final isForMainFrame = error.isForMainFrame ?? true;
            final errorUri = Uri.tryParse(error.url ?? '');
            if (isForMainFrame &&
                errorUri?.hasScheme == true &&
                _navigationUri != null &&
                canonicalNavigationTarget(errorUri!) !=
                    canonicalNavigationTarget(_navigationUri!)) {
              return;
            }
            _emitLoadEvent(
              GameLoadPhase.failed,
              errorCode: error.errorCode,
              isMainFrame: isForMainFrame,
            );
            if (isForMainFrame) {
              _failedNavigationEpoch = _navigationEpoch;
              _navigationWatchdog.complete(_navigationEpoch);
              _pageReadiness.pageStarted();
              widget.controller.onWebResourceError(error.description);
              // Check if it's an SSL error (usually -11 on Android, but flutter maps to description)
              if (error.description.toLowerCase().contains('ssl') ||
                  error.description.toLowerCase().contains('cert')) {
                widget.browserController.onWebResourceError(
                  description: '安全证书错误：可能是岛风GO证书未受信任或网络被劫持。',
                  isForMainFrame: isForMainFrame,
                );
                _reportRecoverableError('安全证书错误：可能是岛风GO证书未受信任或网络被劫持。');
                return;
              }
              _reportRecoverableError(
                '游戏页面加载失败 [${error.errorCode}]，请重新加载或检查网络。',
              );
            }
            widget.browserController.onWebResourceError(
              description: error.description,
              isForMainFrame: isForMainFrame,
            );
          },
        ),
      );

    _scheduleStartupSequence();
  }

  @override
  void didUpdateWidget(covariant GameWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_disposed) return;
    if (oldWidget.startupTimeout != widget.startupTimeout) {
      _startupCoordinator.updateTimeout(
        widget.startupTimeout ?? const Duration(seconds: 10),
      );
    }

    final startupDependenciesChanged =
        !identical(
          oldWidget.frameRatePortFactory,
          widget.frameRatePortFactory,
        ) ||
        !identical(
          oldWidget.networkSettingsController,
          widget.networkSettingsController,
        ) ||
        !identical(
          oldWidget.captureModeController,
          widget.captureModeController,
        ) ||
        !identical(oldWidget.audioController, widget.audioController) ||
        !identical(
          oldWidget.gameCaptureController,
          widget.gameCaptureController,
        ) ||
        !identical(
          oldWidget.frameRateSettingsController,
          widget.frameRateSettingsController,
        );
    final startupContextChanged =
        startupDependenciesChanged ||
        !identical(oldWidget.browserController, widget.browserController);
    if (startupContextChanged) {
      _startupEpoch += 1;
      _navigationEpoch += 1;
      _navigationWatchdog.cancel();
      if (_hasNavigated && !_pageReadiness.isReady) {
        _navigationWatchdog.start(
          _navigationEpoch,
          timeout: widget.navigationTimeout,
        );
      }
    }
    if (startupDependenciesChanged) {
      _bindingEpoch += 1;
    }
    if (!identical(
      oldWidget.captureModeController,
      widget.captureModeController,
    )) {
      _activeCaptureMode = widget.captureModeController.mode;
    }

    _bindings.update(
      browserController: widget.browserController,
      networkSettingsController: widget.networkSettingsController,
      captureModeController: widget.captureModeController,
      startupOrchestrator: startupDependenciesChanged
          ? _createStartupOrchestrator(widget)
          : _bindings.startupOrchestrator,
    );

    if (startupDependenciesChanged) {
      _frameRateRuntimeController?.dispose();
      _frameRateRuntimeController = null;
      _frameRateReady = _startFrameRatePreparation();
    }
    if (oldWidget.renderingMode != widget.renderingMode) {
      _compatibilityReady = _configureCompatibility();
    }
    if (startupContextChanged) {
      _scheduleStartupSequence();
    }
  }

  void _scheduleStartupSequence() {
    unawaited(
      _executeStartupSequence().catchError((Object error, StackTrace stack) {
        debugPrint('Game WebView startup scheduling failed: $error\n$stack');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _navigationWatchdog.setForeground(state == AppLifecycleState.resumed);
    _frameRateRuntimeController?.onLifecycleChanged(state);
  }

  Future<void> _executeStartupSequence({bool retryNavigation = false}) {
    final startupEpoch = ++_startupEpoch;
    final orchestrator = _bindings.startupOrchestrator;
    final compatibilityReady = _compatibilityReady;
    final frameRateReady = _frameRateReady;
    final networkSettings = widget.networkSettingsController.settings;
    final browserController = widget.browserController;
    return _startupCoordinator.schedule(
      () => _runStartupSequence(
        startupEpoch: startupEpoch,
        orchestrator: orchestrator,
        compatibilityReady: compatibilityReady,
        frameRateReady: frameRateReady,
        networkSettings: networkSettings,
        browserController: browserController,
        retryNavigation: retryNavigation,
      ),
    );
  }

  Future<void> _runStartupSequence({
    required int startupEpoch,
    required GameSurfaceStartupOrchestrator orchestrator,
    required Future<void> compatibilityReady,
    required Future<void> frameRateReady,
    required NetworkSettings networkSettings,
    required GameBrowserController browserController,
    required bool retryNavigation,
  }) async {
    var waitingForPageCommandResponse = false;
    try {
      if (!_isCurrentStartup(startupEpoch, orchestrator)) return;
      setState(() => _startupState = GameStartupState.applyingNetwork);

      await _startupCoordinator.waitForStage(compatibilityReady);
      if (!_isCurrentStartup(startupEpoch, orchestrator)) return;
      await _startupCoordinator.waitForStage(frameRateReady);
      if (!_isCurrentStartup(startupEpoch, orchestrator)) return;

      final result = await _startupCoordinator.waitForStage(
        orchestrator.applyNetworkSettings(),
      );
      if (!_isCurrentStartup(startupEpoch, orchestrator)) return;

      if (!result.success && networkSettings.mode != NetworkMode.system) {
        _reportRecoverableError('网络设置应用失败 [${result.code}]: ${result.message}');
        return;
      }

      if (!_pageReadiness.isReady) {
        setState(() => _startupState = GameStartupState.networkReady);
      }

      final initialAddress = resolveInitialGameAddress(browserController);

      await _startupCoordinator.waitForStage(
        orchestrator.runCaptureStartup(
          waitForSurface: () async {
            await WidgetsBinding.instance.endOfFrame;
            // The compatibility PlatformView does not exist while initState is
            // configuring its controller. Bind the native all-frame bridge only
            // after the first rendered frame and before the first DMM navigation.
            await _browserPort.configureFrameReload();
          },
          isActive: () => _isCurrentStartup(startupEpoch, orchestrator),
          navigate: () async {
            if (!_isCurrentStartup(startupEpoch, orchestrator)) return;
            await browserController.prepareInitialHome();
            if (!_isCurrentStartup(startupEpoch, orchestrator)) return;
            waitingForPageCommandResponse = true;
            try {
              if (retryNavigation && _hasNavigated) {
                _beginNavigation(_navigationUri ?? initialAddress);
                await _webViewController.reload();
              } else {
                await _startupCoordinator.navigateOnce(initialAddress, () {
                  _beginNavigation(initialAddress);
                  return _webViewController.loadRequest(initialAddress);
                });
              }
            } finally {
              waitingForPageCommandResponse = false;
            }
          },
        ),
      );
      if (_isCurrentStartup(startupEpoch, orchestrator) &&
          _pageReadiness.isReady) {
        await _startupCoordinator.waitForStage(
          orchestrator.attachAudioPortOnce(),
        );
        if (_isCurrentStartup(startupEpoch, orchestrator)) {
          _completePresentationIfReady();
        }
      }
    } catch (error, stackTrace) {
      // Document callbacks can arrive before the platform method acknowledges
      // loadRequest/reload. Once navigation started, its document watchdog owns
      // the deadline, even if this method response arrives late.
      if (error is TimeoutException &&
          waitingForPageCommandResponse &&
          _isCurrentStartup(startupEpoch, orchestrator) &&
          _hasNavigated &&
          !_awaitingNavigationStart) {
        return;
      }
      debugPrint('Game WebView startup failed: $error\n$stackTrace');
      if (_isCurrentStartup(startupEpoch, orchestrator)) {
        _reportRecoverableError('游戏页面启动失败：$error');
      }
    }
  }

  bool _isCurrentStartup(
    int epoch,
    GameSurfaceStartupOrchestrator orchestrator,
  ) {
    return mounted &&
        !_disposed &&
        epoch == _startupEpoch &&
        identical(orchestrator, _bindings.startupOrchestrator);
  }

  void _reportRecoverableError(String message) {
    if (!mounted || _disposed) return;
    _startupEpoch += 1;
    // A completed binding also serves later settings changes and toolbar reloads.
    // Only an unfinished installation should be cancelled by a page error.
    if (_frameRatePreparationPending) _cancelFrameRatePreparation();
    if (_failedNavigationEpoch != _navigationEpoch) {
      _emitLoadEvent(GameLoadPhase.failed);
    }
    _failedNavigationEpoch = _navigationEpoch;
    _navigationWatchdog.complete(_navigationEpoch);
    setState(() {
      _startupState = GameStartupState.error;
      _startupErrorMessage = message;
    });
  }

  Future<void> _attachAudioPortOnce() async {
    await _bindings.startupOrchestrator.attachAudioPortOnce();
  }

  Future<void> _finishPage(String url) async {
    final navigationEpoch = _navigationEpoch;
    if (!_isUsableNavigation(navigationEpoch) || _awaitingNavigationStart) {
      return;
    }
    final finishedUri = Uri.tryParse(url);
    if (_navigationUri != null &&
        finishedUri != null &&
        canonicalNavigationTarget(finishedUri) !=
            canonicalNavigationTarget(_navigationUri!)) {
      return;
    }
    try {
      _emitLoadEvent(GameLoadPhase.documentFinished);
      widget.controller.onPageFinished(url);
      widget.browserController.onPageFinished(url);

      await _startupCoordinator.waitForStage(_synchronizeGamePresentation());
      if (!_isUsableNavigation(navigationEpoch)) return;
      await _startupCoordinator.waitForStage(_prepareCapture());
      if (!_isUsableNavigation(navigationEpoch)) return;
      await _startupCoordinator.waitForStage(_attachAudioPortOnce());
      if (!_isUsableNavigation(navigationEpoch)) return;

      _pageReadiness.pageFinished();
      _documentFinished = true;
      _completePresentationIfReady();
      final frameReady = _frameRateRuntimeController?.onPageReady(
        samplingEnabled:
            widget.browserController.mode != GameBrowserMode.localPrototype &&
            isGameFrameRateSamplingPage(url),
      );
      if (frameReady != null) {
        await _startupCoordinator.waitForStage(frameReady);
      }
    } catch (error, stackTrace) {
      debugPrint('Game WebView page finish failed: $error\n$stackTrace');
      if (_isUsableNavigation(navigationEpoch)) {
        _reportRecoverableError('游戏页面准备失败：$error');
      }
    }
  }

  Future<void> _synchronizeGamePresentation({
    bool refreshAfterCurrent = false,
    bool readOnly = false,
    bool forceNativeFit = false,
  }) {
    final navigationEpoch = _navigationEpoch;
    if (!_isUsableNavigation(navigationEpoch)) return Future<void>.value();
    if (_presentationInFlightEpoch == navigationEpoch &&
        _presentationInFlight != null) {
      // A page-finish install must survive an earlier read-only message probe.
      if (refreshAfterCurrent || forceNativeFit || !readOnly) {
        _presentationRefreshRequested = true;
        _presentationRuntimeRequested |= !readOnly;
        _presentationForceFitRequested |= forceNativeFit;
      }
      return _presentationInFlight!;
    }
    _presentationRefreshRequested = false;
    _presentationRuntimeRequested = !readOnly;
    _presentationForceFitRequested = forceNativeFit;
    // Publish the queue before a platform implementation can synchronously
    // deliver the runtime's game-fit notification during script evaluation.
    final operation = Future<void>.microtask(
      () => _drainGamePresentation(navigationEpoch),
    );
    _presentationInFlight = operation;
    _presentationInFlightEpoch = navigationEpoch;
    return operation.whenComplete(() {
      if (identical(_presentationInFlight, operation)) {
        _presentationInFlight = null;
        _presentationInFlightEpoch = null;
      }
    });
  }

  Future<void> _drainGamePresentation(int navigationEpoch) async {
    if (!_isUsableNavigation(navigationEpoch)) return;
    do {
      _presentationRefreshRequested = false;
      final runRuntime = _presentationRuntimeRequested;
      final forceNativeFit = _presentationForceFitRequested;
      _presentationRuntimeRequested = false;
      _presentationForceFitRequested = false;
      try {
        await _probeGamePresentation(
          navigationEpoch,
          runRuntime: runRuntime,
          forceNativeFit: forceNativeFit,
        );
      } catch (_) {
        // A newer queued request still deserves its own attempt after an
        // older probe or native fit fails. Never retry an idle or retired page.
        if (!_isUsableNavigation(navigationEpoch) ||
            !_presentationRefreshRequested) {
          rethrow;
        }
      }
    } while (_isUsableNavigation(navigationEpoch) &&
        _presentationRefreshRequested);
  }

  Future<void> _probeGamePresentation(
    int navigationEpoch, {
    required bool runRuntime,
    required bool forceNativeFit,
  }) async {
    final gameSurfaceResult = await _startupCoordinator.waitForStage(
      _webViewController.runJavaScriptReturningResult(
        runRuntime ? gamePageAlignmentScript : _readPresentationScript,
      ),
    );
    if (!_isUsableNavigation(navigationEpoch)) return;
    await _applyGamePresentation(
      decodeGamePresentationState(gameSurfaceResult),
      navigationEpoch,
      forceNativeFit: forceNativeFit,
    );
  }

  Future<void> _applyGamePresentation(
    GamePresentationState? state,
    int navigationEpoch, {
    bool forceNativeFit = false,
  }) async {
    if (!_isUsableNavigation(navigationEpoch)) return;
    if (state != _presentationState) {
      _presentationState = state;
      if (state == GamePresentationState.pending) {
        _emitLoadEvent(GameLoadPhase.bodyWaiting);
        if (_documentFinished && _startupState == GameStartupState.ready) {
          _navigationWatchdog.start(
            _navigationEpoch,
            timeout: widget.navigationTimeout,
          );
          setState(() => _startupState = GameStartupState.loadingGame);
        }
      }
      if (state == GamePresentationState.game) {
        _emitLoadEvent(GameLoadPhase.gameDetected);
      }
    }
    final action = state?.platformAction ?? GamePresentationPlatformAction.none;
    if (action == GamePresentationPlatformAction.none) return;
    widget.toolbarController.onStageChanged(
      state == GamePresentationState.game
          ? GameSurfaceStage.game
          : GameSurfaceStage.login,
    );
    if (_webViewController.platform is AndroidWebViewController &&
        (state != _appliedPresentationState ||
            (forceNativeFit && state == GamePresentationState.game))) {
      switch (action) {
        case GamePresentationPlatformAction.bind:
          await _startupCoordinator.waitForStage(
            _scaleChannel.invokeMethod<void>(
              'bindFixedCanvas',
              <String, Object>{'contentWidth': 1200, 'contentHeight': 720},
            ),
          );
        case GamePresentationPlatformAction.release:
          await _startupCoordinator.waitForStage(
            _scaleChannel.invokeMethod<void>('releaseFixedCanvas'),
          );
        case GamePresentationPlatformAction.none:
          return;
      }
      if (!_isCurrentNavigation(navigationEpoch)) return;
    }
    if (state == GamePresentationState.game &&
        (state != _appliedPresentationState || forceNativeFit)) {
      await _startupCoordinator.waitForStage(
        _webViewController.runJavaScript('''
          if (window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();
        '''),
      );
    }
    if (!_isUsableNavigation(navigationEpoch)) return;
    _appliedPresentationState = state;
    _completePresentationIfReady();
  }

  void _beginNavigation(Uri? uri) {
    if (!mounted || _disposed) return;
    _hasNavigated = true;
    _navigationEpoch += 1;
    _navigationUri = uri ?? _navigationUri;
    _navigationStartedAt = DateTime.now();
    _failedNavigationEpoch = null;
    _awaitingNavigationStart = true;
    _documentFinished = false;
    _presentationState = null;
    _appliedPresentationState = null;
    _pageReadiness.pageStarted();
    _navigationWatchdog.start(
      _navigationEpoch,
      timeout: widget.navigationTimeout,
    );
    _emitLoadEvent(GameLoadPhase.navigationStarted);
    setState(() {
      _startupState = GameStartupState.loadingGame;
      _startupErrorMessage = '';
    });
  }

  void _emitLoadEvent(
    GameLoadPhase phase, {
    int? errorCode,
    bool? isMainFrame,
  }) {
    final duration = _navigationStartedAt == null
        ? 0
        : DateTime.now().difference(_navigationStartedAt!).inMilliseconds;
    try {
      widget.onLoadEvent?.call(
        GameLoadEvent(
          phase: phase,
          navigationEpoch: _navigationEpoch,
          durationMs: duration < 0 ? 0 : duration,
          pageCategory: classifyGamePage(_navigationUri),
          errorCode: errorCode,
          isMainFrame: isMainFrame,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Game load observer failed: ${error.runtimeType}\n$stackTrace',
      );
    }
  }

  void _completePresentationIfReady() {
    if (!_isUsableNavigation(_navigationEpoch) ||
        !_documentFinished ||
        !_pageReadiness.isReady ||
        _presentationState == null ||
        _presentationState == GamePresentationState.pending) {
      return;
    }
    _navigationWatchdog.complete(_navigationEpoch);
    if (_startupState != GameStartupState.ready) {
      _emitLoadEvent(
        _presentationState == GamePresentationState.web
            ? GameLoadPhase.loginVisible
            : GameLoadPhase.visible,
      );
      setState(() => _startupState = GameStartupState.ready);
    }
  }

  bool _isCurrentNavigation(int epoch) =>
      mounted && !_disposed && epoch == _navigationEpoch;
  bool _isUsableNavigation(int epoch) =>
      _isCurrentNavigation(epoch) && _failedNavigationEpoch != epoch;

  void _onCaptureModeChanged() {
    final nextMode = widget.captureModeController.mode;
    if (nextMode == _activeCaptureMode) {
      return;
    }
    _activeCaptureMode = nextMode;
    final bindingEpoch = _bindingEpoch;
    final orchestrator = _bindings.startupOrchestrator;
    unawaited(
      _captureUpdates.request(
        configure: orchestrator.prepareCapture,
        reload: _browserPort.reload,
        isActive: () => _isCurrentBinding(bindingEpoch, orchestrator),
        onError: (error, stackTrace) {
          debugPrint('Game WebView capture update failed: $error\n$stackTrace');
          if (_isCurrentBinding(bindingEpoch, orchestrator)) {
            _reportRecoverableError('抓包模式更新失败：$error');
          }
        },
      ),
    );
  }

  Future<void> _prepareCapture() async {
    await _bindings.startupOrchestrator.prepareCapture();
  }

  Future<void> _configureCompatibility() async {
    final platformController = _webViewController.platform;
    if (platformController is! AndroidWebViewController) {
      return;
    }

    await platformController.setUseWideViewPort(false);

    final currentUserAgent = await platformController.getUserAgent();
    if (currentUserAgent == null || currentUserAgent.isEmpty) {
      return;
    }

    final cookieManager = WebViewCookieManager().platform;
    if (cookieManager is! AndroidWebViewCookieManager) {
      return;
    }

    await GameWebViewCompatibility.configure(
      _AndroidWebViewCompatibilityPort(
        controller: platformController,
        cookieManager: cookieManager,
      ),
      currentUserAgent: currentUserAgent,
      renderingMode: widget.renderingMode,
    );
  }

  Future<void> _startFrameRatePreparation() {
    _cancelFrameRatePreparation();
    final cancelled = Completer<void>();
    _frameRatePreparationCancelled = cancelled;
    _frameRatePreparationPending = true;
    final preparation =
        Future.any<void>([
          _configureFrameRate(cancelled.future),
          cancelled.future.then<void>(
            (_) => throw const GameFrameRateConfigurationCancelledException(),
          ),
        ]).whenComplete(() {
          if (identical(_frameRatePreparationCancelled, cancelled)) {
            _frameRatePreparationPending = false;
          }
        });
    // Startup may still be awaiting compatibility/network settings. Observe an
    // early native failure now; awaiting the original future still propagates it.
    unawaited(preparation.catchError((Object _, StackTrace _) {}));
    return preparation;
  }

  void _cancelFrameRatePreparation() {
    _frameRateBindingGeneration++;
    _frameRatePreparationPending = false;
    final cancelled = _frameRatePreparationCancelled;
    _frameRatePreparationCancelled = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }

  Future<void> _configureFrameRate(Future<void> cancelled) async {
    final controller = widget.frameRateSettingsController;
    final bindingEpoch = _bindingEpoch;
    final generation = ++_frameRateBindingGeneration;
    final orchestrator = _bindings.startupOrchestrator;
    bool isActive() =>
        generation == _frameRateBindingGeneration &&
        _isCurrentBinding(bindingEpoch, orchestrator);
    await WidgetsBinding.instance.endOfFrame;
    if (!isActive()) throw const GameFrameRateConfigurationCancelledException();
    final port =
        widget.frameRatePortFactory?.call() ??
        (_webViewController.platform is AndroidWebViewController
            ? MethodChannelGameFrameRatePort(
                isActive: isActive,
                cancelled: cancelled,
              )
            : const UnsupportedGameFrameRatePort());
    var supported = false;
    if (port is UnsupportedGameFrameRatePort) {
      // Keep non-Android implementations on their existing platform path.
      if (controller == null) return;
      supported = await orchestrator.attachFrameRatePlatformPort();
    } else if (controller != null) {
      supported = await controller.attachPortForStartup(
        port,
        cancelled: cancelled,
        isActive: isActive,
      );
    } else {
      try {
        // Both Android bridges inspect the same native view tree. This real
        // frame-rate installation acknowledges that the one WebView is mounted;
        // a Flutter frame ending alone does not. Keep this once per binding,
        // before the frame-reload bridge and first navigation, even when no
        // settings controller was supplied by an embedder.
        await port.configure(GameFrameRateMode.automatic);
        supported = true;
      } on PlatformException catch (error) {
        if (error.code != 'frame_rate_unsupported') rethrow;
        supported = false;
      }
    }
    if (!isActive()) throw const GameFrameRateConfigurationCancelledException();
    if (!supported || controller == null) return;
    final runtimeController = GameFrameRateRuntimeController(
      settings: controller,
      port: createGameFrameRateRuntimePort(_webViewController),
    );
    _frameRateRuntimeController = runtimeController;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null) {
      runtimeController.onLifecycleChanged(lifecycleState);
    }
  }

  bool _isCurrentBinding(
    int epoch,
    GameSurfaceStartupOrchestrator orchestrator,
  ) {
    return mounted &&
        !_disposed &&
        epoch == _bindingEpoch &&
        identical(orchestrator, _bindings.startupOrchestrator);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final isLocalDocument =
        widget.browserController.mode == GameBrowserMode.localPrototype &&
        (uri?.scheme == 'about' || uri?.scheme == 'data');
    if (isLocalDocument ||
        (uri != null && _navigationPolicy.canNavigate(uri))) {
      return NavigationDecision.navigate;
    }

    widget.browserController.onBlockedNavigation(uri ?? Uri(scheme: 'invalid'));
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildWebView(),
        if (_startupState != GameStartupState.ready)
          Container(
            color: appColor(context, Color(0xff102431)),
            child: Center(child: _buildStartupOverlay()),
          ),
      ],
    );
  }

  Widget _buildWebView() {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(
          controller: _webViewController.platform,
        );
    if (_webViewController.platform is AndroidWebViewController) {
      params =
          AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
            params,
            displayWithHybridComposition:
                widget.renderingMode.usesHybridComposition,
          );
    }
    final view = WebViewWidget.fromPlatformCreationParams(
      key: const Key('game-webview'),
      params: params,
    );
    final wheel = widget.mouseWheelSettingsController;
    final platform = _webViewController.platform;
    if (wheel == null || platform is! AndroidWebViewController) return view;
    return AnimatedBuilder(
      animation: wheel,
      child: view,
      builder: (context, child) => GameMouseWheelRegion(
        enabled: wheel.enabled,
        onScroll: (input) {
          unawaited(_forwardMouseWheel(platform.webViewIdentifier, input));
        },
        child: child!,
      ),
    );
  }

  Future<void> _forwardMouseWheel(
    int webViewId,
    GameMouseWheelInput input,
  ) async {
    if (_disposed || widget.mouseWheelSettingsController?.enabled != true) {
      return;
    }
    try {
      await const MethodChannel(
        'app.yahagi.kancollebrowser/game_mouse_wheel',
      ).invokeMethod<bool>('scroll', <String, Object>{
        'webViewId': webViewId,
        'x': input.xRatio,
        'y': input.yRatio,
        'deltaX': input.deltaX,
        'deltaY': input.deltaY,
      });
    } on PlatformException catch (error) {
      debugPrint('Mouse wheel compatibility unavailable: ${error.code}');
    } on MissingPluginException {
      // An older host can still provide its normal input behavior.
    }
  }

  Widget _buildStartupOverlay() {
    if (_startupState == GameStartupState.error) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: appColor(context, Colors.redAccent),
            size: 48,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              runtimeMessageText(context, _startupErrorMessage),
              style: TextStyle(
                color: appColor(context, Colors.redAccent),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            key: const Key('game-webview-page-reload'),
            onPressed: _retryInProgress ? null : () => unawaited(_retryPage()),
            icon: const Icon(Icons.refresh),
            label: Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh')))
                  .reloadGame,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              unawaited(_retryWithSystemNetwork());
            },
            icon: const Icon(Icons.public),
            label: Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh')))
                  .retryWithSystemNetwork,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: appColor(context, Color(0xff183631)),
              foregroundColor: appColor(context, Color(0xff80c8bd)),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: appColor(context, Color(0xffd4a85f))),
        const SizedBox(height: 24),
        Text(
          runtimeMessageText(context, _getStartupStatusText()),
          style: TextStyle(
            color: appColor(context, Color(0xff8197a5)),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Future<void> _retryWithSystemNetwork() async {
    if (_retryInProgress) return;
    _retryInProgress = true;
    try {
      await _startupCoordinator.waitForStage(
        widget.networkSettingsController.applySettings(
          NetworkMode.system,
          '',
          8099,
        ),
      );
      if (!mounted || _disposed) return;
      _emitLoadEvent(GameLoadPhase.retry);
      _renewFrameRatePreparation();
      await _executeStartupSequence(retryNavigation: true);
    } catch (error, stackTrace) {
      debugPrint('Game WebView network retry failed: $error\n$stackTrace');
      if (mounted && !_disposed) {
        _reportRecoverableError('网络重试失败：$error');
      }
    } finally {
      if (mounted && !_disposed) setState(() => _retryInProgress = false);
    }
  }

  Future<void> _retryPage() async {
    if (_retryInProgress || _disposed || !mounted) return;
    setState(() => _retryInProgress = true);
    _emitLoadEvent(GameLoadPhase.retry);
    try {
      _renewFrameRatePreparation();
      await _executeStartupSequence(retryNavigation: true);
    } finally {
      if (mounted && !_disposed) setState(() => _retryInProgress = false);
    }
  }

  void _renewFrameRatePreparation() {
    _frameRateRuntimeController?.dispose();
    _frameRateRuntimeController = null;
    _frameRateReady = _startFrameRatePreparation();
  }

  String _getStartupStatusText() {
    switch (_startupState) {
      case GameStartupState.loadingSettings:
        return '正在读取配置...';
      case GameStartupState.applyingNetwork:
        return '正在应用网络设置...';
      case GameStartupState.networkReady:
        return '网络配置完毕，准备加载游戏...';
      case GameStartupState.loadingGame:
        return _documentFinished &&
                _presentationState == GamePresentationState.pending
            ? '正在等待游戏本体...'
            : '正在加载游戏页面...';
      default:
        return '准备就绪...';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelFrameRatePreparation();
    widget.toolbarController.onStageChanged(GameSurfaceStage.login);
    _startupEpoch += 1;
    _bindingEpoch += 1;
    _navigationEpoch += 1;
    _navigationWatchdog.dispose();
    _captureUpdates.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _frameRateRuntimeController?.dispose();
    unawaited(_bindings.dispose());
    unawaited(
      _disableWebViewController(
        _webViewController,
        _startupCoordinator.stageTimeout,
      ),
    );
    super.dispose();
  }
}

Future<void> _disableWebViewController(
  WebViewController controller,
  Duration timeout,
) async {
  try {
    await controller
        .setJavaScriptMode(JavaScriptMode.disabled)
        .timeout(timeout);
    await controller
        .loadHtmlString('<!DOCTYPE html><html><body></body></html>')
        .timeout(timeout);
  } catch (error, stackTrace) {
    debugPrint('Game WebView shutdown failed: $error\n$stackTrace');
  }
}

final class WebViewGameBrowserPort implements GameBrowserPort {
  WebViewGameBrowserPort(
    this.controller,
    this.localHomeHtml, {
    required this.gameFrameReloadPort,
    Future<void>? compatibilityReady,
    this.waitForSurfaceReady,
    this.isActive,
    this.prepareForRealNavigation,
    required this.synchronizeGamePresentation,
    this.beforeNavigation,
  }) : compatibilityReady = compatibilityReady ?? Future<void>.value();

  final WebViewController controller;
  final String localHomeHtml;
  final GameFrameReloadPort gameFrameReloadPort;
  final Future<void> compatibilityReady;
  final Future<void> Function()? waitForSurfaceReady;
  final bool Function()? isActive;
  final Future<void> Function()? prepareForRealNavigation;
  final Future<void> Function() synchronizeGamePresentation;
  final void Function(Uri? uri)? beforeNavigation;

  Future<void> configureFrameReload() async {
    await waitForSurfaceReady?.call();
    _ensureActive();
    await gameFrameReloadPort.configure();
    _ensureActive();
  }

  void _ensureActive() {
    if (isActive?.call() == false) {
      throw const GameFrameRateConfigurationCancelledException();
    }
  }

  @override
  Future<bool> canGoBack() => controller.canGoBack();

  @override
  Future<void> goBack() async {
    await configureFrameReload();
    beforeNavigation?.call(null);
    await controller.goBack();
  }

  @override
  Future<void> loadUri(Uri uri) async {
    await compatibilityReady;
    await configureFrameReload();
    await prepareForRealNavigation?.call();
    _ensureActive();
    beforeNavigation?.call(uri);
    await controller.loadRequest(uri);
  }

  @override
  Future<void> reload() async {
    await configureFrameReload();
    beforeNavigation?.call(null);
    await controller.reload();
  }

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async {
    await configureFrameReload();
    return gameFrameReloadPort.reload();
  }

  @override
  Future<void> showLocalHome() async {
    await configureFrameReload();
    beforeNavigation?.call(null);
    await controller.loadHtmlString(localHomeHtml);
  }

  @override
  Future<void> runJavaScript(String javascript) =>
      controller.runJavaScript(javascript);

  @override
  Future<void> fitGameScreen() => synchronizeGamePresentation();

  @override
  Future<void> clearCache() => controller.clearCache();

  @override
  Future<void> clearSession() async {
    await WebViewCookieManager().clearCookies();
    await controller.clearLocalStorage();
    await controller.clearCache();
  }
}

final class _AndroidWebViewCompatibilityPort
    implements GameWebViewCompatibilityPort {
  const _AndroidWebViewCompatibilityPort({
    required this.controller,
    required this.cookieManager,
  });

  final AndroidWebViewController controller;
  final AndroidWebViewCookieManager cookieManager;

  @override
  Future<void> allowThirdPartyCookies() {
    return cookieManager.setAcceptThirdPartyCookies(controller, true);
  }

  @override
  Future<void> setUserAgent(String userAgent) {
    return controller.setUserAgent(userAgent);
  }
}
