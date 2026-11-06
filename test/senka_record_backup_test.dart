import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/backup/record_backup.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_store.dart';

Map<String, List<Map<String, Object?>>> _tables() => {
  for (final name in LogbookDatabase.backupTables) name: [],
};

String _raw(int owner, double target) => jsonEncode(
  SenkaState.forMonth('2026-08')
      .copyWith(memberId: owner, targetSenka: target, latestExperience: 100000)
      .toJson()
    ..['futureUnknownField'] = {'preserved': true},
);

Uint8List _v2(String raw, {int owner = 1001}) {
  final compressed = gzip.encode(
    utf8.encode(
      jsonEncode({
        'memberId': owner,
        'logbookSchema': BackupArchive.logbookArchiveSchema,
        'tables': _tables(),
        'compositions': [],
        'senkaSchema': 1,
        'senkaRaw': raw,
      }),
    ),
  );
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'yahagi-record-backup',
        'version': 2,
        'sha256': sha256.convert(compressed).toString(),
        'payload': base64Encode(compressed),
      }),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  test(
    'v2 accepts an owner-verified opaque senka archive without losing unknown fields',
    () {
      final raw = _raw(1001, 3200);
      final decoded = BackupArchive.decode(_v2(raw));
      final reencoded = jsonDecode(utf8.decode(decoded.encode())) as Map;
      final payload =
          jsonDecode(
                utf8.decode(
                  gzip.decode(base64Decode(reencoded['payload'] as String)),
                ),
              )
              as Map;
      expect(reencoded['version'], 2);
      expect(payload['senkaRaw'], raw);
    },
  );

  test('v2 rejects a senka owner mismatch', () {
    expect(
      () => BackupArchive.decode(_v2(_raw(2002, 3200))),
      throwsFormatException,
    );
  });

  test('old v1 logbook backups remain readable', () {
    final old = BackupArchive(
      memberId: 1001,
      tables: _tables(),
      compositions: [],
    ).encode();
    expect(BackupArchive.decode(old).memberId, 1001);
    expect((jsonDecode(utf8.decode(old)) as Map)['version'], 1);
  });

  test('source snapshots enforce ownership and cannot be hidden in v1', () {
    expect(
      () => BackupArchive(
        memberId: 1001,
        tables: _tables(),
        compositions: [],
        senkaRaw: _raw(1001, 3000),
        senkaSources: {'device-a:hash': _raw(2002, 4200)},
      ).encode(),
      throwsFormatException,
    );
    expect(
      () => BackupArchive(
        memberId: 1001,
        tables: _tables(),
        compositions: [],
        senkaSources: {'device-a:hash': _raw(1001, 4200)},
      ).encode(),
      throwsFormatException,
    );
  });

  test(
    'merging another installation preserves its conflicting senka snapshot',
    () {
      final previous = _raw(1001, 3000);
      final current = _raw(1001, 4200);
      final merged = BackupArchive(
        memberId: 1001,
        tables: _tables(),
        compositions: [],
        writerId: 'device-a',
        senkaRaw: previous,
      ).merge(_tables(), [], writerId: 'device-b', senkaRaw: current);
      final outer = jsonDecode(utf8.decode(merged.encode())) as Map;
      final payload =
          jsonDecode(
                utf8.decode(
                  gzip.decode(base64Decode(outer['payload'] as String)),
                ),
              )
              as Map;
      expect(payload['senkaRaw'], current);
      expect(payload['senkaSources'], {
        'device-a:${sha256.convert(utf8.encode(previous))}': previous,
      });
      final secondA = _raw(1001, 3500);
      final returned = merged
          .merge(_tables(), [], writerId: 'device-a', senkaRaw: secondA)
          .merge(
            _tables(),
            [],
            writerId: 'device-b',
            senkaRaw: _raw(1001, 4600),
          );
      expect(
        returned.senkaSources.values,
        containsAll([previous, current, secondA]),
      );
      expect(
        BackupArchive.decode(returned.encode()).senkaSources,
        returned.senkaSources,
      );
    },
  );

  test(
    'senka-only writes trigger a verified v2 backup and preserve opaque fields',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final raw = _raw(1001, 3200);
      await fixture.store.restoreArchiveForAccount(1001, raw);
      await fixture.controller.reloadForAccount(1001);
      await fixture.service.flush();
      expect(BackupArchive.decode(fixture.port.live[1001]!).senkaRaw, raw);
      expect(fixture.controller.state.targetSenka, 3200);
    },
  );

  test(
    'v1 restore leaves current senka unchanged while v2 restores only its owner',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final original = _raw(1001, 3000);
      final other = _raw(2002, 5000);
      await fixture.store.restoreArchiveForAccount(1001, original);
      await fixture.store.restoreArchiveForAccount(2002, other);
      await fixture.controller.reloadForAccount(1001);
      await fixture.service.flush();
      await fixture.service.restore(
        BackupArchive(memberId: 1001, tables: _tables(), compositions: []),
      );
      expect(await fixture.store.readArchiveForAccount(1001), original);
      expect(fixture.controller.state.targetSenka, 3000);
      final restored = _raw(1001, 4200);
      await fixture.service.restore(BackupArchive.decode(_v2(restored)));
      expect(await fixture.store.readArchiveForAccount(1001), restored);
      expect(await fixture.store.readArchiveForAccount(2002), other);
      expect(fixture.controller.state.targetSenka, 4200);
      fixture.controller.setTargetSenka(4300);
      await fixture.controller.idle;
      expect((await fixture.store.loadForAccount(1001))!.targetSenka, 4300);
      final snapshotKey =
          'account.1001.senka.archive.v1.raw.${sha256.convert(utf8.encode(restored))}';
      expect(
        (await SharedPreferences.getInstance()).getString(snapshotKey),
        restored,
      );
    },
  );

  test(
    'settings and timers buffer until the imported state is ready',
    () async {
      late _Fixture fixture;
      Future<bool>? settingsResult;
      late String restored;
      fixture = await _Fixture.create(
        afterRestoreStage: (stage) async {
          if (stage != 'senka') return;
          settingsResult = fixture.controller.setBaseSenka(5);
          fixture.controller.setTargetSenka(4500);
          fixture.controller.refreshForCurrentTime();
          await fixture.controller.idle;
          expect(await fixture.store.readArchiveForAccount(1001), restored);
        },
      );
      addTearDown(fixture.close);
      await fixture.store.restoreArchiveForAccount(1001, _raw(1001, 3000));
      await fixture.controller.reloadForAccount(1001);
      final json = jsonDecode(_raw(1001, 4200)) as Map;
      json['days'] = {
        '2026-08-09': {'experience': 17, 'eo': 75},
      };
      restored = jsonEncode(json);
      await fixture.service.restore(BackupArchive.decode(_v2(restored)));
      expect(await settingsResult, isTrue);
      expect(fixture.controller.state.targetSenka, 4500);
      expect(fixture.controller.monthBaseSenka, 5);
      expect(fixture.controller.state.day(DateTime.utc(2026, 8, 9)).eo, 75);
      expect((await fixture.store.loadForAccount(1001))!.targetSenka, 4500);
    },
  );

  test(
    'failure after senka restore rolls back preferences, controller, logbook and backup',
    () async {
      final fixture = await _Fixture.create(
        afterRestoreStage: (stage) async {
          if (stage == 'senka') throw StateError('injected post-senka failure');
        },
      );
      addTearDown(fixture.close);
      final original = _raw(1001, 3000);
      await fixture.store.restoreArchiveForAccount(1001, original);
      await fixture.controller.reloadForAccount(1001);
      await fixture.database.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'old',
        level: 1,
      );
      await fixture.service.sync();
      final previousLive = fixture.port.live[1001]!;
      await expectLater(
        fixture.service.restore(BackupArchive.decode(_v2(_raw(1001, 4200)))),
        throwsStateError,
      );
      expect(await fixture.store.readArchiveForAccount(1001), original);
      expect(fixture.controller.state.targetSenka, 3000);
      expect(
        (await fixture.database.getRetirementRecords()).single['ship_name'],
        'old',
      );
      expect(fixture.port.live[1001], previousLive);
    },
  );

  test(
    'startup journal replay restores senka and reloads stale controller memory',
    () async {
      final fixture = await _Fixture.create(start: false);
      addTearDown(fixture.close);
      await fixture.store.restoreArchiveForAccount(1001, _raw(1001, 3000));
      await fixture.controller.reloadForAccount(1001);
      final restored = _raw(1001, 4200);
      final journal = File(
        '${fixture.directory.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}1001.yhb',
      );
      await journal.parent.create(recursive: true);
      await journal.writeAsBytes(
        BackupRestoreJournal(
          archive: BackupArchive.decode(_v2(restored)),
          requiresExternal: false,
        ).encode(),
        flush: true,
      );
      await fixture.service.start();
      await fixture.service.flush();
      expect(await fixture.store.readArchiveForAccount(1001), restored);
      expect(fixture.controller.state.targetSenka, 4200);
      expect(BackupArchive.decode(fixture.port.live[1001]!).senkaRaw, restored);
      expect(await journal.exists(), isFalse);
    },
  );

  test(
    'a rejected native senka import rolls all restore domains back',
    () async {
      final previousPlatform = SharedPreferencesStorePlatform.instance;
      final platform = _RejectImportPlatform();
      SharedPreferencesStorePlatform.instance = platform;
      SharedPreferences.resetStatic();
      final fixture = await _Fixture.create();
      addTearDown(() async {
        await fixture.close();
        SharedPreferencesStorePlatform.instance = previousPlatform;
        SharedPreferences.resetStatic();
      });
      final original = _raw(1001, 3000);
      await fixture.store.restoreArchiveForAccount(1001, original);
      await fixture.controller.reloadForAccount(1001);
      await fixture.database.insertRetirementRecord(
        timestamp: 1,
        type: '解体',
        shipType: '驱逐舰',
        shipName: 'old',
        level: 1,
      );
      await fixture.service.sync();
      final live = fixture.port.live[1001]!;
      final rejected = _raw(1001, 4200);
      platform.rejectRaw = rejected;
      await expectLater(
        fixture.service.restore(BackupArchive.decode(_v2(rejected))),
        throwsStateError,
      );
      expect(await fixture.store.readArchiveForAccount(1001), original);
      expect(fixture.controller.state.targetSenka, 3000);
      expect(
        (await fixture.database.getRetirementRecords()).single['ship_name'],
        'old',
      );
      expect(fixture.port.live[1001], live);
    },
  );

  test(
    'retrying startup recovery releases a barrier retained after failure',
    () async {
      var failOnce = true;
      final fixture = await _Fixture.create(
        start: false,
        afterRestoreStage: (stage) async {
          if (stage == 'senka' && failOnce) {
            failOnce = false;
            throw StateError('interrupted recovery');
          }
        },
      );
      addTearDown(fixture.close);
      await fixture.store.restoreArchiveForAccount(1001, _raw(1001, 3000));
      await fixture.controller.reloadForAccount(1001);
      final journal = File(
        '${fixture.directory.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}1001.yhb',
      );
      await journal.parent.create(recursive: true);
      await journal.writeAsBytes(
        BackupRestoreJournal(
          archive: BackupArchive.decode(_v2(_raw(1001, 4200))),
          requiresExternal: false,
        ).encode(),
        flush: true,
      );
      await expectLater(fixture.service.start(), throwsStateError);
      expect(fixture.controller.isArchiveRestoreActive(1001), isTrue);
      await fixture.service.recoverPendingRestores();
      expect(fixture.controller.isArchiveRestoreActive(1001), isFalse);
      fixture.controller.setTargetSenka(4500);
      await fixture.controller.idle;
      expect((await fixture.store.loadForAccount(1001))!.targetSenka, 4500);
    },
  );

  test(
    'cleaning a committed old journal keeps the new restore barrier active',
    () async {
      late _Fixture fixture;
      fixture = await _Fixture.create(
        afterRestoreStage: (stage) async {
          if (stage == 'senka') {
            expect(fixture.controller.isArchiveRestoreActive(1001), isTrue);
          }
        },
      );
      addTearDown(fixture.close);
      final original = _raw(1001, 3000);
      await fixture.store.restoreArchiveForAccount(1001, original);
      await fixture.controller.reloadForAccount(1001);
      await fixture.service.flush();
      final journal = File(
        '${fixture.directory.path}${Platform.pathSeparator}record_backup_restore${Platform.pathSeparator}1001.yhb',
      );
      await journal.parent.create(recursive: true);
      final bytes = BackupRestoreJournal(
        archive: BackupArchive.decode(_v2(original)),
        requiresExternal: false,
      ).encode();
      await journal.writeAsBytes(bytes, flush: true);
      await File(
        '${journal.path}.committed',
      ).writeAsString(sha256.convert(bytes).toString(), flush: true);
      await fixture.service.restore(
        BackupArchive.decode(_v2(_raw(1001, 4200))),
      );
      expect(fixture.controller.isArchiveRestoreActive(1001), isFalse);
      expect(fixture.controller.state.targetSenka, 4200);
    },
  );

  test(
    'raw backup rejects the wrong owner and anonymous global legacy remains unassigned',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesSenkaStore(prefs);
      await prefs.setString(
        'senka.archive.v1',
        jsonEncode({'memberId': 0, 'monthKey': '2026-08', 'targetSenka': 5000}),
      );
      expect(await store.readArchiveForAccount(1001), isNull);
      await expectLater(
        store.restoreArchiveForAccount(1001, _raw(2002, 3000)),
        throwsFormatException,
      );
      await prefs.setString(
        'account.1001.senka.archive.v1',
        jsonEncode({'memberId': 0, 'monthKey': '2026-08', 'targetSenka': 3000}),
      );
      final owned =
          jsonDecode((await store.readArchiveForAccount(1001))!) as Map;
      expect(owned['memberId'], 1001);
      expect(owned['targetSenka'], 3000);
    },
  );
}

class _Fixture {
  _Fixture(
    this.directory,
    this.database,
    this.session,
    this.store,
    this.controller,
    this.port,
    this.service,
  );
  final Directory directory;
  final LogbookDatabase database;
  final AccountSession session;
  final SharedPreferencesSenkaStore store;
  final SenkaController controller;
  final _MemoryPort port;
  final RecordBackupService service;

  static Future<_Fixture> create({
    bool start = true,
    Future<void> Function(String)? afterRestoreStage,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'senka-record-backup-',
    );
    final database = await LogbookDatabase.openForTesting();
    final session = AccountSession(initialMemberId: 1001);
    final store = SharedPreferencesSenkaStore(
      await SharedPreferences.getInstance(),
      accountSession: session,
    );
    final controller = SenkaController(
      store: store,
      accountSession: session,
      now: () => DateTime.utc(2026, 8, 10, 3),
    );
    await controller.initialize();
    final port = _MemoryPort();
    final service = RecordBackupService(
      session: session,
      port: port,
      enabledStore: _EnabledStore(),
      compositionStore: FileCompositionRecordStore(
        rootDirectory: () async => directory,
      ),
      databaseFor: (_) => database,
      installationId: 'senka-backup-test',
      senkaStore: store,
      senkaController: controller,
      afterRestoreStage: afterRestoreStage,
    );
    final fixture = _Fixture(
      directory,
      database,
      session,
      store,
      controller,
      port,
      service,
    );
    if (start) {
      await service.start();
      await service.flush();
    }
    return fixture;
  }

  Future<void> close() async {
    await service.close();
    controller.dispose();
    session.dispose();
    await database.close();
    final target = directory.absolute;
    if (!target.path.startsWith(Directory.systemTemp.absolute.path)) {
      throw StateError('Unexpected temp path');
    }
    await target.delete(recursive: true);
  }
}

class _EnabledStore implements RecordBackupEnabledStore {
  @override
  Future<bool> load() async => true;
  @override
  Future<void> save(bool enabled) async {}
}

class _MemoryPort implements BackupDocumentPort {
  final live = <int, Uint8List>{};
  @override
  Future<bool> hasDirectory() async => true;
  @override
  Future<bool> chooseDirectory() async => true;
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
      'share';
  @override
  Future<String> launchShareFile(String token) async => token;
  @override
  Future<void> discardShareFile(String token) async {}
  @override
  Future<String?> saveFile(String name, Uint8List bytes) async => 'save';
  @override
  Future<void> completeSavedFile(String token) async {}
  @override
  Future<void> discardSavedFile(String token) async {}
  @override
  Future<Uint8List?> pickImport() async => null;
}

class _RejectImportPlatform extends InMemorySharedPreferencesStore {
  _RejectImportPlatform() : super.empty();
  String? rejectRaw;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (value == rejectRaw && key == 'flutter.account.1001.senka.archive.v1') {
      rejectRaw = null;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
