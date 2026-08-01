# Yahagi KanColle Browser

Yahagi 是一个基于 Flutter 和 Android System WebView 的非官方移动端浏览器工具，为《舰队 Collection》提供舰队、任务、战斗和航海日志等本地辅助信息。

本项目不会自动填写登录信息、点击页面或代替玩家操作。使用真实游戏页面及只读接口捕获功能前，请自行评估账号、网络和服务条款风险。

## 主要功能

- 在 Android WebView 中加载 DMM 与游戏页面。
- 只读观察 `fetch` 和 `XMLHttpRequest` 的 `/kcsapi/` 响应。
- 对页面来源、接口路径、消息格式和消息大小进行原生端二次校验。
- 在页面端、Android 端和 Dart 端清理 `api_token`、`api_starttime`。
- 展示舰队、装备、资源、任务、远征、入渠、建造与战斗信息。
- 在本地数据库保存战斗、资源和远征记录。
- 支持简体中文、繁体中文和日语界面。
- 支持系统网络、HTTP 代理和 SOCKS5 代理。
- 提供纯浏览模式；该模式不会安装游戏接口捕获脚本。

## 安全边界

- 真实网页导航仅允许 DMM 和舰队服务器的 HTTPS 来源。
- 原生捕获桥只接受白名单来源和 `/kcsapi/` 路径。
- 应用代码不读取或导出 Cookie、登录表单和完整请求头。
- 页面地址展示会移除查询参数、片段及 DMM 路径参数。
- 捕获逻辑不阻断、不重放且不篡改请求，也不会执行游戏操作。
- Android System WebView 仍可能按系统默认行为保存登录 Cookie。

## 环境要求

- Flutter 3.44 或兼容的稳定版本
- Dart 3.12 或兼容版本
- JDK 17
- Android SDK（版本由当前 Flutter SDK 决定）

## 开始开发

克隆仓库并安装依赖：

```powershell
git clone https://github.com/yamatosaki/yahagi-kancolle-browser.git
Set-Location yahagi-kancolle-browser
flutter pub get
```

运行应用：

```powershell
flutter run
```

构建用于本地测试的 debug APK：

```powershell
flutter build apk --debug
```

APK 默认输出到 `build/app/outputs/flutter-apk/app-debug.apk`。

## 验证

提交变更前依次运行：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
Set-Location android
.\gradlew.bat :app:testDebugUnitTest --console=plain
Set-Location ..
flutter build apk --debug
```

真机或虚拟机测试建议覆盖：

1. DMM 登录和游戏页面加载。
2. 工具栏地址不显示查询参数或片段。
3. 返回、刷新、主页、静音和画面适配。
4. 游戏模式能够更新母港、舰队、任务和战斗信息。
5. 纯浏览模式下信息停止更新。
6. HTTP／SOCKS5 代理的应用、切换和清除。
7. 后台恢复、横竖屏和不同窗口尺寸。
8. 日志中不包含 Cookie、`api_token`、接口正文或完整登录 URL。

## 发布说明

仓库不包含正式 APK 的签名凭据。发布者需要在私有环境或 CI Secret 中配置 release keystore，不应把密钥、密码或 `key.properties` 提交到仓库。

版本发布使用语义化标签，例如 `v1.0.0`。应用内更新检查读取 GitHub Releases 的最新版本。

## 已知限制

- 当前仅实现 Android 捕获；iOS 只保留跨平台接口。
- 游戏服务器域名变化后需要更新来源白名单。
- Android System WebView 的音频、Canvas/WebGL 和长时间运行表现依赖设备及 WebView 版本。
- 页面内包装 XHR／Fetch 可能被网页脚本感知，无法承诺零账号风险。
- 正式发布前仍需在目标设备上完成登录、母港、出击和代理人工验收。

## 许可证

项目源代码使用 [MIT License](LICENSE)。第三方字体、依赖及其他资产的说明见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES)。项目名称、游戏名称、商标及第三方素材的相关权利归各自权利人所有。
