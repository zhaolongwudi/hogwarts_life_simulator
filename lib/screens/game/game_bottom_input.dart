import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_systems.dart';
import 'game_play_screens.dart';

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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(top: BorderSide(color: const Color(0xFF30363D))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: gp.isLoading ? const Color(0xFF374151) : const Color(0xFFD3A625),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (!gp.isLoading)
                      BoxShadow(
                        color: const Color(0xFFD3A625).withValues(alpha: 0.3),
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
                          color: Color(0xFF8B949E),
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.skip_next, size: 18, color: Color(0xFF1C232D)),
                          SizedBox(height: 2),
                          Text(
                            '推进',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF1C232D),
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
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inputController,
                        style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '输入行动或 /命令',
                          hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        onSubmitted: gp.isLoading ? null : (_) => onHandleFreeAction(),
                      ),
                    ),
                    GestureDetector(
                      onTap: gp.isLoading ? null : onHandleFreeAction,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFD3A625),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, size: 16, color: Color(0xFF1C232D)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showCommandMenu(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Icon(Icons.terminal, size: 20, color: Color(0xFFD3A625)),
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
      (label: '委托板', icon: Icons.assignment_outlined, color: const Color(0xFFD3A625), command: null, page: () => const QuestBoardScreen()),
      (label: '装备', icon: Icons.shield_outlined, color: const Color(0xFF7EE787), command: null, page: () => const EquipmentScreen()),
      (label: '宠物', icon: Icons.pets, color: const Color(0xFFF59E0B), command: '/宠物', page: null),
      (label: '魁地奇', icon: Icons.sports_score, color: const Color(0xFF3B82F6), command: '/魁地奇', page: null),
      (label: '决斗', icon: Icons.gavel, color: const Color(0xFFEF4444), command: '/决斗', page: null),
      (label: '禁林', icon: Icons.forest_outlined, color: const Color(0xFF059669), command: '/禁林 探险', page: null),
      (label: '图鉴', icon: Icons.menu_book, color: const Color(0xFF8B5CF6), command: '/图鉴', page: null),
      (label: '学院杯', icon: Icons.emoji_events_outlined, color: const Color(0xFFF59E0B), command: '/学院杯', page: null),
    ];

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final a = actions[index];
          return GestureDetector(
            onTap: !ready
                ? null
                : () {
                    if (a.page != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => a.page!()));
                    } else if (a.command != null) {
                      gp.processChoice(GameChoice(text: a.command!, action: a.command!));
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: a.color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(a.icon, size: 14, color: a.color),
                  const SizedBox(width: 4),
                  Text(a.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ready ? a.color : const Color(0xFF6B7280),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCommandMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('⚡ 指令系统',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD3A625))),
                const SizedBox(height: 4),
                const Text('点击右侧 ▶ 直接运行，或在输入框输入 / 开头的命令',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      _sectionTitle('📖 核心查看', top: 0),
                      _buildCommandItem('/帮助', '显示所有可用命令总览', Icons.help, context),
                      _buildCommandItem('/状态', '查看角色完整属性面板', Icons.person, context),
                      _buildCommandItem('/时间', '查看当前日期时间和时段', Icons.schedule, context),
                      _buildCommandItem('/地图', '查看场景地图/快速跳转', Icons.map, context),
                      _buildCommandItem('/通知', '查看系统通知/待办/未读信件', Icons.notifications, context),
                      _buildCommandItem('/档案', '当前角色完整档案(血统/出身/天赋/魔杖)', Icons.folder_shared, context),
                      _sectionTitle('👥 关系·恋爱·血缘'),
                      _buildCommandItem('/关系', '查看已登场NPC关系总表', Icons.people, context),
                      _buildCommandItem('/恋爱', '当前恋爱关系/阶段/共同经历', Icons.favorite, context),
                      _buildCommandItem('/恋爱等待', '下一次可触发恋爱事件的剩余时间', Icons.hourglass_empty, context),
                      _buildCommandItem('/恋爱阶段', '关系阶段阶梯说明(好感→暧昧→告白→交往)', Icons.auto_graph, context),
                      _buildCommandItem('/关系网络 NPC1 NPC2', '查询两位NPC之间的后台关系', Icons.account_tree, context),
                      _buildCommandItem('/血缘', '你的血缘关系家族树(堂/表/姑/舅)', Icons.family_restroom, context),
                      _buildCommandItem('/骨科', '骨科模式状态与禁忌限制', Icons.local_hospital, context),
                      _sectionTitle('🎓 成长·声望·传闻'),
                      _buildCommandItem('/声望', '多维声望面板(学术/社交/战斗/道德/领导/黑魔法)', Icons.military_tech, context),
                      _buildCommandItem('/舆论', '当前对你的舆论传闻摘要', Icons.record_voice_over, context),
                      _buildCommandItem('/传闻', '同上，别名', Icons.chat_bubble_outline, context),
                      _buildCommandItem('/课程', '本周课表/上课地点/剩余课时', Icons.school, context),
                      _buildCommandItem('/课堂 互动', '触发当前课堂互动(教授提问/实践/同桌)', Icons.edit_note, context),
                      _buildCommandItem('/目标', '查看&切换人生目标(1-6 选目标ID或名称)', Icons.flag, context),
                      _sectionTitle('🎒 收藏·成就·宠物·信件'),
                      _buildCommandItem('/收藏', '背包/收藏物品/魔法道具总览', Icons.inventory_2, context),
                      _buildCommandItem('/成就', '已解锁成就 / 未解锁进度', Icons.workspace_premium, context),
                      _buildCommandItem('/宠物', '当前宠物状态(亲密度/属性/技能)', Icons.pets, context),
                      _buildCommandItem('/日记', 'CG相册列表(也可/日记 重播 cg_id 重看)', Icons.photo_album, context),
                      _buildCommandItem('/信', '查看收到的信件列表/写新信', Icons.mail, context),
                      _sectionTitle('🌍 世界·时代·NPC'),
                      _buildCommandItem('/联动', '跨时代剧情联动痕迹列表', Icons.join_inner, context),
                      _buildCommandItem('/世界演化', '当月世界五大类事件动态', Icons.public, context),
                      _buildCommandItem('/新NPC', '手动生成一位原创学生NPC', Icons.person_add, context),
                      _sectionTitle('🧪 进阶·作弊·结局'),
                      _buildCommandItem('/结局', '开始最终终章流程(当前条件满足时)', Icons.flag_circle, context),
                      _buildCommandItem('/终章', '同上，别名', Icons.flag, context),
                      _buildCommandItem('/cheat', '打开作弊帮助(好感/资源/声望/时间/骨科/CG解锁/舆论)', Icons.bug_report, context),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            inputController.text = '/帮助';
                            onHandleFreeAction();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD3A625),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('用 /帮助 获取带例子的完整文档'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {double top = 12}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, top, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8B949E),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCommandItem(String command, String description, IconData icon, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD3A625).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFD3A625)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(command,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3))),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              inputController.text = command;
              onHandleFreeAction();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD3A625).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow, size: 18, color: Color(0xFFD3A625)),
            ),
          ),
        ],
      ),
    );
  }
}
