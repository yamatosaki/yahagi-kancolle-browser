# ヤハギ (Yahagi) 移动端原型 - 技术交接文档

## 1. 项目概述 (Project Overview)
本项目是一个专为移动端设计的《舰队Collection (Kancolle)》辅助工具（代号：ヤハギ Yahagi）。
其核心机制是通过内置浏览器 (WebView) 代理/劫持游戏网络请求，实时提取 API 数据包进行反序列化，从而实现游戏状态监控、战果记录、统计图表等功能，而不干预游戏正常运行。

**技术栈**: Flutter (Dart), `webview_flutter`, `sqflite`, `fl_chart`.

## 2. 核心架构与数据流 (Architecture & Data Flow)

### 2.1 网络拦截 (Network Interception)
- **核心组件**: `GameCaptureController`
- **机制**: 在 Android 上利用 `webview_flutter_android` 的 `onWebResourceResponse` (或其他平台对应的拦截机制)，过滤 `URL` 包含 `/kcsapi/` 的请求。
- **数据解码**: `GameApiDecoder` 负责去除服务器返回体中特有的 `svdata=` 前缀，并将其转为标准 JSON 字典。

### 2.2 状态管理与解析 (State Management)
- **核心组件**: `GameStateController` & `GameStateReducer`
- **机制**: 拦截到的 JSON 数据会触发 `CapturedApiEvent`，并通过 Reducer 进行解析。
- **持久化状态**: `GameState` 包含了舰队状态、船只信息 (HP/状态/疲劳)、资源、远征等。采用纯函数 `copyWith` 模式，确保状态变更是响应式的。
- **Master Data (基础数据)**: 游戏启动时会通过 `api_start2/getData` 缓存舰娘、装备和地图的基础字典（用于把 ID 映射为真实的中文/日文名字）。

## 3. 持久化存储 (Persistence)
采用 `sqflite` 构建本地 SQLite 数据库 (`LogbookDatabase`)。

- **`battle_logs`**: 记录战斗结果（地图、评级、掉落 ID 等）。目前 UI 层已实现通过 `masterShips` 字典将 `drop_ship_id` 实时转义为舰娘名字。
- **`resource_logs`**: 记录母港刷新 (`api_port/port`) 时的四项资源，用于绘制资源走势图。
- **`expedition_logs`**: 拦截 `api_req_mission/result` 记录远征大成功/成功状态及具体收益。
- **`construction_logs`**: 记录建造历史。

> 提示：记录远征和资源刷新时，匹配 URL 使用了 `.endsWith('/api_req_mission/result')` 以增强对不同网络代理环境的兼容性。

## 4. UI 架构与设计 (UI & Design)

### 4.1 全局主题
- 采用了现代化深色主题 (Dark Theme)。
- 强调扁平化与发光效果，主背景色倾向于 `Color(0xff121212)`，面板使用边框和柔和阴影 (`BoxShadow`)。

### 4.2 游戏工具栏 (GameBrowserToolbar)
- **毛玻璃特效 (Glassmorphism)**: 采用 `BackdropFilter` 配合 `Colors.black.withOpacity(0.5)`，使工具栏在悬浮时不完全遮挡游戏画面（类似 iOS 控制中心风格）。
- **主要按钮**: 包含 刷新、主页、后退、截图 (Screenshot)、静音 及 展开/收起 按钮。

### 4.3 主要功能面板
- **舰队信息中心 (Dashboard)**:
  - 左侧边栏/底部导航用于多页面切换。
  - 实时展示母港资源、入渠队列和建造队列倒计时。
- **实时战斗面板 (Live Battle)**:
  - 拦截出击和战斗 API 实时计算血量变化。
  - 使用了自适应进度条 (HP Bar) 和红绿颜色区分敌我。
- **战果日志 (Logbook)**:
  - **图表展示**: 使用 `fl_chart` 绘制资源折线图和远征收益柱状图。
    - **避坑指南**: 当数据库点数不足（< 2个点）时，`fl_chart` 的曲线模式 (`isCurved: true`) 或 `maxY=0` 会引发底层越界崩溃。代码中已增加动态判定（`isCurved: data.length > 2`）并兜底了 `maxY`。

### 4.4 App 图标与品牌 (Branding)
- **Logo**: 采用了圆形的 ヤハギ 头像。
- **Android 适配**: 针对 Android 8.0+ 的 Adaptive Icons，在 `pubspec.yaml` 中配置了 `adaptive_icon_background: "#FFFFFF"` 和 `adaptive_icon_foreground: "assets/app_icon.png"`（且图片已做纯净的去黑底处理），确保图标尺寸饱满，无默认的白边缩小问题。

## 5. 后续开发路线图 (Future Roadmap)

接手后续开发时，可以优先考虑实现以下已经规划但暂时搁置的功能：

1. **出击前安全检查 (大破防沉拦截)**
   - 监听 `/kcsapi/api_req_map/start` 和 `next`。
   - 读取当前出击舰队的 HP。若 `(当前HP / 最大HP) <= 0.25` (大破)，且装备栏中没有损管 (Damage Control)，则中断网络请求并弹出红色警告 UI。
2. **断网防猫处理 (Network Stability/Error Recovery)**
   - 在 `WebView` 的 `onWebResourceError` 中，注入自定义的优雅错误页面（而不是白屏）。
   - 提供快速刷新按钮重新连接。
3. **沉浸式防误触模式 (Immersive Mode)**
   - 在游戏进行时（出击中），利用 Flutter 的 `SystemChrome.setEnabledSystemUIMode` 隐藏状态栏。
   - 增加一个锁定按钮（使用 `AbsorbYahaginter`），防止误触返回导致游戏刷新。
4. **任务系统集成 (Quest Tracker)**
   - 拦截并记录每日/每周任务列表，持久化任务进度。
