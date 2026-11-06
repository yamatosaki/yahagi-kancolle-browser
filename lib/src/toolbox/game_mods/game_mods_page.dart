import '../../theme/app_palette.dart';
import '../../widgets/app_segmented_style.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'game_mods_controller.dart';
import 'game_mods_library.dart';
import 'game_mods_models.dart';
import 'game_mods_strings.dart';

const _background = Color(0xff091923);
const _surface = Color(0xff102732);
const _border = Color(0xff284553);
const _gold = Color(0xffd7b56d);
const _muted = Color(0xff91aab8);
const _ink = Color(0xffecf3f5);
const _removalSurface = Color(0xff351f28);
const _removalBorder = Color(0xffa9515c);
const _removalInk = Color(0xfff0a5ad);

class GameModsPage extends StatefulWidget {
  const GameModsPage({super.key, this.controller, this.visible = true});
  final GameModsController? controller;
  final bool visible;
  @override
  State<GameModsPage> createState() => _GameModsPageState();
}

class _GameModsPageState extends State<GameModsPage> {
  String _filter = 'all';
  DialogRoute<void>? _progressRoute;
  bool _progressScheduled = false;
  GameModsController? _ownedController;
  GameModsController get c =>
      widget.controller ?? (_ownedController ??= GameModsController());
  String? get _libraryErrorCode =>
      c.librarySupported &&
          !c.saveFailed &&
          (c.errorCode?.startsWith('library_') ?? false)
      ? c.errorCode
      : null;
  @override
  void initState() {
    super.initState();
    c.addListener(_queueProgressDialog);
    c.setVisible(widget.visible);
    unawaited(c.initialize());
    _queueProgressDialog();
  }

  @override
  void didUpdateWidget(GameModsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final previous = oldWidget.controller ?? _ownedController;
      previous?.removeListener(_queueProgressDialog);
      previous?.setVisible(false);
      _removeProgressDialog();
      c.addListener(_queueProgressDialog);
      unawaited(c.initialize());
      _queueProgressDialog();
    }
    c.setVisible(widget.visible);
  }

  @override
  void dispose() {
    c.removeListener(_queueProgressDialog);
    c.setVisible(false);
    final route = _progressRoute;
    _progressRoute = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = route.navigator;
        if (navigator != null && navigator.mounted && route.isActive) {
          navigator.removeRoute(route);
        }
      });
    }
    _ownedController?.dispose();
    super.dispose();
  }

  void _queueProgressDialog() {
    if (_progressScheduled || !mounted) return;
    _progressScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressScheduled = false;
      if (!mounted) return;
      if (c.operationProgress == null) {
        _removeProgressDialog();
        return;
      }
      if (_progressRoute != null) return;
      final controller = c;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: appColor(context, Colors.black.withValues(alpha: .72)),
        settings: const RouteSettings(name: 'game-mods-progress'),
        builder: (context) => PopScope(
          canPop: false,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                _GameModsProgressDialog(controller: controller),
          ),
        ),
      );
      _progressRoute = route;
      unawaited(Navigator.of(context, rootNavigator: true).push(route));
    });
  }

  void _removeProgressDialog() {
    final route = _progressRoute;
    _progressRoute = null;
    final navigator = route?.navigator;
    if (route != null &&
        navigator != null &&
        navigator.mounted &&
        route.isActive) {
      // Remove this exact route, even if the review dialog has already opened.
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = GameModsStrings.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme
        .apply(
          bodyColor: appColor(context, _ink),
          displayColor: appColor(context, _ink),
        )
        .copyWith(
          headlineSmall: theme.textTheme.headlineSmall?.copyWith(
            color: appColor(context, _ink),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleLarge: theme.textTheme.titleLarge?.copyWith(
            color: appColor(context, _ink),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          bodyMedium: theme.textTheme.bodyMedium?.copyWith(
            color: appColor(context, _ink),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          bodySmall: theme.textTheme.bodySmall?.copyWith(
            color: appColor(context, _muted),
            fontSize: 11,
            height: 1.35,
          ),
          labelLarge: theme.textTheme.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: 0,
          ),
        );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    return Theme(
      data: theme.copyWith(
        brightness: AppPalette.of(context).brightness,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: appColor(context, _gold),
              brightness: AppPalette.of(context).brightness,
            ).copyWith(
              primary: appColor(context, _gold),
              surface: appColor(context, _surface),
              onSurface: appColor(context, _ink),
            ),
        textTheme: textTheme,
        dividerColor: appColor(context, _border),
        filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
        outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
        textButtonTheme: TextButtonThemeData(style: buttonStyle),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(44, 44)),
            iconSize: WidgetStatePropertyAll(20),
            visualDensity: VisualDensity.standard,
          ),
        ),
        chipTheme: theme.chipTheme.copyWith(
          labelStyle: textTheme.labelLarge?.copyWith(
            color: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppSegmentedStyle.foreground(context, true)
                  : textTheme.labelLarge?.color ?? appColor(context, _ink),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 7),
          side: WidgetStateBorderSide.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? AppSegmentedStyle.selectedBorder(context)
                  : appColor(context, _border),
            ),
          ),
          selectedColor: AppSegmentedStyle.selectedBackground(context),
          backgroundColor: appColor(context, _surface),
          shape: RoundedRectangleBorder(
            borderRadius: AppSegmentedStyle.itemRadius(compact: true),
          ),
        ),
        expansionTileTheme: ExpansionTileThemeData(
          iconColor: appColor(context, _muted),
          collapsedIconColor: appColor(context, _muted),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: appColor(context, _surface),
          titleTextStyle: textTheme.titleLarge,
          contentTextStyle: textTheme.bodyMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => appColor(
              context,
              states.contains(WidgetState.selected) ? _gold : _muted,
            ),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => appColor(
              context,
              states.contains(WidgetState.selected)
                  ? _gold.withValues(alpha: .28)
                  : const Color(0xff263b49),
            ),
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (states) => appColor(
              context,
              states.contains(WidgetState.selected)
                  ? _gold.withValues(alpha: .6)
                  : _border,
            ),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: appTextStyle(context, textTheme.bodyMedium!),
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            if (c.loading) {
              return ColoredBox(
                color: appColor(context, _background),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (c.supported != true) {
              return ColoredBox(
                color: appColor(context, _background),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.extension_off_outlined,
                          color: appColor(context, _muted),
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.title,
                          style: appTextStyle(
                            context,
                            Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.errorCode == null
                              ? s.unsupported
                              : s.reason(c.errorCode),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final packages = c.status.orderedPackages;
            final filtered = packages
                .where(
                  (p) => switch (_filter) {
                    'enabled' =>
                      c.status.draft.enabledPackages.contains(p.id) &&
                          !p.pendingRemoval,
                    'disabled' =>
                      !c.status.draft.enabledPackages.contains(p.id) ||
                          p.pendingRemoval,
                    'issues' => _hasIssues(p),
                    _ => true,
                  },
                )
                .toList();
            return ColoredBox(
              color: appColor(context, _background),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _header(context),
                        const SizedBox(height: 16),
                        if (c.librarySupported) ...[
                          _libraryPanel(context),
                          const SizedBox(height: 12),
                        ],
                        _panel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.master,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          s.preserve,
                                          style: appTextStyle(
                                            context,
                                            TextStyle(
                                              color: appColor(context, _muted),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    label: s.master,
                                    child: Switch(
                                      key: const Key('game-mods-master'),
                                      value: c.status.draft.master,
                                      onChanged: c.canEdit ? c.setMaster : null,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 17, thickness: 1),
                              _portraitSyncControl(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (c.errorCode != null && _libraryErrorCode == null)
                          _notice(
                            context,
                            s.reason(c.errorCode),
                            action: c.canEdit && c.saveFailed
                                ? TextButton(
                                    onPressed: c.retrySave,
                                    child: Text(s.retry),
                                  )
                                : null,
                          ),
                        if (c.lastApplyResult != null && c.errorCode == null)
                          _notice(context, s.applyResult(c.lastApplyResult!)),
                        const SizedBox(height: 4),
                        _filterToolbar(context, packages),
                        const SizedBox(height: 12),
                        Text(
                          s.orderHint,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, _muted),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: appColor(context, _muted),
                                  size: 36,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  packages.isEmpty ? s.empty : s.noMatches,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        for (final p in filtered)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _packageCard(context, p),
                          ),
                      ],
                    ),
                  ),
                  _footer(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _portraitSyncControl(BuildContext context) {
    final s = GameModsStrings.of(context);
    final portraits = c.portraits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.syncPortraits,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.syncPortraitsHint,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: s.syncPortraits,
              hint: s.syncPortraitsHelp,
              child: Switch(
                key: const Key('game-mods-portrait-sync'),
                value: portraits.enabled,
                onChanged: portraits.saving ? null : portraits.setEnabled,
              ),
            ),
          ],
        ),
        if (portraits.errorCode != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              portraits.errorCode == 'portrait_sync_save_failed'
                  ? s.syncPortraitsSaveFailed
                  : s.syncPortraitsLoadFailed,
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, _gold), fontSize: 11),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _libraryPanel(BuildContext context) {
    final s = GameModsStrings.of(context), library = c.status.library;
    final errorCode =
        _libraryErrorCode ??
        library.error ??
        (library.configured && !library.available
            ? 'library_unavailable'
            : null);
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: appColor(context, _gold),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    s.libraryTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (library.configured)
              _badge(s.librarySavedCount(library.packageCount)),
          ],
        ),
        if (library.configured && library.displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Tooltip(
            message: library.displayName,
            child: Text(
              library.displayName,
              key: const Key('game-mods-library-location'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ],
    );
    final actionTextStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        );
    final buttonStyle =
        OutlinedButton.styleFrom(
          foregroundColor: appColor(context, _gold),
          disabledForegroundColor: appColor(
            context,
            _muted.withValues(alpha: .5),
          ),
          backgroundColor: appColor(
            context,
            _background.withValues(alpha: .25),
          ),
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: actionTextStyle,
          shape: const StadiumBorder(),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: appColor(
                context,
                states.contains(WidgetState.disabled)
                    ? _border
                    : _gold.withValues(alpha: .55),
              ),
            ),
          ),
        );
    final actions = Wrap(
      spacing: 6,
      runSpacing: 0,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          key: const Key('game-mods-library-choose'),
          style: buttonStyle,
          onPressed: c.canEdit ? () => _chooseLibrary(context) : null,
          icon: const Icon(Icons.drive_file_move_outline, size: 16),
          label: Text(library.configured ? s.libraryChange : s.libraryChoose),
        ),
        if (library.configured) ...[
          OutlinedButton.icon(
            key: const Key('game-mods-library-open'),
            style: buttonStyle,
            onPressed: c.canEdit && library.available
                ? c.openLibraryDirectory
                : null,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: Text(s.libraryOpen),
          ),
          OutlinedButton.icon(
            key: const Key('game-mods-library-scan'),
            style: buttonStyle,
            onPressed: c.canEdit ? () => _scanLibrary(context) : null,
            icon: const Icon(Icons.sync, size: 16),
            label: Text(s.libraryScan),
          ),
        ],
      ],
    );
    return _panel(
      key: const Key('game-mods-library'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final labels = [
            library.configured ? s.libraryChange : s.libraryChoose,
            if (library.configured) ...[s.libraryOpen, s.libraryScan],
          ];
          var actionsWidth = (labels.length - 1) * 6.0;
          for (final label in labels) {
            final text = TextPainter(
              text: TextSpan(
                text: label,
                style: appTextStyle(context, actionTextStyle),
              ),
              textDirection: Directionality.of(context),
              textScaler: textScaler,
            )..layout();
            actionsWidth += text.width + 24 + 16 + 8;
            text.dispose();
          }
          final inline =
              constraints.maxWidth >= 600 &&
              textScaler.scale(12) <= 15 &&
              constraints.maxWidth >= actionsWidth + 12 + 240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inline)
                Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 12),
                    actions,
                  ],
                )
              else
                identity,
              const SizedBox(height: 3),
              Text(
                errorCode != null
                    ? s.reason(errorCode)
                    : library.configured
                    ? s.libraryHint
                    : s.libraryUnconfigured,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: errorCode != null ? _gold : _muted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (!inline) ...[
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _chooseLibrary(BuildContext context) async {
    final s = GameModsStrings.of(context);
    if (!await _confirm(
          context,
          s.libraryTitle,
          s.libraryChooseHint,
          s.libraryChoose,
        ) ||
        !mounted) {
      return;
    }
    final chosen = await c.chooseLibraryDirectory();
    if (chosen && context.mounted) await _scanLibrary(context);
  }

  Future<void> _scanLibrary(BuildContext context) async {
    if (!c.status.library.available) {
      await _chooseLibrary(context);
      return;
    }
    await c.scanLibrary();
    if (!context.mounted) {
      await c.cancelLibraryScan();
      return;
    }
    final scan = c.libraryScan;
    if (scan == null) return;
    final s = GameModsStrings.of(context);
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.libraryReview),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scan.restoreAvailable) ...[
                  Text(
                    s.libraryRestoreHint,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _gold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (scan.cleanupCount == 0 ||
                    scan.restoreAvailable ||
                    scan.entries.any((entry) => entry.importable)) ...[
                  Text(s.libraryScanHint),
                  const SizedBox(height: 12),
                ],
                if (scan.cleanupCount > 0) ...[
                  Text(
                    s.libraryCleanupHint(scan.cleanupCount),
                    key: const Key('game-mods-library-cleanup-hint'),
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _gold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (scan.entries.isEmpty) Text(s.libraryEmptyScan),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final kind in GameModLibraryEntryKind.values)
                      if (scan.count(kind) > 0)
                        _badge(
                          '${s.libraryEntryKind(kind)} ${scan.count(kind)}',
                          warning:
                              kind == GameModLibraryEntryKind.invalid ||
                              kind == GameModLibraryEntryKind.missing,
                        ),
                  ],
                ),
                for (final entry in scan.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            s.libraryEntryKind(entry.kind),
                            if (entry.resourceCount > 0)
                              s.resources(entry.resourceCount),
                          ].join(' · '),
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, _muted),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (entry.reason != null)
                          Text(
                            s.reason(entry.reason),
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: appColor(context, _gold),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (entry.detail != null && entry.detail!.isNotEmpty)
                          Text(
                            entry.detail!,
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: appColor(context, _muted),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (entry.unsupportedCount > 0)
                          Text(
                            '${s.reason('unsupported_files')} (${entry.unsupportedCount})',
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: appColor(context, _gold),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (scan.entries.any(
                  (e) =>
                      e.kind == GameModLibraryEntryKind.missing ||
                      e.kind == GameModLibraryEntryKind.invalid,
                )) ...[
                  const SizedBox(height: 12),
                  Text(
                    s.libraryMissingHint,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('game-mods-library-scan-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(scan.hasChanges ? s.cancel : s.close),
          ),
          if (scan.hasChanges)
            FilledButton(
              key: const Key('game-mods-library-scan-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.libraryConfirm),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await c.confirmLibraryScan();
    } else {
      await c.cancelLibraryScan();
    }
  }

  Widget _header(BuildContext context) {
    final s = GameModsStrings.of(context);
    final description = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.headerIntro,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.importHint,
          style: appTextStyle(
            context,
            TextStyle(color: appColor(context, _muted), fontSize: 11),
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: s.help,
          onPressed: () => _help(context),
          icon: const Icon(Icons.help_outline, size: 18),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: FilledButton.icon(
            key: const Key('game-mods-import'),
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            onPressed: c.canEdit ? () => _import(context) : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.importArchive),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              description,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: description),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }

  Widget _filterToolbar(BuildContext context, List<GameModPackage> packages) {
    final s = GameModsStrings.of(context);
    final filters = Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final entry in {
          'all': s.all,
          'enabled': s.enabled,
          'disabled': s.disabled,
          'issues': s.issues,
        }.entries)
          FilterChip(
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: const VisualDensity(vertical: -1),
            label: Text(
              '${entry.value} ${packages.where((p) => switch (entry.key) {
                'enabled' => c.status.draft.enabledPackages.contains(p.id) && !p.pendingRemoval,
                'disabled' => !c.status.draft.enabledPackages.contains(p.id) || p.pendingRemoval,
                'issues' => _hasIssues(p),
                _ => true,
              }).length}',
            ),
            selected: _filter == entry.key,
            onSelected: (_) => setState(() => _filter = entry.key),
          ),
      ],
    );
    final reset = FilledButton.icon(
      key: const Key('game-mods-reset'),
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
      onPressed: c.canEdit && packages.isNotEmpty
          ? () => _reset(context)
          : null,
      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
      label: Text(s.reset),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filters,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: reset),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: filters),
            const SizedBox(width: 12),
            reset,
          ],
        );
      },
    );
  }

  Widget _panel({
    Key? key,
    required Widget child,
    bool removing = false,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) => Container(
    key: key,
    padding: padding,
    decoration: BoxDecoration(
      color: appColor(context, removing ? _removalSurface : _surface),
      border: Border.all(
        color: appColor(context, removing ? _removalBorder : _border),
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
  Widget _notice(BuildContext context, String text, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, _gold),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      );
  int _overridden(GameModPackage p, {bool coordinates = false}) {
    if (!c.status.draft.master ||
        !c.status.draft.enabledPackages.contains(p.id)) {
      return 0;
    }
    var count = 0;
    for (final resource in p.resources) {
      if (resource.isCoordinates != coordinates ||
          !c.status.draft.enabledResources.contains(resource.id)) {
        continue;
      }
      count += resource.targets
          .where(
            (target) =>
                c.status.winners[target] != null &&
                c.status.winners[target] != resource.id,
          )
          .length;
    }
    return count;
  }

  bool _hasIssues(GameModPackage p) =>
      p.warnings.isNotEmpty ||
      p.resources.any(
        (r) => !r.supported || c.status.failures.containsKey(r.id),
      ) ||
      _overridden(p) > 0 ||
      _overridden(p, coordinates: true) > 0;

  Widget _packageCard(BuildContext context, GameModPackage p) {
    final s = GameModsStrings.of(context), draft = c.status.draft;
    final enabled = draft.enabledPackages.contains(p.id) && !p.pendingRemoval;
    final selection = s.selected(
      p.resources.where((r) => draft.enabledResources.contains(r.id)).length,
      p.resources.length,
    );
    return _panel(
      key: Key('game-mods-card-${p.id}'),
      removing: p.pendingRemoval,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showDetailsLabel =
              constraints.maxWidth >= 560 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          final details = showDetailsLabel
              ? TextButton.icon(
                  key: Key('game-mods-details-${p.id}'),
                  onPressed: () => _details(context, p.id),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: Text(s.details),
                )
              : IconButton(
                  key: Key('game-mods-details-${p.id}'),
                  tooltip: s.details,
                  onPressed: () => _details(context, p.id),
                  icon: const Icon(Icons.chevron_right),
                );
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selection · ${_size(p.sizeBytes)}',
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, _muted),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _badges(context, p),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  details,
                  Semantics(
                    label: '${enabled ? s.enabled : s.disabled} ${p.name}',
                    child: Switch(
                      key: Key('game-mods-package-${p.id}'),
                      value: enabled,
                      onChanged:
                          c.canEdit &&
                              !p.pendingRemoval &&
                              p.resources.any((r) => r.supported)
                          ? (value) => c.setPackageEnabled(p.id, value)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _badges(
    BuildContext context,
    GameModPackage p, {
    bool includeSaved = false,
  }) {
    final s = GameModsStrings.of(context);
    var hits = 0,
        partial = 0,
        failures = 0,
        coordinateWritten = 0,
        coordinateWaiting = 0,
        coordinateFailures = 0,
        coordinateFields = 0,
        unsupported = 0;
    for (final resource in p.resources) {
      if (!resource.supported) unsupported++;
      if (resource.isCoordinates) {
        coordinateFields += resource.targets.length;
        if (c.status.failures.containsKey(resource.id)) {
          coordinateFailures++;
        } else if (c.status.coordinatesActive(resource)) {
          if (c.status.hits.contains(resource.id)) {
            coordinateWritten++;
          } else {
            coordinateWaiting++;
          }
        }
      } else {
        if (c.status.hits.contains(resource.id)) {
          hits++;
        } else if (c.status.partialHits.contains(resource.id)) {
          partial++;
        }
        if (c.status.failures.containsKey(resource.id)) failures++;
      }
    }
    final coordinateOverrides = _overridden(p, coordinates: true);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (includeSaved || c.saving || c.saveFailed)
          _badge(
            c.saving
                ? s.saving
                : c.saveFailed
                ? s.unsaved
                : s.saved,
            warning: c.saveFailed,
          ),
        if (p.pendingRemoval) _badge(s.removing, removing: true),
        if (c.status.pending && !p.pendingRemoval)
          _badge(s.pending, warning: true),
        if (hits > 0) _badge(s.supplied(hits)),
        if (partial > 0) _badge(s.partialProvided(partial)),
        if (coordinateWritten > 0)
          _badge(s.coordinatesWrittenCount(coordinateWritten)),
        if (coordinateWaiting > 0)
          _badge(s.coordinatesWaitingCount(coordinateWaiting)),
        if (hits == 0 &&
            partial == 0 &&
            coordinateWritten == 0 &&
            coordinateWaiting == 0 &&
            coordinateFailures == 0)
          _badge(s.noHits),
        if (_overridden(p) > 0)
          _badge(s.overwritten(_overridden(p)), warning: true),
        if (failures > 0) _badge('${s.readFailed} ($failures)', warning: true),
        if (coordinateFailures > 0)
          _badge('${s.coordinatesFailed} ($coordinateFailures)', warning: true),
        if (coordinateOverrides > 0)
          _badge(
            s.coordinateOverridden(coordinateOverrides, coordinateFields),
            warning: true,
          ),
        if (unsupported > 0)
          _badge(
            '${s.resources(unsupported)} · ${s.reason('unsupported_type')}',
            warning: true,
          ),
      ],
    );
  }

  Widget _badge(String text, {bool warning = false, bool removing = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: appColor(
            context,
            removing
                ? _removalBorder.withValues(alpha: .2)
                : warning
                ? _gold.withValues(alpha: .1)
                : _background,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: appTextStyle(
            context,
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.25,
              color: removing
                  ? _removalInk
                  : warning
                  ? _gold
                  : _muted,
            ),
          ),
        ),
      );
  Widget _footer(BuildContext context) {
    final s = GameModsStrings.of(context);
    return Container(
      decoration: BoxDecoration(
        color: appColor(context, _surface),
        border: Border(top: BorderSide(color: appColor(context, _border))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final text = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.busy
                        ? s.working
                        : c.status.pending
                        ? s.pending
                        : s.applied,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.saving
                        ? s.saving
                        : c.status.pending
                        ? c.status.packages.any((p) => p.pendingRemoval)
                              ? s.pendingRemovalHint
                              : s.pendingHint
                        : s.telemetry(
                            c.status.providedFileCount,
                            c.status.partialOnlyHits.length,
                            coordinates: c.status.writtenCoordinateCount,
                            coordinatePending: c.status.waitingCoordinateCount,
                          ),
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 12),
                    ),
                  ),
                ],
              );
              final button = FilledButton(
                key: const Key('game-mods-apply'),
                onPressed: c.canEdit && c.status.pending ? c.apply : null,
                child: Text(
                  c.busy
                      ? s.working
                      : c.status.pending
                      ? s.apply
                      : s.applied,
                ),
              );
              final cancel = Tooltip(
                message: s.cancelChangesHint,
                child: OutlinedButton(
                  key: const Key('game-mods-cancel'),
                  onPressed: c.canEdit && (c.status.pending || c.saveFailed)
                      ? c.cancelChanges
                      : null,
                  child: Text(s.cancel),
                ),
              );
              final compact =
                  constraints.maxWidth < 560 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final actions = Row(
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (compact) Expanded(child: cancel) else cancel,
                  const SizedBox(width: 10),
                  if (compact) Expanded(flex: 2, child: button) else button,
                ],
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [text, const SizedBox(height: 8), actions],
                    )
                  : Row(
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _details(
    BuildContext context,
    String id,
  ) => showModalBottomSheet<void>(
    isDismissible: false,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: appColor(context, _surface),
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (sheetContext) => AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = GameModsStrings.of(context);
        final matches = c.status.packages.where((p) => p.id == id);
        if (matches.isEmpty) return const SizedBox.shrink();
        final p = matches.first, order = c.status.draft.order;
        final owners = <String, GameModPackage>{
          for (final package in c.status.packages)
            for (final resource in package.resources) resource.id: package,
        };
        final groups = <String, List<GameModResource>>{};
        final ordinals = <String, int>{};
        var ordinal = 0;
        for (final r in p.resources) {
          ordinals[r.id] = ++ordinal;
          groups
              .putIfAbsent(
                r.isCoordinates
                    ? 'coordinates:${r.id}'
                    : r.groupId?.isNotEmpty == true
                    ? r.groupId!
                    : r.kind,
                () => [],
              )
              .add(r);
        }
        final sources = <String, int>{};
        for (final r in p.resources) {
          for (final target in r.targets) {
            final winner = c.status.winners[target];
            if (winner != null &&
                winner != r.id &&
                c.status.draft.enabledResources.contains(r.id) &&
                c.status.draft.enabledPackages.contains(p.id)) {
              final name = owners[winner]?.name;
              if (name != null) {
                sources.update(name, (n) => n + 1, ifAbsent: () => 1);
              }
            }
          }
        }
        final rows = <Object>[];
        for (final group in groups.entries) {
          if (group.value.first.isCoordinates) {
            for (final resource in group.value) {
              rows.add(
                _DetailResource(resource, ordinals[resource.id]!, false),
              );
            }
            continue;
          }
          var linked = false, supported = false, allSelected = true;
          for (final resource in group.value) {
            linked |=
                resource.kind == 'coordinates' ||
                resource.path.endsWith('.json');
            if (resource.supported) {
              supported = true;
              allSelected &= c.status.draft.enabledResources.contains(
                resource.id,
              );
            }
          }
          rows.add(
            _DetailGroup(group.key, group.value, supported, allSelected),
          );
          for (final resource in group.value) {
            rows.add(
              _DetailResource(
                resource,
                ordinals[resource.id]!,
                linked &&
                    group.value.length > 1 &&
                    resource.groupId?.isNotEmpty == true,
              ),
            );
          }
        }
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: p.name,
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: appTextStyle(
                            context,
                            Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: s.close,
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: rows.length + 2,
                  itemBuilder: (context, index) {
                    if (index == rows.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          s.priority(order.indexOf(id) + 1, order.length),
                          style: appTextStyle(
                            context,
                            TextStyle(color: appColor(context, _muted)),
                          ),
                        ),
                      );
                    }
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _badges(context, p, includeSaved: true),
                          const SizedBox(height: 12),
                          for (final source in sources.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                s.source(source.key, source.value),
                                style: appTextStyle(
                                  context,
                                  TextStyle(color: appColor(context, _gold)),
                                ),
                              ),
                            ),
                          for (final warning in p.warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                s.reason(warning),
                                style: appTextStyle(
                                  context,
                                  TextStyle(color: appColor(context, _gold)),
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                    final row = rows[index - 1];
                    if (row is _DetailResource) {
                      return _resourceRow(
                        context,
                        p,
                        row.resource,
                        ordinal: row.ordinal,
                        linked: row.linked,
                        owners: owners,
                      );
                    }
                    final group = row as _DetailGroup;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.groupLabel(
                                group.id,
                                group.resources.first.kind,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (group.supported)
                            TextButton(
                              onPressed:
                                  c.canEdit &&
                                      !p.pendingRemoval &&
                                      group.supported
                                  ? () {
                                      c.setResourcesEnabled(
                                        group.resources,
                                        !group.allSelected,
                                      );
                                    }
                                  : null,
                              child: Text(
                                group.allSelected ? s.deselectAll : s.selectAll,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        key: Key('game-mods-remove-$id'),
                        onPressed: c.canEdit && !p.pendingRemoval
                            ? () => _remove(sheetContext, p)
                            : null,
                        child: Text(
                          s.remove,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, Color(0xffe89b91)),
                            ),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            c.canEdit &&
                                !p.pendingRemoval &&
                                order.indexOf(id) > 0
                            ? () => c.movePackage(id, -1)
                            : null,
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        label: Text(s.up),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            c.canEdit &&
                                !p.pendingRemoval &&
                                order.indexOf(id) < order.length - 1
                            ? () => c.movePackage(id, 1)
                            : null,
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        label: Text(s.down),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _resourceRow(
    BuildContext context,
    GameModPackage p,
    GameModResource r, {
    required int ordinal,
    required bool linked,
    required Map<String, GameModPackage> owners,
  }) {
    if (r.isCoordinates) return _coordinateRow(context, p, r, owners);
    final s = GameModsStrings.of(context), status = c.status;
    final label = s.resourceLabel(r, ordinal);
    final enabled = r.supported && status.draft.enabledResources.contains(r.id);
    final active = status.activeWinners[r.path];
    final other = owners[active];
    final stateText = status.failures.containsKey(r.id)
        ? s.readFailed
        : active == r.id
        ? status.hits.contains(r.id)
              ? s.supplied(1)
              : status.partialHits.contains(r.id)
              ? s.partialProvided(1)
              : s.noHits
        : other != null
        ? s.providedBy(other.name)
        : s.inactive;
    final winner = status.winners[r.path];
    final next = winner == null
        ? s.original
        : owners[winner]?.name ?? s.original;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: appColor(context, _border))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.supported ? stateText : s.reason(r.reason),
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: r.supported ? _muted : _gold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (status.pending)
                      Text(
                        s.nextBy(next),
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, _muted),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: '${enabled ? s.enabled : s.disabled} $label',
                child: Switch(
                  key: Key('game-mods-resource-${r.id}'),
                  value: enabled,
                  onChanged: c.canEdit && !p.pendingRemoval && r.supported
                      ? (value) => c.setResourceEnabled(r.id, value)
                      : null,
                ),
              ),
            ],
          ),
          if (linked)
            Text(
              s.grouped,
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, _muted), fontSize: 12),
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            dense: true,
            minTileHeight: 44,
            title: Text(
              s.viewPath,
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, _muted), fontSize: 11),
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  r.path,
                  style: TextStyle(
                    color: appColor(context, _muted),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coordinateRow(
    BuildContext context,
    GameModPackage package,
    GameModResource resource,
    Map<String, GameModPackage> owners,
  ) {
    final s = GameModsStrings.of(context), status = c.status;
    final selected =
        resource.supported &&
        status.draft.enabledResources.contains(resource.id);
    final active = resource.targets
        .where((target) => status.activeWinners[target] == resource.id)
        .length;
    final adopted = resource.targets
        .where((target) => status.winners[target] == resource.id)
        .length;
    final otherActive = <String>{
      for (final target in resource.targets)
        if (status.activeWinners[target] != null &&
            status.activeWinners[target] != resource.id &&
            owners[status.activeWinners[target]] != null)
          owners[status.activeWinners[target]]!.name,
    };
    final conflicts = <String, int>{};
    if (selected &&
        status.draft.master &&
        status.draft.enabledPackages.contains(package.id)) {
      for (final target in resource.targets) {
        final winner = status.winners[target];
        final owner = owners[winner];
        if (winner != null && winner != resource.id && owner != null) {
          conflicts.update(owner.name, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    final overridden = conflicts.values.fold(0, (a, b) => a + b);
    final current = status.failures.containsKey(resource.id)
        ? s.coordinatesFailed
        : active > 0
        ? status.hits.contains(resource.id)
              ? s.coordinatesWritten
              : s.coordinatesWaiting
        : otherActive.isNotEmpty
        ? s.providedBy(otherActive.join(' / '))
        : s.coordinatesInactive;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: appColor(context, _border))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.resourceLabel(resource, 1),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Semantics(
                label: '${s.kind('coordinates')} ${resource.label}',
                child: Switch(
                  key: Key('game-mods-resource-${resource.id}'),
                  value: selected,
                  onChanged:
                      c.canEdit && !package.pendingRemoval && resource.supported
                      ? (value) => c.setResourceEnabled(resource.id, value)
                      : null,
                ),
              ),
            ],
          ),
          Text(
            resource.supported
                ? selected
                      ? s.coordinatesOn
                      : s.coordinatesOff
                : s.reason(resource.reason),
            style: appTextStyle(
              context,
              TextStyle(
                color: resource.supported ? _muted : _gold,
                fontSize: 12,
              ),
            ),
          ),
          if (resource.supported) ...[
            const SizedBox(height: 4),
            Text(
              current,
              style: appTextStyle(
                context,
                TextStyle(
                  color: status.failures.containsKey(resource.id)
                      ? _gold
                      : _muted,
                  fontSize: 12,
                ),
              ),
            ),
            if (selected || status.pending)
              Text(
                s.coordinateAdopted(
                  adopted,
                  resource.targets.length,
                  pending: status.pending,
                ),
                style: appTextStyle(
                  context,
                  TextStyle(color: appColor(context, _muted), fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            s.coordinatesCompatible,
            style: appTextStyle(
              context,
              TextStyle(color: appColor(context, _muted), fontSize: 12),
            ),
          ),
          if (overridden > 0) ...[
            const SizedBox(height: 8),
            Text(
              s.coordinateOverridden(overridden, resource.targets.length),
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, _gold), fontSize: 12),
              ),
            ),
            for (final entry in conflicts.entries)
              Text(
                s.source(entry.key, entry.value),
                style: appTextStyle(
                  context,
                  TextStyle(color: appColor(context, _gold), fontSize: 12),
                ),
              ),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            dense: true,
            minTileHeight: 44,
            title: Text(
              s.coordinateSources,
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, _muted), fontSize: 11),
              ),
            ),
            children: [
              for (final path in resource.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      path,
                      style: TextStyle(
                        color: appColor(context, _muted),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _help(BuildContext context) => showDialog<void>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      final s = GameModsStrings.of(context);
      return AlertDialog(
        title: Text(s.help),
        content: SingleChildScrollView(
          child: Text(
            '${s.helpBody}\n\n${s.syncPortraitsHelp}${c.librarySupported ? '\n\n${s.libraryChooseHint}\n\n${s.libraryHint}' : ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
          ),
        ],
      );
    },
  );
  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async =>
      await showDialog<bool>(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          final s = GameModsStrings.of(context);
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(body)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          );
        },
      ) ??
      false;
  Future<void> _remove(BuildContext context, GameModPackage p) async {
    final s = GameModsStrings.of(context);
    if (await _confirm(context, s.remove, s.removeBody(p.name), s.remove) &&
        mounted) {
      if (context.mounted) Navigator.pop(context);
      await c.removePackage(p.id);
      if (mounted &&
          c.status.packages.any(
            (entry) => entry.id == p.id && entry.pendingRemoval,
          )) {
        // Keep the pending red card visible when removal started in a filter.
        setState(() => _filter = 'all');
      }
    }
  }

  Future<void> _reset(BuildContext context) async {
    final s = GameModsStrings.of(context);
    if (await _confirm(
          context,
          s.reset,
          s.resetBody(c.status.packages.length),
          s.reset,
        ) &&
        mounted) {
      await c.resetAll();
      if (mounted && c.status.packages.any((p) => p.pendingRemoval)) {
        setState(() => _filter = 'all');
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    if (c.librarySupported && !c.status.library.available) {
      final s = GameModsStrings.of(context);
      if (!await _confirm(
            context,
            s.libraryTitle,
            s.libraryChooseHint,
            s.libraryChoose,
          ) ||
          !mounted) {
        return;
      }
    }
    await c.pickArchive();
    if (!context.mounted) {
      await c.cancelImport();
      return;
    }
    if (c.preflight == null) return;
    final s = GameModsStrings.of(context), candidate = c.preflight!;
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.preflight),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                candidate.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(s.preflightCounts(candidate)),
              const SizedBox(height: 12),
              Text(s.importDefault),
              for (final warning in candidate.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.reason(warning)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: candidate.supportedCount > 0
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(
              candidate.unsupportedCount > 0
                  ? s.importSupported
                  : s.confirmImport,
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await c.confirmImport();
    } else {
      await c.cancelImport();
    }
  }

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';
}

class _GameModsProgressDialog extends StatelessWidget {
  const _GameModsProgressDialog({required this.controller});
  final GameModsController controller;

  @override
  Widget build(BuildContext context) {
    final s = GameModsStrings.of(context);
    final progress = controller.operationProgress;
    final seconds = controller.operationElapsedMillis ~/ 1000;
    final minutes = seconds ~/ 60;
    final elapsed = minutes >= 60
        ? '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}'
        : '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
    final bytes = progress?.completedBytes;
    String size(int value) => value >= 1024 * 1024
        ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB'
        : value >= 1024
        ? '${(value / 1024).toStringAsFixed(1)} KB'
        : '$value B';
    Widget current(String label, String value, String key) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: appTextStyle(
              context,
              TextStyle(color: appColor(context, _muted), fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: Key(key),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: AppPalette.of(context).brightness,
        colorScheme: AppPalette.of(context).isDark
            ? const ColorScheme.dark(
                primary: _gold,
                surface: _surface,
                onSurface: _ink,
              )
            : Theme.of(context).colorScheme.copyWith(
                primary: appColor(context, _gold),
                surface: appColor(context, _surface),
                onSurface: appColor(context, _ink),
              ),
      ),
      child: Dialog(
        key: const Key('game-mods-operation-progress'),
        backgroundColor: appColor(context, _surface),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: appColor(context, _border)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DefaultTextStyle(
              style: appTextStyle(
                context,
                TextStyle(
                  color: appColor(context, _ink),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: appColor(context, _gold),
                    size: 30,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.progressTitle(progress?.operation ?? 'import'),
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, _gold),
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      s.progressPhase(progress?.phase ?? 'complete'),
                      key: const Key('game-mods-progress-phase'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress?.fraction,
                    color: appColor(context, _gold),
                    backgroundColor: appColor(context, _border),
                    minHeight: 5,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.progressPackages(
                      progress?.completedPackages ?? 0,
                      progress?.totalPackages,
                    ),
                    key: const Key('game-mods-progress-packages'),
                  ),
                  if (progress?.currentPackage?.isNotEmpty ?? false)
                    current(
                      s.progressCurrentPackage,
                      progress!.currentPackage!,
                      'game-mods-progress-package',
                    ),
                  if (progress?.currentFile?.isNotEmpty ?? false)
                    current(
                      s.progressCurrentFile,
                      progress!.currentFile!,
                      'game-mods-progress-file',
                    ),
                  if (progress?.completedFiles != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      s.progressFiles(
                        progress!.completedFiles!,
                        progress.totalFiles,
                      ),
                    ),
                  ],
                  if (bytes != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      s.progressBytes(
                        progress!.totalBytes == null
                            ? size(bytes)
                            : '${size(bytes)} / ${size(progress.totalBytes!)}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    s.progressElapsed(elapsed),
                    key: const Key('game-mods-progress-elapsed'),
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      height: 1,
                      color: appColor(context, _border),
                    ),
                  ),
                  Text(
                    s.progressWorking,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailGroup {
  const _DetailGroup(this.id, this.resources, this.supported, this.allSelected);
  final String id;
  final List<GameModResource> resources;
  final bool supported, allSelected;
}

class _DetailResource {
  const _DetailResource(this.resource, this.ordinal, this.linked);
  final GameModResource resource;
  final int ordinal;
  final bool linked;
}
