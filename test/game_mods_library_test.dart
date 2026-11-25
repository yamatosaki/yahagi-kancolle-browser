import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_library.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_port.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_strings.dart';

import 'game_mods_controller_test.dart' show FakeGameModsPort;
import 'support/game_mod_portrait_platform_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockGameModPortraitPlatform);
  tearDown(clearGameModPortraitPlatformMock);

  test('every scan status detail from Android has an English translation', () {
    final library = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/mods/GameModLibrary.kt',
    ).readAsLinesSync();
    final messages = <String>{};
    final statusDetail = RegExp(r'"([^"]*[\u3400-\u9fff][^"]*)"');
    for (final line in library) {
      if (line.contains('items.add(item(') || line.contains('row["error"]')) {
        for (final match in statusDetail.allMatches(line)) {
          messages.add(match[1]!);
        }
      }
    }
    expect(messages, contains('公共目录中的文件已缺失，当前生效副本会保留。'));
    const english = GameModsStrings(Locale('en'));
    for (final message in messages) {
      final result = english.libraryScanDetail(message);
      expect(
        result,
        isNot(contains(RegExp(r'[\u3400-\u9fff]'))),
        reason: message,
      );
    }
  });

  test('scan diagnostics preserve unknown provider text and literal paths', () {
    const hant = GameModsStrings(Locale('zh', 'HK'));
    const unknown = '  提供者：無法開啟 /路径/画像.png  ';
    expect(hant.libraryScanDetail(unknown), unknown);
    expect(
      hant.libraryScanDetail(
        'Invalid or unsupported display table: text/英:语/表.json',
      ),
      '顯示文字表無效或不受支援：text/英:语/表.json',
    );
    expect(hant.libraryScanDetail('文件读取失败。 '), '無法讀取檔案。');
    expect(hant.libraryScanDetail('单个魔改文件不能超过 64 MiB。'), contains('64 MiB'));
  });

  test(
    'library channel sends token operations and decodes scan/status',
    () async {
      const channel = MethodChannel('test/game_mod_library');
      const port = MethodChannelGameModsPort(channel);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'chooseLibraryDirectory' => true,
              'scanLibrary' => {
                'token': 'checked',
                'restoreAvailable': true,
                'entries': [
                  {
                    'id': 'pkg',
                    'name': '伊47',
                    'kind': 'updated',
                    'supportedCount': 3,
                    'resourceCount': 3,
                  },
                ],
              },
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(await port.chooseLibraryDirectory(), isTrue);
      await port.openLibraryDirectory();
      final scan = await port.scanLibrary();
      expect(scan.entries.single.kind, GameModLibraryEntryKind.updated);
      expect(scan.entries.single.name, '伊47');
      expect(scan.restoreAvailable, isTrue);
      await port.commitLibraryScan(scan.token);
      await port.discardLibraryScan('cancelled');
      expect(calls.map((c) => c.method), [
        'chooseLibraryDirectory',
        'openLibraryDirectory',
        'scanLibrary',
        'commitLibraryScan',
        'discardLibraryScan',
      ]);
      expect(calls[3].arguments, {'token': 'checked'});
      expect(calls[4].arguments, {'token': 'cancelled'});
    },
  );

  test('library status survives draft and runtime merges', () {
    final status = GameModsStatus.fromMap({
      'library': {
        'configured': true,
        'available': false,
        'displayName': 'Mods',
        'error': 'library_permission_lost',
        'packageCount': 3,
      },
    });
    expect(status.library.configured, isTrue);
    expect(status.library.available, isFalse);
    expect(
      status.withDraft(const GameModsConfig(master: true)).library.displayName,
      'Mods',
    );
    expect(status.withRuntimeFrom(status).library.packageCount, 3);
    expect(
      GameModsStatus.fromMap(status.toMap()).library.error,
      'library_permission_lost',
    );
  });

  test(
    'ZIP cleanup alone is a confirmable scan change and defaults to zero',
    () {
      final scan = GameModLibraryScan.fromMap({
        'token': 'cleanup',
        'cleanupCount': 2,
        'entries': [
          {'id': 'existing', 'name': 'Existing', 'kind': 'unchanged'},
        ],
      });
      expect(scan.hasChanges, isTrue);
      expect(scan.cleanupCount, 2);
      final legacy = GameModLibraryScan.fromMap({'token': 'legacy'});
      expect(legacy.cleanupCount, 0);
      expect(legacy.hasChanges, isFalse);
    },
  );

  test('cancelling directory selection never opens archive picker', () async {
    final port = _LibraryPort()..chooseResult = false;
    final c = GameModsController(port: port);
    addTearDown(c.dispose);
    await c.initialize();
    await c.pickArchive();
    expect(port.chooseCalls, 1);
    expect(port.pickerCalls, 0);
    expect(c.preflight, isNull);
    expect(c.supported, isTrue);
  });

  test(
    'unavailable folder is reselected before importing and no apply occurs',
    () async {
      final port = _LibraryPort()
        ..setLibrary(configured: true, available: false);
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      await c.pickArchive();
      expect(port.chooseCalls, 1);
      expect(port.pickerCalls, 1);
      expect(port.applyCalls, 0);
      expect(c.status.library.available, isTrue);
    },
  );

  test(
    'scan preview retains every outcome and cancellation changes nothing',
    () async {
      final port = _LibraryPort()..setLibrary();
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      final before = c.status.toMap();
      await c.scanLibrary();
      expect(
        c.libraryScan!.entries.map((e) => e.kind),
        GameModLibraryEntryKind.values,
      );
      expect(c.libraryScan!.restoreAvailable, isTrue);
      expect(port.committed, isEmpty);
      await c.cancelLibraryScan();
      expect(port.discardedScans, ['scan-1']);
      expect(c.libraryScan, isNull);
      expect(c.status.toMap(), before);
      expect(port.applyCalls, 0);
    },
  );

  test(
    'confirm scan flushes draft and updates status without applying',
    () async {
      final port = _LibraryPort()..setLibrary();
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      c.setPackageEnabled('b', false);
      await c.scanLibrary();
      await c.confirmLibraryScan();
      expect(port.committed, ['scan-1']);
      expect(port.saved.last.enabledPackages, {'a'});
      expect(c.libraryScan, isNull);
      expect(port.applyCalls, 0);
      expect(c.status.packages.any((p) => p.id == 'new'), isTrue);
      expect(c.status.draft.enabledPackages.contains('new'), isFalse);
    },
  );

  test(
    'scan failure preserves current packages and reports library error',
    () async {
      final port = _LibraryPort()
        ..setLibrary()
        ..scanFailure = true;
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      final before = c.status.toMap();
      await c.scanLibrary();
      expect(c.status.toMap(), before);
      expect(c.errorCode, 'library_permission_lost');
      expect(c.supported, isTrue);
      expect(c.busy, isFalse);
    },
  );

  test(
    'an absent optional library API does not disable mod management',
    () async {
      final port = _LibraryPort()
        ..setLibrary()
        ..missingLibrary = true;
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      await c.scanLibrary();
      expect(c.errorCode, 'library_unavailable');
      expect(c.supported, isTrue);
      expect(c.canEdit, isTrue);
      expect(c.status.packages.length, 2);
    },
  );

  test(
    'failed scan commit clears expired preview refreshes partial draft and allows a fresh scan',
    () async {
      final port = _LibraryPort()
        ..setLibrary()
        ..failCommit = true
        ..partialCommitFailure = true;
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      await c.scanLibrary();
      await c.confirmLibraryScan();
      expect(c.errorCode, 'library_scan_expired');
      expect(c.libraryScan, isNull);
      expect(c.status.packages.any((p) => p.id == 'partial'), isTrue);
      expect(c.lastApplyResult, isNull);
      expect(port.applyCalls, 0);
      port.failCommit = false;
      await c.scanLibrary();
      expect(c.libraryScan?.token, 'scan-2');
      await c.confirmLibraryScan();
      expect(c.libraryScan, isNull);
      expect(c.errorCode, isNull);
      expect(port.committed, ['scan-2']);
      expect(c.status.packages.any((p) => p.id == 'new'), isTrue);
      expect(port.applyCalls, 0);
    },
  );

  test('disposing an open scan discards temporary candidate', () async {
    final port = _LibraryPort()..setLibrary();
    final c = GameModsController(port: port);
    await c.initialize();
    await c.scanLibrary();
    c.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(port.discardedScans, ['scan-1']);
  });

  test('a scan finishing after dispose discards its staged files', () async {
    final port = _LibraryPort()
      ..setLibrary()
      ..scanGate = Completer<void>();
    final c = GameModsController(port: port);
    await c.initialize();
    final scanning = c.scanLibrary();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    port.scanGate!.complete();
    await scanning;
    expect(port.discardedScans, ['scan-1']);
    expect(port.committed, isEmpty);
  });

  test(
    'delete all remains reversible and does not apply until confirmed in footer',
    () async {
      final port = _LibraryPort()..setLibrary();
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await c.initialize();
      final before = c.status.applied;
      for (var i = 0; i < 3; i++) {
        await c.resetAll();
        expect(port.applyCalls, 0);
        expect(c.status.pending, isTrue);
        expect(c.status.packages.every((p) => p.pendingRemoval), isTrue);
        await c.cancelChanges();
        expect(c.status.pending, isFalse);
        expect(c.status.draft.sameAs(before), isTrue);
        expect(c.status.packages.length, 2);
        expect(c.status.library.available, isTrue);
      }
      await c.resetAll();
      await c.apply();
      expect(port.applyCalls, 1);
      expect(c.status.packages, isEmpty);
      expect(c.status.draft.master, isFalse);
    },
  );

  testWidgets(
    'delete all keeps red cards and footer cancel restores public library choices',
    (tester) async {
      tester.view.physicalSize = const Size(720, 832);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final port = _LibraryPort()..setLibrary();
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(body: GameModsPage(controller: c, visible: false)),
        ),
      );
      await tester.pumpAndSettle();
      final enabled = find.widgetWithText(FilterChip, 'Enabled 2');
      await tester.ensureVisible(enabled);
      await tester.pumpAndSettle();
      await tester.tap(enabled);
      await tester.pumpAndSettle();
      final reset = find.byKey(const Key('game-mods-reset'));
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(port.applyCalls, 0);
      expect(c.status.pending, isTrue);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'All 2'))
            .selected,
        isTrue,
      );
      final card = find.byKey(const Key('game-mods-card-a'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final decoration =
          tester.widget<Container>(card).decoration! as BoxDecoration;
      expect(decoration.color!.r, greaterThan(decoration.color!.g));
      await tester.tap(find.byKey(const Key('game-mods-cancel')));
      await tester.pumpAndSettle();
      expect(c.status.packages.every((p) => !p.pendingRemoval), isTrue);
      expect(c.status.draft.enabledPackages, {'a', 'b'});
      expect(c.status.library.available, isTrue);
      expect(c.status.pending, isFalse);
      expect(port.applyCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide resource folder panel keeps three outlined capsules inline and compact',
    (tester) async {
      tester.view.physicalSize = const Size(750, 832);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final port = _LibraryPort()..setLibrary();
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: const [Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: GameModsPage(controller: c, visible: false)),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const Key('game-mods-library'));
      await tester.ensureVisible(panel);
      expect(find.text('魔改资源文件夹'), findsOneWidget);
      expect(tester.getSize(panel).height, lessThanOrEqualTo(112));
      final buttons = [
        'choose',
        'open',
        'scan',
      ].map((id) => find.byKey(Key('game-mods-library-$id'))).toList();
      final first = tester.getCenter(buttons.first).dy;
      for (final button in buttons) {
        expect(tester.widget(button), isA<OutlinedButton>());
        expect(tester.getCenter(button).dy, closeTo(first, .1));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      }
      expect(
        tester.getTopLeft(buttons.first).dy,
        lessThan(
          tester
              .getBottomRight(
                find.byKey(const Key('game-mods-library-location')),
              )
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Japanese folder actions wrap below readable identity at the inline width boundary',
    (tester) async {
      tester.view.physicalSize = const Size(650, 832);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final port = _LibraryPort()..setLibrary();
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          supportedLocales: const [Locale('ja')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
          home: Scaffold(body: GameModsPage(controller: c, visible: false)),
        ),
      );
      await tester.pumpAndSettle();
      final location = find.byKey(const Key('game-mods-library-location'));
      final choose = find.byKey(const Key('game-mods-library-choose'));
      await tester.ensureVisible(location);
      expect(tester.getSize(location).width, greaterThanOrEqualTo(240));
      expect(
        tester.getTopLeft(choose).dy,
        greaterThanOrEqualTo(tester.getBottomRight(location).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unchanged scan can confirm ZIP cleanup without applying resources',
    (tester) async {
      tester.view.physicalSize = const Size(720, 832);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final port = _LibraryPort()
        ..setLibrary()
        ..cleanupOnly = true
        ..cleanupCount = 2;
      final c = GameModsController(port: port);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(body: GameModsPage(controller: c, visible: false)),
        ),
      );
      await tester.pumpAndSettle();
      final before = c.status.toMap();
      final scan = find.byKey(const Key('game-mods-library-scan'));
      await tester.ensureVisible(scan);
      await tester.tap(scan);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('game-mods-library-scan-confirm'));
      expect(confirm, findsOneWidget);
      expect(
        find.byKey(const Key('game-mods-library-cleanup-hint')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('game-mods-library-cleanup-hint')),
            )
            .data,
        contains('2'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(port.committed, ['scan-1']);
      expect(c.libraryScan, isNull);
      expect(c.status.toMap(), before);
      expect(port.applyCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in const [
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
    Locale('en'),
    Locale('ko'),
  ]) {
    testWidgets(
      'scan details follow ${locale.toLanguageTag()} and preserve paths and provider diagnostics',
      (tester) async {
        const rawStatus = '内容与已有魔改包相同，已跳过。';
        const rawChecksum = 'ZIP 文件长度或校验和错误：';
        const path = 'kcs2/漢字：画像.png';
        const providerMessage = 'EIO /storage/游戏/資源: read failed';
        const expected = {
          'zh': (rawStatus, rawChecksum),
          'zh-Hant': ('內容與現有魔改包相同，已略過。', 'ZIP 內的檔案長度或校驗值有誤：'),
          'ja': ('既存のMODと内容が同じためスキップしました。', 'ZIP内のファイルの長さまたはチェックサムが一致しません：'),
          'en': (
            'Skipped because the contents match an existing mod package.',
            'The file length or checksum is incorrect in the ZIP: ',
          ),
          'ko': (
            '기존 모드 패키지와 내용이 같아 건너뛰었습니다.',
            'ZIP에 있는 파일의 길이 또는 체크섬이 잘못되었습니다: ',
          ),
        };
        final (statusLabel, checksumLabel) = expected[locale.toLanguageTag()]!;
        final port = _LibraryPort()
          ..setLibrary()
          ..details = [rawStatus, '$rawChecksum$path', providerMessage];
        final controller = GameModsController(port: port);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: [locale],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: GameModsPage(controller: controller, visible: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scan = find.byKey(const Key('game-mods-library-scan'));
        await tester.ensureVisible(scan);
        await tester.tap(scan);
        await tester.pumpAndSettle();
        expect(find.text(statusLabel), findsOneWidget);
        expect(find.text('$checksumLabel$path'), findsOneWidget);
        expect(find.text(providerMessage), findsOneWidget);
        expect(port.committed, isEmpty);
        expect(port.applyCalls, 0);
      },
    );
    for (final errorCode in const [
      'library_metadata_invalid',
      'library_directory_required',
    ]) {
      for (final entryPoint in const ['choose', 'import']) {
        testWidgets(
          '$entryPoint directory failure stays in the folder panel for '
          '$errorCode in ${locale.toLanguageTag()}',
          (tester) async {
            final port = _LibraryPort()..chooseError = errorCode;
            final c = GameModsController(port: port);
            addTearDown(c.dispose);
            final s = GameModsStrings(locale);
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                supportedLocales: [locale],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: Scaffold(
                  body: GameModsPage(controller: c, visible: false),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final before = c.status.toMap();
            final entry = find.byKey(
              Key(
                entryPoint == 'choose'
                    ? 'game-mods-library-choose'
                    : 'game-mods-import',
              ),
            );
            await tester.ensureVisible(entry);
            await tester.tap(entry);
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(FilledButton, s.libraryChoose),
              ),
            );
            await tester.pumpAndSettle();

            final panel = find.byKey(const Key('game-mods-library'));
            final error = find.text(s.reason(errorCode));
            expect(find.descendant(of: panel, matching: error), findsOneWidget);
            expect(error, findsOneWidget);
            expect(find.text(errorCode), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(c.errorCode, errorCode);
            expect(c.status.toMap(), before);
            expect(port.chooseCalls, 1);
            expect(port.pickerCalls, 0);
            expect(port.scanCalls, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'library scan review works at 360px large text in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final port = _LibraryPort()
          ..setLibrary()
          ..cleanupCount = 2;
        final c = GameModsController(port: port);
        addTearDown(c.dispose);
        final s = GameModsStrings(locale);
        expect(s.libraryChooseHint, contains('Documents/Yahagi/Mods'));
        expect(s.libraryChooseHint, isNot(contains('Yahagi/魔改')));
        final appliedClaim = switch (locale.languageCode) {
          'zh' => locale.scriptCode == 'Hant' ? '設定已生效' : '设置已生效',
          'ja' => '設定は適用済み',
          'ko' => '설정은 적용',
          _ => 'Settings are active',
        };
        expect(
          s.reason('library_cleanup_failed'),
          isNot(contains(appliedClaim)),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: [locale],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(body: GameModsPage(controller: c, visible: false)),
          ),
        );
        await tester.pumpAndSettle();
        final scan = find.byKey(const Key('game-mods-library-scan'));
        await tester.ensureVisible(scan);
        await tester.pumpAndSettle();
        await tester.tap(scan);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(s.libraryRestoreHint), findsOneWidget);
        expect(
          find.byKey(const Key('game-mods-library-cleanup-hint')),
          findsOneWidget,
        );
        final cancel = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, s.cancel),
        );
        expect(tester.getSize(cancel).height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(port.discardedScans, ['scan-1']);
        expect(port.committed, isEmpty);
        expect(port.applyCalls, 0);
        expect(c.status.packages.length, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _LibraryPort extends FakeGameModsPort implements GameModsLibraryPort {
  bool chooseResult = true,
      scanFailure = false,
      missingLibrary = false,
      failCommit = false,
      partialCommitFailure = false,
      cleanupOnly = false;
  int chooseCalls = 0, pickerCalls = 0, scanCalls = 0, cleanupCount = 0;
  final committed = <String>[], discardedScans = <String>[];
  Completer<void>? scanGate;
  String? chooseError;
  List<String> details = [];
  void setLibrary({bool configured = true, bool available = true}) {
    current = GameModsStatus.fromMap({
      ...current.toMap(),
      'library': {
        'configured': configured,
        'available': available,
        'displayName': 'Documents/Yahagi/Mods',
        'packageCount': 2,
      },
    });
  }

  @override
  Future<bool> chooseLibraryDirectory() async {
    chooseCalls++;
    if (chooseError != null) throw PlatformException(code: chooseError!);
    if (chooseResult) setLibrary();
    return chooseResult;
  }

  @override
  Future<void> openLibraryDirectory() async {}
  @override
  Future<GameModsPreflight?> pickAndPreflightArchive() async {
    pickerCalls++;
    return super.pickAndPreflightArchive();
  }

  @override
  Future<GameModLibraryScan> scanLibrary() async {
    if (missingLibrary) throw MissingPluginException();
    if (scanFailure) throw PlatformException(code: 'library_permission_lost');
    await scanGate?.future;
    return GameModLibraryScan.fromMap({
      'token': 'scan-${++scanCalls}',
      'restoreAvailable': !cleanupOnly,
      'cleanupCount': cleanupCount,
      'entries': details.isNotEmpty
          ? [
              for (final (index, detail) in details.indexed)
                {
                  'id': 'pkg-$index',
                  'name': 'pkg-$index',
                  'kind': 'invalid',
                  'detail': detail,
                },
            ]
          : [
              for (final kind
                  in cleanupOnly
                      ? [GameModLibraryEntryKind.unchanged]
                      : GameModLibraryEntryKind.values)
                {
                  'id': kind.name,
                  'name': kind.name,
                  'kind': kind == GameModLibraryEntryKind.added
                      ? 'new'
                      : kind.name,
                  'supportedCount': 2,
                  'resourceCount': 2,
                },
            ],
    });
  }

  @override
  Future<void> commitLibraryScan(String token) async {
    if (failCommit) {
      if (partialCommitFailure) {
        current = GameModsStatus.fromMap({
          ...current.toMap(),
          'packages': [
            ...current.packages.map((p) => p.toMap()),
            {'id': 'partial', 'name': 'Completed before failure'},
          ],
        });
      }
      throw PlatformException(code: 'invalid_token');
    }
    committed.add(token);
    if (cleanupOnly) return;
    current = GameModsStatus.fromMap({
      ...current.toMap(),
      'packages': [
        ...current.packages.map((p) => p.toMap()),
        {'id': 'new', 'name': 'New import'},
      ],
    });
  }

  @override
  Future<void> discardLibraryScan(String token) async =>
      discardedScans.add(token);
}
