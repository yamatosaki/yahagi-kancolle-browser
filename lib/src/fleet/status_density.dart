import 'package:flutter/widgets.dart';

import '../layout/adaptive_layout.dart';

/// 手机紧凑密度：以屏幕短边判断，竖屏/横屏手机都会命中；
/// 平板与展开的折叠屏短边足够大（>=600dp），保持完整布局不变。
bool isPhoneDensity(BuildContext context) {
  return classifyAdaptiveWindow(MediaQuery.sizeOf(context)) ==
      AdaptiveWindowClass.compact;
}

bool isNearSquareLargeDisplay(BuildContext context) {
  return classifyAdaptiveWindow(MediaQuery.sizeOf(context)) ==
      AdaptiveWindowClass.nearSquareLarge;
}

bool usesCompactFleetLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return classifyAdaptiveWindow(size) == AdaptiveWindowClass.compact ||
      usesVerticalWorkspace(size);
}
