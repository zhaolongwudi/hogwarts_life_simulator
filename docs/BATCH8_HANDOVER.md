# 任务交接文档 - Batch 8 剩余 + Batch 9 + Batch 10

## 当前状态

**已完成（CI 全绿）：**
- ✅ Batch 5 · Issue #7（P14 频次口径统一）- commit `9f353d8`
- ✅ Batch 6 · Issue #8（selectYearGoal 加权随机 + 关联主线）- commit `eb12ce1`
- ✅ Batch 7 · Issue #11（论坛评论只 +1 数字无文本 → 写真实评论实体）- commit `0078cd0` + `77ba437`
- ✅ Batch 8 · Issue #12（传闻生成缺去重 → 加近 7 天去重 + 每日 1 条节流 + 已被传闻化标记）- commit `0be5ecf` + `1d0fe37`
- ✅ Batch 8 · Issue #15（foreshadow 实体一致性放行通道：NPC 全名/别名 + 物品名 token 双命中即放行）- commit `e535761`
- ✅ Batch 8 · Issue #16（scene_illustration Color 显式豁免 + 遗留 CI 红修复）- commit `4deedb1` + `e2d493b`

**当前任务（按优先级排）：**

### 🔨 Batch 8 剩余（AI 生成侧治理）
- Issue #17 narrative_prompts 分级（T0 常挂/T1 抽样/T2 动态）——**已调研**：`narrative_prompts.dart` 127 行含 `buildOpeningNarrativePrompt` + `kNarrativeWritingRules`（超长常量，常挂进 narrative prompt，见 `mixin_narrative.dart:727`）；方案：拆 T0（铁律：时间/场景推进/格式约束）/T1（质量类：多样性/文风）/T2（动态按需），新增 `buildNarrativeRules(level)` 按场景拼装；测试 `test/batch8_narrative_prompts_test.dart`
- Issue #18 长期记忆落库时按事件类型微调 importance

### 🔨 Batch 9 · 数值打磨（可后置）
- Issue #4 compressAffectionDelta 幂律平滑替换三段线性

### 🔨 Batch 10 · 工程基建
- Issue #13 CI 全开 smoke 套件
- Issue #14 文档纳入 CI 同步流程
- Issue #19 story_data 五书时间单调性静态校验
- Issue #23 CI 静态扫描纯计数增量必须配套字符串实体

**未采纳（明确跳过）：**
- Issue #22「去疤清理 mixin_response_affection 头部注释」——审美建议，非 bug，不做。
- 章节六·玩法提案 P1–P7（心结/预言/梦境/遗物/匿名代号/镜像/时间倒流小剧场）——工作量数天级，等 Batch 全部落地稳定后再动。

## 工作流规则（必须遵守）

1. **每批修复前先重新核实该问题确实存在**（grep 源码确认）
2. **每修复一批立即 commit 并 push**（沿用本地 pull.sh/push.sh 流程）
3. **等待 GitHub Actions CI 构建测试**（约 3-5 分钟）
4. **有错误先修复，成功后进入下一批**
5. **每批同步更新 docs/设计审查_2026-09-21.md 的处理台账**

## 关键注意事项

1. **不要使用 heredoc 传递中文** - shell 会破坏 UTF-8 编码，改用 Python 脚本文件或 edit_file 工具
2. **每个补丁要幂等化** - 先检查 anchor 是否存在，不存在就跳过
3. **每改一个文件立刻验证** - 用 grep 确认修改成功
4. **重要操作前先 git status** - 方便回滚
5. **CI 结果要等到绿才切下一批** - 不要跳过验证
6. **存档字段数变更要同步更新 progression_fix_test.dart** - 该测试硬编码了 `_saveExtraData` 字段数（当前 21），新增字段要 +1
7. **测试里不要用 `isA<List>().having(length, ...)`** - `length` 会被解析为未定义标识符，改为先 cast 再断言
8. **测试里未使用的 import 要移除** - CI 会报 unused_import warning（虽然不卡门禁，但保持干净）

## 文件位置速查

### 核心数据文件
- `lib/data/goal_data.dart` - SubGoal 类、yearGoalPool、selectYearGoal 函数
- `lib/data/foreshadow_data.dart` - 伏笔数据（Issue #15）
- `lib/data/scene_illustration_data.dart` - 场景插图数据（Issue #16）
- `lib/data/story_data.dart` - 主线剧情数据（Issue #19）
- `lib/data/balance_constants.dart` - 平衡常量（Issue #4）

### 核心逻辑文件
- `lib/mixins/mixin_systems.dart` - 系统逻辑（含 _maybeGenerateRumor、_saveExtraData、applySaveData）
- `lib/mixins/mixin_relations.dart` - 关系逻辑（含 addRumor）
- `lib/providers/game_provider_base.dart` - GameProvider 基类（含 dailyActivityCount、rumoredEventDays 等字段）
- `lib/providers/game_provider.dart` - GameProvider 本体
- `lib/models/player.dart` - Player 类（含 ForumPost、ForumComment）
- `lib/models/world_state.dart` - WorldState 类（含 NarrativeEvent、recentNarrativeEvents）
- `lib/models/long_term_memory.dart` - 长期记忆（Issue #18）
- `lib/prompts/narrative_prompts.dart` - 叙事提示词（Issue #17）

### 测试文件
- `test/batch6_year_goal_test.dart` - Batch 6 测试
- `test/batch7_forum_comment_test.dart` - Batch 7 测试
- `test/batch8_rumor_dedup_test.dart` - Batch 8 Issue #12 测试
- `test/progression_fix_test.dart` - 存档字段数硬编码测试（第 1576 行）
- `test/helpers/test_fixtures.dart` - 共享测试 fixture（makeGame）

### 文档
- `docs/设计审查_2026-09-21.md` - 设计审查台账（必须每批更新）
- `docs/BATCH6_HANDOVER.md` - Batch 6 交接文档（参考格式）

## 各 Issue 详细分析

### Issue #15 foreshadow 实体一致性放行通道
**问题：** `foreshadow_data.dart` 用中文二字组重合度匹配伏笔闭环，但可能误关（长文本稀释）或漏关（实体名不一致）。
**修法：** 加人名 token + 物件名 token 双命中即放行的通道。
**文件：** `lib/data/foreshadow_data.dart`（255 行）
**测试：** 新增 `test/batch8_foreshadow_test.dart`

### Issue #16 scene_illustration Data Color(0xFF...) 收敛
**问题：** `scene_illustration_data.dart` 里大量硬编码 `Color(0xFF...)`，应收敛到主题系统或显式豁免。
**修法：** 要么收敛到 `AppColors`/`Theme`，要么在顶部注明"仅供场景插图，不参与主题切换"。
**文件：** `lib/data/scene_illustration_data.dart`（322 行）
**测试：** 新增 `test/batch8_scene_illustration_test.dart`（源码检查）

### Issue #17 narrative_prompts 分级
**问题：** `narrative_prompts.dart` 所有提示词都常挂，token 消耗高。
**修法：** 分级 T0 常挂/T1 抽样/T2 动态，按场景选择。
**文件：** `lib/prompts/narrative_prompts.dart`（127 行）
**测试：** 新增 `test/batch8_narrative_prompts_test.dart`

### Issue #18 长期记忆 importance 微调
**问题：** 长期记忆落库时 importance 固定，未按事件类型微调。
**修法：** 按事件类型（战斗/社交/探索/学习等）微调 importance。
**文件：** `lib/models/long_term_memory.dart`（863 行）
**测试：** 新增 `test/batch8_long_term_memory_test.dart`

### Issue #4 compressAffectionDelta 幂律平滑
**问题：** 三段线性斜率 1/0.4/0.2/0 接缝跳变。
**修法：** 改单调平滑 `mapped = min(10, round(sqrt(d*2)))` 一类幂律。
**文件：** `lib/data/balance_constants.dart`
**测试：** 更新现有测试

### Issue #13 CI 全开 smoke 套件
**问题：** 默认关掉全部新系统保证 1900+ 既有用例稳定，代价是默认配置与测试配置完全不同。
**修法：** CI 加一份"全开 smoke"套件。
**文件：** `.github/workflows/` 下新增 workflow
**测试：** 新增 smoke 测试

### Issue #14 文档纳入 CI 同步流程
**问题：** 文档漂移（PROJECT_GUIDE v5.0.2 / 规划文档基线 v4.8.4 / README 滞后）。
**修法：** 文档纳入 CI 同步流程。
**文件：** `.github/workflows/` 下新增 workflow
**测试：** 新增文档同步测试

### Issue #19 story_data 五书时间单调性静态校验
**问题：** story_data 五书时间可能不单调。
**修法：** 加静态校验。
**文件：** `lib/data/story_data.dart`、`lib/data/story_data_gof.dart`、`lib/data/story_data_hbp.dart` 等
**测试：** 新增 `test/batch10_story_data_monotonic_test.dart`

### Issue #23 CI 静态扫描纯计数增量必须配套字符串实体
**问题：** 纯计数增量（如 `comments += 1`）可能没有配套字符串实体。
**修法：** CI 静态扫描。
**文件：** `.github/workflows/` 下新增 workflow
**测试：** 新增静态扫描测试

## 开始工作前请执行

```bash
cd /root/hogwarts_life_simulator
bash pull.sh  # 拉取最新代码
```

## 建议执行顺序

1. **Issue #16**（scene_illustration Color 收敛）- 改动最小、收益最直接
2. **Issue #15**（foreshadow 实体一致性）- 中等改动
3. **Issue #17**（narrative_prompts 分级）- 中等改动
4. **Issue #18**（长期记忆 importance 微调）- 中等改动
5. **Issue #4**（compressAffectionDelta 幂律平滑）- 独立改动
6. **Issue #19**（story_data 时间单调性）- 独立改动
7. **Issue #13**（CI smoke 套件）- 工程基建
8. **Issue #14**（文档同步）- 工程基建
9. **Issue #23**（CI 静态扫描）- 工程基建

---

**交接时间：** 2026-09-21
**交接人：** 当前对话
**接收人：** 下一个对话

**当前 HEAD：** `24b52d9`（docs: mark Batch 8 Issue #15 & #16 done，已 rebase CI changelog v5.1.2）
**CI 状态：** 全绿（Issue #15/16 所在 run 35572952394 success，2066 tests passed）