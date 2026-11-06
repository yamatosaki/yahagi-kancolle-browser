import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'flat_style.dart';
import 'flat_text_toggle.dart';

/// 极简档（扁平面板）下的舰队切换：等宽平分整行，选中项金色字加底部下划线。
/// 配色与 [FlatTextToggle] 一致，两者常上下相邻（如维修简报的模式与舰队）。
class FlatUnderlineTabs extends StatelessWidget {
  const FlatUnderlineTabs({super.key, required this.options});

  static const height = 22.0;

  final List<FlatTextToggleOption> options;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    // 自带透明 Material：否则按下高亮画在整屏 Material 上，被信息栏底色盖住。
    child: Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: InkWell(
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
                  child: Center(
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
                        fontSize: flatRowFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
