# 无伤基地空袭识别修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 正确识别只有 stage1、没有 stage3 的无伤基地空袭，并在未卜先知与基地状态中记录 0 损伤。

**架构：** 保留 `api_destruction_battle` 作为事件来源，以有效的基地 HP 数组作为结果成立条件。伤害数组变为可选输入：存在时沿用原解析，不存在时逐基地补 0；控制器和 reducer 使用同一语义。

**技术栈：** Dart、Flutter、flutter_test

---

## 文件结构

- 修改 `test/battle_controller_test.dart`：加入真实 J 点形态的控制器回归测试。
- 修改 `test/game_state_reducer_test.dart`：加入无 stage3 的基地状态回归测试。
- 修改 `lib/src/battle/battle_controller.dart`：无伤空袭仍生成 `LandBaseRaidResult`。
- 修改 `lib/src/game_state/game_state_reducer.dart`：无伤空袭仍更新 HP 和 0 损伤。

### 任务 1：建立失败复现

**文件：**
- 修改：`test/battle_controller_test.dart`
- 修改：`test/game_state_reducer_test.dart`

- [ ] **步骤 1：增加无 stage3 的控制器测试**

```dart
'api_destruction_battle': {
  'api_f_nowhps': [200],
  'api_f_maxhps': [200],
  'api_air_base_attack': {
    'api_stage_flag': [1, 0, 0],
    'api_stage1': {'api_disp_seiku': 3},
  },
}
```

断言 `phaseLabel == '基地空袭'`、结果存在、`currentHp == 200`、`damage == 0`。

- [ ] **步骤 2：增加 reducer 测试**

以相同响应更新已有基地，断言 `maxHp == 200`、`currentHp == 200`、`lastRaidDamage == 0`。

- [ ] **步骤 3：运行测试确认红灯**

运行：`flutter test test/battle_controller_test.dart test/game_state_reducer_test.dart`

预期：新增控制器测试得到 `landBaseRaid == null`，reducer 未写入 HP，证明复现当前缺陷。

### 任务 2：最小修复与验证

**文件：**
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`

- [ ] **步骤 1：修改控制器**

```dart
final attack = _optionalMap(rawAttack);
final stage3 = _optionalMap(attack?['api_stage3']);
var damage = _list(stage3?['api_fdam']);
if (attack == null) return null;
```

不再要求 `stage3` 存在；后续索引缺失时现有代码自然取 0。

- [ ] **步骤 2：修改 reducer**

```dart
final attack = _optionalMap(rawAttack);
final stage3 = _optionalMap(attack?['api_stage3']);
var damage = _optionalList(stage3?['api_fdam']);
if (attack == null) return existing;
```

不再要求 `stage3` 存在，并保留空伤害数组的逐基地 0 默认值。

- [ ] **步骤 3：格式化并运行相关测试**

运行：`dart format lib/src/battle/battle_controller.dart lib/src/game_state/game_state_reducer.dart test/battle_controller_test.dart test/game_state_reducer_test.dart`

运行：`flutter test test/battle_controller_test.dart test/game_state_reducer_test.dart test/land_base_raid_panel_test.dart test/live_battle_card_node_test.dart`

预期：全部 PASS。

- [ ] **步骤 4：静态分析与差异检查**

运行：`dart analyze lib/src/battle/battle_controller.dart lib/src/game_state/game_state_reducer.dart test/battle_controller_test.dart test/game_state_reducer_test.dart`

运行：`git diff --check`

预期：本次修改文件无分析问题，无空白错误。
