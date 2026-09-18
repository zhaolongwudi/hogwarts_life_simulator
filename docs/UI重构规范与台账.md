# UI 重构规范与台账 · Hogwarts Life Simulator

> 给后续 AI 助手 / 开发者的界面重构"工作纲领 + 进度簿"。
> 背景：项目已完成 P0~P14 共 14 轮**玩法侧**迭代（离线"世界在动"、校园社团等），
> 但 UI 侧长期跟随功能堆叠演进，暴露出三类"不清晰"：功能入口分散、双色板并存、
> 硬编码色值漂移、部分页信息层级堆叠。本轮以 **全量 40+ 界面**为目标重构轮次。
>
> 版本基线：v4.8.x ｜ 视觉基调：**保持液态玻璃（Miui 玻璃拟态 + 魔法辉光）精修**，
> **不推倒重做**。门禁：`flutter analyze` 0 error；`flutter test` 全绿。

## 一、重构三大目标（用户确认）

1. **功能入口清晰化**：把散落的系统（社团 / 节庆 / 奇遇 / 羁绊 / 宠物 / 来信 / 学院杯 / 职业 /
   阿尼马格斯 / 守护神 / 指令中心…）按系统归纳成清晰、可发现的入口，玩家一眼知道有什么可玩、在哪进。
2. **统一视觉与组件**：收敛 100+ 处硬编码色值到设计 token；建立统一可复用组件（玻璃卡片 / 分区标题 /
   空态 / 加载态 / 入口 tile），消除页面间风格漂移。
3. **信息层级打磨**：逐页重排信息主次、分组、空态与加载态，让每个界面重点突出、不堆叠。

## 二、基座现状与核心问题

| 维度 | 现状 | 问题 |
|---|---|---|
| 色板 | `lib/theme/miuix_tokens.dart`（Miui 体系）+ `lib/utils/ui_helpers.dart`（AppColors 早期色板）并存 | **双色板并存**是"不清晰"的根源之一；同语义两处定义 |
| 硬编码色 | UI 层散落 `100+` 处 `Color(0xFF...)` | 同一语义多种写法，深浅混用，无法统一收敛 |
| 入口 | 「手机」tab = 8 宫格 App + 4 快捷坞；指令中心 = 数据驱动分组面板（已较清晰） | 入口**偏平堆叠**，未按系统分组；P9~P14 新系统入口缺失或埋得深 |
| 组件 | 已有玻璃容器 / 导航 / 弹层等 | 缺**统一"页面级"骨架**（空态/加载态/分区标题/入口 tile），各页自写 |
| 好感色 | `UiHelpers.getAffectionColor` 已有 8 档，但地图页/通讯录曾分写两套 | 少量页面仍可能有历史自写映射，需归并 |

## 三、目标架构（落地规划）

### A. 统一设计基座
- 以 `MiuiColors` 为**唯一语义色源**；`AppColors` 收敛为兼容别名指向 Miui 值，逐步淘汰 import。
- 新增集中式 **`lib/theme/ui_tokens.dart` 语义映射**：把 `AppColors.*` 编译期指向 `MiuiColors.*`，
  存量 import 不改也能跑；新代码一律引 Miui。硬编码色收敛清单见下方台账。
- 建立基线约定：**任何新 UI 不得新增裸色值**（沿用 PROJECT_GUIDE §3.5）。

### B. 统一组件库（`lib/widgets/` 下新增）
组件名（建议）与职责：
- `glass_card.dart` → `GlassCard`：毛玻璃 + 描边 + 圆角卡片（替代各页重复的 BackdropFilter 写法）。
- `section_header.dart` → `SectionHeader`：分区标题（名称 + 可选副标题/右操作），统一层级。
- `empty_placeholder.dart` → `EmptyPlaceholder`：统一空态（图标 + 主文案 + 副文案 + 可选动作）。
- `loading_indicator.dart` → `PageLoading`：统一加载态（含骨架或转圈 + 文案）。
- `feature_tile.dart` → `FeatureTile`：**功能入口 tile**（图标 + 名称 + 一句话说明 + 徽标），供系统入口网格复用。

### C. 功能入口组织（手机 tab 重构）
按"系统域"分组，而非再叠一面宫格。建议分组：
- **魔法校园**：课程/考试 / 学院杯 / 社团（P14）/ 魁地奇 / 阿尼马格斯 / 守护神 / 职业 / 打工
- **社交关系**：通讯录(NPC) / 羁绊小剧场(P11) / 姻缘红娘 / 好感排行
- **日常与来信**：日记 / 猫头鹰来信(P13) / 论坛 / 平行世界
- **冒险与奇遇**：奇遇(P10) / 节庆(P9) / 宠物(P12) / 地图 / 回忆
- **经济与道具**：商店 / 背包 / 古灵阁
- 顶栏或页首放：主角状态摘要（属性 / 学院 / 金钱 / 当前角色标签），一眼可见。

> 具体系统归属以代码实际为准，落盘前先对照 `docs/工作思路与后续规划.md` 的系统清单与
> `command_registry.dart` 的分组，避免与现有指令中心分组冲突。P9~P14 是否有独立 UI 页，
> 若无则入口作为"打开对应指令中心/触发面板"的引导。

### D. 信息层级打磨
- 每个页面遵循骨架：**状态摘要（最上）→ 主要操作（次之）→ 次级列表 → 空态兜底**。
- 所有页面补统一的空态 / 加载态（复用 B 组件）。
- 逐页登记进入下面台账。

## 四、逐页重构台账（对照本表打勾）

图例：✅ 完成 ｜ 🚧 进行中 ｜ ⬜ 未开始

| 页面 / 文件 | 现状问题 | 状态 |
|---|---|---|
| `game/home 四 tab` | 入口平铺，未按系统分组 | ⬜ |
| `game/phone_tab` | ✅ 8 宫格+快捷坞 → 系统域分组（魔法校园·玩法/社交·日常/冒险·工具），接入 P9-P14 玩法入口 |
| `game/narrative_tab` | 叙事区 / 选项 / 副 tab | ⬜ 达标优先 |
| `game/world_tab` | ✅ 已较成熟：玻璃头+已登场/未登场分区+操作行，无需大改（仅后续顺手色板统一） |
| `game/settings_tab` | ✅ 已复用单一 SettingsBody 并拆分 10+ 子组件，无需大改 |
| `command_center_panel` | 已较清晰，仅统一组件替换 | ⬜ |
| `game/top_bar / bottom_input` | 状态摘要与快捷 | ⬜ |
| `other/communication/forum/diary` 等 | ✅ diary/communication/forum/matchmaker/affection/inventory 空态→EmptyPlaceholder；memory 的 `_emptyHint` 为内嵌区块空态且已用 theme token，保留 |
| `shop/* , settings/* , world_map/*` | 字体/色板统一 | ⬜ |
| 其余 20+ 低频页 | 统一组件 + 色值收敛 | ⬜ |

> 主页（world/settings/phone）评估：架构已较成熟、色调统一，本轮不再深度重排；
> 打磨重心应放在**长尾子页的空态/加载态补齐**与色板随页收敛。

> 新增统一组件：`lib/widgets/feature_tile.dart`（FeatureTile/SectionHeader）、
> `lib/widgets/loading_placeholder.dart`（PageLoading/EmptyPlaceholder）。
> `AppColors↔Miui 色板收敛`（上节 A）本轮未做——改动面广、回归风险高，留到信息层级批次同步推进。

## 四·附·B：加载态归一（PageLoading）
✅ 已收编 5 处整块居中 `Center(CircularProgressIndicator())` → `PageLoading`：
`matchmaker`（正在为你牵线…）、`save_load`（正在读取存档…）、
`settings_crash_section`（正在加载崩溃报告…）、`game_narrative_tab`（加载角色档案…）、
`game_screen`（正在加载存档...）。
边界：按钮/行内小转圈（`SizedBox(~20)`）为动作态、布局不同，**不归并**保留。

## 四·附：色板收编映射表（AppColors → MiuiColors 单一来源）

> 规则：新代码只用 `MiuiColors`；存量 `AppColors`/裸色随逐页打磨替换为右侧权威 token。
> 凡值不同（标注近似→）替换时以右侧值为准，保证全局一致。
>
> **收编边界（重要）**：映射表只适用于**与全局语义同类**的裸色（危险红 / 成功绿 / 金系 /
> 文字灰阶 / 画布背景）。**页面级专属主题色不收编**——如 `game_play_screens.dart` 的蓝紫
> 深浅体系（`#1A1A2E` 底 / `#5A5A7A`~`#B0B0C8` 文字 / `#2A2A4A` 填充）是各面板自洽的主题
> 配色，机械收编会把页面从蓝紫改成灰金、等于推倒重做，违背「精修不推倒」原则，故保留。

| AppColors 成员 | 值 | → MiuiColors 权威 token | 说明 |
|---|---|---|---|
| `gold` | `#D3A625` | `primary` | 同值 |
| `goldBright` | `#DDB54A` | `primaryVariant` `#E0B84A` | 近似→统一 |
| `goldDeep` | `#B8860B` | `primaryContainer` | 同值 |
| `danger` | `#EF4444` | `error` `#F12522` | 近似→统一到危险红 |
| `success` | `#10B981` | `success` | 同值 |
| `warning` | `#F59E0B` | `warning` | 同值 |
| `info` | `#79C0FF` | `info` | 同值 |
| `textPrimary` | `#E6EDF3` | `onSurface` `#F2F2F2` | 近似→统一 |
| `textSecondary` | `#8B949E` | `onSurfaceSecondary` `#CCFFFFFF` | 近似→统一 |
| `textMuted` | `#6B7280` | `onSurfaceVariantSummary` `#8FFFFFFF` | 近似→统一 |
| `bg` | `#0D1117` | `background` `#0A0A0C` | 近似→统一画布 |
| `surface` | `#161B22` | `surface` | 语义同 |
| `card` | `#21262D` | `surfaceContainer` | 语义近似 |
| `border` | `#30363D` | `outline` `#43434F` | 近似→统一描边 |
| `getHouseColor` | 裸色 | `MiuiColors.gryffindor/slytherin/ravenclaw/hufflepuff/houseNeutral` | 学院色已收敛至 Miui |

## 四·附·C：长尾子页空态收口（EmptyPlaceholder）

> 承接「四·附·B」，逐批把长尾子页**独立成区的空态**（整页/整块主体）收口到
> `EmptyPlaceholder`。沿用收编边界：**卡片/区块内的一行 hint**（如 parallel_world
> 的 `_emptyCard`、memory 的 `_emptyHint`、token 面板的「暂无数据」、好感明细
> 「暂无变动记录」）为内嵌区块空态且已用 theme token，保留不强行套整页空态。

✅ 首批已收编 3 处独立空态：
- `shop_tab.dart`（出售页全空 → 背包没有可出售物）
- `story_history_screen.dart`（整页空 → 暂无剧情记录）
- `job_screen.dart`（岗位列表空 → 暂无岗位 / 搜索无匹配，按关键词切换图标文案）

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

✅ 首批已收编 2 处**映射表内**裸色（页面级专属主题色不收编，沿用"收编边界"）：
- `gringotts_tab.dart`：金色标题 `0xFFDDB54A` → `MiuiColors.primaryVariant`
- `settings_scene_routing.dart`：provider 芯片边线 `0xFF4B5563` → `MiuiColors.outline`

> 其余审计发现的裸色（token 统计的蓝/紫系列色、DeepSeek/SenseNova 品牌色、
> preset 默认格兰芬多红）均属数据系列色 / 品牌专属 / 语义不对应单一 token，**保留**不入表。

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

## 五、回归与安全红线

- 每一批改动后跑 `flutter analyze`（0 error）与 `flutter test`（全绿）。
- 只做**视觉与组织层**改造，**不改动任何玩法/存档/行为逻辑**，除非用户明确要求。
- 硬编码色收敛时，语义必须一致（危险红 / 成功绿 / 强调金 / 文字三灰阶），不改变已有语义。
- 源码扫描测试（见 PROJECT_GUIDE §4，如 `narrative_format_test` / `progression_fix_test`）
  会断言 UI 源码里的方法名/结构。**重构回调/方法名时同步检查这些测试**，避免误删或改名被断言的方法。

## 六、备注

- 本文件随重构进度持续更新，最终作为 UI 侧"唯一规范 + 台账"，与 `PROJECT_GUIDE.md` /
  `docs/工作思路与后续规划.md` 形成「玩法侧 + 结构侧 + 界面侧」三份纲领闭环。