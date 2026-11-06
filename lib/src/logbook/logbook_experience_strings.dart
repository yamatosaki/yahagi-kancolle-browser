import 'package:flutter/widgets.dart';

import '../localization/ui_text.dart';

final class LogbookExperienceStrings {
  LogbookExperienceStrings.of(BuildContext context)
    : _locale = Localizations.localeOf(context);

  final Locale _locale;

  String _text(String zh, String hant, String ja, String ko, String en) =>
      switch (_locale.languageCode) {
        'ja' => ja,
        'ko' => ko,
        'en' => en,
        'zh'
            when _locale.scriptCode == 'Hant' ||
                const {'TW', 'HK', 'MO'}.contains(_locale.countryCode) =>
          hant,
        _ => zh,
      };

  String get tab => _text('经验', '經驗', '経験値', '경험치', 'EXP');
  String loaded(int count) => _text(
    '已加载 $count 条',
    '已載入 $count 筆',
    '$count 件を表示中',
    '$count개 표시 중',
    '$count loaded',
  );
  String total(int count) => uiTextForLocale(_locale, '共 $count 条');
  String get empty => uiTextForLocale(_locale, '暂无记录');
  String get practice => uiTextForLocale(_locale, '演习');
  String get completedAt => _text('完成时间', '完成時間', '完了時刻', '완료 시각', 'Completed');
  String get type => _text('类型', '類型', '種別', '유형', 'Type');
  String get areaType =>
      _text('海域 / 类型', '海域 / 類型', '海域 / 種別', '해역 / 유형', 'Area / type');
  String get fleet => _text('舰队', '艦隊', '艦隊', '함대', 'Fleet');
  String get battles => _text('战斗结算', '戰鬥結算', '戦闘結果', '전투 결과', 'Battles');
  String get fleetAndBattles =>
      _text('舰队 / 战斗', '艦隊 / 戰鬥', '艦隊 / 戦闘', '함대 / 전투', 'Fleet / battles');
  String get typeFleetAndBattles => _text(
    '类型 / 舰队 / 战斗',
    '類型 / 艦隊 / 戰鬥',
    '種別 / 艦隊 / 戦闘',
    '유형 / 함대 / 전투',
    'Type / fleet / battles',
  );
  String get combined =>
      _text('联合舰队', '聯合艦隊', '連合艦隊', '연합 함대', 'Combined fleet');
  String get partial =>
      _text('部分记录', '部分記錄', '一部記録', '일부 기록', 'Partial record');
  String get retry => _text(
    '读取失败，点击重试',
    '讀取失敗，點擊重試',
    '読み込みに失敗しました。再試行',
    '불러오지 못했습니다. 다시 시도',
    'Unable to load. Retry',
  );

  String gained(bool practice) => practice
      ? _text('本次演习经验', '本次演習經驗', '今回の演習経験値', '이번 연습 경험치', 'Exercise EXP')
      : _text('本次出击经验', '本次出擊經驗', '今回の出撃経験値', '이번 출격 경험치', 'Sortie EXP');
}
