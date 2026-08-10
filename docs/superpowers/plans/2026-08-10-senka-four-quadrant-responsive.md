# 战果 Demo 四象限响应式布局实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将战果 Demo 改为横屏 2×2、竖屏 1×4 的无滚动布局，让五档尺寸在首屏显示四个核心区域和完整日历。

**架构：** 保留现有状态计算和交互数据流，只收缩 HTML 信息层级并重写响应式 CSS。静态 PowerShell 契约先锁定被删除内容、四象限标记和无滚动规则，再通过浏览器读取五档布局的实际尺寸。

**技术栈：** HTML、CSS、原生 JavaScript、Node.js `node:test`、PowerShell 静态契约、浏览器实测。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`，定义四象限布局的静态验收契约。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`，删除辅助说明和状态长列表。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`，移除状态长列表和校准说明的渲染依赖。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`，实现横屏 2×2、竖屏 1×4 和五档紧凑尺寸。
- 验证：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`，确保数值计算和交互状态不回归。

### 任务 1：建立失败的四象限静态契约

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`

- [ ] **步骤 1：将新布局要求写入契约**

从 `$requiredHtml` 删除 `id="statusList"`，并要求以下 CSS 标记：

```powershell
foreach ($layoutRule in @(
  '--senka-four-quadrant: 1',
  '--senka-portrait-stack: 1',
  'overflow: hidden',
  'grid-template-rows: repeat(6, minmax(0, 1fr))'
)) {
  if (-not $css.Contains($layoutRule)) {
    throw "Missing responsive layout contract: $layoutRule"
  }
}
```

把以下内容加入禁止列表：

```powershell
'id="calibrationNote"',
'class="calibration-note"',
'class="status-list-heading"',
'id="statusList"',
'class="status-note"',
'排名页数据是服务器锚点',
'手动校准不会主动重放游戏请求'
```

- [ ] **步骤 2：运行契约并确认红灯**

运行：

```powershell
powershell -ExecutionPolicy Bypass -File "G:\kancolle project\ui-demos\senka-manual-calibration\verify-demo.ps1"
```

预期：失败，首先报告仍存在 `id="calibrationNote"` 或缺少 `--senka-four-quadrant: 1`。

### 任务 2：删除非核心内容及其渲染依赖

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`

- [ ] **步骤 1：删除 HTML 辅助区域**

删除 `.calibration-note`、`.status-list-heading`、`#statusList` 和 `.status-note`。保留 `.gap-warning`，因为它是跨设备游玩缺口的状态反馈，不是静态辅助说明。

- [ ] **步骤 2：删除 JavaScript 的长列表数据和 DOM 写入**

删除 `statusSources`，并把 `renderStatusGroups()` 收缩为仅更新四项统计与选中态：

```javascript
function renderStatusGroups() {
  const groups = selectStatusGroups(state);
  groups.forEach((group) => {
    const [countId, totalId] = statusIds[group.key];
    byId(countId).textContent = group.count;
    byId(totalId).textContent = `+${format.format(group.total)}`;
  });
  all('[data-status-key]').forEach((button) => {
    const selected = button.dataset.statusKey === state.selectedStatus;
    button.classList.toggle('active', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
}
```

从 `render()` 删除对 `calibrationNote` 的赋值。加载态继续由按钮文字和 Toast 呈现。

- [ ] **步骤 3：运行状态测试**

运行：

```powershell
node "G:\kancolle project\ui-demos\senka-manual-calibration\demo-state.test.js"
```

预期：8 项测试全部通过。

### 任务 3：实现四象限响应式布局

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`

- [ ] **步骤 1：建立统一四象限基线**

为横屏四档设置固定 2×2 网格，四张卡分别占据一个象限：

```css
.app-content { --senka-four-quadrant: 1; }
.hero-card { grid-column: 1; grid-row: 1; }
.target-card { grid-column: 2; grid-row: 1; }
.status-card { grid-column: 1; grid-row: 2; }
.calendar-card { grid-column: 2; grid-row: 2; }
```

四张卡均使用 `overflow: hidden`，内容区不得使用 `overflow-y: auto`。

- [ ] **步骤 2：压缩四张卡内部结构**

- 当前战果：主数值、目标进度和三项构成紧凑排列，移除自动撑底。
- 本月目标：保留输入、两项汇总、进度条与图例。
- EO 与任务：四项状态格改为 2×2，填满卡片剩余高度。
- 战果日历：标题、星期、6 行日期和单行明细按可用高度分配。

- [ ] **步骤 3：设置竖屏 1×4**

```css
.app.tablet-portrait .app-content {
  --senka-portrait-stack: 1;
  grid-template-columns: 1fr;
  grid-template-rows: 210px 150px 210px minmax(300px, 1fr);
  overflow: hidden;
}
```

四张卡依次放在第 1–4 行，并确保总高度加间距不超过应用内容区。

- [ ] **步骤 4：设置手机两档紧凑参数**

手机横屏和紧凑横屏使用更小标题栏、间距、卡片标题、主数值和日历字号；不隐藏四张卡，不设置页面或内容区滚动。

- [ ] **步骤 5：运行静态契约确认绿灯**

运行：

```powershell
powershell -ExecutionPolicy Bypass -File "G:\kancolle project\ui-demos\senka-manual-calibration\verify-demo.ps1"
```

预期：输出 `Senka demo contract OK`。

### 任务 4：五档浏览器与交互回归

**文件：**
- 验证：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`

- [ ] **步骤 1：测量五档预设**

对每档读取 `.app-content`、四张卡和 `#calendarGrid` 的 `clientWidth`、`clientHeight`、`scrollWidth`、`scrollHeight`。验收：

- 四张卡均可见且位于应用边界内。
- `.app-content.scrollHeight <= .app-content.clientHeight + 1`。
- 手机两档日历完整显示 6 行日期，日历格无纵向溢出。
- 页面无横向溢出。

- [ ] **步骤 2：验证交互**

依次验证：模拟自动同步使预计战果由 `3,548` 增加；目标输入更新差值；四项状态可切换选中态；有记录日期可选择；手动校准进入加载态后恢复。

- [ ] **步骤 3：运行完整回归**

```powershell
node "G:\kancolle project\ui-demos\senka-manual-calibration\demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:\kancolle project\ui-demos\senka-manual-calibration\verify-demo.ps1"
```

预期：8/8 测试通过，静态契约输出 `Senka demo contract OK`。

- [ ] **步骤 4：恢复默认预览**

刷新页面并选择「大平板」，确保浏览器留在默认初始状态供用户查看。
