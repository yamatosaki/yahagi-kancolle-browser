import 'package:flutter/widgets.dart';

/// Initializes a tab on first use and retains its state on later switches.
/// Child positions must be stable, as with [IndexedStack].
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.sizing = StackFit.loose,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;
  final StackFit sizing;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Map<int, Key?> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.removeWhere(
      (index, key) =>
          index >= widget.children.length || widget.children[index].key != key,
    );
    _visited[widget.index] = widget.children[widget.index].key;
    return IndexedStack(
      index: widget.index,
      sizing: widget.sizing,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          TickerMode(
            enabled: index == widget.index,
            child: ExcludeFocus(
              excluding: index != widget.index,
              child: _visited.containsKey(index)
                  ? widget.children[index]
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
