import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../theme/miuix_tokens.dart';

// ==================== 平行世界小剧场 ====================
//
// 旧实现有三个毛病：
//  1. 列表开头五条硬编码的「如果斯内普教授是个搞笑担当」不加说明地混在
//     一起，看起来像是游戏内容，其实是写死的示例；
//  2. 玩家点 FAB 创作的剧本只存在 State 的局部变量里，退出页面就没了；
//  3. 详情弹窗里的「收藏」按钮点了只弹一句「小剧场已收藏」，什么也没收。
//
// 现在预设与玩家创作分成两段（预设明确标注为示例、没有收藏按钮），玩家写
// 的进 Player.parallelScenarios 随存档持久化，也可以删。

/// 内置的示例脑洞。只读，不进存档——它们是给玩家看的引子，不是游戏内容。
final List<ParallelScenario> kPresetScenarios = [
  ParallelScenario(
    title: '如果斯内普教授是个搞笑担当',
    description: '某天早上，斯内普用夸张的语调说："哦~看呐，又一个磨磨蹭蹭的家伙来上我的课了~"',
    icon: '🎭',
  ),
  ParallelScenario(
    title: '如果分院帽直接按成绩分配',
    description: '不再看勇气和忠诚，只看成绩单。所有学霸都去了拉文克劳...',
    icon: '🎓',
  ),
  ParallelScenario(
    title: '如果魁地奇比赛没有扫把',
    description: '选手们只能用想象力飞行。结果每场比赛都成了冥想课。',
    icon: '🧹',
  ),
  ParallelScenario(
    title: '如果邓布利多开了家甜品店',
    description: '新的"蜂蜜公爵"由邓布利多亲自经营，招牌产品是"凤凰涅槃蛋糕"。',
    icon: '🍰',
  ),
  ParallelScenario(
    title: '如果魔法部改成民主选举',
    description: '选举日成了全魔法界的盛事，候选人辩论比魁地奇比赛还精彩。',
    icon: '🗳️',
  ),
];

class ParallelWorldScreen extends StatelessWidget {
  const ParallelWorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mine = context.watch<GameProvider>().player?.parallelScenarios ??
        const <ParallelScenario>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('平行世界·小剧场'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, '我的创作', '${mine.length} 条'),
          if (mine.isEmpty)
            _emptyCard(context, '还没有写过。点右下角的 ✨，写一条你自己的如果。')
          else
            for (var i = 0; i < mine.length; i++)
              _ScenarioCard(
                scenario: mine[i],
                onTap: () => _showDetail(context, mine[i], index: i),
                onDelete: () {
                  context.read<GameProvider>().removeParallelScenario(i);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
                  );
                },
              ),
          const SizedBox(height: 18),
          _sectionHeader(context, '预设脑洞', '${kPresetScenarios.length} 条',
              hint: '下面这些是写死的示例，只作引子，不会进存档。'),
          for (final s in kPresetScenarios)
            _ScenarioCard(scenario: s, onTap: () => _showDetail(context, s)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String count,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(count,
                  style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint,
                style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
          ],
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color)),
    );
  }

  /// [index] 为该条在 Player.parallelScenarios 里的下标；预设脑洞不传，
  /// 于是它们没有「采纳」按钮——预设是只读的引子，不进存档。
  void _showDetail(BuildContext context, ParallelScenario s, {int? index}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(s.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Expanded(child: Text(s.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.description,
                style: const TextStyle(fontSize: 14, height: 1.6)),
            if (index != null && !s.adopted) ...[
              const SizedBox(height: 14),
              const Text(
                '采纳之后，它不会真的发生——'
                '它会变成你认真想过的另一种可能，'
                '在往后某些时刻自己想起来。收不回来。',
                style: TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
              ),
            ],
            if (s.adopted) ...[
              const SizedBox(height: 14),
              const Text('已经留在心里了。',
                  style: TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ],
        ),
        actions: [
          if (index != null && !s.adopted)
            TextButton(
              onPressed: () {
                final ok =
                    context.read<GameProvider>().adoptParallelScenario(index);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok ? '已留在心里' : '它已经在那儿了'),
                      duration: const Duration(seconds: 2)),
                );
              },
              child: const Text('留在心里'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = '🎭';
    const icons = ['🎭', '🎓', '🧹', '🍰', '🗳️', '⚡', '🔮', '🎨'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创作小剧场'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('选择图标:', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: icons.map((icon) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selectedIcon == icon
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2)
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                if (title.isEmpty || desc.isEmpty) return;
                context.read<GameProvider>().addParallelScenario(
                      title: title,
                      description: desc,
                      icon: selectedIcon,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已保存，随存档一起留存')),
                );
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final ParallelScenario scenario;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ScenarioCard({
    required this.scenario,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(scenario.icon,
                        style: const TextStyle(fontSize: 22)),
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
                              scenario.title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (onDelete != null)
                            GestureDetector(
                              onTap: onDelete,
                              child: const Icon(Icons.delete_outline,
                                  size: 18, color: MiuiColors.onSurfaceVariantSummary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scenario.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(height: 4),
                        Text('写于 ${scenario.createdAt}',
                            style: const TextStyle(
                                fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
                      ],
                      // 采纳过的留个记号：它不是"完成了"，
                      // 是"你决定把它留在心里"，而且收不回来。
                      if (scenario.adopted) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.dark_mode_outlined,
                                size: 12, color: MiuiColors.onSurfaceVariantSummary),
                            const SizedBox(width: 4),
                            Text(
                              '已留在心里',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
