import 'package:flutter/widgets.dart';

import 'expedition_models.dart';
import '../localization/ui_text.dart';

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
  String get compact => _ja || traditional ? '簡潔' : '简洁';
  String get detailed => _ja || traditional ? '詳細' : '详细';
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
  String get expeditionFallbackName => _ja
      ? '遠征'
      : traditional
      ? '遠征'
      : '远征';
  String expeditionAreaName(int areaId) => switch (areaId) {
    1 => _ja || traditional ? '鎮守府海域' : '镇守府海域',
    2 =>
      _ja
          ? '南西諸島海域'
          : traditional
          ? '南西群島海域'
          : '南西群岛海域',
    3 => _ja ? '北方海域' : '北方海域',
    4 => _ja ? '西方海域' : '西方海域',
    5 => _ja ? '南方海域' : '南方海域',
    7 => _ja ? '南西海域' : '南西海域',
    _ =>
      _ja
          ? '海域 $areaId'
          : traditional
          ? '海域 $areaId'
          : '海域 $areaId',
  };
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
            ? value.label.replaceFirst('舰队构成：', '艦隊編成：')
            : traditional
            ? value.label.replaceFirst('舰队构成：', '艦隊構成：')
            : value.label,
      ExpeditionConditionKind.flagshipType =>
        _ja
            ? '旗艦艦種：${_localizedFlagshipType(value.label, japanese: true)}'
            : traditional
            ? '旗艦艦種為${_localizedFlagshipType(value.label, traditional: true)}'
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
      ExpeditionConditionKind.daihatsuFill =>
        _ja
            ? '可能な限り大発動艇または特大発動艇を搭載'
            : traditional
            ? '盡可能多攜帶大發動艇或特大發動艇'
            : value.label,
    };
  }

  String _localizedFlagshipType(
    String label, {
    bool japanese = false,
    bool traditional = false,
  }) {
    final code = RegExp(r'（([A-Z]+)）').firstMatch(label)?.group(1) ?? '';
    final unknownTypeId = RegExp(r'舰种 (\d+)').firstMatch(label)?.group(1);
    if (code.isEmpty && unknownTypeId != null) {
      return japanese || traditional
          ? '艦種 $unknownTypeId'
          : '舰种 $unknownTypeId';
    }
    final name = switch (code) {
      'CL' =>
        japanese
            ? '軽巡洋艦'
            : traditional
            ? '輕巡洋艦'
            : '轻巡洋舰',
      'CA' =>
        japanese
            ? '重巡洋艦'
            : traditional
            ? '重巡洋艦'
            : '重巡洋舰',
      'CVL' =>
        japanese
            ? '軽空母'
            : traditional
            ? '輕空母'
            : '轻空母',
      'AV' =>
        japanese
            ? '水上機母艦'
            : traditional
            ? '水上機母艦'
            : '水上机母舰',
      'AS' =>
        japanese
            ? '潜水母艦'
            : traditional
            ? '潛水母艦'
            : '潜水母舰',
      'CT' =>
        japanese
            ? '練習巡洋艦'
            : traditional
            ? '練習巡洋艦'
            : '练习巡洋舰',
      _ =>
        japanese
            ? '指定艦種'
            : traditional
            ? '指定艦種'
            : '指定舰种',
    };
    return code.isEmpty ? name : '$name（$code）';
  }

  String conditionActual(ExpeditionConditionResult value) {
    if (value.actual == '已补满') {
      return _ja
          ? '補給済み'
          : traditional
          ? '已補滿'
          : value.actual;
    }
    if (value.actual == '已满足' || value.actual == '未满足') {
      return value.passed ? satisfied : notSatisfied;
    }
    return uiTextForLocale(
      Locale.fromSubtags(
        languageCode: languageCode,
        scriptCode: traditional ? 'Hant' : null,
      ),
      value.actual,
    );
  }
}
