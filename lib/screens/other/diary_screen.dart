import 'package:flutter/material.dart';
import '../../utils/ui_helpers.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../data/cg_data.dart';
import '../../models/player.dart';

// ==================== 日记 / CG 图鉴 ====================
//
// 旧实现的问题：
//  1. 一进来就往列表里塞两条写死的假日记（"入学第一天""分院帽的抉择"），
//     跟玩家实际经历毫无关系，还打着「系统」标签看起来像真的；
//  2. 玩家自己写的日记只存在 Widget 的局部变量里，退出页面就没了。
//
// 现在改成两个 Tab：
//  · CG 图鉴：直接读 player.cgRecords + allCgs()，与挑战令里的 /日记 同一份数据
//  · 我的手记：写入 player.diary，随存档持久化
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final unlocked = gp.player?.cgRecords.length ?? 0;
    final total = allCgs().length;

    return Scaffold(
      appBar: AppBar(
        title: Text('日记 · CG $unlocked/$total'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'CG 图鉴'),
            Tab(text: '我的手记'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          CgGalleryTab(recs: gp.player?.cgRecords ?? const {}),
          const _JournalTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context),
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedMood = '😊';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('写手记'),
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
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('选择心情:', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['😊', '😄', '😰', '😢', '😡', '😍', '🤔', '😴']
                        .map(
                          (mood) => GestureDetector(
                            onTap: () => setDialogState(() => selectedMood = mood),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedMood == mood
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.2)
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
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
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
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) return;
                context.read<GameProvider>().addDiaryEntry(
                      title: title,
                      content: content,
                      mood: selectedMood,
                    );
                titleController.dispose();
                contentController.dispose();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('手记已保存到存档')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- CG 图鉴（真实数据） ----------------

/// CG 图鉴本体。
///
/// 公开是为了让「你的回忆」页（lib/screens/memory_screen.dart）复用同一份
/// 实现。那一页的 CG 画廊原本是写死的「暂无CG」占位，照着这里再抄一遍就
/// 是本项目第九处「同一份东西手抄 N 遍」——两边迟早长得不一样。
class CgGalleryTab extends StatelessWidget {
  final Map<String, CgRecord> recs;

  const CgGalleryTab({required this.recs});

  @override
  Widget build(BuildContext context) {
    final chapters = <String, List<CgDef>>{};
    for (final cg in allCgs()) {
      chapters.putIfAbsent(cg.chapter, () => []).add(cg);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in chapters.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD3A625)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.where((c) => recs.containsKey(c.id)).length}/${entry.value.length}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.value
                .map((cg) => _CgCard(cg: cg, rec: recs[cg.id]))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CgCard extends StatelessWidget {
  final CgDef cg;
  final CgRecord? rec;

  const _CgCard({required this.cg, this.rec});

  @override
  Widget build(BuildContext context) {
    final unlocked = rec != null;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: unlocked ? () => _showDetail(context) : null,
      child: Container(
        width: 104,
        height: 118,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: unlocked ? cs.primary.withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked ? cs.primary : cs.surface.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unlocked ? Icons.photo : Icons.lock_outline,
              size: 28,
              color: unlocked ? cs.primary : const Color(0xFF484F58),
            ),
            const SizedBox(height: 6),
            Text(
              unlocked ? cg.name : '???',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    unlocked ? cs.onSurface : cs.onSurface.withValues(alpha: 0.35),
              ),
            ),
            const Spacer(),
            Text(
              unlocked ? cg.starText : '未解锁',
              style: TextStyle(
                fontSize: 10,
                color: unlocked
                    ? const Color(0xFFD3A625)
                    : const Color(0xFF484F58),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(cg.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cg.id} · ${cg.chapter} · ${cg.starText}'),
            const SizedBox(height: 10),
            Text('解锁条件：${cg.conditionText}'),
            const SizedBox(height: 10),
            Text('解锁于：${rec!.unlockedDate}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

// ---------------- 我的手记（持久化） ----------------

class _JournalTab extends StatelessWidget {
  const _JournalTab();

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final entries = gp.player?.diary ?? const <DiaryEntry>[];
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book,
                size: 60, color: Colors.grey.withValues(alpha: 0.45)),
            const SizedBox(height: 14),
            const Text('还没有手记'),
            const SizedBox(height: 8),
            Text(
              '点击右下角，记下今天发生的事',
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) => _JournalCard(
        entry: entries[index],
        onDelete: () async {
          final ok = await confirmDangerDialog(
            context,
            title: '删除手记',
            message: '确定要删除「${entries[index].title}」吗？删除后无法恢复。',
            confirmText: '删除',
          );
          if (ok) gp.removeDiaryEntry(index);
        },
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onDelete;

  const _JournalCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(entry.mood, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.date} · ${entry.time}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8B949E)),
                      ),
                      Text(
                        entry.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF8B949E)),
                  onPressed: onDelete,
                  tooltip: '删除',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(entry.content,
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
