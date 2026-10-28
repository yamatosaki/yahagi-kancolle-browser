import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameStateController.disableTimerForTest = true;
  });
  tearDown(() => GameStateController.disableTimerForTest = false);

  testWidgets(
    'local completion survives a same-frame successful claim with default notifications',
    (tester) async {
      final game = _game(_repairQuest(), goals: _repairRules());
      final notices = await _mount(tester, game);
      expect(find.text('completed:0'), findsOneWidget);
      expect(notices.notices, isEmpty);

      await _repair(game);
      expect(game.state.quests[503]?.exactProgressLabel, '5/5');
      expect(game.state.quests[503]?.isCompleted, isTrue);
      // No rendered frame may separate completion from the successful claim.
      await _claim(game, 503);
      expect(game.state.quests, isEmpty);
      await _paintNotices(tester);

      _expectNotice(notices, '任务达成：修理五次');
      expect(find.text('任务达成：修理五次'), findsOneWidget);
      expect(find.text('completed:0'), findsOneWidget);
      notices.hide();
    },
  );

  testWidgets(
    'full unverified progress survives another API update before the frame',
    (tester) async {
      final game = _game(_destructionQuest(), goals: _destructionRules());
      final notices = await _mount(tester, game);
      expect(game.state.quests[609]?.exactProgressLabel, '1/2');
      expect(notices.notices, isEmpty);

      await _destroyShip(game);
      expect(game.state.quests[609]?.exactProgressLabel, '2/2');
      expect(game.state.quests[609]?.isCompleted, isFalse);
      game.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/basic',
          {'api_member_id': 100, 'api_level': 99},
          sequence: 2,
          capturedAt: DateTime.now().toUtc(),
        ),
      );
      await game.idle;
      expect(game.lastError, isNull);
      expect(game.state.quests[609]?.exactProgressLabel, '2/2');
      await _paintNotices(tester);

      _expectNotice(notices, '任务目标已达成（待游戏确认）：解体两次');
      expect(find.text('任务目标已达成（待游戏确认）：解体两次'), findsOneWidget);
      expect(find.text('completed:0'), findsOneWidget);
      notices.hide();
    },
  );

  testWidgets(
    'server completion survives a claim before the post-frame notice',
    (tester) async {
      final game = _game(
        _repairQuest(),
        goals: _repairRules(),
        synchronousNotifications: true,
      );
      final notices = await _mount(tester, game);
      game.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          {
            'api_count': 1,
            'api_exec_count': 1,
            'api_page_count': 1,
            'api_disp_page': 1,
            'api_list': [
              {
                'api_no': 503,
                'api_title': '修理五次',
                'api_detail': '',
                'api_category': 5,
                'api_type': 1,
                'api_state': 3,
                'api_progress_flag': 2,
              },
            ],
          },
          sequence: 1,
          capturedAt: DateTime.now().toUtc(),
        ),
      );
      await game.idle;
      expect(game.lastError, isNull);
      expect(game.state.quests[503]?.isServerCompleted, isTrue);
      expect(notices.notices, isEmpty);
      await _claim(game, 503);
      expect(game.state.quests, isEmpty);
      await _paintNotices(tester);

      _expectNotice(notices, '任务达成：修理五次');
      expect(find.text('任务达成：修理五次'), findsOneWidget);
      expect(find.text('completed:0'), findsOneWidget);
      await tester.pump();
      _expectNotice(notices, '任务达成：修理五次');
      notices.hide();
    },
  );

  testWidgets(
    'same-frame server confirmation replaces a pending notice for the same quest',
    (tester) async {
      final game = _game(_destructionQuest(), goals: _destructionRules());
      final notices = await _mount(tester, game);

      await _destroyShip(game);
      expect(game.state.quests[609]?.exactProgressLabel, '2/2');
      expect(game.state.quests[609]?.isCompleted, isFalse);
      await _serverQuest(game, 609, state: 3, flag: 2);
      expect(game.state.quests[609]?.isServerCompleted, isTrue);
      await _paintNotices(tester);

      _expectNotice(notices, '任务达成：解体两次');
      expect(find.text('任务达成：解体两次'), findsOneWidget);
      expect(find.textContaining('待游戏确认'), findsNothing);
      expect(find.text('completed:1'), findsOneWidget);
      notices.hide();
    },
  );

  testWidgets(
    'contradicted local completion can alert when the goal is reached again',
    (tester) async {
      final game = _game(_repairQuest(), goals: _repairRules());
      final notices = await _mount(tester, game);

      await _repair(game);
      expect(game.state.quests[503]?.exactProgressLabel, '5/5');
      expect(game.state.quests[503]?.isCompleted, isTrue);
      await _serverQuest(game, 503, state: 2, flag: 2);
      expect(game.state.quests[503]?.exactProgressLabel, '4/5');
      expect(game.state.quests[503]?.isCompleted, isFalse);
      await _paintNotices(tester);
      expect(notices.notices, isEmpty);
      expect(find.text('任务达成：修理五次'), findsNothing);
      expect(find.text('completed:0'), findsOneWidget);

      await _repair(game);
      expect(game.state.quests[503]?.exactProgressLabel, '5/5');
      expect(game.state.quests[503]?.isCompleted, isTrue);
      await _paintNotices(tester);

      _expectNotice(notices, '任务达成：修理五次');
      expect(find.text('任务达成：修理五次'), findsOneWidget);
      expect(find.text('completed:1'), findsOneWidget);
      notices.hide();
    },
  );

  testWidgets(
    'contradicted pending count can alert when the count becomes full again',
    (tester) async {
      final game = _game(_destructionQuest(), goals: _destructionRules());
      final notices = await _mount(tester, game);

      await _destroyShip(game);
      expect(game.state.quests[609]?.exactProgressLabel, '2/2');
      expect(game.state.quests[609]?.isCompleted, isFalse);
      await _serverQuest(game, 609, state: 2, flag: 1);
      expect(game.state.quests[609]?.exactProgressLabel, '1/2');
      await _paintNotices(tester);
      expect(notices.notices, isEmpty);
      expect(find.textContaining('待游戏确认'), findsNothing);

      await _destroyShip(game);
      expect(game.state.quests[609]?.exactProgressLabel, '2/2');
      expect(game.state.quests[609]?.isCompleted, isFalse);
      await _paintNotices(tester);

      _expectNotice(notices, '任务目标已达成（待游戏确认）：解体两次');
      expect(find.text('任务目标已达成（待游戏确认）：解体两次'), findsOneWidget);
      expect(find.text('completed:0'), findsOneWidget);
      notices.hide();
    },
  );

  testWidgets(
    'same-frame account change discards the previous account completion',
    (tester) async {
      final game = _game(_repairQuest(), goals: _repairRules());
      final notices = await _mount(tester, game);

      await _repair(game);
      expect(game.state.quests[503]?.isCompleted, isTrue);
      game.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/basic',
          {'api_member_id': 200, 'api_level': 1},
          sequence: 2,
          capturedAt: DateTime.now().toUtc(),
        ),
      );
      await game.idle;
      expect(game.lastError, isNull);
      expect(game.state.memberId, 200);
      expect(game.state.quests, isEmpty);
      await _paintNotices(tester);

      expect(notices.notices, isEmpty);
      expect(find.text('任务达成：修理五次'), findsNothing);
      expect(find.text('completed:0'), findsOneWidget);
      notices.hide();
    },
  );

  testWidgets('previous-period completion cannot hide a newly claimed task', (
    tester,
  ) async {
    final game = GameStateController(
      initialState: GameState(
        memberId: 100,
        quests: {
          503: GameQuest(
            id: 503,
            title: '修理五次',
            detail: '',
            category: 5,
            type: 1,
            state: 3,
            progressFlag: 2,
            progressCurrent: 5,
            progressRequired: 5,
            updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
          ),
        },
      ),
    );
    final notices = await _mount(tester, game);
    expect(find.text('completed:0'), findsOneWidget);

    await _serverQuest(game, 503, state: 3, flag: 2);
    await _claim(game, 503);
    await _paintNotices(tester);

    _expectNotice(notices, '任务达成：修理五次');
    expect(find.text('completed:0'), findsOneWidget);
    notices.hide();
  });

  for (final verified in <bool?>[true, null, false]) {
    testWidgets(
      'local full verified=$verified alerts ${verified == false ? 'pending confirmation' : 'completion'}',
      (tester) async {
        final awaiting = verified == false;
        final game = _game(
          awaiting ? _destructionQuest() : _repairQuest(verified: verified),
          // A missing extended rule preserves the reducer's legacy null flag.
          // The known repair counter still advances through the real API path.
          goals: awaiting
              ? _destructionRules()
              : verified == null
              ? {}
              : _repairRules(),
        );
        final notices = await _mount(tester, game);
        final id = awaiting ? 609 : 503;
        expect(game.state.quests[id]?.isCompleted, isFalse);
        expect(notices.notices, isEmpty);

        if (awaiting) {
          await _destroyShip(game);
        } else {
          await _repair(game);
        }
        final quest = game.state.quests[id]!;
        expect(quest.exactProgressLabel, awaiting ? '2/2' : '5/5');
        expect(quest.localCompletionVerified, verified);
        expect(quest.isCompleted, !awaiting);
        await _paintNotices(tester);

        final message = awaiting ? '任务目标已达成（待游戏确认）：解体两次' : '任务达成：修理五次';
        _expectNotice(notices, message);
        expect(find.text(message), findsOneWidget);
        expect(find.text('completed:${awaiting ? 0 : 1}'), findsOneWidget);
        notices.hide();
      },
    );
  }
}

GameQuest _repairQuest({bool? verified = true}) => GameQuest(
  id: 503,
  title: '修理五次',
  detail: '',
  category: 5,
  type: 1,
  state: 2,
  progressFlag: 2,
  progressCurrent: 4,
  progressRequired: 5,
  localCompletionVerified: verified,
  updatedAt: DateTime.now().toUtc(),
);

GameQuest _destructionQuest() => GameQuest(
  id: 609,
  title: '解体两次',
  detail: '',
  category: 6,
  type: 1,
  state: 2,
  progressFlag: 1,
  progressCurrent: 1,
  progressRequired: 2,
  localCompletionVerified: false,
  updatedAt: DateTime.now().toUtc(),
);

Map<int, QuestProgressGoal> _repairRules() => {
  503: QuestProgressGoal(503, {
    'type': 1,
    'repair': {'required': 5, 'init': 0},
  }),
};

Map<int, QuestProgressGoal> _destructionRules() => {
  609: QuestProgressGoal(609, {
    'type': 1,
    'destroy_ship': {'required': 2, 'init': 0},
  }),
};

GameStateController _game(
  GameQuest quest, {
  required Map<int, QuestProgressGoal> goals,
  bool synchronousNotifications = false,
}) => GameStateController(
  initialState: GameState.empty.copyWith(
    memberId: 100,
    quests: {quest.id: quest},
  ),
  questProgress: QuestProgressEngine(
    goals: goals,
    storage: _MemoryProgressStorage(),
  ),
  captureNotifications: synchronousNotifications
      ? FrameNotificationCoalescer(scheduleFrame: (callback) => callback())
      : null,
);

Future<TopNoticeController> _mount(
  WidgetTester tester,
  GameStateController game,
) async {
  final layout = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  final notices = TopNoticeController();
  addTearDown(game.dispose);
  addTearDown(layout.dispose);
  addTearDown(notices.dispose);
  await game.initialize();
  expect(layout.topNoticeEnabled, isTrue);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QuestCompletionDrawerHost(
          controller: notices,
          child: Column(
            children: [
              const SizedBox(
                height: 44,
                child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
              ),
              Expanded(
                child: QuestCompletionFeedback(
                  controller: game,
                  layoutSettingsController: layout,
                  builder: (_, count) => Text('completed:$count'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return notices;
}

Future<void> _repair(GameStateController game) async {
  game.accept(
    kcsapiEvent(
      '/kcsapi/api_req_nyukyo/start',
      const {},
      includeApiData: false,
      requestParams: const {
        'api_ndock_id': '1',
        'api_ship_id': '999',
        'api_highspeed': '0',
      },
      sequence: 1,
      capturedAt: DateTime.now().toUtc(),
    ),
  );
  await game.idle;
  expect(game.lastError, isNull);
}

Future<void> _destroyShip(GameStateController game) async {
  game.accept(
    kcsapiEvent(
      '/kcsapi/api_req_kousyou/destroyship',
      const {},
      requestParams: const {'api_ship_id': '1'},
      sequence: 1,
      capturedAt: DateTime.now().toUtc(),
    ),
  );
  await game.idle;
  expect(game.lastError, isNull);
}

Future<void> _claim(GameStateController game, int id) async {
  game.accept(
    kcsapiEvent(
      '/kcsapi/api_req_quest/clearitemget',
      const {},
      requestParams: {'api_quest_id': id},
      sequence: 2,
      capturedAt: DateTime.now().toUtc(),
    ),
  );
  await game.idle;
  expect(game.lastError, isNull);
}

Future<void> _serverQuest(
  GameStateController game,
  int id, {
  required int state,
  required int flag,
}) async {
  final quest = game.state.quests[id]!;
  game.accept(
    kcsapiEvent(
      '/kcsapi/api_get_member/questlist',
      {
        'api_count': 1,
        'api_exec_count': 1,
        'api_page_count': 1,
        'api_disp_page': 1,
        'api_list': [
          {
            'api_no': id,
            'api_title': quest.title,
            'api_detail': quest.detail,
            'api_category': quest.category,
            'api_type': quest.type,
            'api_state': state,
            'api_progress_flag': flag,
          },
        ],
      },
      sequence: 3,
      capturedAt: DateTime.now().toUtc(),
    ),
  );
  await game.idle;
  expect(game.lastError, isNull);
}

Future<void> _paintNotices(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(tester.takeException(), isNull);
}

void _expectNotice(TopNoticeController notices, String message) {
  final quests = notices.notices.where(
    (notice) => notice.tone == TopNoticeTone.quest,
  );
  expect(quests, hasLength(1));
  expect(quests.single.message, message);
}

class _MemoryProgressStorage implements QuestProgressStorage {
  final values = <int, String>{};

  @override
  Future<String?> read(int account) async => values[account];

  @override
  Future<void> write(int account, String value) async {
    values[account] = value;
  }
}
