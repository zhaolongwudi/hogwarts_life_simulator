# ⚡ 霍格沃茨人生模拟器 · Hogwarts Life Simulator

> **一个由 AI 驱动的魔法世界人生模拟器** —— 你不是「大难不死的男孩」，只是这个世界里一个普通又独一无二的人。

在魔法世界里活一次：去霍格沃茨上学，结识朋友与恋人，加入社团，从事喜欢的职业，选择自己的立场。**没有强制主线，没有主角光环，世界自己在运转，你只需要做你自己。**

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44%2B-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.12%2B-0175C2?style=flat-square&logo=dart&logoColor=white" />
  <img alt="版本" src="https://img.shields.io/badge/version-v5.1.8-E3B341?style=flat-square" />
  <img alt="构建" src="https://img.shields.io/github/actions/workflow/status/zhaolongwudi/hogwarts_life_simulator/android-build.yml?style=flat-square&logo=github&label=CI" />
  <img alt="测试" src="https://img.shields.io/badge/tests-1994%2B%20passed-10B981?style=flat-square" />
  <img alt="AI" src="https://img.shields.io/badge/AI%20Driven-Atria%20%7C%20DeepSeek%20%7C%20GLM%20%7C%20Agnes%20%7C%20SenseNova-79C0FF?style=flat-square" />
</p>

---

## 📑 目录

- [✨ 核心特色](#-核心特色)
- [🎮 玩法与系统](#-玩法与系统)
- [🚀 快速开始](#-快速开始)
- [🧠 配置 AI 引擎](#-配置-ai-引擎首次使用必看)
- [📖 游戏指令](#-游戏指令60)
- [🛡️ 隐私说明](#️-隐私说明)
- [📝 更新日志](#-更新日志)
- [👨‍💻 开发相关](#-开发相关)
- [📜 开源说明](#-开源说明)

---

## ✨ 核心特色

### 🌍 世界不因你而停转
学生在上课、考试、恋爱、吵架；魔法部每天在开会；对角巷商铺开张或倒闭；黑巫师不会等你准备好了才行动。学年晋升、毕业离校、时代事件按时间线推进——**玩家不干预，世界照样转**。

### 🤖 真正的自由行动
没有预设剧情分支。想做什么就输入什么——翘课去霍格莫德、研究黑魔法、跟教授吵架、向喜欢的人表白、加入俱乐部……系统不会告诉你"不能做什么"，只会告诉你"做了之后会发生什么"。

### 💕 真正"活"着的 NPC
每个角色有自己的性格、日程、目标和人际关系。教授按课表出现在教室，魁地奇队长在球场训练，有人主动追求你，也有人因你的背叛而永远记恨。还能写信、看他们之间的八卦传闻。

### 🏰 度过"漫长的离线日常"
不连 AI 也不无聊——离线模式里世界继续运转：年度节庆如约而至，奇遇随机落在你身上，羁绊好友跨好感门槛与你演一场小戏，宠物有自己的小插曲，旧友寄来回信，而你加入的社团在一点点记下你的付出。**全程 0 次 AI 调用，但记忆照常沉淀**——离线期间的长期记忆由纯本地结构化摘要接管，切回在线时 AI 依然接得上。

---

## 🎮 玩法与系统

### 📖 五个时代可选

| 时代 | 起始年份 | 氛围 |
|------|---------|------|
| 邓布利多时代 | 1892 | 魔法世界的黄金年代 |
| 亲世代 | 1971 | 掠夺者们的校园时光 |
| 一战末期 | 1976 | 战争阴影下的人人自危 |
| 子世代 | 1991 | 哈利入学的经典时期 |
| 战后重建 | 2020 | 和平年代的新生活 |

### 🧬 深度人生系统

| 系统 | 说明 |
|---|---|
| 🏆 **校园社团** | 决斗/魔药/魁地奇/快讯四社；行动对上社团干系事就攒积分，候补→活跃→骨干→王牌→传奇五阶晋升，跨阶得属性/学院分/声望；社团任务跨回合推进（接取→出力→领奖），晋升王牌/传奇时同好回访信 |
| 🍂 **年度节庆** | 万圣节/圣诞/元旦/情人节/春季寻宝/学年舞会，按日期触发、每学年一次，`/节庆 日历` 查看 |
| ✨ **奇遇** | 随机落在你身上的两段式小故事，触发回合给选项、下回合结算结局 |
| 💞 **羁绊小剧场** | 好感跨过门槛后，与亲近之人的跨回合小戏，最终幕由你抉择 |
| 🐾 **宠物生活** | 宠物偶尔有自己的小插曲，亲和跨 25/55/85 分别演一次羁绊里程碑 |
| 🦉 **猫头鹰来信** | 已结识的 NPC 主动寄来只言片语；带牵念的信进入待回信，下一回合真正回信 |
| 💀 **死亡与坏结局** | 决斗/禁林战败可能致死且不可逆；黑化会被终章定性为「被黑暗吞没的人」 |
| 💼 **毕业后职业** | 傲罗/治疗师/魔法部/记者/职业魁地奇/诅咒破解师/魔药大师……以及神奇动物照看员等岗位，成绩+属性+声望门槛，年结晋升 |
| 🐺 **阿尼马格斯** | 研习→训练→满月夜尝试→魔法部登记，形态与人格关联，失败有真实代价 |
| ✨ **守护神** | 10 种形态与人格/学院/信念关联，情绪稳定是召唤关键 |
| 📝 **考试结算** | 8 门必修 O/E/A/P/D/T 六级，期末 + 五年级 O.W.L + 七年级 N.E.W.T 真实结算 |
| 📅 **周计划** | `/计划 学习/社交/魁地奇/调查/放松/打工`，批量推进一周 |
| 🗂️ **收藏与图鉴** | **33 张 CG** 收集与 **35 项成就** 解锁，解锁路径可追溯；图鉴里的角色档案随羁绊与来信不断丰富 |

### 🧪 扩展玩法

物品真实可用 · 宠物互动 · 装备四槽位 · 魁地奇每周一场（胜场为学院赢分）· 巫师决斗 · 禁林探险 · 魔法生物图鉴 · 支线委托板 · 学院杯学年结算 · 传承局（下一代接管你的故事）· 拉郎配撮合 · 世界八卦传闻系统（30 天自然衰减）

### 🎈 开局稀有特质

创建角色时抽取稀有度不同的开局特质（软保底），影响属性加成与叙事走向。

---

## 🚀 快速开始

### 📱 下载 APK（推荐）

| 来源 | 链接 |
|------|------|
| 最新版（Release 稳定直链） | [HogwartLige-latest.apk](https://github.com/zhaolongwudi/hogwarts_life_simulator/releases/latest/download/HogwartLige-latest.apk) |
| 最新构建（自动构建） | [nightly.link](https://nightly.link/zhaolongwudi/hogwarts_life_simulator/workflows/android-build/main/HogwartLige-nightly.zip) |
| 历史版本 | [GitHub Releases](https://github.com/zhaolongwudi/hogwarts_life_simulator/releases) |

> nightly.link 指向最近一次**成功构建**的产物；若最近一次推送仅含文档/测试（未触发构建），该链接可能暂不可用，请用上方的 Release 稳定直链。

> 每次推送触达 App 关键路径时，CI 会自动 bump 版本、构建 Release APK 并发布到 Releases（保留最近 5 个版本）；仅文档/测试/CI 变更不会触发构建。

### 🤖 自行构建

```bash
git clone https://github.com/zhaolongwudi/hogwarts_life_simulator.git
cd hogwarts_life_simulator
flutter pub get
flutter run          # 直接跑
# 或构建 Release APK
flutter build apk --release
```

**环境要求**：Flutter 3.44+ / Dart 3.12+（Android minSdk ≥ 23）。

---

## 🧠 配置 AI 引擎（首次使用必看）

剧情由大语言模型实时生成，需要准备一个 API Key。支持多家服务商：

| 服务商 | 说明 |
|--------|------|
| **Atria** | 默认付费提供商（Atria-Dawn-Preview），出厂默认 |
| **DeepSeek** | 剧情生成质量好，价格便宜 |
| **智谱 GLM** | 有免费额度，适合新手（glm-4.7-flash） |
| **Agnes** | 响应快，适合 NPC 聊天（agnes-2.5-flash 有免费） |
| **SenseNova 商汤** | 稳定，默认模型 deepseek-v4-flash，适合摘要与轻量任务 |

**配置步骤**：游戏内「设置」→ 选提供商 → 填 API Key（加密存本机）→ 可按场景绑定不同模型 → 支持多 Key 负载均衡、限流熔断、失败自动切换提供商。

> 💡 **没配 Key 也能玩**：离线「本地模式」把世界在动的部分照常推进。本地模式还提供「AI 润色」选项——本地先成型、先落盘，AI 异步润色措辞，失败静默回退原文，绝不变成新的断点（润色走独立熔断，不影响主链路的健康 Key）。

---

## 📖 游戏指令（60+）

剧情输入框可直接输入指令。全部指令收纳在**指令中心面板**（底部终端按钮 `>_` 打开），按分组展示、实时搜索、一键执行，作弊默认折叠。

| 分组 | 指令 |
|------|------|
| **基础信息** | `/状态` `/时间` `/地图` `/通知` `/世界演化` `/城堡` `/帮助` |
| **关系情感** | `/恋爱阶段` `/恋爱等待` `/关系网络` `/声望` `/送信` `/写信` `/表白` `/拉郎配` |
| **学业成长** | `/课程 成绩` `/计划 …` `/阿尼马格斯` `/守护神` `/社团` |
| **离线世界** | `/节庆 日历` `/信 读` `/备忘` |
| **玩法活动** | `/魁地奇` `/决斗` `/禁林 探险` `/图鉴` `/委托` |
| **物品宠物** | `/使用` `/装备` `/卸下` `/宠物` |
| **世界结局** | `/职业 …` `/结局` `/传承` `/联动` |
| **作弊（默认折叠）** | `/cheat 列表` — 25+ 子命令（好感/熟练度/加隆/世界线/配对/新NPC/收藏/成就…） |

> 想发送以 `/` 开头的**普通内容**？用 `//` 开头即可（如 `// 我捡起地上那本书`）。

---

## 🛡️ 隐私说明

- **所有数据都在本地**：API Key 加密存储（secure_storage），存档自动备份 + 损坏回滚
- **不收集任何用户数据**，无远程上报、无后台统计
- 用户输入自动做 **Prompt 注入净化**（含历史回放二次净化），防越狱
- AI 服务费由你选择的提供商收取（多数有免费额度）

---

## 📝 更新日志

完整历史见 [CHANGELOG.md](./CHANGELOG.md)（由 CI 自动同步）。**最近更新：**

| 版本 | 概要 |
|------|------|
| **v5.1.8** | fix(S4/S7): 睡眠语义两表对齐 + 魁地奇训练 30 分钟 |
| **v5.1.7** | refactor(S2/S3/S12): 减法三连——每回合省约 1800 token |
| **v5.1.6** | fix(S1): CI Analyze 修复——同步 chatComplete 新增的 onDelta 参数 |
| **v5.1.5** | revert: 撤回SenseNova RPM限流 保留叙事maxTokens2000 |
| **v5.1.4** | fix(ui): 世界地图几何错位/覆盖/对比度修复+金底深字语义色收敛 |

> 版本策略：minor 仅限跨领域大版本，日常迭代走 patch，一天内同主题多轮合并计数。

---

## 👨‍💻 开发相关

> 📘 项目结构与维修导航：[PROJECT_GUIDE.md](./PROJECT_GUIDE.md)
> 🗺️ 迭代思路与后续规划（P1~P14 + roadmap）：[docs/工作思路与后续规划.md](./docs/工作思路与后续规划.md)
> 🏛️ 架构全景与 ADR：[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)
> 🔌 AI 服务对接：[docs/AI_SERVICE_API.md](./docs/AI_SERVICE_API.md)

### 技术栈

Flutter 3.44+ / Dart 3.12+ · Provider 状态管理 · JSON 存档 + secure_storage 加密 · Atria / DeepSeek / 智谱 / Agnes / SenseNova

### 构建与 CI

推送 `main` 后 GitHub Actions（[android-build.yml](.github/workflows/android-build.yml)）自动执行：

1. **质量门禁**：`flutter analyze`（0 error）→ 全量测试回归（1994+ 项）
2. **版本与产物**：触达 App 关键路径时 bump 版本 → 构建 Release APK → 同步 CHANGELOG → 发布 GitHub Release（保留最近 5 个）
3. **依赖巡检**：Dependabot 每周扫描依赖更新

### 存档兼容

存档 JSON 含 `save_version` 版本号（`lib/services/save_service.dart` 全局唯一），模型 `fromJson` 一律给老档缺省值，旧档不丢。

---

## 📜 开源说明

本项目仅供学习和交流使用。以《哈利·波特》原著七部小说为世界观正典，同人创作内容与 J.K. Rowling 及华纳兄弟无关。
