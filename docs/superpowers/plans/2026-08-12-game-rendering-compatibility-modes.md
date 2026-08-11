# 游戏渲染兼容模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不改变现有布局和业务功能的前提下，实现标准、Hybrid WebGL 兼容和 Hybrid Canvas 深度兼容三种可自动重建的游戏渲染模式。

**架构：** 用独立的模式策略和 SharedPreferences 控制器保存选择；由 `GameEnvironmentHost` 两阶段卸载和重建唯一的 `GameWebView`；WebView 根据模式选择 Android PlatformView 合成参数和 UA，工具栏根据模式选择是否使用背景模糊。

**技术栈：** Flutter 3.44、Dart 3.12、webview_flutter 4.14、webview_flutter_android 4.13、SharedPreferences、Flutter widget/unit tests。

---

## 文件结构

- 创建 `lib/src/settings/game_rendering_mode.dart`：枚举与不可变渲染策略。
- 创建 `lib/src/settings/game_rendering_mode_controller.dart`：存储、控制器、切换端口和结果。
- 创建 `lib/src/settings/game_rendering_mode_section.dart`：三模式设置 UI 与确认流程。
- 创建 `lib/src/browser/game_environment_host.dart`：两阶段唯一 WebView 重建宿主。
- 修改 `lib/src/browser/game_webview_compatibility.dart`：桌面/Canvas UA 策略。
- 修改 `lib/src/game_webview.dart`：按模式创建 PlatformView。
- 修改 `lib/src/browser/game_browser_toolbar.dart`：可关闭 BackdropFilter。
- 修改 `lib/main.dart`：启动加载、依赖注入、Host 和工具栏策略。
- 修改 `lib/src/settings/screen_settings_page.dart`、`settings_page.dart`：接入设置区块。
- 修改 `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：模式和确认文案。
- 创建 `test/game_rendering_mode_test.dart`。
- 创建 `test/game_rendering_mode_controller_test.dart`。
- 创建 `test/game_environment_host_test.dart`。
- 创建 `test/game_rendering_mode_section_test.dart`。
- 修改 `test/game_webview_compatibility_test.dart`、`test/game_browser_toolbar_test.dart`（若不存在则创建）。

### 任务 1：渲染策略模型

**文件：**
- 创建：`test/game_rendering_mode_test.dart`
- 创建：`lib/src/settings/game_rendering_mode.dart`

- [ ] **步骤 1：编写失败测试**，断言三种模式的 `usesHybridComposition`、`usesCanvasRenderer`、`enablesToolbarBlur` 和损坏值回退。
- [ ] **步骤 2：运行测试验证失败**：`flutter test test/game_rendering_mode_test.dart`，预期因目标文件或类型不存在而失败。
- [ ] **步骤 3：实现最小枚举和策略 getter**，解析未知字符串时返回 `standard`。
- [ ] **步骤 4：再次运行同一测试并确认通过。**

### 任务 2：持久化与切换控制器

**文件：**
- 创建：`test/game_rendering_mode_controller_test.dart`
- 创建：`lib/src/settings/game_rendering_mode_controller.dart`

- [ ] **步骤 1：编写失败测试**，使用内存 Store 和假重启端口覆盖加载默认值、保存后重启、相同模式无操作、忙碌互斥、保存失败保持原模式、重启失败回退标准模式。
- [ ] **步骤 2：运行测试确认因控制器不存在而失败。**
- [ ] **步骤 3：实现 `GameRenderingModeStore`、SharedPreferences/Memory Store、`GameEnvironmentRestartPort`、`GameRenderingModeController` 和结构化结果。**
- [ ] **步骤 4：运行控制器测试并保持任务 1 测试通过。**

### 任务 3：两阶段游戏环境宿主

**文件：**
- 创建：`test/game_environment_host_test.dart`
- 创建：`lib/src/browser/game_environment_host.dart`

- [ ] **步骤 1：编写失败 Widget 测试**，假游戏工厂记录活动实例数，断言重启时先降为 0，下一帧才恢复为 1，且重复请求被控制器拒绝。
- [ ] **步骤 2：运行测试确认失败原因是 Host 不存在。**
- [ ] **步骤 3：实现 `GameEnvironmentHost`，用 generation Key、停止占位和 `endOfFrame` 完成两阶段重建，并向控制器附加/解除重启端口。**
- [ ] **步骤 4：运行 Host 与控制器测试确认通过。**

### 任务 4：WebView合成参数与UA

**文件：**
- 创建或修改：`test/game_webview_compatibility_test.dart`
- 修改：`lib/src/browser/game_webview_compatibility.dart`
- 修改：`lib/src/game_webview.dart`

- [ ] **步骤 1：先写失败测试**，断言标准/兼容使用桌面 UA，深度兼容使用 Canvas Safari UA。
- [ ] **步骤 2：运行测试并确认 Canvas UA 断言失败。**
- [ ] **步骤 3：实现集中 UA 选择器，并让 `GameWebView` 接收不可变 `renderingMode`。**
- [ ] **步骤 4：将 `WebViewWidget` 改为平台创建参数：Android兼容模式设置 `displayWithHybridComposition: true`，其他平台保持默认。**
- [ ] **步骤 5：运行 UA 测试、现有 WebView 测试和 `flutter analyze` 相关文件。**

### 任务 5：工具栏无模糊路径

**文件：**
- 创建或修改：`test/game_browser_toolbar_test.dart`
- 修改：`lib/src/browser/game_browser_toolbar.dart`

- [ ] **步骤 1：编写失败 Widget 测试**，分别断言 `enableBackdropBlur=true` 存在 BackdropFilter，false 时不存在，但工具栏按钮仍存在。
- [ ] **步骤 2：运行测试确认 false 路径失败。**
- [ ] **步骤 3：实现可选模糊包装，默认值保持 true 以避免现有调用回归。**
- [ ] **步骤 4：运行工具栏测试确认通过。**

### 任务 6：设置UI与确认流程

**文件：**
- 创建：`test/game_rendering_mode_section_test.dart`
- 创建：`lib/src/settings/game_rendering_mode_section.dart`
- 修改：`lib/src/settings/screen_settings_page.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`

- [ ] **步骤 1：编写失败 Widget 测试**，覆盖三个选项、取消不切换、确认触发切换、忙碌禁用和战斗中增强警告。
- [ ] **步骤 2：运行测试确认设置区块不存在。**
- [ ] **步骤 3：实现设置区块，并将 `BattleController` 的未完成会话状态作为只读警告输入。**
- [ ] **步骤 4：在屏幕设置页接入控制器，不改变原有区块顺序之外的布局。**
- [ ] **步骤 5：补充三语言 ARB，运行 `flutter gen-l10n` 生成本地化代码。**
- [ ] **步骤 6：运行设置 Widget 测试。**

### 任务 7：应用集成与安全重建

**文件：**
- 修改：`lib/main.dart`
- 修改：`lib/src/game_webview.dart`
- 修改：`lib/src/settings/game_rendering_mode_controller.dart`

- [ ] **步骤 1：先写或扩展集成 Widget 测试**，断言模式控制器贯穿 `YahagiApp`、工具栏读取实际模式、重启仅替换游戏表面。
- [ ] **步骤 2：运行测试确认构造参数或行为失败。**
- [ ] **步骤 3：在 `main()` 启动阶段加载模式控制器并注入 App、Shell、设置和 Host。**
- [ ] **步骤 4：将现有 `BattleResultWarningOverlay + GameWebView` 移入 Host 工厂；用 generation Key 替代固定 GlobalObjectKey。**
- [ ] **步骤 5：让工具栏从实际模式读取 `enablesToolbarBlur`，重启阶段禁用网页操作。**
- [ ] **步骤 6：在重启前等待 `GameStateController.idle`、`SenkaController.idle`、`BattleController.idle`，并为等待设置有限超时。**
- [ ] **步骤 7：运行相关 Widget 测试。**

### 任务 8：诊断与回归验证

**文件：**
- 修改：`lib/src/settings/diagnostics_section.dart`
- 修改：对应诊断测试文件。

- [ ] **步骤 1：编写失败测试**，断言诊断区显示当前模式、合成方式、游戏渲染器和模糊状态。
- [ ] **步骤 2：实现只读诊断字段，不记录账号、Cookie或接口正文。**
- [ ] **步骤 3：运行诊断测试。**
- [ ] **步骤 4：运行格式化：`dart format lib test`。**
- [ ] **步骤 5：运行静态检查：`flutter analyze`。**
- [ ] **步骤 6：运行完整测试：`flutter test`。**
- [ ] **步骤 7：运行 Android JVM 测试：`cd android; .\gradlew.bat testDebugUnitTest`。**
- [ ] **步骤 8：构建调试 APK：`flutter build apk --debug`，不安装、不启动。**

## 真机手动验收

真机测试不由自动化代理登录账号。由用户在空闲时按标准、兼容、深度兼容顺序验证 Cookie 保留、母港、编成、装备翻页、完整出击、截图、静音、Gadget、前后台和 30 分钟持续运行。Magic10 额外记录三种模式的掉帧体感与内存趋势。
