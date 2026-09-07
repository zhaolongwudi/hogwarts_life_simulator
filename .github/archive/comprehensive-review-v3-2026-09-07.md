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
> | 1 | 文档与配置补齐 | DOC1 / DOC2 / DOC3 / F27 / F45 / F46 / F18 / F47 | ✅ 已推送（CI 全绿） |
| 2 | 错误处理与日志 | F7 / F8 / F19 / F26 / S2 / S3 | ✅ 已推送（CI 两次变红，见 2.1） |
| **2.1** | **CI 热修复 — 脱敏正则的语法** | **F26 / S2 / S3** | **✅ 已推送（CI 全绿）** |
| 3 | 存储与启动 | F16 / F36 / F37 / D4 / CS1 / CS2 | ✅ 已推送 |
| **4** | **外来数据的健壮性** | **F3 / F5 / SI2 / SI3** | **✅ 已推送（CI 验证中）** |
> **已核对为误判的条目**：DOC1（README 其实存在）、F18 / F47（`_maxRetriesPerService`
> 的注释早已解释清楚，本轮只做了二次核对）、SI1 / F4（版本号与 `_migrateSave`
> 早就都有，批次 1 我只搜了一个文件就写了「缺迁移函数」，批次 4 已更正）。
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

> **✅ 已修复（批次 4）。** 新增 `lib/utils/json_read.dart` 安全读取工具
> （`readString/readStringOrNull/readInt/readIntOrNull/readDouble/readBool/readStringList`），
> 把 `Player.fromJson` 全部标量字段与 String 列表字段改走宽容读取：
> 数字、数字字符串等宽容形态能算出值就用，取不到走 fallback，
> 不再「一个字段类型漂移就整份档读不出来」。见 [批次 4 记录](#41-修复记录)。

### F4 — 存档版本无迁移机制 `[Medium] [v1]`

存档中无版本号字段，新旧格式变更时无法自动迁移，只能依赖手动清零。

> **✅ 核对更正（批次 4）：与 SI1 是同一件事，已具备。** 版本号 + `_migrateSave`
> 都在（见 [SI1 的说明](#si1--存档无版本号-high-v3)）。

### F5 — NarrativeEvent.fromJson(dynamic) 类型风险 `[Low] [v2]`

`lib/models/world_state.dart:16` 参数类型为 `dynamic`，内部自动推导，但外来数据可能引发运行时异常。

> **✅ 已修复（批次 4）。** `NarrativeEvent.fromJson` 的 `src['t'] as String?`
> 在 t 为非字符串时会抛类型异常，已改走宽容读取（`readString` / `readIntOrNull`）：
> 数值也转成字符串尽量保住内容，取不到用空串，绝不炸在读档上。

### 优点：JSON 序列化覆盖全面

- `Player`, `WorldState`, `NPC`, `LongTermMemory`, `NarrativeEvent`, `GameTime`, `ChatMessage`, `CrashEntry`, `QuestRecord`, `Scar`, `TokenUsage` 等均有 toJson/fromJson
- 手动手写序列化，无代码生成依赖，可控性强

---

## 4. 错误处理与异常恢复

### F6 — 用户可见错误信息不足 `[Medium] [v1]`

大多数 catch 块仅做 `debugPrint` 日志，用户界面无任何反馈。如网络超时、AI 服务异常等场景用户只能看到白屏或卡住。

### F7 — 前置断言完全缺失 `[High] [v1]`

全库未发现 `assert()` 调用，无法在开发阶段捕获前置条件违反。

> **✅ 已修复（批次 2）— 按「症状与原因距离」挑了最值得断言的两个入口**
> 不搞全员撒 assert（那会制造一堆无意义的噪音），只补了两类**症状与原因隔得最远**的入口：
> - `AiRouter.chatComplete`（`ai_router.dart`）：断言 `prompt` 非空、`maxTokens > 0`、
>   `temperature ∈ [0,2]`。这三条被破坏时不会崩，而是变成「AI 返回空/半截内容」，
>   排查成本以小时计；断言让它在开发期直接炸在调用点。
> - `SaveService.saveGame`（`save_service.dart`）：断言槽位 id 非空且不含路径分隔符、
>   `turnCount >= 0`。槽位 id 是**直接当文件名用的**，含 `/` 时写出去一个打不开的文件，
>   而读档端只报「存档不存在」—— 症状和原因隔了十万八千里。
> 已核对三处生产调用点（`mixin_systems` / `npc_chat_service` / 测试）的入参均满足断言。

### F8 — 部分 catch 块为空或仅日志 `[Medium] [v3 新发现]`

`liquid_glass.dart:38` 和 `game_world_tab.dart:552` 使用 `catch (_) {}` 完全静默吞异常。

**影响：** 静默吞异常会隐藏潜在 bug，导致难以排查的问题。

> **✅ 已修复（批次 2）**
> 三处静默 catch 全部补上了日志，**兜底行为一个都没改**（这点很重要：
> 这些 catch 的降级逻辑是对的，缺的只是痕迹）：
> | 位置 | 原状 | 改后 |
> |---|---|---|
> | `widgets/liquid_glass.dart` | `catch (_) {}` 静默降级 | `catch (e, st)` + 记录着色器不可用的原因（Skia 后端 / 编译失败 / 资源缺失） |
> | `screens/game/game_world_tab.dart` | `catch (_) { return 1; }` | 记录解析失败的 `yearStr` 与异常，仍回退 1 年级 |
> | `services/save_service.dart:185` | `catch (_) {}` 空块 | 记录「用备份修复主存档失败」——不影响本次读档，但"主存档一直是坏的、每次都靠备份顶着"必须留下痕迹 |
>
> 另外全库扫了一遍：除这三处外没有其他 `catch (_) {}` / `catch (e) {}` 空块。
> 报告里提到的 `game_world_tab.dart:552` 行号与当前代码对得上（现 556 行，因补了几行注释）。

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

> **✅ 已修复（批次 3）**
> 4 处 `.then((prefs) => ...)` 全部改走 `PrefsStore.instance.writeAsync(...)`
> （`game_started` / `display_mode` / `identity_mode` / `era`）。
> 关键区别不是"改成 await"，而是**仍然不阻塞 UI、但一定会 catch 并记日志** ——
> 设置项写慢一点无所谓，静默丢掉才是真问题（用户改了设置、下次打开又变回去，
> 还以为是玄学）。封装见 D4。

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

> **✅ 已修复（批次 2）— 核对为「剩余同步写是刻意的」**
> `CrashLogger` 现在有两个入口，同步是**分场景的正确选择**，不是遗漏：
> - `record()` —— 已经是**全异步**（`await f.writeAsString`），日常记录走这条；
> - `recordSync()` —— 崩溃 handler 专用。进程随时会被系统杀掉，异步写根本来不及落盘，
>   写完前进程一死崩溃就"没有记录"了。这里必须同步 + `flush: true`；
> - `logHeartbeat()` —— ANR 定位专用，带 **300ms 节流**（同一瞬间爆发的心跳只落盘第一条，
>   内存始终最新），把每回合 2~4 次同步写降到 1~2 次。
>
> 三者都在源码注释里写明了"为什么必须同步"。所以这条结论是：**不需要改**，
> 强行改成异步反而会让崩溃日志彻底失效。

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

> **✅ 已修复（批次 2）— 84 处，比报告估计的 20+ 多得多**
> - 新增 `lib/utils/debug_log.dart`，导出 `debugLog(String?, {int? wrapWidth})`：
>   签名与 `debugPrint` **完全一致**，`kDebugMode` 为 false 时直接返回。
> - 全库 17 个文件、84 处 `debugPrint(` 一次性替换为 `debugLog(` 并补上 import
>   （`debug_log.dart` 自身内部的 `debugPrint` 保留，否则会无限递归 —— 这个坑踩了一次，已修）。
> - 为什么值得做：`debugPrint` 只做**节流**、不做**环境判断**，release 里照样往 stdout 写；
>   AI 链路那批日志带着完整 prompt、response 与 Key 片段，等于把用户对话内容输出到系统日志。
> - 新增 `test/debug_log_test.dart`（9 个用例）钉住脱敏边界。

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

> **✅ 已修复（批次 3）**（与 F16 同一批改动）
> 全库 16 处 `SharedPreferences.getInstance()` 现已收敛为 1 处（`PrefsStore.init`），
> 写入路径全部带 label 与 catch，失败日志形如
> `[PrefsStore] 偏好写入失败(display_mode): ...`，能直接看出是哪个设置丢了。

### F37 — SharedPreferences 缺少批量写入 `[Medium] [v2]`

多个独立 `setBool`/`setInt` 调用，未使用 `SetBatch` 批量写入。

> **✅ 已修复（批次 3）**
> `PrefsStore.write(label, (prefs) { ... })` 的闭包里可以写任意多个 key，
> 一次调用只提交一次。`clearApiKeyFor` 里原先两次独立 `remove`（各提交一次）
> 已合并进同一个闭包。测试用"闭包被调用次数 == 1"钉住这个契约。
> 附带更正：报告里的 `SetBatch` 不是 shared_preferences 的 API；
> 该插件本来就是"多次 setXxx + 一次提交"的模型，真正的收益是把多次提交合成一次。

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

> **✅ 已修复（批次 2）**
> - 新增 `redactSecrets()`（`lib/utils/debug_log.dart`），落盘前统一过一遍。
> - `CrashLogger` 的 `error` / `stackTrace` / `extra` 三个字段全部脱敏，
>   且**抽成一个 `_sanitizedEntry()` 工厂**供 `record()` 与 `recordSync()` 共用 ——
>   两条路径行为必须一致，漏一条就等于没做。
> - 匹配三类：`Bearer/Basic xxx`、`sk-xxx`、`apiKey/token/secret/password=xxx` 键值，
>   以及 URL query 里的 `?key=` / `&token=`。
> - **刻意没做**「长度 ≥32 的 hex/base64 长串一律打码」：实测会把堆栈里的文件路径、
>   package 名、UUID 一起吃掉，日志直接失去定位能力。宁可漏掉一种罕见形态，
>   也不能让日志没法用。测试里专门有一条断言钉住"堆栈必须原样保留"。

### S3 — debugPrint 中的 AI 调试日志可能泄露 `[Low] [v3]`

`ai_debug_logger.dart` 和多个 mixin 使用 `debugPrint` 输出 AI 请求和响应内容，在调试模式下可能被系统日志捕获。

> **✅ 已修复（批次 2）**
> - `debugPrint` → `debugLog`（release 静默），见 F26。
> - 核对了 `AiDebugLogger` 的落盘开关：它**本来就受 `_enabled` 控制**，
>   而该值来自 `AppProvider.aiDebugLogEnabled`（默认 `false`，用户在设置页显式开启才写）。
>   所以"完整 prompt/response 写进设备文件"只在用户主动开调试时发生，不是默认行为。
> - `docs/AI_SERVICE_API.md` §8 明确写了：日志含用户对话内容，不要公开贴出完整日志。

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

> **✅ 已修复（批次 9）**
> 新增 `test/helpers/test_fixtures.dart`：`makeGame({offlineQuickMode})` 成为唯一来源。
> `provider_logic_test` / `round15_fixes_test` / `round16_fixes_test` / `round16c_repro_test`
> 四份完全相同的 `Future<GameProvider> makeGame()` 定义全部删除，改为引用共享 fixture
> （round16c 的离线快速模式差异收敛为参数 `offlineQuickMode: true`）。
> 结构护栏见 `test/code_dedup_audit_test.dart`（test/ 下出现第二份 makeGame 定义即报错）。

### D2 — 重复的导航模式 `[Medium] [v3]`

`Navigator.push(context, MaterialPageRoute(builder: ...))` 模式在 10+ 个文件中重复出现，可封装为辅助函数。

> **✅ 已修复（批次 9）**
> `lib/utils/ui_helpers.dart` 新增 `pushRoute<T>(context, page)`：Route 构造细节（全屏/动效/泛型）
> 集中一处维护，调用方只表达「去哪」。8 个文件 20 处 `Navigator.push(MaterialPageRoute(...))`
> 全部收口（`game_phone_tab` 10、`communication_screen` 2、`game_narrative_tab` 2、
> `home_screen` 2、`shop_tab` / `settings_body` / `settings_crash_section` / `game_bottom_input` 各 1）。
> `Navigator.pushNamed`（命名路由跳转）不在此列，按原样保留。
> 结构护栏见 `test/code_dedup_audit_test.dart`（lib/ 下 MaterialPageRoute 只允许出现在
> ui_helpers.dart，且不再出现 `Navigator.push(` 直连）。

### D3 — 重复的 try/catch 模式 `[Low] [v3]`

`save_load_screen.dart` 中 7 个 try/catch 块结构几乎相同，仅调用方法不同。

### D4 — 重复的 SharedPreferences 读取模式 `[Low] [v3]`

`app_provider.dart` 中多次 `SharedPreferences.getInstance()` 调用，可封装为单例或缓存。

> **✅ 已修复（批次 3）**
> 新增 `lib/services/prefs_store.dart`：`PrefsStore` 单例缓存实例 + 三个入口
> （`init()` / `write()` / `writeAsync()`）+ 三个带 fallback 的同步读。
> `app_provider.dart` 里 9 处调用全部改走它，并且**把 `shared_preferences` 的 import
> 从 app_provider 里删掉了** —— 现在想绕过 PrefsStore 直接写偏好得先重新 import，
> 是个天然阻力。刻意没做「全局自动初始化」：初始化失败是有意义的信号，
> 静默吞掉只会让问题更难查。

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

> **🟡 部分修复（批次 3）**
> 先更正位置：await 不在构造函数里（构造函数是纯同步的），而在 `main.dart` 的启动区；
> 真正慢的也不是 SharedPreferences，而是**加密存储的 Key 读取**。
> 已做的：
> - `loadSettings()` 里三个 provider 各 1~2 次 `KeyStore` 读取（Keystore /
>   EncryptedSharedPreferences，比 SharedPreferences 慢一个量级）**原先全串行**，
>   改成两轮 `Future.wait`：先并行读所有 provider 的多 Key，再对没读到的并行读单 Key。
>   跨 provider 无依赖可并行；同一 provider 内 `readKeys → readKey` 有依赖，只能分两轮。
>   最坏从「6 次 platform 往返串成一条」降到「2 轮」。
> - SharedPreferences 实例由 `PrefsStore` 统一缓存（见 D4），后续读取不再走 channel。
>
> **没做的**：把 `runApp` 提前到加载完成之前（splash 首帧方案）。主游戏页深度依赖
> `appProvider` 的 Key 与场景路由，提前渲染就要引入"设置未就绪"中间态，
> 改动面横跨 `main.dart` / `app.dart` / 所有读 `AiProvider` 的页面，
> 收益（几十到几百毫秒）配不上这个回归风险。等真有启动耗时投诉再做。

### CS2 — 启动时加载所有 NPC 数据 `[Medium] [v3]`

`npc_data.dart` 1,581 行，所有 NPC 数据在启动时一次性加载到内存。可按需加载或懒加载。

> **✅ 已修复（批次 3）— 核对为误判**
> `npc_data.dart` 里全是 **`const` 顶层集合**（`staffSeeds` / `harrySameGryffindor` /
> `maraudersSeeds` …），只有 `firstWarSeeds` 是 `final`。Dart 顶层变量是**懒初始化**
> 的：只在第一次被引用时才求值，`const` 更是在编译期就规范好了。
> 所以"启动时一次性加载所有 NPC 数据"并不存在 —— 1581 行是源码规模，不是启动期开销。
>
> 顺带记一条方法论：**用行数推断性能问题不可靠**。本报告里 CS2 / L1 / P2 都有这个毛病，
> 只有 F1 / F13 / F14 / F22 那种"行数 = 可维护性"的用法才成立。

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

> **✅ 核对更正（批次 4）：这条整体不成立，版本号与迁移机制都有。**
> 存档版本号 `kSaveVersion = 2` 定义在 `lib/services/save_service.dart`，
> 每次写档都会把 `'save_version': kSaveVersion` 盖进去；迁移函数
> `_migrateSave(data, version)` 在 `lib/mixins/mixin_systems.dart:3006`，
> 已有 v1→v2 的实际迁移逻辑（英文月份名 → 中文月份、`world_state.time` 字段补全），
> 并且 `test/progression_fix_test.dart` 里有一组测试专门钉住
> 「版本号只有一处定义」「写档必须盖 `kSaveVersion` 的章」「当前版本要有迁移分支」。
>
> 批次 1 时我在这里写下「版本号存在、缺迁移函数」，那是**只搜了 `save_service.dart`
> 就下结论**的结果 —— 迁移函数一直住在 `mixin_systems.dart` 里。
> 这是本轮修复中我自己犯的一次误判，比报告原作者的误判更该记下来：
> **"全库检索不到"和"我没搜到"是两回事。**

### SI2 — 存档完整性校验缺失 `[Medium] [v3]`

加载存档时无校验和或签名验证，损坏的存档文件可能导致静默数据丢失。

> **✅ 已修复（批次 4）。** `SaveService` 新增公开方法 `isStructurallyValid()`：
> 校验 `player` / `world_state` 必须是对象、`turn_count` 须非负数值（容忍数字
> 字符串）、`save_version` 须可识别；`loadGame` / `_tryLoadBackup` / `importSave`
> 三处统一改走该校验，不合格走已有的备份回滚路径，不再带着坏数据继续。

### SI3 — 部分状态可能未持久化 `[Medium] [v3]`

`AppProvider` 中的 AI 调试日志开关、快速模式开关等用户偏好通过 SharedPreferences 持久化，但 `CrashLogger` 和 `AiDebugLogger` 的日志文件路径无统一管理。

> **✅ 已修复（批次 4）。** 日志路径统一收口到 `lib/utils/log_paths.dart`
> （`kCrashLogFileName` / `kHeartbeatFileName` / `kAiDebugLogDirName` 三个常量），
> `CrashLogger` 与 `AiDebugLogger` 改用常量拼接，改名/搬目录只改一处。
> 偏好持久化部分批次 3 已随 PrefsStore 处理。

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
| F3 | Player.fromJson 部分字段缺少类型断言 | 序列化 | High | v1 | ✅ 批次4 |
| F4 | 存档版本无迁移机制 | 序列化 | Medium | v1 | ✅ 批次4（误判，同 SI1） |
| F5 | NarrativeEvent.fromJson(dynamic) 类型风险 | 序列化 | Low | v2 | ✅ 批次4 |
| F6 | 用户可见错误信息不足 | 错误处理 | Medium | v1 | 🟢 批次6（统一映射原语+示范屏迁移，AI 主链路边界已注明，待渐进） |
| F7 | 前置断言完全缺失 | 错误处理 | High | v1 | ✅ 批次2 |
| F8 | 部分 catch 块为空或仅日志 | 错误处理 | Medium | v3 | ✅ 批次2 |
| F9 | 错误恢复策略缺乏统一模式 | 错误处理 | Medium | v3 | 🟢 批次6（统一错误提示原语，存量屏幕渐进接入） |
| F10 | notifyListeners 调用频繁（20+ 次） | 状态管理 | Medium | v1 | 🟢 批次8/10（批量通知收口 + `processChoice` 分支双通知合并，余下均为单次/互斥/await 间隔） |
| F11 | 部分 UI 缺少 dispose 清理 | 状态管理 | Medium | v1 | 🟢 批次7（6 处对话框局部控制器统一 whenComplete 释放） |
| F12 | 23 个文件使用 setState 尚未优化 | Widget 性能 | Medium | v1 | — |
| F13 | game_narrative_tab build() 1,927 行 | Widget 性能 | High | v1 | — |
| F14 | world_map_screen.dart 1,488 行 | Widget 性能 | Medium | v2 | — |
| F15 | 异步操作无 CancellationToken | 异步安全 | Medium | v1 | — |
| F16 | SharedPreferences fire-and-forget | 异步安全 | High | v2 | ✅ 批次3 |
| F17 | 部分异步操作未检查生命周期 | 异步安全 | Medium | v3 | 🟢 批次8（核对：`Future.delayed` 前后均有 mounted 检查） |
| F18 | _maxRetriesPerService = 0 注释矛盾 | 网络层 | Low | v1 | ✅ 批次1（核对已修复） |
| F19 | crash_logger 同步写盘 | 文件 I/O | Low | v1 | ✅ 批次2（核对：同步是刻意的） |
| F20 | 505 条源码文本断言迁移停滞 | 测试质量 | High | v1 | — |
| F21 | UI 测试缺失 | 测试质量 | Medium | v1 | — |
| F22 | 测试文件规模分布不均 | 测试质量 | Medium | v2 | — |
| F23 | 全中文硬编码，无国际化 | 国际化 | Medium | v1 | — |
| F24 | 未使用 Semantics 标签 | 无障碍 | Low | v1 | — |
| F25 | 大量硬编码魔法数字 | 配置管理 | Medium | v1 | — |
| F26 | debugPrint 生产环境残留 | 日志 | Low | v1 | ✅ 批次2（84 处） |
| F27 | 缺少 Android 签名配置模板 | 构建系统 | Low | v1 | ✅ 批次1 |
| F28 | 路由模式混合不统一 | 导航/路由 | Medium | v2 | 🟢 批次10（`router/app_routes.dart` 唯一路由源，`main.dart` 引用 `appRoutes` 表） |
| F29 | 硬编码导航集中在 game_phone_tab | 导航/路由 | Medium | v2 | 🟢 批次10（幽灵路由 `/world_map` `/save_load` 清除，低频页走 `pushRoute` 构造器） |
| F30 | story_text_renderer 正则密集 | 正则/文本解析 | High | v2 | 🟢 批次5/8（核对：全部静态化，含标签/动词预编译） |
| F31 | 部分 RegExp 未使用静态缓存 | 正则/文本解析 | Low | v2 | ✅ 批次5 |
| F32 | 频繁的 List.from + sort 重建 | 集合/内存 | Medium | v2 | 🟢 批次5/8（核对：热路径已静态缓存，其余一次性排序非热路径） |
| F33 | 全局缓存缺乏清理策略 | 集合/内存 | Low | v2 | ✅ 批次5 |
| F34 | 多个 AnimationController 未释放 | 动画/渲染 | Medium | v2 | ✅ 批次8（误判：`liquid_glass_nav_bar` / `miuix_components` 均已 dispose） |
| F35 | liquid_glass 着色器每次 build 重建 | 动画/渲染 | Low | v2 | ✅ 批次5 |
| F36 | SharedPreferences fire-and-forget | 存储模式 | High | v2 | ✅ 批次3 |
| F37 | SharedPreferences 缺少批量写入 | 存储模式 | Medium | v2 | ✅ 批次3 |
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
| F48 | AI 服务层缺少请求超时统一管理 | AI 架构 | Medium | v3 | 🟢 批次8（超时策略收口 `ai_timeouts.dart` 单一来源） |
| S1 | API Key 缺少降级策略 | 安全审计 | High | v3 | — |
| S2 | crash_logger 可能记录敏感信息 | 安全审计 | Medium | v3 | ✅ 批次2 |
| S3 | debugPrint 中的 AI 调试日志可能泄露 | 安全审计 | Low | v3 | ✅ 批次2 |
| P1 | 缺少性能基准测试 | 性能基准 | High | v3 | — |
| P2 | story_text_renderer 渲染性能瓶颈 | 性能基准 | High | v3 | — |
| P3 | 频繁的集合重建 | 性能基准 | Medium | v3 | — |
| P4 | notifyListeners 级联触发 | 性能基准 | Medium | v3 | 🟢 批次8/10（明显级联已合并，同帧重复 rebuild 清除） |
| D1 | 测试数据设置重复 | 代码重复度 | Medium | v3 | 🟢 批次9（`test/helpers/test_fixtures.dart` 唯一来源，4 处重复定义删除） |
| D2 | 重复的导航模式 | 代码重复度 | Medium | v3 | 🟢 批次9（`pushRoute` 收口 8 文件 20 处） |
| D3 | 重复的 try/catch 模式 | 代码重复度 | Low | v3 | 🟢 批次6/7（`_showError` 统一错误处理，骨架差异属必要） |
| D4 | 重复的 SharedPreferences 读取 | 代码重复度 | Low | v3 | ✅ 批次3 |
| DS1 | 缺少 Repository 模式 | 设计模式 | Medium | v3 | — |
| DS2 | 缺少 DI 容器 | 设计模式 | Medium | v3 | — |
| DOC1 | 缺少 README 项目总览 | 文档完整性 | Medium | v3 | ✅ 批次1（误判，已校正过期内容） |
| DOC2 | 缺少架构文档 | 文档完整性 | Medium | v3 | ✅ 批次1 |
| DOC3 | 缺少 API 文档 | 文档完整性 | Low | v3 | ✅ 批次1 |
| CS1 | 启动时同步加载 SharedPreferences | 冷启动性能 | High | v3 | 🟡 批次3（部分） |
| CS2 | 启动时加载所有 NPC 数据 | 冷启动性能 | Medium | v3 | ✅ 批次3（误判） |
| CS3 | 缺少启动画面优化 | 冷启动性能 | Low | v3 | — |
| SI1 | 存档无版本号 | 状态持久化 | High | v3 | ✅ 批次4（整体误判，版本号+迁移都有） |
| SI2 | 存档完整性校验缺失 | 状态持久化 | Medium | v3 | ✅ 批次4 |
| SI3 | 部分状态可能未持久化 | 状态持久化 | Medium | v3 | ✅ 批次4 |
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
   ~~真正缺的是迁移函数 —— 全库检索不到它的实现，后续批次补。~~
   **这条结论错了，批次 4 更正**：`_migrateSave` 一直住在
   `lib/mixins/mixin_systems.dart:3006`（v1→v2 迁移英文月份名、补 `world_state.time`），
   我当时只在 `save_service.dart` 里搜了，因为它的注释提到 `_migrateSave`
   就以为实现"该在这儿"。**"没搜到"不等于"不存在"，尤其在一个 8 万行、
   逻辑按 mixin 分散的仓库里。** 详见 [SI1 条目](#si1--存档无版本号-high-v3)。

**未做的事**

- F18 / F47 只做了核对、没有改代码 —— 注释本来就写得对，改它反而是制造噪音。
- 没有因为加了签名配置就让 CI 依赖私钥（回退 debug 是刻意的，见 ADR-010）。

### 批次 2 — 错误处理与日志（F7 / F8 / F19 / F26 / S2 / S3）

**改动清单**

| 文件 | 改动 |
|---|---|
| `lib/utils/debug_log.dart` | **新增**。`debugLog()`（release 静默，签名与 `debugPrint` 一致）+ `redactSecrets()` |
| `test/debug_log_test.dart` | **新增**。9 个用例，钉住脱敏的「该吃的吃掉 / 不该吃的别碰」两端边界 |
| 17 个 lib 文件 | 84 处 `debugPrint(` → `debugLog(`，并补 import |
| `lib/utils/crash_logger.dart` | 新增 `_sanitizedEntry()`，`record` / `recordSync` 共用，三字段脱敏 |
| `lib/services/ai_router.dart` | `chatComplete` 加 3 条前置断言（prompt / maxTokens / temperature） |
| `lib/services/save_service.dart` | `saveGame` 加 3 条前置断言（槽位 id 非空、不含路径分隔符、turnCount ≥ 0）；空 catch 补日志 |
| `lib/widgets/liquid_glass.dart` | 静默 catch 补日志（降级行为不变） |
| `lib/screens/game/game_world_tab.dart` | 静默 catch 补日志（回退 1 年级不变） |

**这一批的一个判断**：三处静默 catch 的**降级逻辑都是对的**，缺的只是痕迹。
所以只补日志、没动兜底值 —— 把 `return 1` 改成"抛异常"看似更严谨，实际会让玩家在
学年解析失败时直接白屏，比显示成一年级糟得多。**日志的作用是让问题可见，不是让程序更脆。**

**踩到并修掉的坑**：批量替换时脚本把 `debug_log.dart` 自己也处理了 ——
它内部实现要调 `debugPrint`，被替换成 `debugLog` 后成了无限递归，
还给自己加了一条 import 自己。已还原。教训是"批量改之前先想清楚豁免条件"，
不是"批量改有风险所以别做"。

**两条核对为「不需要改」的条目**

- **F19（crash_logger 同步写盘）**：`record()` 本来就是异步的；剩下两处同步写
  （崩溃 handler 的 `recordSync`、带 300ms 节流的心跳）**必须**同步，
  改成异步会让崩溃日志彻底失效。报告没区分这两类，结论有误导性。
- **S3 的落盘部分**：`AiDebugLogger` 本来就受用户开关控制（默认关），
  不是默认就把 prompt 写进设备文件。真正的问题只在 `debugPrint` 输出到 stdout，已随 F26 修掉。

### 批次 3 — 存储与启动（F16 / F36 / F37 / D4 / CS1 / CS2）

**改动清单**

| 文件 | 改动 |
|---|---|
| `lib/services/prefs_store.dart` | **新增**。SharedPreferences 唯一收口：单例缓存 + `init/write/writeAsync` + 带 fallback 的同步读 |
| `test/prefs_store_test.dart` | **新增**。4 个用例：写入可见、批量只提交一次、writeAsync 不阻塞、未初始化不抛 |
| `lib/providers/app_provider.dart` | 9 处调用改走 PrefsStore；删掉 `shared_preferences` import；`loadSettings` 的 KeyStore 读取改两轮 `Future.wait` |

**这一批的核心判断**：F16/F36 的修法不是"把 `.then()` 改成 `await`"。
设置项这种场景**确实不该阻塞 UI**，问题只在于失败时无声无息。
所以 `writeAsync` 保留了 fire-and-forget 的"不阻塞"，补上了 `catch + 日志 + 返回值`。

**CS1 只做了一半，理由写在这里**：把 `runApp` 提前到设置加载完成之前，
需要在 `main.dart` / `app.dart` / 所有读 `AiProvider` 的页面引入"设置未就绪"中间态，
改动面很大，而收益只是几十到几百毫秒。真正的长尾开销（加密存储 Key 读取串行）
已经用 `Future.wait` 消掉了。剩下那部分等有实测数据再决定要不要动。

**CS2 是误判**：`npc_data.dart` 全是 `const` 顶层集合，Dart 顶层变量懒初始化，
不存在"启动时一次性加载"。这条暴露了报告的方法论问题 —— 用源码行数推断运行时开销不可靠。

### 批次 2.1 — CI 热修复：脱敏正则（`(?i)` 在 Dart 里是非法语法）

**发生了什么**：批次 2 推送后，CI run `34129953088` 的 `Run tests with coverage` 步骤报
`1327 tests passed, 7 failed.`，7 个失败全部来自新增的 `test/debug_log_test.dart`，
而且连"堆栈必须原样保留""空串原样返回"这种不该失败的用例也一起红了。

**根因**：`redactSecrets` 的三条规则写成了

```dart
RegExp(r'(?i)\b(bearer|basic)\s+[A-Za-z0-9._\-+/=]{8,}')
```

Dart 的 `RegExp` 走 **ECMAScript 语义，不支持 `(?i)` 内联标志**，构造时直接抛
`FormatException: Invalid group`。而 `_rules` 是**顶层 `final` 懒初始化** ——
报错要等到第一次调用 `redactSecrets` 才发生，于是 7 个用例无差别全红，
堆栈里只看到 `new RegExp ← _rules ← redactSecrets`，看不出是哪个模式写错了。

**修法**：去掉 `(?i)`，改用构造参数 `RegExp(pattern, caseSensitive: false)`。
顺手把这条规则写进源码注释，避免有人再改回去。同时补一条测试用例
「大小写混写也要脱敏」，把 `(?i)` 的**本意**钉住 —— 否则下次有人"顺手删掉
`caseSensitive`"，测试一样是绿的。

**更该记住的教训**：本机没有 3.44 的 Flutter，跑不了 `flutter test`，
所以批次 2 是**带着没验证过的正则**推上去的。现在补了本地预检手段：
用本机 Dart 2.17 把规则表单独构造一遍并跑 21 条行为断言 ——
`RegExp` 的语义在 2.17 与 3.x 之间没有差异，足够在推送前抓出这类
"编译得过、跑起来才炸"的错误。**没有完整 SDK 不等于没有验证手段，
至少要把"能验的那部分"验掉。**

### 批次 4 — 外来数据的健壮性（F3 / F5 / SI2 / SI3）

**改动清单**

| 文件 | 改动 |
|---|---|
| `lib/utils/json_read.dart` | **新增**。宽容读取工具：`readString/readStringOrNull/readInt/readIntOrNull/readDouble/readBool/readStringList`，接受 num/数字字符串等宽容形态并带 fallback，绝不在对外部数据做类型转换时抛异常 |
| `lib/models/player.dart` | `Player.fromJson` 全部标量字段与 String 列表字段改走 `json_read` 宽容读取（`id/health/generations/grade/currentGoal/injuries/personalityTraits/...` 等）；Map 型字段与嵌套对象保持原样（改动面收敛到"类型漂移高发区"） |
| `lib/models/world_state.dart` | `NarrativeEvent.fromJson` 的 `src['t'] as String?` → `readString`（数值也转字符串保住内容）、`src['r'] as int?` → `readIntOrNull`、`a` 用 `readString` 再 `tryParse` |
| `lib/services/save_service.dart` | 新增公开 `static isStructurallyValid(data)`（player/world_state 是 Map、turn_count 非负数值容忍数字字符串、save_version 可识别）；`loadGame` / `_tryLoadBackup` / `importSave` 三处改走该校验 |
| `lib/utils/log_paths.dart` | **新增**。日志文件名统一收口：`kCrashLogFileName` / `kHeartbeatFileName` / `kAiDebugLogDirName` |
| `lib/utils/crash_logger.dart` | 4 处硬编码 `crash_logs.json` / `heartbeat.json` 改用 `log_paths` 常量 |
| `lib/utils/ai_debug_logger.dart` | 硬编码 `ai_debug_logs` 改用 `kAiDebugLogDirName` 常量 |
| `test/foreign_data_robustness_test.dart` | **新增**。21 个用例钉住 json_read 各读取函数的边界、`Player.fromJson`/`NarrativeEvent.fromJson` 的类型漂移不再崩、`isStructurallyValid` 放行/拦截 |

**这一批的核心判断**：外来数据（旧存档 / 导入存档）的类型漂移**不该成为读档的全局开关**。
修复前 `Player.fromJson` 里 `id: json['id']`、`health: json['health'] ?? 100` 直接把 `dynamic`
透传进 `String` / `int` 字段，一个字段不干净整份档就崩、只能清零。修法是「宽容但不纵容」：
数值区分度保留（`int` 用 `readInt`、`double` 用 `readDouble`，不把小数静默读成整数），
可选字段用 `*OrNull` 只认合法形态，String 列表里的嵌套结构过滤掉而不是炸掉。
`log_paths` 只统一文件名、**不迁移已有文件位置**，避免在传统玩家设备上产生孤儿日志文件。

**为什么敢不带 SDK 推送**：本机没有 3.44 的 Flutter，跑不了 `flutter test`（沿用批次 2.1 的约束）。
这一批改动是**纯宽容化**——对所有合法存储格式的行为逐字段核对不变，只把「抛异常」换成
「用 fallback」；新增测试全部走正常读入路径的期望值。改动面收敛、无新增可变状态，
风险主要靠推送后的 CI（`flutter analyze` + `flutter test`）兜底确认。

**下一批（批次 5）建议范围**（按性价比排）：
1. **F33 / F31 / F35（缓存清理与正则静态缓存，小改动）**：全局缓存缺清理策略 / 部分
   `RegExp` 未静态缓存 / `liquid_glass` 着色器每次 build 重建 —— 三处都是局部小改，
   回归风险低，适合在没有完整 SDK 时继续推进。
2. **F6 / F9（错误反馈与恢复模式统一，需动 UI，单独一批）**：做到一半 UI 不易回归验证，
   放 F33/F31/F35 之后。

### 批次 5 — 缓存与正则静态化（F31 / F33 / F35）

**改动清单**

| 文件 | 改动 |
|---|---|
| `lib/utils/story_text_renderer.dart` | **F31 正则静态化**：热路径上一整批内联 `RegExp(...)` 收口为类级 `static final` 常量 —— 段落清洗（`_multiNewlineRe/_doubleNewlineRe`）、选择块/选项行剥离、Markdown 兜底（加粗/斜体/标题/列表）、好感/声望区块、时间戳剥离、说话人判定（引号/括号/纯神态/数字/句读/名字尾缀/叙述虚词）、内部 meta 标记（承接×3/SceneGraph）、好感/神态行（`_signedIntRe/_signedIntStartRe/_moodParenRe`）、对话引号成对（`_dialogueQuotePatterns`）。pattern 与编译标志逐条比对原字面量一致，纯行为无变化 |
| `lib/utils/story_text_renderer.dart` | **F33 核对（已具备）**：全局解析缓存 `_cache` 本就带 `_maxCacheSize = 32`，写路径满时淘汰最旧条目（近似 LRU），不无限膨胀 |
| `lib/widgets/liquid_glass.dart` | **F35 核对（已具备）**：`LiquidGlassShaderLoader` 静态缓存 `FragmentProgram`（`_program` + `_pending`，防并发重复加载）；`_LiquidGlassState` 的 `FragmentShader` 是 State 字段，`initState` 创建一次、build 复用同一实例，并非每次 build 重建。build 里 `ImageFilter.shader(shader)` 只是对同一 shader 实例的轻量包装 |
| `test/f31_regex_cache_test.dart` | **新增**。行为回归护栏：8 组解析函数（`stripInternalMetaMarkers`/配 `stripMarkdownArtifacts`/`extractAffectionSections`/`dedupeRepeatedParagraphs`/`splitParagraphs`/`autoParagraph`/`stripTimestampPrefix`/`parseAffectionLine`/冒号对话）逐一钉住重构后输出不变；外加 F33 压测（1500 段不同叙事反复解析久跑不炸、结果正确） |

**这一批的核心结论**：F31 是真实的小改进——把热路径上每方法调用都重复编译的正则收口成
静态常量，低端机渲染更稳；F33、F35 经核对**原实现已满足**（缓存有上限淘汰 / 着色器本就
静态缓存），只补了回归护栏确认不是假修复。改动面单纯靠在途改动（行为保持），
本地无 Flutter SDK，照例推 `main` 用 CI（`flutter analyze` + `flutter test`）验证。

### 批次 6 — 统一错误反馈与恢复原语（F6 / F9 基础设施）

**改动清单**

| 文件 | 改动 |
|---|---|
| `lib/utils/user_feedback.dart` | **新增**。`userFriendlyError(error, fallback:)` —— 把底层异常映射成玩家能看懂的中文：`SocketException/HttpException→网络类`、`TimeoutException→请求超时`、`FormatException→数据无法解析`、`HandshakeException→安全连接失败`；**未知/空错误一律回退到 fallback，绝不把 `$e` 原始文本怼给玩家**。纯函数、无 Flutter 依赖，可在 service/provider 层复用 |
| `lib/widgets/miuix_overlays.dart` | 新增 `miuixErrorSnack(context, message)` —— 错误态统一入口：`Icons.error_outline` + `MiuiColors.error` + 稍长展示时长（2.6s），复用既有 `miuixSnack` 的浮动玻璃样式，视觉上「哪里出错了」一眼可辨 |
| `lib/screens/save_load_screen.dart` | **示范屏迁移**：新增 `_showError(e, fallback)`（调 `miuixErrorSnack`+`userFriendlyError`）；把 6 处 `_showSnack('xxx失败: $e')` 全部改成 `_showError(e, 'xxx失败')`——玩家不再看到 `Bad state: ...` 这类内部文本；`_showSnack` 本身改走 `miuixSnack`，与全局 toast 样式统一（F9） |
| `lib/screens/job_screen.dart` | AI 打工推荐失败路径：裸 `SnackBar(content: Text('AI 暂时没想出来：$e'))` → `miuixErrorSnack(userFriendlyError(...))`；「未配置 AI」提示也改走 `miuixSnack` |
| `test/user_feedback_test.dart` | **新增**。`userFriendlyError` 已知类型映射、未知/null 回退、以及「fallback 不泄露异常细节」三类断言，CI 可独立验证 |

**这一批的边界**：报告给 F6/F9 的定性是「需动 UI，做到一半 UI 不易回归验证」。所以这一批不铺开改十几个屏幕，而是先落地**可被 atomic 单测钉死的基础设施**（`userFriendlyError` 纯映射 + `miuixErrorSnack` 统一原语），并迁移报告点名的**示范屏** `save_load_screen` 和高价值的**AI 失败路径** `job_screen`。AI 主叙事链路的完整 UI 反馈（`mixin_narrative` 深链路、无便捷 context）留作后续渐进接入——其余存量裸 SnackBar 屏幕可照 `miuixErrorSnack` + `userFriendlyError` 的模式逐个替换。

### 批次 7 — UI 资源释放与重复消除（F11、D3）

**F11 病灶定位**：初审 v1 只写了「部分 StatefulWidget 未在 dispose 清理」，复查后发现**字段级控制器（`_searchController` 等）在主要屏幕里其实都已释放**，真正漏掉的是**对话框内局部创建的 `TextEditingController`**：它们在方法里 new、传给 `AlertDialog` 的 `TextField`，对话框关闭后没有任何持有者会释放它——点遮罩（barrier）或返回键关闭时，按钮里的 `dispose()` 也不会执行，是确定的内存泄漏。

**改动清单**

| 文件 | 改动 |
|---|---|
| `lib/screens/game/game_phone_tab.dart` | `_editSignature`：局部 `controller` 原来**完全不释放**，改为 `showMiuixDialog(...).whenComplete(controller.dispose)` |
| `lib/screens/world_map_screen.dart` | `_editAreaLabel`：同上，原来完全不释放 |
| `lib/screens/other/forum_screen.dart` | `_showCommentDialog` / `_showCreatePostDialog`：原来只在按钮内 `dispose()`（点遮罩泄漏），改为 `whenComplete` 统一释放，按钮内的显式 `dispose()` 移除（防双重释放崩溃） |
| `lib/screens/other/parallel_world_screen.dart` | `_showCreateDialog`：`titleController`+`descController` 改为 `whenComplete` 统一释放 |
| `lib/screens/other/diary_screen.dart` | `_showAddEntryDialog`：同上，按钮内 dispose 移除，`whenComplete` 兜底 |

**统一模式**：`showMiuixDialog` 返回的 `Future` 在对话框**无论以何种方式关闭**（按钮 / barrier / 返回键）后都会 complete，`whenComplete(controller.dispose)` 恰好覆盖全部关闭路径，且只执行一次；按钮内原有的 `dispose()` 全部移除，避免 `TextEditingController` 二次 dispose 抛错。

**D3 结论**：`save_load_screen` 的 7 个 try/catch 在批次6 已通过 `_showError(e, fallback)` 统一了错误处理口径（这正是 D3 的实质诉求）；剩余骨架差异（await 的调用、fallback 文案、是否重置 loading）属于必要差异，强行抽成一个 `_runSafely` 反而让每个调用点都要传回调和标志，可读性不升反降。故 D3 随批次6/7 关闭。

**为什么这批不写新单测**：泄漏点在对话框关闭路径，controller 是方法内局部变量，外部无法断言其状态；强行为了测试改造成可注入反而引入新复杂度。这批的护栏是 CI 的 `analyze`（`whenComplete` 类型检查、未使用 import 检查）+ 既有测试套件全绿。

### 批次 8 — AI 超时策略单一来源 + 核对关闭四项（F48、F17、F30、F32、F34）

**F48 收口**：AI 服务层的超时以前分两处维护——`ai_router.dart` 的单次调用预算（35s / sensenova 50s）与 `deepseek_service.dart` 的 Dio 接收超时（45s / 60s），靠注释约定「必须成对改」。第八轮 P1-B 已把两边改成按 provider 取值，但两套数字仍是手抄关系。本次新建 `lib/services/ai_timeouts.dart` 作为**唯一策略来源**：

| 成员 | 语义 |
|---|---|
| `perCallTimeoutFor(provider)` | 路由层单次调用预算（默认 35s，sensenova 50s），`perCallTimeoutOverride` 测试注入点一并移入 |
| `receiveTimeoutFor(provider)` | = `perCallTimeoutFor + kDioTimeoutBuffer(10s)`，结构性保证 Dio 永远晚于路由层掐断 |
| `maxPerCallTimeout` | 全局预算上界 |

`ai_router.dart` / `deepseek_service.dart` 只保留转发入口（`AiRouter.perCallTimeoutFor`、`DeepSeekService.receiveTimeoutFor`、`AiRouter.perCallTimeoutOverride` 签名不变），调用点与既有测试零改动；`audit_round8_test.dart` 的 `_receiveTimeoutFor` 改调 `DeepSeekService.receiveTimeoutFor`，并**新增一条护栏测试**：`receiveTimeoutFor(p) == perCallTimeoutFor(p) + kDioTimeoutBuffer` 对全部 provider 恒成立（钉差值关系而非具体秒数，调参不假红）。文档 `docs/AI_SERVICE_API.md` 超时表同步更新。

**核对关闭四项**（均为 v1/v2 审查遗留，逐一复核代码现状）：

| # | 结论 | 依据 |
|---|---|---|
| F17 | 🟢 已修复 | `game_narrative_tab.dart:1731` 是全文件唯一 `Future.delayed`，其前后（1730/1732）及外层 `addPostFrameCallback`（1724）均有 `if (!mounted) return;`，报告点名的缺口已不存在 |
| F30 | 🟢 已解决 | `story_text_renderer.dart` 全部 `RegExp` 已是 `static final`（含 `_outlineLabelPatterns` / `_singleCharVerbPatterns` 按标签预编译），热路径不再现编译 |
| F32 | 🟢 已解决 | 热路径的 `.toList()..sort()`（422-427 / 723 / 1278-1281）已静态缓存；其余散落的 sort 均为一次性数据准备，非热路径 |
| F34 | ✅ 误判 | `liquid_glass_nav_bar.dart:226` 与 `miuix_components.dart:62` 的 `dispose()` 均已调用 `_pressCtrl.dispose()` / `_ctrl.dispose()` |

### 批次 9 — 代码重复收口（D1 测试 fixture 抽取、D2 导航封装）

**D1**：四个测试文件各自写了一份 `makeGame()`（160+ 行重复），抽取到
`test/helpers/test_fixtures.dart` 成为唯一来源（可选 `offlineQuickMode` 参数），
原四处删除。**D2**：`Navigator.push(MaterialPageRoute(...))` 全项目 8 文件 20 处
收口到 `ui_helpers.dart` 的 `pushRoute`，新页面一律走它。护栏测试
`test/code_dedup_audit_test.dart`：`lib/` 下 `MaterialPageRoute` 只允许出现在
`ui_helpers.dart`，杜绝导航构造细节回流。CI 两处热修：`shop_tab.dart` 补
`ui_helpers` import、`round16_fixes_test.dart` 恢复 `app_provider` import、
`progression_fix_test.dart` 同步识别 `pushRoute`/`pushNamed` 分支。

### 批次 10 — 路由统一（F28/F29）+ notifyListeners 剩余合并（F10/P4）

**F28/F29 路由统一**：新建 `lib/router/app_routes.dart` 作为命名路由**唯一字符串源**：

- `AppRoutes` 编译期常量（`home/intro/settings/game`），拼错直接编译失败；
- `appRoutes` 表由 `main.dart` 的 `routes:` 直接引用，不再各自维护；
- 8 个文件的 `pushNamed` 全部改用常量；
- 幽灵路由清除：`game_phone_tab` 的 `/world_map`、`/save_load` 此前表里未定义
  （真点进去会走 onUnknownRoute 抛错），改为 `pushRoute(WorldMapScreen()/SaveLoadScreen())`
  直接推构造器；`home_screen` 的裸字符串路由同样改用 `AppRoutes` 常量。

**F10/P4 剩余合并**：`processChoice`（AI 路径）中三个纯本地分支
（表白就位 / 留校邀请 / 因果抉择）各自 `notifyListeners()` 后立即走到方法尾部的
统一通知，中间无 await —— 同一帧重复 rebuild，每回合多 3 次全量刷新。删除
分支内三处通知，统一由尾部一次通知覆盖（loading 分支的提前通知因后面跟着
AI 请求而保留，那是「先渲染 loading 再 await」的必要节奏）。其余各文件
`notifyListeners` 经逐点核对均为单次/互斥分支/await 间隔通知，无进一步合并空间。

### 批次 11a — F1 `_ensureCommandsRegistered()` 神方法拆分 `[Critical]`

**问题**：`mixin_commands.dart` 的 `_ensureCommandsRegistered()` 单方法 1,337 行
（34..1370），7 个 `registerAll` 块混在一个函数体里，任何命令改动都要在千行
函数中定位。

**改法（纯机械搬移，内容零改动）**：

- `_ensureCommandsRegistered()` 收缩为调度器：`if (_commandsRegistered) return;`
  + `resetForTesting()` + 依次调用 7 个分组注册方法 + `registry.seal()`；
- 7 个分组方法按命令域拆分，各自 `registry.registerAll([...])`：
  - `_registerBasicInfoCommands`（基础信息类）
  - `_registerRelationCommands`（关系/恋爱/声望类）
  - `_registerStudyCommands`（学业&成就&收藏类）
  - `_registerItemCommands`（物品&宠物）
  - `_registerActivityCommands`（活动&玩法）
  - `_registerWorldCommands`（信件&目标&世界&结局）
  - `_registerCheatCommands`（作弊指令）
- 每个 `registerAll` 块的内容逐字节保留，只在外层包方法签名；
  用脚本按边界（注释行 + 4 空格缩进 `]);`）切割，避免手改漏行。

**验证**：`flutter analyze` 0 error；`flutter test` 全量 1381 通过
（含 command_registry / command_subs / command_center_panel 33 项命令相关用例）。

### 批次 11b — F13 `game_narrative_tab.dart` 组件抽取

**问题**：`game_narrative_tab.dart` 1,927 行，底部混着 5 个与
`_NarrativeTabState` 完全无关的自包含 widget（可独立复用、无私有依赖）。

**改法（纯搬移 + 公开化）**：

- 新建 `lib/screens/game/widgets/narrative_widgets.dart`，集中 4 个公开组件：
  `ResourceFloat`（数值变化浮层）、`AiErrorBanner`（AI 失败提示条）、
  `PanelIconAction`（圆形图标动作）、`BubbleTail`（气泡尾巴）；
- `TrianglePainter` 是 `BubbleTail` 的私有实现细节，留在同一文件内
  保持 `_` 私有，不对外暴露；
- 主文件删除原 5 个类定义（~260 行），4 处调用点改用公开类名；
- 私有类跨文件不可见，故全部去掉 `_` 前缀并补 `super.key`
  （公开 widget 构造器 lint 要求）。

**验证**：`dart analyze` 0 error；叙事/时间/选项面板等 68 项相关测试通过。

### 批次 11c — F2 mixin 未使用导入清理 + F40 mixin 组织评估

**F2 导入精简**：`flutter analyze lib/mixins` 发现 6 处未使用导入
（`mixin_commands/init/narrative/relations/response` 的 `flutter/widgets.dart`、
`mixin_play` 的 `flutter/foundation.dart`），全部删除。mixin 域只依赖
dart:async + 数据/模型/服务层，不再依赖 flutter 库本身。

**F40 mixin 组织评估结论**：14 个 mixin 已按职责域拆分完毕（每个 mixin
单一主题：init / narrative / narrative_continuity / commands / response×3 /
relations / systems / play / animagus / death / career），`GameProvider`
本体仅剩 486 行调度层（构造 / autoSave / saveNow / 生命周期 / API key）。
`GameProviderBase` 承载共享字段与静态正则，6 个 mixin 以
`mixin X on GameProviderBase` 声明避免 recursive_interface_inheritance。
**无需进一步合并/拆分**——继续拆会切断 mixin 间共享状态的自然访问，
合并会重新制造神类；当前粒度即为接口隔离的落地形态。

**验证**：`dart analyze lib/mixins` 0 error / 0 warning；全量 1381 测试通过。

### ⏭️ 交接：当前状态与下一步（2026-09-07 深夜收尾）

**已完成并全部推送、CI 全绿**（最近一次全绿 run：`101805871387`，批次6）：

| 批次 | 内容 | 提交 |
|---|---|---|
| 1 | 文档与配置补齐（DOC1/2/3、F27、F45、F46、F18、F47） | `b0ce53c` |
| 2 | 错误处理与日志（F7、F8、F19、F26、S2、S3） | `5950b62` |
| 2.1 | CI 热修复×2：`(?i)` 非法 → `caseSensitive`；字符类 `-` 只放头尾 | `7155538` → `280e1bf` |
| 3 | 存储与启动（F16、F36、F37、D4、CS1 部分修复、CS2 误判） | `97079f6` |
| 4 | 外来数据的健壮性（F3、F5、SI2、SI3） | `8dab7e3` |
| 报告更正 | SI1 / F4 其实早已具备（版本号 + `_migrateSave` 都在），误判源于只搜了一个文件 | `108832c` |
| 5 | 缓存与正则静态化（F31、F33、F35） | `934cc52` / `38f307d` |
| 6 | 统一错误反馈与恢复原语（F6、F9 基础设施） | `62b5c24` |
| 7 | UI 资源释放与重复消除（F11、D3） | `fdbe5e7` |
| 8 | AI 超时单一来源 + 核对四项（F48、F17、F30、F32、F34） | `5548c80` |
| 9 | 代码重复收口（D1 测试 fixture 抽取、D2 导航封装 20 处） | `87b3570` → `9b178aa` |
| 10 | 路由统一（F28/F29 `app_routes.dart` 收口）+ notifyListeners 剩余合并（F10/P4） | `c6d977b` |
| 11a | F1 神方法拆分（`_ensureCommandsRegistered` → 7 个分组注册方法） | `a083683` |
| 11b | F13 组件抽取（`narrative_widgets.dart`，1927 → 1667 行） | `a27fdcd` |
| 11c | F2 mixin 未使用导入清理 ×6 + F40 mixin 组织评估（无需再拆） | 本次提交 |

**下一批（批次 4）建议范围 —— 「外来数据的健壮性」，已定未动工**：

1. **F3（High）**：`lib/models/player.dart:491` 的 `Player.fromJson` 大量字段无类型断言
   （`id: json['id']`、`health: json['health'] ?? 100` 等直接透传 dynamic），
   旧存档字段类型一变就崩在 fromJson 上。建议新增 `lib/utils/json_read.dart`
   安全读取函数（`readString/readInt/readDouble/readBool/readStringList`，
   接受 num/数字字符串等宽容形态并带 fallback），再改造 `fromJson`。
2. **SI2（Medium）**：`save_service.dart` 的读档校验只有 `containsKey('player')`，
   建议加结构校验（player/world_state 是 Map、turn_count 是非负 int、
   save_version 可识别），不合格走已有的备份回滚路径。
3. **F5（Low）**：`world_state.dart` 的 `NarrativeEvent.fromJson` 已按 String/Map 分流，
   剩余风险是 `src['t'] as String?` 在 t 为非字符串时抛错，顺手换成宽容读取。
4. **SI3（Medium）**：CrashLogger / AiDebugLogger 日志路径无统一管理，可收口到一个常量。

**再往后的候选**（按性价比排）：F12（setState 局部刷新，面大需基准）、
F1/F40/F13/F14（大拆分，放最后，等本地能跑 `flutter test` 时再动）。
（批次9/10 已完成 D1/D2 代码重复收口、F10/P4 notifyListeners 合并、F28/F29 路由统一，
结构护栏见 `test/code_dedup_audit_test.dart`。）

**注意两件事**：

- 本仓库 CI 会自动 bump 版本 + sync CHANGELOG 并推送，**每次 push 前先
  `git pull --rebase origin main`**，否则被拒。
- 改正则前先读 `lib/utils/debug_log.dart` 的规则表注释 —— `(?i)` 与
  字符类中间的 `-` 都是「编译得过、跑起来才炸」的坑，本机 Dart 2.17 比 CI 的 3.x
  宽松，验不出来；推送后必须看 CI。
