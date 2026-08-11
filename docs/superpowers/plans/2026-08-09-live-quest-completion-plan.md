# 任务即时完成实现计划

> **面向 AI 代理的工作者：** 使用 executing-plans 在当前会话逐项实现；使用复选框跟踪进度。

**目标：** 已知可靠任务在本地计数达到目标时立即呈现完成状态，服务器同步仍可校准结果。

**架构：** `GameQuest` 的完成语义由“服务器完成”或“可靠精确计数已满”共同推导。Reducer 只负责根据捕获的 API 事件推进计数，首页与详情页继续读取同一个 `isCompleted`，无需增加 UI 专用状态。

**技术栈：** Dart、Flutter、现有 `GameStateReducer`、Flutter test。

---

## 文件结构

- 修改 `lib/src/game_state/game_state.dart`：定义本地完成推导语义和一致的进度标签。
- 修改 `lib/src/game_state/game_state_reducer.dart`：确保达到目标时发出带更新时间的新任务状态，并让服务器同步能够重新校准。
- 修改 `lib/src/quest/pinned_quests_summary.dart`：首页状态文字和颜色统一读取 `isCompleted`，不再直接判断服务器 `state`。
- 修改 `test/game_state_reducer_test.dart`：覆盖从目标前一步到完成、领取前保留任务、服务器校准。
- 修改 `test/home_summary_cards_test.dart`：覆盖首页无需再次同步 questlist 即显示完成。
- 修改 `test/quest_center_page_test.dart`：覆盖详情页即时完成和精确计数。

### 任务 1：建立失败的模型与 Reducer 回归测试

**文件：**
- 修改：`test/game_state_reducer_test.dart`

- [ ] 添加测试：任务 503 已接受且为 `4/5`，处理一次 `/api_req_nyukyo/start` 后仍保留在 `quests`，计数为 `5/5`，`isCompleted == true`，`progressPercentLabel == '100%'`。
- [ ] 添加测试：随后 questlist 返回未完成服务器状态和低于目标的对齐值时，本地状态按服务器档位校准，不永久锁死为完成。
- [ ] 运行：`flutter test test/game_state_reducer_test.dart --name "known quest becomes locally completed|server quest sync recalibrates local completion"`。
- [ ] 预期：第一项因 `isCompleted` 只检查 `state == 3` 而失败。

### 任务 2：实现最小完成推导

**文件：**
- 修改：`lib/src/game_state/game_state.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 修改：`lib/src/quest/pinned_quests_summary.dart`

- [ ] 将完成语义实现为：

```dart
bool get isServerCompleted => state == 3;
bool get isLocallyCompleted =>
    progressCurrent != null &&
    progressRequired != null &&
    progressRequired! > 0 &&
    progressCurrent! >= progressRequired!;
bool get isCompleted => isServerCompleted || isLocallyCompleted;
```

- [ ] `incrementExactProgress` 创建新对象时将 `updatedAt` 更新为事件时间；为此让方法接受可选 `DateTime`，Reducer 传入 `event.capturedAt`。
- [ ] 保持 `_parseQuests` 使用服务器状态、档位和目标值重新对齐本地计数，使服务器后续同步可纠正本地结果。
- [ ] 将首页 `_getProgressText` 和 `_getProgressColor` 的完成分支改为读取 `q.isCompleted`；未完成时仍使用服务器进度档位。
- [ ] 重新运行任务 1 的两项测试，预期通过。

### 任务 3：首页与详情即时呈现测试

**文件：**
- 修改：`test/home_summary_cards_test.dart`
- 修改：`test/quest_center_page_test.dart`

- [ ] 首页测试先注入已同步的 `4/5` 任务，随后仅处理一次修理事件，不处理第二次 questlist；断言首页任务状态显示“已完成”。
- [ ] 详情测试以同样状态处理事件；断言精确进度为 `5/5`，完成状态徽章存在。
- [ ] 运行：`flutter test test/home_summary_cards_test.dart test/quest_center_page_test.dart --name "immediately"`。
- [ ] 若测试因现有页面无关断言失败，缩小到新增测试名称，并记录现有失败，不修改无关页面。

### 任务 4：任务功能回归

- [ ] 运行：`flutter test test/game_state_reducer_test.dart --name "quest|known quest"`。
- [ ] 运行：`flutter test test/home_summary_cards_test.dart`。
- [ ] 运行：`flutter test test/quest_center_page_test.dart --name "exact known quest progress|immediately"`。
- [ ] 执行 `git diff --check`，确认没有新增空白错误。
