import 'package:flutter/widgets.dart';

import 'expedition_models.dart';

class ExpeditionStrings {
  const ExpeditionStrings._(this.languageCode, this.traditional);

  factory ExpeditionStrings.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ExpeditionStrings._(
      locale.languageCode,
      locale.scriptCode == 'Hant' || locale.countryCode == 'TW',
    );
  }

  final String languageCode;
  final bool traditional;

  bool get _ja => languageCode == 'ja';
  String get title => _ja
      ? '遠征チェック'
      : traditional
      ? '遠征檢查'
      : '远征检查';
  String get compact => _ja ? '簡潔' : '简洁';
  String get detailed => _ja ? '詳細' : '详细';
  String get success => _ja ? '成功' : '成功';
  String get greatSuccess => _ja ? '大成功' : '大成功';
  String get detailsPage => _ja
      ? '詳細画面'
      : traditional
      ? '詳情頁'
      : '详情页';
  String get waiting => _ja
      ? '母港データを待っています'
      : traditional
      ? '等待母港資料'
      : '等待母港数据';
  String get selectExpedition => _ja
      ? '遠征を選択'
      : traditional
      ? '選擇遠征'
      : '选择远征';
  String get expectedIncome => _ja
      ? '予想収入'
      : traditional
      ? '預計收入'
      : '预计收入';
  String get conditions => _ja
      ? '遠征条件'
      : traditional
      ? '遠征條件'
      : '远征条件';
  String get normalCheck => _ja
      ? '通常チェック'
      : traditional
      ? '常規檢查'
      : '常规检查';
  String get passed => _ja
      ? '合格'
      : traditional
      ? '通過'
      : '通过';
  String get failed => _ja
      ? '不合格'
      : traditional
      ? '未通過'
      : '未通过';
  String get targetRate => _ja
      ? '目標確率'
      : traditional
      ? '目標概率'
      : '目标概率';
  String get timeAndCost => _ja
      ? '所要時間と消費'
      : traditional
      ? '遠征時間與消耗'
      : '远征时间与消耗';
  String get requiredTime => _ja
      ? '所要時間'
      : traditional
      ? '所需時間'
      : '所需时间';
  String get fuelCost => _ja
      ? '燃料消費'
      : traditional
      ? '燃料消耗'
      : '燃料消耗';
  String get ammoCost => _ja
      ? '弾薬消費'
      : traditional
      ? '彈藥消耗'
      : '弹药消耗';
  String get back => _ja
      ? 'ゲームに戻る'
      : traditional
      ? '返回遊戲'
      : '返回游戏';

  String get satisfied => _ja
      ? '達成'
      : traditional
      ? '已滿足'
      : '已满足';
  String get notSatisfied => _ja
      ? '未達成'
      : traditional
      ? '未滿足'
      : '未满足';

  String conditionLabel(ExpeditionConditionResult value) {
    final number = RegExp(r'\d+').firstMatch(value.label)?.group(0) ?? '';
    return switch (value.kind) {
      ExpeditionConditionKind.flagshipLevel =>
        _ja
            ? '旗艦レベル ≥ $number'
            : traditional
            ? '旗艦等級 ≥ $number'
            : value.label,
      ExpeditionConditionKind.shipCount =>
        _ja
            ? '艦数 ≥ $number'
            : traditional
            ? '艦船數量 ≥ $number'
            : value.label,
      ExpeditionConditionKind.composition =>
        _ja
            ? '艦隊編成条件'
            : traditional
            ? '艦隊構成條件'
            : value.label,
      ExpeditionConditionKind.flagshipType =>
        _ja
            ? '旗艦艦種条件'
            : traditional
            ? '旗艦艦種條件'
            : value.label,
      ExpeditionConditionKind.levelSum =>
        _ja
            ? '艦隊レベル合計 ≥ $number'
            : traditional
            ? '艦隊等級合計 ≥ $number'
            : value.label,
      ExpeditionConditionKind.resupply =>
        _ja
            ? '艦隊補給済み'
            : traditional
            ? '艦隊完成補給'
            : value.label,
      ExpeditionConditionKind.morale =>
        _ja
            ? '全員コンディション ≥ $number'
            : traditional
            ? '全員士氣 ≥ $number'
            : value.label,
      ExpeditionConditionKind.drumCount =>
        _ja
            ? 'ドラム缶数 ≥ $number'
            : traditional
            ? '運輸桶數量 ≥ $number'
            : value.label,
      ExpeditionConditionKind.drumCarrierCount =>
        _ja
            ? 'ドラム缶搭載艦 ≥ $number'
            : traditional
            ? '攜帶運輸桶艦船 ≥ $number'
            : value.label,
      ExpeditionConditionKind.firepower =>
        _ja
            ? '合計火力 ≥ $number'
            : traditional
            ? '總火力 ≥ $number'
            : value.label,
      ExpeditionConditionKind.antiAir =>
        _ja
            ? '合計対空 ≥ $number'
            : traditional
            ? '總對空 ≥ $number'
            : value.label,
      ExpeditionConditionKind.antiSub =>
        _ja
            ? '合計対潜 ≥ $number'
            : traditional
            ? '總對潛 ≥ $number'
            : value.label,
      ExpeditionConditionKind.lineOfSight =>
        _ja
            ? '合計索敵 ≥ $number'
            : traditional
            ? '總索敵 ≥ $number'
            : value.label,
      ExpeditionConditionKind.greatSuccessRate =>
        _ja
            ? '現在の大成功率 ≥ $number%'
            : traditional
            ? '目前大成功概率 ≥ $number%'
            : value.label,
      ExpeditionConditionKind.allSparkled =>
        _ja
            ? '全艦キラ状態'
            : traditional
            ? '艦隊全體處於戰意高昂'
            : value.label,
      ExpeditionConditionKind.higherLevelFlagship =>
        _ja
            ? '艦隊最高レベル艦が旗艦'
            : traditional
            ? '艦隊最高等級艦為旗艦'
            : value.label,
      ExpeditionConditionKind.daihatsuFill =>
        _ja
            ? '可能な限り大発系装備を搭載'
            : traditional
            ? '盡可能多攜帶大發系裝備'
            : value.label,
    };
  }

  String conditionActual(ExpeditionConditionResult value) {
    if (value.actual == '已满足' ||
        value.actual == '未满足' ||
        value.actual == '已补满') {
      return value.passed ? satisfied : notSatisfied;
    }
    return value.actual;
  }
}
