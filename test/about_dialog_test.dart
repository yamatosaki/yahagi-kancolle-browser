import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/about_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/about_support_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_check_service.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Widget withTopNotice(Widget child) => MaterialApp(
  home: TopNoticeHost(child: Scaffold(body: child)),
);

void main() {
  testWidgets(
    'version labels are compact while the checker receives the canonical value',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final checker = _FakeReleaseChecker(
        const UpdateAvailable(
          latestVersion: '1.11.0-beta.2',
          releaseName: '1.11.0-beta.2',
          releaseNotes: '',
          releaseUrl: 'https://example.test/releases/v1.11-beta2',
        ),
      );
      await tester.pumpWidget(
        withTopNotice(
          AboutContentWidget(
            currentVersion: '1.10.0-beta.1',
            releaseChecker: checker,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1.10 Beta1'), findsOneWidget);
      expect(find.textContaining('1.10.0-beta.1'), findsNothing);

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(checker.currentVersion, '1.10.0-beta.1');
      expect(find.text('当前版本: 1.10 Beta1'), findsOneWidget);
      expect(find.text('最新版本: 1.11 Beta2'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GitHub button directly launches the repository URL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Uri? launchedUri;
    await tester.pumpWidget(
      withTopNotice(
        AboutContentWidget(
          externalUrlLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.textContaining('GitHub'));
    await tester.pump();

    expect(launchedUri, Uri.parse(AboutContentWidget.githubUrl));
  });

  testWidgets('GitHub button reports an external launch failure', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      withTopNotice(
        AboutContentWidget(externalUrlLauncher: (_) async => false),
      ),
    );

    await tester.tap(find.textContaining('GitHub'));
    await tester.pump();

    expect(find.text('无法打开链接，请检查是否已安装浏览器。'), findsOneWidget);
    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('download reports a launch failure after closing update dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const releaseUrl = 'https://example.test/releases/1.1.0';
    Uri? launchedUri;
    await tester.pumpWidget(
      withTopNotice(
        AboutContentWidget(
          currentVersion: '1.0.2',
          releaseChecker: _FakeReleaseChecker(
            const UpdateAvailable(
              latestVersion: '1.1.0',
              releaseName: '1.1.0',
              releaseNotes: 'release notes',
              releaseUrl: releaseUrl,
            ),
          ),
          externalUrlLauncher: (uri) async {
            launchedUri = uri;
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('🚀 发现新版本！'), findsOneWidget);

    await tester.tap(find.text('前往下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(launchedUri, Uri.parse(releaseUrl));
    expect(find.byType(AlertDialog), findsNothing);
    final notice = find.byKey(topNoticeKey);
    expect(notice, findsOneWidget);
    expect(
      find.descendant(of: notice, matching: find.text('无法打开链接，请检查是否已安装浏览器。')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notice,
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('about dialog fits a compact landscape viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(820, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(withTopNotice(const AboutContentWidget()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('about-disclaimer-scroll')), findsOneWidget);
    expect(find.textContaining('1.0.2'), findsOneWidget);
  });

  testWidgets('about header wraps actions on a narrow viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      withTopNotice(const AboutSupportSettingsPage(currentVersion: '1.0.2')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final github = tester.getRect(find.textContaining('GitHub'));
    final update = tester.getRect(find.text('检查更新'));
    expect(github.left, greaterThanOrEqualTo(0));
    expect(github.right, lessThanOrEqualTo(320));
    expect(update.left, greaterThanOrEqualTo(0));
    expect(update.right, lessThanOrEqualTo(320));
  });

  testWidgets('compact landscape keeps the full about content reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      withTopNotice(const AboutSupportSettingsPage(currentVersion: '1.0.2')),
    );
    await tester.pumpAndSettle();

    final scroll = find.byType(SingleChildScrollView).first;
    expect(scroll, findsOneWidget);
    expect(tester.getSize(scroll).height, greaterThanOrEqualTo(140));
    await tester.drag(scroll, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-disclaimer-end')), findsOneWidget);
    expect(find.textContaining('HarmonyOS Sans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeReleaseChecker implements ReleaseChecker {
  _FakeReleaseChecker(this.result);

  final ReleaseCheckResult result;
  String? currentVersion;

  @override
  Future<ReleaseCheckResult> check({required String currentVersion}) async {
    this.currentVersion = currentVersion;
    return result;
  }
}
