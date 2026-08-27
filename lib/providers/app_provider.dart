import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_router.dart';
import '../services/key_store.dart';

enum DisplayMode { magazine, compact, immersive }
enum IdentityMode { pure, noble, order, dark, neutral, transmigration, bone_mode }
enum Era { marauders, first_war, harry_same, post_war, random, dumbledore }
enum AiProvider { deepseek, agnes, sensenova }

// 场景 → 提供商名 的默认路由
// 策略：SenseNova（商汤日日新）用于主剧情/摘要/选项（免费、剧情质量最好、Token效率高），
//       Agnes 用于 NPC 聊天（免费、响应最快）；DeepSeek 为付费模型，仅个别场景手动选用，不进默认路由与自动回退。
// 用户可通过设置页面自定义路由覆盖默认值
const Map<AiScene, String> kDefaultRoute = {
  AiScene.narrative: 'sensenova',
  AiScene.summary: 'sensenova',
  AiScene.npcChat: 'agnes',
  AiScene.choice: 'sensenova',
};

// 场景简介（显示在设置页）
const Map<AiScene, String> kSceneDescriptions = {
  AiScene.narrative: '主剧情：生成每回合的叙事文本、分支选择和行动反馈。默认使用 SenseNova（商汤日日新，剧情质量最好）。',
  AiScene.summary: '剧情摘要：每10回合自动压缩历史剧情为摘要。默认使用 SenseNova（Token效率最高，省60%）。',
  AiScene.npcChat: 'NPC聊天：与游戏中角色的独立对话。默认使用 Agnes（免费、响应最快），仅在需要更强长文本能力时手动改用 DeepSeek。',
  AiScene.choice: '选项生成：独立于主剧情的选项生成，使用更强模型保证选项质量。默认使用 SenseNova。',
};

// 提供商简介（含优缺点与限制，帮助用户选择）
const Map<AiProvider, String> kProviderDescriptions = {
  AiProvider.deepseek:
      '付费模型。高质量长文本叙事，中文表现优秀。\n'
      '✅ 优点：推理能力强，支持思考模式，1M上下文\n'
      '⚠️ 限制：付费按量计费，无免费额度\n'
      '🎯 推荐：复杂推理、代码审计等高质量场景',
  AiProvider.agnes:
      '免费模型。Agnes-2.5-flash，响应速度最快（<1s首字）。\n'
      '✅ 优点：512K上下文（最长），65.5K输出，Thinking模式，永久免费不限额\n'
      '⚠️ 限制：20 RPM 硬限制（高频调用易触发429），偶有韩文输出\n'
      '🎯 推荐：NPC短对话、快速响应、需要长上下文的场景\n'
      '💡 提示：可注册多个账号获取多个Key，每个Key独立20RPM',
  AiProvider.sensenova:
      '免费模型。SenseNova·商汤日日新，多模态智能体模型。\n'
      '✅ 优点：256K上下文，剧情质量最高（评测顶级），Token效率最高（省60%）\n'
      '⚠️ 限制：6.8版响应较慢，每5小时1500次配额，deepseek/glm仅500次/5h\n'
      '🎯 推荐：主剧情、摘要等核心叙事场景（质量优先）\n'
      '💡 提示：6.8和6.7配额独立计量，可交替使用翻倍额度',
};

// 场景中文名
const Map<AiScene, String> kSceneLabels = {
  AiScene.narrative: '主剧情生成',
  AiScene.summary: '剧情摘要压缩',
  AiScene.npcChat: 'NPC独立聊天',
  AiScene.choice: '选项独立生成',
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
        model: 'sensenova-6.8-flash-lite',
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
  IdentityMode _identityMode = IdentityMode.pure;
  Era _era = Era.harry_same;
  AiProvider _aiProvider = AiProvider.deepseek;
  String _aiModel = 'deepseek-chat';
  Map<String, String> _apiKeys = {};
  Map<String, String> _baseUrls = {};
  Map<String, String> _models = {};
  Map<AiScene, String> _sceneRoute = Map<AiScene, String>.from(kDefaultRoute);
  bool _aiDebugLogEnabled = false;

  String? get apiKey => _apiKey;
  bool get isGameStarted => _isGameStarted;
  DisplayMode get displayMode => _displayMode;
  IdentityMode get identityMode => _identityMode;
  Era get era => _era;
  AiProvider get aiProvider => _aiProvider;
  String get aiModel => _aiModel;
  bool get aiDebugLogEnabled => _aiDebugLogEnabled;
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
      case AiProvider.agnes:
        return 'agnes-2.5-flash';
      case AiProvider.sensenova:
        return 'sensenova-6.8-flash-lite';
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
      case AiProvider.agnes:
        return ['agnes-2.5-flash', 'agnes-2.5-turbo', 'agnes-2.5-pro', 'agnes-2.5'];
      case AiProvider.sensenova:
        // 平台公测版模型（参考 https://platform.sensenova.cn/docs，2026-08更新）
        // 所有模型公测期间免费，但有调用次数限制（每5小时重置）
        return [
          'sensenova-6.8-flash-lite', // 最新：多模态智能体，1500次/5h
          'sensenova-6.7-flash-lite', // 稳定版：256K上下文+多模态，1500次/5h
          'deepseek-v4-flash',         // DeepSeek对话模型，500次/5h
          'glm-5.2',                   // 智谱旗舰：1M上下文+128K输出，500次/5h
          'sensenova-u1-fast',         // 信息图生成专用（非chat场景）
        ];
    }
  }

  String get providerLabel {
    switch (_aiProvider) {
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.agnes:
        return 'Agnes';
      case AiProvider.sensenova:
        return 'SenseNova·商汤日日新';
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isGameStarted = prefs.getBool('game_started') ?? false;
    final savedDisplayIdx = prefs.getInt('display_mode') ?? 0;
    _displayMode = (savedDisplayIdx >= 0 && savedDisplayIdx < DisplayMode.values.length)
        ? DisplayMode.values[savedDisplayIdx]
        : DisplayMode.values.first;
    final savedIdentityIdx = prefs.getInt('identity_mode');
    if (savedIdentityIdx == null || savedIdentityIdx < 0 || savedIdentityIdx >= IdentityMode.values.length) {
      _identityMode = IdentityMode.pure;
    } else {
      _identityMode = IdentityMode.values[savedIdentityIdx];
    }
    final savedEraIdx = prefs.getInt('era') ?? 2;
    _era = (savedEraIdx >= 0 && savedEraIdx < Era.values.length) ? Era.values[savedEraIdx] : Era.harry_same;
    final savedProviderIdx = prefs.getInt('ai_provider') ?? 0;
    _aiProvider = (savedProviderIdx >= 0 && savedProviderIdx < AiProvider.values.length)
        ? AiProvider.values[savedProviderIdx]
        : AiProvider.values.first;
    _aiModel = prefs.getString('ai_model') ?? 'deepseek-v4-flash';

    // 迁移旧版单一明文 api_key → 安全存储
    final legacyApiKey = prefs.getString('api_key');
    if (legacyApiKey != null && legacyApiKey.isNotEmpty) {
      await KeyStore.instance.writeKey(_aiProvider.name, legacyApiKey);
      await prefs.remove('api_key');
    }

    final providers = ['deepseek', 'agnes', 'sensenova'];
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

    // Load AI debug log switch
    _aiDebugLogEnabled = prefs.getBool('ai_debug_log_enabled') ?? false;

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
      AiProvider.agnes: 'agnes-2.5-turbo',
      AiProvider.sensenova: 'sensenova-6.7-flash-lite',
    };
    _aiModel = defaults[provider] ?? 'deepseek-v4-flash';
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
      case AiProvider.agnes:
        return ['agnes-2.5-flash', 'agnes-2.5-turbo'];
      case AiProvider.sensenova:
        // 公测期间全部免费，按调用次数限流（每5小时重置）
        return [
          'sensenova-6.8-flash-lite', // 1500次/5h，最新多模态智能体
          'sensenova-6.7-flash-lite', // 1500次/5h，稳定版
          'deepseek-v4-flash',         // 500次/5h
          'glm-5.2',                   // 500次/5h，1M上下文
        ];
    }
  }

  /// 常用付费模型（按性价比与质量推荐）
  List<String> popularPaidModelsFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return ['deepseek-v4-pro', 'deepseek-reasoner'];
      case AiProvider.agnes:
        return ['agnes-2.5-pro', 'agnes-2.5'];
      case AiProvider.sensenova:
        // 公测期间暂无付费模型；U1 系列为图像生成专用
        return ['sensenova-u1-fast'];
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

  /// 切换 AI 调试日志开关，同步写入 SharedPreferences 持久化
  Future<void> setAiDebugLogEnabled(bool value) async {
    _aiDebugLogEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_debug_log_enabled', value);
    notifyListeners();
  }
}
