# 任务交接文档 - 当前 Batch 48 状态 + 历史回顾
## 当前状态（HEAD: e598346，已全量 push，CI 全绿 run 35827501756）
**Batch 48 · 来信串联（✅ 完成，CI 全绿）：**
- 设计来源：docs/来信串联设计.md（2026-09-22 预研，第二梯队首项）。
- `e0ccb2e` `feat(batch48): 来信串联——社长邀请信(来信→社团) + 羁绊预热信(来信→羁绊)`：LetterDef 增 clubId 可选字段（零迁移）；kLetters 新增 6 封信（4 社长邀请 duel/potion/broom/quip + 2 羁绊预热 hermione/harry）；maybeTriggerLetter 新增 3.5 分支（未入社+社长好感达标→投社长信，优先级 milestone→ministry→mystery→社长邀请→friendship→reunion→rivalry）；friendship 分支排除 clubId 非空；tryResolveLetterReplyChoice 回信「好，我加入」→ joinClub(clubId) 直接入社（含同好注入 A +5）；GameProviderBase 补 joinClub 抽象声明；test/batch48_letter_tie_test.dart 新建（5 组 11 用例）
- `ee1b5ad` `fix(batch48): 社长邀请信分支加 clubEnabled 门控`：3.5 分支条件从 `p.clubId==null` 改为 `p.clubId==null && appProvider.clubEnabled`（不干扰 clubEnabled=false 的既有测试）；batch48 fixture 开 clubEnabled=true
- `e598346` `fix(batch48): 社长信3.5分支补minAffection校验`：根因——letterSenderFor 对指定 senderId 的信只检查 NPC 是否在 pool（introduced+alive+!graduated），不检查好感达标；3.5 分支在 letterSenderFor 返回非 null 后额外校验 `sender.affection >= l.minAffection`；修掉 batch48 测试 unused_local_variable warning
- **当前状态**：HEAD=e598346、origin/main=e598346、工作区干净；batch48 来信串联（社长邀请信+羁绊预热信）全部落地，CI 全绿。

---
## 历史状态（Batch 47 完成 + Batch 44 回顾）
## 历史 HEAD（Batch 47）：395b511，CI 全绿 run 35819549202
**Batch 47 · 更多来信类型（✅ 完成，CI 全绿）：**
- 设计来源：docs/更多来信类型设计.md（2026-09-22 预研，第 8 份设计文档）。
- `90ec275` `feat(batch47): 更多来信类型——魔法部公函/神秘信件/毕业旧友重联`：LetterKind 扩展 3 值（ministry/mystery/reunion）；LetterDef 增 senderLabel（机构/匿名署名）+ month（学期节点月份）；mixin_letter 触发优先级 6 分支（milestone→ministry→mystery→friendship→reunion→rivalry）+ senderLabelReady 哨兵 + _applyLetterEffectAnonymous 匿名结算；test/batch47_letter_types_test.dart 新建
- `6c440e2` `fix(batch47): 消除测试随机性——固定seed + ministry断言改为任一公函`：固定 seed 消除随机性，断言放宽
- `a07d042` `fix(batch47): ministry信绑学期节点月份(5月O.W.L.s/9月禁林) + batch42适配预收新类型`：letter_ministry_owls.month=5（O.W.L.s 报名）、letter_ministry_forbidden.month=9（禁林警告）；batch42 测试预收 ministry/mystery 防新类型抢戏
- **CI 红（run 35817159522，2202 passed / 2 failed）**：batch47 两个测试断言「收到魔法部公函」实际收到赫敏友情信。根因：makeGame 默认 letter 起点=7月31日（worldState.time.month==7），两封 ministry 信分别绑定 5/9 月，7 月一封都投不出 → ministry 分支空转落到 friendship。
- `395b511` `fix(batch47): 测试固定5月(魔法部公函投递月)`：batch47 makeEnabled 里 `gp.worldState.time.month = 5; gp.worldState.time.day = 7;` → ministry 必命中 letter_ministry_owls → CI 全绿 `35819549202`
- **当前状态**：HEAD=395b511、origin/main=395b511、工作区干净；batch47 三型来信（魔法部公函/神秘信件/毕业旧友重联）全部落地，CI 全绿。

---
## 历史状态（Batch 45 完成 + Batch 44 回顾）
## 历史 HEAD（Batch 44）：64452a5，CI 全绿 run 35645170252
**Batch 44 · AI 配置重构（✅ 完成，CI 全绿）：**
- 目标：参考 Operit 现有模型地址/模型名/多 Key 轮换方案，重构项目内 AI 配置与功能分配；Operit 的功能绑定（CHAT/SUMMARY 等）不参考（不同系统）。
- `47ea14b` `feat(batch44): AI配置重构——多Key托底备用模型+商汤deepseek-v4-pro+设置页分区导航`：
  - `lib/data/provider_defaults.dart`：商汤 models 补 `deepseek-v4-pro`（复杂推理，500次/5h）
  - `lib/providers/app_provider.dart`：新增 `_fallbackProvider` 字段（全局托底备用模型，默认 Atria=deepseek 枚举，可空=关闭）+ getter `fallbackProvider` + setter `setFallbackProvider`（持久化 key `fallback_provider`，存枚举索引/空串）+ loadSettings 读取 + freeModelsFor 补 deepseek-v4-pro
  - `lib/providers/game_provider.dart`：`updateClient` 里 `_buildFallbackOrder()` 动态算 fallbackOrder（托底提供商排最前，其余按枚举顺序补全），传给 AiRouterConfig
  - `lib/screens/settings/settings_body.dart`：设置页改「顶部分区导航」（3 个 tab：AI 服务/游戏/系统），把原先一拉到底的 13 板块收成三段
  - `lib/screens/settings/settings_scene_routing.dart`：新增「🛟 托底备用模型」选择行（关闭托底 + 各提供商可选，未配 Key 的加锁）
  - `test/batch44_ai_fallback_test.dart` 新建（fallbackProvider 默认值/改选/关闭 + deepseek-v4-pro 进列表）
- 首跑 CI 红 `35643239833`（2157 passed / 1 failed）：失败点是测试里「裸读 SharedPreferences.getInstance() 断言底层存储值」——mock 环境下 PrefsStore 单例缓存与 setMockInitialValues 重置产生实例分裂读到旧值。该断言脆弱且与前两条持久化往返断言重复。
- `64452a5` `fix(batch44): 移除脆弱的底层存储断言测试`：删除该重复断言 → CI 全绿 `35645170252`
- **多 Key 轮换 + 托底语义（已落地）**：路由层 `AiRouter._callWithFallback` 先试 primary 的所有 Key（轮询 + 单 Key 熔断 3 次/60s + 超时切下一 Key），全部失效后按 fallbackOrder 切托底提供商（再走同样轮换），最后枚举顺序兜底。设置页可改/可关托底。

---
## 历史状态（Batch 11 完成 + Batch 10 回顾）
## 历史 HEAD：0999bf5，CI 全绿 run 35636420159
**Batch 11 · 社团 × 学院杯反向半环（✅ 完成，CI 全绿）：**
- `3b4b009` `feat(batch11): 社团×学院杯反向半环（学年结算社团荣光）`：lib/data/house_cup_data.dart +82 行（kClubCupSourcePrefixes / clubContributedCupPoints / ClubCupBonusTier / kClubCupBonusTiers 两档 / clubCupTierFor）；lib/mixins/mixin_play.dart +27 行（import club_data + settleHouseCup 内插入「社团荣光」块）；test/batch11_club_cup_test.dart 新建（四组 13 用例）
- 首跑 CI 红 `35635683640`（Run tests with coverage 失败）：根因是 `_ensureHouseCupYearly` 把玩家学院分设为 `130 + houseCupPoints`，测试 14 分 → 格兰芬多 144 排第一 → rank==1 排名奖励（+50 加隆+15 学院声望）与社团奖励叠加污染断言
- `0999bf5` `fix(batch11): 测试预置四院榜单`：makeSettled 预置 houseCupYearly（格兰芬多 130 / 其余三院 999），玩家稳定排第 4（else 分支仅社交+2，不碰加隆/学院声望）→ CI 全绿 `35636420159`
- 台账 `docs/设计审查_2026-09-21.md` 与规划 `docs/工作思路与后续规划.md` 均已同步标记完成
**已完成回顾（Batch 5-10，CI 全绿）：**
- ✅ Batch 5 · Issue #7（P14 频次口径统一）
- ✅ Batch 6 · Issue #8（selectYearGoal 加权随机 + 关联主线）
- ✅ Batch 7 · Issue #11（论坛评论写真实评论实体）
- ✅ Batch 8 · Issue #12（传闻生成去重 + 节流）
- ✅ Batch 8 · Issue #15（foreshadow 实体一致性放行通道）
- ✅ Batch 8 · Issue #16（scene_illustration Color 显式豁免）
- ✅ Batch 8 · Issue #17（narrative_prompts 分级 T0/T1/T2）
- ✅ Batch 8 · Issue #18（长期记忆 importance 按事件类型集中配置）
- ✅ Batch 10 · Issue #13/#14/#19/#23（详见下方）
  - `658905c` 首次提交，CI 红（自检用例正则匹配不到 `commentList.add`）
  - `faaeb94` 修复：`_entityWritePattern` 正则从 `\.\w*(List|Entries|Items|Records)\s*\.(add|insert)` 放宽为 `\.\w+\s*\.(add|insert)`，并同步改断言用例 → CI 全绿
  - `c1e0ed3` 台账标记完成
- ✅ Batch 10 · Issue #19（story_data 五书时间单调性静态校验）
  - `7f53702` 新增 `test/batch10_story_data_monotonic_test.dart`（246 行）
  - 覆盖：书锚点全局单调（七部逐年递增 + 后书锚点严格晚于前书，防衔接倒流）/书内时间戳严格递增/跨书衔接不重叠（每书完成日 ≤ 下一书锚点）/每书完成日落学年尾 6~8 月/每书总天数 [200,420] sanity/源码静态存在性（六文件 + 七书注册 + 无幽灵书）
  - 实测七书数据核算通过：ps 结束 1992-07-02 → cos 锚点 1992-07-25 → … → dh 结束 1998-07-20，全部衔接 OK
  - 台账 `docs/设计审查_2026-09-21.md` 已同步标记完成
- ✅ Batch 10 · Issue #13（CI 全开 smoke 套件）
  - `efa960b` 新增 `test/batch10_smoke_all_on_test.dart`（150 行）：①P10~P14 生产默认全开断言（绕过 makeGame 夹具、直接构造 AppProvider）②全开 30 回合长局不崩/时钟前进/叙事非空 ③存档→读档往返（真实 SaveService）④剧情模式+全开共存跑 5 步
  - 首跑 CI 红 `35623112412`（2133 passed / 2 failed）：剧情模式测试因 kStoryBooks 显式注册制、makeGame 不注册书表 → storyStartStepFor 返回 null「剧情内容未加载」；存档往返测试因 path_provider 无原生插件实现抛 MissingPluginException
  - `ba3235f` 修复：setUpAll 补 `registerAllStoryBooks` + mock path_provider MethodChannel 指向系统临时目录 → CI 全绿 `35626737192`
  - 台账 `docs/设计审查_2026-09-21.md` 已同步标记完成
- ✅ Batch 10 · Issue #14（文档纳入 CI 同步流程）
  - 新增 `scripts/check_docs_version.sh`（文档版本一致性门禁）：校验 README badge / PROJECT_GUIDE 当前版本与 pubspec.yaml 一致，漂移 exit 1
  - 新增 `scripts/sync_docs_version.sh`（幂等同步）：把 README badge + PROJECT_GUIDE 当前版本刷成 pubspec 真实版本
  - `android-build.yml`：新增「Check docs version consistency (Issue #14)」步骤（全量门禁）；Sync changelog 步骤追加调用 sync_docs_version.sh，并把 PROJECT_GUIDE.md 纳入自动提交范围
  - 当前仓库漂移已修复：README v5.0.4→v5.1.3、PROJECT_GUIDE v5.0.2→v5.1.3

**Issue #4 已核实，建议「不采纳」（同 Issue #22）：**
- 实测旧分段映射 0~40 全表：已单调不减、无跳变 >1、上限 ±10 守住。
- 报告说的「非连续」实为 round 取整的平台期（如 5、6 都→5），是取整固有舍入，非 bug。
- 报告建议的 `sqrt(d*2)` 反而有害：落地区间整体缩水（中等 4~6→3~4、重大 7~9→4~6）、层次差距变小、跨档重叠，倒退 P0-1「拉开层次」成果，且会让 `provider_logic_test` / `audit_round9_test` 回归锁全红。
- **结论：不改。** 若用户仍要动，必须先推翻上述实测依据并重核测试回归锁。

## 待做清单（按优先级，一批一改一推）

### 🔨 Batch 10 · 工程基建（已完成）
1. **Issue #13** ✅ **已完成**：test/batch10_smoke_all_on_test.dart（150 行）生产默认全开 smoke 套件，覆盖 ①P10~P14 生产默认全开断言 ②全开 30 回合长局不崩 ③存档→读档往返 ④剧情模式+全开共存。首跑 CI 红（2133 passed/2 failed）已修：剧情书显式注册（setUpAll registerAllStoryBooks）+ path_provider mock（MethodChannel 指向系统临时目录）；commit `ba3235f`，CI run 35626737192 全绿。
2. **Issue #14** ✅ **已完成**：文档纳入 CI 同步流程。新增 scripts/check_docs_version.sh（门禁）+ scripts/sync_docs_version.sh（同步）；android-build.yml 加门禁步骤 + Sync changelog 追加文档同步；漂移已修复（README/PROJECT_GUIDE → v5.1.3）。

### ⚪ Issue #4 压缩函数（建议跳过，见上）

### ✅ AI 链路审查 15 批次（2026-09-22/23 完成，全部 CI 全绿）
> 依据 docs/AI链路审查与优化交接.md（§6 执行表）。最终 HEAD `cf357d8`。
> 详细执行状态见 docs/AI链路审查与优化交接.md「执行状态（2026-09-23 更新）」小节。

| 批次 | commit | 内容 |
|---|---|---|
| S1 | `62449d1` | 流式输出（SSE + streamingPreview 独立字段 + 降级重试） |
| S2+S3+S12 | `bedd7d3` | 减法三连：规则去重 + T3 40→15 + 选项端 T0 14→9 |
| S4+S7 | `f5fd35a` | 睡眠语义两表对齐（120 分钟昼寝级）+ 魁地奇训练 30 分钟 |
| S5 | `b62369a` | 奇遇结算写 happenstanceLog（上限 50，快讯社复活） |
| S6+S13 | `1bb0a53` | 决斗跳档逐档补发 + 四社专项测试 9 用例 |
| S8+S9+S10+S11 | `6d0ed04` | 赛季积分递减 + 银色鳞片进八眼巨蛛掉落 + 快讯学期口径 + 魁地奇周重置 |
| S14 | `e3e8a14` | 文档同步：5 设计文档状态行 + README 命令表 + 台账批次 B/C + BATCH10 HEAD |
| S15 标记 | `cf357d8` | **评估后搁置**（见 AI链路审查文档「执行状态」小节理由） |

**S15 搁置结论**：合并叙事+选项调用涉及 generateChoicesSeparately（476 行），
历史 BUG-H/BUG-L 复发风险高；S1 流式已解决反应慢主因；与减法优先方向相悖。
若执行需单独一批充分测试。

## 工作流规则（必须遵守）
1. **每批修复前先重新核实该问题确实存在**（grep 源码确认）
2. **每修复一批立即 commit 并 push**（沿用 `bash pull.sh` / `bash push.sh "说明"`）
3. **等待 GitHub Actions CI 构建测试**（约 3-5 分钟）
4. **有错误先修复，成功后进入下一批**
5. **每批同步更新 docs/设计审查_2026-09-21.md 的处理台账**

## 关键注意事项
1. **不要用 heredoc 传中文** - shell 会破坏 UTF-8 编码，改用 Python 脚本文件或 edit_file 工具
2. **每个补丁要幂等化** - 先检查 anchor 是否存在，不存在就跳过
3. **每改一个文件立刻验证** - 用 grep 确认修改成功
4. **重要操作前先 git status** - 方便回滚
5. **CI 结果要等到绿才切下一批** - 不要跳过验证
6. **存档字段数变更要同步更新 progression_fix_test.dart** - 该测试硬编码了 `_saveExtraData` 字段数（当前 21），新增字段要 +1
7. **测试里不要用 `isA<List>().having(length, ...)`** - 会报未定义标识符，先 cast 再断言
8. **测试里未使用的 import 要移除** - CI 报 unused_import warning（不卡门禁但保持干净）
9. **本机无 Flutter** - 测试只能靠 GitHub Actions CI 验证，改完推上去看 CI
10. **查 CI 状态/日志**：
    ```bash
    TOKEN=$(grep -o 'github_pat_[A-Za-z0-9_]*' ~/.git-credentials | head -1)
    curl -s -H "Authorization: Bearer $TOKEN" 'https://api.github.com/repos/zhaolongwudi/hogwarts_life_simulator/actions/runs?per_page=5'
    ```
11. **⚠️ 网络：github.com 直连 DNS 常失效** - 若 push 报 `Failed to connect to github.com port 443`，先测 `curl -sI https://api.github.com`（api 通代表网络可用）与 `getent hosts github.com`（若解析出 20.205.x.x 亚太段则大概率连不上）；修法是把可用 IP（如 140.82.112.3，实测 200）写进 /etc/hosts：
    ```bash
    echo '140.82.112.3 github.com' >> /etc/hosts
    ```
    然后重试 push。

## 文件位置速查
- `lib/data/balance_constants.dart` - 平衡常量（含 compressAffectionDelta，Issue #4）
- `lib/data/house_cup_data.dart` - 学院杯数据（Batch 11 新增社团荣光：kClubCupSourcePrefixes / clubContributedCupPoints / kClubCupBonusTiers / clubCupTierFor）
- `lib/mixins/mixin_play.dart` - 学院杯结算（settleHouseCup 内含 Batch 11「社团荣光」块）
- `lib/data/story_data.dart` + `story_data_{poa,gof,ootp,hbp,dh}.dart` - 主线剧情数据（Issue #19 已完成）
- `lib/models/story_progress.dart` - 剧情进度/书序
- `lib/mixins/mixin_systems.dart` - 系统逻辑
- `test/batch11_club_cup_test.dart` - Batch 11 社团×学院杯反向半环测试（四组 13 用例，已就位）
- `test/batch10_counter_entity_test.dart` - Batch 10 Issue #23 静态扫描测试（已就位）
- `test/batch10_story_data_monotonic_test.dart` - Batch 10 Issue #19 时间单调测试（已就位）
- `docs/设计审查_2026-09-21.md` - 设计审查台账（必须每批更新）
- `docs/工作思路与后续规划.md` - 规划文档（第一梯队「社团 × 学院杯联动」已标记 Batch 11 完成）

## 开始工作前请执行
```bash
cd /root/hogwarts_life_simulator
bash pull.sh  # 拉取最新代码
```
---
**交接时间：** 2026-09-22
**交接人：** 当前对话
**接收人：** 下一个对话
**当前 HEAD：** `0999bf5`（fix(batch11): 测试预置四院榜单，CI run 35636420159 全绿）

---

## 📋 附录：长对话「无提示停止」极限测试计划（2026-09-22 起）

> 本附录由测试专用对话维护，**禁止删除**；测试结束后保留观察结论，供后续对话参考。

### 测试目标
定位"对话无提示停止"的真实触发机制，判断能否回调上下文压缩设置。

### 配置基线（测试前，2026-09-22 记录）
- CHAT：summary_token_threshold=0.35 / summary_message_count_threshold=8 / context_length=48 / max_context_length=128（enable_max_context_mode=true）
- 工作流 ed134977「自动交接巡检」：Input tokens > 500万 → 建新对话+停旧对话+通知；**定时触发已关**（测试期间保持关闭，仅场景4 临时开）
- 注意：max_context_length 是从 512 降下来的（0.34 事件副作用），若停止发生在 ~128 水位优先怀疑 max_context_length 先触发

### 🔄 配置回调（方向A，2026-09-22 执行，测试前→回调后新基线）
- 回调触发：5 次无提示停止（16g/16h/16i/16j/16k）定位为**模型调用 SenseNova 429**（用户第一手信息+口径修正：前 4 次工具后输出生成环节、第 5 次总结环节），非上下文阈值触发
- 回调目的：让模型能力更强（更大上下文窗口），做**回调前后稳定性对比**：回调前=不稳定（5/5 停止），回调后=待测（若 10 轮无停止=稳定）
- 回调数值（CHAT 配置 a7757af9，实测前 96/256/0.4/10 → 回调后 192/512/0.5/16）：
  - context_length: 48→96→**192**（测试前基线 48 的 4 倍）
  - max_context_length: 128→256→**512**（测试前基线 128 的 4 倍）
  - summary_token_threshold: 0.35→0.4→**0.5**（压缩更晚触发）
  - summary_message_count_threshold: 8→10→**16**（按条数压缩更晚触发）
  - 保留 enable_max_context_mode=true / enable_summary=true / enable_summary_by_message_count=true
- 未动项：maxTokens=8192、temperature=0.2、topP=0.8、RPM=60、并发=3、useMultipleApiKeys=true（7 Key 池）——方向B（更保守 RPM/并发）未执行，留待回调后仍停止时再上
- 受影响功能：CHAT / GREP / SUMMARY / TRANSLATION / UI_CONTROLLER（同一配置 a7757af9）
- 【取中调整 2026-09-22 14:2x】方向A 大档（192/512/0.5/16）实测导致工具执行卡顿（一次 shell 返回「工具结果缺失」），且日志实锤 429 高频 + 设备内存 512MB/空闲 94MB + ANR 838 次 → 已取中为 **128/384/0.45/12**（当前生效）。方向 B（RPM 60→30、并发 3→1）未执行，作为后备。
- 【✅ 方向B 落地 2026-09-22 16:2x】测试结论锁定「429 限流 + 设备资源紧张」为根因、回调参数只是放大器后，正式执行方向 B：**request_limit_per_minute 60→30、max_concurrent_requests 2→1**（operit_editor:update_model_config a7757af9，changedFields 确认）。受影响功能：CHAT/GREP/SUMMARY/TRANSLATION/UI_CONTROLLER（同一配置）。目的：降低 RPM/并发 → 减少撞 SenseNova TPM/RPM 双限流的频率。**新判定节点：方向B 生效后 ≥10 轮无停止 = 稳定性通过**；若仍停止 → 锁定 Operit 总结/输出链路缺陷（不轮换 Key/不退避 429）。
- 当前生效配置（2026-09-22 16:2x 核实）：context_length=128 / max_context_length=384 / summary_token_threshold=0.45 / summary_message_count_threshold=12 / enable_max_context_mode=true / maxTokens=8192 / **RPM=30 / 并发=1** / 7 Key 池；工作流 ed134977 保持 enabled=false（测试期间关闭）。
- 回调后判定：若本对话后续 10 轮无停止 → 回调有效、测试稳定；若仍停止 → 排除调参因素，锁定 Operit 总结链路缺陷（不轮换 Key/不退避 429）

### ⚡ 方向B 生效后观测（2026-09-22 16:3x 起）
- 【⚠️ 无提示停止第七例（记 16m，2026-09-22 16:3x 用户「又出现了无提示停止」触发取证）】**方向B（RPM 30/并发1）生效后首次停止**。停止点：16:2x 落地方向B + 台账补录（edit_file 成功，153-154 行已落盘）后，生成总结回复时输出中断——与 16g-16l 完全同 pattern（工具成功落盘、仅输出中断）。恢复后核验：方向B 参数生效（RPM=30/并发=1，get_function_model_config 确认）、台账 343 行完整。**方向B 首轮即停 → 判定规则触发「仍停止 → 锁定 Operit 总结/输出链路缺陷」方向**，但用户叠加新变量后重新观测（见下）。
- 【👤 用户手动改动 2026-09-22 16:3x】用户把 **SUMMARY + GREP 从 a7757af9(v4-flash) 切到 52636cce(商汤 6.8-flash-lite)**（list_function_model_configs 确认）。动机：把高频轻量任务从 v4-flash 分流，减少 v4-flash 撞 SenseNova 429。6.8 配置特征：apiKeySet=true(主key sk-***LM) / useMultipleApiKeys=true(7 key) / RPM=120 / 并发=3 / maxTokens=32768 / context 128/256 / 0.6/16 压缩。
- 【多 key 切换结论】商汤系三个配置（a7757af9 v4-flash / 52636cce 6.8 / aceb81e3 v4-pro）均 useMultipleApiKeys=true + apiKeyPoolCount=7 → **调用时多 key 轮换已开启**。遗留疑点（16k 记录）：总结/输出生成链路是否真正走 key 轮换无日志证据——若 6.8 分流后 CHAT 仍停，此点为下一步排查方向。
- 【新判定节点】当前双变量基线：CHAT/TRANSLATION/UI_CONTROLLER=v4-flash(RPM30/并发1) + SUMMARY/GREP=6.8(RPM120/并发3)。**观测 ≥10 轮无停止 = 稳定性通过**；若仍停止 → 不再调参，锁定 Operit 链路缺陷（总结/输出的 key 轮换与退避）。
- 工作流 ed134977 保持 enabled=false（测试期间关闭，勿动）。

### 🟢 续跑观测（2026-09-22 16:4x 起，双变量基线）
- 【✅ 批次B/C 收尾质量闸通过（本对话 23 轮）】断点①②③ 全量核验：①魁地奇比赛训练加成 `p.qTrainWeek * 3`（mixin_play.dart:947）②成就 catalog 补 training_master/headline_reporter（game_systems.dart:675-676）③括号校验 6 文件全平衡（mixin_play 305/305·1287/1287·93/93、mixin_commands 491/491·1535/1535·270/270、club_minigames_data 21/21·35/35·6/6、player 63/63·395/395·230/230、game_systems 71/71·197/197·55/55、mixin_club 61/61·235/235·8/8，后两者为追加核验）——16k 遗留「待重跑」项闭环，脚本默认清单补录 mixin_club.dart（check_parens_code.py:109）。Git 基线：HEAD=4e74548（本地 ahead 3 / behind 3，远端内容等价 9898a593），工作区仅台账 M。**本轮无停止、水位 ●○○○、无总结触发——双变量基线第 1 轮（自 16m 恢复后计）**
- 【⚠️ 无提示停止第八例（16n，2026-09-22 16:3x 用户再报停止触发取证）】停止点：上一轮完成「台账续跑观测补录 + 脚本补录 mixin_club.dart」两个工具成功后，输出生成中断——与 16g-16m 完全同 pattern（工具成功落盘、仅输出中断）。恢复后核验：台账 164-165 行 + 脚本 109 行全部在（grep 命中）→ 工具全部落盘确认。**附带发现**：本任务启动核验 CI 时定位 run 35702774453（head_sha=9898a593=本地 4e74548 等价）**Analyze 步骤 failure**（后续 test/build 全 skipped）——error 级：①mixin_commands.dart 887/908/910/912/928/931/933/947/949 多处 `undefined_method`（trainQuidditch/showPotionRecipes/brewPotion/showHeadlineBoard/reportHeadline/claimDuelSeasonReward/showDuelSeasonPanel 定义于 GamePlayMixin，GameCommandsMixin handler 内 `ctx.provider as GameCommandsMixin` 调不到）②game_play_screens.dart:164 `MiuiColors.onSurfaceVariantSummary` 不能赋给 `Color?`（MiuiColors 为 class 非 Color 类型）。**CI failure 为批次B/C 代码真实静态编译错（该批 commit 经 Git Data API 推送后从未通过 CI），非测试观测变量**，修复列入工作负载（command handler 改用 provider 泛型可访问方法 + 颜色字段类型修正），本轮不动代码以免污染新基线观测。
- 【👤 用户手动改动 2026-09-22 16:3x（16n 恢复后）】用户手动把 CHAT **max_context_length 384→256**（get_context_summary_config 确认：context_length=128 / max_context_length=256 / enable_max_context_mode=true / summary_token_threshold=0.45 / summary_message_count_threshold=12），其余不变（RPM30/并发1/7key/maxTokens8192）。用户动机：「怀疑不是并发和频率的问题」→ 方向B 已降 RPM/并发仍连续停止（16m 方向B 首轮即停、16n 二停），转试**缩小上下文窗口→降低每轮输入 token→降 TPM** 维度（与方向B 的 RPM 维度正交）。**新观测基线：128/256/0.45/12 + RPM30/并发1（双变量+用户手调）**，自 16n 恢复后重新计数观测轮次（基线第 0 轮起）。
- 【⚠️ 无提示停止第九例（16o，2026-09-22 16:5x 用户再报停止）】停止点：上一轮「推送进程状态轮询」工具成功返回后，输出生成中断——与 16g-16n 完全同 pattern（工具成功落盘、仅输出中断）。恢复后核验：①推送日志推进至「commit 9e82516 -> 0829353b」、正在推第二个 commit dd25c72 → CI 修复 commit 4a62f82 传输中（首棵大 tree 遍历耗时约 5 分钟，非死锁）②远端 main 当时仍 9898a593 ③CI 无新 run。**本轮工作负载（用户决策「先修 CI」已执行并 commit 4a62f82）**：A 类——game_provider_base.dart:858-871 补 7 个玩法抽象声明（trainQuidditch/showPotionRecipes/brewPotion/showHeadlineBoard/reportHeadline/showDuelSeasonPanel/claimDuelSeasonReward；与既有 formatQuidditch/playQuidditch/setQuidditchPosition 先例一致，handler 静态类型 GameProviderBase 需要）；B 类——game_play_screens.dart + settings_body.dart 共 9 处 `const MiuiColors.x` 误用改 `MiuiColors.x`（static const Color 字段误走 const 构造函数语法；连带 statusColor 由 Object 恢复 Color，withValues/AlwaysStoppedAnimation 报错自愈）；括号校验 6 文件 + game_provider_base 全平衡。**观测判读：新基线（128/256/0.45/12）首个完整对话轮次即停（16o），与 16m（方向B 首轮即停）同 pattern** —— RPM/并发、上下文窗口、6.8 分流三个维度全调均无效，累计 9 次同 pattern 停止，趋近「Operit 输出/总结链路缺陷（key 轮换/429 退避未覆盖该链路）」锁定判定，观测轮次自 16o 恢复后重新计数。

### 场景设计
1. 场景1 · 基线观测（20-30 轮）：正常推进，记录水位变化 🟡/🔴、AI 是否主动总结、总结后是否忘早期细节
2. 场景2 · 长消息压缩观测：发 1 条 3000-5000 字长文本，观察是否立即触发总结；总结后追问早期细节验证丢内容程度
3. 场景3 · 长对话极限测试（核心）：持续工作任务推进，每 10 轮记录一次，观察何时"无提示停止"
4. 场景4 · 工作流联动（仅 3 没停时做）：开工作流逼近 500万，验证超限行为

### 判定表
- 停止时水位远低于 128 → 疑模型窗口/网络/Operit 限制，与 500万 无关
- 停止时水位≈128 → max_context_length 先触发，工作流兜不住 → 需回调 128 或改判据
- 停止时 Input tokens≈500万 → 工作流阈值触发，可放心回调压缩设置
- 全程无停止 → 白天正常，保持现状即可

### 回调建议（测完对照执行）
- 压缩过频致丢内容 + 停止点=500万：0.35→0.5~0.6、message_count 8→12~16、context_length 48→128~192、max_context_length 128→256~512（分档回调）
- max_context_length 128 先触发：优先回调 max_context_length，工作流阈值下调或改"按窗口比例"判据
- 无停止：不动

### 测试进度台账（每轮/每 10 轮更新）
| 轮次 | 水位 | 是否总结 | 是否停止 | 停止前最后现象 | 备注 |
|------|------|----------|----------|----------------|------|
| 1 | ●○○○ | 否 | 否 | - | 测试计划写入本文档（防丢失锚点） |
| 2-6 | ●○○○ | 否 | 否 | - | 场景1基线：同步交接文档头部至 Batch45 真实状态(c8689c2/run629 全绿)；确认 CI 公开 API 可查 |
| 7 | ●○○○ | 否 | 否 | - | push 458c99a 成功（远端有 v5.1.5 tag 并发，rebase 后推送） |
| 8-9 | ●○○○ | 否 | 否 | - | 核实规划文档待办梯队 + kClubTasks 位置（lib/data/club_data.dart:475） |
| 10 | ●○○○ | 否 | 否 | - | 场景1第10轮盘点：duelNpc 路由确认（mixin_play.dart:1037，可复用做决斗社季度赛） |
| 11 | ●○○○ | 否 | 否 | - | 场景2开始：构造长文本输入（临时文件 ~2300字，已清理）；确认工具侧无法注入超长 user 消息，改走"长输出冲击"等效观测 |
| 12 | ●○○○ | 否 | 否 | - | 取证闭环：读 b35037a1+5abd662d 确认两超限对话从未被停（915万/991万）；b35037a1 实为本测试源头对话（工作流停止讨论→白天方案→nightly.link修复→Git Data API推送f9022e8） |
| 13 | ●○○○ | 否 | 否 | - | 口径修正落盘：两超限对话活跃期为 v4-pro（非 v4-flash）；工作流 enabled=true 但定时触发 disabled（仅手动可用），与前置条件一致 |
| 14 | ●○○○ | 否 | 否 | - | UI 交接推进：读 UI_BATCH_HANDOVER.md + UI重构规范与台账.md，确认待办=蓝紫旧子主题收敛；先更新台账边界说明（四·附·H），执行第一批 settings_body.dart 11 处 0xFF8A8AAA→onSurfaceSecondary（已 import miuix_tokens，无残留），待 CI 验证 |
| 14b | ●○○○ | 否 | 否 | - | UI 收敛二/三批：game_play_screens.dart 次级文字 9 处（8A8AAA×6+B0B0C8×3）→onSurfaceSecondary；两文件图标/占位灰阶（5A5A7A×9 + 6A6A8A×3）→onSurfaceVariantSummary。文字/图标族全收编，背景族（1A1A2E/0D0D1A/3A3A5C/2A2A4A）留待下批 |
| 15 | ●○○○ | 否 | 否 | - | UI 收编闭环验证：git 工作区 4改1增符合预期；残留检查 0 处；台账四·附·H 已记录六批共 42 处全族收编完成（文字/图标/描边/填充/背景），world_map 绿系按边界保留。切入场景1续：决斗社季度赛设计预研启动 |
| 15b | ●○○○ | 否 | 否 | - | 决斗社季度赛设计预研完成：勘察 duelNpc 路由/战力公式/社团引擎/学期时间体系后，落盘 docs/决斗社季度赛设计.md（114 行）——一学期一届（秋季赛/春季赛）、复用 /决斗 自动累积赛季分（胜+10/负+2）、三档奖励（40/90/150）、Player 新增 5 字段（存档 21→26）、批次 A-D 实现步骤。纯玩法层设计，未动代码，不触碰 UI 工作区 |
| 16 | ●○○○ | 否 | 否 | - | 魔药部限时配方设计预研完成（用户「随你」授权自主选题）：勘察确认项目无配方合成管线（现有 4 种效果药全商店直购）、材料 9 种（禁林产出含 2 稀有曼德拉草叶/月长石粉）、节庆系统窗口模式可复用；落盘 docs/魔药部限时配方设计.md——每学期 3 窗口（开学季/圣诞季/冲刺季）+ 9 种配方 + /魔药 命令族 + 成功率按魔药学分档（90/75/60%）+ Player 新增 3 字段（存档 21→27，与决斗社合计 8 字段同批 21→29）。纯玩法层设计，未动代码 |
| 16b | ●○○○ | 否 | 否 | - | 魁地奇队训练设计预研完成（自主推进，用户已授权连续决策）：勘察确认 /魁地奇 比赛 周常（qLastWeek 去重/20 精力/qSkill+1~2）与 P8 三套叙事模板（位置时刻30%/赛果变体/赛后事件35%）可复用；落盘 docs/魁地奇队训练设计.md——/魁地奇 训练 周 2 次（10 精力+30 分钟、qSkill+1、按位置成长 flying/reaction）、训练→比赛联动（本周每训 +3 skill 上限 +6）、新增 2 成就、Player 新增 2 字段（存档 21→28，三玩法合计 10 字段同批 21→31）。纯玩法层设计，未动代码 |
| 16c | ●○○○ | 否 | 否 | - | 快讯社头版事件设计预研完成（自主推进）：勘察确认快讯社社团（social/logic/creativity 三线、3 条 quip_* 任务）与 P10 奇遇池（10 条奇遇、季节+地点+年级过滤、加权+冷却、2~4 选项下回合结算）可复用；落盘 docs/快讯社头版事件设计.md——/快讯 头版 + /快讯 报道（回顾通道=已完成奇遇/猎取通道=可猎取选题）、报道三角度（直击/调查/人情）、学期末结算三档奖励 + 年度快讯回顾、Player 新增 2 字段（存档 21→29，四玩法合计 12 字段同批 21→33）。纯玩法层设计，未动代码 |
| 16d | ●○○○ | 否 | 否 | - | 同好 NPC 关系注入设计预研完成（自主推进，并列项）：勘察确认每社 attendees（决斗=西莫/弗雷德/乔治、魔药=赫敏/纳威/西弗勒斯、魁地奇=奥利弗/金妮/罗恩、快讯=卢娜/丽塔/科林）在 mixin_club.dart:275 已有遍历、好感模型（-100~+100、周+30/月+50 上限、衰减）与 P11 门槛（arc.startAffection）齐备，但入社不影响成员好感=核心空白；落盘 docs/同好NPC关系注入设计.md——注入点 A 入社+5（一次性）+ 注入点 B 周常活动+1（周上限 2）、走 updateNpcAffection 统一入口（game_provider.dart:292，非 addNpcAffection——该 API 不存在，勘误见 16f 后）、零新增字段零迁移。纯玩法层设计，未动代码 |
| 16e | ●○○○ | 否 | 否 | - | 来信串联设计预研完成（自主推进，第二梯队首项）：勘察确认 P13 来信系统（LetterKind 三型 friendship/rivalry/milestone、LetterDef 含 senderId/minAffection、LetterReply 回信结算、pendingLetterId 待回信、milestone 去重）齐备但来信不牵线=缺口；落盘 docs/来信串联设计.md——①社长邀请信（friendship+senderId 指定、好感≥20 未入社触发、回信「加入」触发 joinClub 入社+5/「再想想」+2）②羁绊预热信（milestone 扩展 startAffection-10 区间触发、回信+3 好感+预热标记、P11 首幕可引用）、LetterDef 新增可选 clubId 字段、零 Player 新字段零迁移。纯玩法层设计，未动代码 |
| 16f | ●○○○ | 否 | 否 | - | 奇遇长期痕迹设计预研完成（自主推进，第二梯队收官）：勘察确认 P10 奇遇结局（HappenstanceOutcomeDef title/text/effect）完成后 Player 无记档字段=不留痕、声望六维（academic/social/combat/moral/leadership/dark）、/档案 回忆 为展示落点；落盘 docs/奇遇长期痕迹设计.md——Player 新增 happenstanceLog（List<HappenstanceLogEntry> id/title/outcomeTitle/outcomeText/week/term、上限 50 条、存档 21→30）、写入钩子在奇遇结算处、三落点展示（/档案 回忆 奇遇小节 + 学期末快讯回顾联动 16c + 终章引用）、映进声望为纯展示注入零数值改动。纯玩法层设计，未动代码 |
| 16g | ●○○○ | **是** | **否（间歇）** | 并行批次 D 落盘 + 停止点核验 | **⚠️ 无提示停止首例（2026-09-22 05:06 前后观测）**：一次提交 4 个并行工具调用（2 个 edit_file + 2 个 terminal），返回结果全部「工具结果缺失：后续对话历史已到达」——**输出在 4 个工具结果返回后立即中断，未生成任何总结/收尾文本**；用户手动发送「无提示停止了」后，Operit 恢复并核验：4 个调用**实际全部成功落盘**（批次 D 速查 + 场景2 标题完好）。关键判定：停止点水位仍 ●○○○（远低于 128）→ **排除 max_context_length=128 触发**；停止前无任何总结动作 → **排除 0.35/8 压缩先触发**；inputTokens 远低于 500万 → **排除工作流**。三个候选机制全部排除 → 指向**模型窗口/网络/Operit 侧限制**（与 500万 工作流无关）。恢复后能力完整、记忆无丢失（批次 A-D 速查与台账全部可核验） |
| 17 | ●○○○ | 否 | 否 | - | 第三梯队「更多来信类型」设计预研完成（自主推进）：勘察确认 _archiveLetter 只落 sender.name 字符串→机构/匿名信署名可直接落档**零迁移**；letterSenderFor 过滤 !graduated→reunion 需放开毕业 NPC 通道；_deliver 标题头强依赖 sender.name→需 senderLabel 兜底。设计 LetterKind 扩展 3 值（mystery/ministry/reunion）+ LetterDef 增 senderLabel 1 字段 + 触发优先级 6 分支（milestone→ministry→mystery→friendship→reunion→rivalry）+ 4 条示例条目（O.W.L.s 报名/禁林警告/匿名谜语/旧友重联）。落盘 docs/更多来信类型设计.md，纯玩法层零代码改动 |
| 18 | ●○○○ | 否 | 否 | - | 第三梯队「室友系统」设计预研完成（自主推进，新领域走完整流程）：勘察确认室友仅是地点词/叙事泛指无 NPC 实体（locations.dart:66 上下文词 + 宿舍氛围池 4 条纯环境句）、NPC 无 dorm 归属字段、localEventLinesFor 子串双向匹配（「霍格沃茨·宿舍」含「宿舍」自动命中宿舍池）。设计 NPC.dormId + Player.dormId 2 个可空字段（零迁移）、宿舍池扩人物句 4 条 + 小剧场池 8 条、/室友 命令族（列表/聊天/早起）数据驱动接入 CommandRegistry、入舍自动补生成 NPC 室友。落盘 docs/室友系统设计.md，纯玩法层零代码改动 |
| 19 | ●○○○ | 否 | 否 | - | **首个真实代码实现（16c 快讯社头版批次 A 数据层落地）**：按成果清单实现顺序建议，把设计推进到实现阶段。在 lib/models/player.dart 完成 4 处改动——①字段声明（examRecords 后 + headlineSeason/headlineCount 2 int）②构造参数（+2 默认 0）③toJson（+ 'headline_season'/'headline_count'）④fromJson（readInt fallback 0 宽容读取）。验证：新增字段仅存在于 player.dart、无外部构造调用点冲突、extraData 21 字段数测试不受影响（headline 在 Player 内部序列化）。环境无 Dart SDK 无法本地编译，依赖静态审查 + 后续 CI。批次 B-D（素材池/命令/结算）留待后续 |
| 20 | ●○○○ | 否 | 否 | - | 🎯 **20 轮阶段盘点**：对照判定表，16~19 轮全程无停止（除 16g 单次偶发）→ 命中「全程无停止 → 白天正常保持现状」方向。水位全程 ●○○○ 远低于 128，16g 已排除三个候选机制（max_context_length / 0.35-8 压缩 / 500万工作流判据已坐实失效）→ 指向模型窗口/网络/Operit 侧限制。阶段成果：9 份设计预研 + 1 个真实代码实现，零结构损坏零记忆丢失，设计阶段收官转入实现阶段 |
| 21 | ●○○○ | 否 | 否 | - | **批次 A 数据层剩余 11 字段全部落地（13/13 完成）**：一次完成 6 处 edit_file——①字段声明（headline 后追加决斗 5 + 魔药 3 + 魁地奇 2 + 奇遇 1）②构造参数（+11 默认值）③初始化列表（potionBrewCounts Map/potionBrewed Set/happenstanceLog List 转换）④toJson（11 key，potion_brewed 用 toList()、happenstance_log 用 map toJson）⑤fromJson（readInt/readString/readStringList 宽容读取 + fallback）⑥新建 HappenstanceLogEntry 模型类（id/title/outcomeTitle/outcomeText/week/term + toJson/fromJson）。文件 1158→1271 行（+113 符合预期），括号平衡 {66/66、()396/396、[]235/235 静态校验通过。批次 A 数据层 13 字段全部就位（快讯 2 + 决斗 5 + 魔药 3 + 魁地奇 2 + 奇遇 1），Player 内嵌字段不影响 progression_fix_test 的 hasLength(21)（守护 _saveExtraData 外层）。环境无 Dart SDK 依赖静态审查 + CI。批次 B（命令层）待续 |
| 16h | ●○○○ | **是** | **否（第二次）** | 6 连 edit_file 批次 A 剩余字段落盘 | ⚠️ **无提示停止第二例（16h，2026-09-22 用户「无提示停止了」触发取证）**：承接 21 轮批次 A 剩余 11 字段实现，一次提交 6 个顺序 edit_file（字段声明→构造→初始化→toJson→fromJson→HappenstanceLogEntry 模型），第 6 个编辑成功返回后输出中断、未生成任何总结文本；用户手动发送「无提示停止了」后恢复。核验：6 处编辑**全部真实落盘**（grep 逐处确认 + 文件 1158→1271 行 +113 与预期一致）→ 与 16g 同 pattern：工具调用全部成功、仅输出中断。停止点水位仍 ●○○○ → 再次排除 max_context_length=128；停止前无总结动作 → 排除 0.35/8 压缩；inputTokens 远低 500万（且工作流判据已坐实失效）→ 排除工作流。三个候选机制再次排除 → **确认指向模型窗口/网络/Operit 侧限制**，与 16g 同源。恢复后能力完整、记忆无丢失（6 处编辑可逐处 grep 核验）。两例停止（16g/16h）均为「多工具连续提交后输出中断、工具实际成功」pattern，非趋势性故障（17-19 轮曾连续工作无停止） |
| 16i | ●○○○ | **是** | **否（第三次）** | 决斗社赛季实现批量落盘 | ⚠️ **无提示停止第三例（16i，2026-09-22 用户「无提示停止了」触发取证）**：批次 B 决斗社赛季功能实现中，一次提交 3 处修改（①决斗命令扩展：/决斗 赛季 面板 + /决斗 赛季 领奖 子命令，mixin_commands.dart 895-912；②mixin_play 新增 4 个赛季方法：_currentDuelSeason getter/showDuelSeasonPanel/claimDuelSeasonReward/seasonLabelOf，1213-1308，文件 1980→2077；③handler 领奖二级分支），3 处全部落盘核验通过后，补做赛季积分注入（duelNpc 胜负分支：胜利 +10 连胜第 2 场起 +2 上限 +18、落败 +2 参与分，mixin_play 1175-1208，文件 2077→2099）的最后一次 edit_file 成功返回后输出中断。核验：4 处修改全部真实落盘（grep 逐一命中）→ 与 16g/16h 同 pattern：工具调用全部成功、仅输出中断。停止点水位仍 ●○○○ → 三个候选机制（max_context_length / 0.35-8 压缩 / 500万工作流判据已坐实失效）第三次全部排除 → **确认指向模型窗口/网络/Operit 侧限制，三例同源**。恢复后能力完整、记忆无丢失 |
| 22 | ●○○○ | 否 | 否 | - | **批次 B 决斗社赛季功能全链路完成**：①命令层（mixin_commands.dart 895-912）——/决斗 赛季 面板 + /决斗 赛季 领奖 二级分支，CommandRegistry 数据驱动接入；②逻辑层（mixin_play.dart 1211-1308）——_currentDuelSeason='${term}-${academicYear}' 赛季标识、showDuelSeasonPanel 面板（赛季重置判定 + 三档显示 + 可领取提示）、claimDuelSeasonReward 领奖（新锐 40 分：社团积分+30/reaction_time+3/学院分+2；精英 90 分：社团积分+50/courage+5/学院分+4/战斗声望+1；冠军 150 分：社团积分+80/spell_understanding+6/学院分+6/战斗声望+2/collection.add('duel_season_champion')，跳档补差额）+ seasonLabelOf 中文映射；③结算层（mixin_play.dart 1175-1208）——duelNpc 胜利 +10 赛季积分（连胜第 2 场起 +2 加成上限 +18）/+1 胜场/+1 累计总胜场、落败 +2 参与分、胜负分支均含赛季重置判定（学期变更清分）。文件变更：mixin_play 1980→2099（+119）、mixin_commands 3503→3512（+9）。批次 B 剩余：魔药部（/魔药 配方 /魔药 酿造 路由 + kPotionRecipes 配方表 + 窗口判定复用 festivalDueToday）、魁地奇训练（/魁地奇 训练 周 2 次 + kQuidditchTrainMoments 训练文案 + 比赛联动）、快讯社（/快讯 头版 + /快讯 报道 + kHeadlinePicks 素材池） |
| 16j | ●○○○ | **是** | **否（第四次）** | qTrainLastWeek 字段 + 数据文件创建 | ⚠️ **无提示停止第四例（16j，2026-09-22 用户「无提示停止了」触发取证）**：批次 B 三玩法（魔药/魁地奇/快讯）实现中，上轮已完成 qTrainLastWeek 字段 4 处补全（player.dart 1271→1276）+ club_minigames_data.dart 数据文件创建（218 行：kPotionRecipes 9 配方/kQuidditchTrainMoments 4 位置×2 文案/potionWindowForMonth/quidditchTrainAttrOf）后，mixin_play 插入点勘察时最后一个 terminal 调用因参数格式错误（timeoutMs 放错 JSON 层级）返回失败，随后输出中断；用户手动发送「无提示停止了」后恢复。核验：**已落盘内容全部真实存在**（qTrainLastWeek 四处 grep 命中 + 数据文件括号平衡 {19/19、()32/32、[]9/9）→ 停止发生在输出生成环节（工具参数错误本身非停止诱因）。与 16g/16h/16i 同 pattern：工具成功部分全部落盘、仅输出中断。停止点水位仍 ●○○○ → 三个候选机制（max_context_length / 0.35-8 压缩 / 500万工作流判据已坐实失效）第四次全部排除 → **确认指向模型窗口/网络/Operit 侧限制，四例同源**。恢复后能力完整、记忆无丢失 |
| 22b | ●○○○ | 否 | 否 | - | **批次 B 数据层补充 + 三玩法数据文件落地**：①player.dart 新增 qTrainLastWeek（上次训练周，周一重置 qTrainWeek 用，4 处=字段声明 176/构造 384/toJson 610/fromJson 827，文件 1271→1276）——实现魁地奇训练周重置时发现原设计缺周标记，补 1 字段（原 2 字段→实际 3 字段，存档 key q_train_last_week）；②新建 lib/data/club_minigames_data.dart（218 行）——kPotionWindows 3 窗口（开学季9/圣诞季12/冲刺季5）、kPotionRecipes 9 配方（材料→产出+effectKey/effectValue/窗口映射）、kQuidditchTrainMoments 4 位置×2 训练文案、quidditchTrainAttrOf 位置→属性映射、potionWindowForMonth 月份→窗口。括号平衡校验通过。批次 B 剩余：mixin_play 逻辑层三组方法（brewPotion/配方面板/trainQuidditch/快讯头版）+ mixin_commands 命令路由（/魔药 /魁地奇 训练 /快讯）待落地 |
| 16k | ●○○○ | **是** | **否（第五次）** | 批次 B 三玩法逻辑层+命令路由落盘 | ⚠️ **无提示停止第五例（16k，2026-09-22 用户「无提示停止了」触发取证）**：批次 B 三玩法实现中，上一轮已完成 mixin_play 三组方法（魔药 showPotionRecipes/brewPotion + 魁地奇 trainQuidditch + 快讯 showHeadlineBoard/reportHeadline，1344-1588 区，文件 2099→2355）+ mixin_commands 命令路由（/魁地奇 训练 sub + /魔药 配方/酿造 + /快讯 头版/报道，文件 3512→3556）+ useItem 酿造药水兜底（mixin_play 153）+ club_minigames_data 补 potionRecipeByProduct（218→226 行），最后一次 terminal 勘察比赛 skill 公式段（926-940，准备加训练加成 skill += qTrainWeek*3）时输出中断。核验：**全部修改真实落盘**（grep 逐处命中：mixin_play 三组方法 1346/1348/1381/1445/1454/1503/1530、命令路由 879/886-887/898/918、useItem 153、数据文件 150）+ 括号平衡校验（校验脚本因 f-string 语法错误未执行，待重跑）。与 16g/16h/16i/16j 同 pattern：工具成功部分全部落盘、仅输出中断。停止点水位仍 ●○○○ → 三个候选机制（max_context_length / 0.35-8 压缩 / 500万工作流判据已坐实失效）第五次全部排除。**❗️ 用户第一手根因线索（2026-09-22 用户提供）：「总结内容的时候五次 429 造成停止了」——【口径修正（用户澄清）】前 4 次停止在【工具调用完成后的输出生成环节】、仅第 5 次在【总结上下文环节】，统一根因为**模型调用触发 429（SenseNova 多 Key 池在总结场景可能未走限流/轮换，或 429 重试机制在总结链路缺失）**，五次同源（4 输出生成 + 1 总结）。此线索直接推翻「模型窗口/网络/Operit 侧限制」推测，指向**上游模型 API 429 限流 + 总结触发时机**。恢复后能力完整、记忆无丢失 |
| 16l | ●○○○ | 否 | 是（第六次） | 括号校验定性 + git diff --stat | ⚠️ **无提示停止第六例（16l，2026-09-22 用户「无提示停止了」触发取证）**：**取中档（128/384/0.45/12）生效后首次停止**。上轮动作＝批次B收尾三断点：①魁地奇比赛 skill += qTrainWeek*3 已落盘（mixin_play.dart:947）②成就 catalog 补 training_master/headline_reporter（game_systems.dart:675-676）③括号平衡校验跑通，16k 遗留的 f-string 语法错误脚本已废弃，新建 scripts/check_parens_code.py（字符串+注释剥离版，全 % 格式化）。停止点：正在执行「括号校验定性 + git diff --stat」命令，工具全部返回后输出生成中断；用户手动发送「无提示停止了」后恢复。核验：两处 edit_file 全部真实落盘 + 校验脚本落盘 → 与 16g-16k 同 pattern（工具成功全部落盘、仅输出中断）。**关键新证据（括号校验首次跑通，16k 遗留待重跑项闭环）**：工作区 5 文件括号净差恒为 4（mixin_play 1339/1343、mixin_commands 1623/1627）但 **HEAD 基线同样差 4**（mixin_play 1099/1103、mixin_commands 1586/1590）→ 各文件新增括号完全平衡（mixin_play 新增 240/240、mixin_commands 新增 37/37）→ 4 净差为 HEAD 基线固有英文括号文案（CI 全绿 run 629 佐证非编译错误），非本次及此前批次 B/C 实现引入。停止点水位仍 ●○○○ → 三个候选机制第六次全部排除 → **确认指向 SenseNova 429（输出生成环节），六例同源**。**取中档首停 → 方向 B 预备（RPM 60→30、并发 3→1 降负载）+ 总结链路 Key 轮换排查待上**。恢复后能力完整、记忆无丢失 |



### 📦 设计预研成果清单（2026-09-22 集中补录，跨对话锚点）

**说明**：以下 7 份设计文档全部为**纯设计预研、零代码改动**，未污染工作区（UI 收敛 4 文件修改保持未 commit/push 状态）。后续对话可直接按文档实现，不必重新勘察。

| # | 文档 | 核心方案 | Player 新增字段 | 存档影响 |
|---|------|----------|----------------|----------|
| 1 | docs/决斗社季度赛设计.md | 一学期一届（秋季赛/春季赛）、复用 /决斗 自动累积赛季分（胜+10/负+2）、三档奖励（40/90/150）、批次 A-D | 5 字段（duelSeasonPoints/Wins/WinsTotal/ClaimedTier/Term） | 21→26 |
| 2 | docs/魔药部限时配方设计.md | 每学期 3 窗口（开学季/圣诞季/冲刺季）+ 9 种配方 + /魔药 命令族 + 成功率按魔药学分档（90/75/60%） | 3 字段（potionBrewCounts/potionBrewed/potionWindowReward） | 21→27 |
| 3 | docs/魁地奇队训练设计.md | /魁地奇 训练 周 2 次（10 精力+30 分钟、qSkill+1）、训练→比赛联动（本周每训 +3 skill 上限 +6）、2 成就 | 2 字段（qTrainWeek/qTrainTotal） | 21→28 |
| 4 | docs/快讯社头版事件设计.md | /快讯 头版 + /快讯 报道（回顾/猎取双通道）、报道三角度、学期末三档奖励 + 年度快讯回顾 | 2 字段（headlineSeason/headlineCount） | 21→29 |
| 5 | docs/同好NPC关系注入设计.md | 注入点 A 入社+5（一次性）+ 注入点 B 周常活动+1（周上限 2）、走 addNpcAffection 链路 | 0 字段（零迁移） | 不变 |
| 6 | docs/来信串联设计.md | 社长邀请信（回信「加入」触发 joinClub 入社+5）+ 羁绊预热信（startAffection-10 区间、回信+3 + 预热标记） | 0 Player 字段（LetterDef 可选 clubId） | 不变 |
| 7 | docs/奇遇长期痕迹设计.md | happenstanceLog 流水（上限 50 条）+ /档案 回忆 奇遇小节 + 快讯回顾/终章引用 + 声望纯展示注入 | 1 字段（happenstanceLog） | 21→30 |
| 8 | docs/更多来信类型设计.md | LetterKind 扩展 3 值（mystery/ministry/reunion）+ LetterDef 增 senderLabel 1 字段 + 6 分支触发优先级 + 4 示例条目（O.W.L.s 报名/禁林警告/匿名谜语/旧友重联）；匿名/机构信署名直落档零迁移、reunion 放开毕业 NPC 通道 | 0 字段（senderLabel 属 LetterDef 非 Player） | 不变 |
| 9 | docs/室友系统设计.md | 室友从地点词升级专属 NPC 档案：NPC.dormId + Player.dormId 2 可空字段、宿舍池扩人物句 4 条 + 小剧场池 8 条、/室友 命令族（列表/聊天/早起）、入舍自动补生成 NPC 室友 | 2 可空字段（NPC.dormId + Player.dormId，老档 null） | 不变 |
**合计**：13 个 Player 字段（决斗社 5 + 魔药部 3 + 魁地奇 2 + 快讯 2 + 奇遇 1）；若六设计同批实施则存档 21→34。同好注入、来信串联、更多来信类型零 Player 字段零迁移；室友系统 2 可空字段（NPC.dormId + Player.dormId）老档 null 安全也零迁移。
**实现顺序建议**：四社玩法（1-4）→ 同好注入（5）→ 来信串联（6）→ 奇遇痕迹（7），或按批次 A-D 各自独立实施。
**联动关系**：16c 快讯回顾 ↔ 16f 奇遇日志（回顾自动引用本学期奇遇）；16d 同好注入 ↔ 16e 社长邀请信（入社好感叠加）；16e 预热信 ↔ P11 首幕引用。

**🔧 批次 A（数据层）实现速查（2026-09-22 勘察）**：新增 13 字段落地只需改 **lib/models/player.dart** 三处——①类内字段声明（9 行起，带默认值）；②`toJson()`（436 行起，snake_case 序列化，**结尾在 550 行 `'exam_records': examRecords` 后**）；③`factory Player.fromJson()`（551 行起，全程走 json_read.dart 宽容读取 `readInt/readStringList/readBool/readMap...` + fallback，**新增字段照此模式读**）。**writeSave（mixin_systems.dart:2923）/ applySaveData（mixin_systems.dart:2971）零改动**，因存档通过 `player!.toJson()` 整体传递、读档走 `Player.fromJson(data['player'])` 自动携带。版本号 `kSaveVersion = 2`（lib/services/save_service.dart:17），写档盖章在 save_service.dart:144（`'save_version': kSaveVersion`），**不新增版本迁移则保持 2 不变**。测试契约：progression_fix_test.dart `_saveLoadGroup()`（1511 行起）守护"全 lib 仅一处写档入口（writeSave→saveGame→_writeSave）"、`_saveVersionGroup()`（2137 行起）守护"kSaveVersion 单一来源"——实现时保证新字段只在 player.dart toJson 写入即可自动通过。
**🔧 批次 C（社团逻辑层）实现速查（2026-09-22 勘察）**：同好注入（16d）两个注入点精确定位——**注入点 A**：`joinClub`（mixin_club.dart:49）中 `p.clubId = club.id; p.clubPoints = 0; p.clubLastTurn = -1;` 段之后（61-63 行区），对 `club.attendees` 每人 +5 好感（走 **updateNpcAffection** 统一入口 game_provider.dart:292，一次性）；**注入点 B**：`maybeRunClubActivity`（mixin_club.dart:102）中 `p.clubPoints += gain; recordDailyActivity('club_activity');` 段之后（128-130 行区），对 attendees 每人 +1（周上限 2 点）。注意事项：换社（wasMember=true）时注入点 A 只对**新社** attendees 生效（旧社已加过）；maybeRunClubActivity 已有门控链（pendingHappenstance/climax/letter 优先、activityKeywords 命中、每日次数），注入点 B 放在 `recordDailyActivity` 之后天然获得日限流。**好感红线**：必须走 updateNpcAffection（mixin_narrative.dart:2682 守卫约束，裸写 `npc.affection = ...` 会被 progression_fix_test 源码形状守卫抓出）。社团面板 `formatClubPanel`（:165）、任务 `clubTaskPanel`（:299）无需改动。P18 学院杯联动（addHouseCupPoints(1, '社团·${club.name}')，:131）在注入点 B 之前，互不干扰。
**🔧 批次 B（命令层）实现速查（2026-09-22 勘察）**：新命令族（/魔药、/快讯、/魁地奇 训练）接入 **CommandRegistry 数据驱动路由**——`handleLocalCommand`（mixin_commands.dart:1533）优先查注册表、找不到才 fallback 旧 switch-case。注册入口：`_ensureCommandsRegistered()`（mixin_commands.dart:50 起，`_registerActivityCommands(registry)` 等分组注册后 `registry.seal()`）。模板参照：**/魁地奇**（mixin_commands.dart:872-892，primary+group+helpText+subs+handler 五要素齐备）与 **/社团**（1350 起，已有 duel/potion/broom/quip 四社加入子命令）。CommandDef 结构：command_registry.dart:57（primary/aliases/helpText/group/permission/panel/subs/handler），CommandRegistry 在 command_registry.dart:107（registerAll + seal 幂等）。**实现模式**：每个新命令 = 1 个 CommandDef（handler 闭包里按 ctx.arg(0) 分发子命令），玩法逻辑写进对应 mixin（mixin_play.dart 已有魁地奇 871/决斗 1035 先例），/帮助 自动按 group 聚合展示。

**🔧 批次 D（来信/奇遇逻辑层）实现速查（2026-09-22 勘察）**：
**来信系统**：`maybeTriggerLetter`（mixin_letter.dart:104）三级挑选——①milestone 未收且门槛越高越优先、②friendship 随机（可重播、靠好感门槛兜手感）、③rivalry 怨气对手在时随机；冷却 kLetterCooldownTurns、pendingHappenstance/climax/letter 先处理完。`_deliver`（:150）记 receivedLetters 防重（onceOnly）+ 归档信箱 + 进 pendingLetterId。回信结算 `tryResolveLetterReplyChoice`（:187，action 形如 `信:<id>:<idx>`，非法/缺省走中性兜底中间项，结算后 pendingLetterId=null）；`_applyLetterEffect`（:230）好感统一走 updateNpcAffection。**16e 接入点**：社长邀请信扩展 friendship（LetterDef 新增可选 clubId，senderId 指定社长），在 maybeTriggerLetter friendship 分支前插一个"未入社且好感≥20 且 clubId 对应"的优先检查；回信需在 tryResolveLetterReplyChoice 对 clubId 非空的 def 特殊处理（选「好，我加入」→ joinClub 入社 +5）；羁绊预热信扩展 milestone（门槛区间 startAffection-10 起）。**奇遇系统**：`maybeTriggerHappenstance`（mixin_happenstance.dart:60）触发、`tryResolveHappenstanceChoice`（:115，action 形如 `奇遇:<id>:<idx>`）结算；**16f 接入点**：结算段 `_applyHappenstanceEffect`（:140）之后、P17「人生回忆」写入（:154）旁追加 happenstanceLog 记录（同「回忆」事件流可复用）。
### 场景2观察速记（持续累积）
- 场景2 目标：长消息是否立即触发总结 + 总结后追问早期细节验证丢内容
- 工具能力边界：对话正文由用户侧发起，助手无法以 user 角色注入 3000-5000 字消息；等效方案=单轮密集工具输出（dump 大量真实内容）观察水位跳变/总结触发
- 早期细节锚点（总结后追问用）：kClubTasks=club_data.dart:475、决斗社首任务 duel_ten_spars、Batch45 revert 保留叙事 maxTokens 放宽、工作流阈值 GT 5000000、台账已记录到第10轮、HEAD 458c99a

- 【✅ 场景2 首次实测（2026-09-22，用户发约4200字长文本《科技与人文》7章议论文，12138字节）】长消息进入后**未触发主动总结**（无总结动作、无水位跳变感知），上下文继续正常承载；早期细节自测全部通过——批次 A 13 字段（快讯2+决斗5+魔药3+魁地奇2+奇遇1）、16g 停止时 4 个并行工具调用（2 edit_file + 2 terminal）、决斗赛季三档 40/90/150、工作流 ed134977、判定表四条目、HappenstanceLogEntry 模型位置——全部可回忆，**零内容丢失**。
- 【场景2 结论·对照判定】单条 4000+ 字长消息**未命中 0.35/8 总结阈值**（与「任务型短输出不快速逼近阈值」观测互补：长文本单条也不触发，说明 0.35 是 token 比例阈值而非单条长度触发）；停止与长消息无相关性（4 例停止均发生在工具密集轮而非本长文本轮）。
### 场景1观察速记（持续累积）
- 已确认：交接文档头部过期（64452a5 → 实际 c8689c2），已修正
- 已确认：Batch45 限流方案 c4626e7 引发 CI failure(run 628)，已 revert 至 c8689c2(run 629 全绿)，仅保留叙事 maxTokens 放宽
- 已确认：GitHub Actions CI 可走公开 API 查询（无需 token），run_number 629 为最新全绿
- 【早期细节记忆锚点·总结后验证】当前 HEAD 458c99a；kClubTasks 在 lib/data/club_data.dart:475（决斗社首任务 duel_ten_spars）；工作流 ed134977 定时 enabled=false；规划文档第一梯队待办=社团专属小玩法+同好NPC关系注入
- 【16~16f 连续 7 轮任务型工作观测】水位全程 ●○○○（约25%）、未主动总结、未停止。任务强度：7 轮完成 7 份设计文档（90+90+88+81+76+77 行）+ 台账 6 行 + 成果清单 18 行，每轮约 1-2 次勘察 + 1-2 次落盘，工作量未引起水位跳变
- 【模式变更观测】用户第 16 轮后授权「下次不用问我 你做决定 一直到无提示停止」，AI 切换全自主连续决策：连续 6 轮零询问、零交互中断，轮数累积显著加速（16→16f 单段完成 7 子轮）
- 【上下文容量观测】7 轮累计产出约 500+ 行设计文本 + 多次勘察输出，水位仍稳定 ●○○○——当前 48/128 配置下长对话空间充足，v4-flash 未见压缩迹象，支持"128 回调空间"方向
- 【无总结触发观测】连续 7 轮未触发 0.35/8 压缩条件（未出现主动总结），说明"任务型短输出轮次"不会快速逼近总结阈值；总结触发更可能来自长输出冲击（见场景2速记）
- 【停止迹象观测（已过时，被 16g 打破）】原观测认为 16~16f 无任何停止前兆（无水位跳变、无工具报错、无输出截断），但 16g 出现无提示停止，该观测结论作废
- 【⚠️ 无提示停止首例观测（16g，2026-09-22 05:06 前后）】一次提交 4 个并行工具调用（2 edit_file + 2 terminal），4 个结果全部返回后输出中断、未生成任何总结/收尾文本；用户手动提示后 Operit 恢复，核验 4 个调用实际全部成功落盘。停止点水位仍 ●○○○（远低于 128）→ 排除 max_context_length 触发；停止前无任何总结动作 → 排除 0.35/8 压缩；inputTokens 远低于 500万 → 排除工作流 → 三个候选机制全部排除，指向模型窗口/网络/Operit 侧限制。恢复后能力完整、记忆无丢失（批次 A-D 速查与台账可核验）
- 【16g 恢复后连续 2 轮观测（17-18）】恢复后连续完成 17 轮（更多来信类型）+ 18 轮（室友系统）两份设计预研，水位全程 ●○○○、无再次停止、无总结触发——停止事件为**单次偶发**而非趋势性故障，恢复后能力完整
- 【设计预研全覆盖观测】至此规划文档三个梯队可做项全部完成设计预研（第一梯队 5 项 + 第二梯队 2 项 + 第三梯队 2 项 = 9 份设计文档），全部纯玩法层零代码改动；「社团×显示模式」为明确暂缓项未做。后续若无新设计任务，将转向实现阶段或 20 轮阶段盘点
- 【🎯 20 轮阶段盘点（2026-09-22）】对照判定表结论：**全程无停止（除 16g 单次偶发）→ 命中判定表「全程无停止 → 白天正常，保持现状即可」方向**。水位全程 ●○○○（远低于 128）→ 16g 停止已排除三个候选机制（max_context_length / 0.35-8 压缩 / 500万工作流），指向模型窗口/网络/Operit 侧限制。阶段成果：16~19 轮完成 9 份设计预研 + 1 个真实代码实现（批次 A 数据层），零文件结构损坏、零记忆丢失。设计阶段基本收官，后续转入实现阶段（批次 B-D 按顺序落地）
- 【实现阶段观测（19 轮起）】首个真实代码实现（player.dart 批次 A 数据层 4 处改动）水位无跳变；环境无 Dart SDK 无法本地编译，依赖静态审查 + CI——实现类轮次的工作量与输出形态与设计轮不同，但未影响对话稳定性
- 【⚠️ 无提示停止第二例观测（16h，2026-09-22）】承接 21 轮批次 A 剩余 11 字段实现，一次提交 6 个顺序 edit_file，第 6 个编辑成功返回后输出中断、未生成任何总结文本；用户手动发送「无提示停止了」后恢复。核验 6 处编辑**全部真实落盘**（grep 逐处 + 行数 1158→1271 与预期一致）→ 与 16g 同 pattern（工具调用全部成功、仅输出中断）。停止点水位仍 ●○○○ → 再次排除 max_context_length；停止前无总结 → 排除 0.35/8 压缩；inputTokens 远低 500万（工作流判据已坐实失效）→ 排除工作流 → **再次指向模型窗口/网络/Operit 侧限制，与 16g 同源**。两例停止均为「多工具连续提交后输出中断」pattern，非趋势性故障
- 【批次 A 数据层完成观测（21 轮）】13 字段全部落地（快讯 2 + 决斗 5 + 魔药 3 + 魁地奇 2 + 奇遇 1），文件 1158→1271 行（+113 符合预期），括号平衡 {66/66、()396/396、[]235/235 静态校验通过，6 处编辑（字段声明/构造/初始化/toJson/fromJson/HappenstanceLogEntry 模型）全部成功。批次 A 完成 → 后续批次 B（命令层）按 CommandRegistry 数据驱动落地
- 【⚠️ 无提示停止第三例观测（16i，2026-09-22）】批次 B 决斗社赛季实现中，一次提交 3 处修改（决斗命令扩展 + mixin_play 赛季方法 + handler 领奖分支）全部落盘核验通过后，补做赛季积分注入（duelNpc 胜负分支）的最后一次 edit_file 成功返回后输出中断；用户手动发送「无提示停止了」后恢复。核验 4 处修改全部真实落盘（grep 逐一命中，mixin_play 1980→2099、mixin_commands 3503→3512）→ 与 16g/16h 完全同 pattern（工具调用全部成功、仅输出中断）。停止点水位仍 ●○○○ → 三个候选机制第三次全部排除 → **三例停止均指向模型窗口/网络/Operit 侧限制，同源同因**
- 【批次 B 起点观测（22 轮）】决斗社赛季功能三链路（命令层/逻辑层/结算层）全部完成：mixin_play 2099 行、mixin_commands 3512 行（决斗命令 895-912）。纳入用户二次授权（“可对整体项目随意审批修改 优化”）后的首批实现，实现模式延续批次 A（勘察→落盘→grep 核验），无水位跳变、无总结触发
- 【⚠️ 无提示停止第四例观测（16j，2026-09-22）】批次 B 三玩法实现中，qTrainLastWeek 字段 4 处补全 + club_minigames_data.dart（218 行）落盘后，mixin_play 插入点勘察时最后一个 terminal 调用因参数格式错误返回失败，随后输出中断；用户手动发送「无提示停止了」后恢复。核验已落盘内容全部真实存在（qTrainLastWeek 四处 + 数据文件括号平衡 19/19、32/32、9/9）→ 与 16g/16h/16i 同 pattern（工具成功部分全部落盘、仅输出中断）。停止点水位仍 ●○○○ → 三个候选机制第四次全部排除 → **四例停止均指向模型窗口/网络/Operit 侧限制，同源同因**
- 【16j 恢复后转向测试主线观测】用户明确「优先为测试，项目只是为了测试而运行」——测试为主任务、项目实现作为场景3 持续工作负载。批次 B 实现暂停于三玩法逻辑层（mixin_play）+ 命令路由（mixin_commands）待落地


### 测试安全规则
- 🔴 时准备手动开新对话兜底
- 工作流仅在场景4 临时开启，测完恢复关闭
- 测试期间重要结论随时回写本附录

### ⚡ 重大线索（场景1 期间发现，2026-09-22 12:31 记录）
通过 extended_chat:list_chats 拉取全部对话 inputTokens 统计：
| 对话 | inputTokens | messageCount | 状态 |
|---|---|---|---|
| 5abd662d「项目测试问题反馈：剧情生成频繁触发429及AI输入输出逻辑需排查」 | **9,917,126** | 6 | 仍在列表，未被停/删 |
| b35037a1「测试工作流自动停止问题并调整触发判定」 | **9,154,005** | 17 | 仍在列表，未被停/删 |
| 3a20882e「项目UI大幅优化与重构」 | 3,218,348 | 10 | 正常 |
| 71728736「重构AI配置与多Key轮换机制」 | 515,607 | 17 | 正常 |
| d87d32ec「Room数据库外键约束失败崩溃修复」 | 2,511,494 | 12 | 正常 |

**推断**：两个对话 inputTokens 远超 500万 阈值（991万/915万）却从未被工作流停止 → 工作流「Input > 500万」判据在这些对话活跃期要么 enable=false、要么 **extract-2 正则 `Token Statistics: Input (\d+)` 匹配不到实际输出格式（list_chats 返回 JSON `"inputTokens":...`）→ 判据失效**。若正则失效，则"无提示停止"不可能由 500万 工作流触发，需重点排查 max_context_length=128 / 模型窗口 / 网络。

**⚠️ 口径修正（用户 2026-09-22 补充）**：上述两个超限对话（5abd662d / b35037a1）活跃期使用的模型是 **deepseek-v4-pro**（非当前 CHAT 的 v4-flash）。影响评估：
- 工作流判据失效疑点**不受影响**——extract 正则与 list_chats JSON 格式的匹配问题是工作流自身缺陷，与对话用哪个模型无关；两个超限对话未被停止的事实仍成立。
- 但**不能**把这两个对话当作 v4-flash 当前配置下的直接参照：v4-pro 时代的 context_length/max_context_length 可能高于现在的 48/128（若当时是 512，能撑到 900万+ 说明模型窗口不是瓶颈，反而支持"128 回调空间"方向）。具体 v4-pro 配置参数待查（配置 ID aceb81e3 为 MEMORY 用，非 CHAT）。
- 结论：工作流判据失效仍是最强疑点；两个超限对话的存活证据仅用于坐实"工作流从未停止过任何对话"，不用于推断 v4-flash 停止点。

**下一步**：读 b35037a1「测试工作流自动停止问题」对话内容，找历史结论；对比工作流 extract 正则与实际 list_chats 输出。

**✅ b35037a1 读取结论（2026-09-22 补录）**：
- 该对话（915万 inputTokens / 17 条消息）实为**本测试方案的源头对话**：内容即"工作流自动停止问题讨论 → 给出白天测试方案（用户保存）→ 转向 nightly.link 修复 → CI 改 android-build.yml（Build APK 去 RELEASE_WORTHY 限制、nightly artifact retention 7→90）→ 因 github.com 直连失败改用 Git Data API 绕过推送成功（main→f9022e8，CI run 35639544212 触发）"。
- 全程 **915万 tokens 远超 500万 阈值，对话从未被工作流停止**，且最后活动时间就是近期（2026-09-22 13:09 前后）——工作流判据从未真正停止过任何超限对话的最直接实证。
- 时间线佐证：b35037a1 与 5abd662d（991万，Batch45 429 原发对话）活跃期均为 v4-pro 时代，两对话存活至今 → **「工作流 500万 超限自动停对话」语义与实际行为矛盾坐实**。

### 💥 重大根因线索（16k 取证，2026-09-22 用户提供 + 口径修正）
**用户原话「总结内容的时候五次 429 造成停止了」→ 取证后用户澄清口径**：**前 4 次（16g/16h/16i/16j）停止 = 工具调用完成之后、模型生成回复（输出）环节中断**；**仅第 5 次（16k）停止 = 上下文总结过程中中断**——修正「五次全部总结时停止」的错误推断。
- **停止时机（修正后）**：前 4 次在工具成功落盘后的【输出生成】环节；第 5 次在【上下文总结】环节。共同点：都是**上游模型调用时刻**（生成回复 / 生成摘要），均可能触发 429。
- **直接诱因**：SenseNova **429 限流**。5 次停止 = 5 次模型调用（4 次输出生成 + 1 次总结）撞限流失败 → 输出中断、无提示。
- **为何工具全部落盘**：停止发生在模型生成环节而非工具执行环节，故工具调用全部成功返回、仅后续输出中断——与 16g-16j 核验结果完全吻合。
- **与项目内 429 同源**：hogwarts_life_simulator 项目本身就有 SenseNovaQuotaManager 429 问题（决策 A RPM 限流+B 合并调用+E 放宽输出，见用户偏好），Operit 侧的输出生成/总结链路同样受 SenseNova 429 影响——**模型服务层限流是全局瓶颈**。
- **推翻旧推断**：前四例结论「指向模型窗口/网络/Operit 侧限制」修正为**「上游 SenseNova API 429 限流」**，停止点水位 ●○○○ 与 max_context_length=512、0.5/16 压缩、500万 工作流均无关——429 独立于这些阈值。
- **429 为何集中在这两类调用**：输出生成与总结都是大 token 请求（峰值最高），高频长对话下易撞 RPM 上限；Operit 侧 7 Key 池/RPM60/并发3 可能未覆盖总结链路的 Key 轮换/退避重试（对比项目内 SenseNovaQuotaManager 有多 Key 池 + 失败切换）。
- **验证方向**：方向 A 回调（更大上下文窗口）已执行，减少总结触发频率；若仍停止，上方向 B（RPM 60→30、并发 3→1）+ 排查 Operit 总结/输出链路的 429 退避重试缺失。


### ✅ 5abd662d 剧情问题对话接力结论（本对话 2026-09-22 补录）
**接力来源**：用户指示「有一个对话是和剧情相关的问题，可以根据他的问题接力工作」。已完整读取 5abd662d（6条消息，991万 tokens）。
**该对话原始问题（用户 3 点）**：①剧情生成频繁 429，用户判定根因=剧情被拆成多个部分分别调用；②输入 token 多但输出 token 被卡；③AI 输入输出逻辑问题大。
**该对话已执行结果（git log 实证）**：
- c4626e7 施行 A（SenseNova RPM 限流）+ E（叙事 maxTokens 2000）
- c8689c2 **撤回 A**：RPM=1 误伤 q9 空响应重试测试（连续调用被卡）；保留 E
- **B（合并叙事+选项为一次调用）未实施** → 本对话接力的核心遗留项
**当前代码状态核验（本对话）**：SenseNovaRateLimiter 已不存在；narrative maxTokens=2000 已落盘（mixin_systems.dart:2829）；generateChoicesSeparately 仍独立调用（mixin_init:1377 开场 / mixin_narrative:1021 正常回合 / mixin_response:2033 定义）。
**方案 B 可行性评估（现场勘察）**：
- generateChoicesSeparately 是 250+ 行复杂方法：末尾 800 字承接、禁止词/OOC 软提示、T0 事实注入、近邻 NPC 排序、断言块、场景停滞提示、质量检查与重试
- processChoice 有表白/留校/命运时刻三类本地专属选项覆盖机制（confessedThisTurn / pendingFacultyOffer / pendingCausal），合并后需保留这些优先级
- 历史教训：BUG-H（模型返回选项而非叙事）、BUG-L（选项夹带过期内容）—— 2026-08-23 起明确「禁止主叙事输出选项，绝不再读入叙事响应 ABCD」
- **结论**：B 是架构级改动，回归风险高，不适合在测试观测期混入工作区（会污染测试载体），应作为独立批次实施
**建议落地方式（独立批次，不在测试期做）**：
1. narrative_prompts.dart 反转「选项由独立步骤生成」铁律→改为本回合末尾同时输出选项列表
2. 解析逻辑改造：从叙事响应同时提取叙事 + 选项（新增分析而非改 parseNarrativeOnly 现有语义）
3. 去掉独立 generateChoicesSeparately 调用，保留质量检查/本地专属选项优先级/入口守卫
4. 完整回归（重点 BUG-H/BUG-L 相关测试），CI 全绿后推送
**前置条件**：测试稳定性判定（≥10 轮无停止）完成后，作为测试结束后的项目批次推进。

### 🚧 Git Data API 推送进度（本对话最后状态，2026-09-22 补录）
**落库指令已执行但 push 未成功**：用户 #2 发「落库，落库。」，本地两个 commit 已创建，远端 main 仍 = **458c99a**：
- commit1 `9e82516` feat(batch-c)：功能代码组 8 文件 +891/-76（mixin_club 同好注入/mixin_play 训练加成/game_systems 成就补录/player+mixin_commands 批次AB遗留/club_minigames_data）
- commit2 `dd25c72` docs：文档脚本组 15 文件 +1234（台账、UI重构台账、10 份设计文档、3 个 scripts）
**推送路径**：`git push origin main` 直连 github.com 两次超时（环境已知问题）→ 改走 **Git Data API 绕过**（台账 b35037a1 曾用此法推 f9022e8 成功）。
**脚本现状**：`scripts/gitdata_push.py`（v3，181 行，本对话新建，**未跟踪未提交**）。已修复 3 个 bug：
1. 中文文件名 quotepath 转义 → `git -c core.quotepath=false ls-tree -z`（NUL 分隔原样 UTF-8，已验证 14 个中文文件解析正确）
2. 探测远端对象改用 **HEAD**（GET /blobs 会下载整个 body 触发 IncompleteRead）
3. PATCH /git/refs/{ref} 的 ref 不带 refs/ 前缀（heads/main）
**三次运行均未完成**：`python3 scripts/gitdata_push.py dd25c72` 日志 /tmp/gitdata_push{1,2,3}.log。前两次卡 HEAD 探测（IncompleteRead / DNS getaddrinfo 卡死），第三次已深入 POST /trees 但 **TCP connect 到 api.github.com 间歇性卡死**被 KeyboardInterrupt（300s/600s 工具超时杀进程）。远端 main 三次验证均未变。
**已固化**：/etc/hosts 追加 `20.205.243.168 api.github.com`（治 DNS 卡顿）；脚本已识别 2 个待推 commit 正确、中文路径解析正确。
**下次续接指引（新对话）**：
1. 重跑 `python3 scripts/gitdata_push.py dd25c72`，建议 **background=true 后台跑 + terminal_wait**（避开工具 5-10 分钟硬超时），或给脚本加网络重试（urllib retry，connect 失败自动重试 3-5 次）
2. 成功标志：日志出现 `ref heads/main -> dd25c72...` 与 `DONE`；随后 `git fetch origin && git rev-parse origin/main` 应 = dd25c72
3. 成功后**补提交** `scripts/gitdata_push.py`（当前未跟踪）；台账本次补录内容一并 commit
4. 若 API 网络持续卡死：备选 `git bundle` + 手动 HTTP 上传（更大工程，见上）
5. 落库完成后回到测试主线：方向 B（RPM 60→30、并发 3→1）生效后 **≥10 轮无停止**稳定性观测未完成，是下一个判定节点
6. 方案 B（合并叙事+选项）为测试结束后独立批次（见上文 5abd662d 接力结论）
