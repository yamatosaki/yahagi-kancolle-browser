import '../theme/app_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/top_notice.dart';
import 'game_rendering_mode.dart';
import 'game_rendering_mode_controller.dart';
import 'settings_ui_helpers.dart';

class GameRenderingModeSection extends StatelessWidget {
  const GameRenderingModeSection({
    super.key,
    required this.controller,
    this.isBattleActive = false,
  });

  final GameRenderingModeController controller;
  final bool isBattleActive;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.isBusy)
            const LinearProgressIndicator(
              key: Key('rendering-mode-progress'),
              minHeight: 2,
            ),
          if (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android) ...<Widget>[
            _modeTile(
              context,
              key: const Key('rendering-mode-native-activity'),
              mode: GameRenderingMode.nativeActivityExperimental,
              title: l10n.gameRenderingModeNativeActivity,
              subtitle: l10n.gameRenderingModeNativeActivityDesc,
            ),
            Divider(color: appColor(context, Color(0xff294052)), height: 1),
          ],
          _modeTile(
            context,
            key: const Key('rendering-mode-compatibility'),
            mode: GameRenderingMode.compatibility,
            title: l10n.gameRenderingModeCompatibility,
            subtitle: l10n.gameRenderingModeCompatibilityDesc,
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          _modeTile(
            context,
            key: const Key('rendering-mode-standard'),
            mode: GameRenderingMode.standard,
            title: l10n.gameRenderingModeStandard,
            subtitle: l10n.gameRenderingModeStandardDesc,
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          _modeTile(
            context,
            key: const Key('rendering-mode-canvas'),
            mode: GameRenderingMode.canvasCompatibility,
            title: l10n.gameRenderingModeCanvas,
            subtitle: l10n.gameRenderingModeCanvasDesc,
          ),
        ],
      ),
    );
  }

  Widget _modeTile(
    BuildContext context, {
    required Key key,
    required GameRenderingMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected = controller.mode == mode;
    return InkWell(
      key: key,
      onTap: controller.isBusy || selected
          ? null
          : () => _requestChange(context, mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: appTextStyle(context, SettingsTileTypography.title),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: appTextStyle(
                      context,
                      SettingsTileTypography.description,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: appColor(
                context,
                selected ? const Color(0xff70c7bc) : const Color(0xff8197a5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestChange(
    BuildContext context,
    GameRenderingMode target,
  ) async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('rendering-mode-confirm-dialog'),
        title: Text(l10n.gameRenderingModeConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.gameRenderingModeConfirmMessage),
            if (isBattleActive) ...[
              const SizedBox(height: 12),
              Text(
                l10n.gameRenderingModeBattleWarning,
                key: const Key('rendering-mode-battle-warning'),
                style: TextStyle(
                  color: appColor(context, Colors.orangeAccent),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('rendering-mode-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('rendering-mode-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await controller.changeMode(target);
    if (!context.mounted) return;
    final applied =
        result.status == GameRenderingModeChangeStatus.applied ||
        result.status == GameRenderingModeChangeStatus.unchanged;
    TopNotice.show(
      context,
      message: applied
          ? l10n.gameRenderingModeApplied
          : l10n.gameRenderingModeFailed,
      tone: applied ? TopNoticeTone.success : TopNoticeTone.error,
    );
  }
}
