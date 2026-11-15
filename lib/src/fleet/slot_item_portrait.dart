import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'equipment_type_icon.dart';
import 'ship_portrait.dart';
import 'ship_portrait_cache.dart';

abstract final class SlotItemPortraitUriBuilder {
  static Uri? build({
    required MasterSlotItem item,
    required String serverOrigin,
  }) {
    final origin = Uri.tryParse(serverOrigin);
    if (origin == null ||
        (origin.scheme != 'http' && origin.scheme != 'https') ||
        origin.host.isEmpty) {
      return null;
    }
    final server = Uri(
      scheme: origin.scheme,
      host: origin.host,
      port: origin.hasPort ? origin.port : null,
    );
    final paddedId = item.id.toString().padLeft(4, '0');
    final cipher = ShipPortraitUriBuilder.createCipher(item.id, 'slot_item_up');
    final version = item.resourceVersion.trim();
    return server.replace(
      path: '/kcs2/resources/slot/item_up/${paddedId}_$cipher.png',
      queryParameters: version.isNotEmpty && version != '1'
          ? <String, String>{'version': version}
          : null,
    );
  }
}

class SlotItemPortrait extends StatelessWidget {
  const SlotItemPortrait({
    super.key,
    required this.item,
    required this.serverOrigin,
    this.width = 108,
    this.height = 52,
    this.fit = BoxFit.cover,
    this.cache,
  });

  final MasterSlotItem? item;
  final String serverOrigin;
  final double width;
  final double height;
  final BoxFit fit;
  final ShipPortraitCache? cache;

  @override
  Widget build(BuildContext context) {
    final uri = item == null
        ? null
        : SlotItemPortraitUriBuilder.build(
            item: item!,
            serverOrigin: serverOrigin,
          );
    final iconId = item != null && item!.type.length > 3 ? item!.type[3] : -1;
    final fallback = ColoredBox(
      color: appColor(context, Color(0xff162a35)),
      child: Center(
        child: EquipmentTypeIconImage(
          iconId: iconId,
          width: height * 0.62,
          height: height * 0.62,
        ),
      ),
    );
    Widget portrait = fallback;
    if (uri != null) {
      final portraitCache = cache ?? ShipPortraitCache.shared;
      portrait = portraitCache.routeChangesFor(uri) == null
          ? Image.network(
              uri.toString(),
              width: width,
              height: height,
              fit: fit,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : CachedGamePortraitImage(
              uri: uri,
              cacheKey: 'slot_${item!.id}_item_up',
              cache: portraitCache,
              height: height,
              fit: fit,
              placeholder: fallback,
            );
    }
    return SizedBox(width: width, height: height, child: portrait);
  }
}
