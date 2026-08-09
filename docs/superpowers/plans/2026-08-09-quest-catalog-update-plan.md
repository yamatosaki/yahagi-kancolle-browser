# 任务资料库在线更新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为任务资料增加与 FCD 未卜先知资料一致的启动自动检查、设置页手动更新、校验、原子缓存、失败回退和即时刷新能力。

**架构：** 新建独立的 QuestCatalogDataset、Store、UpdateService 和 Controller，不修改 FCD 更新内部实现。启动时从内置资源和应用支持目录缓存中选择较新有效版本，Controller 负责检查去重和即时通知，QuestCenterPage 从 Controller 获取当前目录，设置页用独立更新行展示状态并触发同一个检查入口。

**技术栈：** Flutter/Dart、`http`、`path_provider`、`crypto`、`flutter_test`、应用现有 ARB 本地化生成流程。

---

## 文件结构

- 创建 `lib/src/quest/quest_catalog_dataset.dart`：版本模型、原始 JSON 解析和完整数据验证。
- 创建 `lib/src/quest/quest_catalog_store.dart`：内置/缓存择优、状态文件、原子写入和备份恢复。
- 创建 `lib/src/quest/quest_catalog_update_service.dart`：可信版本查询、固定 HTTPS 源下载、校验和持久化。
- 创建 `lib/src/quest/quest_catalog_controller.dart`：当前目录、检查去重、更新通知和诊断状态。
- 创建 `lib/src/settings/quest_catalog_update_section.dart`：设置页任务资料更新行与结果对话框。
- 修改 `lib/src/quest/quest_catalog.dart`：保留任务领域模型，允许由已验证 Dataset 构造，不再自行决定生产环境资源来源。
- 修改 `lib/src/quest/quest_center_page.dart`：可选监听 QuestCatalogController，更新后立即重建任务目录。
- 修改 `lib/src/settings/settings_page.dart`：在数据更新区域加入任务资料更新行。
- 修改 `lib/main.dart`：启动加载、依赖注入、首帧自动检查和 dispose。
- 修改 `assets/data/quests-scn.json`：继续作为内置保底资料。
- 创建 `assets/data/quests-meta.json`：记录内置资料的提交时间、完整提交号和 SHA-256。
- 修改 `pubspec.yaml`：声明元数据资源及 `crypto` 直接依赖。
- 修改 `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：任务资料更新文案；生成的本地化 Dart 文件由 `flutter gen-l10n` 统一刷新。
- 创建 `test/quest_catalog_dataset_test.dart`、`quest_catalog_store_test.dart`、`quest_catalog_update_service_test.dart`、`quest_catalog_controller_test.dart`、`quest_catalog_update_section_test.dart`。
- 修改 `test/quest_center_page_test.dart`：验证目录热更新后页面即时刷新。

### 任务 1：任务资料 Dataset 和版本模型

**文件：**
- 创建：`lib/src/quest/quest_catalog_dataset.dart`
- 修改：`lib/src/quest/quest_catalog.dart`
- 创建：`test/quest_catalog_dataset_test.dart`

- [ ] **步骤 1：编写版本比较和合法资料解析的失败测试**

```dart
test('parses a valid catalog and compares versions by commit time', () {
  final old = QuestCatalogDataset.parse(
    rawJson: validCatalogJson(501),
    version: QuestCatalogVersion(
      committedAt: DateTime.utc(2026, 8, 1),
      commitSha: 'a' * 40,
      sha256: sha256Of(validCatalogJson(501)),
    ),
    minimumQuestCount: 500,
  );
  final latest = QuestCatalogVersion(
    committedAt: DateTime.utc(2026, 8, 9),
    commitSha: 'b' * 40,
    sha256: 'c' * 64,
  );
  expect(latest.compareTo(old.version), greaterThan(0));
  expect(old.catalog.entries.length, 501);
});
```

- [ ] **步骤 2：运行测试确认因类型不存在而失败**

运行：`flutter test test/quest_catalog_dataset_test.dart`

预期：FAIL，提示 `QuestCatalogDataset` 或 `QuestCatalogVersion` 未定义。

- [ ] **步骤 3：实现最小版本与 Dataset 解析接口**

```dart
final class QuestCatalogVersion implements Comparable<QuestCatalogVersion> {
  const QuestCatalogVersion({
    required this.committedAt,
    required this.commitSha,
    required this.sha256,
  });

  final DateTime committedAt;
  final String commitSha;
  final String sha256;

  @override
  int compareTo(QuestCatalogVersion other) =>
      committedAt.compareTo(other.committedAt);
}

final class QuestCatalogDataset {
  const QuestCatalogDataset({
    required this.catalog,
    required this.version,
    required this.rawJson,
  });

  final QuestCatalog catalog;
  final QuestCatalogVersion version;
  final String rawJson;

  static QuestCatalogDataset parse({
    required String rawJson,
    required QuestCatalogVersion version,
    int minimumQuestCount = 500,
    int maxBytes = 1024 * 1024,
  }) { /* JSON、数量、字段、编号唯一、自引用和哈希校验 */ }
}
```

- [ ] **步骤 4：增加并运行拒绝非法资料的测试**

覆盖：少于 500 项、重复 `code`、非数字游戏 ID、错误字段类型、自引用前置、内容 SHA-256 不匹配、超过 1 MiB。每个测试都先运行并确认因验证缺失而 FAIL，再补最小验证直至 PASS。

运行：`flutter test test/quest_catalog_dataset_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交 Dataset 变更**

```powershell
git add lib/src/quest/quest_catalog.dart lib/src/quest/quest_catalog_dataset.dart test/quest_catalog_dataset_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(任务): 增加任务资料版本与校验"
```

### 任务 2：缓存择优、状态持久化和断电恢复

**文件：**
- 创建：`lib/src/quest/quest_catalog_store.dart`
- 创建：`test/quest_catalog_store_test.dart`
- 创建：`assets/data/quests-meta.json`
- 修改：`pubspec.yaml`

- [ ] **步骤 1：编写缓存较新时优先、缓存损坏时回退的失败测试**

```dart
test('loads newer valid cache and falls back when cache is invalid', () async {
  final storage = MemoryQuestCatalogStorage(
    bundledData: bundledRaw,
    bundledMetadata: bundledMeta,
    cachedData: newerRaw,
    cachedMetadata: newerMeta,
  );
  final store = QuestCatalogStore(storage, minimumQuestCount: 1);
  expect((await store.loadBestAvailable()).source, QuestCatalogSource.cache);

  storage.cachedData = '{broken';
  expect((await store.loadBestAvailable()).source, QuestCatalogSource.bundled);
});
```

- [ ] **步骤 2：运行测试确认 Store 不存在**

运行：`flutter test test/quest_catalog_store_test.dart`

预期：FAIL，提示 `QuestCatalogStore` 未定义。

- [ ] **步骤 3：实现 Storage、Store 和状态模型**

```dart
abstract interface class QuestCatalogStorage {
  Future<String> readBundledData();
  Future<String> readBundledMetadata();
  Future<String?> readCachedData();
  Future<String?> readCachedMetadata();
  Future<void> writeCached(QuestCatalogDataset dataset);
}

final class QuestCatalogState {
  const QuestCatalogState({
    required this.version,
    required this.source,
    required this.lastCheckedAt,
    required this.result,
  });
  // fromJson/toJson 使用 UTC ISO-8601。
}
```

`ApplicationQuestCatalogStorage.create()` 使用 `getApplicationSupportDirectory()`，文件名为 `quest-catalog.json`、`quest-catalog-meta.json`、`quest-catalog-state.json`。写入过程复制 FCD 的 `.tmp` / `.bak` 原子替换和启动恢复规则，但校验调用 QuestCatalogDataset。

- [ ] **步骤 4：增加原子替换、备份恢复、旧缓存拒绝和状态读写测试**

每个行为先补失败测试并单独运行，再实现最少代码。测试目录使用 `Directory.systemTemp.createTemp()`，结束时只删除该测试目录。

运行：`flutter test test/quest_catalog_store_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：生成并声明内置元数据**

`assets/data/quests-meta.json` 格式：

```json
{
  "committedAt": "2026-08-09T00:00:00Z",
  "commitSha": "40位上游提交号",
  "sha256": "quests-scn.json 的64位SHA-256"
}
```

提交前通过上游 API 核实准确提交时间与提交号，并计算当前内置 JSON 的 SHA-256；不得保留示例值。

- [ ] **步骤 6：提交存储层变更**

```powershell
git add lib/src/quest/quest_catalog_store.dart test/quest_catalog_store_test.dart assets/data/quests-meta.json pubspec.yaml
git commit -m "feat(任务): 增加任务资料缓存与恢复"
```

### 任务 3：可信远端检查和安全下载

**文件：**
- 创建：`lib/src/quest/quest_catalog_update_service.dart`
- 创建：`test/quest_catalog_update_service_test.dart`

- [ ] **步骤 1：编写同版本和新版本更新的失败测试**

```dart
test('downloads a newer immutable revision and stores it', () async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/commits')) {
      return http.Response(remoteCommitResponse, 200);
    }
    expect(request.url.path, contains(remoteCommitSha));
    return http.Response(newerRaw, 200);
  });
  final result = await service(client).checkAndUpdate(current: current);
  expect(result, isA<QuestCatalogUpdated>());
  expect(storage.savedDataset?.version.commitSha, remoteCommitSha);
});
```

- [ ] **步骤 2：运行测试确认更新服务不存在**

运行：`flutter test test/quest_catalog_update_service_test.dart`

预期：FAIL，提示 `QuestCatalogUpdateService` 未定义。

- [ ] **步骤 3：实现固定地址和结果类型**

```dart
const questCatalogCommitApi =
    'https://api.github.com/repos/kcwikizh/kcQuests/commits?path=quests-scn.json&per_page=1';

String rawSource(String sha) =>
    'https://raw.githubusercontent.com/kcwikizh/kcQuests/$sha/quests-scn.json';
String cdnSource(String sha) =>
    'https://cdn.jsdelivr.net/gh/kcwikizh/kcQuests@$sha/quests-scn.json';

sealed class QuestCatalogUpdateResult { /* sourceHost */ }
final class QuestCatalogUpToDate extends QuestCatalogUpdateResult { /* version */ }
final class QuestCatalogUpdated extends QuestCatalogUpdateResult { /* dataset */ }
final class QuestCatalogUpdateFailed extends QuestCatalogUpdateResult {
  final QuestCatalogUpdateFailure kind; // network、validation、storage
}
```

服务先获取文件对应的最新 commit SHA 和提交时间，再使用完整 SHA 构造不可变下载 URL。请求禁止重定向，限定 HTTPS、固定域名和固定路径；User-Agent 使用应用版本；单次总超时 10 秒；元数据最大 64 KiB、任务文件最大 1 MiB。

- [ ] **步骤 4：逐项补充备用源、防降级和错误分类测试**

覆盖：Raw 失败后 jsDelivr 成功、API 失败、HTTP 非 200、超时、响应超限、SHA 不符、旧提交拒绝、数据校验失败、存储失败、失败后旧资料不变。每项先确认 FAIL 再实现。

运行：`flutter test test/quest_catalog_update_service_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交更新服务**

```powershell
git add lib/src/quest/quest_catalog_update_service.dart test/quest_catalog_update_service_test.dart
git commit -m "feat(任务): 增加任务资料安全更新服务"
```

### 任务 4：Controller 检查去重和任务页即时应用

**文件：**
- 创建：`lib/src/quest/quest_catalog_controller.dart`
- 创建：`test/quest_catalog_controller_test.dart`
- 修改：`lib/src/quest/quest_center_page.dart`
- 修改：`test/quest_center_page_test.dart`

- [ ] **步骤 1：编写并发检查复用和成功替换的失败测试**

```dart
test('deduplicates checks and swaps catalog after a verified update', () async {
  final completer = Completer<QuestCatalogUpdateResult>();
  final controller = QuestCatalogController(
    dataset: oldDataset,
    updater: FakeUpdater(completer.future),
  );
  final first = controller.checkForUpdates();
  final second = controller.checkForUpdates();
  expect(identical(first, second), isTrue);
  completer.complete(QuestCatalogUpdated(newDataset));
  await first;
  expect(controller.catalog.byGameId(201)?.name, '新任务名');
});
```

- [ ] **步骤 2：运行测试确认 Controller 不存在**

运行：`flutter test test/quest_catalog_controller_test.dart`

预期：FAIL，提示 `QuestCatalogController` 未定义。

- [ ] **步骤 3：实现 ChangeNotifier Controller**

Controller 暴露 `dataset`、`catalog`、`version`、`isChecking`、`lastResult`、`lastCheckedAt`、`sourceHost` 和 `checkForUpdates()`；更新成功才替换 Dataset，失败只更新诊断状态。dispose 后不得通知监听者。

- [ ] **步骤 4：先写任务页即时刷新的失败 Widget 测试**

页面注入 Controller，初始显示旧英文编号或任务名；FakeUpdater 完成后不重建 MaterialApp，只 `pump()`，断言新编号、说明和关系已经显示。

运行：`flutter test test/quest_center_page_test.dart --plain-name "refreshes after catalog update"`

预期：FAIL，页面未监听 Controller。

- [ ] **步骤 5：让 QuestCenterPage 监听 Controller**

新增可选 `QuestCatalogController? catalogController`。生产环境传 Controller；既有单元测试仍可用固定 `catalog`。`AnimatedBuilder` 监听 `Listenable.merge([gameStateController, catalogController])`，目录优先取 Controller 当前值。

- [ ] **步骤 6：运行 Controller 和任务页测试**

运行：`flutter test test/quest_catalog_controller_test.dart test/quest_center_page_test.dart`

预期：全部 PASS。

- [ ] **步骤 7：提交 Controller 和页面接入**

```powershell
git add lib/src/quest/quest_catalog_controller.dart lib/src/quest/quest_center_page.dart test/quest_catalog_controller_test.dart test/quest_center_page_test.dart
git commit -m "feat(任务): 支持任务资料即时应用"
```

### 任务 5：设置页同款手动更新交互

**文件：**
- 创建：`lib/src/settings/quest_catalog_update_section.dart`
- 创建：`test/quest_catalog_update_section_test.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_localizations.dart`
- 修改：`lib/l10n/app_localizations_zh.dart`
- 修改：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写设置行显示与按钮加载态的失败测试**

```dart
testWidgets('shows quest data version and disables sync while checking', (
  tester,
) async {
  await tester.pumpWidget(localizedApp(QuestCatalogUpdateSection(
    controller: controller,
  )));
  expect(find.text('任务资料'), findsOneWidget);
  expect(find.textContaining(controller.version.shortLabel), findsOneWidget);
  await tester.tap(find.byKey(const Key('quest-catalog-check-button')));
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(
    tester.widget<IconButton>(
      find.byKey(const Key('quest-catalog-check-button')),
    ).onPressed,
    isNull,
  );
});
```

- [ ] **步骤 2：运行测试确认组件不存在**

运行：`flutter test test/quest_catalog_update_section_test.dart`

预期：FAIL，提示 `QuestCatalogUpdateSection` 未定义。

- [ ] **步骤 3：补齐三语言文案并生成本地化代码**

新增：任务资料标题、资料版本、上次检查、尚未检查、更新来源、检查按钮、已经最新、更新成功、网络失败、验证失败、存储失败。简中用“任务资料”，繁中用“任務資料”，日文用“任務データ”。

运行：`flutter gen-l10n`

- [ ] **步骤 4：实现与 FcdMapUpdateSection 相同布局的设置行**

使用 `ListTile + AnimatedBuilder + IconButton`，同样的金色 `Icons.sync`、20px CircularProgressIndicator、禁用态和结果 AlertDialog。成功文案包含旧版本、新版本和“已立即生效”。

- [ ] **步骤 5：补充已经最新、成功及三种失败对话框测试**

每个结果先写失败断言，再实现对应 switch 分支。

运行：`flutter test test/quest_catalog_update_section_test.dart`

预期：全部 PASS。

- [ ] **步骤 6：接入 SettingsPage 数据更新区域**

SettingsPage 新增可选 `QuestCatalogController? questCatalogController`，在 `FcdMapUpdateSection` 后插入 `QuestCatalogUpdateSection`；Controller 为空时不显示，保持现有测试构造兼容。

- [ ] **步骤 7：提交设置页交互**

```powershell
git add lib/src/settings/quest_catalog_update_section.dart lib/src/settings/settings_page.dart lib/l10n test/quest_catalog_update_section_test.dart
git commit -m "feat(设置): 增加任务资料手动更新入口"
```

### 任务 6：启动加载、自动检查和生命周期接入

**文件：**
- 修改：`lib/main.dart`
- 修改：相关 `test/prototype_shell_test.dart` 或新增 `test/quest_catalog_startup_test.dart`

- [ ] **步骤 1：编写 Shell 将 Controller 传给设置页和任务页的失败测试**

测试构造 YahagiApp/YahagiShell 时注入 Fake QuestCatalogController，进入任务工作区断言页面显示 Controller 目录；进入设置工作区断言出现 `quest-catalog-check-button`。

运行相应测试，预期因构造参数和传递链不存在而 FAIL。

- [ ] **步骤 2：在 main 启动阶段加载最佳资料**

流程与 FCD 并列：

```dart
final storage = await ApplicationQuestCatalogStorage.create();
final store = QuestCatalogStore(storage);
final loaded = await store.loadBestAvailable();
final state = await store.loadState();
final controller = QuestCatalogController(
  dataset: loaded.dataset,
  updater: QuestCatalogUpdateService(
    client: http.Client(),
    store: store,
    appVersion: currentVersion,
  ),
  lastCheckedAt: state?.lastCheckedAt,
  sourceHost: state?.source ?? '',
);
```

应用支持目录不可用时使用 `BundledOnlyQuestCatalogStorage` 并记录 debugPrint，不阻止启动。

- [ ] **步骤 3：沿 YahagiApp、YahagiShell、SettingsPage 和 QuestCenterPage 传递 Controller**

所有测试构造保留可空默认值；生产 main 必须传非空 Controller。Shell dispose 时释放 Controller 及其 HTTP client，遵循现有 FCD 生命周期方式。

- [ ] **步骤 4：首帧后启动自动检查**

在现有 FCD `addPostFrameCallback` 中并列调用：

```dart
unawaited(fcdMapController.checkForUpdates());
unawaited(questCatalogController.checkForUpdates());
```

自动检查只更新 Controller 状态，不显示对话框。

- [ ] **步骤 5：运行启动与 Shell 测试**

运行：`flutter test test/prototype_shell_test.dart test/quest_catalog_startup_test.dart`

如果复用现有测试而未创建新文件，则命令只包含实际存在的测试文件。预期全部 PASS。

- [ ] **步骤 6：提交启动接入**

```powershell
git add lib/main.dart test/prototype_shell_test.dart test/quest_catalog_startup_test.dart
git commit -m "feat(任务): 启动时加载并检查任务资料"
```

### 任务 7：完整验证和热重载交付

**文件：**
- 检查本计划涉及的全部文件。

- [ ] **步骤 1：运行任务资料与设置页测试**

运行：

```powershell
flutter test test/quest_catalog_test.dart test/quest_catalog_dataset_test.dart test/quest_catalog_store_test.dart test/quest_catalog_update_service_test.dart test/quest_catalog_controller_test.dart test/quest_catalog_update_section_test.dart test/quest_center_page_test.dart test/workspace_context_header_test.dart
```

预期：全部 PASS、没有 RenderFlex overflow 或未处理异步异常。

- [ ] **步骤 2：运行静态分析**

先运行本次文件范围分析，预期 `No issues found`。再运行 `flutter analyze`；如果只剩任务前已经存在的无关错误，记录文件和错误，不修改无关代码。

- [ ] **步骤 3：验证真实内置资源和远端检查**

使用真实 `assets/data/quests-scn.json` 与 `quests-meta.json` 运行 Dataset 测试；使用 MockClient 验证 URL 固定到完整 commit SHA。不得在自动测试中依赖公网。

- [ ] **步骤 4：检查工作区差异**

运行：

```powershell
git diff --check -- lib/main.dart lib/src/quest lib/src/settings/quest_catalog_update_section.dart lib/src/settings/settings_page.dart lib/l10n test pubspec.yaml assets/data/quests-meta.json
git status --short
```

确认没有覆盖用户的其他未提交修改。

- [ ] **步骤 5：交付重载指引**

由于新增依赖、资源和启动注入，本次完成后明确提示用户点击绿色重新加载按钮；不生成 APK。绿色加载成功后，后续仅 Dart UI 调整恢复使用黄色闪电。
