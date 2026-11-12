import 'package:flutter/widgets.dart';
import '../localization/game_name_localizations.dart';
import '../../l10n/app_localizations.dart';

/// Source keys for the five-locale [fleetText] catalog below. Keep screen
/// structure and Chinese lookup keys together so UI call sites contain no
/// untranslated literals.
abstract final class FleetUiKeys {
  static const unknownShipType = '未知舰种';
  static const unknownShip = '未知舰娘';
  static const noFurtherRemodel = '无后续改造';
  static const dataIncomplete = '数据未齐';
  static const remodel = '改造';
  static const fleetSummaryDisplay = '编队简报显示内容';
  static const reset = '恢复默认';
  static const capsuleAppearance = '胶囊外观';
  static const name = '名字';
  static const displayContent = '显示内容';
  static const fleetSelectorName = '舰队切换名称';
  static const customFleetName = '自定义舰队名';
  static const shortFleetNumber = '1–4 简称';
  static const summaryGroup = '舰队汇总';
  static const singleShipGroup = '单舰胶囊';
  static const summaryLimitHint = '最多同时显示 5 项；先取消一项即可选择其他指标。';
  static const mechanismsHint = '先制对潜、对空 CI、喷进弹幕、空母夜袭与旗舰特殊攻击';
  static const shipTypeName = '舰种名称';
  static const chinese = '中文';
  static const englishAbbreviation = '英文缩写';
  static const nosakiShort = '野埼功能简称';
  static const dockShort = '入渠模式简称';
  static const anchorageShort = '泊地模式简称';
  static const landBaseRadiusShort = '半径';

  static const displayGroups = <String, Map<String, String>>{
    '外观与状态': {
      'portrait': '舰娘头像',
      'equipment': '装备类型图标',
      'hp': 'HP 数值',
      'fuel': '燃料数值',
      'ammo': '弹药数值',
      'bars': '条状显示',
    },
    singleShipGroup: {
      'level': '等级',
      'type': '舰种',
      'shipSpeed': '单舰速度',
      'morale': '疲劳值',
      'mechanisms': '特殊机制',
    },
    summaryGroup: {
      'speed': '舰队速度',
      'total-level': '总等级',
      'firepower': '火力',
      'torpedo': '雷装',
      'anti-air': '对空',
      'anti-sub': '对潜',
      'air-power': '制空',
      'line-of-sight': '索敌',
      'minimum-condition': '最低疲劳',
      'recovery-countdown': '恢复倒计时',
    },
  };

  static const moduleDisplayOptions = <String, Map<String, String>>{
    'land_base': {
      'portrait': '飞机图片',
      'bars': '条状显示',
      'airPower': '制空值',
      'range': '航程',
    },
    'repair': {'portrait': '舰娘头像', 'empty': '显示空闲槽位'},
    'construction': {'portrait': '舰娘头像', 'empty': '显示空闲槽位'},
    'expedition': {
      'fleet': '舰队名字',
      'number': '远征编号',
      'name': '远征名称',
      'time': '远征倒计时',
    },
    'quests': {
      'type': '任务类型',
      'number': '任务编号',
      'name': '任务名字',
      'progress': '任务进度',
    },
    'battle': {
      'sortieMap': '地图',
      'enemyPreview': '提前剧透',
      'predictionResult': '结果剧透',
    },
    'pre_sortie': <String, String>{},
    'sortie_experience': <String, String>{},
  };

  static const moduleDisplayTitles = <String, String>{
    'land_base': '陆基显示内容',
    'repair': '维修显示内容',
    'construction': '建造显示内容',
    'expedition': '远征显示内容',
    'quests': '任务简报显示内容',
    'battle': '战斗简报显示内容',
    'pre_sortie': '出击准备显示内容',
    'sortie_experience': '出击经验显示内容',
  };
}

/// Localizes app-owned fleet labels at their rendering boundary.
String fleetText(BuildContext context, String source) {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('zh');
  final ja = locale.languageCode == 'ja';
  final ko = locale.languageCode == 'ko';
  final en = locale.languageCode == 'en';
  final hant =
      locale.scriptCode == 'Hant' ||
      ['TW', 'HK', 'MO'].contains(locale.countryCode);
  const resources = <String, (String, String, String, String, String)>{
    FleetUiKeys.nosakiShort: ("野埼", "野埼", "野埼", "노사키", "Nosaki"),
    FleetUiKeys.dockShort: ("入渠", "入渠", "入渠", "입거", "Dock"),
    FleetUiKeys.anchorageShort: ("泊地", "泊地", "泊地", "정박지", "Anch."),
    FleetUiKeys.landBaseRadiusShort: ("半径", "半徑", "半径", "반경", "Radius"),
    "野崎刷闪中": ("野埼刷闪中", "野埼刷閃中", "野埼キラ付け中", "노사키 반짝이 작업 중", "Nosaki sparkling"),
    "泊地修理": ("泊地修理", "泊地修理", "泊地修理", "정박지 수리", "Anchorage repair"),
    "远征显示内容": ("远征显示内容", "遠征顯示內容", "遠征の表示内容", "원정 표시 항목", "Expedition display"),
    "舰队名字": ("舰队名字", "艦隊名字", "艦隊名", "함대 이름", "Fleet name"),
    "远征编号": ("远征编号", "遠征編號", "遠征番号", "원정 번호", "Expedition number"),
    "远征倒计时": ("远征倒计时", "遠征倒數計時", "遠征残り時間", "원정 남은 시간", "Expedition countdown"),
    "远征名称": ("远征名称", "遠征名稱", "遠征名", "원정 이름", "Expedition name"),
    "飞机图片": ("飞机图片", "飛機圖片", "航空機画像", "항공기 이미지", "Aircraft image"),
    "制空值": ("制空值", "制空值", "制空値", "제공치", "Air power"),
    "航程": ("航程", "航程", "行動半径", "행동반경", "Range"),
    "显示空闲槽位": ("显示空闲槽位", "顯示空閒槽位", "空きスロットを表示", "빈 슬롯 표시", "Show empty slots"),
    "陆基显示内容": (
      "陆基显示内容",
      "陸基顯示內容",
      "基地航空隊の表示内容",
      "기지항공대 표시 항목",
      "Land base display",
    ),
    "维修显示内容": ("维修显示内容", "維修顯示內容", "修理の表示内容", "수리 표시 항목", "Repair display"),
    "建造显示内容": (
      "建造显示内容",
      "建造顯示內容",
      "建造の表示内容",
      "건조 표시 항목",
      "Construction display",
    ),
    "暂无修理": ("暂无修理", "暫無修理", "修理なし", "수리 중인 함선 없음", "No repairs"),
    "暂无建造": ("暂无建造", "暫無建造", "建造なし", "건조 중인 함선 없음", "No construction"),
    "暂无舰娘": ("暂无舰娘", "暫無艦娘", "艦娘なし", "칸무스 없음", "No ships"),

    "HP 数值": ("HP 数值", "HP 數值", "HP数値", "HP 수치", "HP value"),
    "条状显示": ("条状显示", "條狀顯示", "ゲージ表示", "게이지 표시", "Show gauges"),
    "编队简报显示内容": (
      "编队简报显示内容",
      "編隊簡報顯示內容",
      "編成概要の表示内容",
      "편성 요약 표시 항목",
      "Fleet summary display",
    ),
    "任务简报显示内容": (
      "任务简报显示内容",
      "任務簡報顯示內容",
      "任務の表示内容",
      "임무 요약 표시 항목",
      "Quest briefing display",
    ),
    "战斗简报显示内容": (
      "战斗简报显示内容",
      "戰鬥簡報顯示內容",
      "戦闘の表示内容",
      "전투 요약 표시 항목",
      "Battle briefing display",
    ),
    "地图": ("地图", "地圖", "マップ", "지도", "Map"),
    "提前剧透": (
      "提前剧透",
      "提前劇透",
      "敵編成の先読み",
      "적 편성 미리 보기",
      "Enemy preview",
    ),
    "结果剧透": (
      "结果剧透",
      "結果劇透",
      "戦闘結果の先読み",
      "전투 결과 미리 보기",
      "Battle outcome preview",
    ),
    "出击准备显示内容": (
      "出击准备显示内容",
      "出擊準備顯示內容",
      "出撃準備の表示内容",
      "출격 준비 표시 항목",
      "Sortie preparation display",
    ),
    "出击经验显示内容": (
      "出击经验显示内容",
      "出擊經驗顯示內容",
      "出撃経験値の表示内容",
      "출격 경험치 표시 항목",
      "Sortie EXP display",
    ),
    "胶囊外观": ("胶囊外观", "膠囊外觀", "カプセルの外観", "캡슐 모양", "Capsule appearance"),
    "胶囊外观设置": (
      "胶囊外观设置",
      "膠囊外觀設定",
      "カプセル外観設定",
      "캡슐 모양 설정",
      "Capsule appearance settings",
    ),
    "LOGO": ("LOGO", "LOGO", "ロゴ", "로고", "Logo"),
    "名字": ("名字", "名字", "名前", "이름", "Name"),
    "显示内容": ("显示内容", "顯示內容", "表示内容", "표시 항목", "Display content"),
    "隐藏后自动重排；舰名与关键状态始终保留。": (
      "隐藏后自动重排；舰名与关键状态始终保留。",
      "隱藏後自動重排；艦名與關鍵狀態始終保留。",
      "非表示にすると自動で再配置します。艦名・重要な状態は常に表示します。",
      "숨기면 자동으로 재배치됩니다. 함명과 주요 상태는 항상 표시됩니다.",
      "Hidden items are removed from the layout automatically. Ship names and key statuses are always shown.",
    ),
    "恢复默认": ("恢复默认", "恢復預設", "初期設定に戻す", "기본값 복원", "Restore defaults"),
    "紧凑文字": ("紧凑文字", "緊湊文字", "コンパクト表示", "간결한 텍스트", "Compact text"),
    "外观与状态": ("外观与状态", "外觀與狀態", "外観と状態", "모양 및 상태", "Appearance and status"),
    "单舰胶囊": ("单舰胶囊", "單艦膠囊", "艦ごとの情報", "개별 함선 캡슐", "Individual ship capsules"),
    "舰队汇总": ("舰队汇总", "艦隊彙總", "艦隊の集計", "함대 집계", "Fleet totals"),
    "视觉效果": ("视觉效果", "視覺效果", "視覚効果", "시각 효과", "Visual effects"),
    "舰娘头像": ("舰娘头像", "艦娘頭像", "艦娘画像", "칸무스 이미지", "Ship portrait"),
    "装备类型图标": (
      "装备类型图标",
      "裝備類型圖示",
      "装備種別アイコン",
      "장비 유형 아이콘",
      "Equipment type icons",
    ),
    "燃料数值": ("燃料数值", "燃料數值", "燃料の数値", "연료 수치", "Fuel value"),
    "弹药数值": ("弹药数值", "彈藥數值", "弾薬の数値", "탄약 수치", "Ammo value"),
    "HP / 燃料 / 弹药进度条": (
      "HP / 燃料 / 弹药进度条",
      "HP / 燃料 / 彈藥進度條",
      "HP・燃料・弾薬ゲージ",
      "HP / 연료 / 탄약 게이지",
      "HP / fuel / ammo gauges",
    ),
    "等级": ("等级", "等級", "レベル", "레벨", "Level"),
    "舰种": ("舰种", "艦種", "艦種", "함종", "Ship type"),
    "舰种名称": ("舰种名称", "艦種名稱", "艦種名", "함종 이름", "Ship type name"),
    "舰队切换名称": ("舰队切换名称", "艦隊切換名稱", "艦隊切替名", "함대 전환 이름", "Fleet selector names"),
    "自定义舰队名": (
      "自定义舰队名",
      "自訂艦隊名",
      "カスタム艦隊名",
      "사용자 지정 함대 이름",
      "Custom fleet names",
    ),
    "1–4 简称": ("1–4 简称", "1–4 簡稱", "1～4の略称", "1~4 약칭", "Numbers 1–4"),
    "中文": ("中文", "中文", "中国語", "중국어", "Chinese"),
    "英文缩写": ("英文缩写", "英文縮寫", "英語略称", "영문 약칭", "English abbreviations"),
    "单舰速度": ("单舰速度", "單艦速度", "各艦の速力", "개별 함선 속력", "Ship speed"),
    "疲劳值": ("士气值", "士氣值", "コンディション", "컨디션", "Morale"),
    "特殊机制": ("特殊机制", "特殊機制", "特殊能力", "특수 능력", "Special mechanics"),
    "舰队速度": ("舰队速度", "艦隊速度", "艦隊速力", "함대 속력", "Fleet speed"),
    "最低疲劳": ("最低士气", "最低士氣", "最低コンディション", "최저 컨디션", "Minimum morale"),
    "恢复倒计时": ("恢复倒计时", "恢復倒數計時", "回復まで", "회복 남은 시간", "Recovery countdown"),
    "火力": ("火力", "火力", "火力", "화력", "Firepower"),
    "雷装": ("雷装", "雷裝", "雷装", "뇌장", "Torpedo"),
    "对空": ("对空", "對空", "対空", "대공", "Anti-air"),
    "对潜": ("对潜", "對潛", "対潜", "대잠", "Anti-sub"),
    "损伤边框脉冲": (
      "损伤边框脉冲",
      "損傷邊框脈衝",
      "損傷枠の点滅",
      "손상 테두리 점멸",
      "Damage border pulse",
    ),
    "闪光动画": ("闪光动画", "閃光動畫", "キラキラ演出", "반짝임 효과", "Sparkle animation"),
    "最多同时显示 5 项；先取消一项即可选择其他指标。": (
      "最多同时显示 5 项；先取消一项即可选择其他指标。",
      "最多同時顯示 5 項；先取消一項即可選擇其他指標。",
      "同時に表示できるのは5項目までです。選択を解除すると別の項目を選べます。",
      "동시에 최대 5개 항목을 표시할 수 있습니다. 한 항목을 해제하면 다른 지표를 선택할 수 있습니다.",
      "Show up to 5 items at once. Deselect one to choose another metric.",
    ),
    "先制对潜、对空 CI、喷进弹幕、空母夜袭与旗舰特殊攻击": (
      "先制对潜、对空 CI、喷进弹幕、空母夜袭与旗舰特殊攻击",
      "先制對潛、對空 CI、噴進彈幕、空母夜襲與旗艦特殊攻擊",
      "先制対潜・対空CI・噴進弾幕・空母夜襲・旗艦特殊攻撃",
      "선제 대잠, 대공 CI, 분진탄막, 항모 야습 및 기함 특수 공격",
      "Opening ASW, anti-air cut-ins, rocket barrage, carrier night attacks and flagship special attacks",
    ),

    "Normal": ("通常海域", "通常海域", "通常海域", "일반 해역", "Normal areas"),
    "SP Normal": (
      "特殊通常海域",
      "特殊通常海域",
      "特殊通常海域",
      "특수 일반 해역",
      "Special normal areas",
    ),
    "Extra": ("额外作战", "額外作戰", "拡張作戦", "확장 작전", "Extra operations"),
    "Event": ("活动海域", "活動海域", "イベント海域", "이벤트 해역", "Event areas"),
    "弾薬": ("弹药", "彈藥", "弾薬", "탄약", "Ammo"),
    "鋼材": ("钢材", "鋼材", "鋼材", "강재", "Steel"),
    "ボーキサイト": ("铝土", "鋁土", "ボーキサイト", "보크사이트", "Bauxite"),
    "高速建造材": (
      "高速建造材",
      "高速建造材",
      "高速建造材",
      "고속건조재",
      "Instant construction material",
    ),
    "高速修復材": ("高速修复材", "高速修復材", "高速修復材", "고속수복재", "Instant repair material"),
    "開発資材": ("开发资材", "開發資材", "開発資材", "개발자재", "Development material"),
    "改修資材": ("改修资材", "改修資材", "改修資材", "개수자재", "Improvement material"),
    "家具コイン": ("家具币", "家具幣", "家具コイン", "가구 코인", "Furniture coins"),
    "家具箱（小）": (
      "家具箱（小）",
      "家具箱（小）",
      "家具箱（小）",
      "가구 상자(소)",
      "Furniture box (small)",
    ),
    "家具箱（中）": (
      "家具箱（中）",
      "家具箱（中）",
      "家具箱（中）",
      "가구 상자(중)",
      "Furniture box (medium)",
    ),
    "家具箱（大）": (
      "家具箱（大）",
      "家具箱（大）",
      "家具箱（大）",
      "가구 상자(대)",
      "Furniture box (large)",
    ),
    "給糧艦「間宮」": (
      "给粮舰「间宫」",
      "給糧艦「間宮」",
      "給糧艦「間宮」",
      "급양함 마미야",
      "Food Supply Ship Mamiya",
    ),
    "勲章": ("勋章", "勳章", "勲章", "훈장", "Medal"),
    "給糧艦「伊良湖」": (
      "给粮舰「伊良湖」",
      "給糧艦「伊良湖」",
      "給糧艦「伊良湖」",
      "급양함 이라코",
      "Food Supply Ship Irako",
    ),
    "甲種勲章": ("甲种勋章", "甲種勳章", "甲種勲章", "갑종훈장", "First Class Medal"),
    "秋刀魚": ("秋刀鱼", "秋刀魚", "秋刀魚", "꽁치", "Saury"),
    "熟練搭乗員": ("熟练搭乘员", "熟練搭乘員", "熟練搭乗員", "숙련탑승원", "Skilled Crew Member"),
    "新型砲熕兵装資材": (
      "新型炮熕兵装资材",
      "新型砲熕兵裝資材",
      "新型砲熕兵装資材",
      "신형포공병장자재",
      "New Model Gun Mount Improvement Material",
    ),
    "新型航空兵装資材": (
      "新型航空兵装资材",
      "新型航空兵裝資材",
      "新型航空兵装資材",
      "신형항공병장자재",
      "New Model Aerial Armament Material",
    ),
    "戦闘詳報": ("战斗详报", "戰鬥詳報", "戦闘詳報", "전투상보", "Action Report"),
    "新型兵装資材": (
      "新型兵装资材",
      "新型兵裝資材",
      "新型兵装資材",
      "신형병장자재",
      "New Model Armament Material",
    ),
    "潜水艦補給物資": (
      "潜水舰补给物资",
      "潛水艦補給物資",
      "潜水艦補給物資",
      "잠수함 보급물자",
      "Submarine Supply Material",
    ),
    "海外艦最新技術": (
      "海外舰最新技术",
      "海外艦最新技術",
      "海外艦最新技術",
      "해외함 최신기술",
      "New Overseas Warship Technology",
    ),
    "当前疲劳": ("当前士气", "目前士氣", "現在のコンディション", "현재 컨디션", "Current morale"),
    "疲劳 ": ("士气 ", "士氣 ", "コンディション ", "컨디션 ", "Morale "),
    "未改野埼需疲劳≥49": (
      "未改野埼需士气≥49",
      "未改野埼需士氣≥49",
      "未改造の野埼はCond≥49が必要",
      "미개장 노사키는 Cond≥49 필요",
      "Unremodeled Nosaki requires Cond≥49",
    ),
    "野埼自身疲劳过低（需Cond≥30）": (
      "野埼自身士气过低（需Cond≥30）",
      "野埼自身士氣過低（需Cond≥30）",
      "野埼のコンディション不足（Cond≥30が必要）",
      "노사키 컨디션 부족(Cond≥30 필요)",
      "Nosaki morale too low (requires Cond≥30)",
    ),
  };
  final resource = resources[source];
  if (resource != null) {
    return en
        ? resource.$5
        : ko
        ? resource.$4
        : ja
        ? resource.$3
        : hant
        ? resource.$2
        : resource.$1;
  }
  for (final entry in resources.entries) {
    // Short UI labels must be requested by key; their values can be ship names.
    if (const {
      FleetUiKeys.nosakiShort,
      FleetUiKeys.dockShort,
      FleetUiKeys.anchorageShort,
    }.contains(entry.key)) {
      continue;
    }
    final candidate = entry.value;
    if (source == candidate.$1) {
      return en
          ? candidate.$5
          : ko
          ? candidate.$4
          : ja
          ? candidate.$3
          : hant
          ? candidate.$2
          : candidate.$1;
    }
  }
  switch (source) {
    case "已完成":
      return l10n.completed;
    case "入渠":
      return l10n.notificationRepair;
    case "制空":
      return l10n.airPower;
    case "回避":
      return l10n.evasion;
    case "完成":
      return l10n.done;
    case "对潜":
      return l10n.antiSub;
    case "对空":
      return l10n.antiAir;
    case "建造":
      return l10n.notificationConstruction;
    case "弹药":
      return l10n.ammo;
    case "当前舰队没有舰娘":
      return l10n.fleetNoShips;
    case "总等级":
      return l10n.totalLevel;
    case "战果":
      return l10n.senkaUnit;
    case "无":
      return l10n.noValue;
    case "无数据":
      return l10n.landBaseNoData;
    case "无法修理":
      return l10n.unableToRepair;
    case "暂无附加属性":
      return l10n.noAdditionalStats;
    case "最低疲劳":
      return l10n.averageCondition;
    case "未知":
      return l10n.statusUnknown;
    case "未知舰娘":
      return l10n.unknownShip;
    case "未知舰种":
      return l10n.unknownShipType;
    case "未知装备":
      return l10n.unknownEquipment;
    case "未编成":
      return l10n.fleetNotFormed;
    case "检查":
      return l10n.check;
    case "母港待命":
      return l10n.fleetStandby;
    case "泊地":
      return l10n.notificationAnchorage;
    case "火力":
      return l10n.firepower;
    case "燃料":
      return l10n.fuel;
    case "疲劳":
      return l10n.fatigue;
    case "知道了":
      return l10n.acknowledge;
    case "确定":
      return l10n.confirm;
    case "等待母港数据":
      return l10n.waitingForPortData;
    case "简报":
      return l10n.briefing;
    case "索敌":
      return l10n.lineOfSight;
    case "编队简报":
      return l10n.fleetBrief;
    case "舰娘":
      return l10n.shipGirl;
    case "舰队":
      return l10n.fleet;
    case "血量":
      return l10n.hp;
    case "装备数据等待更新":
      return l10n.equipmentDataWaiting;
    case "装甲":
      return l10n.armor;
    case "超出修理范围":
      return l10n.outOfRepairRange;
    case "进入游戏母港或刷新游戏页面后，这里会自动更新":
      return l10n.waitingForPortDataDescription;
    case "远征":
      return l10n.notificationExpedition;
    case "退避":
      return l10n.landBaseActionRetreat;
    case "速度":
      return l10n.speed;
    case "雷装":
      return l10n.torpedo;
    case "需要补给":
      return l10n.needsSupply;
  }
  if (!ja && !hant && !ko && !en) {
    final condition = RegExp(r'^疲劳 (\d+)$').firstMatch(source);
    return condition == null ? source : '士气 ${condition[1]}';
  }
  const labels = <String, (String, String, String, String)>{
    "空闲": ("空閒", "空き", "비어 있음", "Empty"),
    "闲置": ("閒置", "待機中", "대기 중", "Idle"),
    "建中": ("建中", "建造中", "건조 중", "Building"),
    "未知远征": ("未知遠征", "不明な遠征", "알 수 없는 원정", "Unknown expedition"),
    "高建造材": ("高建造材", "高速建造材", "고속건조재", "Instant construction material"),
    "高修复材": ("高修復材", "高速修復材", "고속수복재", "Instant repair material"),
    "钢材": ("鋼材", "鋼材", "강재", "Steel"),
    "铝土": ("鋁土", "ボーキサイト", "보크사이트", "Bauxite"),
    "增设": ("增設", "増設", "증설", "Expansion slot"),
    "修理时间": ("修理時間", "修理時間", "수리 시간", "Repair time"),
    "远征中": ("遠征中", "遠征中", "원정 중", "On expedition"),
    "状态": ("狀態", "状態", "상태", "Status"),
    "耐久": ("耐久", "耐久", "내구", "HP"),
    "功能区位置": ("功能區位置", "機能エリアの位置", "기능 영역 위치", "Panel position"),
    "拓展功能区位置": (
      "拓展功能區位置",
      "拡張機能エリアの位置",
      "확장 기능 영역 위치",
      "Extended panel position",
    ),
    "游戏下方": ("遊戲下方", "ゲームの下", "게임 아래", "Below the game"),
    "游戏上方": ("遊戲上方", "ゲームの上", "게임 위", "Above the game"),
    "选择功能区显示在左侧或右侧，竖屏保持上下布局。": (
      "選擇功能區顯示在左側或右側，直向保持上下配置。",
      "機能エリアの左右位置を選択します。縦画面では上下配置を維持します。",
      "기능 영역을 왼쪽이나 오른쪽에 표시합니다. 세로 화면에서는 위아래 배치를 유지합니다.",
      "Show the panel on the left or right. Portrait mode keeps the vertical layout.",
    ),
    "任务类型": ("任務類型", "任務種別", "임무 유형", "Quest type"),
    "任务编号": ("任務編號", "任務番号", "임무 번호", "Quest number"),
    "任务名字": ("任務名稱", "任務名", "임무 이름", "Quest name"),
    "任务进度": ("任務進度", "任務進捗", "임무 진행도", "Quest progress"),
    "改造": ("改造", "改造", "개장", "Remodel"),
    "无后续改造": ("無後續改造", "次の改造なし", "후속 개장 없음", "No further remodel"),
    "数据未齐": ("資料未齊", "データ未取得", "데이터 미확보", "Data incomplete"),
    "爆装": ("爆裝", "爆装", "폭장", "Bombing"),
    "命中": ("命中", "命中", "명중", "Accuracy"),
    "射程": ("射程", "射程", "사거리", "Firing range"),
    "搭载": ("搭載", "搭載", "탑재", "Aircraft capacity"),
    "速力": ("速力", "速力", "속력", "Speed"),
    "运": ("運", "運", "운", "Luck"),
    "短": ("短", "短", "단", "Short"),
    "中": ("中", "中", "중", "Medium"),
    "最速": ("最速", "最速", "최속", "Fastest"),
    "高速+": ("高速+", "高速+", "고속+", "Fast+"),
    "高速": ("高速", "高速", "고속", "Fast"),
    "低速": ("低速", "低速", "저속", "Slow"),
    "旗舰": ("旗艦", "旗艦", "기함", "Flagship"),
    "先制对潜": ("先制對潛", "先制対潜", "선제 대잠", "Opening ASW"),
    "先反": ("先反", "先制対潜", "선제 대잠", "Opening ASW"),
    "对空 CI": ("對空 CI", "対空CI", "대공 CI", "Anti-air CI"),
    "对空喷进弹幕": ("對空噴進彈幕", "対空噴進弾幕", "대공 분진탄막", "Anti-air rocket barrage"),
    "喷2": ("噴2", "噴進改二", "분진 개2", "Rocket barrage"),
    "空母夜间航空攻击": (
      "空母夜間航空攻擊",
      "空母夜間航空攻撃",
      "항모 야간 항공 공격",
      "Carrier night air attack",
    ),
    "夜袭": ("夜襲", "夜襲", "야습", "Night attack"),
    "特攻": ("特攻", "特殊攻撃", "특수 공격", "Special attack"),
    "一齐射击（长门）": ("一齊射擊（長門）", "一斉射（長門）", "일제사격(長門)", "Simultaneous fire (長門)"),
    "一齐射击（陆奥）": ("一齊射擊（陸奧）", "一斉射（陸奥）", "일제사격(陸奥)", "Simultaneous fire (陸奥)"),
    "大和型特殊攻击": ("大和型特殊攻擊", "大和型特殊攻撃", "大和형 특수 공격", "大和-class special attack"),
    "僚舰夜战突击": ("僚艦夜戰突擊", "僚艦夜戦突撃", "동료함 야전 돌격", "Consort night assault"),
    "Queen Elizabeth级特殊攻击": (
      "Queen Elizabeth級特殊攻擊",
      "Queen Elizabeth級特殊攻撃",
      "Queen Elizabeth급 특수 공격",
      "Queen Elizabeth-class special attack",
    ),
    "Richelieu级特殊攻击": (
      "Richelieu級特殊攻擊",
      "Richelieu級特殊攻撃",
      "Richelieu급 특수 공격",
      "Richelieu-class special attack",
    ),
    "潜水舰队攻击": ("潛水艦隊攻擊", "潜水艦隊攻撃", "잠수함대 공격", "Submarine fleet attack"),
    "开幕雷击前先进行一次对潜攻击。": (
      "開幕雷擊前先進行一次對潛攻擊。",
      "開幕雷撃前に対潜攻撃を1回行います。",
      "개막 뇌격 전에 대잠 공격을 1회 수행합니다.",
      "Performs one ASW attack before opening torpedoes.",
    ),
    "当前舰娘的舰种、对潜值和装备组合满足 Yahagi 的先制对潜静态判定。": (
      "目前艦娘的艦種、對潛值和裝備組合滿足 Yahagi 的先制對潛靜態判定。",
      "この艦娘の艦種・対潜値・装備の組み合わせは、Yahagiの先制対潜の静的判定条件を満たしています。",
      "현재 칸무스의 함종, 대잠 수치, 장비 조합이 Yahagi의 선제 대잠 정적 판정 조건을 충족합니다.",
      "The ship type, ASW value and equipment meet the static opening ASW conditions used by Yahagi.",
    ),
    "当前装备组合可触发对空弹幕（对空 Cut-in）。": (
      "目前裝備組合可觸發對空彈幕（對空 Cut-in）。",
      "現在の装備の組み合わせで対空カットインが発動可能です。",
      "현재 장비 조합으로 대공탄막(대공 컷인)을 발동할 수 있습니다.",
      "The current equipment can trigger an anti-air cut-in.",
    ),
    "实际触发类型和击坠效果由舰娘与装备组合决定。": (
      "實際觸發類型和擊墜效果由艦娘與裝備組合決定。",
      "実際の発動種別と撃墜効果は艦娘と装備の組み合わせで決まります。",
      "실제 발동 유형과 격추 효과는 칸무스와 장비 조합에 따라 결정됩니다.",
      "The activation type and aircraft losses depend on the ship and equipment combination.",
    ),
    "当前舰种装备了 12cm 30连装喷进炮改二，可在航空战中判定对空喷进弹幕。": (
      "目前艦種裝備了 12cm 30連裝噴進砲改二，可在航空戰中判定對空噴進彈幕。",
      "この艦種は12cm30連装噴進砲改二を装備しており、航空戦で対空噴進弾幕の発動判定が可能です。",
      "현재 함종에 12cm30連装噴進砲改二가 장착되어 있어 항공전에서 대공 분진탄막 발동 판정이 가능합니다.",
      "This ship type has 12cm30連装噴進砲改二 equipped and can attempt an anti-air rocket barrage during aerial combat.",
    ),
    "搭载夜间飞机（夜战/夜攻）及夜间作战航空要员或自带夜战起飞能力，可在夜战中发动空母夜间航空攻击（夜袭 CI）。": (
      "搭載夜間飛機（夜戰/夜攻）及夜間作戰航空要員或自帶夜戰起飛能力，可在夜戰中發動空母夜間航空攻擊（夜襲 CI）。",
      "夜間機（夜戦・夜攻）を搭載し、夜間作戦航空要員を搭載するか、艦自体が夜間発艦能力を持つ場合、夜戦で空母夜間航空攻撃（夜襲カットイン）が可能です。",
      "야간 항공기(야간 전투기/공격기)를 탑재하고 夜間作戦航空要員을 탑재하거나 함 자체에 야간 발함 능력이 있으면 야전에서 항모 야간 항공 공격(야습 CI)을 발동할 수 있습니다.",
      "With night aircraft (fighters/torpedo bombers) and 夜間作戦航空要員, or built-in night launch capability, a carrier can perform a night air attack (night cut-in).",
    ),
    "当前仅表示编成与耐久等静态条件匹配；实际发动还受阵型、联合舰队状态和本次出击中的使用次数限制。": (
      "目前僅表示編成與耐久等靜態條件匹配；實際發動還受陣型、聯合艦隊狀態和本次出擊中的使用次數限制。",
      "編成・耐久などの静的条件の一致のみを示します。実際の発動は陣形・連合艦隊の状態・今回の出撃中の使用回数にも制限されます。",
      "편성과 내구 등 정적 조건의 충족 여부만 표시합니다. 실제 발동은 진형, 연합함대 상태, 이번 출격에서의 사용 횟수에도 제한됩니다.",
      "This only indicates that static conditions such as composition and HP are met. Actual activation also depends on formation, combined fleet status and the number of uses during this sortie.",
    ),
    "Nelson 级旗舰的特殊攻击编成。": (
      "Nelson 級旗艦的特殊攻擊編成。",
      "Nelson級を旗艦とする特殊攻撃編成です。",
      "Nelson급을 기함으로 하는 특수 공격 편성입니다.",
      "Special attack composition with a Nelson-class flagship.",
    ),
    "长门改二旗舰的特殊攻击编成。": (
      "長門改二旗艦的特殊攻擊編成。",
      "長門改二を旗艦とする特殊攻撃編成です。",
      "長門改二를 기함으로 하는 특수 공격 편성입니다.",
      "Special attack composition with 長門改二 as flagship.",
    ),
    "陆奥改二旗舰的特殊攻击编成。": (
      "陸奧改二旗艦的特殊攻擊編成。",
      "陸奥改二を旗艦とする特殊攻撃編成です。",
      "陸奥改二를 기함으로 하는 특수 공격 편성입니다.",
      "Special attack composition with 陸奥改二 as flagship.",
    ),
    "Colorado 级旗舰的特殊攻击编成。": (
      "Colorado 級旗艦的特殊攻擊編成。",
      "Colorado級を旗艦とする特殊攻撃編成です。",
      "Colorado급을 기함으로 하는 특수 공격 편성입니다.",
      "Special attack composition with a Colorado-class flagship.",
    ),
    "大和改二／武藏改二旗舰的特殊攻击编成。": (
      "大和改二／武藏改二旗艦的特殊攻擊編成。",
      "大和改二／武蔵改二を旗艦とする特殊攻撃編成です。",
      "大和改二／武蔵改二를 기함으로 하는 특수 공격 편성입니다.",
      "Special attack composition with 大和改二／武蔵改二 as flagship.",
    ),
    "金刚级改二丙／榛名改二乙系旗舰的夜战特殊攻击编成。": (
      "金剛級改二丙／榛名改二乙系旗艦的夜戰特殊攻擊編成。",
      "金剛型改二丙／榛名改二乙系を旗艦とする夜戦特殊攻撃編成です。",
      "金剛改二丙급／榛名改二乙 계열을 기함으로 하는 야전 특수 공격 편성입니다.",
      "Night special attack composition with a 金剛改二丙-class or 榛名改二乙-series flagship.",
    ),
    "Warspite改与Valiant改组成的特殊攻击编成。": (
      "Warspite改與Valiant改組成的特殊攻擊編成。",
      "Warspite改とValiant改による特殊攻撃編成です。",
      "Warspite改와 Valiant改로 구성된 특수 공격 편성입니다.",
      "Special attack composition with Warspite改 and Valiant改.",
    ),
    "Richelieu改／Deux与Jean Bart改组成的特殊攻击编成。": (
      "Richelieu改／Deux與Jean Bart改組成的特殊攻擊編成。",
      "Richelieu改／DeuxとJean Bart改による特殊攻撃編成です。",
      "Richelieu改／Deux와 Jean Bart改로 구성된 특수 공격 편성입니다.",
      "Special attack composition with Richelieu改／Deux and Jean Bart改.",
    ),
    "潜水母舰旗舰与潜水舰僚舰的特殊攻击编成。": (
      "潛水母艦旗艦與潛水艦僚艦的特殊攻擊編成。",
      "潜水母艦旗艦と潜水艦僚艦による特殊攻撃編成です。",
      "잠수모함 기함과 잠수함 동료함으로 구성된 특수 공격 편성입니다.",
      "Special attack composition with a submarine tender flagship and submarine consorts.",
    ),
    "当前状态": ("目前狀態", "現在の状態", "현재 상태", "Current status"),
    "泊地修理已计时": (
      "泊地修理已計時",
      "泊地修理の経過時間",
      "정박지 수리 경과 시간",
      "Anchorage repair elapsed",
    ),
    "可修理数量": ("可修理數量", "修理可能隻数", "수리 가능 척수", "Repair capacity"),
    "HP 修理准备就绪": ("HP 修理準備就緒", "HP修理の準備完了", "HP 수리 준비 완료", "HP repair ready"),
    "HP 修理未就绪": (
      "HP 修理未就緒",
      "HP修理の準備未完了",
      "HP 수리 준비 미완료",
      "HP repair not ready",
    ),
    "泊地修理状态": ("泊地修理狀態", "泊地修理の状態", "정박지 수리 상태", "Anchorage repair status"),
    "单位修理时间": ("單位修理時間", "1HPあたりの修理時間", "HP 1당 수리 시간", "Repair time per HP"),
    "预计已回复": ("預計已回復", "推定回復量", "예상 회복량", "Estimated HP recovered"),
    "修理已完成": ("修理已完成", "修理完了", "수리 완료", "Repair complete"),
    "正在修理中": ("正在修理中", "修理中", "수리 중", "Repairing"),
    "母港给粮就绪中": (
      "母港給糧就緒中",
      "母港での給糧準備完了",
      "모항 급양 준비 완료",
      "Ready to supply food at port",
    ),
    "刷闪计时": ("刷閃計時", "キラ付けの経過時間", "반짝이 작업 경과 시간", "Sparkling elapsed"),
    "预估消耗": ("預估消耗", "推定消費量", "예상 소모량", "Estimated cost"),
    "预估满闪 (54)": (
      "預估滿閃 (54)",
      "Cond 54到達予測",
      "컨디션 54 도달 예상",
      "Estimated time to Cond 54",
    ),
    "单次增量": ("單次增量", "1回あたりの増加量", "1회 증가량", "Increase per cycle"),
    "已达成 54": ("已達成 54", "Cond 54達成", "컨디션 54 달성", "Cond 54 reached"),
    "刷闪中": ("刷閃中", "キラ付け中", "반짝이 작업 중", "Sparkling"),
    "泊地修理中": ("泊地修理中", "泊地修理中", "정박지 수리 중", "Anchorage repair in progress"),
    "泊地修理·刷闪中": (
      "泊地修理·刷閃中",
      "泊地修理・キラ付け中",
      "정박지 수리·반짝이 작업 중",
      "Anchorage repair / sparkling",
    ),
    "已刷闪": ("已刷閃", "キラ付け完了", "반짝이 작업 완료", "Sparkled"),
    "给粮舰": ("給糧艦", "給糧艦", "급양함", "Food supply ship"),
    "条件不符": ("條件不符", "条件未達成", "조건 미충족", "Conditions not met"),
    "未就绪": ("未就緒", "準備未完了", "준비 미완료", "Not ready"),
    "入渠中": ("入渠中", "入渠中", "입거 중", "In repair dock"),
    "入渠修理": ("入渠修理", "入渠修理", "입거 수리", "Dock repair"),
    "野埼刷闪": ("野埼刷閃", "野埼キラ付け", "노사키 반짝이 작업", "Nosaki sparkling"),
    "有效": ("有效", "有効", "유효", "Active"),
    "长": ("長", "長", "장", "Long"),
    "超长": ("超長", "超長", "초장", "Very long"),
    "超长＋": ("超長＋", "超長＋", "초장＋", "Very long+"),
    "恢复默认": ("恢復預設", "初期設定に戻す", "기본값 복원", "Restore defaults"),
    "筛选显示项目": ("篩選顯示項目", "表示項目を選択", "표시 항목 선택", "Select visible items"),
    "泊地修理计时": ("泊地修理計時", "泊地修理タイマー", "정박지 수리 타이머", "Anchorage repair timer"),
    "野埼刷闪计时": (
      "野埼刷閃計時",
      "野埼キラ付けタイマー",
      "노사키 반짝이 작업 타이머",
      "Nosaki sparkling timer",
    ),
    "选择顶部显示项目": (
      "選擇頂部顯示項目",
      "上部の表示項目を選択",
      "상단 표시 항목 선택",
      "Select header items",
    ),
    "泊地计时": ("泊地計時", "泊地タイマー", "정박지 타이머", "Anchorage timer"),
    "野埼计时": ("野埼計時", "野埼タイマー", "노사키 타이머", "Nosaki timer"),
    "需Cond≥49": ("需Cond≥49", "Cond≥49が必要", "Cond≥49 필요", "Requires Cond≥49"),
    "锁": ("鎖", "ロック", "잠금", "Locked"),
    "舰队不存在": ("艦隊不存在", "艦隊が存在しません", "함대가 존재하지 않습니다", "Fleet does not exist"),
    "舰队为空": ("艦隊為空", "艦隊が空です", "함대가 비어 있습니다", "Fleet is empty"),
    "未配置野埼（需在第1或第2位）": (
      "未配置野埼（需在第1或第2位）",
      "野埼が未配置（1番艦または2番艦に配置）",
      "노사키 미배치(1번함 또는 2번함에 배치 필요)",
      "Nosaki is not assigned (must be ship 1 or 2)",
    ),
    "未配置野埼": ("未配置野埼", "野埼が未配置", "노사키 미배치", "Nosaki is not assigned"),
    "舰队处于远征中": ("艦隊處於遠征中", "艦隊が遠征中", "함대가 원정 중입니다", "Fleet is on expedition"),
    "野埼正在入渠修理中": (
      "野埼正在入渠修理中",
      "野埼が入渠修理中",
      "노사키가 입거 수리 중입니다",
      "Nosaki is in a repair dock",
    ),
    "野埼未满补给（需满油弹）": (
      "野埼未滿補給（需滿油彈）",
      "野埼の補給不足（燃料・弾薬の全補給が必要）",
      "노사키 보급 부족(연료·탄약 완전 보급 필요)",
      "Nosaki is not fully supplied (full fuel and ammo required)",
    ),
    "野埼有破损（需完全无伤）": (
      "野埼有破損（需完全無傷）",
      "野埼が損傷中（無傷であることが必要）",
      "노사키 손상(손상이 없어야 함)",
      "Nosaki is damaged (must be undamaged)",
    ),
    "给粮舰主体": ("給糧艦主體", "給糧艦本人", "급양함 본인", "Food supply ship itself"),
    "伴随舰入渠中": (
      "隨伴艦入渠中",
      "随伴艦が入渠中",
      "수반함 입거 중",
      "Accompanying ship in repair dock",
    ),
    "已达成 54 薄闪": ("已達成 54 薄閃", "Cond 54達成", "컨디션 54 달성", "Cond 54 reached"),
    "母港刷闪中": ("母港刷閃中", "母港でキラ付け中", "모항에서 반짝이 작업 중", "Sparkling at port"),
    "刷闪": ("刷閃", "キラ付け", "반짝이 작업", "Sparkling"),
    "出击中": ("出擊中", "出撃中", "출격 중", "On sortie"),
    "已返母港": ("已返母港", "母港帰投済み", "모항 귀환 완료", "Returned to port"),
  };
  final translated = labels[source];
  if (translated != null) {
    return en
        ? translated.$4
        : ko
        ? translated.$3
        : ja
        ? translated.$2
        : translated.$1;
  }
  const templates = <(String, String, String, String, String)>[
    (
      r"^当前配装预估发动概率约为 (\d+)%。$",
      "目前配裝預估發動概率約為 {0}%。",
      "現在の装備での推定発動率は約{0}%です。",
      "현재 장비 구성의 예상 발동 확률은 약 {0}%입니다.",
      "Estimated activation chance with the current equipment: about {0}%.",
    ),
    (r"^展开(.+)$", "展開{0}", "{0}を展開", "{0} 펼치기", "Expand {0}"),
    (r"^折叠(.+)$", "摺疊{0}", "{0}を折りたたむ", "{0} 접기", "Collapse {0}"),
    (r"^疲劳 (\d+)$", "士氣 {0}", "コンディション {0}", "컨디션 {0}", "Morale {0}"),
    (
      r"^(\d+) 艘（修理设施 X (\d+)）$",
      "{0} 艘（修理設施 X {1}）",
      "{0}隻（修理施設 × {1}）",
      "{0}척(수리 시설 × {1})",
      "Ships: {0} (repair facilities × {1})",
    ),
    (
      r"^(\d+) 艘（(\d+) $",
      "{0} 艘（{1} ",
      "{0}隻（{1} ",
      "{0}척({1} ",
      "Ships: {0} ({1} ",
    ),
    (r"^/次）$", "/次）", "/回）", "/회)", "/cycle)"),
    (r"^0 艘$", "0 艘", "0隻", "0척", "Ships: 0"),
    (
      r"^(\d+) 分 \((\d+)次\)$",
      "{0} 分（{1}次）",
      "{0}分（{1}回）",
      "{0}분({1}회)",
      "{0} min ({1} cycles)",
    ),
    (r"^(\d+)号舰$", "{0}號艦", "{0}番艦", "{0}번함", "Ship {0}"),
    (r"^(\d+)号位$", "{0}號位", "{0}番艦", "{0}번 위치", "Position {0}"),
    (r"^泊地：(.*)$", "泊地：{0}", "泊地：{0}", "정박지: {0}", "Anchorage: {0}"),
    (r"^野埼：(.*)$", "野埼：{0}", "野埼：{0}", "노사키: {0}", "Nosaki: {0}"),
    (r"^战果：(.*)$", "戰果：{0}", "戦果：{0}", "전과: {0}", "Senka: {0}"),
    (
      r"^刷闪中 \(★(\d+)\)$",
      "刷閃中 (★{0})",
      "キラ付け中 (★{0})",
      "반짝이 작업 중 (★{0})",
      "Sparkling (★{0})",
    ),
    (
      r"^已刷闪 \(★(\d+)\)$",
      "已刷閃 (★{0})",
      "キラ付け済み (★{0})",
      "반짝이 작업 완료 (★{0})",
      "Sparkled (★{0})",
    ),
    (
      r"^给粮舰 \(★(\d+)\)$",
      "給糧艦 (★{0})",
      "給糧艦 (★{0})",
      "급양함 (★{0})",
      "Food supply ship (★{0})",
    ),
  ];
  for (final template in templates) {
    final match = RegExp(template.$1).firstMatch(source);
    if (match == null) continue;
    var result = en
        ? template.$5
        : ko
        ? template.$4
        : ja
        ? template.$3
        : template.$2;
    if (en && template.$1 == r"^(\d+) 分 \((\d+)次\)$" && match[2] == '1') {
      result = result.replaceFirst('cycles', 'cycle');
    }
    for (var i = 1; i <= match.groupCount; i++) {
      result = result.replaceAll("{${i - 1}}", match.group(i) ?? "");
    }
    return result;
  }
  final rateLabel = RegExp(r'^(先反|对空|喷2|夜袭|特攻) (\d+%)$').firstMatch(source);
  if (rateLabel != null) {
    return '${fleetText(context, rateLabel[1]!)} ${rateLabel[2]}';
  }
  return source;
}

String fleetMechanismDescription(BuildContext context, String source) {
  final translatedDescription = source.splitMapJoin(
    RegExp(r'[^。\n]+。|[^。\n]+(?=\n)'),
    onMatch: (match) {
      final sentence = match[0]!;
      final leading = RegExp(r'^\s*').stringMatch(sentence) ?? '';
      final original = sentence.trimLeft();
      final translated = fleetText(context, original);
      final needsSpace =
          Localizations.maybeLocaleOf(context)?.languageCode == 'en' &&
          translated != original &&
          sentence.endsWith('。') &&
          match.end < source.length &&
          !RegExp(r'\s').hasMatch(source[match.end]);
      return '$leading$translated${needsSpace ? ' ' : ''}';
    },
  );
  return gameNames(context).entityText(translatedDescription);
}
