import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../battle/battle_models.dart';
import '../game_state/game_state.dart';

class LogbookDatabase {
  static final LogbookDatabase instance = LogbookDatabase._init();

  static Database? _database;

  LogbookDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('logbook.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('Logbook is not supported on Web');
    }

    // Initialize FFI for Windows/Linux/MacOS if testing or running on desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      // 测试环境使用无 isolate 模式，IO 同步完成，避免 fake-async 下事务挂起。
      databaseFactory = Platform.environment.containsKey('FLUTTER_TEST')
          ? databaseFactoryFfiNoIsolate
          : databaseFactoryFfi;
    }

    final String path;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getApplicationSupportDirectory();
      path = p.join(dbPath.path, filePath);
    }

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Battle Logs
    await db.execute('''
      CREATE TABLE battle_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        map_area INTEGER NOT NULL,
        map_no INTEGER NOT NULL,
        node INTEGER NOT NULL,
        node_type INTEGER NOT NULL,
        rank TEXT NOT NULL,
        drop_ship_id INTEGER,
        enemy_fleet_name TEXT NOT NULL,
        friend_fleet_state TEXT NOT NULL,
        enemy_fleet_state TEXT NOT NULL
      )
    ''');

    // Resource Logs
    await db.execute('''
      CREATE TABLE resource_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        fuel INTEGER NOT NULL,
        ammo INTEGER NOT NULL,
        steel INTEGER NOT NULL,
        bauxite INTEGER NOT NULL,
        bucket INTEGER NOT NULL,
        blowtorch INTEGER NOT NULL,
        devmat INTEGER NOT NULL,
        screw INTEGER NOT NULL
      )
    ''');

    // Expedition Logs
    await db.execute('''
      CREATE TABLE expedition_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        expedition_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        result INTEGER NOT NULL,
        yield_fuel INTEGER,
        yield_ammo INTEGER,
        yield_steel INTEGER,
        yield_bauxite INTEGER,
        yield_bucket INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_resource_logs_timestamp
      ON resource_logs(timestamp)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_resource_logs_timestamp
        ON resource_logs(timestamp)
      ''');
    }
  }

  /// Add a battle record to the log
  Future<void> insertBattleRecord(BattleRecord record) async {
    final db = await instance.database;
    final battle = record.battle;
    await db.insert('battle_logs', {
      'timestamp': record.completedAt.millisecondsSinceEpoch,
      'map_area': battle.context.mapAreaId,
      'map_no': battle.context.mapInfoNo,
      'node': battle.context.node,
      'node_type': battle.context.eventKind,
      'rank': battle.rank.name,
      'drop_ship_id': battle.dropShipMasterId,
      'enemy_fleet_name': battle.enemyFleetName,
      // We can store a brief snapshot of ships or just ignore it for the DB to save space,
      // but for now let's just store the count of alive ships as a simple string or JSON.
      // E.g., '6/6'
      'friend_fleet_state':
          '${battle.friendShips.where((s) => !s.isSunk).length}/${battle.friendShips.length}',
      'enemy_fleet_state':
          '${battle.enemyShips.where((s) => !s.isSunk).length}/${battle.enemyShips.length}',
    });
  }

  /// Get battle records with pagination
  Future<List<Map<String, dynamic>>> getBattleRecords({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await instance.database;
    return await db.query(
      'battle_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Take a snapshot of resources
  Future<void> insertResourceSnapshot(GameState state) async {
    final db = await instance.database;
    // Don't record if we don't have basic resources loaded
    if (state.resource(GameResourceType.fuel) == null) return;

    await db.insert('resource_logs', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'fuel': state.resource(GameResourceType.fuel) ?? 0,
      'ammo': state.resource(GameResourceType.ammunition) ?? 0,
      'steel': state.resource(GameResourceType.steel) ?? 0,
      'bauxite': state.resource(GameResourceType.bauxite) ?? 0,
      'bucket': state.resource(GameResourceType.instantRepair) ?? 0,
      'blowtorch': state.resource(GameResourceType.instantBuild) ?? 0,
      'devmat': state.resource(GameResourceType.developmentMaterial) ?? 0,
      'screw': state.resource(GameResourceType.improvementMaterial) ?? 0,
    });
  }

  /// Insert expedition result
  Future<void> insertExpeditionResult({
    required int expeditionId,
    required String name,
    required int result,
    required List<int> materials,
    int? bucketYield,
  }) async {
    final db = await instance.database;
    await db.insert('expedition_logs', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expedition_id': expeditionId,
      'name': name,
      'result': result,
      'yield_fuel': materials.isNotEmpty ? materials[0] : 0,
      'yield_ammo': materials.length > 1 ? materials[1] : 0,
      'yield_steel': materials.length > 2 ? materials[2] : 0,
      'yield_bauxite': materials.length > 3 ? materials[3] : 0,
      'yield_bucket': bucketYield ?? 0,
    });
  }

  /// Get recent resource logs for chart
  Future<List<Map<String, dynamic>>> getResourceTrendLogs({
    int limit = 50,
  }) async {
    final db = await instance.database;
    final results = await db.query(
      'resource_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    // Reverse so the oldest is first for the chart (left to right)
    return results.reversed.toList();
  }

  /// Get resource logs within a specific time range
  Future<List<Map<String, dynamic>>> getResourceLogsByTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await instance.database;
    final results = await db.query(
      'resource_logs',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );
    return results;
  }

  /// Get all resource logs
  Future<List<Map<String, dynamic>>> getAllResourceLogs() async {
    final db = await instance.database;
    final results = await db.query('resource_logs', orderBy: 'timestamp ASC');
    return results;
  }

  /// Get aggregated expedition yields per day
  Future<List<Map<String, dynamic>>> getDailyExpeditionYields({
    int limitDays = 7,
  }) async {
    final db = await instance.database;
    // Group by day. SQLite date('now') works if timestamp is in Unix seconds.
    // Our timestamp is milliseconds since epoch.
    final results = await db.rawQuery(
      '''
      SELECT 
        date(timestamp / 1000, 'unixepoch', 'localtime') as day,
        SUM(yield_fuel) as fuel,
        SUM(yield_ammo) as ammo,
        SUM(yield_steel) as steel,
        SUM(yield_bauxite) as bauxite,
        SUM(yield_bucket) as bucket
      FROM expedition_logs
      WHERE result >= 1
      GROUP BY day
      ORDER BY day DESC
      LIMIT ?
    ''',
      [limitDays],
    );
    // Reverse to chronological order (left to right)
    return results.reversed.toList();
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('battle_logs');
    await db.delete('resource_logs');
    await db.delete('expedition_logs');
  }
}
