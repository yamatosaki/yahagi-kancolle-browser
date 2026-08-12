import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../battle/battle_models.dart';
import '../game_state/game_state.dart';

enum LogbookChangeCategory {
  battle,
  resource,
  expedition,
  construction,
  development,
  retirement,
}

final class DevelopmentLogEntry {
  const DevelopmentLogEntry({
    required this.timestamp,
    required this.success,
    required this.equipmentId,
    required this.equipmentName,
    required this.equipmentType,
    required this.equipmentIconId,
    required this.fuel,
    required this.ammo,
    required this.steel,
    required this.bauxite,
    required this.secretaryName,
  });

  final int timestamp;
  final bool success;
  final int? equipmentId;
  final String equipmentName;
  final String equipmentType;
  final int equipmentIconId;
  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;
  final String secretaryName;

  Map<String, Object?> toRow() => <String, Object?>{
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
  };
}

final class RetirementLogEntry {
  const RetirementLogEntry({
    required this.timestamp,
    required this.type,
    required this.shipType,
    required this.shipName,
    required this.level,
  });

  final int timestamp;
  final String type;
  final String shipType;
  final String shipName;
  final int level;

  Map<String, Object?> toRow() => <String, Object?>{
    'timestamp': timestamp,
    'type': type,
    'ship_type': shipType,
    'ship_name': shipName,
    'level': level,
  };
}

class LogbookDatabase extends ChangeNotifier {
  static final LogbookDatabase instance = LogbookDatabase._init();

  final Future<Database> Function()? _databaseOpener;
  Database? _database;
  Future<Database>? _openingDatabase;
  Future<void>? _resourceWriteQueue;
  _ResourceSnapshotValues? _lastResourceValues;
  bool _resourceBaselineLoaded = false;
  final Map<LogbookChangeCategory, ValueNotifier<int>> _changeSignals = {
    for (final category in LogbookChangeCategory.values)
      category: ValueNotifier<int>(0),
  };

  LogbookDatabase._init({this._databaseOpener});

  @visibleForTesting
  static LogbookDatabase lazyForTesting(
    Future<Database> Function() databaseOpener,
  ) => LogbookDatabase._init(databaseOpener: databaseOpener);

  static Future<LogbookDatabase> openForTesting() async {
    sqfliteFfiInit();
    final result = LogbookDatabase._init();
    result._database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 7, onCreate: result._createDB),
    );
    return result;
  }

  Future<void> close() async {
    final pendingResourceWrite = _resourceWriteQueue;
    try {
      await pendingResourceWrite;
    } catch (_) {
      // A failed snapshot write must not prevent the database from closing.
    }
    var current = _database;
    final opening = _openingDatabase;
    if (current == null && opening != null) {
      try {
        current = await opening;
      } catch (_) {
        // A failed lazy open leaves nothing to close.
      }
    }
    _database = null;
    _openingDatabase = null;
    _resourceWriteQueue = null;
    _lastResourceValues = null;
    _resourceBaselineLoaded = false;
    await current?.close();
  }

  Future<Database> get database {
    final current = _database;
    if (current != null) return Future<Database>.value(current);
    final opening = _openingDatabase;
    if (opening != null) return opening;

    final operation = _openAndCacheDatabase();
    _openingDatabase = operation;
    return operation;
  }

  Future<Database> _openAndCacheDatabase() async {
    try {
      final opened = await (_databaseOpener?.call() ?? _initDB('logbook.db'));
      _database = opened;
      return opened;
    } finally {
      _openingDatabase = null;
    }
  }

  ValueListenable<int> changesFor(LogbookChangeCategory category) =>
      _changeSignals[category]!;

  void _notifyChange(LogbookChangeCategory category) {
    final signal = _changeSignals[category]!;
    signal.value += 1;
    notifyListeners();
  }

  void _notifyAllChanges() {
    for (final signal in _changeSignals.values) {
      signal.value += 1;
    }
    notifyListeners();
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
      version: 7,
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
        map_name TEXT NOT NULL DEFAULT '',
        node INTEGER NOT NULL,
        node_label TEXT NOT NULL DEFAULT '',
        node_type INTEGER NOT NULL,
        map_difficulty INTEGER NOT NULL DEFAULT 0,
        rank TEXT NOT NULL,
        drop_ship_id INTEGER,
        enemy_fleet_name TEXT NOT NULL,
        friend_fleet_state TEXT NOT NULL,
        enemy_fleet_state TEXT NOT NULL,
        flagship_name TEXT NOT NULL DEFAULT '—',
        escort_flagship_name TEXT NOT NULL DEFAULT '—',
        mvp_name TEXT NOT NULL DEFAULT '—',
        escort_mvp_name TEXT NOT NULL DEFAULT '—'
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
        item2_count INTEGER NOT NULL DEFAULT 0,
        reward_items_json TEXT NOT NULL DEFAULT '[]'
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
        dock_id INTEGER NOT NULL DEFAULT 0,
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
    if (oldVersion < 4) {
      for (final column in <String>[
        'flagship_name',
        'escort_flagship_name',
        'mvp_name',
        'escort_mvp_name',
      ]) {
        await db.execute(
          "ALTER TABLE battle_logs ADD COLUMN $column TEXT NOT NULL DEFAULT '—'",
        );
      }
      if (oldVersion >= 3) {
        await db.execute(
          'ALTER TABLE construction_logs ADD COLUMN dock_id INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE battle_logs ADD COLUMN map_difficulty INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE battle_logs ADD COLUMN map_name TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE battle_logs ADD COLUMN node_label TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE expedition_logs ADD COLUMN reward_items_json TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  /// Add a battle record to the log
  Future<void> insertBattleRecord(
    BattleRecord record, {
    int mapDifficulty = 0,
    String mapName = '',
    String nodeLabel = '',
  }) async {
    final db = await database;
    final battle = record.battle;
    String nameAt(List<BattleShipSnapshot> ships, int position) {
      for (final ship in ships) {
        if (ship.position == position) return ship.name;
      }
      return '—';
    }

    var mainMvp = '—';
    var escortMvp = '—';
    for (final position in battle.mvpPositions) {
      if (position >= 6) {
        escortMvp = nameAt(battle.friendEscort, position - 6);
      } else {
        mainMvp = nameAt(battle.friendMain, position);
      }
    }
    await db.insert('battle_logs', {
      'timestamp': record.completedAt.millisecondsSinceEpoch,
      'map_area': battle.context.mapAreaId,
      'map_no': battle.context.mapInfoNo,
      'map_name': mapName,
      'node': battle.context.node,
      'node_label': nodeLabel,
      'node_type': battle.context.nodeTypeLabel,
      'map_difficulty': mapDifficulty,
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
      'flagship_name': battle.friendMain.isEmpty
          ? '—'
          : battle.friendMain.first.name,
      'escort_flagship_name': battle.friendEscort.isEmpty
          ? '—'
          : battle.friendEscort.first.name,
      'mvp_name': mainMvp,
      'escort_mvp_name': escortMvp,
    });
    _notifyChange(LogbookChangeCategory.battle);
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
  Future<void> insertResourceSnapshot(GameState state) {
    final values = _ResourceSnapshotValues.fromState(state);
    if (values == null) return Future<void>.value();

    final previous = _resourceWriteQueue;
    final operation = previous == null
        ? _insertResourceSnapshot(values)
        : previous.then(
            (_) => _insertResourceSnapshot(values),
            onError: (_) => _insertResourceSnapshot(values),
          );
    _resourceWriteQueue = operation;
    return operation;
  }

  Future<void> _insertResourceSnapshot(_ResourceSnapshotValues values) async {
    final db = await database;
    if (!_resourceBaselineLoaded) {
      final latest = await db.query(
        'resource_logs',
        columns: _ResourceSnapshotValues.columns,
        orderBy: 'id DESC',
        limit: 1,
      );
      _lastResourceValues = latest.isEmpty
          ? null
          : _ResourceSnapshotValues.fromRow(latest.single);
      _resourceBaselineLoaded = true;
    }
    if (values == _lastResourceValues) return;

    await db.insert('resource_logs', values.toRow(DateTime.now()));
    _lastResourceValues = values;
    _notifyChange(LogbookChangeCategory.resource);
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
    List<Map<String, Object?>> rewardItems = const <Map<String, Object?>>[],
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
      'reward_items_json': jsonEncode(rewardItems),
    });
    _notifyChange(LogbookChangeCategory.expedition);
  }

  Future<List<Map<String, dynamic>>> getExpeditionRecords({
    int limit = 50,
    int? beforeId,
  }) =>
      _getOperationRecords('expedition_logs', limit: limit, beforeId: beforeId);

  Future<int> insertConstructionRecord({
    int dockId = 0,
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
    final id = await db.insert('construction_logs', {
      'dock_id': dockId,
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
    _notifyChange(LogbookChangeCategory.construction);
    return id;
  }

  Future<bool> updateConstructionResult({
    required int dockId,
    required int shipId,
    required String shipName,
    required String shipType,
  }) async {
    final db = await database;
    final changed = await db.update(
      'construction_logs',
      {'ship_id': shipId, 'ship_name': shipName, 'ship_type': shipType},
      where:
          'id = (SELECT id FROM construction_logs WHERE dock_id = ? ORDER BY id DESC LIMIT 1)',
      whereArgs: [dockId],
    );
    if (changed > 0) _notifyChange(LogbookChangeCategory.construction);
    return changed > 0;
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
  }) => insertDevelopmentRecords(<DevelopmentLogEntry>[
    DevelopmentLogEntry(
      timestamp: timestamp,
      success: success,
      equipmentId: equipmentId,
      equipmentName: equipmentName,
      equipmentType: equipmentType,
      equipmentIconId: equipmentIconId,
      fuel: fuel,
      ammo: ammo,
      steel: steel,
      bauxite: bauxite,
      secretaryName: secretaryName,
    ),
  ]);

  Future<void> insertDevelopmentRecords(
    Iterable<DevelopmentLogEntry> records,
  ) async {
    final values = records.toList(growable: false);
    if (values.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final record in values) {
      batch.insert('development_logs', record.toRow());
    }
    await batch.commit(noResult: true);
    _notifyChange(LogbookChangeCategory.development);
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
  }) => insertRetirementRecords(<RetirementLogEntry>[
    RetirementLogEntry(
      timestamp: timestamp,
      type: type,
      shipType: shipType,
      shipName: shipName,
      level: level,
    ),
  ]);

  Future<void> insertRetirementRecords(
    Iterable<RetirementLogEntry> records,
  ) async {
    final values = records.toList(growable: false);
    if (values.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final record in values) {
      batch.insert('retirement_logs', record.toRow());
    }
    await batch.commit(noResult: true);
    _notifyChange(LogbookChangeCategory.retirement);
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

  Future<int> countResourceLogs({DateTime? start, DateTime? end}) async {
    final db = await database;
    final filter = _resourceRangeFilter(start: start, end: end);
    final rows = await db.query(
      'resource_logs',
      columns: const <String>['COUNT(*) AS row_count'],
      where: filter.where,
      whereArgs: filter.arguments,
    );
    final value = rows.singleOrNull?['row_count'];
    return value is num ? value.toInt() : 0;
  }

  Stream<Map<String, dynamic>> streamResourceLogs({
    DateTime? start,
    DateTime? end,
    int pageSize = 1000,
  }) async* {
    assert(pageSize > 0);
    final db = await database;
    var lastId = 0;
    while (true) {
      final filter = _resourceRangeFilter(
        start: start,
        end: end,
        afterId: lastId,
      );
      final rows = await db.query(
        'resource_logs',
        where: filter.where,
        whereArgs: filter.arguments,
        orderBy: 'id ASC',
        limit: pageSize,
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        yield row;
      }
      lastId = (rows.last['id'] as num).toInt();
      if (rows.length < pageSize) return;
    }
  }

  ({String? where, List<Object?>? arguments}) _resourceRangeFilter({
    DateTime? start,
    DateTime? end,
    int? afterId,
  }) {
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (start != null) {
      clauses.add('timestamp >= ?');
      arguments.add(start.millisecondsSinceEpoch);
    }
    if (end != null) {
      clauses.add('timestamp <= ?');
      arguments.add(end.millisecondsSinceEpoch);
    }
    if (afterId != null) {
      clauses.add('id > ?');
      arguments.add(afterId);
    }
    return (
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      arguments: arguments.isEmpty ? null : arguments,
    );
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
    final pendingResourceWrite = _resourceWriteQueue;
    if (pendingResourceWrite != null) await pendingResourceWrite;
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete('battle_logs');
      await transaction.delete('resource_logs');
      await transaction.delete('expedition_logs');
      await transaction.delete('construction_logs');
      await transaction.delete('development_logs');
      await transaction.delete('retirement_logs');
    });
    _resourceWriteQueue = null;
    _lastResourceValues = null;
    _resourceBaselineLoaded = false;
    _notifyAllChanges();
  }
}

final class _ResourceSnapshotValues {
  const _ResourceSnapshotValues({
    required this.fuel,
    required this.ammo,
    required this.steel,
    required this.bauxite,
    required this.bucket,
    required this.blowtorch,
    required this.devmat,
    required this.screw,
  });

  static const List<String> columns = <String>[
    'fuel',
    'ammo',
    'steel',
    'bauxite',
    'bucket',
    'blowtorch',
    'devmat',
    'screw',
  ];

  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;
  final int bucket;
  final int blowtorch;
  final int devmat;
  final int screw;

  static _ResourceSnapshotValues? fromState(GameState state) {
    final fuel = state.resource(GameResourceType.fuel);
    if (fuel == null) return null;
    return _ResourceSnapshotValues(
      fuel: fuel,
      ammo: state.resource(GameResourceType.ammunition) ?? 0,
      steel: state.resource(GameResourceType.steel) ?? 0,
      bauxite: state.resource(GameResourceType.bauxite) ?? 0,
      bucket: state.resource(GameResourceType.instantRepair) ?? 0,
      blowtorch: state.resource(GameResourceType.instantBuild) ?? 0,
      devmat: state.resource(GameResourceType.developmentMaterial) ?? 0,
      screw: state.resource(GameResourceType.improvementMaterial) ?? 0,
    );
  }

  factory _ResourceSnapshotValues.fromRow(Map<String, Object?> row) =>
      _ResourceSnapshotValues(
        fuel: _int(row['fuel']),
        ammo: _int(row['ammo']),
        steel: _int(row['steel']),
        bauxite: _int(row['bauxite']),
        bucket: _int(row['bucket']),
        blowtorch: _int(row['blowtorch']),
        devmat: _int(row['devmat']),
        screw: _int(row['screw']),
      );

  Map<String, Object?> toRow(DateTime timestamp) => <String, Object?>{
    'timestamp': timestamp.millisecondsSinceEpoch,
    'fuel': fuel,
    'ammo': ammo,
    'steel': steel,
    'bauxite': bauxite,
    'bucket': bucket,
    'blowtorch': blowtorch,
    'devmat': devmat,
    'screw': screw,
  };

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  @override
  bool operator ==(Object other) =>
      other is _ResourceSnapshotValues &&
      fuel == other.fuel &&
      ammo == other.ammo &&
      steel == other.steel &&
      bauxite == other.bauxite &&
      bucket == other.bucket &&
      blowtorch == other.blowtorch &&
      devmat == other.devmat &&
      screw == other.screw;

  @override
  int get hashCode =>
      Object.hash(fuel, ammo, steel, bauxite, bucket, blowtorch, devmat, screw);
}
