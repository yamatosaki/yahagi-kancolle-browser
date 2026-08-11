# 全机型游戏画面流畅度优化设计

## 背景

客户端当前通过 Flutter 承载布局，并在 Android Platform View 中运行游戏 WebView。现有三种渲染模式分别覆盖 Texture + WebGL、Hybrid Composition + WebGL，以及 Hybrid Composition + Canvas。它们解决了不同 WebView 和 GPU 驱动的兼容问题，但尚未形成面向所有 Android 设备的统一性能策略。

本设计不按华为、荣耀、小米、三星等品牌划分设备。所有决策只依据玩家选择、Android 平台能力和当次运行中的短期帧表现。

## 目标

- 保持现有布局、数据捕获、安全功能和三种渲染模式。
- 减少 WebView 与 Flutter 界面组合时的无效重绘。
- 将大型游戏接口的 JSON 解析移出 Dart UI Isolate。
- 提供「自动」「稳定 30 FPS」「优先 60 FPS」三档帧率策略。
- 在满足条件的设备上启用 Hybrid Composition++（HCPP），不满足条件时自动回退。
- 合并同一帧内的状态通知，减少接口返回瞬间的界面抖动。
- 使用自动化测试和开发工具验证性能相关行为，不收集玩家性能诊断数据。

## 非目标

- 不增加品牌、型号或厂商系统白名单。
- 不保存或上传设备型号、WebView 版本、FPS、温度和慢帧记录。
- 不在设置页面增加性能诊断入口。
- 不替换为独立原生 Android WebView Activity。
- 不改变游戏请求，不模拟点击、滑动或按键。
- 不追求 90 FPS 或 120 FPS。
- 不在运行中自动切换渲染模式，因为切换会重建 WebView 并重新加载页面。

## 方案选择

### 采用方案：平衡型自适应

保留标准模式作为全机型默认路径。兼容模式继续由玩家手动选择。帧率默认使用自动策略，在当次运行中短暂尝试 60 FPS；如果持续无法稳定运行，则降为 30 FPS，并在本次运行剩余时间保持 30 FPS。

该方案同时改善高性能设备的峰值流畅度和中低端设备的稳定性。它不会根据品牌推断能力，也不会持久化性能样本。

### 未采用方案：完全手动

完全手动的 30/60 FPS 设置风险最低，但不能处理设备发热、系统负载变化和玩家不理解帧率选项的问题。

### 未采用方案：默认强制 60 FPS

强制 60 FPS 可以提高部分设备的峰值表现，但会增加中低端设备的 CPU、GPU 和电量压力，并可能因热降频造成更严重的长时间卡顿。

## 总体架构

性能优化分为 4 个相互独立的模块：

1. **游戏表面隔离：** 保持 WebView 的 Widget 身份和原生视图稳定，限制工具栏、信息面板和警告层的重绘范围。
2. **后台解析管线：** 在后台 Isolate 中完成大型响应的 JSON 解码，再在 UI Isolate 中按顺序归并状态。
3. **帧率策略控制器：** 保存玩家选择，并根据当次运行中的临时帧样本决定 30 或 60 FPS。
4. **平台合成能力：** 在 Android 14、Vulkan 和 Impeller 条件满足时启用 HCPP，否则使用现有合成路径。

这 4 个模块通过小型接口连接，可以分别测试和回滚。任何模块失败都不能阻止游戏页面加载或数据捕获。

## 游戏表面与重绘边界

### WebView 身份

- `GameWebView` 在非渲染模式切换期间保持稳定 Key。
- 舰队、任务、战斗和日志状态更新不得替换 WebView Controller 或 Platform View。
- 游戏画面包裹独立 `RepaintBoundary`，其父级只负责尺寸约束，不监听游戏状态 Controller。
- 渲染模式切换仍使用现有 `GameEnvironmentHost` 重建流程。

### 工具栏

- 工具栏只监听浏览器、音频和自身显示状态。
- 浮动工具栏完全收起后，不保留持续运行的透明度或位移动画。
- 兼容模式继续关闭 `BackdropFilter` 模糊。
- 固定工具栏和浮动工具栏保持现有布局与功能，不强制玩家更改显示方式。

### 警告与覆盖层

- 战斗警告动画仅在警告实际显示时创建。
- 未显示警告时，覆盖层直接返回稳定的游戏子树，不参与逐帧动画。
- 截图、弹窗和 SnackBar 只在玩家触发时产生临时绘制负担。

## 后台解析与通知合并

### 数据流

```text
原生捕获桥
  -> CapturedApiEvent 原始响应
  -> 按 sequence 排队
  -> 后台 Isolate 解码 JSON
  -> UI Isolate 顺序归并 GameState / Battle / Senka
  -> 每个 Flutter 帧最多通知一次对应监听者
  -> 异步数据库写入队列
```

### 顺序与一致性

- 继续使用捕获事件的 `sequence` 保证处理顺序。
- 后台任务可以并行执行解码，但状态归并必须按事件顺序提交。
- 不识别或不需要 JSON 的接口不得启动后台任务。
- JSON 响应正文达到 64 KiB 时进入后台解码；`api_start2/getData` 无论大小都进入后台解码。其余响应保持现有顺序管线，避免为小对象支付 Isolate 调度成本。
- 解码失败时保留现有错误状态，不中断后续事件队列。

### 通知策略

- Controller 可以在同一事件中多次改变内部字段，但每个 Flutter 帧最多调用一次 `notifyListeners()`。
- 不同 Controller 仍保持独立通知，避免建立新的全局状态容器。
- 战斗安全提醒不能因通知合并而延迟到下一个游戏操作；最多延迟 1 个 Flutter 帧。

### 数据库写入

- 日志和资源快照继续使用有序异步队列。
- 状态归并不等待非关键数据库写入完成。
- 切换渲染模式时，沿用现有 `idle` 屏障等待关键处理队列，不丢弃已捕获事件。

## 帧率策略

### 玩家设置

设置值定义为：

| 模式 | 行为 |
|---|---|
| 自动 | 当次运行尝试 60 FPS，持续不稳定时降为 30 FPS |
| 稳定 30 FPS | 强制 CreateJS Ticker 使用 30 FPS 策略 |
| 优先 60 FPS | 强制 CreateJS Ticker 使用 `requestAnimationFrame` 策略 |

原有布尔值「解除帧率限制」自动迁移：开启映射为「优先 60 FPS」，关闭映射为「稳定 30 FPS」，避免升级后改变玩家已经选择的行为。没有旧设置的新安装默认使用「自动」。迁移成功后使用新的枚举存储键。

### 临时采样

- 样本仅保存在内存中，应用退出后丢弃。
- 使用 CreateJS Ticker 的实测 Tick 间隔判断游戏是否持续达到目标节奏；单独的页面 `requestAnimationFrame` 不能代表游戏实际更新帧率，因此不作为降级依据。
- 使用 Flutter `FrameTiming` 判断客户端覆盖层是否同时出现连续慢帧。
- 不记录设备型号、品牌、WebView 版本或历史样本。

### 自动降级规则

- 页面进入稳定游戏阶段后再开始采样，登录、首屏加载和渲染模式重启期间不采样。
- 自动模式先尝试 60 FPS。
- 每秒读取 1 次 CreateJS 实测 FPS，使用连续 5 秒的滑动窗口评估；窗口内少于 4 个有效样本时继续观察，不做决定。
- CreateJS 有至少 3 个有效样本低于 50 FPS 时，当前窗口判定为不稳定。
- Flutter 帧总耗时超过 32 ms 视为明显慢帧；窗口内至少产生 10 个 Flutter 帧且慢帧占比达到 20% 时，当前窗口判定为不稳定。Flutter 样本不足时只参考 CreateJS。
- 连续 2 个窗口不稳定时降为 30 FPS。
- 降级后设置本次运行锁，不再自动升回 60 FPS，避免反复切换。
- 手动 30/60 FPS 模式不使用自动降级规则。

### 动态应用

- 帧率变化通过受控 JavaScript 更新现有 CreateJS Ticker，不重新加载网页。
- 如果页面中尚未出现 CreateJS Ticker，则等待页面就绪后重试有限次数。
- 动态应用失败时保持游戏原始帧率，不影响捕获、导航和安全功能。
- 原生 `main.js` 补丁继续作为「优先 60 FPS」的首文档兜底，但必须与运行时策略使用同一枚举。

## HCPP 接入

- 项目使用 Flutter 3.44.8，具备 HCPP 接入条件。
- Android Manifest 的 `<application>` 节点加入 Flutter 官方配置：`io.flutter.embedding.android.EnableHcpp=true`。
- HCPP 只会影响 Hybrid Composition 路径；标准 Texture 模式保持不变。
- 运行设备需要 Android API 34 以上、Vulkan 和 Impeller。Flutter 在条件不满足时自动回退。
- HCPP 不作为玩家设置项，不显示设备能力判断结果。
- 由于 HCPP 仍属实验能力，Android 构建和三种模式回归测试必须覆盖启用配置。

## 错误处理与安全

- 性能模块的初始化失败不得阻止游戏 WebView 加载。
- 后台解析失败沿用安全的类型化错误，不把响应正文写入日志。
- 帧率 JavaScript 只读取和设置 CreateJS Ticker，不发送游戏请求，不触发 DOM 事件。
- HCPP 回退由 Flutter 平台能力判断完成，业务代码不猜测厂商能力。
- 数据捕获桥仍必须在首导航前安装，不能因性能优化恢复旧的初始化竞态。

## 测试策略

### Dart 单元测试

- 旧帧率布尔值到新枚举的迁移。
- 自动、30 FPS 和 60 FPS 的存储往返。
- 自动策略在稳定窗口中保持 60 FPS。
- 自动策略在连续不稳定窗口后只降级一次。
- 登录和加载阶段不采样。
- 后台解码保持事件提交顺序。
- 同一帧内的重复通知被合并。

### Flutter Widget 测试

- 信息面板更新不替换 `GameWebView`。
- 工具栏收起后不存在持续动画。
- 三种渲染模式继续选择正确的 Platform View 路径。
- 帧率设置三档文案在简体中文、繁体中文和日文中完整显示。

### Android 单元与构建测试

- CreateJS 30/60 FPS 脚本只修改目标对象。
- `main.js` 拦截与新帧率枚举一致。
- HCPP Manifest 配置存在。
- `:app:testDebugUnitTest` 通过。
- Debug APK 和 Release APK 至少各完成一次不安装构建。

### 开发阶段人工验证

- 使用 Profile 构建和 Flutter DevTools 检查 UI、Raster 慢帧。
- 使用 Chrome DevTools Performance 检查 WebView `requestAnimationFrame` 节奏。
- 使用 Android Studio Profiler 检查 CPU、GPU 和内存趋势。
- 不登录用户账号；需要真实游戏页面验证时，由用户自行安装测试包并反馈。

## 技术依据

- [Flutter Android Platform Views 与 HCPP](https://docs.flutter.dev/platform-integration/android/platform-views)
- [Flutter DevTools 性能视图](https://docs.flutter.dev/tools/devtools/performance)
- [Android 刷新率优化](https://developer.android.com/games/optimize/display-refresh-rate-change)

## 交付与回滚

按以下批次分别提交：

1. WebView 重绘边界与工具栏静止优化。
2. 后台 JSON 解码与通知合并。
3. 帧率三档设置、迁移和运行时自动降级。
4. HCPP 配置与平台回归。
5. 全套测试、三语文案检查和构建验证。

每个批次必须可独立回滚。任何批次不得混入当前工作区其他未提交功能。若 HCPP 出现平台回归，可单独撤销其 Manifest 提交，不影响帧率和后台解析模块。

## 验收标准

- 三种渲染模式均能加载网页并持续捕获数据。
- 标准模式仍为默认模式，且布局、工具栏和信息功能不变。
- 自动帧率只在当次运行中采样，不创建性能日志或上传数据。
- 自动模式降到 30 FPS 后不在本次运行中反复升降。
- 大型响应 JSON 不在 Dart UI Isolate 中解码。
- 同一 Controller 每个 Flutter 帧最多发出一次合并通知。
- HCPP 在支持设备上可用，在不支持设备上自动回退。
- 简体中文、繁体中文和日文文案同步。
- 自动化测试、静态分析和 Android APK 构建通过。
