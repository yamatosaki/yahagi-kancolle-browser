import 'package:flutter/widgets.dart';

final class SortieExperienceStrings {
  SortieExperienceStrings(Locale locale)
    : _language = switch (locale.languageCode) {
        'ja' => 2,
        'ko' => 3,
        'en' => 4,
        'zh'
            when locale.scriptCode == 'Hant' ||
                const {'TW', 'HK', 'MO'}.contains(locale.countryCode) =>
          1,
        _ => 0,
      };

  final int _language;

  String _text(String zh, String hant, String ja, String ko, String en) =>
      switch (_language) {
        1 => hant,
        2 => ja,
        3 => ko,
        4 => en,
        _ => zh,
      };

  String get lastSortie =>
      _text('上次出击', '上次出擊', '前回の出撃', '지난 출격', 'Last sortie');
  String get total => _text('总累计', '總累計', '累計', '총 누적', 'Total');
  String get experienceTab => _text('经验', '經驗', '経験値', '경험치', 'EXP');
  String get consumptionTab => _text('消耗', '消耗', '消費', '소모', 'Spending');
  String get warehouseSpending => _text(
    '本轮仓库支出',
    '本輪倉庫支出',
    '今回の資材支出',
    '이번 자원 지출',
    'Warehouse spending this period',
  );
  String get resourceSort =>
      _text('资源排序', '資源排序', '資材で並べ替え', '자원 정렬', 'Sort by resource');
  String get periodSpending =>
      _text('本轮消耗', '本輪消耗', '今回の消費', '이번 소모', 'Period spending');
  String get resourceUnrecorded =>
      _text('未统计', '未統計', '記録なし', '기록 없음', 'Not recorded');
  String get resourceIncomplete => _text(
    '部分明细未捕获，仅显示已确认支出。',
    '部分明細未擷取，僅顯示已確認支出。',
    '一部の明細を取得できなかったため、確認済みの支出を表示します。',
    '일부 내역을 확인할 수 없어 확인된 지출을 표시합니다.',
    'Some details are missing. Only confirmed spending is shown.',
  );
  String get pendingSupply => _text(
    '本轮待补给',
    '本輪待補給',
    '今回の補給待ち',
    '이번 보급 대기',
    'Pending supply this period',
  );
  String get unallocatedSpending => _text(
    '补给差额，待核对',
    '補給差額，待核對',
    '補給差額・確認待ち',
    '보급 차액 · 확인 대기',
    'Supply balance difference to verify',
  );
  String shipBill(String name) => _text(
    '$name 的账单',
    '$name 的帳單',
    '$name の資材明細',
    '$name 자원 내역',
    '$name spending details',
  );
  String get supplySpending => _text(
    '出击补给支出',
    '出擊補給支出',
    '出撃の補給支出',
    '출격 보급 지출',
    'Sortie supply spending',
  );
  String get repairSpending =>
      _text('入渠与加速', '入渠與加速', '入渠と高速修復', '입거 및 고속수복', 'Repairs and buckets');
  String totalExperience(String amount) => _text(
    '合计 $amount EXP',
    '合計 $amount EXP',
    '合計 $amount EXP',
    '합계 $amount EXP',
    'Total $amount EXP',
  );
  String get sortieArea => _text('海域', '海域', '海域', '해역', 'Map');
  String get sortieFleet => _text('出击舰队', '出擊艦隊', '出撃艦隊', '출격 함대', 'Fleet');
  String sortieFleetExperience({required bool active}) => active
      ? _text('本次舰队合计', '本次艦隊合計', '今回の艦隊合計', '이번 함대 합계', 'Current fleet total')
      : _text('上次舰队合计', '上次艦隊合計', '前回の艦隊合計', '지난 함대 합계', 'Last fleet total');
  String get totalRecord =>
      _text('累计记录', '累計記錄', '累計記録', '누적 기록', 'Cumulative record');
  String get allShipsExperience =>
      _text('全部舰船合计', '全部艦船合計', '全艦船の合計', '전체 함선 합계', 'All ships total');
  String get ship => _text('舰船', '艦船', '艦船', '함선', 'Ship');
  String mvpTooltip({required bool total}) => total
      ? _text(
          '本轮累计的 MVP 次数。— 表示暂无数据。',
          '本輪累計的 MVP 次數。— 表示暫無資料。',
          '今回の累計MVP回数。— は記録なし。',
          '이번 누적 MVP 횟수입니다. —는 기록 없음입니다.',
          'MVP count for this tracking period. — indicates no data.',
        )
      : _text(
          '这趟出击各场战斗的 MVP 次数。— 表示暂无数据。',
          '這趟出擊各場戰鬥的 MVP 次數。— 表示暫無資料。',
          'この出撃でのMVP回数。— は記録なし。',
          '이번 출격의 MVP 횟수입니다. —는 기록 없음입니다.',
          'MVP count for this sortie. — indicates no data.',
        );
  String get active => _text('出击中', '出擊中', '出撃中', '출격 중', 'Underway');
  String get returned => _text('已返港', '已返港', '帰投済み', '귀항 완료', 'Returned');
  String get practiceActive =>
      _text('演习中', '演習中', '演習中', '연습 중', 'In exercise');
  String get settled => _text('已结算', '已結算', '結果確定', '결과 확정', 'Settled');
  String get practiceSettled =>
      _text('演习已结算', '演習已結算', '演習終了', '연습 완료', 'Exercise settled');
  String get fleetMain => _text('主力舰队', '主力艦隊', '主力艦隊', '주력 함대', 'Main fleet');
  String get fleetEscort =>
      _text('护卫舰队', '護衛艦隊', '護衛艦隊', '호위 함대', 'Escort fleet');
  String get retreated => _text('已退避', '已退避', '退避済み', '퇴피 완료', 'Retreated');
  String get unknownShip =>
      _text('未知舰船', '未知艦船', '不明な艦船', '알 수 없는 함선', 'Unknown ship');
  String get uncaptured => _text('未捕获', '未擷取', '未取得', '미수집', 'Not captured');
  String get clear => _text('清零', '歸零', 'リセット', '초기화', 'Clear');
  String get filterTitle => _text(
    '选择显示舰娘',
    '選擇顯示艦娘',
    '表示する艦娘を選択',
    '표시할 함선 선택',
    'Choose ships to show',
  );
  String get noVisibleShips => _text(
    '当前未选择显示舰娘',
    '目前未選擇顯示艦娘',
    '表示する艦娘が選択されていません',
    '표시할 함선이 선택되지 않았습니다',
    'No ships selected for display',
  );
  String get clearTitle => _text(
    '清理累计记录？',
    '清除累計記錄？',
    '累計記録をリセットしますか？',
    '누적 기록을 초기화할까요?',
    'Clear cumulative records?',
  );
  String get clearMessage => _text(
    '将清零当前账号的出击经验、MVP 次数和资源支出总累计。此操作无法撤销。',
    '將歸零目前帳號的出擊經驗、MVP 次數與資源支出總累計。此操作無法復原。',
    '現在のアカウントの累計出撃経験値、MVP回数、資材支出をリセットします。この操作は元に戻せません。',
    '현재 계정의 누적 출격 경험치, MVP 횟수, 자원 지출을 초기화합니다. 이 작업은 되돌릴 수 없습니다.',
    'This resets the current account’s cumulative sortie EXP, MVP counts, and resource spending. This action cannot be undone.',
  );
  String get tracking => _text('累计开关', '累計開關', '累計記録', '누적 기록', 'Track total');
  String get on => _text('开启', '開啟', 'オン', '켜짐', 'On');
  String get off => _text('关闭', '關閉', 'オフ', '꺼짐', 'Off');
  String get waiting =>
      _text('暂无出击记录', '暫無出擊記錄', '出撃記録なし', '출격 기록 없음', 'No sortie yet');
  String get emptyRoster =>
      _text('暂无舰船数据', '暫無艦船資料', '艦船データなし', '함선 데이터 없음', 'No ship data yet');
  String get incomplete => _text(
    '数据不完整，仅显示已确认经验',
    '資料不完整，僅顯示已確認經驗',
    '一部のデータが不足しています。確認済みの経験値のみ表示します',
    '일부 데이터가 누락되어 확인된 경험치만 표시합니다',
    'Only confirmed EXP is shown. Some data is missing.',
  );
  String get storageUnavailable => _text(
    '无法保存或读取总累计',
    '無法儲存或讀取總累計',
    '累計を読み込み・保存できません',
    '총 누적을 읽거나 저장할 수 없습니다',
    'Unable to load or save totals',
  );
  String get trackingHint => _text(
    '出击返港或演习结算后更新',
    '出擊返港或演習結算後更新',
    '出撃は帰投後、演習は結果確定後に更新します',
    '출격은 귀항 후, 연습은 결과 확정 후 갱신됩니다',
    'Updates after returning to port or finishing an exercise',
  );
  String get offHint => _text(
    '开启后开始记录逐舰经验',
    '開啟後開始記錄逐艦經驗',
    'オンにすると艦船ごとの経験値を記録します',
    '켜면 함선별 경험치를 기록합니다',
    'Enable tracking to record EXP per ship',
  );

  String battles(String count, {required bool singular}) => _text(
    '已结算 $count 场战斗',
    '已結算 $count 場戰鬥',
    '$count 戦終了',
    '$count회 전투 완료',
    '$count ${singular ? 'battle' : 'battles'} settled',
  );

  String battleCount(String count, {required bool singular}) => _text(
    '$count 场战斗',
    '$count 場戰鬥',
    '$count 戦',
    '$count회 전투',
    '$count ${singular ? 'battle' : 'battles'}',
  );

  String totalCount(String count) => _text(
    '总累计 $count 场',
    '總累計 $count 場',
    '累計 $count 回',
    '총 $count 회',
    'Total $count',
  );

  String totalUnit({required bool singular}) =>
      _text('出击', '出擊', '出撃', '출격', singular ? 'sortie' : 'sorties');

  String fleet(int id) =>
      _text('第 $id 舰队', '第 $id 艦隊', '第 $id 艦隊', '제 $id 함대', 'Fleet $id');
}
