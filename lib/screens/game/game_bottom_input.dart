import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';

class GameBottomInput extends StatelessWidget {
  final TextEditingController inputController;
  final TextEditingController menuController;
  final VoidCallback onHandleFreeAction;

  const GameBottomInput({
    super.key,
    required this.inputController,
    required this.menuController,
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
        child: Row(
          children: [
            GestureDetector(
              onTap: gp.isLoading
                  ? null
                  : () {
                      if (gp.choices.isNotEmpty) {
                        gp.processChoice(gp.choices.first);
                      }
                    },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: gp.isLoading ? const Color(0xFF374151) : const Color(0xFFD3A625),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!gp.isLoading)
                      BoxShadow(
                        color: const Color(0xFFD3A625).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
      ),
    );
  }

  void _showCommandMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
              const Text('在输入框输入 / 开头的命令即可触发',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
              const SizedBox(height: 16),
              _buildCommandItem('/帮助', '显示所有可用命令', Icons.help, context),
              _buildCommandItem('/状态', '查看角色完整属性', Icons.person, context),
              _buildCommandItem('/时间', '查看当前日期时间', Icons.schedule, context),
              _buildCommandItem('/地图', '快速跳转地图', Icons.map, context),
              _buildCommandItem('/关系', '查看NPC关系', Icons.people, context),
              _buildCommandItem('/恋爱', '查看恋爱状态', Icons.favorite, context),
              _buildCommandItem('/声望', '查看声望值', Icons.emoji_events, context),
              _buildCommandItem('/cheat', '打开作弊面板', Icons.bug_report, context),
              const SizedBox(height: 16),
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
                  child: const Text('查看完整命令列表'),
                ),
              ),
            ],
          ),
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
