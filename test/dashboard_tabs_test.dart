import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_tabs.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';

const _tabs = [
  DashboardTab(
    id: 'fleet',
    label: '舰队',
    title: '舰队状态',
    icon: Icons.sailing,
    badgeCount: 3,
  ),
  DashboardTab(id: 'tasks', label: '任务', title: '任务进度', icon: Icons.assignment),
  DashboardTab(id: 'repair', label: '入渠', title: '入渠与建造', icon: Icons.build),
];

Widget _host({
  required Widget child,
  AppThemeMode mode = AppThemeMode.dark,
  double width = 420,
  double textScale = 1,
}) => MaterialApp(
  theme: createAppTheme(mode: mode),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: 420, child: child),
      ),
    ),
  ),
);

class _Counter extends StatefulWidget {
  const _Counter(this.id);
  final String id;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        key: ValueKey('counter-${widget.id}'),
        onPressed: () => setState(() => count++),
        child: Text('${widget.id}: $count'),
      ),
      Text('tabbed: ${DashboardPresentationScope.isTabbed(context)}'),
      Text('ticker: ${TickerMode.valuesOf(context).enabled}'),
      const SizedBox(height: 1500),
    ],
  );
}

Finder _scroll(String id) => find.byKey(
  PageStorageKey<String>('dashboard-tab-scroll-$id'),
  skipOffstage: false,
);

ScrollController _controller(WidgetTester tester, String id) =>
    tester.widget<SingleChildScrollView>(_scroll(id)).controller!;

void main() {
  testWidgets('uses a compact strip and keeps every supplied module logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: DashboardTabs(
          tabs: _tabs,
          selectedId: 'fleet',
          onSelected: (_) {},
          cardBuilder: (id) => Text('content: $id'),
        ),
      ),
    );
    final bar = find.byKey(const Key('dashboard-tab-bar'));
    expect(tester.getSize(bar).height, inInclusiveRange(30.0, 32.0));
    for (final tab in _tabs) {
      final item = find.byKey(ValueKey('dashboard-tab-${tab.id}'));
      expect(tester.getSize(item).height, inInclusiveRange(30.0, 32.0));
      expect(tester.getSize(item).width, lessThan(100));
      final logo = find.descendant(of: item, matching: find.byIcon(tab.icon!));
      expect(logo, findsOneWidget);
      expect(tester.widget<Icon>(logo).size, 14);
    }
    expect(find.byKey(const Key('dashboard-tabs-edit-order')), findsNothing);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    expect(tester.getSize(bar).width, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press requests layout editing without selecting the tab', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final selected = <String>[];
    final edited = <String>[];
    var parentLongPresses = 0;
    await tester.pumpWidget(
      _host(
        child: GestureDetector(
          onLongPress: () => parentLongPresses++,
          child: DashboardTabs(
            tabs: _tabs,
            selectedId: 'fleet',
            onSelected: selected.add,
            onLongPressTab: edited.add,
            cardBuilder: (id) => Text('content: $id'),
          ),
        ),
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('dashboard-tab-tasks')));
    await tester.pumpAndSettle();
    expect(edited, ['tasks']);
    expect(selected, isEmpty);
    expect(parentLongPresses, 0);
    expect(find.text('content: fleet'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('任务进度'))
          .getSemanticsData()
          .hasAction(SemanticsAction.longPress),
      isTrue,
    );
    expect(find.text('任务进度'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'a slow tab swipe does not enter layout editing or select a tab',
    (tester) async {
      final selected = <String>[];
      final edited = <String>[];
      var parentLongPresses = 0;
      await tester.pumpWidget(
        _host(
          width: 150,
          child: GestureDetector(
            onLongPress: () => parentLongPresses++,
            child: DashboardTabs(
              tabs: _tabs,
              selectedId: 'fleet',
              onSelected: selected.add,
              onLongPressTab: edited.add,
              cardBuilder: (id) => Text('content: $id'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byKey(const Key('dashboard-tab-bar'));
      final controller = tester.widget<SingleChildScrollView>(bar).controller!;
      final initialOffset = controller.offset;
      await tester.timedDrag(
        bar,
        const Offset(-140, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(initialOffset));
      expect(edited, isEmpty);
      expect(selected, isEmpty);
      expect(parentLongPresses, 0);
      expect(find.text('content: fleet'), findsOneWidget);

      final repair = find.byKey(const ValueKey('dashboard-tab-repair'));
      await tester.ensureVisible(repair);
      await tester.pumpAndSettle();
      await tester.longPress(repair);
      await tester.pumpAndSettle();
      expect(edited, ['repair']);
      expect(selected, isEmpty);
      expect(parentLongPresses, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long press remains reachable after scrolling overflowing tabs', (
    tester,
  ) async {
    var edits = 0;
    await tester.pumpWidget(
      _host(
        width: 150,
        child: DashboardTabs(
          tabs: _tabs,
          selectedId: 'fleet',
          onSelected: (_) {},
          onLongPressTab: (_) => edits++,
          cardBuilder: (id) => Text('content: $id'),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('dashboard-tab-bar')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    final repair = find.byKey(const ValueKey('dashboard-tab-repair'));
    await tester.ensureVisible(repair);
    await tester.pumpAndSettle();
    expect(repair.hitTestable(), findsOneWidget);
    await tester.longPress(repair);
    await tester.pumpAndSettle();
    expect(edits, 1);
    expect(find.byKey(const Key('dashboard-tabs-edit-order')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not add a standalone action beside the tab strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: DashboardTabs(
          tabs: _tabs,
          selectedId: 'fleet',
          onSelected: (_) {},
          cardBuilder: (id) => Text('content: $id'),
        ),
      ),
    );
    expect(find.byKey(const Key('dashboard-tabs-edit-order')), findsNothing);
  });

  testWidgets('supports names and logos being customized independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        child: DashboardTabs(
          tabs: const [
            DashboardTab(
              id: 'fleet',
              label: '',
              title: '舰队状态',
              icon: Icons.sailing,
            ),
            DashboardTab(id: 'tasks', label: '任务', title: '任务进度'),
          ],
          selectedId: 'fleet',
          onSelected: (_) {},
          cardBuilder: (id) => Text('content: $id'),
        ),
      ),
    );
    final fleet = find.byKey(const ValueKey('dashboard-tab-fleet'));
    final logo = find.descendant(
      of: fleet,
      matching: find.byIcon(Icons.sailing),
    );
    expect(
      find.descendant(of: fleet, matching: find.byType(Text)),
      findsNothing,
    );
    expect(tester.getSize(fleet).width, 48);
    expect(tester.getCenter(logo).dx, tester.getCenter(fleet).dx);
    final tasks = find.byKey(const ValueKey('dashboard-tab-tasks'));
    expect(
      find.descendant(of: tasks, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(of: tasks, matching: find.text('任务')),
      findsOneWidget,
    );
    expect(find.byTooltip('舰队状态'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects a tab and exposes full titles and badge', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selected = 'fleet';
    await tester.pumpWidget(
      _host(
        child: StatefulBuilder(
          builder: (context, setState) => DashboardTabs(
            tabs: _tabs,
            selectedId: selected,
            onSelected: (id) => setState(() => selected = id),
            cardBuilder: (id) => Text('content: $id'),
            notice: const Text('fixed notice'),
            footer: const Text('page footer'),
          ),
        ),
      ),
    );
    expect(find.text('content: fleet'), findsOneWidget);
    expect(find.byTooltip('舰队状态'), findsOneWidget);
    expect(find.bySemanticsLabel('舰队状态'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('fixed notice'), findsOneWidget);
    expect(find.text('page footer'), findsOneWidget);

    await tester.tap(find.text('任务'));
    await tester.pumpAndSettle();
    expect(selected, 'tasks');
    expect(find.text('content: tasks'), findsOneWidget);
    expect(find.text('content: fleet'), findsNothing);
    expect(find.text('fixed notice'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('retains state and independent scroll offsets between tabs', (
    tester,
  ) async {
    var selected = 'fleet';
    await tester.pumpWidget(
      _host(
        child: StatefulBuilder(
          builder: (context, setState) => DashboardTabs(
            tabs: _tabs,
            selectedId: selected,
            onSelected: (id) => setState(() => selected = id),
            cardBuilder: (id) => _Counter(id),
            notice: const Text('fixed notice'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('counter-fleet')));
    await tester.pump();
    final noticePosition = tester.getTopLeft(find.text('fixed notice'));
    _controller(tester, 'fleet').jumpTo(260);
    await tester.pump();
    expect(tester.getTopLeft(find.text('fixed notice')), noticePosition);

    await tester.tap(find.text('任务'));
    await tester.pumpAndSettle();
    expect(find.text('tabbed: true'), findsOneWidget);
    expect(find.text('ticker: true'), findsOneWidget);
    expect(find.text('ticker: false', skipOffstage: false), findsNWidgets(2));
    expect(_controller(tester, 'tasks').offset, 0);
    expect(_controller(tester, 'fleet'), isNot(_controller(tester, 'tasks')));
    _controller(tester, 'tasks').jumpTo(120);
    await tester.pump();

    await tester.tap(find.text('舰队'));
    await tester.pumpAndSettle();
    expect(_controller(tester, 'fleet').offset, 260);
    expect(_controller(tester, 'tasks').offset, 120);
    _controller(tester, 'fleet').jumpTo(0);
    await tester.pump();
    expect(find.text('fleet: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles empty lists and safely falls back from a hidden tab', (
    tester,
  ) async {
    var visible = _tabs;
    var selected = 'fleet';
    late StateSetter update;
    await tester.pumpWidget(
      _host(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return DashboardTabs(
              tabs: visible,
              selectedId: selected,
              onSelected: (id) => setState(() => selected = id),
              cardBuilder: (id) => _Counter(id),
              notice: const Text('fixed notice'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('任务'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('counter-tasks')));
    await tester.pump();
    update(() {
      visible = [_tabs[2], _tabs[1]];
      selected = 'fleet';
    });
    await tester.pumpAndSettle();
    expect(find.text('repair: 0'), findsOneWidget);
    await tester.tap(find.text('任务'));
    await tester.pump();
    expect(find.text('tasks: 1'), findsOneWidget);

    update(() => visible = []);
    await tester.pumpAndSettle();
    expect(find.text('fixed notice'), findsOneWidget);
    expect(find.byType(_Counter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final mode in AppThemeMode.values) {
    testWidgets('fits 260px with enlarged text in ${mode.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          mode: mode,
          width: 260,
          textScale: 2.5,
          child: DashboardTabs(
            tabs: [
              ..._tabs,
              const DashboardTab(
                id: 'equipment',
                label: 'Equipment inventory',
                title: 'Equipment and aircraft inventory',
                icon: Icons.airplanemode_active,
                badgeCount: 123,
              ),
            ],
            selectedId: 'fleet',
            onSelected: (_) {},
            cardBuilder: (id) => Text('content: $id'),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      final bar = find.byKey(const Key('dashboard-tab-bar'));
      expect(tester.getSize(bar).height, greaterThan(32));
      final item = find.byKey(const ValueKey('dashboard-tab-fleet'));
      final label = find.descendant(of: item, matching: find.text('舰队'));
      final tabBounds = tester.getRect(item);
      final labelBounds = tester.getRect(label);
      expect(labelBounds.top, greaterThanOrEqualTo(tabBounds.top));
      expect(labelBounds.bottom, lessThanOrEqualTo(tabBounds.bottom));
      expect(find.byKey(const Key('dashboard-tabs-edit-order')), findsNothing);
      expect(
        find.byTooltip('Equipment and aircraft inventory'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('dashboard-tab-bar')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
