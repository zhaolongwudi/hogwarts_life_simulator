import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../utils/story_text_renderer.dart';
import '../widgets/narrative_visuals.dart';
import '../widgets/scaled_rich_text.dart';

/// 剧情历史回放界面：查看所有已保存的剧情记录，支持翻页和分享
class StoryHistoryScreen extends StatefulWidget {
  const StoryHistoryScreen({super.key});

  @override
  State<StoryHistoryScreen> createState() => _StoryHistoryScreenState();
}

class _StoryHistoryScreenState extends State<StoryHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  static const int _turnsPerPage = 10;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final allTurns = gp.recentTurns;

    if (allTurns.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('剧情历史'),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 64, color: Color(0xFF8B949E)),
              SizedBox(height: 16),
              Text(
                '暂无剧情记录\n开始游戏后会自动保存每回合剧情',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (allTurns.length / _turnsPerPage).ceil();
    final start = _currentPage * _turnsPerPage;
    final end = (start + _turnsPerPage).clamp(0, allTurns.length);
    final displayedTurns = allTurns.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('剧情历史'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${allTurns.length} 回合',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
                Text(
                  '第 ${_currentPage + 1} / $totalPages 页',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              itemCount: displayedTurns.length,
              itemBuilder: (context, index) {
                final turnIndex = start + index;
                final narrative = displayedTurns[index];
                return _buildTurnCard(context, turnIndex + 1, narrative);
              },
            ),
          ),
          if (totalPages > 1)
            _buildPageNavigation(totalPages),
        ],
      ),
    );
  }

  Widget _buildTurnCard(BuildContext context, int turnNumber, String narrative) {
    final header = _extractHeader(narrative);
    final timestamp = header['timestamp'];
    final location = header['location'];
    final body = header['body'] ?? narrative;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF252C36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFD3A625).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 回合标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C232D),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3A625).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFD3A625).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '第 $turnNumber 回合',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD3A625),
                    ),
                  ),
                ),
                const Spacer(),
                if (timestamp != null && timestamp.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)),
                        const SizedBox(width: 3),
                        Text(
                          timestamp,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (location != null && location.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 12, color: Color(0xFF6B7280)),
                      const SizedBox(width: 3),
                      Text(
                        location.length > 12 ? '${location.substring(0, 12)}…' : location,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // 场景插图横幅
          if (location != null || timestamp != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SceneIllustrationBanner(
                location: location,
                timestamp: null,
              ),
            ),
          // 剧情正文
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildBodyContent(body),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(String body) {
    if (body.trim().isEmpty) {
      return const Text(
        '(空剧情)',
        style: TextStyle(color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
      );
    }

    final segments = StoryTextRenderer.splitIntoSegments(body);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          if (segments[i].isDialogue)
            DialogueBubble(
              speaker: segments[i].speaker,
              mood: segments[i].mood,
              text: segments[i].text,
              npcId: null, // 历史回放中不查NPC注册表，只使用名字
              houseColor: const Color(0xFFD3A625),
              animate: false, // 历史列表关闭动画，避免滚动卡顿
            )
          else
            ScaledRichText(
              text: TextSpan(
                children: StoryTextRenderer.parse(segments[i].text),
              ),
            ),
        ],
      ],
    );
  }

  Map<String, String?> _extractHeader(String narrative) {
    String? timestamp;
    String? location;
    int bodyStartIdx = 0;

    final lines = narrative.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('【时间戳】')) {
        timestamp = line.replaceFirst('【时间戳】', '').trim();
        bodyStartIdx = i + 1;
      } else if (line.startsWith('【地点】')) {
        location = line.replaceFirst('【地点】', '').trim();
        bodyStartIdx = i + 1;
      } else {
        break;
      }
    }

    final bodyLines = lines.sublist(bodyStartIdx);
    final body = bodyLines.join('\n').trim();

    return {
      'timestamp': timestamp,
      'location': location,
      'body': body.isEmpty ? null : body,
    };
  }

  Widget _buildPageNavigation(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('上一页'),
          ),
          Text(
            '${_currentPage + 1} / $totalPages',
            style: const TextStyle(
              color: Color(0xFFC9D1D9),
              fontWeight: FontWeight.w600,
            ),
          ),
          ElevatedButton(
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }
}
