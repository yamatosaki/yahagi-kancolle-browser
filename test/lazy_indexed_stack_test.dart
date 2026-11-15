import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';
import 'package:yahagi_kancolle_browser/src/widgets/lazy_indexed_stack.dart';

void main() {
  testWidgets('hidden tabs lose focus and reset only when their key changes', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget app(int index, int generation) => MaterialApp(
      home: Scaffold(
        body: LazyIndexedStack(
          index: index,
          children: [
            const Text('game'),
            Builder(
              key: ValueKey(generation),
              builder: (context) => TextField(focusNode: focus),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(app(1, 0));
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.enterText(field, 'keep me');
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(app(0, 0));
    expect(focus.hasFocus, isFalse);
    await tester.pumpWidget(app(1, 0));
    expect(find.text('keep me'), findsOneWidget);

    await tester.pumpWidget(app(0, 1));
    expect(find.byType(TextField, skipOffstage: false), findsNothing);
    await tester.pumpWidget(app(1, 1));
    expect(find.text('keep me'), findsNothing);
  });

  testWidgets('tabs initialize once, retain state, and stop hidden ticks', (
    tester,
  ) async {
    final builds = [0, 0];
    Widget app(int index, String text) => MaterialApp(
      home: LazyIndexedStack(
        index: index,
        children: [
          SecondTickBuilder(
            builder: (context, now, _) {
              builds[0]++;
              return Text(text);
            },
          ),
          SecondTickBuilder(
            builder: (context, now, _) {
              builds[1]++;
              return const Text('second');
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(app(0, 'first'));
    expect(builds[1], 0);
    final firstState = tester.state(find.byType(SecondTickBuilder));
    await tester.pump(const Duration(seconds: 1));
    expect(builds[0], 2);
    await tester.pumpWidget(app(1, 'updated'));
    final hiddenBuilds = builds[0];
    final activeBuilds = builds[1];
    await tester.pump(const Duration(seconds: 1));
    expect(builds[0], hiddenBuilds);
    expect(builds[1], activeBuilds + 1);
    await tester.pumpWidget(app(0, 'updated'));
    expect(tester.state(find.byType(SecondTickBuilder)), same(firstState));
    expect(find.text('updated'), findsOneWidget);
    final resumedBuilds = builds[0];
    await tester.pump(const Duration(seconds: 1));
    expect(builds[0], resumedBuilds + 1);
  });
}
