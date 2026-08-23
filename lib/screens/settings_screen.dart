import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../services/deepseek_service.dart';
import '../utils/ai_debug_logger.dart';
import 'settings/settings_provider_card.dart';
import 'settings/settings_scene_routing.dart';
import 'settings/settings_preset_pickers.dart';
import 'settings/settings_token_usage.dart';
import 'settings/settings_crash_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyControllers = <AiProvider, TextEditingController>{};
  final _modelControllers = <AiProvider, TextEditingController>{};
  bool _testing = false;
  final _testResults = <AiProvider, String>{};
  final _testSuccess = <AiProvider, bool>{};

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    for (final p in AiProvider.values) {
      _keyControllers[p] = TextEditingController(text: appProvider.apiKeys[p.name] ?? '');
      _modelControllers[p] = TextEditingController(text: appProvider.providerModel(p));
    }
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    for (final c in _modelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveKeyAndModel(AiProvider p) async {
    final key = _keyControllers[p]!.text.trim();
    final model = _modelControllers[p]!.text.trim();
    final appProvider = context.read<AppProvider>();

    if (key.isNotEmpty) {
      await appProvider.saveApiKeyFor(p, key);
    }

    if (model.isNotEmpty) {
      await appProvider.setModelForProvider(p, model);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _testConnection(AiProvider p) async {
    setState(() {
      _testing = true;
      _testResults[p] = '测试中...';
      _testSuccess[p] = false;
    });

    try {
      final service = DeepSeekService(
        config: AiConfig(
          provider: p,
          apiKey: _keyControllers[p]!.text.trim(),
          baseUrl: defaultBaseUrl(p),
          chatPath: defaultChatPath(p),
          model: _modelControllers[p]!.text.trim().isEmpty
              ? defaultModel(p)
              : _modelControllers[p]!.text.trim(),
        ),
      );
      final connected = await service.checkConnection();
      if (!mounted) return;
      setState(() {
        _testResults[p] = connected ? '✅ 连接成功' : '❌ 连接失败';
        _testSuccess[p] = connected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResults[p] = '❌ $e';
        _testSuccess[p] = false;
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  String defaultBaseUrl(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'https://api.deepseek.com';
      case AiProvider.agnes:
        return 'https://api.agnes-ai.cn';
      case AiProvider.sensenova:
        return 'https://token.sensenova.cn';
    }
  }

  String defaultChatPath(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
      case AiProvider.agnes:
      case AiProvider.sensenova:
        return '/v1/chat/completions';
    }
  }

  String defaultModel(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'deepseek-v4-flash';
      case AiProvider.agnes:
        return 'agnes-2.5-flash';
      case AiProvider.sensenova:
        return 'sensenova-6.7-flash-lite';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final gp = context.watch<GameProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('🤖 AI 服务配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('选择并配置您的 AI 提供商',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          ...AiProvider.values.map((p) => SettingsProviderCard(
            provider: p,
            appProvider: appProvider,
            keyController: _keyControllers[p]!,
            modelController: _modelControllers[p]!,
            testing: _testing,
            testResult: _testResults[p],
            testSuccess: _testSuccess[p],
            onSave: () => _saveKeyAndModel(p),
            onTest: () => _testConnection(p),
            onModelPresetSelected: (m) {
              context.read<AppProvider>().setModelForProvider(p, m);
              setState(() {});
            },
          )),
          const SizedBox(height: 16),
          SettingsSceneRouting(
            appProvider: appProvider,
            onSceneRouteChanged: (scene, provider) {
              appProvider.setSceneRoute(scene, provider);
              context.read<GameProvider>().refreshClient();
            },
          ),
          const SizedBox(height: 16),
          SettingsTokenUsage(
            gameProvider: gp,
            onReset: () {
              gp.resetTokenUsage();
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          SettingsCrashSection(),
          const SizedBox(height: 20),
          const Text('📺 显示模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('选择游戏界面的显示风格',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          SettingsPresetPickers.buildModePicker(
            appProvider.displayMode.name,
            disabled: appProvider.identityMode == IdentityMode.transmigration
                ? const {'magazine'}
                : null,
            onSelect: (v) {
              if (v == 'magazine') context.read<AppProvider>().setDisplayMode(DisplayMode.magazine);
              else if (v == 'compact') context.read<AppProvider>().setDisplayMode(DisplayMode.compact);
              else context.read<AppProvider>().setDisplayMode(DisplayMode.immersive);
            },
          ),
          const SizedBox(height: 24),
          const Text('🎭 身份模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('选择玩家在游戏中的身份定位',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          SettingsPresetPickers.buildModePicker(
            appProvider.identityMode.name,
            modes: const [
              ModeOption('原住民', 'native', '角色不知道自己是小说人物'),
              ModeOption('穿越者', 'transmigration', '角色知道这是哈利·波特世界'),
            ],
            disabled: appProvider.displayMode == DisplayMode.magazine
                ? const {'transmigration'}
                : null,
            onSelect: (v) {
              if (v == 'native') context.read<AppProvider>().setIdentityMode(IdentityMode.native);
              else context.read<AppProvider>().setIdentityMode(IdentityMode.transmigration);
            },
          ),
          if (appProvider.displayMode == DisplayMode.magazine)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '使用「魔法手账」显示模式时，身份只能是「原住民」',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
          const Text('⏳ 时代背景',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('选择游戏开始的时代',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          SettingsPresetPickers.buildEraPicker(context, appProvider.era.name),
          const SizedBox(height: 24),
          // AI 调试日志设置
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252C36),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Text('🔧 调试日志',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('启用 AI 调用日志'),
                  subtitle: const Text('记录每回合 AI 的输入输出到本地文件，用于排查 bug'),
                  value: appProvider.aiDebugLogEnabled,
                  onChanged: (v) async {
                    AiDebugLogger.instance.setEnabled(v);
                    if (v) {
                      await AiDebugLogger.instance.initialize(enabled: true);
                    }
                    await context.read<AppProvider>().setAiDebugLogEnabled(v);
                  },
                ),
                if (appProvider.aiDebugLogEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final files = await AiDebugLogger.instance.getLogFiles();
                          if (!mounted) return;
                          if (files.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('暂无日志文件')),
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            builder: (_) => LogViewerDialog(logFiles: files),
                          );
                        },
                        icon: const Icon(Icons.folder),
                        label: const Text('查看日志'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('清空日志？'),
                              content: const Text('将删除所有已保存的 AI 调用日志'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                                ElevatedButton(
                                  onPressed: () {
                                    AiDebugLogger.instance.clearAllLogs();
                                    Navigator.pop(context);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('日志已清空')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('清空'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('清空'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '日志文件保存在应用文档目录下的 ai_debug_logs 文件夹\n可用于分析上下文污染、路由错误等问题',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 危险操作
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252C36),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ 危险操作',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('清除所有 API Key'),
                  subtitle: const Text('删除本地保存的所有 AI 提供商 Key'),
                  trailing: const Icon(Icons.delete, color: Colors.red),
                  onTap: () {
                    for (final p in AiProvider.values) {
                      context.read<AppProvider>().clearApiKeyFor(p);
                      _keyControllers[p]!.clear();
                    }
                    setState(() {});
                  },
                ),
                ListTile(
                  title: const Text('开始新游戏'),
                  subtitle: const Text('重置当前游戏进度'),
                  trailing: const Icon(Icons.refresh, color: Colors.orange),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('确认？'),
                        content: const Text('所有进度将被清除，确定继续？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                          ElevatedButton(
                            onPressed: () {
                              // 先清空 GameProvider 内所有旧叙事/玩家/世界状态（摘要、近期剧情、回合计数等）
                              // 否则新游戏第一回合 Prompt 里会注入旧游戏的前情摘要，导致 AI 接着旧剧情写
                              context.read<GameProvider>().resetAllState();
                              appProvider.setGameStarted(false);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
