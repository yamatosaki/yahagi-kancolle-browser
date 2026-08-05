import 'dart:convert';
import 'dart:io';

void main() {
  final raw = File('tool/wiki_bonus/cache/raw/start2.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  print('keys: ${data.keys.toList()}');
  final ships = (data['api_mst_ship'] as List).cast<Map<String, dynamic>>();
  final items = (data['api_mst_slotitem'] as List).cast<Map<String, dynamic>>();
  final stypes = (data['api_mst_stype'] as List).cast<Map<String, dynamic>>();
  print('ships=${ships.length} items=${items.length} stypes=${stypes.length}');
  print('ship[0] keys: ${ships.first.keys.toList()}');
  print('item[0] keys: ${items.first.keys.toList()}');
  final targets = ['時雨改三','時雨改二','雪風改二','雪風改','丹陽','磯風乙改','陽炎改二','不知火改二','黒潮改二','親潮改二','早潮改二','天津風改二','秋雲改二','白露','朝潮','陽炎'];
  for (final n in targets) {
    final s = ships.where((e) => e['api_name'] == n).toList();
    if (s.isEmpty) {
      print('$n => NOT FOUND');
    } else {
      for (final e in s) {
        print('$n => id=${e['api_id']} ctype=${e['api_ctype']} stype=${e['api_stype']} country=${e['api_country']} sortno=${e['api_sortno']}');
      }
    }
  }
  final e266 = items.where((e) => (e['api_id'] as num).toInt() == 266).toList();
  print('item 266: ${jsonEncode(e266)}');
  final e22 = items.where((e) => (e['api_name'] ?? '').contains('22号対水上電探')).toList();
  print('22号対水上電探: ${e22.map((e) => 'id=${e['api_id']} name=${e['api_name']} type=${e['api_type']} saku=${e['api_saku']}').join('; ')}');
  final e13 = items.where((e) => (e['api_name'] ?? '').contains('13号対空電探')).toList();
  print('13号対空電探: ${e13.map((e) => 'id=${e['api_id']} name=${e['api_name']} type=${e['api_type']} saku=${e['api_saku']}').join('; ')}');
  final kagero = ships.where((e) => (e['api_ctype'] as num).toInt() == 23).toList();
  print('kagero class (ctype 23?): ${kagero.length}');
  if (kagero.isNotEmpty) print(kagero.take(3).map((e) => 'id=${e['api_id']} name=${e['api_name']}').join('; '));
  final stypeNames = stypes.map((e) => '${e['api_id']}=${e['api_name']}').toList();
  print('stypes: ${stypeNames.join(', ')}');
}
