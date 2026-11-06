import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import 'data_update_metadata.dart';

import '../../l10n/app_localizations.dart';
import '../quest/quest_catalog_controller.dart';
import '../quest/quest_catalog_update_service.dart';

final class QuestCatalogUpdateSection extends StatelessWidget {
  const QuestCatalogUpdateSection({super.key, required this.controller});

  final QuestCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.questCatalogDataTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    version: controller.version.shortLabel,
                    lastCheckedAt: controller.lastCheckedAt,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              key: const Key('quest-catalog-check-button'),
              tooltip: l10n.questCatalogCheckUpdates,
              onPressed: controller.isChecking ? null : () => _check(context),
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

  Future<void> _check(BuildContext context) async {
    final oldVersion = controller.version.shortLabel;
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final current = controller.version.shortLabel;
    final message = switch (result) {
      QuestCatalogUpToDate() =>
        '${l10n.questCatalogUpToDate}\n${l10n.questCatalogDataVersion(current)}',
      QuestCatalogUpdated() => l10n.questCatalogUpdated(oldVersion, current),
      QuestCatalogUpdateFailed(kind: QuestCatalogUpdateFailure.network) =>
        '${l10n.questCatalogNetworkError}\n${l10n.questCatalogDataVersion(current)}',
      QuestCatalogUpdateFailed(kind: QuestCatalogUpdateFailure.validation) =>
        '${l10n.questCatalogValidationError}\n${l10n.questCatalogDataVersion(current)}',
      QuestCatalogUpdateFailed(kind: QuestCatalogUpdateFailure.storage) =>
        '${l10n.questCatalogStorageError}\n${l10n.questCatalogDataVersion(current)}',
    };
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.questCatalogDataTitle),
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
