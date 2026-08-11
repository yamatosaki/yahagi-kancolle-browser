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
import 'browser/game_page_alignment_script.dart';
import 'browser/game_toolbar_controller.dart';
import 'browser/game_webview_compatibility.dart';
import 'browser/safe_page_address.dart';
import 'browser/game_launch_config.dart';
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
    this.renderingMode = GameRenderingMode.standard,
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

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late final WebViewController _webViewController;
  late final Future<void> _compatibilityReady;
  late final Future<void> _frameRateReady;
  late final GameCapturePort _gameCapturePort;
  late CaptureMode _activeCaptureMode;
  static const _scaleChannel = MethodChannel(
    'app.webview/fixed_canvas_scaling',
  );

  bool _audioPortAttached = false;
  bool _capturePortAttached = false;

  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  void _onNetworkSettingsChanged() {
    if (!mounted) return;
    if (_startupState == GameStartupState.error) {
      _executeStartupSequence();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.networkSettingsController.addListener(_onNetworkSettingsChanged);
    _activeCaptureMode = widget.captureModeController.mode;
    _gameCapturePort = createPlatformGameCapturePort();
    widget.captureModeController.addListener(_onCaptureModeChanged);
    _webViewController = WebViewController();
    _compatibilityReady = _configureCompatibility();
    _frameRateReady = _configureFrameRate();
    widget.browserController.attachPort(
      WebViewGameBrowserPort(
        _webViewController,
        _prototypePage,
        compatibilityReady: _compatibilityReady,
        prepareForRealNavigation: _prepareCapture,
      ),
    );

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (url) {
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
            widget.controller.onPageFinished(url);
            widget.browserController.onPageFinished(url);

            if (_webViewController.platform is AndroidWebViewController) {
              await _scaleChannel.invokeMethod<void>(
                'bindFixedCanvas',
                <String, Object>{'contentWidth': 1200, 'contentHeight': 720},
              );
            }

            await _webViewController.runJavaScript(gamePageAlignmentScript);
            await _webViewController.runJavaScript('''
              if (window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();
            ''');
            await _prepareCapture();
            await _attachAudioPortOnce();

            if (_startupState == GameStartupState.loadingGame) {
              setState(() => _startupState = GameStartupState.ready);
            }
          },
          onWebResourceError: (error) {
            final isForMainFrame = error.isForMainFrame ?? true;
            if (isForMainFrame) {
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

    _executeStartupSequence();
  }

  Future<void> _executeStartupSequence() async {
    setState(() => _startupState = GameStartupState.applyingNetwork);

    // Ensure compatibility is done
    await _compatibilityReady;
    await _frameRateReady;

    // Apply network settings
    final netSettings = widget.networkSettingsController.settings;
    final formattedHost = NetworkSettingsValidator.formatProxyHost(
      netSettings.host,
    );
    final result = await widget.networkSettingsController.applySettings(
      netSettings.mode,
      formattedHost,
      netSettings.port,
    );

    if (!mounted) return;

    if (!result.success && netSettings.mode != NetworkMode.system) {
      setState(() {
        _startupState = GameStartupState.error;
        _startupErrorMessage = '网络设置应用失败 [${result.code}]: ${result.message}';
      });
      return;
    }

    setState(() => _startupState = GameStartupState.networkReady);

    // Initial Load Request
    final displayAddress = widget.browserController.displayAddress;
    final address = Uri.tryParse(displayAddress);
    final initialAddress =
        address != null &&
            SafePageAddress.canNavigate(address) &&
            widget.browserController.mode != GameBrowserMode.localPrototype
        ? address
        : GameLaunchConfig.dmmGameEntry;

    await GameCaptureStartupSequence.run(
      waitForPlatformView: () async {
        await WidgetsBinding.instance.endOfFrame;
      },
      configureCapture: () async {
        if (!mounted) return;
        await _prepareCapture();
      },
      navigate: () async {
        if (!mounted) return;
        await _webViewController.loadRequest(initialAddress);
      },
    );
  }

  Future<void> _attachAudioPortOnce() async {
    if (_audioPortAttached) {
      return;
    }
    _audioPortAttached = true;
    await widget.audioController.attachPort(MethodChannelGameAudioPort());
  }

  Future<void> _onCaptureModeChanged() async {
    final nextMode = widget.captureModeController.mode;
    if (nextMode == _activeCaptureMode) {
      return;
    }
    _activeCaptureMode = nextMode;
    await _prepareCapture();
    await _webViewController.reload();
  }

  Future<void> _prepareCapture() async {
    if (!_capturePortAttached) {
      _capturePortAttached = true;
      await widget.gameCaptureController.attach(
        _gameCapturePort,
        enabled: widget.captureModeController.mode.installsGameBridge,
        script: nativeGameCaptureScript,
      );
      return;
    }
    await widget.gameCaptureController.configure(
      enabled: widget.captureModeController.mode.installsGameBridge,
      script: nativeGameCaptureScript,
    );
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
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await controller.attachPort(createPlatformGameFrameRatePort());
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final isLocalDocument =
        widget.browserController.mode == GameBrowserMode.localPrototype &&
        (uri?.scheme == 'about' || uri?.scheme == 'data');
    if (isLocalDocument ||
        (uri != null && SafePageAddress.canNavigateInGameWebView(uri))) {
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
              _startupErrorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              widget.networkSettingsController
                  .applySettings(NetworkMode.system, '', 8099)
                  .then((_) {
                    _executeStartupSequence();
                  });
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
          _getStartupStatusText(),
          style: const TextStyle(color: Color(0xff8197a5), fontSize: 14),
        ),
      ],
    );
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
    widget.captureModeController.removeListener(_onCaptureModeChanged);
    widget.networkSettingsController.removeListener(_onNetworkSettingsChanged);
    _webViewController.setJavaScriptMode(JavaScriptMode.disabled);
    _webViewController.loadHtmlString(
      '<!DOCTYPE html><html><body></body></html>',
    );
    _gameCapturePort.dispose();
    super.dispose();
  }
}

final class WebViewGameBrowserPort implements GameBrowserPort {
  WebViewGameBrowserPort(
    this.controller,
    this.localHomeHtml, {
    Future<void>? compatibilityReady,
    this.prepareForRealNavigation,
  }) : compatibilityReady = compatibilityReady ?? Future<void>.value();

  final WebViewController controller;
  final String localHomeHtml;
  final Future<void> compatibilityReady;
  final Future<void> Function()? prepareForRealNavigation;

  @override
  Future<bool> canGoBack() => controller.canGoBack();

  @override
  Future<void> goBack() => controller.goBack();

  @override
  Future<void> loadUri(Uri uri) async {
    await compatibilityReady;
    await prepareForRealNavigation?.call();
    await controller.loadRequest(uri);
  }

  @override
  Future<void> reload() => controller.reload();

  @override
  Future<void> showLocalHome() => controller.loadHtmlString(localHomeHtml);

  @override
  Future<void> runJavaScript(String javascript) =>
      controller.runJavaScript(javascript);

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

const String _prototypePage = '''
<!doctype html>
<html lang="zh-CN">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{height:100%;margin:0;background:#102431;color:#c7d5dc;font-family:sans-serif}
body{display:flex;align-items:center;justify-content:center}
main{text-align:center;padding:28px}h2{color:#d4a85f}p{color:#8299a5;line-height:1.6}
button{border:1px solid #5d786f;border-radius:8px;background:#183631;color:#80c8bd;padding:10px 14px}
</style>
<main>
  <h2>游戏 WebView 测试首页</h2>
  <p>这里不会连接真实账号，<br>使用上方“DMM 登录测试”主动进入真实网页。</p>
  <button onclick="YahagiBridge.postMessage(JSON.stringify({
    kind:'kcsapi-response',
    path:'/kcsapi/api_port/port',
    body:'svdata={&quot;api_result&quot;:1}',
    source:'manual',
    capturedAt:new Date().toISOString()
  }))">发送模拟舰队数据</button>
</main>
</html>
''';
