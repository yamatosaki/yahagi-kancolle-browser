import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';

void main() {
  test('连续捕获只在下一帧通知一次', () async {
    final scheduled = <void Function()>[];
    final controller = SenkaController(
      store: MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 10),
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduled.add,
      ),
    );
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller
      ..accept(
        event('/kcsapi/api_get_member/basic', {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        }),
      )
      ..accept(
        event('/kcsapi/api_get_member/mapinfo', {
          'api_map_info': [
            {'api_id': 15, 'api_cleared': 1},
          ],
        }),
      );
    await controller.idle;

    expect(controller.state.completedEoIds, {15});
    expect(notifications, 0);
    expect(scheduled, hasLength(1));
    scheduled.single();
    expect(notifications, 1);
    controller.dispose();
  });

  test('初始化加载当月档案并在事件处理后保存', () async {
    final store = MemorySenkaStore(
      SenkaState.forMonth('2026-08').copyWith(memberId: 123),
    );
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();
    controller.accept(
      event('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        },
      }),
    );
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(store.saved?.nickname, '矢矧');
    expect(store.saveCount, 1);
  });

  test('加载旧月份只保留账号身份并创建当月档案', () async {
    final store = MemorySenkaStore(
      SenkaState.forMonth(
        '2026-07',
      ).copyWith(memberId: 123, nickname: '矢矧', completedEoIds: {15}),
    );
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();

    expect(controller.state.monthKey, '2026-08');
    expect(controller.state.memberId, 123);
    expect(controller.state.completedEoIds, isEmpty);
  });

  test('手动切换 EO 和任务只改变完成状态不伪造日历记录', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();

    controller.toggleEo(15);
    controller.toggleQuest(854);
    await controller.idle;

    expect(controller.state.completedEoIds, {15});
    expect(controller.state.completedQuestIds, {854});
    expect(controller.state.completedSenka, 425);
    expect(controller.state.monthRecorded, 0);

    controller.toggleEo(15);
    controller.toggleQuest(854);
    await controller.idle;
    expect(controller.state.completedEoIds, isEmpty);
    expect(controller.state.completedQuestIds, isEmpty);
  });

  test('同一时间捕获的多条数据依次入档不丢失', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();

    controller.accept(
      event('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        },
      }),
    );
    controller.accept(
      event('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
        ],
      }),
    );
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(controller.state.completedEoIds, {15});
    expect(store.saveCount, 2);
  });

  test('EO 自动同步后仍可由玩家手动取消', () async {
    final controller = SenkaController(
      store: MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();
    controller.accept(
      event('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
        ],
      }),
    );
    await controller.idle;
    expect(controller.state.completedEoIds, {15});

    controller.toggleEo(15);
    await controller.idle;
    expect(controller.state.completedEoIds, isEmpty);
    controller.dispose();
  });
}

class MemorySenkaStore implements SenkaStore {
  MemorySenkaStore([this.saved]);

  SenkaState? saved;
  int saveCount = 0;

  @override
  Future<SenkaState?> load() async => saved;

  @override
  Future<void> save(SenkaState state) async {
    saved = state;
    saveCount++;
  }
}

CapturedApiEvent event(String path, Object data) => CapturedApiEvent(
  path: path,
  responseBody: jsonEncode({'api_result': 1, 'api_data': data}),
  source: CaptureSource.manual,
  capturedAt: DateTime.utc(2026, 8, 10, 3),
);
