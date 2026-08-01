import 'dart:convert';

import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';

CapturedApiEvent kcsapiEvent(
  String path,
  Object? apiData, {
  int apiResult = 1,
  int sequence = 1,
  Map<String, Object?> requestParams = const <String, Object?>{},
  DateTime? capturedAt,
}) {
  return CapturedApiEvent(
    path: path,
    responseBody: jsonEncode(<String, Object?>{
      'api_result': apiResult,
      'api_data': apiData,
    }),
    source: CaptureSource.xhr,
    sourceOrigin: 'https://w01y.kancolle-server.com',
    capturedAt: capturedAt ?? DateTime.utc(2026, 7, 30, 9, 30),
    requestParams: requestParams,
    sequence: sequence,
  );
}

final CapturedApiEvent start2Event = kcsapiEvent(
  '/kcsapi/api_start2/getData',
  <String, Object?>{
    'api_mst_stype': <Object?>[
      <String, Object?>{'api_id': 2, 'api_name': '軽巡洋艦'},
      <String, Object?>{'api_id': 3, 'api_name': '駆逐艦'},
    ],
    'api_mst_ship': <Object?>[
      <String, Object?>{
        'api_id': 101,
        'api_name': '夕張',
        'api_stype': 2,
        'api_ctype': 34,
        'api_soku': 10,
        'api_leng': 2,
        'api_fuel_max': 25,
        'api_bull_max': 40,
        'api_buildtime': 60,
      },
      <String, Object?>{
        'api_id': 102,
        'api_name': '吹雪',
        'api_stype': 3,
        'api_ctype': 12,
        'api_soku': 10,
        'api_leng': 1,
        'api_fuel_max': 15,
        'api_bull_max': 20,
        'api_buildtime': 20,
      },
    ],
    'api_mst_mission': <Object?>[
      <String, Object?>{'api_id': 5, 'api_name': '海上護衛任務', 'api_time': 90},
      <String, Object?>{'api_id': 21, 'api_name': '北方鼠輸送作戦', 'api_time': 140},
    ],
    'api_mst_slotitem': <Object?>[
      <String, Object?>{
        'api_id': 201,
        'api_name': '12.7cm 连装炮',
        'api_houg': 3,
        'api_tyku': 2,
        'api_houm': 1,
        'api_leng': 1,
        'api_type': <int>[1, 1, 1, 1, 0],
      },
      <String, Object?>{
        'api_id': 202,
        'api_name': '零式水上侦察机',
        'api_tyku': 1,
        'api_saku': 5,
        'api_houm': 2,
        'api_type': <int>[5, 7, 10, 10, 0],
      },
      <String, Object?>{
        'api_id': 203,
        'api_name': '三式水中探信仪',
        'api_tais': 10,
        'api_houm': 2,
        'api_type': <int>[7, 10, 14, 18, 0],
      },
    ],
    'api_mst_shipgraph': <Object?>[
      <String, Object?>{
        'api_id': 101,
        'api_filename': 'ship_101',
        'api_version': <String>['7', '1', '1'],
      },
    ],
  },
);

final CapturedApiEvent portEvent = kcsapiEvent(
  '/kcsapi/api_port/port',
  <String, Object?>{
    'api_basic': <String, Object?>{'api_level': 120},
    'api_material': <Object?>[
      for (var id = 1; id <= 8; id++)
        <String, Object?>{
          'api_id': id,
          'api_value': <int>[
            123260,
            138649,
            220250,
            74349,
            799,
            708,
            2249,
            24,
          ][id - 1],
        },
    ],
    'api_ship': <Object?>[
      <String, Object?>{
        'api_id': 9001,
        'api_ship_id': 101,
        'api_lv': 50,
        'api_nowhp': 28,
        'api_maxhp': 30,
        'api_cond': 49,
        'api_fuel': 25,
        'api_bull': 35,
        'api_exp': <int>[45000, 1200, 0],
        'api_karyoku': <int>[55, 65],
        'api_raisou': <int>[42, 50],
        'api_taiku': <int>[38, 50],
        'api_taisen': <int>[100, 100],
        'api_sakuteki': <int>[22, 38],
        'api_slot': <int>[7001, 7002, 7004],
        'api_onslot': <int>[0, 2, 0],
        'api_slot_ex': -1,
        'api_ndock_time': 0,
      },
      <String, Object?>{
        'api_id': 9002,
        'api_ship_id': 102,
        'api_lv': 44,
        'api_nowhp': 8,
        'api_maxhp': 15,
        'api_cond': 32,
        'api_fuel': 8,
        'api_bull': 10,
        'api_exp': <int>[30000, 800, 0],
        'api_karyoku': <int>[29, 39],
        'api_raisou': <int>[59, 79],
        'api_taiku': <int>[29, 39],
        'api_taisen': <int>[49, 59],
        'api_sakuteki': <int>[18, 28],
        'api_slot': <int>[7003, -1],
        'api_onslot': <int>[0, 0],
        'api_slot_ex': -1,
        'api_ndock_time': 5400000,
      },
    ],
    'api_deck_port': <Object?>[
      <String, Object?>{
        'api_id': 1,
        'api_name': '第一舰队',
        'api_ship': <int>[9001, 9002, -1, -1, -1, -1],
        'api_mission': <int>[0, 0, 0, 0],
      },
      <String, Object?>{
        'api_id': 2,
        'api_name': '第二舰队',
        'api_ship': <int>[9002, -1, -1, -1, -1, -1],
        'api_mission': <int>[1, 5, 1785391200000, 0],
      },
      <String, Object?>{
        'api_id': 3,
        'api_name': '第三舰队',
        'api_ship': <int>[-1, -1, -1, -1, -1, -1],
        'api_mission': <int>[0, 0, 0, 0],
      },
      <String, Object?>{
        'api_id': 4,
        'api_name': '第四舰队',
        'api_ship': <int>[-1, -1, -1, -1, -1, -1],
        'api_mission': <int>[0, 0, 0, 0],
      },
    ],
    'api_ndock': <Object?>[
      <String, Object?>{
        'api_id': 1,
        'api_state': 1,
        'api_ship_id': 9002,
        'api_complete_time': 1785411000000,
        'api_item1': 24,
        'api_item2': 46,
      },
      <String, Object?>{
        'api_id': 2,
        'api_state': 0,
        'api_ship_id': 0,
        'api_complete_time': 0,
        'api_item1': 0,
        'api_item2': 0,
      },
      <String, Object?>{
        'api_id': 3,
        'api_state': 1,
        'api_ship_id': 9001,
        'api_complete_time': 1785412800000,
        'api_item1': 15,
        'api_item2': 28,
      },
      <String, Object?>{
        'api_id': 4,
        'api_state': -1,
        'api_ship_id': 0,
        'api_complete_time': 0,
        'api_item1': 0,
        'api_item2': 0,
      },
    ],
    'api_kdock': <Object?>[
      <String, Object?>{
        'api_id': 1,
        'api_state': 2,
        'api_created_ship_id': 101,
        'api_complete_time': 1785412800000,
        'api_item1': 30,
        'api_item2': 30,
        'api_item3': 30,
        'api_item4': 30,
        'api_item5': 1,
      },
      <String, Object?>{
        'api_id': 2,
        'api_state': 0,
        'api_created_ship_id': 0,
        'api_complete_time': 0,
        'api_item1': 0,
        'api_item2': 0,
        'api_item3': 0,
        'api_item4': 0,
        'api_item5': 0,
      },
      <String, Object?>{
        'api_id': 3,
        'api_state': 2,
        'api_created_ship_id': 102,
        'api_complete_time': 1785430800000,
        'api_item1': 6000,
        'api_item2': 7000,
        'api_item3': 7000,
        'api_item4': 2000,
        'api_item5': 20,
      },
      <String, Object?>{
        'api_id': 4,
        'api_state': -1,
        'api_created_ship_id': 0,
        'api_complete_time': 0,
        'api_item1': 0,
        'api_item2': 0,
        'api_item3': 0,
        'api_item4': 0,
        'api_item5': 0,
      },
    ],
  },
);

final CapturedApiEvent slotItemEvent = kcsapiEvent(
  '/kcsapi/api_get_member/slot_item',
  <Object?>[
    <String, Object?>{
      'api_id': 7001,
      'api_slotitem_id': 201,
      'api_level': 4,
      'api_alv': 0,
    },
    <String, Object?>{
      'api_id': 7002,
      'api_slotitem_id': 202,
      'api_level': 0,
      'api_alv': 6,
    },
    <String, Object?>{
      'api_id': 7003,
      'api_slotitem_id': 201,
      'api_level': 0,
      'api_alv': 0,
    },
    <String, Object?>{
      'api_id': 7004,
      'api_slotitem_id': 203,
      'api_level': 1,
      'api_alv': 0,
    },
  ],
);

final CapturedApiEvent mapStartEvent = kcsapiEvent(
  '/kcsapi/api_req_map/start',
  <String, Object?>{
    'api_maparea_id': 1,
    'api_mapinfo_no': 1,
    'api_no': 1,
    'api_bosscell_no': 5,
    'api_event_id': 4,
    'api_event_kind': 1,
  },
  sequence: 20,
  requestParams: <String, Object?>{'api_deck_id': '1'},
);

final CapturedApiEvent dayBattleEvent = kcsapiEvent(
  '/kcsapi/api_req_sortie/battle',
  <String, Object?>{
    'api_deck_id': 1,
    'api_formation': <int>[1, 1, 1],
    'api_f_nowhps': <int>[30, 15],
    'api_f_maxhps': <int>[30, 15],
    'api_e_nowhps': <int>[20, 10],
    'api_e_maxhps': <int>[20, 10],
    'api_ship_ke': <int>[501, 502],
    'api_ship_lv': <int>[1, 1],
    'api_hougeki1': <String, Object?>{
      'api_at_eflag': <int>[0, 1],
      'api_at_list': <int>[0, 0],
      'api_df_list': <Object?>[
        <int>[0],
        <int>[0],
      ],
      'api_damage': <Object?>[
        <num>[20.9],
        <num>[10.4],
      ],
    },
    'api_raigeki': <String, Object?>{
      'api_fdam': <num>[2.8, 0],
      'api_edam': <num>[0, 5.9],
    },
  },
  sequence: 21,
);

final CapturedApiEvent battleResultEvent = kcsapiEvent(
  '/kcsapi/api_req_sortie/battleresult',
  <String, Object?>{
    'api_win_rank': 'S',
    'api_mvp': 1,
    'api_quest_name': 'Test Sea',
    'api_enemy_info': <String, Object?>{'api_deck_name': 'Test Enemy Fleet'},
    'api_get_ship': <String, Object?>{'api_ship_id': 102},
    'api_get_useitem': <String, Object?>{'api_useitem_id': 44},
  },
  sequence: 22,
);

final CapturedApiEvent nightBattleEvent = kcsapiEvent(
  '/kcsapi/api_req_battle_midnight/battle',
  <String, Object?>{
    'api_hougeki': <String, Object?>{
      'api_at_eflag': <int>[1],
      'api_at_list': <int>[0],
      'api_df_list': <Object?>[
        <int>[0],
      ],
      'api_damage': <Object?>[
        <num>[5.8],
      ],
    },
  },
  sequence: 23,
);
