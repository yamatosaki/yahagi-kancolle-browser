import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_filter_panel.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';

Widget _host(Widget child, VoidCallback onBackgroundTap) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Stack(
      children: [
        Positioned(
          right: 0,
          bottom: 0,
          child: TextButton(
            key: const Key('underlying-action'),
            onPressed: onBackgroundTap,
            child: const Text('background'),
          ),
        ),
        Center(child: child),
      ],
    ),
  ),
);

void main() {
  testWidgets(
    'filter outside taps neither close nor reach underlying actions',
    (tester) async {
      var backgroundTaps = 0;
      Map<String, String>? selected;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showLogbookFilterPanel(
                  context: context,
                  anchor: const Rect.fromLTWH(100, 50, 40, 30),
                  title: '筛选',
                  fields: const [
                    LogbookFilterField(
                      keyName: 'kind',
                      label: '类型',
                      options: ['全部', 'A'],
                    ),
                  ],
                  values: const {'kind': '全部'},
                  defaults: const {'kind': '全部'},
                );
              },
              child: const Text('open filter'),
            ),
          ),
          () => backgroundTaps++,
        ),
      );
      await tester.tap(find.text('open filter'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('underlying-action')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logbook-filter-panel')), findsOneWidget);
      expect(backgroundTaps, 0);
      expect(selected, isNull);
      await tester.tap(find.byKey(const Key('logbook-filter-apply')));
      await tester.pumpAndSettle();
      expect(selected, {'kind': '全部'});
      expect(find.byKey(const Key('logbook-filter-panel')), findsNothing);
    },
  );

  testWidgets(
    'settings dropdown blocks outside taps and retains selection and Back',
    (tester) async {
      final controller = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      addTearDown(controller.dispose);
      var backgroundTaps = 0;
      await tester.pumpWidget(
        _host(
          DisplayModeSection(controller: controller),
          () => backgroundTaps++,
        ),
      );
      final dropdown = find.byType(DropdownButton<DisplayMode>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      final portrait = find.text('竖屏');
      expect(portrait, findsOneWidget);
      await tester.tap(
        find.byKey(const Key('underlying-action')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(portrait, findsOneWidget);
      expect(backgroundTaps, 0);
      expect(controller.displayMode, DisplayMode.auto);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(portrait, findsNothing);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(portrait);
      await tester.pumpAndSettle();
      expect(controller.displayMode, DisplayMode.portrait);
    },
  );
}
