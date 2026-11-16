import 'package:flutter/widgets.dart';

/// Canonical game difficulty codes; these are stored as data across locales.
const compositionDifficultyCodes = <String>['甲', '乙', '丙', '丁'];

/// Labels owned by the composition image feature; game-provided names stay intact.
class CompositionImageStrings {
  const CompositionImageStrings(this.locale);

  factory CompositionImageStrings.of(BuildContext context) =>
      CompositionImageStrings(
        Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
      );

  final Locale locale;
  String _text(String zh, String hant, String ja, String ko, String en) =>
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

  String get title =>
      _text('编成记录', '編成記錄', '編成記録', '편성 기록', 'Composition records');
  String get luck => _text('运', '運', '運', '운', 'Luck');
  String get savedTab => _text('已保存', '已儲存', '保存済み', '저장됨', 'Saved');
  String get currentTab =>
      _text('当前编成', '目前編成', '現在の編成', '현재 편성', 'Current composition');
  String get newRecord => _text('新建记录', '新增記錄', '新規記録', '새 기록', 'New record');
  String get recordSave => _text(
    '保存编队记录',
    '儲存編隊記錄',
    '編成記録を保存',
    '편성 기록 저장',
    'Save composition record',
  );
  String get recordSaved => _text(
    '编队记录已保存。',
    '編隊記錄已儲存。',
    '編成記録を保存しました。',
    '편성 기록을 저장했습니다.',
    'Composition record saved.',
  );
  String get recordLimitReached => _text(
    '已经达到最大记录数量',
    '已達到記錄數量上限',
    '記録件数の上限に達しました',
    '기록 수가 상한에 도달했습니다',
    'The record limit has been reached',
  );
  String get exportImage =>
      _text('导出图片', '匯出圖片', '画像を書き出す', '이미지 내보내기', 'Export image');
  String get fleetForm =>
      _text('编队形式', '編隊形式', '編成形式', '편성 형태', 'Fleet formation');
  String get targetMap => _text('目标海域', '目標海域', '目標海域', '목표 해역', 'Target map');
  String get noTargetMap =>
      _text('无目标海域', '無目標海域', '目標海域なし', '목표 해역 없음', 'No target map');
  String get normalMap =>
      _text('常规海域', '通常海域', '通常海域', '일반 해역', 'Regular maps');
  String get eventMap =>
      _text('活动海域', '活動海域', 'イベント海域', '이벤트 해역', 'Event maps');
  String get chooseMap => _text(
    '请选择常规海域',
    '請選擇通常海域',
    '通常海域を選択',
    '일반 해역을 선택하세요',
    'Select a regular map',
  );
  String get eventMapHint => _text(
    '例如：2026 夏活 E3-3',
    '例如：2026 夏活 E3-3',
    '例：2026 夏 E3-3',
    '예: 2026 여름 이벤트 E3-3',
    'Example: Summer 2026 E3-3',
  );
  String get difficulty => _text(
    '难度（可选）',
    '難度（可選）',
    '難易度（任意）',
    '난이도(선택 사항)',
    'Difficulty (optional)',
  );
  String get recordName =>
      _text('编队名称', '編隊名稱', '編成名', '편성 이름', 'Composition name');
  String get recordNameHint => _text(
    '自由填写编队名称',
    '自由填寫編隊名稱',
    '編成名を自由に入力',
    '편성 이름을 자유롭게 입력하세요',
    'Enter a composition name',
  );
  String get normalNameHint =>
      _text('例如：任务编队', '例如：任務編隊', '例：任務編成', '예: 임무 편성', 'Example: Quest fleet');
  String get eventNameHint => _text(
    '例如：斩杀编队',
    '例如：斬殺編隊',
    '例：最終編成',
    '예: 최종 공략 편성',
    'Example: Final clear fleet',
  );
  String get finalRecordName =>
      _text('保存后名称', '儲存後名稱', '保存後の名前', '저장할 이름', 'Name when saved');
  String get nameRequired => _text(
    '请填写编队名称。',
    '請填寫編隊名稱。',
    '編成名を入力してください。',
    '편성 이름을 입력하세요.',
    'Enter a composition name.',
  );
  String get search => _text(
    '搜索编队名称或海域',
    '搜尋編隊名稱或海域',
    '編成名・海域を検索',
    '편성 이름 또는 해역 검색',
    'Search composition names or maps',
  );
  String get compactSearch =>
      _text('搜索记录', '搜尋記錄', '記録を検索', '기록 검색', 'Search records');
  String get searchShort => _text('搜索', '搜尋', '検索', '검색', 'Search');
  String get filterRecords => _text('筛选', '篩選', '絞り込み', '필터', 'Filter');
  String get filterTitle => _text(
    '按海域筛选记录',
    '依海域篩選記錄',
    '海域で記録を絞り込む',
    '해역별 기록 필터',
    'Filter records by map',
  );
  String get allRecords =>
      _text('全部记录', '全部記錄', 'すべての記録', '모든 기록', 'All records');
  String normalArea(int id) => switch (id) {
    1 => _text('镇守府海域', '鎮守府海域', '鎮守府海域', '鎮守府海域', '鎮守府海域'),
    2 => _text('南西群岛海域', '南西群島海域', '南西諸島海域', '南西諸島海域', '南西諸島海域'),
    3 => _text('北方海域', '北方海域', '北方海域', '北方海域', '北方海域'),
    4 => _text('西方海域', '西方海域', '西方海域', '西方海域', '西方海域'),
    5 => _text('南方海域', '南方海域', '南方海域', '南方海域', '南方海域'),
    6 => _text('中部海域', '中部海域', '中部海域', '中部海域', '中部海域'),
    7 => _text('南西海域', '南西海域', '南西海域', '南西海域', '南西海域'),
    _ => area(id),
  };
  String get noRecords => _text(
    '还没有编队记录',
    '尚無編隊記錄',
    '編成記録はまだありません',
    '아직 편성 기록이 없습니다',
    'No composition records yet',
  );
  String get recordLoadFailed => _text(
    '读取编队记录失败。',
    '讀取編隊記錄失敗。',
    '編成記録を読み込めませんでした。',
    '편성 기록을 불러오지 못했습니다.',
    'Could not load composition records.',
  );
  String get recordImageUnavailable => _text(
    '记录图片无法读取。',
    '記錄圖片無法讀取。',
    '記録画像を読み込めませんでした。',
    '기록 이미지를 불러오지 못했습니다.',
    'Could not load the saved image.',
  );
  String get retry => _text('重试', '重試', '再試行', '다시 시도', 'Retry');
  String get noMatches => _text(
    '没有找到匹配的记录。',
    '找不到符合的記錄。',
    '該当する記録がありません。',
    '일치하는 기록이 없습니다.',
    'No matching records found.',
  );
  String get selectRecord => _text(
    '选择一条记录，即可查看当时保存的编成。',
    '選擇記錄即可查看儲存時的編成。',
    '記録を選択すると保存時の編成を表示します。',
    '기록을 선택하면 저장 당시의 편성을 볼 수 있습니다.',
    'Select a record to view the composition saved at that time.',
  );
  String get deleteRecord =>
      _text('删除记录', '刪除記錄', '記録を削除', '기록 삭제', 'Delete record');
  String get deleteQuestion => _text(
    '删除这条记录？',
    '刪除此記錄？',
    'この記録を削除しますか？',
    '이 기록을 삭제할까요?',
    'Delete this record?',
  );
  String get deleteHint => _text(
    '删除后无法找回，已导出的图片不会受影响。',
    '刪除後無法復原，已匯出的圖片不受影響。',
    '削除すると元に戻せません。書き出した画像には影響しません。',
    '삭제한 기록은 복구할 수 없습니다. 내보낸 이미지에는 영향을 주지 않습니다.',
    'Deleted records cannot be recovered. Exported images will be kept.',
  );
  String get cancel => _text('取消', '取消', 'キャンセル', '취소', 'Cancel');
  String get unnamed =>
      _text('未命名编队', '未命名編隊', '無題の編成', '이름 없는 편성', 'Untitled composition');
  String get mapRequired => _text(
    '请先选择或填写目标海域。',
    '請先選擇或填寫目標海域。',
    '目標海域を選択または入力してください。',
    '먼저 목표 해역을 선택하거나 입력하세요.',
    'Select or enter a target map first.',
  );
  String get operationFailed => _text(
    '操作失败，请重试。',
    '操作失敗，請重試。',
    '操作に失敗しました。',
    '작업에 실패했습니다. 다시 시도하세요.',
    'The operation failed. Please try again.',
  );
  String get recordDeleted =>
      _text('记录已删除。', '記錄已刪除。', '記録を削除しました。', '기록을 삭제했습니다.', 'Record deleted.');
  List<String> get fleetForms => [
    _text('普通舰队', '普通艦隊', '通常艦隊', '일반 함대', 'Normal fleet'),
    _text('支援舰队', '支援艦隊', '支援艦隊', '지원 함대', 'Support fleet'),
    _text('水上打击部队', '水上打擊部隊', '水上打撃部隊', '수상타격부대', 'Surface task force'),
    _text('空母机动部队', '空母機動部隊', '空母機動部隊', '항모기동부대', 'Carrier task force'),
    _text('输送护卫部队', '輸送護衛部隊', '輸送護衛部隊', '수송호위부대', 'Transport escort force'),
    _text('游击部队', '遊擊部隊', '遊撃部隊', '유격부대', 'Striking force'),
  ];

  /// Older snapshots only retain the label in the locale used at save time.
  static bool isLegacyCombinedFleetForm(String label) {
    final trimmed = label.trim();
    if (trimmed == '运送护卫部队' || trimmed == '運送護衛部隊') return true;
    const locales = [
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('ja'),
      Locale('ko'),
      Locale('en'),
    ];
    return locales.any(
      (locale) => CompositionImageStrings(
        locale,
      ).fleetForms.getRange(2, 5).contains(trimmed),
    );
  }

  String get subtitle => _text(
    '把此刻的舰队，保存成一张图。',
    '把此刻的艦隊，儲存成一張圖。',
    '今の艦隊を、一枚の画像に。',
    '현재 함대를 이미지 한 장으로 저장하세요.',
    'Save the current fleet in a single image.',
  );
  String get save =>
      _text('保存编成图', '儲存編成圖', '編成画像を保存', '편성 이미지 저장', 'Save composition image');
  String get saving => _text('正在保存…', '正在儲存…', '保存中…', '저장 중…', 'Saving…');
  String get saved => _text(
    '编成图已保存到相册。',
    '編成圖已儲存至相簿。',
    '編成画像をアルバムに保存しました。',
    '편성 이미지를 앨범에 저장했습니다.',
    'Composition image saved to the gallery.',
  );
  String get saveFailed => _text(
    '编成图保存失败，请重试。',
    '編成圖儲存失敗，請重試。',
    '編成画像を保存できませんでした。もう一度お試しください。',
    '편성 이미지를 저장하지 못했습니다. 다시 시도하세요.',
    'Could not save the composition image. Please try again.',
  );
  String get permissionDenied => _text(
    '需要相册存储权限才能保存编成图。',
    '需要相簿儲存權限才能儲存編成圖。',
    '編成画像の保存にはストレージの権限が必要です。',
    '편성 이미지를 저장하려면 앨범 저장 권한이 필요합니다.',
    'Gallery storage permission is required to save composition images.',
  );
  String get selection =>
      _text('显示内容', '顯示內容', '表示する内容', '표시 내용', 'Display content');
  String get fleets => _text('舰队', '艦隊', '艦隊', '함대', 'Fleet');
  String get airBaseTitle =>
      _text('基地航空队', '基地航空隊', '基地航空隊', '기지항공대', 'Land-based air squadron');
  String get noAirBase => _text(
    '不使用航空队',
    '不使用航空隊',
    '基地航空隊を使用しない',
    '항공대 사용 안 함',
    'No air squadrons',
  );
  String get noAirBases => _text(
    '打开游戏中的基地航空队后即可加入编成图。',
    '開啟遊戲中的基地航空隊後即可加入編成圖。',
    'ゲーム内で基地航空隊を開くと、画像に追加できます。',
    '게임에서 기지항공대를 열면 편성 이미지에 추가할 수 있습니다.',
    'Open land-based air squadrons in the game to add them to the image.',
  );
  String get planeCounts =>
      _text('搭载数', '搭載數', '搭載数', '탑재 수', 'Aircraft count');
  String get hidden => _text('隐藏', '隱藏', '非表示', '숨기기', 'Hide');
  String get current => _text('当前', '目前', '現在', '현재', 'Current');
  String get maximum => _text('最大', '最大', '最大', '최대', 'Maximum');
  String get preview =>
      _text('图片预览', '圖片預覽', '画像プレビュー', '이미지 미리보기', 'Image preview');
  String get previewHint => _text(
    '保存完整高清图片，包含下方全部编成。',
    '儲存完整高畫質圖片，包含下方全部編成。',
    '下の編成をすべて含む高画質の画像を保存します。',
    '아래 모든 편성을 포함한 고화질 이미지를 저장합니다.',
    'Save a full-resolution image containing all compositions below.',
  );
  String get emptySelection => _text(
    '请选择要保存的舰队或陆航。',
    '請選擇要儲存的艦隊或陸航。',
    '保存する艦隊または基地航空隊を選択してください。',
    '저장할 함대 또는 기지항공대를 선택하세요.',
    'Select fleets or land-based air squadrons to save.',
  );
  String get emptyFleet =>
      _text('暂无舰娘', '暫無艦娘', '艦がいません', '함선이 없습니다', 'No ships');
  String get waitingForPort => _text(
    '等待母港数据',
    '等待母港資料',
    '母港データを待っています',
    '모항 데이터 대기 중',
    'Waiting for home port data',
  );
  String get waitingForEquipment => _text(
    '等待完整装备数据',
    '等待完整裝備資料',
    '装備データを待っています',
    '전체 장비 데이터 대기 중',
    'Waiting for complete equipment data',
  );
  String get refreshingShips => _text(
    '正在更新舰娘数据…',
    '正在更新艦娘資料…',
    '艦データを更新しています…',
    '함선 데이터 갱신 중…',
    'Updating ship data…',
  );
  String get emptySlot => _text('未装备', '未裝備', '未装備', '미장착', 'Unequipped');
  String slot(int index) => _text(
    '装备 $index',
    '裝備 $index',
    '装備 $index',
    '장비 $index',
    'Equipment $index',
  );
  String get expansionSlot =>
      _text('增设', '增設', '補強増設', '보강증설', 'Expansion slot');
  String squadron(int index) => _text(
    '中队 $index',
    '中隊 $index',
    '第 $index 中隊',
    '제$index 중대',
    'Squadron $index',
  );
  String get missingShip => _text(
    '舰娘数据未就绪',
    '艦娘資料未就緒',
    '艦データ未取得',
    '함선 데이터가 준비되지 않았습니다',
    'Ship data is not ready',
  );
  String get missingEquipment => _text(
    '装备数据未就绪',
    '裝備資料未就緒',
    '装備データ未取得',
    '장비 데이터가 준비되지 않았습니다',
    'Equipment data is not ready',
  );
  String get footer => _text(
    'Yahagi · 编成记录',
    'Yahagi · 編成記錄',
    'Yahagi · 編成記録',
    'Yahagi · 편성 기록',
    'Yahagi · Composition records',
  );
  String fleet(int id) =>
      _text('第 $id 舰队', '第 $id 艦隊', '第 $id 艦隊', '제$id함대', 'Fleet $id');
  String landBase(int id) => _text(
    '第 $id 航空队',
    '第 $id 航空隊',
    '第 $id 航空隊',
    '제$id 항공대',
    'Air squadron $id',
  );
  String area(int id) =>
      _text('海域 $id', '海域 $id', '海域 $id', '해역 $id', 'Map $id');
  String level(int value) => 'Lv. $value';
  String range(int value) => _text(
    '航程 $value',
    '航程 $value',
    '行動半径 $value',
    '행동 반경 $value',
    'Combat radius $value',
  );
  String landBaseCount(int value) => locale.languageCode == 'en' && value == 1
      ? '1 land-based air squadron'
      : _text(
          '$value 队陆航',
          '$value 隊陸航',
          '基地航空隊 $value 隊',
          '기지항공대 $value개',
          '$value land-based air squadrons',
        );
  String baseMode(int kind) => switch (kind) {
    1 => _text('出击', '出擊', '出撃', '출격', 'Sortie'),
    2 => _text('防空', '防空', '防空', '방공', 'Air defense'),
    3 => _text('退避', '退避', '退避', '퇴피', 'Evacuate'),
    4 => _text('休息', '休息', '休息', '휴식', 'Rest'),
    _ => _text('待机', '待機', '待機', '대기', 'Standby'),
  };
}
