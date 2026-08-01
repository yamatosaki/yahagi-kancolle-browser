import 'package:flutter/material.dart';

import 'capture_mode.dart';
import 'capture_mode_controller.dart';

class CaptureModeSelector extends StatelessWidget {
  const CaptureModeSelector({super.key, required this.controller});

  final CaptureModeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mode = controller.mode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<CaptureMode>(
              key: const Key('capture-mode-selector'),
              showSelectedIcon: false,
              segments: CaptureMode.values
                  .map(
                    (value) => ButtonSegment<CaptureMode>(
                      value: value,
                      label: Text(value.title, textAlign: TextAlign.center),
                    ),
                  )
                  .toList(growable: false),
              selected: {mode},
              onSelectionChanged: (selection) async {
                final nextMode = selection.single;
                final changed = await controller.setMode(nextMode);
                if (!context.mounted || !changed) {
                  return;
                }
                final message = switch (nextMode) {
                  CaptureMode.game => '游戏模式将在重新载入页面后启用只读捕获。',
                  CaptureMode.browserOnly => '纯浏览模式将在重新载入页面后停止数据捕获。',
                };
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
              },
            ),
            const SizedBox(height: 8),
            Text(
              mode.description,
              style: const TextStyle(
                color: Color(0xff8197a5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (controller.errorMessage case final error?) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: const TextStyle(color: Color(0xffffaaa4), fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
}
