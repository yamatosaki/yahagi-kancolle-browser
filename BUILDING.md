# 源码构建与验证

简体中文 ｜ [English](BUILDING.en.md) ｜ [한국어](BUILDING.ko.md)

本指南面向需要自行构建 Android 客户端或参与开发的人。安装已发布应用请使用 [GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases)。主分支源码可能领先于安装包；需要某个发布版本的源码时，请选择发布页对应的标签，并以该标签的配置为准。

## 开发环境

当前 [CI 配置](.github/workflows/ci.yml) 使用：

- Flutter **3.44.8 stable**；Dart 随 Flutter 安装，版本约束见 `pubspec.yaml`。
- JDK **17**。运行 Android 原生测试时，让 `JAVA_HOME` 指向 JDK 17。
- Android SDK、命令行工具及接受许可的构建组件。`compileSdk` 和 NDK 版本由 Flutter SDK 决定，见 `android/app/build.gradle.kts`。
- Git。构建 APK 不需要 Python；运行完整数据校验时另需 Python 3 和 Pillow。

先安装上述工具，再用 `flutter doctor -v` 检查环境；Android 许可可通过 `flutter doctor --android-licenses` 确认。首次构建需要下载 Flutter、Pub、Gradle 和 Android 相关依赖。

## 获取源码并构建 debug

在终端中执行：

```sh
git clone https://github.com/yamatosaki/yahagi-kancolle-browser.git
cd yahagi-kancolle-browser
flutter pub get
flutter build apk --debug
```

生成的安装包位于 `build/app/outputs/flutter-apk/app-debug.apk`。连接调试设备后，也可以运行 `flutter run`。

debug 构建使用本机自动生成的调试签名，不需要维护者的签名密钥、账号数据、游戏数据库或备份文件。Android SDK 路径等本机配置由工具生成，不应提交进仓库。

仓库已包含构建所需的资源快照、字体、Gradle Wrapper 和 `pubspec.lock`，无需另外克隆资料仓库或运行数据抓取脚本。`flutter pub get` 会按锁文件下载依赖并生成本机配置；不要用 `flutter pub upgrade` 代替首次安装。当前仓库提供 Android 工程，iOS 第三方移植不属于这里的构建目标。

自行签名的 APK 不能直接覆盖签名不同的官方安装包。如需并存，可按 [定制指南](CUSTOMIZING.md) 更改应用 ID；如选择卸载旧应用后安装，请先导出所需记录，卸载会清除应用数据。以后更新自己的安装包时，使用同一签名密钥并保持或提高版本号。

## 使用 GitHub Actions 构建

也可以 Fork 本仓库，在自己的仓库中启用 Actions，进入 **Actions → CI → Run workflow**，选择自己的默认分支并运行。完整检查和 debug 构建成功后，在该次运行页面的 Artifacts 下载 `yahagi-debug-apk`，解压得到 `app-debug.apk`。构建产物保留 7 天；过期后可再次运行。首次构建和网络下载可能需要较长时间，失败时先查看运行日志。

这条路径不需要配置维护者的签名密钥，提供的是调试签名 APK。它同样不能覆盖签名不同的官方安装包；Actions 的临时运行环境也可能在不同次构建中生成不同的调试密钥，因此不能保证两次产物可以直接覆盖升级。长期使用或独立分发时，建议配置自己持有的固定 release 密钥。

## 验证命令

在仓库根目录执行与 CI 对应的检查：

```sh
python -m pip install pillow
python -m unittest tool.test_check_repository_hygiene -v
python tool/check_repository_hygiene.py
python -m unittest tool.test_build_sortie_release tool.test_build_enemy_release tool.test_verify_data_release -v
dart run tool/verify_data_release.dart
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Android 原生单元测试和 lint 检查，在 Windows PowerShell 中执行：

```powershell
.\android\gradlew.bat -p android :app:testDebugUnitTest :app:lintDebug --console=plain
```

在 Linux 或 macOS 中执行：

```sh
chmod +x android/gradlew
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug --console=plain
```

部分集成测试使用仅保存在本地的原始样本，公开检出缺少这些样本时会明确跳过。公开的人工合成测试不需要真实账号或游戏接口转储；不要为运行本地集成测试而把原始数据加入仓库。

## release 签名

`flutter build apk` 默认选择 release 模式。该模式需要自行配置签名；首次验证源码能否构建时，请使用上面的 `--debug` 命令。

制作自己的 release 包时，先在仓库外创建个人签名密钥。以下示例使用 JDK 自带的 `keytool`，它会交互式询问密码和证书信息：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE/.yahagi-custom"
keytool -genkeypair -v -keystore "$env:USERPROFILE/.yahagi-custom/yahagi-custom.jks" -alias yahagi-custom -keyalg RSA -keysize 2048 -validity 10000
```

在同一个目录手动新建 `release-signing.properties`，填写自己的路径与密码。路径使用绝对路径和正斜线；下列内容只是模板：

```properties
storeFile=C:/Users/yourname/.yahagi-custom/yahagi-custom.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=yahagi-custom
keyPassword=YOUR_KEY_PASSWORD
```

`keyPassword` 填密钥实际使用的密码；若生成时未设置独立密钥密码，通常与 `storePassword` 相同。

在仓库根目录用 PowerShell 执行：

```powershell
$env:YAHAGI_SIGNING_PROPERTIES = "$env:USERPROFILE/.yahagi-custom/release-signing.properties"
flutter build apk --release
```

macOS/Linux 可以将上述目录换为自己的主目录，在执行构建前使用 `export YAHAGI_SIGNING_PROPERTIES="$HOME/.yahagi-custom/release-signing.properties"`。APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。密钥和密码需要自行妥善保存，后续更新仍要使用它们。具体签名读取逻辑见 `android/app/build.gradle.kts`。

密钥、签名配置、本机 SDK 配置、安装包、日志和记录备份均不应提交。第三方代码与资源许可见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES)，提交规范见 [贡献指南](CONTRIBUTING.md)。

## 修改界面、资料或应用标识

常见修改入口、无需重新编译的内容定制方式，以及独立分发时需要检查的更新源和统计设置，见 [定制指南](CUSTOMIZING.md)。
