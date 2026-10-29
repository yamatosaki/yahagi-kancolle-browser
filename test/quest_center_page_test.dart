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
  testWidgets(
    'resources and choice rewards survive quest states and mode changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1180, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController(
        questStore: _QuestFixtureStore(const <int, GameQuest>{}),
      );
      addTearDown(controller.dispose);
      await controller.idle;
      const materials = <int>[0, 200, 1200, 200];
      const rewards =
          '二回選択報酬：[装備運用枠+8、二式爆雷★4、開発資材×40]'
          '[61cm五連装(酸素)魚雷★4×2、12.7cm連装高角砲改二★4、新型兵装資材×3]';
      final catalog = QuestCatalog(<QuestCatalogEntry>[
        QuestCatalogEntry.fromJson(1164, <String, Object?>{
          'code': 'F142',
          'name': '水雷戦隊新改装艦、改装準備！',
          'desc': '第一艦隊に旗艦「玉波」を配備せよ！',
          'rewards': rewards,
          'resources': <Object?>[
            <num>[0, 200, 1200.0, 200],
            <int>[0, 0, 0, 0],
          ],
        }),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(
            controller: controller,
            catalog: catalog,
            mode: QuestCenterMode.all,
          ),
        ),
      );

      Future<void> expectRewards(String reason) async {
        await _openDetailTab(tester, 'rewards');
        _expectQuestMaterials(tester, materials, reason: reason);
        expect(_questDetailText(rewards), findsOneWidget, reason: reason);
        for (final item in const <String>[
          '二式爆雷★4',
          '開発資材×40',
          '61cm五連装(酸素)魚雷★4×2',
          '新型兵装資材×3',
        ]) {
          expect(
            find.descendant(
              of: find.byKey(const Key('quest-detail-panel')),
              matching: find.textContaining(item),
            ),
            findsOneWidget,
            reason: reason,
          );
        }
      }

      await expectRewards('catalog rewards before the first quest snapshot');
      var sequence = 0;
      for (final state in const <int>[1, 2, 3, 1]) {
        await _acceptRewardQuestSnapshot(
          controller,
          id: 1164,
          state: state,
          materials: materials,
          sequence: ++sequence,
        );
        await tester.pumpAndSettle();
        final status = switch (state) {
          1 => '未接取',
          2 => '进行中',
          _ => '待领取',
        };
        expect(
          find.descendant(
            of: find.byKey(const Key('quest-detail-status-1164')),
            matching: find.text(status),
          ),
          findsOneWidget,
        );
        await expectRewards('all quests, api_state $state, snapshot $sequence');

        if (state >= 2) {
          await tester.tap(_questModeTab('已接取'));
          await tester.pumpAndSettle();
          await expectRewards('active quests, api_state $state');
          await tester.tap(_questModeTab('全任务'));
          await tester.pumpAndSettle();
          await expectRewards('return to all quests, api_state $state');
        }
      }
      await tester.tap(_questModeTab('已接取'));
      await tester.pumpAndSettle();
      expect(find.text('当前无进行中任务'), findsOneWidget);
      await tester.tap(_questModeTab('全任务'));
      await tester.pumpAndSettle();
      await expectRewards('return to all quests after stopping the quest');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'API materials stay visible without catalog and override catalog values',
    (tester) async {
      final controller = GameStateController(
        questStore: _QuestFixtureStore(const <int, GameQuest>{}),
      );
      addTearDown(controller.dispose);
      await controller.idle;
      const materials = <int>[50, 0, 400, 0];
      await _acceptRewardQuestSnapshot(
        controller,
        id: 9001,
        state: 2,
        materials: materials,
      );
      await tester.pumpWidget(
        MaterialApp(home: QuestCenterPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _openDetailTab(tester, 'rewards');
      _expectQuestMaterials(tester, materials, reason: 'no catalog supplied');

      const rewards = '零式艦戦21型×2、開発資材×3';
      final catalog = QuestCatalog(<QuestCatalogEntry>[
        QuestCatalogEntry.fromJson(9001, <String, Object?>{
          'code': 'B1',
          'name': '報酬のある任務',
          'desc': '任務を達成せよ。',
          'rewards': rewards,
          'resources': <Object?>[
            <num>[600, 300, 0.0, 200],
            <int>[0, 0, 3, 0],
          ],
        }),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(controller: controller, catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();
      for (final mode in const <String>['已接取', '全任务']) {
        await tester.tap(_questModeTab(mode));
        await tester.pumpAndSettle();
        await _openDetailTab(tester, 'rewards');
        _expectQuestMaterials(tester, materials, reason: mode);
        expect(_questDetailText(rewards), findsOneWidget, reason: mode);
        for (final value in const <String>['600', '300', '200', '650']) {
          expect(_questDetailText(value), findsNothing, reason: mode);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone detail wraps long rewards beside all four resources', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController(
      questStore: _QuestFixtureStore(const <int, GameQuest>{}),
    );
    addTearDown(controller.dispose);
    await controller.idle;
    const materials = <int>[0, 200, 1200, 200];
    const rewards =
        '二回選択報酬：[装備運用枠+8、二式爆雷★4、開発資材×40]\n'
        '[61cm五連装(酸素)魚雷★4×2、12.7cm連装高角砲改二★4、新型兵装資材×3]';
    final catalog = QuestCatalog(<QuestCatalogEntry>[
      QuestCatalogEntry.fromJson(1164, <String, Object?>{
        'code': 'F142',
        'name': '水雷戦隊新改装艦、改装準備！',
        'desc': '第一艦隊に旗艦「玉波」を配備せよ！',
        'rewards': rewards,
        'resources': <Object?>[
          <num>[0, 200, 1200.0, 200],
          <int>[0, 0, 0, 0],
        ],
      }),
    ]);
    await _acceptRewardQuestSnapshot(
      controller,
      id: 1164,
      state: 2,
      materials: materials,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(controller: controller, catalog: catalog),
      ),
    );
    for (final mode in const <String>['已接取', '全任务']) {
      await tester.tap(_questModeTab(mode));
      await tester.pumpAndSettle();
      await _openQuestDetail(tester, 1164);
      await _openDetailTab(tester, 'rewards');
      _expectQuestMaterials(tester, materials, reason: mode);
      final reward = _questDetailText(rewards);
      expect(reward, findsOneWidget, reason: mode);
      await tester.ensureVisible(reward);
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(reward);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getSize(reward).height, greaterThan(60));
      final panel = tester.getRect(find.byKey(const Key('quest-detail-panel')));
      final rewardRect = tester.getRect(reward);
      expect(rewardRect.left, greaterThanOrEqualTo(panel.left));
      expect(rewardRect.right, lessThanOrEqualTo(panel.right));
      expect(rewardRect.top, greaterThanOrEqualTo(panel.top));
      expect(rewardRect.bottom, lessThanOrEqualTo(panel.bottom));
      expect(tester.takeException(), isNull, reason: mode);
    }
  });

  testWidgets('unfolded square screen keeps quest list beside details', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController(
      questStore: _QuestFixtureStore(<int, GameQuest>{
        201: const GameQuest(
          id: 201,
          title: '敵艦隊を撃破せよ！',
          detail: '敵艦隊を捕捉、これを撃破せよ！',
          category: 2,
          type: 2,
          state: 2,
          progressFlag: 0,
        ),
      }),
    );
    addTearDown(controller.dispose);
    await controller.idle;

    for (final size in const [Size(673, 841), Size(841, 673), Size(720, 720)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(home: QuestCenterPage(controller: controller)),
      );
      final card = tester.getRect(find.byKey(const Key('quest-card-201')));
      final detail = tester.getRect(
        find.byKey(const Key('quest-detail-panel')),
      );
      expect(detail.left, greaterThan(card.right), reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

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
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-mode-tabs')),
        matching: find.text('已接取'),
      ),
      findsOneWidget,
    );
    expect(find.text('全任务'), findsOneWidget);
    expect(find.textContaining('更新于'), findsNothing);
    expect(find.byKey(const Key('quest-mode-tabs')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('quest-mode-tabs'))),
      const Size(220, 40),
    );
    expect(find.byKey(const Key('quest-search-button')), findsOneWidget);
    expect(find.byKey(const Key('quest-filter-button')), findsNothing);
    expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
    expect(find.byKey(const Key('quest-card-402')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-201')),
        matching: find.text('0/1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-402')),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-status-201')),
        matching: find.text('进行中'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-status-402')),
        matching: find.text('待领取'),
      ),
      findsOneWidget,
    );
    expect(find.text('进度可信度'), findsNothing);
    final detailTitle = find.byKey(const Key('quest-detail-title-402'));
    expect(tester.getTopLeft(detailTitle).dy, lessThan(130));
    await tester.tap(find.byKey(const Key('quest-card-201')));
    await tester.pump();
    expect(find.text('敵艦隊を捕捉、これを撃破せよ！'), findsOneWidget);
    await _openDetailTab(tester, 'rewards');
    expect(find.text('50'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('quest-card-402')));
    await tester.pump();

    expect(find.text('输送船を撃沉せよ。'), findsNothing);
    expect(find.text('輸送船を撃沈せよ。'), findsOneWidget);
    await _openDetailTab(tester, 'rewards');
    expect(find.text('500'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    controller.dispose();
  });

  testWidgets(
    'Chinese translation is opt-in and updates quest cards and details',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1180, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController(
        questStore: _QuestFixtureStore(<int, GameQuest>{
          442: const GameQuest(
            id: 442,
            title: '西方連絡作戦準備を実施せよ！',
            detail: '西方連絡作戦準備：各遠征を実施せよ！',
            category: 4,
            type: 4,
            state: 2,
            progressFlag: 0,
            materials: <int>[0, 900, 500, 500],
          ),
        }),
      );
      await controller.idle;
      final catalog = QuestCatalog(const <QuestCatalogEntry>[
        QuestCatalogEntry(
          gameId: 441,
          code: 'D1',
          name: '日本語前提任務',
          description: '日本語前提説明',
          translatedName: '中文前置任务',
          translatedDescription: '中文前置说明',
        ),
        QuestCatalogEntry(
          gameId: 442,
          code: 'Dy7',
          name: '西方連絡作戦準備を実施せよ！',
          description: '西方連絡作戦準備：各遠征を実施せよ！',
          translatedName: '实施西方联络作战准备！',
          translatedDescription: '西方联络作战准备：实施各项远征！',
          prerequisites: <String>['D1'],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(controller: controller, catalog: catalog),
        ),
      );

      final toggle = find.byKey(const Key('quest-translation-toggle'));
      final tabs = find.byKey(const Key('quest-mode-tabs'));
      expect(toggle, findsOneWidget);
      expect(tester.getRect(toggle).right, lessThan(tester.getRect(tabs).left));
      expect(find.text('西方連絡作戦準備を実施せよ！'), findsWidgets);
      expect(find.text('实施西方联络作战准备！'), findsNothing);
      expect(find.byType(Image), findsNothing);
      await _openDetailTab(tester, 'rewards');
      _expectQuestMaterials(tester, const [
        0,
        900,
        500,
        500,
      ], reason: 'original');
      await _openDetailTab(tester, 'relations');
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-relation-pre-441')),
          matching: find.text('日本語前提任務'),
        ),
        findsOneWidget,
      );
      expect(find.text('中文前置任务'), findsNothing);
      await _openDetailTab(tester, 'conditions');

      await tester.tap(toggle);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('quest-card-442')),
          matching: find.text('实施西方联络作战准备！'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-detail-title-442')),
          matching: find.text('实施西方联络作战准备！'),
        ),
        findsOneWidget,
      );
      expect(find.text('西方联络作战准备：实施各项远征！'), findsOneWidget);
      expect(find.text('燃料 0'), findsNothing);
      expect(find.text('弹药 900'), findsNothing);
      await _openDetailTab(tester, 'rewards');
      _expectQuestMaterials(tester, const [
        0,
        900,
        500,
        500,
      ], reason: 'translated');
      await _openDetailTab(tester, 'relations');
      final translatedRelation = find.byKey(
        const Key('quest-relation-pre-441'),
      );
      expect(
        find.descendant(of: translatedRelation, matching: find.text('中文前置任务')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: translatedRelation, matching: find.text('日本語前提任務')),
        findsNothing,
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          home: QuestCenterPage(controller: controller, catalog: catalog),
        ),
      );
      expect(find.text('实施西方联络作战准备！'), findsNothing);
      expect(find.text('西方連絡作戦準備を実施せよ！'), findsWidgets);
      controller.dispose();
    },
  );

  testWidgets('missing Chinese fields fall back to Japanese detail text', (
    tester,
  ) async {
    final controller = GameStateController(
      questStore: _QuestFixtureStore(<int, GameQuest>{
        201: const GameQuest(
          id: 201,
          title: '日本語任務名',
          detail: '日本語説明',
          category: 2,
          type: 4,
          state: 2,
          progressFlag: 0,
        ),
      }),
    );
    await controller.idle;
    final catalog = QuestCatalog(const <QuestCatalogEntry>[
      QuestCatalogEntry(
        gameId: 201,
        code: 'Bd1',
        name: '日本語任務名',
        description: '日本語説明',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(controller: controller, catalog: catalog),
      ),
    );
    await tester.tap(find.byKey(const Key('quest-translation-toggle')));
    await tester.pump();

    expect(find.text('日本語任務名'), findsWidgets);
    expect(find.text('日本語説明'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('Chinese translation also applies in all-quests mode', (
    tester,
  ) async {
    final controller = GameStateController();
    final catalog = QuestCatalog(const <QuestCatalogEntry>[
      QuestCatalogEntry(
        gameId: 442,
        code: 'Dy7',
        name: '日本語任務名',
        description: '日本語説明',
        translatedName: '中文任务名',
        translatedDescription: '中文说明',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(
          controller: controller,
          catalog: catalog,
          mode: QuestCenterMode.all,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('quest-translation-toggle')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-442')),
        matching: find.text('中文任务名'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-detail-title-442')),
        matching: find.text('中文任务名'),
      ),
      findsOneWidget,
    );
    expect(find.text('中文说明'), findsOneWidget);
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
    expect(find.text('1/5'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-card-503')),
        matching: find.text('1/5'),
      ),
      findsOneWidget,
    );
    controller.dispose();
  });

  testWidgets(
    'local completion keeps server status while showing exact progress',
    (tester) async {
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

      expect(find.text('5/5'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-detail-status-503')),
          matching: find.text('进行中'),
        ),
        findsOneWidget,
      );
      controller.dispose();
    },
  );

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
    'unified query commits drafts and keeps portrait relation navigation in scope',
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
      final filters = QuestFilterController();
      addTearDown(controller.dispose);
      addTearDown(filters.dispose);
      await controller.idle;
      final catalog = QuestCatalog(const <QuestCatalogEntry>[
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
          theme: ThemeData(
            fontFamily: 'HarmonyOS_Sans_SC',
            fontFamilyFallback: const <String>['HarmonyOS_Sans_TC'],
          ),
          home: QuestCenterPage(
            controller: controller,
            initialQuestId: 201,
            mode: QuestCenterMode.all,
            catalog: catalog,
            filterController: filters,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quest-search-button')), findsOneWidget);
      expect(find.byKey(const Key('quest-filter-button')), findsNothing);
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-back-to-list')), findsNothing);
      expect(find.text('当前说明'), findsOneWidget);
      expect(find.text('奖励内容'), findsNothing);

      await _tapQuestKey(tester, 'quest-search-button');
      expect(find.byKey(const Key('quest-query-dialog')), findsOneWidget);
      expect(find.text('查询范围：全任务'), findsOneWidget);
      expect(find.text('全部类型'), findsOneWidget);
      expect(find.text('全部周期'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quest-search-field')), 'B1');
      await tester.pumpAndSettle();
      expect(filters.value, const QuestQuery());
      expect(find.text('显示 1 个任务'), findsOneWidget);
      await _tapQuestKey(tester, 'quest-query-cancel');
      expect(filters.value, const QuestQuery());
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);

      await _applyQuestSearch(tester, 'B1');
      expect(filters.query, 'B1');
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-101')), findsNothing);
      expect(find.byKey(const Key('quest-card-202')), findsNothing);
      expect(find.byKey(const Key('quest-detail-panel')), findsOneWidget);
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-code-201')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('quest-card-201')),
          matching: find.text('50%+'),
        ),
        findsOneWidget,
      );

      await _tapQuestKey(tester, 'quest-search-button');
      await _tapQuestKey(tester, 'quest-query-reset');
      expect(filters.query, 'B1');
      expect(find.text('显示 3 个任务'), findsOneWidget);
      await _tapQuestKey(tester, 'quest-query-cancel');
      expect(filters.query, 'B1');
      expect(find.byKey(const Key('quest-card-101')), findsNothing);

      await _tapQuestKey(tester, 'quest-search-button');
      await _tapQuestKey(tester, 'quest-query-reset');
      await _tapQuestKey(tester, 'quest-filter-category-1');
      expect(filters.value, const QuestQuery(query: 'B1'));
      expect(find.text('显示 1 个任务'), findsOneWidget);
      await _tapQuestKey(tester, 'quest-query-apply');
      expect(filters.value, const QuestQuery(category: 1));
      expect(find.byKey(const Key('quest-card-101')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-201')), findsNothing);

      await _tapQuestKey(tester, 'quest-search-button');
      await _tapQuestKey(tester, 'quest-query-reset');
      await _tapQuestKey(tester, 'quest-query-apply');
      expect(filters.value, const QuestQuery());
      for (final id in const [101, 201, 202]) {
        expect(find.byKey(Key('quest-card-$id')), findsOneWidget);
      }

      // The related quests remain available even outside the applied query.
      await _applyQuestSearch(tester, 'B1');
      await _openQuestDetail(tester, 201);
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.text('当前说明'), findsOneWidget);
      void expectDetailStyle(Finder finder) {
        final text = tester.widget<Text>(finder);
        final style = DefaultTextStyle.of(
          tester.element(finder),
        ).style.merge(text.style);
        expect(style.fontFamily, 'HarmonyOS_Sans_SC');
        expect(style.color, const Color(0xffe6edf2));
      }

      expectDetailStyle(find.text('当前说明'));
      await _openDetailTab(tester, 'rewards');
      _expectQuestMaterials(tester, const [0, 0, 0, 0], reason: 'live rewards');
      expect(find.text('奖励内容'), findsOneWidget);
      expectDetailStyle(find.text('奖励内容'));

      await _openDetailTab(tester, 'relations');
      final pre = find.byKey(const Key('quest-relation-pre-101'));
      final post = find.byKey(const Key('quest-relation-post-202'));
      expect(
        find.descendant(of: pre, matching: find.text('A1')),
        findsOneWidget,
      );
      final preName = find.descendant(of: pre, matching: find.text('前置任务'));
      expect(preName, findsOneWidget);
      expect(
        find.descendant(of: pre, matching: find.text('推算完成')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: post, matching: find.text('后置任务')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: post, matching: find.text('未解锁')),
        findsOneWidget,
      );
      final preRect = tester.getRect(pre);
      final postRect = tester.getRect(post);
      expect(postRect.top, greaterThan(preRect.bottom));

      await _tapQuestKey(tester, 'quest-relation-pre-101');
      expect(find.byKey(const Key('quest-detail-title-101')), findsOneWidget);
      expect(find.text('前置说明'), findsOneWidget);
      expect(filters.value, const QuestQuery(query: 'B1'));
      expect(_questModeTab('全任务'), findsOneWidget);
      await _tapQuestKey(tester, 'quest-relation-back');
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-relation-post-202')), findsOneWidget);

      await _tapQuestKey(tester, 'quest-relation-post-202');
      expect(find.byKey(const Key('quest-detail-title-202')), findsOneWidget);
      expect(find.byKey(const Key('quest-detail-code-202')), findsOneWidget);
      expect(find.text('后置说明'), findsOneWidget);
      expect(filters.value, const QuestQuery(query: 'B1'));
      expect(find.byKey(const Key('quest-return-target')), findsNothing);
      await _tapQuestKey(tester, 'quest-relation-back');
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-relation-post-202')), findsOneWidget);
      await _openDetailTab(tester, 'conditions');
      expect(find.text('当前说明'), findsOneWidget);
      expect(find.byKey(const Key('quest-back-to-list')), findsNothing);
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-card-101')), findsNothing);
      expect(find.byKey(const Key('quest-card-202')), findsNothing);
      expect(find.byKey(const Key('quest-detail-panel')), findsOneWidget);
      expect(filters.value, const QuestQuery(query: 'B1'));
      await _openQuestDetail(tester, 201);
      await _openDetailTab(tester, 'relations');
      expectDetailStyle(preName);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'portrait keeps a naturally short list above the selected detail',
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

      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-detail-panel')), findsOneWidget);
      expect(find.byKey(const Key('quest-detail-title-201')), findsOneWidget);
      expect(find.text('details'), findsOneWidget);
      final list = tester.getRect(find.byKey(const Key('quest-list-panel')));
      final detail = tester.getRect(
        find.byKey(const Key('quest-detail-panel')),
      );
      final contentHeight = detail.bottom - list.top;
      expect(list.height, lessThan(contentHeight * .5));
      expect(detail.top, greaterThanOrEqualTo(list.bottom));
      expect(detail.top - list.bottom, lessThanOrEqualTo(16));
      expect(detail.height, greaterThan(list.height));
      expect(
        detail.bottom,
        closeTo(tester.getRect(find.byType(QuestCenterPage)).bottom, 1),
      );
      await _openQuestDetail(tester, 201);
      expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
      expect(find.byKey(const Key('quest-detail-panel')), findsOneWidget);
      expect(find.text('details'), findsOneWidget);
      expect(find.byKey(const Key('quest-back-to-list')), findsNothing);
      expect(tester.takeException(), isNull);
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

  testWidgets('filter rebuilds reuse the catalog projection', (tester) async {
    final gameController = GameStateController();
    final filters = QuestFilterController();
    final catalog = _CountingQuestCatalog(const <QuestCatalogEntry>[
      QuestCatalogEntry(
        gameId: 201,
        code: 'B1',
        name: 'quest',
        description: 'description',
      ),
    ]);
    addTearDown(gameController.dispose);
    addTearDown(filters.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(
          controller: gameController,
          catalog: catalog,
          filterController: filters,
          mode: QuestCenterMode.all,
        ),
      ),
    );
    expect(catalog.projectCalls, 1);

    filters.setQuery('B1');
    await tester.pump();
    filters.setCategory(2);
    await tester.pump();

    expect(catalog.projectCalls, 1);
  });
}

Future<void> _tapQuestKey(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openQuestDetail(WidgetTester tester, int id) =>
    _tapQuestKey(tester, 'quest-card-$id');

Future<void> _openDetailTab(WidgetTester tester, String tab) =>
    _tapQuestKey(tester, 'quest-detail-tab-$tab');

Future<void> _applyQuestSearch(WidgetTester tester, String query) async {
  await _tapQuestKey(tester, 'quest-search-button');
  await tester.enterText(find.byKey(const Key('quest-search-field')), query);
  await tester.pumpAndSettle();
  await _tapQuestKey(tester, 'quest-query-apply');
}

Finder _questDetailText(String text) => find.descendant(
  of: find.byKey(const Key('quest-detail-panel')),
  matching: find.text(text),
);

Finder _questModeTab(String label) => find.descendant(
  of: find.byKey(const Key('quest-mode-tabs')),
  matching: find.text(label),
);

void _expectQuestMaterials(
  WidgetTester tester,
  List<int> materials, {
  required String reason,
}) {
  final panel = find.byKey(const Key('quest-detail-panel'));
  expect(panel, findsOneWidget, reason: reason);
  expect(
    find.descendant(of: panel, matching: find.byType(Image)),
    findsNWidgets(4),
    reason: reason,
  );
  for (var index = 0; index < 4; index++) {
    final asset =
        'assets/images/material/${(index + 1).toString().padLeft(2, '0')}.png';
    final icon = find.descendant(
      of: panel,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == asset,
      ),
    );
    expect(icon, findsOneWidget, reason: reason);
    final resourceRow = find
        .ancestor(of: icon, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(
        of: resourceRow,
        matching: find.text('${materials[index]}'),
      ),
      findsOneWidget,
      reason: '$reason, resource ${index + 1}',
    );
  }
}

Future<void> _acceptRewardQuestSnapshot(
  GameStateController controller, {
  required int id,
  required int state,
  required List<int> materials,
  int sequence = 1,
}) async {
  controller.accept(
    kcsapiEvent(
      '/kcsapi/api_get_member/questlist',
      <String, Object?>{
        'api_count': 1,
        'api_page_count': 1,
        'api_exec_count': state >= 2 ? 1 : 0,
        'api_list': <Object?>[
          <String, Object?>{
            'api_no': id,
            'api_category': 6,
            'api_type': 4,
            'api_state': state,
            'api_progress_flag': state == 3 ? 2 : 0,
            'api_title': '報酬のある任務',
            'api_detail': '任務を達成せよ。',
            'api_get_material': materials,
          },
        ],
      },
      sequence: sequence,
      requestParams: const <String, Object?>{
        'api_tab_id': '0',
        'api_page_no': '1',
      },
    ),
  );
  await controller.idle;
}

final class _CountingQuestCatalog extends QuestCatalog {
  _CountingQuestCatalog(super.entries);

  int projectCalls = 0;

  @override
  QuestCatalogProjection project(
    Map<int, GameQuest> liveQuests, {
    bool isComplete = true,
    Set<int> confirmedCompleted = const {},
  }) {
    projectCalls += 1;
    return super.project(
      liveQuests,
      isComplete: isComplete,
      confirmedCompleted: confirmedCompleted,
    );
  }
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
