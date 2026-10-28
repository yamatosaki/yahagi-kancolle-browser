import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/dashboard_card.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_editing_scope.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/layout/flat_collapse_chevron.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';

void main() {
  for (final style in PanelStyle.values) {
    testWidgets(
      'tab presentation removes the duplicate title and keeps controls: $style',
      (tester) async {
        var collapses = 0;
        var actions = 0;
        var settings = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardPresentationScope(
                tabbed: true,
                child: PanelStyleScope(
                  style: style,
                  child: DashboardCard(
                    title: '出击前检查',
                    icon: const Icon(Icons.shield),
                    collapsed: false,
                    onToggleCollapse: () => collapses++,
                    titleBadge: const Text('准备就绪'),
                    trailing: TextButton(
                      onPressed: () => actions++,
                      child: const Text('海域'),
                    ),
                    headerAction: IconButton(
                      key: const Key('tab-header-settings'),
                      onPressed: () => settings++,
                      icon: const Icon(Icons.settings),
                    ),
                    child: const Text('完整简报内容'),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('完整简报内容'), findsOneWidget);
        expect(find.text('出击前检查'), findsNothing);
        expect(find.byIcon(Icons.shield), findsNothing);
        expect(find.text('准备就绪'), findsOneWidget);
        expect(find.byType(FlatCollapseChevron), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
        await tester.tap(find.text('海域'));
        await tester.tap(find.byKey(const Key('tab-header-settings')));
        expect(actions, 1);
        expect(settings, 1);
        expect(collapses, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tab without controls has no empty header space: $style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          style: style,
          child: DashboardCard(
            title: '建造简报',
            icon: const Icon(Icons.build),
            collapsed: false,
            onToggleCollapse: () {},
            child: const SizedBox(key: Key('tab-body'), height: 20),
          ),
        ),
      );

      expect(find.text('建造简报'), findsNothing);
      expect(find.byIcon(Icons.build), findsNothing);
      final cardTop = tester.getTopLeft(find.byType(DashboardCard)).dy;
      expect(
        tester.getTopLeft(find.byKey(const Key('tab-body'))).dy - cardTop,
        style == PanelStyle.flat ? 0 : 10,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tab controls keep their size in a narrow large-text card: $style',
      (tester) async {
        var selected = false;
        await tester.pumpWidget(
          _host(
            style: style,
            width: 160,
            textScale: 1.8,
            child: DashboardCard(
              title: '很长的模块标题',
              icon: const Icon(Icons.shield),
              collapsed: false,
              onToggleCollapse: () {},
              titleBadge: const SizedBox(
                key: Key('tab-status-badge'),
                width: 100,
                height: 40,
                child: Text('战斗进行中'),
              ),
              trailing: SizedBox(
                key: const Key('tab-mode-control'),
                width: 160,
                height: 48,
                child: TextButton(
                  onPressed: () => selected = true,
                  child: const Text('先知模式'),
                ),
              ),
              child: const Text('战斗内容'),
            ),
          ),
        );

        final control = find.byKey(const Key('tab-mode-control'));
        expect(tester.getRect(control).width, closeTo(160, 0.01));
        expect(tester.getRect(control).height, closeTo(48, 0.01));
        expect(
          find.ancestor(of: control, matching: find.byType(FittedBox)),
          findsNothing,
        );
        await tester.ensureVisible(find.text('先知模式'));
        await tester.tap(find.text('先知模式'));
        expect(selected, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('ordinary cards keep their title logo and collapse: $style', (
      tester,
    ) async {
      var collapses = 0;
      await tester.pumpWidget(
        _host(
          style: style,
          tabbed: false,
          child: DashboardCard(
            title: '普通模块',
            icon: const Icon(Icons.shield),
            collapsed: false,
            collapseButtonKey: const Key('ordinary-card-collapse'),
            onToggleCollapse: () => collapses++,
            child: const Text('内容'),
          ),
        ),
      );

      expect(find.text('普通模块'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      await tester.tap(find.byKey(const Key('ordinary-card-collapse')));
      expect(collapses, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing cards keep their module identity: $style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          style: style,
          child: DashboardEditingScope(
            child: DashboardCard(
              title: '编辑模块',
              icon: const Icon(Icons.shield),
              collapsed: true,
              onToggleCollapse: () {},
              child: const Text('内容'),
            ),
          ),
        ),
      );

      expect(find.text('编辑模块'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.text('内容'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _host({
  required PanelStyle style,
  required Widget child,
  bool tabbed = true,
  double width = 400,
  double textScale = 1,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DashboardPresentationScope(
            tabbed: tabbed,
            child: PanelStyleScope(style: style, child: child),
          ),
        ),
      ),
    ),
  ),
);
