import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  for (final expires in [false, true]) {
    testWidgets('normal completion reports dismissal once expiry=$expires', (
      tester,
    ) async {
      final context = await _mountHost(tester);
      var dismissed = 0;
      var unavailable = 0;
      final shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
        onDismissed: () => dismissed++,
        onUnavailable: () => unavailable++,
      );
      await tester.pump();
      expect(await shown, isTrue);
      if (expires) {
        await tester.pump(const Duration(seconds: 10));
      } else {
        await tester.pump(const Duration(milliseconds: 240));
        await tester.tap(find.text('大破舰已携带损管'));
      }
      await tester.pumpAndSettle();
      await _mountHost(tester, withSlot: false);
      await tester.pump(const Duration(seconds: 20));
      expect(dismissed, 1);
      expect(unavailable, 0);
      expect(find.text('大破舰已携带损管'), findsNothing);
    });
  }

  for (final removedBy in ['programmatic', 'build', 'unavailable', 'dispose']) {
    testWidgets('removal by $removedBy is not normal dismissal', (
      tester,
    ) async {
      final context = await _mountHost(tester);
      var dismissed = 0;
      var unavailable = 0;
      final shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
        onDismissed: () => dismissed++,
        onUnavailable: () => unavailable++,
      );
      await tester.pump();
      expect(await shown, isTrue);
      switch (removedBy) {
        case 'programmatic':
          QuestCompletionDrawerHost.removeDamageControlNotice(context);
        case 'build':
          final remove = QuestCompletionDrawerHost.damageControlNoticeRemover(
            context,
          )!;
          await _mountHost(tester, duringBuild: remove);
        case 'unavailable':
          await _mountHost(tester, withSlot: false);
        case 'dispose':
          await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(dismissed, 0);
      expect(unavailable, removedBy == 'unavailable' ? 1 : 0);
    });
  }

  testWidgets('replaying dismisses only the latest confirmed notice', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    var firstDismissed = 0;
    var secondDismissed = 0;
    var shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      'old',
      onDismissed: () => firstDismissed++,
    );
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump(const Duration(seconds: 8));
    final oldTap = tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('old'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!;
    shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
      onDismissed: () => secondDismissed++,
    );
    await tester.pump();
    expect(await shown, isTrue);
    oldTap();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    expect(firstDismissed, 0);
    expect(secondDismissed, 0);
    await tester.pump(const Duration(seconds: 8));
    expect(firstDismissed, 0);
    expect(secondDismissed, 1);
  });

  testWidgets('damage control uses the header capsule without an icon', (
    tester,
  ) async {
    final context = await _mountHost(tester, toolbarVisible: true);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    final entrance = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.text('大破舰已携带损管'),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(entrance.position.value, const Offset(-0.2, 0));
    await tester.pump(const Duration(milliseconds: 240));
    final capsule = find
        .ancestor(of: find.text('大破舰已携带损管'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(capsule).height, 34);
    final decoration =
        tester.widget<Container>(capsule).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(
      (decoration.border! as Border).top.color,
      const Color(0xffd4a85f).withValues(alpha: 0.35),
    );
    expect(
      find.descendant(of: capsule, matching: find.byType(Icon)),
      findsNothing,
    );
    final switcher = tester.widget<AnimatedSwitcher>(
      find.ancestor(of: capsule, matching: find.byType(AnimatedSwitcher)).first,
    );
    expect(switcher.duration, const Duration(milliseconds: 240));
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    await tester.pump();
  });

  testWidgets('damage control expires after ten seconds', (tester) async {
    final context = await _mountHost(tester);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump(const Duration(milliseconds: 9999));
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('大破舰已携带损管'), findsNothing);
  });

  testWidgets('replaying resets the damage control timer', (tester) async {
    final context = await _mountHost(tester);
    var shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump(const Duration(seconds: 8));
    shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump(const Duration(milliseconds: 9999));
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('大破舰已携带损管'), findsNothing);
  });

  testWidgets('tapping capsule padding dismisses only damage control', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    QuestCompletionDrawerHost.show(
      context,
      'quest',
      duration: const Duration(seconds: 30),
    );
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump(const Duration(milliseconds: 240));
    final capsule = find
        .ancestor(of: find.text('大破舰已携带损管'), matching: find.byType(Container))
        .first;
    final rect = tester.getRect(capsule);
    await tester.tapAt(Offset(rect.left + 2, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('大破舰已携带损管'), findsNothing);
    expect(find.text('quest'), findsOneWidget);
    QuestCompletionDrawerHost.hide(context);
    await tester.pump();
  });

  testWidgets('quest updates and deletion preserve damage control', (
    tester,
  ) async {
    final context = await _mountHost(tester, toolbarVisible: true);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    QuestCompletionDrawerHost.show(context, 'quest');
    await tester.pumpAndSettle();
    expect(find.text('quest'), findsOneWidget);
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.removeQuestNotices(context);
    await tester.pump();
    expect(find.text('quest'), findsNothing);
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.show(context, 'other', tone: TopNoticeTone.info);
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    await tester.pump();
    expect(find.text('大破舰已携带损管'), findsNothing);
    expect(find.text('other'), findsNothing);
    QuestCompletionDrawerHost.hide(context);
    await tester.pump();
  });

  testWidgets('damage control expiry leaves the quest timer intact', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    QuestCompletionDrawerHost.show(
      context,
      'quest',
      duration: const Duration(seconds: 15),
    );
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('大破舰已携带损管'), findsNothing);
    expect(find.text('quest'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('quest'), findsNothing);
  });

  testWidgets('Flutter fullscreen provides its own available header slot', (
    tester,
  ) async {
    final context = await _mountHost(tester, fullscreen: true, withSlot: false);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    await tester.pump();
  });

  testWidgets('no host or unavailable slot returns false', (tester) async {
    late BuildContext outside;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            outside = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    expect(
      await QuestCompletionDrawerHost.showDamageControlNotice(
        outside,
        '大破舰已携带损管',
      ),
      isFalse,
    );
    QuestCompletionDrawerHost.removeDamageControlNotice(outside);
    final context = await _mountHost(tester, withSlot: false);
    expect(
      await QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
      ),
      isFalse,
    );
    expect(find.text('大破舰已携带损管'), findsNothing);
  });

  testWidgets('hidden and zero width header slots return false', (
    tester,
  ) async {
    var context = await _mountHost(tester, hiddenSlot: true);
    expect(
      await QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
      ),
      isFalse,
    );
    context = await _mountHost(tester, slotWidth: 0);
    expect(
      await QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
      ),
      isFalse,
    );
  });

  for (final scenario in <(String, double, double)>[
    ('大破舰已携带损管', 1, 1),
    ('大破舰已携带损管', 1, 20),
    ('Damage control active', 1, 20),
    ('大破舰已携带损管', 2, 120),
    ('Damage control active', 1.6, 240),
    ('大破舰已携带损管', 3, 600),
  ]) {
    testWidgets('unreadable slot returns false for $scenario', (tester) async {
      final context = await _mountHost(
        tester,
        slotWidth: scenario.$3,
        textScale: scenario.$2,
      );
      final shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        scenario.$1,
      );
      await tester.pump();
      expect(await shown, isFalse);
      expect(find.text(scenario.$1), findsNothing);
    });
  }

  for (final message in ['大破舰已携带损管', 'Damage control active']) {
    testWidgets('readability follows the rendered phrase width for $message', (
      tester,
    ) async {
      var context = await _mountHost(tester, slotWidth: 600);
      var shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        message,
      );
      await tester.pump();
      expect(await shown, isTrue);
      await tester.pump(const Duration(milliseconds: 240));
      final capsule = find
          .ancestor(of: find.text(message), matching: find.byType(Container))
          .first;
      final requiredWidth = tester.getSize(capsule).width;
      QuestCompletionDrawerHost.removeDamageControlNotice(context);
      await tester.pump();
      context = await _mountHost(tester, slotWidth: requiredWidth - 1);
      shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        message,
      );
      await tester.pump();
      expect(await shown, isFalse);
      context = await _mountHost(
        tester,
        slotWidth: requiredWidth.ceilToDouble(),
      );
      shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        message,
      );
      await tester.pump();
      expect(await shown, isTrue);
      QuestCompletionDrawerHost.removeDamageControlNotice(context);
      await tester.pump();
    });
  }

  for (final enlargedText in [false, true]) {
    testWidgets(
      'a displayed notice reports lost readability with large text $enlargedText',
      (tester) async {
        var failures = 0;
        final context = await _mountHost(tester, slotWidth: 600);
        final shown = QuestCompletionDrawerHost.showDamageControlNotice(
          context,
          '大破舰已携带损管',
          onUnavailable: () => failures++,
        );
        await tester.pump();
        expect(await shown, isTrue);
        await tester.pump(const Duration(milliseconds: 240));
        await _mountHost(
          tester,
          slotWidth: enlargedText ? 600 : 20,
          textScale: enlargedText ? 3 : 1,
        );
        await tester.pump();
        expect(failures, 1);
        expect(find.text('大破舰已携带损管'), findsNothing);
        await tester.pump(const Duration(seconds: 20));
        expect(failures, 1);
      },
    );
  }

  testWidgets(
    'native fullscreen falls back when its damage bubble is rejected',
    (tester) async {
      const channel = MethodChannel(
        'app.yahagi.kancollebrowser/game_fullscreen',
      );
      final messages = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        messages.add((call.arguments as Map)['message'] as String);
        throw PlatformException(code: 'unavailable');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final context = await _mountHost(tester, fullscreen: true, native: true);
      final shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
      );
      await tester.pump();
      expect(await shown, isFalse);
      await tester.pumpAndSettle();
      expect(messages.where((message) => message.isNotEmpty), ['大破舰已携带损管']);
      expect(find.text('大破舰已携带损管'), findsNothing);
    },
  );

  testWidgets('an obsolete show cannot remove the replayed notice', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    final first = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      'old',
    );
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    final second = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(find.text('old'), findsNothing);
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    await tester.pump();
  });

  testWidgets('a cached remover stays safe after its context is disposed', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    final remove = QuestCompletionDrawerHost.damageControlNoticeRemover(
      context,
    );
    expect(remove, isNotNull);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    remove!();
    await tester.pump();
    expect(find.text('大破舰已携带损管'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    remove();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cached removal during a descendant build avoids locked notifications',
    (tester) async {
      final context = await _mountHost(tester);
      final remove = QuestCompletionDrawerHost.damageControlNoticeRemover(
        context,
      )!;
      final shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
      );
      await tester.pump();
      expect(await shown, isTrue);
      await _mountHost(tester, duringBuild: remove);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('大破舰已携带损管'), findsNothing);
    },
  );

  testWidgets(
    'a deferred build-time removal cannot clear the subsequent replay',
    (tester) async {
      final context = await _mountHost(tester);
      final remove = QuestCompletionDrawerHost.damageControlNoticeRemover(
        context,
      )!;
      final first = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        'old',
      );
      await tester.pump();
      expect(await first, isTrue);
      late Future<bool> replayed;
      tester.binding.addPostFrameCallback((_) {
        replayed = QuestCompletionDrawerHost.showDamageControlNotice(
          context,
          '大破舰已携带损管',
        );
      });
      await _mountHost(tester, duringBuild: remove);
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(await replayed, isTrue);
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.text('old'), findsNothing);
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      remove();
      await tester.pump();
    },
  );

  testWidgets('show returns false if the slot disappears before rendering', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await _mountHost(tester, withSlot: false);
    expect(await shown, isFalse);
    await tester.pump();
    expect(find.text('大破舰已携带损管'), findsNothing);
  });

  for (final unavailable in ['removed', 'hidden', 'native']) {
    testWidgets(
      'a displayed notice reports when its slot becomes $unavailable',
      (tester) async {
        const channel = MethodChannel(
          'app.yahagi.kancollebrowser/game_fullscreen',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        var failures = 0;
        final context = await _mountHost(tester);
        final shown = QuestCompletionDrawerHost.showDamageControlNotice(
          context,
          '大破舰已携带损管',
          onUnavailable: () => failures++,
        );
        await tester.pump();
        expect(await shown, isTrue);
        await tester.pump(const Duration(milliseconds: 240));
        await _mountHost(
          tester,
          withSlot: unavailable != 'removed',
          hiddenSlot: unavailable == 'hidden',
          fullscreen: unavailable == 'native',
          native: unavailable == 'native',
        );
        await tester.pump();
        expect(failures, 1);
        await tester.pump(const Duration(seconds: 20));
        expect(failures, 1);
        expect(find.text('大破舰已携带损管'), findsNothing);
      },
    );
  }

  testWidgets(
    'unavailable show and normal dismissal do not report a lost slot',
    (tester) async {
      var failures = 0;
      var context = await _mountHost(tester, withSlot: false);
      expect(
        await QuestCompletionDrawerHost.showDamageControlNotice(
          context,
          '大破舰已携带损管',
          onUnavailable: () => failures++,
        ),
        isFalse,
      );
      context = await _mountHost(tester);
      var shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
        onUnavailable: () => failures++,
      );
      await tester.pump();
      expect(await shown, isTrue);
      await tester.pump(const Duration(milliseconds: 240));
      await tester.tap(find.text('大破舰已携带损管'));
      await tester.pump();
      shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
        onUnavailable: () => failures++,
      );
      await tester.pump();
      expect(await shown, isTrue);
      await tester.pump(const Duration(seconds: 10));
      await _mountHost(tester, withSlot: false);
      expect(failures, 0);
    },
  );

  testWidgets('show returns false if the host is disposed before rendering', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await shown, isFalse);
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an outgoing capsule tap cannot close a replayed notice', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    var shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      'old',
    );
    await tester.pump();
    expect(await shown, isTrue);
    final oldTap = tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('old'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!;
    shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    oldTap();
    await tester.pump();
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    await tester.pump();
  });

  testWidgets('quest dismissal and expiry leave damage control visible', (
    tester,
  ) async {
    final context = await _mountHost(tester);
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      '大破舰已携带损管',
    );
    await tester.pump();
    expect(await shown, isTrue);
    QuestCompletionDrawerHost.show(
      context,
      'quest',
      duration: const Duration(seconds: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('quest'), findsNothing);
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.show(context, 'new quest');
    await tester.pumpAndSettle();
    await tester.tap(find.text('new quest'));
    await tester.pumpAndSettle();
    expect(find.text('new quest'), findsNothing);
    expect(find.text('大破舰已携带损管'), findsOneWidget);
    QuestCompletionDrawerHost.removeDamageControlNotice(context);
    await tester.pump();
  });

  testWidgets(
    'replacing the controller preserves damage control and its timer',
    (tester) async {
      final first = TopNoticeController();
      final second = TopNoticeController();
      var failures = 0;
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var context = await _mountHost(tester, controller: first);
      var shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        'old',
        onUnavailable: () => failures++,
      );
      await tester.pump();
      expect(await shown, isTrue);
      await tester.pump(const Duration(seconds: 8));
      context = await _mountHost(tester, controller: second);
      expect(find.text('old'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('old'), findsNothing);
      expect(failures, 0);
      shown = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        '大破舰已携带损管',
      );
      await tester.pump();
      expect(await shown, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('大破舰已携带损管'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('replacing the host controller detaches the previous notices', (
    tester,
  ) async {
    final first = TopNoticeController();
    final second = TopNoticeController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget page(TopNoticeController controller) => MaterialApp(
      home: QuestCompletionDrawerHost(
        controller: controller,
        child: const QuestCompletionHeaderSlot(child: Text('controls')),
      ),
    );
    await tester.pumpWidget(page(first));
    first.show(message: 'old quest', tone: TopNoticeTone.quest);
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(second));
    second.show(message: 'new quest', tone: TopNoticeTone.quest);
    await tester.pumpAndSettle();
    expect(find.text('old quest'), findsNothing);
    expect(find.text('new quest'), findsOneWidget);
    first.hide();
    second.hide();
    await tester.pump();
  });
}

Future<BuildContext> _mountHost(
  WidgetTester tester, {
  TopNoticeController? controller,
  bool toolbarVisible = false,
  bool fullscreen = false,
  bool native = false,
  bool withSlot = true,
  bool hiddenSlot = false,
  double? slotWidth,
  double textScale = 1,
  VoidCallback? duringBuild,
}) async {
  late BuildContext target;
  var pendingBuild = duringBuild;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: QuestCompletionDrawerHost(
          controller: controller,
          fullscreen: fullscreen,
          nativeQuestOverlay: native,
          child: Builder(
            builder: (context) {
              target = context;
              final callback = pendingBuild;
              pendingBuild = null;
              callback?.call();
              return Column(
                children: [
                  if (withSlot)
                    Offstage(
                      offstage: hiddenSlot,
                      child: SizedBox(
                        width: slotWidth ?? double.infinity,
                        height: 44,
                        child: QuestCompletionHeaderSlot(
                          toolbarVisible: toolbarVisible,
                          child: const Text('controls'),
                        ),
                      ),
                    ),
                  const Expanded(child: SizedBox.expand()),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  return target;
}
