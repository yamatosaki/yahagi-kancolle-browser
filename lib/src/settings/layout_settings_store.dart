import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_fonts.dart';
import 'header_resource_settings.dart';
import 'module_display_settings.dart';

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
}

abstract interface class FleetMoraleMetricSettingsStore {
  Future<FleetMoraleMetricMode> loadFleetMoraleMetricMode();
  Future<void> saveFleetMoraleMetricMode(FleetMoraleMetricMode mode);
}

class SharedPreferencesLayoutSettingsStore
    implements
        LayoutSettingsStore,
        ModuleDisplaySettingsStore,
        FleetDisplaySettingsStore,
        FleetMoraleMetricSettingsStore,
        HeaderResourceSettingsStore,
        WorkspaceMenuOrderSettingsStore,
        InformationPanelSideSettingsStore {
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
  static const _keyFleetMoraleMetricMode = 'layout_fleet_morale_metric_mode';

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
    final list = prefs.getStringList(_keyDashboardCardOrder);
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
