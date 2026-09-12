import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../widgets/top_notice.dart';
import 'deck_builder_exporter.dart';
import 'external_fleet_tool_launcher.dart';

typedef FleetExportCopyCallback = Future<void> Function(String text);

class FleetExportPage extends StatefulWidget {
  const FleetExportPage({
    super.key,
    required this.state,
    this.exporter = const DeckBuilderExporter(),
    this.launcher = const ExternalFleetToolLauncher(),
    this.copyText,
  });

  final GameState state;
  final DeckBuilderExporter exporter;
  final ExternalFleetToolLauncher launcher;
  final FleetExportCopyCallback? copyText;

  @override
  State<FleetExportPage> createState() => _FleetExportPageState();
}

class _FleetExportPageState extends State<FleetExportPage> {
  bool _eventLandBasesOnly = true;
  late String _exportText;

  @override
  void initState() {
    super.initState();
    _exportText = _generateText();
  }

  @override
  void didUpdateWidget(covariant FleetExportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.memberId != widget.state.memberId ||
        (oldWidget.state.canExportFleet != widget.state.canExportFleet)) {
      _exportText = _generateText();
    }
  }

  String _generateText() => widget.state.canExportFleet
      ? widget.exporter.exportJson(
          widget.state,
          eventLandBasesOnly: _eventLandBasesOnly,
        )
      : '';

  void _refresh() {
    setState(() => _exportText = _generateText());
  }

  Future<void> _open(ExternalFleetTool tool) async {
    if (!widget.state.canExportFleet) return;
    final latestText = _generateText();
    setState(() => _exportText = latestText);
    var launched = false;
    try {
      launched = await widget.launcher.open(
        tool,
        latestText,
        state: widget.state,
      );
    } catch (_) {
      launched = false;
    }
    if (!mounted || launched) return;
    final l10n = AppLocalizations.of(context)!;
    TopNotice.show(
      context,
      message: l10n.externalFleetToolOpenFailed,
      tone: TopNoticeTone.error,
    );
  }

  Future<void> _copy() async {
    if (!widget.state.canExportFleet) return;
    final latestText = _generateText();
    setState(() => _exportText = latestText);
    final l10n = AppLocalizations.of(context)!;
    try {
      await (widget.copyText?.call(latestText) ??
          Clipboard.setData(ClipboardData(text: latestText)));
      if (!mounted) return;
      TopNotice.show(
        context,
        message: l10n.fleetExportCopied,
        tone: TopNoticeTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      TopNotice.show(
        context,
        message: l10n.fleetExportCopyFailed,
        tone: TopNoticeTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetPanel = _FleetExportPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExternalToolButton(
                buttonKey: const Key('fleet-export-noro6'),
                label: l10n.exportToNoro6,
                enabled: widget.state.canExportFleet,
                onPressed: () => _open(ExternalFleetTool.noro6),
              ),
              const SizedBox(height: 10),
              _ExternalToolButton(
                buttonKey: const Key('fleet-export-noro6-mirror'),
                label: l10n.exportToNoro6Mirror,
                enabled: widget.state.canExportFleet,
                onPressed: () => _open(ExternalFleetTool.noro6Mirror),
              ),
              const SizedBox(height: 10),
              _ExternalToolButton(
                buttonKey: const Key('fleet-export-jervis'),
                label: l10n.exportToJervis,
                enabled: widget.state.canExportFleet,
                onPressed: () => _open(ExternalFleetTool.jervis),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.openInSystemBrowser,
                style: const TextStyle(color: Color(0xff8fa5b2), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  key: const Key('event-land-bases-only'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _eventLandBasesOnly,
                  title: Text(
                    l10n.eventLandBasesOnly,
                    style: const TextStyle(color: Color(0xffd7e2e8)),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _eventLandBasesOnly = value;
                      _exportText = _generateText();
                    });
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.landBaseExportLimitHint,
                style: const TextStyle(
                  color: Color(0xff8fa5b2),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
        final textPanel = _FleetExportPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.fleetExportText,
                    style: const TextStyle(
                      color: Color(0xffe8eef2),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _FormatBadge(label: l10n.deckBuilderV4),
                  OutlinedButton.icon(
                    key: const Key('refresh-fleet-export'),
                    onPressed: widget.state.canExportFleet ? _refresh : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.refreshExportText),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('copy-fleet-export'),
                    onPressed: widget.state.canExportFleet ? _copy : null,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(l10n.copyExportText),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 190),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff081923),
                  border: Border.all(color: const Color(0xff294657)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  widget.state.canExportFleet
                      ? _exportText
                      : widget.state.hasPortData
                      ? l10n.waitingForEquip
                      : l10n.waitingForPortData,
                  key: const Key('fleet-export-text'),
                  style: const TextStyle(
                    color: Color(0xffc4d4dc),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
        final wide = constraints.maxWidth >= 720;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: wide
              ? Row(
                  key: const Key('fleet-export-two-column'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 270, child: targetPanel),
                    const SizedBox(width: 16),
                    Expanded(child: textPanel),
                  ],
                )
              : Column(
                  key: const Key('fleet-export-one-column'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    targetPanel,
                    const SizedBox(height: 16),
                    textPanel,
                  ],
                ),
        );
      },
    );
  }
}

class _ExternalToolButton extends StatelessWidget {
  const _ExternalToolButton({
    required this.buttonKey,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    key: buttonKey,
    onPressed: enabled ? onPressed : null,
    icon: const Icon(Icons.open_in_new_rounded, size: 18),
    label: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(label),
    ),
  );
}

class _FleetExportPanel extends StatelessWidget {
  const _FleetExportPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff102733),
      border: Border.all(color: const Color(0xff294657)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xff173947),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xff98c6d8),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
