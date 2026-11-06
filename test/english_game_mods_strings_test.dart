import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/game_mods/game_mods_strings.dart';

void main() {
  test(
    'English resource counts use singular and plural and preserve package names',
    () {
      const strings = GameModsStrings(Locale('en'));
      expect(strings.supplied(1), '1 complete replacement resource provided');
      expect(strings.supplied(2), '2 complete replacement resources provided');
      expect(strings.resources(1), '1 resource');
      expect(strings.resources(2), '2 resources');
      expect(strings.source('原始包名.zip', 1), '原始包名.zip overrides 1 resource');
      expect(strings.source('原始包名.zip', 2), '原始包名.zip overrides 2 resources');
      const zhStrings = GameModsStrings(Locale('zh'));
      GameModResource res(String path) => GameModResource(
        id: '1',
        path: path,
        kind: 'image',
        label: path,
        supported: true,
      );
      expect(
        zhStrings.resourceLabel(res('kcs2/img/common/bg_map/bg_h.png'), 1),
        '日战背景',
      );
      expect(
        zhStrings.resourceLabel(res('kcs2/img/common/bg_map/bg_y.png'), 2),
        '夜战背景',
      );
      expect(
        zhStrings.resourceLabel(res('kcs2/img/common/common_shutter.png'), 3),
        '过场闸门界面',
      );
      expect(
        zhStrings.resourceLabel(res('kcs2/img/common/bg/011.png'), 4),
        '编成背景',
      );
      expect(
        zhStrings.resourceLabel(
          res('kcs2/resources/furniture/outside/050_01.png'),
          5,
        ),
        '窗外背景家具 · 050_01',
      );
      expect(
        zhStrings.reason('hack_overrides_original'),
        '压缩包同时包含 .hack 与同名原版文件，已优先采用 .hack 魔改文件',
      );
    },
  );
}
