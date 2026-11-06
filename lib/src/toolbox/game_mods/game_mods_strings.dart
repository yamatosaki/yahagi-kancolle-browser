import 'package:flutter/widgets.dart';

import 'game_mods_models.dart';
import 'game_mods_library.dart';

/// Feature-owned labels; archive names and trusted resource names remain intact.
class GameModsStrings {
  const GameModsStrings(this.locale);
  factory GameModsStrings.of(BuildContext context) => GameModsStrings(
    Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
  );
  final Locale locale;
  String get tabTitle => _t('魔改', '魔改', 'MOD', 'Mods', '모드');
  String _t(String zh, String hant, String ja, String en, String ko) =>
      switch (locale.languageCode) {
        'en' => en,
        'ja' => ja,
        'ko' => ko,
        _ =>
          locale.scriptCode == 'Hant' ||
                  const ['TW', 'HK', 'MO'].contains(locale.countryCode)
              ? hant
              : zh,
      };
  String get title => _t('魔改管理', '魔改管理', 'MOD管理', 'Mod manager', '모드 관리');
  String progressTitle(String operation) => switch (operation) {
    'scan' => _t(
      '正在扫描魔改包',
      '正在掃描魔改包',
      'MODをスキャン中',
      'Scanning mod packages',
      '모드 패키지 스캔 중',
    ),
    'directory' => _t(
      '正在准备资源文件夹',
      '正在準備資源資料夾',
      '素材フォルダーを準備中',
      'Preparing mod folder',
      '리소스 폴더 준비 중',
    ),
    _ => _t(
      '正在处理魔改包',
      '正在處理魔改包',
      'MODを処理中',
      'Processing mod packages',
      '모드 패키지 처리 중',
    ),
  };
  String progressPhase(String phase) => switch (phase) {
    'read' => _t('读取文件', '讀取檔案', 'ファイルを読み込み中', 'Reading files', '파일 읽는 중'),
    'validate' => _t(
      '校验资源',
      '驗證資源',
      '素材を検証中',
      'Validating resources',
      '리소스 검사 중',
    ),
    'import' => _t(
      '导入资源',
      '匯入資源',
      '素材をインポート中',
      'Importing resources',
      '리소스 가져오는 중',
    ),
    'save' => _t('保存结果', '儲存結果', '結果を保存中', 'Saving changes', '결과 저장 중'),
    'complete' => _t('正在完成', '正在完成', '完了処理中', 'Finishing up', '마무리 중'),
    _ => _t('查找魔改包', '尋找魔改包', 'MODを検索中', 'Finding mod packages', '모드 패키지 찾는 중'),
  };
  String progressPackages(int done, int? total) {
    final count = total == null ? '$done' : '$done / $total';
    return _t(
      '已处理 $count 个包',
      '已處理 $count 個包',
      '処理済み $count パッケージ',
      'Packages processed: $count',
      '처리한 패키지: $count',
    );
  }

  String get progressCurrentPackage =>
      _t('当前包', '目前套件', '現在のMOD', 'Current package', '현재 패키지');
  String get progressCurrentFile =>
      _t('当前文件', '目前檔案', '現在のファイル', 'Current file', '현재 파일');
  String progressFiles(int done, int? total) {
    final count = total == null ? '$done' : '$done / $total';
    return _t(
      '已处理 $count 个文件',
      '已處理 $count 個檔案',
      '処理済み $count ファイル',
      'Files processed: $count',
      '처리한 파일: $count',
    );
  }

  String progressBytes(String value) => _t(
    '已读取 $value',
    '已讀取 $value',
    '読み込み済み $value',
    'Data read: $value',
    '읽은 데이터: $value',
  );
  String progressElapsed(String value) => _t(
    '已用时间 $value',
    '已用時間 $value',
    '経過時間 $value',
    'Elapsed time $value',
    '경과 시간 $value',
  );
  String get progressWorking => _t(
    '正在处理中，完成后会自动关闭。',
    '正在處理中，完成後會自動關閉。',
    '処理中です。完了すると自動的に閉じます。',
    'Processing. This window closes automatically when finished.',
    '처리 중입니다. 완료되면 자동으로 닫힙니다.',
  );
  String get libraryTitle => _t(
    '魔改资源文件夹',
    '魔改資源資料夾',
    'MODリソースフォルダー',
    'Mod resource folder',
    '모드 리소스 폴더',
  );
  String get libraryChoose =>
      _t('选择文件夹', '選擇資料夾', 'フォルダーを選択', 'Choose folder', '폴더 선택');
  String get libraryChange =>
      _t('更换文件夹', '變更資料夾', 'フォルダーを変更', 'Change folder', '폴더 변경');
  String get libraryOpen =>
      _t('打开文件夹', '開啟資料夾', 'フォルダーを開く', 'Open folder', '폴더 열기');
  String get libraryScan =>
      _t('扫描文件夹', '掃描資料夾', 'フォルダーをスキャン', 'Scan folder', '폴더 스캔');
  String get libraryUnconfigured => _t(
    '选择公共文件夹，保存并迁移现有魔改包',
    '選擇共用資料夾，儲存並遷移現有魔改包',
    '共有フォルダーを選択し、既存のMODを移行します',
    'Choose a shared folder to save and migrate existing mods',
    '공유 폴더를 선택해 기존 모드를 저장하고 이전하세요',
  );
  String get libraryChooseHint => _t(
    '首次选择并授权“文档”（Documents）根目录后，会自动创建 Documents/Yahagi/Mods；也可选择 Documents 下已有的独立文件夹。现有包以解压目录迁移，可直接编辑。按钮导入不移动原 ZIP；库内 ZIP 在扫描确认成功后清理。卸载后目录保留，重装重新选择同一文件夹并扫描即可恢复。',
    '首次選擇並授權「文件」（Documents）根目錄後，會自動建立 Documents/Yahagi/Mods；也可選擇 Documents 下既有的獨立資料夾。現有包以解壓縮目錄遷移，可直接編輯。按鈕匯入不移動原 ZIP；庫內 ZIP 於掃描確認成功後清理。解除安裝後目錄保留，重裝後重新選擇同一資料夾並掃描即可還原。',
    '初回に「ドキュメント」（Documents）のルートフォルダーを選択してアクセスを許可すると、Documents/Yahagi/Mods を自動作成します。Documents 配下の既存の専用フォルダーも選択できます。既存のMODは編集できる展開済みフォルダーとして移行します。インポートボタンは元のZIPを移動せず、ライブラリー内のZIPはスキャンの確認成功後に削除します。アンインストール後もフォルダーは残り、再インストール後は同じ場所を選択してスキャンすると復元できます。',
    'The first time you select and grant access to the Documents root folder, Documents/Yahagi/Mods is created automatically. You can also choose an existing dedicated folder under Documents. Existing mods are saved as editable, extracted folders. The import button leaves original ZIPs in place; library ZIPs are removed after successful scan confirmation. Folders remain after uninstalling. After reinstalling, choose the same folder and scan to restore.',
    '처음에 문서(Documents) 루트 폴더를 선택하고 접근 권한을 허용하면 Documents/Yahagi/Mods 폴더를 자동으로 만듭니다. Documents 아래의 기존 전용 폴더를 선택할 수도 있습니다. 기존 모드는 편집 가능한 압축 해제 폴더로 이전합니다. 가져오기 버튼은 원본 ZIP을 옮기지 않으며 라이브러리 안의 ZIP은 스캔 확인이 완료되면 삭제합니다. 앱을 삭제해도 폴더는 유지됩니다. 재설치 후 같은 폴더를 선택하고 스캔하면 복원됩니다.',
  );
  String get libraryHint => _t(
    '只保存解压目录。放入 ZIP 或修改文件后手动扫描；库内 ZIP 确认成功后清理。应用后保存开关与优先级。',
    '僅儲存解壓縮目錄。放入 ZIP 或修改檔案後手動掃描；庫內 ZIP 確認成功後清理。套用後儲存開關與優先順序。',
    '展開済みフォルダーだけを保存します。ZIPの追加やファイルの編集後は手動でスキャンし、確認成功後にライブラリー内のZIPを削除します。設定と優先順位は適用後に保存します。',
    'Keep extracted folders only. Scan after adding ZIPs or editing files; library ZIPs are removed after successful confirmation. Apply to save switches and priority.',
    '압축을 푼 폴더만 저장합니다. ZIP 추가나 파일 수정 후 수동으로 스캔하세요. 확인이 완료되면 라이브러리 안의 ZIP을 삭제합니다. 선택과 우선순위는 적용 후 저장됩니다.',
  );
  String librarySavedCount(int n) => _t(
    '已保存 $n 个包',
    '已儲存 $n 個包',
    '$n 件保存済み',
    '$n saved ${n == 1 ? 'package' : 'packages'}',
    '패키지 $n개 저장됨',
  );
  String get libraryReview =>
      _t('扫描结果', '掃描結果', 'スキャン結果', 'Scan results', '스캔 결과');
  String get libraryScanHint => _t(
    '新包默认关闭；更新保留已有选择和优先级。确认后仍需“应用并刷新游戏”。',
    '新包預設關閉；更新保留現有選擇和優先順序。確認後仍需「套用並重新整理遊戲」。',
    '新しいMODはオフで追加し、更新時は設定と優先順位を維持します。確認後に「適用してゲームを再読み込み」を押してください。',
    'New packages start disabled; updates retain your choices and priority. Confirm, then use Apply & reload game.',
    '새 패키지는 꺼진 상태로 추가되며 업데이트 시 선택과 우선순위를 유지합니다. 확인한 뒤 적용 후 게임 새로고침을 누르세요.',
  );
  String get libraryRestoreHint => _t(
    '发现之前保存的搭配。确认后将恢复开关、资源选择和优先级，应用后生效。',
    '找到先前儲存的搭配。確認後將還原開關、資源選擇和優先順序，套用後生效。',
    '保存済みの組み合わせが見つかりました。確認するとオン／オフ・素材の選択・優先順位を復元し、適用後に反映します。',
    'A saved setup was found. Confirm to restore switches, resource choices and priority, then apply to activate it.',
    '저장된 설정을 찾았습니다. 확인하면 켜기/끄기, 리소스 선택 및 우선순위를 복원하며 적용 후 반영됩니다.',
  );
  String libraryCleanupHint(int n) => _t(
    '确认成功后清理 $n 个库内 ZIP，仅保留解压目录。',
    '確認成功後清理 $n 個庫內 ZIP，僅保留解壓縮目錄。',
    '確認が正常に完了すると、ライブラリー内の ZIP $n 件を削除し、展開済みフォルダーだけを残します。',
    'After successful confirmation, remove $n ZIP files from this library and keep the extracted folders.',
    '확인이 완료되면 라이브러리 안의 ZIP $n개를 삭제하고 압축을 푼 폴더만 유지합니다.',
  );
  String get libraryMissingHint => _t(
    '缺失或异常的文件不会自动删除现有包，当前生效版本继续保留。',
    '遺失或異常的檔案不會自動刪除現有包，目前生效版本繼續保留。',
    'ファイルが見つからない場合や異常がある場合も、既存のMODと現在の適用内容を保持します。',
    'Missing or invalid files do not remove existing packages. The active version is preserved.',
    '파일이 없거나 잘못되어도 기존 패키지를 삭제하지 않으며 현재 적용된 버전을 유지합니다.',
  );
  String get libraryEmptyScan => _t(
    '未发现魔改包。请放入 ZIP 或包含游戏资源的包文件夹后重新扫描。',
    '未找到魔改包。請放入 ZIP 或包含遊戲資源的包資料夾後重新掃描。',
    'MODが見つかりません。ZIPまたはゲーム素材入りのフォルダーを追加して再スキャンしてください。',
    'No mod packages found. Add ZIPs or package folders containing game resources, then scan again.',
    '모드 패키지가 없습니다. ZIP 또는 게임 리소스가 있는 패키지 폴더를 추가한 뒤 다시 스캔하세요.',
  );
  String get libraryConfirm =>
      _t('确认扫描结果', '確認掃描結果', 'スキャン結果を確認', 'Confirm changes', '스캔 결과 확인');
  String libraryEntryKind(GameModLibraryEntryKind kind) => switch (kind) {
    GameModLibraryEntryKind.added => _t('新包', '新包', '新規', 'New', '새 패키지'),
    GameModLibraryEntryKind.updated => _t(
      '有更新',
      '有更新',
      '更新あり',
      'Updated',
      '업데이트 있음',
    ),
    GameModLibraryEntryKind.unchanged => _t(
      '无变化',
      '無變更',
      '変更なし',
      'Unchanged',
      '변경 없음',
    ),
    GameModLibraryEntryKind.duplicate => _t(
      '重复跳过',
      '重複略過',
      '重複・スキップ',
      'Duplicate; skipped',
      '중복 · 건너뜀',
    ),
    GameModLibraryEntryKind.missing => _t(
      '文件缺失',
      '檔案遺失',
      'ファイルなし',
      'Missing',
      '파일 없음',
    ),
    GameModLibraryEntryKind.invalid => _t(
      '文件异常',
      '檔案異常',
      '無効なファイル',
      'Invalid',
      '잘못된 파일',
    ),
  };
  String get subtitle => _t(
    '自由搭配本地资源，刷新后统一应用',
    '自由搭配本機資源，重新整理後統一套用',
    'ローカル素材を組み合わせ、再読み込みで適用',
    'Combine local resources, then apply together',
    '로컬 리소스를 조합하고 한 번에 적용',
  );
  String get importArchive =>
      _t('导入魔改包', '匯入魔改包', 'MODをインポート', 'Import mod ZIP', '모드 ZIP 가져오기');
  String get headerIntro => _t(
    '自由搭配使用魔改资源',
    '自由搭配使用魔改資源',
    'MOD素材を自由に組み合わせ',
    'Mix and match mod resources',
    '모드 리소스를 자유롭게 조합',
  );
  String get importHint => _t(
    '支持 cache.zip、标准游戏 PNG / MP3 / WAV 及舰娘坐标 INI / JSON 资源 ZIP',
    '支援 cache.zip、標準遊戲 PNG / MP3 / WAV 及艦娘座標 INI / JSON 資源 ZIP',
    'cache.zip、標準ゲーム PNG / MP3 / WAV、艦娘座標 INI / JSON のZIPに対応',
    'Choose a cache.zip or a ZIP of standard game PNG / MP3 / WAV and ship coordinate INI / JSON files',
    'cache.zip, 표준 게임 PNG / MP3 / WAV, 함선 좌표 INI / JSON 리소스 ZIP 지원',
  );
  String get master =>
      _t('使用魔改资源', '使用魔改資源', 'MOD素材を使用', 'Use mod resources', '모드 리소스 사용');
  String get preserve => _t(
    '暂停使用时，保留各包与资源选择',
    '暫停使用時，保留各包與資源選擇',
    'オフにしても各MOD・素材の選択は保持',
    'Turning this off preserves package and resource choices',
    '꺼도 패키지와 리소스 선택은 유지됩니다',
  );
  String get syncPortraits => _t(
    '同步到软件界面',
    '同步至軟體介面',
    'アプリ画面にも反映',
    'Sync portraits to app',
    '앱 화면에 이미지 동기화',
  );
  String get syncPortraitsHint => _t(
    '编队简报、舰娘详情和持有一览',
    '編隊簡報、艦娘詳情和持有一覽',
    '編成サマリー・艦娘詳細・所持一覧',
    'Fleet summary, ship details and owned inventory',
    '함대 요약, 함선 상세 및 보유 목록',
  );
  String get syncPortraitsHelp => _t(
    '界面同步开关立即生效，使用当前已应用的魔改立绘。关闭后，编队简报、舰娘详情和持有一览恢复原版头像，不影响游戏内的魔改。',
    '介面同步開關立即生效，使用目前已套用的魔改立繪。關閉後，編隊簡報、艦娘詳情和持有一覽恢復原版頭像，不影響遊戲內的魔改。',
    '画面への反映設定はすぐに有効になり、適用済みのMOD画像を使用します。オフにすると編成サマリー・艦娘詳細・所持一覧の画像を元に戻します。ゲーム内のMODには影響しません。',
    'Interface sync takes effect immediately and uses currently applied mod portraits. Turning it off restores original portraits in the fleet summary, ship details and owned inventory without affecting in-game mods.',
    '화면 동기화는 즉시 적용되며 현재 적용된 모드 이미지를 사용합니다. 끄면 함대 요약, 함선 상세 및 보유 목록이 원본 이미지로 돌아갑니다. 게임 내 모드에는 영향을 주지 않습니다.',
  );
  String get syncPortraitsSaveFailed => _t(
    '界面同步设置未能保存，请重试',
    '介面同步設定未能儲存，請重試',
    '画面への反映設定を保存できません。もう一度お試しください',
    'Could not save interface sync. Please try again.',
    '화면 동기화 설정을 저장하지 못했습니다. 다시 시도하세요.',
  );
  String get syncPortraitsLoadFailed => _t(
    '界面同步设置未能读取，请重新选择',
    '介面同步設定未能讀取，請重新選擇',
    '画面への反映設定を読み込めません。設定を選び直してください',
    'Could not load interface sync. Please select it again.',
    '화면 동기화 설정을 불러오지 못했습니다. 다시 선택하세요.',
  );
  String get current => _t('当前游戏', '目前遊戲', '現在のゲーム', 'Current game', '현재 게임');
  String get original => _t(
    '使用原版资源',
    '使用原版資源',
    'オリジナル素材を使用',
    'Using original resources',
    '원본 리소스 사용 중',
  );
  String supplied(int n) => _t(
    '已完整提供 $n 项替换资源',
    '已完整提供 $n 項替換資源',
    '$n 件の置換素材を全体提供済み',
    '$n complete replacement ${n == 1 ? 'resource' : 'resources'} provided',
    '대체 리소스 $n개 전체 제공됨',
  );
  String partialProvided(int n) => _t(
    '已提供 $n 项语音的部分数据',
    '已提供 $n 項語音的部分資料',
    '$n 件の音声データを一部提供済み',
    '$n voice ${n == 1 ? 'resource' : 'resources'} partially provided',
    '음성 리소스 $n개의 일부 데이터 제공됨',
  );
  String telemetry(
    int full,
    int partial, {
    int coordinates = 0,
    int coordinatePending = 0,
  }) {
    final labels = [
      if (full > 0) supplied(full),
      if (partial > 0) partialProvided(partial),
      if (coordinates > 0) coordinatesWrittenCount(coordinates),
      if (coordinatePending > 0) coordinatesWaitingCount(coordinatePending),
    ];
    return labels.isEmpty ? noHits : labels.join(' · ');
  }

  String get coordinatesWritten => _t(
    '已写入游戏坐标',
    '已寫入遊戲座標',
    'ゲーム座標へ書き込み済み',
    'Written to game coordinates',
    '게임 좌표에 기록됨',
  );
  String get coordinatesWaiting => _t(
    '已启用，等待游戏坐标确认',
    '已啟用，等待遊戲座標確認',
    '有効・ゲーム座標の確認待ち',
    'Enabled; waiting for game coordinate confirmation',
    '활성화됨 · 게임 좌표 확인 대기',
  );
  String get coordinatesInactive => _t(
    '当前未启用坐标修改',
    '目前未啟用座標修改',
    '現在は座標変更を使用していません',
    'Coordinate changes are currently inactive',
    '현재 좌표 변경이 비활성 상태입니다',
  );
  String get coordinatesOn =>
      _t('配置已开启', '設定已開啟', '設定オン', 'Configuration on', '설정 켜짐');
  String get coordinatesOff =>
      _t('配置已关闭', '設定已關閉', '設定オフ', 'Configuration off', '설정 꺼짐');
  String get coordinatesFailed => _t(
    '游戏坐标写入失败，请重新应用或查看日志',
    '遊戲座標寫入失敗，請重新套用或檢視日誌',
    'ゲーム座標の更新に失敗しました。再適用またはログを確認してください',
    'Game coordinate update failed; apply again or check the logs',
    '게임 좌표 업데이트에 실패했습니다. 다시 적용하거나 로그를 확인하세요',
  );
  String get coordinateSources => _t(
    '查看坐标来源文件',
    '檢視座標來源檔案',
    '座標の元ファイルを表示',
    'View coordinate sources',
    '좌표 원본 파일 보기',
  );
  String get coordinatesCompatible => _t(
    'INI / JSON 是同一坐标配置的兼容格式，作为一项统一切换；图片和语音独立选择',
    'INI / JSON 是同一座標設定的相容格式，作為一項統一切換；圖片與語音獨立選擇',
    'INI / JSON は同じ座標設定の互換形式です。1項目として切り替え、画像・音声は個別に選択します',
    'INI / JSON are compatible sources for one coordinate configuration; images and voices remain independent',
    'INI / JSON은 같은 좌표 설정의 호환 형식입니다. 하나로 전환하며 이미지와 음성은 개별 선택합니다',
  );
  String coordinatesWrittenCount(int n) => _t(
    '已写入 $n 组游戏坐标',
    '已寫入 $n 組遊戲座標',
    'ゲーム座標 $n 組を書き込み済み',
    '$n coordinate ${n == 1 ? 'group' : 'groups'} written',
    '게임 좌표 $n개 그룹 기록됨',
  );
  String coordinatesWaitingCount(int n) => _t(
    '$n 组坐标等待游戏确认',
    '$n 組座標等待遊戲確認',
    '座標 $n 組はゲーム確認待ち',
    '$n coordinate ${n == 1 ? 'group' : 'groups'} awaiting game confirmation',
    '좌표 $n개 그룹 게임 확인 대기',
  );
  String coordinateOverridden(int n, int total) => _t(
    n == total ? '全部坐标被覆盖（$n 项）' : '部分坐标被覆盖（$n/$total 项）',
    n == total ? '全部座標被覆蓋（$n 項）' : '部分座標被覆蓋（$n/$total 項）',
    '座標 $total 項目中 $n 項目は他のMODが優先',
    '$n of $total coordinate fields overridden',
    '좌표 $total개 중 $n개가 다른 패키지로 대체됨',
  );
  String coordinateAdopted(int n, int total, {bool pending = false}) => _t(
    '${pending ? '下次应用' : '配置采用'}：本包 $n/$total 项坐标',
    '${pending ? '下次套用' : '設定採用'}：本包 $n/$total 項座標',
    '${pending ? '次回適用' : '設定'}：本MODの座標 $n/$total 項目',
    '${pending ? 'After applying' : 'Configured'}: $n/$total fields from this package',
    '${pending ? '적용 후' : '설정'}: 이 패키지의 좌표 $n/$total개',
  );
  String get noHits =>
      _t('尚无加载记录', '尚無載入記錄', '読み込み記録なし', 'No load recorded yet', '아직 로드 기록 없음');
  String get help => _t('状态怎么看？', '如何看狀態？', '状態の見方', 'About statuses', '상태 안내');
  String get helpBody => _t(
    '开关是已保存的选择，待应用时当前游戏仍使用上一次配置，刷新后统一生效。\n\n标准游戏路径下的 MP3 / WAV 语音需使用游戏的数字编号，支持单独选择和分段读取。WAV 支持 PCM 或 32 位 IEEE 浮点编码。完整提供表示整个文件的数据已提供；部分提供表示实际提供了部分语音数据。两者都不保证已绘制或播放。尚无加载记录表示尚未遇到相关请求，不等于失败。\n\n坐标 INI / JSON 合为一项，必须关联到包内舰娘图片。开启只表示配置选择；游戏确认写入后才显示“已写入游戏坐标”。上方包按坐标字段优先，其余字段可由下方包补充。关闭或移除后应用并刷新，恢复对应原版坐标。',
    '開關是已儲存的選擇，待套用時目前遊戲仍使用上一次設定，重新整理後統一生效。\n\n標準遊戲路徑下的 MP3 / WAV 語音需使用遊戲的數字編號，支援單獨選擇與分段讀取。WAV 支援 PCM 或 32 位元 IEEE 浮點編碼。完整提供表示整個檔案的資料已提供；部分提供表示實際提供了部分語音資料。兩者都不保證已繪製或播放。尚無載入記錄表示尚未遇到相關請求，不等於失敗。\n\n座標 INI / JSON 合為一項，必須關聯到包內艦娘圖片。開啟只表示設定選擇；遊戲確認寫入後才顯示「已寫入遊戲座標」。上方包依座標欄位優先，其餘欄位可由下方包補充。關閉或移除後套用並重新整理，恢復對應原版座標。',
    'スイッチは保存した選択です。適用待ちの間は以前の設定を使用し、再読み込みでまとめて反映します。\n\n標準ゲームパスの MP3 / WAV 音声にはゲームの数字IDを使用し、個別選択と分割読み込みに対応します。WAV は PCM または 32 ビット IEEE 浮動小数点エンコードに対応します。全体提供はファイル全体、一部提供は音声の一部を実際に提供した記録です。描画・再生済みを保証しません。記録がない場合は対象の要求がまだ発生していない可能性があります。\n\n座標 INI / JSON は1項目にまとめ、MOD内の艦娘画像に関連付けます。オンは設定の選択です。ゲームが書き込みを確認した場合のみ書き込み済みと表示します。上のMODが座標項目ごとに優先され、残りは下のMODが補います。オフ・削除後に適用して再読み込みすると元の座標に戻します。',
    'Switches are saved choices. The game uses its previous configuration until you apply and reload.\n\nMP3 / WAV voices at standard game paths must use numeric game IDs and support individual selection and partial range reads. WAV supports PCM or 32-bit IEEE floating-point encoding. Complete means the whole file was supplied; partial means some voice bytes were actually supplied. Neither proves a resource was drawn or played. No load record means the game has not requested it yet.\n\nCoordinate INI / JSON sources form one configuration bound to ship images in the package. Switching it on selects the configuration; only confirmation from the game marks it as written. Higher packages win each coordinate field; lower packages may fill other fields. Disable or remove, then apply and reload to restore the corresponding original coordinates.',
    '스위치는 저장된 선택입니다. 적용 대기 중에는 이전 설정을 사용하며 새로고침하면 한 번에 반영됩니다.\n\n표준 게임 경로의 MP3 / WAV 음성은 게임의 숫자 ID를 사용해야 하며 개별 선택과 부분 범위 읽기를 지원합니다. WAV는 PCM 또는 32비트 IEEE 부동 소수점 인코딩을 지원합니다. 전체 제공은 파일 전체를, 일부 제공은 실제 음성 데이터의 일부를 제공한 기록입니다. 표시나 재생을 보장하지 않습니다. 로드 기록이 없으면 관련 요청이 아직 없을 수 있습니다.\n\n좌표 INI / JSON은 패키지의 함선 이미지와 연결된 하나의 설정입니다. 켜짐은 설정 선택이며 게임이 기록을 확인한 후에만 기록됨을 표시합니다. 위쪽 패키지가 좌표 필드별로 우선하며 나머지는 아래쪽 패키지가 채울 수 있습니다. 끄거나 삭제한 뒤 적용하고 새로고침하면 해당 원본 좌표로 복원됩니다.',
  );
  String get all => _t('全部', '全部', 'すべて', 'All', '전체');
  String get enabled => _t('已开启', '已開啟', 'オン', 'Enabled', '켜짐');
  String get disabled => _t('已关闭', '已關閉', 'オフ', 'Disabled', '꺼짐');
  String get issues => _t('需处理', '需處理', '要確認', 'Needs attention', '확인 필요');
  String get orderHint => _t(
    '上方的包优先 · 重叠资源会标出来源',
    '上方的包優先 · 重疊資源會標出來源',
    '上のMODが優先・重複素材の提供元を表示',
    'Higher packages take priority; overlaps show their source',
    '위쪽 패키지 우선 · 중복 리소스의 제공처 표시',
  );
  String get empty => _t(
    '还没有魔改包',
    '尚無魔改包',
    'MODはまだありません',
    'No mod packages yet',
    '모드 패키지가 없습니다',
  );
  String get noMatches => _t(
    '没有符合筛选的魔改包',
    '沒有符合篩選的魔改包',
    '該当するMODはありません',
    'No packages match this filter',
    '필터에 맞는 패키지가 없습니다',
  );
  String get details =>
      _t('资源与顺序', '資源與順序', '素材と優先順位', 'Resources & priority', '리소스 및 우선순위');
  String get unsaved =>
      _t('选择未保存', '選擇未儲存', '選択は未保存', 'Choices not saved', '선택이 저장되지 않음');
  String get saved =>
      _t('选择已保存', '選擇已儲存', '選択を保存済み', 'Choices saved', '선택 저장됨');
  String get saving => _t('正在保存…', '正在儲存…', '保存中…', 'Saving…', '저장 중…');
  String get pending =>
      _t('有设置等待应用', '有設定等待套用', '変更の適用待ち', 'Changes pending', '변경 사항 적용 대기');
  String get pendingHint => _t(
    '当前游戏仍使用上一次配置',
    '目前遊戲仍使用上一次設定',
    '現在のゲームは以前の設定を使用中',
    'The current game still uses the previous configuration',
    '현재 게임은 이전 설정을 사용합니다',
  );
  String get pendingRemovalHint => _t(
    '应用后删除，点「取消」可撤回本次修改',
    '套用後刪除，點「取消」可復原本次修改',
    '削除は適用後に実行されます。「キャンセル」で変更を取り消せます',
    'Deletion happens after applying. Cancel restores your previous choices.',
    '적용 후 삭제됩니다. 취소하면 이전 설정으로 돌아갑니다.',
  );
  String get cancelChangesHint => _t(
    '撤回全部未应用的修改，包括删除、开关和优先级',
    '復原全部尚未套用的修改，包括刪除、開關和優先順序',
    '削除・オン／オフ・優先順位を含む未適用の変更をすべて取り消す',
    'Discard all unapplied changes, including removals, switches and priority',
    '삭제, 켜기/끄기 및 우선순위 등 적용 전 변경 사항을 모두 취소',
  );
  String get applied => _t('已应用', '已套用', '適用済み', 'Applied', '적용됨');
  String get apply => _t(
    '应用并刷新游戏',
    '套用並重新整理遊戲',
    '適用してゲームを再読み込み',
    'Apply & reload game',
    '적용 후 게임 새로고침',
  );
  String get working => _t('正在处理…', '正在處理…', '処理中…', 'Working…', '처리 중…');
  String get close => _t('关闭', '關閉', '閉じる', 'Close', '닫기');
  String get cancel => _t('取消', '取消', 'キャンセル', 'Cancel', '취소');
  String get retry => _t('重试保存', '重試儲存', '保存を再試行', 'Retry saving', '저장 재시도');
  String get viewPath =>
      _t('查看资源路径', '檢視資源路徑', '素材パスを表示', 'View resource path', '리소스 경로 보기');
  String get selectAll => _t('全部选择', '全部選擇', 'すべて選択', 'Select all', '모두 선택');
  String get deselectAll =>
      _t('全部取消', '全部取消', 'すべて解除', 'Deselect all', '모두 해제');
  String get grouped => _t(
    '关联资源必须一起启用或关闭',
    '關聯資源必須一起啟用或關閉',
    '関連する素材はまとめて切り替えます',
    'Linked resources must be enabled or disabled together',
    '연결된 리소스는 함께 켜거나 끕니다',
  );
  String get up => _t('提高优先级', '提高優先順序', '優先順位を上げる', 'Move up', '우선순위 높이기');
  String get down => _t('降低优先级', '降低優先順序', '優先順位を下げる', 'Move down', '우선순위 낮추기');
  String priority(int n, int total) => _t(
    '优先级 $n/$total',
    '優先順序 $n/$total',
    '優先順位 $n/$total',
    'Priority $n/$total',
    '우선순위 $n/$total',
  );
  String resources(int n) => _t(
    '$n 项资源',
    '$n 項資源',
    '素材 $n 件',
    '$n ${n == 1 ? 'resource' : 'resources'}',
    '리소스 $n개',
  );
  String selected(int n, int total) => _t(
    '已选 $n/$total 项',
    '已選 $n/$total 項',
    '$n/$total 件を選択',
    '$n/$total selected',
    '$n/$total개 선택됨',
  );
  String overwritten(int n) =>
      _t('$n 项被覆盖', '$n 項被覆蓋', '$n 件は他のMODが優先', '$n overridden', '$n개 덮어씀');
  String source(String name, int n) => _t(
    '「$name」覆盖 $n 项',
    '「$name」覆蓋 $n 項',
    '「$name」が $n 件で優先',
    '$name overrides $n ${n == 1 ? 'resource' : 'resources'}',
    '$name에서 $n개 덮어씀',
  );
  String providedBy(String name) => _t(
    '当前由「$name」提供',
    '目前由「$name」提供',
    '現在は「$name」が提供',
    'Currently provided by $name',
    '현재 $name에서 제공',
  );
  String nextBy(String name) => _t(
    '下次应用：$name',
    '下次套用：$name',
    '次回適用：$name',
    'After applying: $name',
    '적용 후: $name',
  );
  String get inactive =>
      _t('当前未启用', '目前未啟用', '現在は未使用', 'Currently inactive', '현재 비활성');
  String get readFailed => _t(
    '本次读取失败，后续请求回退原版',
    '本次讀取失敗，後續請求回復原版',
    '読み込みに失敗・以降はオリジナルを使用',
    'Read failed; subsequent requests use the original',
    '읽기 실패 · 이후 요청은 원본 사용',
  );
  String get remove => _t('移除包', '移除包', 'MODを削除', 'Remove package', '패키지 삭제');
  String get removing => _t('待移除', '待移除', '削除待ち', 'Removal pending', '삭제 대기');
  String removeBody(String name) => _t(
    '移除「$name」？应用后删除已导入文件及魔改资源文件夹中的对应包。应用前可点底部“取消”撤回。魔改资源文件夹之外的原始 ZIP 保留。',
    '移除「$name」？套用後刪除已匯入檔案及魔改資源資料夾中的對應包。套用前可點底部「取消」復原。魔改資源資料夾之外的原始 ZIP 保留。',
    '「$name」を削除しますか？適用後にインポートファイルとMODフォルダー内の該当MODを削除します。適用前は画面下の「キャンセル」で取り消せます。MODフォルダー外の元のZIPは残ります。',
    'Remove $name? Imported files and this package in the mod folder are deleted after applying. Use Cancel at the bottom before applying to undo. Source ZIPs outside the mod folder are preserved.',
    '$name을 삭제할까요? 적용하면 가져온 파일과 모드 폴더의 해당 패키지가 삭제됩니다. 적용 전에는 화면 아래의 취소로 되돌릴 수 있습니다. 모드 폴더 밖의 원본 ZIP은 유지됩니다.',
  );
  String get reset =>
      _t('删除全部魔改', '刪除全部魔改', 'MODをすべて削除', 'Delete all mods', '모든 모드 삭제');
  String resetBody(int n) => _t(
    '将全部 $n 个魔改包标记为待删除。应用后清理已导入文件、魔改资源文件夹中的对应包和已保存搭配。应用前可点底部“取消”撤回。账号、官方资源缓存和日志保留。',
    '將全部 $n 個魔改包標記為待刪除。套用後清理已匯入檔案、魔改資源資料夾中的對應包和已儲存搭配。套用前可點底部「取消」復原。帳號、官方資源快取與日誌保留。',
    '全 $n 件のMODを削除待ちにします。適用後にインポートファイル・MODフォルダー内の該当MOD・保存済み設定を削除します。適用前は画面下の「キャンセル」で取り消せます。アカウント・公式素材キャッシュ・ログは保持します。',
    'Mark all $n packages for deletion. Applying removes imported files, their copies in the mod folder, and the saved setup. Use Cancel at the bottom before applying to undo. Accounts, official resource cache and logs are preserved.',
    '모드 패키지 $n개를 모두 삭제 대기로 표시합니다. 적용하면 가져온 파일, 모드 폴더의 해당 패키지 및 저장된 설정을 삭제합니다. 적용 전에는 화면 아래의 취소로 되돌릴 수 있습니다. 계정, 공식 리소스 캐시 및 로그는 유지됩니다.',
  );
  String get preflight =>
      _t('导入预检', '匯入預檢', 'インポートの確認', 'Import review', '가져오기 확인');
  String get importSupported => _t(
    '仅导入支持的内容',
    '僅匯入支援的內容',
    '対応素材のみインポート',
    'Import supported content only',
    '지원하는 항목만 가져오기',
  );
  String get confirmImport =>
      _t('确认导入', '確認匯入', 'インポート', 'Confirm import', '가져오기 확인');
  String get importDefault => _t(
    '新包默认关闭，排在列表下方。导入后可调整资源选择。',
    '新包預設關閉，排在清單下方。匯入後可調整資源選擇。',
    '新しいMODはオフで末尾に追加します。インポート後に素材を選択できます。',
    'New packages are disabled and added at the bottom. Choose resources after importing.',
    '새 패키지는 꺼진 상태로 목록 아래에 추가됩니다. 가져온 후 리소스를 선택할 수 있습니다.',
  );
  String preflightCounts(GameModsPreflight p) => p.fileCount != p.resourceCount
      ? _t(
          '${p.fileCount} 个文件，识别 ${p.resourceCount} 项资源：支持 ${p.supportedCount} 项，不支持 ${p.unsupportedCount} 项',
          '${p.fileCount} 個檔案，辨識 ${p.resourceCount} 項資源：支援 ${p.supportedCount} 項，不支援 ${p.unsupportedCount} 項',
          '${p.fileCount} ファイル・素材 ${p.resourceCount} 件：対応 ${p.supportedCount}・非対応 ${p.unsupportedCount}',
          '${p.fileCount} files, ${p.resourceCount} resources: ${p.supportedCount} supported, ${p.unsupportedCount} unsupported',
          '${p.fileCount}개 파일, 리소스 ${p.resourceCount}개: 지원 ${p.supportedCount}개, 미지원 ${p.unsupportedCount}개',
        )
      : _t(
          '发现 ${p.resourceCount} 项：支持 ${p.supportedCount} 项，不支持 ${p.unsupportedCount} 项',
          '發現 ${p.resourceCount} 項：支援 ${p.supportedCount} 項，不支援 ${p.unsupportedCount} 項',
          '${p.resourceCount} 件：対応 ${p.supportedCount}・非対応 ${p.unsupportedCount}',
          '${p.resourceCount} found: ${p.supportedCount} supported, ${p.unsupportedCount} unsupported',
          '${p.resourceCount}개 발견: 지원 ${p.supportedCount}개, 미지원 ${p.unsupportedCount}개',
        );
  String get unsupported => _t(
    '此平台暂不支持魔改管理',
    '此平台暫不支援魔改管理',
    'この環境ではMOD管理を利用できません',
    'Mod management is unavailable on this platform',
    '이 플랫폼에서는 모드 관리를 사용할 수 없습니다',
  );
  String reason(String? code) => switch (code) {
    'library_default_migration_conflict' => _t(
      'Mods 文件夹已存在，未覆盖任何内容。请使用“更换文件夹”选择要管理的资源目录。',
      'Mods 資料夾已存在，未覆寫任何內容。請使用「變更資料夾」選擇要管理的資源目錄。',
      'Modsフォルダーが既にあるため上書きしていません。「フォルダーを変更」で管理するリソースフォルダーを選択してください。',
      'Mods already exists; no files were overwritten. Use Change folder to choose the resource folder to manage.',
      'Mods 폴더가 이미 있어 덮어쓰지 않았습니다. 폴더 변경에서 관리할 리소스 폴더를 선택하세요.',
    ),
    'library_default_migration_permission' => _t(
      '将默认目录更名为 Mods 需要授权“文档”根目录。现有资源仍保留，请使用“更换文件夹”重新授权。',
      '將預設目錄更名為 Mods 需要授權「文件」根目錄。現有資源仍保留，請使用「變更資料夾」重新授權。',
      '既定のフォルダーをModsに変更するにはDocumentsのルートへのアクセス許可が必要です。既存のリソースは保持されています。「フォルダーを変更」で許可してください。',
      'Grant access to the Documents root to rename the default folder to Mods. Existing resources are retained. Use Change folder to grant access.',
      '기본 폴더를 Mods로 바꾸려면 문서 루트 접근 권한이 필요합니다. 기존 리소스는 유지됩니다. 폴더 변경에서 권한을 부여하세요.',
    ),
    'library_default_migration_failed' => _t(
      '默认目录更名尚未完成，资源已保留。请检查文件夹权限后重试。',
      '預設目錄更名尚未完成，資源已保留。請檢查資料夾權限後重試。',
      '既定フォルダーの名前変更が完了していません。リソースは保持されています。権限を確認して再試行してください。',
      'The default folder rename is incomplete. Resources are retained. Check folder permissions and retry.',
      '기본 폴더 이름 변경이 완료되지 않았습니다. 리소스는 유지됩니다. 폴더 권한을 확인하고 다시 시도하세요.',
    ),
    'library_directory_required' => _t(
      '请选择本机文档文件夹或其子文件夹作为魔改库。',
      '請選擇本機文件資料夾或其子資料夾作為魔改庫。',
      '端末内のドキュメントフォルダーまたはそのサブフォルダーをMODライブラリーに選択してください。',
      'Choose a local Documents folder or one of its subfolders for the mod library.',
      '기기의 문서 폴더 또는 그 하위 폴더를 모드 라이브러리로 선택하세요.',
    ),
    'library_cleanup_failed' => _t(
      '部分公共文件未能删除。请检查目录权限后重新扫描并确认重试。',
      '部分共用檔案未能刪除。請檢查目錄權限後重新掃描並確認重試。',
      '一部の共有ファイルを削除できませんでした。フォルダーの権限を確認し、再スキャンして結果を確定すると再試行できます。',
      'Some shared files could not be deleted. Check folder permissions, then scan again and confirm to retry.',
      '일부 공유 파일을 삭제하지 못했습니다. 폴더 권한을 확인한 뒤 다시 스캔하고 확인을 눌러 재시도하세요.',
    ),
    'library_backup_pending' => _t(
      '设置已生效，但魔改库备份尚未完成。请重新扫描重试。',
      '設定已生效，但魔改庫備份尚未完成。請重新掃描重試。',
      '設定は適用済みですが、MODライブラリーへのバックアップが完了していません。再スキャンしてお試しください。',
      'Settings are active, but the mod library backup is incomplete. Scan again to retry.',
      '설정은 적용되었지만 모드 라이브러리 백업을 완료하지 못했습니다. 다시 스캔하세요.',
    ),
    'library_not_configured' || 'library_required' => libraryUnconfigured,
    'library_permission_lost' ||
    'library_permission_denied' ||
    'library_unavailable' ||
    'library_missing' => _t(
      '魔改资源文件夹暂不可访问，请重新选择并授权。当前已生效的资源继续保留。',
      '魔改資源資料夾暫時無法存取，請重新選擇並授權。目前已生效的資源繼續保留。',
      'MODフォルダーにアクセスできません。フォルダーを選び直して許可してください。現在の適用内容は保持します。',
      'The mod folder is unavailable. Choose it again and grant access. Active resources are preserved.',
      '모드 폴더에 접근할 수 없습니다. 폴더를 다시 선택하고 권한을 허용하세요. 적용 중인 리소스는 유지됩니다.',
    ),
    'library_scan_failed' || 'library_scan_expired' || 'library_changed' => _t(
      '扫描结果已失效或文件仍在变化，请完成文件修改后重新扫描。',
      '掃描結果已失效或檔案仍在變更，請完成檔案修改後重新掃描。',
      'スキャン結果が期限切れか、ファイルが変更中です。編集が完了した後に再スキャンしてください。',
      'The scan expired or files are changing. Finish editing, then scan again.',
      '스캔 결과가 만료되었거나 파일이 변경 중입니다. 수정을 마친 뒤 다시 스캔하세요.',
    ),
    'library_write_failed' ||
    'library_storage_error' ||
    'library_migration_failed' ||
    'library_read_only' => _t(
      '无法写入魔改资源文件夹，迁移或保存未完成。请检查空间和写入权限后重试。',
      '無法寫入魔改資源資料夾，遷移或儲存未完成。請檢查空間和寫入權限後重試。',
      'MODフォルダーへの移行または保存が完了していません。空き容量と書き込み権限を確認して再試行してください。',
      'Migration or saving to the mod folder did not finish. Check free space and write access, then retry.',
      '모드 폴더 이전 또는 저장을 완료하지 못했습니다. 저장 공간과 쓰기 권한을 확인한 뒤 다시 시도하세요.',
    ),
    'library_metadata_invalid' || 'invalid_config' => _t(
      '魔改包信息或已保存搭配损坏，现有资源已保留。请修复文件或重新选择文件夹后扫描。',
      '魔改包資訊或已儲存搭配損壞，現有資源已保留。請修復檔案或重新選擇資料夾後掃描。',
      'MOD情報または保存済み設定が破損しています。既存の素材は保持しています。ファイルを修復するかフォルダーを選び直してスキャンしてください。',
      'Package information or the saved setup is damaged. Existing resources are preserved. Repair the files or choose the folder again, then scan.',
      '패키지 정보 또는 저장된 설정이 손상되었습니다. 기존 리소스는 유지됩니다. 파일을 복구하거나 폴더를 다시 선택한 뒤 스캔하세요.',
    ),
    'library_open_failed' => _t(
      '无法打开文件夹，请使用系统文件管理器前往所选位置。',
      '無法開啟資料夾，請使用系統檔案管理員前往所選位置。',
      'フォルダーを開けません。システムのファイル管理アプリから開いてください。',
      'Could not open the folder. Open its location in your system file manager.',
      '폴더를 열 수 없습니다. 시스템 파일 관리자에서 해당 위치를 여세요.',
    ),
    'library_package_missing' => libraryMissingHint,
    'coordinate_unmatched' => _t(
      '坐标配置未找到匹配的舰娘图片，无法启用',
      '座標設定找不到匹配的艦娘圖片，無法啟用',
      '座標設定に対応する艦娘画像が見つからないため使用できません',
      'No matching ship image was found for this coordinate configuration',
      '이 좌표 설정과 일치하는 함선 이미지를 찾지 못했습니다',
    ),
    'invalid_coordinates' => _t(
      '坐标配置格式或数值无效，请修正后再导入',
      '座標設定格式或數值無效，請修正後再匯入',
      '座標設定の形式または値が無効です。修正してからインポートしてください',
      'Coordinate format or values are invalid; correct them before importing',
      '좌표 형식이나 값이 잘못되었습니다. 수정한 뒤 가져오세요',
    ),
    'coordinate_conflict' => _t(
      'INI 与 JSON 中的同一坐标值不一致，请修正后再导入',
      'INI 與 JSON 中的同一座標值不一致，請修正後再匯入',
      'INI と JSON の同じ座標値が一致しません。修正してからインポートしてください',
      'INI and JSON disagree on a coordinate value; correct them before importing',
      'INI와 JSON의 같은 좌표 값이 다릅니다. 수정한 뒤 가져오세요',
    ),
    'coordinate_metadata_ignored' => _t(
      '坐标中的名称等附加资料已忽略，不会修改游戏舰娘资料',
      '座標中的名稱等附加資料已略過，不會修改遊戲艦娘資料',
      '座標内の名前などの付加情報は無視し、ゲームの艦娘情報は変更しません',
      'Extra names or metadata in the coordinate file are ignored; game ship metadata is unchanged',
      '좌표 파일의 이름 등 추가 정보는 무시하며 게임 함선 정보는 변경하지 않습니다',
    ),
    'coordinate_apply_failed' => coordinatesFailed,
    'coordinate_unknown_fields_ignored' => _t(
      '已忽略未识别的坐标字段，仅应用支持的坐标',
      '已略過未識別的座標欄位，僅套用支援的座標',
      '未対応の座標項目は無視し、対応する座標のみ適用します',
      'Unknown coordinate fields are ignored; supported coordinates are applied',
      '알 수 없는 좌표 필드는 무시하며 지원되는 좌표만 적용합니다',
    ),
    'coordinate_dependency_unresolved' => _t(
      '无法可靠关联坐标与舰娘图片，相关内容未启用',
      '無法可靠關聯座標與艦娘圖片，相關內容未啟用',
      '座標と艦娘画像を確実に関連付けられないため対象を無効にしました',
      'Coordinates could not be reliably bound to ship images; affected content is disabled',
      '좌표를 함선 이미지와 확실하게 연결하지 못해 관련 항목이 비활성화되었습니다',
    ),
    'seven_zip_unsupported' => _t(
      '这是 7z 压缩包，请先转换为 ZIP 再导入',
      '這是 7z 壓縮檔，請先轉換為 ZIP 再匯入',
      'これは 7z 形式です。ZIP に変換してからインポートしてください',
      'This is a 7z archive; convert it to ZIP before importing',
      '7z 압축 파일입니다. ZIP으로 변환한 뒤 가져오세요',
    ),
    'audio_filename_unsupported' => _t(
      '语音文件名需使用游戏的数字编号，备份或自定义名称无法替换',
      '語音檔名需使用遊戲的數字編號，備份或自訂名稱無法替換',
      '音声ファイル名はゲームの数字IDが必要です。バックアップ名や独自名は置換できません',
      'Voice filenames must use numeric game IDs; backup or custom names cannot replace game voices',
      '음성 파일명은 게임의 숫자 ID여야 합니다. 백업이나 사용자 지정 이름은 대체할 수 없습니다',
    ),
    'audio_path_unsupported' => _t(
      '仅支持 kcs/sound 下的标准游戏语音路径',
      '僅支援 kcs/sound 下的標準遊戲語音路徑',
      'kcs/sound 配下の標準ゲーム音声パスのみ対応します',
      'Only standard game voice paths under kcs/sound are supported',
      'kcs/sound 아래의 표준 게임 음성 경로만 지원합니다',
    ),
    'audio_format_unsupported' || 'unsupported_audio_type' => _t(
      '音频格式或编码不支持；旧版导入的 WAV 请重新导入检查',
      '音訊格式或編碼不支援；舊版匯入的 WAV 請重新匯入檢查',
      '音声の形式またはエンコードに対応していません。旧版でインポートした WAV は再インポートして確認してください',
      'Audio format or encoding is unsupported; reimport WAV files imported by an older version to check support',
      '오디오 형식 또는 인코딩을 지원하지 않습니다. 이전 버전에서 가져온 WAV는 다시 가져와 확인하세요',
    ),
    'invalid_audio' || 'invalid_mp3' => _t(
      '音频校验未通过，文件可能不完整或编码暂不支持',
      '音訊驗證未通過，檔案可能不完整或編碼暫不支援',
      '音声の検証に失敗しました。ファイルが不完全か、未対応のエンコードの可能性があります',
      'Audio validation failed; the file may be incomplete or use an unsupported encoding',
      '오디오 검증에 실패했습니다. 파일이 불완전하거나 지원하지 않는 인코딩일 수 있습니다',
    ),
    'hack_overrides_original' => _t(
      '压缩包同时包含 .hack 与同名原版文件，已优先采用 .hack 魔改文件',
      '壓縮包同時包含 .hack 與同名原版檔案，已優先採用 .hack 魔改檔案',
      'ZIP内に .hack と同名の元ファイルが含まれていたため、.hack ファイルを優先しました',
      'The archive contained both .hack and original files; .hack mod files were used',
      '압축 파일에 .hack 파일과 원본 파일이 함께 있어 .hack 파일을 우선 적용했습니다',
    ),
    'png_trailing_data_removed' => _t(
      '部分图片含多余尾部数据，导入时已清理（原压缩包不变）',
      '部分圖片含多餘尾端資料，匯入時已清理（原壓縮檔不變）',
      '一部画像の末尾に余分なデータがあったため、インポートしたコピーから除去しました（元のZIPは変更しません）',
      'Extra trailing data was removed from imported image copies; the source archive is unchanged',
      '일부 이미지의 불필요한 후행 데이터를 가져온 사본에서 제거했습니다. 원본 압축 파일은 변경되지 않습니다',
    ),
    'coordinates_unsupported' || 'coordinate_dependency' => _t(
      '此包由旧版导入，请重新导入以启用坐标支持',
      '此包由舊版匯入，請重新匯入以啟用座標支援',
      '旧バージョンでインポートされたMODです。座標を使用するには再インポートしてください',
      'This package was imported by an older version; reimport it to enable coordinates',
      '이전 버전에서 가져온 패키지입니다. 좌표를 사용하려면 다시 가져오세요',
    ),
    'spritesheet_json_dependency' || 'spritesheet_json_unsupported' => _t(
      '暂不支持依赖图集 JSON 的资源',
      '暫不支援依賴圖集 JSON 的資源',
      'アトラス JSON に依存する素材には未対応です',
      'Resources that depend on atlas JSON are not supported yet',
      '아틀라스 JSON에 의존하는 리소스는 아직 지원하지 않습니다',
    ),
    'audio_range_unsupported' => _t(
      '此包由旧版导入，请重新导入以启用语音',
      '此包由舊版匯入，請重新匯入以啟用語音',
      '旧バージョンでインポートされたMODです。音声を使用するには再インポートしてください',
      'This package was imported by an older version; reimport it to enable voices',
      '이전 버전에서 가져온 패키지입니다. 음성을 사용하려면 다시 가져오세요',
    ),
    'script_unsupported' => _t(
      '不支持导入或执行脚本',
      '不支援匯入或執行指令碼',
      'スクリプトのインポート・実行には未対応です',
      'Importing or executing scripts is unsupported',
      '스크립트 가져오기 및 실행은 지원하지 않습니다',
    ),
    'json_unsupported' => _t(
      '暂不支持此 JSON 配置',
      '暫不支援此 JSON 設定',
      'このJSON設定には未対応です',
      'This JSON configuration is unsupported',
      '이 JSON 설정은 지원하지 않습니다',
    ),
    'unknown_ship_asset' => _t(
      '无法可靠识别此舰娘资源',
      '無法可靠識別此艦娘資源',
      '艦娘素材を確実に識別できません',
      'This ship resource could not be reliably identified',
      '이 함선 리소스를 확실하게 식별할 수 없습니다',
    ),
    'unsupported_path' => _t(
      '此资源位置暂不支持替换',
      '此資源位置暫不支援替換',
      'この素材の場所は置換に未対応です',
      'Replacement at this resource location is unsupported',
      '이 리소스 위치의 대체는 지원하지 않습니다',
    ),
    'unsupported_audio_files' => _t(
      '部分音频不符合游戏替换规则，将跳过；支持的 MP3 / WAV 仍可导入',
      '部分音訊不符合遊戲替換規則，將略過；支援的 MP3 / WAV 仍可匯入',
      '置換条件を満たさない音声はスキップします。対応する MP3 / WAV はインポートできます',
      'Unsupported audio files will be skipped; supported MP3 / WAV voices can still be imported',
      '대체 조건에 맞지 않는 오디오는 건너뜁니다. 지원하는 MP3 / WAV 음성은 계속 가져올 수 있습니다',
    ),
    'unsupported_files' => _t(
      '部分内容不支持，将跳过这些内容',
      '部分內容不支援，將略過這些內容',
      '非対応の内容はスキップします',
      'Unsupported content will be skipped',
      '지원하지 않는 항목은 건너뜁니다',
    ),
    'duplicate_resource' => _t(
      '压缩包包含重复的目标资源',
      '壓縮包包含重複的目標資源',
      'ZIPに重複した置換対象があります',
      'The ZIP contains duplicate target resources',
      'ZIP에 중복 대상 리소스가 있습니다',
    ),
    'invalid_png' => _t(
      '图像不是有效的 PNG 文件',
      '圖像不是有效的 PNG 檔案',
      '有効なPNG画像ではありません',
      'The image is not a valid PNG',
      '올바른 PNG 이미지가 아닙니다',
    ),
    'invalid_token' => _t(
      '导入预检已失效，请重新选择 ZIP',
      '匯入預檢已失效，請重新選擇 ZIP',
      '確認の有効期限が切れました。ZIPを選び直してください',
      'Import review expired; choose the ZIP again',
      '가져오기 확인이 만료되었습니다. ZIP을 다시 선택하세요',
    ),
    'save_failed' || 'storage_error' => _t(
      '设置未能保存，请重试保存后再应用',
      '設定未能儲存，請重試儲存後再套用',
      '設定を保存できません。保存を再試行してから適用してください',
      'Settings could not be saved; retry saving before applying',
      '설정을 저장하지 못했습니다. 저장을 재시도한 뒤 적용하세요',
    ),
    'unsupported' ||
    'platform_unsupported' ||
    'unsupported_platform' => unsupported,
    'unsupported_type' ||
    'unsupported_extension' ||
    'unsupported_file_type' => _t(
      '暂不支持此文件类型',
      '暫不支援此檔案類型',
      '非対応のファイル形式',
      'Unsupported file type',
      '지원하지 않는 파일 형식',
    ),
    'missing_pair' || 'missing_atlas_pair' || 'atlas_pair_missing' => _t(
      '缺少配套 PNG 或 JSON',
      '缺少配套 PNG 或 JSON',
      '対応するPNGまたはJSONがありません',
      'Matching PNG or JSON is missing',
      '연결된 PNG 또는 JSON이 없습니다',
    ),
    'invalid_path' ||
    'unsafe_archive' ||
    'path_traversal' ||
    'unsafe_path' => _t(
      '压缩包包含不安全的资源路径',
      '壓縮包包含不安全的資源路徑',
      'ZIPに安全でないパスが含まれます',
      'The archive contains an unsafe resource path',
      '압축 파일에 안전하지 않은 경로가 있습니다',
    ),
    'archive_too_large' ||
    'zip_bomb' ||
    'limits_exceeded' ||
    'quota_exceeded' => _t(
      '压缩包超过导入限制',
      '壓縮包超過匯入限制',
      'ZIPがインポート上限を超えています',
      'The archive exceeds import limits',
      '압축 파일이 가져오기 제한을 초과합니다',
    ),
    'invalid_archive' ||
    'invalid_zip' ||
    'archive_invalid' ||
    'unsupported_archive' => _t(
      '无法读取此 ZIP，请检查文件',
      '無法讀取此 ZIP，請檢查檔案',
      'ZIPを読み込めません。ファイルを確認してください',
      'Unable to read this ZIP; check the file',
      'ZIP을 읽을 수 없습니다. 파일을 확인하세요',
    ),
    'no_supported_resources' || 'no_resources' => _t(
      '未找到支持的游戏资源',
      '找不到支援的遊戲資源',
      '対応するゲーム素材がありません',
      'No supported game resources were found',
      '지원하는 게임 리소스가 없습니다',
    ),
    'blocked' || 'game_busy' || 'busy' => _t(
      '当前游戏状态无法刷新，请稍后重试',
      '目前遊戲狀態無法重新整理，請稍後重試',
      '現在は再読み込みできません。後でお試しください',
      'The game cannot reload now; try again shortly',
      '지금은 게임을 새로고침할 수 없습니다. 잠시 후 다시 시도하세요',
    ),
    'import_cancelled' || 'cancelled' => cancel,
    _ => _t(
      '无法完成此操作，请重试或查看日志',
      '無法完成此操作，請重試或檢視日誌',
      '操作を完了できません。再試行またはログを確認してください',
      'Unable to complete this operation; retry or check the logs',
      '작업을 완료하지 못했습니다. 다시 시도하거나 로그를 확인하세요',
    ),
  };
  String kind(String kind) => switch (kind) {
    'coordinates' => _t(
      '坐标配置',
      '座標設定',
      '座標設定',
      'Coordinate configuration',
      '좌표 설정',
    ),
    'audio' ||
    'sound' ||
    'voice' => _t('声音资源', '聲音資源', '音声素材', 'Audio resources', '오디오 리소스'),
    'atlas' || 'sprite' || 'sprite_atlas' => _t(
      '图集与坐标',
      '圖集與座標',
      'アトラスと座標',
      'Atlas & coordinates',
      '아틀라스 및 좌표',
    ),
    'image' ||
    'background' ||
    'ship' ||
    'ship_image' => _t('图像资源', '圖像資源', '画像素材', 'Image resources', '이미지 리소스'),
    _ => _t('其他资源', '其他資源', 'その他の素材', 'Other resources', '기타 리소스'),
  };
  String groupLabel(String id, String resourceKind) =>
      resourceKind == 'coordinates'
      ? kind(resourceKind)
      : id.startsWith('ship:')
      ? '${_t('舰娘图像', '艦娘圖像', '艦娘画像', 'Ship images', '함선 이미지')} · ${id.substring(5)}'
      : kind(resourceKind);
  String resourceLabel(GameModResource resource, int ordinal) {
    if (resource.isCoordinates) {
      final raw = resource.label.isEmpty
          ? resource.path.split('/').last
          : resource.label;
      final id = RegExp(r'^\d+$').hasMatch(raw) ? raw.padLeft(4, '0') : raw;
      return '${_t('舰娘坐标', '艦娘座標', '艦娘座標', 'Coordinates', '함선 좌표')} · $id';
    }
    if (const {'audio', 'sound', 'voice'}.contains(resource.kind)) {
      final file = resource.path.split('/').last;
      final voice = RegExp(
        r'^([0-9]+)\.(?:mp3|wav)$',
        caseSensitive: false,
      ).firstMatch(file);
      if (voice != null) {
        return '${_t('语音', '語音', 'ボイス', 'Voice', '음성')} · ${voice.group(1)}';
      }
      if (RegExp(r'\.(mp3|wav)$', caseSensitive: false).hasMatch(file)) {
        return '${_t('语音', '語音', 'ボイス', 'Voice', '음성')} · $file';
      }
    }
    final known = switch (resource.path) {
      'kcs2/img/port/port_background.png' => _t(
        '母港背景',
        '母港背景',
        '母港背景',
        'Home port background',
        '모항 배경',
      ),
      'kcs2/img/port/port_decoration.png' => _t(
        '母港装饰图像',
        '母港裝飾圖像',
        '母港装飾画像',
        'Home port decoration',
        '모항 장식 이미지',
      ),
      'kcs2/img/common/bg_map/bg_h.png' => _t(
        '日战背景',
        '日戰背景',
        '昼戦背景',
        'Day battle background',
        '주간전 배경',
      ),
      'kcs2/img/common/common_shutter.png' => _t(
        '过场闸门界面',
        '過場閘門介面',
        'シャッター画面',
        'Shutter transition screen',
        '셔터 전환 화면',
      ),
      'kcs2/img/common/bg/011.png' => _t(
        '编成背景',
        '編成背景',
        '編成背景',
        'Organize background',
        '편성 배경',
      ),
      'kcs2/img/common/bg/012.png' => _t(
        '补给背景',
        '補給背景',
        '補給背景',
        'Supply background',
        '보급 배경',
      ),
      'kcs2/img/common/bg/013.png' => _t(
        '改装背景',
        '改裝背景',
        '改装背景',
        'Remodel background',
        '개장 배경',
      ),
      'kcs2/img/common/bg/014.png' => _t(
        '入渠背景',
        '入渠背景',
        '入渠背景',
        'Repair background',
        '입거 배경',
      ),
      'kcs2/img/common/bg/015.png' => _t(
        '工厂背景',
        '工廠背景',
        '工廠背景',
        'Arsenal background',
        '공창 배경',
      ),
      'kcs2/img/common/bg/016.png' => _t(
        '出击背景',
        '出擊背景',
        '出撃背景',
        'Sortie background',
        '출격 배경',
      ),
      'kcs2/img/common/bg/021.png' => _t(
        '图鉴背景（上）',
        '圖鑑背景（上）',
        '図鑑背景（上）',
        'Album background (upper)',
        '도감 배경 (상)',
      ),
      'kcs2/img/common/bg/022.png' => _t(
        '图鉴背景（下）',
        '圖鑑背景（下）',
        '図鑑背景（下）',
        'Album background (lower)',
        '도감 배경 (하)',
      ),
      'kcs2/img/common/bg/031.png' => _t(
        '改修工厂背景',
        '改修工廠背景',
        '改修工廠背景',
        'Akashi\'s Arsenal background',
        '개수공창 배경',
      ),
      'kcs2/img/common/bg/g1.png' => _t(
        '获得报酬背景',
        '獲得報酬背景',
        '報酬獲得背景',
        'Reward background',
        '보상 획득 배경',
      ),
      'kcs2/img/common/bg/g2.png' => _t(
        '舰娘掉落背景',
        '艦娘掉落背景',
        '艦娘ドロップ背景',
        'Ship drop background',
        '함선 드롭 배경',
      ),
      'kcs2/img/common/bg_map/bg_n.png' || 'kcs2/img/common/bg_map/bg_y.png' =>
        _t('夜战背景', '夜戰背景', '夜戦背景', 'Night battle background', '야간전 배경'),
      _ => null,
    };
    if (known != null) return known;
    if (resource.path.startsWith('kcs2/resources/furniture/')) {
      final parts = resource.path.split('/');
      final category = parts.length >= 4 ? parts[3] : '';
      final file = parts.last.replaceAll(
        RegExp(r'\.png$', caseSensitive: false),
        '',
      );
      final catLabel = switch (category) {
        'outside' => _t(
          '窗外背景家具',
          '窗外背景家具',
          '窓外背景家具',
          'Window view furniture',
          '창밖 배경 가구',
        ),
        'floor' => _t('地板家具', '地板家具', '床家具', 'Floor furniture', '바닥 가구'),
        'wall' => _t('墙壁家具', '牆壁家具', '壁家具', 'Wall furniture', '벽지 가구'),
        'window' => _t('窗户家具', '窗戶家具', '窓家具', 'Window furniture', '창문 가구'),
        'object' => _t(
          '墙饰家具',
          '牆飾家具',
          '装飾家具',
          'Wall hanging furniture',
          '벽장식 가구',
        ),
        'chest' => _t('家具柜', '家具櫃', '家具棚', 'Chest furniture', '수납장 가구'),
        'desk' => _t('执务桌家具', '執務桌家具', '執務机家具', 'Desk furniture', '집무책상 가구'),
        _ => _t('母港家具', '母港家具', '母港家具', 'Port furniture', '모항 가구'),
      };
      return '$catLabel · $file';
    }
    final match = RegExp(
      r'^([0-9]{4}) · ([a-z0-9_]+)$',
    ).firstMatch(resource.label);
    if (match != null) {
      final type = match.group(2)!;
      final purpose =
          type.startsWith('full') || type.startsWith('character_full')
          ? _t('全身立绘', '全身立繪', '全身画像', 'Full portrait', '전신 이미지')
          : type.startsWith('card')
          ? _t('舰娘卡面', '艦娘卡面', 'カード画像', 'Ship card', '함선 카드')
          : type.startsWith('banner')
          ? _t(
              '编成与战斗头像',
              '編成與戰鬥頭像',
              '編成・戦闘画像',
              'Fleet & battle portrait',
              '편성 및 전투 이미지',
            )
          : _t('舰娘图像', '艦娘圖像', '艦娘画像', 'Ship image', '함선 이미지');
      final damaged = type.contains('dmg')
          ? ' · ${_t('中破', '中破', '中破', 'Damaged', '중파')}'
          : '';
      return '${match.group(1)} · $purpose$damaged';
    }
    if (resource.label.isNotEmpty &&
        resource.label != resource.path &&
        !resource.label.contains('/')) {
      return resource.label;
    }
    return '${kind(resource.kind)} $ordinal';
  }

  String applyResult(GameModsApplyResult result) => switch (result) {
    GameModsApplyResult.reloaded => _t(
      '已应用并刷新游戏',
      '已套用並重新整理遊戲',
      '適用してゲームを再読み込みしました',
      'Applied and game reloaded',
      '적용 후 게임을 새로고침했습니다',
    ),
    GameModsApplyResult.noGame => _t(
      '已应用，下次打开游戏时生效',
      '已套用，下次開啟遊戲時生效',
      '適用しました。次回ゲーム起動時に有効になります',
      'Applied; takes effect next time the game opens',
      '적용됨 · 다음 게임 실행 시 반영됩니다',
    ),
    GameModsApplyResult.blocked => reason('blocked'),
    GameModsApplyResult.unsupported => unsupported,
    GameModsApplyResult.failed => reason('apply_failed'),
  };
}
