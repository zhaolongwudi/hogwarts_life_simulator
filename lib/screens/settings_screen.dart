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
          const Text('DeepSeek API',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('在 https://platform.deepseek.com 获取 API Key（免费领取）',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'sk-...',
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _saveKey, child: const Text('保存')),
            ],
          ),
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
        return RadioListTile<String>(
          title: Text(m.label),
          subtitle: Text(m.desc),
          value: m.value,
          // ignore: deprecated_member_use
          groupValue: current,
          // ignore: deprecated_member_use
          onChanged: isDisabled ? null : (v) => onSelect?.call(v!),
          contentPadding: EdgeInsets.zero,
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
        return RadioListTile<String>(
          title: Text(e.label),
          subtitle: Text(e.desc),
          value: e.value,
          // ignore: deprecated_member_use
          groupValue: current,
          // ignore: deprecated_member_use
          onChanged: (v) {
            if (v == 'dumbledore') context.read<AppProvider>().setEra(Era.dumbledore);
            else if (v == 'marauders') context.read<AppProvider>().setEra(Era.marauders);
            else if (v == 'first_war') context.read<AppProvider>().setEra(Era.first_war);
            else if (v == 'harry_same') context.read<AppProvider>().setEra(Era.harry_same);
            else if (v == 'post_war') context.read<AppProvider>().setEra(Era.post_war);
            else context.read<AppProvider>().setEra(Era.random);
          },
          contentPadding: EdgeInsets.zero,
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
