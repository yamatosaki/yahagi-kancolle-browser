import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

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
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));
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
            Text(
              l10n.diagnosticsAndAbout,
              style: const TextStyle(
                color: Color(0xffd4a85f),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _DiagnosticCard(
              title: _browserStateLabel(l10n, browserController.loadState),
              subtitle:
                  browserController.errorMessage ??
                  browserController.displayAddress,
              warning: browserController.loadState == GamePageLoadState.failed,
            ),
            const SizedBox(height: 8),
            _DiagnosticCard(
              title: captureModeController.mode == CaptureMode.browserOnly
                  ? l10n.browserOnlyCaptureOff
                  : _captureStateTitle(l10n, gameCaptureController.state),
              subtitle: captureModeController.mode == CaptureMode.browserOnly
                  ? l10n.browserOnlyCaptureOffDesc
                  : _captureStateSubtitle(l10n, gameCaptureController, event),
              warning:
                  gameCaptureController.state == GameCaptureState.error ||
                  gameCaptureController.state == GameCaptureState.unsupported,
            ),
            const SizedBox(height: 8),
            _DiagnosticCard(
              title: l10n.capturedCount(capturedCount),
              subtitle: event == null
                  ? l10n.waitingKcsapi
                  : '${event.source.label} · ${event.capturedAt.toLocal()}',
            ),
            if (prototypeStatusController.lastBridgeError
                case final error?) ...[
              const SizedBox(height: 8),
              _DiagnosticCard(
                title: l10n.ignoredNonTargetMessage,
                subtitle: error,
                warning: true,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.safetyBoundary,
              style: const TextStyle(
                color: Color(0xffd4a85f),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _DiagnosticCard(
              title: l10n.readOnlyNoActions,
              subtitle: l10n.readOnlyNoActionsDesc,
            ),
            const SizedBox(height: 8),
            _DiagnosticCard(
              title: l10n.noCookieRead,
              subtitle: l10n.noCookieReadDesc,
            ),
          ],
        );
      },
    );
  }

  String _browserStateLabel(AppLocalizations l10n, GamePageLoadState state) {
    return switch (state) {
      GamePageLoadState.idle => l10n.browserIdle,
      GamePageLoadState.loading => l10n.browserLoading,
      GamePageLoadState.ready => l10n.browserReady,
      GamePageLoadState.failed => l10n.browserFailed,
    };
  }

  String _captureStateTitle(AppLocalizations l10n, GameCaptureState state) {
    return switch (state) {
      GameCaptureState.disabled => l10n.capturePreparing,
      GameCaptureState.checking => l10n.capturePreparing,
      GameCaptureState.ready => l10n.captureReady,
      GameCaptureState.capturing => l10n.captureActive,
      GameCaptureState.unsupported => l10n.captureUnsupported,
      GameCaptureState.error => l10n.captureFailed,
    };
  }

  String _captureStateSubtitle(
    AppLocalizations l10n,
    GameCaptureController captureController,
    CapturedApiEvent? latestEvent,
  ) {
    return switch (captureController.state) {
      GameCaptureState.disabled ||
      GameCaptureState.checking => l10n.captureCheckingDesc,
      GameCaptureState.ready => l10n.captureReadyDesc,
      GameCaptureState.capturing =>
        latestEvent?.path == '/kcsapi/api_port/port' &&
                latestEvent?.apiResult == 1
            ? l10n.portCaptureVerified
            : latestEvent == null
            ? l10n.captureReceived
            : l10n.captureLatest(latestEvent.path),
      GameCaptureState.unsupported => l10n.captureUnsupportedDesc,
      GameCaptureState.error =>
        captureController.errorMessage ?? l10n.captureFailedDesc,
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
