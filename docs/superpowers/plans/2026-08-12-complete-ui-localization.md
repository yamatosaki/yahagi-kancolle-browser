# 客户端完整 UI 本地化实施计划

> **面向 AI 代理的工作者：** 使用 executing-plans 在当前会话逐批执行；每批严格遵循红灯、绿灯、重构、提交顺序。

**目标：** 将客户端自身的用户可见文案完整迁入简中、繁中、日文 ARB，并建立防止硬编码中文回归的自动守卫。

**架构：** `AppLocalizations` 是应用 UI 的单一文案源；动态游戏数据仅作为 ARB 模板参数。静态审计负责键/占位符一致性和源代码硬编码边界，三语言 Widget 测试负责实际渲染行为。

**技术栈：** Flutter、Dart、gen-l10n、ARB、flutter_test。

---

### 任务 1：本地化契约与自动守卫

**文件：**
- 创建：`test/localization_contract_test.dart`
- 创建：`tool/localization_ui_allowlist.txt`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`

- [ ] 编写失败测试：断言三份 ARB 的键、元数据和占位符一致；扫描指定 UI 文件中的中文字符串字面量，仅允许逐条白名单。
- [ ] 运行测试，确认因已知硬编码 UI 失败并报告文件、行号。
- [ ] 建立最小精确允许列表，仅收录游戏原始数据和内部日志，不豁免整个目录。
- [ ] 运行测试，保留后续批次对应的红灯清单。
- [ ] 提交守卫测试。

### 任务 2：主导航与全部设置页面

**文件：**
- 修改：`lib/main.dart`
- 修改：`lib/src/layout/workspace_context_header.dart`
- 修改：`lib/src/settings/screen_settings_page.dart`
- 修改：`lib/src/settings/battle_settings_page.dart`
- 修改：`lib/src/settings/battle_prediction_settings_section.dart`
- 修改：`lib/src/settings/network_settings_validator.dart`
- 修改：`lib/src/settings/network_settings_section.dart`
- 修改：`lib/src/improvement/improvement_dataset_update_section.dart`
- 修改：三份 ARB 与生成文件
- 测试：`test/settings_localization_test.dart`

- [ ] 先以日文和繁中渲染导航/设置，断言当前硬编码中文导致失败。
- [ ] 为设置分页、帧率、战斗提醒/预测、资料更新、网络校验和战果/持有入口补三语键。
- [ ] 将校验器改为稳定错误码，由 Widget 映射本地化消息。
- [ ] 运行 `flutter gen-l10n` 和设置本地化测试，确认三语通过。
- [ ] 提交设置与导航迁移。

### 任务 3：持有列表与任务中心

**文件：**
- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 修改：`lib/src/quest/quest_center_page.dart`
- 修改：相关辅助 Widget
- 修改：三份 ARB 与生成文件
- 测试：`test/inventory_quest_localization_test.dart`

- [ ] 编写日文/繁中失败测试，覆盖分页、搜索、筛选、表头、空状态和详情标签。
- [ ] 将应用生成的标签迁入 ARB；舰名、装备名、任务原文作为模板参数保留。
- [ ] 运行生成和目标测试，确认三语通过。
- [ ] 提交持有列表与任务中心迁移。

### 任务 4：航海日志、战果与改修规划

**文件：**
- 修改：`lib/src/logbook/logbook_page.dart`
- 修改：`lib/src/logbook/logbook_filter_panel.dart`
- 修改：`lib/src/senka/senka_page.dart`
- 修改：`lib/src/improvement/improvement_planner_view.dart`
- 修改：相关辅助文件与三份 ARB
- 测试：`test/logbook_senka_improvement_localization_test.dart`

- [ ] 编写失败测试，覆盖分类、表头、筛选、战果面板、日历和改修操作。
- [ ] 迁移应用文案并保留游戏资料原文。
- [ ] 运行生成和目标测试，确认三语通过。
- [ ] 提交日志、战果与改修迁移。

### 任务 5：其余舰队、远征、建造与战斗 UI

**文件：**
- 修改：`lib/src/expedition/expedition_strings.dart`
- 修改：`lib/src/fleet/` 中守卫报告的用户界面文件
- 修改：`lib/src/battle/` 中守卫报告的用户界面文件
- 修改：`lib/src/capture/` 中用户可见状态文件
- 修改：三份 ARB
- 测试：现有对应 Widget 测试及 `test/remaining_ui_localization_test.dart`

- [ ] 编写失败测试，至少覆盖远征简繁、舰队通用状态和战斗面板标签。
- [ ] 将剩余应用文案迁入 ARB或正确的三语映射；游戏数据进入白名单。
- [ ] 收紧守卫白名单，确保无未解释的用户可见中文硬编码。
- [ ] 运行生成和目标测试并提交。

### 任务 6：完整验证与交付

**文件：**
- 修改：仅验证发现的本次迁移问题。

- [ ] 运行 `flutter gen-l10n`，确认无生成差异遗漏。
- [ ] 运行本地化契约和所有新增三语 Widget 测试。
- [ ] 对本次变更文件运行 `dart format` 与 `flutter analyze`。
- [ ] 运行可执行的既有相关测试，记录与本次无关的基线失败。
- [ ] 运行 `android\\gradlew.bat :app:testDebugUnitTest`。
- [ ] 运行 `flutter build apk --debug`，不安装、不启动、不登录账号。
- [ ] 汇总迁移范围、守卫规则、测试证据与仍需真机校对的术语。
