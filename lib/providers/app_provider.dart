import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DisplayMode { magazine, compact, immersive }
enum IdentityMode { native, transmigration }
enum Era { marauders, first_war, harry_same, post_war, random, dumbledore }
enum AiProvider { deepseek, zhipu, agnes }

class AiConfig {
  final AiProvider provider;
  final String model;
  final String apiKey;
  final String baseUrl;
  final String chatPath;
  final String modelsPath;

  const AiConfig({
    required this.provider,
    required this.model,
    required this.apiKey,
    required this.baseUrl,
    this.chatPath = '/v1/chat/completions',
    this.modelsPath = '/v1/models',
  });

  factory AiConfig.deepseek(String apiKey) => AiConfig(
        provider: AiProvider.deepseek,
        model: 'deepseek-chat',
        apiKey: apiKey,
        baseUrl: 'https://api.deepseek.com',
      );

  factory AiConfig.zhipu(String apiKey) => AiConfig(
        provider: AiProvider.zhipu,
        model: 'glm-4-flash',
        apiKey: apiKey,
        baseUrl: 'https://open.bigmodel.cn',
        chatPath: '/api/paas/v4/chat/completions',
        modelsPath: '/api/paas/v4/models',
      );

  factory AiConfig.agnes(String apiKey) => AiConfig(
        provider: AiProvider.agnes,
        model: 'agnes-2.5-flash',
        apiKey: apiKey,
        baseUrl: 'https://apihub.agnes-ai.cn',
      );

  AiConfig copyWith({
    AiProvider? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
    String? chatPath,
    String? modelsPath,
  }) => AiConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        chatPath: chatPath ?? this.chatPath,
        modelsPath: modelsPath ?? this.modelsPath,
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

  String? get apiKey => _apiKey;
  bool get isGameStarted => _isGameStarted;
  DisplayMode get displayMode => _displayMode;
  IdentityMode get identityMode => _identityMode;
  Era get era => _era;
  AiProvider get aiProvider => _aiProvider;
  String get aiModel => _aiModel;
  Map<String, String> get apiKeys => Map.unmodifiable(_apiKeys);

  AiConfig get aiConfig {
    final key = _apiKeys[_aiProvider.name] ?? _apiKey ?? '';
    switch (_aiProvider) {
      case AiProvider.deepseek:
        return AiConfig.deepseek(key).copyWith(model: _aiModel);
      case AiProvider.zhipu:
        return AiConfig.zhipu(key).copyWith(model: _aiModel);
      case AiProvider.agnes:
        return AiConfig.agnes(key).copyWith(model: _aiModel);
    }
  }

  List<String> get availableModels {
    switch (_aiProvider) {
      case AiProvider.deepseek:
        return ['deepseek-chat', 'deepseek-reasoner'];
      case AiProvider.zhipu:
        return ['glm-4-flash', 'glm-4', 'glm-4-long'];
      case AiProvider.agnes:
        return ['agnes-2.5-flash', 'agnes-2.5-pro', 'agnes-2.5'];
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
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _isGameStarted = prefs.getBool('game_started') ?? false;
    _displayMode = DisplayMode.values[prefs.getInt('display_mode') ?? 0];
    _identityMode = IdentityMode.values[prefs.getInt('identity_mode') ?? 0];
    _era = Era.values[prefs.getInt('era') ?? 2];
    _aiProvider = AiProvider.values[prefs.getInt('ai_provider') ?? 0];
    _aiModel = prefs.getString('ai_model') ?? 'deepseek-chat';

    final providers = ['deepseek', 'zhipu', 'agnes'];
    for (final p in providers) {
      final key = prefs.getString('api_key_$p');
      if (key != null) _apiKeys[p] = key;
    }

    final currentKey = _apiKeys[_aiProvider.name];
    if (currentKey != null) _apiKey = currentKey;

    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    _apiKeys[_aiProvider.name] = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    await prefs.setString('api_key_${_aiProvider.name}', key);
    notifyListeners();
  }

  Future<void> setAiProvider(AiProvider provider) async {
    _aiProvider = provider;
    final key = _apiKeys[provider.name];
    if (key != null) _apiKey = key;
    final defaults = {
      AiProvider.deepseek: 'deepseek-chat',
      AiProvider.zhipu: 'glm-4-flash',
      AiProvider.agnes: 'agnes-2.5-flash',
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

  void clearApiKey() {
    _apiKey = null;
    _apiKeys.remove(_aiProvider.name);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('api_key');
      prefs.remove('api_key_${_aiProvider.name}');
    });
    notifyListeners();
  }
}
