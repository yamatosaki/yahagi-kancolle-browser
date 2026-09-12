import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/development/development_workbench_state_store.dart';
import 'package:yahagi_kancolle_browser/src/development/development_repository.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_page.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart'
    show ConstructionCenterMode;
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  setUp(() => AccountSession.shared.selectMember(1001));
  testWidgets(
    'development workbench shows calculator table without old groups',
    (tester) async {
      await tester.pumpWidget(_app(size: const Size(1000, 700)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('development-command-card')), findsOneWidget);
      expect(
        find.byKey(const Key('development-mode-calculator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('development-mode-formula')), findsOneWidget);
      expect(find.byKey(const Key('development-inline-search')), findsNothing);
      expect(find.text('开发工作台'), findsNothing);
      expect(find.byIcon(Icons.precision_manufacturing), findsNothing);
      final commandCard = tester.widget<Container>(
        find.byKey(const Key('development-command-card')),
      );
      final cardDecoration = commandCard.decoration as BoxDecoration;
      expect(cardDecoration.color, const Color(0xff142735));
      expect(
        find.descendant(
          of: find.byKey(const Key('development-workbench-mode-tabs')),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      expect(find.text('出货概率'), findsOneWidget);
      expect(find.text('舰上攻击机'), findsOneWidget);
      expect(find.text('#8'), findsNothing);
      expect(find.textContaining('其他出货'), findsNothing);
      expect(find.textContaining('被替换出货'), findsNothing);
      expect(find.byKey(const Key('development-minimum-7')), findsNothing);
      for (var index = 0; index < 4; index++) {
        expect(
          find.byKey(Key('development-resource-icon-$index')),
          findsOneWidget,
        );
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(Key('development-resource-$index')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.decoration?.labelText, isNull);
        expect(
          find.byKey(Key('development-resource-semantics-$index')),
          findsOneWidget,
        );
      }

      final tableWidth = tester.getSize(find.byType(DataTable)).width;
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.headingRowHeight, 34);
      expect(table.dataRowMinHeight, 44);
      expect(table.dataRowMaxHeight, 44);
      final outputSortLabel = tester.widget<Text>(find.text('最终概率 ▼'));
      expect(outputSortLabel.style?.color, const Color(0xffffc85a));
      expect(
        find.descendant(
          of: find.byKey(const Key('development-output-probability-sort')),
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsNothing,
      );
      table.columns[2].onSort!(2, false);
      await tester.pump();
      expect(find.text('最终概率 ▲'), findsOneWidget);
      final equipmentName = tester.widget<Text>(find.text('测试舰攻'));
      expect(equipmentName.style?.fontSize, 12);
      expect(equipmentName.style?.fontWeight, FontWeight.w800);
      final outputIcon = tester.widget<EquipmentTypeIconImage>(
        find.byType(EquipmentTypeIconImage).first,
      );
      expect(outputIcon.width, 23);
      expect(outputIcon.height, 23);
      final containerWidth = tester
          .getSize(find.byKey(const Key('development-output-table')))
          .width;
      expect(tableWidth, greaterThanOrEqualTo(containerWidth - 2));
    },
  );

  testWidgets(
    'equipment names follow the current locale instead of game data',
    (tester) async {
      await tester.pumpWidget(
        _app(
          size: const Size(1000, 700),
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('測試艦攻'), findsOneWidget);
      expect(find.text('テスト艦攻'), findsNothing);
    },
  );

  testWidgets('workbench switches modes and preserves calculator resources', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(1000, 700)));
    await tester.pumpAndSettle();
    final fuel = find.byType(TextFormField).first;
    await tester.enterText(fuel, '20');
    await tester.pump();

    await tester.tap(find.byKey(const Key('development-mode-formula')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('development-open-target-picker')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('development-output-table')), findsNothing);

    await tester.tap(find.byKey(const Key('development-mode-calculator')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-output-table')), findsOneWidget);
    expect(find.text('20'), findsWidgets);
  });

  testWidgets('workbench state survives page recreation', (tester) async {
    final store = _MemoryDevelopmentWorkbenchStateStore();
    await tester.pumpWidget(
      _app(size: const Size(1000, 700), stateStore: store),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '20');
    await tester.pump();
    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-target-close')));
    await tester.pumpAndSettle();

    final tableFinder = find.byKey(const Key('development-recipe-table'));
    tester.widget<DataTable>(tableFinder).columns[5].onSort!(5, true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(size: const Size(1000, 700), stateStore: store),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-recipe-table')), findsOneWidget);
    expect(find.widgetWithText(InputChip, '测试舰攻'), findsOneWidget);
    expect(find.text('总资源 ▲'), findsOneWidget);

    await tester.tap(find.byKey(const Key('development-mode-calculator')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '20',
    );
  });

  testWidgets('target dialog uses two columns and keeps search in a button', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-target-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('development-equipment-type-filter')),
      findsNothing,
    );
    expect(find.text('舰上攻击机'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('#8'), findsNothing);
    expect(find.textContaining('ID '), findsNothing);
    expect(find.byKey(const Key('development-inline-search')), findsNothing);

    await tester.tap(find.byKey(const Key('development-equipment-type-other')));
    await tester.pumpAndSettle();
    expect(find.text('测试喷气机'), findsOneWidget);
    expect(find.text('测试直升机'), findsOneWidget);

    await tester.tap(find.byKey(const Key('development-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-search-dialog')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('development-search-dialog')),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a target produces recipe rows that can be applied', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(1000, 700)));
    await tester.pumpAndSettle();
    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-target-dialog')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('development-target-dialog')),
        matching: find.text('已选 1 件'),
      ),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(const Key('development-target-dialog'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('development-recipe-row-0')), findsOneWidget);
    final tableFinder = find.byKey(const Key('development-recipe-table'));
    final table = tester.widget<DataTable>(tableFinder);
    expect(table.headingRowHeight, 34);
    expect(table.dataRowMinHeight, 44);
    expect(table.dataRowMaxHeight, 44);
    expect(table.horizontalMargin, 8);
    expect(table.columnSpacing, 16);
    expect(table.columns.length, 9);
    expect(table.sortColumnIndex, isNull);
    final defaultSortLabel = tester.widget<Text>(find.text('出货率 ▼'));
    expect(defaultSortLabel.style?.color, const Color(0xffffc85a));
    const resourceLabels = ['燃料', '弹药', '钢材', '铝土'];
    for (var index = 0; index < 4; index++) {
      final resourceIcon = find.byKey(
        Key('development-recipe-resource-$index'),
      );
      expect(resourceIcon, findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: resourceIcon, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, resourceLabels[index]);
      expect(semantics.properties.image, isTrue);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: resourceIcon, matching: find.byType(Tooltip)).first,
      );
      expect(tooltip.message, resourceLabels[index]);
    }
    expect(find.text('油'), findsNothing);
    expect(find.text('弹'), findsNothing);
    expect(find.text('钢'), findsNothing);
    expect(find.text('铝'), findsNothing);
    expect((table.columns.last.label as Text).data, '池类型');
    expect((table.rows.first.cells.last.child as Text).data, '铝土系');
    final frame = find.byKey(const Key('development-recipe-table-frame'));
    final formulaBody = find.byKey(const Key('development-formula-body'));
    expect(frame, findsOneWidget);
    expect(formulaBody, findsOneWidget);
    expect(tester.getSize(frame).width, tester.getSize(formulaBody).width);
    expect(
      find.descendant(of: frame, matching: find.text('可用公式')),
      findsOneWidget,
    );
    expect(find.text('可用公式'), findsOneWidget);

    table.columns[5].onSort!(5, true);
    await tester.pump();
    expect(find.text('总资源 ▲'), findsOneWidget);
    expect(find.text('出货率'), findsOneWidget);
    tester.widget<DataTable>(tableFinder).columns[6].onSort!(6, true);
    await tester.pump();
    expect(find.text('出货率 ▼'), findsOneWidget);
    expect(find.text('总资源'), findsOneWidget);
    tester.widget<DataTable>(tableFinder).columns[7].onSort!(7, true);
    await tester.pump();
    expect(find.text('失败率 ▲'), findsOneWidget);
    expect(find.text('出货率'), findsOneWidget);
    await tester.tap(find.byKey(const Key('development-recipe-row-0')));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsWidgets);
    expect(find.text('铝土系'), findsWidgets);
    expect(
      tester
          .getSemantics(find.byKey(const Key('development-recipe-row-0')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('recipe table scrolls horizontally on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();
    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-target-close')));
    await tester.pumpAndSettle();

    final horizontalScrollView = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollView, findsOneWidget);
    final scrollable = find.descendant(
      of: horizontalScrollView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
  });

  testWidgets('resource input updates immediately and normalizes on blur', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(1000, 700)));
    await tester.pumpAndSettle();
    final fuel = find.byType(TextFormField).first;

    await tester.enterText(fuel, '20');
    await tester.pump();
    expect(tester.widget<TextFormField>(fuel).controller!.text, '20');

    await tester.enterText(fuel, '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextFormField>(fuel).controller!.text, '10');
  });

  testWidgets('incompatible equipment stays visible but disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();
    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-15')));
    await tester.pumpAndSettle();

    final incompatible = find.byKey(const Key('development-equipment-9'));
    expect(incompatible, findsOneWidget);
    expect(tester.widget<InkWell>(incompatible).onTap, isNull);
  });

  testWidgets('target dialog preserves multi-selection across types', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(700, 844)));
    await tester.pumpAndSettle();
    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('development-equipment-type-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-8')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('development-target-dialog')),
        matching: find.text('已选 2 件'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('development-target-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('development-target-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('development-target-dialog')), findsNothing);
    expect(find.text('测试舰攻'), findsOneWidget);
    expect(find.text('测试雷达'), findsOneWidget);

    final attackIconFinder = find.byKey(
      const Key('development-target-chip-icon-7'),
    );
    final radarIconFinder = find.byKey(
      const Key('development-target-chip-icon-8'),
    );
    expect(attackIconFinder, findsOneWidget);
    expect(radarIconFinder, findsOneWidget);
    final attackIcon = tester.widget<EquipmentTypeIconImage>(attackIconFinder);
    final radarIcon = tester.widget<EquipmentTypeIconImage>(radarIconFinder);
    expect(attackIcon.iconId, 5);
    expect(radarIcon.iconId, 11);
    expect(attackIcon.width, 23);
    expect(attackIcon.height, 23);

    tester
        .widget<InputChip>(find.widgetWithText(InputChip, '测试舰攻'))
        .onDeleted!();
    await tester.pumpAndSettle();
    expect(attackIconFinder, findsNothing);
    expect(find.text('测试舰攻'), findsNothing);
  });

  testWidgets('search trims confirmation and cancel preserves prior query', (
    tester,
  ) async {
    await tester.pumpWidget(_app(size: const Size(390, 844)));
    await tester.pumpAndSettle();
    await _openFormula(tester);
    await tester.tap(find.byKey(const Key('development-open-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-equipment-type-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('development-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('development-search-dialog')),
        matching: find.byType(TextField),
      ),
      '  雷达  ',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '雷达'), findsOneWidget);

    await tester.tap(find.byKey(const Key('development-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('development-search-dialog')),
        matching: find.byType(TextField),
      ),
      '主炮',
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '雷达'), findsOneWidget);
  });

  testWidgets('unsupported current flagship keeps pool and shows notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(size: const Size(1000, 700), state: _stateWithUnknownFlagship),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '当前旗舰: 未知旗舰'));
    await tester.pump();

    expect(find.text('当前旗舰没有可用的开发池，已保留原选择'), findsOneWidget);
  });
}

Future<void> _openFormula(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('development-mode-formula')));
  await tester.pumpAndSettle();
}

Widget _app({
  required Size size,
  GameState state = _state,
  DevelopmentWorkbenchStateStore? stateStore,
  Locale locale = const Locale('zh'),
}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: TopNoticeHost(
      child: _TestAppHost(
        state: state,
        stateStore: stateStore ?? _MemoryDevelopmentWorkbenchStateStore(),
        repository: DevelopmentRepository(
          loadString: (_) async => jsonEncode(_snapshot),
        ),
      ),
    ),
  ),
);

class _TestAppHost extends StatefulWidget {
  const _TestAppHost({
    required this.state,
    required this.stateStore,
    required this.repository,
  });

  final GameState state;
  final DevelopmentWorkbenchStateStore stateStore;
  final DevelopmentRepository repository;

  @override
  State<_TestAppHost> createState() => _TestAppHostState();
}

class _TestAppHostState extends State<_TestAppHost> {
  late DevelopmentWorkbenchMode _mode =
      widget.stateStore is _MemoryDevelopmentWorkbenchStateStore
      ? (widget.stateStore as _MemoryDevelopmentWorkbenchStateStore)
                .state
                ?.mode ??
            DevelopmentWorkbenchMode.calculator
      : DevelopmentWorkbenchMode.calculator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: WorkspaceContextHeader(
          workspaceIndex: 4,
          state: widget.state,
          selectedFleetId: 1,
          constructionMode: ConstructionCenterMode.development,
          developmentMode: _mode,
          onDevelopmentModeChanged: (mode) => setState(() => _mode = mode),
        ),
      ),
      body: EquipmentDevelopmentPage(
        state: widget.state,
        mode: _mode,
        onModeChanged: (mode) => setState(() => _mode = mode),
        stateStore: widget.stateStore,
        repository: widget.repository,
      ),
    );
  }
}

final class _MemoryDevelopmentWorkbenchStateStore
    implements DevelopmentWorkbenchStateStore {
  DevelopmentWorkbenchState? state;

  @override
  Future<DevelopmentWorkbenchState?> load() async => state;

  @override
  Future<void> save(DevelopmentWorkbenchState state) async {
    this.state = state;
  }
}

const _state = GameState(
  hasPortData: true,
  ships: {1: OwnedShip(id: 1, masterId: 101, level: 1)},
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [1]),
  ],
  masterShips: {101: MasterShip(id: 101, name: '赤城', shipTypeId: 11)},
  masterSlotItems: {
    7: MasterSlotItem(id: 7, name: 'テスト艦攻', type: [0, 0, 8]),
    8: MasterSlotItem(id: 8, name: '测试雷达', type: [0, 0, 12]),
    9: MasterSlotItem(id: 9, name: '测试爆雷', type: [0, 0, 15]),
    10: MasterSlotItem(id: 10, name: '高耗测试装备', type: [0, 0, 1]),
    11: MasterSlotItem(id: 11, name: '测试喷气机', type: [0, 0, 47]),
    12: MasterSlotItem(id: 12, name: '测试直升机', type: [0, 0, 48]),
  },
  masterSlotItemTypes: {8: '舰上攻击机', 12: '小型电探', 15: '爆雷', 1: '小口径主炮'},
);

const _stateWithUnknownFlagship = GameState(
  hasPortData: true,
  ships: {2: OwnedShip(id: 2, masterId: 999, level: 1)},
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [2]),
  ],
  masterShips: {999: MasterShip(id: 999, name: '未知旗舰', shipTypeId: 2)},
);

final _snapshot = <String, Object?>{
  'schema_version': 1,
  'generated_at': '2026-09-01T00:00:00.000Z',
  'source': {
    'repository': 'https://example.invalid',
    'commit': 'abc',
    'hashes': {'pool': 'hash'},
  },
  'summary': {
    'pool_count': 3,
    'selectable_pool_count': 3,
    'equipment_count': 6,
    'negative_pool_count': 0,
    'minimum_resource_pool_count': 0,
  },
  'equipment': [
    {
      'id': 7,
      'name': 'テスト艦攻',
      'names': {'zh': '测试舰攻', 'zh_Hant': '測試艦攻', 'ja': 'テスト艦攻'},
      'type_id': 8,
      'icon_id': 5,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 8,
      'name': '测试雷达',
      'type_id': 12,
      'icon_id': 11,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 9,
      'name': '测试爆雷',
      'type_id': 15,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 10,
      'name': '高耗测试装备',
      'type_id': 1,
      'minimum_resources': [20, 20, 20, 20],
    },
    {
      'id': 11,
      'name': '测试喷气机',
      'type_id': 47,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 12,
      'name': '测试直升机',
      'type_id': 48,
      'minimum_resources': [10, 10, 10, 10],
    },
  ],
  'pools': [
    {
      'pool_key': 'carrier-akagi#1',
      'name': 'carrier-akagi',
      'labels': {'zh': '空母系-赤城', 'zh_Hant': '空母系-赤城', 'ja': '空母系-赤城'},
      'descriptions': {'zh': '赤城', 'zh_Hant': '赤城', 'ja': '赤城'},
      'pool_id': 1,
      'ship_ids': [101],
      'drop_rates': {'7': 2, '8': 1, '10': 1},
      'criteria': {
        'ship_types': <Object?>[],
        'class_types': <Object?>[],
        'ship_names': <Object?>[],
        'ship_ids': <Object?>[],
        'excluded_ship_ids': <Object?>[],
      },
    },
    {
      'pool_key': 'depth-charge#1',
      'name': 'depth-charge',
      'labels': {'zh': '爆雷系', 'zh_Hant': '爆雷系', 'ja': '爆雷系'},
      'descriptions': {'zh': '测试秘书舰', 'zh_Hant': '測試秘書艦', 'ja': 'テスト秘書艦'},
      'pool_id': 1,
      'ship_ids': [202],
      'drop_rates': {'9': 2},
      'criteria': {
        'ship_types': <Object?>[],
        'class_types': <Object?>[],
        'ship_names': <Object?>[],
        'ship_ids': <Object?>[],
        'excluded_ship_ids': <Object?>[],
      },
    },
    {
      'pool_key': 'carrier-akagi#3',
      'name': 'carrier-akagi',
      'labels': {'zh': '空母系-赤城', 'zh_Hant': '空母系-赤城', 'ja': '空母系-赤城'},
      'descriptions': {'zh': '赤城', 'zh_Hant': '赤城', 'ja': '赤城'},
      'pool_id': 3,
      'ship_ids': [101],
      'drop_rates': {'7': 2, '8': 1, '10': 1},
      'criteria': {
        'ship_types': <Object?>[],
        'class_types': <Object?>[],
        'ship_names': <Object?>[],
        'ship_ids': <Object?>[],
        'excluded_ship_ids': <Object?>[],
      },
    },
  ],
  'secretaries': [
    {'ship_id': 101, 'pool_key': 'carrier-akagi#1'},
  ],
};
