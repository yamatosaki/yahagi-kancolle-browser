import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_privacy_policy.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yahagi-diagnostics-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('batches disk work for events sharing an existing segment', () async {
    final first = _event(0);
    await DiagnosticStorage(directory: directory).appendAll([first]);
    final events = List.generate(64, (index) => _event(index + 1));
    final io = _CountingIo();

    await IOOverrides.runWithIOOverrides(() async {
      await DiagnosticStorage(
        directory: Directory(directory.path),
      ).appendAll(events);
    }, io);

    expect(
      io.writes,
      1,
      reason: 'lists: ${io.directoryLists}, lengths: ${io.lengthReads}',
    );
    expect(io.directoryLists, lessThanOrEqualTo(3));
    expect(io.lengthReads, lessThanOrEqualTo(2));
    expect(
      await DiagnosticStorage(directory: directory).readRecords().toList(),
      [first, ...events].map((event) => event.toJson()).toList(),
    );
  });

  test('batches disk writes once per destination segment', () async {
    final events = List.generate(8, _event);
    final segmentBytes = events.first.estimatedEncodedBytes * 2;
    final io = _CountingIo();

    await IOOverrides.runWithIOOverrides(() async {
      await DiagnosticStorage(
        directory: Directory(directory.path),
        maxSegmentBytes: segmentBytes,
      ).appendAll(events);
    }, io);

    expect(
      io.writes,
      4,
      reason: 'lists: ${io.directoryLists}, lengths: ${io.lengthReads}',
    );
    expect(io.directoryLists, lessThanOrEqualTo(3));
    expect(io.lengthReads, lessThanOrEqualTo(5));
    expect(await _segmentContents(directory), [
      for (var index = 0; index < events.length; index += 2)
        _line(events[index]) + _line(events[index + 1]),
    ]);
  });

  test('uses UTF-8 bytes and permits an exact segment fit', () async {
    final event = _event(0, state: '日本語の画面描画完了' * 8);
    final line = _line(event);
    final lineBytes = utf8.encode(line).length;
    final storage = DiagnosticStorage(
      directory: directory,
      maxSegmentBytes: lineBytes * 2,
    );

    await storage.appendAll([event, event, event]);

    expect(await _segmentContents(directory), [line + line, line]);
    expect(
      await Future.wait(_segmentFiles(directory).map((file) => file.length())),
      [lineBytes * 2, lineBytes],
    );
  });

  test(
    'does not retry a failed segment write and allows later appends',
    () async {
      final events = List.generate(5, _event);
      final io = _CountingIo()..failWriteAt = 2;

      await IOOverrides.runWithIOOverrides(() async {
        final storage = DiagnosticStorage(
          directory: Directory(directory.path),
          maxSegmentBytes: events.first.estimatedEncodedBytes * 2,
        );
        await expectLater(
          storage.appendAll(events),
          throwsA(isA<FileSystemException>()),
        );
        expect(io.writes, 2);
        expect(await _segmentContents(directory), [
          _line(events[0]) + _line(events[1]),
        ]);

        io.failWriteAt = null;
        await storage.appendAll([_event(8)]);
      }, io);

      expect(io.writes, 3);
      expect(
        await DiagnosticStorage(directory: directory).readRecords().toList(),
        [events[0].toJson(), events[1].toJson(), _event(8).toJson()],
      );
    },
  );

  test('keeps an oversized event whole and rotates before the next', () async {
    final oversized = _event(0, state: '描画' * 80);
    final next = _event(1);
    final storage = DiagnosticStorage(
      directory: directory,
      maxSegmentBytes: next.estimatedEncodedBytes,
    );

    await storage.appendAll([oversized, next]);
    await storage.appendAll([next]);

    expect(await _segmentContents(directory), [
      _line(oversized),
      _line(next),
      _line(next),
    ]);
  });

  test(
    'persists only the valid prefix if a later record fails validation',
    () async {
      final prefix = [_event(0), _event(1), _event(2)];
      final invalid = DiagnosticEvent.lifecycle(
        occurredAt: _InvalidTimestamp(),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      );
      final storage = DiagnosticStorage(
        directory: directory,
        maxSegmentBytes: prefix.first.estimatedEncodedBytes * 2,
      );

      await expectLater(
        storage.appendAll([...prefix, invalid, _event(3)]),
        throwsA(isA<DiagnosticPrivacyViolation>()),
      );

      expect(await _segmentContents(directory), [
        _line(prefix[0]) + _line(prefix[1]),
        _line(prefix[2]),
      ]);
      await storage.appendAll([_event(4)]);
      expect(await storage.readRecords().toList(), [
        ...prefix.map((event) => event.toJson()),
        _event(4).toJson(),
      ]);
      await storage.clear();
      expect(await _segmentContents(directory), isEmpty);
      await storage.appendAll([_event(5)]);
      expect(await _segmentContents(directory), [_line(_event(5))]);
    },
  );

  test('a successful batch prunes expired and excess segments', () async {
    final events = List.generate(6, _event);
    final segmentBytes = events.first.estimatedEncodedBytes * 2;
    final expired = File(
      '${directory.path}${Platform.pathSeparator}diagnostic-0-0.jsonl',
    );
    await expired.writeAsString(_line(_event(8)) + _line(_event(9)));
    await expired.setLastModified(
      DateTime.now().subtract(const Duration(days: 8)),
    );
    final storage = DiagnosticStorage(
      directory: directory,
      maxSegmentBytes: segmentBytes,
      maxTotalBytes: segmentBytes * 2,
    );

    await storage.appendAll(events);

    expect(await expired.exists(), isFalse);
    expect(await storage.readRecords().toList(), [
      for (final event in events.skip(2)) event.toJson(),
    ]);
    expect((await storage.inspect()).totalBytes, segmentBytes * 2);
  });

  test('rotates segments and keeps total bytes bounded', () async {
    final storage = DiagnosticStorage(
      directory: directory,
      maxTotalBytes: 1400,
      maxSegmentBytes: 400,
      retention: const Duration(days: 7),
      now: () => DateTime.utc(2026, 8, 13),
    );

    for (var index = 0; index < 80; index++) {
      await storage.appendAll(<DiagnosticEvent>[
        DiagnosticEvent.webViewState(
          occurredAt: DateTime.utc(2026, 8, 13, 0, 0, index),
          state: 'pageReady',
          durationMs: index,
        ),
      ]);
    }

    final state = await storage.inspect();
    expect(state.totalBytes, lessThanOrEqualTo(1400));
    expect(state.segmentCount, greaterThan(1));
  });

  test('removes segments older than retention', () async {
    var now = DateTime.utc(2026, 8, 1);
    final storage = DiagnosticStorage(
      directory: directory,
      maxTotalBytes: 4096,
      maxSegmentBytes: 128,
      retention: const Duration(days: 7),
      now: () => now,
    );
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: now,
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    for (final file in directory.listSync().whereType<File>()) {
      await file.setLastModified(now);
    }
    now = DateTime.utc(2026, 8, 13);

    await storage.prune();

    expect((await storage.inspect()).segmentCount, 0);
  });

  test('reads valid lines before a corrupt tail', () async {
    final storage = DiagnosticStorage(
      directory: directory,
      maxTotalBytes: 4096,
      maxSegmentBytes: 4096,
      now: () => DateTime.utc(2026, 8, 13),
    );
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    final segment = directory.listSync().whereType<File>().single;
    await segment.writeAsString('{broken', mode: FileMode.append, flush: true);

    final records = await storage.readRecords().toList();

    expect(records, hasLength(1));
    expect(records.single['type'], 'lifecycle');
  });
}

DiagnosticEvent _event(int index, {String state = 'pageReady'}) =>
    DiagnosticEvent.webViewState(
      occurredAt: DateTime.utc(2026, 8, 13),
      state: state,
      durationMs: index,
    );

String _line(DiagnosticEvent event) => '${jsonEncode(event.toJson())}\n';

List<File> _segmentFiles(Directory directory) =>
    directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.jsonl'))
        .toList()
      ..sort((first, second) => first.path.compareTo(second.path));

Future<List<String>> _segmentContents(Directory directory) =>
    Future.wait(_segmentFiles(directory).map((file) => file.readAsString()));

// Event fields are validated at construction; timestamps are validated on append.
class _InvalidTimestamp implements DateTime {
  @override
  DateTime toUtc() => this;

  @override
  String toIso8601String() => 'api_token=TEST_ONLY';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Count storage's filesystem calls while delegating every operation to real files.
final class _CountingIo extends IOOverrides {
  int directoryLists = 0;
  int lengthReads = 0;
  int writes = 0;
  int? failWriteAt;

  @override
  Directory createDirectory(String path) =>
      _CountingDirectory(super.createDirectory(path), this);

  @override
  File createFile(String path) => _CountingFile(super.createFile(path), this);

  void beforeWrite() {
    writes++;
    if (writes == failWriteAt) {
      throw const FileSystemException('Injected diagnostic write failure');
    }
  }
}

class _CountingDirectory implements Directory {
  _CountingDirectory(this.delegate, this.io);

  final Directory delegate;
  final _CountingIo io;

  @override
  String get path => delegate.path;

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<Directory> create({bool recursive = false}) =>
      delegate.create(recursive: recursive);

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    io.directoryLists++;
    return delegate
        .list(recursive: recursive, followLinks: followLinks)
        .map((entity) => entity is File ? io.createFile(entity.path) : entity);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingFile implements File {
  _CountingFile(this.delegate, this.io);

  final File delegate;
  final _CountingIo io;

  @override
  String get path => delegate.path;

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<int> length() {
    io.lengthReads++;
    return delegate.length();
  }

  @override
  Future<DateTime> lastModified() => delegate.lastModified();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      delegate.delete(recursive: recursive);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    io.beforeWrite();
    return delegate.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    io.beforeWrite();
    return delegate.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
