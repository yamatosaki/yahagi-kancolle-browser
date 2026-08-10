# 战果 EO／任务矩阵实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将四组 EO／任务状态改为可切换的 4×4 矩阵，增加动态已获得战果，并优化玩家行和日历字号。

**架构：** `demo-state.js` 用纯 reducer 处理格子切换并用选择器计算完成战果；`demo-ui.js` 动态渲染 15 个格子并以嵌套详情按钮区分两种点击；CSS 固定矩阵、玩家双行和五档字号。现有任务详情、排行榜刷新、自动同步和日历数据流继续复用。

**技术栈：** 原生 HTML、CSS、JavaScript，Node.js `node:test`，PowerShell 契约检查，Chromium 页面测量。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`——切换动作和已完成战果选择器。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`——切换、合计、日期和无效 ID 测试。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`——矩阵容器和汇总行。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`——矩阵渲染、主体切换、详情按钮和玩家双行。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`——4×4、汇总、玩家两行和日历字号。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`——新结构和旧四组结构删除契约。

### 任务 1：状态切换与完成战果

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`

- [ ] **步骤 1：添加失败测试**

```js
test('completed senka sums every green EO and quest', () => {
  assert.equal(selectCompletedSenka(createInitialState()), 725);
});

test('matrix item toggle changes completion and clears an old completion day', () => {
  let state = reduce(createInitialState(), { type: 'toggle-item', kind: 'quest', id: 888 });
  assert.equal(state.questItems.find((item) => item.id === 888).completed, true);
  assert.equal(selectCompletedSenka(state), 925);
  state = reduce(state, { type: 'toggle-item', kind: 'eo', id: 15 });
  assert.equal(state.eoItems.find((item) => item.id === 15).completedDay, undefined);
  assert.equal(selectDailySenka(state, 3).eo, 0);
});
```

- [ ] **步骤 2：运行测试确认因 `selectCompletedSenka` 和 `toggle-item` 缺失而失败**

运行：`node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"`

- [ ] **步骤 3：实现最小状态逻辑**

```js
const selectCompletedSenka = (state) => [...state.eoItems, ...state.questItems]
  .filter((item) => item.completed)
  .reduce((sum, item) => sum + item.value, 0);

case 'toggle-item': {
  const key = action.kind === 'eo' ? 'eoItems' : action.kind === 'quest' ? 'questItems' : null;
  if (!key || !state[key].some((item) => item.id === Number(action.id))) return state;
  return {
    ...state,
    [key]: state[key].map((item) => item.id !== Number(action.id)
      ? item
      : item.completed
        ? { ...item, completed: false, completedDay: undefined }
        : { ...item, completed: true }),
  };
}
```

- [ ] **步骤 4：运行测试确认全部通过**

运行：`node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"`

### 任务 2：矩阵与玩家双行 DOM

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`

- [ ] **步骤 1：先添加失败契约**

```powershell
foreach ($token in @('id="senkaMatrix"', 'id="completedSenkaTotal"', 'class="matrix-summary"')) {
  if (-not $html.Contains($token)) { throw "Missing matrix token: $token" }
}
foreach ($token in @('class="status-row"', 'data-status-items=')) {
  if ($html.Contains($token)) { throw "Legacy status groups remain: $token" }
}
```

- [ ] **步骤 2：运行契约检查确认失败**

运行：`powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"`

- [ ] **步骤 3：替换状态卡骨架**

```html
<div class="senka-matrix" id="senkaMatrix" aria-label="EO 与战果任务完成矩阵"></div>
<div class="matrix-summary"><span>本月已获得战果</span><b id="completedSenkaTotal">+0</b></div>
```

- [ ] **步骤 4：动态渲染矩阵并分离点击区域**

`renderSenkaMatrix` 按 8 个 EO、7 个任务和 1 个空占位生成 16 格。格子主体使用 `data-matrix-kind`、`data-matrix-id` 和 `aria-pressed`；任务格内的 `data-quest-detail-id` 小按钮显示 `›`。矩阵事件委托优先处理详情按钮，否则派发 `toggle-item`。任务简称使用 `shortName`，EO 使用 `label.split(' ')[0]`。

排行榜玩家条目渲染为一个 `.ranking-current-group`，内部先输出横跨三列的 `.ranking-current-label`，再输出原三列 `.ranking-row.player`；参考线结构不变。

- [ ] **步骤 5：运行语法、状态和契约检查**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

### 任务 3：响应式样式与交互验收

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`

- [ ] **步骤 1：实现固定 4×4 和汇总**

```css
.senka-matrix { min-height: 0; padding: 5px 7px; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); grid-template-rows: repeat(4, minmax(0, 1fr)); gap: 4px; }
.matrix-cell { min-width: 0; min-height: 0; display: flex; align-items: center; }
.matrix-cell.completed { border-color: #477c62; background: #173a2d; color: #a9e7c0; }
.matrix-cell.pending { border-color: #8a6c32; background: #3a2d16; color: #f4cf79; }
.matrix-summary { display: flex; align-items: center; justify-content: space-between; }
```

- [ ] **步骤 2：实现玩家双行与日历字号**

`.ranking-current-group` 使用统一高亮外框；`.ranking-current-label` 横跨三列；玩家数据行取消自身外框。大屏／竖屏设置 `.calendar-day b { font-size: 16px }` 和 `.calendar-day span { font-size: 12px }`，两种手机横屏覆盖为 `14px / 10px`。

- [ ] **步骤 3：浏览器验收五档**

测量 1280×680、1024×600、800×1100、844×390、740×360：应用内容、三张卡、16 格矩阵、汇总、排行榜和日历均要求 `scrollWidth <= clientWidth` 且 `scrollHeight <= clientHeight`；日历保持 42 格。

- [ ] **步骤 4：验证点击行为**

初始汇总为 `+725`；点击 `Bq7` 主体后变绿且汇总为 `+925`；点击其 `›` 后进入 ID 888 详情且完成状态不变；返回后状态保留。自动同步仍更新 10 日。

- [ ] **步骤 5：运行最终检查**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

预期：全部 PASS，五档测量均零溢出。
