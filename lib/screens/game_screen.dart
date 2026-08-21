import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import 'settings_screen.dart';
import 'world_map_screen.dart';
import 'shop_inventory_screens.dart';
import 'memory_screen.dart';
import 'job_screen.dart';
import 'other_screens.dart';
import '../utils/story_text_renderer.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _currentTab = 0;
  int _subTab = 0;
  bool _expandedStats = false;
  int _tokenUsage = 0;
  final _inputController = TextEditingController();
  final _menuController = TextEditingController();
  final _scrollController = ScrollController();
  String? _lastNarrative;

  @override
  void dispose() {
    _inputController.dispose();
    _menuController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleFreeAction() {
    final gp = context.read<GameProvider>();
    if (gp.isLoading) return;
    final action = _inputController.text.trim();
    if (action.isEmpty) return;
    gp.processChoice(
          GameChoice(text: action, action: action),
        );
    _inputController.clear();
  }

  void _handleChoice(int index) {
    final gp = context.read<GameProvider>();
    if (index < gp.choices.length) {
      gp.processChoice(gp.choices[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    // Auto-scroll to top when narrative changes
    if (gp.currentNarrative != _lastNarrative) {
      _lastNarrative = gp.currentNarrative;
      _scrollToTop();
    }

    if (gp.isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载存档...', style: TextStyle(color: Color(0xFF8B949E))),
            ],
          ),
        ),
      );
    }

    if (gp.player == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Color(0xFF8B949E)),
              const SizedBox(height: 16),
              Text(gp.error ?? '没有找到存档', style: const TextStyle(color: Color(0xFF8B949E))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildTabContent()),
            _currentTab == 0 ? _buildBottomInput() : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    final gp = context.watch<GameProvider>();
    final player = gp.player;
    if (player == null) return const SizedBox.shrink();

    final houseLabel = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    }[player.house ?? ''] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(player.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                    if (houseLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          houseLabel,
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.bolt, size: 12, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 2),
                    Text('${player.energy}/5',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
                    const SizedBox(width: 8),
                    Icon(Icons.schedule, size: 12, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(gp.worldState.timestamp,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await gp.quickSave();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 已存档'), duration: Duration(seconds: 1)),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.save, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildNarrativeTab();
      case 1:
        return _buildPhoneTab();
      case 2:
        return _buildWorldTab();
      case 3:
        return _buildSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNarrativeTab() {
    final gp = context.watch<GameProvider>();
    final player = gp.player;

    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildPanelEventTabs(),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_subTab == 0) ...[
                  _buildNarrativeText(gp),
                  const SizedBox(height: 12),
                  _buildChoiceList(gp),
                ] else ...[
                  _buildPanelContent(player),
                ],
              ],
            ),
          ),
        ),
        if (gp.isLoading)
          Padding(
            padding: const EdgeInsets.all(8),
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
                  if (gp.totalTokens > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A5568),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${gp.totalTokens} tokens',
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
              onTap: () => setState(() => _subTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _subTab == 0 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('事件',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subTab == 0 ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _subTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _subTab == 1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('面板',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subTab == 1 ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
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
    final events = [
      {'title': '特快列车上的初遇', 'time': '第1年·9月'},
      {'title': '猫头鹰的意外', 'time': '第1年·9月'},
      {'title': '红头发的热情', 'time': '第1年·9月'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('当前事件列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh, size: 16),
                SizedBox(width: 4),
                Text('重刷', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('可通过探索地图触发新的事件', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
        const SizedBox(height: 8),
        ...events.map((e) => _buildEventCard(e['title']!, e['time']!)),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.history, color: Theme.of(context).textTheme.bodyMedium!.color),
            const SizedBox(width: 4),
            Text('往期与已完结', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerTheme.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('0', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventCard(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                    const SizedBox(width: 2),
                    Text('时间: $time', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.bookmark_border, size: 20, color: Theme.of(context).textTheme.bodyMedium!.color),
          const SizedBox(width: 12),
          Icon(Icons.edit, size: 20, color: Theme.of(context).textTheme.bodyMedium!.color),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 24, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildNarrativeText(GameProvider gp) {
    final narrative = gp.currentNarrative;
    if (narrative.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerTheme.color!),
        ),
        child: const Text(
          '等待开始...\n\n输入自由行动或选择一个选项开始你的霍格沃茨之旅。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              _buildLegendItem(const Color(0xFF58A6FF), '对话'),
              _buildLegendItem(const Color(0xFF56D364), '地点'),
              _buildLegendItem(const Color(0xFFBC8CFF), '物品'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerTheme.color!),
          ),
          child: RichText(
            text: TextSpan(
              children: StoryTextRenderer.parse(narrative),
            ),
          ),
        ),
      ],
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
    if (gp.choices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('可选行动', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...gp.choices.asMap().entries.map((entry) {
          final index = entry.key;
          final choice = entry.value;
          return GestureDetector(
            onTap: () => _handleChoice(index),
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


  Widget _buildBottomInput() {
    final gp = context.watch<GameProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: gp.isLoading
                    ? null
                    : () {
                        if (gp.choices.isNotEmpty) {
                          gp.processChoice(gp.choices.first);
                        }
                      },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: gp.isLoading ? const Color(0xFF484f58) : const Color(0xFFE8A0A0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('推进', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('剧情', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).dividerTheme.color!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Color(0xFFE6EDF3)),
                          decoration: const InputDecoration(
                            hintText: '输入行动或 /命令...',
                            hintStyle: TextStyle(color: Color(0xFF8B949E)),
                            prefixIcon: Icon(Icons.auto_awesome, size: 20, color: Color(0xFF8B949E)),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: gp.isLoading ? null : (_) => _handleFreeAction(),
                        ),
                      ),
                      GestureDetector(
                        onTap: gp.isLoading ? null : _handleFreeAction,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, size: 20),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showCommandMenu(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3A625).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD3A625).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.terminal, size: 20, color: Color(0xFFD3A625)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCommandMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('⚡ 指令系统',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD3A625))),
              const SizedBox(height: 4),
              const Text('在输入框输入 / 开头的命令即可触发',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              const SizedBox(height: 16),
              _buildCommandItem('/帮助', '显示所有可用命令', Icons.help),
              _buildCommandItem('/状态', '查看角色完整属性', Icons.person),
              _buildCommandItem('/时间', '查看当前日期时间', Icons.schedule),
              _buildCommandItem('/地图', '快速跳转地图', Icons.map),
              _buildCommandItem('/关系', '查看NPC关系', Icons.people),
              _buildCommandItem('/恋爱', '查看恋爱状态', Icons.favorite),
              _buildCommandItem('/声望', '查看声望值', Icons.emoji_events),
              _buildCommandItem('/cheat', '打开作弊面板', Icons.bug_report),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _inputController.text = '/帮助';
                    _handleFreeAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD3A625),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('查看完整命令列表'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandItem(String command, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD3A625).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFD3A625)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(command,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _inputController.text = command;
              _handleFreeAction();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD3A625).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow, size: 18, color: Color(0xFFD3A625)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneTab() {
    final gp = context.watch<GameProvider>();
    final player = gp.player;
    final time = gp.worldState.time;
    final hourStr = time.hour.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    final weekdayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF161b22).withValues(alpha: 0.8),
                const Color(0xFF0d1117).withValues(alpha: 0.5),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      '${time.month}月${time.day}日 ${weekdayNames[time.weekday]}',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$hourStr:$minStr',
                      style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w200, color: Colors.white, height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildCompactProfile(player),
              const SizedBox(height: 12),
              _buildCompactMusicPlayer(),
              const SizedBox(height: 16),
              _buildPhoneAppGrid(),
              const SizedBox(height: 16),
              _buildBottomQuickRow(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactProfile(Player? player) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
              ),
            ),
            child: Center(
              child: Text(
                player?.name.isNotEmpty == true ? player!.name[0] : '旅',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player?.name ?? '旅人', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    '点击这里编辑你的个性签名',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMusicPlayer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('背景音乐', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('游戏原声', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneAppGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAppItem(Icons.phone_in_talk, '魔法通讯', Color(0xFF3B82F6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationScreen()));
            }),
            _buildAppItem(Icons.forum, '魔法论坛', Color(0xFFEF4444), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ForumScreen()));
            }),
            _buildAppItem(Icons.edit_note, '查看日记', Color(0xFF8B5CF6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
            }),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAppItem(Icons.store_mall_directory, '魔法商店', Color(0xFFF59E0B), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            }),
            _buildAppItem(Icons.apps, '应用商店', Color(0xFF10B981), () {}),
            _buildAppItem(Icons.auto_awesome, '平行世界\n小剧场', Color(0xFFEC4899), () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildAppItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBottomQuickRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickItem(Icons.account_balance_wallet, '你的背包', Color(0xFF3B82F6), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
          }),
          _buildQuickItem(Icons.photo_album, '你的回忆', Color(0xFF8B5CF6), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
          }),
          _buildQuickItem(Icons.work, '找点活干', Color(0xFF10B981), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const JobScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildQuickItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildWorldTab() {
    final gp = context.watch<GameProvider>();
    final npcs = gp.npcRegistry.values.toList();
    final nearby = npcs.where((n) => gp.isNearby(n.id)).toList();
    final others = npcs.where((n) => !gp.isNearby(n.id)).toList();
    final totalCount = npcs.length;
    final unmetCount = npcs.where((n) => n.affection == 0 && !gp.isNearby(n.id)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorldHeader(totalCount, unmetCount),
          const SizedBox(height: 12),
          _buildWorldActionRow(),
          const SizedBox(height: 12),
          _buildNpcSection('未登场人物', others, true),
          const SizedBox(height: 8),
          _buildNpcSection('已登场人物', nearby, false),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWorldHeader(int total, int unmet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.public, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('世界', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '第${_currentYear()}年·9月 · 已登场 ${total - unmet} 人 · 未登场 $unmet 人',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldActionRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✨ 从收藏引入 NPC')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, color: Theme.of(context).colorScheme.secondary, size: 18),
                  const SizedBox(width: 6),
                  Text('从收藏引入', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✨ 新建 NPC')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('新建 NPC', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNpcSection(String title, List<NPC> npcs, bool initiallyCollapsed) {
    final isEmpty = npcs.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        children: [
          StatefulBuilder(
            builder: (context, setInnerState) {
              return GestureDetector(
                onTap: () => setInnerState(() {}),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.keyboard_arrow_right, size: 20, color: Theme.of(context).textTheme.bodyMedium!.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${npcs.length}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '暂无',
                style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
              ),
            )
          else
            ...npcs.map((npc) => _buildNpcDetailCard(npc)),
        ],
      ),
    );
  }

  Widget _buildNpcDetailCard(NPC npc) {
    final gp = context.read<GameProvider>();
    final isNearby = gp.isNearby(npc.id);
    final relationLabel = _getRelationLabel(npc);
    final hasAppearance = npc.appearance.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(npc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3))),
                        if (isNearby) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('同地点', style: TextStyle(fontSize: 11, color: Colors.green)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(relationLabel, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                        const SizedBox(width: 3),
                        Text(
                          npc.currentLocation,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAppearance) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text(
                npc.appearance,
                style: TextStyle(fontSize: 13, height: 1.6, color: Theme.of(context).textTheme.bodyLarge!.color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRelationLabel(NPC npc) {
    if (npc.affection <= -30) return '敌对';
    if (npc.affection <= -10) return '冷淡';
    if (npc.affection <= 10) return '关系未明';
    if (npc.affection <= 30) return '初识';
    if (npc.affection <= 50) return '朋友';
    if (npc.affection <= 70) return '好友';
    if (npc.affection <= 90) return '亲密';
    return '挚友';
  }

  int _currentYear() {
    final gp = context.read<GameProvider>();
    final yearStr = gp.worldState.academicYear;
    try {
      return int.parse(yearStr.split('-')[0]) - 1991 + 1;
    } catch (_) {
      return 1;
    }
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
                      '💰 ${gp.player?.inventory.isNotEmpty == true ? '有' : '无'}资产 · 🎯 第${_turnCount(gp)}回合',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
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

    // Collapsed view: 2-row grid for basic attributes
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

  Widget _buildSettingsTopBar(GameProvider gp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTopBarAction(
            icon: Icons.sync,
            label: '同步剧本',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✨ 正在同步剧本...')),
              );
            },
          ),
          _buildTopBarAction(
            icon: Icons.save,
            label: '存读档',
            onTap: () async {
              await gp.quickSave();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 已存档')),
                );
              }
            },
          ),
          _buildTopBarAction(
            icon: Icons.import_export,
            label: '导入导出',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📦 导入导出功能')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTokenUsageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bolt, size: 18, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              const Text('Token 用量统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本月消耗', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      const SizedBox(height: 4),
                      Text('$_tokenUsage', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Tokens', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('预计费用', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      const SizedBox(height: 4),
                      Text('\$${(_tokenUsage * 0.0001).toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('基于当前模型', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '本应用使用本地 API Key 直接调用 AI 服务，不收取任何平台费用。实际费用取决于您选择的 AI 提供商的计费标准。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('上次本地自动备份 刚刚', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📊 查看详细用量报表')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 18),
                  SizedBox(width: 8),
                  Text('用量明细', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('💾 正在导出本地数据...')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 8),
                  Text('导出存档数据', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final appProvider = context.watch<AppProvider>();
    final gp = context.read<GameProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSettingsTopBar(gp),
          const SizedBox(height: 12),
          _buildTokenUsageSection(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI 引擎', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 12),
                const Text('选择 AI 提供商', style: TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 8),
                _buildProviderPicker(appProvider),
                const SizedBox(height: 12),
                if (appProvider.availableModels.isNotEmpty) ...[
                  const Text('选择模型', style: TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                  const SizedBox(height: 8),
                  _buildModelPicker(appProvider),
                  const SizedBox(height: 12),
                ],
                const Text('API Key', style: TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 8),
                _buildApiKeyInput(appProvider, gp),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('文字展示与阅读速度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: const Text('AI 输出优先', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerTheme.color!),
                        ),
                        child: const Text('阅读优先', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('阅读速度', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSpeedChip('慢 10字/秒', false)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSpeedChip('中 20字/秒', true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSpeedChip('快 30字/秒', false)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerTheme.color!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('危险操作', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('清除 API Key'),
                  subtitle: const Text('删除当前提供商的 API Key'),
                  trailing: const Icon(Icons.delete, color: Colors.red),
                  onTap: () {
                    appProvider.clearApiKey();
                  },
                ),
                ListTile(
                  title: const Text('前往详细设置'),
                  subtitle: const Text('显示模式、身份、时代背景等'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPicker(AppProvider appProvider) {
    final providers = [
      ('DeepSeek', AiProvider.deepseek, 'https://platform.deepseek.com'),
      ('智谱 AI', AiProvider.zhipu, 'https://open.bigmodel.cn'),
      ('Agnes', AiProvider.agnes, 'https://apihub.agnes-ai.cn'),
      ('商汤日日新', AiProvider.sensenova, 'https://platform.sensenova.cn'),
    ];

    return Column(
      children: providers.map((p) {
        final isSelected = appProvider.aiProvider == p.$2;
        return GestureDetector(
          onTap: () => appProvider.setAiProvider(p.$2),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!),
            ),
            child: Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null),
                const SizedBox(width: 8),
                Expanded(child: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w500))),
                Text(p.$3, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModelPicker(AppProvider appProvider) {
    return Wrap(
      spacing: 8,
      children: appProvider.availableModels.map((model) {
        final isSelected = appProvider.aiModel == model;
        return GestureDetector(
          onTap: () => appProvider.setAiModel(model),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!),
            ),
            child: Text(model,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontSize: 13,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApiKeyInput(AppProvider appProvider, GameProvider gp) {
    final controller = TextEditingController(text: appProvider.apiKey ?? '');
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'sk-...',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            await appProvider.saveApiKey(controller.text.trim());
            await gp.updateApiKey(controller.text.trim());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ 已保存 API Key')),
              );
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildSpeedChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerTheme.color!),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : null, fontSize: 13)),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (index) => setState(() => _currentTab = index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '剧情'),
        BottomNavigationBarItem(icon: Icon(Icons.phone_android), label: '手机'),
        BottomNavigationBarItem(icon: Icon(Icons.public), label: '世界'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
      ],
    );
  }
}
