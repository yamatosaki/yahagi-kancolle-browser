<div align="center">
  <img src="assets/app_icon.png" width="128" alt="Yahagi KanColle Browser 图标">

# Yahagi KanColle Browser

面向 Android 平板与手机的《舰队 Collection》非官方浏览器及本地信息辅助工具。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![CI](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml/badge.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml)

</div>

## 软件介绍

Yahagi 将游戏浏览器与信息面板整合在同一个 Android 应用中。玩家可以在 WebView 中打开 DMM 与游戏页面，并在侧边信息中心查看舰队、资源、任务、远征、入渠、建造和战斗等数据。

应用只读取游戏页面已经收到的 `/kcsapi/` 响应，用于生成本地辅助信息和日志。它不会自动填写账号、点击页面、编成舰队、补给、出击或领取任务，所有游戏操作仍由玩家本人完成。

## 核心功能

### 游戏浏览

- 在 Android System WebView 中加载 DMM 登录页和游戏页面。
- 提供返回、刷新、主页、静音和画面适配等常用控制。
- 针对平板横屏和信息面板并排使用场景优化布局。
- 提供“游戏信息模式”和“纯浏览模式”，可随时关闭接口信息读取。

### 舰队信息中心

- 查看各舰队的舰娘、等级、耐久、疲劳度和装备。
- 汇总制空、索敌、装备属性和联合舰队信息。
- 识别先制对潜、对空 CI、对空喷进弹幕等战斗机制。
- 提供出击前舰队状态检查，帮助快速发现需要留意的编成状态。

### 任务与作业状态

- 展示进行中和已完成任务，并显示类型、周期与完成进度。
- 支持任务筛选、排序和重点任务查看。
- 集中展示远征、入渠和建造状态及剩余时间。

### 战斗辅助

- 记录航海节点、敌我舰队和交战状态。
- 根据已收到的战斗数据展示耐久变化与战斗过程。
- 提供战果等级和 MVP 预测，并在官方结算返回后更新为正式结果。
- 支持通常舰队与联合舰队战斗信息展示。

### 日志与统计

- 在设备本地保存战斗、资源和远征记录。
- 提供历史记录查看，便于回顾资源变化与作战结果。
- 数据保存在本地数据库中，不需要额外的云端账号。

### 网络与界面

- 支持系统网络、HTTP 代理和 SOCKS5 代理。
- 支持简体中文、繁体中文和日语界面。
- 支持应用内版本检查，并从 GitHub Releases 获取最新版本信息。

## 数据与安全边界

- 真实网页导航仅允许 DMM 与舰队服务器的 HTTPS 来源。
- 原生捕获桥只接受白名单来源和 `/kcsapi/` 路径。
- 页面端、Android 端和 Dart 端会清理 `api_token`、`api_starttime` 等敏感参数。
- 应用不会读取或导出 Cookie、登录表单和完整请求头。
- 捕获逻辑不阻断、不重放、不修改游戏通信，也不会代替玩家操作游戏。
- Android System WebView 仍可能按照系统默认行为保存登录 Cookie。

## 获取与运行

正式版本发布后，可前往 [GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases) 获取安装包。

目前也可以从源码运行。开发环境需要 Flutter 3.44、Dart 3.12、JDK 17 和 Android SDK：

```powershell
git clone https://github.com/yamatosaki/yahagi-kancolle-browser.git
Set-Location yahagi-kancolle-browser
flutter pub get
flutter run
```

构建本地测试用 debug APK：

```powershell
flutter build apk --debug
```

APK 默认输出到 `build/app/outputs/flutter-apk/app-debug.apk`。

## 开源与贡献

Yahagi 以开放源代码的方式开发。欢迎通过以下方式参与项目：

- 提交 Issue，报告错误或提出功能建议。
- 提交 Pull Request，改进功能、兼容性、文档或本地化。
- 在不同 Android 设备和 WebView 版本上测试，并反馈运行情况。

参与开发前请阅读 [贡献指南](CONTRIBUTING.md) 和 [安全政策](SECURITY.md)。提交变更前建议运行：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
Set-Location android
.\gradlew.bat :app:testDebugUnitTest --console=plain
```

项目源代码使用 [MIT License](LICENSE)。第三方字体、依赖及其他资产的说明见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES)。

## 免责声明

Yahagi 是由社区开发的非官方工具，与《舰队 Collection》运营方、开发方、DMM 及相关权利方不存在隶属、授权或合作关系。

使用者应自行了解并遵守相关服务条款，并承担使用第三方工具可能产生的账号、网络和兼容性风险。游戏名称、商标及第三方素材的相关权利归各自权利人所有。

## 致谢

特别感谢 [POI 浏览器](https://github.com/poooi/poi) 项目及其开源社区。POI 长期以来通过开放源代码推动《舰队 Collection》社区工具的发展，在数据组织、功能设计和社区协作等方面为本项目提供了宝贵的参考与启发。

同时感谢 Flutter、WebView Flutter 及本项目所有依赖库的维护者，也感谢每一位参与测试、反馈问题和贡献代码的用户。

Yahagi 是独立开发的项目，项目观点与实现不代表上述项目或社区的官方立场。
