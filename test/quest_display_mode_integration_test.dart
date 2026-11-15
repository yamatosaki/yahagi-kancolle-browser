import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

const _questId = 201;
const _rewardText =
    '二回選択報酬：[開発資材×3、改修資材×2、戦闘糧食]'
    '[零式艦戦21型×2、九四式爆雷投射機×2、三式爆雷投射機]';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localeTestValue = const Locale('zh');
    binding.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
  });

  for (final size in [const Size(800, 400), const Size(600, 700)]) {
    for (final viaPinned in [true, false]) {
      testWidgets(
        'English quest summary and details fit $size via ${viaPinned ? 'pinned summary' : 'navigation'}',
        (tester) async {
          await _pumpQuestApp(tester, size: size, localeCode: 'en');
          final summary = find.byKey(const Key('quest-summary-item-201'));
          expect(summary, findsOneWidget);
          expect(find.text('Quest summary'), findsOneWidget);
          expect(find.text('In progress'), findsOneWidget);
          expect(find.text('布局回归任务'), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'English pinned summary',
          );

          if (viaPinned) {
            await tester.ensureVisible(summary);
            await tester.tap(summary);
            await tester.pump(const Duration(milliseconds: 300));
          } else {
            await _openQuestNavigation(tester);
            await _selectQuest(tester);
          }
          expect(find.byType(QuestCenterPage), findsOneWidget);
          expect(find.text('Accepted'), findsOneWidget);
          expect(
            find.byKey(const Key('quest-detail-title-201')),
            findsOneWidget,
          );
          expect(find.text('任务列表与奖励详情遵循保存的显示模式。'), findsOneWidget);
          await _openRewards(tester);
          expect(find.text('Quest rewards'), findsWidgets);
          expect(find.text(_rewardText), findsOneWidget);
          _expectHorizontal(tester, 'English quest details at $size');
          expect(
            tester.takeException(),
            isNull,
            reason: 'English quest details',
          );
        },
      );
    }
  }

  testWidgets(
    'saved landscape reaches quest layout through the left navigation',
    (tester) async {
      final fixture = await _pumpQuestApp(tester);
      expect(fixture.display.displayMode, DisplayMode.landscape);

      await _openQuestNavigation(tester);
      await _selectQuest(tester);
      final page = find.byType(QuestCenterPage);
      // A normal left sidebar leaves 752 logical pixels from the 800px window.
      // That is below the old 760px page breakpoint despite saved landscape.
      expect(tester.getSize(page).width, closeTo(752, 0.01));
      _expectHorizontal(tester, 'saved landscape on initial navigation');
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-detail-tab-rewards')),
          matching: find.text('任务奖励'),
        ),
        findsOneWidget,
      );
      await _openRewards(tester);
      expect(find.text('任务奖励'), findsNWidgets(2));
      expect(find.text(_rewardText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('display mode changes reflow the mounted quest page in place', (
    tester,
  ) async {
    final fixture = await _pumpQuestApp(tester);
    await _openQuestNavigation(tester);
    await _selectQuest(tester);
    final page = find.byType(QuestCenterPage);
    final originalElement = tester.element(page);

    // Assert portrait before landscape so a broken initial landscape layout
    // cannot hide the independent portrait/reflow checks.
    await fixture.display.setDisplayMode(DisplayMode.portrait);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await fixture.store.loadDisplayMode(), DisplayMode.portrait);
    expect(tester.element(page), same(originalElement));
    _expectStacked(tester, 'portrait at the same window size');
    await _openRewards(tester);
    expect(find.text(_rewardText), findsOneWidget);

    await fixture.display.setDisplayMode(DisplayMode.landscape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await fixture.store.loadDisplayMode(), DisplayMode.landscape);
    expect(tester.element(page), same(originalElement));
    _expectHorizontal(tester, 'landscape restored without reopening quests');
    await _openRewards(tester);
    expect(find.text(_rewardText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinned quest opens the same landscape detail layout', (
    tester,
  ) async {
    final fixture = await _pumpQuestApp(tester);
    expect(fixture.display.displayMode, DisplayMode.landscape);
    final summary = find.byKey(const Key('quest-summary-item-201'));
    expect(summary, findsOneWidget);
    await tester.ensureVisible(summary);
    await tester.pump();
    await tester.tap(summary);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuestCenterPage), findsOneWidget);
    expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
    _expectHorizontal(tester, 'pinned summary navigation');
    await _openRewards(tester);
    expect(find.text(_rewardText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foldable detail stays horizontal in every saved display mode', (
    tester,
  ) async {
    final fixture = await _pumpQuestApp(
      tester,
      size: const Size(600, 700),
      displayMode: DisplayMode.portrait,
    );
    await _openQuestNavigation(tester);
    await _selectQuest(tester);
    final page = find.byType(QuestCenterPage);
    final originalElement = tester.element(page);
    expect(tester.getSize(page).width, closeTo(552, 0.01));
    _expectHorizontal(tester, 'saved portrait on a near-square foldable');

    for (final displayMode in DisplayMode.values) {
      await fixture.display.setDisplayMode(displayMode);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.element(page), same(originalElement));
      _expectHorizontal(tester, 'near-square foldable in $displayMode');
    }
    tester.view.physicalSize = const Size(700, 600);
    await tester.pump(const Duration(milliseconds: 300));
    _expectHorizontal(tester, 'rotated near-square foldable in portrait mode');

    tester.view.physicalSize = const Size(390, 780);
    await tester.pump(const Duration(milliseconds: 300));
    _expectStacked(tester, 'compact portrait window after folding');
    expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
    await _openRewards(tester);
    expect(find.text(_rewardText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'portrait quest navigation keeps its list above selected details',
    (tester) async {
      await _pumpQuestApp(
        tester,
        size: const Size(390, 780),
        displayMode: DisplayMode.portrait,
      );
      await _openQuestNavigation(tester);

      _expectStacked(tester, 'phone portrait on initial navigation');
      final page = find.byType(QuestCenterPage);
      final originalElement = tester.element(page);

      await _selectQuest(tester);
      _expectStacked(tester, 'phone portrait after selecting a quest');
      expect(tester.element(page), same(originalElement));
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
      expect(find.text('任务列表与奖励详情遵循保存的显示模式。'), findsOneWidget);
      await _openRewards(tester);
      expect(find.text(_rewardText), findsOneWidget);
      _expectStacked(
        tester,
        'portrait list remains visible while reading rewards',
      );

      await _selectQuest(tester);
      _expectStacked(tester, 'reselecting updates the lower detail in place');
      expect(tester.element(page), same(originalElement));
      expect(find.text('任务列表与奖励详情遵循保存的显示模式。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectHorizontal(WidgetTester tester, String reason) {
  final card = tester.getRect(find.byKey(const Key('quest-card-201')));
  final detail = tester.getRect(find.byKey(const Key('quest-detail-panel')));
  expect(detail.left, greaterThan(card.right), reason: reason);
  expect(detail.top, lessThan(card.bottom), reason: reason);
}

void _expectStacked(WidgetTester tester, String reason) {
  expect(
    find.byKey(const Key('quest-card-201')),
    findsOneWidget,
    reason: reason,
  );
  expect(
    find.byKey(const Key('quest-list-panel')),
    findsOneWidget,
    reason: reason,
  );
  expect(
    find.byKey(const Key('quest-detail-panel')),
    findsOneWidget,
    reason: reason,
  );
  final list = tester.getRect(find.byKey(const Key('quest-list-panel')));
  final detail = tester.getRect(find.byKey(const Key('quest-detail-panel')));
  final paneHeight = list.height + detail.height;
  expect(detail.top, greaterThanOrEqualTo(list.bottom), reason: reason);
  expect(detail.left, closeTo(list.left, 0.01), reason: reason);
  expect(detail.width, closeTo(list.width, 0.01), reason: reason);
  expect(list.height, lessThanOrEqualTo(paneHeight / 2 + 0.01), reason: reason);
  expect(
    detail.height,
    greaterThanOrEqualTo(paneHeight / 2 - 0.01),
    reason: reason,
  );
  expect(
    find.byKey(const Key('quest-back-to-list')),
    findsNothing,
    reason: reason,
  );
}

Future<void> _selectQuest(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quest-card-201')));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openRewards(WidgetTester tester) async {
  final tab = find.byKey(const Key('quest-detail-tab-rewards'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(find.text(_rewardText));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openQuestNavigation(WidgetTester tester) async {
  final item = find.byKey(const Key('workspace-nav-quests'));
  final navigation = find.byKey(const Key('workspace-navigation-list'));
  await tester.dragUntilVisible(item, navigation, const Offset(0, -50));
  await tester.tap(item);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<
  ({DisplayModeController display, SharedPreferencesDisplayModeStore store})
>
_pumpQuestApp(
  WidgetTester tester, {
  Size size = const Size(800, 400),
  DisplayMode displayMode = DisplayMode.landscape,
  String? localeCode,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'settings.displayMode': displayMode.name,
    'layout_dashboard_card_hidden': <String>[
      for (final id in LayoutSettingsStore.defaultDashboardCardOrder)
        if (id != 'quests') id,
    ],
  });
  final previousTimerSetting = GameStateController.disableTimerForTest;
  GameStateController.disableTimerForTest = true;
  addTearDown(
    () => GameStateController.disableTimerForTest = previousTimerSetting,
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final layout = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  if (localeCode != null) await layout.setLocaleCode(localeCode);
  expect(layout.workspaceMenuOnRight, isFalse);
  expect(layout.workspaceMenuHorizontal, isFalse);
  final gameState = GameStateController(
    questStore: _MemoryQuestStore(<int, GameQuest>{
      _questId: const GameQuest(
        id: _questId,
        title: '布局回归任务',
        detail: '任务列表与奖励详情遵循保存的显示模式。',
        category: 2,
        type: 4,
        state: 2,
        progressFlag: 0,
        materials: <int>[50, 50, 0, 0],
      ),
    }),
  );
  await gameState.idle;
  final battle = BattleController(gameState: () => gameState.state);
  final toolbar = GameToolbarController();
  final capture = GameCaptureController();
  final browser = GameBrowserController();
  final status = PrototypeStatusController();
  final network = NetworkSettingsController(
    store: SharedPreferencesNetworkSettingsStore(),
  );
  final bypass = GadgetBypassController(
    store: SharedPreferencesGadgetBypassStore(),
    port: MethodChannelGadgetBypassPort(),
  );
  final safety = await SafetySettingsController.load(
    MemorySafetySettingsStore(),
  );
  final store = SharedPreferencesDisplayModeStore();
  final display = await DisplayModeController.load(store);
  final mode = await CaptureModeController.load(
    SharedPreferencesCaptureModeStore(),
  );
  final audio = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  final raw = jsonEncode(<String, Object?>{
    '201': <String, Object?>{
      'code': 'Bd1',
      'name': '布局回归任务',
      'desc': '任务列表与奖励详情遵循保存的显示模式。',
      'rewards': _rewardText,
      'resources': <List<int>>[
        <int>[50, 50, 0, 0],
        <int>[0, 0, 0, 0],
      ],
    },
  });
  final catalog = QuestCatalogController(
    dataset: QuestCatalogDataset.parse(
      rawJson: raw,
      version: QuestCatalogVersion(
        committedAt: DateTime.utc(2026, 10, 7),
        commitSha: '1' * 40,
        sha256: sha256.convert(utf8.encode(raw)).toString(),
      ),
      minimumQuestCount: 1,
    ),
    updater: _UnchangedCatalogUpdater(),
  );
  for (final notifier in <ChangeNotifier>[
    layout,
    gameState,
    battle,
    toolbar,
    capture,
    browser,
    status,
    network,
    bypass,
    safety,
    display,
    mode,
    audio,
    catalog,
  ]) {
    addTearDown(notifier.dispose);
  }
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    YahagiApp(
      layoutSettingsController: layout,
      networkSettingsController: network,
      gadgetBypassController: bypass,
      safetySettingsController: safety,
      displayModeController: display,
      controller: status,
      browserController: browser,
      captureModeController: mode,
      gameCaptureController: capture,
      gameStateController: gameState,
      battleController: battle,
      audioController: audio,
      toolbarController: toolbar,
      questCatalogController: catalog,
      gameSurface: const ColoredBox(color: Colors.black),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return (display: display, store: store);
}

class _MemoryQuestStore extends QuestStore {
  _MemoryQuestStore(this.quests);
  Map<int, GameQuest> quests;

  @override
  Future<Map<int, GameQuest>> loadQuests() async => Map.of(quests);

  @override
  Future<void> saveQuests(Map<int, GameQuest> value) async {
    quests = Map.of(value);
  }

  @override
  Future<void> clearQuests() async => quests.clear();
}

class _UnchangedCatalogUpdater implements QuestCatalogUpdateClient {
  @override
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  }) async => QuestCatalogUpToDate(current.version);
}
