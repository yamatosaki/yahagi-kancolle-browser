import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_event_recorder.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v11 upgrade retains old rows and saves subsequent material drops',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'yahagi-material-v11-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/logbook.db';
      final legacy = await LogbookDatabase.openForTesting(path: path);
      final raw = await legacy.database;
      await raw.execute('DROP TABLE ${LogbookDatabase.experienceTable}');
      await raw.execute('DROP TABLE map_resource_logs');
      await raw.execute('''
      CREATE TABLE map_resource_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_key TEXT NOT NULL UNIQUE,
        timestamp INTEGER NOT NULL,
        map_area INTEGER NOT NULL,
        map_no INTEGER NOT NULL,
        map_name TEXT NOT NULL DEFAULT '',
        node INTEGER NOT NULL,
        node_label TEXT NOT NULL DEFAULT '',
        map_difficulty INTEGER NOT NULL DEFAULT 0,
        fuel_delta INTEGER NOT NULL DEFAULT 0,
        ammo_delta INTEGER NOT NULL DEFAULT 0,
        steel_delta INTEGER NOT NULL DEFAULT 0,
        bauxite_delta INTEGER NOT NULL DEFAULT 0,
        reward_items_json TEXT NOT NULL DEFAULT '[]',
        radar_reduced INTEGER NOT NULL DEFAULT 0
      )
    ''');
      await raw.insert('map_resource_logs', {
        'event_key': 'legacy',
        'timestamp': 1,
        'map_area': 6,
        'map_no': 3,
        'node': 7,
        'ammo_delta': 150,
      });
      await raw.execute('PRAGMA user_version = 11');
      await legacy.close();
      final upgraded = await LogbookDatabase.openForTesting(path: path);
      addTearDown(upgraded.close);
      final oldRow = (await upgraded.getSortieRecords()).single;
      expect(oldRow['ammo_delta'], 150);
      for (final column in [
        'instant_build_delta',
        'instant_repair_delta',
        'development_material_delta',
        'improvement_material_delta',
      ]) {
        expect(oldRow[column], 0);
      }
      await LogbookEventRecorder(database: upgraded).record(
        kcsapiEvent('/kcsapi/api_req_map/next', {
          'api_maparea_id': 6,
          'api_mapinfo_no': 3,
          'api_no': 7,
          'api_itemget': {'api_usemst': 4, 'api_id': 7, 'api_getcount': 3},
        }, sequence: 6312),
        GameState.empty,
      );
      await upgraded.close();
      final reopened = await LogbookDatabase.openForTesting(path: path);
      addTearDown(reopened.close);
      final rows = await reopened.getSortieRecords();
      expect(rows, hasLength(2));
      expect(rows.first['development_material_delta'], 3);
      expect(rows.last['ammo_delta'], 150);
    },
  );

  for (final field in ['api_itemget', 'api_itemget_eo_comment']) {
    testWidgets('6-3 development material survives $field to logbook', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1500, 620);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final recorder = LogbookEventRecorder(database: database);
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      final event = kcsapiEvent('/kcsapi/api_req_map/next', {
        'api_maparea_id': 6,
        'api_mapinfo_no': 3,
        'api_no': 7,
        'api_event_id': 2,
        field: {'api_usemst': 4, 'api_id': 7, 'api_getcount': 3},
      }, sequence: 6301);
      controller.accept(event);
      await controller.idle;
      expect(
        controller.current!.resourceChanges.single.type,
        GameResourceType.developmentMaterial,
      );
      expect(controller.current!.resourceChanges.single.amount, 3);

      await recorder.record(event, GameState.empty);
      await recorder.record(event, GameState.empty);
      final rows = await database.getSortieRecords();
      expect(rows, hasLength(1));
      expect(rows.single['development_material_delta'], 3);
      expect(rows.single['reward_items_json'], '[]');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogbookPage(battleController: controller, database: database),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logbook-resource-icon-7')), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'map records keep all eight resource deltas and item rewards distinct',
    () async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final recorder = LogbookEventRecorder(database: database);
      await recorder.record(
        kcsapiEvent('/kcsapi/api_req_map/start', {
          'api_maparea_id': 6,
          'api_mapinfo_no': 3,
          'api_no': 7,
          'api_itemget': [
            for (var id = 1; id <= 8; id++)
              {'api_usemst': 4, 'api_id': id, 'api_getcount': id},
            {'api_usemst': 11, 'api_id': 11, 'api_getcount': 1},
          ],
          'api_itemget_eo_comment': {
            'api_usemst': 4,
            'api_id': 7,
            'api_getcount': 2,
          },
        }, sequence: 6302),
        GameState.empty,
      );
      final row = (await database.getSortieRecords()).single;
      expect(row['fuel_delta'], 1);
      expect(row['ammo_delta'], 2);
      expect(row['steel_delta'], 3);
      expect(row['bauxite_delta'], 4);
      expect(row['instant_build_delta'], 5);
      expect(row['instant_repair_delta'], 6);
      expect(row['development_material_delta'], 9);
      expect(row['improvement_material_delta'], 8);
      expect(row['reward_items_json'], contains('家具箱（中）'));
    },
  );
}
