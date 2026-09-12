import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/data_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('account switch closes stale base senka input without saving', (
    tester,
  ) async {
    AccountSession.shared.selectMember(1001);
    addTearDown(AccountSession.shared.reset);
    final dependencies = await _Dependencies.create();
    addTearDown(dependencies.dispose);
    final senka = SenkaController(
      store: _MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 20, 3),
    );
    await senka.initialize();
    addTearDown(senka.dispose);
    await dependencies.pump(tester, senkaController: senka);
    final set = find.byKey(const Key('settings-set-base-senka'));
    await tester.ensureVisible(set);
    await tester.tap(set);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('settings-base-senka-input')),
      '123.45',
    );
    AccountSession.shared.selectMember(2002);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-base-senka-dialog')), findsNothing);
    expect(senka.monthBaseSenka, 0);
  });

  testWidgets(
    'account switch cancels a pending base senka reset confirmation',
    (tester) async {
      AccountSession.shared.selectMember(1001);
      addTearDown(AccountSession.shared.reset);
      final dependencies = await _Dependencies.create();
      addTearDown(dependencies.dispose);
      final senka = SenkaController(
        store: _MemorySenkaStore(),
        now: () => DateTime.utc(2026, 8, 20, 3),
      );
      await senka.initialize();
      await senka.setBaseSenka(55);
      addTearDown(senka.dispose);
      await dependencies.pump(tester, senkaController: senka);
      final reset = find.byKey(const Key('settings-reset-base-senka'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      AccountSession.shared.selectMember(2002);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-reset-base-senka-dialog')),
        findsNothing,
      );
      expect(senka.monthBaseSenka, 55);
    },
  );

  testWidgets('横屏键盘弹出后素战果输入弹窗不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    final dependencies = await _Dependencies.create();
    addTearDown(dependencies.dispose);
    final senka = SenkaController(
      store: _MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 20, 3),
    );
    await senka.initialize();
    addTearDown(senka.dispose);
    await dependencies.pump(tester, senkaController: senka);

    final set = find.byKey(const Key('settings-set-base-senka'));
    await tester.ensureVisible(set);
    await tester.tap(set);
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final save = find.byKey(const Key('settings-base-senka-save'));
    expect(save, findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(160));
  });

  testWidgets('数据设置可归零并手动填写本月累计素战果', (tester) async {
    final dependencies = await _Dependencies.create();
    addTearDown(dependencies.dispose);
    final store = _MemorySenkaStore(
      SenkaState.forMonth('2026-08').copyWith(
        latestExperience: 15000000,
        days: const {
          '2026-08-19': SenkaDayRecord(experience: 12.34, eo: 75),
          '2026-08-20': SenkaDayRecord(experience: 2.18, quest: 80),
        },
      ),
    );
    final senka = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 20, 3),
    );
    await senka.initialize();
    addTearDown(senka.dispose);
    await dependencies.pump(tester, senkaController: senka);

    final reset = find.byKey(const Key('settings-reset-base-senka'));
    final set = find.byKey(const Key('settings-set-base-senka'));
    final summary = find.byKey(const Key('settings-base-senka-summary'));
    expect(summary, findsOneWidget);
    expect(reset, findsOneWidget);
    expect(set, findsOneWidget);
    expect(find.text('本月累计素战果'), findsOneWidget);
    expect(find.textContaining('14.52'), findsOneWidget);

    final resetRect = tester.getRect(reset);
    final setRect = tester.getRect(set);
    expect((resetRect.center.dy - setRect.center.dy).abs(), lessThan(0.1));
    expect(resetRect.width, greaterThanOrEqualTo(44));
    expect(resetRect.height, greaterThanOrEqualTo(44));
    expect(setRect.width, greaterThanOrEqualTo(44));
    expect(setRect.height, greaterThanOrEqualTo(44));

    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-reset-base-senka-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('settings-reset-base-senka-confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(senka.monthBaseSenka, 0);
    expect(senka.state.day(DateTime(2026, 8, 19)).eo, 75);
    expect(senka.state.day(DateTime(2026, 8, 20)).quest, 80);
    expect(find.text('本月累计素战果已归零'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(set);
    await tester.tap(set);
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('settings-base-senka-input'));
    expect(input, findsOneWidget);
    await tester.enterText(input, '123.45');
    await tester.tap(find.byKey(const Key('settings-base-senka-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(senka.monthBaseSenka, 123.45);
    final setNotice = find.byKey(topNoticeKey);
    expect(
      find.descendant(of: setNotice, matching: find.text('本月累计素战果已设为 123.45')),
      findsOneWidget,
    );
    expect(find.text('本月累计素战果已归零'), findsNothing);
    expect(
      find.descendant(
        of: setNotice,
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('手动填写素战果拒绝非法值并保持对话框', (tester) async {
    final dependencies = await _Dependencies.create();
    addTearDown(dependencies.dispose);
    final senka = SenkaController(
      store: _MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 20, 3),
    );
    await senka.initialize();
    addTearDown(senka.dispose);
    await dependencies.pump(tester, senkaController: senka);

    final set = find.byKey(const Key('settings-set-base-senka'));
    await tester.ensureVisible(set);
    await tester.tap(set);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('settings-base-senka-input')),
    );
    field.controller!.text = '12.345';
    await tester.tap(find.byKey(const Key('settings-base-senka-save')));
    await tester.pump();

    expect(find.byKey(const Key('settings-base-senka-dialog')), findsOneWidget);
    expect(find.byKey(const Key('settings-base-senka-error')), findsOneWidget);
    expect(senka.monthBaseSenka, 0);
  });
}

final class _MemorySenkaStore implements SenkaStore {
  _MemorySenkaStore([this.state]);

  SenkaState? state;

  @override
  Future<SenkaState?> load() async => state;

  @override
  Future<void> save(SenkaState value) async => state = value;
}

final class _Dependencies {
  _Dependencies({
    required this.capture,
    required this.browser,
    required this.gameCapture,
    required this.prototype,
    required this.gameState,
  });

  final CaptureModeController capture;
  final GameBrowserController browser;
  final GameCaptureController gameCapture;
  final PrototypeStatusController prototype;
  final GameStateController gameState;

  static Future<_Dependencies> create() async => _Dependencies(
    capture: await CaptureModeController.load(_MemoryCaptureModeStore()),
    browser: GameBrowserController(),
    gameCapture: GameCaptureController(),
    prototype: PrototypeStatusController(),
    gameState: GameStateController(),
  );

  Future<void> pump(
    WidgetTester tester, {
    required SenkaController senkaController,
  }) => tester.pumpWidget(
    MaterialApp(
      home: TopNoticeHost(
        child: Scaffold(
          body: DataSettingsPage(
            captureModeController: capture,
            browserController: browser,
            gameCaptureController: gameCapture,
            prototypeStatusController: prototype,
            gameStateController: gameState,
            senkaController: senkaController,
          ),
        ),
      ),
    ),
  );

  void dispose() {
    capture.dispose();
    browser.dispose();
    gameCapture.dispose();
    prototype.dispose();
    gameState.dispose();
  }
}

final class _MemoryCaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}
