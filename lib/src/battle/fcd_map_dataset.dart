import 'dart:convert';

import 'battle_node_label_resolver.dart';

final class FcdMapVersion implements Comparable<FcdMapVersion> {
  const FcdMapVersion._(this.year, this.month, this.day, this.revision);

  factory FcdMapVersion.parse(String value) {
    final match = RegExp(
      r'^(\d{4})/(\d{2})/(\d{2})/(\d{2})$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid FCD map version: $value');
    }
    final parts = List<int>.generate(
      4,
      (index) => int.parse(match.group(index + 1)!),
    );
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2]) {
      throw FormatException('Invalid FCD map version date: $value');
    }
    return FcdMapVersion._(parts[0], parts[1], parts[2], parts[3]);
  }

  final int year;
  final int month;
  final int day;
  final int revision;

  @override
  int compareTo(FcdMapVersion other) {
    final own = <int>[year, month, day, revision];
    final theirs = <int>[other.year, other.month, other.day, other.revision];
    for (var index = 0; index < own.length; index++) {
      final result = own[index].compareTo(theirs[index]);
      if (result != 0) return result;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is FcdMapVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(year, month, day, revision);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}/'
      '${month.toString().padLeft(2, '0')}/'
      '${day.toString().padLeft(2, '0')}/'
      '${revision.toString().padLeft(2, '0')}';
}

final class FcdMapDataset implements BattleNodeLabelResolver {
  const FcdMapDataset._({
    required this.version,
    required this.rawJson,
    required this.mapCount,
    required this.routeCount,
    required this.labels,
  });

  factory FcdMapDataset.empty() => const FcdMapDataset._(
    version: FcdMapVersion._(0, 0, 0, 0),
    rawJson: '',
    mapCount: 0,
    routeCount: 0,
    labels: <String, String>{},
  );

  factory FcdMapDataset.parse(
    String rawJson, {
    int maxBytes = 1024 * 1024,
    int minimumMapCount = 50,
  }) {
    if (utf8.encode(rawJson).length > maxBytes) {
      throw const FormatException('FCD map data exceeds the size limit');
    }
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('FCD map root must be an object');
    }
    final meta = decoded['meta'];
    if (meta is! Map<String, dynamic> || meta['name'] != 'map') {
      throw const FormatException('FCD map metadata is invalid');
    }
    final versionValue = meta['version'];
    if (versionValue is! String) {
      throw const FormatException('FCD map version is missing');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic> || data.length < minimumMapCount) {
      throw const FormatException('FCD map data is missing');
    }

    final labels = <String, String>{};
    var routeCount = 0;
    final mapPattern = RegExp(r'^[1-9]\d*-[1-9]\d*$');
    final routePattern = RegExp(r'^\d+$');
    for (final mapEntry in data.entries) {
      if (!mapPattern.hasMatch(mapEntry.key) ||
          mapEntry.value is! Map<String, dynamic>) {
        throw FormatException('Invalid FCD map entry: ${mapEntry.key}');
      }
      final mapValue = mapEntry.value as Map<String, dynamic>;
      final routes = mapValue['route'];
      if (routes is! Map<String, dynamic>) {
        throw FormatException('FCD map routes are missing: ${mapEntry.key}');
      }
      for (final routeEntry in routes.entries) {
        if (!routePattern.hasMatch(routeEntry.key) ||
            routeEntry.value is! List ||
            (routeEntry.value as List).length != 2) {
          throw FormatException(
            'Invalid FCD route: ${mapEntry.key}/${routeEntry.key}',
          );
        }
        final destination = (routeEntry.value as List)[1];
        if (destination is! String ||
            destination.trim().isEmpty ||
            destination.trim().length > 16) {
          throw FormatException(
            'Invalid FCD destination: ${mapEntry.key}/${routeEntry.key}',
          );
        }
        labels['${mapEntry.key}-${int.parse(routeEntry.key)}'] = destination
            .trim();
        routeCount++;
      }
    }
    if (routeCount == 0) {
      throw const FormatException('FCD map routes are empty');
    }

    return FcdMapDataset._(
      version: FcdMapVersion.parse(versionValue),
      rawJson: rawJson,
      mapCount: data.length,
      routeCount: routeCount,
      labels: Map<String, String>.unmodifiable(labels),
    );
  }

  final FcdMapVersion version;
  final String rawJson;
  final int mapCount;
  final int routeCount;
  final Map<String, String> labels;

  @override
  String? resolve({
    required int mapAreaId,
    required int mapInfoNo,
    required int internalNodeId,
  }) => labels['$mapAreaId-$mapInfoNo-$internalNodeId'];
}
