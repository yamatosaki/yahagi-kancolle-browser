# 战果状态胶囊与任务跳转实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将战果 Demo 改为紧凑的四行 EO／任务胶囊，并让任务胶囊可进入对应的模拟“全任务”详情，同时提高日历可读性。

**架构：** `demo-state.js` 继续保存唯一演示状态，并补充展示简称和详情选择状态；`demo-ui.js` 根据四个状态组动态生成胶囊，通过任务 ID 驱动详情视图；`index.html` 只提供页面骨架；`styles.css` 负责五档无滚动布局。正式客户端跳转约定记录在设计规格中，本计划只修改独立 HTML Demo。

**技术栈：** 原生 HTML、CSS、JavaScript，Node.js `node:test`，PowerShell 契约检查，Chromium 浏览器尺寸验证。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`——任务简称、任务详情状态与纯状态转换。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`——简称、打开／关闭详情和同步后分组测试。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`——顺位位置、紧凑战果胶囊、四行状态容器和任务详情画面。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`——动态状态胶囊渲染、颜色类、任务详情跳转和返回。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`——紧凑布局、完成度配色、详情画面和日历字号。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`——新增 DOM、文案、配色语义与跳转契约检查。

### 任务 1：补齐状态模型与失败测试

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`

- [ ] **步骤 1：添加任务简称和详情状态测试**

```js
test('quest groups expose compact labels', () => {
  const quests = selectStatusGroups(createInitialState())
    .find((group) => group.key === 'unconfirmed-quest').items;
  assert.deepEqual(quests.map((item) => item.shortLabel), [
    'Bq7 三川舰队', 'Bq8 泊地周边', 'Bq10 Z作战后',
    'Bq11 海上警备', 'Bq12 西方海域', 'Bq13 六水战',
  ]);
});

test('quest detail opens by id and returns to senka', () => {
  let state = reduce(createInitialState(), { type: 'open-quest', id: 893 });
  assert.equal(state.openQuestId, 893);
  state = reduce(state, { type: 'close-quest' });
  assert.equal(state.openQuestId, null);
});
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"`

预期：新增测试因 `shortLabel` 和 `openQuestId` 尚未实现而失败。

- [ ] **步骤 3：添加展示字段和详情动作**

```js
const QUEST_ITEMS = [
  { id: 854, code: 'Bq2', shortName: 'Z作战前', label: 'Z 作战前段', value: 350, completed: true, completedDay: 7 },
  { id: 888, code: 'Bq7', shortName: '三川舰队', label: '新编三川舰队', value: 200, completed: false },
  { id: 893, code: 'Bq8', shortName: '泊地周边', label: '泊地周边海域安全确保', value: 300, completed: false },
  { id: 872, code: 'Bq10', shortName: 'Z作战后', label: 'Z 作战后段', value: 400, completed: false },
  { id: 284, code: 'Bq11', shortName: '海上警备', label: '海上警备行动', value: 80, completed: false },
  { id: 845, code: 'Bq12', shortName: '西方海域', label: '西方海域作战', value: 330, completed: false },
  { id: 903, code: 'Bq13', shortName: '六水战', label: '扩张六水战、最前线', value: 390, completed: false },
];

const withDisplayLabel = (item, isQuest) => ({
  ...item,
  shortLabel: isQuest ? `${item.code} ${item.shortName}` : String(item.id).replace(/(.)5$/, '$1-5'),
});

// 初始状态
openQuestId: null,

// reducer
case 'open-quest':
  return state.questItems.some((item) => item.id === Number(action.id))
    ? { ...state, openQuestId: Number(action.id) }
    : state;
case 'close-quest':
  return { ...state, openQuestId: null };
```

EO 的 `shortLabel` 应直接由 `label` 的第一个空格前内容生成，避免依赖 ID 格式。

- [ ] **步骤 4：运行状态测试并确认通过**

运行：`node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"`

预期：全部测试 PASS。

### 任务 2：建立四行胶囊和任务详情 DOM

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`

- [ ] **步骤 1：先扩展契约检查**

```powershell
Assert-Contains $html 'id="questDetailView"'
Assert-Contains $html 'id="senkaView"'
Assert-Contains $html 'id="questDetailBack"'
Assert-Contains $ui 'data-quest-id'
Assert-Contains $ui "type: 'open-quest'"
Assert-Contains $css '.status-chip.completed'
Assert-Contains $css '.status-chip.pending'
```

- [ ] **步骤 2：运行契约检查并确认失败**

运行：`powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"`

预期：FAIL，提示新增的详情视图或胶囊选择器不存在。

- [ ] **步骤 3：调整 HTML 骨架**

```html
<div class="app-screen" id="senkaView">
  <!-- 原 app-bar 与 app-content -->
</div>
<section class="quest-detail-view" id="questDetailView" hidden>
  <header class="app-bar"><button id="questDetailBack" type="button">‹</button><h1>全任务</h1></header>
  <div class="quest-detail-shell" id="questDetailContent"></div>
</section>
```

把顺位胶囊移动到 `.hero-main` 内、主数值左侧；删除三项战果分项中的 `<em>`；把四个固定 `status-tile` 改成四个带标题、合计和 `data-status-items` 容器的 `status-row`。

- [ ] **步骤 4：实现动态胶囊和视图切换**

```js
function renderStatusGroups() {
  selectStatusGroups(state).forEach((group) => {
    const container = document.querySelector(`[data-status-items="${group.key}"]`);
    const completed = group.key.startsWith('completed-');
    container.innerHTML = group.items.map((item) => {
      const quest = group.key.endsWith('quest');
      return quest
        ? `<button class="status-chip ${completed ? 'completed' : 'pending'}" data-quest-id="${item.id}">${item.shortLabel}</button>`
        : `<span class="status-chip ${completed ? 'completed' : 'pending'}">${item.shortLabel}</span>`;
    }).join('');
  });
}

function renderQuestDetail() {
  const quest = state.questItems.find((item) => item.id === state.openQuestId);
  byId('senkaView').hidden = Boolean(quest);
  byId('questDetailView').hidden = !quest;
  if (quest) byId('questDetailContent').innerHTML = `
    <aside><b>全任务</b><button class="selected">${quest.code} ${quest.label}</button></aside>
    <article><span>${quest.code}</span><h2>${quest.label}</h2>
      <p>${quest.completed ? '已完成' : '未确认'} · 战果 +${quest.value}</p></article>`;
}
```

状态区使用事件委托读取 `data-quest-id`，派发 `open-quest`；返回按钮派发 `close-quest`。状态组不再响应选择动作，也不再渲染数量。

- [ ] **步骤 5：运行状态测试和契约检查**

运行：

```powershell
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

预期：两条命令均 PASS。

### 任务 3：压缩布局并提高日历可读性

**文件：**
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`

- [ ] **步骤 1：实现紧凑战果分项和四行状态布局**

```css
.senka-metrics article { height: 48px; padding: 6px 8px 6px 20px; }
.senka-metrics em { display: none; }
.status-grid { display: grid; grid-template-rows: repeat(4, minmax(0, 1fr)); }
.status-row { min-height: 0; display: grid; grid-template-columns: auto auto minmax(0, 1fr); }
.status-items { min-width: 0; display: flex; flex-wrap: wrap; align-content: center; }
.status-chip.completed { border-color: #477c62; background: #173a2d; color: #a9e7c0; }
.status-chip.pending { border-color: #8a6c32; background: #3a2d16; color: #f4cf79; }
```

- [ ] **步骤 2：重新分配横屏左栏行高并增大日历字号**

横屏把左栏三行调整为约 `0.88fr 0.58fr 1.21fr`；手机横屏进一步减少面板标题、边距和卡片间距。日期数字不得低于 10px，每日战果不得低于 8px，星期不得低于 9px；竖屏使用更大字号。

- [ ] **步骤 3：为任务详情建立同尺寸视图样式**

```css
.app-screen, .quest-detail-view { width: 100%; height: 100%; }
.quest-detail-view[hidden], .app-screen[hidden] { display: none; }
.quest-detail-shell { height: calc(100% - var(--app-bar-height)); display: grid; grid-template-columns: 42fr 58fr; }
```

紧凑宽度仍显示任务列表摘要和详情，不产生页面滚动；返回按钮位置与战果页一致。

### 任务 4：浏览器交互与五档验收

**文件：**
- 验证：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`

- [ ] **步骤 1：启动本地服务器并打开 Demo**

运行：`python -m http.server 8765 --directory "G:/kancolle project/ui-demos/senka-manual-calibration"`

打开：`http://127.0.0.1:8765/`

- [ ] **步骤 2：逐档检查边界和溢出**

在 1280×680、1024×600、800×1100、844×390、740×360 五档检查：应用、四张卡、日历、四个状态组的 `scrollWidth <= clientWidth` 且 `scrollHeight <= clientHeight`；横屏日历完整显示 42 个格位和选中日明细。

- [ ] **步骤 3：检查任务跳转映射**

依次点击 `Bq2 Z作战前` 与 `Bq8 泊地周边`，确认进入“全任务”详情、任务代码和完整名称分别匹配 ID 854 与 893；点击返回后恢复战果页。

- [ ] **步骤 4：检查动态状态更新**

点击“模拟自动同步”，确认 `1-6` 和 `Bq7 三川舰队` 从黄色未完成／未确认组移入绿色完成组，四组战果合计同步变化，日历 10 日数值更新。

- [ ] **步骤 5：运行最终自动检查**

运行：

```powershell
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

预期：全部状态测试和 Demo 契约检查 PASS。
