abstract final class GameCapturePathCatalog {
  static const Set<String> gameState = <String>{
    '/kcsapi/api_start2/getData',
    '/kcsapi/api_port/port',
    '/kcsapi/api_get_member/basic',
    '/kcsapi/api_get_member/require_info',
    '/kcsapi/api_get_member/useitem',
    '/kcsapi/api_get_member/material',
    '/kcsapi/api_get_member/deck',
    '/kcsapi/api_get_member/ship2',
    '/kcsapi/api_get_member/ship3',
    '/kcsapi/api_get_member/ship_deck',
    '/kcsapi/api_get_member/slot_item',
    '/kcsapi/api_get_member/ndock',
    '/kcsapi/api_get_member/kdock',
    '/kcsapi/api_get_member/questlist',
    '/kcsapi/api_get_member/mapinfo',
    '/kcsapi/api_req_air_corps/set_plane',
    '/kcsapi/api_req_air_corps/change_deployment_base',
    '/kcsapi/api_req_air_corps/set_action',
    '/kcsapi/api_req_air_corps/supply',
    '/kcsapi/api_req_air_corps/change_name',
    '/kcsapi/api_req_air_corps/cond_recovery',
    '/kcsapi/api_port/airCorpsCondRecoveryWithTimer',
    '/kcsapi/api_req_hokyu/charge',
    '/kcsapi/api_req_kaisou/slotset',
    '/kcsapi/api_req_kaisou/slotset_ex',
    '/kcsapi/api_req_kaisou/unsetslot_all',
    '/kcsapi/api_req_kaisou/slot_deprive',
    '/kcsapi/api_req_kaisou/slot_exchange_index',
    '/kcsapi/api_req_kousyou/createship',
    '/kcsapi/api_req_kousyou/createitem',
    '/kcsapi/api_req_kousyou/remodel_slot',
    '/kcsapi/api_req_kousyou/remodel_slot_recover',
    '/kcsapi/api_req_member/itemuse',
    '/kcsapi/api_req_kousyou/destroyship',
    '/kcsapi/api_req_kousyou/destroyitem2',
    '/kcsapi/api_req_kousyou/createship_speedchange',
    '/kcsapi/api_req_kousyou/getship',
    '/kcsapi/api_req_hensei/change',
    '/kcsapi/api_req_hensei/combined',
    '/kcsapi/api_req_hensei/preset_select',
    '/kcsapi/api_req_kaisou/powerup',
    '/kcsapi/api_req_kaisou/marriage',
    '/kcsapi/api_req_kaisou/open_exslot',
    '/kcsapi/api_req_kaisou/hangar_expand',
    '/kcsapi/api_req_nyukyo/start',
    '/kcsapi/api_req_nyukyo/speedchange',
    '/kcsapi/api_req_quest/clearitemget',
    '/kcsapi/api_req_quest/stop',
    '/kcsapi/api_req_quest/start',
    '/kcsapi/api_req_map/select_eventmap_rank',
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/next',
    '/kcsapi/api_req_map/air_raid',
    '/kcsapi/api_req_sortie/battle',
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_combined_battle/battleresult',
    '/kcsapi/api_req_sortie/goback_port',
    '/kcsapi/api_req_combined_battle/goback_port',
    '/kcsapi/api_req_mission/result',
    '/kcsapi/api_req_mission/start',
    '/kcsapi/api_req_practice/battle_result',
  };

  static const Set<String> battleMap = <String>{
    '/kcsapi/api_req_map/start',
    '/kcsapi/api_req_map/next',
  };

  static const Set<String> battlePhases = <String>{
    '/kcsapi/api_req_practice/battle',
    '/kcsapi/api_req_practice/midnight_battle',
    '/kcsapi/api_req_sortie/battle',
    '/kcsapi/api_req_sortie/airbattle',
    '/kcsapi/api_req_sortie/ld_airbattle',
    '/kcsapi/api_req_sortie/ld_shooting',
    '/kcsapi/api_req_combined_battle/battle',
    '/kcsapi/api_req_combined_battle/battle_water',
    '/kcsapi/api_req_combined_battle/airbattle',
    '/kcsapi/api_req_combined_battle/ld_airbattle',
    '/kcsapi/api_req_combined_battle/ld_shooting',
    '/kcsapi/api_req_combined_battle/ec_battle',
    '/kcsapi/api_req_combined_battle/each_battle',
    '/kcsapi/api_req_combined_battle/each_battle_water',
    '/kcsapi/api_req_battle_midnight/battle',
    '/kcsapi/api_req_battle_midnight/sp_midnight',
    '/kcsapi/api_req_combined_battle/midnight_battle',
    '/kcsapi/api_req_combined_battle/sp_midnight',
    '/kcsapi/api_req_combined_battle/ec_midnight_battle',
    '/kcsapi/api_req_combined_battle/ec_night_to_day',
  };

  static const Set<String> battleResults = <String>{
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_combined_battle/battleresult',
    '/kcsapi/api_req_practice/battle_result',
  };

  static const Set<String> battleRetreat = <String>{
    '/kcsapi/api_req_sortie/goback_port',
    '/kcsapi/api_req_combined_battle/goback_port',
  };

  static const Set<String> battle = <String>{
    '/kcsapi/api_req_map/air_raid',
    ...battleMap,
    ...battlePhases,
    ...battleResults,
    ...battleRetreat,
    '/kcsapi/api_port/port',
    '/kcsapi/api_start2/getData',
  };

  static const Set<String> senkaExperience = <String>{
    '/kcsapi/api_get_member/basic',
    '/kcsapi/api_get_member/record',
    '/kcsapi/api_port/port',
    '/kcsapi/api_req_mission/result',
    '/kcsapi/api_req_practice/battle_result',
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_combined_battle/battleresult',
  };

  static const String senkaRanking = '/kcsapi/api_req_ranking/mxltvkpyuklh';

  static const Set<String> senka = <String>{
    ...senkaExperience,
    ...battleMap,
    ...battleRetreat,
    '/kcsapi/api_get_member/mapinfo',
    '/kcsapi/api_req_quest/clearitemget',
    senkaRanking,
  };

  static const Set<String> logbook = <String>{
    ...battleMap,
    '/kcsapi/api_req_mission/result',
    '/kcsapi/api_req_kousyou/createitem',
    '/kcsapi/api_req_kousyou/createship',
    '/kcsapi/api_req_kousyou/getship',
    '/kcsapi/api_get_member/kdock',
    '/kcsapi/api_req_kousyou/destroyship',
    '/kcsapi/api_req_kaisou/powerup',
  };

  static final Set<String> all = Set<String>.unmodifiable(<String>{
    ...gameState,
    ...battle,
    ...senka,
    ...logbook,
    ...kcwikiOnly,
  });

  /// Endpoints that have no local consumer and are routed only to the
  /// opt-in KCWiki consumer after capture.
  static const Set<String> kcwikiOnly = <String>{
    '/kcsapi/api_req_kousyou/remodel_slotlist',
    '/kcsapi/api_req_kousyou/remodel_slotlist_detail',
    '/kcsapi/api_req_member/set_friendly_request',
  };
}
