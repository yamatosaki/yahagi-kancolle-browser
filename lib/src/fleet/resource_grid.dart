import 'package:flutter/material.dart';

import '../game_state/game_state.dart';

class ResourceGrid extends StatelessWidget {
  const ResourceGrid({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 450 ? 2 : 4;

        const spacing = 4.0;
        final available =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final itemWidth = available.clamp(0.0, double.infinity);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final type in GameResourceType.values)
              SizedBox(
                width: itemWidth,
                child: Tooltip(
                  message: type.label,
                  child: _ResourceItem(type: type, value: state.resource(type)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResourceItem extends StatelessWidget {
  const _ResourceItem({required this.type, required this.value});

  final GameResourceType type;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('resource-item-${type.apiId}'),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xff142735),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff213b4b)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Image.asset(
            _assetPath(type),
            key: Key('resource-icon-${type.apiId}'),
            width: 17,
            height: 17,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value?.toString() ?? '—',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Color(0xffdce6eb),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _assetPath(GameResourceType type) =>
      'assets/images/material/${type.apiId.toString().padLeft(2, '0')}.png';
}

class CompactResourceBar extends StatelessWidget {
  const CompactResourceBar({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: GameResourceType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final type = GameResourceType.values[index];
          return Tooltip(
            message: type.label,
            child: SizedBox(
              width:
                  82, // Fixed width to prevent unbounded layout in horizontal ListView
              child: _ResourceItem(type: type, value: state.resource(type)),
            ),
          );
        },
      ),
    );
  }
}
