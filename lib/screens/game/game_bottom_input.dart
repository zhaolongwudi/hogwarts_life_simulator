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
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MiuiColors.outline.withValues(alpha: 0.7),
          width: MiuiSpace.dividerThickness,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQuickActions(gp),
            const SizedBox(height: 6),
            Row(
              children: [
            GestureDetector(
              onTap: gp.isLoading
                  ? null
                  : () {
                      if (gp.choices.isNotEmpty) {
                        gp.processAutoAdvanceChoice();
                      }
                    },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gp.isLoading ? MiuiColors.disabledSecondary : MiuiColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!gp.isLoading)
                      BoxShadow(
                        color: MiuiColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: gp.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
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
                          SizedBox(height: 2),
                          Text(
                            '推进',
                            style: TextStyle(
                              fontSize: 9,
                              color: MiuiColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: MiuiColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: MiuiColors.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inputController,
                        maxLength: 500,
                        style: const TextStyle(color: MiuiColors.onSurface, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: '输入行动或 /命令（// 开头按普通内容发送）',
                          hintStyle: TextStyle(color: MiuiColors.onSurfaceVariantActions, fontSize: 11),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                          counterText: '',
                        ),
                        onSubmitted: gp.isLoading ? null : (_) => onHandleFreeAction(),
                      ),
                    ),
                    GestureDetector(
                      onTap: gp.isLoading ? null : onHandleFreeAction,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: MiuiColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, size: 14, color: MiuiColors.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 指令中心面板（CommandCenterPanel）：数据驱动、按注册表分组展示全部指令
            GestureDetector(
              onTap: () => showCommandCenterFromGame(
                  context, inputController, onHandleFreeAction),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MiuiColors.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: MiuiColors.outline),
                ),
                child: const Icon(Icons.terminal, size: 20, color: MiuiColors.primary),
              ),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }

  /// 玩法快捷栏：委托板/装备打开独立页面，其余直接运行本地命令（零 token）。
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
                        Navigator.push(context, MaterialPageRoute(builder: (_) => a.page!()));
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
                  border: Border.all(color: a.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icon, size: 14, color: a.color),
                    const SizedBox(width: 5),
                    Text(a.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ready ? a.color : MiuiColors.onSurfaceVariantActions,
                        )),
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
