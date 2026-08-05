import 'package:flutter/foundation.dart';

import 'layout_settings_store.dart';

class LayoutSettingsController extends ChangeNotifier {
  LayoutSettingsController._(
    this._store,
    this._gameAreaRatio,
    this._informationPanelWidth,
    this._autoZoom,
    this._dashboardCardOrder,
    this._dashboardCardCollapsed,
    this._dashboardCardHidden,
    this._fontFamily,
    this._localeCode,
    this._fontLocaleCode,
  );

  static Future<LayoutSettingsController> load(
    LayoutSettingsStore store, {
    String? systemLocaleCode,
  }) async {
    final ratio = await store.loadGameAreaRatio();
    final width = await store.loadInformationPanelWidth();
    final autoZoom = await store.loadAutoZoom();
    final dashboardCardOrder = await store.loadDashboardCardOrder();
    final dashboardCardCollapsed = await store.loadDashboardCardCollapsed();
    final dashboardCardHidden = await store.loadDashboardCardHidden();
    final fontFamily = await store.loadFontFamily();
    final localeCode = await store.loadLocaleCode();
    final fontLocaleCode = localeCode ?? systemLocaleCode ?? 'zh';
    final regionalFont = _fontForLocale(fontLocaleCode);
    if (fontFamily != null && fontFamily != regionalFont) {
      await store.saveFontFamily(regionalFont);
    }
    return LayoutSettingsController._(
      store,
      ratio,
      width,
      autoZoom,
      dashboardCardOrder,
      dashboardCardCollapsed,
      dashboardCardHidden,
      fontFamily == null ? null : regionalFont,
      localeCode,
      fontLocaleCode,
    );
  }

  final LayoutSettingsStore _store;

  double _gameAreaRatio;
  double _informationPanelWidth;
  bool _autoZoom;
  List<String> _dashboardCardOrder;
  List<String> _dashboardCardCollapsed;
  List<String> _dashboardCardHidden;
  String? _fontFamily;
  String? _localeCode;
  String _fontLocaleCode;

  double get gameAreaRatio => _gameAreaRatio;
  double get informationPanelWidth => _informationPanelWidth;
  bool get autoZoom => _autoZoom;
  List<String> get dashboardCardOrder => _dashboardCardOrder;
  List<String> get dashboardCardCollapsed => _dashboardCardCollapsed;
  List<String> get dashboardCardHidden => _dashboardCardHidden;
  String? get fontFamily => _fontFamily;
  String? get localeCode => _localeCode;
  List<String> get fontFamilyFallback => switch (_fontLocaleCode) {
    'ja' => const <String>['HarmonyOS_Sans_TC', 'HarmonyOS_Sans_SC'],
    'zh_Hant' => const <String>['NotoSansJP', 'HarmonyOS_Sans_SC'],
    _ => const <String>['HarmonyOS_Sans_TC', 'NotoSansJP'],
  };

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

  Future<void> setFontFamily(String? fontFamily) async {
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
    _fontLocaleCode = localeCode ?? 'zh';
    _fontFamily = _fontForLocale(_fontLocaleCode);
    notifyListeners();
    await _store.saveLocaleCode(localeCode);
    await _store.saveFontFamily(_fontFamily);
  }
}

String _fontForLocale(String localeCode) => switch (localeCode) {
  'ja' => 'NotoSansJP',
  'zh_Hant' => 'HarmonyOS_Sans_TC',
  _ => 'HarmonyOS_Sans_SC',
};
