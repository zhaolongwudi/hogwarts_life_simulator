import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/provider_defaults.dart';
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

  /// 三家工厂统一从 kProviderDefaults 取值。
  /// 原先这里各自写死 model/baseUrl，与 AppProvider._defaultModel 和
  /// 设置页的三份副本取值不一致（Agnes 一边 turbo 一边 flash）。
  factory AiConfig.deepseek(String apiKey) => AiConfig._fromDefaults(
        provider: AiProvider.deepseek,
        apiKey: apiKey,
      );

  factory AiConfig.agnes(String apiKey) =>
      AiConfig._fromDefaults(provider: AiProvider.agnes, apiKey: apiKey);

  /// 商汤日日新 SenseNova
  factory AiConfig.sensenova(String apiKey) =>
      AiConfig._fromDefaults(provider: AiProvider.sensenova, apiKey: apiKey);

  factory AiConfig._fromDefaults({
    required AiProvider provider,
    required String apiKey,
  }) {
    final d = defaultsForProvider(provider.name);
    return AiConfig(
      provider: provider,
      model: d.model,
      apiKey: apiKey,
      baseUrl: d.baseUrl,
      chatPath: d.chatPath,
      modelsPath: d.modelsPath,
      balancePath: d.balancePath,
    );
  }

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
  Map<String, List<String>> _apiKeys = {};
  Map<String, String> _baseUrls = {};
  Map<String, String> _models = {};
  Map<AiScene, String> _sceneRoute = Map<AiScene, String>.from(kDefaultRoute);
  bool _aiDebugLogEnabled = false;

  String? get apiKey => _apiKey;
  bool get isGameStarted => _isGameStarted;
  DisplayMode get displayMode => _displayMode;
  IdentityMode get identityMode => _identityMode;
  Era get era => _era;
  bool get aiDebugLogEnabled => _aiDebugLogEnabled;
  Map<String, String> get models => Map.unmodifiable(_models);
  String providerModel(AiProvider p) => _models[p.name] ?? _defaultModel(p);

  AiProvider providerForScene(AiScene scene) {
    final name = _sceneRoute[scene] ?? kDefaultRoute[scene]!;
    return AiProvider.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AiProvider.deepseek,
    );
  }

  /// 返回指定提供商的所有配置文件（每个 API Key 一个 config）
  List<AiConfig> configsForProvider(AiProvider provider) {
    final keys = keysForProvider(provider);
    if (keys.isEmpty) return [];
    final model = _models[provider.name] ?? _defaultModel(provider);
    final customBaseUrl = _baseUrls[provider.name];
    return keys.map((key) {
      switch (provider) {
        case AiProvider.deepseek:
          return AiConfig.deepseek(key).copyWith(model: model, baseUrl: customBaseUrl);
        case AiProvider.agnes:
          return AiConfig.agnes(key).copyWith(model: model, baseUrl: customBaseUrl);
        case AiProvider.sensenova:
          return AiConfig.sensenova(key).copyWith(model: model, baseUrl: customBaseUrl);
      }
    }).toList();
  }


  /// 指定提供商是否有至少一个 API Key
  bool hasKey(AiProvider provider) => keysForProvider(provider).isNotEmpty;

  /// 指定提供商的 API Key 数量
  int keyCount(AiProvider provider) => keysForProvider(provider).length;

  /// 获取指定提供商的所有 API Key
  List<String> keysForProvider(AiProvider provider) =>
      _apiKeys[provider.name] ?? [];

  String _defaultModel(AiProvider provider) =>
      defaultsForProvider(provider.name).model;


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

    // 迁移旧版单一明文 api_key → 安全存储
    final legacyApiKey = prefs.getString('api_key');
    if (legacyApiKey != null && legacyApiKey.isNotEmpty) {
      await KeyStore.instance.writeKey(_aiProvider.name, legacyApiKey);
      await prefs.remove('api_key');
    }

    final providers = ['deepseek', 'agnes', 'sensenova'];
    for (final p in providers) {
      // 先尝试加载多 key（带索引的 key）
      final multiKeys = await KeyStore.instance.readKeys(p);
      if (multiKeys.isNotEmpty) {
        _apiKeys[p] = multiKeys;
      } else {
        // 单 key 模式：优先从安全存储读取；旧版明文自动迁移并清除
        var key = await KeyStore.instance.readKey(p);
        if (key == null) {
          final legacyKey = prefs.getString('api_key_$p');
          if (legacyKey != null && legacyKey.isNotEmpty) {
            key = legacyKey;
            await KeyStore.instance.writeKey(p, legacyKey);
            await prefs.remove('api_key_$p');
          }
        }
        if (key != null && key.isNotEmpty) _apiKeys[p] = [key];
      }

      final url = prefs.getString('base_url_$p');
      if (url != null && url.isNotEmpty) _baseUrls[p] = url;
      final model = prefs.getString('model_$p');
      if (model != null && model.isNotEmpty) _models[p] = model;
    }

    final currentKeys = _apiKeys[_aiProvider.name];
    if (currentKeys != null && currentKeys.isNotEmpty) _apiKey = currentKeys.first;

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
    if (key.isEmpty) {
      _apiKeys.remove(_aiProvider.name);
      await KeyStore.instance.deleteKey(_aiProvider.name);
    } else {
      _apiKeys[_aiProvider.name] = [key];
      await KeyStore.instance.writeKeys(_aiProvider.name, [key]);
    }
    notifyListeners();
  }

  // ========== 多 Key 支持 ==========
  /// 删除指定提供商的第 index 个 API Key
  Future<void> removeApiKeyAt(AiProvider provider, int index) async {
    final existing = keysForProvider(provider);
    if (index < 0 || index >= existing.length) return;
    existing.removeAt(index);
    if (existing.isEmpty) {
      _apiKeys.remove(provider.name);
      await KeyStore.instance.writeKeys(provider.name, []);
    } else {
      _apiKeys[provider.name] = existing;
      await KeyStore.instance.writeKeys(provider.name, existing);
    }
    if (provider == _aiProvider) {
      _apiKey = existing.isEmpty ? null : existing.first;
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

  /// 把「随机时代」落定成具体时代，但**不写进偏好**。
  ///
  /// 与 [setEra] 唯一的区别是不落盘：玩家在设置里选的是"随机时代"，
  /// 这个偏好应当保留——下一局还要能再随机一次。
  /// 走 setEra 的话，第一局掷到的时代会被存进 SharedPreferences，
  /// 从此"随机时代"就退化成"上一次随机到的时代"。
  ///
  /// 落定之后这一整局的所有 `appProvider.era` 引用都会拿到具体时代，
  /// 事件锚点、NPC 种子、违禁词、校长表才对得上。
  void lockEra(Era era) {
    _era = era;
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
    notifyListeners();
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
  void clearApiKeyFor(AiProvider p) {
    _apiKeys.remove(p.name);
    _baseUrls.remove(p.name);
    KeyStore.instance.deleteKey(p.name);
    KeyStore.instance.writeKeys(p.name, []);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('api_key_${p.name}');
      prefs.remove('base_url_${p.name}');
    });
    notifyListeners();
  }

  /// 切换 AI 调试日志开关，同步写入 SharedPreferences 持久化
  /// 批量设置指定提供商的所有 API Key（一次性写入，避免多次 notifyListeners）
  Future<void> setAllKeysForProvider(AiProvider provider, List<String> keys) async {
    if (keys.isEmpty) {
      clearApiKeyFor(provider);
      return;
    }
    _apiKeys[provider.name] = List<String>.from(keys);
    await KeyStore.instance.writeKeys(provider.name, keys);
    if (provider == _aiProvider) {
      _apiKey = keys.first;
    }
    notifyListeners();
  }

  Future<void> setAiDebugLogEnabled(bool value) async {
    _aiDebugLogEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_debug_log_enabled', value);
    notifyListeners();
  }
}
