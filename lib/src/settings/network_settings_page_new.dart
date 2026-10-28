import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../account/account_session.dart';
import '../game_state/game_state_controller.dart';
import '../logbook/logbook_database.dart';
import '../widgets/top_notice.dart';
import 'settings_organization_strings.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import 'gadget_bypass_section.dart';
import 'network_settings_controller.dart';
import 'game_connector_controller.dart';
import 'game_connector_section.dart';
import 'network_settings_section.dart';
import 'settings_ui_helpers.dart';

class NetworkSettingsPageNew extends StatelessWidget with SettingsUIHelpers {
  const NetworkSettingsPageNew({
    super.key,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.browserController,
    this.gameConnectorController,
    this.gameStateController,
    this.accountSession,
  });

  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final GameBrowserController browserController;
  final GameConnectorController? gameConnectorController;
  final GameStateController? gameStateController;
  final AccountSession? accountSession;

  AccountSession get _accountSession =>
      accountSession ??
      gameStateController?.accountSession ??
      LogbookDatabase.accountSession;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (gameConnectorController case final connector?) ...<Widget>[
              buildSectionTitle(l10n.gameConnectorTitle),
              buildCard(
                child: GameConnectorSection(
                  controller: connector,
                  browserController: browserController,
                ),
              ),
              const SizedBox(height: 24),
            ],
            buildSectionTitle(l10n.networkSettings),
            buildCard(
              child: NetworkSettingsSection(
                controller: networkSettingsController,
                onApplySuccess: () {
                  // Reload game page
                  browserController.reload();
                },
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.gadgetBypass),
            buildCard(
              child: GadgetBypassSection(
                controller: gadgetBypassController,
                onReloadRequired: browserController.reload,
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(
              settingsOrganizationText(context, 'settingsGroupAccount'),
            ),
            buildCard(
              child: buildActionTile(
                title: l10n.logoutAndClear,
                titleKey: const Key('settings-logout-label'),
                subtitle: l10n.logoutAndClearDesc,
                trailing: Icon(
                  Icons.logout,
                  color: appColor(context, const Color(0xffd4a85f)),
                ),
                onTap: () => _logoutAndClear(context, l10n),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _logoutAndClear(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final confirmed = await _showAccountDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmDesc),
        backgroundColor: appColor(context, const Color(0xff142735)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !session.isCurrent(scope)) return;
    try {
      await browserController.logoutAndClearSession();
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.logoutSucceeded,
          tone: TopNoticeTone.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.logoutFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Future<T?> _showAccountDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    final session = _accountSession;
    final scope = session.current;
    final route = DialogRoute<T>(context: context, builder: builder);
    void dismissStaleDialog() {
      if (!session.isCurrent(scope) && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }

    session.addListener(dismissStaleDialog);
    try {
      return await Navigator.of(context, rootNavigator: true).push<T>(route);
    } finally {
      session.removeListener(dismissStaleDialog);
    }
  }
}
