import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  test('an explicitly batched notice appends without a time window', () {
    final controller = TopNoticeController();
    addTearDown(controller.dispose);
    controller.show(message: '舰队有大破舰');
    controller.show(message: '舰队尚未补给', appendToCurrentBatch: true);

    expect(controller.notices.map((notice) => notice.message), [
      '舰队有大破舰',
      '舰队尚未补给',
    ]);
  });

  Widget buildApp({
    required Widget child,
    Size size = const Size(400, 800),
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MaterialApp(
          builder: (context, materialChild) => MediaQuery(
            data: MediaQueryData(size: size, padding: padding),
            child: materialChild!,
          ),
          home: Scaffold(body: TopNoticeHost(child: child)),
        ),
      ),
    );
  }

  Future<void> showNotice(
    WidgetTester tester, {
    String message = '舰队准备完成',
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
    Size size = const Size(400, 800),
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.pumpWidget(
      buildApp(
        size: size,
        padding: padding,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => TopNotice.show(
              context,
              message: message,
              tone: tone,
              duration: duration,
            ),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
  }

  testWidgets('uses the safe-area top inset and stays horizontally centered', (
    tester,
  ) async {
    await showNotice(
      tester,
      padding: const EdgeInsets.only(top: 24),
      size: const Size(800, 600),
    );
    expect(tester.getRect(find.byKey(topNoticeKey)).top, lessThan(28));
    await tester.pump(const Duration(milliseconds: 180));

    final rect = tester.getRect(find.byKey(topNoticeKey));
    expect(rect.top, 28);
    expect(rect.center.dx, 400);
    expect(rect.width, lessThanOrEqualTo(720));
    expect(rect.height, greaterThanOrEqualTo(36));
  });

  testWidgets(
    'provides Material text styling in the production host topology',
    (tester) async {
      late BuildContext noticeContext;
      await tester.pumpWidget(
        MaterialApp(
          home: TopNoticeHost(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  noticeContext = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      TopNotice.show(noticeContext, message: 'compact notice');
      await tester.pump();

      final materialAncestors = find.ancestor(
        of: find.byKey(topNoticeTextKey),
        matching: find.byType(Material),
      );
      expect(materialAncestors, findsWidgets);
      final text = tester.widget<Text>(find.byKey(topNoticeTextKey));
      expect(text.style?.fontSize, 14);
      expect(text.style?.decoration, TextDecoration.none);
    },
  );

  testWidgets(
    'keeps toolbar capsule height and truncates long text to one line',
    (tester) async {
      const message = '这是一个很长很长的提示文案，用于确认窄屏设备不会发生水平溢出，并且文本最多只显示两行。';
      await showNotice(tester, message: message, size: const Size(240, 600));

      final noticeRect = tester.getRect(find.byKey(topNoticeKey));
      expect(noticeRect.left, greaterThanOrEqualTo(16));
      expect(noticeRect.right, lessThanOrEqualTo(224));
      expect(noticeRect.height, 36);
      final text = tester.widget<Text>(find.byKey(topNoticeTextKey));
      expect(text.maxLines, 1);
      expect(text.style?.fontSize, 14);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses four seconds by default and then animates out', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => TopNotice.show(context, message: 'default'),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 3999));
    expect(find.text('default'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 141));
    expect(find.text('default'), findsNothing);
  });

  testWidgets('honors an explicit display duration', (tester) async {
    await showNotice(
      tester,
      message: 'brief',
      duration: const Duration(milliseconds: 250),
    );

    await tester.pump(const Duration(milliseconds: 249));
    expect(find.text('brief'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 141));
    expect(find.text('brief'), findsNothing);
  });

  testWidgets('a new message replaces the old one and owns its timer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    late BuildContext noticeContext;
    await tester.pumpWidget(
      buildApp(
        child: Builder(
          builder: (context) {
            noticeContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    TopNotice.show(
      noticeContext,
      message: 'first',
      duration: const Duration(milliseconds: 300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    TopNotice.show(
      noticeContext,
      message: 'second',
      duration: const Duration(milliseconds: 400),
    );
    await tester.pump();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(find.bySemanticsLabel('first'), findsNothing);
    final secondSemantics = tester.getSemantics(
      find.bySemanticsLabel('second'),
    );
    expect(secondSemantics.label, 'second');
    expect(secondSemantics.flagsCollection.isLiveRegion, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 141));
    expect(find.text('second'), findsNothing);
    semantics.dispose();
  });

  for (final entry in <(TopNoticeTone, IconData, Color, Color, Color)>[
    (
      TopNoticeTone.neutral,
      Icons.info_outline_rounded,
      const Color(0xff1a3447),
      const Color(0xff3c586b),
      Colors.white,
    ),
    (
      TopNoticeTone.success,
      Icons.check_circle_outline_rounded,
      const Color(0xff173d3b),
      const Color(0xff4fa79b),
      const Color(0xffb9f1e8),
    ),
    (
      TopNoticeTone.error,
      Icons.error_outline_rounded,
      const Color(0xff54292d),
      const Color(0xff9b464c),
      const Color(0xffffaaa4),
    ),
  ]) {
    testWidgets('${entry.$1.name} uses its specified icon and colors', (
      tester,
    ) async {
      await showNotice(tester, tone: entry.$1);

      expect(find.byIcon(entry.$2), findsOneWidget);
      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(topNoticeKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, entry.$3);
      expect((decoration.border! as Border).top.color, entry.$4);
      expect(tester.widget<Icon>(find.byIcon(entry.$2)).color, entry.$5);
      expect(
        tester.widget<Text>(find.byKey(topNoticeTextKey)).style?.color,
        entry.$5,
      );
    });
  }

  testWidgets('announces the full message as a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    const message = '完整的无障碍提示文案';
    await showNotice(tester, message: message);
    await tester.pump(const Duration(milliseconds: 180));

    final node = tester.getSemantics(find.bySemanticsLabel(message));
    expect(node.label, message);
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets(
    'hide removes the notice and its old timer cannot affect a new one',
    (tester) async {
      late BuildContext noticeContext;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              noticeContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      TopNotice.show(
        noticeContext,
        message: 'hidden early',
        duration: const Duration(milliseconds: 300),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      TopNotice.hide(noticeContext);
      await tester.pump();
      expect(find.text('hidden early'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 141));
      expect(find.text('hidden early'), findsNothing);

      TopNotice.show(
        noticeContext,
        message: 'new notice',
        duration: const Duration(milliseconds: 500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 59));
      expect(find.text('new notice'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 440));
      expect(find.text('new notice'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 141));
      expect(find.text('new notice'), findsNothing);
    },
  );

  testWidgets(
    'a notice shown during hide exit immediately replaces the outgoing notice',
    (tester) async {
      final semantics = tester.ensureSemantics();
      late BuildContext noticeContext;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              noticeContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      TopNotice.show(
        noticeContext,
        message: 'outgoing old',
        duration: const Duration(milliseconds: 300),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));

      TopNotice.hide(noticeContext);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(find.text('outgoing old'), findsOneWidget);

      TopNotice.show(
        noticeContext,
        message: 'current new',
        duration: const Duration(milliseconds: 400),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('outgoing old'), findsNothing);
      expect(find.text('current new'), findsOneWidget);
      expect(find.byKey(topNoticeKey), findsOneWidget);
      expect(find.bySemanticsLabel('outgoing old'), findsNothing);
      final currentSemantics = tester.getSemantics(
        find.bySemanticsLabel('current new'),
      );
      expect(currentSemantics.label, 'current new');
      expect(currentSemantics.flagsCollection.isLiveRegion, isTrue);

      await tester.pump(const Duration(milliseconds: 49));
      expect(find.text('current new'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 349));
      expect(find.text('current new'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 141));
      expect(find.text('current new'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('does not intercept taps intended for content underneath', (
    tester,
  ) async {
    var taps = 0;
    late BuildContext noticeContext;
    await tester.pumpWidget(
      buildApp(
        child: Builder(
          builder: (context) {
            noticeContext = context;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
    TopNotice.show(noticeContext, message: 'tap through');
    await tester.pump();

    final ignorePointers = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(topNoticeKey),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(ignorePointers.any((widget) => widget.ignoring), isTrue);
    await tester.tapAt(tester.getCenter(find.byKey(topNoticeKey)));
    expect(taps, 1);
  });

  testWidgets('disposing the host cancels its pending timer', (tester) async {
    await showNotice(tester, duration: const Duration(minutes: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));

    expect(tester.takeException(), isNull);
  });
}
