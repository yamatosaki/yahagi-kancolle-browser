import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import 'data_update_metadata.dart';

import '../toolbox/sortie_map_query/enemy_catalog_controller.dart';
import '../toolbox/sortie_map_query/enemy_catalog_update_service.dart';

final class EnemyCatalogUpdateSection extends StatelessWidget {
  const EnemyCatalogUpdateSection({super.key, required this.controller});

  final EnemyCatalogController controller;

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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.enemyDataTitle,
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
            IconButton(
              key: const Key('enemy-catalog-check-button'),
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
      EnemyCatalogUpToDate() => l10n.dataCatalogUpToDate(after),
      EnemyCatalogUpdated() => l10n.dataCatalogUpdated(before, after),
      EnemyCatalogUpdateFailed(kind: EnemyCatalogUpdateFailure.incompatible) =>
        l10n.dataCatalogIncompatible,
      EnemyCatalogUpdateFailed(kind: EnemyCatalogUpdateFailure.storage) =>
        l10n.dataCatalogStorageFailed,
      EnemyCatalogUpdateFailed(kind: EnemyCatalogUpdateFailure.validation) =>
        l10n.dataCatalogValidationFailed,
      EnemyCatalogUpdateFailed() => l10n.dataCatalogNetworkFailed,
    };
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.enemyDataTitle),
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
}
