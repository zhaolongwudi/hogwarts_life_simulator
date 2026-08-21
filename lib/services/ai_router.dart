import 'package:flutter/foundation.dart';
import '../providers/app_provider.dart';
import 'deepseek_service.dart';
import 'deepseek_service.dart' show ChatResult;

enum AiScene { narrative, summary, npcChat }

class AiRouterConfig {
  final AiProvider narrativeProvider;
  final AiProvider summaryProvider;
  final AiProvider npcChatProvider;
  final List<AiProvider> fallbackOrder;

  const AiRouterConfig({
    this.narrativeProvider = AiProvider.deepseek,
    this.summaryProvider = AiProvider.sensenova,
    this.npcChatProvider = AiProvider.agnes,
    // DeepSeek 作为最终兜底，智谱作为次级备用
    this.fallbackOrder = const [AiProvider.zhipu, AiProvider.deepseek],
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
        return await service.chatComplete(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
        );
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

  Future<int?> checkBalance(AiProvider provider) async {
    final service = _services[provider];
    if (service == null) return null;
    try {
      return await service.checkBalance();
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
