import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../battle/battle_models.dart';
import '../game_state/game_state.dart';

class LogbookDatabase extends ChangeNotifier {
  static final LogbookDatabase instance = LogbookDatabase._init();

  Database? _database;

  LogbookDatabase._init();

  static Future<LogbookDatabase> openForTesting() async {
    sqfliteFfiInit();
    final result = LogbookDatabase._init();
    result._database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 3, onCreate: result._createDB),
    );
    return result;
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }

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
      version: 3,
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
        yield_bucket INTEGER,
        item1_id INTEGER,
        item1_name TEXT,
        item1_count INTEGER NOT NULL DEFAULT 0,
        item2_id INTEGER,
        item2_name TEXT,
        item2_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createOperationTables(db);

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_resource_logs_timestamp
      ON resource_logs(timestamp)
    ''');
    await _createOperationIndexes(db);
  }

  Future<void> _createOperationTables(Database db) async {
    await db.execute('''
      CREATE TABLE construction_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        construction_type TEXT NOT NULL,
        ship_id INTEGER,
        ship_name TEXT NOT NULL,
        ship_type TEXT NOT NULL,
        fuel INTEGER NOT NULL,
        ammo INTEGER NOT NULL,
        steel INTEGER NOT NULL,
        bauxite INTEGER NOT NULL,
        development_material INTEGER NOT NULL,
        secretary_name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE development_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        success INTEGER NOT NULL,
        equipment_id INTEGER,
        equipment_name TEXT NOT NULL,
        equipment_type TEXT NOT NULL,
        equipment_icon_id INTEGER NOT NULL,
        fuel INTEGER NOT NULL,
        ammo INTEGER NOT NULL,
        steel INTEGER NOT NULL,
        bauxite INTEGER NOT NULL,
        secretary_name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE retirement_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        ship_type TEXT NOT NULL,
        ship_name TEXT NOT NULL,
        level INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createOperationIndexes(Database db) async {
    for (final table in <String>[
      'battle_logs',
      'expedition_logs',
      'construction_logs',
      'development_logs',
      'retirement_logs',
    ]) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_${table}_timestamp
        ON $table(timestamp DESC)
      ''');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_resource_logs_timestamp
        ON resource_logs(timestamp)
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE expedition_logs ADD COLUMN item1_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE expedition_logs ADD COLUMN item1_name TEXT',
      );
      await db.execute(
        'ALTER TABLE expedition_logs ADD COLUMN item1_count INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE expedition_logs ADD COLUMN item2_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE expedition_logs ADD COLUMN item2_name TEXT',
      );
      await db.execute(
        'ALTER TABLE expedition_logs ADD COLUMN item2_count INTEGER NOT NULL DEFAULT 0',
      );
      await _createOperationTables(db);
      await _createOperationIndexes(db);
    }
  }

  /// Add a battle record to the log
  Future<void> insertBattleRecord(BattleRecord record) async {
    final db = await database;
    final battle = record.battle;
    await db.insert('battle_logs', {
      'timestamp': record.completedAt.millisecondsSinceEpoch,
      'map_area': battle.context.mapAreaId,
      'map_no': battle.context.mapInfoNo,
      'node': battle.context.node,
      'node_type': battle.context.nodeTypeLabel,
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
    notifyListeners();
  }

  /// Get battle records with pagination
  Future<List<Map<String, dynamic>>> getBattleRecords({
    int limit = 50,
    int offset = 0,
    int? beforeId,
  }) async {
    final db = await database;
    return await db.query(
      'battle_logs',
      where: beforeId == null ? null : 'id < ?',
      whereArgs: beforeId == null ? null : <Object>[beforeId],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Take a snapshot of resources
  Future<void> insertResourceSnapshot(GameState state) async {
    final db = await database;
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
    int? item1Id,
    String? item1Name,
    int item1Count = 0,
    int? item2Id,
    String? item2Name,
    int item2Count = 0,
    int? timestamp,
  }) async {
    final db = await database;
    await db.insert('expedition_logs', {
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'expedition_id': expeditionId,
      'name': name,
      'result': result,
      'yield_fuel': materials.isNotEmpty ? materials[0] : 0,
      'yield_ammo': materials.length > 1 ? materials[1] : 0,
      'yield_steel': materials.length > 2 ? materials[2] : 0,
      'yield_bauxite': materials.length > 3 ? materials[3] : 0,
      'yield_bucket': bucketYield ?? 0,
      'item1_id': item1Id,
      'item1_name': item1Name,
      'item1_count': item1Count,
      'item2_id': item2Id,
      'item2_name': item2Name,
      'item2_count': item2Count,
    });
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getExpeditionRecords({
    int limit = 50,
    int? beforeId,
  }) =>
      _getOperationRecords('expedition_logs', limit: limit, beforeId: beforeId);

  Future<void> insertConstructionRecord({
    required int timestamp,
    required String constructionType,
    required int? shipId,
    required String shipName,
    required String shipType,
    required int fuel,
    required int ammo,
    required int steel,
    required int bauxite,
    required int developmentMaterial,
    required String secretaryName,
  }) async {
    final db = await database;
    await db.insert('construction_logs', {
      'timestamp': timestamp,
      'construction_type': constructionType,
      'ship_id': shipId,
      'ship_name': shipName,
      'ship_type': shipType,
      'fuel': fuel,
      'ammo': ammo,
      'steel': steel,
      'bauxite': bauxite,
      'development_material': developmentMaterial,
      'secretary_name': secretaryName,
    });
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getConstructionRecords({
    int limit = 50,
    int? beforeId,
  }) => _getOperationRecords(
    'construction_logs',
    limit: limit,
    beforeId: beforeId,
  );

  Future<void> insertDevelopmentRecord({
    required int timestamp,
    required bool success,
    required int? equipmentId,
    required String equipmentName,
    required String equipmentType,
    required int equipmentIconId,
    required int fuel,
    required int ammo,
    required int steel,
    required int bauxite,
    required String secretaryName,
  }) async {
    final db = await database;
    await db.insert('development_logs', {
      'timestamp': timestamp,
      'success': success ? 1 : 0,
      'equipment_id': equipmentId,
      'equipment_name': equipmentName,
      'equipment_type': equipmentType,
      'equipment_icon_id': equipmentIconId,
      'fuel': fuel,
      'ammo': ammo,
      'steel': steel,
      'bauxite': bauxite,
      'secretary_name': secretaryName,
    });
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getDevelopmentRecords({
    int limit = 50,
    int? beforeId,
  }) => _getOperationRecords(
    'development_logs',
    limit: limit,
    beforeId: beforeId,
  );

  Future<void> insertRetirementRecord({
    required int timestamp,
    required String type,
    required String shipType,
    required String shipName,
    required int level,
  }) async {
    final db = await database;
    await db.insert('retirement_logs', {
      'timestamp': timestamp,
      'type': type,
      'ship_type': shipType,
      'ship_name': shipName,
      'level': level,
    });
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getRetirementRecords({
    int limit = 50,
    int? beforeId,
  }) =>
      _getOperationRecords('retirement_logs', limit: limit, beforeId: beforeId);

  Future<List<Map<String, dynamic>>> _getOperationRecords(
    String table, {
    required int limit,
    required int? beforeId,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: beforeId == null ? null : 'id < ?',
      whereArgs: beforeId == null ? null : <Object>[beforeId],
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  /// Get recent resource logs for chart
  Future<List<Map<String, dynamic>>> getResourceTrendLogs({
    int limit = 50,
  }) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    final results = await db.query('resource_logs', orderBy: 'timestamp ASC');
    return results;
  }

  /// Get aggregated expedition yields per day
  Future<List<Map<String, dynamic>>> getDailyExpeditionYields({
    int limitDays = 7,
  }) async {
    final db = await database;
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
    final db = await database;
    await db.delete('battle_logs');
    await db.delete('resource_logs');
    await db.delete('expedition_logs');
    await db.delete('construction_logs');
    await db.delete('development_logs');
    await db.delete('retirement_logs');
  }
}
