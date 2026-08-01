import 'package:shared_preferences/shared_preferences.dart';

abstract class LayoutSettingsStore {
  Future<double> loadGameAreaRatio();
  Future<void> saveGameAreaRatio(double ratio);

  Future<double> loadInformationPanelWidth();
  Future<void> saveInformationPanelWidth(double width);

  Future<bool> loadAutoZoom();
  Future<void> saveAutoZoom(bool autoZoom);

  Future<List<String>> loadDashboardCardOrder();
  Future<void> saveDashboardCardOrder(List<String> order);

  Future<List<String>> loadDashboardCardCollapsed();
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds);

  Future<String?> loadFontFamily();
  Future<void> saveFontFamily(String? fontFamily);

  Future<String?> loadLocaleCode();
  Future<void> saveLocaleCode(String? localeCode);
}

class SharedPreferencesLayoutSettingsStore implements LayoutSettingsStore {
  static const _keyGameAreaRatio = 'layout_game_area_ratio';
  static const _keyInformationPanelWidth = 'layout_information_panel_width';
  static const _keyAutoZoom = 'layout_auto_zoom';

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

  static const _keyDashboardCardOrder = 'layout_dashboard_card_order';
  static const _keyDashboardCardCollapsed = 'layout_dashboard_card_collapsed';

  static const _defaultDashboardCardOrder = <String>[
    'fleet',
    'expedition',
    'repair',
    'construction',
    'quests',
    'battle',
    'pre_sortie',
  ];

  @override
  Future<List<String>> loadDashboardCardOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyDashboardCardOrder);
    if (list != null && list.isNotEmpty) {
      // Ensure all default keys are present in case we added new ones
      for (final key in _defaultDashboardCardOrder) {
        if (!list.contains(key)) list.add(key);
      }
      return list;
    }
    return List<String>.from(_defaultDashboardCardOrder);
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

  static const _keyFontFamily = 'layout_font_family';

  @override
  Future<String?> loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to HarmonyOS_Sans_SC, but if they specifically want system font, they might set it to empty string or 'system'.
    // We'll use 'system' for system font, and 'HarmonyOS_Sans_SC' for the custom one.
    if (!prefs.containsKey(_keyFontFamily)) {
      return 'HarmonyOS_Sans_SC';
    }
    final value = prefs.getString(_keyFontFamily);
    return value == 'system' ? null : value;
  }

  @override
  Future<void> saveFontFamily(String? fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, fontFamily ?? 'system');
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
