import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/npc.dart';
import '../../models/player.dart';
import '../../providers/game_provider.dart';
import '../../utils/ui_helpers.dart';

// ==================== 姻缘一线牵红娘 ====================
class MatchmakerScreen extends StatefulWidget {
  const MatchmakerScreen({super.key});

  @override
  State<MatchmakerScreen> createState() => _MatchmakerScreenState();
}

class _MatchmakerScreenState extends State<MatchmakerScreen> {
  List<_Match> _matches = [];
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

    final matches = <_Match>[];
    for (int i = 0; i < candidates.length; i++) {
      for (int j = i + 1; j < candidates.length; j++) {
        final a = candidates[i];
        final b = candidates[j];
        int score = 0;

        if (a.house == b.house) score += 20;
        if (a.grade == b.grade) score += 15;
        if ((a.affection + b.affection) > 20) score += 10;

        final personalityOverlap =
            a.personality.where((p) => b.personality.contains(p)).length;
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
          matches.add(_Match(
            npcA: a,
            npcB: b,
            score: score,
            reason: _generateReason(a, b, score),
          ));
        }
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
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
    if (a.personality.any((p) => p.contains('温柔')) &&
        b.personality.any((p) => p.contains('幽默'))) {
      reasons.add('性格互补');
    }
    if (reasons.isEmpty) reasons.add('缘分天定');
    return reasons.join(' · ');
  }

  void _ship(NPC a, NPC b) {
    final gp = context.read<GameProvider>();
    final err = gp.startShipping(a.name, b.name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '💞 开始留意 ${a.name} × ${b.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _release(int index) {
    final gp = context.read<GameProvider>();
    gp.stopShipping(index);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已经放手了'), duration: Duration(seconds: 2)),
    );
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
            tooltip: '重新分析',
            onPressed: () {
              _analyzeMatches();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('重新分析中...')));
            },
          ),
        ],
      ),
      body: _isAnalyzing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildShippingPanel(),
                Expanded(
                  child: _matches.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _matches.length,
                          itemBuilder: (context, index) =>
                              _buildMatchCard(_matches[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border,
              size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('暂无匹配'),
          const SizedBox(height: 8),
          Text('继续游戏以结识更多NPC',
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
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
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
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
                const Text('红娘牵线',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '为你找到 ${_matches.length} 对可能的缘分；撮合后他们同框时羁绊会加深',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 已撮合面板：绑定真实的 player.shippings
  Widget _buildShippingPanel() {
    return Consumer<GameProvider>(
      builder: (context, gp, _) {
        final ships = gp.player?.shippings ?? const <ShipRecord>[];
        if (ships.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.pink.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 16, color: Colors.pink),
                    const SizedBox(width: 6),
                    const Text('我在撮合',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${ships.length}/5',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8B949E))),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < ships.length; i++) _buildShipRow(ships[i], i),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShipRow(ShipRecord s, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.pairLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: s.bond / 100,
                          minHeight: 6,
                          backgroundColor: Colors.pink.withValues(alpha: 0.12),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.pink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${s.bond}/100 阶段${s.stage}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8B949E))),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: '放手',
            visualDensity: VisualDensity.compact,
            onPressed: () => _release(index),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(_Match match) {
    final npcA = match.npcA;
    final npcB = match.npcB;
    final score = match.score;

    return Consumer<GameProvider>(
      builder: (context, gp, _) {
        final ships = gp.player?.shippings ?? const <ShipRecord>[];
        final key = ShipRecord.keyOf(npcA.name, npcB.name);
        final shipping = ships.any((s) => s.key == key);
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
                    Expanded(child: _buildPersonChip(npcA)),
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
                          const Icon(Icons.favorite,
                              size: 16, color: Colors.pink),
                        ],
                      ),
                    ),
                    Expanded(child: _buildPersonChip(npcB)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: Color(0xFFD3A625)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                match.reason,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: shipping ? null : () => _ship(npcA, npcB),
                      icon: Icon(shipping ? Icons.check : Icons.favorite_border,
                          size: 16),
                      label: Text(shipping ? '已撮合' : '撮合'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              style: TextStyle(
                  fontSize: 20,
                  color: houseColor,
                  fontWeight: FontWeight.bold),
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

class _Match {
  final NPC npcA;
  final NPC npcB;
  final int score;
  final String reason;

  const _Match({
    required this.npcA,
    required this.npcB,
    required this.score,
    required this.reason,
  });
}
