import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.child,
    this.titleBadge,
    this.trailing,
    this.padding,
    this.borderColor,
  });

  final String title;
  final Widget icon;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final Widget child;
  final Widget? titleBadge;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding:
            padding ??
            EdgeInsets.fromLTRB(14, collapsed ? 8 : 10, 10, collapsed ? 8 : 10),
        decoration: BoxDecoration(
          color: const Color(0xff142735),
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTheme(
                  data: const IconThemeData(size: 16, color: Color(0xffd4a85f)),
                  child: icon,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xffd4a85f),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (!collapsed && titleBadge != null) ...[
                        const SizedBox(width: 8),
                        titleBadge!,
                      ],
                    ],
                  ),
                ),
                if (!collapsed && trailing != null) ...[
                  trailing!,
                  const SizedBox(width: 3),
                ],
                IconButton(
                  tooltip: collapsed ? '展开$title' : '折叠$title',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                  onPressed: onToggleCollapse,
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: const Color(0xff8fa8b6),
                  ),
                ),
              ],
            ),
            if (!collapsed) ...[const SizedBox(height: 5), child],
          ],
        ),
      ),
    );
  }
}
