import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_page_new.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('network account action keeps logout confirmation and success', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    expect(find.text('账号操作'), findsOneWidget);
    final logout = find.byKey(const Key('settings-logout-label'));
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(fixture.port.clearSessionCalls, 0);
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.tap(find.text(l10n.confirmClear));
    await tester.pumpAndSettle();
    expect(fixture.port.clearSessionCalls, 1);
    expect(fixture.port.loads, 1);
    expect(find.text(l10n.logoutSucceeded), findsOneWidget);
  });

  testWidgets('account switch cancels pending network logout', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app());
    final logout = find.byKey(const Key('settings-logout-label'));
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    fixture.session.selectMember(2002);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(fixture.port.clearSessionCalls, 0);
    expect(fixture.port.loads, 0);
  });
}

final class _Fixture {
  _Fixture() {
    browser = GameBrowserController(port: port);
  }
  final session = AccountSession(initialMemberId: 1001);
  final port = _BrowserPort();
  late final GameBrowserController browser;
  final network = NetworkSettingsController(store: _NetworkStore());
  final bypass = GadgetBypassController(
    store: _BypassStore(),
    port: MethodChannelGadgetBypassPort(),
  );
  Widget app() => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TopNoticeHost(
      child: Scaffold(
        body: NetworkSettingsPageNew(
          networkSettingsController: network,
          gadgetBypassController: bypass,
          browserController: browser,
          accountSession: session,
        ),
      ),
    ),
  );
  void dispose() {
    session.dispose();
    browser.dispose();
    network.dispose();
    bypass.dispose();
  }
}

final class _NetworkStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();
  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}

final class _BypassStore implements GadgetBypassStore {
  @override
  Future<GadgetBypassSettings> load() async => const GadgetBypassSettings();
  @override
  Future<void> save(GadgetBypassSettings settings) async {}
}

final class _BrowserPort implements GameBrowserPort {
  int clearSessionCalls = 0;
  int loads = 0;
  @override
  Future<void> clearSession() async => clearSessionCalls++;
  @override
  Future<void> loadUri(Uri uri) async => loads++;
  @override
  Future<void> clearCache() async {}
  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<void> goBack() async {}
  @override
  Future<void> showLocalHome() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<GameFrameReloadResult> reloadGameFrame() async =>
      GameFrameReloadResult.reloaded;
  @override
  Future<void> runJavaScript(String javascript) async {}
  @override
  Future<void> fitGameScreen() async {}
}
