import 'package:flutter/material.dart';


// ==================== 平行世界小剧场 ====================
class ParallelWorldScreen extends StatefulWidget {
  const ParallelWorldScreen({super.key});

  @override
  State<ParallelWorldScreen> createState() => _ParallelWorldScreenState();
}

class _ParallelWorldScreenState extends State<ParallelWorldScreen> {
  final List<Map<String, String>> _scenarios = [
    {
      'title': '如果斯内普教授是个搞笑担当',
      'description': '某天早上，斯内普用夸张的语调说："哦~看呐，又一个磨磨蹭蹭的家伙来上我的课了~"',
      'icon': '🎭',
    },
    {
      'title': '如果分院帽直接按成绩分配',
      'description': '不再看勇气和忠诚，只看成绩单。所有学霸都去了拉文克劳...',
      'icon': '🎓',
    },
    {
      'title': '如果魁地奇比赛没有扫把',
      'description': '选手们只能用想象力飞行。结果每场比赛都成了冥想课。',
      'icon': '🧹',
    },
    {
      'title': '如果邓布利多开了家甜品店',
      'description': '新的"蜂蜜公爵"由邓布利多亲自经营，招牌产品是"凤凰涅槃蛋糕"。',
      'icon': '🍰',
    },
    {
      'title': '如果魔法部改成民主选举',
      'description': '选举日成了全魔法界的盛事，候选人辩论比魁地奇比赛还精彩。',
      'icon': '🗳️',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('平行世界·小剧场'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _scenarios.length,
        itemBuilder: (context, index) => _buildScenarioCard(_scenarios[index]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateScenarioDialog,
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildScenarioCard(Map<String, String> scenario) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showScenarioDetail(scenario),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(scenario['icon']!, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scenario['title']!,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  scenario['description']!,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScenarioDetail(Map<String, String> scenario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(scenario['icon']!, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(child: Text(scenario['title']!)),
          ],
        ),
        content: Text(scenario['description']!, style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('小剧场已收藏')),
              );
            },
            child: const Text('收藏'),
          ),
        ],
      ),
    );
  }

  void _showCreateScenarioDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = '🎭';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创作小剧场'),
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
                  controller: descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('选择图标:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['🎭', '🎓', '🧹', '🍰', '🗳️', '⚡', '🔮', '🎨'].map((icon) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selectedIcon == icon
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedIcon == icon
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
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
                descController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty && descController.text.isNotEmpty) {
                  setState(() {
                    _scenarios.insert(0, {
                      'title': titleController.text,
                      'description': descController.text,
                      'icon': selectedIcon,
                    });
                  });
                  titleController.dispose();
                  descController.dispose();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 姻缘一线牵红娘 ====================
