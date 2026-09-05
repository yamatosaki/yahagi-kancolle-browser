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
  bool _audioPortAttached = false;
  bool _disposed = false;
  int _captureRevision = 0;
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
        if (isActive()) await prepareCapture();
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
    while (!_disposed) {
      final revision = _captureRevision;
      final enabled = captureModeController.mode.installsGameBridge;
      final script = nativeGameCaptureScript;
      if (!_capturePortAttached) {
        await gameCaptureController.attach(
          _gameCapturePort,
          enabled: enabled,
          script: script,
        );
        if (_disposed) return;
        _capturePortAttached = true;
      } else {
        await gameCaptureController.configure(enabled: enabled, script: script);
      }
      if (revision == _captureRevision) return;
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
    this.renderingMode = GameRenderingMode.compatibility,
    this.startupTimeout,
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
  final GameRenderingMode renderingMode;
  final Duration? startupTimeout;

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
  final GameWebViewPageReadiness _pageReadiness = GameWebViewPageReadiness();
  late CaptureMode _activeCaptureMode;
  GameFrameRateRuntimeController? _frameRateRuntimeController;
  static const _scaleChannel = MethodChannel(
    'app.webview/fixed_canvas_scaling',
  );

  int _navigationEpoch = 0;
  int _startupEpoch = 0;
  int _bindingEpoch = 0;
  bool _disposed = false;

  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  void _onNetworkSettingsChanged() {
    if (!mounted || _disposed) return;
    if (_startupState == GameStartupState.error) {
      _scheduleStartupSequence();
    }
  }

  void _handleCaptureModeChanged() {
    _onCaptureModeChanged();
  }

  GameSurfaceStartupOrchestrator _createStartupOrchestrator(
    GameWebView config,
  ) {
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
    WidgetsBinding.instance.addObserver(this);
    _activeCaptureMode = widget.captureModeController.mode;
    _webViewController = WebViewController();
    _compatibilityReady = _configureCompatibility();
    _browserPort = WebViewGameBrowserPort(
      _webViewController,
      gameLocalHomeHtml,
      gameFrameReloadPort: MethodChannelGameFrameReloadPort(),
      compatibilityReady: _compatibilityReady,
      prepareForRealNavigation: _prepareCapture,
      synchronizeGamePresentation: _synchronizeGamePresentation,
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
    _frameRateReady = _configureFrameRate();

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
          final state = decodeGamePresentationState(message.message);
          if (state == null || state == GamePresentationState.pending) return;
          // Re-read the current document instead of trusting a possibly stale
          // message that was queued immediately before a navigation.
          _synchronizeGamePresentation().catchError((Object _) {});
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (url) {
            _startupCoordinator.acknowledgeNavigation(Uri.tryParse(url));
            _pageReadiness.pageStarted();
            _navigationPolicy.onPageStarted(Uri.tryParse(url));
            _navigationEpoch += 1;
            _frameRateRuntimeController?.onPageStarted();
            widget.controller.onPageStarted(url);
            widget.browserController.onPageStarted(url);
            widget.toolbarController.onStageChanged(
              widget.browserController.mode == GameBrowserMode.localPrototype
                  ? GameSurfaceStage.localPrototype
                  : GameSurfaceStage.login,
            );
            if (_startupState == GameStartupState.networkReady) {
              setState(() => _startupState = GameStartupState.loadingGame);
            }
          },
          onPageFinished: (url) async {
            await _finishPage(url);
          },
          onWebResourceError: (error) {
            final isForMainFrame = error.isForMainFrame ?? true;
            if (isForMainFrame) {
              _pageReadiness.pageStarted();
              widget.controller.onWebResourceError(error.description);
              // Check if it's an SSL error (usually -11 on Android, but flutter maps to description)
              if (error.description.toLowerCase().contains('ssl') ||
                  error.description.toLowerCase().contains('cert')) {
                widget.browserController.onWebResourceError(
                  description: '安全证书错误：可能是岛风GO证书未受信任或网络被劫持。',
                  isForMainFrame: isForMainFrame,
                );
                return;
              }
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

    if (!identical(
      oldWidget.frameRateSettingsController,
      widget.frameRateSettingsController,
    )) {
      _frameRateRuntimeController?.dispose();
      _frameRateRuntimeController = null;
      _frameRateReady = _configureFrameRate();
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
    _frameRateRuntimeController?.onLifecycleChanged(state);
  }

  Future<void> _executeStartupSequence() {
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
  }) async {
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

      setState(() => _startupState = GameStartupState.networkReady);

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
            await _startupCoordinator.navigateOnce(
              initialAddress,
              () => _webViewController.loadRequest(initialAddress),
            );
          },
        ),
      );
      if (_isCurrentStartup(startupEpoch, orchestrator) &&
          _pageReadiness.isReady) {
        await _startupCoordinator.waitForStage(
          orchestrator.attachAudioPortOnce(),
        );
        if (_isCurrentStartup(startupEpoch, orchestrator)) {
          setState(() => _startupState = GameStartupState.ready);
        }
      }
    } catch (error, stackTrace) {
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
    try {
      widget.controller.onPageFinished(url);
      widget.browserController.onPageFinished(url);

      await _startupCoordinator.waitForStage(_synchronizeGamePresentation());
      if (!_isCurrentNavigation(navigationEpoch)) return;
      await _startupCoordinator.waitForStage(_prepareCapture());
      if (!_isCurrentNavigation(navigationEpoch)) return;
      await _startupCoordinator.waitForStage(_attachAudioPortOnce());
      if (!_isCurrentNavigation(navigationEpoch)) return;

      _pageReadiness.pageFinished();
      if (_startupState == GameStartupState.loadingGame) {
        setState(() => _startupState = GameStartupState.ready);
      }
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
      if (_isCurrentNavigation(navigationEpoch)) {
        _reportRecoverableError('游戏页面准备失败：$error');
      }
    }
  }

  Future<void> _synchronizeGamePresentation() async {
    final navigationEpoch = _navigationEpoch;
    final gameSurfaceResult = await _startupCoordinator.waitForStage(
      _webViewController.runJavaScriptReturningResult(gamePageAlignmentScript),
    );
    if (!_isCurrentNavigation(navigationEpoch)) return;
    await _applyGamePresentation(
      decodeGamePresentationState(gameSurfaceResult),
      navigationEpoch,
    );
  }

  Future<void> _applyGamePresentation(
    GamePresentationState? state,
    int navigationEpoch,
  ) async {
    if (!_isCurrentNavigation(navigationEpoch)) return;
    final action = state?.platformAction ?? GamePresentationPlatformAction.none;
    if (action == GamePresentationPlatformAction.none) return;
    if (_webViewController.platform is AndroidWebViewController) {
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
    if (state == GamePresentationState.game) {
      await _startupCoordinator.waitForStage(
        _webViewController.runJavaScript('''
          if (window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();
        '''),
      );
    }
  }

  bool _isCurrentNavigation(int epoch) => mounted && epoch == _navigationEpoch;

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
        reload: _webViewController.reload,
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

  Future<void> _configureFrameRate() async {
    final controller = widget.frameRateSettingsController;
    if (controller == null) return;
    final bindingEpoch = _bindingEpoch;
    final orchestrator = _bindings.startupOrchestrator;
    await WidgetsBinding.instance.endOfFrame;
    if (!_isCurrentBinding(bindingEpoch, orchestrator)) return;
    try {
      final supported = await orchestrator.attachFrameRatePlatformPort();
      if (!_isCurrentBinding(bindingEpoch, orchestrator)) return;
      if (!supported) return;
      final runtimeController = GameFrameRateRuntimeController(
        settings: controller,
        port: createGameFrameRateRuntimePort(_webViewController),
      );
      _frameRateRuntimeController = runtimeController;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState != null) {
        runtimeController.onLifecycleChanged(lifecycleState);
      }
    } catch (error, stackTrace) {
      debugPrint('Frame-rate runtime unavailable: $error\n$stackTrace');
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
            color: const Color(0xff102431),
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
    return WebViewWidget.fromPlatformCreationParams(
      key: const Key('game-webview'),
      params: params,
    );
  }

  Widget _buildStartupOverlay() {
    if (_startupState == GameStartupState.error) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              runtimeMessageText(context, _startupErrorMessage),
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
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
              backgroundColor: const Color(0xff183631),
              foregroundColor: const Color(0xff80c8bd),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Color(0xffd4a85f)),
        const SizedBox(height: 24),
        Text(
          runtimeMessageText(context, _getStartupStatusText()),
          style: const TextStyle(color: Color(0xff8197a5), fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _retryWithSystemNetwork() async {
    try {
      await _startupCoordinator.waitForStage(
        widget.networkSettingsController.applySettings(
          NetworkMode.system,
          '',
          8099,
        ),
      );
      if (!mounted || _disposed) return;
      await _executeStartupSequence();
    } catch (error, stackTrace) {
      debugPrint('Game WebView network retry failed: $error\n$stackTrace');
      if (mounted && !_disposed) {
        _reportRecoverableError('网络重试失败：$error');
      }
    }
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
        return '正在加载游戏页面...';
      default:
        return '准备就绪...';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _startupEpoch += 1;
    _bindingEpoch += 1;
    _navigationEpoch += 1;
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
    this.prepareForRealNavigation,
    required this.synchronizeGamePresentation,
  }) : compatibilityReady = compatibilityReady ?? Future<void>.value();

  final WebViewController controller;
  final String localHomeHtml;
  final GameFrameReloadPort gameFrameReloadPort;
  final Future<void> compatibilityReady;
  final Future<void> Function()? prepareForRealNavigation;
  final Future<void> Function() synchronizeGamePresentation;

  Future<void> configureFrameReload() => gameFrameReloadPort.configure();

  @override
  Future<bool> canGoBack() => controller.canGoBack();

  @override
  Future<void> goBack() => controller.goBack();

  @override
  Future<void> loadUri(Uri uri) async {
    await compatibilityReady;
    await gameFrameReloadPort.configure();
    await prepareForRealNavigation?.call();
    await controller.loadRequest(uri);
  }

  @override
  Future<void> reload() => controller.reload();

  @override
  Future<GameFrameReloadResult> reloadGameFrame() =>
      gameFrameReloadPort.reload();

  @override
  Future<void> showLocalHome() => controller.loadHtmlString(localHomeHtml);

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
