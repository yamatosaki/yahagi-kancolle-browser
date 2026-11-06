import 'dart:convert';

class HdBottomModule {
  const HdBottomModule(
    this.id,
    this.span, {
    this.rows = 1,
    this.row,
    this.column,
  });
  final String id;
  final int span;
  final int rows;
  final int? row, column;
}

/// HD preferences are deliberately separate from the ordinary layout keys.
class HdLayoutSettings {
  const HdLayoutSettings({
    this.enabled = false,
    this.extensionPosition = 'bottom',
    this.split = true,
    this.leftModule = 'expedition',
    this.rightModule = 'repair',
    this.wideModule = 'fleet',
    this.sidebarOrder,
    this.hiddenModules,
    this.bottomModules,
    this.portraitModules,
    this.portraitHiddenModules,
  });

  static const moduleIds = [
    'expedition',
    'repair',
    'construction',
    'fleet',
    'quests',
    'battle',
    'land_base',
    'pre_sortie',
    'sortie_experience',
  ];
  static const defaultSidebarOrder = [
    'battle',
    'fleet',
    'land_base',
    'expedition',
    'repair',
    'construction',
    'quests',
    'pre_sortie',
    'sortie_experience',
  ];
  final List<HdBottomModule>? portraitModules;
  final List<String>? portraitHiddenModules;
  List<HdBottomModule> get portrait {
    final result = <HdBottomModule>[];
    for (final item in portraitModules ?? const <HdBottomModule>[]) {
      if (moduleIds.contains(item.id) && !result.any((e) => e.id == item.id)) {
        result.add(HdBottomModule(item.id, item.span.clamp(1, 2), rows: 1));
      }
    }
    for (final id in defaultSidebarOrder) {
      if (result.any((e) => e.id == id)) continue;
      final module = HdBottomModule(id, 1);
      if (id == 'sortie_experience') {
        final checks = result.indexWhere((entry) => entry.id == 'pre_sortie');
        result.insert(checks + 1, module);
      } else {
        result.add(module);
      }
    }
    return List.unmodifiable(result);
  }

  Set<String> get portraitHidden =>
      Set.unmodifiable(portraitHiddenModules ?? const <String>[]);
  final List<String>? sidebarOrder;
  final List<String>? hiddenModules;
  final List<HdBottomModule>? bottomModules;
  List<HdBottomModule> get bottom {
    final source =
        bottomModules ??
        (split
            ? [HdBottomModule(leftModule, 1), HdBottomModule(rightModule, 1)]
            : [HdBottomModule(wideModule, 3)]);
    final result = <HdBottomModule>[];
    var used = 0;
    for (final item in source) {
      if (!moduleIds.contains(item.id) ||
          result.any((entry) => entry.id == item.id)) {
        continue;
      }
      final span = item.span.clamp(1, 3);
      if (used + span > 3) continue;
      result.add(HdBottomModule(item.id, span));
      used += span;
    }
    return List.unmodifiable(result);
  }

  int get usedColumns => bottom.fold(0, (sum, item) => sum + item.span);
  List<String> get orderedModules {
    final order = {
      ...?sidebarOrder?.where(moduleIds.contains),
      ...defaultSidebarOrder,
    }.toList();
    if (sidebarOrder?.contains('sortie_experience') != true) {
      order.remove('sortie_experience');
      order.insert(order.indexOf('pre_sortie') + 1, 'sortie_experience');
    }
    return List.unmodifiable(order);
  }

  Set<String> get hidden => Set.unmodifiable(hiddenModules ?? const <String>[]);
  final bool enabled;
  final String? extensionPosition;
  bool get extensionAboveGame => extensionPosition == 'top';
  final bool split;
  final String leftModule;
  final String rightModule;
  final String wideModule;

  List<String> get activeModules =>
      bottom.map((item) => item.id).toList(growable: false);

  HdLayoutSettings copyWith({
    String? extensionPosition,
    bool? enabled,
    bool? split,
    String? leftModule,
    String? rightModule,
    String? wideModule,
    List<String>? sidebarOrder,
    List<String>? hiddenModules,
    List<HdBottomModule>? bottomModules,
    List<HdBottomModule>? portraitModules,
    List<String>? portraitHiddenModules,
  }) => HdLayoutSettings(
    extensionPosition: extensionPosition ?? this.extensionPosition ?? 'bottom',
    enabled: enabled ?? this.enabled,
    split: split ?? this.split,
    leftModule: leftModule ?? this.leftModule,
    rightModule: rightModule ?? this.rightModule,
    wideModule: wideModule ?? this.wideModule,
    sidebarOrder: sidebarOrder ?? this.sidebarOrder,
    hiddenModules: hiddenModules ?? this.hiddenModules,
    bottomModules: bottomModules ?? this.bottomModules,
    portraitModules: portraitModules ?? this.portraitModules,
    portraitHiddenModules: portraitHiddenModules ?? this.portraitHiddenModules,
  );

  String encode() => jsonEncode({
    'extensionPosition': extensionAboveGame ? 'top' : 'bottom',
    'portrait': [
      for (final item in portrait)
        {
          'id': item.id,
          'span': item.span,
          'rows': item.rows,
          'row': item.row,
          'column': item.column,
        },
    ],
    'portraitHidden': portraitHidden.toList(),
    'enabled': enabled,
    'split': split,
    'left': leftModule,
    'right': rightModule,
    'wide': wideModule,
    'order': orderedModules,
    'hidden': hidden.toList(),
    'bottom': [
      for (final item in bottom) {'id': item.id, 'span': item.span},
    ],
  });

  static HdLayoutSettings decode(String? raw) {
    if (raw == null) return const HdLayoutSettings();
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return const HdLayoutSettings();
      String module(String key, String fallback) =>
          moduleIds.contains(value[key]) ? value[key] as String : fallback;
      return HdLayoutSettings(
        extensionPosition: value['extensionPosition'] == 'top'
            ? 'top'
            : 'bottom',
        portraitModules: value['portrait'] is List
            ? [
                for (final item in value['portrait'] as List)
                  if (item is Map &&
                      item['id'] is String &&
                      item['span'] is int)
                    HdBottomModule(
                      item['id'] as String,
                      item['span'] as int,
                      row:
                          item['row'] is int &&
                              item['row'] >= 0 &&
                              item['row'] < 64
                          ? item['row'] as int
                          : null,
                      column:
                          item['column'] is int &&
                              item['column'] >= 0 &&
                              item['column'] < 2
                          ? item['column'] as int
                          : null,
                      rows: item['rows'] is int
                          ? item['rows'] as int
                          : (item['id'] == 'fleet' ? 2 : 1),
                    ),
              ]
            : null,
        portraitHiddenModules: value['portraitHidden'] is List
            ? (value['portraitHidden'] as List)
                  .whereType<String>()
                  .where(moduleIds.contains)
                  .toList()
            : null,
        enabled: value['enabled'] == true,
        split: value['split'] != false,
        leftModule: module('left', 'expedition'),
        rightModule: module('right', 'repair'),
        wideModule: module('wide', 'fleet'),
        bottomModules: value['bottom'] is List
            ? [
                for (final item in value['bottom'] as List)
                  if (item is Map &&
                      item['id'] is String &&
                      item['span'] is int)
                    HdBottomModule(item['id'] as String, item['span'] as int),
              ]
            : null,
        sidebarOrder: value['order'] is List
            ? (value['order'] as List).whereType<String>().toList()
            : null,
        hiddenModules: value['hidden'] is List
            ? (value['hidden'] as List)
                  .whereType<String>()
                  .where(moduleIds.contains)
                  .toList()
            : null,
      );
    } on FormatException {
      return const HdLayoutSettings();
    }
  }
}

abstract interface class HdLayoutSettingsStore {
  Future<HdLayoutSettings> loadHdLayoutSettings();
  Future<void> saveHdLayoutSettings(HdLayoutSettings settings);
}
