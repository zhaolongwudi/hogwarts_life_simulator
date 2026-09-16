import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'other/diary_screen.dart';
import '../providers/game_provider.dart';
import '../data/collectible_data.dart';
import '../data/cg_data.dart';
import '../models/world_state.dart';
import '../theme/miuix_tokens.dart';
import '../theme/miuix_typography.dart';
import '../widgets/miui_magic_backdrop.dart';
import '../widgets/miuix_components.dart';
import '../widgets/miuix_overlays.dart';

/// 「你的回忆」：大事记 / 收藏 / CG 画廊。
///
/// 这一页以前整个是写死的样板：
///  · 大事记只有一张硬编码的「第1年·9月 · 主线」卡片，底下接一句
///    「—— 全文完 ——」，跟玩家实际经历了什么毫无关系；
///  · 收藏页和 CG 画廊页是两句写死的「暂无收藏」「暂无CG」占位，从来不读
///    player.collection / player.cgRecords——哪怕玩家已经收了一堆东西；
///  · 顶栏的导出按钮弹「导出功能即将上线」；
///  · 「按时间 / 最新更新」两个排序 chip 点了只改一个没人读的 _sortMode。
///
/// 三个分页现在都读真实数据。CG 画廊直接复用日记页的 CgGalleryTab，不另抄
/// 一份（抄了就是两边各写各的，迟早长得不一样）。
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  int _tab = 0;

  /// 0 = 按时间（先发生的在前），1 = 最新在前。真正用来排序，不再是个摆设。
  int _sortMode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('你的回忆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出为文本',
            onPressed: _exportAsText,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MiuiMagicBackdrop(density: 0.5)),
          Column(
            children: [
              _buildTabs(),
              Expanded(child: _buildTabContent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
      child: MiuiSegmented<int>(
        segments: const {0: '大事记', 1: '收藏', 2: 'CG画廊'},
        selected: _tab,
        onChanged: (v) => setState(() => _tab = v),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 1:
        return _buildCollectionView();
      case 2:
        final gp = context.watch<GameProvider>();
        return CgGalleryTab(recs: gp.player?.cgRecords ?? const {});
      default:
        return _buildChronicleView();
    }
  }

  // ==================== 大事记 ====================

  Widget _buildChronicleView() {
    final events = context.watch<GameProvider>().worldState.recentNarrativeEvents;
    final ordered = _sortMode == 1 ? events.reversed.toList() : events.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('大事记', style: MiuiType.title4),
              const Spacer(),
              _buildSortChip('按时间', 0),
              const SizedBox(width: 8),
              _buildSortChip('最新在前', 1),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '共 ${events.length} 条（只保留最近 20 条）',
            style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
          ),
          const SizedBox(height: 12),
          if (ordered.isEmpty)
            _emptyHint('还没有发生过什么值得记下来的事。\n'
                '关键行动、解锁成就、关系变化都会自动记在这里。')
          else
            for (var i = 0; i < ordered.length; i++) ...[
              _buildEventRow(i + 1, ordered[i]),
              const SizedBox(height: 8),
            ],
          ..._buildTimelineBranches(),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineBranches() {
    final branches = context.watch<GameProvider>().worldState.timelineBranches;
    if (branches.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      const Text('世界线分叉',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      for (final b in branches.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🌿 ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(b,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium!.color)),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildEventRow(int number, NarrativeEvent event) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.turn != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('第 ${event.turn} 回合',
                        style: const TextStyle(
                            fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
                  ),
                Text(event.text,
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium!.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, int mode) {
    final isActive = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerTheme.color!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ==================== 收藏 ====================

  Widget _buildCollectionView() {
    final owned = context.watch<GameProvider>().player?.collection ?? const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('收藏', style: MiuiType.title4),
              const Spacer(),
              Text('${owned.length}/${kCollectibleCatalog.length}',
                  style: const TextStyle(fontSize: 13, color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ),
          const SizedBox(height: 12),
          if (owned.isEmpty)
            _emptyHint('还一件都没有。\n'
                '· 吃一只「巧克力蛙」，包装里会附赠著名巫师画片；\n'
                '· 买下「魁地奇徽章」即收进册子；\n'
                '· 进禁林转转，运气好能捡到独角兽尾毛。')
          else
            for (final series in collectibleSeries)
              _buildSeriesBlock(series, owned),
        ],
      ),
    );
  }

  Widget _buildSeriesBlock(String series, List<String> owned) {
    final all = collectiblesInSeries(series);
    final got = all.where((c) => owned.contains(c.id)).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(series,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MiuiColors.primaryVariant)),
              const SizedBox(width: 8),
              Text('${got.length}/${all.length}',
                  style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in all) _buildCollectibleCard(c, owned.contains(c.id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectibleCard(CollectibleDef c, bool has) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: has ? () => _showCollectibleDetail(c) : null,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: has ? cs.primary.withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has ? cs.primary : cs.surface.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              has ? c.name : '？？？',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: has ? null : MiuiColors.onSurfaceVariantSummary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (has) ...[
              const SizedBox(height: 2),
              Text(c.starText,
                  style: const TextStyle(fontSize: 11, color: MiuiColors.primaryVariant)),
            ],
          ],
        ),
      ),
    );
  }

  void _showCollectibleDetail(CollectibleDef c) {
    showMiuixDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${c.series}　${c.starText}',
                  style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
              const SizedBox(height: 10),
              Text(c.desc),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          color: Theme.of(context).textTheme.bodyMedium!.color,
        ),
      ),
    );
  }

  // ==================== 导出 ====================

  /// 把三个分页的内容拼成一段文本复制到剪贴板。
  ///
  /// 顶栏那个按钮以前弹「导出功能即将上线」，而玩家想留一份自己的故事，
  /// 除了手抄没有别的办法。
  Future<void> _exportAsText() async {
    final gp = context.read<GameProvider>();
    final p = gp.player;
    final ws = gp.worldState;
    final buf = StringBuffer('《你的回忆》\n');
    buf.writeln('${ws.time.year} 年 ${ws.time.month} 月 ${ws.time.day} 日　'
        '第 ${gp.turnCount} 回合\n');

    buf.writeln('── 大事记 ──');
    final events = ws.recentNarrativeEvents;
    if (events.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final e in events) {
        buf.writeln(e.turn == null ? '· ${e.text}' : '· [第${e.turn}回合] ${e.text}');
      }
    }

    buf.writeln('\n── 收藏 ──');
    final owned = p?.collection ?? const <String>[];
    if (owned.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final series in collectibleSeries) {
        final all = collectiblesInSeries(series);
        final got = all.where((c) => owned.contains(c.id));
        if (got.isEmpty) continue;
        buf.writeln('$series（${got.length}/${all.length}）');
        for (final c in got) {
          buf.writeln('  · ${c.name} ${c.starText}');
        }
      }
    }

    buf.writeln('\n── CG ──');
    final cgs = p?.cgRecords ?? const {};
    if (cgs.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final cg in allCgs()) {
        final rec = cgs[cg.id];
        if (rec == null) continue;
        buf.writeln('· ${cg.name}（${cg.chapter}）　解锁于 ${rec.unlockedDate}');
      }
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('回忆已复制到剪贴板')),
    );
  }
}
