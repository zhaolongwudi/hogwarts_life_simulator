// ignore_for_file: unnecessary_string_interpolations, prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class SaveLoadScreen extends StatefulWidget {
  const SaveLoadScreen({super.key});

  @override
  State<SaveLoadScreen> createState() => _SaveLoadScreenState();
}

class _SaveLoadScreenState extends State<SaveLoadScreen> {
  int _tab = 0;
  List<Map<String, dynamic>> _saves = [];
  bool _isLoading = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSaves();
  }

  Future<void> _loadSaves() async {
    setState(() => _isLoading = true);
    _saves = await context.read<GameProvider>().listSaves();
    setState(() => _isLoading = false);
  }

  Future<void> _saveCurrentGame() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入存档名称')),
      );
      return;
    }

    final gp = context.read<GameProvider>();
    setState(() => _isLoading = true);
    await gp.quickSave();
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 已保存')),
      );
    }
  }

  Future<void> _loadSave(String slotId) async {
    await context.read<GameProvider>().loadFromSave(slotId);
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, '/game');
    }
  }

  Future<void> _deleteSave(String slotId) async {
    await context.read<GameProvider>().deleteSave(slotId);
    await _loadSaves();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('存档 / 读档')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildTab('📥 存档', _tab == 0)),
                const SizedBox(width: 16),
                Expanded(child: _buildTab('📤 读档', _tab == 1)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _tab == 0 ? _buildSavePanel() : _buildLoadPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _tab = label.contains('存档') ? 0 : 1),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFFD3A625) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFD3A625) : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSavePanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('创建新存档',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: '输入存档名称...',
              prefixIcon: Icon(Icons.bookmark),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveCurrentGame,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('💾 保存游戏'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadPanel() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_saves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无存档', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _saves.length,
      itemBuilder: (context, index) =>
          _buildSaveCard(_saves[index]),
    );
  }

  Widget _buildSaveCard(Map<String, dynamic> save) {
    return Card(
      color: const Color(0xFF21262d),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF740001),
          child: Icon(Icons.save, color: Colors.white),
        ),
        title: Text(save['name'] ?? '未命名',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${save['saved_at']?.toString().substring(0, 16) ?? ''}',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Color(0xFFD3A625)),
              onPressed: () => _loadSave(save['id']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteSave(save['id']),
            ),
          ],
        ),
      ),
    );
  }
}
