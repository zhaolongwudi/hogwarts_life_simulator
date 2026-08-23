import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';

class GringottsTab extends StatefulWidget {
  const GringottsTab({super.key});

  @override
  State<GringottsTab> createState() => _GringottsTabState();
}

class _GringottsTabState extends State<GringottsTab> {
  final _depositCtrl = TextEditingController();
  final _withdrawCtrl = TextEditingController();

  @override
  void dispose() {
    _depositCtrl.dispose();
    _withdrawCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🏛 古灵阁巫师银行', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text(
                  '由妖精运营的千年银行。存款无利息，但绝对安全——没有人敢抢古灵阁。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Consumer<GameProvider>(
            builder: (context, gp, _) => Column(
              children: [
                _buildBankAction(
                  context: context,
                  title: '存入加隆',
                  subtitle: '从随身钱包转入金库',
                  icon: Icons.arrow_upward,
                  color: Colors.green,
                  controller: _depositCtrl,
                  hint: '存入数量',
                  onConfirm: (amount) {
                    final ok = gp.depositToBank(amount);
                    return ok
                        ? '✅ 已存入 $amount 加隆。当前金库：${gp.player?.bankGalleons ?? 0}'
                        : '❌ 存入失败：随身加隆不足。';
                  },
                ),
                const SizedBox(height: 16),
                _buildBankAction(
                  context: context,
                  title: '取出加隆',
                  subtitle: '从金库转回随身钱包',
                  icon: Icons.arrow_downward,
                  color: Colors.orange,
                  controller: _withdrawCtrl,
                  hint: '取出数量',
                  onConfirm: (amount) {
                    final ok = gp.withdrawFromBank(amount);
                    return ok
                        ? '✅ 已取出 $amount 加隆。当前钱包：${gp.player?.galleons ?? 0}'
                        : '❌ 取出失败：金库余额不足。';
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAction({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hint,
    required String Function(int amount) onConfirm,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium!.color),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => controller.text = '',
                      icon: const Icon(Icons.clear, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  onPressed: () {
                    final amount = int.tryParse(controller.text.trim()) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入大于 0 的数量')),
                      );
                      return;
                    }
                    final msg = onConfirm(amount);
                    controller.clear();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('确认'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
