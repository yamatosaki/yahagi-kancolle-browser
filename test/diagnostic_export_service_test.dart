import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_export_service.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_kanxy_observer.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/diagnostics/kanxy');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory root;
  late Directory segments;
  late Directory exports;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('yahagi-export-');
    segments = Directory('${root.path}/segments');
    exports = Directory('${root.path}/exports');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> sendKanxyEvent(Object? arguments) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('kanxyEvent', arguments)),
        (_) {},
      );

  test('exports only allowlisted native Kanxy statuses', () async {
    final storage = DiagnosticStorage(directory: segments);
    final recorder = DiagnosticRecorder(sink: storage);
    final observer = DiagnosticKanxyObserver(recorder, channel: channel);
    addTearDown(recorder.dispose);
    addTearDown(observer.detach);
    observer.attach();
    final date = DateTime.utc(2026, 11, 13, 12);
    final event = <String, Object?>{
      'status': 'WS_OPEN',
      'occurredAtMs': date.millisecondsSinceEpoch,
    };

    await sendKanxyEvent(event);
    for (final malformed in <Object?>[
      null,
      'WS_OPEN',
      {'status': 'WS_OPEN'},
      {...event, 'status': 'WS_FUTURE_STATUS'},
      {...event, 'status': 'ws_open'},
      {...event, 'status': 'ws://127.0.0.1:5412/private'},
      {...event, 'occurredAtMs': '${date.millisecondsSinceEpoch}'},
      {...event, 'occurredAtMs': -1},
      {...event, 'occurredAtMs': 8640000000000001},
      {...event, 'port': 5412},
      {...event, 'data': 'private payload'},
    ]) {
      await sendKanxyEvent(malformed);
    }
    await recorder.flush();

    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: FakeDiagnosticPlatformPort(),
      appVersion: '1.10.0-beta.7+40',
    );
    final file = await service.exportAndShare();
    final decoded = jsonDecode(await file.readAsString()) as Map;
    expect(decoded['records'], <Object?>[
      <String, Object?>{
        'occurredAt': date.toIso8601String(),
        'type': 'kanxy',
        'fields': <String, Object?>{'status': 'WS_OPEN'},
      },
    ]);
  });

  test('Kanxy observer subscribes only while attached', () async {
    final changes = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setKanxyRecording');
      changes.add(call.arguments);
      return null;
    });
    final recorder = DiagnosticRecorder(
      sink: DiagnosticStorage(directory: segments),
    );
    final observer = DiagnosticKanxyObserver(recorder, channel: channel);
    addTearDown(recorder.dispose);
    addTearDown(observer.detach);
    const event = <String, Object?>{'status': 'ROUTE_VPN', 'occurredAtMs': 0};

    await sendKanxyEvent(event);
    observer.attach();
    observer.attach();
    await sendKanxyEvent(event);
    await recorder.setEnabled(false);
    await sendKanxyEvent(event);
    await recorder.setEnabled(true);
    observer.detach();
    observer.detach();
    await sendKanxyEvent(event);

    expect(changes, <bool>[true, false]);
    expect(
      await DiagnosticStorage(directory: segments).readRecords().length,
      1,
    );
    expect(recorder.bufferedEventCount, 0);
  });

  test('exports and shares one parseable json file', () async {
    final storage = DiagnosticStorage(directory: segments);
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.4+5',
      now: () => DateTime.utc(2026, 8, 13, 11, 30, 15),
    );

    final file = await service.exportAndShare();
    final decoded = jsonDecode(await file.readAsString()) as Map;

    expect(platform.sharedPaths, <String>[file.path]);
    expect(file.path, endsWith('.json'));
    expect(decoded['formatVersion'], 1);
    expect(decoded['records'], hasLength(1));
    expect(await file.length(), lessThanOrEqualTo(10 * 1024 * 1024));
  });

  test('exports more than 64 valid diagnostic records', () async {
    final storage = DiagnosticStorage(directory: segments);
    await storage.appendAll(
      List<DiagnosticEvent>.generate(
        70,
        (index) => DiagnosticEvent.lifecycle(
          occurredAt: DateTime.utc(2026, 8, 13).add(Duration(seconds: index)),
          state: DiagnosticLifecycleState.resumed,
          uptimeMs: index * 1000,
        ),
      ),
    );
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.4+5',
      now: () => DateTime.utc(2026, 8, 13, 11, 30, 15),
    );

    final file = await service.exportAndShare();
    final decoded = jsonDecode(await file.readAsString()) as Map;

    expect(decoded['records'], hasLength(70));
    expect(platform.sharedPaths, <String>[file.path]);
  });

  test('saves one audited json file through the platform port', () async {
    final storage = DiagnosticStorage(directory: segments);
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    final platform = FakeDiagnosticPlatformPort(
      savedName: 'Yahagi-Diagnostics-20260813-091445.json',
    );
    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.4+5',
      now: () => DateTime.utc(2026, 8, 13, 9, 14, 45),
    );

    final savedName = await service.save();

    expect(savedName, 'Yahagi-Diagnostics-20260813-091445.json');
    expect(platform.savedPaths, hasLength(1));
    expect(
      jsonDecode(await File(platform.savedPaths.single).readAsString()),
      isA<Map>(),
    );
    expect(platform.sharedPaths, isEmpty);
  });

  test('save cancellation returns null without sharing', () async {
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: DiagnosticStorage(directory: segments),
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.4+5',
    );

    expect(await service.save(), isNull);
    expect(platform.savedPaths, hasLength(1));
    expect(platform.sharedPaths, isEmpty);
  });

  test('privacy audit deletes an unsafe export and refuses sharing', () async {
    await segments.create(recursive: true);
    await File('${segments.path}/diagnostic-1-0.jsonl').writeAsString(
      '${jsonEncode(<String, Object?>{
        'occurredAt': '2026-08-13T00:00:00.000Z',
        'type': 'fixedError',
        'fields': <String, Object?>{'password': 'TEST_ONLY_SECRET_DO_NOT_USE'},
      })}\n',
    );
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: DiagnosticStorage(directory: segments),
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.4+5',
    );

    await expectLater(
      service.exportAndShare(),
      throwsA(isA<DiagnosticExportPrivacyException>()),
    );
    expect(platform.sharedPaths, isEmpty);
    expect(await exports.list().toList(), isEmpty);
  });
}

final class FakeDiagnosticPlatformPort implements DiagnosticPlatformPort {
  FakeDiagnosticPlatformPort({this.savedName});

  final String? savedName;
  final List<String> sharedPaths = <String>[];
  final List<String> savedPaths = <String>[];

  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() async =>
      const DiagnosticDeviceSnapshot(
        manufacturer: 'Google',
        model: 'Pixel',
        androidSdk: 35,
        androidRelease: '15',
        supportedAbi: 'arm64-v8a',
        memoryClassMb: 8192,
        screenWidthPx: 2400,
        screenHeightPx: 1080,
        webViewVersion: '139',
        previousExitReason: 'unavailable',
        previousExitStatus: 0,
        previousExitImportance: 0,
        previousExitPssKb: 0,
        previousExitRssKb: 0,
        previousExitTimestampMs: 0,
      );

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() async =>
      const DiagnosticRuntimeSnapshot(
        pssKb: 1,
        javaHeapKb: 1,
        nativeHeapKb: 1,
        graphicsKb: 1,
        privateOtherKb: 1,
        systemAvailableKb: 1,
        lowMemory: false,
      );

  @override
  Future<String?> saveJson(String path) async {
    savedPaths.add(path);
    return savedName;
  }

  @override
  Future<void> shareJson(String path) async => sharedPaths.add(path);
}
