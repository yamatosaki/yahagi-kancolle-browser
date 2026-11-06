import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_reminder_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_resource_checklist.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_font_size.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';

const _native = MethodChannel('app.yahagi.kancollebrowser/native_warning');
const _open = Key('open-native-style-dialog');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <Map<Object?, Object?>>[];

  setUp(() {
    requests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_native, (call) async {
          if (call.method == 'waitUntilAvailable') return true;
          if (call.method == 'show') {
            requests.add(Map<Object?, Object?>.from(call.arguments as Map));
            return requests.last['kind'] == 'surfaceDialog'
                ? {'action': 'confirm', 'checked': true}
                : 'acknowledge';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_native, null);
  });

  for (final mode in [AppThemeMode.dark, AppThemeMode.seaSalt]) {
    testWidgets('native surface presentation resolves $mode theme colors', (
      tester,
    ) async {
      final theme = createAppTheme(mode: mode);
      final presentation = await _capturePresentation(
        tester,
        requests,
        theme: theme,
      );
      final colors = _map(presentation['colors']);
      final scheme = theme.colorScheme;

      expect(
        colors['surface'],
        (theme.dialogTheme.backgroundColor ?? scheme.surfaceContainerHigh)
            .toARGB32(),
      );
      expect(
        colors['onSurface'],
        (theme.dialogTheme.titleTextStyle?.color ?? scheme.onSurface)
            .toARGB32(),
      );
      expect(
        colors['body'],
        (theme.dialogTheme.contentTextStyle?.color ?? scheme.onSurfaceVariant)
            .toARGB32(),
      );
      expect(colors['primary'], scheme.primary.toARGB32());
      expect(colors['onPrimary'], scheme.onPrimary.toARGB32());
      expect(colors['checkbox'], scheme.primary.toARGB32());
      expect(colors['checkboxCheck'], scheme.onPrimary.toARGB32());
      expect(colors['outline'], scheme.outline.toARGB32());
      expect(
        colors['barrier'],
        (theme.dialogTheme.barrierColor ?? Colors.black54).toARGB32(),
      );
      expect(requests.single['kind'], 'surfaceDialog');
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  for (final scenario in [
    (
      name: 'fixed medium ignores enlarged system text',
      font: UiFontSize.medium,
      systemScale: 2.0,
      scale: 1.0,
    ),
    (
      name: 'fixed large replaces enlarged system text',
      font: UiFontSize.large,
      systemScale: 2.0,
      scale: 1.25,
    ),
    (
      name: 'system font follows enlarged system text',
      font: UiFontSize.system,
      systemScale: 1.5,
      scale: 1.5,
    ),
  ]) {
    testWidgets('native presentation ${scenario.name}', (tester) async {
      final presentation = await _capturePresentation(
        tester,
        requests,
        theme: _fontTheme(),
        textScaler: scenario.font.resolveTextScaler(
          TextScaler.linear(scenario.systemScale),
        ),
      );
      final text = _map(presentation['text']);

      _expectText(
        text,
        'title',
        fontSize: 22 * scenario.scale,
        fontWeight: 500,
      );
      _expectText(text, 'body', fontSize: 16 * scenario.scale, fontWeight: 400);
      _expectText(
        text,
        'action',
        fontSize: 14 * scenario.scale,
        fontWeight: 600,
      );
      _expectText(
        text,
        'checkbox',
        fontSize: 18 * scenario.scale,
        fontWeight: 400,
      );
    });
  }

  testWidgets('native presentation honors global bold text for every role', (
    tester,
  ) async {
    final presentation = await _capturePresentation(
      tester,
      requests,
      theme: _fontTheme(),
      boldText: true,
    );
    final text = _map(presentation['text']);

    _expectText(text, 'title', fontSize: 22, fontWeight: 700);
    _expectText(text, 'body', fontSize: 16, fontWeight: 700);
    _expectText(text, 'action', fontSize: 14, fontWeight: 700);
    _expectText(text, 'checkbox', fontSize: 18, fontWeight: 700);
  });

  testWidgets('native presentation scales each font with a nonlinear scaler', (
    tester,
  ) async {
    final presentation = await _capturePresentation(
      tester,
      requests,
      theme: _fontTheme(),
      textScaler: const _NonlinearTextScaler(),
    );
    final text = _map(presentation['text']);

    _expectText(text, 'title', fontSize: 26.84, fontWeight: 500);
    _expectText(text, 'body', fontSize: 18.56, fontWeight: 400);
    _expectText(text, 'action', fontSize: 15.96, fontWeight: 600);
    _expectText(text, 'checkbox', fontSize: 21.24, fontWeight: 400);
  });

  for (final kind in ['debuff', 'headerResources']) {
    testWidgets('native $kind payload carries the same resolved presentation', (
      tester,
    ) async {
      final theme = createAppTheme(mode: AppThemeMode.seaSalt);
      final presentation = await _capturePresentation(
        tester,
        requests,
        theme: theme,
        kind: kind,
        textScaler: const TextScaler.linear(1.5),
        boldText: true,
      );
      final colors = _map(presentation['colors']);
      final text = _map(presentation['text']);

      expect(requests.single['kind'], kind);
      expect(colors['surface'], 0xfffcfefe);
      expect(colors['primary'], 0xff14666e);
      expect(colors['onPrimary'], 0xfffcfefe);
      _expectText(text, 'title', fontSize: 36, fontWeight: 700);
      _expectText(text, 'body', fontSize: 21, fontWeight: 700);
      expect(_map(presentation['layout'])['radius'], 28.0);
      if (kind == 'headerResources') {
        expect(requests.single['items'], [
          {'id': 'fuel', 'label': '燃料', 'value': '1200', 'checked': true},
        ]);
      }
    });
  }

  testWidgets('native presentation carries the standard dialog geometry', (
    tester,
  ) async {
    final presentation = await _capturePresentation(
      tester,
      requests,
      theme: createAppTheme(mode: AppThemeMode.dark),
    );
    final layout = _map(presentation['layout']);

    expect(layout['insetPadding'], [40.0, 24.0, 40.0, 24.0]);
    expect(layout['titlePadding'], [24.0, 24.0, 24.0, 0.0]);
    expect(layout['contentPadding'], [24.0, 16.0, 24.0, 24.0]);
    expect(layout['actionsPadding'], [24.0, 0.0, 24.0, 24.0]);
    expect(layout['radius'], 28.0);
    expect(layout['minWidth'], 280.0);
    expect(layout['actionMinHeight'], 40.0);
    expect(presentation['textDirection'], 'ltr');
  });

  testWidgets('native presentation resolves directional theme geometry', (
    tester,
  ) async {
    final base = createAppTheme(mode: AppThemeMode.seaSalt);
    final theme = base.copyWith(
      dialogTheme: base.dialogTheme.copyWith(
        insetPadding: const EdgeInsets.fromLTRB(16, 12, 20, 14),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(11, 13, 17, 19),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
    final presentation = await _capturePresentation(
      tester,
      requests,
      theme: theme,
      textDirection: TextDirection.rtl,
    );
    final layout = _map(presentation['layout']);

    expect(layout['insetPadding'], [16.0, 12.0, 20.0, 14.0]);
    expect(layout['actionsPadding'], [17.0, 13.0, 11.0, 19.0]);
    expect(layout['radius'], 18.0);
    expect(presentation['textDirection'], 'rtl');
  });
}

Future<Map<Object?, Object?>> _capturePresentation(
  WidgetTester tester,
  List<Map<Object?, Object?>> requests, {
  required ThemeData theme,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
  bool boldText = false,
  String kind = 'surfaceDialog',
}) async {
  final checklist = kind == 'headerResources'
      ? NativeGameResourceChecklistAdapter(
          kind: kind,
          port: const MethodChannelNativeGameResourceChecklistPort(),
          items: () => [
            {'id': 'fuel', 'label': '燃料', 'value': '1200', 'checked': true},
          ],
          isCurrent: () => true,
          onToggle: (_) {},
          doneLabel: '完成',
        )
      : null;
  if (checklist != null) addTearDown(checklist.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(844, 390),
          textScaler: textScaler,
          boldText: boldText,
        ),
        child: Directionality(
          textDirection: textDirection,
          child: GameDialogPresentationScope(
            nativeActivity: true,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: _open,
                  onPressed: () {
                    if (kind != 'surfaceDialog') {
                      showGameReminderDialog(
                        context: context,
                        kind: kind,
                        title: '提醒',
                        message: '游戏继续播放。',
                        nativePort:
                            checklist ??
                            MethodChannelNativeGameWarningDialogPort.forReminder(
                              kind,
                            ),
                        allowFlutterFallback: false,
                        builder: (_, _) => const SizedBox.shrink(),
                      );
                      return;
                    }
                    showGameSurfaceDialog<bool>(
                      context: context,
                      title: '确认刷新',
                      message: '刷新游戏框架。',
                      checkbox: GameSurfaceDialogCheckbox(
                        label: '以后不再确认',
                        onChanged: (_) {},
                      ),
                      actions: const [
                        GameSurfaceDialogAction(
                          id: 'cancel',
                          label: '取消',
                          value: false,
                        ),
                        GameSurfaceDialogAction(
                          id: 'confirm',
                          label: '确认刷新',
                          value: true,
                        ),
                      ],
                      allowFlutterFallback: false,
                      builder: (_, _) => const SizedBox.shrink(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  expect(requests, hasLength(1));
  return _map(requests.single['presentation']);
}

ThemeData _fontTheme() {
  final base = createAppTheme(mode: AppThemeMode.dark);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      bodyMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
    ),
  );
}

Map<Object?, Object?> _map(Object? value) {
  expect(
    value,
    isA<Map>(),
    reason: 'Native presentation must contain resolved style values',
  );
  return Map<Object?, Object?>.from(value! as Map);
}

void _expectText(
  Map<Object?, Object?> text,
  String role, {
  required double fontSize,
  required int fontWeight,
}) {
  final style = _map(text[role]);
  expect(style['fontSize'], closeTo(fontSize, .001), reason: '$role font size');
  expect(style['fontWeight'], fontWeight, reason: '$role font weight');
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) => fontSize + fontSize * fontSize / 100;

  @override
  double get textScaleFactor => 1;
}
