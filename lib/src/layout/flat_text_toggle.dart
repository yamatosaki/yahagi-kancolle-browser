import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'flat_style.dart';

class FlatTextToggleOption {
  const FlatTextToggleOption({
    required this.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.backgroundColor,
  });

  final Key key;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? backgroundColor;
}

/// 极简档（扁平面板）下的模式切换：文字与选中底线，无底色。
/// 放不下时换行；放在标题行的 FittedBox 里则始终一行、整体缩小。
class FlatTextToggle extends StatelessWidget {
  const FlatTextToggle({super.key, required this.options});

  final List<FlatTextToggleOption> options;

  @override
  Widget build(BuildContext context) {
    // 自带透明 Material：否则按下高亮画在整屏 Material 上，被信息栏底色盖住。
    return Material(
      type: MaterialType.transparency,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final option in options)
            InkWell(
              key: option.key,
              onTap: option.onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: option.selected
                          ? appColor(context, flatAccentColor)
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: Text(
                    option.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appColor(
                        context,
                        option.selected ? flatAccentColor : flatMutedColor,
                      ),
                      fontSize: flatSmallFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
