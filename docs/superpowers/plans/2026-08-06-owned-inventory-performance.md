# 持有一览性能优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框语法跟踪进度。

**目标：** 在保持持有一览现有 UI 和交互完全一致的前提下，将全量表格改为惰性构建，并减少无关计算、状态重建、图片解码和重复行高测量。

**架构：** `_FrozenTable` 使用冻结列和正文两套同步的 `ListView.builder`，共享行数和行高；页面状态持有库存依赖快照以及舰娘、装备派生缓存；装备表内部缓存动态行高；持有一览头像传入按 DPR 计算的解码高度。保留现有横向滚动、冻结表头、排序筛选及视觉组件。

**技术栈：** Flutter/Dart、Widget Tests、ChangeNotifier、ListView.builder、ScrollController、Image.network/ResizeImage。

---

## 文件结构

- 修改：`lib/src/inventory/owned_inventory_page.dart`——当前标签派生缓存、库存依赖监听、惰性冻结表格、装备行高缓存、行级重绘边界和头像缩略参数。
- 修改：`lib/src/fleet/ship_portrait.dart`——增加可选网络图片解码高度并传递给 `Image.network`。
- 修改：`test/owned_inventory_page_test.dart`——大数据集惰性构建、无关状态刷新、动态装备行和头像解码回归测试。
- 验证：`test/owned_inventory_projection_test.dart`——确保投影筛选、排序和装备分组语义不变。

### 任务 1：冻结表格惰性构建

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart:779-965`

- [ ] **步骤 1：编写大舰娘数据集的失败测试**

构造 100 艘舰娘并在 844×390 视口打开持有一览，断言首艘头像存在、末艘头像不存在；滚动正文纵向列表到底部后，断言末艘头像出现。为正文和冻结列表增加稳定 Key，测试通过 Key 操作正确滚动区域。

- [ ] **步骤 2：运行测试确认因全量 `Column` 构建而失败**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "lazily builds ship rows near the viewport"`

预期：FAIL，末艘头像在未滚动时已经存在，或新的惰性列表 Key 尚不存在。

- [ ] **步骤 3：以两套 `ListView.builder` 替换完整 Column**

冻结列使用不可交互的 `ListView.builder`，正文使用可交互的 `ListView.builder`；两者按 `rowHeights[index]` 包装单行，设置零 padding、显式 controller 和稳定 Key。正文滚动继续同步冻结列，横向容器与表头同步保持不变。每个惰性行外包 `RepaintBoundary`。

- [ ] **步骤 4：运行定向和既有布局测试**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "lazily builds ship rows near the viewport"
flutter test test/owned_inventory_page_test.dart
```

预期：新测试通过，既有筛选、冻结列、动态着装行测试全部通过且无 overflow。

### 任务 2：只计算当前标签并缓存库存派生数据

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart:29-125`

- [ ] **步骤 1：编写无关状态更新的失败测试**

为持有表格增加稳定 Key。首次构建后保存该 Key 对应的 Widget 实例，发送只改变资源或战斗状态、但复用所有库存集合引用的 `GameState` 通知；断言表格 Widget 实例保持 identical。发送舰娘或装备更新后，断言表格 Widget 实例更新并显示新数据。

- [ ] **步骤 2：运行测试确认当前 `AnimatedBuilder` 会重建**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "ignores unrelated game state updates and invalidates inventory changes"`

预期：FAIL，无关通知增加表格构建次数。

- [ ] **步骤 3：实现库存依赖快照和当前标签缓存**

把页面从全树 `AnimatedBuilder` 改为显式监听控制器。实现 `_InventoryDependencies`，按 `identical` 比较 `ships`、`fleets`、`slotItems`、`masterShips`、`masterShipTypes`、`masterSlotItems`，并比较 `serverOrigin`。仅在这些值改变时调用 `setState`。

页面分别缓存 `_shipRows` 与 `_equipmentGroups`，缓存键包含设计规格规定的数据依赖和筛选/排序参数。`build()` 中通过 `_showShips` 分支只请求当前标签结果，不执行隐藏标签投影。

- [ ] **步骤 4：正确处理控制器替换和生命周期**

在 `initState` 注册监听，在 `didUpdateWidget` 中解绑旧控制器并绑定新控制器，在 `dispose` 中解绑；控制器替换时清空全部派生缓存并刷新库存快照。

- [ ] **步骤 5：运行定向和投影测试**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "ignores unrelated game state updates and invalidates inventory changes"
flutter test test/owned_inventory_projection_test.dart test/owned_inventory_page_test.dart
```

预期：全部通过，分类、排序、装备数量和着装情况保持原语义。

### 任务 3：舰娘头像缩略尺寸解码

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/fleet/ship_portrait.dart:151-224`
- 修改：`lib/src/inventory/owned_inventory_page.dart:412-460`

- [ ] **步骤 1：编写头像解码尺寸失败测试**

在设备像素比 2 的持有一览中找到舰娘头像内部的网络 `Image`，断言其 provider 是目标高度约 102 像素的 `ResizeImage`；另验证未传缩略参数的普通 `ShipPortrait` 保持未缩放 provider。

- [ ] **步骤 2：运行测试确认当前 provider 未缩放**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "decodes owned ship portraits at thumbnail resolution"`

预期：FAIL，当前 provider 为原始 `NetworkImage`。

- [ ] **步骤 3：增加可选解码高度**

为 `ShipPortrait` 增加 `decodeHeight` 可选参数并传给 `Image.network(cacheHeight: decodeHeight)`。持有一览使用 `(51 * MediaQuery.devicePixelRatioOf(context)).ceil()`，其他调用点不传值。

- [ ] **步骤 4：运行头像和舰队页面测试**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "decodes owned ship portraits at thumbnail resolution"
flutter test test/owned_inventory_page_test.dart test/fleet_information_center_test.dart
```

预期：持有一览使用缩略 provider，舰队详情头像外观和测试不变。

### 任务 4：缓存装备动态行高

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart:481-680`

- [ ] **步骤 1：编写装备行高缓存失败测试**

先运行并保留现有两项动态行高行为测试：大量着装舰娘时行高增长且不重叠；文字缩放后最后一条长舰名仍位于单元格内。随后通过装备表稳定 Key 验证无关状态更新不会替换表格实例，并在文字缩放或装备数据变化后验证行高与内容发生相应更新。

- [ ] **步骤 2：运行测试确认每次构建都会重新测量**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "equipment rows grow for many wearing ships without overlap"
flutter test test/owned_inventory_page_test.dart --plain-name "equipment row contains the final wearing line with long names and scaled text"
```

预期：当前行为基线通过；缓存实现必须继续满足这两个可观察结果。

- [ ] **步骤 3：将装备表改为 StatefulWidget 并缓存行高**

缓存分组列表引用、`TextScaler`、默认文本样式和行高数组。只有任一输入变化时重新调用 `_equipmentRowHeight`；正文和冻结列始终收到同一数组实例。

- [ ] **步骤 4：运行装备多行回归测试**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "reuses equipment row heights until layout inputs change"
flutter test test/owned_inventory_page_test.dart --plain-name "equipment rows grow for many wearing ships without overlap"
flutter test test/owned_inventory_page_test.dart --plain-name "equipment row contains the final wearing line with long names and scaled text"
```

预期：全部通过，无重叠、截断或冻结列错位。

### 任务 5：滚动同步保护与完整验证

**文件：**
- 修改：`lib/src/inventory/owned_inventory_page.dart:802-965`
- 修改：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写连续滚动同步测试**

连续拖动正文垂直列表和横向列表，断言冻结列偏移等于正文偏移、表头偏移等于正文横向偏移，并且测试期间没有滚动越界异常。

- [ ] **步骤 2：运行测试确认基线行为**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "keeps lazy frozen rows and header synchronized while scrolling"`

预期：若现有同步在惰性列表下重复触发或越界则 FAIL；否则测试记录可接受基线。

- [ ] **步骤 3：增加同步重入与范围保护**

用布尔重入标记保护 `_syncHeader` 与 `_syncFrozen`；同步目标使用目标 position 的 `minScrollExtent/maxScrollExtent` 夹取，并只在偏移差大于容差时 `jumpTo`。widget 数据或行高变化后在 post-frame 阶段夹取已有偏移。

- [ ] **步骤 4：格式化、静态检查和完整测试**

运行：

```powershell
dart format lib/src/inventory/owned_inventory_page.dart lib/src/fleet/ship_portrait.dart test/owned_inventory_page_test.dart
flutter analyze lib/src/inventory/owned_inventory_page.dart lib/src/fleet/ship_portrait.dart test/owned_inventory_page_test.dart
flutter test test/owned_inventory_projection_test.dart test/owned_inventory_page_test.dart test/fleet_information_center_test.dart
flutter build apk --debug
```

预期：静态检查 0 issues；所有相关测试通过；生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 5：审查最终差异**

运行：

```powershell
git diff --check
git diff -- lib/src/inventory/owned_inventory_page.dart lib/src/fleet/ship_portrait.dart test/owned_inventory_page_test.dart
```

确认只包含规格内性能改造，未改变列宽、字体、颜色、标签、筛选、排序和分类。
