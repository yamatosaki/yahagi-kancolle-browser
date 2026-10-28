import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_dashboard_content.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';

void main() {
  for (final style in PanelStyle.values) {
    testWidgets(
      'tab fleet selectors and settings work at narrow width: $style',
      (tester) async {
        final controller = await _controller(
          const GameState(
            fleets: [
              Fleet(id: 1, name: 'First', shipIds: []),
              Fleet(id: 2, name: 'Second', shipIds: []),
              Fleet(id: 3, name: 'Third', shipIds: []),
              Fleet(id: 4, name: 'Fourth', shipIds: []),
            ],
            hasPortData: true,
          ),
        );
        addTearDown(controller.dispose);
        var settings = 0;
        await tester.pumpWidget(
          _host(
            style: style,
            child: FleetSummaryCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenFleet: (_) {},
              onOpenDisplaySettings: () => settings++,
              visible: const {},
              twoColumnVisible: const {},
            ),
          ),
        );

        expect(
          find.text(lookupAppLocalizations(const Locale('en')).fleetBrief),
          findsNothing,
        );
        expect(
          find.byIcon(Icons.directions_boat_filled_outlined),
          findsNothing,
        );
        final selectedColor = _selectorColor(tester, 1);
        for (final id in [2, 3, 4, 1]) {
          final selector = find.byKey(Key('fleet-summary-selector-$id'));
          await tester.ensureVisible(selector);
          await tester.tap(selector);
          await tester.pump();
          expect(_selectorColor(tester, id), selectedColor);
        }
        final gear = find.byKey(const Key('fleet-display-settings-button'));
        await tester.ensureVisible(gear);
        await tester.tap(gear);
        expect(settings, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tab sortie submodes and map controls work at narrow width: $style',
      (tester) async {
        final controller = await _controller(
          GameState(
            hasPortData: true,
            memberMapInfos: {
              105: MemberMapInfo(
                id: 15,
                mapAreaId: 1,
                mapNo: 5,
                name: 'Cleared map',
                requiredDefeatCount: 4,
                defeatCount: 4,
              ),
            },
          ),
        );
        addTearDown(controller.dispose);
        var settings = 0;
        await tester.pumpWidget(
          _host(
            style: style,
            child: PreSortieCheckSummary(
              key: const PageStorageKey('tab-sortie-check'),
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenFleet: (_) {},
              onOpenDisplaySettings: () => settings++,
            ),
          ),
        );

        expect(
          find.text(lookupAppLocalizations(const Locale('en')).preSortieCheck),
          findsNothing,
        );
        expect(find.byIcon(Icons.security_outlined), findsNothing);
        final maps = find.byKey(const Key('sortie-check-mode-maps'));
        await tester.ensureVisible(maps);
        await tester.tap(maps);
        await tester.pump();
        final cleared = find.byKey(const Key('map-gauge-toggle-show-cleared'));
        final checkbox = find.descendant(
          of: cleared,
          matching: find.byIcon(Icons.check_box_outline_blank_outlined),
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
        final gauge = find.byKey(const Key('map-gauge-row-1-5'));
        expect(gauge, findsOneWidget);
        final value = find.descendant(of: gauge, matching: find.text('0 / 4'));
        final gaugeRect = tester.getRect(gauge);
        final valueBox = tester.renderObject<RenderBox>(value);
        final valueRect = Rect.fromPoints(
          valueBox.localToGlobal(Offset.zero),
          valueBox.localToGlobal(valueBox.size.bottomRight(Offset.zero)),
        );
        expect(valueRect.left, greaterThanOrEqualTo(gaugeRect.left - 0.01));
        expect(valueRect.right, lessThanOrEqualTo(gaugeRect.right + 0.01));
        expect(valueRect.top, greaterThanOrEqualTo(gaugeRect.top - 0.01));
        expect(valueRect.bottom, lessThanOrEqualTo(gaugeRect.bottom + 0.01));
        if (style == PanelStyle.card) {
          expect(tester.widget<Text>(value).style?.fontSize, 11);
          expect(
            find.ancestor(of: value, matching: find.byType(FittedBox)),
            findsNothing,
          );
        }

        final gear = find.byKey(
          const Key('pre_sortie-display-settings-button'),
        );
        await tester.ensureVisible(gear);
        await tester.tap(gear);
        expect(settings, 1);
        final ships = find.byKey(const Key('sortie-check-mode-ships'));
        await tester.ensureVisible(ships);
        await tester.tap(ships);
        await tester.pump();
        expect(find.byKey(const Key('map-gauge-row-1-5')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('wide standalone HD sortie card keeps its map information row', (
    tester,
  ) async {
    final controller = await _controller(
      const GameState(
        hasPortData: true,
        memberMapInfos: {
          105: MemberMapInfo(
            id: 15,
            mapAreaId: 1,
            mapNo: 5,
            name: 'Wide map',
            requiredDefeatCount: 4,
            defeatCount: 1,
          ),
        },
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        style: PanelStyle.card,
        tabbed: false,
        width: 720,
        textScale: 1,
        columns: 2,
        child: PreSortieCheckSummary(
          controller: controller,
          collapsed: false,
          onToggleCollapse: () {},
          onOpenFleet: (_) {},
        ),
      ),
    );
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).preSortieCheck),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.security_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
    await tester.pump();

    final gauge = find.byKey(const Key('map-gauge-row-1-5'));
    final name = find.descendant(
      of: gauge,
      matching: find.text('1-5 Wide map'),
    );
    final value = find.descendant(of: gauge, matching: find.text('3 / 4'));
    final category = find.descendant(
      of: gauge,
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.style?.fontSize == 9.5,
      ),
    );
    expect(
      tester.getCenter(name).dy,
      closeTo(tester.getCenter(value).dy, 0.01),
    );
    expect(
      tester.getCenter(category).dy,
      closeTo(tester.getCenter(value).dy, 0.01),
    );
    expect(tester.takeException(), isNull);
  });
}

Color? _selectorColor(WidgetTester tester, int id) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key('fleet-summary-selector-$id')),
        matching: find.byType(Text),
      ),
    )
    .style
    ?.color;

Future<GameStateController> _controller(GameState state) async {
  final controller = GameStateController(gameStateStore: _StaticStore(state));
  await controller.idle;
  return controller;
}

Widget _host({
  required PanelStyle style,
  required Widget child,
  bool tabbed = true,
  double width = 180,
  double textScale = 1.8,
  int columns = 1,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: DashboardPresentationScope(
              tabbed: tabbed,
              // Briefing tabs use the regular single-column card content.
              child: PanelStyleScope(
                style: style,
                child: columns > 1
                    ? HdModuleColumns(columns: columns, child: child)
                    : child,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

class _StaticStore extends GameStateStore {
  _StaticStore(this.state);
  final GameState state;

  @override
  Future<GameState> load() async => state;
}
