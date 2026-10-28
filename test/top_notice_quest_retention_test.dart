import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('ordinary replacement keeps the quest until its own deadline', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'quest',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 5),
    );
    await tester.pump(const Duration(milliseconds: 600));
    notices.show(message: 'ordinary', duration: const Duration(seconds: 1));

    expect(_messages(notices), ['quest', 'ordinary']);
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['quest']);
    await tester.pump(const Duration(milliseconds: 3399));
    expect(_messages(notices), ['quest']);
    await tester.pump(const Duration(milliseconds: 1));
    expect(notices.notices, isEmpty);
  });

  testWidgets('ordinary append cannot shorten the quest display duration', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'quest',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 5),
    );
    notices.show(
      message: 'ordinary',
      duration: const Duration(seconds: 1),
      appendWithin: const Duration(seconds: 30),
    );

    expect(_messages(notices), ['quest', 'ordinary']);
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['quest']);
    await tester.pump(const Duration(seconds: 4));
    expect(notices.notices, isEmpty);
  });

  testWidgets('repeated ordinary messages never renew the quest deadline', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'quest',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 5),
    );
    for (var index = 1; index <= 4; index++) {
      await tester.pump(const Duration(seconds: 1));
      notices.show(
        message: 'ordinary $index',
        duration: const Duration(seconds: 10),
      );
      expect(_messages(notices), ['quest', 'ordinary $index']);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['ordinary 4']);
    await tester.pump(const Duration(seconds: 9));
    expect(notices.notices, isEmpty);
  });

  testWidgets('ordinary batches retain their replacement and append behavior', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(message: 'first', duration: const Duration(seconds: 1));
    notices.show(
      message: 'appended',
      duration: const Duration(seconds: 3),
      appendWithin: const Duration(milliseconds: 500),
    );
    expect(_messages(notices), ['first', 'appended']);
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['first', 'appended']);
    notices.show(message: 'replacement', duration: const Duration(seconds: 2));
    expect(_messages(notices), ['replacement']);
    await tester.pump(const Duration(seconds: 2));
    expect(notices.notices, isEmpty);
  });

  testWidgets('new quest still replaces the old batch by default', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'old quest',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 2),
    );
    await tester.pump(const Duration(seconds: 1));
    notices.show(
      message: 'new quest',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 5),
    );
    expect(_messages(notices), ['new quest']);
    var updates = 0;
    notices.addListener(() => updates++);
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['new quest']);
    expect(updates, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(notices.notices, isEmpty);
    expect(updates, 1);
  });

  testWidgets(
    'appended quests retain independent deadlines across a new batch',
    (tester) async {
      final notices = TopNoticeController();
      addTearDown(notices.dispose);
      notices.show(
        message: 'first quest',
        tone: TopNoticeTone.quest,
        duration: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(milliseconds: 500));
      notices.show(
        message: 'second quest',
        tone: TopNoticeTone.quest,
        duration: const Duration(seconds: 5),
        appendWithin: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(milliseconds: 500));
      notices.show(message: 'ordinary', duration: const Duration(seconds: 10));
      expect(_messages(notices), ['first quest', 'second quest', 'ordinary']);
      await tester.pump(const Duration(seconds: 1));
      expect(_messages(notices), ['second quest', 'ordinary']);
      await tester.pump(const Duration(milliseconds: 3499));
      expect(_messages(notices), ['second quest', 'ordinary']);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_messages(notices), ['ordinary']);
      await tester.pump(const Duration(milliseconds: 5500));
      expect(notices.notices, isEmpty);
    },
  );

  testWidgets('a keyed quest replacement cancels the earlier quest deadline', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'old quest',
      tone: TopNoticeTone.quest,
      replacementKey: 'quest',
      duration: const Duration(seconds: 2),
    );
    await tester.pump(const Duration(seconds: 1));
    notices.show(
      message: 'new quest',
      tone: TopNoticeTone.quest,
      replacementKey: 'quest',
      duration: const Duration(seconds: 5),
    );
    var updates = 0;
    notices.addListener(() => updates++);
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['new quest']);
    expect(updates, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(notices.notices, isEmpty);
    expect(updates, 1);
  });

  testWidgets('an explicit keyed ordinary replacement can clear its quest', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'quest',
      tone: TopNoticeTone.quest,
      replacementKey: 'activity',
      duration: const Duration(seconds: 2),
    );
    await tester.pump(const Duration(seconds: 1));
    notices.show(
      message: 'ordinary',
      replacementKey: 'activity',
      duration: const Duration(seconds: 5),
    );
    var updates = 0;
    notices.addListener(() => updates++);
    await tester.pump(const Duration(seconds: 1));
    expect(_messages(notices), ['ordinary']);
    expect(updates, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(notices.notices, isEmpty);
    expect(updates, 1);
  });

  testWidgets('account quest clearing cancels all retained quest deadlines', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    for (var seconds = 2; seconds <= 3; seconds++) {
      notices.show(
        message: 'quest $seconds',
        tone: TopNoticeTone.quest,
        duration: Duration(seconds: seconds),
        appendWithin: const Duration(seconds: 30),
      );
    }
    notices.show(message: 'ordinary', duration: const Duration(seconds: 5));
    notices.removeByTone(TopNoticeTone.quest);
    var updates = 0;
    notices.addListener(() => updates++);
    await tester.pump(const Duration(seconds: 3));
    expect(_messages(notices), ['ordinary']);
    expect(updates, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(notices.notices, isEmpty);
    expect(updates, 1);
  });

  for (final removal in ['hide', 'tone', 'key']) {
    testWidgets('$removal cancels removed quest timers before a new batch', (
      tester,
    ) async {
      final notices = TopNoticeController();
      addTearDown(notices.dispose);
      notices.show(
        message: 'old quest',
        tone: TopNoticeTone.quest,
        replacementKey: 'quest',
        duration: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(seconds: 1));
      switch (removal) {
        case 'hide':
          notices.hide();
        case 'tone':
          notices.removeByTone(TopNoticeTone.quest);
        case 'key':
          notices.removeByKey('quest');
      }
      expect(notices.notices, isEmpty);
      notices.show(
        message: 'new ordinary',
        duration: const Duration(seconds: 5),
      );
      var updates = 0;
      notices.addListener(() => updates++);
      await tester.pump(const Duration(seconds: 1));
      expect(_messages(notices), ['new ordinary']);
      expect(updates, 0);
      await tester.pump(const Duration(seconds: 4));
      expect(notices.notices, isEmpty);
      expect(updates, 1);
    });
  }

  testWidgets('removing a quest preserves another live ordinary notice', (
    tester,
  ) async {
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    notices.show(
      message: 'quest',
      tone: TopNoticeTone.quest,
      replacementKey: 'quest',
      duration: const Duration(seconds: 2),
    );
    notices.show(
      message: 'ordinary',
      duration: const Duration(seconds: 5),
      appendWithin: const Duration(seconds: 30),
    );
    notices.removeByKey('quest');
    var updates = 0;
    notices.addListener(() => updates++);
    await tester.pump(const Duration(seconds: 2));
    expect(_messages(notices), ['ordinary']);
    expect(updates, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(notices.notices, isEmpty);
    expect(updates, 1);
  });

  testWidgets('dispose cancels quest and ordinary expiry callbacks', (
    tester,
  ) async {
    final notices = TopNoticeController();
    var updates = 0;
    notices.show(
      message: 'quest',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 2),
    );
    notices.show(
      message: 'ordinary',
      duration: const Duration(seconds: 3),
      appendWithin: const Duration(seconds: 30),
    );
    notices.addListener(() => updates++);
    notices.dispose();
    await tester.pump(const Duration(seconds: 4));
    expect(updates, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded toolbar keeps quest visible after a later game message',
    (tester) async {
      final notices = TopNoticeController();
      addTearDown(notices.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestCompletionDrawerHost(
              controller: notices,
              child: const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 760,
                  height: 44,
                  child: QuestCompletionHeaderSlot(
                    toolbarVisible: true,
                    child: Text('toolbar controls'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      notices.show(
        message: '任务达成：测试任务',
        tone: TopNoticeTone.quest,
        duration: const Duration(seconds: 5),
        appendWithin: const Duration(milliseconds: 500),
      );
      await tester.pump();
      // DateTime.now controls batch membership, while pump advances timers.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      notices.show(
        message: '装备改修成功',
        tone: TopNoticeTone.success,
        duration: const Duration(seconds: 10),
        appendWithin: const Duration(milliseconds: 500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('任务达成：测试任务').hitTestable(), findsOneWidget);
      expect(find.text('装备改修成功'), findsOneWidget);
      expect(find.byKey(const Key('quest-completion-drawer')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 4150));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('任务达成：测试任务'), findsNothing);
      expect(_messages(notices), ['装备改修成功']);
      expect(find.text('toolbar controls').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      notices.hide();
    },
  );
}

List<String> _messages(TopNoticeController notices) =>
    notices.notices.map((notice) => notice.message).toList();
