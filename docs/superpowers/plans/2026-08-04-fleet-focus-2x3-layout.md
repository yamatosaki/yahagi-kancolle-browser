# 舰娘信息胶囊 2×3 布局实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将舰队中栏的舰娘信息胶囊改为固定 2×3 信息矩阵，完整展示长舰名，并删除重复的装备标题。

**架构：** 保留 `_FleetFocusPanel` 的数据和交互入口，将其头部拆成身份区、标签区和三个共用 `_CompactStatusMeter` 的网格。三条状态组件由同一列宽约束驱动，头像仅扩大横向可视范围。右侧详情只移除装备模式标题，不改变上下文切换状态。

**技术栈：** Flutter、Dart、`flutter_test`。

---

## 文件结构

- 修改：`lib/src/fleet/fleet_information_center.dart`——实现 2×3 胶囊、响应式头像及标题精简。
- 修改：`test/fleet_information_center_test.dart`——验证布局位置、字号、轨道等宽、长舰名、头像尺寸和标题删除。

### 任务 1：用失败测试锁定 2×3 布局

**文件：**
- 测试：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：编写长舰名与六宫格位置测试**

新增测试数据，将 `api_mst_ship` 第一艘名称改为 `航空戦艦陸奥改二`。渲染 1180 × 720 视口后断言：

```dart
expect(find.text('航空戦艦陸奥改二'), findsOneWidget);
expect(find.textContaining('…'), findsNothing);
expect(
  tester.getTopLeft(find.byKey(const Key('fleet-focus-fuel-track-9001'))).dy,
  greaterThan(tester.getTopLeft(find.byKey(const Key('fleet-focus-hp-track-9001'))).dy),
);
expect(
  tester.getTopLeft(find.byKey(const Key('fleet-focus-ammo-track-9001'))).dy,
  greaterThan(tester.getTopLeft(find.byKey(const Key('fleet-focus-hp-track-9001'))).dy),
);
```

- [ ] **步骤 2：编写头像尺寸、字号与标题测试**

```dart
expect(tester.getSize(find.byKey(const Key('fleet-focus-portrait-9001'))), const Size(96, 42));
expect(tester.widget<Text>(find.text('航空戦艦陸奥改二')).style?.fontSize, 17);
expect(find.text('全部装备'), findsNothing);
await tester.tap(find.byKey(const Key('fleet-equipment-row-9001-0')));
await tester.pumpAndSettle();
expect(find.text('装备详情'), findsNothing);
```

- [ ] **步骤 3：运行测试并确认红灯**

运行：

```powershell
flutter test test/fleet_information_center_test.dart --plain-name "uses the approved 2 by 3 fleet focus layout"
```

预期：FAIL；旧布局中的燃料与 HP 位于同一行、头像仍为 76 × 42 dp，且两个标题仍存在。

### 任务 2：实现 2×3 舰娘信息胶囊

**文件：**
- 修改：`lib/src/fleet/fleet_information_center.dart:521-800`
- 测试：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：将头部改为左右等宽列**

在 `_FleetFocusPanel` 中保留当前字号常量，使用两个 `Expanded` 构建矩阵：左列上两行放头像、舰名和 `Next`，左列下行放燃料；右列依次放标签、HP、弹药。头像尺寸使用：

```dart
final portraitSize = narrow
    ? const Size(60, 28)
    : compact
    ? const Size(68, 32)
    : const Size(96, 42);
```

头像外层增加 `Key('fleet-focus-portrait-${ship.id}')`，实际宽度再限制为左列可用宽度的 35%。

- [ ] **步骤 2：保持舰名字号并完整显示**

舰名继续使用宽屏 17、紧凑 14、窄屏 11 的既有字号。移除 `TextOverflow.ellipsis`，为实际舰娘名称预留固定最小宽度；头像按上一步比例回退，舰名不得换行。

- [ ] **步骤 3：统一三条状态组件几何**

三条 `_CompactStatusMeter` 放入两个等宽列，并统一 `icon` 槽 18 dp、数值槽 38 dp、间距 4 dp 和剩余轨道。保持现有 `valueColor` 与 `barColor` 分离逻辑。

- [ ] **步骤 4：运行单项测试确认绿灯**

运行：

```powershell
flutter test test/fleet_information_center_test.dart --plain-name "uses the approved 2 by 3 fleet focus layout"
```

预期：PASS。

### 任务 3：删除重复装备标题并修正既有测试

**文件：**
- 修改：`lib/src/fleet/fleet_information_center.dart:765-777,1147-1161`
- 测试：`test/fleet_information_center_test.dart:285-323`

- [ ] **步骤 1：删除标题及其专用间距**

删除中栏的“全部装备”`Padding`，保留 1 dp 分隔线；装备列表顶部内边距改为 8 dp。删除 `_equipmentDetails` 中“装备详情”与其分隔线，使装备图标和名称从详情卡顶部 10 dp 开始。

- [ ] **步骤 2：更新上下文切换断言**

将旧的 `expect(find.text('装备详情'), findsOneWidget)` 改为 `findsNothing`，继续断言 `fleet-detail-equipment-icon-9001-0` 出现，以证明详情内容仍正常切换。

- [ ] **步骤 3：运行舰队组件测试**

运行：

```powershell
flutter test test/fleet_information_center_test.dart
```

预期：全部启用的测试通过。

### 任务 4：响应式回归与构建验证

**文件：**
- 测试：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：验证紧凑视口**

在现有 740 × 360 和 412 × 915 测试中继续断言无横向滚动、无溢出，并检查 HP、燃料、弹药轨道宽度集合长度为 1。

- [ ] **步骤 2：运行格式化、测试和静态检查**

```powershell
dart format lib/src/fleet/fleet_information_center.dart test/fleet_information_center_test.dart
flutter test test/fleet_information_center_test.dart test/game_state_reducer_test.dart
flutter analyze
```

预期：测试退出码为 0，`flutter analyze` 输出 `No issues found!`。

- [ ] **步骤 3：构建 Android Debug APK**

```powershell
flutter build apk --debug
```

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。
