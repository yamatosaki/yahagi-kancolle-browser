import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('shows accepted quest cards and selected quest details', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
        'api_exec_count': 2,
        'api_list': <Object?>[
          <String, Object?>{
            'api_no': 201,
            'api_category': 2,
            'api_type': 2,
            'api_state': 2,
            'api_progress_flag': 1,
            'api_title': '敵艦隊を撃破せよ！',
            'api_detail': '敵艦隊を捕捉、これを撃破せよ！',
            'api_get_material': <int>[50, 50, 0, 0],
          },
          <String, Object?>{
            'api_no': 402,
            'api_category': 4,
            'api_type': 3,
            'api_state': 3,
            'api_progress_flag': 2,
            'api_title': '海上通商破壊作戦',
            'api_detail': '輸送船を撃沈せよ。',
            'api_get_material': <int>[500, 0, 400, 0],
          },
        ],
      }),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(home: QuestCenterPage(controller: controller)),
    );

    expect(find.text('任务'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('全任务'), findsOneWidget);
    expect(find.textContaining('更新于'), findsNothing);
    expect(find.byKey(const Key('quest-mode-tabs')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('quest-mode-tabs'))),
      const Size(260, 38),
    );
    expect(find.byKey(const Key('quest-search-button')), findsNothing);
    expect(find.byKey(const Key('quest-filter-button')), findsNothing);
    expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
    expect(find.byKey(const Key('quest-card-402')), findsOneWidget);
    expect(find.text('50%+'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-status-201')),
        matching: find.text('未完成'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-status-402')),
        matching: find.text('已完成'),
      ),
      findsOneWidget,
    );
    expect(find.text('进度可信度'), findsNothing);
    final detailTitle = find.byKey(const Key('quest-detail-title-402'));
    expect(tester.getTopLeft(detailTitle).dy, lessThan(130));
    await tester.tap(find.byKey(const Key('quest-card-201')));
    await tester.pump();
    expect(find.text('敵艦隊を捕捉、これを撃破せよ！'), findsOneWidget);
    expect(find.text('50'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('quest-card-402')));
    await tester.pump();

    expect(find.text('输送船を撃沉せよ。'), findsNothing);
    expect(find.text('輸送船を撃沈せよ。'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('shows a waiting state before quest data arrives', (
    tester,
  ) async {
    final controller = GameStateController();

    await tester.pumpWidget(
      MaterialApp(home: QuestCenterPage(controller: controller)),
    );

    expect(find.text('等待任务数据'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('all quests waits for catalog without null assertion', (
    tester,
  ) async {
    final controller = GameStateController();

    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(
          controller: controller,
          mode: QuestCenterMode.all,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('quest-catalog-loading')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('shows exact known quest progress only in quest details', (
    tester,
  ) async {
    final controller = GameStateController();
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
        'api_exec_count': 1,
        'api_list': <Object?>[
          <String, Object?>{
            'api_no': 503,
            'api_category': 5,
            'api_type': 1,
            'api_state': 2,
            'api_progress_flag': 0,
            'api_title': '修理任务',
            'api_detail': '',
          },
        ],
      }),
    );
    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_nyukyo/start',
        const <String, Object?>{},
        includeApiData: false,
        requestParams: const <String, Object?>{
          'api_ndock_id': '1',
          'api_ship_id': '999',
          'api_highspeed': '0',
        },
      ),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(home: QuestCenterPage(controller: controller)),
    );

    expect(
      find.byKey(const Key('quest-detail-exact-progress-503')),
      findsOneWidget,
    );
    expect(find.text('1/5'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-503')),
        matching: find.text('1/5'),
      ),
      findsNothing,
    );
    controller.dispose();
  });

  testWidgets('known quest completion appears immediately in details', (
    tester,
  ) async {
    final controller = GameStateController(
      questStore: _QuestFixtureStore(<int, GameQuest>{
        503: const GameQuest(
          id: 503,
          title: 'repair quest',
          detail: '',
          category: 5,
          type: 1,
          state: 2,
          progressFlag: 2,
          progressCurrent: 4,
          progressRequired: 5,
        ),
      }),
    );
    await controller.idle;
    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_nyukyo/start',
        const <String, Object?>{},
        includeApiData: false,
        requestParams: const <String, Object?>{
          'api_ndock_id': '1',
          'api_ship_id': '999',
          'api_highspeed': '0',
        },
      ),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(home: QuestCenterPage(controller: controller)),
    );

    expect(find.text('5/5'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-detail-status-503')),
        matching: find.text('已完成'),
      ),
      findsOneWidget,
    );
    controller.dispose();
  });

  testWidgets('does not duplicate the quest header inside the workspace', (
    tester,
  ) async {
    final controller = GameStateController();

    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(controller: controller, showTitle: false),
      ),
    );

    expect(find.byKey(const Key('quest-mode-tabs')), findsNothing);
    expect(find.textContaining('更新于'), findsNothing);
    controller.dispose();
  });

  testWidgets(
    'all quests shows filters, English code, progress and relations',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController(
        questStore: _QuestFixtureStore(<int, GameQuest>{
          201: const GameQuest(
            id: 201,
            title: 'live',
            detail: '',
            category: 2,
            type: 4,
            state: 2,
            progressFlag: 1,
          ),
        }),
      );
      await controller.idle;
      const catalog = QuestCatalog(<QuestCatalogEntry>[
        QuestCatalogEntry(
          gameId: 101,
          code: 'A1',
          name: '前置任务',
          description: '前置说明',
        ),
        QuestCatalogEntry(
          gameId: 201,
          code: 'B1',
          name: '当前任务',
          description: '当前说明',
          rewards: '奖励内容',
          prerequisites: <String>['A1'],
        ),
        QuestCatalogEntry(
          gameId: 202,
          code: 'Bd2',
          name: '后置任务',
          description: '后置说明',
          prerequisites: <String>['B1'],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(
            controller: controller,
            initialQuestId: 201,
            mode: QuestCenterMode.all,
            catalog: catalog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quest-search-button')), findsOneWidget);
      expect(find.byKey(const Key('quest-filter-button')), findsOneWidget);
      expect(find.byKey(const Key('quest-search-field')), findsNothing);
      await tester.tap(find.byKey(const Key('quest-search-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-search-field')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quest-search-field')), 'B1');
      await tester.tap(find.byKey(const Key('quest-search-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-202')), findsNothing);
      await tester.tap(find.byKey(const Key('quest-search-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quest-search-field')), '');
      await tester.tap(find.byKey(const Key('quest-search-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quest-filter-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-filter-sheet')), findsOneWidget);
      expect(find.text('全部类型'), findsOneWidget);
      expect(find.text('全部周期'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quest-filter-category-1')));
      await tester.tap(find.byKey(const Key('quest-filter-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-101')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-201')), findsNothing);
      await tester.tap(find.byKey(const Key('quest-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quest-filter-clear')));
      await tester.tap(find.byKey(const Key('quest-filter-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quest-card-201')));
      await tester.pump();
      expect(find.byKey(const Key('quest-card-code-201')), findsOneWidget);
      expect(find.text('当前任务'), findsWidgets);
      expect(
        tester.getSize(find.byKey(const Key('quest-card-201'))).height,
        64,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-card-201')),
          matching: find.text('50%+'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-relation-pre-101')),
          matching: find.text('A1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-relation-pre-101')),
          matching: find.text('前置任务'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('quest-relation-pre-scroll')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('quest-relation-post-scroll')),
        findsOneWidget,
      );
      expect(find.text('奖励内容'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quest-relation-post-202')));
      await tester.pump();
      expect(find.byKey(const Key('quest-detail-title-202')), findsOneWidget);
      expect(find.byKey(const Key('quest-detail-code-202')), findsOneWidget);
      expect(find.text('后置任务'), findsWidgets);
      controller.dispose();
    },
  );

  testWidgets(
    'portrait detail follows a short list without a half-screen gap',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController(
        questStore: _QuestFixtureStore(<int, GameQuest>{
          201: const GameQuest(
            id: 201,
            title: 'short list',
            detail: 'details',
            category: 2,
            type: 4,
            state: 2,
            progressFlag: 0,
          ),
        }),
      );
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(home: QuestCenterPage(controller: controller)),
      );

      final card = tester.getRect(find.byKey(const Key('quest-card-201')));
      final detail = tester.getRect(
        find.byKey(const Key('quest-detail-panel')),
      );
      expect(detail.top - card.bottom, lessThan(32));
      controller.dispose();
    },
  );

  testWidgets('refreshes after catalog controller update without restart', (
    tester,
  ) async {
    QuestCatalogDataset dataset(String name, int day) {
      final raw = jsonEncode(<String, Object?>{
        '201': <String, Object?>{'code': 'B1', 'name': name, 'desc': name},
      });
      return QuestCatalogDataset.parse(
        rawJson: raw,
        version: QuestCatalogVersion(
          committedAt: DateTime.utc(2026, 8, day),
          commitSha: day.toRadixString(16).padLeft(40, '0'),
          sha256: sha256.convert(utf8.encode(raw)).toString(),
        ),
        minimumQuestCount: 1,
      );
    }

    final completer = Completer<QuestCatalogUpdateResult>();
    final catalogController = QuestCatalogController(
      dataset: dataset('旧任务名', 1),
      updater: _CatalogUpdater(completer.future),
    );
    final gameController = GameStateController();
    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(
          controller: gameController,
          catalogController: catalogController,
          mode: QuestCenterMode.all,
        ),
      ),
    );
    expect(find.textContaining('旧任务名'), findsWidgets);

    final check = catalogController.checkForUpdates();
    completer.complete(QuestCatalogUpdated(dataset('新任务名', 2)));
    await check;
    await tester.pump();

    expect(find.textContaining('新任务名'), findsWidgets);
    expect(find.textContaining('旧任务名'), findsNothing);
    gameController.dispose();
    catalogController.dispose();
  });
}

final class _CatalogUpdater implements QuestCatalogUpdateClient {
  _CatalogUpdater(this.result);
  final Future<QuestCatalogUpdateResult> result;

  @override
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  }) => result;
}

final class _QuestFixtureStore extends QuestStore {
  _QuestFixtureStore(this.quests);

  final Map<int, GameQuest> quests;

  @override
  Future<Map<int, GameQuest>> loadQuests() async => quests;

  @override
  Future<void> saveQuests(Map<int, GameQuest> quests) async {}

  @override
  Future<void> clearQuests() async {}
}
