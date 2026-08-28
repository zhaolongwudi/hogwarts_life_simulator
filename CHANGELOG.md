# 更新日志

所有版本变更记录都在这里。日常小修小补、analyze 报错修复不单独列出。
新条目由 CI（`scripts/sync_changelog.sh`）在每次 `main` 分支推送时自动追加到顶部。

---

### v2.6.5 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.6.4 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.6.3 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.6.2 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.6.1 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.6.0 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.9 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.8 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.7 — 2026-08-28

**📋 变更说明**
refactor: 血统标签四份手写副本收敛为一份；补上缺失的「幽灵」译名

- 新增 lib/data/blood_status.dart：标签 / 问卷可选项 / 问卷说明 / NPC 别称 的唯一权威
- mixin_systems.bloodStatusLabel 改为转发
- intro_screen 删掉 _bloodLabels/_bloodOptions/_bloodDescriptions
- mixin_systems._bloodLabel（NPC 侧 switch）删除，改用 npcBloodStatusLabel
- 修 bug：npc_data 里宾斯教授的 bloodStatus 是 'ghost'，标签表里没有，

### v2.5.6 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.5 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.4 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.3 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.2 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.1 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.5.0 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.4.9 — 2026-08-28

**📋 变更说明**
merge: 合并远端最新改动

### v2.4.8 — 2026-08-28

**📋 变更说明**
merge: 合并远端 v2.4.7 changelog

### v2.4.7 — 2026-08-28

**📋 变更说明**
merge: 合并远端 v2.4.6 changelog

### v2.4.6 — 2026-08-28

**📋 变更说明**
merge: 合并远端 v2.4.5 changelog

### v2.4.5 — 2026-08-28

**📋 变更说明**
merge: 合并远端 v2.4.4 changelog

### v2.4.4 — 2026-08-28

**📋 变更说明**
ui: 手机页消灭死点击 + 地图标记防重叠，附 6 例布局测试

手机页（game_phone_tab.dart）
- 音乐播放器卡片包 Material+InkWell，标签由「游戏原声」改为「尚未上线」，
  不再骗玩家这里能点
- 「应用商店」改为统一的「敬请期待」提示，不再静默无响应
- 「平行世界小剧场」接上 ParallelWorldScreen，此前点了没反应

### v2.4.3 — 2026-08-28

**📋 变更说明**
fix: 添加 win32 依赖覆盖解决 Dart SDK 兼容性问题

win32 5.2.0 使用已移除的 UnmodifiableUint8ListView 类型，
添加 dependency_overrides 强制使用 >=5.3.0 版本。

### v2.4.2 — 2026-08-28

**📋 变更说明**
修复 flutter analyze 报告的16个问题

- 添加 foundation.dart 导入修复 mixin_narrative_continuity.dart 中3处 debugPrint 未定义
- 修复 mixin_response.dart 中10处静态方法调用，添加 GameResponseChoiceMixin 前缀
- 调整 game_provider.dart 中 GameNarrativeContinuityMixin 在 GameNarrativeMixin 之前
- 清理2处未使用的 import

### v2.4.1 — 2026-08-28

**📋 变更说明**
fix: 修复缺失 import / 乱码 / const 构造问题

- 添加 5 个缺失的 import（mixin 间依赖、CrashLogger、debugPrint、GameResponseChoiceMixin）
- 清除 mixin_response.dart 中残留的 1154→ 行号前缀
- StagnationDetector._() 私有构造 → StagnationDetector.instance
- 清理 mixin_narrative_continuity.dart 的 6 个 unused import

### v2.4.0 — 2026-08-28

**📋 变更说明**
fix: 修复代码拆分后跨文件引用错误

- 添加 mixin on 子句依赖（GameNarrativeMixin→GameNarrativeContinuityMixin,
  GameResponseMixin→GameResponseChoiceMixin+GameResponseAffectionMixin）
- 私有方法改为公开(_buildOpenLoopsStagnationHint/_extractChoicesFromRawText等)
- _TransitionNode 改为公开 TransitionNode 类
- 添加缺失的 import（stagnation_detector, story_text_renderer）

### v2.3.9 — 2026-08-28

**📋 变更说明**
refactor: 拆分大文件 + 清理调试日志 + CI 优化

大文件拆分：
- mixin_response.dart: 146KB→66.6KB，提取选项处理/好感度解析到独立 mixin
- mixin_narrative.dart: 112KB→59.8KB，提取连续性/断言到独立 mixin
- 提取 AffectionValidator/StagnationDetector 到 utils/

### v2.3.8 — 2026-08-28

**📋 变更说明**
docs: 优化项目首页介绍 — 更新日志版本至v2.3.6，精简结构，更新玩法说明

- 更新日志从过时的v1.x更新为v2.1.0~v2.3.6最近15个版本
- 特色/玩法部分重组为更紧凑的格式，提升可读性
- 补充多API Key支持等新功能说明

### v2.3.7 — 2026-08-28

**📋 变更说明**
fix: 移除_looksLikeNarrationWord方法后注入的65KB乱码字符串，修复CI analyze失败

根本原因：上一次编辑操作中结束大括号后误入了65KB的"并不是"乱码字符串，
导致 flutter analyze 解析到该处时出现语法错误，GitHub Actions 构建失败。

验证：所有 lib/ 下 .dart 文件花括号平衡，无乱码残留。

### v2.3.6 — 2026-08-28

**📋 变更说明**
fix: BUG-N 选项被NPC名过滤规则过度拦截，导致UI显示的选项与AI生成的不一致

根本原因：_choiceMentionsUnintroducedNpc 第4步无条件丢弃所有不在白名单、
不像是叙述词、也不是注册NPC的2-4字中文词，导致"仔细观察""周围环境"
"寻找线索"等常见选项用词被误判为"疑似捏造陌生NPC"而过滤掉。

修复方案：

### v2.3.5 — 2026-08-28

**📋 变更说明**
更新 ai_log

### v2.3.4 — 2026-08-28

**📋 变更说明**
fix: CI分析错误 - game_settings_tab中maxRecentTurns改用GameProviderBase.maxRecentTurns完整限定名，Text移除const

### v2.3.3 — 2026-08-28

**📋 变更说明**
feat: 多API Key策略 - Agnes按Key独立20 RPM限流 + 商汤按模型独立配额计量 + 设置页可折叠多Key配置

核心变更：
1. AppProvider: _apiKeys改为Map<String, List<String>>，支持多Key存储/读取/删除
2. KeyStore: 新增readKeys/writeKeys/addKey/removeKeyAt多Key持久化
3. AiRouter: 支持多Key注册 + 轮询选择 + 同提供商内Key级Fallback
4. AgnesRateLimiter: 重构为按KeyHash独立统计RPM，每个Key独立20 RPM

### v2.3.2 — 2026-08-28

**📋 变更说明**
创建 ai_log

### v2.3.1 — 2026-08-28

**📋 变更说明**
fix: 选项生成多回合不更新——强制notifyListeners+catch兜底改buildFallbackChoices+默认选项轮换

- processChoice中choices赋值后立即notifyListeners()，确保UI及时刷新
- catch分支统一使用buildFallbackChoices替代generateContextualFallbackChoices，
  避免静态位置选项与剧情末尾脱节断链
- buildFallbackChoices默认分支基于turnCount%3轮换3种不同风格选项，
  解决多回合兜底时选项完全一致的问题

### v2.3.0 — 2026-08-27

**📋 变更说明**
feat(settings): 提供商配置卡片重构为可折叠式(上次会话中断未完成,补全)

核心问题: 三个提供商卡片永远全展开, Key/模型/预设/说明全部平铺, 信息过载。

重构为可折叠卡片:
- 收起态(默认,已配置时): 提供商图标+名称+一句话定位(付费·高质量长文本/
  免费·响应最快/免费·剧情质量最佳)+当前模型(自定义模型高亮,默认模型灰显+默认标签)

### v2.2.9 — 2026-08-27

**📋 变更说明**
feat: UI美化——对话气泡/场景插图横幅/说话人头像接入叙事页

- StoryTextRenderer 新增 splitIntoSegments：剧情正文切分为叙述段/对话行
- 新增 SceneIllustrationBanner：按地点关键词匹配渐变氛围横幅
- 新增 DialogueBubble：头像+说话人+神态+气泡渲染对话
- 叙事页接入分段渲染，说话人解析到 NPC 用其头像与学院亮色
- UiHelpers 新增 getHouseColorBright 提升深色主题可读性

### v2.2.8 — 2026-08-27

**📋 变更说明**
perf: 系统机制优化——存档导出导入/无界数据上限/LRU缓存/AI token精细化

- 存档系统：新增导出到剪贴板/从剪贴板导入，支持跨设备备份迁移
- 内存与存档体积：NPC记仇记录上限10条、信件上限50封（优先删已读）、打工记录上限50条
- 缓存策略：ResponseCache 从 FIFO 改为 LRU，提升命中率
- AI 调用：选项生成 maxTokens 2500→1000，减少 token 浪费

### v2.2.7 — 2026-08-27

**📋 变更说明**
fix: 长线剧情一致性宏观修复——接通记忆写入管线

根因：LongTermMemory 系统设计完善但写入链路几乎完全断裂——
addKeyFact 仅初始化调用2次，addOrUpdateOpenLoop/upsertRelationshipAnchor/
addWorldEvent 从未被调用。导致数百回合后 T0/T1/T2/T3 记忆库近乎为空，
AI 只能看到最近2回合+600字模糊摘要，必然出现上下文断裂/跳剧情/选项无关。

### v2.2.6 — 2026-08-27

**📋 变更说明**
feat: 更新多模型路由——商汤6.8新模型+网络错误优化

- 商汤：新增 sensenova-6.8-flash-lite（默认）、glm-5.2，更新优缺点描述
- Agnes：默认模型改为 agnes-2.5-flash，补充 20RPM 限制与多Key提示
- 配额管理：SenseNovaQuotaManager 按模型区分（6.8/6.7=1500次/5h，deepseek/glm=500次/5h）
- 网络优化：指数退避重试（429/5xx 先重试同一提供商再切换），避免浪费备用配额
- 超时调整：SenseNova receiveTimeout 30s→90s（6.8响应慢），剧情超时45s→75s

### v2.2.5 — 2026-08-27

**📋 变更说明**
fix: 整体审查修复——恋爱取向/宠物化形/委托死锁/时间口径等

- 恋爱取向匹配：NPC 补 gender 字段，orientationMatches 双向校验（取向对性别）
- 宠物化形：不再清空全部关系，仅新增化形羁绊
- 时间大师成就：改用时代 startYear，去除硬编码 1991
- 魁地奇：对手池排除自己学院
- 决斗：排除教职人员（grade==0）

### v2.2.4 — 2026-08-27

**📋 变更说明**
删除 ai_log

### v2.2.3 — 2026-08-27

**📋 变更说明**
fix(crash): story_text_renderer substring越界崩溃

RangeError (end): Invalid value: Not in inclusive range 564..675: 563
堆栈指向 _tokenize L537（现在L569附近）:
  text.substring(seg.speakerStart, seg.nameEnd)

根因（多层）:

### v2.2.2 — 2026-08-26

**📋 变更说明**
docs: sync changelog for v2.2.1 [skip ci]

### v2.2.1 — 2026-08-26

**📋 变更说明**
fix(CI): Player字段名 hp→health, maxHp/maxEnergy不存在直接去掉

Player类只有 health/energy (int, 默认100)，没有 hp/maxHp/maxEnergy 字段。
retryPrompt 里写的是 player?.hp/maxHp/maxEnergy → 编译报错3个。
改为 player?.health ?? 100 和 player?.energy ?? 100。

### v2.2.0 — 2026-08-26

**📋 变更说明**
fix(剧情v3): 选项双重覆盖/时间戳消失/好感度丢失+主动审查4BUG

日志: 2251行/142KB/10次AI调用/3回合
模型返回的好感度和时间戳都在(AI确实输出了)，但代码层面丢失了。

---
【BUG-L 最严重】选项双重生成：完整prompt的好结果被极简prompt的通用选项覆盖

### v2.1.9 — 2026-08-26

**📋 变更说明**
创建 ai_log

### v2.1.8 — 2026-08-26

**📋 变更说明**
删除 ai_log

### v2.1.7 — 2026-08-26

**📋 变更说明**
fix(test): 最后1个着色测试失败: 括号神态里的"笑"单字误命中叙述动词

仅存失败: 冒号对话「德拉科（冷笑）：何必自讨苦吃。」测试期望
colorOf("德拉科（冷笑）") == speakerColor，但实际 speaker = "德拉"。

根因: 第二步 afterName 扫 _speechVerbs 时用了 contains()，
_speechVerbs 有单字动词"笑"→ afterName="（冷笑）".contains("笑") = true

### v2.1.6 — 2026-08-26

**📋 变更说明**
fix(test): story_text_renderer 4个着色测试修复

4个着色测试失败根因：_validSpeakerNameEnd 返回值两个层面全错：
1) "nameEndInRaw" 公式反了：已知角色赫敏(raw=赫敏,name=赫敏) 旧公式
   raw.length - (name.length + trimRight.diff) 算出来是 0 → nameEnd=0
   导致 seg.nameEnd(0) < seg.speakerEnd(2) → "赫敏："整段按叙述灰，
   测试期望"赫敏"橙/冒号蓝 → 全错。

### v2.1.5 — 2026-08-26

**📋 变更说明**
fix(CI): 3个编译错误修复 - mixin_narrative.dart L679: sanitizeNarrativeForArchive 从 GameResponseMixin 挪到 GameProviderBase   （作为基类 static 公共方法，两个 mixin 都 on GameProviderBase，都能无循环依赖访问） - mixin_response.dart L94: anchorIdx 为 int?，前面 if (anchorIdx==null) return 保证非空，加 ! 断言 - mixin_response.dart L116: finalPick 前面 if (finalPick==null) return flow 已提升非空，去掉多余 !

### v2.1.4 — 2026-08-26

**📋 变更说明**
fix(剧情v2·主动审查): 6个结构性BUG宏观修复(分院误判/返回选项/summary污染/状态栏乱编)

主动审查8471行/588K日志时发现用户未报告但极其严重的6个结构性BUG：

---
【BUG-H】Narrative / Summary 模型返回选项A.B.C.D.，代码直接写进剧情存档
- 日志证据：L1030 场景 narrative/动作 RESPONSE 返回全是 A.坦然迎接哈利波特的目光...B...C...D...

### v2.1.3 — 2026-08-26

**📋 变更说明**
fix(剧情v2): 对话不上色/分院前提前挂学院/霍尔捏造NPC 三问题宏观修复

日志：8471行/588K/38narrative回合
用户报告的3个问题：
1. 剧情大部分对话识别不出，不上色
2. 分院之前，最上方人物简介就挂上了学院
3. 开局几回合，剧情没出场的人(霍尔)却出现在选项中

### v2.1.2 — 2026-08-26

**📋 变更说明**
删除 ai_log

### v2.1.1 — 2026-08-25

**📋 变更说明**
fix(build): _buildFallbackChoices 跨mixin私有访问错误

flutter analyze报错：
The method _buildFallbackChoices is not defined for GameNarrativeMixin

根因：Dart 下划线前缀=文件级私有，GameResponseMixin里定义的
_buildFallbackChoices，GameNarrativeMixin作为另一个mixin无法访问。

### v2.1.0 — 2026-08-25

**📋 变更说明**
fix(ai_log_macro): 基于AI调度日志的9大问题宏观修复

根据ai_log(57次调用/4次TIMEOUT/12360行)的逐段分析，修复以下根因：

BUG1 好感度同步·parseResponse顺序反了
- parseResponse() 中 _parseAffectionChanges 跑到 markIntroducedFromNarrative 前面
- 导致海格首次出场时 introduced=false，AffectionValidator≥+4直接丢弃

### v2.0.9 — 2026-08-25

**📋 变更说明**
更新 ai_log

### v2.0.8 — 2026-08-25

**📋 变更说明**
fix(代码审查·F1-F3): R5 函数改名去误导 + R8 化形去 kyuubi 特判 + 兜底选项验证

### v2.0.7 — 2026-08-25

**📋 变更说明**
fix(build): EraDef _fallback 去掉 const，List[] 非常量表达式

### v2.0.6 — 2026-08-25

**📋 变更说明**
fix(build): 修复 R3 导入路径 & R12 课堂意外字段不存在

### v2.0.5 — 2026-08-25

**📋 变更说明**
feat(宏观架构改造·R1-R12): 全面数据化替代硬编码

P0 高危高收益（必改）：
- R1 指令系统：引入 CommandDef/CommandRegistry（50条命令注册），handleLocalCommand 优先查表 + fallback 旧switch（双活平滑迁移），/帮助 从注册表自动生成，彻底避免「路由 vs 帮助文档不同步」
- R2 开场场景：OpeningSceneDef + opening_scene_data.dart，1处查表替代 mixin_init 中 3 处 switch（时间/地点/开场文案共享同一定义）
- R3 时代定义：EraDef + era_data.dart，1处查表替代 mixin_init 中 5 处 Era switch（eraLabel/shortLabel/academicYear/eraKey/startYear 共享同一定义）

### v2.0.4 — 2026-08-25

**📋 变更说明**
feat(macro): 5 项宏观架构修复（OOC/场景图/衔接桥/停滞/好感校验）

M1 通用 NPC OOC 框架：NPC 统一字段 forbiddenActions + bloodSupremacist + 自动反向推导；R3b 改为
   npcRegistry 全量 allNames × forbiddenActions 笛卡尔匹配；OOC 默认 warn，仅严重才 CRITICAL 防误判熔断
M2 SceneTransitionGraph：替换 _checkOpeningRailroad 硬切 if/else，7 个节点（开局→收到信→对角巷
   →国王十字→特快→大礼堂→分院→公共休息室→第一节课）统一走进度门 visitedLocations + dateInt 时间门，
   不满足依赖不硬切 location 只注入衔接锚点，避免 7/31 直接跳到霍格沃茨大礼堂

### v2.0.3 — 2026-08-25

**📋 变更说明**
fix(剧情连贯性): 修复邓布利多OOC误判+开局地点跳变+选项超时断链(承接式兜底)

- mixin_narrative.dart:
  - R3b_ooc 邓布利多正则删除末尾空分支，避免100%误判 CRITICAL 触发强制重写
  - _checkOpeningRailroad 新增进度门(visitedLocations) 和时间门(dateInt>=901)，
    禁止 7月31日在家时直接切到霍格沃茨大礼堂
- mixin_response.dart:

### v2.0.2 — 2026-08-25

**📋 变更说明**
更新 ai_log

### v2.0.1 — 2026-08-25

**📋 变更说明**
Merge branch 'main' of https://github.com/zhaolongwudi/hogwarts_life_simulator

### v2.0.0 — 2026-08-25

**📋 变更说明**
merge origin/main into 剧情合理性改造分支（解决 game_provider_base 与 mixin_response 两处冲突：保留Quest/Quidditch新玩法声明 + 好感校验P1-2 clamp5）

### v1.9.9 — 2026-08-25

**📋 变更说明**
创建 ai_log

20:35 ai调用日志用于分析剧情合理性

### v1.9.8 — 2026-08-25

**📋 变更说明**
fix: 移除顶部栏错误的 energy/5 显示（精力条已独立展示）

### v1.9.7 — 2026-08-25

**📋 变更说明**
feat: 游戏界面优化 - 玩法快捷栏/顶部状态条/委托板装备独立页面/数值变化浮层/商店购买引导

### v1.9.6 — 2026-08-25

**📋 变更说明**
feat: 新增玩法系统（物品使用/宠物互动/装备穿戴/魁地奇/决斗/禁林探险/生物图鉴/支线委托/学院杯）

- 新增 item_data/bestiary_data/quest_data 统一数据源与 GamePlayMixin
- 物品/装备/宠物/战斗/探险全部本地判定，零 token 消耗
- 学院杯积分学年末自动结算，施法成功率公式含装备加成
- 商店与背包 UI 接线（统一数据源+使用/装备按钮），新增 8 项成就

### v1.9.5 — 2026-08-25

**📋 变更说明**
fix: 全面修复游玩与逻辑问题 - 恋爱表白链路、时间/周数系统、好感沉淀、商店打工统一数据源

- 恋爱链路全接线:好感阈值推进关系阶段→浪漫事件→表白成熟判定→接受/婉拒结算
- 时间系统:蔡勒公式星期错位、absoluteDayIndex 闰年修正、跨周判定改绝对天数分桶、快进接入学年/月度/事件 pipeline
- 好感沉淀:第2~4周受首月+50约束(原常量未应用)、跨月自动重置、尊重AI好感输出、被动好感仅作用于已登场NPC
- 商店/打工统一数据源:新增 job_data 岗位目录、卖出改半价动态目录、持有数实时徽章、背包分类补齐
- 存档:命名存档以槽名作 slotId、meta 记录真实 turnCount、last_school_year_start 持久化

### v1.9.4 — 2026-08-24

**📋 变更说明**
更新 ai_log

### v1.9.3 — 2026-08-24

**📋 变更说明**
fix: 修复 sanitizeChoiceText 中高位 Unicode 正则导致的崩溃

- 问题：Dart 正则不支持在字符类中使用 [\u{1F300}-\u{1F9FF}] 高位 Unicode 范围
- 现象：开局首回合加载选项时抛 FormatException: Range out of order in character class
- 修复：改用 String.runes 手动过滤 Emoji 和零宽字符，避免正则崩溃
- 影响：此修复解决了开局灰屏、剧情加载失败的问题

### v1.9.2 — 2026-08-24

**📋 变更说明**
fix: 修复AI剧情逻辑问题 - 玩家资质丢失、NPC结识标记错误、剧情墨迹

- 修复玩家 magicAptitude 丢失问题：在 LongTermMemory 解析时增加 fallback，确保存档加载后资质不丢失
- 修复 markIntroducedFromNarrative 过滤失效：改用 NPC.grade=0 判断霍格沃茨教职工，替代原本不存在的 title/role/occupation 字段
- 修复 updateNpcAffection 自动标记结识：移除好感变动时的 markNpcIntroduced 副作用，仅保留剧情扫描引入
- 统一 System/Narrative/Commands 三处资质显示逻辑
- 所有改动均为纯逻辑优化，无破坏性变更

### v1.9.1 — 2026-08-24

**📋 变更说明**
fix: 解决剧情墨迹和选项图片问题

1. 剧情精练优化 (world_rules.dart):
   - 叙事字数从 1500-2500 字缩减为 600-800 字
   - 新增反墨迹规则：每段必须推动剧情、禁止空洞描写
   - 感官细节要求融入动作（而非单独堆砌环境描写）
   - 对话简练要求，去掉冗余寒暄

### v1.9.0 — 2026-08-24

**📋 变更说明**
更新 ai_log

### v1.8.9 — 2026-08-23

**📋 变更说明**
快捷指令双修复:无响应+剧情选项丢失

- BuildChoiceList去掉commandResult隐藏条件
- _buildNarrativeSubTab顶部新增独立命令面板UI(带关闭按钮)
- 正文为空时不渲染空RichText盒子(gap guard)

### v1.8.8 — 2026-08-23

**📋 变更说明**
修NarrativeTab悬浮/选项/黑屏+指令菜单补全28条

1 时间戳不固定悬浮修复:
  * 旧结构 NarrativeTab Column → Expanded→SingleChildScrollView(套剧情卡SizedBox)
    Stack Positioned 无边界尺寸 -> top:0 随整屏滚动=悬浮失效
  * 新结构: build → 删外层SingleChildScrollView 包裹剧情层
    Expanded→LayoutBuilder→_buildNarrativeSubTab

### v1.8.7 — 2026-08-23

**📋 变更说明**
设置Tab完整版+时间悬浮强对比+选项不遮挡

1 剧情时间戳悬浮卡重绘:
  * 背景 #1C232D 深色不透明 + 金边#D3A625 + 黑金双层阴影
  * 时间字 #F8F6EE w800 14pt + Expanded 超长折行
  * 地点字 #E8FBEC w800 13.5pt + Expanded 超长折行
  * 水平padding 16, 卡间距与外层SingleChildScrollView padding统一

### v1.8.6 — 2026-08-23

**📋 变更说明**
修复CI 12报错: _lastScannedNarrativeHash公开化+类型修正+warning清理

- 跨mixin/library私有字段访问报错：
  _lastScannedNarrativeHash 改为 public lastScannedNarrativeHash
  (Dart library级隐私模型：mixin_init/mixin_narrative 在另一个文件，
   无法访问GameProviderBase的私有字段)
- lib/models/world_state.dart: 移除unused dart:convert import

### v1.8.5 — 2026-08-23

**📋 变更说明**
修复:事件时间回退+签名排除+回合扫描去重+世界文案+剧情时间悬浮

A 事件记录相对时间回退bug:
- 新增 NarrativeEvent 模型(text/turn/at, 支持短键t/r/a和长键双读)
- recentNarrativeEvents/recentEvents: List<String> → List<NarrativeEvent>
- addNarrativeEvent(event,{turn}) 15处调用全填 turnCount
- 旧档字符串100%兼容 → fromJson(src is String) 自动升级 turn=null 显示「—」

### v1.8.4 — 2026-08-23

**📋 变更说明**
修复:开局日志合理性+设置去重+身份政治立场拆分

A 开局日志合理性分析说明(见回复)：
- ✅ Prompt结构正确:玩家资料13项全注入+魔杖硬设定+Letter起点匹配
- ✅ 第1回合响应(1642 tokens)符合1500-2500字
- ✅ 世界模块已登场=邓布利多+麦格(信签名) 匹配剧情内容
- ⚠️ 但图2事件记录「结识邓布利多/麦格」2回合前/3回合前描述不对

### v1.8.3 — 2026-08-23

**📋 变更说明**
修复:新开局NPC自动结识/剧情锚残留 + 时间戳样式 + 设置内联

P1 新开局NPC/剧情锚:
- resetAllState 补 LongTermMemory() 重置
- markIntroducedFromNarrative 升级：仅名字出现不够，需上下文
  命中互动动词（见面/握手/介绍/敲门/对话/…）或同名累计≥3次
  才标 introduced 并写入「👤 你结识了」剧情锚点

### v1.8.2 — 2026-08-23

**📋 变更说明**
创建 ai_log

### v1.8.1 — 2026-08-23

**📋 变更说明**
refactor: 全局关联链路审查修复 A+B+C类

【A类 Game子组件小修 4项】
- 删除死组件 game_character_tab.dart(288行，narrative_tab面板已内嵌角色面板)
- GameBottomInput 移除 menuController 死参数(字段/构造/传参三处同步删除)
- game_screen.dart 移除 _menuController 字段和 dispose 调用
- PhoneTab/WorldTab: gp 从 dynamic→GameProvider 强类型，补齐import

### v1.8.0 — 2026-08-23

**📋 变更说明**
fix(CI): 修复flutter analyze 8个warning - 移除unused_imports/unused_fields

修复清单:
- mixin_init.dart: 删除未使用 deepseek_service.dart import
- game_provider.dart: 删除未使用 deepseek_service.dart import
- game_screen.dart: 删除未使用 game_character_tab.dart import + 未使用 _tokenUsage 字段
- settings/settings_provider_card.dart: 删除 flutter/services.dart (冗余, material已提供)

### v1.7.9 — 2026-08-23

**📋 变更说明**
feat(P1+P3): 方案A三期全部落地 - Screen拆分完成(11新文件)

第一期(Screen混装+Prompt拆出): prompts/ 4文件齐全,screens/无内嵌prompt
第二期(GameProvider→6Mixin): 已在上次提交完成
第三期(game_screen+settings_screen拆):
- game_screen.dart: 2477→165行 (-93%), 拆出7个独立组件
  * game_narrative_tab.dart 824行 (叙事Tab+面板+角色)

### v1.7.8 — 2026-08-23

**📋 变更说明**
feat(P1): 方案1实装落地9项全链路闭环

P1-1 角色属性注入（补5个缺失）：
- buildSystemPrompt新增【魔法资质】【家族背景】【学院倾向】
  【模拟风格】【宠物】5个characterLines注入
- 与原有的【性格】【外貌】【童年奇迹】【初始天赋专精】
  【魔杖】【出生身份】【信念】【政治立场】形成完整13项

### v1.7.7 — 2026-08-23

**📋 变更说明**
fix(P2): 清场全部CI错误 + 150 unused imports

ERROR级别修复（共4处）：
1. 删除GameProviderBase.buildPrompt抽象声明（实际是processChoice
   内部的局部函数，不是Mixin方法，导致non_abstract_class报错）
2. 移除generateContextualFallbackChoices/generateFallbackChoices
   前的abstract关键字（Dart只允许abstract class，不允许

### v1.7.6 — 2026-08-23

**📋 变更说明**
fix(P2): Base 4类错误清场

1. abstract_class_member(79+): Dart 不允许类成员前写 'abstract'
   → 全量删除方法签名前的 abstract 前缀；GameProviderBase 本身声明为 abstract class(已加)
2. 移除无效 private abstract: _formatTime() 声明是跨library不可见的_前缀方法
   → Base 中直接删除；mixin_commands 内部定义/引用不动
3. 补 5 个 import：

### v1.7.5 — 2026-08-23

**📋 变更说明**
fix(P2): 终极方案：85+6跨Mixin不可见方法 → GameProviderBase abstract声明

Dart 3 的 Mixin  静态分析只认识 X 的成员，不认识同  中其它 Mixin 的方法，
导致 roll/bloodStatusLabel/formatAffections/unlockAchievement/callDeepSeek 等 85 个方法报 undefined_method。

修复：
- p2_fix_cross_mixin_v3.py 自动扫描所有方法定义在A文件、引用在B文件的 85 个跨 Mixin 方法

### v1.7.4 — 2026-08-23

**📋 变更说明**
fix(P2): 终极解环：GameProviderBase abstract 承载字段 + Mixin on Base

修复 recursive_interface_inheritance + type_argument_not_matching_bounds + 所有 undefined_name 级联:
- 新增 game_provider_base.dart: GameProviderBase extends ChangeNotifier
  - 抽象 getter/setter (appProvider/router/saveService/random/chatService) 由 GameProvider @override 提供
  - 32个核心状态字段(player/worldState/npcRegistry/...) 全部迁移到 Base
  - 6个静态正则(reChoiceOption/maxRecentTurns等) 迁移到 Base

### v1.7.3 — 2026-08-23

**📋 变更说明**
更新 临时构建报错日志.txt

### v1.7.2 — 2026-08-23

**📋 变更说明**
fix(P2): 解决1024+ CI编译错误：recursive_interface/字段可见性/跨Mixin私有/类型转换

- 根因A：6个Mixin  + GameProvider  6个Mixin 形成 recursive_interface 继承环（Dart 3.x不允许）
- 根因B：ChangeNotifierProvider<GameProvider> 泛型边界不接受隐式Mixin扩展的ChangeNotifier
- 修复1：所有6个Mixin声明改为  解环（GameProvider extends ChangeNotifier + with Mixin = 天然满足）
- 修复2：跨Mixin引用的52个私有方法public化（Dart library级隐私模型跨文件_前缀不可见）
- 修复3：houseDimensions数值courage/ambition/wisdom/loyalty 显式.toInt()解决int/double赋值错误

### v1.7.1 — 2026-08-23

**📋 变更说明**
更新 临时构建报错日志.txt

### v1.7.0 — 2026-08-23

**📋 变更说明**
fix(P2): 修复6处编译错误 - getter递归/router自赋值/下划线前缀残留引用

修复详情:
1. 删除notifications/lastAffectionSections同名getter（避免无限递归）
2. router局部变量重命名为newRouter（避免自赋值空操作）
3. 修复5处public化字段残留下划线前缀引用:
   - game_provider:  → ,  →

### v1.6.9 — 2026-08-23

**📋 变更说明**
创建 临时构建报错日志.txt

### v1.6.8 — 2026-08-23

**📋 变更说明**
fix(P2): Dart Library级隐私修复 — 32成员public化+28处命名修正

🔧 修复内容:
1. 删除6个Mixin中对 game_provider.dart 的循环import (跨Library访问禁私有)
2. 将 GameProvider 中 32 个被 Mixin 引用的私有成员 public化(去掉_前缀):
   - 核心状态: player, worldState, npcRegistry, memory, currentNarrative, choices...
   - 时间/回合: turnCount, gameWeek, lastSchoolYearStart

### v1.6.7 — 2026-08-23

**📋 变更说明**
refactor: 拆分GameProvider为6个Mixin (方案1 P2)

- 游戏逻辑核心game_provider.dart从6047行瘦身至337行(-94%)
- 按功能边界拆分为6个Mixin:
  * mixin_init.dart     (1047行) 系统提示词、初始化、分院/魔杖/开局特质
  * mixin_narrative.dart (917行) buildPrompt、记忆注入、上下文截断
  * mixin_commands.dart  (664行) 命令面板、作弊指令

### v1.6.6 — 2026-08-23

**📋 变更说明**
refactor(ui+prompts): P1 拆屏 + 常量抽离

- other_screens 1476行 → 5屏+barrel:
  - other/communication_screen.dart(360) + forum(343) + diary(270)
    + parallel_world(245) + matchmaker(295) + barrel
- shop_inventory_screens 597行 → 商店/库存/古灵阁 4文件+barrel:
  - shop/shop_screen 壳(112) + shop_tab(190) + gringotts_tab(182)

### v1.6.5 — 2026-08-23

**📋 变更说明**
fix(ci): 修复17项flutter analyze错误

CI编译错误全量修复：

game_provider.dart:
- 资料交叉校验：去除不必要的非空断言(!)（行575/577/585）
- currentLocation设置：将未定义的 p.birthLocation 改为 _player!.birthLocation（行634）

### v1.6.4 — 2026-08-23

**📋 变更说明**
fix(1-11): 全量修复剧情锚点/资料/魔杖/选项/伪造事件

🔴 4 剧情节点按真实时间进度条件化：EventAnchor 新增 minHour/maxHour/requiredLocation 字段
   - g1_sep_arrival 特快抵达锚点：需 minHour=11 + currentLocation包含'特快'
   - anchorsFor() 新增 hour 和 currentLocation 参数；注入点一并透传

🟠 5 玩家资料交叉校验：initializeGame 构建 Player 前修复纯血豪门 vs 麻瓜家庭冲突

### v1.6.3 — 2026-08-23

**📋 变更说明**
fix: 查看类指令改用独立结果面板，返回不再丢失当前回合剧情

- 新增 _commandResult 面板：/状态 /关系 /信 等查看类指令输出进面板，
  不覆盖剧情；点「返回剧情」仅关闭面板，不调用 AI、不消耗回合
- 事件类指令（/新NPC 等）仍正常替换剧情并关闭旧面板
- /关系 只显示 introduced 的 NPC：新开局不再列出预注册的全时代角色
- 面板打开时隐藏剧情选项，避免误触行动

### v1.6.2 — 2026-08-23

**📋 变更说明**
fix: 实体高亮恢复长词优先匹配，修复地点渲染测试

_splitNarration 中角色名有按长度降序排序，但地点/物品按
列表原始顺序遍历：「霍格莫德」（列表第3位）先于「霍格莫德
车站」（第37位）命中并占据重叠区间，长地名永远无法整体
高亮，CI 测试「时钟时间不是对话（09:30）」因此失败。

### v1.6.1 — 2026-08-23

**📋 变更说明**
revert: 回退在场NPC与关系快照的登场过滤

误判了「已登场人物」功能的设计意图：该功能要求从开局起
对所有登场人物持续关联好感度。上一轮加的 introduced 过滤
和 6 人上限会让 AI 看不到其余登场人物，导致他们的好感度
变化无法被生成和更新，破坏好感度系统与表白/关系等联动。

### v1.6.0 — 2026-08-23

**📋 变更说明**
fix: 剧情着色第二轮修复与 NPC 登场过滤

基于远端最新代码（v1.5.9）合入本地未推送的改进：

剧情文字渲染（story_text_renderer）：
- 叙述动词剥离：「罗恩说："…"」中「说：」归叙述灰，
  只有「罗恩」按说话人橙色，修复对话前误标橙色

### v1.5.9 — 2026-08-23

**📋 变更说明**
fix: 修复 raw 字符串中引号转义导致字符串提前终止

housePatterns 的分院帽模式 RegExp 用了 raw 字符串 r"..." 却内含
\" 转义，raw 字符串不解释转义，双引号会提前终止字符串，导致 flutter
analyze 报 6 个级联语法错误。改用三引号 raw 字符串 r'''...''' 同时
容纳单/双引号，消除字符串断裂。

### v1.5.8 — 2026-08-23

**📋 变更说明**
fix: raw字符串中 \' 无法转义导致字符串提前终止

Dart raw字符串 r'...' 中 \' 不是转义，' 直接终止字符串
改用双引号 raw 字符串 r"..." 避免 "' 冲突

### v1.5.7 — 2026-08-23

**📋 变更说明**
fix: 修复CI编译错误的两个问题

1. game_provider.dart L4167: 正则中 」(U+300D) 被 Dart 分析器视为非法字符
   导致整行解析断裂，级联 39 个错误
   修复：移除 」 字符，仅用 ASCII 引号 [\"\']? 匹配分院帽引语

2. shop_inventory_screens.dart L83: Icons.vault 不存在于 Flutter Icons 类

### v1.5.6 — 2026-08-23

**📋 变更说明**
全项目功能落地核查·一次到位

核查修复了以下断链/缺失功能：

1. 【系统提示词字数冲突彻底修复】
   - world_rules.dart完整版line20: 400-600→1500-2500(上次已改)
   - 完整版输出格式模板line124: [400-600字叙事文本]→[1500-2500字叙事文本]

### v1.5.5 — 2026-08-23

**📋 变更说明**
fix: 修复已分院但仍显示未分院的问题

根因：
1. 开局场景走 _parseResponse 路径，原代码只在 _parseNarrativeOnly 中提取学院，导致开局叙事中直接分院时无法提取
2. 原正则缺少语境判断，分院前列举学院时可能误匹配第一个出现的学院
3. generateOpeningScene 成功路径缺少 _autoSave()，修改可能未持久化

### v1.5.4 — 2026-08-23

**📋 变更说明**
fix(prompt): 角色创建选项未体现+叙事字数上限冲突+近期事件刷屏

- _buildSystemPrompt 注入角色创建8项属性：出生身份/性格/外貌/童年/信念/政治立场/初始天赋/魔杖，性格加严禁冷酷控制欲约束，魔杖加绝对不要写成柳木
- world_rules 完整版系统提示词 叙事风格5号 400-600→1500-2500字（与narrative prompt一致，解决AI坚守system prompt低字数导致token涨不上去）
- 世界近期重大事件过滤好感上限通知刷屏，且去重

### v1.5.3 — 2026-08-23

**📋 变更说明**
fix(ai): 修复调试日志暴露的4个问题

1. narrative AI重复输出历史叙事（最严重）
   - 前情注入标注从「以此生成选项」改为「已生成内容，严禁重复或改写」
   - 注入量从10回合4800字缩减到3回合1600字，只保留末尾用于理解处境
   - 写作要求新增规则：严禁重复前情回顾中的任何内容，从玩家行动之后续写
2. choice注入完整叙事浪费token：截断为末尾500字
3. 选项违背原住民身份：choice prompt新增身份模式注入+严禁剧情预知类选项，T0阈值≥6→≥4
4. narrative prompt标注错误：「以此生成选项」改为前情标注

fix(prompt): 角色创建选项未体现+叙事字数上限冲突+近期事件刷屏

- _buildSystemPrompt 每回合 system prompt 注入角色创建的 8 项属性：
  【出生身份】【性格】【外貌】【童年奇迹】【信念】【政治立场】【初始天赋专精】【魔杖】
  并针对性格和魔杖加了强约束：严禁写成冷酷控制欲型；不要把枫木·凤凰羽毛写成柳木
- world_rules 完整版系统提示词 叙事风格5号：400-600字→1500-2500字（与 narrative
  prompt 一致，解决 AI 因为 system prompt 权重更高而坚守 400-600 字导致 token 涨不上去）
- 【世界近期重大事件】注入加过滤：剔除"好感本周已达上限/周好感度已达上限"刷屏通知，
  新增去重（同一事件只注入一次）

### v1.5.2 — 2026-08-23

**📋 变更说明**
fix(ai): 免费模型优先路由与回退/存档/并发修复

- AiRouter 回退改为候选列表迭代，默认 fallbackOrder 仅含免费模型
  (sensenova/agnes)，不自动回退到付费 DeepSeek
- hasNarrativeService 改为任一 provider 已配置即可用，避免有备用 key 被挡死
- 超时用 CancelToken 真正取消底层 Dio 请求，避免资源浪费与重复日志
- 修复 WorldEventRecord.score 忽略当前时间导致世界事件新鲜度不衰减

### v1.5.1 — 2026-08-23

**📋 变更说明**
fix(token): 精细化maxTokens+叙事字数要求 + 修复调试日志4个问题

- narrative 写作要求：500-800字→1500-2500字（分4-8段），让每回合总token达到4000
- maxTokens 从二元 6000/7000 改为按场景精细化：
  narrative=4000, choice=2500, summary=4000, npcChat=4000
- 选项场景从7000降到2500：选项只输出4行ABCD，2500绰绰有余
- narrative AI重复输出历史叙事：前情标注改为「已生成内容严禁重复」；注入从10回合4800字缩减到3回合1600字
- choice 注入完整叙事浪费token：截断为末尾500字
- 选项违背原住民身份：choice prompt新增身份模式注入+严禁剧情预知类选项；T0阈值≥6→≥4

### v1.5.0 — 2026-08-23

**📋 变更说明**
perf(token): 模型升级整体放开翻倍 + maxTokens精细化

- T0~T3/recentTurns/摘要/选项prompt条数全部翻倍（详见 v1.4.9 条目）
- narrative 写作要求：500-800字→1500-2500字，让每回合总token达到4000
- maxTokens 从二元 6000/7000 改为按场景精细化：
  narrative=4000, choice=2500, summary=4000, npcChat=4000
- 选项场景从7000降到2500：选项只输出4行ABCD，2500绰绰有余

### v1.4.9 — 2026-08-23

**📋 变更说明**
fix(summary): 修复每10回合token暴涨+选项出现未经历角色/事件

- T4摘要注入：超过200字强制截断；T0+T1结构化事实≥12条时直接跳过T4注入（信息充足无需模糊摘要）
- 选项生成与叙事响应彻底解耦：_parseNarrativeOnly成功后不再从叙事响应里读入ABCD
  - 防止「写作要求已禁止生成选项但AI仍偷偷夹带且夹带了T4旧摘要信息（海格/巨怪事件）」
- 摘要触发频率从每10回合调整为每20回合；字符阈值3000→3200；缓冲上限6000→4000
- 摘要prompt新增第7/8条规则：绝对禁保留一次性事件(巨怪/小决斗)的具体场景和过程；

perf(token): 模型升级整体放开翻倍，提升完整性逻辑性流畅度

- T0：importance≥4，最多 60 条（≥5→≥4，30→60）
- T1 未完结事项：最多 40 条（20→40）
- T2 NPC 关键关系：24 个（12→24），keyMoments/secretsShared/promisesExchanged 每条 3→6
- T3 世界事件：40 条（20→40）
- T4 注入长度 200→600，跳过阈值 T0+T1<12→<30
- WorldState.recentEvents/recentNarrativeEvents 6→12
- _maxRecentTurns 6→12；filteredTurns 取 10（5→10）
- 近期上下文 recent 字符上限 2400→4800
- 摘要：maxPendingSummaryChars 4000→8000；触发 20→15 回合，阈值 3200→6000
- 摘要保存字数：400/700/1000 → 800/1500/2400
- 选项 prompt：knownSpells 6→12；invItems 6→12；openLoops 3→6 importance≥5；
  nearbyNpcs 6→12 好感阈值 15→10；T0 事实 4→10 importance≥6
- 系统提示词 kUseFusedCompact 精简版→切到完整版世界规则
- maxTokens：narrative 3000→6000；其它（选项/摘要/NPC）3500→7000

### v1.4.8 — 2026-08-23

**📋 变更说明**
feat(avatars): 大世界模块 NPC 真实头像替换圆形首字

- 从 HP API (hp-api.onrender.com) 下载 17 个核心角色电影头像到 assets/images/avatars/
  覆盖: 哈利/赫敏/罗恩/纳威/金妮/德拉科/克拉布/高尔/张秋/卢娜/塞德里克/
        小天狼星/卢平/麦格/斯内普/海格/费尔奇
- 新建 NpcAvatar Widget: 优先加载本地图片, 加载失败自动回退为圆形+首字
- 替换 3 个 UI 模块共 4 处圆形首字头像:

fix(summary): 修复每10回合token暴涨+选项出现未经历角色/事件

- T4摘要注入：超过200字强制截断；T0+T1结构化事实≥12条时直接跳过T4注入（信息充足无需模糊摘要）
- 选项生成与叙事响应彻底解耦：_parseNarrativeOnly成功后不再从叙事响应里读入ABCD
  防止「写作要求已禁止生成选项但AI仍偷偷夹带且夹带了T4旧摘要信息（海格/巨怪事件）」
- 摘要触发频率从每10回合调整为每20回合；字符阈值3000→3200；缓冲上限6000→4000
- 摘要prompt新增第7/8条规则：绝对禁保留一次性事件(巨怪/小决斗)的具体场景和过程；
  硬限制保存长度limit*1.2，超出直接截短
- 选项标题强约束「严禁基于历史背景生成当前回合选项与场景」
  解决每10回合token暴涨到5000和选项出现未经历角色/事件

### v1.4.7 — 2026-08-23

**📋 变更说明**
fix(affection): 修复好感度永远不变的根因 + 被动好感推断机制

## 根因
_parseAffectionChanges 中 section 提取有致命 bug：
  sectionMatch.group(0)!.replaceFirst(sectionPattern, '')
group(0) 返回的是完整匹配（header+body），然后用同一个 sectionPattern
再次匹配整段文本 → 全部被替换为空 → section 永远是 "" →

### v1.4.6 — 2026-08-22

**📋 变更说明**
fix(npc-intro): 修复中文名称登场识别永远失败 + docs: 迁移更新日志到独立 CHANGELOG.md

## 1. 大世界 NPC 登场识别根本修复
- 根因：_standaloneNameMentioned 的 isBoundary() 逻辑错误地把「前后是 CJK 汉字」
  判定为「非独立词」——但中文不用空格分词，正文里「捕捉到了金妮骤然...」
  前后必然是汉字，导致所有 NPC 剧情中出现了但大世界永远显示 0 人已登场。
- 修复：区分中文名称（CJK 字符≥50%）与英文/数字名称

### v1.4.5 — 2026-08-22

**📋 变更说明**
更新 README.md

### v1.4.4 — 2026-08-22

**📋 变更说明**
fix(lint): 修复 flutter analyze 全部 21 个问题（11 错误 + 10 警告）

修复内容：
1. WorldState.worldEvents → recentEvents，修复字符串遍历误调用 .timestamp/.description（4错误）
2. Player.year → p.grade ?? 0，共 3 处（3错误）
3. p.house.isNotEmpty → 先判空再访问，修复 nullable 调用（1错误）
4. SpellLevel.intermediate/proficient/mastered → e.value.level >= 2（3错误）

### v1.4.3 — 2026-08-22

**📋 变更说明**
feat(memory&choice): 千回合级结构化记忆银行(T0/T1/T2/T3) + 选项生成专用HP四轴Prompt

## 1. 长期记忆（解决「几千回合后记忆严重丢失」风险）

根本问题：之前只有一条自然语言摘要，由 LLM 每10回合压缩一次。LLM 压缩 = 有损压缩，
1000 回合后 1500 字塞不下千件事，重要事实一定会被淘汰。

### v1.4.1 — 2026-08-22

**📋 变更说明**
fix(log&prompt): 移除调试日志截断 + choice场景精简System Prompt省token

问题：
- 用户看到日志里【档案】【世界上下文】等重要内容被截断为500/200/300字符，影响定位bug
- choice/summary场景也传入完整世界观+玩家档案(231行)的System Prompt，既浪费token又有世界观信息污染风险

---

### v1.2.1 — 2026-08-22

**🎯 长线游玩核心系统完善**

- **学年晋升**：玩家与 NPC 年级每年推进、毕业离校、学期划分
- **存档加固**：原子写入 + 自动备份 + 损坏时自动回滚恢复
- **事件锚点**：手写剧情骨架按月份 / 年级 / 时代注入叙事流程，剧情更有"锚"
- **开局特质**：稀有度分级 + 软保底抽取，影响属性和叙事走向
- **职业目标数值化**：为每个人生目标定义可衡量的毕业条件（终章结局用）
- **长线玩法补充**：课堂互动、舆论传闻系统、信件读写回寄、日记统计重播
- **剧情连贯性**：近期剧情改为 4 回合环形缓冲，AI 不再第二回合失忆

### v1.2.0 — 2026-08-22

**🎯 安全加固 + AI 错误分级**

- **API Key 加密存储**：改用 `flutter_secure_storage`，旧版明文自动迁移并清除
- **AI 错误分级**：超时 / 429 / 5xx / 网络错误自动重试；认证失败 / 余额不足 / 400 错误直接提示用户，不再盲重试
- **Prompt 注入防护**：玩家自由行动输入和 NPC 聊天输入自动做注入净化与限长

### v1.1.0 — 2026-08-22

**🎯 UI 交互全面优化**

- 剧情里的 A./B./C. 选项不再重复出现在正文里（下方「可选行动」独立显示）
- 对话「人物: 台词」自动区分颜色：说话人金色加粗，台词蓝色
- 时间戳、日期、状态标签等不再误被当成对话染色
- **世界 NPC 列表修复**：开局不再 38 人全部「已登场」，只有剧情里正式见过面的人才会标记
- NPC 简介简化：去掉大段外貌描写，改用身份标签（"变形课教授""钥匙看守""马尔福跟班"等）
- 世界 NPC 列表默认折叠「未登场」区块，登场超过 15 人时不再一次性全部展开
- **魔法通讯修复**：开局未认识的 NPC 不会出现在联系人列表里
- 魔法通讯顶部「全部 / 学院」Filter 文字垂直水平居中对齐
- **崩溃日志系统**：全局异常捕获 + 本地 JSON 落盘 + 设置页可查看/复制/清除

### v1.0.0 — 2026-08-21

**🎯 融合版世界观 · 功能全面完善**

**世界观重塑**
- 正式确立「玩家不是天命主角」为游戏最高原则
- 世界独立运转：月度结算魔法部、霍格沃茨、黑巫师、神奇生物、经济五大板块动态
- 剧情风格小说化，包含感官细节、环境氛围、人物心理描写

**AI 系统升级**
- 4 家 AI 服务商：DeepSeek、智谱 AI、Agnes、SenseNova 全部接入可用
- 多模型路由：主剧情 / 摘要 / NPC 聊天可以分别绑定不同 AI
- Token 消耗优化：每回合 3000-5000 → 800-1500
- 主模型失败时自动降级到备用模型
- 设置页模型快捷按钮：免费额度 / 推荐付费 分类一键选

**恋爱 & 关系系统**
- NPC 会主动表白（好感高、关系暧昧、相处够久就会触发）
- 不同性格的 NPC 表白方式不一样（勇敢型直接说、害羞型脸通红、理性型深思熟虑）
- 首周好感上限 +30：防止刷好感太快导致关系不真实
- 记仇机制：严重背叛后，对方对你的好感永远无法超过背叛前的历史峰值

**成就 & CG**
- 20 项成就自动解锁
- 36 张剧情 CG，按好感度自动触发

### v0.8.0 — 2026-08-21

- **多模型路由系统上线**：可按场景分配不同 AI 提供商
- **经济系统落地**：加隆货币、古灵阁存取、5 个打工岗位、对角巷商店买卖
- **新增九尾狐宠物「绯月」**：东方神话背景，可化人形，完全听命于玩家
- Token 消耗大幅降低约 70%

### v0.7.0 — 2026-08-21

- 修复分院 / 魔杖选择数据错误
- 修复大量 UI 显示问题（地图对比度、底部导航覆盖、文字看不清等）
- 崩溃问题集中修复

### v0.6.0 — 2026-08-20

- 项目基础架构搭建完成
- 世界观规则系统、核心初始化选项、手机模块、世界地图、存档系统全部上线
