import 'package:flutter/foundation.dart';
import '../providers/app_provider.dart';
import 'deepseek_service.dart';
import 'rate_limiter.dart';

enum AiScene { narrative, summary, npcChat }

class AiRouterConfig {
  final AiProvider narrativeProvider;
  final AiProvider summaryProvider;
  final AiProvider npcChatProvider;
  final List<AiProvider> fallbackOrder;

  const AiRouterConfig({
    // 智谱AI作为主剧情提供商（中文质量最好）
    this.narrativeProvider = AiProvider.zhipu,
    // SenseNova作为摘要提供商（Token效率最高）
    this.summaryProvider = AiProvider.sensenova,
    // Agnes作为NPC聊天提供商（响应速度最快）
    this.npcChatProvider = AiProvider.agnes,
    // 降级顺序：智谱→SenseNova→Agnes→DeepSeek
    this.fallbackOrder = const [AiProvider.sensenova, AiProvider.agnes, AiProvider.deepseek],
  });

  AiProvider providerFor(AiScene scene) {
    switch (scene) {
      case AiScene.narrative:
        return narrativeProvider;
      case AiScene.summary:
        return summaryProvider;
      case AiScene.npcChat:
        return npcChatProvider;
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
  final _zhipuQueue = ZhipuConcurrencyQueue();
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
    int maxTokens = 2000,
  }) async {
    final primary = _config.providerFor(scene);
    return _callWithFallback(
      primary: primary,
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  Future<ChatResult> _callWithFallback({
    required AiProvider primary,
    required String prompt,
    String? systemPrompt,
    required double temperature,
    required int maxTokens,
  }) async {
    // 检查缓存
    final cached = _responseCache.get(prompt, systemPrompt: systemPrompt);
    if (cached != null) {
      return ChatResult(
        content: cached,
        usage: TokenUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
      );
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
        _responseCache.set(prompt, result.content, systemPrompt: systemPrompt);
        return result;
      } catch (e) {
        debugPrint('⚠️ ${current.name} 调用失败: $e');
        if (tried.length >= _configs.length) {
          rethrow;
        }
        current = _config.fallbackFor(current);
      }
    }

    throw Exception('所有AI服务均不可用');
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
      case AiProvider.zhipu:
        // 智谱AI：使用并发队列（限1个并发）
        return _zhipuQueue.execute(() async {
          return service.chatComplete(
            prompt: prompt,
            systemPrompt: systemPrompt ?? '',
            temperature: temperature,
            maxTokens: maxTokens,
          );
        });

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
      default:
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
      case AiProvider.zhipu:
        return '智谱 AI';
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
