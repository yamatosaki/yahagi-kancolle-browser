import 'ui_display_size.dart';

export 'ui_display_size.dart';

typedef HeaderUiSize = UiDisplaySize;

const headerSenkaId = 'senka';
const headerAnchorageTimerId = 'anchorage-timer';
const headerNosakiTimerId = 'nosaki-timer';
const headerFrameRefreshId = 'frame-refresh';
const headerGameRefreshId = 'game-refresh';
const headerShipCapacityId = 'ship-capacity';
const headerEquipmentCapacityId = 'equipment-capacity';
const headerFurnitureCoinId = 'furniture-coin';

const allHeaderResourceIds = <String>[
  headerSenkaId,
  headerAnchorageTimerId,
  headerNosakiTimerId,
  headerFrameRefreshId,
  headerGameRefreshId,
  headerShipCapacityId,
  headerEquipmentCapacityId,
  'material-1',
  'material-2',
  'material-3',
  'material-4',
  'material-5',
  'material-6',
  'material-7',
  'material-8',
  headerFurnitureCoinId,
  'useitem-10',
  'useitem-11',
  'useitem-12',
  'useitem-54',
  'useitem-57',
  'useitem-59',
  'useitem-61',
  'useitem-68',
  'useitem-70',
  'useitem-75',
  'useitem-77',
  'useitem-78',
  'useitem-94',
  'useitem-95',
  'useitem-100',
];

const defaultVisibleHeaderResourceIds = <String>[
  headerSenkaId,
  headerAnchorageTimerId,
  headerNosakiTimerId,
  headerShipCapacityId,
  headerEquipmentCapacityId,
  'material-1',
  'material-2',
  'material-3',
  'material-4',
  'material-5',
  'material-6',
  'material-7',
  'material-8',
];

List<String> normalizeHeaderResourceOrder(Iterable<String>? saved) {
  final result = <String>[];
  if (saved != null) {
    for (final id in saved) {
      if (allHeaderResourceIds.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }
  }
  for (final id in allHeaderResourceIds) {
    if (result.contains(id)) continue;
    if (id == headerSenkaId) {
      result.insert(0, id);
      continue;
    }
    if (id == headerAnchorageTimerId) {
      final senkaIndex = result.indexOf(headerSenkaId);
      result.insert(senkaIndex < 0 ? 0 : senkaIndex + 1, id);
      continue;
    }
    if (id == headerNosakiTimerId) {
      final anchorageIndex = result.indexOf(headerAnchorageTimerId);
      final senkaIndex = result.indexOf(headerSenkaId);
      final insertIndex = anchorageIndex >= 0
          ? anchorageIndex + 1
          : (senkaIndex >= 0 ? senkaIndex + 1 : 0);
      result.insert(insertIndex, id);
      continue;
    }
    if (id == headerFrameRefreshId) {
      final nosakiIndex = result.indexOf(headerNosakiTimerId);
      result.insert(nosakiIndex < 0 ? 0 : nosakiIndex + 1, id);
      continue;
    }
    if (id == headerGameRefreshId) {
      final frameRefreshIndex = result.indexOf(headerFrameRefreshId);
      result.insert(frameRefreshIndex < 0 ? 0 : frameRefreshIndex + 1, id);
      continue;
    }
    if (id == headerShipCapacityId) {
      final refreshIndex = result.indexOf(headerGameRefreshId);
      final nosakiIndex = result.indexOf(headerNosakiTimerId);
      final insertIndex = refreshIndex >= 0
          ? refreshIndex + 1
          : (nosakiIndex >= 0 ? nosakiIndex + 1 : 0);
      result.insert(insertIndex, id);
      continue;
    }
    if (id == headerEquipmentCapacityId) {
      final shipIndex = result.indexOf(headerShipCapacityId);
      final insertIndex = shipIndex >= 0 ? shipIndex + 1 : result.length;
      result.insert(insertIndex, id);
      continue;
    }
    if (id == headerFurnitureCoinId) {
      final materialIndex = result.indexOf('material-8');
      final furnitureBoxIndex = result.indexOf('useitem-10');
      final insertIndex = materialIndex >= 0
          ? materialIndex + 1
          : (furnitureBoxIndex >= 0 ? furnitureBoxIndex : result.length);
      result.insert(insertIndex, id);
      continue;
    }
    result.add(id);
  }
  return result;
}

List<String> normalizeVisibleHeaderResourceIds(Iterable<String>? saved) {
  if (saved == null) return List<String>.from(defaultVisibleHeaderResourceIds);
  return <String>[
    for (final id in saved)
      if (allHeaderResourceIds.contains(id)) id,
  ];
}
