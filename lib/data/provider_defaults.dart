/// 各 AI 提供商的出厂默认值：模型、端点、展示名。
///
/// 【这份数据原先散了 6 份，而且互相打架】
///
/// * `AiConfig.deepseek/agnes/sensenova` 三个工厂 —— 真正发请求时用的那份
/// * `AppProvider._defaultModel` —— 没显式选模型时的 fallback
/// * `AppProvider.setAiProvider` 里的行内 `defaults` map
/// * `settings_screen` 的 `defaultModel` / `defaultBaseUrl` / `defaultChatPath`
/// * `game_settings_tab` 的同名三件套（与上一份 86% 重复的界面）
/// * `settings_provider_card` 的 `defaultModel` / `defaultBaseUrl` / `providerNameLabel`
///
/// 后果举例：Agnes 出厂模型在发请求那侧（`configsForProvider` 的 fallback）
/// 是 `agnes-2.5-flash`，而 `setAiProvider` 与 `AiConfig.agnes` 写的是
/// `agnes-2.5-turbo`；SenseNova 在界面上是 `6.7`、在 fallback 里是 `6.8`。
/// 用户在设置页看到的和实际发出去的不是同一个模型，调参调了个寂寞。
///
/// 这里收敛成唯一一份。键用提供商的 `name`（String）而不是 `AiProvider` 枚举，
/// 免得 data 层反过来 import providers 层造成循环依赖。
class ProviderDefault {
  /// 展示名（设置页卡片标题用）
  final String displayName;

  /// 一句话定位（收起态显示，帮助用户快速区分三家）
  final String tagline;

  /// 出厂默认模型
  final String model;

  /// 该提供商可选的模型列表
  final List<String> models;

  final String baseUrl;
  final String chatPath;
  final String modelsPath;
  final String? balancePath;

  const ProviderDefault({
    required this.displayName,
    required this.tagline,
    required this.model,
    required this.models,
    required this.baseUrl,
    this.chatPath = '/v1/chat/completions',
    this.modelsPath = '/v1/models',
    this.balancePath,
  });
}

const Map<String, ProviderDefault> kProviderDefaults = {
  'deepseek': ProviderDefault(
    displayName: 'DeepSeek',
    tagline: '付费 · 高质量长文本',
    model: 'deepseek-v4-flash',
    models: [
      'deepseek-v4-flash',
      'deepseek-v4-pro',
      'deepseek-chat',
      'deepseek-reasoner',
    ],
    baseUrl: 'https://api.deepseek.com',
    balancePath: '/user/balance',
  ),
  'agnes': ProviderDefault(
    displayName: 'Agnes',
    tagline: '免费 · 响应最快',
    model: 'agnes-2.5-flash',
    models: [
      'agnes-2.5-flash',
      'agnes-2.5-turbo',
      'agnes-2.5-pro',
      'agnes-2.5',
    ],
    baseUrl: 'https://api.agnes-ai.cn',
  ),
  'sensenova': ProviderDefault(
    displayName: 'SenseNova',
    tagline: '免费 · 剧情质量最佳',
    model: 'sensenova-6.8-flash-lite',
    models: [
      'sensenova-6.8-flash-lite', // 最新：多模态智能体，1500次/5h
      'sensenova-6.7-flash-lite', // 稳定版：256K上下文，1500次/5h
      'deepseek-v4-flash', // DeepSeek对话模型，500次/5h
      'glm-5.2', // 智谱旗舰：1M上下文，500次/5h
      'sensenova-u1-fast', // 信息图生成专用（非chat场景）
    ],
    baseUrl: 'https://token.sensenova.cn',
  ),
};

/// 取指定提供商的出厂默认值；未知 provider 回落到 deepseek，
/// 免得每处调用方都写一遍 `?? const ...`。
ProviderDefault defaultsForProvider(String providerName) =>
    kProviderDefaults[providerName] ?? kProviderDefaults['deepseek']!;
