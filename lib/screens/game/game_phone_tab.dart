import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../other/other_screens.dart';
import '../shop/shop_inventory_screens.dart';
import '../memory_screen.dart';
import '../job_screen.dart';
import '../../utils/ui_helpers.dart';
import '../../theme/miuix_tokens.dart';
import '../../models/game_systems.dart';
import '../../widgets/miuix_overlays.dart';

void _editSignature(BuildContext context) {
  final gp = context.read<GameProvider>();
  final controller = TextEditingController(text: gp.player?.signature ?? '');
  showMiuixDialog<void>(
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
        // 毛玻璃背景层
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MiuiColors.surface.withValues(alpha: 0.85),
                  MiuiColors.background.withValues(alpha: 0.7),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Column(
            children: [
              // ===== ① 日期时间玻璃组件 =====
              _buildDateTimeWidget(context, time, hourStr, minStr, weekdayNames),
              const SizedBox(height: 14),

              // ===== ② 个人资料卡 =====
              _buildCompactProfile(context, player),
              const SizedBox(height: 18),

              // ===== ③ 应用网格 =====
              _buildPhoneAppGrid(context),
              const SizedBox(height: 18),

              // ===== ④ 快捷操作坞 =====
              _buildBottomQuickRow(context),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    );
  }

  /// 玻璃拟态日期时间组件（匹配参考图 Screenshot_00-09-25 风格）
  Widget _buildDateTimeWidget(
    BuildContext context,
    GameTime time,
    String hourStr,
    String minStr,
    List<String> weekdayNames,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.clamp),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MiuiColors.primary.withValues(alpha: 0.12),
                MiuiColors.surfaceContainer.withValues(alpha: 0.45),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MiuiColors.primary.withValues(alpha: 0.15),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${time.month}月${time.day}日 ${weekdayNames[time.weekday]}',
                style: TextStyle(
                  fontSize: 13,
                  color: MiuiColors.onSurfaceVariantSummary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$hourStr:$minStr',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w200,
                  color: MiuiColors.onSurface,
                  height: 1.1,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: MiuiColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Day ${gp.turnCount} · ${gp.worldState.academicYear}',
                  style: TextStyle(
                    fontSize: 11,
                    color: MiuiColors.primaryVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactProfile(BuildContext context, Player? player) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.clamp),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MiuiColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.3),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Row(
            children: [
              // 头像徽章
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      MiuiColors.primary.withValues(alpha: 0.8),
                      MiuiColors.primaryVariant.withValues(alpha: 0.4),
                    ],
                  ),
                  border: Border.all(
                    color: MiuiColors.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    player?.name.isNotEmpty == true ? player!.name[0] : '旅',
                    style: const TextStyle(
                      color: MiuiColors.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                        Text(
                          player?.name ?? '旅人',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MiuiColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: MiuiColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Lv.${gp.turnCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: MiuiColors.primaryVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _editSignature(context),
                      child: Text(
                        player?.signature.isNotEmpty == true
                            ? player!.signature
                            : '点击这里编辑你的个性签名',
                        style: TextStyle(
                          fontSize: 12,
                          color: MiuiColors.onSurfaceVariantSummary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // 加隆快速显示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MiuiColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, size: 14, color: MiuiColors.primaryVariant),
                    const SizedBox(width: 3),
                    Text(
                      '${player?.galleons ?? 0}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MiuiColors.primaryVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 应用网格（匹配参考图 Screenshot_00-09-25 风格：白底圆角图标 + 4列布局）
  // ============================================================================
  Widget _buildPhoneAppGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAppItem(context, Icons.phone_in_talk, '魔法通讯', const Color(0xFF3B82F6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationScreen()));
            }),
            _buildAppItem(context, Icons.forum, '魔法论坛', MiuiColors.error, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ForumScreen()));
            }),
            _buildAppItem(context, Icons.edit_note, '查看日记', const Color(0xFF8B5CF6), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
            }),
            _buildAppItem(context, Icons.auto_awesome, '平行世界', const Color(0xFFEC4899), () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ParallelWorldScreen()));
            }),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAppItem(context, Icons.store_mall_directory, '魔法商店', AppColors.warning, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            }),
            _buildAppItem(context, Icons.favorite, '姻缘红娘', const Color(0xFFF43F5E), () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MatchmakerScreen()));
            }),
            _buildAppItem(context, Icons.account_balance_wallet, '你的背包', const Color(0xFF10B981), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
            }),
            _buildAppItem(context, Icons.leaderboard, '好感排行', AppColors.warning, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AffectionAggregateScreen()));
            }),
          ],
        ),
      ],
    );
  }

  /// 白底圆角图标（Screenshot_00-09-25 风格）：60x60 白色圆角方块 + 图标 + 文字
  Widget _buildAppItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: label,
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MiuiColors.outline.withValues(alpha: 0.25),
                      width: MiuiSpace.dividerThickness,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MiuiColors.onSurfaceVariantSummary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 底部快捷操作坞（玻璃拟态 Dock）
  // ============================================================================
  Widget _buildBottomQuickRow(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14, tileMode: TileMode.clamp),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: MiuiColors.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.25),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDockItem(context, Icons.photo_album, '回忆', const Color(0xFF8B5CF6), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()));
              }),
              _buildDockItem(context, Icons.work, '找活干', MiuiColors.success, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const JobScreen()));
              }),
              _buildDockItem(context, Icons.map_outlined, '地图', MiuiColors.primaryVariant, () {
                Navigator.pushNamed(context, '/world_map');
              }),
              _buildDockItem(context, Icons.save_outlined, '存档', const Color(0xFF3B82F6), () {
                Navigator.pushNamed(context, '/save_load');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: MiuiColors.onSurfaceVariantSummary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}