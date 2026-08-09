# 远征详情顶部自适应与任务计数移除实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 让远征详情顶部在正常宽度完整单行显示、窄屏仅将检查结果换到第二行，并移除任务简报容量计数胶囊。

**架构：** 在 `ExpeditionCheckPage` 内用 `LayoutBuilder` 按可用宽度选择单行或双行结构，抽取可复用的控制区与结果区构建方法；概率菜单改为独立紧凑容器。任务简报只移除标题计数展示，不触碰任务同步和进度状态逻辑。

**技术栈：** Flutter、Dart、flutter_test

---

## 文件结构

- 修改 `lib/src/expedition/expedition_check_page.dart`：响应式顶部布局、紧凑概率菜单、完整远征名称。
- 修改 `test/expedition_check_page_test.dart`：覆盖宽屏单行、窄屏结果换行、无横向滚动。
- 修改 `lib/src/quest/pinned_quests_summary.dart`：移除任务容量标题胶囊及其专用计算和组件。
- 修改 `test/home_summary_cards_test.dart`：确认同步状态保留且容量文字消失。

### 任务 1：用测试复现远征顶部横向滚动

**文件：**
- 修改：`test/expedition_check_page_test.dart`
- 测试：`test/expedition_check_page_test.dart`

- [ ] **步骤 1：编写失败的宽屏与窄屏布局测试**

增加测试键并断言：宽屏时控制区和两个结果胶囊纵坐标一致；窄屏时两个结果胶囊纵坐标一致且低于控制区；页面内不存在 `Axis.horizontal` 的 `SingleChildScrollView`；远征下拉文本不使用省略号。

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/expedition_check_page_test.dart`

预期：FAIL，现有页面仍包含横向滚动容器，且没有响应式布局测试键。

### 任务 2：实现远征顶部响应式布局

**文件：**
- 修改：`lib/src/expedition/expedition_check_page.dart:120-205`
- 修改：`lib/src/expedition/expedition_check_page.dart:515-631`
- 测试：`test/expedition_check_page_test.dart`

- [ ] **步骤 1：实现控制区与检查结果区**

用顶部 `LayoutBuilder` 计算所需宽度。宽度足够时用一个 `Row`；宽度不足时用 `Column`，第一行放远征、成功模式与概率，第二行放两个检查结果。为两行加入稳定测试键。

- [ ] **步骤 2：将概率菜单改为紧凑容器**

 `_TargetMenu` 使用约 82 像素的独立胶囊，不再嵌套宽 260 的 `_SegmentGroup`；成功模式分段组允许传入紧凑宽度。

- [ ] **步骤 3：保证远征名称完整**

移除远征下拉项的 `TextOverflow.ellipsis`，保持单行并由控制区为选择器分配足够宽度；窄屏阈值只影响检查结果换行。

- [ ] **步骤 4：运行远征测试验证绿灯**

运行：`flutter test test/expedition_check_page_test.dart`

预期：PASS，无布局溢出异常。

### 任务 3：移除任务简报容量计数

**文件：**
- 修改：`test/home_summary_cards_test.dart:805-834`
- 修改：`lib/src/quest/pinned_quests_summary.dart:26-50`
- 修改：`lib/src/quest/pinned_quests_summary.dart:170-194`

- [ ] **步骤 1：先将测试改为期望计数不存在**

保留“需进入任务界面同步信息”和“当前无进行中任务”的断言，将 `findsOneWidget` 改为 `findsNothing`，并把测试名称改为“不显示容量计数”。

- [ ] **步骤 2：运行定向测试验证红灯**

运行：`flutter test test/home_summary_cards_test.dart --plain-name "任务简报区分未同步、空任务且不显示容量计数"`

预期：FAIL，当前仍显示 `0/5`。

- [ ] **步骤 3：删除标题胶囊实现**

删除 `displayedQuestCount`、`DashboardCard.titleBadge` 参数和 `_QuestCountBadge`；保留 `state`、`missingQuestCount`、同步状态文案以及任务进度逻辑。

- [ ] **步骤 4：运行定向测试验证绿灯**

运行：`flutter test test/home_summary_cards_test.dart --plain-name "任务简报区分未同步、空任务且不显示容量计数"`

预期：PASS。

### 任务 4：回归验证

**文件：**
- 测试：`test/expedition_check_page_test.dart`
- 测试：`test/home_summary_cards_test.dart`

- [ ] **步骤 1：格式化修改文件**

运行：`dart format lib/src/expedition/expedition_check_page.dart test/expedition_check_page_test.dart lib/src/quest/pinned_quests_summary.dart test/home_summary_cards_test.dart`

- [ ] **步骤 2：运行相关测试**

运行：`flutter test test/expedition_check_page_test.dart test/home_summary_cards_test.dart`

预期：全部 PASS。

- [ ] **步骤 3：运行定向静态分析**

运行：`flutter analyze lib/src/expedition/expedition_check_page.dart lib/src/quest/pinned_quests_summary.dart test/expedition_check_page_test.dart test/home_summary_cards_test.dart`

预期：无新增 error。

- [ ] **步骤 4：检查差异**

运行：`git diff --check -- lib/src/expedition/expedition_check_page.dart test/expedition_check_page_test.dart lib/src/quest/pinned_quests_summary.dart test/home_summary_cards_test.dart`

预期：无空白错误，且差异仅包含本计划要求的布局与计数展示变更。

