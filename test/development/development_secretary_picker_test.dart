import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_secretary_picker.dart';

void main() {
  test('秘书舰开发池按系别分组并保留稳定顺序', () {
    final groups = groupDevelopmentSecretaryPools(
      [
        _pool('kongo#1', '炮战系-金刚级'),
        _pool('nevada#1', '炮战系-内华达级'),
        _pool('akagi#1', '空母系-赤城'),
      ],
      const Locale('zh'),
      otherLabel: '其他',
    );

    expect(groups.map((group) => group.label), ['炮战系', '空母系']);
    expect(groups.first.pools.map((pool) => pool.key), ['kongo#1', 'nevada#1']);
  });

  testWidgets('二级选择器先切换系别再选择具体秘书舰池', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DevelopmentSecretaryPicker(
            pools: [
              _pool('akagi#1', '空母系-赤城', description: '赤城'),
              _pool('kongo#1', '炮战系-金刚级', description: '金刚型'),
              _pool('nevada#1', '炮战系-内华达级', description: '内华达'),
            ],
            selectedPoolKey: 'akagi#1',
            locale: const Locale('zh'),
            label: '秘书舰类型',
            dialogTitle: '选择秘书舰类型',
            otherLabel: '其他',
            onSelected: (key) => selected = key,
          ),
        ),
      ),
    );

    expect(find.text('空母系-赤城（赤城）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('development-secretary-picker')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('development-secretary-picker-dialog')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('development-secretary-picker-dialog')),
      findsOneWidget,
    );
    expect(selected, isNull);

    await tester.tap(find.text('炮战系'));
    await tester.pumpAndSettle();
    expect(find.text('内华达级（内华达）'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('development-secretary-option-nevada#1')),
    );
    await tester.pumpAndSettle();

    expect(selected, 'nevada#1');
    expect(
      find.byKey(const Key('development-secretary-picker-dialog')),
      findsNothing,
    );
  });
}

DevelopmentPoolRecord _pool(
  String key,
  String label, {
  String description = '',
}) => DevelopmentPoolRecord(
  key: key,
  name: key.split('#').first,
  labels: {'zh': label, 'zh_Hant': label, 'ja': label},
  descriptions: {'zh': description, 'zh_Hant': description, 'ja': description},
  poolId: 1,
  shipIds: const [1],
  minimumResources: null,
  dropRates: const {},
  criteria: DevelopmentPoolCriteria(
    shipTypes: const [],
    classTypes: const [],
    shipNames: const [],
    shipIds: const [],
    excludedShipIds: const [],
  ),
);
