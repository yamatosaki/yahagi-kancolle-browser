# 未卜先知受损呼吸提示实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让未卜先知仅对我方受损舰娘显示与画面设置一致的普通/加强呼吸提示。

**架构：** 在舰娘状态视觉模块中增加共享的呼吸相位构建器，继续以 `damagePulseVisualSpec` 作为颜色、阈值和周期的唯一来源。`LiveBattleCard` 从首页接收 `DamagePulseMode` 并传入完整/简洁布局；两种布局只把指定区域放进动画层。

**技术栈：** Flutter、Dart、flutter_test

---

## 文件结构

- 修改 `lib/src/fleet/ship_status_visuals.dart`：增加可复用的 `DamagePulseBuilder`，管理动画生命周期并输出共享相位。
- 修改 `lib/src/battle/live_battle_card.dart`：接收模式并为简洁模式的我方 HP 数字和血条接入呼吸动画。
- 修改 `lib/src/battle/detailed_battle_panel.dart`：为完整模式的我方行背景、HP 数字和血条接入同一动画相位。
- 修改 `lib/main.dart`：把画面设置中的普通/加强模式传给未卜先知。
- 修改 `test/ship_hp_frame_test.dart`：验证共享相位构建器的启停和模式周期。
- 修改 `test/live_battle_card_node_test.dart`：验证完整/简洁模式、敌我范围及满血/0 HP 边界。

### 任务 1：共享呼吸相位组件

**文件：**
- 修改：`test/ship_hp_frame_test.dart`
- 修改：`lib/src/fleet/ship_status_visuals.dart`

- [ ] **步骤 1：编写失败测试**

```dart
testWidgets('damage pulse builder animates damaged hp only', (tester) async {
  await tester.pumpWidget(DamagePulseBuilder(
    ratio: 0.2,
    mode: DamagePulseMode.enhanced,
    normalColor: Colors.red,
    builder: (context, spec, phase) => Text('${spec.duration.inMilliseconds}:$phase'),
  ));
  final before = tester.widget<Text>(find.byType(Text)).data;
  await tester.pump(const Duration(milliseconds: 190));
  expect(tester.widget<Text>(find.byType(Text)).data, isNot(before));
});
```

- [ ] **步骤 2：运行测试确认因缺少组件而失败**

运行：`flutter test test/ship_hp_frame_test.dart`

预期：FAIL，`DamagePulseBuilder` 未定义。

- [ ] **步骤 3：实现最小共享组件**

```dart
typedef DamagePulseWidgetBuilder = Widget Function(
  BuildContext context,
  DamagePulseVisualSpec spec,
  double phase,
);

class DamagePulseBuilder extends StatefulWidget {
  const DamagePulseBuilder({
    super.key,
    required this.ratio,
    required this.mode,
    required this.normalColor,
    required this.builder,
  });
  final double ratio;
  final DamagePulseMode mode;
  final Color normalColor;
  final DamagePulseWidgetBuilder builder;
}
```

状态对象使用 `damagePulseVisualSpec` 设置 `AnimationController.duration`，仅在 `spec.pulses` 时循环，并把缓入缓出的三角相位传给 builder；属性变化时同步启停和更新周期。

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/ship_hp_frame_test.dart`

预期：PASS。

### 任务 2：完整与简洁模式接入

**文件：**
- 修改：`test/live_battle_card_node_test.dart`
- 修改：`lib/src/battle/live_battle_card.dart`
- 修改：`lib/src/battle/detailed_battle_panel.dart`
- 修改：`lib/main.dart`

- [ ] **步骤 1：编写失败的范围测试**

为 `_pumpCard` 增加 `damagePulseMode` 参数，并构造一场包含我方受损、我方满血、敌方受损和敌方 0 HP 的战斗。断言：

```dart
expect(find.byKey(const Key('battle-damage-row-pulse-friend-0')), findsOneWidget);
expect(find.byKey(const Key('battle-damage-hp-pulse-friend-0')), findsOneWidget);
expect(find.byKey(const Key('battle-damage-hp-pulse-enemy-0')), findsNothing);
expect(find.byKey(const Key('compact-damage-hp-pulse-friend-0')), findsOneWidget);
expect(find.byKey(const Key('compact-damage-row-pulse-friend-0')), findsNothing);
```

另以动画前后 `Opacity.opacity` 或背景色透明度变化验证数字、血条和完整模式行背景共享相位，并断言舰名、奖杯位于呼吸透明度组件之外。

- [ ] **步骤 2：运行测试确认因缺少参数和动画层而失败**

运行：`flutter test test/live_battle_card_node_test.dart`

预期：FAIL，找不到未卜先知呼吸层键值或构造参数。

- [ ] **步骤 3：传递画面设置模式**

```dart
LiveBattleCard(
  controller: widget.battleController,
  damagePulseMode: widget.layoutSettingsController.enhancedDamagePulse
      ? DamagePulseMode.enhanced
      : DamagePulseMode.normal,
  collapsed: isCollapsed,
  onToggleCollapse: toggle,
)
```

`LiveBattleCard`、`DetailedBattlePanel`、`_CompactBattlePanel` 和舰队行组件逐层接收该值，测试构造保持默认 `DamagePulseMode.enhanced`。

- [ ] **步骤 4：实现指定区域动画**

完整模式仅对 `BattleSide.friend` 且 `0 < ratio <= 0.75` 的行创建 `DamagePulseBuilder`。builder 输出：

```dart
Stack(
  children: [
    Positioned.fill(child: ColoredBox(color: spec.color.withValues(alpha: rowTint))),
    staticNameAndMvp,
    Opacity(
      key: Key('battle-damage-hp-pulse-friend-$absolutePosition'),
      opacity: hpOpacity,
      child: hpNumberAndBar,
    ),
  ],
)
```

简洁模式仅用 builder 包装 HP 数字与血条；不创建行背景动画层。敌方及不应闪烁的 HP 状态直接输出原静态内容。

- [ ] **步骤 5：运行相关测试确认通过**

运行：`flutter test test/ship_hp_frame_test.dart test/live_battle_card_node_test.dart test/screen_settings_damage_pulse_test.dart`

预期：全部 PASS。

### 任务 3：格式化与回归验证

**文件：**
- 验证上述全部修改文件

- [ ] **步骤 1：格式化**

运行：`dart format lib/src/fleet/ship_status_visuals.dart lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart lib/main.dart test/ship_hp_frame_test.dart test/live_battle_card_node_test.dart`

- [ ] **步骤 2：运行静态分析**

运行：`flutter analyze`

预期：无新增错误或警告。

- [ ] **步骤 3：运行相关回归测试**

运行：`flutter test test/ship_status_style_test.dart test/ship_hp_frame_test.dart test/live_battle_card_node_test.dart test/screen_settings_damage_pulse_test.dart test/home_summary_cards_test.dart`

预期：全部 PASS；若发现与本变更无关的既有失败，记录准确测试名和实际/预期结果，不修改无关业务。

- [ ] **步骤 4：检查差异范围**

运行：`git diff --check` 以及针对上述文件的 `git diff`。

预期：无空白错误，改动仅覆盖已确认设计。
