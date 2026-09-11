import 'package:flutter/foundation.dart';

import '../theme/app_fonts.dart';
import 'header_resource_settings.dart';
import 'fleet_display_options.dart';
import 'module_display_settings.dart';
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
    this._fleetMoraleMetricMode,
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
      fontLocaleCode,
      fleetMoraleMetricMode,
    );
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
          migratesEquipmentCapacity) {
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
      final saved = await (store as FleetDisplaySettingsStore)
          .loadFleetDisplayFields();
      controller._fleetDisplayFields = normalizeDisplayFields(
        saved ?? defaultFields,
      );
      if (saved == null &&
          fleetMoraleMetricMode == FleetMoraleMetricMode.recoveryCountdown) {
        controller._fleetDisplayFields = {...controller._fleetDisplayFields}
          ..remove('minimum-condition')
          ..add('recovery-countdown');
      }
    }
    if (store is ModuleDisplaySettingsStore) {
      for (final module in moduleDisplayOptions.keys) {
        final saved = await (store as ModuleDisplaySettingsStore)
            .loadModuleDisplayFields(module);
        if (saved != null) {
          controller._moduleDisplayFields[module] = saved.toSet().intersection(
            moduleDisplayOptions[module]!.keys.toSet(),
          );
        }
      }
    }
    controller._expeditionCountdownConfigured = true;
    controller._fleetDisplayFieldsLoaded = true;
    return controller;
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

  final LayoutSettingsStore _store;

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
  String? _localeCode;
  String _fontLocaleCode;
  FleetMoraleMetricMode _fleetMoraleMetricMode;
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
  String get fontFamily => _fontFamily;
  String? get localeCode => _localeCode;
  FleetMoraleMetricMode get fleetMoraleMetricMode => _fleetMoraleMetricMode;
  List<String> get headerResourceOrder =>
      List<String>.unmodifiable(_headerResourceOrder ?? allHeaderResourceIds);
  List<String> get visibleHeaderResourceIds => List<String>.unmodifiable(
    _visibleHeaderResourceIds ?? defaultVisibleHeaderResourceIds,
  );
  List<String> get fontFamilyFallback =>
      AppFonts.fallbackForLocale(_fontLocaleCode);

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
    _fontLocaleCode = localeCode ?? 'zh';
    _fontFamily = AppFonts.forLocale(_fontLocaleCode);
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
