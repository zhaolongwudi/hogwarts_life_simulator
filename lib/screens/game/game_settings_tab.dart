import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/app_provider.dart';
import '../settings/settings_scene_routing.dart';
import '../settings/settings_preset_pickers.dart';
import '../settings/settings_token_usage.dart';

class GameSettingsInlineTab extends StatefulWidget {
  const GameSettingsInlineTab({super.key});

  @override
  State<GameSettingsInlineTab> createState() => _GameSettingsInlineTabState();
}

class _GameSettingsInlineTabState extends State<GameSettingsInlineTab> {
  int _tokenUsage = 0;

  @override
  Widget build(BuildContext context) {
    return _buildSettingsTab();
  }

  Widget _buildSettingsTopBar(GameProvider gp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTopBarAction(
            icon: Icons.sync,
            label: '同步剧本',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✨ 正在同步剧本...')),
              );
            },
          ),
          _buildTopBarAction(
            icon: Icons.save,
            label: '存读档',
            onTap: () async {
              await gp.quickSave();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 已存档')),
                );
              }
            },
          ),
          _buildTopBarAction(
            icon: Icons.import_export,
            label: '导入导出',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📦 导入导出功能')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTokenUsageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bolt, size: 18, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              const Text('Token 用量统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本月消耗', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      const SizedBox(height: 4),
                      Text('$_tokenUsage', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Tokens', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('预计费用', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      const SizedBox(height: 4),
                      Text('\$${(_tokenUsage * 0.0001).toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('基于当前模型', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '本应用使用本地 API Key 直接调用 AI 服务，不收取任何平台费用。实际费用取决于您选择的 AI 提供商的计费标准。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('上次本地自动备份 刚刚', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📊 查看详细用量报表')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 18),
                  SizedBox(width: 8),
                  Text('用量明细', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('💾 正在导出本地数据...')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 8),
                  Text('导出存档数据', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final appProvider = context.watch<AppProvider>();
    final gp = context.read<GameProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSettingsTopBar(gp),
          const SizedBox(height: 12),
          _buildTokenUsageSection(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI 引擎', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 12),
                const Text('选择 AI 提供商', style: TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 8),
                _buildProviderPicker(appProvider),
                const SizedBox(height: 12),
                if (appProvider.availableModels.isNotEmpty) ...[
                  const Text('选择模型', style: TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                  const SizedBox(height: 8),
                  _buildModelPicker(appProvider),
                  const SizedBox(height: 12),
                ],
                const Text('API Key', style: TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 8),
                _buildApiKeyInput(appProvider, gp),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('文字展示与阅读速度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: const Text('AI 输出优先', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerTheme.color!),
                        ),
                        child: const Text('阅读优先', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('阅读速度', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSpeedChip('慢 10字/秒', false)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSpeedChip('中 20字/秒', true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSpeedChip('快 30字/秒', false)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('危险操作', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('清除 API Key'),
                  subtitle: const Text('删除当前提供商的 API Key'),
                  trailing: const Icon(Icons.delete, color: Colors.red),
                  onTap: () {
                    appProvider.clearApiKey();
                  },
                ),
                const SizedBox(height: 20),
                const Text('显示与模式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Consumer<AppProvider>(builder: (ctx, app, _) => Column(children: [
                  SettingsPresetPickers.buildModePicker(app.displayMode.name,
                    disabled: const {'magazine'},
                    onSelect: (v) => app.setDisplayMode(DisplayMode.values.byName(v)),
                  ),
                  const SizedBox(height: 10),
                  SettingsPresetPickers.buildModePicker(app.identityMode.name,
                    modes: const [
                      ModeOption('pure', label: '纯血至上主义', icon: Icons.auto_awesome, color: Color(0xFFC0392B), desc: '血统至上，纯血高于一切'),
                      ModeOption('noble', label: '维护传统', icon: Icons.shield_outlined, color: Color(0xFFD4A017), desc: '维护巫师界古老传统与秩序'),
                      ModeOption('order', label: '光明阵营', icon: Icons.brightness_7_outlined, color: Color(0xFFD98880), desc: '加入邓布利多阵营对抗黑魔法'),
                      ModeOption('dark', label: '黑魔法阵营', icon: Icons.bolt_outlined, color: Color(0xFF111111), desc: '追随伏地魔追求力量至上'),
                      ModeOption('neutral', label: '中立旁观者', icon: Icons.all_inclusive_outlined, color: Color(0xFF7F8C8D), desc: '不站队，在各方间游走谋利'),
                      ModeOption('transmigration', label: '穿越者', icon: Icons.public_outlined, color: Color(0xFF2980B9), desc: '知道原著剧情，尝试改写命运'),
                      ModeOption('bone_mode', label: '骨科模式(隐藏)', icon: Icons.favorite_outline, color: Color(0xFFE91E63), desc: '解锁血缘亲属的恋爱与CG线路(⚠️伦理敏感)'),
                    ],
                    disabled: app.displayMode == DisplayMode.magazine ? const {'transmigration'} : null,
                    onSelect: (v) => app.setIdentityMode(IdentityMode.values.byName(v)),
                  ),
                  const SizedBox(height: 10),
                  SettingsPresetPickers.buildEraPicker(ctx, app.era.name,
                    onSelect: (v) => app.setEra(Era.values.byName(v)),
                  ),
                ])),
                const SizedBox(height: 24),
                const Text('场景模型路由', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Consumer<AppProvider>(builder: (ctx, app, _) => SettingsSceneRouting(
                  appProvider: app,
                  onSceneRouteChanged: (scene, provider) {
                    app.setSceneRoute(scene, provider);
                    final gp = ctx.read<GameProvider>();
                    gp.router = null;
                    gp.updateClient();
                  },
                )),
                const SizedBox(height: 24),
                const Text('Token 使用统计', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Consumer<GameProvider>(builder: (ctx, gp, _) => SettingsTokenUsage(
                  gameProvider: gp,
                  onReset: () {
                    gp.resetTokenUsage();
                    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
                    (ctx as Element).markNeedsBuild();
                  },
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPicker(AppProvider appProvider) {
    final providers = [
      ('DeepSeek', AiProvider.deepseek, 'https://platform.deepseek.com'),
      ('Agnes', AiProvider.agnes, 'https://apihub.agnes-ai.cn'),
      ('商汤日日新', AiProvider.sensenova, 'https://platform.sensenova.cn'),
    ];

    return Column(
      children: providers.map((p) {
        final isSelected = appProvider.aiProvider == p.$2;
        return GestureDetector(
          onTap: () => appProvider.setAiProvider(p.$2),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!),
            ),
            child: Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null),
                const SizedBox(width: 8),
                Expanded(child: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w500))),
                Text(p.$3, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModelPicker(AppProvider appProvider) {
    return Wrap(
      spacing: 8,
      children: appProvider.availableModels.map((model) {
        final isSelected = appProvider.aiModel == model;
        return GestureDetector(
          onTap: () => appProvider.setAiModel(model),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!),
            ),
            child: Text(model,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontSize: 13,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApiKeyInput(AppProvider appProvider, GameProvider gp) {
    return _ApiKeyInput(appProvider: appProvider, gp: gp);
  }

  Widget _buildSpeedChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : null, fontSize: 13)),
    );
  }
}

class _ApiKeyInput extends StatefulWidget {
  final AppProvider appProvider;
  final GameProvider gp;
  const _ApiKeyInput({required this.appProvider, required this.gp});

  @override
  State<_ApiKeyInput> createState() => _ApiKeyInputState();
}

class _ApiKeyInputState extends State<_ApiKeyInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.appProvider.apiKey ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'sk-...',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            await widget.gp.updateApiKey(_controller.text.trim());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已保存 API Key')),
              );
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
