import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../fleet/equipment_type_icon.dart';
import '../game_state/game_state.dart';
import '../widgets/top_notice.dart';
import 'development_equipment_picker.dart';
import 'development_output_table.dart';
import 'development_pool_matcher.dart';
import 'development_recipe_table.dart';
import 'development_repository.dart';
import 'development_resources.dart';
import 'development_secretary_picker.dart';
import 'development_workbench_state_store.dart';
import 'equipment_development_controller.dart';

class EquipmentDevelopmentPage extends StatefulWidget {
  const EquipmentDevelopmentPage({
    super.key,
    required this.state,
    this.repository,
    this.stateStore,
    this.controller,
    this.mode,
    this.onModeChanged,
    this.accountSession,
  });

  final GameState state;
  final DevelopmentRepository? repository;
  final DevelopmentWorkbenchStateStore? stateStore;
  final EquipmentDevelopmentController? controller;
  final DevelopmentWorkbenchMode? mode;
  final ValueChanged<DevelopmentWorkbenchMode>? onModeChanged;
  final AccountSession? accountSession;

  @override
  State<EquipmentDevelopmentPage> createState() =>
      _EquipmentDevelopmentPageState();
}

class _EquipmentDevelopmentPageState extends State<EquipmentDevelopmentPage> {
  late final EquipmentDevelopmentController controller;
  late final bool _ownedController;

  @override
  void initState() {
    super.initState();
    _ownedController = widget.controller == null;
    controller =
        widget.controller ??
        EquipmentDevelopmentController(
          accountSession: widget.accountSession,
          repository: widget.repository ?? DevelopmentRepository(),
          stateStore:
              widget.stateStore ??
              SharedPreferencesDevelopmentWorkbenchStateStore(
                accountSession: widget.accountSession,
              ),
        );
    if (widget.mode != null) {
      controller.setMode(widget.mode!);
    }
    controller.addListener(_refresh);
    if (_ownedController) {
      controller.initialize(widget.state);
    }
  }

  @override
  void didUpdateWidget(covariant EquipmentDevelopmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      controller.updateGameState(widget.state);
    }
    if (widget.mode != null && widget.mode != controller.mode) {
      controller.setMode(widget.mode!);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    if (_ownedController) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (widget.mode != null && controller.mode != widget.mode) {
      controller.setMode(widget.mode!);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.isLoading && controller.dataset == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.dataset == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 8),
            Text(l10n.developmentDataError),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.developmentRetry),
            ),
          ],
        ),
      );
    }
    final locale = Localizations.localeOf(context);
    final activeMode = widget.mode ?? controller.mode;
    return ColoredBox(
      color: const Color(0xff081521),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        child: Container(
          key: const Key('development-command-card'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xff142735),
            border: Border.all(color: const Color(0xff294052)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: activeMode == DevelopmentWorkbenchMode.calculator
              ? _CalculatorBody(controller: controller, locale: locale)
              : _FormulaBody(controller: controller, locale: locale),
        ),
      ),
    );
  }
}

class _CalculatorBody extends StatelessWidget {
  const _CalculatorBody({required this.controller, required this.locale});

  final EquipmentDevelopmentController controller;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pools = controller.dataset?.selectablePools.toList() ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 310,
              child: DevelopmentSecretaryPicker(
                pools: pools,
                selectedPoolKey: controller.selectedPoolKey,
                locale: locale,
                label: l10n.developmentSelectPool,
                dialogTitle: l10n.developmentSelectSecretary,
                otherLabel: l10n.developmentOtherSecretaryGroup,
                onSelected: controller.selectPool,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.flag_outlined, size: 17),
              label: Text(
                '${l10n.developmentCurrentFlagship}: ${controller.currentFlagshipName ?? l10n.noValue}',
              ),
              onPressed: () {
                if (!controller.useCurrentFlagship()) {
                  TopNotice.show(
                    context,
                    message: l10n.developmentFlagshipUnsupported,
                    tone: TopNoticeTone.error,
                  );
                }
              },
              side: BorderSide(
                color: controller.followsCurrentFlagship
                    ? const Color(0xffd5a44b)
                    : const Color(0xff315064),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ResourceInput(
              index: 0,
              asset: 'assets/images/material/01.png',
              label: l10n.fuel,
              value: controller.resources.fuel,
              onCommit: (value) => _commitResource(controller, 0, value),
            ),
            _ResourceInput(
              index: 1,
              asset: 'assets/images/material/02.png',
              label: l10n.ammo,
              value: controller.resources.ammo,
              onCommit: (value) => _commitResource(controller, 1, value),
            ),
            _ResourceInput(
              index: 2,
              asset: 'assets/images/material/03.png',
              label: l10n.steel,
              value: controller.resources.steel,
              onCommit: (value) => _commitResource(controller, 2, value),
            ),
            _ResourceInput(
              index: 3,
              asset: 'assets/images/material/04.png',
              label: l10n.bauxite,
              value: controller.resources.bauxite,
              onCommit: (value) => _commitResource(controller, 3, value),
            ),
            Chip(
              avatar: const Icon(Icons.hub_outlined, size: 17),
              label: Text(
                _poolTypeLabel(
                  l10n,
                  selectDevelopmentPoolType(controller.resources),
                ),
              ),
              backgroundColor: const Color(0xff3a301e),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DevelopmentOutputTable(
          controller: controller,
          title: l10n.developmentOutputProbability,
          equipmentLabel: l10n.developmentEquipment,
          finalProbabilityLabel: l10n.developmentFinalProbability,
          typeLabel: l10n.developmentEquipmentType,
          targetLabel: l10n.developmentTargetEquipment,
        ),
      ],
    );
  }
}

class _FormulaBody extends StatelessWidget {
  const _FormulaBody({required this.controller, required this.locale});

  final EquipmentDevelopmentController controller;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const Key('development-formula-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('development-open-target-picker'),
              onPressed: () =>
                  showDevelopmentEquipmentPicker(context, controller),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                controller.targets.isEmpty
                    ? l10n.developmentChooseTarget
                    : l10n.developmentSelectedCount(controller.targets.length),
              ),
            ),
            for (final id in controller.targets)
              InputChip(
                avatar: EquipmentTypeIconImage(
                  key: Key('development-target-chip-icon-$id'),
                  iconId: controller.dataset!.equipment[id]!.iconId,
                  width: 23,
                  height: 23,
                ),
                label: Text(controller.dataset!.equipment[id]!.label(locale)),
                onDeleted: () => controller.toggleTarget(id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        DevelopmentRecipeTable(controller: controller, locale: locale),
      ],
    );
  }
}

class _ResourceInput extends StatefulWidget {
  const _ResourceInput({
    required this.index,
    required this.asset,
    required this.label,
    required this.value,
    required this.onCommit,
  });

  final int index;
  final String asset;
  final String label;
  final int value;
  final ValueChanged<int> onCommit;

  @override
  State<_ResourceInput> createState() => _ResourceInputState();
}

class _ResourceInputState extends State<_ResourceInput> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _ResourceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        (!_focusNode.hasFocus ||
            _textController.text == '${oldWidget.value}')) {
      _setText(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) return;
    final parsed = int.tryParse(_textController.text);
    final normalized = parsed == null ? widget.value : parsed.clamp(10, 300);
    _setText(normalized);
    if (normalized != widget.value) widget.onCommit(normalized);
  }

  void _setText(int value) {
    _textController.value = TextEditingValue(
      text: '$value',
      selection: TextSelection.collapsed(offset: '$value'.length),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    key: Key('development-resource-semantics-${widget.index}'),
    label: widget.label,
    textField: true,
    child: Tooltip(
      message: widget.label,
      child: SizedBox(
        width: 126,
        child: TextFormField(
          key: Key('development-resource-${widget.index}'),
          controller: _textController,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (text) {
            final parsed = int.tryParse(text);
            if (parsed != null && parsed >= 10 && parsed <= 300) {
              widget.onCommit(parsed);
            }
          },
          onFieldSubmitted: (_) => _focusNode.unfocus(),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xff0b202d),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                widget.asset,
                key: Key('development-resource-icon-${widget.index}'),
                width: 23,
                height: 23,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),
    ),
  );
}

void _commitResource(
  EquipmentDevelopmentController controller,
  int index,
  int value,
) {
  final values = controller.resources.values..[index] = value;
  controller.commitResources(
    DevelopmentResources(values[0], values[1], values[2], values[3]),
  );
}

String _poolTypeLabel(AppLocalizations l10n, DevelopmentPoolType type) =>
    switch (type) {
      DevelopmentPoolType.bauxite => l10n.developmentPoolBauxite,
      DevelopmentPoolType.ammunition => l10n.developmentPoolAmmunition,
      DevelopmentPoolType.fuelSteel => l10n.developmentPoolFuelSteel,
    };
