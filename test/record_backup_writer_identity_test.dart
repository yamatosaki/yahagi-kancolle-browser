import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/backup/record_backup.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';

Map<String, List<Map<String, Object?>>> _tables(List<String> ships) => {
  for (final table in LogbookDatabase.backupTables)
    table: table == 'retirement_logs'
        ? [
            for (var index = 0; index < ships.length; index++)
              {'id': index + 1, 'ship_name': ships[index]},
          ]
        : <Map<String, Object?>>[],
};

BackupArchive _empty() =>
    BackupArchive(memberId: 7, tables: _tables([]), compositions: []);

BackupArchive _roundTrip(BackupArchive archive) =>
    BackupArchive.decode(archive.encode());

Uint8List _editPayload(
  BackupArchive archive,
  void Function(Map<String, dynamic>) edit,
) {
  final envelope = jsonDecode(utf8.decode(archive.encode())) as Map;
  final payload =
      jsonDecode(
            utf8.decode(
              gzip.decode(base64Decode(envelope['payload'] as String)),
            ),
          )
          as Map<String, dynamic>;
  edit(payload);
  final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
  envelope['payload'] = base64Encode(compressed);
  envelope['sha256'] = sha256.convert(compressed).toString();
  return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
}

void main() {
  test(
    'returning backup writers update their own rows after codec round trips',
    () {
      var archive = _roundTrip(
        _empty().merge(_tables(['A original']), [], writerId: 'A'),
      );
      archive = _roundTrip(
        archive.merge(_tables(['B original']), [], writerId: 'B'),
      );
      archive = _roundTrip(
        archive.merge(_tables(['A edited', 'A new']), [], writerId: 'A'),
      );
      archive = _roundTrip(
        archive.merge(_tables(['B edited', 'B new']), [], writerId: 'B'),
      );
      expect(
        archive.tables['retirement_logs']!.map((row) => row['ship_name']),
        unorderedEquals(['A edited', 'A new', 'B edited', 'B new']),
      );
    },
  );

  test('legacy current-writer mappings survive another writer and return', () {
    final initial = _empty().merge(_tables(['A']), [], writerId: 'A');
    final legacy = BackupArchive.decode(
      _editPayload(initial, (payload) => payload.remove('writerRowIds')),
    );
    final switched = _roundTrip(
      legacy.merge(_tables(['B']), [], writerId: 'B'),
    );
    final returned = _roundTrip(
      switched.merge(_tables(['A']), [], writerId: 'A'),
    );
    expect(returned.tables['retirement_logs'], hasLength(2));
  });

  test(
    'three writers retain independent byte-identical events across returns',
    () {
      var archive = _empty();
      for (var cycle = 0; cycle < 4; cycle++) {
        for (final writer in ['A', 'B', 'C']) {
          archive = _roundTrip(
            archive.merge(_tables(['same event']), [], writerId: writer),
          );
        }
      }
      expect(archive.tables['retirement_logs'], hasLength(3));
    },
  );

  test(
    'per-writer mappings reject dangling, duplicate and noncanonical IDs',
    () {
      final archive = _empty().merge(_tables(['A', 'B']), [], writerId: 'A');
      for (final mapping in [
        {'1': 999},
        {'1': 1, '2': 1},
        {'0': 1},
        {'01': 1},
        {'-1': 1},
      ]) {
        final bytes = _editPayload(archive, (payload) {
          payload['writerRowIds'] = {
            'other-writer': {'retirement_logs': mapping},
          };
        });
        expect(() => BackupArchive.decode(bytes), throwsFormatException);
      }
    },
  );

  test('per-writer mappings reject invalid writers and unknown tables', () {
    final archive = _empty().merge(_tables(['A']), [], writerId: 'A');
    for (final mappings in [
      {'': <String, Object?>{}},
      {'x' * 101: <String, Object?>{}},
      {
        'A': {
          'unknown_table': {'1': 1},
        },
      },
      {'A': 'not a mapping'},
      {
        'A': {
          'retirement_logs': {'1': 2},
        },
      },
    ]) {
      final bytes = _editPayload(archive, (payload) {
        payload['writerRowIds'] = mappings;
      });
      expect(() => BackupArchive.decode(bytes), throwsFormatException);
    }
  });

  test(
    'writer history limits fail without silently dropping existing writers',
    () {
      final archive = _empty().merge(_tables(['A']), [], writerId: 'A');
      final bytes = _editPayload(archive, (payload) {
        payload['writerRowIds'] = {
          for (var index = 0; index <= 256; index++)
            '$index': <String, Object?>{},
        };
      });
      expect(() => BackupArchive.decode(bytes), throwsFormatException);
      final tooMany = BackupArchive(
        memberId: 7,
        tables: _tables([]),
        compositions: [],
        writerRowIds: {for (var index = 0; index <= 256; index++) '$index': {}},
      );
      expect(tooMany.encode, throwsFormatException);
    },
  );

  test('current and historical writer projections cannot disagree', () {
    final archive = _empty().merge(_tables(['A', 'B']), [], writerId: 'A');
    final bytes = _editPayload(archive, (payload) {
      payload['writerRowIds'] = {
        'A': {
          'retirement_logs': {'1': 2, '2': 1},
        },
      };
    });
    expect(() => BackupArchive.decode(bytes), throwsFormatException);
  });
}
