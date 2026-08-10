# 战果汇总文字与数值颜色实现计划

> **面向 AI 代理的工作者：** 使用 superpowers:executing-plans 逐任务实现此计划，并用复选框跟踪进度。

**目标：** 将月度已记录和日历底部明细拆分为白色标签与黄色数值，并统一为矩阵汇总字号。

**架构：** `demo-ui.js` 输出可独立着色的标签和值元素；`styles.css` 用共享的 `.senka-value` 规则映射黄色，用尺寸覆盖统一 12px／8px；PowerShell 契约和浏览器测量验证结构、颜色与零溢出。

**技术栈：** 原生 HTML、CSS、JavaScript，PowerShell 契约检查，Chromium 页面测量。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`——为月度已记录标签增加明确类名。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js`——输出 `8月10日 +3.8` 和带加号的经验值。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`——统一标签白色、数值黄色和响应式字号。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`——锁定新 DOM 与颜色类。

### 任务 1：锁定并实现分段 DOM

- [ ] **步骤 1：在契约中要求 `month-total-label`、`day-label` 和 `senka-value`**

```powershell
foreach ($token in @('class="month-total-label"', 'class="day-label"', 'class="senka-value"')) {
  if (-not ($html.Contains($token) -or $ui.Contains($token))) { throw "Missing summary token: $token" }
}
```

- [ ] **步骤 2：运行契约并确认因新类不存在而失败**

运行：`powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"`

- [ ] **步骤 3：修改月度汇总 HTML**

```html
<span class="month-total"><span class="month-total-label">本月已记录</span><b id="calendarTotal">0.0</b></span>
```

- [ ] **步骤 4：修改 `renderDayDetail()` 的有数据输出**

```js
byId('dayDetail').innerHTML = `
  <span class="day-item day-date"><span class="day-label">8月${day}日</span><b class="senka-value">+${daily.total.toFixed(1)}</b></span>
  <span class="day-item"><span class="day-label">经验</span><b class="senka-value">+${daily.experience.toFixed(1)}</b></span>
  <span class="day-item"><span class="day-label">EO</span><b class="senka-value">+${daily.eo.toFixed(1)}</b></span>
  <span class="day-item"><span class="day-label">任务</span><b class="senka-value">+${daily.quest.toFixed(1)}</b></span>`;
```

- [ ] **步骤 5：运行语法检查和契约并确认通过**

### 任务 2：统一颜色、字号并验收

- [ ] **步骤 1：新增常规尺寸共享样式**

```css
.month-total, .month-total b, .day-detail, .day-detail b { font-size: 12px; }
.month-total-label, .day-label { color: #dce6eb; }
.month-total b, .senka-value { color: var(--gold); }
```

- [ ] **步骤 2：新增手机横屏 8px 覆盖，并保持 `.day-item` 单行**

- [ ] **步骤 3：运行全部自动检查**

```powershell
node --check "G:/kancolle project/ui-demos/senka-manual-calibration/demo-ui.js"
node "G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.test.js"
powershell -ExecutionPolicy Bypass -File "G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1"
```

- [ ] **步骤 4：浏览器验收五档**

每档要求月度标签与矩阵汇总标签字号一致、月度数值与 `+725` 同色同字号；日历底部四个标签同白色、四个 `+数值` 同黄色；底部单行且应用、日历和明细零溢出。
