class CombatState {
  const CombatState({
    this.mapArea = 0,
    this.mapInfo = 0,
    this.currentNode = 0,
    this.enemyFleetName,
    this.airSuperiority,
    this.dropShipMasterId,
    this.isActive = false,
  });

  final int mapArea;
  final int mapInfo;
  final int currentNode;
  final String? enemyFleetName;
  final String? airSuperiority;
  final int? dropShipMasterId;
  final bool isActive;

  static const CombatState empty = CombatState();

  CombatState copyWith({
    int? mapArea,
    int? mapInfo,
    int? currentNode,
    String? enemyFleetName,
    String? airSuperiority,
    int? dropShipMasterId,
    bool? isActive,
  }) {
    return CombatState(
      mapArea: mapArea ?? this.mapArea,
      mapInfo: mapInfo ?? this.mapInfo,
      currentNode: currentNode ?? this.currentNode,
      enemyFleetName: enemyFleetName ?? this.enemyFleetName,
      airSuperiority: airSuperiority ?? this.airSuperiority,
      dropShipMasterId: dropShipMasterId ?? this.dropShipMasterId,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Use this to clear the node-specific battle states when moving to next node
  CombatState moveNext(int nextNode) {
    return CombatState(
      mapArea: mapArea,
      mapInfo: mapInfo,
      currentNode: nextNode,
      isActive: true,
      // Clear previous battle data
      enemyFleetName: null,
      airSuperiority: null,
      dropShipMasterId: null,
    );
  }
}

const Map<int, String> kAirSuperiorityLabels = <int, String>{
  -1: '未知',
  0: '均衡',
  1: '确保',
  2: '优势',
  3: '劣势',
  4: '丧失',
};

/// 从 kcsapi 战斗响应中提取 api_disp_seiku，缺失时返回 -1。
int parseDispSeiku(Map<String, Object?> data) {
  final kouku = data['api_kouku'];
  if (kouku is! Map) {
    return -1;
  }
  final stage1 = kouku['api_stage1'];
  if (stage1 is! Map || !stage1.containsKey('api_disp_seiku')) {
    return -1;
  }
  final value = stage1['api_disp_seiku'];
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? -1;
}

/// 从 api_formation 的第 4 项（index 3，可选）提取敌方舰队名。
/// 前 3 项为：自军阵形、敌军阵形、交战形态。
String parseEnemyFleetName(Object? formation) {
  if (formation is! List || formation.length <= 3) {
    return '';
  }
  final value = formation[3];
  return value is String && value.isNotEmpty ? value : '';
}
