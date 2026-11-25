import 'package:flutter/widgets.dart';

// Japanese game equipment categories map to stable icon identifiers.
const enemyEquipmentTypeIconIds = <String, int>{
  '小口径主砲': 1,
  '中口径主砲': 2,
  '大口径主砲': 3,
  '副砲': 4,
  '魚雷': 5,
  '艦上戦闘機': 6,
  '艦上爆撃機': 7,
  '艦上攻撃機': 8,
  '水上偵察機': 10,
  '水上爆撃機': 11,
  '小型電探': 12,
  '大型電探': 13,
  'ソナー': 14,
  '爆雷投射機': 15,
  '特殊潜航艇': 17,
  '対空機銃': 18,
  '回転翼機': 20,
  '探照灯': 23,
  '航空要員': 29,
  '潜水艦装備': 43,
  '陸上攻撃機': 47,
  '対艦強化弾': 53,
  '艦載発煙装置': 56,
};

final class EnemyDetailsStrings {
  const EnemyDetailsStrings._(this._ja, this._traditional, this._ko, this._en);

  factory EnemyDetailsStrings.of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('zh');
    return EnemyDetailsStrings._(
      locale.languageCode == 'ja',
      locale.languageCode == 'zh' &&
          (locale.scriptCode == 'Hant' ||
              const ['TW', 'HK', 'MO'].contains(locale.countryCode)),
      locale.languageCode == 'ko',
      locale.languageCode == 'en',
    );
  }

  final bool _ja;
  final bool _en;
  final bool _ko;
  final bool _traditional;

  String _pick(
    String simplified,
    String traditional,
    String japanese,
    String korean,
    String english,
  ) => _en
      ? english
      : _ko
      ? korean
      : (_ja ? japanese : (_traditional ? traditional : simplified));

  String get preciseConfigurationMissing => _pick(
    '未找到该敌舰的精确配置资料',
    '未找到該敵艦的精確配置資料',
    'この敵艦に一致する性能・装備データが見つかりません',
    '이 적 함선과 일치하는 능력치 및 장비 정보가 없습니다',
    'No matching stats or equipment data for this enemy ship',
  );
  String get enemyShip => _pick('敌舰', '敵艦', '敵艦', '적 함선', 'Enemy ship');
  String get preciseConfiguration =>
      _pick('精确配置', '精確配置', '性能・装備データが一致', '능력치 및 장비 일치', 'Exact loadout');
  String get hp => 'HP';
  String get speed => _pick('速力', '速力', '速力', '속력', 'Speed');
  String get range => _pick('射程', '射程', '射程', '사거리', 'Range');
  String get aircraftCapacity =>
      _pick('搭载', '搭載', '搭載', '탑재', 'Aircraft capacity');
  String get equipment => _pick('装备', '裝備', '装備', '장비', 'Equipment');
  String get equipmentMissing => _pick(
    '暂无装备资料',
    '暫無裝備資料',
    '装備データがありません',
    '장비 데이터가 없습니다',
    'No equipment data',
  );
  String get unknownType =>
      _pick('种别不明', '種類不明', '種別不明', '종류 미확인', 'Unknown type');
  String get firepower => _pick('火力', '火力', '火力', '화력', 'Firepower');
  String get torpedo => _pick('雷装', '雷裝', '雷装', '뇌장', 'Torpedo');
  String get bombing => _pick('爆装', '爆裝', '爆装', '폭장', 'Bombing');
  String get antiAir => _pick('对空', '對空', '対空', '대공', 'Anti-air');
  String get armor => _pick('装甲', '裝甲', '装甲', '장갑', 'Armor');
  String get evasion => _pick('回避', '回避', '回避', '회피', 'Evasion');
  String get antiSub => _pick('对潜', '對潛', '対潜', '대잠', 'ASW');
  String get search => _pick('索敌', '索敵', '索敵', '색적', 'LOS');
  String get luck => _pick('运', '運', '運', '운', 'Luck');

  /// Only known UI attribute values are localized; new source values pass through.
  String speedValue(String? value) => switch (value) {
    null => '—',
    '高速' => _pick('高速', '高速', '高速', '고속', 'Fast'),
    '低速' => _pick('低速', '低速', '低速', '저속', 'Slow'),
    '陸上' => _pick('陆上', '陸上', '陸上', '지상', 'Land-based'),
    'なし' => _pick('无', '無', 'なし', '없음', 'None'),
    _ => value,
  };

  String rangeValue(String? value) => switch (value) {
    null => '—',
    '超短' => _pick('超短', '超短', '超短', '초단', 'Very short'),
    '短' => _pick('短', '短', '短', '단', 'Short'),
    '中' => _pick('中', '中', '中', '중', 'Medium'),
    '長' => _pick('长', '長', '長', '장', 'Long'),
    '超長' => _pick('超长', '超長', '超長', '초장', 'Very long'),
    '超長+' => _pick('超长+', '超長+', '超長+', '초장+', 'Very long+'),
    _ => value,
  };
}
