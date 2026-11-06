import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/app_popup_menu_button.dart';

void main() {
  for (final rtl in [false, true]) {
    testWidgets(
      'long menu respects overlay safe area and scrolls in RTL=$rtl',
      (tester) async {
        tester.view.physicalSize = const Size(240, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.fromLTRB(20, 16, 12, 12)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: AppPopupMenuButton<int>(
                  initialValue: 49,
                  onSelected: (value) => selected = value,
                  itemBuilder: (_) => List.generate(
                    50,
                    (i) => PopupMenuItem(
                      value: i,
                      height: 32,
                      child: Text('choice $i'),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final material = find
            .ancestor(
              of: find.text('choice 0'),
              matching: find.byType(Material),
            )
            .first;
        final rect = tester.getRect(material);
        expect(rect.left, greaterThanOrEqualTo(28));
        expect(rect.right, lessThanOrEqualTo(220));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(180));
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -2500),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('choice 49'));
        await tester.pumpAndSettle();
        expect(selected, 49);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
