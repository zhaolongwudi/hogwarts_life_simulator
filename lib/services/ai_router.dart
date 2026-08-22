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
    this.fallbackOrder = const [AiProvider.deepseek, AiProvider.sensenova, AiProvider.agnes],
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

  AiProvider fallbackFor(AiProvider current) {
    final idx = fallbackOrder.indexOf(current);
    if (idx >= 0 && idx < fallbackOrder.length - 1) {
      return fallbackOrder[idx + 1];
    }
    if (current != narrativeProvider && narrativeProvider != AiProvider.deepseek) {
      return narrativeProvider;
    }
    return fallbackOrder.first;
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

  bool get hasNarrativeService => _configs.containsKey(_config.narrativeProvider);

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

    // 记录调用开始
    AiDebugLogger.instance.logCall(
      timestamp: timestamp,
      scene: sceneLabel,
      provider: getProviderLabel(primary),
      action: 'START',
      promptPreview: promptPreview,
      systemPrompt: systemPrompt,
    );

    final future = _callWithFallback(
      primary: primary,
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      useCache: scene != AiScene.narrative && scene != AiScene.choice,
      scene: scene,
    );
    if (scene == AiScene.narrative) {
      return future.timeout(const Duration(seconds: 45), onTimeout: () {
        AiDebugLogger.instance.logCall(
          timestamp: DateTime.now().toIso8601String(),
          scene: sceneLabel,
          provider: getProviderLabel(primary),
          action: 'TIMEOUT',
          error: '剧情生成超时（45秒）',
        );
        throw AiRetryableException('剧情生成超时（45秒），请重试或切换提供商');
      });
    }
    if (scene == AiScene.choice) {
      return future.timeout(const Duration(seconds: 20), onTimeout: () {
        AiDebugLogger.instance.logCall(
          timestamp: DateTime.now().toIso8601String(),
          scene: sceneLabel,
          provider: getProviderLabel(primary),
          action: 'TIMEOUT',
          error: '选项生成超时（20秒）',
        );
        throw AiRetryableException('选项生成超时（20秒），请重试');
      });
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
        return ChatResult(
          content: cached,
          usage: TokenUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
        );
      }
    }

    final tried = <AiProvider>{};
    var current = primary;

    while (tried.length < _configs.length) {
      if (tried.contains(current)) {
        current = _config.fallbackFor(current);
        continue;
      }
      tried.add(current);

      final service = _services[current];
      if (service == null) {
        current = _config.fallbackFor(current);
        continue;
      }

      try {
        final result = await _executeWithRateLimit(
          provider: current,
          service: service,
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
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
        final responsePreview = result.content;
        AiDebugLogger.instance.logCall(
          timestamp: DateTime.now().toIso8601String(),
          scene: sceneLabel,
          provider: getProviderLabel(current),
          action: 'RESPONSE',
          responsePreview: responsePreview,
          promptTokens: result.usage.promptTokens,
          completionTokens: result.usage.completionTokens,
          totalTokens: result.usage.totalTokens,
        );
        return result;
      } catch (e) {
        debugPrint('⚠️ ${current.name} 调用失败: $e');
        // 记录错误
        final sceneLabel = scene?.toString().split('.').last ?? 'unknown';
        AiDebugLogger.instance.logCall(
          timestamp: DateTime.now().toIso8601String(),
          scene: sceneLabel,
          provider: getProviderLabel(current),
          action: 'ERROR',
          error: e.toString(),
        );
        if (tried.length >= _configs.length) {
          rethrow;
        }
        current = _config.fallbackFor(current);
      }
    }

    throw AiNonRetryableException('所有AI服务均不可用');
  }

  Future<ChatResult> _executeWithRateLimit({
    required AiProvider provider,
    required DeepSeekService service,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
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
        );

      case AiProvider.sensenova:
        // SenseNova：使用配额管理器（每5小时1500次）
        await SenseNovaQuotaManager.instance.waitForQuota();
        return service.chatComplete(
          prompt: prompt,
          systemPrompt: systemPrompt ?? '',
          temperature: temperature,
          maxTokens: maxTokens,
        );

      case AiProvider.deepseek:
        // DeepSeek：付费模型无限制
        return service.chatComplete(
          prompt: prompt,
          systemPrompt: systemPrompt ?? '',
          temperature: temperature,
          maxTokens: maxTokens,
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

  String sceneLabel(AiScene scene) {
    switch (scene) {
      case AiScene.narrative:
        return '剧情';
      case AiScene.summary:
        return '摘要';
      case AiScene.npcChat:
        return 'NPC聊天';
      case AiScene.choice:
        return '选项';
    }
  }

  String sceneProviderLabel(AiScene scene) {
    final p = _config.providerFor(scene);
    final fallback = _config.fallbackFor(p);
    final hasFallback = _configs.containsKey(fallback) && fallback != p;
    final buffer = StringBuffer('${getProviderLabel(p)}');
    if (hasFallback) {
      buffer.write(' → ${getProviderLabel(fallback)}');
    }
    return buffer.toString();
  }
}
