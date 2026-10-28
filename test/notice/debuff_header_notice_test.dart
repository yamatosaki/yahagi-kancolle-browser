import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  TopNoticeTone? debuffTone() =>
      TopNoticeTone.values.where((tone) => tone.name == 'debuff').firstOrNull;

  testWidgets('debuff notice stays in the header while the toolbar is open', (
    tester,
  ) async {
    final tone = debuffTone();
    expect(
      tone,
      isNotNull,
      reason: 'Debuff notices need their own display tone',
    );
    if (tone == null) return;
    final controller = TopNoticeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: QuestCompletionDrawerHost(
          controller: controller,
          child: const Scaffold(
            body: SizedBox(
              height: 44,
              child: QuestCompletionHeaderSlot(
                toolbarVisible: true,
                child: Text('Toolbar'),
              ),
            ),
          ),
        ),
      ),
    );
    controller.show(message: '削甲提示', tone: tone);
    await tester.pumpAndSettle();
    expect(find.text('削甲提示'), findsOneWidget);
    await tester.tap(find.text('削甲提示'));
    await tester.pumpAndSettle();
    expect(find.text('削甲提示'), findsNothing);
    expect(find.text('Toolbar'), findsOneWidget);
  });

  testWidgets('native fullscreen forwards debuff and quest notices together', (
    tester,
  ) async {
    final tone = debuffTone();
    expect(tone, isNotNull);
    if (tone == null) return;
    const channel = MethodChannel('app.yahagi.kancollebrowser/game_fullscreen');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final controller = TopNoticeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: QuestCompletionDrawerHost(
          controller: controller,
          fullscreen: true,
          nativeQuestOverlay: true,
          child: const SizedBox.expand(),
        ),
      ),
    );
    controller.show(message: '任务达成', tone: TopNoticeTone.quest);
    controller.show(
      message: '削甲提示',
      tone: tone,
      replacementKey: 'debuff-reminder-1',
    );
    await tester.pumpAndSettle();
    expect(calls.last.method, 'questNotice');
    expect(calls.last.arguments['message'], '削甲提示\n任务达成');
    controller.show(
      message: '另一个任务达成',
      tone: TopNoticeTone.quest,
      replacementKey: 'quest-2',
    );
    controller.show(
      message: '新的削甲提示',
      tone: tone,
      replacementKey: 'debuff-reminder-2',
    );
    await tester.pumpAndSettle();
    // The Android bubble has two lines. New debuff cues must not be hidden
    // below a backlog of task messages.
    expect(calls.last.arguments['message'], '新的削甲提示\n削甲提示\n任务达成\n另一个任务达成');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(calls.last.arguments['message'], '');
    controller.hide();
  });

  testWidgets('ordinary notices cannot remove or extend a debuff deadline', (
    tester,
  ) async {
    final tone = debuffTone();
    expect(tone, isNotNull);
    if (tone == null) return;
    final controller = TopNoticeController();
    addTearDown(controller.dispose);
    controller.show(
      message: '削甲提示',
      tone: tone,
      duration: const Duration(seconds: 5),
    );
    await tester.pump(const Duration(seconds: 2));
    controller.show(
      message: '开发完成',
      tone: TopNoticeTone.success,
      duration: const Duration(seconds: 10),
    );
    expect(controller.notices.map((notice) => notice.message), [
      '削甲提示',
      '开发完成',
    ]);
    await tester.pump(const Duration(seconds: 3));
    expect(controller.notices.map((notice) => notice.message), ['开发完成']);
    await tester.pump(const Duration(seconds: 7));
    expect(controller.notices, isEmpty);
  });
}
