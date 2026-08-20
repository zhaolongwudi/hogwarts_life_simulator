import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'memory_screen.dart';
import 'job_screen.dart';
import 'other_screens.dart';
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
                  _buildAppGrid(),
                  const SizedBox(height: 24),
                  _buildBottomQuickApps(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: _buildAiFloatingButton(),
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
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      '点击这里编辑你的个性签名',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                      ),
                    ),
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
    final yearStr = gp.worldState.academicYear;
    try {
      return int.parse(yearStr.split('-')[0]) - 1991 + 1;
    } catch (_) {
      return 1;
    }
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('背景音乐', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('游戏原声', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🔊', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('0:00', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 3,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const Text('0:00', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMusicBtn(Icons.shuffle),
                const SizedBox(width: 20),
                _buildMusicBtn(Icons.skip_previous),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => setState(() => _isPlaying = !_isPlaying),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildMusicBtn(Icons.skip_next),
                const SizedBox(width: 20),
                _buildMusicBtn(Icons.repeat),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicBtn(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Theme.of(context).textTheme.bodyMedium!.color),
    );
  }

  Widget _buildAppGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAppItem(Icons.phone_in_talk, '魔法通讯', Color(0xFF3B82F6), onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationScreen()));
              }),
              _buildAppItem(Icons.forum, '魔法论坛', Color(0xFFEF4444), onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ForumScreen()));
              }),
              _buildAppItem(Icons.edit_note, '查看日记', Color(0xFF8B5CF6), onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
              }),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAppItem(Icons.store_mall_directory, '魔法商店', Color(0xFFF59E0B), onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
              }),
              _buildAppItem(Icons.apps, '应用商店', Color(0xFF10B981), onTap: () {
                _showComingSoonDialog();
              }),
              _buildAppItem(Icons.auto_awesome, '平行世界\n小剧场', Color(0xFFEC4899), onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ParallelWorldScreen()));
              }),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAppItem(Icons.favorite, '姻缘一线牵\n红娘', Color(0xFFF43F5E), onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchmakerScreen()));
              }),
              Container(width: 80),
              Container(width: 80),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('敬请期待'),
        content: const Text('应用商店正在开发中，更多魔法应用即将上线！'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomQuickApps() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickApp(Icons.account_balance_wallet, '你的背包', Color(0xFF3B82F6), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
            }),
            _buildQuickApp(Icons.photo_album, '你的回忆', Color(0xFF8B5CF6), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
            }),
            _buildQuickApp(Icons.work, '找点活干', Color(0xFF10B981), onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JobScreen()));
            }),
            _buildQuickApp(Icons.settings, '设置', Color(0xFF6B7280), onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickApp(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAiFloatingButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 56,
        height: 56,
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
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('11', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
