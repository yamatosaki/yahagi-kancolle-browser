import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_reducer.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';

void main() {
  const reducer = SenkaReducer();

  test('browsing another page cannot adopt a same-name admiral', () {
    final own = reducer.reduce(
      _initial(),
      _ranking(page: 40, rows: [_row(392, 1200)], minute: 0),
    );
    expect(own.playerRankingRow.rank, 392);
    final otherPage = reducer.reduce(
      own,
      _ranking(
        page: 2,
        params: {'api_pageno': '2'},
        rows: [_row(15, 9000)],
        minute: 1,
      ),
    );

    expect(otherPage.playerRankingRow.rank, 392);
    expect(otherPage.calculatorCurrentSenka, own.calculatorCurrentSenka);
    expect(otherPage.calculatorLocalSenkaAtSet, own.calculatorLocalSenkaAtSet);
    expect(otherPage.rankingHistory['player'], own.rankingHistory['player']);
  });

  test('the game own-page request still refreshes rank and score', () {
    final own = reducer.reduce(
      _initial(),
      _ranking(page: 40, rows: [_row(392, 1200)], minute: 0),
    );
    // RecordRankingAPI omits api_pageno when the game requests the player page.
    final refreshed = reducer.reduce(
      own,
      _ranking(page: 39, rows: [_row(381, 1250)], minute: 1),
    );

    expect(refreshed.playerRankingRow.rank, 381);
    expect(refreshed.calculatorCurrentSenka, 1250);
  });

  test('explicit rank pages still update leaderboard anchors', () {
    final state = reducer.reduce(
      _initial(),
      _ranking(
        page: 1,
        params: {'api_pageno': '1'},
        rows: [_row(5, 9000)],
        minute: 0,
      ),
    );

    expect(state.rankingHistory['5']?.single.senka, 9000);
    expect(state.rankingHistory['player'], isNull);
    expect(state.calculatorCurrentSenka, 0);
  });

  test(
    'another page cannot use the same-name row to recalibrate decryption',
    () {
      final own = reducer.reduce(
        _initial().copyWith(magic: 30),
        _ranking(page: 40, rows: [_row(392, 100, magic: 30)], minute: 0),
      );
      // These rows admit both 30 and 60 as calibration candidates. Using the
      // unrelated namesake as the player's historical anchor incorrectly picks
      // 60, since it decodes that row's 291 points as the player's old 100.
      final otherPage = reducer.reduce(
        own,
        _ranking(
          page: 19,
          params: {'api_pageno': '19'},
          rows: [
            _row(181, 291, magic: 30),
            _row(182, 293, magic: 30, nickname: 'Another admiral'),
          ],
          minute: 1,
        ),
      );

      expect(otherPage.magic, 30);
      expect(otherPage.rankingHistory['player'], own.rankingHistory['player']);
    },
  );
}

SenkaState _initial() => SenkaState.forMonth(
  '2026-10',
).copyWith(memberId: 123, nickname: 'Namesake');

CapturedApiEvent _ranking({
  required int page,
  required List<Map<String, Object?>> rows,
  required int minute,
  Map<String, Object?> params = const {},
}) => CapturedApiEvent(
  path: '/kcsapi/api_req_ranking/mxltvkpyuklh',
  source: CaptureSource.manual,
  capturedAt: DateTime.utc(2026, 10, 30, 6, minute),
  requestParams: params,
  responseBody: jsonEncode({
    'api_result': 1,
    'api_data': {'api_disp_page': page, 'api_list': rows},
  }),
);

Map<String, Object?> _row(
  int rank,
  int senka, {
  String nickname = 'Namesake',
  int magic = 97,
}) {
  const right = [
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
  return {
    'api_mxltvkpyuklh': rank,
    'api_mtjmdcwtvhdr': nickname,
    'api_wuhnhojjxmke': (senka + 91) * right[rank % 13] * magic,
  };
}
