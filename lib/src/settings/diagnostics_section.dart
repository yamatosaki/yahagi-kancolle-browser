import 'package:flutter/material.dart';

import '../browser/game_browser_controller.dart';
import '../bridge/captured_api_event.dart';
import '../capture/capture_mode.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../capture/game_capture_port.dart';
import '../prototype_status_controller.dart';

class DiagnosticsSection extends StatelessWidget {
  const DiagnosticsSection({
    super.key,
    required this.browserController,
    required this.captureModeController,
    required this.gameCaptureController,
    required this.prototypeStatusController,
  });

  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameCaptureController gameCaptureController;
  final PrototypeStatusController prototypeStatusController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        browserController,
        captureModeController,
        gameCaptureController,
        prototypeStatusController,
      ]),
      builder: (context, _) {
        final nativeEvent = gameCaptureController.events.isEmpty
            ? null
            : gameCaptureController.events.last;
        final event = nativeEvent ?? prototypeStatusController.lastEvent;
        final capturedCount =
            gameCaptureController.events.length +
            prototypeStatusController.capturedEvents.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '诊断与关于',
              style: TextStyle(
                color: Color(0xffd4a85f),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _DiagnosticCard(
              title: _browserStateLabel(browserController.loadState),
              subtitle:
                  browserController.errorMessage ??
                  browserController.displayAddress,
              warning: browserController.loadState == GamePageLoadState.failed,
            ),
            const SizedBox(height: 8),
            _DiagnosticCard(
              title: captureModeController.mode == CaptureMode.browserOnly
                  ? '纯浏览模式 · 数据捕获已关闭'
                  : _captureStateTitle(gameCaptureController.state),
              subtitle: captureModeController.mode == CaptureMode.browserOnly
                  ? '游戏网页继续运行，舰队、任务和战斗信息暂停更新。'
                  : _captureStateSubtitle(gameCaptureController, event),
              warning:
                  gameCaptureController.state == GameCaptureState.error ||
                  gameCaptureController.state == GameCaptureState.unsupported,
            ),
            const SizedBox(height: 8),
            _DiagnosticCard(
              title: '已捕获 $capturedCount 条',
              subtitle: event == null
                  ? '等待 /kcsapi/ 响应'
                  : '${event.source.label} · ${event.capturedAt.toLocal()}',
            ),
            if (prototypeStatusController.lastBridgeError
                case final error?) ...[
              const SizedBox(height: 8),
              _DiagnosticCard(
                title: '已忽略非目标消息',
                subtitle: error,
                warning: true,
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '安全边界',
              style: TextStyle(
                color: Color(0xffd4a85f),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const _DiagnosticCard(
              title: '只读取，不操作',
              subtitle: '不会自动点击、补给、编成、出击或领取任务。',
            ),
            const SizedBox(height: 8),
            const _DiagnosticCard(
              title: '不读取 Cookie',
              subtitle: 'JS 桥接消息只包含接口路径、响应正文和时间。',
            ),
          ],
        );
      },
    );
  }

  String _browserStateLabel(GamePageLoadState state) {
    return switch (state) {
      GamePageLoadState.idle => '等待网页',
      GamePageLoadState.loading => '网页加载中',
      GamePageLoadState.ready => '网页已就绪',
      GamePageLoadState.failed => '网页加载失败',
    };
  }

  String _captureStateTitle(GameCaptureState state) {
    return switch (state) {
      GameCaptureState.disabled => '正在准备游戏接口捕获',
      GameCaptureState.checking => '正在准备游戏接口捕获',
      GameCaptureState.ready => '捕获已就绪',
      GameCaptureState.capturing => '正在捕获游戏接口',
      GameCaptureState.unsupported => '当前 WebView 不支持跨框架捕获',
      GameCaptureState.error => '游戏接口捕获启动失败',
    };
  }

  String _captureStateSubtitle(
    GameCaptureController captureController,
    CapturedApiEvent? latestEvent,
  ) {
    return switch (captureController.state) {
      GameCaptureState.disabled ||
      GameCaptureState.checking => '正在检查 Android WebView 捕获能力。',
      GameCaptureState.ready => '等待 /kcsapi/ 响应，游戏仍可正常操作。',
      GameCaptureState.capturing =>
        latestEvent?.path == '/kcsapi/api_port/port' &&
                latestEvent?.apiResult == 1
            ? '母港接口验证通过'
            : latestEvent == null
            ? '已经收到游戏接口。'
            : '最近一次捕获：${latestEvent.path}',
      GameCaptureState.unsupported => '游戏仍可运行；当前设备只提供网页浏览。',
      GameCaptureState.error =>
        captureController.errorMessage ?? '游戏仍可运行，可刷新页面后重试。',
    };
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.title,
    required this.subtitle,
    this.warning = false,
  });

  final String title;
  final String subtitle;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? const Color(0xff3a292b) : const Color(0xff142735),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: warning ? const Color(0xff75484a) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xff8197a5), height: 1.35),
          ),
        ],
      ),
    );
  }
}
