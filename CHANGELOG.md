# 更新日志

所有版本变更记录都在这里。日常小修小补、analyze 报错修复不单独列出。
新条目由 CI（`scripts/sync_changelog.sh`）在每次 `main` 分支推送时自动追加到顶部。

---

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
