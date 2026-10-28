import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'header_resource_settings.dart';
import 'workspace_menu_settings.dart';
import 'module_display_settings.dart';
import 'fleet_display_options.dart';
import 'hd_layout_settings.dart';
import 'camera_avoidance_settings.dart';
import 'ui_font_size.dart';
import 'dashboard_display_mode.dart';

enum FleetMoraleMetricMode { minimumCondition, recoveryCountdown }

abstract class LayoutSettingsStore {
  Future<double> loadGameAreaRatio();
  Future<void> saveGameAreaRatio(double ratio);

  Future<double> loadInformationPanelWidth();
  Future<void> saveInformationPanelWidth(double width);

  Future<bool> loadAutoZoom();
  Future<void> saveAutoZoom(bool autoZoom);

  Future<bool> loadEnhancedDamagePulse();
  Future<void> saveEnhancedDamagePulse(bool enabled);

  Future<bool> loadWorkspaceMenuOnRight();
  Future<void> saveWorkspaceMenuOnRight(bool onRight);

  static const defaultWorkspaceMenuOrder = <String>[
    'game',
    'fleet',
    'expedition',
    'repair',
    'construction',
    'quests',
    'senka',
    'battle-records',
    'owned-inventory',
    'tools',
    'settings',
  ];

  Future<List<String>> loadDashboardCardOrder();
  Future<void> saveDashboardCardOrder(List<String> order);

  static const defaultDashboardCardOrder = <String>[
    'battle',
    'fleet',
    'land_base',
    'expedition',
    'repair',
    'construction',
    'quests',
    'pre_sortie',
  ];

  Future<List<String>> loadDashboardCardCollapsed();
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds);

  Future<List<String>> loadDashboardCardHidden();
  Future<void> saveDashboardCardHidden(List<String> hiddenIds);

  Future<String?> loadFontFamily();
  Future<void> saveFontFamily(String? fontFamily);

  Future<String?> loadLocaleCode();
  Future<void> saveLocaleCode(String? localeCode);
}

abstract interface class InformationPanelSideSettingsStore {
  Future<bool> loadInformationPanelOnLeft();
  Future<void> saveInformationPanelOnLeft(bool onLeft);
}

abstract interface class DashboardDisplayModeSettingsStore {
  Future<DashboardDisplayMode> loadDashboardDisplayMode();
  Future<void> saveDashboardDisplayMode(DashboardDisplayMode mode);
}

abstract interface class WorkspaceMenuOrderSettingsStore {
  Future<List<String>> loadWorkspaceMenuOrder();
  Future<void> saveWorkspaceMenuOrder(List<String> order);
}

abstract interface class HeaderResourceSettingsStore {
  Future<List<String>> loadHeaderResourceOrder();
  Future<void> saveHeaderResourceOrder(List<String> order);
  Future<List<String>?> loadVisibleHeaderResourceIds();
  Future<void> saveVisibleHeaderResourceIds(List<String> visibleIds);
}

abstract interface class FleetDisplaySettingsStore {
  Future<List<String>?> loadFleetDisplayFields();
  Future<void> saveFleetDisplayFields(List<String> fields);
  Future<FleetShipTypeLabelMode> loadFleetShipTypeLabelMode();
  Future<void> saveFleetShipTypeLabelMode(FleetShipTypeLabelMode mode);
  Future<FleetSelectorLabelMode> loadFleetSelectorLabelMode();
  Future<void> saveFleetSelectorLabelMode(FleetSelectorLabelMode mode);
  Future<bool> loadShowClearedMaps();
  Future<void> saveShowClearedMaps(bool show);
}

abstract interface class FleetMoraleMetricSettingsStore {
  Future<FleetMoraleMetricMode> loadFleetMoraleMetricMode();
  Future<void> saveFleetMoraleMetricMode(FleetMoraleMetricMode mode);
}

abstract interface class WorkspaceMenuPositionStore {
  Future<String?> loadWorkspaceMenuPosition();
  Future<void> saveWorkspaceMenuPosition(String position);
}

abstract interface class UiDisplaySizeSettingsStore {
  Future<UiDisplaySize> loadUiDisplaySize();
  Future<void> saveUiDisplaySize(UiDisplaySize size);
}

abstract interface class UiFontSizeSettingsStore {
  Future<UiFontSize> loadUiFontSize();
  Future<void> saveUiFontSize(UiFontSize size);
}

abstract interface class HeaderUiSizeSettingsStore {
  Future<HeaderUiSize> loadHeaderUiSize();
  Future<void> saveHeaderUiSize(HeaderUiSize size);
}

abstract interface class WorkspaceMenuSizeSettingsStore {
  Future<WorkspaceMenuSize> loadWorkspaceMenuSize();
  Future<void> saveWorkspaceMenuSize(WorkspaceMenuSize size);
}

abstract interface class MinimalResourcePositionSettingsStore {
  Future<MinimalResourcePosition> loadMinimalResourcePosition();
  Future<void> saveMinimalResourcePosition(MinimalResourcePosition position);
}

abstract interface class MinimalCollapsedResourceSettingsStore {
  Future<List<String>?> loadCollapsedPanelResourceIds();
  Future<void> saveCollapsedPanelResourceIds(List<String>? ids);
}

abstract interface class UiLockSettingsStore {
  Future<bool> loadUiLocked();
  Future<void> saveUiLocked(bool locked);
}

abstract interface class AppThemeSettingsStore {
  Future<AppThemeMode> loadAppThemeMode();
  Future<void> saveAppThemeMode(AppThemeMode mode);
}

abstract interface class CameraAvoidanceSettingsStore {
  Future<CameraAvoidanceSettings> loadCameraAvoidanceSettings();
  Future<void> saveCameraAvoidanceSettings(CameraAvoidanceSettings settings);
}

abstract interface class TopNoticeSettingsStore {
  Future<bool> loadTopNoticeEnabled();
  Future<void> saveTopNoticeEnabled(bool enabled);
  Future<int> loadTopNoticeDurationSeconds();
  Future<void> saveTopNoticeDurationSeconds(int seconds);
}

class SharedPreferencesLayoutSettingsStore
    implements
        LayoutSettingsStore,
        DashboardDisplayModeSettingsStore,
        ModuleDisplaySettingsStore,
        FleetDisplaySettingsStore,
        FleetMoraleMetricSettingsStore,
        HeaderResourceSettingsStore,
        UiDisplaySizeSettingsStore,
        UiFontSizeSettingsStore,
        MinimalResourcePositionSettingsStore,
        MinimalCollapsedResourceSettingsStore,
        HeaderUiSizeSettingsStore,
        WorkspaceMenuSizeSettingsStore,
        WorkspaceMenuOrderSettingsStore,
        HdLayoutSettingsStore,
        InformationPanelSideSettingsStore,
        WorkspaceMenuPositionStore,
        TopNoticeSettingsStore,
        AppThemeSettingsStore,
        CameraAvoidanceSettingsStore,
        UiLockSettingsStore {
  static const _dashboardDisplayModeKey = 'layout_dashboard_display_mode';

  @override
  Future<DashboardDisplayMode> loadDashboardDisplayMode() async {
    final saved = (await SharedPreferences.getInstance()).get(
      _dashboardDisplayModeKey,
    );
    return DashboardDisplayMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => DashboardDisplayMode.accordion,
    );
  }

  @override
  Future<void> saveDashboardDisplayMode(DashboardDisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.get(_dashboardDisplayModeKey);
    try {
      if (!await prefs.setString(_dashboardDisplayModeKey, mode.name)) {
        throw StateError('Briefing display preference was not saved');
      }
    } catch (_) {
      // Match the cache to the last confirmed platform write.
      try {
        if (previous is String) {
          await prefs.setString(_dashboardDisplayModeKey, previous);
        } else {
          await prefs.remove(_dashboardDisplayModeKey);
        }
      } catch (_) {}
      rethrow;
    }
  }

  static const _cameraAvoidanceKey = 'layout_camera_avoidance_v1';

  @override
  Future<CameraAvoidanceSettings> loadCameraAvoidanceSettings() async {
    final raw = (await SharedPreferences.getInstance()).get(
      _cameraAvoidanceKey,
    );
    return CameraAvoidanceSettings.decode(raw is String ? raw : null);
  }

  @override
  Future<void> saveCameraAvoidanceSettings(
    CameraAvoidanceSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.get(_cameraAvoidanceKey);
    try {
      if (!await prefs.setString(_cameraAvoidanceKey, settings.encode())) {
        throw StateError('Camera avoidance preference was not saved');
      }
    } catch (_) {
      // SharedPreferences changes its cache before the platform write completes.
      // Restore that cache so newly loaded controllers see confirmed settings.
      try {
        if (previous is String) {
          await prefs.setString(_cameraAvoidanceKey, previous);
        } else {
          await prefs.remove(_cameraAvoidanceKey);
        }
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<String?> loadWorkspaceMenuPosition() async =>
      (await SharedPreferences.getInstance()).getString(
        'layout_workspace_menu_position',
      );
  @override
  Future<void> saveWorkspaceMenuPosition(String position) async {
    await (await SharedPreferences.getInstance()).setString(
      'layout_workspace_menu_position',
      position,
    );
  }

  @override
  Future<HdLayoutSettings> loadHdLayoutSettings() async =>
      HdLayoutSettings.decode(
        (await SharedPreferences.getInstance()).getString('hd_layout_v1'),
      );

  @override
  Future<void> saveHdLayoutSettings(HdLayoutSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(
      'hd_layout_v1',
      settings.encode(),
    );
  }

  @override
  Future<List<String>?> loadModuleDisplayFields(String module) async {
    final prefs = await SharedPreferences.getInstance();
    if (module == 'expedition') {
      final current = prefs.getStringList('module_display_expedition_v2');
      if (current != null) return current;
      final old = prefs.getStringList('module_display_expedition');
      return old == null ? null : {...old, 'time'}.toList();
    }
    return prefs.getStringList('module_display_$module');
  }

  @override
  Future<void> saveModuleDisplayFields(
    String module,
    List<String> fields,
  ) async {
    await (await SharedPreferences.getInstance()).setStringList(
      module == 'expedition'
          ? 'module_display_expedition_v2'
          : 'module_display_$module',
      fields,
    );
  }

  @override
  Future<bool> loadModuleShowLogo(String module) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('module_capsule_logo_$module') ?? true;
  }

  @override
  Future<void> saveModuleShowLogo(String module, bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('module_capsule_logo_$module', show);
  }

  @override
  Future<bool> loadModuleShowName(String module) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('module_capsule_name_$module') ?? true;
  }

  @override
  Future<void> saveModuleShowName(String module, bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('module_capsule_name_$module', show);
  }

  @override
  Future<List<String>?> loadFleetDisplayFields() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('fleet_brief_display_fields_v2');
    if (current != null) return current;
    final old = prefs.getStringList('fleet_brief_display_fields_v1');
    return old == null ? null : {...old, 'hp'}.toList();
  }

  @override
  Future<void> saveFleetDisplayFields(List<String> fields) async {
    await (await SharedPreferences.getInstance()).setStringList(
      'fleet_brief_display_fields_v2',
      fields,
    );
  }

  static const _keyFleetShipTypeLabelMode = 'fleet_brief_ship_type_label_mode';
  static const _keyFleetSelectorLabelMode = 'fleet_brief_selector_label_mode';
  static const _keyRepairFleetSelectorLabelMode =
      'repair_summary_selector_label_mode';
  static const _keyShowClearedMaps = 'pre_sortie_show_cleared_maps';

  @override
  Future<FleetShipTypeLabelMode> loadFleetShipTypeLabelMode() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _keyFleetShipTypeLabelMode,
    );
    return FleetShipTypeLabelMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => FleetShipTypeLabelMode.localizedName,
    );
  }

  @override
  Future<void> saveFleetShipTypeLabelMode(FleetShipTypeLabelMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      _keyFleetShipTypeLabelMode,
      mode.name,
    );
  }

  @override
  Future<FleetSelectorLabelMode> loadFleetSelectorLabelMode() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _keyFleetSelectorLabelMode,
    );
    return FleetSelectorLabelMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => FleetSelectorLabelMode.customName,
    );
  }

  @override
  Future<void> saveFleetSelectorLabelMode(FleetSelectorLabelMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      _keyFleetSelectorLabelMode,
      mode.name,
    );
  }

  @override
  Future<FleetSelectorLabelMode> loadRepairFleetSelectorLabelMode() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _keyRepairFleetSelectorLabelMode,
    );
    return FleetSelectorLabelMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => FleetSelectorLabelMode.customName,
    );
  }

  @override
  Future<void> saveRepairFleetSelectorLabelMode(
    FleetSelectorLabelMode mode,
  ) async {
    await (await SharedPreferences.getInstance()).setString(
      _keyRepairFleetSelectorLabelMode,
      mode.name,
    );
  }

  @override
  Future<bool> loadShowClearedMaps() async =>
      (await SharedPreferences.getInstance()).getBool(_keyShowClearedMaps) ??
      false;

  @override
  Future<void> saveShowClearedMaps(bool show) async {
    await (await SharedPreferences.getInstance()).setBool(
      _keyShowClearedMaps,
      show,
    );
  }

  static const _keyInformationPanelOnLeft = 'layout_information_panel_on_left';

  @override
  Future<bool> loadInformationPanelOnLeft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInformationPanelOnLeft) ?? false;
  }

  @override
  Future<void> saveInformationPanelOnLeft(bool onLeft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInformationPanelOnLeft, onLeft);
  }

  static const _keyGameAreaRatio = 'layout_game_area_ratio';
  static const _keyInformationPanelWidth = 'layout_information_panel_width';
  static const _keyAutoZoom = 'layout_auto_zoom';
  static const _keyEnhancedDamagePulse = 'layout_enhanced_damage_pulse';
  static const _keyWorkspaceMenuOnRight = 'layout_workspace_menu_on_right';
  static const _keyWorkspaceMenuOrder = 'layout_workspace_menu_order';
  static const _keyHeaderResourceOrder = 'layout_header_resource_order';
  static const _keyVisibleHeaderResourceIds =
      'layout_visible_header_resource_ids';
  static const _keyUiDisplaySize = 'layout_ui_display_size';
  static const _keyUiFontSize = 'layout_ui_font_size';
  static const _keyHeaderUiSize = 'layout_header_ui_size';
  static const _keyWorkspaceMenuSize = 'layout_workspace_menu_size';
  static const _keyFleetMoraleMetricMode = 'layout_fleet_morale_metric_mode';

  @override
  Future<UiFontSize> loadUiFontSize() async {
    final saved = (await SharedPreferences.getInstance()).get(_keyUiFontSize);
    return UiFontSize.values.firstWhere(
      (size) => size.name == saved,
      orElse: () => UiFontSize.system,
    );
  }

  @override
  Future<void> saveUiFontSize(UiFontSize size) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.get(_keyUiFontSize);
    try {
      if (!await prefs.setString(_keyUiFontSize, size.name)) {
        throw StateError('UI font size preference was not saved');
      }
    } catch (_) {
      // The Dart cache updates before the platform write is confirmed.
      try {
        if (previous is String) {
          await prefs.setString(_keyUiFontSize, previous);
        } else {
          await prefs.remove(_keyUiFontSize);
        }
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<UiDisplaySize> loadUiDisplaySize() async {
    final prefs = await SharedPreferences.getInstance();
    final direct = prefs.getString(_keyUiDisplaySize);
    if (direct != null) {
      return UiDisplaySize.values.firstWhere(
        (size) => size.name == direct,
        orElse: () => UiDisplaySize.normal,
      );
    }
    final legacyHeader = prefs.getString(_keyHeaderUiSize);
    final legacyMenu = prefs.getString(_keyWorkspaceMenuSize);
    if (legacyHeader == UiDisplaySize.compact.name ||
        legacyMenu == UiDisplaySize.compact.name) {
      return UiDisplaySize.compact;
    }
    if (legacyHeader == UiDisplaySize.normal.name ||
        legacyMenu == UiDisplaySize.normal.name) {
      return UiDisplaySize.normal;
    }
    return UiDisplaySize.normal;
  }

  @override
  Future<void> saveUiDisplaySize(UiDisplaySize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUiDisplaySize, size.name);
    await prefs.setString(_keyHeaderUiSize, size.name);
    await prefs.setString(_keyWorkspaceMenuSize, size.name);
  }

  @override
  Future<HeaderUiSize> loadHeaderUiSize() => loadUiDisplaySize();

  @override
  Future<void> saveHeaderUiSize(HeaderUiSize size) => saveUiDisplaySize(size);

  @override
  Future<WorkspaceMenuSize> loadWorkspaceMenuSize() => loadUiDisplaySize();

  @override
  Future<void> saveWorkspaceMenuSize(WorkspaceMenuSize size) =>
      saveUiDisplaySize(size);

  @override
  Future<FleetMoraleMetricMode> loadFleetMoraleMetricMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyFleetMoraleMetricMode);
    return FleetMoraleMetricMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => FleetMoraleMetricMode.minimumCondition,
    );
  }

  @override
  Future<void> saveFleetMoraleMetricMode(FleetMoraleMetricMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFleetMoraleMetricMode, mode.name);
  }

  @override
  Future<List<String>> loadHeaderResourceOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyHeaderResourceOrder) ?? const <String>[];
  }

  @override
  Future<void> saveHeaderResourceOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHeaderResourceOrder,
      normalizeHeaderResourceOrder(order),
    );
  }

  @override
  Future<List<String>?> loadVisibleHeaderResourceIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyVisibleHeaderResourceIds)) return null;
    return normalizeVisibleHeaderResourceIds(
      prefs.getStringList(_keyVisibleHeaderResourceIds),
    );
  }

  @override
  Future<void> saveVisibleHeaderResourceIds(List<String> visibleIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyVisibleHeaderResourceIds,
      normalizeVisibleHeaderResourceIds(visibleIds),
    );
  }

  @override
  Future<double> loadGameAreaRatio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyGameAreaRatio) ?? 0.65;
  }

  @override
  Future<void> saveGameAreaRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGameAreaRatio, ratio);
  }

  @override
  Future<double> loadInformationPanelWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyInformationPanelWidth) ?? 390.0;
  }

  @override
  Future<void> saveInformationPanelWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyInformationPanelWidth, width);
  }

  @override
  Future<bool> loadAutoZoom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoZoom) ?? true;
  }

  @override
  Future<void> saveAutoZoom(bool autoZoom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoZoom, autoZoom);
  }

  @override
  Future<bool> loadEnhancedDamagePulse() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnhancedDamagePulse) ?? true;
  }

  @override
  Future<void> saveEnhancedDamagePulse(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnhancedDamagePulse, enabled);
  }

  @override
  Future<bool> loadWorkspaceMenuOnRight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWorkspaceMenuOnRight) ?? false;
  }

  @override
  Future<void> saveWorkspaceMenuOnRight(bool onRight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWorkspaceMenuOnRight, onRight);
  }

  @override
  Future<List<String>> loadWorkspaceMenuOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeWorkspaceMenuOrder(
      prefs.getStringList(_keyWorkspaceMenuOrder),
    );
  }

  @override
  Future<void> saveWorkspaceMenuOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyWorkspaceMenuOrder,
      normalizeWorkspaceMenuOrder(order),
    );
  }

  static const _keyDashboardCardOrder = 'layout_dashboard_card_order';
  static const _keyDashboardCardCollapsed = 'layout_dashboard_card_collapsed';

  @override
  Future<List<String>> loadDashboardCardOrder() async {
    final prefs = await SharedPreferences.getInstance();
    // Module IDs also identify tab pages, so legacy duplicates must not create
    // multiple pages with the same key. Keep the first saved position.
    final list = prefs.getStringList(_keyDashboardCardOrder)?.toSet().toList();
    if (list != null && list.isNotEmpty) {
      // Ensure all default keys are present in case we added new ones
      for (final key in LayoutSettingsStore.defaultDashboardCardOrder) {
        if (list.contains(key)) continue;
        if (key == 'land_base' && list.contains('fleet')) {
          list.insert(list.indexOf('fleet') + 1, key);
        } else {
          list.add(key);
        }
      }
      // Remove any keys that are no longer supported (e.g. expedition_check)
      list.removeWhere(
        (key) => !LayoutSettingsStore.defaultDashboardCardOrder.contains(key),
      );
      return list;
    }
    return List<String>.from(LayoutSettingsStore.defaultDashboardCardOrder);
  }

  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDashboardCardOrder, order);
  }

  @override
  Future<List<String>> loadDashboardCardCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyDashboardCardCollapsed) ?? <String>[];
  }

  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDashboardCardCollapsed, collapsedIds);
  }

  static const _keyDashboardCardHidden = 'layout_dashboard_card_hidden';

  @override
  Future<List<String>> loadDashboardCardHidden() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyDashboardCardHidden) ?? <String>[];
  }

  @override
  Future<void> saveDashboardCardHidden(List<String> hiddenIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDashboardCardHidden, hiddenIds);
  }

  static const _keyFontFamily = 'layout_font_family';

  @override
  Future<String?> loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyFontFamily)) {
      return AppFonts.simplifiedChinese;
    }
    final value = prefs.getString(_keyFontFamily);
    return value == null || value == 'system'
        ? AppFonts.simplifiedChinese
        : value;
  }

  @override
  Future<void> saveFontFamily(String? fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFontFamily,
      fontFamily ?? AppFonts.simplifiedChinese,
    );
  }

  static const _keyLocaleCode = 'layout_locale_code';

  @override
  Future<String?> loadLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocaleCode);
  }

  @override
  Future<void> saveLocaleCode(String? localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (localeCode == null) {
      await prefs.remove(_keyLocaleCode);
    } else {
      await prefs.setString(_keyLocaleCode, localeCode);
    }
  }

  static const _keyTopNoticeEnabled = 'top_notice_enabled';
  static const _keyTopNoticeDuration = 'top_notice_duration_sec';

  @override
  Future<bool> loadTopNoticeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTopNoticeEnabled) ?? true;
  }

  @override
  Future<void> saveTopNoticeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTopNoticeEnabled, enabled);
  }

  static const _keyMinimalResourcePosition = 'layout_minimal_resource_position';

  @override
  Future<MinimalResourcePosition> loadMinimalResourcePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyMinimalResourcePosition);
    return MinimalResourcePosition.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => MinimalResourcePosition.panel,
    );
  }

  @override
  Future<void> saveMinimalResourcePosition(
    MinimalResourcePosition position,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMinimalResourcePosition, position.name);
  }

  static const _keyMinimalCollapsedResourceIds =
      'layout_minimal_collapsed_resource_ids';

  @override
  Future<List<String>?> loadCollapsedPanelResourceIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyMinimalCollapsedResourceIds);
  }

  @override
  Future<void> saveCollapsedPanelResourceIds(List<String>? ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids == null) {
      await prefs.remove(_keyMinimalCollapsedResourceIds);
    } else {
      await prefs.setStringList(_keyMinimalCollapsedResourceIds, ids);
    }
  }

  static const _keyUiLocked = 'layout_ui_locked';
  static const _keyAppThemeMode = 'app_theme_mode';

  @override
  Future<AppThemeMode> loadAppThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.get(_keyAppThemeMode);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => AppThemeMode.dark,
    );
  }

  @override
  Future<void> saveAppThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.get(_keyAppThemeMode);
    try {
      if (!await prefs.setString(_keyAppThemeMode, mode.name)) {
        throw StateError('Appearance preference was not saved');
      }
    } catch (_) {
      // SharedPreferences updates its Dart cache before the platform finishes.
      // Keep new controllers aligned with the last confirmed preference.
      try {
        if (previous is String) {
          await prefs.setString(_keyAppThemeMode, previous);
        } else {
          await prefs.remove(_keyAppThemeMode);
        }
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<bool> loadUiLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUiLocked) ?? false;
  }

  @override
  Future<void> saveUiLocked(bool locked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUiLocked, locked);
  }

  @override
  Future<int> loadTopNoticeDurationSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTopNoticeDuration) ?? 5;
  }

  @override
  Future<void> saveTopNoticeDurationSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTopNoticeDuration, seconds);
  }
}

List<String> normalizeWorkspaceMenuOrder(Iterable<String>? savedOrder) {
  final normalized = <String>[];
  final known = LayoutSettingsStore.defaultWorkspaceMenuOrder.toSet();
  for (final id in savedOrder ?? const <String>[]) {
    if (known.contains(id) && !normalized.contains(id)) {
      normalized.add(id);
    }
  }
  if (!normalized.contains('tools')) {
    final settingsIndex = normalized.indexOf('settings');
    if (settingsIndex >= 0) {
      normalized.insert(settingsIndex, 'tools');
    }
  }
  for (final id in LayoutSettingsStore.defaultWorkspaceMenuOrder) {
    if (!normalized.contains(id)) normalized.add(id);
  }
  return normalized;
}
