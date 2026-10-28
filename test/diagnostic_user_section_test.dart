import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_controller.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_export_service.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';
import 'package:yahagi_kancolle_browser/src/settings/diagnostic_user_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/about_support_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets(
    'about entry opens diagnostic controls before the original declarations',
    (tester) async {
      final fixture = _Fixture.create();
      addTearDown(() => fixture.dispose(tester));
      await tester.pumpWidget(fixture.app(about: true));
      final entry = find.byKey(const Key('settings-diagnostics-entry'));
      expect(entry, findsOneWidget);
      expect(
        tester.getTopLeft(entry).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('about-disclaimer-scroll')))
              .dy,
        ),
      );
      expect(find.byKey(const Key('diagnosticLoggingSwitch')), findsNothing);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diagnosticLoggingSwitch')), findsOneWidget);
      expect(find.byKey(const Key('saveDiagnosticFileButton')), findsOneWidget);
      expect(
        find.byKey(const Key('shareDiagnosticFileButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('clearDiagnosticDataButton')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('telemetryStatsSwitch')), findsNothing);
      await tester.tap(find.byKey(const Key('saveDiagnosticFileButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('confirmSaveDiagnosticFileButton')),
      );
      await _waitForExport(tester, fixture, fixture.platform.saveCalled);
      expect(find.text('已保存：Yahagi-Diagnostics-test.json'), findsOneWidget);
      expect(find.byKey(topNoticeKey), findsOneWidget);
    },
  );

  testWidgets('offers local save sharing and clear as separate actions', (
    tester,
  ) async {
    final fixture = _Fixture.create();
    addTearDown(() => fixture.dispose(tester));
    await tester.pumpWidget(fixture.app());

    expect(find.byKey(const Key('saveDiagnosticFileButton')), findsOneWidget);
    expect(find.byKey(const Key('shareDiagnosticFileButton')), findsOneWidget);
    expect(find.byKey(const Key('clearDiagnosticDataButton')), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.text('分享诊断文件'), findsOneWidget);
  });

  testWidgets('successful save reports success in a top notice', (
    tester,
  ) async {
    final fixture = _Fixture.create();
    addTearDown(() => fixture.dispose(tester));
    await tester.pumpWidget(fixture.app());

    await tester.tap(find.byKey(const Key('saveDiagnosticFileButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSaveDiagnosticFileButton')));
    await _waitForExport(tester, fixture, fixture.platform.saveCalled);

    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(find.text('已保存：Yahagi-Diagnostics-test.json'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('share exception reports error in a top notice', (tester) async {
    final fixture = _Fixture.create(shareFails: true);
    addTearDown(() => fixture.dispose(tester));
    await tester.pumpWidget(fixture.app());

    await tester.tap(find.byKey(const Key('shareDiagnosticFileButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmShareDiagnosticFileButton')));
    await _waitForExport(tester, fixture, fixture.platform.shareCalled);

    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(find.text('诊断文件分享失败'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelled save does not show a top notice', (tester) async {
    final fixture = _Fixture.create(savedName: null);
    addTearDown(() => fixture.dispose(tester));
    await tester.pumpWidget(fixture.app());

    await tester.tap(find.byKey(const Key('saveDiagnosticFileButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSaveDiagnosticFileButton')));
    await _waitForExport(tester, fixture, fixture.platform.saveCalled);

    expect(find.byKey(topNoticeKey), findsNothing);
  });
}

Future<void> _waitForExport(
  WidgetTester tester,
  _Fixture fixture,
  Completer<void> platformCall,
) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (platformCall.isCompleted && !fixture.controller.exporting) {
      await tester.pump();
      return;
    }
  }
  fail('Diagnostic export did not finish');
}

final class _Fixture {
  _Fixture({
    required this.root,
    required this.controller,
    required this.platform,
    required this.recorder,
  });

  final Directory root;
  final DiagnosticController controller;
  final _FakePlatform platform;
  final DiagnosticRecorder recorder;

  static _Fixture create({
    bool shareFails = false,
    String? savedName = 'Yahagi-Diagnostics-test.json',
  }) {
    final root = Directory.systemTemp.createTempSync('diagnostic-section-');
    final storage = DiagnosticStorage(directory: Directory('${root.path}/log'));
    final recorder = DiagnosticRecorder(sink: storage, enabled: false);
    final platform = _FakePlatform(
      shareFails: shareFails,
      savedName: savedName,
    );
    final controller = DiagnosticController(
      settings: MemoryDiagnosticSettingsStore(false),
      storage: storage,
      recorder: recorder,
      exporter: DiagnosticExportService(
        storage: storage,
        exportDirectory: Directory('${root.path}/export'),
        platform: platform,
        appVersion: 'test',
      ),
      manageGlobalErrors: false,
    );
    return _Fixture(
      root: root,
      controller: controller,
      platform: platform,
      recorder: recorder,
    );
  }

  Widget app({bool about = false}) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TopNoticeHost(
      child: Scaffold(
        body: about
            ? AboutSupportSettingsPage(
                currentVersion: 'test',
                diagnosticController: controller,
              )
            : DiagnosticUserSection(controller: controller),
      ),
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await recorder.dispose();
    await tester.runAsync(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
  }
}

final class _FakePlatform implements DiagnosticPlatformPort {
  _FakePlatform({
    this.shareFails = false,
    this.savedName = 'Yahagi-Diagnostics-test.json',
  });

  final bool shareFails;
  final String? savedName;
  final Completer<void> saveCalled = Completer<void>();
  final Completer<void> shareCalled = Completer<void>();

  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() async =>
      const DiagnosticDeviceSnapshot(
        manufacturer: 'test',
        model: 'test',
        androidSdk: 35,
        androidRelease: '15',
        supportedAbi: 'arm64-v8a',
        memoryClassMb: 256,
        screenWidthPx: 1080,
        screenHeightPx: 1920,
        webViewVersion: 'test',
        previousExitReason: 'unknown',
        previousExitStatus: 0,
        previousExitImportance: 0,
        previousExitPssKb: 0,
        previousExitRssKb: 0,
        previousExitTimestampMs: 0,
      );

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() =>
      throw UnimplementedError();

  @override
  Future<String?> saveJson(String path) async {
    saveCalled.complete();
    return savedName;
  }

  @override
  Future<void> shareJson(String path) async {
    shareCalled.complete();
    if (shareFails) throw StateError('share failed');
  }
}
