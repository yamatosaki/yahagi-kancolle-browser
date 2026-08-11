import 'package:flutter/material.dart';

import 'game_toolbar_controller.dart';

class GameBrowserOverlay extends StatefulWidget {
  const GameBrowserOverlay({
    super.key,
    required this.controller,
    required this.gameSurface,
    required this.toolbar,
  });

  final GameToolbarController controller;
  final Widget gameSurface;
  final Widget toolbar;

  @override
  State<GameBrowserOverlay> createState() => _GameBrowserOverlayState();
}

class _GameBrowserOverlayState extends State<GameBrowserOverlay> {
  static const _minimumVerticalDrag = 36.0;
  static const _maximumHorizontalDrag = 48.0;

  double _verticalDrag = 0;
  double _horizontalDrag = 0;
  bool _gestureRejected = false;
  bool _gestureCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('game-browser-overlay'),
      children: [
        ColoredBox(color: const Color(0xff102431), child: widget.gameSurface),
        AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final isVisible = widget.controller.isVisible;
            return Stack(
              children: [
                if (!isVisible)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 160,
                    height: 40,
                    child: GestureDetector(
                      key: const Key('game-toolbar-swipe-zone'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => _resetGesture(),
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: (_) => _resetGesture(),
                      onPanCancel: _resetGesture,
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    key: const Key('game-toolbar-panel'),
                    ignoring: !isVisible,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          top: 8,
                          right: 12,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          reverseDuration: const Duration(milliseconds: 240),
                          transitionBuilder: (child, animation) {
                            final position =
                                Tween<Offset>(
                                  begin: const Offset(0, -1.4),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: position,
                                child: child,
                              ),
                            );
                          },
                          child: isVisible
                              ? ConstrainedBox(
                                  key: const Key('game-toolbar-visible'),
                                  constraints: const BoxConstraints(
                                    maxWidth: 700,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Listener(
                                      onPointerDown: (_) =>
                                          widget.controller.beginInteraction(),
                                      onPointerUp: (_) =>
                                          widget.controller.endInteraction(),
                                      onPointerCancel: (_) =>
                                          widget.controller.endInteraction(),
                                      child: widget.toolbar,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: Key('game-toolbar-hidden'),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_gestureRejected || _gestureCompleted) {
      return;
    }
    _verticalDrag += details.delta.dy;
    _horizontalDrag += details.delta.dx.abs();
    if (_horizontalDrag > _maximumHorizontalDrag) {
      _gestureRejected = true;
      return;
    }
    if (_verticalDrag >= _minimumVerticalDrag) {
      _gestureCompleted = true;
      widget.controller.reveal();
    }
  }

  void _resetGesture() {
    _verticalDrag = 0;
    _horizontalDrag = 0;
    _gestureRejected = false;
    _gestureCompleted = false;
  }
}
