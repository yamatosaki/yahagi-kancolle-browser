import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'src/battle/battle_controller.dart';
import 'src/logbook/logbook_page.dart';
import 'src/battle/live_battle_card.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/game_browser_overlay.dart';
import 'src/browser/game_browser_toolbar.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/capture/battle_result_warning_overlay.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/capture/game_capture_port.dart';
import 'src/fleet/fleet_information_center.dart';
import 'src/fleet/fleet_summary_card.dart';
import 'src/fleet/expedition_summary_card.dart';
import 'src/fleet/repair_summary_card.dart';
import 'src/fleet/construction_summary_card.dart';
import 'src/fleet/pre_sortie_check_summary.dart';
import 'src/fleet/resource_grid.dart';
import 'src/expedition/expedition_check_card.dart';
import 'src/expedition/expedition_check_page.dart';

import 'src/game_webview.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_state_store.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/pinned_quests_summary.dart';
import 'src/quest/quest_center_page.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/network_settings_controller.dart';
import 'src/settings/network_settings_store.dart';
import 'src/settings/safety_settings_controller.dart';
import 'src/settings/safety_settings_store.dart';
import 'src/settings/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  final networkSettingsController = NetworkSettingsController(
    store: SharedPreferencesNetworkSettingsStore(),
  );
  await networkSettingsController.initialize();
  final safetySettingsController = await SafetySettingsController.load(
    SharedPreferencesSafetySettingsStore(),
  );
  final captureModeController = await CaptureModeController.load(
    SharedPreferencesCaptureModeStore(),
  );
  final controller = PrototypeStatusController(
    captureEnabled: () => captureModeController.captureEnabled,
  );
  final browserController = GameBrowserController();
  final audioController = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  final toolbarController = GameToolbarController();
  final questStore = SharedPreferencesQuestStore();
  final gameStateStore = GameStateStore();
  final gameStateController = GameStateController(
    questStore: questStore,
    gameStateStore: gameStateStore,
  );
  final battleController = BattleController(
    gameState: () => gameStateController.state,
  );
  final gameCaptureController = GameCaptureController(
    onAcceptedEvent: (event) {
      gameStateController.accept(event);
      battleController.accept(event);
    },
  );
  runApp(
    YahagiApp(
      layoutSettingsController: layoutSettingsController,
      networkSettingsController: networkSettingsController,
      safetySettingsController: safetySettingsController,
      controller: controller,
      browserController: browserController,
      captureModeController: captureModeController,
      audioController: audioController,
      toolbarController: toolbarController,
      gameCaptureController: gameCaptureController,
      gameStateController: gameStateController,
      battleController: battleController,
    ),
  );
}

class YahagiApp extends StatelessWidget {
  const YahagiApp({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.battleController,
    this.gameSurface,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final BattleController battleController;
  final Widget? gameSurface;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: layoutSettingsController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ヤハギ',
          locale: layoutSettingsController.localeCode != null
              ? (layoutSettingsController.localeCode == 'zh_Hant'
                    ? const Locale.fromSubtags(
                        languageCode: 'zh',
                        scriptCode: 'Hant',
                      )
                    : Locale(layoutSettingsController.localeCode!))
              : null,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: layoutSettingsController.fontFamily,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffd4a85f),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xff0a1823),
            useMaterial3: true,
          ),
          home: YahagiShell(
            layoutSettingsController: layoutSettingsController,
            networkSettingsController: networkSettingsController,
            safetySettingsController: safetySettingsController,
            controller: controller,
            browserController: browserController,
            captureModeController: captureModeController,
            audioController: audioController,
            toolbarController: toolbarController,
            gameCaptureController: gameCaptureController,
            gameStateController: gameStateController,
            battleController: battleController,
            gameSurface: BattleResultWarningOverlay(
              gameCaptureController: gameCaptureController,
              battleController: battleController,
              safetySettingsController: safetySettingsController,
              child:
                  gameSurface ??
                  GameWebView(
                    key: const GlobalObjectKey('yahagi_game_webview'),
                    networkSettingsController: networkSettingsController,
                    safetySettingsController: safetySettingsController,
                    controller: controller,
                    browserController: browserController,
                    captureModeController: captureModeController,
                    audioController: audioController,
                    toolbarController: toolbarController,
                    gameCaptureController: gameCaptureController,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class YahagiShell extends StatefulWidget {
  const YahagiShell({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameSurface,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.battleController,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final Widget gameSurface;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final BattleController battleController;

  @override
  State<YahagiShell> createState() => _YahagiShellState();
}

class _YahagiShellState extends State<YahagiShell> {
  int _workspaceIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        left: false,
        right: false,
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Color(0xff122431),
                border: Border(bottom: BorderSide(color: Color(0xff294052))),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ヤハギ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: widget.gameStateController,
                      builder: (context, _) => CompactResourceBar(
                        state: widget.gameStateController.state,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _WorkspaceNavigation(
                    selectedIndex: _workspaceIndex,
                    onSelected: (index) {
                      setState(() => _workspaceIndex = index);
                    },
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Offstage(
                          offstage: _workspaceIndex != 0,
                          child: LayoutBuilder(
                            key: const Key('game-workspace'),
                            builder: (context, constraints) {
                              final isLandscape =
                                  constraints.maxWidth >
                                  constraints.maxHeight * 1.35;
                              final gameWidget = GameBrowserOverlay(
                                controller: widget.toolbarController,
                                gameSurface: isLandscape
                                    ? ColoredBox(
                                        color: const Color(0xff0a1823),
                                        child: Center(
                                          child: AspectRatio(
                                            aspectRatio: 1200 / 720,
                                            child: widget.gameSurface,
                                          ),
                                        ),
                                      )
                                    : widget.gameSurface,
                                toolbar: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    widget.browserController,
                                    widget.audioController,
                                  ]),
                                  builder: (context, _) => GameBrowserToolbar(
                                    mode: widget.browserController.mode,
                                    loadState:
                                        widget.browserController.loadState,
                                    displayAddress:
                                        widget.browserController.displayAddress,
                                    onBack: widget.browserController.goBack,
                                    onReload: widget.browserController.reload,
                                    onHome: widget.browserController.goHome,
                                    onEnterDmm: widget
                                        .browserController
                                        .enterDmmLoginTest,
                                    isMuted: widget.audioController.isMuted,
                                    audioEnabled:
                                        widget.audioController.canToggle,
                                    onToggleMuted:
                                        widget.audioController.toggleMuted,
                                    onCollapse:
                                        widget.toolbarController.collapse,
                                    onFitScreen: () =>
                                        widget.browserController.runJavaScript(
                                          'if(window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();',
                                        ),
                                  ),
                                ),
                              );

                              final infoWidget = _InformationPanel(
                                layoutSettingsController:
                                    widget.layoutSettingsController,
                                controller: widget.controller,
                                browserController: widget.browserController,
                                captureModeController:
                                    widget.captureModeController,
                                gameCaptureController:
                                    widget.gameCaptureController,
                                gameStateController: widget.gameStateController,
                                battleController: widget.battleController,
                                onOpenExpeditionCheck: () {
                                  setState(() => _workspaceIndex = 8);
                                },
                              );

                              return isLandscape
                                  ? Row(
                                      children: [
                                        Expanded(
                                          flex: 65,
                                          child: DecoratedBox(
                                            decoration: const BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black38,
                                                  offset: Offset(2, 0),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: gameWidget,
                                          ),
                                        ),
                                        const VerticalDivider(
                                          width: 1,
                                          thickness: 1,
                                          color: Color(0xff294052),
                                        ),
                                        Expanded(
                                          flex: 35,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            child: infoWidget,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        DecoratedBox(
                                          decoration: const BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black38,
                                                offset: Offset(0, 2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 1200 / 720,
                                            child: gameWidget,
                                          ),
                                        ),
                                        const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Color(0xff294052),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: infoWidget,
                                          ),
                                        ),
                                      ],
                                    );
                            },
                          ),
                        ),
                        if (_workspaceIndex == 1)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.fleet,
                          ),
                        if (_workspaceIndex == 2)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.expedition,
                          ),
                        if (_workspaceIndex == 3)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.repair,
                          ),
                        if (_workspaceIndex == 4)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.construction,
                          ),
                        if (_workspaceIndex == 5)
                          QuestCenterPage(
                            controller: widget.gameStateController,
                          ),
                        if (_workspaceIndex == 6)
                          LogbookPage(
                            battleController: widget.battleController,
                          ),
                        if (_workspaceIndex == 7)
                          SettingsPage(
                            layoutSettingsController:
                                widget.layoutSettingsController,
                            networkSettingsController:
                                widget.networkSettingsController,
                            audioController: widget.audioController,
                            captureModeController: widget.captureModeController,
                            browserController: widget.browserController,
                            gameCaptureController: widget.gameCaptureController,
                            prototypeStatusController: widget.controller,
                            gameStateController: widget.gameStateController,
                            safetySettingsController:
                                widget.safetySettingsController,
                          ),
                        if (_workspaceIndex == 8)
                          ExpeditionCheckPage(
                            controller: widget.gameStateController,
                            onBack: () {
                              setState(() => _workspaceIndex = 0);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        color: Color(0xff0a1823),
        border: Border(right: BorderSide(color: Color(0xff294052))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _NavigationButton(
                      key: const Key('workspace-nav-game'),
                      icon: Icons.videogame_asset_outlined,
                      label: AppLocalizations.of(context)?.game ?? '游戏',
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-fleet'),
                      icon: Icons.directions_boat_outlined,
                      label: AppLocalizations.of(context)?.fleet ?? '舰队',
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-expedition'),
                      icon: Icons.explore_outlined,
                      label: AppLocalizations.of(context)?.expedition ?? '远征',
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-repair'),
                      icon: Icons.build_circle_outlined,
                      label: AppLocalizations.of(context)?.repair ?? '入渠',
                      selected: selectedIndex == 3,
                      onTap: () => onSelected(3),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-construction'),
                      icon: Icons.handyman_outlined,
                      label: AppLocalizations.of(context)?.construction ?? '建造',
                      selected: selectedIndex == 4,
                      onTap: () => onSelected(4),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-quests'),
                      icon: Icons.assignment_outlined,
                      label: AppLocalizations.of(context)?.quests ?? '任务',
                      selected: selectedIndex == 5,
                      onTap: () => onSelected(5),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-battle-records'),
                      icon: Icons.menu_book_outlined,
                      label:
                          AppLocalizations.of(context)?.battleRecords ?? '航海日志',
                      selected: selectedIndex == 6,
                      onTap: () => onSelected(6),
                    ),
                    const Spacer(),
                    _NavigationButton(
                      key: const Key('workspace-nav-settings'),
                      icon: Icons.settings_outlined,
                      label: AppLocalizations.of(context)?.settings ?? '设置',
                      selected: selectedIndex == 7,
                      onTap: () => onSelected(7),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          foregroundColor: selected
              ? const Color(0xffd4a85f)
              : const Color(0xff8197a5),
          backgroundColor: selected
              ? const Color(0xff2b2c22)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _InformationPanel extends StatefulWidget {
  const _InformationPanel({
    required this.layoutSettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.battleController,
    required this.onOpenExpeditionCheck,
  });

  final LayoutSettingsController layoutSettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final BattleController battleController;
  final VoidCallback onOpenExpeditionCheck;

  @override
  State<_InformationPanel> createState() => _InformationPanelState();
}

class _InformationPanelState extends State<_InformationPanel> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('information-panel'),
      decoration: const BoxDecoration(
        color: Color(0xff0d1a26),
        border: Border(left: BorderSide(color: Color(0xff294052))),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.layoutSettingsController,
          widget.browserController,
          widget.gameCaptureController,
        ]),
        builder: (context, _) {
          final hasError =
              widget.browserController.loadState == GamePageLoadState.failed ||
              widget.gameCaptureController.state == GameCaptureState.error ||
              widget.gameCaptureController.state ==
                  GameCaptureState.unsupported;

          final collapsedIds =
              widget.layoutSettingsController.dashboardCardCollapsed;
          final hiddenIds = widget.layoutSettingsController.dashboardCardHidden;
          final cardOrder = widget.layoutSettingsController.dashboardCardOrder;
          final visibleOrder = cardOrder.where((id) => !hiddenIds.contains(id)).toList();
          final cardIndexes = <String, int>{
            for (var i = 0; i < cardOrder.length; i++) cardOrder[i]: i,
          };

          Widget buildCard(String id) {
            final isCollapsed = collapsedIds.contains(id);
            void toggle() => widget.layoutSettingsController
                .toggleDashboardCardCollapsed(id);
            final child = switch (id) {
              'fleet' => FleetSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'expedition' => ExpeditionSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'expedition_check' => ExpeditionCheckCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenDetails: widget.onOpenExpeditionCheck,
              ),
              'repair' => RepairSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'construction' => ConstructionSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'quests' => PinnedQuestsSummary(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'battle' => LiveBattleCard(
                controller: widget.battleController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'pre_sortie' => PreSortieCheckSummary(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              _ => const SizedBox.shrink(),
            };

            Widget finalChild = Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: child,
            );

            if (_isEditing) {
              final isHidden = hiddenIds.contains(id);
              finalChild = Opacity(
                opacity: isHidden ? 0.5 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: !isHidden,
                        activeColor: const Color(0xffd4a85f),
                        checkColor: Colors.black,
                        side: const BorderSide(color: Color(0xff8fa8b6), width: 2),
                        onChanged: (val) {
                          widget.layoutSettingsController.toggleDashboardCardHidden(id);
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ReorderableDelayedDragStartListener(
                          index: cardIndexes[id] ?? 0,
                          child: Container(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Icon(Icons.drag_handle, color: Color(0xff8fa8b6)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: IgnorePointer(
                                    child: child,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return KeyedSubtree(
              key: ValueKey(id),
              child: finalChild,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    const Text('功能面板', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xffd4a85f))),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: _isEditing ? const Color(0xff000000) : const Color(0xffd4a85f),
                        backgroundColor: _isEditing ? const Color(0xffd4a85f) : Colors.transparent,
                        side: const BorderSide(color: Color(0xffd4a85f)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {
                        setState(() => _isEditing = !_isEditing);
                      },
                      child: Text(_isEditing ? '完成编辑' : '编辑顺序', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    if (!_isEditing) {
                      setState(() => _isEditing = true);
                    }
                  },
                  child: _isEditing
                      ? ReorderableListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            final order = List<String>.from(
                              widget.layoutSettingsController.dashboardCardOrder,
                            );
                            final item = order.removeAt(oldIndex);
                            order.insert(newIndex, item);
                            widget.layoutSettingsController.setDashboardCardOrder(
                              order,
                            );
                          },
                          children: [
                            for (final id in cardOrder)
                              buildCard(id),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final id in visibleOrder)
                              buildCard(id),
                            if (hasError)
                              Padding(
                                key: const ValueKey('error_card'),
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _InfoCard(
                                  title: '游戏状态异常',
                                  subtitle:
                                      widget.gameCaptureController.errorMessage ??
                                      widget.browserController.errorMessage ??
                                      '网页或捕获状态异常，请在设置中查看诊断信息。',
                                  warning: true,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    this.warning = false,
  });

  final String title;
  final String subtitle;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xff3a292b) : const Color(0xff142735),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: warning ? const Color(0xff75484a) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xff8197a5), height: 1.35),
          ),
        ],
      ),
    );
  }
}
