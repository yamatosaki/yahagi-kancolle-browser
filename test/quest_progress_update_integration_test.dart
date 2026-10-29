import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_update_service.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  test(
    'downloaded rules take effect and survive a complete cold restart',
    () async {
      QuestProgressDataset dataset(int day, int required) =>
          QuestProgressDataset.parsePayload(
            jsonEncode({
              'meta': {'name': 'questgoal', 'version': '2026/10/$day/01'},
              'data': {'403': _goals(required)[403]!.raw},
            }),
          );
      final bundled = dataset(25, 10);
      final remote = dataset(26, 12);
      final counterStorage = _Storage();
      final datasetStore = QuestProgressDatasetStore(_DatasetStorage());
      final game = _controller(
        QuestProgressEngine(goals: bundled.goals, storage: counterStorage),
      );
      addTearDown(game.dispose);
      await game.initialize();
      final client = MockClient(
        (request) async => http.Response(
          request.url.host == 'api.github.com'
              ? jsonEncode([
                  {'sha': 'a' * 40},
                ])
              : remote.rawJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      addTearDown(client.close);
      final rules = QuestProgressRulesController(
        dataset: bundled,
        updater: QuestProgressUpdateService(
          client: client,
          store: datasetStore,
        ),
        onUpdated: (value) => game.updateQuestProgressGoals(value.goals),
      );
      addTearDown(rules.dispose);

      expect(await rules.checkForUpdates(), isA<QuestProgressUpdated>());
      expect(rules.version, remote.version);
      expect(game.state.quests[403]!.displayProgressLabel, '2/12');
      _mission(game, 1);
      await game.idle;
      expect(game.state.quests[403]!.displayProgressLabel, '3/12');

      final restored = await datasetStore.loadBestAvailable(bundled);
      final restarted = GameStateController(
        initialState: game.state,
        questProgress: QuestProgressEngine(
          goals: restored.goals,
          storage: counterStorage,
        ),
      );
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restored.version, remote.version);
      expect(restarted.state.quests[403]!.displayProgressLabel, '3/12');
      _mission(restarted, 2);
      await restarted.idle;
      expect(restarted.state.quests[403]!.displayProgressLabel, '4/12');
      expect(restarted.state.quests[403]!.isServerCompleted, isFalse);
    },
  );

  test('rule adoption is serialized between real API count events', () async {
    final engine = QuestProgressEngine(goals: _goals(10), storage: _Storage());
    final controller = _controller(engine);
    addTearDown(controller.dispose);
    await controller.initialize();
    _mission(controller, 1);
    final Future<void> update = controller.updateQuestProgressGoals(_goals(12));
    _mission(controller, 2);
    await update;
    await controller.idle;

    expect(controller.state.quests[403]!.displayProgressLabel, '4/12');
    expect(controller.state.quests[403]!.isServerCompleted, isFalse);
    expect(engine.goals[403]!.steps.values.single['required'], 12);
    expect(controller.lastError, isNull);
  });

  test(
    'a mounted listener sees new tracking without another API event',
    () async {
      final engine = QuestProgressEngine(goals: {}, storage: _Storage());
      final controller = _controller(engine, tracked: false);
      addTearDown(controller.dispose);
      await controller.initialize();
      final labels = <String>[];
      controller.addListener(() {
        labels.add(controller.state.quests[403]!.displayProgressLabel);
      });

      await controller.updateQuestProgressGoals(_goals(10));

      expect(controller.state.quests[403]!.displayProgressLabel, '0/10');
      expect(labels.last, '0/10');
    },
  );

  test('failed rule adoption leaves the API queue usable', () async {
    final engine = _FailingEngine();
    final controller = _controller(engine);
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.updateQuestProgressGoals(_goals(12)),
      throwsStateError,
    );
    expect(controller.state.quests[403]!.displayProgressLabel, '2/10');
    _mission(controller, 1);
    await controller.idle;
    expect(controller.state.quests[403]!.displayProgressLabel, '3/10');
    expect(controller.lastError, isNull);
  });

  test('an in-flight adoption cannot publish the previous account', () async {
    final account = AccountSession(initialMemberId: 100);
    addTearDown(account.dispose);
    final engine = _DelayedEngine();
    final controller = _controller(engine, account: account);
    addTearDown(controller.dispose);
    await controller.initialize();
    final Future<void> update = controller.updateQuestProgressGoals(_goals(12));
    await engine.started.future;
    account.selectMember(200);
    engine.release.complete();
    await update;

    expect(account.current.memberId, 200);
    expect(controller.state.memberId, isNot(100));
    expect(controller.state.quests, isEmpty);
  });

  test('disposing while adopting rules does not notify a dead view', () async {
    final engine = _DelayedEngine();
    final controller = _controller(engine);
    await controller.initialize();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final Future<void> update = controller.updateQuestProgressGoals(_goals(12));
    await engine.started.future;
    controller.dispose();
    engine.release.complete();
    await update;
    expect(notifications, 0);
  });
}

Map<int, QuestProgressGoal> _goals(int total) => {
  403: QuestProgressGoal(403, {
    'type': 0,
    'mission_success': {'description': '遠征', 'required': total, 'init': 0},
  }),
};

GameStateController _controller(
  QuestProgressEngine engine, {
  bool tracked = true,
  AccountSession? account,
}) => GameStateController(
  questProgress: engine,
  accountSession: account,
  initialState: GameState(
    memberId: 100,
    hasQuestData: true,
    quests: {
      403: GameQuest(
        id: 403,
        title: '遠征',
        detail: '',
        category: 4,
        type: 4,
        state: 2,
        progressFlag: 0,
        progressCurrent: tracked ? 2 : null,
        progressRequired: tracked ? 10 : null,
        updatedAt: DateTime.now().toUtc(),
      ),
    },
  ),
);

void _mission(GameStateController controller, int sequence) =>
    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_mission/result',
        {'api_clear_result': 1},
        sequence: sequence,
        capturedAt: DateTime.now().toUtc().add(
          Duration(milliseconds: sequence),
        ),
      ),
    );

class _Storage implements QuestProgressStorage {
  final values = <int, String>{};
  @override
  Future<String?> read(int account) async => values[account];
  @override
  Future<void> write(int account, String value) async =>
      values[account] = value;
}

class _DatasetStorage implements QuestProgressDatasetStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String raw) async => value = raw;
}

class _FailingEngine extends QuestProgressEngine {
  _FailingEngine() : super(goals: _goals(10), storage: _Storage());
  @override
  Future<GameState> replaceGoals(
    GameState state,
    Map<int, QuestProgressGoal> nextGoals,
    DateTime now,
  ) async => throw StateError('rule adoption unavailable');
}

class _DelayedEngine extends QuestProgressEngine {
  _DelayedEngine() : super(goals: _goals(10), storage: _Storage());
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<GameState> replaceGoals(
    GameState state,
    Map<int, QuestProgressGoal> nextGoals,
    DateTime now,
  ) async {
    started.complete();
    await release.future;
    return super.replaceGoals(state, nextGoals, now);
  }
}
