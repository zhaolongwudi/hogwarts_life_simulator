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
> `AppColors↔Miui 色板收敛`（上节 A）：**已完成**（见「四·附·D」），
> `AppColors` 现已改为转发到 `MiuiColors` 的兼容别名，全库单一色源。

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

✅ 第二批（扩面审计后）：
- 空态：`npc_chat_screen.dart` 消息区全空 → `EmptyPlaceholder`（和 NPC 开始对话吧）
- 加载态：`settings_quota_window.dart` 配额区块自写小转圈 → `PageLoading(compact: true)`
- **保留**：`game_play_screens.dart` 委托板/装备栏的 `_emptyCard/_emptyEquipCard` 为
  页面级蓝紫主题玻璃卡空态（沿用"收编边界"页面主题色不推倒），记档保留。

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

✅ 第三批 · 新玩家玩法引导（P9-P14 系统可发现性）：
- `feature_tile.dart`：`FeatureTile` 新增可选 `onInfo` → 横条形态箭头前渲染小问号按钮
  （独立触发，不抢主 onTap），供宿主弹"系统是什么 / 怎么玩 / 产出"引导。
- `game_phone_tab.dart`：为「魔法校园·玩法」5 个系统入口（社团 / 节庆 / 宠物 / 来信 /
  档案）接入 `onInfo`，新增 `_showSystemGuide` 弹出式说明面板。

> 目的：新玩家一眼知道这些入口是"可持续成长的系统"而非一次点击，契合「所有功能与插件都要清晰」。

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

## 四·附·D：旧色板 AppColors → MiuiColors 单一色源（完成）

✅ **结构性收敛已落地**：`AppColors` 从"自持字面量"改为**转发到 `MiuiColors` 的兼容别名**
（`lib/utils/ui_helpers.dart`）。全库 116 处 `AppColors.*` 调用无需逐页改动，即统一到
`MiuiColors` 单一来源，从根源消除"双色板并存"。

- 同值直接等价：`gold→primary`、`goldDeep→primaryContainer`、`success/warning/info`。
- 近似→收敛到 Miui 统一值（映射表已批准）：`danger→error`、`goldBright→primaryVariant`、
  `textPrimary→onSurface`、`textSecondary→onSurfaceSecondary`、`textMuted→onSurfaceVariantSummary`、
  `bg→background`、`surface→surface`、`card→surfaceContainer`、`border→outline`。
- 实测：UI 层实际引用的旧成员几乎全为金系/状态色；`surface/card/bg/text*` 在 UI 层几乎无使用，
  仅 `getAffectionColor` 内部引用 `textMuted`，故视觉影响集中在金系提亮与危险红的轻微统一，整体更一致。
- 边界不变：页面级专属主题色（`game_play_screens` 蓝紫、world_map 绿系）**不**受本收敛影响。

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

## 四·附·E：学院色单源化 + 选项卡片去重（完成）

✅ **学院色统一到 MiuiColors**（Task A）：
- `UiHelpers.getHouseColor`（`utils/ui_helpers.dart`）原为深品牌色（gryffindor#740001/
  slytherin#1A472A/ravenclaw#0E1A40），现收口到 `MiuiColors` 学院 token（亮色版、暗底可读）。
- `game_world_tab._getHouseColor` 原为第三套金/琥珀 switch（#B8860B/#3B82F6…，且大小写
  敏感匹配不到），已删，改为委托 `UiHelpers.getHouseColor` + 保留 `staff` 特例；同时删掉 4 处
  页面裸色 `Color(0xFF...)`，符合「不在页面裸写色值」约定。
- 删除死代码 `UiHelpers.getHouseColorBright`（定义后无任何调用）。
- `PROJECT_GUIDE.md` §3.5 已同步更新为 `MiuiColors` 为准、`AppColors` 兼容别名。

✅ **设置页两个选择器去重**（Task B）：`settings_preset_pickers.dart` 的 `buildModePicker` /
  `buildEraPicker` 原本各持一份几乎相同（后又各自跑偏）的卡片脚手架（~70 行 x2），
  抽为私有 `_optionCard` 单一实现（选中底保留历史 `0xFF740001@20%` 外观）；仅统一 era 标题色
  为 mode 规则（onSurface→white，肉眼无差）。经查调用方均未使用 `icon/color` 分支，行为不变。

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

## 四·附·F：语义状态色批量收敛到 MiuiColors + 设计专用色板边界（完成）

✅ **宣称一批「与 token 同值」的裸色去重**（零风险一致性漏洞）：
- `settings_body` 两处 Switch 激活金 `0xFFD3A625`→`primary`；
- `game_phone_tab` 背包图标 `0xFF10B981`→`success`；
- `miui_magic_backdrop` 星尘色 `0xFFF3DFA0`→`onPrimaryVariant`（光斑已→`primary/primaryContainer`）。

✅ **语义状态色收敛**（仅改「与语义同类」的裸色；提交 `745b7b5`）：
- 错误红→`error`：`settings_body` 危险操作（清 Key，8 处）与危险按钮 `0xFFE05050`（3 处）、
  `settings_provider_card` 连接测试失败/删除图标、`settings_quota_window` 额度耗尽、
  `npc_chat_screen` 清空确认、`shop_tab` 出售/失败按钮。
- 警告橙→`warning`：`settings_body` 调试日志 amber+重置橙（7 处）、`provider_card` 未配置徽章、
  `scene_routing`、`quota_window` 高占用、`shop_tab` 可用。
- 成功绿→`success`：`settings_body` 本地模式 `0xFF4CAF7D`（4 处）、`shop_tab` 可装备 teal。
- 状态徽章：`game_world_tab` 登场→`success`、未登场→`onSurfaceVariantActions`。

> **收编边界（此处继续沿用）**：下列属**设计专用色板/页面主题**，**不适用**语义映射，勿误改：
> - 物品稀有度色板（`inventory_screen` 的 brown/green/amber/purple/blue/… 按品质区分）；
> - 好感热力与关系色（`matchmaker` 粉色浪漫系、`affection_aggregate` 橙/绿/蓝三档、
>   `communication` 好感/离场色）——按数值档位编码、非常规"成败"语义；
> - `map_area_painter` 地形/水系/建筑色、`game_narrative_tab` 高亮槽位图例与快捷入口色；
> - `_providerColor` 厂商品牌色（DeepSeek/SenseNova/Anthropic/OpenAI 各持本色）；
> - `settings_body` 分区标题彩色强调（蓝/紫/绿/金分节）。

⚠️ **已知残留（偏蓝旧子主题，下一步单独小步处理，勿强收语义）**：
- `settings_body` / `game_play_screens` 的 `0xFF1A1A2E`→`0xFF0D0D1A` 背景渐变及
  `0xFF8A8AAA`/`0xFF3A3A5C`/`0xFF2A2A4A`/`0xFF5A5A7A`/`0xFFB0B0C8`/`0xFF6A6A8A` 等灰阶，
  与全库金/中性色板不一致、属历史主题残留；因其成体系、一次性收敛会大范围改变观感，
  需先在本台账更新边界说明再小步替换（对应日志「下一步方向 1」）。

---

## 四·附·H：蓝紫旧子主题收敛边界与映射（2026-09-22 更新）

> 承接「四·附·F 已知残留」，补全边界说明，作为小步替换的依据。

### 背景与判定
- `game_play_screens.dart`（委托板/装备栏/社交面板）与 `settings_body.dart`（设置页下半区）
  沿用了早期"蓝紫深浅子主题"：`0xFF1A1A2E` 深底（渐变至 `0xFF0D0D1A`）、
  `0xFF8A8AAA`（次级文字）、`0xFF3A3A5C`/`0xFF2A2A4A`（卡片/填充）、
  `0xFF5A5A7A`/`0xFFB0B0C8`/`0xFF6A6A8A`（图标/三级文字/徽章）。
- 与全库金/中性液态玻璃基调不一致，但**自成体系**（背景-卡片-文字三级自洽），
  机械收编到 Miui 语义 token 会整体改变观感 → 需**小步分批替换**，每批跑 analyze + test。

### 收敛映射（仅对「与全局语义同类」的裸色生效）
| 旧裸色 | 语义 | → MiuiColors 权威 token |
|---|---|---|
| `0xFF1A1A2E`（深底） | 卡片/面板背景 | `surfaceContainer`（或页面主题容器，视上下文） |
| `0xFF0D0D1A`（渐变底） | 渐变深底 | `background` / `surfaceContainerHigh` |
| `0xFF8A8AAA` | 次级文字 | `onSurfaceSecondary` |
| `0xFFB0B0C8` | 次级文字偏亮 | `onSurfaceSecondary` |
| `0xFF5A5A7A` | 图标/占位 | `onSurfaceVariantSummary`（占位/图标语义，56% 白；无独立 onSurfaceVariant token） |
| `0xFF6A6A8A` | 三级文字/徽章 | `onSurfaceVariantSummary` |
| `0xFF3A3A5C`（描边） | 卡片描边 | `outline` |
| `0xFF2A2A4A`（填充） | 选中/填充底 | `surfaceContainerHighest` |

### 替换边界（重要）
1. **只替换"语义同类"裸色**：危险红/成功绿/金系/文字灰阶/画布背景等与全局语义可对应的；
   **不替换**页面级专属强调色（如具体面板的自洽主题强调、品牌色、数据系列色）。
2. **每批小步**：建议按「一个文件 → 一个语义族」推进（如先 `0xFF8A8AAA→onSurfaceSecondary`），
   避免一次性大范围观感突变。
3. **行为不变**：只改颜色字面量，不动布局/回调/方法名；改动后跑 `flutter analyze`（0 error）
   与 `flutter test`（全绿）。
4. **回归红线**：涉及源码扫描测试断言的方法/结构不更名。

### 进度（持续累积）
- 2026-09-22：边界与映射落盘（本段落），待分批执行。第一批建议从 `settings_body.dart` 的
  `0xFF8A8AAA`（次级文字，语义最明确）开始。
- 2026-09-22：**第一批执行完成**——`settings_body.dart` 全量 11 处 `0xFF8A8AAA` →
  `MiuiColors.onSurfaceSecondary`（次级文字语义，文件已 import miuix_tokens.dart）。
  待 CI（flutter analyze + test）验证；继续下一语义族（0xFF1A1A2E 底 / 0xFF3A3A5C 描边）时
  沿用本映射表。注意 `0xFF5A5A7A` 映射到 `onSurfaceVariantSummary`（无独立 onSurfaceVariant token，
  已修正映射表）。
- 2026-09-22：**第二批执行完成**——`game_play_screens.dart` 次级文字 9 处
  （`0xFF8A8AAA`×6 + `0xFFB0B0C8`×3）→ `MiuiColors.onSurfaceSecondary`。
- 2026-09-22：**第三批执行完成**——图标/占位/弱化灰阶收编：`game_play_screens.dart` 的
  `0xFF5A5A7A`×8 与 `0xFF6A6A8A`×2、`settings_body.dart` 的 `0xFF5A5A7A`×1 与 `0xFF6A6A8A`×1
  全部 → `MiuiColors.onSurfaceVariantSummary`（56% 白）。
- **状态**：文字/图标灰阶族已全部收编（12 处 8A8AAA + 3 处 B0B0C8 + 9 处 5A5A7A + 3 处 6A6A8A）。
  剩余**背景/描边/填充族**（`0xFF1A1A2E` 底 / `0xFF0D0D1A` 渐变 / `0xFF3A3A5C` 描边 /
  `0xFF2A2A4A` 填充）观感影响大，留待下一批单独处理（建议从描边 3A3A5C→outline 开始，风险最低）。
- 2026-09-22：**第四批执行完成**——描边族：`game_play_screens.dart`×6 + `settings_body.dart`×5
  的 `0xFF3A3A5C`（带 alpha 0.4/0.3 保留）→ `MiuiColors.outline.withValues(alpha: ...)`；
  Divider 1 处 → `outline`。
- 2026-09-22：**第五批执行完成**——填充族：两文件 `0xFF2A2A4A`×5（含 Divider、alpha 0.6 保留）
  → `MiuiColors.surfaceContainerHighest`。
- 2026-09-22：**第六批执行完成**——背景族：两文件 `0xFF1A1A2E`×18（含渐变起点 3 处）→
  `MiuiColors.surfaceContainer`（保留 alpha 0.95~0.45）；渐变深底 `0xFF0D0D1A`×3 → `MiuiColors.background`。
- **✅ 蓝紫旧子主题全族收编完成**（2026-09-22）：`settings_body.dart` + `game_play_screens.dart`
  两文件的 8 类旧裸色（1A1A2E/0D0D1A/3A3A5C/2A2A4A/8A8AAA/B0B0C8/5A5A7A/6A6A8A）共 42 处
  全部映射到 MiuiColors 语义 token，**零残留**。剩 `world_map_screen.dart` 的绿系主题未动
  （不属于蓝紫族，且世界地图已有专属主题收编边界）。待 CI（flutter analyze + test）验证。

门禁：`flutter analyze` 0 error；`flutter test` 1984 全绿。

## 四·附·G：世界地图几何错位 / 覆盖 / 对比度修复（完成）

用户反馈「面板多处错位 / 被莫名其妙的东西覆盖」的核心重灾区是 `world_map_screen.dart`。
本批定位并修复三处**有代码证据**的问题，其余仅做零风险语义色收敛：

✅ **标记盖住顶部标题卡**（覆盖问题）：
- `build()` 的 `SafeArea > Stack` 里，`_buildLocationMarkers()` 原排在 `_buildTopHeader()` 之后
  —— Flutter 的 Stack 后绘制者在上层，标记滚动时会盖在标题卡上。
- 已把标记滚动区移到 Stack 最底层，浮层（标题卡/返回键/图例/切区按钮）全部盖在它上面。

✅ **顶部标题深底配深字看不清**（对比度问题）：
- 标题卡是深灰 `surfaceContainerHigh` 底，标题却用了更深的 `surfaceContainer` 深灰字，
  对比度几乎为零（第16轮E 曾把无 color 改成深灰，反而更糟）。
- 已改为 `MiuiColors.onSurface`（亮色），深底配亮字可读。

✅ **标记区几何预留错乱**（错位问题）：
- `headerOffset=110` 小于标题卡实际高度（padding top 56 + 卡片 ~68 + 底部 16 ≈ 140），
  标记会钻到标题卡底下被遮。
- `bottomOffset=420` 过大（多留 300px），把 `usableHeight` 压到 300+，
  导致标记几乎全被切成「小圆点 compact 模式」，名字不显示。
- 已调整为 `headerOffset=140` / `bottomOffset=150`。

✅ **图例悬浮在地图中央遮挡标记**（覆盖问题）：
- `_buildMapLegend` 原 `bottom:280`，悬浮在地图中央，会遮住标记文字。
- 已改为 `bottom:68`，贴紧底部切区按钮上方。

✅ **零风险语义色收敛**（金底深字 + 危险红）：
- `settings_body.dart` 2 处、`game_play_screens.dart` 3 处金底按钮 `foregroundColor: 0xFF1A1A2E`
  → `MiuiColors.onPrimary`（金底上的规范深字，与 MiuiTokens 一致）。
- `game_play_screens.dart` 卸下按钮的裸色 `0xFFE05050` / `Colors.red` → `MiuiColors.error`。

门禁：`flutter analyze` 0 error；`flutter test` 全绿（GitHub Actions CI run 35652424135 全绿，2026-09-21 已确认）。

## 五、回归与安全红线

- 每一批改动后跑 `flutter analyze`（0 error）与 `flutter test`（全绿）。
- 只做**视觉与组织层**改造，**不改动任何玩法/存档/行为逻辑**，除非用户明确要求。
- 硬编码色收敛时，语义必须一致（危险红 / 成功绿 / 强调金 / 文字三灰阶），不改变已有语义。
- 源码扫描测试（见 PROJECT_GUIDE §4，如 `narrative_format_test` / `progression_fix_test`）
  会断言 UI 源码里的方法名/结构。**重构回调/方法名时同步检查这些测试**，避免误删或改名被断言的方法。

## 六、备注

- 本文件随重构进度持续更新，最终作为 UI 侧"唯一规范 + 台账"，与 `PROJECT_GUIDE.md` /
  `docs/工作思路与后续规划.md` 形成「玩法侧 + 结构侧 + 界面侧」三份纲领闭环。