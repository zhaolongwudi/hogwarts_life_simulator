# 霍格沃兹人生模拟器 · 第九轮全面审查报告

> 审查日期：2026-09-01
> 审查基线：`main` @ `aad0d64`（v3.6.2）
> 审查方式：对照《框架.md》逐条核对 + 三路并行深度审查（架构/内容/测试工程）+ 逐项人工复验 + 实机验证
> 验证环境：Flutter 3.35.0 / Dart 3.9（沙箱内全新搭建）

---

## 一、审查结论总览

| 维度 | 结论 |
|---|---|
| 代码规模 | `lib/` 130+ 文件、约 5.54 万行 Dart；`test/` 41 文件、1254 项测试 |
| 架构 | mixin 组合模式正确但已触顶（450 行上帝接口 + 16000 行上帝实现） |
| 指令覆盖率 | 框架 7.x+8.x 共 69 条指令，代码注册 58 个主命令，**真缺失 11 条（84%）** |
| CG 系统 | 框架 36 个 CG **全部存在**，编号/名称/星级 100% 对齐 |
| 数值规则 | 好感/声望/恋爱惩罚等核心表**与框架逐字一致**，但有 1 处执行层与提示词层冲突（±10 压缩） |
| 测试健康 | 1254 项全绿，但核心 mixin **零功能测试**（14 个 mixin 仅 1 个被 import） |
| 工程风险 | CI 存在**版本先发后验证**（版本膨胀根因）与 **auto-unzip 任意代码直推 main**（安全） |
| 本轮修复 | **10 项缺陷已修复**（4 崩溃级 + 4 玩法失效 + 2 资源/健壮性），analyze 0 error，**1258 项测试全绿** |

---

## 二、本轮已修复（10 项，已提交）

提交：`fix: 第九轮全面审查修复 10 项缺陷——崩溃/玩法失效/资源泄漏/读档静默失败`

| # | 级别 | 位置 | 问题 | 修复 |
|---|---|---|---|---|
| S1 | 🔴 崩溃 | `mixin_narrative.dart` 离线模式 | 事件文本 <10 字时 `substring(0, length.clamp(10,40))` 抛 RangeError，离线模式整回合崩溃（已用 Dart 实机复现） | 提取 `narrativeEventProbe()` 纯函数 + 4 项回归测试 |
| S4 | 🟠 玩法失效 | `mixin_commands.dart` `/计划 学习` | `p.attributes[k] ?? 50 + v` 因 `+` 优先级高于 `??`，属性已存在时加成**被整体丢弃**，学习计划永不涨属性 | 改为 `(p.attributes[k] ?? 50) + v` 再 clamp |
| S5 | 🟠 玩法失效 | `mixin_commands.dart` `/新NPC` | `/新NPC [全名]` 被 `int.tryParse` 失败默认**生成 1 位新 NPC**（查档案变副作用，还消耗学年配额） | 对齐框架 7.7：无参=列表、名字=档案、仅显式「生成/数字」才生成 |
| M1a | 🟠 冻结 | `mixin_commands.dart` `/cheat 时间` | 天数无上限，`/cheat 时间 999999` 主线程冻结 | 夹到 `min(abs, 365)` |
| M6 | 🟠 玩法失效 | `mixin_response.dart` 分院识别 | 正则硬编码「凌天的/凌天」，玩家自定义姓名后分院信号命中率下降、成就/CG 延迟 | 用 `player.name` + `RegExp.escape` 动态拼接主语锚点 |
| M8 | 🟠 竞态 | `mixin_systems.dart` callDeepSeek | 判空后存在重建间隙，请求在飞时重置游戏 → `router!` 抛空异常 | 局部引用 + 二次判空 |
| S3 | 🟡 泄漏 | `game_provider`/`ai_router`/`deepseek_service` | 切换 API Key 时旧 Dio（HttpClient 连接池 + socket）从不 close，全仓 0 处 `dio.close` | 新增 `DeepSeekService.close()` + `AiRouter.dispose()`，`updateClient` 重建前释放 |
| M3 | 🟡 健壮性 | `mixin_systems.dart` loadFromSave | 存档损坏**静默 return**，UI 无反馈；applySaveData 中途异常留下半截状态 | try/catch + `error` 反馈 |
| M2 | 🟡 崩溃 | `npc_chat_screen.dart` | `_loadHistory().then` 后 setState 无 mounted 保护 → setState after dispose | 加 `if (!mounted) return;` |
| M7 | 🟡 崩溃 | `save_load_screen.dart` | pop 后复用同一 context pushReplacementNamed（deactivated context） | 直接 pushReplacementNamed |

**另加固**：`GameProvider` 新增 `WidgetsBindingObserver`，应用退后台（paused/detached/inactive）时提前存档，修复 dispose 里异步存档无人 await、进程回收可能丢最后一回合的问题（S2）。

---

## 三、审查发现 · 遗留问题（未修，按优先级）

### P0 · 建议下一轮优先处理

| # | 位置 | 问题 | 建议 |
|---|---|---|---|
| 1 | `.github/workflows/auto-unzip.yml` | **任意 URL 拉 zip 直推 main，可覆盖 `.github/workflows/` 本身劫持 CI 与 GITHUB_TOKEN**（zip-slip 未过滤、无校验、无 PR） | 删除该 workflow；如必须保留则限定分支 + 校验 checksum + 走 PR |
| 2 | `balance_constants.dart:74` `compressAffectionDelta` | **AI 被教的规则与代码执行的规则是两套**：写入 prompt 的 `affectionChangeRules` 仍写着「生死与共 +20~+30 / 背叛 -15~-30」，但落地被压缩到 ±10；AI 写 +25 实际只有 +10 | 同步两处：要么把极端事件上限提到 ±30 只对极端放行，要么改 prompt 表 |
| 3 | `mixin_systems.dart:2024 fastForwardTime` vs `:462 fastForwardDays` | 两套时间推进实现分叉：`/计划 *` 与 `/cheat 时间` 走的 `fastForwardTime` 不刷新 NPC 位置、不推进孕期、不累计学院杯对手分、锚点按默认 dayDelta 匹配 | `fastForwardTime` 委托 `fastForwardDays`，收敛为单一实现 |
| 4 | `analysis_options.yaml` 不存在且被 `.gitignore:134` 排除 | `flutter analyze` 门禁只等于「能编译」，无任何 lint；`flutter_lints` 是死依赖 | 删 `.gitignore:134` + 补 `analysis_options.yaml`（先开 error 级） |

### P1 · 工程与安全

| # | 位置 | 问题 | 建议 |
|---|---|---|---|
| 5 | `android-build.yml:46-96` | **版本 bump + CHANGELOG sync + push 发生在 analyze/test 之前**——测试失败也已发版（一天 3.4.2→3.6.6 的直接机制） | bump/sync/push 移到 job 末尾 + `if: success()` |
| 6 | `android-build.yml:3-5` | 三个 workflow 均无 `pull_request` 触发，合入 main 才第一次验证 | 新增 PR 触发 analyze+test job |
| 7 | `mixin_systems.dart:2603` 外 / `test/` | 14 个核心 mixin 只有 `mixin_response` 被测试 import，`processChoice`/60+ 指令/时间推进/死亡判定**零功能测试** | 优先补 `mixin_systems`/`mixin_response`/`mixin_commands` 功能测试 |
| 8 | `mixin_systems.dart:2719` | dispose 里的 saveNow 已加固（本轮），但 `crash_logger.dart` 每回合 2~4 次同步写盘 | 合并到回合末一次 |
| 9 | `mixin_response_affection.dart:329` | `catch (e) {}` 空吞，连真实错误一起吞 | 至少 debugPrint |
| 10 | `game_narrative_tab.dart:52/61` | UI 偏好存 `static` 可变字段，跨实例存活 | 迁 SharedPreferences |

### P2 · 内容与体验（框架差距）

| # | 框架条目 | 现状 | 建议 |
|---|---|---|---|
| 11 | 7.1 `/时间 快进`、`/时间 日程` | `/时间` 忽略参数；玩家侧「今日日程」面板不存在 | 参数路由 + 日程面板（数据已在） |
| 12 | 7.2 `/恋爱 历史`、7.5 `/档案 回忆`、`/收藏 [物品名]` | 无恋爱史数据结构；无回忆模式；收藏无单品详情 | 三块都是「数据已有、缺入口/面板」 |
| 13 | 7.8 `/联动 状态` | 代码自承「文案许诺的联动内容并不存在」，面板是空壳 | 要么实现 17.1 联动矩阵的状态化，要么改文案 |
| 14 | 第四部分 NPC 名录 | **伏地魔无 NPC 实体**（三个时代核心反派）；对角巷/霍格莫德 6 位店主（奥利凡德/摩金/罗斯默塔等）全部缺席 | 补实体 NPC，承接魔杖购买/宠物购买场景 |
| 15 | 法则五 · 世界自治 | `death_data.dart` 自承「`NPC.isAlive` 永远为 true，全项目无处置 false」 | 死亡系统落地（战斗致死/剧情生死） |
| 16 | 14.3 新 NPC 档案 | `NpcSeed` 缺「背景故事」「日常日程」字段；宠物表 5 条仅一句描述 | 扩充数据（注意 `spell_system_test` 的「收藏品可达性」契约） |
| 17 | 11.2 数值 | 拉郎配 `_shipStageFor` 用 60/65/70/75/80/90 六档，与玩家侧十一档两套标尺 | 统一映射 |

---

## 四、框架合规性盘点（对照《框架.md》）

| 系统 | 覆盖 | 亮点 / 缺口 |
|---|---|---|
| 四大时代 | ✅ | `event_anchors.dart` 67 条五维过滤事件锚点，按时代换教授（1892 魔药课是斯拉格霍恩） |
| 魔杖系统 | ✅ | 10 根魔杖 + 杖芯修正真实进决斗公式（`wandCoreCastBonus`） |
| 好感度系统 | ✅ | 11 档/变化区间/好感锁/时间沉淀**逐字一致**；缺口见 P0-2（±10 压缩） |
| 声望系统 | ✅ | 6 维度 + 6 等级 + 恋爱声望 5 档完全一致 |
| 表白系统 | ✅ | 好感≥85 + 暧昧≥2 周 + 浪漫事件≥2 全部落地，另加概率模型（扩展） |
| 新 NPC 生成 | ✅ | 每学年 60% 概率 + 限 4 次防刷；三代血亲限制 + 骨科模式 |
| CG 系统 | ✅ 100% | 36 个 CG 全部存在；条件表分裂 19/36（13 处硬编码在 mixin），建议收口 |
| 指令系统 | 🟡 84% | 真缺失 11 条（见 P2-11~13）；另有 32 条正向扩展（魁地奇/决斗/婚育链等） |
| 初始设定 13 轮 | ✅ | 与框架第十九部分一致 |
| 十二层自检 | ✅ | 压缩进 13 行 prompt 注入，实测生效 |
| 课堂/宠物/信件/收藏 | ✅ | 都有可交互动作层；宠物与开场场景文案偏薄 |

---

## 五、架构评分与健康度

**做得好的（保持项，别动）：**
1. `ai_router.dart` —— 单 Key 熔断 + 双 CancelToken + 超时预算参数同源推导，全仓最扎实
2. `deepseek_service.dart` —— HTML 拦截页归一化为可重试异常，三路径共用断言
3. `save_service.dart` —— 写串行化 + 原子 rename + 备份回滚，移动端存档该有的样子
4. `mixin_response.dart` 的「解析与落库副作用分离」——重试驳回不污染状态
5. `world_state.dart`/`npc.dart` fromJson 全字段兜底 + 老档语义注释

**要警惕的：**
- `game_provider_base.dart` 已膨胀为 450+ 行抽象接口 + 各 mixin 摊平的命名空间（方法撞名需别名导入）
- 单回合 10+ 次 `notifyListeners()` × 全仓 33 处 `context.watch<GameProvider>()`、0 处 `context.select` —— 每次全树重建
- `game_narrative_tab.dart:1601` 在 `build()` 里做副作用（postFrameCallback 链式 setState）
- `test/progression_fix_test.dart` 的 O(n²) 文件读取是测试 2 分钟耗时主因

---

## 六、验证记录

| 项 | 结果 |
|---|---|
| `flutter analyze` | **0 error**（5 个历史 warning，非本轮引入） |
| `flutter test` | **1258 项全部通过**（原 1254 + 新增 4 项回归） |
| 崩溃复现 | S1 短文本 RangeError 已用 Dart 实机复现确认，修复后验证通过 |
| 修复范围 | 10 个文件修改 + 1 个新测试文件，`pubspec.lock` 未动 |

---

## 七、下一轮建议路线（按性价比排序）

1. **删 `auto-unzip.yml`**（10 分钟，堵住 CI 劫持风险）
2. **CI 顺序修复**：bump/push 移到测试后（根治版本膨胀）
3. **`fastForwardTime` 委托 `fastForwardDays`**（时间系统单一实现）
4. **补核心 mixin 功能测试**（用 FakeProvider 降低构造成本，重点 mixin_systems）
5. **补伏地魔 + 对角巷店主 NPC 实体**（三个时代的剧情闭环）
6. **CG 条件表收口**（36 条单一维护点）
7. **/时间 快进 参数路由 + 今日日程面板**（框架 7.1 补齐）
