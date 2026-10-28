import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../logbook/logbook_database.dart';
import '../settings/settings_ui_helpers.dart';
import '../widgets/adaptive_input_dialog.dart';
import '../widgets/top_notice.dart';
import 'senka_controller.dart';

/// Existing base-senka actions, located with the month information they edit.
class BaseSenkaSection extends StatelessWidget with SettingsUIHelpers {
  const BaseSenkaSection({
    super.key,
    required this.controller,
    this.accountSession,
  });
  final SenkaController controller;
  final AccountSession? accountSession;
  AccountSession get _accountSession =>
      accountSession ?? LogbookDatabase.accountSession;
  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return buildCard(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => buildActionTile(
          key: const Key('settings-base-senka-summary'),
          title: l10n.baseSenkaManualInputLabel,
          subtitle: l10n.baseSenkaCurrentValue(
            controller.monthBaseSenka.toStringAsFixed(2),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: const Key('settings-set-base-senka'),
                tooltip: l10n.baseSenkaManualTitle,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _setBaseSenka(context, l10n, controller),
              ),
              IconButton(
                key: const Key('settings-reset-base-senka'),
                tooltip: l10n.baseSenkaResetTitle,
                icon: const Icon(Icons.restart_alt),
                onPressed: () => _resetBaseSenka(context, l10n, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resetBaseSenka(
    BuildContext context,
    AppLocalizations l10n,
    SenkaController controller,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final confirmed = await _showAccountDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('settings-reset-base-senka-dialog'),
        title: Text(l10n.baseSenkaResetConfirmTitle),
        content: Text(l10n.baseSenkaResetConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('settings-reset-base-senka-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !session.isCurrent(scope)) return;
    final saved = await controller.resetBaseSenka();
    if (!context.mounted || !session.isCurrent(scope)) return;
    TopNotice.show(
      context,
      message: saved ? l10n.baseSenkaResetSuccess : l10n.baseSenkaSaveFailed,
      tone: saved ? TopNoticeTone.success : TopNoticeTone.error,
    );
  }

  Future<void> _setBaseSenka(
    BuildContext context,
    AppLocalizations l10n,
    SenkaController controller,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final value = await _showAccountDialog<double>(
      context: context,
      builder: (_) => _BaseSenkaInputDialog(
        l10n: l10n,
        initialValue: controller.monthBaseSenka,
      ),
    );
    if (value == null || !session.isCurrent(scope)) return;
    final saved = await controller.setBaseSenka(value);
    if (!context.mounted || !session.isCurrent(scope)) return;
    TopNotice.show(
      context,
      message: saved
          ? l10n.baseSenkaSetSuccess(value.toStringAsFixed(2))
          : l10n.baseSenkaSaveFailed,
      tone: saved ? TopNoticeTone.success : TopNoticeTone.error,
    );
  }

  Future<T?> _showAccountDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    final session = _accountSession;
    final scope = session.current;
    final route = DialogRoute<T>(context: context, builder: builder);
    void dismissStaleDialog() {
      if (!session.isCurrent(scope) && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }

    session.addListener(dismissStaleDialog);
    try {
      return await Navigator.of(context, rootNavigator: true).push<T>(route);
    } finally {
      session.removeListener(dismissStaleDialog);
    }
  }
}

class _BaseSenkaInputDialog extends StatefulWidget {
  const _BaseSenkaInputDialog({required this.l10n, required this.initialValue});

  final AppLocalizations l10n;
  final double initialValue;

  @override
  State<_BaseSenkaInputDialog> createState() => _BaseSenkaInputDialogState();
}

class _BaseSenkaInputDialogState extends State<_BaseSenkaInputDialog> {
  late final TextEditingController _input;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveInputDialog(
    dialogKey: const Key('settings-base-senka-dialog'),
    title: Text(widget.l10n.baseSenkaManualDialogTitle),
    content: TextField(
      key: const Key('settings-base-senka-input'),
      controller: _input,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        TextInputFormatter.withFunction((oldValue, newValue) {
          return RegExp(r'^\d*(?:\.\d{0,2})?$').hasMatch(newValue.text)
              ? newValue
              : oldValue;
        }),
      ],
      decoration: InputDecoration(
        labelText: widget.l10n.baseSenkaManualInputLabel,
        error: _invalid
            ? Text(
                widget.l10n.baseSenkaManualInvalid,
                key: const Key('settings-base-senka-error'),
              )
            : null,
      ),
      onChanged: (_) {
        if (_invalid) setState(() => _invalid = false);
      },
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.l10n.cancel),
      ),
      TextButton(
        key: const Key('settings-base-senka-save'),
        onPressed: _submit,
        child: Text(widget.l10n.confirm),
      ),
    ],
  );

  void _submit() {
    final raw = _input.text.trim();
    final parsed = double.tryParse(raw);
    final valid = RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(raw);
    if (!valid || parsed == null || !parsed.isFinite) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, parsed);
  }
}
