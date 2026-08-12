# 航海日志出击状态官方 API 化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 保持出击状态为官方 API 节点类型，并将无法可靠解析的旧数字记录显示为「旧版记录」，彻底移除错误的「进击」兜底。

**架构：** 复用现有 `BattleContext.nodeTypeLabel` 和数据库文本写入流程，不增加表字段或事件回写。将页面内状态格式化函数改为可直接测试的纯函数，使表格与筛选继续共用同一规则。

**技术栈：** Dart、Flutter、SQLite、`flutter_test`。

---

## 文件结构

- 修改 `lib/src/logbook/logbook_page.dart`：统一格式化官方节点类型文本与旧版数字记录。
- 修改 `test/logbook_page_test.dart`：覆盖纯函数、旧数据筛选和现有官方节点类型筛选。
- 验证 `test/logbook_database_test.dart`：确认新日志仍保存 `BattleContext.nodeTypeLabel`。

### 任务 1：删除「进击」兜底并兼容旧版记录

**文件：**
- 修改：`lib/src/logbook/logbook_page.dart:387,475,832,1287-1296`
- 修改：`test/logbook_page_test.dart`

- [ ] **步骤 1：编写失败的状态格式化测试**

在 `test/logbook_page_test.dart` 的 `main()` 开头新增：

```dart
test('sortie status keeps official labels and marks legacy values', () {
  expect(sortieStatusLabel('普通战斗'), '普通战斗');
  expect(sortieStatusLabel(' 路线选择 '), '路线选择');
  expect(sortieStatusLabel(1), '旧版记录');
  expect(sortieStatusLabel(6), '旧版记录');
  expect(sortieStatusLabel('1'), '旧版记录');
  expect(sortieStatusLabel(null), '旧版记录');
  expect(sortieStatusLabel(''), '旧版记录');
});
```

- [ ] **步骤 2：编写失败的旧数据筛选测试**

在同一测试文件新增 Widget 测试，通过测试数据库直接插入一条旧数字记录：

```dart
testWidgets('legacy numeric sortie status is never exposed as advance', (
  tester,
) async {
  final database = await LogbookDatabase.openForTesting();
  addTearDown(database.close);
  final db = await database.database;
  await db.insert('battle_logs', <String, Object?>{
    'timestamp': DateTime(2026, 8, 13, 12).millisecondsSinceEpoch,
    'map_area': 1,
    'map_no': 1,
    'node': 1,
    'node_type': 1,
    'rank': 's',
    'drop_ship_id': null,
    'enemy_fleet_name': '—',
    'friend_fleet_state': '6/6',
    'enemy_fleet_state': '0/6',
  });
  final controller = BattleController(gameState: () => GameState.empty);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LogbookPage(battleController: controller, database: database),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('logbook-filter-button')));
  await tester.pumpAndSettle();

  final dropdown = tester.widget<DropdownButton<String>>(
    find.descendant(
      of: find.byKey(const Key('logbook-filter-field-status')),
      matching: find.byType(DropdownButton<String>),
    ),
  );
  final options = dropdown.items!.map((item) => item.value).toList();
  expect(options, contains('旧版记录'));
  expect(options, isNot(contains('进击')));
});
```

- [ ] **步骤 3：运行测试验证失败**

运行：

```powershell
flutter test test/logbook_page_test.dart --plain-name "sortie status keeps official labels and marks legacy values"
```

预期：编译失败，提示 `sortieStatusLabel` 不存在。

随后运行旧数据筛选用例：

```powershell
flutter test test/logbook_page_test.dart --plain-name "legacy numeric sortie status is never exposed as advance"
```

预期：失败，因为筛选项实际包含「进击」而不是「旧版记录」。

- [ ] **步骤 4：编写最少实现**

将 `_sortieStatus` 替换为以下纯函数：

```dart
String sortieStatusLabel(Object? raw) {
  if (raw case final String label) {
    final trimmed = label.trim();
    if (trimmed.isNotEmpty && int.tryParse(trimmed) == null) {
      return trimmed;
    }
  }
  return '旧版记录';
}
```

把筛选匹配、筛选选项和表格单元格中的 3 处 `_sortieStatus(...)` 全部改成 `sortieStatusLabel(...)`。

- [ ] **步骤 5：运行目标测试验证通过**

运行：

```powershell
flutter test test/logbook_page_test.dart --plain-name "sortie status keeps official labels and marks legacy values"
flutter test test/logbook_page_test.dart --plain-name "legacy numeric sortie status is never exposed as advance"
flutter test test/logbook_page_test.dart --plain-name "sortie filter options match recorded statuses and all ranks"
```

预期：3 个目标用例全部通过；官方文本筛选仍包含「资源获得」「路线选择」，不包含「进击」。

- [ ] **步骤 6：运行回归与静态分析**

运行：

```powershell
dart format lib/src/logbook/logbook_page.dart test/logbook_page_test.dart
flutter analyze lib/src/logbook/logbook_page.dart test/logbook_page_test.dart test/logbook_database_test.dart
flutter test test/logbook_page_test.dart test/logbook_database_test.dart
```

预期：格式无额外变化，静态分析显示 `No issues found!`，日志页面和数据库测试全部通过。

- [ ] **步骤 7：提交实现**

提交前只暂存本任务的精确改动，检查暂存 diff 不包含工作区其他功能：

```powershell
git add lib/src/logbook/logbook_page.dart test/logbook_page_test.dart
git diff --cached --check
git diff --cached --name-only
git commit -m "fix: 修正航海日志出击状态"
```
