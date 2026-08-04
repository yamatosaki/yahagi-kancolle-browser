import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';

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
    expect(find.text('已接受 2'), findsOneWidget);
    expect(find.text('已完成 1'), findsOneWidget);
    expect(find.textContaining('更新于'), findsNothing);
    expect(find.byKey(const Key('quest-count-segmented')), findsOneWidget);
    final accepted = tester.getRect(
      find.byKey(const Key('quest-count-accepted')),
    );
    final completed = tester.getRect(
      find.byKey(const Key('quest-count-completed')),
    );
    expect(accepted.right, completed.left);
    expect(find.byKey(const Key('quest-card-201')), findsOneWidget);
    expect(find.byKey(const Key('quest-card-402')), findsOneWidget);
    expect(find.text('50%+'), findsWidgets);
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

  testWidgets('does not duplicate the quest header inside the workspace', (
    tester,
  ) async {
    final controller = GameStateController();

    await tester.pumpWidget(
      MaterialApp(
        home: QuestCenterPage(controller: controller, showTitle: false),
      ),
    );

    expect(find.byKey(const Key('quest-count-segmented')), findsNothing);
    expect(find.textContaining('更新于'), findsNothing);
    controller.dispose();
  });
}
