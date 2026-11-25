import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_port.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_strings.dart';

import 'game_mods_controller_test.dart' show FakeGameModsPort;
import 'support/game_mod_portrait_platform_mock.dart';

const _chineseName = '吹雪改二与伊四十七全套立绘语音坐标魔改包：包含通常立绘、中破立绘、图鉴卡面、母港语音及多个可独立启停的资源';
const _englishName =
    'LexingtonAndFubukiKaiNiCompleteIllustrationVoiceCoordinateReplacementCollection'
    'WithAnUnbrokenArchiveNameAndAdditionalOptionalResources';
const _locales = [
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('ja'),
  Locale('en'),
  Locale('ko'),
];

void main() {
  setUp(mockGameModPortraitPlatform);
  tearDown(clearGameModPortraitPlatformMock);
  testWidgets('ZIP update targets the open package and waits for Apply', (
    tester,
  ) async {
    const channel = MethodChannel('app.yahagi.kancollebrowser/mod_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final initial = _layoutStatus('Existing CHS package');
    var pending = false;
    var installed = false;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'commitImport') pending = !installed;
      if (call.method == 'applyAndReload') {
        pending = false;
        installed = true;
      }
      return switch (call.method) {
        'capabilities' => {'supported': true, 'archiveUpdateSupported': true},
        'status' => {
          ...initial.toMap(),
          'applied': initial.draft.toMap(),
          'pending': pending,
          'packages': [
            for (final p in initial.packages)
              {...p.toMap(), 'pendingUpdate': pending && p.id == 'mixed'},
          ],
          'library': {'configured': true, 'available': true},
        },
        'pickAndPreflightUpdate' => {
          'token': 'update-token',
          'name': 'chs-next.zip',
          'resourceCount': 3,
          'supportedCount': 3,
          'unsupportedCount': 0,
          'addedCount': 2,
          'removedCount': 1,
        },
        'applyAndReload' => {'result': 'noGame'},
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final controller = GameModsController(
      port: const MethodChannelGameModsPort(channel),
    );
    await _pumpPage(
      tester,
      controller,
      locale: const Locale('en'),
      size: const Size(360, 760),
      scale: 1.6,
    );
    await _openDetails(tester);

    final action = find.byKey(const Key('game-mods-update-mixed'));
    _expectTouchTarget(tester, action);
    _expectVisible(tester, action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    final review = find.byType(AlertDialog);
    expect(review, findsOneWidget);
    expect(
      find.descendant(of: review, matching: find.text('Existing CHS package')),
      findsOneWidget,
    );
    expect(find.text('chs-next.zip'), findsOneWidget);
    expect(find.text('2 resources added · 1 removed'), findsOneWidget);
    expect(
      calls.singleWhere((c) => c.method == 'pickAndPreflightUpdate').arguments,
      {'id': 'mixed'},
    );
    expect(calls.where((c) => c.method == 'commitImport'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm update'));
    await tester.pumpAndSettle();
    expect(calls.singleWhere((c) => c.method == 'commitImport').arguments, {
      'token': 'update-token',
    });
    expect(calls.where((c) => c.method == 'applyAndReload'), isEmpty);
    expect(find.text('Update pending'), findsOneWidget);

    await tester.tap(find.byKey(const Key('game-mods-apply')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'applyAndReload'), hasLength(1));
    expect(find.text('Update pending'), findsNothing);

    await _openDetails(tester);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm update'));
    await tester.pumpAndSettle();
    expect(find.text('This ZIP matches the current package'), findsOneWidget);
    expect(find.text('Update pending'), findsNothing);
    expect(calls.where((c) => c.method == 'applyAndReload'), hasLength(1));
    _expectNoFrameworkErrors(tester);
  });

  for (final name in [_chineseName, _englishName]) {
    testWidgets(
      '360px large text keeps long ${name == _chineseName ? 'Chinese' : 'English'} package actions usable',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final port = FakeGameModsPort()..current = _layoutStatus(name);
          final controller = GameModsController(port: port);
          const locale = Locale('en');
          final s = GameModsStrings(locale);
          await _pumpPage(
            tester,
            controller,
            locale: locale,
            size: const Size(360, 760),
            scale: 1.6,
          );

          final apply = find.byKey(const Key('game-mods-apply'));
          _expectTouchTarget(tester, apply);
          _expectVisible(tester, apply);
          await _reveal(tester, find.byKey(const Key('game-mods-import')));
          _expectTouchTarget(tester, find.byKey(const Key('game-mods-import')));

          final package = find.byKey(const Key('game-mods-package-mixed'));
          await _reveal(tester, package);
          _expectTouchTarget(tester, package);
          expect(tester.widget<Switch>(package).value, isTrue);
          expect(tester.getSemantics(package).label, contains(name));
          expect(controller.status.pending, isTrue);
          expect(find.text(s.partialProvided(1)), findsWidgets);
          expect(find.text(s.supplied(1)), findsWidgets);
          expect(find.text(s.coordinatesWaitingCount(1)), findsWidgets);
          expect(tester.takeException(), isNull);

          await _openDetails(tester);
          final close = _closeButton(s);
          _expectTouchTarget(tester, close);
          _expectVisible(tester, close);
          // The modal route must inherit the same scaling as the page.
          expect(
            MediaQuery.textScalerOf(tester.element(close)).scale(10),
            closeTo(16, .001),
          );
          final warning = find.text(s.reason('unsupported_audio_files'));
          await _reveal(tester, warning, inSheet: true);
          _expectUnclippedText(tester, warning);

          final resource = find.byKey(const Key('game-mods-resource-image'));
          await _reveal(tester, resource, inSheet: true);
          _expectTouchTarget(tester, resource);
          expect(tester.widget<Switch>(resource).value, isTrue);
          await tester.tap(resource);
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(resource).value, isFalse);
          expect(
            controller.status.draft.enabledResources,
            isNot(contains('image')),
          );
          expect(controller.status.applied.enabledResources, contains('image'));
          expect(port.applyCalls, 0);
          expect(tester.takeException(), isNull);

          final remove = find.byKey(const Key('game-mods-remove-mixed'));
          _expectTouchTarget(tester, remove);
          _expectVisible(tester, remove);
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          final cancel = find.widgetWithText(TextButton, s.cancel);
          _expectTouchTarget(tester, cancel);
          _expectVisible(tester, cancel);
          expect(
            MediaQuery.textScalerOf(tester.element(cancel)).scale(10),
            closeTo(16, .001),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(port.removed, isEmpty);
          expect(
            controller.status.packages.any((p) => p.pendingRemoval),
            isFalse,
          );

          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(close, findsNothing);
          _expectVisible(tester, apply);
          expect(port.applyCalls, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('wide landscape keeps package and detail controls reachable', (
    tester,
  ) async {
    final port = FakeGameModsPort()..current = _layoutStatus(_englishName);
    final controller = GameModsController(port: port);
    const s = GameModsStrings(Locale('en'));
    await _pumpPage(
      tester,
      controller,
      locale: const Locale('en'),
      size: const Size(1200, 700),
      scale: 1,
    );
    _expectVisible(tester, find.byKey(const Key('game-mods-apply')));
    await _openDetails(tester);
    final close = _closeButton(s);
    _expectTouchTarget(tester, close);
    _expectTouchTarget(tester, find.byKey(const Key('game-mods-remove-mixed')));
    final down = find.widgetWithText(OutlinedButton, s.down);
    _expectTouchTarget(tester, down);
    expect(tester.widget<OutlinedButton>(down).onPressed, isNotNull);
    await tester.tap(down);
    await tester.pumpAndSettle();
    expect(controller.status.draft.order, ['overlay', 'mixed']);
    expect(port.applyCalls, 0);
    expect(tester.widget<OutlinedButton>(down).onPressed, isNull);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byTooltip(s.close), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final layout in const [
    (size: Size(360, 760), scale: 1.6, inlineHeader: false),
    (size: Size(720, 760), scale: 1.0, inlineHeader: true),
    (size: Size(720, 760), scale: 1.6, inlineHeader: false),
    (size: Size(1200, 700), scale: 1.0, inlineHeader: true),
  ]) {
    testWidgets(
      'help, filters and reset stay usable at ${layout.size.width}px/${layout.scale}x',
      (tester) async {
        final port = FakeGameModsPort()..current = _layoutStatus(_englishName);
        final controller = GameModsController(port: port);
        const s = GameModsStrings(Locale('en'));
        await _pumpPage(
          tester,
          controller,
          locale: const Locale('en'),
          size: layout.size,
          scale: layout.scale,
        );
        expect(find.text(s.title), findsNothing);
        expect(find.text(s.subtitle), findsNothing);
        expect(find.textContaining('${s.current} ·'), findsNothing);

        final intro = find.text(s.headerIntro);
        final importHint = find.text(s.importHint);
        expect(intro, findsOneWidget);
        expect(importHint, findsOneWidget);
        _expectVisible(tester, intro);
        _expectVisible(tester, importHint);
        _expectUnclippedText(tester, intro);
        _expectUnclippedText(tester, importHint);

        final help = find.ancestor(
          of: find.byTooltip(s.help),
          matching: find.byType(IconButton),
        );
        final importAction = find.byKey(const Key('game-mods-import'));
        _expectVisible(tester, help);
        _expectVisible(tester, importAction);
        _expectTouchTarget(tester, help);
        _expectTouchTarget(tester, importAction);
        expect(
          tester.getRect(help).right,
          lessThanOrEqualTo(tester.getRect(importAction).left),
        );
        expect(
          tester.getCenter(help).dy,
          closeTo(tester.getCenter(importAction).dy, 8),
        );
        final introBounds = tester.getRect(intro);
        final hintBounds = tester.getRect(importHint);
        final textBounds = introBounds.expandToInclude(hintBounds);
        final actionBounds = tester
            .getRect(help)
            .expandToInclude(tester.getRect(importAction));
        expect(introBounds.left, closeTo(hintBounds.left, .1));
        expect(introBounds.bottom, lessThanOrEqualTo(hintBounds.top));
        if (layout.inlineHeader) {
          expect(textBounds.right, lessThanOrEqualTo(actionBounds.left));
          expect(textBounds.center.dy, closeTo(actionBounds.center.dy, 1));
        } else {
          // Narrow or enlarged text keeps the whole text group above actions.
          expect(actionBounds.top, greaterThanOrEqualTo(textBounds.bottom + 8));
          expect(actionBounds.right, closeTo(layout.size.width - 12, .1));
        }
        await tester.tap(help);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final closeHelp = find.widgetWithText(TextButton, s.close);
        _expectTouchTarget(tester, closeHelp);
        _expectVisible(tester, closeHelp);
        expect(
          MediaQuery.textScalerOf(tester.element(closeHelp)).scale(10),
          closeTo(10 * layout.scale, .001),
        );
        _expectNoFrameworkErrors(tester);
        await tester.tap(closeHelp);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // Large-text guidance can place the filters below the initial viewport.
        await _reveal(tester, find.widgetWithText(FilterChip, '${s.all} 2'));
        final chips = find.byType(FilterChip);
        expect(chips, findsNWidgets(4));
        final reset = find.byKey(const Key('game-mods-reset'));
        await _reveal(tester, reset);
        _expectTouchTarget(tester, reset);
        final chipBounds = [
          for (final element in chips.evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ];
        final resetBounds = tester.getRect(reset);
        final filterRight = chipBounds
            .map((r) => r.right)
            .reduce((a, b) => a > b ? a : b);
        final filterBottom = chipBounds
            .map((r) => r.bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(resetBounds.right, greaterThanOrEqualTo(filterRight - .1));
        if (layout.size.width >= 1000) {
          expect(resetBounds.center.dy, closeTo(chipBounds.first.center.dy, 8));
        } else {
          // A wrapped reset action belongs immediately after the filters.
          expect(resetBounds.top, lessThanOrEqualTo(filterBottom + 16));
        }
        for (final element in chips.evaluate()) {
          final chip = element.widget as FilterChip;
          expect(chip.showCheckmark, isFalse);
          _expectTouchTarget(tester, find.byWidget(chip));
        }

        final disabled = find.widgetWithText(FilterChip, '${s.disabled} 0');
        await _reveal(tester, disabled);
        await tester.tap(disabled);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(disabled).selected, isTrue);
        expect(find.byKey(const Key('game-mods-package-mixed')), findsNothing);
        await _reveal(tester, reset);
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final cancelReset = find.widgetWithText(TextButton, s.cancel);
        _expectTouchTarget(tester, cancelReset);
        _expectVisible(tester, cancelReset);
        _expectNoFrameworkErrors(tester);
        await tester.tap(cancelReset);
        await tester.pumpAndSettle();
        expect(port.resetCalls, 0);
        expect(port.applyCalls, 0);
        expect(
          controller.status.packages.any((p) => p.pendingRemoval),
          isFalse,
        );

        final all = find.widgetWithText(FilterChip, '${s.all} 2');
        await _reveal(tester, all);
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(all).selected, isTrue);
        await _reveal(tester, find.byKey(const Key('game-mods-details-mixed')));
        expect(
          port.saved,
          isEmpty,
          reason: 'Filtering does not edit the draft',
        );
        _expectNoFrameworkErrors(tester);
      },
    );
  }

  for (final locale in _locales) {
    testWidgets(
      '360px large-text controls and warnings remain usable in $locale',
      (tester) async {
        final port = FakeGameModsPort()..current = _layoutStatus(_chineseName);
        final controller = GameModsController(port: port);
        final s = GameModsStrings(locale);
        await _pumpPage(
          tester,
          controller,
          locale: locale,
          size: const Size(360, 760),
          scale: 1.6,
        );
        _expectTouchTarget(tester, find.byKey(const Key('game-mods-apply')));
        await _openDetails(tester);
        final warning = find.text(s.reason('unsupported_audio_files'));
        await _reveal(tester, warning, inSheet: true);
        _expectUnclippedText(tester, warning);
        final close = _closeButton(s);
        _expectTouchTarget(tester, close);
        _expectVisible(tester, close);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(close, findsNothing);
        expect(port.applyCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  GameModsController controller, {
  required Locale locale,
  required Size size,
  required double scale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  await controller.initialize();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: _locales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: GameModsPage(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
  _expectNoFrameworkErrors(tester);
}

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  bool inSheet = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    maxScrolls: 80,
    scrollable: inSheet
        ? find.byType(Scrollable).last
        : find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  _expectVisible(tester, finder);
  _expectNoFrameworkErrors(tester);
}

Future<void> _openDetails(WidgetTester tester) async {
  final details = find.byKey(const Key('game-mods-details-mixed'));
  await _reveal(tester, details);
  _expectTouchTarget(tester, details);
  await tester.tap(details);
  await tester.pumpAndSettle();
  _expectNoFrameworkErrors(tester);
}

Finder _closeButton(GameModsStrings s) => find.ancestor(
  of: find.byTooltip(s.close),
  matching: find.byType(IconButton),
);

void _expectNoFrameworkErrors(WidgetTester tester) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: error is FlutterError
        ? error.diagnostics
              .map((diagnostic) => diagnostic.toStringDeep())
              .join('\n')
        : error?.toString(),
  );
}

void _expectTouchTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(44));
  expect(size.height, greaterThanOrEqualTo(44));
}

void _expectVisible(WidgetTester tester, Finder finder) {
  expect(finder.hitTestable(), findsOneWidget);
  final viewport = Offset.zero & tester.view.physicalSize;
  final bounds = tester.getRect(finder);
  expect(bounds.left, greaterThanOrEqualTo(viewport.left - .1));
  expect(bounds.right, lessThanOrEqualTo(viewport.right + .1));
  expect(bounds.top, greaterThanOrEqualTo(viewport.top - .1));
  expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom + .1));
}

void _expectUnclippedText(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + .1),
  );
}

GameModsStatus _layoutStatus(String name) {
  const imagePath = 'kcs2/resources/ship/full/0426_rtkekdbkqrkg.png';
  const voicePath = 'kcs/sound/kcrtkekdbkqrkg/107404.mp3';
  const failedPath = 'kcs2/img/port/alternate_theme.png';
  const normal = 'coordinates/ship/426/api_boko_n';
  const damaged = 'coordinates/ship/426/api_boko_d';
  const draft = GameModsConfig(
    master: true,
    order: ['mixed', 'overlay'],
    enabledPackages: {'mixed', 'overlay'},
    enabledResources: {'image', 'voice', 'failed', 'coords', 'overlay-coords'},
  );
  return GameModsStatus(
    packages: [
      GameModPackage(
        id: 'mixed',
        name: name,
        sizeBytes: 14085511,
        warnings: const [
          'unsupported_audio_files',
          'png_trailing_data_removed',
        ],
        resources: const [
          GameModResource(
            id: 'image',
            path: imagePath,
            kind: 'ship',
            label: '0426 · full',
            supported: true,
          ),
          GameModResource(
            id: 'voice',
            path: voicePath,
            kind: 'audio',
            label: '',
            supported: true,
          ),
          GameModResource(
            id: 'failed',
            path: failedPath,
            kind: 'image',
            label: 'Alternative mother port background',
            supported: true,
          ),
          GameModResource(
            id: 'coords',
            path: 'coordinates/ship/426',
            kind: 'coordinates',
            label: '0426',
            supported: true,
            sourcePaths: [
              'cache/rtkekdbkqrkg.config.ini',
              'cache/rtkekdbkqrkg.config.json',
            ],
            targetPaths: [normal, damaged],
          ),
          GameModResource(
            id: 'unsupported',
            path:
                'backup/AnExtremelyLongUnmappedVoiceFilenameWhichMustRemainReadableInTheResourceDetails.mp3',
            kind: 'audio',
            label: '',
            supported: false,
            reason: 'audio_filename_unsupported',
          ),
        ],
      ),
      const GameModPackage(
        id: 'overlay',
        name: 'Additional independent coordinate overlay',
        resources: [
          GameModResource(
            id: 'overlay-coords',
            path: 'coordinates/ship/426',
            kind: 'coordinates',
            label: '0426',
            supported: true,
            targetPaths: [normal],
          ),
        ],
      ),
    ],
    draft: draft,
    applied: draft.copyWith(order: ['overlay', 'mixed']),
    pending: true,
    sessionId: 3,
    winners: const {
      imagePath: 'image',
      voicePath: 'voice',
      failedPath: 'failed',
      normal: 'coords',
      damaged: 'coords',
    },
    activeWinners: const {
      imagePath: 'image',
      voicePath: 'voice',
      failedPath: 'failed',
      normal: 'overlay-coords',
      damaged: 'coords',
    },
    hits: const {'image', 'overlay-coords'},
    partialHits: const {'voice'},
    failures: const {'failed': 'invalid_png'},
  );
}
