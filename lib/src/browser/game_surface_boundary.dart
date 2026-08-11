import 'package:flutter/widgets.dart';

/// Keeps the platform game surface in its own compositing/repaint boundary.
class GameSurfaceBoundary extends StatelessWidget {
  const GameSurfaceBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('game-surface-repaint-boundary'),
      child: child,
    );
  }
}
