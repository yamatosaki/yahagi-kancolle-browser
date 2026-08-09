# 基地航空战预测与基地空袭损伤实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 让基地航空队攻击正确参与敌舰 HP 与预计胜败，并在未卜先知即时展示基地遭空袭后的各基地 HP 和损失。

**架构：** 战斗伤害继续由 POI/Yahagi 两套预测引擎处理，补齐真实形态的基地航空波次与联合舰队映射。基地资料进入 `GameState`，地图前进响应把 `api_destruction_battle` 转换为独立的基地空袭结果；`LiveBattle` 只持有展示快照，不把基地 HP 混入舰队排名。

**技术栈：** Flutter/Dart、ChangeNotifier、KCSAPI JSON、flutter_test。

---

## 文件结构

- `lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`、`lib/src/battle/battle_damage_parser.dart`：基地航空波次伤害解析。
- `lib/src/game_state/game_state.dart`、`game_state_reducer.dart`、`game_state_serializer.dart`：基地航空队持久状态与空袭更新。
- `lib/src/battle/battle_models.dart`、`battle_controller.dart`：未卜先知空袭快照与控制器数据流。
- 新建 `lib/src/battle/land_base_raid_panel.dart`，并修改 `detailed_battle_panel.dart`、`live_battle_card.dart`：自适应空袭界面。
- 对应修改或新建预测引擎、reducer、controller 和 widget 测试。

### 任务 1：基地航空队攻击敌舰回归与修复

**文件：**

- 修改：`test/poi_battle_prediction_engine_test.dart`
- 修改：`test/yahagi_battle_prediction_engine_test.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`
- 修改：`lib/src/battle/battle_damage_parser.dart`

- [ ] **步骤 1：编写失败测试**

加入真实形态的单波、多波、无前导占位和敌方联合舰队测试：

```dart
final prediction = engine.append(
  path: '/kcsapi/api_req_sortie/battle',
  data: <String, Object?>{
    'api_air_base_attack': <Object?>[
      <String, Object?>{
        'api_stage3': <String, Object?>{
          'api_edam': <Object?>[-1, 30.9, 0, 0, 0, 0, 0],
        },
      },
      <String, Object?>{
        'api_stage3': <String, Object?>{
          'api_edam': <Object?>[-1, 25.1, 0, 0, 0, 0, 0],
        },
      },
    ],
  },
);
expect(prediction.enemyMain.first.currentHp, 0);
expect(prediction.rank, isNot(BattleRank.d));
```

`api_stage3_combined.api_edam` 必须只更新敌方随伴舰队。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/poi_battle_prediction_engine_test.dart test/yahagi_battle_prediction_engine_test.dart`

预期：FAIL，新增场景中的敌舰 HP 或排名不正确。

- [ ] **步骤 3：最小修正基地航空处理**

两套引擎统一按每波对象分别应用主力和随伴伤害：

```dart
for (var index = 0; index < attacks.length; index++) {
  final attack = _map(attacks[index]);
  if (attack == null) {
    recordIssue('api_air_base_attack[$index]', 'attack is not an object');
    continue;
  }
  applyMainDamage(_map(attack['api_stage3'])?['api_edam']);
  applyEscortDamage(_map(attack['api_stage3_combined'])?['api_edam']);
}
```

伤害数组首项为负时去掉占位；数值先 `floor()`；空值、非法值和负数按 0。基地航空普通 `api_stage3` 不受整包 `api_active_deck` 的目标舰队选择影响。

- [ ] **步骤 4：运行预测测试确认通过**

运行：`flutter test test/poi_battle_prediction_engine_test.dart test/yahagi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart`

预期：PASS。

### 任务 2：建立基地航空队状态并解析基地空袭

**文件：**

- 修改：`lib/src/game_state/game_state.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 修改：`lib/src/game_state/game_state_serializer.dart`
- 修改：`test/game_state_reducer_test.dart`
- 修改：`test/game_state_controller_test.dart`

- [ ] **步骤 1：编写 reducer 失败测试**

发送 `api_get_member/mapinfo` 后断言 `(areaId: 47, baseId: 1)`、名称和行动类型被保存。再发送对象形式和 JSON 字符串形式的 `api_destruction_battle.api_air_base_attack`，断言两座基地分别得到 `152/200, -48` 与 `176/200, -24`。测试其他海域不变、异常字段保留旧值、回港清除临时 HP。

```dart
expect(
  state.landBases.first,
  isA<LandBaseState>()
      .having((base) => base.currentHp, 'currentHp', 152)
      .having((base) => base.lastRaidDamage, 'damage', 48),
);
```

- [ ] **步骤 2：运行状态测试确认失败**

运行：`flutter test test/game_state_reducer_test.dart test/game_state_controller_test.dart`

预期：FAIL，因为基地模型尚不存在。

- [ ] **步骤 3：添加不可变基地模型**

```dart
class LandBaseState {
  const LandBaseState({
    required this.areaId,
    required this.baseId,
    required this.name,
    this.actionKind = 0,
    this.maxHp,
    this.currentHp,
    this.lastRaidDamage = 0,
  });

  final int areaId;
  final int baseId;
  final String name;
  final int actionKind;
  final int? maxHp;
  final int? currentHp;
  final int lastRaidDamage;
}
```

为 `GameState` 构造函数、字段和 `copyWith` 增加 `List<LandBaseState> landBases`。

- [ ] **步骤 4：实现 mapinfo、空袭与回港 reducer**

把 `/kcsapi/api_get_member/mapinfo` 加入支持路径。嵌套字符串安全解码：

```dart
Object? _decodeNestedJson(Object? value) {
  if (value is! String) return value;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}
```

空袭只更新当前 `api_maparea_id` 内按 `baseId - 1` 匹配的基地，计算结果约束在 `0..maxHp`；结构无效时不覆盖有效旧状态。`api_port/port` 清除 `maxHp/currentHp/lastRaidDamage`。

- [ ] **步骤 5：更新缓存序列化**

增加 `landBases` 数组并让旧缓存缺少该键时恢复为空列表。仅恢复基础字段，临时 HP 在反序列化时清除，避免冷启动显示过期结果。

- [ ] **步骤 6：运行状态测试确认通过**

运行：`flutter test test/game_state_reducer_test.dart test/game_state_controller_test.dart`

预期：PASS。

### 任务 3：把基地空袭结果接入未卜先知模型

**文件：**

- 修改：`lib/src/battle/battle_models.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`test/battle_controller_test.dart`

- [ ] **步骤 1：编写控制器失败测试**

发送带 `api_destruction_battle` 的 `map/next`，断言：

```dart
expect(controller.current?.phaseLabel, '基地空袭');
expect(controller.current?.landBaseRaid?.bases, hasLength(2));
expect(controller.current?.landBaseRaid?.bases.first.currentHp, 152);
expect(controller.current?.landBaseRaid?.bases.first.damage, 48);
```

没有空袭的下一节点不得伪造结果；回港后结果清空。

- [ ] **步骤 2：运行控制器测试确认失败**

运行：`flutter test test/battle_controller_test.dart`

预期：FAIL，因为 `LiveBattle.landBaseRaid` 尚不存在。

- [ ] **步骤 3：定义空袭展示快照**

```dart
class LandBaseRaidSnapshot {
  const LandBaseRaidSnapshot({
    required this.baseId,
    required this.name,
    required this.currentHp,
    required this.maxHp,
    required this.damage,
  });
}

class LandBaseRaidResult {
  const LandBaseRaidResult({required this.areaId, required this.bases});
  final int areaId;
  final List<LandBaseRaidSnapshot> bases;
}
```

为 `LiveBattle` 增加可空 `landBaseRaid`，`copyWith` 必须能显式清除该字段。

- [ ] **步骤 4：从地图响应生成空袭结果**

`BattleController` 从 `api_destruction_battle` 构造快照，名称优先匹配 `gameState().landBases`，否则使用 `第 N 基地航空队`。有空袭时使用 `phaseLabel: '基地空袭'`；普通地图响应维持 `航行中` 且不带空袭结果。

- [ ] **步骤 5：运行控制器测试确认通过**

运行：`flutter test test/battle_controller_test.dart test/battle_session_test.dart`

预期：PASS。

### 任务 4：实现基地空袭自适应界面

**文件：**

- 创建：`lib/src/battle/land_base_raid_panel.dart`
- 修改：`lib/src/battle/detailed_battle_panel.dart`
- 修改：`lib/src/battle/live_battle_card.dart`
- 创建：`test/land_base_raid_panel_test.dart`
- 修改：`test/live_battle_card_node_test.dart`

- [ ] **步骤 1：编写组件失败测试**

断言 `基地空袭`、完整基地名称、`152 / 200`、`损失 -48` 和零伤害 `损失 0` 可见。以 360×640 泵入组件并断言 `tester.takeException()` 为 null，防止 RenderFlex overflow。

- [ ] **步骤 2：运行界面测试确认失败**

运行：`flutter test test/land_base_raid_panel_test.dart test/live_battle_card_node_test.dart`

预期：FAIL，因为空袭面板尚不存在。

- [ ] **步骤 3：实现紧凑基地 HP 行**

`LandBaseRaidPanel` 使用 `LayoutBuilder` 与 `Wrap`：

```dart
final columns = constraints.maxWidth >= 620 ? 2 : 1;
final itemWidth = columns == 1
    ? constraints.maxWidth
    : (constraints.maxWidth - spacing) / columns;
```

每项包含完整名称、HP 数字、线性 HP 条和损失胶囊；颜色按 HP 比例映射，不使用横向滚动。

- [ ] **步骤 4：接入详细与紧凑卡片**

详细面板在导航概览后显示完整空袭面板。紧凑卡片显示 `基地空袭`、受影响基地数量及最严重 HP 状态，展开后显示完整列表；普通导航与战斗布局保持不变。

- [ ] **步骤 5：运行界面测试确认通过**

运行：`flutter test test/land_base_raid_panel_test.dart test/live_battle_card_node_test.dart`

预期：PASS，且没有 overflow 日志。

### 任务 5：完整验证与热重载交付

**文件：** 验证上述所有修改文件。

- [ ] **步骤 1：格式化本次 Dart 文件**

运行 `dart format`，参数仅包含本计划修改或新建的 Dart 文件。

预期：命令退出码 0。

- [ ] **步骤 2：运行聚焦测试组**

```powershell
flutter test test/poi_battle_prediction_engine_test.dart test/yahagi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart test/game_state_reducer_test.dart test/game_state_controller_test.dart test/battle_controller_test.dart test/battle_session_test.dart test/land_base_raid_panel_test.dart test/live_battle_card_node_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：运行相关静态分析**

```powershell
flutter analyze lib/src/battle lib/src/game_state test/poi_battle_prediction_engine_test.dart test/yahagi_battle_prediction_engine_test.dart test/game_state_reducer_test.dart test/game_state_controller_test.dart test/battle_controller_test.dart test/land_base_raid_panel_test.dart test/live_battle_card_node_test.dart
```

预期：No issues found。

- [ ] **步骤 4：检查工作区边界**

运行 `git diff --check` 与 `git status --short`，确认没有覆盖用户已有修改，也没有生成 APK 或第二个应用实例。

- [ ] **步骤 5：交付运行提示**

本次增加 Dart 类型、状态字段和新 Widget，提示用户点击绿色“重新运行”一次，使当前 Debug 实例完整重建；之后纯样式微调可继续使用黄色闪电。不要执行 APK 打包。
