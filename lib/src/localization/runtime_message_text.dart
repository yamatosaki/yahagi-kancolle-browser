import 'package:flutter/widgets.dart';

/// Localizes app-owned runtime messages at display time. Unrecognized native
/// error details, addresses, and exception type names are returned verbatim.
String runtimeMessageText(BuildContext context, String source) =>
    runtimeMessageForLocale(
      Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
      source,
    );

String runtimeMessageForLocale(Locale locale, String source) {
  final japanese = locale.languageCode == 'ja';
  final korean = locale.languageCode == 'ko';
  final english = locale.languageCode == 'en';
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale.countryCode));
  if (!japanese && !traditional && !korean && !english) {
    if (locale.languageCode != 'zh') return source;
    const knownFallbacks = {
      'Unknown error': '未知错误',
      'No result returned from native platform': '原生平台未返回结果',
      'Platform exception occurred': '原生平台发生异常',
    };
    final fallback = knownFallbacks[source];
    if (fallback != null) return fallback;
    final wrapped = RegExp(
      r'^(网络设置应用失败 \[[^\]]+\]: )(.*)$',
      dotAll: true,
    ).firstMatch(source);
    final knownDetail = wrapped == null ? null : knownFallbacks[wrapped[2]];
    return knownDetail == null ? source : '${wrapped![1]}$knownDetail';
  }
  final entry = runtimeMessageTranslations[source];
  if (entry != null) {
    return english
        ? entry.$4
        : korean
        ? entry.$3
        : japanese
        ? entry.$2
        : entry.$1;
  }
  final networkFailure = RegExp(
    r'^网络设置应用失败 \[([^\]]+)\]: (.*)$',
    dotAll: true,
  ).firstMatch(source);
  if (networkFailure != null) {
    final detail = runtimeMessageForLocale(locale, networkFailure[2]!);
    return english
        ? 'Failed to apply network settings [${networkFailure[1]}]: $detail'
        : korean
        ? '네트워크 설정 적용 실패 [${networkFailure[1]}]: $detail'
        : japanese
        ? 'ネットワーク設定の適用に失敗 [${networkFailure[1]}]：$detail'
        : '網路設定套用失敗 [${networkFailure[1]}]：$detail';
  }
  final loadFailure = RegExp(
    r'^游戏页面加载失败 \[([^\]]+)\]，请重新加载或检查网络。$',
  ).firstMatch(source);
  if (loadFailure != null) {
    return english
        ? 'Failed to load the game page [${loadFailure[1]}]. Reload or check your network.'
        : korean
        ? '게임 페이지 로드 실패 [${loadFailure[1]}]. 새로고침하거나 네트워크를 확인하세요.'
        : japanese
        ? 'ゲームページの読み込みに失敗 [${loadFailure[1]}]。再読み込みするかネットワークを確認してください。'
        : '遊戲頁面載入失敗 [${loadFailure[1]}]，請重新載入或檢查網路。';
  }
  if (english || korean) {
    final captureFailure = RegExp(
      r'^捕获配置失败（(.*)）$',
      dotAll: true,
    ).firstMatch(source);
    if (captureFailure != null) {
      return english
          ? 'Capture configuration failed (${captureFailure[1]})'
          : '캡처 설정 실패(${captureFailure[1]})';
    }
  }
  for (final entry in _prefixes.entries) {
    // Translate paired punctuation only for a complete, recognized wrapper.
    if ((english || korean) && entry.key == '捕获配置失败（') continue;
    if (source.startsWith(entry.key)) {
      final prefix = english
          ? entry.value.$4
          : korean
          ? entry.value.$3
          : japanese
          ? entry.value.$2
          : entry.value.$1;
      // The remainder is a raw exception, protocol, or technical stage.
      return prefix + source.substring(entry.key.length);
    }
  }
  return source;
}

const runtimeMessageTranslations = <String, (String, String, String, String)>{
  '模拟数据': ('模擬資料', 'テストデータ', '테스트 데이터', 'Sample data'),
  'proxy_operation_busy': (
    '代理設定正在套用中',
    'プロキシ設定を適用中です',
    '프록시 설정을 적용 중입니다',
    'Proxy settings are being applied',
  ),
  'unknown_mode': (
    '未知的代理模式',
    '不明なプロキシモード',
    '알 수 없는 프록시 모드',
    'Unknown proxy mode',
  ),
  '游戏模式（默认）': ('遊戲模式（預設）', 'ゲームモード（既定）', '게임 모드(기본)', 'Game mode (default)'),
  '纯浏览模式': ('純瀏覽模式', 'ブラウズ専用モード', '웹 탐색 전용 모드', 'Browser-only mode'),
  '只读解析游戏接口，用于舰队、任务和战斗信息；不会替你操作。': (
    '唯讀解析遊戲介面，用於艦隊、任務和戰鬥資訊；不會代替你操作。',
    'ゲームAPIを読み取り専用で解析し、艦隊・任務・戦闘情報を表示します。操作の代行はしません。',
    '게임 API를 읽기 전용으로 분석하여 함대, 임무, 전투 정보를 표시합니다. 게임 조작을 대신하지 않습니다.',
    'Reads the game API to display fleet, quest and battle information. It does not perform game actions for you.',
  ),
  '不读取游戏接口，仅显示游戏网页；信息功能将暂停更新。': (
    '不讀取遊戲介面，僅顯示遊戲網頁；資訊功能將暫停更新。',
    'ゲームAPIを読み取らず、ゲームページのみ表示します。情報機能の更新は一時停止します。',
    '게임 API를 읽지 않고 게임 페이지만 표시합니다. 정보 기능의 업데이트가 일시 중지됩니다.',
    'Displays only the game page without reading the game API. Information updates will pause.',
  ),
  '游戏模式将在重新载入页面后启用只读捕获。': (
    '遊戲模式將在重新載入頁面後啟用唯讀擷取。',
    'ページ再読み込み後、ゲームモードで読み取り専用のキャプチャを有効にします。',
    '페이지를 새로고침하면 게임 모드에서 읽기 전용 캡처가 활성화됩니다.',
    'Game mode will enable read-only capture after the page is reloaded.',
  ),
  '纯浏览模式将在重新载入页面后停止数据捕获。': (
    '純瀏覽模式將在重新載入頁面後停止資料擷取。',
    'ページ再読み込み後、ブラウズ専用モードでデータキャプチャを停止します。',
    '페이지를 새로고침하면 웹 탐색 전용 모드에서 데이터 캡처가 중지됩니다.',
    'Browser-only mode will stop data capture after the page is reloaded.',
  ),
  '无法读取捕获模式，已使用游戏模式': (
    '無法讀取擷取模式，已使用遊戲模式',
    'キャプチャモードを読み込めないため、ゲームモードを使用します',
    '캡처 모드를 읽을 수 없어 게임 모드를 사용합니다',
    'Unable to read the capture mode. Using game mode',
  ),
  '无法保存捕获模式，请重试': (
    '無法儲存擷取模式，請重試',
    'キャプチャモードを保存できません。再試行してください',
    '캡처 모드를 저장할 수 없습니다. 다시 시도하세요',
    'Unable to save the capture mode. Please try again',
  ),
  '当前设备不支持应用内代理': (
    '目前裝置不支援應用程式內代理',
    'この端末はアプリ内プロキシに対応していません',
    '이 기기는 앱 내 프록시를 지원하지 않습니다',
    'This device does not support an in-app proxy',
  ),
  '代理设置操作进行中，请稍后': (
    '正在套用代理設定，請稍候',
    'プロキシ設定の操作中です。しばらくお待ちください',
    '프록시 설정을 변경 중입니다. 잠시 기다려 주세요',
    'Proxy settings are being changed. Please wait',
  ),
  '代理设置成功': ('代理設定成功', 'プロキシを設定しました', '프록시가 설정되었습니다', 'Proxy configured'),
  '代理设置超时': (
    '代理設定逾時',
    'プロキシ設定がタイムアウトしました',
    '프록시 설정 시간이 초과되었습니다',
    'Proxy setup timed out',
  ),
  '无需清除代理': (
    '無需清除代理',
    '解除するプロキシ設定はありません',
    '해제할 프록시 설정이 없습니다',
    'No proxy settings to clear',
  ),
  '系统网络已恢复': (
    '系統網路已恢復',
    'システムのネットワークに戻しました',
    '시스템 네트워크로 복원되었습니다',
    'System network restored',
  ),
  '清除代理超时': (
    '清除代理逾時',
    'プロキシ解除がタイムアウトしました',
    '프록시 해제 시간이 초과되었습니다',
    'Clearing the proxy timed out',
  ),
  '未知错误': ('未知錯誤', '不明なエラー', '알 수 없는 오류', 'Unknown error'),
  'Unknown error': ('未知錯誤', '不明なエラー', '알 수 없는 오류', 'Unknown error'),
  'TCP连接失败': ('TCP 連線失敗', 'TCP接続に失敗しました', 'TCP 연결 실패', 'TCP connection failed'),
  '普通网络可用，但Google连接超时，不影响游戏。': (
    '一般網路可用，但 Google 連線逾時，不影響遊戲。',
    '通常のネットワークは利用できますが、Googleへの接続がタイムアウトしました。ゲームには影響しません。',
    '일반 네트워크는 이용 가능하지만 Google 연결 시간이 초과되었습니다. 게임에는 영향이 없습니다.',
    'The network is available, but the connection to Google timed out. This does not affect the game.',
  ),
  '网络畅通，可正常访问游戏服务。': (
    '網路暢通，可正常存取遊戲服務。',
    'ネットワークは正常で、ゲームサービスに接続できます。',
    '네트워크가 정상이며 게임 서비스에 접속할 수 있습니다.',
    'The network is working and the game service is accessible.',
  ),
  '外网可用，但游戏相关服务无法访问 (可能被墙或被拦截)。': (
    '外部網路可用，但無法存取遊戲相關服務（可能遭網路封鎖或攔截）。',
    '外部ネットワークは利用できますが、ゲーム関連サービスに接続できません（ネットワーク上で遮断されている可能性があります）。',
    '외부 네트워크는 이용 가능하지만 게임 관련 서비스에 접속할 수 없습니다(네트워크에서 차단되었을 수 있습니다).',
    'The external network is available, but game services are inaccessible (they may be blocked).',
  ),
  '当前网络连接失败或代理无法正常工作。': (
    '目前網路連線失敗或代理無法正常運作。',
    'ネットワーク接続に失敗したか、プロキシが正常に動作していません。',
    '네트워크 연결에 실패했거나 프록시가 정상적으로 작동하지 않습니다.',
    'The network connection failed or the proxy is not working correctly.',
  ),
  'No result returned from native platform': (
    '原生平台未傳回結果',
    'ネイティブ側から結果が返されませんでした',
    '네이티브 플랫폼에서 결과를 반환하지 않았습니다',
    'No result returned from the native platform',
  ),
  'Platform exception occurred': (
    '原生平台發生例外',
    'ネイティブ側で例外が発生しました',
    '네이티브 플랫폼에서 예외가 발생했습니다',
    'A native platform exception occurred',
  ),
  '原生 Activity WebView 仅支持 Android。': (
    '原生 Activity WebView 僅支援 Android。',
    'ネイティブ Activity WebView は Android のみに対応しています。',
    '네이티브 Activity WebView는 Android만 지원합니다.',
    'Native Activity WebView is supported only on Android.',
  ),
  '游戏渲染进程已退出。': (
    '遊戲渲染程序已結束。',
    'ゲームの描画プロセスが終了しました。',
    '게임 렌더링 프로세스가 종료되었습니다.',
    'The game rendering process has exited.',
  ),
  '原生 WebView 已销毁。': (
    '原生 WebView 已銷毀。',
    'ネイティブ WebView は破棄されました。',
    '네이티브 WebView가 제거되었습니다.',
    'The native WebView has been destroyed.',
  ),
  '原生 WebView 事件通道异常。': (
    '原生 WebView 事件通道異常。',
    'ネイティブ WebView のイベントチャネルでエラーが発生しました。',
    '네이티브 WebView 이벤트 채널에 오류가 발생했습니다.',
    'An error occurred in the native WebView event channel.',
  ),
  '原生 WebView 事件通道已关闭。': (
    '原生 WebView 事件通道已關閉。',
    'ネイティブ WebView のイベントチャネルが閉じられました。',
    '네이티브 WebView 이벤트 채널이 닫혔습니다.',
    'The native WebView event channel has closed.',
  ),
  '原生 WebView 无法安全隐藏，已终止该模式。': (
    '原生 WebView 無法安全隱藏，已終止此模式。',
    'ネイティブ WebView を安全に非表示にできないため、このモードを終了しました。',
    '네이티브 WebView를 안전하게 숨길 수 없어 해당 모드를 종료했습니다.',
    'The native WebView could not be hidden safely, so this mode was stopped.',
  ),
  '安全证书错误：可能是岛风GO证书未受信任或网络被劫持。': (
    '安全憑證錯誤：可能是岛风GO憑證未受信任或網路遭到劫持。',
    'セキュリティ証明書エラー：岛风GOの証明書が信頼されていないか、通信が傍受されている可能性があります。',
    '보안 인증서 오류: 岛风GO 인증서가 신뢰되지 않거나 통신이 가로채졌을 수 있습니다.',
    'Security certificate error: the 岛风GO certificate may be untrusted, or the network connection may be intercepted.',
  ),
  '正在读取配置...': (
    '正在讀取設定...',
    '設定を読み込み中...',
    '설정을 읽는 중...',
    'Reading configuration...',
  ),
  '正在应用网络设置...': (
    '正在套用網路設定...',
    'ネットワーク設定を適用中...',
    '네트워크 설정을 적용하는 중...',
    'Applying network settings...',
  ),
  '网络配置完毕，准备加载游戏...': (
    '網路設定完畢，準備載入遊戲...',
    'ネットワーク設定完了、ゲームの読み込みを準備中...',
    '네트워크 설정 완료, 게임 로드 준비 중...',
    'Network configured. Preparing to load the game...',
  ),
  '正在加载游戏页面...': (
    '正在載入遊戲頁面...',
    'ゲームページを読み込み中...',
    '게임 페이지를 로드하는 중...',
    'Loading the game page...',
  ),
  '正在等待游戏本体...': (
    '正在等待遊戲本體...',
    'ゲーム本体の読み込みを待機中...',
    '게임 본체를 기다리는 중...',
    'Waiting for the game to load...',
  ),
  '游戏页面加载超时，请重试。': (
    '遊戲頁面載入逾時，請重試。',
    'ゲームページの読み込みがタイムアウトしました。再試行してください。',
    '게임 페이지 로드 시간이 초과되었습니다. 다시 시도하세요.',
    'The game page took too long to load. Please try again.',
  ),
  '游戏本体加载超时，请重试。': (
    '遊戲本體載入逾時，請重試。',
    'ゲーム本体の読み込みがタイムアウトしました。再試行してください。',
    '게임 본체 로드 시간이 초과되었습니다. 다시 시도하세요.',
    'The game took too long to load. Please try again.',
  ),
  '游戏页面加载超时，请重新加载或检查网络。': (
    '遊戲頁面載入逾時，請重新載入或檢查網路。',
    'ゲームページの読み込みがタイムアウトしました。再読み込みするかネットワークを確認してください。',
    '게임 페이지 로드 시간이 초과되었습니다. 새로고침하거나 네트워크를 확인하세요.',
    'The game page took too long to load. Reload or check your network.',
  ),
  '游戏本体加载超时，请重新加载。': (
    '遊戲本體載入逾時，請重新載入。',
    'ゲーム本体の読み込みがタイムアウトしました。再読み込みしてください。',
    '게임 본체 로드 시간이 초과되었습니다. 새로고침하세요.',
    'The game took too long to load. Please reload.',
  ),
  '准备就绪...': ('準備就緒...', '準備完了...', '준비 완료...', 'Ready...'),
  '暂不支持的外部跳转：未知协议': (
    '暫不支援的外部跳轉：未知通訊協定',
    '未対応の外部ページへの遷移：不明なプロトコル',
    '지원하지 않는 외부 페이지 이동: 알 수 없는 프로토콜',
    'Unsupported external navigation: unknown protocol',
  ),
  'WebView 尚未就绪': (
    'WebView 尚未就緒',
    'WebView の準備ができていません',
    'WebView가 아직 준비되지 않았습니다',
    'WebView is not ready',
  ),
  '本地模拟页': ('本機模擬頁', 'ローカルテストページ', '로컬 테스트 페이지', 'Local test page'),
  '未知页面': ('未知頁面', '不明なページ', '알 수 없는 페이지', 'Unknown page'),
};

const gameAudioMutePendingPrefix = '游戏静音暂未生效，已保留静音设置：';
const gameAudioSaveFailedPrefix = '游戏声音设置保存失败，当前状态已保留：';
const gameAudioToggleFailedPrefix = '游戏声音切换失败：';
const gameAudioUnavailablePrefix = '当前设备无法控制游戏声音：';
const gameAudioBackgroundSettingFailedPrefix = '后台声音设置失败：';

const _prefixes = <String, (String, String, String, String)>{
  gameAudioMutePendingPrefix: (
    '遊戲靜音暫未生效，已保留靜音設定：',
    'ゲームの消音はまだ適用されていません。消音設定は保持されています：',
    '게임 음소거가 아직 적용되지 않았습니다. 음소거 설정은 유지됩니다: ',
    'Game mute has not taken effect yet; the mute setting is retained: ',
  ),
  gameAudioSaveFailedPrefix: (
    '遊戲聲音設定儲存失敗，目前狀態已保留：',
    'ゲーム音声設定を保存できませんでした。現在の状態は保持されています：',
    '게임 소리 설정을 저장하지 못했습니다. 현재 상태는 유지됩니다: ',
    'Could not save the game audio setting; the current state is retained: ',
  ),
  gameAudioToggleFailedPrefix: (
    '遊戲聲音切換失敗：',
    'ゲーム音声の切り替えに失敗：',
    '게임 소리 전환 실패: ',
    'Failed to change game audio: ',
  ),
  gameAudioUnavailablePrefix: (
    '目前裝置無法控制遊戲聲音：',
    'この端末ではゲーム音声を制御できません：',
    '현재 기기에서 게임 소리를 제어할 수 없습니다: ',
    'Game audio could not be controlled on this device: ',
  ),
  gameAudioBackgroundSettingFailedPrefix: (
    '背景聲音設定失敗：',
    'バックグラウンド音声の設定に失敗：',
    '백그라운드 소리 설정 실패: ',
    'Failed to configure background audio: ',
  ),
  '后台保活状态同步失败：': (
    '背景保活狀態同步失敗：',
    'バックグラウンド動作の状態同期に失敗：',
    '백그라운드 유지 상태 동기화 실패: ',
    'Failed to synchronize background retention: ',
  ),
  '后台保活设置失败：': (
    '背景保活設定失敗：',
    'バックグラウンド動作の設定に失敗：',
    '백그라운드 유지 설정 실패: ',
    'Failed to configure background retention: ',
  ),
  '后台保活启动失败：': (
    '背景保活啟動失敗：',
    'バックグラウンド動作の開始に失敗：',
    '백그라운드 유지 시작 실패: ',
    'Failed to start background retention: ',
  ),
  '游戏页面启动失败：': (
    '遊戲頁面啟動失敗：',
    'ゲームページの起動に失敗：',
    '게임 페이지 시작 실패: ',
    'Failed to start the game page: ',
  ),
  '游戏页面准备失败：': (
    '遊戲頁面準備失敗：',
    'ゲームページの準備に失敗：',
    '게임 페이지 준비 실패: ',
    'Failed to prepare the game page: ',
  ),
  '抓包模式更新失败：': (
    '擷取模式更新失敗：',
    'キャプチャモードの更新に失敗：',
    '캡처 모드 업데이트 실패: ',
    'Failed to update the capture mode: ',
  ),
  '网络重试失败：': (
    '網路重試失敗：',
    'ネットワークの再試行に失敗：',
    '네트워크 재시도 실패: ',
    'Network retry failed: ',
  ),
  '网络重载失败：': (
    '網路重新載入失敗：',
    'ネットワークの再読み込みに失敗：',
    '네트워크 새로고침 실패: ',
    'Network reload failed: ',
  ),
  '捕获模式切换失败：': (
    '擷取模式切換失敗：',
    'キャプチャモードの切り替えに失敗：',
    '캡처 모드 전환 실패: ',
    'Failed to switch the capture mode: ',
  ),
  '捕获配置失败（': (
    '擷取設定失敗（',
    'キャプチャ設定に失敗（',
    '캡처 설정 실패(',
    'Capture configuration failed (',
  ),
  '原生 WebView 启动失败：': (
    '原生 WebView 啟動失敗：',
    'ネイティブ WebView の起動に失敗：',
    '네이티브 WebView 시작 실패: ',
    'Failed to start the native WebView: ',
  ),
  '原生 WebView 启动失败 [': (
    '原生 WebView 啟動失敗 [',
    'ネイティブ WebView の起動に失敗 [',
    '네이티브 WebView 시작 실패 [',
    'Failed to start the native WebView [',
  ),
  '原生 WebView 显示失败：': (
    '原生 WebView 顯示失敗：',
    'ネイティブ WebView の表示に失敗：',
    '네이티브 WebView 표시 실패: ',
    'Failed to display the native WebView: ',
  ),
  '暂不支持的外部跳转：': (
    '暫不支援的外部跳轉：',
    '未対応の外部ページへの遷移：',
    '지원하지 않는 외부 페이지 이동: ',
    'Unsupported external navigation: ',
  ),
};
