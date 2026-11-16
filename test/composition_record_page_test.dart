import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_port.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_snapshot.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('saved transport uses the selected formation and frozen fleet', (
    tester,
  ) async {
    const savedState = GameState(
      memberId: 7,
      ships: {
        1: OwnedShip(id: 1, masterId: 100, level: 99),
        2: OwnedShip(id: 2, masterId: 101, level: 95),
      },
      masterShips: {
        100: MasterShip(id: 100, name: '曉改二', shipTypeId: 2),
        101: MasterShip(id: 101, name: '最上改二', shipTypeId: 6),
      },
      fleets: [
        Fleet(id: 1, name: '主力', shipIds: [1]),
        Fleet(id: 2, name: '护卫', shipIds: [2]),
      ],
    );
    final oldSnapshot = serializeCompositionSnapshot(
      savedState,
      fleetIds: {1, 2},
      landBaseAreaId: null,
      landBaseIds: {},
    );
    final store = _MemoryStore()
      ..records.addAll([
        CompositionRecord(
          id: 'legacy-combined',
          createdAt: DateTime(2026, 11, 15),
          note: '',
          name: '旧联合记录',
          fleetForm: '運送護衛部隊',
          targetMap: '',
          fleetIds: const [1, 2],
          landBaseCount: 0,
          snapshotJson: oldSnapshot,
        ),
        CompositionRecord(
          id: 'ordinary',
          createdAt: DateTime(2026, 11, 14),
          note: '',
          name: '普通记录',
          fleetForm: '普通舰队',
          targetMap: '',
          fleetIds: const [1, 2],
          landBaseCount: 0,
          snapshotJson: oldSnapshot,
        ),
        CompositionRecord(
          id: 'partial-combined',
          createdAt: DateTime(2026, 11, 13),
          note: '',
          name: '仅保存主力',
          fleetForm: '联合记录',
          targetMap: '',
          fleetIds: const [1],
          landBaseCount: 0,
          snapshotJson: serializeCompositionSnapshot(
            savedState,
            fleetIds: {1},
            landBaseAreaId: null,
            landBaseIds: {},
            combinedFleetType: CombinedFleetType.transportEscort,
          ),
        ),
      ]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              state: const GameState(memberId: 7),
              recordStore: store,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final main = find.byKey(const Key('composition-metric-1-transport-points'));
    final escort = find.byKey(
      const Key('composition-metric-2-transport-points'),
    );
    final scouting = find.byKey(
      const Key('composition-metric-1-line-of-sight'),
    );
    expect(tester.getTopRight(scouting).dx, tester.getTopLeft(main).dx);
    expect(tester.getSize(main), tester.getSize(scouting));
    expect(find.descendant(of: main, matching: find.text('9')), findsOneWidget);
    expect(
      find.descendant(of: escort, matching: find.text('4')),
      findsOneWidget,
    );
    await tester.tap(main);
    await tester.pumpAndSettle();
    final popup = find.byKey(const Key('fleet-transport-details-popover'));
    expect(popup, findsOneWidget);
    for (final value in ['5 TP', '4 TP']) {
      expect(
        find.descendant(of: popup, matching: find.text(value)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: popup, matching: find.text('S：9（A：6）')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('fleet-transport-details-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-record-ordinary')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: main, matching: find.text('5')), findsOneWidget);
    expect(
      find.descendant(of: escort, matching: find.text('4')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('composition-record-partial-combined')),
    );
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(
      find.descendant(
        of: main,
        matching: find.text(l10n.fleetCombinedTransportPoints),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: main, matching: find.text(l10n.noValue)),
      findsOneWidget,
    );
    expect(escort, findsNothing);
    await tester.tap(main);
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('100 saved records show the limit notice without capturing', (
    tester,
  ) async {
    final store = _MemoryStore();
    for (var index = 0; index < maxCompositionRecordsPerAccount; index++) {
      store.records.add(
        CompositionRecord(
          id: 'record-$index',
          createdAt: DateTime(2026, 9, 23),
          note: '',
          name: '编队 $index',
          fleetForm: '普通舰队',
          targetMap: '',
          fleetIds: const [1],
          landBaseCount: 0,
        ),
      );
    }
    var captures = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              initiallyShowSaved: false,
              state: const GameState(
                memberId: 7,
                hasPortData: true,
                hasEquipmentInventory: true,
                ships: {1: OwnedShip(id: 1, masterId: 100, level: 99)},
                masterShips: {
                  100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
                },
                fleets: [
                  Fleet(id: 1, name: '第一舰队', shipIds: [1]),
                ],
              ),
              recordStore: store,
              capturePng: (_) async {
                captures++;
                return Uint8List(0);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pump();
    expect(find.text('已经达到最大记录数量'), findsOneWidget);
    expect(captures, 0);
    expect(store.records, hasLength(100));
  });

  testWidgets('storage limit after a stale UI count shows the same notice', (
    tester,
  ) async {
    final store = _MemoryStore()..limitReached = true;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              initiallyShowSaved: false,
              state: const GameState(
                memberId: 7,
                hasPortData: true,
                hasEquipmentInventory: true,
                ships: {1: OwnedShip(id: 1, masterId: 100, level: 99)},
                masterShips: {
                  100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
                },
                fleets: [
                  Fleet(id: 1, name: '第一舰队', shipIds: [1]),
                ],
              ),
              recordStore: store,
              capturePng: (_) async => Uint8List.fromList(
                img.encodePng(img.Image(width: 1, height: 1)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pumpAndSettle();
    expect(find.text('已经达到最大记录数量'), findsOneWidget);
    expect(store.records, isEmpty);
  });

  testWidgets('record capture freezes selections and stored metadata', (
    tester,
  ) async {
    final store = _MemoryStore();
    final capture = Completer<Uint8List>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              initiallyShowSaved: false,
              state: const GameState(
                memberId: 7,
                hasPortData: true,
                hasEquipmentInventory: true,
                ships: {
                  1: OwnedShip(id: 1, masterId: 100, level: 99),
                  2: OwnedShip(id: 2, masterId: 101, level: 80),
                },
                masterShips: {
                  100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
                  101: MasterShip(id: 101, name: '能代改二', shipTypeId: 3),
                },
                fleets: [
                  Fleet(id: 1, name: '第一舰队', shipIds: [1]),
                  Fleet(id: 2, name: '第二舰队', shipIds: [2]),
                ],
              ),
              recordStore: store,
              capturePng: (_) => capture.future,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-fleet-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-target-event')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('composition-event-map')),
      'E3',
    );
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pump();
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('composition-fleet-2')))
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('composition-target-none')))
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(const Key('composition-planes-hidden')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('composition-event-map')))
          .enabled,
      isFalse,
    );
    capture.complete(
      Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1))),
    );
    await tester.pumpAndSettle();
    expect(store.records.single.targetMap, 'E3');
    expect(store.records.single.fleetIds, [1, 3, 4]);
    expect(store.records.single.planeCountMode, 'maximum');
    expect(
      deserializeCompositionSnapshot(
        store.records.single.snapshotJson!,
      ).fleets.map((fleet) => fleet.id),
      [1],
    );
  });

  testWidgets('record can be saved with no target map', (tester) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              initiallyShowSaved: false,
              state: const GameState(
                memberId: 7,
                hasPortData: true,
                hasEquipmentInventory: true,
                ships: {1: OwnedShip(id: 1, masterId: 100, level: 99)},
                masterShips: {
                  100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
                },
                fleets: [
                  Fleet(id: 1, name: '第一舰队', shipIds: [1]),
                ],
              ),
              recordStore: store,
              capturePng: (_) async => Uint8List.fromList(
                img.encodePng(img.Image(width: 1, height: 1)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-target-map')), findsNothing);
    await tester.tap(find.byKey(const Key('composition-target-normal')));
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pumpAndSettle();
    expect(store.records, isEmpty);
    await tester.ensureVisible(
      find.byKey(const Key('composition-target-event')),
    );
    await tester.tap(find.byKey(const Key('composition-target-event')));
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pumpAndSettle();
    expect(store.records, isEmpty);
    await tester.ensureVisible(
      find.byKey(const Key('composition-target-none')),
    );
    await tester.tap(find.byKey(const Key('composition-target-none')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    expect(find.text('保存后名称：无目标海域'), findsOneWidget);
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pumpAndSettle();
    expect(store.records.single.targetMap, isEmpty);
    expect(store.records.single.name, '无目标海域');
    expect(store.records.single.note, isEmpty);
    expect(find.text('无目标海域'), findsOneWidget);
    expect(find.byKey(const Key('composition-record-tag-one')), findsNothing);
    expect(store.records.single.effectiveMapTag, 'none');
  });

  testWidgets('normal and event maps save without a custom name', (
    tester,
  ) async {
    final store = _MemoryStore();
    final catalog = SortieMapCatalogController(
      data: const SortieMapCatalogData(
        version: 1,
        source: 'test',
        maps: [
          SortieMapInfo(
            id: '1-1',
            nameJa: '鎮守府正面海域',
            difficulty: 1,
            coverAsset: '',
            mapAsset: '',
            source: null,
            nodes: [],
          ),
        ],
      ),
      updater: const _NoopCatalogUpdater(),
    );
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              initiallyShowSaved: false,
              state: const GameState(
                memberId: 7,
                hasPortData: true,
                hasEquipmentInventory: true,
                ships: {1: OwnedShip(id: 1, masterId: 100, level: 99)},
                masterShips: {
                  100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
                },
                fleets: [
                  Fleet(id: 1, name: '第一舰队', shipIds: [1]),
                ],
              ),
              recordStore: store,
              sortieMapCatalogController: catalog,
              capturePng: (_) async => Uint8List.fromList(
                img.encodePng(img.Image(width: 1, height: 1)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-target-normal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-target-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-1 鎮守府正面海域').last);
    await tester.pumpAndSettle();
    expect(find.text('保存后名称：1-1'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pumpAndSettle();
    expect(store.records.single.name, '1-1');
    expect(store.records.single.effectiveMapTag, 'normal:1-1');
    await tester.tap(find.byKey(const Key('composition-new-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-target-event')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('composition-event-map')),
      'E3',
    );
    await tester.pump();
    expect(find.text('保存后名称：E3'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('composition-save-record')),
    );
    await tester.tap(find.byKey(const Key('composition-save-record')));
    await tester.pumpAndSettle();
    expect(store.records.last.name, 'E3');
    expect(store.records.last.effectiveMapTag, 'event');
  });

  testWidgets('saved records use a 2:8 library without duplicate title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = _MemoryStore();
    store.records.add(
      CompositionRecord(
        id: 'one',
        createdAt: DateTime(2026, 9, 23),
        note: '全员最速',
        fleetForm: '普通舰队',
        targetMap: '1-1 鎮守府正面海域',
        fleetIds: const [1, 2],
        landBaseCount: 1,
      ),
    );
    store.images['one'] = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              state: const GameState(memberId: 7),
              recordStore: store,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final search = tester.getRect(find.byKey(const Key('composition-search')));
    final filter = tester.getRect(find.byKey(const Key('composition-filter')));
    final detail = tester.getRect(
      find.byKey(const Key('composition-saved-preview')),
    );
    expect(search.width, closeTo(filter.width, 1));
    expect(search.bottom, lessThan(filter.top));
    expect(search.width / (detail.width + search.width), closeTo(.2, .04));
    expect(find.text('1-1 未命名编队'), findsOneWidget);
    expect(find.text('1-1'), findsNothing);
    expect(find.text('全员最速'), findsNothing);
    expect(store.records.single.note, '全员最速');
    expect(find.text('编成记录'), findsNothing);
    expect(find.text('普通舰队'), findsNothing);
    expect(find.text('第 1 舰队'), findsNothing);
    expect(find.byKey(const Key('composition-edit-note')), findsNothing);
    expect(find.byKey(const Key('composition-record-note')), findsNothing);
    tester.view.physicalSize = const Size(560, 700);
    await tester.pumpAndSettle();
    final portraitSearch = tester.getRect(
      find.byKey(const Key('composition-search')),
    );
    final portraitFilter = tester.getRect(
      find.byKey(const Key('composition-filter')),
    );
    expect(portraitSearch.width, closeTo(portraitFilter.width, 1));
    expect(portraitSearch.right, lessThan(portraitFilter.left));
    expect(portraitSearch.center.dy, closeTo(portraitFilter.center.dy, 2));
    final recordHeight = tester
        .getRect(find.byKey(const Key('composition-record-one')))
        .height;
    expect(portraitSearch.height, closeTo(recordHeight, 2));
    expect(portraitFilter.height, closeTo(recordHeight, 2));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('composition-search')))
          .style
          ?.fontSize,
      14,
    );
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: find.byKey(const Key('composition-filter')),
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .style
          ?.fontSize,
      14,
    );
    expect(
      tester.getCenter(find.text('筛选')).dy,
      closeTo(portraitFilter.center.dy, 2),
    );
    expect(
      tester.getTopLeft(find.text('筛选')).dx - portraitFilter.left,
      closeTo(tester.getTopLeft(find.text('搜索')).dx - portraitSearch.left, 2),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('composition-filter')),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composition-new-record')), findsOneWidget);
    expect(find.byKey(const Key('composition-export-record')), findsOneWidget);
    expect(find.byKey(const Key('composition-delete-record')), findsOneWidget);
    tester.view.physicalSize = const Size(360, 700);
    await tester.pumpAndSettle();
    final modeBar = tester.getRect(
      find.byKey(const Key('composition-mode-bar')),
    );
    final newRecord = tester.getRect(
      find.byKey(const Key('composition-new-record')),
    );
    expect(modeBar.width, greaterThanOrEqualTo(190));
    expect(modeBar.right, lessThan(newRecord.left));
    expect(newRecord.size, const Size(32, 32));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('composition-new-record')))
          .style
          ?.shape
          ?.resolve({}),
      isA<CircleBorder>(),
    );
    expect(find.text('新建记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone portrait caps saved list at half height and scrolls it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = _MemoryStore();
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    for (var index = 0; index < 20; index++) {
      final id = 'record-$index';
      store.records.add(
        CompositionRecord(
          id: id,
          createdAt: DateTime(2026, 9, 23),
          name: '编队 $index',
          note: '',
          fleetForm: '普通舰队',
          targetMap: '',
          fleetIds: const [1],
          landBaseCount: 0,
        ),
      );
      store.images[id] = png;
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              state: const GameState(memberId: 7),
              recordStore: store,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('composition-record-list-scroll'));
    final detail = find.byKey(const Key('composition-record-detail-scroll'));
    expect(
      tester.getSize(list).height,
      lessThanOrEqualTo(tester.getSize(detail).height),
    );
    final listPosition = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position;
    final detailPosition = tester
        .state<ScrollableState>(
          find.descendant(of: detail, matching: find.byType(Scrollable)).first,
        )
        .position;
    expect(listPosition.maxScrollExtent, greaterThan(0));
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(listPosition.pixels, greaterThan(0));
    expect(detailPosition.pixels, 0);
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    final wideListPosition = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position;
    final wideDetailPosition = tester
        .state<ScrollableState>(
          find.descendant(of: detail, matching: find.byType(Scrollable)).first,
        )
        .position;
    expect(wideListPosition.maxScrollExtent, greaterThan(0));
    wideListPosition.jumpTo(0);
    await tester.pump();
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(wideListPosition.pixels, greaterThan(0));
    expect(wideDetailPosition.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('record map filter is a single ordered scrolling dropdown', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = _MemoryStore();
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    for (final (id, name, tag, target) in [
      ('none', '日常编队', 'none', ''),
      ('event', '活动编队', 'event', 'E3'),
      ('normal', '任务编队', 'normal:1-1', '1-1 鎮守府正面海域'),
    ]) {
      store.records.add(
        CompositionRecord(
          id: id,
          createdAt: DateTime(2026, 9, 23),
          name: name,
          note: '',
          fleetForm: '普通舰队',
          targetMap: target,
          fleetIds: const [1],
          landBaseCount: 0,
          mapTag: tag,
        ),
      );
      store.images[id] = png;
    }
    final catalog = SortieMapCatalogController(
      data: const SortieMapCatalogData(
        version: 1,
        source: 'test',
        maps: [
          SortieMapInfo(
            id: '1-1',
            nameJa: '鎮守府正面海域',
            difficulty: 1,
            coverAsset: '',
            mapAsset: '',
            source: null,
            nodes: [],
          ),
          SortieMapInfo(
            id: '1-2',
            nameJa: '南西諸島沖',
            difficulty: 1,
            coverAsset: '',
            mapAsset: '',
            source: null,
            nodes: [],
          ),
        ],
      ),
      updater: const _NoopCatalogUpdater(),
    );
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              state: const GameState(memberId: 7),
              recordStore: store,
              sortieMapCatalogController: catalog,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-filter')));
    await tester.pumpAndSettle();
    final none = find.byKey(const Key('composition-filter-none')).last;
    final event = find.byKey(const Key('composition-filter-event')).last;
    final map = find.byKey(const Key('composition-filter-map-1-1')).last;
    final all = find.byKey(const Key('composition-filter-all')).last;
    expect(tester.getTopLeft(all).dy, lessThan(tester.getTopLeft(none).dy));
    expect(tester.getTopLeft(none).dy, lessThan(tester.getTopLeft(event).dy));
    expect(tester.getTopLeft(event).dy, lessThan(tester.getTopLeft(map).dy));
    await tester.tap(event);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-record-event')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-none')), findsNothing);
    expect(find.byKey(const Key('composition-record-normal')), findsNothing);
    await tester.tap(find.byKey(const Key('composition-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-filter-map-1-1')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-record-normal')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-event')), findsNothing);
    await tester.tap(find.byKey(const Key('composition-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composition-filter-all')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-record-none')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-event')), findsOneWidget);
    expect(find.byKey(const Key('composition-record-normal')), findsOneWidget);
  });

  testWidgets(
    'saved tab is default; current composition creates immutable record and exports it',
    (tester) async {
      final store = _MemoryStore();
      final port = _Port();
      final catalog = SortieMapCatalogController(
        data: const SortieMapCatalogData(
          version: 1,
          source: 'test',
          maps: [
            SortieMapInfo(
              id: '1-1',
              nameJa: '鎮守府正面海域',
              difficulty: 1,
              coverAsset: '',
              mapAsset: '',
              source: null,
              nodes: [],
            ),
          ],
        ),
        updater: const _NoopCatalogUpdater(),
      );
      addTearDown(catalog.dispose);
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TopNoticeHost(
            child: Scaffold(
              body: CompositionImagePage(
                state: const GameState(
                  memberId: 7,
                  hasPortData: true,
                  hasEquipmentInventory: true,
                  ships: {
                    1: OwnedShip(id: 1, masterId: 100, level: 99, luck: 42),
                  },
                  masterShips: {
                    100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
                  },
                  fleets: [
                    Fleet(id: 1, name: '第一舰队', shipIds: [1]),
                  ],
                ),
                recordStore: store,
                sortieMapCatalogController: catalog,
                port: port,
                capturePng: (RenderRepaintBoundary _) async => png,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('还没有编队记录'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('composition-mode-bar'))).height,
        38,
      );
      expect(
        tester.getSize(find.byKey(const Key('composition-new-record'))).height,
        32,
      );
      final savedCount = find.descendant(
        of: find.byKey(const Key('composition-mode-bar')),
        matching: find.text('0'),
      );
      expect(tester.widget<Text>(savedCount).style?.fontSize, 12);
      expect(
        tester.widget<Text>(savedCount).style?.fontWeight,
        FontWeight.w800,
      );
      await tester.tap(find.byKey(const Key('composition-new-record')));
      await tester.pump();
      for (final label in ['舰队', '编队形式', '目标海域', '基地航空队', '搭载数', '编队名称']) {
        final title = find.descendant(
          of: find.byKey(const Key('composition-controls')),
          matching: find.text(label),
        );
        expect(tester.widget<Text>(title).style?.fontWeight, FontWeight.w700);
      }
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composition-name')))
            .decoration
            ?.counterStyle
            ?.fontWeight,
        FontWeight.w700,
      );
      expect(find.text('编队名称'), findsOneWidget);
      expect(find.byKey(const Key('composition-note')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composition-name')))
            .decoration
            ?.labelText,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composition-name')))
            .decoration
            ?.hintText,
        '自由填写编队名称',
      );
      expect(find.text('矢矧改二乙'), findsOneWidget);
      expect(find.text('运 42'), findsOneWidget);
      expect(find.byKey(const Key('composition-planes-current')), findsNothing);
      expect(
        find.byKey(const Key('composition-form-segmented')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('composition-target-segmented')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('composition-form-2')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('composition-form-4'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('composition-form-0'))).dy,
        ),
      );
      await tester.tap(find.byKey(const Key('composition-target-event')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composition-event-map')), findsOneWidget);
      expect(find.byKey(const Key('composition-name-prefix')), findsNothing);
      expect(
        tester.widget<Text>(find.text('难度（可选）')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composition-event-map')))
            .decoration
            ?.counterStyle
            ?.fontWeight,
        FontWeight.w700,
      );
      await tester.enterText(
        find.byKey(const Key('composition-event-map')),
        '2026 夏活 E3-3',
      );
      await tester.ensureVisible(
        find.byKey(const Key('composition-difficulty-甲')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composition-difficulty-甲')));
      await tester.enterText(find.byKey(const Key('composition-name')), '斩杀编队');
      await tester.pump();
      expect(find.text('保存后名称：2026 夏活 E3-3 · 甲 斩杀编队'), findsOneWidget);
      await tester.tap(find.byKey(const Key('composition-target-normal')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('composition-name')), '任务编队');
      expect(find.byKey(const Key('composition-note')), findsNothing);
      tester.testTextInput.hide();
      await tester.ensureVisible(
        find.byKey(const Key('composition-target-map')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composition-target-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1-1 鎮守府正面海域').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composition-name-prefix')), findsNothing);
      expect(find.text('1-1'), findsNothing);
      expect(find.text('保存后名称：1-1 任务编队'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('composition-save-record')),
      );
      await tester.tap(find.byKey(const Key('composition-save-record')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(store.records.single.note, isEmpty);
      expect(store.records.single.name, '1-1 任务编队');
      expect(store.records.single.fleetForm, '水上打击部队');
      expect(store.records.single.targetMap, '1-1 鎮守府正面海域');
      expect(find.text('1-1 任务编队'), findsOneWidget);
      expect(find.text('1-1'), findsNothing);
      expect(store.records.single.effectiveMapTag, 'normal:1-1');
      expect(find.byKey(const Key('composition-saved-table')), findsOneWidget);
      expect(store.records.single.snapshotJson, isNotNull);
      expect(find.byKey(const Key('composition-image-header')), findsNothing);
      expect(find.byKey(const Key('composition-generated-at')), findsNothing);
      expect(find.text('矢矧改二乙'), findsOneWidget);
      final create = tester.getRect(
        find.byKey(const Key('composition-new-record')),
      );
      final export = tester.getRect(
        find.byKey(const Key('composition-export-record')),
      );
      final delete = tester.getRect(
        find.byKey(const Key('composition-delete-record')),
      );
      expect(create.right, lessThan(export.left));
      expect(export.right, lessThan(delete.left));
      expect(create.center.dy, closeTo(export.center.dy, 1));
      expect(export.center.dy, closeTo(delete.center.dy, 1));
      await tester.tap(find.byKey(const Key('composition-export-record')));
      await tester.pump();
      expect(port.bytes, png);
      expect(find.byKey(const Key('composition-edit-note')), findsNothing);
      expect(store.records.single.note, isEmpty);
      expect(store.records.single.targetMap, '1-1 鎮守府正面海域');
      expect(find.text('1-1 任务编队'), findsOneWidget);
      expect(store.images['one'], png);
      await tester.tap(find.byKey(const Key('composition-delete-record')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除记录').last);
      await tester.pumpAndSettle();
      expect(store.records, isEmpty);
      expect(store.images, isEmpty);
    },
  );

  testWidgets('restored data-only composition exports a freshly rendered PNG', (
    tester,
  ) async {
    final store = _MemoryStore();
    final port = _Port();
    final output = Uint8List.fromList([9, 8, 7]);
    store.records.add(
      CompositionRecord(
        id: 'restored',
        createdAt: DateTime.utc(2026, 9, 26),
        note: '',
        name: 'restored fleet',
        fleetForm: '通常',
        targetMap: '',
        fleetIds: const [],
        landBaseCount: 0,
        snapshotJson: serializeCompositionSnapshot(
          const GameState(memberId: 7),
          fleetIds: {},
          landBaseAreaId: null,
          landBaseIds: {},
        ),
      ),
    );
    // A restore may leave a same-ID image from the old local record when
    // image cleanup was interrupted. It must not override the new snapshot.
    store.images['restored'] = Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: CompositionImagePage(
              state: const GameState(memberId: 7),
              recordStore: store,
              port: port,
              capturePng: (_) async => output,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composition-saved-table')), findsOneWidget);
    final export = find.byKey(const Key('composition-export-record'));
    expect(tester.widget<OutlinedButton>(export).onPressed, isNotNull);
    await tester.tap(export);
    await tester.pump();
    await tester.pump();
    expect(port.bytes, output);
  });
}

class _Port implements CompositionImagePort {
  Uint8List? bytes;
  @override
  Future<String> savePng(Uint8List data) async {
    bytes = data;
    return 'saved';
  }
}

class _MemoryStore implements CompositionRecordStore {
  final records = <CompositionRecord>[];
  final images = <String, Uint8List>{};
  bool limitReached = false;
  @override
  Future<List<CompositionRecord>> load(int memberId) async => List.of(records);
  @override
  Future<CompositionRecord> create({
    required int memberId,
    required Uint8List png,
    required String note,
    required String name,
    required String fleetForm,
    required String targetMap,
    required List<int> fleetIds,
    required int landBaseCount,
    required DateTime createdAt,
    String? snapshotJson,
    int? landBaseAreaId,
    List<int> landBaseIds = const [],
    String planeCountMode = 'maximum',
    String mapTag = '',
  }) async {
    if (limitReached) throw const CompositionRecordLimitReachedException();
    final record = CompositionRecord(
      id: records.isEmpty ? 'one' : 'record-${records.length + 1}',
      createdAt: createdAt,
      note: note,
      name: name,
      fleetForm: fleetForm,
      targetMap: targetMap,
      fleetIds: fleetIds,
      landBaseCount: landBaseCount,
      snapshotJson: snapshotJson,
      landBaseAreaId: landBaseAreaId,
      landBaseIds: landBaseIds,
      planeCountMode: planeCountMode,
      mapTag: mapTag,
    );
    records.add(record);
    images[record.id] = Uint8List.fromList(png);
    return record;
  }

  @override
  Future<Uint8List> readPng(int memberId, String id) async => images[id]!;
  @override
  Future<void> updateNote(int memberId, String id, String note) async {
    final index = records.indexWhere((record) => record.id == id);
    records[index] = records[index].withNote(note);
  }

  @override
  Future<void> delete(int memberId, String id) async {
    records.removeWhere((record) => record.id == id);
    images.remove(id);
  }
}

final class _NoopCatalogUpdater implements SortieMapCatalogUpdateClient {
  const _NoopCatalogUpdater();
  @override
  Future<SortieMapCatalogUpdateResult> checkAndUpdate({
    required SortieMapCatalogData current,
  }) async => SortieMapCatalogUpToDate(current.versionInfo, sourceHost: 'test');
}
