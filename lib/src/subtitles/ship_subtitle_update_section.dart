import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../settings/data_update_metadata.dart';
import 'ship_subtitle_catalog_controller.dart';
import 'ship_subtitle_data_strings.dart';
import 'ship_subtitle_update_service.dart';

final class ShipSubtitleUpdateSection extends StatelessWidget {
  const ShipSubtitleUpdateSection({super.key, required this.controller});
  final ShipSubtitleCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final strings = ShipSubtitleDataStrings(l10n.localeName);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    key: const Key('ship-subtitle-kcwiki-metadata'),
                    version: controller.kcwikiVersion,
                    lastCheckedAt: controller.kcwikiLastCheckedAt,
                  ),
                  DataUpdateMetadata(
                    key: const Key('ship-subtitle-kc3-metadata'),
                    version: controller.kc3Version,
                    lastCheckedAt: controller.kc3LastCheckedAt,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('ship-subtitle-check-button'),
              tooltip: l10n.checkForUpdates,
              onPressed: controller.isChecking
                  ? null
                  : () => _check(context, l10n, strings),
              icon: controller.isChecking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.sync,
                      color: appColor(context, Color(0xffd4a85f)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _check(
    BuildContext context,
    AppLocalizations l10n,
    ShipSubtitleDataStrings strings,
  ) async {
    final before = _versions();
    final language = controller.language;
    final result = await controller.checkForUpdates();
    if (!context.mounted ||
        controller.language != language ||
        !controller.isLanguageReady) {
      return;
    }
    final after = _versions();
    final message = switch (result) {
      ShipSubtitleUpToDate() => l10n.dataCatalogUpToDate(after),
      ShipSubtitleUpdated() => l10n.dataCatalogUpdated(before, after),
      ShipSubtitleUpdateFailed(
        error: ShipSubtitleResourceUpdateError(hasSuccessfulGroup: true),
      ) =>
        strings.partialFailure,
      ShipSubtitleUpdateFailed(error: ShipSubtitleResourceUpdateError()) =>
        strings.updateFailed,
      ShipSubtitleUpdateFailed(kind: ShipSubtitleUpdateFailure.storage) =>
        l10n.dataCatalogStorageFailed,
      ShipSubtitleUpdateFailed(kind: ShipSubtitleUpdateFailure.validation) =>
        l10n.dataCatalogValidationFailed,
      ShipSubtitleUpdateFailed() => l10n.dataCatalogNetworkFailed,
    };
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  String _versions() => [
    controller.kcwikiVersion,
    controller.kc3Version,
  ].where((version) => version.isNotEmpty).join(' / ');
}
