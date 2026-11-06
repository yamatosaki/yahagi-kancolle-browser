import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'diagnostic_event.dart';
import 'diagnostic_privacy_policy.dart';

abstract interface class DiagnosticSink {
  Future<void> appendAll(List<DiagnosticEvent> events);
}

final class DiagnosticStorageState {
  const DiagnosticStorageState({
    required this.totalBytes,
    required this.segmentCount,
    this.oldestRecordAt,
  });

  final int totalBytes;
  final int segmentCount;
  final DateTime? oldestRecordAt;
}

final class DiagnosticStorage implements DiagnosticSink {
  DiagnosticStorage({
    required this.directory,
    this.maxTotalBytes = 10 * 1024 * 1024,
    this.maxSegmentBytes = 2 * 1024 * 1024,
    this.retention = const Duration(days: 7),
    DateTime Function()? now,
  }) : assert(maxTotalBytes > 0),
       assert(maxSegmentBytes > 0),
       _now = now ?? DateTime.now;

  final Directory directory;
  final int maxTotalBytes;
  final int maxSegmentBytes;
  final Duration retention;
  final DateTime Function() _now;
  final DiagnosticPrivacyPolicy _policy = DiagnosticPrivacyPolicy.v1();
  int _sequence = 0;

  @override
  Future<void> appendAll(List<DiagnosticEvent> events) async {
    if (events.isEmpty) return;
    await directory.create(recursive: true);
    File? file;
    var segmentBytes = 0;
    var segmentExists = false;
    final pending = BytesBuilder(copy: false);

    Future<void> writePending() async {
      if (pending.isEmpty) return;
      await file!.writeAsBytes(
        pending.takeBytes(),
        mode: FileMode.append,
        flush: false,
      );
    }

    try {
      for (final event in events) {
        final json = event.toJson();
        _policy.validateRecord(json);
        final bytes = utf8.encode('${jsonEncode(json)}\n');
        if (file == null) {
          file = await _currentSegment();
          segmentExists = await file.exists();
          if (segmentExists) segmentBytes = await file.length();
        }
        if (segmentExists && segmentBytes + bytes.length > maxSegmentBytes) {
          await writePending();
          file = _newSegment();
          segmentBytes = 0;
        }
        pending.add(bytes);
        segmentBytes += bytes.length;
        segmentExists = true;
      }
    } finally {
      // Preserve the valid prefix if validation of a later event fails.
      await writePending();
    }
    await prune();
  }

  Future<DiagnosticStorageState> inspect() async {
    if (!await directory.exists()) {
      return const DiagnosticStorageState(totalBytes: 0, segmentCount: 0);
    }
    final files = await _segments();
    var total = 0;
    DateTime? oldest;
    for (final file in files) {
      total += await file.length();
      final modified = await file.lastModified();
      if (oldest == null || modified.isBefore(oldest)) oldest = modified;
    }
    return DiagnosticStorageState(
      totalBytes: total,
      segmentCount: files.length,
      oldestRecordAt: oldest,
    );
  }

  Future<void> prune() async {
    if (!await directory.exists()) return;
    final cutoff = _now().toUtc().subtract(retention);
    var files = await _segments();
    for (final file in files) {
      if ((await file.lastModified()).toUtc().isBefore(cutoff)) {
        await file.delete();
      }
    }
    files = await _segments();
    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    for (final file in files) {
      if (total <= maxTotalBytes) break;
      final length = await file.length();
      await file.delete();
      total -= length;
    }
  }

  Stream<Map<String, Object?>> readRecords({bool newestFirst = false}) async* {
    final files = await _segments();
    final ordered = newestFirst ? files.reversed : files;
    for (final file in ordered) {
      final lines = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is! Map) continue;
          final record = Map<String, Object?>.from(decoded);
          _policy.validateRecord(record);
          yield record;
        } on FormatException {
          break;
        } on DiagnosticPrivacyViolation {
          rethrow;
        }
      }
    }
  }

  Future<void> clear() async {
    if (!await directory.exists()) return;
    for (final file in await _segments()) {
      await file.delete();
    }
  }

  Future<File> _currentSegment() async {
    final files = await _segments();
    if (files.isEmpty) return _newSegment();
    return files.last;
  }

  File _newSegment() {
    final timestamp = _now().toUtc().microsecondsSinceEpoch;
    return File(
      '${directory.path}${Platform.pathSeparator}diagnostic-$timestamp-${_sequence++}.jsonl',
    );
  }

  Future<List<File>> _segments() async {
    if (!await directory.exists()) return <File>[];
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();
    files.sort((first, second) => first.path.compareTo(second.path));
    return files;
  }
}
