// ignore_for_file: unnecessary_to_list_in_spreads, unnecessary_string_interpolations, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../data/course_data.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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

  void _resolveConfession(GameProvider gp, bool accepted, String npcName) {
    gp.resolveConfession(accepted, npcName);
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
          isScrollable: true,
          labelColor: const Color(0xFFD3A625),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: '叙事'),
            Tab(icon: Icon(Icons.people), text: '人物'),
            Tab(icon: Icon(Icons.person), text: '状态'),
            Tab(icon: Icon(Icons.widgets), text: '系统'),
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
            notifications: gameProvider.notifications,
            player: player,
            gameProvider: gameProvider,
            onChoice: _handleChoice,
            onMoreSuggestions: () => gameProvider.generateMoreSuggestions(),
            onResolveConfession: _resolveConfession,
          ),
          _PeopleTab(gameProvider: gameProvider),
          _StatusTab(
            player: player,
            worldState: gameProvider.worldState,
          ),
          _SystemsTab(gameProvider: gameProvider),
          _MapTab(gameProvider: gameProvider),
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
          '${gp.worldState.timestamp} · ${player?.house ?? '未分院'}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _NarrativeTab extends StatefulWidget {
  final String narrative;
  final List<GameChoice> choices;
  final bool isLoading;
  final String? error;
  final List<String> notifications;
  final Player? player;
  final GameProvider gameProvider;
  final void Function(int) onChoice;
  final VoidCallback? onMoreSuggestions;
  final void Function(GameProvider, bool, String) onResolveConfession;

  const _NarrativeTab({
    required this.narrative,
    required this.choices,
    required this.isLoading,
    this.error,
    required this.notifications,
    required this.player,
    required this.gameProvider,
    required this.onChoice,
    this.onMoreSuggestions,
    required this.onResolveConfession,
  });

  @override
  State<_NarrativeTab> createState() => _NarrativeTabState();
}

class _NarrativeTabState extends State<_NarrativeTab>
    with SingleTickerProviderStateMixin {
  static const int _millisPerChar = 28;
  static const int _maxMillis = 30000;

  late final AnimationController _typeController;
  final ScrollController _scrollController = ScrollController();
  List<int> _chars = const [];
  int _visibleCharCount = 0;

  @override
  void initState() {
    super.initState();
    _chars = widget.narrative.runes.toList();
    _typeController = AnimationController(
      vsync: this,
      duration: _durationFor(_chars.length),
    )..addListener(_onTypeTick);
    if (_chars.isNotEmpty) _typeController.forward();
  }

  Duration _durationFor(int length) {
    return Duration(
      milliseconds: (length * _millisPerChar).clamp(200, _maxMillis).toInt(),
    );
  }

  void _onTypeTick() {
    final count = (_typeController.value * _chars.length).round();
    if (count != _visibleCharCount) {
      setState(() => _visibleCharCount = count);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant _NarrativeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.narrative != widget.narrative) {
      _chars = widget.narrative.runes.toList();
      _visibleCharCount = 0;
      _typeController.duration = _durationFor(_chars.length);
      _typeController.value = 0;
      if (_chars.isNotEmpty) _typeController.forward();
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _displayText {
    if (_visibleCharCount >= _chars.length) return widget.narrative;
    return String.fromCharCodes(_chars.take(_visibleCharCount));
  }

  /// 判断当前叙事是否包含待处理表白
  bool get _isAwaitingConfession =>
      widget.player?.loveState.awaitingConfession ?? false;

  String? get _confessingNpc =>
      widget.player?.loveState.consideringNpcName;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⚠️ ${widget.error}',
                  style: const TextStyle(color: Colors.red)),
            ),

          if (widget.notifications.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD3A625)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.notifications
                    .reversed
                    .take(3)
                    .map((n) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(n,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFFD3A625))),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161b22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363d)),
            ),
            child: SelectableText(
              widget.narrative.isEmpty ? '等待开始...' : _displayText,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),

          const SizedBox(height: 20),

          if (widget.isLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFD3A625)),
                  SizedBox(height: 12),
                  Text('🪄 魔法正在运转...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          if (_isAwaitingConfession && _confessingNpc != null)
            _buildConfessionPanel(),

          if (!widget.isLoading &&
              !_isAwaitingConfession &&
              widget.choices.isNotEmpty) ...[
            const Text('可选行动：', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            ...widget.choices.map((c) {
              final idx = widget.choices.indexOf(c);
              final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFF21262d),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onChoice(idx),
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
              onPressed: widget.onMoreSuggestions,
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
          const Center(
            child: Text(
              '输入 /帮助 查看指令系统',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildConfessionPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1f0e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD3A625)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💘 有人在向你表白',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD3A625)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onResolveConfession(
                      widget.gameProvider, true, _confessingNpc!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF740001),
                  ),
                  child: const Text('接受这份心意'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onResolveConfession(
                      widget.gameProvider, false, _confessingNpc!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('婉拒'),
                ),
              ),
            ],
          ),
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
                Text('${player.house ?? '未分院'} · ${player.grade ?? 1}年级'),
                Text(_bloodStatusLabel(player.bloodType)),
                if (player.loveState.status != '单身')
                  Text('💕 ${player.loveState.status}（${player.loveState.partnerName}）',
                      style: const TextStyle(color: Color(0xFFD3A625))),
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
          '${npc.house.isEmpty ? '教授' : npc.house} · 好感 ${npc.affection}（${npc.affectionStage}）'),
      trailing: SizedBox(
        width: 60,
        child: LinearProgressIndicator(
          value: (npc.affection + 100) / 200,
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation(_relationColor(npc.affection)),
        ),
      ),
      onTap: () => _showNPCDetail(context, npc),
    );
  }

  void _showNPCDetail(BuildContext context, NPC npc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
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
            _detailRow('好感度', '${npc.affection}（${npc.affectionStage}）'),
            _detailRow('当前位置', npc.currentLocation),
            _detailRow('性格', npc.personality.join(', ')),
            if (npc.appearance.isNotEmpty) _detailRow('外貌', npc.appearance),
            if (npc.sexOrientation != null)
              _detailRow('性取向', npc.sexOrientation!),
            if (npc.personalGoal != null) _detailRow('目标', npc.personalGoal!),
            if (npc.giftPrefs.isNotEmpty)
              _detailRow('喜欢的礼物', npc.giftPrefs.keys.take(3).join('、')),
            _detailRow('学术声望', '${npc.reputation.academic}'),
            _detailRow('战斗声望', '${npc.reputation.combat}'),
            if (npc.isConsideringConfession)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('……他/她似乎正在酝酿着什么。',
                    style: TextStyle(color: Color(0xFFD3A625))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
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

  Color _relationColor(int affection) {
    return affection >= 85
        ? const Color(0xFFD3A625)
        : affection >= 50
            ? Colors.green
            : affection >= 30
                ? Colors.yellow
                : affection >= 0
                    ? Colors.blueGrey
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
          _buildRow('恋爱', player!.loveState.status),
        ]),
        const SizedBox(height: 16),
        _buildSection('生存状态', [
          _buildRow('❤️ 生命', '${player!.health}/100'),
          _buildRow('🔮 魔力', '${player!.magic}/100'),
          _buildRow('🧠 精神力', '${player!.spirit}/100'),
          _buildRow('🍗 饱食度', '${player!.satiety}/100'),
          _buildRow('⚡ 精力', '${player!.energy}/100'),
        ]),
        const SizedBox(height: 16),
        _buildSection('学院四维', [
          _buildAttrRow('勇气', player!.houseDimensions['courage'] ?? 50),
          _buildAttrRow('智慧', player!.houseDimensions['wisdom'] ?? 50),
          _buildAttrRow('忠诚', player!.houseDimensions['loyalty'] ?? 50),
          _buildAttrRow('野心', player!.houseDimensions['ambition'] ?? 50),
        ]),
        const SizedBox(height: 16),
        _buildSection('属性（前10项）',
            player!.attributes.entries.take(10).map((e) => _buildAttrRow(e.key, e.value)).toList()),
        const SizedBox(height: 16),
        _buildSection('声望', [
          _buildRow('学术', '${player!.playerReputation.academic}'),
          _buildRow('社交', '${player!.playerReputation.social}'),
          _buildRow('战斗', '${player!.playerReputation.combat}'),
          _buildRow('道德', '${player!.playerReputation.moral}'),
          _buildRow('领导', '${player!.playerReputation.leadership}'),
          _buildRow('黑魔法', '${player!.playerReputation.dark}'),
          _buildRow('学院声望', '${player!.houseReputation}'),
          _buildRow('魔法界声望', '${player!.wizardingReputation}'),
          _buildRow('阵营声望', '${player!.factionReputation}'),
        ]),
        const SizedBox(height: 16),
        _buildSection('世界状态', [
          _buildRow('时间', worldState.timestamp),
          _buildRow('学年', worldState.academicYear),
          _buildRow('学期', _termLabel(worldState.term)),
          _buildRow('世界线变动率',
              '${(player!.worldLineDeviation * 100).toStringAsFixed(1)}%'),
          if (worldState.specialMarkers.isNotEmpty)
            _buildRow('特殊标记', worldState.specialMarkers.join(' ')),
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
      'logic': '逻辑',
      'intuition': '直觉',
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

class _SystemsTab extends StatelessWidget {
  final GameProvider gameProvider;
  const _SystemsTab({required this.gameProvider});

  @override
  Widget build(BuildContext context) {
    final player = gameProvider.player;
    if (player == null) return const Center(child: Text('请先创建角色'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('课程', () => _coursePanel()),
        const SizedBox(height: 16),
        _buildSection('收藏', () => _collectionPanel(player)),
        const SizedBox(height: 16),
        _buildSection('日记 / CG图鉴', () => _cgPanel(player)),
        const SizedBox(height: 16),
        _buildSection('成就', () => _achievementPanel(player)),
        const SizedBox(height: 16),
        _buildSection('宠物', () => _petPanel(player)),
        const SizedBox(height: 16),
        _buildSection('信件', () => _letterPanel(player)),
      ],
    );
  }

  Widget _buildSection(String title, Widget Function() builder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        builder(),
      ],
    );
  }

  Widget _coursePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in requiredCourses) _courseRow(c),
        const SizedBox(height: 8),
        const Text('选修课（三年级起，至少选2门）',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        for (final c in electiveCourses) _courseRow(c),
      ],
    );
  }

  Widget _courseRow(CourseData c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            c.required ? Icons.menu_book : Icons.book_outlined,
            size: 16,
            color: c.required ? const Color(0xFFD3A625) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13))),
          Text(c.professor, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _collectionPanel(Player player) {
    if (player.collection.isEmpty) {
      return const Text('暂无收藏品。在冒险中收集独特物品，如巧克力蛙画片、日记本等。',
          style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: player.collection
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('· $c', style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
    );
  }

  Widget _cgPanel(Player player) {
    final unlocked = player.cgRecords.values.toList();
    if (unlocked.isEmpty) {
      return const Text('暂无解锁CG。在关键剧情节点将解锁专属CG。',
          style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已解锁 ${unlocked.length}/36', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        for (final c in unlocked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('📸 ${c.cgId} ${c.name}（${c.unlockedDate}）',
                style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  Widget _achievementPanel(Player player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: achievementCatalog.map((a) {
        final has = player.achievements.contains(a.id);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(has ? '✅' : '🔒', style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${a.name}${has ? ' — ${a.description}' : ''}',
                  style: TextStyle(
                      fontSize: 13, color: has ? Colors.white : Colors.grey),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _petPanel(Player player) {
    if (player.petName == null && player.petId == null) {
      return const Text('你还没有宠物。可以去对角巷挑选一只猫头鹰、猫或蟾蜍。',
          style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    return Text('名字：${player.petName ?? '未命名'}｜羁绊：${player.petBond}/100',
        style: const TextStyle(fontSize: 13));
  }

  Widget _letterPanel(Player player) {
    if (player.letters.isEmpty) {
      return const Text('暂无信件。', style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: player.letters
          .map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('✉️ ${l.sender}（${l.date}）',
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
    );
  }
}

class _MapTab extends StatelessWidget {
  final GameProvider gameProvider;
  const _MapTab({required this.gameProvider});

  @override
  Widget build(BuildContext context) {
    final worldState = gameProvider.worldState;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363d)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('霍格沃茨',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('当前地点：${worldState.currentLocation ?? '九又四分之三站台'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFD3A625))),
              const SizedBox(height: 12),
              _placeRow(Icons.castle, '城堡主楼', '大礼堂、公共休息室、教室'),
              _placeRow(Icons.local_library, '图书馆', '含禁书区'),
              _placeRow(Icons.science, '地下教室', '魔药学、斯莱特林休息室'),
              _placeRow(Icons.park, '禁林', '高年级或特定课程开放'),
              _placeRow(Icons.sports_rugby, '魁地奇球场', ''),
              _placeRow(Icons.storefront, '霍格莫德村', '周末开放'),
              _placeRow(Icons.filter_drama, '天文塔', ''),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363d)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NPC位置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...gameProvider.npcRegistry.values
                  .where((n) => n.isAlive)
                  .take(8)
                  .map((n) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('· ${n.name}：${n.currentLocation}',
                            style: const TextStyle(fontSize: 13)),
                      )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeRow(IconData icon, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(fontSize: 13)),
          if (desc.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
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
    final media = MediaQuery.of(context);
    final bottomPad = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;
    return Container(
      color: const Color(0xFF161b22),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPad),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '输入自由行动或指令（/帮助）...',
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
