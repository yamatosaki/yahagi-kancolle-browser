import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_surface_dialog.dart';
import '../browser/game_dialog_presentation_scope.dart';
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
  static const _nativeDialogs = MethodChannel(
    'app.yahagi.kancollebrowser/native_warning',
  );
  bool _started = false;
  (bool native, bool enabled)? _presentation;
  int _presentationRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GameDialogPresentationScope.maybeOf(context);
    final next = (
      scope?.nativeActivity ?? false,
      scope?.presentationEnabled != false,
    );
    if (_presentation != next) {
      _presentation = next;
      _presentationRevision++;
    }
  }

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
    final revision = _presentationRevision;
    final result = await widget.checker.check(
      currentVersion: widget.currentVersion,
    );
    if (!mounted ||
        revision != _presentationRevision ||
        _presentation?.$2 != true ||
        result is! UpdateAvailable) {
      return;
    }
    if (_presentation?.$1 == true) {
      // A quick release check can beat native WebView creation/visibility.
      // Never fall back to a Flutter modal that would hide it as it starts.
      bool available;
      try {
        available =
            await _nativeDialogs
                .invokeMethod<bool>('waitUntilAvailable')
                .timeout(const Duration(seconds: 6), onTimeout: () => false) ??
            false;
      } on PlatformException {
        return;
      } on MissingPluginException {
        return;
      }
      if (!mounted || revision != _presentationRevision || !available) return;
    }
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    await showGameSurfaceDialog<bool>(
      context: context,
      title: l10n.startupUpdateTitle,
      message: l10n.startupUpdateMessage(result.latestVersion),
      allowFlutterFallback: false,
      actions: [
        GameSurfaceDialogAction(
          id: 'confirm',
          label: l10n.confirm,
          value: true,
        ),
      ],
      builder: (dialogContext, close) => AlertDialog(
        title: Text(l10n.startupUpdateTitle),
        content: SingleChildScrollView(
          child: Text(l10n.startupUpdateMessage(result.latestVersion)),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => close(true), child: Text(l10n.confirm)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
