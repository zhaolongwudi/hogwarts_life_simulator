// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, prefer_const_declarations

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _checking = false;
  String? _connectionStatus;
  double? _balance;

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    _keyController.text = appProvider.apiKey ?? '';
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    await context.read<AppProvider>().saveApiKey(key);
    await context.read<GameProvider>().updateApiKey(key);
    setState(() => _connectionStatus = null);
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checking = true;
      _connectionStatus = null;
    });

    final connected = await context.read<GameProvider>().checkConnection();
    if (connected) {
      final bal = await context.read<GameProvider>().balance;
      setState(() {
        _connectionStatus = '✅ 连接成功';
        _balance = bal;
      });
    } else {
      setState(() => _connectionStatus = '❌ 连接失败，请检查 API Key');
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('AI 服务配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildProviderPicker(appProvider.aiProvider.name),
          const SizedBox(height: 12),
          _buildApiKeyInput(appProvider),
          const SizedBox(height: 8),
          _buildModelPicker(appProvider),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _checking ? null : _checkConnection,
                child: _checking
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('测试连接'),
              ),
              const SizedBox(width: 12),
              if (_connectionStatus != null)
                Text(_connectionStatus!,
                    style: TextStyle(
                        color: _connectionStatus!.startsWith('✅') ? Colors.green : Colors.red)),
            ],
          ),
          if (_balance != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('余额: \$${_balance!.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey)),
            ),
          const Divider(height: 40),
          
          const Text('显示模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
          
          const Text('身份模式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
          
          const Text('时代背景',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildEraPicker(appProvider.era.name),
          const Divider(height: 40),
          
          const Text('危险操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('清除 API Key'),
            subtitle: const Text('删除本地保存的 API Key'),
            trailing: const Icon(Icons.delete, color: Colors.red),
            onTap: () {
              appProvider.clearApiKey();
              _keyController.clear();
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
    );
  }

  Widget _buildProviderPicker(String current) {
    final providers = const [
      _ProviderOption('DeepSeek', 'deepseek', 'https://platform.deepseek.com'),
      _ProviderOption('智谱 AI', 'zhipu', 'https://open.bigmodel.cn'),
      _ProviderOption('Agnes', 'agnes', 'https://apihub.agnes-ai.cn'),
    ];
    return Column(
      children: providers.map((p) {
        final isSelected = p.value == current;
        return ListTile(
          title: Text(p.label),
          subtitle: Text(p.url, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          leading: Radio<String>(
            // ignore: deprecated_member_use
            value: p.value,
            // ignore: deprecated_member_use
            groupValue: current,
            // ignore: deprecated_member_use
            onChanged: (v) {
              if (v != null) {
                _switchProvider(v);
              }
            },
          ),
          selected: isSelected,
          onTap: () => _switchProvider(p.value),
        );
      }).toList(),
    );
  }

  void _switchProvider(String value) {
    final provider = AiProvider.values.firstWhere(
      (e) => e.name == value,
    );
    context.read<AppProvider>().setAiProvider(provider);
    final savedKey = context.read<AppProvider>().apiKeys[value];
    if (savedKey != null) {
      _keyController.text = savedKey;
    } else {
      _keyController.clear();
    }
    setState(() => _connectionStatus = null);
  }

  Widget _buildApiKeyInput(AppProvider appProvider) {
    final hint = appProvider.aiProvider == AiProvider.deepseek
        ? 'sk-...'
        : appProvider.aiProvider == AiProvider.zhipu
            ? '智谱 API Key'
            : 'Agnes API Key';
    final url = appProvider.aiProvider == AiProvider.deepseek
        ? 'https://platform.deepseek.com'
        : appProvider.aiProvider == AiProvider.zhipu
            ? 'https://open.bigmodel.cn'
            : 'https://apihub.agnes-ai.cn';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('在 $url 获取 API Key',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.key),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _saveKey, child: const Text('保存')),
          ],
        ),
      ],
    );
  }

  Widget _buildModelPicker(AppProvider appProvider) {
    final models = appProvider.availableModels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('模型', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: models.map((m) {
            final selected = appProvider.aiModel == m;
            return FilterChip(
              label: Text(m),
              selected: selected,
              onSelected: (_) => appProvider.setAiModel(m),
            );
          }).toList(),
        ),
      ],
    );
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

class _ProviderOption {
  final String label;
  final String value;
  final String url;
  const _ProviderOption(this.label, this.value, this.url);
}
