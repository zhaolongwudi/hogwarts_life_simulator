import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/npc.dart';
import '../providers/game_provider.dart';
import '../utils/ui_helpers.dart';
import 'memory_screen.dart';
import 'other_screens.dart';
import 'settings_screen.dart';
import 'shop_inventory_screens.dart';

class PhoneHomeScreen extends StatefulWidget {
  const PhoneHomeScreen({super.key});

  @override
  State<PhoneHomeScreen> createState() => _PhoneHomeScreenState();
}

class _PhoneHomeScreenState extends State<PhoneHomeScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4A3728).withValues(alpha: 0.6),
                  Color(0xFF8B7355).withValues(alpha: 0.3),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildClockHeader(gp),
                  const SizedBox(height: 8),
                  _buildUserProfile(player?.name ?? '旅人', player),
                  const SizedBox(height: 12),
                  _buildMusicPlayer(),
                  const SizedBox(height: 16),
                  _buildAppGrid(gp),
                  const SizedBox(height: 24),
                  _buildBottomQuickApps(gp),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: _buildAiFloatingButton(gp),
          ),
        ],
      ),
    );
  }

  Widget _buildClockHeader(GameProvider gp) {
    final time = gp.worldState.time;
    final hourStr = time.hour.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    final weekdayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${time.month}月${time.day}日 ${weekdayNames[time.weekday]}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$hourStr:$minStr',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              height: 1.1,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(String name, player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '旅',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '第${_currentYear()}年·${_currentMonth()}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD3A625).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, size: 12, color: Color(0xFFD3A625)),
                            const SizedBox(width: 3),
                            Text(
                              '${player?.energy ?? 5}/5',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFD3A625), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💰', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text(
                              '${player?.gold ?? 0}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 3),
                            Text(
                              '${context.read<GameProvider>().turnCount}回合',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _currentYear() {
    final gp = context.read<GameProvider>();
    final era = gp.worldState.era;
    final year = gp.worldState.time.year;
    final startYear = {
      'dumbledore': 1892,
      'marauders': 1971,
      'first_war': 1978,
      'harry_same': 1991,
      'post_war': 1998,
    }[era] ?? 1991;
    return year - startYear + 1;
  }

  String _currentMonth() {
    final gp = context.read<GameProvider>();
    final months = ['9月', '10月', '11月', '12月', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月'];
    final m = gp.worldState.time.month;
    if (m >= 1 && m <= 12) return months[m - 1];
    return '9月';
  }

  Widget _buildMusicPlayer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD3A625), Color(0xFF740001)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('霍格沃茨城堡',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('海德薇主题曲 · 游戏原声',
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMusicBtn(Icons.shuffle),
                const SizedBox(width: 16),
                _buildMusicBtn(Icons.skip_previous),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _isPlaying = !_isPlaying),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD3A625), Color(0xFFB8860B)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildMusicBtn(Icons.skip_next),
                const SizedBox(width: 16),
                _buildMusicBtn(Icons.favorite_outline),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicBtn(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Theme.of(context).textTheme.bodyMedium!.color),
    );
  }

  Widget _buildAppGrid(GameProvider gp) {
    final apps = [
      // 通讯与社交类（手机核心功能）
      _AppItem(Icons.message, '魔法通讯', Color(0xFF3B82F6), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationScreen()));
      }),
      _AppItem(Icons.forum, '魔法论坛', Color(0xFFEF4444), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForumScreen()));
      }),
      _AppItem(Icons.edit_note, '我的日记', Color(0xFF8B5CF6), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
      }),
      _AppItem(Icons.favorite, '姻缘红娘', Color(0xFFF43F5E), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchmakerScreen()));
      }),
      // 状态与数据类
      _AppItem(Icons.photo_album, '相册回忆', Color(0xFFA855F7), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
      }),
      _AppItem(Icons.inventory_2, '我的背包', Color(0xFFEAB308), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
      }),
      _AppItem(Icons.auto_awesome, '平行世界', Color(0xFFEC4899), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ParallelWorldScreen()));
      }),
      _AppItem(Icons.favorite, '好感度', Color(0xFFEC4899), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AffectionAggregateScreen()));
      }),
      _AppItem(Icons.settings, '设置', Color(0xFF6B7280), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
        children: apps.map((a) => _buildAppItem(a.icon, a.label, a.color, onTap: a.onTap)).toList(),
      ),
    );
  }

  Widget _buildAppItem(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 64),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomQuickApps(GameProvider gp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    '📊 当前状态',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _buildStatTile('🏠 当前位置', gp.worldState.currentLocation ?? '霍格沃茨', null),
            _buildStatTile('🏫 学年学期', gp.worldState.academicYear, null),
            _buildStatTile('👨‍👩‍👧‍👦 NPC 数量', '${gp.npcRegistry.length} 个角色', null),
            _buildStatTile('💬 已完成事件', '${gp.turnCount} 个回合', null),
            _buildStatTile(
                '❤️ 最高好感', gp.npcRegistry.values.isNotEmpty
                    ? _getHighestAffectionLabel(gp.npcRegistry.values)
                    : '暂无',
                Colors.pink),
          ],
        ),
      ),
    );
  }

  String _getHighestAffectionLabel(Iterable<NPC> npcs) {
    if (npcs.isEmpty) return '暂无';
    NPC best = npcs.first;
    for (final n in npcs) {
      if (n.affection > best.affection) best = n;
    }
    return '${best.name} (${best.affection})';
  }

  Widget _buildStatTile(String label, String value, Color? accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: accent ?? const Color(0xFFE6EDF3),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiFloatingButton(GameProvider gp) {
    final npcCount = gp.npcRegistry.length;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationScreen()));
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.chat, color: Colors.white, size: 26),
            if (npcCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${npcCount > 99 ? '99+' : npcCount}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AppItem(this.icon, this.label, this.color, this.onTap);
}

class AffectionAggregateScreen extends StatefulWidget {
  const AffectionAggregateScreen({super.key});

  @override
  State<AffectionAggregateScreen> createState() => _AffectionAggregateScreenState();
}

class _AffectionAggregateScreenState extends State<AffectionAggregateScreen> {
  NPC? _expandedNpc;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final npcs = gp.npcRegistry.values.where((n) => n.isAlive).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));

    return Scaffold(
      appBar: AppBar(
        title: const Text('好感度汇总'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: npcs.isEmpty
          ? const Center(child: Text('暂无NPC数据'))
          : Column(
              children: [
                _buildTopChart(npcs),
                const Divider(height: 1),
                Expanded(child: _buildNpcList(npcs)),
              ],
            ),
    );
  }

  Widget _buildTopChart(List<NPC> npcs) {
    final top5 = npcs.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();
    final maxAff = top5.first.affection.abs() > 0 ? top5.first.affection.abs() : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '🏆 好感度 Top 5',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ),
          ...top5.asMap().entries.map((entry) {
            final index = entry.key;
            final npc = entry.value;
            final houseColor = UiHelpers.getHouseColor(npc.house);
            final affColor = UiHelpers.getAffectionColor(npc.affection);
            final barWidth = (npc.affection.abs() / maxAff).clamp(0.1, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: houseColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        npc.name.isNotEmpty ? npc.name[0] : '?',
                        style: TextStyle(fontSize: 13, color: houseColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                npc.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${npc.affection >= 0 ? '+' : ''}${npc.affection}',
                              style: TextStyle(fontSize: 12, color: affColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barWidth,
                            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(affColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNpcList(List<NPC> npcs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: npcs.length,
      itemBuilder: (context, index) => _buildNpcTile(npcs[index]),
    );
  }

  Widget _buildNpcTile(NPC npc) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    final houseLabel = UiHelpers.getHouseLabel(npc.house);
    final affColor = UiHelpers.getAffectionColor(npc.affection);
    final affLabel = UiHelpers.getAffectionLabel(npc.affection);
    final isExpanded = _expandedNpc?.id == npc.id;
    final lastReason = _getLastAffectionReason(npc);

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _expandedNpc = isExpanded ? null : npc;
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpanded
                    ? houseColor.withValues(alpha: 0.5)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: houseColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: houseColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      npc.name.isNotEmpty ? npc.name[0] : '?',
                      style: TextStyle(fontSize: 18, color: houseColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              npc.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: houseColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              houseLabel,
                              style: TextStyle(fontSize: 10, color: houseColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (npc.affection.abs() / 100).clamp(0.0, 1.0),
                                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(affColor),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${npc.affection >= 0 ? '+' : ''}${npc.affection}',
                            style: TextStyle(fontSize: 13, color: affColor, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 12, color: affColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$affLabel · $lastReason',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).hintColor,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _buildAffectionDetail(npc),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAffectionDetail(NPC npc) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    final entries = <Widget>[];

    if (npc.grudges.isNotEmpty) {
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.warning_amber, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '记仇记录 (${npc.grudges.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ],
          ),
        ),
      );
      for (final g in npc.grudges) {
        entries.add(
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        g['type']?.toString() ?? '未知类型',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.orange),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '第${g['day'] ?? '?'}天',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  g['reason']?.toString() ?? '无原因描述',
                  style: const TextStyle(fontSize: 12),
                ),
                if (g['affection_at_time'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '当时好感: ${g['affection_at_time']}',
                    style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    if (npc.recentEvents.isNotEmpty) {
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.event_note, size: 14, color: houseColor),
              const SizedBox(width: 4),
              Text(
                '近期事件 (${npc.recentEvents.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: houseColor),
              ),
            ],
          ),
        ),
      );
      for (final event in npc.recentEvents.reversed.take(5)) {
        entries.add(
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: houseColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              event,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    }

    if (entries.isEmpty) {
      entries.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '暂无好感变动记录',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('当前', '${npc.affection}', UiHelpers.getAffectionColor(npc.affection)),
                _buildStatItem('最高', '${npc.maxAffectionReached}', const Color(0xFFEC4899)),
                _buildStatItem('本周+', '${npc.affectionGainedThisWeek}', Colors.blue),
                _buildStatItem('有锁', '${npc.hasGrudge ? '是' : '否'}',
                    npc.hasGrudge ? Colors.orange : Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...entries,
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  String _getLastAffectionReason(NPC npc) {
    if (npc.grudges.isNotEmpty) {
      final last = npc.grudges.last;
      return last['reason']?.toString() ?? '记仇';
    }
    if (npc.recentEvents.isNotEmpty) {
      return npc.recentEvents.last;
    }
    return '累计变动';
  }
}
