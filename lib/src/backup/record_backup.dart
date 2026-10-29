import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_session.dart';
import '../logbook/logbook_database.dart';
import '../senka/senka_controller.dart';
import '../senka/senka_store.dart';
import '../toolbox/composition_record_snapshot.dart';
import '../toolbox/composition_record_store.dart';

/// The Android implementation uses a persisted Storage Access Framework tree
/// permission. Documents in that tree remain after the application is removed.
abstract interface class BackupDocumentPort {
  Future<bool> hasDirectory();
  Future<bool> chooseDirectory();
  Future<Uint8List?> readLive(int memberId, String suggestedName);
  Future<void> writeLive(int memberId, String suggestedName, Uint8List bytes);
  Future<String> prepareShareFile(String name, Uint8List bytes);
  Future<String> launchShareFile(String token);
  Future<void> discardShareFile(String token);

  /// Stages the complete archive before opening the picker, then writes and
  /// verifies the chosen document without depending on a Flutter resume.
  Future<String?> saveFile(String name, Uint8List bytes);
  Future<void> completeSavedFile(String token);
  Future<void> discardSavedFile(String token);
  Future<Uint8List?> pickImport();
}

abstract interface class RecordBackupEnabledStore {
  Future<bool> load();
  Future<void> save(bool enabled);
}

final class SharedPreferencesRecordBackupEnabledStore
    implements RecordBackupEnabledStore {
  const SharedPreferencesRecordBackupEnabledStore();
  static const key = 'record_backup_enabled';

  @override
  Future<bool> load() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;

  @override
  Future<void> save(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      key,
      enabled,
    );
    if (!saved) throw StateError('Could not save backup setting');
  }
}

final class AndroidBackupDocumentPort implements BackupDocumentPort {
  const AndroidBackupDocumentPort({
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/record_backup',
    ),
    this.validateCandidate,
    this.worker = const BackupArchiveWorker(),
  });
  final MethodChannel channel;
  final Future<void> Function(BackupArchive archive)? validateCandidate;
  final BackupArchiveWorker worker;

  @override
  Future<bool> hasDirectory() async =>
      await channel.invokeMethod<bool>('hasDirectory') ?? false;
  @override
  Future<bool> chooseDirectory() async =>
      await channel.invokeMethod<bool>('chooseDirectory') ?? false;
  @override
  Future<Uint8List?> readLive(int memberId, String suggestedName) async {
    final arguments = <String, Object>{
      'memberId': memberId,
      'name': suggestedName,
    };
    var found = false;
    String? chosenSlot;
    Uint8List? chosenBytes;
    // A verified pending write is newer than both the old main and previous.
    // Full archive validation lives here so native and Dart cannot disagree
    // about what constitutes a restorable backup.
    for (final slot in ['pending', 'main', 'previous']) {
      Uint8List? bytes;
      try {
        bytes = await channel.invokeMethod<Uint8List>('readCandidate', {
          ...arguments,
          'slot': slot,
        });
      } catch (error) {
        throw StateError('Backup copy cannot be read ($slot): $error');
      }
      if (bytes == null) continue;
      found = true;
      // Each slot is still read from disk. Identical bytes have already passed
      // the complete codec, ownership and SQLite checks in this invocation.
      if (chosenBytes != null && listEquals(bytes, chosenBytes)) continue;
      BackupArchive archive;
      try {
        archive = await worker.decode(bytes);
      } catch (_) {
        continue;
      }
      if (archive.memberId != memberId) {
        throw StateError('Backup copy belongs to another account');
      }
      // Older copies cannot replace the highest-priority restorable one. Keep
      // their read/ownership barriers without repeating SQLite restoration
      // validation for snapshots that this read will never select or promote.
      if (chosenBytes != null) continue;
      try {
        await (validateCandidate?.call(archive) ??
            LogbookDatabase.forAccount(
              memberId,
            ).validateBackupSnapshot(archive.tables));
      } on FormatException {
        // A checksum can still cover an archive that SQLite cannot restore.
        // Such a copy must never replace a healthy older main document.
        continue;
      }
      chosenSlot = slot;
      chosenBytes = bytes;
    }
    if (chosenBytes != null) {
      if (chosenSlot != 'main') {
        await channel.invokeMethod<void>('promoteCandidate', {
          ...arguments,
          'slot': chosenSlot,
          'bytes': chosenBytes,
        });
        final promoted = await channel.invokeMethod<Uint8List>(
          'readCandidate',
          {...arguments, 'slot': 'main'},
        );
        if (promoted == null || !listEquals(promoted, chosenBytes)) {
          throw StateError('Backup recovery verification failed');
        }
      }
      return chosenBytes;
    }
    if (found) throw StateError('No valid backup copy was found');
    return null;
  }

  @override
  Future<void> writeLive(int memberId, String suggestedName, Uint8List bytes) =>
      channel.invokeMethod<void>('writeLive', {
        'memberId': memberId,
        'name': suggestedName,
        'bytes': bytes,
      });
  @override
  Future<String> prepareShareFile(String name, Uint8List bytes) async =>
      await channel.invokeMethod<String>('prepareShareFile', {
        'name': name,
        'bytes': bytes,
      }) ??
      (throw StateError('Share file unavailable'));
  @override
  Future<String> launchShareFile(String token) async =>
      await channel.invokeMethod<String>('launchShareFile', {'token': token}) ??
      (throw StateError('Share destination unavailable'));
  @override
  Future<void> discardShareFile(String token) =>
      channel.invokeMethod<void>('discardShareFile', {'token': token});
  @override
  Future<String?> saveFile(String name, Uint8List bytes) =>
      channel.invokeMethod<String>('saveFile', {'name': name, 'bytes': bytes});
  @override
  Future<void> completeSavedFile(String token) =>
      channel.invokeMethod<void>('completeSavedFile', {'token': token});
  @override
  Future<void> discardSavedFile(String token) =>
      channel.invokeMethod<void>('discardSavedFile', {'token': token});
  @override
  Future<Uint8List?> pickImport() =>
      channel.invokeMethod<Uint8List>('pickImport');
}

final class BackupArchive {
  // Archive data has its own compatibility version. Bumping the SQLite schema
  // alone must not make already exported v12 files unreadable. Before changing
  // the table contract, add a migrator in _tablesForArchiveSchema.
  static const int logbookArchiveSchema = 12;
  static const List<String> _v12Tables = [
    'battle_logs',
    'map_resource_logs',
    'resource_logs',
    'expedition_logs',
    'pending_construction_logs',
    'construction_logs',
    'development_logs',
    'retirement_logs',
  ];

  static List<String> _tablesForArchiveSchema(Object? schema) =>
      switch (schema) {
        12 => _v12Tables,
        _ => throw const FormatException('Unsupported logbook archive schema'),
      };

  const BackupArchive({
    required this.memberId,
    required this.tables,
    required this.compositions,
    this.writerId = '',
    this.rowIds = const {},
    this.writerRowIds = const {},
    this.senkaRaw,
    this.senkaSources = const {},
  });
  final int memberId;
  final Map<String, List<Map<String, Object?>>> tables;
  final List<CompositionRecord> compositions;

  /// Exact JSON from the owning account; retain unknown future state fields.
  /// A missing value in a v1 archive means preserve the live senka on restore.
  final String? senkaRaw;
  final Map<String, String> senkaSources;

  /// The app installation that last merged database rows into this archive.
  final String writerId;

  /// Main-database row ID -> archive row ID for [writerId].
  final Map<String, Map<String, int>> rowIds;

  /// Retain each database's source IDs when another database writes the file.
  /// [rowIds] remains the current writer's projection for older readers.
  final Map<String, Map<String, Map<String, int>>> writerRowIds;

  Map<String, Map<String, Map<String, int>>> _allWriterRowIds() => {
    ...writerRowIds,
    if (writerId.isNotEmpty) writerId: rowIds,
  };

  BackupArchive merge(
    Map<String, List<Map<String, Object?>>> currentTables,
    List<CompositionRecord> currentCompositions, {
    required String writerId,
    Set<String> deletedCompositions = const {},
    String? senkaRaw,
  }) {
    final mergedTables = <String, List<Map<String, Object?>>>{};
    final mergedRowIds = <String, Map<String, int>>{};
    final allWriterRowIds = _allWriterRowIds();
    for (final table in LogbookDatabase.backupTables) {
      if (table == 'pending_construction_logs') {
        mergedTables[table] = currentTables[table]!;
        continue;
      }
      final rows = <Object?, Map<String, Object?>>{};
      for (final row in tables[table]!) {
        rows[row['id']] = row;
      }
      final ids = Map<String, int>.from(
        allWriterRowIds[writerId]?[table] ??
            (this.writerId == writerId ? rowIds[table] : null) ??
            const {},
      );
      final eventIds = table == 'map_resource_logs'
          ? <Object?, int>{
              for (final entry in rows.entries)
                if (entry.key is int)
                  entry.value['event_key']: entry.key as int,
            }
          : <Object?, int>{};
      var nextId = rows.keys.whereType<int>().fold<int>(0, max) + 1;
      for (final row in currentTables[table]!) {
        final sourceId = row['id'];
        if (sourceId is! int || sourceId <= 0) {
          throw FormatException('Invalid row ID in $table');
        }
        var targetId = ids['$sourceId'] ?? eventIds[row['event_key']];
        if (targetId == null) {
          final existing = rows[sourceId];
          if (existing == null ||
              (this.writerId == writerId && _sameRowWithoutId(existing, row))) {
            targetId = sourceId;
          } else {
            while (rows.containsKey(nextId)) {
              nextId++;
            }
            targetId = nextId++;
          }
        }
        ids['$sourceId'] = targetId;
        rows[targetId] = {...row, 'id': targetId};
        if (table == 'map_resource_logs') eventIds[row['event_key']] = targetId;
      }
      mergedTables[table] = rows.values.toList();
      mergedRowIds[table] = ids;
    }
    final constructionIds = mergedRowIds['construction_logs'] ?? const {};
    final currentConstructionIds = <int>{
      for (final row in currentTables['construction_logs']!)
        constructionIds['${row['id']}'] ?? row['id'] as int,
    };
    final pendingByDock = <int, Map<String, Object?>>{
      for (final row in tables['pending_construction_logs']!)
        if (!currentConstructionIds.contains(row['record_id']))
          row['dock_id'] as int: row,
    };
    for (final row in currentTables['pending_construction_logs']!) {
      pendingByDock[row['dock_id'] as int] = {
        ...row,
        'record_id': constructionIds['${row['record_id']}'] ?? row['record_id'],
      };
    }
    mergedTables['pending_construction_logs'] = pendingByDock.values.toList();
    final records = <String, CompositionRecord>{
      for (final record in compositions) record.id: record,
      for (final record in currentCompositions) record.id: record,
    };
    for (final id in deletedCompositions) {
      records.remove(id);
    }
    final sources = Map<String, String>.of(senkaSources);
    if (senkaRaw != null &&
        this.senkaRaw != null &&
        senkaRaw != this.senkaRaw &&
        this.writerId != writerId) {
      final sourceKey =
          '${this.writerId}:${sha256.convert(utf8.encode(this.senkaRaw!))}';
      sources[sourceKey] = this.senkaRaw!;
    }
    return BackupArchive(
      memberId: memberId,
      tables: mergedTables,
      compositions: records.values.toList(),
      writerId: writerId,
      rowIds: mergedRowIds,
      writerRowIds: {
        ...allWriterRowIds,
        if (writerId.isNotEmpty) writerId: mergedRowIds,
      },
      senkaRaw: senkaRaw ?? this.senkaRaw,
      senkaSources: sources,
    );
  }

  static bool _sameRowWithoutId(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final a = Map<String, Object?>.from(left)..remove('id');
    final b = Map<String, Object?>.from(right)..remove('id');
    return mapEquals(a, b);
  }

  static void _validateWriterMappingLimits(Map mappings) {
    // Bound the new dimension without reducing the old per-table allowance.
    // Reject overflow rather than evicting identities and duplicating history.
    if (mappings.length > 256) {
      throw const FormatException('Too many backup writers');
    }
    var total = 0;
    for (final writer in mappings.entries) {
      if (writer.key is! String ||
          (writer.key as String).isEmpty ||
          (writer.key as String).length > 100 ||
          writer.value is! Map) {
        throw const FormatException('Invalid backup writer mapping');
      }
      for (final table in (writer.value as Map).entries) {
        if (!LogbookDatabase.backupTables.contains(table.key) ||
            table.value is! Map ||
            (table.value as Map).length > 1000000) {
          throw const FormatException('Invalid backup writer mapping');
        }
        total += (table.value as Map).length;
        if (total > LogbookDatabase.backupTables.length * 1000000) {
          throw const FormatException('Too many backup row mappings');
        }
      }
    }
  }

  static Map<String, Map<String, Map<String, int>>> _decodeWriterRowIds(
    Object? raw,
    Map<String, List<Map<String, Object?>>> tables,
  ) {
    if (raw == null) return {};
    if (raw is! Map) {
      throw const FormatException('Invalid backup writer mappings');
    }
    _validateWriterMappingLimits(raw);
    final existingIds = <String, Set<int>>{};
    final result = <String, Map<String, Map<String, int>>>{};
    for (final writer in raw.entries) {
      final mappedTables = <String, Map<String, int>>{};
      for (final table in (writer.value as Map).entries) {
        final name = table.key as String;
        final targets = existingIds.putIfAbsent(
          name,
          () => tables[name]!.map((row) => row['id']).whereType<int>().toSet(),
        );
        final ids = <String, int>{};
        final usedTargets = <int>{};
        for (final entry in (table.value as Map).entries) {
          final sourceId = entry.key is String
              ? int.tryParse(entry.key as String)
              : null;
          final targetId = entry.value;
          if (sourceId == null ||
              sourceId <= 0 ||
              '$sourceId' != entry.key ||
              targetId is! int ||
              !targets.contains(targetId) ||
              !usedTargets.add(targetId)) {
            throw const FormatException('Invalid backup writer row mapping');
          }
          ids[entry.key as String] = targetId;
        }
        mappedTables[name] = ids;
      }
      result[writer.key as String] = mappedTables;
    }
    return result;
  }

  Uint8List encode({
    int maxPlainBytes = 250 * 1024 * 1024,
    int maxEncodedBytes = 100 * 1024 * 1024,
  }) {
    final allWriterRowIds = _allWriterRowIds();
    _validateWriterMappingLimits(allWriterRowIds);
    if (senkaRaw != null) validateSenkaArchiveRaw(senkaRaw!, memberId);
    if (senkaRaw == null && senkaSources.isNotEmpty) {
      throw const FormatException(
        'Senka source snapshots need a primary archive',
      );
    }
    for (final entry in senkaSources.entries) {
      if (entry.key.isEmpty || entry.key.length > 200) {
        throw const FormatException('Invalid senka source key');
      }
      validateSenkaArchiveRaw(entry.value, memberId);
    }
    // Compress JSON as it is produced. A complete plain JSON String and its
    // UTF-8 copy can otherwise coexist with the database snapshot and gzip.
    final output = _BackupByteSink();
    final compressor = gzip.encoder.startChunkedConversion(
      _LimitedByteSink(maxEncodedBytes, output),
    );
    final encoder = JsonUtf8Encoder(
      null,
      null,
      16 * 1024,
    ).startChunkedConversion(_LimitedByteSink(maxPlainBytes, compressor));
    try {
      encoder.add({
        'memberId': memberId,
        'logbookSchema': logbookArchiveSchema,
        'tables': tables,
        'compositions': compositions.map((record) => record.toJson()).toList(),
        'writerId': writerId,
        'rowIds': rowIds,
        if (allWriterRowIds.isNotEmpty) 'writerRowIds': allWriterRowIds,
        if (senkaRaw != null) ...{'senkaSchema': 1, 'senkaRaw': senkaRaw},
        if (senkaSources.isNotEmpty) 'senkaSources': senkaSources,
      });
      encoder.close();
    } catch (error, stack) {
      // Finish/release the native compressor even if the plain-size barrier
      // interrupted encoding. The incomplete result is never returned.
      try {
        compressor.close();
      } catch (_) {}
      Error.throwWithStackTrace(error, stack);
    }
    final compressed = output.takeBytes();
    final envelope = _BackupByteSink();
    final envelopeEncoder = JsonUtf8Encoder().startChunkedConversion(
      _LimitedByteSink(maxEncodedBytes, envelope),
    );
    envelopeEncoder.add({
      'format': 'yahagi-record-backup',
      'version': senkaRaw == null ? 1 : 2,
      'sha256': sha256.convert(compressed).toString(),
      'payload': base64Encode(compressed),
    });
    envelopeEncoder.close();
    return envelope.takeBytes();
  }

  static BackupArchive decode(
    Uint8List bytes, {
    int maxPlainBytes = 250 * 1024 * 1024,
  }) {
    if (bytes.length > 100 * 1024 * 1024) {
      throw const FormatException('Backup is too large');
    }
    final jsonUtf8 = utf8.decoder.fuse(json.decoder);
    final outer = jsonUtf8.convert(bytes);
    if (outer is! Map ||
        outer['format'] != 'yahagi-record-backup' ||
        (outer['version'] != 1 && outer['version'] != 2) ||
        outer['payload'] is! String ||
        outer['sha256'] is! String) {
      throw const FormatException('Unsupported backup format');
    }
    final compressed = base64Decode(outer['payload'] as String);
    if (sha256.convert(compressed).toString() != outer['sha256']) {
      throw const FormatException('Backup checksum mismatch');
    }
    // Feed bounded decompression directly into the incremental JSON parser;
    // do not retain an expanded byte buffer and a second complete String.
    final output = _BackupJsonSink();
    final decoder = gzip.decoder.startChunkedConversion(
      _LimitedByteSink(maxPlainBytes, jsonUtf8.startChunkedConversion(output)),
    );
    decoder.add(compressed);
    decoder.close();
    final value = output.value;
    if (value is! Map ||
        value['memberId'] is! int ||
        (value['memberId'] as int) <= 0 ||
        value['tables'] is! Map ||
        value['compositions'] is! List) {
      throw const FormatException('Invalid backup content');
    }
    final archiveTables = _tablesForArchiveSchema(value['logbookSchema']);
    if (!setEquals(
      archiveTables.toSet(),
      LogbookDatabase.backupTables.toSet(),
    )) {
      // Future DB schemas must explicitly translate the old archive tables
      // before restore or merge; silently dropping a table loses history.
      throw const FormatException('Logbook archive migration is required');
    }
    final rawTables = value['tables'] as Map;
    if (!setEquals(rawTables.keys.toSet(), archiveTables.toSet())) {
      throw const FormatException('Invalid logbook table list');
    }
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in archiveTables) {
      final rows = rawTables[table];
      if (rows is! List) throw FormatException('Invalid $table rows');
      tables[table] = rows.map((row) {
        if (row is! Map<String, dynamic>) {
          throw FormatException('Invalid $table row');
        }
        if (row.keys.any((key) => key.isEmpty) ||
            row.values.any((v) => v is! num && v is! String && v != null)) {
          throw FormatException('Invalid $table value');
        }
        return Map<String, Object?>.from(row);
      }).toList();
      if (table != 'pending_construction_logs') {
        final ids = tables[table]!.map((row) => row['id']).toList();
        if (ids.any((id) => id is! int || id <= 0) ||
            ids.toSet().length != ids.length) {
          throw FormatException('Invalid $table IDs');
        }
      }
    }
    final memberId = value['memberId'] as int;
    final String? senkaRaw;
    final senkaSources = <String, String>{};
    if (outer['version'] == 2) {
      if (value['senkaSchema'] != 1 || value['senkaRaw'] is! String) {
        throw const FormatException('Invalid senka backup content');
      }
      senkaRaw = value['senkaRaw'] as String;
      validateSenkaArchiveRaw(senkaRaw, memberId);
      final sources = value['senkaSources'];
      if (sources != null && sources is! Map) {
        throw const FormatException('Invalid senka source snapshots');
      }
      if (sources is Map) {
        for (final entry in sources.entries) {
          if (entry.key is! String ||
              (entry.key as String).isEmpty ||
              (entry.key as String).length > 200 ||
              entry.value is! String) {
            throw const FormatException('Invalid senka source snapshot');
          }
          validateSenkaArchiveRaw(entry.value as String, memberId);
          senkaSources[entry.key as String] = entry.value as String;
        }
      }
    } else {
      if (value.containsKey('senkaRaw') ||
          value.containsKey('senkaSchema') ||
          value.containsKey('senkaSources')) {
        throw const FormatException('Senka backups require format version 2');
      }
      senkaRaw = null;
    }
    final writerId = value['writerId'];
    if (writerId != null && (writerId is! String || writerId.length > 100)) {
      throw const FormatException('Invalid backup writer');
    }
    final rawIds = value['rowIds'];
    if (rawIds != null && rawIds is! Map) {
      throw const FormatException('Invalid backup row mapping');
    }
    final rowIds = <String, Map<String, int>>{};
    if (rawIds is Map) {
      if (rawIds.keys.any(
        (key) => !LogbookDatabase.backupTables.contains(key),
      )) {
        throw const FormatException('Invalid backup row mapping');
      }
      for (final table in LogbookDatabase.backupTables) {
        final mapping = rawIds[table];
        if (mapping == null) continue;
        if (mapping is! Map || mapping.length > 1000000) {
          throw const FormatException('Invalid backup row mapping');
        }
        final ids = <String, int>{};
        for (final entry in mapping.entries) {
          if (entry.key is! String ||
              int.tryParse(entry.key as String) == null ||
              entry.value is! int ||
              (entry.value as int) <= 0) {
            throw const FormatException('Invalid backup row mapping');
          }
          ids[entry.key as String] = entry.value as int;
        }
        rowIds[table] = ids;
        final existingIds = tables[table]!
            .map((row) => row['id'])
            .whereType<int>()
            .toSet();
        if (ids.values.toSet().length != ids.length ||
            ids.values.any((id) => !existingIds.contains(id))) {
          throw const FormatException('Invalid backup row mapping');
        }
      }
    }
    final writerRowIds = _decodeWriterRowIds(value['writerRowIds'], tables);
    if (writerId is String && writerId.isNotEmpty) {
      final currentMapping = writerRowIds[writerId];
      if (currentMapping != null &&
          !LogbookDatabase.backupTables.every(
            (table) => mapEquals(
              currentMapping[table] ?? const <String, int>{},
              rowIds[table] ?? const <String, int>{},
            ),
          )) {
        throw const FormatException(
          'Conflicting current backup writer mapping',
        );
      }
      writerRowIds[writerId] = rowIds;
    }
    _validateWriterMappingLimits(writerRowIds);
    final records = <CompositionRecord>[];
    for (final raw in value['compositions'] as List) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid composition record');
      }
      final record = CompositionRecord.fromJson(raw);
      if (record.snapshotJson == null ||
          record.snapshotJson!.isEmpty ||
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(record.id) ||
          deserializeCompositionSnapshot(record.snapshotJson!).memberId !=
              memberId) {
        throw const FormatException('Composition account mismatch');
      }
      records.add(record);
    }
    if (records.length > 10000 ||
        records.map((r) => r.id).toSet().length != records.length) {
      throw const FormatException('Invalid composition count');
    }
    return BackupArchive(
      memberId: memberId,
      tables: tables,
      compositions: records,
      writerId: writerId as String? ?? '',
      rowIds: rowIds,
      writerRowIds: writerRowIds,
      senkaRaw: senkaRaw,
      senkaSources: senkaSources,
    );
  }
}

final class _LimitedByteSink implements Sink<List<int>> {
  _LimitedByteSink(this.limit, this.next);

  final int limit;
  final Sink<List<int>> next;
  int _length = 0;

  @override
  void add(List<int> chunk) {
    _length += chunk.length;
    if (_length > limit) throw const FormatException('Backup is too large');
    next.add(chunk);
  }

  @override
  void close() => next.close();
}

final class _BackupByteSink implements Sink<List<int>> {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) => _bytes.add(chunk);

  @override
  void close() {}

  Uint8List takeBytes() => _bytes.takeBytes();
}

final class _BackupJsonSink implements Sink<Object?> {
  Object? value;

  @override
  void add(Object? value) => this.value = value;

  @override
  void close() {}
}

final class _BackupSourceSnapshot {
  Map<String, List<Map<String, Object?>>>? tables;
  List<CompositionRecord>? compositions;
}

final class BackupRestoreJournal {
  const BackupRestoreJournal({
    required this.archive,
    required this.requiresExternal,
  });

  final BackupArchive archive;
  final bool requiresExternal;

  Uint8List encode({int maxEncodedBytes = 100 * 1024 * 1024}) {
    // The journal wraps an archive in base64, so an archive within its own
    // limit can still exceed the journal reader's limit. Reject before writing
    // an unreadable recovery journal or mutating the live database.
    final output = _BackupByteSink();
    final encoder = JsonUtf8Encoder().startChunkedConversion(
      _LimitedByteSink(maxEncodedBytes, output),
    );
    encoder.add({
      'format': 'yahagi-restore-journal',
      'version': 1,
      'memberId': archive.memberId,
      'requiresExternal': requiresExternal,
      'archive': base64Encode(archive.encode()),
    });
    encoder.close();
    return output.takeBytes();
  }

  static BackupRestoreJournal decode(Uint8List bytes) {
    if (bytes.length > 100 * 1024 * 1024) {
      throw const FormatException('Restore journal is too large');
    }
    final value = utf8.decoder.fuse(json.decoder).convert(bytes);
    if (value is! Map ||
        value['format'] != 'yahagi-restore-journal' ||
        value['version'] != 1 ||
        value['memberId'] is! int ||
        value['requiresExternal'] is! bool ||
        value['archive'] is! String) {
      throw const FormatException('Invalid restore journal');
    }
    final archive = BackupArchive.decode(
      base64Decode(value['archive'] as String),
    );
    if (archive.memberId != value['memberId']) {
      throw const FormatException('Restore journal account mismatch');
    }
    return BackupRestoreJournal(
      archive: archive,
      requiresExternal: value['requiresExternal'] as bool,
    );
  }
}

typedef BackupArchiveResult = ({BackupArchive archive, Uint8List bytes});
typedef _BackupMergeInput = ({
  int memberId,
  Uint8List? existing,
  Map<String, List<Map<String, Object?>>> tables,
  List<CompositionRecord> compositions,
  String writerId,
  Set<String> deletedCompositions,
  String? senkaRaw,
});

/// Only detached archive values cross this boundary. Database connections,
/// document ports and account-session objects remain on the calling isolate.
class BackupArchiveWorker {
  const BackupArchiveWorker();

  Future<BackupArchive> decode(
    Uint8List bytes, {
    int maxPlainBytes = 250 * 1024 * 1024,
  }) => compute(_decodeArchive, (bytes, maxPlainBytes));

  Future<Uint8List> encode(BackupArchive archive) =>
      compute(_encodeArchive, archive);

  Future<BackupArchive> normalize(BackupArchive archive) =>
      compute(_normalizeArchive, archive);

  Future<void> validateOwner(int memberId, Uint8List bytes) =>
      compute(_validateArchiveOwner, (memberId, bytes));

  Future<BackupArchiveResult> mergeAndEncode({
    required int memberId,
    required Uint8List? existing,
    required Map<String, List<Map<String, Object?>>> tables,
    required List<CompositionRecord> compositions,
    required String writerId,
    required Set<String> deletedCompositions,
  }) => compute(_mergeArchive, (
    memberId: memberId,
    existing: existing,
    tables: tables,
    compositions: compositions,
    writerId: writerId,
    deletedCompositions: deletedCompositions,
    senkaRaw: null,
  ));

  Future<BackupArchiveResult> mergeAndEncodeWithSenka({
    required int memberId,
    required Uint8List? existing,
    required Map<String, List<Map<String, Object?>>> tables,
    required List<CompositionRecord> compositions,
    required String writerId,
    required Set<String> deletedCompositions,
    required String senkaRaw,
  }) => compute(_mergeArchive, (
    memberId: memberId,
    existing: existing,
    tables: tables,
    compositions: compositions,
    writerId: writerId,
    deletedCompositions: deletedCompositions,
    senkaRaw: senkaRaw,
  ));

  Future<bool> verify(int memberId, Uint8List expected, Uint8List actual) =>
      compute(_verifyArchive, (memberId, expected, actual));

  Future<Uint8List> encodeJournal(BackupRestoreJournal journal) =>
      compute(_encodeJournal, journal);

  Future<BackupRestoreJournal> decodeJournal(Uint8List bytes) =>
      compute(_decodeJournal, bytes);
}

BackupArchive _decodeArchive((Uint8List, int) input) =>
    BackupArchive.decode(input.$1, maxPlainBytes: input.$2);
Uint8List _encodeArchive(BackupArchive archive) => archive.encode();
BackupArchive _normalizeArchive(BackupArchive archive) =>
    BackupArchive.decode(archive.encode());
void _validateArchiveOwner((int, Uint8List) input) {
  if (BackupArchive.decode(input.$2).memberId != input.$1) {
    throw StateError('Backup belongs to another account');
  }
}

Uint8List _encodeJournal(BackupRestoreJournal journal) => journal.encode();
BackupRestoreJournal _decodeJournal(Uint8List bytes) =>
    BackupRestoreJournal.decode(bytes);
bool _verifyArchive((int, Uint8List, Uint8List) input) =>
    BackupArchive.decode(input.$3).memberId == input.$1 &&
    listEquals(input.$2, input.$3);

BackupArchiveResult _mergeArchive(_BackupMergeInput input) {
  final old = input.existing == null
      ? null
      : BackupArchive.decode(input.existing!);
  if (old != null && old.memberId != input.memberId) {
    throw StateError('Backup belongs to another account');
  }
  final archive =
      (old ??
              BackupArchive(
                memberId: input.memberId,
                tables: {
                  for (final table in LogbookDatabase.backupTables) table: [],
                },
                compositions: const [],
              ))
          .merge(
            input.tables,
            input.compositions,
            writerId: input.writerId,
            deletedCompositions: input.deletedCompositions,
            senkaRaw: input.senkaRaw,
          );
  return (archive: archive, bytes: archive.encode());
}

/// Test-only fault used to model process death after a durable restore step.
final class RestoreInterruptionForTesting implements Exception {
  const RestoreInterruptionForTesting();
}

/// Serializes every backup operation, including automatic writes, cleanup
/// barriers, exports and restores. No live document is replaced with an
/// unverified or cross-account archive.
final class RecordBackupService extends ChangeNotifier {
  RecordBackupService({
    required this.session,
    required this.port,
    this.enabledStore = const SharedPreferencesRecordBackupEnabledStore(),
    FileCompositionRecordStore? compositionStore,
    LogbookDatabase Function(int)? databaseFor,
    DateTime Function()? now,
    this.installationId,
    this.deleteRestoreJournal,
    this.deleteCommittedMarker,
    this.deleteAdoptedBaseline,
    this.afterJournalWritten,
    this.afterRestoreStage,
    this.senkaStore,
    this.senkaController,
    this.worker = const BackupArchiveWorker(),
    this.autoSyncDelay = const Duration(seconds: 3),
  }) : compositionStore = compositionStore ?? FileCompositionRecordStore(),
       databaseFor = databaseFor ?? LogbookDatabase.forAccount,
       now = now ?? DateTime.now;

  static RecordBackupService? shared;
  final AccountSession session;
  final BackupDocumentPort port;
  final BackupArchiveWorker worker;

  /// A fixed batching window: continuous writes cannot postpone it forever.
  final Duration autoSyncDelay;
  final RecordBackupEnabledStore enabledStore;
  final FileCompositionRecordStore compositionStore;
  final LogbookDatabase Function(int) databaseFor;
  final DateTime Function() now;
  final String? installationId;
  final Future<void> Function(File file)? deleteRestoreJournal;
  final Future<void> Function(File file)? deleteCommittedMarker;
  final Future<void> Function(File file)? deleteAdoptedBaseline;
  final Future<void> Function(File file)? afterJournalWritten;
  final Future<void> Function(String stage)? afterRestoreStage;
  final SenkaBackupStore? senkaStore;
  final SenkaController? senkaController;
  Future<void> _queue = Future<void>.value();
  StreamSubscription<CompositionRecordChange>? _compositionSubscription;
  StreamSubscription<int>? _senkaSubscription;
  Future<void>? _subscriptionCancellation;
  final Map<int, LogbookDatabase> _observedDatabases = {};
  final Map<int, VoidCallback> _databaseListeners = {};
  final Map<int, Set<String>> _deletedCompositions = {};
  final Map<int, String> _accountNames = {};
  final Map<int, int> _pendingCounts = {};
  final Set<int> _dirtyAccounts = {};
  final Map<int, int> _writeVersions = {};
  final Set<int> _scheduledAccounts = {};
  final Map<int, Timer> _autoSyncTimers = {};
  final Set<int> _offlineRecoveryScheduled = {};
  final Map<int, String> _lastErrors = {};
  final Map<int, ({Object error, StackTrace stack})> _syncFailures = {};
  final Map<int, DateTime> _lastSyncs = {};
  bool _hasDirectory = false;
  bool _enabled = false;
  bool _started = false;
  Future<void>? _starting;
  bool _busy = false;
  bool _choosingDirectory = false;
  bool _exportActive = false;
  bool _disposed = false;
  bool _closing = false;
  int? _maintenanceMemberId;
  Future<void> Function()? onMaintenanceBegin;
  VoidCallback? onMaintenanceEnd;
  void Function(Object error)? onMaintenanceBlocked;

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  void configureMaintenance({
    required Future<void> Function() begin,
    required VoidCallback end,
    required void Function(Object error) blocked,
  }) {
    onMaintenanceBegin = begin;
    onMaintenanceEnd = end;
    onMaintenanceBlocked = blocked;
  }

  Future<void> _beginMaintenance(int memberId) async {
    if (_maintenanceMemberId != null) {
      throw StateError('Restore maintenance is already active');
    }
    await compositionStore.enterMaintenance(memberId);
    _maintenanceMemberId = memberId;
    try {
      await senkaController?.beginArchiveRestore(memberId);
      await onMaintenanceBegin?.call();
    } catch (_) {
      await _endMaintenance();
      rethrow;
    }
  }

  Future<void> _endMaintenance() async {
    final memberId = _maintenanceMemberId;
    if (memberId == null) return;
    await senkaController?.endArchiveRestore(memberId);
    _maintenanceMemberId = null;
    await compositionStore.leaveMaintenance(memberId);
    onMaintenanceEnd?.call();
  }

  Future<void> recoverPendingRestores() async {
    _hasDirectory = await port.hasDirectory();
    await _enqueue(_recoverAllRestoreJournals);
    await _endMaintenance();
  }

  Future<bool> reselectDirectoryForRecovery() async {
    final selected = await port.chooseDirectory();
    if (!selected) return false;
    _hasDirectory = await port.hasDirectory();
    _notifyIfActive();
    return _hasDirectory;
  }

  bool get hasDirectory => _hasDirectory;
  bool get enabled => _enabled;
  bool get busy => _busy || _choosingDirectory || _exportActive;
  bool get maintenanceActive => _maintenanceMemberId != null;
  bool get pending => (_pendingCounts[session.current.memberId] ?? 0) > 0;
  String? get lastError => _lastErrors[session.current.memberId];
  DateTime? get lastSync => _lastSyncs[session.current.memberId];

  Future<void> start() => _disposed
      ? Future<void>.error(StateError('Record backup service is disposed'))
      : _started
      ? Future<void>.value()
      : (_starting ??= _startImpl().whenComplete(() => _starting = null));

  Future<void> _startImpl() async {
    if (_started) return;
    _enabled = await enabledStore.load();
    if (_disposed) return;
    _hasDirectory = await port.hasDirectory();
    if (_disposed) return;
    await _recoverAllRestoreJournals();
    if (_disposed) return;
    _started = true;
    session.addListener(_accountChanged);
    _compositionSubscription = FileCompositionRecordStore.changes.listen((
      change,
    ) {
      if (change.refreshOnly) return;
      if (change.deleted) {
        _deletedCompositions
            .putIfAbsent(change.memberId, () => {})
            .add(change.id);
      }
      _schedule(change.memberId);
    });
    _senkaSubscription = senkaStore?.archiveChanges.listen(
      (memberId) => _schedule(memberId),
    );
    _accountChanged();
  }

  void _accountChanged() {
    final memberId = session.current.memberId;
    if (memberId > 0) _name(memberId);
    if (memberId > 0 && _offlineRecoveryScheduled.add(memberId)) {
      unawaited(
        _enqueue(() async {
          await _completeOfflineDeletions(memberId);
        }).then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _offlineRecoveryScheduled.remove(memberId);
            _lastErrors[memberId] = '$error';
            _notifyIfActive();
          },
        ),
      );
    }
    if (memberId > 0 && !_observedDatabases.containsKey(memberId)) {
      final database = databaseFor(memberId);
      void listener() => _schedule(memberId);
      _observedDatabases[memberId] = database;
      _databaseListeners[memberId] = listener;
      database.backupWrites.addListener(listener);
    }
    if (_hasDirectory && memberId > 0) _schedule(memberId, immediate: true);
    _notifyIfActive();
  }

  void _schedule(int memberId, {bool immediate = false, bool changed = true}) {
    if ((_disposed && !_closing) ||
        !_enabled ||
        !_hasDirectory ||
        memberId <= 0) {
      return;
    }
    if (changed) {
      _writeVersions[memberId] = (_writeVersions[memberId] ?? 0) + 1;
    }
    _dirtyAccounts.add(memberId);
    if (!_scheduledAccounts.add(memberId)) return;
    _pendingCounts[memberId] = 1;
    _notifyIfActive();
    if (immediate || _closing || autoSyncDelay == Duration.zero) {
      _runAutomaticBackup(memberId);
    } else {
      _autoSyncTimers[memberId] = Timer(autoSyncDelay, () {
        _autoSyncTimers.remove(memberId);
        _runAutomaticBackup(memberId);
      });
    }
  }

  void _flushScheduledBackups() {
    final accounts = _autoSyncTimers.keys.toList();
    for (final memberId in accounts) {
      _autoSyncTimers.remove(memberId)?.cancel();
      _runAutomaticBackup(memberId);
    }
  }

  void _runAutomaticBackup(int memberId) {
    unawaited(
      _enqueue(() async {
        if (!_enabled) return;
        // Yield the queue after a bounded number of passes so manual sync,
        // export and cleanup barriers cannot starve under continuous writes.
        for (
          var pass = 0;
          pass < 2 && _dirtyAccounts.remove(memberId);
          pass++
        ) {
          if (!_enabled) break;
          await _syncFor(memberId);
        }
      }, flushAutomatic: false).then<void>(
        (_) => _finishPending(memberId, retryDirty: true),
        onError: (Object error, StackTrace stack) {
          _lastErrors[memberId] = '$error';
          _finishPending(memberId, retryDirty: false);
        },
      ),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await start();
    await _enqueue(() async {
      if (_enabled == enabled) return;
      await enabledStore.save(enabled);
      _enabled = enabled;
      if (!enabled) {
        _dirtyAccounts.clear();
        _pendingCounts.clear();
        _syncFailures.clear();
      } else if (_hasDirectory && session.current.memberId > 0) {
        _schedule(session.current.memberId);
      }
      _notifyIfActive();
    });
  }

  void _requireEnabled() {
    if (!_enabled) throw StateError('Record backup and restore is disabled');
  }

  void _finishPending(int memberId, {required bool retryDirty}) {
    _scheduledAccounts.remove(memberId);
    if (!retryDirty && _enabled && _syncFailures.containsKey(memberId)) {
      // Keep the failed batch, including writes that arrived during it. A
      // later explicit barrier retries once; failure must not cause a hot loop.
      _dirtyAccounts.add(memberId);
      _pendingCounts[memberId] = 1;
    } else {
      _pendingCounts.remove(memberId);
    }
    _notifyIfActive();
    if ((!_disposed || _closing) &&
        retryDirty &&
        _dirtyAccounts.contains(memberId)) {
      _schedule(memberId, changed: false);
    }
  }

  Future<T> _enqueue<T>(
    Future<T> Function() operation, {
    bool flushAutomatic = true,
    int? replacesAutomaticFor,
  }) {
    int? consumedBatch;
    if (replacesAutomaticFor != null) {
      final timer = _autoSyncTimers.remove(replacesAutomaticFor);
      if (timer != null) {
        // This explicit operation takes a fresh snapshot itself. Consume its
        // unstarted batch instead of serializing two identical full archives.
        timer.cancel();
        _scheduledAccounts.remove(replacesAutomaticFor);
        consumedBatch = replacesAutomaticFor;
      }
    }
    // Explicit sync/export/restore/cleanup is a durability barrier and must
    // include batches for accounts that are no longer in the foreground.
    if (flushAutomatic) _flushScheduledBackups();
    final result = _queue.then((_) async {
      _busy = true;
      _notifyIfActive();
      try {
        return await operation();
      } finally {
        _busy = false;
        final memberId = consumedBatch;
        if (memberId != null &&
            _dirtyAccounts.contains(memberId) &&
            !_scheduledAccounts.contains(memberId) &&
            !_syncFailures.containsKey(memberId)) {
          // A queued export may reject its captured account before syncing.
          // Its unacknowledged batch still belongs to that original account.
          _schedule(memberId, changed: false);
        }
        _notifyIfActive();
      }
    });
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  String _name(int memberId) {
    String clean(String value) =>
        value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (session.current.memberId == memberId) {
      final admiral = session.admiralName;
      final server = session.serverName;
      if (admiral.isNotEmpty || server.isNotEmpty) {
        final name =
            '${clean(admiral.isEmpty ? 'Admiral$memberId' : admiral)}-${clean(server.isEmpty ? 'UnknownServer' : server)}';
        _accountNames[memberId] = name;
        return name;
      }
    }
    return _accountNames[memberId] ?? 'Admiral$memberId-UnknownServer';
  }

  String _offlineDeletionKey(int memberId) =>
      'record_backup_offline_deleted_compositions_$memberId';

  Future<Set<String>> _offlineDeletions(int memberId) async =>
      (await SharedPreferences.getInstance())
          .getStringList(_offlineDeletionKey(memberId))
          ?.toSet() ??
      <String>{};

  Future<void> _rememberOfflineDeletion(int memberId, String id) async {
    final preferences = await SharedPreferences.getInstance();
    final deleted = await _offlineDeletions(memberId);
    deleted.add(id);
    if (!await preferences.setStringList(
      _offlineDeletionKey(memberId),
      deleted.toList(),
    )) {
      throw StateError('Could not save pending composition deletion');
    }
  }

  Future<Set<String>> _completeOfflineDeletions(int memberId) async {
    final deleted = await _offlineDeletions(memberId);
    for (final id in deleted) {
      await compositionStore.delete(memberId, id);
    }
    return deleted;
  }

  Future<void> _forgetCompositionDeletions(int memberId) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey(_offlineDeletionKey(memberId)) &&
        !await preferences.remove(_offlineDeletionKey(memberId))) {
      throw StateError('Could not clear pending composition deletion');
    }
    _deletedCompositions.remove(memberId);
  }

  Future<File> _restoreJournal(int memberId) async {
    final root = await compositionStore.supportDirectory();
    return File(
      '${root.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}$memberId.yhb',
    );
  }

  Future<File> _pendingBaseline(int memberId) async {
    final root = await compositionStore.supportDirectory();
    return File(
      '${root.path}${Platform.pathSeparator}record_backup_baseline${Platform.pathSeparator}$memberId.yhb',
    );
  }

  Future<Uint8List?> _readPendingBaseline(int memberId) async {
    final file = await _pendingBaseline(memberId);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if ((await worker.decode(bytes)).memberId != memberId) {
      throw StateError('Pending backup baseline belongs to another account');
    }
    return bytes;
  }

  Future<void> _writePendingBaseline(int memberId, Uint8List bytes) async {
    if ((await worker.decode(bytes)).memberId != memberId) {
      throw StateError('Pending backup baseline belongs to another account');
    }
    final file = await _pendingBaseline(memberId);
    await file.parent.create(recursive: true);
    final adopted = File('${file.path}.adopted');
    if (await adopted.exists()) await adopted.delete();
    final pending = File('${file.path}.pending');
    await pending.writeAsBytes(bytes, flush: true);
    if (!listEquals(await pending.readAsBytes(), bytes)) {
      throw StateError('Pending backup baseline verification failed');
    }
    await pending.rename(file.path);
    if (!listEquals(await file.readAsBytes(), bytes)) {
      throw StateError('Pending backup baseline verification failed');
    }
  }

  Future<void> _restorePendingBaseline(
    int memberId,
    Uint8List? previous,
  ) async {
    if (previous != null) {
      await _writePendingBaseline(memberId, previous);
    } else {
      final file = await _pendingBaseline(memberId);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _adoptPendingBaseline(int memberId, String name) async {
    final bytes = await _readPendingBaseline(memberId);
    if (bytes == null) return;
    final existing = await port.readLive(memberId, name);
    if (existing != null &&
        (await worker.decode(existing)).memberId != memberId) {
      throw StateError('Destination contains another account backup');
    }
    await port.writeLive(memberId, name, bytes);
    final verified = await port.readLive(memberId, name);
    if (verified == null || !listEquals(verified, bytes)) {
      throw StateError('Pending backup baseline adoption failed');
    }
    final file = await _pendingBaseline(memberId);
    final adopted = File('${file.path}.adopted');
    if (await adopted.exists()) await adopted.delete();
    await file.rename(adopted.path);
    try {
      await (deleteAdoptedBaseline?.call(adopted) ?? adopted.delete());
    } catch (error) {
      // The inactive marker is never replayed. Retaining it is harmless;
      // the verified external copy is now the source of truth.
      debugPrint('Adopted backup baseline cleanup deferred: $error');
    }
  }

  Future<void> _writeRestoreJournal(BackupRestoreJournal journal) async {
    final file = await _restoreJournal(journal.archive.memberId);
    if (await file.exists()) {
      throw StateError('An unfinished restore must be recovered first');
    }
    await file.parent.create(recursive: true);
    final oldMarker = _committedMarker(file);
    if (await oldMarker.exists()) await oldMarker.delete();
    final oldPendingMarker = File('${oldMarker.path}.pending');
    if (await oldPendingMarker.exists()) await oldPendingMarker.delete();
    final oldDeletionMarker = _deletionClearMarker(file);
    if (await oldDeletionMarker.exists()) await oldDeletionMarker.delete();
    final oldDeletionPending = File('${oldDeletionMarker.path}.pending');
    if (await oldDeletionPending.exists()) await oldDeletionPending.delete();
    final pending = File('${file.path}.pending');
    final bytes = await worker.encodeJournal(journal);
    await pending.writeAsBytes(bytes, flush: true);
    if (!listEquals(await pending.readAsBytes(), bytes)) {
      throw StateError('Restore journal verification failed');
    }
    await pending.rename(file.path);
    if (!listEquals(await file.readAsBytes(), bytes)) {
      throw StateError('Restore journal verification failed');
    }
    await afterJournalWritten?.call(file);
  }

  File _committedMarker(File journal) => File('${journal.path}.committed');

  File _deletionClearMarker(File journal) =>
      File('${journal.path}.deletions-cleared');

  Future<bool> _deletionIntentCleared(File journal) async {
    final marker = _deletionClearMarker(journal);
    if (!await marker.exists()) return false;
    final checksum = sha256.convert(await journal.readAsBytes()).toString();
    if (await marker.readAsString() != checksum) {
      throw StateError('Restore deletion marker mismatch');
    }
    return true;
  }

  Future<void> _clearRestoredDeletionIntent(File journal, int memberId) async {
    if (await _deletionIntentCleared(journal)) return;
    await _forgetCompositionDeletions(memberId);
    await afterRestoreStage?.call('deletion_intent');
    final checksum = sha256.convert(await journal.readAsBytes()).toString();
    final marker = _deletionClearMarker(journal);
    final pending = File('${marker.path}.pending');
    await pending.writeAsString(checksum, flush: true);
    if (await pending.readAsString() != checksum) {
      throw StateError('Restore deletion marker verification failed');
    }
    await pending.rename(marker.path);
    if (await marker.readAsString() != checksum) {
      throw StateError('Restore deletion marker verification failed');
    }
  }

  Future<void> _markRestoreCommitted(File journal) async {
    final marker = _committedMarker(journal);
    final checksum = sha256.convert(await journal.readAsBytes()).toString();
    final pending = File('${marker.path}.pending');
    await pending.writeAsString(checksum, flush: true);
    if (await pending.readAsString() != checksum) {
      throw StateError('Restore completion marker verification failed');
    }
    await pending.rename(marker.path);
    if (await marker.readAsString() != checksum) {
      throw StateError('Restore completion marker verification failed');
    }
  }

  Future<bool> _isRestoreCommitted(File journal) async {
    final marker = _committedMarker(journal);
    if (!await marker.exists()) return false;
    final checksum = sha256.convert(await journal.readAsBytes()).toString();
    if (await marker.readAsString() != checksum) {
      throw StateError('Restore completion marker mismatch');
    }
    return true;
  }

  Future<void> _cleanCompletedRestore(File journal) async {
    try {
      await (deleteRestoreJournal?.call(journal) ?? journal.delete());
      final deletionMarker = _deletionClearMarker(journal);
      if (await deletionMarker.exists()) await deletionMarker.delete();
      final marker = _committedMarker(journal);
      if (await marker.exists()) {
        await (deleteCommittedMarker?.call(marker) ?? marker.delete());
      }
    } catch (error) {
      // A verified completion marker prevents the next startup from replaying
      // a restore over game data written after this method returns.
      debugPrint('Completed restore journal cleanup deferred: $error');
    }
  }

  static bool _sameTables(
    Map<String, List<Map<String, Object?>>> left,
    Map<String, List<Map<String, Object?>>> right,
  ) {
    for (final table in LogbookDatabase.backupTables) {
      final key = table == 'pending_construction_logs' ? 'dock_id' : 'id';
      final a = [...left[table]!]
        ..sort((x, y) => (x[key] as int).compareTo(y[key] as int));
      final b = [...right[table]!]
        ..sort((x, y) => (x[key] as int).compareTo(y[key] as int));
      if (a.length != b.length) return false;
      for (var index = 0; index < a.length; index++) {
        if (!mapEquals(a[index], b[index])) return false;
      }
    }
    return true;
  }

  static bool _sameCompositions(
    List<CompositionRecord> left,
    List<CompositionRecord> right,
  ) {
    final a = [...left]..sort((x, y) => x.id.compareTo(y.id));
    final b = [...right]..sort((x, y) => x.id.compareTo(y.id));
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (jsonEncode(a[index].toJson()) != jsonEncode(b[index].toJson())) {
        return false;
      }
    }
    return true;
  }

  Future<void> _applyRestoredArchive(BackupArchive archive) async {
    final memberId = archive.memberId;
    if (archive.senkaRaw != null && senkaStore == null) {
      throw StateError('Senka backup storage is unavailable');
    }
    final database = databaseFor(memberId);
    await database.restoreSnapshot(archive.tables);
    if (!_sameTables(await database.backupSnapshot(), archive.tables)) {
      throw StateError('Restored logbook verification failed');
    }
    await afterRestoreStage?.call('logbook');
    await compositionStore.replaceAll(
      memberId,
      archive.compositions,
      removeImages: false,
    );
    if (!_sameCompositions(
      await compositionStore.load(memberId),
      archive.compositions,
    )) {
      throw StateError('Restored composition verification failed');
    }
    await afterRestoreStage?.call('compositions');
    if (archive.senkaRaw case final raw?) {
      await senkaStore!.restoreArchiveForAccount(memberId, raw);
      if (await senkaStore!.readArchiveForAccount(memberId) != raw) {
        throw StateError('Restored senka verification failed');
      }
      await senkaController?.reloadForAccount(memberId);
      await afterRestoreStage?.call('senka');
    }
    final name = '${_name(memberId)}.yhb';
    await _writePendingBaseline(memberId, await worker.encode(archive));
    if (_hasDirectory) await _adoptPendingBaseline(memberId, name);
    await afterRestoreStage?.call('backup');
  }

  Future<void> _recoverRestoreIfNeeded(int memberId) async {
    final file = await _restoreJournal(memberId);
    if (!await file.exists()) return;
    if (await _isRestoreCommitted(file)) {
      await _clearRestoredDeletionIntent(file, memberId);
      await _cleanCompletedRestore(file);
      if (_maintenanceMemberId != memberId) {
        await senkaController?.endArchiveRestore(memberId);
      }
      return;
    }
    final journal = await worker.decodeJournal(await file.readAsBytes());
    if (journal.archive.memberId != memberId) {
      throw StateError('Restore journal belongs to another account');
    }
    if (journal.requiresExternal && !_hasDirectory) {
      throw StateError(
        'Backup folder permission is required to finish restore',
      );
    }
    if (senkaController != null &&
        !senkaController!.isArchiveRestoreActive(memberId)) {
      await senkaController!.beginArchiveRestore(memberId);
    }
    await _applyRestoredArchive(journal.archive);
    await _markRestoreCommitted(file);
    await _clearRestoredDeletionIntent(file, memberId);
    await _cleanCompletedRestore(file);
    try {
      await compositionStore.purgeImages(memberId);
    } catch (error) {
      debugPrint('Old composition image cleanup failed: $error');
    }
    _acknowledgeRestoredArchive(memberId);
    if (_maintenanceMemberId != memberId) {
      await senkaController?.endArchiveRestore(memberId);
    }
  }

  void _acknowledgeRestoredArchive(int memberId) {
    _lastErrors.remove(memberId);
    _syncFailures.remove(memberId);
    if (!_scheduledAccounts.contains(memberId)) {
      _dirtyAccounts.remove(memberId);
      _pendingCounts.remove(memberId);
    }
    _lastSyncs[memberId] = now();
    _notifyIfActive();
  }

  Future<void> _recoverAllRestoreJournals() async {
    final root = await compositionStore.supportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}record_backup_restore',
    );
    if (!await directory.exists()) return;
    final files = await directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.yhb'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.path.split(Platform.pathSeparator).last;
      final memberId = int.tryParse(name.substring(0, name.length - 4));
      if (memberId == null || memberId <= 0) {
        throw const FormatException('Invalid restore journal name');
      }
      await _recoverRestoreIfNeeded(memberId);
    }
  }

  Future<BackupArchive> _syncFor(
    int memberId, {
    _BackupSourceSnapshot? sourceSnapshot,
  }) async =>
      (await _syncPayloadFor(memberId, sourceSnapshot: sourceSnapshot)).archive;

  Future<BackupArchiveResult> _syncPayloadFor(
    int memberId, {
    _BackupSourceSnapshot? sourceSnapshot,
  }) async {
    try {
      return await _performSyncFor(memberId, sourceSnapshot: sourceSnapshot);
    } catch (error, stack) {
      _syncFailures[memberId] = (error: error, stack: stack);
      if (_enabled) {
        _dirtyAccounts.add(memberId);
        _pendingCounts[memberId] = 1;
      }
      _lastErrors[memberId] = '$error';
      _notifyIfActive();
      rethrow;
    }
  }

  Future<BackupArchiveResult> _performSyncFor(
    int memberId, {
    _BackupSourceSnapshot? sourceSnapshot,
  }) async {
    final snapshotVersion = _writeVersions[memberId] ?? 0;
    await _recoverRestoreIfNeeded(memberId);
    if (!_hasDirectory) throw StateError('Backup folder has not been selected');
    final name = _name(memberId);
    await _adoptPendingBaseline(memberId, '$name.yhb');
    final existing = await port.readLive(memberId, '$name.yhb');
    // Preserve the ownership barrier before completing persisted deletions.
    if (existing != null) await worker.validateOwner(memberId, existing);
    final offlineDeletions = await _completeOfflineDeletions(memberId);
    final currentTables = await databaseFor(memberId).backupSnapshot();
    final allRecords = await compositionStore.load(memberId);
    final currentRecords = allRecords
        .where((record) => record.snapshotJson != null)
        .toList();
    await senkaController?.idle;
    if (senkaController?.state.memberId == memberId &&
        senkaController!.hasPersistenceError) {
      throw StateError('Senka must be saved before backing up this account');
    }
    final senkaRaw = await senkaStore?.readArchiveForAccount(memberId);
    sourceSnapshot?.tables = currentTables;
    sourceSnapshot?.compositions = allRecords;
    // These are owned snapshots returned by the database/file stores. The
    // compute message copies them before control returns to the event loop.
    final writerId =
        installationId ?? await databaseFor(memberId).backupSourceId();
    final deleted = {...offlineDeletions, ...?_deletedCompositions[memberId]};
    final result = senkaRaw == null
        ? await worker.mergeAndEncode(
            memberId: memberId,
            existing: existing,
            tables: currentTables,
            compositions: currentRecords,
            writerId: writerId,
            deletedCompositions: deleted,
          )
        : await worker.mergeAndEncodeWithSenka(
            memberId: memberId,
            existing: existing,
            tables: currentTables,
            compositions: currentRecords,
            writerId: writerId,
            deletedCompositions: deleted,
            senkaRaw: senkaRaw,
          );
    final bytes = result.bytes;
    if (existing == null || !listEquals(existing, bytes)) {
      await port.writeLive(memberId, '$name.yhb', bytes);
    }
    final verified = await port.readLive(memberId, '$name.yhb');
    if (verified == null || !await worker.verify(memberId, bytes, verified)) {
      throw StateError('Backup verification failed');
    }
    _deletedCompositions.remove(memberId);
    if (offlineDeletions.isNotEmpty) {
      final removed = await (await SharedPreferences.getInstance()).remove(
        _offlineDeletionKey(memberId),
      );
      if (!removed) {
        throw StateError('Could not clear pending composition deletion');
      }
    }
    _lastErrors.remove(memberId);
    _syncFailures.remove(memberId);
    if (!_scheduledAccounts.contains(memberId) &&
        (_writeVersions[memberId] ?? 0) == snapshotVersion) {
      _dirtyAccounts.remove(memberId);
      _pendingCounts.remove(memberId);
    }
    _lastSyncs[memberId] = now();
    _notifyIfActive();
    return result;
  }

  Future<bool> chooseDirectory() async {
    await start();
    _requireEnabled();
    if (_choosingDirectory) {
      throw StateError('Backup folder picker is already open');
    }
    _choosingDirectory = true;
    _notifyIfActive();
    try {
      return await _chooseDirectoryImpl();
    } finally {
      _choosingDirectory = false;
      _notifyIfActive();
    }
  }

  Future<bool> _chooseDirectoryImpl() async {
    final memberId = session.current.memberId;
    Uint8List? prior;
    if (_hasDirectory && memberId > 0) {
      prior = await _enqueue(
        () => port.readLive(memberId, '${_name(memberId)}.yhb'),
      );
      if (prior != null && (await worker.decode(prior)).memberId != memberId) {
        throw StateError('Current backup belongs to another account');
      }
    }
    final chosen = await port.chooseDirectory();
    if (!chosen) return false;
    _hasDirectory = await port.hasDirectory();
    _notifyIfActive();
    if (_hasDirectory && memberId > 0) {
      if (prior != null) {
        final name = '${_name(memberId)}.yhb';
        final destination = await port.readLive(memberId, name);
        final imported = await worker.decode(prior);
        if (imported.memberId != memberId ||
            (destination != null &&
                (await worker.decode(destination)).memberId != memberId)) {
          throw StateError('Destination contains another account backup');
        }
        if (destination == null) {
          await port.writeLive(memberId, name, prior);
        } else if (!listEquals(destination, prior)) {
          throw StateError('Destination contains a conflicting backup');
        }
      }
      await sync();
    }
    return _hasDirectory;
  }

  Future<void> sync() async {
    await start();
    _requireEnabled();
    final memberId = session.current.memberId;
    if (memberId <= 0) throw StateError('Game account is not verified');
    await _enqueue(() => _syncFor(memberId), replacesAutomaticFor: memberId);
  }

  /// Flushes pending changes without rescanning a clean database. Lifecycle
  /// transitions (including the document picker) often arrive more than once.
  Future<void> flush() async {
    await start();
    _retryFailedBackups();
    await _drainBackupQueue();
    _throwSyncFailure();
  }

  void _retryFailedBackups() {
    if (!_enabled || !_hasDirectory) return;
    for (final memberId in _syncFailures.keys.toList()) {
      if (!_scheduledAccounts.contains(memberId)) {
        _schedule(memberId, immediate: true, changed: false);
      }
    }
  }

  void _throwSyncFailure() {
    if (!_enabled || _syncFailures.isEmpty) return;
    final failure = _syncFailures.values.first;
    Error.throwWithStackTrace(failure.error, failure.stack);
  }

  Future<void> _drainBackupQueue() async {
    while (true) {
      _flushScheduledBackups();
      final pending = _queue;
      await pending;
      // _finishPending may enqueue a final batch after a bounded automatic
      // pass completes. Observe its completion callback before declaring idle.
      await Future<void>.delayed(Duration.zero);
      if (identical(pending, _queue) && _autoSyncTimers.isEmpty) return;
    }
  }

  /// A verified backup snapshot is compared with the live database inside a
  /// single SQLite transaction before deletion. Retry if the game wrote in
  /// the interval; continuous writes eventually reject cleanup safely.
  Future<void> clearLogbookMain() async {
    await start();
    final scope = session.current;
    if (!scope.isKnown) throw StateError('Game account is not verified');
    if (!_enabled || !_hasDirectory) {
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      await databaseFor(scope.memberId).clearAll();
      return;
    }
    await _enqueue(() async {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!session.isCurrent(scope)) throw StateError('Game account changed');
        final source = _BackupSourceSnapshot();
        await _syncFor(scope.memberId, sourceSnapshot: source);
        if (!session.isCurrent(scope)) throw StateError('Game account changed');
        if (await databaseFor(
          scope.memberId,
        ).clearAllIfSnapshotMatches(source.tables!)) {
          return;
        }
      }
      throw StateError('Game data changed during cleanup; please retry');
    });
  }

  Future<int> clearCompositionMain() async {
    await start();
    final scope = session.current;
    if (!scope.isKnown) throw StateError('Game account is not verified');
    if (!_enabled || !_hasDirectory) {
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      return compositionStore.clearAll(scope.memberId);
    }
    return _enqueue(() async {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!session.isCurrent(scope)) throw StateError('Game account changed');
        final source = _BackupSourceSnapshot();
        await _syncFor(scope.memberId, sourceSnapshot: source);
        if (!session.isCurrent(scope)) throw StateError('Game account changed');
        final removed = await compositionStore.clearAllIfSnapshotMatches(
          scope.memberId,
          source.compositions!,
        );
        if (removed != null) return removed;
      }
      throw StateError(
        'Composition records changed during cleanup; please retry',
      );
    });
  }

  Future<T> _withExportScope<T>(
    Future<T> Function(AccountScope scope) operation, {
    AccountScope? expectedScope,
  }) async {
    await start();
    _requireEnabled();
    if (_exportActive) throw StateError('An export is already in progress');
    final scope = expectedScope ?? session.current;
    if (!session.isCurrent(scope)) throw StateError('Game account changed');
    if (!scope.isKnown) throw StateError('Game account is not verified');
    final memberId = scope.memberId;
    _exportActive = true;
    _notifyIfActive();
    try {
      return await operation(scope);
    } catch (error) {
      _lastErrors[memberId] = '$error';
      _notifyIfActive();
      rethrow;
    } finally {
      _exportActive = false;
      _notifyIfActive();
    }
  }

  String _exportName(int memberId) {
    final timestamp = now().toLocal().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return '${_name(memberId)}-$timestamp.yhb';
  }

  Future<String> export({AccountScope? expectedScope}) => _withExportScope((
    scope,
  ) async {
    final payload = await _enqueue(() async {
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      final result = await _syncPayloadFor(scope.memberId);
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      return (name: _exportName(scope.memberId), bytes: result.bytes);
    }, replacesAutomaticFor: scope.memberId);
    if (!session.isCurrent(scope)) throw StateError('Game account changed');
    final token = await port.prepareShareFile(payload.name, payload.bytes);
    try {
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      return await port.launchShareFile(token);
    } catch (error, stack) {
      try {
        await port.discardShareFile(token);
      } catch (discardError) {
        throw StateError('Could not remove incomplete share: $discardError');
      }
      Error.throwWithStackTrace(error, stack);
    }
  }, expectedScope: expectedScope);

  Future<bool> saveExport({AccountScope? expectedScope}) => _withExportScope((
    scope,
  ) async {
    if (!session.isCurrent(scope)) throw StateError('Game account changed');
    // Prepare before a provider can create an empty document. Once the picker
    // opens Android owns the staged bytes and can finish through backgrounding
    // or process recreation without another Dart write callback.
    final bytes = await _enqueue(() async {
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      final result = await _syncPayloadFor(scope.memberId);
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      return result.bytes;
    }, replacesAutomaticFor: scope.memberId);
    if (!session.isCurrent(scope)) throw StateError('Game account changed');
    final token = await port.saveFile(_exportName(scope.memberId), bytes);
    if (token == null) return false;
    try {
      if (!session.isCurrent(scope)) throw StateError('Game account changed');
      await port.completeSavedFile(token);
      return true;
    } catch (error, stack) {
      try {
        await port.discardSavedFile(token);
      } catch (discardError) {
        throw StateError('Could not remove incomplete export: $discardError');
      }
      Error.throwWithStackTrace(error, stack);
    }
  }, expectedScope: expectedScope);

  Future<BackupArchive?> selectImport() async {
    await start();
    _requireEnabled();
    final scope = session.current;
    if (!scope.isKnown) throw StateError('Game account is not verified');
    final bytes = await port.pickImport();
    if (bytes == null) return null;
    final archive = await worker.decode(bytes);
    if (!session.isCurrent(scope)) throw StateError('Game account changed');
    if (archive.memberId != scope.memberId) {
      throw StateError('Backup belongs to another account');
    }
    return archive;
  }

  Future<void> restore(BackupArchive archive) async {
    await start();
    _requireEnabled();
    final scope = session.current;
    archive = await worker.normalize(archive);
    if (!scope.isKnown || archive.memberId != scope.memberId) {
      throw StateError('Backup belongs to another account');
    }
    if (!session.isCurrent(scope)) throw StateError('Game account changed');
    await _beginMaintenance(scope.memberId);
    try {
      await _enqueue(() async {
        if (!session.isCurrent(scope)) throw StateError('Game account changed');
        await _recoverRestoreIfNeeded(scope.memberId);
        final database = databaseFor(scope.memberId);
        final previousTables = await database.backupSnapshot();
        final previousRecords = await compositionStore.load(scope.memberId);
        await senkaController?.idle;
        final previousSenka = await senkaStore?.readArchiveForAccount(
          scope.memberId,
        );
        final previousBaseline = await _readPendingBaseline(scope.memberId);
        final liveName = '${_name(scope.memberId)}.yhb';
        final previousLive = _hasDirectory
            ? await port.readLive(scope.memberId, liveName)
            : null;
        final adopted = BackupArchive(
          memberId: archive.memberId,
          tables: archive.tables,
          compositions: archive.compositions,
          senkaRaw: archive.senkaRaw,
          senkaSources: archive.senkaSources,
          writerId: installationId ?? await database.backupSourceId(),
          writerRowIds: archive._allWriterRowIds(),
          rowIds: {
            for (final table in LogbookDatabase.backupTables)
              if (table != 'pending_construction_logs')
                table: {
                  for (final row in archive.tables[table]!)
                    '${row['id']}': row['id'] as int,
                },
          },
        );
        if (!session.isCurrent(scope)) throw StateError('Game account changed');
        final journal = await _restoreJournal(scope.memberId);
        await _writeRestoreJournal(
          BackupRestoreJournal(
            archive: adopted,
            requiresExternal: _hasDirectory,
          ),
        );
        try {
          await _applyRestoredArchive(adopted);
          if (!session.isCurrent(scope)) {
            throw StateError('Game account changed');
          }
          await _markRestoreCommitted(journal);
        } catch (error, stack) {
          if (error is RestoreInterruptionForTesting) {
            Error.throwWithStackTrace(error, stack);
          }
          try {
            await database.restoreSnapshot(previousTables);
            await compositionStore.replaceAll(
              scope.memberId,
              previousRecords,
              allowLegacy: true,
              removeImages: false,
            );
            if (archive.senkaRaw != null && senkaStore != null) {
              await senkaStore!.restoreArchiveForAccount(
                scope.memberId,
                previousSenka,
              );
              if (await senkaStore!.readArchiveForAccount(scope.memberId) !=
                  previousSenka) {
                throw StateError('Senka rollback verification failed');
              }
              await senkaController?.reloadForAccount(scope.memberId);
            }
            if (!_sameTables(await database.backupSnapshot(), previousTables) ||
                !_sameCompositions(
                  await compositionStore.load(scope.memberId),
                  previousRecords,
                )) {
              throw StateError('Restore rollback verification failed');
            }
            if (_hasDirectory) {
              if (previousLive != null) {
                await port.writeLive(scope.memberId, liveName, previousLive);
                final restored = await port.readLive(scope.memberId, liveName);
                if (restored == null || !listEquals(restored, previousLive)) {
                  throw StateError('Backup rollback verification failed');
                }
              } else if (await port.readLive(scope.memberId, liveName) !=
                  null) {
                throw StateError('New live backup cannot be rolled back');
              }
            }
            await _restorePendingBaseline(scope.memberId, previousBaseline);
            await journal.delete();
          } catch (rollbackError) {
            debugPrint(
              'Restore rollback incomplete; journal retained: $rollbackError',
            );
          }
          Error.throwWithStackTrace(error, stack);
        }
        await _clearRestoredDeletionIntent(journal, scope.memberId);
        await _cleanCompletedRestore(journal);
        try {
          await compositionStore.purgeImages(scope.memberId);
        } catch (error) {
          debugPrint(
            'Old composition image cleanup failed after restore: $error',
          );
        }
        _acknowledgeRestoredArchive(scope.memberId);
      });
      await _endMaintenance();
    } catch (error) {
      final journal = await _restoreJournal(scope.memberId);
      var safeToResume = !await journal.exists();
      if (!safeToResume) {
        try {
          safeToResume =
              await _isRestoreCommitted(journal) &&
              await _deletionIntentCleared(journal);
        } catch (_) {
          safeToResume = false;
        }
      }
      if (safeToResume) {
        await _endMaintenance();
      } else {
        onMaintenanceBlocked?.call(error);
      }
      rethrow;
    }
  }

  Future<bool> import() async {
    final archive = await selectImport();
    if (archive == null) return false;
    await restore(archive);
    return true;
  }

  Future<void> removeCompositionRecord(int memberId, String id) async {
    await start();
    await _enqueue(() async {
      if (_maintenanceMemberId == memberId) {
        throw StateError('Restore must finish before changing compositions');
      }
      if (_enabled && _hasDirectory) {
        _deletedCompositions.putIfAbsent(memberId, () => {}).add(id);
        try {
          await _syncFor(memberId);
        } catch (_) {
          _deletedCompositions[memberId]?.remove(id);
          rethrow;
        }
      }
      try {
        if (!_enabled || !_hasDirectory) {
          await _rememberOfflineDeletion(memberId, id);
        }
        await compositionStore.delete(memberId, id);
      } catch (_) {
        if (_enabled && _hasDirectory) await _syncFor(memberId);
        rethrow;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    for (final memberId in _autoSyncTimers.keys) {
      _scheduledAccounts.remove(memberId);
      _pendingCounts.remove(memberId);
    }
    for (final timer in _autoSyncTimers.values) {
      timer.cancel();
    }
    _autoSyncTimers.clear();
    session.removeListener(_accountChanged);
    for (final entry in _observedDatabases.entries) {
      entry.value.backupWrites.removeListener(_databaseListeners[entry.key]!);
    }
    _subscriptionCancellation ??= Future.wait<void>([
      if (_compositionSubscription case final subscription?)
        subscription.cancel(),
      if (_senkaSubscription case final subscription?) subscription.cancel(),
    ]).then<void>((_) {});
    if (_subscriptionCancellation case final cancellation?) {
      unawaited(cancellation);
    }
    super.dispose();
  }

  /// Stops event sources and waits for queued file and database work to settle.
  Future<void> close() async {
    final starting = _starting;
    _closing = true;
    _retryFailedBackups();
    if (!_disposed) {
      _flushScheduledBackups();
      dispose();
    }
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        // The caller of start() owns its error; close still drains resources.
      }
    }
    try {
      await _subscriptionCancellation;
      await _drainBackupQueue();
      _throwSyncFailure();
    } finally {
      _closing = false;
    }
  }
}
