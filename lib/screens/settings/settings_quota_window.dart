import 'package:flutter/material.dart';
import '../../providers/app_provider.dart';
import '../../services/rate_limiter.dart';
import '../../theme/miuix_tokens.dart';

/// 5 小时配额窗口卡片（Q2）。
///
/// 修复前：设置页只有累计 Token 统计（apiCalls / 输入 / 输出），玩家从
/// UI 上无法回答「当前这个 5h 窗口还能玩几次」——耗尽前毫无预判。
/// 修复后：单独一块卡片，按 SenseNova 每个模型展示「剩余 / 上限」，
/// 数据源直接从限流闸门 `SenseNovaQuotaManager` 读，不抄第二份数字。
///
/// 只展示 SenseNova：DeepSeek 按量计费无限流、Agnes 是 20 RPM/分钟维度
/// （详见卡片说明区），这两个的「5h 剩余」语义不存在。
class SettingsQuotaWindow extends StatefulWidget {
  const SettingsQuotaWindow({super.key});

  @override
  State<SettingsQuotaWindow> createState() => _SettingsQuotaWindowState();
}

class _SettingsQuotaWindowState extends State<SettingsQuotaWindow> {
  Map<String, int>? _remaining; // model → 剩余
  Map<String, int>? _used; // model → 已用，用于进度条
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 免费模型列表即 SenseNova 的 4 个候选；已用/剩余从限流闸门读。
    final models = AppProvider().freeModelsFor(AiProvider.sensenova);
    final remaining = <String, int>{};
    final used = <String, int>{};
    for (final m in models) {
      remaining[m] = await SenseNovaQuotaManager.instance.remainingInWindow(m);
      used[m] = await SenseNovaQuotaManager.instance.usedInWindow(m);
    }
    if (!mounted) return;
    setState(() {
      _remaining = remaining;
      _used = used;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Icon(Icons.hourglass_bottom, color: MiuiColors.primary, size: 18),
              SizedBox(width: 6),
              Text('⏳ 5 小时配额窗口',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: MiuiColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('当前窗口 SenseNova 剩余可用次数（每 5 小时重置）',
              style:
                  TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            for (final m in (_remaining?.keys ?? const <String>[]))
              _buildRow(m, _used![m] ?? 0, _remaining![m] ?? 0),
        ],
      ),
    );
  }

  Widget _buildRow(String model, int used, int remaining) {
    final limit = SenseNovaQuotaManager.quotaForModel(model);
    final fraction = limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final exhausted = remaining <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(model,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: MiuiColors.onSurface)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '剩余 $remaining / $limit 次',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: exhausted
                            ? Colors.red
                            : MiuiColors.onSurfaceVariantSummary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: MiuiColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      exhausted
                          ? Colors.red
                          : (fraction >= 0.8
                              ? Colors.orange
                              : MiuiColors.success),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}