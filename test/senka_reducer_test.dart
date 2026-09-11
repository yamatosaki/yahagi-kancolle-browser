import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_reducer.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';

void main() {
  const reducer = SenkaReducer();

  test('经验差按 7/10000 计入捕获日战果', () {
    var state = SenkaState.forMonth('2026-08');
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        },
      }, atJst: DateTime(2026, 8, 10, 3)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_req_sortie/battleresult', {
        'api_member_exp': 105500,
      }, atJst: DateTime(2026, 8, 10, 12)),
    );

    expect(state.day(DateTime(2026, 8, 10)).experience, 3.85);
    expect(state.monthRecorded, 3.85);
  });

  test('较小或相等经验快照不降低基准且只计算真实正增量', () {
    var state = SenkaState.forMonth('2026-08');
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_get_member/basic', {
        'api_experience': 15000000,
      }, atJst: DateTime(2026, 8, 19, 10)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_req_mission/result', {
        'api_member_exp': 200,
      }, atJst: DateTime(2026, 8, 19, 11)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_port/port', {
        'api_basic': {'api_experience': 15000000},
      }, atJst: DateTime(2026, 8, 19, 12)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_req_sortie/battleresult', {
        'api_member_exp': 15001000,
      }, atJst: DateTime(2026, 8, 19, 13)),
    );

    expect(state.latestExperience, 15001000);
    expect(state.day(DateTime(2026, 8, 19)).experience, closeTo(.7, 1e-9));
  });

  test('首次地图信息同步历史 EO 但不伪造今日记录', () {
    var state = SenkaState.forMonth('2026-08');
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
          {'api_id': 56, 'api_cleared': 1},
          {'api_id': 75, 'api_cleared': 0},
        ],
      }, atJst: DateTime(2026, 8, 10, 9)),
    );

    expect(state.completedEoIds, {15, 56});
    expect(state.completedSenka, 300);
    expect(state.day(DateTime(2026, 8, 10)).eo, 0);
    expect(state.monthRecorded, 300);
    expect(senkaEoCatalog.map((item) => item.id), containsAll([15, 56, 75]));

    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
          {'api_id': 56, 'api_cleared': 1},
          {'api_id': 75, 'api_cleared': 1},
        ],
      }, atJst: DateTime(2026, 8, 11, 9)),
    );

    expect(state.day(DateTime(2026, 8, 11)).eo, 170);
    expect(state.monthRecorded, 470);
  });

  test('战果任务成功领取后自动完成并只入账一次', () {
    var state = SenkaState.forMonth('2026-08');
    final event = apiEvent(
      '/kcsapi/api_req_quest/clearitemget',
      const {},
      params: const {'api_quest_id': '284'},
      atJst: DateTime(2026, 8, 11, 8),
    );
    state = reducer.reduce(state, event);
    state = reducer.reduce(state, event);

    expect(state.completedQuestIds, contains(284));
    expect(state.day(DateTime(2026, 8, 11)).quest, 80);
    expect(state.unsettledSenka, 80);
  });

  test('排名解密优先保留可整除公约数的账号系数', () {
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(memberId: 120, nickname: '本人'),
      rankingEvent(
        page: 1,
        rows: [
          rankingRow(rank: 1, senka: 1, nickname: '甲', magic: 36),
          rankingRow(rank: 2, senka: 3, nickname: '乙', magic: 36),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    expect(state.magic, 36);
  });

  test('复合解密系数不能回退到无法整除当前排名的旧账号系数', () {
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(memberId: 120, nickname: '本人'),
      rankingEvent(
        page: 40,
        rows: [
          rankingRow(rank: 391, senka: 451, nickname: '其他', magic: 78),
          rankingRow(rank: 392, senka: 450, nickname: '本人', magic: 78),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    // The legacy account factor 36 would turn 450 into 1081.1666... .
    expect(state.playerRankingRow.senka, 450);
    expect(state.calculatorCurrentSenka, 450);
    expect(state.magic, 78);
  });

  test('顶部排名 747 保持正确时仍可因旧系数把 488 战果放大为 1453', () {
    // Synthetic payload matching the report's scale, not a captured user API.
    // Rank 747 uses right factor 3779; legacy factor 36 misdecodes this as 1453.
    const encrypted = (488 + 91) * 96 * 3779;
    expect(encrypted / 3779 / 36 - 91, 1453);
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(memberId: 120, nickname: '本人'),
      rankingEvent(
        page: 75,
        rows: [
          rankingRow(rank: 746, senka: 489, nickname: '其他', magic: 96),
          rankingEncryptedRow(
            rank: 747,
            encrypted: encrypted,
            nickname: '本人',
          ),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    expect(state.playerRankingRow.rank, 747);
    expect(state.playerRankingRow.senka, 488);
    expect(state.calculatorCurrentSenka, 488);
    expect(state.magic, 96);
  });

  test('旧系数失效时不能用错误历史战果选择新系数', () {
    final oldSenka = (450 + 91) * 78 / 36 - 91;
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(
        memberId: 120,
        nickname: '本人',
        magic: 36,
        calculatorCurrentSenka: oldSenka,
        rankingHistory: {
          'player': [
            SenkaRankingSnapshot(
              rank: 392,
              senka: oldSenka,
              capturedAt: DateTime.utc(2026, 8, 10, 5),
              localSenkaAtCapture: 0,
            ),
          ],
        },
      ),
      rankingEvent(
        page: 40,
        rows: [
          rankingRow(rank: 391, senka: 452, nickname: '其他', magic: 78),
          rankingRow(rank: 392, senka: 451, nickname: '本人', magic: 78),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    expect(state.playerRankingRow.senka, 451);
    expect(state.calculatorCurrentSenka, 451);
    expect(state.magic, 78);
  });

  test('旧排名事件不会覆盖更新的排名快照', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧');
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 40,
        rows: [rankingRow(rank: 390, senka: 1200, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 41,
        rows: [rankingRow(rank: 400, senka: 1100, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 10, 14),
      ),
    );

    expect(state.playerRankingRow.rank, 390);
    expect(state.playerRankingRow.senka, 1200);
    expect(state.latestRankingUpdatedAt, DateTime.utc(2026, 8, 10, 6));
  });

  test('排名页出现重名时不把他人误识别为当前玩家', () {
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(memberId: 123, nickname: '同名提督'),
      rankingEvent(
        page: 40,
        rows: [
          rankingRow(rank: 391, senka: 1200, nickname: '同名提督'),
          rankingRow(rank: 392, senka: 1190, nickname: '同名提督'),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    expect(state.rankingHistory['player'], isNull);
    expect(state.calculatorCurrentSenka, 0);
  });

  test('排名响应解密锚点和当前玩家并保留两次快照的变化', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧');
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [rankingRow(rank: 5, senka: 4755, nickname: '五位')],
        atJst: DateTime(2026, 8, 10, 3, 5),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [rankingRow(rank: 5, senka: 4828, nickname: '五位')],
        atJst: DateTime(2026, 8, 10, 15, 5),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 388,
        rows: [rankingRow(rank: 3874, senka: 108, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 10, 15, 6),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 384,
        rows: [rankingRow(rank: 3832, senka: 112, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 11, 3, 6),
      ),
    );

    final rank5 = state.rankingRow(5);
    final player = state.playerRankingRow;
    expect(rank5.senka, 4828);
    expect(rank5.senkaDelta, 73);
    expect(player.rank, 3832);
    expect(player.rankDelta, 42);
    expect(player.rankDirection, SenkaRankDirection.up);
    expect(player.senka, 112);
    expect(state.calculatorCurrentSenka, 112);
  });

  test('新的真实玩家排名覆盖手动当前战果且保留解密小数', () {
    final encrypted = 1267 * 4568 * 97 + 1;
    final state = reducer.reduce(
      SenkaState.forMonth(
        '2026-08',
      ).copyWith(memberId: 123, nickname: '矢矧', calculatorCurrentSenka: 9999),
      rankingEvent(
        page: 40,
        rows: [
          rankingEncryptedRow(rank: 397, encrypted: encrypted, nickname: '矢矧'),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    final expected = encrypted / 4568 / 97 - 73 - 18;
    expect(state.calculatorCurrentSenka, expected);
    expect(state.calculatorCurrentSenka, isNot(1176));
  });

  test('排名页自动推导变化后的解密系数，不需要手动校准', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧');
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [
          rankingRow(rank: 1, senka: 1000, nickname: '一位', magic: 61),
          rankingRow(rank: 2, senka: 1001, nickname: '二位', magic: 61),
          rankingRow(rank: 5, senka: 4755, nickname: '五位', magic: 61),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    expect(state.magic, 61);
    expect(state.rankingRow(5).senka, 4755);
  });

  test('解密系数变化为旧系数倍数时用历史锚点选择新系数', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧');
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [
          rankingRow(rank: 1, senka: 1000, nickname: '一位', magic: 31),
          rankingRow(rank: 2, senka: 1001, nickname: '二位', magic: 31),
          rankingRow(rank: 5, senka: 900, nickname: '五位', magic: 31),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [
          rankingRow(rank: 1, senka: 1010, nickname: '一位', magic: 62),
          rankingRow(rank: 2, senka: 1011, nickname: '二位', magic: 62),
          rankingRow(rank: 5, senka: 910, nickname: '五位', magic: 62),
        ],
        atJst: DateTime(2026, 8, 10, 16),
      ),
    );

    expect(state.magic, 62);
    expect(state.rankingRow(5).senka, 910);
    expect(state.rankingRow(5).senkaDelta, 10);
  });

  test('当前玩家变化包含排名后自动确认的经验、EO 与任务战果', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧', latestExperience: 100000);
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 44,
        rows: [rankingRow(rank: 431, senka: 3421, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 10, 3),
      ),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_req_sortie/battleresult', {
        'api_member_exp': 105500,
      }, atJst: DateTime(2026, 8, 10, 8)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
        ],
      }, atJst: DateTime(2026, 8, 10, 9)),
    );
    state = reducer.reduce(
      state,
      apiEvent(
        '/kcsapi/api_req_quest/clearitemget',
        const {},
        params: const {'api_quest_id': '284'},
        atJst: DateTime(2026, 8, 10, 10),
      ),
    );

    expect(state.playerRankingRow.senkaDelta, closeTo(83.85, 0.0001));
  });

  test('同季度新月份保留季度、年度、单次状态并重置月度状态', () {
    final old = SenkaState.forMonth('2026-07').copyWith(
      memberId: 123,
      nickname: '矢矧',
      serverOrigin: 'https://w01y.kancolle-server.com',
      eoStatuses: const {15: SenkaRewardStatus.completed},
      questStatuses: const {
        854: SenkaRewardStatus.planned,
        947: SenkaRewardStatus.completed,
        949: SenkaRewardStatus.planned,
      },
      recordedQuestIds: const {854, 947, 949},
      favoriteSortieMapKeys: const {'1-5'},
      hiddenSortieMapKeys: const {'7-1'},
      targetSenka: 3000,
      calculatorCurrentSenka: 1000,
    );
    final next = reducer.reduce(
      old,
      apiEvent('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 200000,
        },
      }, atJst: DateTime(2026, 8, 1, 3)),
    );

    expect(next.monthKey, '2026-08');
    expect(next.completedEoIds, isEmpty);
    expect(next.questStatuses, old.questStatuses);
    expect(next.recordedQuestIds, old.recordedQuestIds);
    expect(next.memberId, 123);
    expect(next.serverOrigin, old.serverOrigin);
    expect(next.favoriteSortieMapKeys, {'1-5'});
    expect(next.hiddenSortieMapKeys, {'7-1'});
    expect(next.targetSenka, 0);
    expect(next.calculatorCurrentSenka, 0);
  });

  test('舰 C 季度和年度任务在重置月一日五点后才重置', () {
    SenkaState stateAt(String month) => SenkaState.forMonth(month).copyWith(
      questStatuses: const {
        854: SenkaRewardStatus.completed,
        947: SenkaRewardStatus.planned,
        949: SenkaRewardStatus.completed,
      },
    );

    SenkaState migrate(String from, int year, int month, int hour) =>
        reducer.reduce(
          stateAt(from),
          apiEvent(
            '/kcsapi/api_get_member/basic',
            const {},
            atJst: DateTime(year, month, 1, hour),
          ),
        );

    expect(migrate('2026-02', 2026, 3, 3).questStatuses.keys, {854, 947, 949});
    expect(migrate('2026-02', 2026, 3, 5).questStatuses.keys, {947, 949});
    expect(migrate('2026-03', 2026, 4, 5).questStatuses.keys, {854, 947, 949});
    expect(migrate('2026-05', 2026, 6, 3).questStatuses.keys, {854, 947, 949});
    expect(migrate('2026-05', 2026, 6, 5).questStatuses.keys, {949});
    expect(migrate('2026-12', 2027, 1, 5).questStatuses.keys, {854, 947, 949});

    final annualMay = migrate('2026-05', 2026, 6, 5);
    expect(annualMay.questStatuses.containsKey(947), isFalse);
    final annualDecember = migrate('2026-12', 2027, 1, 5);
    expect(annualDecember.questStatuses[947], SenkaRewardStatus.planned);

    final quarterlyReset = migrateSenkaRewardCycles(
      SenkaState.forMonth('2026-03').copyWith(
        quarterlyQuestCycleKey: '2025-12',
        annualQuestCycleKey: '2025-06',
        recordedQuestIds: const {854, 947, 949},
      ),
      DateTime.utc(2026, 3, 1, 20),
    );
    expect(quarterlyReset.recordedQuestIds, {947, 949});

    final annualReset = migrateSenkaRewardCycles(
      SenkaState.forMonth('2026-06').copyWith(
        quarterlyQuestCycleKey: '2026-03',
        annualQuestCycleKey: '2025-06',
        recordedQuestIds: const {854, 947, 949},
      ),
      DateTime.utc(2026, 6, 1, 20),
    );
    expect(annualReset.recordedQuestIds, {949});

    final resetWithDailyTarget = reducer.reduce(
      SenkaState.forMonth('2026-03').copyWith(
        quarterlyQuestCycleKey: '2025-12',
        calculatorCurrentSenka: 1000,
        questStatuses: const {854: SenkaRewardStatus.planned},
        dailyTargetDateKey: '2026-03-01',
        dailyProjectedSenkaAtStart: 1350,
      ),
      apiEvent(
        '/kcsapi/api_get_member/basic',
        const {},
        atJst: DateTime(2026, 3, 1, 5),
      ),
    );
    expect(resetWithDailyTarget.questStatuses, isEmpty);
    expect(resetWithDailyTarget.dailyProjectedSenkaAtStart, 1000);
  });

  test('非法旧 monthKey 不会按字典序永久拒绝有效新事件', () {
    for (final invalid in ['2026-8', 'garbage', '9999-99']) {
      final next = reducer.reduce(
        SenkaState.forMonth(invalid).copyWith(memberId: 123, nickname: '矢矧'),
        apiEvent('/kcsapi/api_get_member/basic', const {
          'api_experience': 100000,
        }, atJst: DateTime(2026, 8, 10, 3)),
      );

      expect(next.monthKey, '2026-08', reason: invalid);
      expect(next.memberId, 123, reason: invalid);
      expect(next.nickname, '矢矧', reason: invalid);
    }
  });

  test('支持事件保存非空服务器来源且空来源不覆盖', () {
    var state = reducer.reduce(
      SenkaState.forMonth('2026-08'),
      apiEvent(
        '/kcsapi/api_get_member/basic',
        const {},
        sourceOrigin: 'https://w14p.kancolle-server.com',
        atJst: DateTime(2026, 8, 10, 3),
      ),
    );
    state = reducer.reduce(
      state,
      apiEvent(
        '/kcsapi/api_get_member/mapinfo',
        const {},
        atJst: DateTime(2026, 8, 10, 4),
      ),
    );

    expect(state.serverOrigin, 'https://w14p.kancolle-server.com');
  });

  test('最后排名刷新时间取所有排名快照中的最新时间', () {
    final state = SenkaState.forMonth('2026-08').copyWith(
      rankingHistory: {
        '5': [
          snapshotAt(DateTime.utc(2026, 8, 10, 3)),
          snapshotAt(DateTime.utc(2026, 8, 10, 6)),
        ],
        'player': [snapshotAt(DateTime.utc(2026, 8, 10, 5))],
      },
    );

    expect(state.latestRankingUpdatedAt, DateTime.utc(2026, 8, 10, 6));
  });

  test('刷新任意排名页都会单独记录最后刷新时间', () {
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(memberId: 123, nickname: '矢矧'),
      rankingEvent(
        page: 2,
        rows: [rankingRow(rank: 11, senka: 900, nickname: '十一位')],
        atJst: DateTime(2026, 8, 10, 16, 41, 47),
      ),
    );

    expect(state.latestRankingUpdatedAt, DateTime.utc(2026, 8, 10, 7, 41, 47));
  });

  group('真实出击统计', () {
    test('出击按 02:00 战果日分别归档并继续累加本月数据', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(
          areaId: 1,
          mapNo: 1,
          nodeNo: 1,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 10, 1, 59),
        ),
      );
      state = reducer.reduce(
        state,
        sortieStart(
          areaId: 2,
          mapNo: 1,
          nodeNo: 1,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 10, 2),
        ),
      );

      expect(state.sortieStats.keys, unorderedEquals(['1-1', '2-1']));
      final storedDaily = state.toJson()['sortieStatsByDay'];
      expect(storedDaily, isA<Map>());
      final daily = storedDaily as Map;
      expect((daily['2026-08-09'] as Map).keys, contains('1-1'));
      expect((daily['2026-08-10'] as Map).keys, contains('2-1'));
    });

    test('旧存档中未完成的出击继续时补齐今日统计不变式', () {
      final oldJson =
          reducer
              .reduce(
                SenkaState.forMonth('2026-08'),
                sortieStart(areaId: 7, mapNo: 5, nodeNo: 9, bossCellNo: 9),
              )
              .toJson()
            ..remove('sortieStatsByDay');
      var state = SenkaState.fromJson(oldJson);

      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 8, 10, 10, 2)),
      );

      final today = state.sortieStatsForDay(DateTime.utc(2026, 8, 10, 3));
      expect(today['7-5']?.sorties, 1);
      expect(today['7-5']?.bossArrivals, 1);
      expect(today['7-5']?.sWins, 1);
      expect(
        SenkaState.fromJson(
          state.toJson(),
        ).sortieStatsForDay(DateTime.utc(2026, 8, 10, 3))['7-5']?.sWins,
        1,
      );
    });

    test('start 记录出击且 S/SS Boss 结果分别计入 S 胜', () {
      for (final rank in ['S', 'SS']) {
        var state = SenkaState.forMonth('2026-08');
        state = reducer.reduce(
          state,
          sortieStart(areaId: 2, mapNo: 3, nodeNo: 1, bossCellNo: 5),
        );
        state = reducer.reduce(
          state,
          apiEvent('/kcsapi/api_req_map/next', {
            'api_no': 5,
            'api_bosscell_no': 5,
          }, atJst: DateTime(2026, 8, 10, 10, 1)),
        );
        state = reducer.reduce(
          state,
          apiEvent('/kcsapi/api_req_sortie/battleresult', {
            'api_win_rank': rank,
          }, atJst: DateTime(2026, 8, 10, 10, 2)),
        );

        expect(state.sortieStats['2-3']?.sorties, 1);
        expect(state.sortieStats['2-3']?.bossArrivals, 1);
        expect(state.sortieStats['2-3']?.sWins, 1);
        expect(state.toJson()['activeSortie'], isNull);
      }
    });

    test('start 直接到 Boss 且 A 胜时各计一次', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(areaId: 7, mapNo: 5, nodeNo: 9, bossCellNo: 9),
      );
      state = reducer.reduce(
        state,
        apiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          {'api_win_rank': 'A'},
          atJst: DateTime(2026, 8, 10, 10, 2),
        ),
      );

      expect(state.sortieStats['7-5']?.sorties, 1);
      expect(state.sortieStats['7-5']?.bossArrivals, 1);
      expect(state.sortieStats['7-5']?.aWins, 1);
    });

    test('Boss 事件标识优先于内部节点编号识别途中 Boss', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(areaId: 2, mapNo: 2, nodeNo: 1, bossCellNo: 11),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 13,
          'api_bosscell_no': 11,
          'api_event_id': 5,
        }, atJst: DateTime(2026, 8, 10, 10, 1)),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'A',
        }, atJst: DateTime(2026, 8, 10, 10, 2)),
      );

      expect(state.sortieStats['2-2']?.sorties, 1);
      expect(state.sortieStats['2-2']?.bossArrivals, 1);
      expect(state.sortieStats['2-2']?.aWins, 1);
      expect(state.activeSortie, isNull);
    });

    test('Boss 事件标识优先于内部节点编号识别起始 Boss', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        apiEvent('/kcsapi/api_req_map/start', {
          'api_maparea_id': 6,
          'api_mapinfo_no': 4,
          'api_no': 14,
          'api_bosscell_no': 11,
          'api_event_id': 5,
        }, atJst: DateTime(2026, 8, 10, 10)),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 8, 10, 10, 1)),
      );

      expect(state.sortieStats['6-4']?.sorties, 1);
      expect(state.sortieStats['6-4']?.bossArrivals, 1);
      expect(state.sortieStats['6-4']?.sWins, 1);
      expect(state.activeSortie, isNull);
    });

    test('非 Boss 结果不计胜场且不清除出击上下文', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(areaId: 3, mapNo: 2, nodeNo: 1, bossCellNo: 4),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 8, 10, 10, 1)),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 4,
        }, atJst: DateTime(2026, 8, 10, 10, 2)),
      );

      expect(state.sortieStats['3-2']?.sWins, 0);
      expect(state.sortieStats['3-2']?.bossArrivals, 1);
      expect(state.toJson()['activeSortie'], isNotNull);
    });

    test('重复 Boss 到达响应只计一次', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(areaId: 4, mapNo: 5, nodeNo: 1, bossCellNo: 6),
      );
      for (var index = 0; index < 2; index++) {
        state = reducer.reduce(
          state,
          apiEvent('/kcsapi/api_req_map/next', {
            'api_no': 6,
            'api_bosscell_no': 6,
          }, atJst: DateTime(2026, 8, 10, 10, index + 1)),
        );
      }

      expect(state.sortieStats['4-5']?.bossArrivals, 1);
    });

    test('goback_port、combined goback_port 与 port 清除上下文', () {
      for (final path in [
        '/kcsapi/api_req_sortie/goback_port',
        '/kcsapi/api_req_combined_battle/goback_port',
        '/kcsapi/api_port/port',
      ]) {
        var state = reducer.reduce(
          SenkaState.forMonth('2026-08'),
          sortieStart(areaId: 1, mapNo: 1, nodeNo: 1, bossCellNo: 3),
        );
        state = reducer.reduce(
          state,
          apiEvent(path, const {}, atJst: DateTime(2026, 8, 10, 10, 1)),
        );
        state = reducer.reduce(
          state,
          apiEvent('/kcsapi/api_req_map/next', {
            'api_no': 3,
          }, atJst: DateTime(2026, 8, 10, 10, 2)),
        );

        expect(state.sortieStats['1-1']?.bossArrivals, 0, reason: path);
        expect(state.toJson()['activeSortie'], isNull, reason: path);
      }
    });

    test('无效与乱序响应不伪造统计，新 start 替换旧出击', () {
      var state = SenkaState.forMonth('2026-08');
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 5,
          'api_bosscell_no': 5,
        }, atJst: DateTime(2026, 8, 10, 9)),
      );
      state = reducer.reduce(
        state,
        sortieStart(areaId: 0, mapNo: 3, nodeNo: 5, bossCellNo: 5),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/start', {
          'api_maparea_id': 2.5,
          'api_mapinfo_no': 3,
          'api_no': 5,
          'api_bosscell_no': 5,
        }, atJst: DateTime(2026, 8, 10, 9, 1)),
      );
      state = reducer.reduce(
        state,
        sortieStart(areaId: 2, mapNo: 1, nodeNo: 1, bossCellNo: 4),
      );
      state = reducer.reduce(
        state,
        sortieStart(areaId: 2, mapNo: 2, nodeNo: 1, bossCellNo: 5),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 4,
        }, atJst: DateTime(2026, 8, 10, 10, 1)),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 5,
        }, atJst: DateTime(2026, 8, 10, 10, 2)),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_practice/battle_result', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 8, 10, 10, 3)),
      );

      expect(state.sortieStats.keys, unorderedEquals(['2-1', '2-2']));
      expect(state.sortieStats['2-1']?.bossArrivals, 0);
      expect(state.sortieStats['2-2']?.bossArrivals, 1);
      expect(state.sortieStats['2-2']?.sWins, 0);
      expect(state.toJson()['activeSortie'], isNotNull);
    });

    test('月度 JSON 往返保留未完成出击且不泄露可变引用', () {
      var original = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(
          areaId: 5,
          mapNo: 5,
          nodeNo: 2,
          bossCellNo: 7,
          atJst: DateTime(2026, 8, 10, 10),
        ),
      );
      original = reducer.reduce(
        original,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 3,
        }, atJst: DateTime(2026, 8, 10, 10, 2)),
      );
      final json = original.toJson();
      final restored = SenkaState.fromJson(json);
      final active = json['activeSortie'];
      expect(active, isA<Map>());
      (active as Map)['areaId'] = 99;

      expect(restored.toJson()['activeSortie'], {
        'areaId': 5,
        'mapNo': 5,
        'bossCellNo': 7,
        'bossArrived': false,
        'startedAt': '2026-08-10T01:00:00.000Z',
        'lastEventAt': '2026-08-10T01:02:00.000Z',
      });
      expect(restored.sortieStats['5-5']?.sorties, 1);
      expect(
        restored.toJson()['latestSortieEventAt'],
        '2026-08-10T01:02:00.000Z',
      );
    });

    test('旧 next 与旧 S 不污染新 start，相同时间戳仍接受', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(
          areaId: 2,
          mapNo: 1,
          nodeNo: 1,
          bossCellNo: 4,
          atJst: DateTime(2026, 8, 10, 10),
        ),
      );
      state = reducer.reduce(
        state,
        sortieStart(
          areaId: 2,
          mapNo: 2,
          nodeNo: 1,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 10, 11),
        ),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 5,
        }, atJst: DateTime(2026, 8, 10, 10, 30)),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 5,
        }, atJst: DateTime(2026, 8, 10, 11)),
      );
      expect(state.sortieStats['2-2']?.bossArrivals, 1);

      state = reducer.reduce(
        state,
        sortieStart(
          areaId: 2,
          mapNo: 3,
          nodeNo: 5,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 10, 12),
        ),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 8, 10, 11, 30)),
      );

      expect(state.sortieStats['2-3']?.sWins, 0);
      expect(state.toJson()['activeSortie'], isNotNull);

      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 8, 10, 12)),
      );

      expect(state.sortieStats['2-3']?.sWins, 1);
      expect(state.toJson()['activeSortie'], isNull);
    });

    test('月度 JSON 丢弃不满足统计不变式的出击上下文', () {
      final validActive = <String, Object?>{
        'areaId': 2,
        'mapNo': 3,
        'bossCellNo': 5,
        'bossArrived': true,
        'startedAt': '2026-08-10T01:00:00.000Z',
        'lastEventAt': '2026-08-10T01:02:00.000Z',
      };
      final validStats = <String, Object?>{
        'areaId': 2,
        'mapNo': 3,
        'sorties': 1,
        'bossArrivals': 1,
      };
      final malformed = <Map<String, Object?>>[
        {
          'sortieStats': {'2-3': validStats},
          'activeSortie': {...validActive, 'bossCellNo': null},
        },
        {'sortieStats': const {}, 'activeSortie': validActive},
        {
          'sortieStats': {
            '2-3': {...validStats, 'sorties': 0},
          },
          'activeSortie': validActive,
        },
        {
          'sortieStats': {
            '2-3': {...validStats, 'bossArrivals': 0},
          },
          'activeSortie': validActive,
        },
      ];

      for (final json in malformed) {
        expect(
          SenkaState.fromJson({'monthKey': '2026-08', ...json}).activeSortie,
          isNull,
          reason: '$json',
        );
      }
    });

    test('无效 Boss 结果清理已到达上下文，但保留非 Boss 上下文', () {
      var bossState = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(areaId: 6, mapNo: 4, nodeNo: 5, bossCellNo: 5),
      );
      bossState = reducer.reduce(
        bossState,
        apiEvent(
          '/kcsapi/api_req_sortie/battleresult',
          null,
          atJst: DateTime(2026, 8, 10, 10, 1),
        ),
      );

      var nonBossState = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(areaId: 6, mapNo: 5, nodeNo: 1, bossCellNo: 5),
      );
      nonBossState = reducer.reduce(
        nonBossState,
        apiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          null,
          atJst: DateTime(2026, 8, 10, 10, 1),
        ),
      );

      expect(bossState.activeSortie, isNull);
      expect(bossState.sortieStats['6-4']?.sWins, 0);
      expect(nonBossState.activeSortie, isNotNull);
    });

    test('八月状态完整忽略七月的 start、next、result 与 clear', () {
      final august = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(
          areaId: 2,
          mapNo: 3,
          nodeNo: 1,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 10, 10),
        ),
      );
      final staleEvents = [
        sortieStart(
          areaId: 1,
          mapNo: 1,
          nodeNo: 1,
          bossCellNo: 3,
          atJst: DateTime(2026, 7, 10, 10),
        ),
        apiEvent('/kcsapi/api_req_map/next', {
          'api_no': 5,
        }, atJst: DateTime(2026, 7, 10, 10, 1)),
        apiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'S',
        }, atJst: DateTime(2026, 7, 10, 10, 2)),
        apiEvent(
          '/kcsapi/api_req_sortie/goback_port',
          const {},
          atJst: DateTime(2026, 7, 10, 10, 3),
        ),
        apiEvent('/kcsapi/api_port/port', const {
          'api_basic': {
            'api_member_id': 999,
            'api_nickname': '旧月',
            'api_experience': 999999,
          },
        }, atJst: DateTime(2026, 7, 10, 10, 4)),
      ];

      var state = august;
      for (final event in staleEvents) {
        final before = state;
        state = reducer.reduce(state, event);
        expect(identical(state, before), isTrue, reason: event.path);
      }
      expect(state.toJson(), august.toJson());
    });

    test('统一 watermark 拒绝旧 malformed start、valid start 与 clear', () {
      var state = reducer.reduce(
        SenkaState.forMonth('2026-08'),
        sortieStart(
          areaId: 2,
          mapNo: 3,
          nodeNo: 1,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 10, 12),
        ),
      );
      final snapshot = state.toJson();
      final staleEvents = [
        apiEvent('/kcsapi/api_req_map/start', {
          'api_maparea_id': 0,
        }, atJst: DateTime(2026, 8, 10, 11)),
        sortieStart(
          areaId: 7,
          mapNo: 5,
          nodeNo: 1,
          bossCellNo: 9,
          atJst: DateTime(2026, 8, 10, 11, 1),
        ),
        apiEvent(
          '/kcsapi/api_req_combined_battle/goback_port',
          const {},
          atJst: DateTime(2026, 8, 10, 11, 2),
        ),
        apiEvent(
          '/kcsapi/api_port/port',
          const {},
          atJst: DateTime(2026, 8, 10, 11, 3),
        ),
      ];

      for (final event in staleEvents) {
        final before = state;
        state = reducer.reduce(state, event);
        expect(identical(state, before), isTrue, reason: event.path);
      }
      expect(state.toJson(), snapshot);
    });

    test('同 timestamp 与地图的重复 start 在 active 清理后仍幂等', () {
      final start = sortieStart(
        areaId: 3,
        mapNo: 4,
        nodeNo: 1,
        bossCellNo: 6,
        atJst: DateTime(2026, 8, 10, 10),
      );
      var state = reducer.reduce(SenkaState.forMonth('2026-08'), start);
      state = reducer.reduce(
        state,
        apiEvent(
          '/kcsapi/api_req_sortie/goback_port',
          const {},
          atJst: DateTime(2026, 8, 10, 10),
        ),
      );
      state = SenkaState.fromJson(state.toJson());
      state = reducer.reduce(state, start);

      expect(state.sortieStats['3-4']?.sorties, 1);
      expect(state.activeSortie, isNull);
      expect(state.toJson()['latestSortieEventAt'], '2026-08-10T01:00:00.000Z');
      expect(state.toJson()['lastSortieStartAt'], '2026-08-10T01:00:00.000Z');
      expect(state.toJson()['lastSortieStartMapKey'], '3-4');
    });

    test('月度 JSON 丢弃非正整数、负计数与跨字段矛盾的出击统计', () {
      final malformedStats = <Map<String, Object?>>[
        {'areaId': -1, 'mapNo': 3, 'sorties': 1},
        {'areaId': 2, 'mapNo': 1.5, 'sorties': 1},
        {'areaId': 2, 'mapNo': 3, 'sorties': -1},
        {'areaId': 2, 'mapNo': 3, 'sorties': 1.5},
        {'areaId': 2, 'mapNo': 3, 'sorties': 1, 'bossArrivals': 2},
        {
          'areaId': 2,
          'mapNo': 3,
          'sorties': 2,
          'bossArrivals': 1,
          'sWins': 1,
          'aWins': 1,
        },
      ];

      for (final stats in malformedStats) {
        final state = SenkaState.fromJson({
          'monthKey': '2026-08',
          'sortieStats': {'2-3': stats},
        });
        expect(state.sortieStats, isEmpty, reason: '$stats');
      }
    });

    test('后续月份 rollover 重置出击统计、watermark 与 active 并保留身份', () {
      var state = SenkaState.forMonth(
        '2026-08',
      ).copyWith(memberId: 123, nickname: '矢矧', magic: 61);
      state = reducer.reduce(
        state,
        sortieStart(
          areaId: 2,
          mapNo: 3,
          nodeNo: 1,
          bossCellNo: 5,
          atJst: DateTime(2026, 8, 31, 10),
        ),
      );
      state = reducer.reduce(
        state,
        apiEvent('/kcsapi/api_get_member/basic', const {
          'api_experience': 100000,
        }, atJst: DateTime(2026, 9, 1, 3)),
      );

      expect(state.monthKey, '2026-09');
      expect(state.memberId, 123);
      expect(state.nickname, '矢矧');
      expect(state.magic, 61);
      expect(state.sortieStats, isEmpty);
      expect(state.activeSortie, isNull);
      expect(state.toJson()['latestSortieEventAt'], isNull);
      expect(state.toJson()['lastSortieStartAt'], isNull);
      expect(state.toJson()['lastSortieStartMapKey'], isNull);
    });

    test('JSON last start 无对应有效统计时清空生命周期元数据且不误判重复', () {
      for (final stats in [
        <String, Object?>{},
        <String, Object?>{
          '7-5': {
            'areaId': 7,
            'mapNo': 5,
            'sorties': 0,
            'bossArrivals': 0,
            'sWins': 0,
            'aWins': 0,
          },
        },
      ]) {
        var state = SenkaState.fromJson({
          'monthKey': '2026-08',
          'sortieStats': stats,
          'latestSortieEventAt': '2026-08-10T01:00:00.000Z',
          'lastSortieStartAt': '2026-08-10T01:00:00.000Z',
          'lastSortieStartMapKey': '7-5',
          'activeSortie': {
            'areaId': 7,
            'mapNo': 5,
            'bossCellNo': 9,
            'bossArrived': false,
            'startedAt': '2026-08-10T01:00:00.000Z',
            'lastEventAt': '2026-08-10T01:00:00.000Z',
          },
        });

        expect(state.latestSortieEventAt, isNull, reason: '$stats');
        expect(state.lastSortieStartAt, isNull, reason: '$stats');
        expect(state.lastSortieStartMapKey, isNull, reason: '$stats');
        expect(state.activeSortie, isNull, reason: '$stats');

        state = reducer.reduce(
          state,
          sortieStart(
            areaId: 7,
            mapNo: 5,
            nodeNo: 1,
            bossCellNo: 9,
            atJst: DateTime(2026, 8, 10, 10),
          ),
        );
        expect(state.sortieStats['7-5']?.sorties, 1, reason: '$stats');
        expect(state.activeSortie, isNotNull, reason: '$stats');
      }
    });

    test('JSON active 必须与最后 start 的 map 和 startedAt 一致', () {
      final base = <String, Object?>{
        'monthKey': '2026-08',
        'sortieStats': {
          '2-3': {
            'areaId': 2,
            'mapNo': 3,
            'sorties': 1,
            'bossArrivals': 0,
            'sWins': 0,
            'aWins': 0,
          },
          '2-4': {
            'areaId': 2,
            'mapNo': 4,
            'sorties': 1,
            'bossArrivals': 0,
            'sWins': 0,
            'aWins': 0,
          },
        },
        'latestSortieEventAt': '2026-08-10T01:05:00.000Z',
        'lastSortieStartAt': '2026-08-10T01:00:00.000Z',
        'lastSortieStartMapKey': '2-3',
      };
      final contradictoryActive = [
        {
          'areaId': 2,
          'mapNo': 4,
          'bossCellNo': 5,
          'bossArrived': false,
          'startedAt': '2026-08-10T01:00:00.000Z',
          'lastEventAt': '2026-08-10T01:05:00.000Z',
        },
        {
          'areaId': 2,
          'mapNo': 3,
          'bossCellNo': 5,
          'bossArrived': false,
          'startedAt': '2026-08-10T01:01:00.000Z',
          'lastEventAt': '2026-08-10T01:05:00.000Z',
        },
        {
          'areaId': 2,
          'mapNo': 3,
          'bossCellNo': 5,
          'bossArrived': false,
          'startedAt': '2026-08-10T01:00:00.000Z',
          'lastEventAt': '2026-08-10T01:06:00.000Z',
        },
      ];

      for (final active in contradictoryActive) {
        final state = SenkaState.fromJson({...base, 'activeSortie': active});
        expect(state.activeSortie, isNull, reason: '$active');
        expect(state.lastSortieStartMapKey, '2-3', reason: '$active');
      }
    });

    test('每个 result、goback 与 port path 都拒绝 watermark 之前的事件', () {
      final stalePaths = <String, Object?>{
        '/kcsapi/api_req_sortie/battleresult': {'api_win_rank': 'S'},
        '/kcsapi/api_req_combined_battle/battleresult': {'api_win_rank': 'A'},
        '/kcsapi/api_req_sortie/goback_port': const {},
        '/kcsapi/api_req_combined_battle/goback_port': const {},
        '/kcsapi/api_port/port': const {
          'api_basic': {
            'api_member_id': 999,
            'api_nickname': '旧事件',
            'api_experience': 999999,
          },
        },
      };

      for (final entry in stalePaths.entries) {
        final state = reducer.reduce(
          SenkaState.forMonth(
            '2026-08',
          ).copyWith(memberId: 123, nickname: '矢矧'),
          sortieStart(
            areaId: 5,
            mapNo: 5,
            nodeNo: 7,
            bossCellNo: 7,
            atJst: DateTime(2026, 8, 10, 12),
          ),
        );
        final next = reducer.reduce(
          state,
          apiEvent(entry.key, entry.value, atJst: DateTime(2026, 8, 10, 11)),
        );

        expect(identical(next, state), isTrue, reason: entry.key);
      }
    });
  });
}

CapturedApiEvent apiEvent(
  String path,
  Object? data, {
  Map<String, Object?> params = const {},
  String sourceOrigin = '',
  required DateTime atJst,
}) {
  return CapturedApiEvent(
    path: path,
    requestParams: params,
    responseBody: jsonEncode({'api_result': 1, 'api_data': data}),
    source: CaptureSource.manual,
    sourceOrigin: sourceOrigin,
    capturedAt: DateTime.utc(
      atJst.year,
      atJst.month,
      atJst.day,
      atJst.hour,
      atJst.minute,
      atJst.second,
    ).subtract(const Duration(hours: 9)),
  );
}

CapturedApiEvent rankingEvent({
  required int page,
  required List<Map<String, Object?>> rows,
  required DateTime atJst,
}) => apiEvent('/kcsapi/api_req_ranking/mxltvkpyuklh', {
  'api_disp_page': page,
  'api_list': rows,
}, atJst: atJst);

CapturedApiEvent sortieStart({
  required int areaId,
  required int mapNo,
  required int nodeNo,
  required int bossCellNo,
  DateTime? atJst,
}) => apiEvent('/kcsapi/api_req_map/start', {
  'api_maparea_id': areaId,
  'api_mapinfo_no': mapNo,
  'api_no': nodeNo,
  'api_bosscell_no': bossCellNo,
}, atJst: atJst ?? DateTime(2026, 8, 10, 10));

Map<String, Object?> rankingRow({
  required int rank,
  required int senka,
  required String nickname,
  int? magic,
}) {
  const magicLeft = [36, 31, 33, 97, 64, 54, 52, 78, 40, 85];
  const magicRight = [
    8931,
    1201,
    1156,
    5061,
    4569,
    4732,
    3779,
    4568,
    5695,
    4619,
    4912,
    5669,
    6586,
  ];
  const memberId = 123;
  final actualMagic = magic ?? magicLeft[memberId % 10];
  return {
    'api_mxltvkpyuklh': rank,
    'api_mtjmdcwtvhdr': nickname,
    'api_wuhnhojjxmke': (senka + 73 + 18) * magicRight[rank % 13] * actualMagic,
  };
}

Map<String, Object?> rankingEncryptedRow({
  required int rank,
  required int encrypted,
  required String nickname,
}) => {
  'api_mxltvkpyuklh': rank,
  'api_mtjmdcwtvhdr': nickname,
  'api_wuhnhojjxmke': encrypted,
};

SenkaRankingSnapshot snapshotAt(DateTime capturedAt) => SenkaRankingSnapshot(
  rank: 1,
  senka: 1,
  capturedAt: capturedAt,
  localSenkaAtCapture: 0,
);
