import 'package:flutter/widgets.dart';

import 'native_game_resource_checklist.dart';

class GameDialogPresentationScope extends InheritedWidget {
  const GameDialogPresentationScope({
    super.key,
    required this.nativeActivity,
    this.presentationEnabled = true,
    this.nativeChecklistPort,
    this.customFontPath,
    required super.child,
  });

  final bool nativeActivity;
  final bool presentationEnabled;
  final NativeGameResourceChecklistPort? nativeChecklistPort;
  final String? customFontPath;

  static GameDialogPresentationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameDialogPresentationScope>();

  @override
  bool updateShouldNotify(GameDialogPresentationScope oldWidget) =>
      nativeActivity != oldWidget.nativeActivity ||
      presentationEnabled != oldWidget.presentationEnabled ||
      nativeChecklistPort != oldWidget.nativeChecklistPort ||
      customFontPath != oldWidget.customFontPath;
}
