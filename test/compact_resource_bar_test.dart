import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/layout/display_corners.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Future<void> _revealChecklistRow(WidgetTester tester, String id) async {
  final list = find.byKey(const Key('header-resource-filter-list'));
  await tester.scrollUntilVisible(
    find.byKey(Key('header-resource-filter-row-$id')),
    60,
    scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('furniture coin is hidden by default and can be enabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    const state = GameState(furnitureCoins: 183854, hasFurnitureCoinData: true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: state,
            settingsController: controller,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('header-resource-furniture-coin')),
      findsNothing,
    );

    await controller.toggleHeaderResourceVisible(headerFurnitureCoinId);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('header-resource-list')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('header-resource-furniture-coin')),
      findsOneWidget,
    );
    expect(find.text('183854'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/material/useitem_44.png',
      ),
      findsOneWidget,
    );
    final coin = find.byKey(const Key('header-resource-furniture-coin'));
    final coinImage = tester.widget<Image>(
      find.descendant(of: coin, matching: find.byType(Image)),
    );
    final valueScaler = tester.widget<FittedBox>(
      find.descendant(of: coin, matching: find.byType(FittedBox)),
    );
    expect(coinImage.fit, BoxFit.contain);
    expect(valueScaler.fit, BoxFit.scaleDown);
    expect(valueScaler.clipBehavior, Clip.hardEdge);
    expect(tester.takeException(), isNull);
  });

  testWidgets('furniture coin uses a dash before api_fcoin is captured', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.toggleHeaderResourceVisible(headerFurnitureCoinId);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: GameState.empty,
            settingsController: controller,
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('header-resource-list')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    final coin = find.byKey(const Key('header-resource-furniture-coin'));
    expect(coin, findsOneWidget);
    expect(find.descendant(of: coin, matching: find.text('—')), findsOneWidget);
  });

  testWidgets('furniture coin toggles the theoretical total from boxes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.toggleHeaderResourceVisible(headerFurnitureCoinId);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(
              furnitureCoins: 183854,
              hasFurnitureCoinData: true,
              useItems: <int, int>{10: 12, 11: 7, 12: 3},
              hasUseItemData: true,
            ),
            settingsController: controller,
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('header-resource-list')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    final coin = find.byKey(const Key('header-resource-furniture-coin'));
    expect(
      find.descendant(of: coin, matching: find.text('183854')),
      findsOneWidget,
    );

    await tester.tap(coin);
    await tester.pump();

    expect(
      find.descendant(of: coin, matching: find.text('≈191154')),
      findsOneWidget,
    );
    final coinIcon = tester.widget<Image>(
      find.descendant(of: coin, matching: find.byType(Image)),
    );
    expect(
      (coinIcon.image as AssetImage).assetName,
      'assets/images/material/useitem_44.png',
    );

    await tester.tap(coin);
    await tester.pump();

    expect(
      find.descendant(of: coin, matching: find.text('183854')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('theoretical furniture coin total waits for box data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.toggleHeaderResourceVisible(headerFurnitureCoinId);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(
              furnitureCoins: 183854,
              hasFurnitureCoinData: true,
            ),
            settingsController: controller,
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('header-resource-list')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    final coin = find.byKey(const Key('header-resource-furniture-coin'));
    await tester.tap(coin);
    await tester.pump();

    expect(find.descendant(of: coin, matching: find.text('—')), findsOneWidget);
    expect(find.textContaining('≈'), findsNothing);
  });

  testWidgets('furniture boxes independently toggle coin equivalents', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    for (final id in <String>['useitem-10', 'useitem-11', 'useitem-12']) {
      await controller.toggleHeaderResourceVisible(id);
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(
              useItems: <int, int>{10: 999, 11: 7, 12: 3},
              hasUseItemData: true,
            ),
            settingsController: controller,
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('header-resource-list')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    final small = find.byKey(const Key('header-resource-useitem-10'));
    final medium = find.byKey(const Key('header-resource-useitem-11'));
    final large = find.byKey(const Key('header-resource-useitem-12'));
    expect(
      find.descendant(of: small, matching: find.text('999')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: medium, matching: find.text('7')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: large, matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(small);
    await tester.tap(medium);
    await tester.tap(large);
    await tester.pump();

    expect(
      find.descendant(of: small, matching: find.text('199800币')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: medium, matching: find.text('2800币')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: large, matching: find.text('2100币')),
      findsOneWidget,
    );
    final smallIcon = tester.widget<Image>(
      find.descendant(of: small, matching: find.byType(Image)),
    );
    expect(
      (smallIcon.image as AssetImage).assetName,
      'assets/images/material/10.png',
    );

    await tester.tap(small);
    await tester.pump();

    expect(
      find.descendant(of: small, matching: find.text('999')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: medium, matching: find.text('2800币')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: large, matching: find.text('2100币')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('furniture box coin mode keeps a dash before data is captured', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.toggleHeaderResourceVisible('useitem-10');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: GameState.empty,
            settingsController: controller,
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('header-resource-list')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    final small = find.byKey(const Key('header-resource-useitem-10'));
    await tester.tap(small);
    await tester.pump();

    expect(
      find.descendant(of: small, matching: find.text('—')),
      findsOneWidget,
    );
    expect(find.textContaining('币'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('frame refresh capsule defaults hidden and becomes actionable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    var refreshCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(),
            settingsController: controller,
            onFrameRefreshTap: () => refreshCalls += 1,
          ),
        ),
      ),
    );

    expect(
      defaultVisibleHeaderResourceIds,
      isNot(contains(headerFrameRefreshId)),
    );
    expect(
      find.byKey(const Key('header-resource-frame-refresh')),
      findsNothing,
    );
    await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
    await tester.pump();
    final refresh = find.byKey(const Key('header-resource-frame-refresh'));
    expect(refresh, findsOneWidget);
    expect(find.text('框架刷新'), findsOneWidget);
    expect(tester.getSize(refresh).width, 98);
    await tester.tap(refresh);
    expect(refreshCalls, 1);
  });

  test('formats anchorage repair elapsed time for the header capsule', () {
    final startedAt = DateTime.utc(2026, 8, 11, 1, 2, 3);

    expect(
      formatAnchorageRepairElapsed(
        startedAt,
        DateTime.utc(2026, 8, 11, 14, 7, 9),
      ),
      '13:05:06',
    );
    expect(
      formatAnchorageRepairElapsed(null, DateTime.utc(2026, 8, 11)),
      '--:--:--',
    );
    expect(
      formatAnchorageRepairElapsed(
        startedAt,
        DateTime.utc(2026, 8, 11, 1, 2, 2),
      ),
      '00:00:00',
    );
  });

  test('formats nosaki sparkle elapsed time for the header capsule', () {
    final startedAt = DateTime.utc(2026, 8, 11, 1, 2, 3);

    expect(
      formatNosakiSparkleElapsed(
        startedAt,
        DateTime.utc(2026, 8, 11, 14, 7, 9),
      ),
      '13:05:06',
    );
    expect(
      formatNosakiSparkleElapsed(null, DateTime.utc(2026, 8, 11)),
      '--:--:--',
    );
    expect(
      formatNosakiSparkleElapsed(startedAt, DateTime.utc(2026, 8, 11, 1, 2, 2)),
      '00:00:00',
    );
  });

  testWidgets('narrow header keeps the empty senka capsule visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: CompactResourceBar(state: GameState()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('战果：--（#--）'), findsOneWidget);
    expect(find.text('泊地：--:--:--'), findsOneWidget);
    expect(
      find.byKey(const Key('header-anchorage-timer-summary')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('header renders nosaki capsule with empty timer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              child: CompactResourceBar(state: GameState()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('野埼：--:--:--'), findsOneWidget);
    expect(
      find.byKey(const Key('header-nosaki-timer-summary')),
      findsOneWidget,
    );
  });

  testWidgets('anchorage capsule invokes tap without breaking long press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(),
            onAnchorageTimerTap: () => taps++,
          ),
        ),
      ),
    );

    final timer = find.byKey(const Key('header-resource-anchorage-timer'));
    await tester.tap(timer);
    await tester.pump();
    expect(taps, 1);

    await tester.longPress(timer);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
  });

  testWidgets('nosaki capsule invokes tap without breaking long press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(),
            onNosakiTimerTap: () => taps++,
          ),
        ),
      ),
    );

    final timer = find.byKey(const Key('header-resource-nosaki-timer'));
    await tester.tap(timer);
    await tester.pump();
    expect(taps, 1);

    await tester.longPress(timer);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
  });

  testWidgets('starts at the leading edge and long press enters edit mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    const state = GameState(
      resources: <GameResourceType, int>{GameResourceType.fuel: 12345},
    );
    var senkaTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(left: 48)),
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 600,
                  child: CompactResourceBar(
                    state: state,
                    senka: 1120,
                    rank: 370,
                    settingsController: controller,
                    onSenkaTap: () => senkaTapCount += 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final senka = find.byKey(const Key('header-senka-summary'));
    expect(senka, findsOneWidget);
    expect(find.text('战果：1120（#370）'), findsOneWidget);
    expect(tester.getTopLeft(senka).dx, 0);
    final senkaDecoration =
        tester.widget<Container>(senka).decoration! as BoxDecoration;
    final senkaBorder = senkaDecoration.border! as Border;
    expect(senkaBorder.top.color, const Color(0xff315064));

    final first = find.byKey(const Key('header-resource-ship-capacity'));
    expect(first, findsOneWidget);
    expect(
      find.byKey(const Key('header-resource-anchorage-timer')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(first).dx,
      greaterThan(tester.getRect(senka).right),
    );
    expect(find.byKey(const Key('header-resource-useitem-68')), findsNothing);

    await tester.tap(find.byKey(const Key('header-resource-senka')));
    await tester.pump();
    expect(senkaTapCount, 1);
    await tester.tap(first);
    await tester.pump();
    expect(senkaTapCount, 1);

    await tester.longPress(senka);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
    expect(find.byKey(const Key('header-resource-filter')), findsOneWidget);
    final resetX = tester
        .getTopLeft(find.byKey(const Key('header-resource-reset')))
        .dx;
    final doneX = tester
        .getTopLeft(find.byKey(const Key('header-resource-edit-done')))
        .dx;
    final filterX = tester
        .getTopLeft(find.byKey(const Key('header-resource-filter')))
        .dx;
    expect(resetX, lessThan(doneX));
    expect(doneX, lessThan(filterX));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('header-resource-filter')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('header-resource-filter-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-senka')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-senka')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-anchorage-timer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-anchorage-timer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-ship-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-ship-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-filter-row-equipment-capacity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('header-resource-visible-equipment-capacity')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('header-resource-visible-senka')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('header-resource-visible-ship-capacity')),
    );
    await tester.pump();

    await _revealChecklistRow(tester, 'material-1');
    final firstFilterRow = find.byKey(
      const Key('header-resource-filter-row-material-1'),
    );
    final secondFilterRow = find.byKey(
      const Key('header-resource-filter-row-material-2'),
    );
    expect(
      tester.getTopLeft(firstFilterRow).dx,
      tester.getTopLeft(secondFilterRow).dx,
    );
    expect(
      tester.getTopLeft(secondFilterRow).dy,
      greaterThan(tester.getTopLeft(firstFilterRow).dy),
    );
    expect(
      find.byKey(const Key('header-resource-visible-material-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('header-resource-filter-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-resource-edit-done')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('header-senka-summary')), findsNothing);
    expect(find.byKey(const Key('header-ship-capacity')), findsNothing);
    expect(find.byKey(const Key('header-resource-material-1')), findsOneWidget);
    expect(find.byKey(const Key('header-resource-material-2')), findsOneWidget);
  });

  testWidgets(
    'header shows --:--:-- for anchorage when damaged, while nosaki shows continuous timer when started',
    (tester) async {
      final startedAt = DateTime.utc(2026, 8, 20, 10);
      // Damaged Akashi (hp 10/45 <= 50%) and damaged Nozaki (hp 30/48 < max)
      const damagedState = GameState(
        fleets: <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
        ],
        ships: <int, OwnedShip>{
          1: OwnedShip(
            id: 1,
            masterId: 187,
            level: 80,
            currentHp: 10,
            maxHp: 45,
          ), // Akashi heavy damage
          2: OwnedShip(
            id: 2,
            masterId: 1002,
            level: 80,
            currentHp: 30,
            maxHp: 48,
            currentFuel: 100,
            currentAmmo: 100,
          ), // Nozaki damaged
        },
        masterShips: <int, MasterShip>{
          187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
          1002: MasterShip(
            id: 1002,
            name: '野埼改',
            shipTypeId: 22,
            maxFuel: 100,
            maxAmmo: 100,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CompactResourceBar(
              state: damagedState,
              anchorageRepairStartedAt: startedAt,
              nosakiSparkleStartedAt: startedAt,
            ),
          ),
        ),
      );

      expect(find.text('泊地：--:--:--'), findsOneWidget);
      expect(find.text('野埼：--:--:--'), findsNothing);
    },
  );

  testWidgets(
    'header shows active elapsed time when Akashi and Nozaki are ready',
    (tester) async {
      final startedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 10),
      );
      const readyState = GameState(
        fleets: <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
        ],
        ships: <int, OwnedShip>{
          1: OwnedShip(
            id: 1,
            masterId: 187,
            level: 80,
            currentHp: 45,
            maxHp: 45,
          ),
          2: OwnedShip(
            id: 2,
            masterId: 1002,
            level: 80,
            currentHp: 48,
            maxHp: 48,
            currentFuel: 100,
            currentAmmo: 100,
            condition: 49,
          ),
        },
        masterShips: <int, MasterShip>{
          187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
          1002: MasterShip(
            id: 1002,
            name: '野埼改',
            shipTypeId: 22,
            maxFuel: 100,
            maxAmmo: 100,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CompactResourceBar(
              state: readyState,
              anchorageRepairStartedAt: startedAt,
              nosakiSparkleStartedAt: startedAt,
            ),
          ),
        ),
      );

      expect(find.text('泊地：--:--:--'), findsNothing);
      expect(find.text('野埼：--:--:--'), findsNothing);
      expect(find.textContaining('泊地：00:10:'), findsOneWidget);
      expect(find.textContaining('野埼：00:10:'), findsOneWidget);
    },
  );

  testWidgets('compact header UI size adjusts bar height and pill sizes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.setHeaderUiSize(HeaderUiSize.compact);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            state: const GameState(),
            settingsController: controller,
          ),
        ),
      ),
    );

    // Verify fuel capsule width is 74 and height is 26 in compact mode
    final fuelPill = find.byKey(const Key('header-resource-material-1'));
    expect(fuelPill, findsOneWidget);
    expect(tester.getSize(fuelPill).height, 26);
    expect(tester.getSize(fuelPill).width, 74);
  });

  testWidgets(
    'flat topbar removes capsules and keeps original resource icons',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      await controller.setUiDisplaySize(UiDisplaySize.compact);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CompactResourceBar(
              state: const GameState(),
              settingsController: controller,
              flatStyle: true,
            ),
          ),
        ),
      );

      final item = find.byKey(const Key('header-resource-material-1'));
      expect(item, findsOneWidget);
      expect(tester.getSize(item), const Size(74, 26));
      final icon = tester.widget<Image>(
        find.descendant(of: item, matching: find.byType(Image)),
      );
      expect(
        (icon.image as AssetImage).assetName,
        'assets/images/material/01.png',
      );
      expect(icon.width, 15);
      expect(icon.height, 15);
      final decorations = <Decoration?>[
        for (final box in tester.widgetList<Container>(
          find.descendant(of: item, matching: find.byType(Container)),
        ))
          box.decoration,
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(of: item, matching: find.byType(DecoratedBox)),
        ))
          box.decoration,
      ];
      for (final decoration in decorations) {
        expect(decoration is BoxDecoration ? decoration.border : null, isNull);
        expect(decoration is BoxDecoration ? decoration.color : null, isNull);
      }
      final divider = find.byKey(
        const Key('header-resource-divider-before-anchorage-timer'),
      );
      expect(divider, findsOneWidget);
      expect(tester.getSize(divider), const Size(1, 14));
      expect(
        find.byKey(const Key('header-resource-divider-before-senka')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('flat topbar preserves actions, filtering and custom order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 350);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    const selectedIds = <String>[
      headerSenkaId,
      headerAnchorageTimerId,
      headerNosakiTimerId,
      headerFrameRefreshId,
      headerFurnitureCoinId,
      'material-1',
    ];
    await controller.setUiDisplaySize(UiDisplaySize.compact);
    await controller.setHeaderResourceOrder(selectedIds);
    for (final id in allHeaderResourceIds) {
      if (controller.visibleHeaderResourceIds.contains(id) !=
          selectedIds.contains(id)) {
        await controller.toggleHeaderResourceVisible(id);
      }
    }
    var senkaTaps = 0;
    var anchorageTaps = 0;
    var nosakiTaps = 0;
    var refreshTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CompactResourceBar(
            flatStyle: true,
            state: const GameState(
              furnitureCoins: 183854,
              hasFurnitureCoinData: true,
              useItems: <int, int>{10: 12, 11: 7, 12: 3},
              hasUseItemData: true,
            ),
            settingsController: controller,
            onSenkaTap: () => senkaTaps++,
            onAnchorageTimerTap: () => anchorageTaps++,
            onNosakiTimerTap: () => nosakiTaps++,
            onFrameRefreshTap: () => refreshTaps++,
          ),
        ),
      ),
    );
    Finder item(String id) => find.byKey(Key('header-resource-$id'));
    Finder dividers() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'header-resource-divider-before-',
          ),
    );
    expect(dividers(), findsNWidgets(selectedIds.length - 1));
    for (final id in selectedIds.take(4)) {
      await tester.tap(item(id));
      await tester.pump();
    }
    expect([senkaTaps, anchorageTaps, nosakiTaps, refreshTaps], [1, 1, 1, 1]);
    await tester.tap(item(headerFurnitureCoinId));
    await tester.pump();
    expect(find.text('≈191154'), findsOneWidget);

    await tester.longPress(item(headerSenkaId));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
    final reorder = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorder.onReorderItem!(
      controller.headerResourceOrder.indexOf('material-1'),
      0,
    );
    await tester.pumpAndSettle();
    expect(controller.headerResourceOrder.first, 'material-1');
    await tester.tap(find.byKey(const Key('header-resource-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-resource-visible-senka')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('header-resource-filter-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-resource-edit-done')));
    await tester.pumpAndSettle();
    expect(item(headerSenkaId), findsNothing);
    expect(dividers(), findsNWidgets(selectedIds.length - 2));
    expect(
      find.byKey(const Key('header-resource-divider-before-material-1')),
      findsNothing,
    );
    expect(
      tester.getRect(item('material-1')).right,
      lessThan(tester.getRect(item(headerAnchorageTimerId)).left),
    );
    expect(find.text('≈191154'), findsOneWidget);

    for (final id in selectedIds.skip(1).take(4)) {
      await controller.toggleHeaderResourceVisible(id);
    }
    await tester.pump();
    expect(dividers(), findsNothing);
    expect(item('material-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<LayoutSettingsController> loadGridController() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
  }

  Widget gridHarness(
    LayoutSettingsController controller, {
    double width = 200,
    double? senka,
    int? rank,
    GameState state = const GameState(),
    Locale locale = const Locale('zh'),
    EdgeInsets gridPadding = EdgeInsets.zero,
    ({double left, double right}) cornerRadii = (left: 0, right: 0),
    String? fontFamily,
    double textScale = 1,
    DateTime? timersStartedAt,
    VoidCallback? onAnchorageTimerTap,
    VoidCallback? onNosakiTimerTap,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: fontFamily == null ? null : ThemeData(fontFamily: fontFamily),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: TopNoticeHost(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: CompactResourceBar(
                state: state,
                senka: senka,
                rank: rank ?? (senka == null ? null : 123),
                anchorageRepairStartedAt: timersStartedAt,
                nosakiSparkleStartedAt: timersStartedAt,
                onAnchorageTimerTap: onAnchorageTimerTap,
                onNosakiTimerTap: onNosakiTimerTap,
                settingsController: controller,
                layout: ResourceBarLayout.grid,
                gridPadding: gridPadding,
                gridCornerRadii: cornerRadii,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('grid layout wraps visible resources into 4 columns', (
    tester,
  ) async {
    final controller = await loadGridController();
    await tester.pumpWidget(gridHarness(controller));

    expect(
      find.byKey(const Key('information-panel-resources')),
      findsOneWidget,
    );
    final first = tester.getTopLeft(
      find.byKey(const Key('header-resource-material-1')),
    );
    final fourth = tester.getTopLeft(
      find.byKey(const Key('header-resource-material-4')),
    );
    final fifth = tester.getTopLeft(
      find.byKey(const Key('header-resource-material-5')),
    );
    expect(fourth.dy, first.dy);
    expect(fourth.dx, greaterThan(first.dx));
    expect(fifth.dx, first.dx);
    expect(fifth.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });

  const richState = GameState(
    resources: <GameResourceType, int>{
      GameResourceType.fuel: 146449,
      GameResourceType.ammunition: 159378,
      GameResourceType.steel: 157012,
      GameResourceType.bauxite: 143589,
      GameResourceType.instantBuild: 771,
      GameResourceType.instantRepair: 889,
      GameResourceType.developmentMaterial: 501,
      GameResourceType.improvementMaterial: 11,
    },
    maxShipCount: 750,
    maxEquipmentCount: 3431,
    hasPortData: true,
  );

  testWidgets('grid flows wide items by width and plain items four per row', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    await tester.pumpWidget(
      gridHarness(controller, width: 250, senka: 3128, state: richState),
    );

    expect(tester.takeException(), isNull);
    Offset topLeft(String key) => tester.getTopLeft(find.byKey(Key(key)));
    Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
    final senka = topLeft('header-senka-summary');
    final anchorage = topLeft('header-anchorage-timer-summary');
    final nosaki = topLeft('header-nosaki-timer-summary');
    final ships = topLeft('header-ship-capacity');
    final equipment = topLeft('header-equipment-capacity');
    // 测试字体每字 1em：战果 10 字、两个空闲计时器各 2 字能挤进一行。
    expect(anchorage.dy, senka.dy);
    expect(nosaki.dy, senka.dy);
    expect(anchorage.dx, greaterThan(senka.dx));
    expect(nosaki.dx, greaterThan(anchorage.dx));
    expect(ships.dy, greaterThan(senka.dy));
    expect(equipment.dy, ships.dy);
    expect(ships.dx, senka.dx);
    expect(equipment.dx, greaterThan(ships.dx));
    // 每行排完后把余量平分，行仍满宽。
    expect(senka.dx, 0);
    expect(rect('header-nosaki-timer-summary').right, closeTo(250, 0.01));
    expect(rect('header-equipment-capacity').right, closeTo(250, 0.01));

    final m1 = topLeft('header-resource-material-1');
    expect(m1.dy, greaterThan(equipment.dy));
    for (final id in [2, 3, 4]) {
      expect(topLeft('header-resource-material-$id').dy, m1.dy);
    }
    final m5 = topLeft('header-resource-material-5');
    expect(m5.dx, m1.dx);
    expect(m5.dy, greaterThan(m1.dy));
    for (final id in [6, 7, 8]) {
      expect(topLeft('header-resource-material-$id').dy, m5.dy);
    }
    expect(
      tester.getSize(find.byKey(const Key('information-panel-resources'))),
      isA<Size>().having((s) => s.height, 'height', lessThanOrEqualTo(5 * 22)),
    );
  });

  testWidgets('grid keeps the toggle whole when no row is left', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    for (var id = 1; id <= 8; id++) {
      await controller.toggleHeaderResourceVisible('material-$id');
    }
    const padding = EdgeInsets.fromLTRB(8, 6, 8, 2);
    await tester.pumpWidget(
      gridHarness(
        controller,
        width: 250,
        senka: 3128,
        state: richState,
        gridPadding: padding,
      ),
    );
    final toggle = find.byKey(const Key('information-panel-resources-toggle'));
    final resources = find.byKey(const Key('information-panel-resources'));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-senka-summary')), findsNothing);
    final area = tester.getRect(resources);
    final box = tester.getRect(toggle);
    expect(box.size, const Size(24, 24));
    expect(box.top, greaterThanOrEqualTo(area.top));
    expect(box.bottom, lessThanOrEqualTo(area.bottom));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-senka-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'grid uses the full width and overlays the toggle on the last row',
    (tester) async {
      final controller = await loadGridController();
      await controller.setUiDisplaySize(UiDisplaySize.minimal);
      const padding = EdgeInsets.fromLTRB(8, 6, 8, 2);
      await tester.pumpWidget(
        gridHarness(
          controller,
          width: 250,
          senka: 3128,
          state: richState,
          gridPadding: padding,
        ),
      );

      expect(tester.takeException(), isNull);
      const cell = (250 - 8 - 8 - 3 * 4) / 4;
      Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
      expect(rect('header-resource-material-1').width, cell);
      expect(rect('header-resource-material-5').width, cell);
      expect(
        rect('header-resource-material-8').left,
        rect('header-resource-material-4').left,
      );
      expect(rect('header-senka-summary').left, 8);
      expect(rect('header-nosaki-timer-summary').right, closeTo(250 - 8, 0.01));

      final toggle = rect('information-panel-resources-toggle');
      final last = rect('header-resource-material-8');
      expect(toggle.size, const Size(24, 24));
      expect(toggle.left, greaterThanOrEqualTo(last.right));
      expect(toggle.right, 250);
      expect(toggle.center.dy, closeTo(last.center.dy, 2.01));
      final icon = tester.getRect(find.byIcon(Icons.keyboard_arrow_up_rounded));
      expect(icon.right, 250 - padding.right);
      expect(icon.center.dy, closeTo(last.center.dy, 0.01));

      // 回归：用户嫌字小。真机 11 号粗体等宽数字约 0.6–0.65em，6 位约 40–43dp，
      // 数值位至少留 40 才能让缩放保持在 0.9 以上。测试字体每个字 1em，量不出真实缩放。
      final fuelSlot = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('header-resource-material-1')),
          matching: find.byType(FittedBox),
        ),
      );
      expect(fuelSlot.width, greaterThanOrEqualTo(40));

      final expandedM1 = rect('header-resource-material-1');
      final expandedM4 = rect('header-resource-material-4');
      await tester.tap(
        find.byKey(const Key('information-panel-resources-toggle')),
      );
      await tester.pumpAndSettle();
      expect(rect('header-resource-material-1').left, expandedM1.left);
      expect(rect('header-resource-material-4').left, expandedM4.left);
      expect(
        rect('header-resource-material-4').top,
        rect('header-resource-material-1').top,
      );
      expect(
        rect('information-panel-resources-toggle').left,
        greaterThanOrEqualTo(rect('header-resource-material-4').right),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grid toggle uses the free space of a short last row', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    await controller.toggleHeaderResourceVisible('material-8');
    await tester.pumpWidget(
      gridHarness(controller, width: 250, state: richState),
    );

    const cell = (250 - 3 * 4) / 4;
    expect(
      tester.getSize(find.byKey(const Key('header-resource-material-7'))).width,
      cell,
    );
    final toggle = tester.getRect(
      find.byKey(const Key('information-panel-resources-toggle')),
    );
    expect(
      toggle.left,
      greaterThanOrEqualTo(
        tester
            .getRect(find.byKey(const Key('header-resource-material-7')))
            .right,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid wide items show an icon instead of the text label', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    await tester.pumpWidget(
      gridHarness(controller, width: 250, senka: 3128, state: richState),
    );

    final grid = find.byKey(const Key('information-panel-resources'));
    for (final label in ['战果', '泊地', '野埼', '舰娘', '装备']) {
      expect(
        find.descendant(of: grid, matching: find.textContaining(label)),
        findsNothing,
        reason: label,
      );
    }
    for (final (key, icon, label) in const [
      ('header-senka-summary', Icons.emoji_events_rounded, '战果'),
      ('header-anchorage-timer-summary', Icons.anchor, '泊地'),
      ('header-nosaki-timer-summary', Icons.auto_awesome, '野埼'),
      ('header-ship-capacity', Icons.directions_boat_filled_rounded, '舰娘'),
      ('header-equipment-capacity', Icons.build_rounded, '装备'),
    ]) {
      final item = find.byKey(Key(key));
      expect(
        find.descendant(of: item, matching: find.byIcon(icon)),
        findsOneWidget,
        reason: key,
      );
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: item, matching: find.byType(Tooltip)).first,
      );
      expect(tooltip.message, contains(label), reason: key);
    }
    expect(find.text('3128(#123)'), findsOneWidget);
    expect(find.text('0/750'), findsOneWidget);
    expect(find.byIcon(Icons.anchor).evaluate().length, 1);
  });

  testWidgets('grid collapses to the first four plain resources and persists', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    await tester.pumpWidget(
      gridHarness(controller, width: 250, senka: 3128, state: richState),
    );
    final toggle = find.byKey(const Key('information-panel-resources-toggle'));
    expect(
      find.descendant(
        of: toggle,
        matching: find.byIcon(Icons.keyboard_arrow_up_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(toggle), const Size(24, 24));
    final lastItem = tester.getRect(
      find.byKey(const Key('header-resource-material-8')),
    );
    final toggleRect = tester.getRect(toggle);
    expect(toggleRect.left, greaterThanOrEqualTo(lastItem.right));
    expect(toggleRect.center.dy, closeTo(lastItem.center.dy, 2.01));

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    void expectCollapsed() {
      for (final id in [1, 2, 3, 4]) {
        expect(
          find.byKey(Key('header-resource-material-$id')),
          findsOneWidget,
          reason: 'material-$id',
        );
      }
      for (final key in [
        'header-resource-material-5',
        'header-resource-material-8',
        'header-senka-summary',
        'header-equipment-capacity',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('information-panel-resources-toggle')),
          matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    expectCollapsed();
    expect(
      controller.dashboardCardCollapsed,
      contains(panelResourcesCollapseId),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('layout_dashboard_card_collapsed'),
      contains('panel-resources'),
    );

    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await tester.pumpWidget(
      gridHarness(restored, width: 250, senka: 3128, state: richState),
    );
    await tester.pumpAndSettle();
    expectCollapsed();

    await tester.tap(
      find.byKey(const Key('information-panel-resources-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-senka-summary')), findsOneWidget);
    expect(
      restored.dashboardCardCollapsed,
      isNot(contains(panelResourcesCollapseId)),
    );
  });

  testWidgets('grid collapse still toggles while the UI is locked', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiLocked(true);
    await tester.pumpWidget(gridHarness(controller, width: 250));

    await tester.tap(
      find.byKey(const Key('information-panel-resources-toggle')),
    );
    await tester.pumpAndSettle();

    expect(
      controller.dashboardCardCollapsed,
      contains(panelResourcesCollapseId),
    );
    expect(find.byKey(const Key('header-resource-material-5')), findsNothing);
  });

  for (final locale in const [Locale('zh'), Locale('en')]) {
    testWidgets('grid fits 190dp without clipping numbers in $locale', (
      tester,
    ) async {
      final controller = await loadGridController();
      await controller.setUiDisplaySize(UiDisplaySize.minimal);
      await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
      await tester.pumpWidget(
        gridHarness(
          controller,
          width: 190,
          senka: 31280.5,
          state: richState,
          locale: locale,
        ),
      );

      expect(tester.takeException(), isNull);
      for (final (key, value) in const [
        ('header-senka-summary', '31280.5(#123)'),
        ('header-ship-capacity', '0/750'),
        ('header-equipment-capacity', '0/3431'),
        ('header-anchorage-timer-summary', '--'),
        ('header-resource-material-1', '146449'),
        ('header-resource-material-2', '159378'),
        ('header-resource-material-4', '143589'),
      ]) {
        final item = find.byKey(Key(key));
        final text = find.descendant(of: item, matching: find.text(value));
        expect(text, findsOneWidget, reason: key);
        final itemRect = tester.getRect(item);
        final textRect = tester.getRect(text);
        expect(textRect.left, greaterThanOrEqualTo(itemRect.left), reason: key);
        expect(
          textRect.right,
          lessThanOrEqualTo(itemRect.right + 0.01),
          reason: key,
        );
      }
    });
  }

  testWidgets('grid layout gives the senka item its natural width at 200dp', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    await tester.pumpWidget(gridHarness(controller, senka: 1234.5));

    expect(tester.takeException(), isNull);
    final summary = find.byKey(const Key('header-senka-summary'));
    final value = find.textContaining('1234.5');
    expect(value, findsOneWidget);
    expect(tester.widget<Text>(value).style?.fontSize, 11);
    // 按自然宽度装行，数值不必缩放，也完整落在格子里。
    final paragraph = tester.renderObject<RenderBox>(value);
    expect(tester.getRect(value).width, closeTo(paragraph.size.width, 0.01));
    final cell = tester.getRect(summary);
    expect(tester.getRect(value).left, greaterThanOrEqualTo(cell.left));
    expect(tester.getRect(value).right, lessThanOrEqualTo(cell.right + 0.01));
  });

  testWidgets('grid layout rows are 20dp tall with numbers unclipped', (
    tester,
  ) async {
    final controller = await loadGridController();
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
    await tester.pumpWidget(
      gridHarness(
        controller,
        senka: 1234.5,
        state: const GameState(
          resources: <GameResourceType, int>{GameResourceType.fuel: 123456},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final key in const [
      'header-resource-material-1',
      'header-senka-summary',
      'header-anchorage-timer-summary',
      'header-nosaki-timer-summary',
      'header-ship-capacity',
      'header-equipment-capacity',
      'header-frame-refresh',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))).height, 20, reason: key);
    }
    final first = tester.getTopLeft(
      find.byKey(const Key('header-resource-material-1')),
    );
    final seventh = tester.getTopLeft(
      find.byKey(const Key('header-resource-material-7')),
    );
    expect(seventh.dy - first.dy, 20 + 2);
    for (final (key, value) in const [
      ('header-resource-material-1', '123456'),
      ('header-senka-summary', '1234.5'),
    ]) {
      final item = tester.getRect(find.byKey(Key(key)));
      final text = tester.getRect(find.textContaining(value));
      expect(text.left, greaterThanOrEqualTo(item.left), reason: value);
      expect(text.top, greaterThanOrEqualTo(item.top), reason: value);
      expect(text.right, lessThanOrEqualTo(item.right), reason: value);
      expect(text.bottom, lessThanOrEqualTo(item.bottom), reason: value);
    }
  });

  for (final size in [UiDisplaySize.normal, UiDisplaySize.minimal]) {
    testWidgets('grid layout items have no capsule decoration at $size', (
      tester,
    ) async {
      final controller = await loadGridController();
      await controller.setUiDisplaySize(size);
      await tester.pumpWidget(gridHarness(controller, senka: 1234.5));

      for (final key in const [
        'header-resource-material-1',
        'header-senka-summary',
        'header-ship-capacity',
      ]) {
        final item = find.byKey(Key(key));
        expect(item, findsOneWidget);
        final boxes = <Decoration?>[
          for (final box in tester.widgetList<Container>(
            find.descendant(of: item, matching: find.byType(Container)),
          ))
            box.decoration,
          if (tester.widget(item) is Container)
            (tester.widget(item) as Container).decoration,
          for (final box in tester.widgetList<DecoratedBox>(
            find.descendant(of: item, matching: find.byType(DecoratedBox)),
          ))
            box.decoration,
        ];
        for (final d in boxes) {
          expect(d is BoxDecoration ? d.border : null, isNull, reason: key);
          expect(d is BoxDecoration ? d.color : null, isNull, reason: key);
        }
      }
    });
  }

  testWidgets('grid layout long-press respects ui lock', (tester) async {
    final controller = await loadGridController();
    await controller.setUiLocked(true);
    await tester.pumpWidget(gridHarness(controller));

    await tester.longPress(find.byKey(const Key('header-resource-material-1')));
    await tester.pump();

    expect(find.byKey(const Key('header-resource-edit-mode')), findsNothing);
    expect(
      find.byKey(const Key('panel-resource-collapsed-dialog')),
      findsNothing,
    );
    expect(find.text('界面已锁定，布局自定义已禁用，功能切换不受影响'), findsOneWidget);
  });

  group('grid long-press picks the items shown when collapsed', () {
    final dialog = find.byKey(const Key('panel-resource-collapsed-dialog'));

    Future<LayoutSettingsController> openDialog(
      WidgetTester tester, {
      LayoutSettingsController? controller,
    }) async {
      controller ??= await loadGridController();
      await controller.setUiDisplaySize(UiDisplaySize.minimal);
      await tester.pumpWidget(gridHarness(controller, width: 250, senka: 3128));
      await tester.longPress(
        find.byKey(const Key('header-resource-material-1')),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    bool? checked(WidgetTester tester, String id) => tester
        .widget<Checkbox>(
          find.descendant(
            of: dialog,
            matching: find.byKey(Key('header-resource-visible-$id')),
          ),
        )
        .value;

    Future<void> tapRow(WidgetTester tester, String id) async {
      final row = find.descendant(
        of: dialog,
        matching: find.byKey(Key('header-resource-filter-row-$id')),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('lists only visible items with the default four checked', (
      tester,
    ) async {
      await openDialog(tester);

      expect(dialog, findsOneWidget);
      expect(find.text('折叠时显示'), findsOneWidget);
      expect(find.byKey(const Key('header-resource-edit-mode')), findsNothing);
      for (final id in [headerFrameRefreshId, 'useitem-10']) {
        expect(
          find.byKey(Key('header-resource-filter-row-$id')),
          findsNothing,
          reason: id,
        );
      }
      for (final id in [headerSenkaId, headerShipCapacityId]) {
        expect(checked(tester, id), isFalse, reason: id);
      }
      for (final id in [
        'material-1',
        'material-2',
        'material-3',
        'material-4',
      ]) {
        await _revealChecklistRow(tester, id);
        expect(checked(tester, id), isTrue, reason: id);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggles persist and drive the collapsed row', (tester) async {
      final controller = await openDialog(tester);
      await tapRow(tester, headerShipCapacityId);
      await tapRow(tester, headerEquipmentCapacityId);
      await tapRow(tester, 'material-1');

      expect(controller.collapsedPanelResourceIds?.toSet(), {
        headerShipCapacityId,
        headerEquipmentCapacityId,
        'material-2',
        'material-3',
        'material-4',
      });
      await tester.tap(find.byKey(const Key('header-resource-filter-done')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      await tester.tap(
        find.byKey(const Key('information-panel-resources-toggle')),
      );
      await tester.pumpAndSettle();
      final ships = tester.getRect(
        find.byKey(const Key('header-resource-$headerShipCapacityId')),
      );
      final equipment = tester.getRect(
        find.byKey(const Key('header-resource-$headerEquipmentCapacityId')),
      );
      expect(equipment.top, ships.top);
      for (final id in [2, 3, 4]) {
        expect(
          find.byKey(Key('header-resource-material-$id')),
          findsOneWidget,
          reason: 'material-$id',
        );
      }
      for (final key in [
        'header-resource-material-1',
        'header-resource-$headerSenkaId',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(tester.takeException(), isNull);

      final restored = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(
        restored.collapsedPanelResourceIds?.toSet(),
        controller.collapsedPanelResourceIds?.toSet(),
      );
    });

    testWidgets('restore default clears the choice', (tester) async {
      final controller = await loadGridController();
      await controller.setCollapsedPanelResourceIds([headerSenkaId]);
      await openDialog(tester, controller: controller);
      expect(checked(tester, 'material-1'), isFalse);

      await tester.tap(find.byKey(const Key('panel-resource-collapsed-reset')));
      await tester.pumpAndSettle();

      expect(controller.collapsedPanelResourceIds, isNull);
      expect(checked(tester, 'material-1'), isTrue);
      expect(checked(tester, headerSenkaId), isFalse);
    });

    testWidgets('closes when the UI gets locked', (tester) async {
      final controller = await openDialog(tester);
      expect(dialog, findsOneWidget);
      await controller.setUiLocked(true);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });

    testWidgets('a hidden choice comes back once visible again', (
      tester,
    ) async {
      final controller = await loadGridController();
      await controller.setUiDisplaySize(UiDisplaySize.minimal);
      await controller.setCollapsedPanelResourceIds([
        headerSenkaId,
        'material-5',
      ]);
      await controller.toggleDashboardCardCollapsed(panelResourcesCollapseId);
      await tester.pumpWidget(gridHarness(controller, width: 250, senka: 3128));
      await tester.pumpAndSettle();
      final senka = find.byKey(const Key('header-resource-$headerSenkaId'));
      expect(senka, findsOneWidget);
      expect(
        find.byKey(const Key('header-resource-material-5')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('header-resource-material-1')), findsNothing);

      await controller.toggleHeaderResourceVisible(headerSenkaId);
      await tester.pumpAndSettle();
      expect(senka, findsNothing);
      expect(controller.collapsedPanelResourceIds, contains(headerSenkaId));

      await controller.toggleHeaderResourceVisible(headerSenkaId);
      await tester.pumpAndSettle();
      expect(senka, findsOneWidget);
    });
  });

  group('grid packs by measured width and clears the corner per row', () {
    // 测试字体每字 1em，比真机宽得多；装行验收用应用实际的中文字体量。
    const appFont = 'HarmonyOS_Sans_SC';
    setUpAll(() async {
      await (FontLoader(
        appFont,
      )..addFont(rootBundle.load('assets/fonts/HarmonyOS_Sans_SC.ttf'))).load();
    });

    const panelWidth = 205.0;
    const radius = 55.0;
    const basePadding = EdgeInsets.fromLTRB(8, 6, 8, 2);

    // 明石、野埼都在第一舰队旗舰位就绪，计时开始后两个计时器都在走。
    final portState = GameState(
      fleets: const <Fleet>[
        Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
      ],
      ships: <int, OwnedShip>{
        1: const OwnedShip(
          id: 1,
          masterId: 187,
          level: 80,
          currentHp: 45,
          maxHp: 45,
        ),
        2: const OwnedShip(
          id: 2,
          masterId: 1002,
          level: 80,
          currentHp: 48,
          maxHp: 48,
          currentFuel: 100,
          currentAmmo: 100,
          condition: 49,
        ),
        for (var id = 3; id <= 320; id++)
          id: OwnedShip(
            id: id,
            masterId: 1,
            level: 1,
            currentHp: 10,
            maxHp: 10,
          ),
      },
      masterShips: const <int, MasterShip>{
        187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
        1002: MasterShip(
          id: 1002,
          name: '野埼改',
          shipTypeId: 22,
          maxFuel: 100,
          maxAmmo: 100,
        ),
      },
      slotItems: <int, OwnedSlotItem>{
        for (var id = 1; id <= 1500; id++)
          id: OwnedSlotItem(id: id, masterId: 1),
      },
      maxShipCount: 340,
      maxEquipmentCount: 1600,
      hasPortData: true,
    );

    Future<LayoutSettingsController> pumpPanel(
      WidgetTester tester, {
      bool timersRunning = false,
      ({double left, double right}) cornerRadii = (left: 0, right: radius),
      Locale locale = const Locale('zh'),
      double textScale = 1,
      String? fontFamily = appFont,
      LayoutSettingsController? controller,
      VoidCallback? onAnchorageTimerTap,
      VoidCallback? onNosakiTimerTap,
    }) async {
      controller ??= await loadGridController();
      await controller.setUiDisplaySize(UiDisplaySize.minimal);
      await tester.pumpWidget(
        gridHarness(
          controller,
          width: panelWidth,
          senka: 1234,
          rank: 56,
          state: portState,
          locale: locale,
          gridPadding: basePadding,
          cornerRadii: cornerRadii,
          fontFamily: fontFamily,
          textScale: textScale,
          timersStartedAt: timersRunning
              ? DateTime.now().toUtc().subtract(const Duration(minutes: 10))
              : null,
          onAnchorageTimerTap: onAnchorageTimerTap,
          onNosakiTimerTap: onNosakiTimerTap,
        ),
      );
      await tester.pump();
      return controller;
    }

    const wideKeys = <String>[
      'header-resource-$headerSenkaId',
      'header-resource-$headerAnchorageTimerId',
      'header-resource-$headerNosakiTimerId',
      'header-resource-$headerFrameRefreshId',
      'header-resource-$headerShipCapacityId',
      'header-resource-$headerEquipmentCapacityId',
    ];
    final plainKeys = <String>[
      for (var id = 1; id <= 8; id++) 'header-resource-material-$id',
    ];

    // 按格子顶边把可见项分成行，行内按左边排序。
    List<List<Rect>> rowsOf(WidgetTester tester, Iterable<String> keys) {
      final byTop = <double, List<Rect>>{};
      for (final key in keys) {
        if (find.byKey(Key(key)).evaluate().isEmpty) continue;
        final rect = tester.getRect(find.byKey(Key(key)));
        byTop.putIfAbsent(rect.top, () => <Rect>[]).add(rect);
      }
      final tops = byTop.keys.toList()..sort();
      return [
        for (final top in tops)
          byTop[top]!..sort((a, b) => a.left.compareTo(b.left)),
      ];
    }

    void expectRowsClearRightCorner(WidgetTester tester) {
      for (final row in rowsOf(tester, [...wideKeys, ...plainKeys])) {
        final iconTop = row.first.top + (20 - 12) / 2;
        expect(
          row.last.right,
          lessThanOrEqualTo(
            panelWidth - 8 - cornerInsetAt(radius, iconTop) + 1e-6,
          ),
          reason: 'row at ${row.first.top}',
        );
      }
    }

    testWidgets('idle timers fit the wide items into two rows', (tester) async {
      await pumpPanel(tester);

      expect(tester.takeException(), isNull);
      expect(rowsOf(tester, wideKeys), hasLength(2));
      expect(rowsOf(tester, [...wideKeys, ...plainKeys]), hasLength(4));
      expectRowsClearRightCorner(tester);
    });

    testWidgets('running timers take no more rows than before', (tester) async {
      await pumpPanel(tester, timersRunning: true);

      expect(tester.takeException(), isNull);
      expect(
        rowsOf(tester, [...wideKeys, ...plainKeys]).length,
        lessThanOrEqualTo(5),
      );
      expectRowsClearRightCorner(tester);
    });

    testWidgets('idle timers show a short dash and stay tappable', (
      tester,
    ) async {
      var anchorageTaps = 0;
      var nosakiTaps = 0;
      await pumpPanel(
        tester,
        onAnchorageTimerTap: () => anchorageTaps++,
        onNosakiTimerTap: () => nosakiTaps++,
      );

      for (final key in const [
        'header-anchorage-timer-summary',
        'header-nosaki-timer-summary',
      ]) {
        final item = find.byKey(Key(key));
        expect(
          find.descendant(of: item, matching: find.text('--')),
          findsOneWidget,
          reason: key,
        );
        expect(
          find.descendant(of: item, matching: find.text('--:--:--')),
          findsNothing,
          reason: key,
        );
      }
      await tester.tap(
        find.byKey(const Key('header-resource-anchorage-timer')),
      );
      await tester.tap(find.byKey(const Key('header-resource-nosaki-timer')));
      expect(anchorageTaps, 1);
      expect(nosakiTaps, 1);
    });

    testWidgets('running timers show hh:mm:ss', (tester) async {
      await pumpPanel(tester, timersRunning: true);

      for (final key in const [
        'header-anchorage-timer-summary',
        'header-nosaki-timer-summary',
      ]) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        );
        expect(text.data, matches(RegExp(r'^00:10:\d\d$')), reason: key);
      }
    });

    testWidgets('wide items keep the user order', (tester) async {
      final controller = await loadGridController();
      await controller.setHeaderResourceOrder(<String>[
        headerEquipmentCapacityId,
        ...allHeaderResourceIds.where((id) => id != headerEquipmentCapacityId),
      ]);
      await pumpPanel(tester, controller: controller);

      final first = rowsOf(tester, wideKeys).first.first;
      expect(
        first,
        tester.getRect(
          find.byKey(const Key('header-resource-$headerEquipmentCapacityId')),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('left corner pulls each row in on the left', (tester) async {
      await pumpPanel(tester, cornerRadii: (left: radius, right: 0));

      expect(tester.takeException(), isNull);
      final rows = rowsOf(tester, [...wideKeys, ...plainKeys]);
      for (final row in rows) {
        final iconTop = row.first.top + (20 - 12) / 2;
        expect(
          row.first.left,
          greaterThanOrEqualTo(8 + cornerInsetAt(radius, iconTop) - 1e-6),
          reason: 'row at ${row.first.top}',
        );
        // 末行末格给折叠按钮让了位，其余行右侧不内缩、仍满宽。
        if (row != rows.last) {
          expect(row.last.right, closeTo(panelWidth - 8, 0.01));
        }
      }
      expect(cornerInsetAt(radius, rows.first.first.top + 4), greaterThan(20));
    });

    testWidgets('running timers keep each timer and capacity pair together', (
      tester,
    ) async {
      await pumpPanel(tester, timersRunning: true);

      expect(tester.takeException(), isNull);
      Rect rect(String id) =>
          tester.getRect(find.byKey(Key('header-resource-$id')));
      final rows = rowsOf(tester, wideKeys);
      expect(rows, hasLength(3));
      expect(rows[0], [rect(headerSenkaId)]);
      expect(rows[1], [
        rect(headerAnchorageTimerId),
        rect(headerNosakiTimerId),
      ]);
      expect(rows[2], [
        rect(headerShipCapacityId),
        rect(headerEquipmentCapacityId),
      ]);
      expectRowsClearRightCorner(tester);
    });

    testWidgets('a timer whose partner is hidden packs like any wide item', (
      tester,
    ) async {
      final controller = await loadGridController();
      await controller.toggleHeaderResourceVisible(headerNosakiTimerId);
      await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
      await pumpPanel(tester, controller: controller, timersRunning: true);

      expect(tester.takeException(), isNull);
      Rect rect(String id) =>
          tester.getRect(find.byKey(Key('header-resource-$id')));
      final rows = rowsOf(tester, wideKeys);
      expect(rows.expand((row) => row), hasLength(5));
      final capacityRow = rows.firstWhere(
        (row) => row.contains(rect(headerShipCapacityId)),
      );
      expect(capacityRow, contains(rect(headerEquipmentCapacityId)));
      expect(capacityRow, hasLength(2));
      expectRowsClearRightCorner(tester);
    });

    testWidgets('timers ordered apart are not pulled together', (tester) async {
      const apart = <String>[
        headerAnchorageTimerId,
        headerShipCapacityId,
        headerNosakiTimerId,
        headerEquipmentCapacityId,
      ];
      final controller = await loadGridController();
      await controller.setHeaderResourceOrder(<String>[
        headerSenkaId,
        ...apart,
        ...allHeaderResourceIds.where(
          (id) => id != headerSenkaId && !apart.contains(id),
        ),
      ]);
      await pumpPanel(tester, controller: controller, timersRunning: true);

      expect(tester.takeException(), isNull);
      final rects = [
        for (final id in apart)
          tester.getRect(find.byKey(Key('header-resource-$id'))),
      ];
      for (var i = 1; i < rects.length; i++) {
        final previous = rects[i - 1];
        expect(
          rects[i].top > previous.top ||
              (rects[i].top == previous.top && rects[i].left > previous.left),
          isTrue,
          reason: apart[i],
        );
      }
      expectRowsClearRightCorner(tester);
    });

    testWidgets('collapsed row too narrow for four cells wraps into 2x2', (
      tester,
    ) async {
      await pumpPanel(tester);
      await tester.tap(
        find.byKey(const Key('information-panel-resources-toggle')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      Rect rect(int id) =>
          tester.getRect(find.byKey(Key('header-resource-material-$id')));
      expect(rect(2).top, rect(1).top);
      expect(rect(3).top, greaterThan(rect(1).top));
      expect(rect(4).top, rect(3).top);
      expect(rect(3).left, rect(1).left);
      expect(find.byKey(const Key('header-resource-material-5')), findsNothing);
      for (final id in [1, 2, 3]) {
        expect(rect(id).width, greaterThanOrEqualTo(55), reason: '$id');
      }
      expectRowsClearRightCorner(tester);
      final rowRight =
          panelWidth - 8 - cornerInsetAt(radius, rect(4).top + (20 - 12) / 2);
      final icon = tester.getRect(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
      );
      expect(icon.right, closeTo(rowRight, 0.01));
      final toggle = tester.getRect(
        find.byKey(const Key('information-panel-resources-toggle')),
      );
      expect(toggle.right, lessThanOrEqualTo(panelWidth));
      expect(
        toggle.left,
        greaterThanOrEqualTo(
          tester
              .getRect(find.byKey(const Key('header-resource-material-4')))
              .right,
        ),
      );
    });

    testWidgets('chosen capacities pair up above a 2x2 of resources', (
      tester,
    ) async {
      final controller = await loadGridController();
      await controller.setCollapsedPanelResourceIds([
        headerShipCapacityId,
        headerEquipmentCapacityId,
        'material-1',
        'material-2',
        'material-3',
        'material-4',
      ]);
      await controller.toggleDashboardCardCollapsed(panelResourcesCollapseId);
      await pumpPanel(tester, controller: controller);

      expect(tester.takeException(), isNull);
      Rect rect(String id) =>
          tester.getRect(find.byKey(Key('header-resource-$id')));
      expect(
        rect(headerEquipmentCapacityId).top,
        rect(headerShipCapacityId).top,
      );
      expect(
        rect('material-1').top,
        greaterThan(rect(headerShipCapacityId).top),
      );
      expect(rect('material-2').top, rect('material-1').top);
      expect(rect('material-3').top, greaterThan(rect('material-1').top));
      expect(rect('material-3').left, rect('material-1').left);
      expect(
        find.byKey(const Key('header-resource-$headerSenkaId')),
        findsNothing,
      );
      expectRowsClearRightCorner(tester);
    });

    for (final locale in const [Locale('zh'), Locale('en')]) {
      for (final running in const [false, true]) {
        testWidgets(
          'large text in $locale (timers running: $running) does not overflow',
          (tester) async {
            final controller = await loadGridController();
            await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
            for (final fontFamily in const <String?>[appFont, null]) {
              await pumpPanel(
                tester,
                controller: controller,
                locale: locale,
                textScale: 1.3,
                timersRunning: running,
                fontFamily: fontFamily,
              );
              expect(tester.takeException(), isNull, reason: '$fontFamily');
              expectRowsClearRightCorner(tester);
            }
          },
        );
      }
    }
  });

  group('minimal strips size items to their content', () {
    const stripState = GameState(
      resources: <GameResourceType, int>{
        GameResourceType.fuel: 146449,
        GameResourceType.ammunition: 159378,
        GameResourceType.steel: 157012,
        GameResourceType.bauxite: 143589,
        GameResourceType.instantBuild: 771,
        GameResourceType.instantRepair: 889,
        GameResourceType.developmentMaterial: 501,
        GameResourceType.improvementMaterial: 11,
      },
      maxShipCount: 750,
      maxEquipmentCount: 3431,
      hasPortData: true,
    );

    Future<LayoutSettingsController> loadStrip(UiDisplaySize size) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      await controller.setUiDisplaySize(size);
      await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
      return controller;
    }

    // 横条要整条排开才能逐项比对，测试窗口放宽到能容下全部项。
    void useWideView(WidgetTester tester) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Widget stripHarness(
      LayoutSettingsController controller, {
      ResourceBarLayout layout = ResourceBarLayout.strip,
      double width = 2400,
      double height = 22,
    }) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: CompactResourceBar(
              state: stripState,
              senka: 3128,
              rank: 5,
              anchorageRepairStartedAt: DateTime.now().toUtc().subtract(
                const Duration(minutes: 10),
              ),
              settingsController: controller,
              layout: layout,
            ),
          ),
        ),
      ),
    );

    List<Rect> itemRects(
      WidgetTester tester,
      LayoutSettingsController controller,
    ) => [
      for (final id in controller.headerResourceOrder)
        if (controller.visibleHeaderResourceIds.contains(id))
          tester.getRect(find.byKey(Key('header-resource-$id'))),
    ];

    void expectTextsUnscaled(
      WidgetTester tester,
      LayoutSettingsController controller,
    ) {
      for (final id in controller.visibleHeaderResourceIds) {
        final item = find.byKey(Key('header-resource-$id'));
        final cell = tester.getRect(item);
        for (final text
            in find
                .descendant(of: item, matching: find.byType(Text))
                .evaluate()) {
          final box = text.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          expect(
            tester.getRect(find.byWidget(text.widget)).width,
            closeTo(box.size.width, 0.01),
            reason: id,
          );
          expect(rect.left, greaterThanOrEqualTo(cell.left - 0.01), reason: id);
          expect(rect.right, lessThanOrEqualTo(cell.right + 0.01), reason: id);
        }
      }
    }

    testWidgets('minimal strip gives each item its natural width', (
      tester,
    ) async {
      useWideView(tester);
      final controller = await loadStrip(UiDisplaySize.minimal);
      await tester.pumpWidget(stripHarness(controller));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expectTextsUnscaled(tester, controller);
      final rects = itemRects(tester, controller);
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left - rects[i - 1].right, closeTo(6, 0.01));
      }
      // 不再套用固定宽表（普通资源 74、战果 132）。
      expect(
        tester
            .getSize(find.byKey(const Key('header-resource-material-1')))
            .width,
        isNot(74),
      );
      expect(
        tester.getSize(find.byKey(const Key('header-resource-senka'))).width,
        isNot(132),
      );
    });

    testWidgets('compact strip keeps the fixed width table', (tester) async {
      useWideView(tester);
      final controller = await loadStrip(UiDisplaySize.compact);
      await tester.pumpWidget(stripHarness(controller, height: 26));
      await tester.pump();

      expect(
        tester
            .getSize(find.byKey(const Key('header-resource-material-1')))
            .width,
        74,
      );
      expect(
        tester.getSize(find.byKey(const Key('header-resource-senka'))).width,
        132,
      );
      final rects = itemRects(tester, controller);
      expect(rects[1].left - rects[0].right, closeTo(5, 0.01));
    });

    testWidgets('static strip lays one unscrollable natural-width row', (
      tester,
    ) async {
      useWideView(tester);
      final controller = await loadStrip(UiDisplaySize.minimal);
      await tester.pumpWidget(
        stripHarness(
          controller,
          layout: ResourceBarLayout.staticStrip,
          height: 21,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      expectTextsUnscaled(tester, controller);
      final rects = itemRects(tester, controller);
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, rects[0].top);
        expect(rects[i].left - rects[i - 1].right, closeTo(6, 0.01));
      }
      for (final rect in rects) {
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(21));
      }
    });

    testWidgets('static strip scales the whole row down when too wide', (
      tester,
    ) async {
      useWideView(tester);
      final controller = await loadStrip(UiDisplaySize.minimal);
      await tester.pumpWidget(
        stripHarness(
          controller,
          layout: ResourceBarLayout.staticStrip,
          width: 300,
          height: 21,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final rects = itemRects(tester, controller);
      expect(rects.first.left, greaterThanOrEqualTo(0));
      expect(rects.last.right, lessThanOrEqualTo(300.01));
      for (final rect in rects) {
        expect(rect.top, rects.first.top);
      }
      final fitted = tester.widget<FittedBox>(
        find.ancestor(
          of: find.byKey(const Key('header-resource-line')),
          matching: find.byType(FittedBox),
        ),
      );
      expect(fitted.fit, BoxFit.scaleDown);
    });
  });
}
