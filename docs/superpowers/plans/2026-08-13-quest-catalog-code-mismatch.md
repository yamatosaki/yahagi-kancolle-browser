# 任务资料跨数据源编号差异修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让任务资料按游戏任务 ID 合并，避免两个上游的 `code` 命名差异阻断在线更新。

**架构：** 保持现有双源下载与数据集校验流程不变。合并器以日文源作为显示字段和 `code` 的权威来源，以关系源作为 `pre` 的权威来源；两个源通过 JSON 键中的游戏任务 ID 关联。

**技术栈：** Dart、Flutter Test、`package:http/testing.dart`

---

## 文件结构

- 修改 `test/quest_catalog_test.dart`：增加合并器回归测试。
- 修改 `lib/src/quest/quest_catalog_merger.dart`：移除跨数据源 `code` 相等的致命校验。
- 修改 `test/quest_catalog_update_service_test.dart`：覆盖下载、合并和保存的完整更新流程。

### 任务 1：允许同一游戏任务 ID 使用不同的上游 `code`

**文件：**

- 修改：`test/quest_catalog_test.dart`
- 修改：`lib/src/quest/quest_catalog_merger.dart:20-32`

- [ ] **步骤 1：编写失败的合并器回归测试**

在 `test/quest_catalog_test.dart` 中增加：

```dart
test('uses game id when upstream quest codes differ', () {
  final merged = mergeQuestCatalogJson(
    japaneseJson: jsonEncode(<String, Object?>{
      '199': <String, Object?>{
        'code': 'L2606A1',
        'name': '期間限定任務',
        'desc': '日本語説明',
      },
    }),
    relationJson: jsonEncode(<String, Object?>{
      '199': <String, Object?>{
        'code': '2606Am1',
        'pre': <String>['Fd4'],
      },
    }),
  );

  final entry = (jsonDecode(merged) as Map<String, dynamic>)['199'];
  expect(entry['code'], 'L2606A1');
  expect(entry['pre'], <String>['Fd4']);
});
```

- [ ] **步骤 2：运行测试并验证红灯**

运行：

```powershell
flutter test test/quest_catalog_test.dart --plain-name "uses game id when upstream quest codes differ"
```

预期：FAIL，并包含 `Quest code mismatch for game id 199`。

- [ ] **步骤 3：实现最小修复**

从 `mergeQuestCatalogJson` 删除以下校验：

```dart
final relationCode = relation['code'];
if (relationCode is String &&
    relationCode.trim().isNotEmpty &&
    relationCode.trim() != code) {
  throw FormatException('Quest code mismatch for game id $gameId');
}
```

保留 `code` 来自日文资料、`pre` 来自关系资料的现有输出逻辑。

- [ ] **步骤 4：运行合并器测试并验证绿灯**

运行：

```powershell
flutter test test/quest_catalog_test.dart
```

预期：全部 PASS。

### 任务 2：覆盖完整在线更新流程

**文件：**

- 修改：`test/quest_catalog_update_service_test.dart:103-180`

- [ ] **步骤 1：扩展更新服务测试输入**

在 `merges immutable Japanese display and relation revisions` 测试中，让相同游戏任务 ID 的两个源使用不同 `code`：

```dart
// 日文源
'code': 'L2606A1',

// 关系源
'code': '2606Am1',
'pre': <String>['Fd4'],
```

并将保存结果断言调整为：

```dart
expect(saved.code, 'L2606A1');
expect(saved.prerequisites, <String>['Fd4']);
```

- [ ] **步骤 2：运行更新服务测试**

运行：

```powershell
flutter test test/quest_catalog_update_service_test.dart
```

预期：全部 PASS，且测试证明不同上游 `code` 不影响下载、合并和保存。

### 任务 3：回归验证与提交

**文件：**

- 验证：`lib/src/quest/quest_catalog_merger.dart`
- 验证：`test/quest_catalog_test.dart`
- 验证：`test/quest_catalog_update_service_test.dart`

- [ ] **步骤 1：格式化修改文件**

运行：

```powershell
dart format lib/src/quest/quest_catalog_merger.dart test/quest_catalog_test.dart test/quest_catalog_update_service_test.dart
```

预期：命令退出码为 0。

- [ ] **步骤 2：运行任务资料相关测试**

运行：

```powershell
flutter test test/quest_catalog_test.dart test/quest_catalog_dataset_test.dart test/quest_catalog_store_test.dart test/quest_catalog_update_service_test.dart test/quest_catalog_controller_test.dart test/quest_catalog_update_section_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：运行静态分析**

运行：

```powershell
flutter analyze lib/src/quest test/quest_catalog_test.dart test/quest_catalog_update_service_test.dart
```

预期：退出码为 0，不新增错误或警告。

- [ ] **步骤 4：检查差异**

运行：

```powershell
git diff --check -- lib/src/quest/quest_catalog_merger.dart test/quest_catalog_test.dart test/quest_catalog_update_service_test.dart
git diff -- lib/src/quest/quest_catalog_merger.dart test/quest_catalog_test.dart test/quest_catalog_update_service_test.dart
```

预期：仅包含本计划规定的合并规则和测试变更。

- [ ] **步骤 5：提交修复**

运行：

```powershell
git add -- lib/src/quest/quest_catalog_merger.dart test/quest_catalog_test.dart test/quest_catalog_update_service_test.dart
git commit -m "fix(任务): 允许跨数据源任务编号差异"
```

预期：提交只包含上述 3 个文件。
