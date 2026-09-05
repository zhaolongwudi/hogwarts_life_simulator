import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/player.dart';
import '../../models/world_state.dart';
import '../world_map_screen.dart';
import '../../utils/story_text_renderer.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/scaled_rich_text.dart';
import '../../widgets/miuix_components.dart';
import '../../widgets/narrative_visuals.dart';

import '../story_history_screen.dart';
import 'choice_panel.dart';
import '../../theme/miuix_tokens.dart';
import '../../widgets/miuix_overlays.dart';

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

  /// 选项区是否收起。
  ///
  /// 正文才是这个页面的主角，选项是附在上面的东西。但默认收起的话，
  /// 每回合结束都得先点一下才能行动，反而更烦——所以默认展开，
  /// 想一屏多看几行正文的人自己收起来。
  ///
  /// 用静态字段而不是实例字段：切到别的 tab 再回来 NarrativeTab 会重建，
  /// 实例字段一丢，玩家就得再收一次。这是个偏好，不是这一帧的状态。
  static bool choicesCollapsed = false;

  /// 文本颜色图例是否收起。
  ///
  /// 图例是给新玩家看的：知道"蓝色=对话、绿色=地点"之后，这行东西
  /// 每回合白占 ~40px 正文高度。前 3 回合强制展开（学习期），
  /// 之后跟随此偏好，默认收起。静态字段，理由同 [choicesCollapsed]。
  static bool legendCollapsed = true;

  /// 场景横幅是否因向下滚动而收起成紧凑条。
  ///
  /// 阅读空间是这个页面最缺的资源：96px 的插图横幅在"看"的那一刻
  /// 有价值，但玩家开始往下读时它就只是占地方的装饰。
  /// 滚动超过 60px 自动收成 36px 紧凑条，滚回顶部 20px 内恢复——
  /// 用滞回阈值而不是单阈值，避免在临界点来回抖动。
  bool bannerCollapsedByScroll = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onNarrativeScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onNarrativeScroll);
    super.dispose();
  }

  void _onNarrativeScroll() {
    if (!widget.scrollController.hasClients) return;
    final offset = widget.scrollController.offset;
    // 滞回：下去 60 才收，回到 20 才放，中间地带保持现状
    final next = bannerCollapsedByScroll ? offset > 20 : offset > 60;
    if (next != bannerCollapsedByScroll && mounted) {
      setState(() => bannerCollapsedByScroll = next);
    }
  }

  Widget _buildPanelContent(Player player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCharacterPanel(player),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorldMapScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColorOf(context)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.map,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '霍格沃茨魔法世界',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '点击打开完整世界地图',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 8),
      child: Row(
        children: [
          Expanded(
            child: MiuiSegmented<int>(
              segments: const {0: '事件', 1: '面板'},
              selected: widget.subTab <= 1 ? widget.subTab : 0,
              height: 34,
              onChanged: (v) => widget.onSubTabChanged(v),
            ),
          ),
          const SizedBox(width: 10),
          // 剧情回放入口
          _PanelIconAction(
            icon: Icons.history,
            tooltip: '剧情回放',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoryHistoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // 阅读模式：一键沉浸（隐藏顶栏/输入栏/底部导航）
          Semantics(
            button: true,
            label: '进入阅读模式',
            child: _PanelIconAction(
              icon: Icons.fullscreen,
              tooltip: '阅读模式',
              onTap: () => context
                  .read<AppProvider>()
                  .setDisplayMode(DisplayMode.immersive),
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
            const Text(
              '📋 事件记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MiuiColors.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dividerColorOf(context)),
              ),
              child: Text(
                '共 ${events.length + narrativeEvents.length} 条',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
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
              border: Border.all(color: dividerColorOf(context)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 36,
                    color: MiuiColors.onSurfaceVariantActions,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '暂无事件记录\n行动起来创建你的故事吧！',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: MiuiColors.onSurfaceVariantSummary),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (narrativeEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '📖 剧情事件',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...narrativeEvents.asMap().entries.map((entry) {
              final idx = entry.key;
              final event = entry.value;
              return _buildEventCard(
                event.text,
                _buildTimeLabel(event, idx == 0, gp.turnCount),
                isRecent: idx == 0,
              );
            }),
            const SizedBox(height: 8),
          ],
          if (events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '🌍 世界动态',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...events.asMap().entries.map((entry) {
              final idx = entry.key;
              final event = entry.value;
              return _buildEventCard(
                event.text,
                _buildTimeLabel(event, idx == 0, gp.turnCount),
                isRecent: idx == 0,
              );
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
        showMiuixDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isWorldEvent ? Icons.public : Icons.auto_awesome,
                  size: 20,
                  color: isRecent
                      ? MiuiColors.primary
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(isWorldEvent ? '世界动态详情' : '剧情事件详情')),
              ],
            ),
            content: Text(title, style: const TextStyle(height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          color: MiuiColors.surfaceContainer.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecent
                ? MiuiColors.primary.withValues(alpha: 0.6)
                : isWorldEvent
                ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                : MiuiColors.outline.withValues(alpha: 0.6),
            width: MiuiSpace.dividerThickness,
          ),
        ),
        child: Row(
          children: [
            // 语义色竖条（金=本回合 / 蓝=世界 / 中性=历史）
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: isRecent
                    ? MiuiColors.primary
                    : isWorldEvent
                    ? const Color(0xFF3B82F6)
                    : MiuiColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:
                    (isRecent
                            ? MiuiColors.primary
                            : isWorldEvent
                            ? const Color(0xFF3B82F6)
                            : MiuiColors.primary)
                        .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWorldEvent ? Icons.public : Icons.auto_awesome,
                size: 16,
                color: isRecent
                    ? MiuiColors.primary
                    : isWorldEvent
                    ? const Color(0xFF3B82F6)
                    : MiuiColors.primary,
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
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: isRecent ? FontWeight.w700 : FontWeight.w500,
                      color: isRecent
                          ? MiuiColors.primaryVariant
                          : MiuiColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ],
        ),
      ),
    );
  }

  /// 判断 AI 时间戳与系统时间的「日期」是否一致（忽略时刻）。
  /// 例如 AI 写「1991年8月1日 07:30」而系统是「1991年7月31日 19:30」→ false。
  bool _sameGameDate(String aiTs, String sysTs) {
    final re = RegExp(r'(\d{4}年\d{1,2}月\d{1,2}日)');
    final a = re.firstMatch(aiTs)?.group(1);
    final b = re.firstMatch(sysTs)?.group(1);
    if (a == null || b == null) return true; // 解析不了就放行，别误伤
    return a == b;
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

  Widget _buildHeaderCard(
    String? timestamp,
    String? location, {
    double height = 96,
    bool compact = false,
  }) {
    if (compact) {
      // 滚动折叠后的紧凑条：信息一行不丢（时间戳+地点），插图让位给正文。
      return Padding(
        key: const ValueKey('header_compact'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: dividerColorOf(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: MiuiColors.onSurfaceVariantSummary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  timestamp ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MiuiColors.onSurfaceVariantSummary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.place, size: 13, color: AppColors.success),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Padding(
      key: const ValueKey('header_full'),
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
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary),
        ),
      ],
    );
  }

  /// 决策 Dock：选项常驻屏底（正文在滚动区滚动，选项永远不用滑）。
  Widget _buildChoiceDock(GameProvider gp) {
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = (screenH * 0.42).clamp(220.0, 460.0);
    return _buildChoiceList(gp, maxHeight: maxH);
  }

  /// 选项区固定在正文下方（不随正文滚动），最多占 [maxHeight] 高度后内部滚动。
  /// 旧实现把选项放在长滚动列表末尾，600~800 字的叙事下玩家必须滑到底才能行动。
  ///
  /// 面板本身在 [ChoicePanel]——高度那两条规则写在那里。
  Widget _buildChoiceList(GameProvider gp, {double maxHeight = 300}) {
    // 注意：快捷指令/查看类命令执行时 commandResult 非空，
    // 但 choices 已经被 processChoice 里恢复为原剧情选项，必须照常显示
    if (gp.choices.isEmpty) {
      return const SizedBox.shrink();
    }

    return ChoicePanel(
      choices: gp.choices,
      maxHeight: maxHeight,
      collapsed: choicesCollapsed,
      busy: gp.isLoading,
      onToggleCollapse: () =>
          setState(() => choicesCollapsed = !choicesCollapsed),
      onShuffle: () {
        gp.generateMoreSuggestions();
        if (gp.error != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(gp.error!)));
        }
      },
      onPick: widget.onNarrativeTapChoice,
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
        border: Border.all(color: dividerColorOf(context)),
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
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        player.name.isNotEmpty ? player.name[0] : '旅',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
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
                        Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 $loc',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💰 ${gp.player?.galleons ?? 0} 加隆 · 🏦 ${gp.player?.bankGalleons ?? 0} 存 · 🎯 第${_turnCount(gp)}回合',
                      style: const TextStyle(
                        fontSize: 11,
                        color: MiuiColors.onSurfaceVariantSummary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _expandedStats = !_expandedStats),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expandedStats ? '收起' : '属性',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _expandedStats
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
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
      {
        'label': '容貌',
        'value': player.attributes['looks'] ?? 80,
        'icon': Icons.face,
        'color': const Color(0xFFD97706),
      },
      {
        'label': '体质',
        'value': player.attributes['constitution'] ?? 50,
        'icon': Icons.favorite,
        'color': AppColors.danger,
      },
      {
        'label': '智力',
        'value': player.attributes['intelligence'] ?? 50,
        'icon': Icons.psychology,
        'color': const Color(0xFF2563EB),
      },
      {
        'label': '魅力',
        'value': player.attributes['charisma'] ?? 50,
        'icon': Icons.favorite_border,
        'color': const Color(0xFFDB2777),
      },
      {
        'label': '体能',
        'value': player.attributes['strength'] ?? 50,
        'icon': Icons.fitness_center,
        'color': AppColors.success,
      },
      {
        'label': '道德',
        'value': player.attributes['morality'] ?? 50,
        'icon': Icons.verified,
        'color': const Color(0xFF7C3AED),
      },
    ];

    if (_expandedStats) {
      final advanced = [
        {
          'label': '魔咒',
          'value': player.attributes['spell_understanding'] ?? 50,
          'icon': Icons.auto_awesome,
          'color': const Color(0xFF3B82F6),
        },
        {
          'label': '变形',
          'value': player.attributes['transfiguration'] ?? 50,
          'icon': Icons.transform,
          'color': const Color(0xFF8B5CF6),
        },
        {
          'label': '魔药',
          'value': player.attributes['potions'] ?? 50,
          'icon': Icons.science,
          'color': MiuiColors.success,
        },
        {
          'label': '草药',
          'value': player.attributes['herbology'] ?? 50,
          'icon': Icons.local_florist,
          'color': AppColors.success,
        },
        {
          'label': '黑防',
          'value': player.attributes['dda'] ?? 50,
          'icon': Icons.shield,
          'color': MiuiColors.error,
        },
        {
          'label': '飞行',
          'value': player.attributes['flying'] ?? 50,
          'icon': Icons.flight,
          'color': const Color(0xFF0EA5E9),
        },
        {
          'label': '勇气',
          'value': player.attributes['courage'] ?? 50,
          'icon': Icons.bolt,
          'color': AppColors.warning,
        },
        {
          'label': '意志',
          'value': player.attributes['willpower'] ?? 50,
          'icon': Icons.self_improvement,
          'color': const Color(0xFF6366F1),
        },
        {
          'label': '创造',
          'value': player.attributes['creativity'] ?? 50,
          'icon': Icons.psychology_alt,
          'color': const Color(0xFFEC4899),
        },
        {
          'label': '社交',
          'value': player.attributes['social'] ?? 50,
          'icon': Icons.people_alt,
          'color': const Color(0xFF14B8A6),
        },
        {
          'label': '观察',
          'value': player.attributes['observation'] ?? 50,
          'icon': Icons.visibility,
          'color': const Color(0xFF06B6D4),
        },
        {
          'label': '逻辑',
          'value': player.attributes['logic'] ?? 50,
          'icon': Icons.analytics,
          'color': const Color(0xFFA855F7),
        },
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
              color: MiuiColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '📚 课程属性',
              style: TextStyle(
                fontSize: 11,
                color: MiuiColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 13, color: color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  attr['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  attr['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
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
        // 加载槽位。旧实现用 if (isLoading) 直接插入/移除 pill，
        // 出现与消失会让正文区高度跳变约 44px，阅读时很晃眼。
        // 但常驻一个 44px 的空槽位，等于每回合白扔两行正文——
        // 而这个页面最缺的就是高度。
        // 改成 AnimatedSize：平时收到 0，加载时平滑长到 44。
        // 有动画就不是"跳变"，正文区也不会一伸一缩地抖。
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: gp.isLoading ? 44 : 0,
            child: AnimatedOpacity(
              opacity: gp.isLoading ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: MiuiColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MiuiColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MiuiColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          gp.loadingStage.isNotEmpty
                              ? gp.loadingStage
                              : '推进中...',
                          style: const TextStyle(
                            fontSize: 13,
                            color: MiuiColors.onSurfaceVariantSummary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (gp.lastRoundTokens > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MiuiColors.disabledOnSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${gp.lastRoundTokens} tokens',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MiuiColors.onSurfaceVariantSummary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // 决策 Dock：subTab==0 时选项常驻屏幕底部（ChoicePanel 自带 SafeArea/上阴影）
        if (widget.subTab == 0) _buildChoiceDock(gp),
      ],
    );
  }

  Widget _buildNarrativeSubTab(GameProvider gp, BoxConstraints constraints) {
    final narrative = gp.currentNarrative;
    final commandPanel = gp.commandResult;
    // 命令面板独立显示 + 剧情正文 + 选项同时存在；不要求 narrative 非空
    // （加载中的一回合可能 narrative 为空，但 choices 可能有历史残留）
    final affectionSections = gp.lastAffectionSections;
    // 沉浸模式（框架2 §10：尽量隐藏精确关系/好感）不渲染好感变化卡片——
    // 数值是"上帝视角"信息，沉浸模式应该让关系变化只通过故事本身呈现
    final immersive =
        context.watch<AppProvider>().displayMode == DisplayMode.immersive;
    final header = _extractHeader(narrative);
    // 时间戳兜底：AI 常写错时间（如"23:45/凌晨"或"8月1日"而系统还是 7月31日傍晚）。
    // 只要 AI 写的日期与系统日历的日期不一致，就改用系统时间展示，
    // 避免 UI 出现"叙事说 8月1日、顶栏说 7月31日"的矛盾。
    var timestamp = header['timestamp'];
    if (timestamp != null &&
        !_sameGameDate(timestamp, gp.worldState.timestamp)) {
      timestamp = null;
    }
    final location = header['location'];
    final bodyNarrative = header['body'] ?? narrative;
    final hasHeader = timestamp != null || location != null;

    // 悬浮横幅实际高度（SceneIllustrationBanner 固定 96，短屏收窄到 72）。
    // 向下滚动时收成 36px 紧凑条——插图在"看一眼"时值钱，读正文时它只是租金。
    final fullBannerH = constraints.maxHeight < 520 ? 72.0 : 96.0;
    final bannerH = bannerCollapsedByScroll ? 36.0 : fullBannerH;
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
              // AnimatedContainer：滚动折叠横幅时留位跟着平滑缩，正文区不跳变。
              if (hasHeader)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: headerReserve,
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: widget.subTab == 0
                      ? widget.scrollController
                      : null,
                  padding: EdgeInsets.fromLTRB(16, hasHeader ? 0 : 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (commandPanel != null && commandPanel.isNotEmpty) ...[
                        _buildCommandResultPanel(gp, commandPanel),
                        const SizedBox(height: 12),
                      ],
                      _buildLegendPanel(gp),
                      const SizedBox(height: 8),
                      if (bodyNarrative.isNotEmpty)
                        _buildBodyCard(
                          bodyNarrative,
                          affections: affectionSections.isNotEmpty && !immersive
                              ? affectionSections
                              : const [],
                        ),
                      // 选项已抽到屏底决策 Dock（_buildChoiceDock），正文区不再承载。
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasHeader)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              // 时间戳只在 banner 卡内显示，避免与顶栏重复
              child: _buildHeaderCard(
                null,
                location,
                height: bannerH,
                compact: bannerCollapsedByScroll,
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: MiuiColors.primary.withValues(alpha: 0.7),
            width: 3.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
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
              const Icon(
                Icons.info_outline,
                color: MiuiColors.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '指令结果',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MiuiColors.primary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => gp.closeCommandPanel(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MiuiColors.disabledOnSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: MiuiColors.onSurfaceVariantSummary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: MiuiColors.onSurfaceVariantSummary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPanel(GameProvider gp) {
    // 前 3 回合是学习期，强制展开；之后跟随玩家偏好（默认收起）。
    // 图例一旦记住就是纯租金：每回合 ~40px，够多放两行正文。
    final effectiveCollapsed = legendCollapsed && gp.turnCount > 3;
    if (effectiveCollapsed) {
      return GestureDetector(
        onTap: () => setState(() => legendCollapsed = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎨', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '文本颜色图例',
                style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: MiuiColors.onSurfaceVariantSummary,
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        // 学习期内（前 3 回合）不记偏好，免得玩家还没看懂就被收起来
        if (gp.turnCount > 3) setState(() => legendCollapsed = true);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dividerColorOf(context)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _buildLegendItem(const Color(0xFFDDB54A), '人名'),
            _buildLegendItem(const Color(0xFFFFC87A), '说话人'),
            _buildLegendItem(MiuiColors.info, '对话'),
            _buildLegendItem(AppColors.success, '地点'),
            _buildLegendItem(const Color(0xFFD2A8FF), '物品'),
            _buildLegendItem(const Color(0xFFB8A6E3), '内心独白'),
          ],
        ),
      ),
    );
  }

  /// 正文卡：小说式分段渲染。
  ///
  /// 600~800 字的剧情按空行拆段、逐段分类（叙述/对话/内心独白/时间戳），
  /// 每段有独立的视觉形态：叙述首行缩进、对话段左侧色条衬底、内心独白
  /// 斜体浅紫、时间戳金色胶囊。段落间距 10px 替代双空行，阅读节奏更清晰。
  /// 单段短文本（指令结果/通知）保留原整段渲染，不给短内容搭段落舞台。
  Widget _buildBodyCard(String body, {List<String> affections = const []}) {
    final paragraphs = StoryTextRenderer.classifyParagraphs(body);
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    if (paragraphs.length == 1 &&
        paragraphs.first.kind == ParagraphKind.narration) {
      return _buildPlainBodyCard(body);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MiuiColors.outline.withValues(alpha: 0.55),
          width: MiuiSpace.dividerThickness,
        ),
      ),
      child: Stack(
        children: [
          // 顶部一抹金色微光：让大块暗面不透气时仍有一丝"魔法光"层次
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 88,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MiuiColors.primary.withValues(alpha: 0.075),
                      MiuiColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < paragraphs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildStoryParagraph(paragraphs[i]),
                ],
                if (affections.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: MiuiSpace.dividerThickness,
                      color: MiuiColors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  _buildAffectionLines(affections),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单段落渲染：按类型给出不同的视觉形态。
  Widget _buildStoryParagraph(StoryParagraph p) {
    switch (p.kind) {
      case ParagraphKind.dialogue:
        // 对话段：浅蓝衬底 + 左侧色条（对话蓝的淡化版本），顶格不缩进——
        // 与叙述段的缩进形成对比锚点，一眼认出"这里有人开口了"
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: MiuiColors.info.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: MiuiColors.info.withValues(alpha: 0.6),
                width: 3,
              ),
            ),
          ),
          child: ScaledRichText(
            text: TextSpan(
              children: StoryTextRenderer.parseParagraphStyled(
                p,
                indent: false,
              ),
            ),
          ),
        );
      case ParagraphKind.innerVoice:
        // 内心独白：斜体浅紫，跟随系统缩放
        return ScaledRichText(
          text: TextSpan(children: StoryTextRenderer.parseParagraphStyled(p)),
        );
      case ParagraphKind.timestamp:
        // 时间戳：金色胶囊徽章，与主题金同族
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: MiuiColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: MiuiColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: ScaledRichText(
              text: TextSpan(
                children: StoryTextRenderer.parseParagraphStyled(p),
              ),
            ),
          ),
        );
      case ParagraphKind.narration:
        // 普通叙述：首行缩进两全角空格
        return ScaledRichText(
          text: TextSpan(children: StoryTextRenderer.parseParagraphStyled(p)),
        );
    }
  }

  /// 原有整段渲染（单段短文本回退）
  Widget _buildPlainBodyCard(String body) {
    // 短正文（指令结果/通知）融入背景，无装饰，避免视觉碎片化
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ScaledRichText(
        text: TextSpan(
          children: StoryTextRenderer.parseWithAffectionStyle(body),
        ),
      ),
    );
  }

  /// 主卡内好感变化块：极简小节，正文卡一部分。
  Widget _buildAffectionLines(List<String> sections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 本回合变化',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium!.color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...sections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ScaledRichText(
              text: TextSpan(
                children: StoryTextRenderer.parseAffectionLine(section),
              ),
            ),
          ),
        ),
      ],
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
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
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
            position: Tween<Offset>(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(anim),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MiuiColors.primary.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
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
                  color: MiuiColors.onSurfaceVariantSummary,
                ),
              ),
            ),
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
        border: Border(
          left: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.7),
            width: 3.0,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.danger),
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
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 12, color: MiuiColors.primary),
              ),
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

/// 剧情页顶部的圆形图标动作（回放/阅读模式）。
class _PanelIconAction extends StatelessWidget {
  const _PanelIconAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MiuiColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.8),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Icon(icon, size: 17, color: MiuiColors.onSurfaceSecondary),
        ),
      ),
    );
  }
}
