/// Pure helpers that keep resource-trend data small enough for cheap
/// chart rendering while preserving the visible shape of the data.
library;

const List<String> resourceTrendKeys = <String>[
  'fuel',
  'ammo',
  'steel',
  'bauxite',
  'bucket',
  'devmat',
  'blowtorch',
  'screw',
];

double _value(Map<String, dynamic> row, String key) =>
    (row[key] as num?)?.toDouble() ?? 0;

bool _sameValues(Map<String, dynamic> a, Map<String, dynamic> b) {
  for (final key in resourceTrendKeys) {
    if (_value(a, key) != _value(b, key)) return false;
  }
  return true;
}

double _deviation(Map<String, dynamic> base, Map<String, dynamic> row) {
  var total = 0.0;
  for (final key in resourceTrendKeys) {
    total += (_value(base, key) - _value(row, key)).abs();
  }
  return total;
}

/// Shrinks a list of resource snapshot rows for chart display.
///
/// Consecutive rows with identical resource values are collapsed first. When
/// the remaining rows still exceed [maxPoints], rows are grouped into buckets
/// and each bucket contributes its first row plus the row with the largest
/// total deviation (across all eight resources), which preserves spikes and
/// dips without keeping every sample. The first and last rows are always kept.
List<Map<String, dynamic>> downsampleResourceLogs(
  List<Map<String, dynamic>> rows, {
  int maxPoints = 500,
}) {
  if (rows.isEmpty) return const <Map<String, dynamic>>[];
  if (maxPoints < 3) maxPoints = 3;

  final deduped = <Map<String, dynamic>>[rows.first];
  var removedDuplicates = false;
  for (final row in rows.skip(1)) {
    if (_sameValues(deduped.last, row)) {
      removedDuplicates = true;
    } else {
      deduped.add(row);
    }
  }
  if (!removedDuplicates && deduped.length <= maxPoints) return rows;
  if (deduped.length <= maxPoints) return deduped;

  final result = <Map<String, dynamic>>[deduped.first];
  final bucketCount = maxPoints - 2;
  final step = (deduped.length - 1) / bucketCount;

  for (var bucket = 0; bucket < bucketCount; bucket++) {
    final start = (bucket * step).floor() + 1;
    if (start >= deduped.length) break;
    final end = (((bucket + 1) * step).floor() + 1).clamp(
      start + 1,
      deduped.length,
    );

    final base = deduped[start];
    var bestIndex = start;
    var bestDeviation = 0.0;
    for (var i = start; i < end; i++) {
      final deviation = _deviation(base, deduped[i]);
      if (deviation > bestDeviation) {
        bestDeviation = deviation;
        bestIndex = i;
      }
    }
    result.add(deduped[bestIndex]);
  }

  if (!identical(result.last, deduped.last)) result.add(deduped.last);
  return result;
}

/// Incrementally downsamples a large, ordered resource result set without
/// retaining every database row in memory.
final class ResourceTrendStreamSampler {
  ResourceTrendStreamSampler({required this.expectedRows, this.maxPoints = 500})
    : assert(expectedRows >= 0),
      assert(maxPoints >= 3);

  final int expectedRows;
  final int maxPoints;
  final List<Map<String, dynamic>> _result = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _smallRows = <Map<String, dynamic>>[];
  Map<String, dynamic>? _pending;
  Map<String, dynamic>? _bucketBase;
  Map<String, dynamic>? _bucketBest;
  double _bucketBestDeviation = 0;
  int? _activeBucket;
  int _receivedRows = 0;

  void add(Map<String, dynamic> row) {
    if (expectedRows <= maxPoints) {
      _smallRows.add(row);
      _receivedRows += 1;
      return;
    }

    final previous = _pending;
    if (previous != null) {
      final previousIndex = _receivedRows - 1;
      if (previousIndex == 0) {
        _result.add(previous);
      } else {
        _addIntermediate(previous, previousIndex);
      }
    }
    _pending = row;
    _receivedRows += 1;
  }

  List<Map<String, dynamic>> finish() {
    if (expectedRows <= maxPoints) {
      return downsampleResourceLogs(_smallRows, maxPoints: maxPoints);
    }
    final last = _pending;
    if (last == null) return const <Map<String, dynamic>>[];
    if (_receivedRows == 1) return <Map<String, dynamic>>[last];

    _flushBucket();
    if (_result.isEmpty || !identical(_result.last, last)) {
      _result.add(last);
    }
    return List<Map<String, dynamic>>.unmodifiable(_result);
  }

  void _addIntermediate(Map<String, dynamic> row, int rowIndex) {
    final bucketCount = maxPoints - 2;
    final interiorRows = (expectedRows - 2).clamp(1, 1 << 31);
    final bucket = (((rowIndex - 1) * bucketCount) ~/ interiorRows).clamp(
      0,
      bucketCount - 1,
    );
    if (_activeBucket != bucket) {
      _flushBucket();
      _activeBucket = bucket;
      _bucketBase = row;
      _bucketBest = row;
      _bucketBestDeviation = 0;
      return;
    }

    final deviation = _deviation(_bucketBase!, row);
    if (deviation > _bucketBestDeviation) {
      _bucketBest = row;
      _bucketBestDeviation = deviation;
    }
  }

  void _flushBucket() {
    final best = _bucketBest;
    if (best != null) _result.add(best);
    _activeBucket = null;
    _bucketBase = null;
    _bucketBest = null;
    _bucketBestDeviation = 0;
  }
}
