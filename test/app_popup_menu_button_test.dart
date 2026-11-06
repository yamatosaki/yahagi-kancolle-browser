import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/app_popup_menu_button.dart';

Future<void> _open(
  WidgetTester tester, {
  required ValueChanged<int> onSelected,
  required VoidCallback onBackgroundTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBackgroundTap,
          child: Center(
            child: AppPopupMenuButton<int>(
              key: const Key('menu-anchor'),
              initialValue: 2,
              onSelected: onSelected,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('first choice')),
                CheckedPopupMenuItem(
                  value: 2,
                  checked: true,
                  child: Text('selected choice'),
                ),
                PopupMenuItem(
                  value: 3,
                  enabled: false,
                  child: Text('disabled choice'),
                ),
              ],
              child: const SizedBox(
                width: 100,
                height: 48,
                child: Text('open menu'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('menu-anchor')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Escape closes a newly opened menu without choosing an item', (
    tester,
  ) async {
    final selected = <int>[];
    var backgroundTaps = 0;
    await _open(
      tester,
      onSelected: selected.add,
      onBackgroundTap: () => backgroundTaps++,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('first choice'), findsNothing);
    expect(selected, isEmpty);
    await tester.tapAt(const Offset(5, 5));
    expect(backgroundTaps, 1);
  });

  testWidgets('outside taps leave the menu open and its choices usable', (
    tester,
  ) async {
    final selected = <int>[];
    var backgroundTaps = 0;
    await _open(
      tester,
      onSelected: selected.add,
      onBackgroundTap: () => backgroundTaps++,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('first choice'), findsOneWidget);
      expect(selected, isEmpty);
      expect(backgroundTaps, 0);
    }
    await tester.tap(find.text('first choice'));
    await tester.pumpAndSettle();
    expect(selected, [1]);
    expect(find.text('first choice'), findsNothing);
    expect(backgroundTaps, 0);
    await tester.tapAt(const Offset(5, 5));
    expect(backgroundTaps, 1);
  });

  testWidgets(
    'outside multi-touch does not dismiss or poison the next choice',
    (tester) async {
      final selected = <int>[];
      var backgroundTaps = 0;
      await _open(
        tester,
        onSelected: selected.add,
        onBackgroundTap: () => backgroundTaps++,
      );
      final first = await tester.startGesture(const Offset(5, 5), pointer: 81);
      final second = await tester.startGesture(
        const Offset(15, 5),
        pointer: 82,
      );
      await tester.pump(const Duration(seconds: 3));
      await first.up();
      await second.cancel();
      await tester.pump();
      expect(find.text('first choice'), findsOneWidget);
      expect(backgroundTaps, 0);
      await tester.tap(find.text('first choice'));
      await tester.pumpAndSettle();
      expect(selected, [1]);
    },
  );

  testWidgets('disabled choices stay disabled and Back still closes the menu', (
    tester,
  ) async {
    final selected = <int>[];
    var backgroundTaps = 0;
    await _open(
      tester,
      onSelected: selected.add,
      onBackgroundTap: () => backgroundTaps++,
    );
    await tester.tap(find.text('disabled choice'));
    await tester.pumpAndSettle();
    expect(find.text('selected choice'), findsOneWidget);
    expect(selected, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('first choice'), findsNothing);
    expect(selected, isEmpty);
    await tester.tapAt(const Offset(5, 5));
    expect(backgroundTaps, 1);
  });
}
