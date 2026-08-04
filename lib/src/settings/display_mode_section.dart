import 'package:flutter/material.dart';

import 'display_mode_controller.dart';
import 'display_mode_store.dart';

class DisplayModeSection extends StatelessWidget {
  const DisplayModeSection({super.key, required this.controller});

  final DisplayModeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('显示模式'),
            DropdownButton<DisplayMode>(
              value: controller.displayMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: DisplayMode.auto, child: Text('自动')),
                DropdownMenuItem(
                  value: DisplayMode.landscape,
                  child: Text('横屏'),
                ),
                DropdownMenuItem(
                  value: DisplayMode.portrait,
                  child: Text('竖屏'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.setDisplayMode(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
