import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../diagnostics/diagnostic_controller.dart';
import '../widgets/top_notice.dart';
import 'settings_ui_helpers.dart';

class DiagnosticUserSection extends StatelessWidget {
  const DiagnosticUserSection({super.key, required this.controller});

  final DiagnosticController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  controller.enabled ? Icons.shield_outlined : Icons.shield,
                  color: appColor(context, const Color(0xffd4a85f)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.enabled
                        ? l10n.diagnosticStatusEnabled
                        : l10n.diagnosticStatusDisabled,
                    style: appTextStyle(context, SettingsTileTypography.title),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.diagnosticPrivacyDesc,
              style: appTextStyle(
                context,
                SettingsTileTypography.description.copyWith(
                  color: const Color(0xff9bb0bd),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.diagnosticStorageUsage(
                _formatBytes(controller.storageBytes),
              ),
              style: appTextStyle(context, SettingsTileTypography.description),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('saveDiagnosticFileButton'),
              onPressed: controller.exporting
                  ? null
                  : () => _confirmSave(context, l10n),
              icon: controller.exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_outlined),
              label: Text(l10n.saveDiagnosticFile),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('shareDiagnosticFileButton'),
              onPressed: controller.exporting
                  ? null
                  : () => _confirmShare(context, l10n),
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(l10n.shareDiagnosticFile),
            ),
            TextButton.icon(
              key: const Key('clearDiagnosticDataButton'),
              onPressed: controller.exporting
                  ? null
                  : () => _confirmClear(context, l10n),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.clearDiagnosticData),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSave(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diagnosticSaveConfirmTitle),
        content: Text(l10n.diagnosticSaveConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('confirmSaveDiagnosticFileButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.diagnosticSaveAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final fileName = await controller.save();
      if (fileName == null || !context.mounted) return;
      TopNotice.show(
        context,
        message: l10n.diagnosticSaveSucceeded(fileName),
        tone: TopNoticeTone.success,
      );
    } catch (_) {
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.diagnosticSaveFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Future<void> _confirmShare(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diagnosticShareConfirmTitle),
        content: Text(l10n.diagnosticShareConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('confirmShareDiagnosticFileButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.diagnosticShareAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.share();
    } catch (_) {
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.diagnosticShareFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diagnosticClearConfirmTitle),
        content: Text(l10n.diagnosticClearConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.clearDiagnosticData),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.clear();
    } catch (_) {
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.diagnosticClearFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
