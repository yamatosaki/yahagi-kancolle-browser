import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

class QueryGate {
  final taken = Completer<void>(), release = Completer<void>();
  bool fail = false;
}

class GateDb implements Database {
  GateDb(this.inner);
  final Database inner;
  final gates = <int, QueryGate>{};
  var queries = 0;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await inner.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    if (table == 'development_logs' && columns == null) {
      final gate = gates[++queries];
      if (gate != null) {
        gate.taken.complete();
        await gate.release.future;
        if (gate.fail) throw StateError('synthetic query failure');
      }
    }
    return rows;
  }

  @override
  Batch batch() => inner.batch();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> insert(LogbookDatabase db, String name, {bool success = true}) =>
    db.insertDevelopmentRecord(
      timestamp: 1,
      success: success,
      equipmentId: 1,
      equipmentName: name,
      equipmentType: '主炮',
      equipmentIconId: 1,
      fuel: 10,
      ammo: 10,
      steel: 10,
      bauxite: 10,
      secretaryName: 'offline',
    );
Widget app(BattleController controller, LogbookDatabase db) => MaterialApp(
  home: Scaffold(
    body: LogbookPage(
      battleController: controller,
      database: db,
      selectedTabIndex: 3,
    ),
  ),
);
int rowCount(WidgetTester tester) => tester
    .widget<FrozenDataTable>(find.byKey(const Key('logbook-table-development')))
    .rowHeights
    .length;
Future<void> filter(WidgetTester tester, String result) async {
  await tester.tap(find.byKey(const Key('logbook-filter-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final dropdown = find.descendant(
    of: find.byKey(const Key('logbook-filter-field-result')),
    matching: find.byType(DropdownButton<String>),
  );
  tester.widget<DropdownButton<String>>(dropdown).onChanged!(result);
  await tester.pump();
  await tester.tap(find.byKey(const Key('logbook-filter-apply')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('an unqueued first-page failure releases the loading indicator', (
    tester,
  ) async {
    final backing = await LogbookDatabase.openForTesting();
    addTearDown(backing.close);
    final proxy = GateDb(await backing.database);
    final gate = QueryGate()..fail = true;
    proxy.gates[1] = gate;
    final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller, db));
    await tester.pump();
    gate.release.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(proxy.queries, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'refresh received during initial loading is drained once for many notifications',
    (tester) async {
      final backing = await LogbookDatabase.openForTesting();
      addTearDown(backing.close);
      await insert(backing, 'old');
      final proxy = GateDb(await backing.database);
      final gate = QueryGate();
      proxy.gates[1] = gate;
      final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller, db));
      await tester.pump();
      expect(gate.taken.isCompleted, true);
      for (var i = 0; i < 3; i++) {
        await insert(db, 'new$i');
      }
      gate.release.complete();
      await tester.pumpAndSettle();
      expect(find.text('old'), findsOneWidget);
      expect(find.text('new0'), findsOneWidget);
      expect(rowCount(tester), 4);
      expect(proxy.queries, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a burst larger than one page joins the captured rows without gaps',
    (tester) async {
      final backing = await LogbookDatabase.openForTesting();
      addTearDown(backing.close);
      await insert(backing, 'old');
      final proxy = GateDb(await backing.database);
      final gate = QueryGate();
      proxy.gates[1] = gate;
      final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller, db));
      await tester.pump();
      for (var i = 0; i < 101; i++) {
        await insert(db, 'new$i');
      }
      gate.release.complete();
      await tester.pumpAndSettle();
      expect(rowCount(tester), 102);
      expect(proxy.queries, 4);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pagination drains inserts without duplicates or moving the visible row',
    (tester) async {
      final backing = await LogbookDatabase.openForTesting();
      addTearDown(backing.close);
      for (var i = 0; i < 100; i++) {
        await insert(backing, 'old$i');
      }
      final proxy = GateDb(await backing.database);
      final gate = QueryGate();
      proxy.gates[2] = gate;
      final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller, db));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<ListView>(
            find.byKey(const Key('logbook-development-body-scroll')),
          )
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(gate.taken.isCompleted, true);
      final position = scroll.offset;
      for (var i = 0; i < 3; i++) {
        await insert(db, 'new$i');
      }
      gate.release.complete();
      await tester.pumpAndSettle();
      expect(rowCount(tester), 103);
      expect(scroll.offset, position + 3 * FrozenDataTable.minimumRowHeight);
      expect(proxy.queries, 3);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.text('new$i'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'late old filter completion cannot consume the new filter pending refresh',
    (tester) async {
      final backing = await LogbookDatabase.openForTesting();
      addTearDown(backing.close);
      await insert(backing, 'success');
      await insert(backing, 'failure', success: false);
      final proxy = GateDb(await backing.database);
      final first = QueryGate(), second = QueryGate();
      proxy.gates.addAll({1: first, 2: second});
      final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller, db));
      await tester.pump();
      await filter(tester, '失败');
      expect(second.taken.isCompleted, true);
      await insert(db, 'new failure', success: false);
      first.release.complete();
      await tester.pump();
      second.release.complete();
      await tester.pumpAndSettle();
      expect(rowCount(tester), 2);
      expect(find.text('success'), findsNothing);
      expect(find.text('new failure'), findsOneWidget);
      expect(proxy.queries, 3);
      await filter(tester, '全部结果');
      expect(rowCount(tester), 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'query failure consumes only a queued notification and stays retryable',
    (tester) async {
      final backing = await LogbookDatabase.openForTesting();
      addTearDown(backing.close);
      await insert(backing, 'old');
      final proxy = GateDb(await backing.database);
      final first = QueryGate()..fail = true;
      final retry = QueryGate()..fail = true;
      proxy.gates.addAll({1: first, 2: retry});
      final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller, db));
      await tester.pump();
      await insert(db, 'new');
      first.release.complete();
      await tester.pumpAndSettle();
      expect(retry.taken.isCompleted, true);
      retry.release.complete();
      await tester.pumpAndSettle();
      expect(proxy.queries, 2);
      expect(tester.takeException(), isNull);
      await insert(db, 'retry trigger');
      await tester.pumpAndSettle();
      expect(rowCount(tester), 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('account replacement and disposal discard old pending results', (
    tester,
  ) async {
    final backing = await LogbookDatabase.openForTesting();
    addTearDown(backing.close);
    final directory = Directory.systemTemp.createTempSync(
      'ui-logbook-isolation-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final next = (await tester.runAsync(
      () => LogbookDatabase.openForTesting(path: '${directory.path}/second.db'),
    ))!;
    addTearDown(next.close);
    await insert(backing, 'old account');
    await insert(next, 'new account');
    final proxy = GateDb(await backing.database);
    final gate = QueryGate();
    proxy.gates[1] = gate;
    final db = LogbookDatabase.lazyForTesting(() => Future.value(proxy));
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller, db));
    await tester.pump();
    await insert(db, 'queued old account');
    await tester.pumpWidget(app(controller, next));
    await tester.pumpAndSettle();
    gate.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('new account'), findsOneWidget);
    expect(find.text('old account'), findsNothing);
    expect(proxy.queries, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
