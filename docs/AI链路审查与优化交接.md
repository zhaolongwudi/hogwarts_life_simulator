# AI 链路审查与优化交接（2026-09-22）

> **本文档用途**：跨对话交接锚点。上一对话完成了对项目的全面代码级审查，重点覆盖 **AI 输入输出链路、剧情逻辑、游戏性、token 开销**，并清理了冗余文档与一次性脚本。
> **给下一个对话**：按 §6 的批次顺序执行修复，不要重新勘察。§3 的每一条都带精确行号证据，可直接定位。
> **不要删除本文档**，它是本次审查的唯一完整记录。

---

## 一、当前项目状态（审查基线）

| 项 | 值 |
|---|---|
| HEAD | `1491e85` fix(ci): 成就总数 33→35 同步 README 与对账测试 |
| 分支 | `main`，本地/远端完全对齐（`origin/main` = `1491e85`） |
| 工作区 | 干净（本次审查前） |
| CI | run **634** 全绿 —— Analyze ✅ / Run tests with coverage ✅ / Build APK ✅ |
| lib 规模 | 195 文件 / 100,101 行 |
| test 规模 | 116 文件 / 31,285 行 |
| 版本 | pubspec `5.1.5+515`，README badge 与 PROJECT_GUIDE 已一致（`check_docs_version.sh` 通过） |

**CI 历史（关键）**：run 631（`9898a59`）Analyze ❌ → run 632（`9933723`）test ❌ → run 633（`ce03da5`）cancelled → run 634（`1491e85`）✅。即批次 B/C 代码推送后曾两次红灯，现已闭环。

---

## 二、审查结论：为什么「越修越难玩」

### 2.1 核心机制（可量化）

近 20 个 commit 的改动方向高度一致：**每一次修复都在玩家每回合必经的链路上"加东西"**。

| 修复动机 | 加在哪里 | 代价 |
|---|---|---|
| 防 AI 跑偏 | 叙事规则 T0 扩到 77 行 | 每回合多送 ~1280 token |
| 防选项脱节 | 独立选项调用 + 完整上下文 | 每回合多一次串行 AI 调用 |
| 防伪造事件 | 5 处 `looksFake()` 校验 | 校验失败 → 重试 |
| 防 BUG-H | 重试 2 次 + 修正 prompt 前置 | 失败时 3 倍耗时 |
| 防内容丢失 | T0/T1/T2/T3/T4 五层全量注入 | 输入 token 随局龄只增不减 |
| 加新玩法 | 四社小玩法 + 新数值奖励 | 奖励来源膨胀、属性上限更快顶满 |

**净效果**：单回合成本（token × 调用次数 × 延迟）持续上升；同时"限制"类否定式规则已达 **23 处**（`严禁` 10 + `不要` 11 + `不得` 2，见 `lib/prompts/narrative_prompts.dart` `kNarrativeRulesCore`）。

**结论**：不是内容变差了，是**每次交互的摩擦系数在变大**。

### 2.2 优先级判断

- **"反应慢"的主因是设计（无流式 + 两次串行调用），不是网络。**
- **"难玩"的主因是限制规则过多 + 奖励通胀 + 数值上限顶满。**
- **429 是既有问题**，A（RPM 限流）已撤回、E（叙事 maxTokens 放宽）已保留、B（合并调用）未实施。

---

## 三、审查发现清单（带精确证据）

### 3.1 P0 —— 功能实际不可用

#### P0-1 快讯社玩法完全不可用（`happenstanceLog` 无写入点）

| 环节 | 位置 | 事实 |
|---|---|---|
| 数据层 | `lib/models/player.dart:181` | `happenstanceLog` 字段已声明 |
| 序列化 | `player.dart:611`（toJson）、`:829`（fromJson） | 已接入 |
| 模型 | `player.dart:842-878` | `HappenstanceLogEntry` 完整 |
| **写入层** | **全库 grep** | **`HappenstanceLogEntry(` 构造调用仅 1 处：`player.dart:866`（fromJson 内部）** |
| 读取层 | `lib/mixins/mixin_play.dart:1498-1503` | `_headlineCandidates()` 读 `p.happenstanceLog` |
| 消费点 | `mixin_play.dart:1512-1518`、`:1537-1539` | `/快讯 头版`、`/快讯 报道` |

`lib/mixins/mixin_happenstance.dart` 结算段（`:162-170`）只写 `worldState.addNarrativeEvent(...)`，**无 `happenstanceLog.add`**。

**后果**：`/快讯 头版` 永远返回「本学期还没有可报道的奇遇经历」；成就 `headline_reporter`（`lib/models/game_systems.dart:676`）永远无法解锁；存档字段 `happenstance_log` 是死字段。

**设计要求**（`docs/奇遇长期痕迹设计.md:45`）：「奇遇结局结算处（`mixin_happenstance.dart` 选择结算段）追加：完成奇遇后 `player.happenstanceLog.add(...)`」。**未实施。**

**修复位置**：`lib/mixins/mixin_happenstance.dart`，在 `_applyHappenstanceEffect(h, outcome);`（`:146`）之后、`worldState.addNarrativeEvent(...)`（`:162`）旁追加写入 + 上限 50 截断。

---

#### P0-2 决斗赛季跳档奖励永久丢失

设计承诺（`docs/决斗社季度赛设计.md:68`）：「每档可领一次，**跳档只补差额**」。

实现（`lib/mixins/mixin_play.dart:1301-1338`）：
```dart
int? claimIdx;
for (var i = tiers.length - 1; i >= 0; i--) {
  if (p.duelSeasonPoints >= tiers[i].points &&
      p.duelSeasonClaimedTier < tiers[i].points) {
    claimIdx = i;
    break;          // ← 只取一档，且是最高档
  }
}
p.duelSeasonClaimedTier = t.points;   // ← 直接跳到最高档
```

**实机复现结果**：

| 首次领奖时积分 | 实发档位 | `claimedTier` | 丢失 |
|---|---|---|---|
| 50 | 新锐 ✅ | 40 | 无 |
| 100 | 精英 | 90 | **新锐档全部奖励** |
| **150** | **冠军** | **150** | **新锐 + 精英两档全部奖励** |

推演：首次 `claimIdx=2`（冠军）→ 第二次 `claimIdx=None` → 提示「目前没有可领取的新档位」，而积分已达 150。

**正确实现**：`for` 从低到高逐档发放并累加 `claimedTier`。

---

### 3.2 P1 —— 逻辑/数值缺陷

#### P1-1 时间系统与精力系统关键词错位（可钻空子，严重）

**两套关键词表不一致：**

精力恢复（`lib/mixins/mixin_systems.dart:2380-2394`，+50 精力 +30 精神）：
```dart
if (action.contains('睡觉') || action.contains('休息') || action.contains('睡') ||
    action.contains('歇') || action.contains('躺') || action.contains('养') ||
    action.contains('放松') || action.contains('回房') || action.contains('回宿舍') ||
    action.contains('小憩')) { p.energy = min(100, p.energy + 50); ... }
```

时间消耗（`lib/data/time_cost_rules.dart:24-27`，480 分钟）：
```dart
TimeCostRule(patterns: ['睡觉', '休息', '就寝'], minutes: 480, priority: 100),
```

**实测推演**：

| 玩家输入 | 精力 | 耗时 | 问题 |
|---|---|---|---|
| 睡一觉 | +50 | **30 分钟** | ❌ 不含「睡觉」→ 落默认 30 分钟 |
| 回宿舍躺下 | +50 | **30 分钟** | ❌ 30 分钟回满精力 |
| 小憩片刻 | +50 | **30 分钟** | ⚠️ 小憩给 +50 偏多 |
| 放松一下 | +50 | **30 分钟** | ❌ 放松 ≠ 睡觉 |
| 休息一会 | +50 | 480 分钟 | ✅ |

**后果**：说「回宿舍躺下」即可 30 分钟换 50 精力 + 30 精神，一天无限刷，**精力/精神系统被绕过**。

**修复**：时间表补 `歇/躺/养/放松/回房/回宿舍/小憩`，或把恢复表收窄为与时间表一致。

---

#### P1-2 魁地奇训练耗时与设计文档差 4 倍

- 设计（`docs/魁地奇队训练设计.md:51`）：「消耗：10 精力 + **30 分钟**」
- 代码（`lib/mixins/mixin_play.dart:1477`）：`advanceTimeForAction('魁地奇训练')`
- 实际命中（`lib/data/time_cost_rules.dart:61-64`）：`patterns: ['魁地奇','训练'] → **120 分钟**`

**后果**：文档承诺 30 分钟，实际扣 2 小时。

---

#### P1-3 决斗赛季积分不受每日递减约束

`lib/mixins/mixin_play.dart:1176-1179` 有防刷递减：
```dart
final nth = this.dailyCountOf('duel');
final decay = nth <= 1 ? 1.0 : (nth == 2 ? 0.6 : 0.3);
```

但赛季积分（`:1200-1201`）**不走 decay**：
```dart
final seasonWinPoints = 10 + (p.duelSeasonWins >= 1 ? 2 : 0);
p.duelSeasonPoints += seasonWinPoints;
```

**后果**：当天第 5 场决斗，加隆/声望已衰减至 30%，赛季积分仍 +12。最优策略是「一天狂打」，与递减设计意图相反。

---

#### P1-4 银色鳞片无常规获取途径 → 开学季主力配方不可用

清醒剂（`lib/data/club_minigames_data.dart:65`，开学季 `windowIndex:0`）唯一材料 `银色鳞片 ×2`。

来源穷举（全库 grep）：
- `lib/data/item_data.dart:421` —— 仅 ItemDef 定义
- `lib/data/happenstance_data.dart:207-210` —— 单条奇遇 `itemName`，给 **1 片**
- **不在** `kCommonLootMaterials`（`item_data.dart:546`）
- **不在** `kRareLootMaterials`（`:549`）
- **不在** 任何 `bestiary_data.dart` 的 `loot`
- **不在** 任何委托奖励

其余 8 种材料均有 2 个以上稳定来源（禁林池 / 图鉴掉落）。该奇遇无 onceOnly 去重，理论可重复触发，但需在同池（10 条）命中同一条 2 次且过 `weighted + baseChance + kHappenstanceSpacingTurns`。实际等同不可用。

---

#### P1-5 快讯社「每学期 1 次」实际是「每学年 1 次」+ 不稳定 hashCode

实现（`mixin_play.dart:1527`、`:1545`、`:1556`）：
```dart
if (p.headlineSeason == worldState.academicYear.hashCode) { ... }
p.headlineSeason = worldState.academicYear.hashCode;
```

`academicYear` 是字符串 `'1991-1992'`（`lib/models/world_state.dart:41`），**一学年只变一次**；学期标识是 `term`（`first`/`second`/`summer`）。

**双重问题**：
1. 语义降级 —— 一学年（3 个 term）只能报道 1 次，比设计少 2/3 机会。
2. **Dart `String.hashCode` 不保证跨进程/跨版本稳定**，落盘为 int 后 App 重启可能算出不同值 → 防重标记静默失效。

设计要求（`docs/快讯社头版事件设计.md:71`）：「本学期头版报道标记（防重复，**学期切换重置**）」。

---

#### P1-6 `qTrainWeek` 周重置只在训练路径触发

- `_ensureTrainWeekReset()`（`mixin_play.dart:1448-1455`）**唯一调用点**是 `trainQuidditch()`（`:1460`）
- 加成消费点 `playQuidditch()`（`:947` 读 `p.qTrainWeek * 3`）**不调用重置**

**触发场景**：第 N 周训练 2 次（`qTrainWeek=2`）→ 跨到第 N+1 周（`gameWeek` 已由 `mixin_systems.dart:80` 递增）→ 直接 `/魁地奇 比赛` → 仍获 +6 实力，而本周未训练。

违背设计（`docs/魁地奇队训练设计.md:65`）：「训练加成仅限本周比赛；下周清零」。

---

#### P1-7 `potionWindowReward` 死字段

`lib/models/player.dart:171`（声明）+ `:382`（构造）+ `:608`（toJson）+ `:825`（fromJson）**全部齐备**，但 `lib/` 内**零业务读写**。

设计要求（`docs/魔药部限时配方设计.md:72`）：「当前窗口奖励领取标记（记档防重）」。酿造流程（`mixin_play.dart:1384-1445`）**无窗口奖励与防重逻辑**。

---

#### P1-8 `_duelBeatenNpcIds` 未持久化

`lib/mixins/mixin_play.dart:35`：`final Set<String> _duelBeatenNpcIds = {};` —— 纯内存，全库仅 3 处引用（定义/`contains`/`add`），**未进 `_saveExtraData`**。

设计意图（`:1184` 注释）：「打赢对方会让人更服气，但只加一次」。存档→读档后集合清空 → 同一 NPC 再次决斗胜利会重复 `updateNpcAffection(opponent.id, 2)`。有周/月上限兜底，影响有限但违背原意。

---

### 3.3 AI 链路 —— token 与延迟

#### 3.3.1 每回合调用结构（2 次串行、无流式）

```
用户点"继续"
  ├─ ① callDeepSeek(narrative)  maxTokens 2000  超时 50s   ← mixin_systems.dart:2829
  │     等待完整响应（stream: false）                       ← deepseek_service.dart:231, :366
  ├─ 解析 + 校验 + 可能重试（最多 2 次）                     ← mixin_narrative.dart:753
  ├─ ② callDeepSeek(choice)     maxTokens 500   超时 50s   ← mixin_response.dart:2243
  │     等待完整响应
  └─ 每 9~11 回合：③ callDeepSeek(summary) maxTokens 3000
```

**关键事实**：

1. **无流式**。`lib/services/deepseek_service.dart:231` 与 `:366` 均为 `'stream': false`。玩家必须等完整生成 600-800 字才见第一个字。**这是"反应慢"最直接原因**。
2. **两次串行**。选项必须等叙事完成（要承接叙事末尾）。理论最坏 = 50s + 50s = **100 秒**。
3. **重试放大**。`retriesLeft = 2`（`mixin_narrative.dart:753`），最坏 3 次叙事 + 1 次选项 = **4 次串行**。

---

#### 3.3.2 prompt 体积实测

工具：`scripts/audit_prompt_sizes.py`（本次新增，纯静态读取，`python3 scripts/audit_prompt_sizes.py` 可复现）

| 常量 | 位置 | 字符数 | 约 token |
|---|---|---|---|
| `kWorldRulesFused` | `lib/data/world_rules.dart:32`（getter） | ~4162 | ~2497 |
| `kNarrativeRulesCore` | `lib/prompts/narrative_prompts.dart:50` | 2133 | ~1280 |
| `kNarrativeRulesQuality` | 同上 `:115` | 396 | ~238 |
| `kChoicePromptPreamble` | `lib/prompts/choice_prompts.dart:3` | 2103 | ~1262 |
| `kChoiceQualityChecklist` | 同上 `:57` | 145 | ~87 |

**动态上下文（叙事端）**，来源 `mixin_narrative.dart:300-510`：
- T0 核心事实（importance≥5，配额条）
- T1 未完结事项（**最多 40 条**，`:388`）
- T2 NPC 关系锚（同场景 5 + 场外 3）
- T3 世界事件银行（**近 60 天 30 条 + 旧事件 10 条 = 40 条**，`:466-468`）
- T4 历史摘要（250~600 字，`:495-500`）
- 世界事件锚点（**最多 12 条**，`:608`）
- 前情回顾（**800 字**，`:625`）

**动态上下文（选项端）**，来源 `mixin_response.dart:2096-2237`：
- narrativeTail（**800 字**）
- 玩家硬状态 + 已知魔法 12 个 + 背包 12 项
- nearbyNpc 8 个（含人设）
- openLoops 6 条
- **T0 核心事实 14 条**（identity 5 + recent 9）

**粗估单回合输入**：叙事 ≈ 7000~9000 token；选项 ≈ 3000~4000 token；**合计 10000~13000 token/回合**（两次调用）。

---

#### 3.3.3 三处明确重复计费

**① T0/T1 事实注入两次**
- 叙事端 `mixin_narrative.dart:378`
- 选项端 `mixin_response.dart:2132`
同一批事实，两次调用各付一次输入费。

**② 系统提示词与叙事规则语义重叠**

`kWorldRulesFused` 已含：「精练叙事：600-800字」「每段必须推动剧情」「感官细节融入动作」「对话简练」「禁止无意义的环境堆砌」。

`kNarrativeRulesCore` 又写一遍：「叙事:600-800字精练正文」「每段必须推动剧情」「禁止空洞的环境描写」「为凑字数拉长句子」。

**同一要求写了两份，每回合都发**。粗估重复 400~600 字符（约 300 token）。

**③ `kNarrativeRulesCore` 内部自重复**

实测关键词频次：`时间` 11、`严禁` 10、`不要` 11、`地点` 8、`数值` 6、`选项` 3。

`选项` 的 3 次中，第 1 行与第 75 行是同一句话：
- 开头：「选项将由独立步骤生成，本回合只需生成叙事和好感变化」
- 结尾：「不需要生成选项，选项将在下一步单独生成」

---

#### 3.3.4 服务端前缀缓存完全未利用

全库 grep `cache_control` / `prompt_cache` / `prefix_cache` → **零命中**。

`ResponseCache` 对叙事/选项明确禁用（`lib/services/ai_router.dart:350`）：
```dart
useCache: scene != AiScene.narrative && scene != AiScene.choice,
```
该禁用本身正确（内容每次不同），但**说明输入侧无任何复用手段**。

而系统提示词（~2500 token）+ 叙事规则（~1280 token）**每回合逐字重发且几乎不变**——正是服务端 context caching 的典型适用场景。

---

#### 3.3.5 可省 token / 提速清单

| # | 措施 | 预计收益 | 风险 |
|---|---|---|---|
| T1 | **开启流式输出** | 首字延迟 10~20s → 1~2s | **低**（纯传输层） |
| T2 | 删重复规则段（两处重叠 + T0 内部重复句） | 省 ~300 token/回合 | 低 |
| T3 | T3 世界事件 40 → 15 条；世界锚点 12 → 6 条 | 省 ~800~1500 token/回合 | 低 |
| T4 | 选项端不再重发 T0 全量 | 省 ~500 token/回合 | 中 |
| T5 | 接服务端前缀缓存 | 输入计费降 50%+ | 中（需确认 API 支持） |
| T6 | **合并叙事+选项为一次调用** | 省 1 次调用、省 3000~4000 输入 token、延迟砍半 | **高** |

**T1 投入产出比最高**：只改传输层，不动业务逻辑。

---

### 3.4 游戏性 —— "越修越难玩"的具体机制

#### 3.4.1 奖励来源膨胀，属性上限形同虚设

属性统一 `clamp(0, 100)`，初始 `?? 50`（`mixin_play.dart` 内 9 处）。

**新增玩法的属性产出**：

| 来源 | 位置 | 属性收益 |
|---|---|---|
| 决斗赛季·新锐 | `mixin_play.dart:1302` | reaction_time +3 |
| 决斗赛季·精英 | `:1303` | courage +5 |
| 决斗赛季·冠军 | `:1304` | spell_understanding +6 |
| 魁地奇训练 | `:1482` | flying/reaction_time **+1/次，每周 2 次** |
| 魔药酿造失败 | `:1441` | potions **+5/次** |
| 快讯报道 | `:1563/1568/1574` | social/logic +2~+3 |

从 50 到 100 只需 50 点。魁地奇训练每周 +2（flying），一学年 40 周 = **+80**。**单一玩法即可顶满。**

**后果**：属性很快全 100，之后所有成长反馈消失。

#### 3.4.2 单一动作给 6 类奖励

`mixin_play.dart:1180-1204`（决斗胜利）同时给：
```dart
p.playerReputation.add('combat', repGain);   // 战斗声望
p.playerReputation.add('moral', 2);          // 道德声望
addHouseCupPoints(...);                       // 学院杯
p.galleons += reward;                         // 加隆
this.updateNpcAffection(opponent.id, 2);      // NPC 好感
p.duelSeasonPoints += seasonWinPoints;        // 赛季积分
```
一次决斗 6 条奖励线同时推进，每条都弹 `notifications` → 信息过载。

#### 3.4.3 限制性规则总量 23 处

`kNarrativeRulesCore`：`严禁` 10 + `不要` 11 + `不得` 2 = **23 处否定式指令**。

LLM 对否定指令处理本就弱（"不要想大象"效应）。23 条堆在一起互相稀释，AI 记不住哪条更重要，反而更易踩线触发重试。

#### 3.4.4 重试的负反馈循环

`mixin_narrative.dart:753-888`：
```
critical 违规 / 违和词 / BUG-H
  → 重试（retriesLeft 2→1→0）
  → 重试 prompt 前置 5 条修正要求（prompt 更长）
  → 更长的 prompt → 更容易超时/429
  → 仍失败 → generateFallbackNarrative() 本地兜底
```

代码注释已自认此点（`mixin_systems.dart:2820`）：
> 「1600 偏紧会截断触发 BUG-H 重试 → 越截断越重试、越重试越打 AI，放大 429」

**但只解决了 maxTokens，未解决重试本身。**

---

### 3.5 P2 —— 工程同步缺陷

#### P2-1 新玩法零专项测试

116 个测试文件中，对以下符号 `grep -rl` **返回 0 个匹配文件**：
`duelSeason` / `showDuelSeasonPanel` / `claimDuelSeasonReward` / `brewPotion` / `showPotionRecipes` / `trainQuidditch` / `showHeadlineBoard` / `reportHeadline` / `qTrainWeek` / `potionBrew` / `headlineSeason`

违反三条项目自身规则：
- `docs/工作思路与后续规划.md:100`：「每个系统的专项测试独立成文件」
- `docs/BATCH10_HANDOVER.md:88` 规则 6：「存档字段数变更要同步更新 `progression_fix_test.dart`」
- 规划文档：「新增一层内容 = … + 一个测试夹具开关 + 台账补一行」

**这也是 P0-2 跳档 bug 未被 CI 拦截的直接原因。**

#### P2-2 五份设计文档状态行全部过期

| 文档 | 第 3 行声明 | 实际 |
|---|---|---|
| `docs/决斗社季度赛设计.md` | 设计预研（未实现） | ✅ 已实现（`0829353`） |
| `docs/魔药部限时配方设计.md` | 设计预研（未实现） | ✅ 已实现 |
| `docs/魁地奇队训练设计.md` | 设计预研（未实现） | ✅ 已实现 |
| `docs/快讯社头版事件设计.md` | 设计预研（未实现） | ⚠️ 已实现但 P0-1 致不可用 |
| `docs/同好NPC关系注入设计.md` | 设计预研（未实现） | ✅ 已实现 |

`docs/设计审查_2026-09-21.md` 无批次 B/C 任何记录。

#### P2-3 README 未同步新命令

`README.md:145`：
```
| **玩法活动** | `/魁地奇` `/决斗` `/禁林 探险` `/图鉴` `/委托` |
```
缺 `/魔药`、`/快讯`。`README.md:64` 校园社团行也未提四社专属小玩法。

#### P2-4 CHANGELOG 未记录批次 B/C

`CHANGELOG.md` 顶部为 v5.1.5。`0829353`/`9933723`/`1491e85` 均未进 CHANGELOG。根因：CI `sync_changelog` 步骤仅在 release-worthy 时执行——run 634 该步骤状态为 `skipped`。

#### P2-5 交接文档三处 HEAD 声明互相矛盾且全部过期

| 位置 | 声明 | 实际 |
|---|---|---|
| `docs/BATCH10_HANDOVER.md:2` | `HEAD: c8689c2`，run 629 | `1491e85`，run 634 |
| `:125` | 当前 HEAD：`0999bf5` | 同上 |
| `:260` | 当前 HEAD `458c99a` | 同上 |

---

## 四、429 治理现状核实

| 项 | 状态 | 证据 |
|---|---|---|
| `SenseNovaRateLimiter`（`c4626e7` 新增 71 行） | **不存在**（已撤回） | `git show --stat c8689c2` 删除 `rate_limiter.dart` 71 行；当前文件 353 行无该类 |
| `SenseNovaQuotaManager` | 存在，**仅 5h 总量按 model 分桶** | `lib/services/rate_limiter.dart:112-238`；`quotaForModel` 返回 1500（sensenova-）/500（其他） |
| SenseNova 每分钟限流 | **无** | 全文件无 RPM 逻辑 |
| `AgnesRateLimiter` | 存在，18 RPM 按 `keyHash` 分桶 | `rate_limiter.dart:43-95` |
| 单 Key 熔断 | 存在（3 次/60s） | `lib/services/ai_router.dart:56-57`、`:191-207` |
| 方案 B（合并调用） | **未实施** | `generateChoicesSeparately` 仍独立调用 |
| 叙事 maxTokens | 2000（E 已保留） | `mixin_systems.dart:2829` |

与既有结论一致：**A 已撤回、E 保留、B 未实施**。

---

## 五、本次整理记录（已完成）

### 5.1 删除的文档（4 份，~30.7 KB）

| 文件 | 大小 | 删除理由 |
|---|---|---|
| `docs/BATCH8_HANDOVER.md` | 9,002 B | 外部引用 0，内容已被 BATCH10 覆盖 |
| `docs/BATCH6_HANDOVER.md` | 7,346 B | 仅被 BATCH8（已删）引用 |
| `docs/工作日志.md` | 8,617 B | 外部引用 0 |
| `docs/scene2_long_text.md` | 5,771 B | 一次性测试素材 |

悬空引用已修复：`docs/BATCH10_HANDOVER.md:195` 中对 `scene2_long_text.md` 的引用已改为「临时文件 ~2300字，已清理」。

### 5.2 删除的脚本（10 个，~62 KB）

已执行完毕的一次性迁移脚本：

| 文件 | 大小 |
|---|---|
| `scripts/p2_cross_mixin_privatize.py` | 4,503 B |
| `scripts/p2_field_ref_check.py` | 2,098 B |
| `scripts/p2_fix_cross_mixin_v2.py` | 10,639 B |
| `scripts/p2_fix_cross_mixin_v3.py` | 10,274 B |
| `scripts/p2_fix_v4_base_cleanup.py` | 6,933 B |
| `scripts/p2_fix_v5_drop_private_abstract.py` | 3,133 B |
| `scripts/p2_verify.py` | 12,795 B |
| `scripts/verify_imports.py` | 5,423 B |
| `scripts/append_16l.py` | 4,080 B |
| `scripts/append_5abd662d_relay.py` | 5,291 B |

另清理 `scripts/__pycache__/`（3 个 .pyc）。

**保留的脚本（10 个）**：
`audit_prompt_sizes.py`（本次新增）、`bump_version.sh`、`check_docs_version.sh`、`check_parens_code.py`、`clean_unused_imports.py`、`commit_push.sh`、`gh_proxy.py`、`gitdata_push.py`、`sync_changelog.sh`、`sync_docs_version.sh`

### 5.3 docs 目录现状（17 份）

```
AI_SERVICE_API.md          ARCHITECTURE.md            BATCH10_HANDOVER.md
NPC_头像素材清单.md        UI_BATCH_HANDOVER.md       UI重构规范与台账.md
决斗社季度赛设计.md        同好NPC关系注入设计.md     奇遇长期痕迹设计.md
室友系统设计.md            工作思路与后续规划.md      快讯社头版事件设计.md
更多来信类型设计.md        来信串联设计.md            设计审查_2026-09-21.md
魁地奇队训练设计.md        魔药部限时配方设计.md
```

**未动的文档**（用户明确要求保留）：`docs/BATCH10_HANDOVER.md`（含"禁止删除"的极限测试附录）。
**待定**：`docs/NPC_头像素材清单.md`（外部引用 0，属素材参考，是否删除由用户决定）。

---

## 六、建议执行批次（减法优先，一批一改一推）

按「改动小 / 收益大 / 风险低」排序。**S1~S4 是减法或纯传输层，不动业务逻辑。**

| 批次 | 内容 | 类型 | 风险 | 预计收益 | 涉及文件 |
|---|---|---|---|---|---|
| **S1** | 开启流式输出（`stream: true` + 增量渲染） | 传输层 | 低 | 首字延迟 10~20s → 1~2s | `lib/services/deepseek_service.dart:231,366` |
| **S2** | 删重复规则段（`kWorldRulesFused` ∩ `kNarrativeRulesCore`）+ 删 T0 内重复的"不生成选项"句 | 减法 | 低 | 省 ~300 token/回合 | `lib/data/world_rules.dart`、`lib/prompts/narrative_prompts.dart` |
| **S3** | T3 世界事件 40 → 15 条；世界锚点 12 → 6 条 | 减法 | 低 | 省 ~1000 token/回合 | `lib/mixins/mixin_narrative.dart:466-468,608` |
| **S4** | 统一"休息"关键词表（时间表补 `歇/躺/养/放松/回房/回宿舍/小憩`） | 修 bug | 低 | 堵住精力漏洞 | `lib/data/time_cost_rules.dart:24-27` |
| **S5** | 修 `happenstanceLog` 写入点 + 上限 50 截断 | 修 P0 | 低 | 快讯社可用 | `lib/mixins/mixin_happenstance.dart:146-170` |
| **S6** | 修决斗赛季跳档补发（循环逐档发放） | 修 P0 | 低 | 奖励不丢 | `lib/mixins/mixin_play.dart:1292-1340` |
| **S7** | 魁地奇训练耗时 120 → 30 分钟 | 修 bug | 低 | 与文档一致 | `lib/mixins/mixin_play.dart:1477` 或 `time_cost_rules.dart` |
| **S8** | 赛季积分纳入每日递减 | 平衡 | 低 | 防一天狂刷 | `lib/mixins/mixin_play.dart:1200` |
| **S9** | 银色鳞片加入 `kRareLootMaterials` 或 bestiary loot | 修 bug | 低 | 开学季配方可用 | `lib/data/item_data.dart:549` 或 `bestiary_data.dart` |
| **S10** | `headlineSeason` 改用 `term` 口径（弃用 `String.hashCode`） | 修 bug | 中 | 语义正确 + 跨重启稳定 | `lib/mixins/mixin_play.dart:1527,1545,1556` |
| **S11** | `_ensureTrainWeekReset()` 前置到 `playQuidditch()` 开头 | 修 bug | 低 | 跨周不加成 | `lib/mixins/mixin_play.dart:917` |
| **S12** | 选项端不再重发 T0 全量 | 减法 | 中 | 省 ~500 token/回合 | `lib/mixins/mixin_response.dart:2132` |
| **S13** | 新建 `test/batch46_club_minigames_test.dart` 覆盖四社玩法（含跳档回归锁） | 补测试 | 低 | 防回归 | `test/` |
| **S14** | 文档同步：5 份设计文档状态行 + 台账 + README 命令表 + 交接文档 HEAD | 整理 | 无 | 一致性 | `docs/`、`README.md` |
| **S15** | 合并叙事+选项为一次调用 | 架构 | **高** | 延迟砍半、省 40% token | `mixin_narrative.dart`、`mixin_response.dart` |

### 批次执行建议

1. **先做 S1**（流式），立竿见影解决"反应慢"，且零业务风险。
2. **再做 S2/S3/S12**（减法），降低每回合 token 负担。
3. **然后 S4~S11**（修 bug），一批一改一推。
4. **S13 必须与 S6 同批**（跳档回归锁），否则修完无保护。
5. **S15 最后做，单独一批，充分测试**——历史教训：BUG-H（模型返回选项而非叙事）、BUG-L（选项夹带过期内容）。

### 批次合并建议

- **S5 + S6**：同为 `0829353` 未完成项。建议先 S6（含跳档回归测试）再 S5（快讯依赖奇遇日志，S5 完成后才可测）。
- **S4 + S7**：同属时间/精力系统，一起改可一次性验证关键词表。

---

## 七、工作流规则（必须遵守，摘自 BATCH10_HANDOVER）

1. **每批修复前先重新核实该问题确实存在**（grep 源码确认）
2. **每修复一批立即 commit 并 push**（沿用 `bash pull.sh` / `bash push.sh "说明"`）
3. **等待 GitHub Actions CI 构建测试**（约 3-5 分钟）
4. **有错误先修复，成功后进入下一批**
5. **每批同步更新 `docs/设计审查_2026-09-21.md` 的处理台账**

### 关键注意事项

1. **不要用 heredoc 传中文** —— shell 会破坏 UTF-8 编码，改用 Python 脚本文件或 `edit_file` 工具
2. **每个补丁要幂等化** —— 先检查 anchor 是否存在，不存在就跳过
3. **每改一个文件立刻验证** —— 用 grep 确认修改成功
4. **重要操作前先 `git status`** —— 方便回滚
5. **CI 结果要等到绿才切下一批** —— 不要跳过验证
6. **存档字段数变更要同步更新 `progression_fix_test.dart`** —— 该测试硬编码 `_saveExtraData` 字段数（当前 21）
7. **测试里不要用 `isA<List>().having(length, ...)`** —— 会报未定义标识符，先 cast 再断言
8. **测试里未使用的 import 要移除** —— CI 报 `unused_import` warning
9. **本机无 Flutter** —— 测试只能靠 GitHub Actions CI 验证
10. **查 CI 状态**：
    ```bash
    curl -s 'https://api.github.com/repos/zhaolongwudi/hogwarts_life_simulator/actions/runs?per_page=5'
    ```
    （公开 API 可查，无需 token；本地 `~/.git-credentials` 中无 `github_pat_`）
11. **网络**：github.com 直连已恢复（2026-09-22 实测 HTTP 200 / 约 0.65s）。若 push 失败，先测 `curl -sI https://api.github.com`。

### 可用校验工具

```bash
python3 scripts/check_parens_code.py      # 括号平衡校验（字符串/注释剥离版）
bash scripts/check_docs_version.sh        # 文档版本一致性门禁
python3 scripts/audit_prompt_sizes.py     # prompt 体积审计（本次新增）
```

`check_parens_code.py` 当前输出（6 文件全平衡）：
```
OK  lib/mixins/mixin_play.dart  code { 305/305 ( 1287/1287 [ 93/93
OK  lib/mixins/mixin_commands.dart  code { 491/491 ( 1535/1535 [ 270/270
OK  lib/data/club_minigames_data.dart  code { 21/21 ( 35/35 [ 6/6
OK  lib/models/player.dart  code { 63/63 ( 395/395 [ 230/230
OK  lib/models/game_systems.dart  code { 71/71 ( 197/197 [ 55/55
OK  lib/mixins/mixin_club.dart  code { 61/61 ( 235/235 [ 8/8
```

---

## 八、关键文件位置速查

| 用途 | 文件:行 |
|---|---|
| 叙事 prompt 拼装 | `lib/mixins/mixin_narrative.dart:300-730`（`buildPrompt`） |
| 叙事调用 + 重试循环 | `lib/mixins/mixin_narrative.dart:753-900` |
| 选项生成（含重试） | `lib/mixins/mixin_response.dart:2033-2400` |
| `callDeepSeek`（maxTokens 分配） | `lib/mixins/mixin_systems.dart:2786-2870` |
| 系统提示词构建 | `lib/mixins/mixin_init.dart:32-208` |
| 世界观规则 | `lib/data/world_rules.dart:32`（`kWorldRulesFused`）、`:209`（Compact）、`:255`（`kUseFusedCompact = false`） |
| 叙事规则 T0/T1 | `lib/prompts/narrative_prompts.dart:50`、`:115`、`:160`（`buildNarrativeRules`） |
| 选项规则 | `lib/prompts/choice_prompts.dart:3`、`:57` |
| 摘要规则 | `lib/prompts/summary_prompts.dart`（`layerPreviousSummary`、`buildSummaryPrompt`） |
| 摘要触发阈值 | `lib/mixins/mixin_narrative.dart:1563`（`shouldRunPeriodicSummary`）、`:3642`（`kSummaryIntervalTurns = 20`）、`:3646`（`kEarlyTriggerChars = 6800`）、`:3635`（`_maxPendingSummaryChars = 8000`） |
| 时间消耗表 | `lib/data/time_cost_rules.dart:22-84`、`resolveActionCost` 在 `:100` |
| 精力恢复关键词 | `lib/mixins/mixin_systems.dart:2368-2407` |
| 决斗（含赛季） | `lib/mixins/mixin_play.dart:1035-1346` |
| 魔药/魁地奇/快讯 | `lib/mixins/mixin_play.dart:1347-1588` |
| 奇遇（含结算） | `lib/mixins/mixin_happenstance.dart:60-220` |
| 社团（含同好注入） | `lib/mixins/mixin_club.dart:49-185` |
| 命令注册 | `lib/mixins/mixin_commands.dart:871-960`（玩法&活动组） |
| 四社数据 | `lib/data/club_minigames_data.dart`（226 行） |
| 材料池 | `lib/data/item_data.dart:546`（common）、`:549`（rare）、`:562`（`rollLootMaterial`） |
| 属性上限 | `lib/data/balance_constants.dart`（`Balance`） |
| 存档字段数断言 | `test/progression_fix_test.dart:1576`（`hasLength(21)`） |
| 叙事来源降级门 | `lib/narrative/narrative_source_gate.dart` |
| AI 路由/缓存/熔断 | `lib/services/ai_router.dart:44-560` |
| 流式开关 | `lib/services/deepseek_service.dart:231`、`:366`（均 `'stream': false`） |
| 限流/配额 | `lib/services/rate_limiter.dart`（`AgnesRateLimiter:43`、`SenseNovaQuotaManager:112`、`ResponseCache:245`） |

---

## 九、交接指引

### 给下一个对话

1. **先读本文档**（你正在读），再读 `docs/工作思路与后续规划.md`（19 处引用的核心文档）与 `docs/BATCH10_HANDOVER.md`（含极限测试附录，**禁止删除**）。
2. **不要重新勘察** —— §3 每条都有精确行号，直接定位修改。
3. **从 S1 开始**（流式输出），做完一批推一批，等 CI 绿再切下一批。
4. **注意用户的协作偏好**：
   - 反对未获授权的额外改动与过度工程化（如擅自新建脚本）——**先汇报状态、确认方案再动手**
   - 项目推进中要求「一批一改一推」
   - 这是**个人自用项目**，用户的核心痛点是「越修越难玩」，即**减法优先于加法**
5. **本文档的定位**：审查快照 + 修复清单。修复过程中如需更新，请在 §6 表格中标注完成状态。

### 已知遗留待确认项

| # | 事项 | 状态 |
|---|---|---|
| 1 | `docs/NPC_头像素材清单.md`（外部引用 0）是否删除 | 待用户决定 |
| 2 | `scripts/audit_prompt_sizes.py` 是否保留 | 用户已同意保留（用于 token 审计） |
| 3 | S15（合并调用）是否执行 | 风险高，建议最后单独评估 |
| 4 | 服务端前缀缓存是否可用 | 需确认 SenseNova API 支持情况 |

---

**审查时间**：2026-09-22
**审查基线**：HEAD `1491e85`，CI run 634 全绿
**审查范围**：`lib/` 195 文件 100,101 行、`test/` 116 文件 31,285 行、`docs/` 21 份、`scripts/` 20 个、近 20 个 commit
**审查方法**：代码级 grep + 逐常量提取 + 逻辑推演复现（非文档转述）
