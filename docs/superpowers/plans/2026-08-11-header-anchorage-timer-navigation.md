# 顶部泊地计时器导航实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 点击首页顶部「泊地」计时胶囊时，打开泊地修理详情，并选择舰队编号最小的当前修理舰队；没有活动舰队时选择第 1 舰队。

**架构：** 新建纯 Dart 导航选择器，复用 `AnchorageRepairCalculator` 判断各舰队是否存在 `repairing` 舰娘。点击事件沿 `CompactResourceBar → WorkspaceContextHeader → YahagiShell` 传递，由应用外壳统一切换工作区、修理模式和目标舰队。

**技术栈：** Dart、Flutter、`flutter_test`、现有 `GameState`、`AnchorageRepairCalculator` 和 `FleetInformationCenter`。

---

## 文件结构

- 创建 `lib/src/fleet/anchorage_repair_navigation.dart`：封装目标舰队选择纯函数。
- 创建 `test/anchorage_repair_navigation_test.dart`：覆盖舰队优先级、单舰队活动和无活动回退。
- 修改 `lib/src/fleet/resource_grid.dart`：为泊地胶囊增加点击回调，保持长按自定义行为。
- 修改 `lib/src/layout/workspace_context_header.dart`：透传泊地胶囊点击回调。
- 修改 `lib/main.dart`：实时计算目标舰队并打开泊地修理详情。
- 修改 `test/compact_resource_bar_test.dart`：验证点击触发和长按不误触。
- 修改 `test/workspace_context_header_test.dart`：验证回调透传。
- 修改 `test/prototype_shell_test.dart`：验证应用外壳最终导航状态，并收窄同用例中已有的重复文本断言。

### 任务 1：实现活动泊地修理舰队选择器

**文件：**
- 创建：`lib/src/fleet/anchorage_repair_navigation.dart`
- 创建：`test/anchorage_repair_navigation_test.dart`

- [ ] **步骤 1：编写失败的纯函数测试**

创建测试状态：每支舰队以明石改为旗舰、普通舰为二号舰；二号舰 HP 不满时该舰队存在 `repairing` 状态，满血时不存在。

```dart
void main() {
  test('prefers the lowest fleet id among repairing fleets', () {
    expect(
      preferredAnchorageRepairFleetId(
        state: _stateWithRepairingFleets(<int>{2, 3}),
        elapsed: Duration.zero,
      ),
      2,
    );
  });

  test('selects fleet 3 when it is the only repairing fleet', () {
    expect(
      preferredAnchorageRepairFleetId(
        state: _stateWithRepairingFleets(<int>{3}),
        elapsed: Duration.zero,
      ),
      3,
    );
  });

  test('falls back to fleet 1 when no fleet is repairing', () {
    expect(
      preferredAnchorageRepairFleetId(
        state: _stateWithRepairingFleets(const <int>{}),
        elapsed: Duration.zero,
      ),
      1,
    );
    expect(
      preferredAnchorageRepairFleetId(
        state: const GameState(),
        elapsed: Duration.zero,
      ),
      1,
    );
  });
}

GameState _stateWithRepairingFleets(Set<int> repairingFleetIds) {
  final ships = <int, OwnedShip>{};
  final fleets = <Fleet>[];
  for (final fleetId in <int>[3, 1, 2]) {
    final flagshipId = fleetId * 10 + 1;
    final escortId = fleetId * 10 + 2;
    ships[flagshipId] = OwnedShip(
      id: flagshipId,
      masterId: 187,
      level: 80,
      currentHp: 39,
      maxHp: 39,
    );
    ships[escortId] = OwnedShip(
      id: escortId,
      masterId: 501,
      level: 50,
      currentHp: repairingFleetIds.contains(fleetId) ? 24 : 30,
      maxHp: 30,
      repairDurationMilliseconds: 1830000,
    );
    fleets.add(Fleet(
      id: fleetId,
      name: '第 $fleetId 舰队',
      shipIds: <int>[flagshipId, escortId],
    ));
  }
  return GameState(
    hasMasterData: true,
    hasPortData: true,
    masterShips: const <int, MasterShip>{
      187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
      501: MasterShip(id: 501, name: '测试舰', shipTypeId: 9),
    },
    ships: ships,
    fleets: fleets,
  );
}
```

测试文件导入 `flutter_test`、目标导航文件和 `game_state.dart`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/anchorage_repair_navigation_test.dart`

预期：编译失败，提示目标文件或 `preferredAnchorageRepairFleetId` 不存在。

- [ ] **步骤 3：编写最少实现**

```dart
import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';

int preferredAnchorageRepairFleetId({
  required GameState state,
  required Duration elapsed,
}) {
  final fleetIds = state.fleets.map((fleet) => fleet.id).toList()..sort();
  for (final fleetId in fleetIds) {
    final projection = AnchorageRepairCalculator.project(
      state: state,
      fleetId: fleetId,
      elapsed: elapsed,
    );
    if (projection.rows.any(
      (row) => row.status == AnchorageRepairShipStatus.repairing,
    )) {
      return fleetId;
    }
  }
  return 1;
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/anchorage_repair_navigation_test.dart`

预期：3 项测试全部通过。

- [ ] **步骤 5：提交选择器**

```powershell
git add lib/src/fleet/anchorage_repair_navigation.dart test/anchorage_repair_navigation_test.dart
git commit -m "feat: 选择活动泊地修理舰队"
```

### 任务 2：让顶部泊地胶囊发出点击事件

**文件：**
- 修改：`lib/src/fleet/resource_grid.dart`
- 修改：`lib/src/layout/workspace_context_header.dart`
- 修改：`test/compact_resource_bar_test.dart`
- 修改：`test/workspace_context_header_test.dart`

- [ ] **步骤 1：编写失败的胶囊点击测试**

在 `test/compact_resource_bar_test.dart` 新增：

```dart
testWidgets('anchorage capsule invokes tap without breaking long press', (
  tester,
) async {
  var taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CompactResourceBar(
          state: const GameState(),
          onAnchorageTimerTap: () => taps++,
        ),
      ),
    ),
  );

  final timer = find.byKey(const Key('header-resource-anchorage-timer'));
  await tester.tap(timer);
  await tester.pump();
  expect(taps, 1);

  await tester.longPress(timer);
  await tester.pumpAndSettle();
  expect(taps, 1);
  expect(find.byKey(const Key('header-resource-edit-mode')), findsOneWidget);
});
```

在 `test/workspace_context_header_test.dart` 的首页工作区测试中传入计数回调，点击 `header-resource-anchorage-timer` 后断言计数为 `1`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/compact_resource_bar_test.dart test/workspace_context_header_test.dart`

预期：编译失败，提示 `onAnchorageTimerTap` 参数不存在。

- [ ] **步骤 3：添加回调并透传**

在 `CompactResourceBar` 和 `WorkspaceContextHeader` 增加：

```dart
final VoidCallback? onAnchorageTimerTap;
```

在 `CompactResourceBar` 非编辑状态的 `GestureDetector` 中增加：

```dart
onTap: id == headerAnchorageTimerId
    ? widget.onAnchorageTimerTap
    : null,
```

`WorkspaceContextHeader` 创建 `CompactResourceBar` 时原样传递该回调。编辑列表不绑定 `onTap`。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/compact_resource_bar_test.dart test/workspace_context_header_test.dart`

预期：顶部胶囊点击、长按和现有顶部栏测试全部通过。

- [ ] **步骤 5：提交胶囊交互**

```powershell
git add lib/src/fleet/resource_grid.dart lib/src/layout/workspace_context_header.dart test/compact_resource_bar_test.dart test/workspace_context_header_test.dart
git commit -m "feat: 支持点击泊地计时胶囊"
```

### 任务 3：从应用外壳打开目标泊地修理舰队

**文件：**
- 修改：`lib/main.dart`
- 修改：`test/prototype_shell_test.dart`

- [ ] **步骤 1：编写失败的外壳导航测试**

在 `test/prototype_shell_test.dart` 现有 `switches to fleet center without disposing the game surface` 用例中，回到游戏工作区后点击泊地胶囊：

```dart
await tester.tap(find.byKey(const Key('workspace-nav-game')));
await tester.pumpAndSettle();
await tester.tap(find.byKey(const Key('header-resource-anchorage-timer')));
await tester.pumpAndSettle();

final anchorageCenter = tester.widget<FleetInformationCenter>(
  find.byType(FleetInformationCenter),
);
expect(anchorageCenter.repairMode, RepairCenterMode.anchorage);
expect(anchorageCenter.initialFleetId, 1);
```

将同一用例中宽泛的 `expect(find.text('建造'), findsOneWidget)` 收窄为读取 `workspace-title-construction` 对应 `Text.data`，避免标题和模式按钮同名导致误报。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/prototype_shell_test.dart --plain-name "switches to fleet center without disposing the game surface"`

预期：点击胶囊后仍停留在游戏工作区，找不到修理中心或修理模式不是 `anchorage`。

- [ ] **步骤 3：连接应用外壳导航**

在 `lib/main.dart` 导入 `anchorage_repair_navigation.dart`，并向 `WorkspaceContextHeader` 传入：

```dart
onAnchorageTimerTap: () {
  final startedAt = widget.gameStateController.anchorageRepairStartedAt;
  final now = DateTime.now().toUtc();
  final elapsed = startedAt == null || now.isBefore(startedAt)
      ? Duration.zero
      : now.difference(startedAt);
  final fleetId = preferredAnchorageRepairFleetId(
    state: widget.gameStateController.state,
    elapsed: elapsed,
  );
  setState(() {
    _repairCenterMode = RepairCenterMode.anchorage;
    _repairCenterInitialFleetId = fleetId;
    _workspaceIndex = 3;
  });
},
```

- [ ] **步骤 4：运行目标测试验证通过**

运行：`flutter test test/prototype_shell_test.dart --plain-name "switches to fleet center without disposing the game surface"`

预期：目标用例通过，点击胶囊后修理模式为泊地修理，目标舰队为 `1`。

- [ ] **步骤 5：运行相关回归和静态分析**

```powershell
flutter analyze lib/main.dart lib/src/fleet/anchorage_repair_navigation.dart lib/src/fleet/resource_grid.dart lib/src/layout/workspace_context_header.dart test/anchorage_repair_navigation_test.dart test/compact_resource_bar_test.dart test/workspace_context_header_test.dart test/prototype_shell_test.dart
flutter test test/anchorage_repair_navigation_test.dart test/compact_resource_bar_test.dart test/workspace_context_header_test.dart test/anchorage_repair_calculator_test.dart test/anchorage_repair_timer_test.dart test/anchorage_repair_view_test.dart
```

预期：静态分析显示 `No issues found!`，相关测试全部通过。

- [ ] **步骤 6：提交外壳导航**

```powershell
git add lib/main.dart test/prototype_shell_test.dart
git commit -m "feat: 从泊地计时器打开修理详情"
```
