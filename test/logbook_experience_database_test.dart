import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/backup/record_backup.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_experience_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'queued experience writes preserve ship order and ignore retries',
    () async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final experience = database.changesFor(LogbookChangeCategory.experience);
      final battles = database.changesFor(LogbookChangeCategory.battle);
      final writes = Future.wait([
        database.insertExperienceRecord(_record('sortie-a', day: 1)),
        database.insertExperienceRecord(_record('sortie-a', day: 3)),
        database.insertExperienceRecord(
          _record('practice-a', isPractice: true),
        ),
        database.insertExperienceRecord(_record('sortie-b')),
      ]);
      final snapshot = await database.backupSnapshot();
      await writes;

      expect(snapshot[LogbookDatabase.experienceTable], hasLength(3));
      expect(experience.value, 3);
      expect(battles.value, 0);
      final records = await database.getExperienceRecords(limit: 2);
      expect(records.map((record) => record.eventKey), [
        'sortie-b',
        'practice-a',
      ]);
      expect(records.last.isPractice, isTrue);
      expect(records.last.battles, 1);

      final first = (await database.getExperienceRecords(offset: 2)).single;
      expect(first.eventKey, 'sortie-a');
      expect(first.completedAt, DateTime.utc(2026, 11, 1));
      expect(first.incomplete, isTrue);
      expect(first.ships.map((ship) => ship.ownedShipId), [30, 10, 20]);
      expect(first.ships.map((ship) => ship.experience), [120, 0, null]);
      expect(first.ships.last.retreated, isTrue);
    },
  );

  test(
    'experience backup round trips and rejects malformed ship data',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'yahagi-exp-restore',
      );
      addTearDown(() => folder.delete(recursive: true));
      final source = await LogbookDatabase.openForTesting(
        path: '${folder.path}${Platform.pathSeparator}source.db',
      );
      addTearDown(source.close);
      final restored = await LogbookDatabase.openForTesting(
        path: '${folder.path}${Platform.pathSeparator}restored.db',
      );
      addTearDown(restored.close);
      await source.insertExperienceRecord(_record('experience-a'));
      expect(await restored.getExperienceRecords(), isEmpty);

      final archive = BackupArchive(
        memberId: 10,
        tables: await source.backupSnapshot(),
        compositions: const [],
      );
      final decoded = BackupArchive.decode(archive.encode());
      await restored.restoreSnapshot(decoded.tables);
      final record = (await restored.getExperienceRecords()).single;
      expect(record.eventKey, 'experience-a');
      expect(record.ships.map((ship) => ship.experience), [120, 0, null]);

      const table = LogbookDatabase.experienceTable;
      final invalidTables = {
        ...decoded.tables,
        table: [
          {
            ...decoded.tables[table]!.single,
            'ships_json': '[{"experience":-1}]',
          },
        ],
      };
      await expectLater(
        restored.restoreSnapshot(invalidTables),
        throwsFormatException,
      );
      expect(
        (await restored.getExperienceRecords()).single.eventKey,
        'experience-a',
      );
      await restored.clearAll();
      expect(await restored.getExperienceRecords(), isEmpty);
    },
  );

  test('archive merge follows the stable experience event key', () async {
    const table = LogbookDatabase.experienceTable;
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertExperienceRecord(_record('same-event'));
    final initial = await database.backupSnapshot();
    final archived = initial[table]!.single;
    final archive = BackupArchive(
      memberId: 10,
      tables: initial,
      compositions: const [],
      writerId: 'writer-a',
    );
    final merged = archive.merge(
      {
        ...initial,
        table: [
          {...archived, 'id': 77},
          {..._record('different-event').toRow(), 'id': archived['id']},
        ],
      },
      const [],
      writerId: 'writer-b',
    );
    final decoded = BackupArchive.decode(merged.encode());
    expect(decoded.rowIds, isNot(contains(table)));
    expect(
      decoded.tables[table]!.map((row) => row['event_key']),
      unorderedEquals(['same-event', 'different-event']),
    );
    expect(
      decoded.tables[table]!.firstWhere(
        (row) => row['event_key'] == 'same-event',
      )['id'],
      archived['id'],
    );
  });

  test('v12 database upgrade preserves existing logs', () async {
    final folder = await Directory.systemTemp.createTemp('yahagi-exp-v12');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}${Platform.pathSeparator}logbook.db';
    final old = await LogbookDatabase.openForTesting(path: path);
    await old.insertRetirementRecord(
      timestamp: 123,
      type: '解体',
      shipType: '驱逐舰',
      shipName: '三日月',
      level: 1,
    );
    final raw = await old.database;
    await raw.execute('DROP TABLE ${LogbookDatabase.experienceTable}');
    await raw.execute('PRAGMA user_version = 12');
    await old.close();

    final upgraded = await LogbookDatabase.openForTesting(path: path);
    addTearDown(upgraded.close);
    expect((await upgraded.getRetirementRecords()).single['ship_name'], '三日月');
    expect(await upgraded.getExperienceRecords(), isEmpty);
    await upgraded.insertExperienceRecord(_record('after-upgrade'));
    expect(
      (await upgraded.getExperienceRecords()).single.eventKey,
      'after-upgrade',
    );
  });
}

LogbookExperienceRecord _record(
  String key, {
  int day = 2,
  bool isPractice = false,
}) => LogbookExperienceRecord(
  eventKey: key,
  completedAt: DateTime.utc(2026, 11, day),
  isPractice: isPractice,
  mapAreaId: isPractice ? 0 : 5,
  mapInfoNo: isPractice ? 0 : 3,
  deckId: 1,
  battles: isPractice ? 1 : 2,
  incomplete: true,
  ships: const [
    LogbookExperienceShip(
      ownedShipId: 30,
      masterShipId: 1,
      name: '矢矧',
      fleetId: 1,
      experience: 120,
    ),
    LogbookExperienceShip(
      ownedShipId: 10,
      masterShipId: 2,
      name: '最上',
      fleetId: 1,
      experience: 0,
    ),
    LogbookExperienceShip(
      ownedShipId: 20,
      masterShipId: 3,
      name: '夕立',
      fleetId: 2,
      experience: null,
      retreated: true,
    ),
  ],
);
