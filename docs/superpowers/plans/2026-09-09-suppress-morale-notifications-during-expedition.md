# 远征期间抑制士气通知实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 远征中的疲劳舰队不再生成自然士气恢复闹钟或常驻士气进度，同时保持远征通知和士气计时锚点不变。

**架构：** 只在 `GameNotificationCoordinator` 的通知展示出口排除 `fleet.mission.isActive`，不修改状态归约器或 `MoraleRecoveryTimerController`。全量通知快照缺少旧士气闹钟后，Android 差异同步会取消已排程闹钟。

**技术栈：** Dart、Flutter、flutter_test

---

## 文件结构

- 修改 `test/notification/game_notification_coordinator_test.dart`：覆盖远征中的疲劳舰队不输出士气通知，并保留远征通知。
- 修改 `lib/src/notification/game_notification_coordinator.dart`：在自然士气闹钟和常驻项目构建入口排除远征舰队。

### 任务 1：锁定远征中的士气通知行为

**文件：**
- 测试：`test/notification/game_notification_coordinator_test.dart:1386-1453`

- [ ] **步骤 1：将现有远征舰队测试改为期望不输出士气项**

在已有自定义舰队名测试中保留远征断言，将士气常驻项断言改为：

```dart
expect(
  fakePort.latestSnapshot!.ongoingItems.where(
    (item) => item.id == 'morale:2',
  ),
  isEmpty,
);
expect(
  fakePort.latestSnapshot!.alarms.where(
    (alarm) => alarm.taskId == 'morale:2',
  ),
  isEmpty,
);
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/notification/game_notification_coordinator_test.dart --plain-name "uses user-defined custom fleet names in ongoing and alarm notifications"
```

预期：FAIL；`morale:2` 常驻项或闹钟仍然存在。

### 任务 2：在展示出口排除远征舰队

**文件：**
- 修改：`lib/src/notification/game_notification_coordinator.dart:784-847`
- 修改：`lib/src/notification/game_notification_coordinator.dart:1111-1141`

- [ ] **步骤 1：实现最少生产代码**

在两个自然士气分支开头加入：

```dart
if (fleet.mission.isActive) continue;
```

不修改 `MoraleRecoveryTimerController.reconcile`，使既有锚点继续保留。

- [ ] **步骤 2：运行定向测试验证通过**

运行：

```powershell
flutter test test/notification/game_notification_coordinator_test.dart --plain-name "uses user-defined custom fleet names in ongoing and alarm notifications"
```

预期：PASS。

- [ ] **步骤 3：运行通知协调器完整测试**

运行：

```powershell
flutter test test/notification/game_notification_coordinator_test.dart
```

预期：所有测试通过。

- [ ] **步骤 4：格式化并进行静态分析**

运行：

```powershell
dart format lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart
dart analyze lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart
```

预期：格式化完成，静态分析无错误。

- [ ] **步骤 5：检查变更范围并提交**

运行：

```powershell
git diff --check
git diff -- lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart
git add lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart docs/superpowers/plans/2026-09-09-suppress-morale-notifications-during-expedition.md
git commit -m "fix(通知): 远征期间抑制士气提醒"
```

预期：提交只包含本计划、协调器和对应测试，不包含工作区既有本地化改动。
