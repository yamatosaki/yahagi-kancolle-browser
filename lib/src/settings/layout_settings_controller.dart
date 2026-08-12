import 'package:flutter/foundation.dart';

import 'header_resource_settings.dart';
import 'layout_settings_store.dart';

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
    this._fontLocaleCode,
  );

  static Future<LayoutSettingsController> load(
    LayoutSettingsStore store, {
    String? systemLocaleCode,
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
    final fontLocaleCode = localeCode ?? systemLocaleCode ?? 'zh';
    final regionalFont = _fontForLocale(fontLocaleCode);
    if (fontFamily != null && fontFamily != regionalFont) {
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
      fontFamily == null ? null : regionalFont,
      localeCode,
      fontLocaleCode,
    );
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
      if (migratesSenka || migratesAnchorageTimer) {
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
    return controller;
  }

  final LayoutSettingsStore _store;

  double _gameAreaRatio;
  double _informationPanelWidth;
  bool _autoZoom;
  bool _enhancedDamagePulse;
  bool _workspaceMenuOnRight;
  List<String> _workspaceMenuOrder;
  List<String> _dashboardCardOrder;
  List<String> _dashboardCardCollapsed;
  List<String> _dashboardCardHidden;
  String? _fontFamily;
  String? _localeCode;
  String _fontLocaleCode;
  List<String>? _headerResourceOrder;
  List<String>? _visibleHeaderResourceIds;

  double get gameAreaRatio => _gameAreaRatio;
  double get effectiveInformationPanelRatio =>
      _autoZoom ? 0.35 : 1.0 - _gameAreaRatio;
  bool get canAdjustInformationPanelRatio => !_autoZoom;
  double get informationPanelWidth => _informationPanelWidth;
  bool get autoZoom => _autoZoom;
  bool get enhancedDamagePulse => _enhancedDamagePulse;
  bool get workspaceMenuOnRight => _workspaceMenuOnRight;
  List<String> get workspaceMenuOrder =>
      List<String>.unmodifiable(_workspaceMenuOrder);
  List<String> get dashboardCardOrder => _dashboardCardOrder;
  List<String> get dashboardCardCollapsed => _dashboardCardCollapsed;
  List<String> get dashboardCardHidden => _dashboardCardHidden;
  String? get fontFamily => _fontFamily;
  String? get localeCode => _localeCode;
  List<String> get headerResourceOrder =>
      List<String>.unmodifiable(_headerResourceOrder ?? allHeaderResourceIds);
  List<String> get visibleHeaderResourceIds => List<String>.unmodifiable(
    _visibleHeaderResourceIds ?? defaultVisibleHeaderResourceIds,
  );
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

  Future<void> setEnhancedDamagePulse(bool enabled) async {
    if (_enhancedDamagePulse == enabled) {
      return;
    }
    _enhancedDamagePulse = enabled;
    notifyListeners();
    await _store.saveEnhancedDamagePulse(enabled);
  }

  Future<void> setWorkspaceMenuOnRight(bool onRight) async {
    if (_workspaceMenuOnRight == onRight) return;
    _workspaceMenuOnRight = onRight;
    notifyListeners();
    await _store.saveWorkspaceMenuOnRight(onRight);
  }

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
    _headerResourceOrder = List<String>.from(allHeaderResourceIds);
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
    notifyListeners();
    await _store.saveDashboardCardOrder(_dashboardCardOrder);
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

String _fontForLocale(String localeCode) => switch (localeCode) {
  'ja' => 'NotoSansJP',
  'zh_Hant' => 'HarmonyOS_Sans_TC',
  _ => 'HarmonyOS_Sans_SC',
};
