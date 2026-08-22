import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/npc.dart';
import '../providers/game_provider.dart';
import 'npc_chat_screen.dart';
import '../utils/ui_helpers.dart';

// ==================== 魔法通讯 ====================
class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final npcs = gp.npcRegistry.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('魔法通讯'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: npcs.isEmpty
                ? _buildEmptyState()
                : _buildContactsList(npcs),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewMessageDialog(npcs);
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('全部', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('格兰芬多', 'Gryffindor'),
          const SizedBox(width: 8),
          _buildFilterChip('斯莱特林', 'Slytherin'),
          const SizedBox(width: 8),
          _buildFilterChip('拉文克劳', 'Ravenclaw'),
          const SizedBox(width: 8),
          _buildFilterChip('赫奇帕奇', 'Hufflepuff'),
          const SizedBox(width: 8),
          _buildFilterChip('教职工', 'staff'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_in_talk, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('还没有联系人', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('开始游戏后会自动添加NPC', style: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildContactsList(List<NPC> npcs) {
    final filtered = npcs.where((npc) {
      if (_filter == 'all') return true;
      if (_filter == 'staff') return npc.grade == 0;
      return npc.house == _filter;
    }).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final npc = filtered[index];
        return _buildContactTile(npc);
      },
    );
  }

  Widget _buildContactTile(NPC npc) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    final affLevel = UiHelpers.getAffectionLabel(npc.affection);
    final isAlive = npc.isAlive;
    final canChat = npc.isAlive;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: !isAlive ? Colors.grey.withValues(alpha: 0.3) : Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canChat
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NpcChatScreen(npc: npc)),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: houseColor.withValues(alpha: isAlive ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: houseColor.withValues(alpha: isAlive ? 0.5 : 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      npc.name.isNotEmpty ? npc.name[0] : '?',
                      style: TextStyle(fontSize: 18, color: houseColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              npc.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: !isAlive ? Colors.grey : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (npc.isConsideringConfession)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('酝酿中', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444))),
                            ),
                          if (!isAlive)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('已离场', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          _buildAffectionBadge(npc.affection),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        affLevel,
                        style: TextStyle(
                          fontSize: 12,
                          color: !isAlive ? Colors.grey : UiHelpers.getAffectionColor(npc.affection),
                        ),
                      ),
                      if (npc.appearance.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          npc.appearance,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                      ],
                      if (npc.personalGoal != null && npc.personalGoal!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          '目标：${npc.personalGoal!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall!.color),
                        ),
                      ],
                      if (npc.recentEvents.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_stories, size: 12, color: Colors.amber.shade700),
                                  const SizedBox(width: 3),
                                  Text(
                                    '近期剧情 · ${npc.recentEvents.first}',
                                    style: TextStyle(fontSize: 10, color: Colors.amber.shade800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: canChat ? Theme.of(context).dividerColor : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAffectionBadge(int affection) {
    final color = UiHelpers.getAffectionColor(affection);
    final icon = affection >= 50 ? Icons.favorite : affection >= 0 ? Icons.sentiment_satisfied : Icons.sentiment_dissatisfied;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$affection',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showNewMessageDialog(List<NPC> npcs) {
    if (npcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有联系人')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择联系人'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: npcs.length,
            itemBuilder: (context, index) {
              final npc = npcs[index];
              return ListTile(
                title: Text(npc.name),
                subtitle: Text(UiHelpers.getAffectionLabel(npc.affection)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NpcChatScreen(npc: npc)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

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
                  onTap: () {},
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
                  onTap: () {},
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
class MatchmakerScreen extends StatefulWidget {
  const MatchmakerScreen({super.key});

  @override
  State<MatchmakerScreen> createState() => _MatchmakerScreenState();
}

class _MatchmakerScreenState extends State<MatchmakerScreen> {
  List<Map<String, dynamic>> _matches = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeMatches();
    });
  }

  void _analyzeMatches() {
    setState(() => _isAnalyzing = true);
    final gp = context.read<GameProvider>();
    final npcs = gp.npcRegistry.values.toList();

    final candidates = npcs.where((n) => n.grade > 0).toList();

    final matches = <Map<String, dynamic>>[];
    for (int i = 0; i < candidates.length; i++) {
      for (int j = i + 1; j < candidates.length; j++) {
        final a = candidates[i];
        final b = candidates[j];
        int score = 0;

        if (a.house == b.house) score += 20;
        if (a.grade == b.grade) score += 15;
        if ((a.affection + b.affection) > 20) score += 10;

        final personalityOverlap = a.personality.where((p) => b.personality.contains(p)).length;
        score += personalityOverlap * 5;

        if (a.personality.any((p) => p.contains('温柔') || p.contains('善良')) &&
            b.personality.any((p) => p.contains('幽默') || p.contains('开朗'))) {
          score += 15;
        }
        if (a.personality.any((p) => p.contains('独立') || p.contains('自信')) &&
            b.personality.any((p) => p.contains('忠诚') || p.contains('坚定'))) {
          score += 10;
        }

        if (score >= 25) {
          matches.add({
            'npcA': a,
            'npcB': b,
            'score': score,
            'reason': _generateReason(a, b, score),
          });
        }
      }
    }

    matches.sort((a, b) => b['score'].compareTo(a['score']));
    if (mounted) {
      setState(() {
        _matches = matches;
        _isAnalyzing = false;
      });
    }
  }

  String _generateReason(NPC a, NPC b, int score) {
    final reasons = <String>[];
    if (a.house == b.house) reasons.add('同院情谊');
    if (a.grade == b.grade) reasons.add('同年级');
    if (score > 40) reasons.add('高度契合');
    if (a.personality.any((p) => p.contains('温柔')) && b.personality.any((p) => p.contains('幽默'))) {
      reasons.add('性格互补');
    }
    if (reasons.isEmpty) reasons.add('缘分天定');
    return reasons.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('姻缘一线牵'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _analyzeMatches());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('重新分析中...')),
              );
            },
          ),
        ],
      ),
      body: _isAnalyzing
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('暂无匹配'),
                      const SizedBox(height: 8),
                      Text('继续游戏以结识更多NPC', style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _matches.length,
                        itemBuilder: (context, index) => _buildMatchCard(_matches[index]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.pink.withValues(alpha: 0.2),
            Colors.purple.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.pink.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.pink.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.pink, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '红娘牵线',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '为你找到 ${_matches.length} 对可能的缘分',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final npcA = match['npcA'] as NPC;
    final npcB = match['npcB'] as NPC;
    final score = match['score'] as int;
    final reason = match['reason'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildPersonChip(npcA),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: UiHelpers.getScoreColor(score),
                        ),
                      ),
                      const Icon(Icons.favorite, size: 16, color: Colors.pink),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildPersonChip(npcB),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFD3A625)),
                  const SizedBox(width: 6),
                  Text(
                    reason,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonChip(NPC npc) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: houseColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: houseColor.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              npc.name.isNotEmpty ? npc.name[0] : '?',
              style: TextStyle(fontSize: 20, color: houseColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          npc.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        if (npc.house.isNotEmpty)
          Text(
            {
              'Gryffindor': '格兰芬多',
              'Slytherin': '斯莱特林',
              'Ravenclaw': '拉文克劳',
              'Hufflepuff': '赫奇帕奇',
            }[npc.house] ?? '',
            style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
          ),
      ],
    );
  }
}
