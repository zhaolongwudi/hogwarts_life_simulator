# 同好 NPC 关系注入 · 设计预研（2026-09-22）

> 状态：设计预研（未实现）｜ 来源：规划文档第一梯队并列项
> 「同好 NPC 关系注入」：社团成员的「眼缘」影响 P11 好感，让「因为是同好」成为关系推进的一个理由。

## 一、需求来源

`docs/工作思路与后续规划.md` 第一梯队并列项：
> **同好 NPC 关系注入**：社团成员的「眼缘」影响 P11 好感，让「因为是同好」成为关系推进的一个理由。

## 二、现状勘察（2026-09-22 核实）

### 2.1 社团 attendees（club_data.dart）
- 每社 `ClubDef.attendees: List<String>` 列出同好 NPC：
  - 决斗社：西莫 / 弗雷德 / 乔治
  - 魔药部：赫敏 / 纳威 / 西弗勒斯
  - 魁地奇队：奥利弗 / 金妮 / 罗恩
  - 快讯社：卢娜 / 丽塔 / 科林
- 代码中 `mixin_club.dart:275` 已有 `for (final name in club.attendees)` 遍历（用于同好列表展示），可扩展为好感注入点。

### 2.2 好感模型（lib/models/npc.dart）
- `affection`：-100 ~ +100（对玩家的好感度）。
- `affectionLocks`：已解锁的好感锁（`NpcDef.affectionLocks` 预置）。
- `maxAffectionReached`：历史最高好感（背叛后不可超越）。
- 增量上限：`affectionGainedThisWeek`（第一周上限 +30）、`affectionGainedThisMonth`（第一个月上限 +50）、`affectionMonthKey` 跨月重置。
- 维系衰减：`affectionDriftIdleDays` 连续 idle 天数后衰减。

### 2.3 P11 羁绊小剧场（companion_arc_data.dart / mixin_companion_arc.dart）
- `maybeTriggerCompanion`：好感跨门槛后触发羁绊小剧场（前幕自动演、最终幕待抉择）。
- 判定：`arc.startAffection`（mixin_companion_arc.dart:63）——好感达到门槛才触发。

### 2.4 现有注入点：无
- 当前加入社团只影响社团积分/rank，**不影响成员 NPC 好感**——「因为是同好」没有体现在关系层，这是本设计的核心空白。

## 三、方案设计

### 3.1 核心思路：入社/活跃 → 同好好感注入
> **玩家加入某社团后，与该社 attendees NPC 的关系获得「同好加成」——好感更快、更稳地推进。**

「同好」成为关系推进的一个显式理由：玩家和西莫/弗雷德/乔治聊决斗、和赫敏/纳威聊魔药、和奥利弗/金妮/罗恩聊魁地奇，都会因为"共同身份"而更容易亲近。

### 3.2 注入点设计（两处，行为克制）

**注入点 A：入社欢迎（一次性）**
- 加入社团时，对 `club.attendees` 每位 NPC 好感 +5（clamp -100~100，走现有好感修改链路）。
- 叙事：入社文本追加「你和西莫、弗雷德、乔治在更衣室击掌，他们开始把你当自己人。」（复用现有入社文案风格）。
- 位置：`mixin_club.dart` 入社分支（`maybeRunClubActivity` 前置的加入处理段）。

**注入点 B：社团活跃周常（每周上限 2 点）**
- 每周首次社团活动命中后，对 attendees NPC 好感 +1（每周最多 2 点，走 `affectionGainedThisWeek` 现有上限保护）。
- 叙事：活动结算尾部追加同好互动小句（「训练完，奥利弗顺手把你的扫帚递过来——同好之间不用谢。」）。
- 位置：`mixin_club.dart:102` `maybeRunClubActivity` 记分后。

### 3.3 与 P11 羁绊联动
- 同好注入让 attendees NPC 的好感更快达到 `arc.startAffection` 门槛 → 更早触发 P11 羁绊小剧场。
- 例：入社即 +5，周常 +2/周 → 默认 acquaintance(0) 起步的 NPC 约 5 周可达小剧场门槛（视具体 startAffection）。
- 羁绊触发后同好注入继续生效（不互斥），但受周/月上限约束，不会无限叠加。

### 3.4 数值约束（不破坏现有平衡）
- 注入走 `updateNpcAffection` 统一入口（game_provider.dart:292），**自动纳入周/月增量上限**（affectionGainedThisWeek/Month），不会突破平衡设计；守卫约束见 mixin_narrative.dart:2682（好感不得裸写 `npc.affection = ...`，会被 progression_fix_test 源码形状守卫抓出）。
- 单次幅度小（+5 / +1），配合衰减系统，长期看是"稳定缓慢的正向漂移"，不是爆发式刷好感。
- 不新增 NPC 字段、不新增存档字段——纯逻辑层注入，改动最小化。

## 四、数据层改动
- **零新增字段**：复用现有 `relationships` / `affection` / 周月上限机制。
- 存档版本不变（21），无迁移成本。

## 五、实现步骤（批次 A-D）
1. **批次 A（注入点 A）**：入社分支对 attendees 好感 +5 + 叙事追加。
2. **批次 B（注入点 B）**：`maybeRunClubActivity` 记分后对 attendees 好感 +1（周上限 2 点，复用 `affectionGainedThisWeek` 判定）。
3. **批次 C（边界处理）**：未注册 NPC（attendees 名字不在 npcRegistry）静默跳过；好感已锁（affectionLocked）跳过。
4. **批次 D（测试）**：入社 +5 / 周常上限 2 / 锁好感跳过 / 未注册跳过 / 与 P11 触发联动。

## 六、风险与边界
- **行为不变红线**：不动现有好感计算主链路（updateNpcAffection / 衰减 / 上限）；只增加两个注入点。
- **数值克制**：+5/+1 幅度小、受周月上限约束，不会破坏现有 P11 节奏。
- **与 UI 无关**：纯玩法层，不触碰本轮 UI 收敛工作区。

## 七、后续（同批可做）
- 与四社小玩法（决斗/魔药/魁地奇/快讯）同批实施，形成「每社可玩入口 + 同好关系」的完整闭环。
- 第二梯队来信串联 / 来信→社团 / 来信→羁绊（P13 信为 P14 社团牵线、为 P11 送好感）。