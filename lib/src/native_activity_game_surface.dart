import 'theme/app_palette.dart';
import 'localization/runtime_message_text.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/game_audio_controller.dart';
import 'browser/game_browser_controller.dart';
import 'browser/game_frame_rate_policy.dart';
import 'browser/game_frame_rate_port.dart';
import 'browser/game_frame_rate_runtime_controller.dart';
import 'browser/game_initial_address.dart';
import 'browser/game_load_event.dart';
import 'browser/game_navigation_watchdog.dart';
import 'browser/game_frame_reload_port.dart';
import 'browser/game_toolbar_controller.dart';
import 'browser/native_game_surface_preview.dart';
import 'browser/native_game_surface_slot.dart';
import 'browser/native_game_webview_contract.dart';
import 'browser/native_game_webview_port.dart';
import 'capture/capture_mode.dart';
import 'capture/capture_mode_controller.dart';
import 'capture/game_capture_controller.dart';
import 'game_webview.dart';
import 'layout/window_metrics_recovery_scheduler.dart';
import 'prototype_status_controller.dart';
import 'settings/game_frame_rate_settings.dart';
import 'settings/network_settings_controller.dart';
import 'settings/network_settings_store.dart';

abstract interface class NativeActivityGameWebViewPort
    implements GameBrowserPort {
  Stream<NativeGameWebViewEvent> get events;

  Future<int> create();

  Future<void> setBounds(NativeGameWebViewBounds bounds);

  Future<void> setVisible(bool visible);

  Future<void> dispose();
}

String nativeWebViewStartupErrorMessage(Object error) {
  if (error is! PlatformException) {
    return '原生 WebView 启动失败：${error.runtimeType}';
  }
  final details = error.details;
  final stage = details is Map ? details['stage'] : null;
  final exceptionType = details is Map ? details['exceptionType'] : null;
  final location = stage is String && stage.isNotEmpty
      ? '${error.code}/$stage'
      : error.code;
  final cause = exceptionType is String && exceptionType.isNotEmpty
      ? ' ($exceptionType)'
      : '';
  return '原生 WebView 启动失败 [$location]$cause';
}

final class MethodChannelNativeActivityGameWebViewPort
    implements NativeActivityGameWebViewPort {
  MethodChannelNativeActivityGameWebViewPort({
    MethodChannelNativeGameWebViewPort? delegate,
    GameFrameReloadPort? frameReloadPort,
  }) : _delegate = delegate ?? MethodChannelNativeGameWebViewPort(),
       _frameReloadPort = frameReloadPort ?? MethodChannelGameFrameReloadPort();

  final MethodChannelNativeGameWebViewPort _delegate;
  final GameFrameReloadPort _frameReloadPort;

  @override
  Stream<NativeGameWebViewEvent> get events => _delegate.events;

  @override
  Future<int> create() => _delegate.create();

  @override
  Future<void> setBounds(NativeGameWebViewBounds bounds) =>
      _delegate.setBounds(bounds);

  @override
  Future<void> setVisible(bool visible) => _delegate.setVisible(visible);

  @override
  Future<void> loadUri(Uri uri) async {
    await _frameReloadPort.configure();
    await _delegate.loadUri(uri);
  }

  @override
  Future<void> showLocalHome() => _delegate.showLocalHome();

  @override
  Future<void> reload() => _delegate.reload();

  @override
  Future<GameFrameReloadResult> reloadGameFrame() => _frameReloadPort.reload();

  @override
  Future<bool> canGoBack() => _delegate.canGoBack();

  @override
  Future<void> goBack() => _delegate.goBack();

  @override
  Future<void> runJavaScript(String javascript) =>
      _delegate.runJavaScript(javascript);

  @override
  Future<void> fitGameScreen() => _delegate.fitGameScreen();

  @override
  Future<void> clearCache() => _delegate.clearCache();

  @override
  Future<void> clearSession() => _delegate.clearSession();

  @override
  Future<void> dispose() => _delegate.dispose();
}

final class _BoundsRecoveringNativeActivityGameWebViewPort
    implements NativeActivityGameWebViewPort {
  _BoundsRecoveringNativeActivityGameWebViewPort({
    required this.delegate,
    required this.recoverBounds,
  });

  final NativeActivityGameWebViewPort delegate;
  final Future<bool> Function() recoverBounds;

  @override
  Stream<NativeGameWebViewEvent> get events => delegate.events;

  @override
  Future<int> create() => delegate.create();

  @override
  Future<void> setBounds(NativeGameWebViewBounds bounds) =>
      delegate.setBounds(bounds);

  @override
  Future<void> setVisible(bool visible) => delegate.setVisible(visible);

  @override
  Future<void> loadUri(Uri uri) => delegate.loadUri(uri);

  @override
  Future<void> showLocalHome() => delegate.showLocalHome();

  @override
  Future<void> reload() => delegate.reload();

  @override
  Future<GameFrameReloadResult> reloadGameFrame() => delegate.reloadGameFrame();

  @override
  Future<bool> canGoBack() => delegate.canGoBack();

  @override
  Future<void> goBack() => delegate.goBack();

  @override
  Future<void> runJavaScript(String javascript) =>
      delegate.runJavaScript(javascript);

  @override
  Future<void> fitGameScreen() async {
    if (!await recoverBounds()) return;
    await delegate.fitGameScreen();
  }

  @override
  Future<void> clearCache() => delegate.clearCache();

  @override
  Future<void> clearSession() => delegate.clearSession();

  @override
  Future<void> dispose() => delegate.dispose();
}

typedef NativeActivityGameWebViewPortFactory =
    NativeActivityGameWebViewPort Function();
typedef NativeGameSurfacePreviewDecoder =
    Future<ImageProvider> Function(Uint8List bytes, BuildContext context);

final class _PendingPageFinish {
  const _PendingPageFinish({
    required this.port,
    required this.generationId,
    required this.operationEpoch,
    required this.pageEpoch,
    required this.url,
  });

  final NativeActivityGameWebViewPort port;
  final int generationId;
  final int operationEpoch;
  final int pageEpoch;
  final String url;
}

final class _PageInitializationFailure implements Exception {
  const _PageInitializationFailure({
    required this.stage,
    required this.cause,
    required this.stackTrace,
  });

  final String stage;
  final Object cause;
  final StackTrace stackTrace;
}

final class NativeActivityGameSurface extends StatefulWidget {
  NativeActivityGameSurface({
    required this.statusController,
    required this.browserController,
    required this.toolbarController,
    required this.routeObserver,
    this.onGenerationChanged,
    this.onRenderProcessGone,
    this.onLoadEvent,
    this.networkSettingsController,
    this.captureModeController,
    this.audioController,
    this.gameCaptureController,
    this.frameRateSettingsController,
    this.frameRateRuntimePortFactory,
    this.previewPort,
    this.previewDecoder,
    this.portFactory,
    this.startupOrchestrator,
    this.createTimeout = const Duration(seconds: 30),
    this.cleanupTimeout,
    this.pageInitializationTimeout,
    this.navigationTimeout = const Duration(seconds: 45),
    super.key,
  }) {
    if (startupOrchestrator == null &&
        (networkSettingsController == null ||
            captureModeController == null ||
            audioController == null ||
            gameCaptureController == null)) {
      throw ArgumentError(
        'Provide startupOrchestrator or all default orchestrator dependencies.',
      );
    }
  }

  final PrototypeStatusController statusController;
  final GameBrowserController browserController;
  final GameToolbarController toolbarController;
  final RouteObserver<ModalRoute<dynamic>> routeObserver;
  final void Function(int)? onGenerationChanged;
  final void Function(bool didCrash)? onRenderProcessGone;
  final void Function(GameLoadEvent event)? onLoadEvent;
  final NetworkSettingsController? networkSettingsController;
  final CaptureModeController? captureModeController;
  final GameAudioController? audioController;
  final GameCaptureController? gameCaptureController;
  final GameFrameRateSettingsController? frameRateSettingsController;
  final GameFrameRateRuntimePort Function()? frameRateRuntimePortFactory;
  final NativeGameSurfacePreviewPort? previewPort;
  final NativeGameSurfacePreviewDecoder? previewDecoder;
  final NativeActivityGameWebViewPortFactory? portFactory;
  final GameSurfaceStartupOrchestrator? startupOrchestrator;

  /// Loading the Android WebView provider has its own startup budget.
  /// It must not inherit the short deadline used to release native resources.
  final Duration createTimeout;
  final Duration? cleanupTimeout;
  final Duration? pageInitializationTimeout;
  final Duration navigationTimeout;

  @override
  State<NativeActivityGameSurface> createState() =>
      _NativeActivityGameSurfaceState();
}

final class _NativeActivityGameSurfaceState
    extends State<NativeActivityGameSurface>
    with WidgetsBindingObserver {
  NativeActivityGameWebViewPort? _port;
  StreamSubscription<NativeGameWebViewEvent>? _eventSubscription;
  late GameSurfaceStartupOrchestrator _startupOrchestrator;
  late Duration _cleanupTimeout;
  late Duration _pageInitializationTimeout;
  late final Future<void> Function(NativeGameWebViewBounds) _boundsSink;
  late final Future<void> Function(bool) _visibilitySink;
  final GlobalKey _surfaceSlotKey = GlobalKey(
    debugLabel: 'native-game-surface-slot',
  );
  final WindowMetricsRecoveryScheduler _windowMetricsRecoveryScheduler =
      WindowMetricsRecoveryScheduler();
  final List<NativeGameWebViewEvent> _pendingEvents =
      <NativeGameWebViewEvent>[];

  int? _generationId;
  int _operationEpoch = 0;
  int _pageEpoch = 0;
  int _navigationEpoch = 0;
  late final GameNavigationWatchdog _documentWatchdog;
  late final GameNavigationWatchdog _bodyWatchdog;
  final Stopwatch _navigationElapsed = Stopwatch();
  GamePageCategory _pageCategory = GamePageCategory.other;
  NativeGamePresentationState? _presentationState;
  bool _navigationCommandPending = false;
  bool _documentFinished = false;
  int? _bodyDeadlineEpoch;
  NativeGameWebViewBounds? _latestBounds;
  bool _desiredVisible = false;
  bool _active = true;
  bool _fatal = false;
  bool _awaitingNewPageStart = false;
  bool _networkRetryAvailable = false;
  Future<void>? _networkRetryFuture;
  Future<void>? _visibilitySyncFuture;
  Future<void>? _captureReconfigureFuture;
  int _captureRevision = 0;
  int _visibilityRevision = 0;
  int _processedVisibilityRevision = 0;
  bool _actualVisible = false;
  bool _forceVisibilityWrite = false;
  bool _navigationIssued = false;
  bool _navigationAcknowledged = false;
  bool _automaticRecoveryReloadUsed = false;
  bool _pageReloadAvailable = false;
  Uri? _navigationTarget;
  Uri? _currentDocumentUri;
  bool _pageReady = false;
  bool _renderProcessRecoveryAvailable = false;
  String? _lastFinishedPageUrl;
  GameFrameRateRuntimeController? _frameRateRuntimeController;
  Future<void>? _navigationFuture;
  Future<void>? _bootstrapTail;
  Future<void>? _pageFinishFuture;
  _PendingPageFinish? _pendingPageFinish;
  AppLifecycleState? _appLifecycleState;
  bool _visibilityFatalCleanupStarted = false;
  bool _createTimeoutCleanupStarted = false;
  int _processedCaptureRevision = 0;
  CaptureMode? _activeCaptureMode;
  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';
  ImageProvider? _popupPreview;
  int _popupPreviewGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boundsSink = _onBoundsChanged;
    _visibilitySink = _onVisibilityChanged;
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    _documentWatchdog = GameNavigationWatchdog(onTimeout: _onDocumentTimeout);
    _bodyWatchdog = GameNavigationWatchdog(onTimeout: _onBodyTimeout);
    final foreground = _appLifecycleState == AppLifecycleState.resumed;
    _documentWatchdog.setForeground(foreground);
    _bodyWatchdog.setForeground(foreground);
    _cleanupTimeout = widget.cleanupTimeout ?? const Duration(seconds: 2);
    _pageInitializationTimeout =
        widget.pageInitializationTimeout ?? const Duration(seconds: 10);
    _startupOrchestrator = _createStartupOrchestrator(widget);
    _activeCaptureMode = widget.captureModeController?.mode;
    widget.networkSettingsController?.addListener(_onNetworkSettingsChanged);
    widget.captureModeController?.addListener(_onCaptureModeChanged);

    final delegate = widget.portFactory?.call() ?? _createDefaultPort();
    final port = delegate == null
        ? null
        : _BoundsRecoveringNativeActivityGameWebViewPort(
            delegate: delegate,
            recoverBounds: _synchronizeNativeBounds,
          );
    _port = port;
    if (port == null) {
      _startupState = GameStartupState.error;
      _startupErrorMessage = '原生 Activity WebView 仅支持 Android。';
      return;
    }
    _eventSubscription = port.events.listen(
      _onEvent,
      onError: _onEventError,
      onDone: _onEventDone,
    );
    unawaited(_start(port));
  }

  GameSurfaceStartupOrchestrator _createStartupOrchestrator(
    NativeActivityGameSurface configuration,
  ) {
    return configuration.startupOrchestrator ??
        DefaultGameSurfaceStartupOrchestrator(
          networkSettingsController: configuration.networkSettingsController!,
          captureModeController: configuration.captureModeController!,
          audioController: configuration.audioController!,
          gameCaptureController: configuration.gameCaptureController!,
          frameRateSettingsController:
              configuration.frameRateSettingsController,
        );
  }

  @override
  void didUpdateWidget(covariant NativeActivityGameSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cleanupTimeout = widget.cleanupTimeout ?? const Duration(seconds: 2);
    _pageInitializationTimeout =
        widget.pageInitializationTimeout ?? const Duration(seconds: 10);

    if (!identical(
      oldWidget.networkSettingsController,
      widget.networkSettingsController,
    )) {
      oldWidget.networkSettingsController?.removeListener(
        _onNetworkSettingsChanged,
      );
      widget.networkSettingsController?.addListener(_onNetworkSettingsChanged);
    }
    if (!identical(
      oldWidget.captureModeController,
      widget.captureModeController,
    )) {
      oldWidget.captureModeController?.removeListener(_onCaptureModeChanged);
      widget.captureModeController?.addListener(_onCaptureModeChanged);
      _activeCaptureMode = widget.captureModeController?.mode;
    }
    final port = _port;
    if (!identical(oldWidget.browserController, widget.browserController) &&
        port != null &&
        _generationId != null) {
      oldWidget.browserController.detachPort(port);
      widget.browserController.attachPort(port);
    }

    if (_startupDependenciesChanged(oldWidget, widget)) {
      final previous = _startupOrchestrator;
      _frameRateRuntimeController?.dispose();
      _frameRateRuntimeController = null;
      _invalidateOperations(fatal: false);
      _startupOrchestrator = _createStartupOrchestrator(widget);
      unawaited(
        _disposeStartupOrchestrator(previous, timeout: _cleanupTimeout),
      );
      final generationId = _generationId;
      if (port != null && generationId != null) {
        unawaited(
          _schedulePostCreateBootstrap(
            port,
            generationId,
            _operationEpoch,
          ).catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              'Native game surface bootstrap scheduling failed: '
              '$error\n$stackTrace',
            );
          }),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    final foreground = state == AppLifecycleState.resumed;
    _documentWatchdog.setForeground(foreground);
    _bodyWatchdog.setForeground(foreground);
    _frameRateRuntimeController?.onLifecycleChanged(state);
    if (state == AppLifecycleState.resumed) {
      _ensurePageFinish();
      _windowMetricsRecoveryScheduler.schedule(() {
        final port = _port;
        if (!_active ||
            !mounted ||
            _appLifecycleState != AppLifecycleState.resumed ||
            port == null ||
            _generationId == null) {
          return;
        }
        if (_pendingPageFinish != null || _pageFinishFuture != null) {
          return;
        }
        unawaited(
          port.fitGameScreen().catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            debugPrint(
              'Native game surface resume recovery failed: '
              '$error\n$stackTrace',
            );
          }),
        );
      });
    } else {
      _windowMetricsRecoveryScheduler.cancel();
    }
  }

  void _startNavigationDeadline(Uri? uri, {bool command = false}) {
    if (command || !_navigationCommandPending) {
      _navigationEpoch += 1;
      _navigationElapsed
        ..reset()
        ..start();
      _emitLoadEvent(
        GameLoadPhase.navigationStarted,
        category: classifyGamePage(uri),
      );
    }
    _navigationCommandPending = command;
    _pageCategory = classifyGamePage(uri);
    _presentationState = null;
    _documentFinished = false;
    _bodyWatchdog.cancel();
    _bodyDeadlineEpoch = null;
    _documentWatchdog.start(
      _navigationEpoch,
      timeout: widget.navigationTimeout,
    );
  }

  void _emitLoadEvent(
    GameLoadPhase phase, {
    GamePageCategory? category,
    int? errorCode,
    bool? isMainFrame,
  }) {
    if (!_active || !mounted) return;
    try {
      widget.onLoadEvent?.call(
        GameLoadEvent(
          phase: phase,
          navigationEpoch: _navigationEpoch,
          durationMs: _navigationElapsed.elapsedMilliseconds,
          pageCategory: category ?? _pageCategory,
          errorCode: errorCode,
          isMainFrame: isMainFrame,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Native game load observer failed: ${error.runtimeType}\n$stackTrace',
      );
    }
  }

  void _onDocumentTimeout(int epoch) {
    if (!_active || !mounted || _fatal || epoch != _navigationEpoch) return;
    _emitLoadEvent(GameLoadPhase.timedOut, isMainFrame: true);
    _reportPageError('游戏页面加载超时，请重试。', emitFailure: false);
  }

  void _onBodyTimeout(int epoch) {
    if (!_active ||
        !mounted ||
        _fatal ||
        epoch != _navigationEpoch ||
        !_isWaitingForBody) {
      return;
    }
    _emitLoadEvent(GameLoadPhase.timedOut, isMainFrame: false);
    _reportPageError('游戏本体加载超时，请重试。', emitFailure: false);
  }

  bool get _isWaitingForBody =>
      _presentationState == NativeGamePresentationState.pending ||
      (_documentFinished &&
          _presentationState == null &&
          (_pageCategory == GamePageCategory.gameEntry ||
              _pageCategory == GamePageCategory.gameServer));

  void _updatePresentationReadiness() {
    if (_isWaitingForBody) {
      if (_documentFinished && _bodyDeadlineEpoch != _navigationEpoch) {
        _bodyDeadlineEpoch = _navigationEpoch;
        if (_presentationState == null) {
          _emitLoadEvent(GameLoadPhase.bodyWaiting);
        }
        _bodyWatchdog.start(
          _navigationEpoch,
          timeout: widget.navigationTimeout,
        );
      }
      _setStartupState(GameStartupState.loadingGame);
    } else {
      _bodyWatchdog.complete(_navigationEpoch);
      _bodyDeadlineEpoch = null;
      if (_pageReady) _setStartupState(GameStartupState.ready);
    }
  }

  Future<bool> _synchronizeNativeBounds() async {
    if (!_active || !mounted) return false;
    final port = _port;
    final operationEpoch = _operationEpoch;
    final generationId = _generationId;
    if (port == null || generationId == null) return false;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (!_matchesGeneration(port, generationId, operationEpoch)) return false;
    final slotContext = _surfaceSlotKey.currentContext;
    if (slotContext == null || !slotContext.mounted) return false;
    final bounds = readNativeGameSurfaceBounds(
      slotContext.findRenderObject(),
      devicePixelRatio: View.of(slotContext).devicePixelRatio,
    );
    if (bounds == null) return false;
    await _onBoundsChanged(bounds);
    return _matchesGeneration(port, generationId, operationEpoch);
  }

  bool _startupDependenciesChanged(
    NativeActivityGameSurface previous,
    NativeActivityGameSurface next,
  ) {
    if (!identical(previous.startupOrchestrator, next.startupOrchestrator)) {
      return true;
    }
    if (next.startupOrchestrator != null) return false;
    return !identical(
          previous.networkSettingsController,
          next.networkSettingsController,
        ) ||
        !identical(
          previous.captureModeController,
          next.captureModeController,
        ) ||
        !identical(previous.audioController, next.audioController) ||
        !identical(
          previous.gameCaptureController,
          next.gameCaptureController,
        ) ||
        !identical(
          previous.frameRateSettingsController,
          next.frameRateSettingsController,
        );
  }

  NativeActivityGameWebViewPort? _createDefaultPort() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    return MethodChannelNativeActivityGameWebViewPort();
  }

  Future<void> _start(NativeActivityGameWebViewPort port) async {
    final operationEpoch = _operationEpoch;
    var creating = true;
    _startupState = GameStartupState.applyingNetwork;
    try {
      final generationId = await port.create().timeout(widget.createTimeout);
      creating = false;
      if (!_matchesAttempt(port, operationEpoch)) return;
      _generationId = generationId;
      widget.onGenerationChanged?.call(generationId);
      widget.browserController.attachPort(port);
      _replayPendingEvents(port, generationId);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      await _schedulePostCreateBootstrap(port, generationId, operationEpoch);
    } catch (error, stackTrace) {
      debugPrint('Native game surface startup failed: $error\n$stackTrace');
      if (_matchesAttempt(port, operationEpoch)) {
        if (creating && error is TimeoutException) {
          _retireTimedOutCreate(port);
        }
        if (_active && mounted) {
          _setFatalError(nativeWebViewStartupErrorMessage(error));
        }
      }
    }
  }

  void _retireTimedOutCreate(NativeActivityGameWebViewPort port) {
    if (_createTimeoutCleanupStarted || !identical(_port, port)) {
      return;
    }
    _createTimeoutCleanupStarted = true;
    _port = null;
    _generationId = null;
    _desiredVisible = false;
    _pendingEvents.clear();
    final subscription = _eventSubscription;
    _eventSubscription = null;
    try {
      widget.browserController.detachPort(port);
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface controller detach failed: $error\n$stackTrace',
      );
    }
    // Mark the underlying port disposed while create may still be pending.
    // Its late generation is then destroyed instead of becoming attachable.
    final nativeCleanup = _runBoundedCleanup(
      port.dispose,
      'destroy',
      timeout: _cleanupTimeout,
    );
    unawaited(
      Future.wait(<Future<void>>[
        nativeCleanup,
        if (subscription != null)
          _runBoundedCleanup(
            subscription.cancel,
            'event cancellation',
            timeout: _cleanupTimeout,
          ),
        _disposeStartupOrchestrator(
          _startupOrchestrator,
          timeout: _cleanupTimeout,
        ),
      ]),
    );
  }

  Future<void> _schedulePostCreateBootstrap(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) {
    final previous = _bootstrapTail ?? Future<void>.value();
    final operation = previous
        .catchError((Object _, StackTrace _) {})
        .then<void>((_) {
          if (!_matchesGeneration(port, generationId, operationEpoch)) {
            return Future<void>.value();
          }
          return _runPostCreateBootstrap(port, generationId, operationEpoch);
        });
    _bootstrapTail = operation;
    return operation;
  }

  Future<void> _runPostCreateBootstrap(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) async {
    final orchestrator = _startupOrchestrator;
    try {
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      _setStartupState(GameStartupState.applyingNetwork);
      final bounds = _latestBounds;
      if (bounds != null) {
        await port.setBounds(bounds).timeout(_cleanupTimeout);
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      await _requestVisibility(force: true);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      var frameRateSupported = false;
      try {
        frameRateSupported = await orchestrator
            .attachFrameRatePlatformPort()
            .timeout(_cleanupTimeout);
      } catch (error, stackTrace) {
        debugPrint('Frame-rate platform port unavailable: $error\n$stackTrace');
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      final frameRateSettings = widget.frameRateSettingsController;
      if (frameRateSupported && frameRateSettings != null) {
        final runtimeController = GameFrameRateRuntimeController(
          settings: frameRateSettings,
          port:
              widget.frameRateRuntimePortFactory?.call() ??
              const MethodChannelGameFrameRateRuntimePort(),
        );
        _frameRateRuntimeController = runtimeController;
        final lifecycleState = WidgetsBinding.instance.lifecycleState;
        if (lifecycleState != null) {
          runtimeController.onLifecycleChanged(lifecycleState);
        }
        final finishedPageUrl = _lastFinishedPageUrl;
        if (_pageReady && finishedPageUrl != null) {
          await runtimeController.onPageReady(
            samplingEnabled:
                widget.browserController.mode !=
                    GameBrowserMode.localPrototype &&
                isGameFrameRateSamplingPage(finishedPageUrl),
          );
        }
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      final result = await orchestrator.applyNetworkSettings().timeout(
        _cleanupTimeout,
      );
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      final settings = widget.networkSettingsController?.settings;
      if (!result.success && settings?.mode != NetworkMode.system) {
        _setNetworkStartupError('网络设置应用失败 [${result.code}]: ${result.message}');
        return;
      }
      await _continueStartupAfterNetwork(port, generationId, operationEpoch);
    } catch (error, stackTrace) {
      debugPrint('Native game surface startup failed: $error\n$stackTrace');
      if (_matchesAttempt(port, operationEpoch)) {
        _setFatalError(nativeWebViewStartupErrorMessage(error));
      }
    }
  }

  Future<void> _continueStartupAfterNetwork(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) async {
    if (!_matchesGeneration(port, generationId, operationEpoch)) return;
    final orchestrator = _startupOrchestrator;
    _networkRetryAvailable = false;
    _setStartupState(GameStartupState.networkReady);
    final initialAddress = resolveInitialGameAddress(widget.browserController);
    var awaitingNavigationCommand = false;
    try {
      await orchestrator
          .runCaptureStartup(
            waitForSurface: () async {
              await WidgetsBinding.instance.endOfFrame;
            },
            isActive: () =>
                _matchesGeneration(port, generationId, operationEpoch),
            navigate: () async {
              if (_matchesGeneration(port, generationId, operationEpoch)) {
                await widget.browserController.prepareInitialHome();
              }
              if (_matchesGeneration(port, generationId, operationEpoch)) {
                awaitingNavigationCommand = true;
                await _navigateInitialPage(
                  port,
                  initialAddress,
                  generationId: generationId,
                  operationEpoch: operationEpoch,
                );
                awaitingNavigationCommand = false;
              }
            },
          )
          .timeout(_cleanupTimeout);
    } on TimeoutException {
      // The outer budget protects surface/capture/cookie preparation. Once
      // Android has acknowledged navigation, its late command reply cannot
      // fail a document already loading (or ready). The inner command budget
      // and the document watchdog still cover the navigation itself.
      if (!awaitingNavigationCommand || !_navigationAcknowledged) rethrow;
    }
    if (!_matchesGeneration(port, generationId, operationEpoch)) return;
    if (_pageReady) {
      await orchestrator.attachAudioPortOnce().timeout(_cleanupTimeout);
      if (_matchesGeneration(port, generationId, operationEpoch)) {
        _updatePresentationReadiness();
      }
    }
  }

  Future<void> _navigateInitialPage(
    NativeActivityGameWebViewPort port,
    Uri address, {
    required int generationId,
    required int operationEpoch,
  }) {
    if (_navigationAcknowledged || _navigationIssued) {
      return _navigationFuture ?? Future<void>.value();
    }
    final existing = _navigationFuture;
    if (existing != null) return existing;
    _navigationIssued = true;
    _navigationTarget = canonicalNavigationTarget(address);
    _startNavigationDeadline(address, command: true);
    var responseTimedOut = false;
    late final Future<void> operation;
    operation = port
        .loadUri(address)
        .timeout(
          _cleanupTimeout,
          onTimeout: () {
            responseTimedOut = true;
            throw TimeoutException('Initial navigation response timed out');
          },
        )
        .catchError((Object error, StackTrace stackTrace) {
          if (!_isCurrentNavigationAttempt(port, generationId)) {
            return;
          }
          if (_navigationAcknowledged) return;
          if (!responseTimedOut) {
            _navigationIssued = false;
            _navigationTarget = null;
          }
          Error.throwWithStackTrace(error, stackTrace);
        })
        .whenComplete(() {
          if (identical(_navigationFuture, operation)) {
            _navigationFuture = null;
          }
        });
    _navigationFuture = operation;
    return operation;
  }

  void _replayPendingEvents(
    NativeActivityGameWebViewPort port,
    int generationId,
  ) {
    final pending = List<NativeGameWebViewEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in pending) {
      if (!_active ||
          !identical(_port, port) ||
          _generationId != generationId) {
        break;
      }
      if (_fatal && event.type != NativeGameWebViewEventType.destroyed) {
        continue;
      }
      _dispatchCurrentEvent(event);
    }
  }

  void _onEvent(NativeGameWebViewEvent event) {
    if (!_active) return;
    final generationId = _generationId;
    if (generationId == null) {
      if (_fatal) return;
      if (_pendingEvents.length == 64) _pendingEvents.removeAt(0);
      _pendingEvents.add(event);
      return;
    }
    if (event.generationId != generationId) return;
    if (_fatal && event.type != NativeGameWebViewEventType.destroyed) return;
    _dispatchCurrentEvent(event);
  }

  void _dispatchCurrentEvent(NativeGameWebViewEvent event) {
    final generationId = _generationId;
    if (!_active ||
        generationId == null ||
        event.generationId != generationId) {
      return;
    }
    if (_fatal && event.type != NativeGameWebViewEventType.destroyed) return;
    switch (event.type) {
      case NativeGameWebViewEventType.created:
        return;
      case NativeGameWebViewEventType.pageStarted:
        _pendingPageFinish = null;
        _pageFinishFuture = null;
        _frameRateRuntimeController?.onPageStarted();
        final startedUri = event.navigationUri;
        if (_navigationIssued &&
            startedUri != null &&
            canonicalNavigationTarget(startedUri) == _navigationTarget) {
          _navigationAcknowledged = true;
        }
        _pageReady = false;
        _awaitingNewPageStart = false;
        _pageEpoch += 1;
        _currentDocumentUri = event.navigationUri;
        _startNavigationDeadline(event.navigationUri);
        final url = event.url!;
        widget.statusController.onPageStarted(url);
        widget.browserController.onPageStarted(url);
        widget.toolbarController.onStageChanged(GameSurfaceStage.login);
        if (_startupState == GameStartupState.networkReady ||
            _startupState == GameStartupState.ready ||
            _startupState == GameStartupState.error) {
          _setStartupState(GameStartupState.loadingGame);
        }
        return;
      case NativeGameWebViewEventType.pageFinished:
        if (_awaitingNewPageStart) return;
        if (_currentDocumentUri != null &&
            event.navigationUri != null &&
            canonicalNavigationTarget(event.navigationUri!) !=
                canonicalNavigationTarget(_currentDocumentUri!)) {
          return;
        }
        _documentFinished = true;
        _navigationCommandPending = false;
        _documentWatchdog.complete(_navigationEpoch);
        _pageCategory = classifyGamePage(event.navigationUri);
        _emitLoadEvent(GameLoadPhase.documentFinished);
        _updatePresentationReadiness();
        final url = event.url!;
        _lastFinishedPageUrl = url;
        widget.statusController.onPageFinished(url);
        // Compatibility scripts need the actual URL; the controller sanitizes
        // it separately for display.
        widget.browserController.onPageFinished(
          event.navigationUri?.toString() ?? url,
        );
        final port = _port;
        if (port != null) {
          _schedulePageFinish(
            _PendingPageFinish(
              port: port,
              generationId: generationId,
              operationEpoch: _operationEpoch,
              pageEpoch: _pageEpoch,
              url: url,
            ),
          );
        }
        return;
      case NativeGameWebViewEventType.presentationChanged:
        if (_awaitingNewPageStart) return;
        final state = event.presentationState!;
        if (state == _presentationState) return;
        _presentationState = state;
        widget.toolbarController.onStageChanged(
          state == NativeGamePresentationState.game
              ? GameSurfaceStage.game
              : GameSurfaceStage.login,
        );
        if (state == NativeGamePresentationState.pending) {
          _emitLoadEvent(GameLoadPhase.bodyWaiting);
        } else if (state == NativeGamePresentationState.game) {
          _emitLoadEvent(GameLoadPhase.gameDetected);
        }
        _updatePresentationReadiness();
        return;
      case NativeGameWebViewEventType.mainFrameError:
        _reportPageError(event.description!, errorCode: event.errorCode);
        return;
      case NativeGameWebViewEventType.resourceError:
        _emitLoadEvent(
          GameLoadPhase.failed,
          errorCode: event.errorCode,
          isMainFrame: false,
        );
        return;
      case NativeGameWebViewEventType.navigationBlocked:
        widget.browserController.onBlockedNavigation(
          Uri(scheme: event.scheme!),
        );
        return;
      case NativeGameWebViewEventType.renderProcessGone:
        widget.toolbarController.onStageChanged(GameSurfaceStage.login);
        widget.onRenderProcessGone?.call(event.didCrash!);
        _renderProcessRecoveryAvailable = true;
        _setFatalError('游戏渲染进程已退出。');
        return;
      case NativeGameWebViewEventType.destroyed:
        widget.toolbarController.onStageChanged(GameSurfaceStage.login);
        _invalidateOperations(fatal: true);
        _generationId = null;
        widget.onGenerationChanged?.call(-1);
        final port = _port;
        if (port != null) {
          try {
            widget.browserController.detachPort(port);
          } catch (error, stackTrace) {
            debugPrint(
              'Native game surface controller detach failed: '
              '$error\n$stackTrace',
            );
          }
        }
        if (!_renderProcessRecoveryAvailable) {
          _notifyFatalError('原生 WebView 已销毁。');
        }
        return;
    }
  }

  void _schedulePageFinish(_PendingPageFinish pending) {
    _pendingPageFinish = pending;
    _ensurePageFinish();
  }

  void _ensurePageFinish() {
    if (!_active ||
        !mounted ||
        _appLifecycleState != AppLifecycleState.resumed ||
        _pageFinishFuture != null ||
        _pendingPageFinish == null) {
      return;
    }
    final operation = _drainPageFinishes();
    _pageFinishFuture = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_pageFinishFuture, operation)) {
          _pageFinishFuture = null;
        }
        if (_pendingPageFinish != null) {
          _ensurePageFinish();
        }
      }),
    );
  }

  Future<void> _drainPageFinishes() async {
    final operationEpoch = _operationEpoch;
    final pageEpoch = _pageEpoch;
    while (_active &&
        mounted &&
        _operationEpoch == operationEpoch &&
        _pageEpoch == pageEpoch &&
        _appLifecycleState == AppLifecycleState.resumed) {
      final pending = _pendingPageFinish;
      if (pending == null) return;
      _pendingPageFinish = null;
      if (!_matchesPage(
        pending.port,
        pending.generationId,
        pending.operationEpoch,
        pending.pageEpoch,
      )) {
        continue;
      }
      await _finishPage(pending);
    }
  }

  Future<void> _finishPage(_PendingPageFinish pending) async {
    _PageInitializationFailure? lastFailure;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (!_matchesPendingPageFinish(pending)) return;
      if (_appLifecycleState != AppLifecycleState.resumed) {
        _pendingPageFinish = pending;
        return;
      }
      try {
        await _runPageInitializationAttempt(pending);
        if (!_matchesPendingPageFinish(pending)) return;
        _pageReady = true;
        _automaticRecoveryReloadUsed = false;
        _pageReloadAvailable = false;
        _updatePresentationReadiness();
        await _frameRateRuntimeController?.onPageReady(
          samplingEnabled:
              widget.browserController.mode != GameBrowserMode.localPrototype &&
              isGameFrameRateSamplingPage(pending.url),
        );
        return;
      } on _PageInitializationFailure catch (error, stackTrace) {
        lastFailure = error;
        debugPrint(
          'Native game surface page finish attempt ${attempt + 1} failed: '
          '$error\n$stackTrace',
        );
        if (!_matchesPendingPageFinish(pending)) return;
        if (_appLifecycleState != AppLifecycleState.resumed) {
          _pendingPageFinish = pending;
          return;
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!_matchesPendingPageFinish(pending)) return;
          if (_appLifecycleState != AppLifecycleState.resumed) {
            _pendingPageFinish = pending;
            return;
          }
        }
      }
    }
    if (lastFailure == null || !_matchesPendingPageFinish(pending)) return;
    await _reloadAfterPageInitializationFailure(pending, lastFailure);
  }

  Future<void> _runPageInitializationAttempt(_PendingPageFinish pending) async {
    await _runPageInitializationStage(
      'fitGameScreen',
      pending.port.fitGameScreen,
    );
    if (!_matchesPendingPageFinish(pending)) return;
    await _runPageInitializationStage(
      'prepareCapture',
      _startupOrchestrator.prepareCapture,
    );
    if (!_matchesPendingPageFinish(pending)) return;
    await _runPageInitializationStage(
      'attachAudioPortOnce',
      _startupOrchestrator.attachAudioPortOnce,
    );
  }

  Future<void> _reloadAfterPageInitializationFailure(
    _PendingPageFinish pending,
    _PageInitializationFailure failure,
  ) async {
    if (_automaticRecoveryReloadUsed) {
      _reportPageInitializationFailure(failure);
      return;
    }
    _automaticRecoveryReloadUsed = true;
    _pageReady = false;
    _awaitingNewPageStart = true;
    _emitLoadEvent(GameLoadPhase.retry);
    _startNavigationDeadline(_navigationTarget, command: true);
    _setStartupState(GameStartupState.loadingGame);
    try {
      await _runPageInitializationStage('reload', pending.port.reload);
    } on _PageInitializationFailure catch (reloadFailure, stackTrace) {
      debugPrint(
        'Native game surface automatic page reload failed: '
        '$reloadFailure\n$stackTrace',
      );
      if (_matchesPendingPageFinish(pending)) {
        _awaitingNewPageStart = false;
        _reportPageInitializationFailure(reloadFailure);
      }
    }
  }

  bool _matchesPendingPageFinish(_PendingPageFinish pending) => _matchesPage(
    pending.port,
    pending.generationId,
    pending.operationEpoch,
    pending.pageEpoch,
  );

  void _reportPageInitializationFailure(_PageInitializationFailure failure) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    _reportPageError(
      l10n.nativeGameSurfacePageInitializationFailed(
        failure.stage,
        failure.cause.runtimeType.toString(),
      ),
      pageReloadAvailable: true,
    );
  }

  void _reloadAfterPageInitializationError() {
    if (!_pageReloadAvailable || !_active || !mounted || _fatal) return;
    final port = _port;
    final generationId = _generationId;
    if (port == null || generationId == null) return;
    final operationEpoch = _operationEpoch;
    _pageReloadAvailable = false;
    _pageReady = false;
    _awaitingNewPageStart = true;
    _emitLoadEvent(GameLoadPhase.retry);
    _startNavigationDeadline(_navigationTarget, command: true);
    _setStartupState(GameStartupState.loadingGame);
    unawaited(
      _runManualPageReload(port, generationId, operationEpoch).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'Native game surface manual page reload failed unexpectedly: '
          '$error\n$stackTrace',
        );
      }),
    );
  }

  Future<void> _runManualPageReload(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) async {
    try {
      await _runPageInitializationStage('reload', port.reload);
    } on _PageInitializationFailure catch (failure, stackTrace) {
      debugPrint(
        'Native game surface manual page reload failed: '
        '$failure\n$stackTrace',
      );
      if (_matchesGeneration(port, generationId, operationEpoch) &&
          _awaitingNewPageStart) {
        _awaitingNewPageStart = false;
        _reportPageInitializationFailure(failure);
      }
    }
  }

  Future<void> _runPageInitializationStage(
    String stage,
    Future<void> Function() action,
  ) async {
    try {
      await action().timeout(_pageInitializationTimeout);
    } catch (error, stackTrace) {
      throw _PageInitializationFailure(
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onEventError(Object error, StackTrace stackTrace) {
    if (!_active || _fatal) return;
    debugPrint('Native game WebView event failed: $error\n$stackTrace');
    _setFatalError('原生 WebView 事件通道异常。');
  }

  void _onEventDone() {
    if (!_active || _fatal) return;
    _setFatalError('原生 WebView 事件通道已关闭。');
  }

  void _reportPageError(
    String message, {
    bool pageReloadAvailable = true,
    int? errorCode,
    bool emitFailure = true,
  }) {
    if (emitFailure) {
      _emitLoadEvent(
        GameLoadPhase.failed,
        errorCode: errorCode,
        isMainFrame: true,
      );
    }
    _pageReloadAvailable = pageReloadAvailable;
    _frameRateRuntimeController?.onPageStarted();
    _invalidateOperations(fatal: false);
    _pageReady = false;
    _awaitingNewPageStart = true;
    widget.statusController.onWebResourceError(message);
    widget.browserController.onWebResourceError(
      description: message,
      isForMainFrame: true,
    );
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _setNetworkStartupError(String message) {
    _documentWatchdog.cancel();
    _bodyWatchdog.cancel();
    _networkRetryAvailable = true;
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _setFatalError(String message) {
    _emitLoadEvent(GameLoadPhase.failed, isMainFrame: true);
    _frameRateRuntimeController?.onPageStarted();
    _pageReady = false;
    _invalidateOperations(fatal: true);
    _notifyFatalError(message);
  }

  void _notifyFatalError(String message) {
    widget.statusController.onWebResourceError(message);
    widget.browserController.onWebResourceError(
      description: message,
      isForMainFrame: true,
    );
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _invalidateOperations({required bool fatal}) {
    _documentWatchdog.cancel();
    _bodyWatchdog.cancel();
    _bodyDeadlineEpoch = null;
    _pendingPageFinish = null;
    // Retired WebView commands can wait until their platform timeout. They
    // must not hold the replacement document's initialization queue open.
    _pageFinishFuture = null;
    if (fatal) {
      _frameRateRuntimeController?.dispose();
      _frameRateRuntimeController = null;
      _fatal = true;
      _awaitingNewPageStart = false;
    }
    _operationEpoch += 1;
    _pageEpoch += 1;
    _networkRetryAvailable = false;
  }

  void _setStartupState(GameStartupState state, {String? errorMessage}) {
    if (!_active || !mounted) return;
    setState(() {
      _startupState = state;
      if (errorMessage != null) _startupErrorMessage = errorMessage;
    });
    _observeVisibilityUpdate(_requestVisibility());
  }

  void _observeVisibilityUpdate(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        debugPrint(
          'Native game surface visibility update failed: '
          '$error\n$stackTrace',
        );
      }),
    );
  }

  bool _isCurrentNavigationAttempt(
    NativeActivityGameWebViewPort port,
    int generationId,
  ) {
    return _active &&
        mounted &&
        !_fatal &&
        identical(_port, port) &&
        _generationId == generationId;
  }

  bool _matchesAttempt(NativeActivityGameWebViewPort port, int operationEpoch) {
    return _active &&
        mounted &&
        !_fatal &&
        identical(_port, port) &&
        _operationEpoch == operationEpoch;
  }

  bool _matchesGeneration(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) {
    return _matchesAttempt(port, operationEpoch) &&
        _generationId == generationId;
  }

  bool _matchesPage(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
    int pageEpoch,
  ) {
    return _matchesGeneration(port, generationId, operationEpoch) &&
        _pageEpoch == pageEpoch;
  }

  Future<void> _onBoundsChanged(NativeGameWebViewBounds bounds) async {
    _latestBounds = bounds;
    final port = _port;
    if (!_active || _fatal || port == null || _generationId == null) return;
    await port.setBounds(bounds).timeout(_cleanupTimeout);
    await _requestVisibility();
  }

  Future<void> _onVisibilityChanged(bool visible) async {
    _desiredVisible = visible;
    await _requestVisibility();
  }

  Future<void> _preparePopupPreview() async {
    final generation = ++_popupPreviewGeneration;
    final previewPort =
        widget.previewPort ?? const MethodChannelNativeGameSurfacePreviewPort();
    try {
      final bytes = await previewPort.capturePreview().timeout(_cleanupTimeout);
      if (!mounted || generation != _popupPreviewGeneration) return;
      final decoder = widget.previewDecoder ?? _decodePopupPreview;
      final provider = await decoder(bytes, context);
      if (!mounted || generation != _popupPreviewGeneration) return;
      setState(() => _popupPreview = provider);
      await WidgetsBinding.instance.endOfFrame;
    } catch (error, stackTrace) {
      debugPrint(
        'Native game popup preview capture failed: $error\n$stackTrace',
      );
    }
  }

  Future<ImageProvider> _decodePopupPreview(
    Uint8List bytes,
    BuildContext context,
  ) async {
    final provider = MemoryImage(bytes);
    await precacheImage(provider, context);
    return provider;
  }

  void _cancelPopupPreviewPreparation() {
    _popupPreviewGeneration++;
  }

  void _discardPopupPreview() {
    _cancelPopupPreviewPreparation();
    _clearPopupPreview();
  }

  void _clearPopupPreview() {
    if (!mounted || _popupPreview == null) return;
    setState(() => _popupPreview = null);
  }

  Future<void> _requestVisibility({bool force = false}) {
    _visibilityRevision += 1;
    _forceVisibilityWrite = _forceVisibilityWrite || force;
    final inFlight = _visibilitySyncFuture;
    if (inFlight != null) return inFlight;
    final operation = _drainVisibility();
    _visibilitySyncFuture = operation;
    unawaited(
      operation.then<void>(
        (_) => _finishVisibilityDrain(operation),
        onError: (Object _, StackTrace _) => _finishVisibilityDrain(operation),
      ),
    );
    return operation;
  }

  void _finishVisibilityDrain(Future<void> operation) {
    if (identical(_visibilitySyncFuture, operation)) {
      _visibilitySyncFuture = null;
    }
    if (!_visibilityFatalCleanupStarted &&
        (_forceVisibilityWrite ||
            _processedVisibilityRevision < _visibilityRevision)) {
      _observeVisibilityUpdate(_requestVisibility());
    }
  }

  Future<void> _drainVisibility() async {
    Object? pendingError;
    StackTrace? pendingStackTrace;
    while (true) {
      final revision = _visibilityRevision;
      final force = _forceVisibilityWrite;
      _forceVisibilityWrite = false;
      final port = _port;
      if (port == null || _generationId == null) {
        _processedVisibilityRevision = revision;
        return;
      }
      final target =
          _active &&
          !_fatal &&
          _desiredVisible &&
          _latestBounds != null &&
          _startupState == GameStartupState.ready;
      if (force || target != _actualVisible) {
        Object? lastError;
        StackTrace? lastStackTrace;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await port.setVisible(target).timeout(_cleanupTimeout);
            if (!identical(_port, port)) return;
            _actualVisible = target;
            if (target &&
                revision == _visibilityRevision &&
                _startupState == GameStartupState.ready &&
                _presentationState != NativeGamePresentationState.pending) {
              if (_presentationState != NativeGamePresentationState.game) {
                _emitLoadEvent(GameLoadPhase.loginVisible);
              }
              _emitLoadEvent(GameLoadPhase.visible);
            }
            lastError = null;
            break;
          } catch (error, stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
            if (revision != _visibilityRevision || !identical(_port, port)) {
              break;
            }
          }
        }
        if (lastError != null && revision == _visibilityRevision) {
          if (!target) {
            await _terminateUnsafeNativeOverlay(
              port,
              lastError,
              lastStackTrace!,
            );
            Error.throwWithStackTrace(lastError, lastStackTrace);
          }
          pendingError = lastError;
          pendingStackTrace = lastStackTrace;
          _reportPageError('原生 WebView 显示失败：${lastError.runtimeType}');
          _forceVisibilityWrite = true;
          continue;
        }
      }
      if (revision == _visibilityRevision) {
        _processedVisibilityRevision = revision;
        if (pendingError != null) {
          Error.throwWithStackTrace(pendingError, pendingStackTrace!);
        }
        return;
      }
    }
  }

  Future<void> _terminateUnsafeNativeOverlay(
    NativeActivityGameWebViewPort port,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (_visibilityFatalCleanupStarted || !identical(_port, port)) return;
    _visibilityFatalCleanupStarted = true;
    debugPrint('Native game surface could not be hidden: $error\n$stackTrace');
    _setFatalError('原生 WebView 无法安全隐藏，已终止该模式。');
    _generationId = null;
    widget.onGenerationChanged?.call(-1);
    _port = null;
    try {
      widget.browserController.detachPort(port);
    } catch (detachError, detachStackTrace) {
      debugPrint(
        'Native game surface controller detach failed: '
        '$detachError\n$detachStackTrace',
      );
    }
    final subscription = _eventSubscription;
    _eventSubscription = null;
    await _disposeNativeResources(subscription, port);
  }

  void _onNetworkSettingsChanged() {
    if (_active &&
        !_fatal &&
        _networkRetryAvailable &&
        _startupState == GameStartupState.error &&
        _networkRetryFuture == null) {
      final port = _port;
      final generationId = _generationId;
      if (port != null && generationId != null) {
        final operation = _restartNetwork(port, generationId, _operationEpoch);
        _networkRetryFuture = operation;
        unawaited(
          operation
              .whenComplete(() {
                if (identical(_networkRetryFuture, operation)) {
                  _networkRetryFuture = null;
                }
              })
              .catchError((Object error, StackTrace stackTrace) {
                debugPrint(
                  'Native game surface network retry failed: '
                  '$error\n$stackTrace',
                );
              }),
        );
      }
    }
  }

  Future<void> _restartNetwork(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) async {
    late final GameSurfaceNetworkResult result;
    try {
      result = await _startupOrchestrator.applyNetworkSettings().timeout(
        _cleanupTimeout,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface network retry failed: $error\n$stackTrace',
      );
      return;
    }
    if (!_matchesGeneration(port, generationId, operationEpoch)) return;
    if (result.success) {
      if (!_navigationIssued && !_navigationAcknowledged) {
        try {
          await _continueStartupAfterNetwork(
            port,
            generationId,
            operationEpoch,
          );
        } catch (error, stackTrace) {
          debugPrint(
            'Native game surface startup retry failed: $error\n$stackTrace',
          );
          if (_matchesGeneration(port, generationId, operationEpoch)) {
            _setFatalError(nativeWebViewStartupErrorMessage(error));
          }
        }
        return;
      }
      _networkRetryAvailable = false;
      _pageReady = false;
      _awaitingNewPageStart = true;
      _emitLoadEvent(GameLoadPhase.retry);
      _startNavigationDeadline(_navigationTarget, command: true);
      _setStartupState(GameStartupState.networkReady);
      try {
        await port.reload().timeout(_cleanupTimeout);
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface network reload failed: $error\n$stackTrace',
        );
        if (_matchesGeneration(port, generationId, operationEpoch) &&
            _awaitingNewPageStart) {
          _setNetworkStartupError('网络重载失败：${error.runtimeType}');
        }
        return;
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      // Page events may have already progressed through loading to ready.
      // A command acknowledgement must never roll their state backwards.
    }
  }

  void _onCaptureModeChanged() {
    final controller = widget.captureModeController;
    if (controller == null || controller.mode == _activeCaptureMode) return;
    _activeCaptureMode = controller.mode;
    _captureRevision += 1;
    _ensureCaptureReconfiguration();
  }

  void _ensureCaptureReconfiguration() {
    if (_captureReconfigureFuture != null) return;
    final operation = _drainCaptureReconfiguration();
    _captureReconfigureFuture = operation;
    unawaited(
      operation.then<void>(
        (_) => _finishCaptureReconfiguration(operation),
        onError: (Object _, StackTrace _) =>
            _finishCaptureReconfiguration(operation),
      ),
    );
  }

  void _finishCaptureReconfiguration(Future<void> operation) {
    if (identical(_captureReconfigureFuture, operation)) {
      _captureReconfigureFuture = null;
    }
    if (_active && !_fatal && _processedCaptureRevision < _captureRevision) {
      _ensureCaptureReconfiguration();
    }
  }

  Future<void> _drainCaptureReconfiguration() async {
    while (_active && !_fatal) {
      final revision = _captureRevision;
      final generationId = _generationId;
      final port = _port;
      if (generationId == null || port == null) {
        _processedCaptureRevision = revision;
        return;
      }
      final operationEpoch = _operationEpoch;
      try {
        await _startupOrchestrator.prepareCapture().timeout(_cleanupTimeout);
        if (!_matchesGeneration(port, generationId, operationEpoch)) return;
        if (revision != _captureRevision) continue;
        _pageReady = false;
        _awaitingNewPageStart = true;
        _startNavigationDeadline(_navigationTarget, command: true);
        _setStartupState(GameStartupState.loadingGame);
        await port.reload().timeout(_cleanupTimeout);
        if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface capture reconfiguration failed: '
          '$error\n$stackTrace',
        );
        if (_matchesGeneration(port, generationId, operationEpoch) &&
            revision == _captureRevision) {
          _reportPageError('捕获模式切换失败：${error.runtimeType}');
        }
        _processedCaptureRevision = revision;
        return;
      }
      if (revision == _captureRevision) {
        _processedCaptureRevision = revision;
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        NativeGameSurfaceSlot(
          key: _surfaceSlotKey,
          onBoundsChanged: _boundsSink,
          onVisibilityChanged: _visibilitySink,
          routeObserver: widget.routeObserver,
          boundsSinkIdentity: _port ?? this,
          onBeforePopupRouteHidden: _preparePopupPreview,
          onImmediatePopupRouteHidden: _discardPopupPreview,
          onPopupRouteRevealStarted: _cancelPopupPreviewPreparation,
          onAfterPopupRouteRevealed: _clearPopupPreview,
        ),
        if (_popupPreview case final preview?)
          Positioned.fill(
            child: Image(
              key: const Key('native-game-surface-popup-preview'),
              image: preview,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
          ),
        if (_startupState != GameStartupState.ready)
          Positioned.fill(
            child: ColoredBox(
              color: appColor(context, Color(0xff102431)),
              child: Center(child: _buildStartupOverlay()),
            ),
          ),
      ],
    );
  }

  Widget _buildStartupOverlay() {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    if (_startupState == GameStartupState.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              runtimeMessageText(context, _startupErrorMessage),
              key: const Key('native-game-surface-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: appColor(context, Colors.redAccent)),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.nativeGameSurfaceSwitchRenderingModeHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: appColor(context, Colors.redAccent),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (_renderProcessRecoveryAvailable) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('native-game-surface-reload'),
                onPressed: _reloadAfterRenderProcessGone,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.reload),
              ),
            ],
            if (_pageReloadAvailable) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('native-game-surface-page-reload'),
                onPressed: _reloadAfterPageInitializationError,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.reload),
              ),
            ],
          ],
        ),
      );
    }
    if (_documentFinished && _isWaitingForBody) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(
            color: appColor(context, Color(0xffd4a85f)),
          ),
          const SizedBox(height: 16),
          Text(
            runtimeMessageText(context, '正在等待游戏本体...'),
            key: const Key('native-game-surface-body-waiting'),
            style: TextStyle(color: appColor(context, Colors.white70)),
          ),
        ],
      );
    }
    return CircularProgressIndicator(
      color: appColor(context, Color(0xffd4a85f)),
    );
  }

  void _reloadAfterRenderProcessGone() {
    if (!_renderProcessRecoveryAvailable || !mounted || !_active) return;
    if (_generationId != null) return;
    final port = _port;
    if (port == null) return;
    _renderProcessRecoveryAvailable = false;
    _fatal = false;
    _pageReady = false;
    _generationId = null;
    widget.onGenerationChanged?.call(-1);
    _pendingEvents.clear();
    _navigationIssued = false;
    _navigationAcknowledged = false;
    _navigationTarget = null;
    _navigationFuture = null;
    _bootstrapTail = null;
    _setStartupState(GameStartupState.applyingNetwork);
    unawaited(
      _start(port).catchError((Object error, StackTrace stackTrace) {
        debugPrint(
          'Native game surface renderer reload failed: '
          '$error\n$stackTrace',
        );
      }),
    );
  }

  @override
  void dispose() {
    _active = false;
    widget.toolbarController.onStageChanged(GameSurfaceStage.login);
    _pendingPageFinish = null;
    _popupPreviewGeneration++;
    _popupPreview = null;
    _windowMetricsRecoveryScheduler.dispose();
    _documentWatchdog.dispose();
    _bodyWatchdog.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.onGenerationChanged?.call(-1);
    _frameRateRuntimeController?.dispose();
    _frameRateRuntimeController = null;
    _invalidateOperations(fatal: true);
    _desiredVisible = false;
    widget.networkSettingsController?.removeListener(_onNetworkSettingsChanged);
    widget.captureModeController?.removeListener(_onCaptureModeChanged);
    _pendingEvents.clear();
    final port = _port;
    if (port == null) {
      if (!_visibilityFatalCleanupStarted && !_createTimeoutCleanupStarted) {
        unawaited(
          _disposeStartupOrchestrator(
            _startupOrchestrator,
            timeout: _cleanupTimeout,
          ),
        );
      }
    } else {
      final subscription = _eventSubscription;
      _eventSubscription = null;
      final orchestrator = _startupOrchestrator;
      final browserController = widget.browserController;
      final hide = _requestVisibility(force: true);
      try {
        browserController.detachPort(port);
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface controller detach failed: '
          '$error\n$stackTrace',
        );
      }
      unawaited(
        _disposeAfterVisibility(hide, subscription, port, orchestrator),
      );
    }
    super.dispose();
  }

  Future<void> _disposeAfterVisibility(
    Future<void> hide,
    StreamSubscription<NativeGameWebViewEvent>? subscription,
    NativeActivityGameWebViewPort port,
    GameSurfaceStartupOrchestrator orchestrator,
  ) async {
    await _runBoundedCleanup(
      () => hide,
      'final visibility',
      timeout: _cleanupTimeout,
    );
    if (_visibilityFatalCleanupStarted) return;
    _port = null;
    await _disposeNativeResources(
      subscription,
      port,
      orchestrator: orchestrator,
    );
  }

  Future<void> _disposeNativeResources(
    StreamSubscription<NativeGameWebViewEvent>? subscription,
    NativeActivityGameWebViewPort port, {
    GameSurfaceStartupOrchestrator? orchestrator,
  }) async {
    if (subscription != null) {
      await _runBoundedCleanup(
        subscription.cancel,
        'event cancellation',
        timeout: _cleanupTimeout,
      );
    }
    final startupCleanup = _disposeStartupOrchestrator(
      orchestrator ?? _startupOrchestrator,
      timeout: _cleanupTimeout,
    );
    final nativeCleanup = _runBoundedCleanup(
      port.dispose,
      'destroy',
      timeout: _cleanupTimeout,
    );
    await Future.wait(<Future<void>>[startupCleanup, nativeCleanup]);
  }

  Future<void> _disposeStartupOrchestrator(
    GameSurfaceStartupOrchestrator orchestrator, {
    Duration? timeout,
  }) {
    return _runBoundedCleanup(
      orchestrator.dispose,
      'orchestrator dispose',
      timeout: timeout,
    );
  }

  Future<void> _runBoundedCleanup(
    FutureOr<void> Function() action,
    String label, {
    Duration? timeout,
  }) async {
    try {
      final operation = Future<void>.sync(action);
      await (timeout == null ? operation : operation.timeout(timeout));
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface $label failed: '
        '$error\n$stackTrace',
      );
    }
  }
}
