import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/npc.dart';
import '../providers/game_provider.dart';
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
