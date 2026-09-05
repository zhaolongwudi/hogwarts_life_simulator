import 'package:flutter/material.dart';
import '../../providers/game_provider.dart';
import '../../theme/miuix_tokens.dart';

class SettingsTokenUsage extends StatelessWidget {
  final GameProvider gameProvider;
  final VoidCallback? onReset;

  const SettingsTokenUsage({
    super.key,
    required this.gameProvider,
    this.onReset,
  });

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: MiuiColors.onSurface)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gp = gameProvider;
    final hasData = gp.apiCalls > 0;
    final tokens = gp.totalTokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MiuiColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiuiColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: MiuiColors.primary, size: 18),
              const SizedBox(width: 6),
              const Text('📈 Token 使用统计',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: MiuiColors.primary)),
              const Spacer(),
              if (hasData)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('重置', style: TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasData)
            const Text('暂无数据，开始游戏后将自动统计',
                style: TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary))
          else ...[
            _buildStatRow('API 调用次数', '${gp.apiCalls} 次', const Color(0xFF3B82F6)),
            const SizedBox(height: 6),
            _buildStatRow('输入 Token', _formatNumber(gp.totalPromptTokens), const Color(0xFF8B5CF6)),
            const SizedBox(height: 6),
            _buildStatRow('输出 Token', _formatNumber(gp.totalCompletionTokens), MiuiColors.success),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MiuiColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('总消耗', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MiuiColors.primary)),
                  Text(_formatNumber(tokens),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: MiuiColors.primary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
