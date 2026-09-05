import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Map<String, String> collectBusinessDartSources(Directory projectRoot) {
  final rootPath = projectRoot.absolute.path;
  final files = <File>[
    File(
      '$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
    ),
    ...Directory(
          '$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}src',
        )
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  ]..sort((a, b) => a.path.compareTo(b.path));

  return <String, String>{
    for (final file in files)
      file.absolute.path.substring(rootPath.length + 1).replaceAll(r'\', '/'):
          file.readAsStringSync(),
  };
}

List<String> findForbiddenBottomNoticeUsages(Map<String, String> sources) {
  final violations = <String>[];
  final entries = sources.entries.toList()
    ..sort(
      (a, b) =>
          a.key.replaceAll(r'\', '/').compareTo(b.key.replaceAll(r'\', '/')),
    );

  for (final entry in entries) {
    final path = entry.key.replaceAll(r'\', '/');
    final lines = entry.value.split('\n');
    final lineNumbers =
        _DartIdentifierScanner(entry.value)
            .findForbiddenOffsets()
            .map(
              (offset) =>
                  '\n'.allMatches(entry.value.substring(0, offset)).length + 1,
            )
            .toSet()
            .toList()
          ..sort();
    for (final lineNumber in lineNumbers) {
      violations.add('$path:$lineNumber: ${lines[lineNumber - 1].trim()}');
    }
  }

  return violations;
}

class _DartIdentifierScanner {
  _DartIdentifierScanner(this.source);

  static const forbiddenIdentifiers = <String>{
    'SnackBar',
    'ScaffoldMessenger',
    'showSnackBar',
    'hideCurrentSnackBar',
  };

  final String source;
  final List<int> _forbiddenOffsets = <int>[];
  var _index = 0;

  List<int> findForbiddenOffsets() {
    _scanCode();
    return _forbiddenOffsets;
  }

  void _scanCode({bool stopAtClosingBrace = false}) {
    while (_index < source.length) {
      if (stopAtClosingBrace && source[_index] == '}') {
        _index++;
        return;
      }
      if (source.startsWith('//', _index)) {
        _skipLineComment();
      } else if (source.startsWith('/*', _index)) {
        _skipBlockComment();
      } else if (_isRawStringStart()) {
        _index++;
        _skipString(raw: true);
      } else if (_isQuote(source[_index])) {
        _skipString(raw: false);
      } else if (_isIdentifierStart(source.codeUnitAt(_index))) {
        _scanIdentifier();
      } else if (source[_index] == '{') {
        _index++;
        _scanCode(stopAtClosingBrace: true);
      } else {
        _index++;
      }
    }
  }

  void _skipLineComment() {
    final newline = source.indexOf('\n', _index + 2);
    _index = newline < 0 ? source.length : newline + 1;
  }

  void _skipBlockComment() {
    var depth = 1;
    _index += 2;
    while (_index < source.length && depth > 0) {
      if (source.startsWith('/*', _index)) {
        depth++;
        _index += 2;
      } else if (source.startsWith('*/', _index)) {
        depth--;
        _index += 2;
      } else {
        _index++;
      }
    }
  }

  void _skipString({required bool raw}) {
    final quote = source[_index];
    final tripleQuote = '$quote$quote$quote';
    final delimiter = source.startsWith(tripleQuote, _index)
        ? tripleQuote
        : quote;
    _index += delimiter.length;
    while (_index < source.length) {
      if (source.startsWith(delimiter, _index)) {
        _index += delimiter.length;
        return;
      }
      if (!raw && source[_index] == r'\') {
        _index += _index + 1 < source.length ? 2 : 1;
      } else if (!raw && source[_index] == r'$') {
        _scanInterpolation();
      } else {
        _index++;
      }
    }
  }

  void _scanInterpolation() {
    if (_index + 1 >= source.length) {
      _index++;
      return;
    }
    if (source[_index + 1] == '{') {
      _index += 2;
      _scanCode(stopAtClosingBrace: true);
      return;
    }
    if (_isIdentifierStart(source.codeUnitAt(_index + 1))) {
      _index++;
      _scanIdentifier();
      return;
    }
    _index++;
  }

  void _scanIdentifier() {
    final start = _index;
    _index++;
    while (_index < source.length &&
        _isIdentifierPart(source.codeUnitAt(_index))) {
      _index++;
    }
    if (forbiddenIdentifiers.contains(source.substring(start, _index))) {
      _forbiddenOffsets.add(start);
    }
  }

  bool _isRawStringStart() =>
      _index + 1 < source.length &&
      (source[_index] == 'r' || source[_index] == 'R') &&
      _isQuote(source[_index + 1]);

  static bool _isQuote(String character) =>
      character == "'" || character == '"';

  static bool _isIdentifierStart(int character) =>
      character == 0x5f ||
      character == 0x24 ||
      (character >= 0x41 && character <= 0x5a) ||
      (character >= 0x61 && character <= 0x7a);

  static bool _isIdentifierPart(int character) =>
      _isIdentifierStart(character) || (character >= 0x30 && character <= 0x39);
}

void main() {
  test('business Dart sources use TopNotice instead of bottom notices', () {
    final violations = findForbiddenBottomNoticeUsages(
      collectBusinessDartSources(Directory.current),
    );

    expect(
      violations,
      isEmpty,
      reason:
          'Business source must use TopNotice.show instead of SnackBar, '
          'ScaffoldMessenger, showSnackBar, or hideCurrentSnackBar.\n'
          '${violations.join('\n')}',
    );
  });

  test('collector recursively scans only business Dart sources', () {
    final project = Directory.systemTemp.createTempSync('top_notice_contract_');
    addTearDown(() {
      if (project.existsSync()) {
        project.deleteSync(recursive: true);
      }
    });
    Directory('${project.path}/lib/src/nested').createSync(recursive: true);
    Directory('${project.path}/test').createSync();
    File('${project.path}/lib/main.dart').writeAsStringSync(
      'void main() {\r\n'
      "  final notice = SnackBar(content: Text('message'));\r\n"
      '  messengerKey.currentState!.showSnackBar(notice);\r\n'
      '  ScaffoldMessenger.of(context);\r\n'
      '}\r\n',
    );
    File(
      '${project.path}/lib/src/nested/feature.dart',
    ).writeAsStringSync('void hide(key) {\n  key.hideCurrentSnackBar();\n}\n');
    File('${project.path}/lib/src/ignored.txt').writeAsStringSync('SnackBar');
    File(
      '${project.path}/test/ignored_test.dart',
    ).writeAsStringSync('SnackBar');

    final sources = collectBusinessDartSources(project);
    final violations = findForbiddenBottomNoticeUsages(sources);

    expect(sources.keys, <String>[
      'lib/main.dart',
      'lib/src/nested/feature.dart',
    ]);
    expect(violations, <String>[
      "lib/main.dart:2: final notice = SnackBar(content: Text('message'));",
      'lib/main.dart:3: messengerKey.currentState!.showSnackBar(notice);',
      'lib/main.dart:4: ScaffoldMessenger.of(context);',
      'lib/src/nested/feature.dart:2: key.hideCurrentSnackBar();',
    ]);
  });

  test('detector ignores comments and strings but scans interpolation code', () {
    final source = <String>[
      r'// SnackBar and showSnackBar are documentation.',
      r'/* ScaffoldMessenger',
      r'/* showSnackBar */ hideCurrentSnackBar',
      r'*/',
      r"const ordinary = 'SnackBar ScaffoldMessenger showSnackBar';",
      r"const escaped = 'can\'t hideCurrentSnackBar';",
      "const triple = '''SnackBar",
      "ScaffoldMessenger''';",
      r"const rawTriple = r'''showSnackBar",
      "hideCurrentSnackBar''';",
      r"const interpolated = '${messengerKey.showSnackBar(value)}';",
      r"const shorthand = '$SnackBar';",
    ].join('\r\n');

    expect(
      findForbiddenBottomNoticeUsages(<String, String>{
        r'lib\src\strings.dart': source,
      }),
      <String>[
        r"lib/src/strings.dart:11: const interpolated = '${messengerKey.showSnackBar(value)}';",
        r"lib/src/strings.dart:12: const shorthand = '$SnackBar';",
      ],
    );
  });

  test('app mounts exactly one TopNoticeHost at MaterialApp home', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(RegExp(r'home:\s*TopNoticeHost\(').allMatches(source), hasLength(1));
    expect(RegExp(r'\bTopNoticeHost\s*\(').allMatches(source), hasLength(1));
  });

  testWidgets('YahagiApp exposes one TopNoticeHost directly as home', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    GameStateController.disableTimerForTest = true;
    addTearDown(() => GameStateController.disableTimerForTest = false);
    final layoutSettingsController = _LayoutSettingsControllerStub();
    final networkSettingsController = _NetworkSettingsControllerStub();
    final gadgetBypassController = _GadgetBypassControllerStub();
    final safetySettingsController = _SafetySettingsControllerStub();
    final displayModeController = _DisplayModeControllerStub();
    final controller = PrototypeStatusController();
    final browserController = GameBrowserController();
    final captureModeController = await CaptureModeController.load(
      _MemoryCaptureModeStore(),
    );
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    addTearDown(layoutSettingsController.dispose);
    addTearDown(networkSettingsController.dispose);
    addTearDown(gadgetBypassController.dispose);
    addTearDown(safetySettingsController.dispose);
    addTearDown(displayModeController.dispose);
    addTearDown(controller.dispose);
    addTearDown(browserController.dispose);
    addTearDown(captureModeController.dispose);
    addTearDown(audioController.dispose);
    addTearDown(toolbarController.dispose);
    addTearDown(gameCaptureController.dispose);
    addTearDown(gameStateController.dispose);
    addTearDown(battleController.dispose);
    addTearDown(() async => tester.pumpWidget(const SizedBox()));

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: networkSettingsController,
        gadgetBypassController: gadgetBypassController,
        safetySettingsController: safetySettingsController,
        displayModeController: displayModeController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const SizedBox(),
      ),
    );

    expect(find.byType(TopNoticeHost, skipOffstage: false), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).home,
      isA<TopNoticeHost>(),
    );
  });
}

class _LayoutSettingsControllerStub extends ChangeNotifier
    implements LayoutSettingsController {
  @override
  bool get autoZoom => false;

  @override
  List<String> get dashboardCardCollapsed => const <String>[];

  @override
  List<String> get dashboardCardHidden => const <String>[];

  @override
  List<String> get dashboardCardOrder => const <String>[];

  @override
  bool get enhancedDamagePulse => false;

  @override
  String get fontFamily => 'sans-serif';

  @override
  List<String> get fontFamilyFallback => const <String>[];

  @override
  double get gameAreaRatio => 0.65;

  @override
  List<String> get headerResourceOrder => allHeaderResourceIds;

  @override
  String? get localeCode => null;

  @override
  List<String> get visibleHeaderResourceIds => defaultVisibleHeaderResourceIds;

  @override
  List<String> get workspaceMenuOrder =>
      LayoutSettingsStore.defaultWorkspaceMenuOrder;

  @override
  bool get workspaceMenuOnRight => false;

  @override
  bool get informationPanelOnLeft => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _NetworkSettingsControllerStub extends ChangeNotifier
    implements NetworkSettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _GadgetBypassControllerStub extends ChangeNotifier
    implements GadgetBypassController {
  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _SafetySettingsControllerStub extends ChangeNotifier
    implements SafetySettingsController {
  @override
  bool get battleDamageVibrationEnabled => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

class _DisplayModeControllerStub extends ChangeNotifier
    implements DisplayModeController {
  @override
  DisplayMode get displayMode => DisplayMode.auto;

  @override
  dynamic noSuchMethod(Invocation invocation) => _unexpected(invocation);
}

Never _unexpected(Invocation invocation) {
  throw UnsupportedError('Unexpected invocation: ${invocation.memberName}');
}

class _MemoryCaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => null;

  @override
  Future<void> write(CaptureMode mode) async {}
}

class _MemoryAudioStore implements GameAudioStore {
  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => null;

  @override
  Future<bool?> readMuted() async => null;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}

  @override
  Future<void> writeMuted(bool muted) async {}
}
