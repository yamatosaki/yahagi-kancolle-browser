import 'package:flutter/widgets.dart';

import 'ship_subtitle_settings.dart';

/// Interface labels follow the app language independently of subtitle text.
class ShipSubtitleStrings {
  const ShipSubtitleStrings(this.locale);
  factory ShipSubtitleStrings.of(BuildContext context) => ShipSubtitleStrings(
    Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
  );

  final Locale locale;

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

  String get title =>
      _t('舰娘语音字幕', '艦娘語音字幕', '艦娘ボイス字幕', 'Ship voice subtitles', '함선 음성 자막');

  String get description => _t(
    '在游戏画面内显示舰娘语音字幕，但是需要开启游戏内语音才能显示字幕。',
    '在遊戲畫面內顯示艦娘語音字幕，但是需要開啟遊戲內語音才能顯示字幕。',
    'ゲーム画面に艦娘ボイスの字幕を表示します。字幕の表示にはゲーム内のボイスを有効にする必要があります。',
    'Show ship voice subtitles inside the game. In-game voices must be enabled for subtitles to appear.',
    '게임 화면에 함선 음성 자막을 표시합니다. 자막을 표시하려면 게임 내 음성을 켜야 합니다.',
  );

  String get fontSize =>
      _t('字幕字体大小', '字幕字級', '字幕の文字サイズ', 'Subtitle font size', '자막 글꼴 크기');

  String get language =>
      _t('字幕语言', '字幕語言', '字幕の言語', 'Subtitle language', '자막 언어');

  String sizeLabel(ShipSubtitleFontSize size) => switch (size) {
    ShipSubtitleFontSize.small => _t('小', '小', '小', 'Small', '작게'),
    ShipSubtitleFontSize.medium => _t('中', '中', '中', 'Medium', '중간'),
    ShipSubtitleFontSize.large => _t('大', '大', '大', 'Large', '크게'),
  };

  String get dragHandleLabel =>
      _t('移动字幕', '移動字幕', '字幕を移動', 'Move subtitles', '자막 이동');

  String get saveFailed => _t(
    '字幕设置保存失败，请重试',
    '字幕設定儲存失敗，請重試',
    '字幕設定を保存できませんでした。もう一度お試しください',
    'Subtitle settings could not be saved. Please try again.',
    '자막 설정을 저장하지 못했습니다. 다시 시도하세요.',
  );

  String get runtimeChecking => _t(
    '正在检测字幕支持…',
    '正在檢測字幕支援…',
    '字幕の対応状況を確認しています…',
    'Checking subtitle support…',
    '자막 지원 여부를 확인하고 있습니다…',
  );

  String get runtimeUnsupported => _t(
    '当前 WebView 不支持字幕，请更新系统 WebView 后重新检测。',
    '目前 WebView 不支援字幕，請更新系統 WebView 後重新檢測。',
    '現在の WebView は字幕に対応していません。システムの WebView を更新して再確認してください。',
    'This WebView does not support subtitles. Update the system WebView, then check again.',
    '현재 WebView는 자막을 지원하지 않습니다. 시스템 WebView를 업데이트한 후 다시 확인하세요.',
  );

  String get runtimeFailed => _t(
    '字幕初始化失败，请重新检测。',
    '字幕初始化失敗，請重新檢測。',
    '字幕を初期化できませんでした。再確認してください。',
    'Subtitles could not be initialized. Please check again.',
    '자막을 초기화하지 못했습니다. 다시 확인하세요.',
  );

  String get runtimeWaitingForGameData => _t(
    '尚未取得舰娘语音资料，请在游戏模式重新载入游戏。',
    '尚未取得艦娘語音資料，請在遊戲模式重新載入遊戲。',
    '艦娘ボイスのデータをまだ取得していません。ゲームモードでゲームを再読み込みしてください。',
    'Ship voice data is not available yet. Reload the game in game mode.',
    '함선 음성 데이터를 아직 가져오지 못했습니다. 게임 모드에서 게임을 다시 불러오세요.',
  );

  String get retry => _t('重新检测', '重新檢測', '再確認', 'Check again', '다시 확인');

  String get dataTitle => _t(
    '舰娘语音字幕资料',
    '艦娘語音字幕資料',
    '艦娘ボイス字幕データ',
    'Ship subtitle data',
    '함선 음성 자막 데이터',
  );

  String get dataDescription => _t(
    '舰娘语音字幕文本',
    '艦娘語音字幕文字',
    '艦娘ボイスの字幕テキスト',
    'Ship voice subtitle text',
    '함선 음성 자막 텍스트',
  );
}
