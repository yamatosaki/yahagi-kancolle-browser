# 受损呼吸提示双模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 保留现有普通呼吸灯，并新增默认开启、可持久化切换的加强模式，使首页舰队简报和舰队详情同步显示分级速度、鲜明颜色及头像内部染色。

**架构：** 将设置保存在现有 `LayoutSettingsController` 中，通过应用外壳显式传给舰队摘要与详情组件。`ShipHpFrame` 自主管理动画周期，并由纯函数把“模式 + HP 比例”映射为视觉规格，避免父组件为不同伤害等级维护多套控制器。

**技术栈：** Flutter、Dart、ChangeNotifier、SharedPreferences、Widget Test、flutter_test

---

## 文件结构

- 修改 `lib/src/settings/layout_settings_store.dart`：新增加强模式的读写接口和 SharedPreferences 默认值。
- 修改 `lib/src/settings/layout_settings_controller.dart`：加载、暴露和切换加强模式。
- 修改 `test/layout_settings_behavior_test.dart`：覆盖默认值和持久化。
- 修改测试内的 `LayoutSettingsStore` 内存实现：补齐新增接口。
- 修改 `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：新增开关标题与说明，并重新生成本地化文件。
- 修改 `lib/src/settings/screen_settings_page.dart`：在显示模式下方加入开关。
- 修改 `lib/src/fleet/ship_status_style.dart`：定义模式、伤害档位和可测试的视觉规格映射。
- 修改 `lib/src/fleet/ship_status_visuals.dart`：让 `ShipHpFrame` 管理周期并绘制加强模式内部染色。
- 修改 `lib/src/fleet/fleet_ship_status_capsule.dart`、`fleet_summary_card.dart`、`fleet_information_center.dart`：传递模式并移除旧的共享伤害动画控制器。
- 修改 `lib/main.dart`：把布局设置值传入首页简报和舰队详情。
- 修改 `test/ship_status_style_test.dart`、`test/fleet_information_center_test.dart`、相关摘要/外壳测试：覆盖双模式与即时切换。

### 任务 1：设置持久化与控制器

- [ ] **步骤 1：编写失败测试**

在 `test/layout_settings_behavior_test.dart` 添加：

```dart
test('enhanced damage pulse defaults on and persists changes', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  var controller = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  expect(controller.enhancedDamagePulse, isTrue);

  await controller.setEnhancedDamagePulse(false);
  controller = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  expect(controller.enhancedDamagePulse, isFalse);
});
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/layout_settings_behavior_test.dart`

预期：FAIL，提示 `enhancedDamagePulse` 和 `setEnhancedDamagePulse` 未定义。

- [ ] **步骤 3：实现最小设置代码**

给 `LayoutSettingsStore` 增加：

```dart
Future<bool> loadEnhancedDamagePulse();
Future<void> saveEnhancedDamagePulse(bool enabled);
```

SharedPreferences 实现使用键 `layout_enhanced_damage_pulse`，缺失时返回 `true`。控制器构造与 `load` 加入 `_enhancedDamagePulse`，并实现：

```dart
bool get enhancedDamagePulse => _enhancedDamagePulse;

Future<void> setEnhancedDamagePulse(bool enabled) async {
  if (_enhancedDamagePulse == enabled) return;
  _enhancedDamagePulse = enabled;
  notifyListeners();
  await _store.saveEnhancedDamagePulse(enabled);
}
```

同步补齐 `test/locale_font_mapping_test.dart` 和 `test/prototype_shell_test.dart` 的内存 store。

- [ ] **步骤 4：验证测试通过**

运行：`flutter test test/layout_settings_behavior_test.dart test/locale_font_mapping_test.dart`

预期：PASS。

### 任务 2：设置页面开关与本地化

- [ ] **步骤 1：编写失败的页面测试**

在现有外壳设置测试中断言 `settings-enhanced-damage-pulse` 存在、初始开启，点击后控制器为 false。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/prototype_shell_test.dart`

预期：FAIL，找不到开关 key。

- [ ] **步骤 3：添加本地化与开关**

三个 ARB 文件加入标题和说明；简体中文使用：

```json
"enhancedDamagePulse": "加强受损呼吸提示",
"enhancedDamagePulseDesc": "按小破、中破、大破增强颜色、速度和头像内部光效。关闭后使用普通效果。"
```

运行 `flutter gen-l10n` 生成本地化 Dart。`ScreenSettingsPage` 在 `DisplayModeSection` 后加入 divider 与：

```dart
buildSwitchTile(
  title: l10n.enhancedDamagePulse,
  subtitle: l10n.enhancedDamagePulseDesc,
  value: layoutSettingsController.enhancedDamagePulse,
  onChanged: layoutSettingsController.setEnhancedDamagePulse,
)
```

并给可定位元素添加 `Key('settings-enhanced-damage-pulse')`。

- [ ] **步骤 4：验证页面测试通过**

运行：`flutter test test/prototype_shell_test.dart`

预期：PASS。

### 任务 3：视觉规格纯函数

- [ ] **步骤 1：编写失败的规格测试**

在 `test/ship_status_style_test.dart` 覆盖：普通模式三档周期均为 2400ms 且无内部染色；加强模式分别为 2200ms、1450ms、760ms，颜色为 `#FFD34F`、`#FF8418`、`#FF2933`，内部染色强度逐档增加；健康及零 HP 不脉冲。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/ship_status_style_test.dart`

预期：FAIL，提示 `DamagePulseMode` 或规格函数未定义。

- [ ] **步骤 3：实现视觉规格**

在 `ship_status_style.dart` 定义 `DamagePulseMode`、不可变 `DamagePulseVisualSpec` 和：

```dart
DamagePulseVisualSpec damagePulseVisualSpec({
  required double hpRatio,
  required DamagePulseMode mode,
  required Color normalColor,
});
```

严格按规格边界映射；普通模式返回旧参数，加强模式返回 B 方案参数。

- [ ] **步骤 4：验证纯函数测试通过**

运行：`flutter test test/ship_status_style_test.dart`

预期：PASS。

### 任务 4：重构 `ShipHpFrame` 并绘制内部染色

- [ ] **步骤 1：编写失败的 widget 测试**

更新 `test/fleet_information_center_test.dart`：普通模式断言三档仍使用相同周期/无 `fleet-damage-tint-*`；加强模式断言三个 tint key 存在、颜色和强度不同，并检查健康舰无 tint。

- [ ] **步骤 2：运行目标测试确认失败**

运行：`flutter test test/fleet_information_center_test.dart --plain-name "renders fleet status effects"`

预期：FAIL，找不到加强模式 tint 或模式参数。

- [ ] **步骤 3：实现自管理动画与染色层**

把 `ShipHpFrame` 改为 `StatefulWidget` + `SingleTickerProviderStateMixin`。状态根据当前规格创建/更新 controller duration；受损时 repeat，健康或零 HP 时停止。绘制顺序为底框、内部半透明染色、发光受损框。内部层 key 使用 `fleet-damage-tint-$shipId`，仅加强模式产生。

从 `_FleetRosterPanelState` 与 `_FleetShipStatusCapsuleState` 移除 `_damagePulse`，保留士气闪光 controller。所有 `ShipHpFrame` 传入 `mode`，不再传外部 `animation`。

- [ ] **步骤 4：验证舰队视觉测试通过**

运行：`flutter test test/fleet_information_center_test.dart test/ship_status_style_test.dart`

预期：PASS。

### 任务 5：贯通首页、详情和即时切换

- [ ] **步骤 1：编写失败的贯通测试**

在 `test/prototype_shell_test.dart` 验证首页舰队简报默认存在加强 tint；关闭设置后 pump，tint 消失但普通 pulse 仍存在。为 `FleetInformationCenter` 添加显式普通模式测试，确保详情页行为一致。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/prototype_shell_test.dart test/fleet_information_center_test.dart`

预期：FAIL，模式尚未从控制器传到舰队 widget。

- [ ] **步骤 3：完成参数传递**

给 `FleetSummaryCard`、`FleetShipStatusCapsule`、`FleetInformationCenter` 和内部舰队卡增加 `DamagePulseMode damagePulseMode`，默认 `enhanced` 以保持产品默认。`main.dart` 从 `layoutSettingsController.enhancedDamagePulse` 转换模式并传入首页和舰队中心；已有 `AnimatedBuilder` 负责即时重建。

- [ ] **步骤 4：验证贯通测试通过**

运行：`flutter test test/prototype_shell_test.dart test/fleet_information_center_test.dart`

预期：PASS。

### 任务 6：格式化与回归验证

- [ ] **步骤 1：格式化修改文件**

运行：`dart format lib/main.dart lib/src/settings lib/src/fleet test/layout_settings_behavior_test.dart test/locale_font_mapping_test.dart test/prototype_shell_test.dart test/ship_status_style_test.dart test/fleet_information_center_test.dart`

- [ ] **步骤 2：静态检查**

运行：`flutter analyze`

预期：无新增 error；若仓库已有 warning，记录且确认与本改动无关。

- [ ] **步骤 3：执行相关回归测试**

运行：`flutter test test/layout_settings_behavior_test.dart test/locale_font_mapping_test.dart test/ship_status_style_test.dart test/fleet_information_center_test.dart test/prototype_shell_test.dart`

预期：全部 PASS。

- [ ] **步骤 4：检查工作区边界**

运行：`git diff --check` 与 `git status --short`，确认未覆盖用户无关改动。由于工作区在本功能开始前已有大量未提交代码，本计划不提交实现文件，避免把其他 1.0.3 修改混入单一 commit；只报告本次实际修改文件。

- [ ] **步骤 5：设备验证指引**

首次验证点击绿色“重新运行”，让新设置字段完成初始化。此后只调整颜色、透明度和周期时点击黄色闪电热重载即可。
