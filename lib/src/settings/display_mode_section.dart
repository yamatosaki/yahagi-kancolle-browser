import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'display_mode_controller.dart';
import 'display_mode_store.dart';

class DisplayModeSection extends StatelessWidget {
  const DisplayModeSection({super.key, required this.controller});

  final DisplayModeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.displayMode,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            DropdownButton<DisplayMode>(
              value: controller.displayMode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: DisplayMode.auto,
                  child: Text(l10n.displayAuto),
                ),
                DropdownMenuItem(
                  value: DisplayMode.landscape,
                  child: Text(l10n.displayLandscape),
                ),
                DropdownMenuItem(
                  value: DisplayMode.portrait,
                  child: Text(l10n.displayPortrait),
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
