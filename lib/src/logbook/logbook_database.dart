import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../account/account_session.dart';
import '../battle/battle_models.dart';
import '../battle/battle_detail_models.dart';
import '../game_state/game_state.dart';

const String _unknownAirSuperiority = '未知';
const String sortieResourceStatusToken = 'resource';

enum LogbookChangeCategory {
  battle,
  resource,
  expedition,
  construction,
  development,
  retirement,
}

final class SortieMapIdentity {
  const SortieMapIdentity({
    required this.mapArea,
    required this.mapNo,
    required this.mapName,
    required this.mapDifficulty,
  });

  final int mapArea;
  final int mapNo;
  final String mapName;
  final int mapDifficulty;
}

final class SortieFilterCatalog {
  const SortieFilterCatalog({required this.maps, required this.statuses});

  final List<SortieMapIdentity> maps;
  final List<String> statuses;
}

final class SortieRecordQuery {
  const SortieRecordQuery({
    this.sinceTimestamp,
    this.maps = const <SortieMapIdentity>[],
    this.statuses = const <String>[],
    this.rank,
  });

  final int? sinceTimestamp;
  final List<SortieMapIdentity> maps;
  final List<String> statuses;
  final String? rank;
}

final class MapResourceLogEntry {
  const MapResourceLogEntry({
    required this.eventKey,
    required this.timestamp,
    required this.mapArea,
    required this.mapNo,
    required this.mapName,
    required this.node,
    this.nodeLabel = '',
    this.mapDifficulty = 0,
    this.fuelDelta = 0,
    this.ammoDelta = 0,
    this.steelDelta = 0,
    this.bauxiteDelta = 0,
    this.instantBuildDelta = 0,
    this.instantRepairDelta = 0,
    this.developmentMaterialDelta = 0,
    this.improvementMaterialDelta = 0,
    this.rewardItems = const <BattleRewardItem>[],
    this.radarReduced = false,
  });

  final String eventKey;
  final DateTime timestamp;
  final int mapArea;
  final int mapNo;
  final String mapName;
  final int node;
  final String nodeLabel;
  final int mapDifficulty;
  final int fuelDelta;
  final int ammoDelta;
  final int steelDelta;
  final int bauxiteDelta;
  final int instantBuildDelta;
  final int instantRepairDelta;
  final int developmentMaterialDelta;
  final int improvementMaterialDelta;
  final List<BattleRewardItem> rewardItems;
  final bool radarReduced;
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
  static const int schemaVersion = 12;
  static AccountSession _accountSession = AccountSession.shared;
  static final Map<int, LogbookDatabase> _accountDatabases = {};

  static AccountSession get accountSession => _accountSession;

  static void bindAccountSession(AccountSession session) {
    _accountSession = session;
  }

  /// An instance's file never changes. Queued writes and exports keep their
  /// captured owner even if the foreground account changes during an await.
  static LogbookDatabase forAccount(int memberId) {
    final owner = memberId > 0 ? memberId : 0;
    return _accountDatabases.putIfAbsent(
      owner,
      () => LogbookDatabase._init(
        fileName: owner == 0
            ? inMemoryDatabasePath
            : AccountScope(memberId: owner, generation: 0).key('logbook.db'),
      ),
    );
  }

  static LogbookDatabase get instance =>
      forAccount(_accountSession.current.memberId);

  final Future<Database> Function()? _databaseOpener;
  final String _fileName;
  Database? _database;
  Future<Database>? _openingDatabase;
  Future<void>? _resourceWriteQueue;
  _ResourceSnapshotValues? _lastResourceValues;
  bool _resourceBaselineLoaded = false;
  final Map<LogbookChangeCategory, ValueNotifier<int>> _changeSignals = {
    for (final category in LogbookChangeCategory.values)
      category: ValueNotifier<int>(0),
  };

  LogbookDatabase._init({
    this._databaseOpener,
    this._fileName = inMemoryDatabasePath,
  });

  @visibleForTesting
  static LogbookDatabase lazyForTesting(
    Future<Database> Function() databaseOpener,
  ) => LogbookDatabase._init(databaseOpener: databaseOpener);

  static Future<LogbookDatabase> openForTesting({
    String path = inMemoryDatabasePath,
  }) async {
    sqfliteFfiInit();
    final result = LogbookDatabase._init();
    result._database = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: result._createDB,
        onUpgrade: result._onUpgrade,
      ),
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
      final opened = await (_databaseOpener?.call() ?? _initDB(_fileName));
      _database = opened;
      return opened;
    } finally {
      _openingDatabase = null;
    }
  }

  ValueListenable<int> changesFor(LogbookChangeCategory category) =>
      _changeSignals[category]!;

  Future<int> diagnosticFileSizeBytes() async {
    final current = _database;
    if (current == null || current.path == inMemoryDatabasePath) return 0;
    final file = File(current.path);
    return await file.exists() ? file.length() : 0;
  }

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
    if (filePath == inMemoryDatabasePath ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getApplicationSupportDirectory();
      path = p.join(dbPath.path, filePath);
    }

    return await openDatabase(
      path,
      singleInstance: path != inMemoryDatabasePath,
      version: schemaVersion,
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
        drop_ship_ids_json TEXT NOT NULL DEFAULT '[]',
        enemy_fleet_name TEXT NOT NULL,
        friend_fleet_state TEXT NOT NULL,
        enemy_fleet_state TEXT NOT NULL,
        friend_formation INTEGER NOT NULL DEFAULT 0,
        enemy_formation INTEGER NOT NULL DEFAULT 0,
        air_superiority TEXT NOT NULL DEFAULT '$_unknownAirSuperiority',
        heavy_damage_ship_names_json TEXT NOT NULL DEFAULT '[]',
        flagship_name TEXT NOT NULL DEFAULT '—',
        escort_flagship_name TEXT NOT NULL DEFAULT '—',
        mvp_name TEXT NOT NULL DEFAULT '—',
        escort_mvp_name TEXT NOT NULL DEFAULT '—',
        reward_items_json TEXT NOT NULL DEFAULT '[]',
        detail_json TEXT
      )
    ''');

    await _createMapResourceTable(db);

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
    await _createPendingConstructionTable(db);
  }

  Future<void> _createPendingConstructionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_construction_logs (
        dock_id INTEGER PRIMARY KEY,
        record_id INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createMapResourceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS map_resource_logs (
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
        instant_build_delta INTEGER NOT NULL DEFAULT 0,
        instant_repair_delta INTEGER NOT NULL DEFAULT 0,
        development_material_delta INTEGER NOT NULL DEFAULT 0,
        improvement_material_delta INTEGER NOT NULL DEFAULT 0,
        reward_items_json TEXT NOT NULL DEFAULT '[]',
        radar_reduced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_map_resource_logs_timestamp
      ON map_resource_logs(timestamp DESC)
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
    if (oldVersion < 8) {
      await _createPendingConstructionTable(db);
    }
    if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE battle_logs ADD COLUMN reward_items_json TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE battle_logs ADD COLUMN drop_ship_ids_json TEXT NOT NULL DEFAULT '[]'",
      );
      await _createMapResourceTable(db);
    }
    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE battle_logs ADD COLUMN friend_formation INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE battle_logs ADD COLUMN enemy_formation INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE battle_logs ADD COLUMN air_superiority TEXT NOT NULL DEFAULT '$_unknownAirSuperiority'",
      );
      await db.execute(
        "ALTER TABLE battle_logs ADD COLUMN heavy_damage_ship_names_json TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE battle_logs ADD COLUMN detail_json TEXT');
    }
    if (oldVersion < 12) {
      // Older upgrades can already create this table with the latest columns.
      await _createMapResourceTable(db);
      final columns = (await db.rawQuery(
        'PRAGMA table_info(map_resource_logs)',
      )).map((column) => column['name']).toSet();
      for (final column in <String>[
        'instant_build_delta',
        'instant_repair_delta',
        'development_material_delta',
        'improvement_material_delta',
      ]) {
        if (!columns.contains(column)) {
          await db.execute(
            'ALTER TABLE map_resource_logs ADD COLUMN $column INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
    }
  }

  /// Add a battle record to the log
  Future<int> insertBattleRecord(
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
      return '-';
    }

    var mainMvp = '-';
    var escortMvp = '-';
    for (final position in battle.mvpPositions) {
      if (position >= 6) {
        escortMvp = nameAt(battle.friendEscort, position - 6);
      } else {
        mainMvp = nameAt(battle.friendMain, position);
      }
    }
    final isPractice = battle.context.practice || battle.context.mapAreaId == 0;
    final id = await db.insert('battle_logs', {
      'timestamp': record.completedAt.millisecondsSinceEpoch,
      'map_area': isPractice ? 0 : battle.context.mapAreaId,
      'map_no': isPractice ? 0 : battle.context.mapInfoNo,
      'map_name': isPractice ? '演习' : mapName,
      'node': isPractice ? 0 : battle.context.node,
      'node_label': isPractice ? '-' : nodeLabel,
      'node_type': isPractice ? '普通战斗' : battle.context.nodeTypeLabel,
      'map_difficulty': isPractice ? 0 : mapDifficulty,
      'rank': battle.rank.name,
      'drop_ship_id': battle.dropShipMasterId,
      'drop_ship_ids_json': jsonEncode(battle.dropShipMasterIds),
      'enemy_fleet_name': isPractice ? '-' : battle.enemyFleetName,
      // We can store a brief snapshot of ships or just ignore it for the DB to save space,
      // but for now let's just store the count of alive ships as a simple string or JSON.
      // E.g., '6/6'
      'friend_fleet_state':
          '${battle.friendShips.where((s) => !s.isSunk).length}/${battle.friendShips.length}',
      'enemy_fleet_state':
          '${battle.enemyShips.where((s) => !s.isSunk).length}/${battle.enemyShips.length}',
      'friend_formation': battle.friendFormation,
      'enemy_formation': battle.enemyFormation,
      'air_superiority': battle.airSuperiority ?? _unknownAirSuperiority,
      'heavy_damage_ship_names_json': jsonEncode(
        battle.friendShips
            .where((ship) => ship.isHeavilyDamaged)
            .map((ship) => ship.name)
            .toList(),
      ),
      'flagship_name': battle.friendMain.isEmpty
          ? '-'
          : battle.friendMain.first.name,
      'escort_flagship_name': battle.friendEscort.isEmpty
          ? '-'
          : battle.friendEscort.first.name,
      'mvp_name': mainMvp,
      'escort_mvp_name': escortMvp,
      'reward_items_json': jsonEncode(_rewardItemRows(battle.rewardItems)),
      'detail_json': record.detail == null
          ? null
          : jsonEncode(record.detail!.toJson()),
    });
    _notifyChange(LogbookChangeCategory.battle);
    return id;
  }

  Future<BattleDetailSnapshot?> getBattleDetail(int id) async {
    final db = await database;
    final rows = await db.query(
      'battle_logs',
      columns: const <String>['detail_json'],
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.single['detail_json']?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return BattleDetailSnapshot.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException {
      return null;
    }
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

  Future<void> insertMapResourceRecord(MapResourceLogEntry entry) async {
    final db = await database;
    await db.insert('map_resource_logs', <String, Object?>{
      'event_key': entry.eventKey,
      'timestamp': entry.timestamp.millisecondsSinceEpoch,
      'map_area': entry.mapArea,
      'map_no': entry.mapNo,
      'map_name': entry.mapName,
      'node': entry.node,
      'node_label': entry.nodeLabel,
      'map_difficulty': entry.mapDifficulty,
      'fuel_delta': entry.fuelDelta,
      'ammo_delta': entry.ammoDelta,
      'steel_delta': entry.steelDelta,
      'bauxite_delta': entry.bauxiteDelta,
      'instant_build_delta': entry.instantBuildDelta,
      'instant_repair_delta': entry.instantRepairDelta,
      'development_material_delta': entry.developmentMaterialDelta,
      'improvement_material_delta': entry.improvementMaterialDelta,
      'reward_items_json': jsonEncode(_rewardItemRows(entry.rewardItems)),
      'radar_reduced': entry.radarReduced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    _notifyChange(LogbookChangeCategory.battle);
  }

  Future<List<Map<String, dynamic>>> getSortieRecords({
    int limit = 50,
    int offset = 0,
    SortieRecordQuery query = const SortieRecordQuery(),
  }) async {
    final db = await database;
    final clauses = <String>[];
    final arguments = <Object>[];
    if (query.sinceTimestamp case final since?) {
      clauses.add('timestamp >= ?');
      arguments.add(since);
    }
    if (query.maps.isNotEmpty) {
      clauses.add(
        '(${query.maps.map((_) => '(map_area = ? AND map_no = ? AND map_name = ? AND map_difficulty = ?)').join(' OR ')})',
      );
      for (final map in query.maps) {
        arguments.addAll(<Object>[
          map.mapArea,
          map.mapNo,
          map.mapName,
          map.mapDifficulty,
        ]);
      }
    }
    if (query.statuses.isNotEmpty) {
      final statusClauses = <String>[];
      if (query.statuses.contains(sortieResourceStatusToken)) {
        statusClauses.add("record_type = 'resource'");
      }
      final battleStatuses = query.statuses
          .where((status) => status != sortieResourceStatusToken)
          .toList(growable: false);
      if (battleStatuses.isNotEmpty) {
        statusClauses.add(
          "(record_type = 'battle' AND CAST(node_type AS TEXT) IN (${List.filled(battleStatuses.length, '?').join(', ')}))",
        );
        arguments.addAll(battleStatuses);
      }
      clauses.add('(${statusClauses.join(' OR ')})');
    }
    final rank = query.rank?.trim().toUpperCase() ?? '';
    if (rank.isNotEmpty) {
      clauses.add("record_type = 'battle' AND UPPER(rank) = ?");
      arguments.add(rank);
    }
    final whereClause = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return db.rawQuery(
      '''
      SELECT * FROM (
        SELECT
          id * 2 AS id,
          'battle' AS record_type,
          timestamp, map_area, map_no, map_name, node, node_label, node_type,
          map_difficulty, rank, drop_ship_id, drop_ship_ids_json,
          enemy_fleet_name,
          friend_fleet_state, enemy_fleet_state,
          friend_formation, enemy_formation, air_superiority,
          heavy_damage_ship_names_json, flagship_name,
          escort_flagship_name, mvp_name, escort_mvp_name,
          reward_items_json,
          CASE WHEN detail_json IS NOT NULL AND TRIM(detail_json) <> ''
            THEN 1 ELSE 0 END AS has_detail,
          0 AS fuel_delta, 0 AS ammo_delta, 0 AS steel_delta,
          0 AS bauxite_delta,
          0 AS instant_build_delta, 0 AS instant_repair_delta,
          0 AS development_material_delta, 0 AS improvement_material_delta,
          0 AS radar_reduced
        FROM battle_logs
        UNION ALL
        SELECT
          id * 2 + 1 AS id,
          'resource' AS record_type,
          timestamp, map_area, map_no, map_name, node, node_label,
          'resource' AS node_type,
          map_difficulty, 'unknown' AS rank, NULL AS drop_ship_id,
          '[]' AS drop_ship_ids_json,
          '-' AS enemy_fleet_name, '-' AS friend_fleet_state,
          '-' AS enemy_fleet_state, 0 AS friend_formation,
          0 AS enemy_formation, '$_unknownAirSuperiority' AS air_superiority,
          '[]' AS heavy_damage_ship_names_json, '-' AS flagship_name,
          '-' AS escort_flagship_name, '-' AS mvp_name,
          '-' AS escort_mvp_name, reward_items_json, 0 AS has_detail,
          fuel_delta, ammo_delta, steel_delta, bauxite_delta,
          instant_build_delta, instant_repair_delta,
          development_material_delta, improvement_material_delta, radar_reduced
        FROM map_resource_logs
      )
      $whereClause
      ORDER BY timestamp DESC, id DESC
      LIMIT ? OFFSET ?
      ''',
      <Object>[...arguments, limit, offset],
    );
  }

  Future<SortieFilterCatalog> getSortieFilterCatalog() async {
    final db = await database;
    final mapRows = await db.rawQuery('''
      SELECT map_area, map_no, map_name, map_difficulty
      FROM battle_logs
      UNION
      SELECT map_area, map_no, map_name, map_difficulty
      FROM map_resource_logs
      ORDER BY map_area, map_no, map_difficulty, map_name
    ''');
    final statusRows = await db.rawQuery('''
      SELECT CAST(node_type AS TEXT) AS status
      FROM battle_logs
      WHERE TRIM(CAST(node_type AS TEXT)) <> ''
      UNION
      SELECT '$sortieResourceStatusToken' AS status
      FROM map_resource_logs
      ORDER BY status
    ''');
    return SortieFilterCatalog(
      maps: List<SortieMapIdentity>.unmodifiable(
        mapRows.map(
          (row) => SortieMapIdentity(
            mapArea: row['map_area'] as int? ?? 0,
            mapNo: row['map_no'] as int? ?? 0,
            mapName: row['map_name']?.toString() ?? '',
            mapDifficulty: row['map_difficulty'] as int? ?? 0,
          ),
        ),
      ),
      statuses: List<String>.unmodifiable(
        statusRows.map((row) => row['status']?.toString() ?? ''),
      ),
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
    final id = await db.insert(
      'construction_logs',
      _constructionRecordRow(
        dockId: dockId,
        timestamp: timestamp,
        constructionType: constructionType,
        shipId: shipId,
        shipName: shipName,
        shipType: shipType,
        fuel: fuel,
        ammo: ammo,
        steel: steel,
        bauxite: bauxite,
        developmentMaterial: developmentMaterial,
        secretaryName: secretaryName,
      ),
    );
    _notifyChange(LogbookChangeCategory.construction);
    return id;
  }

  Future<int> insertConstructionStartRecord({
    required int dockId,
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
    var changed = false;
    final id = await db.transaction((transaction) async {
      final existingRows = await transaction.rawQuery(
        '''
          SELECT construction_logs.*
          FROM pending_construction_logs
          INNER JOIN construction_logs
            ON construction_logs.id = pending_construction_logs.record_id
          WHERE pending_construction_logs.dock_id = ?
          LIMIT 1
        ''',
        <Object?>[dockId],
      );
      final existing = existingRows.isEmpty ? null : existingRows.single;
      if (_sameConstructionStart(
        existing,
        dockId: dockId,
        timestamp: timestamp,
        constructionType: constructionType,
        fuel: fuel,
        ammo: ammo,
        steel: steel,
        bauxite: bauxite,
        developmentMaterial: developmentMaterial,
      )) {
        final existingId = existing!['id'] as int;
        if (shipId != null && shipId > 0 && existing['ship_id'] != shipId) {
          await transaction.update(
            'construction_logs',
            {'ship_id': shipId, 'ship_name': shipName, 'ship_type': shipType},
            where: 'id = ?',
            whereArgs: <Object?>[existingId],
          );
          changed = true;
        }
        return existingId;
      }

      final recordId = await transaction.insert(
        'construction_logs',
        _constructionRecordRow(
          dockId: dockId,
          timestamp: timestamp,
          constructionType: constructionType,
          shipId: shipId,
          shipName: shipName,
          shipType: shipType,
          fuel: fuel,
          ammo: ammo,
          steel: steel,
          bauxite: bauxite,
          developmentMaterial: developmentMaterial,
          secretaryName: secretaryName,
        ),
      );
      await transaction.insert('pending_construction_logs', {
        'dock_id': dockId,
        'record_id': recordId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed = true;
      return recordId;
    });
    if (changed) _notifyChange(LogbookChangeCategory.construction);
    return id;
  }

  bool _sameConstructionStart(
    Map<String, Object?>? row, {
    required int dockId,
    required int timestamp,
    required String constructionType,
    required int fuel,
    required int ammo,
    required int steel,
    required int bauxite,
    required int developmentMaterial,
  }) =>
      row != null &&
      row['dock_id'] == dockId &&
      row['timestamp'] == timestamp &&
      row['construction_type'] == constructionType &&
      row['fuel'] == fuel &&
      row['ammo'] == ammo &&
      row['steel'] == steel &&
      row['bauxite'] == bauxite &&
      row['development_material'] == developmentMaterial;

  Map<String, Object?> _constructionRecordRow({
    required int dockId,
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
  }) => <String, Object?>{
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
  };

  Future<bool> updateConstructionResult({
    required int recordId,
    required int dockId,
    required int shipId,
    required String shipName,
    required String shipType,
    bool markCollected = false,
  }) async {
    final db = await database;
    Future<int> update(DatabaseExecutor executor) => executor.update(
      'construction_logs',
      {'ship_id': shipId, 'ship_name': shipName, 'ship_type': shipType},
      where: 'id = ? AND dock_id = ?',
      whereArgs: <Object?>[recordId, dockId],
    );
    final changed = markCollected
        ? await db.transaction((transaction) async {
            final count = await update(transaction);
            if (count > 0) {
              await transaction.delete(
                'pending_construction_logs',
                where: 'dock_id = ? AND record_id = ?',
                whereArgs: <Object?>[dockId, recordId],
              );
            }
            return count;
          })
        : await update(db);
    if (changed > 0) _notifyChange(LogbookChangeCategory.construction);
    return changed > 0;
  }

  Future<Map<String, dynamic>?> getPendingConstructionRecordForDock(
    int dockId,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
        SELECT construction_logs.*
        FROM pending_construction_logs
        INNER JOIN construction_logs
          ON construction_logs.id = pending_construction_logs.record_id
        WHERE pending_construction_logs.dock_id = ?
        LIMIT 1
      ''',
      <Object?>[dockId],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<bool> clearPendingConstructionRecordForDock({
    required int dockId,
    required int recordId,
  }) async {
    final db = await database;
    final count = await db.delete(
      'pending_construction_logs',
      where: 'dock_id = ? AND record_id = ?',
      whereArgs: <Object?>[dockId, recordId],
    );
    return count > 0;
  }

  Future<Map<String, dynamic>?> getLatestConstructionRecordForDock(
    int dockId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'construction_logs',
      where: 'dock_id = ?',
      whereArgs: <Object?>[dockId],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
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

  /// The actual observation used as the range baseline; never synthesizes a
  /// midnight snapshot from a later observation.
  Future<Map<String, dynamic>?> getResourceSnapshotAtOrBefore(
    DateTime at,
  ) async {
    final db = await database;
    final rows = await db.query(
      'resource_logs',
      where: 'timestamp <= ?',
      whereArgs: [at.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC, id DESC',
      limit: 1,
    );
    return rows.singleOrNull;
  }

  /// Keyset pagination in observation order, including backdated imports and
  /// multiple changes captured in the same millisecond. Export keeps its
  /// existing id-ordered stream below.
  Stream<Map<String, dynamic>> streamResourceLogsByTimestamp({
    required DateTime start,
    required DateTime end,
    int pageSize = 1000,
  }) async* {
    assert(pageSize > 0);
    final db = await database;
    int? lastTime;
    var lastId = 0;
    while (true) {
      final rows = await db.query(
        'resource_logs',
        where:
            'timestamp >= ? AND timestamp <= ?'
            '${lastTime == null ? '' : ' AND (timestamp > ? OR (timestamp = ? AND id > ?))'}',
        whereArgs: [
          // Move the indexed lower bound with the cursor; otherwise SQLite
          // rescans all earlier pages before evaluating the tie-breaking OR.
          lastTime ?? start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          if (lastTime != null) ...[lastTime, lastTime, lastId],
        ],
        orderBy: 'timestamp ASC, id ASC',
        limit: pageSize,
      );
      for (final row in rows) {
        yield row;
      }
      if (rows.length < pageSize) return;
      lastTime = (rows.last['timestamp'] as num).toInt();
      lastId = (rows.last['id'] as num).toInt();
    }
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
      await transaction.delete('map_resource_logs');
      await transaction.delete('resource_logs');
      await transaction.delete('expedition_logs');
      await transaction.delete('pending_construction_logs');
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

List<Map<String, Object?>> _rewardItemRows(
  Iterable<BattleRewardItem> rewards,
) => <Map<String, Object?>>[
  for (final reward in rewards)
    <String, Object?>{
      'kind': reward.kind.name,
      'id': reward.id,
      'count': reward.count,
      'name': reward.name,
    },
];

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
