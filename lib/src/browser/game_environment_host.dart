import 'package:flutter/material.dart';

import '../settings/game_rendering_mode.dart';
import '../settings/game_rendering_mode_controller.dart';

typedef GameEnvironmentBuilder =
    Widget Function(BuildContext context, GameRenderingMode mode, Key key);

class GameEnvironmentHost extends StatefulWidget {
  const GameEnvironmentHost({
    super.key,
    required this.controller,
    required this.gameBuilder,
    this.beforeRestart,
  });

  final GameRenderingModeController controller;
  final GameEnvironmentBuilder gameBuilder;
  final Future<void> Function()? beforeRestart;

  @override
  State<GameEnvironmentHost> createState() => _GameEnvironmentHostState();
}

class _GameEnvironmentHostState extends State<GameEnvironmentHost>
    implements GameEnvironmentRestartPort {
  late GameRenderingMode _mode;
  var _generation = 0;
  var _showGame = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.controller.mode;
    widget.controller.attachRestartPort(this);
  }

  @override
  void didUpdateWidget(covariant GameEnvironmentHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detachRestartPort(this);
      _mode = widget.controller.mode;
      widget.controller.attachRestartPort(this);
    }
  }

  @override
  Future<void> restart(GameRenderingMode mode) async {
    await widget.beforeRestart?.call();
    if (!mounted) throw StateError('Game environment host is not mounted');

    setState(() => _showGame = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) throw StateError('Game environment host was disposed');

    setState(() {
      _mode = mode;
      _generation += 1;
      _showGame = true;
    });
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showGame) {
      return const ColoredBox(
        key: Key('game-environment-restarting'),
        color: Color(0xff102431),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.gameBuilder(
      context,
      _mode,
      ValueKey<String>('game-webview-${_mode.storageName}-$_generation'),
    );
  }

  @override
  void dispose() {
    widget.controller.detachRestartPort(this);
    super.dispose();
  }
}
