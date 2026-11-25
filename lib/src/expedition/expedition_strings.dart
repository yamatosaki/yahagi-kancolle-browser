import 'package:flutter/widgets.dart';

import 'expedition_models.dart';
import '../localization/ui_text.dart';

class ExpeditionStrings {
  const ExpeditionStrings._(this.languageCode, this.traditional);

  factory ExpeditionStrings.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ExpeditionStrings._(
      locale.languageCode,
      locale.languageCode == 'zh' &&
          (locale.scriptCode == 'Hant' ||
              const ['TW', 'HK', 'MO'].contains(locale.countryCode)),
    );
  }

  final String languageCode;
  final bool traditional;

  bool get _ja => languageCode == 'ja';
  bool get _ko => languageCode == 'ko';
  bool get _en => languageCode == 'en';
  String get progress => _en
      ? 'Expedition progress'
      : _ko
      ? '원정 진행도'
      : _ja
      ? '遠征進捗'
      : traditional
      ? '遠征進度'
      : '远征进度';
  String get title => _en
      ? 'Expedition check'
      : _ko
      ? '원정 점검'
      : _ja
      ? '遠征チェック'
      : traditional
      ? '遠征檢查'
      : '远征检查';
  String get modeProgress => _en
      ? 'Progress'
      : _ko
      ? '진행도'
      : _ja
      ? '進捗'
      : traditional
      ? '進度'
      : '进度';
  String get modeCheck => _en
      ? 'Check'
      : _ko
      ? '점검'
      : _ja
      ? 'チェック'
      : traditional
      ? '檢查'
      : '检查';
  String get compact => _en
      ? 'Compact'
      : _ko
      ? '간단히'
      : _ja || traditional
      ? '簡潔'
      : '简洁';
  String get detailed => _en
      ? 'Detailed'
      : _ko
      ? '자세히'
      : _ja || traditional
      ? '詳細'
      : '详细';
  String get success => _en
      ? 'Success'
      : _ko
      ? '성공'
      : _ja
      ? '成功'
      : '成功';
  String get greatSuccess => _en
      ? 'Great success'
      : _ko
      ? '대성공'
      : _ja
      ? '大成功'
      : '大成功';
  String get detailsPage => _en
      ? 'Details'
      : _ko
      ? '상세 화면'
      : _ja
      ? '詳細画面'
      : traditional
      ? '詳情頁'
      : '详情页';
  String get waiting => _en
      ? 'Waiting for port data'
      : _ko
      ? '모항 데이터를 기다리는 중'
      : _ja
      ? '母港データを待っています'
      : traditional
      ? '等待母港資料'
      : '等待母港数据';
  String get selectExpedition => _en
      ? 'Select expedition'
      : _ko
      ? '원정 선택'
      : _ja
      ? '遠征を選択'
      : traditional
      ? '選擇遠征'
      : '选择远征';
  String get expeditionFallbackName => _en
      ? 'Expedition'
      : _ko
      ? '원정'
      : _ja
      ? '遠征'
      : traditional
      ? '遠征'
      : '远征';
  String expeditionAreaName(int areaId) => _ko || _en
      ? switch (areaId) {
          1 => '鎮守府海域',
          2 => '南西諸島海域',
          3 => '北方海域',
          4 => '西方海域',
          5 => '南方海域',
          7 => '南西海域',
          _ => _en ? 'Area $areaId' : '해역 $areaId',
        }
      : switch (areaId) {
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
  String get expectedIncome => _en
      ? 'Expected rewards'
      : _ko
      ? '예상 수입'
      : _ja
      ? '予想収入'
      : traditional
      ? '預計收入'
      : '预计收入';
  String get conditions => _en
      ? 'Expedition requirements'
      : _ko
      ? '원정 조건'
      : _ja
      ? '遠征条件'
      : traditional
      ? '遠征條件'
      : '远征条件';
  String get normalCheck => _en
      ? 'Normal check'
      : _ko
      ? '일반 점검'
      : _ja
      ? '通常チェック'
      : traditional
      ? '常規檢查'
      : '常规检查';
  String get passed => _en
      ? 'Passed'
      : _ko
      ? '통과'
      : _ja
      ? '合格'
      : traditional
      ? '通過'
      : '通过';
  String get failed => _en
      ? 'Failed'
      : _ko
      ? '미통과'
      : _ja
      ? '不合格'
      : traditional
      ? '未通過'
      : '未通过';
  String get targetRate => _en
      ? 'Target chance'
      : _ko
      ? '목표 확률'
      : _ja
      ? '目標確率'
      : traditional
      ? '目標機率'
      : '目标概率';
  String get timeAndCost => _en
      ? 'Time and cost'
      : _ko
      ? '소요 시간 및 소모'
      : _ja
      ? '所要時間と消費'
      : traditional
      ? '遠征時間與消耗'
      : '远征时间与消耗';
  String get requiredTime => _en
      ? 'Time required'
      : _ko
      ? '소요 시간'
      : _ja
      ? '所要時間'
      : traditional
      ? '所需時間'
      : '所需时间';
  String get estimatedCompletionTime => _en
      ? 'Estimated completion time'
      : _ko
      ? '예상 완료 시각'
      : _ja
      ? '完了予定時刻'
      : traditional
      ? '預計完成時間'
      : '预计完成时间';
  String get fuelCost => _en
      ? 'Fuel cost'
      : _ko
      ? '연료 소모'
      : _ja
      ? '燃料消費'
      : traditional
      ? '燃料消耗'
      : '燃料消耗';
  String get ammoCost => _en
      ? 'Ammo cost'
      : _ko
      ? '탄약 소모'
      : _ja
      ? '弾薬消費'
      : traditional
      ? '彈藥消耗'
      : '弹药消耗';
  String get back => _en
      ? 'Back to game'
      : _ko
      ? '게임으로 돌아가기'
      : _ja
      ? 'ゲームに戻る'
      : traditional
      ? '返回遊戲'
      : '返回游戏';
  String get satisfied => _en
      ? 'Met'
      : _ko
      ? '충족'
      : _ja
      ? '達成'
      : traditional
      ? '已滿足'
      : '已满足';
  String get notSatisfied => _en
      ? 'Not met'
      : _ko
      ? '미충족'
      : _ja
      ? '未達成'
      : traditional
      ? '未滿足'
      : '未满足';

  String conditionLabel(ExpeditionConditionResult value) {
    final number = RegExp(r'\d+').firstMatch(value.label)?.group(0) ?? '';
    final greatSuccessDrums = value.label.startsWith('大成功');
    if (_en) {
      return switch (value.kind) {
        ExpeditionConditionKind.flagshipLevel => 'Flagship level ≥ $number',
        ExpeditionConditionKind.shipCount => 'Ship count ≥ $number',
        ExpeditionConditionKind.composition => value.label.replaceFirst(
          '舰队构成：',
          'Fleet composition: ',
        ),
        ExpeditionConditionKind.flagshipType =>
          'Flagship type: ${_localizedFlagshipType(value.label, english: true)}',
        ExpeditionConditionKind.levelSum => 'Total fleet level ≥ $number',
        ExpeditionConditionKind.resupply => 'Fleet fully supplied',
        ExpeditionConditionKind.morale => 'All ships: morale ≥ $number',
        ExpeditionConditionKind.drumCount =>
          greatSuccessDrums
              ? 'Drum count for great success ≥ $number'
              : 'Drum count ≥ $number',
        ExpeditionConditionKind.drumCarrierCount =>
          'Ships carrying drums ≥ $number',
        ExpeditionConditionKind.firepower => 'Total firepower ≥ $number',
        ExpeditionConditionKind.antiAir => 'Total anti-air ≥ $number',
        ExpeditionConditionKind.antiSub => 'Total anti-sub ≥ $number',
        ExpeditionConditionKind.lineOfSight => 'Total LOS ≥ $number',
        ExpeditionConditionKind.greatSuccessRate =>
          'Current great success chance ≥ $number%',
        ExpeditionConditionKind.allSparkled => 'All ships sparkled',
        ExpeditionConditionKind.daihatsuFill =>
          'Equip as many 大発動艇 or 特大発動艇 as possible',
      };
    }
    if (_ko) {
      return switch (value.kind) {
        ExpeditionConditionKind.flagshipLevel => '기함 레벨 ≥ $number',
        ExpeditionConditionKind.shipCount => '함선 수 ≥ $number',
        ExpeditionConditionKind.composition => value.label.replaceFirst(
          '舰队构成：',
          '함대 구성: ',
        ),
        ExpeditionConditionKind.flagshipType =>
          '기함 함종: ${_localizedFlagshipType(value.label, korean: true)}',
        ExpeditionConditionKind.levelSum => '함대 레벨 합계 ≥ $number',
        ExpeditionConditionKind.resupply => '함대 보급 완료',
        ExpeditionConditionKind.morale => '전원 컨디션 ≥ $number',
        ExpeditionConditionKind.drumCount =>
          greatSuccessDrums ? '대성공 드럼통 수 ≥ $number' : '드럼통 수 ≥ $number',
        ExpeditionConditionKind.drumCarrierCount => '드럼통 탑재함 수 ≥ $number',
        ExpeditionConditionKind.firepower => '총 화력 ≥ $number',
        ExpeditionConditionKind.antiAir => '총 대공 ≥ $number',
        ExpeditionConditionKind.antiSub => '총 대잠 ≥ $number',
        ExpeditionConditionKind.lineOfSight => '총 색적 ≥ $number',
        ExpeditionConditionKind.greatSuccessRate => '현재 대성공 확률 ≥ $number%',
        ExpeditionConditionKind.allSparkled => '모든 함선이 반짝이 상태',
        ExpeditionConditionKind.daihatsuFill => '가능한 한 大発動艇 또는 特大発動艇을 많이 탑재',
      };
    }
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
            ? '${greatSuccessDrums ? '大成功に必要な' : ''}ドラム缶数 ≥ $number'
            : traditional
            ? '${greatSuccessDrums ? '大成功' : ''}運輸桶數量 ≥ $number'
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
            ? '目前大成功機率 ≥ $number%'
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
    bool korean = false,
    bool english = false,
  }) {
    final code = RegExp(r'（([A-Z]+)）').firstMatch(label)?.group(1) ?? '';
    final unknownTypeId = RegExp(r'舰种 (\d+)').firstMatch(label)?.group(1);
    if (english) {
      if (code.isEmpty && unknownTypeId != null) {
        return 'Ship type $unknownTypeId';
      }
      final name = switch (code) {
        'CL' => 'Light cruiser',
        'CA' => 'Heavy cruiser',
        'CVL' => 'Light carrier',
        'AV' => 'Seaplane tender',
        'AS' => 'Submarine tender',
        'CT' => 'Training cruiser',
        _ => 'Specified ship type',
      };
      return code.isEmpty ? name : '$name ($code)';
    }
    if (korean) {
      if (code.isEmpty && unknownTypeId != null) return '함종 $unknownTypeId';
      final name = switch (code) {
        'CL' => '경순양함',
        'CA' => '중순양함',
        'CVL' => '경항모',
        'AV' => '수상기모함',
        'AS' => '잠수모함',
        'CT' => '연습순양함',
        _ => '지정 함종',
      };
      return code.isEmpty ? name : '$name($code)';
    }
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
      return _en
          ? 'Fully supplied'
          : _ko
          ? '보급 완료'
          : _ja
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
