import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/release_check_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/startup_update_notice.dart';

void main() {
  testWidgets('shows one confirm-only dialog for a newer release', (
    tester,
  ) async {
    final checker = _FakeReleaseChecker(
      const UpdateAvailable(
        latestVersion: '1.0.2',
        releaseName: '1.0.2',
        releaseNotes: '',
        releaseUrl: 'https://example.test/release',
      ),
    );

    Widget build(String child) => MaterialApp(
      home: StartupUpdateNotice(
        checker: checker,
        currentVersion: '1.0.1',
        child: Scaffold(body: Text(child)),
      ),
    );

    await tester.pumpWidget(build('first'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('ヤハギ 1.0.2 已发布。'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.textContaining('GitHub'), findsNothing);
    expect(find.textContaining('下载'), findsNothing);
    expect(checker.calls, 1);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build('rebuilt'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsNothing);
    expect(checker.calls, 1);
  });

  testWidgets('keeps failed startup checks silent', (tester) async {
    final checker = _FakeReleaseChecker(const ReleaseCheckFailed());

    await tester.pumpWidget(
      MaterialApp(
        home: StartupUpdateNotice(
          checker: checker,
          currentVersion: '1.0.1',
          child: const Scaffold(body: Text('ready')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('ready'), findsOneWidget);
    expect(checker.calls, 1);
  });
}

final class _FakeReleaseChecker implements ReleaseChecker {
  _FakeReleaseChecker(this.result);

  final ReleaseCheckResult result;
  int calls = 0;

  @override
  Future<ReleaseCheckResult> check({required String currentVersion}) async {
    calls += 1;
    return result;
  }
}
