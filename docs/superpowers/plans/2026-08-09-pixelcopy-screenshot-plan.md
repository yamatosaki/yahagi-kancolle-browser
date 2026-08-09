# PixelCopy 游戏截图实现计划

> **面向 AI 代理的工作者：** 使用 executing-plans 在当前会话逐项实现；使用复选框跟踪进度。

**目标：** 在现代 Android 上可靠截取硬件加速的游戏 WebView，并保留旧系统回退与可诊断错误。

**架构：** 把 WebView 候选筛选和窗口矩形计算提取为无 Android 依赖的纯 Kotlin 策略并单元测试。`MainActivity` 负责把真实 View 映射为候选，在 API 26+ 异步调用 `PixelCopy`，低版本继续同步 `draw(Canvas)`；统一复用图片验证和相册保存函数。

**技术栈：** Kotlin、Android PixelCopy、MethodChannel、JUnit、Gradle。

---

## 文件结构

- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/capture/ScreenshotCapturePolicy.kt`：纯 Kotlin 候选选择和矩形数据。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/ScreenshotCapturePolicyTest.kt`：策略单元测试。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：选择可见 WebView、PixelCopy 异步捕获、旧系统回退、生命周期保护。
- 保留 `ScreenshotDestination.kt` 和现有 MediaStore/旧存储写入实现。
- 修改 `test/game_screenshot_controller_test.dart`：确认原生错误详情和并发合并行为不回归。

### 任务 1：建立失败的截图选择策略测试

**文件：**
- 创建：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/ScreenshotCapturePolicyTest.kt`

- [ ] 测试隐藏、未附着、宽高为零的候选被排除。
- [ ] 测试多个有效候选时选择面积最大者。
- [ ] 测试所选候选的窗口坐标生成正确的 `CaptureRect(left, top, right, bottom)`。
- [ ] 运行：`android/gradlew.bat :app:testDebugUnitTest --tests "*ScreenshotCapturePolicyTest"`。
- [ ] 预期：因策略类型尚不存在而编译失败。

### 任务 2：实现纯 Kotlin 捕获策略

**文件：**
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/capture/ScreenshotCapturePolicy.kt`

- [ ] 定义：

```kotlin
data class ScreenshotViewCandidate(
    val index: Int,
    val visible: Boolean,
    val attached: Boolean,
    val width: Int,
    val height: Int,
    val windowX: Int,
    val windowY: Int,
)

data class CaptureRect(val left: Int, val top: Int, val right: Int, val bottom: Int)
```

- [ ] `select` 过滤无效候选并使用 `width.toLong() * height` 选择最大面积，避免整数溢出。
- [ ] `captureRect` 使用窗口左上角加宽高计算边界。
- [ ] 重新运行策略测试，预期通过。

### 任务 3：先写 MainActivity 行为边界测试能覆盖的接口

**文件：**
- 修改：`test/game_screenshot_controller_test.dart`

- [ ] 添加 MethodChannel/伪端口错误断言：`pixel_copy_failed` 的详情被 `GameScreenshotResult.errorMessage` 保留。
- [ ] 运行：`flutter test test/game_screenshot_controller_test.dart`，确认现有控制器已经满足错误透传或得到精确失败证据。

### 任务 4：接入 PixelCopy

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`

- [ ] 导入 `PixelCopy`、`Rect`、`Handler`、`Looper` 及截图策略类型。
- [ ] 收集 WebView 后映射可见性、附着状态、尺寸、`getLocationInWindow` 坐标，选择最大有效候选；无候选返回 `webview_not_found`。
- [ ] API 26+ 创建目标 Bitmap 并调用：

```kotlin
PixelCopy.request(window, sourceRect, bitmap, { copyResult ->
    if (copyResult != PixelCopy.SUCCESS) {
        bitmap.recycle()
        result.error("pixel_copy_failed", "PixelCopy failed with code $copyResult.", null)
        return@request
    }
    finishScreenshot(bitmap, result)
}, Handler(Looper.getMainLooper()))
```

- [ ] API 25 及以下继续 `webView.draw(Canvas(bitmap))` 后调用相同的 `finishScreenshot`。
- [ ] `finishScreenshot` 只回调一次，检查空白、保存相册，并在 `finally` 回收 Bitmap。
- [ ] 捕获 `IllegalArgumentException`、无效源矩形和保存异常，分别返回明确错误；Activity 销毁时不重复完成已回调的请求。

### 任务 5：Android 编译与回归

- [ ] 运行：`android/gradlew.bat :app:testDebugUnitTest --tests "*ScreenshotCapture*"`。
- [ ] 运行：`android/gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin :app:processDebugMainManifest`。
- [ ] 运行：`flutter test test/game_screenshot_controller_test.dart`。
- [ ] 执行 `git diff --check`。
- [ ] 记录设备验证边界：当前无 Android 设备连接；代码与 JVM 测试通过不等于已验证真实相册写入。

