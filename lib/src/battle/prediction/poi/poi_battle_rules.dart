/// Rules shared by the live predictor and recorded battle replay.
/// Based on poi-lib-battle 3.0.5 (poooi/lib-battle), simulator.ts.
int poiFleetTypeForPath(String path, int fleetType) {
  if (path.endsWith('/battle_water') || path.endsWith('/each_battle_water')) {
    return 2;
  }
  if (path == '/kcsapi/api_req_combined_battle/battle' ||
      path == '/kcsapi/api_req_combined_battle/each_battle') {
    return fleetType == 3 ? 3 : 1;
  }
  if (path.startsWith('/kcsapi/api_req_sortie/') ||
      path.startsWith('/kcsapi/api_req_practice/') ||
      path.startsWith('/kcsapi/api_req_battle_midnight/') ||
      path.endsWith('/ec_battle')) {
    return 0;
  }
  return fleetType;
}

List<String> poiDayShellingOrder(String path, int fleetType) {
  final enemyCombined = path.contains('/ec_') || path.contains('/each_');
  final type = poiFleetTypeForPath(path, fleetType);
  if (type == 0 && !enemyCombined) {
    return const ['api_hougeki1', 'api_hougeki2', 'api_raigeki'];
  }
  if (type == 2) {
    return const [
      'api_hougeki1',
      'api_hougeki2',
      'api_hougeki3',
      'api_raigeki',
    ];
  }
  if (type == 0 || !enemyCombined) {
    return const [
      'api_hougeki1',
      'api_raigeki',
      'api_hougeki2',
      'api_hougeki3',
    ];
  }
  return const ['api_hougeki1', 'api_hougeki2', 'api_raigeki', 'api_hougeki3'];
}

List<int>? poiMultiTargetAttackOrder(int type, {required bool isNight}) {
  if (!isNight && type == 1) return const [0, 0, 0];
  return switch (type) {
    100 => const [0, 2, 4],
    101 || 102 || 105 || 106 => const [0, 0, 1],
    103 => const [0, 1, 2],
    104 when isNight => const [0, 1],
    200 when isNight => const [0, 0],
    300 => const [1, 1, 2, 2],
    301 => const [2, 2, 3, 3],
    302 => const [1, 1, 3, 3],
    400 => const [0, 1, 2],
    401 => const [0, 0, 1],
    1000 => const [0, 0, 0, 0, 0, 0],
    _ => null,
  };
}

String poiAttackTypeCode(int type, {required bool isNight}) {
  final special = const <int, String>{
    100: 'Nelson',
    101: 'Nagato',
    102: 'Mutsu',
    103: 'Colorado',
    105: 'Baguette_Charge',
    106: 'QE_Touch',
    300: 'Submarine_Special_Attack_2_3',
    301: 'Submarine_Special_Attack_3_4',
    302: 'Submarine_Special_Attack_2_4',
    400: 'Yamato_Triple',
    401: 'Yamato_Double',
    1000: 'Type_4_LC_Special_Attack',
  }[type];
  if (special != null) return special;
  if (isNight) {
    return switch (type) {
      1 => 'Double',
      2 => 'PTCI',
      3 => 'TTCI',
      4 => 'PSCI',
      5 => 'PrCI',
      6 => 'NightCarrierCI',
      // The 11–14 variants use the same setups as 7–10 with two hits.
      7 || 11 => 'DestroyerGunTorpedoRadarCI',
      8 || 12 => 'DestroyerTorpedoRadarLookoutCI',
      9 || 13 => 'DestroyerTorpedoLookoutCI',
      10 || 14 => 'DestroyerTorpedoDrumCI',
      104 => 'Kongo_Class_Kaini_C',
      200 => 'Zuiyun_Night_Attack',
      _ => 'Normal',
    };
  }
  return const <int, String>{
        1: 'Laser',
        2: 'Double',
        3: 'PSCI',
        4: 'PRCI',
        5: 'PACI',
        6: 'PrCI',
        7: 'CVCI',
        200: 'ZuiunMultiAngle',
        201: 'SeaAirMultiAngle',
      }[type] ??
      'Normal';
}

String poiAttackTypeLabel(int type, {required bool isNight}) {
  final special = const <int, String>{
    100: 'Nelson Touch',
    101: '长门特殊攻击',
    102: '陆奥特殊攻击',
    103: 'Colorado 特殊攻击',
    105: 'Richelieu 特殊攻击',
    106: 'Queen Elizabeth 特殊攻击',
    300: '潜水舰特殊攻击（2·3号舰）',
    301: '潜水舰特殊攻击（3·4号舰）',
    302: '潜水舰特殊攻击（2·4号舰）',
    400: '大和三舰特殊攻击',
    401: '大和两舰特殊攻击',
    1000: '四式陆战特殊攻击',
  }[type];
  if (special != null) return special;
  if (isNight) {
    return switch (type) {
      1 => '连击',
      2 => '主炮·鱼雷 Cut-in',
      3 => '鱼雷 Cut-in',
      4 => '主炮·副炮 Cut-in',
      5 => '主炮·主炮 Cut-in',
      6 => '空母夜袭 CI',
      7 || 11 => '主炮·鱼雷·电探 CI',
      8 || 12 => '鱼雷·电探·见张员 CI',
      9 || 13 => '双鱼雷·水雷见张员 CI',
      10 || 14 => '鱼雷·运输桶·水雷见张员 CI',
      104 => '僚舰夜战突击',
      200 => '夜间瑞云攻击',
      _ => '夜战攻击',
    };
  }
  return const <int, String>{
        1: '激光攻击',
        2: '主炮连击',
        3: '主炮·副炮 Cut-in',
        4: '主炮·电探 Cut-in',
        5: '主炮·彻甲弹 Cut-in',
        6: '主炮·主炮 Cut-in',
        7: '战爆联合 Cut-in',
        200: '瑞云立体攻击',
        201: '海空立体攻击',
      }[type] ??
      '炮击';
}
