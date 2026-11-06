import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../browser/game_browser_controller.dart';
import '../widgets/top_notice.dart';
import 'game_connector.dart';
import 'game_connector_controller.dart';
import 'settings_ui_helpers.dart';

class GameConnectorSection extends StatelessWidget {
  const GameConnectorSection({
    super.key,
    required this.controller,
    required this.browserController,
  });

  final GameConnectorController controller;
  final GameBrowserController browserController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (controller.isBusy)
            const LinearProgressIndicator(
              key: Key('game-connector-progress'),
              minHeight: 2,
            ),
          _connectorTile(
            context,
            key: const Key('game-connector-yahagi'),
            connector: GameConnector.yahagi,
            title: l10n.gameConnectorYahagi,
            subtitle: l10n.gameConnectorYahagiDesc,
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          _connectorTile(
            context,
            key: const Key('game-connector-ooi'),
            connector: GameConnector.ooi,
            title: l10n.gameConnectorOoi,
            subtitle: l10n.gameConnectorOoiDesc,
          ),
        ],
      ),
    );
  }

  Widget _connectorTile(
    BuildContext context, {
    required Key key,
    required GameConnector connector,
    required String title,
    required String subtitle,
  }) {
    final selected = controller.connector == connector;
    return InkWell(
      key: key,
      onTap: controller.isBusy || selected
          ? null
          : () => _requestChange(context, connector),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
    GameConnector target,
  ) async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final gameWasActive = browserController.isOfficialGamePage;
    if (gameWasActive || target == GameConnector.ooi) {
      final confirmed = await showDialog<bool>(
        barrierDismissible: false,
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('game-connector-confirm-dialog'),
          title: Text(l10n.gameConnectorConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (target == GameConnector.ooi) Text(l10n.gameConnectorOoiRisk),
              if (target == GameConnector.ooi && gameWasActive)
                const SizedBox(height: 12),
              if (gameWasActive)
                Text(
                  l10n.gameConnectorActiveWarning,
                  style: TextStyle(
                    color: appColor(context, Colors.orangeAccent),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('cancel-game-connector-change'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirm-game-connector-change'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final result = await controller.change(target);
    if (!context.mounted) return;
    if (result == GameConnectorChangeResult.saveFailed ||
        result == GameConnectorChangeResult.busy) {
      TopNotice.show(
        context,
        message: l10n.gameConnectorSaveFailed,
        tone: TopNoticeTone.error,
      );
      return;
    }

    try {
      await browserController.switchHome(target.entryUri);
      if (!context.mounted) return;
      TopNotice.show(
        context,
        message: l10n.gameConnectorApplied,
        tone: TopNoticeTone.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      TopNotice.show(
        context,
        message: l10n.gameConnectorNavigationFailed,
        tone: TopNoticeTone.error,
      );
    }
  }
}
