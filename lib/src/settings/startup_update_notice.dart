import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'release_check_service.dart';

class StartupUpdateNotice extends StatefulWidget {
  const StartupUpdateNotice({
    super.key,
    required this.checker,
    required this.currentVersion,
    required this.child,
    this.enabled = true,
  });

  final ReleaseChecker checker;
  final String currentVersion;
  final Widget child;
  final bool enabled;

  @override
  State<StartupUpdateNotice> createState() => _StartupUpdateNoticeState();
}

class _StartupUpdateNoticeState extends State<StartupUpdateNotice> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnce());
    }
  }

  Future<void> _checkOnce() async {
    if (_started) {
      return;
    }
    _started = true;
    final result = await widget.checker.check(
      currentVersion: widget.currentVersion,
    );
    if (!mounted || result is! UpdateAvailable) {
      return;
    }
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.startupUpdateTitle),
        content: SingleChildScrollView(
          child: Text(l10n.startupUpdateMessage(result.latestVersion)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
