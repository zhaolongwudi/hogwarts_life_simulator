import 'package:flutter/material.dart';

// ==================== 魔法论坛 ====================
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final List<Map<String, dynamic>> _posts = [
    {
      'id': 1,
      'category': '校园八卦',
      'content': '你们听说了吗？海德薇最近看起来很疲惫，会不会是送信太多了？',
      'author': '匿名巫师',
      'time': '3小时前',
      'likes': 128,
      'comments': 23,
      'liked': false,
    },
    {
      'id': 2,
      'category': '学术讨论',
      'content': '关于黑魔法防御术的教学改革，大家有什么看法？我觉得实践训练应该更多一些。',
      'author': '赫敏·格兰杰',
      'time': '1天前',
      'likes': 56,
      'comments': 12,
      'liked': false,
    },
    {
      'id': 3,
      'category': '魁地奇',
      'content': '格兰芬多 vs 斯莱特林前瞻分析：今年的比赛一定非常精彩，双方都有强力选手！',
      'author': '李·乔丹',
      'time': '2天前',
      'likes': 89,
      'comments': 34,
      'liked': false,
    },
    {
      'id': 4,
      'category': '食谱分享',
      'content': '霍格莫德村最好的热可可配方：黑巧克力+牛奶+一点点肉桂+棉花糖。冬日必备！',
      'author': '食谱达人',
      'time': '3天前',
      'likes': 42,
      'comments': 8,
      'liked': false,
    },
    {
      'id': 5,
      'category': '寻人启事',
      'content': '有人看到我的蟾蜍莱福了吗？它又不见了，我找了整个公共休息室...',
      'author': '纳威·隆巴顿',
      'time': '5天前',
      'likes': 35,
      'comments': 19,
      'liked': false,
    },
  ];

  final List<String> _categories = ['全部', '校园八卦', '学术讨论', '魁地奇', '食谱分享', '寻人启事'];
  String _selectedCategory = '全部';

  void _showCommentDialog(Map<String, dynamic> post) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('回复帖子'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '写下你的回复...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && mounted) {
                setState(() => post['comments'] = (post['comments'] as int) + 1);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('回复已发布：$text')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('发布'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('魔法论坛'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCategoryTabs(),
          Expanded(
            child: _buildPostsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((cat) {
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPostsList() {
    final filtered = _selectedCategory == '全部'
        ? _posts
        : _posts.where((p) => p['category'] == _selectedCategory).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('暂无「$_selectedCategory」的帖子'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildPostCard(filtered[index]),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    post['category'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(post['time'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  post['author'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              post['content'] as String,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      post['liked'] = !post['liked'];
                      post['likes'] += post['liked'] ? 1 : -1;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post['liked'] ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post['liked'] ? Colors.red : const Color(0xFF8B949E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post['likes']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => _showCommentDialog(post),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.comment, size: 18, color: Color(0xFF8B949E)),
                      const SizedBox(width: 4),
                      Text(
                        '${post['comments']} 回复',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制 ${post['content']} 的链接（假装）')),
                  ),
                  child: const Icon(Icons.share, size: 18, color: Color(0xFF8B949E)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog() {
    final contentController = TextEditingController();
    String selectedCategory = _categories.firstWhere((c) => c != '全部');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('发布新帖'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: _categories
                      .where((c) => c != '全部')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedCategory = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    hintText: '说点什么...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                contentController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (contentController.text.isNotEmpty) {
                  setState(() {
                    _posts.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'category': selectedCategory,
                      'content': contentController.text,
                      'author': '我',
                      'time': '刚刚',
                      'likes': 0,
                      'comments': 0,
                      'liked': false,
                    });
                  });
                  contentController.dispose();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('发布成功！')),
                  );
                }
              },
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 日记系统 ====================
