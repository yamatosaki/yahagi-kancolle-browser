import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'game_rendering_mode.dart';
import 'game_rendering_mode_controller.dart';

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
          _modeTile(
            context,
            key: const Key('rendering-mode-compatibility'),
            mode: GameRenderingMode.compatibility,
            title: l10n.gameRenderingModeCompatibility,
            subtitle: l10n.gameRenderingModeCompatibilityDesc,
          ),
          const Divider(color: Color(0xff294052), height: 1),
          _modeTile(
            context,
            key: const Key('rendering-mode-standard'),
            mode: GameRenderingMode.standard,
            title: l10n.gameRenderingModeStandard,
            subtitle: l10n.gameRenderingModeStandardDesc,
          ),
          const Divider(color: Color(0xff294052), height: 1),
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
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.only(left: 4, right: 16),
      minLeadingWidth: 0,
      horizontalTitleGap: 0,
      enabled: !controller.isBusy,
      selected: selected,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? const Color(0xff70c7bc) : null,
      ),
      onTap: controller.isBusy || selected
          ? null
          : () => _requestChange(context, mode),
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
                style: const TextStyle(
                  color: Colors.orangeAccent,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? l10n.gameRenderingModeApplied
              : l10n.gameRenderingModeFailed,
        ),
      ),
    );
  }
}
