import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/backup/record_backup.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/settings/record_backup_section.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_snapshot.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

class _EnabledStore implements RecordBackupEnabledStore {
  _EnabledStore([this.value = true]);
  bool value;
  @override
  Future<bool> load() async => value;
  @override
  Future<void> save(bool enabled) async => value = enabled;
}

class _GatedEnabledStore extends _EnabledStore {
  final gate = Completer<bool>();

  @override
  Future<bool> load() => gate.future;
}

class _GatedExportWorker extends BackupArchiveWorker {
  final started = Completer<void>();
  final gate = Completer<void>();
  bool armed = false;
  bool failNext = false;

  @override
  Future<BackupArchiveResult> mergeAndEncode({
    required int memberId,
    required Uint8List? existing,
    required Map<String, List<Map<String, Object?>>> tables,
    required List<CompositionRecord> compositions,
    required String writerId,
    required Set<String> deletedCompositions,
  }) async {
    if (armed) {
      if (!started.isCompleted) started.complete();
      await gate.future;
      if (failNext) {
        failNext = false;
        throw const FormatException('Simulated export encoding failure');
      }
    }
    return super.mergeAndEncode(
      memberId: memberId,
      existing: existing,
      tables: tables,
      compositions: compositions,
      writerId: writerId,
      deletedCompositions: deletedCompositions,
    );
  }
}

class _MemoryDocumentPort implements BackupDocumentPort {
  bool directory = true;
  final Map<int, Uint8List> live = {};
  final Map<int, String> liveNames = {};
  Uint8List? importBytes;
  int writes = 0;
  bool failNextWrite = false;
  bool failNextExport = false;
  bool failNextSave = false;
  bool saveResult = true;
  String? lastExportName;
  Uint8List? lastExportBytes;
  String? pendingShareName;
  Uint8List? pendingShareBytes;
  int discardedShares = 0;
  Completer<void>? sharePrepareGate;
  Completer<void>? sharePreparePaused;
  String? lastSavedName;
  Uint8List? lastSavedBytes;
  String? pendingSavedName;
  Uint8List? pendingSavedBytes;
  int discardedSaves = 0;
  Completer<void>? savePickerGate;
  Completer<void>? savePickerPaused;
  Completer<void>? saveWriteGate;
  Completer<void>? saveWritePaused;
  Completer<void>? readGate;
  Completer<void>? readPaused;
  int reads = 0;
  int? gateAtRead;
  void Function()? onRead;
  @override
  Future<bool> hasDirectory() async => directory;
  @override
  Future<bool> chooseDirectory() async => directory;
  @override
  Future<Uint8List?> readLive(int memberId, String suggestedName) async {
    liveNames[memberId] = suggestedName;
    reads++;
    onRead?.call();
    if (reads == gateAtRead) {
      readPaused?.complete();
      await readGate?.future;
    }
    return live[memberId];
  }

  @override
  Future<void> writeLive(
    int memberId,
    String suggestedName,
    Uint8List bytes,
  ) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw const FileSystemException('simulated backup write failure');
    }
    live[memberId] = Uint8List.fromList(bytes);
    liveNames[memberId] = suggestedName;
    writes++;
  }

  @override
  Future<String> prepareShareFile(String name, Uint8List bytes) async {
    if (failNextExport) {
      failNextExport = false;
      throw const FileSystemException('simulated export failure');
    }
    pendingShareName = name;
    pendingShareBytes = Uint8List.fromList(bytes);
    sharePreparePaused?.complete();
    await sharePrepareGate?.future;
    return 'prepared-share';
  }

  @override
  Future<String> launchShareFile(String token) async {
    expect(token, 'prepared-share');
    lastExportName = pendingShareName;
    lastExportBytes = pendingShareBytes;
    pendingShareName = null;
    pendingShareBytes = null;
    return lastExportName!;
  }

  @override
  Future<void> discardShareFile(String token) async {
    expect(token, 'prepared-share');
    discardedShares++;
    pendingShareName = null;
    pendingShareBytes = null;
  }

  @override
  Future<String?> saveFile(String name, Uint8List bytes) async {
    savePickerPaused?.complete();
    await savePickerGate?.future;
    if (!saveResult) return null;
    pendingSavedName = name;
    if (failNextSave) {
      failNextSave = false;
      pendingSavedName = null;
      discardedSaves++;
      throw const FileSystemException('simulated local save failure');
    }
    pendingSavedBytes = Uint8List.fromList(bytes);
    saveWritePaused?.complete();
    await saveWriteGate?.future;
    return 'selected-location';
  }

  @override
  Future<void> completeSavedFile(String token) async {
    expect(token, 'selected-location');
    lastSavedName = pendingSavedName;
    lastSavedBytes = pendingSavedBytes;
    pendingSavedName = null;
    pendingSavedBytes = null;
  }

  @override
  Future<void> discardSavedFile(String token) async {
    expect(token, 'selected-location');
    discardedSaves++;
    pendingSavedName = null;
    pendingSavedBytes = null;
  }

  @override
  Future<Uint8List?> pickImport() async => importBytes;
}

class _MigratingDocumentPort implements BackupDocumentPort {
  bool newFolder = false;
  final Map<int, Uint8List> oldLive = {};
  final Map<int, Uint8List> newLive = {};
  Map<int, Uint8List> get live => newFolder ? newLive : oldLive;

  @override
  Future<bool> hasDirectory() async => true;
  @override
  Future<bool> chooseDirectory() async {
    newLive.addAll(
      oldLive.map((key, value) => MapEntry(key, Uint8List.fromList(value))),
    );
    newFolder = true;
    return true;
  }

  @override
  Future<Uint8List?> readLive(int memberId, String suggestedName) async =>
      live[memberId];
  @override
  Future<void> writeLive(
    int memberId,
    String suggestedName,
    Uint8List bytes,
  ) async {
    live[memberId] = Uint8List.fromList(bytes);
  }

  @override
  Future<String> prepareShareFile(String name, Uint8List bytes) async =>
      'prepared-share';
  @override
  Future<String> launchShareFile(String token) async => 'share.yhb';
  @override
  Future<void> discardShareFile(String token) async {}
  @override
  Future<String?> saveFile(String name, Uint8List bytes) async => null;
  @override
  Future<void> completeSavedFile(String token) async {}
  @override
  Future<void> discardSavedFile(String token) async {}
  @override
  Future<Uint8List?> pickImport() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('import decoding yields the event loop before completing', () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('yahagi-worker-import-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: 1001);
    final port = _ImportHeartbeatPort()..directory = false;
    final tables = {
      for (final table in LogbookDatabase.backupTables)
        table: <Map<String, Object?>>[],
    };
    tables['resource_logs'] = [
      for (var i = 1; i <= 50000; i++) {'id': i, 'fuel': i * 7},
    ];
    port.importBytes = BackupArchive(
      memberId: 1001,
      tables: tables,
      compositions: [],
    ).encode();
    final service = RecordBackupService(
      session: session,
      port: port,
      enabledStore: _EnabledStore(),
      databaseFor: (_) => db,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
    );
    addTearDown(() async {
      await service.close();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.start();
    final archive = await service.selectImport();
    expect(archive!.tables['resource_logs'], hasLength(50000));
    expect(
      port.heartbeatFired,
      isTrue,
      reason:
          'JSON/gzip/checksum decoding must leave the UI event loop available',
    );
  });
  test(
    'slow worker keeps account ownership and serializes pending syncs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp(
        'yahagi-worker-queue-',
      );
      final a = await LogbookDatabase.openForTesting();
      final b = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: 1001);
      final port = _MemoryDocumentPort();
      final worker = _GatedMergeWorker();
      final service = RecordBackupService(
        session: session,
        port: port,
        worker: worker,
        enabledStore: _EnabledStore(),
        databaseFor: (id) => id == 1001 ? a : b,
        installationId: 'test',
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
      );
      addTearDown(() async {
        if (!worker.release.isCompleted) worker.release.complete();
        await service.close();
        session.dispose();
        await a.close();
        await b.close();
        await root.delete(recursive: true);
      });
      await service.start();
      await worker.started.future;
      session.reset();
      session.selectMember(2002);
      var finished = false;
      final syncing = service.sync().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      expect(port.live, isEmpty);
      worker.release.complete();
      await syncing;
      expect(worker.peakActive, 1);
      expect(BackupArchive.decode(port.live[1001]!).memberId, 1001);
      expect(BackupArchive.decode(port.live[2002]!).memberId, 2002);
    },
  );

  test(
    'same member in a new generation rejects an import during worker await',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'yahagi-worker-scope-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: 1001);
      final worker = _GatedDecodeWorker();
      final port = _MemoryDocumentPort()..directory = false;
      port.importBytes = BackupArchive(
        memberId: 1001,
        tables: {for (final table in LogbookDatabase.backupTables) table: []},
        compositions: [],
      ).encode();
      final service = RecordBackupService(
        session: session,
        port: port,
        worker: worker,
        enabledStore: _EnabledStore(),
        databaseFor: (_) => db,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
      );
      addTearDown(() async {
        if (!worker.release.isCompleted) worker.release.complete();
        await service.close();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.start();
      final selecting = service.selectImport();
      final rejected = expectLater(selecting, throwsStateError);
      await worker.started.future;
      session.reset();
      session.selectMember(1001);
      worker.release.complete();
      await rejected;
    },
  );
  test(
    'close waits for an in-flight start without attaching listeners',
    () async {
      final enabledStore = _GatedEnabledStore();
      final session = AccountSession(initialMemberId: 903227);
      addTearDown(session.dispose);
      var databaseLookups = 0;
      final service = RecordBackupService(
        enabledStore: enabledStore,
        session: session,
        port: _MemoryDocumentPort(),
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => Directory.systemTemp,
        ),
        databaseFor: (_) {
          databaseLookups++;
          throw StateError('Disposed startup must not attach a database');
        },
      );

      final starting = service.start();
      final closing = service.close();
      var closed = false;
      closing.then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);

      enabledStore.gate.complete(true);
      await starting;
      await closing;
      expect(databaseLookups, 0);
      await expectLater(service.start(), throwsStateError);
    },
  );

  test(
    'backup preference defaults off and survives store recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesRecordBackupEnabledStore();
      expect(await store.load(), isFalse);
      await store.save(true);
      expect(
        await const SharedPreferencesRecordBackupEnabledStore().load(),
        isTrue,
      );
      await store.save(false);
      expect(await store.load(), isFalse);
    },
  );

  test(
    'disabled backup blocks actions and does not write during cleanup',
    () async {
      const owner = 914001;
      final root = await Directory.systemTemp.createTemp('yahagi-disabled-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final setting = _EnabledStore(false);
      final service = RecordBackupService(
        enabledStore: setting,
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'disabled-test',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.start();
      expect(service.enabled, isFalse);
      expect(port.writes, 0);
      await expectLater(service.chooseDirectory(), throwsStateError);
      await expectLater(service.sync(), throwsStateError);
      await expectLater(service.export(), throwsStateError);
      await expectLater(service.saveExport(), throwsStateError);
      await expectLater(service.selectImport(), throwsStateError);
      await service.clearLogbookMain();
      expect(port.writes, 0);
      await service.setEnabled(true);
      await service.sync();
      expect(port.writes, greaterThan(0));
      final writes = port.writes;
      await service.setEnabled(false);
      await service.clearLogbookMain();
      expect(port.writes, writes);
      expect(setting.value, isFalse);
    },
  );

  test('export shares the just-synchronized verified archive', () async {
    const owner = 914003;
    final root = await Directory.systemTemp.createTemp('yahagi-share-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'share-test',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    final name = await service.export();
    expect(name, port.lastExportName);
    expect(name, endsWith('.yhb'));
    expect(port.lastExportBytes, port.live[owner]);
    expect(BackupArchive.decode(port.lastExportBytes!).memberId, owner);
  });

  test(
    'local save uses verified export bytes and cancellation creates no copy',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 914009;
      final root = await Directory.systemTemp.createTemp('yahagi-save-export-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'save-export-test',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      port.saveResult = false;
      expect(await service.saveExport(), isFalse);
      expect(port.lastSavedName, isNull);
      port.saveResult = true;
      expect(await service.saveExport(), isTrue);
      expect(port.lastSavedName, endsWith('.yhb'));
      expect(port.lastSavedBytes, port.live[owner]);
      expect(BackupArchive.decode(port.lastSavedBytes!).memberId, owner);
      expect(port.lastExportName, isNull);
    },
  );

  test('queued export never shares a previous account after switch', () async {
    const accountA = 914005;
    const accountB = 914006;
    final root = await Directory.systemTemp.createTemp('yahagi-export-scope-');
    final dbA = await LogbookDatabase.openForTesting();
    final dbB = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: accountA);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (id) => id == accountA ? dbA : dbB,
      installationId: 'export-scope-test',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await dbA.close();
      await dbB.close();
      await root.delete(recursive: true);
    });
    await service.sync();
    port.readPaused = Completer<void>();
    port.readGate = Completer<void>();
    port.gateAtRead = port.reads + 1;
    final export = service.export();
    await port.readPaused!.future;
    session.selectMember(accountB);
    port.readGate!.complete();
    await expectLater(export, throwsStateError);
    expect(port.lastExportName, isNull);
  });

  test(
    'account switch during share preparation discards the temporary file',
    () async {
      SharedPreferences.setMockInitialValues({});
      const accountA = 914016;
      const accountB = 914017;
      final root = await Directory.systemTemp.createTemp('yahagi-share-scope-');
      final dbA = await LogbookDatabase.openForTesting();
      final dbB = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: accountA);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (id) => id == accountA ? dbA : dbB,
        installationId: 'share-scope-test',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await dbA.close();
        await dbB.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      port.sharePreparePaused = Completer<void>();
      port.sharePrepareGate = Completer<void>();
      final sharing = service.export();
      await port.sharePreparePaused!.future;
      session.selectMember(accountB);
      port.sharePrepareGate!.complete();
      await expectLater(sharing, throwsStateError);
      expect(port.discardedShares, 1);
      expect(port.lastExportName, isNull);
      expect(port.pendingShareBytes, isNull);
    },
  );

  test('export menu keeps the account selected when the menu opened', () async {
    SharedPreferences.setMockInitialValues({});
    const accountA = 914018;
    const accountB = 914019;
    final root = await Directory.systemTemp.createTemp(
      'yahagi-export-menu-scope-',
    );
    final dbA = await LogbookDatabase.openForTesting();
    final dbB = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: accountA);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (id) => id == accountA ? dbA : dbB,
      installationId: 'export-menu-scope-test',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await dbA.close();
      await dbB.close();
      await root.delete(recursive: true);
    });
    await service.start();
    final openedFor = session.current;
    session.selectMember(accountB);
    await expectLater(
      service.export(expectedScope: openedFor),
      throwsStateError,
    );
    await expectLater(
      service.saveExport(expectedScope: openedFor),
      throwsStateError,
    );
    expect(port.lastExportName, isNull);
    expect(port.lastSavedName, isNull);
  });

  test(
    'account switch during local picker discards the selected file',
    () async {
      SharedPreferences.setMockInitialValues({});
      const accountA = 914011;
      const accountB = 914012;
      final root = await Directory.systemTemp.createTemp('yahagi-save-scope-');
      final dbA = await LogbookDatabase.openForTesting();
      final dbB = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: accountA);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (id) => id == accountA ? dbA : dbB,
        installationId: 'save-scope-test',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await dbA.close();
        await dbB.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      port.savePickerPaused = Completer<void>();
      port.savePickerGate = Completer<void>();
      final saving = service.saveExport();
      await port.savePickerPaused!.future;
      session.selectMember(accountB);
      port.savePickerGate!.complete();
      await expectLater(saving, throwsStateError);
      expect(port.discardedSaves, 1);
      expect(port.lastSavedName, isNull);
      expect(port.pendingSavedBytes, isNull);
    },
  );

  test('automatic backup can run while local save picker is open', () async {
    SharedPreferences.setMockInitialValues({});
    const owner = 914013;
    final root = await Directory.systemTemp.createTemp('yahagi-save-queue-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'save-queue-test',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.sync();
    port.savePickerPaused = Completer<void>();
    port.savePickerGate = Completer<void>();
    final saving = service.saveExport();
    await port.savePickerPaused!.future;
    await db.insertRetirementRecord(
      timestamp: 1,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'during picker',
      level: 1,
    );
    await service.sync().timeout(const Duration(seconds: 3));
    expect(
      BackupArchive.decode(port.live[owner]!).tables['retirement_logs'],
      hasLength(1),
    );
    port.savePickerGate!.complete();
    expect(await saving, isTrue);
    expect(
      BackupArchive.decode(port.lastSavedBytes!).tables['retirement_logs'],
      isEmpty,
    );
  });

  test(
    'local export prepares all bytes before creating a destination',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 914020;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-save-prepare-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort()..savePickerPaused = Completer<void>();
      final encoder = _GatedExportWorker();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        worker: encoder,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'save-prepare-test',
      );
      addTearDown(() async {
        await service.close();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      encoder.armed = true;
      final saving = service.saveExport();
      await Future.any([encoder.started.future, port.savePickerPaused!.future]);
      final openedBeforeDataWasReady = port.savePickerPaused!.isCompleted;
      encoder.gate.complete();
      expect(await saving, isTrue);
      expect(
        openedBeforeDataWasReady,
        isFalse,
        reason:
            'The provider must not create an empty document while encoding.',
      );
      expect(BackupArchive.decode(port.lastSavedBytes!).memberId, owner);
    },
  );

  test(
    'failed export preparation creates no document and allows retry',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 914021;
      final root = await Directory.systemTemp.createTemp('yahagi-save-retry-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort()..savePickerPaused = Completer<void>();
      final encoder = _GatedExportWorker()..failNext = true;
      encoder.gate.complete();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        worker: encoder,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'save-retry-test',
      );
      addTearDown(() async {
        await service.close();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      encoder.armed = true;
      await expectLater(service.saveExport(), throwsFormatException);
      expect(port.savePickerPaused!.isCompleted, isFalse);
      expect(port.discardedSaves, 0);
      expect(service.busy, isFalse);
      expect(await db.backupSnapshot(), isNotEmpty);
      expect(await service.saveExport(), isTrue);
      expect(service.busy, isFalse);
      expect(BackupArchive.decode(port.lastSavedBytes!).memberId, owner);
    },
  );

  test(
    'Android local export hands complete bytes to one native operation',
    () async {
      const channel = MethodChannel('test/prepared-backup-export');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'saveFile' ? 'native-verified-export' : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final port = AndroidBackupDocumentPort(channel: channel);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final token = await port.saveFile('prepared.yhb', bytes);
      await port.completeSavedFile(token!);
      expect(calls.map((call) => call.method), [
        'saveFile',
        'completeSavedFile',
      ]);
      expect(calls.first.arguments, {'name': 'prepared.yhb', 'bytes': bytes});
    },
  );

  test('account switch during local write discards the written file', () async {
    SharedPreferences.setMockInitialValues({});
    const accountA = 914014;
    const accountB = 914015;
    final root = await Directory.systemTemp.createTemp(
      'yahagi-save-write-scope-',
    );
    final dbA = await LogbookDatabase.openForTesting();
    final dbB = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: accountA);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (id) => id == accountA ? dbA : dbB,
      installationId: 'save-write-scope-test',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await dbA.close();
      await dbB.close();
      await root.delete(recursive: true);
    });
    port.saveWritePaused = Completer<void>();
    port.saveWriteGate = Completer<void>();
    final saving = service.saveExport();
    await port.saveWritePaused!.future;
    session.selectMember(accountB);
    port.saveWriteGate!.complete();
    await expectLater(saving, throwsStateError);
    expect(port.discardedSaves, 1);
    expect(port.lastSavedBytes, isNull);
    expect(port.pendingSavedBytes, isNull);
  });

  testWidgets('master switch greys out four actions and restores them', (
    tester,
  ) async {
    const owner = 914002;
    late Directory root;
    late LogbookDatabase db;
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort()..directory = false;
    late RecordBackupService service;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('yahagi-switch-ui-');
      db = await LogbookDatabase.openForTesting();
      service = RecordBackupService(
        enabledStore: _EnabledStore(false),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'switch-test',
      );
      await service.start();
      await service.setEnabled(false);
    });
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: SingleChildScrollView(
              child: RecordBackupSection(service: service),
            ),
          ),
        ),
      ),
    );
    expect(find.text('保存在本机文档文件夹；自动同步在后台进行'), findsOneWidget);
    expect(find.text('导入备份文件恢复游戏记录'), findsOneWidget);
    const keys = [
      'settings-backup-folder',
      'settings-backup-sync',
      'settings-backup-export',
      'settings-backup-import',
    ];
    for (final key in keys) {
      expect(tester.widget<InkWell>(find.byKey(Key(key))).onTap, isNull);
    }
    await tester.tap(find.byKey(const Key('settings-backup-enabled')));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && !service.enabled; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(service.enabled, isTrue);
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('settings-backup-folder')))
          .onTap,
      isNotNull,
    );
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('settings-backup-import')))
          .onTap,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('settings-backup-enabled')));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && service.enabled; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(service.enabled, isFalse);
    for (final key in keys) {
      expect(tester.widget<InkWell>(find.byKey(Key(key))).onTap, isNull);
    }
  });

  testWidgets('export menu offers local save, app sharing, and cancel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const owner = 914010;
    late Directory root;
    late LogbookDatabase db;
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    late RecordBackupService service;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('yahagi-export-menu-');
      db = await LogbookDatabase.openForTesting();
      service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'export-menu-test',
      );
      await service.sync();
    });
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopNoticeHost(
          child: Scaffold(
            body: SingleChildScrollView(
              child: RecordBackupSection(service: service),
            ),
          ),
        ),
      ),
    );
    final export = find.byKey(const Key('settings-backup-export'));
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.text('保存到本机'), findsOneWidget);
    expect(find.text('分享给其他应用'), findsOneWidget);
    expect(
      find.byKey(const Key('settings-backup-export-cancel')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settings-backup-export-cancel')));
    await tester.pumpAndSettle();
    expect(port.lastSavedName, isNull);
    expect(port.lastExportName, isNull);

    await tester.tap(export);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-backup-save-device')));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 50 && port.lastSavedName == null;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
    }
    expect(service.lastError, isNull);
    expect(port.lastSavedName, isNotNull);
    expect(port.lastExportName, isNull);

    await tester.tap(export);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-backup-share-apps')));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 50 && port.lastExportName == null;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
    }
    expect(port.lastExportName, isNotNull);
  });
  test(
    'frozen v12 archive survives independent SQLite schema changes',
    () async {
      final bytes = await File(
        'test/fixtures/record_backup_v12_empty.yhb',
      ).readAsBytes();
      final archive = BackupArchive.decode(bytes);
      expect(archive.memberId, 812345);
      expect(archive.writerId, 'fixture-writer');
      expect(archive.tables.keys.toSet(), LogbookDatabase.backupTables.toSet());
      expect(BackupArchive.logbookArchiveSchema, 12);
    },
  );
  test('Android live recovery validates pending before older copies', () async {
    const owner = 88001;
    const channel = MethodChannel('test/backup-candidates');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final archive = BackupArchive(
      memberId: owner,
      tables: {for (final table in LogbookDatabase.backupTables) table: []},
      compositions: const [],
    ).encode();
    final wrongAccount = BackupArchive(
      memberId: owner + 1,
      tables: {for (final table in LogbookDatabase.backupTables) table: []},
      compositions: const [],
    ).encode();
    final slots = <String, Uint8List?>{
      'pending': archive,
      'main': archive,
      'previous': archive,
    };
    final calls = <String>[];
    String? unreadableSlot;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      final slot = args['slot'] as String;
      calls.add('${call.method}:$slot');
      if (call.method == 'readCandidate') {
        if (slot == unreadableSlot) {
          throw PlatformException(code: 'read_failed');
        }
        return slots[slot];
      }
      if (call.method == 'promoteCandidate') {
        slots['main'] = slots[slot];
        slots[slot] = null;
        return null;
      }
      throw StateError('Unexpected method ${call.method}');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final port = AndroidBackupDocumentPort(
      channel: channel,
      validateCandidate: (_) async {},
    );
    expect(await port.readLive(owner, 'Admiral-Server.yhb'), archive);
    expect(calls, [
      'readCandidate:pending',
      'readCandidate:main',
      'readCandidate:previous',
      'promoteCandidate:pending',
      'readCandidate:main',
    ]);
    calls.clear();
    slots['pending'] = Uint8List.fromList([1, 2, 3]);
    slots['main'] = archive;
    expect(await port.readLive(owner, 'Admiral-Server.yhb'), archive);
    expect(calls, [
      'readCandidate:pending',
      'readCandidate:main',
      'readCandidate:previous',
    ]);
    calls.clear();
    slots['main'] = Uint8List.fromList([4, 5, 6]);
    expect(await port.readLive(owner, 'Admiral-Server.yhb'), archive);
    expect(calls, [
      'readCandidate:pending',
      'readCandidate:main',
      'readCandidate:previous',
      'promoteCandidate:previous',
      'readCandidate:main',
    ]);
    for (final foreignSlot in ['pending', 'main', 'previous']) {
      calls.clear();
      slots
        ..['pending'] = archive
        ..['main'] = archive
        ..['previous'] = archive
        ..[foreignSlot] = wrongAccount;
      await expectLater(
        port.readLive(owner, 'Admiral-Server.yhb'),
        throwsA(isA<StateError>()),
      );
      expect(
        calls.where((call) => call.startsWith('promoteCandidate')),
        isEmpty,
      );
      expect(slots[foreignSlot], wrongAccount);
    }
    calls.clear();
    slots
      ..['pending'] = archive
      ..['main'] = archive
      ..['previous'] = archive;
    unreadableSlot = 'pending';
    await expectLater(
      port.readLive(owner, 'Admiral-Server.yhb'),
      throwsA(isA<StateError>()),
    );
    expect(calls, ['readCandidate:pending']);
  });

  test(
    'legacy battle node label survives backup validation and restore',
    () async {
      final db = await LogbookDatabase.openForTesting();
      addTearDown(db.close);
      await (await db.database).insert('battle_logs', {
        'timestamp': 1,
        'map_area': 1,
        'map_no': 1,
        'node': 1,
        'node_type': '普通战斗',
        'rank': 'S',
        'enemy_fleet_name': '',
        'friend_fleet_state': '',
        'enemy_fleet_state': '',
      });
      final tables = await db.backupSnapshot();
      expect(tables['battle_logs']!.single['node_type'], '普通战斗');
      await db.validateBackupSnapshot(tables);
      await db.restoreSnapshot(tables);
      expect(
        (await db.backupSnapshot())['battle_logs']!.single['node_type'],
        '普通战斗',
      );

      final malformed = {
        for (final entry in tables.entries)
          entry.key: entry.key == 'battle_logs'
              ? [
                  <String, Object?>{...entry.value.single, 'node_type': 1.5},
                ]
              : entry.value,
      };
      await expectLater(
        db.validateBackupSnapshot(malformed),
        throwsA(isA<FormatException>()),
      );
      for (final numericLabel in [
        '1',
        ' 1 ',
        '1.0',
        '1e2',
        '+1',
        '-1',
        '.1',
        '1.',
        '0001',
        '1e999',
      ]) {
        final numericString = {
          for (final entry in tables.entries)
            entry.key: entry.key == 'battle_logs'
                ? [
                    <String, Object?>{
                      ...entry.value.single,
                      'node_type': numericLabel,
                    },
                  ]
                : entry.value,
        };
        await expectLater(
          db.restoreSnapshot(numericString),
          throwsA(isA<FormatException>()),
          reason: numericLabel,
        );
      }
      expect(
        (await db.backupSnapshot())['battle_logs']!.single['node_type'],
        '普通战斗',
      );
    },
  );

  test(
    'numeric-string pending battle label cannot replace healthy main',
    () async {
      const owner = 88004;
      const channel = MethodChannel('test/backup-numeric-battle-candidate');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final db = await LogbookDatabase.openForTesting();
      addTearDown(db.close);
      await (await db.database).insert('battle_logs', {
        'timestamp': 1,
        'map_area': 1,
        'map_no': 1,
        'node': 1,
        'node_type': '普通战斗',
        'rank': 'S',
        'enemy_fleet_name': '',
        'friend_fleet_state': '',
        'enemy_fleet_state': '',
      });
      final healthyTables = await db.backupSnapshot();
      final numericTables = {
        for (final entry in healthyTables.entries)
          entry.key: entry.key == 'battle_logs'
              ? [
                  <String, Object?>{...entry.value.single, 'node_type': '1'},
                ]
              : entry.value,
      };
      Uint8List archive(Map<String, List<Map<String, Object?>>> tables) =>
          BackupArchive(
            memberId: owner,
            tables: tables,
            compositions: const [],
          ).encode();
      final main = archive(healthyTables);
      final pending = archive(numericTables);
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final slot = (call.arguments as Map)['slot'] as String;
        calls.add('${call.method}:$slot');
        if (call.method == 'readCandidate') {
          return switch (slot) {
            'pending' => pending,
            'main' => main,
            _ => null,
          };
        }
        throw StateError('Numeric-string pending candidate was promoted');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final port = AndroidBackupDocumentPort(
        channel: channel,
        validateCandidate: (candidate) =>
            db.validateBackupSnapshot(candidate.tables),
      );
      expect(await port.readLive(owner, 'Admiral-Server.yhb'), main);
      expect(calls, [
        'readCandidate:pending',
        'readCandidate:main',
        'readCandidate:previous',
      ]);
    },
  );

  test('missing nullable battle column cannot replace healthy main', () async {
    const owner = 88005;
    const channel = MethodChannel('test/backup-missing-nullable-candidate');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final db = await LogbookDatabase.openForTesting();
    addTearDown(db.close);
    await (await db.database).insert('battle_logs', {
      'timestamp': 1,
      'map_area': 1,
      'map_no': 1,
      'node': 1,
      'node_type': '普通战斗',
      'rank': 'S',
      'enemy_fleet_name': '',
      'friend_fleet_state': '',
      'enemy_fleet_state': '',
      'detail_json': '{"kept":true}',
    });
    final healthyTables = await db.backupSnapshot();
    final incompleteTables = {
      for (final entry in healthyTables.entries)
        entry.key: entry.key == 'battle_logs'
            ? [
                <String, Object?>{...entry.value.single}..remove('detail_json'),
              ]
            : entry.value,
    };
    Uint8List archive(Map<String, List<Map<String, Object?>>> tables) =>
        BackupArchive(
          memberId: owner,
          tables: tables,
          compositions: const [],
        ).encode();
    final main = archive(healthyTables);
    final pending = archive(incompleteTables);
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final slot = (call.arguments as Map)['slot'] as String;
      calls.add('${call.method}:$slot');
      if (call.method == 'readCandidate') {
        return switch (slot) {
          'pending' => pending,
          'main' => main,
          _ => null,
        };
      }
      throw StateError('Incomplete pending candidate was promoted');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final port = AndroidBackupDocumentPort(
      channel: channel,
      validateCandidate: (candidate) =>
          db.validateBackupSnapshot(candidate.tables),
    );
    expect(await port.readLive(owner, 'Admiral-Server.yhb'), main);
    expect(calls, [
      'readCandidate:pending',
      'readCandidate:main',
      'readCandidate:previous',
    ]);
  });

  test(
    'restore rejects missing nullable battle column before writes',
    () async {
      final db = await LogbookDatabase.openForTesting();
      addTearDown(db.close);
      await (await db.database).insert('battle_logs', {
        'timestamp': 1,
        'map_area': 1,
        'map_no': 1,
        'node': 1,
        'node_type': '普通战斗',
        'rank': 'S',
        'enemy_fleet_name': '',
        'friend_fleet_state': '',
        'enemy_fleet_state': '',
        'detail_json': '{"kept":true}',
      });
      final tables = await db.backupSnapshot();
      final incompleteTables = {
        for (final entry in tables.entries)
          entry.key: entry.key == 'battle_logs'
              ? [
                  <String, Object?>{...entry.value.single}
                    ..remove('detail_json'),
                ]
              : entry.value,
      };
      await expectLater(
        db.restoreSnapshot(incompleteTables),
        throwsA(isA<FormatException>()),
      );
      expect(
        (await db.backupSnapshot())['battle_logs']!.single['detail_json'],
        '{"kept":true}',
      );
    },
  );

  test('out-of-range timestamp pending cannot replace healthy main', () async {
    const owner = 88006;
    const channel = MethodChannel('test/backup-timestamp-candidate');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final db = await LogbookDatabase.openForTesting();
    addTearDown(db.close);
    await (await db.database).insert('resource_logs', {
      'timestamp': 1,
      'fuel': 1,
      'ammo': 1,
      'steel': 1,
      'bauxite': 1,
      'bucket': 1,
      'blowtorch': 1,
      'devmat': 1,
      'screw': 1,
    });
    final healthyTables = await db.backupSnapshot();
    const firstUnsafeJstTimestamp = 8640000000000000 - 9 * 60 * 60 * 1000 + 1;
    final invalidTables = {
      for (final entry in healthyTables.entries)
        entry.key: entry.key == 'resource_logs'
            ? [
                <String, Object?>{
                  ...entry.value.single,
                  'timestamp': firstUnsafeJstTimestamp,
                },
              ]
            : entry.value,
    };
    Uint8List archive(Map<String, List<Map<String, Object?>>> tables) =>
        BackupArchive(
          memberId: owner,
          tables: tables,
          compositions: const [],
        ).encode();
    final main = archive(healthyTables);
    final pending = archive(invalidTables);
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final slot = (call.arguments as Map)['slot'] as String;
      calls.add('${call.method}:$slot');
      if (call.method == 'readCandidate') {
        return switch (slot) {
          'pending' => pending,
          'main' => main,
          _ => null,
        };
      }
      throw StateError('Out-of-range pending candidate was promoted');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final port = AndroidBackupDocumentPort(
      channel: channel,
      validateCandidate: (candidate) =>
          db.validateBackupSnapshot(candidate.tables),
    );
    expect(await port.readLive(owner, 'Admiral-Server.yhb'), main);
    expect(calls, [
      'readCandidate:pending',
      'readCandidate:main',
      'readCandidate:previous',
    ]);
  });

  test('restore rejects exhausted autoincrement IDs and keeps main', () async {
    final db = await LogbookDatabase.openForTesting();
    addTearDown(db.close);
    await (await db.database).insert('resource_logs', {
      'timestamp': 1,
      'fuel': 1,
      'ammo': 1,
      'steel': 1,
      'bauxite': 1,
      'bucket': 1,
      'blowtorch': 1,
      'devmat': 1,
      'screw': 1,
    });
    final tables = await db.backupSnapshot();
    final exhausted = {
      for (final entry in tables.entries)
        entry.key: entry.key == 'resource_logs'
            ? [
                <String, Object?>{
                  ...entry.value.single,
                  'id': 9223372036854775807,
                },
              ]
            : entry.value,
    };
    await expectLater(
      db.restoreSnapshot(exhausted),
      throwsA(isA<FormatException>()),
    );
    expect((await db.backupSnapshot())['resource_logs']!.single['id'], 1);
  });

  test(
    'wrong SQLite column type in pending cannot replace healthy main',
    () async {
      const owner = 88002;
      const channel = MethodChannel('test/backup-semantic-candidates');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final db = await LogbookDatabase.openForTesting();
      addTearDown(db.close);
      final valid = BackupArchive(
        memberId: owner,
        tables: {for (final table in LogbookDatabase.backupTables) table: []},
        compositions: const [],
      ).encode();
      final invalid = BackupArchive(
        memberId: owner,
        tables: {
          for (final table in LogbookDatabase.backupTables)
            table: table == 'resource_logs'
                ? [
                    <String, Object?>{'id': 1, 'timestamp': 'bad'},
                  ]
                : <Map<String, Object?>>[],
        },
        compositions: const [],
      ).encode();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final slot = (call.arguments as Map)['slot'] as String;
        calls.add('${call.method}:$slot');
        if (call.method == 'readCandidate') {
          return switch (slot) {
            'pending' => invalid,
            'main' => valid,
            _ => null,
          };
        }
        throw StateError('Invalid pending candidate was promoted');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final port = AndroidBackupDocumentPort(
        channel: channel,
        validateCandidate: (archive) =>
            db.validateBackupSnapshot(archive.tables),
      );
      expect(await port.readLive(owner, 'Admiral-Server.yhb'), valid);
      expect(calls, [
        'readCandidate:pending',
        'readCandidate:main',
        'readCandidate:previous',
      ]);
    },
  );

  test(
    'duplicate unique event keys in pending cannot replace healthy main',
    () async {
      const owner = 88003;
      const channel = MethodChannel('test/backup-unique-candidates');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final db = await LogbookDatabase.openForTesting();
      addTearDown(db.close);
      final empty = BackupArchive(
        memberId: owner,
        tables: {for (final table in LogbookDatabase.backupTables) table: []},
        compositions: const [],
      ).encode();
      await db.insertMapResourceRecord(
        MapResourceLogEntry(
          eventKey: 'same-event',
          timestamp: DateTime.utc(2026),
          mapArea: 1,
          mapNo: 1,
          mapName: 'map',
          node: 1,
        ),
      );
      final tables = await db.backupSnapshot();
      final original = tables['map_resource_logs']!.single;
      tables['map_resource_logs'] = [
        original,
        {...original, 'id': (original['id'] as int) + 1},
      ];
      final duplicate = BackupArchive(
        memberId: owner,
        tables: tables,
        compositions: const [],
      ).encode();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final slot = (call.arguments as Map)['slot'] as String;
        calls.add('${call.method}:$slot');
        if (call.method == 'readCandidate') {
          return switch (slot) {
            'pending' => duplicate,
            'main' => empty,
            _ => null,
          };
        }
        throw StateError('Duplicate event candidate was promoted');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final port = AndroidBackupDocumentPort(
        channel: channel,
        validateCandidate: (archive) =>
            db.validateBackupSnapshot(archive.tables),
      );
      expect(await port.readLive(owner, 'Admiral-Server.yhb'), empty);
      expect(
        calls.where((call) => call.startsWith('promoteCandidate')),
        isEmpty,
      );
    },
  );

  test('pending construction dock primary key must be unique', () async {
    final db = await LogbookDatabase.openForTesting();
    addTearDown(db.close);
    await db.insertConstructionStartRecord(
      dockId: 1,
      timestamp: 1,
      constructionType: '建造',
      shipId: null,
      shipName: '建造中',
      shipType: '',
      fuel: 30,
      ammo: 30,
      steel: 30,
      bauxite: 30,
      developmentMaterial: 1,
      secretaryName: '',
    );
    final tables = await db.backupSnapshot();
    final pending = tables['pending_construction_logs']!.single;
    tables['pending_construction_logs'] = [
      pending,
      {...pending},
    ];
    await expectLater(
      db.validateBackupSnapshot(tables),
      throwsA(isA<FormatException>()),
    );
  });

  test('new installation row IDs cannot overwrite old backup rows', () {
    Map<String, List<Map<String, Object?>>> rows(String ship) => {
      for (final table in LogbookDatabase.backupTables)
        table: table == 'retirement_logs'
            ? [
                <String, Object?>{'id': 1, 'ship_name': ship},
              ]
            : <Map<String, Object?>>[],
    };
    final first = BackupArchive(
      memberId: 7,
      tables: rows('old ship'),
      compositions: const [],
      writerId: 'old-installation',
    );
    final merged = first.merge(
      rows('new ship'),
      const [],
      writerId: 'new-installation',
    );
    expect(
      merged.tables['retirement_logs']!.map((row) => row['ship_name']),
      containsAll(['old ship', 'new ship']),
    );
    final updated = BackupArchive.decode(
      merged.encode(),
    ).merge(rows('updated ship'), const [], writerId: 'new-installation');
    expect(updated.tables['retirement_logs'], hasLength(2));
    expect(
      updated.tables['retirement_logs']!.map((row) => row['ship_name']),
      containsAll(['old ship', 'updated ship']),
    );
    final nextRows = rows('updated ship');
    nextRows['retirement_logs']!.add({'id': 2, 'ship_name': 'third ship'});
    final appended = updated.merge(
      nextRows,
      const [],
      writerId: 'new-installation',
    );
    expect(appended.tables['retirement_logs'], hasLength(3));
    expect(
      appended.tables['retirement_logs']!.map((row) => row['ship_name']),
      containsAll(['old ship', 'updated ship', 'third ship']),
    );
  });

  test('distinct databases preserve even byte-identical events', () {
    final rows = {
      for (final table in LogbookDatabase.backupTables)
        table: table == 'retirement_logs'
            ? <Map<String, Object?>>[
                {'id': 1, 'timestamp': 1, 'ship_name': 'same event values'},
              ]
            : <Map<String, Object?>>[],
    };
    final first = BackupArchive(
      memberId: 7,
      tables: rows,
      compositions: const [],
      writerId: 'database-one',
    );
    final merged = first.merge(rows, const [], writerId: 'database-two');
    expect(merged.tables['retirement_logs'], hasLength(2));
  });

  test('backup decompression stops before exceeding its output budget', () {
    final archive = BackupArchive(
      memberId: 7,
      tables: {
        for (final table in LogbookDatabase.backupTables)
          table: <Map<String, Object?>>[],
      },
      compositions: const [],
    );
    expect(
      () => BackupArchive.decode(archive.encode(), maxPlainBytes: 16),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'fresh account database does not trust restored installation prefs',
    () async {
      const owner = 903207;
      SharedPreferences.setMockInitialValues({
        'record_backup_installation_id': 'restored-pref-token',
      });
      final root = await Directory.systemTemp.createTemp('yahagi-source-id-');
      final oldDb = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}old.db',
      );
      final newDb = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}new.db',
      );
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      RecordBackupService serviceFor(LogbookDatabase db) => RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
      );
      final oldService = serviceFor(oldDb);
      final newService = serviceFor(newDb);
      addTearDown(() async {
        newService.dispose();
        session.dispose();
        await oldDb.close();
        await newDb.close();
        await root.delete(recursive: true);
      });
      await oldDb.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'old database',
        level: 1,
      );
      await oldService.sync();
      oldService.dispose();
      expect((await newDb.backupSnapshot())['retirement_logs'], isEmpty);
      await newDb.insertRetirementRecord(
        timestamp: 2,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'fresh database',
        level: 1,
      );
      await newService.sync();
      final archived = BackupArchive.decode(port.live[owner]!);
      expect(
        archived.tables['retirement_logs']!.map((row) => row['ship_name']),
        containsAll(['old database', 'fresh database']),
      );
    },
  );

  test(
    'failed manual sync and export replace stale successful status',
    () async {
      const owner = 903208;
      final root = await Directory.systemTemp.createTemp('yahagi-status-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'status-installation',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      expect(service.lastSync, isNotNull);
      await (await db.database).insert('retirement_logs', {
        'timestamp': 1,
        'type': '解体',
        'ship_type': '驱逐舰',
        'ship_name': 'new row',
        'level': 1,
      });
      port.failNextWrite = true;
      await expectLater(service.sync(), throwsA(isA<FileSystemException>()));
      expect(service.lastError, isNotNull);
      port.failNextWrite = true;
      await expectLater(service.export(), throwsA(isA<FileSystemException>()));
      expect(service.lastError, isNotNull);
      await service.sync();
      expect(service.lastError, isNull);
      port.failNextExport = true;
      await expectLater(service.export(), throwsA(isA<FileSystemException>()));
      expect(service.lastError, isNotNull);
    },
  );

  test('folder migration does not duplicate already copied log rows', () async {
    const owner = 903209;
    final root = await Directory.systemTemp.createTemp('yahagi-folder-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MigratingDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'same-database',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    for (var index = 0; index < 2; index++) {
      await db.insertRetirementRecord(
        timestamp: index + 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'ship $index',
        level: 1,
      );
    }
    await service.sync();
    expect(
      BackupArchive.decode(port.oldLive[owner]!).tables['retirement_logs'],
      hasLength(2),
    );
    expect(await service.chooseDirectory(), isTrue);
    expect(
      BackupArchive.decode(port.newLive[owner]!).tables['retirement_logs'],
      hasLength(2),
    );
  });

  test('restored construction update replaces its archived row', () async {
    const owner = 903210;
    final root = await Directory.systemTemp.createTemp('yahagi-restore-map-');
    final oldDb = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}old.db',
    );
    final db = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}new.db',
    );
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final store = FileCompositionRecordStore(rootDirectory: () async => root);
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: store,
      databaseFor: (_) => db,
      installationId: 'new-database',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await oldDb.close();
      await db.close();
      await root.delete(recursive: true);
    });
    await oldDb.insertConstructionRecord(
      timestamp: 1,
      constructionType: '建造',
      shipId: null,
      shipName: '建造中',
      shipType: '',
      fuel: 30,
      ammo: 30,
      steel: 30,
      bauxite: 30,
      developmentMaterial: 1,
      secretaryName: '',
    );
    final imported = BackupArchive(
      memberId: owner,
      tables: await oldDb.backupSnapshot(),
      compositions: const [],
      writerId: 'old-database',
    );
    await service.restore(imported);
    await (await db.database).update('construction_logs', {
      'ship_name': '完成',
    }, where: 'id = 1');
    await service.sync();
    final saved = BackupArchive.decode(port.live[owner]!);
    expect(saved.tables['construction_logs'], hasLength(1));
    expect(saved.tables['construction_logs']!.single['ship_name'], '完成');
  });

  test('account A tail write is backed up after switching to B', () async {
    const accountA = 903211;
    const accountB = 903212;
    final root = await Directory.systemTemp.createTemp('yahagi-tail-write-');
    final dbA = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}a.db',
    );
    final dbB = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}b.db',
    );
    final session = AccountSession(initialMemberId: accountA);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (id) => id == accountA ? dbA : dbB,
      installationId: 'tail-write-installation',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await dbA.close();
      await dbB.close();
      await root.delete(recursive: true);
    });
    await service.sync();
    final release = Completer<void>();
    final delayedWrite = () async {
      await release.future;
      await dbA.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'A late write',
        level: 1,
      );
    }();
    session.selectMember(accountB);
    await service.sync();
    release.complete();
    await delayedWrite;
    await service.sync();
    final archiveA = BackupArchive.decode(port.live[accountA]!);
    expect(
      archiveA.tables['retirement_logs']!.map((row) => row['ship_name']),
      contains('A late write'),
    );
  });

  test('queued account A backup keeps its verified display filename', () async {
    const accountA = 903213;
    const accountB = 903214;
    final root = await Directory.systemTemp.createTemp('yahagi-name-race-');
    final dbA = await LogbookDatabase.openForTesting();
    final dbB = await LogbookDatabase.openForTesting();
    final session = AccountSession();
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (id) => id == accountA ? dbA : dbB,
      installationId: 'name-installation',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await dbA.close();
      await dbB.close();
      await root.delete(recursive: true);
    });
    await service.start();
    session.accept(
      CapturedApiEvent(
        path: '/kcsapi/api_get_member/basic',
        responseBody:
            '{"api_result":1,"api_data":{"api_member_id":$accountA,"api_nickname":"提督甲"}}',
        source: CaptureSource.manual,
        sourceOrigin: 'https://w20h.kancolle-server.com',
        capturedAt: DateTime.utc(2026),
      ),
    );
    session.selectMember(accountB);
    await service.sync();
    expect(port.liveNames[accountA], '提督甲-w20h.kancolle-server.com.yhb');
  });

  test('pending construction deletion emits a backup write signal', () async {
    final db = await LogbookDatabase.openForTesting();
    addTearDown(db.close);
    final id = await db.insertConstructionRecord(
      dockId: 1,
      timestamp: 1,
      constructionType: '建造',
      shipId: null,
      shipName: '建造中',
      shipType: '',
      fuel: 30,
      ammo: 30,
      steel: 30,
      bauxite: 30,
      developmentMaterial: 1,
      secretaryName: '',
    );
    await (await db.database).insert('pending_construction_logs', {
      'dock_id': 1,
      'record_id': id,
    });
    final before = db.backupWrites.value;
    expect(
      await db.clearPendingConstructionRecordForDock(dockId: 1, recordId: id),
      isTrue,
    );
    expect(db.backupWrites.value, greaterThan(before));
  });

  test('burst backup write signals coalesce into bounded snapshots', () async {
    const owner = 903223;
    final root = await Directory.systemTemp.createTemp('yahagi-coalesce-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'same-database',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.sync();
    for (var index = 0; index < 12; index++) {
      await db.insertRetirementRecord(
        timestamp: index + 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'history $index',
        level: 1,
      );
    }
    await service.sync();
    port.reads = 0;
    for (var index = 0; index < 100; index++) {
      db.backupWrites.value++;
    }
    await db.insertRetirementRecord(
      timestamp: 99,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'newest',
      level: 1,
    );
    await service.sync();
    expect(port.reads, lessThan(10));
    expect(
      BackupArchive.decode(
        port.live[owner]!,
      ).tables['retirement_logs']!.map((row) => row['ship_name']),
      contains('newest'),
    );
    expect(service.pending, isFalse);
  });

  test(
    'automatic writes wait for a batch and close durably flushes it',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 903228;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-backup-batch-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        session: session,
        port: port,
        enabledStore: _EnabledStore(),
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'batch-test',
      );
      addTearDown(() async {
        await service.close();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      port.reads = 0;
      for (var i = 0; i < 12; i++) {
        await db.insertRetirementRecord(
          timestamp: i + 1,
          type: '解体',
          shipType: '驱逐舰',
          shipName: 'batched $i',
          level: 1,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final readsDuringBurst = port.reads;
      final pendingDuringBurst = service.pending;
      await service.close();
      expect(
        readsDuringBurst,
        0,
        reason: 'Port writes should settle before starting a full archive.',
      );
      expect(pendingDuringBurst, isTrue);
      expect(
        BackupArchive.decode(port.live[owner]!).tables['retirement_logs'],
        hasLength(12),
      );
    },
  );

  test(
    'repeated lifecycle flushes do not rescan clean record history',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 903229;
      final root = await Directory.systemTemp.createTemp('yahagi-clean-flush-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        session: session,
        port: port,
        enabledStore: _EnabledStore(),
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'flush-test',
      );
      addTearDown(() async {
        await service.close();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.sync();
      port.reads = 0;
      await Future.wait([service.flush(), service.flush()]);
      expect(port.reads, 0);
      await db.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'before pause',
        level: 1,
      );
      await Future.wait([service.flush(), service.flush()]);
      expect(port.reads, 2);
      expect(
        BackupArchive.decode(port.live[owner]!).tables['retirement_logs'],
        hasLength(1),
      );
      expect(service.pending, isFalse);
    },
  );

  test('continuous writes do not starve a queued manual sync', () async {
    const owner = 903224;
    final root = await Directory.systemTemp.createTemp('yahagi-coalesce-fair-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'same-database',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.sync();
    port.reads = 0;
    port.onRead = () {
      if (port.reads < 40) db.backupWrites.value++;
    };
    db.backupWrites.value++;
    await service.sync();
    expect(port.reads, lessThan(12));
    port.onRead = null;
    await service.sync();
  });

  test(
    'bulk clear preserves pending construction link until explicit unlink',
    () async {
      const owner = 903221;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-pending-clear-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'same-database',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      final recordId = await db.insertConstructionStartRecord(
        dockId: 1,
        timestamp: 1,
        constructionType: '建造',
        shipId: null,
        shipName: '建造中',
        shipType: '',
        fuel: 30,
        ammo: 30,
        steel: 30,
        bauxite: 30,
        developmentMaterial: 1,
        secretaryName: '',
      );
      await service.sync();
      expect(
        BackupArchive.decode(
          port.live[owner]!,
        ).tables['pending_construction_logs'],
        hasLength(1),
      );
      await service.clearLogbookMain();
      await service.sync();
      final saved = BackupArchive.decode(port.live[owner]!);
      expect(saved.tables['pending_construction_logs'], hasLength(1));
      await service.restore(saved);
      expect(await db.getPendingConstructionRecordForDock(1), isNotNull);
      expect(
        await db.clearPendingConstructionRecordForDock(
          dockId: 1,
          recordId: recordId,
        ),
        isTrue,
      );
      await service.sync();
      expect(
        BackupArchive.decode(
          port.live[owner]!,
        ).tables['pending_construction_logs'],
        isEmpty,
      );
    },
  );

  test('composition writes are rejected during restore maintenance', () async {
    const owner = 903219;
    final root = await Directory.systemTemp.createTemp('yahagi-comp-gate-');
    final store = FileCompositionRecordStore(rootDirectory: () async => root);
    addTearDown(() async => root.delete(recursive: true));
    await store.enterMaintenance(owner);
    try {
      await expectLater(
        store.create(
          memberId: owner,
          png: Uint8List.fromList([1]),
          note: '',
          name: '',
          fleetForm: '',
          targetMap: '',
          fleetIds: const [],
          landBaseCount: 0,
          createdAt: DateTime.utc(2026),
        ),
        throwsA(isA<StateError>()),
      );
      await store.replaceAll(owner, const []);
    } finally {
      await store.leaveMaintenance(owner);
    }
    expect(await store.load(owner), isEmpty);
  });

  test(
    'checksum-valid wrong column types cannot alter main or live data',
    () async {
      const owner = 903215;
      final root = await Directory.systemTemp.createTemp('yahagi-invalid-row-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'validation-installation',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await db.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'original',
        level: 1,
      );
      await service.sync();
      final originalLive = Uint8List.fromList(port.live[owner]!);
      final original = BackupArchive.decode(originalLive);
      final invalid = BackupArchive(
        memberId: owner,
        tables: {
          ...original.tables,
          'retirement_logs': [
            {
              ...original.tables['retirement_logs']!.single,
              'timestamp': 'oops',
            },
          ],
        },
        compositions: const [],
      );
      await expectLater(
        service.restore(invalid),
        throwsA(isA<FormatException>()),
      );
      expect((await db.getRetirementRecords()).single['timestamp'], 1);
      expect(port.live[owner], orderedEquals(originalLive));
    },
  );

  for (final restoringWriter in ['A', 'C']) {
    test(
      'restore as $restoringWriter retains other database row identities',
      () async {
        SharedPreferences.setMockInitialValues({});
        const owner = 903299;
        final root = await Directory.systemTemp.createTemp(
          'yahagi-writer-restore-',
        );
        final source = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}source.db',
        );
        final restoredDb = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}restored.db',
        );
        final session = AccountSession(initialMemberId: owner);
        final port = _MemoryDocumentPort();
        final service = RecordBackupService(
          enabledStore: _EnabledStore(),
          session: session,
          port: port,
          compositionStore: FileCompositionRecordStore(
            rootDirectory: () async => root,
          ),
          databaseFor: (_) => restoredDb,
          installationId: restoringWriter,
        );
        addTearDown(() async {
          service.dispose();
          session.dispose();
          await source.close();
          await restoredDb.close();
          await root.delete(recursive: true);
        });
        await source.insertRetirementRecord(
          timestamp: 1,
          type: '解体',
          shipType: '驱逐舰',
          shipName: 'same event values',
          level: 1,
        );
        final sourceTables = await source.backupSnapshot();
        final archive =
            BackupArchive(
                  memberId: owner,
                  tables: {
                    for (final table in LogbookDatabase.backupTables) table: [],
                  },
                  compositions: [],
                )
                .merge(sourceTables, [], writerId: 'A')
                .merge(sourceTables, [], writerId: 'B');
        await service.restore(archive);
        await service.sync();
        final fromDisk = BackupArchive.decode(port.live[owner]!);
        final returned = fromDisk.merge(sourceTables, [], writerId: 'B');
        expect(returned.tables['retirement_logs'], hasLength(2));
        expect((await restoredDb.getRetirementRecords()), hasLength(2));
      },
    );
  }

  test('startup replays an interrupted restore before automatic sync', () async {
    const owner = 903216;
    final root = await Directory.systemTemp.createTemp('yahagi-journal-');
    final sourceDb = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}source.db',
    );
    final db = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}current.db',
    );
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'current-database',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await sourceDb.close();
      await db.close();
      await root.delete(recursive: true);
    });
    await sourceDb.insertRetirementRecord(
      timestamp: 1,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'restore target',
      level: 1,
    );
    final target = BackupArchive(
      memberId: owner,
      tables: await sourceDb.backupSnapshot(),
      compositions: const [],
      writerId: 'current-database',
      rowIds: {
        'retirement_logs': {'1': 1},
      },
    );
    final journal = File(
      '${root.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}$owner.yhb',
    );
    await journal.parent.create(recursive: true);
    await journal.writeAsBytes(
      BackupRestoreJournal(archive: target, requiresExternal: true).encode(),
      flush: true,
    );
    await service.sync();
    expect(
      (await db.getRetirementRecords()).single['ship_name'],
      'restore target',
    );
    expect(
      BackupArchive.decode(port.live[owner]!).tables['retirement_logs'],
      hasLength(1),
    );
    expect(await journal.exists(), isFalse);
  });

  for (final interruptedStage in ['logbook', 'compositions', 'backup']) {
    test(
      'restart completes restore interrupted after $interruptedStage',
      () async {
        SharedPreferences.setMockInitialValues({});
        const owner = 903225;
        final root = await Directory.systemTemp.createTemp('yahagi-stage-');
        final sourceDb = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}source.db',
        );
        final db = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}current.db',
        );
        final session = AccountSession(initialMemberId: owner);
        final port = _MemoryDocumentPort();
        final store = FileCompositionRecordStore(
          rootDirectory: () async => root,
        );
        final first = RecordBackupService(
          enabledStore: _EnabledStore(),
          session: session,
          port: port,
          compositionStore: store,
          databaseFor: (_) => db,
          installationId: 'current-database',
          afterRestoreStage: (stage) async {
            if (stage == interruptedStage) {
              throw const RestoreInterruptionForTesting();
            }
          },
        );
        addTearDown(() async {
          session.dispose();
          await sourceDb.close();
          await db.close();
          await root.delete(recursive: true);
        });
        await db.insertRetirementRecord(
          timestamp: 1,
          type: '解体',
          shipType: '驱逐舰',
          shipName: 'old',
          level: 1,
        );
        await first.sync();
        await sourceDb.insertRetirementRecord(
          timestamp: 2,
          type: '解体',
          shipType: '驱逐舰',
          shipName: 'target',
          level: 1,
        );
        final record = CompositionRecord(
          id: 'restored-composition',
          createdAt: DateTime.utc(2026),
          note: '',
          fleetForm: '',
          targetMap: '',
          fleetIds: const [],
          landBaseCount: 0,
          snapshotJson: serializeCompositionSnapshot(
            GameState(memberId: owner),
            fleetIds: const {},
            landBaseAreaId: null,
            landBaseIds: const {},
          ),
        );
        await expectLater(
          first.restore(
            BackupArchive(
              memberId: owner,
              tables: await sourceDb.backupSnapshot(),
              compositions: [record],
            ),
          ),
          throwsA(isA<RestoreInterruptionForTesting>()),
        );
        expect(first.maintenanceActive, isTrue);
        await first.close();
        final restarted = RecordBackupService(
          enabledStore: _EnabledStore(),
          session: session,
          port: port,
          compositionStore: FileCompositionRecordStore(
            rootDirectory: () async => root,
          ),
          databaseFor: (_) => db,
          installationId: 'current-database',
        );
        addTearDown(restarted.close);
        await restarted.start();
        expect((await db.getRetirementRecords()).single['ship_name'], 'target');
        expect(
          (await restarted.compositionStore.load(owner)).single.id,
          record.id,
        );
        final live = BackupArchive.decode(port.live[owner]!);
        expect(live.tables['retirement_logs']!.single['ship_name'], 'target');
        expect(live.compositions.single.id, record.id);
      },
    );
  }

  test('runtime recovery reselects folder after SAF permission loss', () async {
    const owner = 903226;
    final root = await Directory.systemTemp.createTemp('yahagi-repick-');
    final sourceDb = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}source.db',
    );
    final db = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}current.db',
    );
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    var interrupted = false;
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'current-database',
      afterRestoreStage: (stage) async {
        if (stage == 'logbook' && !interrupted) {
          interrupted = true;
          port.directory = false;
          throw const RestoreInterruptionForTesting();
        }
      },
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await sourceDb.close();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.sync();
    await sourceDb.insertRetirementRecord(
      timestamp: 1,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'target',
      level: 1,
    );
    await expectLater(
      service.restore(
        BackupArchive(
          memberId: owner,
          tables: await sourceDb.backupSnapshot(),
          compositions: const [],
        ),
      ),
      throwsA(isA<RestoreInterruptionForTesting>()),
    );
    expect(service.maintenanceActive, isTrue);
    port.directory = true;
    expect(await service.reselectDirectoryForRecovery(), isTrue);
    await service.recoverPendingRestores();
    expect(service.maintenanceActive, isFalse);
    expect((await db.getRetirementRecords()).single['ship_name'], 'target');
    expect(BackupArchive.decode(port.live[owner]!).memberId, owner);
  });

  test('committed restore is not replayed if journal deletion fails', () async {
    const owner = 903217;
    final root = await Directory.systemTemp.createTemp('yahagi-commit-marker-');
    final sourceDb = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}source.db',
    );
    final db = await LogbookDatabase.openForTesting(
      path: '${root.path}${Platform.pathSeparator}current.db',
    );
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    RecordBackupService service({bool failDelete = false}) =>
        RecordBackupService(
          enabledStore: _EnabledStore(),
          session: session,
          port: port,
          compositionStore: FileCompositionRecordStore(
            rootDirectory: () async => root,
          ),
          databaseFor: (_) => db,
          installationId: 'current-database',
          deleteRestoreJournal: failDelete
              ? (_) async => throw const FileSystemException('delete denied')
              : null,
        );
    final first = service(failDelete: true);
    addTearDown(() async {
      session.dispose();
      await sourceDb.close();
      await db.close();
      await root.delete(recursive: true);
    });
    await sourceDb.insertRetirementRecord(
      timestamp: 1,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'restored',
      level: 1,
    );
    CompositionRecord record(String id) => CompositionRecord(
      id: id,
      createdAt: DateTime.utc(2026),
      note: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
      snapshotJson: serializeCompositionSnapshot(
        const GameState(memberId: owner),
        fleetIds: {},
        landBaseAreaId: null,
        landBaseIds: {},
      ),
    );
    await first.restore(
      BackupArchive(
        memberId: owner,
        tables: await sourceDb.backupSnapshot(),
        compositions: [record('keep'), record('remove-after-restore')],
      ),
    );
    final journal = File(
      '${root.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}$owner.yhb',
    );
    expect(await journal.exists(), isTrue);
    expect(await File('${journal.path}.committed').exists(), isTrue);
    expect(await File('${journal.path}.deletions-cleared').exists(), isTrue);
    await first.removeCompositionRecord(owner, 'remove-after-restore');
    await first.sync();
    expect(
      BackupArchive.decode(
        port.live[owner]!,
      ).compositions.map((item) => item.id),
      ['keep'],
    );
    await db.insertRetirementRecord(
      timestamp: 2,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'after restore',
      level: 1,
    );
    await first.sync();
    first.dispose();
    final second = service();
    addTearDown(second.dispose);
    await second.start();
    expect(
      (await db.getRetirementRecords()).map((row) => row['ship_name']),
      containsAll(['restored', 'after restore']),
    );
  });

  test(
    'failed deletion marker keeps restore maintenance until recovery',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 914008;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-deletion-marker-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      var failMarker = true;
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'deletion-marker-test',
        afterRestoreStage: (stage) async {
          if (stage == 'deletion_intent' && failMarker) {
            failMarker = false;
            throw const FileSystemException('simulated marker write failure');
          }
        },
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      final record = CompositionRecord(
        id: 'remove-after-recovery',
        createdAt: DateTime.utc(2026),
        note: '',
        fleetForm: '',
        targetMap: '',
        fleetIds: const [],
        landBaseCount: 0,
        snapshotJson: serializeCompositionSnapshot(
          const GameState(memberId: owner),
          fleetIds: {},
          landBaseAreaId: null,
          landBaseIds: {},
        ),
      );
      await expectLater(
        service.restore(
          BackupArchive(
            memberId: owner,
            tables: await db.backupSnapshot(),
            compositions: [record],
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(service.maintenanceActive, isTrue);
      await expectLater(
        service.removeCompositionRecord(owner, record.id),
        throwsStateError,
      );
      expect((await store.load(owner)).map((item) => item.id), [record.id]);
      await service.recoverPendingRestores();
      expect(service.maintenanceActive, isFalse);
      await service.removeCompositionRecord(owner, record.id);
      await service.sync();
      expect(BackupArchive.decode(port.live[owner]!).compositions, isEmpty);
    },
  );

  test(
    'orphan completion marker is removed before a new restore journal',
    () async {
      const owner = 903218;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-orphan-marker-',
      );
      final sourceDb = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}source.db',
      );
      final db = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}current.db',
      );
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      final journal = File(
        '${root.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}$owner.yhb',
      );
      await journal.parent.create(recursive: true);
      await File('${journal.path}.committed').writeAsString('old checksum');
      final first = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'current-database',
        afterJournalWritten: (file) async {
          expect(await File('${file.path}.committed').exists(), isFalse);
          throw const FileSystemException(
            'simulated exit before main mutation',
          );
        },
      );
      addTearDown(() async {
        session.dispose();
        await sourceDb.close();
        await db.close();
        await root.delete(recursive: true);
      });
      await sourceDb.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'target',
        level: 1,
      );
      final target = BackupArchive(
        memberId: owner,
        tables: await sourceDb.backupSnapshot(),
        compositions: const [],
      );
      await expectLater(
        first.restore(target),
        throwsA(isA<FileSystemException>()),
      );
      expect(await db.getRetirementRecords(), isEmpty);
      first.dispose();
      final second = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'current-database',
      );
      addTearDown(second.dispose);
      await second.start();
      expect((await db.getRetirementRecords()).single['ship_name'], 'target');
    },
  );

  test(
    'orphan marker from failed cleanup cannot commit a later restore',
    () async {
      const owner = 903219;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-marker-sequence-',
      );
      final sourceDb = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}source.db',
      );
      final db = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}current.db',
      );
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      final journal = File(
        '${root.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}$owner.yhb',
      );
      final first = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'current-database',
        deleteCommittedMarker: (_) async =>
            throw const FileSystemException('marker delete denied'),
      );
      addTearDown(() async {
        session.dispose();
        await sourceDb.close();
        await db.close();
        await root.delete(recursive: true);
      });
      await sourceDb.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'first target',
        level: 1,
      );
      await first.restore(
        BackupArchive(
          memberId: owner,
          tables: await sourceDb.backupSnapshot(),
          compositions: const [],
        ),
      );
      expect(await journal.exists(), isFalse);
      expect(await File('${journal.path}.committed').exists(), isTrue);
      first.dispose();

      await sourceDb.insertRetirementRecord(
        timestamp: 2,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'second target',
        level: 1,
      );
      final second = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'current-database',
        afterJournalWritten: (_) async =>
            throw const FileSystemException('process stopped after journal'),
      );
      await expectLater(
        second.restore(
          BackupArchive(
            memberId: owner,
            tables: await sourceDb.backupSnapshot(),
            compositions: const [],
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await journal.exists(), isTrue);
      expect(await File('${journal.path}.committed').exists(), isFalse);
      second.dispose();
      final restarted = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'current-database',
      );
      addTearDown(restarted.dispose);
      await restarted.start();
      expect(
        (await db.getRetirementRecords()).map((row) => row['ship_name']),
        containsAll(['first target', 'second target']),
      );
      expect(await journal.exists(), isFalse);
    },
  );

  for (final clearBeforeBinding in [false, true]) {
    test(
      'no-folder restore replaces older folder backup '
      '${clearBeforeBinding ? 'after main clear' : 'on folder bind'}',
      () async {
        const owner = 903220;
        final root = await Directory.systemTemp.createTemp('yahagi-baseline-');
        final oldDb = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}old.db',
        );
        final targetDb = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}target.db',
        );
        final db = await LogbookDatabase.openForTesting(
          path: '${root.path}${Platform.pathSeparator}current.db',
        );
        final session = AccountSession(initialMemberId: owner);
        final port = _MemoryDocumentPort()..directory = false;
        final service = RecordBackupService(
          enabledStore: _EnabledStore(),
          session: session,
          port: port,
          compositionStore: FileCompositionRecordStore(
            rootDirectory: () async => root,
          ),
          databaseFor: (_) => db,
          installationId: 'same-database',
        );
        addTearDown(() async {
          service.dispose();
          session.dispose();
          await oldDb.close();
          await targetDb.close();
          await db.close();
          await root.delete(recursive: true);
        });
        await oldDb.insertRetirementRecord(
          timestamp: 1,
          type: '解体',
          shipType: '驱逐舰',
          shipName: 'obsolete',
          level: 1,
        );
        await targetDb.insertRetirementRecord(
          timestamp: 2,
          type: '解体',
          shipType: '驱逐舰',
          shipName: 'restored',
          level: 1,
        );
        final target = BackupArchive(
          memberId: owner,
          tables: await targetDb.backupSnapshot(),
          compositions: const [],
        );
        await service.restore(target);
        var expectedName = 'restored';
        if (clearBeforeBinding) {
          await targetDb.clearAll();
          await targetDb.insertRetirementRecord(
            timestamp: 4,
            type: '解体',
            shipType: '驱逐舰',
            shipName: 'second restored',
            level: 1,
          );
          await service.restore(
            BackupArchive(
              memberId: owner,
              tables: await targetDb.backupSnapshot(),
              compositions: const [],
            ),
          );
          expectedName = 'second restored';
          await db.clearAll();
        } else {
          await db.insertRetirementRecord(
            timestamp: 3,
            type: '解体',
            shipType: '驱逐舰',
            shipName: 'after restore',
            level: 1,
          );
        }
        port
          ..directory = true
          ..live[owner] = BackupArchive(
            memberId: owner,
            tables: await oldDb.backupSnapshot(),
            compositions: const [],
          ).encode();
        await service.chooseDirectory();
        final names = BackupArchive.decode(
          port.live[owner]!,
        ).tables['retirement_logs']!.map((row) => row['ship_name']).toList();
        expect(names, contains(expectedName));
        expect(names, isNot(contains('obsolete')));
        if (clearBeforeBinding) expect(names, isNot(contains('restored')));
        if (!clearBeforeBinding) expect(names, contains('after restore'));
      },
    );
  }

  test(
    'inactive baseline after cleanup failure never replays over new writes',
    () async {
      const owner = 903222;
      final root = await Directory.systemTemp.createTemp('yahagi-adopted-');
      final source = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}source.db',
      );
      final db = await LogbookDatabase.openForTesting(
        path: '${root.path}${Platform.pathSeparator}current.db',
      );
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort()..directory = false;
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'same-database',
        deleteAdoptedBaseline: (_) async =>
            throw const FileSystemException('adopted delete denied'),
      );
      addTearDown(() async {
        session.dispose();
        await source.close();
        await db.close();
        await root.delete(recursive: true);
      });
      await source.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'restored',
        level: 1,
      );
      await service.restore(
        BackupArchive(
          memberId: owner,
          tables: await source.backupSnapshot(),
          compositions: const [],
        ),
      );
      port.directory = true;
      await service.chooseDirectory();
      final baseline = File(
        '${root.path}${Platform.pathSeparator}record_backup_baseline${Platform.pathSeparator}$owner.yhb',
      );
      expect(await baseline.exists(), isFalse);
      expect(await File('${baseline.path}.adopted').exists(), isTrue);
      await db.insertRetirementRecord(
        timestamp: 2,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'later write',
        level: 1,
      );
      await service.sync();
      service.dispose();
      final restarted = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'same-database',
      );
      addTearDown(restarted.dispose);
      await restarted.sync();
      expect(
        BackupArchive.decode(
          port.live[owner]!,
        ).tables['retirement_logs']!.map((row) => row['ship_name']),
        containsAll(['restored', 'later write']),
      );
    },
  );

  test('merged IDs restore both installations into SQLite', () async {
    final oldDb = await LogbookDatabase.openForTesting();
    final newDb = await LogbookDatabase.openForTesting();
    final restoredDb = await LogbookDatabase.openForTesting();
    addTearDown(() async {
      await oldDb.close();
      await newDb.close();
      await restoredDb.close();
    });
    Future<void> add(LogbookDatabase db, String name) =>
        db.insertRetirementRecord(
          timestamp: 1,
          type: '解体',
          shipType: '驱逐舰',
          shipName: name,
          level: 1,
        );
    await add(oldDb, '旧记录');
    await add(newDb, '新记录');
    final archive = BackupArchive(
      memberId: 77,
      tables: await oldDb.backupSnapshot(),
      compositions: const [],
      writerId: 'old',
    ).merge(await newDb.backupSnapshot(), const [], writerId: 'new');
    await restoredDb.restoreSnapshot(
      BackupArchive.decode(archive.encode()).tables,
    );
    expect(
      (await restoredDb.getRetirementRecords()).map((row) => row['ship_name']),
      containsAll(['旧记录', '新记录']),
    );
  });

  test(
    'backup survives both bulk cleanup actions and restores data without PNG',
    () async {
      const owner = 903201;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-record-backup-',
      );
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'installation-one',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.start();
      await db.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: '五月雨',
        level: 1,
      );
      final record = await store.create(
        memberId: owner,
        png: Uint8List.fromList([1, 2, 3]),
        note: '舰队"甲"\n第二行',
        name: 'fleet',
        fleetForm: '通常',
        targetMap: '',
        fleetIds: [1],
        landBaseCount: 0,
        createdAt: DateTime.utc(2026, 9, 26),
        snapshotJson: serializeCompositionSnapshot(
          const GameState(memberId: owner),
          fleetIds: {1},
          landBaseAreaId: null,
          landBaseIds: {},
        ),
      );
      await service.sync();
      final saved = BackupArchive.decode(port.live[owner]!);
      expect(saved.tables['retirement_logs'], hasLength(1));
      expect(saved.compositions.single.id, record.id);
      await db.clearAll();
      expect(await store.clearAll(owner), 1);
      await service.sync();
      final retained = BackupArchive.decode(port.live[owner]!);
      expect(retained.tables['retirement_logs'], hasLength(1));
      expect(retained.compositions, hasLength(1));
      await service.restore(retained);
      expect(await db.getRetirementRecords(), hasLength(1));
      expect((await store.load(owner)).single.id, record.id);
      expect((await store.load(owner)).single.note, '舰队"甲"\n第二行');
      await expectLater(
        store.readPng(owner, record.id),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'wrong account and damaged backup cannot overwrite current data',
    () async {
      const owner = 903202;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-record-backup-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'installation-one',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.start();
      await db.insertRetirementRecord(
        timestamp: 2,
        type: '解体',
        shipType: '驱逐舰',
        shipName: '时雨',
        level: 2,
      );
      await service.sync();
      final valid = BackupArchive.decode(port.live[owner]!);
      port.importBytes = BackupArchive(
        memberId: owner + 1,
        tables: valid.tables,
        compositions: const [],
      ).encode();
      await expectLater(service.import(), throwsA(isA<StateError>()));
      expect(await db.getRetirementRecords(), hasLength(1));
      final damaged = Uint8List.fromList(port.live[owner]!);
      damaged[damaged.length - 5] ^= 1;
      port.live[owner] = damaged;
      await expectLater(service.sync(), throwsA(isA<FormatException>()));
      expect(await db.getRetirementRecords(), hasLength(1));
    },
  );

  test('single composition deletion removes the archived record', () async {
    const owner = 903203;
    final root = await Directory.systemTemp.createTemp('yahagi-record-backup-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final store = FileCompositionRecordStore(rootDirectory: () async => root);
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: store,
      databaseFor: (_) => db,
      installationId: 'installation-one',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.start();
    final record = await store.create(
      memberId: owner,
      png: Uint8List.fromList([1]),
      note: '',
      name: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
      createdAt: DateTime.utc(2026),
      snapshotJson: serializeCompositionSnapshot(
        const GameState(memberId: owner),
        fleetIds: {},
        landBaseAreaId: null,
        landBaseIds: {},
      ),
    );
    await service.sync();
    await service.removeCompositionRecord(owner, record.id);
    await service.sync();
    expect(BackupArchive.decode(port.live[owner]!).compositions, isEmpty);
    expect(await store.load(owner), isEmpty);
  });

  test('composition deletions without backup access survive restart', () async {
    SharedPreferences.setMockInitialValues({});
    const owner = 914004;
    final root = await Directory.systemTemp.createTemp(
      'yahagi-offline-delete-',
    );
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final store = FileCompositionRecordStore(rootDirectory: () async => root);
    final setting = _EnabledStore();
    RecordBackupService makeService() => RecordBackupService(
      enabledStore: setting,
      session: session,
      port: port,
      compositionStore: store,
      databaseFor: (_) => db,
      installationId: 'offline-delete-test',
    );
    var service = makeService();
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.start();
    final record = await store.create(
      memberId: owner,
      png: Uint8List.fromList([1]),
      note: '',
      name: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
      createdAt: DateTime.utc(2026),
      snapshotJson: serializeCompositionSnapshot(
        const GameState(memberId: owner),
        fleetIds: {},
        landBaseAreaId: null,
        landBaseIds: {},
      ),
    );
    await service.sync();
    expect(BackupArchive.decode(port.live[owner]!).compositions, hasLength(1));
    await service.setEnabled(false);
    await service.removeCompositionRecord(owner, record.id);
    expect(BackupArchive.decode(port.live[owner]!).compositions, hasLength(1));
    service.dispose();
    service = makeService();
    await service.start();
    await service.setEnabled(true);
    await service.sync();
    expect(BackupArchive.decode(port.live[owner]!).compositions, isEmpty);

    final second = await store.create(
      memberId: owner,
      png: Uint8List.fromList([2]),
      note: '',
      name: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
      createdAt: DateTime.utc(2026, 2),
      snapshotJson: serializeCompositionSnapshot(
        const GameState(memberId: owner),
        fleetIds: {},
        landBaseAreaId: null,
        landBaseIds: {},
      ),
    );
    await service.sync();
    expect(BackupArchive.decode(port.live[owner]!).compositions, hasLength(1));
    service.dispose();
    port.directory = false;
    service = makeService();
    await service.start();
    expect(service.enabled, isTrue);
    expect(service.hasDirectory, isFalse);
    await service.removeCompositionRecord(owner, second.id);
    expect(BackupArchive.decode(port.live[owner]!).compositions, hasLength(1));
    service.dispose();
    port.directory = true;
    service = makeService();
    await service.start();
    await service.sync();
    expect(BackupArchive.decode(port.live[owner]!).compositions, isEmpty);

    final third = await store.create(
      memberId: owner,
      png: Uint8List.fromList([3]),
      note: '',
      name: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
      createdAt: DateTime.utc(2026, 3),
      snapshotJson: serializeCompositionSnapshot(
        const GameState(memberId: owner),
        fleetIds: {},
        landBaseAreaId: null,
        landBaseIds: {},
      ),
    );
    await service.sync();
    service.dispose();
    port.directory = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'record_backup_offline_deleted_compositions_$owner',
      [third.id],
    );
    service = makeService();
    await service.start();
    await service.setEnabled(false);
    expect(await store.load(owner), isEmpty);
    service.dispose();
    port.directory = true;
    service = makeService();
    await service.start();
    await service.setEnabled(true);
    await service.sync();
    expect(BackupArchive.decode(port.live[owner]!).compositions, isEmpty);
  });

  test('restore replaces an earlier offline composition deletion', () async {
    SharedPreferences.setMockInitialValues({});
    const owner = 914007;
    final root = await Directory.systemTemp.createTemp(
      'yahagi-restore-delete-',
    );
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final store = FileCompositionRecordStore(rootDirectory: () async => root);
    RecordBackupService makeService() => RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: store,
      databaseFor: (_) => db,
      installationId: 'restore-delete-test',
    );
    var service = makeService();
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.start();
    final record = await store.create(
      memberId: owner,
      png: Uint8List.fromList([1]),
      note: '',
      name: '',
      fleetForm: '',
      targetMap: '',
      fleetIds: const [],
      landBaseCount: 0,
      createdAt: DateTime.utc(2026),
      snapshotJson: serializeCompositionSnapshot(
        const GameState(memberId: owner),
        fleetIds: {},
        landBaseAreaId: null,
        landBaseIds: {},
      ),
    );
    await service.sync();
    final original = BackupArchive.decode(port.live[owner]!);
    service.dispose();
    port.directory = false;
    service = makeService();
    await service.start();
    await service.removeCompositionRecord(owner, record.id);
    expect(await store.load(owner), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    final key = 'record_backup_offline_deleted_compositions_$owner';
    expect(preferences.getStringList(key), contains(record.id));

    await service.restore(original);
    expect(
      (await store.load(owner)).map((item) => item.id),
      contains(record.id),
    );
    expect(preferences.containsKey(key), isFalse);
    port.directory = true;
    expect(await service.chooseDirectory(), isTrue);
    await service.sync();
    expect(
      BackupArchive.decode(
        port.live[owner]!,
      ).compositions.map((item) => item.id),
      contains(record.id),
    );
  });

  test(
    'failed restore rolls back main data and preserves live backup',
    () async {
      const owner = 903204;
      final root = await Directory.systemTemp.createTemp(
        'yahagi-record-backup-',
      );
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: FileCompositionRecordStore(
          rootDirectory: () async => root,
        ),
        databaseFor: (_) => db,
        installationId: 'installation-one',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.start();
      await db.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: '五月雨',
        level: 1,
      );
      await service.sync();
      final original = Uint8List.fromList(port.live[owner]!);
      final archive = BackupArchive.decode(original);
      final replacement = BackupArchive(
        memberId: owner,
        tables: {
          ...archive.tables,
          'retirement_logs': [
            {...archive.tables['retirement_logs']!.single, 'ship_name': '时雨'},
          ],
        },
        compositions: const [],
      );
      port.failNextWrite = true;
      await expectLater(
        service.restore(replacement),
        throwsA(isA<FileSystemException>()),
      );
      expect((await db.getRetirementRecords()).single['ship_name'], '五月雨');
      expect(port.live[owner], orderedEquals(original));
    },
  );

  test('logbook cleanup retries a write after its verified snapshot', () async {
    const owner = 903205;
    final root = await Directory.systemTemp.createTemp('yahagi-clear-race-');
    final db = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: owner);
    final port = _MemoryDocumentPort();
    final service = RecordBackupService(
      enabledStore: _EnabledStore(),
      session: session,
      port: port,
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => root,
      ),
      databaseFor: (_) => db,
      installationId: 'race-installation',
    );
    addTearDown(() async {
      service.dispose();
      session.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    await service.start();
    await service.sync();
    await db.insertRetirementRecord(
      timestamp: 76,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'before',
      level: 1,
    );
    await service.sync();
    port.gateAtRead = port.reads + 2;
    port.readPaused = Completer<void>();
    port.readGate = Completer<void>();
    final cleanup = service.clearLogbookMain();
    await port.readPaused!.future;
    await db.insertRetirementRecord(
      timestamp: 77,
      type: '解体',
      shipType: '驱逐舰',
      shipName: 'interleaved',
      level: 1,
    );
    port.readGate!.complete();
    await cleanup;
    await service.sync();
    final archived = BackupArchive.decode(port.live[owner]!);
    expect(
      archived.tables['retirement_logs']!.map((row) => row['ship_name']),
      containsAll(['before', 'interleaved']),
    );
    await service.restore(archived);
    expect(await db.getRetirementRecords(), hasLength(2));
  });

  test(
    'composition cleanup retries a write after its verified snapshot',
    () async {
      const owner = 903206;
      final root = await Directory.systemTemp.createTemp('yahagi-clear-race-');
      final db = await LogbookDatabase.openForTesting();
      final session = AccountSession(initialMemberId: owner);
      final port = _MemoryDocumentPort();
      final store = FileCompositionRecordStore(rootDirectory: () async => root);
      final service = RecordBackupService(
        enabledStore: _EnabledStore(),
        session: session,
        port: port,
        compositionStore: store,
        databaseFor: (_) => db,
        installationId: 'race-installation',
      );
      addTearDown(() async {
        service.dispose();
        session.dispose();
        await db.close();
        await root.delete(recursive: true);
      });
      await service.start();
      await service.sync();
      Future<CompositionRecord> createRecord(String name) => store.create(
        memberId: owner,
        png: Uint8List.fromList([1]),
        note: '',
        name: name,
        fleetForm: '',
        targetMap: '',
        fleetIds: const [],
        landBaseCount: 0,
        createdAt: DateTime.utc(2026),
        snapshotJson: serializeCompositionSnapshot(
          const GameState(memberId: owner),
          fleetIds: {},
          landBaseAreaId: null,
          landBaseIds: {},
        ),
      );
      final before = await createRecord('before');
      await service.sync();
      port.gateAtRead = port.reads + 2;
      port.readPaused = Completer<void>();
      port.readGate = Completer<void>();
      final cleanup = service.clearCompositionMain();
      await port.readPaused!.future;
      final record = await createRecord('interleaved');
      port.readGate!.complete();
      expect(await cleanup, 2);
      await service.sync();
      final archived = BackupArchive.decode(port.live[owner]!);
      expect(
        archived.compositions.map((item) => item.id),
        containsAll([before.id, record.id]),
      );
      await service.restore(archived);
      expect(await store.load(owner), hasLength(2));
    },
  );
}

class _ImportHeartbeatPort extends _MemoryDocumentPort {
  bool heartbeatFired = false;
  @override
  Future<Uint8List?> pickImport() async {
    Timer.run(() => heartbeatFired = true);
    return importBytes;
  }
}

class _GatedMergeWorker extends BackupArchiveWorker {
  final started = Completer<void>();
  final release = Completer<void>();
  int active = 0;
  int peakActive = 0;
  @override
  Future<BackupArchiveResult> mergeAndEncode({
    required int memberId,
    required Uint8List? existing,
    required Map<String, List<Map<String, Object?>>> tables,
    required List<CompositionRecord> compositions,
    required String writerId,
    required Set<String> deletedCompositions,
  }) async {
    active++;
    if (active > peakActive) peakActive = active;
    try {
      if (!started.isCompleted) {
        started.complete();
        await release.future;
      }
      return await super.mergeAndEncode(
        memberId: memberId,
        existing: existing,
        tables: tables,
        compositions: compositions,
        writerId: writerId,
        deletedCompositions: deletedCompositions,
      );
    } finally {
      active--;
    }
  }
}

class _GatedDecodeWorker extends BackupArchiveWorker {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<BackupArchive> decode(
    Uint8List bytes, {
    int maxPlainBytes = 250 * 1024 * 1024,
  }) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.decode(bytes, maxPlainBytes: maxPlainBytes);
  }
}
