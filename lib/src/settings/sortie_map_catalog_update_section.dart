import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import 'data_update_metadata.dart';

import '../toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import '../toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';

final class SortieMapCatalogUpdateSection extends StatelessWidget {
  const SortieMapCatalogUpdateSection({super.key, required this.controller});

  final SortieMapCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.sortieMapDataTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    version: controller.data.dataVersion,
                    lastCheckedAt: controller.lastCheckedAt,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              key: const Key('sortie-map-catalog-check-button'),
              tooltip: l10n.checkForUpdates,
              onPressed: controller.isChecking
                  ? null
                  : () => _check(context, l10n),
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

  Future<void> _check(BuildContext context, AppLocalizations l10n) async {
    final before = controller.data.dataVersion;
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final after = controller.data.dataVersion;
    final message = switch (result) {
      SortieMapCatalogUpToDate() => l10n.dataCatalogUpToDate(after),
      SortieMapCatalogUpdated() => l10n.dataCatalogUpdated(before, after),
      SortieMapCatalogUpdateFailed(
        kind: SortieMapCatalogUpdateFailure.incompatible,
      ) =>
        l10n.dataCatalogIncompatible,
      SortieMapCatalogUpdateFailed(
        kind: SortieMapCatalogUpdateFailure.validation,
      ) =>
        l10n.dataCatalogValidationFailed,
      SortieMapCatalogUpdateFailed(
        kind: SortieMapCatalogUpdateFailure.storage,
      ) =>
        l10n.dataCatalogStorageFailed,
      SortieMapCatalogUpdateFailed() => l10n.dataCatalogNetworkFailed,
    };
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sortieMapDataTitle),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}
