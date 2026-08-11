# 全机型游戏画面流畅度优化实施计划

> **面向 AI 代理的工作者：** 在当前会话中按任务顺序执行；每个行为变更严格遵循测试驱动开发（TDD），先观察目标测试失败，再写最小实现。每个任务完成后独立提交。

**目标：** 在不改变现有布局、数据功能和三种渲染模式的前提下，隔离 WebView 重绘、后台处理大型游戏数据、合并捕获通知、提供自动/30/60 FPS 策略，并在支持设备上启用 HCPP。

**架构：** 保留 `GameWebView` 和原生捕获桥作为游戏入口。新增有序事件预处理管线，使大型 JSON 只在后台 Isolate 解码一次，并将预解码结果复用于 GameState、Battle、Senka 和日志记录；捕获引起的 Controller 通知通过逐帧合并器限流。帧率由持久化枚举、纯策略状态机、WebView 运行时端口和 Android 首文档补丁共同完成；HCPP 只通过官方 Manifest 元数据接入。

**技术栈：** Flutter 3.44.8、Dart 3.12、Android WebView、AndroidX WebKit、Kotlin、SharedPreferences、Dart Isolate、Flutter FrameTiming、CreateJS Ticker。

---

## 工作区约束

- 当前分支：`feature/game-rendering-compatibility`。
- 不启动或安装应用，不登录用户账号。
- `lib/src/logbook/logbook_page.dart` 的现有修改与本计划无关，不得暂存。
- 工作区中存在大量其他未跟踪功能文件，不得使用 `git add .`。
- 下列帧率文件虽然当前未跟踪，但属于本计划直接改造范围，只能在对应任务中精确暂存：
  - `lib/src/browser/game_frame_rate_port.dart`
  - `lib/src/settings/game_frame_rate_settings.dart`
  - `lib/src/settings/game_frame_rate_settings_section.dart`
  - `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`
  - `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScript.kt`
  - `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScriptTest.kt`
  - `test/game_frame_rate_settings_test.dart`
  - `test/game_frame_rate_settings_section_test.dart`
- 每次提交前运行 `git diff --cached --check` 和 `git diff --cached --stat`，确认只包含当前任务文件。

## 文件职责

### 游戏表面

- 修改：`lib/src/browser/game_browser_overlay.dart`——将游戏子树移出工具栏监听构建器，工具栏隐藏动画结束后卸载透明层。
- 修改：`lib/main.dart`——在游戏区域建立稳定的 `RepaintBoundary`，并保持非模式切换时的 WebView 身份。
- 修改：`test/game_browser_overlay_test.dart`——验证隐藏后工具栏退出树、游戏 Element 不被替换。
- 创建：`test/game_surface_rebuild_isolation_test.dart`——验证信息状态更新不替换游戏子树。

### 捕获事件后台预处理

- 修改：`lib/src/bridge/captured_api_event.dart`——携带可选的预解码 JSON 外层对象，不改变原始正文。
- 修改：`lib/src/game_state/game_api_decoder.dart`——从原始正文或预解码外层对象读取 `api_data`。
- 创建：`lib/src/game_state/game_api_event_pipeline.dart`——按事件顺序选择后台解码并分发给消费者。
- 修改：`lib/src/game_state/game_state_reducer.dart`——公开路径支持判断并复用预解码结果。
- 修改：`lib/src/game_state/game_state_controller.dart`——实现事件消费者接口。
- 修改：`lib/src/battle/battle_controller.dart`——公开路径支持判断并复用预解码结果。
- 修改：`lib/src/senka/senka_reducer.dart`、`lib/src/senka/senka_controller.dart`——公开路径支持判断并复用预解码结果。
- 修改：`lib/src/logbook/logbook_event_recorder.dart`——复用预解码结果。
- 修改：`lib/main.dart`——将捕获回调接到有序预处理管线，并把管线 `idle` 纳入 WebView 重启屏障。
- 创建：`test/game_api_event_pipeline_test.dart`——验证阈值、后台执行、顺序和失败恢复。
- 修改：`test/game_state_reducer_test.dart`、`test/battle_controller_test.dart`、`test/senka_reducer_test.dart`——验证预解码路径与原始路径等价。

### 通知合并与战斗预测

- 创建：`lib/src/performance/frame_notification_coalescer.dart`——每个 Flutter 帧最多调用一次捕获通知。
- 修改：`lib/src/game_state/game_state_controller.dart`、`lib/src/battle/battle_controller.dart`、`lib/src/senka/senka_controller.dart`——仅对捕获事件引起的通知使用合并器；设置和手动操作保持即时通知。
- 创建：`test/frame_notification_coalescer_test.dart`——验证同帧合并、下一帧恢复和销毁安全。
- 修改：`test/game_state_controller_test.dart`、`test/battle_controller_test.dart`、`test/senka_controller_test.dart`——验证状态立即归并，但监听通知按帧合并。
- 创建：`lib/src/battle/prediction/battle_prediction_executor.dart`——在后台 Isolate 执行有状态预测引擎，并返回更新后的引擎与预测结果。
- 修改：`lib/src/battle/battle_controller.dart`——串行等待后台预测结果后继续安全提醒和状态提交。
- 创建：`test/battle_prediction_executor_test.dart`——验证预测状态跨阶段保持、后台异常进入现有错误路径。

### 帧率策略

- 修改：`lib/src/settings/game_frame_rate_settings.dart`——用 `GameFrameRateMode` 枚举替代布尔值并迁移旧设置。
- 修改：`lib/src/settings/game_frame_rate_settings_section.dart`——显示自动、稳定 30 FPS、优先 60 FPS 三档设置。
- 修改：`lib/src/browser/game_frame_rate_port.dart`——原生端口接收枚举；新增 WebView 运行时端口。
- 创建：`lib/src/browser/game_frame_rate_policy.dart`——纯状态机，处理 5 秒窗口和单向自动降级。
- 创建：`lib/src/browser/game_frame_rate_runtime_controller.dart`——临时采样 CreateJS 和 Flutter FrameTiming，不持久化样本。
- 创建：`lib/src/browser/game_frame_rate_script.dart`——生成受控的 Ticker 设置和实测 FPS 查询脚本。
- 修改：`lib/src/game_webview.dart`——页面稳定后连接运行时端口，销毁时停止采样。
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`——接收 `auto`、`stable30`、`prefer60`。
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScript.kt`——仅在 `auto` 或 `prefer60` 时补丁首文档。
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClient.kt`、`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`——把布尔判断替换为枚举策略。
- 修改：`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`——补齐三档文案。
- 生成：`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`。
- 修改：现有帧率 Dart、Widget 和 Kotlin 测试。
- 创建：`test/game_frame_rate_policy_test.dart`、`test/game_frame_rate_script_test.dart`、`test/game_frame_rate_runtime_controller_test.dart`。

### HCPP 与最终验证

- 修改：`android/app/src/main/AndroidManifest.xml`——加入 `io.flutter.embedding.android.EnableHcpp=true`。
- 创建：`test/android_hcpp_manifest_test.dart`——验证元数据位于 `<application>` 节点且值为 `true`。

---

## 任务 1：隔离游戏表面与工具栏重绘

**文件：**

- 修改：`lib/src/browser/game_browser_overlay.dart`
- 修改：`lib/main.dart`
- 修改：`test/game_browser_overlay_test.dart`
- 创建：`test/game_surface_rebuild_isolation_test.dart`

- [ ] **步骤 1：编写失败的工具栏卸载测试**

在 `test/game_browser_overlay_test.dart` 增加：

```dart
testWidgets('removes the hidden toolbar after its exit animation', (
  tester,
) async {
  final controller = GameToolbarController();
  await tester.pumpWidget(_TestApp(controller: controller));

  controller.collapse();
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('fake-toolbar')), findsNothing);
  expect(find.byKey(const Key('game-toolbar-swipe-zone')), findsOneWidget);
});
```

- [ ] **步骤 2：编写失败的游戏子树稳定性测试**

使用带 `StatefulWidget` 计数器的假游戏表面。保存其 `Element`，切换工具栏显隐和信息面板状态后断言 `identical(before, after)` 为真。

- [ ] **步骤 3：运行测试并确认红灯**

运行：

```powershell
flutter test test/game_browser_overlay_test.dart test/game_surface_rebuild_isolation_test.dart
```

预期：隐藏工具栏仍可被找到，或新的隔离测试因缺少稳定边界而失败。

- [ ] **步骤 4：实现最小重绘隔离**

目标结构：

```dart
Stack(
  children: <Widget>[
    RepaintBoundary(
      key: const Key('game-surface-repaint-boundary'),
      child: widget.gameSurface,
    ),
    AnimatedBuilder(
      animation: widget.controller,
      builder: _buildToolbarLayer,
    ),
  ],
)
```

工具栏退出动画完成后将其从树中移除；重新显示时先挂载，再播放进入动画。滑动唤出区域始终保留。`lib/main.dart` 的 `AspectRatio` 内只放稳定的游戏表面边界，不监听 GameState、Battle 或 Senka。

- [ ] **步骤 5：运行测试并确认绿灯**

```powershell
flutter test test/game_browser_overlay_test.dart test/game_surface_rebuild_isolation_test.dart test/game_environment_host_test.dart
```

预期：全部通过。

- [ ] **步骤 6：静态分析并提交**

```powershell
flutter analyze lib/src/browser/game_browser_overlay.dart lib/main.dart test/game_browser_overlay_test.dart test/game_surface_rebuild_isolation_test.dart
git add -- lib/src/browser/game_browser_overlay.dart lib/main.dart test/game_browser_overlay_test.dart test/game_surface_rebuild_isolation_test.dart
git diff --cached --check
git commit -m "perf(游戏画面): 隔离 WebView 与工具栏重绘"
```

## 任务 2：建立有序的后台 JSON 预处理管线

**文件：**

- 修改：`lib/src/bridge/captured_api_event.dart`
- 修改：`lib/src/game_state/game_api_decoder.dart`
- 创建：`lib/src/game_state/game_api_event_pipeline.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 修改：`lib/src/game_state/game_state_controller.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/src/senka/senka_reducer.dart`
- 修改：`lib/src/senka/senka_controller.dart`
- 修改：`lib/src/logbook/logbook_event_recorder.dart`
- 修改：`lib/main.dart`
- 创建：`test/game_api_event_pipeline_test.dart`
- 修改：`test/game_state_reducer_test.dart`
- 修改：`test/battle_controller_test.dart`
- 修改：`test/senka_reducer_test.dart`

- [ ] **步骤 1：定义预解码事件的失败测试**

期望 API：

```dart
final prepared = event.withDecodedEnvelope(<String, Object?>{
  'api_result': 1,
  'api_data': <String, Object?>{'api_value': 7},
});

expect(GameApiDecoder.decodeEventData(prepared), <String, Object?>{
  'api_value': 7,
});
```

另加一条测试，把原始正文改为无效 JSON，确认存在预解码外层对象时仍成功，证明 Reducer 不会再次解析正文。

- [ ] **步骤 2：定义管线阈值与顺序的失败测试**

期望接口：

```dart
final pipeline = GameApiEventPipeline(
  consumers: <GameApiEventConsumer>[consumer],
  decodeEnvelope: (body) async {
    decodeCalls.add(body);
    return GameApiDecoder.decodeEnvelope(body);
  },
  backgroundThresholdBytes: 64 * 1024,
);
```

覆盖以下行为：

- 小于 64 KiB 的普通响应直接分发，不调用后台解码器。
- `api_start2/getData` 无论大小都调用后台解码器。
- 大于等于 64 KiB 且至少一个消费者支持的响应调用一次解码器。
- 不被任何消费者支持的响应不解码。
- 第 1 个事件的后台解码未完成前，第 2 个事件不能先分发。
- 解码失败后第 2 个事件仍能分发，失败事件原样交给消费者，由现有错误路径处理。

- [ ] **步骤 3：运行目标测试并确认红灯**

```powershell
flutter test test/game_api_event_pipeline_test.dart test/game_state_reducer_test.dart test/battle_controller_test.dart test/senka_reducer_test.dart
```

预期：缺少 `withDecodedEnvelope`、`decodeEventData` 和 `GameApiEventPipeline`。

- [ ] **步骤 4：实现预解码载体与解码器**

核心接口：

```dart
class CapturedApiEvent {
  final Map<String, Object?>? decodedEnvelope;

  bool get hasDecodedEnvelope => decodedEnvelope != null;

  CapturedApiEvent withDecodedEnvelope(Map<String, Object?> envelope) =>
      CapturedApiEvent(
        method: method,
        path: path,
        requestParams: requestParams,
        responseBody: responseBody,
        statusCode: statusCode,
        source: source,
        sourceOrigin: sourceOrigin,
        capturedAt: capturedAt,
        sequence: sequence,
        decodedEnvelope: envelope,
      );
}
```

`GameApiDecoder` 拆分为 `decodeEnvelope(String)` 和 `decodeEventData(CapturedApiEvent, {allowMissingData})`。验证 `api_result` 和 `api_data` 的逻辑只保留一份。

- [ ] **步骤 5：实现消费者和有序管线**

```dart
abstract interface class GameApiEventConsumer {
  bool supportsPath(String path);
  void accept(CapturedApiEvent event);
  Future<void> get idle;
}

final class GameApiEventPipeline {
  void add(CapturedApiEvent event) {
    _queue = _queue.then((_) => _prepareAndDispatch(event));
  }

  Future<void> get idle => _queue;
}
```

默认后台解码器使用 `Isolate.run`。路径支持判断由各 Controller 暴露，不能在管线中复制业务路径清单。

- [ ] **步骤 6：让所有消费者复用预解码结果**

将以下调用替换为 `GameApiDecoder.decodeEventData(event)`：

- `GameStateReducer.reduce`
- `BattleController._reduce`
- `SenkaReducer.reduce`
- `LogbookEventRecorder` 中的响应解码

GameState、Battle、Senka Controller 实现 `GameApiEventConsumer`。`lib/main.dart` 将 `GameCaptureController.onAcceptedEvent` 改为 `pipeline.add`，并在 `_waitForCaptureQueues()` 中先等待 `pipeline.idle`，再等待 3 个消费者的 `idle`。

- [ ] **步骤 7：运行测试并确认绿灯**

```powershell
flutter test test/game_api_event_pipeline_test.dart test/game_state_reducer_test.dart test/game_state_controller_test.dart test/battle_controller_test.dart test/senka_reducer_test.dart test/senka_controller_test.dart test/logbook_event_recorder_test.dart
```

预期：全部通过；预解码和原始正文路径生成相同状态。

- [ ] **步骤 8：静态分析并提交**

精确暂存本任务文件后提交：

```powershell
git commit -m "perf(数据捕获): 后台预解码大型游戏响应"
```

## 任务 3：合并捕获事件引起的界面通知

**文件：**

- 创建：`lib/src/performance/frame_notification_coalescer.dart`
- 修改：`lib/src/game_state/game_state_controller.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/src/senka/senka_controller.dart`
- 创建：`test/frame_notification_coalescer_test.dart`
- 修改：`test/game_state_controller_test.dart`
- 修改：`test/battle_controller_test.dart`
- 修改：`test/senka_controller_test.dart`

- [ ] **步骤 1：编写逐帧合并器失败测试**

期望 API：

```dart
final scheduled = <VoidCallback>[];
final coalescer = FrameNotificationCoalescer(
  scheduleFrame: scheduled.add,
);

var calls = 0;
coalescer.schedule(() => calls++);
coalescer.schedule(() => calls++);
expect(scheduled, hasLength(1));

scheduled.removeAt(0)();
expect(calls, 1);
```

同时验证下一帧可再次通知，以及 `dispose()` 后已排队回调不执行。

- [ ] **步骤 2：编写 Controller 通知合并失败测试**

连续向每个 Controller 送入 2 个支持的捕获事件，等待 `idle` 后确认状态已经更新；在测试调度器执行前监听次数为 0，执行一次帧回调后监听次数为 1。

- [ ] **步骤 3：运行测试并确认红灯**

```powershell
flutter test test/frame_notification_coalescer_test.dart test/game_state_controller_test.dart test/battle_controller_test.dart test/senka_controller_test.dart
```

预期：缺少合并器，现有 Controller 每个事件分别通知。

- [ ] **步骤 4：实现最小合并器并接入捕获路径**

默认调度器使用 `SchedulerBinding.instance.scheduleFrameCallback`，并调用 `scheduleFrame()` 确保无动画页面也会产生下一帧。Controller 的初始化、设置修改、手动战果校准等非捕获行为继续直接 `notifyListeners()`。

- [ ] **步骤 5：运行测试并确认绿灯**

```powershell
flutter test test/frame_notification_coalescer_test.dart test/game_state_controller_test.dart test/battle_controller_test.dart test/senka_controller_test.dart test/battle_result_warning_overlay_test.dart
```

- [ ] **步骤 6：静态分析并提交**

```powershell
git commit -m "perf(状态更新): 合并同帧游戏数据通知"
```

## 任务 4：将战斗预测纯计算移到后台 Isolate

**文件：**

- 创建：`lib/src/battle/prediction/battle_prediction_executor.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 创建：`test/battle_prediction_executor_test.dart`
- 修改：`test/battle_controller_test.dart`

- [ ] **步骤 1：编写有状态预测执行器失败测试**

期望 API：

```dart
final first = await executor.append(
  engine: engine,
  path: dayPath,
  data: dayData,
);
final second = await executor.append(
  engine: first.engine,
  path: nightPath,
  data: nightData,
);

expect(second.prediction.enemyMain.single.currentHp, expectedNightHp);
```

测试必须证明第 2 阶段使用第 1 阶段返回的更新后引擎，而不是每次创建新引擎。

- [ ] **步骤 2：编写 BattleController 异常恢复测试**

注入抛出异常的执行器，送入战斗事件并等待 `idle`。断言 Controller 进入现有安全错误状态，下一次地图事件仍可继续处理。

- [ ] **步骤 3：运行测试并确认红灯**

```powershell
flutter test test/battle_prediction_executor_test.dart test/battle_controller_test.dart
```

- [ ] **步骤 4：实现后台执行器**

```dart
typedef BattlePredictionAppendResult = ({
  BattlePredictionEngine engine,
  BattlePrediction prediction,
});

abstract interface class BattlePredictionExecutor {
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  });
}
```

默认实现通过 `Isolate.run` 在后台副本上调用 `engine.append`，把更新后的引擎和预测一起返回。测试可注入同步执行器，避免依赖真实 Isolate 时序。

- [ ] **步骤 5：把 BattleController 处理链改为异步串行**

`_reduce` 和 `_applyBattlePhase` 返回 `Future<void>`。Controller 原有 `_queue` 继续保证地图、昼战、夜战和结算严格顺序。只有预测引擎执行移出 UI Isolate；振动、安全提醒、Session 和 UI 状态仍在主 Isolate 提交。

- [ ] **步骤 6：运行战斗回归并确认绿灯**

```powershell
flutter test test/battle_prediction_executor_test.dart test/battle_controller_test.dart test/poi_battle_prediction_engine_test.dart test/yahagi_battle_prediction_engine_test.dart
```

- [ ] **步骤 7：静态分析并提交**

```powershell
git commit -m "perf(战斗预测): 将纯计算移入后台 Isolate"
```

## 任务 5：迁移为自动、30 FPS、60 FPS 三档设置

**文件：**

- 修改：`lib/src/settings/game_frame_rate_settings.dart`
- 修改：`lib/src/settings/game_frame_rate_settings_section.dart`
- 修改：`lib/src/browser/game_frame_rate_port.dart`
- 修改：`test/game_frame_rate_settings_test.dart`
- 修改：`test/game_frame_rate_settings_section_test.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写存储迁移失败测试**

定义枚举：

```dart
enum GameFrameRateMode { automatic, stable30, prefer60 }
```

覆盖：

- 新安装无任何键时为 `automatic`。
- `game.unlockFrameRate=true` 迁移为 `prefer60`。
- `game.unlockFrameRate=false` 迁移为 `stable30`。
- 旧字符串 `max60`、`followDisplay` 迁移为 `prefer60`。
- 旧字符串 `off` 迁移为 `stable30`。
- 新枚举键往返，未知值回退 `automatic`。

- [ ] **步骤 2：编写三档设置 UI 失败测试**

验证 `SegmentedButton<GameFrameRateMode>` 存在 3 个选项，简中、繁中、日文均显示对应标题和说明。选择后立即调用 Controller，不再显示「重新加载后生效」提示。

- [ ] **步骤 3：运行测试并确认红灯**

```powershell
flutter test test/game_frame_rate_settings_test.dart test/game_frame_rate_settings_section_test.dart
```

预期：当前布尔接口和单个 Switch 不满足测试。

- [ ] **步骤 4：实现枚举存储和 Controller**

端口接口改为：

```dart
abstract interface class GameFrameRatePort {
  Future<bool> isSupported();
  Future<void> configure(GameFrameRateMode mode);
}
```

Controller 暴露 `mode` 和 `setMode`。持久化成功后立即配置已连接端口；端口失败不回滚玩家持久化选择，但更新 `supported=false` 并安全保持游戏原始帧率。

- [ ] **步骤 5：实现三档 UI 与三语文案**

更新 3 个 ARB 后运行：

```powershell
flutter gen-l10n
```

不得直接手改生成文件。运行项目现有本地化守卫，确认三种语言键集合一致且没有新增硬编码中文。

- [ ] **步骤 6：运行测试并提交**

```powershell
flutter test test/game_frame_rate_settings_test.dart test/game_frame_rate_settings_section_test.dart test/localization_resource_guard_test.dart
git commit -m "feat(帧率): 提供自动与稳定 30/60 FPS 三档设置"
```

## 任务 6：实现运行时帧率策略和临时采样

**文件：**

- 创建：`lib/src/browser/game_frame_rate_policy.dart`
- 创建：`lib/src/browser/game_frame_rate_script.dart`
- 创建：`lib/src/browser/game_frame_rate_runtime_controller.dart`
- 修改：`lib/src/browser/game_frame_rate_port.dart`
- 修改：`lib/src/game_webview.dart`
- 创建：`test/game_frame_rate_policy_test.dart`
- 创建：`test/game_frame_rate_script_test.dart`
- 创建：`test/game_frame_rate_runtime_controller_test.dart`

- [ ] **步骤 1：编写纯策略失败测试**

目标规则：

```dart
policy.addCreateJsSample(49);
policy.addCreateJsSample(48);
policy.addCreateJsSample(47);
policy.addCreateJsSample(55);
policy.addCreateJsSample(56);
expect(policy.completeWindow(), FrameRateDecision.keep60);

// 第二个连续不稳定窗口
addAnotherUnstableWindow(policy);
expect(policy.completeWindow(), FrameRateDecision.downgradeTo30);
expect(policy.completeWindow(), FrameRateDecision.lock30);
```

另测 Flutter 窗口：至少 10 帧，`totalSpan > 32 ms` 的比例达到 20% 才判定不稳定；样本不足时不单独触发降级。手动模式永不自动降级。

- [ ] **步骤 2：编写 JavaScript 生成器失败测试**

验证：

- 30 FPS 脚本只设置 CreateJS Ticker 为稳定 30 FPS。
- 60 FPS 脚本只设置 Ticker 为 RAF/60，不覆盖全局 `requestAnimationFrame`。
- 查询脚本调用 `createjs.Ticker.getMeasuredFPS`，缺少 Ticker 时返回 `null`。
- 脚本不包含 `fetch`、`XMLHttpRequest`、`click`、`dispatchEvent`。

- [ ] **步骤 3：编写运行时 Controller 失败测试**

使用假的 WebView 端口、定时器和 FrameTiming 输入，验证：

- 登录和 `loadingGame` 阶段不采样。
- `ready` 后自动模式先应用 60 FPS。
- 每秒最多查询 1 次实测 FPS。
- 连续 2 个不稳定窗口后只调用一次 30 FPS。
- `dispose()` 后停止定时器并移除 `addTimingsCallback`。
- 样本不写入 SharedPreferences，也没有上传端口。

- [ ] **步骤 4：运行测试并确认红灯**

```powershell
flutter test test/game_frame_rate_policy_test.dart test/game_frame_rate_script_test.dart test/game_frame_rate_runtime_controller_test.dart
```

- [ ] **步骤 5：实现纯策略、脚本和运行时端口**

运行时端口：

```dart
abstract interface class GameFrameRateRuntimePort {
  Future<void> apply(GameFrameRateTarget target);
  Future<double?> measuredFps();
}
```

WebView 实现只调用 `runJavaScript` 和 `runJavaScriptReturningResult`。返回值必须严格转换为有限的非负 `double`，其他结果视为无样本。

- [ ] **步骤 6：接入 GameWebView 生命周期**

- 在兼容配置和捕获桥准备完成后创建运行时 Controller。
- 运行时 Controller 监听 `GameFrameRateSettingsController`；玩家切换三档设置后立即应用到当前页面，并重置尚未锁定的自动采样窗口。
- `onPageStarted` 暂停采样。
- 游戏页面 `onPageFinished` 完成对齐、捕获和音频初始化后，先把启动状态改为 `ready`，再开始采样。
- 页面重载时清空当前窗口，但保留本次运行已降级锁。
- `dispose` 时停止采样。
- 初始化或脚本失败时不阻止导航、捕获或音频端口。

- [ ] **步骤 7：运行回归并提交**

```powershell
flutter test test/game_frame_rate_policy_test.dart test/game_frame_rate_script_test.dart test/game_frame_rate_runtime_controller_test.dart test/game_webview_compatibility_test.dart test/game_capture_startup_sequence_test.dart
git commit -m "feat(帧率): 按当次运行表现自动降至 30 FPS"
```

## 任务 7：同步 Android 首文档帧率补丁

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScript.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClient.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScriptTest.kt`
- 修改：`test/android_game_capture_port_test.dart`（仅在通道共存测试需要时）

- [ ] **步骤 1：编写 Kotlin 模式映射失败测试**

覆盖：

- `auto` 和 `prefer60` 允许补丁 `main.js`。
- `stable30` 不补丁远程脚本。
- 未知值安全回退 `auto`。
- 60 FPS 补丁保持域名和 `/kcs2/js/main.js` 限制。

- [ ] **步骤 2：运行 Kotlin 测试并确认红灯**

```powershell
Set-Location android
.\gradlew.bat :app:testDebugUnitTest --tests "*GameFrameRateScriptTest"
Set-Location ..
```

- [ ] **步骤 3：实现原生枚举和通道映射**

```kotlin
enum class GameFrameRateMode(val wireName: String) {
    AUTO("auto"),
    STABLE_30("stable30"),
    PREFER_60("prefer60");

    val patchesMainScript: Boolean
        get() = this != STABLE_30
}
```

MainActivity 和 `GadgetBypassWebViewClient` 只询问 `patchesMainScript`，不判断品牌或 Android 型号。

- [ ] **步骤 4：运行 Android 回归并提交**

```powershell
Set-Location android
.\gradlew.bat :app:testDebugUnitTest
Set-Location ..
git commit -m "feat(Android帧率): 同步三档首文档策略"
```

## 任务 8：启用 HCPP 并验证自动回退配置

**文件：**

- 修改：`android/app/src/main/AndroidManifest.xml`
- 创建：`test/android_hcpp_manifest_test.dart`

- [ ] **步骤 1：编写 Manifest 失败测试**

```dart
test('enables Flutter HCPP inside the Android application node', () {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  expect(manifest, contains('io.flutter.embedding.android.EnableHcpp'));
  expect(manifest, contains('android:value="true"'));
});
```

测试应先提取完整 `<application>...</application>` 区块，再在该区块内匹配同一个 `<meta-data>` 标签的名称和值，不能只依赖文件中的两个独立字符串。

- [ ] **步骤 2：运行测试并确认红灯**

```powershell
flutter test test/android_hcpp_manifest_test.dart
```

- [ ] **步骤 3：添加官方 HCPP 元数据**

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableHcpp"
    android:value="true" />
```

不添加设备判断；Android API 34、Vulkan 或 Impeller 条件不满足时由 Flutter 自动回退。

- [ ] **步骤 4：运行模式与构建回归并提交**

```powershell
flutter test test/android_hcpp_manifest_test.dart test/game_rendering_mode_test.dart test/game_environment_host_test.dart
flutter build apk --debug
git commit -m "perf(Android合成): 为兼容模式启用 HCPP"
```

## 任务 9：完整回归、本地化守卫与交付构建

**文件：**

- 仅修复本计划直接引起的测试或静态分析问题。
- 不借机修改无关功能。

- [ ] **步骤 1：运行格式化和差异检查**

只格式化本计划修改的 Dart/Kotlin 文件。运行：

```powershell
git diff --check
git status --short
```

- [ ] **步骤 2：运行 Dart 与 Flutter 测试**

先运行性能和渲染相关测试集合：

```powershell
flutter test test/game_browser_overlay_test.dart test/game_surface_rebuild_isolation_test.dart test/game_api_event_pipeline_test.dart test/frame_notification_coalescer_test.dart test/battle_prediction_executor_test.dart test/game_frame_rate_settings_test.dart test/game_frame_rate_settings_section_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_script_test.dart test/game_frame_rate_runtime_controller_test.dart test/android_hcpp_manifest_test.dart test/game_rendering_mode_test.dart test/game_environment_host_test.dart test/game_capture_startup_sequence_test.dart test/android_game_capture_port_test.dart
```

再运行完整测试：

```powershell
flutter test
```

预期：0 项失败。

- [ ] **步骤 3：运行静态分析和本地化守卫**

```powershell
flutter analyze
flutter test test/localization_resource_guard_test.dart
```

如果完整 `flutter analyze` 暴露工作区既有问题，记录并区分；本计划修改文件必须 0 issue。

- [ ] **步骤 4：运行 Android 原生测试**

```powershell
Set-Location android
.\gradlew.bat :app:testDebugUnitTest
Set-Location ..
```

预期：`BUILD SUCCESSFUL`。

- [ ] **步骤 5：构建 Debug 与 Release APK**

```powershell
flutter build apk --debug
flutter build apk --release
```

只构建，不安装、不启动。记录 APK 路径、大小和 SHA256。

- [ ] **步骤 6：审查提交和工作区**

```powershell
git log --oneline 705de72..HEAD
git status --short
```

确认计划外既有修改仍保留，且没有被任何性能提交包含。

- [ ] **步骤 7：最终修复提交（仅在必要时）**

如果完整回归发现本计划内部集成问题，修复后重新运行受影响测试与完整构建，再提交：

```powershell
git commit -m "fix(性能优化): 修正全机型回归问题"
```

若没有额外修复，不创建空提交。

---

## 交付说明

最终向用户报告：

- 各批次提交哈希。
- 自动帧率规则和旧设置迁移结果。
- HCPP 的启用条件与自动回退行为。
- 不保存、不上传性能样本的确认。
- 测试、分析和构建的实际结果。
- Debug/Release APK 路径和 SHA256。
- 真机游戏页面尚需用户自行验证的边界。
