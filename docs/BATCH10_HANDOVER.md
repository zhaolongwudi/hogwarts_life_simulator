# 任务交接文档 - 当前 Batch 45 状态 + 历史回顾
## 当前状态（HEAD: c8689c2，已全量 push，CI 全绿 run 629）
**Batch 45 · SenseNova 429 限流治理（✅ 已回退，保留叙事 maxTokens 放宽）：**
- `c4626e7` `fix(batch45): SenseNova补每分钟限流治429 + 叙事maxTokens放宽防截断重试`：新增 lib/services/rate_limiter.dart（71 行）+ lib/mixins/mixin_init.dart 接入 + deepseek_service 每分钟限流；lib/mixins/mixin_systems.dart 叙事 maxTokens 放宽；test/batch45_sensenova_rpm_test.dart（67 行）→ CI run 628 ❌ failure
- `c8689c2` `revert: 撤回SenseNova RPM限流 保留叙事maxTokens2000`：删除 rate_limiter.dart 全部 71 行 + mixin_init 接入行 + deepseek_service 限流 4 行 + batch45 测试 67 行；保留 mixin_systems 叙事 maxTokens 放宽 → CI run 629 ✅ success
- **结论**：SenseNova 每分钟限流方案实测引发回归失败，已整体回退；只保留「叙事 maxTokens 放宽防截断」的正面收益。429 问题后续如需再治，改走「多 Key 轮换 + 熔断」而非新增限流器。

---
## 历史状态（Batch 44 完成 + Batch 11 回顾）
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

### 场景1观察速记（持续累积）
- 已确认：交接文档头部过期（64452a5 → 实际 c8689c2），已修正
- 已确认：Batch45 限流方案 c4626e7 引发 CI failure(run 628)，已 revert 至 c8689c2(run 629 全绿)，仅保留叙事 maxTokens 放宽
- 已确认：GitHub Actions CI 可走公开 API 查询（无需 token），run_number 629 为最新全绿

### 测试安全规则
- 🔴 时准备手动开新对话兜底
- 工作流仅在场景4 临时开启，测完恢复关闭
- 测试期间重要结论随时回写本附录
