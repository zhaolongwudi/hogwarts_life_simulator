# 全方位无遗漏审查报告 v3 — 终极版

> **Hogwarts Life Simulator** — 终极全面审查  
> 覆盖前两轮全部 28 个维度 + 新增 10 个维度，共计 **38 个审查维度**，无任何遗漏  
> 日期：2026-09-07 | 三轮叠加（v1+v2+v3）  
> 152 文件 / 79,506 行 | 38 个审查维度 | 52 项问题
>
> ---
>
> ### 🔧 修复进度（报告正文已随修复同步更新）
>
> 本报告不再只是"问题清单"，同时是**修复台账**：每完成一批修复，就在对应条目上标注
> 「✅ 已修复（批次 N）」并写清改了什么、为什么这么改，再提交推送。完整流水见
> [§41 修复记录](#41-修复记录)。
>
> | 批次 | 主题 | 涉及条目 | 状态 |
> |---|---|---|---|
> | 1 | 文档与配置补齐 | DOC1 / DOC2 / DOC3 / F27 / F45 / F46 / F18 / F47 | ✅ 已推送 |
>
> **已核对为误判的条目**：DOC1（README 其实存在）、F18 / F47（`_maxRetriesPerService`
> 的注释早已解释清楚，本轮只做了二次核对）、SI1（版本号其实存在，缺的是迁移函数）。
> 详见各条目下的说明。

---

## 目录（38 维）

1. [概况与统计](#1-概况与统计)
2. [代码组织与架构](#2-代码组织与架构)
3. [序列化与数据持久化](#3-序列化与数据持久化)
4. [错误处理与异常恢复](#4-错误处理与异常恢复)
5. [状态管理](#5-状态管理)
6. [Widget 性能](#6-widget-性能)
7. [异步安全](#7-异步安全)
8. [网络层](#8-网络层)
9. [文件 I/O](#9-文件-io)
10. [测试质量](#10-测试质量)
11. [国际化与无障碍](#11-国际化与无障碍)
12. [配置管理](#12-配置管理)
13. [日志系统](#13-日志系统)
14. [构建系统与 CI/CD](#14-构建系统与-cicd)
15. [导航/路由](#15-导航路由)
16. [正则/文本解析](#16-正则文本解析)
17. [集合/内存](#17-集合内存)
18. [动画/渲染](#18-动画渲染)
19. [存储模式](#19-存储模式)
20. [导入管理](#20-导入管理)
21. [空安全](#21-空安全)
22. [Mixin 架构](#22-mixin-架构)
23. [测试数据](#23-测试数据)
24. [资源管理](#24-资源管理)
25. [依赖管理](#25-依赖管理)
26. [注释健康度](#26-注释健康度)
27. [AI 架构](#27-ai-架构)
28. [Prompt 工程](#28-prompt-工程)
29. [安全审计（新）](#29-安全审计新)
30. [性能基准（新）](#30-性能基准新)
31. [代码重复度（新）](#31-代码重复度新)
32. [设计模式一致性（新）](#32-设计模式一致性新)
33. [文档完整性（新）](#33-文档完整性新)
34. [冷启动性能（新）](#34-冷启动性能新)
35. [状态持久化完整性（新）](#35-状态持久化完整性新)
36. [回调/闭包生命周期（新）](#36-回调闭包生命周期新)
37. [延迟加载策略（新）](#37-延迟加载策略新)
38. [平台兼容性（新）](#38-平台兼容性新)
39. [问题清单总表](#39-问题清单总表)
40. [优化路线图](#40-优化路线图)
41. [修复记录](#41-修复记录)

---

## 1. 概况与统计

| 指标 | 数值 |
|------|------|
| Dart 源文件 | 152 |
| 总代码行数 | 79,506 |
| 测试文件 | 51 |
| 测试代码行数 | 15,803 |
| 审查维度 | 38 |
| 发现问题 | 52 |
| 最大文件行数 | 3,234 |
| 核心 Provider | 8 |
| Mixin 数 | 14 |
| AI 服务 | 3 |
| 测试用例数 | 1,314 |
| 当前版本 | 3.9.3 |

本报告是 **第三轮全方位无遗漏审查**，在前两轮（v1 覆盖 20 维、v2 覆盖 28 维）的基础上，新增 10 个此前遗漏的审查维度，共计 38 个维度。所有发现的问题按严重度分级（Critical / High / Medium / Low），并附有可操作的优化建议。

**审查范围说明：**
- v1 覆盖维度：20 个（基础维度）
- v2 新增维度：8 个（导航/路由、正则/文本解析、集合/内存、动画/渲染、存储模式、导入管理、空安全、Mixin 架构）
- **v3 新增维度：10 个**（安全审计、性能基准、代码重复度、设计模式一致性、文档完整性、冷启动性能、状态持久化完整性、回调/闭包生命周期、延迟加载策略、平台兼容性）
- v3 保留维度：全部 28 个 v1+v2 维度，已验证修复状态并补充新发现

---

## 2. 代码组织与架构

### F1 — _ensureCommandsRegistered() 神类 3,234 行 `[Critical] [v1]`

`lib/mixins/mixin_commands.dart` 一个方法 3,234 行，违反单一职责原则。调试、定位、维护成本极高。

**影响：** 任何命令注册的修改都需要在 3K+ 行的函数中定位，极易引入回归 bug。

### F2 — Mixin 导入膨胀 `[High] [v1]`

`mixin_init.dart` 41 行导入，`mixin_narrative.dart` 35 行，`mixin_systems.dart` 27 行。部分导入仅在极少数分支中使用。

**影响：** 编译时间增加，代码依赖关系不清晰。

### 优点：目录结构清晰

- `lib/mixins/` — 所有 GameProvider 扩展逻辑集中管理
- `lib/screens/` — 按功能拆分子目录（game/, settings/, shop/, other/）
- `lib/services/` — 所有外部服务隔离
- `lib/utils/` — 工具函数归集

---

## 3. 序列化与数据持久化

### F3 — Player.fromJson 部分字段缺少类型断言 `[High] [v1]`

`lib/models/player.dart` 中部分字段反序列化时未对 `Map<String, dynamic>` 做类型断言，旧存档升级可能静默失败。

### F4 — 存档版本无迁移机制 `[Medium] [v1]`

存档中无版本号字段，新旧格式变更时无法自动迁移，只能依赖手动清零。

### F5 — NarrativeEvent.fromJson(dynamic) 类型风险 `[Low] [v2]`

`lib/models/world_state.dart:16` 参数类型为 `dynamic`，内部自动推导，但外来数据可能引发运行时异常。

### 优点：JSON 序列化覆盖全面

- `Player`, `WorldState`, `NPC`, `LongTermMemory`, `NarrativeEvent`, `GameTime`, `ChatMessage`, `CrashEntry`, `QuestRecord`, `Scar`, `TokenUsage` 等均有 toJson/fromJson
- 手动手写序列化，无代码生成依赖，可控性强

---

## 4. 错误处理与异常恢复

### F6 — 用户可见错误信息不足 `[Medium] [v1]`

大多数 catch 块仅做 `debugPrint` 日志，用户界面无任何反馈。如网络超时、AI 服务异常等场景用户只能看到白屏或卡住。

### F7 — 前置断言完全缺失 `[High] [v1]`

全库未发现 `assert()` 调用，无法在开发阶段捕获前置条件违反。

### F8 — 部分 catch 块为空或仅日志 `[Medium] [v3 新发现]`

`liquid_glass.dart:38` 和 `game_world_tab.dart:552` 使用 `catch (_) {}` 完全静默吞异常。

**影响：** 静默吞异常会隐藏潜在 bug，导致难以排查的问题。

### F9 — 错误恢复策略缺乏统一模式 `[Medium] [v3 新发现]`

不同模块的恢复策略不一致：save_load_screen 统一显示 SnackBar，但 screens 中的 catch 块有的弹 SnackBar、有的 debugPrint、有的静默。

### 优点：try/catch 覆盖广泛

- AI 调用链路三层兜底：重试 → 切 Key → 本地兜底叙事
- 文件 I/O 操作均有 try/catch 保护
- crash_logger 和 ai_debug_logger 全面捕获异常

---

## 5. 状态管理

### F10 — notifyListeners 调用频繁 `[Medium] [v1]`

GameProvider 各 mixin 中 20+ 处 notifyListeners 调用，单次操作可能触发多次重建。

### F11 — 部分 UI 缺少 dispose 清理 `[Medium] [v1]`

部分 StatefulWidget 未在 `dispose()` 中清理控制器和订阅。

### F12 — 23 个文件使用 setState 尚未优化 `[Medium] [v1]`

大量 `setState((){})` 调用会触发整个 widget 子树重建，未使用 `ValueListenableBuilder` 或 `Selector` 做局部刷新。

### 优点：Provider 模式正确

- 使用 `ChangeNotifier` + `Provider` 模式，架构清晰
- `AppProvider` 和 `GameProvider` 职责分离
- `GameProviderBase` 抽象基类提供统一接口

---

## 6. Widget 性能

### F13 — game_narrative_tab build() 1,927 行 `[High] [v1]`

`lib/screens/game/game_narrative_tab.dart` 的 build 方法接近 2,000 行，包含大量嵌套条件和三目运算符，可读性和维护性极差。

### F14 — world_map_screen.dart 1,488 行 `[Medium] [v2]`

地图渲染单文件超 1,400 行，包含自定义 CustomPainter、手势处理、动画逻辑等，应拆分为多个文件。

---

## 7. 异步安全

### F15 — 异步操作无 CancellationToken `[Medium] [v1]`

全库未使用 `CancellationToken`、`CancelableOperation` 或 `Completer` 管理异步操作生命周期。

### F16 — SharedPreferences fire-and-forget `[High] [v2]`

多处 `SharedPreferences.getInstance().then()` 未 await、未 catch，属 fire-and-forget 模式。

### F17 — 部分异步操作未检查生命周期 `[Medium] [v3 新发现]`

`game_narrative_tab.dart:1731` 的 `Future.delayed` 后虽然有 mounted 检查，但前面的 `setState` 调用在 `Future.delayed` 之前未检查。

### 优点：mounted 检查较全面

- 19 处 `if (!mounted) return;` 检查
- 3 处 `context.mounted` 检查（Flutter 3.7+ 推荐方式）

---

## 8. 网络层

### F18 — _maxRetriesPerService = 0 注释矛盾 `[Low] [v1]`

配置值为 0 但注释称"重试 2 次"，文档与实现不一致。

> **✅ 已修复（批次 1）— 实际为「报告过期」，本轮做了二次核对**
> `lib/services/ai_router.dart:98-112` 现在的注释长达 15 行，完整写了「为什么是 0」：
> 允许重试会让单 Key 最坏耗时变成 `perCallTimeout×(n+1)+退避`（2 次重试 = 156s），
> 而全局超时在 summary 场景上限只有 60s，第一个坏 Key 就会把时间吃光。
> 注释与代码一致，**无需改动**。同类的 F47 一并核对为已修复。

### 优点：网络层健壮

- 使用 Dio 作为 HTTP 客户端，支持拦截器
- 多 Key 负载均衡和熔断机制
- ResponseCache 键含 provider+model 维度
- 降级链完整：重试 → 切 Key → 本地兜底

---

## 9. 文件 I/O

### F19 — crash_logger 同步写盘 `[Low] [v1]`

CrashLogger 在 UI 线程同步写文件，可能阻塞主线程。

### 优点：文件操作隔离

- 所有文件操作通过 `path_provider` 获取正确路径
- crash_logger 和 ai_debug_logger 独立管理文件

---

## 10. 测试质量

### F20 — 505 条源码文本断言迁移停滞 `[High] [v1]`

大量测试使用源码文本断言，需迁移至行为型断言。

### F21 — UI 测试缺失 `[Medium] [v1]`

无 Widget 测试 / 集成测试，所有测试均为纯逻辑单元测试。

### F22 — 测试文件规模分布不均 `[Medium] [v2]`

`progression_fix_test.dart` 3,038 行，占全部测试的 19%，而部分测试文件仅 200+ 行。

### 优点：测试覆盖率高

- 51 个测试文件，15,803 行测试代码
- 1,314 个测试用例全部通过
- 测试纪律三原则：注入参数与生产同侧 / 断言性质不守定义式 / 不锁实现细节

---

## 11. 国际化与无障碍

### F23 — 全中文硬编码，无国际化 `[Medium] [v1]`

所有 UI 文本直接硬编码为中文，未使用 ARB 或 l10n 框架。

### F24 — 未使用 Semantics 标签 `[Low] [v1]`

仅 5 处使用 `Semantics` widget，屏幕阅读器支持几乎为零。

---

## 12. 配置管理

### F25 — 大量硬编码魔法数字 `[Medium] [v1]`

Duration 值、padding、margin、动画时长等大量硬编码，未提取为命名常量。

### 优点：主题系统完善

- MiuiTheme 颜色 token 化
- 使用 CSS 变量风格的 Theme 设计

---

## 13. 日志系统

### F26 — debugPrint 生产环境残留 `[Low] [v1]`

20+ 处 `debugPrint` 在生产构建中仍然输出，部分日志包含敏感信息。

### 优点：日志系统分层

- `crash_logger.dart` — 崩溃日志持久化
- `ai_debug_logger.dart` — AI 调用日志专用
- 日志文件轮转（保留最近 N 条）

---

## 14. 构建系统与 CI/CD

### F27 — 缺少 Android 签名配置模板 `[Low] [v1]`

Android 构建缺少签名配置模板，新开发者需手动配置。

> **✅ 已修复（批次 1）**
> - 新增 `android/key.properties.example`：模板含 `storeFile / storePassword /
>   keyAlias / keyPassword` 四项 + 一份现成的 `keytool -genkey` 命令，复制改名即可用。
> - `android/app/build.gradle`：存在 `key.properties` 时用它签 release，
>   **不存在时自动回退 debug 签名**。回退是关键 —— CI 没有私钥也能出包，
>   不会因为加了签名配置就把构建打断。
> - `.gitignore` 追加 `android/key.properties` 与 `*.jks` / `*.keystore`，
>   模板入库、真身不入库。
> - README「构建 APK」补上这段说明。
> 决策记录见 `docs/ARCHITECTURE.md` ADR-010。

### 优点：CI 配置完整

- GitHub Actions CI 配置
- 测试全部自动运行
- Analyze 0 error

---

## 15. 导航/路由

### F28 — 路由模式混合不统一 `[Medium] [v2]`

同时使用 `Navigator.pushNamed`（命名路由）和 `Navigator.push(MaterialPageRoute(...))`（直接构造），无统一路由表。

### F29 — 硬编码导航集中在 game_phone_tab `[Medium] [v2]`

`game_phone_tab.dart` 中所有导航目标硬编码在 widget 中。

### 优点：导航逻辑基本正确

- `Navigator.pop` 使用正确，无栈泄漏
- 所有导航均在 mounted 后执行

---

## 16. 正则/文本解析

### F30 — story_text_renderer 正则密集 `[High] [v2]`

`lib/utils/story_text_renderer.dart` 中 30+ 个 `RegExp` 实例，部分在热路径中重复创建。文本渲染性能瓶颈所在。

### F31 — 部分 RegExp 未使用静态缓存 `[Low] [v2]`

部分 RegExp 未声明为 `static final`，每次方法调用都会重新编译。

### 优点：部分正则已优化

- 部分关键正则已声明为 `static final`
- 使用编译标志提升性能

---

## 17. 集合/内存

### F32 — 频繁的 List.from + sort 重建 `[Medium] [v2]`

`story_text_renderer.dart` 中多处 `.toList()..sort()` 模式，高频调用时产生大量临时对象。

### F33 — 全局缓存缺乏清理策略 `[Low] [v2]`

部分全局 Map 缓存无 LRU 或定时清理机制，长期运行可能内存泄漏。

---

## 18. 动画/渲染

### F34 — 多个 AnimationController 未释放 `[Medium] [v2]`

`liquid_glass_nav_bar.dart` 和 `miuix_components.dart` 中的 AnimationController 在 `dispose()` 中未调用 `dispose()`。

### F35 — liquid_glass 着色器每次 build 重建 `[Low] [v2]`

每次 build 都重新创建 fragment shader 实例，未做缓存。

---

## 19. 存储模式

### F36 — SharedPreferences fire-and-forget `[High] [v2]`

多处 `SharedPreferences.getInstance().then()` 未 await、未 catch，写入失败不可知。

### F37 — SharedPreferences 缺少批量写入 `[Medium] [v2]`

多个独立 `setBool`/`setInt` 调用，未使用 `SetBatch` 批量写入。

---

## 20. 导入管理

### F38 — Barrel 文件编译膨胀 `[Low] [v2]`

`game_provider_mixins.dart` 导出 9 个 mixin，`other_screens.dart` 导出 6 个 screen，Any import of these barrel files pulls in all dependencies。

### 优点：导入组织清晰

- Barrel 文件按功能域分组
- import 顺序合理（dart → flutter → 第三方 → 本地）

---

## 21. 空安全

### F39 — 大量非空断言（!） `[Medium] [v2]`

20+ 处 `!` 非空断言，如果上游数据变化可能导致运行时崩溃。

### 优点：Dart 3 空安全启用

- 项目使用 `sdk: '>=3.12.0 <4.0.0'`，Dart 3 空安全默认开启
- 大部分类型标注正确

---

## 22. Mixin 架构

### F40 — 14 个 mixin 全部混合到 GameProvider `[High] [v2]`

`GameProvider` 使用 14 个 mixin，单类承担过多职责，违反接口隔离原则。

### F41 — mixin 间存在隐式通信 `[Medium] [v2]`

Mixin 之间通过 `GameProvider` 的共享状态通信，无显式接口契约。

---

## 23. 测试数据

### F42 — 测试文件规模分布不均 `[Medium] [v2]`

`progression_fix_test.dart` 3,038 行，占总测试 19%，而部分文件仅 200+ 行。

### F43 — 测试数据设置重复 `[Medium] [v2]`

多个测试文件中的 setUp 块重复创建相似的 Player/WorldState 对象。

---

## 24. 资源管理

### F44 — 图片格式不统一，加载策略单一 `[Low] [v2]`

头像同时使用 PNG 和 JPG 格式，无 webp 或 avif 等现代格式，未使用 `cached_network_image` 或预加载策略。

### 优点：资源组织清晰

- `assets/images/avatars/` 按角色命名
- Shader 文件独立管理

---

## 25. 依赖管理

### F45 — 部分依赖版本约束过宽 `[Low] [v2]`

`cupertino_icons: ^1.0.8` 等允许 major 版本升级，可能引入 breaking change。

> **✅ 已修复（批次 1）— 附带一处事实更正**
> 先更正：Dart 的 `^1.0.8` 语义是 `>=1.0.8 <2.0.0`，**本来就不允许**跨 major，
> 所以"约束过宽"这个定性不成立。真正的问题是**上界是隐式的**，
> 「这个包我们允许它升到哪一版」要脑补 caret 规则才知道。
> 改法：`pubspec.yaml` 全部依赖改写成显式区间（`>=当前 <下一个 major`），
> 上界一律取 `pubspec.lock` 当前解析版本的下一个 major，**不收窄任何现有解析结果**
> （已逐个核对 lock：cupertino_icons 1.0.9 / dio 5.11.1 / provider 6.1.5+1 /
> shared_preferences 2.5.5 / uuid 4.6.0 / flutter_slidable 3.1.2 /
> path_provider 2.1.6 / flutter_secure_storage 9.2.4 / flutter_lints 4.0.0，全部落在区间内）。
> `flutter_secure_storage` 的上界另加了注释：9.x 要求 minSdk ≥ 23，升 10.x 前要先确认。

### F46 — 缺少依赖版本锁定检查 `[Low] [v2]`

无定期 `dart pub outdated` 检查或 Dependabot 配置。

> **✅ 已修复（批次 1）**
> 新增 `.github/dependabot.yml`：
> - `pub` 生态每周一 03:00（Asia/Shanghai）扫描，单生态最多 5 个 PR；
> - `github-actions` 生态每月扫一次（CI 里 pin 的 `actions/checkout@v4` 之类过期会有安全告警）；
> - 打 `dependencies` / `ci` 标签，commit 前缀 `chore(deps)` / `chore(ci)`。
> 与 F45 的显式上界配套：major 升级会单独成一个 PR，breaking change 不会混进无关提交。

### 优点：依赖精简

- 仅 7 个直接依赖（不含 flutter SDK）
- 无冗余或重复依赖

---

## 26. 注释健康度

### F47 — 部分注释与代码不一致 `[Medium] [v2]`

`_maxRetriesPerService = 0` 注释称"重试 2 次"，与代码矛盾。

> **✅ 已修复（批次 1）— 核对为已修复**
> 全库检索「重试 N 次」类注释，仅剩 `mixin_narrative.dart:658` 的
> `retriesLeft = 2`，那是**叙事违规自纠正**的重试（critical 级违规 / BUG-H
> 模型返回选项而非叙事时重来），与 `_maxRetriesPerService` 不是同一回事，语义自洽。
> `ai_router.dart` 侧同 F18，注释已重写完毕。

### 优点：文档注释覆盖率较高

- 大量使用 `///` 文档注释
- 关键算法和业务逻辑有详细说明

---

## 27. AI 架构

### 已修复项（第 17 轮）

- System Prompt 缓存机制
- maxTokens 精细化（narrative 4000→2000, choice 1000→500, npcChat 4000→500, summary 4000→3000）
- Token 自适应削减（>50K 降 20%）
- T2 NPC 场景感知裁剪（24→8）
- T0 阈值提升（≥4→≥5）和上限缩减（60→40）
- T3 近期事件去重
- NPC 聊天使用 API system role

### F48 — AI 服务层缺少请求超时统一管理 `[Medium] [v3]`

`deepseek_service.dart` 和 `ai_router.dart` 中不同场景的超时时间未统一管理，分散在多个文件中。

### 优点：AI 降级链完整

- 重试 2 次 → 切 Key/熔断 → 本地兜底叙事 → 选项承接兜底
- 多 Key 负载均衡
- token 使用追踪

---

## 28. Prompt 工程

### 已修复项

- 写作规则重叠消除
- NPC 聊天 Prompt 使用 system role
- 关系锚注入
- 冗余 sanitization 移除

### 优点：Prompt 设计合理

- 分层 prompt 设计（system → context → instruction）
- 信息密度监控和调节
- 格式示例丰富

---

## 29. 安全审计（新） `[新增维度]`

本维度对项目进行安全审查，涵盖 API Key 存储、输入验证、敏感信息泄露等。

### S1 — API Key 使用 flutter_secure_storage 但缺少降级策略 `[High] [v3]`

`lib/services/key_store.dart` 使用 `flutter_secure_storage` 存储 API Key。在 Android 无锁屏设备上，`flutter_secure_storage` 会自动降级到 `EncryptedSharedPreferences` 或直接报错。缺少降级后的用户提示和备用方案。

**影响：** 用户在无锁屏设备上可能无法使用 AI 功能但不知原因。

### S2 — crash_logger 可能记录敏感信息 `[Medium] [v3]`

`crash_logger.dart` 记录 `dynamic error` 和 `StackTrace`，如果 AI API 响应中包含用户对话内容或 API Key 片段，可能被写入日志文件。

**影响：** 敏感信息可能持久化到设备存储中。

### S3 — debugPrint 中的 AI 调试日志可能泄露 `[Low] [v3]`

`ai_debug_logger.dart` 和多个 mixin 使用 `debugPrint` 输出 AI 请求和响应内容，在调试模式下可能被系统日志捕获。

### 优点：安全设计亮点

- API Key 使用 `flutter_secure_storage` 而非 SharedPreferences
- 输入注入防御双保险（当次净化 + NPC 历史回放重净化）
- `//` 转义处理

---

## 30. 性能基准（新） `[新增维度]`

本维度评估项目的性能测试覆盖、性能关键路径和潜在瓶颈。

### P1 — 缺少性能基准测试 `[High] [v3]`

全项目无任何性能基准测试（benchmark test）。无渲染帧率、启动时间、AI 响应时间、序列化吞吐量等关键指标监控。

**影响：** 性能退化无法被自动检测，只能靠人工发现。

### P2 — story_text_renderer 渲染性能瓶颈 `[High] [v3]`

`story_text_renderer.dart` 2,163 行，30+ 正则表达式，每次文本渲染执行大量字符串操作。更早版本中曾因 colon 扫描死循环导致 ANR。

**影响：** 长文本渲染时可能导致 UI 卡顿。

### P3 — 频繁的集合重建 `[Medium] [v3]`

`.toList()..sort()` 模式在 story_text_renderer 中出现 10+ 次，每次调用创建新列表。热路径中频繁触发 GC。

### P4 — notifyListeners 级联触发 `[Medium] [v3]`

GameProvider 的多个 mixin 顺序调用 notifyListeners，单次用户操作可能触发 3-5 次 UI 重建。

### 已优化的性能点

- 叙事渲染死循环已修复（43ms 替代 3 分钟，3200x 提升）
- System Prompt 缓存减少重复构建
- 部分正则已静态缓存

---

## 31. 代码重复度（新） `[新增维度]`

本维度评估代码重复度，识别可提取为公共函数或类的重复模式。

### D1 — 测试数据设置重复 `[Medium] [v3]`

多个测试文件的 `setUp` 块重复创建相似的 `Player`、`WorldState`、`GameProvider` 对象，可提取为测试 fixture。

### D2 — 重复的导航模式 `[Medium] [v3]`

`Navigator.push(context, MaterialPageRoute(builder: ...))` 模式在 10+ 个文件中重复出现，可封装为辅助函数。

### D3 — 重复的 try/catch 模式 `[Low] [v3]`

`save_load_screen.dart` 中 7 个 try/catch 块结构几乎相同，仅调用方法不同。

### D4 — 重复的 SharedPreferences 读取模式 `[Low] [v3]`

`app_provider.dart` 中多次 `SharedPreferences.getInstance()` 调用，可封装为单例或缓存。

---

## 32. 设计模式一致性（新） `[新增维度]`

本维度评估项目中使用设计模式的一致性和合理性。

### 发现：设计模式使用整体一致

- **Provider 模式**：`ChangeNotifier` + `Provider` 统一使用，无 mix of Riverpod/BLoC 等
- **Mixin 模式**：14 个 mixin 全部用于 `GameProvider`，模式一致但过度集中
- **工厂模式**：`fromJson` 工厂构造函数统一使用
- **策略模式**：`AiRouter` 的降级链属于策略模式
- **单例模式**：`CrashLogger`、`AiDebugLogger` 使用单例

### DS1 — 缺少 Repository 模式 `[Medium] [v3]`

数据访问逻辑（JSON 序列化、文件读写、SharedPreferences）直接混杂在 Provider 和 Service 中，未使用 Repository 模式隔离。

**影响：** 数据源变更（如从本地文件改为数据库）需修改多个层。

### DS2 — 缺少 Service Locator 或 DI 容器 `[Medium] [v3]`

服务依赖通过构造函数注入，但无集中式 DI 容器管理生命周期。部分服务（如 `NpcChatService`）在 `GameProvider` 中延迟创建。

---

## 33. 文档完整性（新） `[新增维度]`

本维度评估项目文档的完整性和质量。

### 优点：文档覆盖较好

- `.github/霍格沃兹审查修复档案总览.md` — 审查历史完整记录
- 大量 `///` 文档注释在关键类和函数上
- CI 配置和测试运行正常

### DOC1 — 缺少 README 项目总览 `[Medium] [v3]`

项目根目录无 `README.md`，新开发者无法快速了解项目用途、架构、如何运行。

> **✅ 已修复（批次 1）— 原始描述有误，README 一直存在**
> 仓库根目录 `README.md` 有 207 行，涵盖核心特色、五个时代、玩法总览、60+ 指令、
> 隐私说明、更新日志、开发相关。**这条是 v3 报告的误判。**
> 真正存在的问题是 README 里的**事实已经过期**，本轮做了校正：
> - 徽章：Flutter 3.16+ → **3.44+**、Dart 3.2+ → **3.12+**（与 `pubspec.yaml` 的
>   `sdk: '>=3.12.0'` / `flutter: '>=3.44.0'` 对齐，写低了会让人以为老版本能跑）；
>   版本 v3.5.5 → **v3.9.3**；测试数 1254 → **1314**（与 v3 报告统计一致）。
> - AI 提供商列表里把已不在代码中的「智谱」删掉（实际是 deepseek / agnes / sensenova 三家）。
> - 「构建 APK」补正式签名说明（配合 F27）；「开发相关」补上架构文档与 API 文档的入口。
> - 「存档兼容」章节原文写的字段名 `_saveVersion` 是**错的**（实际是 `save_version`，
>   常量 `kSaveVersion` 在 `save_service.dart`），已改正。

### DOC2 — 缺少架构文档 `[Medium] [v3]`

无架构决策记录（ADR）或架构概览图，新加入者需通读代码才能理解整体架构。

> **✅ 已修复（批次 1）**
> 新增 `docs/ARCHITECTURE.md`（约 300 行）：
> - **架构全景图**（Mermaid flowchart）：UI / 状态 / 领域逻辑 / 数据 / 外部依赖五层，
>   含四条依赖方向铁律（UI 不直接碰 service、mixin 之间不互相 import、
>   `data/` 保持纯常量、模型 fromJson 必给缺省值）；
> - **11 条 ADR**：mixin 组合选型（ADR-001，含已知债与约束）、手写序列化不引代码生成
>   （ADR-002）、AI 单 Key 不重试（ADR-003）、全局超时按 Key 数算（ADR-004）、
>   老档兼容铁律（ADR-005）、存档版本号唯一来源（ADR-006）、CI 自动 bump 版本（ADR-007）、
>   **暂不引入 Repository/DI（ADR-008，附复查触发条件）**、CI 锁 flutter 版本（ADR-009）、
>   release 签名可回退（ADR-010）、依赖显式上界（ADR-011）；
> - 「一次玩家输入」的时序图（Mermaid sequenceDiagram）；
> - 末尾一张「审查项 ↔ 本文 ADR」对照表，方便后续按审查条目回查。
>
> 顺带把 DS1 / DS2 这两条「建议引入 Repository / DI 容器」明确回复了：
> 目前只有一个本地数据源，加一层无行为差异的接口不划算，写进了 ADR-008 并给了复查触发条件。

### DOC3 — 缺少 API 文档 `[Low] [v3]`

AI 服务接口（DeepSeekService、AiRouter）无外部 API 文档，第三方开发者无法集成。

> **✅ 已修复（批次 1）**
> 新增 `docs/AI_SERVICE_API.md`：组件一览、`AiScene` / `AiProvider` / `AiConfig` 说明、
> `AiRouter.chatComplete` 完整签名与四步行为、**三层超时模型表**（Dio receiveTimeout >
> 路由层 perCallTimeout，否则日志里"网关慢"和"请求挂死"长得一样）、错误模型与熔断参数、
> `NpcChatService` / `KeyStore` 用法、测试注入点（`AiRouter(services: {...})`）、
> 以及调试日志的两段式机制。
> 文中同时点出 S1（KeyStore 无降级策略）为已知缺口，避免文档把现状写得比实际更好。

---

## 34. 冷启动性能（新） `[新增维度]`

本维度评估应用冷启动路径上的性能瓶颈。

### CS1 — 启动时同步加载 SharedPreferences `[High] [v3]`

`AppProvider` 构造函数中 await `SharedPreferences.getInstance()`，阻塞启动流程直到读取完成。

### CS2 — 启动时加载所有 NPC 数据 `[Medium] [v3]`

`npc_data.dart` 1,581 行，所有 NPC 数据在启动时一次性加载到内存。可按需加载或懒加载。

### CS3 — 缺少启动画面优化 `[Low] [v3]`

启动画面为默认 Flutter 白色，无品牌启动页或预加载指示。

---

## 35. 状态持久化完整性（新） `[新增维度]`

本维度评估游戏状态持久化的完整性和一致性。

### 优点：存档覆盖全面

- `saveGame` 保存 player、worldState、npcRegistry、memory
- 所有关键模型均有 toJson/fromJson
- 世界线快照 timelineSnapshots 支持重演

### SI1 — 存档无版本号 `[High] [v3]`

存档中无格式版本号，未来模型变更时无法自动迁移旧存档。用户只能手动清零。

### SI2 — 存档完整性校验缺失 `[Medium] [v3]`

加载存档时无校验和或签名验证，损坏的存档文件可能导致静默数据丢失。

### SI3 — 部分状态可能未持久化 `[Medium] [v3]`

`AppProvider` 中的 AI 调试日志开关、快速模式开关等用户偏好通过 SharedPreferences 持久化，但 `CrashLogger` 和 `AiDebugLogger` 的日志文件路径无统一管理。

---

## 36. 回调/闭包生命周期（新） `[新增维度]`

本维度评估回调、闭包、事件订阅的生命周期管理。

### CL1 — 部分回调未在 dispose 中取消 `[Medium] [v3]`

部分 `StatefulWidget` 使用 `addListener` 或 `StreamSubscription`，但未在 `dispose()` 中调用 `removeListener` 或 `cancel()`。

### CL2 — 闭包捕获可能的内存泄漏 `[Low] [v3]`

部分匿名闭包在 `Future.delayed` 或 `Timer` 中捕获 `BuildContext`，widget 销毁后闭包仍执行。

### 优点：mounted 检查已覆盖大部分场景

- 19 处 `if (!mounted) return;` 检查
- 3 处 `context.mounted` 检查

---

## 37. 延迟加载策略（新） `[新增维度]`

本维度评估项目中延迟加载的使用情况和优化空间。

### L1 — 缺少延迟加载 `[Medium] [v3]`

项目仅在 `pubspec.yaml` 中声明了 `shaders` 和 `assets/images/avatars/`，所有资源在启动时加载。大量 NPC 数据（`npc_data.dart` 1,581 行）在启动时全部加载。

### L2 — 图片无懒加载 `[Medium] [v3]`

所有头像图片（PNG/JPG）在 widget 构建时立即加载，未使用 `FadeInImage` 或占位图策略。

### L3 — screen 级别无懒加载 `[Low] [v3]`

所有 screen 在导航时直接构建，未使用 `DeferredWidget` 或 `lazy loading` 拆分代码包。

---

## 38. 平台兼容性（新） `[新增维度]`

本维度评估项目在不同平台上的兼容性。

### 优点：平台适配亮点

- 使用 `path_provider` 获取平台无关路径
- 使用 `flutter_secure_storage` 跨平台安全存储
- Dio 跨平台网络请求

### PC1 — 仅 Android 平台 `[Medium] [v3]`

项目明确仅支持 Android（通过 `flutter_secure_storage` 的 Android 原生实现），iOS 和 Web 平台未经测试。

### PC2 — 缺少平台条件编译 `[Low] [v3]`

无 `dart:io` / `dart:html` 条件导入，Web 平台编译可能失败。

### PC3 — 缺少平台特定配置 `[Low] [v3]`

iOS 平台缺少 Info.plist 中必要的权限声明。Android 签名配置缺失。

---

## 39. 问题清单总表

本次审查共发现 **52 项** 问题，按严重度分布：

- **Critical 1** | **High 9** | **Medium 15** | **Low 8** | **v3 新增 10** | **优点 9**

| # | 问题 | 维度 | 严重度 | 版本 | 修复状态 |
|---|------|------|--------|------|---------|
| F1 | _ensureCommandsRegistered() 神类 3,234 行 | 代码组织 | Critical | v1 | — |
| F2 | Mixin 导入膨胀（41/35/27 行） | 代码组织 | High | v1 | — |
| F3 | Player.fromJson 部分字段缺少类型断言 | 序列化 | High | v1 | — |
| F4 | 存档版本无迁移机制 | 序列化 | Medium | v1 | — |
| F5 | NarrativeEvent.fromJson(dynamic) 类型风险 | 序列化 | Low | v2 | — |
| F6 | 用户可见错误信息不足 | 错误处理 | Medium | v1 | — |
| F7 | 前置断言完全缺失 | 错误处理 | High | v1 | — |
| F8 | 部分 catch 块为空或仅日志 | 错误处理 | Medium | v3 | — |
| F9 | 错误恢复策略缺乏统一模式 | 错误处理 | Medium | v3 | — |
| F10 | notifyListeners 调用频繁（20+ 次） | 状态管理 | Medium | v1 | — |
| F11 | 部分 UI 缺少 dispose 清理 | 状态管理 | Medium | v1 | — |
| F12 | 23 个文件使用 setState 尚未优化 | Widget 性能 | Medium | v1 | — |
| F13 | game_narrative_tab build() 1,927 行 | Widget 性能 | High | v1 | — |
| F14 | world_map_screen.dart 1,488 行 | Widget 性能 | Medium | v2 | — |
| F15 | 异步操作无 CancellationToken | 异步安全 | Medium | v1 | — |
| F16 | SharedPreferences fire-and-forget | 异步安全 | High | v2 | — |
| F17 | 部分异步操作未检查生命周期 | 异步安全 | Medium | v3 | — |
| F18 | _maxRetriesPerService = 0 注释矛盾 | 网络层 | Low | v1 | ✅ 批次1（核对已修复） |
| F19 | crash_logger 同步写盘 | 文件 I/O | Low | v1 | — |
| F20 | 505 条源码文本断言迁移停滞 | 测试质量 | High | v1 | — |
| F21 | UI 测试缺失 | 测试质量 | Medium | v1 | — |
| F22 | 测试文件规模分布不均 | 测试质量 | Medium | v2 | — |
| F23 | 全中文硬编码，无国际化 | 国际化 | Medium | v1 | — |
| F24 | 未使用 Semantics 标签 | 无障碍 | Low | v1 | — |
| F25 | 大量硬编码魔法数字 | 配置管理 | Medium | v1 | — |
| F26 | debugPrint 生产环境残留 | 日志 | Low | v1 | — |
| F27 | 缺少 Android 签名配置模板 | 构建系统 | Low | v1 | ✅ 批次1 |
| F28 | 路由模式混合不统一 | 导航/路由 | Medium | v2 | — |
| F29 | 硬编码导航集中在 game_phone_tab | 导航/路由 | Medium | v2 | — |
| F30 | story_text_renderer 正则密集 | 正则/文本解析 | High | v2 | — |
| F31 | 部分 RegExp 未使用静态缓存 | 正则/文本解析 | Low | v2 | — |
| F32 | 频繁的 List.from + sort 重建 | 集合/内存 | Medium | v2 | — |
| F33 | 全局缓存缺乏清理策略 | 集合/内存 | Low | v2 | — |
| F34 | 多个 AnimationController 未释放 | 动画/渲染 | Medium | v2 | — |
| F35 | liquid_glass 着色器每次 build 重建 | 动画/渲染 | Low | v2 | — |
| F36 | SharedPreferences fire-and-forget | 存储模式 | High | v2 | — |
| F37 | SharedPreferences 缺少批量写入 | 存储模式 | Medium | v2 | — |
| F38 | Barrel 文件编译膨胀 | 导入管理 | Low | v2 | — |
| F39 | 大量非空断言（!） | 空安全 | Medium | v2 | — |
| F40 | 14 个 mixin 全部混合到 GameProvider | Mixin 架构 | High | v2 | — |
| F41 | mixin 间存在隐式通信 | Mixin 架构 | Medium | v2 | — |
| F42 | 测试文件规模分布不均 | 测试数据 | Medium | v2 | — |
| F43 | 测试数据设置重复 | 测试数据 | Medium | v2 | — |
| F44 | 图片格式不统一，加载策略单一 | 资源管理 | Low | v2 | — |
| F45 | 部分依赖版本约束过宽 | 依赖管理 | Low | v2 | ✅ 批次1（定性更正） |
| F46 | 缺少依赖版本锁定检查 | 依赖管理 | Low | v2 | ✅ 批次1 |
| F47 | 部分注释与代码不一致 | 注释健康度 | Medium | v2 | ✅ 批次1（核对已修复） |
| F48 | AI 服务层缺少请求超时统一管理 | AI 架构 | Medium | v3 | — |
| S1 | API Key 缺少降级策略 | 安全审计 | High | v3 | — |
| S2 | crash_logger 可能记录敏感信息 | 安全审计 | Medium | v3 | — |
| S3 | debugPrint 中的 AI 调试日志可能泄露 | 安全审计 | Low | v3 | — |
| P1 | 缺少性能基准测试 | 性能基准 | High | v3 | — |
| P2 | story_text_renderer 渲染性能瓶颈 | 性能基准 | High | v3 | — |
| P3 | 频繁的集合重建 | 性能基准 | Medium | v3 | — |
| P4 | notifyListeners 级联触发 | 性能基准 | Medium | v3 | — |
| D1 | 测试数据设置重复 | 代码重复度 | Medium | v3 | — |
| D2 | 重复的导航模式 | 代码重复度 | Medium | v3 | — |
| D3 | 重复的 try/catch 模式 | 代码重复度 | Low | v3 | — |
| D4 | 重复的 SharedPreferences 读取 | 代码重复度 | Low | v3 | — |
| DS1 | 缺少 Repository 模式 | 设计模式 | Medium | v3 | — |
| DS2 | 缺少 DI 容器 | 设计模式 | Medium | v3 | — |
| DOC1 | 缺少 README 项目总览 | 文档完整性 | Medium | v3 | ✅ 批次1（误判，已校正过期内容） |
| DOC2 | 缺少架构文档 | 文档完整性 | Medium | v3 | ✅ 批次1 |
| DOC3 | 缺少 API 文档 | 文档完整性 | Low | v3 | ✅ 批次1 |
| CS1 | 启动时同步加载 SharedPreferences | 冷启动性能 | High | v3 | — |
| CS2 | 启动时加载所有 NPC 数据 | 冷启动性能 | Medium | v3 | — |
| CS3 | 缺少启动画面优化 | 冷启动性能 | Low | v3 | — |
| SI1 | 存档无版本号 | 状态持久化 | High | v3 | — |
| SI2 | 存档完整性校验缺失 | 状态持久化 | Medium | v3 | — |
| SI3 | 部分状态可能未持久化 | 状态持久化 | Medium | v3 | — |
| CL1 | 部分回调未在 dispose 中取消 | 回调生命周期 | Medium | v3 | — |
| CL2 | 闭包捕获可能的内存泄漏 | 回调生命周期 | Low | v3 | — |
| L1 | 缺少延迟加载 | 延迟加载 | Medium | v3 | — |
| L2 | 图片无懒加载 | 延迟加载 | Medium | v3 | — |
| L3 | screen 级别无懒加载 | 延迟加载 | Low | v3 | — |
| PC1 | 仅 Android 平台 | 平台兼容性 | Medium | v3 | — |
| PC2 | 缺少平台条件编译 | 平台兼容性 | Low | v3 | — |
| PC3 | 缺少平台特定配置 | 平台兼容性 | Low | v3 | — |

---

## 40. 优化路线图

基于三轮审查的全部发现，制定以下分阶段优化路线图：

### P0 — 立即修复（Critical，1 项）

- **F1** — 拆分 _ensureCommandsRegistered() 为多个方法/文件

### P1 — 短期修复（High，9 项）

- **F2** — 精简 Mixin 导入，按需导入
- **F3** — Player.fromJson 增加类型断言
- **F7** — 增加前置 assert 断言
- **F13** — 拆分 game_narrative_tab build 方法
- **F16/F36** — SharedPreferences 统一 await + catch
- **F20** — 推进源码文本断言迁移
- **F30** — 优化 story_text_renderer 正则性能
- **F40** — GameProvider mixin 拆分评估
- **S1** — API Key 降级策略
- **P1** — 添加性能基准测试
- **P2** — 优化 story_text_renderer 渲染性能
- **CS1** — 启动时异步加载 SharedPreferences
- **SI1** — 存档版本号 + 迁移机制

### P2 — 中期优化（Medium，15 项）

- **F4** — 存档迁移机制
- **F6** — 统一用户可见错误信息
- **F8** — 修复空 catch 块
- **F9** — 统一错误恢复模式
- **F10** — 优化 notifyListeners 调用
- **F11** — 补充 dispose 清理
- **F12** — 使用 Selector/ValueListenableBuilder
- **F14** — 拆分 world_map_screen
- **F15** — 引入 CancellationToken
- **F17** — 异步操作生命周期检查
- **F21** — 添加 UI 测试
- **F22/F42** — 平衡测试文件规模
- **F23** — 引入 ARB 国际化
- **F25** — 提取魔法数字为命名常量
- **F28** — 统一路由表
- **F29** — 解耦导航逻辑
- **F32** — 优化集合重建
- **F34** — 释放 AnimationController
- **F37** — SharedPreferences 批量写入
- **F39** — 减少非空断言
- **F41** — Mixin 间显式接口契约
- **F43/D1** — 测试 fixture 提取
- **F47** — 修复注释与代码不一致
- **F48** — 统一 AI 超时管理
- **S2** — 日志敏感信息过滤
- **P3** — 优化集合重建
- **P4** — 优化 notifyListeners 级联
- **D2** — 封装导航模式
- **DS1** — 引入 Repository 模式
- **DS2** — 引入 DI 容器
- **DOC1** — 添加 README
- **DOC2** — 添加架构文档
- **CS2** — NPC 数据懒加载
- **SI2** — 存档完整性校验
- **SI3** — 统一状态持久化
- **CL1** — 补充 dispose 取消
- **L1** — 引入延迟加载
- **L2** — 图片懒加载
- **PC1** — 评估多平台支持

### P3 — 长期优化（Low，8 项）

- F5 — NarrativeEvent.fromJson 类型加固
- F18 — 修复注释与代码矛盾
- F19 — crash_logger 异步写盘
- F24 — 添加 Semantics 标签
- F26 — 生产环境移除 debugPrint
- F27 — Android 签名配置模板
- F31 — RegExp 静态缓存
- F33 — 全局缓存清理策略
- F35 — 着色器缓存
- F38 — 优化 Barrel 文件
- F44 — 统一图片格式
- F45 — 收紧依赖版本约束
- F46 — 添加 Dependabot
- S3 — 调试日志脱敏
- D3 — 封装 try/catch 模式
- D4 — SharedPreferences 单例
- DOC3 — 添加 API 文档
- CS3 — 启动画面优化
- CL2 — 闭包生命周期管理
- L3 — Screen 懒加载
- PC2 — 平台条件编译
- PC3 — 平台配置补充

---

> **全方位无遗漏审查报告 v3 — 终极版**  
> Hogwarts Life Simulator &copy; 2026 | 三轮审查覆盖 38 个维度，发现 52 项问题  
> 审查工具：Trae Work | 报告生成日期：2026-09-07
---

## 41. 修复记录

> 本节按**批次**记录每一轮实际改了什么。规则：修一批、写一批、提交推送一批，
> 保证报告永远反映仓库的真实状态，而不是一份写完就过期的快照。
>
> 验证方式：本仓库的 GitHub Actions（`android-build.yml`）在 push 到 `main` 时会跑
> `flutter analyze --no-fatal-warnings --no-fatal-infos` + `flutter test --coverage`，
> 每个批次推送后都会看 CI 结果；CI 红了就在下一批次之前先修掉。

### 批次 1 — 文档与配置补齐（DOC1 / DOC2 / DOC3 / F27 / F45 / F46 / F18 / F47）

**改动清单**

| 文件 | 改动 |
|---|---|
| `docs/ARCHITECTURE.md` | **新增**。五层架构 Mermaid 全景图 + 四条依赖方向铁律 + 11 条 ADR + 一次输入的时序图 + 审查项对照表 |
| `docs/AI_SERVICE_API.md` | **新增**。组件一览、配置说明、`chatComplete` 签名与行为、三层超时模型表、错误模型与熔断参数、测试注入点 |
| `android/key.properties.example` | **新增**。签名配置模板 + `keytool` 生成命令 |
| `android/app/build.gradle` | 有 `key.properties` 就签 release，没有就回退 debug 签名 |
| `.gitignore` | 追加 `android/key.properties`、`*.jks`、`*.keystore` |
| `.github/dependabot.yml` | **新增**。pub 每周一扫描、github-actions 每月扫描 |
| `pubspec.yaml` | 9 个依赖全部改写成显式上界 `>=当前 <下一个 major` |
| `README.md` | 校正徽章版本/测试数/SDK 下限、删掉已不存在的「智谱」、补签名说明与文档入口、修正存档字段名 |
| `comprehensive-review-v3-2026-09-07.md` | 本报告：加修复进度表、给 8 个条目写修复说明、总表加「修复状态」列 |

**为什么先做这一批**

这一批全是**新增文件与配置**，不触碰任何 Dart 逻辑，回归风险接近于零。
先把它做掉有两个目的：一是把「改 → 更新报告 → 提交推送 → 看 CI」这条链路先跑通并验证，
后面涉及代码改动的批次才有可信的验证手段；二是 DOC2 的 ADR 里记录了后续几批的
设计立场（比如 DS1/DS2 决定不引入 Repository 与 DI），先把决策定下来，
后面动手时不会边写边改主意。

**顺带更正的三处报告误判**

1. **DOC1（缺少 README）**：README 一直存在（207 行），属误判。真正的问题是内容过期，已校正。
2. **F45（依赖约束过宽）**：`^1.0.8` 在 Dart 里等价于 `>=1.0.8 <2.0.0`，本来就不允许跨 major，
   "过宽"的定性不成立。改成显式区间的真实收益是让上界**变成看得见的事实**。
3. **SI1（存档无版本号）**：版本号一直存在（`kSaveVersion = 2`，写入 `save_version` 字段）。
   真正缺的是**迁移函数** —— `save_service.dart` 的注释里提到了 `_migrateSave`，
   但全库检索不到它的实现。这条降级为「部分属实」，迁移函数在后续批次补。

**未做的事**

- F18 / F47 只做了核对、没有改代码 —— 注释本来就写得对，改它反而是制造噪音。
- 没有因为加了签名配置就让 CI 依赖私钥（回退 debug 是刻意的，见 ADR-010）。
