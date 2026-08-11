# 顶部战果胶囊自定义实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让首页顶部战果胶囊支持与普通资源相同的排序、显隐、重置和持久化操作。

**架构：** 将特殊标识 `senka` 纳入顶部项目设置，但不塞入游戏资源目录。顶部列表按 ID 分派战果或普通资源渲染器，从而复用现有编辑、拖动与筛选流程。

**技术栈：** Flutter、Dart、SharedPreferences、flutter_test

---

## 文件结构

- 修改 `lib/src/settings/header_resource_settings.dart`：定义战果项目 ID、默认位置、显隐默认值和旧设置迁移。
- 修改 `lib/src/fleet/resource_grid.dart`：统一战果与资源的列表、编辑和筛选入口。
- 修改 `test/layout_settings_behavior_test.dart`：验证默认配置、旧配置迁移、显隐与重置。
- 修改 `test/compact_resource_bar_test.dart`：验证战果长按、筛选显隐和列表位置。

### 任务 1：设置模型与旧配置迁移

- [ ] **步骤 1：编写失败的设置测试**

在 `test/layout_settings_behavior_test.dart` 中断言：

```dart
expect(controller.headerResourceOrder.first, headerSenkaId);
expect(controller.visibleHeaderResourceIds, contains(headerSenkaId));
```

另用旧顺序初始化 SharedPreferences，断言缺少的 `senka` 被补到第一项，其他 ID 相对顺序不变。

- [ ] **步骤 2：运行测试并确认因缺少 `senka` 失败**

运行：`flutter test test/layout_settings_behavior_test.dart --reporter compact`

预期：断言失败，首项仍为 `material-1`，列表中没有 `senka`。

- [ ] **步骤 3：实现最少设置变更**

在 `header_resource_settings.dart` 中增加：

```dart
const headerSenkaId = 'senka';

const allHeaderResourceIds = <String>[
  headerSenkaId,
  // 原有项目……
];
```

默认显隐包含 `headerSenkaId`；规范化旧顺序时，如果缺少战果则插入首位，其余缺失资源继续追加。

- [ ] **步骤 4：运行设置测试并确认通过**

运行：`flutter test test/layout_settings_behavior_test.dart --reporter compact`

预期：全部通过。

### 任务 2：统一顶部列表与编辑操作

- [ ] **步骤 1：编写失败的组件测试**

在 `test/compact_resource_bar_test.dart` 中覆盖：战果位于列表第一项；长按战果进入编辑模式；筛选弹窗存在 `header-resource-filter-row-senka`；关闭战果后退出编辑，页面不再显示 `header-senka-summary`。

- [ ] **步骤 2：运行组件测试并确认功能缺失**

运行：`flutter test test/compact_resource_bar_test.dart --reporter compact`

预期：找不到战果筛选行，或隐藏战果后胶囊仍显示。

- [ ] **步骤 3：实现统一 ID 渲染**

在 `resource_grid.dart` 中：

```dart
Widget _buildDisplayItem(String id) => id == headerSenkaId
    ? _HeaderSenkaSummary(senka: widget.senka, rank: widget.rank)
    : _HeaderResourceItem(
        spec: headerResourceById[id]!,
        value: headerResourceById[id]!.value(widget.state),
      );
```

编辑列表和筛选列表也按 `headerSenkaId` 分派专用战果项；战果与普通资源共用手势、排序索引、显隐集合和持久化控制器。

- [ ] **步骤 4：运行组件与设置测试**

运行：

```powershell
flutter test test/compact_resource_bar_test.dart test/layout_settings_behavior_test.dart --reporter compact
```

预期：全部通过。

### 任务 3：静态与回归验证

- [ ] **步骤 1：格式化相关 Dart 文件**

运行：

```powershell
dart format lib/src/settings/header_resource_settings.dart lib/src/fleet/resource_grid.dart test/layout_settings_behavior_test.dart test/compact_resource_bar_test.dart
```

- [ ] **步骤 2：运行目标测试和静态分析**

运行：

```powershell
flutter test test/compact_resource_bar_test.dart test/layout_settings_behavior_test.dart --reporter compact
flutter analyze lib/src/settings/header_resource_settings.dart lib/src/fleet/resource_grid.dart test/layout_settings_behavior_test.dart test/compact_resource_bar_test.dart
git diff --check -- lib/src/settings/header_resource_settings.dart lib/src/fleet/resource_grid.dart test/layout_settings_behavior_test.dart test/compact_resource_bar_test.dart
```

预期：测试全部通过、分析无问题、差异检查退出码为 0。
