import 'package:flutter/foundation.dart';

import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/custom_font_controller.dart';
import 'header_resource_settings.dart';
import 'workspace_menu_settings.dart';
import 'fleet_display_options.dart';
import 'module_display_settings.dart';
import 'layout_settings_store.dart';
import 'hd_layout_settings.dart';
import 'camera_avoidance_settings.dart';
import 'ui_font_size.dart';
import 'dashboard_display_mode.dart';

class LayoutSettingsController extends ChangeNotifier {
  LayoutSettingsController._(
    this._store,
    this._gameAreaRatio,
    this._informationPanelWidth,
    this._autoZoom,
    this._enhancedDamagePulse,
    this._workspaceMenuOnRight,
    this._workspaceMenuOrder,
    this._dashboardCardOrder,
    this._dashboardCardCollapsed,
    this._dashboardCardHidden,
    this._fontFamily,
    this._localeCode,
    this._systemLocaleCode,
    this._fontLocaleCode,
    this._fleetMoraleMetricMode,
  );

  static Future<LayoutSettingsController> load(
    LayoutSettingsStore store, {
    String? systemLocaleCode,
    CustomFontController? customFontController,
  }) async {
    final ratio = await store.loadGameAreaRatio();
    final width = await store.loadInformationPanelWidth();
    final autoZoom = await store.loadAutoZoom();
    final enhancedDamagePulse = await store.loadEnhancedDamagePulse();
    final workspaceMenuOnRight = await store.loadWorkspaceMenuOnRight();
    final workspaceMenuStore = store is WorkspaceMenuOrderSettingsStore
        ? store as WorkspaceMenuOrderSettingsStore
        : null;
    final workspaceMenuOrder = workspaceMenuStore == null
        ? List<String>.from(LayoutSettingsStore.defaultWorkspaceMenuOrder)
        : await workspaceMenuStore.loadWorkspaceMenuOrder();
    final dashboardCardOrder = await store.loadDashboardCardOrder();
    final dashboardCardCollapsed = await store.loadDashboardCardCollapsed();
    final dashboardCardHidden = await store.loadDashboardCardHidden();
    final fontFamily = await store.loadFontFamily();
    final localeCode = await store.loadLocaleCode();
    final moraleMetricStore = store is FleetMoraleMetricSettingsStore
        ? store as FleetMoraleMetricSettingsStore
        : null;
    final fleetMoraleMetricMode = moraleMetricStore == null
        ? FleetMoraleMetricMode.minimumCondition
        : await moraleMetricStore.loadFleetMoraleMetricMode();
    final fontLocaleCode = localeCode ?? systemLocaleCode ?? 'zh';
    final regionalFont = AppFonts.forLocale(fontLocaleCode);
    if (fontFamily != regionalFont) {
      await store.saveFontFamily(regionalFont);
    }
    final controller = LayoutSettingsController._(
      store,
      ratio,
      width,
      autoZoom,
      enhancedDamagePulse,
      workspaceMenuOnRight,
      workspaceMenuOrder,
      dashboardCardOrder,
      dashboardCardCollapsed,
      dashboardCardHidden,
      regionalFont,
      localeCode,
      systemLocaleCode ?? 'zh',
      fontLocaleCode,
      fleetMoraleMetricMode,
    );
    controller._customFontController = customFontController;
    controller._lastCustomFontFamily = customFontController?.fontFamily;
    customFontController?.addListener(controller._handleCustomFontChanged);
    if (store is DashboardDisplayModeSettingsStore) {
      try {
        controller._dashboardDisplayMode =
            await (store as DashboardDisplayModeSettingsStore)
                .loadDashboardDisplayMode();
      } catch (error) {
        debugPrint('Briefing display preference could not be loaded: $error');
      }
    }
    controller._persistedDashboardDisplayMode =
        controller._dashboardDisplayMode;
    if (store is WorkspaceMenuPositionStore) {
      final position = await (store as WorkspaceMenuPositionStore)
          .loadWorkspaceMenuPosition();
      if (['top', 'bottom', 'left', 'right'].contains(position)) {
        controller._workspaceMenuPosition = position;
        controller._workspaceMenuOnRight = position == 'right';
      }
    }
    if (store is HdLayoutSettingsStore) {
      controller._hdSettings = await (store as HdLayoutSettingsStore)
          .loadHdLayoutSettings();
    }
    if (store is InformationPanelSideSettingsStore) {
      controller._informationPanelOnLeft =
          await (store as InformationPanelSideSettingsStore)
              .loadInformationPanelOnLeft();
    }
    final headerStore = store is HeaderResourceSettingsStore
        ? store as HeaderResourceSettingsStore
        : null;
    if (headerStore != null) {
      final savedOrder = await headerStore.loadHeaderResourceOrder();
      final savedVisible = await headerStore.loadVisibleHeaderResourceIds();
      final migratesSenka = !savedOrder.contains(headerSenkaId);
      final migratesAnchorageTimer = !savedOrder.contains(
        headerAnchorageTimerId,
      );
      final migratesNosakiTimer = !savedOrder.contains(headerNosakiTimerId);
      final migratesShipCapacity = !savedOrder.contains(headerShipCapacityId);
      final migratesEquipmentCapacity = !savedOrder.contains(
        headerEquipmentCapacityId,
      );
      final migratesFurnitureCoin = !savedOrder.contains(headerFurnitureCoinId);
      final migratesGameRefresh = !savedOrder.contains(headerGameRefreshId);
      controller._headerResourceOrder = normalizeHeaderResourceOrder(
        savedOrder,
      );
      controller._visibleHeaderResourceIds = normalizeVisibleHeaderResourceIds(
        savedVisible,
      );
      if (migratesSenka && savedVisible != null) {
        controller._visibleHeaderResourceIds = <String>[
          headerSenkaId,
          ...controller._visibleHeaderResourceIds!.where(
            (id) => id != headerSenkaId,
          ),
        ];
      }
      if (migratesAnchorageTimer &&
          savedVisible != null &&
          !controller._visibleHeaderResourceIds!.contains(
            headerAnchorageTimerId,
          )) {
        final visible = controller._visibleHeaderResourceIds!;
        final senkaIndex = visible.indexOf(headerSenkaId);
        visible.insert(
          senkaIndex < 0 ? 0 : senkaIndex + 1,
          headerAnchorageTimerId,
        );
      }
      if (migratesNosakiTimer &&
          savedVisible != null &&
          !controller._visibleHeaderResourceIds!.contains(
            headerNosakiTimerId,
          )) {
        final visible = controller._visibleHeaderResourceIds!;
        final anchorageIndex = visible.indexOf(headerAnchorageTimerId);
        final senkaIndex = visible.indexOf(headerSenkaId);
        final insertIndex = anchorageIndex >= 0
            ? anchorageIndex + 1
            : (senkaIndex >= 0 ? senkaIndex + 1 : 0);
        visible.insert(insertIndex, headerNosakiTimerId);
      }
      if (savedVisible != null) {
        if (migratesShipCapacity &&
            !controller._visibleHeaderResourceIds!.contains(
              headerShipCapacityId,
            )) {
          controller._visibleHeaderResourceIds!.add(headerShipCapacityId);
        }
        if (migratesEquipmentCapacity &&
            !controller._visibleHeaderResourceIds!.contains(
              headerEquipmentCapacityId,
            )) {
          controller._visibleHeaderResourceIds!.add(headerEquipmentCapacityId);
        }
      }
      if (migratesSenka ||
          migratesAnchorageTimer ||
          migratesNosakiTimer ||
          migratesShipCapacity ||
          migratesEquipmentCapacity ||
          migratesGameRefresh ||
          migratesFurnitureCoin) {
        await headerStore.saveHeaderResourceOrder(
          controller._headerResourceOrder!,
        );
        if (savedVisible != null) {
          await headerStore.saveVisibleHeaderResourceIds(
            controller._visibleHeaderResourceIds!,
          );
        }
      }
    }
    if (store is FleetDisplaySettingsStore) {
      final fleetDisplayStore = store as FleetDisplaySettingsStore;
      final saved = await fleetDisplayStore.loadFleetDisplayFields();
      controller._fleetDisplayFields = normalizeDisplayFields(
        saved ?? defaultFields,
      );
      controller._fleetShipTypeLabelMode = await fleetDisplayStore
          .loadFleetShipTypeLabelMode();
      setFleetSelectorLabelModeSetting(
        await fleetDisplayStore.loadFleetSelectorLabelMode(),
      );
      controller._showClearedMaps = await fleetDisplayStore
          .loadShowClearedMaps();
      if (saved == null &&
          fleetMoraleMetricMode == FleetMoraleMetricMode.recoveryCountdown) {
        controller._fleetDisplayFields = {...controller._fleetDisplayFields}
          ..remove('minimum-condition')
          ..add('recovery-countdown');
      }
    }
    if (store is ModuleDisplaySettingsStore) {
      setRepairFleetSelectorLabelModeSetting(
        await (store as ModuleDisplaySettingsStore)
            .loadRepairFleetSelectorLabelMode(),
      );
      final savedHd = await (store as ModuleDisplaySettingsStore)
          .loadModuleDisplayFields('fleet-hd-summary');
      controller._hdFleetSummaryFields = savedHd
          ?.where(summaryFields.contains)
          .take(7)
          .toSet();
      for (final module in moduleDisplayOptions.keys) {
        final saved = await (store as ModuleDisplaySettingsStore)
            .loadModuleDisplayFields(module);
        if (saved != null) {
          controller._moduleDisplayFields[module] = saved.toSet().intersection(
            moduleDisplayOptions[module]!.keys.toSet(),
          );
        }
      }
      for (final module in LayoutSettingsStore.defaultDashboardCardOrder) {
        controller._moduleShowLogo[module] =
            await (store as ModuleDisplaySettingsStore).loadModuleShowLogo(
              module,
            );
        controller._moduleShowName[module] =
            await (store as ModuleDisplaySettingsStore).loadModuleShowName(
              module,
            );
      }
    }
    if (store is TopNoticeSettingsStore) {
      final topNoticeStore = store as TopNoticeSettingsStore;
      controller._topNoticeEnabled = await topNoticeStore
          .loadTopNoticeEnabled();
      controller._topNoticeDurationSeconds = await topNoticeStore
          .loadTopNoticeDurationSeconds();
    }
    if (store is UiDisplaySizeSettingsStore) {
      controller._uiDisplaySize = await (store as UiDisplaySizeSettingsStore)
          .loadUiDisplaySize();
    } else if (store is HeaderUiSizeSettingsStore) {
      controller._uiDisplaySize = await (store as HeaderUiSizeSettingsStore)
          .loadHeaderUiSize();
    } else if (store is WorkspaceMenuSizeSettingsStore) {
      controller._uiDisplaySize =
          await (store as WorkspaceMenuSizeSettingsStore)
              .loadWorkspaceMenuSize();
    }
    if (store is UiFontSizeSettingsStore) {
      try {
        controller._uiFontSize = await (store as UiFontSizeSettingsStore)
            .loadUiFontSize();
      } catch (error) {
        debugPrint('UI font size preference could not be loaded: $error');
      }
    }
    controller._persistedUiFontSize = controller._uiFontSize;
    if (store is MinimalResourcePositionSettingsStore) {
      controller._minimalResourcePosition =
          await (store as MinimalResourcePositionSettingsStore)
              .loadMinimalResourcePosition();
    }
    if (store is MinimalCollapsedResourceSettingsStore) {
      final saved = await (store as MinimalCollapsedResourceSettingsStore)
          .loadCollapsedPanelResourceIds();
      controller._collapsedPanelResourceIds = saved == null
          ? null
          : _normalizeCollapsedPanelResourceIds(saved);
    }
    if (store is UiLockSettingsStore) {
      controller._uiLocked = await (store as UiLockSettingsStore)
          .loadUiLocked();
    }
    if (store is AppThemeSettingsStore) {
      try {
        controller._appThemeMode = await (store as AppThemeSettingsStore)
            .loadAppThemeMode();
      } catch (error) {
        debugPrint('Appearance preference could not be loaded: $error');
      }
    }
    controller._persistedAppThemeMode = controller._appThemeMode;
    if (store is CameraAvoidanceSettingsStore) {
      try {
        controller._cameraAvoidanceSettings =
            (await (store as CameraAvoidanceSettingsStore)
                    .loadCameraAvoidanceSettings())
                .normalized();
      } catch (error) {
        debugPrint('Camera avoidance preference could not be loaded: $error');
      }
    }
    controller._persistedCameraAvoidanceSettings =
        controller._cameraAvoidanceSettings;
    controller._expeditionCountdownConfigured = true;
    controller._fleetDisplayFieldsLoaded = true;
    return controller;
  }

  bool _uiLocked = false;
  bool get uiLocked => _uiLocked;

  DashboardDisplayMode _dashboardDisplayMode = DashboardDisplayMode.accordion;
  DashboardDisplayMode _persistedDashboardDisplayMode =
      DashboardDisplayMode.accordion;
  Future<void> _dashboardDisplayModeSaveQueue = Future<void>.value();
  int _dashboardDisplayModeRevision = 0;
  bool _dashboardDisplayModeDisposed = false;
  DashboardDisplayMode get dashboardDisplayMode => _dashboardDisplayMode;

  Future<void> setDashboardDisplayMode(DashboardDisplayMode mode) async {
    if (_dashboardDisplayModeDisposed) return;
    if (_dashboardDisplayMode == mode) return _dashboardDisplayModeSaveQueue;
    final revision = ++_dashboardDisplayModeRevision;
    _dashboardDisplayMode = mode;
    if (_store is DashboardDisplayModeSettingsStore) {
      final save = _dashboardDisplayModeSaveQueue.then((_) async {
        try {
          await (_store as DashboardDisplayModeSettingsStore)
              .saveDashboardDisplayMode(mode);
          _persistedDashboardDisplayMode = mode;
        } catch (error) {
          if (revision == _dashboardDisplayModeRevision) {
            _dashboardDisplayMode = _persistedDashboardDisplayMode;
            if (!_dashboardDisplayModeDisposed) notifyListeners();
          }
          debugPrint('Briefing display preference could not be saved: $error');
        }
      });
      _dashboardDisplayModeSaveQueue = save;
      notifyListeners();
      await save;
    } else {
      notifyListeners();
    }
  }

  CameraAvoidanceSettings _cameraAvoidanceSettings =
      const CameraAvoidanceSettings();
  CameraAvoidanceSettings _persistedCameraAvoidanceSettings =
      const CameraAvoidanceSettings();
  Future<void> _cameraAvoidanceSaveQueue = Future<void>.value();
  int _cameraAvoidanceRevision = 0;
  bool _cameraAvoidanceDisposed = false;

  bool get cameraAvoidanceEnabled => _cameraAvoidanceSettings.enabled;
  double get cameraAvoidanceDistance => _cameraAvoidanceSettings.distance;

  Future<void> setCameraAvoidanceEnabled(bool enabled) =>
      _setCameraAvoidanceSettings(
        CameraAvoidanceSettings(
          enabled: enabled,
          distance: cameraAvoidanceDistance,
        ),
      );

  Future<void> setCameraAvoidanceDistance(double distance) =>
      _setCameraAvoidanceSettings(
        CameraAvoidanceSettings(
          enabled: cameraAvoidanceEnabled,
          distance: CameraAvoidanceSettings.normalizeDistance(distance),
        ),
      );

  Future<void> _setCameraAvoidanceSettings(
    CameraAvoidanceSettings settings,
  ) async {
    if (_cameraAvoidanceDisposed) return;
    if (settings.enabled == cameraAvoidanceEnabled &&
        settings.distance == cameraAvoidanceDistance) {
      return _cameraAvoidanceSaveQueue;
    }
    final revision = ++_cameraAvoidanceRevision;
    _cameraAvoidanceSettings = settings;
    if (_store is CameraAvoidanceSettingsStore) {
      // Save complete snapshots in order while the UI previews each edit.
      final save = _cameraAvoidanceSaveQueue.then((_) async {
        try {
          await (_store as CameraAvoidanceSettingsStore)
              .saveCameraAvoidanceSettings(settings);
          _persistedCameraAvoidanceSettings = settings;
        } catch (error) {
          if (revision == _cameraAvoidanceRevision) {
            _cameraAvoidanceSettings = _persistedCameraAvoidanceSettings;
            if (!_cameraAvoidanceDisposed) notifyListeners();
          }
          debugPrint('Camera avoidance preference could not be saved: $error');
        }
      });
      _cameraAvoidanceSaveQueue = save;
      notifyListeners();
      await save;
    } else {
      notifyListeners();
    }
  }

  AppThemeMode _appThemeMode = AppThemeMode.dark;
  AppThemeMode _persistedAppThemeMode = AppThemeMode.dark;
  Future<void> _appThemeSaveQueue = Future<void>.value();
  int _appThemeRevision = 0;
  bool _appThemeDisposed = false;
  AppThemeMode get appThemeMode => _appThemeMode;

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    if (_appThemeDisposed) return;
    if (_appThemeMode == mode) return _appThemeSaveQueue;
    final revision = ++_appThemeRevision;
    _appThemeMode = mode;
    if (_store is AppThemeSettingsStore) {
      // Keep the immediate preview while committing rapid selections in order.
      // A late failure may only roll back the selection that caused it.
      final save = _appThemeSaveQueue.then((_) async {
        try {
          await (_store as AppThemeSettingsStore).saveAppThemeMode(mode);
          _persistedAppThemeMode = mode;
        } catch (error) {
          if (revision == _appThemeRevision) {
            _appThemeMode = _persistedAppThemeMode;
            if (!_appThemeDisposed) notifyListeners();
          }
          debugPrint('Appearance preference could not be saved: $error');
        }
      });
      _appThemeSaveQueue = save;
      notifyListeners();
      await save;
    } else {
      notifyListeners();
    }
  }

  Future<void> setUiLocked(bool locked) async {
    if (_uiLocked == locked) return;
    final previous = _uiLocked;
    _uiLocked = locked;
    notifyListeners();
    if (_store is UiLockSettingsStore) {
      try {
        await (_store as UiLockSettingsStore).saveUiLocked(locked);
      } catch (e) {
        _uiLocked = previous;
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> toggleUiLocked() => setUiLocked(!_uiLocked);

  UiDisplaySize _uiDisplaySize = UiDisplaySize.normal;
  UiDisplaySize get uiDisplaySize => _uiDisplaySize;

  UiFontSize _uiFontSize = UiFontSize.system;
  UiFontSize _persistedUiFontSize = UiFontSize.system;
  Future<void> _uiFontSizeSaveQueue = Future<void>.value();
  int _uiFontSizeRevision = 0;
  bool _uiFontSizeDisposed = false;
  UiFontSize get uiFontSize => _uiFontSize;

  Future<void> setUiFontSize(UiFontSize size) async {
    if (_uiFontSizeDisposed) return;
    if (_uiFontSize == size) return _uiFontSizeSaveQueue;
    final revision = ++_uiFontSizeRevision;
    _uiFontSize = size;
    if (_store is UiFontSizeSettingsStore) {
      // Preview immediately while committing rapid selections in order.
      final save = _uiFontSizeSaveQueue.then((_) async {
        try {
          await (_store as UiFontSizeSettingsStore).saveUiFontSize(size);
          _persistedUiFontSize = size;
        } catch (error) {
          if (revision == _uiFontSizeRevision) {
            _uiFontSize = _persistedUiFontSize;
            if (!_uiFontSizeDisposed) notifyListeners();
          }
          debugPrint('UI font size preference could not be saved: $error');
        }
      });
      _uiFontSizeSaveQueue = save;
      notifyListeners();
      await save;
    } else {
      notifyListeners();
    }
  }

  Future<void> setUiDisplaySize(UiDisplaySize size) async {
    if (_uiDisplaySize == size) return;
    _uiDisplaySize = size;
    notifyListeners();
    if (_store is UiDisplaySizeSettingsStore) {
      await (_store as UiDisplaySizeSettingsStore).saveUiDisplaySize(size);
    } else {
      if (_store is HeaderUiSizeSettingsStore) {
        await (_store as HeaderUiSizeSettingsStore).saveHeaderUiSize(size);
      }
      if (_store is WorkspaceMenuSizeSettingsStore) {
        await (_store as WorkspaceMenuSizeSettingsStore).saveWorkspaceMenuSize(
          size,
        );
      }
    }
  }

  MinimalResourcePosition _minimalResourcePosition =
      MinimalResourcePosition.panel;
  MinimalResourcePosition get minimalResourcePosition =>
      _minimalResourcePosition;

  Future<void> setMinimalResourcePosition(
    MinimalResourcePosition position,
  ) async {
    if (_minimalResourcePosition == position) return;
    _minimalResourcePosition = position;
    notifyListeners();
    if (_store is MinimalResourcePositionSettingsStore) {
      await (_store as MinimalResourcePositionSettingsStore)
          .saveMinimalResourcePosition(position);
    }
  }

  List<String>? _collapsedPanelResourceIds;

  /// 信息栏资源区折叠时显示的项；null 表示用户没配置过，由网格按默认规则取。
  List<String>? get collapsedPanelResourceIds =>
      _collapsedPanelResourceIds == null
      ? null
      : List<String>.unmodifiable(_collapsedPanelResourceIds!);

  Future<void> setCollapsedPanelResourceIds(List<String>? ids) async {
    _collapsedPanelResourceIds = ids == null
        ? null
        : _normalizeCollapsedPanelResourceIds(ids);
    notifyListeners();
    if (_store is MinimalCollapsedResourceSettingsStore) {
      await (_store as MinimalCollapsedResourceSettingsStore)
          .saveCollapsedPanelResourceIds(_collapsedPanelResourceIds);
    }
  }

  static List<String> _normalizeCollapsedPanelResourceIds(
    Iterable<String> ids,
  ) => [
    for (final id in {...ids})
      if (allHeaderResourceIds.contains(id)) id,
  ];

  HeaderUiSize get headerUiSize => _uiDisplaySize;
  Future<void> setHeaderUiSize(HeaderUiSize size) => setUiDisplaySize(size);

  WorkspaceMenuSize get workspaceMenuSize => _uiDisplaySize;
  Future<void> setWorkspaceMenuSize(WorkspaceMenuSize size) =>
      setUiDisplaySize(size);

  bool _topNoticeEnabled = true;
  int _topNoticeDurationSeconds = 5;

  bool get topNoticeEnabled => _topNoticeEnabled;
  int get topNoticeDurationSeconds => _topNoticeDurationSeconds;

  Future<void> setTopNoticeEnabled(bool enabled) async {
    if (_topNoticeEnabled == enabled) return;
    _topNoticeEnabled = enabled;
    notifyListeners();
    if (_store is TopNoticeSettingsStore) {
      await (_store as TopNoticeSettingsStore).saveTopNoticeEnabled(enabled);
    }
  }

  Future<void> setTopNoticeDurationSeconds(int seconds) async {
    if (_topNoticeDurationSeconds == seconds) return;
    _topNoticeDurationSeconds = seconds;
    notifyListeners();
    if (_store is TopNoticeSettingsStore) {
      await (_store as TopNoticeSettingsStore).saveTopNoticeDurationSeconds(
        seconds,
      );
    }
  }

  Set<String> _fleetDisplayFields = {...defaultFields};
  bool _fleetDisplayFieldsLoaded = false;
  Set<String> get fleetDisplayFields => Set.unmodifiable(
    _fleetDisplayFieldsLoaded
        ? _fleetDisplayFields
        : {..._fleetDisplayFields, 'hp'},
  );
  Future<void> setFleetDisplayFields(Iterable<String> fields) async {
    _fleetDisplayFieldsLoaded = true;
    _fleetDisplayFields = normalizeDisplayFields(fields);
    notifyListeners();
    if (_store is FleetDisplaySettingsStore) {
      await (_store as FleetDisplaySettingsStore).saveFleetDisplayFields(
        _fleetDisplayFields.toList(),
      );
    }
  }

  Set<String>? _hdFleetSummaryFields;
  Set<String> get hdFleetDisplayFields => {
    ...fleetDisplayFields.difference(summaryFields),
    ...(_hdFleetSummaryFields ??
        {
          ...fleetDisplayFields.intersection(summaryFields),
          if (fleetDisplayFields.any(summaryFields.contains)) ...{
            'firepower',
            'anti-sub',
          },
        }),
  };

  Future<void> setHdFleetDisplayFields(Iterable<String> fields) async {
    final selected = fields.toSet();
    _hdFleetSummaryFields = selected
        .where(summaryFields.contains)
        .take(7)
        .toSet();
    await setFleetDisplayFields({
      ...selected.difference(summaryFields),
      ...fleetDisplayFields.intersection(summaryFields),
    });
    if (_store is ModuleDisplaySettingsStore) {
      await (_store as ModuleDisplaySettingsStore).saveModuleDisplayFields(
        'fleet-hd-summary',
        _hdFleetSummaryFields!.toList(),
      );
    }
  }

  FleetShipTypeLabelMode _fleetShipTypeLabelMode =
      FleetShipTypeLabelMode.localizedName;
  FleetShipTypeLabelMode get fleetShipTypeLabelMode => _fleetShipTypeLabelMode;
  Future<void> setFleetShipTypeLabelMode(FleetShipTypeLabelMode mode) async {
    if (_fleetShipTypeLabelMode == mode) return;
    _fleetShipTypeLabelMode = mode;
    notifyListeners();
    if (_store is FleetDisplaySettingsStore) {
      await (_store as FleetDisplaySettingsStore).saveFleetShipTypeLabelMode(
        mode,
      );
    }
  }

  FleetSelectorLabelMode get fleetSelectorLabelMode =>
      fleetSelectorLabelModeSetting;
  Future<void> setFleetSelectorLabelMode(FleetSelectorLabelMode mode) async {
    if (fleetSelectorLabelModeSetting == mode) return;
    setFleetSelectorLabelModeSetting(mode);
    notifyListeners();
    if (_store is FleetDisplaySettingsStore) {
      await (_store as FleetDisplaySettingsStore).saveFleetSelectorLabelMode(
        mode,
      );
    }
  }

  bool _showClearedMaps = false;
  bool get showClearedMaps => _showClearedMaps;
  Future<void> setShowClearedMaps(bool show) async {
    if (_showClearedMaps == show) return;
    _showClearedMaps = show;
    notifyListeners();
    if (_store is FleetDisplaySettingsStore) {
      await (_store as FleetDisplaySettingsStore).saveShowClearedMaps(show);
    }
  }

  // Existing live settings gain the new default when hot reloaded.
  bool _expeditionCountdownConfigured = false;
  final Map<String, Set<String>> _moduleDisplayFields = {};
  Set<String> moduleDisplayFields(String module) => Set.unmodifiable({
    ...(_moduleDisplayFields[module] ??
        moduleDisplayOptions[module]!.keys.toSet()),
    if (module == 'expedition' && !_expeditionCountdownConfigured) 'time',
  });
  Future<void> setModuleDisplayFields(
    String module,
    Iterable<String> fields,
  ) async {
    if (!moduleDisplayOptions.containsKey(module)) return;
    final selected = fields.toSet().intersection(
      moduleDisplayOptions[module]!.keys.toSet(),
    );
    if (module == 'expedition') _expeditionCountdownConfigured = true;
    _moduleDisplayFields[module] = selected;
    notifyListeners();
    if (_store is ModuleDisplaySettingsStore) {
      await (_store as ModuleDisplaySettingsStore).saveModuleDisplayFields(
        module,
        selected.toList(),
      );
    }
  }

  final Map<String, bool> _moduleShowLogo = {};
  final Map<String, bool> _moduleShowName = {};

  bool moduleShowLogo(String module) => _moduleShowLogo[module] ?? true;
  bool moduleShowName(String module) => _moduleShowName[module] ?? true;

  Future<void> setModuleShowLogo(String module, bool show) async {
    if (_moduleShowLogo[module] == show) return;
    _moduleShowLogo[module] = show;
    notifyListeners();
    if (_store is ModuleDisplaySettingsStore) {
      await (_store as ModuleDisplaySettingsStore).saveModuleShowLogo(
        module,
        show,
      );
    }
  }

  Future<void> setModuleShowName(String module, bool show) async {
    if (_moduleShowName[module] == show) return;
    _moduleShowName[module] = show;
    notifyListeners();
    if (_store is ModuleDisplaySettingsStore) {
      await (_store as ModuleDisplaySettingsStore).saveModuleShowName(
        module,
        show,
      );
    }
  }

  FleetSelectorLabelMode get repairFleetSelectorLabelMode =>
      repairFleetSelectorLabelModeSetting;

  Future<void> setRepairFleetSelectorLabelMode(
    FleetSelectorLabelMode mode,
  ) async {
    if (repairFleetSelectorLabelModeSetting == mode) return;
    setRepairFleetSelectorLabelModeSetting(mode);
    notifyListeners();
    if (_store is ModuleDisplaySettingsStore) {
      await (_store as ModuleDisplaySettingsStore)
          .saveRepairFleetSelectorLabelMode(mode);
    }
  }

  Future<void> resetAllModuleCapsuleVisibility() async {
    final allModules = {
      ...LayoutSettingsStore.defaultDashboardCardOrder,
      ...moduleDisplayOptions.keys,
    };
    for (final module in allModules) {
      _moduleShowLogo[module] = true;
      _moduleShowName[module] = true;
    }
    notifyListeners();
    if (_store is ModuleDisplaySettingsStore) {
      final store = _store as ModuleDisplaySettingsStore;
      await Future.wait([
        for (final module in allModules) ...[
          store.saveModuleShowLogo(module, true),
          store.saveModuleShowName(module, true),
        ],
      ]);
    }
  }

  final LayoutSettingsStore _store;

  HdLayoutSettings _hdSettings = const HdLayoutSettings();
  HdLayoutSettings get hdSettings => _hdSettings;

  Future<void> _setHdSettings(HdLayoutSettings settings) async {
    if (settings.encode() == _hdSettings.encode()) return;
    _hdSettings = settings;
    notifyListeners();
    if (_store is HdLayoutSettingsStore) {
      await (_store as HdLayoutSettingsStore).saveHdLayoutSettings(settings);
    }
  }

  Future<void> setHdEnabled(bool enabled) =>
      _setHdSettings(_hdSettings.copyWith(enabled: enabled));

  Future<void> setHdExtensionPosition(String position) async {
    if (position != 'top' && position != 'bottom') return;
    await _setHdSettings(_hdSettings.copyWith(extensionPosition: position));
  }

  // Kept for earlier callers; the home editor uses insertion and span APIs.
  Future<void> setHdSplit(bool split) => _setHdSettings(
    _hdSettings.copyWith(
      split: split,
      bottomModules: split
          ? [
              HdBottomModule(_hdSettings.leftModule, 1),
              HdBottomModule(_hdSettings.rightModule, 1),
            ]
          : [HdBottomModule(_hdSettings.wideModule, 3)],
    ),
  );

  Future<void> setHdModule(String slot, String module) async {
    if (!HdLayoutSettings.moduleIds.contains(module)) return;
    var next = switch (slot) {
      'left' => _hdSettings.copyWith(leftModule: module),
      'right' => _hdSettings.copyWith(rightModule: module),
      'wide' => _hdSettings.copyWith(wideModule: module),
      _ => _hdSettings,
    };
    final bottom = _hdSettings.bottom.toList();
    final index = slot == 'wide'
        ? (bottom.length == 1 ? 0 : -1)
        : slot == 'left'
        ? 0
        : slot == 'right'
        ? 1
        : -1;
    if (index >= 0 && index < bottom.length) {
      final span = bottom[index].span;
      bottom.removeAt(index);
      bottom.removeWhere((item) => item.id == module);
      bottom.insert(
        index.clamp(0, bottom.length),
        HdBottomModule(module, span),
      );
      next = next.copyWith(bottomModules: bottom);
    }
    await _setHdSettings(next);
  }

  bool canMoveHdModuleToBottom(String module) =>
      HdLayoutSettings.moduleIds.contains(module) &&
      (_hdSettings.activeModules.contains(module) ||
          _hdSettings.usedColumns < 3);

  Future<bool> moveHdModuleToBottom(
    String module, {
    String? before,
    bool after = false,
  }) async {
    if (!canMoveHdModuleToBottom(module)) return false;
    if (before == module) return true;
    final bottom = _hdSettings.bottom.toList();
    final oldIndex = bottom.indexWhere((item) => item.id == module);
    final entry = oldIndex < 0
        ? HdBottomModule(module, 1)
        : bottom.removeAt(oldIndex);
    final target = bottom.indexWhere((item) => item.id == before);
    bottom.insert(target < 0 ? bottom.length : target + (after ? 1 : 0), entry);
    await _setHdSettings(
      _hdSettings.copyWith(
        bottomModules: bottom,
        hiddenModules: _hdSettings.hidden.difference({module}).toList(),
      ),
    );
    return true;
  }

  Future<void> moveHdModuleToSidebar(
    String module, {
    String? target,
    bool after = false,
  }) async {
    if (!HdLayoutSettings.moduleIds.contains(module) || module == target) {
      return;
    }
    final order = _hdSettings.orderedModules.toList()..remove(module);
    final index = order.indexOf(target ?? '');
    order.insert(index < 0 ? order.length : index + (after ? 1 : 0), module);
    await _setHdSettings(
      _hdSettings.copyWith(
        sidebarOrder: order,
        bottomModules: _hdSettings.bottom
            .where((item) => item.id != module)
            .toList(),
        hiddenModules: _hdSettings.hidden.difference({module}).toList(),
      ),
    );
  }

  bool canSetHdModuleSpan(String module, int span) {
    if (span < 1 || span > 3) return false;
    final entries = _hdSettings.bottom.where((item) => item.id == module);
    return entries.isNotEmpty &&
        _hdSettings.usedColumns - entries.first.span + span <= 3;
  }

  Future<bool> setHdModuleSpan(String module, int span) async {
    if (!canSetHdModuleSpan(module, span)) return false;
    await _setHdSettings(
      _hdSettings.copyWith(
        bottomModules: [
          for (final item in _hdSettings.bottom)
            item.id == module ? HdBottomModule(module, span) : item,
        ],
      ),
    );
    return true;
  }

  Future<void> moveHdModuleToSlot(String module, String slot) async {
    final ids = _hdSettings.activeModules;
    final index = slot == 'right' ? 1 : 0;
    await moveHdModuleToBottom(
      module,
      before: index < ids.length ? ids[index] : null,
    );
  }

  Future<void> moveHdModuleBefore(
    String module,
    String target, {
    bool after = false,
  }) => moveHdModuleToSidebar(module, target: target, after: after);

  Future<void> resizeHdModule(String module, {required bool fullWidth}) async {
    await setHdModuleSpan(module, fullWidth ? 3 : 1);
  }

  Future<void> toggleHdModuleHidden(String module) async {
    if (!HdLayoutSettings.moduleIds.contains(module)) return;
    final hidden = _hdSettings.hidden.toSet();
    if (!hidden.remove(module)) hidden.add(module);
    await _setHdSettings(_hdSettings.copyWith(hiddenModules: hidden.toList()));
  }

  Future<void> setHdPortraitSpan(String id, int span) => _setHdSettings(
    _hdSettings.copyWith(
      portraitModules: [
        for (final item in _hdSettings.portrait)
          item.id == id
              ? HdBottomModule(id, span.clamp(1, 2), rows: item.rows)
              : item,
      ],
    ),
  );

  Future<void> placeHdPortraitModules(List<HdBottomModule> modules) =>
      _setHdSettings(_hdSettings.copyWith(portraitModules: modules));

  Future<void> setHdPortraitSize(String id, int rows, int columns) =>
      _setHdSettings(
        _hdSettings.copyWith(
          portraitModules: [
            for (final item in _hdSettings.portrait)
              item.id == id
                  ? HdBottomModule(
                      id,
                      columns.clamp(1, 2),
                      rows: rows.clamp(1, 2),
                    )
                  : item,
          ],
        ),
      );

  Future<void> moveHdPortraitModule(
    String id,
    String? target,
    bool after,
  ) async {
    final items = [
      for (final e in _hdSettings.portrait)
        HdBottomModule(e.id, e.span, rows: e.rows),
    ];
    if (id == target || !items.any((e) => e.id == id)) return;
    final item = items.firstWhere((e) => e.id == id);
    items.removeWhere((e) => e.id == id);
    final index = items.indexWhere((e) => e.id == target);
    items.insert(index < 0 ? items.length : index + (after ? 1 : 0), item);
    await _setHdSettings(_hdSettings.copyWith(portraitModules: items));
  }

  Future<void> toggleHdPortraitHidden(String id) {
    final hidden = {..._hdSettings.portraitHidden};
    if (!hidden.remove(id)) hidden.add(id);
    return _setHdSettings(
      _hdSettings.copyWith(portraitHiddenModules: hidden.toList()),
    );
  }

  Future<void> resetHdPortraitLayout() async {
    await resetAllModuleCapsuleVisibility();
    await _setHdSettings(
      _hdSettings.copyWith(
        portraitModules: [
          for (final id in LayoutSettingsStore.defaultDashboardCardOrder)
            HdBottomModule(id, 2),
        ],
        portraitHiddenModules: const [],
      ),
    );
  }

  Future<void> resetHdLayout() async {
    await resetAllModuleCapsuleVisibility();
    await _setHdSettings(
      HdLayoutSettings(
        enabled: _hdSettings.enabled,
        portraitModules: _hdSettings.portrait,
        portraitHiddenModules: const [],
        bottomModules: const [],
        sidebarOrder: LayoutSettingsStore.defaultDashboardCardOrder,
      ),
    );
  }

  double _gameAreaRatio;
  double _informationPanelWidth;
  bool _autoZoom;
  bool _enhancedDamagePulse;
  bool _workspaceMenuOnRight;
  bool _informationPanelOnLeft = false;
  List<String> _workspaceMenuOrder;
  List<String> _dashboardCardOrder;
  List<String> _dashboardCardCollapsed;
  List<String> _dashboardCardHidden;
  String _fontFamily;
  CustomFontController? _customFontController;
  String? _lastCustomFontFamily;
  String? _localeCode;
  String _systemLocaleCode;
  String _fontLocaleCode;
  FleetMoraleMetricMode _fleetMoraleMetricMode;
  List<String>? _headerResourceOrder;
  List<String>? _visibleHeaderResourceIds;

  double get gameAreaRatio => _gameAreaRatio;
  double get effectiveInformationPanelRatio =>
      _autoZoom ? 0.33 : 1.0 - _gameAreaRatio;
  bool get canAdjustInformationPanelRatio => !_autoZoom;
  double get informationPanelWidth => _informationPanelWidth;
  bool get autoZoom => _autoZoom;
  bool get enhancedDamagePulse => _enhancedDamagePulse;
  String? _workspaceMenuPosition;
  String get workspaceMenuPosition =>
      _workspaceMenuPosition ?? (_workspaceMenuOnRight ? 'right' : 'left');
  bool get workspaceMenuHorizontal =>
      workspaceMenuPosition == 'top' || workspaceMenuPosition == 'bottom';
  bool get workspaceMenuOnRight => _workspaceMenuOnRight;
  Future<void> setWorkspaceMenuPosition(String position) async {
    if (!['top', 'bottom', 'left', 'right'].contains(position) ||
        position == workspaceMenuPosition) {
      return;
    }
    _workspaceMenuPosition = position;
    _workspaceMenuOnRight = position == 'right';
    notifyListeners();
    await _store.saveWorkspaceMenuOnRight(_workspaceMenuOnRight);
    if (_store is WorkspaceMenuPositionStore) {
      await (_store as WorkspaceMenuPositionStore).saveWorkspaceMenuPosition(
        position,
      );
    }
  }

  bool get informationPanelOnLeft => _informationPanelOnLeft;

  Future<void> setInformationPanelOnLeft(bool onLeft) async {
    if (_informationPanelOnLeft == onLeft) return;
    _informationPanelOnLeft = onLeft;
    notifyListeners();
    if (_store is InformationPanelSideSettingsStore) {
      await (_store as InformationPanelSideSettingsStore)
          .saveInformationPanelOnLeft(onLeft);
    }
  }

  List<String> get workspaceMenuOrder =>
      List<String>.unmodifiable(_workspaceMenuOrder);
  List<String> get dashboardCardOrder => _dashboardCardOrder;
  List<String> get dashboardCardCollapsed => _dashboardCardCollapsed;
  List<String> get dashboardCardHidden => _dashboardCardHidden;
  CustomFontController? get customFontController => _customFontController;
  String get defaultFontFamily => _fontFamily;
  String get fontFamily =>
      customFontController?.fontFamily ?? defaultFontFamily;
  String? get localeCode => _localeCode;

  /// Selected language, or the current normalized system language.
  String get effectiveLocaleCode => _localeCode ?? _fontLocaleCode;
  FleetMoraleMetricMode get fleetMoraleMetricMode => _fleetMoraleMetricMode;
  List<String> get headerResourceOrder =>
      List<String>.unmodifiable(_headerResourceOrder ?? allHeaderResourceIds);
  List<String> get visibleHeaderResourceIds => List<String>.unmodifiable(
    _visibleHeaderResourceIds ?? defaultVisibleHeaderResourceIds,
  );
  List<String> get fontFamilyFallback => [
    if (customFontController?.fontFamily != null)
      AppFonts.forLocale(_fontLocaleCode),
    ...AppFonts.fallbackForLocale(_fontLocaleCode),
  ];

  void _handleCustomFontChanged() {
    final family = customFontController?.fontFamily;
    if (_lastCustomFontFamily == family) return;
    _lastCustomFontFamily = family;
    notifyListeners();
  }

  @override
  void dispose() {
    _dashboardDisplayModeDisposed = true;
    _uiFontSizeDisposed = true;
    _cameraAvoidanceDisposed = true;
    _appThemeDisposed = true;
    customFontController?.removeListener(_handleCustomFontChanged);
    super.dispose();
  }

  Future<void> setGameAreaRatio(double ratio) async {
    if (_gameAreaRatio == ratio) {
      return;
    }
    _gameAreaRatio = ratio;
    notifyListeners();
    await _store.saveGameAreaRatio(ratio);
  }

  Future<void> setInformationPanelWidth(double width) async {
    if (_informationPanelWidth == width) {
      return;
    }
    _informationPanelWidth = width;
    notifyListeners();
    await _store.saveInformationPanelWidth(width);
  }

  Future<void> setAutoZoom(bool autoZoom) async {
    if (_autoZoom == autoZoom) {
      return;
    }
    _autoZoom = autoZoom;
    notifyListeners();
    await _store.saveAutoZoom(autoZoom);
  }

  Future<void> setEnhancedDamagePulse(bool enabled) async {
    if (_enhancedDamagePulse == enabled) {
      return;
    }
    _enhancedDamagePulse = enabled;
    notifyListeners();
    await _store.saveEnhancedDamagePulse(enabled);
  }

  Future<void> toggleFleetMoraleMetricMode() async {
    _fleetMoraleMetricMode =
        _fleetMoraleMetricMode == FleetMoraleMetricMode.minimumCondition
        ? FleetMoraleMetricMode.recoveryCountdown
        : FleetMoraleMetricMode.minimumCondition;
    notifyListeners();
    final store = _store is FleetMoraleMetricSettingsStore
        ? _store as FleetMoraleMetricSettingsStore
        : null;
    if (store != null) {
      await store.saveFleetMoraleMetricMode(_fleetMoraleMetricMode);
    }
  }

  Future<void> setWorkspaceMenuOnRight(bool onRight) =>
      setWorkspaceMenuPosition(onRight ? 'right' : 'left');

  Future<void> setWorkspaceMenuOrder(List<String> order) async {
    final normalized = normalizeWorkspaceMenuOrder(order);
    if (listEquals(_workspaceMenuOrder, normalized)) return;
    _workspaceMenuOrder = normalized;
    notifyListeners();
    final store = _store is WorkspaceMenuOrderSettingsStore
        ? _store as WorkspaceMenuOrderSettingsStore
        : null;
    if (store != null) await store.saveWorkspaceMenuOrder(normalized);
  }

  Future<void> reorderWorkspaceMenu(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _workspaceMenuOrder.length) return;
    if (newIndex < 0 || newIndex >= _workspaceMenuOrder.length) {
      return;
    }
    final reordered = List<String>.from(_workspaceMenuOrder);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    await setWorkspaceMenuOrder(reordered);
  }

  Future<void> resetWorkspaceMenuOrder() =>
      setWorkspaceMenuOrder(LayoutSettingsStore.defaultWorkspaceMenuOrder);

  Future<void> setHeaderResourceOrder(List<String> order) async {
    _headerResourceOrder = normalizeHeaderResourceOrder(order);
    notifyListeners();
    final store = _headerResourceStore;
    if (store != null) {
      await store.saveHeaderResourceOrder(_headerResourceOrder!);
    }
  }

  Future<void> toggleHeaderResourceVisible(String id) async {
    if (!allHeaderResourceIds.contains(id)) return;
    final visible = List<String>.from(visibleHeaderResourceIds);
    if (visible.contains(id)) {
      visible.remove(id);
    } else {
      visible.add(id);
    }
    _visibleHeaderResourceIds = visible;
    notifyListeners();
    final store = _headerResourceStore;
    if (store != null) {
      await store.saveVisibleHeaderResourceIds(visible);
    }
  }

  Future<void> resetHeaderResources() async {
    _headerResourceOrder = normalizeHeaderResourceOrder(null);
    _visibleHeaderResourceIds = List<String>.from(
      defaultVisibleHeaderResourceIds,
    );
    notifyListeners();
    final store = _headerResourceStore;
    if (store != null) {
      await Future.wait(<Future<void>>[
        store.saveHeaderResourceOrder(_headerResourceOrder!),
        store.saveVisibleHeaderResourceIds(_visibleHeaderResourceIds!),
      ]);
    }
  }

  HeaderResourceSettingsStore? get _headerResourceStore =>
      _store is HeaderResourceSettingsStore
      ? _store as HeaderResourceSettingsStore
      : null;

  Future<void> setDashboardCardOrder(List<String> order) async {
    _dashboardCardOrder = List<String>.from(order);
    notifyListeners();
    await _store.saveDashboardCardOrder(_dashboardCardOrder);
  }

  Future<void> toggleDashboardCardCollapsed(String id) async {
    final collapsed = List<String>.from(_dashboardCardCollapsed);
    if (collapsed.contains(id)) {
      collapsed.remove(id);
    } else {
      collapsed.add(id);
    }
    _dashboardCardCollapsed = collapsed;
    notifyListeners();
    await _store.saveDashboardCardCollapsed(collapsed);
  }

  Future<void> toggleDashboardCardHidden(String id) async {
    final hidden = List<String>.from(_dashboardCardHidden);
    if (hidden.contains(id)) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    _dashboardCardHidden = hidden;
    notifyListeners();
    await _store.saveDashboardCardHidden(hidden);
  }

  Future<void> resetDashboardCardOrder() async {
    _dashboardCardOrder = List<String>.from(
      LayoutSettingsStore.defaultDashboardCardOrder,
    );
    await resetAllModuleCapsuleVisibility();
    await _store.saveDashboardCardOrder(_dashboardCardOrder);
  }

  Future<void> setFontFamily(String? _) async {
    final fontFamily = AppFonts.forLocale(_fontLocaleCode);
    if (_fontFamily == fontFamily) {
      return;
    }
    _fontFamily = fontFamily;
    notifyListeners();
    await _store.saveFontFamily(fontFamily);
  }

  Future<void> setLocaleCode(String? localeCode) async {
    if (_localeCode == localeCode) {
      return;
    }
    _localeCode = localeCode;
    _fontLocaleCode = localeCode ?? _systemLocaleCode;
    _fontFamily = AppFonts.forLocale(_fontLocaleCode);
    notifyListeners();
    await _store.saveLocaleCode(localeCode);
    await _store.saveFontFamily(_fontFamily);
  }

  void updateSystemLocaleCode(String localeCode) {
    if (_systemLocaleCode == localeCode) return;
    _systemLocaleCode = localeCode;
    if (_localeCode != null) return;
    _fontLocaleCode = localeCode;
    _fontFamily = AppFonts.forLocale(localeCode);
    notifyListeners();
  }
}

List<String> reorderDashboardCards(
  List<String> cards,
  int oldIndex,
  int newIndex,
) {
  final reordered = List<String>.from(cards);
  final item = reordered.removeAt(oldIndex);
  reordered.insert(newIndex.clamp(0, reordered.length), item);
  return reordered;
}
