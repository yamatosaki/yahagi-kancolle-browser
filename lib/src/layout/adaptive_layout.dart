import 'package:flutter/widgets.dart';

const double compactWindowShortestSide = 600;
const double nearSquareMaxAspectRatio = 1.35;

enum AdaptiveWindowClass { compact, nearSquareLarge, wideLarge }

AdaptiveWindowClass classifyAdaptiveWindow(Size size) {
  if (size.shortestSide < compactWindowShortestSide) {
    return AdaptiveWindowClass.compact;
  }
  if (size.longestSide / size.shortestSide < nearSquareMaxAspectRatio) {
    return AdaptiveWindowClass.nearSquareLarge;
  }
  return AdaptiveWindowClass.wideLarge;
}

bool usesVerticalWorkspace(Size size) {
  if (classifyAdaptiveWindow(size) == AdaptiveWindowClass.nearSquareLarge) {
    return true;
  }
  return size.width <= size.height * nearSquareMaxAspectRatio;
}
