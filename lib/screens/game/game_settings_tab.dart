import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/app_provider.dart';
import '../settings_screen.dart';

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
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.tune, color: Color(0xFFD3A625)),
                  title: const Text('🔧 打开完整设置'),
                  subtitle: const Text('显示模式、身份定位、时代背景、场景路由、Token 统计、调试日志'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
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
