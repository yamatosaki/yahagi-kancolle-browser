import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../widgets/lazy_indexed_stack.dart';
import 'composition_image_page.dart';
import 'exp_calc/exp_calc_page.dart';
import 'fleet_export_page.dart';
import 'sortie_map_query/sortie_map_query_page.dart';
import 'sortie_map_query/sortie_map_catalog_controller.dart';
import 'sortie_map_query/enemy_catalog_controller.dart';
import 'toolbox_mode.dart';
import 'game_mods/game_mods_controller.dart';
import 'game_mods/game_mods_page.dart';

export 'toolbox_mode.dart' show ToolboxMode;
export 'composition_image_page.dart' show CompositionImageDraftController;

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({
    super.key,
    required this.state,
    this.mode = ToolboxMode.export,
    this.workspaceVisible = true,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.compositionInitiallyShowSaved = true,
    this.compositionDraftController,
    this.gameModsController,
  });

  final GameState state;
  final ToolboxMode mode;
  final bool workspaceVisible;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final bool compositionInitiallyShowSaved;
  final CompositionImageDraftController? compositionDraftController;
  final GameModsController? gameModsController;

  @override
  Widget build(BuildContext context) => LazyIndexedStack(
    index: mode.index,
    children: [
      FleetExportPage(state: state),
      CompositionImagePage(
        state: state,
        sortieMapCatalogController: sortieMapCatalogController,
        visible: workspaceVisible && mode == ToolboxMode.composition,
        initiallyShowSaved: compositionInitiallyShowSaved,
        draftController: compositionDraftController,
      ),
      ExpCalcPage(state: state, catalogController: sortieMapCatalogController),
      SortieMapQueryPage(
        state: state,
        visible: workspaceVisible && mode == ToolboxMode.mapQuery,
        catalogController: sortieMapCatalogController,
        enemyCatalogController: enemyCatalogController,
      ),
      GameModsPage(
        controller: gameModsController,
        visible: workspaceVisible && mode == ToolboxMode.mods,
      ),
      ColoredBox(
        key: const Key('toolbox-other-page'),
        color: appColor(context, const Color(0xff091923)),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.otherToolsComingSoon,
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffecf3f5)),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
