import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../services/ai_router.dart';
import '../services/deepseek_service.dart';

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
      final savedKeys = Map<String, String>.from(appProvider.apiKeys);
      savedKeys[p.name] = key;
      await SharedPreferences.getInstance().then((prefs) async {
        await prefs.setString('api_key_${p.name}', key);
      });
    }

    if (model.isNotEmpty) {
      final savedModels = Map<String, String>.from(appProvider.providerModels);
      savedModels[p.name] = model;
      await SharedPreferences.getInstance().then((prefs) async {
        await prefs.setString('provider_model_${p.name}', model);
      });
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
          chatPath: '/chat/completions',
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
      case AiProvider.zhipu:
        return 'https://open.bigmodel.cn';
      case AiProvider.agnes:
        return 'https://apihub.agnes-ai.cn';
      case AiProvider.sensenova:
        return 'https://platform.sensenova.cn';
    }
  }

  String defaultModel(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'deepseek-v4-flash';
      case AiProvider.zhipu:
        return 'glm-4.7-flash';
      case AiProvider.agnes:
        return 'agnes-2.5-flash';
      case AiProvider.sensenova:
        return 'SenseNova-N8';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

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
          ...AiProvider.values.map((p) => _buildProviderCard(p, appProvider)),
          const SizedBox(height: 16),
          _buildSceneRouting(appProvider),
          const SizedBox(height: 16),
          _buildTokenUsage(),
          const SizedBox(height: 20),
          const Text('📺 显示模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('选择游戏界面的显示风格',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          _buildModePicker(appProvider.displayMode.name,
              disabled: appProvider.identityMode == IdentityMode.transmigration
                  ? const {'magazine'}
                  : null,
              onSelect: (v) {
                if (v == 'magazine') context.read<AppProvider>().setDisplayMode(DisplayMode.magazine);
                else if (v == 'compact') context.read<AppProvider>().setDisplayMode(DisplayMode.compact);
                else context.read<AppProvider>().setDisplayMode(DisplayMode.immersive);
              }),
          const SizedBox(height: 24),
          const Text('🎭 身份模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('选择玩家在游戏中的身份定位',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
          const SizedBox(height: 12),
          _buildModePicker(appProvider.identityMode.name,
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
              }),
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
          _buildEraPicker(appProvider.era.name),
          const SizedBox(height: 24),
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

  Widget _buildProviderCard(AiProvider p, AppProvider appProvider) {
    final hasKey = appProvider.hasKey(p);
    final desc = kProviderDescriptions[p] ?? '';
    final testResult = _testResults[p];
    final testSuccess = _testSuccess[p];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252C36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: hasKey ? const Color(0xFF10B981) : const Color(0xFF374151),
            width: hasKey ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  providerNameLabel(p),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              if (hasKey)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text('已配置', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                  ],
                )
              else
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('未配置', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 8),
          Text('API Key',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _keyControllers[p]!,
                  obscureText: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'sk-...',
                    helperText: '获取地址: ${defaultBaseUrl(p)}',
                    helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: () => _saveKeyAndModel(p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD3A625),
                    foregroundColor: const Color(0xFF1C232D),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('模型（可选覆盖默认）',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _modelControllers[p]!,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: defaultModel(p),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: _testing ? null : () => _testConnection(p),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD3A625)),
                    foregroundColor: const Color(0xFFD3A625),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 40),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD3A625)),
                        )
                      : const Text('测试', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (testResult != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (testSuccess ?? false)
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    (testSuccess ?? false) ? Icons.check_circle : Icons.error,
                    size: 14,
                    color: (testSuccess ?? false) ? const Color(0xFF10B981) : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      testResult,
                      style: TextStyle(
                        fontSize: 11,
                        color: (testSuccess ?? false) ? const Color(0xFF10B981) : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSceneRouting(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C232D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFFD3A625), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('🔀 多模型路由配置',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('为不同场景分配 AI 提供商，实现最优成本与效果',
              style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
          const SizedBox(height: 10),
          ...AiScene.values.map((scene) => _buildSceneRow(scene, appProvider)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 场景预估',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD3A625))),
                SizedBox(height: 6),
                Text('• 主剧情: 1500-3000 token/回合 | 约8次/游戏小时',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8B949E), height: 1.4)),
                Text('• 摘要压缩: 800-1200 token/次 | 每10回合触发1次',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8B949E), height: 1.4)),
                Text('• NPC聊天: 300-800 token/次 | 按需调用',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8B949E), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneRow(AiScene scene, AppProvider appProvider) {
    final provider = appProvider.providerForScene(scene);
    final description = kSceneDescriptions[scene] ?? '';
    final label = kSceneLabels[scene] ?? scene.name;
    final hasKey = appProvider.hasKey(provider);
    final info = _sceneInfo(scene);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF252C36),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        if (!hasKey)
                          const Text('未配置Key',
                              style: TextStyle(fontSize: 11, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            color: Color(0xFF8B949E), fontSize: 11, height: 1.3)),
                    const SizedBox(height: 2),
                    Text(info,
                        style: const TextStyle(
                            color: Color(0xFFD3A625), fontSize: 10.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: AiProvider.values.map((p) {
              final selected = provider == p;
              final hasP = appProvider.hasKey(p);
              return GestureDetector(
                onTap: () => appProvider.setSceneRoute(scene, p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFD3A625).withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFD3A625)
                          : (hasP
                              ? const Color(0xFF4B5563)
                              : const Color(0xFF374151)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        providerNameLabel(p),
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? const Color(0xFFD3A625)
                              : (hasP ? Colors.white : const Color(0xFF6B7280)),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (!hasP) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock, size: 11, color: Color(0xFF6B7280)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _sceneInfo(AiScene scene) {
    switch (scene) {
      case AiScene.narrative:
        return '≈1500-3000 token/回合 · 约8次/小时';
      case AiScene.summary:
        return '≈800-1200 token/次 · 每10回合1次';
      case AiScene.npcChat:
        return '≈300-800 token/次 · 按需调用';
    }
  }

  String providerNameLabel(AiProvider p) {
    switch (p) {
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.zhipu:
        return '智谱';
      case AiProvider.agnes:
        return 'Agnes';
      case AiProvider.sensenova:
        return 'SenseNova';
    }
  }

  Widget _buildModePicker(String current,
      {List<ModeOption>? modes,
      Set<String>? disabled,
      ValueChanged<String>? onSelect}) {
    final items = modes ?? const [
      ModeOption('魔法手账', 'magazine', '默认推荐，显示日期/地点/状态'),
      ModeOption('简洁', 'compact', '信息密度更高'),
      ModeOption('沉浸', 'immersive', '纯小说叙事，无UI标签'),
    ];
    return Column(
      children: items.map((m) {
        final isDisabled = disabled?.contains(m.value) ?? false;
        final isSelected = current == m.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected ? const Color(0xFF740001).withValues(alpha: 0.2) : const Color(0xFF21262d),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isDisabled ? null : () => onSelect?.call(m.value),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFD3A625) : const Color(0xFF30363d),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFFD3A625) : const Color(0xFF8B949E),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDisabled ? const Color(0xFF484f58) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.desc,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEraPicker(String current) {
    final eras = const [
      EraOption('邓布利多时代', 'dumbledore', '1892-1899 · 少年邓布利多与格林德沃'),
      EraOption('掠夺者时代', 'marauders', '詹姆、小天狼星、卢平、斯内普的学生时代'),
      EraOption('第一次巫师战争', 'first_war', '社会氛围紧张'),
      EraOption('哈利同期', 'harry_same', '与哈利同一年入学（默认）'),
      EraOption('战后时代', 'post_war', '伏地魔战争结束后'),
      EraOption('随机时代', 'random', '系统随机选择'),
    ];
    return Column(
      children: eras.map((e) {
        final isSelected = current == e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected ? const Color(0xFF740001).withValues(alpha: 0.2) : const Color(0xFF21262d),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (e.value == 'dumbledore') context.read<AppProvider>().setEra(Era.dumbledore);
                else if (e.value == 'marauders') context.read<AppProvider>().setEra(Era.marauders);
                else if (e.value == 'first_war') context.read<AppProvider>().setEra(Era.first_war);
                else if (e.value == 'harry_same') context.read<AppProvider>().setEra(Era.harry_same);
                else if (e.value == 'post_war') context.read<AppProvider>().setEra(Era.post_war);
                else context.read<AppProvider>().setEra(Era.random);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFD3A625) : const Color(0xFF30363d),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFFD3A625) : const Color(0xFF8B949E),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFFE6EDF3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.desc,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTokenUsage() {
    final gp = context.watch<GameProvider>();
    final hasData = gp.apiCalls > 0;
    final tokens = gp.totalTokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFFD3A625), size: 18),
              const SizedBox(width: 6),
              const Text('📈 Token 使用统计',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD3A625))),
              const Spacer(),
              if (hasData)
                TextButton(
                  onPressed: () {
                    gp.resetTokenUsage();
                    setState(() {});
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('重置', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasData)
            const Text('暂无数据，开始游戏后将自动统计',
                style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)))
          else ...[
            _buildStatRow('API 调用次数', '${gp.apiCalls} 次', const Color(0xFF3B82F6)),
            const SizedBox(height: 6),
            _buildStatRow('输入 Token', _formatNumber(gp.totalPromptTokens), const Color(0xFF8B5CF6)),
            const SizedBox(height: 6),
            _buildStatRow('输出 Token', _formatNumber(gp.totalCompletionTokens), const Color(0xFF10B981)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD3A625).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('总消耗', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD3A625))),
                  Text(_formatNumber(tokens),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD3A625))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFFC9D1D9))),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class ModeOption {
  final String label;
  final String value;
  final String desc;
  const ModeOption(this.label, this.value, this.desc);
}

class EraOption {
  final String label;
  final String value;
  final String desc;
  const EraOption(this.label, this.value, this.desc);
}
