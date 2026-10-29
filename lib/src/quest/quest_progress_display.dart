import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import '../theme/app_palette.dart';

/// Poi-style progress bands, independent of whether rewards are claimable.
Color questProgressColor(
  BuildContext context, {
  int? current,
  int? total,
  int progressFlag = 0,
  bool completed = false,
}) {
  final palette = AppPalette.of(context);
  final neutral = palette.muted;
  // The usual dark gold maps to the navigation accent in light themes.
  // Keep this progress band gold so it stays distinct from the blue band.
  final halfway = palette.isDark ? const Color(0xffd4a85f) : palette.gold;
  final nearCompletion = palette.isDark
      ? const Color(0xff8ec6e8)
      : palette.info;
  final complete = palette.isDark ? const Color(0xff67d6a3) : palette.success;

  if (completed) return complete;
  if (current != null && total != null && total > 0) {
    if (current >= total) return complete;
    if (current * 5 >= total * 4) return nearCompletion;
    if (current * 2 >= total) return halfway;
    return neutral;
  }
  return switch (progressFlag) {
    1 => halfway,
    2 => nearCompletion,
    _ => neutral,
  };
}

extension GameQuestProgressColors on GameQuest {
  Color progressColor(BuildContext context) => questProgressColor(
    context,
    current: progressCurrent,
    total: progressRequired,
    progressFlag: progressFlag,
    completed: isServerCompleted,
  );
}
