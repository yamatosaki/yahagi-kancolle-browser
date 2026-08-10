# 战果排行榜信息表实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 用三列排行榜信息表替换战果摘要和本月目标，并完整保留 EO／任务、日历与任务详情交互。

**架构：** `demo-state.js` 提供排行榜快照和纯选择器，`demo-ui.js` 只负责格式化渲染与派发刷新动作；HTML 提供固定三列表格骨架，CSS 将横屏改为左侧两行、竖屏改为三行。测试覆盖顺位方向、空值、刷新和自动同步，浏览器测量覆盖五档溢出。

**技术栈：** 原生 HTML、CSS、JavaScript，Node.js `node:test`，PowerShell 契约检查，Chromium 页面测量。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`——排行榜快照、变化选择器和刷新动作。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`——顺位方向、增幅、缺失值和刷新测试。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`——删除旧摘要与目标，增加排行榜三列表格。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`——排行榜渲染及刷新交互。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`——两块左栏、三列表格和竖屏 1×3。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`——新结构和旧结构删除契约。

### 任务 1：排行榜状态与选择器

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`

- [ ] **步骤 1：添加失败测试**

```js
test('ranking rows expose aligned point deltas and player rank direction', () => {
  const rows = selectRankingRows(createInitialState());
  assert.deepEqual(rows.map(({ rank, senka, senkaDelta }) => ({ rank, senka, senkaDelta })), [
    { rank: 5, senka: 4755, senkaDelta: 0 },
    { rank: 20, senka: null, senkaDelta: null },
    { rank: 100, senka: null, senkaDelta: null },
    { rank: 501, senka: 1144, senkaDelta: 0 },
    { rank: 3874, senka: 108, senkaDelta: 78.8 },
  ]);
  assert.deepEqual(rows.at(-1).rankTrend, { direction: 'down', amount: 42 });
});

test('calibration replaces the ranking snapshot', () => {
  const state = reduce(createInitialState(), { type: 'calibration-success' });
  const rows = selectRankingRows(state);
  assert.deepEqual(rows.at(-1).rankTrend, { direction: 'up', amount: 42 });
  assert.equal(rows.at(-1).senka, 112);
  assert.equal(rows.at(-1).senkaDelta, 4.2);
});
```

- [ ] **步骤 2：运行测试确认因 `selectRankingRows` 缺失而失败**

运行：`node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"`

- [ ] **步骤 3：实现最小排行榜状态**

```js
ranking: {
  updatedAt: '8 月 10 日 03:00',
  anchors: [
    { rank: 5, senka: 4755, previousSenka: 4755 },
    { rank: 20, senka: null, previousSenka: null },
    { rank: 100, senka: null, previousSenka: null },
    { rank: 501, senka: 1144, previousSenka: 1144 },
  ],
  player: { rank: 3874, previousRank: 3832, senka: 108, localDelta: 78.8 },
}
```

`selectRankingRows` 将非有限值转换为 `null`，用 `previousRank - rank` 生成 `up/down/same`；`calibration-success` 替换为规格中的第二组固定快照。`auto-sync` 在原有任务完成逻辑之外把获得战果累加到 `ranking.player.localDelta`，不修改 `rank`。

- [ ] **步骤 4：运行测试确认全部通过**

运行：`node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"`

预期：全部测试 PASS。

### 任务 2：排行榜 DOM 与交互

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`

- [ ] **步骤 1：先扩展契约检查**

```powershell
foreach ($token in @('class="ranking-card panel"', 'id="rankingRows"', 'id="rankingUpdatedAt"', 'class="ranking-table-head"')) {
  if (-not $html.Contains($token)) { throw "Missing ranking token: $token" }
}
foreach ($token in @('class="hero-card panel"', 'class="target-card panel"', 'id="targetInput"', 'class="senka-breakdown senka-metrics"')) {
  if ($html.Contains($token)) { throw "Removed summary remains: $token" }
}
```

- [ ] **步骤 2：运行契约检查确认失败**

运行：`powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"`

- [ ] **步骤 3：用排行榜卡替换旧两张卡**

```html
<section class="ranking-card panel">
  <div class="panel-heading"><h2>战果信息</h2><span id="rankingUpdatedAt"></span></div>
  <div class="ranking-table">
    <div class="ranking-table-head"><span>顺位</span><span>战果</span><span aria-hidden="true"></span></div>
    <div class="ranking-table-body" id="rankingRows"></div>
  </div>
</section>
```

- [ ] **步骤 4：实现排行榜行渲染**

```js
function renderRanking() {
  const rows = selectRankingRows(state);
  byId('rankingUpdatedAt').textContent = state.ranking.updatedAt;
  byId('rankingRows').innerHTML = rows.map((row) => {
    const trend = row.player && row.rankTrend
      ? `<span class="rank-trend ${row.rankTrend.direction}">${trendArrow(row.rankTrend)}${row.rankTrend.amount}</span>`
      : '';
    return `<div class="ranking-row${row.player ? ' player' : ''}">
      <span>${row.player ? '<i>当前</i>' : ''}<b>${formatValue(row.rank)}</b>${trend}</span>
      <b>${formatValue(row.senka)}</b>
      <span class="senka-trend">${formatSenkaDelta(row.senkaDelta)}</span>
    </div>`;
  }).join('');
}
```

`formatValue(null)` 和 `formatSenkaDelta(null)` 均返回 `—`。第三列表头保持空元素，不写任何文字。删除目标输入和进度条的事件绑定及旧摘要字段渲染。

- [ ] **步骤 5：运行状态测试、语法检查和契约检查**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

预期：全部 PASS。

### 任务 3：响应式布局与浏览器验收

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`

- [ ] **步骤 1：实现横屏两行和竖屏三行**

```css
.app-content { grid-template-columns: minmax(0, 42fr) minmax(0, 58fr); grid-template-rows: minmax(0, 43fr) minmax(0, 57fr); }
.ranking-card { grid-column: 1; grid-row: 1; }
.status-card { grid-column: 1; grid-row: 2; }
.calendar-card { grid-column: 2; grid-row: 1 / 3; }
.app.tablet-portrait .app-content { grid-template-columns: 1fr; grid-template-rows: minmax(0, .62fr) minmax(0, .78fr) minmax(0, 1.25fr); }
```

- [ ] **步骤 2：实现三列左对齐表格**

```css
.ranking-table-head, .ranking-row { display: grid; grid-template-columns: 48fr 27fr 25fr; align-items: center; }
.ranking-table-head span, .ranking-row > * { text-align: left; font-variant-numeric: tabular-nums; }
.ranking-row.player { border-color: #8e6f37; background: #3b2f1e; }
.rank-trend.up, .senka-trend.up { color: #83d7a4; }
.rank-trend.down, .senka-trend.down { color: #ef8d82; }
```

- [ ] **步骤 3：浏览器检查五档**

在 1280×680、1024×600、800×1100、844×390、740×360 中测量应用内容、三张卡、排行榜、状态行和日历，要求 `scrollWidth <= clientWidth` 且 `scrollHeight <= clientHeight`；确认日历 42 格始终可见。

- [ ] **步骤 4：验证交互**

点击“手动校准”，确认玩家从 `3,874 ↓42 / 108 / ↑78.8` 更新为 `3,832 ↑42 / 112 / ↑4.2`；点击“模拟自动同步”，确认顺位不变、本机增幅增加且 EO／任务胶囊移动；点击任务胶囊确认详情跳转仍工作。

- [ ] **步骤 5：运行最终检查**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

预期：全部测试和契约检查 PASS，浏览器五档均零溢出。
