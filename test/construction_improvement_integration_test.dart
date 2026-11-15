import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_page.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_check_page.dart';
import 'package:yahagi_kancolle_browser/src/fleet/expedition_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';

void main() {
  testWidgets(
    'construction keeps the development workbench mounted across tabs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = GameStateController();
      addTearDown(controller.dispose);
      var mode = ConstructionCenterMode.development;
      late StateSetter setMode;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setMode = setState;
                return FleetInformationCenter(
                  controller: controller,
                  page: FleetInformationPage.construction,
                  constructionMode: mode,
                  showContextHeader: false,
                );
              },
            ),
          ),
        ),
      );
      final development = find.byType(EquipmentDevelopmentPage);
      final workbench = tester.state(development);

      setMode(() => mode = ConstructionCenterMode.construction);
      await tester.pump();
      expect(development, findsNothing);
      expect(find.byIcon(Icons.radar_outlined), findsOneWidget);

      setMode(() => mode = ConstructionCenterMode.development);
      await tester.pump();
      expect(tester.state(development), same(workbench));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'expedition check keeps its target and accepts an external fleet',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = GameStateController(
        initialState: const GameState(
          hasPortData: true,
          fleets: [
            Fleet(id: 1, name: 'Fleet one', shipIds: [1]),
            Fleet(id: 2, name: 'Fleet two', shipIds: [2]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      var mode = ExpeditionSummaryMode.check;
      var initialFleetId = 1;
      late StateSetter setMode;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setMode = setState;
                return FleetInformationCenter(
                  controller: controller,
                  page: FleetInformationPage.expedition,
                  initialFleetId: initialFleetId,
                  expeditionMode: mode,
                  showContextHeader: false,
                );
              },
            ),
          ),
        ),
      );
      final check = find.byType(ExpeditionCheckPage);
      final target = find.byKey(const Key('expedition-target-menu'));
      final fleetSwitcher = find.descendant(
        of: check,
        matching: find.byType(FleetSwitcherBar),
      );
      await tester.tap(find.text('大成功'));
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(find.text('85%'));
      await tester.pumpAndSettle();
      expect(tester.widget<FleetSwitcherBar>(fleetSwitcher).selectedFleetId, 1);

      setMode(() {
        mode = ExpeditionSummaryMode.summary;
        initialFleetId = 2;
      });
      await tester.pumpAndSettle();
      expect(check, findsNothing);

      setMode(() => mode = ExpeditionSummaryMode.check);
      await tester.pumpAndSettle();
      expect(tester.widget<FleetSwitcherBar>(fleetSwitcher).selectedFleetId, 2);
      expect(
        find.descendant(of: target, matching: find.text('85%')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('development is available without port data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = GameStateController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FleetInformationCenter(
            controller: controller,
            page: FleetInformationPage.construction,
            constructionMode: ConstructionCenterMode.development,
            showContextHeader: false,
          ),
        ),
      ),
    );
    expect(find.byType(EquipmentDevelopmentPage), findsOneWidget);
    expect(find.text('等待母港数据'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'construction header defaults to construction and switches mode',
    (tester) async {
      var mode = ConstructionCenterMode.construction;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: WorkspaceContextHeader(
                workspaceIndex: 4,
                state: const GameState(),
                selectedFleetId: 1,
                constructionMode: mode,
                onConstructionModeChanged: (value) =>
                    setState(() => mode = value),
              ),
            ),
          ),
        ),
      );

      final tabs = find.byKey(const Key('construction-mode-tabs'));
      expect(tester.getSize(tabs), const Size(260, 38));
      expect(
        find.byKey(const Key('construction-mode-construction')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('construction-mode-development')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('construction-mode-improvement')),
        findsOneWidget,
      );
      final construction = tester.getRect(
        find.byKey(const Key('construction-mode-construction')),
      );
      final development = tester.getRect(
        find.byKey(const Key('construction-mode-development')),
      );
      final improvement = tester.getRect(
        find.byKey(const Key('construction-mode-improvement')),
      );
      expect(construction.left, lessThan(development.left));
      expect(development.left, lessThan(improvement.left));
      expect(mode, ConstructionCenterMode.construction);
      expect(
        find.byKey(const Key('development-workbench-mode-tabs')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('construction-mode-development')));
      await tester.pump();
      expect(mode, ConstructionCenterMode.development);
      expect(
        find.byKey(const Key('development-workbench-mode-tabs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('development-mode-calculator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('development-mode-formula')), findsOneWidget);
    },
  );
}
