import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/npc.dart';
import '../../providers/game_provider.dart';
import '../npc_chat_screen.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/npc_avatar.dart';

// ==================== 日记系统 ====================
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    final gp = context.read<GameProvider>();
    final worldState = gp.worldState;
    final player = gp.player;

    if (player != null) {
      _entries.addAll([
        {
          'date': '${worldState.time.month}月${worldState.time.day}日',
          'time': '${worldState.time.hour}:${worldState.time.minute.toString().padLeft(2, '0')}',
          'title': '入学第一天',
          'content': '今天终于来到了霍格沃茨！城堡在阳光下闪闪发光。在大礼堂吃了丰盛的早餐，然后开始了第一堂课。认识了几个新朋友，感觉这一年会很有趣。',
          'mood': '😊',
          'isGenerated': true,
        },
        {
          'date': '${worldState.time.month}月${worldState.time.day}日',
          'time': '${worldState.time.hour}:${worldState.time.minute.toString().padLeft(2, '0')}',
          'title': '分院帽的抉择',
          'content': '分院帽在我头上犹豫了好久...我真的很紧张。最后它宣布了结果，那一刻我的心跳几乎停止了。',
          'mood': '😰',
          'isGenerated': true,
        },
      ]);
    }

    if (_entries.isEmpty) {
      _entries.addAll([
        {
          'date': '1991年9月1日',
          'time': '09:00',
          'title': '入学第一天',
          'content': '今天终于来到了霍格沃茨！城堡在阳光下闪闪发光。',
          'mood': '😊',
          'isGenerated': false,
        },
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的日记'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('还没有日记'),
                  const SizedBox(height: 8),
                  Text('点击右下角开始写日记吧', style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) => _buildEntryCard(_entries[index], index),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEntryDialog,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(entry['mood'] ?? '📖', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry['date']} · ${entry['time']}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                      Text(
                        entry['title'] ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (entry['isGenerated'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('系统', style: TextStyle(fontSize: 10, color: Colors.blue)),
                  )
                else
                  GestureDetector(
                    onTap: () => _deleteEntry(index),
                    child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF8B949E)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              entry['content'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedMood = '😊';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('写日记'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('选择心情:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['😊', '😄', '😰', '😢', '😡', '😍', '🤔', '😴'].map((mood) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedMood = mood),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedMood == mood
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedMood == mood
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(mood, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                contentController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                  final gp = context.read<GameProvider>();
                  setState(() {
                    _entries.insert(0, {
                      'date': '${gp.worldState.time.month}月${gp.worldState.time.day}日',
                      'time': '${gp.worldState.time.hour}:${gp.worldState.time.minute.toString().padLeft(2, '0')}',
                      'title': titleController.text,
                      'content': contentController.text,
                      'mood': selectedMood,
                      'isGenerated': false,
                    });
                  });
                  titleController.dispose();
                  contentController.dispose();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('日记已保存')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }
}

// ==================== 平行世界小剧场 ====================
