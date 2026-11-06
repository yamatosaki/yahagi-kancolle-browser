import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_path_catalog.dart';

void main() {
  test('capture allowlist is the union of every event consumer', () {
    expect(GameCapturePathCatalog.all, <String>{
      ...GameCapturePathCatalog.gameState,
      ...GameCapturePathCatalog.battle,
      ...GameCapturePathCatalog.senka,
      ...GameCapturePathCatalog.logbook,
      ...GameCapturePathCatalog.kcwikiOnly,
    });
    expect(
      GameCapturePathCatalog.all.every((path) => path.startsWith('/kcsapi/')),
      isTrue,
    );
  });

  test(
    'capture allowlist includes critical state, battle, senka and log paths',
    () {
      expect(
        GameCapturePathCatalog.all,
        containsAll(<String>{
          '/kcsapi/api_start2/getData',
          '/kcsapi/api_port/port',
          '/kcsapi/api_req_combined_battle/ec_night_to_day',
          '/kcsapi/api_req_ranking/mxltvkpyuklh',
          '/kcsapi/api_req_kousyou/destroyship',
          '/kcsapi/api_req_air_corps/set_plane',
          '/kcsapi/api_req_air_corps/change_deployment_base',
          '/kcsapi/api_req_air_corps/set_action',
          '/kcsapi/api_req_air_corps/supply',
          '/kcsapi/api_req_air_corps/change_name',
          '/kcsapi/api_req_air_corps/cond_recovery',
          '/kcsapi/api_port/airCorpsCondRecoveryWithTimer',
          '/kcsapi/api_get_member/mission',
        }),
      );
    },
  );

  test('KCWiki-only paths are always in the stable allowlist', () {
    expect(GameCapturePathCatalog.kcwikiOnly, <String>{
      '/kcsapi/api_req_kousyou/remodel_slotlist',
      '/kcsapi/api_req_kousyou/remodel_slotlist_detail',
      '/kcsapi/api_req_member/set_friendly_request',
    });
    expect(
      GameCapturePathCatalog.all,
      containsAll(GameCapturePathCatalog.kcwikiOnly),
    );
  });
}
