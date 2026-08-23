import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../models/world_state.dart';
import '../world_map_screen.dart';
import '../../utils/story_text_renderer.dart';

class NarrativeTab extends StatefulWidget {
  final Function(int) onNarrativeTapChoice;
  final ScrollController scrollController;
  final int subTab;
  final Function(int) onSubTabChanged;

  const NarrativeTab({
    super.key,
    required this.onNarrativeTapChoice,
    required this.scrollController,
    required this.subTab,
    required this.onSubTabChanged,
  });

  @override
  State<NarrativeTab> createState() => _NarrativeTabState();
}

class _NarrativeTabState extends State<NarrativeTab> {
  bool _expandedStats = false;

  Widget _buildPanelContent(Player player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCharacterPanel(player),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WorldMapScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.map, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('霍格沃茨魔法世界', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('点击打开完整世界地图', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMapMiniTag('霍格沃茨', Icons.castle),
                    const SizedBox(width: 8),
                    _buildMapMiniTag('霍格莫德村', Icons.store),
                    const SizedBox(width: 8),
                    _buildMapMiniTag('对角巷', Icons.shopping_bag),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildEventList(),
      ],
    );
  }

  Widget _buildPanelEventTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onSubTabChanged(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: widget.subTab == 0 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('事件',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.subTab == 0 ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onSubTabChanged(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: widget.subTab == 1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('面板',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.subTab == 1 ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final gp = context.read<GameProvider>();
    final events = gp.worldState.recentEvents.isNotEmpty
        ? gp.worldState.recentEvents.take(8).toList()
        : <NarrativeEvent>[];
    final narrativeEvents = gp.worldState.recentNarrativeEvents.isNotEmpty
        ? gp.worldState.recentNarrativeEvents.take(5).toList()
        : <NarrativeEvent>[];

    String _buildTimeLabel(NarrativeEvent event, bool isFirst, int turnCount) {
      if (isFirst) return '最新';
      final int? t = event.turn;
      if (t != null && turnCount > t) {
        final int diff = turnCount - t;
        return '$diff 回合前';
      }
      return '—';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📋 事件记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: Text('共 ${events.length + narrativeEvents.length} 条',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty && narrativeEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: const Center(
              child: Text('暂无事件记录\n行动起来创建你的故事吧！', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
            ),
          )
        else ...[
          if (narrativeEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('📖 剧情事件', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color, fontWeight: FontWeight.w600)),
            ),
            ...narrativeEvents.asMap().entries.map((entry) {
              final idx = entry.key;
              final event = entry.value;
              return _buildEventCard(event.text, _buildTimeLabel(event, idx == 0, gp.turnCount), isRecent: idx == 0);
            }),
            const SizedBox(height: 8),
          ],
          if (events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('🌍 世界动态', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color, fontWeight: FontWeight.w600)),
            ),
            ...events.asMap().entries.map((entry) {
              final idx = entry.key;
              final event = entry.value;
              return _buildEventCard(event.text, _buildTimeLabel(event, idx == 0, gp.turnCount), isRecent: idx == 0);
            }),
          ],
        ],
      ],
    );
  }

  Widget _buildEventCard(String title, String time, {bool isRecent = false}) {
    final isWorldEvent = title.startsWith('【');
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(isWorldEvent ? Icons.public : Icons.auto_awesome, size: 20, color: isRecent ? const Color(0xFFD3A625) : Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(isWorldEvent ? '世界动态详情' : '剧情事件详情')),
              ],
            ),
            content: Text(
              title,
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRecent
                ? const Color(0xFFD3A625).withValues(alpha: 0.6)
                : isWorldEvent
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                    : Theme.of(context).dividerTheme.color!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (isRecent ? const Color(0xFFD3A625) : isWorldEvent ? const Color(0xFF3B82F6) : Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWorldEvent ? Icons.public : Icons.auto_awesome,
                size: 16,
                color: isRecent ? const Color(0xFFD3A625) : isWorldEvent ? const Color(0xFF3B82F6) : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.length > 40 ? '${title.substring(0, 38)}…' : title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isRecent ? FontWeight.w700 : FontWeight.w500,
                      color: isRecent ? const Color(0xFFD3A625) : const Color(0xFFE6EDF3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).textTheme.bodyMedium!.color),
          ],
        ),
      ),
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
  @Deprecated('使用 _buildNarrativeSubTab 代替')
  Widget _buildNarrativeText(GameProvider gp) {
    final panel = gp.commandResult;
    if (panel != null && panel.isNotEmpty) {
      return _buildCommandResultPanel(gp, panel);
    }
    return const SizedBox.shrink();
  }


  Widget _buildHeaderCard(String? timestamp, String? location) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = const Color(0xFF30363D);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C232D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3A625), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFD3A625).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, color: const Color(0xFFD3A625), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timestamp,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF8F6EE),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (timestamp != null && location != null)
            Divider(
              height: 1,
              color: dividerColor.withAlpha(40),
              indent: 14,
              endIndent: 14,
            ),
          if (location != null)
            Padding(
              padding: EdgeInsets.fromLTRB(14, timestamp != null ? 2 : 10, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.room_outlined, color: Color(0xFF56D364), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE8FBEC),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
      ],
    );
  }

  Widget _buildChoiceList(GameProvider gp) {
    // 注意：快捷指令/查看类命令执行时 commandResult 非空，
    // 但 choices 已经被 processChoice 里恢复为原剧情选项，必须照常显示
    if (gp.choices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('可选行动', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...gp.choices.asMap().entries.map((entry) {
          final index = entry.key;
          final choice = entry.value;
          return GestureDetector(
            onTap: () => widget.onNarrativeTapChoice(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: Text(
                '${String.fromCharCode(65 + index)}. ${choice.text}',
                style: const TextStyle(fontSize: 14, color: Color(0xFFE6EDF3)),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCharacterPanel(Player? player) {
    if (player == null) return const SizedBox.shrink();

    final gp = context.read<GameProvider>();
    final loc = gp.worldState.currentLocation ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        player.name.isNotEmpty ? player.name[0] : '旅',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(player.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 $loc',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💰 ${gp.player?.galleons ?? 0} 加隆 · 🏦 ${gp.player?.bankGalleons ?? 0} 存 · 🎯 第${_turnCount(gp)}回合',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _expandedStats = !_expandedStats),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expandedStats ? '收起' : '属性',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      Icon(
                        _expandedStats ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAttributesSection(player),
        ],
      ),
    );
  }

  int _turnCount(GameProvider gp) => gp.turnCount;

  Widget _buildAttributesSection(Player player) {
    final basic = [
      {'label': '容貌', 'value': player.attributes['looks'] ?? 80, 'icon': Icons.face, 'color': const Color(0xFFD97706)},
      {'label': '体质', 'value': player.attributes['constitution'] ?? 50, 'icon': Icons.favorite, 'color': const Color(0xFFDC2626)},
      {'label': '智力', 'value': player.attributes['intelligence'] ?? 50, 'icon': Icons.psychology, 'color': const Color(0xFF2563EB)},
      {'label': '魅力', 'value': player.attributes['charisma'] ?? 50, 'icon': Icons.favorite_border, 'color': const Color(0xFFDB2777)},
      {'label': '体能', 'value': player.attributes['strength'] ?? 50, 'icon': Icons.fitness_center, 'color': const Color(0xFF059669)},
      {'label': '道德', 'value': player.attributes['morality'] ?? 50, 'icon': Icons.verified, 'color': const Color(0xFF7C3AED)},
    ];

    if (_expandedStats) {
      final advanced = [
        {'label': '魔咒', 'value': player.attributes['spell_understanding'] ?? 50, 'icon': Icons.auto_awesome, 'color': const Color(0xFF3B82F6)},
        {'label': '变形', 'value': player.attributes['transfiguration'] ?? 50, 'icon': Icons.transform, 'color': const Color(0xFF8B5CF6)},
        {'label': '魔药', 'value': player.attributes['potions'] ?? 50, 'icon': Icons.science, 'color': const Color(0xFF10B981)},
        {'label': '草药', 'value': player.attributes['herbology'] ?? 50, 'icon': Icons.local_florist, 'color': const Color(0xFF84CC16)},
        {'label': '黑防', 'value': player.attributes['dda'] ?? 50, 'icon': Icons.shield, 'color': const Color(0xFFEF4444)},
        {'label': '飞行', 'value': player.attributes['flying'] ?? 50, 'icon': Icons.flight, 'color': const Color(0xFF0EA5E9)},
        {'label': '勇气', 'value': player.attributes['courage'] ?? 50, 'icon': Icons.bolt, 'color': const Color(0xFFF59E0B)},
        {'label': '意志', 'value': player.attributes['willpower'] ?? 50, 'icon': Icons.self_improvement, 'color': const Color(0xFF6366F1)},
        {'label': '创造', 'value': player.attributes['creativity'] ?? 50, 'icon': Icons.psychology_alt, 'color': const Color(0xFFEC4899)},
        {'label': '社交', 'value': player.attributes['social'] ?? 50, 'icon': Icons.people_alt, 'color': const Color(0xFF14B8A6)},
        {'label': '观察', 'value': player.attributes['observation'] ?? 50, 'icon': Icons.visibility, 'color': const Color(0xFF06B6D4)},
        {'label': '逻辑', 'value': player.attributes['logic'] ?? 50, 'icon': Icons.analytics, 'color': const Color(0xFFA855F7)},
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildAttrBarCompact(basic[0])),
              const SizedBox(width: 8),
              Expanded(child: _buildAttrBarCompact(basic[1])),
              const SizedBox(width: 8),
              Expanded(child: _buildAttrBarCompact(basic[2])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildAttrBarCompact(basic[3])),
              const SizedBox(width: 8),
              Expanded(child: _buildAttrBarCompact(basic[4])),
              const SizedBox(width: 8),
              Expanded(child: _buildAttrBarCompact(basic[5])),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD3A625).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('📚 课程属性', style: TextStyle(fontSize: 11, color: Color(0xFFD3A625), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: advanced.map((a) => _buildAttrChipFull(a)).toList(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildAttrChipFull(basic[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildAttrChipFull(basic[1])),
            const SizedBox(width: 8),
            Expanded(child: _buildAttrChipFull(basic[2])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildAttrChipFull(basic[3])),
            const SizedBox(width: 8),
            Expanded(child: _buildAttrChipFull(basic[4])),
            const SizedBox(width: 8),
            Expanded(child: _buildAttrChipFull(basic[5])),
          ],
        ),
      ],
    );
  }

  Widget _buildAttrChipFull(Map<String, dynamic> attr) {
    final value = attr['value'] as int;
    final color = attr['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C232D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 13, color: color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(attr['label'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFFC9D1D9))),
              ),
              Text('$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrBarCompact(Map<String, dynamic> attr) {
    final value = attr['value'] as int;
    final color = attr['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C232D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(attr['label'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFFC9D1D9))),
              ),
              Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMiniTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;

    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildPanelEventTabs(),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              if (widget.subTab == 0) {
                // 剧情子Tab：内部Stack实现时间戳悬浮固定
                // + 同一个 SingleChildScrollView 装 legend/正文/好感变化/可选行动
                // 底部 padding 120 保证选项不被输入栏盖住，且不会出现"无限纯黑下滑"
                return _buildNarrativeSubTab(gp, constraints);
              } else {
                // 面板子Tab：正常全屏滚动手册属性面板
                return SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  child: _buildPanelContent(player),
                );
              }
            },
          ),
        ),
        if (gp.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(
                    gp.loadingStage.isNotEmpty ? gp.loadingStage : '推进中...',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (gp.lastRoundTokens > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A5568),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${gp.lastRoundTokens} tokens',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFA0AEC0)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNarrativeSubTab(GameProvider gp, BoxConstraints constraints) {
    final narrative = gp.currentNarrative ?? '';
    final commandPanel = gp.commandResult;
    // 命令面板独立显示 + 剧情正文 + 选项同时存在；不要求 narrative 非空
    // （加载中的一回合可能 narrative 为空，但 choices 可能有历史残留）
    final affectionSections = gp.lastAffectionSections;
    final header = _extractHeader(narrative);
    final timestamp = header['timestamp'];
    final location = header['location'];
    final bodyNarrative = header['body'] ?? narrative;
    final hasHeader = timestamp != null || location != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            controller: widget.subTab == 0 ? widget.scrollController : null,
            padding: EdgeInsets.only(
              top: hasHeader ? 120 : 16,
              bottom: 120,
              left: 16,
              right: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (commandPanel != null && commandPanel.isNotEmpty) ...[
                  _buildCommandResultPanel(gp, commandPanel),
                  const SizedBox(height: 12),
                ],
                _buildLegendPanel(),
                const SizedBox(height: 8),
                if (bodyNarrative.isNotEmpty) _buildBodyCard(bodyNarrative),
                if (affectionSections.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildAffectionCard(affectionSections),
                ],
                const SizedBox(height: 16),
                _buildChoiceList(gp),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (hasHeader)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeaderCard(timestamp, location),
          ),
      ],
    );
  }

  Widget _buildCommandResultPanel(GameProvider gp, String content) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF232A36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3A625).withValues(alpha: 0.5), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD3A625), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '指令结果',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD3A625)),
                ),
              ),
              GestureDetector(
                onTap: () => gp.closeCommandPanel(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFFC9D1D9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: Color(0xFFD0D7DE), height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _buildLegendItem(const Color(0xFFE3B341), '人名'),
          _buildLegendItem(const Color(0xFFFFA657), '说话人'),
          _buildLegendItem(const Color(0xFF58A6FF), '对话'),
          _buildLegendItem(const Color(0xFF56D364), '地点'),
          _buildLegendItem(const Color(0xFFBC8CFF), '物品'),
        ],
      ),
    );
  }

  Widget _buildBodyCard(String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: RichText(
        text: TextSpan(
          children: StoryTextRenderer.parseWithAffectionStyle(body),
        ),
      ),
    );
  }

  Widget _buildAffectionCard(List<String> sections) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF444444)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 本回合变化',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF8B949E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...sections.map((section) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              section,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFC9D1D9),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
