# 定制与二次开发

简体中文 ｜ [English](CUSTOMIZING.en.md)

先按 [源码构建与验证](BUILDING.md) 完成一次 debug 构建，再修改所需内容。普通 APK 构建直接使用仓库内的资源快照，不依赖维护者电脑上的备份、缓存或数据抓取环境。

## 无需重新编译的定制

- 应用设置中可以调整主题、字体、信息布局、首页模块、顶部资源、提醒和字幕。
- 游戏图片与语音替换可以通过“工具箱 → 魔改”导入兼容的 ZIP，格式与限制见 [魔改包使用说明](docs/game-mods.md)。这类资源包不执行自定义 Dart 或 Kotlin 代码。
- 名称翻译和字幕的资料来源与显示边界见 [游戏名称翻译](docs/game-name-localization.md) 和 [舰娘语音字幕](docs/ship-voice-subtitles.md)。

需要增加功能、更改默认行为或分发独立应用时，再修改源码。

## 常见源码入口

| 想修改的内容 | 入口与注意事项 |
| --- | --- |
| 应用入口与各模块装配 | [`lib/main.dart`](lib/main.dart)；具体功能位于 `lib/src/` 各子目录。 |
| 主题、颜色和字体 | [`lib/src/theme/`](lib/src/theme/)；新增随包字体还需更新 `pubspec.yaml` 的 `fonts`。 |
| 应用界面文字 | `lib/l10n/app_*.arb`；修改 ARB 后运行 `flutter gen-l10n`，不要只编辑生成的 `app_localizations*.dart`。部分动态文字位于 `lib/src/localization/` 和各模块的字符串文件。 |
| Android 原生弹窗、通知与 WebView | [`android/app/src/main/kotlin/app/yahagi/kancollebrowser/`](android/app/src/main/kotlin/app/yahagi/kancollebrowser/)；原生通知文字包括 `notification/NotificationStrings.kt`，不全部来自 Flutter ARB。 |
| 图标和应用显示名称 | `assets/app_icon.png`、`pubspec.yaml` 中的 `flutter_icons`；修改图标后运行 `dart run flutter_launcher_icons`。桌面显示名称在 `android/app/src/main/AndroidManifest.xml` 的 `android:label`。 |
| 版本号 | [`pubspec.yaml`](pubspec.yaml) 的 `version`，格式为 `名称+递增构建号`；版本相关测试也应保持一致。 |
| 随包任务、海域、敌舰和字幕资料 | [`assets/data/`](assets/data/)；维护源资料与更新发布流程见 [`data/sortie/README.md`](data/sortie/README.md)、[`data/enemy/README.md`](data/enemy/README.md) 及相应资料许可说明。 |
| Dart 与 Android 通信 | Dart 侧各 `*_port.dart` 与原生 `MethodChannel`；修改通道名或参数时同步修改两端，并运行相应测试。 |

新增资源时，把实际文件放在仓库中并登记到 `pubspec.yaml`；新增子目录也要检查是否被资产清单覆盖。不要以本机绝对路径、未提交文件或开发缓存作为运行时依赖。

本项目以 Flutter 和 Android 原生代码为主，目前没有稳定的外部代码插件 API。增加功能通常需要修改源码并重新构建；魔改 ZIP 主要用于受支持的游戏资源替换。

## 与官方版本并存

在 `android/app/build.gradle.kts` 中，把 `defaultConfig.applicationId` 改为自己控制的唯一标识，例如 `org.example.yahagi.custom`。只改变安装标识时，可以保留现有 `namespace` 和 Kotlin 的 `package`，避免把简单并存配置扩大为整份原生代码迁移。

使用自己的显示名称、图标和签名，随后重新构建。不同应用 ID 的版本各自保存数据，不会自动继承官方版本的登录状态和记录。需要记录时，可以通过应用已有的导出与恢复功能迁移。个人 release 密钥的创建与使用见 [签名说明](BUILDING.md#release-签名)。

## 独立分发需要调整的配置

Fork 后，部分默认服务仍指向本项目或上游资料源。分发自己的版本前，请根据自己的维护方式检查以下位置：

| 配置 | 源码位置 |
| --- | --- |
| 应用版本检查 | `lib/src/settings/release_check_service.dart` 的 `GitHubReleaseChecker` 默认 `endpoint`，以及 `lib/main.dart` 中的实例创建。默认检查本项目 Releases；独立版本应使用自己的发布源或移除相应入口。 |
| 关于页面、反馈与发布链接 | `lib/src/settings/about_dialog.dart` 的仓库常量及各语言文案；使用自己的名称和联系入口，并保留所需署名。 |
| 匿名使用统计 | `lib/src/telemetry/telemetry_service.dart` 的默认 TelemetryDeck App ID，以及 `lib/main.dart` 中的 `AppTelemetryService`。独立分发时改用自己的 ID，或创建实例时传入 `telemetryDeckAppID: null` 关闭上报；这个公开 ID 是统计项目标识，不是构建所需的密钥。 |
| 海域和敌舰在线资料更新 | `lib/src/toolbox/sortie_map_query/` 下的两个 `*_update_service.dart`、`data/sortie/manifest.json`、`data/enemy/manifest.json`。使用自己的源时需同步清单、下载地址、版本和 SHA-256，并检查客户端的下载地址校验。 |
| 任务、改修、字幕与名称翻译更新 | 对应模块的 `*_update_service.dart`。如更改随包资料，也要决定是否继续允许上游在线版本替换它；保留格式验证、完整性校验和失败回退。 |

这些配置目前在源码中设置，没有统一的 `--dart-define` 配置接口。不要把维护者的正式签名或任何账号令牌复制到 Fork 中。APK 构建本身不需要这些私有信息。

## 修改后的验证

先运行与改动相关的测试，然后按 [构建指南](BUILDING.md#验证命令) 完成公开检查与 APK 构建。修改原生交互后，还应在 Android 设备上验证相关弹窗、通知或 WebView 行为。

维护海域或敌舰资料时，可以先运行 `dart run tool/verify_data_release.dart --local-only` 检查本地产物；在线完整校验会访问发布资产。Python 和 Pillow 用于这些数据工具，不是 APK 构建的前置步骤。

提交前运行 `python tool/check_repository_hygiene.py --working-tree`，检查误加入的本机路径、日志、备份和签名材料。许可证见 [LICENSE](LICENSE)；第三方代码、字体与资料有各自的许可和署名要求，见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES)。
