import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_transport_details.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_transport_points.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  testWidgets('paired details fit five locales and short scaled viewports', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const state = GameState(
      masterShips: {
        1: MasterShip(id: 1, name: 'DD', shipTypeId: 2),
        2: MasterShip(id: 2, name: 'CL', shipTypeId: 3),
      },
      ships: {
        101: OwnedShip(id: 101, masterId: 1, level: 99, slotIds: [401]),
        102: OwnedShip(id: 102, masterId: 2, level: 99),
      },
      slotItems: {401: OwnedSlotItem(instanceId: 401, masterSlotItemId: 576)},
      masterSlotItems: {
        576: MasterSlotItem(id: 576, name: 'R35', type: [0, 0, 24]),
      },
    );
    final points = FleetTransportPoints.fromState(state, [
      const Fleet(id: 1, name: 'Main', shipIds: [101]),
      const Fleet(id: 2, name: 'Escort', shipIds: [102]),
    ])!;

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final size in [
        const Size(320, 640),
        const Size(590, 220),
        const Size(1180, 720),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$locale-$size'),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.25)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: FleetTransportDetails(
                  points: points,
                  builder: (toggle) =>
                      TextButton(onPressed: toggle, child: const Text('Open')),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.fleetTransportPoints), findsOneWidget);
        expect(find.text(l10n.fleetTransportOrdinary), findsOneWidget);
        expect(find.text(l10n.fleetTransportTank), findsOneWidget);
        expect(find.text(l10n.questEligibleFleetFirst), findsNWidgets(2));
        expect(find.text(l10n.questEligibleFleetSecond), findsNWidgets(2));
        expect(
          find.text(l10n.fleetTransportRankValues(15, 10)),
          findsOneWidget,
        );
        final tankTotal = find.text(l10n.fleetTransportRankValues(28, 19));
        await tester.ensureVisible(tankTotal);
        await tester.pumpAndSettle();
        expect(tankTotal.hitTestable(), findsOneWidget);
        expect(find.textContaining('2026'), findsNothing);
        expect(tester.takeException(), isNull, reason: '$locale at $size');

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('fleet-transport-details-popover')),
          findsNothing,
        );
      }
    }
  });
}
