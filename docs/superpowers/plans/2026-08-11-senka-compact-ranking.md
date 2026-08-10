# 战果页紧凑排名与统一字号实现计划

> **面向 AI 代理的工作者：** 使用 superpowers:executing-plans 逐任务实现此计划，并用复选框跟踪进度。

**目标：** 将左栏调整为战果信息 60%／EO 任务 40%，实现六行等高排行榜、紧凑大字矩阵、统一底部字号，并删除手动校准入口。

**架构：** 通过 PowerShell 契约先锁定 DOM 删除和新增结构；`demo-ui.js` 只保留当前页面使用的交互；CSS 最终覆盖层负责五档尺寸的比例、等高行与字体映射。状态层保持不变。

**技术栈：** 原生 HTML、CSS、JavaScript，Node.js `node:test`，PowerShell 契约检查，Chromium 页面测量。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`——新增删除校准入口、六行排名和紧凑布局契约。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`——删除手动校准按钮并增加顶栏对称空白。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`——删除校准渲染、计时器、函数和监听。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`——实现 60%／40%、六行等高、矩阵放大字体和底部统一字号。

### 任务 1：删除手动校准 UI

- [ ] **步骤 1：修改契约，使 `calibrateButton` 成为禁止内容并要求 `titlebar-spacer`**

```powershell
$requiredHtml += 'class="titlebar-spacer"'
$forbidden += 'id="calibrateButton"'
```

- [ ] **步骤 2：运行契约并确认因旧按钮仍存在而失败**

运行：`powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"`

- [ ] **步骤 3：从 HTML 删除按钮，加入 `<span class="titlebar-spacer" aria-hidden="true"></span>`**

- [ ] **步骤 4：从 UI 脚本删除 `reduceMotion`、`calibrationTimer`、校准加载态渲染、`calibrate()` 和按钮监听**

- [ ] **步骤 5：运行语法检查与契约并确认通过**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

### 任务 2：实现六行等高排行榜和 60%／40% 左栏

- [ ] **步骤 1：在契约中要求六行网格和 60／40 比例标记**

```powershell
$layoutRule += 'grid-template-rows: repeat(6, minmax(0, 1fr))'
$layoutRule += '--senka-ranking-share: 60'
$layoutRule += '--senka-matrix-share: 40'
```

- [ ] **步骤 2：运行契约并确认缺少新布局规则而失败**

- [ ] **步骤 3：新增 CSS 最终覆盖**

```css
.app-content { --senka-ranking-share: 60; --senka-matrix-share: 40; grid-template-rows: minmax(0, 60fr) minmax(0, 40fr); }
.ranking-table-body { grid-template-rows: repeat(6, minmax(0, 1fr)); }
.ranking-current-group { grid-row: span 2; grid-template-rows: repeat(2, minmax(0, 1fr)); }
.ranking-table-head, .ranking-current-label { font-size: 12px; }
```

- [ ] **步骤 4：添加手机横屏覆盖，使表头和当前字号为 8px，并保持六行等高**

- [ ] **步骤 5：运行契约检查并确认通过**

### 任务 3：压缩矩阵并统一底部字号

- [ ] **步骤 1：将矩阵常规字号设为 11px、手机字号设为 8px**

- [ ] **步骤 2：将矩阵汇总两段文字统一为 12px，手机统一为 8px**

- [ ] **步骤 3：将日历明细四段文字统一为 12px 白色，手机统一为 8px 白色**

```css
.matrix-summary, .matrix-summary b { font-size: 12px; }
.day-detail, .day-detail b, .day-detail span { color: #dce6eb; font-size: 12px; }
.app.phone-wide .day-detail, .app.phone-compact .day-detail,
.app.phone-wide .day-detail b, .app.phone-compact .day-detail b,
.app.phone-wide .day-detail span, .app.phone-compact .day-detail span { font-size: 8px; }
```

- [ ] **步骤 4：运行全部自动检查**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js"
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

- [ ] **步骤 5：浏览器验收五档尺寸**

测量 1280×680、1024×600、800×1100、844×390、740×360：应用、三张卡、排名表、矩阵、日历均为零溢出；排名参考行、当前行和个人行等高；矩阵 16 格；日历 42 格；指定字号符合 12px／8px；手动校准按钮不存在。
