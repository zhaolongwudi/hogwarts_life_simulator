import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import 'settings_screen.dart';
import 'phone_home_screen.dart';
import 'world_map_screen.dart';
import 'shop_inventory_screens.dart';
import 'memory_screen.dart';
import 'job_screen.dart';
import 'other_screens.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _currentTab = 0;
  int _subTab = 0;
  bool _expandedStats = false;
  bool _showStoryPanel = false;
  int _tokenUsage = 0;
  final _inputController = TextEditingController();
  final _menuController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _handleFreeAction() {
    final action = _inputController.text.trim();
    if (action.isEmpty) return;
    context.read<GameProvider>().processChoice(
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
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                ),
                child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (houseLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$houseLabel · ${player.bloodType == 'pureblood' ? '纯血' : player.bloodType == 'halfblood' ? '混血' : '麻瓜'}',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 14, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text('精力 ${player.energy}/5', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text(gp.worldState.timestamp, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 14, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2),
                        Text(gp.worldState.currentLocation ?? '未知', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_drop_up),
                tooltip: '展开属性',
                onPressed: () {
                  setState(() {
                    _expandedStats = !_expandedStats;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: '存档',
                onPressed: () async {
                  await gp.quickSave();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ 已存档')),
                    );
                  }
                },
              ),
            ],
          ),
          if (_expandedStats) _buildStatsRow(player),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Player player) {
    final attrs = player.attributes;
    final primaryAttrs = attrs.entries.take(2).toList();
    final secondaryAttrs = attrs.entries.skip(2).take(4).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: primaryAttrs.map((e) => Expanded(child: _buildAttrCard(e.key, e.value))).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: secondaryAttrs.map((e) => Expanded(child: _buildAttrChip(e.key, e.value))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrCard(String label, int value) {
    final names = {
      'spell_understanding': '魔咒理解', 'transfiguration': '变形术', 'potions': '魔药',
      'herbology': '草药学', 'dda': '黑魔法防御', 'flying': '飞行',
      'theory': '理论', 'memory': '记忆', 'observation': '观察',
      'magic_control': '魔法控制', 'reaction_time': '反应', 'emotional_stability': '情绪',
      'creativity': '创造', 'social': '社交', 'courage': '勇气',
      'caution': '谨慎', 'willpower': '意志', 'logic': '逻辑', 'intuition': '直觉',
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 4),
          Expanded(child: Text(names[label] ?? label, style: const TextStyle(fontSize: 12))),
          Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAttrChip(String label, int value) {
    final names = {
      'spell_understanding': '魔咒', 'transfiguration': '变形', 'potions': '魔药',
      'herbology': '草药', 'dda': '黑防', 'flying': '飞行',
      'theory': '理论', 'memory': '记忆', 'observation': '观察',
      'magic_control': '控魔', 'reaction_time': '反应', 'emotional_stability': '情绪',
      'creativity': '创造', 'social': '社交', 'courage': '勇气',
      'caution': '谨慎', 'willpower': '意志', 'logic': '逻辑', 'intuition': '直觉',
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 2),
          Text(names[label] ?? label, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 2),
          Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_subTab == 0) ...[
                  _buildPanelContent(player),
                ] else ...[
                  _buildNarrativeText(gp),
                  const SizedBox(height: 12),
                  _buildChoiceList(gp),
                ],
              ],
            ),
          ),
        ),
        if (gp.isLoading)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('推进中...'),
                ],
              ),
            ),
          ),
        _buildProgressButton(gp),
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                child: Text('面板',
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
                child: Text('事件',
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
            const Text('当前事件列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
          style: TextStyle(color: Color(0xFF8B7355)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Text(
        narrative,
        style: const TextStyle(fontSize: 15, height: 1.8),
      ),
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
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProgressButton(GameProvider gp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: gp.isLoading ? null : () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8A0A0),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('推进', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              Text('剧情', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showStoryPanel = !_showStoryPanel;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu, size: 22),
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
                      decoration: const InputDecoration(
                        hintText: '输入自定义行动...',
                        prefixIcon: Icon(Icons.auto_awesome, size: 20),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _handleFreeAction(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleFreeAction,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
                Color(0xFF4A3728).withOpacity(0.5),
                Color(0xFF8B7355).withOpacity(0.2),
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
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
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
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneHomeScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_android, color: Colors.white),
                      SizedBox(width: 8),
                      Text('打开手机', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.3)),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
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
              color: color.withOpacity(0.15),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.2)),
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
          _buildQuickItem(Icons.settings, '设置', Color(0xFF6B7280), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
              color: color.withOpacity(0.15),
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withOpacity(0.5)),
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
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
                        Text(npc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (isNearby) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
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
    final attributes = [
      {'label': '容貌', 'value': 80, 'icon': Icons.face, 'color': Color(0xFFD97706)},
      {'label': '体质', 'value': player.attributes['constitution'] ?? 50, 'icon': Icons.favorite, 'color': Color(0xFFDC2626)},
      {'label': '智力', 'value': player.attributes['intelligence'] ?? 50, 'icon': Icons.psychology, 'color': Color(0xFF2563EB)},
      {'label': '魅力', 'value': player.attributes['charisma'] ?? 50, 'icon': Icons.favorite_border, 'color': Color(0xFFDB2777)},
      {'label': '体能', 'value': player.attributes['strength'] ?? 50, 'icon': Icons.fitness_center, 'color': Color(0xFF059669)},
      {'label': '道德值', 'value': 50, 'icon': Icons.verified, 'color': Color(0xFF7C3AED)},
    ];

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
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 12, color: Colors.white),
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 3),
                              Text(
                                '${player.house ?? ''} · ${player.bloodType == 'pureblood' ? '纯血' : player.bloodType == 'halfblood' ? '混血' : '麻瓜'}',
                                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 13, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 3),
                        Text('体力 ${player.energy}/5', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 10),
                        Icon(Icons.schedule, size: 13, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 3),
                        Text(gp.worldState.timestamp, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 10),
                        Icon(Icons.location_on, size: 13, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            gp.worldState.currentLocation ?? '未知',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedStats = !_expandedStats;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerTheme.color!.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _expandedStats ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildAttrBarCompact(attributes[0])),
              const SizedBox(width: 10),
              Expanded(child: _buildAttrBarCompact(attributes[1])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 2; i < attributes.length; i++) ...[
                if (i > 2) const SizedBox(width: 8),
                Expanded(child: _buildAttrChipFull(attributes[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttrChipFull(Map<String, dynamic> attr) {
    final value = attr['value'] as int;
    final color = attr['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 13, color: color),
              const SizedBox(width: 3),
              Text(attr['label'] as String, style: const TextStyle(fontSize: 11)),
              const Spacer(),
              Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrBarCompact(Map<String, dynamic> attr) {
    final value = attr['value'] as int;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attr['icon'] as IconData, size: 14, color: attr['color'] as Color),
              const SizedBox(width: 4),
              Text(attr['label'] as String, style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: (attr['color'] as Color).withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(attr['color'] as Color),
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
                const Text('AI 引擎', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('选择 AI 提供商', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                _buildProviderPicker(appProvider),
                const SizedBox(height: 12),
                if (appProvider.availableModels.isNotEmpty) ...[
                  const Text('选择模型', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildModelPicker(appProvider),
                  const SizedBox(height: 12),
                ],
                const Text('API Key', style: TextStyle(fontSize: 13)),
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
                const Text('文字展示与阅读速度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
              color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).scaffoldBackgroundColor,
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
