# 任务中心紧凑布局与日文资料实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 在当前会话逐任务实现。步骤使用复选框跟踪进度。

**目标：** 修复全任务目录空值崩溃，将任务目录切换为日文主数据与 kcWiki 关系数据的安全合并，并完成紧凑卡片、统一模式按钮及按需搜索筛选交互。

**架构：** 目录加载与更新层新增双来源合并器：Kcanotify 日文文件提供展示字段，kcWiki 文件提供前置关系，合并后继续进入现有 Dataset 校验、Store 原子缓存和 Controller 热替换链路。任务中心把顶部操作状态提升到可复用组件，通过回调让独立标题栏与工作区标题栏共享搜索、筛选及模式状态；列表只消费已过滤条目，不再拥有常驻筛选区。

**技术栈：** Flutter/Dart、Widget tests、`http`、JSON、现有 QuestCatalog Dataset/Store/Controller。

---

## 文件职责

- 修改 `lib/src/quest/quest_catalog.dart`：支持合并后的日文目录字段和关系投影。
- 创建 `lib/src/quest/quest_catalog_merger.dart`：纯函数合并日文资料与 kcWiki 关系资料。
- 修改 `lib/src/quest/quest_catalog_dataset.dart`：版本记录两个上游修订并校验合并结果。
- 修改 `lib/src/quest/quest_catalog_update_service.dart`：检查、固定提交下载并合并双来源。
- 修改 `lib/src/quest/quest_catalog_store.dart`：加载新的内置合并目录和双修订元数据。
- 修改 `assets/data/quests-scn.json`：替换为构建后的日文合并目录内容（文件名暂保留以减少启动资源迁移风险）。
- 修改 `assets/data/quests-meta.json`：记录日文源、关系源和合并内容校验值。
- 修改 `lib/src/quest/quest_center_page.dart`：修复空值时序、顶部操作、筛选弹层、紧凑卡片和关系区。
- 修改 `lib/src/layout/workspace_context_header.dart`：把全任务搜索与筛选操作接到工作区标题栏。
- 修改 `lib/main.dart`：在工作区层保存并传递查询、筛选和弹层回调。
- 修改 `test/quest_catalog_dataset_test.dart`、`test/quest_catalog_update_service_test.dart`、`test/quest_catalog_test.dart`：覆盖日文合并和双来源更新。
- 修改 `test/quest_center_page_test.dart`、`test/workspace_context_header_test.dart`：覆盖崩溃、顶部交互、尺寸、紧凑卡片、关系单行和响应式布局。

### 任务 1：复现并修复全任务空目录崩溃

- [ ] 在 `test/quest_center_page_test.dart` 新增全任务无目录用例，构建 `QuestCenterPage(mode: QuestCenterMode.all, catalog: null)`，断言无异常且出现 `quest-catalog-loading`。
- [ ] 运行 `flutter test test/quest_center_page_test.dart --plain-name "all quests waits for catalog without null assertion"`，确认当前因 `_catalog!` 失败。
- [ ] 在 `QuestCenterPage.build` 计算 `_entries` 前先判断全任务目录；目录为空直接渲染带 key 的加载态。增加独立无匹配结果状态，避免错误显示“等待游戏任务”。
- [ ] 重跑目标用例和整个 `quest_center_page_test.dart`。
- [ ] 提交崩溃修复及测试。

### 任务 2：合并日文任务资料和 kcWiki 关系

- [ ] 在 `test/quest_catalog_test.dart` 增加合并用例：同一任务的名称、说明、奖励必须取日文源，`pre` 必须取关系源，中文展示字段不得残留。
- [ ] 新建 `quest_catalog_merger.dart`，解析两个 JSON 根对象，按游戏 ID 输出稳定排序的合并 JSON；日文源必须包含合法 `code/name/desc`，关系源仅复制合法 `pre`，代码不一致时报格式错误。
- [ ] 在 Dataset 版本模型加入 `displayCommitSha` 与 `relationCommitSha`，兼容旧缓存的单 `commitSha` 元数据；短版本由两份提交号生成。
- [ ] 下载 Kcanotify `files/quests-jp.json` 与 kcWiki `quests-scn.json` 的最新固定提交，离线生成合并资源和元数据；使用 `QuestCatalogDataset.parse` 验证任务数、唯一编号、字段和内容 SHA。
- [ ] 更新 `QuestCatalog.loadAsset` 和 Store 的资源路径/元数据读取，使冷启动直接加载合并目录。
- [ ] 运行目录、Dataset 和 Store 测试，确认日文展示与前后关系都存在。
- [ ] 提交合并器、资源和加载改动。

### 任务 3：双来源在线更新

- [ ] 在 `test/quest_catalog_update_service_test.dart` 写失败测试：模拟两个提交 API 和两个固定提交文件，断言保存数据为日文字段加 kcWiki `pre`；再覆盖任一来源失败时不替换当前目录。
- [ ] 将 UpdateService 的远端版本读取拆成日文源和关系源；只要任一提交变化就下载两份固定提交文件并调用合并器。
- [ ] 将版本比较改为双修订相等判断；合并数据完成后计算 SHA-256，再调用 Store 原子保存。主源失败时分别使用对应 jsDelivr 固定提交地址。
- [ ] 扩展 HTTPS 允许列表和无重定向检查，只允许 GitHub API、Raw 与 jsDelivr 的两个已声明仓库路径。
- [ ] 重跑 UpdateService、Controller、Store 和设置更新区测试。
- [ ] 提交双来源更新实现。

### 任务 4：顶部模式、搜索和筛选交互

- [ ] 在 `test/quest_center_page_test.dart` 新增失败测试：模式容器为 `260×38`；进行中无搜索/筛选按钮；全任务显示两个按钮；搜索按钮弹出输入框；筛选按钮弹出类型、周期、解锁状态并能清除。
- [ ] 把 `QuestModeTabs` 改为 RepairModeTabs 同规格固定宽度和等宽子项。
- [ ] 新增可复用 `QuestHeaderActions`，在全任务模式渲染 `quest-search-button` 和 `quest-filter-button`；搜索使用锚定 Dialog/Popup，筛选根据屏幕宽度选择 Dialog 或 bottom sheet。
- [ ] 将查询、类型、周期、解锁状态放在 `QuestCenterPage` 状态中，通过公开可选控制器或回调同步给 `workspace_context_header.dart`；工作区标题栏复用相同动作组件。
- [ ] 删除 `_QuestListPanel` 顶部常驻 TextField 和两排筛选胶囊，调整竖屏列表自然高度公式。
- [ ] 重跑任务中心与工作区标题栏测试。
- [ ] 提交顶部交互改动。

### 任务 5：紧凑卡片、编号胶囊和单行关系

- [ ] 在 `test/quest_center_page_test.dart` 写失败断言：卡片高度约 64；标题中编号与任务名为不同节点；编号胶囊颜色等于分类色；关系胶囊只含编号且前后置行不换行。
- [ ] 将卡片高度设为 64、列表间隔设为 6、标题与属性行间距设为 3；`_SmallTag` 垂直内边距设为 2。
- [ ] 新增 `_QuestCodeTag`，通过英文编号首个 A-G 字母映射现有 categoryColor；卡片和详情标题统一使用编号胶囊加名称。
- [ ] `_RelationRow` 改为标签加横向 `SingleChildScrollView(Row(...))`，ActionChip 只显示 `relation.code`，不使用 Wrap。
- [ ] 运行 390×780 和 1180×720 Widget 测试，检查 RenderFlex overflow 和详情固定区高度。
- [ ] 提交视觉密度与关系区改动。

### 任务 6：完整验证与交付

- [ ] 运行 `dart format` 仅格式化本次修改的 Dart 文件。
- [ ] 运行任务目录、更新服务、任务中心、工作区标题栏和设置更新区完整测试集，要求 0 失败。
- [ ] 对本次 Dart 文件运行 `flutter analyze`，要求 0 issues。
- [ ] 运行 `git diff --check` 并核对工作区，只提交本功能文件，不覆盖用户其他未提交改动。
- [ ] 明确交付操作：布局热重载可点黄色闪电；因内置资源和启动版本结构变更，最终验收点绿色重新加载，不打 APK。
