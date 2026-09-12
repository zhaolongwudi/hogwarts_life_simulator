# AI 服务层适配现状调研 — 商汤日日新（SenseNova）· Agnes · DeepSeek

> **调研目的**：在启动第 4 轮修复前，把 AI 服务层对「免费模型约束（SenseNova 1500/500 次每 5 小时、Agnes 20 RPM）+ 单机玩家体验」的适配现状摸清，作为后续修复的依据。
> **方法**：静态代码审读（`lib/services`、`lib/providers`、`lib/mixins` 调用链、`lib/screens/settings`），全部结论附 `文件:行` 证据；无实测数据处明确标注为估算。
> **日期**：2026-09-09 | **基线版本**：v4.2.6
> **结论速览**：适配工程化程度高（超时单一来源、熔断、预算公式、空响应归一、降级链闭环均为亮点）；免费配额在单机自用强度下余量充足（估算百小时级）；真正的适配瓶颈集中在三处——空响应重试浪费约 30% 配额、SenseNova 慢响应下的等待体验（最坏 ~3 分钟无取消）、配额信息对玩家不可见。

---

## 1. 提供商适配总览

| 提供商 | 定位（tagline） | 默认模型 | Base URL | 免费约束 | 默认场景 | 证据 |
|---|---|---|---|---|---|---|
| DeepSeek | 付费 · 高质量长文本 | `deepseek-v4-flash` | `https://api.deepseek.com` | 按量计费，无闸门 | 不进默认路由与回退 | `provider_defaults.dart:50-62` |
| Agnes | 免费 · 响应最快 | `agnes-2.5-flash` | `https://api.agnes-ai.cn` | 20 RPM/Key，本地闸门 18 RPM | npcChat | `provider_defaults.dart:63-74`、`rate_limiter.dart:24` |
| SenseNova（商汤日日新） | 免费 · 剧情质量最佳 | `sensenova-6.8-flash-lite` | `https://token.sensenova.cn` | 1500 次/5h（sensenova-*）/ 500 次/5h（托管模型） | narrative / summary / choice | `provider_defaults.dart:75-87`、`rate_limiter.dart:84-88` |

默认路由与回退顺序定义在 `ai_router.dart:22-28` 的 `AiRouterConfig`：narrative/summary/choice → SenseNova，npcChat → Agnes，fallback `[sensenova, agnes]`；玩家可在设置页按场景覆盖（`app_provider.dart:441-448` `setSceneRoute`）。

---

## 2. 分层适配细节

### 2.1 配置层：单一来源收敛

`lib/data/provider_defaults.dart` 是全部出厂默认值的唯一来源（模型、端点、展示名、tagline）。文件头注释记录了此前该数据散落 6 处、互相打架的历史（Agnes 出厂模型界面与请求侧不一致、SenseNova 界面 6.7 与 fallback 6.8 不一致），现已收敛（`provider_defaults.dart:1-18`）。

玩家可覆盖项（`app_provider.dart`）：每提供商自定义模型（450-457）、自定义 Base URL（存 `_baseUrls`）、多 API Key（505-519 批量写入安全存储）；冷启动 Key 读取已做并行化（CS1，`app_provider.dart:270-297` 两轮 `Future.wait`）。

SenseNova 的端点适配有一个细节：`normalizeBaseUrl`（`deepseek_service.dart:107-116`）会剥掉 URL 末尾的 `/v1`，因为 `chatPath` 默认已以 `/v1/` 开头（`provider_defaults.dart:43`），避免拼成 `/v1/v1/chat/completions` 404。

### 2.2 请求层：DeepSeekService

| 适配点 | 现状 | 证据 |
|---|---|---|
| 请求体 | `model / messages(system+user) / temperature / max_tokens / stream:false` | `deepseek_service.dart:176-190` |
| 连接超时 | 15s | `deepseek_service.dart:86` |
| 接收超时 | perCall（SenseNova 50s / 其余 35s）+ 10s 缓冲，**与路由层同源**（F48） | `ai_timeouts.dart:31-52`、`deepseek_service.dart:70-71` |
| 非 JSON 响应 | `_decodePayload` 归一为可重试异常（服务商免费额度下常见 HTML/WAF 页，避免 NoSuchMethodError 把整个 Key 弃用）；`chatComplete` 与 `checkConnection` 共用 | `deepseek_service.dart:124-140` |
| 空响应 | 归一为可重试（「AI 返回了空响应，请重试」），不放大为 Key 失效 | `deepseek_service.dart:206-209` |
| 错误分型 | 401/403 认证 → 不可重试；404 端点 → 不可重试；429 限流 → 可重试；超时 → 可重试且标记 `isTimeout`（路由层据此直接换 Key 不重试）；4xx 其余 → 不可重试；5xx/网络 → 可重试 | `deepseek_service.dart:222-254` |
| 测试连接 | `checkConnection` 独立文案：超时/连不上/401/404（含最终请求路径）/429/400（含模型名不匹配提示）/5xx | `deepseek_service.dart:257-316` |
| 余额查询 | DeepSeek 有 `/user/balance` 解析；Agnes 与 SenseNova 返回 null（SenseNova 公测无公开余额 API，注释指引控制台） | `deepseek_service.dart:318-347` |
| 连接释放 | `close()` 关闭 Dio 连接池，路由重建前调用（防 Key 切换泄漏 socket） | `deepseek_service.dart:91-102`、`ai_router.dart:173-186` |

### 2.3 路由层：AiRouter

| 适配点 | 现状 | 证据 |
|---|---|---|
| 多 Key 轮询 | 轮询起始索引 + 环状遍历全部 Key，流量均匀 | `ai_router.dart:369-374` |
| 单 Key 熔断 | 连续 3 失败 → 冷却 60s → 半开试探（窗口过后放一次，成功清零） | `ai_router.dart:56-57, 191-209` |
| 同 Key 重试 | **0 次**（刻意）。注释论证：重试会把单 Key 最坏耗时从 50s 拉到 156s，全局超时（summary 上限 60s）容不下，坏 Key 会吃光全部预算 | `ai_router.dart:79-93, 356-359` |
| 预算公式 | `perKeyBudgetFor(keyCount) = 50s×keyCount + 5s`，与 `globalTimeoutFor` 同一参数，两者不再漂移 | `ai_router.dart:130-137` |
| 全局超时 | 按「实际会尝试的 Key 数」动态算；floor：narrative 60s / choice 50s / 其余 35s；ceil：narrative 120s / choice 100s / 其余 60s | `ai_router.dart:148-165` |
| 取消转发 | 整条链一个共享 CancelToken + `_CancelBridge` 单向转发到当前单次请求，防全局超时后请求继续后台跑 | `ai_router.dart:256-268, 540-562` |
| 缓存 | 5 分钟 TTL / 50 条 LRU；键 = systemPrompt+prompt+temperature+maxTokens+**provider+model**（换模型不命中旧输出）；narrative/choice 不缓存，summary/npcChat 缓存 | `rate_limiter.dart:128-217`、`ai_router.dart:264` |
| 终态文案 | 无 Key →「尚未配置任何 AI 服务」；全部熔断 →「全部 N 个 Key 都在熔断冷却中（60 秒后自动恢复）」——两条方向相反的错误被区分开 | `ai_router.dart:526-530` |

### 2.4 限流与配额层：rate_limiter

| 适配点 | 现状 | 证据 |
|---|---|---|
| 闸门接入 | 两个闸门此前完全没接进请求路径（注释记录），现统一在 `DeepSeekService._acquireSlot()` 发请求前调用 | `rate_limiter.dart:12-18, 148-165` |
| 等待超时 | 30s，且**必须小于** per-call 最短 35s——防止排队还没排到就被外层掐断、错误报成「AI 请求超时」（历史 P2-1） | `rate_limiter.dart:3-10` |
| Agnes | 每 Key 独立 18 RPM 桶（留 2 余量），精确睡眠到窗口滑出时刻（非固定轮询） | `rate_limiter.dart:20-67` |
| SenseNova | 5 小时窗口，按模型独立计量：sensenova-* 1500 次 / deepseek-v4-flash、glm-5.2 500 次（约 1.67 次/分钟） | `rate_limiter.dart:74-120` |
| 已知缺口 | 计数为**内存态**：`reset()`（新开局 `resetAllState` 调用）与 App 重启都会清零，与服务商侧 5h 窗口脱节（Q1）；等待超时抛的是普通 `Exception`，被 `chatComplete` 兜底包成「AI 响应解析失败」（Q7） | `rate_limiter.dart:122-124`、`deepseek_service.dart:216-218` |

### 2.5 业务调用层：callDeepSeek（GameProvider）

| 适配点 | 现状 | 证据 |
|---|---|---|
| maxTokens 场景化 | narrative 2000 / choice 500 / summary 3000 / npcChat 500 | `mixin_systems.dart:2717-2727` |
| 长线自动降 Token | 累计 totalTokens >50k → ×0.8；>100k → ×0.6 | `mixin_systems.dart:2728-2733` |
| systemPrompt | narrative/npcChat 用完整世界观 prompt，且按玩家状态哈希（姓名/学院/年级/灵性/精力）缓存，状态变化才重建；choice/summary 用固定简短 system（选项设计员/剧情摘要员） | `mixin_systems.dart:2693-2716` |
| temperature | 固定 0.85 | `mixin_systems.dart:2738` |
| Token 统计 | try-catch 保护，统计失败不影响游戏；累计次数/输入/输出 token 持久化进存档（`_saveExtraData`） | `mixin_systems.dart:2741-2752, 2764-2774` |
| 生命周期 | 双重 null 检查（router 在 await 间隙被重置时防空指针，BUG-FIX） | `mixin_systems.dart:2687-2692` |

### 2.6 业务降级链：四场景闭环

| 场景 | 降级链 | 玩家反馈 | 证据 |
|---|---|---|---|
| narrative | AI → parse 校验 → 强化指令重试（最多 2 次，解析出选项的 BUG-H 也重试）→ 本地兜底叙事 `generateFallbackNarrative`（4 框架 × 8 事件种子 + 信息密度自动增强） | 通知 | `mixin_narrative.dart:665-810`、`mixin_response.dart:936-967` |
| choice | AI 生成 → 质量检查（≥2 条合格）→ 带完整剧情上下文重试 1 次 → `buildFallbackChoices` 按地点承接式兜底补齐 4 条 | 通知（⏱️ 选项生成较慢…） | `mixin_response.dart:1866-1901, 1982-2008` |
| summary | 每 15 回合或缓冲 >6000 字触发（缓冲上限 8000）；失败回缓冲下次重试；输出硬截断 limit×1.2 | 静默（仅 debugLog） | `mixin_narrative.dart:1395-1455` |
| npcChat | AI → 本地模板（4 学院 × 3 条 + 教职工 3 条，按消息哈希选）；历史裁剪 20 条/3000 字符，持久化 50 条 | 返回 offline 标记 | `npc_chat_service.dart` |
| 完全离线 | `offlineQuickMode` 全离线路径：turnCount/摘要/停滞检测/密度增强与 AI 路径对齐 | 设置页开关 | `app_provider.dart:165-167, 530-538` |

### 2.7 玩家 UI 层：设置页适配

| 适配点 | 现状 | 证据 |
|---|---|---|
| Key 管理 | 每提供商多 Key 输入/保存/删除；无 Key 时提示「填入 API Key 并点击保存后…多个 Key 可提升并发上限（每个 Key 独立 20 RPM）」 | `settings_provider_card.dart:596-614` |
| 模型选择 | 「🎁 免费额度」+「⭐ 推荐付费」分组 chips（预设高亮局部刷新），点击填入编辑框；**chip 只显示模型名，无配额数字** | `settings_provider_card.dart:148-234`、`app_provider.dart:460-488` |
| 测试连接 | 调用 `checkConnection`，错误按分型给出可操作文案（含最终请求路径） | `settings_provider_card.dart`、`deepseek_service.dart:257-316` |
| 场景路由 | 4 场景 × 3 提供商独立配置 + 每场景 token 预估说明 | `settings_scene_routing.dart` |
| Token 统计 | 累计 API 调用次数 / 输入 / 输出 token（**累计视角，非配额视角**） | `settings_token_usage.dart:77` |
| 离线模式 | 开关 + 双向说明文案（「已开启…不调用 AI」/「未开启…额度耗尽仍自动切本地兜底」） | `settings_body.dart:468-473` |
| **配额信息缺位** | SenseNova 的 1500/500 次/5h **只存在于代码注释**（`app_provider.dart:467-473`、`provider_defaults.dart:80-84`），全 UI 无展示 → 玩家无法预判托管模型（500 次/5h）的天花板 | 核对 `lib/screens` 全目录无「1500/500/配额」文案 |

---

## 3. 免费约束下的适配结论

### 3.1 配额预算测算（估算，标注假设）

| 场景 | 单次调用输入 | 输出 | 频率假设 | 5h 窗口消耗 |
|---|---|---|---|---|
| narrative | systemPrompt + 剧情 prompt ≈ 2500-5000 token（估算） | 600-800 字 ≈ 1000-1600 token | ~8 次/游戏小时（设置页预估口径） | 8×5=40 次 |
| choice | 剧情上下文重试 1 次时翻倍 | ≤500 token | 选项不足 3 个时触发，低频 | <10 次 |
| summary | 历史摘要全量 + 6000-8000 字缓冲（长线局随局龄增长） | ≤3000 token | 每 15 回合 | ~2-4 次/小时 |
| npcChat | 20 条历史 + 消息 ≈ 1500-3000 token | ≤500 token | 2-4 次/小时 | ~15 次 |

**结论**：默认路由下 SenseNova 承担约 10-15 次/小时的调用，1500 次/5h 窗口可覆盖约 **100-150 游戏小时**；Agnes 承担 npcChat，18 RPM 闸门对小时级频率余量极大。单机自用强度下**配额次数不是瓶颈**。实际瓶颈是：

1. **空响应重试浪费**：SenseNova 偶发空响应（代码注释记录「10 次请求里 3 次」），业务层对空响应/解析失败重试 2 次且每次都完整生成 → 有效调用率约 70%，约 30% 配额被空响应白吃（v4 台账 Q9，Medium）。
2. **慢响应等待体验**：SenseNova per-call 50s、narrative 单 Key 全局超时 60s（floor）；业务层重试 2 次 = 最坏 3 个完整调用链 ≈ 180s+，UI 无取消入口（v4 台账 Q5，Medium）。
3. **托管模型误选风险**：deepseek-v4-flash / glm-5.2 在 SenseNova 通道仅 500 次/5h（~1.67 次/分钟），UI 无配额标注，误选后主剧情几回合即触发限流，体验像「AI 坏了」（v4 台账 Q12，Low）。

### 3.2 适配成熟度评估

| 层 | 成熟度 | 说明 |
|---|---|---|
| 配置层 | 高 | 出厂默认值单一来源；玩家覆盖项完整；Key 读取并行化 |
| 请求层 | 高 | 畸形响应/空响应归一、错误分型、测试连接独立文案、连接池释放 |
| 路由层 | 高 | 轮询+熔断+预算公式一致、缓存键覆盖生成者身份、取消转发 |
| 限流配额层 | 中 | 闸门接入正确、等待超时关系正确；但内存态（重启失忆）与异常文案误导待修 |
| 业务调用层 | 高 | maxTokens 场景化+长线降额、systemPrompt 缓存、token 统计容错 |
| 降级链 | 高 | 四场景闭环、离线路径对齐、无 Key/全熔断文案区分 |
| 玩家 UI 层 | 中 | Key/模型/路由/统计齐全；**配额信息完全不可见**是最大缺口 |

---

## 4. 已知问题索引（承接 v4 审查台账 17 条）

| Q# | 问题 | 层级 | 严重度 |
|---|---|---|---|
| Q5 | 叙事重试 2 次最坏等待 ~3 分钟且无取消入口 | 业务调用/UI | Medium |
| Q9 | 空响应重试 ×3 配额消耗，有效调用率约 70% | 请求/业务 | Medium |
| Q7 | 本地限流/配额等待超时被误标「AI 响应解析失败」 | 请求层 | Low |
| Q12 | SenseNova 配额数字（1500/500）全 UI 无展示 | UI 层 | Low |
| Q1 | 配额本地计数内存态，重启/重置后与服务商窗口脱节 | 限流层 | Low |
| Q15 | 调试日志完整 prompt 落盘，单日超限覆写丢数据 | 诊断 | Low |
| 其余 11 条 | 见 v4 报告台账 | — | Low/Info |

完整台账、逐条证据与处置建议见《comprehensive-review-v4-ai-free-model-2026-09-09.md》。

---

## 5. 适配决策记录（为什么这样设计）

以下决策是历次审查收口的结果，改动前须先读注释，避免回退到已修复的故障模式：

1. **路由层同 Key 重试 = 0**：一旦允许重试，单 Key 最坏耗时超出全局超时上限，坏 Key 会吃光预算、熔断记不满（历史 P1-D 复发）。
2. **超时单一来源 `ai_timeouts.dart`**：路由层与 Dio 层此前各维护一对常量，「网关慢」与「请求挂死」日志无法区分；现在结构上保证 Dio receiveTimeout 恒晚于路由层 per-call 超时。
3. **限流闸门只在 `_acquireSlot` 一处接入**：避免同一 Key 被两道互不知情的闸门串着等。
4. **缓存键含 provider+model**：换模型 5 分钟 TTL 内不命中旧输出；缓存读写下沉到每个 Key（不同 Key 可配不同模型）。
5. **空响应与畸形响应归一为可重试**：免费模型下高频偶发，不该被放大成「Key 失效」触发熔断弃用。
6. **每 Key 独立限流/配额桶**：多 Key 配置互不挤占，且各按自身模型计量（6.8/6.7 交替可翻倍额度）。

---

## 附录 · 证据索引

| 文件 | 关键行 | 内容 |
|---|---|---|
| `lib/data/provider_defaults.dart` | 49-93 | 三家出厂默认值唯一来源 |
| `lib/providers/app_provider.dart` | 186-232, 441-538 | 场景路由/模型/Key/离线开关/调试日志 |
| `lib/services/deepseek_service.dart` | 59-254, 257-347 | 请求构造/错误分型/测试连接/余额 |
| `lib/services/ai_router.dart` | 13-42, 130-165, 226-531 | 场景映射/预算公式/熔断/缓存/取消 |
| `lib/services/ai_timeouts.dart` | 1-52 | 超时策略单一来源 |
| `lib/services/rate_limiter.dart` | 1-125, 128-217 | Agnes RPM/SenseNova 配额/响应缓存 |
| `lib/mixins/mixin_systems.dart` | 2683-2753 | callDeepSeek 场景参数/token 统计 |
| `lib/mixins/mixin_narrative.dart` | 665-810, 1395-1455 | 叙事重试/兜底/摘要触发 |
| `lib/mixins/mixin_response.dart` | 936-967, 1866-2008 | 本地兜底叙事/选项重试与兜底 |
| `lib/screens/settings/settings_provider_card.dart` | 148-234, 596-618 | 模型预设/Key 提示（无配额标注） |
| `lib/screens/settings/settings_body.dart` | 468-473 | 离线模式文案 |
| `lib/screens/settings/settings_token_usage.dart` | 77 | 累计 Token 统计 |

---

> AI 服务层适配现状调研 · Hogwarts Life Simulator © 2026 | 调研日期：2026-09-09 | 基线 v4.2.6
> 结论均基于静态代码审读，预算测算为估算（已标注假设），未做真机实测。
