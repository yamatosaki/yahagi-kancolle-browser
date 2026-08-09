# 基地空袭制空与 HP 紧凑展示实施计划

> **面向 AI 代理的工作者：** 必须使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）跟踪进度。

**目标：** 在基地空袭卡片中显示复用战斗配色的制空胶囊，并将 HP 与损伤合并为 `当前/最大（-损伤）`。

**架构：** `BattleController` 从基地空袭的 `api_stage1.api_disp_seiku` 解析防守视角制空状态并写入 `LandBaseRaidResult`。`LandBaseRaidPanel` 只消费模型，复用 `AirSuperiorityPill` 与舰娘 HP 颜色函数，保持完整/简洁模式一致。

**技术栈：** Dart、Flutter、flutter_test

---

## 文件结构

- 修改 `lib/src/battle/battle_models.dart`：为基地空袭结果增加制空标签。
- 修改 `lib/src/battle/battle_controller.dart`：解析基地防空制空状态。
- 修改 `lib/src/battle/land_base_raid_panel.dart`：实现紧凑状态行与舰娘 HP 配色。
- 修改 `test/battle_controller_test.dart`：覆盖制空解析与零伤事件。
- 修改 `test/land_base_raid_panel_test.dart`：覆盖文字、胶囊、颜色和窄宽布局。

### 任务 1：建立制空解析和展示的失败测试

**文件：**
- 修改：`test/battle_controller_test.dart`
- 修改：`test/land_base_raid_panel_test.dart`

- [ ] **步骤 1：扩展控制器零伤空袭测试**

在现有无 `stage3` 测试的 `api_stage1` 中保留 `api_disp_seiku: 3`，增加断言：

```dart
expect(controller.current?.landBaseRaid?.airSuperiority, '优势');
```

基地空袭采用防守视角映射：`0 → 均衡`、`1 → 丧失`、`2 → 劣势`、`3 → 优势`、`4 → 确保`，其他或缺失值为 `未知`。

- [ ] **步骤 2：更新面板测试期望**

构造结果时传入 `airSuperiority: '确保'`，断言：

```dart
expect(find.text('制空：确保'), findsNWidgets(2));
expect(find.text('152/200（-48）'), findsOneWidget);
expect(find.text('30/200（-0）'), findsOneWidget);
expect(find.textContaining('损失'), findsNothing);
expect(tester.takeException(), isNull);
```

并读取 `AirSuperiorityPill` 使用的装饰颜色，确认与 `airSuperiorityPillColors('确保')` 相同。

- [ ] **步骤 3：运行测试确认红灯**

运行：

```powershell
flutter test test/battle_controller_test.dart --plain-name "map next exposes a zero-damage land-base raid without stage3"
flutter test test/land_base_raid_panel_test.dart
```

预期：因 `LandBaseRaidResult.airSuperiority` 尚不存在、旧 HP 文本和旧损失胶囊仍在而失败。

### 任务 2：实现制空数据流

**文件：**
- 修改：`lib/src/battle/battle_models.dart`
- 修改：`lib/src/battle/battle_controller.dart`

- [ ] **步骤 1：扩展结果模型**

```dart
class LandBaseRaidResult {
  const LandBaseRaidResult({
    required this.areaId,
    required this.bases,
    this.airSuperiority = '未知',
  });

  final int areaId;
  final List<LandBaseRaidSnapshot> bases;
  final String airSuperiority;
}
```

- [ ] **步骤 2：添加防守视角映射并写入结果**

```dart
String _landBaseDefenseAirSuperiority(Object? value) {
  final code = switch (value) {
    int result => result,
    String result => int.tryParse(result),
    _ => null,
  };
  return const <int, String>{
        0: '均衡',
        1: '丧失',
        2: '劣势',
        3: '优势',
        4: '确保',
      }[code] ??
      '未知';
}
```

从 `attack['api_stage1']` 读取 `api_disp_seiku`，构造 `LandBaseRaidResult` 时写入 `airSuperiority`。缺少 `stage1` 不影响零伤空袭触发。

- [ ] **步骤 3：运行控制器测试确认绿灯**

运行：

```powershell
flutter test test/battle_controller_test.dart --plain-name "map next exposes a zero-damage land-base raid without stage3"
```

预期：PASS。

### 任务 3：实现紧凑面板

**文件：**
- 修改：`lib/src/battle/land_base_raid_panel.dart`

- [ ] **步骤 1：复用现有组件与颜色函数**

导入 `battle_pills.dart` 和 `../fleet/ship_status_style.dart`。将 `result.airSuperiority` 传入每个 `_LandBaseRaidTile`。

- [ ] **步骤 2：替换卡片内容**

基地名称保持单独一行。第二行使用：

```dart
Row(
  children: [
    AirSuperiorityPill(label: airSuperiority),
    const Spacer(),
    Text('$currentHp/$maxHp（-${base.damage}）'),
  ],
)
```

删除旧“损失”胶囊。HP 文本颜色使用 `shipHpValueColor`，血条颜色使用 `shipHpBarColor`；0 HP 传入 `isZeroHp: true`。压缩纵向间距，并确保 360 宽度不溢出。

- [ ] **步骤 3：运行面板测试确认绿灯**

运行：

```powershell
flutter test test/land_base_raid_panel_test.dart
```

预期：PASS。

### 任务 4：回归验证

**文件：**
- 验证：上述所有修改文件

- [ ] **步骤 1：格式化**

```powershell
dart format lib/src/battle/battle_models.dart lib/src/battle/battle_controller.dart lib/src/battle/land_base_raid_panel.dart test/battle_controller_test.dart test/land_base_raid_panel_test.dart
```

- [ ] **步骤 2：运行相关测试**

```powershell
flutter test test/battle_controller_test.dart --plain-name "land-base raid"
flutter test test/land_base_raid_panel_test.dart test/live_battle_card_node_test.dart test/ship_status_style_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：静态分析与差异检查**

```powershell
dart analyze lib/src/battle/battle_models.dart lib/src/battle/battle_controller.dart lib/src/battle/land_base_raid_panel.dart test/battle_controller_test.dart test/land_base_raid_panel_test.dart
git diff --check
```

预期：相关文件 0 个分析问题，差异检查无空白错误。

- [ ] **步骤 4：保留现有 Debug 工作区**

不构建 APK、不安装第二个应用、不提交混杂的生产代码；提示用户点击黄色闪电热重载。
