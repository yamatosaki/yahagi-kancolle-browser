# 无伤基地空袭识别修复设计

## 问题与证据

实机 J 点的 `/kcsapi/api_req_map/next` 响应包含 `api_destruction_battle`、`api_f_nowhps: [200]` 和 `api_f_maxhps: [200]`，但 `api_air_base_attack.api_stage_flag` 为 `[1,0,0]`，不存在 `api_stage3`。当前实现要求 `api_stage3` 存在才承认基地空袭，因此把无伤防空误判成没有基地空袭。

## 修复规则

- `api_destruction_battle` 存在且包含有效基地当前/最大 HP 时，即视为基地空袭。
- `api_air_base_attack.api_stage3.api_fdam` 存在时继续按原逻辑计算伤害。
- `api_stage3` 或 `api_fdam` 缺失时，将对应基地伤害视为 0，不取消整个空袭结果。
- 无有效基地 HP 的畸形数据仍不生成空袭结果。
- 现有负数哨兵、字符串形式的 `api_air_base_attack` 和多基地映射保持兼容。

## 修改范围

- `BattleController._landBaseRaid`：允许缺少 stage3 的无伤空袭生成 `LandBaseRaidResult`。
- `GameStateReducer._applyLandBaseRaid`：采用相同规则更新基地 HP 与 `lastRaidDamage = 0`。
- 不改变普通航空战、空袭战节点分类和战斗预测算法。

## 验证

- 使用从实机响应最小化得到的 `[1,0,0]`、`200/200`、无 stage3 数据分别覆盖控制器和状态 reducer。
- 断言未卜先知阶段为“基地空袭”、基地保持 `200/200`、伤害为 0。
- 保留并运行原有有伤害、字符串嵌套和返回母港清理测试。
- 该修复仅修改 Dart 解析逻辑，常驻 Debug 使用黄色闪电热重载即可。
