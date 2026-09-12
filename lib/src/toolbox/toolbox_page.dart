import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import 'fleet_export_page.dart';
import 'composition_image_page.dart';

enum ToolboxMode { export, composition, other }

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({
    super.key,
    required this.state,
    this.mode = ToolboxMode.export,
  });

  final GameState state;
  final ToolboxMode mode;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: mode.index,
    children: [
      FleetExportPage(state: state),
      CompositionImagePage(state: state, visible: mode == ToolboxMode.composition),
      Center(
        child: Text(
          AppLocalizations.of(context)!.otherToolsComingSoon,
          style: const TextStyle(color: Color(0xff8fa5b2), fontSize: 14),
        ),
      ),
    ],
  );
}
