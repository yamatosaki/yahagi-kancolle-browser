# 舰娘头像修理状态胶囊实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 在当前会话逐任务实现本计划。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 在首页舰队简报和舰队详情页头像上统一展示“入渠/泊地”修理胶囊，并在修理时把低疲劳表情移动到右侧中部。

**架构：** 新建无副作用的修理状态投影文件，集中处理入渠优先和泊地实时状态。页面只负责把投影结果传给现有 `ShipMoraleMark`，由该组件统一绘制胶囊和调整低疲劳表情位置。

**技术栈：** Flutter、Dart、flutter_test、现有 `GameStateController` 与 `AnchorageRepairCalculator`。

---

## 文件结构

- 创建 `lib/src/fleet/ship_repair_status.dart`：定义 `ShipRepairStatus` 并投影单舰当前修理状态。
- 创建 `test/ship_repair_status_test.dart`：覆盖入渠、泊地、优先级和完成状态。
- 修改 `lib/src/fleet/ship_status_visuals.dart`：绘制修理胶囊并调整低疲劳表情位置。
- 修改 `lib/src/fleet/fleet_ship_status_capsule.dart`：接收并传递首页单舰修理状态。
- 修改 `lib/src/fleet/fleet_summary_card.dart`：按当前时间计算首页修理状态。
- 修改 `lib/src/fleet/fleet_information_center.dart`：按当前时间计算详情页修理状态，并定时更新泊地投影。
- 修改 `test/fleet_summary_card_test.dart`：验证首页修理胶囊与紧凑布局。
- 修改 `test/fleet_information_center_test.dart`：验证详情页修理胶囊、疲劳胶囊和表情布局。

### 任务 1：共享修理状态投影

**文件：**

- 创建：`lib/src/fleet/ship_repair_status.dart`
- 创建：`test/ship_repair_status_test.dart`

- [ ] **步骤 1：编写失败测试**

测试有效修理槽返回 `ShipRepairStatus.dock`；泊地投影中的 `repairing` 舰返回 `ShipRepairStatus.anchorage`；同时命中时入渠优先；泊地完成、超出范围、无法修理和普通舰返回 `null`。

```dart
expect(
  shipRepairStatusFor(
    state: state,
    shipId: shipId,
    anchorageRepairStartedAt: startedAt,
    now: now,
  ),
  ShipRepairStatus.anchorage,
);
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`flutter test test/ship_repair_status_test.dart`

预期：FAIL，提示 `ship_repair_status.dart` 或 `shipRepairStatusFor` 不存在。

- [ ] **步骤 3：实现最小投影**

```dart
enum ShipRepairStatus { dock, anchorage }

extension ShipRepairStatusLabel on ShipRepairStatus {
  String get label => switch (this) {
    ShipRepairStatus.dock => '入渠',
    ShipRepairStatus.anchorage => '泊地',
  };
}

ShipRepairStatus? shipRepairStatusFor({
  required GameState state,
  required int shipId,
  required DateTime? anchorageRepairStartedAt,
  required DateTime now,
}) {
  if (state.repairDocks.any(
    (dock) => dock.isRepairing && dock.shipId == shipId,
  )) {
    return ShipRepairStatus.dock;
  }
  final startedAt = anchorageRepairStartedAt;
  if (startedAt == null) return null;
  final elapsed =
      now.isAfter(startedAt) ? now.difference(startedAt) : Duration.zero;
  for (final fleet in state.fleets) {
    final projection = AnchorageRepairCalculator.project(
      state: state,
      fleetId: fleet.id,
      elapsed: elapsed,
    );
    if (projection.rows.any(
      (row) =>
          row.ship.id == shipId &&
          row.status == AnchorageRepairShipStatus.repairing,
    )) {
      return ShipRepairStatus.anchorage;
    }
  }
  return null;
}
```

- [ ] **步骤 4：运行测试并确认通过**

运行：`flutter test test/ship_repair_status_test.dart`

预期：PASS。

### 任务 2：头像状态组件布局

**文件：**

- 修改：`lib/src/fleet/ship_status_visuals.dart`
- 修改：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：编写失败组件测试**

为修理中的低疲劳舰传入状态后，断言存在 `fleet-repair-badge-<shipId>`，文本为“入渠”或“泊地”；修理胶囊位于头像右上；疲劳胶囊仍位于右下；疲劳表情的垂直中心接近头像垂直中心。未修理舰继续断言表情位于右上。

- [ ] **步骤 2：运行目标测试并确认失败**

运行：`flutter test test/fleet_information_center_test.dart --plain-name "repair badge"`

预期：FAIL，找不到修理胶囊。

- [ ] **步骤 3：实现最小组件变更**

给 `ShipMoraleMark` 增加可空的 `repairLabel`。复用疲劳胶囊的 `badgeHeight`、最小宽度、内边距和圆角；修理胶囊使用蓝色主题并定位到右上。当 `repairLabel != null && value < 30` 时，疲劳表情使用右侧居中定位，否则保持原来的右上定位。

```dart
if (repairLabel != null)
  Positioned(
    right: 5,
    top: 4,
    child: _statusBadge(
      key: Key('fleet-repair-badge-$shipId'),
      label: repairLabel!,
      tone: const Color(0xff63c7ee),
    ),
  );
```

- [ ] **步骤 4：运行目标测试并确认通过**

运行：`flutter test test/fleet_information_center_test.dart --plain-name "repair badge"`

预期：PASS。

### 任务 3：首页接线

**文件：**

- 修改：`lib/src/fleet/fleet_ship_status_capsule.dart`
- 修改：`lib/src/fleet/fleet_summary_card.dart`
- 修改：`test/fleet_summary_card_test.dart`

- [ ] **步骤 1：编写失败组件测试**

构造入渠和泊地状态，固定 `clock`，断言首页头像右上显示对应胶囊；断言 `fleet-fatigue-badge-<shipId>` 不存在；低疲劳修理舰表情位于右侧中部；未修理舰不显示修理胶囊。

- [ ] **步骤 2：运行目标测试并确认失败**

运行：`flutter test test/fleet_summary_card_test.dart --plain-name "repair badge"`

预期：FAIL，首页胶囊组件尚未接收修理状态。

- [ ] **步骤 3：实现首页接线**

`FleetSummaryCard` 使用 `widget.clock?.call() ?? DateTime.now().toUtc()` 计算当前时间，为每艘舰调用 `shipRepairStatusFor`。`FleetShipStatusCapsule` 接收可空状态并把 `status?.label` 传给 `ShipMoraleMark`，继续保持 `showTextBadge: false`。

- [ ] **步骤 4：运行首页测试并确认通过**

运行：`flutter test test/fleet_summary_card_test.dart`

预期：PASS。

### 任务 4：详情页接线与实时刷新

**文件：**

- 修改：`lib/src/fleet/fleet_information_center.dart`
- 修改：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：编写失败组件测试**

给 `FleetInformationCenter` 提供固定时钟和修理状态，断言列表头像显示修理胶囊，并确认详情页仍显示疲劳数值胶囊。推进时钟到泊地完成后，触发定时刷新，断言“泊地”胶囊消失。

- [ ] **步骤 2：运行目标测试并确认失败**

运行：`flutter test test/fleet_information_center_test.dart --plain-name "repair badge"`

预期：FAIL，详情页尚未传递泊地开始时间和当前时间。

- [ ] **步骤 3：实现详情页接线**

为 `FleetInformationCenter` 增加可选 `clock`，在 State 中维护每秒定时器并在销毁时取消。把修理状态逐层传到 `_FleetRosterShipCapsule`，最终传给 `ShipMoraleMark`。仅改变舰队页头像，不改修理页和其他状态页。

- [ ] **步骤 4：运行详情页测试并确认通过**

运行：`flutter test test/fleet_information_center_test.dart`

预期：PASS。

### 任务 5：回归验证

**文件：**

- 检查：本计划列出的所有 Dart 文件

- [ ] **步骤 1：格式化改动文件**

运行：

```powershell
dart format lib/src/fleet/ship_repair_status.dart lib/src/fleet/ship_status_visuals.dart lib/src/fleet/fleet_ship_status_capsule.dart lib/src/fleet/fleet_summary_card.dart lib/src/fleet/fleet_information_center.dart test/ship_repair_status_test.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart
```

- [ ] **步骤 2：运行相关测试**

运行：

```powershell
flutter test test/ship_repair_status_test.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart test/anchorage_repair_calculator_test.dart test/anchorage_repair_timer_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：运行静态分析和差异检查**

运行：

```powershell
flutter analyze lib/src/fleet/ship_repair_status.dart lib/src/fleet/ship_status_visuals.dart lib/src/fleet/fleet_ship_status_capsule.dart lib/src/fleet/fleet_summary_card.dart lib/src/fleet/fleet_information_center.dart test/ship_repair_status_test.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart
git diff --check -- lib/src/fleet/ship_repair_status.dart lib/src/fleet/ship_status_visuals.dart lib/src/fleet/fleet_ship_status_capsule.dart lib/src/fleet/fleet_summary_card.dart lib/src/fleet/fleet_information_center.dart test/ship_repair_status_test.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart
```

预期：静态分析无问题，差异检查无空白错误。

> 当前工作区包含大量未提交的 1.0.3 改动，生产代码与测试文件可能已有用户修改。实现阶段不整体提交这些文件，避免把无关变更混入本功能提交；仅提交本计划文档。
