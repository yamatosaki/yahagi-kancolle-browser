import 'package:flutter/widgets.dart';
import '../theme/app_palette.dart';

class UiText extends StatelessWidget {
  const UiText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => Text(
    uiText(context, data),
    style: appTextStyle(context, style),
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
    softWrap: softWrap,
  );
}

/// Translates app-owned legacy labels at the display boundary. Stored values,
/// filter identities and game-provided names stay in their original form.
String uiText(BuildContext context, String source) => uiTextForLocale(
  Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
  source,
);

String uiTextForLocale(Locale locale, String source) {
  final japanese = locale.languageCode == 'ja';
  final korean = locale.languageCode == 'ko';
  final english = locale.languageCode == 'en';
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale.countryCode));
  if (!japanese && !traditional && !korean && !english) return source;
  final entry = uiTextTranslations[source];
  if (entry != null) {
    return english
        ? entry.$4
        : korean
        ? entry.$3
        : japanese
        ? entry.$2
        : entry.$1;
  }
  final furnitureBox = RegExp(r'^家具箱（(.+)）$').firstMatch(source);
  final templateSource = furnitureBox == null
      ? source
      : '家具箱(${furnitureBox[1]})';
  for (final template in _templates) {
    final match = template.$1.firstMatch(templateSource);
    if (match == null) continue;
    return (english
            ? template.$5
            : korean
            ? template.$4
            : japanese
            ? template.$3
            : template.$2)
        .replaceAllMapped(RegExp(r'\{(\d+)\}'), (slot) {
          final argument = match.group(int.parse(slot[1]!))!;
          final translated = uiTextForLocale(locale, argument);
          if ((english || korean) && template.$1.pattern == r'^家具箱\((.+)\)$') {
            return switch (argument) {
              '小' => korean ? '소' : 'small',
              '中' => korean ? '중' : 'medium',
              '大' => korean ? '대' : 'large',
              _ => argument,
            };
          }
          // Record types are UI labels, while unknown arguments retain case.
          return english &&
                  template.$1.pattern == r'^筛选(.+)记录$' &&
                  uiTextTranslations.containsKey(argument)
              ? argument == '资源'
                    ? 'resource'
                    : translated.toLowerCase()
              : translated;
        });
  }
  return source;
}

final _templates = <(RegExp, String, String, String, String)>[
  (RegExp(r'^共 (\d+) 条$'), '共 {1} 條', '全 {1} 件', '총 {1}건', 'Total: {1}'),
  (
    RegExp(r'^筛选(.+)记录$'),
    '篩選{1}記錄',
    '{1}記録の絞り込み',
    '{1} 기록 필터',
    'Filter {1} records',
  ),
  (RegExp(r'^路线 (.+)$'), '路線 {1}', 'ルート {1}', '경로 {1}', 'Route {1}'),
  (
    RegExp(r'^改修消耗（(.+)）$'),
    '改修消耗（{1}）',
    '改修消費（{1}）',
    '개수 소모({1})',
    'Improvement cost ({1})',
  ),
  (
    RegExp(r'^缺少 (\d+) 艘$'),
    '缺少 {1} 艘',
    '{1}隻不足',
    '{1}척 부족',
    'Missing ships: {1}',
  ),
  (
    RegExp(r'^家具箱\((.+)\)$'),
    '家具箱（{1}）',
    '家具箱（{1}）',
    '가구 상자({1})',
    'Furniture box ({1})',
  ),
  (RegExp(r'^道具 (\d+)$'), '道具 {1}', 'アイテム {1}', '아이템 {1}', 'Item {1}'),
];

const uiTextTranslations = <String, (String, String, String, String)>{
  '全部': ('全部', 'すべて', '전체', 'All'),
  '周一': ('週一', '月曜', '월요일', 'Mon'),
  '周二': ('週二', '火曜', '화요일', 'Tue'),
  '周三': ('週三', '水曜', '수요일', 'Wed'),
  '周四': ('週四', '木曜', '목요일', 'Thu'),
  '周五': ('週五', '金曜', '금요일', 'Fri'),
  '周六': ('週六', '土曜', '토요일', 'Sat'),
  '周日': ('週日', '日曜', '일요일', 'Sun'),
  '搜索装备': ('搜尋裝備', '装備を検索', '장비 검색', 'Search equipment'),
  '搜索装备名称': ('搜尋裝備名稱', '装備名を検索', '장비 이름 검색', 'Search equipment names'),
  '筛选装备': ('篩選裝備', '装備を絞り込み', '장비 필터', 'Filter equipment'),
  '清除': ('清除', 'クリア', '지우기', 'Clear'),
  '完成': ('完成', '完了', '완료', 'Done'),
  '全部清除': ('全部清除', 'すべてクリア', '모두 지우기', 'Clear all'),
  '装备分类': ('裝備分類', '装備分類', '장비 분류', 'Equipment category'),
  '进化状态': ('進化狀態', '更新可否', '갱신 가능 여부', 'Upgrade availability'),
  '可进化': ('可進化', '更新可能', '갱신 가능', 'Upgradeable'),
  '不可进化': ('不可進化', '更新不可', '갱신 불가', 'Not upgradeable'),
  '收藏': ('收藏', 'お気に入り', '즐겨찾기', 'Favorites'),
  '装备名字': ('裝備名字', '装備名', '장비 이름', 'Equipment name'),
  '基础消耗': ('基礎消耗', '基本消費', '기본 소모', 'Base cost'),
  '进化消耗': ('進化消耗', '更新消費', '갱신 소모', 'Upgrade cost'),
  '秘书舰': ('秘書艦', '秘書艦', '비서함', 'Secretary ship'),
  '进化装备': ('進化裝備', '更新先装備', '갱신 장비', 'Upgrade result'),
  '每次': ('每次', '毎回', '매회', 'per attempt'),
  '当天没有符合条件的改修装备': (
    '當天沒有符合條件的改修裝備',
    'この日に条件に合う改修装備はありません',
    '해당 요일에는 조건에 맞는 개수 장비가 없습니다',
    'No equipment matches the improvement conditions on this day',
  ),
  '关闭筛选': ('關閉篩選', '絞り込みを閉じる', '필터 닫기', 'Close filters'),
  '重置': ('重設', 'リセット', '초기화', 'Reset'),
  '应用': ('套用', '適用', '적용', 'Apply'),
  '日期': ('日期', '日付', '날짜', 'Date'),
  '海域': ('海域', '海域', '해역', 'Area'),
  '状态': ('狀態', '状態', '상태', 'Status'),
  '评价': ('評價', '評価', '평가', 'Rank'),
  '远征': ('遠征', '遠征', '원정', 'Expedition'),
  '结果': ('結果', '結果', '결과', 'Result'),
  '道具': ('道具', 'アイテム', '아이템', 'Item'),
  '建造类型': ('建造類型', '建造種別', '건조 유형', 'Construction type'),
  '舰种': ('艦種', '艦種', '함종', 'Ship type'),
  '装备类型': ('裝備類型', '装備種別', '장비 유형', 'Equipment type'),
  '类型': ('類型', '種別', '유형', 'Type'),
  '全部日期': ('全部日期', 'すべての日付', '모든 날짜', 'All dates'),
  '最近 7 天': ('最近 7 天', '過去7日間', '최근 7일', 'Last 7 days'),
  '最近 30 天': ('最近 30 天', '過去30日間', '최근 30일', 'Last 30 days'),
  '全部海域': ('全部海域', 'すべての海域', '모든 해역', 'All areas'),
  '全部状态': ('全部狀態', 'すべての状態', '모든 상태', 'All statuses'),
  '全部评价': ('全部評價', 'すべての評価', '모든 평가', 'All ranks'),
  '全部远征': ('全部遠征', 'すべての遠征', '모든 원정', 'All expeditions'),
  '全部结果': ('全部結果', 'すべての結果', '모든 결과', 'All results'),
  '全部道具': ('全部道具', 'すべてのアイテム', '모든 아이템', 'All items'),
  '全部类型': ('全部類型', 'すべての種別', '모든 유형', 'All types'),
  '全部舰种': ('全部艦種', 'すべての艦種', '모든 함종', 'All ship types'),
  '全部秘书舰': ('全部秘書艦', 'すべての秘書艦', '모든 비서함', 'All secretary ships'),
  '大成功': ('大成功', '大成功', '대성공', 'Great success'),
  '成功': ('成功', '成功', '성공', 'Success'),
  '失败': ('失敗', '失敗', '실패', 'Failure'),
  '有道具': ('有道具', 'アイテムあり', '아이템 있음', 'With items'),
  '无道具': ('無道具', 'アイテムなし', '아이템 없음', 'Without items'),
  '普通建造': ('普通建造', '通常建造', '일반 건조', 'Normal construction'),
  '大型建造': ('大型建造', '大型艦建造', '대형함 건조', 'Large ship construction'),
  '建造': ('建造', '建造', '건조', 'Construction'),
  '开发': ('開發', '開発', '개발', 'Development'),
  '出击': ('出擊', '出撃', '출격', 'Sortie'),
  '退役': ('退役', '退役', '퇴역', 'Retirement'),
  '改修': ('改修', '近代化改修', '근대화개수', 'Modernization'),
  '解体': ('解體', '解体', '해체', 'Dismantling'),
  '资源': ('資源', '資源', '자원', 'Resources'),
  '舰娘': ('艦娘', '艦娘', '칸무스', 'Ship'),
  '开发装备': ('開發裝備', '開発装備', '장비 개발', 'Equipment development'),
  '时间': ('時間', '時刻', '시각', 'Time'),
  '燃料': ('燃料', '燃料', '연료', 'Fuel'),
  '弹药': ('彈藥', '弾薬', '탄약', 'Ammo'),
  '钢材': ('鋼材', '鋼材', '강재', 'Steel'),
  '铝土': ('鋁土', 'ボーキサイト', '보크사이트', 'Bauxite'),
  '铝土矿': ('鋁土礦', 'ボーキサイト', '보크사이트', 'Bauxite'),
  '高速建造材': ('高速建造材', '高速建造材', '고속건조재', 'Instant construction material'),
  '高速修复材': ('高速修復材', '高速修復材', '고속수복재', 'Instant repair material'),
  '开发资材': ('開發資材', '開発資材', '개발자재', 'Development material'),
  '改修资材': ('改修資材', '改修資材', '개수자재', 'Improvement material'),
  '礼物箱': ('禮物箱', 'プレゼント箱', '선물 상자', 'Gift box'),
  '(大成功获得)': (
    '（大成功獲得）',
    '（大成功時に獲得）',
    '(대성공 시 획득)',
    '(Obtained on great success)',
  ),
  '(有几率获得)': ('（有機率獲得）', '（確率で獲得）', '(확률로 획득)', '(Chance to obtain)'),
  '装备': ('裝備', '装備', '장비', 'Equipment'),
  '未获得': ('未獲得', '未獲得', '미획득', 'Not obtained'),
  '节点': ('節點', 'マス', '지점', 'Node'),
  '敌舰队': ('敵艦隊', '敵艦隊', '적 함대', 'Enemy fleet'),
  '掉落': ('掉落', 'ドロップ', '드롭', 'Drop'),
  '旗舰': ('旗艦', '旗艦', '기함', 'Flagship'),
  '二队旗舰': ('二隊旗艦', '第二艦隊旗艦', '제2함대 기함', 'Second fleet flagship'),
  '二队 MVP': ('二隊 MVP', '第二艦隊 MVP', '제2함대 MVP', 'Second fleet MVP'),
  '旧版记录': ('舊版記錄', '旧形式の記録', '이전 형식의 기록', 'Legacy record'),
  '演习': ('演習', '演習', '연습전', 'Exercise'),
  '除籍': ('除籍', '除籍', '제적', 'Removal'),
  '暂无记录': ('暫無記錄', '記録はありません', '기록이 없습니다', 'No records'),
  '未知舰种': ('未知艦種', '不明な艦種', '알 수 없는 함종', 'Unknown ship type'),
  '未知装备': ('未知裝備', '不明な装備', '알 수 없는 장비', 'Unknown equipment'),
  '小口径主炮': ('小口徑主炮', '小口径主砲', '소구경 주포', 'Small-caliber main gun'),
  '中口径主炮': ('中口徑主炮', '中口径主砲', '중구경 주포', 'Medium-caliber main gun'),
  '大口径主炮': ('大口徑主炮', '大口径主砲', '대구경 주포', 'Large-caliber main gun'),
  '副炮': ('副炮', '副砲', '부포', 'Secondary gun'),
  '鱼雷': ('魚雷', '魚雷', '어뢰', 'Torpedo'),
  '舰上战斗机': ('艦上戰鬥機', '艦上戦闘機', '함상전투기', 'Carrier fighter'),
  '舰上爆击机': ('艦上爆擊機', '艦上爆撃機', '함상폭격기', 'Carrier dive bomber'),
  '舰上攻击机': ('艦上攻擊機', '艦上攻撃機', '함상공격기', 'Carrier torpedo bomber'),
  '舰上侦察机': ('艦上偵察機', '艦上偵察機', '함상정찰기', 'Carrier reconnaissance aircraft'),
  '水上侦察机': ('水上偵察機', '水上偵察機', '수상정찰기', 'Reconnaissance seaplane'),
  '水上爆击机': ('水上爆擊機', '水上爆撃機', '수상폭격기', 'Seaplane bomber'),
  '小型电探': ('小型電探', '小型電探', '소형 전탐', 'Small radar'),
  '大型电探': ('大型電探', '大型電探', '대형 전탐', 'Large radar'),
  '声呐': ('聲納', 'ソナー', '소나', 'Sonar'),
  '爆雷': ('爆雷', '爆雷', '폭뢰', 'Depth charge'),
  '炮弹': ('炮彈', '砲弾', '포탄', 'Shell'),
  '对空机枪': ('對空機槍', '対空機銃', '대공기총', 'Anti-aircraft machine gun'),
  '上陆用舟艇': ('上陸用舟艇', '上陸用舟艇', '상륙용 주정', 'Landing craft'),
  '潜水舰鱼雷': ('潛水艦魚雷', '潜水艦魚雷', '잠수함 어뢰', 'Submarine torpedo'),
  '其他装备': ('其他裝備', 'その他の装備', '기타 장비', 'Other equipment'),
};
