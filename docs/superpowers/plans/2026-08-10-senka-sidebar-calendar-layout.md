# 战果 Demo 左栏与日历布局实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将横屏布局改为左侧 42% 的 1×3 信息栏和右侧 58% 的整列日历，同时保留竖屏 1×4，并更新标题栏顺位胶囊。

**架构：** 只修改布局契约、标题栏结构、初始顺位和响应式 CSS，不改变战果计算与交互数据流。使用静态契约验证结构，再用浏览器测量五档真实尺寸。

**技术栈：** HTML、CSS、原生 JavaScript、Node.js `node:test`、PowerShell、浏览器实测。

---

## 文件结构

- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/verify-demo.ps1`，锁定新布局与标题栏契约。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/index.html`，删除月度状态并改造顺位胶囊。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/demo-state.js`，把初始顺位改为 `431`。
- 修改：`G:/kancolle project/ui-demos/senka-manual-calibration/styles.css`，实现横屏左栏／整列日历和竖屏 1×4。

### 任务 1：建立失败的结构契约

- [ ] 修改 `verify-demo.ps1`，要求 `class="rank-pill"`、`--senka-sidebar-calendar: 1`、`grid-template-columns: minmax(0, 42fr) minmax(0, 58fr)` 和 `white-space: nowrap`。
- [ ] 将 `class="period-pill"` 与「月度作战进行中」加入禁止列表。
- [ ] 运行 `powershell -ExecutionPolicy Bypass -File "G:\kancolle project\ui-demos\senka-manual-calibration\verify-demo.ps1"`。
- [ ] 确认失败原因是缺少 `class="rank-pill"` 或仍存在 `class="period-pill"`。

### 任务 2：更新标题栏与顺位数据

- [ ] 从 `index.html` 删除 `.period-pill`。
- [ ] 用 `<div class="rank-pill">当前顺位：<b id="rankValue">431</b></div>` 替换 `.rank-brief`。
- [ ] 把 `demo-state.js` 初始 `rank` 改为 `431`。
- [ ] 保留 `demo-ui.js` 对 `#rankValue` 的纯数字渲染，不再添加 `#`。
- [ ] 运行 `node "G:\kancolle project\ui-demos\senka-manual-calibration\demo-state.test.js"`，预期 8/8 通过。

### 任务 3：实现横屏左栏与整列日历

- [ ] 在 `styles.css` 增加 `--senka-sidebar-calendar: 1`，横屏列使用 `42fr 58fr`。
- [ ] 左栏 3 行依次放置 `.hero-card`、`.target-card`、`.status-card`。
- [ ] `.calendar-card` 放在第 2 列并跨 `grid-row: 1 / 4`。
- [ ] 平板竖屏保留单列 1×4，并覆盖横屏跨行规则。
- [ ] 删除 `.period-pill`、`.rank-brief` 的废弃样式，增加不换行 `.rank-pill` 胶囊。
- [ ] 运行静态契约，预期输出 `Senka demo contract OK`。

### 任务 4：五档回归

- [ ] 浏览器测量五档 `.app-content` 和四张卡的 `clientHeight`、`scrollHeight`、位置与显示状态。
- [ ] 横屏四档确认左栏宽度占比约 42%，日历跨满 3 行。
- [ ] 竖屏确认 1×4，五档均无页面或卡片滚动。
- [ ] 验证顺位胶囊文本为「当前顺位：431」且单行。
- [ ] 回归目标输入、自动同步、状态选择、日期选择、跨设备开关和手动校准。
- [ ] 重新运行 8 项状态测试与静态契约，并恢复默认大平板预览。
