import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  testWidgets('shows all eight real resource values', (tester) async {
    const state = GameState(
      resources: <GameResourceType, int>{
        GameResourceType.fuel: 123260,
        GameResourceType.ammunition: 138649,
        GameResourceType.steel: 220250,
        GameResourceType.bauxite: 74349,
        GameResourceType.instantBuild: 799,
        GameResourceType.instantRepair: 708,
        GameResourceType.developmentMaterial: 2249,
        GameResourceType.improvementMaterial: 24,
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 420, child: ResourceGrid(state: state)),
        ),
      ),
    );

    for (final value in <String>[
      '123260',
      '138649',
      '220250',
      '74349',
      '799',
      '708',
      '2249',
      '24',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    for (var id = 1; id <= 8; id++) {
      final path =
          'assets/images/material/${id.toString().padLeft(2, '0')}.png';
      final item = find.byKey(Key('resource-item-$id'));
      final icon = find.byKey(Key('resource-icon-$id'));
      expect(item, findsOneWidget);
      expect(
        tester.getTopLeft(icon).dx - tester.getTopLeft(item).dx,
        lessThanOrEqualTo(10),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == path,
        ),
        findsOneWidget,
      );
    }
    expect(
      tester.getSize(find.byKey(const Key('resource-item-1'))),
      const Size(208, 30),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('resource-item-5'))).dx,
      tester.getTopLeft(find.byKey(const Key('resource-item-1'))).dx,
    );
  });

  testWidgets('uses a dash for resources not captured yet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: ResourceGrid(state: GameState.empty),
          ),
        ),
      ),
    );

    expect(find.text('—'), findsNWidgets(8));
  });

  testWidgets('keeps two columns on a very narrow pane', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ResourceGrid(state: GameState.empty),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('resource-item-1'))).width,
      greaterThan(100),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('resource-item-5'))).dx,
      tester.getTopLeft(find.byKey(const Key('resource-item-1'))).dx,
    );
    expect(tester.takeException(), isNull);
  });
}
