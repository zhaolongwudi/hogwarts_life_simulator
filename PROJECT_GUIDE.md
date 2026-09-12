# PROJECT_GUIDE · 项目结构与维护指南

> **给未来的 AI 助手 / 开发者的一份"维修导航"**。
> 读完这份文档，你应当能在 5 分钟内定位任何问题的相关文件，
> 并避开本项目最常踩的坑（源码扫描测试、mixin 组合、版本 CI 机制）。
> 项目规模：约 5.5 万行 Dart，133+ 文件。当前版本 v3.5.x。

---

## 1. 项目速览

| 项 | 值 |
|---|---|
| 类型 | AI 驱动的人生模拟器（Flutter 移动应用） |
| 世界观 | 哈利·波特（含 5 个可选时代） |
| 核心循环 | 玩家自由输入 → AI 生成叙事 → 解析状态变化 → 时间推进 → 世界演化 |
| 技术栈 | Flutter 3.16+ / Dart 3.2+ / Provider / JSON 存档 + secure_storage |
| 跑测试 | `flutter test`（当前 1254+ 项） |
| 跑分析 | `flutter analyze`（门禁：0 error） |

**入口文件**：`lib/main.dart`（主题定义在 `_buildDarkTheme()`）→ `lib/screens/home_screen.dart`（主页）→ `lib/screens/intro_screen.dart`（13 轮角色创建）→ `lib/screens/game_screen.dart`（主游戏）。

---

## 2. 目录地图

```
lib/
├── main.dart                  # App 入口 + 深色主题（GitHub Dark 风格，金 #D3A625）
├── data/          (54 文件)   # ★ 纯数据层：常量表/规则表/事件表（无逻辑）
│   ├── command_registry.dart  #   指令注册表（CommandDef：primary/aliases/group/helpText）
│   ├── course_data.dart       #   课程/成绩（8 门必修 O/E/A/P/D/T）
│   ├── exam_data.dart         #   考试结算模型（学期末/O.W.L/N.E.W.T）
│   ├── career_data.dart       #   毕业后职业线（8 条，成绩+属性+声望门槛）
│   ├── animagus_data.dart     #   阿尼马格斯（形态表/成功率/训练增益）
│   ├── patronus_data.dart     #   守护神（10 形态与人格关联）
│   ├── death_data.dart        #   死亡方式与坏结局文案
│   ├── event_anchors.dart     #   ★ 时代事件锚点（跨学年触发机制）
│   ├── world_rules.dart       #   世界规则（防崩坏约束）
│   ├── balance_constants.dart #   平衡常量（含 growthExpectation 成长曲线）
│   ├── job_data.dart          #   学生打工岗位
│   ├── house_cup_data.dart    #   学院杯
│   ├── legacy_data.dart       #   传承局（下一代）
│   ├── ending_review_data.dart#   人生终章报告（EndingFacts/Epithet）
│   └── ...（cg/collectible/goal/wand/castle/worldline/npc_schedule/monthly_event…）
├── models/       (5 文件)     # 状态模型（JSON 序列化，老档兼容）
│   ├── player.dart            #   ★ 玩家全量状态（属性/声望/好感记录/作弊标记/死亡/职业…）
│   ├── npc.dart               #   ★ NPC（性格/好感/日程/性取向/affectionLocked）
│   ├── world_state.dart       #   世界状态（时间/天气/firedAnchorIds/时间线分支）
│   ├── game_systems.dart      #   系统结构（GameChoice 等）
│   └── long_term_memory.dart  #   ★ 长期记忆（KeyFactRecord，T0 永不遗忘层）
├── providers/    (3 文件)     # 状态管理与游戏主逻辑组装
│   ├── game_provider.dart     #   ★ GameProvider = GameProviderBase + 14 个 mixin
│   ├── game_provider_base.dart#   ★ 抽象基类 + 跨 mixin 调用声明（新跨 mixin 方法在此声明）
│   └── app_provider.dart      #   应用级状态（API Key/游戏是否开始）
├── mixins/       (14 文件)    # ★ 游戏逻辑按领域拆分（全部 mixin 组合进 GameProvider）
│   ├── game_provider_mixins.dart  # barrel：export 所有 mixin（新增 mixin 记得加 export）
│   ├── mixin_init.dart        #   开局初始化 + 系统提示词组装（characterLines）
│   ├── mixin_narrative.dart   #   ★ 主叙事循环 processChoice（输入判定/指令拦截/AI 调用/并发守卫）
│   ├── mixin_commands.dart    #   ★ 全部指令注册 + _handleXxx 实现（60+ 条）
│   ├── mixin_response.dart    #   ★ AI 响应解析（parseNarrativeOnly/清洗链/选项校验 BUG-H）
│   ├── mixin_response_affection.dart # 好感变化提取（正则 → 散行 → 关键词回退）
│   ├── mixin_response_choices.dart   # 选项生成/清洗
│   ├── mixin_relations.dart   #   关系/NPC 生成/好感结算/打工
│   ├── mixin_systems.dart     #   时间推进/学年/事件锚点/学院杯/职业年结/考试结算
│   ├── mixin_play.dart        #   行动结算（决斗/禁林/使用物品/时间快进）
│   ├── mixin_animagus.dart    #   阿尼马格斯
│   ├── mixin_career.dart      #   毕业后职业
│   ├── mixin_death.dart       #   死亡判定与终章
│   └── mixin_narrative_continuity.dart # 叙事连续性/承接
├── prompts/      (4 文件)     # Prompt 模板（narrative/choice/summary）
├── services/     (7 文件)     # 外部依赖
│   ├── ai_router.dart         #   ★ AI 路由（多 key/熔断/限流/场景绑定/超时）
│   ├── deepseek_service.dart  #   AI 调用实现（Dio）
│   ├── npc_chat_service.dart  #   NPC 聊天（历史净化/离线兜底标记）
│   ├── rate_limiter.dart      #   限流器
│   ├── key_store.dart         #   API Key 加密存储
│   └── save_service.dart      #   ★ 存档（_saveVersion 迁移/备份/回滚）
├── screens/      (40 文件)    # 全部 UI
│   ├── game/                  #   主游戏页（narrative_tab 剧情/phone_tab 手机/world_tab 世界/top_bar 顶栏/bottom_input 输入/command_center_panel 指令中心）
│   ├── shop/                  #   商店/背包/宠物店/古灵阁
│   ├── settings/              #   设置（API Key/危险操作/崩溃日志）
│   └── other/                 #   通讯录/日记/论坛/姻缘/平行世界…
├── utils/        (11 文件)    # 工具
│   ├── ui_helpers.dart        #   ★ AppColors 语义色 token + UiHelpers（好感色/学院色）+ confirmDangerDialog
│   ├── story_text_renderer.dart # ★ 文本渲染核心（词级高亮/段落分类/输出清洗/好感提取）
│   ├── prompt_sanitizer.dart  #   ★ 输入净化（注入防御/限长 500）
│   ├── narrative_section_parser.dart # 声望变化提取
│   ├── stagnation_detector.dart     # 输入侧重复预防
│   └── …
└── widgets/      (3 文件)     # 公共组件（ScaledRichText 跟随系统缩放/npc_avatar/narrative_visuals）
```

---

## 3. 核心架构约定（改代码前必读）

### 3.1 Mixin 组合模式（最重要）
`GameProvider` 通过 `with` 组合了 **14 个 mixin**（见 `lib/providers/game_provider.dart`）。
- **跨 mixin 调用**：必须在 `game_provider_base.dart` 声明抽象方法，实现放具体 mixin。
- **新增领域系统**（如新的长期玩法）标准流程：
  1. `lib/data/xxx_data.dart` 建数据表
  2. `lib/mixins/mixin_xxx.dart` 建逻辑（`mixin GameXxxMixin on GameProviderBase`）
  3. `lib/mixins/game_provider_mixins.dart` **加 export**（漏了会编译错）
  4. `lib/providers/game_provider.dart` 的 with 列表加入
  5. 需要 Player 存状态 → `player.dart` 加字段 + 构造参数 + toJson + fromJson（**必须有老档缺省值**）
  6. 需要玩家入口 → 在 `mixin_commands.dart` 注册 `CommandDef`（指令中心面板自动出现）
  7. 需要 AI 知道 → `mixin_init.dart` 的 characterLines 注入系统提示词
  8. 补测试

### 3.2 数据层与状态层分离
- `data/` 是**纯常量/规则**（无状态、无逻辑），UI 与逻辑都从这里读。
- `models/` 是**可变状态**，全部 JSON 序列化。**新字段 fromJson 必须给缺省值**（老档兼容是本项目铁律，`_saveVersion` 自动迁移在 save_service）。

### 3.3 AI 链路（输入 → 输出）
```
玩家输入 → PromptSanitizer.sanitizeAction（注入防御）
   → mixin_narrative.processChoice（/指令 拦截；// 转义为自由文本）
   → buildPrompt（T0 系统规则 + T1 角色 + T2 NPC + T3 状态 + T4 记忆/摘要 + 前情 2 回合）
   → ai_router（多 key 负载均衡 → 熔断阈值 3 次/60s → 限流）
   → mixin_response.parseNarrativeOnly
       ├── 剥离【好感/声望】区块 → 好感提取（mixin_response_affection）
       ├── 选项行剥离 + BUG-H 校验（正文<150字且选项≥3 → 判定模型输出错误 → 重试2次）
       ├── 输出清洗：dedupeRepeatedParagraphs → stripMarkdownArtifacts → autoParagraph
       └── applyNarrativeSideEffects（好感/声望/分院/NPC登场）
```
- **注入防御双保险**：当次输入 sanitize + NPC 历史回放逐条重 sanitize。
- **降级链**：AI 正常 → 同回合重试 2 次 → 切 key/熔断 → 本地兜底叙事（玩家可见通知）→ 选项承接兜底。
- 文本渲染（高亮/分段）统一走 `StoryTextRenderer`；改文案格式**不要**在 UI 层另写一套解析。

### 3.4 指令系统
- 注册在 `mixin_commands.dart` 的 `_registerCommands()`（`CommandDef` 含 primary/aliases/group/helpText/handler）。
- **指令中心面板（command_center_panel.dart）自动从 CommandRegistry 读取**——加新指令无需改面板；参数占位符同时识别 `<尖括号>` 与 `[方括号]`。
- `/` 开头的自由文本会被当指令；想发 `/` 内容用 `//` 前缀。

### 3.5 主题与颜色
- 全局语义色一律用 `AppColors`（`utils/ui_helpers.dart`）：gold/danger(#EF4444)/success(#10B981)/warning(#F59E0B)/三灰阶文本。
- **不要**在页面里裸写新的 `Color(0xFF...)`（历史遗留 ~700 处正在收敛中，新代码不许增加）。
- 好感色映射统一 `UiHelpers.getAffectionColor`（8 档，别在页面里另写）。

---

## 4. 测试契约（最容易坑到模型的地方）

`test/` 下除常规单元测试外，有一批**「源码扫描测试」**——它们会读 `lib/` 源码文本并断言其中包含特定字符串/结构。**改了源码而不同步这些断言，测试必挂**：

| 测试文件 | 扫描对象 | 改代码时注意 |
|---|---|---|
| `narrative_format_test.dart` | game_narrative_tab.dart / story_text_renderer.dart | 渲染方法名（_buildBodyCard/parseParagraph 等）被字符串断言 |
| `progression_fix_test.dart` | 全 lib | 「手写属性表」检测：**不要**用 `Map<String,String>` 写属性→中文名对照，用 `attributeLabel()`；「界面可达性」：新页面类名必须在某处被引用或出现在类型化注释里，否则判死代码 |
| `command_registry_test.dart` | 指令注册 | 提示词/文案里提到的新指令必须已注册 |
| `audit_round*.dart` | 各系统 | 历史审计留下的契约（好感衰减/时间规则等） |
| `regex_hotpath_test.dart` | 正则 | 别把热点正则改成低效写法 |

**经验**：
- 改代码后全量测试只需 `flutter test`（~2 分钟）。
- 新增测试优先放 `test/new_systems_test.dart`（已有 20+ 项测试风格可参考）。
- `flutter analyze` 门禁 0 error；历史 warning 集中在 mixin_narrative/continuity（已知，勿新增）。

---

## 5. 版本与 CI 机制（别再踩版本膨胀的坑）

1. **`pubspec.yaml` 的 version 是唯一事实来源**。
2. **CI 每次 push 自动执行**：bump patch 版本号 → sync CHANGELOG（按最近 commit message 生成条目）→ flutter analyze + test → 构建 APK。
3. **不要手动在 CHANGELOG 新增版本标题**（会与 CI 打架，历史教训：一天 3.4.2→3.6.6）。
4. 版本策略（2026-09-01 起）：minor 仅限跨领域大版本；日常迭代走 patch；一天内同主题多轮合并计数。
5. 想给 CHANGELOG 写详细说明：把内容写进 **commit message body**（CI 自动取前 5 行），或用 `UPDATE_DESC.md`（CI 优先读取后删除）。

---

## 6. 按症状快速定位

| 症状 | 去哪个文件 |
|---|---|
| 想加新系统/新玩法 | §3.1 八步流程 |
| 剧情输出乱（Markdown 残留/复读/格式漂移） | `story_text_renderer.dart`（stripMarkdownArtifacts/dedupeRepeatedParagraphs）→ `mixin_response.dart` 清洗链 |
| 好感/声望不涨不扣 | `mixin_response_affection.dart`（提取回退链）→ `game_provider.dart` 的 updateNpcAffection（注意 affectionLocked 检查） |
| 时间/学年/事件不对 | `mixin_systems.dart`（_advanceWorldClock/_onSchoolYearStart/锚点触发）；锚点按学年记录（id@年级） |
| 指令找不到/面板没有 | `mixin_commands.dart` 注册；面板自动同步，检查 `CommandDef.helpText` 是否含参数占位符 |
| AI 请求失败/超时 | `ai_router.dart`（熔断/多 key）→ `deepseek_service.dart`（Dio 超时）→ `mixin_narrative.dart` 降级链 |
| NPC 聊天异常 | `npc_chat_service.dart`（历史净化/离线标记）→ `npc_chat_screen.dart`（气泡渲染/重试） |
| 存档坏了/读不了 | `save_service.dart`（备份/回滚）→ 模型 fromJson 缺省值 |
| 颜色不对/对比度低 | `ui_helpers.dart` AppColors → 页面硬编码色值（收敛中） |
| 死亡/职业/阿尼马格斯/守护神相关 | 对应 `mixin_death/career/animagus.dart` + `data/` 表 |
| git 握手失败 | `.github/GITHUB_HANDSHAKE_SOLUTION.md`（§8 沙箱恢复三板斧） |
| 版本号/CHANGELOG 乱 | §5：pubspec 唯一来源，勿手动写标题 |

---

## 7. 关键文件速查索引

| 文件 | 一句话职责 |
|---|---|
| `lib/main.dart` | 入口 + 深色主题 |
| `lib/providers/game_provider.dart` | 14 mixin 组装的主游戏 Provider |
| `lib/providers/game_provider_base.dart` | 抽象基类 + 跨 mixin 调用声明 |
| `lib/mixins/mixin_narrative.dart` | 主叙事循环（输入判定/并发守卫/AI 调用） |
| `lib/mixins/mixin_commands.dart` | 60+ 指令注册与实现 |
| `lib/mixins/mixin_response.dart` | AI 输出解析与清洗链 |
| `lib/mixins/mixin_systems.dart` | 时间/学年/锚点/学院杯/考试/职业年结 |
| `lib/utils/story_text_renderer.dart` | 文本渲染（高亮/段落分类/清洗） |
| `lib/utils/prompt_sanitizer.dart` | 输入注入防御 |
| `lib/utils/ui_helpers.dart` | AppColors token / 好感色 / 确认弹窗 |
| `lib/models/player.dart` | 玩家全量状态（含序列化） |
| `lib/services/ai_router.dart` | AI 路由（多 key/熔断/限流） |
| `lib/services/save_service.dart` | 存档/迁移/备份 |
| `lib/data/event_anchors.dart` | 时代事件锚点 |
| `test/new_systems_test.dart` | 新系统测试的参考风格 |
| `.github/GITHUB_HANDSHAKE_SOLUTION.md` | git 通道故障恢复 |

---

*文档维护：随项目演进更新。本文件由 AI 助手编写于 2026-09-01（v3.5.x），目的是降低后续维护成本。*
