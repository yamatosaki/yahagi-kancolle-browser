import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_exit_settings.dart';
import '../widgets/top_notice.dart';
import 'game_surface_dialog.dart';

/// Protects root-route Back navigation while leaving Home navigation to Android.
class AppExitGuard extends StatefulWidget {
  const AppExitGuard({
    super.key,
    this.settingsController,
    required this.fullscreen,
    required this.onExitFullscreen,
    required this.child,
  });

  final AppExitSettingsController? settingsController;
  final bool fullscreen;
  final VoidCallback onExitFullscreen;
  final Widget child;

  @override
  State<AppExitGuard> createState() => _AppExitGuardState();
}

class _AppExitGuardState extends State<AppExitGuard> {
  static const _navigationChannel = MethodChannel(
    'app.yahagi.kancollebrowser/app_navigation',
  );

  bool _handlingExit = false;

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop || _handlingExit) return;
    if (widget.fullscreen) {
      widget.onExitFullscreen();
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && route.willHandlePopInternally) {
      // Closing local details must not be mistaken for leaving the app.
      Navigator.of(context).pop(result);
      return;
    }
    if (!(widget.settingsController?.enabled ?? true)) return;
    unawaited(_confirmExit());
  }

  Future<void> _confirmExit() async {
    _handlingExit = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showGameSurfaceDialog<bool>(
        context: context,
        title: l10n.appExitConfirmTitle,
        message: l10n.appExitConfirmDescription,
        actions: [
          GameSurfaceDialogAction(
            id: 'stay',
            label: l10n.appExitStay,
            value: false,
          ),
          GameSurfaceDialogAction(
            id: 'leave',
            label: l10n.appExitToDesktop,
            value: true,
          ),
        ],
        builder: (dialogContext, close) => AlertDialog(
          key: const Key('app-exit-confirm-dialog'),
          title: Text(l10n.appExitConfirmTitle),
          content: Text(l10n.appExitConfirmDescription),
          actions: [
            FilledButton(
              key: const Key('app-exit-stay'),
              onPressed: () => close(false),
              child: Text(l10n.appExitStay),
            ),
            TextButton(
              key: const Key('app-exit-to-desktop'),
              onPressed: () => close(true),
              child: Text(l10n.appExitToDesktop),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      // Background the task without finishing the Activity or its game WebView.
      final moved = await _navigationChannel.invokeMethod<bool>(
        'moveToBackground',
      );
      if (moved != true && mounted) _showExitFailure();
    } on PlatformException catch (_) {
      if (mounted) _showExitFailure();
    } on MissingPluginException catch (_) {
      if (mounted) _showExitFailure();
    } finally {
      _handlingExit = false;
    }
  }

  void _showExitFailure() {
    TopNotice.show(
      context,
      message: AppLocalizations.of(context)!.appExitFailed,
      tone: TopNoticeTone.error,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation:
        widget.settingsController ?? const AlwaysStoppedAnimation<bool>(true),
    child: widget.child,
    builder: (context, child) => PopScope<Object?>(
      // Keep root Back blocked even while local history is present, so another
      // Back cannot leave the app between its removal and the next frame.
      canPop:
          !widget.fullscreen && !(widget.settingsController?.enabled ?? true),
      onPopInvokedWithResult: _onPopInvoked,
      child: child!,
    ),
  );
}
