import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../other/other_screens.dart';
import '../shop/shop_inventory_screens.dart';
import '../memory_screen.dart';
import '../job_screen.dart';
import '../../utils/ui_helpers.dart';

void _editSignature(BuildContext context) {
  final gp = context.read<GameProvider>();
  final controller = TextEditingController(text: gp.player?.signature ?? '');
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('编辑个性签名'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 30,
        decoration: const InputDecoration(
          hintText: '写一句想对魔法世界说的话...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            gp.updatePlayerSignature(controller.text.trim());
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('签名已更新')),
            );
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

class PhoneTab extends StatelessWidget {
  final GameProvider gp;

  const PhoneTab({super.key, required this.gp});

  @override
  Widget build(BuildContext context) {
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
              _buildCompactProfile(context, player),
              const SizedBox(height: 16),
              _buildPhoneAppGrid(context),
              const SizedBox(height: 16),
              _buildBottomQuickRow(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactProfile(BuildContext context, Player? player) {
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
                  onTap: () => _editSignature(context),
                  child: Text(
                    player?.signature.isNotEmpty == true
                        ? player!.signature
                        : '点击这里编辑你的个性签名',
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

  Widget _buildPhoneAppGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAppItem(context, Icons.phone_in_talk, '魔法通讯', Color(0xFF3B82F6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationScreen()));
            }),
            _buildAppItem(context, Icons.forum, '魔法论坛', Color(0xFFEF4444), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ForumScreen()));
            }),
            _buildAppItem(context, Icons.edit_note, '查看日记', Color(0xFF8B5CF6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
            }),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAppItem(context, Icons.store_mall_directory, '魔法商店', AppColors.warning, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            }),
            // 以前这一格是「应用商店」，点了只弹「还在开发中」。
            // 姻缘红娘（MatchmakerScreen，460 行）早就在代码里，可它的唯一
            // 入口在 phone_home_screen.dart——那个文件从来没被 import 过，
            // 于是整个界面谁也打不开。换掉这个占位，把它接出来。
            _buildAppItem(context, Icons.favorite, '姻缘红娘', Color(0xFFF43F5E), () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MatchmakerScreen()));
            }),
            _buildAppItem(context, Icons.auto_awesome, '平行世界\n小剧场', Color(0xFFEC4899), () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ParallelWorldScreen()));
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildAppItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: label,
          child: SizedBox(
            width: 76,
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
          ),
        ),
      ),
    );
  }

  Widget _buildBottomQuickRow(BuildContext context) {
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
          _buildQuickItem(context, Icons.account_balance_wallet, '你的背包', Color(0xFF3B82F6), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
          }),
          _buildQuickItem(context, Icons.photo_album, '你的回忆', Color(0xFF8B5CF6), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
          }),
          _buildQuickItem(context, Icons.work, '找点活干', Color(0xFF10B981), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const JobScreen()));
          }),
          // 好感排行榜：同样是从没人 import 的 phone_home_screen.dart 里救出来的
          _buildQuickItem(context, Icons.leaderboard, '好感排行', AppColors.warning, () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AffectionAggregateScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildQuickItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: label,
          child: SizedBox(
            width: 68,
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
                Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
