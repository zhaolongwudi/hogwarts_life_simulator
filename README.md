# 哈利·波特 · 魔法纪元

> 一个 AI 驱动的魔法世界人生模拟器 — 你不是"大难不死的男孩"，你只是这个世界里，一个普通又独一无二的人。

在魔法世界里活一次：去霍格沃茨上学，结识朋友与恋人，从事你喜欢的职业，选择自己的立场。没有强制主线，没有主角光环，世界自己在运转，你只需要做你自己。

---

## ✨ 这个游戏有什么特别的？

**🌍 世界不因你而停转**

霍格沃茨的其他学生也在上课、考试、恋爱、吵架；魔法部每天在开会；对角巷的商铺在开张或倒闭；黑巫师不会等你准备好了才行动。你可以选择参与，也可以一辈子当一个安静的旁观者。还会按学年晋升，学生毕业离校，世界一年年往前走。

**🤖 真正的自由行动**

没有预设好的剧情分支。想做什么就输入什么 —— 翘课去霍格莫德、偷偷研究黑魔法、跟教授吵架、向喜欢的人表白、去麻瓜世界旅游、开一家自己的店铺……系统不会告诉你"不能做什么"，只会告诉你"做了之后会发生什么"。

**💕 真正"活"着的 NPC**

每个角色都有自己的性格、日程、目标和人际关系。教授会按课表出现在教室，魁地奇队长会在球场训练，有人会主动追求你，也有人会因为你的背叛而永远记恨在心。还能给 NPC 写信、看他们之间的八卦传闻。

**📖 五个时代可选**

| 时代 | 年份 | 氛围 |
|------|------|------|
| 邓布利多时代 | 1892 | 魔法世界的黄金年代 |
| 亲世代 | 1971 | 掠夺者们的校园时光 |
| 一战末期 | 1976 | 战争阴影下的人人自危 |
| 子世代 | 1991 | 哈利入学的经典时期 |
| 战后重建 | 2020 | 和平年代的新生活 |

**🧬 开局稀有特质抽取**

创建角色时可以抽取稀有度不同的开局特质（有软保底机制），影响你的属性加成和叙事走向。

---

## 🎮 怎么开始玩？

### 📱 方式一：直接下载 APK（推荐）

不需要任何编程知识，下载安装即可。

| 下载来源 | 链接 | 说明 |
|----------|------|------|
| **最新版（免登录）** | [nightly.link](https://nightly.link/zhaolongwudi/hogwarts_life_simulator/workflows/android-build/main/HogwartLige-nightly.zip) | 每次代码更新后自动构建，推荐使用 |
| 历史版本归档 | [GitHub Releases](https://github.com/zhaolongwudi/hogwarts_life_simulator/releases) | 所有正式版本 |

### 🤖 方式二：自己构建

需要 Flutter 开发环境（适合想自己改代码的朋友）：

```bash
git clone https://github.com/zhaolongwudi/hogwarts_life_simulator.git
cd hogwarts_life_simulator
flutter pub get
flutter run
```

---

## 🧠 配置 AI 引擎（首次使用必看）

游戏剧情由大语言模型实时生成，你需要准备一个 AI 服务商的 API Key。目前支持 4 家：

| 服务商 | 说明 |
|--------|------|
| **DeepSeek** | 国产模型，剧情生成质量好，付费价格便宜 |
| **智谱 AI** | 有免费额度，适合新手尝试（glm-4.7-flash） |
| **Agnes** | 响应速度快，适合 NPC 聊天场景（agnes-2.5-flash 有免费） |
| **SenseNova 商汤日日新** | 稳定，适合摘要和轻量任务 |

**配置步骤：**
1. 打开游戏 → 右下角「设置」
2. 选择你想用的 AI 提供商 → 填入 API Key → 保存（Key 会加密存储在本机）
3. （可选）为不同场景绑定不同的模型，比如"主剧情用 DeepSeek，NPC聊天用 Agnes"
4. 设置页有免费/付费模型快捷按钮可以一键选用
5. 返回首页 → 开始游戏

---

## 🎨 能玩些什么？

### 🎓 霍格沃茨的学生生活
- 分院、选课、上课、课堂互动、考试、作业、魁地奇训练
- 四大学院：格兰芬多 · 斯莱特林 · 拉文克劳 · 赫奇帕奇
- 学年晋升：每年升级，毕业离校，最终达成人生目标
- 开局稀有特质抽取（软保底机制）

### 🌍 地图探索
- **四大区域**：霍格沃茨城堡、伦敦、住宅区、霍格莫德村
- **对角巷**：奥利凡德魔杖店、丽痕书店、古灵阁银行、韦斯莱魔法把戏坊……
- **翻倒巷**：黑魔法商店，进去之前想清楚
- 地图层级导航，每个地点有专属背景氛围

### 💬 真实的 NPC 关系
- 想认识谁？去他常出现的地方找他聊天，也能通过魔法通讯写信
- 好感度系统：陌生 → 认识 → 友好 → 暧昧 → 亲密 → 恋爱
- NPC 会主动找你约会、表白、吃醋
- 伤过的心不会复原：背叛过的人，好感永远回不到从前
- 世界传闻系统：NPC 之间会互相传八卦，舆论会影响关系

### 💰 经济与职业
- 加隆 / 西可 / 纳特货币系统
- 古灵阁存钱取钱，还能打工赚钱：霍格莫德店员、魔法部实习生、对角巷商店、圣芒戈护工、古灵阁解咒员
- 商店买东西也能卖东西

### 📱 魔法手机
- **魔法通讯**：跟 NPC 发消息聊天（只显示你已经认识的人）
- **魔法论坛**：看同学们讨论八卦，自己也能发帖
- **我的日记**：系统自动记录剧情，你也可以手写；还有重播回顾功能
- **姻缘红娘**：看看 NPC 之间谁和谁般配
- **相册回忆**：CG 画廊、章节时间线、收藏夹
- **还有**：找工作、地图、背包、存档管理、人生目标

### 🏆 成就与收藏
- 20 项成就：探索、社交、经济、战斗、收藏……
- 36 张 CG：相遇、暧昧、深情、表白、心碎……按剧情自动解锁
- 多结局系统：根据人生目标完成度触发不同终章

---

## ⚡ 游戏指令

在剧情输入框输入以下指令，可以快速访问系统功能：

| 指令 | 作用 |
|------|------|
| `/世界演化` | 查看世界大局和宏观数据 |
| `/恋爱等待` | 查看当前恋爱状态 |
| `/恋爱阶段` | 查看你和每位 NPC 的关系阶段 |
| `/关系网络` | 查看人际关系网 |
| `/信 读/回/寄` | 读信 / 回信 / 给 NPC 寄信 |

---

## 🛡️ 隐私说明

- **所有数据都在你手机本地**：AI API Key 使用 `flutter_secure_storage` 加密存储，存档自动备份 + 损坏时回滚恢复
- **不收集任何用户数据**，没有远程上报，没有后台统计
- 用户自由行动与 NPC 聊天输入自动做 Prompt 注入净化，防越狱
- 实际使用的 AI 服务费由你选择的提供商收取（大多数都有免费额度）

---

## 🚀 更新日志

只记录值得关注的重大版本更新，日常小修小补、analyze 报错修复不在这里列出。

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
- **世界 NPC 列表修复**：开局不再 38 人全部「已登场」，只有剧情里正式见过面的人才会标记（独立词边界判断 + 单回合最多登记 5 人）
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

---

## 👨‍💻 开发相关（对开发者）

想自己改代码或者贡献代码？下面的信息可能有用。

### 技术栈
- Flutter 3.16.0+ / Dart 3.2.0+
- 状态管理：Provider
- 本地存储：应用文档目录下 JSON 文件；API Key 使用 flutter_secure_storage 加密

### 本地构建 Release APK
```bash
flutter build apk --release
```

### CI 自动构建
推送到 `main` 分支后，GitHub Actions 会自动：
1. 跑 `flutter analyze` 代码检查（warning 不再阻断构建）
2. 构建 Release APK
3. 上传到 nightly.link 和 GitHub Releases

### 存档版本迁移
游戏的存档 JSON 有 `_saveVersion` 版本号字段，读取时自动做跨版本迁移，保证旧档不丢。

---

## 📜 开源说明

本项目仅供学习和交流使用。以《哈利·波特》原著七部小说为世界观正典。

## 📝 更新日志

### v1.3.4 — 2026-08-22

**📋 变更说明**
fix: 修复旧剧情残留问题 - 优化上下文过滤和缓存管理

## 问题分析

旧剧情残留的3个核心原因：

### 1. resetAllState 未清理 ResponseCache

### v1.3.3 — 2026-08-22

**📋 变更说明**
feat: 添加 AI 调用调试日志系统 + 修复路由刷新问题

1. 新增 AI 调试日志模块 (AiDebugLogger):
   - 记录每回合 AI 调用的完整输入输出
   - 日志按日期保存到应用文档目录的 ai_debug_logs 文件夹
   - 支持在设置页查看、清空日志
   - 日志内容包含：时间、场景、模型、发送的 Prompt、System Prompt、返回内容、Token 统计、错误信息

### v1.3.2 — 2026-08-22

**📋 变更说明**
feat: 实现选项独立生成方案 - 解决上下文污染问题

核心思路：将选项生成与主剧情生成完全分离

1. 新增 AiScene.choice 场景：
   - 选项生成可独立路由到不同模型（默认商汤日日新）
   - 不受主剧情模型限制（如 Agnes 选项质量不稳定）

### v1.3.1 — 2026-08-22

**📋 变更说明**
fix: systemic fix for 5 narrative/context issues

1. 好感标记变体匹配:
   - extractAffectionSections/parseResponse/_promoteAffectionLines
     统一匹配【好感变化】和【好感度变化】
   - parseWithAffectionStyle 渲染层也兼容两种格式

### v1.3.0 — 2026-08-22

**📋 变更说明**
fix: CI analyze error - remove this. in method parameter

'this.' is only valid in constructor field initializers, not in regular
method parameters. Changed 'this.openingScene = station' to
'String openingScene = station' in initializeGame().

### v1.2.9 — 2026-08-22

**📋 变更说明**
fix: 4 critical issues - NPC coloring/affection separation/choice duplication/opening scene

1. NPC名字染色修复:
   - 添加查理·韦斯莱、纳威·隆巴顿等全名到角色名单
   - 名字匹配按长度降序排列，确保长名优先匹配

2. 好感度变化分离:

### v1.2.8 — 2026-08-22

**📋 变更说明**
fix: LateInitializationError - chatService reassignment crash

Root cause: 'chatService' was declared as 'late final', preventing
reassignment in resetAllState(), causing LateInitializationError on
both '开始新游戏' and intro screen '开启魔法人生' buttons.

Fix:

### v1.2.7 — 2026-08-22

**📋 变更说明**
fix: CI analyze errors - fix game_screen syntax + remove unused field

1. game_screen.dart: Move 'final affectionSections' declaration before Column return
   (Dart doesn't allow variable declarations inside list literals)
2. game_provider.dart: Remove unused _reSectionMarkers regex field

Fixes CI flutter analyze errors

### v1.2.6 — 2026-08-22

**📋 变更说明**
v1.0.1: Remove ZhipuAI + Rewrite routing + Reset fix + Token opt + Paragraph/affection UI

核心改动:
1. 【彻底删除智谱AI】
   - 从AiProvider枚举中移除zhipu
   - 删除所有zhipu相关代码（工厂/路由/余额/UI）
   - 重写默认路由：主剧情→SenseNova(商汤日日新)，摘要→SenseNova，NPC聊天→Agnes

### v1.2.5 — 2026-08-22

**📋 变更说明**
Fix narrative loss after app restart + improve response parsing

- Remove split(paragraph).first truncation in _extractNarrativeFromRawText that
  permanently dropped all but first paragraph when AI forgot section markers
- Widen choice regex: fullwidth letters, digits, chinese numerals, more separators
- Rewrite _parseResponse as state machine: default to everything before the first
  option line as narrative, preserve blank lines inside paragraphs

### v1.2.4 — 2026-08-22

**📋 变更说明**
修复3个核心问题：好感度染色+剧情沉浸+新游戏重置

1. 修复名字+好感度染色失效
   - 补全角色名：新增『莉莉』『詹姆』『塞德里克』『卢娜』『小天狼星』等昵称
   - 改进冒号说话人识别：说话人可出现在句号/问号/感叹号等句子分隔符之后（解决心中涌起一股暖流。莉莉：+5不染色问题）
   - 新增裸好感度行识别：正文里直接出现的『姓名：+5（说明）』『马尔福 -3』等独立行，自动包装为【好感度变化】区块，统一淡色斜体渲染

### v1.2.3 — 2026-08-22

**📋 变更说明**
优化README首页文案，合并更新日志

- 首页文案改为面向普通玩家的描述，突出游戏特色和玩法
- 移除过度专业/代码化内容，减少技术术语
- 合并重复的更新日志为单一部分
- 只保留重大版本更新记录，日常小修小补不再列出
- 开发相关内容折叠到独立章节
