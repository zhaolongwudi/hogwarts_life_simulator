import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_provider.dart';
import '../utils/ai_debug_logger.dart';
import 'deepseek_service.dart';
import 'rate_limiter.dart';

enum AiScene { narrative, summary, npcChat, choice }

class AiRouterConfig {
  final AiProvider narrativeProvider;
  final AiProvider summaryProvider;
  final AiProvider npcChatProvider;
  final AiProvider choiceProvider;
  final List<AiProvider> fallbackOrder;

  const AiRouterConfig({
    this.narrativeProvider = AiProvider.sensenova,
    this.summaryProvider = AiProvider.sensenova,
    this.npcChatProvider = AiProvider.agnes,
    this.choiceProvider = AiProvider.sensenova,
    this.fallbackOrder = const [AiProvider.sensenova, AiProvider.agnes],
  });

  AiProvider providerFor(AiScene scene) {
    switch (scene) {
      case AiScene.narrative:
        return narrativeProvider;
      case AiScene.summary:
        return summaryProvider;
      case AiScene.npcChat:
        return npcChatProvider;
      case AiScene.choice:
        return choiceProvider;
    }
  }
}

class AiRouter {
  /// 每个提供商可能有多个服务（每个 API Key 一个服务）
  final Map<AiProvider, List<DeepSeekService>> _services = {};
  final Map<AiProvider, List<AiConfig>> _configs = {};
  final AiRouterConfig _config;
  final _responseCache = ResponseCache.instance;
  int _roundRobinIndex = 0; // 轮询索引，用于随机选择多 key

  AiRouter(this._config);

  /// 注册一个 API Key 对应的配置
  void register(AiConfig cfg) {
    (_configs[cfg.provider] ??= []).add(cfg);
    (_services[cfg.provider] ??= []).add(DeepSeekService(config: cfg));
  }

  /// 取消注册一个提供商的所有服务
  void unregister(AiProvider provider) {
    _configs.remove(provider);
    _services.remove(provider);
  }

  /// 是否存在任何可用 AI 服务。任一提供商已注册（配置了 key）即可通过 fallback 生成叙事，
  /// 不再只检查主 narrativeProvider，避免「有备用 key 却被挡死」。
  bool get hasNarrativeService => _configs.values.any((list) => list.isNotEmpty);

  /// 获取所有已配置了至少一个 key 的提供商
  List<AiProvider> get registeredProviders => _configs.keys
      .where((p) => _configs[p]!.isNotEmpty)
      .toList();

  /// 获取指定提供商的所有服务（每个 API Key 一个）
  List<DeepSeekService>? getServices(AiProvider provider) => _services[provider];

  /// 获取指定提供商的服务数量
  int serviceCount(AiProvider provider) =>
      _services[provider]?.length ?? 0;

  Future<ChatResult> chatComplete({
    required AiScene scene,
    required String prompt,
    String? systemPrompt,
    double temperature = 0.8,
    int maxTokens = 2500,
  }) async {
    final primary = _config.providerFor(scene);
    final timestamp = DateTime.now().toIso8601String();
    final sceneLabel = scene.toString().split('.').last;
    // 调试日志不再截断 prompt/response 重要内容，完整保存
    final promptPreview = prompt;

    // 记录调用开始 → 返回 callId，后续完成阶段用 callId 拼成完整一条
    final callId = await AiDebugLogger.instance.logStart(
      timestamp: timestamp,
      scene: sceneLabel,
      provider: getProviderLabel(primary),
      promptPreview: promptPreview,
      systemPrompt: systemPrompt,
    );

    final cancelToken = CancelToken();
    final future = _callWithFallback(
      primary: primary,
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      useCache: scene != AiScene.narrative && scene != AiScene.choice,
      scene: scene,
      callId: callId,
      cancelToken: cancelToken,
    );

    if (scene == AiScene.narrative) {
      return future.timeout(
        const Duration(seconds: 75),
        onTimeout: () async {
          cancelToken.cancel('narrative timeout');
          await AiDebugLogger.instance.logComplete(
            callId: callId,
            timestamp: DateTime.now().toIso8601String(),
            scene: sceneLabel,
            provider: getProviderLabel(primary),
            action: 'TIMEOUT',
            error: '剧情生成超时（75秒）',
          );
          throw AiRetryableException('剧情生成超时（75秒），请重试或切换提供商');
        },
      );
    }
    if (scene == AiScene.choice) {
      return future.timeout(
        const Duration(seconds: 60),
        onTimeout: () async {
          cancelToken.cancel('choice timeout');
          await AiDebugLogger.instance.logComplete(
            callId: callId,
            timestamp: DateTime.now().toIso8601String(),
            scene: sceneLabel,
            provider: getProviderLabel(primary),
            action: 'TIMEOUT',
            error: '选项生成超时（60秒）',
          );
          throw AiRetryableException('选项生成超时（60秒），请重试');
        },
      );
    }
    return future;
  }

  Future<ChatResult> _callWithFallback({
    required AiProvider primary,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
    bool useCache = true,
    AiScene? scene,
    String? callId,
    CancelToken? cancelToken,
  }) async {
    // 检查缓存
    if (useCache) {
      final cached = _responseCache.get(
        prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
      );
      if (cached != null) {
        final cacheSceneLabel = scene?.toString().split('.').last ?? 'unknown';
        await AiDebugLogger.instance.logComplete(
          callId: callId,
          timestamp: DateTime.now().toIso8601String(),
          scene: cacheSceneLabel,
          provider: getProviderLabel(primary),
          action: 'CACHE',
          responsePreview: cached,
        );
        return ChatResult(
          content: cached,
          usage: TokenUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
        );
      }
    }

    // 候选提供商列表：primary 优先，随后按 fallbackOrder 去重。
    final candidates = <AiProvider>[primary];
    for (final p in _config.fallbackOrder) {
      if (!candidates.contains(p)) candidates.add(p);
    }

    const maxRetriesPerService = 2; // 每个 key 最多重试 2 次（共 3 次尝试）

    Object? lastError;
    for (final provider in candidates) {
      final services = _services[provider];
      if (services == null || services.isEmpty) continue;

      // 轮询选择起始 key，避免每次从头开始（让多个 key 均匀分配流量）
      _roundRobinIndex = (_roundRobinIndex + 1) % services.length;
      // 从轮询起始点开始，遍历所有 key
      for (int ki = 0; ki < services.length; ki++) {
        final serviceIdx = (_roundRobinIndex + ki) % services.length;
        final service = services[serviceIdx];
        final keyHash = service.config.apiKey.length > 8
            ? service.config.apiKey.substring(0, 8)
            : service.config.apiKey;

        for (var attempt = 0; attempt <= maxRetriesPerService; attempt++) {
          try {
            final result = await _executeWithRateLimit(
              provider: provider,
              service: service,
              keyHash: keyHash,
              prompt: prompt,
              systemPrompt: systemPrompt,
              temperature: temperature,
              maxTokens: maxTokens,
              cancelToken: cancelToken,
            );
            // 缓存成功响应
            if (useCache) {
              _responseCache.set(
                prompt,
                result.content,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
              );
            }
            final sceneLabel = scene?.toString().split('.').last ?? 'unknown';
            await AiDebugLogger.instance.logComplete(
              callId: callId,
              timestamp: DateTime.now().toIso8601String(),
              scene: sceneLabel,
              provider: getProviderLabel(provider),
              action: 'RESPONSE',
              responsePreview: result.content,
              promptTokens: result.usage.promptTokens,
              completionTokens: result.usage.completionTokens,
              totalTokens: result.usage.totalTokens,
            );
            return result;
          } catch (e) {
            if (cancelToken?.isCancelled == true) {
              rethrow;
            }
            lastError = e;

            // 可重试错误且还有重试机会：指数退避后重试同一 key
            if (e is AiRetryableException && attempt < maxRetriesPerService) {
              final backoffMs = (attempt + 1) * 2000;
              debugPrint('⚠️ ${provider.name}[$keyHash] 第${attempt + 1}次失败，${backoffMs}ms后重试: $e');
              await Future.delayed(Duration(milliseconds: backoffMs));
              continue;
            }

            // 当前 key 所有重试耗尽，记录日志并尝试下一个 key
            debugPrint('⚠️ ${provider.name}[$keyHash] 已耗尽，尝试下一个 Key: $e');
            final sceneLabel = scene?.toString().split('.').last ?? 'unknown';
            final isLastKey = (ki == services.length - 1) && (provider == candidates.last);
            await AiDebugLogger.instance.logComplete(
              callId: callId,
              timestamp: DateTime.now().toIso8601String(),
              scene: sceneLabel,
              provider: '${getProviderLabel(provider)}[$keyHash]',
              action: isLastKey ? 'ERROR' : 'FALLBACK',
              error: e.toString(),
              keepPending: !isLastKey,
            );
            break; // 切到下一个 key
          }
        }
      }
    }

    if (lastError != null) throw lastError;
    throw AiNonRetryableException('所有AI服务均不可用');
  }

  Future<ChatResult> _executeWithRateLimit({
    required AiProvider provider,
    required DeepSeekService service,
    required String keyHash,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
    CancelToken? cancelToken,
  }) async {
    switch (provider) {
      case AiProvider.agnes:
        // Agnes：每个 API Key 独立限流（20 RPM）
        await AgnesRateLimiter.instance.waitForSlot(keyHash);
        return service.chatComplete(
          prompt: prompt,
          systemPrompt: systemPrompt ?? '',
          temperature: temperature,
          maxTokens: maxTokens,
          cancelToken: cancelToken,
        );

      case AiProvider.sensenova:
        // SenseNova：使用配额管理器（按模型区分：6.8/6.7=1500次/5h，deepseek/glm=500次/5h）
        await SenseNovaQuotaManager.instance.waitForQuota(service.config.model);
        return service.chatComplete(
          prompt: prompt,
          systemPrompt: systemPrompt ?? '',
          temperature: temperature,
          maxTokens: maxTokens,
          cancelToken: cancelToken,
        );

      case AiProvider.deepseek:
        // DeepSeek：付费模型无限制
        return service.chatComplete(
          prompt: prompt,
          systemPrompt: systemPrompt ?? '',
          temperature: temperature,
          maxTokens: maxTokens,
          cancelToken: cancelToken,
        );
    }
  }

  Future<double?> checkBalance(AiProvider provider) async {
    final services = _services[provider];
    if (services == null || services.isEmpty) return null;
    // 尝试第一个 key 的余额查询
    try {
      return await services.first.getBalance();
    } catch (e) {
      return null;
    }
  }

  String getProviderLabel(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.agnes:
        return 'Agnes';
      case AiProvider.sensenova:
        return 'SenseNova';
    }
  }

  }
