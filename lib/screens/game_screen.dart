// ignore_for_file: unnecessary_to_list_in_spreads, unnecessary_string_interpolations, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/world_state.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final _bottomController = TextEditingController();
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _bottomController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _handleChoice(int index) {
    if (index < context.read<GameProvider>().choices.length) {
      context
          .read<GameProvider>()
          .processChoice(context.read<GameProvider>().choices[index]);
    }
  }

  void _handleFreeAction() {
    final action = _bottomController.text.trim();
    if (action.isEmpty) return;
    context.read<GameProvider>().processChoice(
          GameChoice(text: action, action: action),
        );
    _bottomController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final player = gameProvider.player;

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(player, gameProvider),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '快速存档',
            onPressed: () async {
              await gameProvider.quickSave();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 已快速存档')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD3A625),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: '叙事'),
            Tab(icon: Icon(Icons.people), text: '人物'),
            Tab(icon: Icon(Icons.bar_chart), text: '状态'),
            Tab(icon: Icon(Icons.map), text: '地图'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NarrativeTab(
            narrative: gameProvider.currentNarrative,
            choices: gameProvider.choices,
            isLoading: gameProvider.isLoading,
            error: gameProvider.error,
            onChoice: _handleChoice,
            onMoreSuggestions: () => gameProvider.generateMoreSuggestions(),
          ),
          _PeopleTab(gameProvider: gameProvider),
          _StatusTab(
            player: player,
            worldState: gameProvider.worldState,
          ),
          const _MapTab(),
        ],
      ),
      bottomNavigationBar: _BottomInputBar(
        controller: _bottomController,
        onSend: _handleFreeAction,
        isLoading: gameProvider.isLoading,
      ),
    );
  }

  Widget _buildAppBarTitle(Player? player, GameProvider gp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player?.name ?? '魔法人生',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          '${gp.worldState.academicYear} · ${gp.worldState.month} ${gp.worldState.dayOfMonth}日 · ${player?.house ?? '未分院'}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _NarrativeTab extends StatelessWidget {
  final String narrative;
  final List<GameChoice> choices;
  final bool isLoading;
  final String? error;
  final void Function(int) onChoice;
  final VoidCallback? onMoreSuggestions;

  const _NarrativeTab({
    required this.narrative,
    required this.choices,
    required this.isLoading,
    this.error,
    required this.onChoice,
    this.onMoreSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⚠️ $error', style: const TextStyle(color: Colors.red)),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161b22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363d)),
            ),
            child: SelectableText(
              narrative.isEmpty ? '等待开始...' : narrative,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),

          const SizedBox(height: 20),

          if (isLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFD3A625)),
                  SizedBox(height: 12),
                  Text('🪄 魔法正在运转...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          if (!isLoading && choices.isNotEmpty) ...[
            const Text('可选行动：', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            ...choices.map((c) {
              final idx = choices.indexOf(c);
              final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFF21262d),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onChoice(idx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF740001),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              idx < letters.length ? letters[idx] : '${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(c.text, style: const TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onMoreSuggestions,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD3A625),
                side: const BorderSide(color: Color(0xFFD3A625)),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('更多建议'),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                '让魔法再想出 4 个新的行动建议',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PeopleTab extends StatelessWidget {
  final GameProvider gameProvider;
  const _PeopleTab({required this.gameProvider});

  @override
  Widget build(BuildContext context) {
    final player = gameProvider.player;
    if (player == null) return const Center(child: Text('请先创建角色'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPlayerCard(player),
        const SizedBox(height: 16),
        const Text('同年级同学', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...gameProvider.npcRegistry.values
            .where((n) =>
                n.grade == player.grade &&
                n.isAlive &&
                gameProvider.getViewableCharacter(n.id) != null)
            .take(10)
            .map((n) => _buildNPCRow(context, n, player))
            .toList(),
        const SizedBox(height: 16),
        const Text('教授', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...gameProvider.npcRegistry.values
            .where((n) => n.grade == 0 && n.isAlive)
            .map((n) => _buildNPCRow(context, n, player))
            .toList(),
      ],
    );
  }

  Widget _buildPlayerCard(Player player) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD3A625)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: _getHouseColor(player.house ?? ''),
            child: Text(
              player.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${player.house ?? '未分院'} · 一年级'),
                Text(_bloodStatusLabel(player.bloodType)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNPCRow(BuildContext context, NPC npc, Player player) {
    final rel = player.relationships[npc.id];
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _getHouseColor(npc.house),
        child: Text(npc.name.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      title: Text(npc.name),
      subtitle: Text(
          '${npc.house.isEmpty ? '教授' : npc.house} · ${rel != null ? rel.relationType : '陌生人'}'),
      trailing: rel != null
          ? LinearProgressIndicator(
              value: rel.level / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(_relationColor(rel.level)),
            )
          : null,
      onTap: () => _showNPCDetail(context, npc, rel),
    );
  }

  void _showNPCDetail(BuildContext context, NPC npc, Relationship? rel) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getHouseColor(npc.house),
                  child: Text(npc.name.substring(0, 1),
                      style: const TextStyle(
                          fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(npc.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(npc.house.isEmpty ? '教授' : npc.house),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (rel != null) ...[
              Text('关系: ${rel.relationType}', style: const TextStyle(fontSize: 14)),
              LinearProgressIndicator(
                value: rel.level / 100,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation(_relationColor(rel.level)),
              ),
              Text('${rel.level}/100',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
            ],
            Text('当前位置: ${npc.currentLocation}', style: const TextStyle(fontSize: 14)),
            Text('性格: ${npc.personality.join(', ')}', style: const TextStyle(fontSize: 14)),
            if (npc.personalGoal != null)
              Text('目标: ${npc.personalGoal}', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Color _getHouseColor(String house) {
    return switch (house.toLowerCase()) {
      'gryffindor' => const Color(0xFF740001),
      'slytherin' => const Color(0xFF1a472a),
      'ravenclaw' => const Color(0xFF0e1a40),
      'hufflepuff' => const Color(0xFFecbe22),
      _ => Colors.grey,
    };
  }

  Color _relationColor(int level) {
    return level >= 80
        ? const Color(0xFFD3A625)
        : level >= 50
            ? Colors.green
            : level >= 30
                ? Colors.yellow
                : Colors.red;
  }

  String _bloodStatusLabel(String status) {
    return {
      'muggleborn': '麻瓜出身',
      'halfblood': '混血',
      'pureblood': '纯血',
      'special': '特殊家庭',
    }[status] ?? status;
  }
}

class _StatusTab extends StatelessWidget {
  final Player? player;
  final WorldState worldState;
  const _StatusTab({this.player, required this.worldState});

  @override
  Widget build(BuildContext context) {
    if (player == null) return const Center(child: Text('请先创建角色'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('基本信息', [
          _buildRow('姓名', player!.name),
          _buildRow('血统', _bloodStatusLabel(player!.bloodType)),
          _buildRow('出生地', player!.birthLocation),
          _buildRow('学院', player!.house ?? '未分院'),
          _buildRow('年级', '${player!.grade ?? 1}'),
          _buildRow('魔杖', player!.wandId ?? '未选择'),
        ]),
        const SizedBox(height: 16),
        _buildSection('属性（前8项）',
            player!.attributes.entries.take(8).map((e) => _buildAttrRow(e.key, e.value)).toList()),
        const SizedBox(height: 16),
        _buildSection('世界状态', [
          _buildRow('学年', worldState.academicYear),
          _buildRow('学期', _termLabel(worldState.term)),
          _buildRow('日期', '${worldState.month} ${worldState.dayOfMonth}日'),
          _buildRow('世界线偏移', '${worldState.playerImpactScore.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 16),
        _buildSection('学院杯积分',
            worldState.housePoints.entries.map((e) => _buildRow(e.key, '${e.value}分')).toList()),
        if (worldState.recentEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection('最近事件',
              worldState.recentEvents.map((e) => _buildRow('', e)).toList()),
        ],
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAttrRow(String key, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(_attrLabel(key), style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(
                value >= 70 ? const Color(0xFFD3A625) : Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  String _attrLabel(String key) {
    return {
      'spell_understanding': '魔咒理解',
      'transfiguration': '变形术',
      'potions': '魔药',
      'herbology': '草药学',
      'dda': '黑魔法防御',
      'flying': '飞行',
      'theory': '理论知识',
      'memory': '记忆力',
      'observation': '观察力',
      'magic_control': '魔法控制',
      'reaction_time': '反应速度',
      'emotional_stability': '情绪稳定',
      'creativity': '创造力',
      'social': '社交',
      'courage': '勇气',
      'caution': '谨慎',
      'willpower': '意志',
    }[key] ?? key;
  }

  String _bloodStatusLabel(String status) {
    return {
      'muggleborn': '麻瓜出身',
      'halfblood': '混血',
      'pureblood': '纯血',
      'special': '特殊家庭',
    }[status] ?? status;
  }

  String _termLabel(String term) {
    return {
      'first': '第一学期',
      'second': '第二学期',
      'third': '第三学期',
      'summer': '暑假',
    }[term] ?? term;
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('霍格沃茨地图',
              style: TextStyle(fontSize: 18, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('随着游戏进展，你将探索更多地点',
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _BottomInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _BottomInputBar({
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '输入自由行动...',
                  prefixIcon: Icon(Icons.sailing),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Color(0xFFD3A625)),
              onPressed: isLoading ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
