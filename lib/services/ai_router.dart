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
  final Map<AiProvider, DeepSeekService> _services = {};
  final Map<AiProvider, AiConfig> _configs = {};
  final AiRouterConfig _config;
  final _responseCache = ResponseCache.instance;

  AiRouter(this._config);

  void register(AiConfig cfg) {
    _configs[cfg.provider] = cfg;
    _services[cfg.provider] = DeepSeekService(config: cfg);
  }

  void unregister(AiProvider provider) {
    _configs.remove(provider);
    _services.remove(provider);
  }

  /// 是否存在任何可用 AI 服务。任一提供商已注册（配置了 key）即可通过 fallback 生成叙事，
  /// 不再只检查主 narrativeProvider，避免「有备用 key 却被挡死」。
  bool get hasNarrativeService => _configs.isNotEmpty;

  List<AiProvider> get registeredProviders => _configs.keys.toList();

  DeepSeekService? getService(AiProvider provider) => _services[provider];

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
    // 检查缓存（narrative 场景关闭缓存：其 prompt 每回合都变，命中率极低且有冻结随机性的风险）
    if (useCache) {
      final cached = _responseCache.get(
        prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
      );
      if (cached != null) {
        // 命中缓存也落一条 COMPLETE，避免 logStart 留下的 _pendingCalls 条目泄漏，同时便于调试追踪
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

    // 候选列表：primary 优先，随后按 fallbackOrder 去重。
    // 默认 fallbackOrder 只含免费模型（sensenova/agnes），不会自动切到付费 DeepSeek；
    // 仅当 primary 本身就是 DeepSeek 时它才会被尝试，失败后回退到免费模型。
    final candidates = <AiProvider>[primary];
    for (final p in _config.fallbackOrder) {
      if (!candidates.contains(p)) candidates.add(p);
    }

    Object? lastError;
    for (final provider in candidates) {
      final service = _services[provider];
      if (service == null) continue; // 未注册（无 key），跳过

      // 指数退避重试：对可重试错误（429/5xx/网络抖动）先重试同一提供商，
      // 避免立即切换备用提供商浪费其配额。最多重试 2 次（共 3 次尝试）。
      const maxRetries = 2;
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          final result = await _executeWithRateLimit(
            provider: provider,
            service: service,
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
          // 记录成功响应（完整保存返回内容，不再截断以便调试）
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

          // 可重试错误且还有重试机会：指数退避后重试同一提供商
          if (e is AiRetryableException && attempt < maxRetries) {
            final backoffMs = (attempt + 1) * 2000; // 2s, 4s
            debugPrint('⚠️ ${provider.name} 第${attempt + 1}次失败，${backoffMs}ms后重试: $e');
            await Future.delayed(Duration(milliseconds: backoffMs));
            continue;
          }

          debugPrint('⚠️ ${provider.name} 调用失败: $e');
          final sceneLabel = scene?.toString().split('.').last ?? 'unknown';
          final isLastCandidate = provider == candidates.last;
          await AiDebugLogger.instance.logComplete(
            callId: callId,
            timestamp: DateTime.now().toIso8601String(),
            scene: sceneLabel,
            provider: getProviderLabel(provider),
            action: isLastCandidate ? 'ERROR' : 'FALLBACK',
            error: e.toString(),
            keepPending: !isLastCandidate,
          );
          break; // 重试耗尽或不可重试，切换下一个提供商
        }
      }
    }

    if (lastError != null) throw lastError;
    throw AiNonRetryableException('所有AI服务均不可用');
  }

  Future<ChatResult> _executeWithRateLimit({
    required AiProvider provider,
    required DeepSeekService service,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
    CancelToken? cancelToken,
  }) async {
    switch (provider) {
      case AiProvider.agnes:
        // Agnes：使用速率限制器（限20 RPM）
        await AgnesRateLimiter.instance.waitForSlot();
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
    final service = _services[provider];
    if (service == null) return null;
    try {
      return await service.getBalance();
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
