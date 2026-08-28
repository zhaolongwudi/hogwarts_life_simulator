import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../models/world_state.dart';
import '../../models/npc.dart';
import '../world_map_screen.dart';
import '../../utils/story_text_renderer.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/narrative_visuals.dart';
import '../../widgets/scaled_rich_text.dart';

import '../../mixins/mixin_response_choices.dart';
import '../story_history_screen.dart';

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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onSubTabChanged(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.subTab == 0 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.subTab == 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerTheme.color!,
                      ),
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
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onSubTabChanged(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.subTab == 1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.subTab == 1
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerTheme.color!,
                      ),
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoryHistoryScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.subTab == 2 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD3A625).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 14, color: const Color(0xFFD3A625)),
                      const SizedBox(width: 4),
                      const Text('回放',
                          style: TextStyle(
                            color: Color(0xFFD3A625),
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ],
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
    // 搜索所有行，不要在找到第一个非匹配行就 break
    // 因为 enforceContinuityBridge 可能在开头插入衔接句，将【时间戳】【地点】推到后面
    // ❗修复：必须搜索完所有行，直到找到两个头部都提取到，或者搜索到末尾
    // 之前的逻辑：找到一个头部后遇到非空行就 break，会导致第二个头部没被提取
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('【时间戳】')) {
        timestamp = line.replaceFirst('【时间戳】', '').trim();
        bodyStartIdx = i + 1;
        continue;
      } else if (line.startsWith('【地点】')) {
        location = line.replaceFirst('【地点】', '').trim();
        bodyStartIdx = i + 1;
        continue;
      }
      // 不 break —— 继续搜索，直到找到两个头部或者遍历完
      // 只有当两个头部都找到了，我们才能确定正文开始位置
      if (timestamp != null && location != null) {
        // 两个都找到了，可以停止搜索了
        break;
      }
      // 否则继续搜索（衔接句、其他非头部行都跳过）
      continue;
    }

    final bodyLines = lines.sublist(bodyStartIdx.clamp(0, lines.length));
    final body = bodyLines.join('\n').trim();

    return {
      'timestamp': timestamp,
      'location': location,
      'body': body.isEmpty ? null : body,
    };
  }
  Widget _buildHeaderCard(String? timestamp, String? location,
      {double height = 96}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SceneIllustrationBanner(
        location: location,
        timestamp: timestamp,
        height: height,
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

  /// 选项区固定在正文下方（不随正文滚动），最多占 [maxHeight] 高度后内部滚动。
  /// 旧实现把选项放在长滚动列表末尾，600~800 字的叙事下玩家必须滑到底才能行动。
  Widget _buildChoiceList(GameProvider gp, {double maxHeight = 300}) {
    // 注意：快捷指令/查看类命令执行时 commandResult 非空，
    // 但 choices 已经被 processChoice 里恢复为原剧情选项，必须照常显示
    if (gp.choices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  '可选行动',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: Color(0xFFD3A625)),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: gp.choices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final choice = entry.value;
                      final displayText =
                          GameResponseChoiceMixin.sanitizeChoiceText(choice.text);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ChoiceButton(
                          label: '${String.fromCharCode(65 + index)}. $displayText',
                          onTap: () => widget.onNarrativeTapChoice(index),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        // AI 失败提示条：以前失败是静默的（只往 notifications 里塞一条），
        // 玩家看到"剧情突然变味"却不知道发生了什么
        if (gp.error != null && gp.error!.isNotEmpty)
          _AiErrorBanner(
            message: gp.error!,
            onDismiss: () => gp.clearError(),
            onRetry: gp.lastPlayerAction.trim().isNotEmpty
                ? () => gp.retryLastAction()
                : null,
          ),
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
        // 固定高度的加载槽位：旧实现用 if (isLoading) 直接插入/移除 pill，
        // 出现与消失会让正文区高度跳变约 44px，阅读时很晃眼。
        // 改成槽位常驻 + AnimatedOpacity 淡入淡出。
        SizedBox(
          height: 44,
          child: AnimatedOpacity(
            opacity: gp.isLoading ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        gp.loadingStage.isNotEmpty ? gp.loadingStage : '推进中...',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildNarrativeSubTab(GameProvider gp, BoxConstraints constraints) {
    final narrative = gp.currentNarrative;
    final commandPanel = gp.commandResult;
    // 命令面板独立显示 + 剧情正文 + 选项同时存在；不要求 narrative 非空
    // （加载中的一回合可能 narrative 为空，但 choices 可能有历史残留）
    final affectionSections = gp.lastAffectionSections;
    final header = _extractHeader(narrative);
    final timestamp = header['timestamp'];
    final location = header['location'];
    final bodyNarrative = header['body'] ?? narrative;
    final hasHeader = timestamp != null || location != null;

    // 悬浮横幅实际高度（SceneIllustrationBanner 固定 96，短屏收窄到 72）
    final bannerH = constraints.maxHeight < 520 ? 72.0 : 96.0;
    final headerReserve = hasHeader ? bannerH + 12 : 16.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部只为「真实悬浮的横幅」留位。
              // 旧实现直接写死 top: 120 / bottom: 120，共 240px 死留白；
              // 但本组件位于 Expanded 内、输入栏是下方兄弟节点（不会盖住内容），
              // 底部那 120px 从头到尾都是纯浪费，小屏上正文只剩一条缝。
              if (hasHeader) SizedBox(height: headerReserve),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.subTab == 0 ? widget.scrollController : null,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    hasHeader ? 0 : 16,
                    16,
                    8,
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
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // 选项固定在底部：600~800 字正文时不必滑到屏幕最底下才能行动
              _buildChoiceList(gp, maxHeight: constraints.maxHeight * 0.42),
            ],
          ),
        ),
        if (hasHeader)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeaderCard(timestamp, location, height: bannerH),
          ),
        Positioned(
          top: headerReserve + 12,
          left: 0,
          right: 0,
          child: const _ResourceFloat(),
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
    final gp = context.read<GameProvider>();
    final segments = StoryTextRenderer.splitIntoSegments(body);

    // 分段失败（全空）时回退到原有整段渲染
    if (segments.isEmpty) {
      return _buildPlainBodyCard(body);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            if (segments[i].isDialogue)
              _buildDialogueSegment(gp, segments[i])
            else
              ScaledRichText(
                text: TextSpan(
                  children: StoryTextRenderer.parse(segments[i].text),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 对话段：头像 + 气泡。说话人解析到 NPC 时用其头像与学院色。
  Widget _buildDialogueSegment(GameProvider gp, NarrativeSegment seg) {
    final npc = _resolveNpcBySpeaker(gp, seg.speaker);
    final houseColor = npc != null
        ? UiHelpers.getHouseColorBright(npc.house)
        : const Color(0xFFD3A625);
    return DialogueBubble(
      speaker: seg.speaker,
      mood: seg.mood,
      text: seg.text,
      npcId: npc?.id,
      houseColor: houseColor,
    );
  }

  /// 按说话人名字在 NPC 注册表中找最佳匹配（复用 NPC.nameMatchScore）。
  NPC? _resolveNpcBySpeaker(GameProvider gp, String speaker) {
    if (speaker.isEmpty || gp.npcRegistry.isEmpty) return null;
    NPC? best;
    int bestScore = 0;
    for (final npc in gp.npcRegistry.values) {
      final score = npc.nameMatchScore(speaker);
      if (score > bestScore) {
        bestScore = score;
        best = npc;
      }
    }
    return best;
  }

  /// 原有整段渲染（无对话分段时的回退）
  Widget _buildPlainBodyCard(String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: ScaledRichText(
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

/// 数值变化浮层：监听玩家关键资源在两次构建间的差值，
/// 变化时在对话区顶部飘出一行「生命 -15 · 精力 -10」的提示并渐隐。
class _ResourceFloat extends StatefulWidget {
  const _ResourceFloat();

  @override
  State<_ResourceFloat> createState() => _ResourceFloatState();
}

class _ResourceFloatState extends State<_ResourceFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Map<String, int> _prev = const {};
  String _text = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check(GameProvider gp) {
    final p = gp.player;
    if (p == null) return;
    final cur = <String, int>{
      '生命': p.health,
      '魔力': p.magic,
      '精神力': p.spirit,
      '饱食度': p.satiety,
      '精力': p.energy,
      '加隆': p.galleons,
    };
    if (_prev.isEmpty) {
      _prev = cur;
      return;
    }
    final parts = <String>[];
    cur.forEach((k, v) {
      final d = v - (_prev[k] ?? v);
      if (d != 0) parts.add('$k ${d > 0 ? '+' : ''}$d');
    });
    _prev = cur;
    if (parts.isEmpty) return;
    final text = parts.join(' · ');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _text = text);
      _ctrl
        ..stop()
        ..value = 0
        ..forward().then((_) async {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 1400));
          if (!mounted) return;
          _ctrl.reverse();
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    _check(gp);
    final anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
                .animate(anim),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF232A36).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFD3A625).withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8F6EE),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 剧情选项按钮。
///
/// 带 400ms 防抖：选项点击会触发一次 AI 请求，连点两下就会连发两条指令、
/// 既烧 token 又会把剧情推进两次。防抖期间按钮同时置灰给出视觉反馈。
class _ChoiceButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ChoiceButton({required this.label, required this.onTap});

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _locked = false;

  Future<void> _handleTap() async {
    if (_locked) return;
    setState(() => _locked = true);
    widget.onTap();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedOpacity(
        opacity: _locked ? 0.5 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerTheme.color!),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 14, color: Color(0xFFE6EDF3)),
          ),
        ),
      ),
    );
  }
}

/// AI 失败提示条。
///
/// 以前 AI 调用失败只会静默切本地兜底剧情，界面毫无提示，
/// 玩家会以为"这段剧情就是长这样"。这里显式告知 + 提供重试入口。
class _AiErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  const _AiErrorBanner({
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF5C2222),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF7B72).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Color(0xFFFF7B72)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFFDCD7)),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重试',
                  style: TextStyle(fontSize: 12, color: Color(0xFFFFC107))),
            ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Color(0xFFFFDCD7)),
            ),
          ),
        ],
      ),
    );
  }
}
