import 'package:flutter/widgets.dart';

class ExpCalcStrings {
  ExpCalcStrings(BuildContext context)
    : locale = Localizations.localeOf(context);
  final Locale locale;
  String text(String zh, String hant, String ja, String ko, String en) =>
      locale.languageCode == 'en'
      ? en
      : locale.languageCode == 'ko'
      ? ko
      : locale.languageCode == 'ja'
      ? ja
      : locale.scriptCode == 'Hant' ||
            const ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? hant
      : zh;

  String get target =>
      text('舰娘与目标', '艦娘與目標', '艦娘と目標', '함선과 목표', 'Ship and target');
  String get selectShip =>
      text('选择舰娘', '選擇艦娘', '艦娘を選択', '함선 선택', 'Select ship');
  String get route => text('出击路线', '出擊路線', '出撃ルート', '출격 경로', 'Sortie route');
  String get result => text('计算结果', '計算結果', '計算結果', '계산 결과', 'Results');
  String get average =>
      text('平均基础经验', '平均基礎經驗', '平均基本経験値', '평균 기본 경험치', 'Average base EXP');
  String get manual =>
      text('手动基础经验', '手動基礎經驗', '基本経験値を入力', '기본 경험치 직접 입력', 'Manual base EXP');
  String get addNode =>
      text('添加战斗点', '新增戰鬥點', '戦闘マスを追加', '전투 지점 추가', 'Add battle node');
  String get addTrack =>
      text('加入追踪', '加入追蹤', '追跡に追加', '추적에 추가', 'Add to tracker');
  String get estimated =>
      text('预计出击次数', '預計出擊次數', '推定出撃回数', '예상 출격 횟수', 'Estimated sorties');
  String get perSortie =>
      text('每轮经验', '每輪經驗', '出撃ごとの経験値', '출격당 경험치', 'EXP per sortie');
  String get subtotal =>
      text('本点收益', '本點收益', '獲得経験値', '이 지점의 획득 경험치', 'EXP from this node');
  String get total => text('总收益', '總收益', '合計経験値', '총 획득 경험치', 'Total EXP');
  String get custom => text('自定义', '自訂', 'カスタム', '사용자 지정', 'Custom');
  String get exercise => text(
    '演习（手动输入）',
    '演習（手動輸入）',
    '演習（手動入力）',
    '연습전(직접 입력)',
    'Exercise (manual entry)',
  );
  String get equalWeight => text(
    '各编成等权平均，含最终形态；结果为估算。',
    '各編成等權平均，含最終形態；結果為估算。',
    '最終形態を含む各編成の単純平均による概算です。',
    '최종 형태를 포함한 각 편성의 단순 평균으로 계산한 추정치입니다.',
    'Estimates use an equally weighted average of all compositions, including final forms.',
  );
  String coverage(int known, int total) => text(
    '已知 $known / $total 种编成',
    '已知 $known / $total 種編成',
    '$total 編成中 $known 編成の経験値が判明',
    '$total개 편성 중 $known개 확인',
    '$known of $total compositions known',
  );
  String get incomplete => text(
    '部分经验缺失，仅按已知编成估算',
    '部分經驗缺失，僅按已知編成估算',
    '経験値不明の編成を除いた概算',
    '경험치가 확인된 편성만으로 계산한 추정치',
    'Some EXP data is missing; estimates use known compositions only',
  );
  String get unknown => text(
    '暂无经验资料，请手动输入',
    '暫無經驗資料，請手動輸入',
    '経験値不明・手動で入力してください',
    '경험치 정보가 없습니다. 직접 입력하세요',
    'No EXP data available. Enter a value manually',
  );
  String get invalid => text(
    '请输入有效的非负经验值',
    '請輸入有效的非負經驗值',
    '0 以上の有効な経験値を入力してください',
    '0 이상의 유효한 경험치를 입력하세요',
    'Enter a valid EXP value of 0 or more',
  );
  String get restore =>
      text('恢复平均值', '恢復平均值', '平均値に戻す', '평균값으로 복원', 'Restore average');
  String get unavailable => text(
    '请补全点位经验后计算',
    '請補全點位經驗後計算',
    '各マスの経験値を入力してください',
    '각 지점의 경험치를 입력한 후 계산하세요',
    'Enter EXP for every node before calculating',
  );
  String get zero => text(
    '当前路线无法获得经验',
    '目前路線無法獲得經驗',
    'このルートでは経験値を獲得できません',
    '현재 경로에서는 경험치를 얻을 수 없습니다',
    'This route does not yield EXP',
  );
  String get loading => text(
    '正在读取海域资料…',
    '正在讀取海域資料…',
    '海域データを読み込み中…',
    '해역 데이터 불러오는 중…',
    'Loading map data…',
  );
  String get loadFailed => text(
    '海域资料读取失败，可重试或手动输入',
    '海域資料讀取失敗，可重試或手動輸入',
    '海域データの読み込みに失敗しました。再試行または手動入力してください',
    '해역 데이터를 불러오지 못했습니다. 다시 시도하거나 직접 입력하세요',
    'Could not load map data. Retry or enter EXP manually',
  );
  String get retry => text('重试', '重試', '再試行', '다시 시도', 'Retry');
  String get times => text('次', '次', '回', '회', 'times');
  String get shared =>
      text('全路线通用', '全路線通用', '全マス共通', '모든 지점에 적용', 'Apply to all nodes');
  String get details =>
      text('单点设置', '單點設定', 'マス個別設定', '지점별 설정', 'Node settings');
  String get base => text('基础经验', '基礎經驗', '基本経験値', '기본 경험치', 'Base EXP');
  String get roundedHint => text(
    '各编成平均，四舍五入至 10 的倍数',
    '各編成平均，四捨五入至 10 的倍數',
    '各編成の平均を、一の位で四捨五入した値',
    '각 편성의 평균을 10 단위로 반올림',
    'Average across compositions, rounded to the nearest 10',
  );
}
