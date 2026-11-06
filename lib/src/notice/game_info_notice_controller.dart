import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../bridge/captured_api_event.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import '../localization/game_name_catalog.dart';
import '../settings/layout_settings_controller.dart';
import '../toolbox/exp_calc/ship_exp_table.dart';
import '../widgets/top_notice.dart';

/// Intercepts game events and dispatches unified top bar notices for:
/// - Equipment development (single & 3-batch with slot-by-slot status)
/// - Equipment improvement (success and failure)
/// - Ship modernization (increases, MAX flags, failure)
/// - Marriage (luck bonus and remaining to cap)
/// - Sortie safety checks (ship/equipment capacity warnings)
/// - Expedition supply checks (Fleets 2, 3, and 4 fuel/ammo status)
/// - Practice assistant (opponent base experience and training cruiser bonus)
class GameInfoNoticeController implements GameApiEventConsumer {
  GameInfoNoticeController({
    required this.stateProvider,
    required this.layoutSettingsController,
    required this.topNoticeController,
    this.accountSession,
    this.namesProvider,
  }) : _noticeScope = accountSession?.current {
    accountSession?.addListener(_onAccountChanged);
  }

  final GameState Function() stateProvider;
  final LayoutSettingsController layoutSettingsController;
  final TopNoticeController topNoticeController;
  final AccountSession? accountSession;
  final GameNameCatalog Function()? namesProvider;
  AccountScope? _noticeScope;
  bool _disposed = false;

  void _onAccountChanged() {
    final current = accountSession?.current;
    if (identical(current, _noticeScope)) return;
    _noticeScope = current;
    topNoticeController.hide();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    accountSession?.removeListener(_onAccountChanged);
  }

  Future<void> _queue = Future<void>.value();

  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) {
    return path == '/kcsapi/api_req_kousyou/createitem' ||
        path == '/kcsapi/api_req_kousyou/remodel_slot' ||
        path == '/kcsapi/api_req_kaisou/powerup' ||
        path == '/kcsapi/api_req_kaisou/marriage' ||
        path == '/kcsapi/api_get_member/mapinfo' ||
        path == '/kcsapi/api_get_member/mission' ||
        path == '/kcsapi/api_req_member/get_practice_enemyinfo';
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed || !layoutSettingsController.topNoticeEnabled) {
      return;
    }

    // Immediately and synchronously capture the current state before any asynchronous
    // processing or pipeline reducers have a chance to update the state.
    final stateBefore = stateProvider();
    final scope = accountSession?.current;

    _queue = _queue.then((_) async {
      if (_disposed || (scope != null && !accountSession!.isCurrent(scope))) {
        return;
      }
      try {
        final rawData = GameApiDecoder.decodeEventData(
          event,
          allowMissingData: event.path == '/kcsapi/api_get_member/mission',
        );
        if (_disposed || (scope != null && !accountSession!.isCurrent(scope))) {
          return;
        }
        if (event.path == '/kcsapi/api_get_member/mission') {
          _handleExpeditionCheck(stateBefore);
          return;
        }
        if (rawData is! Map<String, Object?>) return;

        switch (event.path) {
          case '/kcsapi/api_req_kousyou/createitem':
            _handleDevelopment(rawData, stateBefore);
            break;
          case '/kcsapi/api_req_kousyou/remodel_slot':
            _handleEquipmentImprovement(rawData);
            break;
          case '/kcsapi/api_req_kaisou/powerup':
            _handleModernization(rawData, event, stateBefore);
            break;
          case '/kcsapi/api_req_kaisou/marriage':
            _handleMarriage(rawData, event, stateBefore);
            break;
          case '/kcsapi/api_get_member/mapinfo':
            _handleSortieCheck(stateBefore);
            break;
          case '/kcsapi/api_req_member/get_practice_enemyinfo':
            _handlePracticeEnemyInfo(rawData, stateBefore);
            break;
        }
      } catch (e, stack) {
        debugPrint(
          'GameInfoNoticeController error handling ${event.path}: $e\n$stack',
        );
      }
    });
  }

  void postNotice({
    required String message,
    required TopNoticeTone tone,
    IconData? icon,
    Color? color,
    Duration appendWithin = const Duration(milliseconds: 500),
    String? replacementKey,
  }) {
    if (_disposed || !layoutSettingsController.topNoticeEnabled) return;
    topNoticeController.show(
      message: message,
      tone: tone,
      customIcon: icon,
      customColor: color,
      duration: Duration(
        seconds: layoutSettingsController.topNoticeDurationSeconds,
      ),
      appendWithin: appendWithin,
      replacementKey: replacementKey,
    );
  }

  AppLocalizations _getL10n() {
    final code = layoutSettingsController.effectiveLocaleCode;
    if (code == 'zh_Hant') {
      return lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
    } else if (code == 'ja' || code == 'ko' || code == 'en') {
      return lookupAppLocalizations(Locale(code));
    }
    return lookupAppLocalizations(const Locale('zh'));
  }

  static int _asInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  static bool _isModernizationInt(Object? value) =>
      (value is int && value >= 0) ||
      (value is String && (int.tryParse(value) ?? -1) >= 0);

  static List<int> _requestShipIds(Object? value) {
    if (value is String) {
      return value.split(',').map(int.tryParse).whereType<int>().toList();
    }
    if (value is List) {
      return value.map(_asInt).where((id) => id > 0).toList();
    }
    return const <int>[];
  }

  /// Poi's theoretical maximum gain from the ships consumed in this request.
  static List<int?> _modernizationMaxDeltas(
    CapturedApiEvent event,
    GameState state,
  ) {
    final totals = List<int>.filled(4, 0);
    final rawSourceIds = event.requestParams['api_id_items'];
    final sourceIds = _requestShipIds(rawSourceIds);
    final requestedCount = rawSourceIds is String
        ? rawSourceIds.split(',').length
        : rawSourceIds is List
        ? rawSourceIds.length
        : 0;
    final incompleteSourceIds =
        sourceIds.isEmpty || sourceIds.length != requestedCount;
    var unknownPowerUp = incompleteSourceIds;
    var unknownLuck = incompleteSourceIds;
    var luckFifths = 0;
    for (final id in sourceIds) {
      final masterId = state.ships[id]?.masterId;
      if (masterId == null) {
        unknownPowerUp = true;
        unknownLuck = true;
        continue;
      }
      final powerUp = state.masterShips[masterId]?.powerUp ?? const <int>[];
      if (powerUp.length < 4) unknownPowerUp = true;
      for (var i = 0; i < 4 && i < powerUp.length; i++) {
        totals[i] += powerUp[i];
      }
      if (masterId == 163) luckFifths += 6;
      if (masterId == 402) luckFifths += 8;
    }
    return [
      for (final total in totals)
        unknownPowerUp ? null : total + ((total + 1) ~/ 5),
      unknownLuck ? null : (luckFifths / 5 - 0.0001).ceil(),
      0,
      0,
    ];
  }

  void _handleDevelopment(Map<String, Object?> data, GameState state) {
    final l10n = _getL10n();
    final rawGetItems = data['api_get_items'];
    if (rawGetItems is List && rawGetItems.isNotEmpty) {
      // 3-batch development
      final results = <String>[];
      var successCount = 0;
      for (final item in rawGetItems) {
        Map? slotItem;
        if (item is Map) {
          final nestedSlotItem = item['api_slot_item'];
          if (nestedSlotItem is Map && _asInt(item['api_create_flag']) == 1) {
            slotItem = nestedSlotItem;
          } else if (item.containsKey('api_slotitem_id')) {
            slotItem = item;
          }
        }

        final masterId = slotItem == null
            ? 0
            : _asInt(slotItem['api_slotitem_id']);
        if (masterId > 0) {
          successCount++;
          final name =
              state.masterSlotItems[masterId]?.name ??
              l10n.noticeDevDefaultName;
          results.add(namesProvider?.call().equipmentName(name) ?? name);
        } else {
          results.add(l10n.noticeDevSlotFailed);
        }
      }

      if (successCount == 0) {
        postNotice(
          message: l10n.noticeDevFailedPenguin,
          tone: TopNoticeTone.warning,
        );
      } else {
        postNotice(message: results.join(' / '), tone: TopNoticeTone.success);
      }
      return;
    }

    // Single development
    final createFlag = _asInt(data['api_create_flag']);
    if (createFlag == 1) {
      final slotItem = data['api_slot_item'];
      final masterId = slotItem is Map
          ? _asInt(slotItem['api_slotitem_id'])
          : 0;
      final name =
          state.masterSlotItems[masterId]?.name ?? l10n.noticeDevDefaultName;
      postNotice(
        message: l10n.noticeDevSuccess(
          namesProvider?.call().equipmentName(name) ?? name,
        ),
        tone: TopNoticeTone.success,
      );
    } else {
      postNotice(message: l10n.noticeDevFailed, tone: TopNoticeTone.warning);
    }
  }

  void _handleEquipmentImprovement(Map<String, Object?> data) {
    final l10n = _getL10n();
    final succeeded = _asInt(data['api_remodel_flag']) == 1;
    postNotice(
      message: succeeded
          ? l10n.noticeEquipImproveSuccess
          : l10n.noticeEquipImproveFailed,
      tone: succeeded ? TopNoticeTone.success : TopNoticeTone.warning,
      appendWithin: const Duration(milliseconds: 500),
    );
  }

  void _handleModernization(
    Map<String, Object?> data,
    CapturedApiEvent event,
    GameState state,
  ) {
    final l10n = _getL10n();
    final flag = _asInt(data['api_powerup_flag']);
    if (flag == 0) {
      postNotice(message: l10n.noticeModFailed, tone: TopNoticeTone.warning);
      return;
    }

    final rawShip = data['api_ship'];
    if (rawShip is! Map) {
      postNotice(message: l10n.noticeModSuccess, tone: TopNoticeTone.success);
      return;
    }

    final shipId = _asInt(rawShip['api_id']);
    final oldShip = state.ships[shipId];
    if (oldShip == null) {
      postNotice(message: l10n.noticeModSuccess, tone: TopNoticeTone.success);
      return;
    }

    final rawMasterId = _asInt(rawShip['api_ship_id']);
    final masterId = rawMasterId > 0 ? rawMasterId : oldShip.masterId;
    final master = state.masterShips[masterId];
    final oldKyouka = oldShip.modernization;

    final rawKyouka = rawShip['api_kyouka'];
    final kyoukaList =
        rawKyouka is List &&
            rawKyouka.length >= 7 &&
            rawKyouka.take(7).every(_isModernizationInt)
        ? rawKyouka.map(_asInt).toList()
        : null;

    // Poi compares api_kyouka before and after the request. The response's
    // displayed stats include equipment bonuses, so they are not a reliable
    // measure of modernization gains or remaining capacity.
    if (kyoukaList != null && kyoukaList.length >= 7 && oldKyouka.length >= 7) {
      final maxDeltas = _modernizationMaxDeltas(event, state);
      final labels = [
        l10n.statFirepower,
        l10n.statTorpedo,
        l10n.statAntiAir,
        l10n.statArmor,
        l10n.statLuck,
        l10n.statHp,
        l10n.statAsw,
      ];
      final details = <String>[];
      for (var i = 0; i < labels.length; i++) {
        final delta = kyoukaList[i] - oldKyouka[i];
        // Poi has master ranges for the first five stats only. HP and ASW
        // therefore have unknown remaining capacity, even when the displayed
        // ship stat happens to equal its current maximum.
        final remaining = i < 5
            ? master?.remainingModernization(i, kyoukaList[i])
            : null;
        if (delta == 0 &&
            !(remaining != null &&
                remaining > 0 &&
                maxDeltas[i] != null &&
                maxDeltas[i] != 0)) {
          continue;
        }
        final remainingText = remaining == null
            ? '?'
            : remaining <= 0
            ? 'MAX'
            : '+$remaining';
        final arrow =
            remaining == null ||
                remaining <= 0 ||
                (maxDeltas[i] != null && delta >= maxDeltas[i]!)
            ? '▲▲'
            : '▲';
        details.add('${labels[i]} $arrow $delta / $remainingText');
      }
      postNotice(
        message: details.isEmpty
            ? l10n.noticeModSuccess
            : l10n.noticeModSuccessDetail(details.join(' · ')),
        tone: TopNoticeTone.success,
      );
      return;
    }

    postNotice(message: l10n.noticeModSuccess, tone: TopNoticeTone.success);
  }

  void _handleMarriage(
    Map<String, Object?> data,
    CapturedApiEvent event,
    GameState state,
  ) {
    final l10n = _getL10n();
    final rawShip = data.containsKey('api_id')
        ? data
        : (data['api_ship'] ?? data['api_data']);
    if (rawShip is! Map) return;

    final shipId = _asInt(rawShip['api_id']);
    final oldShip = state.ships[shipId];
    if (oldShip == null) return;

    final rawLucky = rawShip['api_lucky'];
    final newLuck = rawLucky is List && rawLucky.isNotEmpty
        ? _asInt(rawLucky[0])
        : oldShip.luck;
    final maxLuck = rawLucky is List && rawLucky.length > 1
        ? _asInt(rawLucky[1])
        : oldShip.luckMax;

    final delta = newLuck - oldShip.luck;
    final remaining = maxLuck - newLuck;
    final arrow = delta > 4 ? '▲▲' : '▲';

    if (remaining <= 0) {
      postNotice(
        message: l10n.noticeMarriageLuckMax(arrow, delta),
        tone: TopNoticeTone.marriage,
      );
    } else {
      postNotice(
        message: l10n.noticeMarriageLuck(arrow, delta, remaining),
        tone: TopNoticeTone.marriage,
      );
    }
  }

  void _handleSortieCheck(GameState state) {
    final l10n = _getL10n();
    final maxShips = state.maxShipCount;
    final remainingShips = (maxShips != null && maxShips > 0)
        ? maxShips - state.ships.length
        : null;

    final maxItems = state.maxEquipmentCount;
    final remainingItems = (maxItems != null && maxItems > 0)
        ? maxItems - state.equipmentCapacityUsed
        : null;

    final shipFull = remainingShips != null && remainingShips <= 0;
    final itemFull = remainingItems != null && remainingItems <= 0;

    // Error priority: Full capacity
    if (shipFull && itemFull) {
      postNotice(
        message: l10n.noticeSortieShipAndItemFull,
        tone: TopNoticeTone.error,
      );
      return;
    }
    if (shipFull) {
      postNotice(message: l10n.noticeSortieShipFull, tone: TopNoticeTone.error);
      return;
    }
    if (itemFull) {
      postNotice(message: l10n.noticeSortieItemFull, tone: TopNoticeTone.error);
      return;
    }

    // 2. Warning: Low capacity (<= 5)
    final shipLow =
        remainingShips != null && remainingShips > 0 && remainingShips <= 5;
    final itemLow =
        remainingItems != null && remainingItems > 0 && remainingItems <= 5;

    if (shipLow && itemLow) {
      postNotice(
        message: l10n.noticeSortieShipAndItemLow(
          remainingShips,
          remainingItems,
        ),
        tone: TopNoticeTone.warning,
      );
      return;
    }
    if (shipLow) {
      postNotice(
        message: l10n.noticeSortieShipLow(remainingShips),
        tone: TopNoticeTone.warning,
      );
      return;
    }
    if (itemLow) {
      postNotice(
        message: l10n.noticeSortieItemLow(remainingItems),
        tone: TopNoticeTone.warning,
      );
      return;
    }
  }

  void _handleExpeditionCheck(GameState state) {
    if (state.fleets.isEmpty || !state.hasMasterData) {
      return;
    }

    final unresuppliedFleetIds = <int>[];
    for (final targetFleetId in const <int>[2, 3, 4]) {
      Fleet? fleet;
      for (final candidate in state.fleets) {
        if (candidate.id == targetFleetId) {
          fleet = candidate;
          break;
        }
      }
      if (fleet == null ||
          fleet.shipIds.isEmpty ||
          fleet.mission.isActive ||
          fleet.mission.state > 0) {
        continue;
      }

      var needsSupply = false;
      for (final shipId in fleet.shipIds) {
        final ship = state.ships[shipId];
        if (ship == null) continue;
        final master = state.masterShips[ship.masterId];
        if (master == null || (master.maxFuel <= 0 && master.maxAmmo <= 0)) {
          continue;
        }
        if (ship.currentFuel < master.maxFuel ||
            ship.currentAmmo < master.maxAmmo) {
          needsSupply = true;
          break;
        }
      }

      if (needsSupply) {
        unresuppliedFleetIds.add(targetFleetId);
      }
    }

    if (unresuppliedFleetIds.isEmpty) {
      return;
    }

    final l10n = _getL10n();
    final code = layoutSettingsController.effectiveLocaleCode;
    final separator = (code == 'en' || code == 'ko') ? ', ' : '、';
    final fleetsLabel = unresuppliedFleetIds.join(separator);
    postNotice(
      message: l10n.noticeExpeditionSupplyWarning(fleetsLabel),
      tone: TopNoticeTone.warning,
    );
  }

  void _handlePracticeEnemyInfo(Map<String, Object?> data, GameState state) {
    const noticeKey = 'practice-experience';
    final l10n = _getL10n();
    final rawDeck = data['api_deck'];
    if (rawDeck is! Map) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final rawShips = rawDeck['api_ships'];
    if (rawShips is! List || rawShips.isEmpty) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final firstShip = rawShips[0];
    final secondShip = rawShips.length > 1 ? rawShips[1] : null;

    final l1 = firstShip is Map ? _asInt(firstShip['api_level']) : 0;
    final l2 = secondShip is Map ? _asInt(secondShip['api_level']) : 0;

    if (l1 <= 0) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final baseExp = calculatePracticeBaseExp(l1, l2);
    if (baseExp <= 0) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final sExp = (baseExp * 1.2).round();
    final aExp = baseExp;

    // Check if player's fleet 1 contains Training Cruiser(s) (Katori / Kashima)
    final ctBonus = calculateFleetTrainingCruiserBonus(state);
    if (ctBonus > 0) {
      final multiplier = 1.0 + (ctBonus / 100.0);
      final boostedSExp = ((baseExp * 1.2) * multiplier).round();
      final boostedAExp = (baseExp * multiplier).round();
      final bonusStr = ctBonus % 1 == 0 ? '${ctBonus.toInt()}%' : '$ctBonus%';
      postNotice(
        message: l10n.noticePracticeExpCtBonus(
          boostedSExp,
          boostedAExp,
          bonusStr,
        ),
        tone: TopNoticeTone.info,
        replacementKey: noticeKey,
      );
    } else {
      postNotice(
        message: l10n.noticePracticeExp(sExp, aExp),
        tone: TopNoticeTone.info,
        replacementKey: noticeKey,
      );
    }
  }

  /// Calculates training cruiser bonus according to official 4-mode matrix:
  /// 1. CT Flagship only:
  ///    Lv 1~9: +5%, Lv 10~29: +8%, Lv 30~59: +12%, Lv 60~99: +15%, Lv 100+: +20%
  /// 2. CT Flagship + Companion:
  ///    Lv 1~9: +10%, Lv 10~29: +13%, Lv 30~59: +16%, Lv 60~99: +20%, Lv 100+: +25%
  /// 3. Companion 1 only (no CT flagship):
  ///    Lv 1~9: +3%, Lv 10~29: +5%, Lv 30~59: +7%, Lv 60~99: +10%, Lv 100+: +15%
  /// 4. Companion 2 only (no CT flagship):
  ///    Lv 1~9: +4%, Lv 10~29: +6%, Lv 30~59: +8%, Lv 60~99: +12%, Lv 100+: +17.5%
  static double calculateFleetTrainingCruiserBonus(GameState state) {
    if (state.fleets.isEmpty) return 0.0;
    final firstFleet = state.fleets[0];
    var isFlagshipCt = false;
    var accompanyingCtCount = 0;
    var flagshipLevel = 1;
    var maxAccompanyingCtLevel = 1;

    for (var i = 0; i < firstFleet.shipIds.length; i++) {
      final shipId = firstFleet.shipIds[i];
      final ship = state.ships[shipId];
      if (ship == null) continue;
      final master = state.masterShips[ship.masterId];
      final isCt =
          master?.shipTypeId == 21 ||
          (master?.name.contains('香取') ?? false) ||
          (master?.name.contains('鹿島') ?? false);

      if (isCt) {
        if (i == 0) {
          isFlagshipCt = true;
          flagshipLevel = ship.level;
        } else {
          accompanyingCtCount++;
          if (ship.level > maxAccompanyingCtLevel) {
            maxAccompanyingCtLevel = ship.level;
          }
        }
      }
    }

    if (!isFlagshipCt && accompanyingCtCount == 0) return 0.0;

    // 1. CT Flagship only
    if (isFlagshipCt && accompanyingCtCount == 0) {
      if (flagshipLevel >= 100) return 20.0;
      if (flagshipLevel >= 60) return 15.0;
      if (flagshipLevel >= 30) return 12.0;
      if (flagshipLevel >= 10) return 8.0;
      return 5.0;
    }

    // 2. CT Flagship + Companion
    if (isFlagshipCt && accompanyingCtCount > 0) {
      if (flagshipLevel >= 100) return 25.0;
      if (flagshipLevel >= 60) return 20.0;
      if (flagshipLevel >= 30) return 16.0;
      if (flagshipLevel >= 10) return 13.0;
      return 10.0;
    }

    // 3. Companion 1 only (no CT flagship)
    if (!isFlagshipCt && accompanyingCtCount == 1) {
      if (maxAccompanyingCtLevel >= 100) return 15.0;
      if (maxAccompanyingCtLevel >= 60) return 10.0;
      if (maxAccompanyingCtLevel >= 30) return 7.0;
      if (maxAccompanyingCtLevel >= 10) return 5.0;
      return 3.0;
    }

    // 4. Companion 2 only (no CT flagship)
    if (!isFlagshipCt && accompanyingCtCount >= 2) {
      if (maxAccompanyingCtLevel >= 100) return 17.5;
      if (maxAccompanyingCtLevel >= 60) return 12.0;
      if (maxAccompanyingCtLevel >= 30) return 8.0;
      if (maxAccompanyingCtLevel >= 10) return 6.0;
      return 4.0;
    }

    return 0.0;
  }

  /// Practice opponent base experience formula:
  /// - Base exp = floor(exp(L1) / 100 + exp(L2) / 300)
  /// - When total > 500: floor(500 + sqrt(total - 500))
  /// - Minimum exp for valid non-empty opponent is 10.
  /// - Returns 0 for 0-ship/empty opponent (L1 <= 0).
  static int calculatePracticeBaseExp(int l1, int l2) {
    if (l1 <= 0) return 0;
    final exp1 = shipCumulativeExp(l1);
    final exp2 = l2 > 0 ? shipCumulativeExp(l2) : 0;
    final total = (exp1 / 100.0) + (exp2 / 300.0);
    if (total <= 0) return 10;
    if (total > 500) {
      return (500.0 + math.sqrt(total - 500.0)).floor();
    }
    return total.floor();
  }
}
