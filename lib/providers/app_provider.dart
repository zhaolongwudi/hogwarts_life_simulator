import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_router.dart';
import '../services/key_store.dart';

enum DisplayMode { magazine, compact, immersive }
enum IdentityMode { native, transmigration }
enum Era { marauders, first_war, harry_same, post_war, random, dumbledore }
enum AiProvider { deepseek, zhipu, agnes, sensenova }

// 场景 → 提供商名 的默认路由
// 策略：Agnes用于主剧情（响应最快，中文质量可接受），SenseNova用于摘要（Token效率最高），DeepSeek用于NPC聊天（长文本能力强）
// 用户可通过设置页面自定义路由覆盖默认值
const Map<AiScene, String> kDefaultRoute = {
  AiScene.narrative: 'agnes',      // 主剧情：Agnes响应速度最快（<1s首字）
  AiScene.summary: 'sensenova',    // 摘要：商汤Token效率最高(省60%)
  AiScene.npcChat: 'deepseek',    // NPC聊天：DeepSeek长文本能力强
};

// 场景简介（显示在设置页）
const Map<AiScene, String> kSceneDescriptions = {
  AiScene.narrative: '主剧情：生成每回合的叙事文本、分支选择和行动反馈。默认使用 Agnes turbo（速度最快），可改为智谱AI以获得更高中文质量。',
  AiScene.summary: '剧情摘要：每10回合自动压缩历史剧情为摘要。默认使用 SenseNova（Token效率最高，省60%）。',
  AiScene.npcChat: 'NPC聊天：与游戏中角色的独立对话。默认使用 DeepSeek（长文本能力强），可改为 Agnes 以获得更快响应。',
};

// 提供商简介
const Map<AiProvider, String> kProviderDescriptions = {
  AiProvider.deepseek: '付费模型。高质量长文本叙事，中文表现优秀，支持 deepseek-v4-flash/pro/reasoner 等模型。可作为主剧情和备用模型。',
  AiProvider.zhipu: '免费模型。智谱AI，glm-4.7-flash 中文自然度最好，200K上下文，永久免费无Token上限。适合主剧情生成。注意：免费版限1个并发。',
  AiProvider.agnes: '免费模型。Agnes-2.5-flash，响应速度最快（<1s首字），256K上下文。适合NPC短对话。注意：免费版限20 RPM。',
  AiProvider.sensenova: '免费模型。SenseNova·商汤日日新，256K长上下文，Token效率最高（省60%）。适合摘要/压缩任务。注意：每5小时1500次配额。',
};

// 场景中文名
const Map<AiScene, String> kSceneLabels = {
  AiScene.narrative: '主剧情生成',
  AiScene.summary: '剧情摘要压缩',
  AiScene.npcChat: 'NPC独立聊天',
};

List<AiProvider> get allProviders => AiProvider.values;

String providerName(AiProvider p) => p.name;

class AiConfig {
  final AiProvider provider;
  final String model;
  final String apiKey;
  final String baseUrl;
  final String chatPath;
  final String modelsPath;
  final String? balancePath;

  const AiConfig({
    required this.provider,
    required this.model,
    required this.apiKey,
    required this.baseUrl,
    this.chatPath = '/v1/chat/completions',
    this.modelsPath = '/v1/models',
    this.balancePath,
  });

  factory AiConfig.deepseek(String apiKey) => AiConfig(
        provider: AiProvider.deepseek,
        model: 'deepseek-v4-flash',
        apiKey: apiKey,
        baseUrl: 'https://api.deepseek.com',
        balancePath: '/user/balance',
      );

  factory AiConfig.zhipu(String apiKey) => AiConfig(
        provider: AiProvider.zhipu,
        model: 'glm-4.7-flash',
        apiKey: apiKey,
        baseUrl: 'https://open.bigmodel.cn',
        chatPath: '/api/paas/v4/chat/completions',
        modelsPath: '/api/paas/v4/models',
        balancePath: '/api/monitor/usage/quota/limit',
      );

  factory AiConfig.agnes(String apiKey) => AiConfig(
        provider: AiProvider.agnes,
        model: 'agnes-2.5-turbo',
        apiKey: apiKey,
        baseUrl: 'https://api.agnes-ai.cn',
        chatPath: '/v1/chat/completions',
      );

  /// 商汤日日新 SenseNova
  /// 正确端点: https://token.sensenova.cn/v1/chat/completions
  factory AiConfig.sensenova(String apiKey) => AiConfig(
        provider: AiProvider.sensenova,
        model: 'sensenova-6.7-flash-lite',
        apiKey: apiKey,
        baseUrl: 'https://token.sensenova.cn',
        chatPath: '/v1/chat/completions',
      );

  AiConfig copyWith({
    AiProvider? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
    String? chatPath,
    String? modelsPath,
    String? balancePath,
  }) => AiConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        chatPath: chatPath ?? this.chatPath,
        modelsPath: modelsPath ?? this.modelsPath,
        balancePath: balancePath ?? this.balancePath,
      );
}

class AppProvider extends ChangeNotifier {
  String? _apiKey;
  bool _isGameStarted = false;
  DisplayMode _displayMode = DisplayMode.magazine;
  IdentityMode _identityMode = IdentityMode.native;
  Era _era = Era.harry_same;
  AiProvider _aiProvider = AiProvider.deepseek;
  String _aiModel = 'deepseek-chat';
  Map<String, String> _apiKeys = {};
  Map<String, String> _baseUrls = {};
  Map<String, String> _models = {};
  Map<AiScene, String> _sceneRoute = Map<AiScene, String>.from(kDefaultRoute);

  String? get apiKey => _apiKey;
  bool get isGameStarted => _isGameStarted;
  DisplayMode get displayMode => _displayMode;
  IdentityMode get identityMode => _identityMode;
  Era get era => _era;
  AiProvider get aiProvider => _aiProvider;
  String get aiModel => _aiModel;
  Map<String, String> get apiKeys => Map.unmodifiable(_apiKeys);
  Map<String, String> get baseUrls => Map.unmodifiable(_baseUrls);
  Map<String, String> get models => Map.unmodifiable(_models);
  Map<String, String> get providerModels => Map.unmodifiable(_models);
  Map<AiScene, String> get sceneRoute => Map.unmodifiable(_sceneRoute);

  String providerModel(AiProvider p) => _models[p.name] ?? _defaultModel(p);

  AiProvider providerForScene(AiScene scene) {
    final name = _sceneRoute[scene] ?? kDefaultRoute[scene]!;
    return AiProvider.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AiProvider.deepseek,
    );
  }

  AiConfig configForProvider(AiProvider provider) {
    final key = _apiKeys[provider.name] ?? '';
    final model = _models[provider.name] ?? _defaultModel(provider);
    final customBaseUrl = _baseUrls[provider.name];
    switch (provider) {
      case AiProvider.deepseek:
        return AiConfig.deepseek(key).copyWith(model: model, baseUrl: customBaseUrl);
      case AiProvider.zhipu:
        return AiConfig.zhipu(key).copyWith(model: model, baseUrl: customBaseUrl);
      case AiProvider.agnes:
        return AiConfig.agnes(key).copyWith(model: model, baseUrl: customBaseUrl);
      case AiProvider.sensenova:
        return AiConfig.sensenova(key).copyWith(model: model, baseUrl: customBaseUrl);
    }
  }

  bool hasKey(AiProvider provider) =>
      _apiKeys.containsKey(provider.name) && _apiKeys[provider.name]!.isNotEmpty;

  String _defaultModel(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return 'deepseek-v4-flash';
      case AiProvider.zhipu:
        return 'glm-4.7-flash';
      case AiProvider.agnes:
        return 'agnes-2.5-turbo';
      case AiProvider.sensenova:
        return 'sensenova-6.7-flash-lite';
    }
  }

  AiConfig get aiConfig {
    final key = _apiKeys[_aiProvider.name] ?? _apiKey ?? '';
    final customBaseUrl = _baseUrls[_aiProvider.name];
    switch (_aiProvider) {
      case AiProvider.deepseek:
        return AiConfig.deepseek(key).copyWith(
          model: _aiModel,
          baseUrl: customBaseUrl,
        );
      case AiProvider.zhipu:
        return AiConfig.zhipu(key).copyWith(
          model: _aiModel,
          baseUrl: customBaseUrl,
        );
      case AiProvider.agnes:
        return AiConfig.agnes(key).copyWith(
          model: _aiModel,
          baseUrl: customBaseUrl,
        );
      case AiProvider.sensenova:
        return AiConfig.sensenova(key).copyWith(
          model: _aiModel,
          baseUrl: customBaseUrl,
        );
    }
  }

  List<String> get availableModels {
    switch (_aiProvider) {
      case AiProvider.deepseek:
        return ['deepseek-v4-flash', 'deepseek-v4-pro', 'deepseek-chat', 'deepseek-reasoner'];
      case AiProvider.zhipu:
        return ['glm-4.7-flash', 'glm-4-flash', 'glm-4', 'glm-4-long'];
      case AiProvider.agnes:
        return ['agnes-2.5-turbo', 'agnes-2.5-flash', 'agnes-2.5-pro', 'agnes-2.5'];
      case AiProvider.sensenova:
        // 平台公测版模型（参考 https://platform.sensenova.cn/docs）
        // sensenova-u1-fast 是信息图生成专用模型，不走 chat completions，
        // 但用户想通过自定义模型名调用时可以手动输入。
        return [
          'sensenova-6.7-flash-lite', // 主力：256K上下文+多模态+Tool Calls
          'deepseek-v4-flash',         // SenseNova平台上也提供（公测白嫖配额）
          'sensenova-u1-fast',         // 信息图生成（chat接口不适用时保留模型项）
        ];
    }
  }

  String get providerLabel {
    switch (_aiProvider) {
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.zhipu:
        return '智谱 AI';
      case AiProvider.agnes:
        return 'Agnes';
      case AiProvider.sensenova:
        return 'SenseNova·商汤日日新';
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isGameStarted = prefs.getBool('game_started') ?? false;
    _displayMode = DisplayMode.values[prefs.getInt('display_mode') ?? 0];
    _identityMode = IdentityMode.values[prefs.getInt('identity_mode') ?? 0];
    _era = Era.values[prefs.getInt('era') ?? 2];
    _aiProvider = AiProvider.values[prefs.getInt('ai_provider') ?? 0];
    _aiModel = prefs.getString('ai_model') ?? 'deepseek-v4-flash';

    // 迁移旧版单一明文 api_key → 安全存储
    final legacyApiKey = prefs.getString('api_key');
    if (legacyApiKey != null && legacyApiKey.isNotEmpty) {
      await KeyStore.instance.writeKey(_aiProvider.name, legacyApiKey);
      await prefs.remove('api_key');
    }

    final providers = ['deepseek', 'zhipu', 'agnes', 'sensenova'];
    for (final p in providers) {
      // API Key 优先从安全存储读取；旧版明文自动迁移并清除
      var key = await KeyStore.instance.readKey(p);
      if (key == null) {
        final legacyKey = prefs.getString('api_key_$p');
        if (legacyKey != null && legacyKey.isNotEmpty) {
          key = legacyKey;
          await KeyStore.instance.writeKey(p, legacyKey);
          await prefs.remove('api_key_$p');
        }
      }
      if (key != null && key.isNotEmpty) _apiKeys[p] = key;

      final url = prefs.getString('base_url_$p');
      if (url != null && url.isNotEmpty) _baseUrls[p] = url;
      final model = prefs.getString('model_$p');
      if (model != null && model.isNotEmpty) _models[p] = model;
    }

    final currentKey = _apiKeys[_aiProvider.name];
    if (currentKey != null) _apiKey = currentKey;

    // Load scene routes
    for (final scene in AiScene.values) {
      final saved = prefs.getString('scene_route_${scene.name}');
      if (saved != null && saved.isNotEmpty) {
        _sceneRoute[scene] = saved;
      }
    }

    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    _apiKeys[_aiProvider.name] = key;
    await KeyStore.instance.writeKey(_aiProvider.name, key);
    notifyListeners();
  }

  /// 保存指定提供商的 API Key（安全存储）
  Future<void> saveApiKeyFor(AiProvider provider, String key) async {
    if (key.isEmpty) {
      _apiKeys.remove(provider.name);
      await KeyStore.instance.deleteKey(provider.name);
    } else {
      _apiKeys[provider.name] = key;
      await KeyStore.instance.writeKey(provider.name, key);
    }
    if (provider == _aiProvider) {
      _apiKey = key.isEmpty ? null : key;
    }
    notifyListeners();
  }

  Future<void> setAiProvider(AiProvider provider) async {
    _aiProvider = provider;
    final key = _apiKeys[provider.name];
    if (key != null) _apiKey = key;
    final defaults = {
      AiProvider.deepseek: 'deepseek-v4-flash',
      AiProvider.zhipu: 'glm-4.7-flash',
      AiProvider.agnes: 'agnes-2.5-turbo',
      AiProvider.sensenova: 'sensenova-6.7-flash-lite',
    };
    _aiModel = defaults[provider]!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_provider', provider.index);
    await prefs.setString('ai_model', _aiModel);
    notifyListeners();
  }

  Future<void> setAiModel(String model) async {
    _aiModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_model', model);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    if (url.trim().isEmpty) {
      _baseUrls.remove(_aiProvider.name);
    } else {
      _baseUrls[_aiProvider.name] = url.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    if (url.trim().isEmpty) {
      await prefs.remove('base_url_${_aiProvider.name}');
    } else {
      await prefs.setString('base_url_${_aiProvider.name}', url.trim());
    }
    notifyListeners();
  }

  void setGameStarted(bool started) {
    _isGameStarted = started;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('game_started', started));
    notifyListeners();
  }

  void setDisplayMode(DisplayMode mode) {
    if (_identityMode == IdentityMode.transmigration && mode == DisplayMode.magazine) {
      return;
    }
    _displayMode = mode;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('display_mode', mode.index));
    notifyListeners();
  }

  void setIdentityMode(IdentityMode mode) {
    if (_displayMode == DisplayMode.magazine && mode == IdentityMode.transmigration) {
      return;
    }
    _identityMode = mode;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('identity_mode', mode.index));
    notifyListeners();
  }

  void setEra(Era era) {
    _era = era;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('era', era.index));
    notifyListeners();
  }

  Future<void> setSceneRoute(AiScene scene, AiProvider provider) async {
    _sceneRoute[scene] = provider.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scene_route_${scene.name}', provider.name);
    notifyListeners();
  }

  Future<void> setModelForProvider(AiProvider provider, String model) async {
    _models[provider.name] = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_${provider.name}', model);
    if (_aiProvider == provider) {
      _aiModel = model;
      await prefs.setString('ai_model', model);
    }
    notifyListeners();
  }

  List<String> availableModelsFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return ['deepseek-v4-flash', 'deepseek-v4-pro', 'deepseek-chat', 'deepseek-reasoner'];
      case AiProvider.zhipu:
        return ['glm-4.7-flash', 'glm-4.7', 'glm-4-flash', 'glm-4', 'glm-4-long'];
      case AiProvider.agnes:
        return ['agnes-2.5-turbo', 'agnes-2.5-flash', 'agnes-2.5-pro', 'agnes-2.5'];
      case AiProvider.sensenova:
        return ['sensenova-6.7-flash-lite', 'deepseek-v4-flash'];
    }
  }

  /// 免费模型（官方提供免费额度 / 极低资费）
  List<String> freeModelsFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return ['deepseek-chat'];
      case AiProvider.zhipu:
        return ['glm-4-flash', 'glm-4.7-flash'];
      case AiProvider.agnes:
        return ['agnes-2.5-flash', 'agnes-2.5-turbo'];
      case AiProvider.sensenova:
        return ['sensenova-6.7-flash-lite'];
    }
  }

  /// 常用付费模型（按性价比与质量推荐）
  List<String> popularPaidModelsFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return ['deepseek-v4-pro', 'deepseek-reasoner'];
      case AiProvider.zhipu:
        return ['glm-4.7', 'glm-4', 'glm-4-long'];
      case AiProvider.agnes:
        return ['agnes-2.5-pro', 'agnes-2.5'];
      case AiProvider.sensenova:
        return ['deepseek-v4-flash'];
    }
  }

  void clearApiKey() {
    _apiKey = null;
    _apiKeys.remove(_aiProvider.name);
    _baseUrls.remove(_aiProvider.name);
    KeyStore.instance.deleteKey(_aiProvider.name);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('api_key');
      prefs.remove('api_key_${_aiProvider.name}');
      prefs.remove('base_url_${_aiProvider.name}');
    });
    notifyListeners();
  }

  void clearApiKeyFor(AiProvider p) {
    _apiKeys.remove(p.name);
    _baseUrls.remove(p.name);
    KeyStore.instance.deleteKey(p.name);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('api_key_${p.name}');
      prefs.remove('base_url_${p.name}');
    });
    notifyListeners();
  }
}
