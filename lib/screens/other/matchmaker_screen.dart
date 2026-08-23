import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/npc.dart';
import '../../providers/game_provider.dart';
import '../npc_chat_screen.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/npc_avatar.dart';

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
