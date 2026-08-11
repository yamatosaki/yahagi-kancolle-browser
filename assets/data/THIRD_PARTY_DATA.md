# 第三方数据说明 (Third-Party Data Notice)

## 舰队 Collection 任务目录

`quests-scn.json` 是合并目录：日文任务名称、说明和奖励来自 [Kcanotify game data](https://github.com/antest1/kcanotify-gamedata) 的 `quests-jp.json`，英文编号和前置任务关系来自 [kcWiki kcQuests](https://github.com/kcwikizh/kcQuests)。应用在本地由前置关系反向生成后置关系，并参考 [poi-plugin-quest-info-2](https://github.com/lawvs/poi-plugin-quest-2) 的任务链算法推断已解锁和未解锁状态。数据可能存在更新延迟，实际状态以游戏为准。

本目录下的 `equipment_fit_bonuses.json` 数据集由本项目从第三方网站**派生整理**（derived data），不是本项目独立创作的数据，也不属于第三方站点或其运营者的官方数据。

## 数据来源

| 来源 | 用途 | 性质 |
| --- | --- | --- |
| [akashi-list.me](https://akashi-list.me/)（あかしリスト） | 主提取源：装备详情页的「装備ボーナス」 | 非官方第三方整理站 |
| [wikiwiki.jp/kancolle](https://wikiwiki.jp/kancolle/)（艦これ攻略Wiki） | 复核源：语义核对复杂规则、发现缺项 | 非官方社区攻略 Wiki |
| [ElectronicObserverEN/Data](https://github.com/ElectronicObserverEN/Data)（FitBonuses.json） | 复核源：程序化交叉比较 | 开源社区数据仓库 |
| 艦これ KCSAPI `api_start2` master 数据 | 校验装备/舰娘 ID | 游戏客户端 master 数据（仅用于 ID 校验，不随 App 分发） |

## 声明

- Akashi List 是非官方第三方整理站，WikiWiki 是社区攻略 Wiki。两者都可能存在错误、延迟更新或与游戏实际不一致之处。
- 本项目使用 WikiWiki 和独立规则库（ElectronicObserver）对数据进行复核；来源之间的差异经人工审查后以 override 记录，不自动选择某一方覆盖另一方。
- 本项目**不主张**第三方原始数据归本项目所有；正式数据集仅包含：装备/舰娘 ID、规范化条件、数值加成、来源 URL、抓取时间、内容哈希和必要短标签。
- 本数据集**不包含**任何第三方站点的图片、页面正文、HTML 快照、CSS、JavaScript、图标或广告。
- 若 Akashi List、WikiWiki 或 ElectronicObserver 明确要求停止自动抓取，本项目将立即停止抓取并保留上一版可用数据。
- 原始抓取 HTML 仅存在于开发机缓存目录（`tool/akashi_bonus/cache/`，已加入 `.gitignore`），不会随 App 打包或分发。

## 生成与复核

数据集由 `tool/akashi_bonus/` 下的 Dart 工具生成，执行四轮数据检查与一轮代码审查后方可发布。详见 `docs/superpowers/plans/2026-08-04-wiki-equipment-bonus-dataset.md`。

## 改修规划资料

`improvement/planner_snapshot.json` 由 [PlannerRemoteRawData](https://github.com/auluu/PlannerRemoteRawData) 的关系数据规范化生成，用于离线展示每日改修条件、消耗和进化路线。生成时锁定不可变 Git 提交，并保留资料版本和提交号；装备名称与图标由游戏运行时 master 数据补齐。

截至首次接入检查，该仓库未声明 LICENSE。公开分发前需要由项目维护者确认转载及再分发授权；本项目不主张原始资料的所有权，资料也可能存在错误或更新延迟，实际内容以游戏为准。

## 道具图标

以下舰队 Collection 道具图标由[舰娘百科](https://zh.kcwiki.cn/wiki/道具)收录的游戏缓存图片缩放为 75×75 PNG，用于本地离线展示；本项目不主张这些图像的所有权。

| 本地文件 | 道具 | 来源文件 |
| --- | --- | --- |
| `assets/images/material/useitem_54.png` | 给粮舰「间宫」 | [ItemCard054.png](https://zh.kcwiki.cn/wiki/File:ItemCard054.png) |
| `assets/images/material/useitem_59.png` | 给粮舰「伊良湖」 | [ItemCard059.png](https://zh.kcwiki.cn/wiki/File:ItemCard059.png) |
| `assets/images/material/useitem_61.png` | 甲种勋章 | [ItemCard061.png](https://zh.kcwiki.cn/wiki/File:ItemCard061.png) |
| `assets/images/material/useitem_68.png` | 秋刀鱼 | [ItemCard068.png](https://zh.kcwiki.cn/wiki/File:ItemCard068.png) |
