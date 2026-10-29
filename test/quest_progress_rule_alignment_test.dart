import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';

import 'quest_progress_engine_test.dart' as existing;

void main() {
  test('242 discards its weekly counter at Monday 05:00 JST', () async {
    final before = DateTime.utc(2026, 9, 13, 19, 59);
    final h = await _session(242, 2, before);
    await h.battle(44);
    expect(h.engine.stepsFor(242).single.count, 1);

    h.state = h.engine.expire(h.state, DateTime.utc(2026, 9, 13, 20));

    expect(h.state.quests.containsKey(242), isFalse);
    // The API weekly type already removes the active row; the rule must also
    // discard its ledger so reaccepting next week cannot inherit last week.
    expect(h.engine.stepsFor(242), isEmpty);
  });

  test('977 counts the 7-2 second boss at cell 15', () async {
    final h = await _session(977, 4, DateTime.utc(2026, 9, 11, 10));

    await h.battle(72, cell: 15);

    expect(h.state.quests[977]!.progressCurrent, 1);
    expect(_secondBossCount(h), 1);
  });

  test('977 does not count cell 13 as the 7-2 second boss', () async {
    final h = await _session(977, 4, DateTime.utc(2026, 9, 11, 10));

    await h.battle(72, cell: 13);

    expect(h.state.quests[977]!.progressCurrent, 0);
    expect(_secondBossCount(h), 0);
  });

  test('1138 counts disposal of master 120 with equipment type 36', () async {
    final h = await _disposalSession(masterId: 120, equipmentType: 36);

    await _dispose(h);

    expect(h.engine.stepsFor(1138).single.count, 1);
  });

  test('1138 does not count disposal of a type 17 boiler', () async {
    final h = await _disposalSession(masterId: 34, equipmentType: 17);

    await _dispose(h);

    expect(h.engine.stepsFor(1138).single.count, 0);
  });

  test('1138 does not count other equipment in type 36', () async {
    final h = await _disposalSession(masterId: 121, equipmentType: 36);

    await _dispose(h);

    expect(h.engine.stepsFor(1138).single.count, 0);
  });

  test(
    '1167 stays active daily while its unfinished daily count resets',
    () async {
      final before = DateTime.utc(2026, 9, 9, 19, 59);
      final h = await _session(1167, 2, before);
      await h.event('api_req_kousyou/remodel_slot', {'api_remodel_flag': 1});
      expect(h.engine.stepsFor(1167).single.count, 1);

      h.state = h.engine.expire(h.state, DateTime.utc(2026, 9, 9, 20));

      expect(h.state.quests.containsKey(1167), isTrue);
      expect(h.state.quests[1167]!.isAccepted, isTrue);
      expect(h.state.quests[1167]!.progressCurrent, 0);
      expect(h.engine.stepsFor(1167).single.count, 0);
    },
  );

  test(
    '1167 expires its active row and ledger at the weekly boundary',
    () async {
      final before = DateTime.utc(2026, 9, 13, 19, 59);
      final h = await _session(1167, 2, before);
      await h.event('api_req_kousyou/remodel_slot', {'api_remodel_flag': 1});
      expect(h.engine.stepsFor(1167).single.count, 1);

      h.state = h.engine.expire(h.state, DateTime.utc(2026, 9, 13, 20));

      expect(h.state.quests.containsKey(1167), isFalse);
      expect(h.engine.stepsFor(1167), isEmpty);
    },
  );

  test('1167 resets yesterday\'s quest-only cached count on restore', () async {
    final h = await _legacyRemodelSession();

    expect(h.state.quests[1167]!.isAccepted, isTrue);
    expect(h.state.quests[1167]!.progressCurrent, 0);
    expect(h.engine.stepsFor(1167).single.count, 0);
  });

  test(
    '1167 cannot complete with yesterday\'s cached count and two new remodels',
    () async {
      final h = await _legacyRemodelSession();

      await h.event('api_req_kousyou/remodel_slot', {'api_remodel_flag': 1});
      await h.event('api_req_kousyou/remodel_slot', {'api_remodel_flag': 1});

      expect(
        [
          h.state.quests[1167]!.progressCurrent,
          h.engine.stepsFor(1167).single.count,
          h.state.quests[1167]!.isLocallyCompleted,
        ],
        [2, 2, false],
      );
    },
  );
}

Future<existing.Harness> _legacyRemodelSession() {
  final before = DateTime.utc(2026, 9, 9, 19, 59);
  final after = DateTime.utc(2026, 9, 9, 20);
  return _session(
    1167,
    2,
    after,
    initial: existing
        .sample(before, id: 1167, type: 2)
        .copyWith(
          quests: {
            1167: GameQuest(
              id: 1167,
              title: 'task',
              detail: '',
              category: 2,
              type: 2,
              state: 2,
              progressFlag: 0,
              progressCurrent: 1,
              progressRequired: 3,
              updatedAt: before,
            ),
          },
        ),
  );
}

Future<existing.Harness> _session(
  int id,
  int apiType,
  DateTime time, {
  GameState? initial,
}) async {
  final engine = QuestProgressEngine(
    goals: existing.rules(),
    storage: existing.MemoryProgress(),
  );
  final state = initial ?? existing.sample(time, id: id, type: apiType);
  return existing.Harness(engine, await engine.restore(state, time), time);
}

int _secondBossCount(existing.Harness h) => h.engine
    .stepsFor(977)
    .singleWhere((step) => step.description == '7-2P2 S')
    .count;

Future<existing.Harness> _disposalSession({
  required int masterId,
  required int equipmentType,
}) {
  final time = DateTime.utc(2026, 9, 11, 10);
  return _session(
    1138,
    5,
    time,
    initial: existing
        .sample(time, id: 1138, type: 5)
        .copyWith(
          slotItems: {100: OwnedSlotItem(id: 100, masterId: masterId)},
          masterSlotItems: {
            masterId: MasterSlotItem(
              id: masterId,
              name: 'equipment $masterId',
              type: [0, 0, equipmentType],
            ),
          },
        ),
  );
}

Future<void> _dispose(existing.Harness h) => h.event(
  'api_req_kousyou/destroyitem2',
  {},
  params: {'api_slotitem_ids': '100'},
  reduce: true,
);
