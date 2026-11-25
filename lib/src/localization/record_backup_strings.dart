import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reviewed labels for account-scoped logbook and composition backups.
class RecordBackupStrings {
  const RecordBackupStrings(this.locale);
  factory RecordBackupStrings.of(BuildContext context) => RecordBackupStrings(
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

  String get section => _text(
    '记录备份与恢复',
    '記錄備份與復原',
    '記録のバックアップと復元',
    '기록 백업 및 복원',
    'Record backup and restore',
  );
  String errorMessage(Object error) {
    final original = error.toString();
    if (error is PlatformException) {
      if (error.code == 'invalid_backup_directory' &&
          error.message == '请选择本机文档文件夹或其子文件夹') {
        return _text(
          '请选择本机文档文件夹或其子文件夹',
          '請選擇本機的文件資料夾或其子資料夾',
          '端末のドキュメントフォルダーか、その中のフォルダーを選択してください',
          '기기의 문서 폴더나 그 하위 폴더를 선택하세요',
          'Select the Documents folder on this device or one of its subfolders',
        );
      }
      return original;
    }

    // Sync status retains the exception text after the operation finishes.
    final message = switch (error) {
      StateError(:final message) => message,
      FormatException(:final message) => message,
      String text when text.startsWith('Bad state: ') => text.substring(
        'Bad state: '.length,
      ),
      String text when text.startsWith('FormatException: ') => text.substring(
        'FormatException: '.length,
      ),
      _ => null,
    };
    if (message == null) return original;
    if (message == 'Game account changed' || message == accountChanged) {
      return accountChanged;
    }
    if (message == 'Game account is not verified') return loginRequired;
    final key = switch (message) {
      'Backup copy belongs to another account' ||
      'Current backup belongs to another account' =>
        'Backup belongs to another account',
      'Restore journal belongs to another account' =>
        'Restore journal account mismatch',
      _ => message,
    };
    final texts = _errorMessages[key];
    if (texts == null) return original;
    return _text(texts.$1, texts.$2, texts.$3, texts.$4, message);
  }

  static const _errorMessages = <String, (String, String, String, String)>{
    'Backup belongs to another account': (
      '备份属于其他账号',
      '備份屬於其他帳號',
      'このバックアップは別のアカウントのものです',
      '다른 계정의 백업입니다',
    ),
    'Destination contains another account backup': (
      '目标文件夹中已有其他账号的备份',
      '目標資料夾中已有其他帳號的備份',
      '選択したフォルダーに別のアカウントのバックアップがあります',
      '선택한 폴더에 다른 계정의 백업이 있습니다',
    ),
    'Destination contains a conflicting backup': (
      '目标文件夹中已有冲突的备份',
      '目標資料夾中已有衝突的備份',
      '選択したフォルダーに競合するバックアップがあります',
      '선택한 폴더에 충돌하는 백업이 있습니다',
    ),
    'An export is already in progress': (
      '正在导出备份',
      '正在匯出備份',
      'バックアップの書き出しがすでに進行中です',
      '이미 백업을 내보내는 중입니다',
    ),
    'Backup folder picker is already open': (
      '备份文件夹选择器已打开',
      '備份資料夾選擇器已開啟',
      'バックアップ先の選択画面はすでに開いています',
      '백업 폴더 선택 창이 이미 열려 있습니다',
    ),
    'Backup folder has not been selected': (
      '尚未选择备份文件夹',
      '尚未選擇備份資料夾',
      'バックアップ先のフォルダーが選択されていません',
      '백업 폴더를 선택하지 않았습니다',
    ),
    'Backup folder permission is required to finish restore': (
      '请授予备份文件夹访问权限以完成恢复',
      '請授予備份資料夾存取權限以完成復原',
      '復元を完了するには、バックアップ先フォルダーへのアクセスを許可してください',
      '복원을 마치려면 백업 폴더 접근 권한을 허용하세요',
    ),
    'Unsupported backup format': (
      '不支持此备份格式',
      '不支援此備份格式',
      'このバックアップ形式には対応していません',
      '지원하지 않는 백업 형식입니다',
    ),
    'Backup checksum mismatch': (
      '备份校验和不匹配',
      '備份校驗碼不符',
      'バックアップのチェックサムが一致しません',
      '백업 체크섬이 일치하지 않습니다',
    ),
    'Invalid backup content': (
      '备份内容无效',
      '備份內容無效',
      'バックアップの内容が正しくありません',
      '백업 내용이 올바르지 않습니다',
    ),
    'Backup is too large': (
      '备份文件过大',
      '備份檔案過大',
      'バックアップファイルのサイズが上限を超えています',
      '백업 파일이 너무 큽니다',
    ),
    'Backup verification failed': (
      '备份校验失败',
      '備份驗證失敗',
      'バックアップの検証に失敗しました',
      '백업 검증에 실패했습니다',
    ),
    'No valid backup copy was found': (
      '未找到有效的备份副本',
      '找不到有效的備份副本',
      '有効なバックアップのコピーが見つかりません',
      '유효한 백업 사본을 찾을 수 없습니다',
    ),
    'Record backup and restore is disabled': (
      '记录备份与恢复已关闭',
      '記錄備份與復原已關閉',
      '記録のバックアップと復元が無効になっています',
      '기록 백업 및 복원이 꺼져 있습니다',
    ),
    'Game data changed during cleanup; please retry': (
      '清理期间游戏数据发生变化，请重试',
      '清理期間遊戲資料有變動，請重試',
      '削除中にゲームデータが変更されました。もう一度お試しください',
      '삭제 중 게임 데이터가 변경되었습니다. 다시 시도하세요',
    ),
    'Composition records changed during cleanup; please retry': (
      '清理期间编成记录发生变化，请重试',
      '清理期間編成記錄有變動，請重試',
      '削除中に編成記録が変更されました。もう一度お試しください',
      '삭제 중 편성 기록이 변경되었습니다. 다시 시도하세요',
    ),
    'Invalid restore journal': (
      '恢复日志无效',
      '復原日誌無效',
      '復元用ログの内容が正しくありません',
      '복원 로그가 올바르지 않습니다',
    ),
    'Invalid restore journal name': (
      '恢复日志文件名无效',
      '復原日誌檔名無效',
      '復元用ログのファイル名が正しくありません',
      '복원 로그의 파일 이름이 올바르지 않습니다',
    ),
    'Restore journal is too large': (
      '恢复日志过大',
      '復原日誌過大',
      '復元用ログのサイズが上限を超えています',
      '복원 로그가 너무 큽니다',
    ),
    'Restore journal account mismatch': (
      '恢复日志的账号与当前账号不匹配',
      '復原日誌的帳號與目前帳號不符',
      '復元用ログのアカウントが現在のアカウントと一致しません',
      '복원 로그의 계정이 현재 계정과 일치하지 않습니다',
    ),
    'Restore journal verification failed': (
      '恢复日志校验失败',
      '復原日誌驗證失敗',
      '復元用ログの検証に失敗しました',
      '복원 로그 검증에 실패했습니다',
    ),
    'Restore completion marker mismatch': (
      '恢复完成标记不匹配',
      '復原完成標記不符',
      '復元の完了を示す記録が一致しません',
      '복원 완료 표시가 일치하지 않습니다',
    ),
    'Restore deletion marker mismatch': (
      '恢复过程中的删除标记不匹配',
      '復原過程中的刪除標記不符',
      '復元時の削除を示す記録が一致しません',
      '복원 중 삭제 표시가 일치하지 않습니다',
    ),
  };

  String get enabled => _text(
    '启用记录备份与恢复',
    '啟用記錄備份與復原',
    '記録のバックアップと復元を有効にする',
    '기록 백업 및 복원 활성화',
    'Enable record backup and restore',
  );
  String get folder => _text(
    '选择或更换备份文件夹',
    '選擇或更換備份資料夾',
    'バックアップ先を選択・変更',
    '백업 폴더 선택 또는 변경',
    'Select or change the backup folder',
  );
  String get folderHint => _text(
    '保存在本机文档文件夹；自动同步在后台进行',
    '保存在本機文件資料夾；自動同步在背景進行',
    'ドキュメントフォルダーに保存します。自動同期はバックグラウンドで行われます',
    '기기의 문서 폴더에 저장합니다. 자동 동기화는 백그라운드에서 진행됩니다',
    'Saved in the device Documents folder. Automatic syncing runs in the background',
  );
  String get folderSelected => _text(
    '已选择备份文件夹',
    '已選擇備份資料夾',
    'バックアップ先を選択しました',
    '백업 폴더를 선택했습니다',
    'Backup folder selected',
  );
  String get sync => _text('立即同步', '立即同步', '今すぐ同期', '지금 동기화', 'Sync now');
  String get syncDone =>
      _text('同步完成', '同步完成', '同期が完了しました', '동기화 완료', 'Sync complete');
  String get syncPending =>
      _text('等待同步', '等待同步', '同期待ち', '동기화 대기 중', 'Waiting to sync');
  String get neverSynced =>
      _text('尚未同步', '尚未同步', '未同期', '아직 동기화하지 않음', 'Not synced yet');
  String syncFailed(Object error) {
    final detail = errorMessage(error);
    return _text(
      '同步失败：$detail',
      '同步失敗：$detail',
      '同期失敗：$detail',
      '동기화 실패: $detail',
      'Sync failed: $detail',
    );
  }

  String lastSync(DateTime time) {
    final stamp = time.toString().split('.').first;
    return _text(
      '上次同步：$stamp',
      '上次同步：$stamp',
      '最終同期：$stamp',
      '마지막 동기화: $stamp',
      'Last sync: $stamp',
    );
  }

  String get export => _text(
    '导出备份文件',
    '匯出備份檔案',
    'バックアップを書き出す',
    '백업 파일 내보내기',
    'Export backup file',
  );
  String get exportHint => _text(
    '导出前会先同步并校验',
    '匯出前會先同步並驗證',
    '書き出し前に同期・検証します',
    '내보내기 전에 동기화하고 검증합니다',
    'Syncs and verifies before exporting',
  );
  String get saveToDevice =>
      _text('保存到本机', '儲存到本機', '端末に保存', '기기에 저장', 'Save to device');
  String get shareWithApps => _text(
    '分享给其他应用',
    '分享給其他應用程式',
    '他のアプリと共有',
    '다른 앱으로 공유',
    'Share with other apps',
  );
  String get savedToDevice => _text(
    '备份文件已保存',
    '備份檔案已儲存',
    'バックアップファイルを保存しました',
    '백업 파일이 저장되었습니다',
    'Backup file saved',
  );
  String get accountChanged => _text(
    '游戏账号已切换，请重新操作',
    '遊戲帳號已切換，請重新操作',
    'ゲームアカウントが切り替わりました。もう一度お試しください',
    '게임 계정이 전환되었습니다. 다시 시도하세요',
    'The game account has changed. Please try again',
  );
  String get import => _text(
    '从备份文件恢复',
    '從備份檔案復原',
    'バックアップから復元',
    '백업 파일에서 복원',
    'Restore from a backup file',
  );
  String get importHint => _text(
    '导入备份文件恢复游戏记录',
    '匯入備份檔案復原遊戲記錄',
    'バックアップファイルを読み込んでゲーム記録を復元します',
    '백업 파일을 가져와 게임 기록을 복원합니다',
    'Import a backup file to restore game records',
  );
  String get restoreTitle => _text(
    '覆盖当前账号记录？',
    '覆蓋目前帳號記錄？',
    '現在のアカウントの記録を上書きしますか？',
    '현재 계정의 기록을 덮어쓸까요?',
    'Overwrite records for the current account?',
  );
  String restoreDescription(int logs, int compositions) => _text(
    '将用备份中的 $logs 条航海日志和 $compositions 条编成记录覆盖当前账号主数据。',
    '將以備份中的 $logs 筆航海日誌及 $compositions 筆編成記錄覆蓋目前帳號主資料。',
    '航海日誌 $logs 件と編成記録 $compositions 件で現在のデータを上書きします。',
    '백업의 항해 일지 $logs건과 편성 기록 $compositions건으로 현재 계정의 원본 데이터를 덮어씁니다.',
    'Replace the current account data with $logs logbook ${logs == 1 ? 'record' : 'records'} and $compositions composition ${compositions == 1 ? 'record' : 'records'} from the backup.',
  );
  String get cancel => _text('取消', '取消', 'キャンセル', '취소', 'Cancel');
  String get restoreConfirm =>
      _text('覆盖并恢复', '覆蓋並復原', '上書きして復元', '덮어쓰기 및 복원', 'Overwrite and restore');
  String get restoreDone =>
      _text('恢复完成', '復原完成', '復元が完了しました', '복원 완료', 'Restore complete');
  String get recoveryPending => _text(
    '上次数据恢复尚未完成，请先完成恢复再进入游戏。',
    '上次資料復原尚未完成，請先完成復原再進入遊戲。',
    '前回のデータ復元が完了していません。復元を完了してからゲームを開始してください。',
    '이전 데이터 복원이 완료되지 않았습니다. 복원을 완료한 후 게임을 시작하세요.',
    'The previous restore has not finished. Complete it before entering the game.',
  );
  String get recoveryCorruptAdvice => _text(
    '内部恢复文件可能损坏。重新授权文件夹无法修复此问题。请保留应用数据并联系支持；若已确认文档文件夹中有可用备份，可重装后导入。',
    '內部復原檔案可能損壞。重新授權資料夾無法修復此問題。請保留應用程式資料並聯絡支援；若已確認文件資料夾中有可用備份，可重新安裝後匯入。',
    '内部の復元ファイルが破損している可能性があります。フォルダーへのアクセスを許可し直しても修復できません。アプリのデータを保持し、サポートにお問い合わせください。ドキュメントフォルダーに使用可能なバックアップがあることを確認できた場合は、再インストール後に読み込めます。',
    '내부 복원 파일이 손상되었을 수 있습니다. 폴더 접근 권한을 다시 허용해도 해결되지 않습니다. 앱 데이터를 보존하고 지원팀에 문의하세요. 문서 폴더에 사용 가능한 백업이 있음을 확인했다면 재설치 후 가져올 수 있습니다.',
    'The internal recovery file may be damaged. Granting folder access again will not fix this. Keep the app data and contact support. If you have verified that a usable backup exists in the Documents folder, you can reinstall the app and import it.',
  );
  String get recoveryRetryAdvice => _text(
    '若反复失败，请保留应用数据和文档备份文件，重新授权备份文件夹后再试。',
    '若反覆失敗，請保留應用程式資料及文件備份檔案，重新授權備份資料夾後再試。',
    '繰り返し失敗する場合は、アプリのデータとバックアップファイルを保持し、バックアップ先を選び直し、アクセスを許可してから再試行してください。',
    '계속 실패하면 앱 데이터와 문서 백업 파일을 보존하고 백업 폴더 접근 권한을 다시 허용한 후 시도하세요.',
    'If this keeps failing, keep the app data and document backup files, grant access to the backup folder again, and retry.',
  );
  String get retryRestore =>
      _text('重试恢复', '重試復原', '復元を再試行', '복원 다시 시도', 'Retry restore');
  String get reselectFolder => _text(
    '重新选择文档备份文件夹',
    '重新選擇文件備份資料夾',
    'ドキュメントのバックアップ先を再選択',
    '문서 백업 폴더 다시 선택',
    'Select the document backup folder again',
  );
  String get restoring => _text(
    '正在安全恢复记录，请稍候…',
    '正在安全復原記錄，請稍候…',
    '記録を安全に復元しています。しばらくお待ちください…',
    '기록을 안전하게 복원하고 있습니다. 잠시 기다려 주세요…',
    'Restoring records safely. Please wait…',
  );
  String get loginRequired => _text(
    '请先登录游戏并确认账号',
    '請先登入遊戲並確認帳號',
    'ゲームにログインしてアカウントを確認してください',
    '먼저 게임에 로그인하여 계정을 확인하세요',
    'Log in to the game and confirm your account first',
  );
  String get clearLogbook => _text(
    '清理航海日志主数据',
    '清理航海日誌主資料',
    '航海日誌の本体データを削除',
    '항해 일지 원본 데이터 삭제',
    'Delete local logbook data',
  );
  String get clearLogbookHint => _text(
    '只清理当前账号的本机主数据，保留备份文件',
    '只清理目前帳號的本機主資料，保留備份檔案',
    '現在のアカウントの端末データのみ削除し、バックアップは残します',
    '현재 계정의 기기 내 원본 데이터만 삭제하고 백업 파일은 보존합니다',
    'Deletes only local data for the current account and keeps backup files',
  );
  String get clearComposition => _text(
    '清理编成记录',
    '清理編成記錄',
    '編成記録を削除',
    '편성 기록 삭제',
    'Delete composition records',
  );
  String get clearCompositionHint => _text(
    '清理当前账号的所有编成记录，保留备份文件',
    '清理目前帳號的所有編成記錄，保留備份檔案',
    '現在のアカウントの編成記録を削除し、バックアップは残します',
    '현재 계정의 모든 편성 기록을 삭제하고 백업 파일은 보존합니다',
    'Deletes all composition records for the current account and keeps backup files',
  );
  String get clearLogbookTitle => _text(
    '清理航海日志主数据？',
    '清理航海日誌主資料？',
    '航海日誌の本体データを削除しますか？',
    '항해 일지 원본 데이터를 삭제할까요?',
    'Delete local logbook data?',
  );
  String get clearCompositionTitle => _text(
    '清理编成记录？',
    '清理編成記錄？',
    '編成記録を削除しますか？',
    '편성 기록을 삭제할까요?',
    'Delete composition records?',
  );
  String clearLogbookDescription(int count, bool backedUp) => backedUp
      ? _text(
          '将清理当前账号的 $count 条本机航海日志，备份文件不受影响。清理前会先同步。',
          '將清理目前帳號的 $count 筆本機航海日誌，備份檔案不受影響。清理前會先同步。',
          '現在のアカウントの航海日誌 $count 件を削除します。バックアップは残り、削除前に同期します。',
          '현재 계정의 기기 내 항해 일지 $count건을 삭제합니다. 백업 파일은 보존되며 삭제 전에 동기화합니다.',
          'Delete $count local logbook ${count == 1 ? 'record' : 'records'} for the current account. Backup files will be kept. The app will sync before deleting.',
        )
      : _text(
          '将清理当前账号的 $count 条本机航海日志。备份未启用或未设置文件夹，清理前不会同步，请确认已有可恢复的备份。',
          '將清理目前帳號的 $count 筆本機航海日誌。備份未啟用或未設定資料夾，清理前不會同步，請確認已有可復原的備份。',
          '現在のアカウントの航海日誌 $count 件を削除します。バックアップが無効または未設定のため、削除前に同期しません。復元可能なバックアップをご確認ください。',
          '현재 계정의 기기 내 항해 일지 $count건을 삭제합니다. 백업이 비활성화되었거나 폴더가 설정되지 않아 삭제 전에 동기화하지 않습니다. 복원 가능한 백업이 있는지 확인하세요.',
          'Delete $count local logbook ${count == 1 ? 'record' : 'records'} for the current account. Backup is disabled or no folder is set, so the app will not sync before deleting. Make sure you have a usable backup.',
        );
  String clearCompositionDescription(int count, bool backedUp) => backedUp
      ? _text(
          '将清理当前账号的 $count 条本机编成记录，备份文件不受影响。清理前会先同步。',
          '將清理目前帳號的 $count 筆本機編成記錄，備份檔案不受影響。清理前會先同步。',
          '現在のアカウントの編成記録 $count 件を削除します。バックアップは残り、削除前に同期します。',
          '현재 계정의 기기 내 편성 기록 $count건을 삭제합니다. 백업 파일은 보존되며 삭제 전에 동기화합니다.',
          'Delete $count local composition ${count == 1 ? 'record' : 'records'} for the current account. Backup files will be kept. The app will sync before deleting.',
        )
      : _text(
          '将清理当前账号的 $count 条本机编成记录。备份未启用或未设置文件夹，清理前不会同步，请确认已有可恢复的备份。',
          '將清理目前帳號的 $count 筆本機編成記錄。備份未啟用或未設定資料夾，清理前不會同步，請確認已有可復原的備份。',
          '現在のアカウントの編成記録 $count 件を削除します。バックアップが無効または未設定のため、削除前に同期しません。復元可能なバックアップをご確認ください。',
          '현재 계정의 기기 내 편성 기록 $count건을 삭제합니다. 백업이 비활성화되었거나 폴더가 설정되지 않아 삭제 전에 동기화하지 않습니다. 복원 가능한 백업이 있는지 확인하세요.',
          'Delete $count local composition ${count == 1 ? 'record' : 'records'} for the current account. Backup is disabled or no folder is set, so the app will not sync before deleting. Make sure you have a usable backup.',
        );
  String clearFailed(Object error) {
    final detail = errorMessage(error);
    return _text(
      '清理失败：$detail',
      '清理失敗：$detail',
      '削除失敗：$detail',
      '삭제 실패: $detail',
      'Deletion failed: $detail',
    );
  }

  String compositionCleared(int count) => _text(
    '已清理 $count 条编成记录',
    '已清理 $count 筆編成記錄',
    '編成記録 $count 件を削除しました',
    '편성 기록 $count건을 삭제했습니다',
    'Deleted $count composition ${count == 1 ? 'record' : 'records'}',
  );
}
