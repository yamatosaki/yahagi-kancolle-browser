abstract interface class BattleNodeLabelResolver {
  String? resolve({
    required int mapAreaId,
    required int mapInfoNo,
    required int internalNodeId,
  });
}

class EmptyBattleNodeLabelResolver implements BattleNodeLabelResolver {
  const EmptyBattleNodeLabelResolver();

  @override
  String? resolve({
    required int mapAreaId,
    required int mapInfoNo,
    required int internalNodeId,
  }) => null;
}

class MapBattleNodeLabelResolver implements BattleNodeLabelResolver {
  const MapBattleNodeLabelResolver(this.labels);

  /// Keys use `mapAreaId-mapInfoNo-internalNodeId`.
  final Map<String, String> labels;

  @override
  String? resolve({
    required int mapAreaId,
    required int mapInfoNo,
    required int internalNodeId,
  }) => labels['$mapAreaId-$mapInfoNo-$internalNodeId'];
}
