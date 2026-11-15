import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_view.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

const _emptyStage = ImprovementStageCost(
  developmentMin: 0,
  developmentMax: 0,
  improvementMin: 0,
  improvementMax: 0,
  items: <ImprovementConsumeItem>[],
);

void main() {
  final dataset = ImprovementDataset(
    version: const ImprovementDatasetVersion(
      dataVersion: 'test',
      commitSha: '',
    ),
    entries: <ImprovementEntry>[
      ImprovementEntry(
        equipmentId: 1,
        baseCost: const ImprovementResourceCost(
          fuel: 10,
          ammo: 20,
          steel: 30,
          bauxite: 40,
        ),
        arrangements: <ImprovementArrangement>[
          ImprovementArrangement(
            secretaryId: 31,
            secretaryLabel: '睦月',
            weekdays: Set<int>.unmodifiable(<int>{1, 2}),
          ),
        ],
        stage0: const ImprovementStageCost(
          developmentMin: 4,
          developmentMax: 5,
          improvementMin: 2,
          improvementMax: 3,
          items: <ImprovementConsumeItem>[
            ImprovementConsumeItem(equipmentId: 2, count: 1),
          ],
        ),
        stage1: const ImprovementStageCost(
          developmentMin: 7,
          developmentMax: 8,
          improvementMin: 3,
          improvementMax: 6,
          items: <ImprovementConsumeItem>[
            ImprovementConsumeItem(equipmentId: 3, count: 2),
            ImprovementConsumeItem(
              materialKey: 'ActionReport',
              count: 4,
              starFrom: 7,
              starTo: 7,
            ),
            ImprovementConsumeItem(
              materialKey: 'kaigai-skill',
              count: 1,
              starFrom: 8,
              starTo: 8,
            ),
            ImprovementConsumeItem(
              materialKey: 'new_plane_material',
              count: 1,
              starFrom: 9,
              starTo: 9,
            ),
          ],
        ),
        upgrades: const <ImprovementUpgrade>[
          ImprovementUpgrade(
            targetEquipmentId: 293,
            developmentMin: 1,
            developmentMax: 2,
            improvementMin: 3,
            improvementMax: 4,
            items: <ImprovementConsumeItem>[
              ImprovementConsumeItem(equipmentId: 4, count: 1),
            ],
          ),
        ],
      ),
    ],
  );

  for (final (size, scale) in [
    (const Size(390, 780), 1.0),
    (const Size(780, 390), 1.0),
    (const Size(390, 780), 2.0),
    (const Size(780, 390), 2.0),
  ]) {
    testWidgets(
      'English improvement filters fit $size at scale $scale and retain ship names',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = ImprovementPlannerController(
          dataset: dataset,
          clock: () => DateTime.utc(2026, 8, 10),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: ImprovementPlannerView(
                controller: controller,
                state: const GameState(),
              ),
            ),
          ),
        );
        expect(find.text('睦月'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final filter = find.byKey(const Key('improvement-filter-button'));
        await tester.ensureVisible(filter);
        await tester.pumpAndSettle();
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('improvement-filter-sheet')),
          findsOneWidget,
        );
        expect(find.text('Clear all'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final notEvolvable = find.byKey(
          const Key('improvement-filter-evolution-notEvolvable'),
        );
        await tester.ensureVisible(notEvolvable);
        await tester.pumpAndSettle();
        await tester.tap(notEvolvable);
        await tester.pump();
        expect(
          controller.evolutionFilter,
          ImprovementEvolutionFilter.notEvolvable,
        );
        final clear = find.byKey(const Key('improvement-filter-clear'));
        await tester.ensureVisible(clear);
        await tester.pumpAndSettle();
        await tester.tap(clear);
        await tester.pump();
        expect(controller.evolutionFilter, ImprovementEvolutionFilter.all);
        final close = find.byKey(const Key('improvement-filter-close'));
        await tester.ensureVisible(close);
        await tester.pumpAndSettle();
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.text('睦月'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('controller keeps search separate when clearing panel filters', () {
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);

    controller.setQuery('gun');
    controller.selectEquipmentCategory(EquipmentInventoryCategory.mainGun);
    controller.selectEvolutionFilter(ImprovementEvolutionFilter.evolvable);

    expect(controller.hasSearch, isTrue);
    expect(controller.hasFilters, isTrue);

    controller.clearFilters();

    expect(controller.query, 'gun');
    expect(controller.equipmentCategory, EquipmentInventoryCategory.all);
    expect(controller.evolutionFilter, ImprovementEvolutionFilter.all);
    expect(controller.hasSearch, isTrue);
    expect(controller.hasFilters, isFalse);
  });

  test('controller filters rows with live equipment master data', () {
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    const state = GameState(
      masterSlotItems: <int, MasterSlotItem>{
        1: MasterSlotItem(id: 1, name: 'Test Gun', type: <int>[1, 0, 1, 1]),
      },
    );

    controller.setQuery('test');
    controller.selectEquipmentCategory(EquipmentInventoryCategory.mainGun);

    expect(controller.rowsFor(state), hasLength(1));
  });

  test('controller resolves secretary labels through live ship masters', () {
    final controller = ImprovementPlannerController(
      dataset: ImprovementDataset(
        version: const ImprovementDatasetVersion(
          dataVersion: 'test',
          commitSha: '',
        ),
        entries: <ImprovementEntry>[
          ImprovementEntry(
            equipmentId: 1,
            baseCost: const ImprovementResourceCost(
              fuel: 0,
              ammo: 0,
              steel: 0,
              bauxite: 0,
            ),
            arrangements: <ImprovementArrangement>[
              ImprovementArrangement(
                secretaryId: 444,
                secretaryLabel: '#444',
                weekdays: Set<int>.unmodifiable(<int>{DateTime.monday}),
              ),
            ],
            stage0: _emptyStage,
            stage1: _emptyStage,
            upgrades: const <ImprovementUpgrade>[],
          ),
        ],
      ),
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    const state = GameState(
      masterShips: <int, MasterShip>{
        444: MasterShip(id: 444, name: 'Aquila', shipTypeId: 11, sortNo: 244),
        644: MasterShip(id: 644, name: '桃', shipTypeId: 2, sortNo: 444),
      },
    );

    expect(controller.rowsFor(state).single.secretaryLabels, <String>['桃']);
  });

  test('controller defaults to today and accepts all weekdays', () {
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);

    expect(controller.selectedWeekday, DateTime.monday);
    controller.selectWeekday(improvementAllWeekdays);
    expect(controller.selectedWeekday, improvementAllWeekdays);
  });
  for (final size in <Size>[
    const Size(390, 780),
    const Size(780, 390),
    const Size(768, 980),
    const Size(1024, 720),
  ]) {
    testWidgets('renders the frozen improvement table at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = ImprovementPlannerController(
        dataset: dataset,
        clock: () => DateTime.utc(2026, 8, 10),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImprovementPlannerView(
              controller: controller,
              state: const GameState(),
            ),
          ),
        ),
      );

      expect(find.text('周一'), findsOneWidget);
      expect(find.text('周日'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.byKey(const Key('improvement-weekday-all')), findsOneWidget);
      expect(
        find.byKey(const Key('improvement-weekday-segmented')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-weekday-slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-favorites-only')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-evolution-segmented')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('improvement-evolution-slider')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('improvement-search-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-filter-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-frozen-favorite')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-frozen-equipment')),
        findsOneWidget,
      );
      expect(find.text('基础消耗'), findsOneWidget);
      expect(find.text('改修消耗（0 → +6）'), findsOneWidget);
      expect(find.text('改修消耗（+6 → MAX）'), findsOneWidget);
      expect(find.text('进化消耗'), findsOneWidget);
      expect(find.text('秘书舰'), findsOneWidget);
      expect(find.text('可进化'), findsWidgets);
      expect(find.text('进化装备'), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('improvement-table-horizontal-scroll')),
        findsOneWidget,
      );
      expect(
        find.byKey(const PageStorageKey('improvement-table-frozen-scroll')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Align>(
              find.byKey(const Key('improvement-header-base-cost-align')),
            )
            .alignment,
        Alignment.centerLeft,
      );
      expect(
        tester
            .widget<Align>(
              find.byKey(const Key('improvement-cell-base-cost-align-1')),
            )
            .alignment,
        Alignment.centerLeft,
      );
      final baseCostTexts = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('improvement-cell-base-cost-align-1')),
          matching: find.byType(Text),
        ),
      );
      expect(baseCostTexts, hasLength(4));
      expect(
        find.descendant(
          of: find.byKey(const Key('improvement-cell-base-cost-align-1')),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(
        baseCostTexts.every(
          (text) =>
              text.style?.fontSize == 11 &&
              text.style?.fontWeight == FontWeight.w700 &&
              text.style?.color == const Color(0xffdce8ed),
        ),
        isTrue,
      );
      expect(
        find.byKey(const Key('improvement-stage-development-icon-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-stage-improvement-icon-0')),
        findsOneWidget,
      );
      expect(find.text('每次'), findsNWidgets(2));
      expect(find.text('+7→+8'), findsOneWidget);
      expect(find.text('+8→+9'), findsOneWidget);
      expect(find.text('+9→MAX'), findsOneWidget);
      expect(find.text('开'), findsNothing);
      expect(find.text('改'), findsNothing);
      expect(
        tester
            .widget<Align>(
              find
                  .descendant(
                    of: find.byKey(const Key('improvement-stage-1-1')),
                    matching: find.byType(Align),
                  )
                  .first,
            )
            .alignment,
        Alignment.topLeft,
      );
      expect(
        tester.getSize(find.byKey(const Key('improvement-stage-1-1'))).height,
        128,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('favorite star filters and persists across weekdays', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    const state = GameState();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ImprovementPlannerView(controller: controller, state: state),
        ),
      ),
    );
    final firstId = controller.rowsFor(state).first.entry.equipmentId;
    await tester.tap(find.byKey(Key('improvement-favorite-$firstId')));
    await tester.tap(find.byKey(const Key('improvement-favorites-only')));
    await tester.pump();
    expect(
      controller
          .rowsFor(state)
          .every((row) => row.entry.equipmentId == firstId),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('improvement-weekday-2')));
    await tester.pump();
    expect(controller.favoriteEquipmentIds, contains(firstId));
  });

  testWidgets('secretary schedule shows seven days before names', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ImprovementPlannerView(
            controller: controller,
            state: const GameState(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('improvement-weekday-all')));
    await tester.pump(const Duration(milliseconds: 220));

    expect(controller.selectedWeekday, improvementAllWeekdays);
    final secretary = find.byKey(const Key('improvement-secretaries-1'));
    expect(
      find.descendant(of: secretary, matching: find.text('睦月')),
      findsOneWidget,
    );
    expect(find.text('睦月①②'), findsNothing);
    for (final day in <int>[7, 1, 2, 3, 4, 5, 6]) {
      final cell = find.byKey(Key('improvement-secretary-day-1-0-$day'));
      expect(cell, findsOneWidget);
      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(of: cell, matching: find.byType(Container)),
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        decoration.color,
        <int>{1, 2}.contains(day)
            ? const Color(0xff258b68)
            : const Color(0xff37434a),
      );
    }
  });

  testWidgets('places search and filter after favorite and filters evolution', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ImprovementPlannerView(
            controller: controller,
            state: const GameState(),
          ),
        ),
      ),
    );

    final weekdayX = tester
        .getTopLeft(find.byKey(const Key('improvement-weekday-segmented')))
        .dx;
    final favoriteX = tester
        .getTopLeft(find.byKey(const Key('improvement-favorites-only')))
        .dx;
    final searchX = tester
        .getTopLeft(find.byKey(const Key('improvement-search-button')))
        .dx;
    final filterX = tester
        .getTopLeft(find.byKey(const Key('improvement-filter-button')))
        .dx;
    expect(weekdayX, lessThan(favoriteX));
    expect(favoriteX, lessThan(searchX));
    expect(searchX, lessThan(filterX));

    await tester.ensureVisible(
      find.byKey(const Key('improvement-filter-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('improvement-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('improvement-filter-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('improvement-filter-evolution-notEvolvable')),
    );
    await tester.pump();
    expect(controller.evolutionFilter, ImprovementEvolutionFilter.notEvolvable);
    await tester.tap(find.byKey(const Key('improvement-filter-close')));
    await tester.pumpAndSettle();
    expect(find.text('当天没有符合条件的改修装备'), findsOneWidget);
  });

  testWidgets('search dialog filters live and clears query', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    const state = GameState(
      masterSlotItems: <int, MasterSlotItem>{
        1: MasterSlotItem(id: 1, name: 'Test Gun', type: <int>[1, 0, 1, 1]),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ImprovementPlannerView(controller: controller, state: state),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('improvement-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('improvement-search-field')),
      'missing',
    );
    await tester.pump();
    expect(controller.hasSearch, isTrue);
    expect(controller.rowsFor(state), isEmpty);

    await tester.tap(find.byKey(const Key('improvement-search-clear')));
    await tester.pump();
    expect(controller.hasSearch, isFalse);
    expect(controller.rowsFor(state), hasLength(1));
  });

  testWidgets('search dialog closes after editing without lifecycle errors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImprovementPlannerController(
      dataset: dataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ImprovementPlannerView(
            controller: controller,
            state: const GameState(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('improvement-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('improvement-search-field')),
      'gun',
    );
    await tester.tap(find.byKey(const Key('improvement-search-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('improvement-search-field')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile filter sheet has inventory categories and clears filters',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = ImprovementPlannerController(
        dataset: dataset,
        clock: () => DateTime.utc(2026, 8, 10),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImprovementPlannerView(
              controller: controller,
              state: const GameState(),
            ),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('improvement-filter-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('improvement-filter-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('improvement-filter-sheet')), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      for (final category in EquipmentInventoryCategory.values) {
        expect(
          find.byKey(Key('improvement-filter-equipment-${category.name}')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const Key('improvement-filter-evolution-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-filter-evolution-evolvable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('improvement-filter-evolution-notEvolvable')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('improvement-filter-equipment-mainGun')),
      );
      await tester.pump();
      expect(controller.hasFilters, isTrue);
      await tester.tap(find.byKey(const Key('improvement-filter-clear')));
      await tester.pump();
      expect(controller.hasFilters, isFalse);
    },
  );

  testWidgets('links multiple evolution routes with interactive route lanes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final routeDataset = ImprovementDataset(
      version: const ImprovementDatasetVersion(
        dataVersion: 'test',
        commitSha: '',
      ),
      entries: <ImprovementEntry>[
        ImprovementEntry(
          equipmentId: 3,
          baseCost: const ImprovementResourceCost(
            fuel: 0,
            ammo: 0,
            steel: 80,
            bauxite: 70,
          ),
          arrangements: <ImprovementArrangement>[
            ImprovementArrangement(
              secretaryId: 333,
              secretaryLabel: '冬月',
              weekdays: Set<int>.unmodifiable(<int>{1}),
              routeKind: 'kind1',
            ),
            ImprovementArrangement(
              secretaryId: 586,
              secretaryLabel: '白雪改二',
              weekdays: Set<int>.unmodifiable(<int>{1}),
              routeKind: 'kind2',
            ),
          ],
          stage0: const ImprovementStageCost(
            developmentMin: 0,
            developmentMax: 0,
            improvementMin: 0,
            improvementMax: 0,
            items: <ImprovementConsumeItem>[
              ImprovementConsumeItem(materialKey: 'ActionReport', count: 1),
              ImprovementConsumeItem(
                materialKey: 'emergency-repair-material',
                count: 1,
              ),
              ImprovementConsumeItem(materialKey: 'fast-build', count: 1),
              ImprovementConsumeItem(materialKey: 'kaigai-skill', count: 1),
            ],
          ),
          stage1: const ImprovementStageCost(
            developmentMin: 0,
            developmentMax: 0,
            improvementMin: 0,
            improvementMax: 0,
            items: <ImprovementConsumeItem>[
              ImprovementConsumeItem(materialKey: 'kousyo-sigen', count: 1),
              ImprovementConsumeItem(materialKey: 'MedalL', count: 1),
              ImprovementConsumeItem(materialKey: 'NeEngine', count: 1),
              ImprovementConsumeItem(
                materialKey: 'new_plane_material',
                count: 1,
              ),
            ],
          ),
          upgrades: const <ImprovementUpgrade>[
            ImprovementUpgrade(
              targetEquipmentId: 122,
              developmentMin: 8,
              developmentMax: 12,
              improvementMin: 6,
              improvementMax: 10,
              items: <ImprovementConsumeItem>[
                ImprovementConsumeItem(equipmentId: 121, count: 1),
                ImprovementConsumeItem(materialName: '测试资材', count: 1),
              ],
              routeKind: 'kind1',
            ),
            ImprovementUpgrade(
              targetEquipmentId: 553,
              developmentMin: 7,
              developmentMax: 9,
              improvementMin: 5,
              improvementMax: 7,
              items: <ImprovementConsumeItem>[
                ImprovementConsumeItem(
                  materialKey: 'new_gun_material',
                  count: 1,
                ),
                ImprovementConsumeItem(
                  materialKey: 'new_model_material',
                  count: 1,
                ),
                ImprovementConsumeItem(
                  materialKey: 'new-funsiki-material',
                  count: 1,
                ),
                ImprovementConsumeItem(materialKey: 'sensui-hokyu', count: 1),
                ImprovementConsumeItem(materialKey: 'skilled_crew', count: 1),
              ],
              routeKind: 'kind2',
            ),
          ],
        ),
      ],
    );
    final controller = ImprovementPlannerController(
      dataset: routeDataset,
      clock: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(controller.dispose);
    const state = GameState(
      masterSlotItems: <int, MasterSlotItem>{
        3: MasterSlotItem(id: 3, name: '10cm連装高角砲'),
        121: MasterSlotItem(id: 121, name: '94式高射装置'),
        122: MasterSlotItem(id: 122, name: '10cm連装高角砲改＋増設機銃'),
        553: MasterSlotItem(id: 553, name: '10cm連装高角砲改'),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ImprovementPlannerView(controller: controller, state: state),
        ),
      ),
    );

    expect(find.text('94式高射装置'), findsOneWidget);
    expect(find.text('新型砲熕兵装資材'), findsOneWidget);
    expect(find.text('新型兵装資材'), findsOneWidget);
    expect(find.text('冬月'), findsOneWidget);
    expect(find.text('白雪改二'), findsOneWidget);
    expect(find.text('路线 A'), findsNWidgets(3));
    expect(find.text('路线 B'), findsNWidgets(3));
    expect(find.textContaining('①'), findsNothing);
    expect(find.textContaining('②'), findsNothing);
    expect(
      tester
          .widget<FrozenDataTable>(
            find.byKey(const Key('improvement-planner-table')),
          )
          .rowHeights,
      everyElement(greaterThan(152)),
    );
    expect(find.text('10cm連装高角砲改＋増設機銃'), findsOneWidget);
    expect(find.text('10cm連装高角砲改'), findsOneWidget);

    final routeBConsume = find.byKey(
      const Key('improvement-route-3-consume-1'),
    );
    final routeBSecretary = find.byKey(
      const Key('improvement-route-3-secretary-1'),
    );
    final routeBTarget = find.byKey(const Key('improvement-route-3-target-1'));
    final routeAConsume = find.byKey(
      const Key('improvement-route-3-consume-0'),
    );
    final routeASecretary = find.byKey(
      const Key('improvement-route-3-secretary-0'),
    );
    expect(
      tester.getSize(routeASecretary).height,
      lessThan(tester.getSize(routeAConsume).height),
    );
    expect(
      tester.getSize(routeBSecretary).height,
      lessThan(tester.getSize(routeBConsume).height),
      reason: '秘书舰胶囊应按自身内容高度收紧',
    );
    expect(tester.getSize(routeBSecretary).height, lessThanOrEqualTo(60));
    expect(tester.getSize(routeBTarget).height, lessThanOrEqualTo(60));
    for (final column in const <String>['consume', 'secretary', 'target']) {
      final routeA = find.byKey(Key('improvement-route-3-$column-0'));
      final routeB = find.byKey(Key('improvement-route-3-$column-1'));
      final gap = tester.getRect(routeB).top - tester.getRect(routeA).bottom;
      expect(gap, inInclusiveRange(0, 4), reason: '同一列的路线 A 与路线 B 胶囊应紧凑连续排列');
    }
    final routeBLabel = find.descendant(
      of: routeBConsume,
      matching: find.text('路线 B'),
    );
    final routeBLastItem = find.descendant(
      of: routeBConsume,
      matching: find.text('熟練搭乗員'),
    );
    final routeBRect = tester.getRect(routeBConsume);
    final topInset = tester.getRect(routeBLabel).top - routeBRect.top;
    final bottomInset =
        routeBRect.bottom - tester.getRect(routeBLastItem).bottom;
    expect(
      bottomInset,
      lessThanOrEqualTo(topInset + 10),
      reason: '路线胶囊底部留白不应明显大于顶部留白',
    );

    const routeColumns = <String>['consume', 'secretary', 'target'];
    for (final column in routeColumns) {
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-0')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-1')),
            )
            .opacity,
        1,
      );
    }

    await tester.drag(
      find.byKey(const PageStorageKey('improvement-table-horizontal-scroll')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('improvement-route-3-consume-1')));
    await tester.pumpAndSettle();

    for (final column in routeColumns) {
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-0')),
            )
            .opacity,
        0.32,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-1')),
            )
            .opacity,
        1,
      );
    }

    await tester.drag(
      find.byKey(const PageStorageKey('improvement-table-horizontal-scroll')),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('improvement-route-3-target-0')));
    await tester.pumpAndSettle();
    for (final column in routeColumns) {
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-0')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-1')),
            )
            .opacity,
        0.32,
      );
    }

    await tester.tap(find.byKey(const Key('improvement-route-3-secretary-0')));
    await tester.pumpAndSettle();
    for (final column in routeColumns) {
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-0')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(Key('improvement-route-3-$column-1')),
            )
            .opacity,
        1,
      );
    }
    expect(find.text('new_gun_material'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('improvement-material-icon-new_gun_material'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('improvement-material-icon-new_model_material'),
      ),
      findsOneWidget,
    );
    for (final materialKey in <String>[
      'ActionReport',
      'emergency-repair-material',
      'fast-build',
      'kaigai-skill',
      'kousyo-sigen',
      'MedalL',
      'NeEngine',
      'new_plane_material',
      'new-funsiki-material',
      'sensui-hokyu',
      'skilled_crew',
    ]) {
      expect(
        find.byKey(ValueKey<String>('improvement-material-icon-$materialKey')),
        findsOneWidget,
        reason: 'missing icon for $materialKey',
      );
    }
    final quantityTexts = tester.widgetList<Text>(find.text('×1'));
    expect(quantityTexts, isNotEmpty);
    expect(
      quantityTexts.every(
        (text) => text.style?.color == const Color(0xff58bce8),
      ),
      isTrue,
    );
  });
}
