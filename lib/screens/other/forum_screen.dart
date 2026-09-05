import 'package:flutter/material.dart';
import '../../utils/ui_helpers.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../theme/miuix_tokens.dart';
import '../../widgets/miuix_overlays.dart';

// ==================== 魔法论坛 ====================
//
// 旧实现整页都是 Widget 里的硬编码常量：五条署名赫敏/纳威的样板帖，
// 跟这局剧情毫无关系，却长得跟真实游戏内容一模一样；而玩家自己发的帖
// 只是 `_posts.insert(0, …)`，退出页面即丢，点赞、回复数同理。
//
// 现在分两块：
//  · 世界传闻 —— 读 player.rumors，那是 AI 剧情里真实发生过的事
//    （表白、结婚、决斗、丑闻都会往里写），只读，不能点赞；
//  · 我发布的 —— 读 player.forumPosts，进存档，可删可赞可回复。
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  /// 玩家发帖可选的分类（不含「全部」和只读的「世界传闻」）。
  static const List<String> _postableCategories = [
    '校园八卦',
    '学术讨论',
    '魁地奇',
    '食谱分享',
    '寻人启事',
  ];

  static const List<String> _categories = ['全部', '世界传闻', ..._postableCategories];

  String _selectedCategory = '全部';

  void _showCommentDialog(ForumPost post) {
    final controller = TextEditingController();
    showMiuixDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () {
              controller.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                context.read<GameProvider>().addForumPostComment(post.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('回复已发布：$text')),
                  );
                }
              }
              controller.dispose();
              Navigator.pop(dialogContext);
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
            child: _ForumBody(
              selectedCategory: _selectedCategory,
              onComment: _showCommentDialog,
            ),
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
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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

  void _showCreatePostDialog() {
    final contentController = TextEditingController();
    String selectedCategory = _postableCategories.first;

    showMiuixDialog<void>(
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
                  items: _postableCategories
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
                final text = contentController.text.trim();
                if (text.isEmpty) return;
                context.read<GameProvider>().addForumPost(
                      category: selectedCategory,
                      content: text,
                    );
                contentController.dispose();
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('发布成功！已存入存档。')),
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

/// 论坛主体。单独拆出来是因为需要 watch provider 里的两份数据，
/// 放在父 Widget 里会让 tab 切换也跟着重建。
class _ForumBody extends StatelessWidget {
  final String selectedCategory;
  final void Function(ForumPost) onComment;

  const _ForumBody({
    required this.selectedCategory,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;
    final selected = selectedCategory;

    if (player == null) {
      return const Center(child: Text('还没有开始游戏'));
    }

    final rumors = player.rumors;
    final posts = player.forumPosts;

    final showRumors = selected == '全部' || selected == '世界传闻';
    final showPosts = selected != '世界传闻';

    final visiblePosts = showPosts
        ? posts.where((p) => selected == '全部' || p.category == selected).toList()
        : const <ForumPost>[];

    if (rumors.isEmpty && posts.isEmpty) {
      return _emptyState(context);
    }
    if (showRumors && rumors.isEmpty && visiblePosts.isEmpty) {
      return _emptyState(context);
    }
    if (!showRumors && visiblePosts.isEmpty) {
      return _emptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showRumors && rumors.isNotEmpty) ...[
          _sectionHeader(context, '世界传闻', '${rumors.length} 条'),
          const SizedBox(height: 8),
          _rumorIntro(context),
          const SizedBox(height: 10),
          for (final r in rumors) _RumorCard(text: r),
          const SizedBox(height: 18),
        ],
        if (visiblePosts.isNotEmpty) ...[
          _sectionHeader(context, '我发布的', '${visiblePosts.length} 帖'),
          const SizedBox(height: 10),
          for (final p in visiblePosts)
            _PostCard(
              post: p,
              onComment: () => onComment(p),
            ),
        ],
      ],
    );
  }

  Widget _rumorIntro(BuildContext context) {
    return Text(
      '这些是巫师界正在议论的事——由你的所作所为传出去的。',
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('这里还很安静'),
          const SizedBox(height: 6),
          Text(
            '做点值得被议论的事，传闻会出现在这里；\n也可以点右下角自己发一帖。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一条世界传闻。只读：它是你行为的后果，不是可以点赞的帖子。
class _RumorCard extends StatelessWidget {
  final String text;
  const _RumorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👁', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '有人在议论你',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玩家自己发的一帖（可点赞、回复、删除）。
class _PostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onComment;

  const _PostCard({required this.post, required this.onComment});

  @override
  Widget build(BuildContext context) {
    final gp = context.read<GameProvider>();

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
                    post.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  post.timeLabel,
                  style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.author,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(post.content, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => gp.toggleForumPostLike(post.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post.liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.liked ? Colors.red : MiuiColors.onSurfaceVariantSummary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes}',
                        style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: onComment,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.comment, size: 18, color: MiuiColors.onSurfaceVariantSummary),
                      const SizedBox(width: 4),
                      Text(
                        '${post.comments} 回复',
                        style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: post.content));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('帖子内容已复制到剪贴板')),
                      );
                    }
                  },
                  child: const Icon(Icons.share, size: 18, color: MiuiColors.onSurfaceVariantSummary),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () async {
                    final ok = await confirmDangerDialog(
                      context,
                      title: '删除帖子',
                      message: '确定要删除这篇「${post.category}」版块的帖子吗？\n帖子与全部回复、点赞将一并删除，无法恢复。',
                      confirmText: '删除',
                    );
                    if (ok) gp.removeForumPost(post.id);
                  },
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: MiuiColors.onSurfaceVariantSummary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
