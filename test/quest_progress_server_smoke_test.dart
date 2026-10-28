import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _questId = 912;
const _memberId = 100;
const _title = '工作艦「明石」護衛任務';
const _stepDescriptions = ['1-3 A', '1-6', '2-1 A', '2-2 A', '2-3 A'];

final _catalog = QuestCatalog(const [
  QuestCatalogEntry(
    gameId: _questId,
    code: 'By3',
    name: _title,
    description: '',
  ),
]);

void main() {
  test(
    'By3 server snapshots refresh display without inventing map counts',
    () async {
      final storage = _MemoryProgressStorage();
      final engine = _engine(storage);
      final questStore = _MemoryQuestStore();
      final controller = _controller(engine, questStore);
      addTearDown(controller.dispose);
      await controller.initialize();

      final notifications = <String>[];
      controller.addListener(() {
        final quest = controller.state.quests[_questId]!;
        notifications.add(
          '${quest.state}:${quest.progressFlag}:'
          '${quest.displayProgressLabel}:${quest.exactProgressLabel}',
        );
      });

      final now = DateTime.now().toUtc();
      const snapshots = [
        (flag: 0, state: 2, label: '0/5'),
        (flag: 1, state: 2, label: '50%+'),
        (flag: 2, state: 2, label: '80%+'),
        (flag: 0, state: 2, label: '0/5'),
        (flag: 2, state: 3, label: '100%'),
      ];

      for (var index = 0; index < snapshots.length; index++) {
        final snapshot = snapshots[index];
        await _serverQuest(
          controller,
          flag: snapshot.flag,
          state: snapshot.state,
          sequence: index + 1,
          capturedAt: now.add(Duration(milliseconds: index)),
        );

        final completed = snapshot.state == 3;
        final quest = controller.state.quests[_questId]!;
        expect(quest.progressFlag, snapshot.flag);
        expect(quest.displayProgressLabel, snapshot.label);
        expect(quest.exactProgressLabel, completed ? '5/5' : '0/5');
        expect(quest.progressCurrent, completed ? 5 : 0);
        expect(quest.progressRequired, 5);
        expect(quest.isServerCompleted, completed);
        expect(quest.isCompleted, completed);
        // By3 is a fuzzy rule: counts alone must never prove completion.
        expect(quest.isLocallyCompleted, isFalse);
        _expectSteps(engine, count: completed ? 1 : 0);

        final item = _catalog
            .project(controller.state.quests)
            .byGameId(_questId);
        expect(item.entry.code, 'By3');
        expect(item.progressLabel, snapshot.label);
        expect(
          item.status,
          completed ? QuestStatus.claimable : QuestStatus.inProgress,
        );
        expect(item.unlockState, QuestUnlockState.unlocked);
        expect(item.matchesUnlockFilter(QuestUnlockState.completed), completed);
        expect(notifications, hasLength(index + 1));
        expect(
          notifications.last,
          '${snapshot.state}:${snapshot.flag}:${snapshot.label}:'
          '${completed ? '5/5' : '0/5'}',
        );
        expect(
          questStore.quests[_questId]?.displayProgressLabel,
          snapshot.label,
        );
        expect(engine.persistenceError, isNull);
      }

      expect(notifications, [
        '2:0:0/5:0/5',
        '2:1:50%+:0/5',
        '2:2:80%+:0/5',
        '2:0:0/5:0/5',
        '3:2:100%:5/5',
      ]);
    },
  );

  test('By3 cached server milestone survives a new controller', () async {
    final storage = _MemoryProgressStorage();
    final questStore = _MemoryQuestStore();
    final firstEngine = _engine(storage);
    final first = _controller(firstEngine, questStore);
    await first.initialize();
    try {
      await _serverQuest(
        first,
        flag: 2,
        state: 2,
        sequence: 1,
        capturedAt: DateTime.now().toUtc(),
      );
      expect(first.state.quests[_questId]?.displayProgressLabel, '80%+');
      expect(first.state.quests[_questId]?.exactProgressLabel, '0/5');
      _expectSteps(firstEngine, count: 0);
      expect(storage.values[_memberId], isNotNull);
    } finally {
      first.dispose();
    }

    // Restore from the progress ledger itself, without a second quest cache.
    final restoredEngine = _engine(storage);
    final restored = _controller(restoredEngine, _MemoryQuestStore());
    addTearDown(restored.dispose);
    await restored.initialize();

    final quest = restored.state.quests[_questId]!;
    expect(quest.state, 2);
    expect(quest.progressFlag, 2);
    expect(quest.displayProgressLabel, '80%+');
    expect(quest.exactProgressLabel, '0/5');
    expect(quest.isCompleted, isFalse);
    _expectSteps(restoredEngine, count: 0);
    expect(
      _catalog.project(restored.state.quests).byGameId(_questId).progressLabel,
      '80%+',
    );
    expect(restoredEngine.persistenceError, isNull);

    // A fresh authoritative snapshot can replace the cached milestone.
    final refreshedLabels = <String>[];
    restored.addListener(() {
      refreshedLabels.add(
        restored.state.quests[_questId]!.displayProgressLabel,
      );
    });
    await _serverQuest(
      restored,
      flag: 0,
      state: 2,
      sequence: 2,
      capturedAt: DateTime.now().toUtc(),
    );
    expect(refreshedLabels, ['0/5']);
    expect(restored.state.quests[_questId]?.exactProgressLabel, '0/5');
    _expectSteps(restoredEngine, count: 0);
  });

  for (final mode in QuestCenterMode.values) {
    testWidgets(
      'mounted By3 page refreshes real server progress and map counts: $mode',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1180, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final engine = _engine(_MemoryProgressStorage());
        final controller = _controller(engine, _MemoryQuestStore());
        addTearDown(controller.dispose);
        await controller.initialize();
        final now = DateTime.now().toUtc();
        await _serverQuest(
          controller,
          flag: 0,
          state: 2,
          sequence: 1,
          capturedAt: now,
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: QuestCenterPage(
              controller: controller,
              catalog: _catalog,
              mode: mode,
              initialQuestId: _questId,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const Key('quest-card-progress-912'));
        final detail = find.byKey(const Key('quest-detail-panel'));
        Finder detailText(String text) =>
            find.descendant(of: detail, matching: find.text(text));
        expect(
          find.descendant(of: card, matching: find.text('0/5')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('quest-detail-exact-progress-912')),
          findsOneWidget,
        );

        // Keep the page mounted so the controller notification must refresh it.
        await _serverQuest(
          controller,
          flag: 2,
          state: 2,
          sequence: 2,
          capturedAt: now.add(const Duration(seconds: 1)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(of: card, matching: find.text('80%+')),
          findsOneWidget,
        );
        expect(detailText('80%+'), findsOneWidget);
        expect(detailText('服务器进度：80%+'), findsOneWidget);
        expect(
          find.byKey(const Key('quest-detail-exact-progress-912')),
          findsNothing,
        );
        for (final description in _stepDescriptions) {
          expect(detailText(description), findsOneWidget);
        }
        expect(detailText('0/1'), findsNWidgets(5));
        expect(controller.state.quests[_questId]?.exactProgressLabel, '0/5');
        _expectSteps(engine, count: 0);

        await _serverQuest(
          controller,
          flag: 2,
          state: 3,
          sequence: 3,
          capturedAt: now.add(const Duration(seconds: 2)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(of: card, matching: find.text('100%')),
          findsOneWidget,
        );
        expect(detailText('100%'), findsOneWidget);
        expect(detailText('服务器进度：100%'), findsOneWidget);
        expect(detailText('1/1'), findsNWidgets(5));
        expect(detailText('0/1'), findsNothing);
        expect(controller.state.quests[_questId]?.exactProgressLabel, '5/5');
        _expectSteps(engine, count: 1);
      },
    );
  }
}

QuestProgressEngine _engine(_MemoryProgressStorage storage) {
  final raw =
      jsonDecode(
            File('assets/data/quest-progress-goals.json').readAsStringSync(),
          )
          as Map;
  return QuestProgressEngine(
    goals: {
      _questId: QuestProgressGoal(
        _questId,
        Map<String, dynamic>.from(raw['$_questId'] as Map),
      ),
    },
    storage: storage,
  );
}

GameStateController _controller(
  QuestProgressEngine engine,
  _MemoryQuestStore store,
) => GameStateController(
  initialState: GameState.empty.copyWith(memberId: _memberId),
  questProgress: engine,
  questStore: store,
  // Exercise controller listeners without requiring a rendered Flutter frame.
  captureNotifications: FrameNotificationCoalescer(
    scheduleFrame: (callback) => callback(),
  ),
);

Future<void> _serverQuest(
  GameStateController controller, {
  required int flag,
  required int state,
  required int sequence,
  required DateTime capturedAt,
}) async {
  controller.accept(
    kcsapiEvent(
      '/kcsapi/api_get_member/questlist',
      {
        'api_count': 1,
        'api_page_count': 1,
        'api_disp_page': 1,
        'api_exec_count': 1,
        'api_list': [
          {
            'api_no': _questId,
            'api_title': _title,
            'api_detail': '',
            'api_category': 2,
            'api_type': 5,
            'api_state': state,
            'api_progress_flag': flag,
          },
        ],
      },
      capturedAt: capturedAt,
      sequence: sequence,
    ),
  );
  await controller.idle;
  expect(controller.lastError, isNull);
  expect(controller.state.memberId, _memberId);
}

void _expectSteps(QuestProgressEngine engine, {required int count}) {
  final steps = engine.stepsFor(_questId);
  expect(steps.map((step) => step.description), _stepDescriptions);
  expect(steps.map((step) => step.required), [1, 1, 1, 1, 1]);
  expect(steps.map((step) => step.count), List.filled(5, count));
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

class _MemoryQuestStore implements QuestStore {
  Map<int, GameQuest> quests = {};

  @override
  Future<Map<int, GameQuest>> loadQuests() async => Map.of(quests);

  @override
  Future<void> saveQuests(Map<int, GameQuest> value) async {
    quests = Map.of(value);
  }

  @override
  Future<void> clearQuests() async {
    quests.clear();
  }
}
