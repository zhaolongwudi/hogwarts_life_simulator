# AI 服务 API 文档

> **DOC3**：审查报告 v3 指出「AI 服务接口（DeepSeekService、AiRouter）无外部 API 文档」。
> 本文面向需要**调用**或**扩展** AI 能力的开发者，描述公开接口、错误模型、超时预算与降级行为。
>
> 实现细节与排障请读源码注释与 [`PROJECT_GUIDE.md`](../PROJECT_GUIDE.md) §3.3；
> 架构层面「为什么这么设计」见 [`ARCHITECTURE.md`](ARCHITECTURE.md) 的 ADR-003 / ADR-004。

---

## 1. 组件一览

| 组件 | 文件 | 职责 |
|---|---|---|
| `AiRouter` | `lib/services/ai_router.dart` | 场景路由 / 多 Key 负载均衡 / 熔断 / 全局超时 |
| `DeepSeekService` | `lib/services/deepseek_service.dart` | 单个 Key 的一次 HTTP 对话（Dio） |
| `NpcChatService` | `lib/services/npc_chat_service.dart` | NPC 独立对话 + 会话持久化 |
| `KeyStore` | `lib/services/key_store.dart` | API Key 的安全存储（flutter_secure_storage） |
| `RateLimiter` | `lib/services/rate_limiter.dart` | 并发槽位限流 |
| `AiDebugLogger` | `lib/utils/ai_debug_logger.dart` | 调用日志（开始/完成两段拼一条） |

调用方通常**只需要碰 `AiRouter`**；其余为内部组件。

---

## 2. 枚举与配置

### `AiScene`（调用场景）

```dart
enum AiScene { narrative, summary, npcChat, choice }
```

场景决定三件事：**默认走哪个 provider**、**全局超时的上下限**、**是否启用响应缓存**
（`narrative` 与 `choice` 禁用缓存，因为每回合内容必须不同）。

### `AiProvider`

```dart
enum AiProvider { deepseek, agnes, sensenova }
```

默认路由表 `kDefaultRoute`（`lib/providers/app_provider.dart`）：

| 场景 | 默认 provider | 说明 |
|---|---|---|
| `narrative` | sensenova | 剧情质量最好、Token 效率高 |
| `summary` | sensenova | 每 10 回合压缩历史 |
| `npcChat` | agnes | 免费、响应最快 |
| `choice` | sensenova | 独立生成选项 |

DeepSeek 是付费模型，不进默认路由与自动回退，只能由用户在设置页手动指定。

### `AiConfig`

```dart
const AiConfig({
  required AiProvider provider,
  required String model,
  required String apiKey,
  required String baseUrl,
  String chatPath = '/v1/chat/completions',
  String modelsPath = '/v1/models',
  String? balancePath,
});
```

三家工厂 `AiConfig.deepseek(key)` / `.agnes(key)` / `.sensenova(key)` 统一从
`kProviderDefaults` 取值 —— 不要在调用处手写 model / baseUrl，否则会和设置页的副本漂移。

---

## 3. 主入口：`AiRouter.chatComplete`

```dart
Future<ChatResult> chatComplete({
  required AiScene scene,
  required String prompt,
  String? systemPrompt,
  double temperature = 0.8,
  int maxTokens = 2500,
});
```

**返回**：`ChatResult { String content; TokenUsage usage; }`

**行为**：

1. 按 `scene` 选主 provider，取该 provider 已注册的 Key 列表；
2. 用实际 Key 数算全局超时（见 §4），给整条调用链套 `Future.timeout`；
3. 依次尝试每个 Key：未熔断的先试；失败记一次熔断计数；
4. 全部失败 → 抛异常，由**调用方**（`mixin_narrative`）走本地兜底叙事。

**注入测试**（不需要真实网络）：

```dart
final router = AiRouter(
  config,
  services: {AiProvider.sensenova: [FakeService(...)]},
);
```

`services` 参数是熔断 / 故障转移这类异常路径唯一的测试入口 —— 早期版本只能在
`register()` 里用真实 `AiConfig` 构造，导致这两条主动脉完全没有测试覆盖。

**其它公开成员**：

| 成员 | 说明 |
|---|---|
| `void register(AiConfig cfg)` | 注册一个 Key（同 provider 多 Key 即负载均衡） |
| `void dispose()` | 释放资源 |
| `bool get hasNarrativeService` | 是否至少有一个可用 provider |
| `static Duration perCallTimeoutFor(AiProvider)` | 单次调用预算 |
| `static Duration perKeyBudgetFor(int keyCount)` | 一个坏 Key 最多吃掉多少预算 |
| `static Duration globalTimeoutFor(AiScene, int keyCount)` | 全局超时 |
| `String getProviderLabel(AiProvider)` | 中文展示名 |

---

## 4. 超时模型（重要）

三层超时，**必须保持大小关系**，否则日志里「网关慢」和「请求挂死」会长得一模一样：

```
Dio receiveTimeout  >  AiRouter.perCallTimeoutFor  →  由 AiRouter 先掐断，Dio 只做兜底
```

| 层 | 位置 | 默认 |
|---|---|---|
| 单次调用预算 | `AiRouter.perCallTimeoutFor` | 35s（sensenova 50s） |
| Dio 接收超时 | `DeepSeekService.receiveTimeoutFor` | 45s（sensenova 60s） |
| 全局超时 | `AiRouter.globalTimeoutFor` | `5s + perKeyBudget × keyCount`，按场景 clamp |

clamp 区间：

| 场景 | floor | ceil |
|---|---|---|
| `narrative` | 60s | 120s |
| `choice` | 50s | 100s |
| 其它 | 35s | 60s |

**为什么单 Key 不重试**：`_maxRetriesPerService = 0` 是刻意的。允许重试时单 Key 最坏耗时
变成 `perCallTimeout × (n+1) + 退避`，会吃掉整个全局预算，后面的 Key 一次都轮不到，
熔断也记不满阈值。详见 `ai_router.dart` 的注释与 ADR-003。

> ⚠️ 改任何一个超时常数时，`perKeyBudgetFor` 与 `globalTimeoutFor` 必须共用同一组参数，
> 改一个不改另一个会让预算公式与实际行为各说各话。

---

## 5. 错误模型

| 异常 | 含义 | 路由层处理 |
|---|---|---|
| `AiRetryableException(message, isTimeout: true)` | 超时 | 直接切下一个 Key（再试只会再吃一个超时窗口） |
| `AiRetryableException(message)` | 限流 / 5xx | 退避后切下一个 Key |
| `AiNonRetryableException` | 认证失败 / 参数错误 / 端点不存在 | 记失败，切 Key；此类 Key 应被熔断剔除 |

**熔断**：同一 Key 失败 3 次（`circuitThreshold`）后冷却 60s（`circuitCooldown`），
冷却期内跳过该 Key。成功一次即清零计数。

**调用方责任**：`AiRouter` 只负责「尽力拿到一个结果」，最终失败会抛异常。
玩家可见的兜底（本地叙事 / 选项承接）在 `mixin_narrative.dart`，不在服务层 ——
服务层不知道 UI 该怎么提示。

---

## 6. NPC 对话：`NpcChatService`

```dart
final svc = NpcChatService(appProvider: appProvider);

// 返回 (回复文本, 是否离线兜底)
final (String reply, bool offline) = await svc.chatWithNPC(...);

await svc.saveConversation(npcId, messages);
final history = await svc.loadConversation(npcId);
await svc.clearConversation(npcId);
```

- 历史回放会**逐条重新 sanitize**（输入注入防御的第二道保险）；
- 离线兜底时第二个返回值为 `true`，UI 需要据此提示玩家。

---

## 7. 密钥存储：`KeyStore`

```dart
await KeyStore.instance.writeKey(provider, key);
final key = await KeyStore.instance.readKey(provider);
await KeyStore.instance.deleteKey(provider);
await KeyStore.instance.writeKeys(provider, [k1, k2]); // 多 Key
final keys = await KeyStore.instance.readKeys(provider);
```

单例，底层 `flutter_secure_storage`（Android 走 EncryptedSharedPreferences）。

> ⚠️ **已知缺口（审查 S1）**：无锁屏设备上 `flutter_secure_storage` 可能降级或报错，
> 目前没有降级后的用户提示与备用方案。修复计划见审查报告的修复记录。

---

## 8. 调试日志

`AiDebugLogger` 采用「开始 / 完成」两段式：调用开始先写一条带 `callId` 的记录，
结束时按 `callId` 补全，因此**即使请求超时也能留下痕迹**。
日志完整保存 prompt 与 response（不截断），但因为可能包含用户对话内容，
**不要**在公开场合直接贴出完整日志（审查 S3，脱敏修复中）。
