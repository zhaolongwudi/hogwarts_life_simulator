import 'package:flutter/material.dart';
import '../../providers/app_provider.dart';
import '../../services/ai_router.dart';
import '../../data/provider_defaults.dart';
import '../../theme/miuix_tokens.dart';

class SettingsSceneRouting extends StatelessWidget {
  final AppProvider appProvider;
  final void Function(AiScene scene, AiProvider provider)? onSceneRouteChanged;

  const SettingsSceneRouting({
    super.key,
    required this.appProvider,
    this.onSceneRouteChanged,
  });

  String _sceneInfo(AiScene scene) {
    switch (scene) {
      case AiScene.narrative:
        return '≈1500-3000 token/回合 · 约8次/小时';
      case AiScene.summary:
        return '≈800-1200 token/次 · 每10回合1次';
      case AiScene.npcChat:
        return '≈300-800 token/次 · 按需调用';
      case AiScene.choice:
        return '≈200-500 token/次 · 选项不足3个时触发';
    }
  }

  /// 提供商展示名，统一走数据层（settings_provider_card 用的是同一个值）。
  String providerNameLabel(AiProvider p) => providerDisplayName(p.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiuiColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: MiuiColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('🔀 多模型路由配置',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('为不同场景分配 AI 提供商，实现最优成本与效果',
              style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
          const SizedBox(height: 10),
          ...AiScene.values.map((scene) => _buildSceneRow(scene, appProvider, context)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MiuiColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MiuiColors.outline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 场景预估',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MiuiColors.primary)),
                SizedBox(height: 6),
                Text('• 主剧情: 1500-3000 token/回合 | 约8次/游戏小时',
                    style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary, height: 1.4)),
                Text('• 摘要压缩: 800-1200 token/次 | 每10回合触发1次',
                    style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary, height: 1.4)),
                Text('• NPC聊天: 300-800 token/次 | 按需调用',
                    style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneRow(AiScene scene, AppProvider appProvider, BuildContext context) {
    final provider = appProvider.providerForScene(scene);
    final description = kSceneDescriptions[scene] ?? '';
    final label = kSceneLabels[scene] ?? scene.name;
    final hasKey = appProvider.hasKey(provider);
    final info = _sceneInfo(scene);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MiuiColors.disabledOnSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        if (!hasKey)
                          const Text('未配置Key',
                              style: TextStyle(fontSize: 11, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            color: MiuiColors.onSurfaceVariantSummary, fontSize: 11, height: 1.3)),
                    const SizedBox(height: 2),
                    Text(info,
                        style: const TextStyle(
                            color: MiuiColors.primary, fontSize: 10.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: AiProvider.values.map((p) {
              final selected = provider == p;
              final hasP = appProvider.hasKey(p);
              return GestureDetector(
                onTap: () {
                  onSceneRouteChanged?.call(scene, p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? MiuiColors.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? MiuiColors.primary
                          : (hasP
                              ? const Color(0xFF4B5563)
                              : MiuiColors.disabledOnSurface),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        providerNameLabel(p),
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? MiuiColors.primary
                              : (hasP ? Colors.white : MiuiColors.onSurfaceVariantActions),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (!hasP) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock, size: 11, color: MiuiColors.onSurfaceVariantActions),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
