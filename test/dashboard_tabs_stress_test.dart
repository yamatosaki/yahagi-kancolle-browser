import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_tabs.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';

const _pageIds = ['fleet', 'tasks', 'repair'];
const _allPageIds = [..._pageIds, 'expedition', 'construction', 'records'];

void main() {
  testWidgets(
    'rapid selection and reordering keep drafts with their page IDs',
    (tester) async {
      final host = await _mount(tester);
      final originalStates = <String, _DraftPageState>{};
      for (var index = 0; index < _pageIds.length; index++) {
        final id = _pageIds[index];
        await _editPage(tester, host, id, actions: index + 1);
        originalStates[id] = _pageState(tester, id);
        _pageController(tester, id).jumpTo(130.0 * (index + 1));
        await tester.pump();
      }

      const orders = [
        ['repair', 'fleet', 'tasks'],
        ['tasks', 'repair', 'fleet'],
        ['fleet', 'tasks', 'repair'],
      ];
      for (var index = 0; index < 18; index++) {
        final order = orders[index % orders.length];
        final selected = _pageIds[index % _pageIds.length];
        host.change(ids: order, selected: selected);
        await tester.pump(const Duration(milliseconds: 8));
        expect(find.byKey(ValueKey('draft-page-$selected')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'switch $index');
      }
      await tester.pumpAndSettle();

      for (var index = 0; index < _pageIds.length; index++) {
        final id = _pageIds[index];
        final state = _pageState(tester, id);
        expect(state, same(originalStates[id]));
        expect(state.editor.text, 'saved draft for $id');
        expect(state.actions, index + 1);
        expect(_pageController(tester, id).offset, 130.0 * (index + 1));
      }
      await _unmount(tester);
    },
  );

  testWidgets(
    'removing scrolled current and background pages restores only their offsets',
    (tester) async {
      final host = await _mount(tester);
      final originalStates = <String, _DraftPageState>{};
      const offsets = {'fleet': 120.0, 'tasks': 340.0, 'repair': 740.0};
      for (final id in _pageIds) {
        await _editPage(tester, host, id);
        originalStates[id] = _pageState(tester, id);
        _pageController(tester, id).jumpTo(offsets[id]!);
        await tester.pump();
      }

      host.change(ids: const ['repair', 'fleet']);
      await tester.pumpAndSettle();
      expect(originalStates['tasks']!.mounted, isFalse);
      expect(find.byKey(const ValueKey('draft-page-repair')), findsOneWidget);
      expect(_pageState(tester, 'repair'), same(originalStates['repair']));
      expect(_pageController(tester, 'repair').offset, offsets['repair']);

      // The parent still requests the removed page; the first surviving tab wins.
      host.change(ids: const ['fleet']);
      await tester.pumpAndSettle();
      expect(host.selected, 'repair');
      expect(originalStates['repair']!.mounted, isFalse);
      expect(find.byKey(const ValueKey('draft-page-fleet')), findsOneWidget);
      expect(_pageState(tester, 'fleet'), same(originalStates['fleet']));
      expect(_pageController(tester, 'fleet').offset, offsets['fleet']);

      host.change(ids: const ['tasks', 'fleet', 'repair']);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('draft-page-repair')), findsOneWidget);
      for (final id in ['tasks', 'repair']) {
        final restored = _pageState(tester, id);
        expect(restored, isNot(same(originalStates[id])));
        expect(restored.editor.text, 'new draft for $id');
        expect(restored.actions, 0);
        expect(_pageController(tester, id).offset, offsets[id]);
      }
      expect(_pageState(tester, 'fleet').editor.text, 'saved draft for fleet');
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets('all hidden pages recover independent storage after reordering', (
    tester,
  ) async {
    final host = await _mount(tester);
    final oldStates = <_DraftPageState>[];
    for (var index = 0; index < _pageIds.length; index++) {
      final id = _pageIds[index];
      await _editPage(tester, host, id);
      oldStates.add(_pageState(tester, id));
      _pageController(tester, id).jumpTo(210.0 * (index + 1));
      await tester.pump();
    }

    host.change(ids: const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-tabs-edit-order')), findsNothing);
    expect(find.byKey(const Key('dashboard-tab-bar')), findsNothing);
    expect(find.byType(_DraftPage, skipOffstage: false), findsNothing);
    expect(find.text('fixed notice'), findsOneWidget);
    expect(find.text('page footer'), findsOneWidget);
    expect(oldStates.every((state) => !state.mounted), isTrue);

    host.change(ids: const ['repair', 'fleet', 'tasks'], selected: 'missing');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft-page-repair')), findsOneWidget);
    for (var index = 0; index < _pageIds.length; index++) {
      final id = _pageIds[index];
      expect(_pageController(tester, id).offset, 210.0 * (index + 1));
      expect(_pageState(tester, id).editor.text, 'new draft for $id');
    }
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
    'locale, reading direction and orientation preserve page identity',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final host = await _mount(tester, ids: _allPageIds);
      await _editPage(tester, host, 'records', actions: 2);
      final original = _pageState(tester, 'records');
      _pageController(tester, 'records').jumpTo(480);
      _pageController(tester, 'fleet').jumpTo(170);
      await tester.pump();

      const scenarios = [
        (locale: Locale('en'), size: Size(844, 390), rtl: false),
        (locale: Locale('ja'), size: Size(320, 780), rtl: false),
        (locale: Locale('ko'), size: Size(844, 390), rtl: true),
        (
          locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          size: Size(320, 780),
          rtl: false,
        ),
        (locale: Locale('zh'), size: Size(844, 390), rtl: true),
      ];
      for (final scenario in scenarios) {
        tester.view.physicalSize = scenario.size;
        host.change(
          locale: scenario.locale,
          direction: scenario.rtl ? TextDirection.rtl : TextDirection.ltr,
          size: scenario.size,
        );
        await tester.pumpAndSettle();
        final selectedTab = find.byKey(const ValueKey('dashboard-tab-records'));
        expect(selectedTab.hitTestable(), findsOneWidget);
        await tester.longPress(selectedTab);
        await tester.pumpAndSettle();
        expect(_pageState(tester, 'records'), same(original));
        expect(original.editor.text, 'saved draft for records');
        expect(original.actions, 2);
        expect(_pageController(tester, 'records').offset, 480);
        expect(_pageController(tester, 'fleet').offset, 170);
        expect(
          find.byKey(const ValueKey('dashboard-tab-records')).hitTestable(),
          findsOneWidget,
          reason: 'selected tab should stay reachable in ${scenario.locale}',
        );
        final context = tester.element(find.byType(DashboardTabs));
        final label = AppLocalizations.of(context)!.battleRecords;
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('dashboard-tab-records')),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '${scenario.locale}');
      }
      expect(host.orderEdits, scenarios.length);
      await _unmount(tester);
    },
  );

  testWidgets('constraint-only shrink keeps the selected tab reachable', (
    tester,
  ) async {
    final host = await _mount(
      tester,
      ids: _allPageIds,
      selected: 'construction',
      size: const Size(700, 420),
    );
    final selected = find.byKey(const ValueKey('dashboard-tab-construction'));
    expect(selected.hitTestable(), findsOneWidget);

    host.change(size: const Size(220, 420));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('draft-page-construction')),
      findsOneWidget,
    );
    expect(selected.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets(
    'text scaling keeps the active trailing tab visible without changing selection',
    (tester) async {
      final host = await _mount(
        tester,
        ids: _allPageIds,
        selected: 'records',
        size: const Size(500, 420),
      );
      final page = _pageState(tester, 'records');
      host.change(textScale: 3);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dashboard-tab-records')).hitTestable(),
        findsOneWidget,
      );
      expect(_pageState(tester, 'records'), same(page));
      expect(host.selected, 'records');
      await _unmount(tester);
    },
  );

  testWidgets('growing warning badges keep the active trailing tab visible', (
    tester,
  ) async {
    final host = await _mount(
      tester,
      ids: _allPageIds,
      selected: 'records',
      size: const Size(500, 420),
    );
    final page = _pageState(tester, 'records');
    host.change(
      badges: {
        for (final id in _allPageIds.where((id) => id != 'records')) id: 999,
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsNWidgets(5));
    expect(
      find.byKey(const ValueKey('dashboard-tab-records')).hitTestable(),
      findsOneWidget,
    );
    expect(_pageState(tester, 'records'), same(page));
    await _unmount(tester);
  });

  testWidgets(
    'removal and disposal cancel pending scroll and reveal work safely',
    (tester) async {
      final host = await _mount(tester, ids: _allPageIds);
      final fleet = _pageState(tester, 'fleet');
      _pageController(tester, 'fleet').jumpTo(300);
      final scrolling = _pageController(tester, 'fleet').animateTo(
        1100,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      host.change(selected: 'records');
      await tester.pump(const Duration(milliseconds: 16));
      host.change(ids: const ['records'], selected: 'fleet');
      await tester.pump(const Duration(milliseconds: 16));
      expect(fleet.mounted, isFalse);
      expect(find.byKey(const ValueKey('draft-page-records')), findsOneWidget);
      expect(tester.takeException(), isNull);

      host.change(ids: _allPageIds, selected: 'construction');
      await _unmount(tester);
      await scrolling;
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_TabsHostState> _mount(
  WidgetTester tester, {
  List<String> ids = _pageIds,
  String selected = 'fleet',
  Size size = const Size(320, 480),
}) async {
  final key = GlobalKey<_TabsHostState>();
  await tester.pumpWidget(
    _TabsHost(key: key, ids: ids, selected: selected, size: size),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return key.currentState!;
}

Future<void> _editPage(
  WidgetTester tester,
  _TabsHostState host,
  String id, {
  int actions = 1,
}) async {
  host.change(selected: id);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(ValueKey('draft-editor-$id')),
    'saved draft for $id',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  for (var index = 0; index < actions; index++) {
    await tester.tap(find.byKey(ValueKey('draft-action-$id')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}

ScrollController _pageController(WidgetTester tester, String id) => tester
    .widget<SingleChildScrollView>(
      find.byKey(
        PageStorageKey<String>('dashboard-tab-scroll-$id'),
        skipOffstage: false,
      ),
    )
    .controller!;

_DraftPageState _pageState(WidgetTester tester, String id) =>
    tester.state<_DraftPageState>(
      find.byWidgetPredicate(
        (widget) => widget is _DraftPage && widget.id == id,
        skipOffstage: false,
      ),
    );

class _TabsHost extends StatefulWidget {
  const _TabsHost({
    super.key,
    required this.ids,
    required this.selected,
    required this.size,
  });

  final List<String> ids;
  final String selected;
  final Size size;

  @override
  State<_TabsHost> createState() => _TabsHostState();
}

class _TabsHostState extends State<_TabsHost> {
  final bucket = PageStorageBucket();
  late List<String> ids = widget.ids;
  late String selected = widget.selected;
  late Size size = widget.size;
  Locale locale = const Locale('zh');
  TextDirection direction = TextDirection.ltr;
  double textScale = 1;
  Map<String, int> badges = {};
  int orderEdits = 0;

  void change({
    List<String>? ids,
    String? selected,
    Size? size,
    Locale? locale,
    TextDirection? direction,
    double? textScale,
    Map<String, int>? badges,
  }) => setState(() {
    if (ids != null) this.ids = ids;
    if (selected != null) this.selected = selected;
    if (size != null) this.size = size;
    if (locale != null) this.locale = locale;
    if (direction != null) this.direction = direction;
    if (textScale != null) this.textScale = textScale;
    if (badges != null) this.badges = badges;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: createAppTheme(mode: AppThemeMode.dark),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
              textDirection: direction,
              child: PageStorage(
                bucket: bucket,
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    final labels = {
                      'fleet': l10n.fleet,
                      'tasks': l10n.quests,
                      'repair': l10n.repair,
                      'expedition': l10n.expedition,
                      'construction': l10n.construction,
                      'records': l10n.battleRecords,
                    };
                    const icons = {
                      'fleet': Icons.sailing,
                      'tasks': Icons.assignment,
                      'repair': Icons.build,
                      'expedition': Icons.explore,
                      'construction': Icons.precision_manufacturing,
                      'records': Icons.history,
                    };
                    return DashboardTabs(
                      tabs: [
                        for (final id in ids)
                          DashboardTab(
                            id: id,
                            label: labels[id]!,
                            title: labels[id]!,
                            icon: icons[id],
                            badgeCount: badges[id] ?? 0,
                          ),
                      ],
                      selectedId: selected,
                      onSelected: (id) => change(selected: id),
                      onLongPressTab: (_) => setState(() {
                        orderEdits++;
                        ids = ids.reversed.toList();
                      }),
                      cardBuilder: (id) => _DraftPage(id),
                      notice: const Text('fixed notice'),
                      footer: const Text('page footer'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DraftPage extends StatefulWidget {
  const _DraftPage(this.id);

  final String id;

  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  late final editor = TextEditingController(text: 'new draft for ${widget.id}');
  int actions = 0;

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('draft-page-${widget.id}'),
    children: [
      TextButton(
        key: ValueKey('draft-action-${widget.id}'),
        onPressed: () => setState(() => actions++),
        child: Text('${widget.id} actions: $actions'),
      ),
      TextField(key: ValueKey('draft-editor-${widget.id}'), controller: editor),
      const SizedBox(height: 1900),
    ],
  );
}
