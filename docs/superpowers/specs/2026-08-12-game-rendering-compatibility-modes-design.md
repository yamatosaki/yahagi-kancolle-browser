# 游戏渲染兼容模式设计

## 背景

部分华为与荣耀设备反馈游戏画面掉帧、操作后逐渐卡顿，而同设备使用 GotoBrowser 较为流畅。当前游戏画面由 Android WebView 经 Flutter PlatformView 的 Texture Layer 路径进入 Impeller 合成，并在其上叠加 Flutter 工具栏模糊效果。GotoBrowser 默认使用原生 Android WebView 直出，并额外提供 Canvas 旧版渲染器。

本设计在不改变现有页面布局和业务功能的前提下，提供三档手动渲染模式，让玩家在当前 WebGL 路径、Hybrid Composition 路径和 Canvas 后备路径之间选择。

## 目标

- 保持现有左右布局、信息侧栏、工具栏、捕获、截图、代理、Gadget 绕行、日志和提醒功能。
- 在设置中提供标准、兼容、深度兼容三种模式。
- 模式切换由玩家确认后自动重建游戏环境，无需手动结束应用。
- 重建不清除 Cookie、WebView 缓存、航海日志或已解析的游戏状态。
- 任意时刻最多存在一个游戏 WebView。
- 为 Magic10 等问题设备提供可测量的 A/B/C 对照路径。

## 非目标

- 不把游戏页迁移到原生 Activity。
- 不在本功能中关闭 Impeller。
- 不自动按设备品牌选择模式。
- 不修改数据捕获的业务语义。
- 不自动清理 Cookie、缓存或数据库。
- 不承诺 Hybrid Composition 或 Canvas 在所有设备上更快。

## 模式定义

| 模式 | WebView 合成 | 舰 C 渲染 | 工具栏模糊 | FPS 设置 |
|---|---|---|---|---|
| 标准模式 | Texture Layer | WebGL | 保留 | 保持玩家设置 |
| 兼容模式 | Hybrid Composition | WebGL | 关闭 | 保持玩家设置 |
| 深度兼容模式 | Hybrid Composition | Canvas | 关闭 | 保持玩家设置并提示优先使用原始帧率 |

模式用 `GameRenderingMode` 枚举表达，并由不可变策略 getter 映射为 `usesHybridComposition`、`usesCanvasRenderer` 和 `enablesToolbarBlur`。未知或损坏的持久化值回退标准模式。

## 架构

### 设置与持久化

`GameRenderingModeStore` 负责读取和保存 SharedPreferences。`GameRenderingModeController` 保存当前实际模式、忙碌状态和最近一次切换结果，并通过一个可替换的重启端口请求游戏环境重建。

应用启动时先读取模式，再创建 `YahagiApp`。因此首次构建的 WebView 从一开始就使用正确的合成参数和 UA。

### 游戏环境宿主

新增 `GameEnvironmentHost`，只承载现有 `BattleResultWarningOverlay + GameWebView`。`YahagiShell`、侧栏、导航和其他控制器不重建。

重建采用两阶段状态机：

1. `stopping`：卸载旧 `GameWebView`，显示启动遮罩，等待一个 Flutter 帧，确保原生 View 从窗口树移除。
2. `starting`：更新实际模式和 generation，以新 Key 创建 `GameWebView`，再次等待一个 Flutter 帧后解除忙碌状态。

这避免原生 `collectWebViews()` 在缩放、截图、静音或捕获绑定时找到两个 WebView。

### WebView 创建

标准模式沿用 `WebViewWidget(controller: ...)` 的默认 Texture Layer 行为。兼容与深度兼容模式使用 `AndroidWebViewWidgetCreationParams`，设置 `displayWithHybridComposition: true`，再由 `WebViewWidget.fromPlatformCreationParams` 创建。

非 Android 平台忽略 Hybrid Composition 标志，但仍保持枚举和 UI 行为可测试。

### UA 与 Canvas

标准和兼容模式沿用当前 Windows 桌面 Chrome UA。深度兼容模式在首次真实导航前使用与 GotoBrowser 同类的 Safari/Canvas UA，使舰 C 客户端选择自身已有的 Canvas 路径。

UA 策略集中在 `GameWebViewCompatibility`，不得散落在 UI 或原生层。模式切换不清缓存；Cookie 与登录状态继续由 WebView CookieManager 管理。

### 工具栏

`GameBrowserToolbar` 增加 `enableBackdropBlur` 参数。标准模式保持现有效果；另外两种模式移除 `BackdropFilter`，但保留相同尺寸、颜色、边框、按钮与布局。

## 自动重建交互

玩家在设置页选择不同模式时显示确认框：

> 切换渲染模式将自动重启游戏环境，当前网页会重新加载。请勿在战斗或重要操作过程中切换。

检测到未完成战斗时增强警告，但不强制禁止切换。确认后：

1. 禁用模式选项和网页工具栏操作。
2. 保存目标模式。
3. 等待游戏状态、战果和战斗处理队列到达安全点，并刷新待写入状态；等待设置有限超时，防止永久卡住。
4. 执行两阶段 WebView 重建。
5. 新 WebView 重新绑定捕获、Gadget、音频、FPS、固定画布和截图能力。
6. 显示切换成功消息；设置页保持当前位置。

保存失败时保持原模式。重建同步失败时保存回标准模式并回退一次；网络加载失败沿用现有错误页，不视为渲染模式失败。回退仍失败时停止自动操作并提示玩家手动关闭应用。

## 功能保持

三种模式均保留：

- DMM 登录和 Cookie；
- 游戏数据捕获与状态侧栏；
- 战斗预测、大破提醒和震动；
- 航海日志、战果、任务和库存；
- Gadget 绕行与代理；
- 截图、静音、刷新、返回和回到首页；
- 固定 1200×720 画布和现有横竖屏布局；
- 玩家现有 FPS 设置。

深度兼容模式只改变舰 C 的绘制后端。当前项目没有依赖 WebGL 的 3D MOD，因此没有已知业务功能被关闭；画面表现、CPU 占用、流畅度和耗电可能不同。

## 错误处理

- 切换互斥：一次切换完成前拒绝后续请求。
- 同模式切换：直接返回，不保存、不重建。
- 存储异常：显示安全错误，不改变实际模式。
- 旧 WebView 卸载异常：不创建第二个 WebView，提示手动重启。
- 新环境构建异常：只自动回退标准模式一次。
- 网络错误：由现有启动状态处理，不触发模式回退。
- 非 Android：模式可保存，但合成方式保持平台默认。

## 诊断

诊断区域显示：

- 当前渲染模式；
- Texture Layer 或 Hybrid Composition；
- WebGL 或 Canvas；
- 工具栏模糊开关；
- 最近一次模式切换结果。

日志不得包含 Cookie、Token、账号或接口正文。

## 测试与验收

自动化测试覆盖策略映射、存储回退、同模式无操作、切换互斥、保存失败、两帧重建、单 WebView 约束、UA 选择、确认弹窗和工具栏模糊。

Android 集成验证覆盖捕获无重复、Gadget 重绑、FPS 重绑、Cookie 保留、截图不黑、缩放正确、旋转和前后台恢复。

真机至少覆盖荣耀 Magic10、鸿蒙 2.0、鸿蒙 4.2 和一台非华为 Android。Magic10 三种模式各完成母港操作、编成、装备翻页、完整出击、截图、前后台切换和 30 分钟持续运行；至少一种兼容模式需明显优于标准模式。若三种模式均无改善，停止叠加渲染补丁，转向捕获队列和内存诊断。
