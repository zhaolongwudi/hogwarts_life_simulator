import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_systems.dart';
import 'game_play_screens.dart';
import 'command_center_panel.dart';
import '../../utils/ui_helpers.dart';
import '../../theme/miuix_tokens.dart';

class GameBottomInput extends StatelessWidget {
  final TextEditingController inputController;
  final VoidCallback onHandleFreeAction;

  const GameBottomInput({
    super.key,
    required this.inputController,
    required this.onHandleFreeAction,
  });

  @override
  Widget build(BuildContext context) {
    return _buildBottomInput(context);
  }

  Widget _buildBottomInput(BuildContext context) {
    final gp = context.watch<GameProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20,
            sigmaY: 20,
            tileMode: TileMode.clamp,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MiuiColors.surfaceContainer.withValues(alpha: 0.35),
                  MiuiColors.surfaceContainer.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: MiuiColors.primary.withValues(alpha: 0.15),
                width: MiuiSpace.dividerThickness,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 快捷行动栏（参考图风格：圆角胶囊芯片）
                  _buildQuickActions(gp),
                  const SizedBox(height: 8),
                  // 主输入行
                  Row(
                    children: [
                      // 推进按钮（参考图左侧快捷操作风格）
                      _buildAdvanceButton(gp),
                      const SizedBox(width: 10),
                      // 输入框
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: MiuiColors.surfaceContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: MiuiColors.outline.withValues(alpha: 0.5),
                              width: MiuiSpace.dividerThickness,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: inputController,
                                  maxLength: 500,
                                  style: const TextStyle(
                                    color: MiuiColors.onSurface,
                                    fontSize: 14,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '输入行动或 /命令',
                                    hintStyle: TextStyle(
                                      color: MiuiColors.onSurfaceVariantActions,
                                      fontSize: 12,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  onSubmitted: gp.isLoading ? null : (_) => onHandleFreeAction(),
                                ),
                              ),
                              // 发送按钮（参考图风格：主题色填充圆角）
                              GestureDetector(
                                onTap: gp.isLoading ? null : onHandleFreeAction,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: gp.isLoading
                                        ? MiuiColors.disabledSecondary
                                        : MiuiColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      if (!gp.isLoading)
                                        BoxShadow(
                                          color: MiuiColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.send,
                                    size: 14,
                                    color: MiuiColors.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 指令中心按钮
                      GestureDetector(
                        onTap: () => showCommandCenterFromGame(
                            context, inputController, onHandleFreeAction),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: MiuiColors.surfaceContainer.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MiuiColors.outline.withValues(alpha: 0.5),
                              width: MiuiSpace.dividerThickness,
                            ),
                          ),
                          child: Icon(
                            Icons.terminal,
                            size: 18,
                            color: MiuiColors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 推进按钮（参考图风格：紧凑圆角胶囊）
  Widget _buildAdvanceButton(GameProvider gp) {
    return GestureDetector(
      onTap: gp.isLoading
          ? null
          : () {
              if (gp.choices.isNotEmpty) {
                gp.processAutoAdvanceChoice();
              }
            },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: gp.isLoading
              ? MiuiColors.disabledSecondary
              : MiuiColors.primary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (!gp.isLoading)
              BoxShadow(
                color: MiuiColors.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: gp.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MiuiColors.onSurfaceVariantSummary,
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.skip_next, size: 16, color: MiuiColors.onPrimary),
                  SizedBox(height: 1),
                  Text(
                    '推进',
                    style: TextStyle(
                      fontSize: 8,
                      color: MiuiColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 快捷行动栏目（参考图 Screenshot_00-09-17 风格：圆角胶囊芯片排列）
  Widget _buildQuickActions(GameProvider gp) {
    final ready = !gp.isLoading && gp.player != null;
    final actions = <({String label, IconData icon, Color color, String? command, Widget Function()? page})>[
      (label: '委托板', icon: Icons.assignment_outlined, color: MiuiColors.primary, command: null, page: () => const QuestBoardScreen()),
      (label: '装备', icon: Icons.shield_outlined, color: AppColors.success, command: null, page: () => const EquipmentScreen()),
      (label: '宠物', icon: Icons.pets, color: AppColors.warning, command: '/宠物', page: null),
      (label: '魁地奇', icon: Icons.sports_score, color: const Color(0xFF3B82F6), command: '/魁地奇', page: null),
      (label: '决斗', icon: Icons.gavel, color: MiuiColors.error, command: '/决斗', page: null),
      (label: '禁林', icon: Icons.forest_outlined, color: AppColors.success, command: '/禁林 探险', page: null),
      (label: '图鉴', icon: Icons.menu_book, color: const Color(0xFF8B5CF6), command: '/图鉴', page: null),
      (label: '学院杯', icon: Icons.emoji_events_outlined, color: AppColors.warning, command: '/学院杯', page: null),
    ];

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final a = actions[index];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: !ready
                  ? null
                  : () {
                      if (a.page != null) {
                        pushRoute(context, a.page!());
                      } else if (a.command != null) {
                        gp.processChoice(GameChoice(text: a.command!, action: a.command!));
                      }
                    },
              borderRadius: BorderRadius.circular(15),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: a.color.withValues(alpha: 0.3),
                    width: MiuiSpace.dividerThickness,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icon, size: 14, color: a.color),
                    const SizedBox(width: 5),
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ready ? a.color : MiuiColors.onSurfaceVariantActions,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}