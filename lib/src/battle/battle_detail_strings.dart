import 'package:flutter/widgets.dart';
import '../localization/game_name_catalog.dart';
import '../localization/game_name_localizations.dart';

import 'battle_detail_models.dart';

/// Translates display text without changing stored replay labels or identities.
class BattleDetailStrings {
  const BattleDetailStrings.forLocale(this.locale, {this.names});

  factory BattleDetailStrings.of(BuildContext context) =>
      BattleDetailStrings.forLocale(
        Localizations.localeOf(context),
        names: gameNames(context),
      );

  final Locale locale;
  final GameNameCatalog? names;
  bool get _ja => locale.languageCode == 'ja';
  bool get _traditional =>
      locale.scriptCode == 'Hant' ||
      const ['TW', 'HK', 'MO'].contains(locale.countryCode);

  String _text(String zh, String hant, String ja, String ko, String en) =>
      locale.languageCode == 'en'
      ? en
      : locale.languageCode == 'ko'
      ? ko
      : _ja
      ? ja
      : _traditional
      ? hant
      : zh;

  String get fleet => _text('舰队', '艦隊', '艦隊', '함대', 'Fleet');
  String get process =>
      _text('战斗过程', '戰鬥過程', '戦闘経過', '전투 경과', 'Battle sequence');
  String get back => _text(
    '返回出击记录',
    '返回出擊記錄',
    '出撃記録に戻る',
    '출격 기록으로 돌아가기',
    'Back to sortie records',
  );
  String get title => _text('战斗详情', '戰鬥詳情', '戦闘詳細', '전투 상세', 'Battle details');
  String get all => _text('全部', '全部', 'すべて', '전체', 'All');
  String get chronological =>
      _text('按发生顺序', '按發生順序', '発生順', '발생 순서', 'Chronological');
  String get noAttacks => _text(
    '没有符合条件的攻击记录',
    '沒有符合條件的攻擊記錄',
    '条件に一致する攻撃記録はありません',
    '조건에 맞는 공격 기록이 없습니다',
    'No attacks match these filters',
  );
  String get attack => _text('攻击', '攻擊', '攻撃', '공격', 'Attack');
  String get miss => _text('未命中', '未命中', 'ミス', '빗나감', 'Miss');
  String get critical => _text('暴击', '暴擊', 'クリティカル', '치명타', 'Critical hit');
  String get damageControl =>
      _text('损管发动', '損管發動', 'ダメコン発動', '응급수리 발동', 'Damage control activated');
  String get hpUnknown => _text('耐久未知', '耐久未知', '耐久不明', '내구 미확인', 'Unknown HP');
  String get equipmentUnavailable => _text(
    '装备数据未提供',
    '裝備資料未提供',
    '装備データ未取得',
    '장비 데이터가 제공되지 않았습니다',
    'Equipment data not provided',
  );
  String get noEquipment =>
      _text('当前没有装备', '目前沒有裝備', '装備なし', '장비 없음', 'No equipment');
  String get proficiency => _text('熟练度', '熟練度', '熟練度', '숙련도', 'Proficiency');
  String get expansionSlot => _text('增设', '增設', '増設', '보강증설', 'Expansion slot');
  String get escaped => _text('退避', '退避', '退避', '퇴피', 'Evacuated');
  String get sortieMapTitle => localize('海域小地图');
  String get mapCurrent => localize('当前');
  String get mapVisited => localize('已走');
  String get mapPartial => localize('航迹不完整，仅显示已捕获航段');
  String get mapUnavailable => localize('该地图未更新');
  String get mapStart => localize('起点');
  String get mapUnknown => localize('未知');
  String mapRoute(int id) => '${localize('航段')} $id';
  String mapNode(int id) => localize('节点 $id');
  String sideName(BattleDetailSide side) => switch (side) {
    BattleDetailSide.friend => _text('我方', '我方', '味方', '아군', 'Friendly'),
    BattleDetailSide.enemy => _text('敌方', '敵方', '敵', '적', 'Enemy'),
    BattleDetailSide.npc => _text('友军', '友軍', '友軍', '우군', 'Allied fleet'),
  };
  String sideAttack(BattleDetailSide side) => locale.languageCode == 'en'
      ? '${sideName(side)} attack'
      : '${sideName(side)}${locale.languageCode == 'ko' ? ' ' : ''}$attack';
  String? attackCutIn(String typeCode) {
    final label = switch (typeCode) {
      'PTCI' => '主炮·鱼雷 CI',
      'TTCI' => '鱼雷 CI',
      'PSCI' => '主炮·副炮 CI',
      'PrCI' => '主炮·主炮 CI',
      'PRCI' => '主炮·电探 CI',
      'PACI' => '主炮·彻甲弹 CI',
      'CVCI' => '战爆联合 CI',
      'NightCarrierCI' => '空母夜袭 CI',
      'DestroyerGunTorpedoRadarCI' => '主炮·鱼雷·电探 CI',
      'DestroyerTorpedoRadarLookoutCI' => '鱼雷·电探·见张员 CI',
      'DestroyerTorpedoLookoutCI' => '双鱼雷·水雷见张员 CI',
      'DestroyerTorpedoDrumCI' => '鱼雷·运输桶·水雷见张员 CI',
      'Zuiyun_Night_Attack' => '夜间瑞云 CI',
      'ZuiunMultiAngle' => '瑞云立体攻击',
      'SeaAirMultiAngle' => '海空立体攻击',
      _ => null,
    };
    return label == null ? null : localize(label);
  }

  String dealt(int damage) => _text(
    '造成 $damage',
    '造成 $damage',
    '与ダメージ $damage',
    '가한 피해 $damage',
    'Dealt $damage',
  );
  String received(int damage) => _text(
    '承受 $damage',
    '承受 $damage',
    '被ダメージ $damage',
    '받은 피해 $damage',
    'Taken $damage',
  );
  String damage(int damage) => _text(
    '造成 $damage 伤害',
    '造成 $damage 傷害',
    '$damage ダメージ',
    '$damage 피해',
    '$damage damage',
  );
  String stageDamage(BattleDetailSide side, int dealt, int received) => _text(
    '${sideName(side)}造成 $dealt · ${sideName(side)}承受 $received',
    '${sideName(side)}造成 $dealt · ${sideName(side)}承受 $received',
    '${sideName(side)}の与ダメージ $dealt · ${sideName(side)}の被ダメージ $received',
    '${sideName(side)}이 가한 피해 $dealt · ${sideName(side)}이 받은 피해 $received',
    '${sideName(side)} dealt $dealt · ${sideName(side)} took $received',
  );
  String attackCount(int count) => locale.languageCode == 'en' && count == 1
      ? '1 attack'
      : _text('$count 条', '$count 條', '$count 件', '$count건', '$count attacks');
  String shipCount(int count) => locale.languageCode == 'en' && count == 1
      ? '1 ship'
      : _text('$count 艘', '$count 艘', '$count 隻', '$count척', '$count ships');
  String targetHp(int before, int after, int damage, {required bool unknown}) =>
      unknown
      ? _text(
          '目标HP 未知（-$damage）',
          '目標HP 未知（-$damage）',
          '対象HP 不明（-$damage）',
          '대상 HP 미확인(-$damage)',
          'Target HP unknown (-$damage)',
        )
      : _text(
          '目标HP $before → $after（-$damage）',
          '目標HP $before → $after（-$damage）',
          '対象HP $before → $after（-$damage）',
          '대상 HP $before → $after(-$damage)',
          'Target HP $before → $after (-$damage)',
        );
  String hpChange(int before, int after) => _text(
    '耐久 $before → $after',
    '耐久 $before → $after',
    '耐久 $before → $after',
    '내구 $before → $after',
    'HP $before → $after',
  );
  String fleetTitle(BattleDetailSide side, BattleDetailFleetRole role) {
    final escort = role == BattleDetailFleetRole.escort;
    if (side == BattleDetailSide.friend) {
      return escort
          ? _text(
              '第二舰队 · 随伴',
              '第二艦隊 · 隨伴',
              '第二艦隊 · 随伴',
              '제2함대 · 수반',
              'Fleet 2 · Escort',
            )
          : _text(
              '第一舰队 · 主力',
              '第一艦隊 · 主力',
              '第一艦隊 · 主力',
              '제1함대 · 주력',
              'Fleet 1 · Main',
            );
    }
    if (side == BattleDetailSide.npc) {
      return escort
          ? _text('友军随伴', '友軍隨伴', '友軍随伴', '우군 수반', 'Allied escort fleet')
          : _text('友军主力', '友軍主力', '友軍主力', '우군 주력', 'Allied main fleet');
    }
    return escort
        ? _text('敌方随伴', '敵方隨伴', '敵随伴', '적 수반', 'Enemy escort fleet')
        : _text('敌方主力', '敵方主力', '敵主力', '적 주력', 'Enemy main fleet');
  }

  String damageStatus(String code) => switch (code) {
    'sunk' => _text('击沉', '擊沉', '撃沈', '격침', 'Sunk'),
    'heavy' => _text('大破', '大破', '大破', '대파', 'Heavy damage'),
    'moderate' => _text('中破', '中破', '中破', '중파', 'Moderate damage'),
    'minor' => _text('小破', '小破', '小破', '소파', 'Light damage'),
    _ => code,
  };

  /// Ship names are game data; only generated missing-name labels and the
  /// allied fleet prefix belong to the UI.
  String shipDisplayName(String raw, {int? shipId}) {
    if (const {'未知舰船', '未知舰娘', '未知攻击方', '未知目标'}.contains(raw)) {
      return localize(raw);
    }
    final numbered = RegExp(r'^(舰船|舰娘|敌舰) (\d+)$').firstMatch(raw);
    if (numbered != null) {
      final number = numbered.group(2)!;
      return switch (numbered.group(1)) {
        '舰娘' => _text(
          '舰娘 $number',
          '艦娘 $number',
          '艦娘 $number',
          '함선 $number',
          'Ship $number',
        ),
        '敌舰' => _text(
          '敌舰 $number',
          '敵艦 $number',
          '敵艦 $number',
          '적 함선 $number',
          'Enemy ship $number',
        ),
        _ => '${localize('舰船')} $number',
      };
    }
    if (raw.startsWith('友军·')) {
      final name = shipDisplayName(raw.substring(3), shipId: shipId);
      return locale.languageCode == 'en'
          ? '${sideName(BattleDetailSide.npc)} · $name'
          : '${sideName(BattleDetailSide.npc)}·$name';
    }
    return names?.shipName(raw, shipId: shipId) ?? raw;
  }

  /// Only app-owned labels and precisely defined generated wrappers are mapped.
  /// Unknown names pass through, including game-owned Japanese proper names.
  String localize(String raw) {
    final exact = _labels[raw];
    if (exact != null) {
      return _text(raw, exact.$1, exact.$2, exact.$3, exact.$4);
    }
    final numbered = RegExp(r'^(基地航空队|舰船|装备|节点|阵型|航向) (\d+)$').firstMatch(raw);
    if (numbered != null) {
      return '${localize(numbered.group(1)!)} ${numbered.group(2)}';
    }
    if (raw.startsWith('友军·')) {
      return locale.languageCode == 'en'
          ? '${sideName(BattleDetailSide.npc)} · ${localize(raw.substring(3))}'
          : '${sideName(BattleDetailSide.npc)}·${localize(raw.substring(3))}';
    }
    if (raw.startsWith('敌') && _labels.containsKey(raw.substring(1))) {
      final label = localize(raw.substring(1));
      if (locale.languageCode == 'en') {
        return 'Enemy ${label[0].toLowerCase()}${label.substring(1)}';
      }
      return '${_text('敌', '敵', '敵', '적 ', 'Enemy ')}$label';
    }
    final combined = RegExp(r'^(.+)（(.+)）$').firstMatch(raw);
    if (combined != null && _labels.containsKey(combined.group(1))) {
      return locale.languageCode == 'en'
          ? '${localize(combined.group(1)!)} (${localize(combined.group(2)!)})'
          : '${localize(combined.group(1)!)}（${localize(combined.group(2)!)}）';
    }
    final node = RegExp(r'^([A-Za-z0-9]+)点$').firstMatch(raw);
    if (node != null) {
      return _text(
        raw,
        '${node.group(1)}點',
        '${node.group(1)}マス',
        '${node.group(1)} 지점',
        'Sortie node ${node.group(1)}',
      );
    }
    return raw;
  }

  static const _labels = <String, (String, String, String, String)>{
    '海域小地图': ('海域小地圖', '海域ミニマップ', '해역 미니맵', 'Map overview'),
    '当前': ('目前', '現在', '현재', 'Current'),
    '已走': ('已走', '通過済み', '통과 완료', 'Visited'),
    '航段': ('航段', '区間', '구간', 'Route segment'),
    '航迹不完整，仅显示已捕获航段': (
      '航跡不完整，僅顯示已擷取航段',
      '航跡は不完全です。取得済み区間のみ表示',
      '항적이 불완전하여 수집된 구간만 표시합니다',
      'Incomplete route: showing recorded segments only',
    ),
    '该地图未更新': (
      '此地圖尚未更新',
      'このマップは未更新です',
      '이 지도가 아직 갱신되지 않았습니다',
      'This map has not been updated',
    ),
    '未知': ('未知', '不明', '미확인', 'Unknown'),
    '敌': ('敵', '敵', '적', 'Enemy'),
    '我方': ('我方', '味方', '아군', 'Friendly'),
    '敌方': ('敵方', '敵', '적', 'Enemy'),
    '敌方舰队': ('敵方艦隊', '敵艦隊', '적 함대', 'Enemy fleet'),
    '友军': ('友軍', '友軍', '우군', 'Allied fleet'),
    '我方主力': ('我方主力', '味方主力', '아군 주력', 'Friendly main fleet'),
    '我方随伴': ('我方隨伴', '味方随伴', '아군 수반', 'Friendly escort fleet'),
    '敌方主力': ('敵方主力', '敵主力', '적 주력', 'Enemy main fleet'),
    '敌方随伴': ('敵方隨伴', '敵随伴', '적 수반', 'Enemy escort fleet'),
    '敌方护卫': ('敵方護衛', '敵護衛', '적 호위', 'Enemy escort fleet'),
    '我方舰队': ('我方艦隊', '味方艦隊', '아군 함대', 'Friendly fleet'),
    '敌联合舰队': ('敵聯合艦隊', '敵連合艦隊', '적 연합함대', 'Enemy combined fleet'),
    '联合舰队': ('聯合艦隊', '連合艦隊', '연합함대', 'Combined fleet'),
    '出击舰队': ('出擊艦隊', '出撃艦隊', '출격 함대', 'Sortie fleet'),
    '空母机动部队': ('空母機動部隊', '空母機動部隊', '항모기동부대', 'Carrier task force'),
    '水上打击部队': ('水上打擊部隊', '水上打撃部隊', '수상타격부대', 'Surface task force'),
    '输送护卫部队': ('輸送護衛部隊', '輸送護衛部隊', '수송호위부대', 'Transport escort force'),
    '预判': ('預判', '予測', '예측', 'Predicted'),
    '已确认': ('已確認', '確認済み', '확인 완료', 'Confirmed'),
    '航行中': ('航行中', '航行中', '항해 중', 'Underway'),
    '基地空袭': ('基地空襲', '基地空襲', '기지 공습', 'Air raid on base'),
    '演习': ('演習', '演習', '연습', 'Exercise'),
    '节点': ('節點', 'マス', '지점', 'Sortie node'),
    '起点': ('起點', '開始マス', '시작 지점', 'Start node'),
    '无战斗': ('無戰鬥', '戦闘なし', '전투 없음', 'No battle'),
    '资源获得': ('資源獲得', '資源獲得', '자원 획득', 'Resources gained'),
    '资源损失': ('資源損失', '資源喪失', '자원 손실', 'Resources lost'),
    '普通战斗': ('普通戰鬥', '通常戦闘', '일반 전투', 'Normal battle'),
    '潜艇战': ('潛艇戰', '潜水艦戦', '잠수함전', 'Submarine battle'),
    'Boss 战': ('Boss 戰', 'ボス戦', '보스전', 'Boss battle'),
    '空袭战': ('空襲戰', '空襲戦', '공습전', 'Air raid'),
    '护送成功': ('護送成功', '護衛成功', '호위 성공', 'Escort successful'),
    '运输点': ('運輸點', '揚陸マス', '양륙 지점', 'Landing node'),
    '长距离空袭战': ('長距離空襲戰', '長距離空襲戦', '장거리 공습전', 'Long-range air raid'),
    '路线选择': ('路線選擇', '進路選択', '경로 선택', 'Route selection'),
    '航空侦察': ('航空偵察', '航空偵察', '항공 정찰', 'Aerial reconnaissance'),
    '泊地修理': ('泊地修理', '泊地修理', '정박지 수리', 'Anchorage repair'),
    '节点事件': ('節點事件', 'マスイベント', '지점 이벤트', 'Sortie node event'),
    '战斗': ('戰鬥', '戦闘', '전투', 'Battle'),
    '昼战': ('晝戰', '昼戦', '주간전', 'Day battle'),
    '确保': ('確保', '制空権確保', '제공권 확보', 'Air supremacy'),
    '优势': ('優勢', '航空優勢', '항공 우세', 'Air superiority'),
    '均衡': ('均衡', '航空均衡', '항공 균형', 'Air parity'),
    '劣势': ('劣勢', '航空劣勢', '항공 열세', 'Air disadvantage'),
    '丧失': ('喪失', '制空権喪失', '제공권 상실', 'Air control lost'),
    '单纵阵': ('單縱陣', '単縦陣', '단종진', 'Line ahead'),
    '复纵阵': ('複縱陣', '複縦陣', '복종진', 'Double line'),
    '轮形阵': ('輪形陣', '輪形陣', '윤형진', 'Diamond'),
    '梯形阵': ('梯形陣', '梯形陣', '제형진', 'Echelon'),
    '单横阵': ('單橫陣', '単横陣', '단횡진', 'Line abreast'),
    '警戒阵': ('警戒陣', '警戒陣', '경계진', 'Vanguard'),
    '第一警戒': ('第一警戒', '第一警戒', '제1경계', 'Formation 1'),
    '第二警戒': ('第二警戒', '第二警戒', '제2경계', 'Formation 2'),
    '第三警戒': ('第三警戒', '第三警戒', '제3경계', 'Formation 3'),
    '第四警戒': ('第四警戒', '第四警戒', '제4경계', 'Formation 4'),
    '阵型': ('陣型', '陣形', '진형', 'Formation'),
    '同航战': ('同航戰', '同航戦', '동항전', 'Parallel engagement'),
    '反航战': ('反航戰', '反航戦', '반항전', 'Head-on engagement'),
    'T 字有利': ('T 字有利', 'T字有利', 'T자 유리', 'T-crossing advantage'),
    'T 字不利': ('T 字不利', 'T字不利', 'T자 불리', 'T-crossing disadvantage'),
    '航向': ('航向', '交戦形態', '교전 형태', 'Engagement'),
    '未知舰船': ('未知艦船', '不明な艦船', '미확인 함선', 'Unknown ship'),
    '未知舰娘': ('未知艦娘', '不明な艦娘', '미확인 함선', 'Unknown ship'),
    '未知攻击方': ('未知攻擊方', '攻撃側不明', '공격자 미확인', 'Unknown attacker'),
    '未知目标': ('未知目標', '対象不明', '대상 미확인', 'Unknown target'),
    '未知海域': ('未知海域', '海域不明', '미확인 해역', 'Unknown map'),
    '节点未知': ('節點未知', 'マス不明', '지점 미확인', 'Unknown sortie node'),
    '未知节点': ('未知節點', '不明なマス', '미확인 지점', 'Unknown sortie node'),
    '敌舰队': ('敵艦隊', '敵艦隊', '적 함대', 'Enemy fleet'),
    '未知敌舰队': ('未知敵艦隊', '不明な敵艦隊', '미확인 적 함대', 'Unknown enemy fleet'),
    '舰船': ('艦船', '艦船', '함선', 'Ship'),
    '装备': ('裝備', '装備', '장비', 'Equipment'),
    '攻击': ('攻擊', '攻撃', '공격', 'Attack'),
    '战斗阶段': ('戰鬥階段', '戦闘段階', '전투 단계', 'Battle phase'),
    '夜战支援': ('夜戰支援', '夜戦支援', '야전 지원', 'Night support'),
    '夜战第一轮': ('夜戰第一輪', '夜戦第1巡', '야전 제1순', 'Night battle round 1'),
    '夜战第二轮': ('夜戰第二輪', '夜戦第2巡', '야전 제2순', 'Night battle round 2'),
    '友军舰队': ('友軍艦隊', '友軍艦隊', '우군 함대', 'Allied fleet'),
    '夜战': ('夜戰', '夜戦', '야전', 'Night battle'),
    '基地喷气强袭': ('基地噴氣強襲', '基地噴式強襲', '기지 분식 강습', 'Land-based jet assault'),
    '喷气强袭': ('噴氣強襲', '噴式強襲', '분식 강습', 'Jet assault'),
    '基地航空队': ('基地航空隊', '基地航空隊', '기지항공대', 'Land-based air squadron'),
    '友军航空战': ('友軍航空戰', '友軍航空戦', '우군 항공전', 'Allied air battle'),
    '航空战': ('航空戰', '航空戦', '항공전', 'Air battle'),
    '第二次航空战': ('第二次航空戰', '第2次航空戦', '제2차 항공전', 'Air battle 2'),
    '支援攻击': ('支援攻擊', '支援攻撃', '지원 공격', 'Support attack'),
    '开幕反潜': ('開幕反潛', '先制対潜', '선제 대잠', 'Opening ASW'),
    '开幕雷击': ('開幕雷擊', '先制雷撃', '선제 뇌격', 'Opening torpedo attack'),
    '雷击战': ('雷擊戰', '雷撃戦', '뇌격전', 'Torpedo phase'),
    '第一炮击战': ('第一砲擊戰', '第1砲撃戦', '제1포격전', 'Shelling phase 1'),
    '第二炮击战': ('第二砲擊戰', '第2砲撃戦', '제2포격전', 'Shelling phase 2'),
    '第三炮击战': ('第三砲擊戰', '第3砲撃戦', '제3포격전', 'Shelling phase 3'),
    '应急修理要员': ('應急修理要員', '応急修理要員', '応急修理要員', '応急修理要員'),
    '应急修理女神': ('應急修理女神', '応急修理女神', '応急修理女神', '応急修理女神'),
    '长门特殊攻击': ('長門特殊攻擊', '長門特殊攻撃', '長門 특수 공격', '長門 special attack'),
    '陆奥特殊攻击': ('陸奧特殊攻擊', '陸奥特殊攻撃', '陸奥 특수 공격', '陸奥 special attack'),
    'Colorado 特殊攻击': (
      'Colorado 特殊攻擊',
      'Colorado 特殊攻撃',
      'Colorado 특수 공격',
      'Colorado special attack',
    ),
    'Richelieu 特殊攻击': (
      'Richelieu 特殊攻擊',
      'Richelieu 特殊攻撃',
      'Richelieu 특수 공격',
      'Richelieu special attack',
    ),
    'Queen Elizabeth 特殊攻击': (
      'Queen Elizabeth 特殊攻擊',
      'Queen Elizabeth 特殊攻撃',
      'Queen Elizabeth 특수 공격',
      'Queen Elizabeth special attack',
    ),
    '潜水舰特殊攻击（2·3号舰）': (
      '潛水艦特殊攻擊（2·3號艦）',
      '潜水艦特殊攻撃（2・3番艦）',
      '잠수함 특수 공격(2·3번함)',
      'Submarine special attack (ships 2 and 3)',
    ),
    '潜水舰特殊攻击（3·4号舰）': (
      '潛水艦特殊攻擊（3·4號艦）',
      '潜水艦特殊攻撃（3・4番艦）',
      '잠수함 특수 공격(3·4번함)',
      'Submarine special attack (ships 3 and 4)',
    ),
    '潜水舰特殊攻击（2·4号舰）': (
      '潛水艦特殊攻擊（2·4號艦）',
      '潜水艦特殊攻撃（2・4番艦）',
      '잠수함 특수 공격(2·4번함)',
      'Submarine special attack (ships 2 and 4)',
    ),
    '大和三舰特殊攻击': (
      '大和三艦特殊攻擊',
      '大和3隻特殊攻撃',
      '大和 3척 특수 공격',
      '大和 three-ship special attack',
    ),
    '大和两舰特殊攻击': (
      '大和兩艦特殊攻擊',
      '大和2隻特殊攻撃',
      '大和 2척 특수 공격',
      '大和 two-ship special attack',
    ),
    '四式陆战特殊攻击': ('四式陸戰特殊攻擊', '四式陸戦特殊攻撃', '四式陸戦 특수 공격', '四式陸戦 special attack'),
    '连击': ('連擊', '連撃', '연속 공격', 'Double attack'),
    '主炮·鱼雷 Cut-in': (
      '主砲·魚雷 Cut-in',
      '主砲・魚雷カットイン',
      '주포·어뢰 컷인',
      'Main gun / torpedo cut-in',
    ),
    '鱼雷 Cut-in': ('魚雷 Cut-in', '魚雷カットイン', '어뢰 컷인', 'Torpedo cut-in'),
    '主炮·副炮 Cut-in': (
      '主砲·副砲 Cut-in',
      '主砲・副砲カットイン',
      '주포·부포 컷인',
      'Main gun / secondary gun cut-in',
    ),
    '主炮·主炮 Cut-in': (
      '主砲·主砲 Cut-in',
      '主砲・主砲カットイン',
      '주포·주포 컷인',
      'Main gun / main gun cut-in',
    ),
    '僚舰夜战突击': ('僚艦夜戰突擊', '僚艦夜戦突撃', '동료함 야전 돌격', 'Consort night assault'),
    '夜间瑞云攻击': ('夜間瑞雲攻擊', '夜間瑞雲攻撃', '야간 瑞雲 공격', 'Night 瑞雲 attack'),
    '夜战攻击': ('夜戰攻擊', '夜戦攻撃', '야전 공격', 'Night attack'),
    '激光攻击': ('雷射攻擊', 'レーザー攻撃', '레이저 공격', 'Laser attack'),
    '主炮连击': ('主砲連擊', '主砲連撃', '주포 연속 공격', 'Main gun double attack'),
    '主炮·电探 Cut-in': (
      '主砲·電探 Cut-in',
      '主砲・電探カットイン',
      '주포·전탐 컷인',
      'Main gun / radar cut-in',
    ),
    '主炮·彻甲弹 Cut-in': (
      '主砲·徹甲彈 Cut-in',
      '主砲・徹甲弾カットイン',
      '주포·철갑탄 컷인',
      'Main gun / AP shell cut-in',
    ),
    '战爆联合 Cut-in': (
      '戰爆聯合 Cut-in',
      '戦爆連合カットイン',
      '전폭 연합 컷인',
      'Fighter / bomber cut-in',
    ),
    '主炮·鱼雷 CI': ('主砲·魚雷 CI', '主砲・魚雷 CI', '주포·어뢰 CI', 'Gun/Torpedo CI'),
    '鱼雷 CI': ('魚雷 CI', '魚雷 CI', '어뢰 CI', 'Torpedo CI'),
    '主炮·副炮 CI': ('主砲·副砲 CI', '主砲・副砲 CI', '주포·부포 CI', 'Gun/Secondary CI'),
    '主炮·主炮 CI': ('主砲·主砲 CI', '主砲・主砲 CI', '주포·주포 CI', 'Main Gun CI'),
    '主炮·电探 CI': ('主砲·電探 CI', '主砲・電探 CI', '주포·전탐 CI', 'Gun/Radar CI'),
    '主炮·彻甲弹 CI': ('主砲·徹甲彈 CI', '主砲・徹甲弾 CI', '주포·철갑탄 CI', 'Gun/AP Shell CI'),
    '战爆联合 CI': ('戰爆聯合 CI', '戦爆連合 CI', '전폭 연합 CI', 'Fighter/Bomber CI'),
    '空母夜袭 CI': ('空母夜襲 CI', '空母夜襲 CI', '항모 야습 CI', 'Night Carrier CI'),
    '主炮·鱼雷·电探 CI': (
      '主砲·魚雷·電探 CI',
      '主砲・魚雷・電探 CI',
      '주포·어뢰·전탐 CI',
      'Gun/Torpedo/Radar CI',
    ),
    '鱼雷·电探·见张员 CI': (
      '魚雷·電探·見張員 CI',
      '魚雷・電探・見張員 CI',
      '어뢰·전탐·견시원 CI',
      'Torpedo/Radar/Lookout CI',
    ),
    '双鱼雷·水雷见张员 CI': (
      '雙魚雷·水雷見張員 CI',
      '魚雷×2・水雷見張員 CI',
      '어뢰 2개·수뢰견시원 CI',
      'Twin Torpedo/Skilled Lookout CI',
    ),
    '鱼雷·运输桶·水雷见张员 CI': (
      '魚雷·運輸桶·水雷見張員 CI',
      '魚雷・ドラム缶・水雷見張員 CI',
      '어뢰·드럼통·수뢰견시원 CI',
      'Torpedo/Drum/Skilled Lookout CI',
    ),
    '夜间瑞云 CI': ('夜間瑞雲 CI', '夜間瑞雲 CI', '야간 즈이운 CI', 'Night Zuiun CI'),
    '瑞云立体攻击': ('瑞雲立體攻擊', '瑞雲立体攻撃', '즈이운 입체 공격', 'Zuiun Multi-Angle Attack'),
    '海空立体攻击': ('海空立體攻擊', '海空立体攻撃', '해공 입체 공격', 'Sea/Air Multi-Angle Attack'),
    '炮击': ('砲擊', '砲撃', '포격', 'Shelling'),
  };
}
