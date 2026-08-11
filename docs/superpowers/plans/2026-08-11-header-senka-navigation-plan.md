# 顶部战果胶囊导航实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 点击首页顶部战果胶囊时切换到现有战果详情工作区。

**架构：** `CompactResourceBar` 暴露可选点击回调，`WorkspaceContextHeader` 只负责转发，`YahagiShell` 负责把工作区索引改为 9。导航仍使用现有工作区状态，不创建新的路由。

**技术栈：** Flutter、Dart、flutter_test

---

## 文件结构

- 修改 `lib/src/fleet/resource_grid.dart`：只为普通状态的战果项绑定点击回调。
- 修改 `lib/src/layout/workspace_context_header.dart`：声明并转发战果导航回调。
- 修改 `lib/main.dart`：将回调连接到 `_workspaceIndex = 9`。
- 修改 `test/compact_resource_bar_test.dart`：覆盖战果点击与普通资源点击行为。
- 修改 `test/prototype_shell_test.dart`：覆盖从顶部胶囊切换到战果工作区。

### 任务 1：资源栏点击回调

- [ ] **步骤 1：编写失败的组件测试**

在 `test/compact_resource_bar_test.dart` 中传入计数回调，点击 `header-senka-summary` 后断言计数为 1；点击 `header-resource-material-1` 后断言计数仍为 1。

- [ ] **步骤 2：验证测试失败**

运行：`flutter test test/compact_resource_bar_test.dart --reporter compact`

预期：编译失败，因为 `CompactResourceBar` 尚无 `onSenkaTap` 参数。

- [ ] **步骤 3：实现最少回调绑定**

为 `CompactResourceBar` 添加：

```dart
final VoidCallback? onSenkaTap;
```

普通列表项的 `GestureDetector.onTap` 仅在 `id == headerSenkaId` 时设置为该回调；编辑列表不绑定该回调。

- [ ] **步骤 4：验证组件测试通过**

运行：`flutter test test/compact_resource_bar_test.dart --reporter compact`

预期：全部通过。

### 任务 2：工作区导航接线

- [ ] **步骤 1：编写失败的首页集成测试**

在现有带 `SenkaController` 的 `prototype_shell_test.dart` 用例中点击 `header-senka-summary`，断言出现 `senka-landscape-layout` 或 `senka-portrait-layout`，并断言侧栏战果按钮为选中状态。

- [ ] **步骤 2：验证集成测试失败**

运行目标用例，预期点击后仍停留在游戏工作区。

- [ ] **步骤 3：实现回调透传与工作区切换**

`WorkspaceContextHeader` 新增 `onSenkaTap` 并传给 `CompactResourceBar`；`YahagiShell` 传入：

```dart
onSenkaTap: widget.senkaController == null
    ? null
    : () => setState(() => _workspaceIndex = 9),
```

- [ ] **步骤 4：格式化并验证**

运行：

```powershell
dart format lib/src/fleet/resource_grid.dart lib/src/layout/workspace_context_header.dart lib/main.dart test/compact_resource_bar_test.dart test/prototype_shell_test.dart
flutter test test/compact_resource_bar_test.dart --reporter compact
flutter test test/prototype_shell_test.dart --plain-name "header senka capsule opens the senka workspace" --reporter compact
flutter analyze lib/src/fleet/resource_grid.dart lib/src/layout/workspace_context_header.dart lib/main.dart test/compact_resource_bar_test.dart test/prototype_shell_test.dart
git diff --check -- lib/src/fleet/resource_grid.dart lib/src/layout/workspace_context_header.dart lib/main.dart test/compact_resource_bar_test.dart test/prototype_shell_test.dart
```

预期：目标测试通过、静态分析无问题、差异检查退出码为 0。
